///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	If FilesOperationsClient.ScanAvailable() Then
		AddingFromScannerParameters = FilesOperationsClient.AddingFromScannerParameters();
		AddingFromScannerParameters.OwnerForm = ThisObject;
		AddingFromScannerParameters.ResultHandler = New NotifyDescription("ScanSheetCompletion", ThisObject);
		AddingFromScannerParameters.ResultType = FilesOperationsClient.ConversionResultTypeFileName();
		AddingFromScannerParameters.OneFileOnly = True; 
		FilesOperationsClient.AddFromScanner(AddingFromScannerParameters);
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ScanSheetCompletion(Result, Context) Export
	If Result <> Undefined Then 
		FileSystemClient.OpenFile(Result.FileName);
	EndIf;	
EndProcedure

#EndRegion