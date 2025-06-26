///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

&AtClient
Var CurrentSelectedAttribute;

&AtClient
Var ErrorsInfo;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	CheckPlatformVersionAndCompatibilityMode();
	SSLVersionMatchesRequirements = SSLVersionMatchesRequirements();
	AdditionalDataProcessorRef = Parameters.AdditionalDataProcessorRef;

	ContextCall = TypeOf(Parameters.ObjectsArray) = Type("Array");
	
	Items.FormBack.Visible = False;
	EditProhibitionIntegrated = Metadata.FindByFullName("CommonModule.ObjectAttributesLockClient") <> Undefined;
	
	If ContextCall Then
		ExecuteActionsOnContextOpen();
	Else
		If Not IsFullUser() Then
			Raise(NStr("en = 'Insufficient rights.';"), ErrorCategory.AccessViolation);
		EndIf;
		Title = NStr("en = 'Bulk attribute edit';");
		FillObjectsTypesList();
	EndIf;
	
	LoadProcessingSettings();
	
	GenerateNoteOnConfiguredChanges();
	UpdateItemsVisibility();
	
	If Not ContextCall Then
		WindowOpeningMode = FormWindowOpeningMode.Independent;
	EndIf;
	
	// Check if data processor object contains the UsedFileName field.
	DataProcessorObject  = FormAttributeToValue("Object");
	ObjectStructure = New Structure("UsedFileName", Undefined);
	FillPropertyValues(ObjectStructure, DataProcessorObject);
	
	// If the "UsedFileName" field is present, this is an external data processor.
	If Not ValueIsFilled(AdditionalDataProcessorRef)
	   And ValueIsFilled(ObjectStructure.UsedFileName)
	   And Not StrStartsWith(ObjectStructure.UsedFileName, "e1cib/")
	   And Not StrStartsWith(ObjectStructure.UsedFileName, "e1cib\") Then
		ExternalProcessorFilePathAtClient = ObjectStructure.UsedFileName;
	EndIf;

	Items.GenerateErrorReport.Visible = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
#If WebClient Then
	If ValueIsFilled(ExternalProcessorFilePathAtClient) Then
		ErrorText = NStr("en = 'To perform this action, start the client app.';");
		Raise ErrorText;
	EndIf;
#EndIf
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	SendErrorReport();
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper(FullFormName("AdditionalParameters")) Then
		
		RefillObjectAttributesStructure = False;
		If TypeOf(ValueSelected) = Type("Structure") Then
			Object.DeveloperMode = ValueSelected.DeveloperMode;
			DisableSelectionParameterConnections = ValueSelected.DisableSelectionParameterConnections;
			If IncludeHierarchy And ProcessRecursively <> ValueSelected.ProcessRecursively Then
				ProcessRecursively = ValueSelected.ProcessRecursively;
				RefillObjectAttributesStructure = True;
				InitializeSettingsComposer();
			EndIf;
			Object.ChangeInTransaction = ValueSelected.ChangeInTransaction;
			Object.InterruptOnError  = ValueSelected.InterruptOnError;
			
			If Object.ShowInternalAttributes <> ValueSelected.ShowInternalAttributes Then
				Object.ShowInternalAttributes = ValueSelected.ShowInternalAttributes;
				RefillObjectAttributesStructure = True;
				FillObjectsTypesList();
			EndIf;
			
			If RefillObjectAttributesStructure And Not IsBlankString(KindsOfObjectsToChange) Then
				SavedSettings = Undefined;
				LoadObjectMetadata(True, SavedSettings);
				If SavedSettings <> Undefined And Object.OperationType <> "ExecuteAlgorithm" Then
					SetChangeSetting(SavedSettings);
				EndIf;
			EndIf;
			
			UpdateItemsVisibility();
			SaveDataProcessorSettings(Object.ChangeInTransaction, Object.InterruptOnError, ProcessRecursively);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure KindOfObjectsToChangeStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	NotifyDescription = New NotifyDescription("KindOfObjectsToChangeWhenSelected", ThisObject);
	FormParameters = New Structure;
	FormParameters.Insert("SelectedTypes", KindsOfObjectsToChange);
	FormParameters.Insert("ShowHiddenItems", Object.ShowInternalAttributes);
	OpenForm(FullFormName("SelectObjectsKind"), FormParameters, , , , , NotifyDescription);
EndProcedure

&AtClient
Procedure PresentationOfObjectsToChangeOnChange(Item)
	SelectedType = Items.PresentationOfObjectsToChange.ChoiceList.FindByValue(PresentationOfObjectsToChange);
	If SelectedType = Undefined Then
		For Each Type In Items.PresentationOfObjectsToChange.ChoiceList Do
			If StrFind(Lower(Type.Presentation), Lower(PresentationOfObjectsToChange)) = 1 Then
				SelectedType = Type;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If SelectedType = Undefined Then
		PresentationOfObjectsToChange = PresentationOfObjectsToChange();
	Else
		PresentationOfObjectsToChange = SelectedType.Presentation;
		KindsOfObjectsToChange = SelectedType.Value;
		SelectedObjectsInContext.Clear();
		RebuildFormInterfaceForSelectedObjectKind();
		If Not ContextCall Then
			SaveKindsOfObjectsToChange(KindsOfObjectsToChange, SelectedItemsListAddress);
		EndIf;	
	EndIf;
	
	Algorithm = PresentationOfObjectsToChange;
	
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	If Object.OperationType = "ExecuteAlgorithm" Then
		Items.OperationKindPages.CurrentPage = Items.ArbitraryAlgorithm;
		Items.FormChange.Title = NStr("en = 'Run';");
		Items.PreviouslyChangedAttributes.Visible = False;
		Items.Algorithms.Visible = True;
		Items.AttributesSearchString.Visible = False;
	Else
		Items.OperationKindPages.CurrentPage = Items.AttributesToChange;
		Items.FormChange.Title = NStr("en = 'Edit attributes';");
		Items.PreviouslyChangedAttributes.Visible = True;
		Items.Algorithms.Visible = False;
		Items.AttributesSearchString.Visible = True;
	EndIf;
EndProcedure

&AtClient
Procedure ObjectCompositionOnCurrentPageChange(Item, CurrentPage)
	Items.AttributesSearchString.Visible = (CurrentPage = Items.Attributes);
EndProcedure

&AtClient
Procedure GenerateErrorReportClick(Item)
	
	If Not SSLVersionMatchesRequirements Then
		Return;
	EndIf;
	
	ModuleStandardClientSubsystems = CommonModule("StandardSubsystemsClient");
	
	CurrentData = Items.ObjectsThatCouldNotBeChanged.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ErrorReport = InfoOnError(CurrentData.Object).ErrorReport;
	If ErrorReport <> Undefined Then
		ModuleStandardClientSubsystems.ShowErrorReport(ErrorReport);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSettingsComposerSettingsFilter

&AtClient
Procedure UpdateLabel()
	UpdateLabelServer();
EndProcedure

&AtServer
Procedure UpdateLabelServer()
	UpdateSelectedCountLabel();
	GenerateNoteOnConfiguredChanges();
	Algorithm = PresentationOfObjectsToChange;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersObjectsThatCouldNotBeChanged

&AtClient
Procedure ObjectsThatCouldNotBeChangedBeforeRowChange(Item, Cancel)
	If TypeOf(Item.CurrentData.Object) <> Type("String")
		And Item.CurrentItem = Items.ObjectsThatCouldNotBeChangedObject Then
		Cancel = True;
		ShowValue(, Item.CurrentData.Object);
	EndIf;
EndProcedure

&AtClient
Procedure ObjectsThatCouldNotBeChangedOnActivateRow(Item)
	If Item.CurrentData = Undefined Then
		Cause = "";
	Else
		Cause = Item.CurrentData.Cause;
	EndIf;
	
	ConfigureVisibilityAndTitleForURLSendErrorReport();

EndProcedure

&AtClient
Procedure ConfigureVisibilityAndTitleForURLSendErrorReport()
	
	If Not SSLVersionMatchesRequirements Then
		Return;
	EndIf;
	
	ModuleStandardClientSubsystems = CommonModule("StandardSubsystemsClient");
	
	Items.GenerateErrorReport.Visible = False;
	
	If Items.Pages.CurrentPage <> Items.ObjectsChange 
		Or Not Items.ObjectsThatCouldNotBeChangedGroup.Visible Then
		Return;
	EndIf;
	
	CurrentData = Items.ObjectsThatCouldNotBeChanged.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ErrorInfo = InfoOnError(CurrentData.Object).ErrorInfo;
	If ErrorInfo <> Undefined Then
		ModuleStandardClientSubsystems.ConfigureVisibilityAndTitleForURLSendErrorReport(
			Items.GenerateErrorReport, ErrorInfo);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersObjectAttributes

&AtClient
Procedure ObjectAttributesDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	If Field <> Undefined And Field.Name = Items.ObjectAttributesValue.Name 
		And ObjectAttributes.FindByID(String).AllowedTypes.ContainsType(Type("String"))
		And Not StrStartsWith(ObjectAttributes.FindByID(String).Value, "'") Then
		StandardProcessing = False;
	EndIf;
EndProcedure

&AtClient
Procedure ObjectAttributesDrag(Item, DragParameters, StandardProcessing, String, Field)
	AttributeDetails = ObjectAttributes.FindByID(DragParameters.Value[0]);
	PasteTemplate = "[%1]";
	
	TextForInsert = SubstituteParametersToString(PasteTemplate, AttributeDetails.Presentation);
	CurrentData = ObjectAttributes.FindByID(String);
	If Not IsBlankString(CurrentData.Value) Then
		TextForInsert = "+" + TextForInsert;
	EndIf;
	CurrentData.Value = String(CurrentData.Value) + TextForInsert;
	If Not StrStartsWith(TrimL(CurrentData.Value), "=") Then
		CurrentData.Value = "=" + CurrentData.Value;
	EndIf;
	CurrentData.Change = True;
EndProcedure

&AtClient
Procedure ObjectAttributesValueStartChoice(Item, ChoiceData, StandardProcessing)
	CurrentData = Items.ObjectAttributes.CurrentData;
	If CurrentData.AllowedTypes.Types().Count() = 1 And CurrentData.AllowedTypes.ContainsType(Type("String")) Then
		StandardProcessing = False;
		AttachIdleHandler("EditFormula", 0.1, True);
	EndIf;
EndProcedure

&AtClient
Function ExpressionsHaveErrors()
	Result = False;
	For IndexOf = 0 To ObjectAttributes.Count() - 1 Do
		AttributeDetails = ObjectAttributes[IndexOf];
		If AttributeDetails.Change And TypeOf(AttributeDetails.Value) = Type("String") 
			And StrStartsWith(AttributeDetails.Value, "=") Then
			ErrorText = "";
			If ExpressionHasErrors(AttributeDetails.Value, ErrorText) Then
				Result = True;
				Message = New UserMessage;
				Message.Field = SubstituteParametersToString("ObjectAttributes[%1].Value", Format(IndexOf, "NG=0"));
				Message.Text = ErrorText;
				Message.Message();
			EndIf;
		EndIf;
	EndDo;
	Return Result;
EndFunction

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Change(Command)
	
	SendErrorReport();
	If Object.OperationType = "ExecuteAlgorithm" Then
		
		CodeExecutionRights = AvailableCodeExecutionRights();
		
		If Not CodeExecutionRights.CodeExecutionAvailable Then
			Return;
		EndIf;
		
		If Not CodeExecutionRights.UnsafeModeCodeExecutionAvailable And Object.ExecutionMode = 1 Then
			Object.ExecutionMode = 0; // Switching to safe mode
		EndIf;
		
	EndIf;
	
	ButtonPurpose = "Change";
	If ProcessingInProgress Then
		ButtonPurpose = "Abort";
	ElsIf ProcessingCompleted Or Items.Pages.CurrentPage = Items.ObjectsChange Then
		ButtonPurpose = "Close";
		If ObjectsThatCouldNotBeChanged.Count() > 0 Then
			ButtonPurpose = "Retry";
		EndIf;
	EndIf;
	
	If ButtonPurpose = "Close" Then
		Close();
		Return;
	EndIf;
	
	If ButtonPurpose = "Abort" Then
		If CurrentChangeStatus = Undefined Or TimeConsumingOperation = Undefined Then
			Return;
		EndIf;
		CurrentChangeStatus.AbortUpdate = True;
		Items.FormChange.Enabled = False;
		If Not TimeConsumingOperation.Status = "Completed2" Then
			CompleteObjectChange();
		EndIf;
		Return;
	EndIf;
	
	If ButtonPurpose = "Change" Then
		If Not SelectedObjectsAvailable() Then
			ShowMessageBox(, NStr("en = 'Items to edit are not provided.';"));
			Return;
		EndIf;
		
		If ExpressionsHaveErrors() Then
			Return;
		EndIf;
	
		If AvailableConfiguredFilters() Then
			ExecuteChangeFilterCheckCompleted();
		Else
			QueryText = NStr("en = 'Filter not set. Do you want to edit all items?';");
			NotifyDescription = New NotifyDescription("ExecuteChangeFilterCheckCompleted", ThisObject);
			ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.OKCancel, , , NStr("en = 'Edit items';"));
		EndIf;
		
		Return;
	EndIf;
	
	If ButtonPurpose = "Retry" Then
		ExecuteChangeChecksCompleted();
	EndIf;
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	SendErrorReport();
	BackServer();
	
EndProcedure

&AtClient
Procedure ConfigureChangeParameters(Command)
	
	FormParameters = New Structure;
	
	FormParameters.Insert("ChangeInTransaction",            Object.ChangeInTransaction);
	FormParameters.Insert("ProcessRecursively",         ProcessRecursively);
	FormParameters.Insert("InterruptOnError",             Object.InterruptOnError);
	FormParameters.Insert("IncludeHierarchy",              IncludeHierarchy);
	FormParameters.Insert("ShowInternalAttributes",   Object.ShowInternalAttributes);
	FormParameters.Insert("ContextCall",               ContextCall);
	FormParameters.Insert("DeveloperMode",              Object.DeveloperMode);
	FormParameters.Insert("DisableSelectionParameterConnections", DisableSelectionParameterConnections);
		
	OpenForm(FullFormName("AdditionalParameters"), FormParameters, ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// ATTACHABLE HANDLERS

&AtClient
Procedure Attachable_ValueOnChange(FormField)
	CurrentData = FormField.Parent.CurrentData;
	CurrentData.Change = ValueIsFilled(CurrentData.Value);
	UpdateCountersOfAttributesToChange(FormField.Parent);
	AttachIdleHandler("UpdateNoteAboutConfiguredChanges", 0.1, True);
EndProcedure

&AtClient
Procedure Attachable_OnCheckChange(FormField)
	UpdateCountersOfAttributesToChange(FormField.Parent);
	AttachIdleHandler("UpdateNoteAboutConfiguredChanges", 0.1, True);
EndProcedure

// Parameters:
//   Command - FormCommand
//
&AtClient
Procedure Attachable_EnableSetting(Command)
	
	If StrStartsWith(Command.Name, "Algorithms") Then
		CommandLocation = Items.Algorithms;
		CommandNamePattern = CommandLocation.Name + "ChangesSetting";
		CommandIndex = Number(Mid(Command.Name, StrLen(CommandNamePattern) + 1));
		AlgorithmCode = AlgorithmsHistoryList[CommandIndex].Value;
		Algorithm = AlgorithmsHistoryList[CommandIndex].Presentation;
		GenerateNoteOnConfiguredChanges();
	Else
		CommandLocation = Items.PreviouslyChangedAttributes;
		CommandNamePattern = CommandLocation.Name + "ChangesSetting";
		CommandIndex = Number(Mid(Command.Name, StrLen(CommandNamePattern) + 1));
		SetChangeSetting(OperationsHistoryList[CommandIndex].Value);
		GenerateNoteOnConfiguredChanges();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_BeforeRowChange(Item, Cancel)
	
	RestrictSelectableTypesAndSetValueChoiceParameters(Item);
	If (Item.CurrentItem = Items.ObjectAttributesValue
		Or Item.CurrentItem = Items.ObjectAttributesChange)
		And Item.CurrentData.LockedAttribute Then
			Cancel = True;
			CurrentSelectedAttribute = Item.CurrentData;
			AttachIdleHandler("AllowEditAttributes", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure UpdateNoteAboutConfiguredChanges()
	GenerateNoteOnConfiguredChanges();
EndProcedure

&AtClient
Procedure ObjectAttributesValueChoiceCompletion(Formula, CurrentData) Export
	If Formula = Undefined Then
		Return;
	EndIf;
	If Not StrStartsWith(Formula, "=") Then
		Formula = "=" + Formula;
	EndIf;
	CurrentData.Value = Formula;
	CurrentData.Change = True;
EndProcedure

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	// Auto-numbering info. This is always the first setting.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ObjectAttributesValue.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.Change");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.IsStandardAttribute");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.Value");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	FilterGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.Name");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = "Code";
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.Name");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = "Number";
	
	Item.Appearance.SetParameterValue("Text", NoteOnAutonumbering);
	Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);
	
	// Locked attribute.
	
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ObjectAttributesPresentation.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.LockedAttribute");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	//@skip-check new-color
	Item.Appearance.SetParameterValue("TextColor", New Color(192, 192, 192)); // ACC:1346 Standalone data processor cannot use styles.
	
	// Notes for linked attributes
	
	For Each Attribute In ObjectAttributes Do
		Item = ConditionalAppearance.Items.Add();
		
		ItemField = Item.Fields.Items.Add();
		ItemField.Field = New DataCompositionField(Items.ObjectAttributesValue.Name);

		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.Name");
		ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
		ItemFilter.RightValue = Attribute.Name;
		
		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.Value");
		ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
		
		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.Change");
		ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
		ItemFilter.RightValue = False;
		
		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.ChoiceParameterLinksPresentation");
		ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
		
		Item.Appearance.SetParameterValue("Text", Attribute.ChoiceParameterLinksPresentation);
		Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);
	EndDo;
	
	For Each TabularSection In ObjectTabularSections Do
		For Each Attribute In ThisObject[TabularSection.Value] Do
			SetConditionalTabularSectionAttributeFormatting(Attribute, TabularSection);
		EndDo;
	EndDo;
	
EndProcedure

// Parameters:
//   Attribute - Structure:
//   * Name - String
//   ChoiceParameterLinksPresentation - String
//   TabularSection - ValueListItem
//
&AtServer
Procedure SetConditionalTabularSectionAttributeFormatting(Attribute, TabularSection)
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(TabularSection.Value + "Value");

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField(TabularSection.Value + ".Name");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Attribute.Name;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField(TabularSection.Value + ".Value");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField(TabularSection.Value + ".Change");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField(TabularSection.Value + ".ChoiceParameterLinksPresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("Text", Attribute.ChoiceParameterLinksPresentation);
	Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);
EndProcedure


&AtClient
Procedure ExecuteChangeFilterCheckCompleted(QuestionResult = Undefined, AdditionalParameters = Undefined) Export
	
	If QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Not AvailableConfiguredChanges() And Object.OperationType = "EnterValues" Then
		QueryText = NStr("en = 'No changes found. Overwrite the items without introducing changes?';");
		NotifyDescription = New NotifyDescription("ExecuteChangeChecksCompleted", ThisObject);
		ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.OKCancel, , , NStr("en = 'Edit items';"));
	Else
		ExecuteChangeChecksCompleted();
	EndIf;
	
EndProcedure

&AtServer
Function AvailableConfiguredFilters()
	For Each FilterElement In SettingsComposer.Settings.Filter.Items Do
		If FilterElement.Use Then
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

&AtClient
Function FullFormName(Name)
	NameParts = StrSplit(FormName, ".");
	NameParts[3] = Name;
	Return StrConcat(NameParts, ".");
EndFunction

