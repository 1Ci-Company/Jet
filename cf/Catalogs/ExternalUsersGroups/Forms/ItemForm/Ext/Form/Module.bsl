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
	
	If Not UsersInternal.ExternalUsersEmbedded() Then
		Raise NStr("en = 'This application version does not support external users.';");
	EndIf;
	
	SetConditionalAppearance();
	
	If Not ValueIsFilled(Object.Ref) Then
		ProcessRolesInterface("FillRoles", Object.Roles);
		ProcessRolesInterface("SetUpRoleInterfaceOnFormCreate", False);
	EndIf;
	
	// Preparing auxiliary data.
	
	If Not ValueIsFilled(Object.Ref) Then
		AllAuthorizationObjects = Common.ObjectAttributeValue(Object.Parent,
			"AllAuthorizationObjects");
		AllAuthorizationObjects = ?(AllAuthorizationObjects = Undefined, False, AllAuthorizationObjects);
		
		If AllAuthorizationObjects
		 Or Object.Parent = ExternalUsers.AllExternalUsersGroup() Then
			
			Object.Parent = Catalogs.ExternalUsersGroups.EmptyRef();
		EndIf;
		
	EndIf;
	
	SelectGroupMembersTypesAvailableForSelection();
	
	DefineActionsOnForm();
	
	// Making the properties always visible.
	
	Items.Description.Visible     = ValueIsFilled(ActionsOnForm.ItemProperties);
	Items.Parent.Visible         = ValueIsFilled(ActionsOnForm.ItemProperties);
	Items.Comment.Visible      = ValueIsFilled(ActionsOnForm.ItemProperties);
	Items.Content.Visible           = ValueIsFilled(ActionsOnForm.GroupComposition1);
	Items.RolesRepresentation.Visible = ValueIsFilled(ActionsOnForm.Roles);
	
	GroupMembers = ?(Object.AllAuthorizationObjects, "AllSpecifiedKindsUsers", "SelectedUsersOfSpecifiedKinds");
	
	IsAllExternalUsersGroup = 
		Object.Ref = ExternalUsers.AllExternalUsersGroup();
	
	If IsAllExternalUsersGroup Then
		Items.Description.ReadOnly = True;
		Items.Parent.ReadOnly     = True;
		Items.Comment.ReadOnly  = True;
		Items.ExternalUsersInGroup.ReadOnly = True;
	EndIf;
	
	If ReadOnly
	 Or Not IsAllExternalUsersGroup
	     And ActionsOnForm.Roles             <> "Edit"
	     And ActionsOnForm.GroupComposition1     <> "Edit"
	     And ActionsOnForm.ItemProperties <> "Edit"
	 Or IsAllExternalUsersGroup
	   And UsersInternal.CannotEditRoles() Then
		
		ReadOnly = True;
	EndIf;
	
	If ActionsOnForm.ItemProperties <> "Edit" Then
		Items.Description.ReadOnly = True;
		Items.Parent.ReadOnly     = True;
		Items.Comment.ReadOnly  = True;
	EndIf;
	
	If ActionsOnForm.GroupComposition1 <> "Edit" Then
		Items.ExternalUsersInGroup.ReadOnly = True;
	EndIf;
	
	ProcessRolesInterface(
		"SetRolesReadOnly",
		    UsersInternal.CannotEditRoles()
		Or ActionsOnForm.Roles <> "Edit");
	
	UpdateInvalidUsersList(True);
	FillUserStatuses();
	
	If ValueIsFilled(Object.Parent) And Not ValueIsFilled(Object.Ref) Then
		Parent_Assignment = Common.ObjectAttributeValue(Object.Parent, "Purpose");
		If TypeOf(Parent_Assignment) = Type("QueryResult") Then
			Object.Purpose.Load(Parent_Assignment.Unload());
		Else
			Object.Purpose.Clear();
		EndIf;
	EndIf;
	UsersInternal.UpdateAssignmentOnCreateAtServer(ThisObject, False);
	
	SetPropertiesAvailability(ThisObject);
	
	If Common.IsStandaloneWorkplace() Then
		ReadOnly = True;
	EndIf;
	
	If Common.IsMobileClient() Then
		Items.HeaderGroup.ItemsAndTitlesAlign = ItemsAndTitlesAlignVariant.ItemsRightTitlesLeft;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ProcessRolesInterface("FillRoles", Object.Roles);
	ProcessRolesInterface("SetUpRoleInterfaceOnReadAtServer", True);
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Filling object roles from the collection.
	CurrentObject.Roles.Clear();
	For Each Role In RolesCollection Do
		CurrentObject.Roles.Add().Role = Common.MetadataObjectID(
			"Role." + Role.Role);
	EndDo;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillUserStatuses();
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_ExternalUsersGroups", New Structure, Object.Ref);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	AttributesNotToCheck = New Array;
	VerifiedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Checking whether the metadata contains roles.
	VerifiedObjectAttributes.Add("Roles.Role");
	If Not Items.Roles.ReadOnly Then
		TreeItems = Roles.GetItems();
		For Each Item In TreeItems Do
			If Not Item.Check Then
				Continue;
			EndIf;
			If Item.IsNonExistingRole Then
				CommonClientServer.AddUserError(Errors,
					"Roles[%1].RolesSynonym",
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Role ""%1"" does not exist.';"), 
						Item.Synonym),
					"Roles",
					TreeItems.IndexOf(Item),
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Non-existent role ""%1"" in line %2.';"), 
						Item.Synonym, "%1"));
			EndIf;
			If Item.IsUnavailableRole Then
				CommonClientServer.AddUserError(Errors,
					"Roles[%1].RolesSynonym",
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Role ""%1"" is unavailable to external users.';"), 
						Item.Synonym),
					"Roles",
					TreeItems.IndexOf(Item),
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Role ""%1"" in line %2 is unavailable to external users.';"), 
						Item.Synonym, "%1"));
			EndIf;
		EndDo;
	EndIf;
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
	AttributesNotToCheck.Add("Object");
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, AttributesNotToCheck);
	
	CurrentObject = FormAttributeToValue("Object");
	
	CurrentObject.AdditionalProperties.Insert(
		"VerifiedObjectAttributes", VerifiedObjectAttributes);
	
	If Not CurrentObject.CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("SetUpRoleInterfaceOnLoadSettings", Settings);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure MembersListOnChange(Item)
	
	Object.AllAuthorizationObjects = (GroupMembers = "AllSpecifiedKindsUsers");
	If Object.AllAuthorizationObjects Then
		Object.Content.Clear();
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure ParentOnChange(Item)
	
	Object.AllAuthorizationObjects = False;
	SelectGroupMembersTypesAvailableForSelection();
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure ParentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("SelectParent");
	
	OpenForm("Catalog.ExternalUsersGroups.ChoiceForm", FormParameters, Items.Parent);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersRoles

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtClient
Procedure RolesCheckOnChange(Item)
	
	If Items.Roles.CurrentData <> Undefined Then
		ProcessRolesInterface("UpdateRoleComposition");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersContent

&AtClient
Procedure ContentChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	Object.Content.Clear();
	If TypeOf(ValueSelected) = Type("Array") Then
		For Each Value In ValueSelected Do
			ProcessExternalUserSelection(Value);
		EndDo;
	Else
		ProcessExternalUserSelection(ValueSelected);
	EndIf;
	FillUserStatuses();
	Items.Content.Refresh();
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure ContentOnChange(Item)
	SetPropertiesAvailability(ThisObject);
EndProcedure

&AtClient
Procedure ContentExternalUserStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectPickUsers(False);
	
EndProcedure

&AtClient
Procedure ContentDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	UserMessage = MoveUserToGroup(DragParameters.Value, Object.Ref);
	If UserMessage <> Undefined Then
		ShowUserNotification(
			NStr("en = 'Move users';"), , UserMessage, PictureLib.DialogInformation);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure PickExternalUsers(Command)

	SelectPickUsers(True);
	
EndProcedure

&AtClient
Procedure ShowInvalidUsers(Command)
	
	UpdateInvalidUsersList(False);
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure SortAsc(Command)
	CompositionSortRows("Ascending");
EndProcedure

&AtClient
Procedure SortDesc(Command)
	CompositionSortRows("Descending");
EndProcedure

&AtClient
Procedure MoveUp(Command)
	CompositionMoveRow("Up");
