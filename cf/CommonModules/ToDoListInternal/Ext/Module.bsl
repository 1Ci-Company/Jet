///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

// Fills a user's to-do list.
//
// Parameters:
//  Parameters       - Structure - Empty structure.
//  ResultAddress - String    - an address of a temporary storage where a user's
//                                to-do list is saved - ValueTable:
//    * Id - String - an internal to-do ID used by the To-do list algorithm.
//    * HasToDoItems      - Boolean - if True, the to-do item is displayed in the user's to-do list.
//    * Important        - Boolean - if True, the to-do item is highlighted in red.
//    * Presentation - String - a to-do item presentation displayed to a user.
//    * Count    - Number  - a number related to a to-do item; it is displayed in a to-do item's title.
//    * Form         - String - a full path to the form that is displayed by clicking on the
//                               to-do item hyperlink in the "To-do list" panel.
//    * FormParameters- Structure - parameters for opening the indicator form.
//    * Owner      - String
//                    - MetadataObject - String ID of the to-do item that is the owner of the current to-do item,
//                      or a subsystem metadata object.
//    * ToolTip     - String - a tooltip text.
//
Procedure GenerateToDoListForUser(Parameters, ResultAddress) Export
	
	ToDoList = ToDoListServer.ToDoList();
	ViewSettings = SavedViewSettings();
	
	UserTasksCount = 0;
	AddUserTask(ToDoList, SSLSubsystemsIntegration, UserTasksCount);
	
	// Adding to-do items from business applications.
	UserTasksFillingHandlers = New Array;
	SSLSubsystemsIntegration.OnDetermineToDoListHandlers(UserTasksFillingHandlers);
	ToDoListOverridable.OnDetermineToDoListHandlers(UserTasksFillingHandlers);
	
	For Each Handler In UserTasksFillingHandlers Do
		If ReceiveToDoItemsByObject(Handler, ViewSettings) Then
			AddUserTask(ToDoList, Handler, UserTasksCount);
		EndIf;
	EndDo;
	
	// Result post-processing.
	TransformToDoListTable(ToDoList, ViewSettings);
	
	Common.CommonSettingsStorageSave("ToDoList", "ViewSettings", ViewSettings);
	PutToTempStorage(ToDoList, ResultAddress);
	
EndProcedure

// Returns a structure of saved settings for displaying to-do items
// for the current user.
// 
// Returns:
//  Structure:
//     * UserTasksVisible - Map
//     * SectionsVisibility - Map
//     * DisabledObjects - Map
//     * CollapsedSections - Map
//     * UserTasksTree - ValueTree:
//          ** Presentation - String
//          ** IsSection - Boolean
//          ** Check - Boolean
//          ** Id - String
//          ** IndexOf - Number
//          ** ToDoDetails - String
//          ** IsHidden - Boolean
//          ** OutputInNotifications -Boolean
//
Function SavedViewSettings() Export
	
	Result = New Structure;
	Result.Insert("UserTasksVisible", New Map);
	Result.Insert("SectionsVisibility", New Map);
	Result.Insert("DisabledObjects", New Map);
	Result.Insert("CollapsedSections", New Map);
	Result.Insert("UserTasksTree", New ValueTree);

	ViewSettings = CommonSettingsStorage.Load("ToDoList", "ViewSettings");
	If ViewSettings = Undefined Then
		Return Result;
	EndIf;
	
	If TypeOf(ViewSettings) <> Type("Structure") Then
		Return Result;
	EndIf;
	
	FillPropertyValues(Result, ViewSettings);
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See UsersOverridable.OnDefineRoleAssignment
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// BothForUsersAndExternalUsers.
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.UseCurrentToDosProcessor.Name);
	
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming.
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	OldName = "Role.UsingCurCases";
	NewName  = "Role.UseCurrentToDosProcessor";
	Common.AddRenaming(Total, "2.3.3.25", OldName, NewName, Library);
	
	
EndProcedure

#EndRegion

#Region Private

Function NumericUserTasksIndicators(Query, CommonQueryParameters = Undefined) Export
	
	// Set common parameters for all queries.
	// Individual parameters must be set prior to that.
	If Not CommonQueryParameters = Undefined Then
		SetCommonQueryParameters(Query, CommonQueryParameters);
	EndIf;
	
	Result = Query.ExecuteBatch(); // Array of QueryResult 
	BatchQueriesNumbers = New Array;
	BatchQueriesNumbers.Add(Result.Count() - 1);
	
	// Select all queries with data.
	QueryResult = New Structure;
	For Each QueryNumber In BatchQueriesNumbers Do
		
		QueryFromPackage = Result.Get(QueryNumber);
		Selection = QueryFromPackage.Select();
		
		If Selection.Next() Then
			
			For Each Column In QueryFromPackage.Columns Do
				UserTaskValue = ?(TypeOf(Selection[Column.Name]) = Type("Null"), 0, Selection[Column.Name]);
				QueryResult.Insert(Column.Name, UserTaskValue);
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Return QueryResult;
	
