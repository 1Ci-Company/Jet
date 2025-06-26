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
	
	If Parameters.User <> Undefined Then
		UsersArray = New Array;
		UsersArray.Add(Parameters.User);
		
		ThisisExternalUsers = ?(
			TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsers"), True, False);
		Items.FormWriteAndClose.Title = NStr("en = 'Save';");
		OpenFromUserProfileMode = True;
	Else
		UsersArray = Parameters.Users;
		ThisisExternalUsers = Parameters.ExternalUsers;
		OpenFromUserProfileMode = False;
	EndIf;
	CompositionColumnName = ?(ThisisExternalUsers, "ExternalUser", "User");
	
	UsersCount = UsersArray.Count();
	If UsersCount = 0 Then
		Raise NStr("en = 'No users are selected.';");
	EndIf;
	
	UsersType = Undefined;
	For Each UserFromArray In UsersArray Do
		If UsersType = Undefined Then
			UsersType = TypeOf(UserFromArray);
		EndIf;
		UserTypeFromArray = TypeOf(UserFromArray);
		
		If UserTypeFromArray <> Type("CatalogRef.Users")
		   And UserTypeFromArray <> Type("CatalogRef.ExternalUsers") Then
			
			Raise NStr("en = 'Cannot run the command for the object.';");
		EndIf;
		
		If UsersType <> UserTypeFromArray Then
			Raise NStr("en = 'Cannot run the command for two user types.';");
		EndIf;
	EndDo;
		
	If UsersCount > 1
	   And Parameters.User = Undefined Then
		
		Title = NStr("en = 'User groups';");
		Items.GroupsTreeCheck.ThreeState = True;
	EndIf;
	
	UsersList = New Structure;
	UsersList.Insert("UsersArray", UsersArray);
	UsersList.Insert("UsersCount", UsersCount);
	FillGroupTree();
	
	If GroupsTree.GetItems().Count() = 0 Then
		Items.GroupsOrWarning.CurrentPage = Items.Warning;
		If Common.IsMobileClient() Then
			Items.CommandBar.Visible = False;
		EndIf;
		Return;
	EndIf;
	
	If Common.IsStandaloneWorkplace() Then
		Items.FormWriteAndClose.Enabled = False;
		Items.FormExcludeFromAllGroups.Enabled = False;
		Items.GroupsTree.ReadOnly = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If OpenFromUserProfileMode Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("WriteAndCloseBeginning", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersGroupsTree

&AtClient
Procedure GroupsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(,Item.CurrentData.Group);
	
EndProcedure

&AtClient
Procedure GroupsTreeCheckOnChange(Item)
	Modified = True;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)
	WriteAndCloseBeginning();
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	FillGroupTree(True);
	ExpandValueTree();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.GroupsTreeCheck.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("GroupsTree.ReadOnlyGroup");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("ReadOnly", True);

EndProcedure

&AtClient
Procedure WriteAndCloseBeginning(Result = Undefined, AdditionalParameters = Undefined) Export
	
	NotifyUser1 = New Structure;
	NotifyUser1.Insert("Message");
	NotifyUser1.Insert("HasErrors");
	NotifyUser1.Insert("FullMessageText");
	
	WriteChanges(NotifyUser1);
	
	If NotifyUser1.HasErrors = False Then
		If NotifyUser1.Message <> Undefined Then
			ShowUserNotification(
				NStr("en = 'Move users';"), , NotifyUser1.Message, PictureLib.DialogInformation);
		EndIf;
	Else
		
		If NotifyUser1.FullMessageText <> Undefined Then
			QueryText = NotifyUser1.Message;
			QuestionButtons = New ValueList;
			QuestionButtons.Add("OK", NStr("en = 'OK';"));
			QuestionButtons.Add("ShowReport", NStr("en = 'View report';"));
			Notification = New NotifyDescription("WriteAndCloseQuestionProcessing",
				ThisObject, NotifyUser1.FullMessageText);
			ShowQueryBox(Notification, QueryText, QuestionButtons,, QuestionButtons[0].Value);
		Else
			Notification = New NotifyDescription("WriteAndCloseWarningProcessing", ThisObject);
			ShowMessageBox(Notification, NotifyUser1.Message);
		EndIf;
		
		Return;
	EndIf;
	
	Modified = False;
	WriteAndCloseCompletion();
	
EndProcedure

&AtServer
Procedure FillGroupTree(OnlyClearAll = False)
	
	GroupTreeDestination = FormAttributeToValue("GroupsTree");
	If Not OnlyClearAll Then
		GroupTreeDestination.Rows.Clear();
	EndIf;
	
	If OnlyClearAll Then
		
		HadChanges = False;
		FoundItems = GroupTreeDestination.Rows.FindRows(New Structure("Check", 1), True);
		For Each TreeRow In FoundItems Do
			If Not TreeRow.ReadOnlyGroup Then
				TreeRow.Check = 0;
				HadChanges = True;
			EndIf;
		EndDo;
		
		FoundItems = GroupTreeDestination.Rows.FindRows(New Structure("Check", 2), True);
		For Each TreeRow In FoundItems Do
			TreeRow.Check = 0;
			HadChanges = True;
		EndDo;
		
		If HadChanges Then
			Modified = True;
		EndIf;
		
		ValueToFormAttribute(GroupTreeDestination, "GroupsTree");
		Return;
	EndIf;
	
	UserGroups = Undefined;
	SubordinateGroups = New Array; // Array of ValueTableRow: See GetExternalUserGroups.UserGroups
	ParentArray = New Array;
	
	If ThisisExternalUsers Then
		EmptyGroup1 = Catalogs.ExternalUsersGroups.EmptyRef();
		GetExternalUserGroups(UserGroups);
		AuthorizationObjects = UsersAuthenticationObjects(UsersList.UsersArray);
	Else
		EmptyGroup1 = Catalogs.UserGroups.EmptyRef();
		GetUserGroups(UserGroups);
	EndIf;
	
	If UserGroups.Count() <= 1 Then
		Items.GroupsOrWarning.CurrentPage = Items.Warning;
		Return;
	EndIf;
	
	GetSubordinateGroups(UserGroups, SubordinateGroups, EmptyGroup1);
	GroupsComposition = GroupsComposition();
	
	While SubordinateGroups.Count() > 0 Do
		ParentArray.Clear();
		
		For Each Var_Group In SubordinateGroups Do
			
			If Var_Group.Parent = EmptyGroup1 Then
				NewGroupRow = GroupTreeDestination.Rows.Add();
				NewGroupRow.Group = Var_Group.Ref;
				NewGroupRow.Picture = ?(ThisisExternalUsers, 9, 3);
				
				If UsersList.UsersCount = 1 Then
					UserIndirectlyIncludedInGroup = False;
					UserRef = UsersList.UsersArray[0];
					
					If ThisisExternalUsers And Var_Group.AllAuthorizationObjects Then
						Type = TypeOf(AuthorizationObjects.Get(UserRef));
						RefTypeDetails = New TypeDescription(CommonClientServer.ValueInArray(Type));
						Value = RefTypeDetails.AdjustValue(Undefined);
						
						Filter = New Structure("UsersType", Value);
						UserIndirectlyIncludedInGroup = ValueIsFilled(Var_Group.Purpose.FindRows(Filter));
						NewGroupRow.ReadOnlyGroup = True;
					EndIf;
					
					NewGroupRow.Check = ?(UserInGroup(GroupsComposition,
						Var_Group.Ref, UserRef) Or UserIndirectlyIncludedInGroup, 1, 0);
				Else
					NewGroupRow.Check = 2;
				EndIf;
				
			Else
				ParentGroup1 = 
					GroupTreeDestination.Rows.FindRows(New Structure("Group", Var_Group.Parent), True);
				NewSubordinateGroupRow = ParentGroup1[0].Rows.Add();
				NewSubordinateGroupRow.Group = Var_Group.Ref;
				NewSubordinateGroupRow.Picture = ?(ThisisExternalUsers, 9, 3);
				
				If UsersList.UsersCount = 1 Then
					NewSubordinateGroupRow.Check = ?(UserInGroup(GroupsComposition,
						Var_Group.Ref, UsersList.UsersArray[0]), 1, 0);
				Else
					NewSubordinateGroupRow.Check = 2;
				EndIf;
				
			EndIf;
			
			ParentArray.Add(Var_Group.Ref);
		EndDo;
		SubordinateGroups.Clear();
		
		For Each Item In ParentArray Do
			GetSubordinateGroups(UserGroups, SubordinateGroups, Item);
		EndDo;
		
	EndDo;
	
	GroupTreeDestination.Rows.Sort("Group Asc", True);
	ValueToFormAttribute(GroupTreeDestination, "GroupsTree");
	
EndProcedure

// Receives user groups.
//
// Parameters:
//  UserGroups - ValueTable:
//    * Ref - CatalogRef.UserGroups
//    * Parent - CatalogRef.UserGroups
//
&AtServer
Procedure GetUserGroups(UserGroups)
	
	Query = New Query;
	Query.Text = "SELECT
	|	UserGroups.Ref,
	|	UserGroups.Parent
	|FROM
	|	Catalog.UserGroups AS UserGroups
	|WHERE
	|	UserGroups.DeletionMark <> TRUE";
	
	UserGroups = Query.Execute().Unload();
	
EndProcedure

// Receives groups of external users.
//
// Parameters:
//  UserGroups - ValueTable:
//    * Ref - CatalogRef.ExternalUsersGroups
//    * Parent - CatalogRef.ExternalUsersGroups
//    * AllAuthorizationObjects - Boolean
//    * Purpose - ValueTable:
//       ** UsersType - DefinedType.ExternalUser
//
&AtServer
Procedure GetExternalUserGroups(UserGroups)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ExternalUsersGroups.Ref,
	|	ExternalUsersGroups.Parent,
	|	ExternalUsersGroups.AllAuthorizationObjects,
	|	ExternalUsersGroups.Purpose.(
	|		UsersType)
	|FROM
	|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
	|WHERE
	|	ExternalUsersGroups.DeletionMark <> TRUE";
	
	UserGroups = Query.Execute().Unload();
	
EndProcedure

// Receives user subgroups.
// 
// Parameters:
//  UserGroups - See GetExternalUserGroups.UserGroups
//  SubordinateGroups - Array of ValueTableRow: See GetExternalUserGroups.UserGroups
//  ParentGroup1 - CatalogRef.UserGroups
//                 - CatalogRef.ExternalUsersGroups
//
&AtServer
Procedure GetSubordinateGroups(UserGroups, SubordinateGroups, ParentGroup1)
	
	FilterParameters = New Structure("Parent", ParentGroup1);
	PickedRows = UserGroups.FindRows(FilterParameters);
	
	For Each Item In PickedRows Do
		
		If Item.Ref = Users.AllUsersGroup()
			Or Item.Ref = ExternalUsers.AllExternalUsersGroup() Then
			Continue;
		EndIf;
		
		SubordinateGroups.Add(Item);
	EndDo;
	
EndProcedure

&AtServer
Function UsersAuthenticationObjects(UsersArray)
	
	Query = New Query;
	Query.Parameters.Insert("UsersArray", UsersArray);
	Query.Text =
	"SELECT DISTINCT
	|	ExternalUsers.Ref AS Ref,
	|	ExternalUsers.AuthorizationObject AS AuthorizationObject
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.Ref IN (&UsersArray)";
	
	Selection = Query.Execute().Select();
	Result = New Map;
	
	While Selection.Next() Do
		Result.Insert(Selection.Ref, Selection.AuthorizationObject);
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function GroupsComposition()
	
	Query = New Query;
	
	If ThisisExternalUsers Then
		Query.Text =
		"SELECT DISTINCT
		|	GroupsComposition.Ref AS Group,
		|	GroupsComposition.ExternalUser AS User
		|FROM
		|	Catalog.ExternalUsersGroups.Content AS GroupsComposition";
	Else
		Query.Text =
		"SELECT DISTINCT
		|	GroupsComposition.Ref AS Group,
		|	GroupsComposition.User AS User
		|FROM
		|	Catalog.UserGroups.Content AS GroupsComposition";
	EndIf;
	
	Upload0 = Query.Execute().Unload();
	Upload0.Indexes.Add("Group, User");
	
	Return Upload0;
	
EndFunction

&AtServer
Function UserInGroup(GroupsComposition, Var_Group, User)
	
	Filter = New Structure;
	Filter.Insert("Group", Var_Group);
	Filter.Insert("User", User);
	
	Return ValueIsFilled(GroupsComposition.FindRows(Filter));
	
EndFunction

// Parameters:
//  NotifyUser1 - Structure:
//   * Message - String
//   * HasErrors - Boolean
//   * FullMessageText - String
//
&AtServer
Procedure WriteChanges(NotifyUser1)
	
	UsersArray = Undefined;
	NotMovedUsers = New Map;
	GroupTreeSource = GroupsTree.GetItems();
	RefillGroupComposition(GroupTreeSource, GroupsComposition(), UsersArray, NotMovedUsers);
	GenerateMessageText(UsersArray, NotifyUser1, NotMovedUsers)
	
EndProcedure

// Details
// 
// Parameters:
//  GroupTreeSource - FormDataTreeItemCollection
//  MovedUsersArray - Array of CatalogRef.Users
//                                  - Array of CatalogRef.ExternalUsers
//  NotMovedUsers - Map of KeyAndValue:
//    * Key - CatalogRef.Users
//    * Value - Array of CatalogRef.UserGroups
//               - CatalogRef.ExternalUsersGroups
//
&AtServer
Procedure RefillGroupComposition(GroupTreeSource, GroupsComposition, MovedUsersArray, NotMovedUsers)
	
	UsersArray = UsersList.UsersArray; // Array of CatalogRef.Users
	If MovedUsersArray = Undefined Then
		MovedUsersArray = New Array;
	EndIf;
	
	For Each TreeRow In GroupTreeSource Do
		
		If TreeRow.Check = 1
			And Not TreeRow.ReadOnlyGroup Then
			
			For Each UserRef In UsersArray Do
				
				If ThisisExternalUsers Then
					CanMove1 = UsersInternal.CanMoveUser(TreeRow.Group, UserRef);
					
					If Not CanMove1 Then
						
						If NotMovedUsers.Get(UserRef) = Undefined Then
							NotMovedUsers.Insert(UserRef, New Array);
							NotMovedUsers[UserRef].Add(TreeRow.Group);
						Else
							NotMovedUsers[UserRef].Add(TreeRow.Group);
						EndIf;
						
						Continue;
					EndIf;
				EndIf;
				
				If Not UserInGroup(GroupsComposition, TreeRow.Group, UserRef) Then
					Added = False;
					UsersInternal.AddUserToGroup(TreeRow.Group,
						UserRef, CompositionColumnName, Added);
					
					If Added And MovedUsersArray.Find(UserRef) = Undefined Then
						MovedUsersArray.Add(UserRef);
					EndIf;
				EndIf;
				
			EndDo;
			
		ElsIf TreeRow.Check = 0
			And Not TreeRow.ReadOnlyGroup Then
			
			For Each UserRef In UsersArray Do
				
				If UserInGroup(GroupsComposition, TreeRow.Group, UserRef) Then
					Removed = False;
					UsersInternal.DeleteUserFromGroup(TreeRow.Group,
						UserRef, CompositionColumnName, Removed);
					
					If Removed And MovedUsersArray.Find(UserRef) = Undefined Then
						MovedUsersArray.Add(UserRef);
					EndIf;
				EndIf;
				
			EndDo;
			
		EndIf;
		
		TreeRowItems = TreeRow.GetItems();
		// Recursion
		RefillGroupComposition(TreeRowItems, GroupsComposition, MovedUsersArray, NotMovedUsers);
		
	EndDo;
	
EndProcedure

// Parameters:
//  MovedUsersArray - See RefillGroupComposition.MovedUsersArray
//  NotifyUser1         - See WriteChanges.NotifyUser1
//  NotMovedUsers      - See RefillGroupComposition.NotMovedUsers
//
&AtServer
Procedure GenerateMessageText(MovedUsersArray, NotifyUser1, NotMovedUsers)
	
	UsersCount = MovedUsersArray.Count();
	NotMovedUsersCount = NotMovedUsers.Count();
	UserRow = "";
	
	If NotMovedUsersCount > 0 Then
		
		If NotMovedUsersCount = 1 Then
			For Each NotMovedUser In NotMovedUsers Do
				SubjectOf = String(NotMovedUser.Key);
			EndDo;
			UserMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot add user ""%1"" to the selected groups
				           |because they have different types or because the groups have ""All users of the specified types"" option selected.';"),
				SubjectOf);
		Else
			SubjectOf = Format(NotMovedUsersCount, "NFD=0") + " "
				+ UsersInternalClientServer.IntegerSubject(NotMovedUsersCount,
					"", NStr("en = 'user, users,,,0';"));
			UserMessage =
				NStr("en = 'Cannot add some users to the selected groups
				           |because they have different types or because the groups have ""All users of the specified types"" option selected.';");
			For Each NotMovedUser In NotMovedUsers Do
				UserRow = UserRow + String(NotMovedUser.Key)
					+ " : " + StrConcat(NotMovedUser.Value, ",") + Chars.LF;
			EndDo;
			NotifyUser1.FullMessageText =
				NStr("en = 'The following users were not added to the groups:';")
				+ Chars.LF + Chars.LF + UserRow;
		EndIf;
		
		NotifyUser1.Message = UserMessage;
		NotifyUser1.HasErrors = True;
		Return;
		
	ElsIf UsersCount = 1 Then
		UserDescription = Common.ObjectAttributeValue(
			MovedUsersArray[0], "Description");
		
		NotifyUser1.Message = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The list of groups is modified for user ""%1"".';"),
			UserDescription);
			
	ElsIf UsersCount > 1 Then
		StringObject = Format(UsersCount, "NFD=0") + " "
			+ UsersInternalClientServer.IntegerSubject(UsersCount,
				"", NStr("en = 'user, users,,,0';"));
		
		NotifyUser1.Message = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The list of groups is modified for %1.';"), StringObject);
	EndIf;
	
	NotifyUser1.HasErrors = False;
	
EndProcedure

&AtClient
Procedure ExpandValueTree()
	
	For Each Item In GroupsTree.GetItems() Do
		Items.GroupsTree.Expand(Item.GetID(), True);
	EndDo;
	
EndProcedure

&AtClient
Procedure WriteAndCloseQuestionProcessing(Response, FullMessageText) Export
	
	If Response = "OK" Then
		Modified = False;
		WriteAndCloseCompletion();
	Else
		MessageTitle = NStr("en = 'Users not included in the groups';");
		Report = New TextDocument;
		Report.AddLine(FullMessageText);
		Report.Show(MessageTitle);
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteAndCloseWarningProcessing(AdditionalParameters) Export
	
	Modified = False;
	WriteAndCloseCompletion();
	
EndProcedure

&AtClient
Procedure WriteAndCloseCompletion()
	
	Notify("ArrangeUsersInGroups");
	If ThisisExternalUsers Then
		Notify("Write_ExternalUsersGroups");
	Else
		Notify("Write_UserGroups");
	EndIf;
	
	If Not OpenFromUserProfileMode Then
		Close();
	Else
		FillGroupTree();
		ExpandValueTree();
	EndIf;
	
EndProcedure

#EndRegion
