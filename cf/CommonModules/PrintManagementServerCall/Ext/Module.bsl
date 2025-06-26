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

////////////////////////////////////////////////////////////////////////////////
// Operations with office document templates.

// Gets all data required for printing within a single call: object template data, binary
// template data, and template area description.
// Used for calling print forms based on office document templates from client modules.
//
// Parameters:
//   PrintManagerName - String - Name used for accessing the object manager. For example, "Document.<Document name>".
//   TemplatesNames       - String - Names of templates used for print form generation.
//   DocumentsComposition   - Array - References to infobase objects (all references must be of the same type).
//
// Returns:
//  Map of KeyAndValue - Collection of references to objects and their data.:
//   * Key - AnyRef - Reference to an infobase object.
//   * Value - Structure:
//       ** Key - String - Template name.
//       ** Value - Structure - Object data.
//
Function TemplatesAndObjectsDataToPrint(Val PrintManagerName, Val TemplatesNames, Val DocumentsComposition) Export
	
	Return PrintManagement.TemplatesAndObjectsDataToPrint(PrintManagerName, TemplatesNames, DocumentsComposition);
	
EndFunction

#EndRegion

#Region Private

// Generates print forms for direct output to a printer.
//
// Detailed - See PrintManagement.GeneratePrintFormsForQuickPrint().
//
Function GeneratePrintFormsForQuickPrint(PrintManagerName, TemplatesNames, ObjectsArray,	PrintParameters) Export
	
	Return PrintManagement.GeneratePrintFormsForQuickPrint(PrintManagerName, TemplatesNames,
		ObjectsArray,	PrintParameters);
	
EndFunction

// Generates print forms for direct output to a printer in an ordinary application.
//
// Detailed - See PrintManagement.GeneratePrintFormsForQuickPrintOrdinaryApplication().
//
Function GeneratePrintFormsForQuickPrintOrdinaryApplication(PrintManagerName, TemplatesNames, ObjectsArray, PrintParameters) Export
	
	Return PrintManagement.GeneratePrintFormsForQuickPrintOrdinaryApplication(PrintManagerName, TemplatesNames,
		ObjectsArray,	PrintParameters);
	
EndFunction

// Returns True if the user is authorized to post at least one document.
Function HasRightToPost(DocumentsList) Export
	Return StandardSubsystemsServer.HasRightToPost(DocumentsList);
EndFunction

// See PrintManagement.DocumentsPackage.
Function DocumentsPackage(SpreadsheetDocuments, PrintObjects, PrintInSets, Copies = 1) Export
	
	Return PrintManagement.DocumentsPackage(SpreadsheetDocuments, PrintObjects,
		PrintInSets, Copies);
	
EndFunction

#Region PrintingInBackgroundJob

Function StartGeneratingPrintForms(ParametersForOpeningIncoming) Export
	
	OpeningParameters = Common.CopyRecursive(ParametersForOpeningIncoming);
	
	ExecutionParameters = TimeConsumingOperations.FunctionExecutionParameters(OpeningParameters.StorageUUID);
	ExecutionParameters.ResultAddress = PutToTempStorage(Undefined, OpeningParameters.StorageUUID);
	StoragesContents = Undefined;
	ExtractFromRepositories(OpeningParameters.PrintParameters, StoragesContents);
	OpeningParameters.Insert("StoragesContents", StoragesContents);
	If Not ValueIsFilled(OpeningParameters.DataSource) Then 
		CommonClientServer.Validate(TypeOf(OpeningParameters.CommandParameter) = Type("Array") Or Common.RefTypeValue(OpeningParameters.CommandParameter),
			StringFunctionsClientServer.SubstituteParametersToString(NStr(
				"en = 'Invalid parameter value. %1 parameter, %2 method.
				|Expected value: %3, %4.
				|Passed value: %5.';"),
				"CommandParameter",
				"PrintManagementClient.ExecutePrintCommand",
				"Array",
				"AnyRef",
				 TypeOf(OpeningParameters.CommandParameter)));
	EndIf;

	// Support of backward compatibility with version 2.1.3.
	PrintParameters = OpeningParameters.PrintParameters;
	If OpeningParameters.PrintParameters = Undefined Then
		PrintParameters = New Structure;
	EndIf;
	If Not PrintParameters.Property("AdditionalParameters") Then
		OpeningParameters.PrintParameters = New Structure("AdditionalParameters", PrintParameters);
		For Each PrintParameter In PrintParameters Do
			OpeningParameters.PrintParameters.Insert(PrintParameter.Key, PrintParameter.Value);
		EndDo;
	EndIf;
			
	Return TimeConsumingOperations.ExecuteFunction(ExecutionParameters, "PrintManagement.GeneratePrintFormsInBackground", OpeningParameters);
EndFunction 

Procedure ExtractFromRepositories(ParametersStructure, StoragesContents)
	If StoragesContents = Undefined Then
		StoragesContents = New Map;
	EndIf;
	
	ParametersType = TypeOf(ParametersStructure);
	If ParametersType = Type("String") And IsTempStorageURL(ParametersStructure) Then
		StoragesContents.Insert(ParametersStructure, GetFromTempStorage(ParametersStructure));
	ElsIf ParametersType = Type("Array") Or ParametersType = Type("ValueTable") 
		Or ParametersType = Type("ValueTableRow") Or ParametersType = Type("ValueTreeRow") Then
		
		For Each Item In ParametersStructure Do
			ExtractFromRepositories(Item, StoragesContents);
		EndDo;
	ElsIf ParametersType = Type("Structure") Or ParametersType = Type("Map") Then
		
		For Each Item In ParametersStructure Do
			ExtractFromRepositories(Item.Value, StoragesContents);
		EndDo;
		
		If ParametersType = Type("Map") Then
			For Each Item In ParametersStructure Do
				ExtractFromRepositories(Item.Key, StoragesContents);
			EndDo;
		EndIf;

	ElsIf  ParametersType = Type("ValueTree") Then
		For Each Item In ParametersStructure.Rows Do
			ExtractFromRepositories(Item, StoragesContents);
		EndDo;
	EndIf;
	
EndProcedure
#EndRegion

#EndRegion
