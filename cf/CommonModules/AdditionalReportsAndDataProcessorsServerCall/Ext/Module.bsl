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

// Attaches an external report or data processor.
// For details, See AdditionalReportsAndDataProcessors.AttachExternalDataProcessor.
//
// Parameters:
//   Ref - CatalogRef.AdditionalReportsAndDataProcessors - a data processor to attach.
//
// Returns: 
//   String       - a name of the attached report or data processor.
//   Undefined - if an invalid reference is passed.
//
Function AttachExternalDataProcessor(Ref) Export
	
	Return AdditionalReportsAndDataProcessors.AttachExternalDataProcessor(Ref);
	
EndFunction

// Creates and returns an instance of an external report or data processor.
// For details, See AdditionalReportsAndDataProcessors.ExternalDataProcessorObject.
//
// Parameters:
//   Ref - CatalogRef.AdditionalReportsAndDataProcessors - a report or a data processor to attach.
//
// Returns:
//   ExternalDataProcessor 
//   ExternalReport     
//   Undefined     - if an invalid reference is passed.
//
Function ExternalDataProcessorObject(Ref) Export
	
	Return AdditionalReportsAndDataProcessors.ExternalDataProcessorObject(Ref);
	
EndFunction

#EndRegion

#Region Private

// Runs a data processor command and puts the result in a temporary storage.
//   For details, See AdditionalReportsAndDataProcessors.ExecuteCommand.
//
Function ExecuteCommand(CommandParameters, ResultAddress = Undefined) Export
	
	Return AdditionalReportsAndDataProcessors.ExecuteCommand(CommandParameters, ResultAddress);
	
EndFunction

// Puts binary data of an additional report or data processor in a temporary storage.
Function PutInStorage(Ref, FormIdentifier) Export
	If TypeOf(Ref) <> Type("CatalogRef.AdditionalReportsAndDataProcessors") 
		Or Ref = Catalogs.AdditionalReportsAndDataProcessors.EmptyRef() Then
		Return Undefined;
	EndIf;
	If Not AdditionalReportsAndDataProcessors.CanExportDataProcessorToFile(Ref) Then
		Raise(NStr("en = 'Insufficient rights to export additional report or data processor files.';"),
			ErrorCategory.AccessViolation);
	EndIf;
	
	DataProcessorStorage = Common.ObjectAttributeValue(Ref, "DataProcessorStorage");
	
	Return PutToTempStorage(DataProcessorStorage.Get(), FormIdentifier);
EndFunction

// Starts a long-running operation.
Function StartTimeConsumingOperation(Val UUID, Val CommandParameters) Export
	MethodName = "AdditionalReportsAndDataProcessors.ExecuteCommand";
	
	StartSettings1 = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings1.WaitCompletion = 0;
	StartSettings1.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Running %1 additional report or data processor, command name: %2.';"),
		String(CommandParameters.AdditionalDataProcessorRef),
		CommandParameters.CommandID);
	
	Return TimeConsumingOperations.ExecuteInBackground(MethodName, CommandParameters, StartSettings1);
EndFunction

#EndRegion
