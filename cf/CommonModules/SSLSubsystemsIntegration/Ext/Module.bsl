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

// Defines events, to which other libraries can subscribe.
//
// Returns:
//   Structure - structure property keys are names of events, to which
//               libraries can be subscribed.
//
Function SSLEvents() Export

	Events = New Structure;
	
	// Core
	Events.Insert("OnAddSubsystems", False);
	Events.Insert("OnSetSessionParameters", False);
	Events.Insert("OnAddSessionParameterSettingHandlers", False);
	Events.Insert("OnAddReferenceSearchExceptions", False);
	Events.Insert("OnAddMetadataObjectsRenaming", False);
	Events.Insert("OnFillAllExtensionParameters", False);
	Events.Insert("OnClearAllExtemsionParameters", False);
	Events.Insert("OnSendDataToMaster", False);
	Events.Insert("OnSendDataToSlave", False);
	Events.Insert("OnReceiveDataFromMaster", False);
	Events.Insert("OnReceiveDataFromSlave", False);
	Events.Insert("AfterGetData", False);
	Events.Insert("OnEnableSeparationByDataAreas", False);
	Events.Insert("OnDefineSupportedInterfaceVersions", False);
	Events.Insert("OnAddClientParametersOnStart", False);
	Events.Insert("OnAddClientParameters", False);
	Events.Insert("BeforeStartApplication", False);
	Events.Insert("OnAddServerNotifications", False);
	Events.Insert("OnReceiptRecurringClientDataOnServer", False);
	
	// Banks
	Events.Insert("OnDefineBankClassifiersImportSettings");
	
	// ReportsOptions
	Events.Insert("OnDefineReportsOptionsSettings", False);
	Events.Insert("OnDefineSectionsWithReportOptions", False);
	Events.Insert("OnSetUpReportsOptions", False);
	Events.Insert("OnChangeReportsOptionsKeys", False);
	Events.Insert("OnDefineObjectsWithReportCommands", False);
	Events.Insert("BeforeAddReportCommands", False);
	Events.Insert("OnDefineSelectionParametersReportsOptions", False);
	Events.Insert("OnCreateAtServerReportsOptions", False);
	Events.Insert("BeforeLoadVariantAtServer", False);
	
	// AddIns
	Events.Insert("OnDefineUsedAddIns", False);
	
	// BatchObjectsModification
	Events.Insert("OnDefineObjectsWithEditableAttributes", False);
	Events.Insert("OnDefineEditableObjectAttributes", False);
	
	// PeriodClosingDates
	Events.Insert("OnFillPeriodClosingDatesSections", False);
	Events.Insert("OnFillDataSourcesForPeriodClosingCheck", False);
	
	// AdditionalReportsAndDataProcessors
	Events.Insert("OnSetAdditionalReportOrDataProcessorAttachmentModeInDataArea", False);
	
	// ImportDataFromFile
	Events.Insert("OnDefineCatalogsForDataImport", False);
	
	// ObjectAttributesLock
	Events.Insert("OnDefineObjectsWithLockedAttributes", False);
	
	// ODataInterface
	Events.Insert("OnFillTypesExcludedFromExportImportOData", False);
	Events.Insert("OnPopulateDependantTablesForODataImportExport", False);
	
	// AccountingAudit
	Events.Insert("OnDefineChecks", False);
	
	// UserReminders
	Events.Insert("OnFillSourceAttributesListWithReminderDates", False);
	
	// DataExchange
	Events.Insert("OnSetUpSubordinateDIBNode", False);
	
	// IBVersionUpdate
	Events.Insert("OnAddUpdateHandlers", False); // Intended for compatibility with CTL v1.2.2.
	Events.Insert("AfterUpdateInfobase", False);
	Events.Insert("OnGetUpdatePriority", False);
	Events.Insert("OnPopulateObjectsPlannedForDeletion", False);
	
	// Print
	Events.Insert("OnDefinePrintSettings", False);
	Events.Insert("OnPrepareTemplateListInOfficeDocumentServerFormat", False);
	Events.Insert("OnDefineObjectsWithPrintCommands", False); // Deprecated. Obsolete. Use OnDefinePrintSettings instead. 
	Events.Insert("BeforeAddPrintCommands", False);
	Events.Insert("OnGetPrintCommandListSettings", False);
	Events.Insert("OnPrint", False);
	Events.Insert("BeforeSendingByEmail", False);
	Events.Insert("OnGetSignaturesAndSeals", False);
	Events.Insert("PrintDocumentsOnCreateAtServer", False);
	Events.Insert("PrintDocumentsOnImportDataFromSettingsAtServer", False);
	Events.Insert("PrintDocumentsOnSaveDataInSettingsAtServer", False);
	Events.Insert("PrintDocumentsOnExecuteCommand", False);
	Events.Insert("OnDefinePrintDataSources", False);
	Events.Insert("WhenPreparingPrintData", False);
	
	// AttachableCommands
	Events.Insert("OnDefineAttachableCommandsKinds", False);
	Events.Insert("OnDefineAttachableObjectsSettingsComposition", False);
	Events.Insert("OnDefineCommandsAttachedToObject", False);
	Events.Insert("OnDefineObjectsWithCreationBasedOnCommands", False);
	Events.Insert("BeforeAddGenerationCommands", False);
	Events.Insert("OnAddGenerationCommands", False);
	
	// Users
	Events.Insert("OnDefineSettings", False);
	Events.Insert("OnDefineRoleAssignment", False);
	Events.Insert("OnDefineActionsInForm", False);
	Events.Insert("OnGetOtherSettings", False);
	Events.Insert("OnSaveOtherSetings", False);
	Events.Insert("OnDeleteOtherSettings", False);
	Events.Insert("OnEndIBUserProcessing", False);
	Events.Insert("OnDefineRegistrationSettingsForDataAccessEvents", False);
	
	// SecurityProfiles
	Events.Insert("OnCheckCanSetupSecurityProfiles", False);
	Events.Insert("OnRequestPermissionsToUseExternalResources", False);
	Events.Insert("OnRequestToCreateSecurityProfile", False);
	Events.Insert("OnRequestToDeleteSecurityProfile", False);
	Events.Insert("OnAttachExternalModule", False);
	Events.Insert("OnEnableSecurityProfiles", False);
	Events.Insert("OnFillPermissionsToAccessExternalResources", False);
	
	// EmailOperations  
	Events.Insert("BeforeGetEmailMessagesStatuses", False); 
	Events.Insert("AfterGetEmailMessagesStatuses", False);	
	
	// StoredFiles
	Events.Insert("OnCreateFilesListForm", False);
	Events.Insert("OnCreateFilesItemForm", False);
	Events.Insert("OnDefineFileSynchronizationExceptionObjects", False);
	Events.Insert("OnSendFilesViaEmail", False);
	
	// ScheduledJobs
	Events.Insert("OnDefineScheduledJobSettings", False);
	Events.Insert("WhenYouAreForbiddenToWorkWithExternalResources", False);
	Events.Insert("WhenAllowingWorkWithExternalResources", False);
	
	// Properties
	Events.Insert("OnGetPredefinedPropertiesSets", False);
	
	// ToDoList
	Events.Insert("OnDetermineToDoListHandlers", False);
	Events.Insert("OnFillToDoList", False);
	Events.Insert("OnDetermineCommandInterfaceSectionsOrder", False);
	Events.Insert("OnDisableToDos", False);
	Events.Insert("OnDefineToDoListSettings", False);
	Events.Insert("OnSetCommonQueryParameters", False);
	
	// AccessManagement
	Events.Insert("OnFillAccessKinds", False);
	Events.Insert("OnFillListsWithAccessRestriction", False);
	Events.Insert("OnFillSuppliedAccessGroupProfiles", False);
	Events.Insert("OnFillAccessRightsDependencies", False);
	Events.Insert("OnFillAvailableRightsForObjectsRightsSettings", False);
	Events.Insert("OnFillAccessKindUsage", False);
	Events.Insert("OnFillMetadataObjectsAccessRestrictionKinds", False);
	
	// MonitoringCenter
	Events.Insert("OnCollectConfigurationStatisticsParameters", False);

	Return Events;

EndFunction

#Region CTLEventHandlers

// Handle software events that occur in CTL subsystems.
// Intended only for calls from CTL to SSL.

// Defines events, to which this library is subscribed.
//
// Parameters:
//  Subscriptions - See CTLSubsystemsIntegration.EventsCTL.
//
Procedure OnDefineEventsSubscriptionsCTL(Subscriptions) Export
	
	// Core
	Subscriptions.OnAddCTLUpdateHandlers = True;
	
	// ExportImportData
	Subscriptions.OnFillTypesThatRequireRefAnnotationOnImport = True;
	Subscriptions.OnFillCommonDataTypesSupportingRefMappingOnExport = True;
	Subscriptions.OnFillCommonDataTypesThatDoNotRequireMappingRefsOnImport = True;
	Subscriptions.OnFillTypesExcludedFromExportImport = True;
	Subscriptions.OnRegisterDataExportHandlers = True;
	Subscriptions.OnRegisterDataImportHandlers = True;
	Subscriptions.AfterImportData = True;
	Subscriptions.BeforeExportData = True;
	Subscriptions.BeforeImportData = True;
	Subscriptions.OnImportInfobaseUser = True;
	Subscriptions.AfterImportInfobaseUser = True;
	Subscriptions.AfterImportInfobaseUsers = True;
	
	// SaaS_CoreSaaS
	Subscriptions.OnFillIIBParametersTable = True;
	Subscriptions.OnDefineSharedDataExceptions = True;
	Subscriptions.OnDefineUserAlias = True;

	// SaaS_MessageExchange
	Subscriptions.OnDefineMessagesChannelsHandlers  = True;
	Subscriptions.RecordingIncomingMessageInterfaces  = True;
	Subscriptions.RecordingOutgoingMessageInterfaces = True;
	
	// SaaS_JobsQueue
	Subscriptions.OnGetTemplateList = True;
	Subscriptions.OnDefineHandlerAliases = True;
	Subscriptions.OnDefineScheduledJobsUsage = True;
	
	// SaaS_SuppliedData
	Subscriptions.OnDefineSuppliedDataHandlers = True;

EndProcedure

#Region Core

// See InfobaseUpdateCTL.OnAddUpdateHandlers.
Procedure OnAddCTLUpdateHandlers(Handlers) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsSaaS");
		ModuleAdditionalReportsAndDataProcessorsSaaS.OnAddUpdateHandlers(Handlers);
	EndIf;

EndProcedure

#EndRegion

#Region ExportImportData

// See ExportImportDataOverridable.OnFillTypesThatRequireRefAnnotationOnImport.
Procedure OnFillTypesThatRequireRefAnnotationOnImport(Types) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.OnFillTypesThatRequireRefAnnotationOnImport(Types);
	EndIf;

EndProcedure

// See ExportImportDataOverridable.OnFillCommonDataTypesSupportingRefMappingOnExport.
Procedure OnFillCommonDataTypesSupportingRefMappingOnExport(Types) Export

	StandardSubsystemsServer.OnFillCommonDataTypesSupportingRefMappingOnExport(Types);

	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManager = Common.CommonModule("BankManager");
		ModuleBankManager.OnFillCommonDataTypesSupportingRefMappingOnExport(Types);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnFillCommonDataTypesSupportingRefMappingOnExport(Types);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnFillCommonDataTypesSupportingRefMappingOnExport(
			Types);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		ModuleCalendarSchedules = Common.CommonModule("CalendarSchedules");
		ModuleCalendarSchedules.OnFillCommonDataTypesSupportingRefMappingOnExport(Types);
	EndIf;

EndProcedure

// See ExportImportDataOverridable.OnFillCommonDataTypesThatDoNotRequireMappingRefsOnImport.
Procedure OnFillCommonDataTypesThatDoNotRequireMappingRefsOnImport(Types) Export

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnFillCommonDataTypesThatDoNotRequireMappingRefsOnImport(Types);
	EndIf;

EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport.
Procedure OnFillTypesExcludedFromExportImport(Types) Export

	If Not Common.SubsystemExists("CloudTechnology.ExportImportData") Then
		Return;
	EndIf;
	
	StandardSubsystemsServer.OnFillTypesExcludedFromExportImport(Types);
	ServerNotifications.OnFillTypesExcludedFromExportImport(Types);
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		ModuleAddressClassifierInternal.OnFillTypesExcludedFromExportImport(Types);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnFillTypesExcludedFromExportImport(Types);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnFillTypesExcludedFromExportImport(Types);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		ModuleAddInsInternal.OnFillTypesExcludedFromExportImport(Types);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule(
			"AddInsSaaSInternal");
		ModuleAddInsSaaSInternal.OnFillTypesExcludedFromExportImport(Types);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsSaaS");
		ModuleAdditionalReportsAndDataProcessorsSaaS.OnFillTypesExcludedFromExportImport(Types);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UsersSessions") Then
		ModuleIBConnections = Common.CommonModule("IBConnections");
		ModuleIBConnections.OnFillTypesExcludedFromExportImport(Types);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		ModuleAccountingAuditInternal.OnFillTypesExcludedFromExportImport(Types);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule(
			"InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnFillTypesExcludedFromExportImport(Types);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.FilesOperationsSaaS") Then
		ModuleFilesOperationsInternalSaaS = Common.CommonModule("FilesOperationsInternalSaaS");
		ModuleFilesOperationsInternalSaaS.OnFillTypesExcludedFromExportImport(Types);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnFillTypesExcludedFromExportImport(Types);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectsDeletionInternal = Common.CommonModule("MarkedObjectsDeletionInternal");
		ModuleMarkedObjectsDeletionInternal.OnFillTypesExcludedFromExportImport(Types);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DSSElectronicSignatureService") Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleInternal.OnFillTypesExcludedFromExportImport(Types);
	EndIf;
	
EndProcedure

// See ExportImportDataOverridable.OnRegisterDataExportHandlers.
Procedure OnRegisterDataExportHandlers(HandlersTable) Export

	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnRegisterDataExportHandlers(HandlersTable);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.FilesOperationsSaaS") Then
		ModuleFilesOperationsInternalSaaS = Common.CommonModule("FilesOperationsInternalSaaS");
		ModuleFilesOperationsInternalSaaS.OnRegisterDataExportHandlers(HandlersTable);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.OnRegisterDataExportHandlers(HandlersTable);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnRegisterDataExportHandlers(HandlersTable);
	EndIf;

EndProcedure

// See ExportImportDataOverridable.OnRegisterDataImportHandlers.
Procedure OnRegisterDataImportHandlers(HandlersTable) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.FilesOperationsSaaS") Then
		ModuleFilesOperationsInternalSaaS = Common.CommonModule(
			"FilesOperationsInternalSaaS");
		ModuleFilesOperationsInternalSaaS.OnRegisterDataImportHandlers(HandlersTable);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.OnRegisterDataImportHandlers(HandlersTable);
	EndIf;

EndProcedure

// See ExportImportDataOverridable.BeforeExportData
Procedure BeforeExportData(Container) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule(
			"InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.BeforeExportData(Container);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ODataInterface") Then
		ModuleODataInterfaceInternal = Common.CommonModule("ODataInterfaceInternal");
		ModuleODataInterfaceInternal.BeforeExportData(Container);
	EndIf;

EndProcedure

// See ExportImportDataOverridable.BeforeImportData
Procedure BeforeImportData(Container) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule(
			"InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.BeforeImportData(Container);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ODataInterface") Then
		ModuleODataInterfaceInternal = Common.CommonModule("ODataInterfaceInternal");
		ModuleODataInterfaceInternal.BeforeImportData(Container);
	EndIf;

EndProcedure

// See ExportImportDataOverridable.AfterImportData.
Procedure AfterImportData(Container) Export

	UsersInternal.AfterImportData(Container);

	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		ModuleScheduledJobsInternal.AfterImportData(Container);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRatesInternal = Common.CommonModule("CurrencyRateOperationsInternal");
		ModuleCurrencyExchangeRatesInternal.AfterImportData(Container);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule(
			"InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.AfterImportData(Container);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AccessManagementSaaS") Then
		ModuleAccessManagementInternalSaaS = Common.CommonModule(
			"AccessManagementInternalSaaS");
		ModuleAccessManagementInternalSaaS.AfterImportData(Container);
	EndIf;

	InfobaseUpdateInternal.AfterImportData(Container);
	
	StandardSubsystemsServer.AfterImportData(Container);
	
EndProcedure

// See ExportImportDataOverridable.OnImportInfobaseUser.
Procedure OnImportInfobaseUser(Container, Serialization, IBUser, Cancel) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.OnImportInfobaseUser(Container, Serialization,
			IBUser, Cancel);
	EndIf;

EndProcedure

// See ExportImportDataOverridable.AfterImportInfobaseUser.
Procedure AfterImportInfobaseUser(Container, Serialization, IBUser) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.AfterImportInfobaseUser(Container, Serialization,
			IBUser);
	EndIf;

EndProcedure

