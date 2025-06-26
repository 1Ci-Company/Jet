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

// Starts interactive deletion of marked objects.
// 
// Parameters:
//   ObjectsToDelete - Array of AnyRef - the list of objects to be deleted.
//   DeletionParameters - See InteractiveDeletionParameters
// 		
//   Owner - ClientApplicationForm
//            - Undefined - — the form from which deletion was started.
// 							   If not specified, the detailed information on the deletion results
// 							   will not be passed to the processing notification about closing.
//   OnCloseNotifyDescription - NotifyDescription - If specified, then when the deletion is over, or the form is closed,
//								the result is passed to the notification handler as Structure with the properties
//								# Success - Boolean - "True" if all objects are deleted.:
//                              # DeletedItemsCount1 - Number - Number of deleted objects.
//                              # NotDeletedItemsCount - Number - Number of objects that couldn't be deleted.
//                              # ResultAddress- String - Address in the temporary storage.
//                              
//
Procedure StartMarkedObjectsDeletion(ObjectsToDelete, DeletionParameters = Undefined, Owner = Undefined,
	OnCloseNotifyDescription = Undefined) Export

	FormParameters = New Structure;
	FormParameters.Insert("ObjectsToDelete", ObjectsToDelete);
	FormParameters.Insert("DeletionMode", "Standard");
	If DeletionParameters <> Undefined Then
		FillPropertyValues(FormParameters, DeletionParameters);
	EndIf;
	
	ClosingNotification1 = New NotifyDescription("StartMarkedObjectsDeletionCompletion"
		, ThisObject, New Structure("ClosingNotification1", OnCloseNotifyDescription));
		
	OpenForm("DataProcessor.MarkedObjectsDeletion.Form", FormParameters, Owner, , , , ClosingNotification1,
		FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

// Interactive deletion settings.
// 
// Returns:
//   Structure:
//   * Mode - String -  the deletion method can take the following values:
//		"Standard" — deleting objects with reference integrity control and saving 
//					  multiple user operation.
//		"Exclusive" — deleting objects with reference integrity control and setting exclusive mode.
//		"Simplified" — deleting objects with reference integrity control carried out only in not marked
//					  for deletion objects. In the marked for deletion objects, reference to the objects to delete 
//					  will be cleared.
//
Function InteractiveDeletionParameters() Export
	Parameters = New Structure;
	Parameters.Insert("Mode", "Standard");
	Return Parameters;
EndFunction

#Region FormsPublic

// Opens the Deleting marked objects workplace.
//  
// Parameters:
//   Form - ClientApplicationForm
//   FormTable - FormTable
//                - FormDataStructure
//                - Undefined - the form table that relates to the dynamic list
//
Procedure GoToMarkedForDeletionItems(Form, FormTable = Undefined) Export
	
	If FormTable <> Undefined Then
		CommonClientServer.CheckParameter("GoToMarkedForDeletionItems", "FormTable", FormTable, New TypeDescription("FormTable"));
		
		MetadataTypes = Form.MarkedObjectsDeletionParameters[FormTable.Name].MetadataTypes;
		OpeningParameters = New Structure();
		OpeningParameters.Insert("MetadataFilter", MetadataTypes);
	EndIf;
	
	OpenForm("DataProcessor.MarkedObjectsDeletion.Form.DefaultForm", OpeningParameters, Form);
EndProcedure

// Changes visibility of the objects marked for deletion and saves the user setting.
// 
// Parameters:
//   Form - ClientApplicationForm
//   FormTable - FormTable - the form table that relates to the dynamic list.
//   FormButton - FormButton - a form button that relates to the Show objects marked for deletion command.
//
Procedure ShowObjectsMarkedForDeletion(Form, FormTable, FormButton) Export
	CommonClientServer.CheckParameter("ShowObjectsMarkedForDeletion", "FormTable", FormTable, New TypeDescription("FormTable"));
	NewFilterValue = ChangeObjectsMarkedForDeletionFilter(Form, FormTable);
	FormButton.Check = Not NewFilterValue;
EndProcedure

// Opens the form to change the scheduled job schedule.
// If the schedule is set, the scheduled job with a set schedule will be included. 
// 
// Cannot run on mobile devices.
// 
// Parameters:
//   ChangeNotification1 - NotifyDescription - a handler of the scheduled job schedule change.
//
Procedure StartChangeJobSchedule(ChangeNotification1 = Undefined) Export
	ScheduledJobInfoDeletionOfMarkedObjects = MarkedObjectsDeletionInternalServerCall.ModeDeleteOnSchedule();
	Handler = New NotifyDescription("ScheduledJobsAfterChangeSchedule", ThisObject,
			New Structure("ChangeNotification1, OldSchedule", ChangeNotification1, ScheduledJobInfoDeletionOfMarkedObjects.Schedule));
	
	If ScheduledJobInfoDeletionOfMarkedObjects.DataSeparationEnabled Then
		Result = New Structure("Use,Schedule");
		FillPropertyValues(Result, ScheduledJobInfoDeletionOfMarkedObjects);
		ExecuteNotifyProcessing(Handler, ScheduledJobInfoDeletionOfMarkedObjects.Schedule);
	Else		
		ScheduledJobDetails = ScheduledJobInfoDeletionOfMarkedObjects.Schedule;
		Schedule = New JobSchedule;
		FillPropertyValues(Schedule, ScheduledJobDetails);
		Dialog = New ScheduledJobDialog(Schedule);
		Dialog.Show(Handler);
	EndIf;
EndProcedure

// The OnChange event handler for the flag that switches the automatic object deletion mode.
// 
// Parameters:
//   AutomaticallyDeleteMarkedObjects  - Boolean - a new flag value to be processed.
//   ChangeNotification1 - NotifyDescription - if AutomaticallyDeleteMarkedObjectsCheckBoxValue = True, the procedure
//   											  will be called after setting the scheduled job schedule.
//   											  If AutomaticallyDeleteMarkedObjectsCheckBoxValue = False, the procedure will be 
//   											  called immediately. 
// 
// Example:
//	If CommonClient.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
//		ModuleMarkedObjectsDeletionClient = CommonClient.CommonModule("MarkedObjectsDeletionClient");
//		ModuleMarkedObjectsDeletionClient.OnChangeCheckBoxDeleteOnSchedule(AutomaticallyDeleteMarkedObjects);
//	EndIf;
//
Procedure OnChangeCheckBoxDeleteOnSchedule(AutomaticallyDeleteMarkedObjects, ChangeNotification1 = Undefined) Export
	CurrentScheduledJobParameters = MarkedObjectsDeletionInternalServerCall.ModeDeleteOnSchedule();
	Changes = New Structure("Schedule", CurrentScheduledJobParameters.Schedule);
	Changes.Insert("Use", AutomaticallyDeleteMarkedObjects);
	MarkedObjectsDeletionInternalServerCall.SetDeleteOnScheduleMode(Changes);

	If ChangeNotification1 <> Undefined Then
		ExecuteNotifyProcessing(ChangeNotification1, Changes);
	EndIf;
	
	// Keep backward compatibility with version 3.1.2.
	Notify("ModeChangedAutomaticallyDeleteMarkedObjects");
EndProcedure

#EndRegion

// The NotificationProcessing event handler for the form, on which the check box of scheduled deletion is to be displayed.
//
// Parameters:
//   EventName - String - a name of an event that is got by an event handler on the form.
//   AutomaticallyDeleteMarkedObjects - Boolean - an attribute that will store the flag value.
// 
// Example:
//	If CommonClient.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
//		ModuleMarkedObjectsDeletionClient = CommonClient.CommonModule("MarkedObjectsDeletionClient");
//		ModuleMarkedObjectsDeletionClient.DeleteOnScheduleCheckBoxChangeNotificationProcessing(
//			EventName, 
//			AutomaticallyDeleteMarkedObjects);
//	EndIf;
//
Procedure DeleteOnScheduleCheckBoxChangeNotificationProcessing(Val EventName,
		AutomaticallyDeleteMarkedObjects) Export

	If EventName = "ModeChangedAutomaticallyDeleteMarkedObjects" Then
		AutomaticallyDeleteMarkedObjects = MarkedObjectsDeletionInternalServerCall.DeleteOnScheduleCheckBoxValue();
	EndIf;

EndProcedure

#EndRegion

#Region Internal

// The attached command handler.
//
// Parameters:
//   ReferencesArrray - Array of AnyRef - references to the selected objects for which a command is being executed.
//   CommandParameters - See AttachableCommandsClient.CommandExecuteParameters
//
Procedure RunAttachableCommandShowObjectsMarkedForDeletion(Val ReferencesArrray,
		CommandParameters) Export
	NewFilterValue = ChangeObjectsMarkedForDeletionFilter(CommandParameters.Form, CommandParameters.Source);
	MarkedObjectsDeletionInternalServerCall.SaveViewSettingForItemsMarkedForDeletion(CommandParameters.Form.FormName, CommandParameters.Source.Name, NewFilterValue);
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(CommandParameters.Form, CommandParameters.Source);
	EndIf;
EndProcedure

// The attached command handler.
//
// Parameters:
//   ReferencesArrray - Array of AnyRef - references to the selected objects for which a command is being executed.
//   ExecutionParameters - See AttachableCommandsClient.CommandExecuteParameters
//
Procedure RunAttachableCommandGoToObjectsMarkedForDeletion(ReferencesArrray, ExecutionParameters) Export
	GoToMarkedForDeletionItems(ExecutionParameters.Form, ExecutionParameters.Source);
EndProcedure

#EndRegion

#Region Private

Procedure StartMarkedObjectsDeletionCompletion(Val DeletionResult, AdditionalParameters) Export
	If DeletionResult = Undefined And Not AdditionalParameters.Property("ClosingResult") Then
		Return;
	EndIf;
		
	If DeletionResult = Undefined Then
		DeletionResult = AdditionalParameters.ClosingResult;
	EndIf;	
		
	If AdditionalParameters.ClosingNotification1 <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.ClosingNotification1, DeletionResult);
	EndIf;
