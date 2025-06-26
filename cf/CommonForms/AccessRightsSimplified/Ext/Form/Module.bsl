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
	
	ProfileAdministrator = AccessManagement.ProfileAdministrator();
	SetConditionalAppearance();
	
	If Not ValueIsFilled(Parameters.User) Then
		Cancel = True;
		Return;
	EndIf;
	
	If TypeOf(Parameters.User) = Type("CatalogRef.Users")
	   And Common.ObjectAttributeValue(Parameters.User, "IsInternal") = True Then
		
		IsInternalUser = True;
		Items.UtilityUserRights.Visible = True;
		CommandBar.Visible = False;
		Items.RightsAndRestrictions.Visible = False;
		Return;
	EndIf;
	
	CurrentRestrictionsAvailability = True;
	EditCurrentRestrictions = True;
	
	If Users.IsFullUser() Then
		// Viewing and editing profile content and access restrictions.
		FilterProfilesOnlyForCurrentUser = False;
		
	ElsIf Parameters.User = Users.AuthorizedUser() Then
		// Viewing your profiles and the access rights report.
		FilterProfilesOnlyForCurrentUser = True;
		// Hiding unused information.
		Items.Profiles.ReadOnly = True;
		Items.ProfilesCheck.Visible = False;
		Items.Access.Visible = False;
		Items.FormWrite.Visible = False;
	Else
		Items.FormWrite.Visible = False;
		Items.FormReportUserRights.Visible = False;
		Items.FormAccessRightsReport.Visible = False;
		Items.RightsAndRestrictions.Visible = False;
		Items.InsufficientViewRights.Visible = True;
		Return;
	EndIf;
	
	If TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsers") Then
		Items.Profiles.Title = NStr("en = 'External user profiles';");
	Else
		Items.Profiles.Title = NStr("en = 'User profiles';");
	EndIf;
	
	ImportData(FilterProfilesOnlyForCurrentUser);
	
	// Prepare auxiliary data.
	AccessManagementInternal.OnCreateAtServerAllowedValuesEditForm(ThisObject, , "");
	
	For Each ProfileProperties In Profiles Do
		CurrentAccessGroup = ProfileProperties.Profile;
		AccessManagementInternalClientServer.FillAccessKindsPropertiesInForm(ThisObject);
	EndDo;
	CurrentAccessGroup = "";
	
	// Determining if the access restrictions must be set.
	If Not AccessManagement.LimitAccessAtRecordLevel() Then
		Items.Access.Visible = False;
	EndIf;
	
	If Common.DataSeparationEnabled()
	   And Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		Try
			ActionsWithSaaSUser = ModuleUsersInternalSaaS.GetActionsWithSaaSUser(
				Undefined, ActionsWithSaaSUser);
		Except
			ServiceOperationError = ErrorInfo();
		EndTry;
		
		AdministrativeAccessChangeProhibition = Not ActionsWithSaaSUser.ChangeAdministrativeAccess;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If TypeOf(FormOwner) <> Type("ClientApplicationForm")
	 Or FormOwner.Window <> Window Then
		
		AutoTitle = False;
		Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Access rights (%1)';"), String(Parameters.User));
	EndIf;
	
	If ServiceOperationError <> Undefined Then
		CurrentServiceOperationError = ServiceOperationError;
		ServiceOperationError = Undefined;
		StandardSubsystemsClient.OutputErrorInfo(CurrentServiceOperationError);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If IsInternalUser Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("WriteAndCloseNotification", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// Checking for blank and duplicate access values.
	Errors = Undefined;
	
	For Each ProfileProperties In Profiles Do
		
		CurrentAccessGroup = ProfileProperties.Profile;
		AccessManagementInternalClientServer.ProcessingOfCheckOfFillingAtServerAllowedValuesEditForm(
			ThisObject, Cancel, New Array, Errors);
		
		If Cancel Then
			Break;
		EndIf;
		
	EndDo;
	
	If Cancel Then
		CurrentAccessKindRow = Items.AccessKinds.CurrentRow;
		CurrentAccessValueRowOnError = Items.AccessValues.CurrentRow;
		
		Items.Profiles.CurrentRow = ProfileProperties.GetID();
		OnChangeCurrentProfile(ThisObject, False);
		
		Items.AccessKinds.CurrentRow = CurrentAccessKindRow;
		AccessManagementInternalClientServer.OnChangeCurrentAccessKind(ThisObject, False);
		
		CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	Else
		CurrentAccessGroup = CurrentProfile;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetCurrentAccessValueRowOnError()
	
	If CurrentAccessValueRowOnError <> Undefined Then
		Items.AccessValues.CurrentRow = CurrentAccessValueRowOnError;
		CurrentAccessValueRowOnError = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersProfiles

&AtClient
Procedure ProfilesOnActivateRow(Item)
	
	AttachIdleHandler("IdleHandlerProfilesOnActivateRow", 0.1, True);
	
EndProcedure

&AtClient
Procedure ProfilesCheckOnChange(Item)
	
	Cancel = False;
	CurrentData = Items.Profiles.CurrentData;
	
	If CurrentData <> Undefined
	   And Not CurrentData.Check Then
		// Validate for empty and duplicate access values before
		// disabling the profile and its setting.
		ClearMessages();
		Errors = Undefined;
		AccessManagementInternalClientServer.ProcessingOfCheckOfFillingAtServerAllowedValuesEditForm(
			ThisObject, Cancel, New Array, Errors);
		CurrentAccessValueRowOnError = Items.AccessValues.CurrentRow;
		CommonClientServer.ReportErrorsToUser(Errors, Cancel);
		AttachIdleHandler("SetCurrentAccessValueRowOnError", True, 0.1);
	EndIf;
	
	If Cancel Then
		CurrentData.Check = True;
	Else
		OnChangeCurrentProfile(ThisObject);
	EndIf;
	
	If CurrentData <> Undefined
		And CurrentData.Profile = ProfileAdministrator Then
		
		SynchronizationWithServiceRequired = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAccessKinds

&AtClient
Procedure AccessKindsSelection(Item, RowSelected, Field, StandardProcessing)
	
	If EditCurrentRestrictions Then
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
// Event handlers of the AllAllowedPresentation item of the AccessKinds form table.

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
Procedure Write(Command)
	
	WriteChanges();
	
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

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ProfilesCheck.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("AdministrativeAccessChangeProhibition");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Profiles.Profile");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = ProfileAdministrator;

	Item.Appearance.SetParameterValue("Enabled", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ProfilesCheck.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ProfilesProfilePresentation.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("AdministrativeAccessChangeProhibition");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Profiles.Profile");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = ProfileAdministrator;

	Item.Appearance.SetParameterValue("BackColor", StyleColors.InaccessibleCellTextColor);

EndProcedure

// The BeforeClose event handler continuation.
&AtClient
Procedure WriteAndCloseNotification(Result, Context) Export
	
	WriteChanges(New NotifyDescription("WriteAndCloseCompletion", ThisObject));
	
EndProcedure

// The BeforeClose event handler continuation.
&AtClient
Procedure WriteAndCloseCompletion(Cancel, Context) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	Close();
	
EndProcedure

&AtClient
Procedure WriteChanges(ContinuationHandler = Undefined)
	
	If CommonClient.DataSeparationEnabled()
	   And SynchronizationWithServiceRequired Then
		
		UsersInternalClient.RequestPasswordForAuthenticationInService(
			New NotifyDescription("WriteChangesCompletion", ThisObject, ContinuationHandler),
			ThisObject,
			ServiceUserPassword);
	Else
		WriteChangesCompletion(Null, ContinuationHandler);
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteChangesCompletion(SaaSUserNewPassword, ContinuationHandler) Export
	
	If SaaSUserNewPassword = Undefined Then
		Return;
	EndIf;
	
	If SaaSUserNewPassword <> Null Then
		ServiceUserPassword = SaaSUserNewPassword;
	EndIf;
	
	ClearMessages();
	
	Cancel = False;
	CancelOnWriteChanges = False;
	Try
		WriteChangesAtServer(Cancel);
	Except
		ErrorInfo = ErrorInfo();
		If CancelOnWriteChanges Then
			CommonClient.MessageToUser(
				ErrorProcessing.BriefErrorDescription(ErrorInfo),,,, Cancel);
		Else
			Raise;
		EndIf;
	EndTry;
	
	AttachIdleHandler("SetCurrentAccessValueRowOnError", True, 0.1);
	
	If ContinuationHandler = Undefined Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(ContinuationHandler, Cancel);
	
EndProcedure

&AtServer
Procedure ShowUnusedAccessKindsAtServer()
	
	AccessManagementInternal.RefreshUnusedAccessKindsRepresentation(ThisObject);
	
EndProcedure

&AtServer
Procedure ImportData(FilterProfilesOnlyForCurrentUser)
	
	Query = New Query;
	Query.SetParameter("User", Parameters.User);
	Query.SetParameter("ProfileAdministrator", ProfileAdministrator);
	Query.SetParameter("FilterProfilesOnlyForCurrentUser",
	                           FilterProfilesOnlyForCurrentUser);
	Query.Text =
	"SELECT DISTINCT
	|	Profiles.Ref AS Ref,
	|	ISNULL(AccessGroups.Ref, UNDEFINED) AS PersonalAccessGroup,
	|	CASE
	|		WHEN AccessGroups_Users.Ref IS NULL
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Check
	|INTO Profiles
	|FROM
	|	Catalog.AccessGroupProfiles AS Profiles
	|		LEFT JOIN Catalog.AccessGroups AS AccessGroups
	|		ON Profiles.Ref = AccessGroups.Profile
	|			AND (NOT(AccessGroups.User <> &User
	|					AND Profiles.Ref <> &ProfileAdministrator))
	|		LEFT JOIN Catalog.AccessGroups.Users AS AccessGroups_Users
	|		ON (AccessGroups.Ref = AccessGroups_Users.Ref)
	|			AND (AccessGroups_Users.User = &User)
	|WHERE
	|	NOT Profiles.DeletionMark
	|	AND NOT Profiles.IsFolder
	|	AND NOT(&FilterProfilesOnlyForCurrentUser = TRUE
	|				AND AccessGroups_Users.Ref IS NULL)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	Profiles.Ref.Description AS ProfilePresentation,
	|	Profiles.Check AS Check,
	|	Profiles.PersonalAccessGroup AS AccessGroup
	|FROM
	|	Profiles AS Profiles
	|
	|ORDER BY
	|	ProfilePresentation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS AccessGroup,
	|	ProfilesAccessKinds1.AccessKind AS AccessKind,
	|	ISNULL(AccessGroupsTypesOfAccess.AllAllowed, ProfilesAccessKinds1.AllAllowed) AS AllAllowed,
	|	"""" AS AccessKindPresentation,
	|	"""" AS AllAllowedPresentation
	|FROM
	|	Profiles AS Profiles
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfilesAccessKinds1
	|		ON Profiles.Ref = ProfilesAccessKinds1.Ref
	|		LEFT JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsTypesOfAccess
	|		ON Profiles.PersonalAccessGroup = AccessGroupsTypesOfAccess.Ref
	|			AND (ProfilesAccessKinds1.AccessKind = AccessGroupsTypesOfAccess.AccessKind)
	|WHERE
	|	NOT ProfilesAccessKinds1.Predefined
	|
	|ORDER BY
	|	Profiles.Ref.Description,
	|	ProfilesAccessKinds1.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS AccessGroup,
	|	ProfilesAccessKinds1.AccessKind AS AccessKind,
	|	0 AS RowNumberByKind,
	|	AccessGroupsAccessValues.AccessValue AS AccessValue,
	|	AccessGroupsAccessValues.IncludeSubordinateAccessValues AS IncludeSubordinateAccessValues
	|FROM
	|	Profiles AS Profiles
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfilesAccessKinds1
	|		ON Profiles.Ref = ProfilesAccessKinds1.Ref
	|		INNER JOIN Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|		ON Profiles.PersonalAccessGroup = AccessGroupsAccessValues.Ref
	|			AND (ProfilesAccessKinds1.AccessKind = AccessGroupsAccessValues.AccessKind)
	|WHERE
	|	NOT ProfilesAccessKinds1.Predefined
	|
	|ORDER BY
	|	Profiles.Ref.Description,
	|	ProfilesAccessKinds1.LineNumber,
	|	AccessGroupsAccessValues.LineNumber";
	
	SetPrivilegedMode(True);
	QueryResults = Query.ExecuteBatch();
	SetPrivilegedMode(False);
	
	ValueToFormAttribute(QueryResults[1].Unload(), "Profiles");
	ValueToFormAttribute(QueryResults[2].Unload(), "AccessKinds");
	ValueToFormAttribute(QueryResults[3].Unload(), "AccessValues");
	
EndProcedure

&AtServer
Procedure WriteChangesAtServer(Cancel)
	
	If Not CheckFilling() Then
		Cancel = True;
		Return;
	EndIf;
	
	Users.FindAmbiguousIBUsers(Undefined);
	
	// Get a change list.
	Query = New Query;
	Query.SetParameter("User", Parameters.User);
	Query.SetParameter("ProfileAdministrator", ProfileAdministrator);
	Query.SetParameter("Profiles", Profiles.Unload(, "Profile, Check"));
	Query.SetParameter("AccessKinds", AccessKinds.Unload(, "AccessGroup, AccessKind, AllAllowed"));
	
	ValueTable = AccessValues.Unload(, "AccessGroup, AccessKind, AccessValue, IncludeSubordinateAccessValues");
	ValueTable.Columns.Add("LineNumber", New TypeDescription("Number",,,
		New NumberQualifiers(10, 0, AllowedSign.Nonnegative)));
	
	AccessGroupInRow = Undefined;
	For Each TableRow In ValueTable Do
		If AccessGroupInRow <> TableRow.AccessGroup Then
			AccessGroupInRow = TableRow.AccessGroup;
			CurrentRowNumber1 = 1;
		EndIf;
		TableRow.LineNumber = CurrentRowNumber1;
		CurrentRowNumber1 = CurrentRowNumber1 + 1;
	EndDo;
	Query.SetParameter("AccessValues", ValueTable);
	
	Query.Text =
	"SELECT
	|	Profiles.Profile AS Ref,
	|	Profiles.Check
	|INTO Profiles
	|FROM
	|	&Profiles AS Profiles
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKinds.AccessGroup AS Profile,
	|	AccessKinds.AccessKind,
	|	AccessKinds.AllAllowed
	|INTO AccessKinds
	|FROM
	|	&AccessKinds AS AccessKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessValues.AccessGroup AS Profile,
	|	AccessValues.AccessKind,
	|	AccessValues.LineNumber,
	|	AccessValues.AccessValue,
	|	AccessValues.IncludeSubordinateAccessValues
	|INTO AccessValues
	|FROM
	|	&AccessValues AS AccessValues
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Profiles.Ref,
	|	ISNULL(AccessGroups.Ref, UNDEFINED) AS PersonalAccessGroup,
	|	CASE
	|		WHEN AccessGroups_Users.Ref IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Check
	|INTO CurrentProfiles
	|FROM
	|	Catalog.AccessGroupProfiles AS Profiles
	|		LEFT JOIN Catalog.AccessGroups AS AccessGroups
	|		ON Profiles.Ref = AccessGroups.Profile
	|			AND (NOT(AccessGroups.User <> &User
	|					AND Profiles.Ref <> &ProfileAdministrator))
	|		LEFT JOIN Catalog.AccessGroups.Users AS AccessGroups_Users
	|		ON (AccessGroups.Ref = AccessGroups_Users.Ref)
	|			AND (AccessGroups_Users.User = &User)
	|WHERE
	|	NOT Profiles.DeletionMark
	|	AND NOT Profiles.IsFolder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	AccessGroupsTypesOfAccess.AccessKind,
	|	AccessGroupsTypesOfAccess.AllAllowed
	|INTO CurrentAccessKinds
	|FROM
	|	CurrentProfiles AS Profiles
	|		INNER JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsTypesOfAccess
	|		ON Profiles.PersonalAccessGroup = AccessGroupsTypesOfAccess.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	AccessGroupsAccessValues.AccessKind,
	|	AccessGroupsAccessValues.LineNumber,
	|	AccessGroupsAccessValues.AccessValue,
	|	AccessGroupsAccessValues.IncludeSubordinateAccessValues
	|INTO CurrentAccessValues
	|FROM
	|	CurrentProfiles AS Profiles
	|		INNER JOIN Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|		ON Profiles.PersonalAccessGroup = AccessGroupsAccessValues.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ChangedGroupsProfiles.Profile
	|INTO ChangedGroupsProfiles
	|FROM
	|	(SELECT
	|		Profiles.Ref AS Profile
	|	FROM
	|		Profiles AS Profiles
	|			INNER JOIN CurrentProfiles AS CurrentProfiles
	|			ON Profiles.Ref = CurrentProfiles.Ref
	|	WHERE
	|		Profiles.Check <> CurrentProfiles.Check
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessKinds.Profile
	|	FROM
	|		AccessKinds AS AccessKinds
	|			LEFT JOIN CurrentAccessKinds AS CurrentAccessKinds
	|			ON AccessKinds.Profile = CurrentAccessKinds.Profile
	|				AND AccessKinds.AccessKind = CurrentAccessKinds.AccessKind
	|				AND AccessKinds.AllAllowed = CurrentAccessKinds.AllAllowed
	|	WHERE
	|		CurrentAccessKinds.AccessKind IS NULL 
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CurrentAccessKinds.Profile
	|	FROM
	|		CurrentAccessKinds AS CurrentAccessKinds
	|			LEFT JOIN AccessKinds AS AccessKinds
	|			ON (AccessKinds.Profile = CurrentAccessKinds.Profile)
	|				AND (AccessKinds.AccessKind = CurrentAccessKinds.AccessKind)
	|				AND (AccessKinds.AllAllowed = CurrentAccessKinds.AllAllowed)
	|	WHERE
	|		AccessKinds.AccessKind IS NULL 
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValues.Profile
	|	FROM
	|		AccessValues AS AccessValues
	|			LEFT JOIN CurrentAccessValues AS CurrentAccessValues
	|			ON AccessValues.Profile = CurrentAccessValues.Profile
	|				AND AccessValues.AccessKind = CurrentAccessValues.AccessKind
	|				AND AccessValues.LineNumber = CurrentAccessValues.LineNumber
	|				AND AccessValues.AccessValue = CurrentAccessValues.AccessValue
	|				AND AccessValues.IncludeSubordinateAccessValues = CurrentAccessValues.IncludeSubordinateAccessValues
	|	WHERE
	|		CurrentAccessValues.AccessKind IS NULL 
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CurrentAccessValues.Profile
	|	FROM
	|		CurrentAccessValues AS CurrentAccessValues
	|			LEFT JOIN AccessValues AS AccessValues
	|			ON (AccessValues.Profile = CurrentAccessValues.Profile)
	|				AND (AccessValues.AccessKind = CurrentAccessValues.AccessKind)
	|				AND (AccessValues.LineNumber = CurrentAccessValues.LineNumber)
	|				AND (AccessValues.AccessValue = CurrentAccessValues.AccessValue)
	|				AND (AccessValues.IncludeSubordinateAccessValues = CurrentAccessValues.IncludeSubordinateAccessValues)
	|	WHERE
	|		AccessValues.AccessKind IS NULL ) AS ChangedGroupsProfiles
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	CatalogProfiles.Description AS ProfileDescription,
	|	Profiles.Check,
	|	CurrentProfiles.PersonalAccessGroup
	|FROM
	|	ChangedGroupsProfiles AS ChangedGroupsProfiles
	|		INNER JOIN Profiles AS Profiles
	|		ON ChangedGroupsProfiles.Profile = Profiles.Ref
	|		INNER JOIN CurrentProfiles AS CurrentProfiles
	|		ON ChangedGroupsProfiles.Profile = CurrentProfiles.Ref
	|		INNER JOIN Catalog.AccessGroupProfiles AS CatalogProfiles
	|		ON (CatalogProfiles.Ref = ChangedGroupsProfiles.Profile)";
	
	BeginTransaction();
	Try
		AccessGroupsChanges = Query.Execute().Unload();
		
		Block = New DataLock;
		For Each Update In AccessGroupsChanges Do
			LockItem = Block.Add("Catalog.AccessGroups");
			If ValueIsFilled(Update.PersonalAccessGroup) Then
				LockItem.SetValue("Ref", Update.PersonalAccessGroup);
				LockDataForEdit(Update.PersonalAccessGroup);
			EndIf;	
		EndDo;
		Block.Lock();
		
		For Each Update In AccessGroupsChanges Do
			If ValueIsFilled(Update.PersonalAccessGroup) Then
				AccessGroupObject = Update.PersonalAccessGroup.GetObject();
				AccessGroupObject.DeletionMark = False;
			Else
				// Creating a personal access group.
				AccessGroupObject = Catalogs.AccessGroups.CreateItem();
				AccessGroupObject.Parent     = Catalogs.AccessGroups.PersonalAccessGroupsParent();
				AccessGroupObject.Description = Update.ProfileDescription;
				AccessGroupObject.User = Parameters.User;
				AccessGroupObject.Profile      = Update.Profile;
			EndIf;
			
			If Update.Profile = ProfileAdministrator Then
				
				If SynchronizationWithServiceRequired Then
					AccessGroupObject.AdditionalProperties.Insert("ServiceUserPassword", ServiceUserPassword);
				EndIf;
				
				If Update.Check Then
					If AccessGroupObject.Users.Find(Parameters.User, "User") = Undefined Then
						AccessGroupObject.Users.Add().User = Parameters.User;
					EndIf;
				Else
					UserDetails =  AccessGroupObject.Users.Find(
						Parameters.User, "User");
					If UserDetails <> Undefined Then
						AccessGroupObject.Users.Delete(UserDetails);
						
						If Not Common.DataSeparationEnabled() Then
							// Checking a blank list of infobase users in the Administrators access group.
							ErrorDescription = "";
							AccessManagementInternal.CheckAdministratorsAccessGroupForIBUser(
								AccessGroupObject.Users, ErrorDescription);
							
							If ValueIsFilled(ErrorDescription) Then
								CancelOnWriteChanges = True;
								Cancel = True;
								Raise
									NStr("en = 'At least one user authorized to log in
									           |must have the Administrator profile.';");
							EndIf;
						EndIf;
					EndIf;
				EndIf;
			Else
				AccessGroupObject.Users.Clear();
				If Update.Check Then
					AccessGroupObject.Users.Add().User = Parameters.User;
				EndIf;
				
				Filter = New Structure("AccessGroup", Update.Profile);
				AccessGroupObject.AccessKinds.Load(AccessKinds.Unload(Filter, "AccessKind, AllAllowed"));
				AccessGroupObject.AccessValues.Load(AccessValues.Unload(Filter, "AccessKind, AccessValue, IncludeSubordinateAccessValues"));
			EndIf;
			
			AccessGroupObject.Write();
			
		EndDo;
		
		For Each Update In AccessGroupsChanges Do
			If ValueIsFilled(Update.PersonalAccessGroup) Then
				UnlockDataForEdit(Update.PersonalAccessGroup);
			EndIf;	
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		For Each Update In AccessGroupsChanges Do
			If ValueIsFilled(Update.PersonalAccessGroup) Then
				UnlockDataForEdit(Update.PersonalAccessGroup);
			EndIf;	
		EndDo;
		ServiceUserPassword = Undefined;
		Raise;
	EndTry;
	
	Modified = False;
	SynchronizationWithServiceRequired = False;
	
	AccessManagementInternal.StartAccessUpdate();
	
EndProcedure

&AtClient
Procedure IdleHandlerProfilesOnActivateRow()
	
	OnChangeCurrentProfile(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure OnChangeCurrentProfile(Val Form, Val ProcessingAtClient = True)
	
	Items    = Form.Items;
	Profiles     = Form.Profiles;
	AccessKinds = Form.AccessKinds;
	
	If ProcessingAtClient Then
		CurrentData = Items.Profiles.CurrentData;
	Else
		CurrentData = Profiles.FindByID(
			?(Items.Profiles.CurrentRow = Undefined, -1, Items.Profiles.CurrentRow));
	EndIf;
	
	CurrentRestrictionsAvailabilityPrevious    = Form.CurrentRestrictionsAvailability;
	EditCurrentRestrictionsPrevious = Form.EditCurrentRestrictions;
	
	If CurrentData = Undefined Then
		Form.CurrentProfile = Undefined;
		Form.CurrentRestrictionsAvailability = False;
		Form.EditCurrentRestrictions = False;
	Else
		Form.CurrentProfile = CurrentData.Profile;
		Form.CurrentRestrictionsAvailability    = CurrentData.Check;
		Form.EditCurrentRestrictions = CurrentData.Check
			And Form.CurrentProfile <> Form.ProfileAdministrator
			And Not Form.ReadOnly;
	EndIf;
	
	CurrentRestrictionsDisplayUpdateRequired =
		    CurrentRestrictionsAvailabilityPrevious    <> Form.CurrentRestrictionsAvailability
		Or EditCurrentRestrictionsPrevious <> Form.EditCurrentRestrictions;
	
	If Form.CurrentProfile = Undefined Then
		Form.CurrentAccessGroup = "";
	Else
		Form.CurrentAccessGroup = Form.CurrentProfile;
	EndIf;
	
	If Items.AccessKinds.RowFilter = Undefined
	 Or Items.AccessKinds.RowFilter.AccessGroup <> Form.CurrentAccessGroup Then
		
		If Items.AccessKinds.RowFilter = Undefined Then
			RowFilter = New Structure;
		Else
			RowFilter = New Structure(Items.AccessKinds.RowFilter);
		EndIf;
		RowFilter.Insert("AccessGroup", Form.CurrentAccessGroup);
		Items.AccessKinds.RowFilter = New FixedStructure(RowFilter);
		CurrentAccessKinds = AccessKinds.FindRows(New Structure("AccessGroup", Form.CurrentAccessGroup));
		If CurrentAccessKinds.Count() = 0 Then
			Items.AccessValues.RowFilter = New FixedStructure("AccessGroup, AccessKind", Form.CurrentAccessGroup, "");
			AccessManagementInternalClientServer.OnChangeCurrentAccessKind(Form, ProcessingAtClient);
		Else
			Items.AccessKinds.CurrentRow = CurrentAccessKinds[0].GetID();
		EndIf;
	EndIf;
	
	If CurrentRestrictionsDisplayUpdateRequired Then
		If ProcessingAtClient Then
			Form.AttachIdleHandler("UpdateCurrentRestrictionsDisplayIdleHandler", 0.1, True);
		Else
			UpdateCurrentRestrictionsDisplay(Form);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateCurrentRestrictionsDisplayIdleHandler()
	
	UpdateCurrentRestrictionsDisplay(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateCurrentRestrictionsDisplay(Form)
	
	Items = Form.Items;
	
	Items.Access.Enabled                             =    Form.CurrentRestrictionsAvailability;
	Items.AccessKinds.ReadOnly                     = Not Form.EditCurrentRestrictions;
	Items.AccessValuesByAccessKind.Enabled       =    Form.CurrentRestrictionsAvailability;
	Items.AccessValues.ReadOnly                 = Not Form.EditCurrentRestrictions;
	Items.AccessKindsContextMenuChange.Enabled =    Form.EditCurrentRestrictions;
	
EndProcedure

#EndRegion