&AtServer
Procedure ExecuteActionsOnContextOpen()
	
	TitleTemplate1 = NStr("en = 'Edit selected %1 elements (%2)';");
	
	ObjectsTypes = New ValueList;
	For Each PassedObject In Parameters.ObjectsArray Do
		MetadataObject = PassedObject.Metadata();
		ObjectName = MetadataObject.FullName();
		If ObjectsTypes.FindByValue(ObjectName) = Undefined Then
			ObjectsTypes.Add(ObjectName, MetadataObject.Presentation());
		EndIf;
	EndDo;
	
	TypePresentation = Parameters.ObjectsArray[0].Metadata().Presentation();
	If ObjectsTypes.Count() > 1 Then
		TypePresentation = "";
		TitleTemplate1 = NStr("en = 'Edit selected items (%2)';");
	EndIf;
	
	ObjectCount = Parameters.ObjectsArray.Count();
	Title = SubstituteParametersToString(TitleTemplate1, TypePresentation, ObjectCount);
	
	// Hiding all settings-related actions if there are no write permissions for settings.
	Items.PreviouslyChangedAttributes.Visible = AccessRight("SaveUserData", Metadata);
	
	KindsOfObjectsToChange = StrConcat(ObjectsTypes.UnloadValues(), ",");
	
	// Loading the history of operations for this object type.
	LoadOperationsHistory();
	FillPreviouslyChangedAttributesSubmenu();
	
	// This is a hierarchy object.
	IncludeHierarchy = HierarchicalMetadataObject1(Parameters.ObjectsArray[0]);
	FolderHierarchy = HierarchyFoldersAndItems(Parameters.ObjectsArray[0]);
	
	SelectedObjectsInContext.LoadValues(Parameters.ObjectsArray);
	InitializeSettingsComposer();
	
	LoadObjectMetadata();
	
	PresentationOfObjectsToChange = PresentationOfObjectsToChange();
	UpdateSelectedCountLabel();
	
	Items.PresentationOfObjectsToChange.ReadOnly = True;
	
EndProcedure

&AtClient
Procedure ExecuteChangeChecksCompleted(QuestionResult = Undefined, AdditionalParameters = Undefined) Export
	
	If QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	CurrentChangeStatus = Undefined;
	SettButtonsDuringChange(True);
	GoToChangeObjectsPage();
	ObjectsThatCouldNotBeChanged.Clear();
	ErrorsInfo = Undefined;
	
	AttachIdleHandler("ChangeObjects1", 0.1, True);
	
EndProcedure

&AtServer
Function AvailableConfiguredChanges()
	Return AttributesToChange().Count() > 0 Or TabularSectionsToChange().Count() > 0;
EndFunction

&AtServer
Procedure AddChangeToHistory(ChangeStructure, ChangePresentation)
	
	If Object.OperationType = "ExecuteAlgorithm" Then
		Settings = CommonSettingsStorageLoad("BatchEditObjects", 
			"AlgorithmsHistory/" + KindsOfObjectsToChange);
		
		If Settings = Undefined Then
			Settings = New Array;
		Else
			For IndexOf = 0 To Settings.UBound() Do
				If Settings.Get(IndexOf).Presentation = ChangePresentation Then
					Settings.Delete(IndexOf);
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		Settings.Insert(0, New Structure("Update, Presentation", ChangeStructure, ChangePresentation));
		
		If Settings.Count() > 20 Then
			Settings.Delete(19);
		EndIf;
		
		CommonSettingsStorageSave("BatchEditObjects", "AlgorithmsHistory/" + KindsOfObjectsToChange, Settings);
		
		LoadOperationsHistory();
		FillPreviouslyChangedAttributesSubmenu();

		Return;
	EndIf;
	
	Settings = CommonSettingsStorageLoad("BatchEditObjects", 
		"ChangeHistory/" + KindsOfObjectsToChange);
	
	If Settings = Undefined Then
		Settings = New Array;
	Else
		For IndexOf = 0 To Settings.UBound() Do
			If Settings.Get(IndexOf).Presentation = ChangePresentation Then
				Settings.Delete(IndexOf);
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Settings.Insert(0, New Structure("Update, Presentation", ChangeStructure, ChangePresentation));
	
	If Settings.Count() > 20 Then
		Settings.Delete(19);
	EndIf;
	
	CommonSettingsStorageSave("BatchEditObjects", "ChangeHistory/" + KindsOfObjectsToChange, Settings);
	
	LoadOperationsHistory();
	FillPreviouslyChangedAttributesSubmenu();
EndProcedure

&AtServer
Procedure LoadOperationsHistory()
	
	OperationsHistoryList.Clear();
	
	ChangeHistory = CommonSettingsStorageLoad("BatchEditObjects", "ChangeHistory/" + KindsOfObjectsToChange);
	If ChangeHistory <> Undefined And TypeOf(ChangeHistory) = Type("Array") Then
		For Each Setting In ChangeHistory Do
			OperationsHistoryList.Add(Setting.Update, Setting.Presentation);
		EndDo;
	EndIf;
	
	AlgorithmsHistoryList.Clear();
	
	ChangeHistory = CommonSettingsStorageLoad("BatchEditObjects", "AlgorithmsHistory/" + KindsOfObjectsToChange);
	If ChangeHistory = Undefined Then
		Return;
	EndIf;
	
	For Each Setting In ChangeHistory Do
		AlgorithmsHistoryList.Add(Setting.Update, Setting.Presentation);
	EndDo;
	
EndProcedure

&AtClient
Procedure AskForAttributeUnlockConfirmation(SelectedAttribute)
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Allow editing';"));
	QueryText = SubstituteParametersToString(
		NStr("en = 'To prevent data inconsistency, attribute %1 has been locked.
			|
			|Before you allow editing, view the occurrences of the selected items
			|and consider possible data implications.
			|
			|Allow editing of %1?
			|';"),
		SelectedAttribute.Presentation);
	
	Buttons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
	
	NotifyDescription = New NotifyDescription("AskForAttributeUnlockConfirmationCompletion", ThisObject, SelectedAttribute);
	ShowQueryBox(NotifyDescription, QueryText, Buttons, , DialogReturnCode.Yes, NStr("en = 'Attribute is locked';"));
	
EndProcedure

&AtClient
Procedure AskForAttributeUnlockConfirmationCompletion(Response, AttributeDetails) Export
	
	If Response = DialogReturnCode.Yes Then
		AttributeDetails.LockedAttribute = False;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SetChoiceParametersServer(ChoiceParameters, ChoiceParametersArray1)
	
	For IndexOf = 1 To StrLineCount(ChoiceParameters) Do
		ChoiceParametersString      = StrGetLine(ChoiceParameters, IndexOf);
		ChoiceParametersStringsArray = StrSplit(ChoiceParametersString, ";");
		FilterFieldName = TrimAll(ChoiceParametersStringsArray[0]);
		TypeName       = TrimAll(ChoiceParametersStringsArray[1]);
		XMLString     = TrimAll(ChoiceParametersStringsArray[2]);
		
		If Type(TypeName) = Type("FixedArray") Then
			Array = New Array;
			XMLStringArray = StrSplit(XMLString, "#");
			For Each Item In XMLStringArray Do
				Item_Array = StrSplit(Item, "*");
				ElementValue = XMLValue(Type(Item_Array[0]), Item_Array[1]);
				Array.Add(ElementValue);
			EndDo;
			Value = New FixedArray(Array);
		Else
			Value = XMLValue(Type(TypeName), XMLString);
		EndIf;
		
		ChoiceParametersArray1.Add(New ChoiceParameter(FilterFieldName, Value));
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure SaveDataProcessorSettings(ChangeInTransaction, InterruptOnError, ProcessRecursively)
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	SettingsStructure_ = SettingsStructure_();
	SettingsStructure_.ChangeInTransaction    = ChangeInTransaction;
	SettingsStructure_.InterruptOnError     = InterruptOnError;
	SettingsStructure_.ProcessRecursively = ProcessRecursively;
	CommonSettingsStorageSave("DataProcessor.BatchEditObjects", "", SettingsStructure_);
	
EndProcedure

&AtServerNoContext
Procedure SaveKindsOfObjectsToChange(KindsOfObjectsToChange, SelectedItemsListAddress)
	
	ClearUpTempStorageOfListOfSelected(SelectedItemsListAddress);
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	CommonSettingsStorageSave("BatchEditObjects", "KindsOfObjectsToChange", KindsOfObjectsToChange);
	
EndProcedure

&AtServerNoContext
Function SettingsStructure_()
	
	SettingsStructure_ = New Structure;
	SettingsStructure_.Insert("ChangeInTransaction",    False);
	SettingsStructure_.Insert("InterruptOnError",     False);
	SettingsStructure_.Insert("ProcessRecursively", False);
	
	Return SettingsStructure_;
	
EndFunction

&AtServer
Procedure LoadProcessingSettings()
	
	Object.OperationType                  = "EnterValues";
	Object.ObjectWriteOption         = "Write";
	
	If Not ContextCall Then
		KindsOfObjectsToChange = LoadTheConfigurationOfTheTypesOfObjectsToChange();
		If Not IsBlankString(KindsOfObjectsToChange) Then
			PresentationOfObjectsToChange = PresentationOfObjectsToChange();
			SelectedObjectsInContext.Clear();
			RebuildFormInterfaceForSelectedObjectKind();
			Algorithm = PresentationOfObjectsToChange;
		EndIf;
	EndIf;
	
	SettingsStructure_ = CommonSettingsStorageLoad("DataProcessor.BatchEditObjects", KindsOfObjectsToChange, SettingsStructure_());
	Object.ChangeInTransaction = SettingsStructure_.ChangeInTransaction;
	Object.InterruptOnError  = SettingsStructure_.InterruptOnError;
	ProcessRecursively     = SettingsStructure_.ProcessRecursively;
	If AccessRight("DataAdministration", Metadata) And SettingsStructure_.Property("ShowInternalAttributes") Then
		Object.ShowInternalAttributes = SettingsStructure_.ShowInternalAttributes;
	Else
		Object.ShowInternalAttributes = False;
	EndIf;
	
	CodeExecutionAvailable                    = CodeExecutionAvailable() And Not ContextCall;
	Items.ArbitraryAlgorithm.Visible   = CodeExecutionAvailable;
	Items.GroupOperationType.Visible      = CodeExecutionAvailable;

	UnsafeModeCodeExecutionAvailable = UnsafeModeCodeExecutionAvailable();
	Items.ExecutionMode.Visible        = UnsafeModeCodeExecutionAvailable;
	
EndProcedure

&AtServer
Function LoadTheConfigurationOfTheTypesOfObjectsToChange()
	
	KindsOfObjectsToChange = CommonSettingsStorageLoad("BatchEditObjects", "KindsOfObjectsToChange", "");
	
	ListOfSpecies = New Array;
	For Each MetadataObjectName In StrSplit(KindsOfObjectsToChange, ",", False) Do
		MetadataObject = Metadata.FindByFullName(MetadataObjectName);
		If MetadataObject <> Undefined Then
			FullName = MetadataObject.FullName();
			If Items.PresentationOfObjectsToChange.ChoiceList.FindByValue(FullName) <> Undefined Then
				ListOfSpecies.Add(FullName);
			EndIf;
		EndIf;
	EndDo;
	
	KindsOfObjectsToChange = StrConcat(ListOfSpecies, ",");
	
	Return KindsOfObjectsToChange;
	
EndFunction

// Custom algorithms are not allowed in SaaS mode, base configurations, or without SystemAdministrator rights.
//
&AtServerNoContext
Function UnsafeModeCodeExecutionAvailable()
	If IsBaseConfigurationVersion()
		Or DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	If Not AccessRight("Administration", Metadata) Then
		Return False;
	EndIf;
	
	Return True;
EndFunction

&AtServerNoContext
Function CodeExecutionAvailable()
	
	If DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	Return True;
EndFunction

&AtServerNoContext
Function AvailableCodeExecutionRights()
	
	Result = New Structure();
	Result.Insert("UnsafeModeCodeExecutionAvailable", UnsafeModeCodeExecutionAvailable());
	Result.Insert("CodeExecutionAvailable", CodeExecutionAvailable());
	
	Return Result;
EndFunction

&AtClient
Procedure AllowEditAttributes()
	
	SelectedAttribute = CurrentSelectedAttribute;
	
	If Not SubsystemExists("StandardSubsystems.ObjectAttributesLock")
	 Or CommonModule("ObjectAttributesLockClient") = Undefined Then
		
		AskForAttributeUnlockConfirmation(SelectedAttribute);
		Return;
	EndIf;
	
	LockedAttributes = New Array;
	LockedAttributesRows = ObjectAttributes.FindRows(
		New Structure("LockedAttribute", True));
	
	For Each OperationDescriptionString In LockedAttributesRows Do
		LockedAttributes.Add(OperationDescriptionString.Name);
	EndDo;
	
	ModuleObjectAttributesLockClient = CommonModule("ObjectAttributesLockClient");
	
	ProcedureParameters = ModuleObjectAttributesLockClient.NewParametersAllowEditingObjectAttributes();
	ProcedureParameters.ResultProcessing = New NotifyDescription("OnUnlockAttributes", ThisObject);
	ProcedureParameters.FullObjectName = StrSplit(KindsOfObjectsToChange, ",", False)[0];
	ProcedureParameters.LockedAttributes = LockedAttributes;
	ProcedureParameters.MarkedAttribute = SelectedAttribute.Name;
	ProcedureParameters.AddressOfRefsToObjects = AddressOfChangeableObjectsArray();
	
	ModuleObjectAttributesLockClient.AllowObjectsAttributesEdit(ProcedureParameters);
	
EndProcedure

&AtClient
Procedure GoToChangeObjectsPage()
	
	If Items.Pages.CurrentPage = Items.ChangesSetting Then
		Items.Pages.CurrentPage = Items.ObjectsChange;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettButtonsDuringChange(StartChange)
	
	ProcessingInProgress = StartChange;

	Items.FormChange.Enabled = True;
	
	If StartChange Then
		Items.FormChange.Title = NStr("en = 'Abort';");
	Else
		If ObjectsThatCouldNotBeChanged.Count() > 0 Then
			Items.FormChange.Title = NStr("en = 'Edit same attributes';");
		Else
			Items.FormChange.Title = NStr("en = 'Close';");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeObjects1()
	
	ClearMessages();
	CurrentChangeStatus = New Structure;
	ObjectsCountForProcessing = SelectedObjectsCount(True, True);
	
	ShowUserNotification(NStr("en = 'Edit selected items';"),, 
		NStr("en = 'Please wait. Processing may take some time…';"));
	ShowProcessedItemsPercentage = False;
	
	CurrentChangeStatus.Insert("ItemsAvailableForProcessing", True);
	
	// Position of the last processed item, where 1 is the first item.
	CurrentChangeStatus.Insert("CurrentPosition", 0);
	
	// Batching in multithreaded runtime is performed in the object module.
	CurrentChangeStatus.Insert("PortionSize", ObjectsCountForProcessing);
	
	CurrentChangeStatus.Insert("ErrorsCount", 0);            // Initialize the error counter.
	CurrentChangeStatus.Insert("ChangedCount", 0);        // Initialize the changed item counter.
	CurrentChangeStatus.Insert("ObjectsCountForProcessing",  ObjectsCountForProcessing);
	CurrentChangeStatus.Insert("StopChangeOnError", Object.InterruptOnError);
	CurrentChangeStatus.Insert("ShowProcessedItemsPercentage",   ShowProcessedItemsPercentage);
	CurrentChangeStatus.Insert("AbortUpdate", False);
	
	AttachIdleHandler("ChangeObjectsBatch", 0.1, True);
	
	Items.Pages.CurrentPage = Items.WaitingForProcessing;
	
EndProcedure

&AtClient
Async Procedure ChangeObjectsBatch()
	
	If ValueIsFilled(ExternalProcessorFilePathAtClient)
	   And Not ValueIsFilled(Object.ExternalDataProcessorBinaryDataAddress) Then
		
		Result = Await PutFileToServerAsync(,,,
			ExternalProcessorFilePathAtClient, UUID);
		
		If TypeOf(Result) = Type("StoredFileDescription")
		   And Not Result.PutFileCanceled Then
			Object.ExternalDataProcessorBinaryDataAddress = Result.Address;
		EndIf;
		
	EndIf;
	
	ChangeAtServer(CurrentChangeStatus.StopChangeOnError);
	
	If TimeConsumingOperation.Status = "Completed2" Then
		ChangeResult = GetFromTempStorage(TimeConsumingOperation.ResultAddress);
		If TypeOf(ChangeResult) = Type("Structure") Then
			ProcessChangeResult(ChangeResult);
		Else
			OnCompleteChange(TimeConsumingOperation, Undefined);
		EndIf;
	Else
		ModuleTimeConsumingOperationsClient = CommonModule("TimeConsumingOperationsClient");
		IdleParameters = ModuleTimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow = False;
		
		NotifyDescription = New NotifyDescription("OnCompleteChange", ThisObject);
		ModuleTimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, NotifyDescription, IdleParameters);
	EndIf;
	
