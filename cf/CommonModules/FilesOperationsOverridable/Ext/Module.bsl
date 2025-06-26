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

// Overriding the attachments settings.
//
// Parameters:
//   Settings - Structure:
//     * DontClearFiles - Array of MetadataObject - objects, whose files are not to be displayed in the 
//                        file clearing settings (for example, internal documents).
//     * NotSynchronizeFiles - Array of MetadataObject - objects, whose files are not to be displayed in the synchronization 
//                        settings with cloud services (for example, internal documents).
//     * DontCreateFilesByTemplate - Array of MetadataObject - objects for whose files the ability to 
//                        create files by templates is disabled.
//
// Example:
//       Settings.DontClearFiles.Add(Metadata.Catalogs.Products);
//       Settings.DontSynchronizeFiles.Add(Metadata.Catalogs.Partners);
//       Settings.DontCreateFilesByTemplates.Add(Metadata.Catalogs.Partners);
//
Procedure OnDefineSettings(Settings) Export
	
EndProcedure

// Overrides the list of catalogs that store files for a specific owner type.
// 
// Parameters:
//  TypeFileOwner  - Type - a type of object reference, to which the file is added.
//
//  CatalogNames - Map of KeyAndValue:
//    * Key - String     - Name of attachment catalog.
//    * Value - Boolean - Set to True to mark the catalog as main. 
//                          The main catalog is used for interactive file management. 
//
// Example:
//       If TypeFileOwner = Type("CatalogRef.Products") Then
//       	CatalogsNames["ProductsAttachedFiles"] = False;
//       	CatalogsNames.Insert("Files", True);
//       EndIf;
//
Procedure OnDefineFileStorageCatalogs(TypeFileOwner, CatalogNames) Export
	
EndProcedure

// Allows you to cancel a file lock based on the analysis of the structure with the file data.
//
// Parameters:
//  FileData    - See FilesOperations.FileData.
//  ErrorDescription - String - an error text if cannot lock a file.
//                   If it is not blank, the file cannot be locked.
//
Procedure OnAttemptToLockFile(FileData, ErrorDescription = "") Export
	
EndProcedure

// Called when creating a file. For example, it can be used to process logically related data
// that needs to be changed when creating new files.
//
// Parameters:
//  File - DefinedType.AttachedFile - a reference to the created file.
//
Procedure OnCreateFile(File) Export
	
EndProcedure

// Called after copying a file from the source file to fill attributes of the new file
//  manually added to the Files or FilesVersions catalog in the configuration.
//
// Parameters:
//  NewFile    - CatalogRef.Files - a reference to a new file that needs filling.
//  SourceFile - CatalogRef.Files - a reference to the source file, from which you need to copy attributes.
//
Procedure FillFileAtributesFromSourceFile(NewFile, SourceFile) Export
	
EndProcedure

// Called when locking a file. Allows you to change the structure with the file data before locking.
//
// Parameters:
//  FileData             - See FilesOperations.FileData.
//  UUID - UUID - a form UUID.
//
Procedure OnLockFile(FileData, UUID) Export
	
EndProcedure

// Called when unlocking a file. Allows you to change the structure with the file data before unlocking.
//
// Parameters:
//  FileData - See FilesOperations.FileData.
//  UUID -  UUID - a form UUID.
//
Procedure OnUnlockFile(FileData, UUID) Export
	
EndProcedure

// Allows you to define the parameters of the email message before sending the file by email.
//
// Parameters:
//  SendOptions - See EmailOperationsClient.EmailSendOptions.
//  FilesToSend  - Array of DefinedType.AttachedFile - List of files to be sent.
//  FilesOwner    - DefinedType.AttachedFilesOwner - an object that owns files.
//  UUID - UUID - a UUID
//                required for storing data in a temporary storage.
//
Procedure OnSendFilesViaEmail(SendOptions, FilesToSend, FilesOwner, UUID) Export
	
	
	
EndProcedure

// Allows you to define the parameters of digital signature stamps in a signed spreadsheet document.
//
// Parameters:
//  StampParameters - Structure - the returned parameter with the following properties:
//      * MarkText         - String - description of the original signed document location.
//      * Logo              - Picture - a logo that will be displayed in the stamp.
//  Certificate      - CryptoCertificate - a certificate, according to which the digital signature stamp is generated.
//
Procedure OnPrintFileWithStamp(StampParameters, Certificate) Export
	
EndProcedure

// Allows you to change the standard form of the file list.
//
// Parameters:
//    Form - ClientApplicationForm - File list form.:
//      * FilesStorageCatalogName - String
//      * FileOwner - DefinedType.FilesOwner
//
Procedure OnCreateFilesListForm(Form) Export
	
EndProcedure

// Allows you to change the standard file form.
//
// Parameters:
//    Form - ClientApplicationForm - File form.:
//      * Object - DefinedType.AttachedFile
//
Procedure OnCreateFilesItemForm(Form) Export
	
EndProcedure

// Allows to change parameter structure to place hyperlink of attachments on the form.
//
// Parameters:
//  HyperlinkParameters - See FilesOperations.FilesHyperlink.
//
// Example:
//  HyperlinkParameters.Placement = "CommandBar";
//
Procedure OnDefineFilesHyperlink(HyperlinkParameters) Export
	
EndProcedure

#EndRegion

