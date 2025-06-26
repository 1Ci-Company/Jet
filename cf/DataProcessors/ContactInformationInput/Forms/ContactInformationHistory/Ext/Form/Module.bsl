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
	
	If Parameters.Property("ReadOnly") Then
		Items.History.ReadOnly = Parameters.ReadOnly;
	EndIf;
	
	ContactInformationTypeAttributes = Common.ObjectAttributesValues(Parameters.ContactInformationKind,
		"Description, Type, CheckValidity, EditingOption" );
	
	ContactInformationKind = Parameters.ContactInformationKind;
	ContactInformationType = ContactInformationTypeAttributes.Type;
	CheckValidity = ContactInformationTypeAttributes.CheckValidity;
	ContactInformationPresentation = ContactInformationTypeAttributes.Description;
	
	If TypeOf(Parameters.ContactInformationList) = Type("Array") Then
		For Each ContactInformationRow In Parameters.ContactInformationList Do
			TableRow = History.Add();
			FillPropertyValues(TableRow, ContactInformationRow);
			TableRow.Type = ContactInformationType;
			TableRow.Kind = ContactInformationKind;
		EndDo;
		Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Change history (%1)';"), ContactInformationPresentation);
		Items.HistoryPresentation.Title = ContactInformationPresentation;
	Else
		Cancel = True;
	EndIf;
	EditInDialogOnly = ContactInformationTypeAttributes.EditingOption = "Dialog";
	If ContactInformationTypeAttributes.Type = Enums.ContactInformationTypes.Address Then
		EditFormName = "AddressInput";
	ElsIf ContactInformationTypeAttributes.Type = Enums.ContactInformationTypes.Phone Then
		EditFormName = "PhoneInput";
	Else
		EditFormName = "";
		Items.HistoryPresentation.ChoiceButton = False;
	EndIf;
	
	History.Sort("ValidFrom Desc");
	
	If Parameters.FromAddressEntryForm Then
		Items.HistorySelect.DefaultButton = True;
		ChoiceMode = Parameters.FromAddressEntryForm;
		Items.GroupCommandBar.Visible = False;
		Items.HistorySelect.Visible = True;
		Items.HistoryEdit.Visible = False;
		Items.HistoryPresentation.ReadOnly = True;
		If ValueIsFilled(Parameters.ValidFrom) Then
			Filter = New Structure("ValidFrom", Parameters.ValidFrom);
			FoundRows = History.FindRows(Filter);
			If FoundRows.Count() > 0 Then
				Items.History.CurrentRow = FoundRows[0].GetID();
			EndIf;
		EndIf;
	EndIf;
	
	If Common.IsMobileClient() Then
		Items.Move(Items.OK, Items.FormCommandBar);
		Items.Cancel.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersHistory

&AtClient
Procedure HistoryPresentationOnChange(Item)
	CurrentItem.CurrentData.FieldValues = ContactsXMLByPresentation(CurrentItem.CurrentData.Presentation, ContactInformationKind);
EndProcedure

&AtClient
Procedure HistoryBeforeDeleteRow(Item, Cancel)
	// If there is at least one record made earlier than the one to be deleted, you can delete it.
	ValidFrom = Item.CurrentData.ValidFrom;
	If IsFirstDate(ValidFrom) Then
		Cancel = True;
	EndIf;
	If Not Cancel Then
		AdditionalParameters = New Structure("RowID", Item.CurrentRow);
		Notification = New NotifyDescription("AfterAnswerToQuestionAboutDeletion", ThisObject, AdditionalParameters);
		ShowQueryBox(Notification, NStr("en = 'Do you want to remove address registered on';") + " " + Format(ValidFrom, "DLF=DD")+ "?", QuestionDialogMode.YesNo);
	EndIf;
	Cancel = True;
EndProcedure

