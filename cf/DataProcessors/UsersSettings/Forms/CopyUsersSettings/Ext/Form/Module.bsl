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
	
	UseExternalUsers = GetFunctionalOption("UseExternalUsers");
	CopySettingsToRadioButtons = "SelectedUsers1";
	SettingsToCopyRadioButton = "CopyAllSettings";
	FormOpeningMode = Parameters.FormOpeningMode;
	
	SettingsRecipientsUsers = New Structure;
	If Parameters.User <> Undefined Then
		UsersArray = New Array;
		UsersArray.Add(Parameters.User);
		SettingsRecipientsUsers.Insert("UsersArray", UsersArray);
		Items.SelectUsers.Title = String(Parameters.User);
		UsersCount = 1;
		PassedUserType = TypeOf(Parameters.User);
		Items.CopyToGroup.Enabled = False;
	Else
		UserRef = Users.CurrentUser();
	EndIf;
	
	If UserRef = Undefined Then
		Items.SettingsToCopyGroup.Enabled = False;
	EndIf;
	
	ClearSettingsSelectionHistory = True;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("UserSelection") Then
		If Source <> FormName Then
			Return;
		EndIf;
		
		SettingsRecipientsUsers = New Structure("UsersArray", Parameter.UsersDestination);
		
		UsersCount = Parameter.UsersDestination.Count();
		If UsersCount = 1 Then
			Items.SelectUsers.Title = String(Parameter.UsersDestination[0]);
		ElsIf UsersCount > 1 Then
			NumberAndSubject = Format(UsersCount, "NFD=0") + " "
				+ UsersInternalClientServer.IntegerSubject(UsersCount,
					"", NStr("en = 'user, users,,,0';"));
			Items.SelectUsers.Title = NumberAndSubject;
		EndIf;
		Items.SelectUsers.ToolTip = "";
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UserStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedUsersType = Undefined;
	
	If UsersCount <> 0 Then
		UsersToHide = New ValueList;
		UsersToHide.LoadValues(SettingsRecipientsUsers.UsersArray);
	EndIf;
	
	FilterParameters = New Structure(
		"ChoiceMode, UsersToHide",
		True, UsersToHide);
	
	If PassedUserType = Undefined Then
		
		If UseExternalUsers Then
			UsersTypeSelection = New ValueList;
			UsersTypeSelection.Add("ExternalUsers", NStr("en = 'External users';"));
			UsersTypeSelection.Add("Users", NStr("en = 'Users';"));
			
			Notification = New NotifyDescription("UserStartChoiceCompletion", ThisObject, FilterParameters);
			UsersTypeSelection.ShowChooseItem(Notification);
			Return;
		Else
			SelectedUsersType = "Users";
		EndIf;
		
	EndIf;
	
	OpenUserSelectionForm(SelectedUsersType, FilterParameters);
	
EndProcedure

&AtClient
Procedure UserStartChoiceCompletion(SelectedOption, FilterParameters) Export
	
	If SelectedOption = Undefined Then
		Return;
	EndIf;
	SelectedUsersType = SelectedOption.Value;
	
	OpenUserSelectionForm(SelectedUsersType, FilterParameters);
	
EndProcedure

&AtClient
Procedure OpenUserSelectionForm(SelectedUsersType, FilterParameters)
	
	If SelectedUsersType = "Users"
		Or PassedUserType = Type("CatalogRef.Users") Then
		OpenForm("Catalog.Users.ListForm", FilterParameters, Items.UserRef);
	ElsIf SelectedUsersType = "ExternalUsers"
		Or PassedUserType = Type("CatalogRef.ExternalUsers") Then
		OpenForm("Catalog.ExternalUsers.ListForm", FilterParameters, Items.UserRef);
	EndIf;
	UserRefOld = UserRef;
	
EndProcedure

