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
Var WriteParametersOnFirstAdministratorCheck;

&AtClient
Var ShouldSkipDescriptionOnChange, ShouldSkipDescriptionAutoComplete;

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
	
	CommonSettingShowInList =
		UsersInternal.LogonSettings().Overall.ShowInList;
	
	If Common.DataSeparationEnabled() Then
		DataSeparationEnabled = True;
		CanChangeUsers = True;
		If Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
			ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
			CanChangeUsers = ModuleUsersInternalSaaS.CanChangeUsers();
		EndIf;
		
		If Not CanChangeUsers Then
			If Object.Ref.IsEmpty() Then
				Raise NStr("en = 'The demo does not support creating new user accounts.';");
			EndIf;
			ReadOnly = True;
		EndIf;
		
		If ValueIsFilled(Object.Ref)
		   And ValueIsFilled(Object.ServiceUserID)
		   And Object.Ref <> Users.AuthorizedUser() Then
			Items.Indent.Visible = False;
			Items.PasswordExistsLabel.Visible = False;
			Items.ChangePassword.Visible = False;
		EndIf;
		Items.IBUserOpenIDAuthentication.Visible = False;
		Items.InfobaseUserAuthWithOpenIDConnect.Visible = False;
		Items.InfobaseUserAuthWithAccessToken.Visible = False;
		Items.IBUserStandardAuthentication.Visible = False;
		Items.UserMustChangePasswordOnAuthorization.Visible = False;
		Items.IBUserCannotChangePassword.Visible = False;
		Items.IBUserCannotRecoveryPassword.Visible = False;
		Items.OSAuthenticationProperties.Visible  = False;
		Items.IBUserRunMode.Visible = False;
	EndIf;
	
	If StandardSubsystemsServer.IsTrainingPlatform() Then
		Items.OSAuthenticationProperties.ReadOnly = True;
	EndIf;
	
	// Filling auxiliary data.
	
	// Filling the run mode selection list.
	For Each RunMode In ClientRunMode Do
		ValueFullName = GetPredefinedValueFullName(RunMode);
		EnumValueName = Mid(ValueFullName, StrFind(ValueFullName, ".") + 1);
		Items.IBUserRunMode.ChoiceList.Add(EnumValueName, String(RunMode));
	EndDo;
	Items.IBUserRunMode.ChoiceList.SortByPresentation();
	
	// Filling the language selection list.
	If Metadata.Languages.Count() < 2 Then
		Items.IBUserLanguage.Visible = False;
	Else
		For Each LanguageMetadata In Metadata.Languages Do
			Items.IBUserLanguage.ChoiceList.Add(
				LanguageMetadata.Name, LanguageMetadata.Synonym);
		EndDo;
	EndIf;
	
	AccessLevel = UsersInternal.UserPropertiesAccessLevel(Object);
	
	// Preparing for execution of interactive actions according to the form opening scenarios.
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(Object.Ref) Then
		// Creating an item.
		If Parameters.NewUserGroup <> Users.AllUsersGroup() Then
			NewUserGroup = Parameters.NewUserGroup;
		EndIf;
		
		If ValueIsFilled(Parameters.CopyingValue) Then
			// Copy item.
			CopyingValue = Parameters.CopyingValue;
			Object.Description = "";
			SourceIBUserID = Common.ObjectAttributeValue(
				CopyingValue, "IBUserID");
			
			If Not UsersInternal.UserAccessLevelAbove(CopyingValue, AccessLevel) Then
				ReadIBUser(ValueIsFilled(SourceIBUserID));
			Else
				ReadIBUser();
			EndIf;
			
			If Not AccessLevel.ChangeAuthorizationPermission Then
				CanSignIn = False;
				CanSignInDirectChangeValue = False;
			EndIf;
			
			IBUserEmailAddress = "";
		Else
			// Add item.
			
			// Reading initial infobase user property values.
			ReadIBUser();
			
			If Not ValueIsFilled(Parameters.IBUserID) Then
				IBUserStandardAuthentication = True;
				
				If Common.DataSeparationEnabled() Then
					IBUserShowInList = False;
					IBUserOpenIDAuthentication = True;
				EndIf;
				
				If AccessLevel.ChangeAuthorizationPermission Then
					CanSignIn = True;
					CanSignInDirectChangeValue = True;
				EndIf;
			EndIf;
		EndIf;
	Else
		// Open an existing item.
		ReadIBUser();
	EndIf;
	
	SetPrivilegedMode(False);
	
	ProcessRolesInterface("SetUpRoleInterfaceOnFormCreate", IBUserExists);
	InitialIBUserDetails = InitialIBUserDetails();
	SynchronizationWithServiceRequired = Object.Ref.IsEmpty();
	
	PasswordToConfirmEmailChange = Undefined;
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		
		ExcludedKinds = New Array;
		ExcludedKinds.Add(ContactInformationKind("UserPhone"));
		ExcludedKinds.Add(ContactInformationKind("UserEmail"));
		
		AdditionalParameters = ModuleContactsManager.ContactInformationParameters();
		AdditionalParameters.ItemForPlacementName = "ContactInformation";
		AdditionalParameters.ExcludedKinds = ExcludedKinds;
		
		ModuleContactsManager.OnCreateAtServer(ThisObject, Object, AdditionalParameters);
		
		If UsersInternal.PasswordRecoverySettingsAreAvailable(AccessLevel) Then
			
			If Not UsersInternal.InteractivelyPromptForAPassword(AccessLevel, Object) Then
				PasswordToConfirmEmailChange = "";
			EndIf;
			
			AttributeWithEmailForPasswordRecoveryName = ModuleContactsManager.DefineAnItemWithMailForPasswordRecovery(
				ThisObject,
				IBUserEmailAddress,
				UsersInternal.YouCanEditYourEmailToRestoreYourPassword(AccessLevel, Object));
			
		EndIf;
		
		OverrideContactInformationEditingSaaS();
	Else
		Items.GroupContactInformationFieldUserEmail.Visible = False;
		Items.GroupContactInformationFieldUserPhone.Visible = False;
	EndIf;
	
	CustomizeForm(Object, True);
	
	If Common.IsStandaloneWorkplace() Then
		Items.HeaderGroup.ReadOnly = True;
		Items.ContactInformation.ReadOnly = True;
		Items.AdditionalAttributesPage.ReadOnly = True;
		Items.CommentPage.ReadOnly = True;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation")
		And ActionsWithSaaSUser <> Undefined Then
			ModuleContactsManager = Common.CommonModule("ContactsManager");
			ModuleContactsManager.SetContactInformationItemAvailability(ThisObject,
				DetermineContactInformationItemsAvailability());
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesPage");
		AdditionalParameters.Insert("DeferredInitialization", True);
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	
	PrepareOptionalAttribute("Individual", Users.IndividualUsed());
	PrepareOptionalAttribute("Department", Users.IsDepartmentUsed());
	
	RefreshShowInChoiceListAttributeVisibility();
	
	If Common.DataSeparationEnabled()
		Or Not Users.CommonAuthorizationSettingsUsed() Then
		Items.ChangeRestrictionGroup.Visible = False;
	EndIf;
	
	Items.UserMustChangePasswordOnAuthorization.ExtendedTooltip.Title =
		UsersInternal.HintUserMustChangePasswordOnAuthorization(False);
	
	If Common.IsMobileClient() Then
		Items.FormWriteAndClose.Representation = ButtonRepresentation.Picture;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Conversations") Then
		ModuleConversationsInternal = Common.CommonModule("ConversationsInternal");
		ModuleConversationsInternal.OnCreateAtUserServer(Cancel, ThisObject, Object);
	EndIf;
	
	If Not ValueIsFilled(PhotoAddress) Then
		PhotoAddress = PutToTempStorage(PictureLib.UserWithoutPhoto, UUID);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
#If WebClient Then
	Items.IBUserOSUser.ChoiceButton = False;
#EndIf
	
	UpdateShowInListProperty();
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
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
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		If ModulePropertyManagerClient.ProcessNotifications(ThisObject, EventName, Parameter) Then
			UpdateAdditionalAttributesItems();
			ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
		EndIf;
	EndIf;
	
	If Upper(EventName) = Upper("Write_ConstantsSet") Then
		If Upper(Source) = Upper("UseExternalUsers") Then
			AttachIdleHandler("ExternalUsersUsageOnChange", 0.1, True);
		EndIf;
		If Upper(Source) = Upper("UserAuthorizationSettings") Then
			AttachIdleHandler("OnChangingUserAuthorizationSettings", 0.1, True);
		EndIf;
	EndIf;
	
	If Upper(EventName) = Upper("Write_AccessGroups") Then
		AttachIdleHandler("OnChangeAccessGroups", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ModuleContactsManager.OnReadAtServer(ThisObject, CurrentObject, "ContactInformation");
		
		If TypeOf(AccessLevel) = Type("Structure") And UsersInternal.PasswordRecoverySettingsAreAvailable(AccessLevel) Then
			AttributeWithEmailForPasswordRecoveryName = ModuleContactsManager.DefineAnItemWithMailForPasswordRecovery(
				ThisObject,
				IBUserEmailAddress,
				UsersInternal.YouCanEditYourEmailToRestoreYourPassword(AccessLevel, CurrentObject));
		EndIf;
		
	EndIf;
	
	CustomizeForm(CurrentObject);
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = Common.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	EndIf;
	// End StandardSubsystems.AttachableCommands

	Photo = CurrentObject.Photo.Get();
	If Photo <> Undefined Then
		PhotoAddress = PutToTempStorage(Photo, UUID);
		PhotoSpecified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	ClearMessages();
	
	If CommonClient.SubsystemExists("StandardSubsystems.ContactInformation") Then
		If ValueIsFilled(AttributeWithEmailForPasswordRecoveryName)
			And IBUserEmailAddress <> ThisObject[AttributeWithEmailForPasswordRecoveryName] Then
			If PasswordToConfirmEmailChange = Undefined Then
				Cancel = True;
				AdditionalParameters = New Structure("WriteParameters", WriteParameters);
				Notification = New NotifyDescription("AfterRequestingAPasswordToChangeTheMail", ThisObject, AdditionalParameters);
				OpenForm("Catalog.Users.Form.PasswordInput",, ThisObject,,,, Notification, FormWindowOpeningMode.LockOwnerWindow);
				Return;
			EndIf;
		EndIf;
	EndIf;
	
	QuestionTitle1 = NStr("en = 'Save infobase user';");
	
	// Copy user rights.
	If ValueIsFilled(CopyingValue)
	   And Not ValueIsFilled(Object.Ref)
	   And CommonClient.SubsystemExists("StandardSubsystems.AccessManagement")
	   And (Not WriteParameters.Property("NotCopyUserRights")
	      And Not WriteParameters.Property("CopyUserRights")) Then
		
		Cancel = True;
		ShowQueryBox(
			New NotifyDescription("AfterAnswerToQuestionAboutCopyingRights", ThisObject, WriteParameters),
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Do you want to copy the rights of the user ""%1""?';"), String(CopyingValue)),
			QuestionDialogMode.YesNo,
			,
			,
			QuestionTitle1);
		Return;
	EndIf;
	
	If Not WriteParameters.Property("WithEmptyRoleList")
	   And CanSignIn
	   And ActionsOnForm.Roles = "Edit"
	   And IBUserRoles.Count() = 0 Then
	
		Cancel = True;
		ShowQueryBox(
			New NotifyDescription("AfterAnswerToQuestionAboutWritingWithEmptyRoleList", ThisObject, WriteParameters),
			NStr("en = 'No roles are assigned to the infobase user. Do you want to continue?';"),
			QuestionDialogMode.YesNo,
			,
			,
			QuestionTitle1);
		Return;
	EndIf;
	
	If Not WriteParameters.Property("WithFirstAdministratorAdding")
	   And ValueIsFilled(IBUserName)
	   And InfobaseUsersListIsBlank() Then
		
		Cancel = True;
		WriteParametersOnFirstAdministratorCheck = WriteParameters;
		AttachIdleHandler("CheckFirstAdministrator", 0.1, True);
		Return;
	EndIf;
	
	// Password request should be the last step to ensure the try/except statement works properly.
	If CommonClient.DataSeparationEnabled()
		And SynchronizationWithServiceRequired
		And Not WriteParameters.Property("AfterAuthenticationPasswordRequestInService") Then
		
		WriteParameters.Insert("AfterAuthenticationPasswordRequestInService");
		Cancel = True;
		UsersInternalClient.RequestPasswordForAuthenticationInService(
			New NotifyDescription("AfterAuthenticationPasswordRequestInServiceBeforeWrite", ThisObject, WriteParameters),
			ThisObject,
			ServiceUserPassword);
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.AdditionalProperties.Insert("CopyingValue", CopyingValue);
	CurrentObject.AdditionalProperties.Insert("IsRecoveryEmailSetOnForm");
	
	CurrentObject.AdditionalProperties.Insert("ServiceUserPassword", ServiceUserPassword);
	CurrentObject.AdditionalProperties.Insert("SynchronizeWithService", SynchronizationWithServiceRequired);
	
	If IBUserWritingRequired(ThisObject) Then
		
		If UsersInternal.PasswordRecoverySettingsAreAvailable(AccessLevel) Then
			
			If IBUserCannotChangePassword Then
				IBUserCannotRecoveryPassword = True;
			EndIf;
			
			If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
				
				If UsersInternal.YouCanEditYourEmailToRestoreYourPassword(AccessLevel, Object) Then
					
					If ValueIsFilled(AttributeWithEmailForPasswordRecoveryName)
						And IBUserEmailAddress <> ThisObject[AttributeWithEmailForPasswordRecoveryName] Then
						
						If ValueIsFilled(CurrentObject.Ref) Then
							Prepared = Common.ObjectAttributeValue(CurrentObject.Ref, "Prepared");
						Else
							Prepared = AccessLevel.ListManagement;
						EndIf;
						
						ChangeEmailWithoutPasswordConfirmation = Users.IsFullUser() Or Prepared;
						
						If Not ChangeEmailWithoutPasswordConfirmation Then
							
							ThePasswordIsTheSameAsTheSavedOne = False;
							
							If TypeOf(PasswordToConfirmEmailChange) = Type("String") Then
								SetPrivilegedMode(True);
								ThePasswordIsTheSameAsTheSavedOne = UsersInternal.PreviousPasswordMatchSaved(
									PasswordToConfirmEmailChange, Object.IBUserID);
								SetPrivilegedMode(False);
							EndIf;
							
							// Password check.
							If Not ThePasswordIsTheSameAsTheSavedOne Then
								PasswordToConfirmEmailChange = Undefined;
								Raise NStr("en = 'Password is incorrect';");
							EndIf;
							
						EndIf;
						
						IBUserEmailAddress = ThisObject[AttributeWithEmailForPasswordRecoveryName];
						
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
		IBUserDetails = IBUserDetails();
		
		If ValueIsFilled(Object.IBUserID) Then
			IBUserDetails.Insert("UUID", Object.IBUserID);
		EndIf;
		IBUserDetails.Insert("Action", "Write");
		
		CurrentObject.AdditionalProperties.Insert("IBUserDetails", IBUserDetails);
		
		If WriteParameters.Property("WithFirstAdministratorAdding") Then
			CurrentObject.AdditionalProperties.Insert("CreateAdministrator",
				NStr("en = 'The first infobase user is granted administrator rights.';"));
		EndIf;
	EndIf;
	
	If ActionsOnForm.ItemProperties <> "Edit" Then
		FillPropertyValues(CurrentObject, Common.ObjectAttributesValues(
			CurrentObject.Ref, "Description, DeletionMark"));
	EndIf;
	
	InformationRegisters.UsersInfo.ObtainUserInfo(ThisObject, CurrentObject);
	
	CurrentObject.AdditionalProperties.Insert("NewUserGroup", NewUserGroup);
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		If Not Cancel And ActionsOnForm.ContactInformation = "Edit" Then
			ModuleContactsManager.BeforeWriteAtServer(ThisObject, CurrentObject);
		EndIf;
	EndIf;
	
	If PhotoSpecified And IsTempStorageURL(PhotoAddress) Then
		CurrentObject.Photo = New ValueStorage(GetFromTempStorage(PhotoAddress));
	Else 
		CurrentObject.Photo = New ValueStorage(Undefined);
	EndIf;
		
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.Property("CopyUserRights") Then
		Source = CopyingValue;
		Receiver = CurrentObject.Ref;
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnCopyRightsToNewUser(Source, Receiver);
		UsersInternal.CopyUserGroups(Source, Receiver);
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SynchronizationWithServiceRequired = False;
	
	If IBUserWritingRequired(ThisObject) Then
		WriteParameters.Insert(
			CurrentObject.AdditionalProperties.IBUserDetails.ActionResult);
	EndIf;
	
	If WriteParameters.Property("WithFirstAdministratorAdding") Then
		UsersInternal.CopyUserSettings("", IBUserName);
	EndIf;
	
	CustomizeForm(CurrentObject, , WriteParameters);
	
	UpdateEmailChangeMethodSaaS();
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Conversations") Then
		ModuleConversations = Common.CommonModule("Conversations");
		ModuleConversations.UpdateUserInCollaborationSystem(CurrentObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	Notify("Write_Users", New Structure, Object.Ref);
	
	If WriteParameters.Property("IBUserAdded") Then
		Notify("IBUserAdded", WriteParameters.IBUserAdded, ThisObject);
		
	ElsIf WriteParameters.Property("IBUserChanged") Then
		Notify("IBUserChanged", WriteParameters.IBUserChanged, ThisObject);
		
	ElsIf WriteParameters.Property("IBUserDeleted") Then
		Notify("IBUserDeleted", WriteParameters.IBUserDeleted, ThisObject);
		
	ElsIf WriteParameters.Property("MappingToNonExistingIBUserCleared") Then
		Notify(
			"MappingToNonExistingIBUserCleared",
			WriteParameters.MappingToNonExistingIBUserCleared,
			ThisObject);
	EndIf;
	
	If ValueIsFilled(NewUserGroup) Then
		NotifyChanged(NewUserGroup);
		Notify("Write_UserGroups", New Structure, NewUserGroup);
		NewUserGroup = Undefined;
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.Conversations") Then
		CompletionDetails = New NotifyDescription("AfterWriteCompletion", ThisObject, WriteParameters);
		ModuleConversationsInternalClient = CommonClient.CommonModule("ConversationsInternalClient");
		ModuleConversationsInternalClient.AfterWriteUser(ThisObject, CompletionDetails);
		Return;
	EndIf;
	
	PasswordToConfirmEmailChange = Undefined;
	
	AfterWriteCompletion(Undefined, WriteParameters);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If IBUserWritingRequired(ThisObject) Then
		IBUserDetails = IBUserDetails();
		IBUserDetails.Insert("IBUserID", Object.IBUserID);
		
		If ValueIsFilled(AttributeWithEmailForPasswordRecoveryName) Then
			IBUserDetails.Email = ThisObject[AttributeWithEmailForPasswordRecoveryName];
		EndIf;
		
		UsersInternal.CheckIBUserDetails(IBUserDetails, Cancel, False);
		
	EndIf;
	
	If CanSignIn
	   And ValueIsFilled(ValidityPeriod)
	   And ValidityPeriod <= BegOfDay(CurrentSessionDate()) Then
		
		Common.MessageToUser(
			NStr("en = 'The expiration date must be tomorrow or later.';"),, "CanSignIn",, Cancel);
	EndIf;
	
	// Checking whether the metadata contains roles.
	If Not Items.Roles.ReadOnly Then
		Errors = Undefined;
		TreeItems = Roles.GetItems();
		For Each Item In TreeItems Do
			If Not Item.Check Then
				Continue;
			EndIf;
			If Item.IsNonExistingRole Then
				CommonClientServer.AddUserError(Errors,
					"Roles[%1].RolesSynonym",
					StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Role ""%1"" does not exist.';"), Item.Synonym),
					"Roles",
					TreeItems.IndexOf(Item),
					StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Non-existent role ""%1"" in line %2.';"), Item.Synonym, "%1"));
			EndIf;
			If Item.IsUnavailableRole Then
				CommonClientServer.AddUserError(Errors,
					"Roles[%1].RolesSynonym",
					StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Role ""%1"" is unavailable to users.';"), Item.Synonym),
					"Roles",
					TreeItems.IndexOf(Item),
					StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Role ""%1"" in line %2 is unavailable to users.';"), Item.Synonym, "%1"));
			EndIf;
		EndDo;
		CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ModuleContactsManager.FillCheckProcessingAtServer(ThisObject, Object, Cancel);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("SetUpRoleInterfaceOnLoadSettings", Settings);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FillFromIBUser(Command)
	
	If AccessLevel.ListManagement
	   And ActionsOnForm.ItemProperties = "Edit" Then
		
		If CanSignInOnRead And Object.Invalid Then
			Object.Invalid = False;
			InvalidOnChange(Items.Invalid);
		EndIf;
	EndIf;
	
	FillFieldsByIBUserAtServer();
	
EndProcedure

&AtClient
Procedure DescriptionOnChange(Item)
	
	If ShouldSkipDescriptionOnChange = True Then
		Return;
	EndIf;
	
	UpdateUsername(ThisObject, True);
	
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
EndProcedure

&AtClient
Procedure DescriptionAutoComplete(Item, Text, ChoiceData,
			DataGetParameters, Waiting, StandardProcessing)
	
	If Not ValueIsFilled(Text)
	 Or Not CommonClient.SubsystemExists("OnlineUserSupport.PickName")
	 Or ShouldSkipDescriptionAutoComplete = True Then
		ShouldSkipDescriptionAutoComplete = False;
		Return;
	EndIf;
	ModuleNameHintClient = CommonClient.CommonModule("PickNameClient");
	
	FullNameData = New Structure("Presentation", Text);
	ClassifierData = ModuleNameHintClient.Pick("LASTFIRSTNAME", FullNameData);
	
	If ClassifierData.Count() > 0 Then
		StandardProcessing = False;
		ChoiceData = New ValueList;
		ChoiceData.LoadValues(ClassifierData);
	EndIf;
	
EndProcedure

&AtClient
Procedure DescriptionChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	ShouldSkipDescriptionOnChange = True;
	
	DataOfDescription = StrSplit(ValueSelected, " ", False);
	Items.Description.UpdateEditText();
	If DataOfDescription.Count() < 3 Then
		NewValue = ValueSelected + " ";
	Else
		NewValue = ValueSelected;
		ShouldSkipDescriptionAutoComplete = True;
	EndIf;
	Items.Description.SelectedText = NewValue;
	If Object.Description <> NewValue Then
		Object.Description = ValueSelected;
	EndIf;
	
	ShouldSkipDescriptionOnChange = False;
	
EndProcedure

&AtClient
Procedure InvalidOnChange(Item)
	
	If DataSeparationEnabled
	   And Not Object.Invalid Then
		CanSignInDirectChangeValue = True;
	EndIf;
	
	If Object.Invalid Then
		CanSignIn = False;
		If Not IBUserOpenIDAuthentication
		   And Not InfobaseUserAuthWithOpenIDConnect
		   And Not InfobaseUserAuthWithAccessToken
		   And Not IBUserOSAuthentication
		   And Not IBUserStandardAuthenticationDirectChangeValue
		   And IBUserStandardAuthentication Then
			
			IBUserStandardAuthentication = False;
		EndIf;
	ElsIf CanSignInDirectChangeValue Then
		If Not IBUserStandardAuthentication
		   And Not IBUserOpenIDAuthentication
		   And Not InfobaseUserAuthWithOpenIDConnect
		   And Not InfobaseUserAuthWithAccessToken
		   And Not IBUserOSAuthentication Then
			IBUserStandardAuthentication = True;
		EndIf;
		CanSignIn = True;
	EndIf;
	
	UpdateShowInListProperty();
	
	SetPropertiesAvailability(ThisObject);
	
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
EndProcedure

&AtClient
Procedure CanSignInOnChange(Item)
	
	If DataSeparationEnabled
	   And Not CanSignIn Then
		
		CanSignIn = True;
		Object.Invalid = True;
		InvalidOnChange(Items.Invalid);
		Return;
	EndIf;
	
	If Object.DeletionMark And CanSignIn Then
		CanSignIn = False;
		ShowMessageBox(,
			NStr("en = 'To allow logging in to the application, clear the deletion mark from the user.';"));
		Return;
	EndIf;
	
	If Not CanSignIn
	   And Not IBUserOpenIDAuthentication
	   And Not InfobaseUserAuthWithOpenIDConnect
	   And Not InfobaseUserAuthWithAccessToken
	   And Not IBUserOSAuthentication
	   And Not IBUserStandardAuthenticationDirectChangeValue
	   And IBUserStandardAuthentication Then
		
		IBUserStandardAuthentication = False;
	EndIf;
	
	UpdateUsername(ThisObject);
	
	If CanSignIn
	   And Not IBUserOpenIDAuthentication
	   And Not InfobaseUserAuthWithOpenIDConnect
	   And Not InfobaseUserAuthWithAccessToken
	   And Not IBUserOSAuthentication
	   And Not IBUserStandardAuthentication Then
	
		IBUserStandardAuthentication = True;
	EndIf;
	
	UpdateShowInListProperty();
	
	SetPropertiesAvailability(ThisObject);
	
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
	If Not AccessLevel.ChangeAuthorizationPermission
	   And Not CanSignIn Then
		
		ShowMessageBox(,
			NStr("en = 'Once you save the changes, only the administrator can allow login to the application.';"));
	EndIf;
	
	CanSignInDirectChangeValue = CanSignIn;
	
EndProcedure

&AtClient
Procedure ChangeAuthorizationRestriction(Command)
	
	OpenForm("Catalog.Users.Form.AuthorizationRestriction",, ThisObject,,,,
		New NotifyDescription("ChangeAuthorizationRestrictionCompletion", ThisObject));
	
EndProcedure

&AtClient
Procedure IBUserNameOnChange(Item)
	
	IBUserName = TrimAll(IBUserName);
	IBUserNameDirectChangeValue = IBUserName;
	
	SetPropertiesAvailability(ThisObject);
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserStandardAuthenticationOnChange(Item)
	
	AuthenticationOnChange();
	IBUserStandardAuthenticationDirectChangeValue = IBUserStandardAuthentication;
	
EndProcedure

&AtClient
Procedure UserMustChangePasswordOnAuthorizationOnChange(Item)
	
	If UserMustChangePasswordOnAuthorization Then
		IBUserCannotChangePassword = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure IBUserShowInListOnChange(Item)
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserCannotChangePasswordOnChange(Item)
	
	If IBUserCannotChangePassword Then
		UserMustChangePasswordOnAuthorization               = False;
		IBUserCannotRecoveryPassword = True;
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserOpenIDAuthenticationOnChange(Item)
	
	AuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure InfobaseUserAuthWithOpenIDConnectOnChange(Item)
	
	AuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure InfobaseUserAuthWithAccessTokenOnChange(Item)
	
	AuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure IBUserOSAuthenticationOnChange(Item)
	
	AuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure IBUserOSUserOnChange(Item)
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserOSUserStartChoice(Item, ChoiceData, StandardProcessing)
	
#If Not WebClient And Not MobileClient Then
		OpenForm("Catalog.Users.Form.SelectOperatingSystemUser", , Item);
#EndIf
	
EndProcedure

&AtClient
Procedure IBUserLanguageOnChange(Item)
	
	SetPropertiesAvailability(ThisObject);
	
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserRunModeOnChange(Item)
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserRunModeClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties")
		And CurrentPage.Name = "AdditionalAttributesPage"
		And Not PropertiesParameters.DeferredInitializationExecuted Then
		
		PropertiesExecuteDeferredInitialization();
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure UserMustChangePasswordOnAuthorizationExtendedTooltipURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	OpenForm("CommonForm.UserAuthorizationSettings", , ThisObject);
EndProcedure

&AtClient
Procedure PhotoClick(Item, StandardProcessing)
	StandardProcessing = False;
	CompletionNotification1 = New NotifyDescription("PhotoClickCompletion", ThisObject);
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.FormIdentifier = UUID;
	ImportParameters.Dialog.Filter = NStr("en = 'Pictures';") + "|*.JPG;*.JPEG;*.JP2;*.JPG2;*.PNG;*.BMP;*.TIFF";
	FileSystemClient.ImportFile_(CompletionNotification1, ImportParameters);
EndProcedure

&AtClient
Procedure PhotoClickCompletion(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
#If Not WebClient Then
		Picture = New Picture(GetFromTempStorage(Result.Location));
		If Picture.Format() = PictureFormat.UnknownFormat Then
			ShowMessageBox(, NStr("en = 'Select a file with a picture.';"));
			Return;
		EndIf;
		
		If Picture.FileSize() > 2 * 1024 * 1024 Then
			ShowMessageBox(, NStr("en = 'The picture size must be less than 2 MB.';"));
			Return;
		EndIf;
#EndIf
	
	If IsTempStorageURL(PhotoAddress) Then
		DeleteFromTempStorage(PhotoAddress);
	EndIf;
	
	PhotoAddress = Result.Location;
	Modified = True;
	PhotoSpecified = True;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Provide contact information support.

&AtClient
Procedure Attachable_EMailOnChange(Item)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
		
	ModuleContactsManagerClient.StartChanging(ThisObject, Item);
	
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
	If Not Object.Ref.IsEmpty() Then
		Return;
	EndIf;
	
	CITable = ContactInformationAdditionalAttributesDetails;
	
	EmailRow = CITable.FindRows(New Structure("Kind",
		ContactInformationKindUserEmail()))[0];
	
	If ValueIsFilled(ThisObject[EmailRow.AttributeName]) Then
		IBUserPassword = "" + New UUID + "qQ";
		CheckPasswordSet(ThisObject, True, UsersClient.AuthorizedUser());
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

// An attachable clearing handler.
//
// Parameters:
//  Item - FormField
//  StandardProcessing - Boolean
//
&AtClient
Procedure Attachable_EMailClearing(Item, StandardProcessing)
	
	If Not Item.TextEdit Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	
	ModuleContactsManagerClient.StartClearing(ThisObject, Item.Name);
	
EndProcedure

&AtClient
Procedure Attachable_PhoneOnChange(Item)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	
	ModuleContactsManagerClient.StartChanging(ThisObject, Item);
	
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_EMailStartChoice(Item)
	
	If Not ValueIsFilled(Object.Ref) Then
		Return;
	EndIf;
	
	CITable = ContactInformationAdditionalAttributesDetails;
	
	Filter = New Structure("Kind", ContactInformationKindUserEmail());
	
	EmailRow = CITable.FindRows(Filter)[0];
	
	FormParameters = New Structure;
	FormParameters.Insert("OldEmail",  ThisObject[EmailRow.AttributeName]);
	
	OpenForm("Catalog.Users.Form.EmailAddressChange", FormParameters, ThisObject,,,,
		New NotifyDescription("AfterSelectNewEmail", ThisObject));
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.StartChanging(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.StartSelection(ThisObject, Item,, StandardProcessing);
	
EndProcedure

// A attachable click handler.
//
// Parameters:
//  Item - FormDecoration
//          - FormDecorationExtensionForALabel
//  StandardProcessing - Boolean
//
&AtClient
Procedure Attachable_ContactInformationOnClick(Item, StandardProcessing)
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.StartSelection(ThisObject, Item,, StandardProcessing);
EndProcedure

// An attachable clearing handler.
//
// Parameters:
//  Item - FormField
//  StandardProcessing - Boolean
//
&AtClient
Procedure Attachable_ContactInformationClearing(Item, StandardProcessing)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.StartClearing(ThisObject, Item.Name);
	
EndProcedure

// A attachable command handler.
// 
// Parameters:
//  Command - FormCommand
//
&AtClient
Procedure Attachable_ContactInformationExecuteCommand(Command)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.StartCommandExecution(ThisObject, Command.Name);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.AutoCompleteAddress(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing);
	
EndProcedure

// An attachable choice handler.
//
// Parameters:
//  Item - FormField
//  ValueSelected - String
//  StandardProcessing - Boolean
//
&AtClient
Procedure Attachable_ContactInformationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.ChoiceProcessing(ThisObject, ValueSelected, Item.Name, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_ContinueContactInformationUpdate(Result, AdditionalParameters) Export
	UpdateContactInformation(Result);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersRoles

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtClient
Procedure RolesCheckOnChange(Item)
	
	TableRow = Items.Roles.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	If TableRow.Check And TableRow.Name = "InteractiveOpenExtReportsAndDataProcessors" Then
		Notification = New NotifyDescription("RolesMarkOnChangeAfterConfirm", ThisObject);
		UsersInternalClient.ShowSecurityWarning(Notification,
			UsersInternalClientServer.SecurityWarningKinds().BeforeSelectRole);
	Else
		If TableRow.Name = "FullAccess" Then
			DetermineNecessityForSynchronizationWithService(ThisObject);
		EndIf;
		ProcessRolesInterface("UpdateRoleComposition");
	EndIf;
	
EndProcedure

&AtClient
Procedure RolesMarkOnChangeAfterConfirm(Response, ExecutionParameters) Export
	TableRow = Items.Roles.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	If Response = "Continue" Then
		ProcessRolesInterface("UpdateRoleComposition");
	Else
		TableRow.Check = False;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	Write(New Structure("WriteAndClose"));
	
EndProcedure

&AtClient
Procedure ChangePassword(Command)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ReturnPasswordAndDoNotSet", True);
	AdditionalParameters.Insert("PreviousPassword", IBUserPreviousPassword);
	AdditionalParameters.Insert("LoginName",  IBUserName);
	
	UsersInternalClient.OpenChangePasswordForm(Object.Ref, New NotifyDescription(
		"ChangePasswordAfterGetPassword", ThisObject), AdditionalParameters);
	
EndProcedure

&AtClient
Procedure SelectPhoto(Command)
	PhotoClick(Items.Photo, False);
EndProcedure

&AtClient
Procedure ClearPhoto(Command)
	PhotoAddress = PutToTempStorage(PictureLib.UserWithoutPhoto, UUID);
	PhotoSpecified = False;
	Modified = True;
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

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, Var_URL = Undefined, StandardProcessing = Undefined)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RolesCheck.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Roles.Name");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Metadata.Roles.FullAccess.Name;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("AdministrativeAccessChangeProhibition");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Enabled", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RolesCheck.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RolesSynonym.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Roles.Name");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Metadata.Roles.FullAccess.Name;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("AdministrativeAccessChangeProhibition");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("BackColor", StyleColors.InaccessibleCellTextColor);

EndProcedure

&AtClient
Procedure ExternalUsersUsageOnChange()
	
	RefreshShowInChoiceListAttributeVisibility();
	UpdateShowInListProperty();
	
EndProcedure

&AtClient
Procedure OnChangingUserAuthorizationSettings()
	
	OnChangingUserAuthorizationSettingsAtServer();
	UpdateShowInListProperty();
	
EndProcedure

&AtServer
Procedure OnChangingUserAuthorizationSettingsAtServer()
	
	CommonSettingShowInList =
		UsersInternal.LogonSettings().Overall.ShowInList;
	
	RefreshShowInChoiceListAttributeVisibility();
	
EndProcedure

&AtServer
Procedure RefreshShowInChoiceListAttributeVisibility()
	
	If Common.DataSeparationEnabled()
	 Or ExternalUsers.UseExternalUsers() Then
		
		Items.IBUserShowInList.Visible = False;
		Return;
	EndIf;
	
	Items.IBUserShowInList.Visible =
		    CommonSettingShowInList = "EnabledForNewUsers"
		Or CommonSettingShowInList = "DisabledForNewUsers"
	
EndProcedure

&AtClient
Procedure OnChangeAccessGroups()
	
	OnChangeAccessGroupsAtServer();
	
EndProcedure

&AtServer
Procedure OnChangeAccessGroupsAtServer()
	
	SetPrivilegedMode(True);
	WhetherRightsAreAssigned = InformationRegisters.UsersInfo.WhetherRightsAreAssigned(Object.IBUserID);
	SetPrivilegedMode(False);
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtServer
Procedure CustomizeForm(CurrentObject, OnCreateAtServer = False, WriteParameters = Undefined)
	
	If InitialIBUserDetails = Undefined Then
		Return; // OnReadAtServer before OnCreateAtServer.
	EndIf;
	
	If Not OnCreateAtServer Then
		ReadIBUser(, False);
	EndIf;
	
	SetPrivilegedMode(True);
	InformationRegisters.UsersInfo.ReadUserInfo(ThisObject);
	WhetherRightsAreAssigned = InformationRegisters.UsersInfo.WhetherRightsAreAssigned(Object.IBUserID);
	SetPrivilegedMode(False);
	
	AccessLevel = UsersInternal.UserPropertiesAccessLevel(CurrentObject);
	
	DefineActionsOnForm();
	
	FindUserAndIBUserDifferences(WriteParameters);
	
	ProcessRolesInterface("SetRolesReadOnly",
		    UsersInternal.CannotEditRoles()
		Or ActionsOnForm.Roles <> "Edit"
		Or Not AccessLevel.AuthorizationSettings2);
	
	If Common.DataSeparationEnabled()
	   And Common.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		Try
			ActionsWithSaaSUser = ModuleUsersInternalSaaS.GetActionsWithSaaSUser(
				CurrentObject.Ref, ActionsWithSaaSUser);
		Except
			ServiceOperationError = ErrorInfo();
		EndTry;
	EndIf;
	
	// Viewability settings.
	Items.ContactInformation.Visible   = ValueIsFilled(ActionsOnForm.ContactInformation);
	Items.IBUserProperies.Visible = ValueIsFilled(ActionsOnForm.IBUserProperies);
	Items.GroupName.Visible              = ValueIsFilled(ActionsOnForm.IBUserProperies);
	
	OutputRolesList = ValueIsFilled(ActionsOnForm.Roles);
	Items.RolesRepresentation.Visible = OutputRolesList;
	
	Items.CheckAuthorizationSettingsRecommendation.Visible =
		  AccessLevel.ChangeAuthorizationPermission
		And CurrentObject.Prepared
		And Not CanSignInOnRead;
	
	// Editability settings.
	If CurrentObject.IsInternal Then
		ReadOnly = True;
	EndIf;
	Items.InternalUserGroup.Visible = CurrentObject.IsInternal;
	
	ReadOnly = ReadOnly
		Or ActionsOnForm.Roles                   <> "Edit"
		  And ActionsOnForm.ItemProperties       <> "Edit"
		  And ActionsOnForm.ContactInformation   <> "Edit"
		  And ActionsOnForm.IBUserProperies <> "Edit";
	
	ButtonAvailability = Not ReadOnly And AccessRight("Edit",
		Metadata.Catalogs.Users);
	
	If Items.FormWriteAndClose.Enabled <> ButtonAvailability Then
		Items.FormWriteAndClose.Enabled = ButtonAvailability;
	EndIf;
	
	If Items.ChangeAuthorizationRestriction.Enabled <> ButtonAvailability Then
		Items.ChangeAuthorizationRestriction.Enabled = ButtonAvailability;
	EndIf;
	
	If Items.ChangePassword.Enabled <> ButtonAvailability Then
		Items.ChangePassword.Enabled = ButtonAvailability;
	EndIf;
	
	Items.Description.ReadOnly =
		Not (ActionsOnForm.ItemProperties = "Edit" And AccessLevel.ListManagement);
	
	Items.Invalid.ReadOnly = Items.Description.ReadOnly;
	Items.Individual.ReadOnly = Items.Description.ReadOnly;
	Items.Department.ReadOnly  = Items.Description.ReadOnly;
	
	Items.IBUserProperies.ReadOnly =
		Not (  ActionsOnForm.IBUserProperies = "Edit"
		    And (AccessLevel.ListManagement Or AccessLevel.ChangeCurrent));
	Items.GroupName.ReadOnly = Items.IBUserProperies.ReadOnly;
	
	Items.IBUserName.ReadOnly                          = Not AccessLevel.AuthorizationSettings2;
	Items.IBUserStandardAuthentication.ReadOnly    = Not AccessLevel.AuthorizationSettings2;
	Items.IBUserOpenIDAuthentication.ReadOnly         = Not AccessLevel.AuthorizationSettings2;
	Items.InfobaseUserAuthWithOpenIDConnect.ReadOnly  = Not AccessLevel.AuthorizationSettings2;
	Items.InfobaseUserAuthWithAccessToken.ReadOnly = Not AccessLevel.AuthorizationSettings2;
	Items.IBUserOSAuthentication.ReadOnly             = Not AccessLevel.AuthorizationSettings2;
	Items.IBUserOSUser.ReadOnly               = Not AccessLevel.AuthorizationSettings2;
	
	Items.IBUserShowInList.ReadOnly        = Not AccessLevel.ListManagement;
	Items.UserMustChangePasswordOnAuthorization.ReadOnly               = Not AccessLevel.ListManagement;
	Items.IBUserCannotChangePassword.ReadOnly        = Not AccessLevel.ListManagement;
	Items.IBUserCannotRecoveryPassword.ReadOnly = Not AccessLevel.ListManagement;
	Items.IBUserRunMode.ReadOnly                   = Not AccessLevel.ListManagement;
	
	Items.Comment.ReadOnly =
		Not (ActionsOnForm.ItemProperties = "Edit" And AccessLevel.ListManagement);
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtServer
Procedure PrepareOptionalAttribute(Var_AttributeName, Used)
	
	If Not Used Then
		Items[Var_AttributeName].Visible = False;
	Else
		DepartmentTypes = Metadata.DefinedTypes[Var_AttributeName].Type.Types();
		If DepartmentTypes.Count() = 1 And Common.IsReference(DepartmentTypes[0]) Then
			MetadataObject = Metadata.FindByType(DepartmentTypes[0]);
			Items[Var_AttributeName].Title = ObjectPresentation(MetadataObject);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function ObjectPresentation(MetadataObject)
	
	If ValueIsFilled(MetadataObject.ObjectPresentation) Then
		Return MetadataObject.ObjectPresentation;
	EndIf;
	
	Return MetadataObject.Presentation();
	
EndFunction

// The BeforeWrite event handler continuation.
&AtClient
Procedure AfterAuthenticationPasswordRequestInServiceBeforeWrite(SaaSUserNewPassword, WriteParameters) Export
	
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

// The BeforeWrite event handler continuation.
&AtClient
Procedure AfterRequestingAPasswordToChangeTheMail(Result, AdditionalParameters) Export
	
	If TypeOf(Result) = Type("String") Then
		PasswordToConfirmEmailChange = Result;
		Write(AdditionalParameters.WriteParameters);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateUsername(Form, DescriptionOnChange = False)
	
	Items = Form.Items;
	
	// Whether values are required.
	ShowNameOfItemMarkedAsUnfilled = IBUserWritingRequired(Form, False);
	Items.IBUserName.AutoMarkIncomplete = ShowNameOfItemMarkedAsUnfilled;
	If Not ShowNameOfItemMarkedAsUnfilled Then
		Items.IBUserName.MarkIncomplete = False;
	EndIf;
	
	If Form.IBUserExists Then
		Return;
	EndIf;
	
	ShortName = UsersInternalClientServer.GetIBUserShortName(Form.Object.Description);
	
	If Not ShowNameOfItemMarkedAsUnfilled Then
		If (Not ValueIsFilled(Form.IBUserNameDirectChangeValue)
		      Or Form.IBUserNameDirectChangeValue = ShortName)
		   And Form.IBUserName = ShortName Then
			
			Form.IBUserName = "";
		EndIf;
	Else
		If DescriptionOnChange
		 Or Not ValueIsFilled(Form.IBUserName) Then
			
			Form.IBUserName = ShortName;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AuthenticationOnChange()
	
	If Not IBUserStandardAuthentication
	   And Not IBUserOpenIDAuthentication
	   And Not InfobaseUserAuthWithOpenIDConnect
	   And Not InfobaseUserAuthWithAccessToken
	   And Not IBUserOSAuthentication Then
	
		CanSignIn                       = False;
		IBUserCannotRecoveryPassword = True;
		
		If DataSeparationEnabled Then
			Object.Invalid = True;
			InvalidOnChange(Items.Invalid);
			Return;
		EndIf;
		
	ElsIf Not CanSignIn Then
		CanSignIn = CanSignInDirectChangeValue;
		
		If ValueIsFilled(AttributeWithEmailForPasswordRecoveryName)
			And ValueIsFilled(ThisObject[AttributeWithEmailForPasswordRecoveryName]) Then
				IBUserCannotRecoveryPassword = False;
		EndIf;
		
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure UpdateShowInListProperty()
	
	If CommonSettingShowInList = "HiddenAndEnabledForAllUsers" Then
		IBUserShowInList = IBUserStandardAuthentication;
		
	ElsIf CommonSettingShowInList = "HiddenAndDisabledForAllUsers" Then
		IBUserShowInList = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterSelectNewEmail(NewEmailAddress, Context) Export
	
	If Not ValueIsFilled(NewEmailAddress) Then
		Return;
	EndIf;
	
	UsersInternalClient.RequestPasswordForAuthenticationInService(
		New NotifyDescription("ChangeEmailAfterAuthenticationPasswordRequestedInService", ThisObject, NewEmailAddress),
		ThisObject,
		ServiceUserPassword);
	
EndProcedure

&AtClient
Procedure ChangeEmailAfterAuthenticationPasswordRequestedInService(SaaSUserNewPassword, NewEmailAddress) Export
	
	If SaaSUserNewPassword = Undefined Then
		Return;
	EndIf;
	
	ServiceUserPassword = SaaSUserNewPassword;
	
	Try
		CreateEmailAddressChangeRequest(NewEmailAddress, Object.Ref, ServiceUserPassword);
	Except
		ServiceUserPassword = Undefined;
		Raise;
	EndTry;
	
	ShowMessageBox(,
		NStr("en = 'A confirmation request is sent to the specified email address.
		           |The email address will be changed after the confirmation.';"));
	
EndProcedure

&AtServerNoContext
Procedure CreateEmailAddressChangeRequest(Val NewEmailAddress, Val User, Val ServiceUserPassword)
	
	SSLSubsystemsIntegration.OnCreateRequestToChangeEmail(NewEmailAddress,
		User, ServiceUserPassword);
	
EndProcedure

// The procedure that follows ChangePassword procedure.
&AtClient
Procedure ChangePasswordAfterGetPassword(Result, Context) Export
	
	If Not ValueIsFilled(Result) Then
		Return;
	EndIf;
	
	Modified = True;
	
	IBUserPassword       = Result.NewPassword;
	IBUserPreviousPassword = Result.PreviousPassword;
	
	If Result.PreviousPassword <> Undefined Then
		ServiceUserPassword = Result.PreviousPassword;
	EndIf;
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
	CheckPasswordSet(ThisObject, ValueIsFilled(IBUserPassword),
		UsersClient.AuthorizedUser());
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure CheckPasswordSet(Form, PasswordIsSet, AuthorizedUser)
	
	UsersInternalClientServer.CheckPasswordSet(Form, PasswordIsSet, AuthorizedUser);
	
EndProcedure

&AtServer
Procedure DefineActionsOnForm()
	
	ActionsOnForm = New Structure;
	
	// "", "View," "Edit."
	ActionsOnForm.Insert("Roles", "");
	
	// "", "View," "Edit."
	ActionsOnForm.Insert("ContactInformation", "View");
	
	// "", "ViewAll", "Edit".
	ActionsOnForm.Insert("IBUserProperies", "");
	
	// "", "View," "Edit."
	ActionsOnForm.Insert("ItemProperties", "View");
	
	If Not AccessLevel.SystemAdministrator
	   And AccessLevel.FullAccess
	   And Users.IsFullUser(Object.Ref, True) Then
		
		// The system administrator is read-only.
		ActionsOnForm.Roles                   = "View";
		ActionsOnForm.IBUserProperies = "View";
	
	ElsIf AccessLevel.SystemAdministrator
	      Or AccessLevel.FullAccess Then
		
		ActionsOnForm.Roles                   = "Edit";
		ActionsOnForm.ContactInformation   = "Edit";
		ActionsOnForm.IBUserProperies = "Edit";
		ActionsOnForm.ItemProperties       = "Edit";
	Else
		If AccessLevel.ChangeCurrent Then
			ActionsOnForm.IBUserProperies = "Edit";
			ActionsOnForm.ContactInformation   = "Edit";
		EndIf;
		
		If AccessLevel.ListManagement Then
			// The person responsible for the user list and user groups.
			// (The HR manager responsible for recruitment, transfers, reassignments,
			//  and establishment of departments and teams.)
			ActionsOnForm.IBUserProperies = "Edit";
			ActionsOnForm.ContactInformation   = "Edit";
			ActionsOnForm.ItemProperties       = "Edit";
			
			If AccessLevel.AuthorizationSettings2 Then
				ActionsOnForm.Roles = "Edit";
			EndIf;
			If Users.IsFullUser(Object.Ref) Then
				ActionsOnForm.Roles = "View";
			EndIf;
		EndIf;
	EndIf;
	
	UsersInternal.OnDefineActionsInForm(Object.Ref, ActionsOnForm);
	
	// Checking action names in the form.
	If StrFind(", View, Edit,", ", " + ActionsOnForm.Roles + ",") = 0 Then
		ActionsOnForm.Roles = "";
		
	ElsIf ActionsOnForm.Roles = "Edit"
	        And UsersInternal.CannotEditRoles() Then
		
		ActionsOnForm.Roles = "View";
	EndIf;
	
	If StrFind(", View, Edit,", ", " + ActionsOnForm.ContactInformation + ",") = 0 Then
		ActionsOnForm.ContactInformation = "";
	EndIf;
	
	If StrFind(", View, ViewAll, Edit, EditOwn, EditAll,",
	           ", " + ActionsOnForm.IBUserProperies + ",") = 0 Then
		
		ActionsOnForm.IBUserProperies = "";
		
	Else // For backward compatibility.
		If StrFind(ActionsOnForm.IBUserProperies, "View") Then
			ActionsOnForm.IBUserProperies = "View";
			
		ElsIf StrFind(ActionsOnForm.IBUserProperies, "Edit") Then
			ActionsOnForm.IBUserProperies = "Edit";
		EndIf;
	EndIf;
	
	If StrFind(", View, Edit,", ", " + ActionsOnForm.ItemProperties + ",") = 0 Then
		ActionsOnForm.ItemProperties = "";
	EndIf;
	
	If Object.IsInternal Then
		If ActionsOnForm.Roles = "Edit" Then
			ActionsOnForm.Roles = "View";
		EndIf;
		
		If ActionsOnForm.ContactInformation = "Edit" Then
			ActionsOnForm.ContactInformation = "View";
		EndIf;
		
		If ActionsOnForm.IBUserProperies = "Edit" Then
			ActionsOnForm.IBUserProperies = "View";
		EndIf;
		
		If ActionsOnForm.ItemProperties = "Edit" Then
			ActionsOnForm.ItemProperties = "View";
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function IBUserDetails(ForFirstAdministratorCheck = False)
	
	If AccessLevel.ListManagement
	   And ActionsOnForm.ItemProperties = "Edit" Then
		
		IBUserFullName = Object.Description;
	EndIf;
	
	If AccessLevel.SystemAdministrator
	 Or AccessLevel.FullAccess Then
		
		Result = Users.NewIBUserDetails();
		Users.CopyIBUserProperties(
			Result,
			ThisObject,
			,
			"UUID,
			|Roles",
			UsersInternal.PrefixedNamesForInfobaseUserProperties());
		
		Result.Insert("CanSignIn", CanSignIn);
	Else
		Result = New Structure;
		
		If AccessLevel.ChangeCurrent Then
			Result.Insert("Email", IBUserEmailAddress);
			Result.Insert("Password",                IBUserPassword);
			Result.Insert("Language",                  IBUserLanguage);
		EndIf;
		
		If AccessLevel.ListManagement Then
			Result.Insert("Email",          IBUserEmailAddress);
			Result.Insert("CanSignIn",         CanSignIn);
			Result.Insert("ShowInList",        IBUserShowInList
				And Not ExternalUsers.UseExternalUsers());
			Result.Insert("CannotChangePassword",        IBUserCannotChangePassword);
			Result.Insert("CannotRecoveryPassword", IBUserCannotRecoveryPassword);
			Result.Insert("Language",                           IBUserLanguage);
			Result.Insert("RunMode",                   IBUserRunMode);
			
			If ActionsOnForm.ItemProperties = "Edit" Then
				Result.Insert("FullName", IBUserFullName);
			EndIf;
		EndIf;
		
		If AccessLevel.AuthorizationSettings2 Then
			Result.Insert("StandardAuthentication",    IBUserStandardAuthentication);
			Result.Insert("Name",                          IBUserName);
			Result.Insert("Password",                       IBUserPassword);
			Result.Insert("OpenIDAuthentication",         IBUserOpenIDAuthentication);
			Result.Insert("OpenIDConnectAuthentication",  InfobaseUserAuthWithOpenIDConnect);
			Result.Insert("AccessTokenAuthentication", InfobaseUserAuthWithAccessToken);
			Result.Insert("OSAuthentication",             IBUserOSAuthentication);
			Result.Insert("OSUser",               IBUserOSUser);
		EndIf;
	EndIf;
	
	If Not AccessLevel.AuthorizationSettings2 Then
		Return Result;
	EndIf;
	
	If Not UsersInternal.CannotEditRoles() Then
		CurrentRoles = IBUserRoles.Unload(, "Role").UnloadColumn("Role");
		Result.Insert("Roles", CurrentRoles);
	EndIf;
	
	If ForFirstAdministratorCheck Then
		Return Result;
	EndIf;
	
	// Adding roles required to create the first administrator.
	If UsersInternal.CreateFirstAdministratorRequired(Result) Then
		
		If Result.Property("Roles") And Result.Roles <> Undefined Then
			AdministratorRoles = Result.Roles;
		Else
			AdministratorRoles = New Array;
		EndIf;
		
		If AdministratorRoles.Find("FullAccess") = Undefined Then
			AdministratorRoles.Add("FullAccess");
		EndIf;
		
		If AdministratorRoles.Find("SystemAdministrator") = Undefined Then
			AdministratorRoles.Add("SystemAdministrator");
		EndIf;
		Result.Insert("Roles", AdministratorRoles);
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function CreateFirstAdministratorRequired(QueryText = Undefined)
	
	Return UsersInternal.CreateFirstAdministratorRequired(
		IBUserDetails(True), QueryText);
	
EndFunction

&AtServerNoContext
Function InfobaseUsersListIsBlank()
	
	SetPrivilegedMode(True);
	
	Return Not ValueIsFilled(InfoBaseUsers.CurrentUser().Name)
		And InfoBaseUsers.GetUsers().Count() = 0;
	
EndFunction

&AtClientAtServerNoContext
Procedure DetermineNecessityForSynchronizationWithService(Form)
	
	Form.SynchronizationWithServiceRequired = True;
	
EndProcedure

&AtClient
Procedure AfterAnswerToQuestionAboutWritingWithEmptyRoleList(Response, WriteParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		WriteParameters.Insert("WithEmptyRoleList");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckFirstAdministrator() 
	
	WriteParameters = WriteParametersOnFirstAdministratorCheck;
	WriteParametersOnFirstAdministratorCheck = Undefined;
	
	QueryText = "";
	If Not CreateFirstAdministratorRequired(QueryText) Then
		WriteParameters.Insert("WithFirstAdministratorAdding");
		Try
			Write(WriteParameters);
		Except
			ServiceUserPassword = Undefined;
			Raise;
		EndTry;
		Return;
	EndIf;
	
	QuestionTitle = NStr("en = 'Save infobase user';");
	ShowQueryBox(
		New NotifyDescription("AfterFirstAdministratorCreationConfirmation", ThisObject, WriteParameters),
		QueryText, QuestionDialogMode.YesNo, , , QuestionTitle);
	
EndProcedure

&AtClient
Procedure AfterFirstAdministratorCreationConfirmation(Response, WriteParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	CanSignIn = True;
	IBUserStandardAuthentication = True;
	
	UpdateShowInListProperty();
	
	WriteParameters.Insert("WithFirstAdministratorAdding");
	Write(WriteParameters);
	
EndProcedure

&AtClient
Procedure AfterAnswerToQuestionAboutCopyingRights(Response, WriteParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		WriteParameters.Insert("CopyUserRights");
	Else
		WriteParameters.Insert("NotCopyUserRights");
	EndIf;
	Write(WriteParameters);
	
EndProcedure

&AtClient
Procedure AfterWriteCompletion(Result, WriteParameters) Export
	
	If WriteParameters <> Undefined And WriteParameters.Property("WriteAndClose") Then
		AttachIdleHandler("CloseForm", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseForm()
	
	Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Provide contact information support.

&AtServer
Procedure UpdateContactInformation(Result)
	
	ModuleContactsManager = Common.CommonModule("ContactsManager");
	ModuleContactsManager.UpdateContactInformation(ThisObject, Object, Result);
	
EndProcedure

&AtServer
Procedure OverrideContactInformationEditingSaaS()
	
	If Not Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	ContactInformation = ContactInformationAdditionalAttributesDetails;
	
	EmailRow = ContactInformation.FindRows(New Structure("Kind", ContactInformationKind("UserEmail")))[0];
	EmailItem = Items[EmailRow.AttributeName];
	EmailItem.SetAction("OnChange", "Attachable_EMailOnChange");
	EmailItem.SetAction("Clearing",      "Attachable_EMailClearing");
	EmailItem.AutoMarkIncomplete = True;
	
	EmailItem.ChoiceButton = ValueIsFilled(Object.Ref) And ValueIsFilled(ThisObject[EmailRow.AttributeName]);
	EmailItem.TextEdit = Not EmailItem.ChoiceButton;
	EmailItem.SetAction("StartChoice", "Attachable_EMailStartChoice");
	
	PhoneLine = ContactInformation.FindRows(New Structure("Kind", ContactInformationKind("UserPhone")))[0];
	PhoneItem = Items[PhoneLine.AttributeName];
	PhoneItem.SetAction("OnChange", "Attachable_PhoneOnChange");
	
EndProcedure

&AtServer
Procedure UpdateEmailChangeMethodSaaS()
	
	If Not Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	ContactInformation = ContactInformationAdditionalAttributesDetails;
	
	EmailRow = ContactInformation.FindRows(New Structure("Kind", ContactInformationKind("UserEmail")))[0];
	EmailItem = Items[EmailRow.AttributeName];
	
	EmailItem.ChoiceButton = ValueIsFilled(Object.Ref) And ValueIsFilled(ThisObject[EmailRow.AttributeName]);
	EmailItem.TextEdit = Not EmailItem.ChoiceButton;
	
EndProcedure

&AtServerNoContext
Function ContactInformationKind(KindName)
	
	ModuleContactsManager = Common.CommonModule("ContactsManager");
	Return ModuleContactsManager.ContactInformationKindByName(KindName);
	
EndFunction

&AtClientAtServerNoContext
Function ContactInformationKindUserEmail()
	
	PredefinedValueName = "Catalog." + "ContactInformationKinds" + ".UserEmail";
	
	Return PredefinedValue(PredefinedValueName);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Support of additional attributes.

&AtServer
Procedure PropertiesExecuteDeferredInitialization()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillAdditionalAttributesInForm(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.UpdateAdditionalAttributesItems(ThisObject);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Processes an infobase user.

&AtServer
Function InitialIBUserDetails()
	
	SetPrivilegedMode(True);
	
	If InitialIBUserDetails <> Undefined Then
		InitialIBUserDetails.Roles = New Array;
		Return InitialIBUserDetails;
	EndIf;
	
	IBUserDetails = Users.NewIBUserDetails(False);
	
	If Common.DataSeparationEnabled()
	 Or ExternalUsers.UseExternalUsers() Then
		IBUserDetails.ShowInList = False;
	Else
		IBUserDetails.ShowInList =
			    CommonSettingShowInList = "EnabledForNewUsers"
			Or CommonSettingShowInList = "HiddenAndEnabledForAllUsers";
	EndIf;
	IBUserDetails.Roles = New Array;
	
	Return IBUserDetails;
	
EndFunction

&AtServer
Procedure ReadIBUser(OnCopyItem = False, OnCreateAtServer = True)
	
	SetPrivilegedMode(True);
	
	ReadProperties      = Undefined;
	IBUserDetails   = InitialIBUserDetails();
	IBUserExists = False;
	IBUserMain   = False;
	IBUserPassword     = Undefined;
	CanSignIn   = False;
	CanSignInDirectChangeValue = False;
	
	If OnCreateAtServer And OnCopyItem Then
		
		ReadProperties = Users.IBUserProperies(Parameters.CopyingValue.IBUserID);
		If ReadProperties <> Undefined Then
			
			// Mapping an infobase user to a catalog user.
			If Users.CanSignIn(ReadProperties) Then
				CanSignIn = True;
				CanSignInDirectChangeValue = True;
				IBUserDetails.StandardAuthentication = True;
			EndIf;
			
			// Copying infobase user properties and roles.
			FillPropertyValues(
				IBUserDetails,
				ReadProperties,
				"CannotChangePassword,
				|ShowInList,
				|DefaultInterface,
				|RunMode" + ?(Not Items.IBUserLanguage.Visible, "", ",
				|Language") + ?(UsersInternal.CannotEditRoles(), "", ",
				|Roles"));
		EndIf;
		Object.IBUserID = Undefined;
		CheckPasswordSet(ThisObject, False, Users.AuthorizedUser());
	Else
		ReadProperties = Users.IBUserProperies(Object.IBUserID);
		If ReadProperties <> Undefined Then
		
			IBUserExists = True;
			IBUserMain = True;
		
		ElsIf OnCreateAtServer And ValueIsFilled(Parameters.IBUserID) Then
			
			If Object.IBUserID <> Parameters.IBUserID Then
				Object.IBUserID = Parameters.IBUserID;
				Modified = True;
			EndIf;
			ReadProperties = Users.IBUserProperies(Object.IBUserID);
			If ReadProperties <> Undefined Then
				
				IBUserExists = True;
				If Object.Description <> ReadProperties.FullName Then
					Object.Description = ReadProperties.FullName;
					Modified = True;
				EndIf;
			EndIf;
		EndIf;
		
		If IBUserExists Then
			
			If Users.CanSignIn(ReadProperties) Then
				CanSignIn = True;
				CanSignInDirectChangeValue = True;
			EndIf;
			
			FillPropertyValues(
				IBUserDetails,
				ReadProperties,
				"Name,
				|FullName,
				|Email,
				|StandardAuthentication,
				|ShowInList,
				|CannotChangePassword,
				|CannotRecoveryPassword,
				|OpenIDAuthentication,
				|OpenIDConnectAuthentication,
				|AccessTokenAuthentication,
				|OSAuthentication,
				|OSUser,
				|DefaultInterface,
				|RunMode" + ?(Not Items.IBUserLanguage.Visible, "", ",
				|Language") + ?(UsersInternal.CannotEditRoles(), "", ",
				|Roles") + ",
				|UnsafeActionProtection");
		EndIf;
		
		If ReadProperties = Undefined Then
			CheckPasswordSet(ThisObject, False,
				Users.AuthorizedUser());
		Else
			CheckPasswordSet(ThisObject, ReadProperties.PasswordIsSet,
				Users.AuthorizedUser());
		EndIf;
	EndIf;
	
	Users.CopyIBUserProperties(
		ThisObject,
		IBUserDetails,
		,
		"UUID,
		|Roles" + ?(ExternalUsers.UseExternalUsers(), ",
		|ShowInList", ""),
		UsersInternal.PrefixedNamesForInfobaseUserProperties());
	
	If IBUserMain And Not CanSignIn Then
		StoredProperties = UsersInternal.StoredIBUserProperties(Object.Ref);
		IBUserStandardAuthentication    = StoredProperties.StandardAuthentication;
		IBUserOpenIDAuthentication         = StoredProperties.OpenIDAuthentication;
		InfobaseUserAuthWithOpenIDConnect  = StoredProperties.OpenIDConnectAuthentication;
		InfobaseUserAuthWithAccessToken = StoredProperties.AccessTokenAuthentication;
		IBUserOSAuthentication             = StoredProperties.OSAuthentication;
	EndIf;
	
	If IBUserExists Then
		IBUserStandardAuthenticationDirectChangeValue
			= IBUserStandardAuthentication;
	EndIf;
	
	ProcessRolesInterface("FillRoles", IBUserDetails.Roles);
	
	CanSignInOnRead = CanSignIn;
	
EndProcedure

&AtServer
Procedure FindUserAndIBUserDifferences(WriteParameters = Undefined)
	
	// Check if the infobase user's "FullName" property matches the user's "Description" attribute.
	// 
	
	ShowDifference = True;
	ShowDifferenceResolvingCommands = False;
	
	If Not IBUserExists Then
		ShowDifference = False;
		
	ElsIf Not ValueIsFilled(Object.Ref) Then
		Object.Description = IBUserFullName;
		ShowDifference = False;
		
	ElsIf AccessLevel.ListManagement Then
		
		PropertiesToResolve = New Array;
		
		If IBUserFullName <> Object.Description Then
			ShowDifferenceResolvingCommands =
				    ShowDifferenceResolvingCommands
				Or ActionsOnForm.ItemProperties = "Edit";
			
			PropertiesToResolve.Insert(0, StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Full name: ""%1""';"),
				IBUserFullName));
		EndIf;
		
		If CanSignInOnRead And Object.Invalid Then
			CanSignIn = False;
			ShowDifferenceResolvingCommands =
				    ShowDifferenceResolvingCommands
				Or ActionsOnForm.ItemProperties = "Edit";
			
			PropertiesToResolve.Insert(0, NStr("en = 'Login allowed';"));
		EndIf;
		
		// Validate the email.
		If AccessLevel.ChangeCurrent Then
			If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
				
				ModuleContactsManager = Common.CommonModule("ContactsManager");
				
				DetailsString = ModuleContactsManager.EmailDescriptionStringForPasswordRecoveryFromFormData(
					ThisObject, ContactInformationKind("UserEmail"), IBUserEmailAddress);
				
				If DetailsString = Undefined Then
					ShowDifferenceResolvingCommands =
						    ShowDifferenceResolvingCommands
						Or ActionsOnForm.ItemProperties = "Edit";
					
					PropertiesToResolve.Insert(0, StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Email for password recovery ""%1""';"),
						IBUserEmailAddress));
				EndIf;
			EndIf;
		EndIf;
		
		SetPrivilegedMode(True);
		AreSavedInfobaseUserPropertiesMismatch = ValueIsFilled(Object.Ref)
			And InformationRegisters.UsersInfo.AreSavedInfobaseUserPropertiesMismatch(Object);
		SetPrivilegedMode(False);
		
		ShowCommentToDiffResolve =
			    ShowDifferenceResolvingCommands
			Or AreSavedInfobaseUserPropertiesMismatch
			  And ActionsOnForm.ItemProperties = "Edit";
		
		If PropertiesToResolve.Count() > 0
		 Or AreSavedInfobaseUserPropertiesMismatch Then
			
			PropertiesToResolveString = "";
			CurrentRow = "";
			For Each PropertyToResolve In PropertiesToResolve Do
				If StrLen(CurrentRow + PropertyToResolve) > 90 Then
					PropertiesToResolveString = PropertiesToResolveString + TrimR(CurrentRow) + ", " + Chars.LF;
					CurrentRow = "";
				EndIf;
				CurrentRow = CurrentRow + ?(ValueIsFilled(CurrentRow), ", ", "") + PropertyToResolve;
			EndDo;
			If ValueIsFilled(CurrentRow) Then
				PropertiesToResolveString = PropertiesToResolveString + CurrentRow;
			EndIf;
			If ShowCommentToDiffResolve Then
				Recommendation = Chars.LF
					+ NStr("en = 'To resolve the differences and not to show this message again, click ""Save"".';");
			
			ElsIf Not Users.IsFullUser() Then
				Recommendation = Chars.LF
					+ NStr("en = 'To resolve the differences, contact your system administrator.';");
			Else
				Recommendation = "";
			EndIf;
			If ValueIsFilled(PropertiesToResolveString) Then
				MismatchClarification = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The following infobase user properties differ from the properties specified in the form:
					           |%1.';"),
					PropertiesToResolveString) + ?(Not AreSavedInfobaseUserPropertiesMismatch, "", "
					|" + NStr("en = 'The picture in the user list might display an outdated state
					                |as some other saved properties also differ.';"));
			Else
				MismatchClarification =
					NStr("en = 'The picture in the user list might display an outdated state
					           |as some infobase user properties differ from the saved ones.';");
			EndIf;
			Items.PropertiesMismatchNote.Title = MismatchClarification + Recommendation;
		Else
			ShowDifference = False;
		EndIf;
	Else
		ShowDifference = False;
	EndIf;
	
	Items.PropertiesMismatchProcessing.Visible   = ShowDifference;
	Items.ResolveDifferencesCommandProperties.Visible = ShowDifferenceResolvingCommands;
	Items.PropertiesMismatchNote.VerticalAlign = ?(ValueIsFilled(Recommendation),
		ItemVerticalAlign.Top, ItemVerticalAlign.Center);
	
	// Determining the mapping between a nonexistent infobase user and a catalog user.
	HasNewMappingToNonExistingIBUser
		= Not IBUserExists
		And ValueIsFilled(Object.IBUserID);
	
	If WriteParameters <> Undefined
	   And HasMappingToNonexistentIBUser
	   And Not HasNewMappingToNonExistingIBUser Then
		
		WriteParameters.Insert("MappingToNonExistingIBUserCleared", Object.Ref);
	EndIf;
	HasMappingToNonexistentIBUser = HasNewMappingToNonExistingIBUser;
	
	If AccessLevel.ListManagement Then
		Items.MappingMismatchProcessing.Visible = HasMappingToNonexistentIBUser;
	Else
		// Cannot change the mapping.
		Items.MappingMismatchProcessing.Visible = False;
	EndIf;
	
	If ActionsOnForm.ItemProperties = "Edit" Then
		Recommendation = Chars.LF
			+ NStr("en = 'To eliminate the issue and not to show this message again, click ""Save"".';");
		
	ElsIf Not Users.IsFullUser() Then
		Recommendation = Chars.LF
			+ NStr("en = 'To resolve the differences, contact your system administrator.';");
	Else
		Recommendation = "";
	EndIf;
	
	Items.MappingMismatchNote.Title =
		NStr("en = 'The infobase user does not exist.';") + Recommendation;
	
EndProcedure

&AtServer
Procedure FillFieldsByIBUserAtServer()
	
	If AccessLevel.ListManagement
	   And ActionsOnForm.ItemProperties = "Edit" Then
		
		Object.Description = IBUserFullName;
		FillInTheMailFieldForPasswordRecoveryFromTheInformationSecuritySystem();
		
	EndIf;
	
	FindUserAndIBUserDifferences();
	
	SetPropertiesAvailability(ThisObject);
	
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
EndProcedure

&AtServer
Procedure FillInTheMailFieldForPasswordRecoveryFromTheInformationSecuritySystem()
	
	If IsBlankString(AttributeWithEmailForPasswordRecoveryName) Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		
		MailForPasswordRecoveryFromAnObject = New Structure(AttributeWithEmailForPasswordRecoveryName, Undefined);
		FillPropertyValues(MailForPasswordRecoveryFromAnObject, ThisObject);
		
		If ValueIsFilled(MailForPasswordRecoveryFromAnObject[AttributeWithEmailForPasswordRecoveryName])
			Or MailForPasswordRecoveryFromAnObject[AttributeWithEmailForPasswordRecoveryName] <> IBUserEmailAddress Then
			
			ViewOfTheUserSEmailAddress = ContactInformationKind("UserEmail");
			EmailDescription = ModuleContactsManager.EmailDescriptionStringForPasswordRecoveryFromFormData(ThisObject, ViewOfTheUserSEmailAddress, ThisObject[AttributeWithEmailForPasswordRecoveryName]);
			
			If EmailDescription <> Undefined Then
				EmailDescription.Presentation = IBUserEmailAddress;
				EmailDescription.Value = ModuleContactsManager.ContactsByPresentation(
					IBUserEmailAddress, ViewOfTheUserSEmailAddress);
				
				ThisObject[AttributeWithEmailForPasswordRecoveryName] = IBUserEmailAddress;
			EndIf;
			
		EndIf;
		
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Initial filling, fill checks, and availability of properties.

&AtClientAtServerNoContext
Procedure SetPropertiesAvailability(Form)
	
	Items       = Form.Items;
	Object         = Form.Object;
	AccessLevel = Form.AccessLevel;
	ActionsWithSaaSUser = Form.ActionsWithSaaSUser;
	
	// Note to the "Sign-in blocked" state.
	If Form.CanSignIn Then
		Items.GroupNoRights.Visible         = Form.WhetherRightsAreAssigned.HasNoRights;
		Items.GroupNoStartupRights.Visible = Not Form.WhetherRightsAreAssigned.HasNoRights
			And Form.WhetherRightsAreAssigned.HasInsufficientRightsForStartup;
		Items.GroupNoLogonRights.Visible   = Not Form.WhetherRightsAreAssigned.HasNoRights
			And Not Form.WhetherRightsAreAssigned.HasInsufficientRightsForStartup
			And Form.WhetherRightsAreAssigned.HasInsufficientRightForLogon;
	Else
		Items.GroupNoRights.Visible         = False;
		Items.GroupNoStartupRights.Visible = False;
		Items.GroupNoLogonRights.Visible   = False;
	EndIf;
	
	// Setting editing options.
	Items.CanSignIn.ReadOnly =
		Not (  Items.IBUserProperies.ReadOnly = False
		    And (    AccessLevel.ChangeAuthorizationPermission
		       Or AccessLevel.DisableAuthorizationApproval And Form.CanSignInOnRead));
	
	Items.ChangePassword.Enabled =
		(    AccessLevel.AuthorizationSettings2
		 Or AccessLevel.ChangeCurrent
		   And Not Form.IBUserCannotChangePassword)
		And Not Object.IsInternal;
	
	UpdateUsername(Form);
	
	// Setting availability of related items.
	Items.CanSignIn.Enabled    = Not Object.Invalid;
	Items.IBUserProperies.Enabled    = Not Object.Invalid;
	Items.GroupName.Enabled                 = Not Object.Invalid;
	Items.ChangeRestrictionGroup.Enabled = Not Object.Invalid
	                                               And Not Items.Description.ReadOnly;
	
	Items.OneCEnterpriseAuthenticationParameters.Enabled = Form.IBUserStandardAuthentication;
	Items.IBUserOSUser.Enabled         = Form.IBUserOSAuthentication;
	
	Items.IBUserCannotRecoveryPassword.Enabled = Not Form.IBUserCannotChangePassword;
	
	// Adjusting SaaS settings.
	If ActionsWithSaaSUser <> Undefined Then
		
		// Contact information is editable.
		Filter = New Structure("Kind", ContactInformationKindUserEmail());
		FoundRows = Form.ContactInformationAdditionalAttributesDetails.FindRows(Filter);
		EmailFilled = (FoundRows <> Undefined) And ValueIsFilled(Form[FoundRows[0].AttributeName]);
		If Object.Ref.IsEmpty() And EmailFilled Then
			CanChangePassword2 = False;
		Else
			CanChangePassword2 = ActionsWithSaaSUser.EditPassword;
		EndIf;
		
		Items.ChangePassword.Enabled = Items.ChangePassword.Enabled And CanChangePassword2;
		
		Items.IBUserName.ReadOnly = Items.IBUserName.ReadOnly
			Or Not ActionsWithSaaSUser.ChangeName;
		
		Items.Description.ReadOnly = Items.Description.ReadOnly 
			Or Not ActionsWithSaaSUser.ChangeFullName;
		
		Items.CanSignIn.Enabled = Items.CanSignIn.Enabled
			And ActionsWithSaaSUser.ChangeAccess;
		
		Items.Invalid.Enabled = Items.Invalid.Enabled
			And ActionsWithSaaSUser.ChangeAccess;
		
		Form.AdministrativeAccessChangeProhibition =
			Not ActionsWithSaaSUser.ChangeAdministrativeAccess;
	EndIf;
	
	UsersInternalClientServer.UpdateLifetimeRestriction(Form);
	
EndProcedure

&AtServer
Function DetermineContactInformationItemsAvailability()
	
	Result = New Map;
	For Each ContactInformationRow In ContactInformationAdditionalAttributesDetails Do // ValueTableRow of See ContactsManager.NewContactInformation
		ContactInformationKindActions = ActionsWithSaaSUser.ContactInformation.Get(ContactInformationRow.Kind);
		If ContactInformationKindActions = Undefined Then
			// Service manager does not manage whether this kind of contact information can be edited.
			Continue;
		EndIf;
		ContactInformationItem = Items[ContactInformationRow.AttributeName];
		Result.Insert(ContactInformationRow.Kind,
			Not ContactInformationItem.ReadOnly
			And ContactInformationKindActions.Update);
	EndDo;
	
	Return Result;
	
EndFunction

// The procedure that follows ChangeAuthorizationRestriction.
&AtClient
Procedure ChangeAuthorizationRestrictionCompletion(Result, Context) Export
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Function IBUserWritingRequired(Form, UseStandardName = True)
	
	If Form.ActionsOnForm.IBUserProperies <> "Edit" Then
		Return False;
	EndIf;
	
	Template = Form.InitialIBUserDetails;
	
	CurrentName = "";
	If Not UseStandardName Then
		ShortName = UsersInternalClientServer.GetIBUserShortName(
			Form.Object.Description);
		
		If Form.IBUserName = ShortName Then
			CurrentName = ShortName;
		EndIf;
	EndIf;
	
	If Form.IBUserExists
	 Or Form.CanSignIn
	 Or Form.IBUserName                          <> CurrentName
	 Or Form.IBUserStandardAuthentication    <> Template.StandardAuthentication
	 Or Form.IBUserShowInList      <> Template.ShowInList
	 Or Form.IBUserCannotChangePassword      <> Template.CannotChangePassword
	 Or Form.IBUserPassword                       <> Undefined
	 Or Form.IBUserOpenIDAuthentication         <> Template.OpenIDAuthentication
	 Or Form.InfobaseUserAuthWithOpenIDConnect  <> Template.OpenIDConnectAuthentication
	 Or Form.InfobaseUserAuthWithAccessToken <> Template.AccessTokenAuthentication
	 Or Form.IBUserOSAuthentication             <> Template.OSAuthentication
	 Or Form.IBUserOSUser               <> ""
	 Or Form.IBUserRunMode                 <> Template.RunMode
	 Or Form.IBUserLanguage                         <> Template.Language
	 Or Form.IBUserRoles.Count()            <> 0 Then
		
		Return True;
	EndIf;
	
	// Supported in the latest 1C:Enterprise versions.
	If Template.Property("CannotRecoveryPassword")
		 And Form.IBUserCannotRecoveryPassword <> Template.CannotRecoveryPassword Then
			Return True;
	EndIf;
	
	Return False;
	
EndFunction

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

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtServer
Procedure ProcessRolesInterface(Action, MainParameter = Undefined)
	
	ActionParameters = New Structure;
	ActionParameters.Insert("MainParameter", MainParameter);
	ActionParameters.Insert("Form",            ThisObject);
	ActionParameters.Insert("RolesCollection",   IBUserRoles);
	ActionParameters.Insert("AdministrativeAccessChangeProhibition",
		AdministrativeAccessChangeProhibition);
	
	ActionParameters.Insert("RolesAssignment", "ForAdministrators");
	
	AdministrativeAccessEnabled = IBUserRoles.FindRows(
		New Structure("Role", "FullAccess")).Count() > 0;
	
	UsersInternal.ProcessRolesInterface(Action, ActionParameters);
	
	AdministrativeAccessWasEnabled = IBUserRoles.FindRows(
		New Structure("Role", "FullAccess")).Count() > 0;
	
	If AdministrativeAccessWasEnabled <> AdministrativeAccessEnabled Then
		DetermineNecessityForSynchronizationWithService(ThisObject);
	EndIf;
	
EndProcedure


#EndRegion