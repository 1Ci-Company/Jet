///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Returns the file version encoding.
//
// Parameters:
//   VersionRef - DefinedType.AttachedFile - file version.
//
// Returns:
//   String
//
Function FileVersionEncoding(VersionRef) Export
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.FilesEncoding.CreateRecordManager();
	RecordManager.File = VersionRef;
	RecordManager.Read();
	
	Return RecordManager.Encoding;
	
EndFunction

// Writes the file version encoding.
//
// Parameters:
//   VersionRef - DefinedType.AttachedFile - a reference to file version.
//   Encoding - String - new encoding of the file version.
//
Procedure WriteFileVersionEncoding(VersionRef, Encoding) Export
	
	If Not ValueIsFilled(Encoding) Then
		Return;
	EndIf;
	
	If ValueIsFilled(InformationRegisters.FilesEncoding.FileVersionEncoding(VersionRef)) Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.FilesEncoding.CreateRecordManager();
	RecordManager.File = VersionRef;
	RecordManager.Encoding = Encoding;
	RecordManager.Write(True);
	
EndProcedure

// Automatically determines and returns the text file encoding.
//
// Parameters:
//  AttachedFile - DefinedType.AttachedFile
//  Extension         - String - file extension.
//
// Returns:
//  String
//
Function DefineFileEncoding(AttachedFile, Extension) Export
	
	Encoding = FileVersionEncoding(AttachedFile);
	If ValueIsFilled(Encoding) Then
		Return Encoding;
	EndIf;
		
	CommonSettings = FilesOperationsInternalCached.FilesOperationSettings().CommonSettings;
	EncodingAutoDetection = FilesOperationsInternalClientServer.FileExtensionInList(
		CommonSettings.TextFilesExtensionsList, Extension);
	If Not EncodingAutoDetection Then
		Return Encoding;
	EndIf;
		
	BinaryData = FilesOperations.FileBinaryData(AttachedFile, False);
	Encoding = FilesOperationsInternalClientServer.DetermineBinaryDataEncoding(BinaryData, Extension);
	Return Encoding;
	
EndFunction

#EndRegion

#EndIf
