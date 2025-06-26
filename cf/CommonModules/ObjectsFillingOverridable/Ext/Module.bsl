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

// Determines the list of configuration objects in whose manager modules this procedure is available 
// AddFillCommands that generates object filling commands.
// See the manual for the AddFillCommands procedure syntax.
//
// Parameters:
//   Objects - Array of MetadataObject - metadata objects with filling commands.
//
// Example:
//  Objects.Add(Metadata.Catalogs.Companies);
//
Procedure OnDefineObjectsWithFIllingCommands(Objects) Export
	
EndProcedure

// Defines common population commands.
//
// Parameters:
//   FillingCommands - ValueTable - Generated commands to be shown in the submenu:
//     
//     Common settings
//       * Id - String - a command ID.
//     
//     Appearance settings:
//       * Presentation - String   - Command presentation in a form.
//       * Importance      - String   - a submenu group to display the command in.
//                                    Options: "Important", "Ordinary" and "SeeAlso".
//       * Order       - Number    - an order of placing the command in the submenu. It is used to set up a particular
//                                    workplace.
//       * Picture      - Picture - a command picture.
//     
//     Visibility and availability settings:
//       * ParameterType - TypeDescription - types of objects that the command is intended for.
//       * VisibilityInForms    - String - comma-separated names of forms on which the command is to be displayed.
//                                        Used when commands differ for various forms.
//       * FunctionalOptions - String - Comma-delimited names of functional options that affect the command visibility.
//       * VisibilityConditions    - Array - defines the command visibility depending on the context.
//                                        To register conditions, use procedure
//                                        AttachableCommands.AddCommandVisibilityCondition.
//                                        The conditions are combined by "And".
//     
//     :
//       * MultipleChoice - Boolean
//                            - Undefined - if True (default value), the command supports multiple choice.
//             In this case, a list of references will be passed in the execution parameter.
//       * WriteMode - String - actions associated with object writing that are executed before the command handler:
//            "Write"            - write only new and modified objects (default).
//                                      Before writing or posting the object, users are asked for confirmation.
//            "DoNotWrite"          - do not write the object and pass
//                                      the full form in the handler parameters instead of references. In this mode, we recommend that you operate directly with a form
//                                      that is passed in the structure of parameter 2 of the command handler.
//            "WriteNewOnly" - write only new objects.
//            "Post"             - post documents.
//       * FilesOperationsRequired - Boolean - If True, in the web client, users are prompted
//             to install 1C:Enterprise Extension. The default value is False.
//     
//     Handler settings:
//       * Manager - String - an object responsible for executing the command.
//       * FormName - String - name of the form to be retrieved for the command execution.
//             If Handler is not specified, the "Open" form method is called.
//       * FormParameters - Undefined
//                        - FixedStructure - Parameters of the form specified in FormName.
//       * Handler - String - details of the procedure that handles the main action of the command.
//             Format "<CommonModuleName>.<ProcedureName>" is used when the procedure is in a common module.
//             Format "<ProcedureName>" is used in the following cases:
//               if FormName is filled, a client procedure is expected in the specified form module;
//               if FormName is not filled, a server procedure is expected in the manager module.
//       * AdditionalParameters - FixedStructure - Handler parameters specified in Handler.
//   
//   Parameters - Structure - information about execution context:
//       * FormName - String - Form full name.
//   StandardProcessing - Boolean - if False, the AddFillCommands event of the object manager
//                                   is not called.
//
Procedure BeforeAddFillCommands(FillingCommands, Parameters, StandardProcessing) Export
	
EndProcedure

#EndRegion
