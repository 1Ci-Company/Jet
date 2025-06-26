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
	
	UpdateDataItemsAccessKeys = True;
	UpdateAccessKeysRights = True;
	DeleteObsoleteInternalData = True;
	
	If Not StandardSubsystemsServer.ApplicationVersionUpdatedDynamically() Then
		ListsWithRestriction = AccessManagementInternalCached.ListsWithRestriction();
	Else
		ListsWithRestriction = AccessManagementInternal.ActiveAccessRestrictionParameters(Undefined,
			Undefined, False);
	EndIf;
	
	Lists = New Array;
	Lists.Add("Catalog.SetsOfAccessGroups");
	Lists.Add("InformationRegister.AccessRestrictionParameters");
	For Each ListDetails In ListsWithRestriction Do
		FullName = ListDetails.Key;
		Lists.Add(FullName);
		If Not AccessManagementInternal.IsReferenceTableType(FullName) Then
			Continue;
		EndIf;
		EmptyRef = PredefinedValue(FullName + ".EmptyRef");
		AccessUpdateObjectsTypes.Add(EmptyRef, String(TypeOf(EmptyRef)));
		AccessUpdateObjectsTypesTablesNames.Add(EmptyRef, FullName);
	EndDo;
	AccessUpdateObjectsTypes.SortByPresentation();
	
	IDs = Common.MetadataObjectIDs(Lists);
	
	For Each IDDetails In IDs Do
		ListsToUpdate.Add(IDDetails.Value,
			String(IDDetails.Value), True);
	EndDo;
	
	ListsToUpdate.SortByPresentation();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AccessUpdateObjectStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentTypeItem = AccessUpdateObjectsTypes.FindByValue(
		SelectedAccessUpdateObjectType);
	
	If CurrentTypeItem = Undefined Then
		CurrentTypeItem = AccessUpdateObjectsTypes[0];
	EndIf;
	
	AccessUpdateObjectsTypes.ShowChooseItem(
		New NotifyDescription("BeginSelectUpdateObjectFollowUp", ThisObject),
		NStr("en = 'Select data type';"),
		CurrentTypeItem);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ShowAccessToObject(Command)
	
	If Not ValueIsFilled(AccessUpdateObject) Then
		ShowMessageBox(, NStr("en = 'Please select an object.';"));
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateAccessToObject(Command)
	
	ShowMessageBox(, UpdateAccessToObjectAtServer());
	
EndProcedure

&AtClient
Procedure ScheduleListsAccessUpdate(Command)
	
	If Not UpdateDataItemsAccessKeys
	   And Not UpdateAccessKeysRights
	   And Not DeleteObsoleteInternalData Then
	
		ShowMessageBox(, NStr("en = 'Please select at least one update kind.';"));
		Return;
	EndIf;
	
	If Not ScheduleListsAccessUpdateAtServer() Then
		ShowMessageBox(, NStr("en = 'Please select at least one list.';"));
		Return;
	EndIf;
	
	Notify("Write_DataAccessKeysUpdate", New Structure, Undefined);
	Notify("Write_UsersAccessKeysUpdate", New Structure, Undefined);
	
	ShowUserNotification(NStr("en = 'The update is scheduled.';"));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function UpdateAccessToObjectAtServer()
	
	If Not ValueIsFilled(AccessUpdateObject) Then
		Return NStr("en = 'Please select an object.';");
	EndIf;
	
	FullName = AccessUpdateObject.Metadata().FullName();
	TransactionID = New UUID;
	
	Text = "";
	
	UpdateAccessToObjectForUsersKind(AccessUpdateObject,
		FullName, TransactionID, False, Text);
	
	UpdateAccessToObjectForUsersKind(AccessUpdateObject,
		FullName, TransactionID, True, Text);
	
	Return Text;
	
EndFunction

