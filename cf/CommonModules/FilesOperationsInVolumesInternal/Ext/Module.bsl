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

// Determines whether active file storage volumes are available.
// If at least one file storage volume is available, returns True.
//
// Returns:
//   Boolean - if True, at least one working volume exists.
//
Function HasFileStorageVolumes() Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes
	|WHERE
	|	FileStorageVolumes.DeletionMark = FALSE";
	
	SetSafeModeDisabled(True); 
	SetPrivilegedMode(True);
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Returns the file binary data.
//
// Parameters:
//   AttachedFile - DefinedType.AttachedFile - a reference to the catalog item with file.
//   RaiseException1 - Boolean - if True, returns Undefined
//                     instead of raising an exception. The default value is True.
//
// Returns:
//   BinaryData, Undefined - binary data of the attachment. If the binary data of the file is not found
//                               in the infobase or volumes, an exception is thrown. If the binary data is not found and the ShouldRaiseException parameter is set to False,
//                               the return value is Undefined.
//                               
//
Function FileData(AttachedFile, Val RaiseException1 = True) Export
	
	FileProperties = FilePropertiesInVolume(AttachedFile);
	Try
		Return New BinaryData(FullFileNameInVolume(FileProperties));
	Except
		FileObject1 = FilesOperationsInternal.FileObject1(AttachedFile);
		FilesOperationsInternal.ReportErrorFileNotFound(FileObject1, RaiseException1);
		Return Undefined;
	EndTry;
	
EndFunction

// Constructor of attached file data structure. For details,  See AppendFile.
// 
// Returns:
//   Structure:
//     The following properties must be filled in before adding a file:
//       * Ref                       - DefinedType.AttachedFile - a reference to the catalog item with files.
//       * Description                 - String - a description of the file being added.
//       * Size                       - Number - a file size.
//       * Extension                   - String - an extension of the file being added.
//       * FileOwner                - DefinedType.AttachedFilesOwner - a reference to the file owner.
//       * UniversalModificationDate - Date - the file modification date.
//       * AdditionalProperties - Structure
//    After adding you can analyze the following properties:
//       * FileStorageType - EnumRef.FileStorageTypes - the file data storage type.
//       * Volume              - CatalogRef.FileStorageVolumes - the volume to which the file was added.
//       * PathToFile       - String - a path in the volume, by which the file was placed.
//       * StoredFile     - ValueStorage - data of the added file.
//
Function FileAddingOptions() Export
	
	FileParameters = New Structure;
	FileParameters.Insert("Ref", Undefined);
	FileParameters.Insert("Volume", Catalogs.FileStorageVolumes.EmptyRef());
	FileParameters.Insert("PathToFile", "");
	FileParameters.Insert("Extension", Undefined);
	FileParameters.Insert("Size", 0);
	FileParameters.Insert("Description", "");
	FileParameters.Insert("StoredFile", Undefined);
	FileParameters.Insert("FileOwner", Undefined);
	FileParameters.Insert("FileStorageType", Undefined);
	FileParameters.Insert("UniversalModificationDate", Undefined);
	FileParameters.Insert("AdditionalProperties", New Structure);
	
	Return FileParameters;
	
EndFunction

// Adds a file to one of the volumes (which has free space) or to the infobase if
// the method for storing files in the settings is InInfobaseAndVolumesOnHardDrive and the file
// matches the infobase storage settings.
//
// Parameters:
//   AttachedFile  - See FilesOperationsInVolumesInternal.FileAddingOptions
//                       - DefinedType.AttachedFileObject - An attachment catalog item
//                         or a structure with properties whose data is saved to a volume.
//   BinaryDataOrPath - BinaryData
//                         - String - binary data of the file or the full file path.
//   FileDateInVolume - Date - if not specified, set it so the current session date.
//   FillInternalStorageAttribute - Boolean - if the parameter is True, also store
//                                       the binary file data to the FileStorage internal attribute.
//   VolumeForPlacement - CatalogRef.FileStorageVolumes
//                    - Undefined - If the parameter is filled, files will be placed to a specified volume.
//                                     Otherwise, the volume will be selected automatically.
//
Procedure AppendFile(AttachedFile, BinaryDataOrPath,
	FileDateInVolume = Undefined, FillInternalStorageAttribute = False, VolumeForPlacement = Undefined) Export
	
	FillInTheFileDetails(AttachedFile, BinaryDataOrPath, FileDateInVolume, 
		FillInternalStorageAttribute, VolumeForPlacement);
	
	If AttachedFile.FileStorageType <> Enums.FileStorageTypes.InInfobase Then
		WriteTheFileDataToTheVolume(AttachedFile, BinaryDataOrPath);
	EndIf;
	
EndProcedure

// Fills in the attributes of the attachment by file or binary data.
// 
// If the file is stored in volumes, it generates a new file name in the volume without putting the file data in the volume.
//  
// The attachment is not saved.
// 
// Throws exceptions. 
// 
// Parameters:
//   AttachedFile  - See FilesOperationsInVolumesInternal.FileAddingOptions
//                       - DefinedType.AttachedFileObject - An attachment catalog item whose data is saved to a volume,
//                                     or a structure with properties required to save data to the volume.
//                                     
//   BinaryDataOrPath - BinaryData
//                         - String - binary data of the file or the full file path.
//   FileDateInVolume - Date - if it is not specified, the current session time is used.
//   FillInternalStorageAttribute - Boolean - if the parameter is True, also store
//                                       the binary file data to the FileStorage internal attribute.
//   VolumeForPlacement - CatalogRef.FileStorageVolumes
//                    - Undefined - If the parameter is filled, files will be placed to a specified volume.
//                                     Otherwise, the volume will be selected automatically.
//
Procedure FillInTheFileDetails(AttachedFile, BinaryDataOrPath, 
	FileDateInVolume = Undefined, FillInternalStorageAttribute = False, VolumeForPlacement = Undefined) Export
	
	ExpectedTypes = New Array;
	ExpectedTypes.Add(Type("BinaryData"));
	ExpectedTypes.Add(Type("String"));
	CommonClientServer.CheckParameter("FilesOperationsInternal.AddFileToVolume",
		"BinaryDataOrPath", BinaryDataOrPath, New TypeDescription(ExpectedTypes));
	
	If TypeOf(AttachedFile) = Type("Structure")
		And Not ValueIsFilled(AttachedFile.Ref) Then
		
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Blank value of the %1 property the %2 parameter (Structure) of the %3 procedure.';"),
			"Ref",
			"AttachedFile",
			"FilesOperationsInVolumesInternal.AppendFile"), ErrorCategory.ConfigurationError);
		
	EndIf;
	
	If TypeOf(BinaryDataOrPath) = Type("String") Then
		
		FileOnHardDrive = New File(BinaryDataOrPath);
		If FileOnHardDrive.Exists() Then
			AttachedFile.Size = FileOnHardDrive.Size();
			AttachedFile.Extension = StrReplace(FileOnHardDrive.Extension, ".", "");
		Else
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot add file ""%1"" to a volume as the file is missing.
				|The file might have been deleted by antivirus software. Please contact the administrator.';"),
				AttachedFile.Description + "." + AttachedFile.Extension);
			Raise ErrorText;
			
		EndIf;
		
	Else
		AttachedFile.Size = BinaryDataOrPath.Size();
		AttachedFile.Extension = StrReplace(AttachedFile.Extension, ".", "");
	EndIf;
	
	FileStorageType = AttachedFile.FileStorageType;
	If Not ValueIsFilled(FileStorageType) Then
		FileStorageType = FilesOperationsInternal.FileStorageType(AttachedFile.Size, AttachedFile.Extension);
	EndIf;

	If FileStorageType = Enums.FileStorageTypes.InInfobase Then
		
		FileRef = AttachedFile.Ref;
		If Not ValueIsFilled(FileRef) Then
			MetadataAttachedFile = AttachedFile.Metadata(); // MetadataObject
			FileRef = Catalogs[MetadataAttachedFile.Name].GetRef();
			AttachedFile.SetNewObjectRef(FileRef);
		EndIf;
		
		FileData = ?(TypeOf(BinaryDataOrPath) = Type("String"),
			New BinaryData(BinaryDataOrPath), BinaryDataOrPath);
		FilesOperationsInternal.WriteFileToInfobase(FileRef, FileData);
		
		AttachedFile.FileStorageType = Enums.FileStorageTypes.InInfobase;
		AttachedFile.Volume = Undefined;
		AttachedFile.PathToFile = "";
		If FillInternalStorageAttribute Then
			AttachedFile.FileStorage = New ValueStorage(FileData);
		EndIf;

	Else
		
		If ValueIsFilled(VolumeForPlacement) Then
			AttachedFile.Volume = VolumeForPlacement;
		Else
			AttachedFile.Volume = FreeVolume(AttachedFile);
		EndIf;
		AttachedFile.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive;
		
		FileProperties = FilePropertiesInVolume();
		FillPropertyValues(FileProperties, AttachedFile);
		If FileProperties.FileOwner = Undefined 
			And TypeOf(AttachedFile.Ref) = Type("CatalogRef.FilesVersions") Then
			FileProperties.FileOwner = Common.ObjectAttributeValue(
				AttachedFile.Owner, "FileOwner");
		EndIf;
		
		VolumePath = FullVolumePath(AttachedFile.Volume);
		PathToFile = FullFileNameInVolume(FileProperties, FileDateInVolume);
		
		AttachedFile.PathToFile = Mid(PathToFile, StrLen(VolumePath) + 1);
		AttachedFile.AdditionalProperties.Insert("VolumePath", VolumePath);
		If FillInternalStorageAttribute Then
			AttachedFile.FileStorage = New ValueStorage(Undefined);
		EndIf;
	EndIf;
	
EndProcedure

// Copies the attachment data by the specified path.
//
// Parameters:
//   AttachedFile - DefinedType.AttachedFile
//   FilePathDestination - String - a full path (including a file name), to which the file will be copied from the volume.
//
Procedure CopyAttachedFile(AttachedFile, FilePathDestination) Export
	
	FileProperties = FilePropertiesInVolume(AttachedFile);
	FilePathSource = FullFileNameInVolume(FileProperties);
	
	SourceFile1 = New File(FilePathSource);
	If Not SourceFile1.Exists() Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'File data was deleted. The file might have been cleaned up as unused or deleted by the antivirus software.
				|%1';"), String(AttachedFile));
		Raise ErrorMessage;		
	EndIf;
	
	FileCopy(FilePathSource, FilePathDestination);
	
	// If the file is read-only, clear this attribute for 
	// the destination file to be able to edit or delete.
	FileDestination = New File(FilePathDestination);
	If FileDestination.Exists() And FileDestination.GetReadOnly() Then
		FileDestination.SetReadOnly(False);
	EndIf;
	
EndProcedure

