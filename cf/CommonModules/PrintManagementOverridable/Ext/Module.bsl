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

// Overrides subsystem settings.
//
// Parameters:
//  Settings - Structure:
//   * UseSignaturesAndSeals - Boolean - If False, the inserting signatures and stamps in print forms is disabled. 
//                                           
//   * HideSignaturesAndSealsForEditing - Boolean - If True, remove the images of signatures and stamps when a user clears the
//                                           "Stamps and signatures" checkbox to be able to edit the text behind them.
//                                           
//   * CheckPostingBeforePrint    - Boolean - Flag indicating whether to check if documents are posted before printing out.
//                                        By default, True for the Print command. Unposted documents are not printed.
//                                        See PrintManagement.CreatePrintCommandsCollection.
//                                        If the parameters is not passed, the check is skipped.
//                                        
//   * PrintObjects - Array - Managers of objects with the OnDefinePrintSettings procedure.
//
Procedure OnDefinePrintSettings(Settings) Export
	
	Settings.PrintObjects.Add(Documents.SupplierInvoice);
	Settings.PrintObjects.Add(Documents.SalesInvoice);
	
EndProcedure

// Allows to override a list of print commands in an arbitrary form.
// Can be used for common forms that do not have a manager module to place the AddPrintCommands procedure in it
// and when the standard functionality is not enough to add commands to such forms. 
// For example, if common forms require specific print commands.
// It is called from the PrintManagement.FormPrintCommands.
// 
// Parameters:
//  FormName             - String - a full name of form, in which print commands are added;
//  PrintCommands        - See PrintManagement.CreatePrintCommandsCollection
//  StandardProcessing - Boolean - when setting to False, the PrintCommands collection will not be filled in automatically.
//
// Example:
//  If FormName = "CommonForm.DocumentJournal" Then
//    If Users.RolesAvailable("PrintProformaInvoiceToPrinter") Then
//      PrintCommand = PrintCommands.Add();
//      PrintCommand.ID = "Invoice";
//      PrintCommand.Presentation = NStr("en = 'Proforma invoice to printer)'");
//      PrintCommand.Picture = PictureLib.PrintImmediately;
//      PrintCommand.CheckPostingBeforePrint = True;
//      PrintCommand.SkipPreview = True;
//    EndIf;
//  EndIf;
//
Procedure BeforeAddPrintCommands(FormName, PrintCommands, StandardProcessing) Export
	
EndProcedure

// Allows to set additional print command settings in document journals.
//
// Parameters:
//  ListSettings - Structure - Modifiers of print command lists::
//   * PrintCommandsManager     - CommonModule - an object manager, in which the list of print commands is generated;
//   * AutoFilling - Boolean - filling print commands from the objects included in the journal.
//                                         If the value is False, the list of journal print commands will be
//                                         filled by calling the AddPrintCommands method from the journal manager module.
//                                         The default value is True - the AddPrintCommands method will be called from
//                                         the document manager modules from the journal.
//
// Example:
//   If ListSettings.PrintCommandsManager = "DocumentJournal.WarehouseDocuments" Then
//     ListSettings.Autofill = False;
//   EndIf;
//
Procedure OnGetPrintCommandListSettings(ListSettings) Export
	
EndProcedure

