///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

#Region InfobaseData

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions to manage infobase data.

// Checks whether there are references to the object in the infobase.
// When called in a shared session, does not find references in separated areas.
//
// See Common.RefsToObjectFound
//
// Parameters:
//  RefOrRefArray - AnyRef
//                        - Array - an object or a list of objects.
//  SearchInInternalObjects - Boolean - If True, exceptions defined during configuration development
//      are ignored while searching for references.
//      For more details on exceptions during reference search
//      See CommonOverridable.OnAddReferenceSearchExceptions
//
// Returns:
//  Boolean - True if any references to the object are found.
//
Function RefsToObjectFound(Val RefOrRefArray, Val SearchInInternalObjects = False) Export
	
	Return Common.RefsToObjectFound(RefOrRefArray, SearchInInternalObjects);
	
EndFunction

// Checks posting status of the passed documents and returns
// the unposted documents.
//
// See Common.CheckDocumentsPosting
//
// Parameters:
//  Var_Documents - Array - documents to check.
//
// Returns:
//  Array - unposted documents.
//
Function CheckDocumentsPosting(Val Var_Documents) Export
	
	Return Common.CheckDocumentsPosting(Var_Documents);
	
EndFunction

// Attempts to post the documents.
//
// See Common.PostDocuments
//
// Parameters:
//  Var_Documents - See Common.PostDocuments.Documents
//
// Returns:
//   See Common.PostDocuments
//
Function PostDocuments(Var_Documents) Export
	
	Return Common.PostDocuments(Var_Documents);
	
EndFunction 

#EndRegion

#Region SettingsStorage

////////////////////////////////////////////////////////////////////////////////
// Saving, reading, and deleting settings from storages.

// Saves a setting to the common settings storage as the Save method
// of StandardSettingsStorageManager or SettingsStorageManager.<Storage name>,
// object. Setting keys exceeding 128 characters are supported by hashing the key part
// that exceeds 96 characters.
// If the SaveUserData right is not granted, data save fails and no error is raised.
//
// See Common.CommonSettingsStorageSave
//
// Parameters:
//   ObjectKey       - String           - See Syntax Assistant.
//   SettingsKey      - String           - See Syntax Assistant.
//   Settings         - Arbitrary     - See Syntax Assistant.
//   SettingsDescription  - SettingsDescription - See Syntax Assistant.
//   UserName   - String           - See Syntax Assistant.
//   RefreshReusableValues - Boolean - the flag that indicates whether to execute the method.
//
Procedure CommonSettingsStorageSave(ObjectKey, SettingsKey, Settings,
			SettingsDescription = Undefined,
			UserName = Undefined,
			RefreshReusableValues = False) Export
	
	Common.CommonSettingsStorageSave(
		ObjectKey,
		SettingsKey,
		Settings,
		SettingsDescription,
		UserName,
		RefreshReusableValues);
		
EndProcedure

// Saves settings to the common settings storage as the Save method
// of StandardSettingsStorageManager or SettingsStorageManager.<Storage name>,
// object. Setting keys exceeding 128 characters are supported by hashing the key part
// that exceeds 96 characters.
// If the SaveUserData right is not granted, data save fails and no error is raised.
//
// See Common.CommonSettingsStorageSaveArray
// 
// Parameters:
//   MultipleSettings - Array - with the following values:
//     * Value - Structure:
//         * Object    - String       - see the ObjectKey parameter in the Syntax Assistant.
//         * Setting - String       - see the SettingsKey parameter in the Syntax Assistant.
//         * Value  - Arbitrary - see the Settings parameter in the Syntax Assistant.
//
//   RefreshReusableValues - Boolean - the flag that indicates whether to execute the method.
//
Procedure CommonSettingsStorageSaveArray(MultipleSettings, RefreshReusableValues = False) Export
	
	Common.CommonSettingsStorageSaveArray(MultipleSettings, RefreshReusableValues);
	
EndProcedure

