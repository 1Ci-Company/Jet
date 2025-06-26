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
	
	Query = New Query;
	Query.SetParameter("Selected_",                 Parameters.Selected_);
	Query.SetParameter("GroupsUser",         Parameters.GroupsUser);
	Query.SetParameter("EmployeeResponsible",             Users.AuthorizedUser());
	Query.SetParameter("EmployeeResponsibleIsFullUser", Users.IsFullUser());
	Query.SetParameter("AdministratorsAccessGroup",
		AccessManagement.AdministratorsAccessGroup());
	
	SetPrivilegedMode(True);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref,
	|	AccessGroups.Description AS Description,
	|	AccessGroups.IsFolder AS IsFolder,
	|	CASE
	|		WHEN AccessGroups.IsFolder
	|				AND NOT AccessGroups.DeletionMark
	|			THEN 0
	|		WHEN AccessGroups.IsFolder
	|				AND AccessGroups.DeletionMark
	|			THEN 1
	|		WHEN NOT AccessGroups.IsFolder
	|				AND NOT AccessGroups.DeletionMark
	|			THEN 3
	|		ELSE 4
	|	END AS PictureNumber,
	|	FALSE AS Check,
	|	AccessGroups.Comment AS Comment
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	CASE
	|			WHEN AccessGroups.IsFolder
	|				THEN TRUE
	|			WHEN AccessGroups.Ref IN (&Selected_)
	|				THEN FALSE
	|			WHEN AccessGroups.DeletionMark
	|				THEN FALSE
	|			WHEN AccessGroups.Profile.DeletionMark
	|				THEN FALSE
	|			WHEN AccessGroups.Ref = &AdministratorsAccessGroup
	|				THEN &EmployeeResponsibleIsFullUser
	|						AND VALUETYPE(&GroupsUser) = TYPE(Catalog.Users)
	|			WHEN &EmployeeResponsibleIsFullUser = FALSE
	|					AND AccessGroups.EmployeeResponsible <> &EmployeeResponsible
	|				THEN FALSE
	|			ELSE CASE
	|						WHEN AccessGroups.User = UNDEFINED
	|							THEN TRUE
	|						WHEN AccessGroups.User = VALUE(Catalog.Users.EmptyRef)
	|							THEN TRUE
	|						WHEN AccessGroups.User = VALUE(Catalog.ExternalUsers.EmptyRef)
	|							THEN TRUE
	|						ELSE AccessGroups.User = &GroupsUser
	|					END
	|					AND CASE
	|						WHEN VALUETYPE(&GroupsUser) = TYPE(Catalog.Users)
	|								OR VALUETYPE(&GroupsUser) = TYPE(Catalog.UserGroups)
	|							THEN TRUE IN
	|									(SELECT TOP 1
	|										TRUE
	|									FROM
	|										Catalog.AccessGroupProfiles.Purpose AS AccessGroupProfilesAssignment
	|									WHERE
	|										AccessGroupProfilesAssignment.Ref = AccessGroups.Profile
	|										AND VALUETYPE(AccessGroupProfilesAssignment.UsersType) = TYPE(Catalog.Users))
	|						WHEN VALUETYPE(&GroupsUser) = TYPE(Catalog.ExternalUsers)
	|							THEN TRUE IN
	|									(SELECT TOP 1
	|										TRUE
	|									FROM
	|										Catalog.AccessGroupProfiles.Purpose AS AccessGroupProfilesAssignment,
	|										Catalog.ExternalUsers AS ExternalUsers
	|									WHERE
	|										ExternalUsers.Ref = &GroupsUser
	|										AND AccessGroupProfilesAssignment.Ref = AccessGroups.Profile
	|										AND VALUETYPE(AccessGroupProfilesAssignment.UsersType) = VALUETYPE(ExternalUsers.AuthorizationObject))
	|						WHEN VALUETYPE(&GroupsUser) = TYPE(Catalog.ExternalUsersGroups)
	|							THEN TRUE IN
	|									(SELECT TOP 1
	|										TRUE
	|									FROM
	|										Catalog.AccessGroupProfiles.Purpose AS AccessGroupProfilesAssignment,
	|										Catalog.ExternalUsersGroups.Purpose AS ExternalUserGroupsAssignment
	|									WHERE
	|										ExternalUserGroupsAssignment.Ref = &GroupsUser
	|										AND AccessGroupProfilesAssignment.Ref = AccessGroups.Profile
	|										AND VALUETYPE(AccessGroupProfilesAssignment.UsersType) = VALUETYPE(ExternalUserGroupsAssignment.UsersType))
	|						ELSE FALSE
	|					END
	|		END
	|
	|ORDER BY
	|	AccessGroups.Ref HIERARCHY";
	
	NewTree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	Folders = NewTree.Rows.FindRows(New Structure("IsFolder", True), True);
	
	DeleteFolders = New Map;
	NoFolders = True;
	
	For Each Folder In Folders Do
		If Folder.Parent = Undefined
		   And Folder.Rows.Count() = 0
		 Or Folder.Rows.FindRows(New Structure("IsFolder", False), True).Count() = 0 Then
			
			DeleteFolders.Insert(
				?(Folder.Parent = Undefined, NewTree.Rows, Folder.Parent.Rows),
				Folder);
		Else
			NoFolders = False;
		EndIf;
	EndDo;
	
	For Each KeyAndValue In DeleteFolders Do
		Rows = KeyAndValue.Key; // ValueTreeRowCollection
		If Rows.IndexOf(KeyAndValue.Value) > -1 Then
			Rows.Delete(KeyAndValue.Value);
		EndIf;
	EndDo;
	
	NewTree.Rows.Sort("IsFolder Desc, Description Asc", True);
	ValueToFormAttribute(NewTree, "AccessGroups");
	
	If NoFolders Then
		Items.AccessGroups.Representation = TableRepresentation.List;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAccessGroups

&AtClient
Procedure AccessGroupsSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	OnChoice();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	
	OnChoice();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OnChoice()
	
	CurrentData = Items.AccessGroups.CurrentData;
	
	If CurrentData <> Undefined Then
		If CurrentData.IsFolder Then
			
			If Items.AccessGroups.Expanded(Items.AccessGroups.CurrentRow) Then
				Items.AccessGroups.Collapse(Items.AccessGroups.CurrentRow);
			Else
				Items.AccessGroups.Expand(Items.AccessGroups.CurrentRow);
			EndIf;
		Else
			NotifyChoice(CurrentData.Ref);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
