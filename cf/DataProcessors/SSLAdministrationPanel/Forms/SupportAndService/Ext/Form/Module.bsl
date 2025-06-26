///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		Items.ExternalResourcesOperationsLockGroup.Visible = ScheduledJobsServer.OperationsWithExternalResourcesLocked();

		Items.ScheduledAndBackgroundJobsDataProcessorGroup.Visible = Users.IsFullUser( ,
			True);
	Else
		Items.ScheduledAndBackgroundJobsDataProcessorGroup.Visible = False;
		Items.ExternalResourcesOperationsLockGroup.Visible = False;
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.TotalsAndAggregatesManagement") Then
		Items.TotalsAndAggregatesManagementDataProcessorOpenGroup.Visible = Users.IsFullUser()
			And Not Common.DataSeparationEnabled();
	Else
		Items.TotalsAndAggregatesManagementDataProcessorOpenGroup.Visible = False;
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.IBBackup") Then
		Items.OnLocalComputerPage.Visible =
			Users.IsFullUser( , True)
			And Not Common.DataSeparationEnabled()
			And Not Common.ClientConnectedOverWebServer()
			And Common.IsWindowsClient();

		UpdateBackupSettings();
	Else
		Items.OnLocalComputerPage.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("OnlineUserSupport.CloudArchive20") Then
		ModuleCloudArchive20 = Common.CommonModule("CloudArchive20");
		ModuleCloudArchive20.Maintenance_WhenCreatedOnServer(ThisObject);
	Else
		Items.CloudArchivePage.Visible = False;
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		Items.PerformanceMonitorGroup.Visible = Users.IsFullUser( , True);
	Else
		Items.PerformanceMonitorGroup.Visible = False;
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.BatchEditObjects") Then
		Items.BulkObjectEditingDataProcessorGroup.Visible = Users.IsFullUser();
	Else
		Items.BulkObjectEditingDataProcessorGroup.Visible = False;
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.UsersSessions") Then
		ModuleIBConnections = Common.CommonModule("IBConnections");
		Items.BlockInfobaseConnectionsDataProcessorOpen.Visible = ModuleIBConnections.IsSubsystemUsed();
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.DuplicateObjectsDetection") Then
		Items.DuplicateObjectsDetectionGroup.Visible = False;
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		Items.AdditionalReportsAndDataProcessorsGroup.Visible = ConstantsSet.UseAdditionalReportsAndDataProcessors;
	Else
		Items.AdditionalReportsAndDataProcessorsGroup.Visible = False;
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		Items.InstalledPatchesGroup.Visible = Users.IsFullUser();
	Else
		Items.UpdatesInstallationGroup.Visible = False;
		Items.InstalledPatchesGroup.Visible = False;
	EndIf;

	If Common.FileInfobase() Or Common.DataSeparationEnabled() Then
		Items.UpdatePrioritySettingGroup.Visible = False;
	Else
		UpdateThreadsCount = InfobaseUpdate.UpdateThreadsCount();
		DataProcessingPriority    = InfobaseUpdate.DeferredProcessingPriority();
		Items.UpdateThreadsCount.Visible = InfobaseUpdate.MultithreadUpdateAllowed();
		ConfigureUpdateThreadsCountUsage(DataProcessingPriority);
	EndIf;
	
	If Not Users.IsFullUser(, True) Then
		Items.ClearObsoleteData.Visible = False;
	EndIf;
	
	// Update items states.
	SetAvailability();

	ApplicationSettingsOverridable.ServiceOnCreateAtServer(ThisObject);

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	If EventName = "BackupSettingsFormClosed" And CommonClient.SubsystemExists(
		"StandardSubsystems.IBBackup") Then
		UpdateBackupSettings();
	ElsIf EventName = "OperationsWithExternalResourcesAllowed" Then
		Items.ExternalResourcesOperationsLockGroup.Visible = False;
	EndIf;
	
	If CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive20") Then
		ModuleCloudArchive20Client = CommonClient.CommonModule("CloudArchive20Client");
		ModuleCloudArchive20Client.Maintenance_NotificationProcessing(ThisObject, EventName, Parameter, Source);
	EndIf;

EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Exit Then
		Return;
	EndIf;
	RefreshApplicationInterface();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

#Region OnlineUserSupportCloudArchive20

&AtClient
Procedure BackupRetentionOnChange(Item)
	
	// Output the proper page depending on the given storage option.
	If CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive20") Then
		ModuleCloudArchive20Client = CommonClient.CommonModule("CloudArchive20Client");
		ModuleCloudArchive20Client.Maintenance_BackupRetentionOnChange(ThisObject, BackupRetention);
	EndIf;
	
EndProcedure

&AtClient
Procedure BackupRetentionClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure CloudArchiveCreateBackupClick(Item)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive20") Then
		ModuleCloudArchive20Client = CommonClient.CommonModule("CloudArchive20Client");
		ModuleCloudArchive20Client.OpenBackupForm();
	EndIf;
	
EndProcedure

&AtClient
Procedure CloudArchiveOpenBackupsClick(Item)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive20") Then
		ModuleCloudArchive20Client = CommonClient.CommonModule("CloudArchive20Client");
		ModuleCloudArchive20Client.OpenListOfBackups();
	EndIf;
	
EndProcedure

&AtClient
Procedure NoteCloudArchiveEnabledURLProcessing(
	Item,
	FormattedStringURL,
	StandardProcessing)
	
	StandardProcessing = False;
	
	If CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive20") Then
		ModuleCloudArchive20Client = CommonClient.CommonModule("CloudArchive20Client");
		If FormattedStringURL = "setting" Then
			ModuleCloudArchive20Client.OpenCloudArchiveSetupForm();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

&AtClient
Procedure RunPerformanceMeasurementsOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure WriteIBUpdateDetailsToEventLogOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure DeferredDataProcessingPriorityOnChange(Item)
	SetDeferredProcessingPriority(Item.Name);
EndProcedure

&AtClient
Procedure InfobaseUpdateThreadCountOnChange(Item)
	SetUpdateThreadsCount();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

#Region OnlineUserSupportCloudArchive20

&AtClient
Procedure CloudArchiveBackupSettings(Command)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive20") Then
		ModuleCloudArchive20Client = CommonClient.CommonModule("CloudArchive20Client");
		ModuleCloudArchive20Client.OpenCloudArchiveSetupForm();
	EndIf;
	
EndProcedure

#EndRegion

&AtClient
Procedure UnlockOperationsWithExternalResources(Command)
	UnlockExternalResourcesOperationsAtServer();
	StandardSubsystemsClient.SetAdvancedApplicationCaption();
	Notify("OperationsWithExternalResourcesAllowed");
	RefreshInterface();
EndProcedure

&AtClient
Procedure DeferredDataProcessing(Command)
	FormParameters = New Structure("OpenedFromAdministrationPanel", True);
	OpenForm("DataProcessor.ApplicationUpdateResult.Form.ApplicationUpdateResult", FormParameters);
EndProcedure

&AtClient
Procedure ClearObsoleteData(Command)
	
	OpenForm("DataProcessor.ApplicationUpdateResult.Form.ClearObsoleteData");
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client.

&AtClient
Procedure Attachable_OnChangeAttribute(Item, InterfaceUpdateIsRequired = True)

	ConstantName = OnChangeAttributeServer(Item.Name);
	RefreshReusableValues();

	If InterfaceUpdateIsRequired Then
		RefreshInterface = True;
		AttachIdleHandler("RefreshApplicationInterface", 2, True);
	EndIf;

	If ConstantName <> "" Then
		Notify("Write_ConstantsSet", New Structure, ConstantName);
	EndIf;

EndProcedure

&AtClient
Procedure RefreshApplicationInterface()

	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server call.

