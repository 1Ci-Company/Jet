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
	
	SetConditionalAppearance();
	
	Filter = Parameters.Filter;
	
	If Filter.Count() > 0 Then
		Items.PrintCommands.InitialTreeView = InitialTreeView.ExpandAllLevels;
	EndIf;
	
	FillPrintCommandsList();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("BeforeCloseConfirmationReceived", ThisObject);
	CommonClient.ShowFormClosingConfirmation(NotifyDescription, Cancel, Exit,, WarningText);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPrintCommands

&AtClient
Procedure PrintCommandsVisibleOnChange(Item)
	OnCheckChange(Items.PrintCommands, "Visible");
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command = Undefined)
	Write();
	Close();
EndProcedure

&AtClient
Procedure ShowInList(Command)
	
	If Modified Then
		Notification = New NotifyDescription("ShowInListCompletion", ThisObject, Parameters);
		QueryText = NStr("en = 'The data has been changed. Do you want to save the changes?';");
		ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNoCancel, ,
			DialogReturnCode.Cancel);
		Return;
	EndIf;
	
	GoToList();
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	FillCollectionAttributeValue(PrintCommands, "Visible", True);
	Modified = True;
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	FillCollectionAttributeValue(PrintCommands, "Visible", False);
	Modified = True;
EndProcedure

&AtClient
Procedure ApplyDefaultSettings(Command)
	FillPrintCommandsList();
	Modified = False;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure RefreshCommandsOwnerCheckBox(CommandsOwner)
	HasSelectedItems = False;
	SelectedAllItems = True;
	For Each PrintCommand In CommandsOwner.GetItems() Do
		HasSelectedItems = HasSelectedItems Or PrintCommand.Visible;
		SelectedAllItems = SelectedAllItems And PrintCommand.Visible;
	EndDo;
	CommandsOwner.Visible = HasSelectedItems + ?(HasSelectedItems, (Not SelectedAllItems), HasSelectedItems);
EndProcedure

&AtClient
Procedure PrintCommandsSelection(Item, RowSelected, Field, StandardProcessing)
	If Field.Name = Items.PrintCommandsComment.Name 
		And Not IsBlankString(Items.PrintCommands.CurrentData.URL) Then
			FileSystemClient.OpenURL(Items.PrintCommands.CurrentData.URL);
	EndIf;
EndProcedure

&AtServer
Procedure WriteCommandsSettings()
	
	Block = New DataLock;
	Block.Add("InformationRegister.PrintCommandsSettings");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		RecordSet = InformationRegisters.PrintCommandsSettings.CreateRecordSet();
		For Each CommandsSet In PrintCommands.GetItems() Do
			RecordSet.Filter.Owner.Set(CommandsSet.Owner);
			RecordSet.Read();
			RecordSet.Clear();
			SettingsToWrite = RecordSet.Unload();
			For Each Setting In CommandsSet.GetItems() Do
				FillPropertyValues(SettingsToWrite.Add(), Setting);
			EndDo;
			SettingsToWrite.GroupBy("Owner,UUID", "Visible");
			RecordSet.Load(SettingsToWrite);
			RecordSet.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Modified = False;
	
EndProcedure

&AtClient
Procedure OnCheckChange(FormTree, CheckBoxName)
	
	CurrentData = FormTree.CurrentData;
	
	If CurrentData[CheckBoxName] = 2 Then
		CurrentData[CheckBoxName] = 0;
	EndIf;
	
	Check = CurrentData[CheckBoxName];
	
	// Update subordinate flags.
	For Each SubordinateAttribute In CurrentData.GetItems() Do
		SubordinateAttribute[CheckBoxName] = Check;
	EndDo;
	
	// Update the parent flag.
	Parent = CurrentData.GetParent();
	If Parent <> Undefined Then
		HasSelectedItems = False;
		SelectedAllItems = True;
		For Each Item In Parent.GetItems() Do
			HasSelectedItems = HasSelectedItems Or Item[CheckBoxName];
			SelectedAllItems = SelectedAllItems And Item[CheckBoxName];
		EndDo;
		Parent[CheckBoxName] = HasSelectedItems + ?(HasSelectedItems, (Not SelectedAllItems), HasSelectedItems);
	EndIf;

EndProcedure

&AtClient
Procedure FillCollectionAttributeValue(Collection, Var_AttributeName, Value)
	For Each Item In Collection.GetItems() Do
		Item[Var_AttributeName] = Value;
		FillCollectionAttributeValue(Item, Var_AttributeName, Value);
	EndDo;
EndProcedure

