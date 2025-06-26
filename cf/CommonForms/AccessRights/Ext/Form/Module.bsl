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
	
	If Not ValueIsFilled(Parameters.User) Then
		Cancel = True;
		Return;
	EndIf;
	
	If TypeOf(Parameters.User) = Type("CatalogRef.Users")
	   And Common.ObjectAttributeValue(Parameters.User, "IsInternal") = True Then
		
		IsInternalUser = True;
		Items.UtilityUserRights.Visible = True;
		CommandBar.Visible = False;
		Items.AccessGroupsAndRoles.Visible = False;
		Return;
	EndIf;
	
	IBUserFull = Users.IsFullUser();
	OwnAccess = Parameters.User = Users.AuthorizedUser();
	
	AdministratorsAccessGroup = AccessManagement.AdministratorsAccessGroup();

	IBUserEmployeeResponsible =
		Not IBUserFull
		And AccessRight("Edit", Metadata.Catalogs.AccessGroups);
	
	Items.AccessGroupsContextMenuChangeGroup.Visible =
		IBUserFull
		Or IBUserEmployeeResponsible;
	
	Items.FormAccessRightsReport.Visible =
		IBUserFull
		Or Parameters.User = Users.AuthorizedUser();
	
	If TypeOf(Parameters.User) = Type("CatalogRef.UserGroups")
	 Or TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsersGroups") Then
		
		Items.FormReportUserRights.Visible = False;
	Else
		Items.FormReportUserRights.Visible =
			IBUserFull
			Or Parameters.User = Users.AuthorizedUser();
	EndIf;
	
	// Configuring commands for a limited user.
	Items.FormAddToGroup.Visible   = IBUserEmployeeResponsible;
	Items.FormRemoveFromGroup.Visible = IBUserEmployeeResponsible;
	Items.FormChangeGroup.Visible    = IBUserEmployeeResponsible;
	
	// Configuring commands for a full access user.
	Items.AccessGroupsAddToGroup.Visible   = IBUserFull;
	Items.AccessGroupsRemoveFromGroup.Visible = IBUserFull;
	Items.AccessGroupsChangeGroup.Visible    = IBUserFull;
	
	// Setting the page tab display.
	Items.AccessGroupsAndRoles.PagesRepresentation =
		?(IBUserFull,
		  FormPagesRepresentation.TabsOnTop,
		  FormPagesRepresentation.None);
	
	// Configuring the command bar view for a full access user.
	Items.AccessGroups.CommandBarLocation =
		?(IBUserFull,
		  FormItemCommandBarLabelLocation.Top,
		  FormItemCommandBarLabelLocation.None);
	
	// Configuring roles view for a full access user.
	Items.RolesRepresentation.Visible = IBUserFull;
	
	If IBUserFull
	 Or IBUserEmployeeResponsible
	 Or OwnAccess Then
		
		OutputAccessGroups();
	Else
		// Regular users cannot view other user access settings.
		Items.AccessGroupsAddToGroup.Visible   = False;
		Items.AccessGroupsRemoveFromGroup.Visible = False;
		
		Items.AccessGroupsAndRoles.Visible         = False;
		Items.InsufficientViewRights.Visible = True;
	EndIf;
	
	ProcessRolesInterface("SetUpRoleInterfaceOnFormCreate");
	ProcessRolesInterface("SetRolesReadOnly", True);
	
	If Common.IsStandaloneWorkplace() Then
		Items.FormAddToGroup.Enabled   = False;
		Items.FormRemoveFromGroup.Enabled = False;
		Items.AccessGroupsAddToGroup.Enabled   = False;
		Items.AccessGroupsRemoveFromGroup.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If IsInternalUser Then
		Return;
	EndIf;
	
	If Upper(EventName) = Upper("Write_AccessGroups")
	 Or Upper(EventName) = Upper("Write_AccessGroupProfiles")
	 Or Upper(EventName) = Upper("Write_UserGroups")
	 Or Upper(EventName) = Upper("Write_ExternalUsersGroups") Then
		
		OutputAccessGroups();
		UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If IsInternalUser Then
		Return;
	EndIf;
	
	ProcessRolesInterface("SetUpRoleInterfaceOnLoadSettings", Settings);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAccessGroups

&AtClient
Procedure AccessGroupsOnActivateRow(Item)
	
	CurrentData   = Items.AccessGroups.CurrentData;
	CurrentParent = Items.AccessGroups.CurrentParent;
	
	If CurrentData = Undefined Then
		CurrentAccessGroup = Undefined;
	Else
		CurrentAccessGroup = ?(CurrentParent = Undefined,
			CurrentData.AccessGroup, CurrentParent.AccessGroup);
	EndIf;
	
EndProcedure

