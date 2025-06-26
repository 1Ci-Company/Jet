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
	
	FileOwner = Parameters.FileOwner;
	
	CurrentRef = CommonClientServer.StructureProperty(Parameters, "CurrentRow");
	ListOpenedFromFileCard = ValueIsFilled(CurrentRef);
	Items.FileOwner.Visible = ListOpenedFromFileCard And Not Parameters.ShouldHideOwner;
	If ListOpenedFromFileCard And FileOwner = Undefined Then
		FileOwner = Common.ObjectAttributeValue(CurrentRef, "FileOwner");
		Parameters.FileOwner = FileOwner;
	EndIf;
	If Parameters.FileOwner = Undefined Then
		Raise NStr("en = 'You can view the list of attachments
		                             |only in the owner object form.';");
	EndIf;
	
	OwnerType = TypeOf(Parameters.FileOwner);
	If Metadata.DefinedTypes.FilesOwner.Type.ContainsType(OwnerType) Then
		FullOwnerName = Metadata.FindByType(OwnerType).Name;
		If Metadata.Catalogs.Find(FullOwnerName + FilesOperationsInternal.CatalogSuffixAttachedFiles()) = Undefined Then
			IsFilesCatalogItemsOwner = True;
		EndIf;
	EndIf;
	
	LocationInCommandBar = ?(Parameters.SimpleForm, ButtonLocationInCommandBar.InAdditionalSubmenu, 
		ButtonLocationInCommandBar.Auto);
	Items.FormEdit.LocationInCommandBar = LocationInCommandBar;
	Items.FormOpen.LocationInCommandBar = LocationInCommandBar;
	Items.FormEndEdit.LocationInCommandBar = LocationInCommandBar;
	Items.ListImportantAttributes.Visible = Not Parameters.SimpleForm;
	Preview = Parameters.SimpleForm;
	
	ShowSizeColumn = FilesOperationsInternal.ShowSizeColumn();
	If Not ShowSizeColumn Then
		Items.ListSize.Visible = False;
	EndIf;
	
	If Not IsBlankString(Parameters.FormCaption) Then
		Title = Parameters.FormCaption;
	ElsIf ListOpenedFromFileCard Then
		Title = Title + ": " + Common.SubjectString(FileOwner);
	EndIf;
	
	If ValueIsFilled(Parameters.SendOptions) Then
		SendOptions = Parameters.SendOptions;
	Else
		SendOptions = FilesOperationsInternal.PrepareSendingParametersStructure();
	EndIf;
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "SelectionPick");
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		Title = NStr("en = 'Select attachment';");
	Else
		Items.List.ChoiceMode = False;
	EndIf;
	
	FilesSettings = FilesOperationsInternal.FilesSettings();
	
	FilesStorageCatalogName = FilesOperationsInternal.FileStoringCatalogName(Parameters.FileOwner);
	FileCatalogType = Type("CatalogRef." + FilesStorageCatalogName);
	MetadataOfCatalogWithFiles = Metadata.FindByType(FileCatalogType);
	FileVersionsStorageCatalogName = FilesOperationsInternal.FilesVersionsStorageCatalogName(Parameters.FileOwner);
	HaveFileGroups = MetadataOfCatalogWithFiles.Hierarchical;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then 
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		HasRightToUseTemplates = ModuleAccessManagement.HasRight("Read", Catalogs.FilesFolders.Templates);
	Else
		HasRightToUseTemplates = AccessRight("Read", Metadata.Catalogs.Files) And AccessRight("Read", Metadata.Catalogs.FilesFolders)
	EndIf;
	
	If Not HasRightToUseTemplates Or FilesSettings.DontCreateFilesByTemplate.Find(Metadata.FindByType(TypeOf(FileOwner))) <> Undefined Then
		Items.AddFileByTemplate.Visible = False;
		Items.ListContextMenuAddFileByTemplate.Visible = False;
	EndIf;
	
	HaveFileVersions = IsFilesCatalogItemsOwner;
	If TypeOf(Users.AuthorizedUser()) = Type("CatalogRef.ExternalUsers") Then
		FilesOperationsInternal.ChangeFormForExternalUser(ThisObject, True);
	EndIf;
	
	ThereArePropsInternal = FilesOperationsInternal.ThereArePropsInternal(FilesStorageCatalogName);
	SetUpDynamicList();
	NotifyAboutTooManyGroups(MetadataOfCatalogWithFiles);
	
	If Not HaveFileGroups Then
		HideGroupCreationButtons();
	EndIf;
	
	HasRightToAdd = True;
	If Not AccessRight("InteractiveInsert", MetadataOfCatalogWithFiles) Then
		HideAddButtons();
		HasRightToAdd = False;
	EndIf;
	
	FormButtonItemNames = DetermineFormButtonItemNames(); 
	ReadOnly = Not AccessRight("Edit", MetadataOfCatalogWithFiles);
	If ReadOnly Then
		HideChangeButtons();
	EndIf;
	
	OnChangeUseOfSigningOrEncryptionAtServer();
	
	UsePreview1 = Common.CommonSettingsStorageLoad(FileCatalogType, "Preview");
	If UsePreview1 <> Undefined Then
		Preview = UsePreview1;
	EndIf;
	
	Items.FileDataURL.Visible = Preview;
	Items.Preview.Check       = Preview;
	
	PreviewEnabledExtensions = FilesOperationsInternal.ExtensionsListForPreview();
	
	UpdateCloudServiceNote();
	
	Items.SyncSettings.Visible = AccessRight("Edit", Metadata.Catalogs.FileSynchronizationAccounts);
	HasDigitalSignature = Common.SubsystemExists("StandardSubsystems.DigitalSignature");
	Items.PrintWithStamp.Visible = HasDigitalSignature;
	Items.CompareFiles.Visible = Not Common.IsLinuxClient() And Not Common.IsWebClient();
	Items.Send.Visible = Common.SubsystemExists("StandardSubsystems.EmailOperations");
	
	RestrictedExtensions = FilesOperationsInternal.DeniedExtensionsList();
	Items.ShowServiceFiles.Visible = ThereArePropsInternal
		And Users.IsFullUser();
	
	SetConditionalAppearance();
	If ThereArePropsInternal Then
		FilesOperationsInternal.AddFiltersToFilesList(List);
	Else
		FilesOperationsInternal.SetFilterByDeletionMark(List.Filter);
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		PlacementParameters = ModuleAttachableCommands.PlacementParameters();
		Types = New Array;
		Types.Add(FileCatalogType);
		PlacementParameters.Sources = New TypeDescription(Types);
		ModuleAttachableCommands.OnCreateAtServer(ThisObject, PlacementParameters);
	EndIf;
	// End StandardSubsystems.AttachableCommands

	If Common.IsMobileClient() Then
		Items.AddSubmenu.Representation = ButtonRepresentation.Picture;
		Items.AddFileFromScanner.Title = NStr("en = 'From device camera…';");
	EndIf;
	
	FilesOperationsOverridable.OnCreateFilesListForm(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If HasRightToAdd Then
		ScanCommandAvailable = FilesOperationsInternalClient.ScanAvailable();
		Items.AddFileFromScanner.Visible = ScanCommandAvailable;
		Items.ListContextMenuAddFileFromScanner.Visible = ScanCommandAvailable;
	EndIf;
	
	SetFileCommandsAvailability();
	
	If Items.InfoMessage.Visible 
	   And Items.List.Representation = TableRepresentation.List Then
		 Items.InfoMessage.Visible = False;
	EndIf;
	
EndProcedure


&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_ConstantsSet")
		And (Upper(Source) = Upper("UseDigitalSignature")
		Or Upper(Source) = Upper("UseEncryption")) Then
		
		AttachIdleHandler("SigningOrEncryptionUsageOnChange", 0.3, True);
		Return;
	ElsIf EventName = "Write_File" Then
		
		Items.List.Refresh();
		If Not ValueIsFilled(Source)
			Or (TypeOf(Source) = Type("Array")
			And Source.Count() = 0) Then
			Return;
		EndIf;
		
		FileRef = ?(TypeOf(Source) = Type("Array"), Source[0], Source);
		If TypeOf(FileRef) <> FileCatalogType Then
			Return;
		EndIf;
		
		If Parameter.IsNew = True Then
			
			Items.List.CurrentRow = FileRef;
			SetFileCommandsAvailability();
			
		Else
			CurrentData = CurrentData();
			If FileCommandsAvailable() And CurrentData <> Undefined 
				 And FileRef = CurrentData.Ref Then
				SetFileCommandsAvailability();
			EndIf;
		EndIf;
	ElsIf EventName = "Write_FilesFolders" Then
		Items.List.Refresh();
		SetFileCommandsAvailability();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DecorationSyncDateURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If FormattedStringURL = "OpenJournal" Then
		
		StandardProcessing = False;
		FilterParameters = EventLogFilterData(Account);
		EventLogClient.OpenEventLog(FilterParameters, ThisObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Items.List.ChoiceMode Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	CurrentData = CurrentData();
	
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.IsFolder Then
		ShowValue(, RowSelected);
		Return;
	EndIf;
	
	HowToOpen = FilesOperationsInternalClient.PersonalFilesOperationsSettings().ActionOnDoubleClick;
	
	If HowToOpen = "OpenCard" Then
		ShowValue(, RowSelected);
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(RowSelected,
		Undefined, UUID, Undefined, FilePreviousURL);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData", FileData);
	Handler = New NotifyDescription("ListSelectionAfterEditModeChoice", ThisObject, HandlerParameters);
	
	FilesOperationsInternalClient.SelectModeAndEditFile(Handler, FileData, Items.FormEdit.Enabled);
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	UpdateFileCommandAvailability();
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands

EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	
	If Copy Then
		
		If Not FileCommandsAvailable() Then
			Return;
		EndIf;
		
		CurrentData = CurrentData();
		
		FormParameters = New Structure;
		FormParameters = New Structure("CopyingValue", CurrentData);
		
		If CurrentData.IsFolder Then
			OpenForm("DataProcessor.FilesOperations.Form.FilesGroup", FormParameters);
		Else
			FilesOperationsClient.CopyAttachedFile(FileOwner, CurrentData.Ref, FormParameters);
		EndIf;
		
	Else
		
		AppendFile();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	OpenFileCard();
	
EndProcedure

&AtClient
Procedure ListDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	If FilesBeingEditedInCloudService Then
		DragParameters.Action = DragAction.Cancel;
		DragParameters.Value = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	OwnerCatalogFiles = False;
	
	FileNamesArray = New Array;
	If TypeOf(DragParameters.Value) = Type("Array")
		And DragParameters.Value.Count() > 0 Then
		
		FileToDrag = DragParameters.Value[0];
		If TypeOf(FileToDrag) <> Type("File") Then
			
			FilesOwnerMaps = FilesOwnerMaps(Parameters.FileOwner, FileToDrag);
			If HaveFileGroups And TypeOf(FileToDrag) = FileCatalogType
				And FilesOwnerMaps Then
				Return;
			EndIf;
			
		EndIf;
		
		StandardProcessing = False;
		For Each FileToDrag In DragParameters.Value Do
			
			If TypeOf(FileToDrag) = Type("File")
				And FileToDrag.IsFile() Then
				
				FileNamesArray.Add(FileToDrag.FullName);
				OwnerCatalogFiles = True;
			Else
				FileNamesArray.Add(FileToDrag);
			EndIf;
			
		EndDo;
		
	ElsIf TypeOf(DragParameters.Value) = Type("File")
		And DragParameters.Value.IsFile() Then
		
		StandardProcessing = False;
		FileNamesArray.Add(DragParameters.Value.FullName);
		OwnerCatalogFiles = True;
		
	EndIf;
	
	If FileNamesArray.Count() > 0 Then
		If OwnerCatalogFiles = True Then
			FilesOperationsInternalClient.AddFilesWithDrag(
				Parameters.FileOwner, UUID, FileNamesArray);
		Else
			
			Action = ?(DragParameters.Action = DragAction.Copy,
				"Copy", "Move");
			TransferOrCopyAttachedFiles(FileNamesArray, Parameters.FileOwner, Action);
			
			NotifyChanged(Parameters.FileOwner);
			FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters();
			FileWriteNotificationParameters.IsNew = True;
			FileWriteNotificationParameters.Owner = Parameters.FileOwner;
			FileWriteNotificationParameters.FileOwner = FileWriteNotificationParameters.Owner;
			Notify("Write_File", FileWriteNotificationParameters, FileNamesArray);
			
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListOnChange(Item)
	
	NotifyChanged(FileOwner);
	FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters("FileDataChanged");
	Notify("Write_File", FileWriteNotificationParameters, Item.SelectedRows);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

///////////////////////////////////////////////////////////////////////////////////
// File command handlers.

&AtClient
Procedure Add(Command)
	
	AppendFile();
	
EndProcedure

&AtClient
Procedure AddFileByTemplate(Command)
	
	AddingOptions = New Structure;
	AddingOptions.Insert("ResultHandler",          Undefined);
	AddingOptions.Insert("FileOwner",                 FileOwner);
	AddingOptions.Insert("OwnerForm",                 ThisObject);
	AddingOptions.Insert("FilesStorageCatalogName", FilesStorageCatalogName);
	FilesOperationsInternalClient.AddBasedOnTemplate(AddingOptions);
	
EndProcedure

&AtClient
Procedure AddFileFromScanner(Command)
	
	DCParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter("FilesOwner"));
	If DCParameterValue = Undefined Then
		FileOwner = Undefined;
	Else
		FileOwner = DCParameterValue.Value;
	EndIf;
	
	AddingOptions = FilesOperationsClient.AddingFromScannerParameters();
	AddingOptions.FileOwner = FileOwner;
	AddingOptions.OwnerForm = ThisObject;
	AddingOptions.NotOpenCardAfterCreateFromFile = True;
	AddingOptions.IsFile = False;
	FilesOperationsClient.AddFromScanner(AddingOptions);
	
EndProcedure

&AtClient
Procedure OpenFileForViewing(Command)
	
	OpenFile();
	
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	
	If Not FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = CurrentData();
	
	If CurrentData.Encrypted Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	CurrentData = CurrentData();
	FileRef = CurrentData.Ref;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(FileRef,
		Undefined, UUID, Undefined, Undefined);
	FilesOperationsClient.OpenFileDirectory(FileData);

	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	Items.List.Refresh();
	
	AttachIdleHandler("UpdateFileCommandAvailability", 0.1, True);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnHardDrive(Command)
	
	If Not FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = CurrentData();
	If CurrentData.Encrypted Or CurrentData.SignedWithDS Or CurrentData.FileBeingEdited Then
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataAndWorkingDirectory(Items.List.CurrentRow);
	FilesOperationsInternalClient.UpdateFromFileOnHardDriveWithNotification(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	If Not FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = CurrentData();
	
	If CurrentData.Encrypted
		Or (CurrentData.FileBeingEdited And CurrentData.CurrentUserEditsFile) Then
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToSave(CurrentData.Ref, , UUID);
	FilesOperationsInternalClient.SaveAs(Undefined, FileData, Undefined);
	
EndProcedure

&AtClient
Procedure Copy(Command)
	
	Items.List.CopyRow();
	
EndProcedure

&AtClient
Procedure SetDeletionMark(Command)
	
	SelectedRows = SelectedRows();

	If SelectedRows.Count() = 0 Or Not StandardSubsystemsClient.IsDynamicListItem(Items.List) Then
		Return;
	EndIf;
	
	CurrentData = CurrentData();
	If SelectedRows.Count() = 1 Then
		QuestionTemplate = ?(CurrentData.DeletionMark,
			NStr("en = 'Do you want to clear the deletion mark from ""%1""?';"),
			NStr("en = 'Do you want to mark ""%1"" for deletion?';"));
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(QuestionTemplate, CurrentData.Description);
	Else
		QueryText = ?(CurrentData.DeletionMark,
			NStr("en = 'Do you want to clear the deletion mark from the selected files?';"),
			NStr("en = 'Do you want to mark the selected files for deletion?';"));
	EndIf;
	AdditionalParameters = New Structure("Files", SelectedRows);
	Notification = New NotifyDescription("SetDeletionMarkCompletion", ThisObject, AdditionalParameters);
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo);
EndProcedure

&AtClient
Procedure OpenFileProperties(Command)
	
	OpenFileCard();
	
EndProcedure

&AtClient
Procedure Send(Command)
	
	OnSendFilesViaEmail(SendOptions, Items.List.SelectedRows, FileOwner, UUID);
	
	FilesOperationsInternalClient.SendFilesViaEmail(
		Items.List.SelectedRows, UUID, SendOptions);
	
EndProcedure

&AtClient
Procedure Print(Command)
	
	SelectedRows = Items.List.SelectedRows;
	If SelectedRows.Count() > 0 Then
		FilesOperationsClient.PrintFiles(SelectedRows, UUID);
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintWithStamp(Command)
	
	CurrentData = CurrentData();
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FilesOperationsInternalClient.DoPrintFileWithStamp(CurrentData.Ref, UUID);
	
EndProcedure

&AtClient
Procedure Preview(Command)
	
	Preview = Not Preview;
	Items.Preview.Check = Preview;
	SetPreviewVisibility(Preview);
	SavePreviewOption(FileCatalogType, Preview);
	
#If WebClient Then
	UpdatePreview1();
#EndIf
	
EndProcedure

&AtClient
Procedure SyncSettings(Command)
	
	SyncSetup = SynchronizationSettingsParameters(FileOwner);
	
	If ValueIsFilled(SyncSetup.Account) Then
		ValueType = Type("InformationRegisterRecordKey.FileSynchronizationSettings");
		WriteParameters = New Array(1);
		WriteParameters[0] = SyncSetup;
		
		RecordKey = New(ValueType, WriteParameters);
	
		WriteParameters = New Structure;
		WriteParameters.Insert("Key", RecordKey);
	Else
		WriteParameters = SyncSetup;
	EndIf;
	
	OpenForm("InformationRegister.FileSynchronizationSettings.Form.SimpleRecordFormSettings", WriteParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure CreateFolder(Command)
	
	FormParameters = New Structure;
	
	CurrentData = CurrentData();
	If CurrentData <> Undefined And CurrentData.FileOwner <> FileOwner Then
		CurrentData = Undefined;
	EndIf;
	
	If CurrentData <> Undefined Then
		FormParameters.Insert("Parent", CurrentData.Ref);
	Else
		FormParameters.Insert("Parent", FileOwner);
	EndIf;
	
	FormParameters.Insert("FileOwner",  FileOwner);
	FormParameters.Insert("IsNewGroup", True);
	FormParameters.Insert("FilesStorageCatalogName", FilesStorageCatalogName);
	
	OpenForm("DataProcessor.FilesOperations.Form.FilesGroup", FormParameters);
	
EndProcedure

&AtClient
Procedure ImportFiles(Command)
#If WebClient Then
		WarningText =  NStr("en = 'The web client does not support file upload.
		                                  |Please use the ""Create"" button in the file list.';");
		ShowMessageBox(, WarningText);
		Return;
#EndIf
	
	FileNamesArray = FilesOperationsInternalClient.FilesToImport();
	
	If FileNamesArray.Count() = 0 Then
		Return;
	EndIf;
	
	DCParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter("FilesOwner"));
	If DCParameterValue = Undefined Then
		FileOwner = Undefined;
	Else
		FileOwner = DCParameterValue.Value;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("FolderForAdding",            FileOwner);
	FormParameters.Insert("FileNamesArray",              FileNamesArray);
	CurrentData = CurrentData();
	FilesGroup = Undefined;
	If CurrentData <> Undefined And CurrentData.IsFolder Then
		FilesGroup = CurrentData.Ref;
	ElsIf CurrentData <> Undefined And Not IsFilesCatalogItemsOwner Then
		FilesGroup = FileGroup_(CurrentData.Ref);
	EndIf;
	FormParameters.Insert("FilesGroup",                  FilesGroup);
	OpenForm("DataProcessor.FilesOperations.Form.FilesImportForm", FormParameters);
EndProcedure

&AtClient
Procedure ImportFolder(Command)
	
#If WebClient Then
		WarningText = NStr("en = 'The web client does not support folder upload.
			                             |Please use the ""Create"" button in the file list.';");
		ShowMessageBox(, WarningText);
		Return;
#EndIf
	
	OpenFileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	OpenFileDialog.FullFileName = "";
	OpenFileDialog.Filter = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'All files (%1)|%1';"), GetAllFilesMask());
	OpenFileDialog.Multiselect = False;
	OpenFileDialog.Title = NStr("en = 'Select directory';");
	If Not OpenFileDialog.Choose() Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("FolderForAdding",            FileOwner);
	FormParameters.Insert("DirectoryOnHardDrive",                OpenFileDialog.Directory);
	FormParameters.Insert("FilesStorageCatalogName", FilesStorageCatalogName);
	CurrentData = CurrentData();
	FilesGroup = Undefined;
	If CurrentData <> Undefined And CurrentData.IsFolder Then
		FilesGroup = CurrentData.Ref;
	ElsIf CurrentData <> Undefined Then
		FilesGroup = FileGroup_(CurrentData.Ref);
	EndIf;
	FormParameters.Insert("FilesGroup",      FilesGroup);
	
	OpenForm("DataProcessor.FilesOperations.Form.FolderImportForm", FormParameters);
	
EndProcedure

&AtClient
Procedure SaveFolder(Command)
	
	CurrentData = CurrentData();
	
	If CurrentData = Undefined Or Not CurrentData.IsFolder Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ExportFolder",                  CurrentData.Ref);
	FormParameters.Insert("FilesStorageCatalogName",  FilesStorageCatalogName);
	FormParameters.Insert("FileVersionsStorageCatalogName", FileVersionsStorageCatalogName);
	OpenForm("DataProcessor.FilesOperations.Form.ExportFolderForm", FormParameters);
	
EndProcedure

&AtClient
Procedure CompareFiles(Command)
	
	SelectedRowsCount = Items.List.SelectedRows.Count();
	
	If SelectedRowsCount = 2 Then
		
		Ref1 = Items.List.SelectedRows[0];
		Ref2 = Items.List.SelectedRows[1];
		
		CurrentData = CurrentData();
		Extension = Lower(CurrentData.Extension);
		
		FilesOperationsInternalClient.CompareFiles(UUID, Ref1, Ref2, Extension);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MoveToGroupCommand(Command)
	If Items.List.SelectedRows.Count() > 0 Then
		OpeningParameters = New Structure;
		OpeningParameters.Insert("FilesOwner", FileOwner);
		OpeningParameters.Insert("FilesToMove", Items.List.SelectedRows);
		OpenForm("DataProcessor.FilesOperations.Form.SelectGroup", OpeningParameters, ThisObject);
	EndIf;
EndProcedure

&AtClient
Procedure ShowServiceFiles(Command)
	
	Items.ShowServiceFiles.Check = 
		FilesOperationsInternalClient.ShowServiceFilesClick(List);
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////
// Command handlers to support digital signature and encryption.

&AtClient
Procedure Sign(Command)
	
	If Not FileCommandsAvailable() Then
		Return;
	EndIf;
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	NotifyDescription      = New NotifyDescription("AddSignaturesCompeltion", ThisObject);
	AdditionalParameters = New Structure("ResultProcessing", NotifyDescription);
	
	ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
	SigningParameters = ModuleDigitalSignatureClient.NewSignatureType();
	SigningParameters.CanSelectLetterOfAuthority = True;
	
	FilesOperationsClient.SignFile(Items.List.SelectedRows, UUID,
		AdditionalParameters, SigningParameters);
	
EndProcedure

&AtClient
Procedure SaveWithDigitalSignature(Command)
	
	If Not FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = CurrentData();
	
	If CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FilesOperationsInternalClient.SaveFileWithSignature(
		CurrentData.Ref, UUID);
	
EndProcedure

&AtClient
Procedure AddDSFromFile(Command)
	
	If Not FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = CurrentData();
	
	If CurrentData.FileBeingEdited
		Or CurrentData.Encrypted Then
		Return;
	EndIf;
	
	AttachedFile = CurrentData.Ref;
	
	FilesOperationsInternalClient.AddSignatureFromFile(
		AttachedFile,
		UUID,
		New NotifyDescription("AddSignaturesCompeltion", ThisObject));
	
EndProcedure

&AtClient
Procedure Encrypt(Command)
	
	If Not FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = CurrentData();
	
	If CurrentData.FileBeingEdited
		Or CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.GetFileDataAndVersionsCount(CurrentData.Ref);
	
	If ValueIsFilled(FileData.BeingEditedBy)
		Or FileData.Encrypted Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData",  FileData);
	HandlerParameters.Insert("ObjectRef", CurrentData.Ref);
	Handler = New NotifyDescription("EncryptAfterEncryptAtClient", ThisObject, HandlerParameters);
	
	FilesOperationsInternalClient.Encrypt(Handler, FileData, UUID);
	
EndProcedure

&AtClient
Procedure EncryptAfterEncryptAtClient(Result, ExecutionParameters) Export
	If Not Result.Success Then
		Return;
	EndIf;
	
	WorkingDirectoryName = FilesOperationsInternalClient.UserWorkingDirectory();
	
	FilesArrayInWorkingDirectoryToDelete = New Array;
	
	EncryptServer(
		Result.DataArrayToStoreInDatabase,
		Result.ThumbprintsArray,
		FilesArrayInWorkingDirectoryToDelete,
		WorkingDirectoryName,
		ExecutionParameters.ObjectRef);
	
	FilesOperationsInternalClient.InformOfEncryption(
		FilesArrayInWorkingDirectoryToDelete,
		ExecutionParameters.FileData.Owner,
		ExecutionParameters.ObjectRef);
	
	SetFileCommandsAvailability();
	
EndProcedure

&AtServer
Procedure EncryptServer(DataArrayToStoreInDatabase, ThumbprintsArray, 
	FilesArrayInWorkingDirectoryToDelete,
	WorkingDirectoryName, ObjectRef)
	
	EncryptionInformationWriteParameters = FilesOperationsInternal.EncryptionInformationWriteParameters();
	EncryptionInformationWriteParameters.WorkingDirectoryName = WorkingDirectoryName;
	EncryptionInformationWriteParameters.DataArrayToStoreInDatabase = DataArrayToStoreInDatabase;
	EncryptionInformationWriteParameters.ThumbprintsArray = ThumbprintsArray;
	EncryptionInformationWriteParameters.FilesArrayInWorkingDirectoryToDelete = FilesArrayInWorkingDirectoryToDelete;
	
	FilesOperationsInternal.WriteEncryptionInformation(
		ObjectRef, EncryptionInformationWriteParameters);
	
EndProcedure

&AtClient
Procedure Decrypt(Command)
	
	If Not FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = CurrentData();
	
	If Not CurrentData.Encrypted Then
		Return;
	EndIf;
	
	ObjectRef = CurrentData.Ref;
	FileData = FilesOperationsInternalServerCall.GetFileDataAndVersionsCount(ObjectRef);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData", FileData);
	HandlerParameters.Insert("ObjectRef", ObjectRef);
	Handler = New NotifyDescription("DecryptAfterDecryptAtClient", ThisObject, HandlerParameters);
	
	FilesOperationsInternalClient.Decrypt(
		Handler,
		FileData.Ref,
		UUID,
		FileData);
		
EndProcedure

&AtClient
Procedure DecryptAfterDecryptAtClient(Result, ExecutionParameters) Export
	
	If Result = False Or Not Result.Success Then
		Return;
	EndIf;
	
	WorkingDirectoryName = FilesOperationsInternalClient.UserWorkingDirectory();
	
	DecryptServer(
		Result.DataArrayToStoreInDatabase,
		WorkingDirectoryName,
		ExecutionParameters.ObjectRef);
	
	FilesOperationsInternalClient.InformOfDecryption(
		ExecutionParameters.FileData.Owner,
		ExecutionParameters.ObjectRef);
	
	SetFileCommandsAvailability();
	
EndProcedure

&AtServer
Procedure DecryptServer(DataArrayToStoreInDatabase, 
	WorkingDirectoryName, ObjectRef)
	
	EncryptionInformationWriteParameters = FilesOperationsInternal.EncryptionInformationWriteParameters();
	EncryptionInformationWriteParameters.Encrypt = False;
	EncryptionInformationWriteParameters.WorkingDirectoryName = WorkingDirectoryName;
	EncryptionInformationWriteParameters.DataArrayToStoreInDatabase = DataArrayToStoreInDatabase;
	
	FilesOperationsInternal.WriteEncryptionInformation(
		ObjectRef, EncryptionInformationWriteParameters);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////////
// Command handlers to support collaboration in operations with files.

&AtClient
Procedure Edit(Command)
	
	If Not FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = CurrentData();
	
	If (CurrentData.FileBeingEdited And Not CurrentData.CurrentUserEditsFile)
		Or CurrentData.Encrypted
		Or CurrentData.SignedWithDS Then
		Return;
	EndIf;
	
	FilesOperationsInternalClient.EditWithNotification(Undefined, CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	FilesArray = New Array;
	For Each ListItem In Items.List.SelectedRows Do
		
		RowData = ListLineData(ListItem);
		If Not RowData.FileBeingEdited
			Or Not RowData.CurrentUserEditsFile Then
			
			Continue;
		EndIf;
		
		FilesArray.Add(RowData.Ref);
		
	EndDo;
	
	If FilesArray.Count() > 1 Then
		FormParameters = New Structure;
		FormParameters.Insert("FilesArray",                     FilesArray);
		FormParameters.Insert("HaveFileVersions", HaveFileVersions);
		FormParameters.Insert("BeingEditedBy",                      RowData.EditedByUser);
		
		OpenForm("DataProcessor.FilesOperations.Form.FormFinishEditing", FormParameters, ThisObject);
	ElsIf FilesArray.Count() = 1 Then 
		Handler = New NotifyDescription("SetFileCommandsAvailability", ThisObject);
		FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(Handler, RowData.Ref, UUID);
		If Not HaveFileVersions Then
			FileUpdateParameters.Insert("CreateNewVersion", False);
		EndIf;
		FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure Release(Command)
	
	If Not FileCommandsAvailable() Then
		Return;
	EndIf;
	
	FilesOperationsInternalClient.UnlockFiles(Items.List);
	SetFileCommandsAvailability();
	
EndProcedure

&AtClient
Procedure Lock(Command)
	
	If Not FileCommandsAvailable() Then
		Return;
	EndIf;
	
	FilesCount = Items.List.SelectedRows.Count();
	If FilesCount = 1 Then
		Handler = New NotifyDescription("SetFileCommandsAvailability", ThisObject);
		FilesOperationsInternalClient.LockWithNotification(Handler, Items.List.CurrentRow);
	ElsIf FilesCount > 1 Then
		
		FilesArray = New Array;
		For Each ListItem In Items.List.SelectedRows Do
			
			RowData = ListLineData(ListItem);
			If ValueIsFilled(RowData.EditedByUser) Then
				Continue;
			EndIf;
			
			FilesArray.Add(RowData.Ref);
			
		EndDo;
		
		Handler = New NotifyDescription("SetFileCommandsAvailability", ThisObject, FilesArray);
		FilesOperationsInternalClient.LockWithNotification(Handler, FilesArray);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Delete(Command)
	
	SelectedRows = SelectedRows();
	
	NotifyDescription = New NotifyDescription("AfterDeleteData", ThisObject);
	FilesOperationsInternalClient.DeleteFilesData(NotifyDescription, SelectedRows, UUID);

EndProcedure

&AtClient
Procedure ShowMarkedFiles(Command)
	
	FilesOperationsInternalClient.ChangeFilterByDeletionMark(List.Filter, Items.ShowMarkedFiles);
	
EndProcedure

#EndRegion

#Region Private
&AtClient
Procedure AfterDeleteData(Result, AdditionalParameters) Export
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	List.ConditionalAppearance.Items.Clear();
	
	// Appearance of the file that is being edited by another user
	
	Item = List.ConditionalAppearance.Items.Add();
	
	If ThereArePropsInternal Then
		FilterGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		
		ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("AnotherUserEditsFile");
		ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
		ItemFilter.RightValue = True;
		
		ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.Use = True;
		ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
		ItemFilter.LeftValue = New DataCompositionField("IsInternal");
		ItemFilter.RightValue = False;
	Else
		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("AnotherUserEditsFile");
		ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
		ItemFilter.RightValue = True;
	EndIf;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	// Appearance of the file that is being edited by the current user
	
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("CurrentUserEditsFile");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.FileLockedByCurrentUser);
	
	// Hide groups that contain files associated with other owner objects.
	If HaveFileGroups Then
		Item = List.ConditionalAppearance.Items.Add();
		
		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("FileOwner");
		ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
		ItemFilter.RightValue = FileOwner;
		
		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("IsFolder");
		ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
		ItemFilter.RightValue = True;
		
		Item.Appearance.SetParameterValue("Visible", False);
		Item.Appearance.SetParameterValue("Show", False);
	EndIf;
	
	// Service files.
	
	Item = List.ConditionalAppearance.Items.Add();
	Item.Use = True;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	Filter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.Use = True;
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.LeftValue = New DataCompositionField("IsInternal");
	Filter.RightValue = True;

EndProcedure

&AtClient
Procedure AppendFile()
	
	CurrentData = CurrentData();
	FilesGroup = Undefined;
	If CurrentData <> Undefined And CurrentData.IsFolder Then
		FilesGroup = CurrentData.Ref;
	ElsIf CurrentData <> Undefined And Not IsFilesCatalogItemsOwner Then
		FilesGroup = FileGroup_(CurrentData.Ref);
	EndIf;
	If IsFilesCatalogItemsOwner Then
		FilesOperationsInternalClient.AddFileFromFileSystem(Parameters.FileOwner, ThisObject);
	Else
		FilesOperationsClient.AddFiles(Parameters.FileOwner, UUID, , FilesGroup);
	EndIf;

EndProcedure

&AtClient
Procedure OpenFile()
	
	If Not FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = CurrentData();
	
	If CurrentData.Encrypted Then
		Return;
	EndIf;
	
	If RestrictedExtensions.FindByValue(CurrentData.Extension) <> Undefined Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("CurrentData", CurrentData);
		Notification = New NotifyDescription("OpenFileAfterConfirm", ThisObject, AdditionalParameters);
		UsersInternalClient.ShowSecurityWarning(Notification,
			UsersInternalClientServer.SecurityWarningKinds().BeforeOpenFile,
			CommonClientServer.GetNameWithExtension(CurrentData.Description, CurrentData.Extension));
		Return;
	EndIf;
	
	FileBeingEdited = CurrentData.FileBeingEdited And CurrentData.CurrentUserEditsFile;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(CurrentData.Ref, Undefined, UUID);
	If FileData.Encrypted Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	FilesOperationsClient.OpenFile(FileData, FileBeingEdited);
	
EndProcedure

&AtClient
Procedure OpenFileCard()
	
	If Not FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = CurrentData();
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key",              CurrentData.Ref);
	FormParameters.Insert("ReadOnly",    ReadOnly);
	FormParameters.Insert("SendOptions", SendOptions);
	
	If CurrentData.IsFolder Then
		OpenForm("DataProcessor.FilesOperations.Form.FilesGroup", FormParameters);
	Else
		FilesOperationsClient.OpenFileForm(CurrentData.Ref,, FormParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenFileAfterConfirm(Result, AdditionalParameters) Export
	
	If Result <> Undefined And Result = "Continue" Then
		
		CurrentData = AdditionalParameters.CurrentData; // See DataProcessorObject.DuplicateObjectsDetection.DuplicatesGroups
		
		FileBeingEdited = CurrentData.FileBeingEdited And CurrentData.CurrentUserEditsFile;
		
		FileData = FilesOperationsInternalServerCall.FileDataToOpen(CurrentData.Ref, Undefined, UUID);
		If FileData.Encrypted Then
			// The file might be changed in another session
			NotifyChanged(CurrentData.Ref);
			Return;
		EndIf;
		
		FilesOperationsClient.OpenFile(FileData, FileBeingEdited);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListSelectionAfterEditModeChoice(Result, ExecutionParameters) Export
	
	If Result = "Edit" Then
		Handler = New NotifyDescription("SelectionListAfterEditFile", ThisObject, ExecutionParameters);
		FilesOperationsInternalClient.EditFile(Handler, ExecutionParameters.FileData);
	ElsIf Result = "Open" Then
		FilesOperationsClient.OpenFile(ExecutionParameters.FileData, False);
	EndIf;
	
EndProcedure

// Parameters:
//   Result - Undefined
//   ExecutionParameters - Structure:
//     * FileData - See FilesOperations.FileData
//
&AtClient
Procedure SelectionListAfterEditFile(Result, ExecutionParameters) Export
	
	NotifyChanged(ExecutionParameters.FileData.Ref);
	
	SetFileCommandsAvailability();
	
EndProcedure

&AtClient
Function FileCommandsAvailable()
	
	Return FilesOperationsInternalClient.FileCommandsAvailable(Items);
	
EndFunction

&AtServer
Procedure HideGroupCreationButtons()
	Items.CreateFolder.Visible                           = False;
	Items.ListContextMenuCreateFolder.Visible      = False;
	Items.ImportFolder.Visible                          = False;
	Items.SaveFolder.Visible                          = False;
	Items.MoveToGroupCommand.Visible                        = False;
	Items.ListContextMenuMoveToGroup.Visible = False;
EndProcedure

&AtServer
Procedure HideAddButtons()
	
	Items.Add.Visible                           = False;
	Items.AddFromFileOnHardDrive.Visible             = False;
	Items.AddFileByTemplate.Visible              = False;
	Items.AddFileFromScanner.Visible              = False;
	Items.ListContextMenuAdd.Visible      = False;
	Items.ListContextMenuCreateFolder.Visible = False;
	Items.CreateFolder.Visible                      = False;
	Items.ListContextMenuCreateFolder.Visible = False;
	Items.FormCopy.Visible                   = False;
	Items.ListContextMenuCopy.Visible   = False;
	
EndProcedure

&AtServer
Procedure HideChangeButtons()
	
	CommandsNames = ObjectChangeCommandsNames();
	For Each FormItemName In FormButtonItemNames Do
		
		FormItem = Items.Find(FormItemName);
		If CommandsNames[FormItem.CommandName] <> Undefined Then
			FormItem.Visible = False;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Function DetermineFormButtonItemNames()
	
	NamesOfFormCommands = NamesOfFormCommands();
	ItemsNames = New Array;
	
	For Each FormItem In Items Do
		
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		
		If NamesOfFormCommands[FormItem.CommandName] <> Undefined 
			Or NamesOfFormCommands[FormItem.Name] <> Undefined Then
			ItemsNames.Add(FormItem.Name);
		EndIf;
		
	EndDo;
	Return New FixedArray(ItemsNames);
	
EndFunction

&AtClient
Procedure SetFileCommandsAvailability(Result = Undefined, ExecutionParameters = Undefined) Export
	
	CurrentData = CurrentData();
	
	CommandsNames = New Map;
	If CurrentData = Undefined And Not FilesBeingEditedInCloudService Then
		
		CommandsNames.Insert("Add", True);
		CommandsNames.Insert("AddFileFromScanner", True);
		CommandsNames.Insert("AddFileByTemplate", True);
		CommandsNames.Insert("ImportFiles", True);
		CommandsNames.Insert("ImportFolder", True);
		
	ElsIf CurrentData <> Undefined And TypeOf(Items.List.CurrentRow) = FileCatalogType Then
		
		AbilityToUnlockFile = FilesOperationsInternalClient.AbilityToUnlockFile(
			CurrentData.Ref,
			CurrentData.CurrentUserEditsFile,
			CurrentData.EditedByUser);
			
		CommandsNames = AvailableCommands(CurrentData, FilesBeingEditedInCloudService,
			AbilityToUnlockFile, UsersClient.AuthorizedUser());
			
	EndIf;
	
	If CurrentData <> Undefined Then
		Items.PrintWithStamp.Visible = HasDigitalSignature
			And (CurrentData.Extension = "mxl") Or (CurrentData.Extension = "docx")
			And CurrentData.SignedWithDS;
	EndIf;
	
	For Each FormItemName In FormButtonItemNames Do
		
		FormItem = Items.Find(FormItemName);
		If CommandsNames[FormItem.CommandName] = True Or CommandsNames[FormItem.Name] = True Then
			
			If Not FormItem.Enabled Then
				FormItem.Enabled = True;
			EndIf;
			
		ElsIf FormItem.Enabled Then
			FormItem.Enabled = False;
		EndIf;
	EndDo;
	
	AttachIdleHandler("UpdatePreview1", 0.1, True);

EndProcedure

&AtClient
Procedure SetDeletionMarkCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		SetClearDeletionMark(AdditionalParameters.Files);
		FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters("FileDataChanged");
		Notify("Write_File", FileWriteNotificationParameters, Items.List.SelectedRows);
		Items.List.Refresh();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetUpDynamicList()
	
	ListProperties = Common.DynamicListPropertiesStructure();
	
	QueryText = 
	"SELECT
	|	Files.Ref AS Ref,
	|	Files.DeletionMark,
	|	CASE
	|		WHEN Files.DeletionMark = TRUE
	|			THEN ISNULL(Files.PictureIndex, 2) + 1
	|		ELSE ISNULL(Files.PictureIndex, 2)
	|	END AS PictureIndex,
	|	Files.Description AS Description,
	|	CAST(Files.LongDesc AS STRING(500)) AS LongDesc,
	|	Files.Author,
	|	Files.CreationDate,
	|	Files.ChangedBy AS WasEditedBy,
	|	DATEADD(Files.UniversalModificationDate, SECOND, &SecondsToLocalTime) AS ChangeDate,
	|	CAST(Files.Size / 1024 AS NUMBER(10, 0)) AS Size,
	|	Files.SignedWithDS,
	|	Files.Encrypted,
	|	CASE
	|		WHEN Files.SignedWithDS
	|				AND Files.Encrypted
	|			THEN 2
	|		WHEN Files.Encrypted
	|			THEN 1
	|		WHEN Files.SignedWithDS
	|			THEN 0
	|		ELSE -1
	|	END AS SignedEncryptedPictureNumber,
	|	CASE
	|		WHEN NOT Files.BeingEditedBy IN (&EmptyUsers)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FileBeingEdited,
	|	CASE
	|		WHEN Files.BeingEditedBy = &CurrentUser
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS CurrentUserEditsFile,
	|	CASE
	|		WHEN NOT Files.BeingEditedBy IN (&EmptyUsers)
	|				AND Files.BeingEditedBy <> &CurrentUser
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AnotherUserEditsFile,
	|	Files.Extension AS Extension,
	|	CASE
	|		WHEN FilesSynchronizationWithCloudServiceStatuses.Account <> UNDEFINED
	|				AND Files.BeingEditedBy = UNDEFINED
	|			THEN FilesSynchronizationWithCloudServiceStatuses.Account
	|		ELSE Files.BeingEditedBy
	|	END AS BeingEditedBy,
	|	Files.BeingEditedBy AS EditedByUser,
	|	&IsFolder AS IsFolder,
	|	&IsInternal AS IsInternal,
	|	&FileGroup_ AS FileGroup_,
	|	Files.FileOwner AS FileOwner,
	|	Files.StoreVersions AS StoreVersions
	|FROM
	|	&CatalogName AS Files
	|		LEFT JOIN InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
	|		ON Files.Ref = FilesSynchronizationWithCloudServiceStatuses.File
	|WHERE
	|	Files.FileOwner = &FilesOwner";
	
	FullCatalogName = "Catalog." + FilesStorageCatalogName;
	QueryText = StrReplace(QueryText, "&CatalogName", FullCatalogName);
	QueryText = StrReplace(QueryText, "&IsInternal", ?(ThereArePropsInternal, "Files.IsInternal", "FALSE"));
	QueryText = StrReplace(QueryText, "&FileGroup_", ?(HaveFileGroups, "Files.Parent", "UNDEFINED"));
	
	
	ListProperties.QueryText = StrReplace(QueryText, "&IsFolder",
		?(HaveFileGroups, "Files.IsFolder", "FALSE"));
		
	ListProperties.MainTable  = FullCatalogName;
	ListProperties.DynamicDataRead = True;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	
	EmptyUsers = New Array;
	EmptyUsers.Add(Undefined);
	EmptyUsers.Add(Catalogs.Users.EmptyRef());
	EmptyUsers.Add(Catalogs.ExternalUsers.EmptyRef());
	EmptyUsers.Add(Catalogs.FileSynchronizationAccounts.EmptyRef());
	
	List.Parameters.SetParameterValue("FilesOwner",      Parameters.FileOwner);
	List.Parameters.SetParameterValue("CurrentUser", Users.AuthorizedUser());
	List.Parameters.SetParameterValue("EmptyUsers",  EmptyUsers);
	
	UniversalDate = CurrentSessionDate();
	List.Parameters.SetParameterValue("SecondsToLocalTime",
		ToLocalTime(UniversalDate, SessionTimeZone()) - UniversalDate);
	
EndProcedure

&AtServer
Procedure NotifyAboutTooManyGroups(MetadataOfCatalogWithFiles) 
	
	MinGroupQtyToOutputMessage = 5000;
	
	If Not MetadataOfCatalogWithFiles.Hierarchical Or Items.List.Representation = TableRepresentation.List Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	QueryText = 
		"SELECT 
		|	COUNT(CatalogAttachedFiles.IsFolder) AS GroupCount
		|FROM
		|	#CatalogAttachedFiles AS CatalogAttachedFiles
		|WHERE
		|	CatalogAttachedFiles.IsFolder = TRUE";
	
	QueryText = StrReplace(QueryText, "#CatalogAttachedFiles", MetadataOfCatalogWithFiles.FullName());
	
	Query = New Query(QueryText);
	
	SelectionDetailRecords = Query.Execute().Select();
	
	If SelectionDetailRecords.Next() Then
		If SelectionDetailRecords.GroupCount >= MinGroupQtyToOutputMessage Then
			Items.InfoMessage.Visible = True;
		EndIf;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function NamesOfFormCommands()
	
	Result = ObjectChangeCommandsNames();

	// Commands that are available to any user reading the files.
	Result.Insert("OpenFileDirectory", True);
	Result.Insert("OpenFileForViewing", True);
	Result.Insert("SaveAs", True);
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function ObjectChangeCommandsNames()
	
	Result = New Map;
	
	// Commands that depend on object states.
	Result.Insert("EndEdit", True);
	Result.Insert("Lock", True);
	Result.Insert("Release", True);
	Result.Insert("Edit", True);
	Result.Insert("SetDeletionMark", True);
	Result.Insert("Delete", True);
	Result.Insert("ContextMenuMarkForDeletion", True);
	
	Result.Insert("Sign", True);
	Result.Insert("AddDSFromFile", True);
	Result.Insert("SaveWithDigitalSignature", True);
	
	Result.Insert("Encrypt", True);
	Result.Insert("Decrypt", True);
	
	Result.Insert("Print", True);
	Result.Insert("PrintWithStamp", True);
	
	Result.Insert("Send", True);
	
	Result.Insert("UpdateFromFileOnHardDrive", True);
	
	// Commands that do not depend on object states.
	Result.Insert("Add", True);
	Result.Insert("AddFromFileOnHardDrive", True);
	Result.Insert("AddFileByTemplate", True);
	Result.Insert("AddFileFromScanner", True);
	Result.Insert("OpenFileProperties", True);
	Result.Insert("Copy", True);
	Result.Insert("ImportFiles", True);
	Result.Insert("ImportFolder", True);
	
	Result.Insert("MoveToGroup", True);
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function AvailableCommands(CurrentFileData, FilesBeingEditedInCloudService, AbilityToUnlockFile, 
	AuthorizedUser)
	
	CommandsNames = NamesOfFormCommands();
	
	CurrentUserEditsFile = CurrentFileData.CurrentUserEditsFile;
	CurrentUserIsAuthor           = CurrentFileData.Author = AuthorizedUser;
	FileBeingEdited                  = CurrentFileData.FileBeingEdited;
	FileSigned                       = CurrentFileData.SignedWithDS;
	FileEncrypted                     = CurrentFileData.Encrypted;
	
	If FileBeingEdited Then
		
		If CurrentUserEditsFile Then
			CommandsNames["UpdateFromFileOnHardDrive"] = False;
		Else
			CommandsNames["EndEdit"] = False;
			If Not AbilityToUnlockFile Then
				CommandsNames["Release"] = False;
			EndIf;
			CommandsNames["Edit"] = False;
		EndIf;
		
		CommandsNames["Lock"] = False;
		CommandsNames["SetDeletionMark"] = False;
		CommandsNames["ContextMenuMarkForDeletion"] = False;

		CommandsNames["Sign"] = False;
		CommandsNames["AddDSFromFile"] = False;
		CommandsNames["SaveWithDigitalSignature"] = False;
		
		CommandsNames["UpdateFromFileOnHardDrive"] = False;
		CommandsNames["SaveAs"] = False;
		
		CommandsNames["Encrypt"] = False;
		CommandsNames["Decrypt"] = False;
		
		CommandsNames["Delete"] = False;
		
	Else
		CommandsNames["EndEdit"] = False;
		CommandsNames["Release"] = False;
	EndIf;
	
	If CurrentFileData.IsFolder Then
		CommandsNames["Edit"] = False;
		CommandsNames["Sign"] = False;
		CommandsNames["AddDSFromFile"] = False;
		CommandsNames["SaveWithDigitalSignature"] = False;
		CommandsNames["Encrypt"] = False;
		CommandsNames["Decrypt"] = False;
		CommandsNames["UpdateFromFileOnHardDrive"] = False;
		CommandsNames["Copy"] = False;
		CommandsNames["OpenFileDirectory"] = False;
		CommandsNames["OpenFileForViewing"] = False;
		CommandsNames["SaveAs"] = False;
		CommandsNames["Lock"] = False;
		CommandsNames["Send"] = False;
		CommandsNames["PrintWithStamp"] = False;
		CommandsNames["Print"] = False;
		CommandsNames["Delete"] = False;
	EndIf;
	
	If FileSigned Then
		CommandsNames["EndEdit"] = False;
		CommandsNames["Release"] = False;
		CommandsNames["Edit"] = False;
		CommandsNames["UpdateFromFileOnHardDrive"] = False;
		CommandsNames["Lock"] = False;
	EndIf;
	
	If FileEncrypted Then
		CommandsNames["Sign"] = False;
		CommandsNames["AddDSFromFile"] = False;
		CommandsNames["SaveWithDigitalSignature"] = False;
		
		CommandsNames["EndEdit"] = False;
		CommandsNames["Release"] = False;
		CommandsNames["Edit"] = False;
		CommandsNames["Lock"] = False;
		
		CommandsNames["UpdateFromFileOnHardDrive"] = False;
		
		CommandsNames["Encrypt"] = False;
		
		CommandsNames["OpenFileDirectory"] = False;
		CommandsNames["OpenFileForViewing"] = False;
		CommandsNames["SaveAs"] = False;
	Else
		CommandsNames["Decrypt"] = False;
	EndIf;
	
	If FilesBeingEditedInCloudService Then
		
		CommandsNames["Add"] = False;
		CommandsNames["AddFromFileOnHardDrive"] = False;
		CommandsNames["AddFileByTemplate"] = False;
		CommandsNames["AddFileFromScanner"] = False;
		CommandsNames["Copy"] = False;
		
		CommandsNames["CreateFolder"] = False;
		CommandsNames["MoveToGroup"] = False;
		CommandsNames["SetDeletionMark"] = False;
		CommandsNames["ContextMenuMarkForDeletion"] = False;
		CommandsNames["Lock"] = False;
		CommandsNames["Release"] = False;
		
		CommandsNames["ImportFiles"] = False;
		CommandsNames["ImportFolder"] = False;
		
		CommandsNames["Delete"] = False;
		
		CommandsNames["Sign"] = False;
		CommandsNames["AddDSFromFile"] = False;
		CommandsNames["Encrypt"] = False;
		CommandsNames["Decrypt"] = False;
		
	EndIf;
	
	If Not CurrentUserIsAuthor Then
		CommandsNames["Delete"] = False;
	EndIf;
	
	Return CommandsNames;
	
EndFunction

&AtClient
Procedure SigningOrEncryptionUsageOnChange()
	
	OnChangeUseOfSigningOrEncryptionAtServer();
	
EndProcedure

&AtServer
Procedure OnChangeUseOfSigningOrEncryptionAtServer()
	
	FilesOperationsInternal.CryptographyOnCreateFormAtServer(ThisObject);
	
EndProcedure

// Continues Sign and AddDSFromFile procedures execution.
&AtClient
Procedure AddSignaturesCompeltion(Success, Context) Export
	
	If Success = True Then
		SetFileCommandsAvailability();
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SavePreviewOption(FileCatalogType, Preview)
	Common.CommonSettingsStorageSave(FileCatalogType, "Preview", Preview);
EndProcedure

&AtServerNoContext
Procedure OnSendFilesViaEmail(SendOptions, Val FilesToSend, FilesOwner, UUID)
	SSLSubsystemsIntegration.OnSendFilesViaEmail(SendOptions, FilesToSend, FilesOwner, UUID);
	FilesOperationsOverridable.OnSendFilesViaEmail(SendOptions, FilesToSend, FilesOwner, UUID);
EndProcedure

&AtServerNoContext
Procedure SetClearDeletionMark(Files)
	DeletionMark = Undefined;
	For Each FileRef In Files Do
		BeginTransaction();
		Try
			Block = New DataLock();
			LockItem = Block.Add(FileRef.Metadata().FullName());
			LockItem.SetValue("Ref", FileRef);
			Block.Lock();

			FileObject1 = FileRef.GetObject();
			If DeletionMark = Undefined Then
				DeletionMark = Not FileObject1.DeletionMark;
			EndIf;
			FileObject1.SetDeletionMark(DeletionMark);

			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
EndProcedure

&AtClient
Procedure SetPreviewVisibility(UsePreview1)
	
	Items.FileDataURL.Visible = UsePreview1;
	Items.Preview.Check = UsePreview1;

EndProcedure

&AtClient
Procedure UpdatePreview1()
	
	If Not Preview Then
		Return;
	EndIf;
	
	CurrentData = CurrentData();
	If CurrentData <> Undefined And PreviewEnabledExtensions.FindByValue(CurrentData.Extension) <> Undefined Then
		
		Try
			FileData = FilesOperationsInternalServerCall.FileDataToOpen(CurrentData.Ref, Undefined, UUID,, FileDataURL);
			FileDataURL = FileData.RefToBinaryFileData;
		Except
			// If the file does not exist, an exception will be called.
			FileDataURL         = Undefined;
			NonselectedPictureText = NStr("en = 'Preview is not available. Reason:';") + Chars.LF + ErrorProcessing.BriefErrorDescription(ErrorInfo());
		EndTry;
		
	Else
		
		FileDataURL         = Undefined;
		NonselectedPictureText = NStr("en = 'No data to preview';");
		
	EndIf;
	
	If Not ValueIsFilled(FileDataURL) Then
		Items.FileDataURL.NonselectedPictureText = NonselectedPictureText;
	EndIf;

EndProcedure

&AtServer
Procedure UpdateCloudServiceNote()
	
	NoteVisibility = False;
	
	If GetFunctionalOption("UseFileSync") Then
		
		SynchronizationInfo = FilesOperationsInternal.SynchronizationInfo(FileOwner);
		
		If SynchronizationInfo.Count() > 0  Then
			
			FilesBeingEditedInCloudService = True;
			Account = SynchronizationInfo.Account;
			NoteVisibility = True;
			
			FolderAddressInCloudService = FilesOperationsInternalClientServer.AddressInCloudService(
				SynchronizationInfo.Service, SynchronizationInfo.Href);
				
			Items.DecorationNote.Title = StringFunctions.FormattedString(
				NStr("en = 'The files are stored in cloud service <a href=""%1"">%2</a>.';"),
				String(FolderAddressInCloudService), String(SynchronizationInfo.AccountDescription1));
			
			Items.DecorationPictureSyncStatus.Visible = Not SynchronizationInfo.IsSynchronized;
			Items.DecorationSyncDate.ToolTipRepresentation =?(SynchronizationInfo.IsSynchronized, ToolTipRepresentation.None, ToolTipRepresentation.Button);
			
			Items.DecorationSyncDate.Title = StringFunctions.FormattedString(
				NStr("en = 'Synchronized on: <a href=""%1"">%2</a>';"),
				"OpenJournal", Format(SynchronizationInfo.SynchronizationDate, "DLF=DD"));
			
		EndIf;
		
	EndIf;
	
	Items.CloudServiceNoteGroup.Visible = NoteVisibility;
	
EndProcedure

&AtServerNoContext
Function EventLogFilterData(Service)
	Return FilesOperationsInternal.EventLogFilterData(Service);
EndFunction

&AtServer
Function SynchronizationSettingsParameters(Val FileOwner)
	
	FileOwnerType = Common.MetadataObjectID(FileCatalogType);
	
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

&AtClient
Procedure UpdateFileCommandAvailability()
	
	SetFileCommandsAvailability();
	
EndProcedure

&AtServerNoContext
Function FilesOwnerMaps(FilesOwner, FileToDrag)
	
	Return FilesOwner = Common.ObjectAttributeValue(FileToDrag, "FileOwner");
	
EndFunction

&AtServerNoContext
Procedure TransferOrCopyAttachedFiles(Val FileNamesArray, Val FileOwner, Val Action)
	
	FileToDragOwner = Common.ObjectAttributeValue(FileNamesArray[0], "FileOwner");
	If TypeOf(FileToDragOwner) <> TypeOf(FileOwner) Then
		Return;
	EndIf;
	
	If Action = "Move" Then
		FilesOperationsInternalServerCall.MoveFiles(FileNamesArray, FileOwner);
	ElsIf Action = "Copy" Then
		FilesOperationsInternalServerCall.DoCopyAttachedFiles(FileNamesArray, FileOwner);
	EndIf;

EndProcedure

// Returns:
//   FormDataStructure:
//     * Ref - CatalogRef
//   CollectionItemFormData:
//     * Ref - CatalogRef
//
&AtClient
Function ListLineData(ListItem)
	
	Return Items.List.RowData(ListItem);
	
EndFunction

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
	ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Items.List);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
	ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Items.List);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
	ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure

// End StandardSubsystems.AttachableCommands

&AtClient
Function CurrentData()
	If Not StandardSubsystemsClient.IsDynamicListItem(Items.List) Then
		Return Undefined;
	ElsIf Items.List.CurrentData.FileOwner = FileOwner Then
		Return Items.List.CurrentData;
	Else
		Return Undefined;
	EndIf;
EndFunction

&AtServerNoContext
Function FileGroup_(File)
	If File.Metadata().Hierarchical Then
		Return Common.ObjectAttributeValue(File, "Parent");
	Else
		Return Undefined;
	EndIf;
EndFunction

&AtClient
Function SelectedRows()
	SelectedRows = New Array;
	
	For Each SelectedRow In Items.List.SelectedRows Do
		If TypeOf(SelectedRow) <> Type("DynamicListGroupRow") Then
			SelectedRows.Add(SelectedRow);
		EndIf;
	EndDo;
	
	Return SelectedRows
	
EndFunction

#EndRegion
