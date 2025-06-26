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

// The user's to-do items table.
// Is passed to the OnFillToDoList handlers.
//
// Returns:
//  ValueTable - Defines the parameters of a to-do item:
//    * Id  - String - an internal to-do ID used by the subsystem.
//    * HasToDoItems       - Boolean - if True, the to-do item is displayed in the user's to-do list.
//    * Important         - Boolean - if True, the to-do item is highlighted in red.
//    * OutputInNotifications - Boolean - if True, the notification of the item will be duplicated in a pop-up
//                             notification and displayed in the notification center.
//    * HideInSettings - Boolean - if True, the to-do item is hidden from the to-do list settings form.
//                            It can be applied to
//                            nonrecurring to-do items. Once completed, these to-do items are
//                            no longer displayed in the infobase.
//    * Presentation  - String - a to-do item presentation displayed to a user.
//    * Count     - Number  - a number related to a to-do item; it is displayed in a to-do item's title.
//    * Form          - String - a full path to the form that is displayed by clicking on the
//                                to-do item hyperlink in the "To-do list" panel.
//    * FormParameters - Structure - parameters for opening the indicator form.
//    * Owner       - String
//                     - MetadataObject - String ID of the to-do item that is the owner of the current to-do item,
//                       or a subsystem metadata object.
//    * ToolTip      - String - a tooltip text.
//    * ToDoOwnerObject - String - the full name of the metadata object where the handler of the to-do list filling is placed.
//
Function ToDoList() Export
	
	UserTasks1 = New ValueTable;
	UserTasks1.Columns.Add("Id", New TypeDescription("String", New StringQualifiers(250)));
	UserTasks1.Columns.Add("HasToDoItems", New TypeDescription("Boolean"));
	UserTasks1.Columns.Add("Important", New TypeDescription("Boolean"));
	UserTasks1.Columns.Add("Presentation", New TypeDescription("String", New StringQualifiers(250)));
	UserTasks1.Columns.Add("HideInSettings", New TypeDescription("Boolean"));
	UserTasks1.Columns.Add("OutputInNotifications", New TypeDescription("Boolean"));
	UserTasks1.Columns.Add("Count", New TypeDescription("Number"));
	UserTasks1.Columns.Add("Form", New TypeDescription("String", New StringQualifiers(250)));
	UserTasks1.Columns.Add("FormParameters", New TypeDescription("Structure"));
	UserTasks1.Columns.Add("Owner");
	UserTasks1.Columns.Add("ToolTip", New TypeDescription("String", New StringQualifiers(250)));
	UserTasks1.Columns.Add("ToDoOwnerObject", New TypeDescription("String", New StringQualifiers(256)));
	UserTasks1.Columns.Add("HasUserTasks"); // Backward compatibility.
	
	Return UserTasks1;
	
EndFunction

// Returns an array of command interface subsystems containing the passed
// metadata object.
//
// Parameters:
//  MetadataObjectName - String - Full name of a metadata object.
//
// Returns: 
//  Array - an array of command interface subsystems.
//
Function SectionsForObject(MetadataObjectName) Export
	ObjectsBelonging = ToDoListInternalCached.ObjectsBelongingToCommandInterfaceSections();
	
	CommandInterfaceSubsystems = New Array;
	SubsystemsNames                 = ObjectsBelonging.Get(MetadataObjectName);
	If SubsystemsNames <> Undefined Then
		For Each SubsystemName In SubsystemsNames Do
			CommandInterfaceSubsystems.Add(Common.MetadataObjectByFullName(SubsystemName));
		EndDo;
	EndIf;
	
	If CommandInterfaceSubsystems.Count() = 0 Then
		CommandInterfaceSubsystems.Add(DataProcessors.ToDoList);
	EndIf;
	
	Return CommandInterfaceSubsystems;
EndFunction

// Determines whether a to-do item must be displayed in a user's to-do list.
//
// Parameters:
//  ToDoItemID - String - a to-do item ID to be checked against the list of disabled to-do items.
//
// Returns:
//  Boolean - Boolean - True if a to-do was disabled programmatically and it should not be shown to the user.
//
Function UserTaskDisabled(ToDoItemID) Export
	ToDoItemsToDisable = New Array;
	SSLSubsystemsIntegration.OnDisableToDos(ToDoItemsToDisable);
	ToDoListOverridable.OnDisableToDos(ToDoItemsToDisable);
	
	Return (ToDoItemsToDisable.Find(ToDoItemID) <> Undefined)
	
EndFunction

// Returns a structure of common values used for calculating current to-do items.
//
// Returns:
//  Structure:
//    * User - CatalogRef.Users
//                   - CatalogRef.ExternalUsers - current user.
//    * IsFullUser - Boolean - True if it is a full access user.
//    * CurrentDate - Date - a current session date.
//    * DateEmpty  - Date - a blank date.
//
Function CommonQueryParameters() Export
	Return ToDoListInternal.CommonQueryParameters();
EndFunction

// Sets common query parameters for calculating to-do items.
//
// Parameters:
//  Query                 - Query    - a running query with common parameters
//                                       to be filled in.
//  CommonQueryParameters - Structure - common values for calculating indicators.
//
Procedure SetQueryParameters(Query, CommonQueryParameters) Export
	ToDoListInternal.SetCommonQueryParameters(Query, CommonQueryParameters);
EndProcedure

// Gets numeric values of to-do items from a query.
//
// Query with data must have only one string with an arbitrary number of fields.
// Values of such fields must be values of matching indicators.
//
// For example, such query can be as follows:
//   SELECT
//      COUNT(*) AS <Name of a predefined item being a document quantity indicator>.
//   FROM
//      Document.<Document name>.
//
// Parameters:
//  Query - Query - a running query.
//  CommonQueryParameters - Structure - common values for calculating to-do items.
//
// Returns:
//  Structure:
//     * Key     - String - a name of a to-do item indicator.
//     * Value - Number - a numerical indicator value.
//
Function NumericUserTasksIndicators(Query, CommonQueryParameters = Undefined) Export
	Return ToDoListInternal.NumericUserTasksIndicators(Query, CommonQueryParameters);
EndFunction

#EndRegion