// Imports the setting from the common settings storage as the Import method
// of the StandardSettingsStorageManager or SettingsStorageManager.<Storage name> objects.
// Setting keys exceeding 128 characters are supported by hashing the key part
// that exceeds 96 characters.
// Returns the specified default value if the settings do not exist.
// If the SaveUserData right is not granted, the default value is returned and no error is raised.
//
// The return value clears references to a non-existent object in the database, namely:
// - The returned reference is replaced with the default value.
// - The references are deleted from the data of the Array type.
// - The key is not changed for the data of the Structure or Map types, and the value is set to Undefined.
// - Recursive analysis of values in the data of the Array, Structure, Map types is carried out.
//
// See Common.CommonSettingsStorageLoad
//
// Parameters:
//   ObjectKey          - String           - See Syntax Assistant.
//   SettingsKey         - String           - See Syntax Assistant.
//   DefaultValue  - Arbitrary     - the value that is returned if the settings do not exist.
//                                             If not specified, returns Undefined.
//   SettingsDescription     - SettingsDescription - See Syntax Assistant.
//   UserName      - String           - See Syntax Assistant.
//
// Returns: 
//   Arbitrary - See Syntax Assistant.
//
Function CommonSettingsStorageLoad(ObjectKey, SettingsKey, DefaultValue = Undefined,
			SettingsDescription = Undefined,
			UserName = Undefined) Export
	
	Return Common.CommonSettingsStorageLoad(
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDescription,
		UserName);
		
EndFunction

// Removes a setting from the general settings storage as the Remove method,
// StandardSettingsStorageManager objects, or SettingsStorageManager.<Storage name>,
// The setting key supports more than 128 characters by hashing the part
// that exceeds 96 characters.
// If the SaveUserData right is not granted, no data is deleted and no error is raised.
//
// See Common.CommonSettingsStorageDelete
//
// Parameters:
//   ObjectKey     - String
//                   - Undefined - See Syntax Assistant.
//   SettingsKey    - String
//                   - Undefined - See Syntax Assistant.
//   UserName - String
//                   - Undefined - See Syntax Assistant.
//
Procedure CommonSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	Common.CommonSettingsStorageDelete(ObjectKey, SettingsKey, UserName);
	
EndProcedure

// Saves a setting to the system settings storage as the Save method
// of StandardSettingsStorageManager object. Setting keys
// exceeding 128 characters are supported by hashing the key part that exceeds 96 characters.
// If the SaveUserData right is not granted, data save fails and no error is raised.
//
// See Common.SystemSettingsStorageSave
//
// Parameters:
//   ObjectKey       - String           - See Syntax Assistant.
//   SettingsKey      - String           - See Syntax Assistant.
//   Settings         - Arbitrary     - See Syntax Assistant.
//   SettingsDescription  - SettingsDescription - See Syntax Assistant.
//   UserName   - String           - See Syntax Assistant.
//   RefreshReusableValues - Boolean - the flag that indicates whether to execute the method.
//
Procedure SystemSettingsStorageSave(ObjectKey, SettingsKey, Settings,
			SettingsDescription = Undefined,
			UserName = Undefined,
			RefreshReusableValues = False) Export
	
	Common.SystemSettingsStorageSave(
		ObjectKey,
		SettingsKey,
		Settings,
		SettingsDescription,
		UserName,
		RefreshReusableValues);
	
EndProcedure

// Imports settings from the system settings storage as the Import method
// of the StandardSettingsStorageManager object. Setting keys exceeding
// 128 characters are supported by hashing the key part that exceeds 96 characters.
// Returns the specified default value if the settings do not exist.
// If the SaveUserData right is not granted, the default value is returned and no error is raised.
//
// The return value clears references to a non-existent object in the database, namely:
// - The returned reference is replaced with the default value.
// - The references are deleted from the data of the Array type.
// - The key is not changed for the data of the Structure or Map types, and the value is set to Undefined.
// - Recursive analysis of values in the data of the Array, Structure, Map types is carried out.
//
// See Common.SystemSettingsStorageLoad
//
// Parameters:
//   ObjectKey          - String           - See Syntax Assistant.
//   SettingsKey         - String           - See Syntax Assistant.
//   DefaultValue  - Arbitrary     - the value that is returned if the settings do not exist.
//                                             If not specified, returns Undefined.
//   SettingsDescription     - SettingsDescription - See Syntax Assistant.
//   UserName      - String           - See Syntax Assistant.
//
// Returns: 
//   Arbitrary - See Syntax Assistant.
//
Function SystemSettingsStorageLoad(ObjectKey, SettingsKey, DefaultValue = Undefined, 
			SettingsDescription = Undefined,
			UserName = Undefined) Export
	
	Return Common.SystemSettingsStorageLoad(
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDescription,
		UserName);
	
EndFunction