// See ExportImportDataOverridable.AfterImportInfobaseUsers.
Procedure AfterImportInfobaseUsers(Container) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.AfterImportInfobaseUsers(Container);
	EndIf;

EndProcedure

#EndRegion

#Region SaaSOperations_CoreSaaS

// See SaaSOperationsOverridable.OnFillIIBParametersTable.
Procedure OnFillIIBParametersTable(Val ParametersTable) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnFillIIBParametersTable(ParametersTable);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		ModuleScheduledJobsInternal.OnFillIIBParametersTable(ParametersTable);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UsersSessions") Then
		ModuleIBConnections = Common.CommonModule("IBConnections");
		ModuleIBConnections.OnFillIIBParametersTable(ParametersTable);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DSSElectronicSignatureService") Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleInternal.OnFillIIBParametersTable(ParametersTable);
	EndIf;
	
EndProcedure

// Overrides shared data exceptions for the SaaSTechnology subsystem 
// 
// Parameters:
//  Exceptions - Array of MetadataObject - Exceptions.
//
Procedure OnDefineSharedDataExceptions(Exceptions) Export

	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnDefineSharedDataExceptions(Exceptions);
	EndIf;

EndProcedure

// Allows to override the result of the SaaS.InfobaseUserAlias function.
//
// Parameters:
//   UserIdentificator - UUID - user ID.
//   Alias - String - Infobase user alias to be shown in interface.
//
Procedure OnDefineUserAlias(UserIdentificator, Alias) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.OnDefineUserAlias(UserIdentificator,
			Alias);
	EndIf;

EndProcedure

#EndRegion

#Region SaaSOperations_MessagesExchange

// See MessagesExchangeOverridable.GetMessagesChannelsHandlers.
Procedure OnDefineMessagesChannelsHandlers(Handlers) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnDefineMessagesChannelsHandlers(Handlers);
	EndIf;

EndProcedure

// See MessageInterfacesSaaSOverridable.FillInHandlersForSendingMessages.
Procedure RecordingOutgoingMessageInterfaces(HandlersArray) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.RecordingOutgoingMessageInterfaces(HandlersArray);
	EndIf;

EndProcedure

// See MessageInterfacesSaaSOverridable.FillInReceivedMessageHandlers.
Procedure RecordingIncomingMessageInterfaces(HandlersArray) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.RecordingIncomingMessageInterfaces(HandlersArray);
	EndIf;

EndProcedure

#EndRegion

#Region SaaSOperations_JobsQueue

// See JobsQueueOverridable.OnGetTemplateList.
Procedure OnGetTemplateList(JobTemplates) Export

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnGetTemplateList(JobTemplates);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnGetTemplateList(JobTemplates);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnGetTemplateList(JobTemplates);
		ModuleEmailManager = Common.CommonModule("EmailManagement");
		ModuleEmailManager.OnGetTemplateList(JobTemplates);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnGetTemplateList(JobTemplates);
	EndIf;

	InfobaseUpdateInternal.OnGetTemplateList(JobTemplates);

	StandardSubsystemsServer.OnGetTemplateList(JobTemplates);

	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectsDeletionInternal = Common.CommonModule("MarkedObjectsDeletionInternal");
		ModuleMarkedObjectsDeletionInternal.OnGetTemplateList(JobTemplates);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AccessManagementSaaS") Then
		ModuleAccessManagementInternalSaaS = Common.CommonModule(
			"AccessManagementInternalSaaS");
		ModuleAccessManagementInternalSaaS.OnGetTemplateList(JobTemplates);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.TotalsAndAggregatesManagement") Then
		ModuleTotalsAndAggregatesInternal = Common.CommonModule(
			"TotalsAndAggregatesManagementInternal");
		ModuleTotalsAndAggregatesInternal.OnGetTemplateList(JobTemplates);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.FilesOperationsSaaS") Then
		ModuleFilesOperationsInternalSaaS = Common.CommonModule("FilesOperationsInternalSaaS");
		ModuleFilesOperationsInternalSaaS.OnGetTemplateList(JobTemplates);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule(
			"ContactsManagerInternal");
		ModuleContactsManagerInternal.OnGetTemplateList(JobTemplates);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		ModuleAccountingAuditInternal.OnGetTemplateList(JobTemplates);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnGetTemplateList(JobTemplates);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MachineReadableLettersOfAuthority") Then
		ModuleMachineReadableLettersOfAuthorityFTSInternal = Common.CommonModule("MachineReadableLettersOfAuthorityFTSInternal");
		ModuleMachineReadableLettersOfAuthorityFTSInternal.OnGetTemplateList(JobTemplates);
	EndIf;

	
EndProcedure

// See JobsQueueOverridable.OnDefineHandlerAliases.
Procedure OnDefineHandlerAliases(NamesAndAliasesMap) Export
	
	ServerNotifications.OnDefineHandlerAliases(NamesAndAliasesMap);
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDefineHandlerAliases(NamesAndAliasesMap);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnDefineHandlerAliases(NamesAndAliasesMap);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnDefineHandlerAliases(NamesAndAliasesMap);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRatesInternal = Common.CommonModule("CurrencyRateOperationsInternal");
		ModuleCurrencyExchangeRatesInternal.OnDefineHandlerAliases(NamesAndAliasesMap);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule(
			"ContactsManagerInternal");
		ModuleContactsManagerInternal.OnDefineHandlerAliases(
			NamesAndAliasesMap);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		ModuleCalendarSchedulesInternal = Common.CommonModule("CalendarSchedulesInternal");
		ModuleCalendarSchedulesInternal.OnDefineHandlerAliases(NamesAndAliasesMap);
	EndIf;

	InfobaseUpdateInternal.OnDefineHandlerAliases(NamesAndAliasesMap);
	
	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule(
			"InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnDefineHandlerAliases(
			NamesAndAliasesMap);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.FilesOperationsSaaS") Then
		ModuleFilesOperationsInternalSaaS = Common.CommonModule("FilesOperationsInternalSaaS");
		ModuleFilesOperationsInternalSaaS.OnDefineHandlerAliases(NamesAndAliasesMap);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectsDeletionInternal = Common.CommonModule("MarkedObjectsDeletionInternal");
		ModuleMarkedObjectsDeletionInternal.OnDefineHandlerAliases(NamesAndAliasesMap);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnDefineHandlerAliases(NamesAndAliasesMap);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnDefineHandlerAliases(NamesAndAliasesMap);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule("EmailOperationsInternal");
		ModuleEmailOperationsInternal.OnDefineHandlerAliases(NamesAndAliasesMap);
	EndIf;
	
EndProcedure

// See JobsQueueOverridable.OnDefineScheduledJobsUsage.
Procedure OnDefineScheduledJobsUsage(UsageTable) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule(
			"InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnDefineScheduledJobsUsage(
			UsageTable);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.FilesOperationsSaaS") Then
		ModuleFilesOperationsInternalSaaS = Common.CommonModule("FilesOperationsInternalSaaS");
		ModuleFilesOperationsInternalSaaS.OnDefineScheduledJobsUsage(UsageTable);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		ModuleScheduledJobsInternal.OnDefineScheduledJobsUsage(UsageTable);
	EndIf;
	
EndProcedure

#EndRegion

#Region SaaSOperations_SuppliedData

// See SuppliedDataOverridable.GetHandlersForSuppliedData.
Procedure OnDefineSuppliedDataHandlers(Handlers) Export

	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		ModuleAddressClassifierInternal.OnDefineSuppliedDataHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRatesInternal = Common.CommonModule("CurrencyRateOperationsInternal");
		ModuleCurrencyExchangeRatesInternal.OnDefineSuppliedDataHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnDefineSuppliedDataHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsSaaS");
		ModuleAdditionalReportsAndDataProcessorsSaaS.OnDefineSuppliedDataHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnDefineSuppliedDataHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DSSElectronicSignatureService") Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleInternal.OnDefineSuppliedDataHandlers(Handlers);
	EndIf;

EndProcedure

#EndRegion

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
	
	// Core
	Subscriptions.OnChangeOnlineSupportAuthenticationData = True;
	
	// ClassifiersOperations
	Subscriptions.OnAddClassifiers = True;
	Subscriptions.OnImportClassifier = True;
	Subscriptions.OnProcessDataArea = True;
	
	// DigitalSignature
	Subscriptions.OnDefineAddInsVersionsToUse = True;
	
EndProcedure

#Region Core

// See OnlineUserSupportOverridable.OnChangeOnlineSupportAuthenticationData.
Procedure OnChangeOnlineSupportAuthenticationData(UserData) Export

	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnChangeOnlineSupportAuthenticationData(UserData);
	EndIf;

EndProcedure

#EndRegion

#Region AddInsSaaS

// See GetAddInsSaaSOverridable.OnDefineAddInsVersionsToUse.
Procedure OnDefineAddInsVersionsToUse(IDs) Export

	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		CommonClientServer.SupplementArray(
			IDs, ModuleAddInsInternal.SuppliedAddIns(), True);
	EndIf;

EndProcedure

#EndRegion

#Region ClassifiersOperations