&AtClient
Procedure UserRefOnChange(Item)
	
	If UserRef <> Undefined
		And IBUserName(UserRef) = Undefined Then
		ShowMessageBox(,NStr("en = 'The selected user does not have any settings to copy.
				|Please select another user.';"));
		UserRef = UserRefOld;
		Return;
	EndIf;
	
	If UserRef <> Undefined
		And SettingsRecipientsUsers.Property("UsersArray") Then
		
		If SettingsRecipientsUsers.UsersArray.Find(UserRef) <> Undefined Then
			ShowMessageBox(,NStr("en = 'Cannot copy user settings to the source user.
					|Please select a different user.';"));
				UserRef = UserRefOld;
				Return;
		EndIf;
		
	EndIf;
	
	Items.SettingsToCopyGroup.Enabled = UserRef <> Undefined;
	
	SelectedSettings = Undefined;
	SettingsCount = 0;
	Items.SelectSettings.Title = NStr("en = 'Select';");
	
EndProcedure

&AtServer
Function IBUserName(UserRef)
	
	Return DataProcessors.UsersSettings.IBUserName(UserRef);
	
EndFunction

&AtClient
Procedure SelectSettings(Item)
	
	FormParameters = New Structure("User, SettingsOperation, ClearSettingsSelectionHistory",
		UserRef, "Copy", ClearSettingsSelectionHistory);
	OpenForm("DataProcessor.UsersSettings.Form.SettingsChoice", FormParameters, ThisObject,,,,
		New NotifyDescription("SelectSettingsAfterChoice", ThisObject));
	
EndProcedure

&AtClient
Procedure SelectUsers(Item)
	
	SelectedUsers = Undefined;
	SettingsRecipientsUsers.Property("UsersArray", SelectedUsers);
	If SelectedUsers = Undefined Then
		SelectedUsers = New Array;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("User",          UserRef);
	FormParameters.Insert("ActionType",           "Copy");
	FormParameters.Insert("SelectedUsers", SelectedUsers);
	FormParameters.Insert("Source", FormName);
	
	OpenForm("DataProcessor.UsersSettings.Form.SelectUsers", FormParameters);
	
EndProcedure

&AtClient
Procedure CopySettingsToRadioButtonsOnChange(Item)
	
	If CopySettingsToRadioButtons = "SelectedUsers1" Then
		Items.SelectUsers.Enabled = True;
	Else
		Items.SelectUsers.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingsToCopyRadioButtonOnChange(Item)
	
	If SettingsToCopyRadioButton = "CopySelectedSettings1" Then
		Items.SelectSettings.Enabled = True;
	Else
		Items.SelectSettings.Enabled = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Copy(Command)
	
	ClearMessages();
	
	If UserRef = Undefined Then
		CommonClient.MessageToUser(
			NStr("en = 'Select the source user.';"), , "UserRef");
		Return;
	EndIf;
	
	If UsersCount = 0 And CopySettingsToRadioButtons <> "ToAllUsers" Then
		CommonClient.MessageToUser(
			NStr("en = 'Select one or several destination users.';"), , "Receiver");
		Return;
	EndIf;
	
	If SettingsToCopyRadioButton = "CopySelectedSettings1" And SettingsCount = 0 Then
		CommonClient.MessageToUser(
			NStr("en = 'Select the settings to copy.';"), , "SettingsToCopyRadioButton");
		Return;
	EndIf;
	
	// XnWhen copying external type settings or all settings to other users,
	// check if the app supports them. And if it does, inform the user in a user message.
	OpenFormsToCopy = OpenFormsToCopy();
	CheckActiveUsers();
	If CheckResult = "HasActiveUsersRecipients"
		Or (ValueIsFilled(OpenFormsToCopy) And CheckResult = "CurrentUserRecipient") Then
		
		If SettingsToCopyRadioButton = "CopyAllSettings" 
			Or (SettingsToCopyRadioButton = "CopySelectedSettings1"
			And SelectedSettings.Interface.Count() <> 0) Then
			
			ClosingNotification1 = New NotifyDescription("CopyFollowUp", ThisObject);
			
			FormParameters = New Structure;
			FormParameters.Insert("Action", Command.Name);
			FormParameters.Insert("OpenFormsToCopy", OpenFormsToCopy);
			FormParameters.Insert("HasActiveUsersRecipients", CheckResult = "HasActiveUsersRecipients");
			OpenForm("DataProcessor.UsersSettings.Form.CopySettingsWarning", FormParameters, , , , , ClosingNotification1);
			Return;
			
		EndIf;
		
	EndIf;
	CopySettings(Command.Name);
	
EndProcedure

&AtClient
Function OpenFormsToCopy()
	
	If SelectedSettings = Undefined Then
		Return "";
	EndIf;
	
	Settings = SelectedSettings.Interface;
	
	OpenFormsRow          = "";
	AllSettingsToCopyRow = "";
	For Each FormSettings In Settings Do
		For Each FormSettingsItem In FormSettings Do
			AllSettingsToCopyRow = AllSettingsToCopyRow + Chars.LF + FormSettingsItem.Value;
		EndDo;
	EndDo;
	
	OpenWindows = GetWindows();
	For Each OpenWindow In OpenWindows Do
		If OpenWindow.HomePage Or OpenWindow.IsMain Then
			Continue;
		EndIf;
		Content    = OpenWindow.Content;
		DefaultForm = Content.Get(0);
		
		OpenFormName = DefaultForm.FormName;
		If StrFind(OpenFormName, "DataProcessor.UsersSettings") > 0
			Or StrFind(OpenFormName, ".SSLAdministrationPanel.") > 0 Then
			Continue;
		EndIf;
		
		If StrFind(AllSettingsToCopyRow, OpenFormName) > 0 Then
			OpenFormsRow = ?(ValueIsFilled(OpenFormsRow),
				OpenFormsRow + Chars.LF + "- " + OpenWindow.Caption,
				NStr("en = 'The open windows';") + ":" + Chars.LF + "- " + OpenWindow.Caption)
		EndIf;
		
	EndDo;
	
	Return OpenFormsRow;
	
EndFunction

#EndRegion

#Region Private

&AtClient
Procedure CopyFollowUp(Result, AdditionalParameters) Export
	
	If TypeOf(Result) = Type("Structure")
		And Result.Property("Action")
		And Result.Action = "CopyAndClose" Then
		CopySettings(Result.Action);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectSettingsAfterChoice(Parameter, Context) Export
	
	If TypeOf(Parameter) <> Type("Structure") Then
		Return;
	EndIf;
	
	SelectedSettings = New Structure;
	SelectedSettings.Insert("Interface",       Parameter.Interface);
	SelectedSettings.Insert("ReportsSettings", Parameter.ReportsSettings);
	SelectedSettings.Insert("OtherSettings",  Parameter.OtherSettings);
	
	SelectedSettings.Insert("ReportOptionTable",  Parameter.ReportOptionTable);
	SelectedSettings.Insert("SelectedReportsOptions", Parameter.SelectedReportsOptions);
	
	SelectedSettings.Insert("PersonalSettings",           Parameter.PersonalSettings);
	SelectedSettings.Insert("OtherUserSettings", Parameter.OtherUserSettings);
	
	SettingsCount = Parameter.SettingsCount;
	
	If SettingsCount = 0 Then
		TitleText = NStr("en = 'Select';");
	ElsIf SettingsCount = 1 Then
		SettingPresentation = Parameter.SettingsPresentations[0];
		TitleText = SettingPresentation;
	Else
		TitleText = Format(SettingsCount, "NFD=0") + " "
			+ UsersInternalClientServer.IntegerSubject(SettingsCount,
				"", NStr("en = 'setting,settings,,,0';"));
	EndIf;
	
	Items.SelectSettings.Title = TitleText;
	Items.SelectSettings.ToolTip = "";
	
EndProcedure

&AtClient
Procedure CopySettings(CommandName)
	
	If CopySettingsToRadioButtons = "SelectedUsers1" Then
		
		SettingsCopiedToNote = UsersInternalClient.UsersNote(
			UsersCount, SettingsRecipientsUsers.UsersArray[0]);
	Else
		SettingsCopiedToNote = NStr("en = 'all users';");
	EndIf;
	
	NotificationText1    = NStr("en = 'Copy settings';");
	NotificationPicture = PictureLib.DialogInformation;
	
	If SettingsToCopyRadioButton = "CopySelectedSettings1" Then
		Report = Undefined;
		CopySelectedSettings(Report);
		
		If Report <> Undefined Then
			QueryText = NStr("en = 'Some report options and settings are not copied.';");
			QuestionButtons = New ValueList;
			QuestionButtons.Add("OK", NStr("en = 'OK';"));
			QuestionButtons.Add("ShowReport", NStr("en = 'View report';"));
			
			Notification = New NotifyDescription("CopySettingsShowQueryBox", ThisObject, Report);
			ShowQueryBox(Notification, QueryText, QuestionButtons,, QuestionButtons[0].Value);
			Return;
		EndIf;
			
		If Report = Undefined Then
			NotificationComment = UsersInternalClient.GenerateNoteOnCopy(
				SettingPresentation, SettingsCount, SettingsCopiedToNote);
			
			ShowUserNotification(NotificationText1, , NotificationComment, NotificationPicture);
		EndIf;
	Else
		SettingsCopied = CopyingAllSettings();
		If Not SettingsCopied Then
			
			ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The settings were not copied because user ""%1"" does not have any saved settings.';"),
				String(UserRef)));
			Return;
		EndIf;
		
		NotificationComment = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'All settings are copied to %1';"), SettingsCopiedToNote);
		
		ShowUserNotification(NotificationText1, , NotificationComment, NotificationPicture);
	EndIf;
	
	// If this is copying settings from another user, notifying the UsersSettings form
	If FormOpeningMode = "CopyFrom" Then
		Notify("SettingsCopied1", True);
	EndIf;
	
	If CommandName = "CopyAndClose" Then
		Close();
	EndIf;
	
	Return;
	
EndProcedure

&AtClient
Procedure CopySettingsShowQueryBox(Response, Report) Export
	
	If Response = "OK" Then
		Return;
	Else
		Report.ShowGroups = True;
		Report.ShowGrid = False;
		Report.ShowHeaders = False;
		Report.Show();
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure CopySelectedSettings(Report)
	
	User = DataProcessors.UsersSettings.IBUserName(UserRef);
	
	If CopySettingsToRadioButtons = "SelectedUsers1" Then
		Destinations = SettingsRecipientsUsers.UsersArray;
	ElsIf CopySettingsToRadioButtons = "ToAllUsers" Then
		Destinations = New Array;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add("User");
		UsersTable.Columns.Add("Department");
		UsersTable.Columns.Add("Individual");
		DataProcessors.UsersSettings.UsersToCopy(UserRef, UsersTable,
			TypeOf(UserRef) = Type("CatalogRef.ExternalUsers"));
		
		For Each TableRow In UsersTable Do
			Destinations.Add(TableRow.User);
		EndDo;
		
	EndIf;
	
	NotCopiedReportSettings = New ValueTable;
	NotCopiedReportSettings.Columns.Add("User");
	NotCopiedReportSettings.Columns.Add("ReportsList", New TypeDescription("ValueList"));
	
	If SelectedSettings.ReportsSettings.Count() > 0 Then
		
		DataProcessors.UsersSettings.CopyReportAndPersonalSettings(ReportsUserSettingsStorage,
			User, Destinations, SelectedSettings.ReportsSettings, NotCopiedReportSettings);
		
		DataProcessors.UsersSettings.CopyReportOptions(
			SelectedSettings.SelectedReportsOptions, SelectedSettings.ReportOptionTable, User, Destinations);
	EndIf;
		
	If SelectedSettings.Interface.Count() > 0 Then
		DataProcessors.UsersSettings.CopyInterfaceSettings(User, Destinations, SelectedSettings.Interface);
	EndIf;
	
	If SelectedSettings.OtherSettings.Count() > 0 Then
		DataProcessors.UsersSettings.CopyInterfaceSettings(User, Destinations, SelectedSettings.OtherSettings);
	EndIf;
	
	If SelectedSettings.PersonalSettings.Count() > 0 Then
		DataProcessors.UsersSettings.CopyReportAndPersonalSettings(CommonSettingsStorage,
			User, Destinations, SelectedSettings.PersonalSettings);
	EndIf;
	
	For Each OtherUserSettingsItem In SelectedSettings.OtherUserSettings Do
		For Each CatalogUser In Destinations Do
			UserInfo = New Structure;
			UserInfo.Insert("UserRef", CatalogUser);
			UserInfo.Insert("InfobaseUserName", 
				DataProcessors.UsersSettings.IBUserName(CatalogUser));
			UsersInternal.OnSaveOtherUserSettings(
				UserInfo, OtherUserSettingsItem);
		EndDo;
	EndDo;
	
	If NotCopiedReportSettings.Count() <> 0 Then
		Report = DataProcessors.UsersSettings.CreateReportOnCopyingSettings(
			NotCopiedReportSettings);
	EndIf;
	
EndProcedure

&AtServer
Function CopyingAllSettings()
	
	If CopySettingsToRadioButtons = "SelectedUsers1" Then
		Destinations = SettingsRecipientsUsers.UsersArray;
	Else
		Destinations = New Array;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add("User");
		UsersTable.Columns.Add("Department");
		UsersTable.Columns.Add("Individual");
		UsersTable = DataProcessors.UsersSettings.UsersToCopy(UserRef, UsersTable, 
			TypeOf(UserRef) = Type("CatalogRef.ExternalUsers"));
		
		For Each TableRow In UsersTable Do
			Destinations.Add(TableRow.User);
		EndDo;
		
	EndIf;
	
	SettingsToCopy = New Array;
	SettingsToCopy.Add("ReportsSettings");
	SettingsToCopy.Add("InterfaceSettings2");
	SettingsToCopy.Add("PersonalSettings");
	SettingsToCopy.Add("Favorites");
	SettingsToCopy.Add("PrintSettings");
	SettingsToCopy.Add("OtherUserSettings");
	
	SettingsCopied = DataProcessors.UsersSettings.
		CopyUsersSettings(UserRef, Destinations, SettingsToCopy);
		
	Return SettingsCopied;
	
EndFunction

&AtServer
Procedure CheckActiveUsers()
	
	CurrentUser = Users.CurrentUser();
	If SettingsRecipientsUsers.Property("UsersArray") Then
		UsersArray = SettingsRecipientsUsers.UsersArray;
	EndIf;
	
	If CopySettingsToRadioButtons = "ToAllUsers" Then
		
		UsersArray = New Array;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add("User");
		UsersTable.Columns.Add("Department");
		UsersTable.Columns.Add("Individual");
		UsersTable = DataProcessors.UsersSettings.UsersToCopy(UserRef, UsersTable, 
			TypeOf(UserRef) = Type("CatalogRef.ExternalUsers"));
		
		For Each TableRow In UsersTable Do
			UsersArray.Add(TableRow.User);
		EndDo;
		
	EndIf;
	
	If UsersArray.Count() = 1 
		And UsersArray[0] = CurrentUser Then
		
		CheckResult = "CurrentUserRecipient";
		Return;
		
	EndIf;
		
	HasActiveUsersRecipients = False;
	Sessions = GetInfoBaseSessions();
	For Each Recipient In UsersArray Do
		If Recipient = CurrentUser Then
			CheckResult = "CurrentUserAmongRecipients";
			Return;
		EndIf;
		For Each Session In Sessions Do
			If Recipient.IBUserID = Session.User.UUID Then
				HasActiveUsersRecipients = True;
			EndIf;
		EndDo;
	EndDo;
	
	CheckResult = ?(HasActiveUsersRecipients, "HasActiveUsersRecipients", "");
	
EndProcedure

#EndRegion
