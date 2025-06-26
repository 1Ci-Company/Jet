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
Var CurrentContext;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	URL = "e1cib/app/CommonForm.Extensions";
	
	If Not AccessRight("Administration", Metadata) Then
		Items.ExtensionsListSafeModeFlag.ReadOnly = True;
	EndIf;
	
	Items.FormInstalledPatches.Visible = 
		Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate");
	
	If Not AccessRight("ConfigurationExtensionsAdministration", Metadata) Then
		Items.ExtensionsListUpdate.LocationInCommandBar = ButtonLocationInCommandBar.InCommandBar;
		Items.ExtensionsList.ReadOnly = True;
		Items.ExtensionsListAdd.Visible = False;
		Items.ExtensionsListDelete.Visible = False;
		Items.ExtensionsListUpdateFromFile.Visible = False;
		Items.ExtensionsListSaveAs.Visible = False;
		Items.ExtensionsListContextMenuAdd.Visible = False;
		Items.ExtensionsListContextMenuDelete.Visible = False;
		Items.ExtensionsListContextMenuUpdateFromFile.Visible = False;
		Items.ExtensionsListContextMenuSaveAs.Visible = False;
		Items.FormInstalledPatches.Visible = False;
		Items.CheckIfAllExtensionsCanBeApplied.Visible = False;
		Items.SubmenuEnableExtensions.Visible = False;
		Items.SubmenuTransferToSubordinateDIBNodes.Visible = False;
		Items.SubmenuSafeMode.Visible = False;
		Items.SetEmployeeResponsible.Visible = False;
		Items.ExtensionsListEmployeeResponsible.Visible = False;
		Items.ExtensionsListHasComment.Visible = False;
		Items.ExtensionsListComment.Visible = False;
	EndIf;
	
	Items.ExtensionsListCommon.Visible = Common.DataSeparationEnabled() And AccessRight("Administration", Metadata);
	Items.ExtensionsListReceivedFromMasterDIBNode.Visible = Common.IsSubordinateDIBNode();
	Items.ExtensionsListPassToSubordinateDIBNodes.Visible = Common.IsDistributedInfobase();
	
	UpdateList();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetCommandBarButtonAvailability()
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "LoggedOffFromDataArea" 
		Or EventName = "LoggedOnToDataArea" Then
		
		AttachIdleHandler("UpdateListIdleHandler", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure WarningDetailsURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	Exit(False, True);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersExtensionsList

&AtClient
Procedure ExtensionsListSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Field.Name="ExtensionsListHasComment" Then
		CurrentItem = Items.ExtensionsListComment;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExtensionsListOnActivateRow(Item)
	
	SetCommandBarButtonAvailability();
	
EndProcedure

&AtClient
Procedure ExtensionsListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	Cancel = True;
	LoadExtension(Undefined, True);
	
EndProcedure

&AtClient
Procedure ExtensionsListBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	DeleteExtensions(Item.SelectedRows);
	
EndProcedure

&AtClient
Procedure ExtensionsListSafeModeFlagOnChange(Item)
	
	CurrentExtension = Items.ExtensionsList.CurrentData;
	If CurrentExtension = Undefined Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("RowID", CurrentExtension.GetID());
	
	ShowTimeConsumingOperation();
	CurrentContext = Context;
	AttachIdleHandler("ExtensionsListSafeModeFlagOnChangeCompletion", 0.1, True);
	
EndProcedure

&AtClient
Procedure ExtensionsListAttachOnChange(Item)
	
	CurrentExtension = Items.ExtensionsList.CurrentData;
	If CurrentExtension = Undefined Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("RowID", CurrentExtension.GetID());
	
	If Not CurrentExtension.Attach
	   And IsExtensionWithData(CurrentExtension.ExtensionID) Then
		
		Notification = New NotifyDescription("DetachExtensionAfterConfirmation", ThisObject, Context);
		UsersInternalClient.ShowSecurityWarning(Notification,
			UsersInternalClientServer.SecurityWarningKinds().BeforeDisableExtensionWithData);
	Else
		ExtensionsListAttachOnChangeFollowUp(Context);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExtensionsListPassToSubordinateDIBNodesOnChange(Item)
	
	CurrentExtension = Items.ExtensionsList.CurrentData;
	If CurrentExtension = Undefined Then
		Return;
	EndIf;
	
	ExtensionsListSendToSubordinateDIBNodesOnChangeAtServer(CurrentExtension.GetID());
	
EndProcedure

&AtClient
Procedure ExtensionsListEmployeeResponsibleOnChange(Item)
	
	CurrentExtension = Items.ExtensionsList.CurrentData;
	SaveExtensionsProperties(CurrentExtension.ExtensionID, ExtensionProperties(CurrentExtension));
	
EndProcedure

&AtClient
Procedure ExtensionsListCommentOnChange(Item)
	
	CurrentExtension = Items.ExtensionsList.CurrentData;
	CurrentExtension.HasComment = ValueIsFilled(CurrentExtension.Comment);
	SaveExtensionsProperties(CurrentExtension.ExtensionID, ExtensionProperties(CurrentExtension));
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Refresh(Command)
	
	UpdateList();
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	SelectedRows = Items.ExtensionsList.SelectedRows;
	NotifyDescription = New NotifyDescription("SaveAsCompletion", ThisObject, SelectedRows);
	
	If SelectedRows.Count() = 0 Then
		Return;
	ElsIf SelectedRows.Count() = 1 Then
		FilesToSave = SaveAtServer(SelectedRows);
	Else
		Title = NStr("en = 'Select directory';");
		FileSystemClient.SelectDirectory(NotifyDescription, Title);
		Return;
	EndIf;
	
	If FilesToSave.Count() = 0 Then
		Return;
	EndIf;
	
	SavingParameters = FileSystemClient.FileSavingParameters();
	SavingParameters.Dialog.Title = NStr("en = 'Select file';");
	SavingParameters.Dialog.Filter    = NStr("en = 'Configuration extension files (*.cfe)|*.cfe';") + "|"
			+ StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'All files (%1)|%1';"), GetAllFilesMask());
	
	FileSystemClient.SaveFiles(Undefined, FilesToSave, SavingParameters);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnHardDrive(Command)
	
	CurrentExtension = Items.ExtensionsList.CurrentData;
	
	If CurrentExtension = Undefined Then
		Return;
	EndIf;
	
	LoadExtension(Items.ExtensionsList.SelectedRows);
	
EndProcedure

&AtClient
Procedure ShowEventsBackgroundUpdateSettingsExtensionsJob(Command)
	
	EventFilter = New Structure;
	EventFilter.Insert("EventLogEvent", ParameterFillingEventName());
	
	EventLogClient.OpenEventLog(EventFilter, ThisObject);
	
EndProcedure

&AtClient
Procedure RunUpdateSettingsExtensionsWorkInBackground(Command)
	
	WarningText = "";
	RunUpdateSettingsExtensionsWorkInBackgroundOnServer(WarningText);
	
	ShowMessageBox(, WarningText);
	
EndProcedure

&AtClient
Procedure DeleteObsoleteParametersWorkExtensions(Command)
	
	DeleteDeprecatedSettingsExtensionsWorkOnServer();
	ShowMessageBox(, NStr("en = 'Obsolete versions of extension parameters are deleted.';"));
	
EndProcedure

&AtClient
Procedure InstalledPatches(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleConfigurationUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
		ModuleConfigurationUpdateClient.ShowInstalledPatches();
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckIfAllExtensionsCanBeApplied(Command)
	
	Result = ResultOfAllExtensionsApplicabilityCheck();
	
	If Result.IssuesCount = 0 Then
		QuestionFormParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionFormParameters.Picture = PictureLib.DialogInformation;
		QuestionFormParameters.PromptDontAskAgain = False;
		QuestionFormParameters.Title = NStr("en = 'Result of extensions applicability check';");
		StandardSubsystemsClient.ShowQuestionToUser(Undefined,
			NStr("en = 'The extensions applicability check is passed.';"),
			QuestionDialogMode.OK,
			QuestionFormParameters);
	Else
		Result.InfoOnIssues.Show(NStr("en = 'The extension check result.';"));
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableExtensions(Command)
	
	ShowTimeConsumingOperation();
	AttachIdleHandler("EnableAttachExtensions", 0.1, True);
	
EndProcedure

&AtClient
Procedure DisableExtensions(Command)
	
	ShowTimeConsumingOperation();
	AttachIdleHandler("DisableAttachExtensions", 0.1, True);
	
EndProcedure

&AtClient
Procedure EnableTransferToSubordinateDIBNodes(Command)
	
	ShowTimeConsumingOperation();
	AttachIdleHandler("EnableTransferToSubordinateDIBNodesCompletion", 0.1, True);
	
EndProcedure

&AtClient
Procedure DisableTransferToSubordinateDIBNodes(Command)
	
	ShowTimeConsumingOperation();
	AttachIdleHandler("DisableTransferToSubordinateDIBNodesCompletion", 0.1, True);
	
EndProcedure

&AtClient
Procedure EnableSafeMode(Command)
	
	ShowTimeConsumingOperation();
	AttachIdleHandler("EnableSafeModeCompletion", 0.1, True);
	
EndProcedure

&AtClient
Procedure DisableSafeMode(Command)
		
	ShowTimeConsumingOperation();
	AttachIdleHandler("DisableSafeModeCompletion", 0.1, True);
	
EndProcedure

&AtClient
Procedure SetEmployeeResponsible(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CloseOnChoice", True);
	FormParameters.Insert("MultipleChoice", False);
	FormParameters.Insert("AdvancedPick", False);
	
	Notification = New NotifyDescription("SetAssigneeAfterSelection", ThisObject);
	
	OpenForm("Catalog.Users.ChoiceForm", FormParameters, ThisObject,,,, Notification,
		FormWindowOpeningMode.LockOwnerWindow);	

EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure UpdateListIdleHandler()
	
	UpdateList();
	
EndProcedure

&AtServer
Procedure UpdateList(AfterAdd = False)
	
	If AfterAdd Then
		CurrentRowIndex = ExtensionsList.Count();
	Else
		CurrentRowIndex = 0;
		CurrentRowID = Items.ExtensionsList.CurrentRow;
		If CurrentRowID <> Undefined Then
			String = ExtensionsList.FindByID(CurrentRowID);
			If String <> Undefined Then
				CurrentRowIndex = ExtensionsList.IndexOf(String);
			EndIf;
		EndIf;
	EndIf;
	
	ExtensionsList.Clear();
	
	SetPrivilegedMode(True);
	Extensions = ConfigurationExtensions.Get();
	AttachedExtensions = ExtensionsIDs(ConfigurationExtensionsSource.SessionApplied);
	DetachedExtensions  = ExtensionsIDs(ConfigurationExtensionsSource.SessionDisabled);
	SetPrivilegedMode(False);
	
	ModuleConfigurationUpdate = Undefined;
	If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then 
		ModuleConfigurationUpdate = Common.CommonModule("ConfigurationUpdate");
	EndIf;
	
	DontOutputCommonExtensions = Common.DataSeparationEnabled() And Not AccessRight("Administration", Metadata);
	SerialNumber = 1;
	For Each Extension In Extensions Do
		
		If DontOutputCommonExtensions 
			And (Extension.Scope = ConfigurationExtensionScope.InfoBase) Then
			Continue;
		EndIf;
			
		If ModuleConfigurationUpdate <> Undefined And ModuleConfigurationUpdate.IsPatch(Extension) Then 
			Continue;
		EndIf;
			
		ExtensionItem = ExtensionsList.Add();
		ExtensionItem.ExtensionID = Extension.UUID;
		ExtensionItem.Name = Extension.Name;
		ExtensionItem.Version = Extension.Version;
		ExtensionItem.Checksum = Base64String(Extension.HashSum);
		ExtensionItem.Synonym = Extension.Synonym;
		ExtensionItem.Purpose = Extension.Purpose;
		ExtensionItem.SafeMode = Extension.SafeMode;
		ExtensionItem.Attach = Extension.Active;
		ExtensionItem.ReceivedFromMasterDIBNode = Extension.MasterNode <> Undefined;
		ExtensionItem.PassToSubordinateDIBNodes = Extension.UsedInDistributedInfoBase;
		ExtensionItem.SerialNumber = SerialNumber;
		
		ExtensionItem.Common = (Extension.Scope = ConfigurationExtensionScope.InfoBase);
		
		ExtensionItem.AssignmentPriority =
			?(Extension.Purpose = Metadata.ObjectProperties.ConfigurationExtensionPurpose.Patch, 1,
			?(Extension.Purpose = Metadata.ObjectProperties.ConfigurationExtensionPurpose.Customization, 2, 3));
		
		ExtensionKey = Extension.Name + Extension.HashSum + Extension.Scope;	
		If AttachedExtensions[ExtensionKey] <> Undefined Then
			ExtensionItem.Attached = 0;
			ExtensionItem.ActivationState = NStr("en = 'Attached';");
		ElsIf DetachedExtensions[ExtensionKey] <> Undefined Then
			ExtensionItem.Attached = 2;
			ExtensionItem.ActivationState = NStr("en = 'Detached';");
		Else
			ExtensionItem.Attached = 1;
			ExtensionItem.ActivationState = NStr("en = 'Restart required';");
		EndIf;	
			
		If IsBlankString(ExtensionItem.Synonym) Then
			ExtensionItem.Synonym = ExtensionItem.Name;
		EndIf;
		
		If TypeOf(Extension.SafeMode) = Type("Boolean") Then
			ExtensionItem.SafeModeFlag = Extension.SafeMode;
		Else
			ExtensionItem.SafeModeFlag = True;
		EndIf;
		SerialNumber = SerialNumber + 1;
	EndDo;
	ExtensionsList.Sort("ReceivedFromMasterDIBNode DESC, AssignmentPriority, Common DESC, SerialNumber");
	
	If CurrentRowIndex >= ExtensionsList.Count() Then
		CurrentRowIndex = ExtensionsList.Count() - 1;
	EndIf;
	If CurrentRowIndex >= 0 Then
		Items.ExtensionsList.CurrentRow = ExtensionsList.Get(
			CurrentRowIndex).GetID();
	EndIf;
	
	SetPrivilegedMode(True);
	InstalledExtensions = Catalogs.ExtensionsVersions.InstalledExtensions();
	ExtensionsStateChanged = 
		(SessionParameters.InstalledExtensions.MainState <> InstalledExtensions.MainState);
	Items.WarningGroup.Visible = ExtensionsStateChanged;
	SetPrivilegedMode(False);
	
	// Updating the form attribute for conditional formatting.
	IsSharedUserInArea = IsSharedUserInArea();
	
	Items.WarningDetails.Visible = Not IsSharedUserInArea;
	Items.WarningDetails2.Visible = IsSharedUserInArea;
	
	UpdateExtensionsPropertiesInList();
	
EndProcedure

&AtServer
Function ExtensionsIDs(ExtensionSource)
	
	Extensions = ConfigurationExtensions.Get(, ExtensionSource);
	IDs = New Map;
	
	For Each Extension In Extensions Do
		IDs.Insert(Extension.Name + Extension.HashSum + Extension.Scope, True);
	EndDo;
	
	Return IDs;
	
EndFunction

&AtClient
Procedure SaveAsCompletion(PathToDirectory, SelectedRows) Export
	
	FilesToSave = SaveAtServer(SelectedRows, PathToDirectory);
	
	If FilesToSave.Count() = 0 Then
		Return;
	EndIf;
	
	SavingParameters = FileSystemClient.FileSavingParameters();
	SavingParameters.Interactively     = False;
	
	FileSystemClient.SaveFiles(Undefined, FilesToSave, SavingParameters);
	
EndProcedure

&AtServer
Function SaveAtServer(RowsIDs, PathToDirectory = "")
	
	FilesToSave = New Array;
	For Each RowID In RowsIDs Do
		ListLine = ExtensionsList.FindByID(RowID);
		ExtensionID = ListLine.ExtensionID;
		Extension = FindExtension(ExtensionID);
	
		If Extension <> Undefined Then
			If ValueIsFilled(PathToDirectory) Then
				Prefix = PathToDirectory + GetPathSeparator();
			Else
				Prefix = "";
			EndIf;
			Name = Prefix + Extension.Name + "_" + Extension.Version + ".cfe";
			Location = PutToTempStorage(Extension.GetData(), UUID);
			TransferableFileDescription = New TransferableFileDescription(Name, Location);
			FilesToSave.Add(TransferableFileDescription);
		EndIf;
	EndDo;
	
	Return FilesToSave;
	
EndFunction

&AtServerNoContext
Function FindExtension(ExtensionID)
	
	Return Catalogs.ExtensionsVersions.FindExtension(ExtensionID);
	
EndFunction

&AtServer
Procedure RunUpdateSettingsExtensionsWorkInBackgroundOnServer(WarningText)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.ExtensionVersionParameters.EnableFillingExtensionsWorkParameters();
	
	WarningText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '1. Scheduled job
		           |""%1"" is enabled and started.
		           |
		           |2. See the result in the event log in the events
		           |""%2"",
		           |for example, by clicking
		           |""%3"" in the More menu.';"),
		InformationRegisters.ExtensionVersionParameters.TaskNameFillingParameters(),
		InformationRegisters.ExtensionVersionParameters.ParameterFillingEventName(),
		Commands.Find("RunUpdateSettingsExtensionsWorkInBackground").Title);
		
EndProcedure

&AtServer
Procedure DeleteDeprecatedSettingsExtensionsWorkOnServer()
	
	SetPrivilegedMode(True);
	Catalogs.ExtensionsVersions.DeleteObsoleteParametersVersions();
	
EndProcedure

&AtClient
Procedure DeleteExtensions(SelectedRows)
	
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	ExtensionsIDs = New Array;
	RowsToSkip = New Array;
	
	For Each RowID In SelectedRows Do
		ExtensionRow = ExtensionsList.FindByID(RowID);
		
		If ExtensionRow.Common
		   And IsSharedUserInArea
		 Or ExtensionRow.ReceivedFromMasterDIBNode Then
			
			RowsToSkip.Add(RowID);
			Continue;
		EndIf;
		ExtensionsIDs.Add(ExtensionRow.ExtensionID);
	EndDo;
	
	For Each RowID In RowsToSkip Do
		SelectedRows.Delete(SelectedRows.Find(RowID));
	EndDo;
	
	If ExtensionsIDs.Count() = 0 Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("ExtensionsIDs", ExtensionsIDs);
	
	Notification = New NotifyDescription("DeleteExtensionAfterConfirmation", ThisObject, Context);
	WarningKind = ?(HasExtensionWithData(ExtensionsIDs),
		UsersInternalClientServer.SecurityWarningKinds().BeforeDeleteExtensionWithData,
		UsersInternalClientServer.SecurityWarningKinds().BeforeDeleteExtensionWithoutData);
	
	UsersInternalClient.ShowSecurityWarning(Notification,
		WarningKind, ExtensionsIDs.Count() > 1);
	
EndProcedure

&AtClient
Procedure DeleteExtensionAfterConfirmation(Result, Context) Export
	
	If Result <> "Continue" Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("DeleteExtensionFollowUp", ThisObject, Context);
	
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		Queries = RequestsToRevokeExternalModuleUsagePermissions(Context.ExtensionsIDs);
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, ThisObject, Notification);
	Else
		ExecuteNotifyProcessing(Notification, DialogReturnCode.OK);
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteExtensionFollowUp(Result, Context) Export
	
	If Result = DialogReturnCode.OK Then
		ShowTimeConsumingOperation();
		CurrentContext = Context;
		AttachIdleHandler("DeleteExtensionCompletion", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteExtensionCompletion()
	
	Context = CurrentContext;
	
	Try
		DeleteExtensionsAtServer(Context.ExtensionsIDs);
	Except
		ErrorInfo = ErrorInfo();
		AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
		StandardSubsystemsClient.OutputErrorInfo(ErrorInfo);
		Return;
	EndTry;
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	
EndProcedure

&AtServer
Procedure DeleteExtensionsAtServer(ExtensionsIDs)
	
	ErrorText = "";
	Catalogs.ExtensionsVersions.DeleteExtensions(ExtensionsIDs, ErrorText);
	
	UpdateList();
	
	If ValueIsFilled(ErrorText) Then
		Raise ErrorText;
	EndIf;
	
EndProcedure

&AtClient
Procedure DetachExtensionAfterConfirmation(Result, Context) Export
	
	If Result <> "Continue" Then
		
		ListLine = ExtensionsList.FindByID(Context.RowID);
		If ListLine = Undefined Then
			Return;
		EndIf;
		
		ListLine.Attach = Not ListLine.Attach;
		AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
		Return;
	EndIf;
	
	ExtensionsListAttachOnChangeFollowUp(Context);
	
EndProcedure

&AtClient
Procedure ExtensionsListAttachOnChangeFollowUp(Context)
	
	ShowTimeConsumingOperation();
	CurrentContext = Context;
	AttachIdleHandler("ExtensionsListAttachOnChangeCompletion", 0.1, True);
	
EndProcedure

&AtClient
Procedure ExtensionsListAttachOnChangeCompletion()
	
	Context = CurrentContext;
	
	Try
		ExtensionsListAttachOnChangeAtServer(Context.RowID);
	Except
		ErrorInfo = ErrorInfo();
		AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
		ShowMessageBox(, ErrorProcessing.BriefErrorDescription(ErrorInfo));
		Return;
	EndTry;
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	
EndProcedure

&AtClient
Procedure ExtensionsListSafeModeFlagOnChangeCompletion()
	
	Context = CurrentContext;
	
	Try
		ExtensionListSafeModeFlagOnChangeAtServer(Context.RowID);
	Except
		ErrorInfo = ErrorInfo();
		AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
		ShowMessageBox(, ErrorProcessing.BriefErrorDescription(ErrorInfo));
		Return;
	EndTry;
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	
EndProcedure

&AtServer
Function RequestsToRevokeExternalModuleUsagePermissions(ExtensionsIDs)
	
	Return Catalogs.ExtensionsVersions.RequestsToRevokeExternalModuleUsagePermissions(ExtensionsIDs);
	
EndFunction

&AtClient
Procedure ShowTimeConsumingOperation()
	
	Items.RefreshPages.CurrentPage = Items.TimeConsumingOperationPage;
	SetCommandBarButtonAvailability();
	
EndProcedure

&AtClient
Procedure HideTimeConsumingOperation()
	
	Items.RefreshPages.CurrentPage = Items.ExtensionsListPage;
	SetCommandBarButtonAvailability();
	
EndProcedure

&AtClient
Procedure LoadExtension(Val ExtensionID, MultipleChoice = False)
	
	Context = New Structure;
	Context.Insert("ExtensionID", ExtensionID);
	Context.Insert("MultipleChoice", MultipleChoice);
	Context.Insert("SelectedRows", ExtensionID);
	
	Notification = New NotifyDescription("LoadExtensionAfterConfirmation", ThisObject, Context);
	UsersInternalClient.ShowSecurityWarning(Notification,
		UsersInternalClientServer.SecurityWarningKinds().BeforeAddExtensions);
	
EndProcedure

&AtClient
Procedure LoadExtensionAfterConfirmation(Response, Context) Export
	If Response <> "Continue" Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("LoadExtensionAfterPutFiles", ThisObject, Context);
	
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.Dialog.Filter = NStr("en = 'Configuration extensions';")+ " (*.cfe)|*.cfe";
	ImportParameters.Dialog.Title = NStr("en = 'Select configuration extension file';");
	ImportParameters.Dialog.CheckFileExist = True;
	
	ImportParameters.FormIdentifier = UUID;
	FileSystemClient.ImportFiles(Notification, ImportParameters);
	
EndProcedure

&AtClient
Procedure LoadExtensionAfterPutFiles(PlacedFiles, Context) Export
	
	If PlacedFiles = Undefined
	 Or PlacedFiles.Count() = 0 Then
		
		Return;
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleConfigurationUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
		
		If SelectedFilesContainOnlyPatches(PlacedFiles, ModuleConfigurationUpdateClient) Then 
			
			BackupParameters = New Structure;
			BackupParameters.Insert("SelectedFiles", SelectedFilesByDetails(PlacedFiles));
			ModuleConfigurationUpdateClient.ShowUpdateSearchAndInstallation(BackupParameters);
			Return;
			
		ElsIf SelectedFilesContainPatches(PlacedFiles, ModuleConfigurationUpdateClient) Then 
			ShowMessageBox(,
				NStr("en = 'The selected files cannot contain both patches and extensions of other types.';"));
			Return;
		EndIf;
	EndIf;
	
	Context.Insert("PlacedFiles", PlacedFiles);
	
	ClosingNotification1 = New NotifyDescription(
		"LoadExtensionContinuation", ThisObject, Context);
	
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		
		PermissionsRequests = New Array;
		Try
			AddPermissionRequest(PermissionsRequests, PlacedFiles, Context.ExtensionID);
		Except
			ErrorInfo = ErrorInfo();
			ShowMessageBox(, ErrorProcessing.BriefErrorDescription(ErrorInfo));
			Return;
		EndTry;
		
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(
			PermissionsRequests, ThisObject, ClosingNotification1);
	Else
		ExecuteNotifyProcessing(ClosingNotification1, DialogReturnCode.OK);
	EndIf;
	
EndProcedure

// Parameters:
//  PlacedFiles - Array of TransferredFileDescription
//  ModuleConfigurationUpdateClient - CommonModule
//
// Returns:
//  Boolean
//
&AtClient
Function SelectedFilesContainPatches(PlacedFiles, ModuleConfigurationUpdateClient)
	
	For Each FileThatWasPut In PlacedFiles Do 
		File = New File(FileThatWasPut.Name);
		If ModuleConfigurationUpdateClient.IsPatch(File.Name) Then 
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Parameters:
//  PlacedFiles - Array of TransferredFileDescription
//  ModuleConfigurationUpdateClient - CommonModule
//
// Returns:
//  Boolean
//
&AtClient
Function SelectedFilesContainOnlyPatches(PlacedFiles, ModuleConfigurationUpdateClient)
	
	For Each FileThatWasPut In PlacedFiles Do 
		File = New File(FileThatWasPut.Name);
		If Not ModuleConfigurationUpdateClient.IsPatch(File.Name) Then 
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Parameters:
//   PlacedFiles - Array of TransferredFileDescription
//
// Returns:
//  String
//
&AtClient
Function SelectedFilesByDetails(PlacedFiles)
	
	ListOfFiles = New Array;
	
	For Each FileThatWasPut In PlacedFiles Do 
		File = New File(FileThatWasPut.Name);
		ListOfFiles.Add(File.FullName);
	EndDo;
	
	Return StrConcat(ListOfFiles, ", ");
	
EndFunction

&AtClient
Procedure LoadExtensionContinuation(Result, Context) Export
	
	If Result <> DialogReturnCode.OK Then
		Return;
	EndIf;
	
	ShowTimeConsumingOperation();
	CurrentContext = Context;
	AttachIdleHandler("LoadExtensionCompletion", 0.1, True);
	
EndProcedure

&AtClient
Procedure LoadExtensionCompletion()
	
	Context = CurrentContext;
	
	UnattachedExtensions = "";
	ExtensionsChanged = False;
	If Context.Property("NameReplacementConfirmed") Then
		NameReplacementConfirmation = Undefined;
	Else
		NameReplacementConfirmation = New Structure("OldName, NewName", "", "");
	EndIf;
	Try
		ChangeExtensionsAtServer(Context.PlacedFiles,
			Context.SelectedRows, UnattachedExtensions, ExtensionsChanged, NameReplacementConfirmation);
		If ExtensionsToReAdd.Count() > 0 Then
			ToOpenTheFormCompleteTheUserExperience();
		EndIf;
	Except
		ErrorInfo = ErrorInfo();
		AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
		ShowMessageBox(, ErrorProcessing.BriefErrorDescription(ErrorInfo));
		Return;
	EndTry;
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	
	If Not Context.Property("NameReplacementConfirmed")
	   And ValueIsFilled(NameReplacementConfirmation.OldName) Then
		
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Extension ""%1"" will be replaced with extension ""%2"".
			           |
			           |If extension ""%2"" is not an update for extension ""%1"",
			           |refuse to replace it and add extension ""%2"" as a new one.
			           |Note: if you cannot add extension ""%2"" because of extension ""%1"",
			           |delete extension ""%1"" before adding extension ""%2"".';"),
			NameReplacementConfirmation.OldName,
			NameReplacementConfirmation.NewName);
			
		CompletionHandler = New NotifyDescription(
			"LoadExtensionAfterQuestionNameReplacement", ThisObject, Context);
		
		Buttons = New ValueList;
		Buttons.Add("Replace",   NStr("en = 'Replace';"));
		Buttons.Add("NotReplace", NStr("en = 'Do not replace';"));
		
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.DefaultButton = "NotReplace";
		QuestionParameters.PromptDontAskAgain = False;
		
		StandardSubsystemsClient.ShowQuestionToUser(CompletionHandler,
			QueryText, Buttons, QuestionParameters);
		Return;
	EndIf;
	
	If Not ExtensionsChanged Then
		Return;
	EndIf;
	
	If Context.ExtensionID = Undefined Then
		If Context.PlacedFiles.Count() > 1 Then
			NotificationText1 = NStr("en = 'Configuration extensions added';");
		Else
			NotificationText1 = NStr("en = 'Configuration extension added';");
		EndIf;
	Else
		NotificationText1 = NStr("en = 'Configuration extension updated';");
	EndIf;
	
	ShowUserNotification(NotificationText1);
	
	If Not ValueIsFilled(UnattachedExtensions) Then
		Return;
	EndIf;
	
	If Context.PlacedFiles.Count() > 1 Then
		If StrFind(UnattachedExtensions, ",") > 0 Then
			WarningText = NStr("en = 'Cannot attach the following extensions:';");
		Else
			WarningText = NStr("en = 'Cannot attach the extension:';");
		EndIf;
		WarningText = WarningText + " " + UnattachedExtensions;
	Else
		WarningText = NStr("en = 'Cannot attach an extension.';");
	EndIf;
	
	ShowMessageBox(, WarningText);
	
EndProcedure

&AtClient
Procedure LoadExtensionAfterQuestionNameReplacement(Result, Context) Export
	
	If Result = Undefined
	 Or Result.Value <> "Replace" Then
		Return;
	EndIf;
	
	Context.Insert("NameReplacementConfirmed");
	
	ShowTimeConsumingOperation();
	CurrentContext = Context;
	AttachIdleHandler("LoadExtensionCompletion", 0.1, True);
	
EndProcedure

&AtServer
Procedure ChangeExtensionsAtServer(PlacedFiles, RowsIDs,
			UnattachedExtensions, ExtensionsChanged, NameReplacementConfirmation)
			
	ExtensionsToReAdd.Clear();
	Extension = Undefined;
	
	SelectedExtensions = New Structure;
	If RowsIDs <> Undefined Then
		For Each FileThatWasPut In PlacedFiles Do
			BinaryData = GetFromTempStorage(FileThatWasPut.Location);
			ExtensionDetails = New ConfigurationDescription(BinaryData);
			SelectedExtensions.Insert(ExtensionDetails.Name, BinaryData);
		EndDo;
	EndIf;
	
	ExtensionsToCheck = New Map;
	AddedExtensions = New Array;
	SourceExtensions    = New Map;
	
	ErrorText = "";
	AddedExtensionFileName = Undefined;
	Try
		If RowsIDs <> Undefined Then
			For Each RowID In RowsIDs Do
				TableRow = ExtensionsList.FindByID(RowID);
				ExtensionID = TableRow.ExtensionID;
				Extension = FindExtension(ExtensionID);
				If Extension = Undefined Then
					Continue;
				EndIf;
				
				PreviousExtensionName = Extension.Name;
				NewExtensionName = PreviousExtensionName;
				
				If Not SelectedExtensions.Property(PreviousExtensionName) Then
					If RowsIDs.Count() <> 1 Then
						Continue;
					ElsIf NameReplacementConfirmation <> Undefined Then
						NameReplacementConfirmation.OldName = PreviousExtensionName;
						NameReplacementConfirmation.NewName = ExtensionDetails.Name;
						Return;
					Else
						NewExtensionName = ExtensionDetails.Name;
					EndIf;
				EndIf;
				
				ExtensionData = Extension.GetData();
				SourceExtensions.Insert(PreviousExtensionName, ExtensionData);
				
				DisableSecurityWarnings(Extension);
				DisableMainRolesUsageForAllUsers(Extension);
				NewBinaryData = SelectedExtensions[NewExtensionName];
				Errors = Extension.CheckCanApply(NewBinaryData, False);
				For Each Error In Errors Do
					If Error.Severity <> ConfigurationExtensionApplicationIssueSeverity.Critical Then
						Continue;
					EndIf;
					ErrorText = ErrorText + Chars.LF + Error.Description;
				EndDo;
				
				If ValueIsFilled(ErrorText) Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot apply the extension. Reason:
						           |%1';"),
						ErrorText);
					Break;
				Else
					Extension.Write(NewBinaryData);
					Extension = FindExtension(ExtensionID);
					ExtensionsToCheck.Insert(Extension.Name, Extension.Synonym);
				EndIf;
			EndDo;
		Else
			For Each FileThatWasPut In PlacedFiles Do
				FileBinaryData = GetFromTempStorage(FileThatWasPut.Location);
				ExtensionDetails = New ConfigurationDescription(FileBinaryData);
				Filter = New Structure("Name", ExtensionDetails.Name);
				Extensions = ConfigurationExtensions.Get(Filter);
				If Extensions.Count() > 0 Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot add extension ""%1""
						           | from file %2, 
						           |as an extension with this name already exists.';"),
						ExtensionDetails.Name,
						FileThatWasPut.Name);
					Break;
				EndIf;
			EndDo;
			If Not ValueIsFilled(ErrorText) Then
				For Each FileThatWasPut In PlacedFiles Do
					FileBinaryData = GetFromTempStorage(FileThatWasPut.Location);
					ExtensionDetails = New ConfigurationDescription(FileBinaryData);
					Extension = ConfigurationExtensions.Create();
					DisableSecurityWarnings(Extension);
					DisableMainRolesUsageForAllUsers(Extension);
					AddedExtensionFileName = FileThatWasPut.Name;
					Extension.Write(FileBinaryData);
					AddedExtensionFileName = Undefined;
					Extension = FindExtension(String(Extension.UUID));
					AddedExtensions.Insert(0, Extension);
					ExtensionsToCheck.Insert(Extension.Name, Extension.Synonym);
				EndDo;
			EndIf;
		EndIf;
	Except
		ErrorInfo = ErrorInfo();
		If RowsIDs <> Undefined Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot update the extension. Reason:
				           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
			
		ElsIf ValueIsFilled(AddedExtensionFileName) Then
			BriefErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo);
			If IsInfobaseExclusiveLockError(BriefErrorDescription) Then
				
				IndexOfFirstExtensionFailedToAdd = PlacedFiles.Find(FileThatWasPut);
				If IndexOfFirstExtensionFailedToAdd <> Undefined Then
					ExtensionsToReAdd.Clear();
					For IndexOf = IndexOfFirstExtensionFailedToAdd To PlacedFiles.UBound() Do
						ExtensionsToReAdd.Add(PlacedFiles.Get(IndexOf));
					EndDo;
				EndIf;
			Else
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot add extension ""%1""
					           | from file %2. Reason:
					           |%3';"),
					ExtensionDetails.Name,
					AddedExtensionFileName,
					BriefErrorDescription);
			EndIf;
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot add the extension. Reason:
				           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
		EndIf;
	EndTry;
	
	If Not ValueIsFilled(ErrorText) Then
		Try
			InformationRegisters.ExtensionVersionParameters.UpdateExtensionParameters(ExtensionsToCheck, UnattachedExtensions);
			ExtensionsChanged = True;
		Except
			ErrorInfo = ErrorInfo();
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'An unexpected error occurred while preparing the added extensions:
				           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
		EndTry;
	EndIf;
	
	If ValueIsFilled(ErrorText) Then
		RecoveryErrorInformation = Undefined;
		RecoveryPerformed = False;
		Try
			If RowsIDs <> Undefined Then
				For Each ExtensionToCheck In ExtensionsToCheck Do
					ExtensionData = SourceExtensions[ExtensionToCheck.Key];
					Extension = FindExtension(ExtensionID);
					If Extension = Undefined Then
						Extension = ConfigurationExtensions.Create();
					EndIf;
					DisableSecurityWarnings(Extension);
					DisableMainRolesUsageForAllUsers(Extension);
					Extension.Write(ExtensionData);
				EndDo;
				RecoveryPerformed = True;
			Else
				For Each AddedExtension In AddedExtensions Do
					Filter = New Structure("Name", AddedExtension.Name);
					Extensions = ConfigurationExtensions.Get(Filter);
					For Each Extension In Extensions Do
						If Extension.HashSum = AddedExtension.HashSum Then
							Extension.Delete();
							RecoveryPerformed = True;
						EndIf;
					EndDo;
				EndDo;
			EndIf;
		Except
			RecoveryErrorInformation = ErrorInfo();
			If RowsIDs <> Undefined Then
				ErrorText = ErrorText + Chars.LF + Chars.LF
					+ StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'An unexpected error occurred while restoring the changed extension:
						           |%1';"), ErrorProcessing.BriefErrorDescription(RecoveryErrorInformation));
			Else
				ErrorText = ErrorText + Chars.LF + Chars.LF
					+ StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'An unexpected error occurred while trying to delete the added extensions:
						           |%1';"), ErrorProcessing.BriefErrorDescription(RecoveryErrorInformation));
			EndIf;
		EndTry;
		If RecoveryPerformed
		   And RecoveryErrorInformation = Undefined Then
			
			If RowsIDs <> Undefined Then
				If ExtensionsToCheck.Count() > 0 Then
					ErrorText = ErrorText + Chars.LF + Chars.LF
						+ NStr("en = 'The modified extension is restored.';");
				Else
					ErrorText = ErrorText + Chars.LF + Chars.LF
						+ NStr("en = 'The extension is not modified.';");
				EndIf;
			Else
				ErrorText = ErrorText + Chars.LF + Chars.LF
					+ NStr("en = 'The added extensions are deleted.';");
			EndIf;
		EndIf;
	EndIf;
	
	If ValueIsFilled(ErrorText) Then
		Raise ErrorText;
	EndIf;
	
	UpdateList(ExtensionID = Undefined);
	
