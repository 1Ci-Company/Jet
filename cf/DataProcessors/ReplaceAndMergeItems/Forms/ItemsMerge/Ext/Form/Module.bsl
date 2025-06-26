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
//     RefSet - Array of AnyRef - Items to be replaced with another Ref-type item.
//

#Region Variables

&AtClient
Var ReportsToSend; // Array of ErrorReport 

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	
	InitializeReferencesToMerge(Parameters.RefSet);
	
	ObjectMetadata = MainItem.Metadata();
	HasRightToDeletePermanently = AccessRight("DataAdministration", Metadata) 
		Or AccessRight("InteractiveDelete", ObjectMetadata);
	ReplacementNotificationEvent        = DataProcessors.ReplaceAndMergeItems.ReplacementNotificationEvent();
	
	CurrentDeletionOption = "Check";
	
	// Initialize the step-by-step wizard.
	InitializeStepByStepWizardSettings();
	
	// 1. Search for occurrences by parameter.
	SearchStep = AddWizardStep(Items.SearchForUsageInstancesStep);
	SearchStep.BackButton.Visible = False;
	SearchStep.NextButton.Visible = False;
	SearchStep.CancelButton.Title = NStr("en = 'Cancel';");
	SearchStep.CancelButton.ToolTip = NStr("en = 'Cancel merging.';");
	
	// 2. Select main item.
	Step = AddWizardStep(Items.MainItemSelectionStep);
	Step.BackButton.Visible = False;
	Step.NextButton.DefaultButton = True;
	Step.NextButton.Title = NStr("en = 'Merge >';");
	Step.NextButton.ToolTip = NStr("en = 'Run merging.';");
	Step.CancelButton.Title = NStr("en = 'Cancel';");
	Step.CancelButton.ToolTip = NStr("en = 'Cancel merging.';");
	
	// 3. Waiting for process.
	Step = AddWizardStep(Items.MergeStep);
	Step.CancelButton.Visible = False;
	Step.NextButton.Visible = False;
	Step.BackButton.Title = NStr("en = 'Cancel';");
	Step.BackButton.ToolTip = NStr("en = 'Return to selection of the main item.';");
	
	// 4. Merged successfully.
	Step = AddWizardStep(Items.SuccessfulCompletionStep);
	Step.BackButton.Visible = False;
	Step.NextButton.Visible = False;
	Step.CancelButton.DefaultButton = True;
	Step.CancelButton.Title = NStr("en = 'Close';");
	Step.CancelButton.ToolTip = NStr("en = 'Close merge results.';");
	
	// 5. Reference replacement issues.
	Step = AddWizardStep(Items.RetryMergeStep);
	Step.BackButton.Title = NStr("en = '< To Beginning';");
	Step.BackButton.ToolTip = NStr("en = 'Return to selection of the main item.';");
	Step.NextButton.DefaultButton = True;
	Step.NextButton.Title = NStr("en = 'Merge again';");
	Step.NextButton.ToolTip = NStr("en = 'Merge again';");
	Step.CancelButton.Title = NStr("en = 'Cancel';");
	Step.CancelButton.ToolTip = NStr("en = 'Close merge results.';");
	
	// 6 Runtime errors.
	Step = AddWizardStep(Items.ErrorOccurredStep);
	Step.BackButton.Visible = False;
	Step.NextButton.Visible = False;
	Step.CancelButton.Title = NStr("en = 'Close';");
	
	// Update form items.
	WizardSettings.CurrentStep = SearchStep;
	SetVisibilityAvailability(ThisObject);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	OnActivateWizardStep();
	ReportsToSend = New Map;
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	// References replacement is a critical step that requires confirmation of cancellation.
	If WizardSettings.ShowDialogBeforeClose
		And Items.WizardSteps.CurrentPage = Items.MergeStep Then
		
		Cancel = True;
		If Exit Then
			Return;
		EndIf;
		
		QueryText = NStr("en = 'Do you want to cancel merging and close the form?';");
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Abort, NStr("en = 'Cancel merging';"));
		Buttons.Add(DialogReturnCode.No,      NStr("en = 'Continue merging';"));
		
		Handler = New NotifyDescription("AfterConfirmCancelJob", ThisObject);
		ShowQueryBox(Handler, QueryText, Buttons, , DialogReturnCode.No);
		
	EndIf;
	
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
Procedure MainItemSelectionTooltipURLProcessing(Item, URLValue, StandardProcessing)
	StandardProcessing = False;
	
	If URLValue = "SwitchDeletionMode" Then
		If CurrentDeletionOption = "Directly" Then
			CurrentDeletionOption = "Check" 
		Else
			CurrentDeletionOption = "Directly" 
		EndIf;
		GenerateMergeTooltip();
	EndIf;
	
