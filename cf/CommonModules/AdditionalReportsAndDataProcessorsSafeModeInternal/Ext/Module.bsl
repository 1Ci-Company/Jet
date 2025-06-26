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

// Returns a template of a security profile name for an external module.
// The function must return the same value every time it is called.
//
// Parameters:
//  ExternalModule - AnyRef - a reference to an external module.
//
// Returns:
//   String - a template of a security profile name containing characters
//  "%1". These characters are replaced with a unique ID later.
//
Function SecurityProfileNameTemplate(Val ExternalModule) Export
	
	Kind = Common.ObjectAttributeValue(ExternalModule, "Kind");
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		
		Return "AdditionalReport_%1"; // Not localizable.
		
	Else
		
		Return "AdditionalDataProcessor_%1"; // Not localizable.
		
	EndIf;
	
EndFunction

// Returns an external module icon.
//
// Parameters:
//  ExternalModule - AnyRef - a reference to an external module
//
// Returns:
//   Picture
//
Function ExternalModuleIcon(Val ExternalModule) Export
	
	Kind = Common.ObjectAttributeValue(ExternalModule, "Kind");
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		
		Return PictureLib.Report;
		
	Else
		
		Return PictureLib.DataProcessor;
		
	EndIf;
	
EndFunction

// Returns a dictionary of presentations for external container modules.
//
// Returns:
//   Structure:
//   * Nominative - String - an external module type presentation in nominative case,
//   * Genitive - String - an external module type presentation in genitive case.
//
Function ExternalModuleContainerDictionary() Export
	
	Result = New Structure();
	
	Result.Insert("Nominative", NStr("en = 'Additional report or data processor';"));
	Result.Insert("Genitive", NStr("en = 'Additional report or data processor';"));
	
	Return Result;
	
EndFunction

// Returns an array of reference metadata objects that can be used
//  as external module containers.
//
// Returns:
//   Array of MetadataObject
//
Function ExternalModulesContainers() Export
	
	Result = New Array();
	Result.Add(Metadata.Catalogs.AdditionalReportsAndDataProcessors);
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See SSLSubsystemsIntegration.OnRegisterExternalModulesManagers
Procedure OnRegisterExternalModulesManagers(Managers) Export
	
	Managers.Add(AdditionalReportsAndDataProcessorsSafeModeInternal);
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources.
Procedure OnFillPermissionsToAccessExternalResources(PermissionsRequests) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	NewRequests = AdditionalDataProcessorsPermissionRequests();
	CommonClientServer.SupplementArray(PermissionsRequests, NewRequests);
	
EndProcedure

#EndRegion

#Region Private

Function AdditionalDataProcessorsPermissionRequests(Val FOValue = Undefined)
	
	If FOValue = Undefined Then
		FOValue = GetFunctionalOption("UseAdditionalReportsAndDataProcessors");
	EndIf;
	
	Result = New Array();
	
	QueryText =
		"SELECT DISTINCT
		|	AdditionalReportsAndPermissionProcessing.Ref AS Ref
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors.Permissions AS AdditionalReportsAndPermissionProcessing
		|WHERE
		|	AdditionalReportsAndPermissionProcessing.Ref.Publication <> &Publication";
	Query = New Query(QueryText);
	Query.SetParameter("Publication", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Object = Selection.Ref.GetObject();
		NewRequests = AdditionalDataProcessorPermissionRequests(Object, FOValue);
		CommonClientServer.SupplementArray(Result, NewRequests);
		
	EndDo;
	
	Return Result;
	
EndFunction

// Parameters:
//   Object - CatalogObject.AdditionalReportsAndDataProcessors
//   FOValue - Boolean
//              - Undefined
//   DeletionMark - Boolean
// Returns:
//   Array
//
Function AdditionalDataProcessorPermissionRequests(Val Object, Val FOValue = Undefined, Val DeletionMark = Undefined)
	
	PermissionsInData = Object.Permissions.Unload();
	PermissionsToRequest = New Array();
	
	If FOValue = Undefined Then
		FOValue = GetFunctionalOption("UseAdditionalReportsAndDataProcessors");
	EndIf;
	
	If DeletionMark = Undefined Then
		DeletionMark = Object.DeletionMark;
	EndIf;
	
	ClearPermissions1 = False;
	
	If Not FOValue Then
		ClearPermissions1 = True;
	EndIf;
	
	If Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled Then
		ClearPermissions1 = True;
	EndIf;
	
	If DeletionMark Then
		ClearPermissions1 = True;
	EndIf;
	
	ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
	
	If Not ClearPermissions1 Then
		
		HadPermissions = ModuleSafeModeManagerInternal.ExternalModuleAttachmentMode(Object.Ref) <> Undefined;
		HasPermissions1 = Object.Permissions.Count() > 0;
		
		If HadPermissions Or HasPermissions1 Then
			
			PermissionsToRequest = New Array();
			For Each PermissionInData In PermissionsInData Do
				Resolution = XDTOFactory.Create(XDTOFactory.Type(ModuleSafeModeManagerInternal.Package(), PermissionInData.PermissionKind));
				PropertiesInData = PermissionInData.Parameters.Get();
				FillPropertyValues(Resolution, PropertiesInData);
				PermissionsToRequest.Add(Resolution);
			EndDo;
			
		EndIf;
		
	EndIf;
	
	Return ModuleSafeModeManagerInternal.PermissionsRequestForExternalModule(Object.Ref, PermissionsToRequest);
	
EndFunction

#EndRegion