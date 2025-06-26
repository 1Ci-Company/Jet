///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Common and personal file operation settings.

// Returns a structure that contains CommonSettings and PersonalSettings.
Function FilesOperationSettings() Export
	
	CommonSettings        = New Structure;
	PersonalSettings = New Structure;
	
	FilesOperationsInternal.AddFilesOperationsSettings(CommonSettings, PersonalSettings);
	
	AddFilesOperationsSettings(CommonSettings, PersonalSettings);
	
	Settings = New Structure;
	Settings.Insert("CommonSettings",        CommonSettings);
	Settings.Insert("PersonalSettings", PersonalSettings);
	
	Return Settings;
	
EndFunction

// Sets common and personal file function settings.
Procedure AddFilesOperationsSettings(CommonSettings, PersonalSettings)
	
	SetPrivilegedMode(True);
	
	// Populate common settings.
	
	CommonSettings.Insert(
		"ExtractTextFilesOnServer", FilesOperationsInternal.ExtractTextFilesOnServer());
	CommonSettings.Insert("MaxFileSize", FilesOperations.MaxFileSize());
	
	DenyUploadFilesByExtension = Constants.DenyUploadFilesByExtension.Get();
	If DenyUploadFilesByExtension = Undefined Then
		DenyUploadFilesByExtension = False;
		Constants.DenyUploadFilesByExtension.Set(DenyUploadFilesByExtension);
	EndIf;
	CommonSettings.Insert("FilesImportByExtensionDenied", DenyUploadFilesByExtension);
	
	CommonSettings.Insert("DeniedExtensionsList", DeniedExtensionsList());
	CommonSettings.Insert("FilesExtensionsListOpenDocument", FilesExtensionsListOpenDocument());
	CommonSettings.Insert("TextFilesExtensionsList", TextFilesExtensionsList());
	
	// Populate personal settings.
	
	LocalFileCacheMaxSize = Common.CommonSettingsStorageLoad(
		"LocalFileCache", "LocalFileCacheMaxSize");
	If LocalFileCacheMaxSize = Undefined Then
		LocalFileCacheMaxSize = 100*1024*1024; // 100 MB.
		Common.CommonSettingsStorageSave("LocalFileCache",
			"LocalFileCacheMaxSize", LocalFileCacheMaxSize);
	EndIf;
	PersonalSettings.Insert("LocalFileCacheMaxSize",
		LocalFileCacheMaxSize);
	
	PathToLocalFileCache = Common.CommonSettingsStorageLoad(
		"LocalFileCache", "PathToLocalFileCache");
	// Do not get the variable directly.
	// Use the getter function "FilesOperationsInternalClient.UserWorkingDirectory".
	PersonalSettings.Insert("PathToLocalFileCache", PathToLocalFileCache);
	
	DeleteFileFromLocalFileCacheOnCompleteEdit =
		Common.CommonSettingsStorageLoad(
			"LocalFileCache", "DeleteFileFromLocalFileCacheOnCompleteEdit", False);
	PersonalSettings.Insert("DeleteFileFromLocalFileCacheOnCompleteEdit",
		DeleteFileFromLocalFileCacheOnCompleteEdit);
	
	ShowTooltipsOnEditFiles = Common.CommonSettingsStorageLoad(
		"ApplicationSettings", "ShowTooltipsOnEditFiles");
	If ShowTooltipsOnEditFiles = Undefined Then
		ShowTooltipsOnEditFiles = True;
		Common.CommonSettingsStorageSave("ApplicationSettings",
			"ShowTooltipsOnEditFiles", ShowTooltipsOnEditFiles);
	EndIf;
	PersonalSettings.Insert("ShowTooltipsOnEditFiles",
		ShowTooltipsOnEditFiles);
	
	ShowFileNotModifiedFlag = Common.CommonSettingsStorageLoad(
		"ApplicationSettings", "ShowFileNotModifiedFlag");
	If ShowFileNotModifiedFlag = Undefined Then
		ShowFileNotModifiedFlag = True;
		
		Common.CommonSettingsStorageSave(
			"ApplicationSettings",
			"ShowFileNotModifiedFlag",
			ShowFileNotModifiedFlag);
	EndIf;
	PersonalSettings.Insert("ShowFileNotModifiedFlag",
		ShowFileNotModifiedFlag);
	
	// File open settings.
	
	TextFilesExtension = Common.CommonSettingsStorageLoad(
		"OpenFileSettings\TextFiles",
		"Extension", "TXT XML INI");
	TextFilesOpeningMethod = Common.CommonSettingsStorageLoad(
		"OpenFileSettings\TextFiles", 
		"OpeningMethod",
		Enums.OpenFileForViewingMethods.UsingBuiltInEditor);
	GraphicalSchemasExtension = Common.CommonSettingsStorageLoad(
		"OpenFileSettings\GraphicalSchemas", "Extension", "GRS");
	GraphicalSchemasOpeningMethod = Common.CommonSettingsStorageLoad(
		"OpenFileSettings\GraphicalSchemas",
		"OpeningMethod", Enums.OpenFileForViewingMethods.UsingBuiltInEditor);
	
	PersonalSettings.Insert("TextFilesExtension",       TextFilesExtension);
	PersonalSettings.Insert("TextFilesOpeningMethod",   TextFilesOpeningMethod);
	PersonalSettings.Insert("GraphicalSchemasExtension",     GraphicalSchemasExtension);
	PersonalSettings.Insert("GraphicalSchemasOpeningMethod", GraphicalSchemasOpeningMethod);
	
