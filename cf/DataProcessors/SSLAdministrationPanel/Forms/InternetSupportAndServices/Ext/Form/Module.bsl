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
Var RefreshInterface;	// Boolean

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsSystemAdministrator   = Users.IsFullUser(, True);
	DataSeparationEnabled        = Common.DataSeparationEnabled();
	IsStandaloneWorkplace = Common.IsStandaloneWorkplace();
	
	ApplicationSettings.OnlineSupportAndServicesOnCreateAtServer(
		ThisObject,
		Cancel,
		StandardProcessing);
	
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ApplicationSettingsClient.OnlineSupportAndServicesOnOpen(ThisObject, Cancel);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	ApplicationSettingsClient.OnlineSupportAndServicesProcessNotification(
		ThisObject,
		EventName,
		Parameter,
		Source);
	
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

&AtClient
Procedure UseAddressesWebServiceOnChange(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.ApplicationSettings") Then
		OnChangeWebServiceAddressesUsage(UseAddressesWebService);
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowDataSendingOnChange(Item)
	
	OnChangeModeOfDataExportToMonitoringCenter(Item);
	
EndProcedure

&AtClient
Procedure AllowSendDataTo(Item)
	
	OnChangeModeOfDataExportToMonitoringCenter(Item);
	
EndProcedure

&AtClient
Procedure ForbidSendingDataOnChange(Item)
	
	OnChangeModeOfDataExportToMonitoringCenter(Item);
	
EndProcedure

&AtClient
Procedure MonitoringCenterServiceAddressOnChange(Item)
	
	MonitoringCenterServiceAddressOnChangeAtServer(Item.Name);
	
EndProcedure

&AtClient
Procedure UseMorpherDeclinationServiceOnChange(Item)
	
	OnChangeConstantAtServer("UseMorpherDeclinationService");
	ApplicationSettingsClient.OnlineSupportAndServicesOnConstantChange(
		ThisObject,
		Item);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AddressClassifierLoading(Command)
	
	ApplicationSettingsClient.OnlineSupportAndServicesImportAddressClassifier(
		ThisObject,
		Command);
	
EndProcedure

&AtClient
Procedure ClearAddressInfoRecords(Command)
	
	ApplicationSettingsClient.OnlineSupportAndServicesClearAddressInfoRecords(
		ThisObject,
		Command);
	
EndProcedure

&AtClient
Procedure CurrenciesRatesImport(Command)
	
	ApplicationSettingsClient.OnlineSupportAndServicesImportExchangeRates(
		ThisObject,
		Command);
	
EndProcedure

&AtClient
Procedure EnableDisableConversations(Command)
	
	ApplicationSettingsClient.OnlineSupportAndServicesToggleConversations(
		ThisObject,
		Command);
	
EndProcedure

&AtClient
Procedure ConversationsConfigureIntegrationWithExternalSystems(Command)
	
	ApplicationSettingsClient.OnlineSupportAndServicesShowSettingForIntegrationWithExternalSystems(
		ThisObject,
		Command);
	
EndProcedure

&AtClient
Procedure MorpherServiceAccessSetting(Command)
	
	ApplicationSettingsClient.OnlineSupportAndServicesConfigureAccessToMorpher(
		ThisObject,
		Command);
	
EndProcedure

&AtClient
Procedure MonitoringCenter_Settings(Command)
	
	ApplicationSettingsClient.OnlineSupportAndServicesMonitoringCenterSettings(
		ThisObject,
		Command);
	
EndProcedure

&AtClient
Procedure MonitoringCenterSendContactInformation(Command)
	
	ApplicationSettingsClient.OnlineSupportAndServicesMonitoringCenterSendContactInfo(
		ThisObject,
		Command);
	
EndProcedure

&AtClient
Procedure OpenAddIns(Command)
	
	ApplicationSettingsClient.OnlineSupportAndServicesOpenAddIns(
		ThisObject,
		Command);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Server call.

&AtServer
Procedure OnChangeConstantAtServer(ConstantName)
	
	ApplicationSettings.OnlineSupportAndServicesOnConstantChange(
		ThisObject,
		ConstantName,
		ThisObject[ConstantName]);
	
EndProcedure

&AtServer
Procedure AllowDataSendingOnChangeAtServer(TagName, OperationParametersList)
	
	ApplicationSettings.OnlineSupportAndServicesAllowSendDataOnChange(
		ThisObject,
		Items[TagName],
		OperationParametersList);
	
EndProcedure

&AtServer
Procedure MonitoringCenterServiceAddressOnChangeAtServer(TagName)
	
	ApplicationSettings.OnlineSupportAndServicesMonitoringCenterOnChange(
		ThisObject,
		Items[TagName]);
	
EndProcedure

&AtServerNoContext
Procedure OnChangeWebServiceAddressesUsage(UseAddressesWebService)
	
	ApplicationSettings.InternetSupportAndServicesWebServiceUsage(UseAddressesWebService);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client.

&AtClient
Procedure OnChangeModeOfDataExportToMonitoringCenter(Item)
	
	MonitoringCenterParameters = New Structure();
	AllowDataSendingOnChangeAtServer(Item.Name, MonitoringCenterParameters);
	ApplicationSettingsClient.OnlineSupportAndServicesAllowSendDataOnChange(
		ThisObject,
		Item,
		MonitoringCenterParameters);
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

#EndRegion