EndProcedure

&AtClient
Procedure MoveDown(Command)
	CompositionMoveRow("Down");
EndProcedure

&AtClient
Procedure SelectPurpose(Command)
	
	NotifyDescription = New NotifyDescription("AfterAssignmentChoice", ThisObject);
	UsersInternalClient.SelectPurpose(ThisObject, NStr("en = 'Select users type';"), False, False, NotifyDescription);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtClient
Procedure ShowSelectedRolesOnly(Command)
	
	ProcessRolesInterface("SelectedRolesOnly");
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure RolesBySubsystemsGroup(Command)
	
	ProcessRolesInterface("GroupBySubsystems");
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure AddRoles(Command)
	
	ProcessRolesInterface("UpdateRoleComposition", "IncludeSelected");
	
	UsersInternalClient.ExpandRoleSubsystems(ThisObject, False);
	
EndProcedure

&AtClient
Procedure RemoveRoles(Command)
	
	ProcessRolesInterface("UpdateRoleComposition", "ClearMarked");
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ContentExternalUser.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Content.Invalid");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);

EndProcedure

&AtServer
Function MoveUserToGroup(UsersArray, NewParentGroup)
	
	MovedUsersArray = New Array;
	UnmovedUsersArray = New Array;
	For Each UserRef In UsersArray Do
		
		FilterParameters = New Structure("ExternalUser", UserRef);
		If TypeOf(UserRef) = Type("CatalogRef.ExternalUsers")
			And Object.Content.FindRows(FilterParameters).Count() = 0 Then
			Object.Content.Add().ExternalUser = UserRef;
			MovedUsersArray.Add(UserRef);
		EndIf;
		
	EndDo;
	
	Return UsersInternal.CreateUserMessage(
		MovedUsersArray, NewParentGroup, False, UnmovedUsersArray);
	
EndFunction

