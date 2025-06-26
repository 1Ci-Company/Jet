///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

Procedure UpdateAttachedFile(Val AttachedFile, Val FileInfo) Export

	FilesOperations.RefreshFile(AttachedFile, FileInfo);

EndProcedure

// See the AddAttachedFile function in the StoredFiles module.
Function AppendFile(FileParameters, Val FileAddressInTempStorage, Val TempTextStorageAddress = "",
	Val LongDesc = "") Export

	Return FilesOperations.AppendFile(
		FileParameters, FileAddressInTempStorage, TempTextStorageAddress, LongDesc);

EndFunction

// Receives file data and its binary data.
//
// Parameters:
//  FileOrVersionRef - CatalogRef.Files
//                      - CatalogRef.FilesVersions - file or file version.
//  SignatureAddress - String - an URL, containing the signature file address in a temporary storage.
//  FormIdentifier  - UUID - a form UUID.
//
// Returns:
//   Structure:
//     * FileData - See FileData
//     * BinaryData - BinaryData
//     * SignatureBinaryData - BinaryData
//
Function FileDataAndBinaryData(FileOrVersionRef, SignatureAddress = Undefined, FormIdentifier = Undefined) Export

	ObjectMetadata = Metadata.FindByType(TypeOf(FileOrVersionRef));
	IsFilesCatalog = Common.HasObjectAttribute("FileOwner", ObjectMetadata);
	AbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", ObjectMetadata);

	If AbilityToStoreVersions Then
		If Not IsFilesCatalog Then
			FileOrVersionAttributes = Common.ObjectAttributesValues(FileOrVersionRef,
				"CurrentVersion, Owner");
		Else
			FileOrVersionAttributes = Common.ObjectAttributesValues(FileOrVersionRef, "CurrentVersion");
		EndIf;
	ElsIf Not IsFilesCatalog Then
		FileOrVersionAttributes = Common.ObjectAttributesValues(FileOrVersionRef, "Owner");
	EndIf;

	FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	FileDataParameters.GetBinaryDataRef = False;

	If AbilityToStoreVersions And ValueIsFilled(FileOrVersionAttributes.CurrentVersion) Then

		VersionRef = FileOrVersionAttributes.CurrentVersion;
		FileData = FileData(FileOrVersionRef, VersionRef, FileDataParameters);
	ElsIf IsFilesCatalog Then
		VersionRef = FileOrVersionRef;
		FileData = FileData(FileOrVersionRef,, FileDataParameters);
	Else
		VersionRef = FileOrVersionRef;
		FileData = FileData(FileOrVersionAttributes.Owner, VersionRef, FileDataParameters);
	EndIf;

	BinaryData = Undefined;

	FileStorageType = Common.ObjectAttributeValue(VersionRef, "FileStorageType");
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		BinaryData = FilesOperationsInVolumesInternal.FileData(VersionRef);
	Else
		FileStorage1 = FilesOperations.FileFromInfobaseStorage(VersionRef);
		BinaryData = FileStorage1.Get();
	EndIf;

	SignatureBinaryData = Undefined;
	If SignatureAddress <> Undefined Then
		SignatureBinaryData = GetFromTempStorage(SignatureAddress);
	EndIf;

	If FormIdentifier <> Undefined Then
		BinaryData = PutToTempStorage(BinaryData, FormIdentifier);
	EndIf;

	ReturnStructure = New Structure("FileData, BinaryData, SignatureBinaryData", FileData,
		BinaryData, SignatureBinaryData);

	Return ReturnStructure;

EndFunction

// Create a folder of files.
//
// Parameters:
//   Name - String - folder name
//   Parent - DefinedType.AttachedFilesOwner - parent folder.
//   User - CatalogRef.Users - a person responsible for a folder.
//   FilesGroup - DefinedType.AttachedFile - a group (for hierarchical file catalogs).
//   WorkingDirectory - String - a folder working directory in the file system.
//
// Returns:
//   CatalogRef.FilesFolders
//
Function CreateFilesFolder(Name, Parent, User = Undefined, FilesGroup = Undefined,
	WorkingDirectory = Undefined) Export

	If IsDirectoryFiles(Parent) Then
		Folder = Catalogs.FilesFolders.CreateItem();
		Folder.EmployeeResponsible = ?(User <> Undefined, User, Users.AuthorizedUser());
		Folder.Parent = Parent;
	Else

		Folder = Catalogs[FilesOperationsInternal.FileStoringCatalogName(Parent)].CreateFolder();
		If TypeOf(Folder.Ref) = TypeOf(Parent) Then
			Folder.Parent = ?(FilesGroup = Undefined, Parent, FilesGroup);
			Folder.FileOwner = Common.ObjectAttributeValue(Parent, "FileOwner");
		Else
			Folder.Parent = FilesGroup;
			Folder.FileOwner = Parent;
		EndIf;

		Folder.Author = ?(User <> Undefined, User, Users.AuthorizedUser());

	EndIf;
	Folder.Description = Name;
	Folder.CreationDate = CurrentSessionDate();
	Folder.Fill(Undefined);
	Folder.Write();

	If ValueIsFilled(WorkingDirectory) Then
		FilesOperationsInternal.SaveFolderWorkingDirectory(Folder.Ref, WorkingDirectory);
	EndIf;

	Return Folder.Ref;

EndFunction

// Creates a file in the infobase together with its version.
//
// Parameters:
//   Owner       - CatalogRef.FilesFolders
//                  - , AnyRef - it will be set to the FileOwner attribute of
//                    the created file.
//   FileInfo1 - See FilesOperationsClientServer.FileInfo1
//
// Returns:
//    CatalogRef.Files - created file.
//
Function CreateFileWithVersion(FileOwner, FileInfo1) Export

	If FileInfo1.Encrypted = Undefined Then
		
		FileInfo1.Encrypted = Lower(FileInfo1.ExtensionWithoutPoint) = Lower(FilesOperations.EncryptedFilesExtension());
		
		If FileInfo1.Encrypted Then
			ForUnencryptedFile = New File(FileInfo1.BaseName);
			FileInfo1.ExtensionWithoutPoint = CommonClientServer.ExtensionWithoutPoint(ForUnencryptedFile.Extension);
			FileInfo1.BaseName = ForUnencryptedFile.BaseName;
		EndIf;
	EndIf;
	
	BeginTransaction();
	Try

		FileRef = CreateFile(FileOwner, FileInfo1);
		Version = Catalogs.FilesVersions.EmptyRef();
		If FileInfo1.StoreVersions Then
			Version = FilesOperationsInternal.CreateVersion(FileRef, FileInfo1);
		EndIf;
		FilesOperationsInternal.UpdateVersionInFile(FileRef, Version, FileInfo1.TempTextStorageAddress);

		If Not FileInfo1.Encrypted And Not ValueIsFilled(FileInfo1.Encoding) Then
			FileInfo1.Encoding = FilesOperationsInternalClientServer.DetermineBinaryDataEncoding(
				FileInfo1.TempFileStorageAddress, FileInfo1.ExtensionWithoutPoint);
		EndIf;

		If FileInfo1.Encoding <> Undefined Then
			InformationRegisters.FilesEncoding.WriteFileVersionEncoding(
				?(Version = Catalogs.FilesVersions.EmptyRef(), FileRef, Version), FileInfo1.Encoding);
		EndIf;

		HasSaveRight = AccessRight("SaveUserData", Metadata);
		If FileInfo1.WriteToHistory And HasSaveRight Then
			FileURL1 = GetURL(FileRef);
			UserWorkHistory.Add(FileURL1);
		EndIf;

		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

	FilesOperationsOverridable.OnCreateFile(FileRef);
	Return FileRef;

EndFunction

// Releases the file.
//
// Parameters:
//   FileData - See FileData.
//   UUID - UUID - a form UUID.
//
Procedure UnlockFile(FileData, UUID = Undefined) Export

	BeginTransaction();
	Try
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(
			FileData.Ref)).FullName());
		DataLockItem.SetValue("Ref", FileData.Ref);
		DataLock.Lock();

		FileObject1 = FileData.Ref.GetObject();

		LockDataForEdit(FileObject1.Ref,, UUID);
		FileObject1.BeingEditedBy = Catalogs.Users.EmptyRef();
		FileObject1.LockedDate = Date("00010101000000");
		FileObject1.Write();

		FilesOperationsOverridable.OnUnlockFile(FileData, UUID);
		UnlockDataForEdit(FileData.Ref, UUID);
		CommitTransaction();
	Except
		RollbackTransaction();
		UnlockDataForEdit(FileData.Ref, UUID);
		Raise;
	EndTry;

EndProcedure

Function UnlockFiles(Val Files) Export

	FilesVersions = New Map;

	FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	FileDataParameters.GetBinaryDataRef = False;

	For Each AttachedFile In Files Do
		FilesOperationsInternal.UnlockFile(AttachedFile);
		FileData = FileData(AttachedFile,, FileDataParameters);
		FilesVersions.Insert(AttachedFile, FileData.CurrentVersion);
	EndDo;

	Result = New Structure;
	Result.Insert("LockedFilesCount", FilesOperationsInternal.LockedFilesCount());
	Result.Insert("FilesVersions", FilesVersions);
	Return Result;

EndFunction

// Lock the file for editing.
//
// Parameters:
//  FileData  - Structure - Output parameter.
//  ErrorString - String - Contains the error reason.
//                          For example, "The file is locked by another user".
//  AdditionalParameters - See FilesOperationsInternalClientServer.FileLockParameters
//
//
// Returns:
//   Boolean  - shows whether the operation is performed successfully.
//
Function LockFile(FileData, ErrorString = "", AdditionalParameters = Undefined) Export

	If AdditionalParameters = Undefined Then
		AdditionalParameters = FilesOperationsInternalClientServer.FileLockParameters();
	EndIf;

	ErrorString = "";
	FilesOperationsOverridable.OnAttemptToLockFile(FileData, ErrorString);
	If Not IsBlankString(ErrorString) Then
		Return False;
	EndIf;

	BeginTransaction();
	Try
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(
			FileData.Ref)).FullName());
		DataLockItem.SetValue("Ref", FileData.Ref);
		DataLock.Lock();

		FileObject1 = FileData.Ref.GetObject();

		LockDataForEdit(FileObject1.Ref,, AdditionalParameters.UUID);
		If AdditionalParameters.User = Undefined Then
			FileObject1.BeingEditedBy = Users.AuthorizedUser();
		Else
			FileObject1.BeingEditedBy = AdditionalParameters.User;
		EndIf;
		If TypeOf(AdditionalParameters.AdditionalProperties) = Type("Structure") Then
			CommonClientServer.SupplementStructure(FileObject1.AdditionalProperties,
				AdditionalParameters.AdditionalProperties, False);
		EndIf;
		FileObject1.LockedDate = CurrentSessionDate();
		FileObject1.Write();

		CurrentVersionURL = FileData.CurrentVersionURL;
		OwnerWorkingDirectory = FileData.OwnerWorkingDirectory;

		FileDataParameters = FilesOperationsClientServer.FileDataParameters();
		FileDataParameters.RaiseException1 = AdditionalParameters.RaiseException1;

		FileData = FileData(FileData.Ref, ?(FileData.Version = FileData.Ref, Undefined,
			FileData.Version), FileDataParameters);
		FileData.CurrentVersionURL = CurrentVersionURL;
		FileData.OwnerWorkingDirectory = OwnerWorkingDirectory;

		FilesOperationsOverridable.OnLockFile(FileData, AdditionalParameters.UUID);

		UnlockDataForEdit(FileData.Ref, AdditionalParameters.UUID);
		CommitTransaction();

	Except
		RollbackTransaction();
		UnlockDataForEdit(FileData.Ref, AdditionalParameters.UUID);
		Raise;
	EndTry;

	Return True;

EndFunction

// Returns an array of structures or a structure (depending on the passed data) 
// with various information records about the file.
//
// Parameters:
//  Files  - Array from:
//         - CatalogRef.Files
//  FormIdentifier             - UUID - a form UUID. The method puts the file to the temporary storage
//                                 of this form and returns the address in the RefToBinaryFileData property.
//
// Returns:
//  - Array of See FilesOperations.FileData
//      See FilesOperations.FileData
//   
//
Function FileDataForSigning(Val Files, FormIdentifier = Undefined) Export

	If TypeOf(Files) <> Type("Array") Then
		FileDataParameters = FilesOperationsClientServer.FileDataParameters();
		FileDataParameters.FormIdentifier = FormIdentifier;
		Return FileData(Files,, FileDataParameters);
	EndIf;

	FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	FileDataParameters.FormIdentifier = FormIdentifier;

	FilesData = New Array;
	For Each File In Files Do
		FilesData.Add(FileData(File,, FileDataParameters));
	EndDo;

	Return FilesData;

EndFunction

