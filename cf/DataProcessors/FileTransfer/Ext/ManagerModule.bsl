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
	
// Returns:
//  Structure:
//   * Action - String
//   * MoveToVolume - Boolean
//   * DestinationStorageVolume - CatalogRef.FileStorageVolumes
// 
Function FileTransferOptions() Export
	Result = New Structure("Action,MoveToVolume,DestinationStorageVolume");
	Return Result;
EndFunction

// Parameters:
//  FilesToTransfer - ValueTable
//  Parameters - See FileTransferOptions
// 
// Returns:
//  Structure:
//    * FilesTransferred - Number
//    * TransferErrors - Array of See TransferError
//
Function ExecuteFileTransfer(FilesToTransfer, Parameters) Export

	TransferErrors = New Array;

	If Parameters.Action = "MoveBetweenVolumes" Then
		ActionForLog = NStr("en = 'between volumes on a server.';");
	ElsIf Parameters.Action = "MoveToVolumes" Then
		ActionForLog = NStr("en = 'to volume on a server.';")
	Else
		ActionForLog = NStr("en = 'to the infobase.';")
	EndIf;
	
	WriteLogEvent(NStr("en = 'Files.Start moving files.';", Common.DefaultLanguageCode()),
		EventLogLevel.Information,,,
		NStr("en = 'Started moving files';") + " " + ActionForLog);
	
	FilesToMoveCount = FilesToTransfer.Count();
	
	VolumeProperties = New Structure("VolumePath, MaxVolumeSize");
	VolumeProperties.Insert("CurrentVolumeSize", 0);
	If Parameters.MoveToVolume Then
		VolumeProperties.VolumePath = FilesOperationsInVolumesInternal.FullVolumePath(Parameters.DestinationStorageVolume);
		VolumeProperties.CurrentVolumeSize = FilesOperationsInVolumesInternal.VolumeSize(Parameters.DestinationStorageVolume);
		VolumeProperties.MaxVolumeSize = 1024*1024 * Common.ObjectAttributeValue(
			Parameters.DestinationStorageVolume, "MaximumSize");
	EndIf;
	
	FilesTransferred = 0;
	For Each File In FilesToTransfer Do
		TransferFile(File, VolumeProperties, Parameters, TransferErrors, FilesTransferred);
	EndDo;
	
	RecordOnCompletionText = NStr("en = 'The files are moved %1
		|Total files: %2';");
	
	RecordOnCompletionText = StringFunctionsClientServer.SubstituteParametersToString(
		RecordOnCompletionText, ActionForLog, Format(FilesTransferred, "NZ=0; NG="));
	
	If FilesTransferred < FilesToMoveCount Then
		RecordOnCompletionText = RecordOnCompletionText + "
			|" + NStr("en = 'Total errors: %1.';");
		RecordOnCompletionText = StringFunctionsClientServer.SubstituteParametersToString(
			RecordOnCompletionText, Format(FilesToMoveCount - FilesTransferred, "NZ=0; NG="));
	EndIf;
	
	WriteLogEvent(NStr("en = 'Files.End moving files.';", Common.DefaultLanguageCode()),
		EventLogLevel.Information,,, RecordOnCompletionText);
	
	Return New Structure("FilesTransferred,TransferErrors", FilesTransferred, TransferErrors);
	
EndFunction	

// Parameters:
//   File             - CatalogObject
//   VolumeProperties     - Structure
//   Parameters        - See FileTransferOptions
//   TransferErrors   - Array of See TransferError
//   FilesTransferred - Number
//
Procedure TransferFile(File, VolumeProperties, Parameters, TransferErrors, FilesTransferred)
	
	FileRef = File.Ref;
	FileProperties = Common.ObjectAttributesValues(FileRef, "Description, Extension, Size");
	
	BeginTransaction();
	Try

		Block = New DataLock;
		DataLockItem = Block.Add(FileRef.Metadata().FullName());
		DataLockItem.SetValue("Ref", FileRef);
		Block.Lock();
		
		FileObject1 = FileRef.GetObject();

		ThrowAnExceptionWhenTheVolumeSizeIsExceeded(VolumeProperties, FileObject1, Parameters);
		
		If Parameters.Action = "MoveBetweenVolumes" Then
			MoveBetweenVolumes(FileObject1, VolumeProperties, Parameters);
		ElsIf Parameters.Action = "MoveToVolumes" Then
			MoveToVolumes(FileObject1, VolumeProperties, Parameters);
		ElsIf Parameters.Action = "MoveToInfobase" Then
			MoveToInfobase(FileObject1, VolumeProperties, Parameters);
		Else
			Raise NStr("en = 'Unsupported operation.';");
		EndIf;
		
		FilesTransferred = FilesTransferred + 1;
		VolumeProperties.CurrentVolumeSize = VolumeProperties.CurrentVolumeSize + FileProperties.Size;
		
		CommitTransaction();

	Except
	
		RollbackTransaction();

		NameForLog = CommonClientServer.GetNameWithExtension(FileProperties.Description,
			FileProperties.Extension);
		
		Error = TransferError(FileRef, ErrorInfo());
		Error.FileName = NameForLog;
		TransferErrors.Add(Error);
		
		WriteLogEvent(NStr("en = 'Files.File moving error.';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,, FileRef,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t move file %1
				|%2
				|due to:
				|%3"".';"),
				Common.SubjectString(FileRef), 
				NameForLog, Error.DetailErrorDescription));

	EndTry;
	
EndProcedure

Procedure MoveBetweenVolumes(FileObject1, VolumeProperties, Parameters)
	FileProperties = FilesOperationsInVolumesInternal.FilePropertiesInVolume();
	FillPropertyValues(FileProperties, FileObject1);
	If TypeOf(FileObject1) = Type("CatalogObject.FilesVersions") Then
		FileProperties.FileOwner = Common.ObjectAttributeValue(
		FileObject1.Owner, "FileOwner");
	EndIf;
	
	CurrentFilePath = FilesOperationsInVolumesInternal.FullFileNameInVolume(FileProperties);
	
	FileOnHardDrive = New File(CurrentFilePath);
	If Not FileOnHardDrive.Exists() Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'File ""%1"" is not found.';"), CurrentFilePath);
	EndIf;
	
	FileProperties.Volume = Parameters.DestinationStorageVolume;
	FileProperties.PathToFile = "";
	
	NewFilePath = FilesOperationsInVolumesInternal.FullFileNameInVolume(FileProperties, FileObject1.UniversalModificationDate);
	FileCopy(CurrentFilePath, NewFilePath);
	
	FileObject1.Volume = Parameters.DestinationStorageVolume;
	FileObject1.PathToFile = Mid(NewFilePath, StrLen(VolumeProperties.VolumePath) + 1);
	FileObject1.Write();
	
	FilesOperationsInVolumesInternal.DeleteFile(CurrentFilePath);
EndProcedure

Procedure MoveToVolumes(FileObject1, VolumeProperties, Parameters)
	FileData = FilesOperations.FileBinaryData(FileObject1.Ref);
	FileObject1.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive;
	FilesOperationsInVolumesInternal.AppendFile(FileObject1, FileData,
		FileObject1.UniversalModificationDate, , ?(Parameters.MoveToVolume, Parameters.DestinationStorageVolume, Undefined));
		
	If FileObject1.FileStorageType <> Enums.FileStorageTypes.InInfobase Then
		InformationRegisters.FileRepository.DeleteBinaryData(FileObject1.Ref);	
	EndIf;
	
	FileObject1.Write();
EndProcedure

Procedure MoveToInfobase(FileObject1, VolumeProperties, Parameters)
	FileData = FilesOperationsInVolumesInternal.FileData(FileObject1.Ref);
	FilesOperationsInternal.WriteFileToInfobase(FileObject1.Ref, FileData);
	
	PathToFile = FilesOperationsInVolumesInternal.FullFileNameInVolume(
					New Structure("Volume, PathToFile", FileObject1.Volume, FileObject1.PathToFile));
	
	FileObject1.Volume = Undefined;
	FileObject1.PathToFile = "";
	FileObject1.FileStorageType = Enums.FileStorageTypes.InInfobase;
	FileObject1.Write();
	FilesOperationsInVolumesInternal.DeleteFile(PathToFile);
EndProcedure

// Parameters:
//  FileRef - DefinedType.AttachedFile
//  ErrorInfo - ErrorInfo
// 
// Returns:
//  Structure:
//   * FileName - String
//   * Error - String
//   * DetailErrorDescription - String
//   * Version - DefinedType.AttachedFile
//
Function TransferError(FileRef, ErrorInfo)

	ErrorDescription = New Structure;
	ErrorDescription.Insert("FileName","");
	ErrorDescription.Insert("Error", "");
	ErrorDescription.Insert("DetailErrorDescription", "");
	ErrorDescription.Insert("Version", FileRef);
	ErrorDescription.Error = ErrorProcessing.BriefErrorDescription(ErrorInfo);
	ErrorDescription.DetailErrorDescription = ErrorProcessing.DetailErrorDescription(ErrorInfo);
	Return ErrorDescription;

EndFunction

Procedure ThrowAnExceptionWhenTheVolumeSizeIsExceeded(Val VolumeProperties, Val FileObject1, Val Parameters)
	
	If Parameters.MoveToVolume
		And VolumeProperties.MaxVolumeSize > 0
		And VolumeProperties.CurrentVolumeSize + FileObject1.Size > VolumeProperties.MaxVolumeSize Then
		
		Raise NStr("en = 'Volume size limit exceeded.';");
	EndIf;

EndProcedure

#EndRegion

#EndIf