EndProcedure

&AtServer
Procedure ExtensionListSafeModeFlagOnChangeAtServer(RowID)
	
	ListLine = ExtensionsList.FindByID(RowID);
	If ListLine = Undefined Then
		Return;
	EndIf;
	
	Extension = FindExtension(ListLine.ExtensionID);
	
	If Extension = Undefined
	 Or Extension.SafeMode = ListLine.SafeModeFlag Then
		
		UpdateList();
		Return;
	EndIf;
	
	Extension.SafeMode = ListLine.SafeModeFlag;
	DisableSecurityWarnings(Extension);
	DisableMainRolesUsageForAllUsers(Extension);
	Try
		Extension.Write();
	Except
		ListLine.SafeModeFlag = Not ListLine.SafeModeFlag;
		Raise;
	EndTry;
	
	Try
		InformationRegisters.ExtensionVersionParameters.UpdateExtensionParameters();
	Except
		ErrorInfo = ErrorInfo();
		If Extension.SafeMode Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'An unexpected error occurred while preparing the extensions (after enabling the safe mode):
				           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'An unexpected error occurred while preparing the extensions (after disabling the safe mode):
				           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
		EndIf;
	EndTry;
	
	If ValueIsFilled(ErrorText) Then
		RecoveryErrorInformation = Undefined;
		Try
			Extension.SafeMode = Not Extension.SafeMode;
			Extension.Write();
		Except
			RecoveryErrorInformation = ErrorInfo();
			ErrorText = ErrorText + Chars.LF + Chars.LF
				+ StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'An unexpected error occurred when trying to cancel the change of the safe extension mode check box:
					           |%1';"), ErrorProcessing.BriefErrorDescription(RecoveryErrorInformation));
		EndTry;
		If RecoveryErrorInformation = Undefined Then
			ListLine.SafeModeFlag = Extension.SafeMode;
			ErrorText = ErrorText + Chars.LF + Chars.LF
				+ NStr("en = 'The change of the ""Safe mode"" extension parameter is canceled.';");
		EndIf;
	EndIf;
	
	UpdateList();
	
	If ValueIsFilled(ErrorText) Then
		Raise ErrorText;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function HasExtensionWithData(ExtensionsIDs)
	
	For Each ExtensionID In ExtensionsIDs Do
		If IsExtensionWithData(ExtensionID) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

