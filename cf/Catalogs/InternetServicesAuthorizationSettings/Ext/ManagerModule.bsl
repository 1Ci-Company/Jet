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

#Region Private

// Returns:
//  Structure:
//   * Ref - CatalogRef.InternetServicesAuthorizationSettings
//   * InternetServiceName - String
//   * DataOwner - String
//   * AuthorizationAddress - String
//   * DeviceRegistrationAddress - String
//   * KeyReceiptAddress - String
//   * RedirectAddress - String
//   * PermissionsToRequest - String
//   * UsePKCEAuthenticationKey - Boolean
//   * AppID - String
//   * UseApplicationPassword - Boolean
//   * ApplicationPassword - String
//   * AdditionalAuthorizationParameters - String
//   * AdditionalTokenReceiptParameters - String
//   * ExplanationByRedirectAddress - String
//   * ExplanationByApplicationID - String
//   * ExplanationApplicationPassword - String
//   * AdditionalNote - String
//   * AliasRedirectAddresses - String
//   * ApplicationIDAlias - String
//   * ApplicationPasswordAlias - String
//   * RedirectAddressDefault - String
//   * RedirectionAddressWebClient - String
//
Function SettingsAuthorizationInternetService(InternetServiceName, DataOwner) Export

	AuthorizationSettings = New Structure;
	AuthorizationSettings.Insert("Ref");
	AuthorizationSettings.Insert("InternetServiceName");
	AuthorizationSettings.Insert("DataOwner");
	AuthorizationSettings.Insert("AuthorizationAddress");
	AuthorizationSettings.Insert("DeviceRegistrationAddress");
	AuthorizationSettings.Insert("KeyReceiptAddress");
	AuthorizationSettings.Insert("RedirectAddress");
	AuthorizationSettings.Insert("RedirectionAddressWebClient");
	AuthorizationSettings.Insert("PermissionsToRequest");
	AuthorizationSettings.Insert("UsePKCEAuthenticationKey");
	AuthorizationSettings.Insert("AppID");
	AuthorizationSettings.Insert("UseApplicationPassword");
	AuthorizationSettings.Insert("ApplicationPassword");
	AuthorizationSettings.Insert("AdditionalAuthorizationParameters");
	AuthorizationSettings.Insert("AdditionalTokenReceiptParameters");
	AuthorizationSettings.Insert("ExplanationByRedirectAddress", "");
	AuthorizationSettings.Insert("ExplanationByApplicationID", "");
	AuthorizationSettings.Insert("ExplanationApplicationPassword", "");
	AuthorizationSettings.Insert("AdditionalNote", "");
	AuthorizationSettings.Insert("AliasRedirectAddresses", "");
	AuthorizationSettings.Insert("ApplicationIDAlias", "");
	AuthorizationSettings.Insert("ApplicationPasswordAlias", "");
	AuthorizationSettings.Insert("RedirectAddressDefault", "");
	
	QueryText =
	"SELECT
	|	InternetServicesAuthorizationSettings.Ref,
	|	InternetServicesAuthorizationSettings.AuthorizationAddress,
	|	InternetServicesAuthorizationSettings.KeyReceiptAddress,
	|	InternetServicesAuthorizationSettings.DeviceRegistrationAddress,
	|	InternetServicesAuthorizationSettings.RedirectAddress,
	|	InternetServicesAuthorizationSettings.RedirectionAddressWebClient,
	|	InternetServicesAuthorizationSettings.UsePKCEAuthenticationKey,
	|	InternetServicesAuthorizationSettings.AppID,
	|	InternetServicesAuthorizationSettings.PermissionsToRequest,
	|	InternetServicesAuthorizationSettings.UseApplicationPassword,
	|	InternetServicesAuthorizationSettings.AdditionalAuthorizationParameters,
	|	InternetServicesAuthorizationSettings.AdditionalTokenReceiptParameters,
	|	InternetServicesAuthorizationSettings.InternetServiceName,
	|	InternetServicesAuthorizationSettings.DataOwner
	|FROM
	|	Catalog.InternetServicesAuthorizationSettings AS InternetServicesAuthorizationSettings
	|WHERE
	|	InternetServicesAuthorizationSettings.DataOwner = &DataOwner
	|	AND InternetServicesAuthorizationSettings.InternetServiceName = &InternetServiceName
	|	AND NOT InternetServicesAuthorizationSettings.DeletionMark";
	
	Query = New Query(QueryText);
	Query.SetParameter("DataOwner", DataOwner);
	Query.SetParameter("InternetServiceName", InternetServiceName);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(AuthorizationSettings, Selection);
		AuthorizationSettings.ApplicationPassword = Common.ReadDataFromSecureStorage(Selection.Ref, "ApplicationPassword");
	EndIf;
	
	Return AuthorizationSettings;
	