// See ClassifiersOperationsOverridable.OnAddClassifiers.
Procedure OnAddClassifiers(Classifiers) Export

	If Common.SubsystemExists("StandardSubsystems.Banks") And Metadata.DataProcessors.Find(
		"ImportBankClassifier") <> Undefined Then
		ModuleImportBankClassifier = Common.CommonModule("DataProcessors.ImportBankClassifier");
		ModuleImportBankClassifier.OnAddClassifiers(Classifiers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Currencies") And Metadata.DataProcessors.Find(
		"CurrenciesRatesImport") <> Undefined Then
		ModuleImportCurrenciesRates = Common.CommonModule("DataProcessors.CurrenciesRatesImport");
		ModuleImportCurrenciesRates.OnAddClassifiers(Classifiers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		ModuleCalendarSchedules = Common.CommonModule("CalendarSchedules");
		ModuleCalendarSchedules.OnAddClassifiers(Classifiers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternalCached = Common.CommonModule("ContactsManagerInternalCached");
		If ModuleContactsManagerInternalCached.AreAddressManagementModulesAvailable() Then
			ModuleAddressManager = Common.CommonModule("AddressManager");
			ModuleAddressManager.OnAddClassifiers(Classifiers);
		EndIf;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") 
		And Metadata.CommonModules.Find("DigitalSignatureInternalLocalization") <> Undefined Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnAddClassifiers(Classifiers);
	EndIf;
	
EndProcedure

// See ClassifiersOperationsOverridable.OnImportClassifier.
Procedure OnImportClassifier(Id, Version, Address, Processed, AdditionalParameters) Export

	If Common.SubsystemExists("StandardSubsystems.Banks")
		And Metadata.DataProcessors.Find("ImportBankClassifier") <> Undefined Then
		ModuleImportBankClassifier = Common.CommonModule("DataProcessors.ImportBankClassifier");
		ModuleImportBankClassifier.OnImportClassifier(Id, Version, Address, Processed,
			AdditionalParameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Currencies")
		And Metadata.DataProcessors.Find("CurrenciesRatesImport") <> Undefined Then
		ModuleImportCurrenciesRates = Common.CommonModule("DataProcessors.CurrenciesRatesImport");
		ModuleImportCurrenciesRates.OnImportClassifier(Id, Version, Address, Processed,
			AdditionalParameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		ModuleCalendarSchedules = Common.CommonModule("CalendarSchedules");
		ModuleCalendarSchedules.OnImportClassifier(Id, Version, Address, Processed,
			AdditionalParameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternalCached = Common.CommonModule("ContactsManagerInternalCached");
		If ModuleContactsManagerInternalCached.AreAddressManagementModulesAvailable() Then
			ModuleAddressManager = Common.CommonModule("AddressManager");
			ModuleAddressManager.OnImportClassifier(Id, Version, Address, Processed,
				AdditionalParameters);
		EndIf;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature")
		And Metadata.CommonModules.Find("DigitalSignatureInternalLocalization") <> Undefined Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnImportClassifier(Id, Version, Address, Processed,
			AdditionalParameters);
	EndIf;

EndProcedure

// See ClassifiersOperationsSaaSOverridable.OnProcessDataArea.
Procedure OnProcessDataArea(Id, Version, AdditionalParameters) Export

	If Not Common.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		Return;
	EndIf;

	ModuleCalendarSchedules = Common.CommonModule("CalendarSchedules");
	If Id <> ModuleCalendarSchedules.ClassifierID() Then
		Return;
	EndIf;

	If Not AdditionalParameters.Property(Id) Then
		Return;
	EndIf;

	ParametersOfUpdate = AdditionalParameters[Id];

	ModuleCalendarSchedules.FillDataDependentOnBusinessCalendars(ParametersOfUpdate.ChangesTable);

EndProcedure

#EndRegion

#EndRegion

#EndRegion

#EndRegion

#Region Internal

#Region Core

// See ConfigurationSubsystemsOverridable.OnAddSubsystems.
Procedure OnAddSubsystems(SubsystemsModules) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnAddSubsystems Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnAddSubsystems(SubsystemsModules);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnAddSubsystems Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnAddSubsystems(SubsystemsModules);
	EndIf;

EndProcedure

// Parameters:
//   Parameters - See StandardSubsystemsServer.SessionParametersSetting.SessionParametersNames.
//
Procedure OnSetSessionParameters(Parameters) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnSetSessionParameters Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnSetSessionParameters(Parameters);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnSetSessionParameters Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnSetSessionParameters(Parameters);
	EndIf;

EndProcedure

// See CommonOverridable.OnAddSessionParameterSettingHandlers.
Procedure OnAddSessionParameterSettingHandlers(Handlers) Export

	InfobaseUpdateInternal.OnAddSessionParameterSettingHandlers(Handlers);
	UsersInternal.OnAddSessionParameterSettingHandlers(Handlers);

	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule(
			"ContactsManagerInternal");
		ModuleContactsManagerInternal.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		ModulePerformanceMonitorInternal.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleWorkLockWithExternalResources = Common.CommonModule("ExternalResourcesOperationsLock");
		ModuleWorkLockWithExternalResources.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectsDeletionInternal = Common.CommonModule("MarkedObjectsDeletionInternal");
		ModuleMarkedObjectsDeletionInternal.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnAddSessionParameterSettingHandlers Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnAddSessionParameterSettingHandlers Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DSSElectronicSignatureService") Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleInternal.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MachineReadableLettersOfAuthority") Then
		ModuleMachineReadableLettersOfAuthorityFTSInternal = Common.CommonModule("MachineReadableLettersOfAuthorityFTSInternal");
		ModuleMachineReadableLettersOfAuthorityFTSInternal.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddReferenceSearchExceptions.
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectsDeletionInternal = Common.CommonModule("MarkedObjectsDeletionInternal");
		ModuleMarkedObjectsDeletionInternal.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;

	UsersInternal.OnAddReferenceSearchExceptions(RefSearchExclusions);
	InfobaseUpdateInternal.OnAddReferenceSearchExceptions(RefSearchExclusions);
	StandardSubsystemsServer.OnAddReferenceSearchExceptions(RefSearchExclusions);

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnAddReferenceSearchExceptions Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnAddReferenceSearchExceptions Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;

EndProcedure

// See CommonOverridable.OnDefineSubordinateObjects
Procedure OnDefineSubordinateObjects(SubordinateObjects) Export

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnDefineSubordinateObjects(SubordinateObjects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnDefineSubordinateObjects(SubordinateObjects);
	EndIf;

EndProcedure

// Adds related subordinate objects to a duplicate collection.
//
// Parameters:
//  ReplacementPairs		 - See Common.ReplaceReferences.ReplacementPairs
//  ReplacementParameters - See Common.RefsReplacementParameters
//
Procedure BeforeSearchForUsageInstances(ReplacementPairs, ExecutionParameters) Export

	If Common.SubsystemExists("StandardSubsystems.DuplicateObjectsDetection") Then
		ModuleDuplicateObjectsDetection = Common.CommonModule("DuplicateObjectsDetection");
		ModuleDuplicateObjectsDetection.SupplementDuplicatesWithLinkedSubordinateObjects(ReplacementPairs, ExecutionParameters);
	EndIf;

EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming.
Procedure OnAddMetadataObjectsRenaming(Total) Export

	StandardSubsystemsServer.OnAddMetadataObjectsRenaming(Total);

	If Common.SubsystemExists("StandardSubsystems.UserMonitoring") Then
		ModuleUserMonitoringInternal = Common.CommonModule("UserMonitoringInternal");
		ModuleUserMonitoringInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnAddMetadataObjectsRenaming(Total);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnAddMetadataObjectsRenaming(Total);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UserNotes") Then
		ModuleUserNotesInternal = Common.CommonModule("UserNotesInternal");
		ModuleUserNotesInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UserReminders") Then
		ModuleUserReminderInternal = Common.CommonModule("UserRemindersInternal");
		ModuleUserReminderInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ApplicationSettings") Then
		ModuleAdministrationPanelSSL = Common.CommonModule("DataProcessors.SSLAdministrationPanel");
		ModuleAdministrationPanelSSL.OnAddMetadataObjectsRenaming(Total);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnAddMetadataObjectsRenaming(Total);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule(
			"EmailOperationsInternal");
		ModuleEmailOperationsInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SubordinationStructure") Then
		ModuleHierarchyInternal = Common.CommonModule("SubordinationStructureInternal");
		ModuleHierarchyInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ToDoList") Then
		ModuleToDoListInternal = Common.CommonModule("ToDoListInternal");
		ModuleToDoListInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnAddMetadataObjectsRenaming Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnAddMetadataObjectsRenaming(Total);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnAddMetadataObjectsRenaming Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnAddMetadataObjectsRenaming(Total);
	EndIf;

EndProcedure

// 
Procedure OnFillAllExtensionParameters() Export

	UsersInternal.OnFillAllExtensionParameters();
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnFillAllExtensionParameters();
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnFillAllExtensionParameters();
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnFillAllExtensionParameters();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnFillAllExtensionParameters();
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnFillAllExtensionParameters Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnFillAllExtensionParameters();
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnFillAllExtensionParameters Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnFillAllExtensionParameters();
	EndIf;

EndProcedure

// 
Procedure OnClearAllExtemsionParameters() Export

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnClearAllExtemsionParameters();
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnClearAllExtemsionParameters Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnClearAllExtemsionParameters();
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnClearAllExtemsionParameters Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnClearAllExtemsionParameters();
	EndIf;

EndProcedure

// 
Procedure OnSendDataToMaster(DataElement, ItemSend, Recipient) Export

	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnSendDataToMaster(DataElement, ItemSend, Recipient);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		ModuleAddInsInternal.OnSendDataToMaster(DataElement, ItemSend, Recipient);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule(
			"AddInsSaaSInternal");
		ModuleAddInsSaaSInternal.OnSendDataToMaster(DataElement,
			ItemSend, Recipient);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnSendDataToMaster(DataElement, ItemSend, Recipient);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnSendDataToMaster(DataElement, ItemSend, Recipient);
	EndIf;

	InfobaseUpdateInternal.OnSendDataToMaster(DataElement, ItemSend, Recipient);
	UsersInternal.OnSendDataToMaster(DataElement, ItemSend, Recipient);

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnSendDataToMaster(DataElement, ItemSend, Recipient);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnSendDataToMaster(DataElement, ItemSend, Recipient);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnSendDataToMaster Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnSendDataToMaster(DataElement, ItemSend, Recipient);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnSendDataToMaster Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnSendDataToMaster(DataElement, ItemSend, Recipient);
	EndIf;

EndProcedure

// See StandardSubsystemsServer.OnSendDataToSlave.
Procedure OnSendDataToSlave(DataElement, ItemSend, InitialImageCreating, Recipient) Export

	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnSendDataToSlave(DataElement,
			ItemSend, InitialImageCreating, Recipient);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		ModuleAddInsInternal.OnSendDataToSlave(DataElement,
			ItemSend, InitialImageCreating, Recipient);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule(
			"AddInsSaaSInternal");
		ModuleAddInsSaaSInternal.OnSendDataToSlave(DataElement,
			ItemSend, InitialImageCreating, Recipient);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnSendDataToSlave(DataElement,
			ItemSend, InitialImageCreating, Recipient);
	EndIf;

	InfobaseUpdateInternal.OnSendDataToSlave(DataElement,
			ItemSend, InitialImageCreating, Recipient);

	UsersInternal.OnSendDataToSlave(DataElement,
			ItemSend, InitialImageCreating, Recipient);

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnSendDataToSlave(DataElement,
			ItemSend, InitialImageCreating, Recipient);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnSendDataToSlave(DataElement,
			ItemSend, InitialImageCreating, Recipient);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnSendDataToSlave Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnSendDataToSlave(DataElement,
			ItemSend, InitialImageCreating, Recipient);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnSendDataToSlave Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnSendDataToSlave(DataElement,
			ItemSend, InitialImageCreating, Recipient);
	EndIf;

EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromMaster.
Procedure OnReceiveDataFromMaster(DataElement, ItemReceive, SendBack, Sender) Export

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnReceiveDataFromMaster(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnReceiveDataFromMaster(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		ModuleAddInsInternal.OnReceiveDataFromMaster(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule(
			"AddInsSaaSInternal");
		ModuleAddInsSaaSInternal.OnReceiveDataFromMaster(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnReceiveDataFromMaster(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnReceiveDataFromMaster(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnReceiveDataFromMaster(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	UsersInternal.OnReceiveDataFromMaster(DataElement,
		ItemReceive, SendBack, Sender);

	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule(
			"EmailOperationsInternal");
		ModuleEmailOperationsInternal.OnReceiveDataFromMaster(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnReceiveDataFromMaster(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnReceiveDataFromMaster(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnReceiveDataFromMaster Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnReceiveDataFromMaster(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnReceiveDataFromMaster Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnReceiveDataFromMaster(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromSlave.
Procedure OnReceiveDataFromSlave(DataElement, ItemReceive, SendBack, Sender) Export

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnReceiveDataFromMaster(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnReceiveDataFromSlave(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		ModuleAddInsInternal.OnReceiveDataFromSlave(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule(
			"AddInsSaaSInternal");
		ModuleAddInsSaaSInternal.OnReceiveDataFromSlave(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnReceiveDataFromSlave(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnReceiveDataFromSlave(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnReceiveDataFromSlave(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnReceiveDataFromSlave(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	UsersInternal.OnReceiveDataFromSlave(DataElement, ItemReceive, SendBack, Sender);

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnReceiveDataFromSlave(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule(
			"EmailOperationsInternal");
		ModuleEmailOperationsInternal.OnReceiveDataFromSlave(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnReceiveDataFromSlave(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnReceiveDataFromSlave Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnReceiveDataFromSlave(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnReceiveDataFromSlave Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnReceiveDataFromSlave(DataElement,
			ItemReceive, SendBack, Sender);
	EndIf;

EndProcedure

// See StandardSubsystemsServer.AfterGetData.
Procedure AfterGetData(Sender, Cancel, GetFromMasterNode) Export

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.AfterGetData(Sender, Cancel, GetFromMasterNode);
	EndIf;

	UsersInternal.AfterGetData(Sender, Cancel, GetFromMasterNode);

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterGetData(Sender, Cancel, GetFromMasterNode);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().AfterGetData Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.AfterGetData(Sender, Cancel, GetFromMasterNode);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().AfterGetData Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.AfterGetData(Sender, Cancel, GetFromMasterNode);
	EndIf;

EndProcedure

// See SaaSOperationsOverridable.OnEnableSeparationByDataAreas.
Procedure OnEnableSeparationByDataAreas() Export

	If Common.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		ModuleCalendarSchedules = Common.CommonModule("CalendarSchedules");
		ModuleCalendarSchedules.OnEnableSeparationByDataAreas();
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnEnableSeparationByDataAreas();
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnEnableSeparationByDataAreas Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnEnableSeparationByDataAreas();
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnEnableSeparationByDataAreas Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnEnableSeparationByDataAreas();
	EndIf;

EndProcedure

// See CommonOverridable.OnDefineSupportedInterfaceVersions.
Procedure OnDefineSupportedInterfaceVersions(SupportedVersions) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineSupportedInterfaceVersions Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineSupportedInterfaceVersions(SupportedVersions);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnDefineSupportedInterfaceVersions(SupportedVersions);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnDefineSupportedInterfaceVersions(SupportedVersions);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineSupportedInterfaceVersions Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineSupportedInterfaceVersions(SupportedVersions);
	EndIf;

	UsersInternal.OnDefineSupportedInterfaceVersions(SupportedVersions);
	
	If Common.SubsystemExists("StandardSubsystems.DSSElectronicSignatureService") Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleInternal.OnDefineSupportedInterfaceVersions(SupportedVersions);
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart.
Procedure OnAddClientParametersOnStart(Parameters) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnAddClientParametersOnStart Then
		ModuleSaaSTechnology = Common.CommonModule("CloudTechnology");
		CTLVersion = ModuleSaaSTechnology.LibraryVersion();
		If Parameters.SeparatedDataUsageAvailable
		 Or CommonClientServer.CompareVersions(CTLVersion, "2.0.11.0") >= 0 Then
			ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
			ModuleCTLSubsystemsIntegration.OnAddClientParametersOnStart(Parameters);
		EndIf;
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.InformationOnStart") Then
		ModuleInformationOnStart = Common.CommonModule("InformationOnStart");
		ModuleInformationOnStart.OnAddClientParametersOnStart(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		ModuleAccountingAuditInternal.OnAddClientParametersOnStart(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UserReminders") Then
		ModuleUserReminderInternal = Common.CommonModule("UserRemindersInternal");
		ModuleUserReminderInternal.OnAddClientParametersOnStart(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnAddClientParametersOnStart(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnAddClientParametersOnStart(Parameters);
	EndIf;

	InfobaseUpdateInternal.OnAddClientParametersOnStart(Parameters);

	If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleConfigurationUpdate = Common.CommonModule("ConfigurationUpdate");
		ModuleConfigurationUpdate.OnAddClientParametersOnStart(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		ModulePerformanceMonitorInternal.OnAddClientParametersOnStart(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManager = Common.CommonModule("BankManager");
		ModuleBankManager.OnAddClientParametersOnStart(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnAddClientParametersOnStart(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnAddClientParametersOnStart(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.IBBackup") Then
		ModuleIBBackupServer = Common.CommonModule("IBBackupServer");
		ModuleIBBackupServer.OnAddClientParametersOnStart(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UsersSessions") Then
		ModuleIBConnections = Common.CommonModule("IBConnections");
		ModuleIBConnections.OnAddClientParametersOnStart(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
		ModuleMonitoringCenterInternal.OnAddClientParametersOnStart(Parameters);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnAddClientParametersOnStart Then
		ModuleOnlineUserSupportClientServer = Common.CommonModule("OnlineUserSupportClientServer");
		ISLVersion = ModuleOnlineUserSupportClientServer.LibraryVersion();
		If Parameters.SeparatedDataUsageAvailable
		 Or CommonClientServer.CompareVersions(ISLVersion, "2.6.5.0") >= 0 Then
			ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
			ModuleOSLSubsystemsIntegration.OnAddClientParametersOnStart(Parameters);
		EndIf;
	EndIf;

EndProcedure

// See CommonOverridable.OnAddClientParameters.
Procedure OnAddClientParameters(Parameters) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnAddClientParameters Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnAddClientParameters(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		ModuleAddressClassifierInternal.OnAddClientParameters(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnAddClientParameters(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnAddClientParameters(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnAddClientParameters(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleConfigurationUpdate = Common.CommonModule("ConfigurationUpdate");
		ModuleConfigurationUpdate.OnAddClientParameters(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SendSMSMessage") Then
		ModuleSMS = Common.CommonModule("SendSMSMessage");
		ModuleSMS.OnAddClientParameters(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadInternal = Common.CommonModule("GetFilesFromInternetInternal");
		ModuleNetworkDownloadInternal.OnAddClientParameters(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
		ModuleSafeModeManagerInternal.OnAddClientParameters(Parameters);
	EndIf;
	
	UsersInternal.OnAddClientParameters(Parameters);

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnAddClientParameters(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.IBBackup") Then
		ModuleIBBackupServer = Common.CommonModule("IBBackupServer");
		ModuleIBBackupServer.OnAddClientParameters(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UsersSessions") Then
		ModuleIBConnections = Common.CommonModule("IBConnections");
		ModuleIBConnections.OnAddClientParameters(Parameters);
	EndIf;

	StandardSubsystemsServer.OnAddClientParameters(Parameters);

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnAddClientParameters(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnAddClientParameters(Parameters);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnAddClientParameters Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnAddClientParameters(Parameters);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DSSElectronicSignatureService") Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleInternal.OnAddClientParameters(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserReminders") Then
		ModuleUserReminderInternal = Common.CommonModule("UserRemindersInternal");
		ModuleUserReminderInternal.OnAddClientParameters(Parameters);
	EndIf;
	
	If Common.SubsystemExists("IntegrationWith1CDocumentManagementSubsystem") Then
		Parameters.Insert("DMILVersion", InfobaseUpdate.IBVersion("DocumentManagementIntegrationLibrary"));
	EndIf;
	
	If Common.SubsystemExists("ElectronicInteraction") Then
		Parameters.Insert("HasModuleEDLSubsystemsIntegrationClient", 
			Metadata.CommonModules.Find("EDLSubsystemsIntegrationClient") <> Undefined);
	EndIf;
	
EndProcedure

// See CommonOverridable.BeforeStartApplication
Procedure BeforeStartApplication() Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.BeforeStartApplication();
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().BeforeStartApplication Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.BeforeStartApplication();
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().BeforeStartApplication Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.BeforeStartApplication();
	EndIf;

EndProcedure

// See also InfobaseUpdateOverridable.OnDefineSettings
//
// Parameters:
//  Objects - Array of MetadataObject
//
Procedure OnDefineObjectsWithInitialFilling(Objects) Export

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDefineObjectsWithInitialFilling(Objects);
	EndIf;

	UsersInternal.OnDefineObjectsWithInitialFilling(Objects);

	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule(
			"ContactsManagerInternal");
		ModuleContactsManagerInternal.OnDefineObjectsWithInitialFilling(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule(
			"EmailOperationsInternal");
		ModuleEmailOperationsInternal.OnDefineObjectsWithInitialFilling(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnDefineObjectsWithInitialFilling(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnDefineObjectsWithInitialFilling(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnDefineObjectsWithInitialFilling(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnDefineObjectsWithInitialFilling(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SourceDocumentsOriginalsRecording") Then
		ModuleSourceDocumentsOriginalsAccounting = Common.CommonModule("SourceDocumentsOriginalsRecording");
		ModuleSourceDocumentsOriginalsAccounting.OnDefineObjectsWithInitialFilling(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
		ModuleMessageTemplatesInternal.OnDefineObjectsWithInitialFilling(Objects);
	EndIf;
EndProcedure

// See CommonOverridable.OnAddServerNotifications
Procedure OnAddServerNotifications(Notifications) Export
	
	StandardSubsystemsServer.OnAddServerNotifications(Notifications);
	UsersInternal.OnAddServerNotifications(Notifications);
	
	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		ModuleAddInsInternal.OnAddServerNotifications(Notifications);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UsersSessions") Then
		ModuleIBConnections = Common.CommonModule("IBConnections");
		ModuleIBConnections.OnAddServerNotifications(Notifications);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserReminders") Then
		ModuleUserReminderInternal = Common.CommonModule("UserRemindersInternal");
		ModuleUserReminderInternal.OnAddServerNotifications(Notifications);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MachineReadableLettersOfAuthority") Then
		ModuleMachineReadableLettersOfAuthorityFTSInternal = Common.CommonModule("MachineReadableLettersOfAuthorityFTSInternal");
		ModuleMachineReadableLettersOfAuthorityFTSInternal.OnAddServerNotifications(Notifications);
	EndIf;
	
	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnAddServerNotifications Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnAddServerNotifications(Notifications);
	EndIf;
	
	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnAddServerNotifications Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnAddServerNotifications(Notifications);
	EndIf;
	
	If SSLSubsystemsIntegrationCached.EDLSubscriptions().OnAddServerNotifications Then
		ModuleEDLSubsystemsIntegration = Common.CommonModule("EDLSubsystemsIntegration");
		ModuleEDLSubsystemsIntegration.OnAddServerNotifications(Notifications);
	EndIf;
	
EndProcedure

// See CommonOverridable.OnReceiptRecurringClientDataOnServer
Procedure OnReceiptRecurringClientDataOnServer(Parameters, Results) Export
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Try
		StandardSubsystemsServer.OnReceiptRecurringClientDataOnServer(Parameters, Results);
	Except
		ServerNotifications.HandleError(ErrorInfo());
	EndTry;
	ServerNotifications.AddIndicator(Results, StartMoment,
		"StandardSubsystemsServer.OnReceiptRecurringClientDataOnServer");
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Try
		If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
			ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
			ModulePerformanceMonitorInternal.OnReceiptRecurringClientDataOnServer(Parameters, Results);
		EndIf;
	Except
		ServerNotifications.HandleError(ErrorInfo());
	EndTry;
	ServerNotifications.AddIndicator(Results, StartMoment,
		"PerformanceMonitorInternal.OnReceiptRecurringClientDataOnServer");
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Try
		If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
			ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
			ModuleMonitoringCenterInternal.OnReceiptRecurringClientDataOnServer(Parameters, Results);
		EndIf;
	Except
		ServerNotifications.HandleError(ErrorInfo());
	EndTry;
	ServerNotifications.AddIndicator(Results, StartMoment,
		"MonitoringCenterInternal.OnReceiptRecurringClientDataOnServer");
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Try
		If SSLSubsystemsIntegrationCached.EDLSubscriptions().OnReceiptRecurringClientDataOnServer Then
			ModuleEDLSubsystemsIntegration = Common.CommonModule("EDLSubsystemsIntegration");
			ModuleEDLSubsystemsIntegration.OnReceiptRecurringClientDataOnServer(Parameters, Results);
		EndIf;
	Except
		ServerNotifications.HandleError(ErrorInfo());
	EndTry;
	ServerNotifications.AddIndicator(Results, StartMoment,
		"EDLSubsystemsIntegration.OnReceiptRecurringClientDataOnServer");
	
EndProcedure

#EndRegion

#Region Banks

// See BankManagerOverridable.OnDefineBankClassifiersImportSettings
Procedure OnDefineBankClassifiersImportSettings(Settings) Export
	
EndProcedure

#EndRegion

#Region ReportsOptions

// See ReportsOptionsOverridable.OnDefineSettings.
Procedure OnDefineReportsOptionsSettings(Settings) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineReportsOptionsSettings Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineReportsOptionsSettings(Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineReportsOptionsSettings Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineReportsOptionsSettings(Settings);
	EndIf;

EndProcedure

// See ReportsOptionsOverridable.DefineSectionsWithReportOptions.
Procedure OnDefineSectionsWithReportOptions(SectionsList) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineSectionsWithReportOptions Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineSectionsWithReportOptions(SectionsList);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineSectionsWithReportOptions Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineSectionsWithReportOptions(SectionsList);
	EndIf;

EndProcedure

// See ReportsOptionsOverridable.CustomizeReportsOptions.
Procedure OnSetUpReportsOptions(Settings) Export

	If Common.SubsystemExists("StandardSubsystems.UserMonitoring") Then
		ModuleUserMonitoringInternal = Common.CommonModule("UserMonitoringInternal");
		ModuleUserMonitoringInternal.OnSetUpReportsOptions(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Surveys") Then
		ModulePolls = Common.CommonModule("Surveys");
		ModulePolls.OnSetUpReportsOptions(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnSetUpReportsOptions(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnSetUpReportsOptions(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnSetUpReportsOptions(Settings);
	EndIf;

	InfobaseUpdateInternal.OnSetUpReportsOptions(Settings);

	If Common.SubsystemExists("StandardSubsystems.DuplicateObjectsDetection") Then
		ModuleDuplicateObjectsDetection = Common.CommonModule("DuplicateObjectsDetection");
		ModuleDuplicateObjectsDetection.OnSetUpReportsOptions(Settings);
	EndIf;

	UsersInternal.OnSetUpReportsOptions(Settings);

	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
		ModuleSafeModeManagerInternal.OnSetUpReportsOptions(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnSetUpReportsOptions(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnSetUpReportsOptions(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DocumentRecordsReport") Then
		ModuleRegisterRecords = Common.CommonModule("Reports.DocumentRegisterRecords");
		ModuleRegisterRecords.OnSetUpReportsOptions(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		ModulePerformanceMonitorInternal.OnSetUpReportsOptions(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditResult = Common.CommonModule("Reports.AccountingCheckResults");
		ModuleAccountingAuditResult.OnSetUpReportsOptions(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistributionControl = Common.CommonModule("Reports.ReportDistributionControl");
		ModuleReportDistributionControl.OnSetUpReportsOptions(Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnSetUpReportsOptions Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnSetUpReportsOptions(Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnSetUpReportsOptions Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnSetUpReportsOptions(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DSSElectronicSignatureService") Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleInternal.OnSetUpReportsOptions(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnSetUpReportsOptions(Settings);
	EndIf;
	
EndProcedure

// See ReportsOptionsOverridable.RegisterChangesOfReportOptionsKeys.
Procedure OnChangeReportsOptionsKeys(Changes) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnChangeReportsOptionsKeys Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnChangeReportsOptionsKeys(Changes);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnChangeReportsOptionsKeys Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnChangeReportsOptionsKeys(Changes);
	EndIf;

EndProcedure

// See ReportsOptionsOverridable.DefineObjectsWithReportCommands.
Procedure OnDefineObjectsWithReportCommands(Objects) Export

	If Common.SubsystemExists("StandardSubsystems.Surveys") Then
		ModulePolls = Common.CommonModule("Surveys");
		ModulePolls.OnDefineObjectsWithReportCommands(Objects);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineObjectsWithReportCommands Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineObjectsWithReportCommands(Objects);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineObjectsWithReportCommands Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineObjectsWithReportCommands(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureCertificates = Common.CommonModule("Reports.DigitalSignatureCertificates");
		ModuleDigitalSignatureCertificates.OnDefineObjectsWithReportCommands(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DSSElectronicSignatureService") Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleInternal.OnDefineObjectsWithReportCommands(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleVolumeIntegrityCheck = Common.CommonModule("Reports.VolumeIntegrityCheck");
		ModuleVolumeIntegrityCheck.OnDefineObjectsWithReportCommands(Objects);
		
		ModuleIrrelevantFilesVolume = Common.CommonModule("Reports.IrrelevantFilesVolume");
		ModuleIrrelevantFilesVolume.OnDefineObjectsWithReportCommands(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistributionControl = Common.CommonModule("Reports.ReportDistributionControl");
		ModuleReportDistributionControl.OnDefineObjectsWithReportCommands(Objects);
	EndIf;
	
EndProcedure

// See ReportsOptionsOverridable.BeforeAddReportCommands.
Procedure BeforeAddReportCommands(ReportsCommands, Parameters, StandardProcessing) Export

	DataProcessors.EventLog.BeforeAddReportCommands(ReportsCommands, Parameters, StandardProcessing);
	
	If Common.SubsystemExists("StandardSubsystems.DocumentRecordsReport") Then
		ModuleRegisterRecords = Common.CommonModule("Reports.DocumentRegisterRecords");
		ModuleRegisterRecords.BeforeAddReportCommands(ReportsCommands, Parameters, StandardProcessing);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditResult = Common.CommonModule("Reports.AccountingCheckResults");
		ModuleAccountingAuditResult.BeforeAddReportCommands(ReportsCommands, Parameters,
			StandardProcessing);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UserMonitoring") Then
		ModuleUserMonitoringInternal = Common.CommonModule("UserMonitoringInternal");
		ModuleUserMonitoringInternal.BeforeAddReportCommands(ReportsCommands, Parameters,
			StandardProcessing);
	EndIf;

	UsersInternal.BeforeAddReportCommands(ReportsCommands, Parameters, StandardProcessing);

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.BeforeAddReportCommands(ReportsCommands, Parameters,
			StandardProcessing);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().BeforeAddReportCommands Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.BeforeAddReportCommands(ReportsCommands, Parameters, StandardProcessing);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().BeforeAddReportCommands Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.BeforeAddReportCommands(ReportsCommands, Parameters, StandardProcessing);
	EndIf; 
	
EndProcedure

// See ReportsOverridable.OnDefineSelectionParameters.
Procedure OnDefineSelectionParametersReportsOptions(Form, SettingProperties) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineSelectionParametersReportsOptions Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineSelectionParametersReportsOptions(Form, SettingProperties);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineSelectionParametersReportsOptions Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineSelectionParametersReportsOptions(Form, SettingProperties);
	EndIf;

EndProcedure

// See ReportsOverridable.OnCreateAtServer.
Procedure OnCreateAtServerReportsOptions(Form, Cancel, StandardProcessing) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnCreateAtServerReportsOptions Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnCreateAtServerReportsOptions(Form, Cancel, StandardProcessing);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnCreateAtServerReportsOptions Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnCreateAtServerReportsOptions(Form, Cancel, StandardProcessing);
	EndIf;

EndProcedure

// See ReportsOverridable.BeforeLoadVariantAtServer.
Procedure BeforeLoadVariantAtServer(Form, NewDCSettings) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().BeforeLoadVariantAtServer Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.BeforeLoadVariantAtServer(Form, NewDCSettings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().BeforeLoadVariantAtServer Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.BeforeLoadVariantAtServer(Form, NewDCSettings);
	EndIf;

EndProcedure

#EndRegion

#Region AddIns

// Parameters:
//  Components - ValueTable - List of add-ins used in the configuration:
//      * Id          - String - Add-in ID (a 50-character-long string).
//      * AutoUpdate - Boolean - Autoupdate flag.
//
Procedure OnDefineUsedAddIns(Components) Export
	
	If SSLSubsystemsIntegrationCached.PELSubscriptions().OnDefineUsedAddIns Then
		ModulePELSubsystemsIntegration = Common.CommonModule("PELSubsystemsIntegration");
		ModulePELSubsystemsIntegration.OnDefineUsedAddIns(Components);
	EndIf;
	
	If SSLSubsystemsIntegrationCached.EDLSubscriptions().OnDefineUsedAddIns Then
		ModuleEDLSubsystemsIntegration = Common.CommonModule("EDLSubsystemsIntegration");
		ModuleEDLSubsystemsIntegration.OnDefineUsedAddIns(Components);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnDefineUsedAddIns(Components);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnDefineUsedAddIns(Components);
	EndIf;

EndProcedure

#EndRegion

#Region BatchEditObjects

// See BatchEditObjectsOverridable.OnDefineObjectsWithEditableAttributes.
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export

	StandardSubsystemsServer.OnDefineObjectsWithEditableAttributes(Objects);
	UsersInternal.OnDefineObjectsWithEditableAttributes(Objects);

	If Common.SubsystemExists("StandardSubsystems.Surveys") Then
		ModulePolls = Common.CommonModule("Surveys");
		ModulePolls.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManager = Common.CommonModule("BankManager");
		ModuleBankManager.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		ModuleAddInsInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule(
			"AddInsSaaSInternal");
		ModuleAddInsSaaSInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UserNotes") Then
		ModuleUserNotesInternal = Common.CommonModule("UserNotesInternal");
		ModuleUserNotesInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule(
			"ContactsManagerInternal");
		ModuleContactsManagerInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule(
			"EmailOperationsInternal");
		ModuleEmailOperationsInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineObjectsWithEditableAttributes Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineObjectsWithEditableAttributes Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DSSElectronicSignatureService") Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
EndProcedure

// See BatchEditObjectsOverridable.OnDefineEditableObjectAttributes.
Procedure OnDefineEditableObjectAttributes(Object, AttributesToEdit, AttributesToSkip) Export
	
	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineEditableObjectAttributes Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineEditableObjectAttributes(Object, AttributesToEdit, AttributesToSkip);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineEditableObjectAttributes Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineEditableObjectAttributes(Object, AttributesToEdit, AttributesToSkip);
	EndIf;
	
EndProcedure

#EndRegion

#Region Period_Closing_Dates

// See PeriodClosingDatesOverridable.OnFillPeriodClosingDatesSections.
Procedure OnFillPeriodClosingDatesSections(Sections) Export

	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnFillPeriodClosingDatesSections(Sections);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnFillPeriodClosingDatesSections Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnFillPeriodClosingDatesSections(Sections);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnFillPeriodClosingDatesSections Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnFillPeriodClosingDatesSections(Sections);
	EndIf;

EndProcedure

// See PeriodClosingDatesOverridable.FillDataSourcesForPeriodClosingCheck.
Procedure OnFillDataSourcesForPeriodClosingCheck(DataSources) Export

	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnFillDataSourcesForPeriodClosingCheck(DataSources);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnFillDataSourcesForPeriodClosingCheck Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnFillDataSourcesForPeriodClosingCheck(DataSources);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnFillDataSourcesForPeriodClosingCheck Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnFillDataSourcesForPeriodClosingCheck(DataSources);
	EndIf;

EndProcedure

#EndRegion

#Region AdditionalReportsAndDataProcessors

// Sets an operation mode for an additional report or a data processor.
//
// Parameters:
//   SuppliedDataProcessor - CatalogRef.SuppliedAdditionalReportsAndDataProcessors - an additional report
//                         or a data processor that requires setting an operation mode.
//   AttachmentMode      - DefinedType.SafeMode - operation mode of an additional report or a data processor.
//
Procedure OnSetAdditionalReportOrDataProcessorAttachmentModeInDataArea(SuppliedDataProcessor,
	AttachmentMode) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnSetAdditionalReportOrDataProcessorAttachmentModeInDataArea Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnSetAdditionalReportOrDataProcessorAttachmentModeInDataArea(
			SuppliedDataProcessor, AttachmentMode);
	EndIf;

EndProcedure

#Region AdditionalReportsAndDataProcessorsForInternalUsage

// Call to determine whether the current user has right to add an additional
// report or data processor to a data area.
//
// Parameters:
//  AdditionalDataProcessor - CatalogObject.AdditionalReportsAndDataProcessors - catalog item
//                            written by user.
//  Result               - Boolean - Indicates whether the required rights are granted.
//  StandardProcessing    - Boolean - flag specifying whether
//                            standard processing is used to validate rights.
//
Procedure OnCheckInsertRight(Val AdditionalDataProcessor, Result, StandardProcessing) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then

		ModuleAdditionalReportsAndDataProcessorsStandaloneMode = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsStandaloneMode");
		ModuleAdditionalReportsAndDataProcessorsStandaloneMode.OnCheckInsertRight(AdditionalDataProcessor,
			Result, StandardProcessing);

		If StandardProcessing Then
			ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule(
				"AdditionalReportsAndDataProcessorsSaaS");
			ModuleAdditionalReportsAndDataProcessorsSaaS.OnCheckInsertRight(AdditionalDataProcessor,
				Result, StandardProcessing);
		EndIf;

	EndIf;

EndProcedure

// Called to check whether an additional report or data processor can be imported from file.
//
// Parameters:
//  AdditionalDataProcessor - CatalogRef.AdditionalReportsAndDataProcessors,
//  Result - Boolean - Indicates whether additional reports or data processors can be
//    imported from files.
//  StandardProcessing - Boolean - Indicates whether
//    standard processing checks if additional reports or data processors can be imported from files.
//
Procedure OnCheckCanImportDataProcessorFromFile(Val AdditionalDataProcessor, Result, StandardProcessing) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then

		ModuleAdditionalReportsAndDataProcessorsStandaloneMode = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsStandaloneMode");
		ModuleAdditionalReportsAndDataProcessorsStandaloneMode.OnCheckCanImportDataProcessorFromFile(
			AdditionalDataProcessor, Result, StandardProcessing);

		If StandardProcessing Then
			ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule(
				"AdditionalReportsAndDataProcessorsSaaS");
			ModuleAdditionalReportsAndDataProcessorsSaaS.OnCheckCanImportDataProcessorFromFile(
				AdditionalDataProcessor, Result, StandardProcessing);
		EndIf;

	EndIf;

EndProcedure

// Called to check whether an additional report or data processor can be exported to a file.
//
// Parameters:
//  AdditionalDataProcessor - CatalogRef.AdditionalReportsAndDataProcessors,
//  Result - Boolean - Indicates whether additional reports or data processors can be
//    exported to files.
//  StandardProcessing - Boolean - Indicates whether
//    standard processing checks if additional reports or data processors can be exported to files.
//
Procedure OnCheckCanExportDataProcessorToFile(Val AdditionalDataProcessor, Result, StandardProcessing) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then

		ModuleAdditionalReportsAndDataProcessorsStandaloneMode = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsStandaloneMode");
		ModuleAdditionalReportsAndDataProcessorsStandaloneMode.OnCheckCanExportDataProcessorToFile(
			AdditionalDataProcessor, Result, StandardProcessing);

		If StandardProcessing Then
			ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule(
				"AdditionalReportsAndDataProcessorsSaaS");
			ModuleAdditionalReportsAndDataProcessorsSaaS.OnCheckCanExportDataProcessorToFile(
				AdditionalDataProcessor, Result, StandardProcessing);
		EndIf;

	EndIf;

EndProcedure

// Fills additional report or data processor publication kinds that cannot be used
// in the current infobase model.
//
// Parameters:
//  NotAvailablePublicationKinds - Array of String
//
Procedure OnFillUnavailablePublicationKinds(Val NotAvailablePublicationKinds) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then

		ModuleAdditionalReportsAndDataProcessorsStandaloneMode = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsStandaloneMode");
		ModuleAdditionalReportsAndDataProcessorsStandaloneMode.OnFillUnavailablePublicationKinds(
			NotAvailablePublicationKinds);

		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsSaaS");
		ModuleAdditionalReportsAndDataProcessorsSaaS.OnFillUnavailablePublicationKinds(
			NotAvailablePublicationKinds);

	EndIf;

EndProcedure

// It is called from the BeforeWriteEvent of catalog
//  AdditionalReportsAndDataProcessors. Validates changes to the catalog item
//  attributes for additional data processors retrieved
//  from the additional data processor directory from the service manager.
//
// Parameters:
//  Source - CatalogObject.AdditionalReportsAndDataProcessors,
//  Cancel - Boolean - Indicates whether writing a catalog item must be canceled.
//
Procedure BeforeWriteAdditionalDataProcessor(Source, Cancel) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then

		ModuleAdditionalReportsAndDataProcessorsStandaloneMode = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsStandaloneMode");
		ModuleAdditionalReportsAndDataProcessorsStandaloneMode.BeforeWriteAdditionalDataProcessor(Source, Cancel);

		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsSaaS");
		ModuleAdditionalReportsAndDataProcessorsSaaS.BeforeWriteAdditionalDataProcessor(Source, Cancel);

	EndIf;

EndProcedure

// Called from the BeforeDelete event of the AdditionalReportsAndDataProcessors catalog.
//
// Parameters:
//  Source - CatalogObject.AdditionalReportsAndDataProcessors,
//  Cancel - Boolean - Indicates whether the catalog item deletion from the infobase must be canceled.
//
Procedure BeforeDeleteAdditionalDataProcessor(Source, Cancel) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsSaaS");
		ModuleAdditionalReportsAndDataProcessorsSaaS.BeforeDeleteAdditionalDataProcessor(Source, Cancel);
	EndIf;

EndProcedure

// Called to get registration data for a new additional report
// or data processor.
//
Procedure OnGetRegistrationData(Object, RegistrationData, StandardProcessing) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsSaaS");
		ModuleAdditionalReportsAndDataProcessorsSaaS.OnGetRegistrationData(Object,
			RegistrationData, StandardProcessing);
	EndIf;

EndProcedure

// Called to attach an external data processor.
//
// Parameters:
//  Ref - CatalogRef.AdditionalReportsAndDataProcessors,
//  StandardProcessing - Boolean - Indicates whether the standard processing is required to attach an
//    external data processor,
//  Result - String - a name of the attached external report or data processor (provided that the
//    handler StandardProcessing parameter is set to False).
//
Procedure OnAttachExternalDataProcessor(Val Ref, StandardProcessing, Result) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsSaaS");
		ModuleAdditionalReportsAndDataProcessorsSaaS.OnAttachExternalDataProcessor(Ref, StandardProcessing,
			Result);
	EndIf;

EndProcedure

// Called to create an external data processor object.
//
// Parameters:
//  Ref - CatalogRef.AdditionalReportsAndDataProcessors,
//  StandardProcessing - Boolean - Indicates whether the standard processing is required to attach an
//    external data processor.
//  Result - ExternalDataProcessor
//            - ExternalReport - an object of the attached external report or
//    data processor (provided that the handler StandardProcessing parameter is set to False).
//
Procedure OnCreateExternalDataProcessor(Val Ref, StandardProcessing, Result) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsSaaS");
		ModuleAdditionalReportsAndDataProcessorsSaaS.OnCreateExternalDataProcessor(Ref, StandardProcessing,
			Result);
	EndIf;

EndProcedure

// Called before writing changes of a scheduled job of additional reports and data processors in SaaS.
//
// Parameters:
//   Object - CatalogObject.AdditionalReportsAndDataProcessors - an object of an additional report or a data processor.
//   Command - CatalogTabularSectionRow.AdditionalReportsAndDataProcessors.Commands - a command details.
//   Job - ScheduledJob
//           - ValueTableRow - Scheduled job details.
//       See the ScheduledJobsServer.Job() function for the return value details.
//   Changes - Structure - Job attribute values to be modified.
//       See details of the second parameter of the ScheduledJobsServer.ChangeJob procedure.
//       If the value is Undefined, the scheduled job stays unchanged.
//
Procedure BeforeUpdateJob(Object, Command, Job, Changes) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsSaaS");
		ModuleAdditionalReportsAndDataProcessorsSaaS.BeforeUpdateJob(Object, Command, Job, Changes);
	EndIf;

EndProcedure

#EndRegion

#EndRegion

#Region ImportDataFromFile

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport.
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export

	StandardSubsystemsServer.OnDefineCatalogsForDataImport(CatalogsToImport);
	UsersInternal.OnDefineCatalogsForDataImport(CatalogsToImport);

	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule(
			"ContactsManagerInternal");
		ModuleContactsManagerInternal.OnDefineCatalogsForDataImport(
			CatalogsToImport);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManager = Common.CommonModule("BankManager");
		ModuleBankManager.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineCatalogsForDataImport Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SourceDocumentsOriginalsRecording") Then
		ModuleSourceDocumentsOriginalsAccounting = Common.CommonModule("SourceDocumentsOriginalsRecording");
		ModuleSourceDocumentsOriginalsAccounting.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineCatalogsForDataImport Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DSSElectronicSignatureService") Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleInternal.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;
	
EndProcedure

#EndRegion

#Region ObjectAttributesLock

// See ObjectAttributesLockOverridable.OnDefineObjectsWithLockedAttributes.
Procedure OnDefineObjectsWithLockedAttributes(Objects) Export

	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule(
			"ContactsManagerInternal");
		ModuleContactsManagerInternal.OnDefineObjectsWithLockedAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnDefineObjectsWithLockedAttributes(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnDefineObjectsWithLockedAttributes(Objects);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineObjectsWithLockedAttributes Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineObjectsWithLockedAttributes(Objects);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineObjectsWithLockedAttributes Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineObjectsWithLockedAttributes(Objects);
	EndIf;

EndProcedure

#EndRegion

#Region ODataInterface

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport.
Procedure OnFillTypesExcludedFromExportImportOData(TypesToExclude) Export

	OnFillTypesExcludedFromExportImport(TypesToExclude);

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnFillTypesExcludedFromExportImportOData Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnFillTypesExcludedFromExportImportOData(TypesToExclude);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnFillTypesExcludedFromExportImportOData Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnFillTypesExcludedFromExportImportOData(TypesToExclude);
	EndIf;

EndProcedure

// See ODataInterfaceOverridable.OnPopulateDependantTablesForODataImportExport
Procedure OnPopulateDependantTablesForODataImportExport(Tables) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		ModuleAccountingAuditInternal.OnPopulateDependantTablesForODataImportExport(Tables);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.FilesOperationsSaaS") Then
		ModuleFilesOperationsInternalSaaS = Common.CommonModule("FilesOperationsInternalSaaS");
		ModuleFilesOperationsInternalSaaS.OnPopulateDependantTablesForODataImportExport(Tables);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectsDeletionInternal = Common.CommonModule("MarkedObjectsDeletionInternal");
		ModuleMarkedObjectsDeletionInternal.OnPopulateDependantTablesForODataImportExport(Tables);
	EndIf;
	
	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnPopulateDependantTablesForODataImportExport Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnPopulateDependantTablesForODataImportExport(Tables);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnPopulateDependantTablesForODataImportExport Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnPopulateDependantTablesForODataImportExport(Tables);
	EndIf;
	
EndProcedure

#EndRegion

#Region AccountingAudit

// See AccountingAuditOverridable.OnDefineChecks.
Procedure OnDefineChecks(ChecksGroups, Checks) Export

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnDefineChecks(ChecksGroups, Checks);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule(
			"ContactsManagerInternal");
		ModuleContactsManagerInternal.OnDefineChecks(ChecksGroups, Checks);
	EndIf;
	
	InfobaseUpdateInternal.OnDefineChecks(ChecksGroups, Checks);

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineChecks Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineChecks(ChecksGroups, Checks);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineChecks Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineChecks(ChecksGroups, Checks);
	EndIf;
	

EndProcedure

// Allows to define the list of objects that must be ignored when executing
// system checks.
//
// Parameters:
//  Objects - Array of MetadataObject - a list of objects.
//
Procedure OnDefineObjectsToExcludeFromCheck(Objects) Export
	
	StandardSubsystemsServer.OnDefineObjectsToExcludeFromCheck(Objects);
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnDefineObjectsToExcludeFromCheck(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnDefineObjectsToExcludeFromCheck(Objects);
	EndIf;

EndProcedure

#EndRegion

#Region UserReminders

// See UserRemindersOverridable.OnFillSourceAttributesListWithReminderDates.
Procedure OnFillSourceAttributesListWithReminderDates(Source, AttributesWithDates) Export

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnFillSourceAttributesListWithReminderDates(Source,
			AttributesWithDates);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UserNotes") Then
		ModuleUserNotesInternal = Common.CommonModule("UserNotesInternal");
		ModuleUserNotesInternal.OnFillSourceAttributesListWithReminderDates(Source,
			AttributesWithDates);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnFillSourceAttributesListWithReminderDates Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnFillSourceAttributesListWithReminderDates(Source,
			AttributesWithDates);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnFillSourceAttributesListWithReminderDates Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnFillSourceAttributesListWithReminderDates(Source,
			AttributesWithDates);
	EndIf;

EndProcedure

#EndRegion

#Region ItemOrderSetup

Procedure BeforeItemMoved(ItemToMove, AdjacentElement, Direction, ErrorText, StandardProcessing) Export
	
	If Common.SubsystemExists("StandardSubsystems.SourceDocumentsOriginalsRecording") Then
		ModuleSourceDocumentsOriginalsAccounting = Common.CommonModule("SourceDocumentsOriginalsRecording");
		ModuleSourceDocumentsOriginalsAccounting.BeforeItemMoved(
			ItemToMove, AdjacentElement, Direction, ErrorText, StandardProcessing);
	EndIf;
	
EndProcedure

#EndRegion

#Region DataExchange

// See DataExchangeOverridable.OnSetUpSubordinateDIBNode.
Procedure OnSetUpSubordinateDIBNode() Export

	UsersInternal.OnSetUpSubordinateDIBNode();

	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule(
			"EmailOperationsInternal");
		ModuleEmailOperationsInternal.OnSetUpSubordinateDIBNode();
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnSetUpSubordinateDIBNode();
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		ModuleScheduledJobsInternal.OnSetUpSubordinateDIBNode();
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnSetUpSubordinateDIBNode();
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnSetUpSubordinateDIBNode Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnSetUpSubordinateDIBNode();
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnSetUpSubordinateDIBNode Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnSetUpSubordinateDIBNode();
	EndIf;

EndProcedure

#EndRegion

#Region IBVersionUpdate

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export

	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		ModuleAddressClassifierInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Surveys") Then
		ModulePolls = Common.CommonModule("Surveys");
		ModulePolls.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		ModuleAddInsInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		ModuleWorkSchedules.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.InformationOnStart") Then
		ModuleInformationOnStart = Common.CommonModule("InformationOnStart");
		ModuleInformationOnStart.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		ModuleCalendarSchedules = Common.CommonModule("CalendarSchedules");
		ModuleCalendarSchedules.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule(
			"ContactsManagerInternal");
		ModuleContactsManagerInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		ModuleAccountingAuditInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MachineReadableLettersOfAuthority") Then
		ModuleMachineReadableLettersOfAuthorityFTSInternal = Common.CommonModule("MachineReadableLettersOfAuthorityFTSInternal");
		ModuleMachineReadableLettersOfAuthorityFTSInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnAddUpdateHandlers(Handlers);
	EndIf;

	InfobaseUpdateInternal.OnAddUpdateHandlers(Handlers);

	If Common.SubsystemExists("StandardSubsystems.Conversations") Then
		ModuleConversationsInternal =  Common.CommonModule("ConversationsInternal");
		ModuleConversationsInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		ModulePerformanceMonitorInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FullTextSearch") Then
		ModuleFullTextSearchServer = Common.CommonModule("FullTextSearchServer");
		ModuleFullTextSearchServer.OnAddUpdateHandlers(Handlers);
	EndIf;

	UsersInternal.OnAddUpdateHandlers(Handlers);

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule("AddInsSaaSInternal");
		ModuleAddInsSaaSInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule(
			"EmailOperationsInternal");
		ModuleEmailOperationsInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		ModuleScheduledJobsInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

	StandardSubsystemsServer.OnAddUpdateHandlers(Handlers);

	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectsDeletionInternal = Common.CommonModule("MarkedObjectsDeletionInternal");
		ModuleMarkedObjectsDeletionInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.TotalsAndAggregatesManagement") Then
		ModuleTotalsAndAggregatesInternal = Common.CommonModule(
			"TotalsAndAggregatesManagementInternal");
		ModuleTotalsAndAggregatesInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SourceDocumentsOriginalsRecording") Then
		ModuleSourceDocumentsOriginalsAccounting = Common.CommonModule("SourceDocumentsOriginalsRecording");
		ModuleSourceDocumentsOriginalsAccounting.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
		ModuleMonitoringCenterInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
		ModuleMessageTemplatesInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnAddUpdateHandlers(Handlers);
	EndIf;

EndProcedure

// See InfobaseUpdateSSL.OnAddApplicationMigrationHandlers.
Procedure OnAddApplicationMigrationHandlers(Handlers) Export
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnAddApplicationMigrationHandlers(Handlers);
	EndIf;
	
EndProcedure

// See InfobaseUpdateSSL.AfterUpdateInfobase.
Procedure AfterUpdateInfobase(Val PreviousVersion, Val CurrentVersion, Val CompletedHandlers,
	OutputUpdatesDetails, ExclusiveMode) Export
	
	UsersInternal.AfterUpdateInfobase(PreviousVersion, CurrentVersion,
		CompletedHandlers, OutputUpdatesDetails, ExclusiveMode);
	
	If Common.SubsystemExists("StandardSubsystems.InformationOnStart") Then
		ModuleInformationOnStart = Common.CommonModule("InformationOnStart");
		ModuleInformationOnStart.AfterUpdateInfobase(PreviousVersion, CurrentVersion,
			CompletedHandlers, OutputUpdatesDetails, ExclusiveMode);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.TotalsAndAggregatesManagement") Then
		ModuleTotalsAndAggregatesInternal = Common.CommonModule(
			"TotalsAndAggregatesManagementInternal");
		ModuleTotalsAndAggregatesInternal.AfterUpdateInfobase(PreviousVersion, CurrentVersion,
			CompletedHandlers, OutputUpdatesDetails, ExclusiveMode);
	EndIf;

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule(
			"InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.AfterUpdateInfobase(PreviousVersion,
			CurrentVersion, CompletedHandlers, OutputUpdatesDetails, ExclusiveMode);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterUpdateInfobase(PreviousVersion, CurrentVersion,
			CompletedHandlers, OutputUpdatesDetails, ExclusiveMode);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().AfterUpdateInfobase Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.AfterUpdateInfobase(PreviousVersion, CurrentVersion,
			CompletedHandlers, OutputUpdatesDetails, ExclusiveMode);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().AfterUpdateInfobase Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.AfterUpdateInfobase(PreviousVersion, CurrentVersion,
			CompletedHandlers, OutputUpdatesDetails, ExclusiveMode);
	EndIf;

EndProcedure

// With it, you can override update priority. The default priority order is stored in the IBUpdateInfo constant.
// For example, CTL can override update priority for each data area in SaaS mode.
//
// Parameters:
//  Priority - String - a new update priority value (return value):
//              "UserWork" - user processing priority (single thread);
//              "DataProcessing" - data processing priority (several threads);
//              Another - apply the priority as specified in the IBUpdateInfo constant (do not override).
//
Procedure OnGetUpdatePriority(Priority) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule(
			"InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnGetUpdatePriority(Priority);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnGetUpdatePriority Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnGetUpdatePriority(Priority);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnGetUpdatePriority Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnGetUpdatePriority(Priority);
	EndIf;

EndProcedure

// See InfobaseUpdateOverridable.OnPopulateObjectsPlannedForDeletion.
Procedure OnPopulateObjectsPlannedForDeletion(Objects) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnPopulateObjectsPlannedForDeletion(Objects);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnPopulateObjectsPlannedForDeletion Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnPopulateObjectsPlannedForDeletion(Objects);
	EndIf;
	
	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnPopulateObjectsPlannedForDeletion Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnPopulateObjectsPlannedForDeletion(Objects);
	EndIf;
	
EndProcedure

#EndRegion

#Region Print

// See PrintManagementOverridable.OnDefinePrintSettings.
Procedure OnDefinePrintSettings(PrintSettings) Export
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnDefinePrintSettings(PrintSettings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MachineReadableLettersOfAuthority") Then
		ModuleMachineReadableLettersOfAuthorityFTSInternal = Common.CommonModule("MachineReadableLettersOfAuthorityFTSInternal");
		ModuleMachineReadableLettersOfAuthorityFTSInternal.OnDefinePrintSettings(PrintSettings);
	EndIf;
	
	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefinePrintSettings Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefinePrintSettings(PrintSettings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefinePrintSettings Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefinePrintSettings(PrintSettings);
	EndIf;
	
EndProcedure

// See PrintManagementOverridable.BeforeAddPrintCommands.
Procedure BeforeAddPrintCommands(FormName, PrintCommands, StandardProcessing) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().BeforeAddPrintCommands Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.BeforeAddPrintCommands(FormName, PrintCommands, StandardProcessing);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().BeforeAddPrintCommands Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.BeforeAddPrintCommands(FormName, PrintCommands, StandardProcessing);
	EndIf;

EndProcedure

// See PrintManagementOverridable.OnGetPrintCommandListSettings.
Procedure OnGetPrintCommandListSettings(ListSettings) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnGetPrintCommandListSettings Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnGetPrintCommandListSettings(ListSettings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnGetPrintCommandListSettings Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnGetPrintCommandListSettings(ListSettings);
	EndIf;

EndProcedure

// See PrintManagementOverridable.OnPrint.
Procedure OnPrint(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnPrint Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnPrint(
			ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnPrint Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnPrint(
			ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters);
	EndIf;

EndProcedure

// See PrintManagementOverridable.BeforeSendingByEmail.
Procedure BeforeSendingByEmail(SendOptions, OutputParameters, PrintObjects, PrintForms) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().BeforeSendingByEmail Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.BeforeSendingByEmail(SendOptions, OutputParameters, PrintObjects,
			PrintForms);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().BeforeSendingByEmail Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.BeforeSendingByEmail(SendOptions, OutputParameters, PrintObjects,
			PrintForms);
	EndIf;

EndProcedure

// See PrintManagementOverridable.OnGetSignaturesAndSeals.
Procedure OnGetSignaturesAndSeals(Var_Documents, SignaturesAndSeals) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnGetSignaturesAndSeals Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnGetSignaturesAndSeals(Var_Documents, SignaturesAndSeals);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnGetSignaturesAndSeals Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnGetSignaturesAndSeals(Var_Documents, SignaturesAndSeals);
	EndIf;

EndProcedure

// See PrintManagementOverridable.PrintDocumentsOnCreateAtServer.
Procedure PrintDocumentsOnCreateAtServer(Form, Cancel, StandardProcessing) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().PrintDocumentsOnCreateAtServer Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.PrintDocumentsOnCreateAtServer(Form, Cancel, StandardProcessing);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().PrintDocumentsOnCreateAtServer Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.PrintDocumentsOnCreateAtServer(Form, Cancel, StandardProcessing);
	EndIf;
	
	If SSLSubsystemsIntegrationCached.EDLSubscriptions().PrintDocumentsOnCreateAtServer Then
		ModuleEDLSubsystemsIntegration = Common.CommonModule("EDLSubsystemsIntegration");
		ModuleEDLSubsystemsIntegration.PrintDocumentsOnCreateAtServer(Form, Cancel, StandardProcessing);
	EndIf;

EndProcedure

// See PrintManagementOverridable.PrintDocumentsOnImportDataFromSettingsAtServer.
Procedure PrintDocumentsOnImportDataFromSettingsAtServer(Form, Settings) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().PrintDocumentsOnImportDataFromSettingsAtServer Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.PrintDocumentsOnImportDataFromSettingsAtServer(Form, Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().PrintDocumentsOnImportDataFromSettingsAtServer Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.PrintDocumentsOnImportDataFromSettingsAtServer(Form, Settings);
	EndIf;

EndProcedure

// See PrintManagementOverridable.PrintDocumentsOnSaveDataInSettingsAtServer.
Procedure PrintDocumentsOnSaveDataInSettingsAtServer(Form, Settings) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().PrintDocumentsOnSaveDataInSettingsAtServer Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.PrintDocumentsOnSaveDataInSettingsAtServer(Form, Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().PrintDocumentsOnSaveDataInSettingsAtServer Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.PrintDocumentsOnSaveDataInSettingsAtServer(Form, Settings);
	EndIf;

EndProcedure

// See PrintManagementOverridable.PrintDocumentsOnExecuteCommand.
Procedure PrintDocumentsOnExecuteCommand(Form, AdditionalParameters) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().PrintDocumentsOnExecuteCommand Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.PrintDocumentsOnExecuteCommand(Form, AdditionalParameters);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().PrintDocumentsOnExecuteCommand Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.PrintDocumentsOnExecuteCommand(Form, AdditionalParameters);
	EndIf;
	
	If SSLSubsystemsIntegrationCached.EDLSubscriptions().PrintDocumentsOnExecuteCommand Then
		ModuleEDLSubsystemsIntegration = Common.CommonModule("EDLSubsystemsIntegration");
		ModuleEDLSubsystemsIntegration.PrintDocumentsOnExecuteCommand(Form, AdditionalParameters);
	EndIf;

EndProcedure

// See PrintManagementOverridable.OnDefinePrintDataSources
Procedure OnDefinePrintDataSources(Object, PrintDataSources) Export
	
	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefinePrintDataSources Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefinePrintDataSources(Object, PrintDataSources);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefinePrintDataSources Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefinePrintDataSources(Object, PrintDataSources);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnDefinePrintDataSources(Object, PrintDataSources);
	EndIf;
	
EndProcedure

// See PrintManagementOverridable.WhenPreparingPrintData
Procedure WhenPreparingPrintData(DataSources, ExternalDataSets, DataCompositionSchemaId, LanguageCode,
	AdditionalParameters) Export
	
	If Common.SubsystemExists("StandardSubsystems.ObjectPresentationDeclension") Then
		ModuleObjectsPresentationsDeclension = Common.CommonModule("ObjectPresentationDeclension");
		ModuleObjectsPresentationsDeclension.WhenPreparingPrintData(DataSources, ExternalDataSets,
			DataCompositionSchemaId, LanguageCode, AdditionalParameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.WhenPreparingPrintData(DataSources, ExternalDataSets,
			DataCompositionSchemaId, LanguageCode, AdditionalParameters);
	EndIf;	
	
	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().WhenPreparingPrintData Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.WhenPreparingPrintData(DataSources, ExternalDataSets,
			DataCompositionSchemaId, LanguageCode, AdditionalParameters);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().WhenPreparingPrintData Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.WhenPreparingPrintData(DataSources, ExternalDataSets,
			 DataCompositionSchemaId, LanguageCode, AdditionalParameters);
	EndIf;
	
EndProcedure

#Region PrintingForInternalUsage

Procedure OnPrepareTemplateListInOfficeDocumentServerFormat(TemplatesList) Export

	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnPrepareTemplateListInOfficeDocumentServerFormat(
			TemplatesList);
	EndIf;

EndProcedure

#EndRegion

#EndRegion

#Region AttachableCommands

// See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export

	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ItemOrderSetup") Then
		ModuleItemOrdering = Common.CommonModule("ItemOrderSetup");
		ModuleItemOrdering.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DuplicateObjectsDetection") Then
		ModuleDuplicateObjectsDetection = Common.CommonModule("DuplicateObjectsDetection");
		ModuleDuplicateObjectsDetection.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.BatchEditObjects") Then
		ModuleBatchObjectsModification = Common.CommonModule("BatchEditObjects");
		ModuleBatchObjectsModification.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineAttachableCommandsKinds Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineAttachableCommandsKinds Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;
	
	If SSLSubsystemsIntegrationCached.EDLSubscriptions().OnDefineAttachableCommandsKinds Then
		ModuleEDLSubsystemsIntegration = Common.CommonModule("EDLSubsystemsIntegration");
		ModuleEDLSubsystemsIntegration.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectsDeletionInternal = Common.CommonModule("MarkedObjectsDeletionInternal");
		ModuleMarkedObjectsDeletionInternal.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SubordinationStructure") Then
		ModuleHierarchyInternal = Common.CommonModule("SubordinationStructureInternal");
		ModuleHierarchyInternal.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SourceDocumentsOriginalsRecording") Then
		ModuleSourceDocumentsOriginalsAccounting = Common.CommonModule("SourceDocumentsOriginalsRecording");
		ModuleSourceDocumentsOriginalsAccounting.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;
	
	InfobaseUpdateInternal.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);

EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableObjectsSettingsComposition
Procedure OnDefineAttachableObjectsSettingsComposition(InterfaceSettings4) Export

	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OnDefineAttachableObjectsSettingsComposition(InterfaceSettings4);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnDefineAttachableObjectsSettingsComposition(InterfaceSettings4);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
		ModuleMessageTemplatesInternal.OnDefineAttachableObjectsSettingsComposition(InterfaceSettings4);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineAttachableObjectsSettingsComposition Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineAttachableObjectsSettingsComposition(InterfaceSettings4);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineAttachableObjectsSettingsComposition Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineAttachableObjectsSettingsComposition(InterfaceSettings4);
	EndIf;

EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export

	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ItemOrderSetup") Then
		ModuleItemOrdering = Common.CommonModule("ItemOrderSetup");
		ModuleItemOrdering.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DuplicateObjectsDetection") Then
		ModuleDuplicateObjectsDetection = Common.CommonModule("DuplicateObjectsDetection");
		ModuleDuplicateObjectsDetection.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.BatchEditObjects") Then
		ModuleBatchObjectsModification = Common.CommonModule("BatchEditObjects");
		ModuleBatchObjectsModification.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;
		
	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
		ModuleMessageTemplatesInternal.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;
		
	If Common.SubsystemExists("StandardSubsystems.UserNotes") Then
		ModuleUserNotesInternal = Common.CommonModule("UserNotesInternal");
		ModuleUserNotesInternal.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;
		
	If Common.SubsystemExists("StandardSubsystems.UserReminders") Then
		ModuleUserReminderInternal = Common.CommonModule("UserRemindersInternal");
		ModuleUserReminderInternal.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;
		
	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineCommandsAttachedToObject Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineCommandsAttachedToObject Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;
	
	If SSLSubsystemsIntegrationCached.EDLSubscriptions().OnDefineCommandsAttachedToObject Then
		ModuleEDLSubsystemsIntegration = Common.CommonModule("EDLSubsystemsIntegration");
		ModuleEDLSubsystemsIntegration.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectsDeletionInternal = Common.CommonModule("MarkedObjectsDeletionInternal");
		ModuleMarkedObjectsDeletionInternal.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SubordinationStructure") Then
		ModuleHierarchyInternal = Common.CommonModule("SubordinationStructureInternal");
		ModuleHierarchyInternal.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SourceDocumentsOriginalsRecording") Then
		ModuleSourceDocumentsOriginalsAccounting = Common.CommonModule("SourceDocumentsOriginalsRecording");
		ModuleSourceDocumentsOriginalsAccounting.OnDefineCommandsAttachedToObject(FormSettings, Sources,
			AttachedReportsAndDataProcessors, Commands);
	EndIf;
	
	InfobaseUpdateInternal.OnDefineCommandsAttachedToObject(FormSettings, Sources,
		AttachedReportsAndDataProcessors, Commands);
	
EndProcedure

// See GenerateFromOverridable.OnDefineObjectsWithCreationBasedOnCommands.
Procedure OnDefineObjectsWithCreationBasedOnCommands(Objects) Export

	UsersInternal.OnDefineObjectsWithCreationBasedOnCommands(Objects);

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MachineReadableLettersOfAuthority") Then
		ModuleMachineReadableLettersOfAuthorityFTSInternal = Common.CommonModule("MachineReadableLettersOfAuthorityFTSInternal");
		ModuleMachineReadableLettersOfAuthorityFTSInternal.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplates = Common.CommonModule("MessageTemplates");
		ModuleMessageTemplates.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineObjectsWithCreationBasedOnCommands Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineObjectsWithCreationBasedOnCommands Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	EndIf;

EndProcedure

// See GenerateFromOverridable.BeforeAddGenerationCommands.
Procedure BeforeAddGenerationCommands(GenerationCommands, Parameters, StandardProcessing) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().BeforeAddGenerationCommands Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.BeforeAddGenerationCommands(GenerationCommands, Parameters,
			StandardProcessing);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().BeforeAddGenerationCommands Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.BeforeAddGenerationCommands(GenerationCommands, Parameters,
			StandardProcessing);
	EndIf;

EndProcedure

// See GenerateFromOverridable.OnAddGenerationCommands.
Procedure OnAddGenerationCommands(Object, GenerationCommands, Parameters, StandardProcessing) Export

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnAddGenerationCommands(Object, GenerationCommands,
			Parameters, StandardProcessing);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplates = Common.CommonModule("MessageTemplates");
		ModuleMessageTemplates.OnAddGenerationCommands(Object, GenerationCommands, Parameters,
			StandardProcessing);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnAddGenerationCommands Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnAddGenerationCommands(Object, GenerationCommands,
			Parameters, StandardProcessing);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnAddGenerationCommands Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnAddGenerationCommands(Object, GenerationCommands,
			Parameters, StandardProcessing);
	EndIf;

EndProcedure

#EndRegion

#Region DuplicateObjectsDetection

// See DuplicateObjectsDetectionOverridable.OnDefineObjectsWithSearchForDuplicates.
Procedure OnDefineObjectsWithSearchForDuplicates(Objects) Export

	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule(
			"ContactsManagerInternal");
		ModuleContactsManagerInternal.OnDefineObjectsWithSearchForDuplicates(Objects);
	EndIf;

EndProcedure

// See DuplicateObjectsDetectionOverridable.OnDefineObjectsWithSearchForDuplicates
Procedure OnAddTypesToExcludeFromPossibleDuplicates(TypesToExclude) Export

	If Common.SubsystemExists("StandardSubsystems.UserNotes") Then
		ModuleUserNotesInternal = Common.CommonModule("UserNotesInternal");
		ModuleUserNotesInternal.OnAddTypesToExcludeFromPossibleDuplicates(TypesToExclude);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnAddTypesToExcludeFromPossibleDuplicates(TypesToExclude);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		ModuleWorkSchedules.OnAddTypesToExcludeFromPossibleDuplicates(TypesToExclude);
	EndIf;

EndProcedure

#EndRegion

#Region FullTextSearchServer

// Parameters:
//  ObjectMetadata - MetadataObject
//  Value - Arbitrary
//  Presentation - String
//
Procedure OnGetFullTextSearchResults(ObjectMetadata, Value, Presentation) Export
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then 
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnGetFullTextSearchResults(ObjectMetadata, Value, Presentation);
	EndIf;
	
EndProcedure

#EndRegion

#Region Users

// See UsersOverridable.OnDefineSettings.
Procedure OnDefineSettings(Settings) Export

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnDefineSettings(Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineSettings Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineSettings(Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineSettings Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineSettings(Settings);
	EndIf;

EndProcedure

// See UsersOverridable.OnDefineRoleAssignment.
Procedure OnDefineRoleAssignment(RolesAssignment) Export

	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		ModuleAddressClassifierInternal.OnDefineRoleAssignment(RolesAssignment);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Surveys") Then
		ModulePolls = Common.CommonModule("Surveys");
		ModulePolls.OnDefineRoleAssignment(RolesAssignment);
	EndIf;

	StandardSubsystemsServer.OnDefineRoleAssignment(RolesAssignment);

	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManager = Common.CommonModule("BankManager");
		ModuleBankManager.OnDefineRoleAssignment(RolesAssignment);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnDefineRoleAssignment(RolesAssignment);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnDefineRoleAssignment(RolesAssignment);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		ModuleWorkSchedules.OnDefineRoleAssignment(RolesAssignment);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnDefineRoleAssignment(RolesAssignment);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		ModuleCalendarSchedules = Common.CommonModule("CalendarSchedules");
		ModuleCalendarSchedules.OnDefineRoleAssignment(RolesAssignment);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		ModulePerformanceMonitorInternal.OnDefineRoleAssignment(RolesAssignment);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OnDefineRoleAssignment(RolesAssignment);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnDefineRoleAssignment(RolesAssignment);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ToDoList") Then
		ModuleToDoListInternal = Common.CommonModule("ToDoListInternal");
		ModuleToDoListInternal.OnDefineRoleAssignment(RolesAssignment);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineRoleAssignment Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineRoleAssignment(RolesAssignment);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineRoleAssignment Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineRoleAssignment(RolesAssignment);
	EndIf;

EndProcedure

// See UsersOverridable.ChangeActionsOnForm.
Procedure OnDefineActionsInForm(Val UserOrGroup, Val ActionsOnForm) Export

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnDefineActionsInForm(UserOrGroup, ActionsOnForm);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineActionsInForm Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineActionsInForm(UserOrGroup, ActionsOnForm);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineActionsInForm Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineActionsInForm(UserOrGroup, ActionsOnForm);
	EndIf;

EndProcedure

// See UsersOverridable.OnGetOtherSettings.
Procedure OnGetOtherSettings(UserInfo, Settings) Export
	
	StandardSubsystemsServer.OnGetOtherSettings(UserInfo, Settings);
	
	// Adding additional report and data processor settings.
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnGetOtherSettings(UserInfo, Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnGetOtherSettings Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnGetOtherSettings(UserInfo, Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnGetOtherSettings Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnGetOtherSettings(UserInfo, Settings);
	EndIf;

EndProcedure

// See UsersOverridable.OnSaveOtherSetings.
Procedure OnSaveOtherSetings(UserInfo, Settings) Export
	
	StandardSubsystemsServer.OnSaveOtherSetings(UserInfo, Settings);
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnSaveOtherSetings(UserInfo, Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnSaveOtherSetings Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnSaveOtherSetings(UserInfo, Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnSaveOtherSetings Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnSaveOtherSetings(UserInfo, Settings);
	EndIf;

EndProcedure

// See UsersOverridable.OnDeleteOtherSettings.
Procedure OnDeleteOtherSettings(UserInfo, Settings) Export
	
	StandardSubsystemsServer.OnDeleteOtherSettings(UserInfo, Settings);
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnDeleteOtherSettings(UserInfo, Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDeleteOtherSettings Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDeleteOtherSettings(UserInfo, Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDeleteOtherSettings Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDeleteOtherSettings(UserInfo, Settings);
	EndIf;

EndProcedure

// See UsersOverridable.OnDefineRegistrationSettingsForDataAccessEvents
Procedure OnDefineRegistrationSettingsForDataAccessEvents(Settings) Export
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnDefineRegistrationSettingsForDataAccessEvents(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserMonitoring") Then
		ModuleUserMonitoringInternal = Common.CommonModule("UserMonitoringInternal");
		ModuleUserMonitoringInternal.OnDefineRegistrationSettingsForDataAccessEvents(Settings);
	EndIf;
	
	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineRegistrationSettingsForDataAccessEvents Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineRegistrationSettingsForDataAccessEvents(Settings);
	EndIf;
	
	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineRegistrationSettingsForDataAccessEvents Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineRegistrationSettingsForDataAccessEvents(Settings);
	EndIf;
	
EndProcedure

// See UsersInternalSaaS.OnEndIBUserProcessing
Procedure OnEndIBUserProcessing(User) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnEndIBUserProcessing Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnEndIBUserProcessing(User);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnEndIBUserProcessing Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnEndIBUserProcessing(User);
	EndIf;

EndProcedure

#Region UsersForInternalUsage

// The procedure is called if the current infobase user
// cannot be found in the user catalog. For such cases, you can enable auto
// creation of a Users catalog item for the current user.
//
// Parameters:
//  CreateUser - Boolean - a return value. If True,
//       a new user is created in the Users catalog.
//       To override the default user settings before its creation,
//       use OnAutoCreateCurrentUserInCatalog.
//
Procedure OnNoCurrentUserInCatalog(CreateUser) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.OnNoCurrentUserInCatalog(CreateUser);
	EndIf;

EndProcedure

// The procedure is called when a Users catalog item is created automatically as a result of
// interactive sign in or on the call from code.
//
// Parameters:
//  NewUser - CatalogObject.Users - a new user before recording.
//
Procedure OnAutoCreateCurrentUserInCatalog(NewUser) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.OnAutoCreateCurrentUserInCatalog(
			NewUser);
	EndIf;

EndProcedure

// The procedure is called upon authorization of a new infobase user.
//
// Parameters:
//  IBUser - InfoBaseUser - the current infobase user,
//  StandardProcessing - Boolean - the value can be set in the handler. In this case,
//    standard processing of new infobase user authorization is not executed.
//
Procedure OnAuthorizeNewIBUser(IBUser, StandardProcessing) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.OnAuthorizeNewIBUser(IBUser,
			StandardProcessing);
	EndIf;

EndProcedure

// The procedure is called at the start of infobase user processing.
//
// Parameters:
//  ProcessingParameters - See UsersInternal.StartIBUserProcessing.ProcessingParameters.
//  IBUserDetails - Structure
//
Procedure OnStartIBUserProcessing(ProcessingParameters, IBUserDetails) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.OnStartIBUserProcessing(ProcessingParameters,
			IBUserDetails);
	EndIf;

EndProcedure

// Called before writing an infobase user.
//
// Parameters:
//  IBUser - InfoBaseUser - the user to be written.
//
Procedure BeforeWriteIBUser(IBUser) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.BeforeWriteIBUser(IBUser);
	EndIf;

EndProcedure

// Called before deleting an infobase user.
//
// Parameters:
//  IBUser - InfoBaseUser - the user to be deleted.
//
Procedure BeforeDeleteIBUser(IBUser) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.BeforeWriteIBUser(IBUser);
	EndIf;

EndProcedure

// Overrides comment text during the authorization of an infobase user.
// User must be created in Designer and have administrative rights. The procedure is called by Users.AuthenticateCurrentUser().
// The comment is written to the event log.
// 
// Parameters:
//  Comment  - String
//
Procedure AfterWriteAdministratorOnAuthorization(Comment) Export

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterWriteAdministratorOnAuthorization(Comment);
	EndIf;

EndProcedure

// Redefines the actions that are required after assigning an infobase
// user to a user or external user
// (when filling the IBUserID attribute becomes filled).
//
// For example, these actions can include the update of roles.
// 
// Parameters:
//  Ref - CatalogRef.Users
//         - CatalogRef.ExternalUsers - user.
//
Procedure AfterSetIBUser(Ref, ServiceUserPassword) Export

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterSetIBUser(Ref, ServiceUserPassword);
	EndIf;

EndProcedure

// Allows you to override the question text that users see before saving the first administrator.
//  The procedure is called from the BeforeWrite handler in the user form.
//  The procedure is called if RoleEditProhibition() is set and
// the number of infobase users is zero.
// 
// Parameters:
//  QueryText - String - the text of question to be overridden.
//
Procedure OnDefineQuestionTextBeforeWriteFirstAdministrator(QueryText) Export

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnDefineQuestionTextBeforeWriteFirstAdministrator(QueryText);
	EndIf;

EndProcedure

// Redefines actions when creating the administrator in the Users subsystem
// and when a user signs in with administrator roles, which might have been assigned in Designer.
//
// Parameters:
//  Administrator - CatalogRef.Users
//  Refinement     - String - clarifies the conditions of administrator creation.
//
Procedure OnCreateAdministrator(Administrator, Refinement) Export

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnCreateAdministrator(Administrator, Refinement);
	EndIf;

EndProcedure

// Redefines the actions that are required after adding or modifying a user,
// user group, external user, or external user group.
//
// Parameters:
//  Ref     - CatalogRef.Users
//             - CatalogRef.UserGroups
//             - CatalogRef.ExternalUsers
//             - CatalogRef.ExternalUsersGroups - changed object.
//
//  IsNew   - Boolean - the object is added if True, modified otherwise.
//
Procedure AfterAddChangeUserOrGroup(Ref, IsNew) Export

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.AfterAddChangeUserOrGroup(Ref, IsNew);
	EndIf;

EndProcedure

// Redefines the actions required after completing link updates
// in the registers "UserGroupCompositions" and "UserGroupsHierarchy".
//
// Parameters:
//  ItemsToChange - Array of CatalogRef.Users
//                     - Array of CatalogRef.ExternalUsers -
//                       Users who edited the groups.
//
//  ModifiedGroups   - Array of CatalogRef.UserGroups
//                     - Array of CatalogRef.ExternalUsersGroups -
//                       New groups and groups whose content or parents were changes.
//                       
//
Procedure AfterUserGroupsUpdate(ItemsToChange, ModifiedGroups) Export

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterUserGroupsUpdate(ItemsToChange,
			ModifiedGroups);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.AfterUserGroupsUpdate(ItemsToChange,
			ModifiedGroups);
	EndIf;

EndProcedure

// Gets options of the passed report and their presentations.
//
// Parameters:
//  FullReportName                - String - the report to which the report options are received.
//  InfoBaseUser - String - the name of an infobase user.
//  ReportsOptionsInfo      - ValueTable - a table that stores report option data:
//       * ObjectKey          - String - a report key in format "Report.ReportName".
//       * VariantKey         - String - a report option key.
//       * Presentation        - String - a report option presentation.
//       * StandardProcessing - Boolean - If True, a report option is saved to the standard storage.
//  StandardProcessing           - Boolean - If True, a report option is saved to the standard storage.
//
Procedure OnReceiveUserReportsOptions(FullReportName, InfoBaseUser,
	ReportsOptionsInfo, StandardProcessing) Export

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.UserReportOptions(FullReportName, InfoBaseUser,
			ReportsOptionsInfo, StandardProcessing);
	EndIf;

EndProcedure

// Deletes the passed report option from the report option storage.
//
// Parameters:
//  ReportOptionInfo   - ValueTable - report option data:
//       * ObjectKey          - String - a report key in format "Report.ReportName".
//       * VariantKey         - String - a report option key.
//       * Presentation        - String - a report option presentation.
//       * StandardProcessing - Boolean - If True, a report option is saved to the standard storage.
//  InfoBaseUser - String - a name of the infobase user from whose report option is being deleted.
//  StandardProcessing           - Boolean - If True, a report option is saved to the standard storage.
//
Procedure OnDeleteUserReportOptions(ReportOptionInfo, InfoBaseUser,
	StandardProcessing) Export

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.DeleteUserReportOption(ReportOptionInfo,
			InfoBaseUser, StandardProcessing);
	EndIf;

EndProcedure

// Generates a request for changing SaaS user email address.
//
// Parameters:
//  NewEmailAddress                - String - the new email address of the user.
//  User              - CatalogRef.Users - the user whose email address
//                                                              is to be changed.
//  ServiceUserPassword - String - user password for service manager.
//
Procedure OnCreateRequestToChangeEmail(Val NewEmailAddress, Val User, Val ServiceUserPassword) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.CreateEmailAddressChangeRequest(NewEmailAddress, User,
			ServiceUserPassword);
	EndIf;

EndProcedure

#EndRegion

#EndRegion

#Region SecurityProfiles

// See SafeModeManagerOverridable.OnCheckCanSetupSecurityProfiles.
Procedure OnCheckCanSetupSecurityProfiles(Cancel) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnCheckCanSetupSecurityProfiles Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnCheckCanSetupSecurityProfiles(Cancel);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnCheckCanSetupSecurityProfiles Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnCheckCanSetupSecurityProfiles(Cancel);
	EndIf;

EndProcedure

// See SafeModeManagerOverridable.OnRequestPermissionsToUseExternalResources.
Procedure OnRequestPermissionsToUseExternalResources(Val ProgramModule, Val Owner,
	Val ReplacementMode, Val PermissionsToAdd, Val PermissionsToDelete, StandardProcessing, Result) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnRequestPermissionsToUseExternalResources Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnRequestPermissionsToUseExternalResources(ProgramModule, Owner,
			ReplacementMode, PermissionsToAdd, PermissionsToDelete, StandardProcessing, Result);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnRequestPermissionsToUseExternalResources Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnRequestPermissionsToUseExternalResources(ProgramModule, Owner,
			ReplacementMode, PermissionsToAdd, PermissionsToDelete, StandardProcessing, Result);
	EndIf;

EndProcedure

// See SafeModeManagerOverridable.OnRequestToCreateSecurityProfile.
Procedure OnRequestToCreateSecurityProfile(Val ProgramModule, StandardProcessing, Result) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnRequestToCreateSecurityProfile Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnRequestToCreateSecurityProfile(ProgramModule, StandardProcessing,
			Result);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnRequestToCreateSecurityProfile Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnRequestToCreateSecurityProfile(ProgramModule, StandardProcessing,
			Result);
	EndIf;

EndProcedure

// See SafeModeManagerOverridable.OnRequestToDeleteSecurityProfile.
Procedure OnRequestToDeleteSecurityProfile(Val ProgramModule, StandardProcessing, Result) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnRequestToDeleteSecurityProfile Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnRequestToDeleteSecurityProfile(ProgramModule, StandardProcessing,
			Result);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnRequestToDeleteSecurityProfile Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnRequestToDeleteSecurityProfile(ProgramModule, StandardProcessing,
			Result);
	EndIf;

EndProcedure

// See SafeModeManagerOverridable.OnAttachExternalModule.
Procedure OnAttachExternalModule(Val ExternalModule, SafeMode) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnAttachExternalModule Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnAttachExternalModule(ExternalModule, SafeMode);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnAttachExternalModule Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnAttachExternalModule(ExternalModule, SafeMode);
	EndIf;

EndProcedure

// See SafeModeManagerOverridable.OnEnableSecurityProfiles.
Procedure OnEnableSecurityProfiles() Export

	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadInternal = Common.CommonModule("GetFilesFromInternetInternal");
		ModuleNetworkDownloadInternal.OnEnableSecurityProfiles();
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.IBBackup") Then
		ModuleIBBackupServer = Common.CommonModule("IBBackupServer");
		ModuleIBBackupServer.OnEnableSecurityProfiles();
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnEnableSecurityProfiles Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnEnableSecurityProfiles();
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnEnableSecurityProfiles Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnEnableSecurityProfiles();
	EndIf;

EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources.
Procedure OnFillPermissionsToAccessExternalResources(PermissionsRequests) Export

	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		ModuleAddressClassifierInternal.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessorsSafeModeInternal = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsSafeModeInternal");
		ModuleAdditionalReportsAndDataProcessorsSafeModeInternal.OnFillPermissionsToAccessExternalResources(
			PermissionsRequests);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Conversations") Then
		ModuleConversationsInternal = Common.CommonModule("ConversationsInternal");
		ModuleConversationsInternal.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SendSMSMessage") Then
		ModuleSMS = Common.CommonModule("SendSMSMessage");
		ModuleSMS.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		ModulePerformanceMonitorInternal.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadInternal = Common.CommonModule("GetFilesFromInternetInternal");
		ModuleNetworkDownloadInternal.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule(
			"EmailOperationsInternal");
		ModuleEmailOperationsInternal.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	EndIf;

	StandardSubsystemsServer.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.TextTranslation") Then
		ModuleTranslationOfTextIntoOtherLanguages = Common.CommonModule("TextTranslationTool");
		ModuleTranslationOfTextIntoOtherLanguages.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnFillPermissionsToAccessExternalResources Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnFillPermissionsToAccessExternalResources Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnFillPermissionsToAccessExternalResources(PermissionsRequests);
	EndIf;

EndProcedure

#Region SecurityProfilesForInternalUsage

// The procedure is called when external module managers are registered.
//
// Parameters:
//  Managers - Array - references to modules.
//
Procedure OnRegisterExternalModulesManagers(Managers) Export

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessorsSafeModeInternal = Common.CommonModule(
			"AdditionalReportsAndDataProcessorsSafeModeInternal");
		ModuleAdditionalReportsAndDataProcessorsSafeModeInternal.OnRegisterExternalModulesManagers(Managers);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnRegisterExternalModulesManagers(Managers);
	EndIf;

EndProcedure

#EndRegion

#EndRegion

#Region ReportMailing

// See ReportMailingOverridable.DetermineReportsToExclude
Procedure WhenDefiningExcludedReports(ReportsToExclude) Export

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.WhenDefiningExcludedReports(ReportsToExclude);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Surveys") Then
		ModulePolls = Common.CommonModule("Surveys");
		ModulePolls.WhenDefiningExcludedReports(ReportsToExclude);
	EndIf;

EndProcedure

#EndRegion

#Region EmailOperations

// See EmailOperationsOverridable.BeforeGetEmailMessagesStatuses
Procedure BeforeGetEmailMessagesStatuses(EmailMessagesIDs) Export
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.BeforeGetEmailMessagesStatuses(EmailMessagesIDs);
	EndIf;
	
EndProcedure    

// See EmailOperationsOverridable.AfterGetEmailMessagesStatuses
Procedure AfterGetEmailMessagesStatuses(DeliveryStatuses) Export
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.AfterGetEmailMessagesStatuses(DeliveryStatuses);
	EndIf;
	
EndProcedure

#EndRegion

#Region FilesOperations

// Parameters:
//   Objects - Array of MetadataObject
//
Procedure OnDefineFileSynchronizationExceptionObjects(Objects) Export

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnDefineFileSynchronizationExceptionObjects(Objects);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineFileSynchronizationExceptionObjects Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineFileSynchronizationExceptionObjects(Objects);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineFileSynchronizationExceptionObjects Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineFileSynchronizationExceptionObjects(Objects);
	EndIf;

EndProcedure

// See FilesOperationsOverridable.OnCreateFilesListForm
Procedure OnCreateFilesListForm(Form) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnCreateFilesListForm Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnCreateFilesListForm(Form);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnCreateFilesListForm Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnCreateFilesListForm(Form);
	EndIf;

EndProcedure

// See FilesOperationsOverridable.OnCreateFilesItemForm
Procedure OnCreateFilesItemForm(Form) Export

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnCreateFilesItemForm(Form);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnCreateFilesItemForm Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnCreateFilesItemForm(Form);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnCreateFilesItemForm Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnCreateFilesItemForm(Form);
	EndIf;

EndProcedure

// See FilesOperationsOverridable.OnSendFilesViaEmail.
Procedure OnSendFilesViaEmail(SendOptions, FilesToSend, FilesOwner, UUID) Export
	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnSendFilesViaEmail Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnSendFilesViaEmail(SendOptions, FilesToSend, FilesOwner,
			UUID);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnSendFilesViaEmail Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnSendFilesViaEmail(SendOptions, FilesToSend, FilesOwner,
			UUID);
	EndIf;
EndProcedure

#EndRegion

#Region ScheduledJobs

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings.
Procedure OnDefineScheduledJobSettings(Settings) Export
	
	StandardSubsystemsServer.OnDefineScheduledJobSettings(Settings);
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptionsInternal = Common.CommonModule("ReportsOptionsInternal");
		ModuleReportsOptionsInternal.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnDefineScheduledJobSettings(Settings);
	EndIf;

	InfobaseUpdateInternal.OnDefineScheduledJobSettings(Settings);

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		ModulePerformanceMonitorInternal.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FullTextSearch") Then
		ModuleFullTextSearchServer = Common.CommonModule("FullTextSearchServer");
		ModuleFullTextSearchServer.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
		ModuleMonitoringCenterInternal.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectsDeletionInternal = Common.CommonModule("MarkedObjectsDeletionInternal");
		ModuleMarkedObjectsDeletionInternal.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MachineReadableLettersOfAuthority") Then
		ModuleMachineReadableLettersOfAuthorityFTSInternal = Common.CommonModule("MachineReadableLettersOfAuthorityFTSInternal");
		ModuleMachineReadableLettersOfAuthorityFTSInternal.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineScheduledJobSettings Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineScheduledJobSettings(Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineScheduledJobSettings Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineScheduledJobSettings(Settings);
	EndIf;

EndProcedure

// See ExternalResourcesOperationsLockOverridable.WhenYouAreForbiddenToWorkWithExternalResources.
Procedure WhenYouAreForbiddenToWorkWithExternalResources() Export
	
	If Common.SubsystemExists("StandardSubsystems.Conversations") Then
		ModuleConversationsInternal = Common.CommonModule("ConversationsInternal");
		ModuleConversationsInternal.Lock();
	EndIf;
	
	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().WhenYouAreForbiddenToWorkWithExternalResources Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.WhenYouAreForbiddenToWorkWithExternalResources();
	EndIf;
	
	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().WhenYouAreForbiddenToWorkWithExternalResources Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.WhenYouAreForbiddenToWorkWithExternalResources();
	EndIf;
	
EndProcedure

// See ExternalResourcesOperationsLockOverridable.WhenAllowingWorkWithExternalResources.
Procedure WhenAllowingWorkWithExternalResources() Export
	
	If Common.SubsystemExists("StandardSubsystems.Conversations") Then
		ModuleConversationsInternal = Common.CommonModule("ConversationsInternal");
		ModuleConversationsInternal.Unlock();
	EndIf;
	
	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().WhenAllowingWorkWithExternalResources Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.WhenAllowingWorkWithExternalResources();
	EndIf;
	
	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().WhenAllowingWorkWithExternalResources Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.WhenAllowingWorkWithExternalResources();
	EndIf;
	
EndProcedure

#EndRegion

#Region Properties

// See PropertyManagerOverridable.OnGetPredefinedPropertiesSets.
Procedure OnGetPredefinedPropertiesSets(Sets) Export

	UsersInternal.OnGetPredefinedPropertiesSets(Sets);

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnGetPredefinedPropertiesSets(Sets);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnGetPredefinedPropertiesSets(Sets);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnGetPredefinedPropertiesSets(Sets);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnGetPredefinedPropertiesSets(Sets);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ModuleContactsManager.OnGetPredefinedPropertiesSets(Sets);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnGetPredefinedPropertiesSets Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnGetPredefinedPropertiesSets(Sets);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnGetPredefinedPropertiesSets Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnGetPredefinedPropertiesSets(Sets);
	EndIf;

EndProcedure

#EndRegion

#Region ToDoList

// See ToDoListOverridable.OnDetermineToDoListHandlers
Procedure OnDetermineToDoListHandlers(ToDoList) Export

	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ToDoList.Add(Common.CommonModule("AddressClassifierInternal"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ToDoList.Add(Common.CommonModule("BusinessProcessesAndTasksServer"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ToDoList.Add(Common.CommonModule("ObjectsVersioning"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ToDoList.Add(Common.CommonModule("Interactions"));
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ToDoList.Add(Common.CommonModule("AddInsInternal"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ToDoList.Add(Common.CommonModule("AdditionalReportsAndDataProcessors"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UserNotes") Then
		ToDoList.Add(Common.CommonModule("UserNotesInternal"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ToDoList.Add(Common.CommonModule("PersonalDataProtection"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ToDoList.Add(Common.CommonModule("DataExchangeServer"));
	EndIf;

	ToDoList.Add(InfobaseUpdateInternal);

	If Common.SubsystemExists("StandardSubsystems.FullTextSearch") Then
		ToDoList.Add(Common.CommonModule("FullTextSearchServer"));
	EndIf;

	ToDoList.Add(UsersInternal);

	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ToDoList.Add(Common.CommonModule("BankManager"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ToDoList.Add(Common.CommonModule("CurrencyRateOperations"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SendSMSMessage") Then
		ToDoList.Add(Common.CommonModule("SendSMSMessage"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ToDoList.Add(Common.CommonModule("FilesOperationsInternal"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ToDoList.Add(Common.CommonModule("ReportMailing"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.IBBackup") Then
		ToDoList.Add(Common.CommonModule("IBBackupServer"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UsersSessions") Then
		ToDoList.Add(Common.CommonModule("IBConnections"));
	EndIf;

	ToDoList.Add(StandardSubsystemsServer);

	If Common.SubsystemExists("StandardSubsystems.TotalsAndAggregatesManagement") Then
		ToDoList.Add(Common.CommonModule("TotalsAndAggregatesManagementInternal"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ToDoList.Add(Common.CommonModule("PrintManagement"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ToDoList.Add(Common.CommonModule("Catalogs.AccessGroupProfiles"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ToDoList.Add(Common.CommonModule("AccountingAuditInternal"));
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		ToDoList.Add(Common.CommonModule("MonitoringCenterInternal"));
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ToDoList.Add(Common.CommonModule("DigitalSignatureInternal"));
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MachineReadableLettersOfAuthority") Then
		ToDoList.Add(Common.CommonModule("MachineReadableLettersOfAuthorityFTSInternal"));
	EndIf;
	
	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDetermineToDoListHandlers Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDetermineToDoListHandlers(ToDoList);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDetermineToDoListHandlers Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDetermineToDoListHandlers(ToDoList);
	EndIf;

EndProcedure

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export

	If Common.SubsystemExists("StandardSubsystems.UserMonitoring") Then
		ModuleUserMonitoringInternal = Common.CommonModule("UserMonitoringInternal");
		ModuleUserMonitoringInternal.OnFillToDoList(ToDoList);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectsDeletionInternal = Common.CommonModule("MarkedObjectsDeletionInternal");
		ModuleMarkedObjectsDeletionInternal.OnFillToDoList(ToDoList);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnFillToDoList Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnFillToDoList(ToDoList);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnFillToDoList Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnFillToDoList(ToDoList);
	EndIf;

EndProcedure

// See ToDoListOverridable.OnDetermineCommandInterfaceSectionsOrder.
Procedure OnDetermineCommandInterfaceSectionsOrder(CommandInterfaceSectionsOrder) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDetermineCommandInterfaceSectionsOrder Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDetermineCommandInterfaceSectionsOrder(
			CommandInterfaceSectionsOrder);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDetermineCommandInterfaceSectionsOrder Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDetermineCommandInterfaceSectionsOrder(
			CommandInterfaceSectionsOrder);
	EndIf;

EndProcedure

// See ToDoListOverridable.OnDisableToDos.
Procedure OnDisableToDos(ToDoItemsToDisable) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDisableToDos Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDisableToDos(ToDoItemsToDisable);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDisableToDos Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDisableToDos(ToDoItemsToDisable);
	EndIf;

EndProcedure

// See ToDoListOverridable.OnDefineSettings.
Procedure OnDefineToDoListSettings(Settings) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineToDoListSettings Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineToDoListSettings(Settings);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineToDoListSettings Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineToDoListSettings(Settings);
	EndIf;

EndProcedure

// See ToDoListOverridable.SetCommonQueryParameters.
Procedure OnSetCommonQueryParameters(Query, CommonQueryParameters) Export

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnSetCommonQueryParameters Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnSetCommonQueryParameters(Query, CommonQueryParameters);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnSetCommonQueryParameters Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnSetCommonQueryParameters(Query, CommonQueryParameters);
	EndIf;

EndProcedure

#EndRegion

#Region AccessManagement

// See AccessManagementOverridable.OnFillAccessKinds.
Procedure OnFillAccessKinds(AccessKinds) Export
	
	// The first call must be made to the Users subsystems.
	UsersInternal.OnFillAccessKinds(AccessKinds);

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnFillAccessKinds(AccessKinds);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnFillAccessKinds(AccessKinds);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule(
			"EmailOperationsInternal");
		ModuleEmailOperationsInternal.OnFillAccessKinds(AccessKinds);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnFillAccessKinds(AccessKinds);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnFillAccessKinds Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnFillAccessKinds(AccessKinds);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnFillAccessKinds Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnFillAccessKinds(AccessKinds);
	EndIf;

EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction.
Procedure OnFillListsWithAccessRestriction(Lists) Export

	If Common.SubsystemExists("StandardSubsystems.Surveys") Then
		ModulePolls = Common.CommonModule("Surveys");
		ModulePolls.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UserNotes") Then
		ModuleUserNotesInternal = Common.CommonModule("UserNotesInternal");
		ModuleUserNotesInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		ModuleAccountingAuditInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UserReminders") Then
		ModuleUserReminderInternal = Common.CommonModule("UserRemindersInternal");
		ModuleUserReminderInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Users") Then
		ModuleUsersInternal = Common.CommonModule("UsersInternal");
		ModuleUsersInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule(
			"EmailOperationsInternal");
		ModuleEmailOperationsInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
		ModuleMessageTemplatesInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnFillListsWithAccessRestriction Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnFillListsWithAccessRestriction Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnFillListsWithAccessRestriction(Lists);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DSSElectronicSignatureService") Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
EndProcedure

// See AccessManagementOverridable.OnFillSuppliedAccessGroupProfiles.
Procedure OnFillSuppliedAccessGroupProfiles(ProfilesDetails, ParametersOfUpdate) Export

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnFillSuppliedAccessGroupProfiles(ProfilesDetails, ParametersOfUpdate);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnFillSuppliedAccessGroupProfiles Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnFillSuppliedAccessGroupProfiles(ProfilesDetails,
			ParametersOfUpdate);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnFillSuppliedAccessGroupProfiles Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnFillSuppliedAccessGroupProfiles(ProfilesDetails,
			ParametersOfUpdate);
	EndIf;

EndProcedure

// See AccessManagementOverridable.OnFillAccessRightsDependencies.
Procedure OnFillAccessRightsDependencies(RightsDependencies) Export

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnFillAccessRightsDependencies(RightsDependencies);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnFillAccessRightsDependencies Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnFillAccessRightsDependencies(RightsDependencies);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnFillAccessRightsDependencies Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnFillAccessRightsDependencies(RightsDependencies);
	EndIf;

EndProcedure

// See AccessManagementOverridable.OnFillAvailableRightsForObjectsRightsSettings.
Procedure OnFillAvailableRightsForObjectsRightsSettings(AvailableRights) Export

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnFillAvailableRightsForObjectsRightsSettings(AvailableRights);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnFillAvailableRightsForObjectsRightsSettings Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnFillAvailableRightsForObjectsRightsSettings(AvailableRights);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnFillAvailableRightsForObjectsRightsSettings Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnFillAvailableRightsForObjectsRightsSettings(AvailableRights);
	EndIf;

EndProcedure

// See AccessManagementOverridable.OnFillAccessKindUsage.
Procedure OnFillAccessKindUsage(AccessKind, Use) Export

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnFillAccessKindUsage(AccessKind, Use);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnFillAccessKindUsage(AccessKind, Use);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnFillAccessKindUsage Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnFillAccessKindUsage(AccessKind, Use);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnFillAccessKindUsage Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnFillAccessKindUsage(AccessKind, Use);
	EndIf;

EndProcedure

// See AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionKinds.
Procedure OnFillMetadataObjectsAccessRestrictionKinds(LongDesc) Export

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnFillMetadataObjectsAccessRestrictionKinds(LongDesc);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnFillMetadataObjectsAccessRestrictionKinds(LongDesc);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnFillMetadataObjectsAccessRestrictionKinds(LongDesc);
	EndIf;

	UsersInternal.OnFillMetadataObjectsAccessRestrictionKinds(LongDesc);

	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule(
			"EmailOperationsInternal");
		ModuleEmailOperationsInternal.OnFillMetadataObjectsAccessRestrictionKinds(LongDesc);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnFillMetadataObjectsAccessRestrictionKinds(LongDesc);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnFillMetadataObjectsAccessRestrictionKinds(LongDesc);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
		ModuleMessageTemplatesInternal.OnFillMetadataObjectsAccessRestrictionKinds(LongDesc);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnFillMetadataObjectsAccessRestrictionKinds Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnFillMetadataObjectsAccessRestrictionKinds(LongDesc);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnFillMetadataObjectsAccessRestrictionKinds Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnFillMetadataObjectsAccessRestrictionKinds(LongDesc);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DSSElectronicSignatureService") Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleInternal.OnFillMetadataObjectsAccessRestrictionKinds(LongDesc);
	EndIf;
	
EndProcedure

#Region AccessManagementForInternalUsage

// Returns a temporary table manager that contains a temporary table of users included in additional user groups,
// such as task assignee group users that correspond to addressing keys
// (PerformerRole + MainAddressingObject + AdditionalAddressingObject).
// 
//
// Parameters:
//  TempTablesManager - TempTablesManager - The method puts the following table to the manager
//                            PerformersGroupTable with the following fields:
//                              PerformersGroup. For example
//                                                   CatalogRef.TaskPerformersGroups.
//                              User       - CatalogRef.Users
//                                                 - CatalogRef.ExternalUsers
//
//  ParameterContent     - Undefined - the parameter is not specified, return all the data.
//                            If string value is
//                              set to "PerformerGroups", returns
//                               only the contents of the specified performer groups.
//                              If set to "Performers", only
//                               returns the contents of performer groups that
//                               include the specified performers.
//
//  ParameterValue       - Undefined - If ParameterContent = Undefined,
//                          - CatalogRef.TaskPerformersGroups - 
//                              If ParameterContent = "PerformersGroups".
//                          - CatalogRef.Users
//                          - CatalogRef.ExternalUsers -
//                              If ParameterContent = "Assignees".
//                          - Array - array of the types specified above.
//
//  NoPerformerGroups    - Boolean - If False, TempTablesManager contains a temporary table. Otherwise, does not.
//
Procedure OnDeterminePerformersGroups(TempTablesManager, ParameterContent, ParameterValue,
	NoPerformerGroups) Export

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDeterminePerformersGroups(TempTablesManager, ParameterContent,
			ParameterValue, NoPerformerGroups);
	EndIf;

EndProcedure

// This procedure is called when updating the infobase user roles.
//
// Parameters:
//  IBUserID - UUID,
//  Cancel - Boolean - If this parameter is set to False in the event handler,
//    roles are not updated for this infobase user.
//
Procedure OnUpdateIBUserRoles(IBUserID, Cancel) Export

	If Common.SubsystemExists(
		"StandardSubsystems.SaaSOperations.AccessManagementSaaS") Then
		ModuleAccessManagementInternalSaaS = Common.CommonModule(
			"AccessManagementInternalSaaS");
		ModuleAccessManagementInternalSaaS.OnUpdateIBUserRoles(IBUserID,
			Cancel);
	EndIf;

EndProcedure

#EndRegion

#EndRegion

#Region MarkedObjectsDeletion

// See MarkedObjectsDeletionOverridable.BeforeDeletingAGroupOfObjects
Procedure BeforeDeletingAGroupOfObjects(Context, ObjectsToDelete) Export
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.BeforeDeletingAGroupOfObjects(Context, ObjectsToDelete);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.BeforeDeletingAGroupOfObjects(Context, ObjectsToDelete);
	EndIf;
		
EndProcedure

// See MarkedObjectsDeletionOverridable.AfterDeletingAGroupOfObjects
Procedure AfterDeletingAGroupOfObjects(Context, Success) Export
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.AfterDeletingAGroupOfObjects(Context, Success);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.AfterDeletingAGroupOfObjects(Context, Success);
	EndIf;
	
EndProcedure

#EndRegion

#Region MonitoringCenter

// See MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters.
Procedure OnCollectConfigurationStatisticsParameters() Export

	InfobaseUpdateInternal.OnCollectConfigurationStatisticsParameters();
	UsersInternal.OnCollectConfigurationStatisticsParameters();

	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnCollectConfigurationStatisticsParameters();
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnCollectConfigurationStatisticsParameters();
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SendSMSMessage") Then
		ModuleSMS = Common.CommonModule("SendSMSMessage");
		ModuleSMS.OnCollectConfigurationStatisticsParameters();
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnCollectConfigurationStatisticsParameters();
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnCollectConfigurationStatisticsParameters Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnCollectConfigurationStatisticsParameters();
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnCollectConfigurationStatisticsParameters Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnCollectConfigurationStatisticsParameters();
	EndIf;

EndProcedure

#EndRegion

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Use SSLSubsystemsIntegration.OnDefinePrintSettings instead.
// See PrintManagementOverridable.OnDefineObjectsWithPrintCommands.
//
Procedure OnDefineObjectsWithPrintCommands(ListOfObjects) Export
	
	If SSLSubsystemsIntegrationCached.SubscriptionsCTL().OnDefineObjectsWithPrintCommands Then
		ModuleCTLSubsystemsIntegration = Common.CommonModule("CTLSubsystemsIntegration");
		ModuleCTLSubsystemsIntegration.OnDefineObjectsWithPrintCommands(ListOfObjects);
	EndIf;

	If SSLSubsystemsIntegrationCached.SubscriptionsOSL().OnDefineObjectsWithPrintCommands Then
		ModuleOSLSubsystemsIntegration = Common.CommonModule("OSLSubsystemsIntegration");
		ModuleOSLSubsystemsIntegration.OnDefineObjectsWithPrintCommands(ListOfObjects);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion