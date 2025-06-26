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
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	If Not UsersInternal.ExternalUsersEmbedded() Then
		Items.AuthorizationObject.Enabled = False;
	EndIf;
	
	// Filling auxiliary data.
	
	CannotEditRoles = UsersInternal.CannotEditRoles();
	
	// Filling the language selection list.
	If Metadata.Languages.Count() < 2 Then
		Items.IBUserLanguage.Visible = False;
	Else
		For Each LanguageMetadata In Metadata.Languages Do
			Items.IBUserLanguage.ChoiceList.Add(
				LanguageMetadata.Name, LanguageMetadata.Synonym);
		EndDo;
	EndIf;
	
	// Preparing for execution of interactive actions according to the form opening scenarios.
	AccessLevel = UsersInternal.UserPropertiesAccessLevel(Object);
	
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(Object.Ref) Then
		
		// Creating an item.
		If Parameters.NewExternalUserGroup
		       <> ExternalUsers.AllExternalUsersGroup() Then
			
			NewExternalUserGroup = Parameters.NewExternalUserGroup;
		EndIf;
		
		If ValueIsFilled(Parameters.CopyingValue) Then
			// Copy item.
			CopyingValue = Parameters.CopyingValue;
			Object.Description      = "";
			Object.AuthorizationObject = Undefined;
			IBUserEmailAddress = "";
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
		Else
			// Add item.
			If ValueIsFilled(Parameters.NewExternalUserAuthorizationObject) Then
				
				Object.AuthorizationObject = Parameters.NewExternalUserAuthorizationObject;
				AuthorizationObjectSetOnOpen = ValueIsFilled(Object.AuthorizationObject);
				
			ElsIf ValueIsFilled(NewExternalUserGroup) Then
				
				ExternalUserGroupPurpose = Common.ObjectAttributeValue(
					NewExternalUserGroup, "Purpose").Unload();
				
				SingleUserType = ExternalUserGroupPurpose.Count() = 1;
				
				If SingleUserType Then
					Object.AuthorizationObject = ExternalUserGroupPurpose[0].UsersType;
				EndIf;
				
				Items.AuthorizationObject.ChooseType = Not SingleUserType;
			EndIf;
			
			// Reading initial infobase user property values.
			ReadIBUser();
			
			If Not ValueIsFilled(Parameters.IBUserID) Then
				IBUserStandardAuthentication = True;
				
				If AccessLevel.ChangeAuthorizationPermission Then
					CanSignIn = True;
					CanSignInDirectChangeValue = True;
				EndIf;
			EndIf;
		EndIf;
		
		If AccessLevel.ListManagement
		   And Object.AuthorizationObject <> Undefined Then
			
			IBUserName = UsersInternalClientServer.GetIBUserShortName(
				CurrentAuthorizationObjectPresentation);
			
			IBUserFullName = Object.Description;
		EndIf;
	Else
		// Open an existing item.
		ReadIBUser();
	EndIf;
	
	SetPrivilegedMode(False);
	
	ProcessRolesInterface("SetUpRoleInterfaceOnFormCreate", True);
	InitialIBUserDetails = InitialIBUserDetails();
	
	CustomizeForm(Object, True);
	
	If AuthorizationObjectSetOnOpen Then
		AuthorizationObjectOnChangeAtClientAtServer(ThisObject, Object);
	EndIf;
	
	If Common.IsStandaloneWorkplace() Then
		Items.HeaderGroup.ReadOnly = True;
		Items.AdditionalAttributesPage.ReadOnly = True;
		Items.CommentPage.ReadOnly = True;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesPage");
		AdditionalParameters.Insert("DeferredInitialization", True);
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	
	PasswordToConfirmEmailChange = Undefined;
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		
		If ModuleContactsManager.ContainsContactInformation(Object.AuthorizationObject)
		   And ValueIsFilled(Object.AuthorizationObject) Then
			AccountNameAuthorizationObject = AccountNameAuthorizationObject(TypeOf(Object.AuthorizationObject));
			
			ModuleContactsManager.OnCreateAtServer(ThisObject, ThisObject[AccountNameAuthorizationObject]);
			
			If UsersInternal.PasswordRecoverySettingsAreAvailable(AccessLevel) Then
			
				If Not UsersInternal.InteractivelyPromptForAPassword(AccessLevel, Object) Then
					PasswordToConfirmEmailChange = "";
				EndIf;
				
				AttributeWithEmailForPasswordRecoveryName = ModuleContactsManager.DefineAnItemWithMailForPasswordRecovery(
					ThisObject,
					IBUserEmailAddress,
					UsersInternal.YouCanEditYourEmailToRestoreYourPassword(AccessLevel, Object),
					True);
			
			EndIf;
			
			Items.ContactInformationGroup.Enabled = Users.IsFullUser();
			
		EndIf;
	EndIf;
	
	If Common.DataSeparationEnabled()
		Or Not Users.CommonAuthorizationSettingsUsed() Then
		Items.ChangeRestrictionGroup.Visible = False;
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Items.IBUserCannotRecoveryPassword.Visible = False;
	EndIf;
	
	Items.UserMustChangePasswordOnAuthorization.ExtendedTooltip.Title =
		UsersInternal.HintUserMustChangePasswordOnAuthorization(True);
	
	If Common.IsMobileClient() Then
		Items.FormWriteAndClose.Representation = ButtonRepresentation.Picture;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
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
	
	CustomizeForm(CurrentObject);
	
	CurrentAuthorizationObjectPresentation = String(Object.AuthorizationObject);
	
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
	
	// StandardSubsystems.ContactInformation
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		If ModuleContactsManager.ContainsContactInformation(Object.AuthorizationObject) Then
			AccountNameAuthorizationObject = AccountNameAuthorizationObject(TypeOf(Object.AuthorizationObject));
			ModuleContactsManager.OnReadAtServer(ThisObject, ThisObject[AccountNameAuthorizationObject]);
			
			If TypeOf(AccessLevel) = Type("Structure") And UsersInternal.PasswordRecoverySettingsAreAvailable(AccessLevel) Then
				AttributeWithEmailForPasswordRecoveryName = ModuleContactsManager.DefineAnItemWithMailForPasswordRecovery(
					ThisObject,
					IBUserEmailAddress,
					UsersInternal.YouCanEditYourEmailToRestoreYourPassword(AccessLevel, Object.AuthorizationObject), True);
			EndIf;
			
		EndIf;
	EndIf;
	// End StandardSubsystems.ContactInformation
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	ClearMessages();
	QuestionTitle1 = NStr("en = 'Save infobase user';");
	
	// Copying user rights.
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
	
	If ActionsOnForm.Roles = "Edit"
	   And Object.SetRolesDirectly
	   And IBUserRoles.Count() = 0 Then
		
		If Not WriteParameters.Property("WithEmptyRoleList") Then
			Cancel = True;
			ShowQueryBox(
				New NotifyDescription("AfterAnswerToQuestionAboutWritingWithEmptyRoleList", ThisObject, WriteParameters),
				NStr("en = 'No roles are assigned to the infobase user. Do you want to continue?';"),
				QuestionDialogMode.YesNo,
				,
				,
				NStr("en = 'Save infobase user';"));
			Return;
		EndIf;
	EndIf;
	
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
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.AdditionalProperties.Insert("CopyingValue", CopyingValue);
	CurrentObject.AdditionalProperties.Insert("IsRecoveryEmailSetOnForm");
	
	UpdateDisplayedUserType();
	// Auto updating external user description.
	SetPrivilegedMode(True);
	CurrentAuthorizationObjectPresentation = String(CurrentObject.AuthorizationObject);
	SetPrivilegedMode(False);
	Object.Description        = CurrentAuthorizationObjectPresentation;
	CurrentObject.Description = CurrentAuthorizationObjectPresentation;
	
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
	EndIf;
	
	If ActionsOnForm.ItemProperties <> "Edit" Then
		FillPropertyValues(CurrentObject, Common.ObjectAttributesValues(
			CurrentObject.Ref, "DeletionMark"));
	EndIf;
	
	InformationRegisters.UsersInfo.ObtainUserInfo(ThisObject, CurrentObject);
	
	CurrentObject.AdditionalProperties.Insert(
		"NewExternalUserGroup", NewExternalUserGroup);
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	
	// StandardSubsystems.ContactInformation
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		If ModuleContactsManager.ContainsContactInformation(Object.AuthorizationObject) Then
			AccountNameAuthorizationObject = AccountNameAuthorizationObject(TypeOf(Object.AuthorizationObject));
			ModuleContactsManager = Common.CommonModule("ContactsManager");
			ModuleContactsManager.BeforeWriteAtServer(ThisObject, ThisObject[AccountNameAuthorizationObject]);
		EndIf;
	EndIf;
	// End StandardSubsystems.ContactInformation
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.ContactInformation
	If Common.SubsystemExists("StandardSubsystems.ContactInformation")
		 And Users.IsFullUser() Then
		
		AccountNameAuthorizationObject = AccountNameAuthorizationObject(TypeOf(Object.AuthorizationObject));
		
		AuthorizationObjectObject = FormAttributeToValue(AccountNameAuthorizationObject);
		If Not AuthorizationObjectObject.Ref.IsEmpty() Then
			AuthorizationObjectObject.Write();
			ValueToFormAttribute(AuthorizationObjectObject, AccountNameAuthorizationObject);
		EndIf;
	EndIf;
	// End StandardSubsystems.ContactInformation
	
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
	
	If IBUserWritingRequired(ThisObject) Then
		WriteParameters.Insert(
			CurrentObject.AdditionalProperties.IBUserDetails.ActionResult);
	EndIf;
	
	CustomizeForm(CurrentObject, , WriteParameters);
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
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
	
	Notify("Write_ExternalUsers", New Structure, Object.Ref);
	NotifyChanged(Object.AuthorizationObject);
	
	If WriteParameters.Property("IBUserAdded") Then
		Notify("IBUserAdded", WriteParameters.IBUserAdded, ThisObject);
		
	ElsIf WriteParameters.Property("IBUserChanged") Then
		Notify("IBUserChanged", WriteParameters.IBUserChanged, ThisObject);
		
	ElsIf WriteParameters.Property("IBUserDeleted") Then
		Notify("IBUserDeleted", WriteParameters.IBUserDeleted, ThisObject);
		
	ElsIf WriteParameters.Property("MappingToNonExistingIBUserCleared") Then
		
		Notify(
			"MappingToNonExistingIBUserCleared",
			WriteParameters.MappingToNonExistingIBUserCleared, ThisObject);
	EndIf;
	
	If ValueIsFilled(NewExternalUserGroup) Then
		NotifyChanged(NewExternalUserGroup);
		
		Notify(
			"Write_ExternalUsersGroups",
			New Structure,
			NewExternalUserGroup);
		
		NewExternalUserGroup = Undefined;
	EndIf;
	
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
	If WriteParameters.Property("WriteAndClose") Then
		AttachIdleHandler("CloseForm", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	ErrorText = "";
	If UsersInternal.AuthorizationObjectIsInUse(
	         Object.AuthorizationObject, Object.Ref, , , ErrorText) Then
		
		Common.MessageToUser(
			ErrorText, , "Object.AuthorizationObject", , Cancel);
	EndIf;
	
	If CanSignIn
	   And ValueIsFilled(ValidityPeriod)
	   And ValidityPeriod <= BegOfDay(CurrentSessionDate()) Then
		
		Common.MessageToUser(
			NStr("en = 'The expiration date must be tomorrow or later.';"),, "CanSignIn",, Cancel);
	EndIf;
	
	If IBUserWritingRequired(ThisObject) Then
		IBUserDetails = IBUserDetails();
		IBUserDetails.Insert("IBUserID", Object.IBUserID);
		UsersInternal.CheckIBUserDetails(IBUserDetails, Cancel, True);
		
		MessageText = "";
		If UsersInternal.CreateFirstAdministratorRequired(Undefined, MessageText) Then
			Common.MessageToUser(
				MessageText, , "CanSignIn", , Cancel);
		EndIf;
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
					StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Role ""%1"" is unavailable to external users.';"), Item.Synonym),
					"Roles",
					TreeItems.IndexOf(Item),
					StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Role ""%1"" in line %2 is unavailable to external users.';"), Item.Synonym, "%1"));
			EndIf;
		EndDo;
		CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	
	// StandardSubsystems.ContactInformation
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		If ModuleContactsManager.ContainsContactInformation(Object.AuthorizationObject) Then
			AccountNameAuthorizationObject = AccountNameAuthorizationObject(TypeOf(Object.AuthorizationObject));
			AuthorizationObjectObject = FormAttributeToValue(AccountNameAuthorizationObject);
			ModuleContactsManager.FillCheckProcessingAtServer(ThisObject, AuthorizationObjectObject, Cancel);
		EndIf;
	EndIf;
	// End StandardSubsystems.ContactInformation
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("SetUpRoleInterfaceOnLoadSettings", Settings);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AuthorizationObjectOnChange(Item)
	
	AuthorizationObjectOnChangeAtClientAtServer(ThisObject, Object);
	ChangeTheAuthorizationObjectDetails();
	
EndProcedure

&AtClient
Procedure InvalidOnChange(Item)
	
	If Object.Invalid Then
		CanSignIn = False;
		If Not IBUserOpenIDAuthentication
		   And Not InfobaseUserAuthWithOpenIDConnect
		   And Not InfobaseUserAuthWithAccessToken
		   And Not IBUserStandardAuthenticationDirectChangeValue
		   And IBUserStandardAuthentication Then
			
			IBUserStandardAuthentication = False;
		EndIf;
	ElsIf CanSignInDirectChangeValue Then
		If Not IBUserStandardAuthentication
		   And Not IBUserOpenIDAuthentication
		   And Not InfobaseUserAuthWithOpenIDConnect
		   And Not InfobaseUserAuthWithAccessToken Then
			IBUserStandardAuthentication = True;
		EndIf;
		CanSignIn = True;
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure CanSignInOnChange(Item)
	
	If Object.DeletionMark And CanSignIn Then
		CanSignIn = False;
		ShowMessageBox(,
			NStr("en = 'To allow logging in to the application, clear
			           |the deletion mark from the external user.';"));
		Return;
	EndIf;
	
	If Not CanSignIn
	   And Not IBUserOpenIDAuthentication
	   And Not InfobaseUserAuthWithOpenIDConnect
	   And Not InfobaseUserAuthWithAccessToken
	   And Not IBUserStandardAuthenticationDirectChangeValue
	   And IBUserStandardAuthentication Then
		
		IBUserStandardAuthentication = False;
	EndIf;
	
	UpdateUsername(ThisObject);
	
	If CanSignIn
	   And Not IBUserOpenIDAuthentication
	   And Not InfobaseUserAuthWithOpenIDConnect
	   And Not InfobaseUserAuthWithAccessToken
	   And Not IBUserStandardAuthentication Then
	
		IBUserStandardAuthentication = True;
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	
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
Procedure IBUserCannotChangePasswordOnChange(Item)
	
	If IBUserCannotChangePassword Then
		UserMustChangePasswordOnAuthorization = False;
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
Procedure IBUserLanguageOnChange(Item)
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure SetRolesDirectlyOnChange(Item)
	
	If Not Object.SetRolesDirectly Then
		ReadIBUserRoles();
		UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	ProcessRoleInterfaceSetRoleViewOnly();
	
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
	FormParameters = New Structure;
	FormParameters.Insert("ShowExternalUsersSettings", True);
	
	OpenForm("CommonForm.UserAuthorizationSettings", FormParameters, ThisObject);
EndProcedure

// StandardSubsystems.ContactInformation

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
	ModuleContactsManagerClient.StartSelection(ThisObject, Item, , StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationOnClick(Item, StandardProcessing)
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.StartSelection(ThisObject, Item, , StandardProcessing);
EndProcedure

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

// Parameters:
//  Item - FormField
//  ValueSelected - Arbitrary
//  StandardProcessing -Boolean
//
&AtClient
Procedure Attachable_ContactInformationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.ChoiceProcessing(ThisObject, ValueSelected, Item.Name, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.StartURLProcessing(ThisObject, Item, FormattedStringURL, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContinueContactInformationUpdate(Result, AdditionalParameters) Export
	UpdateContactInformation(Result);
EndProcedure

&AtServer
Procedure UpdateContactInformation(Result)
	ModuleContactsManager =
		Common.CommonModule("ContactsManager");
	ModuleContactsManager.UpdateContactInformation(ThisObject, Object, Result);
EndProcedure

// End StandardSubsystems.ContactInformation

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

////////////////////////////////////////////////////////////////////////////////
// Support of additional attributes.

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, Var_URL = Undefined, StandardProcessing = Undefined)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
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
Procedure CreateAuthorizationObjectAccountDetails()
	
	ValueOfTheAuthorizationObject = AuthorizationObject("AuthorizationObject");
	
	If ValueOfTheAuthorizationObject = Undefined Then
		Return;
	EndIf;
	
	CurrentTypeAuthorizationObject = TypeOf(ValueOfTheAuthorizationObject);
	
	AccountNameAuthorizationObject = AccountNameAuthorizationObject(CurrentTypeAuthorizationObject);
	
	DescriptionOfTheTypeOnTheForm = Undefined;
	FormAttributes = GetAttributes();
	For Each FormAttribute In FormAttributes Do
		If FormAttribute.Name = AccountNameAuthorizationObject Then
			DescriptionOfTheTypeOnTheForm = FormAttribute.ValueType.Types()[0];
			Break;
		EndIf;
	EndDo;
	
	If CurrentTypeAuthorizationObject <> DescriptionOfTheTypeOnTheForm Then
		
		AttributesToBeAdded = New Array;
		
		TypesArray = New Array;
		TypesArray.Add(CurrentTypeAuthorizationObject);
		
		TypeDetails = New TypeDescription(TypesArray);
		AttributesToBeAdded.Add(New FormAttribute(AccountNameAuthorizationObject, TypeDetails));
		ChangeAttributes(AttributesToBeAdded);
	EndIf;
	
	ValueToFormAttribute(ValueOfTheAuthorizationObject, AccountNameAuthorizationObject);
	
EndProcedure

&AtServer
Function AuthorizationObject(AccountNameAuthorizationObject)
	
	If TypeOf(Object[AccountNameAuthorizationObject])= Type("String")
		Or Not ValueIsFilled(Object[AccountNameAuthorizationObject]) Then
		Return Undefined;
	EndIf;
	
	ValueOfTheAuthorizationObject = Object[AccountNameAuthorizationObject].GetObject();
	
	Return ValueOfTheAuthorizationObject;
	
EndFunction

&AtServerNoContext
Function AccountNameAuthorizationObject(TypeAuthorizationObject)
	Prefix = Metadata.FindByType(TypeAuthorizationObject).Name;
	Return "ExternalUserAuthorizationObject" + Prefix;
EndFunction

&AtServer
Procedure ChangeTheAuthorizationObjectDetails()
	
	// StandardSubsystems.ContactInformation
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		CreateAuthorizationObjectAccountDetails();
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		
		If Not ValueIsFilled(Object.AuthorizationObject) 
			Or Not ModuleContactsManager.ContainsContactInformation(Object.AuthorizationObject) Then
				Return;
		EndIf;
		
		AccountNameAuthorizationObject = AccountNameAuthorizationObject(TypeOf(Object.AuthorizationObject));
		
		If Items.ContactInformationGroup.ChildItems.Count() = 0 Then
			
			If ModuleContactsManager.ContainsContactInformation(Object.AuthorizationObject) Then
				ModuleContactsManager.OnCreateAtServer(ThisObject, ThisObject[AccountNameAuthorizationObject]);
			EndIf;
			
		Else
			
			ModuleContactsManager.OnReadAtServer(ThisObject, ThisObject[AccountNameAuthorizationObject]);
			
		EndIf;
		
		PasswordToConfirmEmailChange  = Undefined;
		If Users.IsFullUser() Then
			
			If Not UsersInternal.InteractivelyPromptForAPassword(AccessLevel, Object) Then
				PasswordToConfirmEmailChange = "";
			EndIf;
			
			AttributeWithEmailForPasswordRecoveryName = ModuleContactsManager.DefineAnItemWithMailForPasswordRecovery(
			ThisObject, 
			IBUserEmailAddress,
			UsersInternal.YouCanEditYourEmailToRestoreYourPassword(AccessLevel, Object),
			True);
			
			Items.ContactInformationGroup.Enabled = True;
			
		Else
			
			Items.ContactInformationGroup.Enabled = False;
			
		EndIf;
			
		
	EndIf;
	// End StandardSubsystems.ContactInformation
	
EndProcedure

&AtServer
Procedure ProcessRoleInterfaceSetRoleViewOnly(CurrentObject = Undefined)
	
	If CurrentObject = Undefined Then
		CurrentObject = Object;
	EndIf;
	
	ProcessRolesInterface("SetRolesReadOnly",
		    CannotEditRoles
		Or ActionsOnForm.Roles <> "Edit"
		Or Not AccessLevel.AuthorizationSettings2
		Or Not CurrentObject.SetRolesDirectly);
	
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
	
	CreateAuthorizationObjectAccountDetails();
	
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
	
	ProcessRoleInterfaceSetRoleViewOnly(CurrentObject);
	
	// Making the properties always visible.
	Items.IBUserProperies.Visible =
		ValueIsFilled(ActionsOnForm.IBUserProperies);
	
	Items.GroupName.Visible =
		ValueIsFilled(ActionsOnForm.IBUserProperies);
	
	Items.RolesRepresentation.Visible =
		ValueIsFilled(ActionsOnForm.Roles);
	
	Items.SetRolesDirectly.Visible =
		ValueIsFilled(ActionsOnForm.Roles) And Not UsersInternal.CannotEditRoles();
	
	UpdateDisplayedUserType();
	
	ReadOnly = ReadOnly
		Or ActionsOnForm.Roles                   <> "Edit"
		  And ActionsOnForm.ItemProperties       <> "Edit"
		  And ActionsOnForm.IBUserProperies <> "Edit";
	
	
	ButtonAvailability = Not ReadOnly And AccessRight("Edit",
		Metadata.Catalogs.ExternalUsers);
	
	If Items.FormWriteAndClose.Enabled <> ButtonAvailability Then
		Items.FormWriteAndClose.Enabled = ButtonAvailability;
	EndIf;
	
	If Items.ChangeAuthorizationRestriction.Enabled <> ButtonAvailability Then
		Items.ChangeAuthorizationRestriction.Enabled = ButtonAvailability;
	EndIf;
	
	If Items.ChangePassword.Enabled <> ButtonAvailability Then
		Items.ChangePassword.Enabled = ButtonAvailability;
	EndIf;
	
	Items.CheckAuthorizationSettingsRecommendation.Visible =
		  AccessLevel.ChangeAuthorizationPermission
		And CurrentObject.Prepared
		And Not CanSignInOnRead;
	
	SetPropertiesAvailability(ThisObject);
	
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
	
	ShortName = UsersInternalClientServer.GetIBUserShortName(
		Form.CurrentAuthorizationObjectPresentation);
	
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
	   And Not InfobaseUserAuthWithAccessToken Then
	
		CanSignIn = False;
		
	ElsIf Not CanSignIn Then
		CanSignIn = CanSignInDirectChangeValue;
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	
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
	ActionsOnForm.Insert("IBUserProperies", "");
	
	// "", "View," "Edit."
	ActionsOnForm.Insert("ItemProperties", "View");
	
	If AccessLevel.ChangeCurrent Or AccessLevel.ListManagement Then
		ActionsOnForm.IBUserProperies = "Edit";
	EndIf;
	
	If AccessLevel.ListManagement Then
		ActionsOnForm.ItemProperties = "Edit";
	EndIf;
	
	If AccessLevel.FullAccess Then
		ActionsOnForm.Roles = "Edit";
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
	   And Not ValueIsFilled(Object.AuthorizationObject) Then
		
		ActionsOnForm.ItemProperties = "Edit";
	EndIf;
	
	UsersInternal.OnDefineActionsInForm(Object.Ref, ActionsOnForm);
	
	// Checking action names in the form.
	If StrFind(", View, Edit,", ", " + ActionsOnForm.Roles + ",") = 0 Then
		ActionsOnForm.Roles = "";
		
	ElsIf ActionsOnForm.Roles = "Edit"
	        And UsersInternal.CannotEditRoles() Then
		
		ActionsOnForm.Roles = "View";
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
	
EndProcedure

&AtServer
Function IBUserDetails()
	
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
			Result.Insert("Password", IBUserPassword);
			Result.Insert("Language",   IBUserLanguage);
		EndIf;
		
		If AccessLevel.ListManagement Then
			Result.Insert("CanSignIn",  CanSignIn);
			Result.Insert("CannotChangePassword", IBUserCannotChangePassword);
			Result.Insert("Language",                    IBUserLanguage);
			Result.Insert("FullName",               IBUserFullName);
		EndIf;
		
		If AccessLevel.AuthorizationSettings2 Then
			Result.Insert("StandardAuthentication",    IBUserStandardAuthentication);
			Result.Insert("Password",                       IBUserPassword);
			Result.Insert("Name",                          IBUserName);
			Result.Insert("OpenIDAuthentication",         IBUserOpenIDAuthentication);
			Result.Insert("OpenIDConnectAuthentication",  InfobaseUserAuthWithOpenIDConnect);
			Result.Insert("AccessTokenAuthentication", InfobaseUserAuthWithAccessToken);
		EndIf;
	EndIf;
	
	If AccessLevel.AuthorizationSettings2
	   And Not UsersInternal.CannotEditRoles()
	   And Object.SetRolesDirectly Then
		
		CurrentRoles = IBUserRoles.Unload(, "Role").UnloadColumn("Role");
		Result.Insert("Roles", CurrentRoles);
	EndIf;
	
	If AccessLevel.ListManagement Then
		Result.Insert("ShowInList", False);
		Result.Insert("RunMode", "Auto");
	EndIf;
	
	If AccessLevel.FullAccess Then
		Result.Insert("OSAuthentication", False);
		Result.Insert("OSUser", "");
	EndIf;
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Procedure AuthorizationObjectOnChangeAtClientAtServer(Form, Object)
	
	If Object.AuthorizationObject = Undefined Then
		Object.AuthorizationObject = Form.AuthorizationObjectsType;
	EndIf;
	
	If Form.CurrentAuthorizationObjectPresentation <> String(Object.AuthorizationObject) Then
		Form.CurrentAuthorizationObjectPresentation = String(Object.AuthorizationObject);
		UpdateUsername(Form, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateDisplayedUserType()
	
	If Common.IsReference(TypeOf(Object.AuthorizationObject)) Then
		Items.AuthorizationObject.Title = Metadata.FindByType(TypeOf(Object.AuthorizationObject)).ObjectPresentation;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAnswerToQuestionAboutWritingWithEmptyRoleList(Response, WriteParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		WriteParameters.Insert("WithEmptyRoleList");
		Write(WriteParameters);
	EndIf;
	
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
Procedure CloseForm()
	
	Close();
	
EndProcedure

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

// The BeforeWrite event handler continuation.
&AtClient
Procedure AfterRequestingAPasswordToChangeTheMail(Result, AdditionalParameters) Export
	
	If TypeOf(Result) = Type("String") Then
		PasswordToConfirmEmailChange = Result;
		Write(AdditionalParameters.WriteParameters);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Processes an infobase user.

&AtServer
Procedure ReadIBUserRoles()
	
	IBUserProperies = Users.IBUserProperies(Object.IBUserID);
	If IBUserProperies = Undefined Then
		IBUserProperies = Users.NewIBUserDetails(False);
	EndIf;
	ProcessRolesInterface("FillRoles", IBUserProperies.Roles);
	
EndProcedure

&AtServer
Function InitialIBUserDetails()
	
	If InitialIBUserDetails <> Undefined Then
		InitialIBUserDetails.Roles = New Array;
		Return InitialIBUserDetails;
	EndIf;
	
	IBUserDetails = Users.NewIBUserDetails(False);
	IBUserDetails.ShowInList = False;
	IBUserDetails.Roles = New Array;
	
	Return IBUserDetails;
	
EndFunction

&AtServer
Procedure ReadIBUser(OnCopyItem = False, OnCreateAtServer = True)
	
	SetPrivilegedMode(True);
	
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
					ReadProperties.FullName = Object.Description;
					Modified = True;
				EndIf;
				If ReadProperties.OSAuthentication Then
					ReadProperties.OSAuthentication = False;
					Modified = True;
				EndIf;
				If ValueIsFilled(ReadProperties.OSUser) Then
					ReadProperties.OSUser = "";
					Modified = True;
				EndIf;
			EndIf;
		EndIf;
		
		If IBUserExists Then
			
			If Not Items.IBUserLanguage.Visible Then
				ReadProperties.Language = IBUserDetails.Language;
			EndIf;
			
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
		|Roles",
		UsersInternal.PrefixedNamesForInfobaseUserProperties());
	
	If IBUserMain And Not CanSignIn Then
		StoredProperties = UsersInternal.StoredIBUserProperties(Object.Ref);
		IBUserStandardAuthentication    = StoredProperties.StandardAuthentication;
		IBUserOpenIDAuthentication         = StoredProperties.OpenIDAuthentication;
		InfobaseUserAuthWithOpenIDConnect  = StoredProperties.OpenIDConnectAuthentication;
		InfobaseUserAuthWithAccessToken = StoredProperties.AccessTokenAuthentication;
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
	
	// Check if the infobase user's "FullName" property value matches
	// the external user's "Description" attribute (and the default property values).
	
	ShowDifference = True;
	ShowDifferenceResolvingCommands = False;
	
	If Not IBUserExists Then
		ShowDifference = False;
		
	ElsIf Not ValueIsFilled(Object.Ref) Then
		IBUserFullName = Object.Description;
		ShowDifference = False;
		
	ElsIf AccessLevel.ListManagement Then
		
		PropertiesToResolve = New Array;
		HasDifferencesResolvableWithoutAdministrator = False;
		
		If IBUserOSAuthentication <> False Then
			PropertiesToResolve.Add(NStr("en = 'OS authentication (enabled)';"));
		EndIf;
		
		If CanSignInOnRead And Object.Invalid Then
			CanSignIn = False;
			PropertiesToResolve.Insert(0, NStr("en = 'Login allowed';"));
		EndIf;
		
		If ValueIsFilled(PropertiesToResolve) Then
			ShowDifferenceResolvingCommands =
				  AccessLevel.AuthorizationSettings2
				And ActionsOnForm.IBUserProperies = "Edit";
		EndIf;
		
		If IBUserFullName <> Object.Description Then
			HasDifferencesResolvableWithoutAdministrator = True;
			
			PropertiesToResolve.Insert(0, StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Full name: ""%1""';"),
				IBUserFullName));
		EndIf;
		
		If IBUserOSUser <> "" Then
			PropertiesToResolve.Add(NStr("en = 'OS user (specified)';"));
		EndIf;
		
		If IBUserShowInList Then
			HasDifferencesResolvableWithoutAdministrator = True;
			PropertiesToResolve.Add(NStr("en = 'Show in choice list (enabled)';"));
		EndIf;
		
		If IBUserRunMode <> "Auto" Then
			HasDifferencesResolvableWithoutAdministrator = True;
			PropertiesToResolve.Add(NStr("en = 'Run mode (not Auto)';"));
		EndIf;
		
		SetPrivilegedMode(True);
		AreSavedInfobaseUserPropertiesMismatch = ValueIsFilled(Object.Ref)
			And InformationRegisters.UsersInfo.AreSavedInfobaseUserPropertiesMismatch(Object);
		SetPrivilegedMode(False);
		
		HasDifferencesResolvableWithoutAdministrator =
			HasDifferencesResolvableWithoutAdministrator
			Or AreSavedInfobaseUserPropertiesMismatch;
		
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
			If ShowDifferenceResolvingCommands
			 Or HasDifferencesResolvableWithoutAdministrator
			   And ActionsOnForm.ItemProperties = "Edit" Then
				
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
					|" + NStr("en = 'The picture in the list of external users and authorization objects might display an outdated state
					                |as some other saved properties also differ.';"));
			Else
				MismatchClarification =
					NStr("en = 'The picture in the list of external users and authorization objects might display an outdated state
					           |as some infobase user properties differ from the saved ones.';");
			EndIf;
			Items.PropertiesMismatchNote.Title = MismatchClarification + Recommendation;
		Else
			ShowDifference = False;
		EndIf;
	Else
		ShowDifference = False;
	EndIf;
	
	Items.PropertiesMismatchProcessing.Visible = ShowDifference;
	Items.PropertiesMismatchNote.VerticalAlign = ?(ValueIsFilled(Recommendation),
		ItemVerticalAlign.Top, ItemVerticalAlign.Center);
	
	// Checking the mapping of a nonexistent infobase user to a catalog user.
	HasNewMappingToNonExistingIBUser =
		Not IBUserExists And ValueIsFilled(Object.IBUserID);
	
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

////////////////////////////////////////////////////////////////////////////////
// Initial filling, fill checks, and availability of properties.

&AtClientAtServerNoContext
Procedure SetPropertiesAvailability(Form)
	
	Items       = Form.Items;
	Object         = Form.Object;
	ActionsOnForm = Form.ActionsOnForm;
	AccessLevel = Form.AccessLevel;
	
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
	Items.AuthorizationObject.ReadOnly
		=   ActionsOnForm.ItemProperties <> "Edit"
		Or Form.AuthorizationObjectSetOnOpen
		Or   ValueIsFilled(Object.Ref)
		    And ValueIsFilled(Object.AuthorizationObject);
	
	Items.Invalid.ReadOnly =
		Not (ActionsOnForm.ItemProperties = "Edit" And AccessLevel.ListManagement);
	
	Items.IBUserProperies.ReadOnly =
		Not (  ActionsOnForm.IBUserProperies = "Edit"
		    And (AccessLevel.ListManagement Or AccessLevel.ChangeCurrent));
	Items.GroupName.ReadOnly = Items.IBUserProperies.ReadOnly;
	
	Items.CanSignIn.ReadOnly =
		Not (  Items.IBUserProperies.ReadOnly = False
		    And (    AccessLevel.ChangeAuthorizationPermission
		       Or AccessLevel.DisableAuthorizationApproval And Form.CanSignInOnRead));
	
	Items.IBUserName.ReadOnly                          = Not AccessLevel.AuthorizationSettings2;
	Items.IBUserStandardAuthentication.ReadOnly    = Not AccessLevel.AuthorizationSettings2;
	Items.IBUserOpenIDAuthentication.ReadOnly         = Not AccessLevel.AuthorizationSettings2;
	Items.InfobaseUserAuthWithOpenIDConnect.ReadOnly  = Not AccessLevel.AuthorizationSettings2;
	Items.InfobaseUserAuthWithAccessToken.ReadOnly = Not AccessLevel.AuthorizationSettings2;
	Items.SetRolesDirectly.ReadOnly              = Not AccessLevel.AuthorizationSettings2;
	
	Items.UserMustChangePasswordOnAuthorization.ReadOnly               = Not AccessLevel.ListManagement;
	Items.IBUserCannotChangePassword.ReadOnly        = Not AccessLevel.ListManagement;
	Items.IBUserCannotRecoveryPassword.ReadOnly = Not AccessLevel.ListManagement;
	
	Items.IBUserCannotRecoveryPassword.Enabled    = Not Form.IBUserCannotChangePassword;
	
	Items.ChangePassword.Enabled =
		(    AccessLevel.AuthorizationSettings2
		 Or AccessLevel.ChangeCurrent
		   And Not Form.IBUserCannotChangePassword);
	
	Items.Comment.ReadOnly =
		Not (ActionsOnForm.ItemProperties = "Edit" And AccessLevel.ListManagement);
	
	UpdateUsername(Form);
	
	// Setting availability of related items.
	Items.CanSignIn.Enabled         = Not Object.Invalid;
	Items.IBUserProperies.Enabled         = Not Object.Invalid;
	Items.GroupName.Enabled                      = Not Object.Invalid;
	Items.EditOrViewRoles.Enabled = Not Object.Invalid;
	Items.ChangeRestrictionGroup.Enabled      = Not Object.Invalid
	                                                    And Not Items.Invalid.ReadOnly;
	
	Items.OneCEnterpriseAuthenticationParameters.Enabled =
		Form.IBUserStandardAuthentication;
	
	UsersInternalClientServer.UpdateLifetimeRestriction(Form);
	
EndProcedure

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
			Form.CurrentAuthorizationObjectPresentation);
		
		If Form.IBUserName = ShortName Then
			CurrentName = ShortName;
		EndIf;
	EndIf;
	
	If Form.IBUserExists
	 Or Form.CanSignIn
	 Or Form.IBUserName                          <> CurrentName
	 Or Form.IBUserStandardAuthentication    <> Template.StandardAuthentication
	 Or Form.IBUserCannotChangePassword      <> Template.CannotChangePassword
	 Or Form.IBUserPassword                       <> Undefined
	 Or Form.IBUserOpenIDAuthentication         <> Template.OpenIDAuthentication
	 Or Form.InfobaseUserAuthWithOpenIDConnect  <> Template.OpenIDConnectAuthentication
	 Or Form.InfobaseUserAuthWithAccessToken <> Template.AccessTokenAuthentication
	 Or Form.IBUserLanguage                         <> Template.Language
	 Or Form.IBUserRoles.Count()            <> 0 Then
		
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
	ActionParameters.Insert("RolesAssignment",  "ForExternalUsers");
	
	UsersInternal.ProcessRolesInterface(Action, ActionParameters);
	
EndProcedure

#EndRegion