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

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.IBVersionUpdate

////////////////////////////////////////////////////////////////////////////////
// Info about the library or configuration.

// Fills in main information about the library or base configuration.
// The library that has the same name as the base configuration name in the metadata is considered as a base configuration.
// 
// Parameters:
//  LongDesc - Structure:
//
//   * Name                 - String - a library name (for example, "StandardSubsystems").
//   * Version              - String - a version number in a four-digit format (for example, "2.1.3.1").
//
//   * OnlineSupportID - String - a unique application name in online support services.
//   * RequiredSubsystems1 - Array - names of other libraries (String) the current library depends on.
//                                    Update handlers of such libraries must be called earlier than
//                                    update handlers of the current library.
//                                    If they have circular dependencies or, on the contrary, no dependencies,
//                                    the update handlers are called by the order of adding modules in the
//                                    SubsystemsOnAdd procedure of the
//                                    ConfigurationSubsystemsOverridable common module.
//   * DeferredHandlersExecutionMode - String - Sequentially - deferred update handlers run
//                                    sequentially in the interval from the infobase version
//                                    number to the configuration version number. Parallel - once the first data batch is processed,
//                                    the deferred handler passes control to another handler;
//                                    once the last handler finishes work, the cycle is repeated.
//   * FillDataNewSubsystemsWhenSwitchingFromAnotherProgram - Boolean - If set to True, initial subsystem population handlers
//                                    will run automatically during a migration from another app.
//                                    To disable a custom update handler, provide the property
//                                    "DoNotExecuteWhenSwitchingFromAnotherProgram".
//
Procedure OnAddSubsystem(LongDesc) Export
	
	LongDesc.Name    = "Jet";
	LongDesc.Version = "1.0.1.1";
	LongDesc.DeferredHandlersExecutionMode = "Sequentially";
	
	LongDesc.RequiredSubsystems1.Add("StandardSubsystems");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update handlers.

// Adds infobase data update handlers
// for all supported versions of the library or configuration to the list.
// Called before starting infobase data update to build an update plan.
//
// Parameters:
//  Handlers - See InfobaseUpdate.NewUpdateHandlerTable
//
// Example:
//  To add a custom handler procedure to a list:
//  Handler = Handlers.Add();
//  Handler.Version              = "1.1.0.0";
//  Handler.Procedure           = "IBUpdate.SwitchToVersion_1_1_0_0";
//  Handler.ExecutionMode     = "Seamless";
//
Procedure OnAddUpdateHandlers(Handlers) Export
	
EndProcedure

// See InfobaseUpdateOverridable.BeforeUpdateInfobase.
Procedure BeforeUpdateInfobase() Export
	
EndProcedure

// The procedure is called after the infobase data is updated.
// Depending on conditions, you can turn off regular opening of a form
// containing description of new version updates at first launch of a program (right after an update),
// and also execute other actions.
//
// It is not recommended to execute any kind of data processing in this procedure.
// Such procedures should be applied by regular update handlers executed for each "*" version.
// 
// Parameters:
//   PreviousVersion     - String - The initial version number. For empty infobases, "0.0.0.0".
//   CurrentVersion        - String - version after an update. As a rule, it corresponds with Metadata.Version.
//   CompletedHandlers - ValueTree:
//     * InitialFilling - Boolean - if True, then a handler is started on a launch with an empty base.
//     * Version              - String - for example, "2.1.3.39". Configuration version number.
//                                      The handler is executed when the configuration migrates to this version number.
//                                      If an empty string is specified, this handler is intended for initial filling only
//                                      (when the InitialFilling parameter is specified).
//     * Procedure           - String - the full name of an update handler or initial filling handler. 
//                                      For example, "MEMInfobaseUpdate.FillNewAttribute"
//                                      Must be an export procedure.
//     * ExecutionMode     - String - update handler run mode. The following values are available:
//                                      Exclusive, Deferred, Seamless. If this value is not specified, the handler
//                                      is considered exclusive.
//     * SharedData         - Boolean - if True, the handler is executed prior to
//                                      other handlers that use shared data.
//                                      Is is allowed to specify it only for handlers with Exclusive or Seamless execution mode.
//                                      If the True value is specified for a handler with
//                                      a Deferred execution mode, an exception will be brought out.
//     * HandlerManagement - Boolean - if True, then the handler has a parameter of a Structure type which has
//                                          the SeparatedHandlers property that is the table of values characterized by the structure
//                                          returned by this function.
//                                      In this case the version column is ignored. If separated handler
//                                      execution is required, you have to add a row with
//                                      the description of the handler procedure.
//                                      Makes sense only for required (Version = *) update handlers 
//                                      having a SharedData flag set.
//     * Comment         - String - details for actions executed by an update handler.
//     * Id       - UUID - it must be filled in only for deferred update handlers
//                                                 and not required for others. Helps to identify
//                                                 a handler in case it was renamed.
//     
//     * ObjectsToLock  - String - it must be filled in only for deferred update handlers
//                                      and not required for others. Full names of objects separated by commas. 
//                                      These names must be locked from changing until data processing procedure is finalized.
//                                      If it is not empty, then the CheckProcedure property must also be filled in.
//     * CheckProcedure   - String - It must be filled in only for deferred update handlers
//                                      and not required for others. Name of a function that defines if data processing procedure is finalized 
//                                      for the passed object. 
//                                      If the passed object is fully processed, it must acquire the True value. 
//                                      Called from the InfobaseUpdate.CheckObjectProcessed procedure.
//                                      Parameters that are passed to the function:
//                                         Parameters - See InfobaseUpdate.MetadataAndFilterByData.
//     * UpdateDataFillingProcedure - String - the procedure for registering data
//                                      to be updated by this handler must be specified.
//     * ExecuteInMasterNodeOnly  - Boolean - only for deferred update handlers with a Parallel execution mode.
//                                      Specify as True if an update handler must be executed only in the master
//                                      DIB node.
//     * RunAlsoInSubordinateDIBNodeWithFilters - Boolean - only for deferred update handlers with a Parallel execution
//                                      mode.
//                                      Specify as True if an update handler must also be executed in
//                                      the subordinate DIB node using filters.
//     * ObjectsToRead              - String - objects to be read by the update handler while processing data.
//     * ObjectsToChange            - String - objects to be changed by the update handler while processing data.
//     * ExecutionPriorities         - ValueTable - table of execution priorities for deferred handlers
//                                      changing or reading the same data. For more information, see the commentary
//                                      to the InfobaseUpdate.HandlerExecutionPriorities function.
//     * ExecuteInMandatoryGroup - Boolean - specify this parameter if the handler must be
//                                      executed in the group that contains handlers for the "*" version.
//                                      You can change the order of handlers
//                                      in the group by changing their priorities.
//     * Priority           - Number  - for internal use.
//     * ExclusiveMode    - Undefined
//                           - Boolean - if Undefined, the handler 
//                                      is executed unconditionally in the exclusive mode.
//                                      For handlers that execute migration to a specific version (Version <> *):
//                                        False - handler execution does not require an exclusive mode.
//                                        True - handler execution requires an exclusive mode.
//                                      For required update handlers (Version = "*"):
//                                        False - handler execution does not require an exclusive mode.
//                                        True - handler execution may require an exclusive mode.
//                                                 A parameter of structure type
//                                                 with ExclusiveMode property (of Boolean type) is passed to such handlers.
//                                                 To execute the handler in exclusive mode, set
//                                                 this parameter to True. In this case the handler must perform
//                                                 the required update operations. Changing the parameter
//                                                 in the handler body is ignored.
//                                                 To execute the handler in nonexclusive mode, set this parameter to
//                                                 False. In this case the handler must not make any
//                                                 changes to the infobase.
//                                                 If the analysis reveals that a handler needs to
//                                                 change infobase data, set the parameter value to the True,
//                                                 and stop handler execution.
//                                                 In this case nonexclusive infobase update is
//                                                 canceled and an error message with a recommendation to perform the update in
//                                                 exclusive mode is displayed.
//   OutputUpdatesDetails - Boolean - if False s set, a form
//                                containing description of new version updates will not be opened at first launch of a program. True by default.
//   ExclusiveMode           - Boolean - indicates that an update was executed in an exclusive mode.
//
Procedure AfterUpdateInfobase(Val PreviousVersion, Val CurrentVersion,
		Val CompletedHandlers, OutputUpdatesDetails, Val ExclusiveMode) Export
		
