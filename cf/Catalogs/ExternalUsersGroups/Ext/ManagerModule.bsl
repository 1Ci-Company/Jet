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

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchEditObjects

// Returns the object attributes that are not recommended to be edited
// using a bulk attribute modification data processor.
//
// Returns:
//  Array of String
//
Function AttributesToSkipInBatchProcessing() Export
	
	NotAttributesToEdit = New Array;
	NotAttributesToEdit.Add("AuthorizationObjectsType");
	NotAttributesToEdit.Add("AllAuthorizationObjects");
	
	Return NotAttributesToEdit;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.TextForExternalUsers1 =
	"AllowReadUpdate
	|WHERE
	|	Ref = VALUE(Catalog.ExternalUsersGroups.AllExternalUsers)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region Private

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling
// 
// Parameters:
//  Settings - See InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.Settings
//
Procedure OnSetUpInitialItemsFilling(Settings) Export
	
	Settings.OnInitialItemFilling = False;
	
EndProcedure

// See also InfobaseUpdateOverridable.OnInitialItemsFilling
// 
// Parameters:
//   LanguagesCodes - See InfobaseUpdateOverridable.OnInitialItemsFilling.LanguagesCodes
//   Items - See InfobaseUpdateOverridable.OnInitialItemsFilling.Items
//   TabularSections - See InfobaseUpdateOverridable.OnInitialItemsFilling.TabularSections
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items, TabularSections) Export

	Item = Items.Add();
	Item.PredefinedDataName = "AllExternalUsers";
	Item.Description = NStr("en = 'All external users';", Common.DefaultLanguageCode());
	
	BlankRefs = UsersInternalCached.BlankRefsOfAuthorizationObjectTypes();
	For Each EmptyRef In BlankRefs Do
		AssignmentTable = TabularSections.Purpose; // ValueTable
		NewRow = AssignmentTable.Add();
		NewRow.UsersType = EmptyRef;
	EndDo;
	Item.Purpose = TabularSections.Purpose;
	
EndProcedure

// Returns the UUID of the predefined group "AllExternalUsers".
// 
//
// Returns:
//  String - UUID string.
//
Function AllExternalUsersGroupID() Export
	
	Return "dce2cab1-46b8-45b8-844b-d10b62597e14";
	
EndFunction

#EndRegion


#EndIf
