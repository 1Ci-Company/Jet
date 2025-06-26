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
Var NotificationProcessingParameters;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CurrentUserRef = Users.CurrentUser();
	
	If Not Users.IsFullUser() Then
		ConfigureFormForLimitedUser();
	EndIf;
	
	If NoViewRight Then
		Items.ReportOrWarning.CurrentPage = Items.InsufficientRights;
		Return;
	EndIf;
	
	CurrentInfobaseUser = DataProcessors.UsersSettings.IBUserName(
		CurrentUserRef);
	
	If Parameters.User <> Undefined Then
		
		IBUserID = Common.ObjectAttributeValue(Parameters.User,
			"IBUserID");
		
		SetPrivilegedMode(True);
		IBUser = InfoBaseUsers.FindByUUID(
			IBUserID);
		SetPrivilegedMode(False);
		
		If IBUser = Undefined Then
			Items.ReportOrWarning.CurrentPage = Items.DisplayWarning;
			Return;
		EndIf;
		
		UserRef = Parameters.User;
		Items.UserRef.Visible = False;
		Title = NStr("en = 'User settings';");
	Else
		UserRef = Users.CurrentUser();
	EndIf;
	
	InfoBaseUser = DataProcessors.UsersSettings.IBUserName(UserRef);
	
	UseExternalUsers = GetFunctionalOption("UseExternalUsers");
	
	PersonalSettingsFormName = Common.CommonCoreParameters().PersonalSettingsFormName;
	
	SelectedSettingsPage = Items.SettingsKinds.CurrentPage.Name;
	
EndProcedure

&AtServer
Procedure ConfigureFormForLimitedUser()
	
	Items.Copy.Visible = False;
	Items.CopyToOtherUsers.Visible = False;
	Items.CopyFrom.Visible = False;
	Items.ClearSelectedSettingsGroup.Visible = False;
	Items.InterfaceContextMenuCopy.Visible = False;
	Items.ReportSettingsTreeContextMenuCopy.Visible = False;
	Items.OtherSettingsContextMenuCopy.Visible = False;
	
	NoViewRight = (CurrentUserRef <> Parameters.User);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("UserSelection") And Source <> FormName Then
		Return;
	EndIf;
	
	NotificationProcessingParameters = New Structure("EventName, Parameter", EventName, Parameter);
	AttachIdleHandler("Attachable_ExecuteNotifyProcessing", 0.1, True);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If NoViewRight Then
		Return;
	EndIf;
	
	AttachIdleHandler("UpdateSettingsList", 0.1, True);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OnCurrentPageChange(Item, CurrentPage)
	
	SelectedSettingsPage = CurrentPage.Name;
	
EndProcedure

&AtClient
Procedure UserRefStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FilterParameters = New Structure("ChoiceMode", True);
	
	If UseExternalUsers Then
		UsersTypeSelection = New ValueList;
		UsersTypeSelection.Add("ExternalUsers", NStr("en = 'External users';"));
		UsersTypeSelection.Add("Users",        NStr("en = 'Users';"));
		
		UsersTypeSelection.ShowChooseItem(New NotifyDescription(
			"UserRefStartChoiceCompletion", ThisObject, FilterParameters));
	Else
		OpenForm("Catalog.Users.ListForm",
			FilterParameters, Items.UserRef);
	EndIf;
	
EndProcedure

&AtClient
Procedure UserRefStartChoiceCompletion(SelectedOption, FilterParameters) Export
	
	If SelectedOption = Undefined Then
		Return;
	EndIf;
	
	If SelectedOption.Value = "Users" Then
		OpenForm("Catalog.Users.ListForm",
			FilterParameters, Items.UserRef);
		
	ElsIf SelectedOption.Value = "ExternalUsers" Then
		OpenForm("Catalog.ExternalUsers.ListForm",
			FilterParameters, Items.UserRef);
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportAndInterfaceSettingsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	If Not Copy Then
		Cancel = True;
		Return;
	EndIf;
	
	CopySettings();
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure SettingsBeforeDelete(Item, Cancel)
	
	Cancel = True;
	
	QueryText = NStr("en = 'Do you want to clear the selected settings?';");
	Notification = New NotifyDescription("SettingsBeforeDeleteCompletion", ThisObject, Item);
	
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure SettingsTreeChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	UsersInternalClient.OpenReportOrForm(CurrentItem,
		InfoBaseUser, CurrentInfobaseUser, PersonalSettingsFormName);
	
EndProcedure

&AtClient
Procedure UserRefOnChange(Item)
	
	Items.CommandBar.Enabled = Not IsBlankString(Item.SelectedText);
	
	If SettingsGettingResult() = "NoIBUser" Then
		UserRef = CurrentUserRef;
		
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot view the settings of the selected user ""%1""
			           |because it is not mapped to an infobase user.
			           |You can correct this in the user card.';"),
			UserRef));
		Return;
	EndIf;
	
	UpdateSettingsList();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Refresh(Command)
	
	UpdateSettingsList();
	
EndProcedure

&AtClient
Procedure CopyToOtherUsers(Command)
	
	CopySettings();
	
EndProcedure