EndProcedure

// See InfobaseUpdateOverridable.OnPrepareUpdateDetailsTemplate.
Procedure OnPrepareUpdateDetailsTemplate(Val Template) Export
	
EndProcedure

// Overrides the infobase update mode.
// Intended for custom migration scenarios.
// 
//
// Parameters:
//   DataUpdateMode - String - Takes one of the values:
//              InitialFilling - The first start of an empty infobase or data area.
//              VersionUpdate - The first start after a configuration update.
//              MigrationFromAnotherApplication - The first start after a configuration update that changes the configuration name. 
//                                          
//
//   StandardProcessing  - Boolean - If False, the standard procedure of the update mode identification is skipped.
//                                    Instead, the DataUpdateMode value is assigned. 
//                                    
//
Procedure OnDefineDataUpdateMode(DataUpdateMode, StandardProcessing) Export
	
EndProcedure

// Adds handlers of migration from another application to the list.
// For example, to migrate between different applications of the same family: Base -> Standard -> CORP.
// The procedure is called before the infobase data update.
//
// Parameters:
//  Handlers - ValueTable:
//    * PreviousConfigurationName - String - a name of the configuration to migrate from
//                                           or an asterisk (*) if must be executed while migrating from any configuration.
//    * Procedure                 - String - full name of a handler procedure for a migration from a program
//                                           PreviousConfigurationName.
//                                  For example, "MEMInfobaseUpdate.FillAdministrativePolicy"
//                                  Must be an export procedure.
//
// Example:
//  Handler = Handlers.Add();
//  Handler.PreviousConfigurationName = "TradeManagement";
//  Handler.Procedure = "MEMInfobaseUpdate.FillAccountingPolicy";
//
Procedure OnAddApplicationMigrationHandlers(Handlers) Export
	
EndProcedure

// Called when all the application migration handlers have been executed
// but before the infobase data update.
//
// Parameters:
//  PreviousConfigurationName    - String - Configuration name before migration.
//  PreviousConfigurationVersion - String - Old configuration version.
//  Parameters                    - Structure:
//    * ExecuteUpdateFromVersion   - Boolean - By default, True. 
//        If False, run only required update handlers (whose version is "*").
//    * ConfigurationVersion           - String - a version number after migration. 
//        By default, it is equal to the configuration version in metadata properties.
//        To execute, for example, all migration handlers from PreviousConfigurationVersion version, 
//        set the parameter value to PreviousConfigurationVersion.
//        To execute all update handlers, set the value to "0.0.0.1".
//    * ClearPreviousConfigurationInfo - Boolean - Default value is True. 
//        When the previous configuration has the same name as the current configuration subsystem,
//        set the parameter to False.
//
Procedure OnCompleteApplicationMigration(PreviousConfigurationName, PreviousConfigurationVersion, Parameters) Export
	
EndProcedure

// End StandardSubsystems.IBVersionUpdate

#EndRegion

#EndRegion
