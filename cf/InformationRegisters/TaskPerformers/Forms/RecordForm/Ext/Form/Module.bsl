///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetItemsState();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	If Not ValueIsFilled(CurrentObject.MainAddressingObject) Then
		CurrentObject.MainAddressingObject = Undefined;
	EndIf;
	If Not ValueIsFilled(CurrentObject.AdditionalAddressingObject) Then
		CurrentObject.AdditionalAddressingObject = Undefined;
	EndIf;
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("WriteRoleAddressing", WriteParameters, Record.PerformerRole);
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PerformerRoleOnChange(Item)
	
	Record.MainAddressingObject = Undefined;
	Record.AdditionalAddressingObject = Undefined;
	SetItemsState();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetItemsState()

	MainAddressingObjectTypes = Undefined;
	AdditionalAddressingObjectTypes = Undefined;
	UsedByAddressingObjects = False;
	UsedWithoutAddressingObjects = False;

	RoleIsSet = Not Record.PerformerRole.IsEmpty();
	If RoleIsSet Then
		RoleProperties = Common.ObjectAttributesValues(Record.PerformerRole,
			"MainAddressingObjectTypes,AdditionalAddressingObjectTypes,UsedByAddressingObjects,UsedWithoutAddressingObjects");
		MainAddressingObjectTypes = Common.ObjectAttributeValue(
			RoleProperties.MainAddressingObjectTypes, "ValueType");
		AdditionalAddressingObjectTypes = Common.ObjectAttributeValue(
			RoleProperties.AdditionalAddressingObjectTypes, "ValueType");
		UsedByAddressingObjects = RoleProperties.UsedByAddressingObjects;
		UsedWithoutAddressingObjects = RoleProperties.UsedWithoutAddressingObjects;
	EndIf;
	MainAddressingObjectTitle = ?(RoleIsSet, String(RoleProperties.MainAddressingObjectTypes), "");
	AdditionalAddressingObjectTitle = ?(RoleIsSet, String(RoleProperties.AdditionalAddressingObjectTypes), "");
	
	MainAddressingObjectTypesAreSet = RoleIsSet And UsedByAddressingObjects
		And ValueIsFilled(MainAddressingObjectTypes);
	TypesOfAditionalAddressingObjectAreSet = RoleIsSet And UsedByAddressingObjects 
		And ValueIsFilled(AdditionalAddressingObjectTypes);
	Items.MainAddressingObject.Enabled = MainAddressingObjectTypesAreSet;
	Items.AdditionalAddressingObject.Enabled = TypesOfAditionalAddressingObjectAreSet;
	
	Items.MainAddressingObject.AutoMarkIncomplete = MainAddressingObjectTypesAreSet
		And Not UsedWithoutAddressingObjects;
	If MainAddressingObjectTypes <> Undefined Then
		Items.MainAddressingObject.TypeRestriction = MainAddressingObjectTypes;
	EndIf;
	Items.MainAddressingObject.Title = MainAddressingObjectTitle;
	
	Items.AdditionalAddressingObject.AutoMarkIncomplete = TypesOfAditionalAddressingObjectAreSet
		And Not UsedWithoutAddressingObjects;
	If AdditionalAddressingObjectTypes <> Undefined Then
		Items.AdditionalAddressingObject.TypeRestriction = AdditionalAddressingObjectTypes;
	EndIf;
	Items.AdditionalAddressingObject.Title = AdditionalAddressingObjectTitle;
	
	SetRoleAvailability(Record.PerformerRole);
EndProcedure

&AtServer
Procedure SetRoleAvailability(Role)
	
	RoleIsAvailableToExternalUsers = GetFunctionalOption("UseExternalUsers");
	If Not RoleIsAvailableToExternalUsers Then
		AssignmentOption = "UsersOnly"; 
		RoleIsAvailableToUsers = True;
	Else
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ExecutorRolesAssignment.UsersType
		|FROM
		|	Catalog.PerformerRoles.Purpose AS ExecutorRolesAssignment
		|WHERE
		|	ExecutorRolesAssignment.Ref = &Ref";
		
		Query.SetParameter("Ref", Role);
		
		QueryResult = Query.Execute();
		SelectionDetailRecords = QueryResult.Select();
		
		RoleIsAvailableToUsers = False;
		ExternalUsersAreNotAssignedForRole = True;
		While SelectionDetailRecords.Next() Do
			If SelectionDetailRecords.UsersType = Catalogs.Users.EmptyRef() Then
				RoleIsAvailableToUsers = True;
			Else
				ExternalUsersAreNotAssignedForRole = False;
			EndIf;
		EndDo;
		
		If ExternalUsersAreNotAssignedForRole Then
			RoleIsAvailableToExternalUsers = False;
		EndIf;
	EndIf;
	
	If RoleIsAvailableToExternalUsers And RoleIsAvailableToUsers Then
		Items.Performer.ChooseType = True;
	Else
		If RoleIsAvailableToExternalUsers And TypeOf(Record.Performer) = Type("CatalogRef.Users") Then
			Record.Performer = Catalogs.ExternalUsers.EmptyRef();
		ElsIf TypeOf(Record.Performer) = Type("CatalogRef.ExternalUsers") Then
			Record.Performer = Catalogs.Users.EmptyRef();
		EndIf;
		Items.Performer.ChooseType = False;
	EndIf;
	
EndProcedure


#EndRegion