&AtClient
Procedure CopyAllSettings(Command)
	
	SettingsToCopy.Clear();
	
	SettingsToCopy.Add("ReportsSettings",      NStr("en = 'Report settings';"));
	SettingsToCopy.Add("InterfaceSettings2", NStr("en = 'Interface settings';"));
	SettingsToCopy.Add("FormData",            NStr("en = 'Form data';"));
	SettingsToCopy.Add("PersonalSettings", NStr("en = 'Personal settings';"));
	SettingsToCopy.Add("Favorites",             NStr("en = 'Favorites';"));
	SettingsToCopy.Add("PrintSettings",       NStr("en = 'Print settings';"));
	SettingsToCopy.Add("OtherUserSettings",
		NStr("en = 'Additional report and data processor settings';"));
	
	FormParameters = New Structure;
	FormParameters.Insert("User", UserRef);
	FormParameters.Insert("ActionType",  "CopyAll");
	
	SelectUsers(FormParameters);
	
EndProcedure

&AtClient
Procedure CopyReportSettings(Command)
	
	SettingsToCopy.Clear();
	
	SettingsToCopy.Add("ReportsSettings", NStr("en = 'Report settings';"));
	
	FormParameters = New Structure;
	FormParameters.Insert("User", UserRef);
	FormParameters.Insert("ActionType",  "CopyAll");
	SelectUsers(FormParameters);
	
EndProcedure

&AtClient
Procedure CopyInterfaceSettings(Command)
	
	SettingsToCopy.Clear();
	
	SettingsToCopy.Add("InterfaceSettings2", NStr("en = 'Interface settings';"));
	
	FormParameters = New Structure;
	FormParameters.Insert("User", UserRef);
	FormParameters.Insert("ActionType",  "CopyAll");
	SelectUsers(FormParameters);
	
EndProcedure

&AtClient
Procedure CopyReportAndInterfaceSettings(Command)
	
	SettingsToCopy.Clear();
	SettingsToCopy.Add("ReportsSettings",      NStr("en = 'Report settings';"));
	SettingsToCopy.Add("InterfaceSettings2", NStr("en = 'Interface settings';"));
	
	FormParameters = New Structure;
	FormParameters.Insert("User", UserRef);
	FormParameters.Insert("ActionType",  "CopyAll");
	SelectUsers(FormParameters);
	
EndProcedure

&AtClient
Procedure Clear(Command)
	
	SettingsTree = SelectedSettingsPageFormTable();
	
	If SettingsTree.SelectedRows.Count() = 0 Then
		
		ShowMessageBox(,NStr("en = 'Select the settings that you want to delete.';"));
		Return;
		
	EndIf;
	
	Notification = New NotifyDescription("ClearCompletion", ThisObject, SettingsTree);
	QueryText = NStr("en = 'Do you want to clear the selected settings?';");
	
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure ClearSettingsForSelectedUsers(Command)
	
	SettingsTree = SelectedSettingsPageFormTable();
	SelectedRows = SettingsTree.SelectedRows;
	If SelectedRows.Count() = 0 Then
		
		ShowMessageBox(, NStr("en = 'Select the settings that you want to delete.';"));
		Return;
		
	EndIf;
	
	QueryText =
		NStr("en = 'Do you want to clear the selected settings?
		           |This will open the list where you can select the users whose settings will be cleared.';");
	
	Notification = New NotifyDescription("ClearSettingsForSelectedUsersCompletion", ThisObject);
	
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure ClearAllSettings(Command)
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Do you want to clear all settings for user ""%1""?';"), String(UserRef));
	
	QuestionButtons = New ValueList;
	QuestionButtons.Add("Clear", NStr("en = 'Clear';"));
	QuestionButtons.Add("Cancel",   NStr("en = 'Cancel';"));
	
	Notification = New NotifyDescription("ClearAllSettingsCompletion", ThisObject);
	
	ShowQueryBox(Notification, QueryText, QuestionButtons,, QuestionButtons[1].Value);
	
EndProcedure

&AtClient
Procedure ClearObsoleteSettings(Command)
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Clear obsolete settings for the ""%1"" users?';"), String(UserRef));
	
	QuestionButtons = New ValueList;
	QuestionButtons.Add("Clear", NStr("en = 'Clear the settings.';"));
	QuestionButtons.Add("Cancel",   NStr("en = 'Cancel';"));
	
	Notification = New NotifyDescription("ClearObsoleteSettingsCompletion", ThisObject);
	
	ShowQueryBox(Notification, QueryText, QuestionButtons,, QuestionButtons[1].Value);
	
EndProcedure

&AtClient
Procedure ClearReportAndInterfaceSettings(Command)
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Do you want to clear all interface and report settings for user ""%1""?';"),
		String(UserRef));
	
	QuestionButtons = New ValueList;
	QuestionButtons.Add("Clear", NStr("en = 'Clear';"));
	QuestionButtons.Add("Cancel",   NStr("en = 'Cancel';"));
	
	Notification = New NotifyDescription("ClearReportAndInterfaceSettingsCompletion", ThisObject);
	
	ShowQueryBox(Notification, QueryText, QuestionButtons,, QuestionButtons[1].Value);
	
EndProcedure

&AtClient
Procedure OpenSettingsItem(Command)
	
	UsersInternalClient.OpenReportOrForm(CurrentItem,
		InfoBaseUser, CurrentInfobaseUser, PersonalSettingsFormName);
	
EndProcedure

