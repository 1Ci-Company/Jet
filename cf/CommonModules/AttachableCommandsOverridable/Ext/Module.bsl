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

// Using the OnDefineAttachableCommandsKinds you can define the native kinds of attachable commands
// in addition to those already listed in the standard package (print forms, reports and population commands).
//
// Parameters:
//   AttachableCommandsKinds - ValueTable - supported command kinds:
//       * Name         - String            - a command kind name. It must meet the requirements of naming variables and
//                                           be unique (do not match the names of other kinds).
//                                           It can correspond to the name of the subsystem responsible for the output of these commands.
//                                           These names are reserved: Print, Reports, and ObjectsFilling.
//       * SubmenuName  - String            - a submenu name for placing commands of this kind on the object forms.
//       * Title   - String            - the name of the submenu that is displayed to a user.
//       * Picture    - Picture          - a submenu picture.
//       * Representation - ButtonRepresentation - a submenu representation mode.
//       * Order     - Number             - submenu order in the command bar of the form object in relation 
//                                           to other submenus. It is used when automatically creating a submenu 
//                                           in the object form.
//
// Example:
//
//	Kind = AttachableCommandsKinds.Add();
//	Kind.Name         = Motivators;
//	Kind.SubmenuName  = MotivatorsSubmenu;
//	Kind.Title   = NStr(en = Motivators);
//	Kind.Picture    = PicturesLib.Info;
//	Picture.Representation = ButtonRepresentation.PictureAndText;
//	
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export
	
	
	
EndProcedure

// It allows you to expand the Settings parameter composition of the OnDefineSettings procedure in the manager modules of reports and 
// data processors included in the AttachableReportsAndDataProcessors subsystem. Using it, reports and data processors can 
// report that they provide certain command types and interact with the subsystems through their 
// application interface.
//
// Parameters:
//  InterfaceSettings4 - ValueTable:
//   * Key              - String        - Setting name. For example, AddMotivators.
//   * TypeDescription     - TypeDescription - Setting type. For example, New TypeDescription("Boolean").
//   * AttachableObjectsKinds - String - Comma-separated metadata object types for which this setting will be available.
//                                             For example, "Report" or "Report, Data processor".
//
// Example:
//  To provide a custom AddMotivators flag in the OnDefineSettings of the data processor module:
//  Procedure OnDefineSettings(Settings) Export
//    Settings.AddMotivators = True; // Call the AddMotivators procedure.
//    Settings.Location.Add(Metadata.Documents.Questionnaires);
//  EndProcedure
//
//  Implement the following code:
//  Setting = InterfaceSettings4.Add();
//  Setting.Key = "AddMotivators";
//  Setting.TypeDescription = New TypeDescription("Boolean");
//  Setting.AttachableObjectsKinds = "DataProcessor";
//
Procedure OnDefineAttachableObjectsSettingsComposition(InterfaceSettings4) Export
	
	
	
EndProcedure

