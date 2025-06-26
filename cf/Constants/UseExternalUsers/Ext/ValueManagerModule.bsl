///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

// 
Var PreviousValue2;

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	PreviousValue2 = Constants.UseExternalUsers.Get();
	
	If Value = PreviousValue2 Then
		Return;
	EndIf;
	
	If Not PreviousValue2 And Value And Not UsersInternal.ExternalUsersEmbedded() Then
		ErrorText =
			NStr("en = 'The application does not support external users.';");
		Raise ErrorText;
	EndIf;
	
	If Common.IsStandaloneWorkplace() Then
		ErrorText =
			NStr("en = 'To change the usage of user groups, go to the app in the service.';");
		Raise ErrorText;
		
	ElsIf Common.IsSubordinateDIBNode() Then
		ErrorText =
			NStr("en = 'User groups can only be customized in the master node.';");
		Raise ErrorText;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Constants.UseExternalUserGroups.Refresh();
	
	If Value <> PreviousValue2 Then
		OnToggleExternalUsersUsage(Value);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// For internal use only.
Procedure RegisterChangeUponDataImport(DataElement) Export
	
	If DataElement.Value = Constants.UseExternalUsers.Get() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	UsersInternal.RegisterRefs("UseExternalUsers", True);
	
EndProcedure

// For internal use only.
Procedure ProcessChangeRegisteredUponDataImport() Export
	
	If Common.DataSeparationEnabled() Then
		// Settings changes in SWP are locked and cannot be imported into the data area.
		Return;
	EndIf;
	
	Changes = UsersInternal.RegisteredRefs("UseExternalUsers");
	If Changes.Count() = 0 Then
		Return;
	EndIf;
	
	OnToggleExternalUsersUsage(
		Constants.UseExternalUsers.Get());
	
	UsersInternal.RegisterRefs("UseExternalUsers", Null);
	
EndProcedure

Procedure OnToggleExternalUsersUsage(Var_Value)
	
	UsersInternal.UpdateExternalUsersRoles();
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.UpdateUserRoles(Type("CatalogRef.ExternalUsers"));
		
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		If ModuleAccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
			PlanningParameters = ModuleAccessManagementInternal.AccessUpdatePlanningParameters();
			PlanningParameters.ForUsers = False;
			PlanningParameters.ForExternalUsers = True;
			PlanningParameters.IsUpdateContinuation = True;
			PlanningParameters.LongDesc = "UseExternalUsersOnWrite";
			ModuleAccessManagementInternal.ScheduleAccessUpdate(, PlanningParameters);
		EndIf;
	EndIf;
	
	If Var_Value Then
		UsersInternal.SetShowInListAttributeForAllInfobaseUsers(False);
	Else
		ClearCanSignInAttributeForAllExternalUsers();
	EndIf;
	
	SetPropertySetUsageFlag();
	
EndProcedure

// Clears the FlagShowInList attribute for all infobase users.
Procedure ClearCanSignInAttributeForAllExternalUsers()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ExternalUsers.IBUserID AS Id
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers";
	IDs = Query.Execute().Unload();
	IDs.Indexes.Add("Id");
	
	IBUsers = InfoBaseUsers.GetUsers();
	For Each IBUser In IBUsers Do
		
		If IDs.Find(IBUser.UUID, "Id") <> Undefined
		   And Users.CanSignIn(IBUser) Then
			
			IBUser.StandardAuthentication    = False;
			IBUser.OpenIDAuthentication         = False;
			IBUser.OpenIDConnectAuthentication  = False;
			IBUser.AccessTokenAuthentication = False;
			IBUser.OSAuthentication             = False;
			IBUser.Write();
		EndIf;
	EndDo;
	
	InformationRegisters.UsersInfo.UpdateRegisterData();
	
EndProcedure

Procedure SetPropertySetUsageFlag()
	
	If Not Common.SubsystemExists("StandardSubsystems.Properties") Then
		Return;
	EndIf;
	ModulePropertyManager = Common.CommonModule("PropertyManager");
	
	SetParameters = ModulePropertyManager.PropertySetParametersStructure();
	SetParameters.Used = Value;
	ModulePropertyManager.SetPropertySetParameters("Catalog_ExternalUsers", SetParameters);
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf