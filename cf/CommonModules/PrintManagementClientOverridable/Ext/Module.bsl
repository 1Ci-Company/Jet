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

// It is called after executing the OnOpen handler of document printing form (CommonForm.PrintDocuments).
//
// Parameters:
//  Form - ClientApplicationForm - the CommonForm.PrintDocuments form.
//
Procedure PrintDocumentsAfterOpen(Form) Export
	
EndProcedure

// It is called from the Attachable_URLProcessing handler of the document printing form (CommonForm.PrintDocuments).
// Allows to implement a handler of clicking a hyperlink added to the form 
// using PrintManagementOverridable.PrintDocumentsOnCreateAtServer.
//
// Parameters:
//  Form                - ClientApplicationForm - the CommonForm.PrintDocuments form.
//  Item              - FormField - a form item that caused this event.
//  FormattedStringURL - String - a value of the formatted string URL. It is passed by the link.
//  StandardProcessing - Boolean - indicates a standard (system) event processing execution. If it is set to
//                                  False, standard event processing will not be performed.
//
Procedure PrintDocumentsURLProcessing(Form, Item, FormattedStringURL, StandardProcessing) Export
	
	
	
EndProcedure

// It is called from the Attachable_ExecuteCommand handler of the document printing form (CommonForm.PrintDocuments).
// It allows to implement a client part of the command handler that is added to the form 
// using PrintManagementOverridable.PrintDocumentsOnCreateAtServer.
//
// Parameters:
//  Form                         - ClientApplicationForm - the CommonForm.PrintDocuments form.
//  Command                       - FormCommand     - a running command.
//  ContinueExecutionAtServer - Boolean - when set to True, the handler will continue to run in the server context in
//                                           the PrintManagementOverridable.PrintDocumentsOnExecuteCommand procedure.
//  AdditionalParameters       - Arbitrary - parameters to be passed to the server context.
//
// Example:
//  If Command.Name = "MyCommand" Then
//   PrintFormSetting = PrintManagementClient.CurrentPrintFormSetup(Form);
//   
//   AdditionalParameters = New Structure;
//   AdditionalParameters.Insert("CommandName", Command.Name);
//   AdditionalParameters.Insert("SpreadsheetDocumentAttributeName", PrintFormSetting.AttributeName);
//   AdditionalParameters.Insert("PrintFormName", PrintFormSetting.Name);
//   
//   ContinueExecutionAtServer = True;
//  EndIf;
//
Procedure PrintDocumentsExecuteCommand(Form, Command, ContinueExecutionAtServer, AdditionalParameters) Export
	
EndProcedure

// Called from the NotificationProcessing handler of the PrintDocuments form.
// Allows implementing an external event handler in a form.
//
// Parameters:
//  Form      - ClientApplicationForm - the CommonForm.PrintDocuments form.
//  EventName - String - notification ID.
//  Parameter   - Arbitrary - an arbitrary notification parameter.
//  Source   - Arbitrary - an event source.
//
Procedure PrintDocumentsNotificationProcessing(Form, EventName, Parameter, Source) Export
	
EndProcedure

#EndRegion