EndProcedure

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure OnCompleteChange(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		BackServer();
		Return;
	EndIf;
	
	If Result.Status <> "Completed2" Then
		BackServer();
		OutputErrorInfo(Result.ErrorInfo);
		Return;
	EndIf;
	
	ResultsOfChanges = GetFromTempStorage(Result.ResultAddress);
	
	If TypeOf(ResultsOfChanges) <> Type("Map") Then
		ErrorText = NStr("en = 'The background job did not return a result';");
		Raise ErrorText;
	EndIf;
	
	StatusError = "Error";
	
	For Each ChangeResult In ResultsOfChanges Do
		
		ResultOfBatchExecution = ChangeResult.Value;
		If ResultOfBatchExecution.Status = StatusError Then
			OutputErrorInfo(ResultOfBatchExecution.ErrorInfo);
		Else
			ResultOfBatchChange = GetFromTempStorage(ResultOfBatchExecution.ResultAddress);
			If TypeOf(ResultOfBatchChange) <> Type("Structure") Then
				ErrorText = NStr("en = 'The thread background job did not return a result';");
				Raise ErrorText;
			EndIf;
		
			ProcessChangeResult(ResultOfBatchChange);
		EndIf;
		
	EndDo;
	
EndProcedure 

&AtClient
Procedure ProcessChangeResult(ChangeResult = Undefined, ContinueProcessing = Undefined)
	Var ErrorsCount, ChangedCount;
	
	If ContinueProcessing = Undefined Then
		ContinueProcessing = True;
	EndIf;
	
	While ContinueProcessing Do
		FillProcessedObjectsStatus(ChangeResult, ErrorsCount, ChangedCount);
		
		CurrentChangeStatus.ErrorsCount = ErrorsCount + CurrentChangeStatus.ErrorsCount;
		CurrentChangeStatus.ChangedCount = ChangedCount + CurrentChangeStatus.ChangedCount;
		
		If Not (CurrentChangeStatus.StopChangeOnError And ChangeResult.HasErrors) Then
			Break;
		EndIf;
		
		// Rolling back the entire transaction if there were errors.
		If Object.ChangeInTransaction Then
			AttachIdleHandler("CompleteObjectChange", 0.1, True);
			Return; // Exit the loop and procedure.
		EndIf;
		
		QueryText = NStr("en = 'Errors editing items.
			|Do you want to cancel editing and see the Error log?';");
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Abort, NStr("en = 'Cancel';"));
		Buttons.Add(DialogReturnCode.Ignore, NStr("en = 'Continue';"));
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Do not ask again';"));
		
		NotifyDescription = New NotifyDescription("ProcessChangeResultResponseReceived", 
			ThisObject, ChangeResult);
		ShowQueryBox(NotifyDescription, QueryText, Buttons, , DialogReturnCode.Abort, 
			NStr("en = 'Editing errors';"));
		Return;
	EndDo;
	
	CurrentChangeStatus.CurrentPosition = CurrentChangeStatus.CurrentPosition + ChangeResult.ProcessingState.Count();
	
	If CurrentChangeStatus.ShowProcessedItemsPercentage Then
		// Calculating the current percentage of processed objects.
		CurrentPercentage = Round(CurrentChangeStatus.CurrentPosition / CurrentChangeStatus.ObjectsCountForProcessing * 100);
		Status(NStr("en = 'Processing in progress…';"), CurrentPercentage, NStr("en = 'Edit selected items';"));
	EndIf;
	
	ItemsAvailableForProcessing = ?(CurrentChangeStatus.CurrentPosition < CurrentChangeStatus.ObjectsCountForProcessing, True, False);
	
	If ItemsAvailableForProcessing And Not CurrentChangeStatus.AbortUpdate Then
		AttachIdleHandler("ChangeObjectsBatch", 0.1, True);
	Else
		AttachIdleHandler("CompleteObjectChange", 0.1, True);
	EndIf;

EndProcedure

&AtClient
Procedure ProcessChangeResultResponseReceived(QuestionResult, ChangeResult) Export
	
	If QuestionResult = Undefined Or QuestionResult = DialogReturnCode.Abort Then
		AttachIdleHandler("CompleteObjectChange", 0.1, True);
		Return;
	ElsIf QuestionResult = DialogReturnCode.No Then
		CurrentChangeStatus.StopChangeOnError = False;
	EndIf;
	
	ProcessChangeResult(ChangeResult, False);
	
EndProcedure

&AtClient
Procedure CompleteObjectChange()
	
	SettButtonsDuringChange(False);
	FinalActionsOnChangeServer();
	
	For Each Type In TypesOfObjectsToChange() Do
		NotifyChanged(Type);
	EndDo;
	
	Notify("BulkObjectChangeCompletion");
	
	ProcessingCompleted = CurrentChangeStatus.ChangedCount = CurrentChangeStatus.ObjectsCountForProcessing;
	If ProcessingCompleted Then
		ShowUserNotification(NStr("en = 'Edit attributes';"), , 
			SubstituteParametersToString(NStr("en = '%1 items have been edited.';"), CurrentChangeStatus.ChangedCount));
		GoToCompletedPage();
		Return;
	EndIf;
	
	Items.ObjectsThatCouldNotBeChangedGroup.Visible = ObjectsThatCouldNotBeChanged.Count() > 0;
	
	If ProcessingCompleted Then
		MessageTemplate = NStr("en = 'All %2 selected items have been edited.';");
	Else
		If Object.ChangeInTransaction Or CurrentChangeStatus.ChangedCount = 0 Then
			MessageTemplate = NStr("en = 'No items have been edited.';");
		Else
			MessageTemplate = NStr("en = 'Items edited partially.
										|Edited: %1. Could not edit: %3.';");
		EndIf;
	EndIf;
	
	If Object.ChangeInTransaction And Not ProcessingCompleted Then
		SkippedItemsCount = CurrentChangeStatus.ObjectsCountForProcessing - CurrentChangeStatus.ErrorsCount;
		If SkippedItemsCount > 0 And Not CurrentChangeStatus.AbortUpdate Then
			TableRow = ObjectsThatCouldNotBeChanged.Add();
			TableRow.Object = SubstituteParametersToString(NStr("en = '… and other items (%1)';"), SkippedItemsCount);
			TableRow.Cause = NStr("en = 'Cannot modify some items. The items were skipped.';");
		EndIf;
	EndIf;
	
	Items.ProcessingResultsLabel.Title = SubstituteParametersToString(
		MessageTemplate,
		CurrentChangeStatus.ChangedCount,
		CurrentChangeStatus.ObjectsCountForProcessing,
		CurrentChangeStatus.ErrorsCount);
		
	Items.FormBack.Visible = True;
	
EndProcedure

&AtServer
Procedure BackServer()
	
	Items.Pages.CurrentPage = Items.ChangesSetting;
	
	ProcessingCompleted = False;
	ObjectsThatCouldNotBeChanged.Clear();
	Items.FormBack.Visible = False;
	If Object.OperationType = "ExecuteAlgorithm" Then
		Items.FormChange.Title = NStr("en = 'Run';");
		Items.FormChange.ExtendedTooltip.Title = NStr("en = 'Run algorithm';");
	Else
		Items.FormChange.Title = NStr("en = 'Edit attributes';");
	EndIf;
	
	UpdateLabelServer();
	
EndProcedure

&AtServer
Procedure GoToCompletedPage()
	
	Items.Pages.CurrentPage = Items.AllDone;
	Items.DoneLabel.Title = SubstituteParametersToString(
		NStr("en = 'Attributes of selected items edited.
			|Total items edited: %1.';"), CurrentChangeStatus.ChangedCount);
	Items.FormChange.Title = NStr("en = 'Finish';");
	Items.FormBack.Visible = True;
	
	AddMessagePossibleToEditAttributesFaster();
	
EndProcedure

// A message stating that attribute edit can be accelerated is shown if:
// 1. The run mode is client/server (not SaaS).
// 2. The transaction runtime flag is set.
// 3. The number of batches in Administration settings is more than 1.
//
&AtServer
Procedure AddMessagePossibleToEditAttributesFaster()
	
	If Not Object.ChangeInTransaction Then
		Return;
	EndIf;
	
	DataProcessorObject = FormAttributeToValue("Object");
	If Not DataProcessorObject.IsLongRunningOperationsAvailable() Then
		Return;
	EndIf;
	
	ModuleTimeConsumingOperations = CommonModule("TimeConsumingOperations");
	
	LongRunningOperationsThreadCount = ModuleTimeConsumingOperations.AllowedNumberofThreads();
	If LongRunningOperationsThreadCount <= 1 Then
		Return;
	EndIf;
	
	Items.DoneLabel.Title = Items.DoneLabel.Title
		+ Chars.LF + Chars.LF
		+ NStr("en = 'You can edit attributes faster.
		|To do it, clear the ""Edit in transaction"" check box in the additional parameters.';");
	
EndProcedure

&AtServer
Function TypesOfObjectsToChange()
	Result = New Array;
	For Each ObjectsKind In StrSplit(KindsOfObjectsToChange, ",", False) Do
		ObjectManager = ObjectManagerByFullName(ObjectsKind);
		Result.Add(TypeOf(ObjectManager.EmptyRef()));
	EndDo;
	Return Result;
EndFunction

&AtServer
Procedure FinalActionsOnChangeServer()
	If TimeConsumingOperation.Property("JobID") Then
		ModuleTimeConsumingOperations = CommonModule("TimeConsumingOperations");
		ModuleTimeConsumingOperations.CancelJobExecution(TimeConsumingOperation.JobID);
	EndIf;
	
	Items.Pages.CurrentPage = Items.ObjectsChange;
	SaveCurrentChangeSettings();
EndProcedure

&AtServer
Procedure SaveCurrentChangeSettings()
	
	CurrentSettings = CurrentChangeSettings();
	If CurrentSettings <> Undefined Then
		AddChangeToHistory(CurrentSettings.ChangeDescription, CurrentSettings.ChangePresentation);
	EndIf;
	
EndProcedure

&AtServer
Function CurrentChangeSettings()
	
	If Object.OperationType = "ExecuteAlgorithm" Then
		Result = New Structure;
		Result.Insert("ChangeDescription", AlgorithmCode);
		Result.Insert("ChangePresentation", Algorithm);
		Return Result;
	EndIf;
	
	ChangeDescription = New Structure;
	OperationsCollection = ObjectAttributes.FindRows(New Structure("Change", True));
	
	TemplateOfPresentation = "[Field] = <Value>";
	ChangePresentation = "";
	
	AttributesChangeSetting = New Array;
	For Each OperationDescription In OperationsCollection Do
		ChangeStructure = New Structure;
		ChangeStructure.Insert("OperationKind", OperationDescription.OperationKind);
		ChangeStructure.Insert("AttributeName", OperationDescription.Name);
		ChangeStructure.Insert("Property", OperationDescription.Property);
		ChangeStructure.Insert("Value", OperationDescription.Value);
		AttributesChangeSetting.Add(ChangeStructure);
		
		ValueAsString = TrimAll(String(OperationDescription.Value));
		If IsBlankString(ValueAsString) Then
			ValueAsString = """""";
		EndIf;
		Update = StrReplace(TemplateOfPresentation, "[Field]", TrimAll(String(OperationDescription.Presentation)));
		Update = StrReplace(Update, "<Value>", ValueAsString);
		
		If Not IsBlankString(ChangePresentation) Then
			ChangePresentation = ChangePresentation + "; ";
		EndIf;
		ChangePresentation = ChangePresentation + Update;
	EndDo;
	ChangeDescription.Insert("Attributes", AttributesChangeSetting);
	
	TabularSectionChangeSetting = New Structure;
	For Each TabularSection In TabularSectionsToChange() Do
		If Not IsBlankString(ChangePresentation) Then
			ChangePresentation = ChangePresentation + "; ";
		EndIf;
		ChangePresentation = ChangePresentation + TabularSection.Key + " (";
		AttributesChangeSetting = New Array;
		AttributesRow = "";
		For Each Attribute In TabularSection.Value Do
			ChangeStructure = New Structure("Name,Value");
			FillPropertyValues(ChangeStructure, Attribute);
			AttributesChangeSetting.Add(ChangeStructure);
			
			Update = StrReplace(TemplateOfPresentation, "[Field]", TrimAll(String(Attribute.Presentation)));
			Update = StrReplace(Update, "<Value>", TrimAll(String(Attribute.Value)));
			
			If Not IsBlankString(AttributesRow) Then
				AttributesRow = AttributesRow + "; ";
			EndIf;
			AttributesRow = AttributesRow + Update;
		EndDo;
		ChangePresentation = ChangePresentation + AttributesRow + ")";
		TabularSectionChangeSetting.Insert(TabularSection.Key, AttributesChangeSetting);
	EndDo;
	
	ChangeDescription.Insert("TabularSections", TabularSectionChangeSetting);
	
	Result = Undefined;
	If ValueIsFilled(ChangePresentation) Then
		Result = New Structure;
		Result.Insert("ChangeDescription", ChangeDescription);
		Result.Insert("ChangePresentation", ChangePresentation);
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure FillProcessedObjectsStatus(ChangeResult, ErrorsCount, ChangedCount)
	
	ErrorsCount = 0;
	ChangedCount = 0;
	
	For Each ProcessedObjectStatus In ChangeResult.ProcessingState Do
		If Not IsBlankString(ProcessedObjectStatus.Value.ErrorCode) Then
			ErrorsCount = ErrorsCount + 1;
			
			ErrorInfo = ProcessedObjectStatus.Value.ErrorMessage;
			
			ErrorReport = New ErrorReport(ErrorInfo);
			
			InfoOnError = InfoOnError();
			InfoOnError.ErrorReport = ErrorReport;
			InfoOnError.ErrorInfo = ErrorInfo;
			
			ErrorsInfo().Insert(ProcessedObjectStatus.Key, InfoOnError);
			
			ErrorRecord = ObjectsThatCouldNotBeChanged.Add();
			ErrorRecord.Object = ProcessedObjectStatus.Key;
			ErrorRecord.Cause = ErrorProcessing.ErrorMessageForUser(ErrorInfo);
		Else
			ChangedCount = ChangedCount + 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function NextBatchOfObjectsForChange()
	
	SelectionStart = CurrentChangeStatus.CurrentPosition;
	SelectionEnd = CurrentChangeStatus.CurrentPosition + CurrentChangeStatus.PortionSize - 1;
	
	SelectedObjects = SelectedObjects();
	If SelectionEnd > SelectedObjects.Rows.Count() - 1 Then
		SelectionEnd = SelectedObjects.Rows.Count() - 1;
	EndIf;
	
	Result = New ValueTree;
	For Each Column In SelectedObjects.Columns Do
		Result.Columns.Add(Column.Name, Column.ValueType);
	EndDo;
	
	For IndexOf = SelectionStart To SelectionEnd Do
		ObjectDetails = Result.Rows.Add();
		FillPropertyValues(ObjectDetails, SelectedObjects.Rows[IndexOf]);
		For Each ObjectString In SelectedObjects.Rows[IndexOf].Rows Do
			FillPropertyValues(ObjectDetails.Rows.Add(), ObjectString);
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function AttributesToChange(TabularSectionName = "ObjectAttributes")
	AttributesTable = ThisObject[TabularSectionName];
	Return ValueTableToArray(AttributesTable.Unload(New Structure("Change", True)));
EndFunction

&AtServer
Function TabularSectionsToChange()
	Result = New Structure;
	For Each TabularSection In ObjectTabularSections Do
		AttributesToChange = AttributesToChange(TabularSection.Value);
		If AttributesToChange.Count() > 0 Then
			TabularSectionName = Mid(TabularSection.Value, StrLen("TabularSection") + 1);
			Result.Insert(TabularSectionName, AttributesToChange);
		EndIf;
	EndDo;
	Return Result;
EndFunction

&AtServer
Procedure ChangeAtServer(Val StopChangeOnError)
	
	ObjectsForProcessing = NextBatchOfObjectsForChange();
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	JobParameters = New Structure;
	JobParameters.Insert("ObjectsToProcess", New ValueStorage(ObjectsForProcessing));
	JobParameters.Insert("StopChangeOnError", StopChangeOnError);
	JobParameters.Insert("ChangeInTransaction", DataProcessorObject.ChangeInTransaction);
	JobParameters.Insert("InterruptOnError", DataProcessorObject.InterruptOnError);
	JobParameters.Insert("OperationType", DataProcessorObject.OperationType);
	JobParameters.Insert("AlgorithmCode", AlgorithmCode);
	JobParameters.Insert("ExecutionMode", DataProcessorObject.ExecutionMode);
	JobParameters.Insert("ObjectWriteOption", DataProcessorObject.ObjectWriteOption);
	JobParameters.Insert("AdditionalAttributesUsed", DataProcessorObject.AdditionalAttributesUsed);
	JobParameters.Insert("AdditionalInfoUsed", DataProcessorObject.AdditionalInfoUsed);
	JobParameters.Insert("AttributesToChange", AttributesToChange());
	JobParameters.Insert("AvailableAttributes", ValueTableToArray(ObjectAttributes.Unload(, "Name,Presentation,OperationKind,Property")));
	JobParameters.Insert("TabularSectionsToChange", TabularSectionsToChange());
	JobParameters.Insert("ObjectsForChanging", New ValueStorage(SelectedObjects()));
	JobParameters.Insert("DeveloperMode", DataProcessorObject.DeveloperMode);
	JobParameters.Insert("ExternalReportDataProcessor", Undefined);
	
	StorageAddress = PutToTempStorage(Undefined, UUID);
	TimeConsumingOperation = DataProcessorObject.ChangeObjects1(JobParameters, StorageAddress);
	
	If TimeConsumingOperation = Undefined Then
		TimeConsumingOperation = New Structure("Status, ResultAddress");
		TimeConsumingOperation.Status          = "Completed2";
		TimeConsumingOperation.ResultAddress = StorageAddress;
	EndIf;
	
EndProcedure

&AtServer
Function AddressOfChangeableObjectsArray()
	
	SelectedObjects = SelectedObjects();
	References = SelectedObjects.Rows.UnloadColumn("Ref");
	Return PutToTempStorage(References, UUID);
	
EndFunction

&AtServerNoContext
Function HierarchicalMetadataObject1(FirstObjectReference)
	
	ObjectKindByRef = ObjectKindByRef(FirstObjectReference);
	Return ((ObjectKindByRef = "Catalog" Or ObjectKindByRef = "ChartOfCharacteristicTypes") And FirstObjectReference.Metadata().Hierarchical)
	 	Or (ObjectKindByRef = "ChartOfAccounts");
	
EndFunction

&AtServerNoContext
Function HierarchyFoldersAndItems(FirstObjectReference)
	
	ObjectKindByRef = ObjectKindByRef(FirstObjectReference);
	Return (ObjectKindByRef = "Catalog" And FirstObjectReference.Metadata().Hierarchical
		And FirstObjectReference.Metadata().HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems)
		Or (ObjectKindByRef = "ChartOfCharacteristicTypes" And FirstObjectReference.Metadata().Hierarchical);
	
EndFunction

&AtClient
Procedure ResetChangeSettings()
	For Each Attribute In ObjectAttributes Do
		Attribute.Value = Undefined;
		Attribute.Change = False;
	EndDo;
	
	For Each TabularSection In ObjectTabularSections Do
		For Each Attribute In ThisObject[TabularSection.Value] Do
			Attribute.Value = Undefined;
			Attribute.Change = False;
		EndDo;
	EndDo;	
EndProcedure

&AtClient
Procedure FilterSettingsClick(Item)
	GoToFilterSettings();
EndProcedure

&AtClient
Procedure OnCloseSelectedObjectsForm(Settings, AdditionalParameters) Export
	If TypeOf(Settings) = Type("DataCompositionSettings") Then
		SettingsComposer.LoadSettings(Settings);
		UpdateLabel();
		ClearUpTempStorageOfListOfSelected(SelectedItemsListAddress);
	EndIf;
EndProcedure

&AtServerNoContext
Function Filter_Settings()
	Result = New Structure;
	Result.Insert("UpdateList", False);
	Result.Insert("IncludeTabularSectionsInSelection", False);
	Result.Insert("RestrictSelection", False);
	Return Result;
EndFunction

// Parameters:
//   Filter_Settings - Structure:
//     * RestrictSelection - Boolean
//     * IncludeTabularSectionsInSelection - Boolean
//     * UpdateList - Boolean
//   ErrorMessageText - String
//
// Returns:
//   ValueTree:
//     * Ref - AnyRef
//
&AtServer
Function SelectedObjects(Filter_Settings = Undefined, ErrorMessageText = "")
	
	If Filter_Settings = Undefined Then
		Filter_Settings = Filter_Settings();
	EndIf;
	
	UpdateList = Filter_Settings.UpdateList;
	IncludeTabularSectionsInSelection = Filter_Settings.IncludeTabularSectionsInSelection;
	RestrictSelection = Filter_Settings.RestrictSelection;
	
	If Not UpdateList And Not RestrictSelection And Not IsBlankString(SelectedItemsListAddress) Then
		Return GetFromTempStorage(SelectedItemsListAddress);
	EndIf;
		
	Result = New ValueTree;
	
	If Not IsBlankString(KindsOfObjectsToChange) Then
		DataProcessorObject = FormAttributeToValue("Object");
		QueryText = DataProcessorObject.QueryText(KindsOfObjectsToChange, RestrictSelection);
		DataCompositionSchema = DataCompositionSchema(QueryText);
		
		DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
		SchemaURL = PutToTempStorage(DataCompositionSchema, UUID);
		DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
		DataCompositionSettingsComposer.LoadSettings(SettingsComposer.Settings);
		If IncludeTabularSectionsInSelection Then
			SetResultOutputStructureSetting(DataCompositionSettingsComposer.Settings, IncludeTabularSectionsInSelection);
		EndIf;
		
		If ObjectsThatCouldNotBeChanged.Count() > 0 And Not Object.ChangeInTransaction Then // Repeat for unchanged objects.
			FilterElement = DataCompositionSettingsComposer.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
			FilterElement.LeftValue = New DataCompositionField("Ref");
			FilterElement.ComparisonType = DataCompositionComparisonType.InList;
			FilterElement.RightValue = New ValueList;
			FilterElement.RightValue.LoadValues(ObjectsThatCouldNotBeChanged.Unload().UnloadColumn("Object"));
		EndIf;
		
		Result = New ValueTree;
		TemplateComposer = New DataCompositionTemplateComposer;
		Try
			DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema,
				DataCompositionSettingsComposer.Settings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
		Except
			ErrorMessageText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
			Return Result;
		EndTry;
			
		DataCompositionProcessor = New DataCompositionProcessor;
		DataCompositionProcessor.Initialize(DataCompositionTemplate);

		OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
		OutputProcessor.SetObject(Result);
		OutputProcessor.Output(DataCompositionProcessor);
		If Not RestrictSelection Then
			SelectedItemsListAddress = PutToTempStorage(Result, UUID);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Procedure ClearUpTempStorageOfListOfSelected(SelectedItemsListAddress)
	
	If ValueIsFilled(SelectedItemsListAddress) Then
		DeleteFromTempStorage(SelectedItemsListAddress);
		SelectedItemsListAddress = "";
	EndIf;
	
EndProcedure

&AtServer
Procedure SetResultOutputStructureSetting(Settings, ForChange = False)
	
	Settings.Structure.Clear();
	Settings.Selection.Items.Clear();
	
	DataCompositionGroup = Settings.Structure.Add(Type("DataCompositionGroup"));
	DataCompositionGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	DataCompositionGroup.Use = True;
	
	GroupingField = DataCompositionGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	GroupingField.Field = New DataCompositionField("Ref");
	GroupingField.Use = True;
	
	ComboBox = Settings.Selection.Items.Add(Type("DataCompositionSelectedField"));
	ComboBox.Field = New DataCompositionField("Ref");
	ComboBox.Use = True;
	
	If ForChange Then
		DataProcessorObject = FormAttributeToValue("Object");
		CommonObjectsAttributes = DataProcessorObject.CommonObjectsAttributes(KindsOfObjectsToChange);
		For Each TabularSection In CommonObjectsAttributes.TabularSections Do
			TabularSectionName = TabularSection.Key;
			
			TableGroup = DataCompositionGroup.Structure.Add(Type("DataCompositionGroup"));
			TableGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
			TableGroup.Use = True;
			
			GroupingField = TableGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
			GroupingField.Field = New DataCompositionField(TabularSectionName + ".LineNumber");
			GroupingField.Use = True;
			
			ComboBox = Settings.Selection.Items.Add(Type("DataCompositionSelectedField"));
			ComboBox.Field = New DataCompositionField(TabularSectionName + ".LineNumber");
			ComboBox.Use = True;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Function SelectedObjectsCount(ShouldRecalculate = False, ForChange = False, ErrorMessageText = "")
	Filter_Settings = Filter_Settings();
	Filter_Settings.UpdateList = ShouldRecalculate;
	Filter_Settings.IncludeTabularSectionsInSelection = ForChange;
	
	Return SelectedObjects(Filter_Settings, ErrorMessageText).Rows.Count();
EndFunction

&AtServer
Function DataCompositionSchema(QueryText)
	
	DataCompositionSchema = New DataCompositionSchema;
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.DataSource = "DataSource1";
	DataSet.AutoFillAvailableFields = True;
	DataSet.Query = QueryText;
	DataSet.Name = "DataSet1";
	
	Return DataCompositionSchema;
	
EndFunction

&AtClient
Procedure KindOfObjectsToChangeWhenSelected(Val SelectedObjects, AdditionalParameters) Export
	If SelectedObjects <> Undefined And KindsOfObjectsToChange <> SelectedObjects Then
		KindsOfObjectsToChange = StrConcat(SelectedObjects, ",");
		SelectedObjectsInContext.Clear();
		RebuildFormInterfaceForSelectedObjectKind();
		Items.ObjectAttributesAlgorithm.RowFilter = New FixedStructure(New Structure("OperationKind", "1"));
		If Not ContextCall Then
			SaveKindsOfObjectsToChange(KindsOfObjectsToChange, SelectedItemsListAddress);
		EndIf;	
	EndIf;
EndProcedure

&AtServer
Procedure RebuildFormInterfaceForSelectedObjectKind()
	InitializeFormSettings();
	UpdateItemsVisibility();
	GenerateNoteOnConfiguredChanges();
EndProcedure

&AtServer
Procedure InitializeFormSettings()
	InitializeSettingsComposer();
	LoadObjectMetadata();
	LoadOperationsHistory();
	FillPreviouslyChangedAttributesSubmenu();
	PresentationOfObjectsToChange = PresentationOfObjectsToChange();
	UpdateLabelServer();
EndProcedure

&AtServer
Function PresentationOfObjectsToChange()
	TypesPresentation1 = New Array;
	For Each MetadataObjectName In StrSplit(KindsOfObjectsToChange, ",", False) Do
		MetadataObject = Metadata.FindByFullName(MetadataObjectName);
		TypesPresentation1.Add(MetadataObject.Presentation());
	EndDo;
		
	Result = StrConcat(TypesPresentation1, ", ");
	Return Result;
EndFunction

&AtServer
Procedure InitializeSettingsComposer()
	If IsBlankString(KindsOfObjectsToChange) Then
		Return;
	EndIf;
	
	DataProcessorObject1 = FormAttributeToValue("Object");
	QueryText = DataProcessorObject1.QueryText(KindsOfObjectsToChange);
	DataCompositionSchema = DataCompositionSchema(QueryText);
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(
		PutToTempStorage(DataCompositionSchema, UUID)));
	SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
	
	If SelectedObjectsInContext.Count() > 0 Then
		If TypeOf(Parameters.SettingsComposer) = Type("DataCompositionSettingsComposer") Then
			ComposerSettings = Parameters.SettingsComposer.GetSettings();
			SettingsComposer.LoadSettings(ComposerSettings);
			SettingsComposer.Settings.ConditionalAppearance.Items.Clear();
			
			ItemsToRemove = New Array;
			For Each Item In SettingsComposer.Settings.Order.Items Do
				AvailableField = SettingsComposer.Settings.Order.OrderAvailableFields.FindField(Item.Field);
				If AvailableField = Undefined Then
					ItemsToRemove.Add(Item);
				EndIf;
			EndDo;
			For Each Item In ItemsToRemove Do
				SettingsComposer.Settings.Order.Items.Delete(Item);
			EndDo;
			
			TemplateComposer = New DataCompositionTemplateComposer;
			Try
				TemplateComposer.Execute(DataCompositionSchema, SettingsComposer.Settings,,, 
					Type("DataCompositionValueCollectionTemplateGenerator"));
			Except
				SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
			EndTry;
		EndIf;
		
		FilterElement = SettingsComposer.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterElement.LeftValue = New DataCompositionField("Ref");
		If IncludeHierarchy And ProcessRecursively Then
			FilterElement.ComparisonType = DataCompositionComparisonType.InListByHierarchy;
		Else
			FilterElement.ComparisonType = DataCompositionComparisonType.InList;
		EndIf;
		FilterElement.RightValue = New ValueList;
		FilterElement.RightValue.LoadValues(SelectedObjectsInContext.UnloadValues());
	
	EndIf;
	
	SetResultOutputStructureSetting(SettingsComposer.Settings);
	
EndProcedure

&AtServer
Procedure ClearObjectDetails()
	FormAttributesBeingDeleted = New Array;
	For Each TabularSection In ObjectTabularSections Do
		FormAttributesBeingDeleted.Add(TabularSection.Value);
		Items.Delete(Items.Find("Page" + TabularSection.Value));
	EndDo;
	ChangeAttributes(, FormAttributesBeingDeleted);
	ObjectTabularSections.Clear();
EndProcedure

&AtServer
Procedure LoadObjectMetadata(SaveCurrentChangeSettings = False, SavedSettings = Undefined)
	
	If SaveCurrentChangeSettings Then
		CurrentSettings =  CurrentChangeSettings();
		If CurrentSettings <> Undefined Then
			SavedSettings = CurrentSettings.ChangeDescription;
		EndIf;
	EndIf;
	
	ClearObjectDetails();
	
	DetailsOfAttributes = New Structure;
	DetailsOfAttributes.Insert("AttributesToSkip", AttributesToSkip());
	DetailsOfAttributes.Insert("DisabledAttributes", DisabledAttributes());
	DetailsOfAttributes.Insert("LockedAttributes", LockedAttributes());
	DetailsOfAttributes.Insert("ExcludedAttributeTypes", ExcludedAttributeTypes());

	DataProcessorObject = FormAttributeToValue("Object");
	CommonObjectsAttributes = DataProcessorObject.CommonObjectsAttributes(KindsOfObjectsToChange);
	
	FillObjectAttributes(DetailsOfAttributes, CommonObjectsAttributes.Attributes);
	FillObjectsTabularSections(DetailsOfAttributes, CommonObjectsAttributes.TabularSections);
	
	GenerateNoteAboutAutonumbering();
	SetConditionalAppearance();
	
EndProcedure

&AtServer
Procedure GenerateNoteAboutAutonumbering()
	
	Autonumbering = Undefined;
	For Each TypeName In StrSplit(KindsOfObjectsToChange, ",", False) Do
		MetadataObject = Metadata.FindByFullName(TypeName); // MetadataObjectCatalog, MetadataObjectDocument
		
		If Metadata.ExchangePlans.Contains(MetadataObject) 
			Or Metadata.ChartsOfCalculationTypes.Contains(MetadataObject)
			Or Metadata.ChartsOfAccounts.Contains(MetadataObject) Then
				Autonumbering = Undefined;
				Break;
		EndIf;
		
		If Autonumbering = Undefined Then
			Autonumbering = MetadataObject.Autonumbering;
			Continue;
		EndIf;
		
		If Autonumbering And Not MetadataObject.Autonumbering Then
			Autonumbering = Undefined;
			Break;
		EndIf;
	EndDo;
	
	If Autonumbering = Undefined Then
		NoteOnAutonumbering = "";
	ElsIf Autonumbering Then
		NoteOnAutonumbering = NStr("en = '<Set automatically>';");
	Else
		NoteOnAutonumbering = NStr("en = '<Clear>';");
	EndIf;
	
EndProcedure

&AtServer
Function ObjectAttributesToLock(ObjectName)
	
	If SubsystemExists("StandardSubsystems.ObjectAttributesLock") Then
		ModuleObjectAttributesLock = CommonModule("ObjectAttributesLock");
		Return ModuleObjectAttributesLock.ObjectAttributesToLock(ObjectName);
	EndIf;
	
	Return New Array;
	
EndFunction

&AtServer
Function LockedAttributes()
	
	Result = New Array;
	
	For Each ObjectsKind In StrSplit(KindsOfObjectsToChange, ",", False) Do
		If SSLVersionMatchesRequirements Then
			For Each Attribute In ObjectAttributesToLock(ObjectsKind) Do
				If Result.Find(Attribute) = Undefined Then
					Result.Add(Attribute);
				EndIf;
			EndDo;
			Continue;
		EndIf;
		
		// For configurations without SSL or with an old SSL integrated, 
		// identify if the object has locked attributes (subsystem "Object attribute lock")
		ObjectManager = ObjectManagerByFullName(ObjectsKind);
		Try
			AttributesToLockDetails = ObjectManager.GetObjectAttributesToLock();
		Except
			// Method not found.
			AttributesToLockDetails = Undefined;
		EndTry;
	
		If AttributesToLockDetails <> Undefined Then
			For Each AttributeToLockDetails In AttributesToLockDetails Do
				AttributeName = TrimAll(StrSplit(AttributeToLockDetails, ";")[0]);
				If Result.Find(AttributeName) = Undefined Then
					Result.Add(AttributeName);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function AttributesToSkip()
	
	If Object.ShowInternalAttributes Then
		Return New Array;
	EndIf;
	
	Result = New Array;
	DataProcessorObject = FormAttributeToValue("Object");
	
	AttributesNames = New Map;
	
	For Each KindOfObjectsToChange In StrSplit(KindsOfObjectsToChange, ",", False) Do
		MetadataObject = Metadata.FindByFullName(KindOfObjectsToChange);
		AttributesEditingSettings = DataProcessorObject.AttributesEditingSettings(MetadataObject);
		AttributesToEdit = AttributesEditingSettings.ToEdit;
		AttributesToSkip = AttributesEditingSettings.NotToEdit;
		
		If ValueIsFilled(AttributesToSkip) Then
			If AttributesToSkip.Find("*") = Undefined Then
				For Each AttributeName In AttributesToSkip Do
					AttributesNames.Insert(AttributeName);
				EndDo;
				Continue;
			Else
				AttributesToEdit = New Array;
			EndIf;
		Else
			If AttributesToEdit = Undefined 
				Or TypeOf(AttributesToEdit) = Type("Array") And AttributesToEdit.Find("*") <> Undefined Then
				Continue;
			EndIf;
		EndIf;
		
		AttributesToSkip = New Array;
		MetadataObject = Metadata.FindByFullName(KindOfObjectsToChange);
		StandardAttributesDetails = MetadataObject.StandardAttributes; // Array of StandardAttributeDescription
		For Each AttributeDetails In StandardAttributesDetails Do
			AttributesToSkip.Add(AttributeDetails.Name);
		EndDo;
		
		AttributesDetails1 = MetadataObject.Attributes; // Array of MetadataObjectAttribute
		For Each AttributeDetails In AttributesDetails1 Do
			AttributesToSkip.Add(AttributeDetails.Name);
		EndDo;
		
		For Each TabularSection In MetadataObject.TabularSections Do
			If AttributesToEdit.Find(TabularSection.Name + ".*") <> Undefined Then
				Break;
			EndIf;
			TabularSectionAttributesDetails = TabularSection.Attributes; // Array of MetadataObjectAttribute
			For Each Attribute In TabularSectionAttributesDetails Do
				AttributesToSkip.Add(TabularSection.Name + "." + Attribute.Name);
			EndDo;
		EndDo;
		
		For Each AttributeName In AttributesToEdit Do
			IndexOf = AttributesToSkip.Find(AttributeName);
			If IndexOf = Undefined Then
				Continue;
			EndIf;
			AttributesToSkip.Delete(IndexOf);
		EndDo;
		
		For Each AttributeName In AttributesToSkip Do
			AttributesNames.Insert(AttributeName);
		EndDo;
	EndDo;
	
	For Each Item In AttributesNames Do
		AttributeName = Item.Key;
		Result.Add(AttributeName);
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function DisabledAttributes()

	If Object.ShowInternalAttributes Then
		Return New Array;
	EndIf;
	
	ObjectsEnabled = ObjectsEnabled();
	
	For Each TypeName In StrSplit(KindsOfObjectsToChange, ",", False) Do
		MetadataObject = Metadata.FindByFullName(TypeName);
		DisabledAttributes = EditFilterByType(MetadataObject);
		
		AttributesDisabledByFunctionalOptions = New Map;
		
		AttributesDetails1 = MetadataObject.Attributes; // Array of MetadataObjectAttribute
		For Each Attribute In AttributesDetails1 Do
			If ObjectsEnabled[Attribute] = False Then
				AttributesDisabledByFunctionalOptions.Insert(Attribute.Name, True);
			EndIf;
		EndDo;
		
		TabularSectionsDetails = MetadataObject.TabularSections; // Array of MetadataObjectTabularSection
		For Each TabularSection In TabularSectionsDetails Do
			If ObjectsEnabled[TabularSection] = False Then
				AttributesDisabledByFunctionalOptions.Insert(TabularSection.Name + ".*", True);
				Continue;
			EndIf;
			For Each Attribute In TabularSection.Attributes Do
				If ObjectsEnabled[Attribute] = False Then
					AttributesDisabledByFunctionalOptions.Insert(TabularSection.Name + "." + Attribute.Name, True);
				EndIf;
			EndDo;
		EndDo;
		
		For Each PropsClosedWithFunctionalOptions In AttributesDisabledByFunctionalOptions Do
			DisabledAttributes.Insert(PropsClosedWithFunctionalOptions.Key, True);
		EndDo;
		
	EndDo;
		
	Result = New Array;
	For Each Attribute In DisabledAttributes Do
		Result.Add(Attribute.Key);
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function ExcludedAttributeTypes()
	
	Result = Undefined;
	KindsOfObjectsToChangeList = StrSplit(KindsOfObjectsToChange, ",", False);
	If KindsOfObjectsToChangeList.Count() = 0 Then
		Return Result;
	EndIf;
	
	If SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = CommonModule("FilesOperationsInternal");
		ObjectName = KindsOfObjectsToChangeList[0];
		Result = New Map;
		For Each CatalogName In ModuleFilesOperationsInternal.FileStorageCatalogNames(
			ObjectManagerByFullName(ObjectName).EmptyRef(), True) Do
			Result[Type("CatalogRef." + CatalogName.Key)] = True;
		EndDo;
	EndIf;
	Return Result;
	
EndFunction

&AtServer
Procedure FillObjectsTabularSections(DetailsOfAttributes, AvailableTabularSections)
	
	KindsOfObjectsToChangeList = StrSplit(KindsOfObjectsToChange, ",", False);
	If KindsOfObjectsToChangeList.Count() = 0 Then
		Return;
	EndIf;

	ObjectName = KindsOfObjectsToChangeList[0];
	MetadataObject = Metadata.FindByFullName(ObjectName);
	
	NewFormAttributes = New Array;
	TableColumns = AttributesTableColumnDescriptions();
	ObjectTables = New Structure;
	ObjectTabularSections.Clear();

	For Each TabularSectionDetails In MetadataObject.TabularSections Do
		If Not AvailableTabularSections.Property(TabularSectionDetails.Name) Then
			Continue;
		EndIf;
			
		If Not AccessRight("Edit", TabularSectionDetails) Then
			Continue;
		EndIf;

		If DetailsOfAttributes.AttributesToSkip.Find(TabularSectionDetails.Name + ".*") <> Undefined Then
			Continue;
		EndIf;
		If DetailsOfAttributes.DisabledAttributes.Find(TabularSectionDetails.Name + ".*") <> Undefined Then
			Continue;
		EndIf;
		
		EditableAttributes = EditableAttributes(TabularSectionDetails, DetailsOfAttributes, 
			AvailableTabularSections[TabularSectionDetails.Name]);
		If EditableAttributes.Count() = 0 Then
			Continue;
		EndIf;
		
		AttributeName = "TabularSection" + TabularSectionDetails.Name;
		ValueTable = New FormAttribute(AttributeName, New TypeDescription("ValueTable"), , TabularSectionDetails.Presentation());
		NewFormAttributes.Add(ValueTable);
		
		For Each ColumnDetails In TableColumns Do 
			TableAttribute = New FormAttribute(ColumnDetails.Name, ColumnDetails.Type, ValueTable.Name, ColumnDetails.Presentation);
			NewFormAttributes.Add(TableAttribute);
		EndDo;
		
		ObjectTables.Insert(AttributeName, TabularSectionDetails);
		ObjectTabularSections.Add(AttributeName, TabularSectionDetails.Presentation());
	EndDo;
	ChangeAttributes(NewFormAttributes);
	
	For Each ObjectTable In ObjectTables Do
		AttributeName = ObjectTable.Key;
		PageName = "Page" + AttributeName;
		Page = Items.Add(PageName, Type("FormGroup"), Items.ObjectComposition);
		Page.Type = FormGroupType.Page;
		TabularSectionDetails = ObjectTable.Value;
		Page.Title = TabularSectionDetails.Presentation();
		
		FormTable = Items.Add(AttributeName, Type("FormTable"), Page);
		FormTable.TitleLocation = FormItemTitleLocation.None;
		FormTable.DataPath = AttributeName;
		FormTable.CommandBarLocation = FormItemCommandBarLabelLocation.None;
		FormTable.Title = TabularSectionDetails.Presentation();
		FormTable.SetAction("BeforeRowChange", "Attachable_BeforeRowChange");
		FormTable.ChangeRowOrder = False;
		FormTable.ChangeRowSet = False;
		FormTable.RowsPicture = OperationsKindsPicture();
		FormTable.RowPictureDataPath = AttributeName + ".OperationKind";
		FormTable.Height = 5;
		
		For Each ColumnDetails In TableColumns Do 
			If ColumnDetails.FieldKind = Undefined Then
				Continue;
			EndIf;
			AttributeName = ColumnDetails.Name;
			TagName = FormTable.Name + AttributeName;
			TableColumn2 = Items.Add(TagName, Type("FormField"), FormTable);
			If ColumnDetails.Picture <> Undefined Then
				TableColumn2.TitleLocation = FormItemTitleLocation.None;
				TableColumn2.HeaderPicture = ColumnDetails.Picture;
			EndIf;
			TableColumn2.DataPath = ObjectTable.Key + "." + AttributeName;
			TableColumn2.Type = ColumnDetails.FieldKind;
			TableColumn2.EditMode = ColumnEditMode.EnterOnInput;
			TableColumn2.ReadOnly = ColumnDetails.ReadOnly;
			If ColumnDetails.Actions <> Undefined Then
				For Each Action In ColumnDetails.Actions Do
					TableColumn2.SetAction(Action.Key, Action.Value);
				EndDo;
			EndIf;
		EndDo;
		
		EditableAttributes = EditableAttributes(TabularSectionDetails, DetailsOfAttributes,
			AvailableTabularSections[TabularSectionDetails.Name]);	
		For Each AttributeDetails In EditableAttributes Do
			FormDataTable = ThisObject[ObjectTable.Key]; // See AttributesTableColumnDescriptions
			Attribute = FormDataTable.Add();
			Attribute.Name = AttributeDetails.Name;
			Attribute.Presentation = ?(IsBlankString(AttributeDetails.Presentation()), AttributeDetails.Name, 
				AttributeDetails.Presentation());
			Attribute.AllowedTypes = AttributeDetails.Type;
			Attribute.ChoiceParameterLinks = ChoiceParameterLinksAsString(AttributeDetails.ChoiceParameterLinks);
			Attribute.ChoiceParameters = ChoiceParametersAsString(AttributeDetails.ChoiceParameters);
			Attribute.OperationKind = 1;
			Attribute.ChoiceParameterLinksPresentation = ChoiceParameterLinksPresentation(
				AttributeDetails.ChoiceParameterLinks, MetadataObject);
		EndDo;
	EndDo;
	
EndProcedure

// Parameters:
//   TabularSectionDetails - Structure:
//     * Attributes - Array of MetadataObjectAttribute
//   DetailsOfAttributes - Structure
//   AvailableAttributes - Array
//
// Returns:
//   Array of MetadataObjectAttribute
//
&AtServer
Function EditableAttributes(TabularSectionDetails, DetailsOfAttributes, AvailableAttributes)
	
	Result = New Array;
	
	For Each AttributeDetails In TabularSectionDetails.Attributes Do
		If AvailableAttributes.Find(AttributeDetails.Name) = Undefined Then
			Continue;
		EndIf;
		
		If Not AccessRight("Edit", AttributeDetails) Then
			Continue;
		EndIf;
		
		If DetailsOfAttributes.AttributesToSkip.Find(TabularSectionDetails.Name + "." + AttributeDetails.Name) <> Undefined Then
			Continue;
		EndIf;
		If DetailsOfAttributes.DisabledAttributes.Find(TabularSectionDetails.Name + "." + AttributeDetails.Name) <> Undefined Then
			Continue;
		EndIf;
		If IsExcludedAttributeType(AttributeDetails, DetailsOfAttributes.ExcludedAttributeTypes) Then
			Continue;	
		EndIf;
		
		Result.Add(AttributeDetails);
	EndDo;
	
	Return Result;
	
EndFunction

// Returns:
//   ValueTable:
//   * Name - String
//   * Type - String
//   * Presentation - String 
//   * FieldKind - String
//   * Actions - Structure:
//     ** OnChange - Boolean
//     ** Attachable_OnCheckChange - Boolean
//   * ReadOnly - Boolean
//   * Picture - Picture
//
&AtServer
Function AttributesTableColumnDescriptions()
	
	TableColumns = New ValueTable;
	TableColumns.Columns.Add("Name");
	TableColumns.Columns.Add("Type");
	TableColumns.Columns.Add("Presentation");
	TableColumns.Columns.Add("FieldKind");
	TableColumns.Columns.Add("Actions");
	TableColumns.Columns.Add("ReadOnly", New TypeDescription("Boolean"));
	TableColumns.Columns.Add("Picture");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Name";
	ColumnDetails.Type = New TypeDescription("String");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Presentation";
	ColumnDetails.Type = New TypeDescription("String");
	ColumnDetails.Presentation = NStr("en = 'Attribute';");
	ColumnDetails.FieldKind = FormFieldType.InputField;
	ColumnDetails.ReadOnly = True;
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Change";
	ColumnDetails.Type = New TypeDescription("Boolean");
	ColumnDetails.FieldKind = FormFieldType.CheckBoxField;
	ColumnDetails.Picture = PictureLib.Change;
	ColumnDetails.Actions = New Structure("OnChange", "Attachable_OnCheckChange");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Value";
	ColumnDetails.Type = AllTypes();
	ColumnDetails.Presentation = NStr("en = 'New value';");
	ColumnDetails.FieldKind = FormFieldType.InputField;
	ColumnDetails.Actions = New Structure("OnChange", "Attachable_ValueOnChange");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "AllowedTypes";
	ColumnDetails.Type = New TypeDescription("TypeDescription");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "ChoiceParameterLinks";
	ColumnDetails.Type = New TypeDescription("String");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "ChoiceParameters";
	ColumnDetails.Type = New TypeDescription("String");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "OperationKind";
	ColumnDetails.Type = New TypeDescription("Number");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Property";
	ColumnDetails.Type = New TypeDescription("String");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "ChoiceFoldersAndItems";
	ColumnDetails.Type = New TypeDescription("String");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "ChoiceParameterLinksPresentation";
	ColumnDetails.Type = New TypeDescription("String");
	
	Return TableColumns;
	
EndFunction

&AtServer
Function AllTypes()
	Result = Undefined;
	Attributes = GetAttributes("ObjectAttributes");
	For Each Attribute In Attributes Do
		If Attribute.Name = "Value" Then
			Result = Attribute.ValueType;
			Break;
		EndIf;
	EndDo;
	Return Result;
EndFunction

&AtClient
Procedure RestrictSelectableTypesAndSetValueChoiceParameters(TableBox)
	If TableBox.CurrentData = Undefined Then
		Return;
	EndIf;
	
	InputField = TableBox.ChildItems[TableBox.Name + "Value"];
	InputField.TypeRestriction = TableBox.CurrentData.AllowedTypes;
	
	If InputField.TypeRestriction.Types().Count() = 1 And InputField.TypeRestriction.ContainsType(Type("String")) Then
		InputField.ChoiceButton = True;
	EndIf;
	
	ChoiceParametersArray1 = New Array;
	
	If Not IsBlankString(TableBox.CurrentData.ChoiceParameters) Then
		SetChoiceParametersServer(TableBox.CurrentData.ChoiceParameters, ChoiceParametersArray1)
	EndIf;
	
	If Not IsBlankString(TableBox.CurrentData.ChoiceParameterLinks) Then
		For IndexOf = 1 To StrLineCount(TableBox.CurrentData.ChoiceParameterLinks) Do
			ChoiceParametersLinksString = StrGetLine(TableBox.CurrentData.ChoiceParameterLinks, IndexOf);
			ParsedStrings = StrSplit(ChoiceParametersLinksString, ";");
			ParameterName = TrimAll(ParsedStrings[0]);
			
			AttributeName = TrimAll(ParsedStrings[1]);
			AttributeNameParts = StrSplit(AttributeName, ".", False);
			TabularSectionName = "";
			If AttributeNameParts.Count() > 1 Then
				TabularSectionName = AttributeNameParts[0];
			EndIf;
			AttributeName = AttributeNameParts[AttributeNameParts.Count() - 1];
			
			AttributesTable = ObjectAttributes;
			If Not IsBlankString(TabularSectionName) Then
				AttributesTable = ThisObject["TabularSection" + TabularSectionName];
			EndIf;
			
			FoundRows = AttributesTable.FindRows(New Structure("OperationKind,Name", 1, AttributeName));
			If FoundRows.Count() = 1 Then
				Value = FoundRows[0].Value;
				If ValueIsFilled(Value) Then
					ChoiceParametersArray1.Add(New ChoiceParameter(ParameterName, Value));
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	If ValueIsFilled(TableBox.CurrentData.Property) Then
		ChoiceParametersArray1.Add(New ChoiceParameter("Filter.Owner", TableBox.CurrentData.Property));
	EndIf;
	
	If DisableSelectionParameterConnections Then
		InputField.ChoiceParameters = New FixedArray(New Array);
	Else
		InputField.ChoiceParameters = New FixedArray(ChoiceParametersArray1);
	EndIf;
	
	ChoiceFoldersAndItems = TableBox.CurrentData.ChoiceFoldersAndItems;
	
	If ChoiceFoldersAndItems <> "" Then
		If ChoiceFoldersAndItems = "Groups" Then
			InputField.ChoiceFoldersAndItems = FoldersAndItems.Folders;
		ElsIf ChoiceFoldersAndItems = "FoldersAndItems" Then
			InputField.ChoiceFoldersAndItems = FoldersAndItems.FoldersAndItems;
		ElsIf ChoiceFoldersAndItems = "Items" Then
			InputField.ChoiceFoldersAndItems = FoldersAndItems.Items;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateCountersOfAttributesToChange(Val FormTable = Undefined)
	
	TablesList = New Array;
	If FormTable <> Undefined Then
		TablesList.Add(FormTable);
	Else
		TablesList.Add(Items.ObjectAttributes);
		For Each TabularSection In ObjectTabularSections Do
			TablesList.Add(Items[TabularSection.Value]);
		EndDo;
	EndIf;
	
	For Each FormTable In TablesList Do
		TabularSection = ThisObject[FormTable.Name];
		ItemsToChangeCount = 0;
		For Each Attribute In TabularSection Do
			If Attribute.Change Then
				ItemsToChangeCount = ItemsToChangeCount + 1;
			EndIf;
		EndDo;
	
		Page = FormTable.Parent;// FormGroup
		Page.Title = FormTable.Title + ?(ItemsToChangeCount = 0, "", " (" + ItemsToChangeCount+ ")");
	EndDo;
	
EndProcedure

&AtServer
Procedure UpdateItemsVisibility()
	If ObjectTabularSections.Count() = 0 Then
		Items.ObjectComposition.PagesRepresentation = FormPagesRepresentation.None;
	Else
		Items.ObjectComposition.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
	EndIf;
	
	If Not IsBlankString(KindsOfObjectsToChange) Then
		CommonAttributesAvailable = ObjectAttributes.Count() > 0;
		Items.NoAttributesGroup.Visible = Not CommonAttributesAvailable;
		If Object.OperationType = "ExecuteAlgorithm" Then
			Items.Algorithms.Visible = True;
		Else
			Items.PreviouslyChangedAttributes.Visible = CommonAttributesAvailable Or ObjectTabularSections.Count() > 0;
		EndIf;
		Items.ObjectAttributes.Visible = CommonAttributesAvailable;
	EndIf;
EndProcedure

&AtServer
Procedure FillObjectAttributes(DetailsOfAttributes, AvailableAttributes)
	
	ObjectAttributes.Clear();
	
	KindsOfObjectsToChangeList = StrSplit(KindsOfObjectsToChange, ",", False);
	If KindsOfObjectsToChangeList.Count() = 0 Then
		Return;
	EndIf;
	
	ObjectName = KindsOfObjectsToChangeList[0];
	MetadataObject = Metadata.FindByFullName(ObjectName);

	AddAttributesToSet(DetailsOfAttributes, MetadataObject, AvailableAttributes, MetadataObject.StandardAttributes);
	AddAttributesToSet(DetailsOfAttributes, MetadataObject, AvailableAttributes, MetadataObject.Attributes);
	ObjectAttributes.Sort("Presentation Asc");
	
	If SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = CommonModule("PropertyManager");
		If ModulePropertyManager <> Undefined Then
			AdditionalAttributesUsed = True;
			AdditionalInfoUsed = True;
			For Each ObjectKind In KindsOfObjectsToChangeList Do
				ObjectManager = ObjectManagerByFullName(ObjectKind);
				AdditionalAttributesUsed = AdditionalAttributesUsed And ModulePropertyManager.UseAddlAttributes(ObjectManager.EmptyRef());
				AdditionalInfoUsed  = AdditionalInfoUsed And ModulePropertyManager.UseAddlInfo (ObjectManager.EmptyRef());
			EndDo;
			If AdditionalAttributesUsed Or AdditionalInfoUsed Then
				AddAdditionalAttributesAndInfoToSet();
			EndIf;
		EndIf;
	EndIf;
	
	AddExternalAttributesToSet(DetailsOfAttributes, KindsOfObjectsToChangeList);
	
EndProcedure

&AtServer
Procedure AddAdditionalAttributesAndInfoToSet()
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	KindsOfObjectsToChangeList = StrSplit(KindsOfObjectsToChange, ",", False);
	CommonAttributesList = PropertiesListForObjectsKind(KindsOfObjectsToChangeList[0]);
	For IndexOf = 1 To KindsOfObjectsToChangeList.Count() - 1 Do
		CommonAttributesList = DataProcessorObject.SetIntersection(CommonAttributesList, PropertiesListForObjectsKind(KindsOfObjectsToChangeList[IndexOf]));
	EndDo;
	
	PropertiesToAdd = New Array;
	
	If ContextCall Then
		Filter_Settings = Filter_Settings();
		Filter_Settings.UpdateList = True;
		SelectedObjects = SelectedObjects(Filter_Settings).Rows;
		For Each ObjectData In SelectedObjects Do
			ObjectToChange1 = ObjectData.Ref;
			
			ObjectKindByRef = ObjectKindByRef(ObjectToChange1);
			If (ObjectKindByRef = "Catalog" Or ObjectKindByRef = "ChartOfCharacteristicTypes") And ObjectIsFolder(ObjectToChange1) Then
				Continue;
			EndIf;
			
			ModulePropertyManager = CommonModule("PropertyManager");
			ListOfProperties = ModulePropertyManager.ObjectProperties(ObjectToChange1);
			For Each Property In ListOfProperties Do
				If CommonAttributesList.Find(Property) = Undefined Then
					Continue;
				EndIf;
				
				If PropertiesToAdd.Find(Property) <> Undefined Then
					Continue;
				EndIf;
				
				PropertiesToAdd.Add(Property);
			EndDo;
		EndDo;
	Else
		PropertiesToAdd = CommonAttributesList;
	EndIf;
	
	AddPropertiesToAttributesList(PropertiesToAdd);
	ObjectAttributes.Sort("Presentation");
	
EndProcedure

&AtServer
Procedure AddPropertiesToAttributesList(Properties)
	
	ModuleCommon = CommonModule("Common");
	DetailsOfProperties = ModuleCommon.ObjectsAttributesValues(Properties, "Ref,Description,ValueType,IsAdditionalInfo");
	For Each Property In Properties Do
		PropertyDetails = DetailsOfProperties[Property];
		AttributeDetails = ObjectAttributes.Add();
		AttributeDetails.OperationKind = ?(PropertyDetails.IsAdditionalInfo, 3, 2);
		AttributeDetails.Property = PropertyDetails.Ref;
		AttributeDetails.Presentation = PropertyDetails.Description;
		AttributeDetails.AllowedTypes = PropertyDetails.ValueType;
	EndDo;
	
EndProcedure

&AtServer
Function PropertiesListForObjectsKind(ObjectsKind)
	Result = New Array;
	
	PropertiesKinds = New Array;
	PropertiesKinds.Add("AdditionalAttributes");
	PropertiesKinds.Add("AdditionalInfo");
	
	ModulePropertyManagerInternal = CommonModule("PropertyManagerInternal");
	If ModulePropertyManagerInternal <> Undefined Then
		For Each PropertyKind1 In PropertiesKinds Do
			ListOfProperties = ModulePropertyManagerInternal.PropertiesListForObjectsKind(ObjectsKind, PropertyKind1);
			If ListOfProperties <> Undefined Then
				For Each Item In ListOfProperties Do
					Result.Add(Item.Property);
				EndDo;
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Procedure AddAttributesToSet(DetailsOfAttributes, MetadataObject, AvailableAttributes, AttributesDetails2)
	
	For Each AttributeDetails In AttributesDetails2 Do
		If AvailableAttributes.Find(AttributeDetails.Name) = Undefined Then
			Continue;
		EndIf;
		
		If TypeOf(AttributeDetails) = Type("StandardAttributeDescription") Then
			If Not AccessRight("Edit", MetadataObject, , AttributeDetails.Name) Then
				Continue;
			EndIf;
		Else
			If Not AccessRight("Edit", AttributeDetails) Then
				Continue;
			EndIf;
		EndIf;
		
		If DetailsOfAttributes.AttributesToSkip.Find(AttributeDetails.Name) <> Undefined Then
			Continue;
		EndIf;
		If DetailsOfAttributes.DisabledAttributes.Find(AttributeDetails.Name) <> Undefined Then
			Continue;
		EndIf;
		If IsExcludedAttributeType(AttributeDetails, DetailsOfAttributes.ExcludedAttributeTypes) Then
			Continue;	
		EndIf;
		
		ChoiceFoldersAndItems = "";
		If TypeOf(AttributeDetails) = Type("StandardAttributeDescription") Then
			If AttributeDetails.Name = "Parent" Or AttributeDetails.Name = "Parent" Then
				ChoiceFoldersAndItems = "Groups";
			ElsIf AttributeDetails.Name = "Owner" Or AttributeDetails.Name = "Owner" Then
				If MetadataObject.SubordinationUse = Metadata.ObjectProperties.SubordinationUse.ToItems Then
					ChoiceFoldersAndItems = "Items";
				ElsIf MetadataObject.SubordinationUse = Metadata.ObjectProperties.SubordinationUse.ToFoldersAndItems Then
					ChoiceFoldersAndItems = "FoldersAndItems";
				ElsIf MetadataObject.SubordinationUse = Metadata.ObjectProperties.SubordinationUse.ToFolders Then
					ChoiceFoldersAndItems = "Groups";
				EndIf;
			EndIf;
		Else
			IsReference = False;
			
			For Each Type In AttributeDetails.Type.Types() Do
				If IsReference(Type) Then
					IsReference = True;
					Break;
				EndIf;
			EndDo;
			
			If IsReference Then
				If AttributeDetails.ChoiceFoldersAndItems = FoldersAndItemsUse.Folders Then
					ChoiceFoldersAndItems = "Groups";
				ElsIf AttributeDetails.ChoiceFoldersAndItems = FoldersAndItemsUse.FoldersAndItems Then
					ChoiceFoldersAndItems = "FoldersAndItems";
				ElsIf AttributeDetails.ChoiceFoldersAndItems = FoldersAndItemsUse.Items Then
					ChoiceFoldersAndItems = "Items";
				EndIf;
			EndIf;
		EndIf;
		
		KindsOfObjectsToChangeList = StrSplit(KindsOfObjectsToChange, ",", False);
		ChoiceParameterLinksPresentation = "";
		If KindsOfObjectsToChangeList.Count() = 1 Then
			ChoiceParametersString = ChoiceParametersAsString(AttributeDetails.ChoiceParameters);
			ChoiceParameterLinksString = ChoiceParameterLinksAsString(AttributeDetails.ChoiceParameterLinks);
			ChoiceParameterLinksPresentation = ChoiceParameterLinksPresentation(AttributeDetails.ChoiceParameterLinks, MetadataObject);
		Else
			ChoiceParametersString = ChoiceParametersAsString(New Array);
			ChoiceParameterLinksString = ChoiceParameterLinksAsString(New Array);
		EndIf;
		
		ObjectAttribute = ObjectAttributes.Add();
		ObjectAttribute.Name = AttributeDetails.Name;
		ObjectAttribute.Presentation = AttributeDetails.Presentation();
		
		ObjectAttribute.AllowedTypes = AttributeDetails.Type;
		ObjectAttribute.ChoiceParameters = ChoiceParametersString;
		ObjectAttribute.ChoiceParameterLinks = ChoiceParameterLinksString;
		ObjectAttribute.ChoiceParameterLinksPresentation = ChoiceParameterLinksPresentation;
		ObjectAttribute.ChoiceFoldersAndItems = ChoiceFoldersAndItems;
		ObjectAttribute.OperationKind = 1;
		
		If DetailsOfAttributes.LockedAttributes.Find(AttributeDetails.Name) <> Undefined Then
			ObjectAttribute.LockedAttribute = True;
		EndIf;
		
		ObjectAttribute.IsStandardAttribute = TypeOf(AttributeDetails) = Type("StandardAttributeDescription");
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AddExternalAttributesToSet(AttributesSets, KindsOfObjectsToChangeList)
	
	ModuleUsersInternal = CommonModule("UsersInternal");
	If ModuleUsersInternal = Undefined
	 Or Not SSLVersionMatchesRequirements Then
		Return;
	EndIf;
	
	ExternalAttributes = New Array; // Array of
	ModuleUsersInternal.OnFillExternalAttributes(KindsOfObjectsToChangeList, ExternalAttributes);
	
	For Each ExternalAttribute In ExternalAttributes Do
		If Not Object.ShowInternalAttributes
		   And ExternalAttribute.IsInternal Then
			Continue;
		EndIf;
		AttributeDetails = ObjectAttributes.Add();
		AttributeDetails.OperationKind = 4;
		AttributeDetails.Name = ExternalAttribute.Name;
		AttributeDetails.Presentation = ExternalAttribute.Presentation;
		AttributeDetails.AllowedTypes = ExternalAttribute.ValueType;
	EndDo;
	
	ObjectAttributes.Sort("Presentation");
	
EndProcedure

&AtServer
Function IsExcludedAttributeType(AttributeDetails, ExcludedAttributeTypes)

	If ExcludedAttributeTypes = Undefined Then
		Return False;
	EndIf;

	Result = False;
	For Each AttributeType In AttributeDetails.Type.Types() Do
		If ExcludedAttributeTypes[AttributeType] = True Then 
			Result = True;
			Continue;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

&AtServer
Function FilterAttributes()

	Result = New ValueTable;
	Result.Columns.Add("ObjectType", New TypeDescription("String", New StringQualifiers(80)));
	Result.Columns.Add("Attribute", New TypeDescription("String", New StringQualifiers(80)));
	
	// All objects.
	Filter = Result.Add();
	Filter.ObjectType = "*";
	Filter.Attribute = "Description";

	Filter = Result.Add();
	Filter.ObjectType = "*";
	Filter.Attribute = "DeletionMark";

	Filter = Result.Add();
	Filter.ObjectType = "*";
	Filter.Attribute = "Ref";

	Filter = Result.Add();
	Filter.ObjectType = "*";
	Filter.Attribute = "AdditionalAttributes.*";

	Filter = Result.Add();
	Filter.ObjectType = "*";
	Filter.Attribute = "ContactInformation.*";

	// Catalogs.
	Filter = Result.Add();
	Filter.ObjectType = "Catalogs";
	Filter.Attribute = "PredefinedDataName";

	Filter = Result.Add();
	Filter.ObjectType = "Catalogs";
	Filter.Attribute = "Code";

	Filter = Result.Add();
	Filter.ObjectType = "Catalogs";
	Filter.Attribute = "Predefined";

	Filter = Result.Add();
	Filter.ObjectType = "Catalogs";
	Filter.Attribute = "IsFolder";

	Filter = Result.Add();
	Filter.ObjectType = "Catalogs";
	Filter.Attribute = "AddlOrderingAttribute";
	
	// Documents.
	Filter = Result.Add();
	Filter.ObjectType = "Documents";
	Filter.Attribute = "Number";

	Filter = Result.Add();
	Filter.ObjectType = "Documents";
	Filter.Attribute = "Posted";
	
	// Charts of characteristic types.
	Filter = Result.Add();
	Filter.ObjectType = "ChartsOfCharacteristicTypes";
	Filter.Attribute = "PredefinedDataName";
	
	Filter = Result.Add();
	Filter.ObjectType = "ChartsOfCharacteristicTypes";
	Filter.Attribute = "Code";
	
	Filter = Result.Add();
	Filter.ObjectType = "ChartsOfCharacteristicTypes";
	Filter.Attribute = "Predefined";
	
	Filter = Result.Add();
	Filter.ObjectType = "ChartsOfCharacteristicTypes";
	Filter.Attribute = "IsFolder";
	
	Filter = Result.Add();
	Filter.ObjectType = "ChartsOfCharacteristicTypes";
	Filter.Attribute = "ValueType";
	
	// Charts of accounts.
	Filter = Result.Add();
	Filter.ObjectType = "ChartsOfAccounts";
	Filter.Attribute = "PredefinedDataName";

	Filter = Result.Add();
	Filter.ObjectType = "ChartsOfAccounts";
	Filter.Attribute = "Code";

	Filter = Result.Add();
	Filter.ObjectType = "ChartsOfAccounts";
	Filter.Attribute = "Predefined";

	Filter = Result.Add();
	Filter.ObjectType = "ChartsOfAccounts";
	Filter.Attribute = "Order";

	// Charts of calculation types.
	Filter = Result.Add();
	Filter.ObjectType = "ChartsOfCalculationTypes";
	Filter.Attribute = "PredefinedDataName";
	
	Filter = Result.Add();
	Filter.ObjectType = "ChartsOfCalculationTypes";
	Filter.Attribute = "Code";
	
	Filter = Result.Add();
	Filter.ObjectType = "ChartsOfCalculationTypes";
	Filter.Attribute = "Predefined";
	
	Filter = Result.Add();
	Filter.ObjectType = "ChartsOfCalculationTypes";
	Filter.Attribute = "ActionPeriodIsBasic";
	
	// Tasks.
	Filter = Result.Add();
	Filter.ObjectType = "Tasks";
	Filter.Attribute = "Number";
	
	// Business processes.
	Filter = Result.Add();
	Filter.ObjectType = "BusinessProcesses";
	Filter.Attribute = "Number";

	Filter = Result.Add();
	Filter.ObjectType = "BusinessProcesses";
	Filter.Attribute = "Date";
	
	// Exchange plans.
	Filter = Result.Add();
	Filter.ObjectType = "ExchangePlans";
	Filter.Attribute = "Code";
	
	Filter = Result.Add();
	Filter.ObjectType = "ExchangePlans";
	Filter.Attribute = "SentNo";
	
	Filter = Result.Add();
	Filter.ObjectType = "ExchangePlans";
	Filter.Attribute = "ReceivedNo";
	
	Result.Indexes.Add("ObjectType");
	
	Return Result;
EndFunction
	
// Parameters:
//   MetadataObject - MetadataObject
// 
// Returns:
//   Map
//
&AtServer
Function EditFilterByType(MetadataObject)
	
	FilterTable1 = FilterAttributes();
	
	// Attributes lockable for any metadata object type.
	CommonFilter = FilterTable1.FindRows(New Structure("ObjectType", "*"));
	
	// Attributes lockable for the specified metadata object type.
	FilterByObjectType = FilterTable1.FindRows(New Structure("ObjectType", 
		BaseTypeNameByMetadataObject(MetadataObject)));
	
	DisabledAttributes = New Map;
	
	For Each RowDescription1 In CommonFilter Do
		DisabledAttributes[RowDescription1.Attribute] = True;
	EndDo;
	
	For Each RowDescription1 In FilterByObjectType Do
		DisabledAttributes[RowDescription1.Attribute] = True;
	EndDo;
	
	AttributesBeingDeletedPrefix = "Delete";
	AttributesDetails1 = MetadataObject.Attributes; // Array of MetadataObjectAttribute
	For Each Attribute In AttributesDetails1 Do
		If Lower(Left(Attribute.Name, StrLen(AttributesBeingDeletedPrefix))) = Lower(AttributesBeingDeletedPrefix) Then
			DisabledAttributes[Attribute.Name] = True;
		EndIf;
	EndDo;
	For Each TabularSection In MetadataObject.TabularSections Do
		If Lower(Left(TabularSection.Name, StrLen(AttributesBeingDeletedPrefix))) = Lower(AttributesBeingDeletedPrefix) Then
			DisabledAttributes[TabularSection.Name + ".*"] = True;
		Else
			TabularSectionAttributesDetails = TabularSection.Attributes; // Array of MetadataObjectAttribute
			For Each Attribute In TabularSectionAttributesDetails Do
				If Lower(Left(Attribute.Name, StrLen(AttributesBeingDeletedPrefix))) = Lower(AttributesBeingDeletedPrefix) Then
					DisabledAttributes[TabularSection.Name + "." + Attribute.Name] = True;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	Return DisabledAttributes;
	
EndFunction

&AtServer
Function FilterItemsNoHierarchy(Val FilterItems1)
	Result = New Array;
	For Each FilterElement In FilterItems1 Do
		If TypeOf(FilterElement) = Type("DataCompositionFilterItemGroup") Then
			SubordinateFilters = FilterItemsNoHierarchy(FilterElement.Items);
			For Each SubordinateFilter In SubordinateFilters Do
				Result.Add(SubordinateFilter);
			EndDo;
		Else
			Result.Add(FilterElement);
		EndIf;
	EndDo;
	Return Result;
EndFunction

&AtServer
Procedure GenerateNoteOnConfiguredChanges()
	
	FilterByRowsAvailable = False;
	For Each FilterElement In FilterItemsNoHierarchy(SettingsComposer.Settings.Filter.Items) Do
		If Not FilterElement.Use Then
			Continue;
		EndIf;
		For Each TabularSection In ObjectTabularSections Do
			TabularSectionName = Mid(TabularSection.Value, StrLen("TabularSection") + 1);
			If StrStartsWith(FilterElement.LeftValue, TabularSectionName) Then
				FilterByRowsAvailable = True;
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	TabularSectionsToChange = New Map;
	For Each TabularSection In ObjectTabularSections Do
		AttributesToChange = New Array;
		For Each Attribute In ThisObject[TabularSection.Value] Do
			If Attribute.Change Then
				AttributesToChange.Add(Attribute.Presentation);
			EndIf;
		EndDo;
		If AttributesToChange.Count() > 0 Then 
			TabularSectionsToChange.Insert(TabularSection.Presentation, AttributesToChange);
		EndIf;
	EndDo;
	
	AttributesToChange = New Array;
	For Each Attribute In ObjectAttributes Do
		If Attribute.Change Then
			AttributesToChange.Add(Attribute.Presentation);
		EndIf;
	EndDo;
	
	If Not SelectedObjectsAvailable() Then
		Explanation = NStr("en = 'No items selected.';");
	Else
		If AttributesToChange.Count() = 1 Then
			NoteTemplate = NStr("en = 'Change the %1 attribute for the selected items';") // Example: "Update attribute ""Warehouse""..."
		ElsIf AttributesToChange.Count() > 3 Then
			NoteTemplate = NStr("en = 'Change attributes (%1) for the selected items';"); // Example: "Update attributes (5)..."
		ElsIf AttributesToChange.Count() > 1 Then
			NoteTemplate = NStr("en = 'Change the %1 attributes for the selected items';"); // Example: "Update attributes ""Warehouse"", ""Office""..."
		Else	
			NoteTemplate = "";
		EndIf;
		
		If AttributesToChange.Count() > 3 Then
			Explanation = SubstituteParametersToString(NoteTemplate, AttributesToChange.Count());
		ElsIf AttributesToChange.Count() > 0 Then
			Explanation = SubstituteParametersToString(NoteTemplate, AttributesNames(AttributesToChange));
		Else
			Explanation = "";
		EndIf;
		
		For Each TabularSection In TabularSectionsToChange Do
			
			AttributesToChange = TabularSection.Value;
			If AttributesToChange.Count() = 0 Then
				Continue;
			EndIf;
			
			If AttributesToChange.Count() = 1 Then
				NoteTemplate = ?(IsBlankString(Explanation),
					NStr("en = 'Change the %1 attribute in table ""%2""';"),
					NStr("en = 'the %1 attribute in table ""%2""';")); 
			ElsIf AttributesToChange.Count() > 3 Then
				NoteTemplate = ?(IsBlankString(Explanation),
					NStr("en = 'Change attributes (%1) in table ""%2""';"),
					NStr("en = '%1 attributes in table ""%2""';")); 
			Else 
				NoteTemplate = ?(IsBlankString(Explanation),
					NStr("en = 'Change the %1 attributes in table ""%2""';"),
					NStr("en = 'the %1 attributes in table ""%2""';")); 
			EndIf;
			
			If Not IsBlankString(Explanation) Then
				Explanation = Explanation + ", ";
			EndIf;
			If AttributesToChange.Count() > 3 Then
				Explanation = Explanation + SubstituteParametersToString(NoteTemplate, 
					AttributesToChange.Count(), TabularSection.Key);
			Else
				Explanation = Explanation + SubstituteParametersToString(NoteTemplate, 
					AttributesNames(AttributesToChange), TabularSection.Key);
			EndIf;
		EndDo;
		
		If Not IsBlankString(Explanation) Then
			Explanation = Explanation + ".";
			If TabularSectionsToChange.Count() > 0 Then
				If FilterByRowsAvailable Then 
					Explanation = Explanation + " " + SubstituteParametersToString(NStr(
						"en = 'Apply the changes only to the lines of the selected items that match the <a href = ""%1"">filter</a>.';"),
						"GoToFilterSettings");
				Else
					Explanation = Explanation + " " + SubstituteParametersToString(NStr(
						"en = 'Apply the changes <a href = ""%1"">to all lines</a> of the selected items.';"),
						"GoToFilterSettings");
				EndIf;
			EndIf;
		Else
			Explanation = NStr("en = '<b>Overwrite</b> the selected items.';");
		EndIf;
	EndIf;
	
	Items.NoteOnConfiguredChanges.Title = FormattedString(Explanation);
	If IsBlankString(AlgorithmCode) Then
		AlgorithmCode = SubstituteParametersToString(NStr("en = '// Available variables:
		|// %1 - an object to be processed.';"), "Object") + Chars.LF;
	EndIf;
	
EndProcedure

&AtServer
Function AttributesNames(Val AttributesToChange)
	
	AttributesNames = "";
	For Each Attribute In AttributesToChange Do
		If Not IsBlankString(AttributesNames) Then
			AttributesNames = AttributesNames + ", ";
		EndIf;
		AttributesNames = AttributesNames + """" + Attribute + """";
	EndDo;
	Return AttributesNames;

EndFunction

&AtServer
Function SelectedObjectsAvailable()
	Filter_Settings = Filter_Settings();
	Filter_Settings.RestrictSelection = True;
	Return SelectedObjects(Filter_Settings).Rows.Count() > 0;
EndFunction

&AtServer
Procedure UpdateSelectedCountLabel()
	
	If AvailableConfiguredFilters() Then
		ErrorMessageText = "";
		SelectedObjectsCount = SelectedObjectsCount(True, , ErrorMessageText);
		LabelText = StringWithNumberForAnyLanguage(NStr("en = ';%1 item;;;;%1 items';"),
			SelectedObjectsCount);
	Else
		LabelText = NStr("en = 'All items';");
	EndIf;
	
	Items.FilterSettings.Title = LabelText;
EndProcedure

&AtServer
Procedure FillPreviouslyChangedAttributesSubmenu()
	
	CommandLocation = Items.PreviouslyChangedAttributes;
	
	ItemsToRemove = New Array;
	For Each Setting In CommandLocation.ChildItems Do
		If Setting.Name = "Stub" Then
			Continue;
		EndIf;
		ItemsToRemove.Add(Setting);
	EndDo;
	
	For Each Setting In ItemsToRemove Do
		Commands.Delete(Commands[Setting.Name]);
		Items.Delete(Setting);
	EndDo;
	
	For Each Setting In OperationsHistoryList Do
		CommandNumber = OperationsHistoryList.IndexOf(Setting);
		CommandName = CommandLocation.Name + "ChangesSetting" + CommandNumber;
		
		FormCommand = Commands.Add(CommandName);
		FormCommand.Action = "Attachable_EnableSetting";
		FormCommand.Title = Setting.Presentation;
		FormCommand.ModifiesStoredData = False;
		
		NewItem = Items.Add(CommandName, Type("FormButton"), CommandLocation);
		NewItem.Type = FormButtonType.CommandBarButton;
		NewItem.CommandName = CommandName;
	EndDo;
	
	Items.Stub.Visible = OperationsHistoryList.Count() = 0;
	
	If Not ContextCall Then
		FillAlgorithmsListSubmenu();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAlgorithmsListSubmenu()
	CommandLocation = Items.Algorithms;
	
	ItemsToRemove = New Array;
	For Each Setting In CommandLocation.ChildItems Do
		If Setting.Name = "StubAlgorythms" Then
			Continue;
		EndIf;
		ItemsToRemove.Add(Setting);
	EndDo;
	
	For Each Setting In ItemsToRemove Do
		Commands.Delete(Commands[Setting.Name]);
		Items.Delete(Setting);
	EndDo;
	
	For Each Setting In AlgorithmsHistoryList Do
		CommandNumber = AlgorithmsHistoryList.IndexOf(Setting);
		CommandName = CommandLocation.Name + "ChangesSetting" + CommandNumber;
		
		FormCommand = Commands.Add(CommandName);
		FormCommand.Action = "Attachable_EnableSetting";
		FormCommand.Title = Setting.Presentation;
		FormCommand.ModifiesStoredData = False;
		
		NewItem = Items.Add(CommandName, Type("FormButton"), CommandLocation);
		NewItem.Type = FormButtonType.CommandBarButton;
		NewItem.CommandName = CommandName;
	EndDo;
	
	Items.StubAlgorythms.Visible = AlgorithmsHistoryList.Count() = 0;
EndProcedure

&AtClient
Procedure SetChangeSetting(Val Setting)
	
	ResetChangeSettings();
	
	LockedAttributesAvailable = False;
	
	// For backward compatibility with settings saved in SSL 2.1.
	If TypeOf(Setting) <> Type("Structure") Then
		Setting = New Structure("Attributes,TabularSections", Setting, New Structure);
	EndIf;
	
	For Each AttributeToChange In Setting.Attributes Do
		TheStructureOfTheSearch = New Structure;
		TheStructureOfTheSearch.Insert("OperationKind", AttributeToChange.OperationKind);
		If AttributeToChange.OperationKind = 1 Then // Object attribute.
			TheStructureOfTheSearch.Insert("Name", AttributeToChange.AttributeName);
		Else
			TheStructureOfTheSearch.Insert("Property", AttributeToChange.Property);
		EndIf;
		
		FoundRows = ObjectAttributes.FindRows(TheStructureOfTheSearch);
		If FoundRows.Count() > 0 Then
			If FoundRows[0].LockedAttribute  Then
				LockedAttributesAvailable = True;
				Continue;
			EndIf;
			FoundRows[0].Value = AttributeToChange.Value;
			FoundRows[0].Change = True;
		EndIf;
	EndDo;
	
	For Each TabularSection In Setting.TabularSections Do
		For Each AttributeToChange In TabularSection.Value Do
			TheStructureOfTheSearch = New Structure;
			TheStructureOfTheSearch.Insert("Name", AttributeToChange.Name);
			If Items.Find("TabularSection" + TabularSection.Key) <> Undefined Then
				FoundRows = ThisObject["TabularSection" + TabularSection.Key].FindRows(TheStructureOfTheSearch);
				If FoundRows.Count() > 0 Then
					FoundRows[0].Value = AttributeToChange.Value;
					FoundRows[0].Change = True;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	If LockedAttributesAvailable Then
		ShowMessageBox(, NStr("en = 'Some attributes are locked for editing. Changes are not saved.';"));
	EndIf;
	
	UpdateCountersOfAttributesToChange();
EndProcedure

&AtServer
Function ChoiceParametersAsString(ChoiceParameters)
	Result = "";
	
	For Each ChoiceParameterDescription In ChoiceParameters Do
		CurrentCPString = "[FilterField];[StringType];[StringValue1]";
		ValueType = TypeOf(ChoiceParameterDescription.Value);
		
		If ValueType = Type("FixedArray") Then
			TypePresentationString = "FixedArray";
			StringValue1 = "";
			
			For Each Item In ChoiceParameterDescription.Value Do
				ValueStringPattern = "[Type]*[Value]";
				ValueStringPattern = StrReplace(ValueStringPattern, "[Type]", TypePresentationString(TypeOf(Item)));
				ValueStringPattern = StrReplace(ValueStringPattern, "[Value]", XMLString(Item));
				StringValue1 = StringValue1 + ?(IsBlankString(StringValue1), "", "#") + ValueStringPattern;
			EndDo;
		Else
			TypePresentationString = TypePresentationString(ValueType);
			StringValue1 = XMLString(ChoiceParameterDescription.Value);
		EndIf;
		
		If Not IsBlankString(StringValue1) Then
			CurrentCPString = StrReplace(CurrentCPString, "[FilterField]", ChoiceParameterDescription.Name);
			CurrentCPString = StrReplace(CurrentCPString, "[StringType]", TypePresentationString);
			CurrentCPString = StrReplace(CurrentCPString, "[StringValue1]", StringValue1);
			
			Result = Result + CurrentCPString + Chars.LF;
		EndIf;
	EndDo;
	
	Result = Left(Result, StrLen(Result)-1);
	Return Result;
EndFunction

&AtServer
Function ChoiceParameterLinksAsString(ChoiceParameterLinks)
	Result = "";
	
	For Each ChoiceParameterLinkDescription In ChoiceParameterLinks Do
		CurrentCPLString = "[ParameterName];[AttributeName]";
		CurrentCPLString = StrReplace(CurrentCPLString, "[ParameterName]", ChoiceParameterLinkDescription.Name);
		CurrentCPLString = StrReplace(CurrentCPLString, "[AttributeName]", ChoiceParameterLinkDescription.DataPath);
		Result = Result + CurrentCPLString + Chars.LF;
	EndDo;
	
	Result = Left(Result, StrLen(Result)-1);
	Return Result;
EndFunction

&AtServer
Function ChoiceParameterLinksPresentation(ChoiceParameterLinks, MetadataObject)
	Result = "";
	
	LinkedAttributes = New Array;
	For Each ChoiceParameterLinkDescription In ChoiceParameterLinks Do
		AttributeName = ChoiceParameterLinkDescription.DataPath;
		TabularSectionPresentation = "";
		AttributesOwner = MetadataObject;
		NameParts = StrSplit(AttributeName, ".", True);
		If NameParts.Count() = 2 Then
			AttributeName = NameParts[1];
			TabularSectionName = NameParts[0];
			AttributesOwner = MetadataObject.TabularSections.Find(TabularSectionName);
			If AttributesOwner <> Undefined Then
				TabularSectionPresentation = AttributesOwner.Presentation();
			EndIf;
		EndIf;
		If AttributesOwner <> Undefined Then
			Attribute = AttributesOwner.Attributes.Find(AttributeName);
			If Attribute = Undefined Then
				StandardAttributesDetails = AttributesOwner.StandardAttributes;// StandardAttributeDescriptions
				For Each StandardAttribute In StandardAttributesDetails Do
					If StandardAttribute.Name = AttributeName Then
						Attribute = StandardAttribute;
						Break;
					EndIf;
				EndDo;
			EndIf;
			If Attribute <> Undefined Then
				AttributeRepresentation = Attribute.Presentation();
				If Not IsBlankString(TabularSectionPresentation) Then
					AttributeRepresentation = AttributeRepresentation + " (" + NStr("en = 'table';") + " " 
						+ TabularSectionPresentation + ")";
				EndIf;
				LinkedAttributes.Add(AttributeRepresentation);
			EndIf;
		EndIf;
	EndDo;
	
	If LinkedAttributes.Count() > 0 Then
		LinkPresentationPattern = NStr("en = 'Dependency to attributes: %1.';");
		If LinkedAttributes.Count() = 1 Then
			LinkPresentationPattern = NStr("en = 'Depends on the %1 attribute.';");
		EndIf;
		Result = SubstituteParametersToString(LinkPresentationPattern, StrConcat(LinkedAttributes, ", "));
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Procedure FillObjectsTypesList()
	Items.PresentationOfObjectsToChange.ChoiceList.Clear();
	DataProcessorObject = FormAttributeToValue("Object");
	DataProcessorObject.FillEditableObjectsCollection(
		Items.PresentationOfObjectsToChange.ChoiceList, Object.ShowInternalAttributes);
EndProcedure

&AtClient
Procedure NoteOnConfiguredChangesURLProcessing(Item, FormattedStringURL, StandardProcessing)
	If FormattedStringURL = "GoToFilterSettings" Then
		StandardProcessing = False;
		GoToFilterSettings();
	EndIf;
EndProcedure

&AtClient
Procedure GoToFilterSettings()
	If Not IsBlankString(KindsOfObjectsToChange) Then
		NotifyDescription = New NotifyDescription("OnCloseSelectedObjectsForm", ThisObject);
		OpenForm(FullFormName("SelectedItems"), 
			New Structure("SelectedTypes, Settings", KindsOfObjectsToChange, SettingsComposer.Settings), , , , , NotifyDescription);
	EndIf;
EndProcedure

&AtClient
Function ComposerParameters(Formula)
	Result = New Structure;
	Result.Insert("Formula", Formula);
	Result.Insert("OperandsTitle", NStr("en = 'Available attributes';"));
	Result.Insert("Operands", Operands());
	Result.Insert("Advanced", False);
	Return Result;
EndFunction

&AtServer
Function Operands()
	OperandsTable = New ValueTable;
	OperandsTable.Columns.Add("Id");
	OperandsTable.Columns.Add("Presentation");
	
	For Each AttributeDetails In ObjectAttributes Do
		Operand = OperandsTable.Add();
		Operand.Id = AttributeDetails.Presentation;
	EndDo;
	
	Return PutToTempStorage(OperandsTable, UUID);
EndFunction

&AtClient
Function ExpressionHasErrors(Val Expression, ErrorText = "")
	
	Expression = Mid(Expression, 2);
	
	For Each AttributeDetails In ObjectAttributes Do
		Expression = StrReplace(Expression, "[" + AttributeDetails.Presentation + "]", """1""");
	EndDo;
	
	Try
		Return Eval(Expression) = Undefined;
	Except
		ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		Return True;
	EndTry;
	
EndFunction

&AtClient
Procedure OnUnlockAttributes(UnlockedAttributes, AdditionalParameters) Export
	
	If UnlockedAttributes = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(UnlockedAttributes) = Type("Array") And UnlockedAttributes.Count() > 0 Then
		Filter = New Structure("LockedAttribute", True);
		LockedAttributesRows = ObjectAttributes.FindRows(Filter);
		For Each OperationDescriptionString In LockedAttributesRows Do
			If OperationDescriptionString.LockedAttribute
			   And UnlockedAttributes.Find(OperationDescriptionString.Name) <> Undefined Then
				OperationDescriptionString.LockedAttribute = False;
			EndIf;
		EndDo;
		
	ElsIf UnlockedAttributes = True Then
	
		For Each OperationDescriptionString In LockedAttributesRows Do
			OperationDescriptionString.LockedAttribute = False;
		EndDo;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Base-functionality procedures and functions for standalone mode support.

// Saves a setting to the common settings storage.
// 
// Parameters:
//   As for the CommonSettingsStorageSave.Save method, 
//   see StorageSave() parameters.
// 
&AtServerNoContext
Procedure CommonSettingsStorageSave(ObjectKey, SettingsKey, Value,
	SettingsDescription = Undefined, UserName = Undefined, 
	NeedToRefreshCachedValues = False)
	
	StorageSave(
		CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		Value,
		SettingsDescription,
		UserName,
		NeedToRefreshCachedValues);
	
EndProcedure

// Loads settings from the common settings storage.
//
// Parameters:
//   As for the CommonSettingsStorage.Load method,
//   see StorageLoad() parameters.
//
&AtServerNoContext
Function CommonSettingsStorageLoad(ObjectKey, SettingsKey, DefaultValue = Undefined, 
	SettingsDescription = Undefined, UserName = Undefined)
	
	Return StorageLoad(
		CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDescription,
		UserName);
	
EndFunction

&AtServerNoContext
Procedure StorageSave(StorageManager, ObjectKey, SettingsKey, Value,
	SettingsDescription, UserName, NeedToRefreshCachedValues)
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	StorageManager.Save(ObjectKey, SettingsKey(SettingsKey), Value, SettingsDescription, UserName);
	
	If NeedToRefreshCachedValues Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

&AtServerNoContext
Function StorageLoad(StorageManager, ObjectKey, SettingsKey, DefaultValue,
	SettingsDescription, UserName)
	
	Result = Undefined;
	
	If AccessRight("SaveUserData", Metadata) Then
		Result = StorageManager.Load(ObjectKey, SettingsKey(SettingsKey), SettingsDescription, UserName);
	EndIf;
	
	If (Result = Undefined) And (DefaultValue <> Undefined) Then
		Result = DefaultValue;
	EndIf;

	Return Result;
	
EndFunction

// Returns a settings key string within a valid length.
// Checks the length of the passed string. If it exceeds 128, converts its end according to the MD5 algorithm into a short
// alternative. As the result, string becomes 128 character length.
// If the original string is less then 128 characters, it is returned as is.
//
// Parameters:
//  String - String - string of any number of characters.
//
&AtServerNoContext
Function SettingsKey(Val String)
	Result = String;
	If StrLen(String) > 128 Then // A key longer than 128 characters raises an exception when accessing the settings storage.
		Result = Left(String, 96);
		DataHashing = New DataHashing(HashFunction.MD5);
		DataHashing.Append(Mid(String, 97));
		Result = Result + StrReplace(DataHashing.HashSum, " ", "");
	EndIf;
	Return Result;
EndFunction

// Returns an object manager by the passed full name of a metadata object.
//
// Does not regard business process route points.
//
// Parameters:
//  FullName    - String - full name of the metadata object,
//                 for example, "Catalog.Companies".
//
// Returns:
//  CatalogManager, DocumentManager, DataProcessorManager, InformationRegisterManager - an object manager.
//
&AtServerNoContext
Function ObjectManagerByFullName(FullName)
	Var MOClass, MetadataObjectName1, Manager;
	
	NameParts = StrSplit(FullName, ".");
	
	If NameParts.Count() = 2 Then
		MOClass = NameParts[0];
		MetadataObjectName1  = NameParts[1];
	EndIf;
	
	If      Upper(MOClass) = "EXCHANGEPLAN" Then
		Manager = ExchangePlans;
		
	ElsIf Upper(MOClass) = "CATALOG" Then
		Manager = Catalogs;
		
	ElsIf Upper(MOClass) = "DOCUMENT" Then
		Manager = Documents;
		
	ElsIf Upper(MOClass) = "DOCUMENTJOURNAL" Then
		Manager = DocumentJournals;
		
	ElsIf Upper(MOClass) = "ENUM" Then
		Manager = Enums;
		
	ElsIf Upper(MOClass) = "REPORT" Then
		Manager = Reports;
		
	ElsIf Upper(MOClass) = "DATAPROCESSOR" Then
		Manager = DataProcessors;
		
	ElsIf Upper(MOClass) = "CHARTOFCHARACTERISTICTYPES" Then
		Manager = ChartsOfCharacteristicTypes;
		
	ElsIf Upper(MOClass) = "CHARTOFACCOUNTS" Then
		Manager = ChartsOfAccounts;
		
	ElsIf Upper(MOClass) = "CHARTOFCALCULATIONTYPES" Then
		Manager = ChartsOfCalculationTypes;
		
	ElsIf Upper(MOClass) = "INFORMATIONREGISTER" Then
		Manager = InformationRegisters;
		
	ElsIf Upper(MOClass) = "ACCUMULATIONREGISTER" Then
		Manager = AccumulationRegisters;
		
	ElsIf Upper(MOClass) = "ACCOUNTINGREGISTER" Then
		Manager = AccountingRegisters;
		
	ElsIf Upper(MOClass) = "CALCULATIONREGISTER" Then
		If NameParts.Count() = 2 Then
			// Calculation register.
			Manager = CalculationRegisters;
		Else
			SubordinateMOClass = NameParts[2];
			If Upper(SubordinateMOClass) = "RECALCULATION" Then
				// Recalculate.
				Manager = CalculationRegisters[MetadataObjectName1].Recalculations;
			Else
				Raise SubstituteParametersToString(NStr("en = 'Unknown metadata object type: %1.';"), FullName);
			EndIf;
		EndIf;
		
	ElsIf Upper(MOClass) = "BUSINESSPROCESS" Then
		Manager = BusinessProcesses;
		
	ElsIf Upper(MOClass) = "TASK" Then
		Manager = Tasks;
		
	ElsIf Upper(MOClass) = "CONSTANT" Then
		Manager = Constants;
		
	ElsIf Upper(MOClass) = "SEQUENCE" Then
		Manager = Sequences;
	EndIf;
	
	If Manager <> Undefined Then
		Try
			Return Manager[MetadataObjectName1];
		Except
			Manager = Undefined;
		EndTry;
	EndIf;
	
	Raise SubstituteParametersToString(NStr("en = 'Unknown metadata object type: %1.';"), FullName);
	
EndFunction

&AtClientAtServerNoContext
Function SubstituteParametersToString(Val SubstitutionString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	SubstitutionString = StrReplace(SubstitutionString, "%1", Parameter1);
	SubstitutionString = StrReplace(SubstitutionString, "%2", Parameter2);
	SubstitutionString = StrReplace(SubstitutionString, "%3", Parameter3);
	
	Return SubstitutionString;
EndFunction

// Returns the name of a kind
// for a referenced metadata object.
//
// Does not regard business process route points.
//
// Parameters:
//  Ref       - AnyRef - catalog item, document, etc.
//
// Returns:
//  String       - Metadata object kind name. For example, Catalog or Document.
//
&AtServerNoContext
Function ObjectKindByRef(Ref)
	
	Return ObjectKindByType(TypeOf(Ref));
	
EndFunction 

// Returns the name of a kind for a metadata object of a specific type.
//
// Does not regard business process route points.
//
// Parameters:
//  ObjectType - Type - an applied object type defined in the configuration.
//
// Returns:
//  String       - Metadata object kind name. For example, Catalog or Document.
// 
&AtServerNoContext
Function ObjectKindByType(Type)
	
	If Catalogs.AllRefsType().ContainsType(Type) Then
		Return "Catalog";
	
	ElsIf Documents.AllRefsType().ContainsType(Type) Then
		Return "Document";
	
	ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
		Return "BusinessProcess";
	
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCharacteristicTypes";
	
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
		Return "ChartOfAccounts";
	
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCalculationTypes";
	
	ElsIf Tasks.AllRefsType().ContainsType(Type) Then
		Return "Task";
	
	ElsIf ExchangePlans.AllRefsType().ContainsType(Type) Then
		Return "ExchangePlan";
	
	ElsIf Enums.AllRefsType().ContainsType(Type) Then
		Return "Enum";
	
	Else
		Raise SubstituteParametersToString(NStr("en = 'Invalid parameter value type: %1.';"), String(Type));
	
	EndIf;
	
EndFunction 

// Checks whether the object is an item group.
//
// Parameters:
//  Object - CatalogObject
//         - DocumentObject
//         - AnyRef
//         - FormDataStructure
//
// Returns:
//  Boolean
//
&AtServerNoContext
Function ObjectIsFolder(Object)
	
	If RefTypeValue(Object) Then
		Ref = Object;
	Else
		Ref = Object.Ref;
	EndIf;
	
	ObjectMetadata = Ref.Metadata();
	
	If IsCatalog(ObjectMetadata) Then
		
		If Not ObjectMetadata.Hierarchical
		 Or ObjectMetadata.HierarchyType
		     <> Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
			
			Return False;
		EndIf;
		
	ElsIf Not IsChartOfCharacteristicTypes(ObjectMetadata) Then
		Return False;
		
	ElsIf Not ObjectMetadata.Hierarchical Then
		Return False;
	EndIf;
	
	If Ref <> Object Then
		Return Object.IsFolder;
	EndIf;
	
	Return ObjectAttributeValue(Ref, "IsFolder");
	
EndFunction

// Checks whether the metadata object belongs to the Catalog common type.
//
// Parameters:
//  MetadataObject - MetadataObject - to be checked for having a specific type.
//
//  Returns:
//   Boolean
//
&AtServerNoContext
Function IsCatalog(MetadataObject)
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = CatalogsTypeName();
	
EndFunction

// Checking whether it's a reference data type.
//
&AtServerNoContext
Function IsReference(Type)
	
	Return Type <> Type("Undefined") 
		And (Catalogs.AllRefsType().ContainsType(Type)
		Or Documents.AllRefsType().ContainsType(Type)
		Or Enums.AllRefsType().ContainsType(Type)
		Or ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type)
		Or ChartsOfAccounts.AllRefsType().ContainsType(Type)
		Or ChartsOfCalculationTypes.AllRefsType().ContainsType(Type)
		Or BusinessProcesses.AllRefsType().ContainsType(Type)
		Or BusinessProcesses.RoutePointsAllRefsType().ContainsType(Type)
		Or Tasks.AllRefsType().ContainsType(Type)
		Or ExchangePlans.AllRefsType().ContainsType(Type));
	
EndFunction

// Checks whether the value is a reference type value.
//
// Parameters:
//  Value - Arbitrary - a value to check.
//
// Returns:
//  Boolean       - True if the value has a reference type.
//
&AtServerNoContext
Function RefTypeValue(Value)
	
	If Value = Undefined Then
		Return False;
	EndIf;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Documents.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Enums.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfCharacteristicTypes.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfAccounts.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfCalculationTypes.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If BusinessProcesses.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If BusinessProcesses.RoutePointsAllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Tasks.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ExchangePlans.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Checks whether the metadata object belongs to the Chart of Characteristic Types common type.
//
// Parameters:
//  MetadataObject - MetadataObject - to be checked for having a specific type.
//
//  Returns:
//   Boolean
//
&AtServerNoContext
Function IsChartOfCharacteristicTypes(MetadataObject)
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = ChartsOfCharacteristicTypesTypeName();
	
EndFunction

// Returns a base type name by the passed metadata object value.
//
// Parameters:
//  MetadataObject - MetadataObject - to use for identifying the base type.
// 
// Returns:
//  String - name of the base type for the passed metadata object value.
//
&AtServerNoContext
Function BaseTypeNameByMetadataObject(MetadataObject)
	
	If Metadata.Documents.Contains(MetadataObject) Then
		Return DocumentsTypeName();
		
	ElsIf Metadata.Catalogs.Contains(MetadataObject) Then
		Return CatalogsTypeName();
		
	ElsIf Metadata.Enums.Contains(MetadataObject) Then
		Return EnumsTypeName();
		
	ElsIf Metadata.InformationRegisters.Contains(MetadataObject) Then
		Return InformationRegistersTypeName();
		
	ElsIf Metadata.AccumulationRegisters.Contains(MetadataObject) Then
		Return AccumulationRegistersTypeName();
		
	ElsIf Metadata.AccountingRegisters.Contains(MetadataObject) Then
		Return AccountingRegistersTypeName();
		
	ElsIf Metadata.CalculationRegisters.Contains(MetadataObject) Then
		Return CalculationRegistersTypeName();
		
	ElsIf Metadata.ExchangePlans.Contains(MetadataObject) Then
		Return ExchangePlansTypeName();
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject) Then
		Return ChartsOfCharacteristicTypesTypeName();
		
	ElsIf Metadata.BusinessProcesses.Contains(MetadataObject) Then
		Return BusinessProcessesTypeName();
		
	ElsIf Metadata.Tasks.Contains(MetadataObject) Then
		Return TasksTypeName();
		
	ElsIf Metadata.ChartsOfAccounts.Contains(MetadataObject) Then
		Return ChartsOfAccountsTypeName();
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(MetadataObject) Then
		Return ChartsOfCalculationTypesTypeName();
		
	ElsIf Metadata.Constants.Contains(MetadataObject) Then
		Return ConstantsTypeName();
		
	ElsIf Metadata.DocumentJournals.Contains(MetadataObject) Then
		Return DocumentJournalsTypeName();
		
	ElsIf Metadata.Sequences.Contains(MetadataObject) Then
		Return SequencesTypeName();
		
	ElsIf Metadata.ScheduledJobs.Contains(MetadataObject) Then
		Return ScheduledJobsTypeName();
		
	Else
		
		Return "";
		
	EndIf;
	
EndFunction

// Returns a value for identification of the Information registers type.
//
// Returns:
//  String
//
&AtServerNoContext
Function InformationRegistersTypeName()
	
	Return "InformationRegisters";
	
EndFunction

// Returns a value for identification of the Accumulation registers type.
//
// Returns:
//  String
//
&AtServerNoContext
Function AccumulationRegistersTypeName()
	
	Return "AccumulationRegisters";
	
EndFunction

// Returns a value for identification of the Accounting registers type.
//
// Returns:
//  String
//
&AtServerNoContext
Function AccountingRegistersTypeName()
	
	Return "AccountingRegisters";
	
EndFunction

// Returns a value for identification of the Calculation registers type.
//
// Returns:
//  String
//
&AtServerNoContext
Function CalculationRegistersTypeName()
	
	Return "CalculationRegisters";
	
EndFunction

// Returns a value for identification of the Documents type.
//
// Returns:
//  String
//
&AtServerNoContext
Function DocumentsTypeName()
	
	Return "Documents";
	
EndFunction

// Returns a value for identification of the Catalogs type.
//
// Returns:
//  String
//
&AtServerNoContext
Function CatalogsTypeName()
	
	Return "Catalogs";
	
EndFunction

// Returns a value for identifying the Enumeration data type.
//
// Returns:
//  String
//
&AtServerNoContext
Function EnumsTypeName()
	
	Return "Enums";
	
EndFunction

// Returns a value for identification of the Exchange plans type.
//
// Returns:
//  String
//
&AtServerNoContext
Function ExchangePlansTypeName()
	
	Return "ExchangePlans";
	
EndFunction

// Returns a value for identification of the Charts of characteristic types type.
//
// Returns:
//  String
//
&AtServerNoContext
Function ChartsOfCharacteristicTypesTypeName()
	
	Return "ChartsOfCharacteristicTypes";
	
EndFunction

// Returns a value for identification of the Business processes type.
//
// Returns:
//  String
//
&AtServerNoContext
Function BusinessProcessesTypeName()
	
	Return "BusinessProcesses";
	
EndFunction

// Returns a value for identification of the Tasks type.
//
// Returns:
//  String
//
&AtServerNoContext
Function TasksTypeName()
	
	Return "Tasks";
	
EndFunction

// Checks whether the metadata object belongs to the Charts of accounts type.
//
// Returns:
//  String
//
&AtServerNoContext
Function ChartsOfAccountsTypeName()
	
	Return "ChartsOfAccounts";
	
EndFunction

// Returns a value for identification of the Charts of calculation types type.
//
// Returns:
//  String
//
&AtServerNoContext
Function ChartsOfCalculationTypesTypeName()
	
	Return "ChartsOfCalculationTypes";
	
EndFunction

// Returns a value for identification of the Constants type.
//
// Returns:
//  String
//
&AtServerNoContext
Function ConstantsTypeName()
	
	Return "Constants";
	
EndFunction

// Returns a value for identification of the Document journals type.
//
// Returns:
//  String
//
&AtServerNoContext
Function DocumentJournalsTypeName()
	
	Return "DocumentJournals";
	
EndFunction

// Returns a value for identification of the Sequences type.
//
// Returns:
//  String
//
&AtServerNoContext
Function SequencesTypeName()
	
	Return "Sequences";
	
EndFunction

// Returns a value for identification of the ScheduledJobs type.
//
// Returns:
//  String
//
&AtServerNoContext
Function ScheduledJobsTypeName()
	
	Return "ScheduledJobs";
	
EndFunction

// Returns a structure containing attribute values retrieved from the infobase
// using the object reference.
// 
//  If access to any of the attributes is denied, an exception is raised.
//  To read attribute values regardless of current user rights,
//  enable privileged mode.
// 
// Parameters:
//  Ref    - AnyRef - catalog item, document, etc.
//
//  Attributes - String - attribute names separated with commas, formatted
//              according to structure requirements.
//              Example: "Code, Description, Parent".
//            - Structure
//            - FixedStructure - Keys are field aliases used for resulting structure keys.
//              (Optional) Values are field names.
//              If a value is undefined, it repeats the key.
//              
//            - Array
//            - FixedArray - attribute names formatted according to
//              structure property requirements.
//
// Returns:
//  Structure - contains names (keys) and values of the requested attributes.
//              If the string of the requested attributes is empty, an empty structure is returned.
//
&AtServerNoContext
Function ObjectAttributesValues(Ref, Val Attributes)
	
	If TypeOf(Attributes) = Type("String") Then
		If IsBlankString(Attributes) Then
			Return New Structure;
		EndIf;
		Attributes = StrSplit(Attributes, ",", False);
	EndIf;
	
	AttributesStructure1 = New Structure;
	If TypeOf(Attributes) = Type("Structure") Or TypeOf(Attributes) = Type("FixedStructure") Then
		AttributesStructure1 = Attributes;
	ElsIf TypeOf(Attributes) = Type("Array") Or TypeOf(Attributes) = Type("FixedArray") Then
		For Each Attribute In Attributes Do
			AttributesStructure1.Insert(StrReplace(Attribute, ".", ""), Attribute);
		EndDo;
	Else
		Raise SubstituteParametersToString(NStr("en = 'Invalid Attributes parameter type: %1.';"), String(TypeOf(Attributes)));
	EndIf;
	
	FieldTexts = "";
	For Each KeyAndValue In AttributesStructure1 Do
		FieldName   = ?(ValueIsFilled(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Key));
		
		Alias = TrimAll(KeyAndValue.Key);
		
		FieldTexts  = FieldTexts + ?(IsBlankString(FieldTexts), "", ",") + "
		|	" + FieldName + " AS " + Alias;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	|	&FieldTexts
	|FROM
	|	&TableName AS SpecifiedTableAlias
	|WHERE
	|	SpecifiedTableAlias.Ref = &Ref
	|";
	Query.Text = StrReplace(Query.Text, "&FieldTexts", FieldTexts);
	Query.Text = StrReplace(Query.Text, "&TableName", Ref.Metadata().FullName());
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Result = New Structure;
	For Each KeyAndValue In AttributesStructure1 Do
		Result.Insert(KeyAndValue.Key);
	EndDo;
	FillPropertyValues(Result, Selection);
	
	Return Result;
	
EndFunction

// Returns an attribute value retrieved from the infobase using the object reference.
//
//  If access to the attribute is denied, an exception is raised.
//  To read attribute values regardless of current user rights,
//  enable privileged mode.
//
// Parameters:
//  Ref       - AnyRef - catalog item, document, etc.
//  AttributeName - String - for example, "Code".
//
// Returns:
//  Arbitrary    - Depends on the type of the read attribute.
//
&AtServerNoContext
Function ObjectAttributeValue(Ref, AttributeName)
	
	Result = ObjectAttributesValues(Ref, AttributeName);
	Return Result[StrReplace(AttributeName, ".", "")];
	
EndFunction 

// Returns a reference to the common module by the name.
//
// Parameters:
//  Name          - String - a common module name, for example:
//                 "Common",
//                 "CommonClient".
//
// Returns:
//  CommonModule
//
&AtClientAtServerNoContext
Function CommonModule(Name)
	
// ACC:488-off "Calculate" instead of "Common.CalculateInSafeMode" because it's a standalone data processor.
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If Metadata.CommonModules.Find(Name) <> Undefined Then
		SetSafeMode(True);
		Module = Eval(Name);
	Else
		Module = Undefined;
	EndIf;
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise SubstituteParametersToString(NStr("en = 'Common module ""%1"" does not exist.';"), Name);
	EndIf;
#Else
	Module = Eval(Name);
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise SubstituteParametersToString(NStr("en = 'Common module ""%1"" does not exist.';"), Name);
	EndIf;
#EndIf
// ACC:488-on
	
	Return Module;
	
EndFunction

// Returns True if a subsystem exists.
//
// Parameters:
//  FullSubsystemName - String - the full name of the subsystem metadata object, excluding word "Subsystem.".
//                        Example: "StandardSubsystems.Core".
//
// Example of calling an optional subsystem:
//
//  If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
//  	ModuleAccessManagement = Common.CommonModule("AccessManagement");
//  	ModuleAccessManagement.<Method name>();
//  EndIf;
//
// Returns:
//  Boolean
//
&AtServer
Function SubsystemExists(FullSubsystemName)
	
	If Not SSLVersionMatchesRequirements Then
		Return False;
	EndIf;
	
	SubsystemsNames = SubsystemsNames();
	Return SubsystemsNames.Get(FullSubsystemName) <> Undefined;
	
EndFunction

// Returns a map between subsystem names and the True value;
&AtServerNoContext
Function SubsystemsNames()
	
	Return New FixedMap(SubordinateSubsystemsNames(Metadata));
	
EndFunction

&AtServerNoContext
Function SubordinateSubsystemsNames(ParentSubsystem)
	
	Names = New Map;
	
	For Each CurrentSubsystem In ParentSubsystem.Subsystems Do
		
		Names.Insert(CurrentSubsystem.Name, True);
		SubordinatesNames = SubordinateSubsystemsNames(CurrentSubsystem);
		
		For Each SubordinateFormName In SubordinatesNames Do
			Names.Insert(CurrentSubsystem.Name + "." + SubordinateFormName.Key, True);
		EndDo;
	EndDo;
	
	Return Names;
	
EndFunction

// Returns a string presentation of the type. 
// For reference types, returns a string in format "CatalogRef.ObjectName" or "DocumentRef.ObjectName".
// For any other types, converts the type to string. Example: "Number".
//
&AtServerNoContext
Function TypePresentationString(Type)
	
	Presentation = "";
	
	If IsReference(Type) Then
	
		FullName = Metadata.FindByType(Type).FullName();
		ObjectName = StrSplit(FullName, ".")[1];
		
		If Catalogs.AllRefsType().ContainsType(Type) Then
			Presentation = "CatalogRef";
		
		ElsIf Documents.AllRefsType().ContainsType(Type) Then
			Presentation = "DocumentRef";
		
		ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
			Presentation = "BusinessProcessRef";
		
		ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfCharacteristicTypesRef";
		
		ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfAccountsRef";
		
		ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfCalculationTypesRef";
		
		ElsIf Tasks.AllRefsType().ContainsType(Type) Then
			Presentation = "TaskRef";
		
		ElsIf ExchangePlans.AllRefsType().ContainsType(Type) Then
			Presentation = "ExchangePlanRef";
		
		ElsIf Enums.AllRefsType().ContainsType(Type) Then
			Presentation = "EnumRef";
		
		EndIf;
		
		Result = ?(Presentation = "", Presentation, Presentation + "." + ObjectName);
		
	ElsIf Type = Type("Undefined") Then
		
		Result = "Undefined";
		
	ElsIf Type = Type("String") Then
		Result = "String";

	ElsIf Type = Type("Number") Then
		Result = "Number";

	ElsIf Type = Type("Boolean") Then
		Result = "Boolean";

	ElsIf Type = Type("Date") Then
		Result = "Date";
	
	Else
		
		Result = String(Type);
		
	EndIf;
	
	Return Result;
	
EndFunction

//	Converts the value table into an array.
//	Use this function to pass data received on the server
//	as a value table to the client. This is only possible
//	if all of values from the value
//  table can be passed to the client.
//
//	The resulting array contains structures that duplicate
//	value table row structures.
//
//	It is recommended that you do not use this procedure to convert value tables
//	with a large number of rows.
//
//	Parameters:
//    ValueTable - ValueTable 
//
//	Returns:
//    Array
//
&AtServerNoContext
Function ValueTableToArray(ValueTable)
	
	Array = New Array();
	StructureString = "";
	CommaRequired = False;
	For Each Column In ValueTable.Columns Do
		If CommaRequired Then
			StructureString = StructureString + ",";
		EndIf;
		StructureString = StructureString + Column.Name;
		CommaRequired = True;
	EndDo;
	For Each String In ValueTable Do
		NewRow = New Structure(StructureString);
		FillPropertyValues(NewRow, String);
		Array.Add(NewRow);
	EndDo;
	Return Array;

EndFunction

// Generates a string according to the specified pattern.
// The following tags are available:
//	 String  - formats the string as bold.
//	 String 
//
// Example:
//	The lowest supported version is 1.1. Update the app.
//
// Returns:
//  FormattedString
//
&AtServerNoContext
Function FormattedString(Val String)
	
	BoldStrings = New ValueList;
	While StrFind(String, "<b>") <> 0 Do
		BoldBeginning = StrFind(String, "<b>");
		StringBeforeOpeningTag = Left(String, BoldBeginning - 1);
		BoldStrings.Add(StringBeforeOpeningTag);
		StringAfterOpeningTag = Mid(String, BoldBeginning + 3);
		BoldEnd = StrFind(StringAfterOpeningTag, "</b>");
		SelectedFragment = Left(StringAfterOpeningTag, BoldEnd - 1);
		BoldStrings.Add(SelectedFragment,, True);
		StringAfterBold = Mid(StringAfterOpeningTag, BoldEnd + 4);
		String = StringAfterBold;
	EndDo;
	BoldStrings.Add(String);
	
	StringsWithLinks = New ValueList;
	For Each RowPart In BoldStrings Do
		
		String = RowPart.Value;
		
		If RowPart.Check Then
			StringsWithLinks.Add(String,, True);
			Continue;
		EndIf;
		
		BoldBeginning = StrFind(String, "<a href = ");
		While BoldBeginning <> 0 Do
			StringBeforeOpeningTag = Left(String, BoldBeginning - 1);
			StringsWithLinks.Add(StringBeforeOpeningTag, );
			
			StringAfterOpeningTag = Mid(String, BoldBeginning + 9);
			EndTag1 = StrFind(StringAfterOpeningTag, ">");
			
			Ref = TrimAll(Left(StringAfterOpeningTag, EndTag1 - 2));
			If StrStartsWith(Ref, """") Then
				Ref = Mid(Ref, 2, StrLen(Ref) - 1);
			EndIf;
			If StrEndsWith(Ref, """") Then
				Ref = Mid(Ref, 1, StrLen(Ref) - 1);
			EndIf;
			
			StringAfterLink = Mid(StringAfterOpeningTag, EndTag1 + 1);
			BoldEnd = StrFind(StringAfterLink, "</a>");
			HyperlinkAnchorText = Left(StringAfterLink, BoldEnd - 1);
			StringsWithLinks.Add(HyperlinkAnchorText, Ref);
			
			StringAfterBold = Mid(StringAfterLink, BoldEnd + 4);
			String = StringAfterBold;
			
			BoldBeginning = StrFind(String, "<a href = ");
		EndDo;
		StringsWithLinks.Add(String);
		
	EndDo;
	
	RowArray = New Array;
	For Each RowPart In StringsWithLinks Do
		
		If RowPart.Check Then
			//@skip-check new-font
			RowArray.Add(New FormattedString(RowPart.Value, New Font(,,True))); // ACC:1345 Standalone data processor cannot use styles.
		ElsIf Not IsBlankString(RowPart.Presentation) Then
			RowArray.Add(New FormattedString(RowPart.Value,,,, RowPart.Presentation));
		Else
			RowArray.Add(RowPart.Value);
		EndIf;
		
	EndDo;
	
	Return New FormattedString(RowArray); // ACC:1356 Can use a compound format string as the string array consists of the passed text.
	
EndFunction

// Generates the presentation of a number for a certain language and number parameters.
//
// Parameters:
//  Template          - String - contains semicolon-separated 6 string forms
//                             for each numeral category: 
//                             %1 denotes the number position;
//  Number           - Number - a number to be inserted instead of the "%1" parameter.
//  Kind             - NumericValueType - defines a kind of the numeric value for which a presentation is formed. 
//                             Cardinal (default) or Ordinal.
//  FormatString - String - a string of formatting parameters. See similar example for StringWithNumber. 
//
// Returns:
//  String - presentation of the number string in the requested format.
//
// Example:
//  
//  String = StringFunctionsClientServer.StringWithNumberForAnyLanguage(
//		NStr("ru=';остался %1 день;;осталось %1 дня;осталось %1 дней;осталось %1 дня';
//		     |en=';%1 day left;;;;%1 days left'"), 
//		0.05,,"NFD=1);
// 
&AtServerNoContext
Function StringWithNumberForAnyLanguage(Template, Number, Kind = Undefined, FormatString = "NZ=0;")

	If IsBlankString(Template) Then
		Return Format(Number, FormatString); 
	EndIf;

	If Kind = Undefined Then
		Kind = NumericValueType.Cardinal;
	EndIf;

	Return StringWithNumber(Template, Number, Kind, FormatString);

EndFunction

// Returns a flag that shows whether this is the base configuration.
//
// Returns:
//   Boolean   - True if this is the basic configuration.
//
&AtServerNoContext
Function IsBaseConfigurationVersion()
	
	Return StrFind(Upper(Metadata.Name), "BASIC") > 0;
	
EndFunction

// Checks if conditional separation is enabled.
// If it is called in shared application it returns False.
//
&AtServerNoContext
Function DataSeparationEnabled()
	
	SaaSAvailable = Metadata.FunctionalOptions.Find("SaaSOperations");
	If SaaSAvailable <> Undefined Then
		OptionName1 = "SaaSOperations";
		Return IsSeparatedConfiguration() And GetFunctionalOption(OptionName1);
	EndIf;
	
	Return False;
	
EndFunction

// Returns a flag indicating if there are any common separators in the configuration.
//
// Returns:
//   Boolean
//
&AtServerNoContext
Function IsSeparatedConfiguration()
	
	HasSeparators = False;
	For Each CommonAttribute In Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			HasSeparators = True;
			Break;
		EndIf;
	EndDo;
	
	Return HasSeparators;
	
EndFunction

&AtServer
Function SSLVersionMatchesRequirements()
	DataProcessorObject = FormAttributeToValue("Object");
	Return DataProcessorObject.SSLVersionMatchesRequirements();
EndFunction

&AtServer
Procedure CheckPlatformVersionAndCompatibilityMode()
	
	Information = New SystemInfo;
	If Not (Left(Information.AppVersion, 3) = "8.3"
		And (Metadata.CompatibilityMode = Metadata.ObjectProperties.CompatibilityMode.DontUse
		Or (Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_1
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_2_13
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_2_16"]
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_1"]
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_2"]))) Then
		
		Raise NStr("en = 'The data processor supports 1C:Enterprise 8.3 or later,
			|with disabled compatibility mode.';");
		
	EndIf;
	
EndProcedure

&AtServer
Function OperationsKindsPicture()
	If SSLVersionMatchesRequirements Then
		Return PictureLib["OperationKinds"];
	Else
		Return New Picture;
	EndIf;
EndFunction

&AtClient
Procedure Object1AttributesStartDrag(Item, DragParameters, Perform)
	DragParameters.Value = "Object." + Item.CurrentData.Name;
	// Insert the handler content.
EndProcedure

&AtClient
Procedure PresentationOfObjectsToChangeAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	InputFieldAutoSelection(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
EndProcedure

&AtClient
Procedure InputFieldAutoSelection(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	ChoiceData = ChoiceData(Text, Item.ChoiceList);
	StandardProcessing = Not ValueIsFilled(Text);
EndProcedure

&AtClient
Function ChoiceData(String, ChoiceList)
	
	Result = New ValueList;
	
	If Not ValueIsFilled(String) Then
		Return Result;
	EndIf;
	
	For Each Item In ChoiceList Do
		ItemPresentation = Item.Presentation;
		
		SearchString = ItemPresentation;
		
		FormattedStrings = New Array;
		For Each Substring In StrSplit(String, " ", False) Do
			Position = StrFind(Lower(SearchString), Lower(Substring));
			If Position = 0 Then
				FormattedStrings = Undefined;
				Break;
			EndIf;
			
			SubstringBeforeOccurence = Left(SearchString, Position - 1);
			OccurenceSubstring = Mid(SearchString, Position, StrLen(Substring));
			SearchString = Mid(SearchString, Position + StrLen(Substring));
			
			FormattedStrings.Add(SubstringBeforeOccurence);
			//@skip-check new-font
			//@skip-check new-color
			FormattedStrings.Add(New FormattedString(OccurenceSubstring,
				New Font( , , True), New Color(0,128,0))); // ACC:1345, ACC:1346 Standalone data processor cannot use styles.
		EndDo;
		
		If Not ValueIsFilled(FormattedStrings) Then
			Continue;
		EndIf;
		
		FormattedStrings.Add(SearchString);
		HighlightedString = New FormattedString(FormattedStrings); // ACC:1356 - A compound format string can be used as the string array consists of the passed text.
		
		Result.Add(Item.Value, HighlightedString);
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function ObjectsEnabled()
	
	ObjectsEnabled = New Map;
	For Each FunctionalOption In Metadata.FunctionalOptions Do
		If Not Metadata.Constants.Contains(FunctionalOption.Location) Then
			Continue;
		EndIf;
		Value = GetFunctionalOption(FunctionalOption.Name, New Structure);
		For Each Item In FunctionalOption.Content Do
			If Item.Object = Undefined Then
				Continue;
			EndIf;
			If Value = True Then
				ObjectsEnabled.Insert(Item.Object, True);
			Else
				If ObjectsEnabled[Item.Object] = Undefined Then
					ObjectsEnabled.Insert(Item.Object, False);
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	Return ObjectsEnabled;
	
EndFunction

&AtServer
Function IsFullUser()
	
	If SSLVersionMatchesRequirements Then
		ModuleUsers = CommonModule("Users");
		Return ModuleUsers.IsFullUser();
	EndIf;
	
	Return True;
	
EndFunction

&AtClient
Procedure EditFormula()
	CurrentData = Items.ObjectAttributes.CurrentData;
	NotifyDescription = New NotifyDescription("ObjectAttributesValueChoiceCompletion", ThisObject, CurrentData);
	OpenForm(FullFormName("FormulaEdit"), ComposerParameters(CurrentData.Value), , , , ,
		NotifyDescription);
EndProcedure

&AtClient
Function ErrorsInfo()
	
	If ErrorsInfo = Undefined Then
		ErrorsInfo = New Map;
	EndIf;
	
	Return ErrorsInfo;
	
EndFunction

&AtClient
Function InfoOnError(Val Var_Key = Undefined)
	
	InfoOnError = Undefined;
	
	If Var_Key <> Undefined Then
		InfoOnError = ErrorsInfo()[Var_Key];
	EndIf;
	
	If InfoOnError = Undefined Then
		InfoOnError = New Structure;
		InfoOnError.Insert("ErrorReport");
		InfoOnError.Insert("ErrorInfo");
	EndIf;
	
	Return InfoOnError;
	
EndFunction

&AtClient
Procedure SendErrorReport()
	
	If Not SSLVersionMatchesRequirements Then
		Return;
	EndIf;
	
	ModuleStandardClientSubsystems = CommonModule("StandardSubsystemsClient");
	
	For Each Item In ErrorsInfo() Do
		InfoOnError = Item.Value;
		ModuleStandardClientSubsystems.SendErrorReport(InfoOnError.ErrorReport, InfoOnError.ErrorInfo);
	EndDo;
	
	ErrorsInfo = Undefined;
	
EndProcedure

&AtClient
Procedure OutputErrorInfo(ErrorInfo)
	
	If SSLVersionMatchesRequirements Then
		ModuleStandardClientSubsystems = CommonModule("StandardSubsystemsClient");
		ModuleStandardClientSubsystems.OutputErrorInfo(ErrorInfo);
	Else
		Raise ErrorProcessing.BriefErrorDescription(ErrorInfo);
	EndIf;
	
EndProcedure

#EndRegion