&AtServer
Procedure SelectGroupMembersTypesAvailableForSelection()
	
	If ValueIsFilled(Object.Parent)
		And Object.Parent <> ExternalUsers.AllExternalUsersGroup() Then
		
		Items.UsersType.Enabled = False;
		GroupMembers = Items.GroupMembers.ChoiceList.FindByValue("SelectedUsersOfSpecifiedKinds").Value;
		
	Else
		
		Items.UsersType.Enabled = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DefineActionsOnForm()
	
	ActionsOnForm = New Structure;
	
	// "", "View," "Edit."
	ActionsOnForm.Insert("Roles", "");
	
	// "", "View," "Edit."
	ActionsOnForm.Insert("GroupComposition1", "");
	
	// "", "View," "Edit."
	ActionsOnForm.Insert("ItemProperties", "");
	
	If Users.IsFullUser()
	 Or AccessRight("Insert", Metadata.Catalogs.Users) Then
		// Administrator.
		ActionsOnForm.Roles             = "Edit";
		ActionsOnForm.GroupComposition1     = "Edit";
		ActionsOnForm.ItemProperties = "Edit";
		
	ElsIf AccessRight("Edit", Metadata.Catalogs.ExternalUsersGroups) Then
		// Can manage external users.
		ActionsOnForm.Roles             = "";
		ActionsOnForm.GroupComposition1     = "Edit";
		ActionsOnForm.ItemProperties = "Edit";
		
	Else
		// Can read external users.
		ActionsOnForm.Roles             = "";
		ActionsOnForm.GroupComposition1     = "View";
		ActionsOnForm.ItemProperties = "View";
	EndIf;
	
	UsersInternal.OnDefineActionsInForm(Object.Ref, ActionsOnForm);
	
	// Checking action names in the form.
	If StrFind(", View, Edit,", ", " + ActionsOnForm.Roles + ",") = 0 Then
		ActionsOnForm.Roles = "";
	ElsIf ActionsOnForm.Roles = "Edit"
	        And UsersInternal.CannotEditRoles() Then
		ActionsOnForm.Roles = "View";
	EndIf;
	If StrFind(", View, Edit,", ", " + ActionsOnForm.GroupComposition1 + ",") = 0 Then
		ActionsOnForm.IBUserProperies = "";
	EndIf;
	If StrFind(", View, Edit,", ", " + ActionsOnForm.ItemProperties + ",") = 0 Then
		ActionsOnForm.ItemProperties = "";
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetPropertiesAvailability(Form)
	
	Items = Form.Items;
	
	Items.Content.ReadOnly = Form.Object.AllAuthorizationObjects;
	
	CommandsAvailability =
		Not Form.ReadOnly
		And Not Items.ExternalUsersInGroup.ReadOnly
		And Not Items.Content.ReadOnly
		And Items.Content.Enabled
		And Form.Object.Purpose.Count() <> 0;
	
	GroupComposition1 = Form.Object.Content;
	
	FilterParameters = New Structure;
	FilterParameters.Insert("Invalid", False);
	HasValidUsers = GroupComposition1.FindRows(FilterParameters).Count() > 0;
	
	FilterParameters.Insert("Invalid", True);
	HasInvalidUsers = GroupComposition1.FindRows(FilterParameters).Count() > 0;
	
	MoveCommandsAvailability =
		HasValidUsers
		Or (HasInvalidUsers
			And Items.ShowInvalidUsers.Check);
	
	Items.Content.ReadOnly		                = Not CommandsAvailability;
	
	Items.CompositionPick.Enabled                = CommandsAvailability;
	Items.CompositionContextMenuSelect.Enabled = CommandsAvailability;
	
	Items.ContentSortAsc.Enabled = CommandsAvailability;
	Items.ContentSortDesc.Enabled    = CommandsAvailability;
	
	Items.ContentMoveUp.Enabled         = CommandsAvailability And MoveCommandsAvailability;
	Items.ContentMoveDown.Enabled          = CommandsAvailability And MoveCommandsAvailability;
	Items.ContentContextMenuMoveUp.Enabled = CommandsAvailability And MoveCommandsAvailability;
	Items.ContentContextMenuMoveDown.Enabled  = CommandsAvailability And MoveCommandsAvailability;
	
EndProcedure

&AtServer
Procedure DeleteNontypicalExternalUsers()
	
	Query = New Query;
	Query.SetParameter("SelectedExternalUsers", Object.Content.Unload().UnloadColumn("ExternalUser"));
	Query.SetParameter("UsersTypes", Object.Purpose.Unload());
	
	Query.Text =
	"SELECT
	|	UsersTypes.UsersType
	|INTO UsersTypes
	|FROM
	|	&UsersTypes AS UsersTypes
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExternalUsers.Ref
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	NOT FALSE IN
	|			(SELECT TOP 1
	|				FALSE
	|			FROM
	|				UsersTypes AS UsersTypes
	|			WHERE
	|				VALUETYPE(UsersTypes.UsersType) = VALUETYPE(ExternalUsers.AuthorizationObject))
	|	AND ExternalUsers.Ref IN(&SelectedExternalUsers)";
	
	BeginTransaction();
	Try
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			FoundRows = Object.Content.FindRows(
				New Structure("ExternalUser", Selection.Ref));
			
			For Each FoundRow In FoundRows Do
				Object.Content.Delete(Object.Content.IndexOf(FoundRow));
			EndDo;
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtClient
Procedure SelectPickUsers(Pick)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", ?(
		Items.Content.CurrentData = Undefined,
		Undefined,
		Items.Content.CurrentData.ExternalUser));
	
	If Pick Then
		FormParameters.Insert("CloseOnChoice", False);
		FormParameters.Insert("MultipleChoice", True);
		FormParameters.Insert("AdvancedPick", True);
		FormParameters.Insert("ExtendedPickFormParameters", ExtendedPickFormParameters());
	EndIf;
	
	BlankRefsArray = New Array;
	For Each AssignmentRow1 In Object.Purpose Do
		BlankRefsArray.Add(AssignmentRow1.UsersType);
	EndDo;
	
	FormParameters.Insert("Purpose", BlankRefsArray);
	
	OpenForm(
		"Catalog.ExternalUsers.ChoiceForm",
		FormParameters,
		?(Pick,
			Items.Content,
			Items.ContentExternalUser));
	