&AtServerNoContext
Function IsExtensionWithData(ExtensionID)
	
	Extension = FindExtension(ExtensionID);
	
	If Extension = Undefined Then
		Return False;
	EndIf;
	
	Return Extension.ModifiesDataStructure();
	
EndFunction

&AtServer
Procedure ExtensionsListAttachOnChangeAtServer(RowID)
	
	ListLine = ExtensionsList.FindByID(RowID);
	If ListLine = Undefined Then
		Return;
	EndIf;
	
	CurrentUsage = ListLine.Attach;
	Try
		Catalogs.ExtensionsVersions.ToggleExtensionUsage(ListLine.ExtensionID, CurrentUsage);
	Except
		ListLine.Attach = Not ListLine.Attach;
		UpdateList();
		
		Raise;
	EndTry;
	
	UpdateList();
	
EndProcedure

&AtServer
Procedure ExtensionsListSendToSubordinateDIBNodesOnChangeAtServer(RowID)
	
	ListLine = ExtensionsList.FindByID(RowID);
	
	If ListLine = Undefined Then
		Return;
	EndIf;
	
	Extension = FindExtension(ListLine.ExtensionID);
	
	If Extension <> Undefined Then
	
		If Extension.UsedInDistributedInfoBase <> ListLine.PassToSubordinateDIBNodes Then
			Extension.UsedInDistributedInfoBase = ListLine.PassToSubordinateDIBNodes;
			
			DisableSecurityWarnings(Extension);
			DisableMainRolesUsageForAllUsers(Extension);
			Try
				Extension.Write();
			Except
				ListLine.PassToSubordinateDIBNodes = Not ListLine.PassToSubordinateDIBNodes;
				Raise;
			EndTry;
		EndIf;
		
	EndIf;
	
	UpdateList();
	
