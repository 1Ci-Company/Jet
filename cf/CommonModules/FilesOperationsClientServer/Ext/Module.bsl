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

// Initializes a structure of parameters for getting file data. See FilesOperations.FileData.
//
// Returns:
//  Structure:
//    * FormIdentifier             - UUID - a form UUID. The method puts the file to the temporary storage
//                                     of this form and returns the address in the RefToBinaryFileData property.
//                                     The default value is Undefined.
//    * GetBinaryDataRef - Boolean - if False, reference to the binary data in the RefToBinaryFileData
//                                     is not received thus significantly speeding up execution for large binary data.
//                                     The default value is True.
//    * ForEditing              - Boolean - if you specify True, a file will be locked for editing.
//                                     The default value is False.
//    * RaiseException1             - Boolean - if you specify False, the function will not raise
//                                     exceptions in exceptional situations and will return Undefined. The default value is True.
//
Function FileDataParameters() Export
	
	DataParameters = New Structure;
	DataParameters.Insert("ForEditing",              False);
	DataParameters.Insert("FormIdentifier",             Undefined);
	DataParameters.Insert("RaiseException1",             True);
	DataParameters.Insert("GetBinaryDataRef", True);
	Return DataParameters;
	
EndFunction

// Handler of the subscription to FormGetProcessing event for overriding file form.
//
// Parameters:
//  Source                 - CatalogManager - the *AttachedFiles catalog manager.
//  FormType                 - String - a standard form name.
//  Parameters                - Structure - form parameters.
//  SelectedForm           - String - a name or metadata object of the form to open.
//  AdditionalInformation - Structure - additional information of the form opening.
//  StandardProcessing     - Boolean - indicates whether standard (system) event processing is executed.
//
Procedure DetermineAttachedFileForm(Source, FormType, Parameters,
	SelectedForm, AdditionalInformation, StandardProcessing) Export
	
	FilesOperationsInternalServerCall.DetermineAttachedFileForm(
		Source,
		FormType,
		Parameters,
		SelectedForm,
		AdditionalInformation,
		StandardProcessing);
		
EndProcedure

// Returns user scanning settings.
// 
// Returns:
//  Structure:
//   * ShowScannerDialog - Boolean
//   * DeviceName - String - ScannerDescription
//   * ScannedImageFormat - EnumRef.ScannedImageFormats
//   * ShouldSaveAsPDF - Boolean
//   * MultipageStorageFormat - EnumRef.MultipageFileStorageFormats 
//   * Resolution - EnumRef.ScannedImageResolutions
//   * Chromaticity - EnumRef.ImageColorDepths
//   * Rotation - EnumRef.PictureRotationOptions
//   * PaperSize - EnumRef.PaperSizes
//   * DuplexScanning - Boolean
//   * DocumentAutoFeeder - Boolean
//   * UseImageMagickToConvertToPDF - Boolean
//   * JPGQuality - Number
//   * TIFFDeflation - EnumRef.TIFFCompressionTypes
//   * PathToConverterApplication - String
//
Function UserScanSettings() Export
	Result = New Structure;
	Result.Insert("ShowScannerDialog", False);
	Result.Insert("DeviceName", "");
	Result.Insert("ScannedImageFormat");
	Result.Insert("ShouldSaveAsPDF", False);
	Result.Insert("MultipageStorageFormat");
	Result.Insert("Resolution");
	Result.Insert("Chromaticity");
	Result.Insert("Rotation");
	Result.Insert("PaperSize");
	Result.Insert("DuplexScanning", False);
	Result.Insert("DocumentAutoFeeder", False);
	Result.Insert("UseImageMagickToConvertToPDF", False);
	Result.Insert("JPGQuality", 0);
	Result.Insert("TIFFDeflation");
	Result.Insert("PathToConverterApplication", "");
	Result.Insert("ScanLogCatalog");
	Result.Insert("UseScanLogDirectory", False);
	Return Result;
EndFunction

#EndRegion

#Region Internal

