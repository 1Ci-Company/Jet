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
	
	SetConditionalAppearance();
	
	Role = Parameters.Role;
	SetRoleAvailability(Role);
	MainAddressingObject = Parameters.MainAddressingObject;
	If MainAddressingObject = Undefined Or MainAddressingObject = "" Then
		Items.AdditionalAddressingObject.Visible = False;
		Items.List.Header = False;
		Items.MainAddressingObject.Visible = False;
	Else
		Items.MainAddressingObject.Title = MainAddressingObject.Metadata().ObjectPresentation;
		If Not Parameters.Role.IsEmpty() Then
			AdditionalAddressingObject = Common.ObjectAttributeValue(
				Parameters.Role, "AdditionalAddressingObjectTypes");
		Else
			AdditionalAddressingObject = ChartsOfCharacteristicTypes.TaskAddressingObjects.EmptyRef();
		EndIf;
		Items.AdditionalAddressingObject.Visible = Not AdditionalAddressingObject.IsEmpty();
		If Not AdditionalAddressingObject.IsEmpty() Then 
			AddressingObjectProperties = Common.ObjectAttributesValues(AdditionalAddressingObject, 
				"Description,ValueType");
			Items.AdditionalAddressingObject.Title = AddressingObjectProperties.Description;
			AdditionalAddressingObjectTypes = AddressingObjectProperties.ValueType;
		EndIf;
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Users assigned to role ""%1""';"), Role);
	
	SetRecordSetFilter();
	
	
EndProcedure

&AtServer
Procedure SetRoleAvailability(Role)
	
	RoleIsAvailableToExternalUsers = GetFunctionalOption("UseExternalUsers");
	If Not RoleIsAvailableToExternalUsers Then
		RoleIsAvailableToUsers = True;
		Return;
	EndIf;
	
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
	ExternalUsersAreNotAssignedForRole = True;
	
	If Not QueryResult.IsEmpty() Then
		SelectionDetailRecords = QueryResult.Select();
		
		RoleIsAvailableToUsers = False;
		
		While SelectionDetailRecords.Next() Do
			Purpose.Add(SelectionDetailRecords.UsersType);
			If SelectionDetailRecords.UsersType = Catalogs.Users.EmptyRef() Then
				RoleIsAvailableToUsers = True;
			Else
				ExternalUsersAreNotAssignedForRole = False;
			EndIf;
		
		EndDo;
	Else
		RoleIsAvailableToUsers = True;
	EndIf;
	
	If ExternalUsersAreNotAssignedForRole Then
		RoleIsAvailableToExternalUsers = False;
	EndIf;
	
	If RoleIsAvailableToExternalUsers And RoleIsAvailableToUsers Then
		Items.Performer.ChooseType = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	SetRecordSetFilter();

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtServer
Procedure SetRecordSetFilter()
	
	RecordSetObject = FormAttributeToValue("RecordSet");
	RecordSetObject.Filter.MainAddressingObject.Set(MainAddressingObject);
	RecordSetObject.Filter.PerformerRole.Set(Role);
	RecordSetObject.Read();
	ValueToFormAttribute(RecordSetObject, "RecordSet");
	
	RolePerformers = RecordSetObject.UnloadColumn("Performer");
	RolesAssigneesProperties = Common.ObjectsAttributeValue(RolePerformers, "Invalid");
	For Each Record In RecordSet Do
		Record.Invalid = RolesAssigneesProperties[Record.Performer];
	EndDo;

EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	For Each LinePerformer In RecordSet Do
		If Not ValueIsFilled(LinePerformer.Performer) Then
			ShowMessageBox(, NStr("en = 'Specify assignees.';"));
			Cancel = True;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("WriteRoleAddressing", WriteParameters, RecordSet);
	
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

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)
	If Role <> Undefined Then
		Item.CurrentData.PerformerRole = Role;
	EndIf;
	If MainAddressingObject <> Undefined Then
		Item.CurrentData.MainAddressingObject = MainAddressingObject;
	EndIf;
	
	Item.CurrentData.Invalid = DetermineUsersValidity(Item.CurrentData.Performer);
	