EndProcedure

&AtServer
Procedure AddPermissionRequest(PermissionsRequests, PlacedFiles, ExtensionID = Undefined)
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	If Not ModuleSafeModeManager.UseSecurityProfiles() Then
		Return;
	EndIf;
	Permissions = New Array;
	
	For Each FileThatWasPut In PlacedFiles Do
		UpdatedExtensionData = Undefined;
		RecoveryRequired = False;
		Try
			If ExtensionID = Undefined Then
				TemporaryExtension = ConfigurationExtensions.Create();
			Else
				TemporaryExtension = FindExtension(ExtensionID);
				If TemporaryExtension = Undefined Then
					Raise StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The app does not have extensions with the id ""%1"". Probably, the extension was deleted by another user.';"),
						ExtensionID);
				EndIf;
				UpdatedExtensionData = TemporaryExtension.GetData();
			EndIf;
			DisableSecurityWarnings(TemporaryExtension);
			DisableMainRolesUsageForAllUsers(TemporaryExtension);
			ExtensionData = GetFromTempStorage(FileThatWasPut.Location);
			TemporaryExtension.Write(ExtensionData);
			RecoveryRequired = True;
			TemporaryExtension = FindExtension(String(TemporaryExtension.UUID));
			TemporaryExtensionProperties = New Structure;
			TemporaryExtensionProperties.Insert("Name",      TemporaryExtension.Name);
			TemporaryExtensionProperties.Insert("HashSum", TemporaryExtension.HashSum);
			If ExtensionID = Undefined Then
				TemporaryExtension.Delete();
			Else
				TemporaryExtension = FindExtension(ExtensionID);
				If TemporaryExtension = Undefined Then
					TemporaryExtension = ConfigurationExtensions.Create();
				EndIf;
				DisableSecurityWarnings(TemporaryExtension);
				DisableMainRolesUsageForAllUsers(TemporaryExtension);
				TemporaryExtension.Write(UpdatedExtensionData);
			EndIf;
			RecoveryRequired = False;
			
			Permissions.Add(ModuleSafeModeManager.PermissionToUseExternalModule(
				TemporaryExtensionProperties.Name, Base64String(TemporaryExtensionProperties.HashSum)));
				
		Except
			ErrorInfo = ErrorInfo();
			If ExtensionID = Undefined Then
				If PlacedFiles.Count() > 1 Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Cannot add extensions from the file
							           |""%1""
							           |when receiving permissions due to:
							           |%2';"),
							FileThatWasPut.Name,
							ErrorProcessing.BriefErrorDescription(ErrorInfo));
				Else
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Cannot add the extension when receiving permissions due to:
							           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
				EndIf;
			Else
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot update the extension when receiving permissions due to:
						           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
			EndIf;
			If RecoveryRequired Then
				Try
					If ExtensionID = Undefined Then
						TemporaryExtension.Delete();
					Else
						TemporaryExtension = FindExtension(ExtensionID);
						If TemporaryExtension = Undefined Then
							TemporaryExtension = ConfigurationExtensions.Create();
						EndIf;
						DisableSecurityWarnings(TemporaryExtension);
						DisableMainRolesUsageForAllUsers(TemporaryExtension);
						TemporaryExtension.Write(UpdatedExtensionData);
					EndIf;
				Except
					ErrorInfo = ErrorInfo();
					If ExtensionID = Undefined Then 
						If PlacedFiles.Count() > 1 Then
							ErrorText = ErrorText + Chars.LF + Chars.LF
								+ StringFunctionsClientServer.SubstituteParametersToString(
									NStr("en = 'Cannot delete the added extension from the file when receiving permissions
									           |%1
									           |due to:
									           |%2';"),
									FileThatWasPut.Name,
									ErrorProcessing.BriefErrorDescription(ErrorInfo));
						Else
							ErrorText = ErrorText + Chars.LF + Chars.LF
								+ StringFunctionsClientServer.SubstituteParametersToString(
									NStr("en = 'An unexpected error occurred when trying to delete the temporarily added extension:
									           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
						EndIf;
					Else
						ErrorText = ErrorText + Chars.LF + Chars.LF
							+ StringFunctionsClientServer.SubstituteParametersToString(
								NStr("en = 'An unexpected error occurred when trying to restore the temporarily changed extension:
								           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
					EndIf;
				EndTry;
			EndIf;
			Raise ErrorText;
		EndTry;
	EndDo;
	
	InstalledExtensions = ConfigurationExtensions.Get();
	For Each Extension In InstalledExtensions Do
		Permissions.Add(ModuleSafeModeManager.PermissionToUseExternalModule(
			Extension.Name, Base64String(Extension.HashSum)));
	EndDo;
	
	PermissionsRequests.Add(ModuleSafeModeManager.RequestToUseExternalResources(Permissions,
		Common.MetadataObjectID("InformationRegister.ExtensionVersionParameters")));
	
EndProcedure

&AtServer
Procedure DisableSecurityWarnings(Extension)
	
	Catalogs.ExtensionsVersions.DisableSecurityWarnings(Extension);
	
EndProcedure

&AtServer
Procedure DisableMainRolesUsageForAllUsers(Extension)
	
	Catalogs.ExtensionsVersions.DisableMainRolesUsageForAllUsers(Extension);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Setting ViewOnly appearance parameter for common extensions and extensions passed from the master node to the subordinate DIB node.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExtensionsListAttach.Name);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExtensionsListSafeModeFlag.Name);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExtensionsListPassToSubordinateDIBNodes.Name);
	
	FilterItemsGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemsGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	FilterItemGroupCommon = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemGroupCommon.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = FilterItemGroupCommon.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExtensionsList.Common");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = FilterItemGroupCommon.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IsSharedUserInArea");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExtensionsList.ReceivedFromMasterDIBNode");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
EndProcedure

&AtClient
Procedure SetCommandBarButtonAvailability()
	
	If Items.RefreshPages.CurrentPage = Items.TimeConsumingOperationPage Then 
		
		Items.ExtensionsListAdd.Enabled = False;
		Items.ExtensionsListDelete.Enabled = False;
		Items.ExtensionsListUpdateFromFile.Enabled = False;
		
		Items.ExtensionsListContextMenuAdd.Enabled = False;
		Items.ExtensionsListContextMenuDelete.Enabled = False;
		Items.ExtensionsListContextMenuUpdateFromFile.Enabled = False;
		
	ElsIf Items.RefreshPages.CurrentPage = Items.ExtensionsListPage Then 
		
		OneRowSelected = Items.ExtensionsList.SelectedRows.Count() = 1;
		
		CanEdit1 = True;
		If OneRowSelected Then 
			CurrentExtension = Items.ExtensionsList.CurrentData;
			
			CanEdit1 = (Not CurrentExtension.Common 
				Or Not IsSharedUserInArea())
				And Not CurrentExtension.ReceivedFromMasterDIBNode;
		EndIf;
		
		Items.ExtensionsListAdd.Enabled = True;
		Items.ExtensionsListDelete.Enabled = CanEdit1;
		Items.ExtensionsListUpdateFromFile.Enabled = CanEdit1;
		
		Items.ExtensionsListContextMenuAdd.Enabled = True;
		Items.ExtensionsListContextMenuDelete.Enabled = CanEdit1;
		Items.ExtensionsListContextMenuUpdateFromFile.Enabled = OneRowSelected And CanEdit1;
		
		AttachIdleHandler("SetTitleToCommentItem", 0.1, True);

	EndIf;
	
EndProcedure

&AtServerNoContext
Function IsSharedUserInArea()
	
	Return StandardSubsystemsServer.ThisIsSplitSessionModeWithNoDelimiters();
		
EndFunction

&AtServerNoContext
Function ParameterFillingEventName()
	
	Return InformationRegisters.ExtensionVersionParameters.ParameterFillingEventName();
	
EndFunction

&AtServerNoContext
Function ResultOfAllExtensionsApplicabilityCheck()
	
	InfoOnApplyingIssues = ConfigurationExtensions.CheckCanApplyAll();
	
	Result = New Structure;
	Result.Insert("IssuesCount", InfoOnApplyingIssues.Count());
	Result.Insert("InfoOnIssues", New TextDocument);

	If InfoOnApplyingIssues.Count() = 0 Then
		Return Result;
	EndIf;
	
	ProblematicExtensions = New Map;
	
	For Each Issue1 In InfoOnApplyingIssues Do
		InfoOnIssue = ProblematicExtensions.Get(Issue1.Extension);
		If InfoOnIssue = Undefined Then
			Text = Issue1.Extension.Synonym;
		Else
			Text = InfoOnIssue;
		EndIf;
		Text = Text + Chars.LF + Chars.Tab + "(" + String(Issue1.Severity) + ")" + " " + Issue1.Description;
		ProblematicExtensions.Insert(Issue1.Extension, Text);
	EndDo;
	
	For Each Extension In ProblematicExtensions Do
		Result.InfoOnIssues.AddLine(Extension.Value);
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure EnableSafeModeCompletion()
	
	ExtensionsModificationErrors = New Array;
	ToggleSafeModeForSelectedExtensions(True, ExtensionsModificationErrors);
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	OutputErrorsInfoOnExtensionsReconfiguration(ExtensionsModificationErrors);
	
EndProcedure

&AtClient
Procedure DisableSafeModeCompletion()
	
	ExtensionsModificationErrors = New Array;
	ToggleSafeModeForSelectedExtensions(False, ExtensionsModificationErrors);
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	OutputErrorsInfoOnExtensionsReconfiguration(ExtensionsModificationErrors);
	
EndProcedure

&AtServer
Procedure ToggleSafeModeForSelectedExtensions(Value, ExtensionsModificationErrors)
	
	For Each RowID In Items.ExtensionsList.SelectedRows Do
		ListLine = ExtensionsList.FindByID(RowID);
		If ListLine = Undefined Then
			Continue;
		EndIf;
		
		ListLine.SafeModeFlag = Value;
		
		Extension = FindExtension(ListLine.ExtensionID);
		
		If Extension = Undefined
			Or Extension.SafeMode = ListLine.SafeModeFlag Then
			Continue;
		EndIf;
		
		Extension.SafeMode = ListLine.SafeModeFlag;
		DisableSecurityWarnings(Extension);
		DisableMainRolesUsageForAllUsers(Extension);
		Try
			Extension.Write();
		Except
			ListLine.SafeModeFlag = Not ListLine.SafeModeFlag;
			IssueDetails = ListLine.Synonym + ": " + ErrorProcessing.BriefErrorDescription(ErrorInfo());
			ExtensionsModificationErrors.Add(IssueDetails);
		EndTry;
		
	EndDo;
	
	InformationRegisters.ExtensionVersionParameters.UpdateExtensionParameters();
	
EndProcedure

&AtClient
Procedure OutputErrorsInfoOnExtensionsReconfiguration(ExtensionsModificationErrors)
	If ExtensionsModificationErrors.Count() = 0 Then
		Return;
	EndIf;
	
	ErrorInformation_ = "";
	For Each StringError In ExtensionsModificationErrors Do
		ErrorInformation_ = ?(ValueIsFilled(ErrorInformation_), ErrorInformation_ + Chars.LF + Chars.LF + StringError, StringError);
	EndDo;
	
	QuestionFormParameters = StandardSubsystemsClient.QuestionToUserParameters();
	QuestionFormParameters.Picture = PictureLib.DialogExclamation;
	QuestionFormParameters.PromptDontAskAgain = False;
	QuestionFormParameters.Title = NStr("en = 'Failed to reconfigure some extensions';");
	StandardSubsystemsClient.ShowQuestionToUser(Undefined,
		ErrorInformation_,
		QuestionDialogMode.OK,
		QuestionFormParameters);
	
EndProcedure

&AtClient
Procedure EnableTransferToSubordinateDIBNodesCompletion()
	
	ExtensionsModificationErrors = New Array;
	ToggleTransferToSubordinateDIBNodes(True, ExtensionsModificationErrors);
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	OutputErrorsInfoOnExtensionsReconfiguration(ExtensionsModificationErrors);
	
EndProcedure

&AtClient
Procedure DisableTransferToSubordinateDIBNodesCompletion()
	
	ExtensionsModificationErrors = New Array;
	ToggleTransferToSubordinateDIBNodes(False, ExtensionsModificationErrors);
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	OutputErrorsInfoOnExtensionsReconfiguration(ExtensionsModificationErrors);
	
EndProcedure

&AtServer
Procedure ToggleTransferToSubordinateDIBNodes(Value, ExtensionsModificationErrors)
	
	For Each RowID In Items.ExtensionsList.SelectedRows Do
		ListLine = ExtensionsList.FindByID(RowID);
		If ListLine = Undefined Then
			Continue;
		EndIf;
		
		ListLine.PassToSubordinateDIBNodes = Value;
		
		Extension = FindExtension(ListLine.ExtensionID);
		
		If Extension = Undefined
			Or Extension.UsedInDistributedInfoBase = ListLine.PassToSubordinateDIBNodes Then
			Continue;
		EndIf;
		
		Extension.UsedInDistributedInfoBase = ListLine.PassToSubordinateDIBNodes;
		DisableSecurityWarnings(Extension);
		DisableMainRolesUsageForAllUsers(Extension);
		Try
			Extension.Write();
		Except
			ListLine.PassToSubordinateDIBNodes = Not ListLine.PassToSubordinateDIBNodes;
			IssueDetails = ListLine.Synonym + ": " + ErrorProcessing.BriefErrorDescription(ErrorInfo());
			ExtensionsModificationErrors.Add(IssueDetails);
		EndTry;
		
	EndDo;
	
	UpdateList();
	
EndProcedure

&AtClient
Procedure EnableAttachExtensions()
	
	ExtensionsModificationErrors = New Array;
	ToggleAttachExtensions(True, ExtensionsModificationErrors);
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	OutputErrorsInfoOnExtensionsReconfiguration(ExtensionsModificationErrors);
	
EndProcedure

&AtClient
Procedure DisableAttachExtensions()
	
	ExtensionsSynonyms = ExtensionsSynonymsSelectedExtensionsToDisable();
	If ExtensionsSynonyms.WithData.Count() = 1 And ExtensionsSynonyms.NoData.Count() = 0 Then
		
		CurrentExtension = Items.ExtensionsList.CurrentData;
		If CurrentExtension = Undefined Then
			Return;
		EndIf;
		CurrentExtension.Attach = False;
		Context = New Structure;
		Context.Insert("RowID", CurrentExtension.GetID());
	
		Notification = New NotifyDescription("DetachExtensionAfterConfirmation", ThisObject, Context);
		UsersInternalClient.ShowSecurityWarning(Notification,
			UsersInternalClientServer.SecurityWarningKinds().BeforeDisableExtensionWithData);

	ElsIf ExtensionsSynonyms.WithData.Count() > 0 Then
		
		If ExtensionsSynonyms.WithData.Count() = 1 Then
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'One of the selected extensions stores its data in the app. This data will become unavailable.
				           |The related app data might become unchangeable.
				           |
				           |The extension with data:
				           | - %1';"),
				ExtensionsSynonyms.WithData[0]);
		Else
			ExtensionsWithDataText = StrConcat(ExtensionsSynonyms.WithData, Chars.LF + " - ");
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Some selected extensions store their data in the app. This data will become unavailable.
				           |The related app data might become unchangeable.
				           |
				           |The extensions with data stored in the app:
				           | - %1';"),
				ExtensionsWithDataText);
		EndIf;
			
		CompletionHandler = New NotifyDescription(
			"DisableExtensionsAfterQuestion", ThisObject);
		
		Buttons = New ValueList;
		If ExtensionsSynonyms.NoData.Count() > 0 Then
			Buttons.Add("TurnOffExtensionsWithoutData", NStr("en = 'Disabled only extensions without stored data';"));
			
			If ExtensionsSynonyms.NoData.Count() = 1 Then
				ExtensionsWithoutDataText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'An extension without stored data:
			           | - %1';"),
					ExtensionsSynonyms.NoData[0]);
			Else
				ExtensionsWithoutDataText = StrConcat(ExtensionsSynonyms.NoData, Chars.LF + " - ");
				ExtensionsWithoutDataText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Extensions without stored data:
			           | - %1';"), 
					ExtensionsWithoutDataText);
			EndIf;
			QueryText = QueryText + Chars.LF + Chars.LF + ExtensionsWithoutDataText;
		EndIf;
		Buttons.Add("TurnOffAll", NStr("en = 'Disable all';"));
		Buttons.Add("Cancel", NStr("en = 'Cancel';"));
		
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.Title = NStr("en = 'Warning';");
		QuestionParameters.Picture = PictureLib.DialogExclamation;
		QuestionParameters.DefaultButton = "TurnOffExtensionsWithoutData";
		QuestionParameters.PromptDontAskAgain = False;
		
		StandardSubsystemsClient.ShowQuestionToUser(CompletionHandler,
			QueryText, Buttons, QuestionParameters);
			
	Else
		ExtensionsModificationErrors = New Array;
		ToggleAttachExtensions(False, ExtensionsModificationErrors);
		AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
		OutputErrorsInfoOnExtensionsReconfiguration(ExtensionsModificationErrors);
	EndIf;
	