// Allows you to post-process print forms while generating them.
// For example, you can insert a generation date into a print form.
// It is called after completing the Print procedure of the object print manager and has the same parameters.
// Not called upon calling PrintManagementClient.PrintDocuments.
//
// Parameters:
//  ObjectsArray - Array of AnyRef - a list of objects for which the print command is being executed;
//  PrintParameters - Structure - arbitrary parameters passed when calling the print command;
//  PrintFormsCollection - ValueTable - Return parameter. A collection of generated print forms:
//   * TemplateName - String - print form ID;
//   * TemplateSynonym - String - a print form name;
//
//   * SpreadsheetDocument - SpreadsheetDocument - Print forms output to a spreadsheet.
//                         To layout print forms inside a spreadsheet, after outputting every print form,
//                         call the PrintManagement.SetDocumentPrintArea procedure.
//                         The parameter is not used if print forms are output in an office document.
//                         See the OfficeDocuments parameter.
//
//   * OfficeDocuments - Map of KeyAndValue - Collection of print forms in the format of office documents:
//                         ** Key - String - an address in the temporary storage of binary data of the print form;
//                         ** Value - String - a print form file name.
//
//   * PrintFormFileName - String - a print form file name upon saving to a file or sending as
//                                      an email attachment. Do not use for print forms in the office document format.
//                                      By default, a file name is set as
//                                      "[НазваниеПечатнойФормы] # [Номер] from [Дата]" for documents and
//                                      "[НазваниеПечатнойФормы] — [ПредставлениеОбъекта] — [ТекущаяДата]" for objects.
//                           - Map of KeyAndValue - Filenames for each object:
//                              ** Key - AnyRef - a reference to a print object from the ObjectsArray collection;
//                              ** Value - String - file name;
//
//   * Copies2 - Number - a number of copies to be printed;
//   * FullTemplatePath - String - used for quick access to print form template editing
//                                  in the PrintDocuments common form;
//   * OutputInOtherLanguagesAvailable - Boolean - set to True if the print form is adapted
//                                            for output in an arbitrary language.
//  
//  PrintObjects - ValueList - Output parameter. A mapping between objects and area names in spreadsheets
//                                   . It is filled automatically upon calling
//                                   PrintManagement.SetDocumentPrintArea::
//   * Value - AnyRef - a reference from the ObjectsArray collection,
//   * Presentation - String - an area name with the object in spreadsheet documents;
//
//  OutputParameters - Structure - Print form output settings:
//   * SendOptions - Structure - Interned for autofilling fields in the message creation form upon sending generated print forms by email 
//                                     :
//     ** Recipient - 
//     ** Subject       - 
//     ** Text      - 
//   * LanguageCode - String - a language in which the print form needs to be generated.
//                         Consists of the ISO 639-1 language code and the ISO 3166-1 country code (optional)
//                         separated by the underscore character. Examples: "en", "en_US", "en_GB", "ru", "ru_RU".
//
//   * FormCaption - String - overrides title of the document printing form (PrintDocuments).
//
// Example:
//
//  PrintForm = PrintManagement.PrintFormInfo(PrintFormsCollection, "<PrintFormID>");
//  If PrintForm <> Undefined Then
//    SpreadsheetDocument = New SpreadsheetDocument;
//    SpreadsheetDocument.PrintParametersKey = "<PrintFormParametersSaveKey>"
//    For Each Ref In ObjectsArray Do
//      If SpreadsheetDocument.TableHeight > 0 Then
//        SpreadsheetDocument.PutHorizontalPageBreak();
//      EndIf;
//      AreaStart = SpreadsheetDocument.TableHeight + 1;
//      // … code for spreadsheet document generation …
//      PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, AreaStart, PrintObjects, Ref);
//    EndDo;
//    PrintForm.SpreadsheetDocument = SpreadsheetDocument;
//  EndIf;
//
Procedure OnPrint(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	
	
EndProcedure

// Intended for overriding print form data before it's generated.
//
// Parameters:
//  PrintFormID - String - print form ID;
//  PrintObjects      - Array    - a collection of references to print objects;
//  PrintParameters - Structure - arbitrary parameters passed when calling the print command;
//
Procedure BeforePrint(Val PrintFormID, PrintObjects, PrintParameters) Export 
	
	
	
EndProcedure

// Overrides the print form send parameters when preparing a message.
// It can be used, for example, to prepare a message text.
//
// Parameters:
//  SendOptions - Structure:
//   * Recipient - Array - a collection of recipient names;
//   * Subject - String - an email subject;
//   * Text - String - an email text;
//   * Attachments - Structure:
//    ** AddressInTempStorage - String - an attachment address in a temporary storage;
//    ** Presentation - String - an attachment file name.
//  PrintObjects - Array - a collection of objects, by which print forms are generated.
//  OutputParameters - Structure - the OutputParameters parameter when calling the Print procedure.
//  PrintForms - ValueTable - Collection of spreadsheet documents:
//   * Name1 - String - a print form name;
//   * SpreadsheetDocument - SpreadsheetDocument - print form.
//
Procedure BeforeSendingByEmail(SendOptions, OutputParameters, PrintObjects, PrintForms) Export
	
	
	
EndProcedure

// Defines a set of signatures and stamps for documents.
//
// Parameters:
//  Var_Documents      - Array    - a collection of references to print objects;
//  SignaturesAndSeals - Map of KeyAndValue - Collection of print objects and their sets of signatures and stamps:
//   * Key     - AnyRef - a reference to the print object;
//   * Value - Structure   - Set of signatures and stamps:
//     ** Key     - String - Identifier of a signature or stamp in print form template. 
//                            It must end with "Signature…", "Stamp…", or "Facsimile".
//                            For example, ManagerSignature or CompanyStamp.
//     ** Value - Picture - Signature or stamp image.
//
Procedure OnGetSignaturesAndSeals(Var_Documents, SignaturesAndSeals) Export
	
	
	
EndProcedure

// It is called from the OnCreateAtServer handler of the document print form (CommonForm.PrintDocuments).
// Allows to change form appearance and behavior, for example, place the following additional items on it:
// information labels, buttons, hyperlinks, various settings, and so on.
//
// When adding commands (buttons), specify the Attachable_ExecuteCommand name as a handler
// and place its implementation either to PrintManagementOverridable.PrintDocumentsOnExecuteCommand (server part),
// or to PrintManagementClientOverridable.PrintDocumentsExecuteCommand (client part).
//
// To add your command to the form.
// 1. Create a command and a button in PrintManagementOverridable.PrintDocumentsOnCreateAtServer.
// 2. Implement the command client handler in PrintManagementClientOverridable.PrintDocumentsExecuteCommand.
// 3. (Optional) Implement server command handler in PrintManagementOverridable.PrintDocumentsOnExecuteCommand.
//
// When adding hyperlinks as a click handler, specify the Attachable_URLProcessing name
// and place its implementation to PrintManagementClientOverridable.PrintDocumentsURLProcessing.
//
// When placing items whose values must be remembered between print form openings,
// use the PrintDocumentsOnImportDataFromSettingsAtServer and
// PrintDocumentsOnSaveDataInSettingsAtServer procedures.
//
// Parameters:
//  Form                - ClientApplicationForm - the CommonForm.PrintDocuments form.
//  Cancel                - Boolean - indicates that the form creation is canceled. If this parameter is set
//                                  to True, the form is not created.
//  StandardProcessing - Boolean - a flag indicating whether the standard (system) event processing is executed is passed to this
//                                  parameter. If this parameter is set to False, 
//                                  standard event processing will not be carried out.
// 
// Example:
//  FormCommand = Form.Command.Add("MyCommand");
//  FormCommand.Action = "Attachable_ExecuteCommand";
//  FormCommand.Header = NStr("en = 'MyCommand…'");
//  
//  FormButton = Form.Items.Add(FormCommand.Name, Type("FormButton"), Form.Items.CommandBarRightPart);
//  FormButton.Kind = FormButtonKind.CommandBarButton;
//  FormButton.CommandName = FormCommand.Name;
//
Procedure PrintDocumentsOnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	
	
EndProcedure

// It is called from the OnImportDataFromSettingsAtServer handler of the document print form (CommonForm.PrintDocuments).
// Together with PrintDocumentsOnSaveDataInSettingsAtServer, it allows you to import and save form control 
// settings placed using PrintDocumentsOnCreateAtServer.
//
// Parameters:
//  Form     - ClientApplicationForm - the CommonForm.PrintDocuments form.
//  Settings - Map     - form attribute values.
//
Procedure PrintDocumentsOnImportDataFromSettingsAtServer(Form, Settings) Export
	
EndProcedure

// It is called from the OnSaveDataInSettingsAtServer handler of the document print form (CommonForm.PrintDocuments).
// Together with PrintDocumentsOnImportDataFromSettingsAtServer, it allows you to import and save form control 
// settings placed using PrintDocumentsOnCreateAtServer.
//
// Parameters:
//  Form     - ClientApplicationForm - the CommonForm.PrintDocuments form.
//  Settings - Map     - form attribute values.
//
Procedure PrintDocumentsOnSaveDataInSettingsAtServer(Form, Settings) Export

EndProcedure

// It is called from the Attachable_ExecuteCommand handler of the document printing form (CommonForm.PrintDocuments).
// It allows you to implement server part of the command handler added to the form 
// using PrintDocumentsOnCreateAtServer.
//
// Parameters:
//  Form                   - ClientApplicationForm - the CommonForm.PrintDocuments form.
//  AdditionalParameters - Arbitrary     - parameters passed from PrintManagementClientOverridable.PrintDocumentsExecuteCommand.
//
// Example:
//  If TypeOf(AdditionalParameters) = Type("Structure") AND AdditionalParameters.CommandName = "MyCommand" Then
//   SpreadsheetDocument = New SpreadsheetDocument;
//   SpreadsheetDocument.Area("R1C1").Text = NStr("en = 'An example of using a server handler of the attached command.'");
//  
//   PrintForm = Form[AdditionalParameters.SpreadsheetDocumentAttributeName];
//   PrintFrom.InsertArea(SpreadsheetDocument.Area("R1"), PrintForm.Area("R1"), 
//    SpreadsheetDocumentShiftType.Horizontally)
//  EndIf;
//
Procedure PrintDocumentsOnExecuteCommand(Form, AdditionalParameters) Export
	
EndProcedure

// Determines the used print data template for metadata objects and individual fields.
// By default, the "PrintData" template is used for Ref data.
// If the template is missing in metadata, 1C:Enterprise generates it based on the set of the selected object attributes.
// The procedure allows for overriding the printable fields for the entire object or individual fields.
//
// Parameters:
//  Object - String - Full name of a metadata object.
//                      Or the name of the field from the PrintData template in the format "FullMetadataName.FieldName".
//  PrintDataSources - ValueList:
//    * Value - DataCompositionSchema - Print data schema. It determines the list of fields subordinate to an object or another field.
//                                         It is used for obtaining print data, which filters values by the Ref field.
//                                         Therefore, the Ref field is mandatory for data composition schemas event if the data it contains has another type.
//                                         
//                                         
//                                         
//      
//    * Presentation - String - Schema ID. Intended to export data.
//    * Check -Boolean - True if the key field is the data source owner.
//
Procedure OnDefinePrintDataSources(Object, PrintDataSources) Export
	
	
	
EndProcedure

// Prepares printable data.
//
// Parameters:
//  DataSources - Array - Objects whose data is being printed out.
//  ExternalDataSets - Structure - Collection of datasets to pass to the data composition processor.
//  DataCompositionSchemaId - String - DCS ID specified in 
//  LanguageCode - String - Language of the data being printed out.
//  AdditionalParameters - Structure:
//   * DataSourceDescriptions - ValueTable - Additional info about objects whose data is being printed out.
//   * SourceDataGroupedByDataSourceOwner - Boolean - Flag indicating whether after composing the print data is grouped in the print schema by the print object owner.
//                           
//  
Procedure WhenPreparingPrintData(DataSources, ExternalDataSets, DataCompositionSchemaId, LanguageCode,
	AdditionalParameters) Export
	
	
	
EndProcedure

// Allows to specify additional print command settings.
//
// Parameters:
//   FullMetadataObjectName   - MetadataObject - Object the command sources are attached to
//   PrintCommands 		- See PrintManagement.CreatePrintCommandsCollection
//
Procedure OnReceivePrintCommands(Val FullMetadataObjectName, PrintCommands) Export
	
	
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Deprecated. Use PrintManagementOverridable.OnDefinePrintSettings instead.
// Defines configuration objects, in whose manager modules the AddPrintCommands procedure is placed.
// The procedure generates a print command list provided by this object.
// See the AddPrintCommands procedure in the subsystem documentation.
//
// Parameters:
//  ListOfObjects - Array - object managers with the AddPrintCommands procedure.
//
Procedure OnDefineObjectsWithPrintCommands(ListOfObjects) Export
		
EndProcedure

#EndRegion

#EndRegion

