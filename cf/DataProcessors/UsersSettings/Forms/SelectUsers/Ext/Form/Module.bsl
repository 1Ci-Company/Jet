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
	
	UserType = TypeOf(Parameters.User);
	
	If UserType = Type("CatalogRef.ExternalUsers") Then
		AllUsersGroup = ExternalUsers.AllExternalUsersGroup();
	Else
		AllUsersGroup = Users.AllUsersGroup();
	EndIf;
	
	WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	UseGroups = GetFunctionalOption("UseUserGroups");
	SourceUser = Parameters.User;
	FillUserList(UserType, UseGroups);
	
	CopyAll   = (Parameters.ActionType = "CopyAll");
	SettingsClearing = (Parameters.ActionType = "Clearing");
	If SettingsClearing Then
		Title =
			NStr("en = 'Select users to clear settings';");
		Items.Label.Title =
			NStr("en = 'Select the users whose settings you want to clear:';");
	EndIf;
	
	If Parameters.SelectedUsers <> Undefined Then
		AddCheckMarksToPassedUsers = True;
		For Each SelectedUser In Parameters.SelectedUsers Do
			MarkUser(SelectedUser);
		EndDo;
	EndIf;
	
	Source = Parameters.Source;
	
	If Not Users.IndividualUsed() Then
		Items.UsersListIndividual.Visible = False;
	EndIf;
	
	If Not Users.IsDepartmentUsed() Then
		Items.UsersListDepartment.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	
	Settings.Delete("AllUsersList");
	
	// If the form is opened from the "Clear application user settings" form or from the "Copy application user settings" form, do not save the settings.
	If AddCheckMarksToPassedUsers Then
		Return;
	EndIf;
	
	FilterParameters = New Structure("Check", True);
	MarkedUsersList = New ValueList;
	MarkedUsersArray = AllUsersList.FindRows(FilterParameters);
	
	For Each ArrayRow In MarkedUsersArray Do
		MarkedUsersList.Add(ArrayRow.User);
	EndDo;
	
	Settings.Insert("MarkedUsers", MarkedUsersList);
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	// If the form is opened from the "Application user settings clearing" form or from the "Application user settings copying" form, do not load the settings
	If AddCheckMarksToPassedUsers Then
		Settings.Delete("AllUsersList");
		Settings.Delete("MarkedUsers");
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	MarkedUsers = Settings.Get("MarkedUsers");
	
	If MarkedUsers = Undefined Then
		Return;
	EndIf;
	
	For Each MarkedUserRow In MarkedUsers Do
		
		UserRef = MarkedUserRow.Value;
		MarkUser(UserRef);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateGroupTitlesOnToggleCheckBox();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UserGroupsOnActivateRow(Item)
	
	SelectedGroup = Item.CurrentData;
	If SelectedGroup = Undefined Then
		Return;
	EndIf;
	
	ApplyGroupFilter(SelectedGroup);
	If UseGroups Then
		Items.ShowUsersFromSubgroupsGroup.CurrentPage = Items.SetPropertyGroup;
	Else
		Items.ShowUsersFromSubgroupsGroup.Visible = False;
	EndIf;
	
#If MobileClient Then
	Items.UsersList.TitleLocation = FormItemTitleLocation.Top;
#EndIf
	
EndProcedure

&AtClient
Procedure UsersListSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(,Item.CurrentData.User);
	
EndProcedure

&AtClient
Procedure UserGroupsSelection(Item, RowSelected, Field, StandardProcessing)
	
	ShowValue(,Item.CurrentData.Group);
	
EndProcedure

&AtClient
Procedure ShowUsersFromSubgroupsOnChange(Item)
	
	SelectedUserGroup = Items.UserGroups.CurrentData;
	ApplyGroupFilter(SelectedUserGroup);
	
	// Update group titles.
	ClearGroupTitles();
	UpdateGroupTitlesOnToggleCheckBox();
	