EndProcedure

&AtServer
Procedure ToggleAttachExtensions(Value, ExtensionsModificationErrors, ShouldHandleExtensionsContainingData = True)
	
	For Each RowID In Items.ExtensionsList.SelectedRows Do
		ListLine = ExtensionsList.FindByID(RowID);
		If ListLine = Undefined Then
			Continue;
		EndIf;
		
		If Not ShouldHandleExtensionsContainingData And IsExtensionWithData(ListLine.ExtensionID) Then
			Continue;
		EndIf;
		
		ListLine.Attach = Value;
		
	Try
		Catalogs.ExtensionsVersions.ToggleExtensionUsage(ListLine.ExtensionID, Value);
	Except
		ListLine.Attach = Not ListLine.Attach;
		IssueDetails = ListLine.Synonym + ": " + ErrorProcessing.BriefErrorDescription(ErrorInfo());
		ExtensionsModificationErrors.Add(IssueDetails);
	EndTry;
		
	EndDo;
	
	UpdateList();
	
EndProcedure

&AtServer
Function ExtensionsSynonymsSelectedExtensionsToDisable()
	
	WithData = New Array;
	NoData = New Array;
	
	For Each RowID In Items.ExtensionsList.SelectedRows Do
		ListLine = ExtensionsList.FindByID(RowID);
		If ListLine = Undefined And ListLine.Attach Then
			Continue;
		EndIf;
		If IsExtensionWithData(ListLine.ExtensionID) Then
			WithData.Add(ListLine.Synonym);
		Else
			NoData.Add(ListLine.Synonym);
		EndIf;
	EndDo;
	
	ExtensionsSynonyms = New Structure;
	ExtensionsSynonyms.Insert("WithData", WithData);
	ExtensionsSynonyms.Insert("NoData", NoData);
	
	Return ExtensionsSynonyms;
	
