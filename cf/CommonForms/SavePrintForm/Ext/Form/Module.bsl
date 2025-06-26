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
	
	ArrayOfSaveFormatsRestrictions = StrSplit(Parameters.RestrictionOfSaveFormats, ",", False);
	
	// Populate format list.
	For Each SaveFormat In PrintManagement.SpreadsheetDocumentSaveFormatsSettings() Do
		If Not ArrayOfSaveFormatsRestrictions.Count()
			Or ArrayOfSaveFormatsRestrictions.Find(SaveFormat.Extension) <> Undefined Then
				
			SelectedSaveFormats.Add(String(SaveFormat.SpreadsheetDocumentFileType), SaveFormat.Presentation, False, SaveFormat.Picture);
		EndIf;
	EndDo;
	SelectedSaveFormats[0].Check = True; // By default, only the first format from the list is selected.
	
	If SelectedSaveFormats.Count() = 1 Then
		Items.FormatsSelectionGroup.Visible = False;
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "WithoutChoosingFormat");
	ElsIf SelectedSaveFormats.Count() > 1 Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "");
	EndIf;
	
	// Default save destination.
	SavingOption = "SaveToFolder";
	
	// Visibility setup.
	CanBeSaved = Parameters.PrintObjects.Count() > 0;
	
	AttachmentObjects = GetObjectsToAttach(Parameters.PrintObjects);
	If Parameters.PrintObjects.Count() = 1 Then
		HasOpportunityToAttach = AttachmentObjects[0].Check;
	ElsIf CanBeSaved Then
		HasOpportunityToAttach = False;
		For Each ObjectForAttaching In AttachmentObjects Do
			HasOpportunityToAttach = HasOpportunityToAttach Or ObjectForAttaching.Check;			
		EndDo;
	Else
		HasOpportunityToAttach = False;
	EndIf;
	
	AttachableItem = Items.SavingOption.ChoiceList.FindByValue("Join");
	
	If Not HasOpportunityToAttach Then
		Items.SavingOption.ChoiceList.Delete(AttachableItem);
		AttachableItem = Undefined;
		SavingOption = "SaveToFolder";
		Items.SavingOption.ReadOnly = True;
	EndIf;
	
	Items.SelectFileSaveLocation.Visible = Parameters.FileOperationsExtensionAttached 
		Or CanBeSaved;
	Items.SavingOption.Visible = CanBeSaved;
	If Not CanBeSaved Then
		Items.FolderToSaveFiles.TitleLocation = FormItemTitleLocation.Top;
	EndIf;
	Items.FolderToSaveFiles.Visible = Parameters.FileOperationsExtensionAttached;
	
	If Parameters.PrintObjects.Count() > 1 And AttachableItem <> Undefined Then
		AttachableItem.Presentation = NStr("en = 'Attach to documents';")
				+ " (" + Format(Parameters.PrintObjects.Count(), "NFD=0;") + ")";
	EndIf;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		Items.SaveButton.Representation = ButtonRepresentation.Picture;
		Items.Sign.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	If SelectedSaveFormats.Count() <> 1 Then
		SaveFormatsFromSettings = Settings["SelectedSaveFormats"];
		If SaveFormatsFromSettings <> Undefined Then
			For Each SelectedFormat In SelectedSaveFormats Do 
				FormatFromSettings = SaveFormatsFromSettings.FindByValue(SelectedFormat.Value);
				If FormatFromSettings <> Undefined Then
					SelectedFormat.Check = FormatFromSettings.Check;
				EndIf;
			EndDo;
			Settings.Delete("SelectedSaveFormats");
		EndIf;
	Else
		Settings.Delete("SelectedSaveFormats");
	EndIf;
	
	If Items.SavingOption.ReadOnly Then
		Settings["SavingOption"] = "SaveToFolder"; 
	EndIf;
	
	If Common.IsMobileClient() Then
		Settings["Sign"] = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	If SelectedSaveFormats.Count() = 1 Then
		Settings.Delete("SelectedSaveFormats");
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetSaveLocationPage();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SavingOptionOnChange(Item)
	SetSaveLocationPage();
	ClearMessages();
EndProcedure

