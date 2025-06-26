///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Appearance of items marked for deletion.
	ConditionalAppearanceItem = List.ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("DeletionMark");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use  = True;
	
	FilesOperationsInternal.SetFilterByDeletionMark(List.Filter);
	
	If Common.IsMobileClient() Then
		Items.ListComment.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_File"
	   And (Parameter.Event = "EditFinished"
	      Or Parameter.Event = "VersionSaved") Then
		
		Items.List.Refresh();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(FileOwner(RowSelected), RowSelected, UUID);
	FilesOperationsInternalClient.OpenFileVersion(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ListBeforeDeleteRow(Item, Cancel)
	
	FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	FileDataParameters.GetBinaryDataRef = False;

	FileData = FilesOperationsInternalServerCall.FileData(Items.List.CurrentRow,,FileDataParameters);
	If FileData.CurrentVersion = Items.List.CurrentRow Then
		ShowMessageBox(, NStr("en = 'Cannot delete the active version.';"));
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	Cancel = True;
	OpenFileCard();
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Items.List.CurrentRow <> Undefined Then
		ChangeCommandsAvailability();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Delete(Command)
	
	If Items.List.CurrentRow = Undefined Then
		Return;
	EndIf;
	
	FilesOperationsInternalClient.DeleteData(
		New NotifyDescription("AfterDeleteData", ThisObject),
		Items.List.CurrentData.Ref, UUID);
	
EndProcedure

&AtClient
Procedure ShowMarkedFiles(Command)
	
	FilesOperationsInternalClient.ChangeFilterByDeletionMark(List.Filter, Items.ShowMarkedFiles);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ChangeCommandsAvailability()
	
	CurrentUserIsAuthor =
		Items.List.CurrentData.Author = UsersClient.AuthorizedUser();
	
	Items.FormDelete.Enabled = CurrentUserIsAuthor;
	Items.ListContextMenuDelete.Enabled = CurrentUserIsAuthor;
	
EndProcedure

&AtClient
Procedure AfterDeleteData(Result, AdditionalParameters) Export
	
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure OpenFileCard()
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then 
		
		Version = CurrentData.Ref;
		
		FormOpenParameters = New Structure("Key", Version);
		OpenForm("DataProcessor.FilesOperations.Form.AttachedFileVersion", FormOpenParameters);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function FileOwner(RowSelected)
	Return RowSelected.Owner;
EndFunction

#EndRegion