// Returns a structure with various information records on the file and version.
// 
// Parameters: 
//  FileRef - See FilesOperations.FileBinaryData.AttachedFile.
//  VersionRef - CatalogRef.FilesVersions - a version of the file by which the data is generated. If it is not specified,
//                                                 data is generated by the current version or file.
//  FileDataParameters - See FilesOperationsClientServer.FileDataParameters.
// 
// Returns:
//  Structure:
//   * Author - CatalogRef.Users
//   * CurrentVersionAuthor - CatalogRef.Users
//   * InWorkingDirectoryForRead - Boolean
//   * Version - CatalogRef.FilesVersions
//   * Owner - DefinedType.AttachedFilesOwner
//   * LockedDate - Date
//   * UniversalModificationDate - Date
//   * Encrypted	- Boolean
//   * Encoding - String
//   * CurrentVersionEncoding - String
//   * ForReading - Boolean
//   * URL - String
//   * CurrentVersionURL - String
//   * Description - String
//   * VersionNumber - Number
//   * FolderForSaveAs - String
//   * SignedWithDS - Boolean
//   * FullFileNameInWorkingDirectory - String
//   * FullVersionDescription - String
//   * DeletionMark - Boolean
//   * OwnerWorkingDirectory - String
//   * Size - Number
//   * Extension - String
//   * BeingEditedBy - CatalogRef.Users
//   * IsInternal - Boolean
//   * Ref - DefinedType.AttachedFile
//   * RefToBinaryFileData - String
//   * TextExtractionStatus - String
//   * CurrentVersion - CatalogRef.FilesVersions
//   * Volume - CatalogRef.FileStorageVolumes
//   * CurrentUserEditsFile - Boolean
//   * StoreVersions - Boolean
//
Function FileData(FileRef, VersionRef = Undefined, FileDataParameters = Undefined) Export

	If FileDataParameters = Undefined Then
		FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	EndIf;

	FormIdentifier = FileDataParameters.FormIdentifier;
	RaiseException1 = FileDataParameters.RaiseException1;
	GetBinaryDataRef = FileDataParameters.GetBinaryDataRef;

	HasRightsToObject = Common.ObjectAttributesValues(FileRef, "Ref", True);

	If HasRightsToObject = Undefined Then
		Return Undefined;
	EndIf;
	InfobaseUpdate.CheckObjectProcessed(FileRef);

	FileObject1 = FileRef.GetObject();

	FileData = New Structure;
	FileData.Insert("Ref", FileObject1.Ref);
	FileData.Insert("BeingEditedBy", FileObject1.BeingEditedBy);
	FileData.Insert("Owner", FileObject1.FileOwner);

	FileObjectMetadata = Metadata.FindByType(TypeOf(FileRef));

	If Common.HasObjectAttribute("CurrentVersion", FileObjectMetadata) And ValueIsFilled(
		FileRef.CurrentVersion) Then
		CurrentFileVersion = FileObject1.CurrentVersion;
	Else
		CurrentFileVersion = FileRef;
	EndIf;

	If VersionRef <> Undefined Then
		FileData.Insert("Version", VersionRef);
	Else
		FileData.Insert("Version", CurrentFileVersion);
	EndIf;

	FileData.Insert("CurrentVersion", CurrentFileVersion);
	FileData.Insert("StoreVersions", FileObject1.StoreVersions);
	FileData.Insert("DeletionMark", FileObject1.DeletionMark);
	FileData.Insert("Encrypted", FileObject1.Encrypted);
	FileData.Insert("SignedWithDS", FileObject1.SignedWithDS);
	FileData.Insert("LockedDate", FileObject1.LockedDate);

	If VersionRef = Undefined Then
		If GetBinaryDataRef Then
			RefToBinaryFileData = PutToTempStorage(FilesOperations.FileBinaryData(
				CurrentFileVersion, RaiseException1), FormIdentifier);
		Else
			RefToBinaryFileData = Undefined;
		EndIf;
		FileData.Insert("RefToBinaryFileData", RefToBinaryFileData);

		FileData.Insert("URL", GetURL(FileRef));
		FileData.Insert("CurrentVersionAuthor", FileRef.ChangedBy);
		FileData.Insert("Encoding", InformationRegisters.FilesEncoding.DefineFileEncoding(CurrentFileVersion,
			FileObject1.Extension));
	Else
		If GetBinaryDataRef Then
			RefToBinaryFileData = PutToTempStorage(FilesOperations.FileBinaryData(
				VersionRef, RaiseException1), FormIdentifier);
		Else
			RefToBinaryFileData = Undefined;
		EndIf;
		FileData.Insert("RefToBinaryFileData", RefToBinaryFileData);

		FileData.Insert("URL", GetURL(FileObject1.Ref));
		FileData.Insert("CurrentVersionAuthor", VersionRef.Author);
		FileData.Insert("Encoding", InformationRegisters.FilesEncoding.DefineFileEncoding(VersionRef,
			FileObject1.Extension));
	EndIf;

	If FileData.Encrypted Then

		If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
			EncryptionCertificatesArray = ModuleDigitalSignature.EncryptionCertificates(FileData.Ref);
		Else
			EncryptionCertificatesArray = Undefined;
		EndIf;

		FileData.Insert("EncryptionCertificatesArray", EncryptionCertificatesArray);

	EndIf;

	FileData.Insert("IsInternal", False);
	If CommonClientServer.HasAttributeOrObjectProperty(FileObject1, "IsInternal") Then
		FileData.IsInternal = FileObject1.IsInternal;
	EndIf;

	FilesOperationsInternal.FillAdditionalFileData(FileData, FileObject1, VersionRef);
	Return FileData;

EndFunction

Function GetFileData(Val AttachedFile, Val FormIdentifier = Undefined,
	Val GetBinaryDataRef = True, Val ForEditing = False) Export

	Return FilesOperations.FileData(AttachedFile, FormIdentifier, GetBinaryDataRef,
		ForEditing);
EndFunction

Function FileDataToPrint(Val AttachedFile, Val FormIdentifier = Undefined) Export

	FileData = GetFileData(AttachedFile, FormIdentifier);
	Extension = Lower(FileData.Extension);
	If Extension = "mxl" Then
		FileBinaryData = GetFromTempStorage(FileData.RefToBinaryFileData); // BinaryData
		TempFileName = GetTempFileName();
		FileBinaryData.Write(TempFileName);
		SpreadsheetDocument = New SpreadsheetDocument;
		SpreadsheetDocument.Read(TempFileName);
		SafeModeSet = SafeMode() <> False;

		If TypeOf(SafeModeSet) = Type("String") Then
			SafeModeSet = True;
		EndIf;

		If Not SafeModeSet Then
			DeleteFiles(TempFileName);
		EndIf;
		FileData.Insert("SpreadsheetDocument", SpreadsheetDocument);
	EndIf;

	Return FileData;

EndFunction

// Returns information records about the file and its version.
// 
// Parameters:
//  FileRef - CatalogRef.Files
//  VersionRef - CatalogRef.FilesVersions
//  FormIdentifier - UUID
//  OwnerWorkingDirectory - String
//  FilePreviousURL - String
// 
// Returns:
//   See FileData
//
Function FileDataToOpen(FileRef, VersionRef, FormIdentifier = Undefined,
	OwnerWorkingDirectory = Undefined, FilePreviousURL = Undefined) Export

	HasRightsToObject = Common.ObjectAttributesValues(FileRef, "Ref", True);
	If HasRightsToObject = Undefined Then
		Return Undefined;
	EndIf;

	If FilePreviousURL <> Undefined Then
		If Not IsBlankString(FilePreviousURL) And IsTempStorageURL(FilePreviousURL) Then
			DeleteFromTempStorage(FilePreviousURL);
		EndIf;
	EndIf;

	If Not ValueIsFilled(VersionRef) And Common.HasObjectAttribute("CurrentVersion",
		Metadata.FindByType(TypeOf(FileRef))) Then

		CurrentVersion = Common.ObjectAttributeValue(FileRef, "CurrentVersion");
		If ValueIsFilled(CurrentVersion) Then
			VersionRef = CurrentVersion;
		EndIf;
	EndIf;

	FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	FileDataParameters.FormIdentifier = FormIdentifier;

	FileData = FileData(FileRef, VersionRef, FileDataParameters);
	If OwnerWorkingDirectory = Undefined Then
		OwnerWorkingDirectory = FolderWorkingDirectory(FileData.Owner);
	EndIf;
	FileData.Insert("OwnerWorkingDirectory", OwnerWorkingDirectory);

	If FileData.OwnerWorkingDirectory <> "" Then
		FileName = CommonClientServer.GetNameWithExtension(
			FileData.FullVersionDescription, FileData.Extension);
		Common.ShortenFileName(FileName);
		FullFileNameInWorkingDirectory = OwnerWorkingDirectory + FileName;
		FileData.Insert("FullFileNameInWorkingDirectory", FullFileNameInWorkingDirectory);
	EndIf;

	VersionInfo = Common.ObjectAttributesValues(FileData.Version,
		"FileStorageType, Volume, PathToFile");

	If FileData.Version <> Undefined And VersionInfo.FileStorageType
		= Enums.FileStorageTypes.InVolumesOnHardDrive Then

		BinaryData = FilesOperationsInVolumesInternal.FileData(FileData.Version);
		FileData.CurrentVersionURL = PutToTempStorage(BinaryData, FormIdentifier);

	EndIf;

	FilePreviousURL = FileData.CurrentVersionURL;
	Return FileData;

EndFunction

Function ImageFieldUpdateData(FileRef, DataGetParameters) Export

	FileData = ?(ValueIsFilled(FileRef), GetFileData(FileRef, DataGetParameters),
		Undefined);

	UpdateData = New Structure;
	UpdateData.Insert("FileData", FileData);
	UpdateData.Insert("TextColor", StyleColors.NotSelectedPictureTextColor);
	UpdateData.Insert("FileCorrupted", False);

	If FileData <> Undefined And GetFromTempStorage(FileData.RefToBinaryFileData)
		= Undefined Then

		UpdateData.FileCorrupted = True;
		UpdateData.TextColor    = StyleColors.ErrorNoteText;

	EndIf;

	Return UpdateData;

EndFunction

Procedure DetermineAttachedFileForm(Source, FormType, Parameters, SelectedForm, AdditionalInformation,
	StandardProcessing) Export

	IsVersionForm = False;

	If Source <> Undefined Then
		IsVersionForm = Common.HasObjectAttribute("ParentVersion", Metadata.FindByType(TypeOf(
			Source)));
	EndIf;

	If FormType = "FolderForm" Then
		SelectedForm = "DataProcessor.FilesOperations.Form.FilesGroup";
		StandardProcessing = False;
	ElsIf FormType = "ObjectForm" Then

		If Not IsVersionForm Then
			SelectedForm = "DataProcessor.FilesOperations.Form.AttachedFile";
			StandardProcessing = False;
		EndIf;

	ElsIf FormType = "ListForm" Then

		If Not IsVersionForm Then
			SelectedForm = "DataProcessor.FilesOperations.Form.AttachedFiles";
			StandardProcessing = False;
		EndIf;

	EndIf;

EndProcedure

Function AttachedFilesCount(FilesOwner, ReturnFilesData = False,
	PlacementAttribute = Undefined) Export

	OwnerFiles = New Structure;
	OwnerFiles.Insert("FilesCount", 0);
	OwnerFiles.Insert("FileData", Undefined);

	StorageCatalogName = FilesOperationsInternal.FileStoringCatalogName(FilesOwner);
	If ValueIsFilled(StorageCatalogName) Then

		QueryText =
		"SELECT ALLOWED DISTINCT
		|	FilesStorageCatalog.Ref AS File
		|FROM
		|	&CatalogName AS FilesStorageCatalog
		|WHERE
		|	FilesStorageCatalog.FileOwner = &FileOwner
		|	AND NOT FilesStorageCatalog.DeletionMark
		|	AND &IsFolder = FALSE
		|	AND &IsInternal = FALSE";
		QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + StorageCatalogName);

		QueryText = StrReplace(QueryText, "&IsInternal", ?(FilesOperationsInternal.ThereArePropsInternal(
			StorageCatalogName), "FilesStorageCatalog.IsInternal", "FALSE"));

		QueryText = StrReplace(QueryText, "&IsFolder", ?(
			Metadata.Catalogs[StorageCatalogName].Hierarchical, "FilesStorageCatalog.IsFolder", "FALSE"));

		Query = New Query(QueryText);
		Query.SetParameter("FileOwner", FilesOwner);
		TableOfFiles = Query.Execute().Unload();
		FilesCount = TableOfFiles.Count();

		OwnerFiles.FilesCount = FilesCount;

		FileDataParameters = FilesOperationsClientServer.FileDataParameters();
		FileDataParameters.GetBinaryDataRef = False;
		FileDataParameters.RaiseException1 = False;

		If ReturnFilesData And FilesCount > 0 Then
			If PlacementAttribute = Undefined Or Not ValueIsFilled(FilesOwner[PlacementAttribute]) Then
				OwnerFiles.FileData = FileData(TableOfFiles[0].File,, FileDataParameters);
			Else
				OwnerFiles.FileData = FileData(FilesOwner[PlacementAttribute],, FileDataParameters);
			EndIf;
		EndIf;

	EndIf;

	Return ?(ReturnFilesData, OwnerFiles, OwnerFiles.FilesCount);

EndFunction

Function IsFilesOperationsItem(DataElement) Export
	Return FilesOperationsInternal.IsFilesOperationsItem(DataElement);
EndFunction

Function NewSpreadsheetAtServer(PageCount) Export
	SpreadsheetDocument =New SpreadsheetDocument;
	EmptyArea = SpreadsheetDocument.GetArea(1, 1, 1, 1);
	For ObjectIndex = 1 To PageCount Do
		SpreadsheetDocument.Put(EmptyArea);
		SpreadsheetDocument.PutHorizontalPageBreak();
	EndDo;
	Return SpreadsheetDocument;
EndFunction

Procedure FillScanSettings(ScanningParameters, ClientID) Export

	UserScanSettings = FilesOperations.GetUserScanSettings(ClientID);
	FillPropertyValues(ScanningParameters, UserScanSettings);

EndProcedure

Function GetUserScanSettings(ClientID) Export
	Return FilesOperations.GetUserScanSettings(ClientID);
EndFunction

Procedure SaveUserScanSettings(ClientScanSettings, ClientID) Export
	FilesOperations.SaveUserScanSettings(ClientScanSettings, ClientID);
EndProcedure