EndFunction

&AtClient
Procedure DisableExtensionsAfterQuestion(Result, Context) Export
	
	If Result = Undefined Or Result.Value = "Cancel" Then
		AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
		Return;
	ElsIf Result.Value = "TurnOffExtensionsWithoutData" Then
		ShouldHandleExtensionsContainingData = False;
	ElsIf Result.Value = "TurnOffAll" Then
		ShouldHandleExtensionsContainingData = True;
	EndIf;
		
	ExtensionsModificationErrors = New Array;
	ToggleAttachExtensions(False, ExtensionsModificationErrors, ShouldHandleExtensionsContainingData);
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	OutputErrorsInfoOnExtensionsReconfiguration(ExtensionsModificationErrors);
	
EndProcedure

&AtServerNoContext
Procedure SaveExtensionsProperties(ExtensionID, ExtensionProperties)
	InformationRegisters.ExtensionProperties.SaveExtensionsProperties(ExtensionID, ExtensionProperties);
EndProcedure

&AtClientAtServerNoContext
Function ExtensionProperties(CurrentExtension)
	
	Properties = New Structure;
	Properties.Insert("EmployeeResponsible", CurrentExtension.EmployeeResponsible);
	Properties.Insert("Comment", CurrentExtension.Comment);
	
	Return Properties;
	