EndProcedure

&AtClient
Procedure DetailsRefClick(Item)
	StandardSubsystemsClient.ShowDetailedInfo(Undefined, Item.ToolTip);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersUsageInstances

&AtClient
Procedure UsageInstancesSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	Ref = UsageInstances.FindByID(RowSelected).Ref;
	
	If Field <> Items.UsageInstancesUsageInstancesCount Then
		ShowValue(, Ref);
		Return;
	EndIf;
	
	RefSet = New Array;
	RefSet.Add(Ref);
	DuplicateObjectsDetectionClient.ShowUsageInstances(RefSet);
	
EndProcedure

&AtClient
Procedure UsageInstancesBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	If Copy Then
		Return;
	EndIf;
	
	// Always add an item of the same type as the main one.
	ChoiceFormName = SelectionFormNameByReference(MainItem);
	If Not IsBlankString(ChoiceFormName) Then
		FormParameters = New Structure("MultipleChoice", True);
		If ReferencesToReplaceCommonOwner <> Undefined Then
			FormParameters.Insert("Filter", New Structure("Owner", ReferencesToReplaceCommonOwner));
		EndIf;
		OpenForm(ChoiceFormName, FormParameters, Item);
	EndIf;
EndProcedure

&AtClient
Procedure UsageInstancesBeforeDeleteRow(Item, Cancel)
	Cancel = True;
	
	CurrentData = Item.CurrentData;
	If CurrentData=Undefined Or UsageInstances.Count()<3 Then
		Return;
	EndIf;
	
	Ref = CurrentData.Ref;
	Code    = String(CurrentData.Code);
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Delete item %1 from the merge list?';"),
		String(Ref) + ?(IsBlankString(Code), "", " (" + Code + ")" ));
	
	Notification = New NotifyDescription("UsageInstancesBeforeDeleteRowCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("CurrentRow", Item.CurrentRow);
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo);
EndProcedure

&AtClient
Procedure UsageInstancesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	StandardProcessing = False;
	
	If TypeOf(ValueSelected) = Type("Array") Then
		ItemsToAdd = ValueSelected;
	Else
		ItemsToAdd = New Array;
		ItemsToAdd.Add(ValueSelected);
	EndIf;
	
	AddUsageInstancesRows(ItemsToAdd);
	GenerateMergeTooltip();
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
Procedure OpenUsageInstancesItem(Command)
	CurrentData = Items.UsageInstances.CurrentData;
	If CurrentData <> Undefined Then
		ShowValue(, CurrentData.Ref);
	EndIf;
EndProcedure

&AtClient
Procedure UsageInstances(Command)
	
	CurrentData = Items.UsageInstances.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	RefSet = New Array;
	RefSet.Add(CurrentData.Ref);
	DuplicateObjectsDetectionClient.ShowUsageInstances(RefSet);
	
EndProcedure

&AtClient
Procedure AllUsageInstances(Command)
	
	If UsageInstances.Count() > 0 Then 
		DuplicateObjectsDetectionClient.ShowUsageInstances(UsageInstances);
	EndIf;
	
EndProcedure