// Deletes file from the volume.
//
// Parameters:
//   PathToFile - String - a path to the file to be deleted.
// 
// Returns:
//    Structure:
//    * Success - Boolean
//    * ErrorInfo - ErrorInfo
//
Function DeleteFile(PathToFile) Export
	Result = New Structure("Name,Success,ErrorInfo", 
		PathToFile, True, Undefined);
	
	FileOnHardDrive = New File(PathToFile);
	If FileOnHardDrive.Exists() Then
		
		FileDirectory = FileOnHardDrive.Path;
		Try
			FileOnHardDrive.SetReadOnly(False);
			DeleteFiles(PathToFile);
			
			// Deleting the file directory if the directory is empty after the file deletion.
			FilesInDirectory = FindFiles(FileDirectory, GetAllFilesMask());
			If FilesInDirectory.Count() = 0 Then
				DeleteFiles(FileDirectory);
			EndIf;
			
		Except
			Error = ErrorInfo();
			Result.ErrorInfo = ErrorProcessing.ErrorMessageForUser(Error);
			Result.Success = False;
			WriteLogEvent(
				NStr("en = 'Files.Delete files from volume';", Common.DefaultLanguageCode()),
				EventLogLevel.Error,,,
				ErrorProcessing.DetailErrorDescription(Error));
		EndTry;
		
	EndIf;
	
	Return Result;
EndFunction

// Renames a file in the volume.
//
// Parameters:
//   AttachedFile      - DefinedType.AttachedFile - a reference to the catalog item with file.
//   NewName                - String - a name that will be set to the file in the volume.
//   OldName               - String - the current file name in the volume. If the parameter is not filled in, the description of the attached file will be considered the current
//                           name.
//   UUID - UUID - a form ID to lock the attached
//                           file when writing a new file path to the volume.
//
Procedure RenameFile(AttachedFile,Val NewName,
	Val OldName = "", UUID = Undefined) Export
	
	BeginTransaction();
	Try
		
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(
			Metadata.FindByType(TypeOf(AttachedFile)).FullName());
		DataLockItem.SetValue("Ref", AttachedFile);
		DataLock.Lock();
		
		AttachedFileObject = AttachedFile.GetObject();
		LockDataForEdit(AttachedFile, , UUID);
		
		FileProperties = FilePropertiesInVolume();
		FillPropertyValues(FileProperties, AttachedFileObject);
		
		VolumePath = FullVolumePath(AttachedFileObject.Volume);
		CurrentFilePath = FullFileNameInVolume(FileProperties);
		
		FileOnHardDrive = New File(CurrentFilePath);
		NameForReplacement = ?(IsBlankString(OldName), AttachedFileObject.Description, OldName);
		NewNameOfFile = StrReplace(FileOnHardDrive.BaseName, NameForReplacement, NewName) + FileOnHardDrive.Extension;

		NewFilePath = FileOnHardDrive.Path
			+ FilesOperationsInternalClientServer.UniqueNameByWay(FileOnHardDrive.Path, NewNameOfFile);
			
		MoveFile(CurrentFilePath, NewFilePath);
		
		AttachedFileObject.PathToFile = StrReplace(NewFilePath, VolumePath, "");
		AttachedFileObject.Write();
		
		UnlockDataForEdit(AttachedFile, UUID);
		CommitTransaction();
		
	Except
		RollbackTransaction();
		UnlockDataForEdit(AttachedFile, UUID);
		Raise;
	EndTry;
	
EndProcedure

// Initializes the file property structure to get the full path to the file in the volume.
// 
// If version storage is used for a file and there are no versions, 
// then the data will be filled in by the file, and empty values will be returned as the Volume and path.
//
// Parameters:
//   File - DefinedType.AttachedFile
//        - Undefined - If the parameter value is filled,
//          properties are filled with values of respective file attributes of the same name. Otherwise, the properties take the Undefined values.
//
// Returns:
//   Structure:
//     * Description - String - a file description.
//     * Volume - CatalogRef.FileStorageVolumes
//     * PathToFile - String - a path to file.
//     * FileOwner - DefinedType.AttachedFilesOwner
//                     - DefinedType.FilesOwner
//                     - Undefined
//     * Extension - String - a file extension.
//     * VersionNumber - String - the file version number.
//
Function FilePropertiesInVolume(File = Undefined) Export
	
	FileProperties = New Structure;
	FileProperties.Insert("Description", "");
	FileProperties.Insert("Extension", "");
	FileProperties.Insert("Volume", Catalogs.FileStorageVolumes.EmptyRef());
	FileProperties.Insert("PathToFile", "");
	FileProperties.Insert("FileOwner", Undefined);
	FileProperties.Insert("VersionNumber", "");
	
	If ValueIsFilled(File) Then
		
		If TypeOf(File) = Type("CatalogRef.Files") Then
			RefToVersion = Common.ObjectAttributeValue(File, "CurrentVersion");
		Else
			RefToVersion = File;
		EndIf;
		
		// During file deletion there could be no file versions.
		PropertyToCheck = New Structure("DataVersion");
		FillPropertyValues(PropertyToCheck, RefToVersion);
		If Not ValueIsFilled(PropertyToCheck.DataVersion) Then
			RefToVersion = File;
		EndIf;
		
		FileAttributes = New Array;
		FileAttributes.Add("Description");
		FileAttributes.Add("Extension");
		FileAttributes.Add("Volume");
		FileAttributes.Add("PathToFile");
		If TypeOf(RefToVersion) = Type("CatalogRef.FilesVersions") Then
			FileAttributes.Add("Owner");
			FileAttributes.Add("VersionNumber");
		Else
			FileAttributes.Add("FileOwner");
		EndIf;
		
		AttributesNames = StrConcat(FileAttributes, ",");
		FileAttributes = Common.ObjectAttributesValues(RefToVersion, AttributesNames);
		FillPropertyValues(FileProperties, FileAttributes);
		 
		If FileAttributes.Property("Owner") And ValueIsFilled(FileAttributes.Owner) Then
			FileProperties.FileOwner = Common.ObjectAttributeValue(FileAttributes.Owner, "FileOwner");
		EndIf;
		
	EndIf;
	
	If TypeOf(FileProperties.VersionNumber) <> Type("String") Then
		FileProperties.VersionNumber = String(FileProperties.VersionNumber);
	EndIf;
	
	Return FileProperties;
	
EndFunction

// Returns a full name for the file in the volume, considering file storage
// settings in volumes and separator values.
//
// Parameters:
//   FileProperties - See FilePropertiesInVolume.
//   FileDateInVolume - Date
//   
// Returns:
//   String
//
Function FullFileNameInVolume(FileProperties, FileDateInVolume = Undefined) Export
	
	Separator = GetPathSeparator();
	
	If Not ValueIsFilled(FileProperties.Volume) Then
		Return "";
	EndIf;
	
	FullVolumePath = FullVolumePath(FileProperties.Volume);
	If Not IsBlankString(FileProperties.PathToFile) Then
		Return FullVolumePath + FileProperties.PathToFile;
	EndIf;
	
	RootDirectory1 = FullVolumePath + ?(Right(FullVolumePath, 1) = Separator, "", Separator);
	If CreateSubdirectoriesWithOwnersNames() Then
		FileOwnerDirectoryName = FileOwnerDirectoryName(FileProperties.FileOwner);
		RootDirectory1 = RootDirectory1 + FileOwnerDirectoryName + ?(FileOwnerDirectoryName = "", "", Separator);
	EndIf;
	
	PlacementDate = ?(ValueIsFilled(FileDateInVolume), FileDateInVolume, CurrentSessionDate());
	RootDirectory1 = RootDirectory1 + Format(PlacementDate, "DF=yyyyMMdd") + Separator;
	
	VersionNumber = ?(ValueIsFilled(FileProperties.VersionNumber), "." + FileProperties.VersionNumber, "");
	AddPoint = ValueIsFilled(FileProperties.Extension) And StrFind(FileProperties.Extension, ".") = 0;
	FileName = CommonClientServer.ReplaceProhibitedCharsInFileName(FileProperties.Description)
		+ VersionNumber + ?(AddPoint, ".", "") + FileProperties.Extension;
		
	Common.ShortenFileName(FileName);
	
	Try
		Return RootDirectory1
			+ FilesOperationsInternalClientServer.UniqueNameByWay(RootDirectory1, FileName);
	Except
		Volume = New File(FullVolumePath);
		If Not Volume.Exists() Or Not Volume.IsDirectory() Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'A network directory for the ""%1"" storage volume does not exist: %2
					|Contact your administrator.';"), FileProperties.Volume, FullVolumePath);
		EndIf;
		Raise;
	EndTry	
EndFunction

// Returns a full path to the root directory of a file storage volume.
//
// Parameters:
//   Volume - CatalogRef.FileStorageVolumes - the volume whose root directory path is to be received.
//
// Returns:
//   String - Full path to the volume's root directory.
//
Function FullVolumePath(Volume) Export

	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	RootDirectory1 = Common.ObjectAttributeValue(Volume,
		?(Common.IsWindowsServer(), "FullPathWindows", "FullPathLinux"));
	
	If Common.DataSeparationEnabled() Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		SeparatorValue = "";
		If VolumePathIgnoreRegionalSettings() Then
			SeparatorValue = ?(ModuleSaaSOperations.SessionSeparatorUsage(),
									Format(ModuleSaaSOperations.SessionSeparatorValue(), "NG=;"),
									"");
		Else
			SeparatorValue = ?(ModuleSaaSOperations.SessionSeparatorUsage(),
									ModuleSaaSOperations.SessionSeparatorValue(),
									"");
		EndIf;
	Else
		SeparatorValue = "";
	EndIf;
	
	Return StrReplace(RootDirectory1, "%z",SeparatorValue);
	
EndFunction

// Returns the total size of all files in the volume in bytes.
//
// Parameters:
//   Volume - CatalogRef.FileStorageVolumes - a volume whose size must be calculated.
//
// Returns:
//   Number - Total size of the volume files.
//
Function VolumeSize(Volume) Export
	
	VolumeSize = 0;
	If Not Common.SeparatedDataUsageAvailable() Then
		Return VolumeSize;
	EndIf;
	
	Query = New Query;
	AttachedFilesTypes = Metadata.DefinedTypes.AttachedFile.Type.Types();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ISNULL(SUM(Versions.Size), 0) AS FilesSize
	|FROM
	|	Catalog.FilesVersions AS Versions
	|WHERE
	|	Versions.Volume = &Volume";
	
	For Each Type In AttachedFilesTypes Do
		
		If Type = Type("CatalogRef.FilesVersions")
			Or Type = Type("CatalogRef.MetadataObjectIDs") Then
			
			Continue;
		EndIf;
		
		CatalogMetadata = Metadata.FindByType(Type);
		If CatalogMetadata.Attributes.Find("CurrentVersion") <> Undefined Then
			Continue;
		EndIf;
		
		QueryTextByDirectory = "SELECT
		|	ISNULL(SUM(AttachedFiles.Size), 0)
		|FROM
		|	&CatalogName AS AttachedFiles
		|WHERE
		|	AttachedFiles.Volume = &Volume";
		
		Query.Text = Query.Text + "
		|
		|UNION ALL
		|
		|" + StrReplace(QueryTextByDirectory, "&CatalogName",
			Metadata.FindByType(Type).FullName());
		
	EndDo;
	
	Query.Parameters.Insert("Volume", Volume);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VolumeSize = VolumeSize + Selection.FilesSize;
	EndDo;
			
	Return VolumeSize;
	