&AtClient
Procedure HistoryBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	Cancel = True;
	If ChoiceMode Then
		GenerateData(True);
	Else
		OpenAddressEditForm(Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure HistoryBeforeRowChange(Item, Cancel)
	
	If Item.CurrentItem.Name = "HistoryValidFrom" Then
		If IsFirstDate(Item.CurrentData.ValidFrom) Then
			Cancel = True;
		EndIf;
		PreviousDate = Item.CurrentData.ValidFrom;
	Else
		OpenAddressEditForm(Items.History.CurrentRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure HistoryOnChange(Item)
	
	If Item.CurrentItem.Name = "HistoryValidFrom" Then
		IndexOf = History.IndexOf(CurrentItem.CurrentData);
		CurrentItem.CurrentData.ValidFrom = AllowedHistoryDate(PreviousDate, CurrentItem.CurrentData.ValidFrom, IndexOf);
		History.Sort("ValidFrom Desc");
	EndIf;
EndProcedure

&AtClient
Procedure AddressHistoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	If ChoiceMode Then
		GenerateData();
	EndIf;
	
EndProcedure

&AtClient
Procedure HistoryOnActivateRow(Item)
	
	If Item.CurrentData <> Undefined Then
		Items.HistoryEdit.Enabled = Not IsFirstDate(Item.CurrentData.ValidFrom) And Not ReadOnly;
		Items.HistoryDelete.Enabled = Not IsFirstDate(Item.CurrentData.ValidFrom) And Not ReadOnly;
		Items.HistoryContextMenuChange.Enabled = Not IsFirstDate(Item.CurrentData.ValidFrom) And Not ReadOnly;
		Items.HistoryContextMenuDelete.Enabled = Not IsFirstDate(Item.CurrentData.ValidFrom) And Not ReadOnly;
	EndIf;
	
EndProcedure

&AtClient
Procedure HistorySelection(Item, RowSelected, Field, StandardProcessing)
	
	If ChoiceMode Then
		GenerateData();
	EndIf;
	
EndProcedure

&AtClient
Procedure HistoryValidFromOnChange(Item)
	Modified = True;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	GenerateData();
EndProcedure

&AtClient
Procedure Cancel(Command)
	CloseFormWithoutSaving = True;
	Close();
EndProcedure

&AtClient
Procedure Select(Command)
	GenerateData();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GenerateData(EnterNewAddress = False)
	
	CloseFormWithoutSaving = True;
	Result = New Structure();
	
	DatesOptions = New Map;
	NoInitialDate = True;
	ValidAddress1 = 0;
	MinDelta = Undefined;
	CurrentCheckDate = CommonClient.SessionDate();
	For IndexOf = 0 To History.Count() - 1 Do
		If Not ValueIsFilled(History[IndexOf].ValidFrom) Then
			NoInitialDate = False;
		EndIf;
		If DatesOptions[History[IndexOf].ValidFrom] = Undefined Then
			DatesOptions.Insert(History[IndexOf].ValidFrom, True);
		Else
			CommonClient.MessageToUser(NStr("en = 'You cannot enter addresses with the same date.';"),, 
				"History[" + Format(IndexOf, "NG=0") + "].ValidFrom");
			Return;
		EndIf;
		Delta = History[IndexOf].ValidFrom - CurrentCheckDate;
		If Delta < 0 And (MinDelta = Undefined Or Delta > MinDelta) Then
			MinDelta = Delta;
			ValidAddress1 = IndexOf;
		EndIf;
		History[IndexOf].IsHistoricalContactInformation = True;
		History[IndexOf].StoreChangeHistory             = True;
	EndDo;
	
	History[ValidAddress1].IsHistoricalContactInformation = False;

	If Not EnterNewAddress And NoInitialDate Then
		ShowMessageBox(, NStr("en = 'An address valid on the accounting start date is required.';"));
		Return;
	EndIf;
	
	Result.Insert("History", History);
	Result.Insert("EditInDialogOnly", EditInDialogOnly);
	Result.Insert("Modified", Modified);
	If ChoiceMode Then
		Result.Insert("EnterNewAddress", EnterNewAddress);
		If EnterNewAddress Then
			Result.Insert("CurrentAddress", CommonClient.SessionDate());
		Else
			Result.Insert("CurrentAddress", Items.History.CurrentData.ValidFrom);
		EndIf;
	EndIf;
	
	Close(Result);

EndProcedure

&AtClient
Procedure OpenAddressEditForm(Val RowSelected)
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("ContactInformationKind", ContactInformationKind);
	OpeningParameters.Insert("FromHistoryForm", True);
	OpeningParameters.Insert("ReadOnly", Items.History.ReadOnly);
	If RowSelected = Undefined Then
		If History.Count() = 1 And IsBlankString(History[0].Presentation) Then
			OpeningParameters.Insert("ValidFrom", Date(1, 1, 1));
		Else
			OpeningParameters.Insert("ValidFrom", CommonClient.SessionDate());
		EndIf;
		OpeningParameters.Insert("EnterNewAddress", True);
		AdditionalParameters = New Structure("New", True);
	Else
		RowData = History.FindByID(RowSelected);
		OpeningParameters.Insert("FieldValues", RowData.FieldValues);
		OpeningParameters.Insert("Value",      RowData.Value);
		OpeningParameters.Insert("Presentation", RowData.Presentation);
		OpeningParameters.Insert("ValidFrom",    RowData.ValidFrom);
		OpeningParameters.Insert("Comment",   RowData.Comment);
		OpeningParameters.Insert("ContactInformationAdditionalAttributesDetails", History);
		AdditionalParameters = New Structure("ValidFrom, New", RowData.ValidFrom, Not ValueIsFilled(RowData.FieldValues));
	EndIf;
	
	Notification = New NotifyDescription("AfterAddressEdit", ThisObject, AdditionalParameters);
	ContactsManagerClient.OpenContactInformationForm(OpeningParameters,, Notification);
	
EndProcedure

&AtClient
Procedure AfterAnswerToQuestionAboutDeletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		History.Delete(History.FindByID(AdditionalParameters.RowID));
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.HistoryValidFrom.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("History.ValidFrom");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	Item.Appearance.SetParameterValue("ReadOnly", True);
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Default value';"));
	
EndProcedure

&AtClient
Function AllowedHistoryDate(OldDate, NewDate, IndexOf)
	
	Filter = New Structure("ValidFrom", NewDate);
	FoundRows = History.FindRows(Filter);
	If FoundRows.Count() > 1 Then
		CommonClient.MessageToUser(NStr("en = 'You cannot enter addresses with the same date.';"),, 
			"History[" + Format(IndexOf, "NG=0") + "].ValidFrom");
		If ValueIsFilled(OldDate) Then
			Return OldDate;
		Else
			Return CommonClient.SessionDate();
		EndIf;
	EndIf;
	
	Return NewDate;
EndFunction

// Parameters:
//  ClosingResult - Structure:
//    * AsHyperlink - Boolean
//    * EnteredInFreeFormat - Boolean
//    * Kind - CatalogRef.ContactInformationKinds
//    * ValidFrom - Date
//    * Value - String
//    * Comment - String
//    * ContactInformation - String
//    * ContactInformationAdditionalAttributesDetails - See ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm
//    * Presentation - String
//    * Type - EnumRef.ContactInformationTypes
//  AdditionalParameters - Structure
//
&AtClient
Procedure AfterAddressEdit(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;
	
	If AdditionalParameters.New Then
		
		ValidFrom = ClosingResult.ValidFrom;
		Filter = New Structure("ValidFrom", ValidFrom);
		FoundRows = History.FindRows(Filter);
		If FoundRows.Count() > 0 Then
			String = FoundRows[0];
		Else
			String = History.Insert(0);
		EndIf;
		
		String.ValidFrom = ClosingResult.ValidFrom;
		String.FieldValues = ClosingResult.ContactInformation;
		String.Value      = ClosingResult.Value;
		String.Presentation = ClosingResult.Presentation;
		String.Comment = ClosingResult.Comment;
		String.Kind = ClosingResult.Kind;
		String.Type = ClosingResult.Type;
		String.StoreChangeHistory = True;
		Items.History.CurrentRow = String.GetID();
		Items.History.CurrentItem = Items.History.ChildItems.HistoryPresentation;
		History.Sort("ValidFrom Desc");
	Else
		ValidFrom = AdditionalParameters.ValidFrom;
		Filter = New Structure("ValidFrom", ValidFrom);
		FoundRows = History.FindRows(Filter);
		If FoundRows.Count() > 0 Then
			FoundRows[0].Presentation = ClosingResult.Presentation;
			FoundRows[0].FieldValues = ClosingResult.ContactInformation;
			FoundRows[0].Comment = ClosingResult.Comment;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Function IsFirstDate(ValidFrom)
	
	For Each HistoryRow In History Do
		If HistoryRow.ValidFrom < ValidFrom Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
EndFunction

&AtServer
Function ContactsXMLByPresentation(Text, ContactInformationKind)
	
	Return ContactsManager.ContactsByPresentation(Text, ContactInformationKind);
	
EndFunction

#EndRegion