///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

// Expected parameters:
//
//     DuplicatesSearchArea - String - The full name of the metadata table for the given search area.
//
// Return value (as a selection result):
//
//     Undefined - Editing is canceled.
//     String - Address of the new composer settings in a temporary storage.
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("DuplicatesSearchArea", DefaultArea);
	Parameters.Property("SettingsAddress", SettingsAddress);
	
	InitializeSearchForDuplicatesAreasList();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DuplicatesSearchAreasSelection(Item, RowSelected, Field, StandardProcessing)
	
	MakeChoice(RowSelected);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	
	MakeChoice(Items.DuplicatesSearchAreas.CurrentRow);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure MakeChoice(Val RowID)
	
	Item = DuplicatesSearchAreas.FindByID(RowID);
	If Item = Undefined Then
		Return;
		
	ElsIf Item.Value = DefaultArea Then
		// No changes were made.
		Close();
		Return;
		
	EndIf;
	
	NotifyChoice(Item.Value);
EndProcedure

&AtServer
Procedure InitializeSearchForDuplicatesAreasList()
	If ValueIsFilled(SettingsAddress)
		And IsTempStorageURL(SettingsAddress) Then
		SettingsTable = GetFromTempStorage(SettingsAddress);
	Else
		SettingsTable = DuplicateObjectsDetection.MetadataObjectsSettings();
		SettingsAddress = PutToTempStorage(SettingsTable, UUID);
	EndIf;
	
	For Each TableRow In SettingsTable Do
		Item = DuplicatesSearchAreas.Add(TableRow.FullName, TableRow.ListPresentation, , PictureLib[TableRow.Kind]);
		If TableRow.FullName = DefaultArea Then
			Items.DuplicatesSearchAreas.CurrentRow = Item.GetID();
		EndIf;
	EndDo;
EndProcedure

#EndRegion