EndProcedure

Function DeniedExtensionsList()
	
	SetPrivilegedMode(True);
	
	ExtensionsList = Constants.DeniedDataAreaExtensionsList.Get();
	If ExtensionsList = Undefined Or ExtensionsList = "" Then
		ExtensionsList = Upper(StrConcat(FilesOperationsInternal.DeniedExtensionsList().UnloadValues(), " "));
		Constants.DeniedDataAreaExtensionsList.Set(ExtensionsList);
	EndIf;
	
	Result = "";
	If Common.DataSeparationEnabled()
	   And Common.SeparatedDataUsageAvailable() Then
		
		DeniedExtensionsList = Constants.DeniedExtensionsList.Get();
		Result = DeniedExtensionsList + " "  + ExtensionsList;
	Else
		Result = ExtensionsList;
	EndIf;
		
	Return Result;
	
EndFunction

Function FilesExtensionsListOpenDocument()
	
	SetPrivilegedMode(True);
	
	FilesExtensionsListDocumentDataAreas =
		Constants.FilesExtensionsListDocumentDataAreas.Get();
	
	If FilesExtensionsListDocumentDataAreas = Undefined
	 Or FilesExtensionsListDocumentDataAreas = "" Then
		
		FilesExtensionsListDocumentDataAreas =
			"ODT OTT ODP OTP ODS OTS ODC OTC ODF OTF ODM OTH SDW STW SXW STC SXC SDC SDD STI";
		
		Constants.FilesExtensionsListDocumentDataAreas.Set(
			FilesExtensionsListDocumentDataAreas);
	EndIf;
	
	FinalExtensionList = "";
	
	If Common.DataSeparationEnabled()
	   And Common.SeparatedDataUsageAvailable() Then
		
		DeniedExtensionsList = Constants.FilesExtensionsListOpenDocument.Get();
		
		FinalExtensionList =
			DeniedExtensionsList + " "  + FilesExtensionsListDocumentDataAreas;
	Else
		FinalExtensionList = FilesExtensionsListDocumentDataAreas;
	EndIf;
	
	Return FinalExtensionList;
	
EndFunction

Function TextFilesExtensionsList()

	SetPrivilegedMode(True);
	TextFilesExtensionsList = Constants.TextFilesExtensionsList.Get();
	SetPrivilegedMode(False);
	If IsBlankString(TextFilesExtensionsList) Then
		TextFilesExtensionsList = FilesOperationsInternal.TextFilesExtensionsList();
	EndIf;
	Return TextFilesExtensionsList;

EndFunction

// Returns the flag showing whether the node belongs to DIB exchange plan.
//
// Parameters:
//  FullExchangePlanName - String - an exchange plan string that requires receiving the function value.
//
//  Returns:
//    Boolean - If True, the node belongs to the exchange plan of the distributed infobase. Otherwise, False.
//
Function IsDistributedInfobaseNode(FullExchangePlanName) Export

	Return Common.MetadataObjectByFullName(FullExchangePlanName).DistributedInfoBase;
	
EndFunction

// For the function, see FullVolumePath.
// 
// Returns:
//  Boolean
//
Function VolumePathIgnoreRegionalSettings() Export
	Return Constants.VolumePathIgnoreRegionalSettings.Get();
EndFunction

// Returns the flag indicating whether data migrated to a new register.
//
//  Returns:
//    Boolean - If "True", data was migrated. Otherwise, "False".
// 
Function IsDeduplicationCompleted() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	TRUE AS Validation
	|FROM
	|	InformationRegister.DeleteFilesBinaryData AS DeleteFilesBinaryData";
	
	Return Query.Execute().IsEmpty();
	
EndFunction

#EndRegion