Function RunFilesRecovery(Volume, FormUniqueID) Export
	ExecutionParameters = TimeConsumingOperations.FunctionExecutionParameters(FormUniqueID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = '""File recovery""';");
	ExecutionParameters.BackgroundJobKey = "FileRecovery";
	
	Return TimeConsumingOperations.ExecuteFunction(ExecutionParameters, "Reports.VolumeIntegrityCheck.RecoverFiles", Volume);
EndFunction

#EndRegion

#Region Private

// Saves the path to the user's working directory to the settings.
//
// Parameters:
//  DirectoryName - String - a directory name.
//  User - CatalogRef.Users - the user for whom the working directory will be set.
//               - Undefined - sets a working directory for the current user.
//
Procedure SetUserWorkingDirectory(DirectoryName, User = Undefined) Export

	UserName = Undefined;

	SetPrivilegedMode(True);
	If User <> Undefined Then
		IBUserID = Common.ObjectAttributeValue(User,
			"IBUserID");
		IBUserProperies = Users.IBUserProperies(IBUserID);
		UserName = CommonClientServer.StructureProperty(IBUserProperies, "Name");
	EndIf;

	CommonServerCall.CommonSettingsStorageSave(
		"LocalFileCache", "PathToLocalFileCache", DirectoryName,, UserName, True);

EndProcedure

Function IsDirectoryFiles(FilesOwner) Export

	Return FilesOperationsInternal.FileStoringCatalogName(FilesOwner) = "Files";

EndFunction

Function FileStoringCatalogName(FilesOwner) Export

	Return FilesOperationsInternal.FileStoringCatalogName(FilesOwner);

EndFunction

// Creates a file in the infobase.
//
// Parameters:
//   Owner       - CatalogRef.FilesFolders
//                  - AnyRef - will be set to the FilesOwner attribute
//                    of the created file.
//   FileInfo1 - See FilesOperationsClientServer.FileInfo1
//
// Returns:
//    CatalogRef.Files - created file.
//
Function CreateFile(Val Owner, Val FileInfo1)

	FilesCatalogManager = Catalogs[FileInfo1.FilesStorageCatalogName]; // CatalogManager

	File = FilesCatalogManager.CreateItem(); // DefinedType.AttachedFileObject
	File.FileOwner = Owner;
	File.Description = FileInfo1.BaseName;
	File.Author = ?(FileInfo1.Author <> Undefined, FileInfo1.Author,
		Users.AuthorizedUser());
	File.ChangedBy = File.Author;
	File.CreationDate = CurrentSessionDate();
	File.LongDesc = FileInfo1.Comment;
	File.PictureIndex = FilesOperationsInternalClientServer.IndexOfFileIcon(Undefined);
	File.StoreVersions = FileInfo1.StoreVersions;
	File.Extension = FileInfo1.ExtensionWithoutPoint;
	File.Size = FileInfo1.Size;
	File.UniversalModificationDate = FileInfo1.ModificationTimeUniversal;
	File.Encrypted = FileInfo1.Encrypted;

	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	If Metadata.Catalogs[FileInfo1.FilesStorageCatalogName].FullTextSearch
		= FullTextSearchUsing Then

		If TypeOf(FileInfo1.TempTextStorageAddress) = Type("ValueStorage") Then
			// When creating a File from a template, the value storage is copied directly.
			File.TextStorage = FileInfo1.TempTextStorageAddress;
		ElsIf Not IsBlankString(FileInfo1.TempTextStorageAddress) Then
			TextExtractionResult = FilesOperationsInternal.ExtractText1(
				FileInfo1.TempTextStorageAddress);
			File.TextStorage = TextExtractionResult.TextStorage;
			File.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
		EndIf;

	Else
		File.TextStorage = New ValueStorage("");
		File.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	EndIf;

	File.Fill(Undefined);
	File.Write();
	Return File.Ref;

EndFunction

// Updates or creates a File version and returns a reference to the updated version (or False if the file is
// not modified binary).
//
// Parameters:
//   FileRef     - CatalogRef.Files        - a file, for which a new version is created.
//   FileInfo1 - See FilesOperationsClientServer.FileInfo1
//   VersionRef   - CatalogRef.FilesVersions - a file version that needs to be updated.
//   FormUniqueID                   - UUID - the UUID of 
//                                                    the form that provides operation context.
//
// Returns:
//   CatalogRef.FilesVersions - created or changed version; Undefined if the file has not been binarily changed.
//
Function RefreshFileObject(FileRef, FileInfo1, VersionRef = Undefined,
	FormUniqueID = Undefined, User = Undefined)

	HasSaveRight = AccessRight("SaveUserData", Metadata);
	HasRightsToObject = Common.ObjectAttributesValues(FileRef, "Ref", True);
	If HasRightsToObject = Undefined Then
		Return Undefined;
	EndIf;

	SetPrivilegedMode(True);

	ModificationTimeUniversal = FileInfo1.ModificationTimeUniversal;
	If Not ValueIsFilled(ModificationTimeUniversal) Or ModificationTimeUniversal > CurrentUniversalDate() Then
		ModificationTimeUniversal = CurrentUniversalDate();
	EndIf;

	Modified = FileInfo1.Modified;
	If Not ValueIsFilled(Modified) Or ToUniversalTime(Modified) > ModificationTimeUniversal Then
		Modified = CurrentSessionDate();
	EndIf;

	FilesOperationsInternal.CheckExtentionOfFileToDownload(FileInfo1.ExtensionWithoutPoint);

	BinaryData = Undefined;
	CatalogMetadata = Metadata.FindByType(TypeOf(FileRef));
	CatalogSupportsPossibitityToStoreVersions = Common.HasObjectAttribute("CurrentVersion",
		CatalogMetadata);

	VersionRefToCompareSize = VersionRef;
	If VersionRef <> Undefined Then
		VersionRefToCompareSize = VersionRef;
	ElsIf CatalogSupportsPossibitityToStoreVersions And ValueIsFilled(FileRef.CurrentVersion) Then
		VersionRefToCompareSize = FileRef.CurrentVersion;
	Else
		VersionRefToCompareSize = FileRef;
	EndIf;

	PreVersionEncoding = InformationRegisters.FilesEncoding.FileVersionEncoding(VersionRefToCompareSize);

	AttributesStructure1 = Common.ObjectAttributesValues(VersionRefToCompareSize,
		"Size, FileStorageType");

	FileStorage1 = Undefined;
	If FileInfo1.Size = AttributesStructure1.Size Then

		If AttributesStructure1.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			PreviousVersionBinaryData = FilesOperationsInVolumesInternal.FileData(VersionRefToCompareSize,
				False);
		Else
			FileStorage1 = FilesOperations.FileFromInfobaseStorage(VersionRefToCompareSize);
			PreviousVersionBinaryData = FileStorage1.Get();
		EndIf;

		BinaryData = FilesOperationsInternal.BinaryDataFromFileInformation(FileInfo1);
		If PreviousVersionBinaryData = BinaryData Then
			Return Undefined; // If the file is not changed binary, returning False.
		EndIf;

	EndIf;

	RefToVersion = ?(VersionRef = Undefined, FileRef, VersionRef);

	Block = New DataLock;
	LockItem = Block.Add(RefToVersion.Metadata().FullName());
	LockItem.SetValue("Ref", RefToVersion);

	Extension = CommonClientServer.ExtensionWithoutPoint(FileInfo1.ExtensionWithoutPoint);
	FileStorageType = FilesOperationsInternal.FileStorageType(FileInfo1.Size, Extension);
	FileManager = FilesOperationsInternal.FileManagerByType(FileStorageType);
	Context = FilesOperationsInternal.FileUpdateContext(RefToVersion,
		FileInfo1.TempFileStorageAddress,, FileStorageType);
	FileManager.BeforeUpdatingTheFileData(Context);

	BeginTransaction();
	Try

		Block.Lock();

		Version = RefToVersion.GetObject();
		LockDataForEdit(RefToVersion,, FormUniqueID);

		Version.FileStorageType = FileStorageType;
		If Version.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			VersionProperties = FilesOperationsInVolumesInternal.FilePropertiesInVolume();
			FillPropertyValues(VersionProperties, Version);
		EndIf;

		If User = Undefined Then
			Version.ChangedBy = Users.AuthorizedUser();
		Else
			Version.ChangedBy = User;
		EndIf;
		Version.UniversalModificationDate = ModificationTimeUniversal;
		Version.Size                       = FileInfo1.Size;
		Version.Description                 = FileInfo1.BaseName;
		Version.LongDesc                     = FileInfo1.Comment;
		Version.Extension                   = Extension;

		If BinaryData = Undefined Then
			BinaryData = FilesOperationsInternal.BinaryDataFromFileInformation(FileInfo1);
		EndIf;

		If FileStorageType = Enums.FileStorageTypes.InInfobase Then

			FileStorage1 = New ValueStorage(BinaryData);

			If Version.Size = 0 Then
				FileBinaryData = FileStorage1.Get(); // BinaryData
				Version.Size = FileBinaryData.Size();

				FilesOperationsInternal.CheckFileSizeForImport(Version);
			EndIf;
			
			// Clear fields.
			Version.PathToFile = "";
			Version.Volume = Catalogs.FileStorageVolumes.EmptyRef();

		Else // store in a volume

			If Version.Size = 0 Then
				Version.Size = BinaryData.Size();
				FilesOperationsInternal.CheckFileSizeForImport(Version);
			EndIf;
			Version.FileStorage = New ValueStorage(Undefined);
			FilesOperationsInVolumesInternal.FillInTheFileDetails(Version, BinaryData);
		EndIf;

		FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
		If CatalogMetadata.FullTextSearch = FullTextSearchUsing Then

			If FileInfo1.TempTextStorageAddress <> Undefined Then
				If FilesOperationsInternal.ExtractTextFilesOnServer() Then
					Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
				Else
					TextExtractionResult = FilesOperationsInternal.ExtractText1(
						FileInfo1.TempTextStorageAddress);
					Version.TextStorage = TextExtractionResult.TextStorage;
					Version.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
				EndIf;
			Else
				Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
			EndIf;

			If FileInfo1.NewTextExtractionStatus <> Undefined Then
				Version.TextExtractionStatus = FileInfo1.NewTextExtractionStatus;
			EndIf;

		Else
			Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		EndIf;

		If Version.Size = 0 Then
			If FileStorageType = Enums.FileStorageTypes.InInfobase Then
				FileBinaryData = FileStorage1.Get(); // BinaryData
				Version.Size = FileBinaryData.Size();
			EndIf;
		EndIf;

		Version.Fill(Undefined);

		FileManager.BeforeWritingFileData(Context, Version);
		Version.Write();
		FileManager.WhenUpdatingFileData(Context, Version.Ref);

		InformationRegisters.FilesEncoding.WriteFileVersionEncoding(Version.Ref, PreVersionEncoding);
		If FileInfo1.StoreVersions Then
			FilesOperationsInternal.UpdateVersionInFile(FileRef, Version.Ref,
				FileInfo1.TempTextStorageAddress, FormUniqueID);
		Else
			FilesOperationsInternal.UpdateTextInFile(FileRef, FileInfo1.TempTextStorageAddress,
				FormUniqueID);
		EndIf;

		UnlockDataForEdit(RefToVersion, FormUniqueID);
		CommitTransaction();

	Except
		RollbackTransaction();
		UnlockDataForEdit(RefToVersion, FormUniqueID);
		FileManager.AfterUpdatingTheFileData(Context, False);
		Raise;
	EndTry;

	FileManager.AfterUpdatingTheFileData(Context, True);

	If HasSaveRight Then
		FileURL1 = GetURL(FileRef);
		UserWorkHistory.Add(FileURL1);
	EndIf;

	Return Version.Ref;

EndFunction

// Updates or creates a file version and unlocks it. 
// 
// Throws exceptions.
//
// Parameters:
//   FileData                  - Structure - a structure with file data.
//   FileInfo1               - See FilesOperationsClientServer.FileInfo1
//   DontChangeRecordInWorkingDirectory - Boolean  - do not change record the FilesInWorkingDirectory information register.
//   FullFilePath             - String    - specified if DontChangeRecordInWorkingDirectory = False.
//   UserWorkingDirectory   - String    - specified if DontChangeRecordInWorkingDirectory = False.
//   FormUniqueID - UUID - a form UUID.
//
// Returns:
//   Boolean - True if the version is created (and the file has been binarily changed).
//
Function SaveChangesAndUnlockFile(FileData, FileInfo1, DontChangeRecordInWorkingDirectory,
	FullFilePath, UserWorkingDirectory, FormUniqueID = Undefined) Export

	FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	FileDataParameters.GetBinaryDataRef = False;

	FileDataCurrent = FileData(FileData.Ref,, FileDataParameters);
	If Not FileDataCurrent.CurrentUserEditsFile And Not FileToSynchronizeByCloudService(
		FileData.Ref) Then
		Raise NStr("en = 'The file is not locked by the current user.';");
	EndIf;

	PreviousVersion = FileData.CurrentVersion;
	FileInfo1.Encrypted = FileData.Encrypted;
	FileInfo1.Encoding  = FileData.Encoding;

	If TypeOf(FileData.Ref) = Type("CatalogRef.Files") Then
		NewVersion = FilesOperationsInternal.UpdateFileVersion(FileData.Ref, FileInfo1,,
			FormUniqueID);
	Else
		NewVersion = RefreshFileObject(FileData.Ref, FileInfo1,, FormUniqueID);
	EndIf;

	UnlockFile(FileData, FormUniqueID);

	If NewVersion = Undefined Then
		Return False;
	EndIf;

	FileData.CurrentVersion = NewVersion;

	If Not Common.IsWebClient() And Not DontChangeRecordInWorkingDirectory Then
		DeleteVersionAndPutFileInformationIntoRegister(PreviousVersion, NewVersion, FullFilePath,
			UserWorkingDirectory, FileData.OwnerWorkingDirectory <> "");
	EndIf;

	Return True;

EndFunction

// Receives file data and then updates or creates a File version and unlocks it.
// It is necessary for cases, when the FileData is missing on the client (for reasons of saving client-server calls).
//
// Parameters:
//   FileRef       - CatalogRef.Files - a file where a version is updated.
//   FileInfo1   - See FilesOperationsClientServer.FileInfo1
//   FullFilePath             - String
//   UserWorkingDirectory   - String
//   FormUniqueID - UUID - a form UUID.
//
// Returns:
//   Structure:
//     * Success     - Boolean    - True if the version is created (and file is binary changed).
//     * FileData - Structure - a structure with file data.
//
Function SaveChangesAndUnlockFileByRef(FileRef, FileInfo1, FullFilePath,
	UserWorkingDirectory, FormUniqueID = Undefined) Export

	FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	FileDataParameters.GetBinaryDataRef = False;

	FileData = FileData(FileRef,, FileDataParameters);
	VersionCreated = SaveChangesAndUnlockFile(FileData, FileInfo1, False, FullFilePath,
		UserWorkingDirectory, FormUniqueID);
	Return New Structure("Success,FileData", VersionCreated, FileData);

EndFunction

// It is designed to save file changes without unlocking it.
//
// Parameters:
//   FileRef                  - DefinedType.AttachedFile - Attachment.
//   FileInfo1               - See FilesOperationsClientServer.FileInfo1
//   DontChangeRecordInWorkingDirectory - Boolean  - do not change record the FilesInWorkingDirectory information register.
//   RelativeFilePath      - String    - a relative path without a working directory path, for example,
//                                              "A1/Order.doc"; it is required if DontChangeRecordInWorkingDirectory =
//                                              False.
//   FullFilePath             - String    - a path on the client in the working directory. It is specified if
//                                              DontChangeRecordInWorkingDirectory = False.
//   InOwnerWorkingDirectory    - Boolean    - the file is stored in the working directory of its owner.
//   FormUniqueID - UUID - a form UUID.
//
// Returns:
//   Boolean  - True if the version is created (and the file has been binarily changed).
//
Function SaveFileChanges(FileRef, FileInfo1, DontChangeRecordInWorkingDirectory, RelativeFilePath,
	FullFilePath, InOwnerWorkingDirectory, FormUniqueID = Undefined) Export

	FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	FileDataParameters.GetBinaryDataRef = False;
	FileDataCurrent = FileData(FileRef,, FileDataParameters);
	If Not FileDataCurrent.CurrentUserEditsFile And Not FileToSynchronizeByCloudService(FileRef) Then
		Raise NStr("en = 'The file is not locked by the current user.';");
	EndIf;

	OldVersion = ?(FileInfo1.StoreVersions, FileRef.CurrentVersion, FileRef);
	If FileInfo1.Encrypted = Undefined Then
		FileInfo1.Encrypted = FileDataCurrent.Encrypted;
	EndIf;

	If FileInfo1.Encoding = Undefined Then
		FileInfo1.Encoding = FilesOperationsInternalClientServer.DetermineBinaryDataEncoding(
			FileInfo1.TempFileStorageAddress, FileInfo1.ExtensionWithoutPoint);
	EndIf;

	If TypeOf(FileRef.Ref) = Type("CatalogRef.Files") Then
		NewVersion = FilesOperationsInternal.UpdateFileVersion(FileRef.Ref, FileInfo1,,
			FormUniqueID, FileInfo1.NewVersionAuthor);
	Else
		NewVersion = RefreshFileObject(FileRef.Ref, FileInfo1,, FormUniqueID);
	EndIf;

	If NewVersion = Undefined Then
		Return False;
	EndIf;

	If FileInfo1.StoreVersions Then

		If Not Common.IsWebClient() And Not DontChangeRecordInWorkingDirectory Then
			DeleteFromRegister(OldVersion);
			WriteFullFileNameToRegister(NewVersion, RelativeFilePath, False, InOwnerWorkingDirectory);
		EndIf;

	EndIf;

	Return True;

EndFunction

// Creates a new file similarly to the specified one and returns a reference to it.
// 
// Parameters:
//  SourceFile  - CatalogRef.Files - an existing file.
//  NewFileOwner - DefinedType.FilesOwner - file owner.
//
// Returns:
//   CatalogRef.Files - new file.
//
Function CopyAttachedFile(SourceFile, NewFileOwner)

	If SourceFile = Undefined Or SourceFile.IsEmpty() Then
		Return Undefined;
	EndIf;

	ObjectManager = Common.ObjectManagerByRef(SourceFile);
	NewFile = SourceFile.Copy();
	FileCopyRef = ObjectManager.GetRef();
	NewFile.SetNewObjectRef(FileCopyRef);
	NewFile.FileOwner = NewFileOwner;
	NewFile.BeingEditedBy = Catalogs.Users.EmptyRef();

	NewFile.TextStorage = New ValueStorage(SourceFile.TextStorage.Get());
	NewFile.FileStorage  = New ValueStorage(SourceFile.FileStorage.Get());

	BinaryData = FilesOperations.FileBinaryData(SourceFile);
	BinaryDataInValueStorage = New ValueStorage(BinaryData);

	FileStorageType = FilesOperationsInternal.FileStorageType(NewFile.Size, NewFile.Extension);
	If FileStorageType = Enums.FileStorageTypes.InInfobase Then
		NewFile.FileStorageType = FilesOperationsInternal.FilesStorageTyoe();
		SetPrivilegedMode(True);
		InformationRegisters.FileRepository.WriteBinaryData(FileCopyRef, BinaryData);
		SetPrivilegedMode(False);
		SetPrivilegedMode(True);
		InformationRegisters.FileRepository.WriteBinaryData(FileCopyRef, BinaryData);
		SetPrivilegedMode(False);
	Else

		NewFile.Volume = Undefined;
		NewFile.PathToFile = Undefined;
		NewFile.FileStorageType = Undefined;

		FilesOperationsInVolumesInternal.AppendFile(NewFile, BinaryData);

	EndIf;

	NewFile.Write();

	If NewFile.StoreVersions Then

		CurrentVersionAttributes = Common.ObjectAttributesValues(NewFile.CurrentVersion,
			"Size,Extension,TextStorage");

		FileInfo1 = FilesOperationsClientServer.FileInfo1("FileWithVersion");
		FileInfo1.BaseName = NewFile.Description;
		FileInfo1.Size = CurrentVersionAttributes.Size;
		FileInfo1.ExtensionWithoutPoint = CurrentVersionAttributes.Extension;
		FileInfo1.TempFileStorageAddress = BinaryDataInValueStorage;
		FileInfo1.TempTextStorageAddress = CurrentVersionAttributes.TextStorage;
		FileInfo1.RefToVersionSource = NewFile.CurrentVersion;
		FileInfo1.Encrypted = NewFile.Encrypted;
		Version = FilesOperationsInternal.CreateVersion(NewFile.Ref, FileInfo1);
		FilesOperationsInternal.UpdateVersionInFile(NewFile.Ref, Version, CurrentVersionAttributes.TextStorage);

	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then

		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		DigitalSignatureAvailable = ModuleDigitalSignatureInternal.DigitalSignatureAvailable(TypeOf(SourceFile));
		If DigitalSignatureAvailable Then

			ModuleDigitalSignature = Common.CommonModule("DigitalSignature");

			If SourceFile.SignedWithDS Then

				NewFile.Read();
				NewFile.SignedWithDS = True;
				NewFile.Write();

				DigitalSignaturesOfInitialFile = ModuleDigitalSignature.SetSignatures(SourceFile);
				For Each DS In DigitalSignaturesOfInitialFile Do
					RecordManager = InformationRegisters["DigitalSignatures"].CreateRecordManager(); // InformationRegisterRecordManager.DigitalSignatures
					RecordManager.SignedObject = NewFile;
					FillPropertyValues(RecordManager, DS);
					RecordManager.Write(True);
				EndDo;

			EndIf;

			If SourceFile.Encrypted Then

				NewFile.Read();
				NewFile.Encrypted = True;

				DigitalSignaturesOfInitialFile = ModuleDigitalSignature.EncryptionCertificates(SourceFile);
				For Each Certificate In DigitalSignaturesOfInitialFile Do
					RecordManager = InformationRegisters["EncryptionCertificates"].CreateRecordManager(); // InformationRegisterRecordManager.EncryptionCertificates
					RecordManager.EncryptedObject = NewFile;
					FillPropertyValues(RecordManager, Certificate);
					RecordManager.Write(True);
				EndDo;
				// To write a previously signed object.
				NewFile.AdditionalProperties.Insert("WriteSignedObject", True);
				NewFile.Write();

			EndIf;

		EndIf;

	EndIf;

	FilesOperationsOverridable.FillFileAtributesFromSourceFile(NewFile, SourceFile);

	Return NewFile;

EndFunction

// Moves the File to another folder.
//
// Parameters:
//  FileData - See FileData
//  Folder - CatalogRef.FilesFolders - a reference to the folder, to which you need to move the file.
//
Procedure TransferFile(FileData, Folder)

	BeginTransaction();
	Try
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(
			FileData.Ref)).FullName());
		DataLockItem.SetValue("Ref", FileData.Ref);
		DataLock.Lock();
		FileObject1 = FileData.Ref.GetObject();
		FileObject1.Lock();
		FileObject1.FileOwner = Folder;
		FileObject1.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure

// Moves Files to another folder.
//
// Parameters:
//   ObjectsRef - Array - an array of file references.
//   Folder - CatalogRef.FilesFolders - a reference to the folder, to which you need to move the files.
//
// Returns:
//    Array of See FilesOperationsInternalServerCall.FileData
//
Function MoveFiles(ObjectsRef, Folder) Export

	FilesData = New Array;

	FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	FileDataParameters.GetBinaryDataRef = False;

	For Each FileRef In ObjectsRef Do
		TransferFile(FileRef, Folder);
		FileData = FileData(FileRef,, FileDataParameters);
		FilesData.Add(FileData);
	EndDo;

	Return FilesData;

EndFunction

// Gets file data and performs a checkout. To reduce the number of client/server 
// calls, GetFileData and LockFile are combined into a single function.
// Parameters:
//  FileRef  - CatalogRef.Files - file.
//  FileData  - Structure - a structure with file data.
//  ErrorString - String - where the reason of an error is returned (for example, "File is locked by another
//                 user").
//  UUID - form UUID.
//
// Returns:
//   Boolean  - shows whether the operation is performed successfully.
//
Function GetFileDataAndLockFile(FileRef, FileData, ErrorString, UUID = Undefined) Export

	FileData = FileData(FileRef);

	ErrorString = "";
	If Not FilesOperationsClientServer.WhetherPossibleLockFile(FileData, ErrorString) Then
		Return False;
	EndIf;

	If Not ValueIsFilled(FileData.BeingEditedBy) Then

		FileLockParameters = FilesOperationsInternalClientServer.FileLockParameters();
		FileLockParameters.UUID = UUID;

		ErrorString = "";
		If Not LockFile(FileData, ErrorString, FileLockParameters) Then
			Return False;
		EndIf;
	EndIf;

	Return True;

EndFunction

// Receives FileData for files and places it into FileDataArray.
//
// Parameters:
//  FilesArray - Array of DefinedType.AttachedFile
//  FileDataArray - Array - structures with file data.
//
Procedure GetDataForFilesArray(Val FilesArray, FileDataArray) Export

	For Each File In FilesArray Do
		FileData = FileData(File);
		FileDataArray.Add(FileData);
	EndDo;

EndProcedure

// Locks the file and returns the file data for further editing.
// 
// Parameters:
//  FileRef  - CatalogRef.Files
//  UUID - form UUID.
//  OwnerWorkingDirectory - String - a working directory of the file owner.
//  VersionRef - CatalogRef.FilesVersions
//
// Returns:
//   Structure:
//    * DataReceived - Boolean  - True if the operation is successful.
//    * FileData    - Structure
//    * MessageText - String - Contains the error reason. For example, "The file is locked by another user".
//    * FileIsAlreadyEditedByCurrentUser - Boolean - True if the file has already been locked for editing.
///
Function BorrowFileToEdit(FileRef, UUID = Undefined,
	OwnerWorkingDirectory = Undefined, VersionRef = Undefined) Export

	Result = New Structure;
	Result.Insert("DataReceived", False);
	Result.Insert("FileData", Undefined);
	Result.Insert("MessageText", "");
	Result.Insert("FileIsAlreadyEditedByCurrentUser", False);

	Result.FileData = FileDataToOpen(FileRef, VersionRef, UUID,
		OwnerWorkingDirectory);
	If Not FilesOperationsClientServer.WhetherPossibleLockFile(Result.FileData, Result.MessageText) Then
		Return Result;
	EndIf;

	FileLockParameters = FilesOperationsInternalClientServer.FileLockParameters();
	FileLockParameters.UUID = UUID;

	Result.FileIsAlreadyEditedByCurrentUser = Result.FileData.CurrentUserEditsFile;
	If Not ValueIsFilled(Result.FileData.BeingEditedBy) And Not LockFile(Result.FileData,
		Result.MessageText, FileLockParameters) Then
		Return Result;
	EndIf;

	Result.DataReceived = True;
	Return Result;

EndFunction

// Executes PutInTempStorage (if the file is stored in a volume) and returns a required reference.
//
// Parameters:
//   VersionRef - file version.
//   FormIdentifier - form UUID.
//
// Returns:
//   String  - URL in the temporary storage.
//
Function GetURLToOpen(VersionRef, FormIdentifier = Undefined) Export

	HasRightsToObject = Common.ObjectAttributesValues(VersionRef, "Ref", True);

	If HasRightsToObject = Undefined Then
		Return Undefined;
	EndIf;

	Return PutToTempStorage(FilesOperations.FileBinaryData(VersionRef));

EndFunction

// Executes FileData and calculates OwnerWorkingDirectory.
//
// Parameters:
//  FileOrVersionRef     - CatalogRef.Files
//                          - CatalogRef.FilesVersions - file or file version.
//  OwnerWorkingDirectory - String - the user working directory is returned in it.
//
// Returns:
//   Structure - structure with file data:
//     * Ref - DefinedType.AttachedFile
//
Function FileDataAndWorkingDirectory(FileOrVersionRef, OwnerWorkingDirectory = Undefined) Export

	FileRef = Undefined;
	VersionRef = Undefined;
	AbilityToStoreVersions = False;
	If TypeOf(FileOrVersionRef) = Type("CatalogRef.FilesVersions") Then
		VersionRef = FileOrVersionRef;
	Else
		FileRef = FileOrVersionRef;
		AbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion",
			FileOrVersionRef.Metadata());
	EndIf;

	CurrentVersion = ?(Not AbilityToStoreVersions, Undefined, Common.ObjectAttributeValue(FileRef,
		"CurrentVersion"));

	FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	FileDataParameters.GetBinaryDataRef = False;

	FileData = FileData(FileOrVersionRef,, FileDataParameters);
	If OwnerWorkingDirectory = Undefined Then
		OwnerWorkingDirectory = FolderWorkingDirectory(FileData.Owner);
	EndIf;

	FileData.Insert("OwnerWorkingDirectory", OwnerWorkingDirectory);
	If OwnerWorkingDirectory <> "" Then

		FullFileNameInWorkingDirectory = "";
		DirectoryName = ""; // Path to the local cache is not used here.
		InWorkingDirectoryForRead = True; // Path to the local cache is not used here. 
		InOwnerWorkingDirectory = True;

		If VersionRef <> Undefined Then
			FullFileNameInWorkingDirectory = FullFileNameInWorkingDirectory(VersionRef, DirectoryName,
				InWorkingDirectoryForRead, InOwnerWorkingDirectory);
		ElsIf AbilityToStoreVersions And CurrentVersion <> Undefined Then
			FullFileNameInWorkingDirectory = FullFileNameInWorkingDirectory(CurrentVersion, DirectoryName,
				InWorkingDirectoryForRead, InOwnerWorkingDirectory);
		Else
			FullFileNameInWorkingDirectory = FullFileNameInWorkingDirectory(FileRef, DirectoryName,
				InWorkingDirectoryForRead, InOwnerWorkingDirectory);
		EndIf;

		FileData.Insert("FullFileNameInWorkingDirectory", FullFileNameInWorkingDirectory);
	EndIf;

	Return FileData;
EndFunction

// Makes GetFileData and calculates the number of file versions.
// Parameters:
//  FileRef  - CatalogRef.Files - file.
//
// Returns:
//   Structure - structure with file data.
//
Function GetFileDataAndVersionsCount(FileRef) Export

	FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	FileDataParameters.GetBinaryDataRef = False;

	FileData = FileData(FileRef,, FileDataParameters);
	VersionsCount = GetVersionsCount(FileRef);
	FileData.Insert("VersionsCount", VersionsCount);

	Return FileData;

EndFunction

