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

// Determines a list of handlers (manager modules or common modules) that generate and update
// the list of all to-do items available in the configuration.
//
// In the specified modules, there must be a handler procedure the parameter is passed to
// ToDoList - See ToDoListServer.ToDoList.
// 
// The following is an example of a handler procedure for copying to the specified modules
//
//Parameters:
//ToDoList - See ToDoListServer.ToDoList.
////
//
//
//Procedure OnFillToDoList(ToDoList) Export
// EndProcedure
//
// Parameters:
//  ToDoList - Array - manager modules or common modules,
//                         for example: Documents.SalesOrder, SalesToDoList.
// Example:
//  ToDoList.Add(Documents.SalesOrder);
//
Procedure OnDetermineToDoListHandlers(ToDoList) Export
	
	
	
EndProcedure

// Sets the default order of sections in the to-do list panel.
//
// Parameters:
//  Sections - Array - an array of command interface sections.
//                     Sections in the To-do list panel are shown in
//                     the order in which they were added to the array.
//
Procedure OnDetermineCommandInterfaceSectionsOrder(Sections) Export
	
	
	
EndProcedure

// Defines to-do items that are hidden from a user.
//
// Parameters:
//  ToDoItemsToDisable - Array - an array of strings IDs of to-do items to disable.
//
Procedure OnDisableToDos(ToDoItemsToDisable) Export
	
EndProcedure

// It allows you to change some subsystem settings.
//
// Parameters:
//  Parameters - Structure:
//     * OtherToDoItemsTitle - String - a title of a section that displays
//                            to-do items not included in any command interface sections.
//                            It is applicable to to-do items whose positions in the panel
//                            are determined by the ToDoListServer.SectionsForObject function.
//                            If this parameter is not specified, to-do items are displayed as a group named
//                            Other to dos.
//
Procedure OnDefineSettings(Parameters) Export
	
	
	
EndProcedure

// Helps to set query parameters that are common for several to-do items.
//
// For example, if several handlers of getting to-do items have
// the CurrentDate parameter, you can add the algorithm that sets the parameter to this
// procedure and then call the
// ToDoList.SetCommonQueryParameters() procedure to set the parameter.
//
// Parameters:
//  Query - Query - a running query.
//  CommonQueryParameters - Structure - common values for calculating to-do items.
//
Procedure SetCommonQueryParameters(Query, CommonQueryParameters) Export
	
EndProcedure

#EndRegion