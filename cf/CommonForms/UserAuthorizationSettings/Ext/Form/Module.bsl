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

&AtServer
Var CurrentSettingsByItems, CurrentItemsBySettings;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ShowExternalUsersSettings = Parameters.ShowExternalUsersSettings;
	UseExternalUsers = ExternalUsers.UseExternalUsers();
	
	RecommendedSettingsValues = New Structure;
	RecommendedSettingsValues.Insert("PasswordMustMeetComplexityRequirements", Null);
	RecommendedSettingsValues.Insert("MinPasswordLength", 8);
	RecommendedSettingsValues.Insert("ShouldBeExcludedFromBannedPasswordList", Null);
	RecommendedSettingsValues.Insert("ActionUponLoginIfRequirementNotMet", "SuggestPasswordChange");
	RecommendedSettingsValues.Insert("MaxPasswordLifetime", 30);
	RecommendedSettingsValues.Insert("MinPasswordLifetime", 1);
	RecommendedSettingsValues.Insert("DenyReusingRecentPasswords", 10);
	RecommendedSettingsValues.Insert("WarnAboutPasswordExpiration", 5);
	RecommendedSettingsValues.Insert("InactivityPeriodBeforeDenyingAuthorization", 45);
	
	RecommendedCommonSettingsValues = New Structure;
	RecommendedCommonSettingsValues.Insert("AreSeparateSettingsForExternalUsers", Null);
	RecommendedCommonSettingsValues.Insert("NotificationLeadTimeBeforeAccessExpire", 7);
	RecommendedCommonSettingsValues.Insert("PasswordSaveOptionUponLogin", "AllowedAndDisabled");
	RecommendedCommonSettingsValues.Insert("PasswordRemembranceDuration",
		SuggestedValue(600, True, "PasswordSaveOptionUponLogin", True));
	RecommendedCommonSettingsValues.Insert("InactivityTimeoutBeforeTerminateSession", 960);
	RecommendedCommonSettingsValues.Insert("NotificationLeadTimeBeforeTerminateInactiveSession", 5);
	RecommendedCommonSettingsValues.Insert("PasswordAttemptsCountBeforeLockout", 3);
	RecommendedCommonSettingsValues.Insert("PasswordLockoutDuration",
		SuggestedValue(5, True, "PasswordAttemptsCountBeforeLockout", True));
	RecommendedCommonSettingsValues.Insert("ShowInList", Null);
	RecommendedCommonSettingsValues.Insert("ShouldUseStandardBannedPasswordList", Null);
	RecommendedCommonSettingsValues.Insert("ShouldUseAdditionalBannedPasswordList", Null);
	RecommendedCommonSettingsValues.Insert("ShouldUseBannedPasswordService", Null);
	RecommendedCommonSettingsValues.Insert("BannedPasswordServiceAddress", Null);
	RecommendedCommonSettingsValues.Insert("BannedPasswordServiceMaxTimeout", Null);
	RecommendedCommonSettingsValues.Insert("ShouldSkipValidationIfBannedPasswordServiceOffline", Null);
	
	LogonSettings = UsersInternal.LogonSettings();
	If Common.DataSeparationEnabled() Then
		Items.GroupWarnAboutPasswordExpiration.Visible = False;
		Items.GroupWarnAboutPasswordExpiration2.Visible = False;
	EndIf;
	
	FillMapOfSettingAndItemNames();
	
	FillSettingsInForm(LogonSettings.Overall, RecommendedCommonSettingsValues);
	FillSettingsInForm(LogonSettings.Users, RecommendedSettingsValues);
	FillSettingsInForm(LogonSettings.ExternalUsers, RecommendedSettingsValues, True);
	
	If UseExternalUsers Then
		UpdateExternalUsersSettingsAvailability(ThisObject);
		If ShowExternalUsersSettings Then
			Items.Pages.CurrentPage = Items.ForExternalUsers;
		EndIf;
	Else
		Items.AreSeparateSettingsForExternalUsers.Visible = False;
		AreSeparateSettingsForExternalUsers = False;
		UpdateExternalUsersSettingsAvailability(ThisObject);
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Items.WarningConfigurationInService.Visible = True;
		Items.FormWriteAndClose.Enabled = False;
		Items.Pages.ReadOnly = True;
		Items.NoteShowInListDataSeparationEnabled.Visible = True;
		Items.ShowInList.Enabled = False;
		Items.ShowBannedPasswordList.Enabled = False;
		Items.ClearBannedPasswordList.Enabled = False;
		Items.ImportBannedPasswordList.Enabled = False;
		
	ElsIf UseExternalUsers Then
		Items.NoteShowInListExternalUsers.Visible = True;
		Items.ShowInList.Enabled = False;
	EndIf;
	
	If Common.FileInfobase() Then
		Items.GroupPasswordAttemptsCountBeforeLockout.Visible = False;
		Items.GroupPasswordLockoutDuration.Visible = False;
	EndIf;
	
	If Not UsersInternal.IsSettings8_3_26Available() Then
		Items.ShouldBeExcludedFromBannedPasswordList.Visible = False;
		Items.ActionUponLoginIfRequirementNotMetEnable.Visible = False;
		Items.GroupActionUponLoginIfRequirementNotMet.Visible = False;
		Items.ShouldBeExcludedFromBannedPasswordList2.Visible = False;
		Items.ActionUponLoginIfRequirementNotMet2Enable.Visible = False;
		Items.GroupActionUponLoginIfRequirementNotMet2.Visible = False;
		Items.GroupInactivityTimeoutBeforeTerminateSession.Visible = False;
		Items.GroupNotificationLeadTimeBeforeTerminateInactiveSession.Visible = False;
		Items.GroupPasswordSaveOptionUponLogin.Visible = False;
		Items.GroupPasswordRemembranceDuration.Visible = False;
		Items.BannedPasswords.Visible = False;
	EndIf;
	
	Items.ImportBannedPasswordListExtendedTooltip.Title =
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Import a banned password list from a text file encoded with %1 with specification (with %2). Each password should be specified on a separate line.
			           |You can specify either a password or its %3 hash in the %4 format.';"),
			"UTF-8", "BOM", "sha1", "base64");
	
	UpdateAvailabilityOfBannedPasswordServiceSettings(ThisObject);
	RecountPasswordsInAdditionalBannedList();
	
	StandardSubsystemsServer.ResetWindowLocationAndSize(ThisObject);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If ShouldUseBannedPasswordService
	   And Not ValueIsFilled(BannedPasswordServiceAddress) Then
		
		Common.MessageToUser(
			NStr("en = 'Service address required';"),, "BannedPasswordServiceAddress",, Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AreSeparateSettingsForExternalUsersOnChange(Item)
	
	UpdateExternalUsersSettingsAvailability(ThisObject, True);
	
EndProcedure

&AtClient
Procedure PasswordMustMeetComplexityRequirementsOnChange(Item)
	
	If MinPasswordLength < 7 Then
		MinPasswordLength = 7;
	EndIf;
	If MinPasswordLength2 < 7 Then
		MinPasswordLength2 = 7;
	EndIf;
	
EndProcedure

&AtClient
Procedure MinPasswordLengthOnChange(Item)
	
	If MinPasswordLength < 7
	  And PasswordMustMeetComplexityRequirements Then
		
		MinPasswordLength = 7;
	EndIf;
	
	If MinPasswordLength2 < 7
	  And PasswordMustMeetComplexityRequirements2 Then
		
		MinPasswordLength2 = 7;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingEnableOnChange(Item)
	
	Names = SettingsByItems.Get(Item.Name);
	
	If ThisObject[Item.Name] = False Then
		SuggestedValue = SuggestedValue(RecommendedSettingsValues[Names.SettingName]);
		ThisObject[Names.SettingNameOnForm] = SuggestedValue.Value;
	EndIf;
	
	Items[Names.TagName].Enabled = ThisObject[Item.Name];
	
EndProcedure

&AtClient
Procedure CommonSettingEnableOnChange(Item, EnableSynchronously = True)
	
	Names = SettingsByItems.Get(Item.Name);
	
	If ThisObject[Item.Name] = False Then
		SuggestedValue = SuggestedValue(RecommendedCommonSettingsValues[Names.SettingName]);
		ThisObject[Names.SettingNameOnForm] = SuggestedValue.Value;
	EndIf;
	
	Items[Names.TagName].Enabled = ThisObject[Item.Name];
	
	If Not EnableSynchronously Then
		Return;
	EndIf;
	
	EnableSynchronously(Item,
		Items.ShouldTerminateSessionAfterInactivityTimeout.Name,
		Items.ShouldNotifyUserBeforeTerminateInactiveSession.Name);
	
	EnableSynchronously(Item,
		Items.PasswordAttemptsCountBeforeLockoutEnable.Name,
		Items.PasswordLockoutDurationEnable.Name);
	
	EnableSynchronously(Item,
		Items.CanSavePasswordUponLogin.Name,
		Items.ShouldTemporarilyRememberPassword.Name);
	
EndProcedure

&AtClient
Procedure SettingValueOnChange(Item, Value = 1)
	
	If ThisObject[Item.Name] < Value Then
		ThisObject[Item.Name] = Value;
	EndIf;
	
EndProcedure

&AtClient
Procedure InactivityTimeoutBeforeTerminateSessionOnChange(Item)
	
	SettingValueOnChange(Item, 2);
	
	If NotificationLeadTimeBeforeTerminateInactiveSession > InactivityTimeoutBeforeTerminateSession - 1 Then
		NotificationLeadTimeBeforeTerminateInactiveSession = InactivityTimeoutBeforeTerminateSession - 1;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationLeadTimeBeforeTerminateInactiveSessionOnChange(Item)
	
	SettingValueOnChange(Item);
	
	If InactivityTimeoutBeforeTerminateSession < NotificationLeadTimeBeforeTerminateInactiveSession + 1 Then
		InactivityTimeoutBeforeTerminateSession = NotificationLeadTimeBeforeTerminateInactiveSession + 1;
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowInListClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ShowInListChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ShowInList = ValueSelected
	 Or ValueSelected = "EnabledForNewUsers"
	 Or ValueSelected = "DisabledForNewUsers" Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	Notification = New NotifyDescription("ShowInListChoiceProcessingCompletion",
		ThisObject, ValueSelected);
	
	If ValueSelected = "HiddenAndEnabledForAllUsers" Then
		QueryText =
			NStr("en = 'When you start the application, the user choice list will become full.
			           |The Show in list attribute in cards
			           | of all users will be enabled and hidden.';");
	Else
		QueryText =
			NStr("en = 'The user list in the startup dialog will be cleared
			           |(attribute ""Show in choice list"" will be cleared and hidden from all user profiles).
			           |';");
	EndIf;
	
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure ShouldUseBannedPasswordServiceOnChange(Item)
	
	UpdateAvailabilityOfBannedPasswordServiceSettings(ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	WriteAtServer();
	Notify("Write_ConstantsSet", New Structure, "UserAuthorizationSettings");
	Close();
	
EndProcedure

&AtClient
Procedure ShowBannedPasswordList(Command)
	
	If ValueIsFilled(NewPasswordListAddressInTempStorage) Then
		Text = ImportedBannedPasswordList(NewPasswordListAddressInTempStorage);
		If IsNewListContainsPasswords Then
			DocumentTitle = NStr("en = 'Banned passwords (imported)';");
		Else
			DocumentTitle = NStr("en = 'Banned password hashes (imported)';");
		EndIf;
	Else
		Text = CurrentBannedPasswordHashList();
		DocumentTitle = NStr("en = 'Banned password hashes';");
	EndIf;
	
	TextDocument = New TextDocument;
	TextDocument.SetText(Text);
	TextDocument.Show(DocumentTitle);
	
EndProcedure

&AtClient
Procedure ClearBannedPasswordList(Command)
	
	RecountPasswordsInAdditionalBannedList(True);
	
EndProcedure

&AtClient
Procedure ImportBannedPasswordList(Command)
	
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.FormIdentifier = UUID;
	ImportParameters.Dialog.Filter = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Text file: %1 with specification (with %2)';"), "UTF-8", "BOM") + "|*.txt";
	
	Notification = New NotifyDescription("AfterFileImported", ThisObject);
	FileSystemClient.ImportFile_(Notification, ImportParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillMapOfSettingAndItemNames()
	
	CurrentSettingsByItems = New Map;
	CurrentItemsBySettings = New Map;
	
	AddNames(Items.PasswordMustMeetComplexityRequirements2.Name,
		Items.PasswordMustMeetComplexityRequirements2.Name,
		"PasswordMustMeetComplexityRequirements",
		"PasswordMustMeetComplexityRequirements2");
	
	AddNames(Items.MinPasswordLengthEnable.Name,
		Items.MinPasswordLength.Name,
		"MinPasswordLength");
	
	AddNames(Items.MinPasswordLength2Enable.Name,
		Items.MinPasswordLength2.Name,
		"MinPasswordLength",
		"MinPasswordLength2");
	
	AddNames(Items.ActionUponLoginIfRequirementNotMetEnable.Name,
		Items.ActionUponLoginIfRequirementNotMet.Name,
		"ActionUponLoginIfRequirementNotMet");
	
	AddNames(Items.ActionUponLoginIfRequirementNotMet2Enable.Name,
		Items.ActionUponLoginIfRequirementNotMet2.Name,
		"ActionUponLoginIfRequirementNotMet",
		"ActionUponLoginIfRequirementNotMet2");
	
	AddNames(Items.MaxPasswordLifetimeEnable.Name,
		Items.MaxPasswordLifetime.Name,
		"MaxPasswordLifetime");
	
	AddNames(Items.MaxPasswordLifetime2Enable.Name,
		Items.MaxPasswordLifetime2.Name,
		"MaxPasswordLifetime",
		"MaxPasswordLifetime2");
	
	AddNames(Items.MinPasswordLifetimeEnable.Name,
		Items.MinPasswordLifetime.Name,
		"MinPasswordLifetime");
	
	AddNames(Items.MinPasswordLifetime2Enable.Name,
		Items.MinPasswordLifetime2.Name,
		"MinPasswordLifetime",
		"MinPasswordLifetime2");
	
	AddNames(Items.DenyReusingRecentPasswordsEnable.Name,
		Items.DenyReusingRecentPasswords.Name,
		"DenyReusingRecentPasswords");
	
	AddNames(Items.DenyReusingRecentPasswords2Enable.Name,
		Items.DenyReusingRecentPasswords2.Name,
		"DenyReusingRecentPasswords",
		"DenyReusingRecentPasswords2");
	
	AddNames(Items.WarnAboutPasswordExpirationEnable.Name,
		Items.WarnAboutPasswordExpiration.Name,
		"WarnAboutPasswordExpiration");
	
	AddNames(Items.WarnAboutPasswordExpiration2Enable.Name,
		Items.WarnAboutPasswordExpiration2.Name,
		"WarnAboutPasswordExpiration",
		"WarnAboutPasswordExpiration2");
	
	AddNames(Items.InactivityPeriodBeforeDenyingAuthorizationEnable.Name,
		Items.InactivityPeriodBeforeDenyingAuthorization.Name,
		"InactivityPeriodBeforeDenyingAuthorization");
	
	AddNames(Items.InactivityPeriodBeforeDenyingAuthorization2Enable.Name,
		Items.InactivityPeriodBeforeDenyingAuthorization2.Name,
		"InactivityPeriodBeforeDenyingAuthorization",
		"InactivityPeriodBeforeDenyingAuthorization2");
	
	AddNames(Items.ShouldNotifyUserBeforeAccessExpire.Name,
		Items.NotificationLeadTimeBeforeAccessExpire.Name,
		"NotificationLeadTimeBeforeAccessExpire");
	
	AddNames(Items.ShouldTerminateSessionAfterInactivityTimeout.Name,
		Items.InactivityTimeoutBeforeTerminateSession.Name,
		"InactivityTimeoutBeforeTerminateSession");
	
	AddNames(Items.ShouldNotifyUserBeforeTerminateInactiveSession.Name,
		Items.NotificationLeadTimeBeforeTerminateInactiveSession.Name,
		"NotificationLeadTimeBeforeTerminateInactiveSession");
	
	AddNames(Items.PasswordAttemptsCountBeforeLockoutEnable.Name,
		Items.PasswordAttemptsCountBeforeLockout.Name,
		"PasswordAttemptsCountBeforeLockout");
	
	AddNames(Items.PasswordLockoutDurationEnable.Name,
		Items.PasswordLockoutDuration.Name,
		"PasswordLockoutDuration");
	
	AddNames(Items.CanSavePasswordUponLogin.Name,
		Items.PasswordSaveOptionUponLogin.Name,
		"PasswordSaveOptionUponLogin");
	
	AddNames(Items.ShouldTemporarilyRememberPassword.Name,
		Items.PasswordRemembranceDuration.Name,
		"PasswordRemembranceDuration");
	
	SettingsByItems = New FixedMap(CurrentSettingsByItems);
	ItemsBySettings = New FixedMap(CurrentItemsBySettings);
	
EndProcedure

&AtServer
Procedure AddNames(ItemNameInclude, TagName, SettingName, SettingNameOnForm = Undefined)
	
	Properties = New Structure;
	Properties.Insert("TagName", TagName);
	Properties.Insert("SettingName", SettingName);
	Properties.Insert("SettingNameOnForm", SettingNameOnForm);
	
	If SettingNameOnForm = Undefined Then
		Properties.SettingNameOnForm = SettingName;
	EndIf;
	
	CurrentSettingsByItems.Insert(ItemNameInclude, New FixedStructure(Properties));
	
	NamesKey = ?(SettingNameOnForm = Undefined, SettingName, SettingName + "2");
	Properties.Delete("SettingName");
	Properties.Insert("ItemNameInclude", ItemNameInclude);
	
	CurrentItemsBySettings.Insert(NamesKey, New FixedStructure(Properties));
	
EndProcedure

&AtClientAtServerNoContext
Function SuggestedValue(Value, Enable = True, Dependence = "", IsEmptyForbidden = False)
	
	If TypeOf(Value) = Type("Structure") Then
		Return Value;
	EndIf;
	
	Result = New Structure;
	Result.Insert("Value", Value);
	Result.Insert("Enable", Enable);
	Result.Insert("Dependence", Dependence);
	Result.Insert("IsEmptyForbidden", IsEmptyForbidden);
	
	Return Result;
	
EndFunction

&AtClient
Procedure EnableSynchronously(Item, Name1, Name2)
	
	If Item.Name = Name1 Then
		ThisObject[Name2] = ThisObject[Name1];
		CommonSettingEnableOnChange(Items[Name2], False);
		
	ElsIf Item.Name = Name2 Then
		ThisObject[Name1] = ThisObject[Name2];
		CommonSettingEnableOnChange(Items[Name1], False);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateExternalUsersSettingsAvailability(Form, OnChange = False)
	
	If Form.AreSeparateSettingsForExternalUsers Then
		Form.Items.ForUsers.Title = NStr("en = 'For users';");
		Form.Items.ForExternalUsers.Visible = True;
		If OnChange Then
			Form.Items.Pages.CurrentPage =
				Form.Items.ForExternalUsers;
		EndIf;
	Else
		Form.Items.ForUsers.Title = NStr("en = 'Main';");
		Form.Items.ForExternalUsers.Visible = False;
		Form.Items.Pages.CurrentPage =
			Form.Items.ForUsers;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateAvailabilityOfBannedPasswordServiceSettings(Form)
	
	Form.Items.BannedPasswordServiceAddress.Enabled =
		Form.ShouldUseBannedPasswordService;
	
	Form.Items.BannedPasswordServiceAddress.AutoMarkIncomplete =
		?(Form.ShouldUseBannedPasswordService, True, Undefined);
	
	Form.Items.BannedPasswordServiceMaxTimeout.Enabled =
		Form.ShouldUseBannedPasswordService;
	
	Form.Items.ShouldSkipValidationIfBannedPasswordServiceOffline.Enabled =
		Form.ShouldUseBannedPasswordService;
	
EndProcedure

&AtServer
Procedure RecountPasswordsInAdditionalBannedList(Val Clear = False, Val Count = -1)
	
	If UsersInternal.IsSettings8_3_26Available() Then
		If Clear Then
			Count = 0;
			NewPasswordListAddressInTempStorage =
				PutToTempStorage(New Array, UUID);
		ElsIf Count = -1 Then
			ManagerOfList = AdditionalAuthenticationSettings.PasswordCompromiseCheckList;
			Count = ManagerOfList.GetPasswordsStoredValuesCount();
		EndIf;
	Else
		Count = 0;
	EndIf;
	
	If ValueIsFilled(Count) Then
		IsListAvailable = Not Common.DataSeparationEnabled();
		TitleText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Additional list (%1)';"), String(Count));
	Else
		IsListAvailable = False;
		TitleText = NStr("en = 'Additional list';");
	EndIf;
	
	Items.ShowBannedPasswordList.Enabled = IsListAvailable;
	Items.ClearBannedPasswordList.Enabled = IsListAvailable;
	Items.ShouldUseAdditionalBannedPasswordList.Title = TitleText;
	
EndProcedure

&AtServer
Procedure FillSettingsInForm(Settings, RecommendedSettingsValues, ForExternalUsers = False)
	
	For Each KeyAndValue In RecommendedSettingsValues Do
		NamesKey = KeyAndValue.Key + ?(ForExternalUsers, "2", "");
		Names = ItemsBySettings.Get(NamesKey);
		If Names = Undefined Then
			Names = New Structure("SettingNameOnForm, TagName",
				KeyAndValue.Key, KeyAndValue.Key);
		EndIf;
		If KeyAndValue.Value = Null Then
			ThisObject[Names.SettingNameOnForm] = Settings[KeyAndValue.Key];
			Continue;
		EndIf;
		SuggestedValue = SuggestedValue(KeyAndValue.Value,, KeyAndValue.Key);
		If ValueIsFilled(Settings[KeyAndValue.Key]) Then
			ThisObject[Names.SettingNameOnForm] = Settings[KeyAndValue.Key];
			If SuggestedValue.Enable Then
				ThisObject[Names.ItemNameInclude] = True;
			EndIf;
		Else
			ThisObject[Names.SettingNameOnForm] = SuggestedValue.Value;
		EndIf;
		If Not ValueIsFilled(Settings[SuggestedValue.Dependence]) Then
			Items[Names.TagName].Enabled = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure WriteAtServer()
	
	BeginTransaction();
	Try
		SetNewAdditionalBannedPasswordList();
		Overall = Users.CommonAuthorizationSettingsNewDetails();
		If IsShowInListPropertyBulkChangeConfirmed
		   And Overall.ShowInList <> ShowInList
		   And (    ShowInList = "HiddenAndEnabledForAllUsers"
		      Or ShowInList = "HiddenAndDisabledForAllUsers") Then
			UsersInternal.SetShowInListAttributeForAllInfobaseUsers(
				ShowInList = "HiddenAndEnabledForAllUsers");
		EndIf;
		FillSettingsFromForm(Overall, RecommendedCommonSettingsValues);
		Users.SetCommonAuthorizationSettings(Overall);
		
		UsersSettings = Users.NewDescriptionOfLoginSettings();
		FillSettingsFromForm(UsersSettings, RecommendedSettingsValues);
		Users.SetLoginSettings(UsersSettings);
		
		ExternalUsersSettings = Users.NewDescriptionOfLoginSettings();
		FillSettingsFromForm(ExternalUsersSettings, RecommendedSettingsValues, True);
		Users.SetLoginSettings(ExternalUsersSettings, True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	NewPasswordListAddressInTempStorage = "";
	
	RefreshReusableValues();
	
EndProcedure

&AtServer
Procedure SetNewAdditionalBannedPasswordList()
	
	If Not ValueIsFilled(NewPasswordListAddressInTempStorage)
	 Or Not UsersInternal.IsSettings8_3_26Available() Then
		Return;
	EndIf;
	
	Rows = GetFromTempStorage(NewPasswordListAddressInTempStorage);
	ManagerOfList = AdditionalAuthenticationSettings.PasswordCompromiseCheckList;
	
	If IsNewListContainsPasswords Then
		ManagerOfList.SetListFromPasswords(Rows);
	Else
		ManagerOfList.SetListFromPasswordsStoredValues(Rows);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillSettingsFromForm(Settings, RecommendedSettingsValues, ForExternalUsers = False)
	
	For Each KeyAndValue In RecommendedSettingsValues Do
		NamesKey = KeyAndValue.Key + ?(ForExternalUsers, "2", "");
		Names = ItemsBySettings.Get(NamesKey);
		If Names = Undefined Then
			Names = New Structure("SettingNameOnForm, TagName",
				KeyAndValue.Key, KeyAndValue.Key);
		EndIf;
		If KeyAndValue.Value = Null Then
			Settings[KeyAndValue.Key] = ThisObject[Names.SettingNameOnForm];
			Continue;
		EndIf;
		SuggestedValue = SuggestedValue(KeyAndValue.Value);
		
		If SuggestedValue.Enable And ThisObject[Names.ItemNameInclude] Then
			Settings[KeyAndValue.Key] = ThisObject[Names.SettingNameOnForm];
		ElsIf SuggestedValue.IsEmptyForbidden Then
			Settings[KeyAndValue.Key] = SuggestedValue.Value;
		ElsIf TypeOf(KeyAndValue.Value) = Type("Number") Then
			Settings[KeyAndValue.Key] = 0;
		ElsIf TypeOf(KeyAndValue.Value) = Type("String") Then
			Settings[KeyAndValue.Key] = "";
		ElsIf TypeOf(KeyAndValue.Value) = Type("Boolean") Then
			Settings[KeyAndValue.Key] = False;
		Else
			Settings[KeyAndValue.Key] = Undefined;
		EndIf;
	EndDo;
	
EndProcedure

&AtServerNoContext
Function CurrentBannedPasswordHashList()
	
	If Not UsersInternal.IsSettings8_3_26Available() Then
		Return "";
	EndIf;
	
	ManagerOfList = AdditionalAuthenticationSettings.PasswordCompromiseCheckList;
	Rows = ManagerOfList.GetPasswordsStoredValuesList();
	
	If TypeOf(Rows) = Type("Array") Then
		Return StrConcat(Rows, Chars.LF);
	EndIf;
	
	Return "";
	
EndFunction

&AtServerNoContext
Function ImportedBannedPasswordList(Address)
	
	Rows = GetFromTempStorage(Address);
	
	Return StrConcat(Rows, Chars.LF);
	
EndFunction

&AtClient
Procedure ShowInListChoiceProcessingCompletion(Response, ValueSelected) Export
	
	If Response = DialogReturnCode.Yes Then
		ShowInList = ValueSelected;
		IsShowInListPropertyBulkChangeConfirmed = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterFileImported(FileThatWasPut, Context) Export
	
	If FileThatWasPut = Undefined Then
		Return;
	EndIf;
	
	Result = ListPreparationPreliminaryResult(FileThatWasPut.Location);
	If TypeOf(Result) <> Type("Array") Then
		ShowMessageBox(, Result);
		Return;
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add("Passwords", NStr("en = 'Passwords';"));
	Buttons.Add("PasswordsHash", NStr("en = 'Password hashes';"));
	Buttons.Add("Cancel", NStr("en = 'Cancel';"));
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Does this file contain passwords or password hashes?
		           |
		           |%1
		           |
		           |(Hash format must be %3 hashed with %2.)';"),
		StrConcat(Result, Chars.LF), "sha1", "base64");
	
	Notification = New NotifyDescription("AfterFileFormatSelected", ThisObject, FileThatWasPut.Location);
	
	ShowQueryBox(Notification, QueryText, Buttons);
	
EndProcedure

&AtClient
Procedure AfterFileFormatSelected(Response, PutFileAddress) Export
	
	If Response <> "Passwords" And Response <> "PasswordsHash" Then
		Return;
	EndIf;
	
	Text = ListPreparationResult(PutFileAddress, Response);
	ShowMessageBox(, Text);
	
EndProcedure

&AtServerNoContext
Function ListPreparationPreliminaryResult(Val Address)
	
	BinaryData = GetFromTempStorage(Address);
	If TypeOf(BinaryData) <> Type("BinaryData") Then
		Return NStr("en = 'Couldn''t receive the file data';");
	EndIf;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Couldn''t find specification at the beginning of the file:  %1 (with %2)';"), "UTF-8", "BOM");
	
	If BinaryData.Size() < 3 Then
		Return ErrorText;
	EndIf;
	
	DataReader = New DataReader(BinaryData);
	BinaryDataBuffer = DataReader.ReadIntoBinaryDataBuffer(3);
	
	If BinaryDataBuffer[0] <> NumberFromHexString("0xEF")
	 Or BinaryDataBuffer[1] <> NumberFromHexString("0xBB")
	 Or BinaryDataBuffer[2] <> NumberFromHexString("0xBF") Then
		
		Return ErrorText;
	EndIf;
	
	Text = GetStringFromBinaryData(BinaryData, TextEncoding.UTF8);
	Rows = StrSplit(Text, Chars.LF + Chars.CR, False);
	AllRows = New Array;
	FirstStrings = New Array;
	
	For Each String In Rows Do
		If Not ValueIsFilled(String) Then
			Continue;
		EndIf;
		String = TrimAll(String);
		AllRows.Add(String);
		If FirstStrings.Count() < 5 Then
			FirstStrings.Add(String);
		EndIf;
	EndDo;
	
	If Not ValueIsFilled(AllRows) Then
		Return NStr("en = 'Empty file';");
	EndIf;
	
	If AllRows.Count() > 5 Then
		FirstStrings.Add("...");
	EndIf;
	
	PutToTempStorage(AllRows, Address);
	
	Return FirstStrings;
	
EndFunction

&AtServer
Function ListPreparationResult(Val Address, Val Format)
	
	Rows = GetFromTempStorage(Address);
	
	If Format = "PasswordsHash" Then
		LineNumber = 0;
		For Each String In Rows Do
			LineNumber = LineNumber + 1;
			If Not ValueIsFilled(String) Then
				Continue;
			EndIf;
			Try
				Hash = Base64Value(String);
			Except
				ErrorInfo = ErrorInfo();
				Return StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Line %2 (""%1"") format is not %3 due to:
					|%4';"),
					String,
					Format(LineNumber, "NG="),
					"base64",
					ErrorProcessing.DetailErrorDescription(ErrorInfo));
			EndTry;
			If Hash.Size() = 0 Then
				Return StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Line %2 (""%1"") format is not %3.';"),
					String,
					Format(LineNumber, "NG="),
					"base64");
			EndIf;
			If Hash.Size() <> 20 Then
				Return StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Line %2 (""%1"") contains binary data with a length other  than 20 bites: %3';"),
					String,
					Format(LineNumber, "NG="),
					Format(Hash.Size(), "NG="));
			EndIf;
		EndDo;
	EndIf;
	
	NewPasswordListAddressInTempStorage =
		PutToTempStorage(Rows, UUID);
	IsNewListContainsPasswords = Format <> "PasswordsHash";
	
	RecountPasswordsInAdditionalBannedList(False, Rows.Count());
	
	If Format = "PasswordsHash" Then
		Return NStr("en = 'Password hashes imported';");
	EndIf;
	
	Return NStr("en = 'Passwords imported';");
	
EndFunction

#EndRegion