// Unlocking File with receiving data.
// Parameters:
//  FileRef  - CatalogRef.Files - file.
//  FileData  - Structure - with the file data.
//  UUID - form UUID.
//
Procedure GetFileDataAndUnlockFile(FileRef, FileData, UUID = Undefined) Export

	FileData = FileData(FileRef);
	UnlockFile(FileData, UUID);

EndProcedure

// To save file changes without unlocking it.
//
// Parameters:
//   FileRef                   - Structure - a structure with file data.
//   FileInfo1               - See FilesOperationsClientServer.FileInfo1
//   RelativeFilePath      - String    - a relative path without a working directory path, for example,
//                                              "A1/Order.doc"; it is required if DontChangeRecordInWorkingDirectory =
//                                              False.
//   FullFilePath             - String    - a path on the client in the working directory. It is specified if
//                                              DontChangeRecordInWorkingDirectory = False.
//   InOwnerWorkingDirectory    - Boolean    - the file is stored in the working directory of its owner.
//   FormUniqueID - UUID - a form UUID.
//
// Returns:
//   Structure:
//     * Success     - Boolean    - True if the version is created (and file is binary changed).
//     * FileData - Structure - a structure with file data.
//
Function GetFileDataAndSaveFileChanges(FileRef, FileInfo1, RelativeFilePath,
	FullFilePath, InOwnerWorkingDirectory, FormUniqueID = Undefined) Export

	FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	FileDataParameters.GetBinaryDataRef = False;

	FileData = FileData(FileRef,, FileDataParameters);
	If Not FileData.CurrentUserEditsFile Then
		Raise NStr("en = 'The file is not locked by the current user.';");
	EndIf;

	VersionCreated = SaveFileChanges(FileRef, FileInfo1, False, RelativeFilePath,
		FullFilePath, InOwnerWorkingDirectory, FormUniqueID);
	Return New Structure("Success,FileData", VersionCreated, FileData);

EndFunction

// Receives the synthetic working directory of the folder on the computer (it can be obtained from the parent folder).
//
// Parameters:
//  FolderRef  - CatalogRef.FilesFolders - file owner.
//
// Returns:
//   String  - working directory.
//
Function FolderWorkingDirectory(FolderRef) Export

	If Not IsDirectoryFiles(FolderRef) Then
		Return "";
	EndIf;

	SetPrivilegedMode(True);

	WorkingDirectory = "";
	
	// Prepare a filter structure by dimensions.

	FilterStructure1 = New Structure;
	FilterStructure1.Insert("Folder", FolderRef);
	FilterStructure1.Insert("User", Users.AuthorizedUser());
	
	// Receive structure with the data of record resources.
	ResourcesStructure = InformationRegisters.FileWorkingDirectories.Get(FilterStructure1);
	
	// Getting a path from the register
	WorkingDirectory = ResourcesStructure.Path;

	If Not IsBlankString(WorkingDirectory) Then
		// Add a slash at the end (unless it is already there).
		WorkingDirectory = CommonClientServer.AddLastPathSeparator(WorkingDirectory);
	EndIf;

	Return WorkingDirectory;

EndFunction

// Returns:
//   Structure:
//     * File                         - DefinedType.AttachedFile
//     * Path                         - String
//     * Size                       - Number
//     * PutFileInWorkingDirectoryDate - Date
//     * ForReading                     - Boolean
//
Function FileInWorkingDirectory()

	Return New Structure("File, Path, Size, PutFileInWorkingDirectoryDate, ForReading");

EndFunction