EndFunction

&AtServer
Procedure UpdateExtensionsPropertiesInList()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Extensions.ExtensionID AS ExtensionID
		|INTO ExtensionsIDs
		|FROM
		|	&ExtensionsList AS Extensions
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ExtensionProperties.EmployeeResponsible AS EmployeeResponsible,
		|	ExtensionProperties.Comment AS Comment,
		|	ExtensionsIDs.ExtensionID AS ExtensionID
		|FROM
		|	ExtensionsIDs AS ExtensionsIDs
		|		INNER JOIN InformationRegister.ExtensionProperties AS ExtensionProperties
		|		ON ExtensionsIDs.ExtensionID = ExtensionProperties.ExtensionID";
	
	Query.SetParameter("ExtensionsList", ExtensionsList.Unload());
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		StructureForSearch = New Structure;
		StructureForSearch.Insert("ExtensionID", Selection.ExtensionID);
		ExtensionsStrings = ExtensionsList.FindRows(StructureForSearch);
		FillPropertyValues(ExtensionsStrings[0], Selection);
		ExtensionsStrings[0].HasComment = ValueIsFilled(ExtensionsStrings[0].Comment);
	EndDo;
	
EndProcedure

&AtClient
Procedure SetTitleToCommentItem()
	
	If Items.ExtensionsList.CurrentData = Undefined Then
		 Return;
	EndIf;
	
	Items.ExtensionsListComment.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Comment for %1';"), Items.ExtensionsList.CurrentData.Synonym);
		