&AtClient
Procedure ClearSettingsForAllUsers(Command)
	
	QueryText =
		NStr("en = 'All settings of all users will be cleared.
		           |Do you want to continue?';");
	
	QuestionButtons = New ValueList;
	QuestionButtons.Add("ClearAll", NStr("en = 'Clear all';"));
	QuestionButtons.Add("Cancel",      NStr("en = 'Cancel';"));
	
	Notification = New NotifyDescription("ClearSettingsForAllUsersCompletion", ThisObject);
	ShowQueryBox(Notification, QueryText, QuestionButtons,, QuestionButtons[1].Value);
	
EndProcedure

&AtClient
Procedure ClearObsoleteSettingsOfAllUsers(Command)
	
	QueryText =
		NStr("en = 'Obsolete settings for all users will be cleared.
		           |Continue?';");
	
	QuestionButtons = New ValueList;
	QuestionButtons.Add("ClearAll", NStr("en = 'Clear all';"));
	QuestionButtons.Add("Cancel",      NStr("en = 'Cancel';"));
	
	Notification = New NotifyDescription("ClearObsoleteSettingsOfAllUsersCompletion", ThisObject);
	ShowQueryBox(Notification, QueryText, QuestionButtons,, QuestionButtons[1].Value);
	
EndProcedure

&AtClient
Procedure CopyFrom(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("User",       UserRef);
	FormParameters.Insert("FormOpeningMode", "CopyFrom");
	
	OpenForm("DataProcessor.UsersSettings.Form.CopyUsersSettings", FormParameters);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for displaying lists of settings.

&AtClient
Procedure UpdateSettingsList()
	
	Items.QuickSearch.Enabled = False;
	Items.CommandBar.Enabled = False;
	Items.TimeConsumingOperationPages.CurrentPage = Items.TimeConsumingOperationPage;
	
	Result = UpdatingSettingsList();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	
	CallbackOnCompletion = New NotifyDescription("UpdateSettingsListCompletion", ThisObject);
	
	TimeConsumingOperationsClient.WaitCompletion(Result, CallbackOnCompletion, IdleParameters);
	
EndProcedure

&AtServer
Function UpdatingSettingsList()
	
	If ValueIsFilled(JobID) Then
		TimeConsumingOperations.CancelJobExecution(JobID);
	EndIf;
	
	TimeConsumingOperationParameters = TimeConsumingOperationParameters();
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.WaitCompletion = 0; // Run immediately.
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Update user settings';");
	
	TimeConsumingOperation = TimeConsumingOperations.ExecuteInBackground("UsersInternal.FillSettingsLists",
		TimeConsumingOperationParameters, ExecutionParameters);
	
	If TimeConsumingOperation.Status = "Running" Then
		JobID = TimeConsumingOperation.JobID; 
	EndIf;
	
	Return TimeConsumingOperation;
	
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure UpdateSettingsListCompletion(Result, AdditionalParameters) Export
	
	Items.TimeConsumingOperationPages.CurrentPage = Items.SettingsPage;
	Items.QuickSearch.Enabled = True;
	Items.CommandBar.Enabled = True;
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Completed2" Then
		FillSettings(Result.ResultAddress);
		AttachIdleHandler("Attachable_ExpandValueTree", 0.1, True);
		
	ElsIf Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillSettings(Val ResultAddress)
	
	Result = GetFromTempStorage(ResultAddress);
	
	ValueToFormAttribute(Result.ReportSettingsTree, "ReportsSettings");
	ValueToFormAttribute(Result.UserReportOptions, "UserReportOptionTable");
	ValueToFormAttribute(Result.InterfaceSettings2, "Interface");
	ValueToFormAttribute(Result.OtherSettingsTree, "OtherSettings");
	
	CalculateSettingsCount();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for calculating the number of settings items.

&AtServer
Procedure CalculateSettingsCount()
	
	SettingsList = ReportsSettings.GetItems();
	SettingsCount = SettingsInTreeCount(SettingsList);
	
	If SettingsCount <> 0 Then
		Items.ReportSettingsPage.Title =
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Report settings (%1)';"), SettingsCount);
	Else
		Items.ReportSettingsPage.Title = NStr("en = 'Report settings';");
	EndIf;
	
	SettingsList = Interface.GetItems();
	SettingsCount = SettingsInTreeCount(SettingsList);
	
	If SettingsCount <> 0 Then
		Items.InterfacePage.Title =
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Interface settings (%1)';"), SettingsCount);
	Else
		Items.InterfacePage.Title = NStr("en = 'Interface';");
	EndIf;
	
	SettingsList = OtherSettings.GetItems();
	SettingsCount = SettingsInTreeCount(SettingsList);
	
	If SettingsCount <> 0 Then
		Items.OtherSettingsPage.Title =
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Other settings (%1)';"), SettingsCount);
	Else
		Items.OtherSettingsPage.Title = NStr("en = 'Other settings';");
	EndIf;
	
EndProcedure

&AtServer
Function SettingsInTreeCount(SettingsList)
	
	SettingsCount = 0;
	For Each Setting In SettingsList Do
		
		SubordinateSettingsCount = Setting.GetItems().Count();
		If SubordinateSettingsCount = 0 Then
			SettingsCount = SettingsCount + 1;
		Else
			SettingsCount = SettingsCount + SubordinateSettingsCount;
		EndIf;
		
	EndDo;
	
	Return SettingsCount;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for copying, deleting, and clearing settings.

&AtServer
Procedure CopyAtServer(UsersDestination, ReportPersonalizationCount, Report)
	
	Result = SelectedSettings1();
	SelectedReportOptionsTable = New ValueTable;
	SelectedReportOptionsTable.Columns.Add("Presentation");
	SelectedReportOptionsTable.Columns.Add("StandardProcessing");
	
	If SelectedSettingsPage = "ReportSettingsPage" Then
		
		For Each Setting In Result.SettingsArray Do
			
			For Each Item In Setting Do
				
				If Item.Check Then
					ReportPersonalizationCount = ReportPersonalizationCount + 1;
					ReportKey = StringFunctionsClientServer.SubstituteParametersToString(Item.Value, "/");
					
					FilterParameter = New Structure("ObjectKey", ReportKey[0]);
					RowsArray = UserReportOptionTable.FindRows(FilterParameter);
					
					If RowsArray.Count() <> 0 Then
						TableRow = SelectedReportOptionsTable.Add();
						TableRow.Presentation = RowsArray[0].Presentation;
						TableRow.StandardProcessing = True;
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
		NotCopiedReportSettings = New ValueTable;
		NotCopiedReportSettings.Columns.Add("User");
		NotCopiedReportSettings.Columns.Add("ReportsList", New TypeDescription("ValueList"));
		
		DataProcessors.UsersSettings.CopyReportAndPersonalSettings(
			ReportsUserSettingsStorage,
			InfoBaseUser,
			UsersDestination,
			Result.SettingsArray,
			NotCopiedReportSettings);
		
		// Copy report options.
		DataProcessors.UsersSettings.CopyReportOptions(Result.ReportOptionArray,
			UserReportOptionTable, InfoBaseUser, UsersDestination);
			
		If NotCopiedReportSettings.Count() <> 0
		 Or UserReportOptionTable.Count() <> 0 Then
			
			Report = DataProcessors.UsersSettings.CreateReportOnCopyingSettings(
				NotCopiedReportSettings, SelectedReportOptionsTable);
		EndIf;
		
	ElsIf SelectedSettingsPage = "InterfacePage" Then
		DataProcessors.UsersSettings.CopyInterfaceSettings(InfoBaseUser,
			UsersDestination, Result.SettingsArray);
	Else
		
		If Result.PersonalSettingsArray.Count() <> 0 Then
			DataProcessors.UsersSettings.CopyReportAndPersonalSettings(
				CommonSettingsStorage,
				InfoBaseUser,
				UsersDestination,
				Result.PersonalSettingsArray);
		EndIf;
			
		If Result.UserSettingsArray.Count() <> 0 Then
			
			For Each OtherUserSettings In Result.UserSettingsArray Do
				For Each DestinationUser In UsersDestination Do
					
					UserInfo = New Structure;
					UserInfo.Insert("UserRef", DestinationUser);
					UserInfo.Insert("InfobaseUserName",
						DataProcessors.UsersSettings.IBUserName(DestinationUser));
					
					UsersInternal.OnSaveOtherUserSettings(
						UserInfo, OtherUserSettings);
				EndDo;
			EndDo;
		EndIf;
		
		DataProcessors.UsersSettings.CopyInterfaceSettings(
			InfoBaseUser, UsersDestination, Result.SettingsArray);
	EndIf;
	
EndProcedure

&AtServer
Procedure CopyAllSettingsAtServer(User, UsersDestination, SettingsArray, Report)
	
	NotCopiedReportSettings = New ValueTable;
	NotCopiedReportSettings.Columns.Add("User");
	NotCopiedReportSettings.Columns.Add("ReportsList", New TypeDescription("ValueList"));
	
	DataProcessors.UsersSettings.CopyUsersSettings(
		UserRef, UsersDestination, SettingsArray, NotCopiedReportSettings);
		
	If NotCopiedReportSettings.Count() <> 0
	 Or UserReportOptionTable.Count() <> 0 Then
		
		Report = DataProcessors.UsersSettings.CreateReportOnCopyingSettings(
			NotCopiedReportSettings, UserReportOptionTable);
	EndIf;
	
EndProcedure

&AtServer
Procedure ClearAtServer(Users = Undefined, SelectedUsers1 = False)
	
	Result = SelectedSettings1();
	StorageDescription = SettingsStorageForSelectedPage();
	
	If SelectedUsers1 Then
		
		DataProcessors.UsersSettings.DeleteSettingsForSelectedUsers(Users,
			Result.SettingsArray, StorageDescription);
		
		If Result.PersonalSettingsArray.Count() <> 0 Then
			DataProcessors.UsersSettings.DeleteSettingsForSelectedUsers(Users,
				Result.PersonalSettingsArray, "CommonSettingsStorage");
		EndIf;
		
		Return;
	EndIf;
	
	// Clear settings.
	UserInfo = New Structure;
	UserInfo.Insert("InfobaseUserName", InfoBaseUser);
	UserInfo.Insert("UserRef", UserRef);
	
	DataProcessors.UsersSettings.DeleteSelectedSettings(UserInfo,
		Result.SettingsArray, StorageDescription);
	
	If Result.PersonalSettingsArray.Count() <> 0 Then
		DataProcessors.UsersSettings.DeleteSelectedSettings(UserInfo,
			Result.PersonalSettingsArray, "CommonSettingsStorage");
	EndIf;
	
	If Result.UserSettingsArray.Count() <> 0 Then
		
		For Each OtherUserSettings In Result.UserSettingsArray Do
			UsersInternal.OnDeleteOtherUserSettings(
				UserInfo, OtherUserSettings);
		EndDo;
	EndIf;
	
	// Clear report options.
	If SelectedSettingsPage = "ReportSettingsPage" Then
		
		DataProcessors.UsersSettings.DeleteReportOptions(Result.ReportOptionArray,
			UserReportOptionTable, InfoBaseUser);
	EndIf;
	
EndProcedure

&AtServer
Procedure ClearAllSettingsAtServer(SettingsToClear, ClearAll = False)
	
	UsersArray = New Array;
	UsersArray.Add(UserRef);
	
	DataProcessors.UsersSettings.DeleteUserSettings(SettingsToClear,
		UsersArray, UserReportOptionTable, ClearAll);
	
EndProcedure

&AtServer
Procedure ClearOutdatedSettingsOnTheServer()
	
	UsersArray = New Array;
	UsersArray.Add(UserRef);
	
	DataProcessors.UsersSettings.DeleteOutdatedUserSettings(UsersArray);
	
EndProcedure

&AtServer
Procedure ClearAllUserSettingsAtServer()
	
	SettingsToClear = New Array;
	SettingsToClear.Add("ReportsSettings");
	SettingsToClear.Add("InterfaceSettings2");
	SettingsToClear.Add("PersonalSettings");
	SettingsToClear.Add("FormData");
	SettingsToClear.Add("Favorites");
	SettingsToClear.Add("PrintSettings");
	
	UsersArray = New Array;
	UsersTable = New ValueTable;
	UsersTable.Columns.Add("User");
	UsersTable.Columns.Add("Department");
	UsersTable.Columns.Add("Individual");
	
	UsersTable = DataProcessors.UsersSettings.UsersToCopy("",
		UsersTable, False, True);
	
	For Each TableRow In UsersTable Do
		UsersArray.Add(TableRow.User);
	EndDo;
	
	DataProcessors.UsersSettings.DeleteUserSettings(SettingsToClear, UsersArray,, True);
	
EndProcedure

&AtServer
Procedure ClearOutdatedSettingsOfAllUsersOnTheServer()
	
	DataProcessors.UsersSettings.DeleteOutdatedUserSettings(Undefined);
	
EndProcedure

&AtClient
Procedure DeleteSettingsFromValueTree(SelectedRows)
	
	For Each SelectedRow In SelectedRows Do
		
		If SelectedSettingsPage = "ReportSettingsPage" Then
			DeleteSettingsRow(ReportsSettings, SelectedRow);
			
		ElsIf SelectedSettingsPage = "InterfacePage" Then
			DeleteSettingsRow(Interface, SelectedRow);
		Else
			DeleteSettingsRow(OtherSettings, SelectedRow);
		EndIf;
		
	EndDo;
	
	CalculateSettingsCount();
EndProcedure

&AtClient
Procedure ClearCompletion(Response, SettingsTree) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	SelectedRows = SettingsTree.SelectedRows;
	SettingsCount = CopiedOrDeletedSettingsCount(SettingsTree);
	
	ClearAtServer();
	CommonClient.RefreshApplicationInterface();
	
	If SettingsCount = 1 Then
		
		SettingName1 = SettingsTree.CurrentData.Setting;
		If StrLen(SettingName1) > 24 Then
			SettingName1 = Left(SettingName1, 24) + "...";
		EndIf;
		
	EndIf;
	
	DeleteSettingsFromValueTree(SelectedRows);
	
	NotifyDeletion(SettingsCount, SettingName1);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

&AtClient
Procedure Attachable_ExecuteNotifyProcessing()
	
	EventName = NotificationProcessingParameters.EventName;
	Parameter   = NotificationProcessingParameters.Parameter;
	
	If Upper(EventName) = Upper("SettingsCopied1") Then
		UpdateSettingsList();
		CommonClient.RefreshApplicationInterface();
		Return;
	EndIf;
	
	If Upper(EventName) <> Upper("UserSelection") Then
		Return;
	EndIf;
	
	UsersDestination = Parameter.UsersDestination;
	UsersCount = UsersDestination.Count();
	
	SettingsCopiedToNote = UsersInternalClient.UsersNote(
		UsersCount, UsersDestination[0]);
	
	NotificationText1     = NStr("en = 'Copy settings';");
	NotificationPicture  = PictureLib.DialogInformation;
	
	If Parameter.CopyAll Then
		
		SettingsArray = New Array;
		SettingsNames = "";
		For Each Setting In SettingsToCopy Do 
			
			SettingsNames = SettingsNames + Lower(Setting.Presentation) + ", ";
			SettingsArray.Add(Setting.Value);
			
		EndDo;
		
		SettingsNames = Left(SettingsNames, StrLen(SettingsNames)-2);
		
		If SettingsArray.Count() = 7 Then
			NotificationComment = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'All settings are copied to %1.';"), SettingsCopiedToNote);
		Else
			NotificationComment = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 copied to %2';"), SettingsNames, SettingsCopiedToNote);
		EndIf;
		
		Report = Undefined;
		CopyAllSettingsAtServer(InfoBaseUser,
			UsersDestination, SettingsArray, Report);
		
		If Report <> Undefined Then
			QueryText = NStr("en = 'Some report options and settings are not copied.';");
			
			QuestionButtons = New ValueList;
			QuestionButtons.Add("OK", NStr("en = 'OK';"));
			QuestionButtons.Add("ShowReport", NStr("en = 'View report';"));
			
			Notification = New NotifyDescription("NotificationProcessingShowQueryBox", ThisObject, Report);
			ShowQueryBox(Notification, QueryText, QuestionButtons,, QuestionButtons[0].Value);
			
			Return;
		EndIf;
		
		ShowUserNotification(NotificationText1, , NotificationComment, NotificationPicture);
		Return;
	EndIf;
	
	If Parameter.SettingsClearing Then
		
		SettingsTree = SelectedSettingsPageFormTable();
		SettingsCount = CopiedOrDeletedSettingsCount(SettingsTree);
		
		ClearAtServer(UsersDestination, True);
		
		If SettingsCount = 1 Then
			
			SettingName1 = SettingsTree.CurrentData.Setting;
			If StrLen(SettingName1) > 24 Then
				SettingName1 = Left(SettingName1, 24) + "...";
			EndIf;
			
		EndIf;
		
		UsersCount = Parameter.UsersDestination.Count();
		NotifyDeletion(SettingsCount, SettingName1, UsersCount);
		Return;
	EndIf;
	
	SettingsTree = SelectedSettingsPageFormTable();
	SettingsCount = CopiedOrDeletedSettingsCount(SettingsTree);
	
	ReportPersonalizationCount = 0;
	Report = Undefined;
	CopyAtServer(UsersDestination, ReportPersonalizationCount, Report);
	
	If Report <> Undefined Then
		QueryText = NStr("en = 'Some report options and settings are not copied.';");
		QuestionButtons = New ValueList;
		QuestionButtons.Add("OK", NStr("en = 'OK';"));
		QuestionButtons.Add("ShowReport", NStr("en = 'View report';"));
		
		Notification = New NotifyDescription("NotificationProcessingShowQueryBox", ThisObject, Report);
		ShowQueryBox(Notification, QueryText, QuestionButtons,, QuestionButtons[0].Value);
		Return;
	Else
		
		If SettingsCount = 1 Then
			SettingPresentation = SettingsTree.CurrentData.Setting;
		EndIf;
		
		NotificationComment = UsersInternalClient.GenerateNoteOnCopy(
			SettingPresentation, SettingsCount, SettingsCopiedToNote);
		
		ShowUserNotification(NotificationText1, , NotificationComment, NotificationPicture);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectUsers(ChoiceParameters)
	
	ChoiceParameters.Insert("Source", FormName);
	OpenForm("DataProcessor.UsersSettings.Form.SelectUsers", ChoiceParameters);
	
EndProcedure

&AtClient
Procedure ClearSettingsForSelectedUsersCompletion(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("User", UserRef);
	FormParameters.Insert("ActionType",  "Clearing");
	SelectUsers(FormParameters);
	
EndProcedure

&AtClient
Procedure ClearSettingsForAllUsersCompletion(Response, AdditionalParameters) Export
	
	If Response = "Cancel" Then
		Return;
	EndIf;
	
	ClearAllUserSettingsAtServer();
	CommonClient.RefreshApplicationInterface();
	
	ShowUserNotification(NStr("en = 'Clear settings';"), ,
		NStr("en = 'All settings of all users are cleared.';"), PictureLib.DialogInformation);
	
EndProcedure

&AtClient
Procedure ClearObsoleteSettingsOfAllUsersCompletion(Response, AdditionalParameters) Export
	
	If Response = "Cancel" Then
		Return;
	EndIf;
	
	ClearOutdatedSettingsOfAllUsersOnTheServer();
	CommonClient.RefreshApplicationInterface();
	
	ShowUserNotification(NStr("en = 'Clear settings';"), ,
		NStr("en = 'Obsolete settings are cleared for all users';"), PictureLib.DialogInformation);
	
EndProcedure

&AtClient
Procedure ClearAllSettingsCompletion(Response, AdditionalParameters) Export
	
	If Response = "Cancel" Then
		Return;
	EndIf;
	
	SettingsToClear = New Array;
	SettingsToClear.Add("ReportsSettings");
	SettingsToClear.Add("InterfaceSettings2");
	SettingsToClear.Add("FormData");
	SettingsToClear.Add("PersonalSettings");
	SettingsToClear.Add("Favorites");
	SettingsToClear.Add("PrintSettings");
	SettingsToClear.Add("OtherUserSettings");
	
	ClearAllSettingsAtServer(SettingsToClear, True);
	CommonClient.RefreshApplicationInterface();
	UpdateSettingsList();
	
	ExplanationText = NStr("en = 'All settings of user ""%1"" are cleared.';");
	ExplanationText = StringFunctionsClientServer.SubstituteParametersToString(ExplanationText, UserRef);
	ShowUserNotification(NStr("en = 'Clear settings';"), , ExplanationText, PictureLib.DialogInformation);
	
EndProcedure

&AtClient
Procedure ClearObsoleteSettingsCompletion(Response, AdditionalParameters) Export
	
	If Response = "Cancel" Then
		Return;
	EndIf;
	
	ClearOutdatedSettingsOnTheServer();
	CommonClient.RefreshApplicationInterface();
	UpdateSettingsList();
	
	ExplanationText = NStr("en = 'Obsolete settings are cleared for the ""%1"" user';");
	ExplanationText = StringFunctionsClientServer.SubstituteParametersToString(ExplanationText, UserRef);
	ShowUserNotification(NStr("en = 'Clear settings';"), , ExplanationText, PictureLib.DialogInformation);
	
EndProcedure

&AtClient
Procedure ClearReportAndInterfaceSettingsCompletion(Response, AdditionalParameters) Export
	
	If Response = "Cancel" Then
		Return;
	EndIf;
	
	SettingsToClear = New Array;
	SettingsToClear.Add("ReportsSettings");
	SettingsToClear.Add("InterfaceSettings2");
	SettingsToClear.Add("FormData");
	
	ClearAllSettingsAtServer(SettingsToClear);
	CommonClient.RefreshApplicationInterface();
	
	ExplanationText = NStr("en = 'All interface and report settings of user ""%1"" are cleared.';");
	ExplanationText = StringFunctionsClientServer.SubstituteParametersToString(ExplanationText, String(UserRef));
	ShowUserNotification(NStr("en = 'Clear settings';"), , ExplanationText, PictureLib.DialogInformation);
	
EndProcedure

&AtClient
Procedure SettingsBeforeDeleteCompletion(Response, Item) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	ClearAtServer();
	CommonClient.RefreshApplicationInterface();
	
	SelectedRows = Item.SelectedRows;
	SettingsCount = CopiedOrDeletedSettingsCount(Item);
	
	If SettingsCount = 1 Then
		
		SettingsTree = SelectedSettingsPageFormTable();
		SettingName1 = SettingsTree.CurrentData.Setting;
		
		If StrLen(SettingName1) > 24 Then
			SettingName1 = Left(SettingName1, 24) + "...";
		EndIf;
		
	EndIf;
	
	DeleteSettingsFromValueTree(SelectedRows);
	
	NotifyDeletion(SettingsCount, SettingName1);
	
EndProcedure

&AtClient
Procedure NotificationProcessingShowQueryBox(Response, Report) Export
	
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

&AtClient
Procedure Attachable_ExpandValueTree()
	
	For Each Item In ReportsSettings.GetItems() Do
		Items.ReportSettingsTree.Expand(Item.GetID(), True);
	EndDo;
	
	For Each Item In Interface.GetItems() Do
		Items.Interface.Expand(Item.GetID(), True);
	EndDo;
	
EndProcedure

&AtClient
Function SelectedSettingsPageFormTable()
	
	If SelectedSettingsPage = "ReportSettingsPage" Then
		Return Items.ReportSettingsTree;
	ElsIf SelectedSettingsPage = "InterfacePage" Then
		Return Items.Interface;
	Else
		Return Items.OtherSettings;
	EndIf;
	
EndFunction

&AtClient
Function CopiedOrDeletedSettingsCount(SettingsTree)
	
	SelectedRows = SettingsTree.SelectedRows;
	// Moving the array of selected rows to a value list in order to sort the selected rows.
	SelectedRowsList = New ValueList;
	For Each Item In SelectedRows Do
		SelectedRowsList.Add(Item);
	EndDo;
	
	SelectedRowsList.SortByValue();
	If SelectedSettingsPage = "ReportSettingsPage" Then
		CurrentValueTree = ReportsSettings;
	ElsIf SelectedSettingsPage = "InterfacePage" Then
		CurrentValueTree = Interface;
	Else
		CurrentValueTree = OtherSettings;
	EndIf;
	
	SettingsCount = 0;
	For Each SelectedRow In SelectedRowsList Do
		TreeItem = CurrentValueTree.FindByID(SelectedRow.Value);
		SubordinateItemsCount = TreeItem.GetItems().Count();
		ItemParent = TreeItem.GetParent();
		
		If SubordinateItemsCount <> 0 Then
			SettingsCount = SettingsCount + SubordinateItemsCount;
			TopLevelItem = TreeItem;
		ElsIf SubordinateItemsCount = 0
			And ItemParent = Undefined Then
			SettingsCount = SettingsCount + 1;
		Else
			
			If ItemParent <> TopLevelItem Then
				SettingsCount = SettingsCount + 1;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return SettingsCount;
EndFunction

&AtClient
Procedure DeleteSettingsRow(SettingsTree, SelectedRow)
	
	SettingsItem = SettingsTree.FindByID(SelectedRow);
	If SettingsItem = Undefined Then
		Return;
	EndIf;
	
	SettingsItemParent = SettingsItem.GetParent();
	If SettingsItemParent <> Undefined Then
		
		SubordinateRowsCount = SettingsItemParent.GetItems().Count();
		If SubordinateRowsCount = 1 Then
			
			If SettingsItemParent.Type <> "PersonalOption" Then
				SettingsTree.GetItems().Delete(SettingsItemParent);
			EndIf;
			
		Else
			SettingsItemParent.GetItems().Delete(SettingsItem);
		EndIf;
		
	Else
		SettingsTree.GetItems().Delete(SettingsItem);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyDeletion(SettingsCount, SettingName1 = Undefined, UsersCount = Undefined)
	
	SubjectInWords = Format(SettingsCount, "NFD=0") + " "
		+ UsersInternalClientServer.IntegerSubject(SettingsCount,
			"", NStr("en = 'setting,settings,,,0';"));
	
	If SettingsCount = 1
	   And UsersCount = Undefined Then
		
		ExplanationText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '""%1"" cleared for user ""%2.""';"), SettingName1, String(UserRef));
		
	ElsIf UsersCount = Undefined Then
		ExplanationText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 cleared for user ""%2.""';"), SubjectInWords, String(UserRef));
	EndIf;
	
	ClearSettingsForNote = UsersInternalClient.UsersNote(
		UsersCount, String(UserRef));
	
	If UsersCount <> Undefined Then
		
		If SettingsCount = 1 Then
			ExplanationText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '""%1"" cleared for %2';"), SettingName1, ClearSettingsForNote);
		Else
			ExplanationText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 cleared for %2';"), SubjectInWords, ClearSettingsForNote);
		EndIf;
		
	EndIf;
	
	ShowUserNotification(NStr("en = 'Clear settings';"),
		, ExplanationText, PictureLib.DialogInformation);
	
EndProcedure

&AtClient
Procedure CopySettings()
	
	SettingsTree = SelectedSettingsPageFormTable();
	If SettingsTree.SelectedRows.Count() = 0 Then
		ShowMessageBox(,
			NStr("en = 'Select the settings to copy.';"));
		Return;
	ElsIf SettingsTree.SelectedRows.Count() = 1 Then
		
		If SettingsTree.CurrentData.Type = "PersonalOption" Then
			ShowMessageBox(,
				NStr("en = 'Cannot copy a personal report option.
			               |To make the personal report option available to other users,
			               |save it with ""Available to author only"" check box cleared.';"));
			Return;
		ElsIf SettingsTree.CurrentData.Type = "SettingsItemPersonal" Then
			ShowMessageBox(,
				NStr("en = 'Cannot copy the setting of a personal report option.
			               |Copying settings of personal report options is not supported.';"));
			Return;
		EndIf;
		
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("User", UserRef);
	FormParameters.Insert("ActionType",  "");
	SelectUsers(FormParameters);
	
EndProcedure

&AtServer
Function SettingsGettingResult()
	
	If Not ValueIsFilled(UserRef) Then
		UserRef = Catalogs.Users.EmptyRef();
		InfoBaseUser = Undefined;
	Else
		InfoBaseUser = DataProcessors.UsersSettings.IBUserName(
			UserRef);
	EndIf;
	
	If InfoBaseUser = Undefined Then
		Return "NoIBUser";
	EndIf;
	
	Return "Success";
	
EndFunction

&AtServer
Function SettingsTreeForSelectedPage()
	
	If SelectedSettingsPage = "ReportSettingsPage" Then
		Return ReportsSettings;
	ElsIf SelectedSettingsPage = "InterfacePage" Then
		Return Interface;
	Else
		Return OtherSettings;
	EndIf;
	
EndFunction

&AtServer
Function SettingsStorageForSelectedPage()
	
	If SelectedSettingsPage = "ReportSettingsPage" Then
		Return "ReportsUserSettingsStorage";
	ElsIf SelectedSettingsPage = "InterfacePage"
		Or SelectedSettingsPage = "OtherSettingsPage" Then
		Return "SystemSettingsStorage";
	EndIf;
	
EndFunction

&AtServer
Function SelectedSettingsItems()
	
	If SelectedSettingsPage = "ReportSettingsPage" Then
		Return Items.ReportSettingsTree.SelectedRows;
	ElsIf SelectedSettingsPage = "InterfacePage" Then
		Return Items.Interface.SelectedRows;
	Else
		Return Items.OtherSettings.SelectedRows;
	EndIf;
	
EndFunction

&AtServer
Function SelectedSettings1()
	
	SettingsTree = SettingsTreeForSelectedPage();
	SettingsArray = New Array;
	PersonalSettingsArray = New Array;
	ReportOptionArray = New Array;
	UserSettingsArray = New Array;
	CurrentReportOption = Undefined;
	
	SelectedItems = SelectedSettingsItems();
	
	For Each SelectedItem In SelectedItems Do
		SelectedSetting = SettingsTree.FindByID(SelectedItem);
		
		// Filling the array of personal settings.
		If SelectedSetting.Type = "PersonalSettings" Then
			PersonalSettingsArray.Add(SelectedSetting.Keys);
			Continue;
		EndIf;
		
		// Filling the array of other user settings.
		If SelectedSetting.Type = "OtherUserSettingsItem1" Then
			OtherUserSettings = New Structure;
			OtherUserSettings.Insert("SettingID", SelectedSetting.RowType);
			OtherUserSettings.Insert("SettingValue",      SelectedSetting.Keys);
			UserSettingsArray.Add(OtherUserSettings);
			Continue;
		EndIf;
		
		// Marking personal settings in the list of keys.
		If SelectedSetting.Type = "PersonalOption" Then
			
			For Each Item In SelectedSetting.Keys Do
				Item.Check = True;
			EndDo;
			CurrentReportOption = SelectedSetting.Keys.Copy();
			// Filling the array of user-defined report options.
			ReportOptionArray.Add(SelectedSetting.Keys);
			
		ElsIf SelectedSetting.Type = "StandardOptionPersonal" Then
			ReportOptionArray.Add(SelectedSetting.Keys);
		EndIf;
		
		If SelectedSetting.Type = "SettingsItemPersonal" Then
			
			If CurrentReportOption <> Undefined
			   And CurrentReportOption.FindByValue(SelectedSetting.Keys[0].Value) <> Undefined Then
				
				Continue;
			Else
				SelectedSetting.Keys[0].Check = True;
				SettingsArray.Add(SelectedSetting.Keys);
				Continue;
			EndIf;
			
		EndIf;
		
		SettingsArray.Add(SelectedSetting.Keys);
		
	EndDo;
	
	Result = New Structure;
	Result.Insert("SettingsArray", SettingsArray);
	Result.Insert("PersonalSettingsArray", PersonalSettingsArray);
	Result.Insert("ReportOptionArray", ReportOptionArray);
	Result.Insert("UserSettingsArray", UserSettingsArray);
	
	Return Result;
EndFunction

&AtServer
Function TimeConsumingOperationParameters()
	
	TimeConsumingOperationParameters = New Structure;
	TimeConsumingOperationParameters.Insert("FormName");
	TimeConsumingOperationParameters.Insert("SettingsOperation");
	TimeConsumingOperationParameters.Insert("InfoBaseUser");
	TimeConsumingOperationParameters.Insert("UserRef");
	
	FillPropertyValues(TimeConsumingOperationParameters, ThisObject);
	
	TimeConsumingOperationParameters.Insert("ReportSettingsTree",
		FormAttributeToValue("ReportsSettings"));
	
	TimeConsumingOperationParameters.Insert("InterfaceSettings2",
		FormAttributeToValue("Interface"));
	
	TimeConsumingOperationParameters.Insert("OtherSettingsTree",
		FormAttributeToValue("OtherSettings"));
	
	TimeConsumingOperationParameters.Insert("UserReportOptions",
		FormAttributeToValue("UserReportOptionTable"));
	
	Return TimeConsumingOperationParameters;
	
EndFunction

#EndRegion