EndFunction

// Returns a structure of common values used for calculating current to-do items.
//
// Returns:
//  Structure - a value name and a value.
//
Function CommonQueryParameters() Export
	
	CommonQueryParameters = New Structure;
	CommonQueryParameters.Insert("User", Users.CurrentUser());
	CommonQueryParameters.Insert("IsFullUser", Users.IsFullUser());
	CommonQueryParameters.Insert("CurrentDate", CurrentSessionDate());
	CommonQueryParameters.Insert("DateEmpty", '00010101000000');
	
	Return CommonQueryParameters;
	
EndFunction

// Sets common query parameters for calculating to-do items.
//
// Parameters:
//  Query - a running query.
//  CommonQueryParameters - Structure - common values for calculating indicators.
//
Procedure SetCommonQueryParameters(Query, CommonQueryParameters) Export
	
	For Each KeyAndValue In CommonQueryParameters Do
		Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	SSLSubsystemsIntegration.OnSetCommonQueryParameters(Query, CommonQueryParameters);
	ToDoListOverridable.SetCommonQueryParameters(Query, CommonQueryParameters);
	
EndProcedure

// For internal use only.
//
// Parameters:
//   ToDoList - ValueTable
//
Procedure SetInitialSectionsOrder(ToDoList) Export
	
	CommandInterfaceSectionsOrder = New Array;
	SSLSubsystemsIntegration.OnDetermineCommandInterfaceSectionsOrder(CommandInterfaceSectionsOrder);
	ToDoListOverridable.OnDetermineCommandInterfaceSectionsOrder(CommandInterfaceSectionsOrder);
	
	IndexOf = 0;
	For Each CommandInterfaceSection In CommandInterfaceSectionsOrder Do
		If TypeOf(CommandInterfaceSection) = Type("String") Then
			CommandInterfaceSection = StrReplace(CommandInterfaceSection, " ", "");
		Else
			CommandInterfaceSection = StrReplace(CommandInterfaceSection.FullName(), ".", "");
		EndIf;
		RowFilter = New Structure;
		RowFilter.Insert("OwnerID", CommandInterfaceSection);
		
		FoundRows = ToDoList.FindRows(RowFilter);
		For Each FoundRow In FoundRows Do
			RowIndexInTable = ToDoList.IndexOf(FoundRow);
			If RowIndexInTable = IndexOf Then
				IndexOf = IndexOf + 1;
				Continue;
			EndIf;
			
			ToDoList.Move(RowIndexInTable, (IndexOf - RowIndexInTable));
			IndexOf = IndexOf + 1;
		EndDo;
		
	EndDo;
	
EndProcedure