EndProcedure

&AtClient
Procedure ListOnStartEdit(Item, NewRow, Copy)
	
	If Items.AdditionalAddressingObject.Visible Then
		Items.AdditionalAddressingObject.TypeRestriction = AdditionalAddressingObjectTypes;
	EndIf;
	
	If Item.CurrentData <> Undefined And Not ValueIsFilled(Item.CurrentData.Performer) Then
		If RoleIsAvailableToUsers And Not RoleIsAvailableToExternalUsers Then
			Item.CurrentData.Performer = PredefinedValue("Catalog.Users.EmptyRef");
		ElsIf Not RoleIsAvailableToUsers And RoleIsAvailableToExternalUsers Then
			Item.CurrentData.Performer = PredefinedValue("Catalog.ExternalUsers.EmptyRef");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	UsersList = DetermineUsersValidity(ValueSelected);
	For Each Value In UsersList Do
		
		If RecordSet.FindRows(New Structure("Performer", Value.Key)).Count() > 0 Then
			Continue;
		EndIf;
			
		Performer = RecordSet.Add();
		
		Performer.Performer = Value.Key;
		Performer.Invalid = Value.Value;
		If Role <> Undefined Then
			Performer.PerformerRole = Role;
		EndIf;
		If MainAddressingObject <> Undefined Then
			Performer.MainAddressingObject = MainAddressingObject;
		EndIf;
		Modified = True;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtServerNoContext
Function DetermineUsersValidity(UsersList)
	
	If ValueIsFilled(UsersList) Then
		If TypeOf(UsersList) = Type("Array") Then
			Result = New Map;
			For Each Value In UsersList Do
				Result.Insert(Value, Value.Invalid);
			EndDo;
			Return Result;
		Else
			Return UsersList.Invalid;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

&AtClient
Procedure Pick(Command)
	
	If RoleIsAvailableToExternalUsers And RoleIsAvailableToUsers Then
		Case = New ValueList;
		Case.Add("ExternalUser", NStr("en = 'External user';"));
		Case.Add("User", NStr("en = 'User';"));
		NotifyDescription = New NotifyDescription("AfterUserTypeChoice", ThisObject);
		Case.ShowChooseItem(NotifyDescription, NStr("en = 'Select user type';"));
	ElsIf RoleIsAvailableToUsers Then
		OpenSelectionForm("User");
	ElsIf RoleIsAvailableToExternalUsers Then
		OpenSelectionForm("ExternalUser");
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterUserTypeChoice(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		OpenSelectionForm(Result.Value);
	EndIf;
EndProcedure

&AtClient
Procedure OpenSelectionForm(OpeningMode)
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.FoldersAndItems);
	ChoiceFormParameters.Insert("CloseOnChoice", False);
	ChoiceFormParameters.Insert("CloseOnOwnerClose", True);
	ChoiceFormParameters.Insert("MultipleChoice", True);
	ChoiceFormParameters.Insert("ChoiceMode", True);
	ChoiceFormParameters.Insert("SelectGroups", False);
	ChoiceFormParameters.Insert("UsersGroupsSelection", False);
		
	If OpeningMode = "ExternalUser" Then
		ChoiceFormParameters.Insert("Purpose", Purpose.UnloadValues());
		OpenForm("Catalog.ExternalUsers.ChoiceForm", ChoiceFormParameters, Items.List);
	Else
		OpenForm("Catalog.Users.ChoiceForm", ChoiceFormParameters, Items.List);
	EndIf;

EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("Performer");
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RecordSet.Invalid");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", Metadata.StyleItems.InaccessibleCellTextColor.Value);
	
EndProcedure

#EndRegion