EndProcedure

&AtClient
Procedure SetAssigneeAfterSelection(EmployeeResponsible, AdditionalParameters) Export
	
	If EmployeeResponsible = Undefined Then
		Return;
	EndIf;
	
	SetAssigneeOnSelectedExtensions(EmployeeResponsible);
	
EndProcedure

&AtServer
Procedure SetAssigneeOnSelectedExtensions(EmployeeResponsible)
	
	For Each RowID In Items.ExtensionsList.SelectedRows Do
		ListLine = ExtensionsList.FindByID(RowID);
		If ListLine = Undefined Then
			Continue;
		EndIf;
		ListLine.EmployeeResponsible = EmployeeResponsible;
		SaveExtensionsProperties(ListLine.ExtensionID, ExtensionProperties(ListLine));
	EndDo;
	
EndProcedure

&AtServerNoContext
Function IsInfobaseExclusiveLockError(ErrorText)
	ExclusiveLockErrorText = NStr("en = 'Error setting an exclusive lock';");
	Return (StrFind(ErrorText, ExclusiveLockErrorText) <> 0);
EndFunction

&AtClient
Procedure ToOpenTheFormCompleteTheUserExperience()

	If ExtensionsToReAdd.Count() = 0 Then
		Return;
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.UsersSessions") Then
		Notification = New NotifyDescription("AfterSettingTheExclusiveMode", ThisObject);
		ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");

		FormParameters = ModuleIBConnectionsClient.ExclusiveModeSetErrorFormOpenParameters();
		ItemsToImportCount = ExtensionsToReAdd.Count();
		FormParameters.Title = ?(ItemsToImportCount = 1,
			NStr("en = 'Couldn''t add extension';"), NStr("en = 'Couldn''t add extensions';"));
		FormParameters.ErrorMessageText = ?(ItemsToImportCount = 1, 
			NStr("en = 'Couldn''t add extension: active users detected';"),
			StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t add extensions (%1): active users detected';"), ItemsToImportCount));
		FormParameters.ErrorTextExitFailed = ?(ItemsToImportCount = 1, 
			NStr("en = 'Couldn''t add extensions. Failed to terminate the user sessions:';"),
			StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t add extensions (%1). Failed to terminate the user sessions:';"), ItemsToImportCount));
		FormParameters.LoginMessage = NStr("en = 'Cannot add extensions while the app is being used.';");
		FormParameters.ShouldCloseAllSessionsButCurrent = True;
		FormParameters.ShouldCloseDesignerSession = True;
		FormParameters.BlockingPeriod = 60;
		
		ModuleIBConnectionsClient.OnOpenExclusiveModeSetErrorForm(Notification, FormParameters);
	Else
		StandardSubsystemsClient.OpenActiveUserList();
	EndIf;

EndProcedure

&AtClient
Procedure AfterSettingTheExclusiveMode(Result, AdditionalParameters) Export
	If Result = False Then // The exclusive mode is set.
		ShowTimeConsumingOperation();
		AttachIdleHandler("ReAddExtensionWithData", 0.1, True);
	EndIf;
EndProcedure

&AtClient
Procedure ReAddExtensionWithData()
	
	If ExtensionsToReAdd = Undefined Then
		Return;
	EndIf;
	
	UnattachedExtensions = "";
	ExtensionsChanged = False;
	NameReplacementConfirmation = New Structure("OldName, NewName", "", "");
	ChangeExtensionsAtServer(ExtensionsToReAdd.UnloadValues(), Undefined, UnattachedExtensions,
		ExtensionsChanged, NameReplacementConfirmation);
		
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	If ExtensionsToReAdd.Count() > 0 Then
		ToOpenTheFormCompleteTheUserExperience();
	EndIf;
	
EndProcedure

#EndRegion