&AtClient
Procedure FolderToSaveFilesStartChoice(Item, ChoiceData, StandardProcessing)

	SelectedFolder = Item.EditText;
	FileSystemClient.SelectDirectory(New NotifyDescription("FolderToSaveFilesSelectionCompletion", ThisObject), , SelectedFolder);
	
EndProcedure

// Completion handler that handles selection of the destination directory.
//  See "FileDialog.Show" in Syntax Assistant.
//
&AtClient
Procedure FolderToSaveFilesSelectionCompletion(Folder, AdditionalParameters) Export 
	If Not IsBlankString(Folder) Then 
		SelectedFolder = Folder;
		ClearMessages();
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Save(Command)
	
	If Items.FolderToSaveFiles.Visible Then
		If SavingOption = "SaveToFolder" And IsBlankString(SelectedFolder) Then
			CommonClient.MessageToUser(NStr("en = 'Select a folder.';"),,"SelectedFolder");
			Return;
		EndIf;
	EndIf;
		
	SaveFormats = New Array;
	
	For Each SelectedFormat In SelectedSaveFormats Do
		If SelectedFormat.Check Then
			SaveFormats.Add(SelectedFormat.Value);
		EndIf;
	EndDo;
	
	If SaveFormats.Count() = 0 Then
		ShowMessageBox(,NStr("en = 'Specify at least one of the suggested formats.';"));
		Return;
	EndIf;
	
	SelectionResult = New Structure;
	SelectionResult.Insert("PackToArchive", PackToArchive);
	SelectionResult.Insert("SaveFormats", SaveFormats);
	SelectionResult.Insert("SavingOption", SavingOption);
	SelectionResult.Insert("FolderForSaving", SelectedFolder);
	SelectionResult.Insert("TransliterateFilesNames", TransliterateFilesNames);
	SelectionResult.Insert("Sign", Sign);
	
	If SavingOption = "Join" Then
		ErrorString = "";
		ObjectsToAttach = New Map; 
		For Each ObjectOfAttachment In AttachmentObjects Do
			If Not ObjectOfAttachment.Check Then
				ErrorString = ErrorString + ObjectOfAttachment.Value;
			Else
				ObjectsToAttach.Insert(ObjectOfAttachment.Value, True);
			EndIf;
		EndDo;
		
		SelectionResult.Insert("ObjectsToAttach", ObjectsToAttach);
		
		If ErrorString <> "" Then
			SaveFollowUpNotificationDetails = New NotifyDescription("ResumeSaving", ThisObject, SelectionResult);
			
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot attach the objects:
			| %1';"), ErrorString);
			
			Buttons = New ValueList;
			Buttons.Add("Cancel", NStr("en = 'Cancel';"));
			Buttons.Add("Continue", NStr("en = 'Continue';"));
			
			QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
			QuestionParameters.Title = NStr("en = 'Insufficient rights to attach';");
			QuestionParameters.LockWholeInterface = True;
			QuestionParameters.PromptDontAskAgain = False;
			
			StandardSubsystemsClient.ShowQuestionToUser(SaveFollowUpNotificationDetails, QueryText, Buttons, QuestionParameters);
		Else
			NotifyChoice(SelectionResult);
		EndIf;
	Else
		NotifyChoice(SelectionResult);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetSaveLocationPage()
	
	If Items.FolderToSaveFiles.Visible Then
		Items.FolderToSaveFiles.Enabled = Not SavingOption = "Join";
	EndIf
	
EndProcedure

&AtClient
Procedure ResumeSaving(QuestionResult, SelectionResult) Export
	If QuestionResult.Value = "Cancel" Then
		Close();
	Else
		NotifyChoice(SelectionResult);
	EndIf;
EndProcedure

&AtServerNoContext
Function GetObjectsToAttach(PrintObjects)
	Result = New ValueList;
	ModuleAccessManagement = Undefined;
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
	EndIf;
	
	For Each PrintObject In PrintObjects Do
		Result.Add(PrintObject.Value,,?(ModuleAccessManagement <> Undefined, 
			ModuleAccessManagement.EditionAllowed(PrintObject.Value), True)); 
	EndDo;
	
	Return Result;
EndFunction

#EndRegion