&AtServer
Function OnChangeAttributeServer(TagName)

	DataPathAttribute = Items[TagName].DataPath;
	ConstantName = SaveAttributeValue(DataPathAttribute);
	SetAvailability(DataPathAttribute);
	RefreshReusableValues();
	Return ConstantName;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server.

&AtServer
Procedure SetDeferredProcessingPriority(TagName)
	InfobaseUpdate.SetDeferredProcessingPriority(DataProcessingPriority);
	ConfigureUpdateThreadsCountUsage(DataProcessingPriority);
EndProcedure

&AtServer
Procedure ConfigureUpdateThreadsCountUsage(Priority)
	Items.UpdateThreadsCount.Enabled = (Priority = "DataProcessing");
EndProcedure

&AtServer
Procedure SetUpdateThreadsCount()
	InfobaseUpdate.SetUpdateThreadsCount(UpdateThreadsCount);
EndProcedure

&AtServer
Function SaveAttributeValue(DataPathAttribute)

	NameParts = StrSplit(DataPathAttribute, ".");
	If NameParts.Count() <> 2 Then
		Return "";
	EndIf;

	ConstantName = NameParts[1];
	ConstantManager = Constants[ConstantName];
	ConstantValue = ConstantsSet[ConstantName];

	If ConstantManager.Get() <> ConstantValue Then
		ConstantManager.Set(ConstantValue);
	EndIf;

	Return ConstantName;

EndFunction

&AtServer
Procedure SetAvailability(DataPathAttribute = "")

	If Not Users.IsFullUser( , True) Then
		Return;
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") And (DataPathAttribute
		= "ConstantsSet.RunPerformanceMeasurements" Or DataPathAttribute = "") Then
		ItemDataProcessorPerformanceMonitorPerformanceMeasurementsImport = Items.Find(
			"PerformanceEvaluationPerformanceMeasurementImportDataProcessor");
		ItemDataProcessorPerformanceMonitorDataExport = Items.Find(
			"PerformanceEvaluationDataExportDataProcessor");
		ItemCatalogKeyOperationsProfilesOpenList = Items.Find(
			"CatalogKeyOperationsProfilesOpenList");
		ItemDataProcessorPerformanceMonitorSettings = Items.Find("PerformanceEvaluationSettingsDataProcessor");
		If (ItemDataProcessorPerformanceMonitorSettings <> Undefined
			And ItemDataProcessorPerformanceMonitorDataExport <> Undefined
			And ItemCatalogKeyOperationsProfilesOpenList <> Undefined
			And ItemDataProcessorPerformanceMonitorPerformanceMeasurementsImport <> Undefined
			And ConstantsSet.Property("RunPerformanceMeasurements")) Then
			ItemDataProcessorPerformanceMonitorSettings.Enabled = ConstantsSet.RunPerformanceMeasurements;
			ItemDataProcessorPerformanceMonitorDataExport.Enabled = ConstantsSet.RunPerformanceMeasurements;
			ItemCatalogKeyOperationsProfilesOpenList.Enabled = ConstantsSet.RunPerformanceMeasurements;
			ItemDataProcessorPerformanceMonitorPerformanceMeasurementsImport.Enabled = ConstantsSet.RunPerformanceMeasurements;
		EndIf;
	EndIf;

EndProcedure

&AtServer
Procedure UpdateBackupSettings()

	If Not Common.DataSeparationEnabled() And Users.IsFullUser( , True) Then

		ModuleIBBackupServer = Common.CommonModule("IBBackupServer");
		Items.IBBackupSetup.ExtendedTooltip.Title = ModuleIBBackupServer.CurrentBackupSetting();
	EndIf;

EndProcedure

&AtServer
Procedure UnlockExternalResourcesOperationsAtServer()
	Items.ExternalResourcesOperationsLockGroup.Visible = False;
	ModuleScheduledJobsServer = Common.CommonModule("ScheduledJobsServer");
	ModuleScheduledJobsServer.UnlockOperationsWithExternalResources();
EndProcedure

#EndRegion