&AtClient
Procedure MarkAsOriginal(Command)
	CurrentData = Items.UsageInstances.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	MainItem = CurrentData.Ref;
	GenerateMergeTooltip();
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

&AtServer
Procedure InitializeStepByStepWizardSettings()
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
EndProcedure

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
//           ** Visible - Boolean - if True, the button is visible. The default value is True.
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

&AtClientAtServerNoContext
Procedure SetVisibilityAvailability(Form)
	
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
	SetVisibilityAvailability(ThisObject);
	OnActivateWizardStep();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Wizard events

&AtClient
Procedure OnActivateWizardStep()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.SearchForUsageInstancesStep Then
		
		StartDeterminingUseLocations();
		
	ElsIf CurrentPage = Items.MainItemSelectionStep Then
		
		GenerateMergeTooltip();
		
	ElsIf CurrentPage = Items.MergeStep Then
		
		StartReplacingLinks();
		
	ElsIf CurrentPage = Items.SuccessfulCompletionStep Then
		
		Items.MergeResult.Title = CompleteMessage() + " """ + String(MainItem) + """";
		NotifyOfSuccessfulReplacement(PlacesofUseInArray());
		
	ElsIf CurrentPage = Items.RetryMergeStep Then
		
		GenerateUnsuccessfulReplacementLabel();
		NotifyOfSuccessfulReplacement(DeleteProcessedItemsFromUsageInstances());
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepNext()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	Step = WizardSettings.CurrentStep; // See AddWizardStep
	If CurrentPage = Items.MainItemSelectionStep Then
		
		ErrorText = CheckCanReplaceReferences();
		If Not IsBlankString(ErrorText) Then
			StandardSubsystemsClient.ShowQuestionToUser(Undefined, 
				StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot merge items due to:
					|%1';"), ErrorText), QuestionDialogMode.OK);
			Return;
		EndIf;
		
		GoToWizardStep1(Step.IndexOf + 1);
		
	ElsIf CurrentPage = Items.RetryMergeStep Then
		GoToWizardStep1(Items.MergeStep);
	Else
		GoToWizardStep1(Step.IndexOf + 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepBack()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	If CurrentPage = Items.RetryMergeStep Then
		GoToWizardStep1(Items.SearchForUsageInstancesStep);
	Else
		Step = WizardSettings.CurrentStep;// See AddWizardStep
		GoToWizardStep1(Step.IndexOf - 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepCancel()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	If CurrentPage = Items.MergeStep Then
		WizardSettings.ShowDialogBeforeClose = False;
	EndIf;
	
	If IsOpen() Then
		Close();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal procedures for item merging

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesMain.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsageInstances.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = New DataCompositionField("MainItem");

	Item.Appearance.SetParameterValue("Show", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesRef.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesCode.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesUsageInstancesCount.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsageInstances.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = New DataCompositionField("MainItem");

	Item.Appearance.SetParameterValue("Font", StyleFonts.MainListItem);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesNotUsed.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsageInstances.UsageInstancesCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.LessOrEqual;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Visible", True);
	Item.Appearance.SetParameterValue("Show", True);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesNotUsed.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsageInstances.UsageInstancesCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesUsageInstancesCount.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsageInstances.UsageInstancesCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.LessOrEqual;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UnsuccessfulReplacementsCode.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UnsuccessfulReplacements.Code");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visible", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesUsageInstancesCount.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsageInstances.UsageInstancesCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Visible", True);
	Item.Appearance.SetParameterValue("Show", True);

EndProcedure

&AtServer
Procedure InitializeReferencesToMerge(Val ReferencesArrray)
	
	ReferencesToReplaceCommonOwner = CheckReferencesToMerge(ReferencesArrray);
	MainItem = ReferencesArrray[0];
	
	UsageInstances.Clear();
	For Each Item In ReferencesArrray Do
		UsageInstances.Add().Ref = Item;
	EndDo;
EndProcedure

&AtServerNoContext
Function CheckReferencesToMerge(Val RefSet)
	
	RefsCount = RefSet.Count();
	If RefsCount < 2 Then
		Raise NStr("en = 'Select more than one item to merge.';");
	EndIf;
	
	TheFirstControl = RefSet[0];	
	BasicMetadata = TheFirstControl.Metadata();
	VerifyAccessRights("Update", BasicMetadata);
	
	Characteristics = New Structure("Owners, Hierarchical, HierarchyType", New Array, False);
	FillPropertyValues(Characteristics, BasicMetadata);
	
	HasOwners = Characteristics.Owners.Count() > 0;
	HasGroups    = Characteristics.Hierarchical And Characteristics.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems;
	
	QueryText = 
		"SELECT Ref AS Ref,
		|&Owner AS Owner,
		|&IsFolder AS IsFolder
		|INTO RefsToReplace
		|FROM #TableName WHERE Ref IN (&RefSet)
		|INDEX BY Owner, IsFolder
		|;
		|SELECT 
		|	COUNT(DISTINCT Owner) AS OwnersCount,
		|	MIN(Owner)              AS CommonOwner,
		|	MAX(IsFolder)            AS HasGroups,
		|	COUNT(Ref)             AS RefsCount
		|FROM
		|	RefsToReplace";
	QueryText = StrReplace(QueryText, "#TableName", BasicMetadata.FullName());
	QueryText = StrReplace(QueryText, "&Owner", ?(HasOwners, "Owner", "UNDEFINED"));
	QueryText = StrReplace(QueryText, "&IsFolder", ?(HasGroups, "IsFolder", "FALSE"));
	
	Query = New Query(QueryText);
	Query.SetParameter("RefSet", RefSet);
	
	Control = Query.Execute().Unload()[0];
	If Control.HasGroups Then
		Raise NStr("en = 'One of the items to merge is a group.
			|Groups cannot be merged.';");
	ElsIf Control.OwnersCount > 1 Then 
		Raise NStr("en = 'Items to merge have different owners.
			|They cannot be merged.';");
	ElsIf Control.RefsCount <> RefsCount Then
		Raise NStr("en = 'All items to merge must be of the same type.';");
	EndIf;

	Return ?(HasOwners, Control.CommonOwner, Undefined);
	
EndFunction

// Parameters:
//  QuestionResult - DialogReturnCode
//  AdditionalParameters - Structure
//
&AtClient
Procedure UsageInstancesBeforeDeleteRowCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	// Actual deletion from the table.
	String = UsageInstances.FindByID(AdditionalParameters.CurrentRow);
	If String = Undefined Then
		Return;
	EndIf;
	
	DeletedRowIndex = UsageInstances.IndexOf(String);
	CalculateMain     = String.Ref = MainItem;
	
	UsageInstances.Delete(String);
	If CalculateMain Then
		LastRowIndex = UsageInstances.Count() - 1;
		If DeletedRowIndex <= LastRowIndex Then 
			MainStringIndex = DeletedRowIndex;
		Else
			MainStringIndex = LastRowIndex;
		EndIf;
			
		MainItem = UsageInstances[MainStringIndex].Ref;
	EndIf;
	
	GenerateMergeTooltip();
EndProcedure

&AtServer
Procedure GenerateMergeTooltip()

	If HasRightToDeletePermanently Then
		If CurrentDeletionOption = "Check" Then
			ToolTipText = NStr("en = '%1 items will be <a href = ""[Action]"">marked for deletion</a>
				|and replaced with %2.';");
			RowParameters = New Structure("Action", "SwitchDeletionMode");
			ToolTipText = StringFunctionsClientServer.InsertParametersIntoString(ToolTipText, RowParameters);
		Else
			ToolTipText = NStr("en = '%1 items will be <a href = ""[Action]"">permanently deleted</a>
				|and replaced with %2.';");
			RowParameters = New Structure("Action", "SwitchDeletionMode");
			ToolTipText = StringFunctionsClientServer.InsertParametersIntoString(ToolTipText, RowParameters);
		EndIf;
	Else
		ToolTipText = NStr("en = '%1 items will be marked for deletion
			|and replaced with %2.';");
	EndIf;
	
	Items.MainItemSelectionTooltip.Title = StringFunctions.FormattedString(ToolTipText, UsageInstances.Count()-1, MainItem);
	
EndProcedure

&AtClient
Function CompleteMessage()
	Return StringFunctionsClientServer.StringWithNumberForAnyLanguage(
		NStr("en = ';%1 item was merged into:;;;;%1 items were merged into:';"),
		UsageInstances.Count());
EndFunction

&AtClient
Procedure GenerateUnsuccessfulReplacementLabel()
	
	Items.UnsuccessfulReplacementsResult.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot merge the items. Cannot replace some items
			|to ""%1"".';"),
		MainItem);
	
EndProcedure

// Parameters:
//     DataList - Array of AnyRef
//
&AtClient
Procedure NotifyOfSuccessfulReplacement(Val DataList)
	CommonClient.NotifyObjectsChanged(DataList);
EndProcedure

&AtServerNoContext
Function SelectionFormNameByReference(Val Ref)
	Meta = Metadata.FindByType(TypeOf(Ref));
	Return ?(Meta = Undefined, Undefined, Meta.FullName() + ".ChoiceForm");
EndFunction

&AtServer
Procedure AddUsageInstancesRows(Val ReferencesArrray)
	LastItemIndex = Undefined;
	MetadataCache    = New Map;
	
	Filter = New Structure("Ref");
	For Each Ref In ReferencesArrray Do
		Filter.Ref = Ref;
		ExistingRows = UsageInstances.FindRows(Filter);
		If ExistingRows.Count() = 0 Then
			String = UsageInstances.Add();
			String.Ref = Ref;
			String.Code      = ObjectCode(Ref, MetadataCache);
			String.Owner = ObjectOfOwner(Ref, MetadataCache);
			String.UsageInstancesCount = -1;
			String.NotUsed    = NStr("en = 'Locations not searched for';");
		Else
			String = ExistingRows[0];
		EndIf;
		
		LastItemIndex = String.GetID();
	EndDo;
	
	If LastItemIndex <> Undefined Then
		Items.UsageInstances.CurrentRow = LastItemIndex;
	EndIf;
EndProcedure

// Returns:
//   String - Catalog code if specified, 
//   Undefined if there is no code.
//
&AtServerNoContext
Function ObjectCode(Val Ref, MetadataCache)
	Data = MetadataDetails(Ref, MetadataCache);
	Return ?(Data.HasCode, Ref.Code, Undefined);
EndFunction

// Returns:
//   CatalogRef - Catalog owner if specified, 
//   Undefined if there is no owner.
//
&AtServerNoContext
Function ObjectOfOwner(Val Ref, MetadataCache)
	Data = MetadataDetails(Ref, MetadataCache);
	Return ?(Data.HasOwner, Ref.Owner, Undefined);
EndFunction

&AtServerNoContext
Function MetadataDetails(Val Ref, MetadataCache)
	
	ObjectMetadata = Ref.Metadata();
	Data = MetadataCache[ObjectMetadata];
	
	If Data = Undefined Then
		Test = New Structure("CodeLength, Owners", 0, New Array);
		FillPropertyValues(Test, ObjectMetadata);
		
		Data = New Structure;
		Data.Insert("HasCode", Test.CodeLength > 0);
		Data.Insert("HasOwner", Test.Owners.Count() > 0);
		
		MetadataCache[ObjectMetadata] = Data;
	EndIf;
	
	Return Data;
EndFunction

&AtClient
Function DeleteProcessedItemsFromUsageInstances()
	Result = New Array;
	
	Unsuccessful = New Map;
	For Each Item In UnsuccessfulReplacements.GetItems() Do
		Unsuccessful.Insert(Item.Ref, True);
	EndDo;
	
	IndexOf = UsageInstances.Count() - 1;
	While IndexOf >= 0 Do
		Ref = UsageInstances[IndexOf].Ref;
		If Ref <> MainItem And Unsuccessful[Ref] = Undefined Then
			UsageInstances.Delete(IndexOf);
			Result.Add(Ref);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function CheckCanReplaceReferences()
	
	RefSet = New Array;
	ReplacementPairs   = New Map;
	For Each UsageInstance1 In UsageInstances Do
		RefSet.Add(UsageInstance1.Ref);
		ReplacementPairs.Insert(UsageInstance1.Ref, MainItem);
	EndDo;
	
	Try
		CheckReferencesToMerge(RefSet);
	Except
		Return ErrorProcessing.BriefErrorDescription(ErrorInfo());
	EndTry;
	
	ReplacementParameters = New Structure("DeletionMethod", CurrentDeletionOption);
	Return DuplicateObjectsDetection.CheckCanReplaceItemsString(ReplacementPairs, ReplacementParameters);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Long-running operation management

&AtClient
Procedure StartDeterminingUseLocations()
	Job = DefineUsageInstances();
	
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	WaitSettings.OutputIdleWindow = False;
	
	Handler = New NotifyDescription("AfterCompleteDeterminingUseLocations", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(Job, Handler, WaitSettings);
	
EndProcedure

&AtServer
Function DefineUsageInstances()
	
	StartSettings1 = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings1.BackgroundJobDescription = NStr("en = 'Duplicate cleaner: Find occurrences';");
	Return TimeConsumingOperations.ExecuteInBackground("DuplicateObjectsDetection.DefineUsageInstances", 
		UsageInstances.Unload(, "Ref").UnloadColumn(0), StartSettings1);
		
EndFunction

&AtClient
Procedure AfterCompleteDeterminingUseLocations(Job, AdditionalParameters) Export
	
	WizardSettings.ShowDialogBeforeClose = False;
	If Job = Undefined 
		Or Items.WizardSteps.CurrentPage = Items.MainItemSelectionStep Then
		GoToWizardStep1(Items.MainItemSelectionStep);
		Return;
	EndIf;
	
	If Job.Status <> "Completed2" Then
		Brief1 = NStr("en = 'Couldn''t find item occurrences:';") 
			+ Chars.LF + Job.BriefErrorDescription;
		More = Brief1 + Chars.LF + Chars.LF + Job.DetailErrorDescription;
		Items.ErrorTextLabel.Title = Brief1;
		Items.DetailsRef.ToolTip    = More;
		GoToWizardStep1(Items.ErrorOccurredStep);
		Activate();
		Return;
	EndIf;
		
	FillUsageInstances(Job.ResultAddress);
	Step = WizardSettings.CurrentStep; // See AddWizardStep
	GoToWizardStep1(Step.IndexOf + 1);
	Activate();
		
EndProcedure

&AtClient
Procedure StartReplacingLinks()
	
	ReportsToSend = New Map;

	WizardSettings.ShowDialogBeforeClose = True;
	Job = ReplaceReferences();
	
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	WaitSettings.OutputIdleWindow = False;
	
	Handler = New NotifyDescription("AfterCompletionReplacingLinks", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(Job, Handler, WaitSettings);
	
EndProcedure

&AtServer
Function ReplaceReferences()
	
	MethodParameters = New Structure("ReplacementPairs, DeletionMethod");
	MethodParameters.ReplacementPairs = New Map;
	For Each UsageInstance1 In UsageInstances Do
		MethodParameters.ReplacementPairs.Insert(UsageInstance1.Ref, MainItem);
	EndDo;
	MethodParameters.Insert("DeletionMethod", CurrentDeletionOption);

	StartSettings1 = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings1.BackgroundJobDescription = NStr("en = 'Duplicate cleaner: Merge items';");
	
	Return TimeConsumingOperations.ExecuteInBackground("DuplicateObjectsDetection.ReplaceReferences", 
		MethodParameters, StartSettings1);
EndFunction

&AtClient
Procedure AfterCompletionReplacingLinks(Job, AdditionalParameters) Export
	
	WizardSettings.ShowDialogBeforeClose = False;
	If Job = Undefined 
		Or Items.WizardSteps.CurrentPage = Items.MainItemSelectionStep Then
		GoToWizardStep1(Items.MainItemSelectionStep);
		Return;
	EndIf;
	
	If Job.Status <> "Completed2" Then
		Brief1 = NStr("en = 'Failed to replace items:';") + Chars.LF + Job.BriefErrorDescription;
		More = Brief1 + Chars.LF + Chars.LF + Job.DetailErrorDescription;
		Items.ErrorTextLabel.Title = Brief1;
		Items.DetailsRef.ToolTip    = More;
		GoToWizardStep1(Items.ErrorOccurredStep);
		Activate();
		Return;
	EndIf;
	
	HasUnsuccessfulReplacements = FillUnsuccessfulReplacements(Job.ResultAddress);
	If HasUnsuccessfulReplacements Then
		GoToWizardStep1(Items.RetryMergeStep);
		Activate();
	Else
		ShowUserNotification(CompleteMessage(), GetURL(MainItem),
			String(MainItem), PictureLib.DialogInformation);
		NotifyOfSuccessfulReplacement(PlacesofUseInArray());
		Close();
	EndIf
	
EndProcedure

&AtClient
Function PlacesofUseInArray()
	Result = New Array();
	For Each Item In UsageInstances Do
		Result.Add(Item.Ref);
	EndDo;
	Return Result;
EndFunction

&AtServer
Procedure FillUsageInstances(Val ResultAddress)
	UsageTable = GetFromTempStorage(ResultAddress); // See Common.ReplaceReferences
	
	NewUsageInstances = UsageInstances.Unload();
	NewUsageInstances.Indexes.Add("Ref");
	
	IsUpdate = NewUsageInstances.Find(MainItem, "Ref") <> Undefined;
	If Not IsUpdate Then
		NewUsageInstances = UsageInstances.Unload(New Array);
		NewUsageInstances.Indexes.Add("Ref");
	EndIf;
	
	MetadataCache = New Map;
	
	MaxReference = Undefined;
	MaxInstances   = -1;
	DeletionMarks = Common.ObjectsAttributeValue(
		UsageTable.UnloadColumn("Ref"), "DeletionMark");
	For Each TableRow In UsageTable Do
		
		UsageRow = NewUsageInstances.Find(TableRow.Ref, "Ref");
		If UsageRow = Undefined Then
			UsageRow = NewUsageInstances.Add();
			UsageRow.Ref = TableRow.Ref;
		EndIf;
		
		Instances = TableRow.Occurrences;
		If Instances > MaxInstances And Not DeletionMarks[TableRow.Ref] Then
			MaxReference = TableRow.Ref;
			MaxInstances   = Instances;
		EndIf;
		
		UsageRow.UsageInstancesCount = Instances;
		UsageRow.Code      = ObjectCode(TableRow.Ref, MetadataCache);
		UsageRow.Owner = ObjectOfOwner(TableRow.Ref, MetadataCache);
		
		UsageRow.NotUsed = ?(Instances = 0, NStr("en = 'Not applicable';"), "");
	EndDo;
	
	UsageInstances.Load(NewUsageInstances);
	
	If MaxReference <> Undefined Then
		MainItem = MaxReference;
	EndIf;
	
	// Refresh headers.
	Presentation = ?(MainItem = Undefined, "", MainItem.Metadata().Presentation());
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Merge %1 items into one item';"), Presentation);
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
			TreeRow.Code    = String( ObjectCode(Ref, MetadataCache) );
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
	If Response = DialogReturnCode.Abort Then
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