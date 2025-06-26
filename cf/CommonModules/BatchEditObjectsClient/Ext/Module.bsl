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

// Opens a dialog to bulk-modify attributes of the selected objects.
//
// Parameters:
//  ListItem  - FormTable
//                 - Array of AnyRef - Form item that contains the list.
//  ListAttribute1 - DynamicList - Form item that contains the list.
//
Procedure ChangeSelectedItems(ListItem, Val ListAttribute1 = Undefined) Export
	
	FormParameters = New Structure("ObjectsArray", New Array);
	If TypeOf(ListItem) = Type("Array") Then
		
		FormParameters.ObjectsArray = ListItem;
		
	Else
		
		If ListAttribute1 = Undefined Then
			
			Form = ListItem.Parent;
			While TypeOf(Form) <> Type("ClientApplicationForm") Do
				Form = Form.Parent;
			EndDo;
			
			Try
				ListAttribute1 = Form.List;
			Except
				ListAttribute1 = Undefined;
			EndTry;
			
		EndIf;
		
		SelectedRows = ListItem.SelectedRows;
		
		If TypeOf(ListAttribute1) = Type("DynamicList") Then
			FormParameters.Insert("SettingsComposer", ListAttribute1.SettingsComposer);
		EndIf;
		
		For Each SelectedRow In SelectedRows Do
			If TypeOf(SelectedRow) = Type("DynamicListGroupRow") Then
				Continue;
			EndIf;
			
			CurrentRow = ListItem.RowData(SelectedRow);
			If CurrentRow <> Undefined And ValueIsFilled(CurrentRow.Ref) Then
				FormParameters.ObjectsArray.Add(CurrentRow.Ref);
			EndIf;
		EndDo;
		
	EndIf;
	
	StartEditSelectedItems(FormParameters);
	
EndProcedure

#EndRegion

#Region Internal

// Parameters:
//   ReferencesArrray - Array of AnyRef - references to the selected objects for which a command is being executed.
//   ExecutionParameters - See AttachableCommandsClient.CommandExecuteParameters
//
Procedure HandlerCommands(Val ReferencesArrray, Val ExecutionParameters) Export
	CommandParameters = New Structure;
	CommandParameters.Insert("ObjectsArray", ReferencesArrray);
	StartEditSelectedItems(CommandParameters);
EndProcedure

Procedure StartChangingTheSelectedOnesWithAnAlert(BulkEditParameters, NotifyDescription) Export
	
	If BulkEditParameters.ObjectsArray.Count() = 0 Then
		
		ShowMessageBox(, NStr("en = 'Cannot run the command for the object.';"));
		
	Else
		
		OpenForm("DataProcessor.BatchEditAttributes.Form", BulkEditParameters,,,,, NotifyDescription);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Parameters:
//  BulkEditParameters - Structure:
//    * ObjectsArray - Array of AnyRef
//    * SettingsComposer - DataCompositionSettingsComposer
//
Procedure StartEditSelectedItems(BulkEditParameters)
	
	If BulkEditParameters.ObjectsArray.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'Cannot run the command for the object.';"));
	Else
		OpenForm("DataProcessor.BatchEditAttributes.Form", BulkEditParameters);
	EndIf;
	
EndProcedure

#EndRegion