&AtServer
Procedure UpdateAccessToObjectForUsersKind(ObjectReference, FullName, TransactionID, ForExternalUsers, Text)
	
	RestrictionParameters = AccessManagementInternal.RestrictionParameters(FullName,
		TransactionID, ForExternalUsers);
	
	Text = Text + ?(Text = "", "", Chars.LF + Chars.LF);
	If ForExternalUsers Then
		If RestrictionParameters.AccessDenied Then
			Text = Text + NStr("en = 'For external users (access denied):';");
			
		ElsIf RestrictionParameters.RestrictionDisabled Then
			Text = Text + NStr("en = 'For external users (restriction disabled):';");
		Else
			Text = Text + NStr("en = 'For external users:';");
		EndIf;
	Else
		If RestrictionParameters.AccessDenied Then
			Text = Text + NStr("en = 'For users (access denied):';");
			
		ElsIf RestrictionParameters.RestrictionDisabled Then
			Text = Text + NStr("en = 'For users (restriction disabled):';");
		Else
			Text = Text + NStr("en = 'For users:';");
		EndIf;
	EndIf;
	
	SourceAccessKeyObsolete = AccessManagementInternal.SourceAccessKeyObsolete(
		ObjectReference, RestrictionParameters);
	
	HasRightsChanges = False;
	
	AccessManagementInternal.UpdateAccessKeysOfDataItemsOnWrite(ObjectReference,
		RestrictionParameters, TransactionID, True, HasRightsChanges);
	
	If RestrictionParameters.DoNotWriteAccessKeys Then
		If RestrictionParameters.AccessDenied
		 Or RestrictionParameters.RestrictionDisabled Then
			Text = Text + Chars.LF + NStr("en = 'Update not required. Objects of this type don''t require access keys.';");
		Else
			Text = Text + Chars.LF + NStr("en = 'Update not required. Objects of this type use the owner''s access key.';");
		EndIf;
		Return;
	EndIf;
	
	If SourceAccessKeyObsolete Then
		Text = Text + Chars.LF + NStr("en = 'The object access key is updated.';");
	Else
		Text = Text + Chars.LF + NStr("en = '1. Update is not required. The object access key is not expired.';");
	EndIf;
	
	If HasRightsChanges Then
		If RestrictionParameters.HasUsersRestriction Then
			If ForExternalUsers Then
				Text = Text + Chars.LF + NStr("en = '2. Rights to the access key are updated for external users and access groups.';");
			Else
				Text = Text + Chars.LF + NStr("en = '2. Rights to the access key are updated for users and access groups.';");
			EndIf;
		Else
			Text = Text + Chars.LF + NStr("en = '2. Rights to the access key are updated for access groups.';");
		EndIf;
	Else
		If RestrictionParameters.HasUsersRestriction Then
			If ForExternalUsers Then
				Text = Text + Chars.LF + NStr("en = '2. Update is not required. Rights to the access key for external users and access groups are current.';");
			Else
				Text = Text + Chars.LF + NStr("en = '2. Update is not required. Rights to the access key for users and access groups are current.';");
			EndIf;
		Else
			Text = Text + Chars.LF + NStr("en = '2. Update is not required. Rights to the access key for access groups are current.';");
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function ScheduleListsAccessUpdateAtServer()
	
	Lists = New Array;
	For Each ListItem In ListsToUpdate Do
		If ListItem.Check Then
			Lists.Add(ListItem.Value);
		EndIf;
	EndDo;
	
	If Lists.Count() = 0 Then
		Return False;
	EndIf;
	
	If Lists.Count() = ListsToUpdate.Count() Then
		Lists = Undefined;
	EndIf;
	
	If UpdateDataItemsAccessKeys Or UpdateAccessKeysRights Then
		PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters();
		PlanningParameters.IsUpdateContinuation = True;
		If Not UpdateDataItemsAccessKeys Then
			PlanningParameters.DataAccessKeys = False;
		EndIf;
		If Not UpdateAccessKeysRights Then
			PlanningParameters.AllowedAccessKeys = False;
		EndIf;
		PlanningParameters.LongDesc = "ScheduleManualAccessUpdate";
		AccessManagementInternal.ScheduleAccessUpdate(Lists, PlanningParameters);
	EndIf;
	
	If DeleteObsoleteInternalData Then
		PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters();
		PlanningParameters.IsObsoleteItemsDataProcessor = True;
		PlanningParameters.LongDesc = "ScheduleManualAccessUpdate";
		AccessManagementInternal.ScheduleAccessUpdate(Lists, PlanningParameters);
	EndIf;
	
	AccessManagementInternal.SetAccessUpdate(False);
	AccessManagementInternal.SetAccessUpdate(True);
	
	Return True;
	
EndFunction

// AccessUpdateObjectStartChoice event handler continuation.
&AtClient
Procedure BeginSelectUpdateObjectFollowUp(SelectedElement, NotDefined) Export
	
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	
	SelectedAccessUpdateObjectType = SelectedElement.Value;
	If TypeOf(AccessUpdateObject) <> TypeOf(SelectedAccessUpdateObjectType) Then
		AccessUpdateObject = SelectedAccessUpdateObjectType;
	EndIf;
	
	AccessValueStartChoiceCompletion();
	
EndProcedure

// Completes the AccessUpdateObjectStartChoice event handler.
&AtClient
Procedure AccessValueStartChoiceCompletion()
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", AccessUpdateObject);
	
	ListItem = AccessUpdateObjectsTypesTablesNames.FindByValue(
		SelectedAccessUpdateObjectType);
	
	If ListItem = Undefined Then
		Return;
	EndIf;
	ChoiceFormName = ListItem.Presentation + ".ChoiceForm";
	
	OpenForm(ChoiceFormName, FormParameters, Items.AccessUpdateObject);
	
EndProcedure

#EndRegion