EndProcedure

Procedure ScheduledJobsAfterChangeSchedule(Schedule, ExecutionParameters) Export
	If Schedule = Undefined Then
		Return;
	EndIf;	

	DeleteMarkedObjectsUsage = True;
	Changes = New Structure;
	Changes.Insert("Schedule", Schedule);
	Changes.Insert("Use", True);
	MarkedObjectsDeletionInternalServerCall.SetDeleteOnScheduleMode(Changes);
	
	Notify("ModeChangedAutomaticallyDeleteMarkedObjects");
	
	If ExecutionParameters.Property("ChangeNotification1") And ExecutionParameters.ChangeNotification1 <> Undefined Then
		ExecuteNotifyProcessing(ExecutionParameters.ChangeNotification1,
			New Structure("Use, Schedule", DeleteMarkedObjectsUsage, Schedule));
	EndIf;
EndProcedure

// Changes visibility of the objects for deletion in the list
// 
// Parameters:
//   Form - ClientApplicationForm
//   FormTable - FormTable
// Returns:
//   Boolean - — a set filter value
//
Function ChangeObjectsMarkedForDeletionFilter(Form, FormTable)
	
	Setting = Form.MarkedObjectsDeletionParameters[FormTable.Name];
	NewFilterValue = Not Setting.FilterValue;
	MarkedObjectsDeletionInternalClientServer.SetFilterByDeletionMark(Form[Setting.ListName], NewFilterValue);
	Setting.FilterValue = NewFilterValue;
	Setting.CheckMarkValue = Not NewFilterValue;
	MarkedObjectsDeletionInternalServerCall.SaveViewSettingForItemsMarkedForDeletion(Form.FormName, FormTable.Name, NewFilterValue);
	Return NewFilterValue;
	
EndFunction

#EndRegion