EndProcedure

&AtClient
Procedure ProcessExternalUserSelection(ValueSelected)
	
	If TypeOf(ValueSelected) = Type("CatalogRef.ExternalUsers") Then
		Object.Content.Add().ExternalUser = ValueSelected;
	EndIf;
	
EndProcedure

&AtServer
Function ExtendedPickFormParameters()
	
	PickingParameters = UsersInternal.NewParametersOfExtendedPickForm();
	PickingParameters.PickFormHeader = NStr("en = 'Pick external user group members';");
	
	PickingParameters.SelectedUsers =
		Object.Content.Unload(, "ExternalUser").UnloadColumn("ExternalUser");
	
	Return PutToTempStorage(PickingParameters, UUID);
	
EndFunction

&AtServer
Procedure FillUserStatuses()
	
	For Each GroupCompositionRow In Object.Content Do
		GroupCompositionRow.Invalid = 
			Common.ObjectAttributeValue(GroupCompositionRow.ExternalUser, "Invalid");
	EndDo;
	
EndProcedure

&AtServer
Procedure UpdateInvalidUsersList(BeforeOpenForm)
	
	Items.ShowInvalidUsers.Check = ?(BeforeOpenForm, False,
		Not Items.ShowInvalidUsers.Check);
	
	Filter = New Structure;
	
	If Not Items.ShowInvalidUsers.Check Then
		Filter.Insert("Invalid", False);
		Items.Content.RowFilter = New FixedStructure(Filter);
	Else
		Items.Content.RowFilter = New FixedStructure();
	EndIf;
	
EndProcedure

&AtServer
Procedure CompositionSortRows(SortType)
	If Not Items.ShowInvalidUsers.Check Then
		Items.Content.RowFilter = New FixedStructure();
	EndIf;
	
	If SortType = "Ascending" Then
		Object.Content.Sort("ExternalUser Asc");
	Else
		Object.Content.Sort("ExternalUser Desc");
	EndIf;
	
	If Not Items.ShowInvalidUsers.Check Then
		Filter = New Structure;
		Filter.Insert("Invalid", False);
		Items.Content.RowFilter = New FixedStructure(Filter);
	EndIf;
EndProcedure

&AtServer
Procedure CompositionMoveRow(MovementDirection)
	
	String = Object.Content.FindByID(Items.Content.CurrentRow);
	If String = Undefined Then
		Return;
	EndIf;
	
	CurrentRowIndex = String.LineNumber - 1;
	Move = 0;
	
	While True Do
		Move = Move + ?(MovementDirection = "Up", -1, 1);
		
		If CurrentRowIndex + Move < 0
		Or CurrentRowIndex + Move >= Object.Content.Count() Then
			Return;
		EndIf;
		
		If Items.ShowInvalidUsers.Check
		 Or Object.Content[CurrentRowIndex + Move].Invalid = False Then
			Break;
		EndIf;
	EndDo;
	
	Object.Content.Move(CurrentRowIndex, Move);
	Items.Content.Refresh();
	
EndProcedure

&AtClient
Procedure AfterAssignmentChoice(TypesArray, AdditionalParameters) Export
	
	Modified = True;
	DeleteNontypicalExternalUsers();
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtServer
Procedure ProcessRolesInterface(Action, MainParameter = Undefined)
	
	ActionParameters = New Structure;
	ActionParameters.Insert("MainParameter", MainParameter);
	ActionParameters.Insert("Form",            ThisObject);
	ActionParameters.Insert("RolesCollection",   RolesCollection);
	ActionParameters.Insert("RolesAssignment",  "ForExternalUsers");
	
	UsersInternal.ProcessRolesInterface(Action, ActionParameters);
	
EndProcedure

#EndRegion
