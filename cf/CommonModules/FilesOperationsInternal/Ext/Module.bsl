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

// See GenerateFromOverridable.OnDefineObjectsWithCreationBasedOnCommands.
Procedure OnDefineObjectsWithCreationBasedOnCommands(Objects) Export
	
	Objects.Add(Metadata.Catalogs.Files);
	
EndProcedure

// See ObjectAttributesLockOverridable.OnDefineObjectsWithLockedAttributes.
Procedure OnDefineObjectsWithLockedAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.FileSynchronizationAccounts.FullName(), "");
EndProcedure

// See DuplicateObjectsDetection.TypesToExcludeFromPossibleDuplicates
Procedure OnAddTypesToExcludeFromPossibleDuplicates(TypesToExclude) Export

	CommonClientServer.SupplementArray(
		TypesToExclude, Metadata.DefinedTypes.AttachedFile.Type.Types());
		
	TypesToExclude.Add(Type("CatalogRef.BinaryDataStorage"));

EndProcedure

// Used when exporting files for cloud migration (CTL).
//
// Parameters:
//   FileObject    - CatalogObject
//   NewFileName - String
//
Procedure ExportFile(Val FileObject, Val NewFileName) Export
	
	If FileObject.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		FilesOperationsInVolumesInternal.CopyAttachedFile(FileObject.Ref, NewFileName);
	Else
		FileBinaryData = FilesOperations.FileBinaryData(FileObject.Ref);
		Try
			FileBinaryData.Write(NewFileName);
		Except
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'File data was deleted. The file might have been cleaned up as unused.
					|%1';"), String(FileObject.Ref));
			Raise ErrorMessage;
		EndTry;
	EndIf;
	
EndProcedure

// Used when importing files to go to the service (CTL).
//
// Parameters:
//  FileObject - DefinedType.AttachedFileObject
//  PathToFile - String
//
Procedure ImportFile_(Val FileObject, Val PathToFile) Export
	
	BinaryData = New BinaryData(PathToFile);
	FileStorageType = FileStorageType(FileObject.Size, FileObject.Extension);
	FileObject.FileStorageType = FileStorageType;
	FileObject.PathToFile = "";
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		FilesOperationsInVolumesInternal.AppendFile(FileObject, BinaryData, , True);
	Else
		FileObject.AdditionalProperties.Insert("FileBinaryData", BinaryData);
		FileObject.FileStorage = New ValueStorage(Undefined);
		FileObject.Volume = Catalogs.FileStorageVolumes.EmptyRef();
		FileObject.FileStorageType = Enums.FileStorageTypes.InInfobase;
	EndIf;
	
EndProcedure

// Parameters:
//   Result - Structure
//   AttachedFile - DefinedType.AttachedFileObject
//   FileVersion - CatalogRef.FilesVersions
//
Procedure FillAdditionalFileData(Result, AttachedFile, FileVersion = Undefined) Export
	
	CatalogSupportsPossibitityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", Metadata.FindByType(TypeOf(AttachedFile)));
	
	If CatalogSupportsPossibitityToStoreVersions And ValueIsFilled(AttachedFile.CurrentVersion) Then
		CurrentFileVersion = AttachedFile.CurrentVersion;
	Else
		CurrentFileVersion = AttachedFile.Ref;
	EndIf;
	
	Result.Insert("CurrentVersion", CurrentFileVersion);
	
	If FileVersion <> Undefined Then
		Result.Insert("Version", FileVersion);
	ElsIf CatalogSupportsPossibitityToStoreVersions And ValueIsFilled(AttachedFile.CurrentVersion) Then
		Result.Insert("Version", AttachedFile.CurrentVersion);
	Else
		Result.Insert("Version", AttachedFile.Ref);
	EndIf;
	
	If ValueIsFilled(FileVersion) Then
		CurrentVersionObject = FileVersion.GetObject();
		Result.Insert("VersionNumber", CurrentVersionObject.VersionNumber);
		CurrentFileVersion = FileVersion;
	Else
		Result.Insert("VersionNumber", 0);
		CurrentFileVersion = Result.Version;
		CurrentVersionObject = AttachedFile;
	EndIf;
	
	Result.Insert("Description",                 CurrentVersionObject.Description);
	Result.Insert("Extension",                   CurrentVersionObject.Extension);
	Result.Insert("Size",                       CurrentVersionObject.Size);
	Result.Insert("UniversalModificationDate", CurrentVersionObject.UniversalModificationDate);
	Result.Insert("Volume",                          CurrentVersionObject.Volume);
	Result.Insert("Author",                        CurrentVersionObject.Author);
	Result.Insert("TextExtractionStatus",       CurrentVersionObject.TextExtractionStatus);
	Result.Insert("FullVersionDescription",     TrimAll(CurrentVersionObject.Description));
	
	Result.Insert("CurrentVersionURL", InformationRegisters.FileRepository.FileURL1(CurrentFileVersion));
	
	CurrentVersionEncoding = InformationRegisters.FilesEncoding.FileVersionEncoding(CurrentFileVersion);
	Result.Insert("CurrentVersionEncoding", CurrentVersionEncoding);
	CurrentUser = Users.AuthorizedUser();
	ForReading = Result.BeingEditedBy <> CurrentUser;
	Result.Insert("ForReading", ForReading);
	
	InWorkingDirectoryForRead = True;
	InOwnerWorkingDirectory = False;
	DirectoryName = UserWorkingDirectory();
	
	If ValueIsFilled(CurrentFileVersion) Then
		FullFileNameInWorkingDirectory = FilesOperationsInternalServerCall.FullFileNameInWorkingDirectory(CurrentFileVersion, DirectoryName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
	
		Result.Insert("FullFileNameInWorkingDirectory", FullFileNameInWorkingDirectory);
	EndIf;
	Result.Insert("InWorkingDirectoryForRead", InWorkingDirectoryForRead);
	Result.Insert("OwnerWorkingDirectory", "");
	
	EditedByCurrentUser = (Result.BeingEditedBy = CurrentUser);
	Result.Insert("CurrentUserEditsFile", EditedByCurrentUser);
	
	TextExtractionStatusString = "NotExtracted";
	If Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted Then
		TextExtractionStatusString = "NotExtracted";
	ElsIf Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted Then
		TextExtractionStatusString = "Extracted";
	ElsIf Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.FailedExtraction Then
		TextExtractionStatusString = "FailedExtraction";
	EndIf;
	Result.Insert("TextExtractionStatus", TextExtractionStatusString);
	
	FolderForSaveAs = Common.CommonSettingsStorageLoad("ApplicationSettings", "FolderForSaveAs");
	Result.Insert("FolderForSaveAs", FolderForSaveAs);
	
EndProcedure

// The procedure adds settings specific to the File operations subsystem.
//
// Parameters:
//  CommonSettings        - Structure - settings common for all users.
//  PersonalSettings - Structure - settings different for different users.
//  
Procedure AddFilesOperationsSettings(CommonSettings, PersonalSettings) Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	PersonalSettings.Insert("ActionOnDoubleClick", ActionOnDoubleClick());
	PersonalSettings.Insert("FileVersionsComparisonMethod",  FileVersionsComparisonMethod());
	
	PersonalSettings.Insert("PromptForEditModeOnOpenFile",
		PromptForEditModeOnOpenFile());
	PersonalSettings.Insert("FileOpeningOption", FileOpeningOption());
	
	// Outdated. Use UsersClient.IsFullUser.
	PersonalSettings.Insert("IsFullUser",
		Users.IsFullUser(,, False));
	
	ShowLockedFilesOnExit = Common.CommonSettingsStorageLoad(
		"ApplicationSettings", "ShowLockedFilesOnExit");
	
	If ShowLockedFilesOnExit = Undefined Then
		ShowLockedFilesOnExit = True;
		
		Common.CommonSettingsStorageSave(
			"ApplicationSettings",
			"ShowLockedFilesOnExit",
			ShowLockedFilesOnExit);
	EndIf;
	
	PersonalSettings.Insert("ShowLockedFilesOnExit",
		ShowLockedFilesOnExit);
	
	PersonalSettings.Insert("ShowSizeColumn", ShowSizeColumn());
	
EndProcedure

// Receives all subordinate files.
//
// Parameters:
//   FileOwner - AnyRef - file owner.
//   StoredFilesTable - String - Full name of a file storage table. By default, "Catalog.Files".
//
// Returns:
//   Array of CatalogRef.Files - an array of files.
//
Function GetAllSubordinateFiles(Val FileOwner, Val StoredFilesTable = Undefined) Export

	If StoredFilesTable = Undefined Then
		StoredFilesTable = Metadata.Catalogs.Files.FullName();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Files.Ref AS Ref
	|FROM
	|	&StoredFilesTable AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner";
	
	Query.Text = StrReplace(Query.Text, "&StoredFilesTable", StoredFilesTable);
	
	Query.SetParameter("FileOwner", FileOwner);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Returns True if a file with such extension can be imported.
//
// Parameters:
//  FileExtention - String
//  RaiseException1 - Boolean
// 
// Returns:
//  Boolean
//
Function CheckExtentionOfFileToDownload(FileExtention, RaiseException1 = True) Export
	
	CommonSettings = FilesOperationsInternalCached.FilesOperationSettings().CommonSettings;
	
	If Not CommonSettings.FilesImportByExtensionDenied Then
		Return True;
	EndIf;
	
	If FilesOperationsInternalClientServer.FileExtensionInList(
		CommonSettings.DeniedExtensionsList, FileExtention) Then
		
		If RaiseException1 Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Uploading files with the ""%1"" extension is not allowed.
				           |Please contact the administrator.';"),
				FileExtention);
		Else
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// Returns metadata object types of attachments.
//
// Returns:
//  TypeDescription
//
Function AttachedFilesTypes() Export
	Return Metadata.DefinedTypes.AttachedFile.Type;
EndFunction

// Returns a common module that implements the event handlers:
//    BeforeUpdateFileData;
//    OnUpdateFileData;
//    AfterUpdateFileData.
// 
// The file storage type must be set for the file.
// 
// Parameters:
//  AttachedFile - DefinedType.AttachedFile
// 
// Returns:
//     CommonModule
//
Function FilesManager(AttachedFile) Export
	Return FileManagerByType(AttachedFile.FileStorageType);
EndFunction

// Returns a common module that implements the event handlers:
//    BeforeUpdateFileData;
//    OnUpdateFileData;
//    AfterUpdateFileData.
// 
// Parameters:
//  FileStorageType - EnumRef.FileStorageTypes
// 
// Returns:
//     CommonModule
//
Function FileManagerByType(FileStorageType) Export
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		Return FilesOperationsInVolumesInternal;
	Else
		Return FilesOperationsInternal;
	EndIf;
EndFunction

// File update context.
// Must be initialized when the main data of the file is set or changed.
// 
// Parameters:
//    AttachedFile - DefinedType.AttachedFileObject - a reference or an object of the file.
//                       - DefinedType.AttachedFile
//     FileData - String - AddressInTempStorage
//                 - BinaryData
//    FileRef - DefinedType.AttachedFile - if specified, it will be used as a reference.
//    													  Used when a new file reference is set for a new file. 
//    FileStorageType - See FileManagerByType.
// 
// Returns:
//  Structure - file update context:
//   * AttributesToChange - Structure - attribute values set before saving an attached file.
//   * AttachedFile - See FileUpdateContext.AttachedFile
//   * FileData - See FileUpdateContext.FileData
//   * OldFilePath - String
//   * FileAddingOptions - See FilesOperationsInVolumesInternal.FileAddingOptions
//
Function FileUpdateContext(AttachedFile, FileData, FileRef = Undefined, FileStorageType = Undefined) Export
	Context = New Structure;
	Context.Insert("AttributesToChange", New Structure);
	Context.Insert("OldFilePath", "");
	Context.Insert("FileAddingOptions", FilesOperationsInVolumesInternal.FileAddingOptions());
	Context.Insert("IsNew", False);
	Context.Insert("AttachedFile", Undefined);
	FileParameterType = TypeOf(AttachedFile);
	If Not Common.IsReference(FileParameterType)  Then
		Context.IsNew =  AttachedFile.IsNew();
	EndIf;
	Context.AttachedFile = ?(ValueIsFilled(FileRef), FileRef, AttachedFile.Ref);
	
	FillPropertyValues(Context.FileAddingOptions, AttachedFile);
	Context.FileAddingOptions.FileStorageType = FileStorageType;
	
	If TypeOf(Context.AttachedFile) = Type("CatalogRef.FilesVersions") Then
		Context.FileAddingOptions.FileOwner = AttachedFile.Owner.FileOwner;
	EndIf;
	If TypeOf(FileData) = Type("String") And IsTempStorageURL(FileData) Then
		FileData = GetFromTempStorage(FileData);
	EndIf;
	
	Context.Insert("FileData", FileData);
	Return Context;
EndFunction

// Parameters:
//  Context - See FileUpdateContext
//
Procedure BeforeUpdatingTheFileData(Context) Export
	Return; // Obsolete.
EndProcedure

// Called in a modification transaction after saving an attachment.
// 
// Parameters:
//  Context - See FileUpdateContext
//  AttachedFileObject - DefinedType.AttachedFileObject
//
Procedure BeforeWritingFileData(Context, AttachedFileObject) Export
	Return; // Obsolete.
EndProcedure

// Called in a modification transaction after saving an attachment.
// 
// Parameters:
//  Context - See FileUpdateContext
//  AttachedFile - DefinedType.AttachedFile
//
Procedure WhenUpdatingFileData(Context, AttachedFile) Export
	WriteFileToInfobase(AttachedFile, Context.FileData);
EndProcedure

// Parameters:
//  Context - See FileUpdateContext
//  Success - Boolean - True if the transaction is successfully committed.
//
Procedure AfterUpdatingTheFileData(Context, Success) Export
	Return; // Obsolete.
EndProcedure

// Returns an array of file addresses and detached signatures. 
// 
// Parameters:
//  FilesArray - Array of DefinedType.AttachedFile - a reference to the catalog item with file.
//  FormIdentifier - UUID
// 
// Returns:
//  Array of Structure:
//             * Presentation - String - a file name.
//             * AddressInTempStorage - String
//
Function PutFilesInTempStorage(FilesArray, FormIdentifier) Export
	
	Parameters = New Structure;
	Parameters.Insert("FilesArray", FilesArray);
	Parameters.Insert("FormIdentifier", FormIdentifier);
	
	Return FilesOperationsInternalServerCall.PutFilesInTempStorage(Parameters);
	
EndFunction

// Returns True if it is the metadata item, related to the StoredFiles subsystem.
//
Function IsFilesOperationsItem(DataElement) Export
	
	DataItemType = TypeOf(DataElement);
	If DataItemType = Type("ObjectDeletion") Then
		Return False;
	EndIf;
	
	ItemMetadata = DataElement.Metadata();
	
	Return Common.IsCatalog(ItemMetadata)
		And (Metadata.DefinedTypes.AttachedFileObject.Type.ContainsType(DataItemType)
			Or (Metadata.DefinedTypes.AttachedFile.Type.ContainsType(DataItemType)));
	
EndFunction

// 
// Returns:
//  String - Suffix of the "Attachments" catalog
//
Function CatalogSuffixAttachedFiles() Export
	Return "AttachedFiles";
EndFunction

#Region DataExchangeProcedures

// Returns the array of catalogs that own files.
//
// Returns:
//   Array of MetadataObject
//
Function FilesCatalogs() Export
	
	Result = New Array();
	
	MetadataCollections = New Array();
	MetadataCollections.Add(Metadata.Catalogs);
	MetadataCollections.Add(Metadata.Documents);
	MetadataCollections.Add(Metadata.BusinessProcesses);
	MetadataCollections.Add(Metadata.Tasks);
	MetadataCollections.Add(Metadata.ChartsOfAccounts);
	MetadataCollections.Add(Metadata.ExchangePlans);
	MetadataCollections.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollections.Add(Metadata.ChartsOfCalculationTypes);
	
	For Each MetadataCollection In MetadataCollections Do
		
		For Each MetadataObject In MetadataCollection Do
			
			ObjectManager = Common.ObjectManagerByFullName(MetadataObject.FullName());
			EmptyRef = ObjectManager.EmptyRef();
			FileStorageCatalogNames = FileStorageCatalogNames(EmptyRef, True);
			
			For Each FileStoringCatalogName In FileStorageCatalogNames Do
				Result.Add(Metadata.Catalogs[FileStoringCatalogName.Key]);
			EndDo;
			
		EndDo;
		
	EndDo;
	
	Result.Add(Metadata.Catalogs.FilesVersions);
	
	Return Result;
	
EndFunction

// Returns an array of metadata objects used for storing
// binary file data in the infobase.
//
// Returns:
//   Array of MetadataObject
//
Function InfobaseFileStoredObjects() Export
	
	Result = New Array();
	Result.Add(Metadata.InformationRegisters.FileRepository);
	Result.Add(Metadata.Catalogs.BinaryDataStorage);
	Return Result;
	
EndFunction

// Returns a file extension.
//
// Parameters:
//  Object - DefinedType.AttachedFileObject
// 
// Returns:
//   String
//
Function FileExtention(Object) Export
	
	Return Object.Extension;
	
EndFunction

// Returns objects that have attachments (using the "File operations" subsystem).
//
// Used together with the AttachedFiles.ConvertFilesInAttached() function.
//
// Parameters:
//  FilesOwnersTable - String - a full name of metadata object
//                            that can own attached files.
//  StoredFilesTable - String - Full name of the metadata object containing attachments.
//                                   By default, "Catalog.Files".
//
// Returns:
//   Array
//
Function ReferencesToObjectsWithFiles(Val FilesOwnersTable, Val StoredFilesTable = Undefined) Export
	
	If StoredFilesTable = Undefined Then
		StoredFilesTable = Metadata.Catalogs.Files.FullName();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ObjectsWithFiles.Ref AS Ref
	|FROM
	|	&Table AS ObjectsWithFiles
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				&StoredFilesTable AS Files
	|			WHERE
	|				Files.FileOwner = ObjectsWithFiles.Ref)";
	
	Query.Text = StrReplace(Query.Text, "&StoredFilesTable", StoredFilesTable);
	Query.Text = StrReplace(Query.Text, "&Table", FilesOwnersTable);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Checks the the current user right
// when using the limit for a folder or file.
//
// Parameters:
//   Folder - CatalogRef.FilesFolders
//         - CatalogRef.Files - file folder.
//         - CatalogRef - file owner.
//
Function RightToAddFilesToFolder(Folder) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		Return ModuleAccessManagement.HasRight("AddFilesAllowed", Folder);
	EndIf;
	
	Return True;
	
EndFunction

// Writes attachments to a folder.
//
// Parameters:
//   DeliveryParameters - Structure:
//     * Folder - CatalogRef.FilesFolders
//     * BulkEmail - AnyRef
//     * ExecutionDate - Date
//     * AddReferences - String
//     * RecipientReportsPresentation - String
//   Attachments - Map of KeyAndValue:
//     * Key - String
//     * Value - String 
//
Procedure OnExecuteDeliveryToFolder(DeliveryParameters, Attachments) Export
	
	// Transfer attachments to the table
	SetPrivilegedMode(True);
	
	AttachmentsTable = New ValueTable;
	AttachmentsTable.Columns.Add("FileName",              New TypeDescription("String"));
	AttachmentsTable.Columns.Add("FullFilePath",      New TypeDescription("String"));
	AttachmentsTable.Columns.Add("File",                  New TypeDescription("File"));
	AttachmentsTable.Columns.Add("FileRef",            New TypeDescription("CatalogRef.Files"));
	AttachmentsTable.Columns.Add("FileNameWithoutExtension", New TypeDescription("String"));
	
	SetPrivilegedMode(False);
	
	For Each Attachment In Attachments Do
		TableRow = AttachmentsTable.Add();
		TableRow.FileName              = Attachment.Key;
		TableRow.FullFilePath      = Attachment.Value;
		TableRow.File                  = New File(TableRow.FullFilePath);
		TableRow.FileNameWithoutExtension = TableRow.File.BaseName;
	EndDo;
	
	// Search the existing files.
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	Files.Ref,
	|	Files.Description
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner
	|	AND Files.Description IN(&FileNamesArray)";
	
	Query.SetParameter("FileOwner", DeliveryParameters.Folder);
	Query.SetParameter("FileNamesArray", AttachmentsTable.UnloadColumn("FileNameWithoutExtension"));
	
	ExistingFiles = Query.Execute().Unload();
	For Each File In ExistingFiles Do
		TableRow = AttachmentsTable.Find(File.Description, "FileNameWithoutExtension");
		TableRow.FileRef = File.Ref;
	EndDo;
	
	Comment = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Report distribution ""%1"", %2';"),
		DeliveryParameters.BulkEmail,
		Format(DeliveryParameters.ExecutionDate, "DLF=DT"));
	
	For Each Attachment In AttachmentsTable Do
		
		FileInfo1 = FilesOperationsClientServer.FileInfo1("FileWithVersion", Attachment.File);
		FileInfo1.TempFileStorageAddress = PutToTempStorage(New BinaryData(Attachment.FullFilePath));
		FileInfo1.BaseName = Attachment.FileNameWithoutExtension;
		FileInfo1.Comment = Comment;
		
		If ValueIsFilled(Attachment.FileRef) Then
			VersionRef = CreateVersion(Attachment.FileRef, FileInfo1); // @skip-check query-in-loop - Writing data object-by-object.
			UpdateVersionInFile(Attachment.FileRef, VersionRef, FileInfo1.TempTextStorageAddress);
		Else
			Attachment.FileRef = FilesOperationsInternalServerCall.CreateFileWithVersion(DeliveryParameters.Folder, FileInfo1); 
		EndIf;
		
		If DeliveryParameters.AddReferences <> "" Then
			DeliveryParameters.RecipientReportsPresentation = StrReplace(
				DeliveryParameters.RecipientReportsPresentation,
				Attachment.FullFilePath,
				GetInfoBaseURL() + "#" + GetURL(Attachment.FileRef));
		EndIf;
		
		DeleteFromTempStorage(FileInfo1.TempFileStorageAddress);
	EndDo;
	
EndProcedure

// Sets a deletion mark for all versions of the specified file.
Procedure MarkForDeletionFileVersions(Val FileRef, Val VersionException) Export
	
	Query = New Query(
		"SELECT
		|	FilesVersions.Ref AS Ref
		|FROM
		|	Catalog.FilesVersions AS FilesVersions
		|WHERE
		|	FilesVersions.Owner = &Owner
		|	AND NOT FilesVersions.DeletionMark
		|	AND FilesVersions.Ref <> &Exception");
	Query.SetParameter("Owner", FileRef);
	Query.SetParameter("Exception", VersionException);
	
	VersionsSelection = Query.Execute().Unload();
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("Catalog.FilesVersions");
		LockItem.SetValue("Owner", FileRef);
		Block.Lock();
		
		For Each Version In VersionsSelection Do
			VersionObject = Version.Ref.GetObject();
			VersionObject.DeletionMark = True;
			VersionObject.AdditionalProperties.Insert("FileConversion", True);
			VersionObject.Write();
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Returns the map of catalog names and Boolean values for the specified owner.
// 
// Parameters:
//  FilesOwner - AnyRef - an object for adding the file.
// 
// Returns:
//   Map of KeyAndValue:
//      * Key - String
//      * Value - Boolean
//
Function FileStorageCatalogNames(FilesOwner, NotRaiseException1 = False) Export
	
	If TypeOf(FilesOwner) = Type("Type") Then
		FilesOwnerType = FilesOwner;
	Else
		FilesOwnerType = TypeOf(FilesOwner);
	EndIf;
	
	CatalogSuffix = CatalogSuffixAttachedFiles();
	
	OwnerMetadata = Metadata.FindByType(FilesOwnerType);
	CatalogNames = New Map;
	If OwnerMetadata <> Undefined Then
		StandardMainCatalogName = OwnerMetadata.Name
			+ ?(StrEndsWith(OwnerMetadata.Name, CatalogSuffix), "", CatalogSuffix);
			
		If Metadata.Catalogs.Find(StandardMainCatalogName) <> Undefined Then
			CatalogNames.Insert(StandardMainCatalogName, True);
		EndIf;
		
		If Metadata.DefinedTypes.FilesOwner.Type.ContainsType(FilesOwnerType) Then
			CatalogNames.Insert(Metadata.Catalogs.Files.Name, CatalogNames.Count() = 0);
		EndIf;
		
		// Redefining the default catalog for attachment storage.
		FilesOperationsOverridable.OnDefineFileStorageCatalogs(
			FilesOwnerType, CatalogNames);
	EndIf;
	
	DefaultCatalogIsSpecified = False;
	Errors = New Array;
	Errors.Add(NStr("en = 'An error occurred when determining names of file storage catalogs.';"));
	
	For Each KeyAndValue In CatalogNames Do
		
		If Metadata.Catalogs.Find(KeyAndValue.Key) = Undefined Then
			
			Errors.Add(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'File location of type ""%1""
					|contains the catalog ""%2"" that does not exist.';"),
				String(FilesOwnerType), String(KeyAndValue.Key)));
				
		ElsIf Not StrEndsWith(KeyAndValue.Key, CatalogSuffix) And Not KeyAndValue.Key ="Files" Then
			
			Errors.Add(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'File location of type ""%1""
					|contains a name of catalog ""%2""
					|without the required postfix ""%3"".';"),
				String(FilesOwnerType), String(KeyAndValue.Key), CatalogSuffix));
			
		ElsIf KeyAndValue.Value = Undefined Then
			CatalogNames.Insert(KeyAndValue.Key, False);
			
		ElsIf KeyAndValue.Value = True Then
			If DefaultCatalogIsSpecified Then
				Errors.Add(StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'File location of type ""%1""
						|contains more than one main catalog.';"),
					String(FilesOwnerType), String(KeyAndValue.Key)));
			EndIf;
			DefaultCatalogIsSpecified = True;
		EndIf;
	EndDo;
	
	If CatalogNames.Count() = 0 Then
		
		If NotRaiseException1 Then
			Return CatalogNames;
		EndIf;
		
		Errors.Add(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'File location of type ""%1""
				|does not have file storage catalogs.';"),
			String(FilesOwnerType)));
		Raise StrConcat(Errors, Chars.LF + Chars.LF);
	EndIf;
	
	If Errors.Count() > 1 Then
		Raise StrConcat(Errors, Chars.LF + Chars.LF);
	EndIf; 
	
	Return CatalogNames;
	
EndFunction

// Creates copies of all Source attachments for the Recipient.
// Source and Recipient must be objects of the same type.
//
// Parameters:
//  Source   - AnyRef - a source object with attached files.
//  Recipient - AnyRef - an object, to which the attached files are copied to.
//
Procedure CopyAttachedFiles(Val Source, Val Recipient) Export
	
	DigitalSignatureAvailable = Undefined;
	ModuleDigitalSignatureInternal = Undefined;
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
	EndIf;
	
	CopiedFiles = AttachedFilesToObject(Source, True);
	For Each CopyFiles In CopiedFiles Do
		If DigitalSignatureAvailable = Undefined Then
			DigitalSignatureAvailable = (ModuleDigitalSignatureInternal <> Undefined) 
				And (ModuleDigitalSignatureInternal.DigitalSignatureAvailable(TypeOf(CopyFiles)));
		EndIf;
		
		BeginTransaction();
		Try
			ObjectManager = Common.ObjectManagerByRef(CopyFiles);
			FileCopy = CopyFiles.Copy();
			FileCopyRef = ObjectManager.GetRef();
			FileCopy.SetNewObjectRef(FileCopyRef);
			FileCopy.FileOwner = Recipient;
			FileCopy.BeingEditedBy = Catalogs.Users.EmptyRef();
			
			FileCopy.TextStorage = CopyFiles.TextStorage;
			FileCopy.TextExtractionStatus = CopyFiles.TextExtractionStatus;
			FileCopy.FileStorage = CopyFiles.FileStorage;
			
			BinaryData = FilesOperations.FileBinaryData(CopyFiles);
			
			FileStorageType = FileStorageType(FileCopy.Size, FileCopy.Extension);
			If FileStorageType = Enums.FileStorageTypes.InInfobase Then
				FileCopy.FileStorageType = FileStorageType;
				WriteFileToInfobase(FileCopyRef, BinaryData);
			Else
				FileCopy.Volume = Undefined;
				FileCopy.PathToFile = Undefined;
				FileCopy.FileStorageType = Undefined;
				FilesOperationsInVolumesInternal.AppendFile(FileCopy, BinaryData);
			EndIf;
			FileCopy.Write();
			
			If DigitalSignatureAvailable Then
				SetSignatures = ModuleDigitalSignature.SetSignatures(CopyFiles);
				ModuleDigitalSignature.AddSignature(FileCopy.Ref, SetSignatures);
				
				SourceCertificates = ModuleDigitalSignature.EncryptionCertificates(CopyFiles);
				ModuleDigitalSignature.WriteEncryptionCertificates(FileCopy, SourceCertificates);
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
	
EndProcedure

// Returns file object structure.
//
Function FileObject1(Val AttachedFile) Export
	
	FileObject1 = Undefined;
	FileObjectMetadata = Metadata.FindByType(TypeOf(AttachedFile));
	
	// This is a file catalog.
	If Common.HasObjectAttribute("FileOwner", FileObjectMetadata) Then
		ThereIsACurrentVersion = False;
		If Common.HasObjectAttribute("CurrentVersion", FileObjectMetadata) Then
			CurrentVersion = Common.ObjectAttributeValue(AttachedFile, "CurrentVersion"); 
			ThereIsACurrentVersion = ValueIsFilled(CurrentVersion); 
		EndIf;	
		If ThereIsACurrentVersion Then // Version tracking is enabled.
			AttributesNames = "Ref,FileStorageType,Description,Extension,Volume,PathToFile,DeletionMark";
			If FileObjectMetadata.Hierarchical Then
				AttributesNames = AttributesNames + "," + "IsFolder";
			EndIf;
			FileObject1 = Common.ObjectAttributesValues(CurrentVersion, AttributesNames);
			FileObject1.Insert("FileOwner", Common.ObjectAttributeValue(AttachedFile, "FileOwner"));
			If Not FileObjectMetadata.Hierarchical Then
				FileObject1.Insert("IsFolder", False);
			EndIf;
		Else // Version tracking is disabled.
			AttributesNames = "Ref,FileStorageType,FileOwner,Description,Extension,Volume,PathToFile,DeletionMark"; 
			If FileObjectMetadata.Hierarchical Then
				AttributesNames = AttributesNames + "," + "IsFolder";
			EndIf;
			FileObject1 = Common.ObjectAttributesValues(AttachedFile, AttributesNames);
			If Not FileObjectMetadata.Hierarchical Then
				FileObject1.Insert("IsFolder", False);
			EndIf;
		EndIf;
	// This is a catalog of file versions.
	ElsIf Common.HasObjectAttribute("ParentVersion", FileObjectMetadata) Then
		FileObject1 = Common.ObjectAttributesValues(AttachedFile, 
			"Ref,FileStorageType,Description,Extension,Volume,PathToFile,Owner,DeletionMark");
		FileObject1.Insert("FileOwner",
			Common.ObjectAttributeValue(FileObject1.Owner, "FileOwner"));
		FileObject1.Delete("Owner");
		FileObject1.Insert("IsFolder", False);
	EndIf;
	
	Return FileObject1;
	
EndFunction

#EndRegion

#Region CleanUpUnusedFiles

Function FullFilesVolumeQueryText() Export
	MetadataCatalogs = Metadata.Catalogs;
	AddFieldAlias = True;
	QueryText = "";
	For Each Catalog In MetadataCatalogs Do
		If Catalog.Attributes.Find("FileOwner") <> Undefined Then
			
			HasAbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", Catalog);
			If HasAbilityToStoreVersions Then
				AttributeType = Catalog.Attributes.CurrentVersion.Type.Types()[0];
				FullAttributeName = Metadata.FindByType(AttributeType).FullName();
				FullFilesVersionsCatalogName = FullAttributeName;
				
				PartOfTheRequestText = "
					|SELECT
					|	VALUETYPE(Files.FileOwner) AS FileOwner,
					|	SUM(ISNULL(FilesVersions.Size, Files.Size) / 1024 / 1024) AS TotalFileSize
					|FROM
					|	#CatalogName AS Files
					|		LEFT JOIN #FullFilesVersionsCatalogName AS FilesVersions
					|		ON Files.Ref = FilesVersions.Owner
					|WHERE
					|	NOT Files.DeletionMark
					|	AND NOT ISNULL(FilesVersions.DeletionMark, FALSE)
					|
					|GROUP BY
					|	VALUETYPE(Files.FileOwner)";
				
				PartOfTheRequestText = StrReplace(PartOfTheRequestText, "#CatalogName", "Catalog." + Catalog.Name);
				PartOfTheRequestText = StrReplace(PartOfTheRequestText, "#FullFilesVersionsCatalogName",
					FullFilesVersionsCatalogName);
				
				QueryText = QueryText + ?(IsBlankString(QueryText),"", " UNION ALL ") + PartOfTheRequestText;
				
				If AddFieldAlias Then
					AddFieldAlias = False;
				EndIf;
			Else
				QueryText = QueryText + ?(IsBlankString(QueryText),"", " UNION ALL") + "
					|
					|SELECT
					|	VALUETYPE(Files.FileOwner) " + ?(AddFieldAlias, "AS FileOwner,",",") + "
					|	Files.Size / 1024 / 1024 " + ?(AddFieldAlias, "AS TotalFileSize","") + "
					|FROM
					|	Catalog." + Catalog.Name + " AS Files
					|WHERE
					|	NOT Files.DeletionMark";
				
				If AddFieldAlias Then
					AddFieldAlias = False;
				EndIf;
			EndIf;
				
		EndIf;
	EndDo;
	
	Return QueryText;
	
EndFunction

#EndRegion

#Region FilesVolumesOperations

// Returns the file storage option including volume storage.
// If volume storage is not used, then returns storage in the infobase.
//
// Returns:
//   EnumRef.FileStorageTypes
//
Function FilesStorageTyoe() Export
	
	If FilesOperationsInVolumesInternal.StoreFilesInVolumesOnHardDrive()
		And FilesOperationsInVolumesInternal.HasFileStorageVolumes() Then
		Return Enums.FileStorageTypes.InVolumesOnHardDrive;
	Else
		Return Enums.FileStorageTypes.InInfobase;
	EndIf;

EndFunction

// Returns the file storage option including volumes and mix-type storage.
// If volume storage is not used, then returns storage in the infobase.
//
// Parameters:
//  FileSize - Number
//  FileExtention - String 
//
// Returns:
//   EnumRef.FileStorageTypes
//
Function FileStorageType(Val FileSize, Val FileExtention) Export
	
	If FilesOperationsInVolumesInternal.StoreFilesInVolumesOnHardDrive()
		And FilesOperationsInVolumesInternal.HasFileStorageVolumes() Then
		Return FilesOperationsInVolumesInternal.FileStorageType(FileSize, FileExtention);
	Else
		Return Enums.FileStorageTypes.InInfobase;
	EndIf;

EndFunction

// Checks whether there is at least one file in one of the volumes.
//
// Returns:
//  Boolean
//
Function HasFilesInVolumes() Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	FilesInfo.File AS File
	|FROM
	|	InformationRegister.FilesInfo AS FilesInfo
	|WHERE
	|	FilesInfo.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#EndRegion

#Region AccessManagement

Function IsFilesOrFilesVersionsCatalog(FullName) Export
	
	NameParts = StrSplit(FullName, ".", False);
	If NameParts.Count() <> 2 Then
		Return False;
	EndIf;
	
	If Upper(NameParts[0]) <> Upper("Catalog")
	   And Upper(NameParts[0]) <> Upper("Catalog") Then
		Return False;
	EndIf;
	
	If StrEndsWith(Upper(NameParts[1]), Upper(CatalogSuffixAttachedFiles()))
	 Or Upper(NameParts[1]) = Upper("Files")
	 Or Upper(NameParts[1]) = Upper("FilesVersions") Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

#EndRegion

#Region DigitalSignatureAndEncryption

Function DigitalSignatureAvailable(FileType) Export
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		Return ModuleDigitalSignatureInternal.DigitalSignatureAvailable(FileType);
	EndIf;
	
	Return False;
	
EndFunction

// Controls the visibility of items and commands depending on the availability and
// use of digital signature and encryption.
// 
// Parameters:
//   Form - ClientApplicationForm
//   IsListForm - Boolean
//   RowsPictureOnly - Boolean
//
Procedure CryptographyOnCreateFormAtServer(Form, IsListForm = True, RowsPictureOnly = False) Export
	
	Items = Form.Items;
	
	Signing = False;
	Encryption = False;
	ViewEncrypted = False;
	AvailableAdvancedSignature = False;
	GuideVisibility = False;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
	
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		If ModuleDigitalSignatureInternal.InteractiveUseofElectronicSignaturesandEncryption() Then
			ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
			Signing            = ModuleDigitalSignature.AddEditDigitalSignatures();
			Encryption            = ModuleDigitalSignature.EncryptAndDecryptData();
			ViewEncrypted = ModuleDigitalSignature.DataDecryption();
			AvailableAdvancedSignature = ModuleDigitalSignature.AvailableAdvancedSignature();
			GuideVisibility = ModuleDigitalSignatureInternal.VisibilityOfRefToAppsTroubleshootingGuide();
		EndIf;
		
	EndIf;
	
	If IsListForm Then
		If Common.IsCatalog(Common.MetadataObjectByFullName(Form.List.MainTable)) Then
			TableOfFiles = Common.ObjectManagerByFullName(Form.List.MainTable);
			DigitalSignatureAvailable = DigitalSignatureAvailable(TypeOf(TableOfFiles.EmptyRef()));
		Else
			DigitalSignatureAvailable = True;
		EndIf;
	Else
		DigitalSignatureAvailable = DigitalSignatureAvailable(TypeOf(Form.Object.Ref));
	EndIf;
	
	If Not RowsPictureOnly Then
		
		Items.FormDigitalSignatureAndEncryptionCommandsGroup.Visible = DigitalSignatureAvailable;
		
		Items.FormSign.Visible = Signing;
		Items.FormAddSignatureFromFile.Visible = Signing;
		Items.FormEncrypt.Visible = Encryption;
		Items.FormDecrypt.Visible = ViewEncrypted;
		
		If IsListForm Then
			
			Items.ListContextMenuSign.Visible = Signing;
			Items.ListContextMenuAddSignatureFromFile.Visible = Signing;
			Items.ListContextMenuEncrypt.Visible = Encryption;
			Items.ListContextMenuDigitalSignatureAndEncryptionCommandsGroup.Visible = DigitalSignatureAvailable;
			
		Else
			Items.DigitalSignaturesExtendActionSignatures.Visible = Signing And AvailableAdvancedSignature;
			Items.DigitalSignatures.ChangeRowSet = Signing;
			Items.DigitalSignaturesSign.Visible = Signing;
			Items.DigitalSignaturesDelete.Visible = Signing;
			Items.DigitalSignaturesGroup.Visible = DigitalSignatureAvailable;
			Items.EncryptionCertificatesGroup.Visible = ViewEncrypted And DigitalSignatureAvailable;
			Items.Instruction.Visible = Signing And GuideVisibility;
			Items.FormSaveWithSignature.Visible = Form.DigitalSignatures.Count() <> 0;
		EndIf;
	EndIf;
	
	If IsListForm Then
		Items.ListSignedEncryptedPictureNumber.Visible = DigitalSignatureAvailable;
	EndIf;

	If Not DigitalSignatureAvailable Then
		Return;
	EndIf;
	
	If Not RowsPictureOnly Then
		Items.FormEncryptionCommandsGroup.Visible = ViewEncrypted;
		If IsListForm Then
			Items.ListContextMenuEncryptionCommandsGroup.Visible = ViewEncrypted;
		EndIf;
	EndIf;
	
	If ViewEncrypted Then
		Title = NStr("en = 'Digital signature and encryption';");
		ToolTip = NStr("en = 'Digital signature or encryption available.';");
		Picture  = PictureLib["SignedEncryptedTitle"];
	Else
		Title = NStr("en = 'Digital signature';");
		ToolTip = NStr("en = 'Digital signature available.';");
		Picture  = PictureLib["SignedWithDS"];
	EndIf;
	
	If IsListForm Then
		Items.ListSignedEncryptedPictureNumber.HeaderPicture = Picture;
		Items.ListSignedEncryptedPictureNumber.ToolTip = ToolTip;
	EndIf;
	
	If Not RowsPictureOnly Then
		
		DSCommandsGroup = Items.FormDigitalSignatureAndEncryptionCommandsGroup; //FormGroup
		DSCommandsGroup.Title = Title;
		DSCommandsGroup.ToolTip = Title;
		DSCommandsGroup.Picture  = Picture;
		
		If IsListForm Then
			
			DSListCommand = Items.ListContextMenuDigitalSignatureAndEncryptionCommandsGroup; // FormButton
			DSListCommand.Title = Title;
			DSListCommand.ToolTip = Title;
			DSListCommand.Picture  = Picture;
			
		EndIf;
		
	EndIf;
	
	ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
	ModuleDigitalSignatureInternal.RegisterSignaturesList(Form, "DigitalSignatures");
	
EndProcedure

// For internal use only.
//
// Parameters:
//   SignaturesInForm - ValueTable
//
Procedure MoveSignaturesCheckResults(SignaturesInForm, SignedFile) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
		
	ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
	If Not ModuleDigitalSignatureInternal.DigitalSignatureAvailable(TypeOf(SignedFile)) Then
		Return;
	EndIf;
		
	ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
	SignaturesInObject = ModuleDigitalSignature.SetSignatures(SignedFile, Undefined, True);
	
	If SignaturesInForm.Count() <> SignaturesInObject.Count() Then
		Return; // If the object was changed, the test results are not transferred.
	EndIf;
	
	If SignaturesInForm.Count() = 0 Then
		Return;
	EndIf;
		
	Properties = New Structure("SignatureValidationDate, SignatureCorrect, IsVerificationRequired", Null, Null, Null);
	Properties.Insert("SignatureType", Null);
	Properties.Insert("DateActionLastTimestamp", Null);
	Properties.Insert("ResultOfSignatureVerificationByMRLOA", Null);
	Properties.Insert("CheckResult", Null);
	
	FillPropertyValues(Properties, SignaturesInForm[0]);
	If Properties.SignatureValidationDate = Null
	 Or Properties.SignatureCorrect = Null Then
		Return; // If the form does not have check attributes, the check results are not transferred.
	EndIf;
	
	If Properties.IsVerificationRequired = Null Then
		Properties.Delete("IsVerificationRequired");
	EndIf;
	If Properties.SignatureType = Null Then
		Properties.Delete("SignatureType");
	EndIf;
	If Properties.DateActionLastTimestamp = Null Then
		Properties.Delete("DateActionLastTimestamp");
	EndIf;
	If Properties.ResultOfSignatureVerificationByMRLOA = Null Then
		Properties.Delete("ResultOfSignatureVerificationByMRLOA");
	EndIf;
	If Properties.CheckResult = Null Then
		HasCheckResult = False;
		Properties.Delete("CheckResult");
	Else
		HasCheckResult = True;
	EndIf;
	
	For Each Signature In SignaturesInForm Do
		SignatureInObject = SignaturesInObject.Get(SignaturesInForm.IndexOf(Signature));
		If Signature.SignatureDate         <> SignatureInObject.SignatureDate
		 Or Signature.Comment         <> SignatureInObject.Comment
		 Or Signature.CertificateOwner <> SignatureInObject.CertificateOwner And ValueIsFilled(SignatureInObject.CertificateOwner)
		 Or Signature.Thumbprint           <> SignatureInObject.Thumbprint And ValueIsFilled(SignatureInObject.Thumbprint)
		 Or Signature.SignatureSetBy <> SignatureInObject.SignatureSetBy Then
			Return; // If the object was changed, the test results are not transferred.
		EndIf;
	EndDo;
	
	Properties.Insert("Thumbprint");
	Properties.Insert("CertificateOwner");
	
	For Each Signature In SignaturesInForm Do
		SignatureInObject = SignaturesInObject.Get(SignaturesInForm.IndexOf(Signature));
		FillPropertyValues(Properties, SignatureInObject);
		HasChanges = False;
		For Each KeyAndValue In Properties Do
			
			
			If Signature[KeyAndValue.Key] <> Properties[KeyAndValue.Key] Then
				HasChanges = True;
			EndIf;
		EndDo;
		
		If Not HasChanges Then
			Continue; // Do not set the modification if the test results match.
		EndIf;
		
		FillPropertyValues(Properties, Signature);
		FillPropertyValues(SignatureInObject, Properties);
		If HasCheckResult And ValueIsFilled(Signature.CheckResult) Then
			FillPropertyValues(SignatureInObject, Signature.CheckResult);
		EndIf;
		ModuleDigitalSignature.UpdateSignature(SignedFile, SignatureInObject);
	EndDo;
	
EndProcedure

// Parameters to record information about encryption.
// 
// Returns:
//  Structure - parameters to record information about encryption:
//   * Encrypt - Boolean - True (by default) - encrypt a file, False - decrypt a file.
//   * DataArrayToStoreInDatabase - Array of Structure
//   * UUID - UUID - a form UUID.
//   * WorkingDirectoryName - String - a working directory.
//   * FilesArrayInWorkingDirectoryToDelete - Array - files to delete from the register.
//   * ThumbprintsArray - Array - an array of certificate thumbprints used for encryption.
//   * FileInfo1 - See FilesOperationsClientServer.FileInfo1
//
Function EncryptionInformationWriteParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("Encrypt", True);
	Parameters.Insert("DataArrayToStoreInDatabase", New Array);
	Parameters.Insert("UUID", Undefined);
	Parameters.Insert("WorkingDirectoryName", "");
	Parameters.Insert("FilesArrayInWorkingDirectoryToDelete", New Array);
	Parameters.Insert("ThumbprintsArray", New Array);
	Parameters.Insert("FileInfo1", Undefined);
	
	Return Parameters;
	
EndFunction

// Places the encrypted files in the database and checks the Encrypted flag to the file and all its versions.
//
// Parameters:
//  FileRef - CatalogRef.Files - a file.
//  EncryptionInformationWriteParameters - See EncryptionInformationWriteParameters
//
Procedure WriteEncryptionInformation(FileRef, EncryptionInformationWriteParameters) Export
	
	ObjectMetadata = FileRef.Metadata();
	If Common.HasObjectAttribute("CurrentVersion", ObjectMetadata) Then
		CurrentFileVersion = CurrentVersion(FileRef);
	EndIf;
	
	CurrentVersionTextTempStorageAddress = "";
	MainFileTempStorageAddress      = "";
	
	BeginTransaction();
	Try
		
		For Each DataToWriteAtServer In EncryptionInformationWriteParameters.DataArrayToStoreInDatabase Do
			
			If TypeOf(DataToWriteAtServer.VersionRef) <> Type("CatalogRef.FilesVersions") Then
				MainFileTempStorageAddress = DataToWriteAtServer.TempStorageAddress;
				Continue;
			EndIf;
			
			TempStorageAddress = DataToWriteAtServer.TempStorageAddress;
			VersionRef = DataToWriteAtServer.VersionRef; // CatalogRef.FilesVersions
			TempTextStorageAddress = DataToWriteAtServer.TempTextStorageAddress;
			
			If VersionRef = CurrentFileVersion Then
				CurrentVersionTextTempStorageAddress = TempTextStorageAddress;
			EndIf;
			
			FullFileNameInWorkingDirectory = "";
			If ValueIsFilled(EncryptionInformationWriteParameters.WorkingDirectoryName) Then
				InWorkingDirectoryForRead = True; // Obsolete. 
				InOwnerWorkingDirectory = True;
				FullFileNameInWorkingDirectory = FilesOperationsInternalServerCall.FullFileNameInWorkingDirectory(VersionRef, 
				EncryptionInformationWriteParameters.WorkingDirectoryName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
			EndIf;
			
			If Not IsBlankString(FullFileNameInWorkingDirectory) Then
				EncryptionInformationWriteParameters.FilesArrayInWorkingDirectoryToDelete.Add(FullFileNameInWorkingDirectory);
			EndIf;
			
			FilesOperationsInternalServerCall.DeleteFromRegister(VersionRef);
			
			If EncryptionInformationWriteParameters.FileInfo1 = Undefined Then
				
				VersionAttributes = Common.ObjectAttributesValues(VersionRef, "Description, Comment,
					|Extension, CreationDate, UniversalModificationDate, Size");
				
				FileInfo1 = FilesOperationsClientServer.FileInfo1("FileWithVersion");
				FileInfo1.BaseName = VersionAttributes.Description;
				FileInfo1.Comment = VersionAttributes.Comment;
				FileInfo1.TempFileStorageAddress = TempStorageAddress;
				FileInfo1.ExtensionWithoutPoint = VersionAttributes.Extension;
				FileInfo1.Modified = VersionAttributes.CreationDate;
				FileInfo1.ModificationTimeUniversal = VersionAttributes.UniversalModificationDate;
				FileInfo1.Size = VersionAttributes.Size;
				FileInfo1.NewTextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
				FileInfo1.Encrypted = EncryptionInformationWriteParameters.Encrypt;
				FileInfo1.StoreVersions = False;
			Else
				FileInfo1 = EncryptionInformationWriteParameters.FileInfo1;
			EndIf;
			
			// @skip-check query-in-loop - Save data object-by-object.
			UpdateFileVersion(FileRef, FileInfo1, VersionRef, EncryptionInformationWriteParameters.UUID);
			
			// For the option of storing files in volumes, delete the File from the temporary storage after receiving it.
			If Not IsBlankString(DataToWriteAtServer.FileAddress) And IsTempStorageURL(DataToWriteAtServer.FileAddress) Then
				DeleteFromTempStorage(DataToWriteAtServer.FileAddress);
			EndIf;
			
		EndDo;
		
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(FileRef)).FullName());
		DataLockItem.SetValue("Ref", FileRef);
		DataLock.Lock();
		
		FileObject1 = FileRef.GetObject();
		LockDataForEdit(FileRef, , EncryptionInformationWriteParameters.UUID);
		
		FileObject1.Encrypted = EncryptionInformationWriteParameters.Encrypt;
		FileObject1.TextStorage = New ValueStorage("");
		FileObject1.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		
		// To write a previously signed object.
		FileObject1.AdditionalProperties.Insert("WriteSignedObject", True);
		
		If EncryptionInformationWriteParameters.Encrypt Then
			If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
				ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
				ModuleDigitalSignatureInternal.AddEncryptionCertificates(FileRef, EncryptionInformationWriteParameters.ThumbprintsArray);
			EndIf;
		Else
			If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
				ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
				ModuleDigitalSignatureInternal.ClearEncryptionCertificates(FileRef);
			EndIf;
		EndIf;
		
		FileMetadata = Metadata.FindByType(TypeOf(FileRef));
		FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
		
		If Not EncryptionInformationWriteParameters.Encrypt And CurrentVersionTextTempStorageAddress <> "" Then
			
			If FileMetadata.FullTextSearch = FullTextSearchUsing Then
				TextExtractionResult = ExtractText1(CurrentVersionTextTempStorageAddress);
				FileObject1.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
				FileObject1.TextStorage = TextExtractionResult.TextStorage;
			Else
				FileObject1.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
				FileObject1.TextStorage = New ValueStorage("");
			EndIf;
			
		EndIf;
		
		FileMetadata = Metadata.FindByType(TypeOf(FileRef));
		AbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", FileMetadata);
		If Not FileObject1.StoreVersions Or (AbilityToStoreVersions And Not ValueIsFilled(CurrentFileVersion)) Then
			UpdateFileBinaryDataAtServer(FileObject1, MainFileTempStorageAddress);
		EndIf;
		
		FileObject1.Write();
		UnlockDataForEdit(FileRef, EncryptionInformationWriteParameters.UUID);
		CommitTransaction();
	Except
		RollbackTransaction();
		UnlockDataForEdit(FileRef, EncryptionInformationWriteParameters.UUID);
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#Region AccountingAudit

// See AccountingAuditOverridable.OnDefineChecks
Procedure OnDefineChecks(ChecksGroups, Checks) Export
	
	FilesOperationsInVolumesInternal.OnDefineChecks(ChecksGroups, Checks);
	
EndProcedure

#EndRegion

#Region TextExtractionForFullTextSearch

Procedure ExtractTextFromFiles() Export
	
	SetPrivilegedMode(True);
	
	If Not Common.IsWindowsServer() Then
		Return; // Text extraction is available only under Windows.
	EndIf;
	
	WriteLogEvent(NStr("en = 'Files.Extract text';", Common.DefaultLanguageCode()),
		EventLogLevel.Information,,, NStr("en = 'Scheduled text extraction started';"));
	
	Query = New Query(QueryTextToExtractText());
	FilesToExtractText = Query.Execute().Unload();
	
	For Each FileWithoutText In FilesToExtractText Do
		
		FileLocked = False;
		
		Try
			FileWithBinaryDataName = ExtractTextFromFile(FileWithoutText, FileLocked);
		Except
			If FileLocked Then
				FileFields = Common.ObjectAttributesValues(FileWithoutText.Ref,
					"Description, Extension");
				WriteLogEvent(NStr("en = 'Files.Extract text';", Common.DefaultLanguageCode()),
					EventLogLevel.Error,,,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot complete scheduled text extraction from file
						           |""%1.""
						           |Reason:
						           |%2';"),
						CommonClientServer.GetNameWithExtension(FileFields.Description, FileFields.Extension),
						ErrorProcessing.DetailErrorDescription(ErrorInfo()) ));
			EndIf;
		EndTry;
		
		If ValueIsFilled(FileWithBinaryDataName) Then
			File = New File(FileWithBinaryDataName);
			If File.Exists() Then
				Try
					DeleteFiles(FileWithBinaryDataName);
				Except
					WriteLogEvent(NStr("en = 'Files.Extract text';", Common.DefaultLanguageCode()),
						EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				EndTry;
			EndIf;
		EndIf;
		
	EndDo;
	
	WriteLogEvent(NStr("en = 'Files.Extract text';", Common.DefaultLanguageCode()),
		EventLogLevel.Information,,, NStr("en = 'Scheduled text extraction completed';"));
	
EndProcedure

// Returns True if the file text is extracted on the server (not on the client).
//
// Returns:
//  Boolean -  False if the text is not extracted on the server,
//                 which means it can and must be extracted on the client.
//
Function ExtractTextFilesOnServer() Export
	
	SetPrivilegedMode(True);
	
	Return Constants.ExtractTextFilesOnServer.Get();
	
EndFunction

// Writes to the server the text extraction results that are the extracted text and the TextExtractionStatus.
Procedure RecordTextExtractionResult(FileOrVersionRef, ExtractionResult,
				TempTextStorageAddress) Export
				
	FileMetadata = FileOrVersionRef.Metadata();
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	
	DataLock = New DataLock;
	DataLockItem = DataLock.Add(FileMetadata.FullName());
	DataLockItem.SetValue("Ref", FileOrVersionRef);
	
	If Not Common.HasObjectAttribute("FileOwner", FileMetadata) Then
		Owner = Common.ObjectAttributeValue(FileOrVersionRef, "Owner");
		DataLockItem = DataLock.Add(Owner.Metadata().FullName());
		DataLockItem.SetValue("Ref", Owner);
	EndIf;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		LockDataForEdit(FileOrVersionRef);
		
		FileOrVersionObject = FileOrVersionRef.GetObject();
		If FileOrVersionObject <> Undefined Then
			
			If Not IsBlankString(TempTextStorageAddress) Then
				If FileMetadata.FullTextSearch = FullTextSearchUsing Then
					TextExtractionResult = ExtractText1(TempTextStorageAddress);
					FileOrVersionObject.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
					FileOrVersionObject.TextStorage = TextExtractionResult.TextStorage;
				Else
					FileOrVersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
					FileOrVersionObject.TextStorage = New ValueStorage("");
				EndIf;
				DeleteFromTempStorage(TempTextStorageAddress);
			EndIf;
			
			If ExtractionResult = "NotExtracted" Then
				FileOrVersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
			ElsIf ExtractionResult = "Extracted" Then
				FileOrVersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
			ElsIf ExtractionResult = "FailedExtraction" Then
				FileOrVersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.FailedExtraction;
			EndIf;
		
			OnWriteExtractedText(FileOrVersionObject);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#Region OtherFunctions

Function ExtensionsListForPreview() Export
	
	// See also the PictureFormat enumeration.
	ExtensionsForPreview = New ValueList;
	ExtensionsForPreview.Add("bmp");
	ExtensionsForPreview.Add("emf");
	ExtensionsForPreview.Add("gif");
	ExtensionsForPreview.Add("ico");
	ExtensionsForPreview.Add("icon");
	ExtensionsForPreview.Add("jpg");
	ExtensionsForPreview.Add("jpeg");
	ExtensionsForPreview.Add("png");
	ExtensionsForPreview.Add("tiff");
	ExtensionsForPreview.Add("tif");
	ExtensionsForPreview.Add("wmf");
	
	Return ExtensionsForPreview;
	
EndFunction

Function DeniedExtensionsList() Export
	
	DeniedExtensionsList = New ValueList;
	DeniedExtensionsList.Add("ade");
	DeniedExtensionsList.Add("adp");
	DeniedExtensionsList.Add("app");
	DeniedExtensionsList.Add("bas");
	DeniedExtensionsList.Add("bat");
	DeniedExtensionsList.Add("chm");
	DeniedExtensionsList.Add("class");
	DeniedExtensionsList.Add("cmd");
	DeniedExtensionsList.Add("com");
	DeniedExtensionsList.Add("cpl");
	DeniedExtensionsList.Add("crt");
	DeniedExtensionsList.Add("dll");
	DeniedExtensionsList.Add("exe");
	DeniedExtensionsList.Add("fxp");
	DeniedExtensionsList.Add("hlp");
	DeniedExtensionsList.Add("hta");
	DeniedExtensionsList.Add("ins");
	DeniedExtensionsList.Add("isp");
	DeniedExtensionsList.Add("jse");
	DeniedExtensionsList.Add("js");
	DeniedExtensionsList.Add("lnk");
	DeniedExtensionsList.Add("mda");
	DeniedExtensionsList.Add("mdb");
	DeniedExtensionsList.Add("mde");
	DeniedExtensionsList.Add("mdt");
	DeniedExtensionsList.Add("mdw");
	DeniedExtensionsList.Add("mdz");
	DeniedExtensionsList.Add("msc");
	DeniedExtensionsList.Add("msi");
	DeniedExtensionsList.Add("msp");
	DeniedExtensionsList.Add("mst");
	DeniedExtensionsList.Add("ops");
	DeniedExtensionsList.Add("pcd");
	DeniedExtensionsList.Add("pif");
	DeniedExtensionsList.Add("prf");
	DeniedExtensionsList.Add("prg");
	DeniedExtensionsList.Add("reg");
	DeniedExtensionsList.Add("scf");
	DeniedExtensionsList.Add("scr");
	DeniedExtensionsList.Add("sct");
	DeniedExtensionsList.Add("shb");
	DeniedExtensionsList.Add("shs");
	DeniedExtensionsList.Add("url");
	DeniedExtensionsList.Add("vb");
	DeniedExtensionsList.Add("vbe");
	DeniedExtensionsList.Add("vbs");
	DeniedExtensionsList.Add("wsc");
	DeniedExtensionsList.Add("wsf");
	DeniedExtensionsList.Add("wsh");
	
	Return DeniedExtensionsList;
	
EndFunction

Function TextFilesExtensionsList() Export
	
	Return "TXT XML INI"; 
	
EndFunction

Function PrepareSendingParametersStructure() Export
	
	Return New Structure("Recipient,Subject,Text", Undefined, "", "");
	
EndFunction

Procedure ScheduledFileSynchronizationWebdav(Parameters = Undefined, ResultAddress = Undefined) Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.FilesSynchronization);
	
	SetPrivilegedMode(True);
	DeleteUnsynchronizedFiles();
	
	Result = SynchronizationAccounts();
	For Each Selection In Result Do
		
		If IsBlankString(Selection.Service) Then
			Continue;
		EndIf;
		
		// @skip-check query-in-loop - Batch processing of a large amount of data.
		SynchronizeFilesWithCloudService(Selection.Ref);
		
	EndDo;
	
EndProcedure

// Fills in the list with the specified file types. List item value
// is used in the FilesOperationsInternalClient.ExtensionsByFileType
// to map possible extensions to a known file type.
//
// Parameters:
//   List - ValueList - a list, to which the supported
//          file types will be added.
//
Procedure FillListWithFilesTypes(List) Export
	
	List.Add("Pictures", NStr("en = 'Images (JPG, JPEG, PNG…)';"));
	List.Add("OfficeDocuments", NStr("en = 'Office documents (DOC, DOCX, XLS…)';"));
	
EndProcedure

#EndRegion

#Region FileExchange

// Preparation of parameters and preliminary checks before creating a file initial image.
//
Function PrepareDataToCreateFileInitialImage(ParametersStructure) Export
	
	Result = New Structure("DataReady, ConfirmationRequired, QueryText", True, False, "");
	
	FullWindowsFileInfobaseName 	= ParametersStructure.FullWindowsFileInfobaseName;
	FileInfobaseFullNameLinux 		= ParametersStructure.FileInfobaseFullNameLinux;
	WindowsVolumesFilesArchivePath = ParametersStructure.WindowsVolumesFilesArchivePath;
	PathToVolumeFilesArchiveLinux 	= ParametersStructure.PathToVolumeFilesArchiveLinux;
	
	VolumesFilesArchivePath = "";
	FullFileInfobaseName = "";
	
	HasFilesInVolumes = False;
	
	If FilesOperations.HasFileStorageVolumes() Then
		HasFilesInVolumes = HasFilesInVolumes();
	EndIf;
	
	If Common.IsWindowsServer() Then
		
		VolumesFilesArchivePath = WindowsVolumesFilesArchivePath;
		FullFileInfobaseName = FullWindowsFileInfobaseName;
		
		If Not Common.FileInfobase() Then
			If HasFilesInVolumes And Not IsBlankString(VolumesFilesArchivePath) And (Left(VolumesFilesArchivePath, 2) <> "\\"
				Or StrFind(VolumesFilesArchivePath, ":") <> 0) Then
				
				Common.MessageToUser(
					NStr("en = 'The path to the volume archive must be
					           |in the UNC format (\\servername\resource).';"),
					,
					"WindowsVolumesFilesArchivePath");
				Result.DataReady = False;
			EndIf;
			If Not IsBlankString(FullFileInfobaseName) And (Left(FullFileInfobaseName, 2) <> "\\" Or StrFind(FullFileInfobaseName, ":") <> 0) Then
				Common.MessageToUser(
					NStr("en = 'The path to the file infobase must be
					           |in the UNC format (\\servername\resource).';"),
					,
					"FullWindowsFileInfobaseName");
				Result.DataReady = False;
			EndIf;
		EndIf;
	Else
		VolumesFilesArchivePath = PathToVolumeFilesArchiveLinux;
		FullFileInfobaseName = FileInfobaseFullNameLinux;
	EndIf;
	
	If IsBlankString(FullFileInfobaseName) Then
		Common.MessageToUser(
			NStr("en = 'Please provide the full name of the file infobase (1cv8.1cd file).';"),,
			"FullWindowsFileInfobaseName");
		Result.DataReady = False;
	ElsIf Result.DataReady Then
		InfobaseFile = New File(FullFileInfobaseName);
		
		If HasFilesInVolumes Then
			If IsBlankString(VolumesFilesArchivePath) Then
				Common.MessageToUser(
					NStr("en = 'Please provide the full name of the archive with volume files (it is a *.zip file).';"),, 
					"WindowsVolumesFilesArchivePath");
				Result.DataReady = False;
			Else
				File = New File(VolumesFilesArchivePath);
				
				If File.Exists() And InfobaseFile.Exists() Then
					Result.QueryText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Files ""%1"" and ""%2"" already exist.
							           |Do you want to overwrite them?';"), VolumesFilesArchivePath, FullFileInfobaseName);
					Result.ConfirmationRequired = True;
				ElsIf File.Exists() Then
					Result.QueryText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'File ""%1"" already exists.
							           |Do you want to overwrite it?';"), VolumesFilesArchivePath);
					Result.ConfirmationRequired = True;
				EndIf;
			EndIf;
		EndIf;
		
		If Result.DataReady Then
			If InfobaseFile.Exists() And Not Result.ConfirmationRequired Then
				Result.QueryText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'File ""%1"" already exists.
						           |Do you want to overwrite it?';"), FullFileInfobaseName);
				Result.ConfirmationRequired = True;
			EndIf;
			
			// Create a temporary directory.
			// ACC:441-off - The procedure "CreateFileInitialImageAtServer" clears up temporary files.
			DirectoryName = GetTempFileName();
			CreateDirectory(DirectoryName);
			
			// Creating a temporary file directory.
			FileDirectoryName = GetTempFileName();
			CreateDirectory(FileDirectoryName);
			// ACC:441-on
			
			// To pass a file directory path to the OnSendFileData handler.
			SaveSetting("FileExchange", "TempDirectory", FileDirectoryName);
			
			// Adding variables to the parameters that are required to create the initial image.
			ParametersStructure.Insert("DirectoryName", DirectoryName);
			ParametersStructure.Insert("FileDirectoryName", FileDirectoryName);
			ParametersStructure.Insert("HasFilesInVolumes", HasFilesInVolumes);
			ParametersStructure.Insert("VolumesFilesArchivePath", VolumesFilesArchivePath);
			ParametersStructure.Insert("FullFileInfobaseName", FullFileInfobaseName);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Procedure - Create file initial image on the server
//
// Parameters:
//  Parameters - Structure:
//   * DirectoryName - String
//   * Language - String
//   * VolumesFilesArchivePath - String
//   * HasFilesInVolumes- Boolean
//   * FileDirectoryName - String
//   * FullFileInfobaseName  - String
//  StorageAddress - UUID
//
Procedure CreateFileInitialImageAtServer(Parameters, StorageAddress) Export
	
	Try
		
		ConnectionString = "File=""" + Parameters.DirectoryName + """;"
						 + "Locale=""" + Parameters.Language + """;";
		ExchangePlans.CreateInitialImage(Parameters.Node, ConnectionString);  // Actual creation of the initial image.
		
		If Parameters.HasFilesInVolumes Then
			ZipFile = New ZipFileWriter;
			ZipFile.Open(Parameters.VolumesFilesArchivePath);
			
			TemporaryFiles = New Array;
			TemporaryFiles = FindFiles(Parameters.FileDirectoryName, GetAllFilesMask());
			
			For Each TempFile In TemporaryFiles Do
				If TempFile.IsFile() Then
					TemporaryFilePath = TempFile.FullName;
					ZipFile.Add(TemporaryFilePath);
				EndIf;
			EndDo;
			
			ZipFile.Write();
			
			DeleteFiles(Parameters.FileDirectoryName); // Deleting along with all the files inside.
		EndIf;
		
	Except
		
		DeleteFiles(Parameters.DirectoryName);
		Raise;
		
	EndTry;
	
	TemporaryInfobaseFilePath = Parameters.DirectoryName + "\1Cv8.1CD";
	MoveFile(TemporaryInfobaseFilePath, Parameters.FullFileInfobaseName);
	
	// Clear
	DeleteFiles(Parameters.DirectoryName);
	
EndProcedure

// Preparation of parameters and preliminary checks before creating a server initial image.
//
Function PrepareDataToCreateServerInitialImage(ParametersStructure) Export
	
	Result = New Structure("DataReady, ConfirmationRequired, QueryText", True, False, "");
	
	WindowsVolumesFilesArchivePath = ParametersStructure.WindowsVolumesFilesArchivePath;
	PathToVolumeFilesArchiveLinux 	= ParametersStructure.PathToVolumeFilesArchiveLinux;
	VolumesFilesArchivePath        = "";
	
	HasFilesInVolumes = False;
	
	If FilesOperations.HasFileStorageVolumes() Then
		HasFilesInVolumes = HasFilesInVolumes();
	EndIf;
	
	If Common.IsWindowsServer() Then
		
		VolumesFilesArchivePath = WindowsVolumesFilesArchivePath;
		
		If HasFilesInVolumes Then
			If Not IsBlankString(VolumesFilesArchivePath)
			   And (Left(VolumesFilesArchivePath, 2) <> "\\"
			 Or StrFind(VolumesFilesArchivePath, ":") <> 0) Then
				
				Common.MessageToUser(
					NStr("en = 'The path to the volume archive must be
					           |in the UNC format (\\servername\resource).';"),
					,
					"WindowsVolumesFilesArchivePath");
				Result.DataReady = False;
			EndIf;
		EndIf;
		
	Else
		VolumesFilesArchivePath = PathToVolumeFilesArchiveLinux;
	EndIf;
	
	If Result.DataReady Then
		If HasFilesInVolumes And IsBlankString(VolumesFilesArchivePath) Then
				Common.MessageToUser(
					NStr("en = 'Please provide the full name of the archive with volume files (it is a *.zip file).';"),
					,
					"WindowsVolumesFilesArchivePath");
				Result.DataReady = False;
		Else
			If HasFilesInVolumes Then
				File = New File(VolumesFilesArchivePath);
				If File.Exists() Then
					Result.QueryText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'File ""%1"" already exists.
							           |Do you want to overwrite it?';"), VolumesFilesArchivePath);
					Result.ConfirmationRequired = True;
				EndIf;
			EndIf;

			// ACC:441-off - The procedure "CreateFileInitialImageAtServer" clears up temporary files.			
			// Create a temporary directory.
			DirectoryName = GetTempFileName();
			CreateDirectory(DirectoryName);
			
			// Creating a temporary file directory.
			FileDirectoryName = GetTempFileName();
			CreateDirectory(FileDirectoryName);
			// ACC:441-on
			
			// To pass a file directory path to the OnSendFileData handler.
			SaveSetting("FileExchange", "TempDirectory", FileDirectoryName);
			
			// Adding variables to the parameters that are required to create the initial image.
			ParametersStructure.Insert("HasFilesInVolumes", HasFilesInVolumes);
			ParametersStructure.Insert("FilePath", VolumesFilesArchivePath);
			ParametersStructure.Insert("DirectoryName", DirectoryName);
			ParametersStructure.Insert("FileDirectoryName", FileDirectoryName);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Create server initial image on the server.
//
Procedure CreateServerInitialImageAtServer(Parameters, ResultAddress) Export
	
	Try
		
		ExchangePlans.CreateInitialImage(Parameters.Node, Parameters.ConnectionString);
		
		If Parameters.HasFilesInVolumes Then
			ZipFile = New ZipFileWriter;
			ZIPPath = Parameters.FilePath;
			ZipFile.Open(ZIPPath);
			
			TemporaryFiles = New Array;
			TemporaryFiles = FindFiles(Parameters.FileDirectoryName, GetAllFilesMask());
			
			For Each TempFile In TemporaryFiles Do
				If TempFile.IsFile() Then
					TemporaryFilePath = TempFile.FullName;
					ZipFile.Add(TemporaryFilePath);
				EndIf;
			EndDo;
			
			ZipFile.Write();
			DeleteFiles(Parameters.FileDirectoryName); // Deleting along with all the files inside.
		EndIf;
		
	Except
		
		DeleteFiles(Parameters.DirectoryName);
		Raise;
		
	EndTry;
	
	// Clear
	DeleteFiles(Parameters.DirectoryName);
	
EndProcedure

#EndRegion

#Region ScheduledJobsHandlers

// Handler of the TextExtraction scheduled job.
// Extracts text from files for the full-text search.
//
Procedure ExtractTextFromFilesAtServer() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.TextExtraction);
	
	ExtractTextFromFiles();
	
EndProcedure

#EndRegion

#Region TextExtraction

// Returns text for a query used to get files with unextracted text.
//
// Parameters:
//  GetAllFiles - Boolean - the initial value is False. If True, disables individual
//                     file selection.
//
// Returns:
//  String - Query text.
//
Function QueryTextToExtractText(GetAllFiles = False, AdditionalFields = False) Export
	
	// Generating the query text for all attachment catalogs
	QueryText = "";
	
	FilesTypes = Metadata.DefinedTypes.AttachedFile.Type.Types();
	
	TotalCatalogNames = New Array;
	
	For Each Type In FilesTypes Do
		FilesDirectoryMetadata = Metadata.FindByType(Type);
		NotUseFullTextSearch = Metadata.ObjectProperties.FullTextSearchUsing.DontUse;
		If FilesDirectoryMetadata.FullTextSearch = NotUseFullTextSearch Then
			Continue;
		EndIf;
		TotalCatalogNames.Add(FilesDirectoryMetadata.Name);
	EndDo;
	
	FilesNumberInSelection = Int(100 / TotalCatalogNames.Count());
	FilesNumberInSelection = ?(FilesNumberInSelection < 10, 10, FilesNumberInSelection);
	
	For Each CatalogName In TotalCatalogNames Do
	
		If Not IsBlankString(QueryText) Then
			QueryText = QueryText + "
				|
				|UNION ALL
				|
				|";
		EndIf;
		
		QueryText = QueryText + QueryTextForFilesWithUnextractedText(CatalogName,
			FilesNumberInSelection, GetAllFiles, AdditionalFields);
		EndDo;
		
	Return QueryText;
	
EndFunction

#EndRegion

#Region Scanning

Function ScannerParametersInEnumerations(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber) Export 
	
	If PermissionNumber = 200 Then
		Resolution = Enums.ScannedImageResolutions.dpi200;
	ElsIf PermissionNumber = 300 Then
		Resolution = Enums.ScannedImageResolutions.dpi300;
	ElsIf PermissionNumber = 600 Then
		Resolution = Enums.ScannedImageResolutions.dpi600;
	ElsIf PermissionNumber = 1200 Then
		Resolution = Enums.ScannedImageResolutions.dpi1200;
	EndIf;
	
	If ChromaticityNumber = 0 Then
		Chromaticity = Enums.ImageColorDepths.Monochrome;
	ElsIf ChromaticityNumber = 1 Then
		Chromaticity = Enums.ImageColorDepths.Grayscale;
	ElsIf ChromaticityNumber = 2 Then
		Chromaticity = Enums.ImageColorDepths.Colored;
	EndIf;
	
	If RotationNumber = 0 Then
		Rotation = Enums.PictureRotationOptions.NoRotation;
	ElsIf RotationNumber = 90 Then
		Rotation = Enums.PictureRotationOptions.Right90;
	ElsIf RotationNumber = 180 Then
		Rotation = Enums.PictureRotationOptions.Right180;
	ElsIf RotationNumber = 270 Then
		Rotation = Enums.PictureRotationOptions.Left90;
	EndIf;
	
	If PaperSizeNumber = 0 Then
		PaperSize = Enums.PaperSizes.NotDefined;
	ElsIf PaperSizeNumber = 11 Then
		PaperSize = Enums.PaperSizes.A3;
	ElsIf PaperSizeNumber = 1 Then
		PaperSize = Enums.PaperSizes.A4;
	ElsIf PaperSizeNumber = 5 Then
		PaperSize = Enums.PaperSizes.A5;
	ElsIf PaperSizeNumber = 6 Then
		PaperSize = Enums.PaperSizes.B4;
	ElsIf PaperSizeNumber = 2 Then
		PaperSize = Enums.PaperSizes.B5;
	ElsIf PaperSizeNumber = 7 Then
		PaperSize = Enums.PaperSizes.B6;
	ElsIf PaperSizeNumber = 14 Then
		PaperSize = Enums.PaperSizes.C4;
	ElsIf PaperSizeNumber = 15 Then
		PaperSize = Enums.PaperSizes.C5;
	ElsIf PaperSizeNumber = 16 Then
		PaperSize = Enums.PaperSizes.C6;
	ElsIf PaperSizeNumber = 3 Then
		PaperSize = Enums.PaperSizes.USLetter;
	ElsIf PaperSizeNumber = 4 Then
		PaperSize = Enums.PaperSizes.USLegal;
	ElsIf PaperSizeNumber = 10 Then
		PaperSize = Enums.PaperSizes.USExecutive;
	EndIf;
	
	Result = New Structure;
	Result.Insert("Resolution", Resolution);
	Result.Insert("Chromaticity", Chromaticity);
	Result.Insert("Rotation", Rotation);
	Result.Insert("PaperSize", PaperSize);
	Return Result;
	
EndFunction

Function CommandScanSheet() Export
	Return "e1cib/command/DataProcessor.Scanning.Command.ScanSheet";
EndFunction

Function ConvertScanSettings(Val Settings) Export

	If Settings.Resolution = Enums.ScannedImageResolutions.dpi200 Then
		Settings.Resolution = 200;
	ElsIf Settings.Resolution = Enums.ScannedImageResolutions.dpi300 Then
		Settings.Resolution = 300;
	ElsIf Settings.Resolution = Enums.ScannedImageResolutions.dpi600 Then
		Settings.Resolution = 600;
	ElsIf Settings.Resolution = Enums.ScannedImageResolutions.dpi1200 Then
		Settings.Resolution = 1200;
	Else
		Settings.Resolution = -1;
	EndIf;

	If Settings.Chromaticity = Enums.ImageColorDepths.Monochrome Then
		Settings.Chromaticity = 0;
	ElsIf Settings.Chromaticity = Enums.ImageColorDepths.Grayscale Then
		Settings.Chromaticity = 1;
	ElsIf Settings.Chromaticity = Enums.ImageColorDepths.Colored Then
		Settings.Chromaticity = 2;
	Else
		Settings.Chromaticity = -1;
	EndIf;

	If Settings.Rotation = Enums.PictureRotationOptions.Right90 Then
		Settings.Rotation = 90;
	ElsIf Settings.Rotation = Enums.PictureRotationOptions.Right180 Then
		Settings.Rotation = 180;
	ElsIf Settings.Rotation = Enums.PictureRotationOptions.Left90 Then
		Settings.Rotation = 270;
	Else
		Settings.Rotation = 0;
	EndIf;

	If Settings.PaperSize = Enums.PaperSizes.NotDefined Then
		Settings.PaperSize = 0;
	ElsIf Settings.PaperSize = Enums.PaperSizes.A3 Then
		Settings.PaperSize = 11;
	ElsIf Settings.PaperSize = Enums.PaperSizes.A4 Then
		Settings.PaperSize = 1;
	ElsIf Settings.PaperSize = Enums.PaperSizes.A5 Then
		Settings.PaperSize = 5;
	ElsIf Settings.PaperSize = Enums.PaperSizes.B4 Then
		Settings.PaperSize = 6;
	ElsIf Settings.PaperSize = Enums.PaperSizes.B5 Then
		Settings.PaperSize = 2;
	ElsIf Settings.PaperSize = Enums.PaperSizes.B6 Then
		Settings.PaperSize = 7;
	ElsIf Settings.PaperSize = Enums.PaperSizes.C4 Then
		Settings.PaperSize = 14;
	ElsIf Settings.PaperSize = Enums.PaperSizes.C5 Then
		Settings.PaperSize = 15;
	ElsIf Settings.PaperSize = Enums.PaperSizes.C6 Then
		Settings.PaperSize = 16;
	ElsIf Settings.PaperSize = Enums.PaperSizes.USLetter Then
		Settings.PaperSize = 3;
	ElsIf Settings.PaperSize = Enums.PaperSizes.USLegal Then
		Settings.PaperSize = 4;
	ElsIf Settings.PaperSize = Enums.PaperSizes.USExecutive Then
		Settings.PaperSize = 10;
	Else
		Settings.PaperSize = 0;
	EndIf;

	If Settings.TIFFDeflation = Enums.TIFFCompressionTypes.LZW Then
		Settings.TIFFDeflation = 2;
	ElsIf Settings.TIFFDeflation = Enums.TIFFCompressionTypes.RLE Then
		Settings.TIFFDeflation = 5;
	ElsIf Settings.TIFFDeflation = Enums.TIFFCompressionTypes.CCITT3 Then
		Settings.TIFFDeflation = 3;
	ElsIf Settings.TIFFDeflation = Enums.TIFFCompressionTypes.CCITT4 Then
		Settings.TIFFDeflation = 4;
	Else
		Settings.TIFFDeflation = 6; // NoCompression
	EndIf;

	Return Settings;

EndFunction

#EndRegion

#Region CleanUpUnusedFiles

Procedure ClearExcessiveFiles(Parameters = Undefined, ResultAddress = Undefined) Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.CleanUpUnusedFiles);
	
	SetPrivilegedMode(True);
	
	If Parameters <> Undefined And TypeOf(Parameters) = Type("Structure") And Parameters.Property("ManualStart1") Then
		CleanUpUnnecessaryFiles = Enums.FilesCleanupModes.CleanUpDeletedAndUnusedFiles;
	Else
		CleanUpUnnecessaryFiles = FilesCleanupMode();
	EndIf;
	WriteToEventLogCleanupFiles(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Scheduled cleanup of unused files is started (%1).';"), CleanUpUnnecessaryFiles));
	
	If CleanUpUnnecessaryFiles = Enums.FilesCleanupModes.CleanUpDeletedAndUnusedFiles Then
		CleanupSettings = InformationRegisters.FilesClearingSettings.CurrentClearSettings();
		FilesClearingSettings = CleanupSettings.FindRows(New Structure("IsCatalogItemSetup", False));
		For Each Setting In FilesClearingSettings Do
			
			ExceptionsArray = New Array;
			DetailedSettings = CleanupSettings.FindRows(New Structure(
				"OwnerID, IsCatalogItemSetup",
				Setting.FileOwner, True));
				
			For Each ExceptionItem In DetailedSettings Do
				ClearConfigurationFiles(ExceptionItem, ExceptionsArray);
			EndDo;
			
			ClearConfigurationFiles(Setting, ExceptionsArray);
		EndDo;
	EndIf;
	
	FilesOperationsInVolumesInternal.ClearDeletedFiles();
	WriteToEventLogCleanupFiles(NStr("en = 'Scheduled cleanup of unused files is completed.';"));
	
EndProcedure

Function ExceptionItemsOnClearFiles() Export
	
	Return FilesSettings().DontClearFiles;
	
EndFunction

#EndRegion

#Region ForCallsFromOtherSubsystems

// See StandardSubsystemsServer.OnSendDataToSlave.
Procedure OnSendDataToSlave(DataElement, ItemSend, InitialImageCreating, Recipient) Export
	
	WhenSendingFile(DataElement, ItemSend, InitialImageCreating, Recipient);
	
EndProcedure

// 
Procedure OnSendDataToMaster(DataElement, ItemSend, Recipient) Export
	
	WhenSendingFile(DataElement, ItemSend);
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromSlave.
Procedure OnReceiveDataFromSlave(DataElement, ItemReceive, SendBack, Sender) Export
	
	WhenReceivingFile(DataElement, ItemReceive, Sender);
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromMaster.
Procedure OnReceiveDataFromMaster(DataElement, ItemReceive, SendBack, Sender) Export
	
	WhenReceivingFile(DataElement, ItemReceive);
	
EndProcedure

// See CommonOverridable.OnAddReferenceSearchExceptions.
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export
	
	RefSearchExclusions.Add(Metadata.InformationRegisters.FilesInWorkingDirectory.FullName());
	RefSearchExclusions.Add(Metadata.InformationRegisters.FilesInfo.FullName());
	RefSearchExclusions.Add("Catalog.Files.Attributes.CurrentVersion");
	RefSearchExclusions.Add("Catalog.FilesVersions.Attributes.ParentVersion");
	
EndProcedure

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not AccessRight("Read", Metadata.Catalogs.Files)
		Or ModuleToDoListServer.UserTaskDisabled("FilesToEdit") Then
		Return;
	EndIf;
	
	LockedFilesCount = LockedFilesCount();
	
	// The procedure can be called only if the "To-do list" subsystem is integrated.
	// Therefore, don't check if the subsystem is integrated.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.Catalogs.Files.FullName());
	
	For Each Section In Sections Do
		
		EditedFilesID = "FilesToEdit" + StrReplace(Section.FullName(), ".", "");
		ToDoItem = ToDoList.Add();
		ToDoItem.Id  = EditedFilesID;
		ToDoItem.HasToDoItems       = LockedFilesCount > 0;
		ToDoItem.Presentation  = NStr("en = 'Locked files';");
		ToDoItem.Count     = LockedFilesCount;
		ToDoItem.Important         = False;
		ToDoItem.Form          = "DataProcessor.FilesOperations.Form.FilesToEdit";
		ToDoItem.Owner       = Section;
		
	EndDo;
	
EndProcedure

// See BatchEditObjectsOverridable.OnDefineObjectsWithEditableAttributes.
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.FilesFolders.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.Files.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.FilesVersions.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.FileStorageVolumes.FullName(), "AttributesToEditInBatchProcessing");
EndProcedure

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport.
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	// File synchronization with cloud service.
	
	// Import to FileStorageVolumes catalog is prohibited.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.FileStorageVolumes.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings
Procedure OnDefineScheduledJobSettings(Settings) Export
	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.TextExtraction;
	If Common.SubsystemExists("StandardSubsystems.FullTextSearch") Then
		ModuleFullTextSearchServer = Common.CommonModule("FullTextSearchServer");
		Dependence.FunctionalOption = ModuleFullTextSearchServer.UseFullTextSearchFunctionalOption();
	EndIf;
	Dependence.AvailableSaaS = False;
	
	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.CleanUpUnusedFiles;
	Dependence.UseExternalResources = True;
	
	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.FilesSynchronization;
	Dependence.FunctionalOption = Metadata.FunctionalOptions.UseFileSync;
	Dependence.UseExternalResources = True;
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction.
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.FilesVersions, True);
	Lists.Insert(Metadata.Catalogs.FilesFolders, True);
	Lists.Insert(Metadata.Catalogs.Files, True);
	
EndProcedure

// See AccessManagementOverridable.OnFillAvailableRightsForObjectsRightsSettings.
Procedure OnFillAvailableRightsForObjectsRightsSettings(AvailableRights) Export
	
	////////////////////////////////////////////////////////////
	// Catalog.FilesFolders
	
	// Read folders and files right.
	Right = AvailableRights.Add();
	Right.RightsOwner  = Metadata.Catalogs.FilesFolders.FullName();
	Right.Name           = "Read";
	Right.Title     = NStr("en = 'Read';");
	Right.ToolTip     = NStr("en = 'Read folders and files.';");
	Right.InitialValue = True;
	// Rights for standard access restriction templates.
	Right.ReadInTables.Add("*");
	
	// Right "Modify folders".
	Right = AvailableRights.Add();
	Right.RightsOwner  = Metadata.Catalogs.FilesFolders.FullName();
	Right.Name           = "FoldersModification";
	Right.Title     = NStr("en = 'Edit
	                                 |folders';");
	Right.ToolTip     = NStr("en = 'Add, edit, and mark folders
	                                 |for deletion.';");
	// Rights that are required for this right.
	Right.RequiredRights1.Add("Read");
	// Rights for standard access restriction templates.
	Right.ChangeInTables.Add(Metadata.Catalogs.FilesFolders.FullName());
	
	// Right "Modify files".
	Right = AvailableRights.Add();
	Right.RightsOwner  = Metadata.Catalogs.FilesFolders.FullName();
	Right.Name           = "FilesModification";
	Right.Title     = NStr("en = 'Edit
	                                 |files';");
	Right.ToolTip     = NStr("en = 'Edit files in a folder.';");
	// Rights that are required for this right.
	Right.RequiredRights1.Add("Read");
	// Rights for standard access restriction templates.
	Right.ChangeInTables.Add("*");
	
	// Right "Add files".
	Right = AvailableRights.Add();
	Right.RightsOwner  = Metadata.Catalogs.FilesFolders.FullName();
	Right.Name           = "AddFilesAllowed";
	Right.Title     = NStr("en = 'Add
	                                 |files';");
	Right.ToolTip     = NStr("en = 'Add files to a folder.';");
	// Rights that are required for this right.
	Right.RequiredRights1.Add("FilesModification");
	
	// File deletion mark right.
	Right = AvailableRights.Add();
	Right.RightsOwner  = Metadata.Catalogs.FilesFolders.FullName();
	Right.Name           = "FilesDeletionMark";
	Right.Title     = NStr("en = 'Mark for
	                                 |deletion';");
	Right.ToolTip     = NStr("en = 'Set deletion marks to files in a folder.';");
	// Rights that are required for this right.
	Right.RequiredRights1.Add("FilesModification");
	
	Right = AvailableRights.Add();
	Right.RightsOwner  = Metadata.Catalogs.FilesFolders.FullName();
	Right.Name           = "RightsManagement";
	Right.Title     = NStr("en = 'Manage
	                                 |access rights';");
	Right.ToolTip     = NStr("en = 'Manage folder access rights.';");
	// Rights that are required for this right.
	Right.RequiredRights1.Add("Read");
	
EndProcedure

// See AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionKinds.
Procedure OnFillMetadataObjectsAccessRestrictionKinds(LongDesc) Export
	
	LongDesc = LongDesc + "
		|Catalog.FilesFolders.Read.RightsSettings.Catalog.FilesFolders
		|Catalog.FilesFolders.Update.RightsSettings.Catalog.FilesFolders
		|Catalog.Files.Read.RightsSettings.Catalog.FilesFolders
		|Catalog.Files.Update.RightsSettings.Catalog.FilesFolders
		|Catalog.Files.Update.ExternalUsers
		|Catalog.Files.Read.ExternalUsers
		|";
	
	FilesOwnersTypes = Metadata.DefinedTypes.FilesOwner.Type.Types();
	For Each OwnerType In FilesOwnersTypes Do
		
		OwnerMetadata = Metadata.FindByType(OwnerType);
		If OwnerMetadata = Undefined Then
			Continue;
		EndIf;
		
		FullOwnerName = OwnerMetadata.FullName();
		
		LongDesc = LongDesc + "
			|Catalog.FilesVersions.Read.Object." + FullOwnerName + "
			|Catalog.FilesVersions.Update.Object." + FullOwnerName + "
			|Catalog.Files.Read.Object." + FullOwnerName + "
			|Catalog.Files.Update.Object." + FullOwnerName + "
			|";
		
	EndDo;
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.SharedData = True;
	Handler.InitialFilling = True;
	Handler.Procedure = "FilesOperationsInternal.UpdateDeniedExtensionsList";
	Handler.ExecutionMode = "Seamless";
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.InitialFilling = True;
	Handler.Procedure = "FilesOperationsInternal.UpdateProhibitedExtensionListInDataArea";
	Handler.ExecutionMode = "Seamless";
	
	Handler = Handlers.Add();
	Handler.Version = "3.1.3.119";
	Handler.SharedData = True;
	Handler.InitialFilling = True;
	Handler.Procedure = "FilesOperationsInternal.UpdateTextFilesExtensionsList";
	Handler.ExecutionMode = "Seamless";
			
	Handler = Handlers.Add();
	Handler.Version = "3.0.2.46";
	Handler.Comment =
			NStr("en = 'Update universal date and storage type for items of the ""Files"" catalog.';");
	Handler.Id = New UUID("8b417c47-dd46-45ce-b59b-c675059c9020");
	Handler.Procedure = "Catalogs.Files.ProcessDataForMigrationToNewVersion";
	Handler.ExecutionMode = "Deferred";
	Handler.ObjectsToRead      = "Catalog.Files";
	Handler.ObjectsToChange    = "Catalog.Files,InformationRegister.FilesInfo";
	Handler.ObjectsToLock   = "Catalog.Files,Catalog.FilesVersions";
	Handler.UpdateDataFillingProcedure = "Catalogs.Files.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure    = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
	Handler.Multithreaded = True;
	
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion";
	Priority.Order = "Any";
	
	
	Handler = Handlers.Add();
	Handler.Procedure = "InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion";
	Handler.Version = "3.0.2.46";
	Handler.ExecutionMode = "Deferred";
	Handler.Id = New UUID("5137a43e-75aa-4a68-ba2f-525a3a646af8");
	Handler.Multithreaded = True;
	Handler.UpdateDataFillingProcedure = "InformationRegisters.FilesInfo.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Comment = NStr("en = 'Move file data to the ""File info"" information register.';");
	
	ItemsToRead = New Array;
	ItemsToRead.Add(Metadata.Catalogs.Files.FullName());
	ItemsToRead.Add(Metadata.InformationRegisters.FilesInfo.FullName());
	Handler.ObjectsToRead = StrConcat(ItemsToRead, ",");
	
	Editable1 = New Array;
	Editable1.Add(Metadata.InformationRegisters.FilesInfo.FullName());
	Handler.ObjectsToChange = StrConcat(Editable1, ",");
	
	ToLock = New Array;
	ToLock.Add(Metadata.Catalogs.Files.FullName());
	ToLock.Add(Metadata.InformationRegisters.FilesInfo.FullName());
	Handler.ObjectsToLock = StrConcat(ToLock, ",");
	
	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();

	ExecutionPriority = Handler.ExecutionPriorities.Add();
	ExecutionPriority.Procedure = "InformationRegisters.FileRepository.ProcessDataForMigrationToNewVersion";
	ExecutionPriority.Order = "Before";

	ExecutionPriority = Handler.ExecutionPriorities.Add();
	ExecutionPriority.Procedure = "Catalogs.Files.ProcessDataForMigrationToNewVersion";
	ExecutionPriority.Order = "Any";
		
	Handler = Handlers.Add();
	Handler.Procedure = "InformationRegisters.FileRepository.ProcessDataForMigrationToNewVersion";
	Handler.Version = "3.1.3.260";
	Handler.ExecutionMode = "Deferred";
	Handler.Id = New UUID("84e58943-94fe-4f92-99b3-91be534d3754");
	Handler.UpdateDataFillingProcedure = "InformationRegisters.FileRepository.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Comment = NStr("en = 'Creating missing file versions for the Files catalog items.';");
	
	ObjectsToRead = New Array;
	ObjectsToRead.Add(Metadata.Catalogs.Files.FullName());
	ObjectsToRead.Add(Metadata.InformationRegisters.DeleteFilesBinaryData.FullName());
	Handler.ObjectsToRead = StrConcat(ObjectsToRead, ",");
	
	ObjectsToChange = New Array;
	ObjectsToChange.Add(Metadata.Catalogs.Files.FullName());
	ObjectsToChange.Add(Metadata.InformationRegisters.DeleteFilesBinaryData.FullName());
	ObjectsToChange.Add(Metadata.InformationRegisters.FileRepository.FullName());
	ObjectsToChange.Add(Metadata.Catalogs.FilesVersions.FullName());
	Handler.ObjectsToChange = StrConcat(ObjectsToChange, ",");
	
	ObjectsToLock = New Array;
	ObjectsToLock.Add(Metadata.InformationRegisters.DeleteFilesBinaryData.FullName());
	ObjectsToLock.Add(Metadata.InformationRegisters.FileRepository.FullName());
	ObjectsToLock.Add(Metadata.Catalogs.FilesVersions.FullName());
	ObjectsToLock.Add(Metadata.Catalogs.Files.FullName());
	Handler.ObjectsToLock = StrConcat(ObjectsToLock, ",");
	
	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();

	ExecutionPriority = Handler.ExecutionPriorities.Add();
	ExecutionPriority.Procedure = "Catalogs.Files.ProcessDataForMigrationToNewVersion";
	ExecutionPriority.Order = "After";
	
	Handler = Handlers.Add();
	Handler.Procedure = "InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion";
	Handler.Version = "3.1.10.301";
	Handler.ExecutionMode = "Deferred";
	Handler.Id = New UUID("fb2fba94-f4a1-408a-9274-d5c44e5a42a1");
	Handler.UpdateDataFillingProcedure = "InformationRegisters.FilesExist.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Comment = NStr("en = 'Update the attachment flag (ignores service files).';");
	Handler.ObjectsToRead = NamesOfCatalogsWithServiceFiles();
	Handler.ObjectsToChange = Metadata.InformationRegisters.FilesExist.FullName();
    Handler.Multithreaded = True;
	
	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();

	ExecutionPriority = Handler.ExecutionPriorities.Add();
	ExecutionPriority.Procedure = "Catalogs.Files.ProcessDataForMigrationToNewVersion";
	ExecutionPriority.Order = "After";
	
	FilesOperationsInVolumesInternal.OnAddUpdateHandlers(Handlers);
	
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming.
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	OldName = "Role.WorkingWithFileFolders";
	NewName  = "Role.AddEditFoldersAndFiles";
	Common.AddRenaming(Total, "2.4.1.1", OldName, NewName, Library);
	
EndProcedure

// See CommonOverridable.OnAddClientParameters.
Procedure OnAddClientParameters(Parameters) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	FilesOperationSettings = FilesOperationsInternalCached.FilesOperationSettings();
	
	Parameters.Insert("PersonalFilesOperationsSettings", New FixedStructure(
		FilesOperationSettings.PersonalSettings));
	
	Parameters.Insert("CommonFilesOperationsSettings", New FixedStructure(
		FilesOperationSettings.CommonSettings));
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart.
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	FilesOperationSettings = FilesOperationsInternalCached.FilesOperationSettings();
	
	Parameters.Insert("PersonalFilesOperationsSettings", New FixedStructure(
		FilesOperationSettings.PersonalSettings));
		
	LockedFilesCount = 0;
	If Common.SeparatedDataUsageAvailable() Then
		User = Users.AuthorizedUser();
		If TypeOf(User) = Type("CatalogRef.Users") Then
			LockedFilesCount = LockedFilesCount();
		EndIf;
	EndIf;
	
	Parameters.Insert("LockedFilesCount", LockedFilesCount);
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources.
Procedure OnFillPermissionsToAccessExternalResources(PermissionsRequests) Export
	
	If GetFunctionalOption("StoreFilesInVolumesOnHardDrive") Then
		Catalogs.FileStorageVolumes.AddRequestsToUseExternalResourcesForAllVolumes(PermissionsRequests);
	EndIf;
	
EndProcedure

// See ExportImportDataOverridable.OnFillCommonDataTypesThatDoNotRequireMappingRefsOnImport.
Procedure OnFillCommonDataTypesThatDoNotRequireMappingRefsOnImport(Types) Export
	
	// References to the "FileStorageVolumes" catalog are cleared during export.
	// Import applies the volume settings in the destination infobase,
	// while the volume settings in the source infobase are ignored.
	Types.Add(Metadata.Catalogs.FileStorageVolumes);
	
EndProcedure

// See ReportsOptionsOverridable.CustomizeReportsOptions.
Procedure OnSetUpReportsOptions(Settings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.IrrelevantFilesVolume);
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.VolumeIntegrityCheck);
EndProcedure

// See MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters.
Procedure OnCollectConfigurationStatisticsParameters() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		Return;
	EndIf;
	
	ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
	
	QueryText = 
		"SELECT
		|	COUNT(1) AS Count
		|FROM
		|	Catalog.FileSynchronizationAccounts AS FileSynchronizationAccounts";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	
	ModuleMonitoringCenter.WriteConfigurationObjectStatistics("Catalog.FileSynchronizationAccounts",
		Selection.Count());
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	StatisticsParameters = New ValueTable;
	StatisticsParameters.Columns.Add("ParameterName", New TypeDescription("String"));
	StatisticsParameters.Columns.Add("Count", New TypeDescription("Number"));
	UsersList = InfoBaseUsers.GetUsers();
	For Each CurUser In UsersList Do
		DevicesNameSettingsKeys = CommonSettingsStorage.GetList("ScanningSettings1/DeviceName",
			CurUser.Name);
		For Each SettingsKey In DevicesNameSettingsKeys Do
			DeviceName = Common.CommonSettingsStorageLoad(
				"ScanningSettings1/DeviceName", SettingsKey, "", ,CurUser.Name);
			If ValueIsFilled(DeviceName) Then 
				StatisticsParameter = StatisticsParameters.Add();
				StatisticsParameter.ParameterName = "ImageScanning.Scanner." + DeviceName;
				StatisticsParameter.Count = 1;
			EndIf;
		EndDo;
		
		DevicesNameSettingsKeys = CommonSettingsStorage.GetList(
			"ScanningSettings1/ScannedImageFormat", CurUser.Name);
		For Each SettingsKey In DevicesNameSettingsKeys Do
			ScannedImageFormat = Common.CommonSettingsStorageLoad(
				"ScanningSettings1/ScannedImageFormat", 
				SettingsKey, "", ,CurUser.Name);
			If ValueIsFilled(ScannedImageFormat) Then 
				StatisticsParameter = StatisticsParameters.Add();
				StatisticsParameter.ParameterName = "ImageScanning.Scanner." + ScannedImageFormat;
				StatisticsParameter.Count = 1;
			EndIf;
		EndDo;
	EndDo;
	StatisticsParameters.GroupBy("ParameterName", "Count");
	
	For Each StatisticsParameter In StatisticsParameters Do
		ModuleMonitoringCenter.WriteConfigurationObjectStatistics(StatisticsParameter.ParameterName,
			StatisticsParameter.Count);
	EndDo;
	
EndProcedure

// See UsersOverridable.OnDefineRoleAssignment
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// BothForUsersAndExternalUsers.
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.AddEditFoldersAndFilesByExternalUsers.Name);
	
EndProcedure

// See PropertyManagerOverridable.OnGetPredefinedPropertiesSets.
Procedure OnGetPredefinedPropertiesSets(Sets) Export
	Set = Sets.Rows.Add();
	Set.Name = "Catalog_FilesFolders";
	Set.Id = New UUID("3f4bfd8d-b111-4416-8797-760b78f15910");
	
	Set = Sets.Rows.Add();
	Set.Name = "Catalog_Files";
	Set.Id = New UUID("f85ae5e1-0ff9-4c97-b2bb-d0996eacc6cf");
EndProcedure

// To migrate from SSL versions 2.3.7 and lower. It connects the AttachedFiles and StoredFiles
// subsystems.
//
Procedure OnDefineSubsystemsInheritance(Upload0, InheritingSubsystems) Export
	
	FilterByDeletedFiles = New Structure;
	FilterByDeletedFiles.Insert("Updated", True);
	FilterByDeletedFiles.Insert("DeletionMark", True);
	Trash = Upload0.FindRows(FilterByDeletedFiles);
	InheritingSubsystems = New Array;
	For Each Deleted In Trash Do
		If StrFind(Deleted.FullName, "Subsystem.StandardSubsystems.Subsystem.AttachedFiles") Then
			FilesOperationsString = Upload0.Find("Subsystem.StandardSubsystems.Subsystem.FilesOperations", "FullName");
			If FilesOperationsString <> Undefined Then
				InheritingSubsystems.Add(FilesOperationsString);
			EndIf;
			
			Break;
		EndIf;
	EndDo;
	
EndProcedure

// See also InfobaseUpdateOverridable.OnDefineSettings
//
// Parameters:
//  Objects - Array of MetadataObject
//
Procedure OnDefineObjectsWithInitialFilling(Objects) Export
	
	Objects.Add(Metadata.Catalogs.FilesFolders);
	
EndProcedure

// See DataExchangeOverridable.OnSetUpSubordinateDIBNode.
Procedure OnSetUpSubordinateDIBNode() Export

	FilesOperationsInVolumesInternal.FillFilesStorageSettings();

EndProcedure

// See SSLSubsystemsIntegration.OnDefineUsedAddIns.
Procedure OnDefineUsedAddIns(Components) Export

	NewRow = Components.Add();
	NewRow.Id = FilesOperationsInternalClientServer.ComponentDetails().ObjectName;
	NewRow.AutoUpdate = True;
	
EndProcedure

// 
Function IsTechnicalObject(FullObjectName) Export
	Return FullObjectName = Upper(Metadata.Catalogs.FilesVersions.FullName());
EndFunction

// See SSLSubsystemsIntegration.AfterAddChangeUserOrGroup
Procedure AfterAddChangeUserOrGroup(Ref, IsNew) Export

	TypeOf = TypeOf(Ref);
	ThisIsTheUser = TypeOf = Type("CatalogRef.Users")
						Or TypeOf = Type("CatalogRef.ExternalUsers");
	If IsNew And ThisIsTheUser Then
		// Clear catalog settings if they were copied from another user.
		FilesOperationsInternalServerCall.SetUserWorkingDirectory(Undefined, Ref);
	EndIf;

EndProcedure

// See MarkedObjectsDeletionOverridable.BeforeDeletingAGroupOfObjects
Procedure BeforeDeletingAGroupOfObjects(Context, ObjectsToDelete) Export
	Context.Insert("FilesToBeDeleted", New Array);
	
	For Each RemovableObject In ObjectsToDelete Do
		If Not Metadata.DefinedTypes.AttachedFile.Type.ContainsType(TypeOf(RemovableObject)) Then
			Continue;
		EndIf;
		
		AttachedFile = RemovableObject; // DefinedType.AttachedFile
		FilesStorageTyoe = Common.ObjectAttributeValue(AttachedFile, "FileStorageType");
		If FilesStorageTyoe = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			FileProperties = FilesOperationsInVolumesInternal.FilePropertiesInVolume(AttachedFile);
			FullFileName = FilesOperationsInVolumesInternal.FullFileNameInVolume(FileProperties);
			FilesToBeDeleted = Context.FilesToBeDeleted; // Array of String
			FilesToBeDeleted.Add(FullFileName);
		EndIf;
	EndDo;
EndProcedure

// See MarkedObjectsDeletionOverridable.AfterDeletingAGroupOfObjects
Procedure AfterDeletingAGroupOfObjects(Context, Success) Export
	If Not Success Then
		Return;
	EndIf;
	
	For Each File In Context.FilesToBeDeleted Do
		FilesOperationsInVolumesInternal.DeleteFile(File);
	EndDo;
EndProcedure

Function ScanningSettings(Name, Value, ClientID) Export
	
	Item = New Structure;
	Item.Insert("Object", "ScanningSettings1/" + Name);
	Item.Insert("Setting", ClientID);
	Item.Insert("Value", Value);
	Return Item;
	
EndFunction
#EndRegion

#EndRegion

#Region Private

#Region CleanUpUnusedFiles

Procedure ClearConfigurationFiles(Setting, ExceptionsArray)
	If Setting.Action = Enums.FilesCleanupOptions.NotClear Then
		Return;
	EndIf;
	
	UnusedFiles = CollectUnusedFiles(Setting, ExceptionsArray);
	ExceptionsArray.Add(Setting.FileOwner);
	ClearUnusedFilesData(UnusedFiles);
EndProcedure

// Parameters:
//  FileOwner - CatalogRef.MetadataObjectIDs
//  Setting - See InformationRegisters.FilesClearingSettings.CurrentClearSettings
//  ExceptionsArray - Array of DefinedType.FilesOwner
//  ExceptionItem -  Type - DefinedType.FilesOwner type.
// 
// Returns:
//  String
//
Function QueryTextToClearFiles(FileOwner, Setting, ExceptionsArray, ExceptionItem)
	
	FilesCatalogAttributes = Common.ObjectAttributesValues(Setting.FileOwnerType, "FullName, Name");
	
	FilesOwnerMedatada = Common.MetadataObjectByID(FileOwner);
	FilesOwnerFullName = FilesOwnerMedatada.FullName();
	
	FilesObjectMetadata = Common.MetadataObjectByID(Setting.FileOwnerType);
	HasAbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", FilesObjectMetadata);
	If HasAbilityToStoreVersions Then
		FilesVersionsCatalog = Common.MetadataObjectID(FilesObjectMetadata.Attributes.CurrentVersion.Type.Types()[0]);
		FilesVersionsMetadata = Common.MetadataObjectByID(FilesVersionsCatalog);
		FullFilesVersionsCatalogName = FilesVersionsMetadata.FullName();
		
		If Setting.ClearingPeriod <> Enums.FilesCleanupPeriod.ByRule Then
			QueryText = 
				"SELECT 
				|	VALUETYPE(Files.FileOwner) AS FileOwner,
				|	FilesVersions.Size / (1024 * 1024) AS Size,
				|	Files.Ref AS FileRef,
				|	FilesVersions.Ref AS VersionRef
				|FROM
				|	#FullFilesCatalogName AS Files
				|		INNER JOIN #FullFilesVersionsCatalogName AS FilesVersions
				|		ON Files.Ref = FilesVersions.Owner
				|WHERE
				|	FilesVersions.CreationDate <= &ClearingPeriod
				|	AND NOT Files.DeletionMark
				|	AND &ThisIsNotGroup
				|	AND VALUETYPE(Files.FileOwner) = &OwnerType
				|	AND CASE
				|			WHEN FilesVersions.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)
				|				THEN FilesVersions.Volume <> VALUE(Catalog.FileStorageVolumes.EmptyRef)
				|						OR (CAST(FilesVersions.PathToFile AS STRING(100))) <> """"
				|			ELSE TRUE
				|		END
				|	";

			QueryText = StrReplace(QueryText, "#FullFilesCatalogName", FilesCatalogAttributes.FullName);
			QueryText = StrReplace(QueryText, "#FullFilesVersionsCatalogName", FullFilesVersionsCatalogName);
		Else
			
			QueryText = 
				"SELECT 
				|	CatalogFileOwner.Ref,
				|	&Attributes,
				|	VALUETYPE(Files.FileOwner) AS FileOwner,
				|	FilesVersions.Size / (1024 * 1024) AS Size,
				|	Files.Ref AS FileRef,
				|	FilesVersions.Ref AS VersionRef
				|FROM
				|	#CatalogFileOwner AS CatalogFileOwner
				|	INNER JOIN #FullFilesCatalogName AS Files
				|		INNER JOIN #FullFilesVersionsCatalogName AS FilesVersions
				|		ON Files.Ref = FilesVersions.Owner
				|	ON CatalogFileOwner.Ref = Files.FileOwner
				|WHERE
				|	NOT Files.DeletionMark
				|	AND &ThisIsNotGroup
				|	AND NOT ISNULL(FilesVersions.DeletionMark, FALSE)
				|	AND CASE
				|			WHEN FilesVersions.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)
				|				THEN FilesVersions.Volume <> VALUE(Catalog.FileStorageVolumes.EmptyRef)
				|						OR (CAST(FilesVersions.PathToFile AS STRING(100))) <> """"
				|			ELSE TRUE
				|		END
				|	AND VALUETYPE(Files.FileOwner) = &OwnerType
				|";	
			
			QueryText = StrReplace(QueryText, "&Attributes" + ",", DetailsOfTheFileOwner(FileOwner));
			QueryText = StrReplace(QueryText, "#FullFilesVersionsCatalogName", FullFilesVersionsCatalogName);
			QueryText = StrReplace(QueryText, "#FullFilesCatalogName", FilesCatalogAttributes.FullName);
			QueryText = StrReplace(QueryText, "#CatalogFileOwner", FilesOwnerFullName);
		EndIf;
	
	Else // Not HasAbilityToStoreVersions
	
		If Setting.ClearingPeriod <> Enums.FilesCleanupPeriod.ByRule Then
			QueryText = 
			"SELECT
			|	VALUETYPE(Files.FileOwner) AS FileOwner,
			|	Files.Size / (1024 * 1024) AS Size,
			|	Files.Ref AS FileRef
			|FROM
			|	#FileOwnerType AS Files
			|		INNER JOIN #CatalogFileOwner AS CatalogFileOwner
			|		ON Files.FileOwner = CatalogFileOwner.Ref
			|WHERE
			|	Files.CreationDate <= &ClearingPeriod
			|	AND NOT Files.DeletionMark
			|	AND &ThisIsNotGroup
			|	AND CASE
			|			WHEN Files.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)
			|				THEN (CAST(Files.PathToFile AS STRING(100))) <> """"
			|						OR NOT Files.Volume = VALUE(Catalog.FileStorageVolumes.EmptyRef)
			|			ELSE TRUE
			|		END
			|	AND VALUETYPE(Files.FileOwner) = &OwnerType
			|	";

			QueryText = StrReplace(QueryText, "#FileOwnerType", "Catalog." + FilesCatalogAttributes.Name);
			QueryText = StrReplace(QueryText, "#CatalogFileOwner", FilesOwnerFullName);
		Else
			
			QueryText = 
			"SELECT
			|	CatalogFileOwner.Ref,
			|	VALUETYPE(Files.FileOwner) AS FileOwner,
			|	Files.Size / (1024 * 1024) AS Size,
			|	&Attributes,
			|	Files.Ref AS FileRef
			|FROM
			|	#FullFilesCatalogName AS Files
			|		LEFT JOIN #CatalogFileOwner AS CatalogFileOwner
			|		ON Files.FileOwner = CatalogFileOwner.Ref
			|WHERE
			|	NOT Files.DeletionMark
			|	AND &ThisIsNotGroup
			|	AND CASE
			|			WHEN Files.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)
			|				THEN (CAST(Files.PathToFile AS STRING(100))) <> """"
			|						OR NOT Files.Volume = VALUE(Catalog.FileStorageVolumes.EmptyRef)
			|			ELSE TRUE
			|		END
			|	AND VALUETYPE(Files.FileOwner) = &OwnerType";
			QueryText = StrReplace(QueryText, "&Attributes" + ",", DetailsOfTheFileOwner(FileOwner));
			QueryText = StrReplace(QueryText, "#FullFilesCatalogName", FilesCatalogAttributes.FullName);
			QueryText = StrReplace(QueryText, "#CatalogFileOwner", FilesOwnerFullName);
		EndIf;
	EndIf;
	
	If ExceptionsArray.Count() > 0 Then
		QueryText = QueryText + "
		|	AND NOT Files.FileOwner IN HIERARCHY (&ExceptionsArray)"; // @query-part
	EndIf;
	If ExceptionItem <> Undefined Then
		QueryText = QueryText + "
		|	AND Files.FileOwner IN HIERARCHY (&ExceptionItem)"; // @query-part
	EndIf;
	If HasAbilityToStoreVersions And Setting.Action = Enums.FilesCleanupOptions.CleanUpVersions Then
		QueryText =  QueryText + "
		|	AND FilesVersions.Ref <> Files.CurrentVersion
		|	AND FilesVersions.ParentVersion <> VALUE(Catalog.FilesVersions.EmptyRef)"; // @query-part
	EndIf;
	QueryText = StrReplace(QueryText, "&ThisIsNotGroup", 
		?(FilesObjectMetadata.Hierarchical, "NOT Files.IsFolder", "TRUE")); // @query-part
	
	Return QueryText;
	
EndFunction

// Returns the file cleanup mode.
// 
// Returns:
//  EnumRef.FilesCleanupModes
//
Function FilesCleanupMode() Export
	Mode = Constants.FilesCleanupMode.Get();
	If Not ValueIsFilled(Mode) Then
		Filter = New Structure;
		Filter.Insert("Metadata", Metadata.ScheduledJobs.CleanUpUnusedFiles);
		Job = ScheduledJobsServer.FindJobs(Filter);
		If Job.Count() > 0 Then
			Job = Job[0];
			Mode = ?(Job.Use, Enums.FilesCleanupModes.CleanUpDeletedAndUnusedFiles, Enums.FilesCleanupModes.NotClear);
		Else
			Mode = Enums.FilesCleanupModes.NotClear;
		EndIf;
	EndIf;
	
	Return Mode;
EndFunction

// Sets the FilesCleanupMode constant value and use of the scheduled job.
// 
// Parameters:
//  Mode - EnumRef.FilesCleanupModes
//
Procedure SetTheFileCleaningMode(Mode) Export
	AutomaticallyCleanUpUnusedFiles = ?(Mode = Enums.FilesCleanupModes.NotClear, False, True);
	Constants.FilesCleanupMode.Set(Mode);
	
	JobParameters = New Structure;
	JobParameters.Insert("Metadata", Metadata.ScheduledJobs.CleanUpUnusedFiles);
	If Not Common.DataSeparationEnabled() Then
		JobParameters.Insert("MethodName", Metadata.ScheduledJobs.CleanUpUnusedFiles.MethodName);
	EndIf;
	
	SetPrivilegedMode(True);
	
	JobsList = ScheduledJobsServer.FindJobs(JobParameters);
	ParameterName = "Use";
	If JobsList.Count() = 0 Then
		JobParameters.Insert(ParameterName, AutomaticallyCleanUpUnusedFiles);
		ScheduledJobsServer.AddJob(JobParameters);
	Else
		JobParameters = New Structure(ParameterName, AutomaticallyCleanUpUnusedFiles);
		For Each Job In JobsList Do
			ScheduledJobsServer.ChangeJob(Job, JobParameters);
		EndDo;
	EndIf;
EndProcedure

Procedure WriteToEventLogCleanupFiles(Val MessageText, Val Level = Undefined,
	AttachedFile = Undefined)

	If Level = Undefined Then
		Level = EventLogLevel.Information;
	EndIf;
	WriteLogEvent(LogEventRegistrationClearFiles(), 
		Level, ?(AttachedFile <> Undefined, AttachedFile.Metadata(), Undefined),
		AttachedFile, MessageText);
	
EndProcedure

Function LogEventRegistrationClearFiles()
	
	Return NStr("en = 'Files.File cleanup';", Common.DefaultLanguageCode());
	
EndFunction

#EndRegion

// Binary data from the file information.
// 
// Parameters:
//  FileInfo1 - See FilesOperationsClientServer.FileInfo1
// 
// Returns:
//  BinaryData
//
Function BinaryDataFromFileInformation(FileInfo1) Export
	TypeOf = TypeOf(FileInfo1.TempFileStorageAddress);
	If TypeOf = Type("BinaryData") Then
		Return FileInfo1.TempFileStorageAddress;
	ElsIf IsTempStorageURL(FileInfo1.TempFileStorageAddress) Then
		Return GetFromTempStorage(FileInfo1.TempFileStorageAddress);
	Else
		Raise NStr("en = 'Not supported file storage type.';");
	EndIf;
EndFunction

// Information about the files being cleaned.
// 
// Returns:
//  Structure:
//   * TheAmountOfFilesBeingDeleted - Number - Size in MB. For the report result, See Reports.VolumeIntegrityCheck.
//   * IrrelevantFilesVolume - Number - Size in MB. For the report result, See Reports.IrrelevantFilesVolume.
//
Function InformationAboutFilesToBeCleaned() Export
	Result = New Structure;
	Result.Insert("TheAmountOfFilesBeingDeleted", 0);
	Result.Insert("IrrelevantFilesVolume", 0);
	
	UnusedFilesTable = Reports.IrrelevantFilesVolume.UnusedFilesTable();
	UnusedFilesTable.GroupBy(,"IrrelevantFilesVolume");
	Result.IrrelevantFilesVolume = ?(UnusedFilesTable.Count() > 0, 
		UnusedFilesTable[0].IrrelevantFilesVolume, 0);
	
	Volumes = FilesOperationsInVolumesInternal.AvailableVolumes();
	UnnecessaryFiles = FilesOperationsInVolumesInternal.UnnecessaryFilesOnHardDrive();
	For Each Volume In Volumes Do
		FilesOperationsInVolumesInternal.FillInExtraFiles(UnnecessaryFiles, Volume);
	EndDo;
	
	For Each ExtraFile In UnnecessaryFiles Do
		File = New File(ExtraFile.FullName);
		
		If File.Exists() Then
			Result.TheAmountOfFilesBeingDeleted = Result.TheAmountOfFilesBeingDeleted + File.Size();
		EndIf;
	EndDo;
	
	Result.TheAmountOfFilesBeingDeleted = Result.TheAmountOfFilesBeingDeleted / 1024 / 1024;
	
	Return Result;
EndFunction

// Returns a path to a user working directory in settings.
//
// Returns:
//  String - a directory name.
//
Function UserWorkingDirectory()
	
	SetPrivilegedMode(True);
	DirectoryName = Common.CommonSettingsStorageLoad("LocalFileCache", "PathToLocalFileCache");
	If DirectoryName = Undefined Then
		DirectoryName = "";
	EndIf;
	
	Return DirectoryName;
	
EndFunction

// Returns the URL to the file (to an attribute or temporary storage).
//
// Parameters:
//  FileRef             -  DefinedType.AttachedFile
//  UUID - UUID
// 
// Returns:
//   See FilesOperationsInternalServerCall.GetURLToOpen
//
Function FileURL2(FileRef, UUID) Export
	
	If IsFilesOperationsItem(FileRef) Then
		Return FilesOperationsInternalServerCall.GetURLToOpen(FileRef, UUID);
	EndIf;
	
	Return Undefined;
	
EndFunction

// On write subscription handler of the attachment.
//
Procedure OnWriteAttachedFileServer(FilesOwner, Source) Export
	
	SetPrivilegedMode(True);
	BeginTransaction();
	Try
	
		RecordChanged = False;
		
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.InformationRegisters.FilesExist.FullName());
		DataLockItem.SetValue("ObjectWithFiles", FilesOwner);
		DataLock.Lock();
		
		RecordManager = InformationRegisters.FilesExist.CreateRecordManager();
		RecordManager.ObjectWithFiles = FilesOwner;
		RecordManager.Read();
		
		If Not ValueIsFilled(RecordManager.ObjectWithFiles) Then
			RecordManager.ObjectWithFiles = FilesOwner;
			RecordChanged = True;
		EndIf;
		
		IsInternalFile = False;
		If Common.HasObjectAttribute("IsInternal",Source.Metadata()) Then
			IsInternalFile = Source.IsInternal;	
		EndIf;
		
		HasFiles = Not Source.DeletionMark And Not IsInternalFile Or OwnerHasFiles(FilesOwner);
		If RecordManager.HasFiles <> HasFiles Then
			RecordManager.HasFiles = HasFiles;
			RecordChanged = True;
		EndIf;
		
		If IsBlankString(RecordManager.ObjectID) Then
			RecordManager.ObjectID = GetNextObjectID();
			RecordChanged = True;
		EndIf;
		
		If RecordChanged Then
			RecordManager.Write();
		EndIf;
		
		If Not Source.IsFolder Then
			RecordManager = InformationRegisters.FilesInfo.CreateRecordManager();
			FillPropertyValues(RecordManager, Source);
			RecordManager.File = Source.Ref;
			If Source.SignedWithDS And Source.Encrypted Then
				RecordManager.SignedEncryptedPictureNumber = 2;
			ElsIf Source.Encrypted Then
				RecordManager.SignedEncryptedPictureNumber = 1;
			ElsIf Source.SignedWithDS Then
				RecordManager.SignedEncryptedPictureNumber = 0;
			Else
				RecordManager.SignedEncryptedPictureNumber = -1;
			EndIf;
			
			RecordManager.Write();
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// To pass a file directory path to the OnSendFileData handler.
//
Procedure SaveSetting(ObjectKey, SettingsKey, Settings) 
	
	SetPrivilegedMode(True);
	CommonSettingsStorage.Save(ObjectKey, SettingsKey, Settings);
	
EndProcedure

// For internal use only.
//
// Parameters:
//   DataElement - DocumentObject
//                 - CatalogObject
//                 - ChartOfCalculationTypesObject
//                 - ChartOfCharacteristicTypesObject
//                 - InformationRegisterRecordSet
//                 - AccumulationRegisterRecordSet
//                 - AccountingRegisterRecordSet
//                 - BusinessProcessObject
//                 - TaskObject
//   ItemSend - DataItemSend
//  InitialImageCreating - Boolean
//   Recipient - ExchangePlanRef
//
Procedure WhenSendingFile(DataElement, ItemSend, Val InitialImageCreating = False, Recipient = Undefined)
	
	// For non-DIB data exchanges, use a regular exchange session algorithm. Do not use the initial image creation algorithm
	// because "InitialImageCreating" that is set to "True" means the initial data export.
	If InitialImageCreating And Recipient <> Undefined 
		And Not IsDistributedInfobaseNode(Recipient.Ref) Then
		InitialImageCreating = False;
	EndIf;
	
	If ItemSend = DataItemSend.Delete
		Or ItemSend = DataItemSend.Ignore Then
		
		// No overriding for a standard data processor.
		
	Else
		
		If InitialImageCreating Then
			WhenSendingAFileCreateTheInitialImage(DataElement, ItemSend, Recipient);
		Else	
			WhenSendingAFileTheMessageIsExchanged(DataElement, ItemSend, Recipient);
		EndIf;
		
	EndIf
		
EndProcedure

// Parameters:
//   DataElement - See WhenSendingFile.DataElement
//   ItemSend - See WhenSendingFile.ItemSend
//   Recipient - See WhenSendingFile.Recipient
//
Procedure WhenSendingAFileCreateTheInitialImage(DataElement, ItemSend, Recipient);

	// Modifying objects during the initial image generation is prohibited.
	// Therefore, export the files to a separate volume (unless they are stored in the infobase).
	// 
	
	FileType = TypeOf(DataElement);
	IsFilesOperationsItem = IsFilesOperationsItem(DataElement);

	If FileType = Type("InformationRegisterRecordSet.FileRepository")
		Or FileType = Type("CatalogObject.BinaryDataStorage") Then
			
		// Files are stored in the infobase.
		// Do not override the standard data processor.
		Return;
		
	ElsIf IsFilesOperationsItem 
			And FileType <> Type("CatalogObject.MetadataObjectIDs") Then
			
		If DataElement.FileStorageType <> Enums.FileStorageTypes.InVolumesOnHardDrive Then
			
		// Files are stored in the infobase.
		// Do not override the standard data processor.

			Return;
		Else
			
			// Files with versions
			// Files in the "AttachedFiles" catalogs
			// Copy the files from the volume to the initial image directory.
			NewFilePath1 = CommonClientServer.GetFullFileName(
								String(CommonSettingsStorage.Load("FileExchange", "TempDirectory")),
								DataElement.Ref.Metadata().Name + "." + DataElement.Ref.UUID());
				
			Try
				// File data can be cleared.
				FilesOperationsInVolumesInternal.CopyAttachedFile(DataElement.Ref, NewFilePath1);
			Except
				ErrorMessage = NStr("en = 'Cannot copy file data to the temporary directory.';") 
									+ Chars.LF + Chars.LF 
									+ ErrorProcessing.DetailErrorDescription(ErrorInfo());
									
				WriteLogEvent(EventLogEventForExchange(), 
					EventLogLevel.Warning, 
					DataElement.Ref.Metadata(), 
					DataElement.Ref, 
					ErrorMessage);
			EndTry;
		EndIf;
	EndIf;

EndProcedure

// Parameters:
//   DataElement - See WhenSendingFile.DataElement
//   ItemSend - See WhenSendingFile.ItemSend
//   Recipient - See WhenSendingFile.Recipient
//
Procedure WhenSendingAFileTheMessageIsExchanged(DataElement, ItemSend, Recipient);

	If TypeOf(DataElement) = Type("InformationRegisterRecordSet.FileRepository")
		Or TypeOf(DataElement) = Type("CatalogObject.BinaryDataStorage") Then
		// Files are stored in the register.
		// Export the register if the initial image is being created.
		ItemSend = DataItemSend.Ignore;

	ElsIf IsFilesOperationsItem(DataElement)
			And TypeOf(DataElement) <> Type("CatalogObject.MetadataObjectIDs") Then
			
		ProcessFileSendingByStorageType(DataElement);
	EndIf;

EndProcedure

// For internal use only.
//
// Parameters:
//   Sender - ExchangePlanRef
//
Procedure WhenReceivingFile(DataElement, ItemReceive, Sender = Undefined)
	
	ProcessReceivedFiles = False;
	If ItemReceive = DataItemReceive.Ignore Then
		
		// No overriding for a standard data processor.
		
	ElsIf TypeOf(DataElement) = Type("CatalogObject.Files") Then
		
		If GetFileProhibited(DataElement) Then
			ItemReceive = DataItemReceive.Ignore;
			Return;
		EndIf;
		
		// Process the file data only if it has no versions.
		// Otherwise, process binary data when handling file versions.
		StoreVersions = DataElement.StoreVersions;
		ProcessReceivedFiles = Not StoreVersions;
		
	ElsIf TypeOf(DataElement) = Type("CatalogObject.FilesVersions")
		Or (IsFilesOperationsItem(DataElement)
			And TypeOf(DataElement) <> Type("CatalogObject.MetadataObjectIDs")) Then
		
		// The catalog "MetadataObjectIDs" can iterate through the results of "IsFilesOperationsItem".
		// However, it should not be processed here.
		If GetFileVersionProhibited(DataElement) Then
			ItemReceive = DataItemReceive.Ignore;
			Return;
		EndIf;
		ProcessReceivedFiles = True;
		
	EndIf;
	
	If ProcessReceivedFiles Then
		
		If Sender <> Undefined
			And ExchangePlans.IsChangeRecorded(Sender.Ref, DataElement) Then
			
			// Object collision (changes are registered both on the master node and on the subordinate one).
			ItemReceive = DataItemReceive.Ignore;
			Return;
		EndIf;
		
		If DataElement.IsFolder Then
			Return;
		EndIf;
		
		BinaryData = DataElement.FileStorage.Get();
		NewFileStorageType = FileStorageType(DataElement.Size, DataElement.Extension);
		DataElement.FileStorageType = NewFileStorageType;
		
		If Not DataElement.IsNew() Then
			StorageTypeOfThePreviousVersionOfTheFile = Common.ObjectAttributeValue(
													DataElement.Ref,
													"FileStorageType");
													
			If StorageTypeOfThePreviousVersionOfTheFile = Enums.FileStorageTypes.InVolumesOnHardDrive Then
				FileProperties = FilesOperationsInVolumesInternal.FilePropertiesInVolume(DataElement.Ref);
				
				If ValueIsFilled(FileProperties.Volume) Then
					PathToTheFile = FilesOperationsInVolumesInternal.FullFileNameInVolume(FileProperties);
					FilesOperationsInVolumesInternal.DeleteFile(PathToTheFile);
				
					DataElement.Volume = Catalogs.FileStorageVolumes.EmptyRef();
					DataElement.PathToFile = "";
				EndIf;
			Else
				SetPrivilegedMode(True);
				InformationRegisters.FileRepository.DeleteBinaryData(DataElement.Ref);
				SetPrivilegedMode(False);
			EndIf;
		EndIf;
		
		If NewFileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			
			// During the exchange, an item with the storage type "InInfobase," but the destination stores data in volumes.
			// Put the file from the internal attribute to a volume and set "FileStorageType" to "InVolumesOnHardDrive".
			MetadataType = Metadata.FindByType(TypeOf(DataElement));
			
			If BinaryData = Undefined Then
				
				DataElement.Volume = Undefined;
				DataElement.PathToFile = Undefined;
				
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Cannot add the file to a volume as the file does not exist.
								|The file might have been deleted by the antivirus software.
								|%1.';"),
								CommonClientServer.GetNameWithExtension(DataElement.Description, DataElement.Extension));
				
				WriteLogEvent(NStr("en = 'Files.Add file to volume';", Common.DefaultLanguageCode()),
					EventLogLevel.Error, MetadataType, DataElement.Ref, ErrorText);
				
			Else
				FilesOperationsInVolumesInternal.AppendFile(DataElement, BinaryData, , True);
			EndIf;
			
		Else
			
			If TypeOf(BinaryData) = Type("BinaryData") Then
				DataElement.AdditionalProperties.Insert("FileBinaryData", BinaryData);
			EndIf;
			
			DataElement.FileStorage = New ValueStorage(Undefined);
			DataElement.Volume = Catalogs.FileStorageVolumes.EmptyRef();
			DataElement.PathToFile = "";
			
		EndIf;
		
	EndIf;
	
EndProcedure


// Writes binary file data to the infobase.
//
// Parameters:
//  AttachedFile - DefinedType.AttachedFile - a reference to the attached file.
//  BinaryData     - BinaryData - to be written.
//
Procedure WriteFileToInfobase(Val AttachedFile, Val BinaryData) Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	InformationRegisters.FileRepository.WriteBinaryData(AttachedFile, BinaryData);
	
EndProcedure

// Returns new object ID.
// To receive a new ID it selects the last object ID
// from the AttachmentExistence register, increases its value
// by one unit and returns the result.
//
// Returns:
//  String - String - 10 characters
//
Function GetNextObjectID()
	
	// Calculate a new ID of an object.
	Result = "0000000000"; // Same length as for the ObjectID attribute.
	
	QueryText =
	"SELECT TOP 1
	|	FilesExist.ObjectID AS ObjectID
	|FROM
	|	InformationRegister.FilesExist AS FilesExist
	|
	|ORDER BY
	|	ObjectID DESC";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Id = Selection.ObjectID;
		
		If IsBlankString(Id) Then
			Return Result;
		EndIf;
		
		// The calculation rule is the same as for arithmetic addition: 
		// When a position reaches its maximum and then increments, it resets to 0, and the next position increments by 1.
		// A position can take values in the ranges [0…9] and [a…z], totaling 36 values.
		// 
		// 
		// 
		
		Position = 10; // 10th character's index is "9"
		While Position > 0 Do
			
			Char = Mid(Id, Position, 1);
			
			If Char = "z" Then
				Id = Left(Id, Position-1) + "0" + Right(Id, 10 - Position);
				Position = Position - 1;
				Continue;
				
			ElsIf Char = "9" Then
				NewChar = "a";
			Else
				NewChar = Char(CharCode(Char)+1);
			EndIf;
			
			Id = Left(Id, Position-1) + NewChar + Right(Id, 10 - Position);
			Break;
		EndDo;
		
		Result = Id;
	EndIf;
	
	Return Result;
	
EndFunction

// See FilesOperationsInternalSaaS.UpdateTextExtractionQueueState.
Procedure UpdateTextExtractionQueueState(TextSource, TextExtractionState) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.FilesOperationsSaaS")
		And Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable() Then
			
		ModuleFilesOperationsInternalSaaS = Common.CommonModule("FilesOperationsInternalSaaS");
		ModuleFilesOperationsInternalSaaS.UpdateTextExtractionQueueState(TextSource, TextExtractionState);
		
	EndIf;
	
EndProcedure

// Saves a working directory of the folder to the information register.
// Parameters:
//  FolderRef  - CatalogRef.FilesFolders - file owner.
//  OwnerWorkingDirectory - String - a working directory of the folder.
//
Procedure SaveFolderWorkingDirectory(FolderRef, FolderWorkingDirectory) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.FileWorkingDirectories.CreateRecordSet();
	
	RecordSet.Filter.Folder.Set(FolderRef);
	RecordSet.Filter.User.Set(Users.AuthorizedUser());
	
	NewRecord = RecordSet.Add();
	NewRecord.Folder = FolderRef;
	NewRecord.User = Users.AuthorizedUser();
	NewRecord.Path = FolderWorkingDirectory;
	
	RecordSet.Write();
	
EndProcedure

// Clears a working directory of the folder in the information register.
// Parameters:
//  FolderRef  - CatalogRef.FilesFolders - file owner.
//
Procedure CleanUpWorkingDirectory(FolderRef) Export
	
	SetPrivilegedMode(True);
	
	CurrentUser = Users.AuthorizedUser();
	
	Block = New DataLock;
	
	LockItem = Block.Add("Catalog.FilesFolders");
	LockItem.SetValue("Parent", FolderRef);
	LockItem.Mode = DataLockMode.Shared;
	
	LockItem = Block.Add("InformationRegister.FileWorkingDirectories");
	LockItem.SetValue("User", CurrentUser);
	
	BeginTransaction();
	Try
		
		Block.Lock();
		
		RecordSet = InformationRegisters.FileWorkingDirectories.CreateRecordSet();
		RecordSet.Filter.Folder.Set(FolderRef);
		RecordSet.Filter.User.Set(CurrentUser);
		RecordSet.Write(); // delete records
		
		// Clear working directories for child folders.
		Query = New Query;
		Query.Text =
		"SELECT
		|	FilesFolders.Ref AS Ref
		|FROM
		|	Catalog.FilesFolders AS FilesFolders
		|WHERE
		|	FilesFolders.Parent = &Ref";
		
		Query.SetParameter("Ref", FolderRef);
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			CleanUpWorkingDirectory(Selection.Ref); // @skip-check query-in-loop - Recursive deletion of file records.
		EndDo;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure


#Region OtherProceduresAndFunctions

// Returns the catalog name for the specified owner or raises an exception
// if multiple catalogs are found.
// 
// Parameters:
//  FilesOwner  - AnyRef - an object for adding the file.
//  CatalogName  - String - If this parameter is filled, it checks
//                    for the catalog among the file owner storage catalogs.
//                    If it is not filled, returns the main catalog name.
//  ErrorTitle - String - an error title.
//                  - Undefined - do not throw an exception, return an empty string.
//  ParameterName - String - the name of a required parameter to determine the catalog name.
//  ErrorEnd - String - an error end (only for the case, when ParameterName = Undefined).
// 
// Returns:
//  String - catalog name
//
Function FileStoringCatalogName(FilesOwner, CatalogName = "",
	ErrorTitle = Undefined, ErrorEnd = Undefined) Export
	
	NotRaiseException1 = (ErrorTitle = Undefined);
	CatalogNames = FileStorageCatalogNames(FilesOwner, NotRaiseException1);
	
	If CatalogNames.Count() = 0 Then
		If NotRaiseException1 Then
			Return "";
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			ErrorTitle + Chars.LF
			+ NStr("en = 'File location ""%1"" of type ""%2""
			             |does not have file storage catalogs.';"),
			String(FilesOwner),
			String(TypeOf(FilesOwner)));
	EndIf;
	
	If ValueIsFilled(CatalogName) Then
		If CatalogNames[CatalogName] <> Undefined Then
			Return CatalogName;
		EndIf;
	
		If NotRaiseException1 Then
			Return "";
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			ErrorTitle + Chars.LF
			+ NStr("en = 'File location ""%1"" of type ""%2""
			             |does not have file storage catalog ""%3"".';"),
			String(FilesOwner),
			String(TypeOf(FilesOwner)),
			String(CatalogName));
	EndIf;
	
	DefaultCatalog = "";
	For Each KeyAndValue In CatalogNames Do
		If KeyAndValue.Value = True Then
			DefaultCatalog = KeyAndValue.Key;
			Break;
		EndIf;
	EndDo;
	
	If ValueIsFilled(DefaultCatalog) Then
		Return DefaultCatalog;
	EndIf;
		
	If NotRaiseException1 Then
		Return "";
	EndIf;
	
	ErrorReasonTemplate = 
		NStr("en = 'The main file storage catalog is not specified
			|for file owner ""%1"" of type ""%2"".';") + Chars.LF;
			
	ErrorReason = StringFunctionsClientServer.SubstituteParametersToString(
		ErrorReasonTemplate, String(FilesOwner), String(TypeOf(FilesOwner)));
		
	ErrorText = ErrorTitle + Chars.LF
		+ ErrorReason + Chars.LF
		+ ErrorEnd;
		
	Raise TrimAll(ErrorText);
	
EndFunction

// Returns the map of catalog names and Boolean values
// for the specified owner.
// 
// Parameters:
//  FilesOwner - AnyRef - an object for adding the file.
// 
// Returns:
//  Map of KeyAndValue:
//   * Key - String
//   * Value - Boolean
//
Function FilesVersionsStorageCatalogsNames(FilesOwner, NotRaiseException1 = False)
	
	If TypeOf(FilesOwner) = Type("Type") Then
		FilesOwnerType = FilesOwner;
	Else
		FilesOwnerType = TypeOf(FilesOwner);
	EndIf;
	
	OwnerMetadata = Metadata.FindByType(FilesOwnerType);
	
	CatalogNames = New Map;
	
	If Metadata.DefinedTypes.FilesOwner.Type.ContainsType(FilesOwnerType) Then
		CatalogNames.Insert("FilesVersions", True);
	EndIf;
	
	Return CatalogNames;
	
EndFunction

Function NamesOfCatalogsWithServiceFiles() 

	ObjectsWithFiles = Metadata.InformationRegisters.FilesExist.Dimensions.ObjectWithFiles.Type.Types();
	
	Result = New Array;
	Result.Add(Metadata.InformationRegisters.FilesExist.FullName());
	For Each ObjectWithFiles In ObjectsWithFiles Do
		CatalogNames = FileStorageCatalogNames(ObjectWithFiles, True);
				
		For Each KeyAndValue In CatalogNames Do
			
			CurrentCatalog = Metadata.Catalogs[KeyAndValue.Key];
			If ThereArePropsInternal(KeyAndValue.Key) = False Then
				Continue;
			EndIf;
			FullCatalogName = CurrentCatalog.FullName();
			If Result.Find(FullCatalogName) = Undefined Then
				Result.Add(FullCatalogName);
	       	EndIf;
		EndDo;
	EndDo;

	Return StrConcat(Result, ",");
	
EndFunction

// Returns the catalog name for the specified owner or raises an exception
// if multiple catalogs are found.
// 
// Parameters:
//  FilesOwner  - AnyRef - an object for adding the file.
//  CatalogName  - String - If this parameter is filled, it checks
//                    for the catalog among the file owner storage catalogs.
//                    If it is not filled, returns the main catalog name.
//  ErrorTitle - String - an error title.
//                  - Undefined - do not throw an exception, return an empty string.
//  ParameterName - String - the name of a required parameter to determine the catalog name.
//  ErrorEnd - String - an error end (only for the case, when ParameterName = Undefined).
// 
// Returns:
//  String - catalog name
//
Function FilesVersionsStorageCatalogName(FilesOwner, CatalogName = "",
	ErrorTitle = Undefined, ErrorEnd = Undefined) Export
	
	NotRaiseException1 = (ErrorTitle = Undefined);
	CatalogNames = FilesVersionsStorageCatalogsNames(FilesOwner, NotRaiseException1);
	
	If CatalogNames.Count() = 0 Then
		Return "";
	EndIf;
	
	DefaultCatalog = "";
	For Each KeyAndValue In CatalogNames Do
		If KeyAndValue.Value = True Then
			DefaultCatalog = KeyAndValue.Key;
			Break;
		EndIf;
	EndDo;
	
	If ValueIsFilled(DefaultCatalog) Then
		Return DefaultCatalog;
	EndIf;
		
	If NotRaiseException1 Then
		Return "";
	EndIf;
	
	ErrorReasonTemplate = 
		NStr("en = 'The main catalog to store file versions is not specified
			|for file owner ""%1"".';") + Chars.LF;
			
	ErrorReason = StringFunctionsClientServer.SubstituteParametersToString(
		ErrorReasonTemplate, String(FilesOwner));
		
	ErrorText = ErrorTitle + Chars.LF
		+ ErrorReason + Chars.LF
		+ ErrorEnd;
		
	Raise TrimAll(ErrorText);
	
EndFunction

// Cancels file editing.
//
// Parameters:
//  AttachedFile - DefinedType.AttachedFile
//                     - DefinedType.AttachedFileObject - a reference or 
//                     an object of the attachment that must be released.
//
Procedure UnlockFile(Val AttachedFile) Export
	
	BeginTransaction();
	Try
	
		If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
			DataLock              = New DataLock;
			DataLockItem       = DataLock.Add(Metadata.FindByType(TypeOf(AttachedFile)).FullName());
			DataLockItem.SetValue("Ref", AttachedFile);
			DataLock.Lock();
			FileObject1 = AttachedFile.GetObject();
		Else
			FileObject1 = AttachedFile;
		EndIf;
		
		If ValueIsFilled(FileObject1.BeingEditedBy) Then
			FileObject1.BeingEditedBy = Catalogs.Users.EmptyRef();
			FileObject1.Write();
		EndIf;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function LockedFilesCount(Val FileOwner = Undefined, Val BeingEditedBy = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
		"SELECT COUNT(1) AS Count
		|FROM
		|	InformationRegister.FilesInfo AS FilesInfo
		|WHERE
		|	FilesInfo.BeingEditedBy <> VALUE(Catalog.Users.EmptyRef)";
	
	If BeingEditedBy = Undefined Then 
		BeingEditedBy = Users.AuthorizedUser();
	EndIf;
		
	Query.Text = Query.Text + " AND FilesInfo.BeingEditedBy = &BeingEditedBy ";
	Query.SetParameter("BeingEditedBy", BeingEditedBy);
	
	If FileOwner <> Undefined Then 
		Query.Text = Query.Text + " AND FilesInfo.FileOwner = &FileOwner ";
		Query.SetParameter("FileOwner", FileOwner);
	EndIf;
	
	Selection = Query.Execute().Unload().UnloadColumn("Count");
	Return Selection[0];
	
EndFunction

// Compares 2 data composition selection items.
// Parameters:
//   Item1 - DataCompositionFilterItem
//            - DataCompositionFilterItemGroup - an item of conditional appearance of the list.
//   Item2 - DataCompositionFilterItem
//            - DataCompositionFilterItemGroup - an item of conditional appearance of the list.
//
// Returns:
//   Boolean - comparison result.
//
Function CompareFilterItems(Item1, Item2)
	
	If Item1.Use = Item2.Use
		And TypeOf(Item1) = TypeOf(Item2) Then
		
		If TypeOf(Item1) = Type("DataCompositionFilterItem") Then
			If Item1.ComparisonType <> Item2.ComparisonType
				Or Item1.LeftValue <> Item2.LeftValue
				Or Item1.RightValue <> Item2.RightValue Then
				Return False;
			EndIf;
		Else
			
			ItemsCount = Item1.Items.Count();
			If Item1.GroupType <> Item2.GroupType
				Or ItemsCount <> Item2.Items.Count() Then
				Return False;
			EndIf;
			
			For IndexOf = 0 To ItemsCount - 1 Do
				SubordinateItem1 = Item1.Items[IndexOf];
				SubordinateItem2 = Item2.Items[IndexOf];
				ItemsEqual = CompareFilterItems(SubordinateItem1, SubordinateItem2);
				
				If Not ItemsEqual Then
					Return ItemsEqual;
				EndIf;
			EndDo;
			
		EndIf;
	Else
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Generates a report for files with errors.
//
// Parameters:
//   ArrayOfFilesNamesWithErrors - Array of String - paths to files.
//
// Returns:
//  SpreadsheetDocument
//
Function FilesImportGenerateReport(ArrayOfFilesNamesWithErrors) Export
	
	Document = New SpreadsheetDocument;
	Template = Catalogs.Files.GetTemplate("ReportTemplate");
	
	HeaderArea_ = Template.GetArea("Title");
	HeaderArea_.Parameters.LongDesc = NStr("en = 'Cannot upload the following files:';");
	Document.Put(HeaderArea_);
	
	AreaRow = Template.GetArea("String");

	For Each Selection In ArrayOfFilesNamesWithErrors Do
		AreaRow.Parameters.Name1 = Selection.FileName;
		AreaRow.Parameters.Error = Selection.Error;
		Document.Put(AreaRow);
	EndDo;
	
	Report = New SpreadsheetDocument;
	Report.Put(Document);

	Return Report;
	
EndFunction

// Fills the conditional appearance of the file list.
//
// Parameters:
//   List - DynamicList
//
Procedure FillConditionalAppearanceOfFilesList(List) Export
	
	DCConditionalAppearance = List.SettingsComposer.Settings.ConditionalAppearance;
	DCConditionalAppearance.UserSettingID = "MainAppearance";
	
	Item = DCConditionalAppearance.Items.Add();
	Item.Use = True;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	FilterGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	
	Filter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	Filter.Use = True;
	Filter.ComparisonType = DataCompositionComparisonType.Filled;
	Filter.LeftValue = New DataCompositionField("BeingEditedBy");

	Filter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	Filter.Use = True;
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.LeftValue = New DataCompositionField("IsInternal");
	Filter.RightValue = False;
	
	If HasDuplicateItem(DCConditionalAppearance.Items, Item) Then
		DCConditionalAppearance.Items.Delete(Item);
	EndIf;
	
	Item = DCConditionalAppearance.Items.Add();
	Item.Use = True;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.FileLockedByCurrentUser);
	
	FilterGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	
	Filter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.Use = True;
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.LeftValue = New DataCompositionField("BeingEditedBy");
	Filter.RightValue = Users.AuthorizedUser();
	
	Filter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	Filter.Use = True;
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.LeftValue = New DataCompositionField("IsInternal");
	Filter.RightValue = False;
	
	If HasDuplicateItem(DCConditionalAppearance.Items, Item) Then
		DCConditionalAppearance.Items.Delete(Item);
	EndIf;
	
	Item = DCConditionalAppearance.Items.Add();
	Item.Use = True;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	Filter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.Use = True;
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.LeftValue = New DataCompositionField("IsInternal");
	Filter.RightValue = True;
	
	If HasDuplicateItem(DCConditionalAppearance.Items, Item) Then
		DCConditionalAppearance.Items.Delete(Item);
	EndIf;
	
EndProcedure

// Fills conditional appearance of the folder list.
//
// Parameters:
//   Folders - DynamicList
//
Procedure FillConditionalAppearanceOfFoldersList(Folders) Export
	
	DCConditionalAppearance = Folders.SettingsComposer.Settings.ConditionalAppearance;
	DCConditionalAppearance.UserSettingID = "MainAppearance";
	
	Item = DCConditionalAppearance.Items.Add();
	Item.Use = True;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	Filter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.Use = True;
	Filter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.LeftValue = New DataCompositionField("FolderSynchronizationEnabled");
	Filter.RightValue = True;
	
	If HasDuplicateItem(DCConditionalAppearance.Items, Item) Then
		DCConditionalAppearance.Items.Delete(Item);
	EndIf;
	
EndProcedure

// If there is a duplicate item in the list conditional appearance.
// Parameters:
//   Items - Array of ConditionalAppearanceItem - an item array of the list conditional appearance.
//   SearchItem - ConditionalAppearanceItem - an item of the list conditional appearance.
//
// Returns:
//   Boolean - there is a duplicate.
//
Function HasDuplicateItem(Items, SearchItem)
	
	For Each Item In Items Do
		If Item <> SearchItem Then
			
			If Item.Appearance.Items.Count() <> SearchItem.Appearance.Items.Count() Then
				Continue;
			EndIf;
			
			DifferentItemFound = False;
			
			// Iterating all appearance items, and if there is at least one different, click Continue.
			ItemsCount = Item.Appearance.Items.Count();
			For IndexOf = 0 To ItemsCount - 1 Do
				Item1 = Item.Appearance.Items[IndexOf]; // DataCompositionSettingsParameterValue
				Item2 = SearchItem.Appearance.Items[IndexOf]; // DataCompositionSettingsParameterValue
				
				If Item1.Use And Item2.Use Then
					If Item1.Parameter <> Item2.Parameter Or Item1.Value <> Item2.Value Then
						DifferentItemFound = True;
						Break;
					EndIf;
				EndIf;
			EndDo;
			
			If DifferentItemFound Then
				Continue;
			EndIf;
			
			If Item.Filter.Items.Count() <> SearchItem.Filter.Items.Count() Then
				Continue;
			EndIf;
			
			// Iterating all filter items, and if there is at least one different, click Continue.
			ItemsCount = Item.Filter.Items.Count();
			For IndexOf = 0 To ItemsCount - 1 Do
				Item1 = Item.Filter.Items[IndexOf];
				Item2 = SearchItem.Filter.Items[IndexOf];
				
				ItemsEqual = CompareFilterItems(Item1, Item2);
				If Not ItemsEqual Then
					DifferentItemFound = True;
					Break;
				EndIf;
				
			EndDo;
			
			If DifferentItemFound Then
				Continue;
			EndIf;
			
			// If you iterated all appearance and filter items and they are all the same, it is a duplicate.
			Return True;
			
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Executes PutInTempStorage (if the file is stored in a volume) and returns a required reference.
//
// Parameters:
//  VersionRef - CatalogRef.FilesVersions - file version.
//  FormIdentifier - UUID
//                     - Undefined - form UUID.
//  ThrowAnException - Boolean - throw an exception if the storage type is "In volumes"
//									 and an error occurred while receiving the file.
//
// Returns:
//   String - URL.
//
Function GetTemporaryStorageURL(VersionRef, FormIdentifier = Undefined, ThrowAnException = True) Export
	
	Address = "";
	FileStorageType = Common.ObjectAttributeValue(VersionRef, "FileStorageType");
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		BinaryData = FilesOperationsInVolumesInternal.FileData(VersionRef, ThrowAnException);
		Address = PutToTempStorage(BinaryData, FormIdentifier);
	Else
		BinaryData = Undefined;
		FileStorage1 = FilesOperations.FileFromInfobaseStorage(VersionRef);
		// If data is cleared, Storage = Undefined.
		If FileStorage1 <> Undefined Then
			BinaryData = FileStorage1.Get();
		EndIf;
		
		Address = PutToTempStorage(BinaryData, FormIdentifier);
	EndIf;
	
	Return Address;
	
EndFunction

// Returns:
//   Boolean
//
Function ShowSizeColumn() Export
	
	ShowSizeColumn = Common.CommonSettingsStorageLoad("ApplicationSettings", "ShowSizeColumn");
	If ShowSizeColumn = Undefined Then
		ShowSizeColumn = False;
		Common.CommonSettingsStorageSave("ApplicationSettings", "ShowSizeColumn", ShowSizeColumn);
	EndIf;
	
	Return ShowSizeColumn;
	
EndFunction

// Returns:
//   String
//
Function ErrorFileNotFoundInFileStorage(FileObject1)
	
	FileName = CommonClientServer.GetNameWithExtension(FileObject1.Description, FileObject1.Extension);
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot open file:
			|%1
			|that is attached to:
			|%2';"),
		FileName, Common.SubjectString(FileObject1.FileOwner));

	If FileObject1.DeletionMark Then
		ErrorText = ErrorText + Chars.LF + Chars.LF
			+ NStr("en = 'File is marked for deletion and cleaned up as unused.';");	
	ElsIf FileObject1.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		ErrorText = ErrorText + Chars.LF + Chars.LF
			+ NStr("en = 'File data is unavailable because the file might have been cleaned up as unused or deleted by the antivirus software.';");
	Else
		ErrorText = ErrorText + Chars.LF + Chars.LF
			+ NStr("en = 'File data is unavailable because the file might have been cleaned up as unused.';");
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Parameters:
//   FileObject1 - DefinedType.AttachedFileObject
//   RaiseException1 - Boolean
//
Procedure ReportErrorFileNotFound(FileObject1, RaiseException1) Export
	
	ErrorMessage = ErrorFileNotFoundInFileStorage(FileObject1);
	CriticalityOfTheError = ?(RaiseException1, EventLogLevel.Error, EventLogLevel.Warning);
	WriteLogEvent(NStr("en = 'Files.Open file';", Common.DefaultLanguageCode()),
		CriticalityOfTheError, FileObject1.Ref.Metadata(), FileObject1.Ref, ErrorMessage);
		
	If RaiseException1 Then
		Raise ErrorMessage;
	EndIf;
	
EndProcedure	

// Returns number ascending. The previous value is taken from the ScannedFilesNumbers information register.
//
// Parameters:
//   FileOwner - DefinedType.FilesOwner
//
// Returns:
//   Number  - new number for scanning.
//
Function GetNewNumberToScan(FileOwner) Export
	
	// Prepare a filter structure by dimensions.
	FilterStructure1 = New Structure;
	FilterStructure1.Insert("Owner", FileOwner);
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.ScannedFilesNumbers");
		LockItem.SetValue("Owner", FileOwner);
		Block.Lock();
	
		// Receive structure with the data of record resources.
		ResourcesStructure = InformationRegisters.ScannedFilesNumbers.Get(FilterStructure1);
		
		// Receive the max number from the register.
		Number = ResourcesStructure.Number;
		Number = Number + 1; // Increment by 1.
		
		SetSafeModeDisabled(True);
		SetPrivilegedMode(True);
		
		// Writing a new number to the register.
		RecordSet = InformationRegisters.ScannedFilesNumbers.CreateRecordSet();
		
		RecordSet.Filter.Owner.Set(FileOwner);
		
		NewRecord = RecordSet.Add();
		NewRecord.Owner = FileOwner;
		NewRecord.Number = Number;
		
		RecordSet.Write();
		
		SetPrivilegedMode(False);
		SetSafeModeDisabled(False);
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Number;
	
EndFunction

// Determines if there is optional attribute IsInternal in the catalog metadata.
//
// Parameters:
//  CatalogName - String - a catalog name in metadata.
//
// Returns:
//  Boolean - The Internal attribute availability.
//
Function ThereArePropsInternal(Val CatalogName) Export
	
	MetadataObject  = Metadata.Catalogs[CatalogName];
	AttributeInternal = MetadataObject.Attributes.Find("IsInternal");
	Return AttributeInternal <> Undefined;
	
EndFunction

// Parameters:
//  FileRef - CatalogRef.Files
// 
// Returns:
//  CatalogRef.FilesVersions
//
Function CurrentVersion(FileRef)
	Return Common.ObjectAttributeValue(FileRef, "CurrentVersion");
EndFunction

// Adds data composition filter items to dynamic file lists.
//
// Parameters:
//  List - DynamicList - a dynamic list to which filters will be added.
//
Procedure AddFiltersToFilesList(List) Export
	
	CommonClientServer.AddCompositionItem(List.Filter, "IsInternal", DataCompositionComparisonType.NotEqual, 
		True, "HideInternal", True);
	
	SetFilterByDeletionMark(List.Filter);
	
EndProcedure

// Changes the visibility of the attachment form items for external users to work.
// External users have access only to common file information and its characteristics.
//
// Parameters:
//  Form - ClientApplicationForm - a form, for which item visibility changes.
//  IsListForm - Boolean - indicates that procedure is called from the list form.
//
Procedure ChangeFormForExternalUser(Form, Val IsListForm = False) Export
	
	Items = Form.Items;
	If IsListForm Then
		Items.ListAuthor.Visible = False;
		Items.ListBeingEditedBy.Visible = False;
		Items.ListSignedEncryptedPictureNumber.Visible = False;
		If Items.Find("ListWasEditedBy") <> Undefined Then
			Items.ListWasEditedBy.Visible = False;
		EndIf;
	Else
		Items.FileCharacteristicsGroup.Visible = True;
		Items.AdditionalPageDataGroup.Visible = False;
		Items.FormDigitalSignatureAndEncryptionCommandsGroup.Visible = False;
	EndIf;
	
EndProcedure

Procedure SetFilterByDeletionMark(Area) Export
	
	CommonClientServer.AddCompositionItem(Area, "DeletionMark",
		DataCompositionComparisonType.Equal, False, "HideDeletionMarkByDefault", True,
		DataCompositionSettingsItemViewMode.Inaccessible);
	
EndProcedure

#EndRegion

#Region UserSettings

// Calculating ActionOnDoubleClick. If it is for the first time, setting the correct value.
//
// Returns:
//   String - double-click action.
//
Function ActionOnDoubleClick()
	
	HowToOpen = Common.CommonSettingsStorageLoad(
		"OpenFileSettings", "ActionOnDoubleClick");
	
	If HowToOpen = Undefined
	 Or HowToOpen = Enums.DoubleClickFileActions.EmptyRef() Then
		
		HowToOpen = Enums.DoubleClickFileActions.OpenFile;
		
		Common.CommonSettingsStorageSave(
			"OpenFileSettings", "ActionOnDoubleClick", HowToOpen);
	EndIf;
	
	If HowToOpen = Enums.DoubleClickFileActions.OpenFile Then
		Return "OpenFile";
	Else
		Return "OpenCard";
	EndIf;
	
EndFunction

// Calculating from the FilesVersionsComparisonMethod settings.
//
// Returns:
//   String - a method to compare file versions.
//
Function FileVersionsComparisonMethod()
	
	CompareMethod = Common.CommonSettingsStorageLoad(
		"FileComparisonSettings", "FileVersionsComparisonMethod");
	
	If CompareMethod = Enums.FileVersionsComparisonMethods.MicrosoftOfficeWord Then
		Return "MicrosoftOfficeWord";
		
	ElsIf CompareMethod = Enums.FileVersionsComparisonMethods.OpenOfficeOrgWriter Then
		Return "OpenOfficeOrgWriter";
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Returns the setting Ask the editing mode when opening file.
// Returns:
//   Boolean - Ask about the editing mode when opening a file.
//
Function PromptForEditModeOnOpenFile()
	PromptForEditModeOnOpenFile = 
		Common.CommonSettingsStorageLoad("OpenFileSettings", "PromptForEditModeOnOpenFile");
	If PromptForEditModeOnOpenFile = Undefined Then
		PromptForEditModeOnOpenFile = True;
		Common.CommonSettingsStorageSave("OpenFileSettings", "PromptForEditModeOnOpenFile", PromptForEditModeOnOpenFile);
	EndIf;
	
	Return PromptForEditModeOnOpenFile;
EndFunction

// Returns the setting -  mode when opening a file: view or edit.
//
// Returns:
//   String - mode when opening a file. Options: "View", "Edit".
//
Function FileOpeningOption()
	
	FileOpeningOption = 
		Common.CommonSettingsStorageLoad("OpenFileSettings", "FileOpeningOption");
	If FileOpeningOption = Undefined Then
		FileOpeningOption = "Open";
		Common.CommonSettingsStorageSave("OpenFileSettings", "FileOpeningOption", FileOpeningOption);
	EndIf;
	
	Return FileOpeningOption;
EndFunction

#EndRegion

#Region EncodingsOperations

// Returns a table of encoding names.
//
// Returns:
//   ValueList:
//     * Value - String - for example, "ibm852".
//     * Presentation - String - for example, "ibm852 (Central European DOS)".
//
Function Encodings() Export
	
	Return FilesOperationsInternalClientServer.Encodings();

EndFunction

#EndRegion

#Region AuxiliaryProceduresAndFunctions

// Marks a file as editable.
//
// Parameters:
//  AttachedFile - a reference or an Attachment object that must be marked.
//
Procedure BorrowFileToEditServer(Val AttachedFile, User = Undefined) Export
	
	BeginTransaction();
	Try
		If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(AttachedFile)).FullName());
			DataLockItem.SetValue("Ref", AttachedFile);
			DataLock.Lock();
			LockDataForEdit(AttachedFile);
			
			FileObject1 = AttachedFile.GetObject();
		Else
			FileObject1 = AttachedFile;
		EndIf;
		
		If User = Undefined Then
			FileObject1.BeingEditedBy = Users.AuthorizedUser();
		Else
			FileObject1.BeingEditedBy = User;
		EndIf;
		FileObject1.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure WriteFileDataToRegisterDuringExchange(Source)
	
	Var FileBinaryData;
	
	If Source.AdditionalProperties.Property("FileBinaryData", FileBinaryData) Then
		InformationRegisters.FileRepository.WriteBinaryData(Source.Ref, FileBinaryData);
		Source.AdditionalProperties.Delete("FileBinaryData");
	EndIf;
	
EndProcedure

Function GetFileProhibited(DataElement)
	
	Return DataElement.IsNew()
	      And Not CheckExtentionOfFileToDownload(DataElement.Extension, False);
	
EndFunction

Function GetFileVersionProhibited(DataElement)
	
	Return DataElement.IsNew()
	      And Not CheckExtentionOfFileToDownload(DataElement.Extension, False);
	
EndFunction

Procedure ProcessFileSendingByStorageType(DataElement)
	
	If DataElement.IsFolder Then
		Return;
	EndIf;
	
	If DataElement.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		
		// Place the file data from a volume to an internal attribute of the catalog.
		FilesOperationsInVolumesInternal.PutFileInCatalogAttribute(DataElement);
		
	Else
		// "Enums.FileStorageTypes.InInfobase"
		// If file versions are stored, take the binary data from the current version.
		If DataElement.Metadata().Attributes.Find("CurrentVersion") <> Undefined
			And ValueIsFilled(DataElement.CurrentVersion) Then
			BinaryDataSource = DataElement.CurrentVersion;
		Else
			BinaryDataSource = DataElement.Ref;
		EndIf;
		Try
			// Placing the file data from the infobase to an internal catalog attribute.
			AddressInTempStorage = GetTemporaryStorageURL(BinaryDataSource,,False);
			DataElement.FileStorage = New ValueStorage(GetFromTempStorage(AddressInTempStorage), New Deflation(9));
		Except
			// The file is probably not found. Resume the data export.
			// ACC:154-off - File data is missing (an ordinary situation).
			WriteLogEvent(EventLogEventForExchange(), 
				EventLogLevel.Warning,,, 
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			// ACC:154-on
			DataElement.FileStorage = New ValueStorage(Undefined);
		EndTry;
		
		DataElement.FileStorageType = Enums.FileStorageTypes.InInfobase;
		DataElement.PathToFile = "";
		DataElement.Volume = Catalogs.FileStorageVolumes.EmptyRef();
		
	EndIf;
	
EndProcedure

// Returns references to attachments for the given owner.
//
// Parameters:
//  FilesOwner - DefinedType.AttachedFile
//  ExceptMarkedForDeletion - Boolean
//
// Returns:
//  Array of DefinedType.AttachedFile
//
Function AttachedFilesToObject(Val FilesOwner, Val ExceptMarkedForDeletion = False) Export
	
	CatalogNames = FileStorageCatalogNames(FilesOwner, True);
	If CatalogNames.Count() = 0 Then
		Return New Array;
	EndIf;
	
	QueriesText = "";
	
	For Each KeyAndValue In CatalogNames Do
		
		If ValueIsFilled(QueriesText) Then
			
			QueriesText = QueriesText + "
			|UNION ALL
			|
			|";
			
		EndIf;
		
		QueryText =
		"SELECT
		|	AttachedFiles.Ref
		|FROM
		|	&CatalogName AS AttachedFiles
		|WHERE
		|	AttachedFiles.FileOwner = &FilesOwner";
		
		If Metadata.Catalogs[KeyAndValue.Key].Hierarchical = True Then
			QueryText = QueryText + "
				|	AND NOT AttachedFiles.IsFolder";
		EndIf;
		If ExceptMarkedForDeletion Then
			QueryText = QueryText + "
				|	AND NOT AttachedFiles.DeletionMark";
		EndIf;
		
		QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + KeyAndValue.Key);
		QueriesText = QueriesText + QueryText;
		
	EndDo;
	
	Query = New Query(QueriesText);
	Query.SetParameter("FilesOwner", FilesOwner);
	
	SetPrivilegedMode(True);
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Returns a string constant for generating event log messages.
//
// Returns:
//   String
//
Function EventLogEventForExchange() 
	
	Return NStr("en = 'Files.Cannot send file during data exchange';", Common.DefaultLanguageCode());
	
EndFunction

// Replaces the binary data of an infobase file with data in a temporary storage.
Procedure UpdateFileBinaryDataAtServer(Val AttachedFile,
	                                           Val FileAddressInBinaryDataTempStorage,
	                                           Val AttributesValues1 = Undefined)
	
	SetPrivilegedMode(True);
	IsReference = Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile));
	
	Context = FileUpdateContext(AttachedFile, FileAddressInBinaryDataTempStorage);
	FileManager = FilesManager(AttachedFile);
	FileManager.BeforeUpdatingTheFileData(Context);
	
	BeginTransaction();
	Try
		If IsReference Then
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(AttachedFile)).FullName());
			DataLockItem.SetValue("Ref", AttachedFile);
			DataLock.Lock();
			
			LockDataForEdit(AttachedFile);
			
			FileObject1 = AttachedFile.GetObject();
		Else
			FileObject1 = AttachedFile;
		EndIf;
		
		FileObject1.ChangedBy = Users.AuthorizedUser();
		
		If TypeOf(AttributesValues1) = Type("Structure") Then
			FillPropertyValues(FileObject1, AttributesValues1);
		EndIf;
		
		FileManager.BeforeWritingFileData(Context, FileObject1);
		FileObject1.Write();
		FileManager.WhenUpdatingFileData(Context, FileObject1.Ref);
		CommitTransaction();
		
	Except
		RollbackTransaction();
		FileManager.AfterUpdatingTheFileData(Context, False);
		Raise;
	EndTry;
	
	FileManager.AfterUpdatingTheFileData(Context, True);
	
EndProcedure

// Creates a version of the saved file to save to infobase.
//
// Parameters:
//   FileRef     - CatalogRef.Files - a file, for which a new version is created.
//   FileInfo1 - See FilesOperationsClientServer.FileInfo1
//   Context - See FileUpdateContext
//
// Returns:
//   CatalogRef.FilesVersions - created version.
//
Function CreateVersion(FileRef, FileInfo1, Context = Undefined) Export
	
	HasRightsToObject = Common.ObjectAttributesValues(FileRef, "Ref", True);
	If HasRightsToObject = Undefined Then
		Return Undefined;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(FileInfo1.ModificationTimeUniversal)
		Or FileInfo1.ModificationTimeUniversal > CurrentUniversalDate() Then
		
		FileInfo1.ModificationTimeUniversal = CurrentUniversalDate();
	EndIf;
	
	If Not ValueIsFilled(FileInfo1.Modified)
		Or ToUniversalTime(FileInfo1.Modified) > FileInfo1.ModificationTimeUniversal Then
		
		FileInfo1.Modified = CurrentSessionDate();
	EndIf;
	
	CheckExtentionOfFileToDownload(FileInfo1.ExtensionWithoutPoint);
	
	Version = Catalogs.FilesVersions.CreateItem();
	If FileInfo1.NewVersionVersionNumber = Undefined Then
		Version.VersionNumber = MaxVersionNumber(FileRef) + 1;
	Else
		Version.VersionNumber = FileInfo1.NewVersionVersionNumber;
	EndIf;
	
	Version.Owner                     = FileRef;
	Version.UniversalModificationDate = FileInfo1.ModificationTimeUniversal;
	Version.FileModificationDate         = FileInfo1.Modified;
	Version.Comment                  = FileInfo1.NewVersionComment;
	
	Version.PictureIndex = FilesOperationsInternalClientServer.IndexOfFileIcon(FileInfo1.ExtensionWithoutPoint);
	
	If FileInfo1.NewVersionAuthor = Undefined Then
		Version.Author = Users.AuthorizedUser();
	Else
		Version.Author = FileInfo1.NewVersionAuthor;
	EndIf;
	
	If FileInfo1.NewVersionCreationDate = Undefined Then
		Version.CreationDate = CurrentSessionDate();
	Else
		Version.CreationDate = FileInfo1.NewVersionCreationDate;
	EndIf;
	
	Version.Size             = FileInfo1.Size;
	Version.Extension         = CommonClientServer.ExtensionWithoutPoint(FileInfo1.ExtensionWithoutPoint);
	Version.Description       = FileInfo1.BaseName;
		
	FilesStorageTyoe = FileStorageType(Version.Size, Version.Extension);
	Version.FileStorageType = FilesStorageTyoe;

	If FileInfo1.RefToVersionSource <> Undefined Then // Creating file from template
		
		TemplateFilesStorageType = FileInfo1.RefToVersionSource.FileStorageType;
		If TemplateFilesStorageType = Enums.FileStorageTypes.InInfobase
			And FilesStorageTyoe = Enums.FileStorageTypes.InInfobase Then
			
			// Both the template and the new file are located in the infobase.
			// When a "File" instance is created, the value is copied directly from the template storage.
			BinaryDataOrPath = FileInfo1.TempFileStorageAddress.Get();
			
		ElsIf TemplateFilesStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive
			And FilesStorageTyoe = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			
			//  If the template and the new file are in the volume, just copy the file.
			If Not FileInfo1.RefToVersionSource.Volume.IsEmpty() Then
				FullTemplateFilePath = FilesOperationsInVolumesInternal.FullFileNameInVolume(
					FilesOperationsInVolumesInternal.FilePropertiesInVolume(FileInfo1.RefToVersionSource));
				FilesOperationsInVolumesInternal.AppendFile(Version, FullTemplateFilePath);
			EndIf;
			
		ElsIf TemplateFilesStorageType = Enums.FileStorageTypes.InInfobase
			And FilesStorageTyoe = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			
			// The template is located in the infobase, the new file is located in a volume.
			// In this case, "TempFileStorageAddress" takes the value from the file's "ValueStorage".
			FilesOperationsInVolumesInternal.AppendFile(Version, FileInfo1.TempFileStorageAddress.Get());
			
		ElsIf TemplateFilesStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive
			And FilesStorageTyoe = Enums.FileStorageTypes.InInfobase Then
			
			// The template is in the volume and the new file is in the infobase.
			If Not FileInfo1.RefToVersionSource.Volume.IsEmpty() Then
				BinaryDataOrPath = FilesOperationsInVolumesInternal.FileData(FileInfo1.RefToVersionSource);
			EndIf;
			
		EndIf;
	Else // Create the File object based on the selected file from the computer.
		
		If IsTempStorageURL(FileInfo1.TempFileStorageAddress) Then
			
			BinaryDataOrPath = GetFromTempStorage(FileInfo1.TempFileStorageAddress); // BinaryData
			
			If Version.Size = 0 Then
				Version.Size = BinaryDataOrPath.Size();
				CheckFileSizeForImport(Version);
			EndIf;
			
			If FilesStorageTyoe = Enums.FileStorageTypes.InVolumesOnHardDrive Then
				If Context <> Undefined Then
					FillPropertyValues(Version, Context.AttributesToChange);
				Else
					FilesOperationsInVolumesInternal.AppendFile(Version, BinaryDataOrPath);
				EndIf;
				
			EndIf;
			
		Else
			
			BinaryDataOrPath = FileInfo1.TempFileStorageAddress;
			FillPropertyValues(Version, FileRef, "Volume, PathToFile");
			
		EndIf;
		
	EndIf;
	
	Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	If Metadata.Catalogs.FilesVersions.FullTextSearch = FullTextSearchUsing Then
		If TypeOf(FileInfo1.TempTextStorageAddress) = Type("ValueStorage") Then
			// When creating a File from a template, the value storage is copied directly.
			Version.TextStorage = FileInfo1.TempTextStorageAddress;
			Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		ElsIf Not IsBlankString(FileInfo1.TempTextStorageAddress) Then
			TextExtractionResult = ExtractText1(FileInfo1.TempTextStorageAddress);
			Version.TextStorage = TextExtractionResult.TextStorage;
			Version.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
		EndIf;
	EndIf;
	
	Version.Fill(Undefined);
	Version.Write();
	
	If FilesStorageTyoe = Enums.FileStorageTypes.InInfobase Then
		WriteFileToInfobase(Version.Ref, BinaryDataOrPath);
	EndIf;
	
	Return Version.Ref;
	
EndFunction

// Updates file properties without considering versions, which are binary data, text, modification date,
// and also other optional properties.
//
Procedure RefreshFile(FileInfo, AttachedFile) Export
	
	CommonClientServer.CheckParameter("FilesOperations.FileBinaryData", "AttachedFile", 
		AttachedFile, Metadata.DefinedTypes.AttachedFile.Type);
	
	AttributesValues1 = New Structure;
	
	If FileInfo.Property("BaseName") And ValueIsFilled(FileInfo.BaseName) Then
		AttributesValues1.Insert("Description", FileInfo.BaseName);
	EndIf;
	
	If Not FileInfo.Property("UniversalModificationDate")
		Or Not ValueIsFilled(FileInfo.UniversalModificationDate)
		Or FileInfo.UniversalModificationDate > CurrentUniversalDate() Then
		
		// Filling current date in the universal time format.
		AttributesValues1.Insert("UniversalModificationDate", CurrentUniversalDate());
	Else
		AttributesValues1.Insert("UniversalModificationDate", FileInfo.UniversalModificationDate);
	EndIf;
	
	If FileInfo.Property("BeingEditedBy") Then
		AttributesValues1.Insert("BeingEditedBy", FileInfo.BeingEditedBy);
	EndIf;
	
	If FileInfo.Property("Extension") Then
		AttributesValues1.Insert("Extension", FileInfo.Extension);
	EndIf;
	
	If FileInfo.Property("Encoding") And Not IsBlankString(FileInfo.Encoding) Then
		InformationRegisters.FilesEncoding.WriteFileVersionEncoding(AttachedFile, FileInfo.Encoding);
	EndIf;
	
	BinaryData = GetFromTempStorage(FileInfo.FileAddressInTempStorage);
	
	FileMetadata = Metadata.FindByType(TypeOf(AttachedFile));
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	If FileMetadata.FullTextSearch = FullTextSearchUsing Then
		TextExtractionResult = ExtractText1(FileInfo.TempTextStorageAddress, BinaryData,
			AttachedFile.Extension);
		AttributesValues1.Insert("TextExtractionStatus", TextExtractionResult.TextExtractionStatus);
		AttributesValues1.Insert("TextStorage", TextExtractionResult.TextStorage);
	Else
		AttributesValues1.Insert("TextExtractionStatus", Enums.FileTextExtractionStatuses.NotExtracted);
		AttributesValues1.Insert("TextStorage", New ValueStorage(""));
	EndIf;
	
	UpdateFileBinaryDataAtServer(AttachedFile, BinaryData, AttributesValues1);
	
EndProcedure

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
Function UpdateFileVersion(FileRef,
	FileInfo1,
	VersionRef = Undefined,
	FormUniqueID = Undefined,
	User = Undefined) Export
	
	HasSaveRight = AccessRight("SaveUserData", Metadata);
	HasRightsToObject = Common.ObjectAttributesValues(FileRef, "Ref", True);
	If HasRightsToObject = Undefined Then
		Return Undefined;
	EndIf;
	
	SetPrivilegedMode(True);
	
	ModificationTimeUniversal = FileInfo1.ModificationTimeUniversal;
	If Not ValueIsFilled(ModificationTimeUniversal)
		Or ModificationTimeUniversal > CurrentUniversalDate() Then
		ModificationTimeUniversal = CurrentUniversalDate();
	EndIf;
	
	Modified = FileInfo1.Modified;
	If Not ValueIsFilled(Modified)
		Or ToUniversalTime(Modified) > ModificationTimeUniversal Then
		Modified = CurrentSessionDate();
	EndIf;
	
	CheckExtentionOfFileToDownload(FileInfo1.ExtensionWithoutPoint);
	
	BinaryData = Undefined;
	ObjectMetadata = Metadata.FindByType(TypeOf(FileRef));
	AbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", ObjectMetadata);
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	
	VersionRefToCompareSize = VersionRef;
	If VersionRef <> Undefined Then
		VersionRefToCompareSize = VersionRef;
	ElsIf AbilityToStoreVersions And ValueIsFilled(CurrentVersion(FileRef))Then
		VersionRefToCompareSize = CurrentVersion(FileRef);
	Else
		VersionRefToCompareSize = FileRef;
	EndIf;
	
	PreVersionEncoding = InformationRegisters.FilesEncoding.FileVersionEncoding(VersionRefToCompareSize);
	
	AttributesStructure1 = Common.ObjectAttributesValues(VersionRefToCompareSize, 
		"Size, FileStorageType, Volume, PathToFile");
	
	FileStorage1 = Undefined;
	If FileInfo1.Size = AttributesStructure1.Size Then
		
		If AttributesStructure1.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			PreviousVersionBinaryData = FilesOperationsInVolumesInternal.FileData(VersionRefToCompareSize, False);
		Else
			FileStorage1 = FilesOperations.FileFromInfobaseStorage(VersionRefToCompareSize);
			PreviousVersionBinaryData = FileStorage1.Get();
		EndIf;
		
		BinaryData = GetFromTempStorage(FileInfo1.TempFileStorageAddress);
		
		If PreviousVersionBinaryData = BinaryData Then
			Return Undefined; // If the file is not changed binary, returning False.
		EndIf;
		
	EndIf;
	
	BlockVersion = False;
	Version = Undefined;
	
	If FileInfo1.StoreVersions Then
			
		ErrorTitle = NStr("en = 'An error occurred when saving a new version of the attachments.';");
		ErrorEnd = NStr("en = 'Cannot overwrite the file.';");
		
		FileAttributesValues = Common.ObjectAttributesValues(FileRef, "FileOwner,CurrentVersion");
		
		FileVersionsStorageCatalogName = FilesVersionsStorageCatalogName(
			TypeOf(FileAttributesValues.FileOwner), "", ErrorTitle, ErrorEnd);
		
		Version = Catalogs[FileVersionsStorageCatalogName].CreateItem();
		Version.ParentVersion = FileAttributesValues.CurrentVersion;
		Version.VersionNumber = MaxVersionNumber(FileRef) + 1;
		RefToVersion = Catalogs[FileVersionsStorageCatalogName].GetRef(New UUID());
		Version.SetNewObjectRef(RefToVersion);
		
	Else
		
		RefToVersion = ?(VersionRef = Undefined, CurrentVersion(FileRef), VersionRef);
		Version = RefToVersion.GetObject();
		BlockVersion = True;

	EndIf;
	
	Version.Owner = FileRef;
	If User = Undefined Then
		Version.Author = Users.AuthorizedUser();
	Else
		Version.Author = User;
	EndIf;
	Version.UniversalModificationDate = ModificationTimeUniversal;
	Version.FileModificationDate = Modified;
	Version.CreationDate = CurrentSessionDate();
	Version.Size = FileInfo1.Size;
	Version.Description = FileInfo1.BaseName;
	Version.Comment = FileInfo1.Comment;
	Version.Extension = CommonClientServer.ExtensionWithoutPoint(FileInfo1.ExtensionWithoutPoint);
	
	FileStorageType = FileStorageType(FileInfo1.Size, FileInfo1.ExtensionWithoutPoint);
	Version.FileStorageType = FileStorageType;
	
	If BinaryData = Undefined Then
		BinaryData = BinaryDataFromFileInformation(FileInfo1);
	EndIf;
	
	If Version.Size = 0 Then
		Version.Size = BinaryData.Size();
		CheckFileSizeForImport(Version);
	EndIf;
		
	If FileStorageType = Enums.FileStorageTypes.InInfobase Then
		Version.PathToFile = "";
		Version.Volume = Catalogs.FileStorageVolumes.EmptyRef();
	EndIf;
	
	If FileInfo1.Encrypted = False And ObjectMetadata.FullTextSearch = FullTextSearchUsing Then
		TextExtractionResult = ExtractText1(FileInfo1.TempTextStorageAddress);
		Version.TextStorage = TextExtractionResult.TextStorage;
		Version.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
		If FileInfo1.NewTextExtractionStatus <> Undefined Then
			Version.TextExtractionStatus = FileInfo1.NewTextExtractionStatus;
		EndIf;
	Else
		Version.TextStorage = New ValueStorage("");
		Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	EndIf;
	
	Version.Fill(Undefined);
	
	Context = FileUpdateContext(Version, FileInfo1.TempFileStorageAddress, RefToVersion, FileStorageType);
	FilesManager = FileManagerByType(FileStorageType);
	FilesManager.BeforeUpdatingTheFileData(Context);
	BeginTransaction();
	Try
		
		If BlockVersion Then
			Block = New DataLock;
			LockItem = Block.Add(RefToVersion.Metadata().FullName());
			LockItem.SetValue("Ref", RefToVersion);
			Block.Lock();
			LockDataForEdit(RefToVersion, , FormUniqueID);
		EndIf;
		
		FilesManager.BeforeWritingFileData(Context, Version);
		Version.Write();
		FilesManager.WhenUpdatingFileData(Context, Version.Ref);
		
		InformationRegisters.FilesEncoding.WriteFileVersionEncoding(Version.Ref, FileInfo1.Encoding);
		If FileInfo1.StoreVersions Then
			UpdateVersionInFile(FileRef, Version.Ref, FileInfo1.TempTextStorageAddress, FormUniqueID);
		Else
			UpdateTextInFile(FileRef, FileInfo1.TempTextStorageAddress, FormUniqueID);
		EndIf;
		
		InformationRegisters.FilesEncoding.WriteFileVersionEncoding(Version.Ref, PreVersionEncoding);
		If BlockVersion Then
			UnlockDataForEdit(RefToVersion, FormUniqueID);
		EndIf;
		CommitTransaction();
		
	Except
		RollbackTransaction();
		If BlockVersion Then
			UnlockDataForEdit(RefToVersion, FormUniqueID);
		EndIf;
		FilesManager.AfterUpdatingTheFileData(Context, False);
		Raise;
	EndTry;

	FilesManager.AfterUpdatingTheFileData(Context, True);
	
	If HasSaveRight Then
		FileURL1 = GetURL(FileRef);
		UserWorkHistory.Add(FileURL1);
	EndIf;
	
	Return Version.Ref;
	
EndFunction

// Parameters:
//   FileRef - CatalogRef.Files
//   TempTextStorageAddress - String - Address in the temporary storage where binary data is located.
//                                  - ValueStorage
//   UUID - UUID - a form UUID.
//
Procedure UpdateTextInFile(FileRef,
	Val TempTextStorageAddress, UUID = Undefined) Export
	
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	CatalogMetadata = Metadata.FindByType(TypeOf(FileRef));
	If CatalogMetadata.FullTextSearch = FullTextSearchUsing Then
		TextExtractionResult = ExtractText1(TempTextStorageAddress);
		ExtractedText = TextExtractionResult.TextStorage;
		TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
	Else
		TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		ExtractedText = New ValueStorage("");
	EndIf;
	
	DataLock = New DataLock;
	DataLockItem = DataLock.Add(CatalogMetadata.FullName());
	DataLockItem.SetValue("Ref", FileRef);
	
	BeginTransaction();
	Try
		DataLock.Lock(); 
		
		FileObject1 = FileRef.GetObject();
		LockDataForEdit(FileRef, , UUID);
		
		FileObject1.TextExtractionStatus = TextExtractionStatus;
		FileObject1.TextStorage = ExtractedText;
		FileObject1.Write();

		UnlockDataForEdit(FileRef, UUID);
		CommitTransaction();
	Except
		RollbackTransaction();
		UnlockDataForEdit(FileRef, UUID);
		Raise;
	EndTry
	
EndProcedure

// Substitutes the reference to the version in the File card.
//
// Parameters:
//   FileRef - CatalogRef.Files - a file in which a version is created.
//   Version  - CatalogRef.FilesVersions - a file version.
//   TempTextStorageAddress - String - contains the address in the temporary storage, where the binary data with
//                                           the text file, or the ValueStorage that directly contains the binary
//                                           data with the text file are located.
//  UUID - UUID - a form UUID.
//
Procedure UpdateVersionInFile(FileRef,
								Version,
								Val TempTextStorageAddress,
								UUID = Undefined) Export
	
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	
	BeginTransaction();
	Try
		
		CatalogMetadata = Metadata.FindByType(TypeOf(FileRef));
		
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(CatalogMetadata.FullName());
		DataLockItem.SetValue("Ref", FileRef);
		DataLock.Lock();
		
		LockDataForEdit(FileRef, , UUID);
		
		FileObject1 = FileRef.GetObject();
		VersionStorage = Common.ObjectAttributesValues(Version, "FileStorageType, Volume, PathToFile");
		
		FileObject1.CurrentVersion = Version;
		If TempTextStorageAddress <> Undefined
			And CatalogMetadata.FullTextSearch = FullTextSearchUsing Then
			
			If TypeOf(TempTextStorageAddress) = Type("ValueStorage") Then
				// When creating a File from a template, the value storage is copied directly.
				FileObject1.TextStorage = TempTextStorageAddress;
			Else
				TextExtractionResult = ExtractText1(TempTextStorageAddress);
				FileObject1.TextStorage = TextExtractionResult.TextStorage;
				FileObject1.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
			EndIf;
			
		Else
			FileObject1.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
			FileObject1.TextStorage = New ValueStorage("");
		EndIf;
		
		FillPropertyValues(FileObject1, VersionStorage);
		FileObject1.Write();
		
		UnlockDataForEdit(FileRef, UUID);
		CommitTransaction();
		
	Except
		RollbackTransaction();
		UnlockDataForEdit(FileRef, UUID);
		Raise;
	EndTry;
	
EndProcedure

// Returns the maximum version number for this File object. If there are no versions, returns 0.
//
// Parameters:
//  FileRef  - CatalogRef.Files
//
// Returns:
//   Number
//
Function MaxVersionNumber(FileRef)
	
	Query = New Query("SELECT
	|	ISNULL(MAX(Versions.VersionNumber), 0) AS MaxNumber
	|FROM
	|	Catalog.FilesVersions AS Versions
	|WHERE
	|	Versions.Owner = &File");
	Query.Parameters.Insert("File", FileRef);
		
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return ?(Selection.MaxNumber = Null, 0, Number(Selection.MaxNumber));
	EndIf;
	
	Return 0;
EndFunction

// Raises an exception if file has an invalid size for import.
Procedure CheckFileSizeForImport(File) Export
	
	CommonSettings = FilesOperationsInternalCached.FilesOperationSettings().CommonSettings;
	
	If TypeOf(File) = Type("File") Then
		Size = File.Size();
	Else
		Size = File.Size;
	EndIf;
	
	If Size > CommonSettings.MaxFileSize Then
	
		SizeInMB     = Size / (1024 * 1024);
		SizeInMBMax = CommonSettings.MaxFileSize / (1024 * 1024);
		
		If TypeOf(File) = Type("File") Then
			Name = File.Name;
		Else
			Name = CommonClientServer.GetNameWithExtension(File.Description, File.Extension);
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The size of file ""%1"" (%2 MB)
			           |exceeds the limit (%3 MB).';"),
			Name,
			FilesOperationsInternalClientServer.FileSizePresentation(SizeInMB),
			FilesOperationsInternalClientServer.FileSizePresentation(SizeInMBMax));
	EndIf;
	
EndProcedure

#EndRegion

#Region FileItemFormEventHandlers

// Parameters:
//   Context - ClientApplicationForm:
//     * Object - DefinedType.AttachedFileObject
//
Procedure ItemFormOnCreateAtServer(Context, Cancel, StandardProcessing, Parameters, ReadOnly, CustomizeFormObject = False) Export
	
	Items = Context.Items;
	
	ColumnsArray = New Array;
	DigitalSignaturesTable = Context.FormAttributeToValue("DigitalSignatures"); // ValueTable
	For Each ColumnDetails In DigitalSignaturesTable.Columns Do
		ColumnsArray.Add(ColumnDetails.Name);
	EndDo;
	
	If ValueIsFilled(Parameters.CopyingValue) Then
		InfobaseUpdate.CheckObjectProcessed(Parameters.CopyingValue);
		If Parameters.CreateMode = "FromTemplate" Then
			ObjectValue = FillFileDataByTemplate(Context, Parameters)
		Else
			ObjectValue = FillFileDataFromCopy(Context, Parameters);
		EndIf;
	Else
		If ValueIsFilled(Parameters.AttachedFile) Then
			ObjectValue = Parameters.AttachedFile.GetObject();
		ElsIf ValueIsFilled(Parameters.Key) Then
			ObjectValue = Parameters.Key.GetObject();
		Else
			Raise NStr("en = 'You cannot create a file.';");
		EndIf;
		InfobaseUpdate.CheckObjectProcessed(ObjectValue, Context);
	EndIf;
	ObjectValue.Fill(Undefined);
	
	CatalogMetadata = ObjectValue.Metadata(); // MetadataObjectCatalog
	Context.CatalogName = CatalogMetadata.Name;
	
	CanCreateFileVersions = TypeOf(ObjectValue.Ref) = Type("CatalogRef.Files");
	Context.CanCreateFileVersions = CanCreateFileVersions; 
	
	If CustomizeFormObject Then
		Items.StoreVersions0.Visible = CanCreateFileVersions;
		SetUpFormObject(ObjectValue, Context);
	Else
		ValueToFormData(ObjectValue, Context.Object);
		Items.StoreVersions.Visible = CanCreateFileVersions;
	EndIf;
	
	Context.ModificationDate = ToLocalTime(Context.Object.UniversalModificationDate);
	
	CryptographyOnCreateFormAtServer(Context, False);
	FillSignatureList(Context, Parameters.CopyingValue);
	FillEncryptionList(Context, Parameters.CopyingValue);
	
	CommonSettings = FilesOperationsInternalCached.FilesOperationSettings().CommonSettings;
	
	FileExtensionInList = FilesOperationsInternalClientServer.FileExtensionInList(
		CommonSettings.TextFilesExtensionsList, Context.Object.Extension);
	
	If FileExtensionInList Then
		If CanCreateFileVersions And Context.Object.Property("CurrentVersion") And ValueIsFilled(Context.Object.CurrentVersion) Then
			CurrentFileVersion = Context.Object.CurrentVersion;
		Else
			CurrentFileVersion = Context.Object.Ref;
		EndIf;
		If ValueIsFilled(CurrentFileVersion) Then
			
			EncodingValue = InformationRegisters.FilesEncoding.FileVersionEncoding(CurrentFileVersion);
			
			EncodingsList = Encodings();
			ListItem = EncodingsList.FindByValue(EncodingValue);
			If ListItem = Undefined Then
				Context.Encoding = EncodingValue;
			Else
				Context.Encoding = ListItem.Presentation;
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(Context.Encoding) Then
			Context.Encoding = NStr("en = 'Default';");
		EndIf;
		
	Else
		Context.Items.Encoding.Visible = False;
	EndIf;
	
	IsInternalFile = False;
	If ThereArePropsInternal(Context.CatalogName) Then
		IsInternalFile = ObjectValue.IsInternal;
	EndIf;
	
	If IsInternalFile Then
		Context.ReadOnly = True;
	EndIf;
	
	Items.FormClose.Visible = IsInternalFile;
	Items.FormClose.DefaultButton = IsInternalFile;
	Items.DecorationNoteInternal.Visible = IsInternalFile;
	
	Items.FormSend.Visible = Common.SubsystemExists("StandardSubsystems.EmailOperations");

	If TypeOf(Context.CurrentUser) = Type("CatalogRef.ExternalUsers") Then
		ChangeFormForExternalUser(Context);
	EndIf;
	
	If GetFunctionalOption("UseFileSync") Then
		Context.FileToEditInCloud = FileToEditInCloud(Context.Object.Ref);
	EndIf;
	
	If ReadOnly
		Or Not AccessRight("Update", Context.Object.Ref.Metadata()) Then
		SetChangeButtonsInvisible(Context.Items);
	EndIf;
	
	If Not ReadOnly
		And Not Context.Object.Ref.IsEmpty() And CustomizeFormObject Then
		LockDataForEdit(Context.Object.Ref, , Context.UUID);
	EndIf;
	
	OwnerType = TypeOf(ObjectValue.FileOwner);
	ItemFileOwner = Context.Items.FileOwner; // FormField
	ItemFileOwner.Title = OwnerType;
	
EndProcedure

// Parameters:
//   Context - ClientApplicationForm:
//     * Object - DefinedType.AttachedFileObject
//     * CopyingValue - DefinedType.AttachedFile
//   Parameters - Structure:
//     * CopyingValue - DefinedType.AttachedFile
//     * FilesStorageCatalogName - String
//     * FileOwner - DefinedType.AttachedFilesOwner
//
Function FillFileDataByTemplate(Context, Parameters)
	
	CreationDate = CurrentSessionDate();
	ObjectToCopy = Parameters.CopyingValue.GetObject(); // DefinedType.AttachedFileObject
	Context.CopyingValue = Parameters.CopyingValue;
	
	CatalogManager = Catalogs[Parameters.FilesStorageCatalogName]; // CatalogManager
	ObjectValue = CatalogManager.CreateItem();
	FillPropertyValues(ObjectValue, ObjectToCopy,
		"Description,
		|Encrypted,
		|LongDesc,
		|SignedWithDS,
		|Size,
		|Extension,
		|FileOwner,
		|TextStorage,
		|DeletionMark");
	ObjectValue.FileOwner                = Parameters.FileOwner;
	ObjectValue.CreationDate                 = CreationDate;
	ObjectValue.UniversalModificationDate = ToUniversalTime(CreationDate);
	ObjectValue.Author                        = Users.AuthorizedUser();
	ObjectValue.FileStorageType             = FileStorageType(ObjectToCopy.Size, ObjectToCopy.Extension);
	ObjectValue.StoreVersions                = ?(Parameters.FilesStorageCatalogName = "Files",
		ObjectToCopy.StoreVersions, False);
	
	Return ObjectValue;
	
EndFunction

Function FillFileDataFromCopy(Context, Parameters)

	ObjectToCopy = Parameters.CopyingValue.GetObject();
	Context.CopyingValue = Parameters.CopyingValue;
	
	MetadataObject = ObjectToCopy.Metadata();
	CatalogManager = Catalogs[MetadataObject.Name]; // CatalogManager
	ObjectValue = CatalogManager.CreateItem();
	
	AttributesToExclude = "Parent,Owner,LockedDate,ChangedBy,Code,DeletionMark,BeingEditedBy,Volume,PredefinedDataName,Predefined,PathToFile,TextExtractionStatus";
	If MetadataObject.Attributes.Find("CurrentVersion") <> Undefined Then
		AttributesToExclude = AttributesToExclude + ",CurrentVersion";
	EndIf;
	
	FillPropertyValues(ObjectValue,ObjectToCopy, , AttributesToExclude);
	ObjectValue.Author            = Users.AuthorizedUser();
	ObjectValue.FileStorageType = FileStorageType(ObjectValue.Size, ObjectValue.Extension);
	
	Return ObjectValue;
	
EndFunction

Procedure SetUpFormObject(Val NewObject, Context)
	
	NewObjectType = New Array;
	NewObjectType.Add(TypeOf(NewObject));
	NewAttribute = New FormAttribute("Object", New TypeDescription(NewObjectType));
	NewAttribute.StoredData = True;
	
	AttributesToBeAdded = New Array;
	AttributesToBeAdded.Add(NewAttribute);
	Context.ChangeAttributes(AttributesToBeAdded);
	Context.ValueToFormAttribute(NewObject, "Object");

	For Each Item In Context.Items Do
		If TypeOf(Item) = Type("FormField")
			And StrStartsWith(Item.DataPath, "PrototypeObject[0].")
			And StrEndsWith(Item.Name, "0") Then
			
			TagName = Left(Item.Name, StrLen(Item.Name) -1);
			
			If Context.Items.Find(TagName) <> Undefined  Then
				Continue;
			EndIf;
			
			NewItem = Context.Items.Insert(TagName, TypeOf(Item), Item.Parent, Item);
			NewItem.DataPath = "Object." + Mid(Item.DataPath, StrLen("PrototypeObject[0].") + 1);
			
			If Item.Type = FormFieldType.CheckBoxField Or Item.Type = FormFieldType.PictureField Then
				PropertiesToExclude = "Name, DataPath";
			Else
				PropertiesToExclude = "Name, DataPath, SelectedText, TypeLink";
			EndIf;
			FillPropertyValues(NewItem, Item, , PropertiesToExclude);
			Item.Visible = False;
		EndIf;
	EndDo;
	
	If Not NewObject.IsNew() Then
		Context.URL = GetURL(NewObject);
	EndIf;
	
EndProcedure

Procedure FillEncryptionList(Context, Val Source = Undefined) Export
	If Not ValueIsFilled(Source) Then
		Source = Context.Object;
	EndIf;
	
	Context.EncryptionCertificates.Clear();
	
	If Source.Encrypted Then
		
		If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
			EncryptionCertificates = ModuleDigitalSignature.EncryptionCertificates(Source.Ref);
			
			For Each EncryptionCertificate In EncryptionCertificates Do
				
				NewRow = Context.EncryptionCertificates.Add();
				NewRow.Presentation = EncryptionCertificate.Presentation;
				NewRow.Thumbprint = EncryptionCertificate.Thumbprint;
				NewRow.SequenceNumber = EncryptionCertificate.SequenceNumber;
				
				CertificateBinaryData = EncryptionCertificate.Certificate;
				If CertificateBinaryData <> Undefined Then
					
					NewRow.CertificateAddress = PutToTempStorage(
						CertificateBinaryData, Context.UUID);
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	TitleText = NStr("en = 'Decryption allowed';");
	
	If Context.EncryptionCertificates.Count() <> 0 Then
		TitleText =TitleText + " (" + Format(Context.EncryptionCertificates.Count(), "NG=") + ")";
	EndIf;
	
	EncryptionCertificatesGroup = Context.Items.EncryptionCertificatesGroup; // FormGroup
	EncryptionCertificatesGroup.Title = TitleText;
	
EndProcedure

Procedure FillSignatureList(Context, Val Source = Undefined) Export
	
	If Not ValueIsFilled(Source) Then
		Source = Context.Object;
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	Context.DigitalSignatures.Clear();
	
	DigitalSignatures = DigitalSignaturesList(Source, Context.UUID);
	ModuleDigitalSignatureClientServer = Common.CommonModule("DigitalSignatureClientServer");
	
	For Each FileDigitalSignature In DigitalSignatures Do
		
		ResultOfSignatureValidationOnForm = ModuleDigitalSignatureClientServer.ResultOfSignatureValidationOnForm();
		FillPropertyValues(ResultOfSignatureValidationOnForm, FileDigitalSignature);
		FillPropertyValues(ResultOfSignatureValidationOnForm.CheckResult, FileDigitalSignature);
		
		NewRow = Context.DigitalSignatures.Add();
		FillPropertyValues(NewRow, ResultOfSignatureValidationOnForm);
		
		If NewRow.Property("BriefCheckResult") Then
			ModuleDigitalSignatureClientServer.FillSignatureStatus(NewRow, CurrentSessionDate());
		Else
			FilesOperationsInternalClientServer.FillSignatureStatus(NewRow, CurrentSessionDate());
		EndIf;
		
		CertificateBinaryData = FileDigitalSignature.Certificate.Get();
		If CertificateBinaryData <> Undefined Then 
			NewRow.CertificateAddress = PutToTempStorage(
				CertificateBinaryData, Context.UUID);
		EndIf;
		
	EndDo;
	
	TitleText = NStr("en = 'Digital signatures';");
	
	If Context.DigitalSignatures.Count() <> 0 Then
		TitleText = TitleText + " (" + String(Context.DigitalSignatures.Count()) + ")";
	EndIf;
	
	DigitalSignaturesGroup = Context.Items.DigitalSignaturesGroup; // FormGroup
	DigitalSignaturesGroup.Title = TitleText;
	
EndProcedure

Function DigitalSignaturesList(Source, UUID)
	
	DigitalSignatures = New Array;
	
	If Source.SignedWithDS Then
		
		If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			
			ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
			DigitalSignatures = ModuleDigitalSignature.SetSignatures(Source.Ref, Undefined, True);
			
			
			For Each FileDigitalSignature In DigitalSignatures Do
				
				FileDigitalSignature.Insert("Object", Source.Ref);
				SignatureAddress = PutToTempStorage(FileDigitalSignature.Signature, UUID);
				FileDigitalSignature.Insert("SignatureAddress", SignatureAddress);
				
				
			EndDo;
	
		EndIf;
		
	EndIf;
	
	Return DigitalSignatures;
	
EndFunction

Function StgnaturesListToSend(Source, UUID, FileName)
	
	DigitalSignatures = New Array;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		
		DigitalSignatures = DigitalSignaturesList(Source, UUID);
		DataFileNameContent = CommonClientServer.ParseFullFileName(FileName);
		
		ModuleDigitalSignatureInternalClientServer = Common.CommonModule("DigitalSignatureInternalClientServer");
		ModuleDigitalSignatureInternal             = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignature                      = Common.CommonModule("DigitalSignature");
		
		SignatureFilesExtension = ModuleDigitalSignature.PersonalSettings().SignatureFilesExtension;
		
		For Each FileDigitalSignature In DigitalSignatures Do
			
			SignatureFileName = ModuleDigitalSignatureInternalClientServer.SignatureFileName(DataFileNameContent.BaseName,
				String(FileDigitalSignature.CertificateOwner), SignatureFilesExtension);
			FileDigitalSignature.Insert("FileName", SignatureFileName);
			
			DataByCertificate = ModuleDigitalSignatureInternal.DataByCertificate(FileDigitalSignature, UUID);
			FileDigitalSignature.Insert("CertificateAddress", DataByCertificate.CertificateAddress);
			
			CertificateFileName = ModuleDigitalSignatureInternalClientServer.CertificateFileName(DataFileNameContent.BaseName,
				String(FileDigitalSignature.CertificateOwner), DataByCertificate.CertificateExtension);
				
			FileDigitalSignature.Insert("CertificateFileName", CertificateFileName);
			
		EndDo;
	EndIf;
	
	Return DigitalSignatures;
	
EndFunction

Procedure SetChangeButtonsInvisible(Items)
	
	CommandsNames = GetObjectChangeCommandsNames();
	
	For Each FormItem In Items Do
	
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		
		If CommandsNames.Find(FormItem.CommandName) <> Undefined Then
			FormItem.Visible = False;
		EndIf;
	EndDo;
	
EndProcedure

Function GetObjectChangeCommandsNames()
	
	CommandsNames = New Array;
	
	CommandsNames.Add("DigitallySignFile");
	CommandsNames.Add("AddDSFromFile");
	
	CommandsNames.Add("DeleteDS");
	CommandsNames.Add("ExtendActionSignatures");
	
	CommandsNames.Add("Edit");
	CommandsNames.Add("SaveChanges");
	CommandsNames.Add("EndEdit");
	CommandsNames.Add("Release");
	
	CommandsNames.Add("Encrypt");
	CommandsNames.Add("Decrypt");
	
	CommandsNames.Add("StandardCommandsCopy");
	CommandsNames.Add("UpdateFromFileOnHardDrive");
	
	CommandsNames.Add("StandardWrite");
	CommandsNames.Add("StandardSaveAndClose");
	CommandsNames.Add("StandardSetDeletionMark");
	
	CommandsNames.Add("Lock");
	
	Return CommandsNames;
	
EndFunction

Function FilesSettings() Export
	
	FilesSettings = New Structure;
	FilesSettings.Insert("DontClearFiles",            New Array);
	FilesSettings.Insert("NotSynchronizeFiles",   New Array);
	FilesSettings.Insert("DontOutputToInterface",      New Array);
	FilesSettings.Insert("DontCreateFilesByTemplate", New Array);
	FilesSettings.Insert("FilesWithoutFolders",             New Array);
	
	SSLSubsystemsIntegration.OnDefineFileSynchronizationExceptionObjects(FilesSettings.NotSynchronizeFiles);
	FilesOperationsOverridable.OnDefineSettings(FilesSettings);
	
	Return FilesSettings;
	
EndFunction

// Parameters:
//   Result - Array of See FileDetails
//
Procedure GenerateFilesListToSendViaEmail(Result, FileAttachment, FormIdentifier) Export
	
	FileDataAndBinaryData = FilesOperations.FileData(FileAttachment, FormIdentifier); // See FilesOperations.FileData
	FileName = CommonClientServer.GetNameWithExtension(
		FileDataAndBinaryData.Description, FileDataAndBinaryData.Extension);
	Common.ShortenFileName(FileName);
	
	FileDetails = FileDetails(FileName, FileDataAndBinaryData.RefToBinaryFileData);
	Result.Add(FileDetails);
	
	If FileAttachment.SignedWithDS Then
		SignaturesList = StgnaturesListToSend(FileAttachment, FormIdentifier, FileName);
		For Each FileDigitalSignature In SignaturesList Do
			FileDetails = FileDetails(FileDigitalSignature.FileName, FileDigitalSignature.SignatureAddress);
			Result.Add(FileDetails);
			
			If ValueIsFilled(FileDigitalSignature.CertificateAddress) Then
				FileDetails = FileDetails(FileDigitalSignature.CertificateFileName, FileDigitalSignature.CertificateAddress);
				Result.Add(FileDetails);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

Function FileDetails(FileName, AddressInTempStorage)
	
	FileDetails = New Structure;
	FileDetails.Insert("Presentation",             FileName);
	FileDetails.Insert("AddressInTempStorage", AddressInTempStorage);
	
	Return FileDetails;
	
EndFunction

#EndRegion

#Region CleanUpUnusedFiles

// Parameters:
//   UnusedFiles - See CollectUnusedFiles
//
Procedure ClearUnusedFilesData(UnusedFiles)
	
	If UnusedFiles.Rows.Count() = 0 Then
		Return;
	EndIf;
	
	ItemsToDeleteAttachedFiles = New Array;
	For Each File In UnusedFiles.Rows Do
		AttachedFile = File.FileRef; // DefinedType.AttachedFile
		PreparedFile = PrepareTheFileForDeletion(AttachedFile);
		If ValueIsFilled(PreparedFile) Then
			ItemsToDeleteAttachedFiles.Add(PreparedFile);
		EndIf;
	EndDo;
	
	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectsDeletion = Common.CommonModule("MarkedObjectsDeletion");
		DeletionResult = ModuleMarkedObjectsDeletion.ToDeleteMarkedObjects(ItemsToDeleteAttachedFiles);
		If Not DeletionResult.Success Then
			WriteToEventLogCleanupFiles(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Some of the files have not been deleted automatically (%1) as they are used elsewhere in the application or due to other reasons.
				|To view the reasons why the files cannot be deleted, open ""Marked object deletion"" in the application settings.';"),
				DeletionResult.NotTrash.Count()), EventLogLevel.Warning);
		EndIf;
		Return;
	EndIf;
	
	UsageInstances = Common.UsageInstances(ItemsToDeleteAttachedFiles);
	For Each AttachedFile In ItemsToDeleteAttachedFiles Do
		Filter = New Structure("Ref, AuxiliaryData, IsInternalData", AttachedFile, False, False);
		PlacesWhereTheFileIsUsed = UsageInstances.FindRows(Filter);
		
		For IndexOf = -PlacesWhereTheFileIsUsed.UBound() To 0 Do
			Location = UsageInstances[-IndexOf];
			If Location.Metadata = Metadata.Catalogs.FilesVersions Then
				PlacesWhereTheFileIsUsed.Delete(-IndexOf);
			EndIf;
		EndDo;

		HasUsageInstances = PlacesWhereTheFileIsUsed.Count() <> 0;
		If HasUsageInstances Then
			Continue;
		EndIf;
		AttachedFile = UnusedFiles.Rows.Find(AttachedFile, "FileRef");
		DeleteJunkFiles(AttachedFile);
	EndDo;

EndProcedure

Function PrepareTheFileForDeletion(AttachedFile)
	Result = Undefined;
	
	WriteToEventLogCleanupFiles(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Deleting unused file ""%1""...';"), Common.SubjectString(AttachedFile)),,
		AttachedFile);
	Block = New DataLock();
	LockItem = Block.Add(AttachedFile.Metadata().FullName());
	LockItem.SetValue("Ref", AttachedFile);
		
	BeginTransaction();
	Try
		Block.Lock();
		LockDataForEdit(AttachedFile);
		
		FileObject1 = AttachedFile.GetObject();
		If FileObject1 = Undefined Then // Object has already been deleted.
			CommitTransaction();
			Return Result;
		EndIf;
		If Common.HasObjectAttribute("BeingEditedBy", FileObject1.Metadata())
			And ValueIsFilled(FileObject1.BeingEditedBy) Then
			WriteToEventLogCleanupFiles(NStr("en = 'The file cannot be deleted as it is being edited.';"),,
				AttachedFile);
			CommitTransaction();
			Return Result;
		EndIf;
		
		FileObject1.SetDeletionMark(True);
		Result = AttachedFile;
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteToEventLogCleanupFiles(ErrorProcessing.DetailErrorDescription(ErrorInfo()),
			EventLogLevel.Error, AttachedFile);
	EndTry;
	
	Return Result;
EndFunction

// Parameters:
//  DescriptionOfTheAttachedFile - See CollectUnusedFiles
//
Procedure DeleteJunkFiles(DescriptionOfTheAttachedFile)
	
	FilesToBeDeleted = New Array;
	
	ItemsToDeleteAttachedFiles = New Array; 
	For Each Version In DescriptionOfTheAttachedFile.Rows Do
		ItemsToDeleteAttachedFiles.Add(Version.VersionRef);
	EndDo;
	ItemsToDeleteAttachedFiles.Add(DescriptionOfTheAttachedFile.FileRef);
	
	For Each AttachedFile In ItemsToDeleteAttachedFiles Do
		
		FileStorageType = Common.ObjectAttributeValue(AttachedFile, "FileStorageType");
		If FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			FileProperties = FilesOperationsInVolumesInternal.FilePropertiesInVolume(AttachedFile);
			FilesToBeDeleted.Add(FilesOperationsInVolumesInternal.FullFileNameInVolume(FileProperties));
		EndIf;
		
		Try
			DeleteAnUnnecessaryFile(AttachedFile);
		Except
			If FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive
					And FilesToBeDeleted.Count() > 0 Then
				FilesToBeDeleted.Delete(FilesToBeDeleted.UBound());	
			EndIf;
			Continue;
		EndTry;	
	EndDo;
	
	For Each File In FilesToBeDeleted Do
		
		If Not ValueIsFilled(File) Then
			Continue;
		EndIf;
		
		FilesOperationsInVolumesInternal.DeleteFile(File);
	EndDo;

EndProcedure

// Parameters:
//  AttachedFile - DefinedType.AttachedFile
//
Function DeleteAnUnnecessaryFile(AttachedFile)
	
	Block = New DataLock();
	LockItem = Block.Add(AttachedFile.Metadata().FullName());
	LockItem.SetValue("Ref", AttachedFile);
		
	BeginTransaction();
	Try
		Block.Lock();
		LockDataForEdit(AttachedFile);
		
		AttachedFileObject = AttachedFile.GetObject();
		If AttachedFileObject = Undefined Then // Object has already been deleted.
			CommitTransaction();
			Return False;
		EndIf;	
		If TypeOf(AttachedFile) <> Type("CatalogRef.FilesVersions")
				And ValueIsFilled(AttachedFileObject.BeingEditedBy) Then
			CommitTransaction();
			Return False;
		EndIf;
		
		Volume = AttachedFileObject.Volume;
		If ValueIsFilled(Volume) Then
			VolumeObject = Volume.GetObject();
			VolumeObject.LastFilesCleanupTime = CurrentUniversalDate();
			VolumeObject.Write();
		EndIf;
		
		AttachedFileObject.Delete();
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteToEventLogCleanupFiles(ErrorProcessing.DetailErrorDescription(ErrorInfo()), 
			EventLogLevel.Error, AttachedFile);
		Raise;
	EndTry;
	
	Return True;
EndFunction

// Parameters:
//  ClearingSetup - ValueTableRow of See InformationRegisters.FilesClearingSettings.CurrentClearSettings
//  ExceptionsArray - Array of DefinedType.FilesOwner
// 
// Returns:
//  ValueTree:
//    * FileRef - DefinedType.AttachedFile
//    * FileOwner - Type - DefinedType.FilesOwner type.
//    * Size - Number - size in MB. 
//
Function CollectUnusedFiles(ClearingSetup, ExceptionsArray) Export
	
	SettingsComposer = New DataCompositionSettingsComposer;
	
	ClearByRule = ClearingSetup.ClearingPeriod = Enums.FilesCleanupPeriod.ByRule;
	If ClearByRule Then
		ComposerSettings = ClearingSetup.FilterRule.Get();
		If ComposerSettings <> Undefined Then
			SettingsComposer.LoadSettings(ClearingSetup.FilterRule.Get());
		EndIf;
	EndIf;
	
	DataCompositionSchema = New DataCompositionSchema;
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "Local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Name = "DataSet1";
	DataSet.DataSource = DataSource.Name;
	
	DataCompositionSchema.TotalFields.Clear();
	
	If ClearingSetup.IsCatalogItemSetup Then
		FileOwner = ClearingSetup.OwnerID;
		ExceptionItem = ClearingSetup.FileOwner;
	Else
		FileOwner = ClearingSetup.FileOwner;
		ExceptionItem = Undefined;
	EndIf;
	
	DataCompositionSchema.DataSets[0].Query = QueryTextToClearFiles(FileOwner,
		ClearingSetup, ExceptionsArray, ExceptionItem);
	
	Structure = SettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("FileRef");
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("FileOwner");
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Size");
	
	If ClearingSetup.IsFile Then
		VersionsStructure = Structure.Structure.Add(Type("DataCompositionGroup"));
		SelectedField = VersionsStructure.Selection.Items.Add(Type("DataCompositionSelectedField"));
		SelectedField.Field = New DataCompositionField("VersionRef");
	EndIf;
	
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	
	Parameter = SettingsComposer.Settings.DataParameters.Items.Find("OwnerType");
	Parameter.Value = TypeOf(Common.ObjectAttributeValue(FileOwner, "EmptyRefValue"));
	Parameter.Use = True;
	
	Parameter = SettingsComposer.Settings.DataParameters.Items.Find("ClearingPeriod");
	If Parameter <> Undefined Then
		If ClearingSetup.ClearingPeriod = Enums.FilesCleanupPeriod.OverOneMonth Then
			ClearingPeriodValue = AddMonth(BegOfDay(CurrentSessionDate()), -1);
		ElsIf ClearingSetup.ClearingPeriod = Enums.FilesCleanupPeriod.OverOneYear Then
			ClearingPeriodValue = AddMonth(BegOfDay(CurrentSessionDate()), -12);
		ElsIf ClearingSetup.ClearingPeriod = Enums.FilesCleanupPeriod.OverSixMonths Then
			ClearingPeriodValue = AddMonth(BegOfDay(CurrentSessionDate()), -6);
		EndIf;
		Parameter.Value = ClearingPeriodValue;
		Parameter.Use = True;
	EndIf;
	
	CurrentDateParameter = SettingsComposer.Settings.DataParameters.Items.Find("CurrentDate");
	If CurrentDateParameter <> Undefined Then
		CurrentDateParameter.Value = CurrentSessionDate();
		CurrentDateParameter.Use = True;
	EndIf;
	
	If ExceptionsArray.Count() > 0 Then
		Parameter = SettingsComposer.Settings.DataParameters.Items.Find("ExceptionsArray");
		Parameter.Value = ExceptionsArray;
		Parameter.Use = True;
	EndIf;
	
	If ClearingSetup.IsCatalogItemSetup Then
		Parameter = SettingsComposer.Settings.DataParameters.Items.Find("ExceptionItem");
		Parameter.Value = ExceptionItem;
		Parameter.Use = True;
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	DataCompositionProcessor = New DataCompositionProcessor;
	
	DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, SettingsComposer.Settings, , ,
		Type("DataCompositionValueCollectionTemplateGenerator"));
	DataCompositionProcessor.Initialize(DataCompositionTemplate);
	
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	OutputProcessor.SetObject(New ValueTree);

	Result = OutputProcessor.Output(DataCompositionProcessor);
	Return Result;
	
EndFunction

// Parameters:
//  FileOwner - CatalogRef.MetadataObjectIDs
//
Function DetailsOfTheFileOwner(FileOwner)

	QueryAttributes = "";
	
	MetadataObject = Common.MetadataObjectByID(FileOwner);
	If Common.IsCatalog(MetadataObject) Then
		For Each Attribute In MetadataObject.Attributes Do
			QueryAttributes = QueryAttributes + Chars.LF + "CatalogFileOwner." + Attribute.Name + ",";
		EndDo;
	ElsIf Common.IsDocument(MetadataObject) Then
		QueryTemplate = "DATEDIFF(&TheNameOfThePropsDate, &CurrentDate, DAY) AS DaysBeforeDeletionFromTheDate"; // @query-part
		For Each Attribute In MetadataObject.Attributes Do
			If Attribute.Type = New TypeDescription("Date") Then
				QueryFragment = StrReplace(QueryTemplate, "&TheNameOfThePropsDate", "CatalogFileOwner." + Attribute.Name);
				QueryFragment = StrReplace(QueryFragment, "DaysBeforeDeletionFromTheDate", "DaysBeforeDeletionFrom" + Attribute.Name);
				QueryAttributes = QueryAttributes + Chars.LF + QueryFragment + ",";
			EndIf;
			QueryAttributes = QueryAttributes + Chars.LF + "CatalogFileOwner." + Attribute.Name + ",";
		EndDo;
	EndIf;
	Return QueryAttributes;
	
EndFunction

#EndRegion

#Region FilesSynchronization

// Returns:
//   ValueTable:
//     * Ref - CatalogRef.FileSynchronizationAccounts
//     * Service - String
//
Function SynchronizationAccounts()
	
	Query = New Query;
	Query.Text = "SELECT DISTINCT
	|	FileSynchronizationAccounts.Ref,
	|	FileSynchronizationAccounts.Service
	|FROM
	|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
	|		LEFT JOIN Catalog.FileSynchronizationAccounts AS FileSynchronizationAccounts
	|		ON FileSynchronizationSettings.Account = FileSynchronizationAccounts.Ref
	|WHERE
	|	NOT FileSynchronizationAccounts.DeletionMark
	|	AND FileSynchronizationSettings.Synchronize";
	
	Return Query.Execute().Unload();
	
EndFunction

Procedure SetFilesSynchronizationScheduledJobParameter(Val ParameterName, Val ParameterValue) Export
	
	JobParameters = New Structure;
	JobParameters.Insert("Metadata", Metadata.ScheduledJobs.FilesSynchronization);
	If Not Common.DataSeparationEnabled() Then
		JobParameters.Insert("MethodName", Metadata.ScheduledJobs.FilesSynchronization.MethodName);
	EndIf;
	
	SetPrivilegedMode(True);
	
	JobsList = ScheduledJobsServer.FindJobs(JobParameters);
	If JobsList.Count() = 0 Then
		JobParameters.Insert(ParameterName, ParameterValue);
		ScheduledJobsServer.AddJob(JobParameters);
	Else
		JobParameters = New Structure(ParameterName, ParameterValue);
		For Each Job In JobsList Do
			ScheduledJobsServer.ChangeJob(Job, JobParameters);
		EndDo;
	EndIf;

EndProcedure

Function IsFilesFolder(OwnerObject) Export
	
	Return TypeOf(OwnerObject) = Type("CatalogRef.FilesFolders");
	
EndFunction

Function FileToEditInCloud(File)
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	FilesSynchronizationWithCloudServiceStatuses.File
		|FROM
		|	InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
		|WHERE
		|	FilesSynchronizationWithCloudServiceStatuses.File = &File";
	
	Query.SetParameter("File", File);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		Return True;
	EndDo;
	
	Return False;
	
EndFunction

Function OnDefineFileSynchronizationExceptionObjects() Export
	
	Return FilesSettings().NotSynchronizeFiles;
	
EndFunction

Function QueryTextToSynchronizeFIles(FileOwner, SyncSetup, ExceptionsArray, ExceptionItem)
	
	OwnerTypePresentation = Common.ObjectKindByType(TypeOf(FileOwner.EmptyRefValue));
	FullFilesCatalogName = SyncSetup.FileOwnerType.FullName;
	FilesObjectMetadata = Common.MetadataObjectByFullName(FullFilesCatalogName);
	HasAbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", FilesObjectMetadata);
	
	QueryText = "";
	
	FilesCatalog = Common.MetadataObjectByID(SyncSetup.FileOwnerType, False);
	If TypeOf(FilesCatalog) <> Type("MetadataObject") Then
		Return "";
	EndIf;
	AbilityToCreateGroups = FilesCatalog.Hierarchical;
	
	If TypeOf(FileOwner) <> Type("CatalogRef.MetadataObjectIDs") Then
		FoldersCatalog = Common.MetadataObjectByID(SyncSetup.OwnerID, False);
	Else
		FoldersCatalog = Common.MetadataObjectByID(FileOwner, False);
	EndIf;
	
	If TypeOf(FoldersCatalog) <> Type("MetadataObject") Then
		Return "";
	EndIf;
		
	QueryText = QueryText + "SELECT
	|	FoldersCatalog.Ref,"; // @query-part
	
	AddAvailableFilterFields(QueryText, FileOwner);
	
	QueryText = QueryText + "
	|	FilesCatalog.Ref AS FileRef,"; // @query-part
	
	If AbilityToCreateGroups Then
		
		QueryText = QueryText + "
		|	CASE WHEN FilesCatalog.IsFolder THEN
		|		FilesCatalog.Description
		|	ELSE
		|		FilesCatalog.Description + ""."" + FilesCatalog.Extension
		|	END AS Description,
		|	CASE WHEN FilesCatalog.IsFolder THEN
		|		""""
		|	ELSE
		|		FilesCatalog.Extension
		|	END AS Extension,
		|	CASE WHEN FilesCatalog.IsFolder THEN
		|		FALSE
		|	ELSE
		|		FilesCatalog.SignedWithDS
		|	END AS SignedWithDS,
		|	CASE WHEN FilesCatalog.IsFolder THEN
		|		FALSE
		|	ELSE
		|		FilesCatalog.Encrypted
		|	END AS Encrypted,
		|	FilesCatalog.DeletionMark AS DeletionMark,
		|	FilesCatalog.FileOwner AS Parent,
		|	FALSE AS Is_Directory,"; // @query-part
		
	Else
		
		QueryText = QueryText + "
		|	FilesCatalog.Description + ""."" + FilesCatalog.Extension AS Description,
		|	FilesCatalog.Extension AS Extension,
		|	FilesCatalog.SignedWithDS AS SignedWithDS,
		|	FilesCatalog.Encrypted AS Encrypted,
		|	FilesCatalog.DeletionMark AS DeletionMark,
		|	FilesCatalog.FileOwner AS Parent,
		|	FALSE AS Is_Directory,"; // @query-part
	
	EndIf;
	
	QueryText = QueryText + "
	|	TRUE AS InInfobase1,
	|	FALSE AS IsOnServer,
	|	UNDEFINED AS UPDATE,
	|	ISNULL(FilesSynchronizationWithCloudServiceStatuses.Href, """") AS Href,
	|	ISNULL(FilesSynchronizationWithCloudServiceStatuses.Etag, """") AS Etag,
	|	FALSE AS Processed,
	|	DATETIME(1, 1, 1, 0, 0, 0) AS SynchronizationDate,
	|	CAST("""" AS STRING(36)) AS UID1C,
	|	"""" AS ToHref,
	|	"""" AS ToEtag,
	|	"""" AS ParentServer,
	|	"""" AS DescriptionServer,
	|	FALSE AS ModifiedAtServer,
	|	FALSE AS EncryptedOnServer,
	|	UNDEFINED AS Level,
	|	"""" AS ParentOrdering,
	|	" + ?(HasAbilityToStoreVersions, "TRUE", "FALSE") + " AS IsFile
	|FROM
	|	Catalog." + FilesCatalog.Name + " AS FilesCatalog
	|		LEFT JOIN InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
	|		ON (FilesSynchronizationWithCloudServiceStatuses.File = FilesCatalog.Ref)
	|		LEFT JOIN " + OwnerTypePresentation+ "." + FoldersCatalog.Name + " AS FoldersCatalog
	|		On (FilesCatalog.FileOwner = FoldersCatalog.Ref)
	|WHERE
	|	VALUETYPE(FilesCatalog.FileOwner) = &OwnerType";
	
	ArrayOfConditions = New Array;
	If ExceptionsArray.Count() > 0 Then
		ArrayOfConditions.Add("NOT FoldersCatalog.Ref IN HIERARCHY (&ExceptionsArray)"); // @query-part
	EndIf;
	If ExceptionItem <> Undefined Then
		ArrayOfConditions.Add("FoldersCatalog.Ref IN HIERARCHY (&ExceptionItem)"); // @query-part
	EndIf;
	
	ConditionSelectionByFolders = "";
	If ArrayOfConditions.Count() > 0 Then
		ConditionSelectionByFolders = StrConcat(ArrayOfConditions, " And ");
	EndIf;
	
	If Not IsBlankString(ConditionSelectionByFolders) Then
		QueryText = QueryText + Chars.LF + "And " + ConditionSelectionByFolders;
	EndIf;
	
	QueryText = QueryText + "
	|
	|UNION ALL
	|
	|SELECT
	|	FoldersCatalog.Ref,"; // @query-part
	
	AddAvailableFilterFields(QueryText, FileOwner);
	
	QueryText = QueryText + "
	|	FoldersCatalog.Ref,
	|	" + ?(OwnerTypePresentation = "Document",
		"FoldersCatalog.Presentation", "FoldersCatalog.Description") + ",
	|	"""",
	|	FALSE,
	|	FALSE,
	|	FoldersCatalog.DeletionMark,";
	
	If Common.IsCatalog(FoldersCatalog) And FoldersCatalog.Hierarchical Then
		QueryText = QueryText + "
		|	CASE
		|		WHEN FoldersCatalog.Parent = VALUE(Catalog." + FoldersCatalog.Name + ".EmptyRef)
		|			THEN UNDEFINED
		|		ELSE FoldersCatalog.Parent
		|	END,";
	Else
		QueryText = QueryText + "Undefined,";
	EndIf;
	
	QueryText = QueryText + "
	|	TRUE,
	|	TRUE,
	|	FALSE,
	|	UNDEFINED,
	|	ISNULL(FilesSynchronizationWithCloudServiceStatuses.Href, """"),
	|	"""",
	|	FALSE,
	|	DATETIME(1, 1, 1, 0, 0, 0),
	|	"""",
	|	"""",
	|	"""",
	|	"""",
	|	"""",
	|	FALSE,
	|	FALSE,
	|	UNDEFINED,
	|	"""",
	|	" + ?(HasAbilityToStoreVersions, "TRUE", "FALSE") + "
	|FROM
	|	" + OwnerTypePresentation + "." + FoldersCatalog.Name + " AS FoldersCatalog
	|		LEFT JOIN InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
	|		ON (FilesSynchronizationWithCloudServiceStatuses.File = FoldersCatalog.Ref
	|			AND FilesSynchronizationWithCloudServiceStatuses.Account = &Account)";
	
	
	If Not IsBlankString(ConditionSelectionByFolders) Then
		QueryText = QueryText + Chars.LF + "WHERE " + ConditionSelectionByFolders;
	EndIf;
	
	Return QueryText;
	
EndFunction

Function IsFilesOwner(OwnerObject)
	
	FilesTypesArray = Metadata.DefinedTypes.AttachedFilesOwner.Type.Types();
	Return FilesTypesArray.Find(TypeOf(OwnerObject)) <> Undefined;
	
EndFunction

// Parameters:
//   FileOwner - DefinedType.AttachedFilesOwner
//
Procedure AddAvailableFilterFields(QueryText, FileOwner)
	
	AllCatalogs = Catalogs.AllRefsType();
	AllDocuments = Documents.AllRefsType();

	If AllCatalogs.ContainsType(TypeOf(FileOwner.EmptyRefValue)) Then
		Catalog = Metadata.Catalogs[FileOwner.Name];
		QueryTemplate = "FoldersCatalog.%1 AS %1,"; // @query-part
		For Each Attribute In Catalog.Attributes Do
			QueryText = QueryText + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
				QueryTemplate, Attribute.Name);
		EndDo;
	ElsIf AllDocuments.ContainsType(TypeOf(FileOwner.EmptyRefValue)) Then
		Document = Metadata.Documents[FileOwner.Name];
		QueryTemplate = "FoldersCatalog.%1,"; // @query-part
		RequestTemplateDate = "DATEDIFF(FoldersCatalog.%1, &CurrentDate, DAY) AS DaysBeforeDeletionFrom%1,"; // @query-part
		For Each Attribute In Document.Attributes Do
			If Attribute.Type.ContainsType(Type("Date")) Then
				QueryText = QueryText + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
					RequestTemplateDate, Attribute.Name);
			EndIf;
			QueryText = QueryText + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
				QueryTemplate, Attribute.Name);
		EndDo;
	EndIf;
	
EndProcedure

// Checks if an HTTP request failed and throws an exception.
Function CheckHTTP1CException(Response, ServerAddress)
	Result = New Structure("Success, ErrorText, ErrorCode");
	
	If IsErrorStateCode(Response.StatusCode) Then
		
		ErrorTemplate = NStr("en = 'Cannot synchronize the file at %2 as the server returned HTTP code %1. %3';");
		ErrorInfo = Response.GetBodyAsString();
		
		Result.Success = False;
		Result.ErrorCode = Response.StatusCode;
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, 
			Response.StatusCode, DecodeString(ServerAddress, StringEncodingMethod.URLInURLEncoding), ErrorInfo);
		
		Return Result;
		
	EndIf;
	
	Result.Success = True;
	Return Result;
	
EndFunction

// Performs the webdav protocol method.
Function PerformWebdavMethod(MethodName, FileAddressHRef, TitlesMap, ExchangeStructure, XMLQuery="", ProtocolText = Undefined)

	HrefStructure = URIStructureDecoded(FileAddressHRef);
	Join = CreateHTTPConnectionWebdav(HrefStructure, ExchangeStructure, 20);
	WebdavHTTPRequest = New HTTPRequest(HrefStructure.PathAtServer, TitlesMap);
	
	If ValueIsFilled(XMLQuery) Then
		WebdavHTTPRequest.SetBodyFromString(XMLQuery);
	EndIf;
	
	If ProtocolText <> Undefined Then
		ProtocolText = ProtocolText + ?(IsBlankString(ProtocolText), "", Chars.LF)
			+ MethodName + " " + FileAddressHRef + Chars.LF + Chars.LF + XMLQuery + Chars.LF;
	EndIf; 
	
	CallHTTPMethod(ExchangeStructure, Join, MethodName, WebdavHTTPRequest);
	
	If ProtocolText <> Undefined Then
		ProtocolText = ProtocolText + ?(IsBlankString(ProtocolText), "", Chars.LF) + "HTTP RESPONSE "
			+ ExchangeStructure.Response.StatusCode + Chars.LF + Chars.LF;
		For Each ResponseTitle In ExchangeStructure.Response.Headers Do
			ProtocolText = ProtocolText+ResponseTitle.Key + ": " + ResponseTitle.Value + Chars.LF;
		EndDo; 
		ProtocolText = ProtocolText + Chars.LF + ExchangeStructure.Response.GetBodyAsString() + Chars.LF;
	EndIf; 
	
	Return CheckHTTP1CException(ExchangeStructure.Response, FileAddressHRef);
	
EndFunction

Procedure CallHTTPMethod(ExchangeStructure, Join, MethodName, WebdavHTTPRequest, CurrentAttempt = 1)
	
	ExchangeStructure.Response = Join.CallHTTPMethod(MethodName, WebdavHTTPRequest);
	If ExchangeStructure.Response.StatusCode = 429
		And CurrentAttempt <= 5 Then
		
		CurrentTime = CurrentSessionDate();
		Timeout = CurrentTime + 2;
		While CurrentTime <= Timeout Do
			CurrentTime = CurrentSessionDate();
		EndDo;
		
		CallHTTPMethod(ExchangeStructure, Join, MethodName, WebdavHTTPRequest, CurrentAttempt + 1)
		
	EndIf;
	
EndProcedure

// Updates the unique service attribute of the file on the webdav server.
Function UpdateFileUID1C(FileAddressHRef, UID1C, SynchronizationParameters)
	
	HTTPHeaders                  = New Map;
	HTTPHeaders["User-Agent"]   = "1C Enterprise 8.3";
	HTTPHeaders["Content-type"] = "text/xml";
	HTTPHeaders["Accept"]       = "text/xml";
	
	XMLQuery = "<?xml version=""1.0"" encoding=""utf-8""?>
				|<D:propertyupdate xmlns:D=""DAV:"" xmlns:U=""tsov.pro"">
				|  <D:set><D:prop>
				|    <U:UID1C>%1</U:UID1C>
				|  </D:prop></D:set>
				|</D:propertyupdate>";
	XMLQuery = StringFunctionsClientServer.SubstituteParametersToString(XMLQuery, UID1C);
	
	Return PerformWebdavMethod("PROPPATCH", FileAddressHRef, HTTPHeaders, SynchronizationParameters, XMLQuery);
	
EndFunction

// Reads the unique service attribute of the file on the webdav server.
Function GetUID1C(FileAddressHRef, SynchronizationParameters)

	HTTPHeaders                 = New Map;
	HTTPHeaders["User-Agent"]   = "1C Enterprise 8.3";
	HTTPHeaders["Content-type"] = "text/xml";
	HTTPHeaders["Accept"]       = "text/xml";
	HTTPHeaders["Depth"]        = "0";
	
	Result = PerformWebdavMethod("PROPFIND",FileAddressHRef,HTTPHeaders,SynchronizationParameters,
					"<?xml version=""1.0"" encoding=""utf-8""?>
					|<D:propfind xmlns:D=""DAV:"" xmlns:U=""tsov.pro""><D:prop>
					|<U:UID1C />
					|</D:prop></D:propfind>");
	
	If Not Result.Success Then
		WriteToEventLogOfFilesSynchronization(Result.ErrorText, SynchronizationParameters.Account, 
			EventLogLevel.Error);
		Return "";
	EndIf;

	XmlContext = DefineXMLContext(SynchronizationParameters.Response.GetBodyAsString());
	FoundEtag = CalculateXPath("//*[local-name()='propstat'][contains(./*[local-name()='status'],'200')]/*[local-name()='prop']/*[local-name()='UID1C']",
		XmlContext).IterateNext();
	If FoundEtag <> Undefined Then
		Return FoundEtag.TextContent;
	EndIf;
	
	Return "";

EndFunction

// Checks if the webdav server supports user properties for the file.
Function CheckUID1CAbility(FileAddressHRef, UID1C, SynchronizationParameters)
	
	UpdateFileUID1C(FileAddressHRef, UID1C, SynchronizationParameters);
	Return ValueIsFilled(GetUID1C(FileAddressHRef, SynchronizationParameters));
	
EndFunction

// Runs MCKOL on the webdav server.
Function CallMKCOLMethod(FileAddressHRef, SynchronizationParameters)

	HTTPHeaders               = New Map;
	HTTPHeaders["User-Agent"] = "1C Enterprise 8.3";
	Return PerformWebdavMethod("MKCOL", FileAddressHRef, HTTPHeaders, SynchronizationParameters);

EndFunction

// Runs DELETE on the webdav server.
Function CallDELETEMethod(FileAddressHRef, SynchronizationParameters)
	
	HrefWithoutSlash = EndWithoutSlash(FileAddressHRef);
	HTTPHeaders               = New Map;
	HTTPHeaders["User-Agent"] = "1C Enterprise 8.3";
	Return PerformWebdavMethod("DELETE", HrefWithoutSlash, HTTPHeaders, SynchronizationParameters);
	
EndFunction

// Receives Etag of the file on the server.
Function GetEtag(FileAddressHRef, SynchronizationParameters)
	
	HTTPHeaders                 = New Map;
	HTTPHeaders["User-Agent"]   = "1C Enterprise 8.3";
	HTTPHeaders["Content-type"] = "text/xml";
	HTTPHeaders["Accept"]       = "text/xml";
	HTTPHeaders["Depth"]        = "0";
	
	Result = PerformWebdavMethod("PROPFIND",FileAddressHRef,HTTPHeaders,SynchronizationParameters,
					"<?xml version=""1.0"" encoding=""utf-8""?>
					|<D:propfind xmlns:D=""DAV:""><D:prop>
					|<D:getetag />
					|</D:prop></D:propfind>");
	
	If Not Result.Success Then
		WriteToEventLogOfFilesSynchronization(Result.ErrorText, SynchronizationParameters.Account, 
			EventLogLevel.Error);
		Return "";
	EndIf;
	
	XmlContext = DefineXMLContext(SynchronizationParameters.Response.GetBodyAsString());
	FoundEtag = CalculateXPath("//*[local-name()='propstat'][contains(./*[local-name()='status'],'200')]/*[local-name()='prop']/*[local-name()='getetag']",
		XmlContext).IterateNext();
	If FoundEtag <> Undefined Then
		Return FoundEtag.TextContent;
	EndIf;
	
	Return "";
	
EndFunction

// Initializes the HTTPConnection object.
Function CreateHTTPConnectionWebdav(HrefStructure, SynchronizationParameters, Timeout)
	
	InternetProxy = Undefined;
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownload = Common.CommonModule("GetFilesFromInternet");
		InternetProxy = ModuleNetworkDownload.GetProxy("https");
	EndIf;
	
	SecureConnection = Undefined;
	If HrefStructure.Schema = "https" Then 
		SecureConnection = CommonClientServer.NewSecureConnection();
	EndIf;
	
	If Not ValueIsFilled(HrefStructure.Port) Then
		Result = New HTTPConnection(
			HrefStructure.Host,
			,
			SynchronizationParameters.Login,
			SynchronizationParameters.Password,
			InternetProxy,
			Timeout,
			SecureConnection);
	Else
		Result = New HTTPConnection(
			HrefStructure.Host,
			HrefStructure.Port,
			SynchronizationParameters.Login,
			SynchronizationParameters.Password,
			InternetProxy,
			Timeout,
			SecureConnection);
	EndIf;
	
	Return Result;
	
EndFunction

// Calls the GET method at the webdav server and returns the imported file address in the temporary storage.
Function CallGETMethod(FileAddressHRef, EtagID, SynchronizationParameters, FileModificationDate = Undefined, FileLength = Undefined)

	Result = New Structure("Success, TempDataAddress, ErrorText");
	
	HrefStructure = URIStructureDecoded(FileAddressHRef);
	
	Timeout = ?(FileLength <> Undefined, CalculateTimeout(FileLength), 43200);
	Join = CreateHTTPConnectionWebdav(HrefStructure, SynchronizationParameters, Timeout);
	
	HTTPHeaders               = New Map;
	HTTPHeaders["User-Agent"] = "1C Enterprise 8.3";
	HTTPHeaders["Accept"]     = "application/octet-stream";
	
	WebdavHTTPRequest = New HTTPRequest(HrefStructure.PathAtServer, HTTPHeaders);
	SynchronizationParameters.Response = Join.Get(WebdavHTTPRequest);
	
	Result = CheckHTTP1CException(SynchronizationParameters.Response, FileAddressHRef);
	If Not Result.Success Then
		Return Result;
	EndIf;
	
	FileWithBinaryData = SynchronizationParameters.Response.GetBodyAsBinaryData(); // BinaryData
	
	// ACC:216-off External service IDs contain Latin and Cyrillic letters.
	Var_664_HTTPHeaders = StandardSubsystemsServer.HTTPHeadersInLowercase(SynchronizationParameters.Response.Headers);
	EtagID = ?(Var_664_HTTPHeaders["etagid"] = Undefined, "", Var_664_HTTPHeaders["etagid"]);
	FileModificationDate = ?(Var_664_HTTPHeaders["last-modified"] = Undefined, CurrentUniversalDate(), 
		CommonClientServer.RFC1123Date(Var_664_HTTPHeaders["last-modified"]));
	FileLength = FileWithBinaryData.Size();
	// ACC:216-on
	
	IsItSignedOrEncryptedData = IsItSignedOrEncryptedData(HrefStructure.PathAtServer, FileWithBinaryData);
	Result.Insert("ThisIsSignature", IsItSignedOrEncryptedData.Signature);
	Result.Insert("ThisIsEncryptedData", IsItSignedOrEncryptedData.EncryptedData);
	
	TempDataAddress = PutToTempStorage(FileWithBinaryData);
	Result.Insert("ImportedFileAddress", TempDataAddress);
	
	Return Result;

EndFunction

// Places the file on the webdav server using the PUT method and returns the assigned etag to a variable.
Function CallPUTMethod(FileAddressHRef, FileRef, SynchronizationParameters, IsFile)
	
	If TypeOf(FileRef) = Type("BinaryData") Then
		FileWithBinaryData = FileRef;
	Else
		FileWithBinaryData = FilesOperations.FileBinaryData(FileRef);
	EndIf;
	
	HrefStructure = URIStructureDecoded(FileAddressHRef);
	
	Timeout = CalculateTimeout(FileWithBinaryData.Size());
	Join = CreateHTTPConnectionWebdav(HrefStructure, SynchronizationParameters, Timeout);
	
	HTTPHeaders = New Map;
	HTTPHeaders["User-Agent"]   = "1C Enterprise 8.3";
	HTTPHeaders["Content-Type"] = "application/octet-stream";
	
	WebdavHTTPRequest = New HTTPRequest(HrefStructure.PathAtServer, HTTPHeaders);
	WebdavHTTPRequest.SetBodyFromBinaryData(FileWithBinaryData);
	SynchronizationParameters.Response = Join.Put(WebdavHTTPRequest);
	CheckHTTP1CException(SynchronizationParameters.Response, FileAddressHRef);
	Return GetEtag(FileAddressHRef,SynchronizationParameters);
	
EndFunction

// Imports file from server, creating a new version.
Function ImportFileFromServer(FileParameters, IsFile = Undefined)
	
	FileName                 = FileParameters.FileName;
	FileAddress               = FileParameters.Href;
	EtagID        = FileParameters.Etag;
	FileModificationDate     = FileParameters.FileModificationDate;
	FileLength               = FileParameters.FileLength;
	OwnerObject           = FileParameters.OwnerObject;
	ExistingFileRef = FileParameters.ExistingFileRef;
	SynchronizationParameters   = FileParameters.SynchronizationParameters;
	
	EventText = NStr("en = 'Upload file from server: %1';");
	WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(EventText, FileParameters.FileName), 
		SynchronizationParameters.Account);
	
	ImportResult1 = CallGETMethod(FileAddress, EtagID, SynchronizationParameters, FileModificationDate, FileLength);
	
	If IsFile = Undefined Then
		IsFile = IsFilesOwner(FileParameters.OwnerObject);
	EndIf;
	
	Encrypted = IsFile = True And ImportResult1.ThisIsEncryptedData;
	
	If Encrypted And StrEndsWith(FileName, ".p7m") Then
		FileName = NameOfEncryptedFile(FileName);
		FileParameters.FileName = FileName;
	EndIf;
	
	If ImportResult1.Success And ImportResult1.ImportedFileAddress <> Undefined Then
		
		ImportedFileAddress = ImportResult1.ImportedFileAddress;
		
		FileNameStructure = New File(FileName);
		
		If ExistingFileRef = Undefined Then
			
			FileToAddParameters = FilesOperations.FileAddingOptions();
			If StrStartsWith(OwnerObject.Metadata().FullName(), "Catalog") And OwnerObject.IsFolder Then
				FileToAddParameters.FilesGroup = OwnerObject;
				FileToAddParameters.FilesOwner = OwnerObject.FileOwner;
			Else
				FileToAddParameters.FilesOwner = OwnerObject;
			EndIf;
			
			FileToAddParameters.Author = SynchronizationParameters.FilesAuthor;
			FileToAddParameters.BaseName = FileNameStructure.BaseName;
			FileToAddParameters.ExtensionWithoutPoint = CommonClientServer.ExtensionWithoutPoint(FileNameStructure.Extension);
			FileToAddParameters.ModificationTimeUniversal = FileModificationDate;
			FileToAddParameters.Insert("Encrypted", Encrypted);
			FileParameters.Encrypted = Encrypted;
			
			NewFile = FilesOperations.AppendFile(FileToAddParameters, ImportedFileAddress);
			
			BorrowFileToEditServer(NewFile, SynchronizationParameters.FilesAuthor);
			
		Else
			
			FileAttributes = Common.ObjectAttributesValues(ExistingFileRef, "StoreVersions, CurrentVersion");
			Mode = ?(FileAttributes.StoreVersions, "FileWithVersion", "File");
			
			FileInfo1 = FilesOperationsClientServer.FileInfo1(Mode);

			FileInfo1.BaseName              = FileNameStructure.BaseName;
			FileInfo1.TempFileStorageAddress = ImportedFileAddress;
			FileInfo1.ExtensionWithoutPoint            = CommonClientServer.ExtensionWithoutPoint(
				FileNameStructure.Extension);
			FileInfo1.ModificationTimeUniversal   = FileModificationDate;
			FileInfo1.Encrypted                    = Encrypted;

			If FileInfo1.StoreVersions Then
				FileInfo1.NewVersionAuthor          = SynchronizationParameters.FilesAuthor;
			EndIf;
			
			If FileParameters.Encrypted <> Encrypted Then
				
				DataToWriteAtServer = New Structure;
				DataToWriteAtServer.Insert("TempStorageAddress", ImportedFileAddress);
				DataToWriteAtServer.Insert("VersionRef", FileAttributes.CurrentVersion);
				DataToWriteAtServer.Insert("TempTextStorageAddress", "");
				DataToWriteAtServer.Insert("FileAddress", "");
				
				EncryptionInformationWriteParameters = EncryptionInformationWriteParameters();
				EncryptionInformationWriteParameters.Encrypt = Encrypted;
				EncryptionInformationWriteParameters.DataArrayToStoreInDatabase.Add(DataToWriteAtServer);
				EncryptionInformationWriteParameters.FileInfo1 = FileInfo1;
				
				WriteEncryptionInformation(ExistingFileRef, EncryptionInformationWriteParameters);
			Else
				FilesOperationsInternalServerCall.SaveFileChanges(ExistingFileRef, FileInfo1, True, "", "", False);
			EndIf;
			
			NewFile = ExistingFileRef;
			
		EndIf;
		
		UID1CFile = String(NewFile.UUID());
		UpdateFileUID1C(FileAddress, UID1CFile, SynchronizationParameters);
		
		RememberRefServerData(NewFile, FileAddress, EtagID, IsFile, OwnerObject, False, SynchronizationParameters.Account);
		
		MessageText = NStr("en = 'File ""%1"" is uploaded from the cloud service.';");
		StatusForEventLog = EventLogLevel.Information;
	Else
		MessageText = NStr("en = 'Cannot upload file ""%1"" from the cloud service. Reason:';") + " " + Chars.LF + ImportResult1.ErrorText;
		StatusForEventLog = EventLogLevel.Error;
	EndIf;
	
	WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(MessageText, FileName), 
		SynchronizationParameters.Account, StatusForEventLog);
	
	Return NewFile;

EndFunction

Procedure WriteToEventLogOfFilesSynchronization(MessageText, Account, EventLogLevelToSet = Undefined)

	If EventLogLevelToSet = Undefined Then
		EventLogLevelToSet = EventLogLevel.Information;
	EndIf;

	WriteLogEvent(EventLogEventSynchronization(),
					EventLogLevelToSet,,
					Account,
					MessageText);
	
EndProcedure

Function EventLogEventSynchronization()
	
	Return NStr("en = 'Files.Synchronization with cloud service';", Common.DefaultLanguageCode());
	
EndFunction

// Reads basic status of the directory on the server. Used to check the connection.
Procedure ReadDirectoryParameters(CheckResult, HttpAddress, ExchangeStructure)

	HTTPAddressStructure = URIStructureDecoded(HttpAddress);
	ServerAddress = EncodeURIByStructure(HTTPAddressStructure);
	
	Try
		// Get a directory.
		HTTPHeaders = New Map;
		HTTPHeaders["User-Agent"]   = "1C Enterprise 8.3";
		HTTPHeaders["Content-type"] = "text/xml";
		HTTPHeaders["Accept"]       = "text/xml";
		HTTPHeaders["Depth"]        = "0";
		
		Result = PerformWebdavMethod("PROPFIND", ServerAddress, HTTPHeaders, ExchangeStructure,
						"<?xml version=""1.0"" encoding=""utf-8""?>
						|<D:propfind xmlns:D=""DAV:"" xmlns:U=""tsov.pro""><D:prop>
						|<D:quota-used-bytes /><D:quota-available-bytes />
						|</D:prop></D:propfind>",
						CheckResult.ResultProtocol);
		
		If Result.Success = False Then
			
			RootFolderCreationResult = CallMKCOLMethod(ServerAddress, ExchangeStructure);
			If RootFolderCreationResult.Success = True Then
				
				Result = PerformWebdavMethod("PROPFIND", ServerAddress, HTTPHeaders, ExchangeStructure,
								"<?xml version=""1.0"" encoding=""utf-8""?>
								|<D:propfind xmlns:D=""DAV:"" xmlns:U=""tsov.pro""><D:prop>
								|<D:quota-used-bytes /><D:quota-available-bytes />
								|</D:prop></D:propfind>",
								CheckResult.ResultProtocol);
								
			EndIf;
			
		EndIf;
		
		If Not Result.Success Then
			
			CheckResult.Cancel = True;
			CheckResult.ErrorCode = Result.ErrorCode;
			CheckResult.ResultText = Result.ErrorText;
			WriteToEventLogOfFilesSynchronization(Result.ErrorText, ExchangeStructure.Account, 
				EventLogLevel.Error);
			Return;
		
		EndIf;
		
		XMLDocumentContext = DefineXMLContext(ExchangeStructure.Response.GetBodyAsString());
		XPathResult = CalculateXPath("//*[local-name()='response']",XMLDocumentContext);
		FoundResponse = XPathResult.IterateNext();
		
		While FoundResponse <> Undefined Do
			
			FoundPropstat = CalculateXPath("./*[local-name()='propstat'][contains(./*[local-name()='status'],'200')]/*[local-name()='prop']", 
				XMLDocumentContext, FoundResponse).IterateNext();
			If FoundPropstat<>Undefined Then
				For Each PropstatChildNode In FoundPropstat.ChildNodes Do
					If PropstatChildNode.LocalName = "quota-available-bytes" Then
						Try
							SizeInMegabytes = Round(Number(PropstatChildNode.TextContent)/1024/1024, 1);
						Except
							SizeInMegabytes = 0;
						EndTry;
						
						FreeSpaceInformation = NStr("en = 'Free space: %1 MB';");
						
						CheckResult.ResultText = CheckResult.ResultText 
							+ ?(IsBlankString(CheckResult.ResultText), "", Chars.LF)
							+ StringFunctionsClientServer.SubstituteParametersToString(FreeSpaceInformation, SizeInMegabytes);
					ElsIf PropstatChildNode.LocalName = "quota-used-bytes" Then
						Try
							SizeInMegabytes = Round(Number(PropstatChildNode.TextContent)/1024/1024, 1);
						Except
							SizeInMegabytes = 0;
						EndTry;
						
						OccupiedSpaceInformation = NStr("en = 'Occupied: %1 MB';");
						
						CheckResult.ResultText = CheckResult.ResultText 
							+ ?(IsBlankString(CheckResult.ResultText), "", Chars.LF)
							+ StringFunctionsClientServer.SubstituteParametersToString(OccupiedSpaceInformation, SizeInMegabytes);
					EndIf; 
				EndDo; 
			EndIf; 
			
			FoundResponse = XPathResult.IterateNext();
			
		EndDo;
	
	Except
		ErrorDescription = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		CheckResult.ResultText = CheckResult.ResultText + ?(IsBlankString(CheckResult.ResultText), "", Chars.LF) + ErrorDescription;
		WriteToEventLogOfFilesSynchronization(ErrorDescription, ExchangeStructure.Account, EventLogLevel.Error);
		CheckResult.Cancel = True;
	EndTry; 
	
EndProcedure

Procedure CheckIfCanStoreFiles(CheckResult, HttpAddress, SynchronizationParameters)
	FileAddressHRef = EndWithoutSlash(HttpAddress) + StartWithSlash("test.txt");
	HrefStructure = URIStructureDecoded(FileAddressHRef);
	FileWithBinaryData = GetBinaryDataFromString("test");
	
	Timeout = CalculateTimeout(FileWithBinaryData.Size());
	Join = CreateHTTPConnectionWebdav(HrefStructure, SynchronizationParameters, Timeout);
	
	HTTPHeaders = New Map;
	HTTPHeaders["User-Agent"]   = "1C Enterprise 8.3";
	HTTPHeaders["Content-Type"] = "application/octet-stream";
	
	WebdavHTTPRequest = New HTTPRequest(HrefStructure.PathAtServer, HTTPHeaders);
	WebdavHTTPRequest.SetBodyFromBinaryData(FileWithBinaryData);
	SynchronizationParameters.Response = Join.Put(WebdavHTTPRequest);
	FileSendingResult = CheckHTTP1CException(SynchronizationParameters.Response, FileAddressHRef);
	
	CheckResult.ResultProtocol = CheckResult.ResultProtocol + ?(CheckResult.ResultProtocol = "", "", Chars.LF)
		+ "PUT" + " " + FileAddressHRef + Chars.LF;
	
	If FileSendingResult.Success Then
		CheckResult.ResultProtocol = CheckResult.ResultProtocol + ?(IsBlankString(CheckResult.ResultProtocol), "", Chars.LF) + "HTTP RESPONSE "
			+ SynchronizationParameters.Response.StatusCode + Chars.LF + Chars.LF;
		For Each ResponseTitle In SynchronizationParameters.Response.Headers Do
			CheckResult.ResultProtocol = CheckResult.ResultProtocol+ResponseTitle.Key + ": " + ResponseTitle.Value + Chars.LF;
		EndDo; 
	Else
		WriteToEventLogOfFilesSynchronization(CheckResult.ResultText, SynchronizationParameters.Account, EventLogLevel.Error);
	    CheckResult.Cancel = True;
		CheckResult.ErrorCode = CheckResult.ErrorCode;
		Return;
	EndIf;
	
	HTTPHeaders["Content-type"] = "text/xml";
	HTTPHeaders["Accept"]       = "text/xml";
	
	XMLQuery = "<?xml version=""1.0"" encoding=""utf-8""?>
				|<D:propertyupdate xmlns:D=""DAV:"" xmlns:U=""tsov.pro"">
				|  <D:set><D:prop>
				|    <U:UID1C>%1</U:UID1C>
				|  </D:prop></D:set>
				|</D:propertyupdate>";
	XMLQuery = StringFunctionsClientServer.SubstituteParametersToString(XMLQuery, New UUID);
	
	PropertySettingResult = PerformWebdavMethod("PROPPATCH", FileAddressHRef, HTTPHeaders, SynchronizationParameters, XMLQuery, CheckResult.ResultProtocol);
	
	If Not PropertySettingResult.Success Then
		WriteToEventLogOfFilesSynchronization(PropertySettingResult.ErrorText, SynchronizationParameters.Account, EventLogLevel.Error);
		CheckResult.ErrorCode = PropertySettingResult.ErrorCode;
	    CheckResult.Cancel = True;
		CheckResult.ResultText = CheckResult.ResultText + ?(IsBlankString(CheckResult.ResultText), "", Chars.LF) + PropertySettingResult.ErrorText;
		Return;
	Else
		XmlContext = DefineXMLContext(SynchronizationParameters.Response.GetBodyAsString());
		ResponseNode = CalculateXPath("//*[local-name()='propstat']/*[local-name()='status']", XmlContext).IterateNext();
		PropertySetResponseCode = Number(StrSplit(ResponseNode.FirstChild.TextContent, " ")[1]);
		If IsErrorStateCode(PropertySetResponseCode) Then
			CheckResult.Cancel = True;
			CheckResult.ErrorCode = 10000+PropertySetResponseCode;
			
			ErrorTemplate = NStr("en = 'Cannot set the file property at %2 as the server returned an HTTP code: %1. %3';");
			ErrorInfo = SynchronizationParameters.Response.GetBodyAsString();
		
			CheckResult.ResultText = CheckResult.ResultText + ?(IsBlankString(CheckResult.ResultText), "", Chars.LF) 
				+ StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, PropertySetResponseCode, 
				DecodeString(FileAddressHRef, StringEncodingMethod.URLInURLEncoding), ErrorInfo);
			
			CheckResult.ResultProtocol = CheckResult.ResultProtocol + ?(IsBlankString(CheckResult.ResultProtocol), "", Chars.LF) + "HTTP RESPONSE "
			+ ResponseNode.FirstChild.TextContent + Chars.LF + Chars.LF;
			For Each ResponseTitle In SynchronizationParameters.Response.Headers Do
				CheckResult.ResultProtocol = CheckResult.ResultProtocol+ResponseTitle.Key + ": " + ResponseTitle.Value + Chars.LF;
			EndDo; 
			CheckResult.ResultProtocol = CheckResult.ResultProtocol + Chars.LF + SynchronizationParameters.Response.GetBodyAsString() + Chars.LF;
		EndIf;
	EndIf;
	
	FileDeletionResult = CallDELETEMethod(FileAddressHRef, SynchronizationParameters);
	
	If Not FileDeletionResult.Success Then
		WriteToEventLogOfFilesSynchronization(FileDeletionResult.ErrorText, SynchronizationParameters.Account, EventLogLevel.Error);
		CheckResult.ErrorCode = FileDeletionResult.ErrorCode;
	    CheckResult.Cancel = True;
		CheckResult.ResultText = CheckResult.ResultText + ?(IsBlankString(CheckResult.ResultText), "", Chars.LF) + FileDeletionResult.ErrorText;
	EndIf;
EndProcedure

// Returns URI structure
Function URIStructureDecoded(Val URIString1)
	
	URIString1 = TrimAll(URIString1);
	
	// Schema
	Schema = "";
	Position = StrFind(URIString1, "://");
	If Position > 0 Then
		Schema = Lower(Left(URIString1, Position - 1));
		URIString1 = Mid(URIString1, Position + 3);
	EndIf;

	// Connection string and path on the server.
	ConnectionString = URIString1;
	PathAtServer = "";
	Position = StrFind(ConnectionString, "/");
	If Position > 0 Then
		// First slash included
		PathAtServer = Mid(ConnectionString, Position);
		ConnectionString = Left(ConnectionString, Position - 1);
	EndIf;
		
	// User details and server name.
	AuthorizationString = "";
	ServerName = ConnectionString;
	Position = StrFind(ConnectionString, "@");
	If Position > 0 Then
		AuthorizationString = Left(ConnectionString, Position - 1);
		ServerName = Mid(ConnectionString, Position + 1);
	EndIf;
	
	// Username and password
	Login = AuthorizationString;
	Password = "";
	Position = StrFind(AuthorizationString, ":");
	If Position > 0 Then
		Login = Left(AuthorizationString, Position - 1);
		Password = Mid(AuthorizationString, Position + 1);
	EndIf;
	
	// Host and port.
	Host = ServerName;
	Port = "";
	Position = StrFind(ServerName, ":");
	If Position > 0 Then
		Host = Left(ServerName, Position - 1);
		Port = Mid(ServerName, Position + 1);
	EndIf;
	
	Result = New Structure;
	Result.Insert("Schema", Lower(Schema));
	Result.Insert("Login", Login);
	Result.Insert("Password", Password);
	Result.Insert("ServerName", Lower(ServerName));
	Result.Insert("Host", Lower(Host));
	Result.Insert("Port", ?(IsBlankString(Port), Undefined, Number(Port)));
	Result.Insert("PathAtServer", DecodeString(EndWithoutSlash(PathAtServer),StringEncodingMethod.URLInURLEncoding)); 
	
	// A path on the server will always have the first but not the last slash, it is universal for files and folders.
	Return Result; 
	
EndFunction

// Returns URI, composed from a structure.
Function EncodeURIByStructure(Val URIStructure, IncludingPathAtServer = True)
	Result = "";
	
	// Protocol.
	If Not IsBlankString(URIStructure.Schema) Then
		Result = Result + URIStructure.Schema + "://";
	EndIf;
	
	// Authorization.
	If Not IsBlankString(URIStructure.Login) Then
		Result = Result + URIStructure.Login + ":" + URIStructure.Password + "@";
	EndIf;
		
	// The rest.
	Result = Result + URIStructure.Host;
	If ValueIsFilled(URIStructure.Port) Then
		Result = Result + ":" + ?(TypeOf(URIStructure.Port) = Type("Number"), Format(URIStructure.Port, "NG=0"), URIStructure.Port);
	EndIf;
	
	Result = Result + ?(IncludingPathAtServer, EndWithoutSlash(URIStructure.PathAtServer), "");
	
	// Always without the final slash
	Return Result; 
	
EndFunction

// Returns a string that is guaranteed to begin with a forward slash.
Function StartWithSlash(Val InitialString)
	Return ?(Left(InitialString,1)="/", InitialString, "/"+InitialString);
EndFunction 

// Returns a string that is guaranteed to end without a forward slash.
Function EndWithoutSlash(Val InitialString)
	Return ?(Right(InitialString,1)="/", Left(InitialString, StrLen(InitialString)-1), InitialString);
EndFunction

// Returns the result of comparing the tow URI paths, regardless of having the starting and final forward slash,
// encoding of special characters, as well as the server address.
//
Function IsIdenticalURIPaths(URI1, URI2, SensitiveToRegister = True, IgnoreEncryptedExtension = False)
	
	// Ensures identity regardless of slashes and encoding.
	URI1Structure = URIStructureDecoded(URI1); 
	URI2Structure = URIStructureDecoded(URI2);
	If Not SensitiveToRegister Then
		URI1Structure.PathAtServer = Lower(URI1Structure.PathAtServer);
		URI2Structure.PathAtServer = Lower(URI2Structure.PathAtServer);
	EndIf;
	
	EncodedURI1 = EncodeURIByStructure(URI1Structure,True);
	EncodedURI2 = EncodeURIByStructure(URI2Structure,True);
	
	Result = EncodedURI1 = EncodedURI2;
	
	If Not Result And IgnoreEncryptedExtension Then
		If StrEndsWith(EncodedURI1, ".p7m") Then
			EncodedURI1 = NameOfEncryptedFile(EncodedURI1);
		EndIf;
		If StrEndsWith(EncodedURI2, ".p7m") Then
			EncodedURI2 = NameOfEncryptedFile(EncodedURI2);
		EndIf;
		Result = EncodedURI1 = EncodedURI2;
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the file name by the file address.
Function FileNameFromAddress(FileAddress)

	URIString = EndWithoutSlash(FileAddress);
	URILength = StrLen(URIString);
	
	// Finding the last slash, after it the file name is located.
	For IndexOf = 1 To URILength Do
		URISymbol = Mid(URIString,URILength - IndexOf + 1, 1);
		If URISymbol = "/" Then
			Return DecodeString(Mid(URIString,URILength - IndexOf + 2), StringEncodingMethod.URLEncoding);
		EndIf;
	EndDo;
	
	Return DecodeString(URIString, StringEncodingMethod.URLEncoding);

EndFunction

// Saves data about Href and Etag of a file or folder to the database.
Procedure RememberRefServerData(
		Ref,
		FileAddressHRef,
		EtagID,
		IsFile,
		FileOwner,
		Is_Directory,
		Account = Undefined)

	RegisterRecord = InformationRegisters.FilesSynchronizationWithCloudServiceStatuses.CreateRecordManager();
	RegisterRecord.File                        = Ref;
	RegisterRecord.Href                        = FileAddressHRef;
	RegisterRecord.Etag                        = EtagID;
	RegisterRecord.UUID1C   = ?(TypeOf(Ref) = Type("String"), "", Ref.UUID());
	RegisterRecord.IsFile                     = IsFile;
	RegisterRecord.IsFileOwner            = Is_Directory;
	RegisterRecord.FileOwner               = FileOwner;
	RegisterRecord.Account               = Account;
	RegisterRecord.IsSynchronized             = False;
	RegisterRecord.SynchronizationDateStart     = CurrentSessionDate();
	RegisterRecord.SynchronizationDateCompletion = CurrentSessionDate() + 1800; // 30 minutes.
	RegisterRecord.SessionNumber                 = InfoBaseSessionNumber();
	RegisterRecord.Write(True);
	
EndProcedure

// Saves data about Href and Etag of a file or folder to the database.
Procedure SetFileSyncStatus(FileInfo1, Account)

	RegisterRecord = InformationRegisters.FilesSynchronizationWithCloudServiceStatuses.CreateRecordManager();
	RegisterRecord.File                        = FileInfo1.FileRef;
	RegisterRecord.Href                        = FileInfo1.ToHref;
	RegisterRecord.Etag                        = FileInfo1.ToEtag;
	RegisterRecord.UUID1C   = FileInfo1.FileRef.UUID();
	RegisterRecord.IsFile                     = FileInfo1.IsFile;
	RegisterRecord.IsFileOwner            = FileInfo1.Is_Directory;
	RegisterRecord.FileOwner               = FileInfo1.Parent;
	RegisterRecord.IsSynchronized             = FileInfo1.Processed;
	RegisterRecord.SynchronizationDateStart     = CurrentSessionDate();
	RegisterRecord.SynchronizationDateCompletion = CurrentSessionDate();
	RegisterRecord.SessionNumber                 = InfoBaseSessionNumber();
	
	RegisterRecord.Account               = Account;
	
	RegisterRecord.Write(True);
	
EndProcedure

// Deletes data about Href and Etag of a file or folder to the database.
Procedure DeleteFileSyncStatus(FileRef, Account)

	RegisterSet = InformationRegisters.FilesSynchronizationWithCloudServiceStatuses.CreateRecordSet();
	RegisterSet.Filter.File.Set(FileRef);
	RegisterSet.Filter.Account.Set(Account);
	RegisterSet.Write(True);

EndProcedure

Procedure LockFileSyncStatus(Block, FileRef, Account)

	LockItem = Block.Add("InformationRegister.FilesSynchronizationWithCloudServiceStatuses");
	LockItem.SetValue("File", FileRef);
	LockItem.SetValue("Account", Account);
	
EndProcedure

// Defines xml context
Function DefineXMLContext(XMLText)
	
	ReadXMLText = New XMLReader;
	ReadXMLText.SetString(XMLText);
	DOMBuilderForXML = New DOMBuilder;
	DOMDocumentForXML = DOMBuilderForXML.Read(ReadXMLText);
	NamesResolverForXML = New DOMNamespaceResolver(DOMDocumentForXML);
	Return New Structure("DOMDocument,DOMDereferencer", DOMDocumentForXML, NamesResolverForXML); 
	
EndFunction

// Calculates xpath expression for xml context.
Function CalculateXPath(Expression, Context, ContextNode = Undefined)
	
	Return Context.DOMDocument.EvaluateXPathExpression(Expression,?(ContextNode=Undefined,Context.DOMDocument,ContextNode),Context.DOMDereferencer);
	
EndFunction

// Returns Href, calculated for a row from a file table by the search of all parents method.
Function CalculateHref(FilesRow,TableOfFiles)
	
	// Retrieve descriptions recursively.
	FilesRowsFound = TableOfFiles.Find(FilesRow.Parent,"FileRef");
	If FilesRowsFound = Undefined Then
		Return ?(ValueIsFilled(FilesRow.Description),
			CommonClientServer.ReplaceProhibitedCharsInFileName(FilesRow.Description, "-") + "/","");
	Else
		Return CalculateHref(FilesRowsFound,TableOfFiles)
			+ CommonClientServer.ReplaceProhibitedCharsInFileName(FilesRow.Description, "-") +"/";
	EndIf;
	
EndFunction

// Returns a file table row by URI, while considering the possible different spelling of URI 
// (for example, encoded, relative or absolute, and so on).
//
Function FindRowByURI(SoughtURI, TableWithURI, URIColumn, IgnoreEncryptedExtension = False)

	For Each TableRow In TableWithURI Do
		If IsIdenticalURIPaths(SoughtURI,TableRow[URIColumn],,IgnoreEncryptedExtension) Then
			Return TableRow;
		EndIf; 
	EndDo; 
	
	Return Undefined;
	
EndFunction

// The level of the file row is calculated by a recursive algorithm.
Function LevelRecursively(FilesRow,TableOfFiles)
	
	// Equals to the level in the database or on the server, depending on where it is less.
	FilesRowsFound = TableOfFiles.FindRows(New Structure("FileRef", FilesRow.Parent));
	AdditionCount = ?(FilesRowsFound.Count() = 0, 0, 1);
	For Each FilesRowFound In FilesRowsFound Do
		AdditionCount = AdditionCount + LevelRecursively(FilesRowFound,TableOfFiles);
	EndDo;
	
	Return AdditionCount;
	
EndFunction

// The file level on the webdav server is calculated using a recursive algorithm.
Function RecursivelyLevelAtServer(FilesRow,TableOfFiles) 
	
	FilesRowsFound = TableOfFiles.FindRows(New Structure("FileRef", FilesRow.ParentServer));
	AdditionCount = ?(FilesRowsFound.Count() = 0, 0, 1);
	For Each FilesRowFound In FilesRowsFound Do
		AdditionCount = AdditionCount + RecursivelyLevelAtServer(FilesRowFound, TableOfFiles);
	EndDo;
	
	Return AdditionCount;
	
EndFunction

// Calculates the levels of all rows in the file table.
Procedure CalculateLevelRecursively(TableOfFiles)
	TableOfFiles.Indexes.Add("FileRef");
	For Each FilesRow In TableOfFiles Do
		
		If Not ValueIsFilled(FilesRow.FileRef) Then
			Continue;
		EndIf;
		
		// Equals to the level in the database or on the server, depending on where it is less.
		LevelInBase    = LevelRecursively(FilesRow, TableOfFiles);
		LevelAtServer = RecursivelyLevelAtServer(FilesRow, TableOfFiles);
		If LevelAtServer = 0 Then
			FilesRow.Level            = LevelInBase;
			FilesRow.ParentOrdering = FilesRow.Parent;
		Else
			If LevelInBase <= LevelAtServer Then
				FilesRow.Level            = LevelInBase;
				FilesRow.ParentOrdering = FilesRow.Parent;
			Else
				FilesRow.Level            = LevelAtServer;
				FilesRow.ParentOrdering = FilesRow.ParentServer;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Recursively imports the list of files from the server into the file table.
Procedure ImportFilesTreeRecursively(CurrentRowsOfFilesTree, HttpAddress, SynchronizationParameters, Cancel=False)

	HTTPAddressStructure   = URIStructureDecoded(HttpAddress);
	CloudServiceAddress = EncodeURIByStructure(HTTPAddressStructure, False);
	ServerAddress          = EncodeURIByStructure(HTTPAddressStructure);
	
	Try
		// Get a directory.
		HTTPHeaders = New Map;
		HTTPHeaders["User-Agent"] = "1C Enterprise 8.3";
		HTTPHeaders["Content-type"] = "text/xml";
		HTTPHeaders["Accept"] = "text/xml";
		HTTPHeaders["Depth"] = "1";
		
		Result = PerformWebdavMethod("PROPFIND", ServerAddress, HTTPHeaders, SynchronizationParameters,
						"<?xml version=""1.0"" encoding=""utf-8""?>
						|<D:propfind xmlns:D=""DAV:"" xmlns:U=""tsov.pro""><D:prop>
						|<D:getetag /><U:UID1C /><D:resourcetype />
						|<D:getlastmodified /><D:getcontentlength />
						|</D:prop></D:propfind>");
		
		If Result.Success = False Then
			WriteToEventLogOfFilesSynchronization(Result.ErrorText, SynchronizationParameters.Account, 
				EventLogLevel.Error);
			Return;
		EndIf;
		
		XMLDocumentContext = DefineXMLContext(SynchronizationParameters.Response.GetBodyAsString());
		
		XPathResult = CalculateXPath("//*[local-name()='response']", XMLDocumentContext);
		
		FoundResponse = XPathResult.IterateNext();
		
		While FoundResponse <> Undefined Do
			
			// There is always Href, otherwise, it is a critical error.
			FoundHref = CalculateXPath("./*[local-name()='href']", XMLDocumentContext, FoundResponse).IterateNext();
			If FoundHref = Undefined Then
				ErrorText = NStr("en = 'The server returned an error: HREF is not found in %1.';");
				Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorText, ServerAddress);
			EndIf; 
			
			HrefText = EndWithoutSlash(StartWithSlash(FoundHref.TextContent));
			
			If IsIdenticalURIPaths(CloudServiceAddress + HrefText, ServerAddress) Then
				FoundResponse = XPathResult.IterateNext();
				Continue;
			EndIf; 
			
			NewFilesTreeRow = CurrentRowsOfFilesTree.Add();
			// Always encoded.
			NewFilesTreeRow.Href = CloudServiceAddress + DecodeString(HrefText, StringEncodingMethod.URLEncoding);
			NewFilesTreeRow.FileName = FileNameFromAddress(NewFilesTreeRow.Href);
			NewFilesTreeRow.Etag = "";
			NewFilesTreeRow.UID1C = "";
			NewFilesTreeRow.Is_Directory = Undefined;
			
			FoundPropstat = CalculateXPath("./*[local-name()='propstat'][contains(./*[local-name()='status'],'200')]/*[local-name()='prop']", XMLDocumentContext, FoundResponse).IterateNext();
			
			If FoundPropstat <> Undefined Then
				For Each PropstatChildNode In FoundPropstat.ChildNodes Do
					If PropstatChildNode.LocalName = "resourcetype" Then
						NewFilesTreeRow.Is_Directory = CalculateXPath("./*[local-name()='collection']", XMLDocumentContext, PropstatChildNode).IterateNext() <> Undefined;
					ElsIf PropstatChildNode.LocalName = "UID1C" Then
						NewFilesTreeRow.UID1C = PropstatChildNode.TextContent;
						NewFilesTreeRow.UID1CNotSupported = False;
					ElsIf PropstatChildNode.LocalName = "getetag" Then
						NewFilesTreeRow.Etag = PropstatChildNode.TextContent;
					ElsIf PropstatChildNode.LocalName = "getlastmodified" Then
						NewFilesTreeRow.ModificationDate = CommonClientServer.RFC1123Date(PropstatChildNode.TextContent);//UTC
					ElsIf PropstatChildNode.LocalName = "getcontentlength" Then
						NewFilesTreeRow.Length = Number("0" + StrReplace(PropstatChildNode.TextContent," ",""));
					EndIf;
				EndDo;
			EndIf;
			
			FoundPropstat = CalculateXPath("./*[local-name()='propstat'][contains(./*[local-name()='status'],'404')]/*[local-name()='prop']", XMLDocumentContext, FoundResponse).IterateNext();
			
			If FoundPropstat <> Undefined Then
				For Each PropstatChildNode In FoundPropstat.ChildNodes Do
					If PropstatChildNode.NodeName = "UID1C" Then
						NewFilesTreeRow.UID1CNotSupported = True;
					EndIf;
				EndDo;
			EndIf;
			
			// If there was no UID, we try to receive it separately, it is necessary, for example, for owncloud.
			If NewFilesTreeRow.UID1CNotSupported = False And Not ValueIsFilled(NewFilesTreeRow.UID1C) Then
				NewFilesTreeRow.UID1C = GetUID1C(NewFilesTreeRow.Href, SynchronizationParameters);
			EndIf;
			
			FoundResponse = XPathResult.IterateNext();
			
		EndDo;
	
	Except
		WriteToEventLogOfFilesSynchronization(ErrorProcessing.DetailErrorDescription(ErrorInfo()), 
			SynchronizationParameters.Account, EventLogLevel.Error);
		Cancel = True;
	EndTry;
	
	For Each FilesTreeRow In CurrentRowsOfFilesTree Do
		If FilesTreeRow.Is_Directory = True Then
			ImportFilesTreeRecursively(FilesTreeRow.Rows, FilesTreeRow.Href, SynchronizationParameters, Cancel);
		EndIf;
	EndDo;
	
EndProcedure

// Imports new folders and files from webdav server that are not yet in the database, and reflects them in the file table.
Procedure ImportNewAttachedFiles(FilesTreeRows, TableOfFiles, SynchronizationParameters, Signatures, OwnerObject = Undefined)
	
	FilesOwners = FileOwnersByUIDs(FilesTreeRows);
	For Each FilesTreeRow In FilesTreeRows Do
		
		If FilesTreeRow.Is_Directory Then
			CurrentFilesFolder = Undefined;
			If Not IsBlankString(FilesTreeRow.UID1C) Then
				TableRow = FilesOwners.Find(New UUID(FilesTreeRow.UID1C), "UUID1C");
				If TableRow <> Undefined Then
					CurrentFilesFolder = TableRow.File; // DefinedType.FilesOwner
				EndIf;
			EndIf;
			
			If (CurrentFilesFolder = Undefined) And (TableOfFiles.Find(FilesTreeRow.Href, "Href") = Undefined) Then
				
				// This is a new server directory. If it's located in the exchange directory root or
				// sync metadata object type root, it doesn't relate to the owner. Ignore such directories.
				// 
				If OwnerObject = Undefined
					Or TypeOf(OwnerObject) = Type("CatalogRef.MetadataObjectIDs") Then
					Continue;
				EndIf;
				
				// Checking if it is possible to store UID1C. If it is not, folder is not loaded.
				If Not CheckUID1CAbility(FilesTreeRow.Href, String(New UUID), SynchronizationParameters) Then
					EventText = NStr("en = 'Cannot download file %1 because an error occurred when saving its additional properties.';");
					WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(
							EventText, FilesTreeRow.FileName), 
						SynchronizationParameters.Account, EventLogLevel.Error);
					Continue;
				EndIf;
				
				Try
					
					CurrentFilesFolder = FilesOperationsInternalServerCall.CreateFilesFolder(FilesTreeRow.FileName, 
						OwnerObject, SynchronizationParameters.FilesAuthor);
					
					FilesTreeRow.UID1C = String(CurrentFilesFolder.UUID());
					UpdateFileUID1C(FilesTreeRow.Href, FilesTreeRow.UID1C, SynchronizationParameters);
					
					NewFilesTableRow                    = TableOfFiles.Add();
					NewFilesTableRow.FileRef         = CurrentFilesFolder;
					NewFilesTableRow.DeletionMark    = False;
					NewFilesTableRow.Parent           = OwnerObject;
					NewFilesTableRow.Is_Directory           = True;
					NewFilesTableRow.UID1C              = FilesTreeRow.UID1C;
					NewFilesTableRow.InInfobase1          = True;
					NewFilesTableRow.IsOnServer      = True;
					NewFilesTableRow.ModifiedAtServer   = False;
					NewFilesTableRow.Changes          = CurrentFilesFolder;
					NewFilesTableRow.Href               = "";
					NewFilesTableRow.Etag               = "";
					NewFilesTableRow.ToHref             = FilesTreeRow.Href;
					NewFilesTableRow.ToEtag             = FilesTreeRow.Etag;
					NewFilesTableRow.ParentServer     = OwnerObject;
					NewFilesTableRow.Description       = FilesTreeRow.FileName;
					NewFilesTableRow.DescriptionServer = FilesTreeRow.FileName;
					NewFilesTableRow.Processed          = True;
					NewFilesTableRow.IsFile            = True;
					
					RememberRefServerData(
						NewFilesTableRow.FileRef,
						NewFilesTableRow.ToHref,
						NewFilesTableRow.ToEtag,
						NewFilesTableRow.IsFile,
						NewFilesTableRow.Parent,
						NewFilesTableRow.Is_Directory,
						SynchronizationParameters.Account);
					
					EventText = NStr("en = 'Downloaded folder from server %1.';");
					WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(
							EventText, NewFilesTableRow.DescriptionServer), 
						SynchronizationParameters.Account);
					
				Except
					WriteToEventLogOfFilesSynchronization(ErrorProcessing.DetailErrorDescription(ErrorInfo()),
						SynchronizationParameters.Account, EventLogLevel.Error);
				EndTry;

				Continue;
			EndIf;
				
			If Not ValueIsFilled(CurrentFilesFolder) Then
				
				// Information record register FilesSynchronizationWithCloudServiceStatuses contains no information about the directory. Search it in the files.
				PreviousFIlesTableRow = TableOfFiles.Find(FilesTreeRow.Href, "Href");
				If PreviousFIlesTableRow = Undefined Then
					PreviousFIlesTableRow = TableOfFiles.Find(DecodeString(FilesTreeRow.Href,
						StringEncodingMethod.URLInURLEncoding), "Href");
				EndIf;
				
				If PreviousFIlesTableRow = Undefined Then
					EventText = NStr("en = 'Skipped synchronization of the %1 folder. The folder is missing on the server.';");
					WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(
						EventText, DecodeString(FilesTreeRow.Href, StringEncodingMethod.URLInURLEncoding)),
						SynchronizationParameters.Account, EventLogLevel.Error);
					Continue;
				EndIf;
				
				// The directory is found by "Href". Now, find the record in the "FilesSynchronizationWithCloudServiceStatuses" information register by "UID1C".
				// @skip-check query-in-loop - A rare query in a cycle during batch data import.
				CurrentFilesFolder = FileOwnerByUID(PreviousFIlesTableRow.UID1C);	
				If Not ValueIsFilled(CurrentFilesFolder) Then
					EventText = NStr("en = 'Cannot synchronize the %1 folder.
						|The %2 folder ID is missing in the file synchronization information records.';");
					WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(
						EventText, DecodeString(FilesTreeRow.Href, StringEncodingMethod.URLInURLEncoding),
							PreviousFIlesTableRow.UID1C),
						SynchronizationParameters.Account, EventLogLevel.Error);
					Continue;
				EndIf;
				
			Else
				PreviousFIlesTableRow = TableOfFiles.Find(CurrentFilesFolder.Ref, "FileRef");
			EndIf;
			
			// Update ToHref.
			If PreviousFIlesTableRow <> Undefined Then
				PreviousFIlesTableRow.ToHref             = FilesTreeRow.Href;
				PreviousFIlesTableRow.ToEtag             = FilesTreeRow.Etag;
				PreviousFIlesTableRow.ParentServer     = OwnerObject;
				PreviousFIlesTableRow.DescriptionServer = FilesTreeRow.FileName;
				PreviousFIlesTableRow.IsOnServer      = True;
				PreviousFIlesTableRow.ModifiedAtServer   = Not IsIdenticalURIPaths(PreviousFIlesTableRow.ToHref,PreviousFIlesTableRow.Href);
			EndIf;
			
			// @skip-check query-in-loop - Recursive algorithm of tree processing.
			ImportNewAttachedFiles(FilesTreeRow.Rows, TableOfFiles, SynchronizationParameters, Signatures, CurrentFilesFolder.Ref);
			Continue;
			
		EndIf;

		// This is a file.
		If OwnerObject = Undefined
			Or TypeOf(OwnerObject) = Type("CatalogRef.MetadataObjectIDs") Then
			// The file is skipped because the user added it to an incorrect folder that has no owner.
			Continue;
		EndIf;
		
		CurrentFile = FindRowByURI(FilesTreeRow.Href, TableOfFiles, "Href", True);
		
		IsItSignedOrEncryptedData = IsItSignedOrEncryptedData(FilesTreeRow.Href);
		
		If CurrentFile = Undefined And IsItSignedOrEncryptedData.Signature Then
			AddSignatureFromService(Signatures, FilesTreeRow);
			Continue;
		EndIf;
		
		If (CurrentFile = Undefined) Or (TableOfFiles.Find(CurrentFile.FileRef ,"FileRef") = Undefined) Then
			// This is a new file on the server, importing it.
			If Not CheckUID1CAbility(FilesTreeRow.Href, String(New UUID), SynchronizationParameters) Then
				EventText = NStr("en = 'Cannot download file %1 because an error occurred when saving its additional properties.';");
				WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(
					EventText, FilesTreeRow.FileName), SynchronizationParameters.Account, EventLogLevel.Error);
				Continue;
			EndIf;
			
			Try
				
				FileParameters = New Structure;
				FileParameters.Insert("FileName",                 FilesTreeRow.FileName);
				FileParameters.Insert("Href",                     FilesTreeRow.Href);
				FileParameters.Insert("Etag",                     FilesTreeRow.Etag);
				FileParameters.Insert("FileModificationDate",     FilesTreeRow.ModificationDate);
				FileParameters.Insert("FileLength",               FilesTreeRow.Length);
				FileParameters.Insert("ForUser",          SynchronizationParameters.FilesAuthor);
				FileParameters.Insert("OwnerObject",           OwnerObject);
				FileParameters.Insert("ExistingFileRef", Undefined);
				FileParameters.Insert("SynchronizationParameters",   SynchronizationParameters);
				FileParameters.Insert("Encrypted",               False);
				
				ExistingFileRef = ImportFileFromServer(FileParameters);
				
				FilesTreeRow.UID1C = String(ExistingFileRef.Ref.UUID());
				
				NewFilesTableRow                    = TableOfFiles.Add();
				NewFilesTableRow.FileRef         = ExistingFileRef;
				NewFilesTableRow.DeletionMark    = False;
				NewFilesTableRow.Parent           = OwnerObject;
				NewFilesTableRow.Is_Directory           = False;
				NewFilesTableRow.UID1C              = FilesTreeRow.UID1C;
				NewFilesTableRow.InInfobase1          = False;
				NewFilesTableRow.IsOnServer      = True;
				NewFilesTableRow.ModifiedAtServer   = False;
				NewFilesTableRow.Href               = "";
				NewFilesTableRow.Etag               = "";
				NewFilesTableRow.ToHref             = FilesTreeRow.Href;
				NewFilesTableRow.ToEtag             = FilesTreeRow.Etag;
				NewFilesTableRow.ParentServer     = OwnerObject;
				NewFilesTableRow.Description       = FileParameters.FileName;
				NewFilesTableRow.DescriptionServer = FileParameters.FileName;
				NewFilesTableRow.Processed          = True;
				NewFilesTableRow.IsFile            = True;
				NewFilesTableRow.Encrypted         = FileParameters.Encrypted;
				
			Except
				WriteToEventLogOfFilesSynchronization(ErrorProcessing.DetailErrorDescription(ErrorInfo()), 
					SynchronizationParameters.Account, EventLogLevel.Error);
			EndTry;
			
		Else
			// Update ToHref.
			PreviousFIlesTableRow                    = TableOfFiles.Find(CurrentFile.FileRef,"FileRef");
			PreviousFIlesTableRow.ToHref             = FilesTreeRow.Href;
			PreviousFIlesTableRow.ToEtag             = FilesTreeRow.Etag;
			PreviousFIlesTableRow.ParentServer     = OwnerObject;
			
			If StrEndsWith(FilesTreeRow.FileName, ".p7m") Then
				PreviousFIlesTableRow.DescriptionServer = NameOfEncryptedFile(FilesTreeRow.FileName);
				PreviousFIlesTableRow.EncryptedOnServer = True;
			Else
				PreviousFIlesTableRow.DescriptionServer = FilesTreeRow.FileName;
			EndIf;
			
			PreviousFIlesTableRow.IsOnServer      = True;
			PreviousFIlesTableRow.ModifiedAtServer   = Not IsIdenticalURIPaths(PreviousFIlesTableRow.ToHref, PreviousFIlesTableRow.Href);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure UploadFileSignatures(FileRef, Signatures, SynchronizationParameters)
	
	If Not Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;

	ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
	ModuleDigitalSignatureClientServer = Common.CommonModule("DigitalSignatureClientServer");
	FileSignatures = ModuleDigitalSignature.SetSignatures(FileRef);
	
	ErrorSignatureDataCouldNotBeRead = "";
	
	SignaturesToAdd = New Array;
	
	UID1C = String(FileRef.UUID());
	
	For Each FileParameters In Signatures Do 
		
		If Not IsBlankString(FileParameters.UID1C) And StrStartsWith(FileParameters.UID1C, UID1C) Then
			Continue; // The signature is already synchronized with the cloud.
		EndIf;
		
		FileName                 = FileParameters.FileName;
		FileAddress               = FileParameters.Href;
		EtagID        = FileParameters.Etag;
		FileModificationDate     = FileParameters.FileModificationDate;
		FileLength               = FileParameters.FileLength;

		EventText = NStr("en = 'Import the signature from the server: %1';");
		WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(EventText,
			FileParameters.FileName), SynchronizationParameters.Account);

		ImportResult1 = CallGETMethod(FileAddress, EtagID, SynchronizationParameters,
			FileModificationDate, FileLength);
			
		If ImportResult1.Success And ImportResult1.ImportedFileAddress <> Undefined Then
			
			If Not ImportResult1.ThisIsSignature Then
				EventText = NStr("en = 'This is not a signature file: %1';");
				WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(
					EventText, FileName), SynchronizationParameters.Account, EventLogLevel.Error);
				Continue;
			EndIf;
			
			ImportedFileAddress = ImportResult1.ImportedFileAddress;
			
			Signature = GetFromTempStorage(ImportedFileAddress);
			
			SignatureAdded = False;
			For Each FileSignature In FileSignatures Do
				If FileSignature.Signature = Signature Then
					SignatureAdded = True;
					Break;
				EndIf;
			EndDo;
			
			If SignatureAdded Then
				Continue;
			EndIf;
			
			SignatureData = ModuleDigitalSignatureClientServer.NewSignatureProperties();
			SignatureData.Signature = Signature;
			
			ResultOfReadSignatureProperties = ModuleDigitalSignature.SignatureProperties(Signature);
			
			If ResultOfReadSignatureProperties.Success <> False Then
				FillPropertyValues(SignatureData, ResultOfReadSignatureProperties);
				SignatureData.Insert("DateSignedFromLabels", ResultOfReadSignatureProperties.DateSignedFromLabels);
				SignatureData.Insert("UnverifiedSignatureDate", ResultOfReadSignatureProperties.UnverifiedSignatureDate);
			Else
				If IsBlankString(ErrorSignatureDataCouldNotBeRead) Then
					EventText = NStr("en = 'Cannot read the %1 file signature data: %2';");
					ErrorSignatureDataCouldNotBeRead = StringFunctionsClientServer.SubstituteParametersToString(
						EventText, FileName, ResultOfReadSignatureProperties.ErrorText);
				EndIf;
			EndIf;
			
			SignaturesToAdd.Add(SignatureData);

			UID1CFile = UID1C + PostfixForCaption(FileSignatures.Count() + SignaturesToAdd.UBound());
			UpdateFileUID1C(FileAddress, UID1CFile, SynchronizationParameters);

			MessageText = NStr("en = 'The signature from the cloud service is imported: ""%1""';");
			StatusForEventLog = EventLogLevel.Information;
		Else
			MessageText = NStr("en = 'Cannot import the %1 signature from the cloud service. Reason:';") + " "
				+ Chars.LF + ImportResult1.ErrorText;
			StatusForEventLog = EventLogLevel.Error;
		EndIf;
		
		WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(MessageText, FileName), 
			SynchronizationParameters.Account, StatusForEventLog);
		
	EndDo;
	
	If SignaturesToAdd.Count() > 0 Then
		ModuleDigitalSignature.AddSignature(FileRef, SignaturesToAdd);
	EndIf;
	
	If ValueIsFilled(ErrorSignatureDataCouldNotBeRead) Then
		WriteToEventLogOfFilesSynchronization(
			ErrorSignatureDataCouldNotBeRead, SynchronizationParameters.Account, EventLogLevel.Information);
	EndIf;

EndProcedure

Function NameOfEncryptedFile(Description)
	
	Return Left(Description, StrLen(Description) - 4);
	
EndFunction

Function IsItSignedOrEncryptedData(Href, BinaryData = Undefined)
	
	Result = New Structure("Signature, EncryptedData", False, False);
	
	If Not Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return Result;
	EndIf;
	
	If StrEndsWith(Lower(Href), ".p7s") Then
		Result.Signature = True;
	ElsIf StrEndsWith(Lower(Href), ".p7m") Then
		Result.EncryptedData = True;
	EndIf;
	
	If Not Result.EncryptedData And Not Result.Signature Or BinaryData = Undefined Then
		Return Result;
	EndIf;
	
	ModuleDigitalSignatureInternalClientServer = Common.CommonModule("DigitalSignatureInternalClientServer");
	DataType = ModuleDigitalSignatureInternalClientServer.DefineDataType(BinaryData);
	Result.Signature             = DataType = "Signature";
	Result.EncryptedData = DataType = "EncryptedData";
	
	Return Result;
	
EndFunction

Procedure AddSignatureFromService(Signatures, FilesTreeRow)
	
	StartOfSignatureExtension = StrLen(FilesTreeRow.Href) - 3;
	
	If Mid(FilesTreeRow.Href, StartOfSignatureExtension - 1, 1) = ")" Then
		Found4 = StrFind(FilesTreeRow.Href, "(", SearchDirection.FromEnd);
		FileHref = Left(FilesTreeRow.Href, Found4 - 1);
	Else
		FileHref = Left(FilesTreeRow.Href, StartOfSignatureExtension - 1); 
	EndIf;
	
	SignaturesArray = Signatures.Get(FileHref);

	If SignaturesArray = Undefined Then
		SignaturesArray = New Array;
	EndIf;
	
	FileParameters = New Structure;
	FileParameters.Insert("FileName",                 FilesTreeRow.FileName);
	FileParameters.Insert("Href",                     FilesTreeRow.Href);
	FileParameters.Insert("Etag",                     FilesTreeRow.Etag);
	FileParameters.Insert("FileModificationDate",     FilesTreeRow.ModificationDate);
	FileParameters.Insert("FileLength",               FilesTreeRow.Length);
	FileParameters.Insert("UID1C",                    FilesTreeRow.UID1C);
	
	SignaturesArray.Add(FileParameters);
	
	Signatures.Insert(FileHref, SignaturesArray);
	
EndProcedure

Procedure FillDataFromCloudService(FilesTreeRows, TableOfFiles, SynchronizationParameters, 
	OwnerObject = Undefined)
	
	Folders = FileOwnersByUIDs(FilesTreeRows);	
	For Each FilesTreeRow In FilesTreeRows Do
		
		If FilesTreeRow.Is_Directory = True Then 
			// Identify the directory using "UID1C". If not found, then retry using the old "Href"
			// (UID could be lost during edit, and the new Href might not be found yet).
			// If UID is lost and the directory is moved to another directory ("Href" changed), it will be loaded to
			// the new folder card, which justifies search by "Href" as it is unique for each directory on the file server.
			CurrentFilesFolder = Undefined;
			If Not IsBlankString(FilesTreeRow.UID1C) Then
				TableRow = Folders.Find(New UUID(FilesTreeRow.UID1C), "UUID1C");
				If TableRow <> Undefined Then
					CurrentFilesFolder = TableRow.File; // DefinedType.FilesOwner
				EndIf;
			EndIf;
			
			If CurrentFilesFolder = Undefined Then
				// Can be marked for deletion, then it has no Href and it will not be found.
				CurrentFilesFolder = FindRowByURI(FilesTreeRow.Href, TableOfFiles, "Href");
			EndIf; 
			
			PreviousFIlesTableRow = TableOfFiles.Find(CurrentFilesFolder.Ref, "FileRef");
			If CurrentFilesFolder = Undefined Or PreviousFIlesTableRow = Undefined Then
				Continue;
			EndIf;
			
			If (CurrentFilesFolder <> Undefined) Or (PreviousFIlesTableRow <> Undefined) Then
				PreviousFIlesTableRow.ToHref = FilesTreeRow.Href;
				PreviousFIlesTableRow.ToEtag = FilesTreeRow.Etag;
				PreviousFIlesTableRow.ParentServer = OwnerObject;
				PreviousFIlesTableRow.DescriptionServer = FilesTreeRow.FileName;
				PreviousFIlesTableRow.IsOnServer = True;
				PreviousFIlesTableRow.ModifiedAtServer = Not IsIdenticalURIPaths(PreviousFIlesTableRow.ToHref,
					PreviousFIlesTableRow.Href);
			EndIf; 
			
			// @skip-check query-in-loop - Recursive algorithm of tree processing.
			FillDataFromCloudService(FilesTreeRow.Rows, TableOfFiles, SynchronizationParameters, 
				CurrentFilesFolder.Ref);
			Continue;
			
		EndIf; 
		
		// This is a file.
		// Identify the file using "UID1C". If not found, then retry using the old "Href"
		// (UID could be lost during edit, and the new Href might not be found yet).
		// If UID is lost and the file is moved to another directory ("Href" changed), it will be loaded to
		// the new file card, which justifies search by "Href" as it is unique for each file on the file server.
		
		CurrentFile = FindRowByURI(FilesTreeRow.Href, TableOfFiles, "Href");
		If (CurrentFile <> Undefined) And (TableOfFiles.Find(CurrentFile.FileRef, "FileRef") <> Undefined) Then
			// Update ToHref.
			PreviousFIlesTableRow = TableOfFiles.Find(CurrentFile.FileRef, "FileRef");
			PreviousFIlesTableRow.ToHref = FilesTreeRow.Href;
			PreviousFIlesTableRow.ToEtag = FilesTreeRow.Etag;
			PreviousFIlesTableRow.ParentServer = OwnerObject;
			PreviousFIlesTableRow.DescriptionServer = FilesTreeRow.FileName;
			PreviousFIlesTableRow.IsOnServer = True;
			PreviousFIlesTableRow.ModifiedAtServer = Not IsIdenticalURIPaths(PreviousFIlesTableRow.ToHref,
				PreviousFIlesTableRow.Href);
		EndIf; 
			
	EndDo; 
	
EndProcedure

Function FileOwnersByUIDs(FilesTreeRows)
	UniqueIdentifiers = New Array; 
	For Each FilesTreeRow In FilesTreeRows Do
		If FilesTreeRow.Is_Directory = True And Not IsBlankString(FilesTreeRow.UID1C) Then 
			UniqueIdentifiers.Add(New UUID(FilesTreeRow.UID1C));
		EndIf; 
	EndDo;
	
	If UniqueIdentifiers.Count() = 0 Then
		Return New ValueTable;
	EndIf;
		
	Query = New Query(
		"SELECT
		|	FilesSynchronizationWithCloudServiceStatuses.File AS File,
		|	FilesSynchronizationWithCloudServiceStatuses.UUID1C AS UUID1C
		|FROM
		|	InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
		|WHERE
		|	FilesSynchronizationWithCloudServiceStatuses.UUID1C IN (&UniqueIdentifiers)");
	Query.SetParameter("UniqueIdentifiers", UniqueIdentifiers);
	Return Query.Execute().Unload();

EndFunction

Function FileOwnerByUID(UID1C)

	Query = New Query(
		"SELECT
		|	FilesSynchronizationWithCloudServiceStatuses.File AS File
		|FROM
		|	InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
		|WHERE
		|	FilesSynchronizationWithCloudServiceStatuses.UUID1C = &UUID");
	If TypeOf(UID1C) = Type("String") Then
		Query.SetParameter("UUID", New UUID(UID1C));
	Else	
		Query.SetParameter("UUID", UID1C);
	EndIf;
	Result = Query.Execute().Unload();
	Return ?(Result.Count() > 0, Result[0].File, Undefined);

EndFunction

// Parameters:
//  Account - CatalogRef.FileSynchronizationAccounts
// 
// Returns:
//  Structure:
//   * Account - CatalogRef.FileSynchronizationAccounts
//   * ServerAddress - String
//   * RootDirectory - String
//   * FilesAuthor - CatalogRef.FileSynchronizationAccounts, CatalogRef.Users
//   * ServerAddressStructure - String
//   * Response - String
//   * Login - String
//   * Password - String
//
Function FilesSyncProperties(Account)

	ReturnStructure = New Structure("ServerAddressStructure, Response, Login, Password");
	Query = New Query(
		"SELECT
		|	FileSynchronizationAccounts.Ref AS Account,
		|	FileSynchronizationAccounts.Service AS ServerAddress,
		|	FileSynchronizationAccounts.RootDirectory AS RootDirectory,
		|	FileSynchronizationAccounts.FilesAuthor AS FilesAuthor
		|FROM
		|	Catalog.FileSynchronizationAccounts AS FileSynchronizationAccounts
		|WHERE
		|	FileSynchronizationAccounts.Ref = &Ref
		|	AND FileSynchronizationAccounts.DeletionMark = FALSE");
	
	Query.SetParameter("Ref", Account);
	Result = Query.Execute().Unload();
	If Result.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	For Each ResultColumn In Result.Columns Do
		ReturnStructure.Insert(ResultColumn.Name, Result[0][ResultColumn.Name]);
	EndDo; 
	
	If Not IsBlankString(ReturnStructure.RootDirectory) Then
		ReturnStructure.ServerAddress = ReturnStructure.ServerAddress + "/" + ReturnStructure.RootDirectory;
	EndIf;
	
	If IsBlankString(ReturnStructure.FilesAuthor) Then
		ReturnStructure.FilesAuthor = Account;
	EndIf;
	
	ReturnStructure.ServerAddressStructure = URIStructureDecoded(ReturnStructure.ServerAddress);
	
	SetPrivilegedMode(True);
	ReturnStructure.Login =  Common.ReadDataFromSecureStorage(Account, "Login");
	ReturnStructure.Password = Common.ReadDataFromSecureStorage(Account);
	SetPrivilegedMode(False);
	
	Return ReturnStructure;

EndFunction

Procedure SynchronizeFilesWithCloudService(Account)
	
	SynchronizationParameters = FilesSyncProperties(Account);
	If SynchronizationParameters = Undefined Then
		Return;
	EndIf;
	
	EventText = NStr("en = 'File synchronization with cloud service started.';");
	WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account);
	
	ExecuteFilesSynchronizationWithCloudService(SynchronizationParameters);
	
	EventText = NStr("en = 'File synchronization with the cloud service is completed.';");
	WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account);

EndProcedure

Procedure ExecuteFilesSynchronizationWithCloudService(SynchronizationParameters)
	
	// Root record about the synchronization start
	RememberRefServerData("", "", "", False, Undefined, False, SynchronizationParameters.Account);

	ServerFilesTree = GenerateStructureOfServerFilesTree();
	ServerAddress        = EncodeURIByStructure(SynchronizationParameters.ServerAddressStructure);
	
	If Not IsBlankString(SynchronizationParameters.RootDirectory) Then
		
		HTTPHeaders                 = New Map;
		HTTPHeaders["User-Agent"]   = "1C Enterprise 8.3";
		HTTPHeaders["Content-type"] = "text/xml";
		HTTPHeaders["Accept"]       = "text/xml";
		HTTPHeaders["Depth"]        = "0";
		
		Try
			Result = PerformWebdavMethod("PROPFIND", ServerAddress, HTTPHeaders, SynchronizationParameters);
			If Not Result.Success Then
				CallMKCOLMethod(ServerAddress, SynchronizationParameters);
			EndIf;
		Except
			EventText = NStr("en = 'Cannot create a root folder on the server. The files are not synchronized.';");
			WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account, EventLogLevel.Error);
			Return;
		EndTry
		
	EndIf;
	
	Cancel = False;
	SynchronizationCompleted = True;
	
	ImportFilesTreeRecursively(ServerFilesTree.Rows, ServerAddress, SynchronizationParameters, Cancel);
	If Cancel = True Then
		EventText = NStr("en = 'Cannot synchronize the files because an error occurred when uploading the file structure from the server.';");
		WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account, EventLogLevel.Error);
		Return;
	EndIf;
	
	// Comparing it with the file tree in the system, synchronization by UUID.
	TableOfFiles = SelectDataByRules(SynchronizationParameters.Account);
	If TableOfFiles = Undefined Then
		EventText = NStr("en = 'Cannot synchronize the files because an error occurred when getting a file table from the infobase.';");
		WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account, EventLogLevel.Error);
		Return;
	EndIf;
	
	For Each TableRow In TableOfFiles Do
		TableRow.UID1C = String(TableRow.FileRef.UUID());
	EndDo;
	
	Signatures = New Map;
	
	// Looping through the tree, importing and adding missing ones at the base to the table, and filling attributes from the server according to the old ones.
	ImportNewAttachedFiles(ServerFilesTree.Rows, TableOfFiles, SynchronizationParameters, Signatures);
	
	CalculateLevelRecursively(TableOfFiles);
	TableOfFiles.Indexes.Add("FileRef");
	
	TableOfFiles.Sort("Level, ParentOrdering, Is_Directory DESC");
	If Not SynchronizeFiles(TableOfFiles, SynchronizationParameters, ServerAddress, Signatures, False) Then
		SynchronizationCompleted = False;
	EndIf;
	
	TableOfFiles.Sort("Level DESC, ParentOrdering, Is_Directory DESC");
	If Not SynchronizeFiles(TableOfFiles, SynchronizationParameters, ServerAddress, Undefined, True) Then
		SynchronizationCompleted = False;
	EndIf;
	
	WriteSynchronizationResult(SynchronizationParameters.Account, SynchronizationCompleted);
	
EndProcedure

Function SynchronizeFiles(TableOfFiles, SynchronizationParameters, ServerAddress, Signatures, IsFilesDeletion = False)
	
	SynchronizationCompleted = True;
	For Each TableRow In TableOfFiles Do
		
		If TableRow.Processed Then
			SetFileSyncStatus(TableRow, SynchronizationParameters.Account);
			Continue;
		EndIf;
		
		UpdateFileSynchronizationStatus = False;
		
		CreatedNewInBase            = (Not ValueIsFilled(TableRow.Href)) And (Not ValueIsFilled(TableRow.ToHref));
		
		ModifiedInBase                = ValueIsFilled(TableRow.Changes); // Something changed
		ModifiedContentAtServer = ValueIsFilled(TableRow.ToEtag) And (TableRow.Etag <> TableRow.ToEtag); // something has changed
		ModifiedAtServer            = ModifiedContentAtServer Or TableRow.ModifiedAtServer; // the content has changed
		
		DeletedInBase                 = TableRow.DeletionMark;
		DeletedAtServer             = ValueIsFilled(TableRow.Href) And Not ValueIsFilled(TableRow.ToHref);
		
		BeginTransaction();
		Try
			If IsRefToFile(TableRow.FileRef) Then
				DataLock = New DataLock;
				DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(TableRow.FileRef)).FullName());
				DataLockItem.SetValue("Ref", TableRow.FileRef);
				LockFileSyncStatus(DataLock, TableRow.FileRef, SynchronizationParameters.Account);
				DataLock.Lock();  
			EndIf;
			
			If IsFilesDeletion Then
				If DeletedAtServer And Not DeletedInBase Then
					UpdateFileSynchronizationStatus = DeleteFileInCloudService(SynchronizationParameters, TableRow);
				EndIf;
			Else
				
				If CreatedNewInBase And Not DeletedInBase Then
					// Import file to the cloud server
					UpdateFileSynchronizationStatus = CreateFileInCloudService(ServerAddress, SynchronizationParameters, TableRow, TableOfFiles);
					
				ElsIf (ModifiedInBase Or ModifiedAtServer) And Not (DeletedInBase Or DeletedAtServer) Then
					
					If ModifiedAtServer And TableRow.SignedWithDS Then
						Raise NStr("en = 'You cannot import changed files with signatures in the application from the cloud.
							|Delete the signatures from the application and add them to the cloud to synchronize the file.';")
					EndIf;
					
					If ModifiedAtServer And Not ModifiedInBase Then
						UpdateFileSynchronizationStatus = ModifyFileInCloudService(ModifiedContentAtServer, UpdateFileSynchronizationStatus, SynchronizationParameters, TableRow);
					EndIf;
					
				EndIf;
				
			EndIf;
			
			If UpdateFileSynchronizationStatus Then
				// Writing updates to the information register of statuses.
				If TableRow.DeletionMark Then
					// Deleting the last Href not to identify it again.
					DeleteFileSyncStatus(TableRow.FileRef, SynchronizationParameters.Account);
				Else
					SetFileSyncStatus(TableRow, SynchronizationParameters.Account);
				EndIf;
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			TableRow.SynchronizationDate = CurrentSessionDate();
			SetFileSyncStatus(TableRow, SynchronizationParameters.Account);
			
			SynchronizationCompleted = False;
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot synchronize file ""%1"". Reason:';"), String(TableRow.FileRef))
				+ Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo());
			WriteToEventLogOfFilesSynchronization(ErrorText, SynchronizationParameters.Account, EventLogLevel.Error);
		EndTry;
		
	EndDo;
	
	If ValueIsFilled(Signatures) Then
		
		For Each KeyAndValue In Signatures Do
			
			CurrentFile = FindRowByURI(KeyAndValue.Key, TableOfFiles, "ToHref", True);
			
			If CurrentFile = Undefined Then
				EventText = NStr("en = 'The %1 file to import signatures is not found.';");
				WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(
					EventText, KeyAndValue.Key),
				SynchronizationParameters.Account, EventLogLevel.Error);
				Continue;
			EndIf;
			
			If CurrentFile.Processed Or Not CurrentFile.ModifiedAtServer Then
				UploadFileSignatures(CurrentFile.FileRef, KeyAndValue.Value, SynchronizationParameters);
			EndIf;
		
		EndDo;
		
	EndIf;

	Return SynchronizationCompleted;
	
EndFunction

Procedure WriteSynchronizationResult(Account, Val SynchronizationCompleted)
	
	DataLock = New DataLock;
	DataLockItem = DataLock.Add("InformationRegister.FilesSynchronizationWithCloudServiceStatuses");
	DataLockItem.SetValue("File", "");
	DataLockItem = DataLock.Add("InformationRegister.FilesSynchronizationWithCloudServiceStatuses");
	DataLockItem.SetValue("Account", Account);
	
	BeginTransaction();
	Try
		
		DataLock.Lock();
		
		RecordSet = InformationRegisters.FilesSynchronizationWithCloudServiceStatuses.CreateRecordSet();
		RecordSet.Filter.File.Set("", True);
		RecordSet.Filter.Account.Set(Account, True);
		RecordSet.Read();
		
		If RecordSet.Count() > 0 Then
			Record                             = RecordSet.Get(0);
			Record.SynchronizationDateCompletion = CurrentSessionDate();
			Record.IsSynchronized             = SynchronizationCompleted;
			RecordSet.Write();
		EndIf;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function GenerateStructureOfServerFilesTree()
	
	ServerFilesTree = New ValueTree;
	ServerFilesTree.Columns.Add("Href");
	ServerFilesTree.Columns.Add("UID1C");
	ServerFilesTree.Columns.Add("UID1CNotSupported");
	ServerFilesTree.Columns.Add("Etag");
	ServerFilesTree.Columns.Add("FileName");
	ServerFilesTree.Columns.Add("Is_Directory");
	ServerFilesTree.Columns.Add("ModificationDate");
	ServerFilesTree.Columns.Add("Length");
	Return ServerFilesTree;
	
EndFunction

Function ModifyFileInCloudService(Val ModifiedContentAtServer, UpdateFileSynchronizationStatus, Val SynchronizationParameters, Val TableRow)
	
	Block = New DataLock;
	LockItem = Block.Add(TableRow.FileRef.Metadata().FullName());
	LockItem.SetValue("Ref", TableRow.FileRef);
	
	BeginTransaction();
	Try
		
		Block.Lock();
		
		// Importing from the server.
		If TableRow.Is_Directory Then
			// It is possible to track renaming.
			TableRowObject                 = TableRow.FileRef.GetObject();
			TableRowObject.Description    = TableRow.DescriptionServer;
			TableRowObject.Parent        = Undefined;
			TableRowObject.DeletionMark = False;
			TableRowObject.Write();
			
			TableRow.Description    = TableRow.DescriptionServer;
			TableRow.Changes       = TableRow.FileRef;
			TableRow.Parent        = TableRow.ParentServer;
			TableRow.DeletionMark = False;
			
		Else
			
			FileNameStructure = New File(TableRow.DescriptionServer);
			NewFileExtension = CommonClientServer.ExtensionWithoutPoint(FileNameStructure.Extension);
			// Upload file only is its content was modified. Otherwise, update only attributes.
			If ModifiedContentAtServer Or (NewFileExtension <> TableRow.Extension)
				Or (NewFileExtension <> TableRow.Extension)
				Or TableRow.Encrypted <> TableRow.EncryptedOnServer Then
				
				FileParameters = New Structure;
				FileParameters.Insert("FileName",                 TableRow.DescriptionServer);
				FileParameters.Insert("Href",                     TableRow.ToHref);
				FileParameters.Insert("Etag",                     TableRow.ToEtag);
				FileParameters.Insert("FileModificationDate",     Undefined);
				FileParameters.Insert("FileLength",               Undefined);
				FileParameters.Insert("ForUser",          SynchronizationParameters.FilesAuthor);
				FileParameters.Insert("OwnerObject",           TableRow.Parent);
				FileParameters.Insert("ExistingFileRef", TableRow.FileRef);
				FileParameters.Insert("SynchronizationParameters",   SynchronizationParameters);
				FileParameters.Insert("Encrypted",               TableRow.Encrypted);
				
				ImportFileFromServer(FileParameters, TableRow.IsFile);
				
			EndIf;
			
			TableRowObject = TableRow.FileRef.GetObject();
			TableRowObject.Description    = FileNameStructure.BaseName;
			TableRowObject.DeletionMark = False;
			TableRowObject.Write();
			
			TableRow.Description    = TableRow.DescriptionServer;
			TableRow.Changes       = TableRow.FileRef;
			TableRow.Parent        = TableRow.ParentServer;
			TableRow.DeletionMark = False;
			
		EndIf;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	TableRow.Processed = True;
	TableRow.SynchronizationDate = CurrentSessionDate();
	
	EventText = NStr("en = 'File modified: %1';");
	WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(
			EventText, TableRow.Description), 
		SynchronizationParameters.Account);
	
	Return True;
	
EndFunction

Function DeleteFileInCloudService(Val SynchronizationParameters, Val TableRow)
	
	If Not ValueIsFilled(TableRow.FileRef) Then
		Return False;
	EndIf;
	
	If Not IsRefToFile(TableRow.FileRef) Then
		TableRow.Processed = True;
		Return False;
	EndIf;
	
	BeginTransaction();
	Try
		
		UnlockFile(TableRow.FileRef);
		TableRow.FileRef.GetObject().SetDeletionMark(True, False);
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		WriteToEventLogOfFilesSynchronization(
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'File is not deleted: %1';"), TableRow.Description), 
			SynchronizationParameters.Account, EventLogLevel.Error);
		Return False;
		
	EndTry;
	
	TableRow.DeletionMark = True;
	TableRow.Changes       = TableRow.FileRef;
	TableRow.Processed       = True;
	TableRow.SynchronizationDate  = CurrentSessionDate();
	
	WriteToEventLogOfFilesSynchronization(
		StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'File is deleted: %1';"), TableRow.Description), 
		SynchronizationParameters.Account);
	
	Return True;

EndFunction

Function IsRefToFile(OwnerObject)
	
	FilesTypesArray = Metadata.DefinedTypes.AttachedFile.Type.Types();
	Return FilesTypesArray.Find(TypeOf(OwnerObject)) <> Undefined;
	
EndFunction

Function CalculateTimeout(Size)
	
	Timeout = Int(Size / 8192); // Size in MB multiplied by 128
	If Timeout < 10 Then
		Return 10;
	ElsIf Timeout > 43200 Then
		Return 43200;
	EndIf;
	
	Return Timeout;
	
EndFunction

Function CreateFileInCloudService(Val ServerAddress, Val SynchronizationParameters, Val TableRow, Val TableOfFiles)
	
	// sending the new one to server
	TableRow.Description = CommonClientServer.ReplaceProhibitedCharsInFileName(TableRow.Description, "-");
	TableRow.ToHref       = EndWithoutSlash(ServerAddress) + StartWithSlash(EndWithoutSlash(CalculateHref(TableRow,TableOfFiles)));
	
	If Common.ObjectIsFolder(TableRow.FileRef) Then
		CallMKCOLMethod(TableRow.ToHref, SynchronizationParameters);
	ElsIf TableRow.Is_Directory Then
		CallMKCOLMethod(TableRow.ToHref, SynchronizationParameters);
	Else
		
		If TableRow.Encrypted Then
			TableRow.ToHref = TableRow.ToHref + ".p7m";
		EndIf;
		
		TableRow.ToEtag = CallPUTMethod(TableRow.ToHref, TableRow.FileRef, SynchronizationParameters, TableRow.IsFile);
		
		If Common.SubsystemExists("StandardSubsystems.DigitalSignature") And TableRow.SignedWithDS Then
			
			ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
			DigitalSignatures = ModuleDigitalSignature.SetSignatures(TableRow.FileRef);
			SignatureNumber = 0;
			
			For Each Signature In DigitalSignatures Do
				Postfix = PostfixForCaption(SignatureNumber);

				If TableRow.Encrypted Then
					ToHrefSignatures = NameOfEncryptedFile(TableRow.ToHref) + Postfix;
				Else
					ToHrefSignatures = TableRow.ToHref + Postfix;
				EndIf;

				UID1CSignatures = TableRow.UID1C + Postfix;
				CallPUTMethod(ToHrefSignatures, Signature.Signature, SynchronizationParameters, True);
				UpdateFileUID1C(ToHrefSignatures, UID1CSignatures, SynchronizationParameters);
				SignatureNumber = SignatureNumber + 1;
			EndDo;
			
		EndIf;
	EndIf;
	
	UpdateFileUID1C(TableRow.ToHref, TableRow.UID1C, SynchronizationParameters);
	
	TableRow.ParentServer     = TableRow.Parent;
	TableRow.DescriptionServer = TableRow.Description;
	TableRow.IsOnServer      = True;
	TableRow.Processed          = True;
	TableRow.SynchronizationDate  = CurrentSessionDate();
	
	ObjectIsFolder = Common.ObjectIsFolder(TableRow.FileRef);
	If Not TableRow.IsFile
		And Not TableRow.Is_Directory
		And Not ObjectIsFolder Then
		If Common.ObjectAttributeValue(TableRow.FileRef, "BeingEditedBy") <> SynchronizationParameters.FilesAuthor Then
			BorrowFileToEditServer(TableRow.FileRef, SynchronizationParameters.FilesAuthor);
		EndIf;
	ElsIf Not TableRow.Is_Directory And Not ObjectIsFolder Then
		FileData = FilesOperationsInternalServerCall.FileData(TableRow.FileRef);
		
		If TableRow.SignedWithDS Then
			AdditionalProperties = New Structure("WriteSignedObject", True);
		Else
			AdditionalProperties = Undefined;
		EndIf;
		
		FileLockParameters = FilesOperationsInternalClientServer.FileLockParameters();
		FileLockParameters.User = SynchronizationParameters.FilesAuthor;
		FileLockParameters.AdditionalProperties = AdditionalProperties;
				
		FilesOperationsInternalServerCall.LockFile(FileData, , FileLockParameters);
	EndIf;
	
	EventText = NStr("en = 'Object %1 created in cloud service';");
	WriteToEventLogOfFilesSynchronization(
		StringFunctionsClientServer.SubstituteParametersToString(EventText, TableRow.Description), 
		SynchronizationParameters.Account);
	
	Return True;
	
EndFunction

Function PostfixForCaption(SignatureNumber)
	
	Return ?(SignatureNumber = 0, "", "(" + SignatureNumber + ")") + ".p7s"
	
EndFunction

Function SelectDataByRules(Account, Synchronize = True)
	
	SynchronizationSettingQuiery = New Query;
	SynchronizationSettingQuiery.Text = 
	"SELECT
	|	FileSynchronizationSettings.FileOwner AS FileOwner,
	|	FileSynchronizationSettings.FileOwnerType AS FileOwnerType,
	|	MetadataObjectIDs.Ref AS OwnerID,
	|	CASE
	|		WHEN VALUETYPE(MetadataObjectIDs.Ref) <> VALUETYPE(FileSynchronizationSettings.FileOwner)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS IsCatalogItemSetup,
	|	FileSynchronizationSettings.FilterRule AS FilterRule,
	|	FileSynchronizationSettings.IsFile AS IsFile,
	|	FileSynchronizationSettings.Account AS Account,
	|	FileSynchronizationSettings.Synchronize AS Synchronize
	|FROM
	|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
	|		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|		ON (VALUETYPE(FileSynchronizationSettings.FileOwner) = VALUETYPE(MetadataObjectIDs.EmptyRefValue))
	|WHERE
	|	FileSynchronizationSettings.Account = &Account";
	
	SynchronizationSettingQuiery.SetParameter("Account", Account);
	SynchronizationSettings = SynchronizationSettingQuiery.Execute().Unload();
	
	TableOfFiles = Undefined;
	
	For Each Setting In SynchronizationSettings Do
		
		FilesCatalog = Common.MetadataObjectByID(Setting.FileOwnerType, False);
		If TypeOf(FilesCatalog) <> Type("MetadataObject") Then
			Continue;
		EndIf;
		If Not Common.MetadataObjectAvailableByFunctionalOptions(FilesCatalog) Then
			Continue;
		EndIf;
		
		FilesTree = SelectDataBySynchronizationRule(Setting);
		If FilesTree = Undefined Then
			Continue;
		EndIf;
		
		If TableOfFiles = Undefined Then
			
			TableOfFiles = New ValueTable;
			For Each Column In FilesTree.Columns Do
				TableOfFiles.Columns.Add(Column.Name);
			EndDo;
			
			TableOfFiles.Columns.Add("Synchronize", New TypeDescription("Number"));
			
		EndIf;
		
		If Setting.IsCatalogItemSetup Then
			RootDirectory = Setting.OwnerID;
		Else
			RootDirectory = Setting.FileOwner;
		EndIf;
		
		For Each FilesRow In FilesTree.Rows Do
			
			NewRow = TableOfFiles.Add();
			NewRow.Synchronize = ?(Setting.Synchronize, 1, 0);
			FillPropertyValues(NewRow, FilesRow);
			
			If NewRow.FileRef = Undefined Then
				NewRow.FileRef = RootDirectory;
			EndIf;
			
			If ValueIsFilled(FilesRow.FileRef) Then
				
				FileMetadata = FilesRow.FileRef.Metadata();
				If Metadata.Catalogs.Contains(FileMetadata)
					And FileMetadata.Hierarchical Then
				
					FileParent = Common.ObjectAttributeValue(FilesRow.FileRef, "Parent");
					If ValueIsFilled(FileParent) Then
						NewRow.Parent = FileParent;
					EndIf;
					
				EndIf;
				
			EndIf;
			
			If Not ValueIsFilled(NewRow.Parent) Then
				NewRow.Parent = RootDirectory;
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If TableOfFiles = Undefined Then
		Return TableOfFiles;
	EndIf;
	
	ColumnsNames = New Array;
	For Each Column In TableOfFiles.Columns Do
		If Column.Name <> "Synchronize" Then
			ColumnsNames.Add(Column.Name);
		EndIf;
	EndDo;
	
	GroupColumns = StrConcat(ColumnsNames, ",");
	TableOfFiles.GroupBy(GroupColumns, "Synchronize");
	TableOfFiles.Sort("Synchronize" + ?(Not Synchronize, " Desc", ""));
	
	LinesToDelete = New Array;
	UnsynchronizedOwners = New Array;
	For Each TableRow In TableOfFiles Do
		
		If (Synchronize And TableRow.Synchronize > 0)
			Or (Not Synchronize And TableRow.Synchronize = 0) Then
			Break;
		EndIf;
		
		LinesToDelete.Add(TableRow);
		If Not Synchronize
			And UnsynchronizedOwners.Find(TableRow.Parent) = Undefined Then
			UnsynchronizedOwners.Add(TableRow.Parent);
		EndIf;
		
	EndDo;
	
	For Each TableRow In LinesToDelete Do
		TableOfFiles.Delete(TableRow);
	EndDo;
	
	OwnersTable = TableOfFiles.Copy(, "Parent");
	OwnersTable.GroupBy("Parent");
	
	If Synchronize Then
		ObjectsToSynchronize = OwnersTable.UnloadColumn("Parent");
	Else
		
		ObjectsToSynchronize = New Array;
		For Each OwnerRow In OwnersTable Do
			
			If UnsynchronizedOwners.Find(OwnerRow.Parent) = Undefined Then
				ObjectsToSynchronize.Add(OwnerRow.Parent);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	CASE
	|		WHEN VALUETYPE(FileSynchronizationSettings.FileOwner) = TYPE(Catalog.MetadataObjectIDs)
	|			THEN FileSynchronizationSettings.FileOwner
	|		ELSE MetadataObjectIDs.Ref
	|	END AS FileRef,
	|	FileSynchronizationSettings.IsFile AS IsFile,
	|	FileSynchronizationSettings.Account AS Account,
	|	FileSynchronizationSettings.FileOwner AS FileOwner,
	|	FileSynchronizationSettings.FileOwnerType AS FileOwnerType
	|INTO TTVirtualRootFolders
	|FROM
	|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
	|		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|		ON (VALUETYPE(FileSynchronizationSettings.FileOwner) = VALUETYPE(MetadataObjectIDs.EmptyRefValue))
	|WHERE
	|	FileSynchronizationSettings.Synchronize = &Synchronize
	|	AND FileSynchronizationSettings.Account = &Account
	|
	|INDEX BY
	|	Account
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TTVirtualRootFolders.FileRef AS FileRef,
	|	ISNULL(MetadataObjectIDs.Synonym, """") AS Synonym,
	|	TTVirtualRootFolders.IsFile AS IsFile,
	|	FALSE AS DeletionMark,
	|	TRUE AS Is_Directory,
	|	TRUE AS InInfobase1,
	|	FALSE AS IsOnServer,
	|	FALSE AS Processed,
	|	FALSE AS ModifiedAtServer,
	|	FilesSynchronizationWithCloudServiceStatuses.Href AS Href,
	|	FilesSynchronizationWithCloudServiceStatuses.Etag AS Etag,
	|	FilesSynchronizationWithCloudServiceStatuses.UUID1C AS UUID1C,
	|	TTVirtualRootFolders.FileOwner AS FileOwner,
	|	TTVirtualRootFolders.FileOwnerType AS FileOwnerType
	|FROM
	|	TTVirtualRootFolders AS TTVirtualRootFolders
	|		LEFT JOIN InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
	|		ON TTVirtualRootFolders.Account = FilesSynchronizationWithCloudServiceStatuses.Account
	|			AND TTVirtualRootFolders.FileRef = FilesSynchronizationWithCloudServiceStatuses.File
	|		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|			ON TTVirtualRootFolders.FileRef = MetadataObjectIDs.Ref 
	|WHERE
	|	TTVirtualRootFolders.FileRef IN (&FilesOwners)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TTVirtualRootFolders";
		
	Query.SetParameter("Account", Account);
	Query.SetParameter("Synchronize", Synchronize);
	Query.SetParameter("FilesOwners", ObjectsToSynchronize);
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	VirtualFoldersArray = New Array;
	
	While SelectionDetailRecords.Next() Do
		If VirtualFoldersArray.Find(SelectionDetailRecords.FileRef) <> Undefined Then
			Continue;
		EndIf;
		VirtualFoldersArray.Add(SelectionDetailRecords.FileRef);
		VirtualRootFolderString = TableOfFiles.Add();
		FillPropertyValues(VirtualRootFolderString, SelectionDetailRecords);
		VirtualRootFolderString.Description = StrReplace(SelectionDetailRecords.Synonym, ":", "");
	EndDo;
	
	Return TableOfFiles;
	
EndFunction

Function SelectDataBySynchronizationRule(SyncSetup)
	
	SettingsComposer = New DataCompositionSettingsComposer;
	
	ComposerSettings = SyncSetup.FilterRule.Get();
	If ComposerSettings <> Undefined Then
		SettingsComposer.LoadSettings(SyncSetup.FilterRule.Get());
	EndIf;
	
	DataCompositionSchema = New DataCompositionSchema;
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "Local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Name = "DataSet1";
	DataSet.DataSource = DataSource.Name;
	
	DataCompositionSchema.TotalFields.Clear();
	
	If SyncSetup.IsCatalogItemSetup Then
		FileOwner = SyncSetup.OwnerID;
		ExceptionItem = SyncSetup.FileOwner;
	Else
		FileOwner = SyncSetup.FileOwner;
		ExceptionItem = Undefined;
	EndIf;
	
	ExceptionsArray = New Array;
	QueryText = QueryTextToSynchronizeFIles(FileOwner, SyncSetup, ExceptionsArray, 
		ExceptionItem);
	If IsBlankString(QueryText) Then
		Return Undefined;
	EndIf;
			
	DataCompositionSchema.DataSets[0].Query = QueryText;
		
	Structure = SettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("FileRef");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Description");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Extension");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("DeletionMark");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Parent");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Is_Directory");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("InInfobase1");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("IsOnServer");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Changes");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Href");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Etag");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Processed");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("SynchronizationDate");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("UID1C");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("ToHref");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("ToEtag");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("ParentServer");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("DescriptionServer");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("ModifiedAtServer");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("EncryptedOnServer");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Level");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("ParentOrdering");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("IsFile");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("SignedWithDS");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Encrypted");
	
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	
	Parameter = SettingsComposer.Settings.DataParameters.Items.Find("Account");
	Parameter.Value = SyncSetup.Account;
	Parameter.Use = True;
	
	Parameter = SettingsComposer.Settings.DataParameters.Items.Find("OwnerType");
	Parameter.Value = TypeOf(FileOwner.EmptyRefValue);
	Parameter.Use = True;
	
	If ExceptionsArray.Count() > 0 Then
		Parameter = SettingsComposer.Settings.DataParameters.Items.Find("ExceptionsArray");
		Parameter.Value = ExceptionsArray;
		Parameter.Use = True;
	EndIf;
	
	If SyncSetup.IsCatalogItemSetup Then
		Parameter = SettingsComposer.Settings.DataParameters.Items.Find("ExceptionItem");
		Parameter.Value = ExceptionItem;
		Parameter.Use = True;
	EndIf;
	
	TemplateComposer         = New DataCompositionTemplateComposer;
	DataCompositionProcessor = New DataCompositionProcessor;
	OutputProcessor           = New DataCompositionResultValueCollectionOutputProcessor;
	ValueTree            = New ValueTree;
	
	DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, SettingsComposer.Settings,
		, , Type("DataCompositionValueCollectionTemplateGenerator"));
	DataCompositionProcessor.Initialize(DataCompositionTemplate);
	OutputProcessor.SetObject(ValueTree);
	OutputProcessor.Output(DataCompositionProcessor);
	
	Return ValueTree;
	
EndFunction

// Parameters:
//   Account - CatalogRef.FileSynchronizationAccounts
//
Procedure ExecuteConnectionCheck(Account, CheckResult) Export 

	CheckResult = New Structure("ResultText, ResultProtocol, Cancel, ErrorCode","","",False);
	
	SynchronizationParameters = FilesSyncProperties(Account);
	
	ServerAddress = EncodeURIByStructure(SynchronizationParameters.ServerAddressStructure);
	
	UserAccountDescription = String(Account);
	
	EventText = NStr("en = 'File synchronization check started';") + " " + UserAccountDescription;
	WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account);
	
	ReadDirectoryParameters(CheckResult, ServerAddress, SynchronizationParameters);
	CheckIfCanStoreFiles(CheckResult, ServerAddress, SynchronizationParameters);
	
	EventText = NStr("en = 'File synchronization check completed';") + " " + UserAccountDescription;
	WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account);

EndProcedure

Procedure UnlockLockedFilesBackground(CallParameters, AddressInStorage) Export
	DeleteUnsynchronizedFiles();
EndProcedure

Procedure DeleteUnsynchronizedFiles()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	FileSynchronizationAccounts.Ref AS Account
	|FROM
	|	Catalog.FileSynchronizationAccounts AS FileSynchronizationAccounts
	|		LEFT JOIN InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
	|		ON (FileSynchronizationSettings.Account = FileSynchronizationAccounts.Ref)
	|		LEFT JOIN InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
	|		ON (FilesSynchronizationWithCloudServiceStatuses.Account = FileSynchronizationAccounts.Ref)
	|WHERE
	|	(FileSynchronizationAccounts.DeletionMark
	|			OR FileSynchronizationSettings.Synchronize <> TRUE)
	|	AND FilesSynchronizationWithCloudServiceStatuses.Account IS NOT NULL 
	|
	|GROUP BY
	|	FileSynchronizationAccounts.Ref";
	SelectionAccount = Query.Execute().Select();
	While SelectionAccount.Next() Do
		// @skip-check query-in-loop - Batch processing of a large amount of data.
		DeleteAccountUnsynchronizedFiles(SelectionAccount.Account);
	EndDo;
	
EndProcedure

// Releasing files captured by user accounts marked for deletion or with synchronization settings disabled.
//
Procedure DeleteAccountUnsynchronizedFiles(Account)
	
	SynchronizationParameters = FilesSyncProperties(Account);
	If SynchronizationParameters = Undefined Then
		Return;
	EndIf;
	
	ServerAddress = EncodeURIByStructure(SynchronizationParameters.ServerAddressStructure);
	
	EventText = NStr("en = 'Releasing files locked by the cloud service started.';");
	WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account);
	
	ServerFilesTree = GenerateStructureOfServerFilesTree();
		
	Try
		
		Cancel = False;
		ImportFilesTreeRecursively(ServerFilesTree.Rows, ServerAddress, SynchronizationParameters, Cancel);
		If Cancel = True Then
			ErrorText = NStr("en = 'Cannot synchronize the files as an error occurred when importing the file structure from the cloud service.';");
			Raise ErrorText;
		EndIf;
		
		// Comparing it with the file tree in the system, synchronization by UUID.
		TableOfFiles = SelectDataByRules(Account, False);
		If TableOfFiles <> Undefined Then
		
			CalculateLevelRecursively(TableOfFiles);
			TableOfFiles.Sort("Is_Directory ASC, Level DESC, ParentOrdering DESC");
			// Looping through the table and deciding what to do with files and folders.
			For Each TableRow In TableOfFiles Do
				
				If TableRow.Processed Then
					Continue;
				EndIf;
				
				BeginTransaction();
				Try
					
					DataLock = New DataLock();
					If Not TableRow.Is_Directory Then
						LockItem = DataLock.Add(Metadata.FindByType(TypeOf(TableRow.FileRef)).FullName());
						LockItem.SetValue("Ref", TableRow.FileRef);
					EndIf;
					LockFileSyncStatus(DataLock, TableRow.FileRef, Account);
					DataLock.Lock();
					
					If ValueIsFilled(TableRow.Href) Then
						CallDELETEMethod(TableRow.Href, SynchronizationParameters);
						EventText = NStr("en = 'Object deleted in cloud service %1';");
						WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(
								EventText, TableRow.DescriptionServer), 
							SynchronizationParameters.Account);
							
						If Not TableRow.Is_Directory And TableRow.SignedWithDS Then
							DeleteUnsynchronizedSignatures(TableRow, ServerFilesTree.Rows, SynchronizationParameters);
						EndIf;
					EndIf;

					TableRow.ParentServer = Undefined;
					TableRow.DescriptionServer = "";
					TableRow.IsOnServer = False;
					TableRow.Processed = True;
					
					If Not TableRow.Is_Directory Then
						UnlockFile(TableRow.FileRef);
					EndIf;
					
					// Deleting the last Href not to identify it again.
					DeleteFileSyncStatus(TableRow.FileRef, Account);
					CommitTransaction();
					
				Except
					RollbackTransaction();
					EventText = NStr("en = 'The object is not deleted in the %1 cloud service due to:
						|%2';");
					WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(
						EventText, TableRow.DescriptionServer, ErrorProcessing.DetailErrorDescription(ErrorInfo())),
						SynchronizationParameters.Account, EventLogLevel.Error);
				EndTry;
				
			EndDo;
		EndIf;
		
	Except
		WriteToEventLogOfFilesSynchronization(ErrorProcessing.DetailErrorDescription(ErrorInfo()), 
			SynchronizationParameters.Account, EventLogLevel.Error);
	EndTry;
	
	EventText = NStr("en = 'Files locked by the cloud service are released.';");
	WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account);
	
EndProcedure

Procedure DeleteUnsynchronizedSignatures(TableRow, StringServerFileTree, SynchronizationParameters)
		
	Filter = New Structure("Etag, FileName", TableRow.Etag);
	Filter.FileName = ?(TableRow.Encrypted, TableRow.Description + ".p7m", TableRow.Description);
	
	FileString = StringServerFileTree.FindRows(Filter, True);

	If FileString.Count() = 0 Then
		Return;
	EndIf;
	
	UID1C = FileString[0].UID1C;
	
	If Not ValueIsFilled(UID1C) Then
		Return;
	EndIf;
	
	FileFolder = FileString[0].Parent;
	
	For Each TreeRow In FileFolder.Rows Do
		If StrStartsWith(TreeRow.UID1C, UID1C)
			And StrEndsWith(TreeRow.UID1C, "p7s") Then
			
			CallDELETEMethod(TreeRow.Href, SynchronizationParameters);
			EventText = NStr("en = 'The %1 signature of the %2 object is deleted from the cloud service';");
			WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(
				EventText, TreeRow.FileName, TableRow.Description),
				SynchronizationParameters.Account);
		EndIf;
	EndDo;

EndProcedure

Function EventLogFilterData(Account) Export
	
	Filter = New Structure;
	Filter.Insert("EventLogEvent ", EventLogEventSynchronization());
	
	Query = New Query;
	Query.Text = "SELECT
	|	FilesSynchronizationWithCloudServiceStatuses.SessionNumber AS SessionNumber,
	|	FilesSynchronizationWithCloudServiceStatuses.SynchronizationDateStart AS SynchronizationDateStart,
	|	FilesSynchronizationWithCloudServiceStatuses.SynchronizationDateCompletion AS SynchronizationDateCompletion
	|FROM
	|	InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
	|WHERE
	|	FilesSynchronizationWithCloudServiceStatuses.File = """"
	|	AND FilesSynchronizationWithCloudServiceStatuses.Account = &Account";
	
	Query.SetParameter("Account", Account);
	
	QueryResult = Query.Execute().Select();
	
	If QueryResult.Next() Then
		
		SessionsList = New ValueList;
		SessionsList.Add(QueryResult.SessionNumber);
		
		Filter.Insert("Data                    ", Account);
		Filter.Insert("StartDate",                 QueryResult.SynchronizationDateStart);
		Filter.Insert("EndDate",              QueryResult.SynchronizationDateCompletion);
		Filter.Insert("Session",                      SessionsList);
	
	EndIf;
	
	Return Filter;
	
EndFunction

Function SynchronizationInfo(Val FileOwner = Undefined) Export
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
		|	FilesSynchronizationWithCloudServiceStatuses.Account AS Account,
		|	FilesSynchronizationWithCloudServiceStatuses.SynchronizationDateStart AS SynchronizationDate,
		|	FilesSynchronizationWithCloudServiceStatuses.SessionNumber AS SessionNumber,
		|	FilesSynchronizationWithCloudServiceStatuses.IsSynchronized AS IsSynchronized,
		|	FilesSynchronizationWithCloudServiceStatuses.SynchronizationDateCompletion AS SynchronizationDateCompletion,
		|	FilesSynchronizationWithCloudServiceStatuses.Href AS Href,
		|	FilesSynchronizationWithCloudServiceStatuses.Account.Description AS AccountDescription1,
		|	FilesSynchronizationWithCloudServiceStatuses.Account.Service AS Service
		|FROM
		|	InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
		|		LEFT JOIN InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS CloudServiceFileSynchronizationStatusesRoot
		|		ON FilesSynchronizationWithCloudServiceStatuses.Account = CloudServiceFileSynchronizationStatusesRoot.Account
		|			AND (CloudServiceFileSynchronizationStatusesRoot.File = """""""")
		|WHERE
		|	FilesSynchronizationWithCloudServiceStatuses.File = &File";
	
	Query.SetParameter("File", FileOwner);
	Table = Query.Execute().Unload();
	
	While Table.Count() > 0  Do
		Result = Common.ValueTableRowToStructure(Table[0]);
		Return Result;
	EndDo;
	
	Return New Structure();
	
EndFunction

// Returns the flag showing whether the node belongs to DIB exchange plan.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - an exchange plan node that requires receiving the function value.
//
// Returns:
//    Boolean - If True, the node belongs to the exchange plan of the distributed infobase. Otherwise, False.
//
Function IsDistributedInfobaseNode(Val InfobaseNode)
	
	Return FilesOperationsInternalCached.IsDistributedInfobaseNode(
		InfobaseNode.Metadata().FullName());
	
EndFunction

Function IsErrorStateCode(StatusCode)
	Return (StatusCode >= 400 And StatusCode <= 599) Or StatusCode = 0; 
EndFunction

#EndRegion

#Region TextExtraction

Function QueryTextForFilesWithUnextractedText(CatalogName, FilesNumberInSelection,
	GetAllFiles, AdditionalFields)
	
	If AdditionalFields Then
		QueryText =
		"SELECT TOP 1
		|	Files.Ref AS Ref,
		|	ISNULL(InformationRegisterFilesEncoding.Encoding, """") AS Encoding,
		|	Files.Extension AS Extension,
		|	Files.Description AS Description
		|FROM
		|	&CatalogName AS Files
		|		LEFT JOIN InformationRegister.FilesEncoding AS InformationRegisterFilesEncoding
		|		ON (InformationRegisterFilesEncoding.File = Files.Ref)
		|WHERE
		|	Files.TextExtractionStatus IN (
		|		VALUE(Enum.FileTextExtractionStatuses.NotExtracted),
		|		VALUE(Enum.FileTextExtractionStatuses.EmptyRef))";
	Else
		QueryText =
		"SELECT TOP 1
		|	Files.Ref AS Ref,
		|	ISNULL(InformationRegisterFilesEncoding.Encoding, """") AS Encoding
		|FROM
		|	&CatalogName AS Files
		|		LEFT JOIN InformationRegister.FilesEncoding AS InformationRegisterFilesEncoding
		|		ON (InformationRegisterFilesEncoding.File = Files.Ref)
		|WHERE
		|	Files.TextExtractionStatus IN (
		|		VALUE(Enum.FileTextExtractionStatuses.NotExtracted),
		|		VALUE(Enum.FileTextExtractionStatuses.EmptyRef))";
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		If CatalogName = "FilesVersions" Then
			QueryText = QueryText + "
				|	AND NOT Files.Owner.Encrypted"; // @query-part
		Else
			QueryText = QueryText + "
				|	AND NOT Files.Encrypted"; // @query-part
		EndIf;
	EndIf;
	
	ReplacementString = ?(GetAllFiles, "SELECT", // @query-part
		"SELECT TOP " + Format(FilesNumberInSelection, "NG=; NZ=")); // @query-part
	QueryText = StrReplace(QueryText, "SELECT TOP 1", ReplacementString); // @query-part
	QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + CatalogName);
	Return QueryText;
	
EndFunction

// Gets a full path to the file.
//
// Parameters:
//   ObjectRef - DefinedType.AttachedFileObject - a catalog item with files
//                that requires getting a file path.
//
// Returns:
//   String
//
Function FileWithBinaryDataName(ObjectRef) 
	
	FullFileName = "";
	
	If ObjectRef.FileStorageType = Enums.FileStorageTypes.InInfobase Then
		
		FileStorage1 = FilesOperations.FileFromInfobaseStorage(ObjectRef);
		If FileStorage1 = Undefined Then
			Return "";
		EndIf;
		
		FileBinaryData = FileStorage1.Get(); //BinaryData
		If TypeOf(FileBinaryData) <> Type("BinaryData") Then
			Return "";
		EndIf;
		
		FullFileName = GetTempFileName(ObjectRef.Extension);
		FileBinaryData.Write(FullFileName);
		
	Else
		
		FileProperties = FilesOperationsInVolumesInternal.FilePropertiesInVolume();
		FillPropertyValues(FileProperties, ObjectRef);
		
		FullFileName = FilesOperationsInVolumesInternal.FullFileNameInVolume(FileProperties);
		
	EndIf;
	
	Return FullFileName;
	
EndFunction

// Writes the extracted text.
//
// Parameters:
//  CurrentVersion  - CatalogRef.FilesVersions - a file version.
//
Procedure OnWriteExtractedText(CurrentVersion, FileLocked = True)
	
	// Write it if it is not a version.
	If Common.HasObjectAttribute("FileOwner", Metadata.FindByType(TypeOf(CurrentVersion))) Then
		InfobaseUpdate.WriteData(CurrentVersion);
		Return;
	EndIf;
	
	File = CurrentVersion.Owner;
	CurrentFileVersion = Common.ObjectAttributeValue(File, "CurrentVersion");
	If CurrentFileVersion = CurrentVersion.Ref Then
		Try
			LockDataForEdit(File);
		Except
			FileLocked = False;
			Raise;
		EndTry;
	EndIf;
	
	InfobaseUpdate.WriteData(CurrentVersion);
	
	If CurrentFileVersion = CurrentVersion.Ref Then
		FileObject1 = File.GetObject();
		FileObject1.TextStorage = CurrentVersion.TextStorage;
		InfobaseUpdate.WriteData(FileObject1);
	EndIf;
	
EndProcedure

// Extracts a text from a temporary storage or from binary data and returns extraction status.
//
// Parameters:
//   TempTextStorageAddress - String
//   BinaryData                 - BinaryData
//                                  - Undefined
//   Extension                     - String
//                                  - Undefined
//
Function ExtractText1(Val TempTextStorageAddress, Val BinaryData = Undefined, Val Extension = Undefined) Export
	
	SetSafeModeDisabled(True);
	
	Result = New Structure("TextExtractionStatus, TextStorage");
	
	If IsTempStorageURL(TempTextStorageAddress) Then
		ExtractedText = RowFromTempStorage(TempTextStorageAddress);
		Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		Result.TextStorage = New ValueStorage(ExtractedText, New Deflation(9));
		Return Result;
	EndIf;
		
	If ExtractTextFilesOnServer() Then
		Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		Result.TextStorage = New ValueStorage("");
		Return Result; // The text will be extracted earlier in the scheduled job.
	EndIf;
	
	If Not Common.IsWindowsServer() Or BinaryData = Undefined Then
		Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		Result.TextStorage = New ValueStorage("");
		Return Result;
	EndIf;
	
	// The text is extracted right away, not in the scheduled job.
	TempFileName = GetTempFileName(Extension);
	BinaryData.Write(TempFileName);
	Result = ExtractTextFromFileOnHardDrive(TempFileName);
	Try
		DeleteFiles(TempFileName);
	Except
		WriteLogEvent(NStr("en = 'Files.Extract text';",	Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return Result;
	
EndFunction

Function ExtractTextFromFileOnHardDrive(Val FileName, Val Encoding = Undefined) Export
	
	ExtractedText = "";
	Result = New Structure("TextExtractionStatus, TextStorage");
	Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.FailedExtraction;
	
	Try
		File = New File(FileName);
		If Not File.Exists() Then
			Return Result;
		EndIf;
	Except
		Return Result;
	EndTry;
	
	Cancel = False;
	CommonSettings = FilesOperationsInternalCached.FilesOperationSettings().CommonSettings;
	
	FileNameExtension =
		CommonClientServer.GetFileNameExtension(FileName);
	
	FileExtensionInList = FilesOperationsInternalClientServer.FileExtensionInList(
		CommonSettings.TextFilesExtensionsList, FileNameExtension);
	
	If FileExtensionInList Then
		
		ExtractedText = FilesOperationsInternalClientServer.ExtractTextFromTextFile(
			FileName, Encoding, Cancel);
			
	Else
	
		Try
			Extracting = New TextExtraction(FileName);
			ExtractedText = Extracting.GetText();
		Except
			// Don't throw an exception if there is no handler to extract the text. This is a common scenario.
			ExtractedText = "";
			Cancel = True;
		EndTry;
		
		If IsBlankString(ExtractedText) Then
			
			FileNameExtension =
				CommonClientServer.GetFileNameExtension(FileName);
			
			FileExtensionInList = FilesOperationsInternalClientServer.FileExtensionInList(
				CommonSettings.FilesExtensionsListOpenDocument, FileNameExtension);
			
			If FileExtensionInList Then
				ExtractedText = FilesOperationsInternalClientServer.ExtractOpenDocumentText(FileName, Cancel);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Not Cancel Then
		Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		Result.TextStorage = New ValueStorage(ExtractedText, New Deflation(9));
	EndIf;
	
	Return Result;
	
EndFunction

// Receives a row from a temporary storage (transfer from client to server,
// done via temporary storage).
//
Function RowFromTempStorage(TempTextStorageAddress)
	
	If IsBlankString(TempTextStorageAddress) Then
		Return "";
	EndIf;
	
	TempFileName = GetTempFileName();
	FileBinaryData = GetFromTempStorage(TempTextStorageAddress); //BinaryData
	FileBinaryData.Write(TempFileName);
	
	TextFile = New TextReader(TempFileName, TextEncoding.UTF8);
	Text = TextFile.Read();
	TextFile.Close();
	
	Try
		DeleteFiles(TempFileName);
	Except
		WriteLogEvent(NStr("en = 'Files.Extract text';",	Common.DefaultLanguageCode()),
			EventLogLevel.Error,,,	ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return Text;
	
EndFunction

// Parameters:
//   FileWithoutText - DefinedType.AttachedFileObject
//
Function ExtractTextFromFile(FileWithoutText, FileLocked)
	
	FileWithBinaryDataName = "";
	FileMetadata = FileWithoutText.Ref.Metadata();
	
	DataLock = New DataLock;
	DataLockItem = DataLock.Add(FileMetadata.FullName());
	DataLockItem.SetValue("Ref", FileWithoutText.Ref);
	
	If Not Common.HasObjectAttribute("FileOwner", FileMetadata) Then
		Owner = Common.ObjectAttributeValue(FileWithoutText.Ref, "Owner");
		DataLockItem = DataLock.Add(Owner.Metadata().FullName());
		DataLockItem.SetValue("Ref", Owner);
	EndIf;
	
	BeginTransaction();
	Try
		
		DataLock.Lock();
		LockDataForEdit(FileWithoutText.Ref, FileWithBinaryDataName);
		FileLocked = True;
		
		FileObject1 = FileWithoutText.Ref.GetObject();
		FileObject1.AdditionalProperties.Insert("TextExtraction", True);
		If FileObject1 <> Undefined Then
			
			If IsFilesOperationsItem(FileObject1.Ref) Then
				ObjectMetadata = Metadata.FindByType(TypeOf(FileObject1.Ref));
				AbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", ObjectMetadata);
				If AbilityToStoreVersions And Not FileObject1.CurrentVersion.IsEmpty() Then
					FileWithBinaryDataName = FileWithBinaryDataName(FileObject1.CurrentVersion);
				Else
					FileWithBinaryDataName = FileWithBinaryDataName(FileObject1.Ref);
				EndIf;
			EndIf;
			
			If IsBlankString(FileWithBinaryDataName) Then
				UnlockDataForEdit(FileWithoutText.Ref);
				FileLocked = False;
			Else
				TextExtractionResult = ExtractTextFromFileOnHardDrive(FileWithBinaryDataName, FileWithoutText.Encoding);
				FileObject1.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
				FileObject1.TextStorage = TextExtractionResult.TextStorage;
				
				OnWriteExtractedText(FileObject1, FileLocked);
				
				If FileObject1.FileStorageType <> Enums.FileStorageTypes.InInfobase Then
					FileWithBinaryDataName = "";
				EndIf;
				
			EndIf;
			
		EndIf;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return FileWithBinaryDataName;
	
EndFunction

#EndRegion

#Region EventsSubscriptionsHandlers

// The "on write" file version subscription.
//
// Parameters:
//   Source - CatalogObject.FilesVersions
//
Procedure FilesVersionsOnWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		WriteFileDataToRegisterDuringExchange(Source);
		Return;
	EndIf;
	
	If Source.AdditionalProperties.Property("FileRenaming")
		Or Source.AdditionalProperties.Property("FileConversion") Then
		
		Return;
	EndIf;
	
	// Copying attributes from version to file.
	CurrentVersion = Source;
	If Not CurrentVersion.Ref.IsEmpty() Then
	
		FileRef = Source.Owner;
		FileAttributes = Common.ObjectAttributesValues(FileRef, 
			"CurrentVersion, PictureIndex, Size, UniversalModificationDate, ChangedBy, Extension, Volume, PathToFile, UniversalModificationDate");
		
		If FileAttributes.Size <> CurrentVersion.Size 
			Or FileAttributes.Extension <> CurrentVersion.Extension
			Or FileAttributes.Volume <> CurrentVersion.Volume
			Or FileAttributes.PathToFile <> CurrentVersion.PathToFile 
			Or FileAttributes.PictureIndex <> CurrentVersion.PictureIndex
			Or FileAttributes.UniversalModificationDate <> CurrentVersion.UniversalModificationDate Then
			BeginTransaction();
			Try
				DataLock = New DataLock;
				DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(FileRef)).FullName());
				DataLockItem.SetValue("Ref", FileRef);
				DataLock.Lock();
				
				FileObject1 = FileRef.GetObject();
				FileObject1.PictureIndex = CurrentVersion.PictureIndex;
				FileObject1.Size = CurrentVersion.Size;
				FileObject1.ChangedBy = CurrentVersion.Author;
				FileObject1.Extension = CurrentVersion.Extension;
				FileObject1.Volume = CurrentVersion.Volume;
				FileObject1.PathToFile = CurrentVersion.PathToFile;
				FileObject1.FileStorageType = CurrentVersion.FileStorageType;
				FileObject1.UniversalModificationDate = CurrentVersion.UniversalModificationDate;
				If Not ValueIsFilled(FileObject1.CreationDate) Then
					FileObject1.CreationDate = CurrentVersion.CreationDate;
				EndIf;
				
				If Source.AdditionalProperties.Property("WriteSignedObject") Then
					FileObject1.AdditionalProperties.Insert("WriteSignedObject",
						Source.AdditionalProperties.WriteSignedObject);
				EndIf;
				
				// No need to check access rights.
				SetPrivilegedMode(True);
				FileObject1.Write();
				SetPrivilegedMode(False);
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
		EndIf;
		
	EndIf;
	
	UpdateTextExtractionQueueState(Source.Ref, Source.TextExtractionStatus);
	
EndProcedure

// Subscription handler of the "before delete attachment" event.
Procedure BeforeDeleteAttachedFileServer(Val Ref,
                                                   Val FilesOwner,
                                                   Val Volume,
                                                   Val FileStorageType,
                                                   Val PathToFile) Export
	
	SetPrivilegedMode(True);
	
	If FilesOwner <> Undefined And Not OwnerHasFiles(FilesOwner, Ref) Then
		
		BeginTransaction();
		Try
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(Metadata.InformationRegisters.FilesExist.FullName());
			DataLockItem.SetValue("ObjectWithFiles", FilesOwner);
			DataLock.Lock();
			
			RecordManager = InformationRegisters.FilesExist.CreateRecordManager();
			RecordManager.ObjectWithFiles = FilesOwner;
			RecordManager.Read();
			If RecordManager.Selected() Then
				RecordManager.HasFiles = False;
				RecordManager.Write();
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndIf;
	
	If FileStorageType = Enums.FileStorageTypes.InInfobase Then
		InformationRegisters.FileRepository.DeleteBinaryData(Ref);
	EndIf;
	
EndProcedure

// Checks the the current user right
// when using the limit for a folder or file.
// 
// Parameters:
//  Right        - String - a right name.
//  RightsOwner - CatalogRef.FilesFolders
//               - CatalogRef.Files
//               - DefinedType.AttachedFilesOwner
//
Function HasRight(Right, RightsOwner) Export
	
	If Not IsFilesFolder(RightsOwner) Then
		Return True; 
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		
		If Not ModuleAccessManagement.HasRight(Right, RightsOwner) Then
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// Handler of the "Processing attachment filling check" attachment subscription.
//
Procedure ProcessAttachedFileFillingCheck(Source, Cancel) Export
	
	If Source.AdditionalProperties.Property("DeferredWriting")
		And FilesOperations.FileBinaryData(Source.Ref, False) = Undefined Then
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

Function OwnerHasFiles(Val FilesOwner, Val ExceptionFile = Undefined) Export
	
	QueryText =
	"SELECT TOP 1
	|	AttachedFiles.Ref
	|FROM
	|	&CatalogName AS AttachedFiles
	|WHERE
	|	NOT AttachedFiles.DeletionMark
	|	AND AttachedFiles.FileOwner = &FilesOwner
	|	AND &ExceptionConditions";
	
	Query = New Query;
	Query.Parameters.Insert("FilesOwner", FilesOwner);
	ExceptionConditions = "";
	If ExceptionFile <> Undefined Then
		ExceptionConditions = "AttachedFiles.Ref <> &ExceptionFile";
		Query.Parameters.Insert("ExceptionFile", ExceptionFile);
	EndIf;
	
	QueryTexts = New Array;	
	For Each KeyAndValue In FileStorageCatalogNames(FilesOwner) Do
		CurrentQueryText = QueryText;
		CurrExceptionConditions = ExceptionConditions;
		If ThereArePropsInternal(KeyAndValue.Key) Then
			CurrExceptionConditions = CurrExceptionConditions + ?(ValueIsFilled(CurrExceptionConditions)," And ","") + "AttachedFiles.IsInternal = FALSE";
		EndIf;
		If Not ValueIsFilled(CurrExceptionConditions) Then
			CurrExceptionConditions = "TRUE";
		EndIf;
		CurrentQueryText = StrReplace(CurrentQueryText, "&ExceptionConditions", CurrExceptionConditions); // @Query-part-2
		QueryTexts.Add(StrReplace(CurrentQueryText, "&CatalogName", "Catalog." + KeyAndValue.Key));
	EndDo;
	
	Query.Text = StrConcat(QueryTexts, Chars.LF + "UNION" + Chars.LF);
	SetPrivilegedMode(True);
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#EndRegion

#Region InfobaseUpdate

Procedure UpdateDeniedExtensionsList() Export
	
	DeniedExtensionsToImportList = DeniedExtensionsList();
	
	DeniedExtensionsListInDatabase = Constants.DeniedExtensionsList.Get();
	DeniedExtensionsArray = StrSplit(DeniedExtensionsListInDatabase, " ");
	UpdateDeniedExtensionsList = False;
	For Each Extension In DeniedExtensionsToImportList Do
		If DeniedExtensionsArray.Find(Upper(Extension)) = Undefined Then
			UpdateDeniedExtensionsList = True;
			DeniedExtensionsArray.Add(Upper(Extension));
		EndIf;
	EndDo;
	DeniedExtensionsListInDatabase = StrConcat(DeniedExtensionsArray, " ");
	If UpdateDeniedExtensionsList Then
		Constants.DeniedExtensionsList.Set(DeniedExtensionsListInDatabase);
	EndIf;
	
EndProcedure

Procedure UpdateProhibitedExtensionListInDataArea() Export
	
	DeniedExtensionsToImportList = DeniedExtensionsList();
	
	UpdateDeniedDataAreaExtensionsList = False;
	DeniedDataAreaExtensionsList = Constants.DeniedDataAreaExtensionsList.Get();
	DeniedDataAreaExtensionsArray = StrSplit(DeniedDataAreaExtensionsList, " ");
	For Each Extension In DeniedExtensionsToImportList Do
		If DeniedDataAreaExtensionsArray.Find(Upper(Extension)) = Undefined Then
			DeniedDataAreaExtensionsArray.Add(Upper(Extension));
			UpdateDeniedDataAreaExtensionsList = True;
		EndIf;
	EndDo;
	DeniedDataAreaExtensionsList = StrConcat(DeniedDataAreaExtensionsArray, " ");
	If UpdateDeniedDataAreaExtensionsList Then
		Constants.DeniedDataAreaExtensionsList.Set(DeniedDataAreaExtensionsList);
	EndIf;
	
EndProcedure

Procedure UpdateTextFilesExtensionsList() Export
	
	ExtensionsList = Constants.TextFilesExtensionsList.Get();
	TextFilesExtensions = StrSplit(ExtensionsList, " ");
	
	UpdateExtensionsList = False;
	For Each Extension In StrSplit(TextFilesExtensionsList(), " ") Do
		If TextFilesExtensions.Find(Upper(Extension)) = Undefined Then
			UpdateExtensionsList = True;
			TextFilesExtensions.Add(Upper(Extension));
		EndIf;
	EndDo;
	If UpdateExtensionsList Then
		Constants.TextFilesExtensionsList.Set(StrConcat(TextFilesExtensions, " "));
	EndIf;
	
EndProcedure

Function VersionsWithUnextractedTextCount() Export
	
	QueryTexts = New Array;	
	For Each Type In Metadata.DefinedTypes.AttachedFile.Type.Types() Do
		
		QueryText = 
			"SELECT
			|	ISNULL(COUNT(Files.Ref), 0) AS FilesCount
			|FROM
			|	&CatalogName AS Files
			|WHERE
			|	Files.TextExtractionStatus IN (VALUE(Enum.FileTextExtractionStatuses.NotExtracted), 
			|		VALUE(Enum.FileTextExtractionStatuses.EmptyRef))";
	
		If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			If Type = Type("CatalogRef.FilesVersions") Then
				QueryText = QueryText + "
					|	AND NOT Files.Owner.Encrypted";
			Else
				QueryText = QueryText + "
					|	AND NOT Files.Encrypted";
			EndIf;
		EndIf;
	
		FilesDirectoryMetadata = Metadata.FindByType(Type);
		QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + FilesDirectoryMetadata.Name);
		QueryTexts.Add(QueryText);
		
	EndDo;
	
	FilesCount = 0;	
	Query = New Query(StrConcat(QueryTexts, Chars.LF + "UNION" + Chars.LF));
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FilesCount = FilesCount + Selection.FilesCount;
	EndIf;
	
	Return FilesCount;
	
EndFunction

#EndRegion

#EndRegion