// For internal use only.
//
Procedure TransformToDoListTable(ToDoList, ViewSettings)
	
	ToDoList.Columns.Add("OwnerID", New TypeDescription("String", New StringQualifiers(250)));
	ToDoList.Columns.Add("IsSection", New TypeDescription("Boolean"));
	ToDoList.Columns.Add("SectionPresentation", New TypeDescription("String", New StringQualifiers(250)));
	
	DisabledObjects = ViewSettings.DisabledObjects;
	InvalidChars = """'`/\-[]{}:;|=?*<>,.()+#№@!%^&~ ";
	UserTasksToRemove = New Array;
	For Each ToDoItem In ToDoList Do
		
		If TypeOf(ToDoItem.Owner) = Type("MetadataObject") Then
			SectionAvailable = Common.MetadataObjectAvailableByFunctionalOptions(ToDoItem.Owner);
			If Not SectionAvailable Then
				UserTasksToRemove.Add(ToDoItem);
				Continue;
			EndIf;
			
			ToDoItem.OwnerID = StrReplace(ToDoItem.Owner.FullName(), ".", "");
			ToDoItem.IsSection              = True;
			ToDoItem.SectionPresentation   = ?(ValueIsFilled(ToDoItem.Owner.Synonym), ToDoItem.Owner.Synonym, ToDoItem.Owner.Name);
		Else
			SectionPresentation = ToDoItem.Owner;
			If TypeOf(ToDoItem.Owner) = Type("DataProcessorManager.ToDoList") Then
				ToDoItem.Owner = ToDoItem.Owner.FullName();
				SectionPresentation = ToDoItem.Owner;
			EndIf;
			ToDoItem.Owner      = StrConcat(StrSplit(ToDoItem.Owner, InvalidChars, True));
			If StartsWithNumber(ToDoItem.Owner) Then
				ToDoItem.Owner = "_" + ToDoItem.Owner;
			EndIf;
			ToDoItem.Id = StrConcat(StrSplit(ToDoItem.Id, InvalidChars, True));
			If StartsWithNumber(ToDoItem.Id) Then
				ToDoItem.Id = "_" + ToDoItem.Id;
			EndIf;
			
			IsUserTaskID = (ToDoList.Find(ToDoItem.Owner, "Id") <> Undefined);
			If Not IsUserTaskID Then
				IsUserTaskID = (ToDoList.Find(SectionPresentation, "Id") <> Undefined);
			EndIf;
			
			ToDoItem.OwnerID = StrReplace(ToDoItem.Owner, " ", "");
			ToDoItem.OwnerID = StrConcat(StrSplit(ToDoItem.OwnerID, InvalidChars, True));
			If StartsWithNumber(ToDoItem.OwnerID) Then
				ToDoItem.OwnerID = "_" + ToDoItem.OwnerID;
			EndIf;
			If Not IsUserTaskID Then
				ToDoItem.IsSection              = True;
				ToDoItem.SectionPresentation   = SectionPresentation;
			EndIf;
		EndIf;
		
		If ValueIsFilled(ToDoItem.ToDoOwnerObject) And ToDoItem.IsSection Then
			If DisabledObjects[ToDoItem.ToDoOwnerObject] = Undefined Then
				DisabledObjects.Insert(ToDoItem.ToDoOwnerObject, New Array);
				DisabledObjects[ToDoItem.ToDoOwnerObject].Add(ToDoItem.Id);
			Else
				DisabledCases = DisabledObjects[ToDoItem.ToDoOwnerObject]; // Array
				DisabledCases.Add(ToDoItem.Id);
			EndIf;
		EndIf;
		
		// Backward compatibility.
		If TypeOf(ToDoItem.HasUserTasks) = Type("Boolean") Then
			ToDoItem.HasToDoItems = ToDoItem.HasUserTasks;
		EndIf;
		
	EndDo;
	
	If DisabledObjects.Count() > 0 Then
		ViewSettings.Insert("DisabledObjects", DisabledObjects);
	EndIf;
	
	For Each UserTaskToRemove In UserTasksToRemove Do
		ToDoList.Delete(UserTaskToRemove);
	EndDo;
	
	ToDoList.Columns.Delete("Owner");
	
EndProcedure

Function StartsWithNumber(Name)
	
	FirstChar = Left(Name, 1);
	StringToCheck = "0123456789";
	
	If StrFind(StringToCheck, FirstChar) > 0 Then
		Return True
	EndIf;
	
	Return False;
	
EndFunction

Procedure AddUserTask(ToDoList, Manager, UserTasksCount)
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		MeasurementStart = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	UserTasksCount = ToDoList.Count();
	Manager.OnFillToDoList(ToDoList);
	NewUserTasksCount = ToDoList.Count();
	
	If UserTasksCount <> NewUserTasksCount
		And TypeOf(Manager) <> Type("CommonModule") Then
		ToDoOwnerObject = Metadata.FindByType(TypeOf(Manager)).FullName();
		For IndexOf = UserTasksCount To NewUserTasksCount - 1 Do
			String = ToDoList.Get(IndexOf);
			String.ToDoOwnerObject = ToDoOwnerObject;
		EndDo;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor")
		And ToDoList.Count() <> UserTasksCount Then
		UserTasksCount = ToDoList.Count();
		LastUserTask = ToDoList.Get(UserTasksCount - 1);
		Owner = LastUserTask.Owner;
		If TypeOf(Owner) = Type("MetadataObject") Then
			UserTaskPresentation = LastUserTask.Presentation;
		Else
			OwnerDetails = ToDoList.Find(LastUserTask.Owner, "Id");
			If OwnerDetails = Undefined Then
				UserTaskPresentation = LastUserTask.Presentation;
			Else
				UserTaskPresentation = OwnerDetails.Presentation;
			EndIf;
		EndIf;
		
		KeyOperation = "ToDosUpdate." + UserTaskPresentation;
		ModulePerformanceMonitor.EndTimeMeasurement(KeyOperation, MeasurementStart);
	EndIf;
EndProcedure

Function ReceiveToDoItemsByObject(Handler, ViewSettings)
	If TypeOf(Handler) = Type("CommonModule") Then
		Return True;
	EndIf;
		
	ReceiveToDoItems = True;
	ToDoOwnerObject = Metadata.FindByType(TypeOf(Handler)).FullName();
	ToDoItemsToCheck = ViewSettings.DisabledObjects[ToDoOwnerObject];
	If TypeOf(ToDoItemsToCheck) = Type("Array") Then
		ReceiveToDoItems = False;
		For Each ToDoItemToCheck In ToDoItemsToCheck Do
			Value = ViewSettings.UserTasksVisible[ToDoItemToCheck];
			If Value <> False Then
				ReceiveToDoItems = True;
			EndIf;
		EndDo;
		If Not ReceiveToDoItems Then
			Return False;
		EndIf;
		ViewSettings.DisabledObjects.Delete(ToDoOwnerObject);
	EndIf;
	Return ReceiveToDoItems;
	
EndFunction

#EndRegion
