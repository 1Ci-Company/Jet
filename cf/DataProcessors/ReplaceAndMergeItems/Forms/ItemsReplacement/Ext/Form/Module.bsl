///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

// Form parameters are:
//  RefSet - Array, ValueList - Items to be replaced with another Ref-type item.
//

#Region Variables

&AtClient
Var ReportsToSend; // Array of ErrorReport 

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.OpenByScenario Then
		Raise NStr("en = 'The data processor cannot be opened manually.';");
	EndIf;
	
	InitializeReferencesToReplace(RefArrayFromList(Parameters.RefSet));
	
	HasRightToDeletePermanently = AccessRight("DataAdministration", Metadata);
	ReplacementNotificationEvent        = DataProcessors.ReplaceAndMergeItems.ReplacementNotificationEvent();
	CurrentDeletionOption          = "Check";
	
	// Initializing a dynamic list on the form - selection form imitation.
	BasicMetadata = ReplacementItem.Metadata();
	List.CustomQuery = False;
	
	DynamicListParameters = Common.DynamicListPropertiesStructure();
	DynamicListParameters.MainTable = BasicMetadata.FullName();
	DynamicListParameters.DynamicDataRead = True;
	Common.SetDynamicListProperties(Items.List, DynamicListParameters);
	
	Items.List.ChangeRowOrder = False;
	Items.List.ChangeRowSet  = False;
	
	ItemsToReplaceList = New ValueList;
	ItemsToReplaceList.LoadValues(RefsToReplace.Unload().UnloadColumn("Ref"));
	CommonClientServer.SetDynamicListFilterItem(List, "Ref", ItemsToReplaceList,
		DataCompositionComparisonType.NotInList, NStr("en = 'Do not show replaceable items';"), True, 
		DataCompositionSettingsItemViewMode.Inaccessible, "5bf5cd06-c1fd-4bd3-94b9-4e9803e90fd5");
	If ReferencesToReplaceCommonOwner <> Undefined Then 
		CommonClientServer.SetDynamicListFilterItem(List, "Owner", ReferencesToReplaceCommonOwner);
		Items.ListFilterTooltip.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The list contains suitable options with the filter: %2 = %3.';"),
			Common.ListPresentation(BasicMetadata),
			OwnerPresentation(BasicMetadata),
			Common.SubjectString(ReferencesToReplaceCommonOwner));
	Else
		Items.ListFilterTooltip.Visible = False;
	EndIf;
	
	If RefsToReplace.Count() > 1 Then
		Items.SelectedItemTypeLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Select one of the %1 items. The item will replace all %2 selected values:';"),
			BasicMetadata.Presentation(), RefsToReplace.Count());
	Else
		Title = NStr("en = 'Item replacement';");
		Items.SelectedItemTypeLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Select one of the %1 items. The item will replace %2:';"),
			BasicMetadata.Presentation(), RefsToReplace[0].Ref);
	EndIf;
	Items.ReplacementItemSelectionTooltip.Title = NStr("en = 'Replacement item required.';");
	
	// Initialize the step-by-step wizard.
	WizardSettings = StepByStepWizardSettings(Items);
	
	// 1. Select main item.
	StepSelect = AddWizardStep(Items.ReplacementItemSelectionStep);
	StepSelect.BackButton.Visible = False;
	StepSelect.NextButton.Title = NStr("en = 'Replace >';");
	StepSelect.NextButton.ToolTip = NStr("en = 'Start replacement.';");
	StepSelect.CancelButton.Title = NStr("en = 'Cancel';");
	StepSelect.CancelButton.ToolTip = NStr("en = 'Cancel replacement.';");
	
	// 2. Waiting for process.
	Step = AddWizardStep(Items.ReplacementStep);
	Step.CancelButton.Visible = False;
	Step.NextButton.Visible = False;
	Step.BackButton.Title = NStr("en = 'Abort';");
	Step.BackButton.ToolTip = NStr("en = 'Return to selection of the main item.';");
	
	// 3. Reference replacement issues.
	Step = AddWizardStep(Items.RetryReplacementStep);
	Step.BackButton.Title = NStr("en = '< Back';");
	Step.BackButton.ToolTip = NStr("en = 'Return to selecting replacement item.';");
	Step.NextButton.Title = NStr("en = 'Replace again >';");
	Step.NextButton.ToolTip = NStr("en = 'Replace again.';");
	Step.CancelButton.Title = NStr("en = 'Close';");
	Step.CancelButton.ToolTip = NStr("en = 'Close replacement results.';");
	
	// 4 Runtime errors.
	Step = AddWizardStep(Items.ErrorOccurredStep);
	Step.BackButton.Visible = False;
	Step.NextButton.Visible = False;
	Step.CancelButton.Title = NStr("en = 'Close';");
	
	// Update form items.
	WizardSettings.CurrentStep = StepSelect;
	VisibleEnabled(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	OnActivateWizardStep();
	ReportsToSend = New Map;
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Items.WizardSteps.CurrentPage <> Items.ReplacementStep
		Or Not WizardSettings.ShowDialogBeforeClose Then
		Return;
	EndIf;
	
	Cancel = True;
	If Exit Then
		Return;
	EndIf;
	
	QueryText = NStr("en = 'Do you want to abort replacing and close the form?';");
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Abort, NStr("en = 'Abort';"));
	Buttons.Add(DialogReturnCode.No,      NStr("en = 'Continue';"));
	
	Handler = New NotifyDescription("AfterConfirmCancelJob", ThisObject);
	ShowQueryBox(Handler, QueryText, Buttons, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	For Each UnsuccessfulReplacement In UnsuccessfulReplacements.GetItems() Do
		For Each DetailsOfReplacement In UnsuccessfulReplacement.GetItems() Do
			If DetailsOfReplacement.ErrorInfo = Undefined Then
				Continue;
			EndIf;
			ReportToSend = ReportsToSend[DetailsOfReplacement.ErrorInfo];
			If ReportToSend = Undefined Then
				ReportToSend = New ErrorReport(DetailsOfReplacement.ErrorInfo);
			EndIf;
			StandardSubsystemsClient.SendErrorReport(ReportToSend,
				DetailsOfReplacement.ErrorInfo);
		EndDo
	EndDo
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ReplacementItemSelectionTooltipURLProcessing(Item, Ref, StandardProcessing)
	
	StandardProcessing = False;
	
	If Ref = "SwitchDeletionMode" Then
		If CurrentDeletionOption = "Directly" Then
			CurrentDeletionOption = "Check" 
		Else
			CurrentDeletionOption = "Directly" 
		EndIf;
		
		GenerateReplacementItemAndTooltip(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure DetailsRefClick(Item)
	StandardSubsystemsClient.ShowDetailedInfo(Undefined, Item.ToolTip);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("GenerateReplacementItemAndTooltipDeferred", 0.01, True);
	
EndProcedure

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	StepReplacementItemSelectionOnClickNextButton();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersUnsuccessfulReplacements

&AtClient
Procedure UnsuccessfulReplacementsOnActivateRow(Item)
	
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined Then
		FailureReasonDetails = "";	
		Items.DecorationSendErrorReport.Visible = False;
		Return;
	EndIf;
		
	FailureReasonDetails = CurrentData.DetailedReason;
	If CurrentData.ErrorInfo = Undefined Then
		Items.DecorationSendErrorReport.Visible = False;
	Else
		StandardSubsystemsClient.ConfigureVisibilityAndTitleForURLSendErrorReport(
			Items.DecorationSendErrorReport, CurrentData.ErrorInfo);
	EndIf;
			
EndProcedure

&AtClient
Procedure UnsuccessfulReplacementsSelection(Item, RowSelected, Field, StandardProcessing)

	StandardProcessing = False;
	Ref = UnsuccessfulReplacements.FindByID(RowSelected).Ref;
	If Ref <> Undefined Then
		ShowValue(, Ref);
	EndIf;

EndProcedure

&AtClient
Procedure DecorationSendErrorReportClick(Item)

	CurrentData = Items.UnsuccessfulReplacements.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;

	ReportToSend = ReportsToSend[CurrentData.ErrorInfo];
	If ReportToSend = Undefined Then
		ReportToSend = New ErrorReport(CurrentData.ErrorInfo);
		ReportsToSend[CurrentData.ErrorInfo] = ReportToSend;
	EndIf;
	StandardSubsystemsClient.ShowErrorReport(ReportToSend);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WizardButtonHandler(Command)
	
	If Command.Name = WizardSettings.NextButton Then
		
		WizardStepNext();
		
	ElsIf Command.Name = WizardSettings.BackButton Then
		
		WizardStepBack();
		
	ElsIf Command.Name = WizardSettings.CancelButton Then
		
		WizardStepCancel();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenUnsuccessfulReplacementItem(Command)
	CurrentData = Items.UnsuccessfulReplacements.CurrentData;
	If CurrentData <> Undefined Then
		ShowValue(, CurrentData.Ref);
	EndIf;
EndProcedure

&AtClient
Procedure ExpandAllUnsuccessfulReplacements(Command)
	FormTree = Items.UnsuccessfulReplacements;
	For Each Item In UnsuccessfulReplacements.GetItems() Do
		FormTree.Expand(Item.GetID(), True);
	EndDo;
EndProcedure

&AtClient
Procedure CollapseAllUnsuccessfulReplacements(Command)
	FormTree = Items.UnsuccessfulReplacements;
	For Each Item In UnsuccessfulReplacements.GetItems() Do
		FormTree.Collapse(Item.GetID());
	EndDo;
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Wizard API

// Initializes wizard structures.
// 
// Parameters:
//   Items - FormItems 
// 
// Returns:
//   Structure - Describes wizard settings.
//     Public wizard settings are:
//       * Steps - Array - description of wizard steps. Read only.
//           To add steps, use the AddWizardStep function.
//       * CurrentStep - See AddWizardStep.
//       * ShowDialogBeforeClose - Boolean - if True, a warning will be displayed before closing the form.
//           For changing.
//     Internal wizard settings:
//       * PagesGroup - String - a form item name that is passed to the PageGroup parameter.
//       * NextButton - String - a form item name that is passed to the NextButton parameter.
//       * BackButton - String - a form item name that is passed to the BackButton parameter.
//       * CancelButton - String - a form item name that is passed to the CancelButton parameter.
//
&AtServerNoContext
Function StepByStepWizardSettings(Items)
	WizardSettings = New Structure;
	WizardSettings.Insert("Steps", New Array);
	WizardSettings.Insert("CurrentStep", Undefined);
	
	// Interface part IDs.
	WizardSettings.Insert("PagesGroup", Items.WizardSteps.Name);
	WizardSettings.Insert("NextButton",   Items.WizardStepNext.Name);
	WizardSettings.Insert("BackButton",   Items.WizardStepBack.Name);
	WizardSettings.Insert("CancelButton",  Items.WizardStepCancel.Name);
	
	// To process long-running operations.
	WizardSettings.Insert("ShowDialogBeforeClose", False);
	
	// Everything is disabled by default.
	Items.WizardStepNext.Visible  = False;
	Items.WizardStepBack.Visible  = False;
	Items.WizardStepCancel.Visible = False;
	
	Return WizardSettings;
EndFunction

// Adds a wizard step. Navigation between pages is performed according to the order the pages are added.
//
// Parameters:
//   Page - FormGroup - a page that contains step items.
//
// Returns:
//   Structure - Describes page settings, where:
//       * PageName - String - a page name.
//       * NextButton - Structure - description of "Next" button, where:
//           ** Title - String - a button title. The default value is "Next >".
//           ** ToolTip - String - button tooltip. Corresponds to the button title by default.
//           ** Visible - Boolean - if True, the button is visible. Default value is True.
//           ** Enabled - Boolean - if True, the button is clickable. Default value is True.
//           ** DefaultButton - Boolean - if True, the button is the main button of the form. Default value is True.
//       * BackButton - Structure - description of the "Back" button, where:
//           ** Title - String - a button title. Default value - "< Back".
//           ** ToolTip - String - button tooltip. Corresponds to the button title by default.
//           ** Visible - Boolean - if True, the button is visible. Default value is True.
//           ** Enabled - Boolean - if True, the button is clickable. Default value is True.
//           ** DefaultButton - Boolean - if True, the button is the main button of the form. Default value is False.
//       * CancelButton - Structure - description of the "Cancel" button, where:
//           ** Title - String - a button title. The default value is "Cancel".
//           ** ToolTip - String - button tooltip. Corresponds to the button title by default.
//           ** Visible - Boolean - if True, the button is visible. Default value is True.
//           ** Enabled - Boolean - if True, the button is clickable. Default value is True.
//           ** DefaultButton - Boolean - if True, the button is the main button of the form. Default value is False.
//
&AtServer
Function AddWizardStep(Val Page)
	StepDescription = New Structure;
	StepDescription.Insert("IndexOf", 0);
	StepDescription.Insert("PageName", "");
	StepDescription.Insert("BackButton", WizardButton());
	StepDescription.Insert("NextButton", WizardButton());
	StepDescription.Insert("CancelButton", WizardButton());
	 
	StepDescription.PageName = Page.Name;
	
	StepDescription.BackButton.Title = NStr("en = '< Back';");
	
	StepDescription.NextButton.DefaultButton = True;
	StepDescription.NextButton.Title = NStr("en = 'Next >';");
	
	StepDescription.CancelButton.Title = NStr("en = 'Cancel';");
	
	WizardSettings.Steps.Add(StepDescription);
	
	StepDescription.IndexOf = WizardSettings.Steps.UBound();
	Return StepDescription;
EndFunction

// Updates visibility and availability of form items according to the current wizard step.
&AtClientAtServerNoContext
Procedure VisibleEnabled(Form)
	
	Items = Form.Items;
	WizardSettings = Form.WizardSettings;
	CurrentStep = WizardSettings.CurrentStep;
	
	// Navigate to the page.
	Items[WizardSettings.PagesGroup].CurrentPage = Items[CurrentStep.PageName];
	
	// Update buttons.
	UpdateWizardButtonProperties(Items[WizardSettings.NextButton],  CurrentStep.NextButton);
	UpdateWizardButtonProperties(Items[WizardSettings.BackButton],  CurrentStep.BackButton);
	UpdateWizardButtonProperties(Items[WizardSettings.CancelButton], CurrentStep.CancelButton);
	
EndProcedure

// Navigates to the specified page.
//
// Parameters:
//   StepOrIndexOrFormGroup - Structure
//                              - Number
//                              - FormGroup - a page to navigate to.
//
&AtClient
Procedure GoToWizardStep1(Val StepOrIndexOrFormGroup)
	
	// Search for step.
	Type = TypeOf(StepOrIndexOrFormGroup);
	If Type = Type("Structure") Then
		StepDescription = StepOrIndexOrFormGroup;
	ElsIf Type = Type("Number") Then
		StepIndex = StepOrIndexOrFormGroup;
		If StepIndex < 0 Then
			Raise NStr("en = 'Attempt to go back from the first step.';");
		ElsIf StepIndex > WizardSettings.Steps.UBound() Then
			Raise NStr("en = 'Attempt to go next from the last step.';");
		EndIf;
		StepDescription = WizardSettings.Steps[StepIndex];
	Else
		StepFound = False;
		RequiredPageName = StepOrIndexOrFormGroup.Name;
		For Each StepDescription In WizardSettings.Steps Do
			If StepDescription.PageName = RequiredPageName Then
				StepFound = True;
				Break;
			EndIf;
		EndDo;
		If Not StepFound Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Step %1 is not found.';"),
				RequiredPageName);
		EndIf;
	EndIf;
	
	// Step switch.
	WizardSettings.CurrentStep = StepDescription;
	
	// Update visibility.
	VisibleEnabled(ThisObject);
	OnActivateWizardStep();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Wizard events

&AtClient
Procedure OnActivateWizardStep()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.ReplacementItemSelectionStep Then
		
		GenerateReplacementItemAndTooltip(ThisObject);
		
	ElsIf CurrentPage = Items.ReplacementStep Then
		
		WizardSettings.ShowDialogBeforeClose = True;
		ReplacementItemResult = ReplacementItem; // Save start parameters.
		StartReplacingLinks();
		
	ElsIf CurrentPage = Items.RetryReplacementStep Then
		
		// Update number of failures.
		Unsuccessful = New Map;
		For Each Item In UnsuccessfulReplacements.GetItems() Do
			Unsuccessful.Insert(Item.Ref, True);
		EndDo;
		
		ReplacementsCount = RefsToReplace.Count();
		If ReplacementsCount > 1 Then 
			Items.UnsuccessfulReplacementsResult.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot automatically replace some items to ""%3"". %1 out of %2 items were not replaced.';"),
				Unsuccessful.Count(),
				ReplacementsCount,
				ReplacementItem);
		Else
			Items.UnsuccessfulReplacementsResult.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot automatically replace some items to ""%1"". Some items were not replaced.';"),
				ReplacementItem);
		EndIf;
		
		// Generating a list of successful replacements and clearing a list of items to replace.
		UpdatedItemsList = New Array;
		UpdatedItemsList.Add(ReplacementItem);
		For Number = 1 To ReplacementsCount Do
			ReverseIndex = ReplacementsCount - Number;
			Ref = RefsToReplace[ReverseIndex].Ref;
			If Ref <> ReplacementItem And Unsuccessful[Ref] = Undefined Then
				RefsToReplace.Delete(ReverseIndex);
				UpdatedItemsList.Add(Ref);
			EndIf;
		EndDo;
		
		// Notification of completed replacements.
		NotifyOfSuccessfulReplacement(UpdatedItemsList);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepNext()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	If CurrentPage = Items.ReplacementItemSelectionStep Then
		StepReplacementItemSelectionOnClickNextButton();
	ElsIf CurrentPage = Items.RetryReplacementStep Then
		GoToWizardStep1(Items.ReplacementStep);
	Else
		CurrentStep = WizardSettings.CurrentStep; // See AddWizardStep
		GoToWizardStep1(CurrentStep.IndexOf + 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepBack()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	If CurrentPage = Items.RetryReplacementStep Then
		GoToWizardStep1(Items.ReplacementItemSelectionStep);
	Else
		Step = WizardSettings.CurrentStep; // See AddWizardStep
		GoToWizardStep1(Step.IndexOf - 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepCancel()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	If CurrentPage = Items.ReplacementStep Then
		WizardSettings.ShowDialogBeforeClose = False;
	EndIf;
	
	If IsOpen() Then
		Close();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal procedures for item replacement and merging

&AtClient
Procedure StepReplacementItemSelectionOnClickNextButton()
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
	ElsIf RefsToReplace.Count() = 1 And CurrentData.Ref = RefsToReplace.Get(0).Ref Then
		ShowMessageBox(, NStr("en = 'Cannot replace an item with itself.';"));
		Return;
	ElsIf AttributeValue(CurrentData, "IsFolder", False) Then
		ShowMessageBox(, NStr("en = 'Cannot replace an item with a group.';"));
		Return;
	EndIf;
	
	CurrentOwner = AttributeValue(CurrentData, "Owner");
	If CurrentOwner <> ReferencesToReplaceCommonOwner Then
		Text = NStr("en = 'Cannot replace an item with the item that belongs to another owner.
			|Owner of the selected item:%1. Owner of the replacement item: %2.';");
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(Text, CurrentOwner, ReferencesToReplaceCommonOwner));
		Return;
	EndIf;
	
	If AttributeValue(CurrentData, "DeletionMark", False) Then
		// Attempt to replace with an item marked for deletion.
		Text = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Item %1 is marked for deletion. Continue?';"),
			CurrentData.Ref);
		LongDesc = New NotifyDescription("ConfirmItemSelection", ThisObject);
		ShowQueryBox(LongDesc, Text, QuestionDialogMode.YesNo);
	Else
		// Additional check for applied data is required.
		AppliedAreaReplacementAvailabilityCheck();
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyOfSuccessfulReplacement(Val DataList)
	CommonClient.NotifyObjectsChanged(DataList);
EndProcedure

&AtClient
Procedure GenerateReplacementItemAndTooltipDeferred()
	GenerateReplacementItemAndTooltip(ThisObject);
EndProcedure

&AtClient
Procedure ConfirmItemSelection(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	// Additional check by applied data.
	AppliedAreaReplacementAvailabilityCheck();
EndProcedure

&AtClient
Procedure AppliedAreaReplacementAvailabilityCheck()
	// Checking items replacement for validity in terms of applied data.
	ErrorText = CheckCanReplaceReferences();
	If Not IsBlankString(ErrorText) Then
		DialogSettings = New Structure;
		DialogSettings.Insert("PromptDontAskAgain", False);
		DialogSettings.Insert("Picture", PictureLib.DialogExclamation);
		DialogSettings.Insert("DefaultButton", 0);
		DialogSettings.Insert("Title", NStr("en = 'Cannot replace items';"));
		
		Buttons = New ValueList;
		Buttons.Add(0, NStr("en = 'OK';"));
		
		StandardSubsystemsClient.ShowQuestionToUser(Undefined, ErrorText, Buttons, DialogSettings);
		Return;
	EndIf;
	
	Step = WizardSettings.CurrentStep;// See AddWizardStep
	GoToWizardStep1(Step.IndexOf + 1);
EndProcedure

&AtClient
Procedure GenerateReplacementItemAndTooltip(Context)
	
	CurrentData = Context.Items.List.CurrentData;
	If CurrentData = Undefined Or AttributeValue(CurrentData, "IsFolder", False) Then
		Return;
	EndIf;
	Context.ReplacementItem = CurrentData.Ref;
	
	Count = Context.RefsToReplace.Count();
	If Count = 1 Then
		
		If Context.HasRightToDeletePermanently Then
			If Context.CurrentDeletionOption = "Check" Then
				ToolTipText = NStr("en = 'The selected item will be replaced with ""[ReplacementItem]""
					|and <a href = ""[Hyperlink]"">marked for deletion</a>.';");
			Else
				ToolTipText = NStr("en = 'The selected item will be replaced with ""[ReplacementItem]""
					|and <a href = ""[Hyperlink]"">permanently deleted</a>.';");
			EndIf;
		Else
			ToolTipText = NStr("en = 'The selected item will be replaced with ""[ReplacementItem]""
				|and marked for deletion.';");
		EndIf;
		
		RowParameters = New Structure();
		RowParameters.Insert("ReplacementItem", Context.ReplacementItem);
		RowParameters.Insert("Hyperlink", "SwitchDeletionMode");
		
		ToolTipText = StringFunctionsClientServer.InsertParametersIntoString(ToolTipText, RowParameters);
		Context.Items.ReplacementItemSelectionTooltip.Title = StringFunctionsClient.FormattedString(ToolTipText);
		
	Else
		
		If Context.HasRightToDeletePermanently Then
			If Context.CurrentDeletionOption = "Check" Then
				ToolTipText = NStr("en = 'Selected items (%1) will be replaced with ""%2""
					|and <a href = ""[Action]"">marked for deletion</a>.';");
				RowParameters = New Structure("Action", "SwitchDeletionMode");
				ToolTipText = StringFunctionsClientServer.InsertParametersIntoString(ToolTipText, RowParameters);
			Else
				ToolTipText = NStr("en = 'Selected items (%1) will be replaced with ""%2""
					|and <a href = ""[Action]"">permanently deleted</a>.';");
				RowParameters = New Structure("Action", "SwitchDeletionMode");
				ToolTipText = StringFunctionsClientServer.InsertParametersIntoString(ToolTipText, RowParameters);
			EndIf;
		Else
			ToolTipText = NStr("en = 'All %1 selected items will be replaced with %2
				|and marked for deletion.';");
		EndIf;
			
		ToolTipText = StringFunctionsClientServer.SubstituteParametersToString(ToolTipText, Count, Context.ReplacementItem);
		Context.Items.ReplacementItemSelectionTooltip.Title = StringFunctionsClient.FormattedString(ToolTipText);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function OwnerPresentation(BasicMetadata)
	For Each Attribute In BasicMetadata.StandardAttributes Do
		If Attribute.Name = "Owner" Then
			Return Attribute.Synonym;	
		EndIf;
	EndDo;
	Return "";	
EndFunction

&AtClientAtServerNoContext
Function AttributeValue(Val Data, Val AttributeName, Val ValueIfNotFound = Undefined)
	// Gets an attribute value safely.
	Trial = New Structure(AttributeName);
	
	FillPropertyValues(Trial, Data);
	If Trial[AttributeName] <> Undefined Then
		// There is a value.
		Return Trial[AttributeName];
	EndIf;
	
	// Value in data might be set to Undefined.
	Trial[AttributeName] = True;
	FillPropertyValues(Trial, Data);
	If Trial[AttributeName] <> True Then
		Return Trial[AttributeName];
	EndIf;
	
	Return ValueIfNotFound;
EndFunction

&AtServer
Function CheckCanReplaceReferences()
	
	ReplacementPairs = New Map;
	For Each RefToReplace In RefsToReplace Do
		ReplacementPairs.Insert(RefToReplace.Ref, ReplacementItem);
	EndDo;
	
	ReplacementParameters = New Structure("DeletionMethod", CurrentDeletionOption);
	Return DuplicateObjectsDetection.CheckCanReplaceItemsString(ReplacementPairs, ReplacementParameters);
	
EndFunction

// Parameters:
//   References - ValueList of AnyRef
//          - Array of AnyRef
//          - ValueTable:
//        * Ref - AnyRef
// Returns:
//   Array
//
&AtServerNoContext
Function RefArrayFromList(Val References)
	// Converts an array, list of values, or collection to an array.
	
	ParameterType = TypeOf(References);
	If References = Undefined Then
		ReferencesArrray = New Array;
		
	ElsIf ParameterType  = Type("ValueList") Then
		ReferencesArrray = References.UnloadValues();
		
	ElsIf ParameterType = Type("Array") Then
		ReferencesArrray = References;
		
	Else
		ReferencesArrray = New Array;
		For Each Item In References Do
			ReferencesArrray.Add(Item.Ref);
		EndDo;
		
	EndIf;
	
	Return ReferencesArrray;
EndFunction

&AtServerNoContext
Function ObjectCode(Val Ref, MetadataCache)
	
	Meta = Ref.Metadata();
	HasCode = MetadataCache[Meta];
	
	If HasCode = Undefined Then
		// Checking whether the code exists.
		Test = New Structure("CodeLength", 0);
		FillPropertyValues(Test, Meta);
		HasCode = Test.CodeLength > 0;
		
		MetadataCache[Meta] = HasCode;
	EndIf;
	
	Return ?(HasCode, Common.ObjectAttributeValue(Ref, "Code"), Undefined);
EndFunction

&AtServer
Procedure InitializeReferencesToReplace(Val ReferencesArrray)
	
	RefsCount = ReferencesArrray.Count();
	If RefsCount = 0 Then
		Raise NStr("en = 'Select at least one item to replace.';");
	EndIf;
	
	ReplacementItem = ReferencesArrray[0];
	BasicMetadata = ReplacementItem.Metadata();
	VerifyAccessRights("Update", BasicMetadata);
	
	Characteristics = New Structure("Owners, Hierarchical, HierarchyType", New Array, False);
	FillPropertyValues(Characteristics, BasicMetadata);
	
	HasOwners = Characteristics.Owners.Count() > 0;
	HasGroups    = Characteristics.Hierarchical And Characteristics.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems;
	
	QueryText =
		"SELECT
		|Ref AS Ref,
		|&Field_Owner AS Owner,
		|&IsFolder AS IsFolder
		|INTO RefsToReplace
		|FROM
		|	#TableName
		|WHERE
		|	Ref IN (&RefSet)
		|INDEX BY
		|	Owner,
		|	IsFolder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	COUNT(DISTINCT Owner) AS OwnersCount,
		|	MIN(Owner)              AS CommonOwner,
		|	MAX(IsFolder)            AS HasGroups,
		|	COUNT(Ref)             AS RefsCount
		|FROM
		|	RefsToReplace
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	DestinationTable2.Ref
		|FROM
		|	#TableName AS DestinationTable2
		|		LEFT JOIN RefsToReplace AS RefsToReplace
		|		ON DestinationTable2.Ref = RefsToReplace.Ref
		|WHERE
		|	RefsToReplace.Ref IS NULL
		|	AND &ConditionGroup
		|	AND &ConditionOwner";
	QueryText = StrReplace(QueryText, "#TableName", BasicMetadata.FullName());
	QueryText = StrReplace(QueryText, "&Field_Owner", ?(HasOwners, "Owner", "UNDEFINED"));
	QueryText = StrReplace(QueryText, "&IsFolder", ?(HasGroups, "IsFolder", "FALSE"));
	QueryText = StrReplace(QueryText, "&ConditionOwner", 
		?(HasOwners, "DestinationTable2.Owner = &Owner", "TRUE")); // @query-part
	QueryText = StrReplace(QueryText, "&ConditionGroup", 
		?(HasGroups, "NOT DestinationTable2.IsFolder", "TRUE")); // @query-part
		
	Query = New Query(QueryText);
	Query.SetParameter("RefSet", ReferencesArrray);
	If HasOwners Then
		Query.SetParameter("Owner", Common.ObjectAttributeValue(ReplacementItem, "Owner"));
	EndIf;
	
	Result = Query.ExecuteBatch();
	Conditions = Result[1].Unload()[0];
	If Conditions.HasGroups Then
		Raise NStr("en = 'One of the items to replace is a group.
			|Groups cannot be replaced.';");
	ElsIf Conditions.OwnersCount > 1 Then 
		Raise NStr("en = 'Items to replace have different owners.
			|They cannot be replaced.';");
	ElsIf Conditions.RefsCount <> RefsCount Then
		Raise NStr("en = 'All items to replace must be of the same type.';");
	EndIf;
	
	If Result[2].Unload().Count() = 0 Then
		If RefsCount > 1 Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The selected items (%1) cannot be replaced as there are no suitable items for replacement.';"), 
				RefsCount);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The selected %1 item cannot be replaced as there are no suitable items for replacement.';"), 
				Common.SubjectString(ReplacementItem));
		EndIf;
	EndIf;
	
	ReferencesToReplaceCommonOwner = ?(HasOwners, Conditions.CommonOwner, Undefined);
	For Each Item In ReferencesArrray Do
		RefsToReplace.Add().Ref = Item;
	EndDo;
	Items.List.Representation = ?(Conditions.HasGroups, TableRepresentation.HierarchicalList, TableRepresentation.List);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Long-running operation management

&AtClient
Procedure StartReplacingLinks()
	
	ReportsToSend = New Map;
	
	MethodParameters = New Structure("ReplacementPairs, DeletionMethod");
	MethodParameters.ReplacementPairs = New Map;
	For Each RefToReplace In RefsToReplace Do
		MethodParameters.ReplacementPairs.Insert(RefToReplace.Ref, ReplacementItem);
	EndDo;
	MethodParameters.Insert("DeletionMethod", CurrentDeletionOption);
	
	Job = ReplaceReferences(MethodParameters, UUID);
	
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	WaitSettings.OutputIdleWindow = False;
	
	Handler = New NotifyDescription("AfterCompletionReplacingLinks", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(Job, Handler, WaitSettings);
	
EndProcedure

&AtServerNoContext
Function ReplaceReferences(Val MethodParameters, Val UUID)
	
	MethodName = "DuplicateObjectsDetection.ReplaceReferences";
	MethodDescription = NStr("en = 'Duplicate cleaner: Replace references';");
	
	StartSettings1 = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings1.BackgroundJobDescription = MethodDescription;
	
	Return TimeConsumingOperations.ExecuteInBackground(MethodName, MethodParameters, StartSettings1);
	
EndFunction

&AtClient
Procedure AfterCompletionReplacingLinks(Job, AdditionalParameters) Export
	
	WizardSettings.ShowDialogBeforeClose = False;
	If Job = Undefined 
		Or Items.WizardSteps.CurrentPage = Items.ReplacementItemSelectionStep Then
		Return;
	EndIf;
	
	If Job.Status <> "Completed2" Then
		// Background job is completed with error.
		Brief1 = NStr("en = 'Items were not replaced due to:';") + Chars.LF + Job.BriefErrorDescription;
		More = Brief1 + Chars.LF + Chars.LF + Job.DetailErrorDescription;
		Items.ErrorTextLabel.Title = Brief1;
		Items.DetailsRef.ToolTip    = More;
		GoToWizardStep1(Items.ErrorOccurredStep);
		Activate();
		Return;
	EndIf;
	
	HasUnsuccessfulReplacements = FillUnsuccessfulReplacements(Job.ResultAddress);
	If HasUnsuccessfulReplacements Then
		// Partially successful: display the details.
		GoToWizardStep1(Items.RetryReplacementStep);
		Activate();
	Else
		// Completely successful: display the notification and close the form.
		Count = RefsToReplace.Count();
		If Count = 1 Then
			ResultingText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Item %1 has been replaced with %2.';"),
				RefsToReplace[0].Ref,
				ReplacementItemResult);
		Else
			ResultingText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 items have been replaced with %2.';"),
				Count,
				ReplacementItemResult);
		EndIf;
		ShowUserNotification(, GetURL(ReplacementItem),
			ResultingText, PictureLib.DialogInformation);
		UpdatedItemsList = New Array;
		For Each RefToReplace In RefsToReplace Do
			UpdatedItemsList.Add(RefToReplace.Ref);
		EndDo;
		NotifyOfSuccessfulReplacement(UpdatedItemsList);
		Close();
	EndIf
	
EndProcedure

&AtServer
Function FillUnsuccessfulReplacements(Val ResultAddress)
	ReplacementResults = GetFromTempStorage(ResultAddress); // See Common.ReplaceReferences
	
	RootRows = UnsuccessfulReplacements.GetItems();
	RootRows.Clear();
	
	RowsMap = New Map;
	MetadataCache     = New Map;
	
	For Each ResultString1 In ReplacementResults Do
		Ref = ResultString1.Ref;
		
		ErrorsByReference = RowsMap[Ref];
		If ErrorsByReference = Undefined Then
			TreeRow = RootRows.Add();
			TreeRow.Ref = Ref;
			TreeRow.Data = String(Ref);
			TreeRow.Code    = String(ObjectCode(Ref, MetadataCache));
			TreeRow.Pictogram = -1;
			
			ErrorsByReference = TreeRow.GetItems();
			RowsMap.Insert(Ref, ErrorsByReference);
		EndIf;
		
		ErrorString = ErrorsByReference.Add();
		ErrorString.Ref = ResultString1.ErrorObject;
		ErrorString.Data = ResultString1.ErrorObjectPresentation;
		
		ErrorType = ResultString1.ErrorType;
		If ErrorType = "UnknownData" Then
			ErrorString.Cause = NStr("en = 'Found instances whose replacement wasn''t intended.';");
			
		ElsIf ErrorType = "LockError" Then
			ErrorString.Cause = NStr("en = 'Another user updated some data. Retry replacement.';");
			
		ElsIf ErrorType = "DataChanged1" Then
			ErrorString.Cause = NStr("en = 'Another user updated some data.';");
			
		ElsIf ErrorType = "WritingError" Then
			ErrorString.Cause = ?(ResultString1.ErrorInfo <> Undefined,
				ErrorProcessing.ErrorMessageForUser(ResultString1.ErrorInfo),
				ResultString1.ErrorText);
			
		ElsIf ErrorType = "DeletionError" Then
			ErrorString.Cause = NStr("en = 'Cannot delete data.';");
			
		Else
			ErrorString.Cause = NStr("en = 'Unexpected error.';");
			
		EndIf;
		
		ErrorString.ErrorInfo = ResultString1.ErrorInfo;
		ErrorString.DetailedReason = ?(ResultString1.ErrorInfo <> Undefined,
			ErrorProcessing.ErrorMessageForUser(ResultString1.ErrorInfo),
			ResultString1.ErrorText);
	EndDo;
	
	Return RootRows.Count() > 0;
EndFunction

&AtClient
Procedure AfterConfirmCancelJob(Response, ExecutionParameters) Export
	If Response = DialogReturnCode.Abort
		And Items.WizardSteps.CurrentPage = Items.ReplacementStep Then
		WizardSettings.ShowDialogBeforeClose = False;
		Close();
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Wizard's internal procedures and functions

// Description of wizard button settings.
//
// Returns:
//  Structure - Form's button settings, where:
//    * Title         - String - a button title.
//    * ToolTip         - String - button tooltip.
//    * Visible         - Boolean - if True, the button is visible. The default value is True.
//    * Enabled       - Boolean - if True, the button is clickable. The default value is True.
//    * DefaultButton - Boolean - if True, the button is the main button of the form. Default value is False.
//    * ExtendedTooltip - Structure:
//    ** Title - String
//
&AtClientAtServerNoContext
Function WizardButton()
	Result = New Structure;
	Result.Insert("Title", "");
	Result.Insert("ToolTip", "");
	
	Result.Insert("Enabled", True);
	Result.Insert("Visible", True);
	Result.Insert("DefaultButton", False);
	
	Return Result;
EndFunction

// Parameters:
//  WizardButton - See WizardButton
//  LongDesc - String
//
&AtClientAtServerNoContext
Procedure UpdateWizardButtonProperties(WizardButton, LongDesc)
	
	FillPropertyValues(WizardButton, LongDesc);
	WizardButton.ExtendedTooltip.Title = LongDesc.ToolTip;
	
EndProcedure

#EndRegion