EndFunction

// Parameters:
//  AuthorizationSettings - See SettingsAuthorizationInternetService
//
Procedure WriteAuthorizationSettings(AuthorizationSettings) Export
	
	VerifyAccessRights("Update", Metadata.Catalogs.EmailAccounts);
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		If ValueIsFilled(AuthorizationSettings.Ref) Then
			Block = New DataLock;
			LockItem = Block.Add("Catalog.InternetServicesAuthorizationSettings");
			LockItem.SetValue("Ref", AuthorizationSettings.Ref);
			Block.Lock();
			
			SettingsAuthorizationObject = AuthorizationSettings.Ref.GetObject();
		Else
			SettingsAuthorizationObject = CreateItem();
		EndIf;
		
		If ValueIsFilled(AuthorizationSettings.Ref) Then
			For Each Item In AuthorizationSettings Do
				If Item.Key = "Ref" Or Item.Key = "ApplicationPassword" Then
					Continue;
				EndIf;
				
				PropertyToCheck = New Structure(Item.Key, null);
				FillPropertyValues(PropertyToCheck, SettingsAuthorizationObject);
				
				If PropertyToCheck[Item.Key] <> null 
					And SettingsAuthorizationObject[Item.Key] <> Item.Value Then
						SettingsAuthorizationObject[Item.Key] = Item.Value;
				EndIf;
			EndDo;
		Else
			FillPropertyValues(SettingsAuthorizationObject, AuthorizationSettings, , "Ref");
		EndIf;
		
		If SettingsAuthorizationObject.Modified() Then
			SettingsAuthorizationObject.Write();
		EndIf;
		If AuthorizationSettings.UseApplicationPassword Then
			ApplicationPassword = Common.ReadDataFromSecureStorage(SettingsAuthorizationObject.Ref, "ApplicationPassword");
			If ApplicationPassword <> AuthorizationSettings.ApplicationPassword Then
				Common.WriteDataToSecureStorage(SettingsAuthorizationObject.Ref, AuthorizationSettings.ApplicationPassword, "ApplicationPassword");
			EndIf;
		EndIf;
	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function Permissions()
	
	Result = New Map;
	
	QueryText = 
	"SELECT
	|	InternetServicesAuthorizationSettings.Ref,
	|	InternetServicesAuthorizationSettings.AuthorizationAddress,
	|	InternetServicesAuthorizationSettings.KeyReceiptAddress,
	|	InternetServicesAuthorizationSettings.DeviceRegistrationAddress
	|FROM
	|	Catalog.InternetServicesAuthorizationSettings AS InternetServicesAuthorizationSettings
	|WHERE
	|	NOT InternetServicesAuthorizationSettings.DeletionMark";
	
	Query = New Query(QueryText);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Permissions = New Array;
		
		AddPermissionForInternetResource(Permissions, Selection.AuthorizationAddress);
		AddPermissionForInternetResource(Permissions, Selection.KeyReceiptAddress);
		AddPermissionForInternetResource(Permissions, Selection.DeviceRegistrationAddress);
				
		Result.Insert(Selection.Ref, Permissions);
	EndDo;
	
	Return Result;
	
EndFunction

Procedure AddPermissionForInternetResource(Permissions, InternetResourceAddress)
	
	If Not ValueIsFilled(InternetResourceAddress) Then
		Return;
	EndIf;
	
	URIStructure = CommonClientServer.URIStructure(InternetResourceAddress);
	
	If Not ValueIsFilled(URIStructure.Schema) Or Not ValueIsFilled(URIStructure.Host) Then
		Return;
	EndIf;
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	Permissions.Add(
		ModuleSafeModeManager.PermissionToUseInternetResource(
			Upper(URIStructure.Schema),
			URIStructure.Host,
			,
			NStr("en = 'Email.';")));
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources.
Procedure OnFillPermissionsToAccessExternalResources(PermissionsRequests) Export

	If Common.DataSeparationEnabled()
	   And Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	For Each PermissionsDetails In Permissions() Do
		PermissionsRequests.Add(ModuleSafeModeManager.RequestToUseExternalResources(
			PermissionsDetails.Value, PermissionsDetails.Key));
	EndDo;
	
EndProcedure

#EndRegion

#EndIf