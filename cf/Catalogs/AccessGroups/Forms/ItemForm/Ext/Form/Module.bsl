///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

&AtClient
Var ExternalUsersSelectionAndPickup;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	// Prepare auxiliary data.
	AccessManagementInternal.OnCreateAtServerAllowedValuesEditForm(ThisObject);
	
	InitialSettingsOnReadAndCreate(Object);
	
	ExternalUsersCatalogAvailable = AccessRight(
		"View", Metadata.Catalogs.ExternalUsers);
	
	UserTypesList.Add(Type("CatalogRef.Users"));
	UserTypesList.Add(Type("CatalogRef.ExternalUsers"));
	
	// Making the properties always visible.
	
	// Determining if the access restrictions must be set.
	If Not AccessManagement.LimitAccessAtRecordLevel() Then
		Items.Access.Visible = False;
	EndIf;
	
	// Setting availability for viewing the form in read-only mode.
	Items.UsersPick.Enabled                = Not ReadOnly;
	Items.UsersPickContextMenu.Enabled = Not ReadOnly;
	
	If Common.DataSeparationEnabled()
	   And Object.Ref = AdministratorsAccessGroup
	   And Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		Try
			ActionsWithSaaSUser = ModuleUsersInternalSaaS.GetActionsWithSaaSUser(
				Undefined, ActionsWithSaaSUser);
			If Not ActionsWithSaaSUser.ChangeAdministrativeAccess Then
				Raise(NStr("en = 'Insufficient access rights to edit administrators.';"), 
					ErrorCategory.AccessViolation);
			EndIf;
		Except
			If Not Users.IsFullUser() Then
				Raise;
			EndIf;
			ReadOnly = True;
			ServiceOperationError = ErrorInfo();
		EndTry;
		
	EndIf;
	
	UpdateAssignment();
	
	ProcedureExecutedOnCreateAtServer = True;
	
	If Common.IsStandaloneWorkplace() Then
		If Not Object.Ref = AdministratorsAccessGroup
		   And Not AccessManagementInternal.IsProfileOpenExternalReportsAndDataProcessors(Object.Profile) Then
		
			ReadOnly = True;
		Else
			ProhibitAllChangesExceptMembers();
		EndIf;
	EndIf;
	
	Items.FormWriteAndClose.Enabled = Not ReadOnly
		And AccessRight("Edit", Metadata.Catalogs.AccessGroups);
	
	Parameters.Property("GotoViewAccess",     GotoViewAccess);
	Parameters.Property("JumpToAccessValue", JumpToAccessValue);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If AnswerToQuestionOnOpenForm = "SetReadOnly" Then
		AnswerToQuestionOnOpenForm = "";
		ReadOnly = True;
		Items.FormWriteAndClose.Enabled = False;
	EndIf;
	
	If AnswerToQuestionOnOpenForm = "SetAdministratorProfile" Then
		AnswerToQuestionOnOpenForm = Undefined;
		Object.Profile = ProfileAdministrator;
		Modified = True;
		
	ElsIf Not ReadOnly
	        And Object.Ref = AdministratorsAccessGroup
	        And Object.Profile <> ProfileAdministrator Then
		
		Cancel = True;
		ShowQueryBox(
			New NotifyDescription("OnOpenAfterAdministratorProfileInstallationConfirmation", ThisObject),
			NStr("en = 'The ""Administrators"" access group must have the ""Administrator"" profile.
			           |
			           |Do you want to assign the profile to the access group? If you select ""No"", the group will be read-only.';"),
			QuestionDialogMode.YesNo,
			,
			DialogReturnCode.No);
	Else
		If AnswerToQuestionOnOpenForm = "RefreshAccessKindsContent" Then
			AnswerToQuestionOnOpenForm = "";
			RefreshAccessKindsContent();
			AccessKindsOnReadChanged = False;
			
		ElsIf Not ReadOnly And AccessKindsOnReadChanged Then
			
			Cancel = True;
			ShowQueryBox(
				New NotifyDescription("OnOpenAfterAccessKindUpdateConfirmation", ThisObject),
				NStr("en = 'The access kinds of the access group''s profile were changed.
				           |
				           |Do you want to update the access kinds in the access group? If you select ""No"", the group will be read-only.';"),
				QuestionDialogMode.YesNo,
				,
				DialogReturnCode.No);
		
		ElsIf Not ReadOnly
			   And Not ValueIsFilled(Object.Ref)
			   And TypeOf(FormOwner) = Type("FormTable")
			   And FormOwner.Parent.Parameters.Property("Profile") Then
			
			If ValueIsFilled(FormOwner.Parent.Parameters.Profile) Then
				Object.Profile = FormOwner.Parent.Parameters.Profile;
				AttachIdleHandler("IdleHandlerProfileOnChange", 0.1, True);
			EndIf;
		EndIf;
	EndIf;
	
	If JumpToAccessValue <> Undefined Then
		AttachIdleHandler("JumpToAccessValue", 0.1, True);
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	If ServiceOperationError <> Undefined Then
		CurrentServiceOperationError = ServiceOperationError;
		ServiceOperationError = Undefined;
		StandardSubsystemsClient.OutputErrorInfo(CurrentServiceOperationError);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnReopen()
	
	AttachIdleHandler("JumpToAccessValue", 0.1, True);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Not ProcedureExecutedOnCreateAtServer Then
		Return;
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = Common.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	AccessManagementInternal.OnRereadAtServerAllowedValuesEditForm(ThisObject, CurrentObject);
	
	InitialSettingsOnReadAndCreate(CurrentObject);
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If CommonClient.DataSeparationEnabled()
	   And Object.Ref = AdministratorsAccessGroup
	   And Not WriteParameters.Property("AfterAuthenticationPasswordRequestInService") Then
		
		WriteParameters.Insert("AfterAuthenticationPasswordRequestInService");
		Cancel = True;
		UsersInternalClient.RequestPasswordForAuthenticationInService(
			New NotifyDescription("BeforeWriteFollowUp", ThisObject, WriteParameters),
			ThisObject,
			ServiceUserPassword);
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not Users.IsFullUser() Then
		// Responsible persons can change only the membership.
		// Re-read the object to prevent changes in access groups in restricted areas on the client.
		// 
		RestoreObjectWithoutGroupMembers(CurrentObject);
	EndIf;
	
	CurrentObject.Users.Clear();
	
	If CurrentObject.Ref <> AdministratorsAccessGroup
	   And ValueIsFilled(CurrentObject.User) Then
		
		If PersonalAccessUsage Then
			CurrentObject.Users.Add().User = CurrentObject.User;
		EndIf;
	Else
		For Each Item In GroupUsers.GetItems() Do
			NewRow = CurrentObject.Users.Add();
			NewRow.User = Item.User;
			NewRow.ValidityPeriod = Item.ValidityPeriod;
		EndDo;
	EndIf;
	
	If CurrentObject.Ref = AdministratorsAccessGroup Then
		Object.Parent      = Undefined;
		Object.EmployeeResponsible = Undefined;
	EndIf;
	
	If Common.DataSeparationEnabled()
		And Object.Ref = AdministratorsAccessGroup Then
		
		CurrentObject.AdditionalProperties.Insert(
			"ServiceUserPassword", ServiceUserPassword);
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SetPrivilegedMode(True);
	
	ProfileMarkedForDeletion = Common.ObjectAttributeValue(Object.Profile, "DeletionMark");
	ProfileMarkedForDeletion = ?(ProfileMarkedForDeletion = Undefined, False, ProfileMarkedForDeletion);
	
	SetPrivilegedMode(False);
	
	If Not Object.DeletionMark And ProfileMarkedForDeletion Then
		WriteParameters.Insert("WarnThatProfileIsMarkedForDeletion");
	EndIf;
	
	AccessManagementInternal.AfterWriteAtServerAllowedValuesEditForm(
		ThisObject, CurrentObject, WriteParameters);
		
	UpdateCommentPicture(Items.CommentPage, Object.Comment);
	
	AccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_AccessGroups", New Structure, Object.Ref);
	
	If WriteParameters.Property("WarnThatProfileIsMarkedForDeletion") Then
		
		ShowMessageBox(
			New NotifyDescription("AfterWriteCompletion", ThisObject, WriteParameters),
			NStr("en = 'The access group does not affect its members'' rights
			           |as its profile is marked for deletion.';"));
	Else
		AfterWriteCompletion(WriteParameters);
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	VerifiedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Checking for unfilled and duplicate users.
	VerifiedObjectAttributes.Add("Users.User");
	UsersTreeRows = FormAttributeToValue("GroupUsers").Rows;
	ErrorsCount = ?(Errors = Undefined, 0, Errors.Count());
	
	// Preparing data to check mapping between authorization object types.
	Query = New Query;
	Query.SetParameter("Users", UsersTreeRows.UnloadColumn("User"));
	Query.SetParameter("Parent", Object.Profile);
	Query.Text =
	"SELECT
	|	AccessGroupProfilesAssignment.UsersType AS UsersType
	|INTO AccessGroupProfilesAssignment
	|FROM
	|	Catalog.AccessGroupProfiles.Purpose AS AccessGroupProfilesAssignment
	|WHERE
	|	AccessGroupProfilesAssignment.Ref = &Parent
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExternalUsers.Ref AS Ref,
	|	FALSE AS IsInternal
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	NOT FALSE IN
	|				(SELECT TOP 1
	|					FALSE
	|				FROM
	|					AccessGroupProfilesAssignment AS AccessGroupProfilesAssignment
	|				WHERE
	|					VALUETYPE(AccessGroupProfilesAssignment.UsersType) = VALUETYPE(ExternalUsers.AuthorizationObject))
	|	AND ExternalUsers.Ref IN(&Users)
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUserGroupsAssignment.Ref,
	|	FALSE
	|FROM
	|	Catalog.ExternalUsersGroups.Purpose AS ExternalUserGroupsAssignment
	|WHERE
	|	NOT FALSE IN
	|				(SELECT TOP 1
	|					FALSE
	|				FROM
	|					AccessGroupProfilesAssignment AS AccessGroupProfilesAssignment
	|				WHERE
	|					VALUETYPE(AccessGroupProfilesAssignment.UsersType) = VALUETYPE(ExternalUserGroupsAssignment.UsersType))
	|	AND ExternalUserGroupsAssignment.Ref IN(&Users)
	|
	|UNION ALL
	|
	|SELECT
	|	Users.Ref,
	|	Users.IsInternal
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	(Users.IsInternal
	|			OR NOT FALSE IN
	|					(SELECT TOP 1
	|						FALSE
	|					FROM
	|						AccessGroupProfilesAssignment AS AccessGroupProfilesAssignment
	|					WHERE
	|						VALUETYPE(AccessGroupProfilesAssignment.UsersType) = TYPE(Catalog.Users)))
	|	AND Users.Ref IN(&Users)
	|
	|UNION ALL
	|
	|SELECT
	|	UserGroups.Ref,
	|	FALSE
	|FROM
	|	Catalog.UserGroups AS UserGroups
	|WHERE
	|	NOT FALSE IN
	|				(SELECT TOP 1
	|					FALSE
	|				FROM
	|					AccessGroupProfilesAssignment AS AccessGroupProfilesAssignment
	|				WHERE
	|					VALUETYPE(AccessGroupProfilesAssignment.UsersType) = TYPE(Catalog.Users))
	|	AND UserGroups.Ref IN(&Users)";
	
	SetPrivilegedMode(True);
	ProhibitedUsers = Query.Execute().Unload();
	SetPrivilegedMode(False);
	BegOfDay = BegOfDay(CurrentSessionDate());
	
	For Each CurrentRow In UsersTreeRows Do
		LineNumber = UsersTreeRows.IndexOf(CurrentRow);
		Member = CurrentRow.User;
		ValidityPeriod = CurrentRow.ValidityPeriod;
		
		// Checking whether the value is filled.
		If Not ValueIsFilled(Member) Then
			CommonClientServer.AddUserError(Errors,
				"GroupUsers[%1].User",
				SpecifyMessage(NStr("en = 'The user is not selected.';"), Member),
				"GroupUsers",
				LineNumber,
				SpecifyMessage(NStr("en = 'The user is not selected in line #%1.';"), Member));
		EndIf;
		If ValueIsFilled(ValidityPeriod) And ValidityPeriod <= BegOfDay Then
			DueDate = Format(ValidityPeriod, NStr("en = 'DLF=D';"));
			CommonClientServer.AddUserError(Errors,
				"GroupUsers[%1].User",
				SpecifyMessage(NStr("en = 'Membership of %2 should expire tomorrow or later.';"), DueDate),
				"GroupUsers",
				LineNumber,
				SpecifyMessage(NStr("en = 'Membership of %2 (line %1) should expire tomorrow or later.';"), DueDate));
		EndIf;
		If Not ValueIsFilled(Member) Then
			Continue;
		EndIf;
		
		// Checking for duplicate values.
		FoundValues = UsersTreeRows.FindRows(
			New Structure("User", CurrentRow.User));
		
		If FoundValues.Count() > 1 Then
			
			If TypeOf(CurrentRow.User) = Type("CatalogRef.Users") Then
				SingleErrorText      = NStr("en = 'Duplicate user: ""%2"".';");
				SeveralErrorsText = NStr("en = 'Duplicate user ""%2"" in line #%1.';");
				
			ElsIf TypeOf(CurrentRow.User) = Type("CatalogRef.ExternalUsers") Then
				SingleErrorText      = NStr("en = 'Duplicate external user: ""%2"".';");
				SeveralErrorsText = NStr("en = 'Duplicate external user ""%2"" in line #%1.';");
				
			ElsIf TypeOf(CurrentRow.User) = Type("CatalogRef.UserGroups") Then
				SingleErrorText      = NStr("en = 'Duplicate user group: ""%2"".';");
				SeveralErrorsText = NStr("en = 'Duplicate user group ""%2"" in line #%1.';");
			Else
				SingleErrorText      = NStr("en = 'Duplicate external user group: ""%2"".';");
				SeveralErrorsText = NStr("en = 'Duplicate external user group ""%2"" in line #%1.';");
			EndIf;
			
			CommonClientServer.AddUserError(Errors,
				"GroupUsers[%1].User",
				SpecifyMessage(SingleErrorText, Member),
				"GroupUsers",
				LineNumber,
				SpecifyMessage(SeveralErrorsText, Member));
		EndIf;
		
		// Checking for users in the predefined Administrators group.
		If Object.Ref = AdministratorsAccessGroup
		   And TypeOf(CurrentRow.User) <> Type("CatalogRef.Users") Then
			
			If TypeOf(CurrentRow.User) = Type("CatalogRef.ExternalUsers") Then
				SingleErrorText      = NStr("en = 'External user ""%2"" cannot be a member of the predefined access group ""Administrators"".';");
				SeveralErrorsText = NStr("en = 'External user ""%2"" in line #%1 cannot be a member of the predefined access group ""Administrators"".';");
				
			ElsIf TypeOf(CurrentRow.User) = Type("CatalogRef.UserGroups") Then
				SingleErrorText      = NStr("en = 'User group ""%2"" cannot be a member of the predefined access group ""Administrators"".';");
				SeveralErrorsText = NStr("en = 'User group ""%2"" in line #%1 cannot be a member of the predefined access group ""Administrators"".';");
			Else
				SingleErrorText      = NStr("en = 'External user group ""%2"" cannot be a member of the predefined access group ""Administrators"".';");
				SeveralErrorsText = NStr("en = 'External user group ""%2"" in line #%1 cannot be a member of the predefined access group ""Administrators"".';");
			EndIf;
			
			CommonClientServer.AddUserError(Errors,
				"GroupUsers[%1].User",
				SpecifyMessage(SingleErrorText, Member),
				"GroupUsers",
				LineNumber,
				SpecifyMessage(SeveralErrorsText, Member));
		EndIf;
		
		ProhibitedUser = ProhibitedUsers.Find(CurrentRow.User, "Ref");
		If ProhibitedUser <> Undefined Then
			
			If TypeOf(CurrentRow.User) = Type("CatalogRef.Users") Then
				If ProhibitedUser.IsInternal Then
					SingleErrorText      = NStr("en = 'Rights (roles) of utility user ""%2"" cannot be changed interactively.';");
					SeveralErrorsText = NStr("en = 'Rights (roles) on line %1 of utility user ""%2"" cannot be changed interactively.';");
				Else
					SingleErrorText      = NStr("en = 'User ""%2"" cannot be a member as it does not have the required type.';");
					SeveralErrorsText = NStr("en = 'User ""%2"" in line #%1 cannot be a member as it does not have the required type.';");
				EndIf;
			ElsIf TypeOf(CurrentRow.User) = Type("CatalogRef.UserGroups") Then
				SingleErrorText      = NStr("en = 'User group ""%2"" cannot be a member as it does not have the required type.';");
				SeveralErrorsText = NStr("en = 'User group ""%2"" in line #%1 cannot be a member as it does not have the required type.';");
			ElsIf TypeOf(CurrentRow.User) = Type("CatalogRef.ExternalUsers") Then
				SingleErrorText      = NStr("en = 'External user ""%2"" cannot be a member as it does not have the required type.';");
				SeveralErrorsText = NStr("en = 'External user ""%2"" in line #%1 cannot be a member as it does not have the required type.';");
			Else // External user group.
				SingleErrorText      = NStr("en = 'External user group ""%2"" cannot be a member as it does not have the required type.';");
				SeveralErrorsText = NStr("en = 'External user group ""%2"" in line #%1 cannot be a member as it does not have the required type.';");
			EndIf;
			
			CommonClientServer.AddUserError(Errors,
				"GroupUsers[%1].User",
				SpecifyMessage(SingleErrorText, Member),
				"GroupUsers",
				LineNumber,
				SpecifyMessage(SeveralErrorsText, Member));
			
		EndIf;
		
	EndDo;
	
	If Not Common.DataSeparationEnabled()
		And Object.Ref = AdministratorsAccessGroup Then
		
		ErrorDescription = "";
		AccessManagementInternal.CheckAdministratorsAccessGroupForIBUser(
			GroupUsers.GetItems(), ErrorDescription);
		
		If ValueIsFilled(ErrorDescription) Then
			CommonClientServer.AddUserError(Errors,
				"GroupUsers", ErrorDescription, "");
		EndIf;
	EndIf;
	
	// Checking for blank and duplicate access values.
	SkipKindsAndValuesCheck = False;
	If ErrorsCount <> ?(Errors = Undefined, 0, Errors.Count()) Then
		SkipKindsAndValuesCheck = True;
		Items.UsersAndAccess.CurrentPage = Items.GroupUsers;
	EndIf;
	
	AccessManagementInternalClientServer.ProcessingOfCheckOfFillingAtServerAllowedValuesEditForm(
		ThisObject, Cancel, VerifiedObjectAttributes, Errors, SkipKindsAndValuesCheck);
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
	CheckedAttributes.Delete(CheckedAttributes.Find("Object"));
	CurrentObject = FormAttributeToValue("Object");
	
	CurrentObject.AdditionalProperties.Insert(
		"VerifiedObjectAttributes", VerifiedObjectAttributes);
	
	If Not CurrentObject.CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ProfileOnChange(Item)
	
	ProfileOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure UserOwnerStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	UpdateCommentPicture(Items.CommentPage, Object.Comment);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersUsers

&AtClient
Procedure UsersOnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure UsersBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	If Item.Representation = TableRepresentation.List Then
		If Copy Then
			Cancel = True;
			Items.Users.AddRow();
		EndIf;
		Return;
	EndIf;
	
	If Copy Then
		
		If Item.CurrentData.GetParent() <> Undefined Then
			Cancel = True;
			
			Items.Users.CurrentRow =
				Item.CurrentData.GetParent().GetID();
			
			Items.Users.CopyRow();
		EndIf;
		
	ElsIf Items.Users.CurrentRow <> Undefined Then
		Cancel = True;
		Items.Users.CopyRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersBeforeRowChange(Item, Cancel)
	
	If Item.CurrentData.GetParent() <> Undefined Then
		Cancel = True;
		
		Items.Users.CurrentRow =
			Item.CurrentData.GetParent().GetID();
		
		Items.Users.ChangeRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersBeforeDeleteRow(Item, Cancel)
	
	ParentLevelRow = Item.CurrentData.GetParent();
	
	If ParentLevelRow <> Undefined Then
		Cancel = True;
		
		If TypeOf(ParentLevelRow.User) =
		        Type("CatalogRef.UserGroups") Then
			
			ShowMessageBox(,
				NStr("en = 'Cannot remove users from the list.
				           |The purpose of the list is to display users
				           |that inherit rights from access groups.';"));
		Else
			ShowMessageBox(,
				NStr("en = 'Cannot remove external users from the list.
				           |The purpose of the list is to display external users
				           |that inherit rights from external user access groups.';"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersOnStartEdit(Item, NewRow, Copy)
	
	If Copy Then
		Item.CurrentData.User = Undefined;
	EndIf;
	
	If Item.CurrentData.User = Undefined Then
		Item.CurrentData.PictureNumber = -1;
		Item.CurrentData.User = PredefinedValue(
			"Catalog.Users.EmptyRef");
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersOnEditEnd(Item, NewRow, CancelEdit)
	
	If NewRow
	   And Item.CurrentData <> Undefined
	   And Item.CurrentData.User = PredefinedValue(
	     	"Catalog.Users.EmptyRef") Then
		
		Item.CurrentData.User = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If PickMode Then
		UserType = ?(ExternalUsersSelectionAndPickup,
			New TypeDescription("CatalogRef.ExternalUsers,CatalogRef.ExternalUsersGroups"),
			New TypeDescription("CatalogRef.Users,CatalogRef.UserGroups"));
		UsersItems = GroupUsers.GetItems();
		IndexOf = UsersItems.Count();
		While IndexOf > 0 Do
			IndexOf = IndexOf - 1;
			CurrentUser = UsersItems[IndexOf].User;
			If Not ValueIsFilled(CurrentUser)
			 Or UserType.ContainsType(TypeOf(CurrentUser))
			   And ValueSelected.Find(CurrentUser) = Undefined Then
				UsersItems.Delete(IndexOf);
			EndIf;
		EndDo;
	EndIf;
	
	ModifiedRows = New Array;
	
	If TypeOf(ValueSelected) = Type("Array") Then
		For Each Value In ValueSelected Do
			ValueFound2 = False;
			For Each Item In GroupUsers.GetItems() Do
				If Item.User = Value Then
					ValueFound2 = True;
					Break;
				EndIf;
			EndDo;
			If Not ValueFound2 Then
				NewItem = GroupUsers.GetItems().Add();
				NewItem.User = Value;
				ModifiedRows.Add(NewItem.GetID());
			EndIf;
		EndDo;
		
	ElsIf Item.CurrentData.User <> ValueSelected Then
		Item.CurrentData.User = ValueSelected;
		ModifiedRows.Add(Item.CurrentRow);
	EndIf;
	
	If PickMode Then
		TypeExternalUser = New TypeDescription("CatalogRef.ExternalUsers,
			|CatalogRef.ExternalUsersGroups");
		List = New ValueList;
		UsersItems = GroupUsers.GetItems();
		For Each Item In UsersItems Do
			List.Add(Item,
				?(TypeExternalUser.ContainsType(TypeOf(Item.User)), "2", "1")
					+ String(Item.User));
		EndDo;
		List.SortByPresentation();
		NewIndex = 0;
		For Each ListItem In List Do
			PreviousIndex = UsersItems.IndexOf(ListItem.Value);
			UsersItems.Move(PreviousIndex, NewIndex - PreviousIndex);
			NewIndex = NewIndex + 1;
		EndDo;
	EndIf;
	
	If ModifiedRows.Count() > 0 Then
		UpdatedRows = Undefined;
		RefreshGroupsUsers(ModifiedRows, UpdatedRows);
		For Each RowID In UpdatedRows Do
			Items.Users.Expand(RowID);
		EndDo;
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersAfterDeleteRow(Item)
	
	// Set a tree visibility.
	HasNested = False;
	For Each Item In GroupUsers.GetItems() Do
		If Item.GetItems().Count() > 0 Then
			HasNested = True;
			Break;
		EndIf;
	EndDo;
	
	Items.Users.Representation =
		?(HasNested, TableRepresentation.Tree, TableRepresentation.List);
	
EndProcedure

&AtClient
Procedure UserOnChange(Item)
	
	If ValueIsFilled(Items.Users.CurrentData.User) Then
		RefreshGroupsUsers(Items.Users.CurrentRow);
		Items.Users.Expand(Items.Users.CurrentRow);
	Else
		Items.Users.CurrentData.PictureNumber = -1;
	EndIf;
	
EndProcedure

&AtClient
Procedure UserStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectPickUsers(False);
	PickMode = False;
	
EndProcedure

&AtClient
Procedure UserClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	Items.Users.CurrentData.PictureNumber = -1;
	Items.Users.CurrentData.User  = PredefinedValue(
		"Catalog.Users.EmptyRef");
	
EndProcedure

&AtClient
Procedure UserTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		If Object.Ref = AdministratorsAccessGroup Then
			ChoiceData = AccessManagementInternalServerCall.GenerateUserSelectionData(
				Text, False, False);
		Else
			ChoiceData = AccessManagementInternalServerCall.GenerateUserSelectionData(
				Text);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure UserAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		If Object.Ref = AdministratorsAccessGroup Then
			ChoiceData = AccessManagementInternalServerCall.GenerateUserSelectionData(
				Text, False, False);
		Else
			ChoiceData = AccessManagementInternalServerCall.GenerateUserSelectionData(
				Text);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAccessKinds

&AtClient
Procedure AccessKindsSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Not ReadOnly
	   And Not Items.Access.ReadOnly Then
		
		Items.AccessKinds.ChangeRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure AccessKindsOnActivateRow(Item)
	
	AccessManagementInternalClient.AccessKindsOnActivateRow(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsOnActivateCell(Item)
	
	AccessManagementInternalClient.AccessKindsOnActivateCell(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsOnStartEdit(Item, NewRow, Copy)
	
	AccessManagementInternalClient.AccessKindsOnStartEdit(
		ThisObject, Item, NewRow, Copy);
	
EndProcedure

&AtClient
Procedure AccessKindsOnEditEnd(Item, NewRow, CancelEdit)
	
	AccessManagementInternalClient.AccessKindsOnEditEnd(
		ThisObject, Item, NewRow, CancelEdit);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the "AllAllowedPresentation" item of the "AccessKinds" form table.

&AtClient
Procedure AccessKindsAllAllowedPresentationOnChange(Item)
	
	AccessManagementInternalClient.AccessKindsAllAllowedPresentationOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsAllAllowedPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AccessManagementInternalClient.AccessKindsAllAllowedPresentationChoiceProcessing(
		ThisObject, Item, ValueSelected, StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAccessValues

&AtClient
Procedure AccessValuesOnChange(Item)
	
	AccessManagementInternalClient.AccessValuesOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessValuesOnStartEdit(Item, NewRow, Copy)
	
	AccessManagementInternalClient.AccessValuesOnStartEdit(
		ThisObject, Item, NewRow, Copy);
	
EndProcedure

&AtClient
Procedure AccessValuesOnEditEnd(Item, NewRow, CancelEdit)
	
	AccessManagementInternalClient.AccessValuesOnEditEnd(
		ThisObject, Item, NewRow, CancelEdit);
	
EndProcedure

&AtClient
Procedure AccessValuesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AccessManagementInternalClient.AccessValuesChoiceProcessing(
		ThisObject, Item, ValueSelected, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueStartChoice(
		ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueClearing(Item, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueClearing(
		ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueAutoComplete(
		ThisObject, Item, Text, ChoiceData, Waiting, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueTextInputCompletion(Item, Text, ChoiceData, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueTextInputCompletion(
		ThisObject, Item, Text, ChoiceData, StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	Write(New Structure("WriteAndClose"));
	
EndProcedure

&AtClient
Procedure Pick(Command)
	
	SelectPickUsers(True);
	PickMode = True;
	
EndProcedure

&AtClient
Procedure SnowUnusedAccessKinds(Command)
	
	ShowUnusedAccessKindsAtServer();
	
EndProcedure

&AtClient
Procedure PickAccessValues(Command)
	
	AccessManagementInternalClient.AccessValuesPick(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ValidityPeriod.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("GroupUsers.Level");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 1;
	
	Item.Appearance.SetParameterValue("Visible", False);
	
EndProcedure

// OnOpen event handler continuation.
&AtClient
Procedure OnOpenAfterAdministratorProfileInstallationConfirmation(Response, Context) Export
	
	If Response = DialogReturnCode.Yes Then
		AnswerToQuestionOnOpenForm = "SetAdministratorProfile";
	Else
		AnswerToQuestionOnOpenForm = "SetReadOnly";
	EndIf;
	
	Open();
	
EndProcedure

// OnOpen event handler continuation.
&AtClient
Procedure OnOpenAfterAccessKindUpdateConfirmation(Response, Context) Export
	
	If Response = DialogReturnCode.Yes Then
		AnswerToQuestionOnOpenForm = "RefreshAccessKindsContent";
	Else
		AnswerToQuestionOnOpenForm = "SetReadOnly";
	EndIf;
	
	Open();
	
EndProcedure

// The BeforeWrite event handler continuation.
&AtClient
Procedure BeforeWriteFollowUp(SaaSUserNewPassword, WriteParameters) Export
	
	If SaaSUserNewPassword = Undefined Then
		Return;
	EndIf;
	
	ServiceUserPassword = SaaSUserNewPassword;
	
	Try
		Write(WriteParameters);
	Except
		ServiceUserPassword = Undefined;
		Raise;
	EndTry;
	
EndProcedure

// AfterWrite event handler continuation.
&AtClient
Procedure AfterWriteCompletion(WriteParameters) Export
	
	If WriteParameters.Property("WriteAndClose") Then
		AttachIdleHandler("CloseForm", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseForm()
	
	Close();
	
EndProcedure

&AtClient
Procedure IdleHandlerProfileOnChange()
	
	ProfileOnChangeAtServer();
	
EndProcedure

&AtServer
Procedure ProhibitAllChangesExceptMembers()
	
	Items.Description.ReadOnly          = True;
	Items.Parent.Visible                   = False;
	Items.Profile.ReadOnly               = True;
	Items.PersonalGroupProperties.Visible = False;
	Items.Comment.ReadOnly           = True;
	
EndProcedure

&AtServer
Procedure InitialSettingsOnReadAndCreate(CurrentObject)
	
	ProfileAdministrator        = AccessManagement.ProfileAdministrator();
	AdministratorsAccessGroup = AccessManagement.AdministratorsAccessGroup();
	
	If CurrentObject.Ref = AdministratorsAccessGroup Then
		ProhibitAllChangesExceptMembers();
		
		If Not Users.IsFullUser() Then
			ReadOnly = True;
			Items.FormWriteAndClose.Enabled = False;
		EndIf;
	Else
		If ValueIsFilled(CurrentObject.User) Then
			// Preparing for personal access group mode.
			AutoTitle = False;
			Title = AccessManagementInternalClientServer.PresentationAccessGroups(CurrentObject)
				+ " " + NStr("en = '(Access group)';");
			
			Filter = New Structure("User", CurrentObject.User);
			FoundRows = CurrentObject.Users.FindRows(Filter);
			PersonalAccessUsage = FoundRows.Count() > 0;
		Else
			AutoTitle = True;
		EndIf;
		
		UserFilled = ValueIsFilled(CurrentObject.User);
		
		Items.Description.ReadOnly                 = UserFilled;
		Items.Parent.ReadOnly                     = UserFilled;
		Items.Profile.ReadOnly                      = UserFilled;
		Items.PersonalGroupProperties.Visible        = UserFilled;
		Items.GroupUsers.Visible                = Not UserFilled;
		
		Items.UsersAndAccess.PagesRepresentation =
			?(UserFilled,
			  FormPagesRepresentation.None,
			  FormPagesRepresentation.TabsOnTop);
		
		Items.AccessKinds.TitleLocation =
			?(UserFilled,
			  FormItemTitleLocation.Top,
			  FormItemTitleLocation.None);
		
		Items.UserOwner.ReadOnly
			= AccessManagementInternal.SimplifiedAccessRightsSetupInterface();
		
		// Preparing to switch to the mode where an employee responsible for group members can edit users.
		If Not Users.IsFullUser() Then
			Items.Description.ReadOnly = True;
			Items.Parent.ReadOnly = True;
			Items.Profile.ReadOnly = True;
			Items.Access.ReadOnly = True;
			Items.EmployeeResponsible.ReadOnly = True;
			Items.Comment.ReadOnly = True;
		EndIf;
	EndIf;
	
	RefreshAccessKindsContent(True);
	
	// Prepare a user tree.
	UsersTree = GroupUsers.GetItems();
	UsersTree.Clear();
	For Each TSRow In CurrentObject.Users Do
		NewRow = UsersTree.Add();
		NewRow.User = TSRow.User;
		NewRow.ValidityPeriod = TSRow.ValidityPeriod;
	EndDo;
	RefreshGroupsUsers();
	
	UpdateCommentPicture(Items.CommentPage, Object.Comment);
	
EndProcedure

&AtServer
Procedure ProfileOnChangeAtServer()
	
	UpdateAssignment();
	DeleteNonTypicalUsers();
	RefreshAccessKindsContent();
	AccessManagementInternalClientServer.FillAccessKindsPropertiesInForm(ThisObject);
	
EndProcedure

&AtServer
Procedure UpdateAssignment()
	
	Purpose.Clear();
	PurposePresentation = "";
	AssignmentToProfile = Common.ObjectAttributeValue(Object.Profile, "Purpose");
	If TypeOf(AssignmentToProfile) = Type("QueryResult") Then
		ProfileAssignment = AssignmentToProfile.Unload();
		For Each Member In ProfileAssignment Do
			If Member.UsersType <> Undefined Then
				Purpose.Add(Member.UsersType);
				TypePresentation = Member.UsersType.Metadata().Synonym;
				PurposePresentation = ?(IsBlankString(PurposePresentation),
					TypePresentation, PurposePresentation + ", " + TypePresentation);
			EndIf;
		EndDo;
	EndIf;
	
	Items.Users.ToolTip = NStr("en = 'Allowed members:';") + " " + PurposePresentation;
	
EndProcedure

&AtServer
Procedure DeleteNonTypicalUsers()
	
	TypesArray = New Array;
	For Each Item In Purpose Do
		TypesArray.Add(TypeOf(Item.Value));
	EndDo;
	
	UsersTree = GroupUsers.GetItems();
	RefsWithAuthorizationObject = New Array; // Array of CatalogRef.ExternalUsers
	For Each TreeRow In UsersTree Do
		If TypeOf(TreeRow.User) = Type("CatalogRef.ExternalUsers") Then
			RefsWithAuthorizationObject.Add(TreeRow.User);
		EndIf;
		If TypeOf(TreeRow.User) = Type("CatalogRef.ExternalUsersGroups") Then
			For Each GroupMember In TreeRow.GetItems() Do
				RefsWithAuthorizationObject.Add(GroupMember.User);
			EndDo;
		EndIf;
	EndDo;
	AuthorizationObjects = Common.ObjectsAttributeValue(RefsWithAuthorizationObject, "AuthorizationObject");
	
	IndexOf = UsersTree.Count() - 1;
	While IndexOf >= 0 Do
		
		TreeRow = UsersTree.Get(IndexOf);
		DeleteRow = False;
		
		If (TypeOf(TreeRow.User) = Type("CatalogRef.Users")
			Or TypeOf(TreeRow.User) = Type("CatalogRef.UserGroups"))
			And TypesArray.Find(Type("CatalogRef.Users")) = Undefined Then
			
			DeleteRow = True;
			
		ElsIf TypeOf(TreeRow.User) = Type("CatalogRef.ExternalUsers")
			And TypesArray.Find(TypeOf(AuthorizationObjects.Get(TreeRow.User))) = Undefined Then
			
			DeleteRow = True;
			
		ElsIf TypeOf(TreeRow.User) = Type("CatalogRef.ExternalUsersGroups") Then
			
			For Each GroupMember In TreeRow.GetItems() Do
				
				If TypesArray.Find(TypeOf(AuthorizationObjects.Get(GroupMember.User))) = Undefined Then
					DeleteRow = True;
					Break;
				EndIf;
				
			EndDo;
			
		EndIf;
		
		If DeleteRow Then
			UsersTree.Delete(IndexOf);
		EndIf;
		
		IndexOf = IndexOf - 1;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshAccessKindsContent(Val OnReadAtServer = False)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProfileAccessKinds.AccessKind,
	|	ProfileAccessKinds.Predefined,
	|	ProfileAccessKinds.AllAllowed
	|FROM
	|	Catalog.AccessGroupProfiles.AccessKinds AS ProfileAccessKinds
	|WHERE
	|	ProfileAccessKinds.Ref = &Ref
	|	AND NOT ProfileAccessKinds.Predefined";
	
	Query.SetParameter("Ref", Object.Profile);
	
	SetPrivilegedMode(True);
	ProfileAccessKinds = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	AccessKindsContentChanged = False;
	
	// Adding missing access kinds.
	IndexOf = ProfileAccessKinds.Count() - 1;
	While IndexOf >= 0 Do
		String = ProfileAccessKinds[IndexOf];
		
		Filter = New Structure("AccessKind", String.AccessKind);
		AccessKindProperties = AccessManagementInternal.AccessKindProperties(String.AccessKind);
		
		If AccessKindProperties = Undefined Then
			ProfileAccessKinds.Delete(String);
		
		ElsIf Object.AccessKinds.FindRows(Filter).Count() = 0 Then
			AccessKindsContentChanged = True;
			
			If OnReadAtServer Then
				Break;
			Else
				NewRow = Object.AccessKinds.Add();
				NewRow.AccessKind   = String.AccessKind;
				NewRow.AllAllowed = String.AllAllowed;
			EndIf;
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	// Deleting unused access kinds.
	IndexOf = Object.AccessKinds.Count() - 1;
	While IndexOf >= 0 Do
		
		AccessKind = Object.AccessKinds[IndexOf].AccessKind;
		Filter = New Structure("AccessKind", AccessKind);
		AccessKindProperties = AccessManagementInternal.AccessKindProperties(AccessKind);
		
		If AccessKindProperties = Undefined
		 Or ProfileAccessKinds.FindRows(Filter).Count() = 0 Then
			
			AccessKindsContentChanged = True;
			If OnReadAtServer Then
				Break;
			Else
				Object.AccessKinds.Delete(IndexOf);
				For Each CollectionItem In Object.AccessValues.FindRows(Filter) Do
					Object.AccessValues.Delete(CollectionItem);
				EndDo;
			EndIf;
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Modified = Modified
		Or AccessKindsContentChanged And Not OnReadAtServer;
	
	// Selecting a check box for prompting the user if they want to update the access kind content.
	If OnReadAtServer
	     And Not Object.Ref.IsEmpty() // It is new.
	     And AccessKindsContentChanged
	     And Users.IsFullUser() // Only the administrator can update access kinds.
	     And Common.ObjectAttributeValue(Object.Ref, "Profile") = Object.Profile Then
	     
		AccessKindsOnReadChanged = True;
	EndIf;
	
	Items.Access.Enabled = Object.AccessKinds.Count() > 0;
	
	// Setting access kind order by profile.
	If Not AccessKindsOnReadChanged Then
		For Each TSRow In ProfileAccessKinds Do
			Filter = New Structure("AccessKind", TSRow.AccessKind);
			IndexOf = Object.AccessKinds.IndexOf(Object.AccessKinds.FindRows(Filter)[0]);
			Object.AccessKinds.Move(IndexOf, ProfileAccessKinds.IndexOf(TSRow) - IndexOf);
		EndDo;
	EndIf;
	
	AccessManagementInternalClientServer.FillAccessKindsPropertiesInForm(ThisObject);
	
EndProcedure

&AtServer
Procedure ShowUnusedAccessKindsAtServer()
	
	AccessManagementInternal.RefreshUnusedAccessKindsRepresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure ShowTypeSelectionUsersOrExternalUsers(ContinuationHandler)
	
	ExternalUsersSelectionAndPickup = False;
	
	If Object.Ref = AdministratorsAccessGroup Then
		ExecuteNotifyProcessing(ContinuationHandler, ExternalUsersSelectionAndPickup);
		Return;
	EndIf;
	
	If Purpose.Count() <> 0 Then
		
		If Purpose.FindByValue(PredefinedValue("Catalog.Users.EmptyRef")) <> Undefined Then
			
			If Purpose.Count() <> 1 Then
				
				If UseExternalUsers Then
					
					UserTypesList.ShowChooseItem(
						New NotifyDescription(
						"ShowTypeSelectionUsersOrExternalUsersCompletion",
						ThisObject,
						ContinuationHandler),
						NStr("en = 'Select data type';"),
						UserTypesList[0]);
				Else
					ExecuteNotifyProcessing(ContinuationHandler, ExternalUsersSelectionAndPickup);
				EndIf;
				
				Return;
				
			EndIf;
			
		Else // for external users only.
			
			ExternalUsersSelectionAndPickup = True;
			
		EndIf;
		
	EndIf;
	
	ExecuteNotifyProcessing(ContinuationHandler, ExternalUsersSelectionAndPickup);
	
EndProcedure

&AtClient
Procedure ShowTypeSelectionUsersOrExternalUsersCompletion(SelectedElement, ContinuationHandler) Export
	
	If SelectedElement <> Undefined Then
		ExternalUsersSelectionAndPickup =
			SelectedElement.Value = Type("CatalogRef.ExternalUsers");
		
		ExecuteNotifyProcessing(ContinuationHandler, ExternalUsersSelectionAndPickup);
	Else
		ExecuteNotifyProcessing(ContinuationHandler, Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectPickUsers(Pick)
	
	CurrentUser = ?(Items.Users.CurrentData = Undefined,
		Undefined, Items.Users.CurrentData.User);
	
	If Not Pick
	   And ValueIsFilled(CurrentUser)
	   And (    TypeOf(CurrentUser) = Type("CatalogRef.Users")
	      Or TypeOf(CurrentUser) = Type("CatalogRef.UserGroups") ) Then
	
		ExternalUsersSelectionAndPickup = False;
	
	ElsIf Not Pick
	        And UseExternalUsers
	        And ValueIsFilled(CurrentUser)
	        And (    TypeOf(CurrentUser) = Type("CatalogRef.ExternalUsers")
	           Or TypeOf(CurrentUser) = Type("CatalogRef.ExternalUsersGroups") ) Then
	
		ExternalUsersSelectionAndPickup = True;
	Else
		ShowTypeSelectionUsersOrExternalUsers(
			New NotifyDescription("SelectPickUsersCompletion", ThisObject, Pick));
		Return;
	EndIf;
	
	SelectPickUsersCompletion(ExternalUsersSelectionAndPickup, Pick);
	
EndProcedure

&AtClient
Procedure SelectPickUsersCompletion(ExternalUsersSelectionAndPickup, Pick) Export
	
	If ExternalUsersSelectionAndPickup = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow",
		?(Items.Users.CurrentData = Undefined,
			Undefined, Items.Users.CurrentData.User));
	
	If Pick Then
		FormParameters.Insert("CloseOnChoice", False);
		FormParameters.Insert("MultipleChoice", True);
		FormParameters.Insert("AdvancedPick", True);
		FormParameters.Insert("ExtendedPickFormParameters",
			ExtendedPickFormParameters(ExternalUsersSelectionAndPickup));
	EndIf;
	
	If Object.Ref <> AdministratorsAccessGroup Then
		If ExternalUsersSelectionAndPickup Then
			FormParameters.Insert("SelectExternalUsersGroups", True);
		Else
			FormParameters.Insert("UsersGroupsSelection", True);
		EndIf;
	EndIf;
	
	If ExternalUsersSelectionAndPickup Then
		
		FormParameters.Insert("Purpose", Purpose.UnloadValues());
		
		If Not UseExternalUsers Then
			ShowMessageBox(, NStr("en = 'External users are disabled in the settings.';"));
		ElsIf ExternalUsersCatalogAvailable Then
			OpenForm("Catalog.ExternalUsers.ChoiceForm", FormParameters, Items.Users);
		Else
			Raise(NStr("en = 'Insufficient rights to select external users.';"),
				ErrorCategory.AccessViolation);
		EndIf;
	Else
		OpenForm("Catalog.Users.ChoiceForm", FormParameters, Items.Users);
	EndIf;
	
EndProcedure

&AtServer
Function ExtendedPickFormParameters(ExternalUsersSelectionAndPickup)
	
	PickingParameters = UsersInternal.NewParametersOfExtendedPickForm();
	PickingParameters.PickFormHeader = NStr("en = 'Pick access group members';");
	
	CollectionItems = GroupUsers.GetItems();
	
	UserType = ?(ExternalUsersSelectionAndPickup,
		New TypeDescription("CatalogRef.ExternalUsers,CatalogRef.ExternalUsersGroups"),
		New TypeDescription("CatalogRef.Users,CatalogRef.UserGroups"));
	
	For Each Item In CollectionItems Do
		If UserType.ContainsType(TypeOf(Item.User))
		   And ValueIsFilled(Item.User) Then
			PickingParameters.SelectedUsers.Add(Item.User);
		EndIf;
	EndDo;
	
	Return PutToTempStorage(PickingParameters, UUID);
	
EndFunction

&AtServer
Procedure RefreshGroupsUsers(RowID = Undefined,
                                     ModifiedRows = Undefined)
	
	SetPrivilegedMode(True);
	ModifiedRows = New Array;
	
	If RowID = Undefined Then
		CollectionItems = GroupUsers.GetItems();
		
	ElsIf TypeOf(RowID) = Type("Array") Then
		CollectionItems = New Array;
		For Each Id In RowID Do
			CollectionItems.Add(GroupUsers.FindByID(Id));
		EndDo;
	Else
		CollectionItems = New Array;
		CollectionItems.Add(GroupUsers.FindByID(RowID));
	EndIf;
	
	UserGroupMembers = New Array;
	For Each Item In CollectionItems Do
		CurrentUser = ?(TypeOf(Item) = Type("FormDataTreeItem"),
			Item.User, Item);
		
		If TypeOf(CurrentUser) = Type("CatalogRef.UserGroups")
		 Or TypeOf(CurrentUser) = Type("CatalogRef.ExternalUsersGroups") Then
		
			UserGroupMembers.Add(CurrentUser);
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("UserGroupMembers", UserGroupMembers);
	Query.Text =
	"SELECT
	|	UserGroupCompositions.UsersGroup AS UsersGroup,
	|	UserGroupCompositions.User AS User
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	UserGroupCompositions.UsersGroup IN(&UserGroupMembers)
	|	AND UserGroupCompositions.User.Invalid <> TRUE
	|	AND UserGroupCompositions.User.IsInternal <> TRUE";
	
	GroupsUsers = Query.Execute().Unload();
	GroupsUsers.Indexes.Add("UsersGroup");
	
	For Each Item In CollectionItems Do
		Item.Ref = Item.User;
		
		If TypeOf(Item.User) = Type("CatalogRef.UserGroups")
		 Or TypeOf(Item.User) = Type("CatalogRef.ExternalUsersGroups") Then
		
			// Populate group users.
			OldUsers = Item.GetItems();
			Filter = New Structure("UsersGroup", Item.User);
			NewUsers = GroupsUsers.FindRows(Filter);
			
			HasChanges = False;
			
			If OldUsers.Count() <> NewUsers.Count() Then
				OldUsers.Clear();
				For Each String In NewUsers Do
					NewItem = OldUsers.Add();
					NewItem.Ref       = String.User;
					NewItem.User = String.User;
					NewItem.Level      = 1;
				EndDo;
				HasChanges = True;
			Else
				IndexOf = 0;
				For Each String In OldUsers Do
					
					If String.Ref       <> NewUsers[IndexOf].User
					 Or String.User <> NewUsers[IndexOf].User Then
						
						String.Ref       = NewUsers[IndexOf].User;
						String.User = NewUsers[IndexOf].User;
						HasChanges = True;
					EndIf;
					IndexOf = IndexOf + 1;
				EndDo;
			EndIf;
			
			If HasChanges Then
				ModifiedRows.Add(Item.GetID());
			EndIf;
		EndIf;
	EndDo;
	
	Users.FillUserPictureNumbers(
		GroupUsers, "Ref", "PictureNumber", RowID, True);
	
	// Set the tree visibility.
	HasTree = False;
	For Each Item In GroupUsers.GetItems() Do
		If Item.GetItems().Count() > 0 Then
			HasTree = True;
			Break;
		EndIf;
	EndDo;
	Items.Users.Representation = ?(HasTree, TableRepresentation.Tree, TableRepresentation.List);
	
EndProcedure

&AtServer
Procedure RestoreObjectWithoutGroupMembers(CurrentObject)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroups.DeletionMark AS DeletionMark,
	|	AccessGroups.Predefined AS Predefined,
	|	AccessGroups.Parent AS Parent,
	|	AccessGroups.IsFolder AS IsFolder,
	|	AccessGroups.Description AS Description,
	|	AccessGroups.Profile AS Profile,
	|	AccessGroups.EmployeeResponsible AS EmployeeResponsible,
	|	AccessGroups.User AS User,
	|	AccessGroups.Comment AS Comment
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroupsTypesOfAccess.AccessKind AS AccessKind,
	|	AccessGroupsTypesOfAccess.AllAllowed AS AllAllowed
	|FROM
	|	Catalog.AccessGroups.AccessKinds AS AccessGroupsTypesOfAccess
	|WHERE
	|	AccessGroupsTypesOfAccess.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroupsAccessValues.AccessKind AS AccessKind,
	|	AccessGroupsAccessValues.AccessValue AS AccessValue
	|FROM
	|	Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|WHERE
	|	AccessGroupsAccessValues.Ref = &Ref";
	
	Query.SetParameter("Ref", CurrentObject.Ref);
	QueriesResults = Query.ExecuteBatch();
	
	// Restoring attributes.
	FillPropertyValues(CurrentObject, QueriesResults[0].Unload()[0]);
	
	// Restoring the AccessKinds tabular section.
	CurrentObject.AccessKinds.Load(QueriesResults[1].Unload());
	
	// Restoring the AccessValues tabular section.
	CurrentObject.AccessValues.Load(QueriesResults[2].Unload());
	
EndProcedure

&AtServer
Function SpecifyMessage(String, Value)
	
	Return StrReplace(String, "%2", Value);
	
EndFunction

&AtClientAtServerNoContext
Procedure UpdateCommentPicture(Item, Comment)
	
	Item.Picture = CommonClientServer.CommentPicture(Comment);
	
EndProcedure

&AtClient
Procedure JumpToAccessValue()
	
	If JumpToAccessValue <> Undefined Then
		Items.UsersAndAccess.CurrentPage = Items.Access;
		CurrentItem = Items.Access;
		Filter = New Structure("AccessKind", GotoViewAccess);
		FoundRows = Object.AccessKinds.FindRows(Filter);
		If FoundRows.Count() = 1 Then
			CurrentItem = Items.AccessKindsAccessKindPresentation;
			Items.AccessKinds.CurrentRow = FoundRows[0].GetID();
			Filter.Insert("AccessValue", JumpToAccessValue);
			FoundRows = Object.AccessValues.FindRows(Filter);
			If FoundRows.Count() = 1 Then
				CurrentItem = Items.AccessValuesAccessValue;
				Items.AccessValues.CurrentRow = FoundRows[0].GetID();
			EndIf;
		EndIf;
	EndIf;
	
	GotoViewAccess     = Undefined;
	JumpToAccessValue = Undefined;
	
EndProcedure

// StandardSubsystems.AttachableCommands

&AtClient
Procedure Attachable_ExecuteCommand(Command)
	ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
	ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
	ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
	ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure

// End StandardSubsystems.AttachableCommands

#EndRegion