// Initializes the structure with file data.
//
// Parameters:
//   Mode        - String - File or FileWithVersion.
//   SourceFile - File   - the file on whose basis the structure properties are filled.
//
// Returns:
//   Structure:
//    * BaseName             - String - File name without the extension.
//    * ExtensionWithoutPoint           - String - a file extension.
//    * Modified               - Date   - date and time of file modification.
//    * ModificationTimeUniversal  - Date   - a date and a time of file modification (UTC).
//    * Size                       - Number  - File size in bytes.
//    * TempFileStorageAddress  - String
//                                     - ValueStorage - address in the temporary storage with binary data of the file
//                                       or binary data of the file.
//    * TempTextStorageAddress - String
//                                     - ValueStorage - address in the temporary storage with an extracted text
//                                       for the full-text search or data with the text.
//    * IsWebClient                 - Boolean - True if a call comes from the web client.
//    * Author                        - CatalogRef.Users - a file author. If Undefined, a current
//                                                                     user.
//    * Comment                  - String - a comment to the file.
//    * WriteToHistory             - Boolean - write to user work history.
//    * StoreVersions                - Boolean - allow storing file versions in the infobase.
//                                              When creating a new version, create a new version, or modify an
//                                              existing one (False).
//    * Encrypted                   - Boolean - the file is encrypted.
//
Function FileInfo1(Val Mode, Val SourceFile = Undefined) Export
	
	Result = New Structure;
	Result.Insert("BaseName");
	Result.Insert("Comment", "");
	Result.Insert("TempTextStorageAddress");
	Result.Insert("Author");
	Result.Insert("FilesStorageCatalogName", "Files");
	Result.Insert("TempFileStorageAddress");
	Result.Insert("ExtensionWithoutPoint");
	Result.Insert("Modified", Date('00010101'));
	Result.Insert("ModificationTimeUniversal", Date('00010101'));
	Result.Insert("Size", 0);
	Result.Insert("Encrypted");
	Result.Insert("WriteToHistory", False);
	Result.Insert("Encoding");
	Result.Insert("NewTextExtractionStatus");
	If Mode = "FileWithVersion" Then
		Result.Insert("StoreVersions", True);
		Result.Insert("RefToVersionSource");
		Result.Insert("NewVersionCreationDate");
		Result.Insert("NewVersionAuthor");
		Result.Insert("NewVersionComment");
		Result.Insert("NewVersionVersionNumber");
	Else
		Result.Insert("StoreVersions", False);
	EndIf;
	
	If SourceFile <> Undefined Then
		Result.BaseName            = SourceFile.BaseName;
		Result.ExtensionWithoutPoint          = CommonClientServer.ExtensionWithoutPoint(SourceFile.Extension);
		Result.Modified              = SourceFile.GetModificationTime();
		Result.ModificationTimeUniversal = SourceFile.GetModificationUniversalTime();
		Result.Size                      = SourceFile.Size();
	EndIf;
	Return Result;
	
EndFunction

#EndRegion

#Region Private

// Determine whether the file can be locked. If not, generate error text.
//
// Parameters:
//  FileData  - Structure - a structure with file data.
//  MessageText - String - Return value.
//                            If failed to locked the file, contains error description.
//
// Returns:
//  Boolean - if True, the current user can lock the file
//           or the file is already locked by the current user.
//
Function WhetherPossibleLockFile(FileData, MessageText = "") Export
	
	If FileData.DeletionMark Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot edit file ""%1""
				|as it is marked for deletion.';"),
			String(FileData.Ref));
		Return False;
	EndIf;
	
	If FileData.IsInternal Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot edit service file ""%1"".';"),
			String(FileData.Ref));
		Return False;
	EndIf;

	Result = Not ValueIsFilled(FileData.BeingEditedBy) Or FileData.CurrentUserEditsFile;  
	If Not Result Then
		If ValueIsFilled(FileData.LockedDate) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'File ""%1""
					| is locked for editing by user ""%2"" on %3.';"),
				String(FileData.Ref), String(FileData.BeingEditedBy), Format(FileData.LockedDate, "DLF=DT"));
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'File ""%1""
					| is locked for editing by user
					|""%2"".';"),
				String(FileData.Ref), String(FileData.BeingEditedBy));
		EndIf;
	EndIf;
		
	Return Result;
	
EndFunction

Function OneFileOnlyText() Export
	Return "OneFileOnly";
EndFunction

Function CommandsPrefix() Export
	Return "AttachedFilesManagement";
EndFunction

Function ImportFileCommandName() Export
	Return "ImportFile_";
EndFunction

Function CreateFromTemplateCommandName() Export
	Return "CreateByTemplate";
EndFunction

Function ScanCommandName() Export
	Return "Scan";
EndFunction

Function OpenListCommandName() Export
	Return "OpenList";
EndFunction

Function SelectFileCommandName() Export
	Return "SelectFile";
EndFunction

Function ViewFileCommandName() Export
	Return "ViewFile1";
EndFunction

Function ClearCommandName() Export
	Return "Clear";
EndFunction

Function OpenFormCommandName() Export
	Return "OpenForm";
EndFunction

Function EditFileCommandName() Export
	Return "EditFile";
EndFunction

Function PutFileCommandName() Export
	Return "PutFile";
EndFunction

Function CancelEditCommandName() Export
	Return "CancelEdit";
EndFunction

Function NameOfAdditionalCommandFromContextMenu() Export
	Return "FromContextMenu";
EndFunction

#EndRegion