&AtClient
Procedure AccessGroupsSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If AccessGroups.FindByID(RowSelected) <> Undefined Then
		
		If Items.FormChangeGroup.Visible
		 Or Items.AccessGroupsChangeGroup.Visible Then
			
			ChangeGroup(Items.FormChangeGroup);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AddToGroup(Command)
	
	FormParameters = New Structure;
	Selected_ = New Array;
	
	For Each AccessGroupDetails In AccessGroups Do
		Selected_.Add(AccessGroupDetails.AccessGroup);
	EndDo;
	
	FormParameters.Insert("Selected_",         Selected_);
	FormParameters.Insert("GroupsUser", Parameters.User);
	
	OpenForm("Catalog.AccessGroups.Form.SelectGroupsByEmployeeResponsible", FormParameters, ThisObject,
		,,, New NotifyDescription("IncludeExcludeFromGroup", ThisObject, True));
	
EndProcedure

&AtClient
Procedure RemoveFromGroup(Command)
	
	If Not ValueIsFilled(CurrentAccessGroup) Then
		ShowMessageBox(, NStr("en = 'No access group is selected.';"));
		Return;
	EndIf;
	
	IncludeExcludeFromGroup(CurrentAccessGroup, False);
	
EndProcedure

&AtClient
Procedure ChangeGroup(Command)
	
	FormParameters = New Structure;
	
	If Not ValueIsFilled(CurrentAccessGroup) Then
		ShowMessageBox(, NStr("en = 'No access group is selected.';"));
		Return;
		
	ElsIf IBUserFull
	      Or IBUserEmployeeResponsible
	          And GroupUsersChangeAllowed(CurrentAccessGroup) Then
		
		FormParameters.Insert("Key", CurrentAccessGroup);
		OpenForm("Catalog.AccessGroups.ObjectForm", FormParameters);
	Else
		Raise(NStr("en = 'Insufficient rights to edit the access group.
			|Only employees responsible for access group members and administrators can edit the access group.';"),
			ErrorCategory.AccessViolation);
	EndIf;
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	OutputAccessGroups();
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure ReportUserRights(Command)
	
	AccessManagementInternalClient.ShowUserRightsOnTables(Parameters.User);
	
EndProcedure

&AtClient
Procedure AccessRightsReport(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", New Structure("User", Parameters.User));
	
	OpenForm("Report.AccessRights.Form", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtClient
Procedure RolesBySubsystemsGroup(Command)
	
	ProcessRolesInterface("GroupBySubsystems");
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure IncludeExcludeFromGroup(AccessGroup, IncludeInAccessGroup) Export
	
	If TypeOf(AccessGroup) <> Type("CatalogRef.AccessGroups")
	  Or Not ValueIsFilled(AccessGroup) Then
		
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("AccessGroup", AccessGroup);
	AdditionalParameters.Insert("IncludeInAccessGroup", IncludeInAccessGroup);
	
	If CommonClient.DataSeparationEnabled()
	   And AccessGroup = AdministratorsAccessGroup Then
		
		UsersInternalClient.RequestPasswordForAuthenticationInService(
			New NotifyDescription(
				"IncludeExcludeFromGroupCompletion", ThisObject, AdditionalParameters),
			ThisObject,
			ServiceUserPassword);
		Return;
	Else
		IncludeExcludeFromGroupCompletion(Null, AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure IncludeExcludeFromGroupCompletion(SaaSUserNewPassword, AdditionalParameters) Export
	
	If SaaSUserNewPassword = Undefined Then
		Return;
	EndIf;
	
	If SaaSUserNewPassword <> Null Then
		ServiceUserPassword = SaaSUserNewPassword;
	EndIf;
	
	ErrorDescription = "";
	
	ChangeGroupContent(
		AdditionalParameters.AccessGroup,
		AdditionalParameters.IncludeInAccessGroup,
		ErrorDescription);
	
	If ValueIsFilled(ErrorDescription) Then
		ShowMessageBox(, ErrorDescription);
	Else
		NotifyChanged(AdditionalParameters.AccessGroup);
		Notify("Write_AccessGroups", New Structure, AdditionalParameters.AccessGroup);
	EndIf;
	
EndProcedure

&AtServer
Procedure OutputAccessGroups()
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	If IBUserFull Or OwnAccess Then
		SetPrivilegedMode(True);
	EndIf;
	
	Query.Text =
	"SELECT ALLOWED
	|	AccessGroups.Ref
	|INTO AllowedAccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups";
	Query.Execute();
	
	SetPrivilegedMode(True);
	
	Query.Text =
	"SELECT
	|	AllowedAccessGroups.Ref
	|FROM
	|	AllowedAccessGroups AS AllowedAccessGroups
	|WHERE
	|	(NOT AllowedAccessGroups.Ref.DeletionMark)
	|	AND (NOT AllowedAccessGroups.Ref.Profile.DeletionMark)";
	AllowedAccessGroups = Query.Execute().Unload();
	AllowedAccessGroups.Indexes.Add("Ref");
	
	Query.SetParameter("User", Parameters.User);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessGroups.Description AS Description,
	|	AccessGroups.Profile.Description AS ProfileDescription,
	|	AccessGroups.Comment AS Comment,
	|	AccessGroups.EmployeeResponsible AS EmployeeResponsible
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	NOT AccessGroups.DeletionMark
	|	AND NOT AccessGroups.Profile.DeletionMark
	|	AND TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				Catalog.AccessGroups.Users AS AccessGroupsUsers
	|			WHERE
	|				AccessGroupsUsers.Ref = AccessGroups.Ref
	|				AND NOT(AccessGroupsUsers.User <> &User
	|						AND NOT AccessGroupsUsers.User IN
	|								(SELECT
	|									UserGroupCompositions.UsersGroup
	|								FROM
	|									InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|								WHERE
	|									UserGroupCompositions.User = &User)))
	|
	|ORDER BY
	|	AccessGroups.Description";
	
	AllAccessGroups = Query.Execute().Unload();
	
	HasProhibitedGroups = False;
	IndexOf = AllAccessGroups.Count()-1;
	
	While IndexOf >= 0 Do
		String = AllAccessGroups[IndexOf];
		
		If AllowedAccessGroups.Find(String.AccessGroup, "Ref") = Undefined Then
			AllAccessGroups.Delete(IndexOf);
			HasProhibitedGroups = True;
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	ValueToFormAttribute(AllAccessGroups, "AccessGroups");
	Items.HasHiddenAccessGroupsWarning.Visible = HasProhibitedGroups;
	
	If Not ValueIsFilled(CurrentAccessGroup) Then
		
		If AccessGroups.Count() > 0 Then
			CurrentAccessGroup = AccessGroups[0].AccessGroup;
		EndIf;
	EndIf;
	
	For Each AccessGroupDetails In AccessGroups Do
		
		If AccessGroupDetails.AccessGroup = CurrentAccessGroup Then
			Items.AccessGroups.CurrentRow = AccessGroupDetails.GetID();
			Break;
		EndIf;
	EndDo;
	
	If IBUserFull Then
		FillRoles();
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeGroupContent(Val AccessGroup, Val Add, ErrorDescription = "")
	
	If Not GroupUsersChangeAllowed(AccessGroup) Then
		If Add Then
			ErrorDescription =
				NStr("en = 'Insufficient rights to add the user to the access group.
				           |Only employees responsible for access group members and administrators can add users to access groups.';");
		Else
			ErrorDescription =
				NStr("en = 'Insufficient rights to remove the user from the access group.
				           |Only employees responsible for access group members and administrators can remove users from access groups.';");
		EndIf;
		Return;
	EndIf;
	
	If Not Add And Not UserIncludedInAccessGroup(CurrentAccessGroup) Then
		ErrorDescription =
			NStr("en = 'Cannot remove the user from the access group
			           |as the user is not a direct member of the group.';");
		Return;
	EndIf;
	
	If Common.DataSeparationEnabled()
	   And AccessGroup = AdministratorsAccessGroup
	   And Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ActionsWithSaaSUser = ModuleUsersInternalSaaS.GetActionsWithSaaSUser();
		
		If Not ActionsWithSaaSUser.ChangeAdministrativeAccess Then
			Raise(NStr("en = 'Insufficient access rights to edit administrators.';"),
				ErrorCategory.AccessViolation);
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("Catalog.AccessGroups");
		LockItem.SetValue("Ref", AccessGroup);
		Block.Lock();
		
		AccessGroupObject = AccessGroup.GetObject();
		LockDataForEdit(AccessGroupObject.Ref, AccessGroupObject.DataVersion);
		If Add Then
			If AccessGroupObject.Users.Find(Parameters.User, "User") = Undefined Then
				AccessGroupObject.Users.Add().User = Parameters.User;
			EndIf;
		Else
			TSRow = AccessGroupObject.Users.Find(Parameters.User, "User");
			If TSRow <> Undefined Then
				AccessGroupObject.Users.Delete(TSRow);
			EndIf;
		EndIf;
		
		If AccessGroupObject.Ref = AdministratorsAccessGroup Then
			
			If Common.DataSeparationEnabled() Then
				AccessGroupObject.AdditionalProperties.Insert(
					"ServiceUserPassword", ServiceUserPassword);
			Else
				AccessManagementInternal.CheckAdministratorsAccessGroupForIBUser(
					AccessGroupObject.Users, ErrorDescription);
				
				If ValueIsFilled(ErrorDescription) Then
					RollbackTransaction();
					UnlockDataForEdit(AccessGroupObject.Ref);
					Return;
				EndIf;
			EndIf;
		EndIf;
		
		AccessGroupObject.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		UnlockDataForEdit(AccessGroupObject.Ref);
		ServiceUserPassword = Undefined;
		Raise;
	EndTry;
	
	UnlockDataForEdit(AccessGroupObject.Ref);
	CurrentAccessGroup = AccessGroupObject.Ref;
	AccessManagementInternal.StartAccessUpdate();
	
EndProcedure

&AtServer
Function GroupUsersChangeAllowed(AccessGroup)
	
	If IBUserFull Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("AccessGroup",              AccessGroup);
	Query.SetParameter("AuthorizedUser", Users.AuthorizedUser());
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON (UserGroupCompositions.User = &AuthorizedUser)
	|			AND (UserGroupCompositions.UsersGroup = AccessGroups.EmployeeResponsible)
	|			AND (AccessGroups.Ref = &AccessGroup)";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Function UserIncludedInAccessGroup(AccessGroup)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("AccessGroup", AccessGroup);
	Query.SetParameter("User", Parameters.User);
	Query.Text =
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroups_Users
	|WHERE
	|	AccessGroups_Users.Ref = &AccessGroup
	|	AND AccessGroups_Users.User = &User";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Procedure FillRoles()
	
	Query = New Query;
	Query.SetParameter("User", Parameters.User);
	
	If TypeOf(Parameters.User) = Type("CatalogRef.Users")
	 Or TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsers") Then
		
		Query.Text =
		"SELECT DISTINCT 
		|	Roles.Role AS Role
		|FROM
		|	Catalog.AccessGroupProfiles.Roles AS Roles
		|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroups_Users
		|			INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|			ON (UserGroupCompositions.User = &User)
		|				AND (UserGroupCompositions.UsersGroup = AccessGroups_Users.User)
		|				AND (NOT AccessGroups_Users.Ref.DeletionMark)
		|		ON Roles.Ref = AccessGroups_Users.Ref.Profile
		|			AND (NOT Roles.Ref.DeletionMark)";
	Else
		// User group or External user group.
		Query.Text =
		"SELECT DISTINCT
		|	Roles.Role AS Role
		|FROM
		|	Catalog.AccessGroupProfiles.Roles AS Roles
		|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroups_Users
		|		ON (AccessGroups_Users.User = &User)
		|			AND (NOT AccessGroups_Users.Ref.DeletionMark)
		|			AND Roles.Ref = AccessGroups_Users.Ref.Profile
		|			AND (NOT Roles.Ref.DeletionMark)";
	EndIf;
	
	ProcessRolesInterface("FillRoles", Query.Execute().Unload());
	
	Filter = New Structure("Role", "FullAccess");
	If ReadRoles.FindRows(Filter).Count() > 0 Then
		OriginalReadRoles = ReadRoles.Unload(, "Role");
		
		ReadRoles.Clear();
		ReadRoles.Add().Role = "FullAccess";
		
		StandardExtensionRoles = AccessManagementInternalCached.DescriptionStandardRolesSessionExtensions().SessionRoles;
		PossibleAdministratorRoles = New Map(StandardExtensionRoles.AdditionalAdministratorRoles);
		PossibleAdministratorRoles.Insert("SystemAdministrator", True);
		PossibleAdministratorRoles.Insert("InteractiveOpenExtReportsAndDataProcessors", True);
		
		For Each RoleDetails In PossibleAdministratorRoles Do
			Filter = New Structure("Role", RoleDetails.Key);
			If OriginalReadRoles.FindRows(Filter).Count() > 0 Then
				ReadRoles.Add().Role = RoleDetails.Key;
			EndIf;
		EndDo;
	EndIf;
	
	ProcessRolesInterface("RefreshRolesTree");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtServer
Procedure ProcessRolesInterface(Action, MainParameter = Undefined)
	
	ActionParameters = New Structure;
	ActionParameters.Insert("MainParameter", MainParameter);
	ActionParameters.Insert("Form",            ThisObject);
	ActionParameters.Insert("RolesCollection",   ReadRoles);
	
	If TypeOf(Parameters.User) = Type("CatalogRef.Users")
	   And Users.IsFullUser(Parameters.User, False, False) Then
		
		RolesAssignment = "ForAdministrators";
		
	ElsIf TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsers")
	      Or TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsersGroups") Then
		
		RolesAssignment = "ForExternalUsers";
	Else
		RolesAssignment = "ForUsers";
	EndIf;
	
	ActionParameters.Insert("RolesAssignment", RolesAssignment);
	
	UsersInternal.ProcessRolesInterface(Action, ActionParameters);
	
EndProcedure

#EndRegion