// Removes a setting from the system settings storage as the Remove method
// or the StandardSettingsStorageManager object. The setting key supports
// more than 128 characters by hashing the part that exceeds 96 characters.
// If the SaveUserData right is not granted, no data is deleted and no error is raised.
//
// See Common.SystemSettingsStorageDelete
//
// Parameters:
//   ObjectKey     - String
//                   - Undefined - See Syntax Assistant.
//   SettingsKey    - String
//                   - Undefined - See Syntax Assistant.
//   UserName - String
//                   - Undefined - See Syntax Assistant.
//
Procedure SystemSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	Common.SystemSettingsStorageDelete(ObjectKey, SettingsKey, UserName);
	
EndProcedure

// Saves a setting to the form data settings storage as the Save method of
// StandardSettingsStorageManager or SettingsStorageManager.<Storage name>,
// object. Setting keys exceeding 128 characters are supported by hashing the key part
// that exceeds 96 characters.
// If the SaveUserData right is not granted, data save fails and no error is raised.
//
// See Common.FormDataSettingsStorageSave
//
// Parameters:
//   ObjectKey       - String           - See Syntax Assistant.
//   SettingsKey      - String           - See Syntax Assistant.
//   Settings         - Arbitrary     - See Syntax Assistant.
//   SettingsDescription  - SettingsDescription - See Syntax Assistant.
//   UserName   - String           - See Syntax Assistant.
//   RefreshReusableValues - Boolean - the flag that indicates whether to execute the method.
//
Procedure FormDataSettingsStorageSave(ObjectKey, SettingsKey, Settings,
			SettingsDescription = Undefined,
			UserName = Undefined,
			RefreshReusableValues = False) Export
	
	Common.FormDataSettingsStorageSave(
		ObjectKey,
		SettingsKey,
		Settings,
		SettingsDescription,
		UserName,
		RefreshReusableValues);
	
EndProcedure

// Imports the setting from the common settings storage as the Import method
// of the StandardSettingsStorageManager or SettingsStorageManager.<Storage name> objects.
// Setting keys exceeding 128 characters are supported by hashing the key part
// that exceeds 96 characters.
// Returns the specified default value if the settings do not exist.
// If the SaveUserData right is not granted, the default value is returned and no error is raised.
//
// The return value clears references to a non-existent object in the database, namely:
// - The returned reference is replaced with the default value.
// - The references are deleted from the data of the Array type.
// - The key is not changed for the data of the Structure or Map types, and the value is set to Undefined.
// - Recursive analysis of values in the data of the Array, Structure, Map types is carried out.
//
// See Common.FormDataSettingsStorageLoad
//
// Parameters:
//   ObjectKey          - String           - See Syntax Assistant.
//   SettingsKey         - String           - See Syntax Assistant.
//   DefaultValue  - Arbitrary     - the value that is returned if the settings do not exist.
//                                             If not specified, returns Undefined.
//   SettingsDescription     - SettingsDescription - See Syntax Assistant.
//   UserName      - String           - See Syntax Assistant.
//
// Returns: 
//   Arbitrary - See Syntax Assistant.
//
Function FormDataSettingsStorageLoad(ObjectKey, SettingsKey, DefaultValue = Undefined,
			SettingsDescription = Undefined,
			UserName = Undefined) Export
	
	Return Common.FormDataSettingsStorageLoad(
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDescription,
		UserName);
	
EndFunction

// Deletes the setting from the form data settings storage using the Delete method
// for StandardSettingsStorageManager or SettingsStorageManager.<Storage name>,
// objects. Setting keys exceeding 128 characters are supported by hashing the key part
// that exceeds 96 characters.
// If the SaveUserData right is not granted, no data is deleted and no error is raised.
//
// See Common.FormDataSettingsStorageDelete
//
// Parameters:
//   ObjectKey     - String
//                   - Undefined - See Syntax Assistant.
//   SettingsKey    - String
//                   - Undefined - See Syntax Assistant.
//   UserName - String
//                   - Undefined - See Syntax Assistant.
//
Procedure FormDataSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	Common.FormDataSettingsStorageDelete(ObjectKey, SettingsKey, UserName);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

#Region Styles

////////////////////////////////////////////////////////////////////////////////
// Functions to manage style colors in the client code.

// See CommonClient.StyleColor
Function StyleColor(Val StyleColorName) Export
	
	Return StyleColors[StyleColorName];
	
EndFunction

// See CommonClient.StyleFont
Function StyleFont(Val StyleFontName) Export
	
	Return StyleFonts[StyleFontName];
	
EndFunction

#EndRegion

#EndRegion
