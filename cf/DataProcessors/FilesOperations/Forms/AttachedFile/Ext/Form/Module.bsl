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
	
	OwnerType  = TypeOf(Parameters.FileOwner);
	
	If ValueIsFilled(Parameters.AttachedFile) Then
		AttachedFile = Parameters.AttachedFile;
	Else
		AttachedFile = Parameters.Key;
	EndIf;
	
	CurrentUser = Users.AuthorizedUser();
	FilesModification = Users.IsFullUser();
	SendOptions = ?(ValueIsFilled(Parameters.SendOptions),
		Parameters.SendOptions, FilesOperationsInternal.PrepareSendingParametersStructure());
	
	FilesOperationsInternal.ItemFormOnCreateAtServer(
		ThisObject, Cancel, StandardProcessing, Parameters, ReadOnly, True);
	
	Items.FileOwner0.Title = OwnerType;
	SetButtonsAvailability(ThisObject, Items);
	RestrictedExtensions = FilesOperationsInternal.DeniedExtensionsList();
	RefreshTitle();
	UpdateCloudServiceNote(AttachedFile);

	AttachedFileObject = FormAttributeToValue("Object"); // DefinedType.AttachedFileObject
	DigitalSignatureAvailable = FilesOperationsInternal.DigitalSignatureAvailable(TypeOf(AttachedFileObject));
	SetTheVisibilityOfTheFormCommands();
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		PlacementParameters = ModuleAttachableCommands.PlacementParameters();
		Types = New Array;
		Types.Add(TypeOf(AttachedFileObject.Ref));
		PlacementParameters.Sources = New TypeDescription(Types);
		PlacementParameters.CommandBar = Items.CommandBar;
		ModuleAttachableCommands.OnCreateAtServer(ThisObject, PlacementParameters);
	EndIf;
	// End StandardSubsystems.AttachableCommands

	If Common.IsMobileClient() Then
		Items["LongDesc"].Height = 0;
		Items["Description"].TitleLocation = FormItemTitleLocation.Top;
		Items["FileOwner"].TitleLocation = FormItemTitleLocation.Top;
		Items.InfoGroupPart1.ItemsAndTitlesAlign =
			ItemsAndTitlesAlignVariant.ItemsRightTitlesLeft;
		Items.InfoGroupPart2.ItemsAndTitlesAlign =
			ItemsAndTitlesAlignVariant.ItemsRightTitlesLeft;
		Items.FileCharacteristicsGroup.ItemsAndTitlesAlign =
			ItemsAndTitlesAlignVariant.ItemsRightTitlesLeft;
	EndIf;
	
	SSLSubsystemsIntegration.OnCreateFilesItemForm(ThisObject);
	FilesOperationsOverridable.OnCreateFilesItemForm(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	DescriptionBeforeWrite = CurrentFileDescription();
	
	SetAvaliabilityOfDSCommandsList();
	SetAvaliabilityOfEncryptionList();
	
	FilesOperationsInternalClient.ReadSignaturesCertificates(ThisObject);
	DisplayAdditionalDataTabs();
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands

EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	UnlockObject(CurrentRefToFile(), UUID);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_ConstantsSet") And (Upper(Source) = Upper("UseDigitalSignature")
		Or Upper(Source) = Upper("UseEncryption")) Then
		
		AttachIdleHandler("OnChangeSigningOrEncryptionUsage", 0.3, True);
	EndIf;
	
	If EventName = "Write_File"
		And Source = CurrentRefToFile()
		And (Parameter.Event = "EditFinished"
		Or Parameter.Event = "EditCanceled") Then
		
		UpdateObject();
	EndIf;
	
	
	If EventName = "Write_Signature" Then
		OnGetSignatures(Undefined, Undefined);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DecorationSyncDateURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If FormattedStringURL = "OpenJournal" Then
		
		StandardProcessing = False;
		FilterParameters      = EventLogFilterData(Account);
		EventLogClient.OpenEventLog(FilterParameters, ThisObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersDigitalSignatures

&AtClient
Procedure DigitalSignaturesSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.OpenSignature(Items.DigitalSignatures.CurrentData);
	
EndProcedure

&AtClient
Procedure InstructionClick(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
		ModuleDigitalSignatureClient.OpenInstructionOnTypicalProblemsOnWorkWithApplications();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersEncryptionCertificates

&AtClient
Procedure EncryptionCertificatesSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenEncryptionCertificate(Undefined);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

///////////////////////////////////////////////////////////////////////////////////
// File command handlers.

&AtClient
Procedure ShowInList(Command)
	
	StandardSubsystemsClient.ShowInList(CurrentRefToFile(), Undefined);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnHardDrive(Command)
	
	If IsNew()
		Or ThisObject.Object.Encrypted
		Or ThisObject.Object.SignedWithDS
		Or ValueIsFilled(ThisObject.Object.BeingEditedBy) Then
		
		Return;
	EndIf;
	
	FileData = FileData(CurrentRefToFile(), UUID, "ServerCall");
	Handler = New NotifyDescription("UpdateFromFileOnHardDriveCompletion", ThisObject);
	FilesOperationsInternalClient.UpdateFromFileOnHardDriveWithNotification(Handler, FileData, UUID);
	
EndProcedure

&AtClient
Procedure StandardSaveAndClose(Command)
	
	If HandleFileRecordCommand() Then
		
		Result = New Structure();
		Result.Insert("ErrorText", "");
		Result.Insert("FileAdded", True);
		Result.Insert("FileRef", CurrentRefToFile());
		
		Close(Result);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StandardWrite(Command)
	
	HandleFileRecordCommand();
	
EndProcedure

&AtClient
Procedure StandardSetDeletionMark(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	If Modified Then
		If ThisObject.Object.DeletionMark Then
			QueryText = NStr(
				"en = 'To proceed, save the file changes.
				      |Save the changes and clear the deletion mark from file
				      |""%1""?';");
		Else
			QueryText = NStr(
				"en = 'To proceed, you need to save the file changes.
				      |Save the changes and mark the
				      |""%1"" file for deletion?';");
		EndIf;
	Else
		If ThisObject.Object.DeletionMark Then
			QueryText = NStr("en = 'Deletion mark will be cleared from %1.
			                          |Continue?';");
		Else
			QueryText = NStr("en = '%1 will be marked for deletion.
			                          |Continue?';");
		EndIf;
	EndIf;
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		QueryText, ThisObject.Object.Ref);
		
	NotifyDescription = New NotifyDescription("StandardSetDeletionMarkAnswerReceived", ThisObject);
	ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure StandardSetDeletionMarkAnswerReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		ThisObject.Object.DeletionMark = Not ThisObject.Object.DeletionMark;
		HandleFileRecordCommand();
	EndIf;
	
EndProcedure

&AtClient
Procedure StandardReread(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	If Not Modified Then
		UpdateObject();
		Return;
	EndIf;
	
	QueryText = NStr("en = 'The data has been changed. Do you want to refresh the data?';");
	
	NotifyDescription = New NotifyDescription("StandardRereadAnswerReceived", ThisObject);
	ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure StandardRereadAnswerReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		UpdateObject();
		Modified = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure StandardCommandsCopy(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	FormParameters = New Structure("CopyingValue", CurrentRefToFile());
	FilesOperationsClient.OpenFileForm(Undefined,, FormParameters);
	
EndProcedure

&AtClient
Procedure Print(Command)
	
	File = CurrentRefToFile();
	If ValueIsFilled(File) Or HandleFileRecordCommand() Then
		Files = CommonClientServer.ValueInArray(CurrentRefToFile()); // Re-obtain the reference if the new file is written.
		FilesOperationsClient.PrintFiles(Files, ThisObject.UUID);
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintWithStamp(Command)
	
	File = CurrentRefToFile();
	If ValueIsFilled(File) Or HandleFileRecordCommand() Then
		FilesOperationsInternalClient.DoPrintFileWithStamp(File, UUID);
	EndIf;
	
EndProcedure

&AtClient
Procedure Send(Command)
	
	File = CurrentRefToFile();
	If ValueIsFilled(File) Or HandleFileRecordCommand() Then
		Files = CommonClientServer.ValueInArray(File);
		OnSendFilesViaEmail(SendOptions, Files, ThisObject.Object.FileOwner, UUID);
		FilesOperationsInternalClient.SendFilesViaEmail(Files, UUID, SendOptions);
	EndIf;
	
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

///////////////////////////////////////////////////////////////////////////////////
// Digital signature and encryption command handlers.

&AtClient
Procedure Sign(Command)
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	If IsNew()
		Or ValueIsFilled(ThisObject.Object.BeingEditedBy)
		Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	If Modified Then
		If Not WriteFile() Then
			Return;
		EndIf;
	EndIf;
	
	NotifyDescription      = New NotifyDescription("OnGetSignature", ThisObject);
	AdditionalParameters = New Structure("ResultProcessing", NotifyDescription);
	
	ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
	SigningParameters = ModuleDigitalSignatureClient.NewSignatureType();
	SigningParameters.CanSelectLetterOfAuthority = True;
	
	FilesOperationsClient.SignFile(
		CurrentRefToFile(), UUID, AdditionalParameters, SigningParameters);
	
EndProcedure

&AtClient
Procedure AddDSFromFile(Command)
	
	If IsNew()
		Or ValueIsFilled(ThisObject.Object.BeingEditedBy)
		Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	AttachedFile = CurrentRefToFile();
	FilesOperationsInternalClient.AddSignatureFromFile(
		AttachedFile,
		UUID,
		New NotifyDescription("OnGetSignatures", ThisObject));
	
EndProcedure

&AtClient
Procedure SaveWithDigitalSignature(Command)
	
	If IsNew()
		Or ValueIsFilled(ThisObject.Object.BeingEditedBy)
		Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FilesOperationsClient.SaveWithDigitalSignature(
		CurrentRefToFile(),
		UUID);
	
EndProcedure

&AtClient
Procedure Encrypt(Command)
	
	If IsNew() Or ValueIsFilled(ThisObject.Object.BeingEditedBy) Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	If Modified Then
		If Not WriteFile() Then
			Return;
		EndIf;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.GetFileDataAndVersionsCount(CurrentRefToFile());
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData", FileData);
	Handler = New NotifyDescription("EncryptAfterEncryptAtClient", ThisObject, HandlerParameters);
	
	FilesOperationsInternalClient.Encrypt(
		Handler,
		FileData,
		UUID);
		
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
		WorkingDirectoryName);
	
	File = CurrentRefToFile();
	FilesOperationsInternalClient.InformOfEncryption(FilesArrayInWorkingDirectoryToDelete,
		ExecutionParameters.FileData.Owner, File);
		
	NotifyChanged(File);
	FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters();
	Notify("Write_File", FileWriteNotificationParameters, File);
	
	SetAvaliabilityOfEncryptionList();
	
EndProcedure

&AtClient
Procedure Decrypt(Command)
	
	If IsNew() Or Not ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.GetFileDataAndVersionsCount(CurrentRefToFile());
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData", FileData);
	Handler = New NotifyDescription("DecryptAfterDecryptAtClient", ThisObject, HandlerParameters);
	
	FilesOperationsInternalClient.Decrypt(
		Handler,
		FileData.Ref,
		UUID,
		FileData);
	
EndProcedure

&AtClient
Procedure DecryptAfterDecryptAtClient(Result, ExecutionParameters) Export
	
	If Not Result.Success Then
		Return;
	EndIf;
	WorkingDirectoryName = FilesOperationsInternalClient.UserWorkingDirectory();
	
	DecryptServer(Result.DataArrayToStoreInDatabase, WorkingDirectoryName);
	
	FilesOperationsInternalClient.InformOfDecryption(
		ExecutionParameters.FileData.Owner,
		CurrentRefToFile());
	
	FillEncryptionListAtServer();
	SetAvaliabilityOfEncryptionList();
	
EndProcedure

&AtServer
Procedure FillEncryptionListAtServer()
	FilesOperationsInternal.FillEncryptionList(ThisObject);
EndProcedure

&AtClient
Procedure DigitalSignatureCommandListOpenSignature(Command)
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.OpenSignature(Items.DigitalSignatures.CurrentData);
	
EndProcedure

&AtClient
Procedure VerifyDigitalSignature(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	If Items.DigitalSignatures.SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	FileData = FileData(CurrentRefToFile(), UUID);
	FilesOperationsInternalClient.VerifySignatures(
		ThisObject,
		FileData.RefToBinaryFileData,
		Items.DigitalSignatures.SelectedRows);
		
	DetermineIfModified();
	
EndProcedure

&AtClient
Procedure CheckEverything(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	FileData = FileData(CurrentRefToFile(), UUID);
	FilesOperationsInternalClient.VerifySignatures(ThisObject, FileData.RefToBinaryFileData);
	
	DetermineIfModified();
	
EndProcedure

&AtClient
Procedure DetermineIfModified()
	If Items.FormStandardSaveAndClose.Visible And Items.FormStandardSaveAndClose.Enabled Then
		Modified = True;
	EndIf;
EndProcedure

&AtClient
Procedure ExtendActionSignatures(Command)
	
	FollowUpHandler = New NotifyDescription("OnGetSignatures", ThisObject);
	
	RenewalOptions = New Structure;
	
	Structure = New Structure;
	Structure.Insert("SignedObject", Parameters.Key);
	Structure.Insert("SequenceNumber", Undefined);
	RenewalOptions.Insert("Signature", Structure);
	
	FilesOperationsInternalClient.ExtendActionSignatures(ThisObject, RenewalOptions, FollowUpHandler);
	
EndProcedure

&AtClient
Procedure SaveSignature(Command)
	
	If Items.DigitalSignatures.CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Items.DigitalSignatures.CurrentData;
	
	If CurrentData.Object = Undefined Or CurrentData.Object.IsEmpty() Then
		Return;
	EndIf;
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
	
	SignatureFileName = CurrentData.SignatureFileName;
	If Not ValueIsFilled(SignatureFileName) Then
	
		SignatureFilesExtension = ModuleDigitalSignatureClient.PersonalSettings().SignatureFilesExtension;
		ModuleDigitalSignatureInternalClientServer = CommonClient.CommonModule("DigitalSignatureInternalClientServer");
		SignatureFileName = ModuleDigitalSignatureInternalClientServer.SignatureFileName(ThisObject.Object.Description,
				CurrentData.CertificateOwner, SignatureFilesExtension);
	EndIf;
	
	
	ModuleDigitalSignatureClient.SaveSignature(CurrentData.SignatureAddress, SignatureFileName);
	
EndProcedure

&AtClient
Procedure DeleteDS(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("DeleteDigitalSignatureAnswerReceived", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("en = 'Do you want to delete the selected signatures?';"), QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure DeleteDigitalSignatureAnswerReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	
	File = CurrentRefToFile();
	DeleteFromSignatureListAndWriteFile();
	NotifyChanged(File);
	FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters();
	Notify("Write_File", FileWriteNotificationParameters, File);
	SetAvaliabilityOfDSCommandsList();
	
EndProcedure

&AtClient
Procedure OpenEncryptionCertificate(Command)
	
	CurrentData = Items.EncryptionCertificates.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
	
	If IsBlankString(CurrentData.CertificateAddress) Then
		ModuleDigitalSignatureClient.OpenCertificate(CurrentData.Thumbprint);
	Else
		ModuleDigitalSignatureClient.OpenCertificate(CurrentData.CertificateAddress);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetAvaliabilityOfDSCommandsList()
	
	FilesOperationsInternalClient.SetCommandsAvailabilityOfDigitalSignaturesList(ThisObject, IsNew());
	
EndProcedure

&AtClient
Procedure SetAvaliabilityOfEncryptionList()
	
	FilesOperationsInternalClient.SetCommandsAvailabilityOfEncryptionCertificatesList(ThisObject);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////////
// Command handlers to support collaboration in operations with files.

&AtClient
Procedure Lock(Command)
	
	If Modified And Not HandleFileRecordCommand() Then
		Return;
	EndIf;
	
	Handler = New NotifyDescription("ReadAndSetFormItemsAvailability", ThisObject);
	FilesOperationsInternalClient.LockWithNotification(Handler, CurrentRefToFile(), UUID);
	
EndProcedure

&AtClient
Procedure Edit(Command)
	
	If IsNew()
		Or ThisObject.Object.SignedWithDS
		Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	If ValueIsFilled(ThisObject.Object.BeingEditedBy)
	   And ThisObject.Object.BeingEditedBy <> CurrentUser Then
		Return;
	EndIf;
	
	If Modified And Not HandleFileRecordCommand() Then
		Return
	EndIf;
	
	FileRef = CurrentRefToFile();
	FileData = FileData(FileRef, UUID);

	FileBeingEdited = ValueIsFilled(ThisObject.Object.BeingEditedBy);
	FilesOperationsInternalClient.EditFile(Undefined, FileData, UUID);
	
	If Not FileBeingEdited Then
		UpdateObject();
		NotifyChanged(FileRef);
		FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters();
		Notify("Write_File", FileWriteNotificationParameters, FileRef);
	EndIf;
	
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	If IsNew()
		Or Not ValueIsFilled(ThisObject.Object.BeingEditedBy)
		Or ThisObject.Object.BeingEditedBy <> CurrentUser Then
			Return;
	EndIf;
	
	FileData = FileData(CurrentRefToFile(), UUID, "ServerCall");
	
	NotifyDescription = New NotifyDescription("EndEditingPuttingCompleted", ThisObject);
	FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(NotifyDescription, FileData.Ref, UUID);
	FileUpdateParameters.StoreVersions = FileData.StoreVersions;
	If Not CanCreateFileVersions Then
		FileUpdateParameters.Insert("CreateNewVersion", False);
	EndIf;
	FileUpdateParameters.CurrentUserEditsFile = FileData.CurrentUserEditsFile;
	FileUpdateParameters.BeingEditedBy = FileData.BeingEditedBy;
	FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
	UpdateObject();
	
EndProcedure

&AtClient
Procedure EndEditingPuttingCompleted(FileInfo, AdditionalParameters) Export
	
	UpdateObject();
	
	File = CurrentRefToFile();
	NotifyChanged(File);
	FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters();
	Notify("Write_File", FileWriteNotificationParameters, File);
	
EndProcedure

&AtClient
Procedure Release(Command)
	
	If IsNew()
		Or Not ValueIsFilled(ThisObject.Object.BeingEditedBy)
		Or ThisObject.Object.BeingEditedBy <> CurrentUser And Not FilesModification Then
		
		Return;
	EndIf;
	
	File = CurrentRefToFile();
	UnlockFile();
	NotifyChanged(File);
	FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters("EditCanceled");
	Notify("Write_File", FileWriteNotificationParameters, File);
	FilesOperationsInternalClient.ChangeLockedFilesCount();
	
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	
	If Modified Then
		WriteFile();
	EndIf;
	
	Handler = New NotifyDescription("ReadAndSetFormItemsAvailability", ThisObject);
	FilesOperationsInternalClient.SaveFileChangesWithNotification(Handler,
		CurrentRefToFile(), UUID);
	
EndProcedure

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

// End StandardSubsystems.Properties

&AtClient
Procedure Delete(Command)
	
	FilesOperationsInternalClient.DeleteData(
		New NotifyDescription("AfterDeleteData", ThisObject),
		CurrentRefToFile(), UUID);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetTheVisibilityOfTheFormCommands()
	
	// Handle the external flag "OnlyFileDataReader".
	// For example, see "Interactions.OnCreateFilesItemForm".
	For Each Command In NamesOfCommandsForChangingFileData() Do
		For Each FormCommand In Command.Value Do
			Items[FormCommand].Visible = Not OnlyFileDataReader And Items[FormCommand].Visible;	
		EndDo;
	EndDo;	
	
	Items.FormDelete.Visible = (ThisObject.Object.Author = CurrentUser) And Items.FormDelete.Visible;
	
EndProcedure

&AtServer
Procedure RefreshTitle()
	
	CurrentObjectRef = CurrentRefToFileServer();
	If ValueIsFilled(CurrentObjectRef) Then
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 (Attachment)';"), String(CurrentObjectRef));
	Else
		Title = NStr("en = 'Create attachment';")
	EndIf;
	
EndProcedure

&AtClient
Procedure DisplayAdditionalDataTabs()
	
	If Items.GroupAdditionalAttributes.ChildItems.Count() > 0 Then
		BlankDecoration = Items.Find("PropertiesEmptyDecoration");
		If BlankDecoration <> Undefined Then
			AdditionalAttributesVisibility = BlankDecoration.Visible;
		Else
			AdditionalAttributesVisibility = True;
		EndIf;
	Else
		AdditionalAttributesVisibility = False;
	EndIf;
	
	UseTabs = AdditionalAttributesVisibility Or Items.DigitalSignaturesGroup.Visible Or Items.EncryptionCertificatesGroup.Visible;
	Items.AdditionalPageDataGroup.PagesRepresentation =
	?(UseTabs , FormPagesRepresentation.TabsOnTop, FormPagesRepresentation.None);

EndProcedure

&AtServerNoContext
Function FileData(Val AttachedFile, Val FormIdentifier = Undefined, Val Mode = "")
	
	UnlockObject(AttachedFile, FormIdentifier);
	If Mode = "ToOpen" Then
		Return FilesOperationsInternalServerCall.FileDataToOpen(
			AttachedFile, Undefined, FormIdentifier);
	ElsIf Mode = "ForSave" Then
		Return FilesOperationsInternalServerCall.FileDataToSave(
			AttachedFile,, FormIdentifier);
	ElsIf Mode = "ServerCall" Then
		FileDataParameters = FilesOperationsClientServer.FileDataParameters();
		FileDataParameters.FormIdentifier = FormIdentifier;
		Return FilesOperationsInternalServerCall.FileData(AttachedFile,, FileDataParameters);
	Else
		FileDataParameters = FilesOperationsClientServer.FileDataParameters();
		FileDataParameters.GetBinaryDataRef = True;
		FileDataParameters.FormIdentifier = FormIdentifier;
		Return FilesOperations.FileData(AttachedFile, FileDataParameters);
	EndIf;
	
EndFunction

&AtClient
Procedure OpenFileForViewing()
	
	If IsNew()
		Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	If RestrictedExtensions.FindByValue(ThisObject.Object.Extension) <> Undefined Then
		Notification = New NotifyDescription("OpenFileAfterConfirm", ThisObject);
		UsersInternalClient.ShowSecurityWarning(Notification,
			UsersInternalClientServer.SecurityWarningKinds().BeforeOpenFile);
		Return;
	EndIf;
	
	FileBeingEdited = ValueIsFilled(ThisObject.Object.BeingEditedBy)
		And ThisObject.Object.BeingEditedBy = CurrentUser;
	FileData = FileData(CurrentRefToFile(), UUID, "ToOpen");	
	FilesOperationsClient.OpenFile(FileData, FileBeingEdited);
	
EndProcedure

&AtClient
Procedure OpenFileAfterConfirm(Result, AdditionalParameters) Export
	
	If Result <> Undefined And Result = "Continue" Then
		FileBeingEdited = ValueIsFilled(ThisObject.Object.BeingEditedBy)
			And ThisObject.Object.BeingEditedBy = CurrentUser;
		
		FileData = FileData(CurrentRefToFile(), UUID, "ToOpen");
		FilesOperationsClient.OpenFile(FileData, FileBeingEdited);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenFileDirectory()
	
	If IsNew()
		Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = FileData(CurrentRefToFile(), UUID, "ToOpen");
	FilesOperationsClient.OpenFileDirectory(FileData);
	
EndProcedure

&AtClient
Procedure SaveAs()
	
	If IsNew() Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = FileData(CurrentRefToFile(), UUID, "ForSave");
	FilesOperationsInternalClient.SaveAs(Undefined, FileData, Undefined);
	
EndProcedure

&AtClient
Procedure AfterDeleteData(Result, AdditionalParameters) Export
	
	Close();
	
EndProcedure

&AtServer
Procedure DeleteFromSignatureListAndWriteFile()
	
	If Not Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
	
	RowIndexes = New Array;
	
	For Each SelectedRowNumber In Items.DigitalSignatures.SelectedRows Do
		RowToDelete = DigitalSignatures.FindByID(SelectedRowNumber);
		RowIndexes.Add(RowToDelete.SequenceNumber);
	EndDo;
	
	ObjectToWrite = FormAttributeToValue("Object");
	ModuleDigitalSignature.DeleteSignature(ObjectToWrite, RowIndexes);
	WriteFile(ObjectToWrite);
	ValueToFormAttribute(ObjectToWrite, "Object");
	
	FilesOperationsInternal.FillSignatureList(ThisObject);
	SetButtonsAvailability(ThisObject, Items);
	
EndProcedure

// Parameters:
//  Form - ClientApplicationForm:
//     * Object - FormDataStructure:
//       ** Extension - String
//       ** SignedWithDS - Boolean
//  Items - FormAllItems
//
&AtClientAtServerNoContext
Procedure SetButtonsAvailability(Form, Items)
	
	AllCommandNames = AllFormCommandsNames();
	CommandsNames = AvailableFormCommands(Form);
		
	If Form.DigitalSignatures.Count() = 0 Then
		MakeCommandUnavailable(CommandsNames, "OpenSignature");
		Form.Items.FormSaveWithSignature.Visible = False;
	Else
		Form.Items.FormSaveWithSignature.Visible = True;
	EndIf;
	
	For Each FormItem In Items Do
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		If AllCommandNames.Find(FormItem.CommandName) <> Undefined Then
			FormItem.Enabled = False;
		EndIf;
	EndDo;
	
	For Each FormItem In Items Do
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		If CommandsNames.Find(FormItem.CommandName) <> Undefined Then
			FormItem.Enabled = True;
		EndIf;
	EndDo;
	
	PrintWithStampAvailable = (Form.Object.Extension = "mxl" Or Form.Object.Extension = "docx") And Form.Object.SignedWithDS;
	Items.PrintWithStamp.Visible = PrintWithStampAvailable;
	
	If Not PrintWithStampAvailable Then
		Items.PrintSubmenu.Type = FormGroupType.ButtonGroup;
		Items.Print.Title = NStr("en = 'Print';");
	Else
		Items.PrintSubmenu.Type = FormGroupType.Popup;
		Items.Print.Title = NStr("en = 'Quick print';");
	EndIf;
	
	If CommandsNames.Find("Edit") <> Undefined Then
		Items["LongDesc"].InputHint = NStr("en = 'A brief description. To edit the file, click Edit.';");
	Else
		Items["LongDesc"].InputHint = NStr("en = 'A brief description. To edit the file, click Edit.';");
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function AllFormCommandsNames()
	
	CommandsNames = FileChangeCommandsNames();
	CommonClientServer.SupplementArray(CommandsNames, OtherCommandsNames()); 
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function OtherCommandsNames()
	
	CommandsNames = New Array;
	
	// Simple commands that are available to any user that reads the files
	CommandsNames.Add("SaveWithDigitalSignature");
	
	CommandsNames.Add("OpenCertificate");
	CommandsNames.Add("OpenSignature");
	CommandsNames.Add("VerifyDigitalSignature");
	CommandsNames.Add("CheckEverything");
	CommandsNames.Add("SaveSignature");
	
	CommandsNames.Add("OpenFileDirectory");
	CommandsNames.Add("OpenFileForViewing");
	CommandsNames.Add("SaveAs");
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function FileChangeCommandsNames()
	
	CommandsNames = New Array;
	
	For Each CommandsElements In NamesOfCommandsForChangingFileData() Do
		CommandsNames.Add(CommandsElements.Key);
	EndDo;
	
	CommandsNames.Add("StandardCommandsCopy");
	CommandsNames.Add("StandardWrite");
	CommandsNames.Add("StandardSaveAndClose");
	CommandsNames.Add("StandardSetDeletionMark");
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function NamesOfCommandsForChangingFileData()
	CommandsNames = New Map;
	
	ItemsNames = New Array;
	ItemsNames.Add("FormSign");
	ItemsNames.Add("DigitalSignaturesSign");
	CommandsNames.Insert("Sign", ItemsNames);
	
	ItemsNames = New Array;
	ItemsNames.Add("FormAddSignatureFromFile");
	CommandsNames.Insert("AddDSFromFile", ItemsNames);
	
	ItemsNames = New Array;
	ItemsNames.Add("DigitalSignaturesDelete");
	CommandsNames.Insert("DeleteDS", ItemsNames);

	ItemsNames = New Array;
	ItemsNames.Add("Edit");
	ItemsNames.Add("FormEdit");
	CommandsNames.Insert("Edit", ItemsNames);
	
	ItemsNames = New Array;
	ItemsNames.Add("FormLock");
	CommandsNames.Insert("Lock", ItemsNames);
	
	ItemsNames = New Array;
	ItemsNames.Add("EndEdit");
	ItemsNames.Add("FormEndEdit");
	CommandsNames.Insert("EndEdit", ItemsNames);
	
	ItemsNames = New Array;
	ItemsNames.Add("FormSaveChanges");
	CommandsNames.Insert("SaveChanges", ItemsNames);
	
	ItemsNames = New Array;
	ItemsNames.Add("DigitalSignaturesExtendActionSignatures");
	CommandsNames.Insert("ExtendActionSignatures", ItemsNames);
	
	ItemsNames = New Array;
	ItemsNames.Add("FormUpdateFromFileOnHardDrive");
	CommandsNames.Insert("UpdateFromFileOnHardDrive", ItemsNames);
	
	ItemsNames = New Array;
	ItemsNames.Add("FormEncrypt");
	CommandsNames.Insert("Encrypt", ItemsNames);
	
	ItemsNames = New Array;
	ItemsNames.Add("FormDecrypt");
	CommandsNames.Insert("Decrypt", ItemsNames);
	
	ItemsNames = New Array;
	ItemsNames.Add("FormDelete");
	CommandsNames.Insert("Delete", ItemsNames);

	ItemsNames = New Array;
	ItemsNames.Add("FormEndEdit");
	ItemsNames.Add("EndEdit");
	CommandsNames.Insert("EndEdit", ItemsNames);
	
	ItemsNames = New Array;
	ItemsNames.Add("FormRelease");
	CommandsNames.Insert("Release", ItemsNames);
	
	Return CommandsNames;
EndFunction

&AtClientAtServerNoContext
Function AvailableFormCommands(Form)
	
	FormObject1 = Form["Object"]; // DefinedType.AttachedFileObject
	IsNewFile = FormObject1.Ref.IsEmpty();
	
	If IsNewFile Then
		CommandsNames = New Array;
		CommandsNames.Add("StandardWrite");
		CommandsNames.Add("StandardSaveAndClose");
		Return CommandsNames;
	EndIf;
	
	CommandsNames = AllFormCommandsNames();
	
	FileToEditInCloud = Form.FileToEditInCloud;
	FileBeingEdited = ValueIsFilled(FormObject1.BeingEditedBy) Or FileToEditInCloud;
	CurrentUserEditsFile = FormObject1.BeingEditedBy = Form.CurrentUser;
	FileSigned = FormObject1.SignedWithDS;
	FileEncrypted = FormObject1.Encrypted;
	
	If FileBeingEdited Then
		If CurrentUserEditsFile Then
			MakeCommandUnavailable(CommandsNames, "UpdateFromFileOnHardDrive");
		Else
			MakeCommandUnavailable(CommandsNames, "EndEdit");
			MakeCommandUnavailable(CommandsNames, "Edit");
			If Not Form.FilesModification Then
				MakeCommandUnavailable(CommandsNames, "Release");
			EndIf;
		EndIf;
		MakeCommandUnavailable(CommandsNames, "Lock");
		
		MakeDSCommandsUnavailable(CommandsNames);
		
		MakeCommandUnavailable(CommandsNames, "UpdateFromFileOnHardDrive");
		MakeCommandUnavailable(CommandsNames, "SaveAs");
		
		MakeCommandUnavailable(CommandsNames, "Encrypt");
		MakeCommandUnavailable(CommandsNames, "Decrypt");
	Else
		MakeCommandUnavailable(CommandsNames, "EndEdit");
		MakeCommandUnavailable(CommandsNames, "SaveChanges");
		If Not Form.FilesModification Then
			MakeCommandUnavailable(CommandsNames, "Release");
		EndIf;
	EndIf;
	
	If FileSigned Then
		MakeCommandUnavailable(CommandsNames, "EndEdit");
		If Not Form.FilesModification Then
			MakeCommandUnavailable(CommandsNames, "Release");
		EndIf;
		MakeCommandUnavailable(CommandsNames, "Edit");
		MakeCommandUnavailable(CommandsNames, "UpdateFromFileOnHardDrive");
	Else
		MakeCommandUnavailable(CommandsNames, "OpenCertificate");
		MakeCommandUnavailable(CommandsNames, "OpenSignature");
		MakeCommandUnavailable(CommandsNames, "VerifyDigitalSignature");
		MakeCommandUnavailable(CommandsNames, "CheckEverything");
		MakeCommandUnavailable(CommandsNames, "SaveSignature");
		MakeCommandUnavailable(CommandsNames, "DeleteDS");
		MakeCommandUnavailable(CommandsNames, "SaveWithDigitalSignature");
	EndIf;
	
	If FileEncrypted Then
		MakeDSCommandsUnavailable(CommandsNames);
		MakeCommandUnavailable(CommandsNames, "EndEdit");
		If Not Form.FilesModification Then
			MakeCommandUnavailable(CommandsNames, "Release");
		EndIf;
		MakeCommandUnavailable(CommandsNames, "Edit");
		
		MakeCommandUnavailable(CommandsNames, "UpdateFromFileOnHardDrive");
		
		MakeCommandUnavailable(CommandsNames, "Encrypt");
		
		MakeCommandUnavailable(CommandsNames, "OpenFileDirectory");
		MakeCommandUnavailable(CommandsNames, "OpenFileForViewing");
		MakeCommandUnavailable(CommandsNames, "SaveAs");
		
		MakeCommandUnavailable(CommandsNames, "Sign");
	Else
		MakeCommandUnavailable(CommandsNames, "Decrypt");
	EndIf;
	
	If FileToEditInCloud Then
		MakeCommandUnavailable(CommandsNames, "StandardCommandsCopy");
		MakeCommandUnavailable(CommandsNames, "StandardSetDeletionMark");
		MakeCommandUnavailable(CommandsNames, "StandardWrite");
		MakeCommandUnavailable(CommandsNames, "StandardSaveAndClose");
		MakeCommandUnavailable(CommandsNames, "SaveChanges");
		
	EndIf;
	
	If Form.ReadOnly Then
		MakeDSCommandsUnavailable(CommandsNames);
	EndIf;
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Procedure MakeDSCommandsUnavailable(Val CommandsNames)
	
	MakeCommandUnavailable(CommandsNames, "Sign");
	MakeCommandUnavailable(CommandsNames, "AddDSFromFile");
	MakeCommandUnavailable(CommandsNames, "SaveWithDigitalSignature");
	
EndProcedure

&AtClientAtServerNoContext
Procedure MakeCommandUnavailable(CommandsNames, CommandName)
	
	CommonClientServer.DeleteValueFromArray(CommandsNames, CommandName);
	
EndProcedure

&AtServer
Procedure EncryptServer(DataArrayToStoreInDatabase,
                            ThumbprintsArray,
                            FilesArrayInWorkingDirectoryToDelete,
                            WorkingDirectoryName)
	
	EncryptionInformationWriteParameters = FilesOperationsInternal.EncryptionInformationWriteParameters();
	EncryptionInformationWriteParameters.WorkingDirectoryName = WorkingDirectoryName;
	EncryptionInformationWriteParameters.DataArrayToStoreInDatabase = DataArrayToStoreInDatabase;
	EncryptionInformationWriteParameters.ThumbprintsArray = ThumbprintsArray;
	EncryptionInformationWriteParameters.FilesArrayInWorkingDirectoryToDelete = FilesArrayInWorkingDirectoryToDelete;
	EncryptionInformationWriteParameters.UUID = UUID;
	
	FilesOperationsInternal.WriteEncryptionInformation(
		CurrentRefToFileServer(), EncryptionInformationWriteParameters);
	
	UpdateInfoOfObjectCertificates();
	
EndProcedure

&AtServer
Procedure DecryptServer(DataArrayToStoreInDatabase, WorkingDirectoryName)
	
	EncryptionInformationWriteParameters = FilesOperationsInternal.EncryptionInformationWriteParameters();
	EncryptionInformationWriteParameters.Encrypt = False;
	EncryptionInformationWriteParameters.WorkingDirectoryName = WorkingDirectoryName;
	EncryptionInformationWriteParameters.DataArrayToStoreInDatabase = DataArrayToStoreInDatabase;
	EncryptionInformationWriteParameters.UUID = UUID;
	
	FilesOperationsInternal.WriteEncryptionInformation(
		CurrentRefToFileServer(), EncryptionInformationWriteParameters);
	
	UpdateInfoOfObjectCertificates();
	
EndProcedure

&AtServer
Procedure UpdateObject()
	
	ValueToFormAttribute(CurrentRefToFileServer().GetObject(), "Object");
	SetButtonsAvailability(ThisObject, Items);
	ModificationDate = ToLocalTime(ThisObject.Object.UniversalModificationDate);
	FilesOperationsInternal.FillSignatureList(ThisObject);
	FilesOperationsInternal.FillEncryptionList(ThisObject);
	
EndProcedure

&AtServer
Procedure UnlockFile()
	
	ObjectToWrite = FormAttributeToValue("Object");
	FilesOperationsInternal.UnlockFile(ObjectToWrite);
	ValueToFormAttribute(ObjectToWrite, "Object");
	
EndProcedure

&AtClient
Function HandleFileRecordCommand()
	
	If IsBlankString(ThisObject.Object.Description) Then
		CommonClient.MessageToUser(
			NStr("en = 'To proceed, please provide the file name.';"), , "Description", "Object");
		Return False;
	EndIf;
	
	Try
		FilesOperationsInternalClient.CorrectFileName(ThisObject.Object.Description);
	Except
		CommonClient.MessageToUser(
			ErrorProcessing.BriefErrorDescription(ErrorInfo()), ,"Description", "Object");
		Return False;
	EndTry;
	
	If Not WriteFile() Then
		Return False;
	EndIf;
	
	Modified = False;
	RepresentDataChange(ThisObject.Object.Ref, DataChangeType.Update);
	NotifyChanged(ThisObject.Object.Ref);
	NotifyChanged(ThisObject.Object.FileOwner);
	
	FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters("Record");
	FileWriteNotificationParameters.IsNew = FileCreated;
	Notify("Write_File", FileWriteNotificationParameters, ThisObject.Object.Ref);
	
	SetAvaliabilityOfDSCommandsList();
	SetAvaliabilityOfEncryptionList();
	
	If DescriptionBeforeWrite <> ThisObject.Object.Description Then
		
		// update file in cache
		FilesOperationsInternalClient.RefreshInformationInWorkingDirectory(
			ThisObject.Object.Ref, ThisObject.Object.Description);
		
		DescriptionBeforeWrite = ThisObject.Object.Description;
		
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Function WriteFile(Val ParameterObject = Undefined)
	
	If ParameterObject = Undefined Then
		ObjectToWrite = FormAttributeToValue("Object");
	Else
		ObjectToWrite = ParameterObject;
	EndIf;
	
	If ValueIsFilled(CopyingValue) Then
		BeginTransaction();
		Try
			BinaryData = FilesOperations.FileBinaryData(CopyingValue);
			CopyingValueAttributes = Common.ObjectAttributesValues(CopyingValue, 
				"Size, Extension");
			FileStorageType = FilesOperationsInternal.FileStorageType(CopyingValueAttributes.Size, 
				CopyingValueAttributes.Extension);
			If FileStorageType = Enums.FileStorageTypes.InInfobase Then
				RefToNew = Catalogs[CatalogName].GetRef();
				ObjectToWrite.SetNewObjectRef(RefToNew);
				FilesOperationsInternal.WriteFileToInfobase(RefToNew, BinaryData);
				ObjectToWrite.FileStorageType = FileStorageType;
			Else
				ObjectToWrite.Volume = Undefined;
				ObjectToWrite.PathToFile = Undefined;
				ObjectToWrite.FileStorageType = Undefined;
				FilesOperationsInVolumesInternal.AppendFile(ObjectToWrite, BinaryData);
			EndIf;
			
			If DigitalSignatureAvailable Then
				FilesOperationsInternal.MoveSignaturesCheckResults(DigitalSignatures, CopyingValue);
			EndIf;
			
			ObjectToWrite.Write();
			
			If DigitalSignatureAvailable And Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
				ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
				
				SourceCertificates = ModuleDigitalSignature.EncryptionCertificates(CopyingValue);
				ModuleDigitalSignature.WriteEncryptionCertificates(ObjectToWrite, SourceCertificates);
				
				SetSignatures = ModuleDigitalSignature.SetSignatures(CopyingValue);
				ModuleDigitalSignature.AddSignature(ObjectToWrite, SetSignatures);
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	Else
		BeginTransaction();
		Try
			If DigitalSignatureAvailable Then
				FilesOperationsInternal.MoveSignaturesCheckResults(DigitalSignatures, ObjectToWrite.Ref);
			EndIf;
			ObjectToWrite.Write();
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
		
	If ParameterObject = Undefined Then
		ValueToFormAttribute(ObjectToWrite, "Object");
	EndIf;
	
	CopyingValue = Catalogs[CatalogName].EmptyRef();
	SetButtonsAvailability(ThisObject, Items);
	RefreshTitle();
	
	Return True;
	
EndFunction

&AtServerNoContext
Procedure UnlockObject(Val Ref, Val UUID)
	
	UnlockDataForEdit(Ref, UUID);
	
EndProcedure

// Continue the SignDSFile procedure.
// It is called from the DigitalSignature subsystem after signing data for non-standard
// way of adding a signature to the object.
//
&AtClient
Procedure OnGetSignature(ExecutionParameters, Context) Export
	
	UpdateInfoOfObjectSignature();
	SetAvaliabilityOfDSCommandsList();
	
EndProcedure

// Continue the SignDSFile procedure.
// It is called from the DigitalSignature subsystem after preparing signatures from files
// for non-standard way of adding a signature to the object.
//
&AtClient
Procedure OnGetSignatures(ExecutionParameters, Context) Export
	
	UpdateInfoOfObjectSignature();
	SetAvaliabilityOfDSCommandsList();
	
EndProcedure

&AtServer
Procedure UpdateInfoOfObjectSignature()
	
	FileObject1 = CurrentRefToFileServer().GetObject();
	ValueToFormAttribute(FileObject1, "Object");
	FilesOperationsInternal.FillSignatureList(ThisObject);
	SetButtonsAvailability(ThisObject, Items);
	
EndProcedure

&AtServer
Procedure UpdateInfoOfObjectCertificates()
	
	FileObject1 = CurrentRefToFileServer().GetObject();
	ValueToFormAttribute(FileObject1, "Object");
	FilesOperationsInternal.FillEncryptionList(ThisObject);
	SetButtonsAvailability(ThisObject, Items);
	
EndProcedure

&AtClient
Procedure ReadAndSetFormItemsAvailability(Result, AdditionalParameters) Export
	
	ReadAndSetAvailabilityAtServer();
	
EndProcedure

&AtServer
Procedure ReadAndSetAvailabilityAtServer()
	
	FileObject1 = CurrentRefToFileServer().GetObject();
	ValueToFormAttribute(FileObject1, "Object");
	SetButtonsAvailability(ThisObject, Items);
	
EndProcedure

&AtClient
Function IsNew()
	
	Return CurrentRefToFile().IsEmpty();
	
EndFunction

&AtClient
Procedure UpdateFromFileOnHardDriveCompletion(Result, ExecutionParameters) Export
	
	UpdateObject();
	
	CurrentFile = CurrentRefToFile();
	NotifyChanged(CurrentFile);
	FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters();
	Notify("Write_File", FileWriteNotificationParameters, CurrentFile);
	
EndProcedure

&AtClient
Procedure OnChangeSigningOrEncryptionUsage()
	
	OnChangeUseSignOrEncryptionAtServer();
	DisplayAdditionalDataTabs();
	
EndProcedure

&AtServer
Procedure OnChangeUseSignOrEncryptionAtServer()
	
	FilesOperationsInternal.CryptographyOnCreateFormAtServer(ThisObject, False);
	
EndProcedure

&AtClient
Procedure AdditionalPageDataGroupOnCurrentPageChange(Item, CurrentPage)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties")
		And CurrentPage.Name = "GroupAdditionalAttributes"
		And Not ThisObject.PropertiesParameters.DeferredInitializationExecuted Then
		
		PropertiesExecuteDeferredInitialization();
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateCloudServiceNote(AttachedFile)
	
	NoteVisibility = False;
	
	If GetFunctionalOption("UseFileSync") Then
		
		SynchronizationInfo = FilesOperationsInternal.SynchronizationInfo(ThisObject.Object.FileOwner);
		
		If SynchronizationInfo.Count() > 0 Then
			
			Account = SynchronizationInfo.Account;
			NoteVisibility = True;
			
			FolderAddressInCloudService = FilesOperationsInternalClientServer.AddressInCloudService(
				SynchronizationInfo.Service, SynchronizationInfo.Href);
				
			Items.DecorationNote.Title = StringFunctions.FormattedString(
				NStr("en = 'This is a read-only file. It is stored in cloud service <a href=""%1"">%2</a>.';"),
				FolderAddressInCloudService, SynchronizationInfo.AccountDescription1);
			
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
Function EventLogFilterData(Account)
	
	Return FilesOperationsInternal.EventLogFilterData(Account);
	
EndFunction

&AtClient
Function CurrentFileDescription()
	
	FormObject = ThisObject.Object; // CatalogObject
	Return FormObject.Description;
	
EndFunction

&AtClient
Function CurrentRefToFile()
	
	FormObject = ThisObject.Object; // CatalogObject
	Return FormObject.Ref;
	
EndFunction

&AtServer
Function CurrentRefToFileServer()

	FormObject = ThisObject.Object; // CatalogObject
	Return FormObject.Ref;

EndFunction

// StandardSubsystems.AttachableCommands

&AtClient
Procedure Attachable_ExecuteCommand(Command)
	ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
	ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, ThisObject.Object);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
	ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, ThisObject.Object);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
	ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, ThisObject.Object);
EndProcedure

// End StandardSubsystems.AttachableCommands

&AtServerNoContext
Procedure OnSendFilesViaEmail(SendOptions, Val FilesToSend, FilesOwner, UUID)
	SSLSubsystemsIntegration.OnSendFilesViaEmail(SendOptions, FilesToSend, FilesOwner, UUID);
	FilesOperationsOverridable.OnSendFilesViaEmail(SendOptions, FilesToSend, FilesOwner, UUID);
EndProcedure

#EndRegion