// It is called once during the first generation of the list of commands that are output in the form of a specific configuration object.
// Return the list of added commands in the Commands parameter.
// The result is cached using a module with repeated use of return values (by form names).
//
// Parameters:
//   FormSettings - Structure - information about the form where the commands are displayed. For reading:
//         * FormName - String - a full name of the form, where the attachable commands are output. 
//                               For example, "Document.Questionnaire.ListForm".
//   
//   Sources - ValueTree - information about the command providers of this form. 
//         The second tree level can contain sources that are registered automatically when the owner is registered.
//         For example, journal register documents:
//         * Metadata - MetadataObject - object metadata.
//         * FullName  - String           - a full object name. For example: "Document.DocumentName".
//         * Kind        - String           - an object kind in uppercase. For example, "CATALOG".
//         * Manager   - Arbitrary     - an object manager module or Undefined if the object 
//                                           does not have a manager module or if it could not be received.
//         * Ref     - CatalogRef.MetadataObjectIDs - a metadata object reference.
//         * IsDocumentJournal - Boolean - True if the object is a document journal.
//         * DataRefType     - Type
//                               - TypeDescription - an item reference type.
//   
//   AttachedReportsAndDataProcessors - ValueTable - reports and data processors, providing their commands 
//         for the Sources objects:
//         * FullName - String       - Full name of a metadata object.
//         * Manager  - Arbitrary - a metadata object manager module.
//         See column content in AttachableCommandsOverridable.OnDefineAttachableObjectsSettingsComposition.
//   
//   Commands - ValueTable - write the generated commands to this parameter for output in submenu: 
//       * Kind - String - Command kind.
//           Details See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds.
//       * Id - String - a command ID.
//       
//       1) Appearance settings.
//       * Presentation - String   - Command presentation in a form.
//       * Importance      - String   - a suffix of a submenu group, in which the command is to be output.
//                                    The following values are acceptable: "Important", "Ordinary", and "SeeAlso".
//       * Order       - Number    - a command position in the group. It is used to set up a particular
//                                    workplace. Can be specified in the range from 1 to 100. The default position is 50.
//       * Picture      - Picture - a command picture. Optional.
//       * Shortcut - Shortcut - a shortcut for fast command call. Optional.
//       * OnlyInAllActions - Boolean - display the command only in the "More actions" menu.
//       * CheckMarkValue - String - a path to the attribute that contains the command mark value. If the command source is a  
//                                    Form table, you can use the %Source % parameter.
//                                    Example:
//                                    "MarksValue.%Source %", where MarksValue is a form attribute of the arbitrary type 
//                                                                                        that contains the structure.
//                                    "Object.DeletionMark", where Object is a form attribute of the CatalogObject type.
//     
//       2) Visibility and accessibility settings.
//       * ParameterType - TypeDescription - types of objects that the command is intended for.
//       * VisibilityInForms    - String - comma-separated names of forms on which the command is to be displayed.
//                                        Used when commands differ for various forms.
//       * Purpose          - String - defines kinds of forms, for which the command is intended. 
//                                        Available values:
//                                         "ForList" - show the command only as a list,
//                                         "ForObject" - show the command only as an object.
//                                        If the parameter is not specified, the command is intended for all kinds of forms.
//       * FunctionalOptions - String - Comma-delimited names of functional options that affect the command visibility.
//       * VisibilityConditions    - Array - Defines the command conditional visibility.
//                                        To add conditions, use procedure AttachableCommands.AddCommandVisibilityCondition().
//                                        Use "And" to specify multiple conditions.
//                                        
//       * ChangesSelectedObjects - Boolean - defines whether the command is available in case
//                                        a user is not authorized to edit the object.
//                                        If True, the button will be unavailable.
//                                        Optional. Default value is False.
//     
//       3) Execution process settings.
//       * MultipleChoice - Boolean - if True, then the command supports multiple choice.
//             In this case, the parameter is passed via a list.
//             Optional. Default value is True.
//       * WriteMode - String - actions associated with object writing that are executed before the command handler:
//             "DoNotWrite"          - do not write the object and pass
//                                          the full form in the handler parameters instead of references. In this mode, we recommend that you operate directly with a form
//                                          that is passed in the structure of parameter 2 of the command handler.
//             "WriteNewOnly" - write only new objects.
//             "Write"            - write only new and modified objects.
//             "Post"             - post documents.
//             Before writing or posting the object, users are asked for confirmation.
//             Optional. Default value is "Write".
//       * FilesOperationsRequired - Boolean - If True, in the web client, users are prompted to
//             install 1C:Enterprise Extension. Optional. The default value is False.
//     
//       4) Handler settings.
//       * Manager - String - an object responsible for executing the command.
//       * FormName - String - name of the form to be retrieved for the command execution.
//           If Handler is not specified, the "Open" form method is called.
//       * FormParameterName - String - Name of the form parameter to pass a reference or a reference array to.
//       * FormParameters - Undefined
//                        - Structure - form parameters specified in formName. Optional.
//       * Handler - String - Describes the procedure that handles the main command action.:
//           The format is "<CommonModuleName>.<ProcedureName>" if the procedure is located in a common module.
//           The format is "<ProcedureName>" in the following cases:
//             • If "FormName" is passed, the client procedure is expected in the object's module manager.
//             • If "FormName" is not passed, the server procedure is expected in the object's module manager.
//           The handler takes two parameters:
//           ## CommandParameter - Array of AnyRef - A list of objects for which the command is executed.
//           ## CommandExecutionParameters - See AttachableCommandsClient.CommandExecuteParameters
//       * AdditionalParameters - Structure - parameters of the handler specified in Handler. Optional.
//
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	
	
	
EndProcedure

#EndRegion