EndFunction

// Checks whether the file is on the computer.
//
// Parameters:
//   AttachedFile - DefinedType.AttachedFile - catalog item with a file.
//
// Returns:
//   Boolean
//
Function AttachedFileIsLocatedOnDisk(AttachedFile) Export
	
	FileProperties = FilePropertiesInVolume(AttachedFile);
	PathToFile = FullFileNameInVolume(FileProperties);
	If Not ValueIsFilled(PathToFile) Then
		Return False;
	EndIf;
			
	FileToCheck = New File(PathToFile);
	If FileToCheck.Exists() Then
		Return True;
	EndIf;
	
	Return False;
EndFunction

#Region AccountingAudit

// See AccountingAuditOverridable.OnDefineChecks
Procedure OnDefineChecks(ChecksGroups, Checks) Export
	
	Validation = Checks.Add();
	Validation.GroupID          = "SystemChecks";
	Validation.Description                 = NStr("en = 'Search for references to missing files in storage volumes';");
	Validation.Reasons                      = NStr("en = 'The file was deleted or moved by the antivirus software,
		|unintentional actions of the administrator, or similar reasons.';");
	Validation.Recommendation                 = NStr("en = '• Mark the file for deletion.
		|• Restore the volume file from a backup.';");
	Validation.Id                = "StandardSubsystems.ReferenceToNonexistingFilesInVolumeCheck";
	Validation.HandlerChecks           = "FilesOperationsInVolumesInternal.ReferenceToNonexistingFilesInVolumeCheck";
	Validation.AccountingChecksContext = "SystemChecks";
	Validation.isDisabled                    = True;
	
EndProcedure

Procedure ReferenceToNonexistingFilesInVolumeCheck(Validation, CheckParameters) Export
	
	If Common.DataSeparationEnabled()
		Or Not StoreFilesInVolumesOnHardDrive() Then
		Return;
	EndIf;
	
	AvailableVolumes = AvailableVolumes(CheckParameters);
	If AvailableVolumes.Count() = 0 Then
		Return;
	EndIf;
	
	ModuleSaaSOperations = Undefined;
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	EndIf;
	
	MetadataObjectsKinds = New Array;
	MetadataObjectsKinds.Add(Metadata.Catalogs);
	MetadataObjectsKinds.Add(Metadata.Documents);
	MetadataObjectsKinds.Add(Metadata.ChartsOfAccounts);
	MetadataObjectsKinds.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataObjectsKinds.Add(Metadata.Tasks);
	
	For Each MetadataObjectKind In MetadataObjectsKinds Do
		For Each MetadataObject In MetadataObjectKind Do
			If ModuleSaaSOperations <> Undefined 
				And Not ModuleSaaSOperations.IsSeparatedMetadataObject(MetadataObject.FullName()) Then
				Continue;
			EndIf;
			If Not CheckAttachedFilesObject(MetadataObject) Then
				Continue;
			EndIf;
			// @skip-check query-in-loop - Batch processing of a large amount of data.
			SearchRefsToNonExistingFilesInVolumes(MetadataObject, CheckParameters, AvailableVolumes);
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion

#Region StorageParameters

// Returns a flag that files can be stored in volumes.
//
// Returns:
//  Boolean
//
Function StoreFilesInVolumesOnHardDrive() Export
	
	SetPrivilegedMode(True);
	FilesStorageMethod = Constants.FilesStorageMethod.Get();
	Return FilesStorageMethod = "InVolumesOnHardDrive"
		Or FilesStorageMethod = "InInfobaseAndVolumesOnHardDrive";
	
EndFunction

// Returns information about file storage settings in the infobase.
// It makes sense in case of storing files in volumes and in the infobase.
//
// Returns:
//   Structure::
//    * FilesExtensions   - String - file extensions that are stored in the infobase.
//                                    Separated by space.
//    * MaximumSize - Number - Maximum size of the file being saved to the infobase, in bytes.
//
Function FilesStorageParametersInInfobase() Export
	
	SetPrivilegedMode(True);
	Return Constants.ParametersOfFilesStorageInIB.Get().Get();
	
EndFunction

// Configures file storage settings in the infobase.
// It makes sense in case of storing files in volumes and in the infobase.
//
// Parameters:
//  StorageParameters - Structure - settings of file storage in the infobase. Properties:
//    * FilesExtensions   - String - file extensions that are stored in the infobase.
//                         Separated by space.
//    * MaximumSize - Number - a maximum size of the file being saved
//                         to the infobase, in bytes.
//
Procedure SetFilesStorageParametersInInfobase(StorageParameters) Export
	
	StorageParametersSet = New ValueStorage(StorageParameters);
	Constants.ParametersOfFilesStorageInIB.Set(StorageParametersSet);
	
EndProcedure

#EndRegion

// Fills the "PathToFile" attribute for attachments.
// 
// Parameters:
//  FilesToRecover - ValueTable:
//   * File - DefinedType.AttachedFile - File
//   * FullName - String - File's full name in the given volume.
//  VolumePath - String
// 
// Returns:
//  Structure:
//   * Processed - Number
//   * Total - Number
//
Function SetFilesStoragePaths(FilesToRecover, VolumePath) Export
	Result = New Structure;
	Result.Insert("Processed", 0);
	Result.Insert("Total", FilesToRecover.Count());
	
	If FilesToRecover.Count() = 0 Then
		Return Result;
	EndIf;
	
	FilesTypes = New Map;
	
	For Each FileToRecover In FilesToRecover Do
		FileType = TypeOf(FileToRecover.File);
		If FilesTypes[FileType] = Undefined Then
			FilesTypes.Insert(FileType, New Array);
		EndIf;
		
		FilesTypes[FileType].Add(FilesToRecover.IndexOf(FileToRecover));
	EndDo;
	
	Portions = New Array;
	PortionSize = 100;
	
	For Each FileType In FilesTypes Do
		NewBatch = True;
		For Each RowIndex In FileType.Value Do
			If NewBatch Then
				FilesInBatch = New ValueTable;
				FilesInBatch.Columns.Add("File", New TypeDescription(CommonClientServer.ValueInArray(FileType.Key)));
				FilesInBatch.Columns.Add("FullName", New TypeDescription("String"));
				NewBatch = False;
			EndIf;
			NewRecord = FilesInBatch.Add();
			FileToRecover = FilesToRecover[RowIndex];
			NewRecord.File = FileToRecover.File;
			NewRecord.FullName = FileToRecover.FullName;
			IsBatchWritten = False;
			If FilesInBatch.Count() = PortionSize Then
				Portions.Add(FilesInBatch);
				NewBatch = True;
				IsBatchWritten = True;
			EndIf;
		EndDo;
		If Not IsBatchWritten Then
			Portions.Add(FilesInBatch);
		EndIf;
	EndDo;
	
	For Each Batch In Portions Do
		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add(Batch[0].File.Metadata().FullName());
			LockItem.DataSource = Batch;
			LockItem.UseFromDataSource("Ref", "File");
			Block.Lock();
			
			FilesStoragePaths = Common.ObjectsAttributeValue(Batch.UnloadColumn("File"), "PathToFile");
			For Each FileToFix In Batch Do
				FileStoragePath = FilesStoragePaths[FileToFix.File];
				If VolumePath = "" Then
					FilePathOnHardDrive = TrimR(FileToFix.FullName);
				ElsIf StrStartsWith(FileToFix.FullName, VolumePath) Then
					FilePathOnHardDrive = TrimR(Mid(FileToFix.FullName, StrLen(VolumePath) + 1));
				Else
					FilePathOnHardDrive = Undefined;
				EndIf;
				
				If FilePathOnHardDrive <> FileStoragePath Then
					FileToWrite = FileToFix.File.GetObject();
					FileToWrite.PathToFile = FilePathOnHardDrive;
					FileToWrite.AdditionalProperties.Insert("FileConversion", True);
					FileToWrite.Write();
				EndIf;
			EndDo;
			Result.Processed = Result.Processed + Batch.Count(); 
			CommitTransaction();
		Except
			RollbackTransaction();
			WriteLogEvent(
				NStr("en = 'Files.File recovery in volume';", Common.DefaultLanguageCode()),
				EventLogLevel.Error,,,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
	EndDo;
	Return Result;
EndFunction

#EndRegion

#Region Private

// Returns sizes of all files in each specified volume in bytes.
//
// Parameters:
//   Volumes - Array of CatalogRef.FileStorageVolumes
//
// Returns:
//   Map of KeyAndValue:
//     * Key - CatalogRef.FileStorageVolumes
//     * Value - Number
//
Function SizesOfVolumes(Volumes)
	
	Result = New Map;
	For Each Volume In Volumes Do
		Result[Volume] = 0;
	EndDo; 
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return Result;
	EndIf;
	
	AttachedFilesTypes = Metadata.DefinedTypes.AttachedFile.Type.Types();
	QueriesTexts = New Array;
	
	QueryText = 
	"SELECT
	|	Versions.Volume AS Volume,
	|	ISNULL(Versions.Size, 0) AS FilesSize
	|FROM
	|	Catalog.FilesVersions AS Versions
	|WHERE
	|	Versions.Volume IN (&Volumes)";
	QueriesTexts.Add(QueryText);
	
	QueryTextTemplate2 = "SELECT
	|	AttachedFiles.Volume,
	|	ISNULL(AttachedFiles.Size, 0)
	|FROM
	|	&CatalogName AS AttachedFiles
	|WHERE
	|	AttachedFiles.Volume IN (&Volumes)";
	
	For Each Type In AttachedFilesTypes Do
		
		If Type = Type("CatalogRef.FilesVersions")
			Or Type = Type("CatalogRef.MetadataObjectIDs") Then
			
			Continue;
		EndIf;
		
		CatalogMetadata = Metadata.FindByType(Type);
		If CatalogMetadata.Attributes.Find("CurrentVersion") <> Undefined Then
			Continue;
		EndIf;
		
		QueriesTexts.Add(StrReplace(QueryTextTemplate2, "&CatalogName", 
			Metadata.FindByType(Type).FullName()));
	EndDo;
	
	QueryText = 
		"SELECT
		|	NestedQuery.Volume,
		|	SUM(NestedQuery.FilesSize) AS FilesSize
		|FROM
		|	&AttachmentsQueryText AS NestedQuery
		|GROUP BY
		|	NestedQuery.Volume";
	QueryText = StrReplace(QueryText, "&AttachmentsQueryText", 
		"(" + StrConcat(QueriesTexts, Chars.LF + "UNION ALL" + Chars.LF) + ")"); // @query-part
	
	Query = New Query(QueryText); 
	Query.Parameters.Insert("Volumes", Volumes);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Result[Selection.Volume] = Selection.FilesSize;
	EndDo;
			
	Return Result;
	
EndFunction

// For the function, See FullVolumePath.
// 
// Returns:
//  Boolean
//
Function VolumePathIgnoreRegionalSettings() Export
	Return FilesOperationsInternalCached.VolumePathIgnoreRegionalSettings();
EndFunction

// Saves the binary file data to a volume, or copies data from the file by the passed path.
// Before calling, fill in the file information (See FillInTheFileDetails)
// 
// .
// 
// Cannot be called with the safe mode enabled (throws exceptions). 
// 
// Parameters:
//   AttachedFile - DefinedType.AttachedFileObject
//   BinaryDataOrPath - BinaryData
//                         - String - binary data of the file or the full file path.
//
Procedure WriteTheFileDataToTheVolume(AttachedFile, BinaryDataOrPath)
	
	SetPrivilegedMode(True);
	
	ErrorDescriptionTemplate = "";
	ExceptionString = "";
	VolumePath = CommonClientServer.StructureProperty(AttachedFile.AdditionalProperties, "VolumePath", "");
	
	FileProperties = FilePropertiesInVolume();
	FillPropertyValues(FileProperties, AttachedFile);
	
	PathToFile = FullFileNameInVolume(FileProperties);
				
	Try
		
		If TypeOf(BinaryDataOrPath) = Type("String") Then
			
			File = New File(PathToFile);
			
			If File.Exists() Then
				File.SetReadOnly(False);
			Else
				Path = File.Path;
				Directory = New File(Path);
				If Not Directory.Exists() Then
					CreateDirectory(Path);
				EndIf;
			EndIf;
				
			FileCopy(BinaryDataOrPath, PathToFile);
			
		Else
			BinaryDataOrPath.Write(PathToFile);
		EndIf;
		
		FileOnHardDrive = New File(PathToFile);
		FileOnHardDrive.SetModificationUniversalTime(AttachedFile.UniversalModificationDate);
		FileOnHardDrive.SetReadOnly(True);
		
	Except
		
		ErrorDescriptionTemplate = NStr("en = 'An error occurred when adding file ""%1""
			|to volume ""%2"" (%3):
			|""%4"".';");
		
		WriteLogEvent(NStr("en = 'Files.Add file';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,,,
			StringFunctionsClientServer.SubstituteParametersToString(
				ErrorDescriptionTemplate,
				AttachedFile.Description + "." + AttachedFile.Extension,
				String(AttachedFile.Volume),
				VolumePath,
				ErrorProcessing.DetailErrorDescription(ErrorInfo())));
		
		If Users.IsFullUser() Then
			
			ExceptionString = StringFunctionsClientServer.SubstituteParametersToString(
				ErrorDescriptionTemplate,
				AttachedFile.Description + "." + AttachedFile.Extension,
				String(AttachedFile.Volume),
				VolumePath,
				ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			
		Else
			
			// Message to end user.
			ExceptionString = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot add file:
				|""%1.%2"".
				|
				|Please contact the administrator.';"),
				AttachedFile.Description,
				AttachedFile.Extension);
				
		EndIf;
		
		Raise ExceptionString;
		
	EndTry; 
	
	If ValueIsFilled(AttachedFile.Ref) Then
		InformationRegisters.FileRepository.DeleteBinaryData(AttachedFile.Ref);
	EndIf;
	
EndProcedure

Procedure ClearDeletedFiles() Export
	If Not StoreFilesInVolumesOnHardDrive() Then
		Return;
	EndIf;
	
	ProcessedVolumes = AvailableVolumes();
	DescriptionOfVolumes = Common.ObjectsAttributesValues(ProcessedVolumes, 
		"Ref, LastFilesCleanupTime, DeletionMark, FullPathLinux, FullPathWindows");
		
	ProcessedDirectories = New Map; // Several volumes can store files in the same directory.
	For Each VolumeDescription In DescriptionOfVolumes Do
		RootDirectory1 = FullVolumePath(VolumeDescription.Key);
		
		SearchDirectoryForDeletedFiles = ProcessedDirectories[RootDirectory1];
		If SearchDirectoryForDeletedFiles = Undefined Then
			SearchDirectoryForDeletedFiles = SearchDirectoryForDeletedFiles(RootDirectory1);
			ProcessedDirectories.Insert(RootDirectory1, SearchDirectoryForDeletedFiles);
		EndIf;
		
		AddVolume(SearchDirectoryForDeletedFiles, VolumeDescription.Value);
	EndDo;
	
	For Each Volume In ProcessedDirectories Do
		// @skip-check query-in-loop - Insignificant number of calls.
		ClearDeletedFilesInTheVolume(Volume.Value);
	EndDo;
EndProcedure

// Parameters:
//  Path - String - Path.
// 
// Returns:
//  Structure - directory of search of files to delete:
//   * Path - String
//   * Volumes - ValueTable:
//   ** Ref - CatalogRef.FileStorageVolumes
//   ** LastFilesCleanupTime - Date
//   ** DeletionMark - Boolean
//   * LastFilesCleanupTime - Date
//   * Process - Boolean
//
Function SearchDirectoryForDeletedFiles(Path)
	Directory = New Structure;
	Directory.Insert("Path", Path);
	
	VolumeTable = New ValueTable;
	VolumeTable.Columns.Add("Ref", New TypeDescription("CatalogRef.FileStorageVolumes"));
	VolumeTable.Columns.Add("LastFilesCleanupTime", New TypeDescription("Date"));
	VolumeTable.Columns.Add("DeletionMark", New TypeDescription("Boolean"));
	
	Directory.Insert("Volumes", VolumeTable);
	Directory.Insert("LastFilesCleanupTime", Date(1,1,1));
	Directory.Insert("Process", True);
	Return Directory;
EndFunction

// Parameters:
//  SearchDirectoryForDeletedFiles - See SearchDirectoryForDeletedFiles
//
Procedure AddVolume(SearchDirectoryForDeletedFiles, Volume)
	// Skip processing of volumes marked for deletion.
	If Volume.DeletionMark <> Undefined And Volume.DeletionMark Then
		SearchDirectoryForDeletedFiles.Process = False;
		Return;
	EndIf;
	
	// Cannot separate deleted files from files in other areas when separation is enabled 
	// and the volumes are shared (volumes are not divided into areas).
	If Common.DataSeparationEnabled() 
			And (ValueIsFilled(Volume.FullPathLinux) And StrFind(Volume.FullPathLinux, "%z") = 0
				Or ValueIsFilled(Volume.FullPathWindows) And StrFind(Volume.FullPathWindows, "%z") = 0) Then
		
		SearchDirectoryForDeletedFiles.Process = False;	
		Return;
	EndIf;
	
	LastFilesCleanupTime = ?(SearchDirectoryForDeletedFiles.LastFilesCleanupTime < Volume.LastFilesCleanupTime,
									Volume.LastFilesCleanupTime,
									SearchDirectoryForDeletedFiles.LastFilesCleanupTime);
	SearchDirectoryForDeletedFiles.LastFilesCleanupTime = LastFilesCleanupTime;
	
	VolumeRow = SearchDirectoryForDeletedFiles.Volumes.Add();
	FillPropertyValues(VolumeRow, Volume);
EndProcedure

// Parameters:
//  Directory - See SearchDirectoryForDeletedFiles
//
Procedure ClearDeletedFilesInTheVolume(Directory)
	If Not Directory.Process Then
		Return;
	EndIf;
	
	TimeOfLastCleaning = Directory.LastFilesCleanupTime;
	RootDirectory1 = Directory.Path;
	
	FilesForDeletion = FilesForDeletion(RootDirectory1, TimeOfLastCleaning);
	
	DeleteVolumesFiles(DeletedFiles(Directory.Volumes, RootDirectory1, FilesForDeletion));
	
	Volume = New Structure("Ref");
	BeginTransaction();
	Try
		Block = New DataLock();
		Item = Block.Add(Metadata.Catalogs.FileStorageVolumes.FullName());
		Item.DataSource = Directory.Volumes;
		Item.UseFromDataSource("Ref", "Ref");
		Block.Lock();
		
		For Each Volume In Directory.Volumes Do
			VolumeObject = Volume.Ref.GetObject();
			VolumeObject.LastFilesCleanupTime = CurrentUniversalDate();
			VolumeObject.Write();
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Error = ErrorInfo();
		WriteLogEvent(NStr("en = 'File management.File cleanup';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,
			Metadata.Catalogs.FileStorageVolumes,
			Volume.Ref,
			ErrorProcessing.DetailErrorDescription(Error));
	EndTry;

EndProcedure

// Returns deleted files.
// 
// Parameters:
//  Volumes - Array of CatalogRef.FileStorageVolumes
//  RootDirectory1 - String
//  FilesForDeletion - Array of File
// 
// Returns:
//   Array of File
//  
Function DeletedFiles(Volumes, RootDirectory1, FilesForDeletion)
	Result = New Array;
	
	FileSystemProperties = FileSystemProperties(RootDirectory1);
	
	ShouldFixFilePaths = Not FileSystemProperties.HasFilenameLeadingWhitespace
		Or Not FileSystemProperties.HasFilenameTrailingDot;
	
	TableFiles = New ValueTable();
	StringLength = Metadata.Catalogs.Files.Attributes.PathToFile.Type;
	TableFiles.Columns.Add("Path", StringLength);
	
	If ShouldFixFilePaths Then
		TableFiles.Columns.Add("AlternativePath", StringLength);
		TableFiles.Columns.Add("ShouldUseAlternativePath", New TypeDescription("Boolean"));
	EndIf;
	
	For Each File In FilesForDeletion Do
		RelativePath = StrReplace(File, RootDirectory1, "");
		FileString = TableFiles.Add();
		FileString.Path = RelativePath;
		
		If ShouldFixFilePaths Then
			
			FileProperties = New File(RelativePath);
			
			AlternativePath = RelativePath;
			ShouldAddWhitespaceString = False;
			If Not FileSystemProperties.HasFilenameLeadingWhitespace
				And Left(FileProperties.Name, 1) <> " " Then
				AlternativePath = FileProperties.Path + " " + FileProperties.Name;
				ShouldAddWhitespaceString = True;
			EndIf;
			
			ShouldAddDotString = False;
			If Not FileSystemProperties.HasFilenameTrailingDot 
				And FileProperties.Extension = "" Then
				AlternativePath = AlternativePath + ".";
				ShouldAddDotString = True;
			EndIf;
			
			If ShouldAddWhitespaceString Or ShouldAddDotString Then
				FileString = TableFiles.Add();
				FileString.Path = RelativePath;
				FileString.ShouldUseAlternativePath = True;
				FileString.AlternativePath = AlternativePath;
			EndIf;
			
			If ShouldAddWhitespaceString And ShouldAddDotString Then
				FileString = TableFiles.Add();
				FileString.Path = RelativePath;
				FileString.ShouldUseAlternativePath = True;
				FileString.AlternativePath = FileProperties.Path + " " + FileProperties.Name;

				FileString = TableFiles.Add();
				FileString.Path = RelativePath;
				FileString.ShouldUseAlternativePath = True;
				FileString.AlternativePath = RelativePath + ".";
			EndIf;
		EndIf;
	EndDo;
	
	If ShouldFixFilePaths Then
		Query = QueryExistingFilesWithRestoredLinks(TableFiles);
		Query.SetParameter("Volumes", Volumes);
		QueryResults = Query.ExecuteBatch();
		UnnecessaryFiles = QueryResults[QueryResults.UBound() - 1];
		
		FilesToFix = QueryResults[QueryResults.UBound()].Unload();
		SetFilesStoragePaths(FilesToFix, "");
	Else
		Query = RequestToVerifyTheExistenceOfFiles(TableFiles);
		Query.SetParameter("Volumes", Volumes);
		UnnecessaryFiles = Query.Execute();
	EndIf;
	
	Selection = UnnecessaryFiles.Select();
	While Selection.Next() Do
		Result.Add(RootDirectory1 + TrimAll(Selection.Path));
	EndDo;
	
	Return Result;
EndFunction

// File length in the query is limited:
// Metadata name (80) + date (6) + subdirectory to exclude repetition (6) + file name (150).
// Total: 242 characters.
//
Function RequestToVerifyTheExistenceOfFiles(Val TableFiles)
	TableManager = New TempTablesManager();
	Query = New Query("SELECT
	|	CAST(Files.Path AS STRING(1024)) AS Path
	|INTO Files
	|FROM
	|	&Files AS Files");  
	
	Query.TempTablesManager = TableManager;
	Query.SetParameter("Files", TableFiles);
	Query.Execute();
	
	QueryPartsForFoundFiles = New Array;
	
	QueryHeaderForFoundFiles = "SELECT
	|	"""" AS Path
	|INTO ExistingFiles
	|WHERE 
	|	FALSE";
	QueryPartsForFoundFiles.Add(QueryHeaderForFoundFiles);
	
	QueryTemplateForFoundFiles = "
	|SELECT
	|	Files.Path AS Path
	|FROM
	|	Files AS Files
	|	INNER JOIN &AttachedFilesCatalog AS AttachedFiles
	|		ON AttachedFiles.Volume IN (&Volumes)
	|		AND CAST(AttachedFiles.PathToFile AS STRING(1024)) = Files.Path";
	
	AttachedFilesTypes = Metadata.DefinedTypes.AttachedFile.Type.Types();
	For Each Type In AttachedFilesTypes Do
		MetadataAttachedFiles = Metadata.FindByType(Type);
		QueryText = StrReplace(QueryTemplateForFoundFiles, "&AttachedFilesCatalog", MetadataAttachedFiles.FullName());
		QueryPartsForFoundFiles.Add(QueryText);
	EndDo;
	
	Separator = "
	|UNION ALL
	|";
	
	QueryText = StrConcat(QueryPartsForFoundFiles, Separator);
	
	QueryText = QueryText + Common.QueryBatchSeparator() + "
	|SELECT 
	|	Files.Path AS Path
	|FROM
	|	Files AS Files
	|WHERE
	|	NOT Files.Path IN (
	|		SELECT
	|			ExistingFiles.Path AS Path
	|		FROM
	|			ExistingFiles AS ExistingFiles)";

	Query = New Query(QueryText);
	Query.TempTablesManager = TableManager;
	Return Query;
EndFunction

Function QueryExistingFilesWithRestoredLinks(Val TableFiles)
	TableManager = New TempTablesManager();
	Query = New Query("SELECT
	|	CAST(Files.AlternativePath AS STRING(1024)) AS AlternativePath,
	|	CAST(Files.ShouldUseAlternativePath AS BOOLEAN) AS ShouldUseAlternativePath,
	|	CAST(Files.Path AS STRING(1024)) AS Path
	|INTO Files
	|FROM
	|	&Files AS Files");  
	
	Query.TempTablesManager = TableManager;
	Query.SetParameter("Files", TableFiles);
	Query.Execute();
	
	QueryPartsForFoundFiles = New Array;

	QueryHeaderForFoundFiles = "SELECT
	|	FALSE AS IsAlternativePathUsed,
	|	VALUE(Catalog.Files.EmptyRef) AS Ref,
	|	"""" AlternativePath,
	|	"""" AS Path
	|INTO ExistingFiles
	|WHERE 
	|	FALSE";
	QueryPartsForFoundFiles.Add(QueryHeaderForFoundFiles);

	QueryTemplateForFoundFiles = "
	|SELECT
	|	Files.ShouldUseAlternativePath AS IsAlternativePathUsed,
	|	AttachedFiles.Ref,
	|	Files.AlternativePath,
	|	Files.Path AS Path
	|FROM
	|	Files AS Files
	|	INNER JOIN &AttachedFilesCatalog AS AttachedFiles
	|		ON AttachedFiles.Volume IN (&Volumes)
	|		AND ((NOT Files.ShouldUseAlternativePath AND CAST(AttachedFiles.PathToFile AS STRING(1024)) = Files.Path)
	|			OR (Files.ShouldUseAlternativePath AND CAST(AttachedFiles.PathToFile AS STRING(1024)) = Files.AlternativePath))";
	
	AttachedFilesTypes = Metadata.DefinedTypes.AttachedFile.Type.Types();
	For Each Type In AttachedFilesTypes Do
		MetadataAttachedFiles = Metadata.FindByType(Type);
		QueryText = StrReplace(QueryTemplateForFoundFiles, "&AttachedFilesCatalog", MetadataAttachedFiles.FullName());
		QueryPartsForFoundFiles.Add(QueryText);
	EndDo;
	
	Separator = "
	|UNION ALL
	|";
	
	QueryText = StrConcat(QueryPartsForFoundFiles, Separator);
	
	QueryText = QueryText + Common.QueryBatchSeparator() + 
	"SELECT
	|	ExistingFiles.Ref AS File,
	|	ExistingVersionFiles.Ref AS Version
	|INTO VersionFiles
	|FROM
	|	ExistingFiles AS ExistingFiles
	|		INNER JOIN ExistingFiles AS ExistingVersionFiles
	|		ON (CASE
	|				WHEN TYPE(Catalog.FilesVersions) = VALUETYPE(ExistingVersionFiles.Ref)
	|						AND CAST(ExistingVersionFiles.Ref AS Catalog.FilesVersions).Owner = ExistingFiles.Ref
	|					THEN TRUE
	|				ELSE FALSE
	|			END)
	|			AND ExistingFiles.Path = ExistingVersionFiles.Path
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExistingFiles.Path AS Path
	|INTO UniqueLinks
	|FROM
	|	ExistingFiles AS ExistingFiles
	|		LEFT JOIN VersionFiles AS VersionFiles
	|		ON (ExistingFiles.Ref = VersionFiles.File
	|				OR ExistingFiles.Ref = VersionFiles.Version)
	|
	|GROUP BY
	|	ExistingFiles.Path
	|
	|HAVING
	|	SUM(CASE
	|			WHEN ExistingFiles.Ref = ISNULL(VersionFiles.File, ExistingFiles.Ref)
	|				THEN 1
	|			ELSE 0
	|		END) = 1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Files.Path AS Path
	|FROM
	|	Files AS Files
	|WHERE
	|	NOT Files.Path IN
	|				(SELECT
	|					UniqueLinks.Path AS Path
	|				FROM
	|					UniqueLinks AS UniqueLinks)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExistingFiles.Path AS FullName,
	|	ExistingFiles.Ref AS File
	|FROM
	|	ExistingFiles AS ExistingFiles
	|WHERE
	|	ExistingFiles.IsAlternativePathUsed = TRUE
	|	AND ExistingFiles.Path IN
	|			(SELECT
	|				UniqueLinks.Path AS Path
	|			FROM
	|				UniqueLinks AS UniqueLinks)";

	Query = New Query(QueryText);
	Query.TempTablesManager = TableManager;
	Return Query;
EndFunction

Function FilesForDeletion(Directory, TimeOfLastCleaning)
	FilesForDeletion = New Array;
	
	CatalogDescription_ = New File(Directory);
	CheckFilesInTheCurrentDirectory = TimeOfLastCleaning <= CatalogDescription_.GetModificationUniversalTime();
	For Each File In FindFiles(Directory, GetAllFilesMask(), False) Do
		If File.IsDirectory() Then
			CommonClientServer.SupplementArray(
				FilesForDeletion,
				FilesForDeletion(File.FullName, TimeOfLastCleaning));
		Else
			If CheckFilesInTheCurrentDirectory And Not File.IsDirectory() Then
				FilesForDeletion.Add(File.FullName);
			EndIf;
		EndIf;
	EndDo;
	
	Return FilesForDeletion;
EndFunction

// It is called before the transaction start.
// All these files must be filled in for new files.
// 
// Parameters:
//  Context - See FilesOperationsInternal.FileUpdateContext
//
Procedure BeforeUpdatingTheFileData(Context) Export
	Context.AttributesToChange.Insert("PathToFile", "");
	Context.AttributesToChange.Insert("Volume", Catalogs.FileStorageVolumes.EmptyRef());
	If Not Context.IsNew Then
		FileProperties = FilePropertiesInVolume(Context.AttachedFile);
		Context.OldFilePath = FullFileNameInVolume(FileProperties);
	EndIf;
	
	FilePropertiesContainer = FileAddingOptions();
	FilePropertiesContainer.Ref = Context.AttachedFile;
	FillPropertyValues(FilePropertiesContainer, Context.FileAddingOptions,,"Ref");
	FilePropertiesContainer.PathToFile = ""; // Always create a new version in the volume without overwriting the old one.
	
	SetSafeModeDisabled(True);
	AppendFile(FilePropertiesContainer, Context.FileData);
	SetSafeModeDisabled(False);
	
	Context.AttributesToChange.PathToFile = FilePropertiesContainer.PathToFile;
	Context.AttributesToChange.Volume = FilePropertiesContainer.Volume;
EndProcedure

// It is called in a modification transaction.
// Parameters:
//  Context - See FilesOperationsInternal.FileUpdateContext
//  AttachedFile - DefinedType.AttachedFileObject
//
Procedure BeforeWritingFileData(Context, AttachedFile) Export
	FillPropertyValues(AttachedFile, Context.AttributesToChange);
EndProcedure

// It is called in a modification transaction.
// Parameters:
//  Context - See FilesOperationsInternal.FileUpdateContext
//  AttachedFile - DefinedType.AttachedFile
//
Procedure WhenUpdatingFileData(Context, AttachedFile) Export
	Return; // Obsolete.
EndProcedure

// It is called after the transaction is committed or rolled back.
// 
// Parameters:
//  Context - See FilesOperationsInternal.FileUpdateContext
//  Success - Boolean - True if the transaction is successfully committed.
//
Procedure AfterUpdatingTheFileData(Context, Success) Export
	If Not Success Then
		FileProperties = FilePropertiesInVolume();
		FillPropertyValues(FileProperties, Context.FileAddingOptions);
		FillPropertyValues(FileProperties, Context.AttributesToChange);
		NewFilePath = FullFileNameInVolume(FileProperties);
		DeletedFile = New File(NewFilePath);
		If DeletedFile.Exists() Then
			DeleteFile(NewFilePath);			
		EndIf;
	Else
		AttachedFile = Context.AttachedFile;
		ThisIsTheVersion = TypeOf(AttachedFile) = Type("CatalogRef.FilesVersions");
		MainFile = ?(ThisIsTheVersion, Common.ObjectAttributeValue(AttachedFile, "Owner"), AttachedFile);
		ThisIsAnEncryptedFile = Common.HasObjectAttribute("Encrypted", MainFile.Metadata())
			And Common.ObjectAttributeValue(MainFile, "Encrypted");
			
		// Always try to delete the old file if it's encrypted (the external transactions is active).
		//  
		// See FilesOperationsInternal.WriteEncryptionInformation
		If ThisIsAnEncryptedFile Or Not TransactionActive() Then
			
			FileProperties = FilePropertiesInVolume(AttachedFile);
			NewFilePath = FullFileNameInVolume(FileProperties);
			
			If NewFilePath <> Context.OldFilePath Then

				SetSafeModeDisabled(True);
				DeleteFile(Context.OldFilePath);
				SetSafeModeDisabled(False);

			EndIf;
		EndIf;
	EndIf;
EndProcedure

// Parameters:
//  FilesForDeletion - Array of String - Full file path.
// 
// Returns:
//  Structure:
//   * Total - Number
//   * Deleted - Number
//   * DeletionErrors - Array of Structure:
//   * Error - String - Error details.
//   * Name - String - Filename.
// 
Function DeleteVolumesFiles(FilesForDeletion) Export
	Result = New Structure;
	Result.Insert("Total", FilesForDeletion.Count());
	Result.Insert("Deleted", 0);
	Result.Insert("DeletionErrors", New Array);
	
	For Each File In FilesForDeletion Do
		DeletionResult = DeleteFile(File);
		If DeletionResult.Success Then
			Result.Deleted = Result.Deleted + 1;
		Else
			Error = New Structure;
			Error.Insert("Error", DeletionResult.ErrorInfo);
			Error.Insert("Name", DeletionResult.Name);
			Result.DeletionErrors.Add(Error);
		EndIf; 
	EndDo;
	
	Return Result;
EndFunction

#Region FilesStorageInVolumesSettings

// Returns a flag that files can be stored in volumes and in the infobase.
//
// Returns:
//   Boolean
//
Function StoreFIlesInVolumesOnHardDriveAndInInfobase()
	
	SetPrivilegedMode(True);
	Return Constants.FilesStorageMethod.Get() = "InInfobaseAndVolumesOnHardDrive";
	
EndFunction

// Returns a flag that files in volumes are stored in subdirectories with the owner name.
//
// Returns:
//   Boolean
//
Function CreateSubdirectoriesWithOwnersNames()
	
	SetPrivilegedMode(True);
	Return Constants.CreateSubdirectoriesWithOwnersNames.Get();
	
EndFunction

#EndRegion

#Region DataExchange

// Puts the binary file data from the volume into internal attribute FileStorage.
//
// Parameters:
//   DataElement - CatalogObject.FilesVersions
//                 - DefinedType.AttachedFile
// 
Procedure PutFileInCatalogAttribute(DataElement) Export
	
	FileData = FileData(DataElement.Ref, False);
	
	DataElement.Volume = Catalogs.FileStorageVolumes.EmptyRef();
	DataElement.PathToFile = "";
	DataElement.FileStorage = New ValueStorage(FileData);
	DataElement.FileStorageType = Enums.FileStorageTypes.InInfobase;
	
EndProcedure

// Adds files to volumes and sets references in FileVersions.
//
Procedure AddFilesToVolumes(WindowsArchivePath, PathToArchiveLinux) Export
	
	FullFileNameZip = "";
	If Common.IsWindowsServer() Then
		FullFileNameZip = WindowsArchivePath;
	Else
		FullFileNameZip = PathToArchiveLinux;
	EndIf;
	
	DirectoryName = FileSystem.CreateTemporaryDirectory();
	CreateDirectory(DirectoryName);
	
	ZipFile = New ZipFileReader(FullFileNameZip);
	ZipFile.ExtractAll(DirectoryName, ZIPRestoreFilePathsMode.DontRestore);
	
	FilesPathsMap = New Map;
	
	For Each ZIPItem In ZipFile.Items Do
		FullFilePath1 = DirectoryName + "\" + ZIPItem.Name;
		// For filename generation,
		CatalogUUID = ZIPItem.Name;
		
		FilesPathsMap.Insert(CatalogUUID, FullFilePath1);
	EndDo;
	
	BeginTransaction();
	Try
		AddFilesToVolumesOnPlace(FilesPathsMap, FilesOperationsInternal.FilesStorageTyoe());
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	FileSystem.DeleteTemporaryDirectory(DirectoryName);
	
EndProcedure

// Adds a file to volumes when executing the "store initial image files" command.
//
// Parameters:
//   FilesPathsMap - Map - mapping of the UUID of the file and the path to the file.
//   FileStorageType        - EnumRef.FileStorageTypes - file storage type.
//
Procedure AddFilesToVolumesOnPlace(FilesPathsMap, FileStorageType)
		
	For Each FileInformationPath In FilesPathsMap Do
		
		FullPathNew = "";
		FileInfo1 = FileInformationFromTheName(FileInformationPath.Key);
		If Not FileInfo1.Full_ Then
			Continue;
		EndIf;
		
		FileRef = Catalogs[FileInfo1.CatalogName].GetRef(FileInfo1.UUID);
		If FileRef.IsEmpty() Then
			Continue;
		EndIf;
		
		FullFilePathOnHardDrive = FileInformationPath.Value;
		
		BeginTransaction();
		Try
			
			DataLock = New DataLock;
			DataLockItem = DataLock.Add("Catalog." + FileInfo1.CatalogName);
			DataLockItem.SetValue("Ref", FileRef);
			DataLock.Lock();
			
			Object = FileRef.GetObject(); // DefinedType.AttachedFileObject
			Object.FileStorageType = FilesOperationsInternal.FileStorageType(Object.Size, Object.Extension);
			
			If FileStorageType = Enums.FileStorageTypes.InInfobase Then
				
				// In the destination, files must be stored within the infobase.
				// Therefore, save them to the infobase even if originally they are stored in volumes.
				
				Object.Volume = Catalogs.FileStorageVolumes.EmptyRef();
				Object.PathToFile = "";
				Object.FileStorageType = Enums.FileStorageTypes.InInfobase;
				
				BinaryData = New BinaryData(FullFilePathOnHardDrive);
				FilesOperationsInternal.WriteFileToInfobase(Object.Ref, BinaryData);
				
			Else
				
				// In the destination base, files must be stored in volumes. Move the unzipped file to the volume.
				FileSource = New File(FullFilePathOnHardDrive);
				FileName = CommonClientServer.GetNameWithExtension(Object.Description, Object.Extension);
				Common.ShortenFileName(FileName);
				FullPathNew = FileSource.Path + FileName;
				MoveFile(FullFilePathOnHardDrive, FullPathNew);
				
				AppendFile(Object, FullPathNew);
				
			EndIf;
			
			Object.AdditionalProperties.Insert("FilePlacementInVolumes", True); // 
			InfobaseUpdate.WriteObject(Object);
			
			CommitTransaction();
			
		Except
			RollbackTransaction();
		EndTry;
		
		If Not IsBlankString(FullPathNew) Then
			DeleteFiles(FullPathNew);
		EndIf;

	EndDo;
	
EndProcedure

Function FileInformationFromTheName(FileName)
	FileInfo1 = New Structure;
	FileInfo1.Insert("CatalogName", "");
	FileInfo1.Insert("UUID", "");
	FileInfo1.Insert("Full_", False);
	
	NameParts = StrSplit(FileName, ".");
	If NameParts.Count() = 2 Then
		CatalogName = NameParts[0];
		FileInfo1.CatalogName = ?(Metadata.Catalogs.Find(CatalogName) = Undefined, "", CatalogName);
		FileInfo1.UUID = New UUID(NameParts[1]);
		FileInfo1.Full_ = ValueIsFilled(FileInfo1.CatalogName) And ValueIsFilled(FileInfo1.UUID);
	EndIf;
		
	Return FileInfo1;
EndFunction

#EndRegion

#Region CleanUpUnusedFiles

// Constructor of a table with unreferenced  files in volumes.
// 
// Returns:
//   ValueTable:
//      * Name                - String
//      * File               - String
//      * BaseName   - String
//      * FullName          - String
//      * Path               - String
//      * Volume                - String
//      * Extension         - String
//      * CheckStatus     - String - "OK", "UnnecessaryFileInVolume", "NoFileInVolume", "FixingPossible"
//      * Count         - String
//      * WasEditedBy     - String
//      * EditDate - String
//
Function UnnecessaryFilesOnHardDrive() Export
	FilesTableOnHardDrive = New ValueTable;
	
	FilesTableOnHardDrive.Columns.Add("Name");
	FilesTableOnHardDrive.Columns.Add("File");
	FilesTableOnHardDrive.Columns.Add("BaseName");
	FilesTableOnHardDrive.Columns.Add("FullName");
	FilesTableOnHardDrive.Columns.Add("Path");
	FilesTableOnHardDrive.Columns.Add("Volume");
	FilesTableOnHardDrive.Columns.Add("Extension");
	FilesTableOnHardDrive.Columns.Add("CheckStatus");
	FilesTableOnHardDrive.Columns.Add("Count");
	FilesTableOnHardDrive.Columns.Add("WasEditedBy");
	FilesTableOnHardDrive.Columns.Add("EditDate");

	FilesTableOnHardDrive.Indexes.Add("FullName");
	FilesTableOnHardDrive.Indexes.Add("CheckStatus");
	
	Return FilesTableOnHardDrive;
EndFunction

// Parameters:
//   FilesTableOnHardDrive - See FilesOperationsInVolumesInternal.UnnecessaryFilesOnHardDrive
//   Volume                  - CatalogRef.FileStorageVolumes - volume reference.
//
Procedure FillInExtraFiles(FilesTableOnHardDrive, Volume) Export
	
	FilesTypes = Metadata.DefinedTypes.AttachedFile.Type.Types();
	
	Query = New Query;
	FirstRequestText = True;
	For Each FilesCatalog In FilesTypes Do
		
		CatalogMetadata = Metadata.FindByType(FilesCatalog);
		IsVersionsCatalog = Common.HasObjectAttribute("ParentVersion", CatalogMetadata);
		
		QueryFragment = 
		"SELECT
		|	CatalogAttachedFiles.Ref,
		|	&FileOwner AS FileOwner,
		|	CatalogAttachedFiles.Extension,
		|	CatalogAttachedFiles.Description,
		|	CatalogAttachedFiles.Volume,
		|	&WasEditedBy AS WasEditedBy,
		|	CatalogAttachedFiles.UniversalModificationDate AS FileModificationDate,
		|	CatalogAttachedFiles.PathToFile,
		|	CatalogAttachedFiles.DeletionMark
		|FROM
		|	&CatalogAttachedFiles AS CatalogAttachedFiles
		|WHERE
		|	CatalogAttachedFiles.Volume = &Volume
		|	AND CatalogAttachedFiles.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)
		|	AND &ConditionCurrentVersion";
		
		QueryFragment = StrReplace(QueryFragment, "&FileOwner", 
			"CatalogAttachedFiles." + ?(IsVersionsCatalog, "Owner.FileOwner", "FileOwner"));
		QueryFragment = StrReplace(QueryFragment, "&WasEditedBy", 
			"CatalogAttachedFiles." + ?(IsVersionsCatalog, "Author", "ChangedBy"));
		QueryFragment = StrReplace(QueryFragment, "&CatalogAttachedFiles", 
			"Catalog." + CatalogMetadata.Name);
		
		If Not IsVersionsCatalog
			And Common.HasObjectAttribute("CurrentVersion", CatalogMetadata) Then
			
			FilesVersionsCatalog = Metadata.FindByType(
				CatalogMetadata.Attributes.CurrentVersion.Type.Types()[0]);
			QueryFragment = StrReplace(QueryFragment, "&ConditionCurrentVersion",
				"CatalogAttachedFiles.CurrentVersion = VALUE(Catalog."
				+ FilesVersionsCatalog.Name + ".EmptyRef)");
			
		Else
			QueryFragment = StrReplace(QueryFragment, "&ConditionCurrentVersion", "TRUE");
		EndIf;
		
		Query.Text = Query.Text + ?(FirstRequestText,"", "
			|UNION ALL
			|") + QueryFragment;
		
		FirstRequestText = False;
		
	EndDo;
	
	Query.SetParameter("Volume", Volume);
	Selection = Query.Execute().Select();
	
	FileProperties = FilePropertiesInVolume();
	FileProperties.Volume = Volume; 
	
	FullVolumePath = FullVolumePath(Volume);
	VolumeFileSystemProperties =  FileSystemProperties(FullVolumePath);
	
	While Selection.Next() Do
		
		VersionRef = Selection.Ref;
		PathToFile   = Selection.PathToFile;
		
		If ValueIsFilled(Selection.PathToFile)
			And ValueIsFilled(Selection.Volume) Then
			
			FileProperties.PathToFile = PathToFile;
			
			FullFilePath1 = FullFileNameInVolume(FileProperties);
			ExistingFile = FilesTableOnHardDrive.FindRows(New Structure("FullName", FullFilePath1));
			
			ShouldSearchUsingAlternativePath = False;
			
			If ExistingFile.Count() = 0 And (Not VolumeFileSystemProperties.HasFilenameTrailingDot
				Or Not VolumeFileSystemProperties.HasFilenameLeadingWhitespace) Then
				
				If Not VolumeFileSystemProperties.HasFilenameTrailingDot And Right(PathToFile, 1) = "." Then
					PathToFile = Left(PathToFile, StrLen(PathToFile)-1);
				EndIf;
				
				If Not VolumeFileSystemProperties.HasFilenameLeadingWhitespace And StrFind(PathToFile, GetPathSeparator()+" ") > 0 Then
					FileParameters = New File(PathToFile);
					PathToFile = FileParameters.Path+TrimAll(FileParameters.Name);
				EndIf;
				
				If Selection.PathToFile <> PathToFile Then
					FileProperties.PathToFile = PathToFile;
				
					FullFilePath1 = FullFileNameInVolume(FileProperties);
					ExistingFile = FilesTableOnHardDrive.FindRows(New Structure("FullName", FullFilePath1));
					ShouldSearchUsingAlternativePath = True;
				EndIf;
			EndIf;
			
			If ExistingFile.Count() = 0 Then
				NonExistingFile = FilesTableOnHardDrive.Add();
				NonExistingFile.File = VersionRef;
				NonExistingFile.FullName = FullFilePath1;
				NonExistingFile.Extension = Selection.Extension;
				NonExistingFile.Name = Selection.Description;
				NonExistingFile.Volume = Volume;
				NonExistingFile.WasEditedBy = Selection.WasEditedBy;
				NonExistingFile.EditDate = Selection.FileModificationDate;
				NonExistingFile.Count = 1;
				NonExistingFile.CheckStatus = ?(Selection.DeletionMark, "OK", "NoFileInVolume");
			ElsIf ShouldSearchUsingAlternativePath Then
				ExistingFile[0].File = VersionRef;
				ExistingFile[0].CheckStatus = "FixingPossible";
				ExistingFile[0].EditDate = Selection.FileModificationDate;
				ExistingFile[0].Count = 1;
				ExistingFile[0].WasEditedBy = Selection.WasEditedBy;
			Else
				ExistingFile[0].File = VersionRef;
				ExistingFile[0].CheckStatus = "OK";
			EndIf;
			
		EndIf;
		
	EndDo;

EndProcedure

// For the VolumeIntegrityCheck DCS report.
Function ViewStatusChecks(Val CheckStatus) Export
	If CheckStatus = "OK" Then
		Return NStr("en = 'Data integrity check passed';");
	ElsIf CheckStatus = "ExtraFileInTome" Then 
		Return NStr("en = 'Unreferenced files (files in the volume that have no entries in the application)';");
	ElsIf CheckStatus = "NoFileInVolume" Then
		Return NStr("en = 'No files in the volume';");
	ElsIf CheckStatus = "FixingPossible" Then
		Return NStr("en = 'Corrupted file info';");
	EndIf;
EndFunction

#EndRegion

#Region AccountingAudit

Function AvailableVolumes(CheckParameters = Undefined) Export
	
	Query = New Query(
	"SELECT
	|	FileStorageVolumes.Ref AS VolumeRef,
	|	FileStorageVolumes.Description AS VolumePresentation,
	|	CASE
	|		WHEN &IsWindowsServer
	|			THEN FileStorageVolumes.FullPathWindows
	|		ELSE FileStorageVolumes.FullPathLinux
	|	END AS FullPath
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes");
	Query.SetParameter("IsWindowsServer", Common.IsWindowsServer());
	Result = Query.Execute().Select();
	
	AvailableVolumes = New Array;
	While Result.Next() Do
		
		If VolumeAvailable(Result.VolumeRef, Result.VolumePresentation, Result.FullPath, CheckParameters) Then
			AvailableVolumes.Add(Result.VolumeRef);
		EndIf;
		
	EndDo;
	
	Return AvailableVolumes;
	
EndFunction

Function VolumeAvailable(Volume, VolumePresentation, Path, CheckParameters)
	
	If IsBlankString(Path) Then
		
		IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t save files to file storage volume ""%1"" as it does not have a path to the network directory.';"), 
			VolumePresentation);
		WriteVolumeIssue(Volume, IssueSummary, CheckParameters);
		Return False;
		
	EndIf;
		
	TestDirectoryName = Path + "CheckAccess" + GetPathSeparator();
	
	Try
		CreateDirectory(TestDirectoryName);
		DeleteFiles(TestDirectoryName);
	Except
		
		IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'File storage volume ""%1"" is unavailable. Reason:
				|%2
				|
				|The network directory might be unavailable, or you have insufficient access rights.
				|Cannot access the files stored in the volume.';"),
				Path, ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		IssueSummary = IssueSummary + Chars.LF;
		WriteVolumeIssue(Volume, IssueSummary, CheckParameters);
		Return False;
		
	EndTry;
	
	Return True;
	
EndFunction

Procedure WriteVolumeIssue(Volume, IssueSummary, CheckParameters)
	
	If CheckParameters = Undefined Then
		Return;
	EndIf;
	
	ModuleAccountingAudit = Common.CommonModule("AccountingAudit");
	
	Issue1 = ModuleAccountingAudit.IssueDetails(Volume, CheckParameters);
	Issue1.IssueSummary = IssueSummary;
	ModuleAccountingAudit.WriteIssue(Issue1, CheckParameters);
	
EndProcedure

Procedure SearchRefsToNonExistingFilesInVolumes(MetadataObject, CheckParameters, AvailableVolumes)
	
	ModuleAccountingAudit = Common.CommonModule("AccountingAudit");
	
	QueryText =
	"SELECT TOP 1000
	|	MetadataObject.Ref AS ObjectWithIssue,
	|	&OwnerField AS Owner,
	|	REFPRESENTATION(MetadataObject.Ref) AS File,
	|	REFPRESENTATION(MetadataObject.Volume) AS Volume,
	|	MetadataObject.PathToFile AS PathToFile,
	|	MetadataObject.Volume AS VolumeRef1,
	|	&Author AS Author
	|FROM
	|	&MetadataObject AS MetadataObject
	|WHERE
	|	MetadataObject.Ref > &Ref
	|	AND MetadataObject.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)
	|	AND MetadataObject.Volume IN(&AvailableVolumes)
	|
	|ORDER BY
	|	MetadataObject.Ref";
	
	FullName = MetadataObject.FullName();
	QueryText = StrReplace(QueryText, "&MetadataObject", FullName);
	
	If MetadataObject.Attributes.Find("Author") <> Undefined Then
		QueryText = StrReplace(QueryText, "&Author", "MetadataObject.Author");
	Else
		QueryText = StrReplace(QueryText, "&Author", "NULL");
	EndIf;
		
	// @query-part-2
	OwnerField = ?(FullName = "Catalog.FilesVersions", "REFPRESENTATION(MetadataObject.Owner) ","Undefined ");
	QueryText = StrReplace(QueryText, "&OwnerField", OwnerField);
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Catalogs.FileStorageVolumes.EmptyRef());
	Query.SetParameter("AvailableVolumes", AvailableVolumes);
	Result = Query.Execute().Unload();
	While Result.Count() > 0 Do
		
		For Each ResultString1 In Result Do
			
			FilePropertiesInVolume = New Structure("Volume, PathToFile",
				ResultString1.VolumeRef1, ResultString1.PathToFile);
			
			PathToFile = FullFileNameInVolume(FilePropertiesInVolume);
			If Not ValueIsFilled(PathToFile) Then
				Continue;
			EndIf;
			
			FileToCheck = New File(PathToFile);
			If FileToCheck.Exists() Then
				Continue;
			EndIf;
				
			ObjectReference = ResultString1.ObjectWithIssue;
			If ResultString1.Owner <> Undefined Then
				IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Version ""%1"" of file ""%2"" does not exist in volume ""%3.""';"),
					ResultString1.File, ResultString1.Owner, ResultString1.Volume);
			Else
				IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'File ""%1"" does not exist in volume ""%2.""';"),
					ResultString1.File, ResultString1.Volume);
			EndIf;
			
			Issue1 = ModuleAccountingAudit.IssueDetails(ObjectReference, CheckParameters);
			
			Issue1.IssueSummary = IssueSummary;
			If ValueIsFilled(ResultString1.Author) Then
				Issue1.Insert("EmployeeResponsible", ResultString1.Author);
			EndIf;
			
			ModuleAccountingAudit.WriteIssue(Issue1, CheckParameters);
			
		EndDo;
		
		Query.SetParameter("Ref", ResultString1.ObjectWithIssue);
		// @skip-check query-in-loop - Batch processing of data
		Result = Query.Execute().Unload();
		
	EndDo;
	
EndProcedure

Function CheckAttachedFilesObject(MetadataObject)
	
	If StrEndsWith(MetadataObject.Name, FilesOperationsInternal.CatalogSuffixAttachedFiles())
		Or MetadataObject.FullName() = "Catalog.FilesVersions" Then
		
		Return MetadataObject.Attributes.Find("PathToFile") <> Undefined
			And MetadataObject.Attributes.Find("Volume") <> Undefined;
		
	Else
		Return False;
	EndIf;
	
EndFunction

#EndRegion

#Region InfobaseUpdate

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.SharedData = True;
	Handler.Procedure = "FilesOperationsInVolumesInternal.SetTheWayToFormTheVolumePath";
	Handler.ExecutionMode = "Seamless";
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.SharedData = True;
	Handler.Procedure = "FilesOperationsInVolumesInternal.UpdateVolumePathLinux";
	Handler.ExecutionMode = "Seamless";
	
	Handler = Handlers.Add();
	Handler.Version = "3.1.2.65";
	Handler.SharedData = True;
	Handler.Procedure = "FilesOperationsInVolumesInternal.FillFilesStorageSettings";
	Handler.ExecutionMode = "Seamless";
	Handler.InitialFilling = True;
	
	Handler = Handlers.Add();
	Handler.Version = "3.1.8.331";
	Handler.Procedure = "Catalogs.FilesVersions.ProcessVersionStoragePath";
	Handler.ExecutionMode = "Deferred";
	Handler.Comment = NStr("en = 'Fixes incorrect file storage paths in a volume.';");
	Handler.Id = New UUID("06354049-b702-4f27-8e99-f49b86f7f152");
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ObjectsToLock = "Catalog.FilesVersions";
	Handler.UpdateDataFillingProcedure = "Catalogs.FilesVersions.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ObjectsToRead = "Catalog.FilesVersions";
	Handler.ObjectsToChange = "Catalog.FilesVersions";
	
EndProcedure

// Sets the FilesStorageMethod constant value depending on the StoreFilesInVolumesOnHardDrive constant
// value and initializes the ParametersOfFilesStorageInIB constant.
//
Procedure FillFilesStorageSettings() Export
	
	Constants.FilesStorageMethod.Set(
		?(Constants.StoreFilesInVolumesOnHardDrive.Get(),
		"InVolumesOnHardDrive", "InInfobase"));
		
	SetFilesStorageParametersInInfobase(
		New Structure("FilesExtensions, MaximumSize", "", 0));
	
EndProcedure

Procedure UpdateVolumePathLinux() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileStorageVolumes.Ref
		|FROM
		|	Catalog.FileStorageVolumes AS FileStorageVolumes
		|WHERE
		|	FileStorageVolumes.FullPathLinux LIKE ""%/\"" ESCAPE ""~""";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		BeginTransaction();
		Try
			
			DataLock = New DataLock;
			DataLockItem = DataLock.Add("Catalog.FileStorageVolumes");
			DataLockItem.SetValue("Ref", Selection.Ref);
			DataLock.Lock();
			
			Volume = Selection.Ref.GetObject(); // CatalogObject.FileStorageVolumes
			Volume.FullPathLinux = StrReplace(Volume.FullPathLinux , "/\", "/");
			Volume.Write();
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process file storage volume %1. Reason:
				|%2';"), 
				Selection.Ref, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Selection.Ref.Metadata(), Selection.Ref, MessageText);
			
		EndTry;
		
	EndDo;
	
EndProcedure

// For the function, See FullVolumePath
//
Procedure SetTheWayToFormTheVolumePath() Export
	Constants.VolumePathIgnoreRegionalSettings.Set(True);
EndProcedure

#EndRegion

#Region AuxiliaryProceduresAndFunctions

// Returns the name of the subdirectory in the volume by the file owner type.
// The subdirectory name is generated as a concatenation of the first 30 characters of the name
// of the file owner metadata object + CRC32 hash from the remaining characters.
//
// Parameters:
//   FileOwner - DefinedType.AttachedFilesOwner
//                 - DefinedType.FilesOwner - reference to
//                 the file owner whose metadata is used to form the subdirectory name.
//
// Returns:
//   String - a directory name.
//
Function FileOwnerDirectoryName(FileOwner)
	
	If Not ValueIsFilled(FileOwner) Then
		Return "";
	EndIf;
	
	MetadataObjectName = FileOwner.Metadata().Name;
	If StrLen(MetadataObjectName) > 30 Then
		RemainderHash = New DataHashing(HashFunction.CRC32);
		RemainderHash.Append(Mid(MetadataObjectName, 31));
		RemainderHashSum = RemainderHash.HashSum;
	Else
		RemainderHashSum = "";
	EndIf;
	
	Return Left(MetadataObjectName, 30) + RemainderHashSum;
	
EndFunction

// Returns a storage type of the uploaded file depending on its extension and size.
// 
// Parameters:
//   FileSize - Number - a size of the file to be added in bytes.
//   FileExtention - String - an extension of the file being added.
//
// Returns:
//   EnumRef.FileStorageTypes - If the file storage method in the settings is InVolumesOnHardDrive,
//      the return value is InVolumesOnHardDrive. If the file storage method is
//       InInfobaseAndVolumesOnHardDrive, the return value is InInfobase
//      when the file matches the infobase storage parameters. Otherwise, the return value is InVolumesOnHardDrive.
//
Function FileStorageType(Val FileSize, Val FileExtention) Export
	
	StorageType = Enums.FileStorageTypes.InVolumesOnHardDrive;
	If StoreFIlesInVolumesOnHardDriveAndInInfobase() Then
		
		StorageParameters = FilesStorageParametersInInfobase();
		If FileSize <= StorageParameters.MaximumSize Then
			StorageType = Enums.FileStorageTypes.InInfobase;
		Else
			FileExtention = Lower(TrimAll(FileExtention));
			If StrStartsWith(FileExtention, ".") Then
				FileExtention = Mid(FileExtention, 2, StrLen(FileExtention) - 1);
			EndIf;
			If StrFind(Lower(StorageParameters.FilesExtensions), FileExtention) > 0 Then
				StorageType = Enums.FileStorageTypes.InInfobase;
			EndIf;
		EndIf;
		
	EndIf;
	
	Return StorageType;
	
EndFunction

// Returns the first volume, to which you can place the specified file, in the filling order.
//
// Parameters:
//   AttachedFile - DefinedType.AttachedFileObject
//                      - See FilesOperationsInVolumesInternal.FileAddingOptions
//
// Returns:
//   CatalogRef.FileStorageVolumes
//
Function FreeVolume(AttachedFile)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	FileStorageVolumes.Ref AS Ref,
	|	FileStorageVolumes.MaximumSize AS MaximumSize
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes
	|WHERE
	|	FileStorageVolumes.DeletionMark = FALSE
	|
	|ORDER BY
	|	FileStorageVolumes.FillOrder";
	Result = Query.Execute();
	If Result.IsEmpty() Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot add the %1 file 
				|as no file storage volume is configured.
				|Contact the administrator.';"),
			AttachedFile.Description + "." + AttachedFile.Extension);
	EndIf;
	
	FileStorageVolumes = Result.Unload();
	SizesOfVolumes = Undefined;
	
	For Each FileStorageVolume In FileStorageVolumes Do
		
		If FileStorageVolume.MaximumSize = 0 Then
			Return FileStorageVolume.Ref;
		EndIf;

		If SizesOfVolumes = Undefined Then
			// @skip-check query-in-loop - One-time call
			SizesOfVolumes = SizesOfVolumes(FileStorageVolumes.UnloadColumn("Ref"));
		EndIf;
		VolumeSize = SizesOfVolumes[FileStorageVolume.Ref];
		If VolumeSize + AttachedFile.Size <= FileStorageVolume.MaximumSize * 1024 * 1024 Then
			Return FileStorageVolume.Ref;
		EndIf;
		
	EndDo;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
	NStr("en = 'Cannot add the %1 file 
		|as the file storage volumes do not have enough space.
		|Contact the administrator.';"),
		AttachedFile.Description + "." + AttachedFile.Extension);
	Raise ErrorText;	
	
EndFunction

Function FileSystemProperties(Directory)
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	TestDirName = Directory + "CheckAccess"+Format(CurrentSessionDate(), "DF=ddMMyy_HHmmss;");
	TestFileName = TestDirName + GetPathSeparator() + " FileNameCheck.";
	CreateDirectory(TestDirName);
	
	TextFile = New TextDocument;
	TextFile.Write(TestFileName);
	
	Result = New Structure;
	Result.Insert("HasFilenameLeadingWhitespace", False);
	Result.Insert("HasFilenameTrailingDot", False);
	FilesFound = FindFiles(TestDirName,"*FileNameCheck*", True);
	For Each FoundFile In FilesFound Do
		If StrEndsWith(FoundFile.FullName, " FileNameCheck.") Then
			Result.HasFilenameLeadingWhitespace = True;
			Result.HasFilenameTrailingDot = True;
			Break;
		ElsIf StrEndsWith(FoundFile.FullName, "FileNameCheck.") Then
			Result.HasFilenameLeadingWhitespace = False;
			Result.HasFilenameTrailingDot = True;
			Break;
		ElsIf StrEndsWith(FoundFile.FullName, " FileNameCheck") Then
			Result.HasFilenameLeadingWhitespace = True;
			Result.HasFilenameTrailingDot = False;
			Break;
		EndIf;
	EndDo;
	DeleteFiles(TestDirName);
	Return Result;
EndFunction

#EndRegion

#EndRegion