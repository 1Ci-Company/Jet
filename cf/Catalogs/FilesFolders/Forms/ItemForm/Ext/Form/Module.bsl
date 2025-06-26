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
	
	If ValueIsFilled(Parameters.Parent) Then
		Object.Parent = Parameters.Parent;
	EndIf;
	
	UpdateCommandsAvailabilityByRightsSetting();
	
	WorkingDirectory = FilesOperationsInternalServerCall.FolderWorkingDirectory(Object.Ref);
	
	If Object.Ref = PredefinedValue("Catalog.FilesFolders.Templates") Then
		Items.Parent.Visible = False;
	EndIf;
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	RefreshFullPath();
	
	UpdateCloudServiceNote();
	Items.FormSyncSettings.Visible = AccessRight("Edit", Metadata.Catalogs.FileSynchronizationAccounts);
	Items.EmployeeResponsible.Visible = TypeOf(Users.AuthorizedUser()) <> Type("CatalogRef.ExternalUsers");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		If ModulePropertyManagerClient.ProcessNotifications(ThisObject, EventName, Parameter) Then
			UpdateAdditionalAttributesItems();
			ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
		EndIf;
	EndIf;
	// End StandardSubsystems.Properties
	
	If EventName = "Write_ObjectsRightsSettings" Then
		UpdateCommandsAvailabilityByRightsSetting();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	
	CurrentObject.AdditionalProperties.Insert("WorkingDirectory", WorkingDirectory);
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	WorkingDirectory = FilesOperationsInternalServerCall.FolderWorkingDirectory(Object.Ref);
	
	UpdateCommandsAvailabilityByRightsSetting();
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ParentOnChange(Item)
	
	RefreshFullPath();
	
EndProcedure

&AtClient
Procedure OwnerWorkingDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	Handler           = New NotifyDescription("FileSystemExtensionAttachedOwnerWorkingDirectorySelectionStartFollowUp", ThisObject);
	FilesOperationsInternalClient.ShowFileSystemExtensionInstallationQuestion(Handler);
	
EndProcedure

&AtClient
Procedure OwnerWorkingDirectoryClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkingDirectory = OwnerWorkingDirectoryClearingAtServer(Object.Ref, Object.Parent, Object.Description);
	Modified = True;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SyncSettings(Command)
	
	SyncSetup = SynchronizationSettingsParameters(Object.Ref);
	
	If ValueIsFilled(SyncSetup.Account) Then
		ValueType = Type("InformationRegisterRecordKey.FileSynchronizationSettings");
		WriteParameters = New Array(1);
		WriteParameters[0] = SyncSetup;
		
		RecordKey = New(ValueType, WriteParameters);
	
		WriteParameters = New Structure;
		WriteParameters.Insert("Key", RecordKey);
	Else
		SyncSetup.Insert("IsFile", True);
		WriteParameters = SyncSetup;
	EndIf;
	
	OpenForm("InformationRegister.FileSynchronizationSettings.Form.SimpleRecordFormSettings", WriteParameters, ThisObject);
	
EndProcedure

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, Var_URL = Undefined, StandardProcessing = Undefined)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#Region Private

&AtClient
Procedure FileSystemExtensionAttachedOwnerWorkingDirectorySelectionStartFollowUp(Result, AdditionalParameters) Export
	
	If Not FilesOperationsInternalClient.FileSystemExtensionAttached1() Then
		FilesOperationsInternalClient.ShowFileSystemExtensionRequiredMessageBox(Undefined);
		Return;
	EndIf;
	
	ClearMessages();
	
	Mode = FileDialogMode.ChooseDirectory;
	
	OpenFileDialog = New FileDialog(Mode);
	OpenFileDialog.Directory = WorkingDirectory;
	OpenFileDialog.FullFileName = "";
	Filter = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'All files (%1)|%1';"), GetAllFilesMask());
	OpenFileDialog.Filter = Filter;
	OpenFileDialog.Multiselect = False;
	OpenFileDialog.Title = NStr("en = 'Select folder';");
	If OpenFileDialog.Choose() Then
		
		DirectoryName = OpenFileDialog.Directory;
		DirectoryName = CommonClientServer.AddLastPathSeparator(DirectoryName);
		
		// Create a directory for files
		Try
			CreateDirectory(DirectoryName);
			TestDirectoryName = DirectoryName + "CheckAccess\";
			CreateDirectory(TestDirectoryName);
			DeleteFiles(TestDirectoryName);
		Except
			// Insufficient rights to create a directory, or this path does not exist.
			
			ErrorText =
				StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Invalid path or insufficient rights to save to folder ""%1""';"), DirectoryName);
			
			CommonClient.MessageToUser(ErrorText, , "WorkingDirectory");
			Return;
		EndTry;
		
		WorkingDirectory = DirectoryName;
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshFullPath()
	
	FolderParent = Common.ObjectAttributeValue(Object.Ref, "Parent");
	
	If ValueIsFilled(FolderParent) Then
	
		FullPath = "";
		While ValueIsFilled(FolderParent) Do
			
			FullPath = String(FolderParent) + "\" + FullPath;
			FolderParent = Common.ObjectAttributeValue(FolderParent, "Parent");
			If Not ValueIsFilled(FolderParent) Then
				Break;
			EndIf;
			
		EndDo;
		
		FullPath = FullPath + String(Object.Ref);
		
		If Not IsBlankString(FullPath) Then
			FullPath = """" + FullPath + """";
		EndIf;
	
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateCommandsAvailabilityByRightsSetting()
	
	If Not Common.SubsystemExists("StandardSubsystems.AccessManagement")
	 Or Items.Find("FormCommonCommandSetRights") = Undefined Then
		Return;
	EndIf;
	
	ModuleAccessManagement = Common.CommonModule("AccessManagement");
	
	If ValueIsFilled(Object.Ref)
	   And Not ModuleAccessManagement.HasRight("FoldersModification", Object.Ref) Then
		
		ReadOnly = True;
	EndIf;
	
	RightsManagement = ValueIsFilled(Object.Ref)
		And ModuleAccessManagement.HasRight("RightsManagement", Object.Ref);
		
	If Items.FormCommonCommandSetRights.Visible <> RightsManagement Then
		Items.FormCommonCommandSetRights.Visible = RightsManagement;
	EndIf;
	