&AtServer
Procedure FillPrintCommandsList()
	
	SetPrivilegedMode(True);
	PrintCommandsSources = PrintManagement.PrintCommandsSources();
	
	PrintCommands.GetItems().Clear();
	For Each PrintCommandsSource In PrintCommandsSources Do
		PrintCommandsSourceID = Common.MetadataObjectID(PrintCommandsSource);
		If Filter.Count() > 0 And Filter.FindByValue(PrintCommandsSourceID) = Undefined Then
			Continue;
		EndIf;
		
		ObjectPrintCommands = PrintManagement.ObjectPrintCommands(PrintCommandsSource);
		
		ObjectPrintCommands.Columns.Add("Owner");
		ObjectPrintCommands.FillValues(PrintCommandsSourceID, "Owner");
		
		ObjectPrintCommands.Columns.Add("IsExternalPrintCommand");
		For Each PrintCommand In ObjectPrintCommands Do
			PrintCommand.IsExternalPrintCommand = PrintCommand.PrintManager = "StandardSubsystems.AdditionalReportsAndDataProcessors";
		EndDo;
		
		If ObjectPrintCommands.Count() = 0 Then
			Continue;
		EndIf;
		
		SourceDetails = PrintCommands.GetItems().Add();
		SourceDetails.Owner = PrintCommandsSourceID;
		SourceDetails.Presentation = PrintCommandsSource.Presentation();
		SourceDetails.Visible = 2;
		SourceDetails.URL = "e1cib/list/" + PrintCommandsSource.FullName();
		
		For Each PrintCommand In ObjectPrintCommands Do
			If PrintCommand.Picture.Type = PictureType.Empty Then
				PrintCommand.Picture = PictureLib.IsEmpty;
			EndIf;
			PrintCommandDetails = SourceDetails.GetItems().Add();
			FillPropertyValues(PrintCommandDetails, PrintCommand);
			PrintCommandDetails.Visible = Not PrintCommand.isDisabled;
			If PrintCommandDetails.PrintManager = "StandardSubsystems.AdditionalReportsAndDataProcessors" Then
				PrintCommandDetails.Comment = String(PrintCommand.AdditionalParameters.Ref);
				PrintCommandDetails.URL = GetURL(PrintCommand.AdditionalParameters.Ref);
			EndIf;
		EndDo;
		
		RefreshCommandsOwnerCheckBox(SourceDetails);
	EndDo;
	
	CommandsTree = FormAttributeToValue("PrintCommands");
	CommandsTree.Rows.Sort("Presentation", True);
	ValueToFormAttribute(CommandsTree, "PrintCommands");
	
EndProcedure

&AtClient
Procedure Write()
	WriteCommandsSettings();
	RefreshReusableValues();
EndProcedure

&AtClient
Procedure ShowInListCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = Undefined Or QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If QuestionResult = DialogReturnCode.Yes Then
		Write();
	EndIf;
	
	GoToList();
	
EndProcedure

&AtClient
Procedure GoToList()
	
	CommandsOwner = Items.PrintCommands.CurrentData;
	If CommandsOwner = Undefined Then
		Return;
	EndIf;
	
	Parent = CommandsOwner.GetParent();
	If Parent <> Undefined Then
		CommandsOwner = Parent;
	EndIf;
	
	URL = CommandsOwner.URL;

	For Each ClientApplicationWindow In GetWindows() Do
		If ClientApplicationWindow.GetURL() = URL Then
			Form = ClientApplicationWindow.Content[0];
			NotifyDescription = New NotifyDescription("GoToListCompletion", ThisObject, 
				New Structure("Form, URL", Form, URL));
			Buttons = New ValueList;
			Buttons.Add("Reopen", NStr("en = 'Reopen';"));
			Buttons.Add("Cancel", NStr("en = 'Do not reopen';"));
			QueryText = 
				NStr("en = 'The list is already open. Reopen the list
				|to see the changes in Print menu?';");
			ShowQueryBox(NotifyDescription, QueryText, Buttons, , "Reopen");
			Return;
		EndIf;
	EndDo;
	
	FileSystemClient.OpenURL(URL);
EndProcedure

&AtClient
Procedure GoToListCompletion(QuestionResult, AdditionalParameters) Export
	If QuestionResult = "Cancel" Then
		Return;
	EndIf;
	
	AdditionalParameters.Form.Close();
	FileSystemClient.OpenURL(AdditionalParameters.URL);
EndProcedure

&AtClient
Procedure BeforeCloseConfirmationReceived(QuestionResult, AdditionalParameters) Export
	WriteAndClose();
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PrintCommands.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PrintCommands.Visible");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

#EndRegion

