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
	SelectedUsers.Add(Users.CurrentUser());
	UpdateUsersSelectionRef(ThisObject);
	
	UsersToClearSettingsRadioButtons = "SelectedUsers1";
	SettingsToClearRadioButton   = "ClearAll";
	ClearSettingsSelectionHistory     = True;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("UserSelection") Then
		If Source <> FormName Then
			Return;
		EndIf;
		
		SelectedUsers.LoadValues(Parameter.UsersDestination);
		UpdateUsersSelectionRef(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UsersToClearSettingsRadioButtonsOnChange(Item)
	
	If UsersToClearSettingsRadioButtons = "SelectedUsers1"
		And UsersCount = 0 Then
		Items.SettingsToClearGroup.Enabled = False;
	Else
		Items.SettingsToClearGroup.Enabled = True;
		SettingsToClearRadioButtonOnChange(Items.SettingsToClearRadioButton);
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingsToClearRadioButtonOnChange(Item)
	
	If SettingsToClearRadioButton = "SelectedSettings2" Then
		If UsersToClearSettingsRadioButtons <> "SelectedUsers1"
		 Or UsersCount <> 1 Then
			SettingsToClearRadioButton = "ClearAll";
			Items.SelectSettings.Enabled = False;
			ShowMessageBox(,NStr("en = 'To clear individual settings, select one user.';"));
		Else
			Items.SelectSettings.Enabled = True;
		EndIf;
	Else
		Items.SelectSettings.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectUsersClick(Item)
	
	If UseExternalUsers Then
		UsersTypeSelection = New ValueList;
		UsersTypeSelection.Add("ExternalUsers", NStr("en = 'External users';"));
		UsersTypeSelection.Add("Users",        NStr("en = 'Users';"));
		
		Notification = New NotifyDescription("SelectUsersClickSelectItem", ThisObject);
		UsersTypeSelection.ShowChooseItem(Notification);
		Return;
	EndIf;
	
	OpenUserSelectionForm(PredefinedValue("Catalog.Users.EmptyRef"));
	
EndProcedure

&AtClient
Procedure SelectSettings(Item)
	
	If UsersCount = 1 Then
		UserRef = SelectedUsers[0].Value;
		FormParameters = New Structure("User, SettingsOperation, ClearSettingsSelectionHistory",
			UserRef, "Clearing", ClearSettingsSelectionHistory);
		OpenForm("DataProcessor.UsersSettings.Form.SettingsChoice", FormParameters, ThisObject,,,,
			New NotifyDescription("SelectSettingsAfterChoice", ThisObject));
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Clear(Command)
	
	ClearMessages();
	SettingsClearing();
	
EndProcedure

&AtClient
Procedure ClearAndClose(Command)
	
	ClearMessages();
	SettingsCleared = SettingsClearing();
	If SettingsCleared Then
		CommonClient.RefreshApplicationInterface();
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure UpdateUsersSelectionRef(Form)
	Form.UsersCount = Form.SelectedUsers.Count();
	If Form.UsersCount = 0 Then
		Form.Items.SelectSettings.Title = NStr("en = 'Select';");
		Form.SelectedSettings = Undefined;
		Form.SettingsCount = Undefined;
	ElsIf Form.UsersCount = 1 Then
		Form.Items.SelectUsers.Title = String(Form.SelectedUsers[0].Value);
		Form.Items.SettingsToClearGroup.Enabled = True;
	Else
		NumberAndSubject = Format(Form.UsersCount, "NFD=0") + " "
			+ UsersInternalClientServer.IntegerSubject(Form.UsersCount,
				"", NStr("en = 'user, users,,,0';"));
		Form.Items.SelectUsers.Title = NumberAndSubject;
		Form.SettingsToClearRadioButton = "ClearAll";
	EndIf;
EndProcedure
	
&AtClient
Procedure SelectUsersClickSelectItem(SelectedOption, AdditionalParameters) Export
	
	If SelectedOption = Undefined Then
		Return;
	EndIf;
	
	If SelectedOption.Value = "Users" Then
		User = PredefinedValue("Catalog.Users.EmptyRef");
		
	ElsIf SelectedOption.Value = "ExternalUsers" Then
		User = PredefinedValue("Catalog.ExternalUsers.EmptyRef");
	EndIf;
	
	OpenUserSelectionForm(User);
	
EndProcedure

&AtClient
Procedure OpenUserSelectionForm(User)
	
	FormParameters = New Structure;
	FormParameters.Insert("User",          User);
	FormParameters.Insert("ActionType",           "Clearing");
	FormParameters.Insert("SelectedUsers", SelectedUsers.UnloadValues());
	FormParameters.Insert("Source", FormName);
	
	OpenForm("DataProcessor.UsersSettings.Form.SelectUsers", FormParameters);
	
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
Function SettingsClearing()
	
	If UsersToClearSettingsRadioButtons = "SelectedUsers1"
		And UsersCount = 0 Then
		CommonClient.MessageToUser(
			NStr("en = 'Select the users whose
				|settings you want to clear.';"), , "Source");
		Return False;
	EndIf;
	
	If UsersToClearSettingsRadioButtons = "SelectedUsers1" Then
			
		If UsersCount = 1 Then
			SettingsClearedForNote = NStr("en = 'user ""%1""';");
			SettingsClearedForNote = StringFunctionsClientServer.SubstituteParametersToString(
				SettingsClearedForNote, SelectedUsers[0].Value);
		Else
			SettingsClearedForNote = NStr("en = '%1 users';");
			SettingsClearedForNote = StringFunctionsClientServer.SubstituteParametersToString(SettingsClearedForNote, UsersCount);
		EndIf;
		
	Else
		SettingsClearedForNote = NStr("en = 'all users';");
	EndIf;
	
	If SettingsToClearRadioButton = "SelectedSettings2"
		And SettingsCount = 0 Then
		CommonClient.MessageToUser(
			NStr("en = 'Select the settings that you want to clear.';"), , "SettingsToClearRadioButton");
		Return False;
	EndIf;
	
	If SettingsToClearRadioButton = "SelectedSettings2" Then
		ClearSelectedSettings();
		
		If SettingsCount = 1 Then
			
			If StrLen(SettingPresentation) > 24 Then
				SettingPresentation = Left(SettingPresentation, 24) + "...";
			EndIf;
			
			ExplanationText = NStr("en = '""%1"" cleared for %2';");
			ExplanationText = StringFunctionsClientServer.SubstituteParametersToString(ExplanationText, SettingPresentation, SettingsClearedForNote);
			
		Else
			SubjectInWords = Format(SettingsCount, "NFD=0") + " "
				+ UsersInternalClientServer.IntegerSubject(SettingsCount,
					"", NStr("en = 'setting,settings,,,0';"));
			
			ExplanationText = NStr("en = '%1 cleared for %2';");
			ExplanationText = StringFunctionsClientServer.SubstituteParametersToString(ExplanationText, SubjectInWords, SettingsClearedForNote);
		EndIf;
		
		ShowUserNotification(NStr("en = 'Clear settings';"), , ExplanationText, PictureLib.DialogInformation);
		
	ElsIf SettingsToClearRadioButton = "ClearAll" Then
		ClearAllSettings();
		
		ExplanationText = NStr("en = 'All settings are cleared for %1';");
		ExplanationText = StringFunctionsClientServer.SubstituteParametersToString(ExplanationText, SettingsClearedForNote);
		ShowUserNotification(NStr("en = 'Clear settings';"), , ExplanationText, PictureLib.DialogInformation);
		
	ElsIf SettingsToClearRadioButton = "ObsoleteSettings" Then
		ClearObsoleteSettings();
		
		ExplanationText = NStr("en = 'Obsolete settings %1 are cleared';");
		ExplanationText = StringFunctionsClientServer.SubstituteParametersToString(ExplanationText, SettingsClearedForNote);
		ShowUserNotification(NStr("en = 'Clear settings';"), , ExplanationText, PictureLib.DialogInformation);
	EndIf;
	
	SettingsCount = 0;
	Items.SelectSettings.Title = NStr("en = 'Select';");
	Return True;
	
EndFunction

&AtServer
Procedure ClearSelectedSettings()
	
	Source = SelectedUsers[0].Value;
	User = DataProcessors.UsersSettings.IBUserName(Source);
	UserInfo = New Structure;
	UserInfo.Insert("UserRef", Source);
	UserInfo.Insert("InfobaseUserName", User);
	
	If SelectedSettings.ReportsSettings.Count() > 0 Then
		DataProcessors.UsersSettings.DeleteSelectedSettings(
			UserInfo, SelectedSettings.ReportsSettings, "ReportsUserSettingsStorage");
		
		DataProcessors.UsersSettings.DeleteReportOptions(
			SelectedSettings.SelectedReportsOptions, SelectedSettings.ReportOptionTable, User);
	EndIf;
	
	If SelectedSettings.Interface.Count() > 0 Then
		DataProcessors.UsersSettings.DeleteSelectedSettings(
			UserInfo, SelectedSettings.Interface, "SystemSettingsStorage");
	EndIf;
	
	If SelectedSettings.OtherSettings.Count() > 0 Then
		DataProcessors.UsersSettings.DeleteSelectedSettings(
			UserInfo, SelectedSettings.OtherSettings, "SystemSettingsStorage");
	EndIf;
	
	If SelectedSettings.PersonalSettings.Count() > 0 Then
		DataProcessors.UsersSettings.DeleteSelectedSettings(
			UserInfo, SelectedSettings.PersonalSettings, "CommonSettingsStorage");
	EndIf;
	
	For Each OtherUserSettings In SelectedSettings.OtherUserSettings Do
		UsersInternal.OnDeleteOtherUserSettings(
			UserInfo, OtherUserSettings);
	EndDo;
	
EndProcedure

&AtServer
Procedure ClearAllSettings()
	
	SettingsArray = New Array;
	SettingsArray.Add("ReportsSettings");
	SettingsArray.Add("InterfaceSettings2");
	SettingsArray.Add("PersonalSettings");
	SettingsArray.Add("FormData");
	SettingsArray.Add("Favorites");
	SettingsArray.Add("PrintSettings");
	SettingsArray.Add("OtherUserSettings");
	
	If UsersToClearSettingsRadioButtons = "SelectedUsers1" Then
		Sources = SelectedUsers.UnloadValues();
	Else
		Sources = New Array;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add("User");
		UsersTable.Columns.Add("Department");
		UsersTable.Columns.Add("Individual");

		UsersTable = DataProcessors.UsersSettings.UsersToCopy("", UsersTable, False, True);
		For Each TableRow In UsersTable Do
			Sources.Add(TableRow.User);
		EndDo;
		
	EndIf;
	
	DataProcessors.UsersSettings.DeleteUserSettings(SettingsArray, Sources,, True);
	
EndProcedure

&AtServer
Procedure ClearObsoleteSettings()
	
	Sources = ?(UsersToClearSettingsRadioButtons = "SelectedUsers1", 
		SelectedUsers.UnloadValues(), Undefined);
	DataProcessors.UsersSettings.DeleteOutdatedUserSettings(Sources);
	
EndProcedure

#EndRegion