EndProcedure

// StandardSubsystems.Properties

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.UpdateAdditionalAttributesItems(ThisObject);
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

// End StandardSubsystems.Properties

&AtServer
Function SynchronizationSettingsParameters(Val FileOwner)
	
	FileOwnerType = Common.MetadataObjectID(Type("CatalogRef.Files"));
	
	Filter = New Structure(
	"FileOwner, FileOwnerType, Account",
		FileOwner,
		FileOwnerType,
		Catalogs.FileSynchronizationAccounts.EmptyRef());
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileSynchronizationSettings.FileOwner,
		|	FileSynchronizationSettings.FileOwnerType,
		|	FileSynchronizationSettings.Account
		|FROM
		|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
		|WHERE
		|	FileSynchronizationSettings.FileOwner = &FileOwner
		|	AND FileSynchronizationSettings.FileOwnerType = &FileOwnerType";
	
	Query.SetParameter("FileOwner", FileOwner);
	Query.SetParameter("FileOwnerType", FileOwnerType);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Count() = 1 Then
		While SelectionDetailRecords.Next() Do
			Filter.Account = SelectionDetailRecords.Account;
		EndDo;
	EndIf;
	
	Return Filter;
	
EndFunction

&AtServer
Procedure UpdateCloudServiceNote()
	
	NoteVisibility = False;
	
	If GetFunctionalOption("UseFileSync") Then
	
		Query = New Query;
		Query.Text = 
			"SELECT TOP 1
			|	FilesSynchronizationWithCloudServiceStatuses.File,
			|	FilesSynchronizationWithCloudServiceStatuses.Href,
			|	FilesSynchronizationWithCloudServiceStatuses.Account.Description,
			|	FilesSynchronizationWithCloudServiceStatuses.Account.Service AS Service
			|FROM
			|	InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
			|WHERE
			|	FilesSynchronizationWithCloudServiceStatuses.File = &FileOwner";
		
		Query.SetParameter("FileOwner", Object.Ref);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		While SelectionDetailRecords.Next() Do
			
			FolderAddressInCloudService = FilesOperationsInternalClientServer.AddressInCloudService(
				SelectionDetailRecords.Service, SelectionDetailRecords.Href);
			
			NoteVisibility = True;
			
			Items.DecorationNote.Title = StringFunctions.FormattedString(
				NStr("en = 'The files are stored in cloud service <a href=""%1"">%2</a>.';"),
				String(FolderAddressInCloudService), String(SelectionDetailRecords.AccountDescription));
			
		EndDo;
		
	EndIf;
	
	Items.CloudServiceNoteGroup.Visible = NoteVisibility;
	
EndProcedure

&AtServerNoContext
Function OwnerWorkingDirectoryClearingAtServer(Val Ref, Val ParentReference, Val Description)
	
	ParentWorkingDirectory = FilesOperationsInternalServerCall.FolderWorkingDirectory(ParentReference);
	
	InheritedFolderWorkingDirectory = ParentWorkingDirectory
		+ Description + GetPathSeparator();
	
	If IsBlankString(ParentWorkingDirectory) Then
		
		WorkingDirectory = ""; // Folder's new working directory.
		
	Else
		
		WorkingDirectory = InheritedFolderWorkingDirectory; // Folder's new working directory.
		
	EndIf;
	
	Return WorkingDirectory;
	
EndFunction

#EndRegion