EndProcedure

&AtClient
Procedure UsersCheckBoxOnChange(Item)
	
	UserListRow = Item.Parent.Parent.CurrentData;
	UserListRow.Check = Not UserListRow.Check;
	ChangeMark2(UserListRow, Not UserListRow.Check);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	
	UsersDestination = New Array;
	For Each Item In UsersList Do
		
		If Item.Check Then
			UsersDestination.Add(Item.User);
		EndIf;
		
	EndDo;
	
	If UsersDestination.Count() = 0 Then
		ShowMessageBox(,NStr("en = 'Select one or several users.';"));
		Return;
	EndIf;
	
	Result = New Structure("UsersDestination, CopyAll, SettingsClearing", 
		UsersDestination, CopyAll, SettingsClearing);
	Notify("UserSelection", Result, Source);
	Close();
	
EndProcedure

&AtClient
Procedure SelectAllItems(Command)
	
	For Each UserListRow In UsersList Do
		ChangeMark2(UserListRow, True);
	EndDo;
	
EndProcedure

&AtClient
Procedure AddCheckMarksToSelectedUsers(Command)
	
	SelectedItems = Items.UsersList.SelectedRows;
	
	If SelectedItems.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Item In SelectedItems Do
		UserListRow = UsersList.FindByID(Item);
		ChangeMark2(UserListRow, True);
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearAllIetms(Command)
	
	For Each UserListRow In UsersList Do
		ChangeMark2(UserListRow, False);
	EndDo;
EndProcedure

&AtClient
Procedure RemoveCheckMarksFromSelectedUsers(Command)
	
	SelectedItems = Items.UsersList.SelectedRows;
	
	If SelectedItems.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Item In SelectedItems Do
		UserListRow = UsersList.FindByID(Item);
		ChangeMark2(UserListRow, False);
	EndDo;
	
EndProcedure

&AtClient
Procedure ModifyUserOrGroup(Command)
	
	CurrentValue = CurrentItem.CurrentData;
	
	If TypeOf(CurrentValue) = Type("FormDataCollectionItem") Then
		
		ShowValue(,CurrentValue.User);
		
	ElsIf TypeOf(CurrentValue) = Type("FormDataTreeItem") Then
		
		ShowValue(,CurrentValue.Group);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ActiveUsers(Command)
	
	StandardSubsystemsClient.OpenActiveUserList();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UserGroupsGroup.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UserGroups.MarkedUsersCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Font", StyleFonts.MainListItem);
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("UserGroups.GroupDescriptionAndUserMarkCount"));

EndProcedure

&AtServer
Procedure MarkUser(UserRef)
	
	For Each AllUsersListRow In AllUsersList Do
		
		If AllUsersListRow.User = UserRef Then
			AllUsersListRow.Check = True;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure UpdateGroupTitlesOnToggleCheckBox()
	
	For Each UsersGroup In UserGroups.GetItems() Do
		
		For Each UserListRow In AllUsersList Do
			
			If UserListRow.Check Then
				CheckMarkValue = True;
				UserListRow.Check = False;
				UpdateGroupTitle(ThisObject, UsersGroup, UserListRow, CheckMarkValue);
				UserListRow.Check = True;
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearGroupTitles()
	
	For Each UsersGroup In UserGroups.GetItems() Do
		ClearGroupTitle(UsersGroup);
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearGroupTitle(UsersGroup)
	
	UsersGroup.MarkedUsersCount = 0;
	SubordinateGroups = UsersGroup.GetItems();
	
	For Each SubordinateGroup In SubordinateGroups Do
	
		ClearGroupTitle(SubordinateGroup);
	
	EndDo;
	
EndProcedure

&AtClient
Procedure ChangeMark2(UserListRow, CheckMarkValue)
	
	If UseGroups Then
		
		UpdateGroupTitles(ThisObject, UserListRow, CheckMarkValue);
		
		UserListRow.Check = CheckMarkValue;
		Filter = New Structure("User", UserListRow.User); 
		FoundUsers = AllUsersList.FindRows(Filter);
		For Each FoundUser In FoundUsers Do
			FoundUser.Check = CheckMarkValue;
		EndDo;
	Else
		UserListRow.Check = CheckMarkValue;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateGroupTitles(Form, UserListRow, CheckMarkValue)
	
	For Each UsersGroup In Form.UserGroups.GetItems() Do
		
		UpdateGroupTitle(Form, UsersGroup, UserListRow, CheckMarkValue);
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateGroupTitle(Form, UsersGroup, UserListRow, CheckMarkValue)
	
	UserRef = UserListRow.User;
	If Form.ShowUsersFromSubgroups 
		Or Form.AllUsersGroup = UsersGroup.Group Then
		Content = UsersGroup.FullComposition;
	Else
		Content = UsersGroup.Content;
	EndIf;
	MarkedUser = Content.FindByValue(UserRef);
	
	If MarkedUser <> Undefined And CheckMarkValue <> UserListRow.Check Then
		MarkedUsersCount = UsersGroup.MarkedUsersCount;
		UsersGroup.MarkedUsersCount = ?(CheckMarkValue, MarkedUsersCount + 1, MarkedUsersCount - 1);
		UsersGroup.GroupDescriptionAndUserMarkCount = 
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (%2)';"), String(UsersGroup.Group), UsersGroup.MarkedUsersCount);
	EndIf;
	
	// Update the titles of all subgroups recursively.
	SubordinateGroups = UsersGroup.GetItems();
	For Each SubordinateGroup In SubordinateGroups Do
		UpdateGroupTitle(Form, SubordinateGroup, UserListRow, CheckMarkValue);
	EndDo;
	
EndProcedure

&AtClient
Procedure ApplyGroupFilter(CurrentGroup)
	
	UsersList.Clear();
	If CurrentGroup = Undefined Then
		Return;
	EndIf;
	
	If ShowUsersFromSubgroups Then
		GroupComposition1 = CurrentGroup.FullComposition;
	Else
		GroupComposition1 = CurrentGroup.Content;
	EndIf;
	
	For Each Item In AllUsersList Do
		If GroupComposition1.FindByValue(Item.User) <> Undefined
			Or AllUsersGroup = CurrentGroup.Group Then
			UserListLine = UsersList.Add();
			FillPropertyValues(UserListLine, Item);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillUserList(UserType, UseGroups);
	
	GroupsTree = FormAttributeToValue("UserGroups");
	AllUsersListTable = FormAttributeToValue("AllUsersList");
	UserListTable = FormAttributeToValue("UsersList");
	
	ExternalUser1 = (UserType = Type("CatalogRef.ExternalUsers"));
	If UseGroups Then
		DataProcessors.UsersSettings.FillGroupTree(GroupsTree, ExternalUser1);
		AllUsersListTable = DataProcessors.UsersSettings.UsersToCopy(
			SourceUser, AllUsersListTable, ExternalUser1);
	Else
		UserListTable = DataProcessors.UsersSettings.UsersToCopy(
			SourceUser, UserListTable, ExternalUser1);
	EndIf;
	
	GroupsTree.Rows.Sort("Group Asc");
	RowToMove1 = GroupsTree.Rows.Find(AllUsersGroup, "Group");
	
	If RowToMove1 <> Undefined Then
		RowIndex = GroupsTree.Rows.IndexOf(RowToMove1);
		GroupsTree.Rows.Move(RowIndex, -RowIndex);
	EndIf;
	
	ValueToFormAttribute(GroupsTree, "UserGroups");
	ValueToFormAttribute(UserListTable, "UsersList");
	ValueToFormAttribute(AllUsersListTable, "AllUsersList");
	
EndProcedure

#EndRegion