// Saves a folder working directory to the information register and
// replaces paths in the FilesInWorkingDirectory information register.
//
// Parameters:
//  FolderRef  - CatalogRef.FilesFolders - file owner.
//  FolderWorkingDirectory - String - a folder working directory.
//  DirectoryNamePreviousValue - String - a previous value of the working directory.
//
Procedure SaveFolderWorkingDirectoryAndReplacePathsInRegister(FolderRef, FolderWorkingDirectory,
	DirectoryNamePreviousValue) Export

	FilesOperationsInternal.SaveFolderWorkingDirectory(FolderRef, FolderWorkingDirectory);

	Query = New Query;
	Query.Text =
	"SELECT
	|	FilesInWorkingDirectory.File AS File,
	|	FilesInWorkingDirectory.Path AS Path,
	|	FilesInWorkingDirectory.Size AS Size,
	|	FilesInWorkingDirectory.PutFileInWorkingDirectoryDate AS PutFileInWorkingDirectoryDate,
	|	FilesInWorkingDirectory.ForReading AS ForReading
	|FROM
	|	InformationRegister.FilesInWorkingDirectory AS FilesInWorkingDirectory
	|WHERE
	|	FilesInWorkingDirectory.User = &User
	|	AND FilesInWorkingDirectory.InOwnerWorkingDirectory = TRUE
	|	AND FilesInWorkingDirectory.Path LIKE &Path ESCAPE ""~""";

	Query.SetParameter("User", Users.AuthorizedUser());
	Query.SetParameter("Path", Common.GenerateSearchQueryString(DirectoryNamePreviousValue)
		+ "%");
	SetPrivilegedMode(True);
	QueryResult = Query.Execute();

	ListForChange = New Array;

	Selection = QueryResult.Select();
	While Selection.Next() Do

		NewPath = Selection.Path;
		NewPath = StrReplace(NewPath, DirectoryNamePreviousValue, FolderWorkingDirectory);

		FileInWorkingDirectory = FileInWorkingDirectory();
		FileInWorkingDirectory.File = Selection.File;
		FileInWorkingDirectory.Path = NewPath;
		FileInWorkingDirectory.Size = Selection.Size;
		FileInWorkingDirectory.PutFileInWorkingDirectoryDate = Selection.PutFileInWorkingDirectoryDate;
		FileInWorkingDirectory.ForReading = Selection.ForReading;

		ListForChange.Add(FileInWorkingDirectory);

	EndDo;

	For Each ListItem In ListForChange Do

		InOwnerWorkingDirectory = True;

		FileInWorkingDirectory = ListItem; // See FileInWorkingDirectory
		WriteRecordStructureToRegister(
			FileInWorkingDirectory.File, FileInWorkingDirectory.Path, FileInWorkingDirectory.Size,
			FileInWorkingDirectory.PutFileInWorkingDirectoryDate, FileInWorkingDirectory.ForReading, InOwnerWorkingDirectory);

	EndDo;

EndProcedure

// After changing the path, write it again with the same values of other fields.
// Parameters:
//  Version - CatalogRef.FilesVersions - a version.
//  Path - String - a relative path inside the working directory.
//  Size  - file size in bytes.
//  PutFileInWorkingDirectoryDate - Date - the date when the file was stored to the working directory.
//  ForReading - Boolean - a file is placed for reading.
//  InOwnerWorkingDirectory - Boolean - a file is in owner working directory (not in the main working directory).
//
Procedure WriteRecordStructureToRegister(File, Path, Size, PutFileInWorkingDirectoryDate, ForReading,
	InOwnerWorkingDirectory)

	HasRightsToObject = Common.ObjectAttributesValues(File, "Ref", True);

	If HasRightsToObject = Undefined Then
		Return;
	EndIf;

	SetPrivilegedMode(True);
	
	// Create a record set.
	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();

	RecordSet.Filter.File.Set(File);
	RecordSet.Filter.User.Set(Users.AuthorizedUser());

	NewRecord = RecordSet.Add();
	NewRecord.File = File;
	NewRecord.Path = Path;
	NewRecord.Size = Size;
	NewRecord.PutFileInWorkingDirectoryDate = PutFileInWorkingDirectoryDate;
	NewRecord.User = Users.AuthorizedUser();

	NewRecord.ForReading = ForReading;
	NewRecord.InOwnerWorkingDirectory = InOwnerWorkingDirectory;

	RecordSet.Write();

EndProcedure

// Returns information records from the "FilesInWorkingDirectory" register for passing filenames.
//
// Parameters:
//  FilesNames - Array of String - file names with a relative path (without a path to the working directory).
//
// Returns:
//  Map of KeyAndValue:
//    * Key - String - File name.
//    * Value - Structure:
//        * FileIsInRegister - Boolean - Information records on the passed file were found.
//        * File              - DefinedType.AttachedFile - File associated with the given name.
//        * PutFileDate     - the date when the file was stored to the working directory.
//        * Owner          - DefinedType.AttachedFile - If "File" is "CatalogRef.FilesVersions",
//                              it contains its "CatalogRef.Files".
//        * VersionNumber       - Number - Version number.
//        * EditedByCurrentUser - Boolean
//        * InRegisterForReading - Boolean - Value of the "ForReading" resource.
//        * FileCodeInRegister - Number - File code.
//        * InRegisterFolder    - DefinedType.FilesOwner - File owner or directory.
//
Function FilesInfoInWorkingDir(Val FilesNames) Export

	SetPrivilegedMode(True);

	Result = New Map;
	AuthorizedUser = Users.AuthorizedUser();

	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.FilesInWorkingDirectory");
	LockItem.SetValue("User", AuthorizedUser);
	LockItem.Mode = DataLockMode.Shared;

	BeginTransaction();
	Try

		Block.Lock();

		Query = New Query;
		Query.Text =
		"SELECT
		|	FilesInWorkingDirectory.File AS File,
		|	FilesInWorkingDirectory.PutFileInWorkingDirectoryDate AS PutFileDate,
		|	FilesInWorkingDirectory.ForReading AS InRegisterForReading,
		|	CASE
		|		WHEN VALUETYPE(FilesInWorkingDirectory.File) = TYPE(Catalog.FilesVersions)
		|			THEN CAST(FilesInWorkingDirectory.File AS Catalog.FilesVersions).Owner
		|		ELSE FilesInWorkingDirectory.File
		|	END AS Owner,
		|	CASE
		|		WHEN VALUETYPE(FilesInWorkingDirectory.File) = TYPE(Catalog.FilesVersions)
		|			THEN CAST(FilesInWorkingDirectory.File AS Catalog.FilesVersions).VersionNumber
		|		ELSE 0
		|	END AS VersionNumber,
		|	FilesInWorkingDirectory.Path AS FilePath
		|FROM
		|	InformationRegister.FilesInWorkingDirectory AS FilesInWorkingDirectory
		|WHERE
		|	FilesInWorkingDirectory.Path IN (&FilesNames)
		|	AND FilesInWorkingDirectory.User = &User";

		Query.SetParameter("FilesNames", FilesNames);
		Query.SetParameter("User", AuthorizedUser);
		Selection = Query.Execute().Select();
		While Selection.Next() Do

			FileInfo1 = FileInfoInWorkingDir();
			FillPropertyValues(FileInfo1, Selection);
			FileInfo1.FileIsInRegister = True;

			// @skip-check query-in-loop - Addressing flexible-type tables
			FileOwner = Common.ObjectAttributesValues(Selection.Owner, "FileOwner,BeingEditedBy");
			FileInfo1.InRegisterFolder = FileOwner.FileOwner;
			FileInfo1.EditedByCurrentUser = FileOwner.BeingEditedBy = AuthorizedUser;
			Result[Selection.FilePath] = FileInfo1;
			
		EndDo;
		
		CommitTransaction();

	Except
		RollbackTransaction();
		Raise;
	EndTry;

	For Each FileName In FilesNames Do
		If Result[FileName] = Undefined Then
			Result[FileName] = FileInfoInWorkingDir();
		EndIf;
	EndDo;

	Return Result;

EndFunction

Function FileInfoInWorkingDir()

	Result = New Structure;
	Result.Insert("FileIsInRegister", False);
	Result.Insert("File", Catalogs.FilesVersions.EmptyRef());
	Result.Insert("PutFileDate");
	Result.Insert("Owner");
	Result.Insert("VersionNumber");
	Result.Insert("EditedByCurrentUser"); 
	Result.Insert("InRegisterForReading");
	Result.Insert("FileCodeInRegister");
	Result.Insert("InRegisterFolder");
	Return Result;

EndFunction


// Finds information on FileVersions in the FilesInWorkingDirectory information register:
// The path to the version file in a working directory and its status: read-only editable.
// 
// Parameters:
//  Version - CatalogRef.FilesVersions - Version.
//  DirectoryName - String - working directory path.
//  InWorkingDirectoryForRead - Boolean - a file is placed for reading.
//  InOwnerWorkingDirectory - Boolean - a file is in owner working directory (not in the main working directory).
//
Function FullFileNameInWorkingDirectory(Val Version, Val DirectoryName, InWorkingDirectoryForRead,
	InOwnerWorkingDirectory) Export

	HasRightsToObject = Common.ObjectAttributesValues(Version, "Ref", True);
	If HasRightsToObject = Undefined Then
		Return Undefined;
	EndIf;

	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);

	FilterStructure1 = New Structure;
	FilterStructure1.Insert("File", Version.Ref);
	FilterStructure1.Insert("User", Users.AuthorizedUser());

	ResourcesStructure = InformationRegisters.FilesInWorkingDirectory.Get(FilterStructure1);
	FullFileName = ResourcesStructure.Path;
	InWorkingDirectoryForRead = ResourcesStructure.ForReading;
	InOwnerWorkingDirectory = ResourcesStructure.InOwnerWorkingDirectory;
	If FullFileName <> "" And InOwnerWorkingDirectory = False Then
		Common.ShortenFileName(FullFileName);
		FullFileName = DirectoryName + FullFileName;
	EndIf;

	Return FullFileName;

EndFunction

// Writing information about a file path to the FilesInWorkingDirectory information register.
// Parameters:
//  CurrentVersion - CatalogRef.FilesVersions - version.
//  FullFileName - name with a path in the working directory.
//  ForReading - Boolean - a file is placed for reading.
//  InOwnerWorkingDirectory - Boolean - a file is in owner working directory (not in the main working directory).
//
Procedure WriteFullFileNameToRegister(CurrentVersion, FullFileName, ForReading, InOwnerWorkingDirectory) Export

	SetPrivilegedMode(True);
	
	// Create a record set.
	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();

	RecordSet.Filter.File.Set(CurrentVersion.Ref);
	RecordSet.Filter.User.Set(Users.AuthorizedUser());

	NewRecord = RecordSet.Add();
	NewRecord.File = CurrentVersion.Ref;
	NewRecord.Path = FullFileName;
	NewRecord.Size = CurrentVersion.Size;
	NewRecord.PutFileInWorkingDirectoryDate = CurrentSessionDate();
	NewRecord.User = Users.AuthorizedUser();

	NewRecord.ForReading = ForReading;
	NewRecord.InOwnerWorkingDirectory = InOwnerWorkingDirectory;

	RecordSet.Write();

EndProcedure

// Delete a record about the specified version of the file from the FilesInWorkingDirectory information register.
// Parameters:
//  Version - CatalogRef.FilesVersions - a version.
//
Procedure DeleteFromRegister(File) Export

	HasRightsToObject = Common.ObjectAttributesValues(File, "Ref", True);
	If HasRightsToObject = Undefined Then
		Return;
	EndIf;

	SetPrivilegedMode(True);

	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();

	RecordSet.Filter.File.Set(File);
	RecordSet.Filter.User.Set(Users.AuthorizedUser());

	RecordSet.Write();

EndProcedure

// Delete a record about the previous version in the FilesInWorkingDirectory information register and write the new one.
// Parameters:
//  OldVersion - CatalogRef.FilesVersions - an old version.
//  NewVersion - CatalogRef.FilesVersions - new version.
//  FullFileName - name with a path in the working directory.
//  DirectoryName - working directory path.
//  InOwnerWorkingDirectory - Boolean - a file is in owner working directory (not in the main working directory).
//
Procedure DeleteVersionAndPutFileInformationIntoRegister(OldVersion, NewVersion, FullFileName, DirectoryName,
	InOwnerWorkingDirectory)

	If Common.IsWebClient() Then
		Return;
	EndIf;

	If Not ValueIsFilled(NewVersion) Then
		Return;
	EndIf;

	DeleteFromRegister(OldVersion);
	ForReading = True;
	PutFileInformationInRegister(NewVersion, FullFileName, DirectoryName, ForReading, 0, InOwnerWorkingDirectory);

EndProcedure

// Writing information about a file path to the FilesInWorkingDirectory information register.
// 
// Parameters:
//  Version - CatalogRef.FilesVersions - version.
//  FullPath - String - a full file path.
//  DirectoryName - String - a working directory path.
//  ForReading - Boolean - a file is placed for reading.
//  FileSize  - Number - File size in bytes.
//  InOwnerWorkingDirectory - Boolean - a file is in owner working directory (not in the main working directory).
//
Procedure PutFileInformationInRegister(Version, FullPath, DirectoryName, ForReading, FileSize,
	InOwnerWorkingDirectory) Export
	FullFileName = FullPath;

	If InOwnerWorkingDirectory = False Then
		If StrFind(FullPath, DirectoryName) = 1 Then
			FullFileName = Mid(FullPath, StrLen(DirectoryName) + 1);
		EndIf;
	EndIf;

	HasRightsToObject = Common.ObjectAttributesValues(Version, "Ref", True);

	If HasRightsToObject = Undefined Then
		Return;
	EndIf;

	SetPrivilegedMode(True);
	
	// Create a record set.
	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();

	RecordSet.Filter.File.Set(Version.Ref);
	RecordSet.Filter.User.Set(Users.AuthorizedUser());

	NewRecord = RecordSet.Add();
	NewRecord.File = Version.Ref;
	NewRecord.Path = FullFileName;

	If FileSize <> 0 Then
		NewRecord.Size = FileSize;
	Else
		NewRecord.Size = Version.Size;
	EndIf;

	NewRecord.PutFileInWorkingDirectoryDate = CurrentSessionDate();
	NewRecord.User = Users.AuthorizedUser();
	NewRecord.ForReading = ForReading;
	NewRecord.InOwnerWorkingDirectory = InOwnerWorkingDirectory;

	RecordSet.Write();

EndProcedure

// Sorts an array of structures by the Date field on the server, since there is no ValueTable on the thin client.
//
// Parameters:
//   StructuresArray - Array of Structure
//
Procedure SortStructuresArray(StructuresArray) Export

	TableOfFiles = New ValueTable;
	TableOfFiles.Columns.Add("Path");
	TableOfFiles.Columns.Add("Version");
	TableOfFiles.Columns.Add("Size");

	TableOfFiles.Columns.Add("PutFileInWorkingDirectoryDate", New TypeDescription("Date"));

	For Each FileInfo1 In StructuresArray Do
		NewRow = TableOfFiles.Add();
		FillPropertyValues(NewRow, FileInfo1, "Path, Size, Version, PutFileInWorkingDirectoryDate");
	EndDo;
	
	// Sorting by date means that in the beginning there will be items, placed in the working directory long ago.
	TableOfFiles.Sort("PutFileInWorkingDirectoryDate Asc");

	Result = New Array;

	For Each FileInfo1 In TableOfFiles Do
		Record = New Structure;
		Record.Insert("Path", FileInfo1.Path);
		Record.Insert("Size", FileInfo1.Size);
		Record.Insert("Version", FileInfo1.Version);
		Record.Insert("PutFileInWorkingDirectoryDate", FileInfo1.PutFileInWorkingDirectoryDate);
		Result.Add(Record);
	EndDo;

	StructuresArray = Result;

EndProcedure

// The function changes FileOwner for the objects as Catalog.File, and returns True if successful.
// Parameters:
//  ArrayOfRefsToFiles - Array - an array of files.
//  NewFileOwner1  - AnyRef - a new file owner.
//
// Returns:
//   Boolean  - shows whether the operation is performed successfully.
//
Function SetFileOwner(ArrayOfRefsToFiles, NewFileOwner1) Export
	If ArrayOfRefsToFiles.Count() = 0 Or Not ValueIsFilled(NewFileOwner1) Then
		Return False;
	EndIf;
	
	// Parent is the same, you do not have to do anything.
	If ArrayOfRefsToFiles.Count() > 0 And (ArrayOfRefsToFiles[0].FileOwner = NewFileOwner1) Then
		Return False;
	EndIf;

	BeginTransaction();
	Try
		Block = New DataLock;
		For Each ReceivedFile1 In ArrayOfRefsToFiles Do
			LockItem = Block.Add(Metadata.FindByType(TypeOf(ReceivedFile1)).FullName());
			LockItem.SetValue("Ref", ReceivedFile1);
		EndDo;
		Block.Lock();

		For Each ReceivedFile1 In ArrayOfRefsToFiles Do
			FileObject1 = ReceivedFile1.GetObject();
			FileObject1.Lock();
			FileObject1.FileOwner = NewFileOwner1;
			FileObject1.Write();
		EndDo;

		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

	Return True;

EndFunction

// The function changes the Parent property to objects of the Catalog.FilesFolders type. It returns True if successful 
// in the variable LoopFound it returns True if one of the folders is transferred to its child folder.
//
// Parameters:
//  ArrayOfRefsToFiles - Array - an array of files.
//  NewParent  - AnyRef - a new file owner.
//  LoopFound - Boolean - returns True if a loop is found.
//
// Returns:
//   Boolean  - Shows whether the operation is performed successfully.
//
Function ChangeFoldersParent(ArrayOfRefsToFiles, NewParent, LoopFound) Export
	LoopFound = False;

	If ArrayOfRefsToFiles.Count() = 0 Then
		Return False;
	EndIf;
	
	// Parent is the same, you do not have to do anything.
	If ArrayOfRefsToFiles.Count() = 1 And (ArrayOfRefsToFiles[0].Parent = NewParent) Then
		Return False;
	EndIf;

	If HasLoop(ArrayOfRefsToFiles, NewParent) Then
		LoopFound = True;
		Return False;
	EndIf;

	BeginTransaction();
	Try
		Block = New DataLock;
		For Each ReceivedFile1 In ArrayOfRefsToFiles Do
			LockItem = Block.Add(Metadata.FindByType(TypeOf(ReceivedFile1)).FullName());
			LockItem.SetValue("Ref", ReceivedFile1);
		EndDo;
		Block.Lock();

		For Each ReceivedFile1 In ArrayOfRefsToFiles Do
			FileObject1 = ReceivedFile1.GetObject();
			FileObject1.Lock();
			FileObject1.Parent = NewParent;
			FileObject1.Write();
		EndDo;

		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

	Return True;

EndFunction

// Receives file data to open and reads from the common settings of FolderToSaveAs.
//
// Parameters:
//  FileOrVersionRef     - CatalogRef.Files
//                          - , CatalogRef.FilesVersions - a file or a file version.
//  FormIdentifier      - UUID - a form UUID.
//  OwnerWorkingDirectory - String - a working directory of the file owner.
//
// Returns:
//   Structure - structure with file data.
//
Function FileDataToSave(FileRef, VersionRef = Undefined, FormIdentifier = Undefined,
	OwnerWorkingDirectory = Undefined) Export

	FileData = FileDataToOpen(FileRef, VersionRef, FormIdentifier, OwnerWorkingDirectory);

	FolderForSaveAs = Common.CommonSettingsStorageLoad("ApplicationSettings",
		"FolderForSaveAs");
	FileData.Insert("FolderForSaveAs", FolderForSaveAs);

	Return FileData;
EndFunction

// Receives FileData and VersionURL of all subordinate files.
// Parameters:
//  FileRef - CatalogRef.Files - file.
//  FormIdentifier - form UUID.
//
// Returns:
//   Array - array of structures with file data.
//
Function FileDataAndURLOfAllFileVersions(FileRef, FormIdentifier) Export

	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	FilesVersions.Ref AS Ref
	|FROM
	|	Catalog.FilesVersions AS FilesVersions
	|WHERE
	|	FilesVersions.Owner = &FileRef";

	Query.SetParameter("FileRef", FileRef);
	Result = Query.Execute();
	Selection = Result.Select();

	FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	FileDataParameters.RaiseException1 = False;
	FileDataParameters.GetBinaryDataRef = False;

	ReturnArray = New Array;
	While Selection.Next() Do

		VersionRef = Selection.Ref;
		FileData = FileData(FileRef, VersionRef, FileDataParameters);

		If FileData.DeletionMark = False And Not AttachedFileIsLocatedOnDisk(VersionRef) Then

			Continue;
		EndIf;

		VersionURL = FilesOperationsInternal.GetTemporaryStorageURL(
			VersionRef, FormIdentifier);

		ReturnStructure = New Structure("FileData, VersionURL, VersionRef", FileData,
			VersionURL, VersionRef);
		ReturnArray.Add(ReturnStructure);

	EndDo;
	
	// If versions are not stored, encrypting the file.
	StoreVersions = Common.ObjectAttributeValue(FileRef, "StoreVersions");
	
	If Not StoreVersions 
		Or Not ValueIsFilled(Common.ObjectAttributeValue(FileRef, "CurrentVersion")) Then
		
		FileDataParameters = FilesOperationsClientServer.FileDataParameters();
		FileDataParameters.GetBinaryDataRef = False;
		FileData = FileData(FileRef,, FileDataParameters);
		VersionURL = FilesOperationsInternal.GetTemporaryStorageURL(FileRef,
			FormIdentifier);

		ReturnStructure = New Structure("FileData, VersionURL, VersionRef", FileData,
			VersionURL, FileRef);
		ReturnArray.Add(ReturnStructure);
	EndIf;

	Return ReturnArray;
EndFunction

// Adds a signature to the file version and marks the file as signed.
Procedure AddSignatureToFile(FileRef, SignatureProperties, FormIdentifier) Export

	AttributesStructure1 = Common.ObjectAttributesValues(FileRef, "BeingEditedBy, Encrypted");

	BeingEditedBy = AttributesStructure1.BeingEditedBy;
	If ValueIsFilled(BeingEditedBy) Then
		Raise FilesOperationsInternalClientServer.MessageAboutInvalidSigningOfLockedFile(
			FileRef);
	EndIf;

	Encrypted = AttributesStructure1.Encrypted;
	If Encrypted Then
		ExceptionString = FilesOperationsInternalClientServer.MessageAboutInvalidSigningOfEncryptedFile(
			FileRef);
		Raise ExceptionString;
	EndIf;

	If Not Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;

	ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
	ModuleDigitalSignature.AddSignature(FileRef, SignatureProperties, FormIdentifier);

EndProcedure

Procedure ShowTooltipsOnEditFiles(Value = Undefined) Export

	SetPrivilegedMode(True);
	If Value <> Undefined Then
		CommonServerCall.CommonSettingsStorageSave(
			"ApplicationSettings", "ShowTooltipsOnEditFiles", Value,,, True);
		RefreshReusableValues();
	EndIf;

EndProcedure

#Region FilesAndVersionsDataDeletion

Function FilesDeletionResult(FilesOrVersions, UUID) Export

	SetPrivilegedMode(True);

	AuthorizedUser = Users.AuthorizedUser();
	DeletionResult = New Map;
	For Each FileOrVersion In FilesOrVersions Do

		IsFileVersion = TypeOf(FileOrVersion) = Type("CatalogRef.FilesVersions");
		Result = New Structure("WarningText, Files", "", New Array);
		If Common.ObjectAttributeValue(FileOrVersion, "Author") = AuthorizedUser Then
			If IsFileVersion Then
				// @skip-check query-in-loop - Batch-wise deletion of versions in transactions. 
				DeleteVersionData(FileOrVersion, UUID, Result);
			Else
				// @skip-check query-in-loop - Batch-wise deletion of files in transactions. 
				DeleteFileData(FileOrVersion, UUID, Result, AuthorizedUser);
			EndIf;
		Else
			Result.WarningText = ?(IsFileVersion, NStr("en = 'Only the author can delete the file version.';"),
				NStr("en = 'Only the author can delete the file.';"));
		EndIf;
		DeletionResult.Insert(FileOrVersion, Result);

	EndDo;

	Return DeletionResult;

EndFunction
Procedure DeleteVersionData(FileOrVersion, UUID, Result)

	DataLock = New DataLock;
	DataLockItem = DataLock.Add(FileOrVersion.Metadata().FullName());
	DataLockItem.SetValue("Ref", FileOrVersion);

	BeginTransaction();
	Try

		DataLock.Lock();
		CurrentOwnerVersionParameters = Common.ObjectAttributeValue(FileOrVersion, "Owner,CurrentVersion");
		If CurrentOwnerVersionParameters.CurrentVersion = FileOrVersion Then

			Query = New Query;
			Query.Text =
			"SELECT
			|	FilesVersions.Ref AS Ref
			|FROM
			|	Catalog.FilesVersions AS FilesVersions
			|WHERE
			|	FilesVersions.Owner = &Owner
			|	AND FilesVersions.Ref <> &Ref
			|	AND NOT FilesVersions.DeletionMark
			|
			|ORDER BY
			|	FilesVersions.VersionNumber DESC";
			Query.SetParameter("Owner", CurrentOwnerVersionParameters.Owner);
			Query.SetParameter("Ref", FileOrVersion);
			OwnerVersions = Query.Execute().Select();

			If OwnerVersions.Next() Then
				FilesOperationsInternal.UpdateVersionInFile(CurrentOwnerVersionParameters.Owner,
					OwnerVersions.Ref, Undefined, UUID);
			EndIf;

		EndIf;

		Result.Files.Add(FileOrVersion);
		DeleteData(FileOrVersion, UUID);
		CommitTransaction();

	Except
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure

Procedure DeleteFileData(File, UUID, Result, AuthorizedUser)

	DataLock = New DataLock;
	DataLockItem = DataLock.Add(File.Metadata().FullName());
	DataLockItem.SetValue("Ref", File);
	
	HasFileVersions = TypeOf(File) = Type("CatalogRef.Files");
	If HasFileVersions Then
		DataLockItem = DataLock.Add(Metadata.Catalogs.FilesVersions.FullName());
		DataLockItem.SetValue("Owner", File);
		DataLockItem.Mode = DataLockMode.Shared;
	EndIf;
	
	HasFileVersions = False;
	BeginTransaction();
	Try
		DataLock.Lock();
		
		If HasFileVersions Then
			Query = New Query;
			Query.Text =
			"SELECT
			|	FilesVersions.Ref AS Ref,
			|	FilesVersions.Author AS Author
			|FROM
			|	Catalog.FilesVersions AS FilesVersions
			|WHERE
			|	FilesVersions.Owner = &Owner
			|
			|ORDER BY
			|	FilesVersions.VersionNumber DESC";
			Query.SetParameter("Owner", File);
			QueryResult = Query.Execute();
	
			HasFileVersions = Not QueryResult.IsEmpty();
		EndIf;
		
		If HasFileVersions Then
			Selection = QueryResult.Select();
		Else
			Result.Files.Add(File);
			DeleteData(File, UUID);
		EndIf;
		CommitTransaction();

	Except
		RollbackTransaction();
		Raise;
	EndTry;

	If Not HasFileVersions Then
		Return;
	EndIf;

	OtherAuthorVersion = Undefined;
	While Selection.Next() Do

		If Selection.Author <> AuthorizedUser Then
			If OtherAuthorVersion = Undefined Then
				OtherAuthorVersion = Selection.Ref;
			EndIf;
			Continue;
		EndIf;

		Result.Files.Add(Selection.Ref);
		DeleteData(Selection.Ref, UUID);

	EndDo;

	If OtherAuthorVersion <> Undefined Then
		FilesOperationsInternal.UpdateVersionInFile(File, OtherAuthorVersion, Undefined, UUID);
	Else
		Result.Files.Add(File);
		DeleteData(File, UUID);
	EndIf;

EndProcedure

Procedure DeleteData(FileOrVersion, UUID)

	DataLock = New DataLock;
	DataLockItem = DataLock.Add(FileOrVersion.Metadata().FullName());
	DataLockItem.SetValue("Ref", FileOrVersion);

	BeginTransaction();
	Try

		DataLock.Lock();
		LockDataForEdit(FileOrVersion,, UUID);

		FileOrVersionObject = FileOrVersion.GetObject();
		If FileOrVersionObject.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then

			AttachedFileIsLocatedOnDisk = AttachedFileIsLocatedOnDisk(FileOrVersion);
			If AttachedFileIsLocatedOnDisk Then

				FileProperties = FilesOperationsInVolumesInternal.FilePropertiesInVolume();
				FillPropertyValues(FileProperties, FileOrVersionObject);
				FilesOperationsInVolumesInternal.DeleteFile(FilesOperationsInVolumesInternal.FullFileNameInVolume(
					FileProperties));

			EndIf;
			// Change the file path to make sure that it is unique.
			// Do not validate the extension since the data is deleted from the computer.
			FileOrVersionObject.PathToFile = FileOrVersionObject.PathToFile + "_remove";//@Non-NLS
		Else
			SetPrivilegedMode(True);
			InformationRegisters.FileRepository.DeleteBinaryData(FileOrVersion);
			SetPrivilegedMode(False);
		EndIf;	
		
		FileOrVersionObject.DeletionMark = True;
		FileOrVersionObject.AdditionalProperties.Insert("DataDeletion", True);
		FileOrVersionObject.Write();

		UnlockDataForEdit(FileOrVersion, UUID);
		CommitTransaction();

	Except
		RollbackTransaction();
		UnlockDataForEdit(FileOrVersion, UUID);
		Raise;
	EndTry;

EndProcedure

#EndRegion

// Information.

// The function returns the number of Files locked by the current user
// by owner.
// Parameters:
//  FileOwner  - AnyRef - file owner.
//
// Returns:
//   Number  - number of locked files.
//
Function FilesLockedByCurrentUserCount(FileOwner) Export

	Return FilesOperationsInternal.LockedFilesCount(FileOwner);

EndFunction

// Receives the number of file versions.
// Parameters:
//  FileRef - CatalogRef.Files - file.
//
// Returns:
//   Number - number of versions
//
Function GetVersionsCount(FileRef)

	SetPrivilegedMode(True);

	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(*) AS Count
	|FROM
	|	Catalog.FilesVersions AS FilesVersions
	|WHERE
	|	FilesVersions.Owner = &FileRef";

	Query.SetParameter("FileRef", FileRef);
	Selection = Query.Execute().Select();
	Selection.Next();

	Return Number(Selection.Count);

EndFunction

// Returns True if there is looping (if a folder is moved into its own child folder).
// Parameters:
//  ArrayOfRefsToFiles - Array - an array of files.
//  NewParent  - AnyRef - a new file owner.
//
// Returns:
//   Boolean  - there is a loop.
//
Function HasLoop(Val ArrayOfRefsToFiles, NewParent)

	If ArrayOfRefsToFiles.Find(NewParent) <> Undefined Then
		Return True; // A looping is found.
	EndIf;

	Query = New Query;
	Query.Text = "SELECT
				   |	FilesFolders.Parent AS Parent
				   |FROM
				   |	Catalog.FilesFolders AS FilesFolders
				   |WHERE
				   |	FilesFolders.Ref = &Ref
				   |TOTALS
				   |BY
				   |	Parent ONLY HIERARCHY";

	Query.SetParameter("Ref", NewParent);

	Parents = Query.Execute().Unload().UnloadColumn("Parent");

	LinksToParentlessFiles = CommonClientServer.ArraysDifference(ArrayOfRefsToFiles, Parents);

	Return LinksToParentlessFiles.Count() <> ArrayOfRefsToFiles.Count();

EndFunction

// Returns True if the specified item of the FilesFolders has a child node with this name.
//
// Parameters:
//  FolderName					 - String					     - folder name
//  Parent					 - DefinedType.AttachedFilesOwner	 - a folder parent.
//  FirstFolderWithSameName	 - DefinedType.AttachedFilesOwner	 - the first found folder with the specified name.
// 
// Returns:
//  Boolean - there is a child item with this name.
//
Function HasFolderWithThisName(FolderName, Parent, FirstFolderWithSameName) Export

	FirstFolderWithSameName = Catalogs.FilesFolders.EmptyRef();

	QuerySelection = QueryToFolders(FolderName, Parent);

	If QuerySelection.Count() > 0 Then
		FirstFolderWithSameName = QuerySelection.Ref;
		Return True;
	EndIf;

	Return False;

EndFunction

// Returns:
//  Structure:
//   * Ref - AnyRef
// 
Function QueryToFolders(Val FolderName, Parent)
	QueryToFolders = New Query;
	QueryToFolders.SetParameter("Description", FolderName);
	QueryToFolders.SetParameter("Parent", Parent);
	QueryToFolders.Text =
	"SELECT ALLOWED TOP 1
	|	FilesFolders.Ref AS Ref
	|FROM
	|	Catalog.FilesFolders AS FilesFolders
	|WHERE
	|	FilesFolders.Description = &Description
	|	AND FilesFolders.Parent = &Parent";

	If Parent <> Undefined And TypeOf(Parent) <> Type("CatalogRef.FilesFolders") Then
		FilesStorageCatalogName = FilesOperationsInternal.FileStoringCatalogName(Parent);
		QueryToFolders.Text = StrReplace(QueryToFolders.Text, ".FilesFolders", "." + FilesStorageCatalogName);
	EndIf;

	QueryResult = QueryToFolders.Execute();
	QuerySelection = QueryResult.Select();
	QuerySelection.Next();
	Return QuerySelection
EndFunction

Function FileToSynchronizeByCloudService(File)

	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	COUNT(FilesSynchronizationWithCloudServiceStatuses.File) AS File
	|FROM
	|	InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
	|WHERE
	|	FilesSynchronizationWithCloudServiceStatuses.File = &File";

	Query.SetParameter("File", File);

	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return False;
	EndIf;

	Return True;

EndFunction

Function HasAccessRight(Right, Ref) Export

	Return AccessRight(Right, Ref.Metadata());

EndFunction

Function ImageAddingOptions(FilesOwner, PlacementAttribute = Undefined) Export

	AddingOptions = New Structure;
	AddingOptions.Insert("InsertRight1", HasAccessRight("Insert", FilesOwner)); // @Access-right-2
	AddingOptions.Insert("EditRight", HasAccessRight("Update", FilesOwner)); // @Access-right-2
	AddingOptions.Insert("OwnerFiles", AttachedFilesCount(FilesOwner, True,
		PlacementAttribute));
	Return AddingOptions;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Creates new files by analogy with the specified ones.
// Parameters:
//  FilesArray  - Array - an array of files CatalogRef.Files - the existing files.
//  NewFileOwner - AnyRef - file owner.
//
Procedure DoCopyAttachedFiles(FilesArray, NewFileOwner) Export

	For Each File In FilesArray Do
		CopyAttachedFile(File, NewFileOwner);
	EndDo;

EndProcedure

// Checks the Encrypted flag for the file.
Procedure CheckEncryptedFlag(FileRef, Encrypted, UUID = Undefined) Export

	BeginTransaction();
	Try
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(FileRef)).FullName());
		DataLockItem.SetValue("Ref", FileRef);
		DataLock.Lock();

		FileObject1 = FileRef.GetObject();
		LockDataForEdit(FileRef,, UUID);

		FileObject1.Encrypted = Encrypted;
		// To write a previously signed object.
		FileObject1.AdditionalProperties.Insert("WriteSignedObject", True);
		FileObject1.Write();
		UnlockDataForEdit(FileRef, UUID);
		CommitTransaction();
	Except
		RollbackTransaction();
		UnlockDataForEdit(FileRef, UUID);
		Raise;
	EndTry;

EndProcedure

// Updates the size of the file and current version.
//
// Parameters:
//   FileData - See FileData
//   FileSize - Number
//   FormIdentifier - UUID
//
Procedure UpdateSizeOfFileAndVersion(FileData, FileSize, FormIdentifier) Export

	FileVersionIsSpecified = FileData.Version <> FileData.Ref;

	Block = New DataLock;
	LockItem = Block.Add(FileData.Ref.Metadata().FullName());
	LockItem.SetValue("Ref", FileData.Ref);
	If FileVersionIsSpecified Then
		LockItem = Block.Add(FileData.Version.Metadata().FullName());
		LockItem.SetValue("Ref", FileData.Version);
	EndIf;

	BeginTransaction();
	Try

		Block.Lock();
		LockDataForEdit(FileData.Ref,, FormIdentifier);
		If FileVersionIsSpecified Then
			LockDataForEdit(FileData.Version,, FormIdentifier);
		EndIf;

		VersionObject = FileData.Version.GetObject();
		VersionObject.Size = FileSize;
		// To write a signed object.
		VersionObject.AdditionalProperties.Insert("WriteSignedObject", True);
		VersionObject.Write();

		If FileVersionIsSpecified Then
			FileObject1 = FileData.Ref.GetObject();
			// To write a signed object.
			FileObject1.AdditionalProperties.Insert("WriteSignedObject", True);
			FileObject1.Write();
		EndIf;

		UnlockDataForEdit(FileData.Ref, FormIdentifier);
		If FileVersionIsSpecified Then
			UnlockDataForEdit(FileData.Version, FormIdentifier);
		EndIf;

		CommitTransaction();
	Except
		RollbackTransaction();
		UnlockDataForEdit(FileData.Ref, FormIdentifier);
		If FileVersionIsSpecified Then
			UnlockDataForEdit(FileData.Version, FormIdentifier);
		EndIf;
		Raise;
	EndTry;

EndProcedure

Procedure WriteFileVersionEncoding(VersionRef, Encoding) Export

	InformationRegisters.FilesEncoding.WriteFileVersionEncoding(VersionRef, Encoding);

EndProcedure

// Writes the file version encoding.
//
// Parameters:
//   VersionRef - reference to the file version.
//   Encoding - encoding string.
//   ExtractedText - text extracted from the file.
//
Procedure WriteFileVersionEncodingAndExtractedText(VersionRef, Encoding, ExtractedText) Export

	InformationRegisters.FilesEncoding.WriteFileVersionEncoding(VersionRef, Encoding);
	WriteTextExtractionResultOnWrite(VersionRef, Enums.FileTextExtractionStatuses.Extracted,
		ExtractedText);

EndProcedure

// Writes to the server the text extraction results that are the extracted text and the TextExtractionStatus.
Procedure WriteTextExtractionResultOnWrite(VersionRef, ExtractionResult,
	TempTextStorageAddress)

	FileLocked = False;

	VersionMetadata = Metadata.FindByType(TypeOf(VersionRef));
	If Common.HasObjectAttribute("ParentVersion", VersionMetadata) Then
		RequestedAttributes = New Structure;
		RequestedAttributes.Insert("Owner", "Owner");
		RequestedAttributes.Insert("CurrentVersion", "Owner.CurrentVersion");
		FileAttributes = Common.ObjectAttributesValues(VersionRef, RequestedAttributes);
		File = FileAttributes.Owner;
		If FileAttributes.CurrentVersion = VersionRef Then

			Try
				LockDataForEdit(File);
				FileLocked = True;
			Except
				// Exception if the object is already locked, including the Lock method.
				Return;
			EndTry;

		EndIf;
	Else
		File = VersionRef;
	EndIf;

	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;

	BeginTransaction();
	Try
		If TypeOf(File) = Type("CatalogRef.Files") Then
			FileToCompare = FileAttributes.CurrentVersion;
		Else
			FileToCompare = VersionRef;
		EndIf;

		VersionLock = New DataLock;
		DataLockItem = VersionLock.Add(Metadata.FindByType(TypeOf(VersionRef)).FullName());
		DataLockItem.SetValue("Ref", VersionRef);

		If FileToCompare = VersionRef Then
			FileLock = New DataLock;
			DataLockItem = FileLock.Add(Metadata.FindByType(TypeOf(File)).FullName());
			DataLockItem.SetValue("Ref", File);
			FileLock.Lock();
		EndIf;

		VersionLock.Lock();

		VersionObject = VersionRef.GetObject();

		If VersionMetadata.FullTextSearch = FullTextSearchUsing Then
			If Not IsBlankString(TempTextStorageAddress) Then

				If Not IsTempStorageURL(TempTextStorageAddress) Then
					VersionObject.TextStorage = New ValueStorage(TempTextStorageAddress,
						New Deflation(9));
					VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
				Else
					TextExtractionResult = FilesOperationsInternal.ExtractText1(TempTextStorageAddress);
					VersionObject.TextStorage = TextExtractionResult.TextStorage;
					VersionObject.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
				EndIf;

			EndIf;
		Else
			VersionObject.TextStorage = New ValueStorage("");
			VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		EndIf;

		If ExtractionResult = "NotExtracted" Then
			VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		ElsIf ExtractionResult = "Extracted" Then
			VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		ElsIf ExtractionResult = "FailedExtraction" Then
			VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.FailedExtraction;
		EndIf;
	
		// To write a previously signed object.
		VersionObject.AdditionalProperties.Insert("WriteSignedObject", True);
		VersionObject.Write();

		If FileToCompare = VersionRef Then
			FileObject1 = File.GetObject();
			FileObject1.TextStorage = VersionObject.TextStorage;
			// To write a previously signed object.
			FileObject1.AdditionalProperties.Insert("WriteSignedObject", True);
			FileObject1.Write();
		EndIf;

		CommitTransaction();
	Except
		RollbackTransaction();

		If FileLocked Then
			UnlockDataForEdit(File);
		EndIf;

		Raise;
	EndTry;

	If FileLocked Then
		UnlockDataForEdit(File);
	EndIf;

EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////////
//Common file functions.
// See this procedure in the FilesOperationsInternal module.
//
Procedure RecordTextExtractionResult(FileOrVersionRef, ExtractionResult, TempTextStorageAddress) Export

	FilesOperationsInternal.RecordTextExtractionResult(
		FileOrVersionRef, ExtractionResult, TempTextStorageAddress);

EndProcedure

// For internal use only.
// 
// Parameters:
//  RawData - String - Address of the data piece in a temporary storage.
//  RowsData - Array of See DigitalSignatureClientServer.ResultOfSignatureValidationOnForm
//  SignedObject - AnyRef
//
Procedure VerifySignatures(RawData, RowsData, SignedObject) Export

	If Not Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
	ModuleDigitalSignatureClientServer = Common.CommonModule("DigitalSignatureClientServer");

	For Each SignatureRow In RowsData Do

		SignatureVerificationResult = ModuleDigitalSignatureClientServer.SignatureVerificationResult();
		ErrorDescription = "";
		ModuleDigitalSignature.VerifySignature(Undefined, RawData,
			SignatureRow.SignatureAddress, ErrorDescription, SignatureRow.SignatureDate, SignatureVerificationResult);

		SignatureRow.SignatureValidationDate = CurrentSessionDate();
		SignatureRow.SignatureCorrect      = (SignatureVerificationResult.Result = True);
		If SignatureRow.ErrorDescription <> Undefined Then
			SignatureRow.ErrorDescription    = ErrorDescription; // Intended for compatibility purposes.
		EndIf;
		FillPropertyValues(SignatureRow.CheckResult, SignatureVerificationResult);
		SignatureRow.CheckResult.IsAdditionalAttributesCheckedManually = False;
		SignatureRow.CheckResult.AdditionalAttributesManualCheckAuthor = Undefined;
		SignatureRow.CheckResult.AdditionalAttributesManualCheckJustification = "";
		
		SignatureRow.IsVerificationRequired = SignatureVerificationResult.IsVerificationRequired;
		If ValueIsFilled(SignatureVerificationResult.SignatureType) Then
			SignatureRow.SignatureType        = SignatureVerificationResult.SignatureType;
		EndIf;
		If ValueIsFilled(SignatureVerificationResult.DateActionLastTimestamp) Then
			SignatureRow.DateActionLastTimestamp = SignatureVerificationResult.DateActionLastTimestamp;
		EndIf;
		

		If SignatureRow.ErrorDescription <> Undefined Then
			FilesOperationsInternalClientServer.FillSignatureStatus(SignatureRow, CurrentSessionDate()); // Intended for compatibility purposes.
		EndIf;
		ModuleDigitalSignatureClientServer.FillSignatureStatus(SignatureRow, CurrentSessionDate());
		
	EndDo;

EndProcedure

Function CheckSignaturesByMachineReadableLOA(Signatures, SignedObject) Export

	If Not Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return New Array;
	EndIf;
	
	ModuleDigitalSignatureInternal = Common.CommonModule(
			"DigitalSignatureInternal");
			
	Return ModuleDigitalSignatureInternal.CheckSignaturesByMachineReadableLOA(Signatures, SignedObject);

EndFunction

// Enters the number to the ScannedFilesNumbers information register.
//
// Parameters:
//   Owner - AnyRef - file owner.
//   NewNumber -  Number  - max number for scanning.
//
Procedure EnterMaxNumberToScan(Owner, NewNumber) Export
	
	// Prepare a filter structure by dimensions.
	FilterStructure1 = New Structure;
	FilterStructure1.Insert("Owner", Owner);

	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.ScannedFilesNumbers");
		LockItem.SetValue("Owner", Owner);
		Block.Lock();   		
		
		// Receive structure with the data of record resources.
		ResourcesStructure = InformationRegisters.ScannedFilesNumbers.Get(FilterStructure1);
		   
		// Receive the max number from the register.
		Number = ResourcesStructure.Number;
		If NewNumber <= Number Then // Somebody has already written the bigger number.
			RollbackTransaction();
			Return;
		EndIf;

		Number = NewNumber;
		SetPrivilegedMode(True);
		
		// Writing a new number to the register.
		RecordSet = InformationRegisters.ScannedFilesNumbers.CreateRecordSet();

		RecordSet.Filter.Owner.Set(Owner);

		NewRecord = RecordSet.Add();
		NewRecord.Owner = Owner;
		NewRecord.Number = Number;

		RecordSet.Write();

		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure

Function PutFilesInTempStorage(Parameters) Export

	Result = New Array;
	For Each FileAttachment In Parameters.FilesArray Do
		FilesOperationsInternal.GenerateFilesListToSendViaEmail(Result, FileAttachment,
			Parameters.FormIdentifier);
	EndDo;
	Return Result;

EndFunction

///////////////////////////////////////////////////////////////////////////////////
// Insets a digital signature stamp to a spreadsheet or office document.

Function DocumentWithStamp(Val FileData) Export

	Extension = FileData.Extension;
	
	If Extension = "mxl" Then
	
		BinaryData = GetFromTempStorage(FileData.RefToBinaryFileData); // BinaryData
		TempFile = GetTempFileName(".mxl");
		BinaryData.Write(TempFile);

		SpreadsheetDocument = New SpreadsheetDocument;
		SpreadsheetDocument.Read(TempFile);

		DeleteFiles(TempFile);

		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");

		StampParameters = New Structure;
		StampParameters.Insert("MarkText", "");
		StampParameters.Insert("Logo");

		DigitalSignatures = ModuleDigitalSignature.SetSignatures(FileData.Ref);
		FileOwner = FileData.Owner;

		FileInfo1 = New Structure;
		FileInfo1.Insert("FileOwner", FileOwner);

		Stamps = New Array;
		For Each Signature In DigitalSignatures Do
			Certificate = Signature.Certificate;
			CryptoCertificate = New CryptoCertificate(Certificate.Get());
			FilesOperationsOverridable.OnPrintFileWithStamp(StampParameters, CryptoCertificate);

			Stamp = ModuleDigitalSignature.DigitalSignatureVisualizationStamp(CryptoCertificate,
				Signature.SignatureDate, StampParameters.MarkText, StampParameters.Logo);
			Stamps.Add(Stamp);
		EndDo;

		ModuleDigitalSignature.AddStampsToSpreadsheetDocument(SpreadsheetDocument, Stamps);

		Return SpreadsheetDocument;
	ElsIf Extension = "docx" Then
				
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		DigitalSignatures = ModuleDigitalSignature.SetSignatures(FileData.Ref);
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.AddStampsToOfficeDoc(FileData.RefToBinaryFileData,
			DigitalSignatures);

		Return FileData.RefToBinaryFileData;
	Else
		Return Undefined;
	EndIf;

EndFunction


// Checks whether the file is on the computer.
//
// Parameters:
//   AttachedFile - DefinedType.AttachedFile - a catalog item to check with a file.
//
// Returns:
//   Boolean
//
Function AttachedFileIsLocatedOnDisk(Val AttachedFile)

	CommonClientServer.CheckParameter("FilesOperations.FileBinaryData", "AttachedFile",
		AttachedFile, Metadata.DefinedTypes.AttachedFile.Type);

	FileObject1 = FilesOperationsInternal.FileObject1(AttachedFile);
	If (FileObject1 = Undefined Or FileObject1.IsFolder) Then
		Return False;
	EndIf;

	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);

	If FileObject1.DeletionMark Then
		Return False;
	EndIf;

	If FileObject1.FileStorageType = Enums.FileStorageTypes.InInfobase Then

		Result = FilesOperations.FileFromInfobaseStorage(FileObject1.Ref);
		If Result <> Undefined Then
			Result = Result.Get();
			If Result <> Undefined Then
				Return True;
			EndIf;
		EndIf;

		Return False;

	Else
		Return FilesOperationsInVolumesInternal.AttachedFileIsLocatedOnDisk(AttachedFile);
	EndIf;
EndFunction

Function MergeImagesIntoTIFFile(Val Pictures) Export
	ProcessingPicture = New ProcessingPicture(Pictures, PictureFormat.TIFF);
	Return ProcessingPicture.GetPicture();
EndFunction

Function CurrentSessionStart() Export
	Session = GetCurrentInfoBaseSession();
	Return Session.SessionStarted;
EndFunction

Function ScanLogParameters(ClientID) Export
	Result = New Structure;
	Result.Insert("ScanLogStartDate", Common.CommonSettingsStorageLoad(
		"ScanAddIn", "ScanLogStartDate", Date(1, 1, 1)));
	Result.Insert("NameOfLogFile", Common.CommonSettingsStorageLoad("ScanAddIn",
		"NameOfLogFile", Undefined));
	Result.Insert("ScanLogCatalog", Common.CommonSettingsStorageLoad(
		"ScanningSettings1/ScanLogCatalog", ClientID, Undefined));
	Result.Insert("UseScanLogDirectory", Common.CommonSettingsStorageLoad(
		"ScanningSettings1/UseScanLogDirectory", ClientID, False));
	Return Result;
EndFunction

Procedure ResetScanLogDirectoryParameters(ClientID) Export
    
	StructuresArray = New Array;
	
	StructuresArray.Add(FilesOperationsInternal.ScanningSettings("ScanLogCatalog",
		"", ClientID));
	StructuresArray.Add(FilesOperationsInternal.ScanningSettings("UseScanLogDirectory",
		False, ClientID));
	
	CommonServerCall.CommonSettingsStorageSaveArray(StructuresArray, True);
		
EndProcedure

// Returns:
//  Structure:
//   * EventLog - BinaryData - Event Log export data.
//   * TechnicalInfoOnExtensionsAndSubsystemsVersions - String
//   * NameOfLogFile - String - Name of the log file used by the scan add-in.
//
Function TechnicalInformation() Export

	Result = New Structure;
	ScanLogEvent = NStr("en = 'Scan images';", Common.DefaultLanguageCode());

	FilterEvents = New Array;
	FilterEvents.Add(ScanLogEvent + "." + "EnumDevices.Start");
	FilterEvents.Add(ScanLogEvent + "." + "EnumDevices.Result");
	FilterEvents.Add(ScanLogEvent + "." + "EnumDevices");
	FilterEvents.Add(ScanLogEvent + "." + "GetSetting.Start");
	FilterEvents.Add(ScanLogEvent + "." + "GetSetting.Result");
	FilterEvents.Add(ScanLogEvent + "." + "GetSetting");
	FilterEvents.Add(ScanLogEvent + "." + "IsDevicePresent.Start");
	FilterEvents.Add(ScanLogEvent + "." + "IsDevicePresent.Result");
	FilterEvents.Add(ScanLogEvent + "." + "IsDevicePresent");
	FilterEvents.Add(ScanLogEvent + "." + "BeginScan.Start");
	FilterEvents.Add(ScanLogEvent + "." + "BeginScan.Result");
	FilterEvents.Add(ScanLogEvent + "." + "BeginScan");
	FilterEvents.Add(ScanLogEvent + "." + "Version");
	FilterEvents.Add(ScanLogEvent + "." + "ScannerEvent");
	FilterEvents.Add(ScanLogEvent + "." + "ScannerEvent.ImageAcquired");
	FilterEvents.Add(ScanLogEvent + "." + "ScannerEvent.EndBatch");
	FilterEvents.Add(ScanLogEvent + "." + "ScannerEvent.UserPressedCancel");
	FilterEvents.Add(ScanLogEvent + "." + "LogFilePath.ValueSetting");
	FilterEvents.Add(ScanLogEvent + "." + "LogFilePath.IsValueSet");
	FilterEvents.Add(ScanLogEvent + "." + "LogFilePath");
	FilterEvents.Add(ScanLogEvent + "." + "ComponentFile");

	Filter = New Structure("Event", FilterEvents);
	Filter.Insert("StartDate", CurrentSessionDate() - 600);
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	Result.Insert("EventLog", GetFromTempStorage(
		EventLog.TechnicalSupportLog(Filter, 200, New UUID)));
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Result.Insert("TechnicalInfoOnExtensionsAndSubsystemsVersions",
		StandardSubsystemsServer.TechnicalInfoOnExtensionsAndSubsystemsVersions());
	Result.Insert("NameOfLogFile", CommonServerCall.CommonSettingsStorageLoad(
		"ScanAddIn", "NameOfLogFile"));
	Return Result;
EndFunction

Procedure SetScanLogStartParameters(NameOfLogFile) Export
	CommonServerCall.CommonSettingsStorageSave("ScanAddIn", "NameOfLogFile", NameOfLogFile);
	CommonServerCall.CommonSettingsStorageSave("ScanAddIn",
		"ScanLogStartDate", CurrentSessionDate());
EndProcedure

Procedure CleanUpWorkingDirectory(FolderRef) Export
	FilesOperationsInternal.CleanUpWorkingDirectory(FolderRef);
EndProcedure

#EndRegion