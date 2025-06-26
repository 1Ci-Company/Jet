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

// Overrides settings of commands of input on basis.
//
// Parameters:
//  Settings - Structure:
//   * UseInputBasedOnCommands - Boolean - allows using application commands of input on basis
//                                                    instead of the standard ones. The default value is True.
//
Procedure OnDefineSettings(Settings) Export
	
EndProcedure

// Specifies the list of configuration objects whose manager modules contain the AddGenerationCommands procedure, 
// which creates commands for generating objects based on other objects.
// See the SSL documentation for the procedure syntax.
//
// Parameters:
//   Objects - Array - metadata objects (MetadataObject) with commands of creation on basis.
//
// Example:
//  Objects.Add(Metadata.Catalogs.Companies);
//
Procedure OnDefineObjectsWithCreationBasedOnCommands(Objects) Export
	
	

EndProcedure

// Called once to generate the GenerationCommands list when it is first
// required. After that, the result is cached by the memorization module.
// Here you can define generation commands that are common for most configuration objects.
//
// Parameters:
//   GenerationCommands - ValueTable - Generated commands to be shown in the submenu:
//     
//     Common settings
//       * Id - String - a command ID.
//     
//     Appearance settings:
//       * Presentation - String   - Command presentation in a form.
//       * Importance      - String   - a submenu group to display the command in.
//                                    The following values are acceptable: "Important", "Ordinary", and "SeeAlso".
//       * Order       - Number    - an order of placing the command in the submenu. It is used to set up a particular
//                                    workplace.
//       * Picture      - Picture - a command picture.
//     
//     Visibility and availability settings:
//       * ParameterType - TypeDescription - types of objects that the command is intended for.
//       * VisibilityInForms    - String - Comma-delimited names of the forms to add a command to.
//                                        Use to add different set of commands to different forms.
//       * FunctionalOptions - String - Comma-delimited names of functional options that affect the command visibility.
//       * VisibilityConditions    - Array - Defines the command conditional visibility.
//                                        To add conditions, use procedure AttachableCommands.AddCommandVisibilityCondition().
//                                        Use "And" to specify multiple conditions.
//                                        
//       * ChangesSelectedObjects - Boolean - defines whether the command is available in case
//                                        a user is not authorized to edit the object.
//                                        If True, the button will be unavailable.
//                                        Optional. The default value is False.
//     
//     Execution process settings:
//       * MultipleChoice - Boolean
//                            - Undefined - if True, then the command supports multiple choice.
//             In this case, the parameter is passed via a list.
//             Optional. Default value is False.
//       * WriteMode - String - actions associated with object writing that are executed before the command handler.
//             "DoNotWrite"          - do not write the object and pass
//                                       the full form in the handler parameters instead of references. In this mode, we recommend that you operate directly with a form
//                                       that is passed in the structure of parameter 2 of the command handler.
//             "WriteNewOnly" - Write only new objects.
//             "Write"            - Write only new and modified objects.
//             "Post"             - Post documents.
//             Before writing or posting the object, users are asked for confirmation.
//             Optional. Default value is "Write".
//       * FilesOperationsRequired - Boolean - If True, in the web client, users are prompted
//             to install 1C:Enterprise Extension.
//             Optional. The default value is False.
//     
//     Handler settings:
//       * Manager - String - an object responsible for executing the command.
//       * FormName - String - name of the form to be retrieved for the command execution.
//             If Handler is not specified, the "Open" form method is called.
//       * FormParameters - Undefined
//                        - FixedStructure - -- optional. Form parameters specified in FormName.
//       * Handler - String - details of the procedure that handles the main action of the command.
//             Format "<CommonModuleName>.<ProcedureName>" is used when the procedure is in a common module.
//             Format "<ProcedureName>" is used in the following cases:
//               1) If FormName is filled, a client procedure is expected in the specified form module.
//               2) If FormName is not filled, a server procedure is expected in the manager module.
//       * AdditionalParameters - FixedStructure - optional. Parameters of the handler specified in Handler.
//   
//   Parameters - Structure - information about execution context:
//       * FormName - String - Form full name.
//
//   StandardProcessing - Boolean - If False, the object manager's AddGenerationCommands event
//                                   is not called.
//
Procedure BeforeAddGenerationCommands(GenerationCommands, Parameters, StandardProcessing) Export

EndProcedure

// Defines the list of generation commands. Called before the object manager's
// AddGenerationCommands call.
//
// Parameters:
//  Object - MetadataObject - an object for which the commands are added.
//  GenerationCommands - See GenerateFromOverridable.BeforeAddGenerationCommands.GenerationCommands
//  Parameters - See GenerateFromOverridable.BeforeAddGenerationCommands.Parameters
//  StandardProcessing - Boolean - If False, the object manager's AddGenerationCommands event
//                                  is not called.
//
Procedure OnAddGenerationCommands(Object, GenerationCommands, Parameters, StandardProcessing) Export
	
	
	
EndProcedure

#EndRegion