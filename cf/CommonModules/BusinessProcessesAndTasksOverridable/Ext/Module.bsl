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

// The procedure is called to update business process data in the BusinessProcessesData information register.
//
// Parameters:
//  Record - InformationRegisterRecord.BusinessProcessesData - a business process record.
//
Procedure OnWriteBusinessProcessesList(Record) Export
	
EndProcedure

// The procedure is called to check whether the current user has rights
// to suspend and resume a business process.
//
// Parameters:
//  BusinessProcess        - DefinedType.BusinessProcessObject
//  HasRights            - Boolean - If False, the rights are denied.
//  StandardProcessing - Boolean - If False, the standard rights check is skipped.
//
Procedure OnCheckStopBusinessProcessRights(BusinessProcess, HasRights, StandardProcessing) Export
	
EndProcedure

// The procedure is called to fill in the MainTask attribute from filling data.
//
// Parameters:
//  BusinessProcessObject  - DefinedType.BusinessProcessObject
//  FillingData     - Arbitrary        - filling data that is passed to the filling handler.
//  StandardProcessing - Boolean              - If False, the standard filling processing is
//                                               skipped.
//
Procedure OnFillMainBusinessProcessTask(BusinessProcessObject, FillingData, StandardProcessing) Export
	
EndProcedure

// The function is called to fill in the task form parameters.
//
// Parameters:
//  BusinessProcessName           - String                         - a business process name.
//  TaskRef                - TaskRef.PerformerTask
//  BusinessProcessRoutePoint - BusinessProcessRoutePointRef.Job - action.
//  FormParameters              - Structure:
//   * FormName       - Form name to pass to the OpenForm method. 
//   * FormParameters - parameters of the form to be opened.
//
// Example:
//  If BusinessProcessName = "Job" Then
//      FormName = "BusinessProcess.Job.Form.ExternalAction" + BusinessProcessRoutePoint.Name;
//      FormParameters.Insert("FormName", FormName);
//  EndIf;
//
Procedure OnReceiveTaskExecutionForm(BusinessProcessName, TaskRef,
	BusinessProcessRoutePoint, FormParameters) Export
	
EndProcedure

// Fills in the list of business processes that are attached to the subsystem
// and their manager modules contain the following export procedures and functions:
//  - OnForwardTask.
//  - TaskExecutionForm.
//  - DefaultCompletionHandler.
//
// Parameters:
//   AttachedBusinessProcesses - Map of KeyAndValue:
//     * Key - String - a full name of the metadata object attached to the subsystem;
//     * Value - String - empty string.
//
// Example:
//   AttachedBusinessProcesses.Insert(Metadata.BusinessProcesses.JobWithRoleAddressing.FullName(), "");
//
Procedure OnDetermineBusinessProcesses(AttachedBusinessProcesses) Export
	
	
	
EndProcedure

// It is called from the BusinessProcessesAndTasks subsystem object modules
// to set up restriction logic in the application.
//
// For the example of filling access value sets, see comments
// to AccessManagement.FillAccessValuesSets.
//
// Parameters:
//  Object - BusinessProcessObject.Job - an object for which the sets are populated.
//  Table - See AccessManagement.AccessValuesSetsTable
//
Procedure OnFillingAccessValuesSets(Object, Table) Export
	
	
	
EndProcedure

// Called by the PerformerRoles catalog manager module at the business role initial population.
// 
//
// Parameters:
//  LanguagesCodes - Array of String - a list of configuration languages. Relevant to multilingual configurations.
//  Items   - ValueTable - filling data. Column content matches the attribute set 
//                                 of the PerformerRoles catalog.
//  TabularSections - Structure - object table details where:
//   * Key - String - Table name.
//   * Value - ValueTable - Value table.
//                                  Its structure must be copied before population. For example:
//                                  Item.Keys = TabularSections.Keys.Copy();
//                                  TSItem = Item.Keys.Add();
//                                  TSItem.KeyName = "Primary";
//
Procedure OnInitiallyFillPerformersRoles(LanguagesCodes, Items, TabularSections) Export
	
	
	
EndProcedure

// Called by the PerformerRoles catalog manager module at the business role initial population.
// 
//
// Parameters:
//  Object                  - CatalogObject.PerformerRoles - Object to populate.
//  Data                  - ValueTableRow - filling data.
//  AdditionalParameters - Structure
//
Procedure AtInitialPerformerRoleFilling(Object, Data, AdditionalParameters) Export
	
	
	
EndProcedure

// Called by the CCT TaskAddressingObjects manager module on the task initial population.
// Standard attribute ValueType must populated in the OnInitialFillingTaskAddressingObjectItem procedure.
// 
//
// Parameters:
//  LanguagesCodes - Array of String - a list of configuration languages. Relevant to multilingual configurations.
//  Items   - ValueTable - filling data. Column content matches the attribute set of the TaskAddressingObjects CCT object.
//  TabularSections - Structure - object table details where:
//   * Key - String - Table name.
//   * Value - ValueTable - Value table.
//                                  Its structure must be copied before population. For example:
//                                  Item.Keys = TabularSections.Keys.Copy();
//                                  TSItem = Item.Keys.Add();
//                                  TSItem.KeyName = "Primary";
//
Procedure OnInitialFillingTasksAddressingObjects(LanguagesCodes, Items, TabularSections) Export
	
	
	
EndProcedure

// Called by the CCT TaskAddressingObjects manager module on the task initial population.
// 
//
// Parameters:
//  Object                  - ChartOfCharacteristicTypesObject.TaskAddressingObjects - Object to populate.
//  Data                  - ValueTableRow - filling data.
//  AdditionalParameters - Structure
//
Procedure OnInitialFillingTaskAddressingObjectItem(Object, Data, AdditionalParameters) Export
	
	
	
EndProcedure

#EndRegion
