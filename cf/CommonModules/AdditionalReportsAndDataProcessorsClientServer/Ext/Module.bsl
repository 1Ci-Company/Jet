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
// Object kind names.

// Print form.
//
// Returns:
//   String - a name of the additional print form kind.
//
Function DataProcessorKindPrintForm() Export
	
	Return "PrintForm"; // Internal ID.
	
EndFunction

// Filling an object.
//
// Returns:
//   String - a name of the additional filling data processor kind.
//
Function DataProcessorKindObjectFilling() Export
	
	Return "ObjectFilling"; // Internal ID.
	
EndFunction

// Create related objects.
//
// Returns:
//   String - a name of a kind of additional data processors for related object creation.
//
Function DataProcessorKindRelatedObjectCreation() Export
	
	Return "RelatedObjectsCreation"; // Internal ID.
	
EndFunction

// Assignable report.
//
// Returns:
//   String - a name of the additional context report kind.
//
Function DataProcessorKindReport() Export
	
	Return "Report"; // Internal ID.
	
EndFunction

// Create related objects.
//
// Returns:
//   String - a name of the additional context report kind.
//
Function DataProcessorKindMessageTemplate() Export
	
	Return "MessageTemplate"; // Internal ID.
	
EndFunction

// Additional data processor.
//
// Returns:
//   String - a name of the additional global data processor kind.
//
Function DataProcessorKindAdditionalDataProcessor() Export
	
	Return "AdditionalDataProcessor"; // Internal ID.
	
EndFunction

// Additional report.
//
// Returns:
//   String - a name of the additional global report kind.
//
Function DataProcessorKindAdditionalReport() Export
	
	Return "AdditionalReport"; // Internal ID.
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Command type names.

// Returns the name of the command type with a server method call. To execute commands of this type,
//   in the object module, determine the export procedure using the following template:
//   
//   For global reports and data processors (Kind = "AdditionalDataProcessor" or Kind = "AdditionalReport"):
//       // Server command handler.
//       //
//       //
//       // Parameters:
//       //   CommandID - String    - a command name determined using function ExternalDataProcessorInfo().
//       //   ExecutionParameters - Structure - command execution context.
//       //       * AdditionalDataProcessorRef - CatalogRef.AdditionalReportsAndDataProcessors - a data processor reference.
//       //           Can be used for reading data processor parameters.
//       //           See an example in the comment to function AdditionalReportsAndDataProcessorsClientServer.CommandTypeOpenForm().
//       //       * ExecutionResult - Structure - a command execution result.
//       //           Can be used for passing the result from server or from a background job to the initial point.
//       //           In particular, it is returned by functions AdditionalReportsAndDataProcessors.ExecuteCommand()
//       //           and AdditionalReportsAndDataProcessors.ExecuteCommandFromExternalObjectForm().
//       //           It can also be obtained from the temporary storage
//       //
//       //           in the idle handler of procedure AdditionalReportsAndDataProcessorsClient.ExecuteCommnadInBackground().
//       	//
//       Procedure ExecuteCommand(CommandID, ExecutionParameters) Export
//   
//   // Implementing command logic.
//       EndProcedure
//       //
//       For print forms (Kind = "PrintForm"):
//       // Print handler.
//       //
//       // Parameters:
//       //   ObjectsArray - Array - references to objects to be printed.
//       //   PrintFormsCollection - ValueTable - information on spreadsheet documents.
//       //       The parameter is used for passing function PrintManagement.PrintFormInfo() in the parameters.
//       //   PrintObjects - ValueList - a map between objects and names of spreadsheet document areas.
//       //       The parameter is used for passing procedure PrintManagement.SetDocumentPrintArea() in the parameters.
//       //   OutputParameters - Structure - additional parameters of generated spreadsheet documents.
//       //
//       //       * AdditionalDataProcessorRef - CatalogRef.AdditionalReportsAndDataProcessors - a data processor reference.
//       //           Can be used for reading data processor parameters.
//       //           See an example in the comment to function AdditionalReportsAndDataProcessorsClientServer.CommandTypeOpenForm().
//       //
//       // Example:
//       //  	PrintForm = PrintManagement.PrintFormInfo(PrintFormsCollection, "<PrintFormID>");
//       //  	If PrintForm <> Undefined, Then
//       //  		SpreadsheetDocument = New SpreadsheetDocument;
//       //  		SpreadsheetDocument.PrintParametersKey = "<KeyToSavePrintFormParameters>";
//       //  		For Each Ref From ObjectsArray Do
//       //  			If SpreadsheetDocument.TableHeight > 0, Then
//       //  				SpreadsheetDocument.OutputHorizontalPageBreak();
//       //  			EndIf;
//       //  			AreaStart = SpreadsheetDocument.TableHeight + 1;
//       //  			// … code for a spreadsheet document generation …
//       //
//       //  			PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, AreaStart, PrintObjects, Ref);
//       	//  		EndDo;
//       //  		PrintForm.SpreadsheetDocument = SpreadsheetDocument;
//   
//   //    	EndIf;
//       //
//       //
//       Procedure Print(ObjectsArray, PrintFormsCollection, PrintObjects, OutputParameters) Export
//       // Implementing command logic.
//       EndProcedure
//       For data processors of related object creation (Kind = "RelatedObjectsCreation"):
//       // Server command handler.
//       //
//       // Parameters:
//       //   CommandID - String - a command name determined using function ExternalDataProcessorInfo().
//       //   RelatedObjects - Array - references to the objects the command is called for.
//       //   CreatedObjects - Array - references to the objects created while executing the command.
//       //   ExecutionParameters - Structure - command execution context.
//       //       * AdditionalDataProcessorRef - CatalogRef.AdditionalReportsAndDataProcessors - a data processor reference.
//       //           Can be used for reading data processor parameters.
//       //           See an example in the comment to function AdditionalReportsAndDataProcessorsClientServer.CommandTypeOpenForm().
//       //
//       //       * ExecutionResult - Structure - a command execution result.
//       	//          Can be used for passing the result from server or from a background job to the initial point.
//       //           In particular, it is returned by functions AdditionalReportsAndDataProcessors.ExecuteCommand()
//   
//   //           and AdditionalReportsAndDataProcessors.ExecuteCommandFromExternalObjectForm().
//       //           It can also be obtained from the temporary storage
//       //
//       //           in the idle handler of procedure AdditionalReportsAndDataProcessorsClient.ExecuteCommnadInBackground().
//       //
//       Procedure ExecuteCommand(CommandID, RelatedObjects, CreatedObjects, ExecutionParameters) Export
//       // Implementing command logic.
//       EndProcedure
//       For filling data processors (Kind = "ObjectFilling"):
//       // Server command handler.
//       //
//       // Parameters:
//       //   CommandID - String - a command name determined using function ExternalDataProcessorInfo().
//       //   RelatedObjects - Array - references to the objects the command is called for.
//       //       - Undefined - for commands FillingForm.
//       //   ExecutionParameters - Structure - command execution context.
//       //       * AdditionalDataProcessorRef - CatalogRef.AdditionalReportsAndDataProcessors - a data processor reference.
//       //
//       //           Can be used for reading data processor parameters.
//       	//           See an example in the comment to function AdditionalReportsAndDataProcessorsClientServer.CommandTypeOpenForm().
//       //       * ExecutionResult - Structure - a command execution result.
// //          Can be used for passing the result from server or from a background job to the initial point.
// //           In particular, it is returned by functions AdditionalReportsAndDataProcessors.ExecuteCommand()
// //           and AdditionalReportsAndDataProcessors.ExecuteCommandFromExternalObjectForm().
// //           It can also be obtained from the temporary storage
// //           in the idle handler of procedure AdditionalReportsAndDataProcessorsClient.ExecuteCommnadInBackground().
// //
// Procedure ExecuteCommand(CommandID, RelatedObjects, ExecutionParameters) Export
// // Implementing command logic.
// EndProcedure
//
// Returns:
//   String - a name of the command type with a server method call.
//
Function CommandTypeServerMethodCall() Export
	
	Return "ServerMethodCall"; // Internal ID.
	
EndFunction

// Returns the name of the command type with a client method call. To execute commands of this type,
//   in the main form of the external object, determine the client export procedure using the following template:
//   
//   For global reports and data processors (Kind = "AdditionalDataProcessor" or Kind = "AdditionalReport"):
//       &AtClient
//       Procedure ExecuteCommand(CommandID) Export
//       	// Implementing command logic.
//       EndProcedure
//   
//   For print forms (Kind = "PrintForm"):
//       &AtClient
//       Procedure Print(CommandID, RelatedObjectsArray) Export
//       	// Implementing command logic.
//       EndProcedure
//   
//   For data processors of related object creation (Kind = "RelatedObjectsCreation"):
//       &AtClient
//       Procedure ExecuteCommand(CommandID, RelatedObjectsArray, CreatedObjects) Export
//       	// Implementing command logic.
//       EndProcedure
//   
//   For filling data processors and context reports (Kind = "ObjectFilling" or Kind = "Report"):
//       &AtClient
//       Procedure ExecuteCommand(CommandID, RelatedObjectsArray) Export
//       	// Implementing command logic.
//       EndProcedure
//   
//   Additionally, (for all kinds) in the AdditionalDataProcessorRef form parameter, a reference to this object is passed
//     (an AdditionalReportsAndDataProcessors catalog item matching the object).
//     The reference can be used for running long-running operations in the background.
//     For more information, see subsystem help, section "Running long-running operations in the background" (in Russian).
//
// Returns:
//   String - a name of the command type with a client method call.
//
Function CommandTypeClientMethodCall() Export
	
	Return "ClientMethodCall"; // Internal ID.
	
EndFunction

// Returns a name of a type of commands for opening a form. When executing these commands,
// the main form of the external object opens with the parameters specified below.
//
//   Common parameters:
//       CommandID - String - a command name determined using function ExternalDataProcessorInfo().
//       AdditionalDataProcessorRef - CatalogRef.AdditionalReportsAndDataProcessors - a reference to the object.
//           Can be used for reading and saving data processor parameters.
//           It can also be used for running long-running operations in the background.
//           For more information, see subsystem help, section "Running long-running operations in the background" (in Russian).
//       FormName - String - a name of the owner form the command is called from.
//   
//   Auxiliary parameters for data processors of related object creation (Kind = "RelatedObjectsCreation"),
//   filling data processors (Kind = "ObjectFilling"), and context reports (Kind = "Report"):
//       RelatedObjects - Array - references to the objects the command is called for.
//   
//   Example of reading common parameter values:
//       ObjectRef = CommonClientServer.StructureProperty(Parameters, "AdditionalDataProcessorRef").
//       CommandID = CommonClientServer.StructureProperty(Parameters, "CommandID").
//   
//   Example of reading additional parameter values:
//       If ValueIsFilled(ObjectRef) Then
//       	SettingsStorage = Common.ObjectAttributeValue(ObjectRef, "SettingsStorage").
//       	Settings = SettingsStorage.Get().
//       	If TypeOf(Settings) = Type("Structure") Then
//       		FillPropertyValues(ThisObject, "<SettingsNames>").
//       	EndIf;
//       EndIf;
//   
//   Example of saving values of additional settings:
//       Settings = New Structure("<SettingsNames>", <SettingsValues>);
//       AdditionalDataProcessorObject = ObjectRef.GetObject().
//       AdditionalDataProcessorObject.SettingsStorage = New ValueStorage(Settings).
//       AdditionalDataProcessorObject.Write().
//
// Returns:
//   String - a name of a type of commands for opening a form.
//
Function CommandTypeOpenForm() Export
	
	Return "OpeningForm"; // Internal ID.
	
EndFunction

// Returns a name of a type of commands for filling a form without writing the object. These commands are available
//   only in filling data processors (Kind = "ObjectFilling").
//   To execute commands of this type, in the object module, determine the export procedure using the following template:
//       // Server command handler.
//       //
//       //
//       // Parameters:
//       //   CommandID - String - a command name determined using function ExternalDataProcessorInfo().
//       //   RelatedObjects - Array - references to the objects the command is called for.
//       //       - Undefined - not passed for commands of the FillingForm type.
//       //   ExecutionParameters - Structure - command execution context.
//       //       * ThisForm - ClientApplicationForm - a form.  The parameter is required for commands of FillingForm type.
//       //       * AdditionalDataProcessorRef - CatalogRef.AdditionalReportsAndDataProcessors - a data processor reference.
//       //           Can be used for reading data processor parameters.
//       //
//       //           See an example in the comment to function AdditionalReportsAndDataProcessorsClientServer.CommandTypeOpenForm().
//       	//
//       Procedure ExecuteCommand(CommandID, RelatedObjects, ExecutionParameters) Export
// //  Implementing command logic.
// EndProcedure
//
// Returns:
//   String - a name of a type of commands for filling a form.
//
Function CommandTypeFormFilling() Export
	
	Return "FillingForm"; // Internal ID.
	
EndFunction

// Returns a name of a type of commands for importing data from a file. These commands are available
//   only in global data processors (Kind = "AdditionalDataProcessor")
//   provided that the configuration includes the ImportDataFromFile subsystem.
//   To execute commands of this type, in the object module, determine the export procedure using the following template:
//       // Determines parameters of data import from a file.
//       //
//       //
//       // Parameters:
//       //   CommandID - String - a command name determined using function ExternalDataProcessorInfo().
//       //   ImportParameters - Structure - data import settings:
//       //       * DataStructureTemplateName - String - a name of the template for data to import.
//       //        Default template is ImportingFromFile.
//       //
//       //       * MandatoryTemplateColumns - Array - a list of names of required columns.
//       	//
//       Procedure GetDataImportingFromFileParameters(CommandID, ImportParameters) Export
//       
//       // Overriding settings of data import from a file.
//       //
//       EndProcedure
//       // Maps the data to import with the existing infobase data.
//       //
//       // Parameters:
//       //   CommandID - String - a command name determined using function ExternalDataProcessorInfo().
//       //   DataToImport - ValueTable - details of data to import:
//       //       * MappedObject - CatalogRef.Ref - a reference to the mapped object.
//       //
//       //           It is populated inside the procedure.
//       	//       * <other columns> - String - data imported from the file.
//       //          Columns are the same as in the ImportingFromFile template.
//       
//       //
//       //
//       Procedure MapDataToImportingFromFile(CommandID, DataToImport) Export
//       // Implementing logic of data search in the application..
//       EndProcedure
//       //  Imports mapped data into the infobase. 
//       //
//       // Parameters:
//       //   CommandID - String - a command name determined using function ExternalDataProcessorInfo().
//       //   DataToImport - ValueTable - details of data to import:
//       //       * MappedObject - CatalogRef - a reference to the mapped object.
//       //       * RowMappingResult - String - an import status, possible values: Created, Updated, and Skipped.
//       //       * ErrorDetails - String - data import error details.
//       //       * ID - Number - a unique row number.
//       //       * <other columns> - String - data imported from the file.
//       //
//       //        Columns are the same as in the ImportingFromFile template.
//       	//   ImportParameters - Structure - parameters with custom settings of data import.
//       //       * CreateNewItems        - Boolean - indicates whether new catalog items are to be created.
// //       * UpdateExistingItems - Boolean - indicates whether catalog items are to be updated.
// //   Cancel - Boolean - indicates whether data import is canceled.
// //
// Procedure LoadFromFile(CommandID, DataToImport, ImportParameters, Cancel) Export
// // Implementing logic of data import into the application.
// EndProcedure
//
// Returns:
//   String - a name of a type of commands for importing data from a file.
//
Function CommandTypeDataImportFromFile() Export
	
	Return "ImportDataFromFile"; // Internal ID.
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Form type names. Used during assignable object setup.

// List form ID.
//
// Returns:
//   String - an ID of list forms.
//
Function ListFormType() Export
	
	Return "ListForm"; // Internal ID.
	
EndFunction

// Object form ID.
//
// Returns:
//   String - an ID of object forms.
//
Function ObjectFormType() Export
	
	Return "ObjectForm"; // Internal ID.
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Filter for dialog boxes used to select or save additional reports or data processors.
//
// Returns:
//   String - filter for dialog boxes used to select or save additional reports or data processors.
//
Function SelectingAndSavingDialogFilter() Export
	
	Filter = NStr("en = 'External reports and data processors (*.%1, *.%2)|*.%1;*.%2|External reports (*.%1)|*.%1|External data processors (*.%2)|*.%2';");
	Filter = StringFunctionsClientServer.SubstituteParametersToString(Filter, "erf", "epf");
	Return Filter;
	
EndFunction

// Name of the section that matches the start page.
//
// Returns:
//   String - name of the section that matches the start page.
//
Function StartPageName() Export
	
	Return "Desktop"; 
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Use AdditionalReportsAndDataProcessorsClientServer.StartPageName instead.
// Name of the section that matches the start page.
//
// Returns:
//   String
//
Function DesktopID() Export
	
	Return "Desktop"; 
	
EndFunction

#EndRegion

#EndRegion

#Region Private

// Defines whether the job schedule is set.
//
// Parameters:
//   Schedule - JobSchedule - scheduled job schedule.
//
// Returns:
//   Boolean - True if the job schedule is set.
//
Function ScheduleSpecified(Schedule) Export
	
	Return Schedule = Undefined
		Or String(Schedule) <> String(New JobSchedule);
	
EndFunction

#EndRegion
