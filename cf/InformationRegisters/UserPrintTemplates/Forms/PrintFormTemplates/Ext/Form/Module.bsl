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

&AtServer
Var SubordinateCatalogs;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	PopulateObjectsWithPrintCommands();
	PopulateTemplateListBySections();
	
	If Parameters.Property("ShowOnlyUserChanges") Then
		FilterByTemplateUsage = "UsedModifiedItems";
	Else
		FilterByTemplateUsage = Items.FilterByTemplateUsage.ChoiceList[0].Value;
	EndIf;
	
	HasUpdateRight = AccessRight("Update", Metadata.InformationRegisters.UserPrintTemplates);
	If Not HasUpdateRight Then
		StandardProcessing = False;
		MessageText = NStr("en = 'Insufficient rights to edit templates.';");
		Raise(MessageText, ErrorCategory.AccessViolation);
	EndIf;
	
	ThereAreAdditionalLanguagesAvailable = False;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.Print") Then
			PrintManagementModuleNationalLanguageSupport = Common.CommonModule("PrintManagementNationalLanguageSupport");
			AdditionalLanguagesOfPrintedForms = PrintManagementModuleNationalLanguageSupport.AdditionalLanguagesOfPrintedForms();
			
			Items.FilterByLanguage.ChoiceList.Add("", NStr("en = 'All';"));
			For Each Language In AdditionalLanguagesOfPrintedForms Do
				LanguagePresentation = ModuleNationalLanguageSupportServer.LanguagePresentation(Language);
				Items.FilterByLanguage.ChoiceList.Add(LanguagePresentation);
			EndDo;
			
			ThereAreAdditionalLanguagesAvailable = AdditionalLanguagesOfPrintedForms.Count() > 0;
		EndIf;
	EndIf;
	
	Items.AdditionalInformationGroup.Visible = ThereAreAdditionalLanguagesAvailable;
	Items.FilterByLanguage.Visible = ThereAreAdditionalLanguagesAvailable;
	Items.TemplatesAvailableLanguages.Visible = ThereAreAdditionalLanguagesAvailable;
	Items.TemplatesAvailableTranslation.Visible = ThereAreAdditionalLanguagesAvailable;
	
	TemplateOpeningModeView = False;

	If Common.IsMobileClient() Then
		TemplateOpeningModeView = True;
		Items.GroupFilters.Group = ChildFormItemsGroup.HorizontalIfPossible;
	EndIf;
	
	AutoURL = False;
	URL = "e1cib/list/InformationRegister.UserPrintTemplates";
	
	If ValueIsFilled(Parameters.TemplatePath) Then
		PositionInTree = TemplatePositionInTree(Parameters.TemplatePath);
		If ValueIsFilled(PositionInTree) Then
			NavigateToItem(PositionInTree);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Not ValueIsFilled(Parameters.TemplatePath) Then
		NavigateToItem(PositionInTree);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If (EventName = "Write_SpreadsheetDocument" Or EventName = "Write_OfficeDocument" 
		Or EventName = "Write_UserPrintTemplates") Then
		If Not ReadOnly Then
			IDsOfModifiedRows = UpdateDisplayLayout(Parameter);
			If Items.Templates.CurrentData <> Undefined And Items.Templates.CurrentData.IsFolder Then
				Items.Templates.CurrentRow = IDsOfModifiedRows[Items.Templates.CurrentData.GetID()];
			Else
				For Each Item In IDsOfModifiedRows Do
					Items.Templates.CurrentRow = Item.Value;
					Break;
				EndDo;
			EndIf;
			If Items.Templates.CurrentData <> Undefined Then
				Items.Templates.CurrentData.MatchesFilter = True;
			EndIf;
		EndIf;
		SetCommandBarButtonsEnabled();
	EndIf;
	
EndProcedure

&AtServer
Function UpdateDisplayLayout(Val Parameter)
	
	IDsOfModifiedRows = New Map;
	IdentifierOfTemplate = Parameter.TemplateMetadataObjectName;
	DataSources = ?(Parameter.Property("DataSources"),
		Parameter.DataSources, New Array);
	
	FoundTemplates = FindTemplates(IdentifierOfTemplate, Templates);
	For Each Template In FoundTemplates Do
		DataSource = Template.GetParent();
		If StrStartsWith(DataSource.Id, "DataProcessor")
			Or StrStartsWith(DataSource.Id, "Report") Then
			DataSources.Add(DataSource.Owner);
		EndIf;
		
		If DataSources.Find(DataSource.Owner) = Undefined Then
			DataSource.GetItems().Delete(Template);
			ClearUpCache(DataSource.Id, ObjectsWithPrintCommands);
		EndIf;
	EndDo;
	
	For Each DataSource In DataSources Do
		TemplatesOwnerBranches = FindBranchesOfTemplateOwner(DataSource, Templates);
		For Each Branch1 In TemplatesOwnerBranches Do
			If Branch1.GetItems().Count() > 0 And Not ValueIsFilled(Branch1.GetItems()[0].Id) Then
				Continue;
			EndIf;
			
			ClearUpCache(Branch1.Id, ObjectsWithPrintCommands);
			
			Template = FindTemplate(IdentifierOfTemplate, Branch1);
			If Template = Undefined Then
				InformationRegisters.UserPrintTemplates.AddUserTemplates(Branch1.GetItems(), IdentifierOfTemplate);
				Template = FindTemplate(IdentifierOfTemplate, Branch1);
				Template.MatchesFilter = True;
				IDsOfModifiedRows.Insert(Branch1.GetID(), Template.GetID());
				Continue;
			EndIf;
			
			IDsOfModifiedRows.Insert(Branch1.GetID(), Template.GetID());
			
			Template.Changed = Not Template.Supplied Or PrintManagement.UserTemplateUsed(IdentifierOfTemplate);
			Template.ChangedTemplateUsed = Template.Changed;
			Template.AvailableLanguages = InformationRegisters.UserPrintTemplates.AvailableLayoutLanguages(Parameter.TemplateMetadataObjectName);
			Template.UsagePicture = -1;
			If Template.Changed Then
				Template.UsagePicture = Number(Template.Changed) + Number(Template.ChangedTemplateUsed);
			EndIf;
			If Parameter.Property("Presentation") Then
				Template.Presentation = Parameter.Presentation;
			EndIf;
	
		EndDo;
	EndDo;
	
	Return IDsOfModifiedRows;
	
EndFunction

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	Parameter = New Structure("Cancel", False);
	Notify("OwnerFormClosing", Parameter, ThisObject);
	
	If Parameter.Cancel Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetTemplatesFilter();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterByLanguageOnChange(Item)
	
	RefreshVisibilityOfTemplates();
	
EndProcedure

&AtClient
Procedure SearchStringClearing(Item, StandardProcessing)
	
	RefreshVisibilityOfTemplates();
	
EndProcedure

&AtClient
Procedure SearchStringEditTextChange(Item, Text, StandardProcessing)
	StandardProcessing = False;
	SearchString = Text;
	
	RefreshVisibilityOfTemplates();
	
EndProcedure

&AtClient
Procedure SearchStringOnChange(Item)
	
	If ValueIsFilled(SearchString) And Items.SearchString.ChoiceList.FindByValue(SearchString) = Undefined Then
		Items.SearchString.ChoiceList.Add(SearchString);
	EndIf;
	
	RefreshVisibilityOfTemplates();
	
EndProcedure

&AtClient
Procedure FilterByUsedTemplateKindOnChange(Item)
	SetTemplatesFilter();
EndProcedure

&AtClient
Procedure FilterByTemplateUsageClearing(Item, StandardProcessing)
	StandardProcessing = False;
	FilterByTemplateUsage = Items.FilterByTemplateUsage.ChoiceList[0].Value;
	SetTemplatesFilter();
EndProcedure

&AtClient
Procedure AdditionalInformationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.NationalLanguageSupport.Print") Then
		PrintManagementModuleNationalLanguageSupportClient = CommonClient.CommonModule("PrintManagementNationalLanguageSupportClient");
		PrintManagementModuleNationalLanguageSupportClient.AdditionalInformationURLProcessing(Item, FormattedStringURL, StandardProcessing);
	EndIf;
	
EndProcedure
	
#EndRegion

#Region FormTableItemsEventHandlersTemplates

&AtClient
Procedure TemplatesSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Templates.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.IsFolder Then
		Return;
	EndIf;
		
	If Field.Name = "LayoutsButtonSettingsAccessibility" Then
		AvailabilityConditions(Undefined);
	Else
		OpenPrintFormTemplate();
	EndIf;
	
EndProcedure

&AtClient
Procedure TemplatesOnActivateRow(Item)
	
	PositionInTree = PathToItemInTree(Items.Templates.CurrentData);
	DetachIdleHandler("SetCommandBarButtonsEnabled");
	AttachIdleHandler("SetCommandBarButtonsEnabled", 0.1, True);
	
EndProcedure

&AtClient
Procedure TemplatesOnChange(Item)
	
	CurrentData = Item.CurrentData;
	If CurrentData <> Undefined And ValueIsFilled(CurrentData.Ref) Then
		SetUseLayout(CurrentData.Ref, CurrentData.Used);
		FoundTemplates = FindTemplates(CurrentData.Id, Templates);
		For Each Template In FoundTemplates Do
			Template.Used = CurrentData.Used;
		EndDo;
		ClearUpCache(CurrentData.GetParent().Id, ObjectsWithPrintCommands);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SetUseLayout(Template, Used)
	
	Catalogs.PrintFormTemplates.SetUseLayout(Template, Used);
	RefreshReusableValues();
	
EndProcedure

&AtClient
Procedure TemplatesBeforeExpand(Item, String, Cancel)

	ItemsCollection = Templates.FindByID(String).GetItems();
	If ItemsCollection.Count() > 0 And Not ValueIsFilled(ItemsCollection[0].Id) Then
		Cancel = True;
		ExpandableBranches = ExpandableBranches + Format(String, "NG=0;") + ";";
		AttachIdleHandler("Attachable_ExpandBranches", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ExpandBranches()
	
	ImportSubordinateItems(ExpandableBranches);
	
	For Each RowID In StrSplit(ExpandableBranches, ";", False) Do
		Branch1 = Templates.FindByID(RowID);
		MarkItemsMatchingFilter(Branch1);
		Items.Templates.Expand(RowID);
	EndDo;
	
	ExpandableBranches = "";
	
EndProcedure

&AtServer
Procedure ImportSubordinateItems(RowsIDs)
	
	For Each RowID In StrSplit(RowsIDs, ";", False) Do
		CurrentData = Templates.FindByID(RowID);
		ItemsCollection = CurrentData.GetItems();
	
		If ItemsCollection.Count() = 0 Or ValueIsFilled(ItemsCollection[0].Id) Then
			Continue;
		EndIf;
		
		ItemsCollection.Clear();
		
		MetadataObject = Common.MetadataObjectByFullName(CurrentData.Id);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;

		OutputTemplates(CurrentData);
		
		If Common.IsDocumentJournal(MetadataObject) Then
			OutputCollection(CurrentData, MetadataObject.RegisteredDocuments);
		ElsIf Common.IsCatalog(MetadataObject) Then 
			OutputCollection(CurrentData, SubordinateCatalogs(MetadataObject));
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ChangeTemplate(Command)
	OpenPrintFormTemplateForEdit();
EndProcedure

&AtClient
Procedure UseModifiedTemplate(Command)
	SwitchSelectedTemplatesUsage(True);
EndProcedure

&AtClient
Procedure UseStandardTemplate(Command)
	SwitchSelectedTemplatesUsage(False);
EndProcedure

&AtClient
Procedure AddTemplate(Command)
	
	NotificationParameters = New Structure("Copy, TemplateType", False, "MXL");
	NotifyDescription = New NotifyDescription("OnSelectingLayoutName", ThisObject, NotificationParameters);
	UniqueDescr = AssignUniqueDescription(NStr("en = 'New print form';"), False);
	ShowInputString(NotifyDescription, UniqueDescr, NStr("en = 'Enter a template description';"), 100, False)
	
EndProcedure

&AtClient
Procedure GoInList(Command)
	GoToList();
EndProcedure

&AtClient
Procedure AddOfficeOpenXMLTemplate(Command)
	
	NotificationParameters = New Structure("Copy, TemplateType", False, "DOCX");
	NotifyDescription = New NotifyDescription("OnSelectingLayoutName", ThisObject, NotificationParameters);
	UniqueDescr = AssignUniqueDescription(NStr("en = 'New print form';"), False);
	ShowInputString(NotifyDescription, UniqueDescr, NStr("en = 'Enter a template description';"), 100, False)
	
EndProcedure


&AtClient
Procedure AvailabilityConditions(Command)
	
	CurrentData = Items.Templates.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentData.Ref) Then
		Return;
	EndIf;
	
	OpeningParameters = New Structure("Key", CurrentData.Ref);
	
	OpenForm("Catalog.PrintFormTemplates.Form.VisibilityConditionsInPrintSubmenu", OpeningParameters, ThisObject);
	
EndProcedure

#EndRegion

#Region Private

#Region Filters

&AtClient
Procedure SetTemplatesFilter();

	ShowChanged = True;
	ShowUnmodified = True;
	ShowUsed = True;
	ShowUnused = True;
	
	If FilterByTemplateUsage = "Modified1" Then
		ShowUnmodified = False;
	ElsIf FilterByTemplateUsage = "NotModified1" Then
		ShowChanged = False;
	ElsIf FilterByTemplateUsage = "UsedModifiedItems" Then
		ShowUnused = False;
		ShowUnmodified = False;
	ElsIf FilterByTemplateUsage = "NotUsedModifiedItems" Then
		ShowUnmodified = False;
		ShowUsed = False;
	EndIf;
	
	RefreshVisibilityOfTemplates();
	
EndProcedure

&AtClient
Procedure RefreshVisibilityOfTemplates(Interval = 0.5);
	
	DetachIdleHandler("ApplySelection");
	AttachIdleHandler("ApplySelection", Interval, True);
	
EndProcedure

#EndRegion

// Template opening

&AtClient
Procedure OpenPrintFormTemplate()
	
	If TemplateOpeningModeView Then
		OpenPrintFormTemplateForView();
	Else
		OpenPrintFormTemplateForEdit();
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenPrintFormTemplateForView()
	
	CurrentData = Items.Templates.CurrentData;
	
	FormParameters = New Structure;
	FormParameters.Insert("TemplateMetadataObjectName", CurrentData.TemplateMetadataObjectName);
	FormParameters.Insert("TemplateType", CurrentData.TemplateType);
	FormParameters.Insert("OpenOnly", True);
	
	If CurrentData.TemplateType = "MXL" Then
		EditorParameters = StandardSubsystemsClient.SpreadsheetEditorParameters();
		EditorParameters.DocumentName = CurrentData.Presentation;
		EditorParameters.Insert("TemplateMetadataObjectName", CurrentData.TemplateMetadataObjectName);
		StandardSubsystemsClient.ShowSpreadsheetEditor(Undefined, EditorParameters,,
			ThisObject);
		Return;
	ElsIf CurrentData.TemplateType = "DOCX" Then
		If TemplateVersion(CurrentData.Id, CurrentData.TemplateType) = "Areas" Then
			OpenForm("InformationRegister.UserPrintTemplates.Form.EditTemplate2", FormParameters, 
				ThisObject);
			Return;
		EndIf;
		FormParameters.Insert("DocumentName", CurrentData.Presentation);
		FormParameters.Insert("Edit", False);
		OpenForm("CommonForm.EditOfficeOpenDoc", FormParameters, ThisObject);
		Return;	
	EndIf;
	
	OpenForm("InformationRegister.UserPrintTemplates.Form.EditTemplate2", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure OpenPrintFormTemplateForEdit()
	
	CurrentData = Items.Templates.CurrentData;
	
	If CurrentData.Changed And Not CurrentData.ChangedTemplateUsed Then
		NotifyDescription = New NotifyDescription("OpenPrintFormTemplateForEditingFollowUp", ThisObject, CurrentData);
		QueryText = NStr("en = 'An edited version of this template is available.
		|You can switch to the edited template or continue with the standard one.
		|';");
		
		Buttons = New ValueList();
		Buttons.Add(True, NStr("en = 'Edited template';"));
		Buttons.Add(False, NStr("en = 'Standard template';"));
		Buttons.Add(Undefined, NStr("en = 'Cancel';"));
		
		ShowQueryBox(NotifyDescription, QueryText, Buttons, , , NStr("en = 'Which template do you want to proceed with?';"));
		Return;
	EndIf;
	
	OpenPrintFormTemplateForEditingFollowUp(False, CurrentData);
	
EndProcedure

&AtClient
Procedure OpenPrintFormTemplateForEditingFollowUp(SwitchUsages, CurrentData) Export

	If SwitchUsages = Undefined Then
		Return;
	ElsIf SwitchUsages Then
		SwitchSelectedTemplatesUsage(True);
	EndIf;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("TemplateMetadataObjectName", CurrentData.TemplateMetadataObjectName);
	OpeningParameters.Insert("TemplateType", CurrentData.TemplateType);
	OpeningParameters.Insert("Ref", CurrentData.Ref);
	OpeningParameters.Insert("DataSource", CurrentData.Owner);
	OpeningParameters.Insert("DataSources", CurrentData.DataSources);
	OpeningParameters.Insert("IsPrintForm", CurrentData.IsPrintForm);
	OpeningParameters.Insert("IsValAvailable", Not CurrentData.Supplied);
	
	If CurrentData.TemplateType = "MXL" Then
		FormParameters = StandardSubsystemsClient.SpreadsheetEditorParameters();
		FormParameters.DocumentName = CurrentData.Presentation;
		FormParameters.Edit = Not ReadOnly;
		CommonClientServer.SupplementStructure(FormParameters, OpeningParameters, True);
		StandardSubsystemsClient.ShowSpreadsheetEditor(Undefined, FormParameters,, ThisObject);
		Return;
	ElsIf CurrentData.TemplateType = "DOCX" Then
		If TemplateVersion(CurrentData.Id, CurrentData.TemplateType) = "Areas" Then
			OpenForm("InformationRegister.UserPrintTemplates.Form.EditTemplate2", OpeningParameters, ThisObject);
			Return;
		EndIf;
		OpeningParameters.Insert("DocumentName", CurrentData.Presentation);
		OpeningParameters.Insert("Edit", True);
		OpenForm("CommonForm.EditOfficeOpenDoc", OpeningParameters, ThisObject);
		Return;	
	EndIf;
	
	OpenForm("InformationRegister.UserPrintTemplates.Form.EditTemplate2", OpeningParameters, ThisObject);
	
EndProcedure

// Template actions

&AtServerNoContext
Function TemplateVersion(Id, TemplateType)
	Template = PrintManagement.PrintFormTemplate(Id);
	TemplateData1 = PrintManagement.InitializeOfficeDocumentTemplate(Template, TemplateType);
	
	If TemplateData1.DocumentStructure.DocumentAreas.Count() > 1 
		Or TemplateData1.DocumentStructure.DocumentAreas["Paragraph"] = Undefined Then
		TemplateVersion = "Areas";
	Else
		TemplateVersion = "Parameters";
	EndIf;
	
	TemplateData1.Insert("TemplateVersion", TemplateVersion);
	Return TemplateData1.TemplateVersion;
EndFunction

&AtClient
Procedure SwitchSelectedTemplatesUsage(ChangedTemplateUsed)
	TemplatesToSwitch = New Array;
	For Each SelectedRow In Items.Templates.SelectedRows Do
		CurrentData = Items.Templates.RowData(SelectedRow);
		If CurrentData.Changed Then
			CurrentData.ChangedTemplateUsed = ChangedTemplateUsed;
			SetPictureUsage(CurrentData);
			TemplatesToSwitch.Add(CurrentData.TemplateMetadataObjectName);
		EndIf;
	EndDo;
	SetModifiedTemplatesUsage(TemplatesToSwitch, ChangedTemplateUsed);
	SetCommandBarButtonsEnabled();
EndProcedure

&AtServerNoContext
Procedure SetModifiedTemplatesUsage(Templates, ChangedTemplateUsed)
	
	InformationRegisters.UserPrintTemplates.SetModifiedTemplatesUsage(Templates, ChangedTemplateUsed);
	
EndProcedure

&AtClient
Procedure DeleteSelectedModifiedTemplates(Command)
	TemplatesToDelete = New Array;
	For Each SelectedRow In Items.Templates.SelectedRows Do
		CurrentData = Items.Templates.RowData(SelectedRow);
		CurrentData.ChangedTemplateUsed = False;
		CurrentData.Changed = False;
		CurrentData.AvailableLanguages = "";
		SetPictureUsage(CurrentData);
		TemplatesToDelete.Add(CurrentData.TemplateMetadataObjectName);
	EndDo;
	DeleteModifiedTemplates(TemplatesToDelete);
	SetCommandBarButtonsEnabled();
EndProcedure

&AtServerNoContext
Procedure DeleteModifiedTemplates(TemplatesToDelete)
	
	For Each TemplateMetadataObjectName In TemplatesToDelete Do
		PrintManagement.DeleteTemplate(TemplateMetadataObjectName);
	EndDo;
	
EndProcedure

// Common

&AtClient
Procedure SetPictureUsage(TemplateDetails)
	TemplateDetails.UsagePicture = -1;
	If TemplateDetails.Changed Then
		TemplateDetails.UsagePicture = Number(TemplateDetails.Changed) + Number(TemplateDetails.ChangedTemplateUsed);
	EndIf;
EndProcedure

&AtClient
Procedure SetCommandBarButtonsEnabled()
	
	CurrentTemplate = Items.Templates.CurrentData;
	CurrentTemplateSelected = CurrentTemplate <> Undefined;
	SeveralTemplatesSelected = Items.Templates.SelectedRows.Count() > 1;
	
	UseModifiedTemplateEnabled  = False;
	UseStandardTemplateEnabled = False;
	DeleteModifiedTemplateEnabled       = False;
	RemoveLayoutVisibility                   = False;
	DisplayInListIsAvailable              = False;
	
	For Each SelectedRow In Items.Templates.SelectedRows Do
		CurrentTemplate = Items.Templates.RowData(SelectedRow);
		UseModifiedTemplateEnabled = CurrentTemplateSelected And CurrentTemplate.Changed And Not CurrentTemplate.ChangedTemplateUsed And Not ValueIsFilled(CurrentTemplate.Ref) Or SeveralTemplatesSelected And UseModifiedTemplateEnabled;
		UseStandardTemplateEnabled = CurrentTemplateSelected And CurrentTemplate.Changed And CurrentTemplate.ChangedTemplateUsed And Not ValueIsFilled(CurrentTemplate.Ref) Or SeveralTemplatesSelected And UseStandardTemplateEnabled;
		DeleteModifiedTemplateEnabled = CurrentTemplateSelected And CurrentTemplate.Changed  And Not ValueIsFilled(CurrentTemplate.Ref) Or SeveralTemplatesSelected And DeleteModifiedTemplateEnabled;
		RemoveLayoutVisibility = CurrentTemplateSelected And ValueIsFilled(CurrentTemplate.Ref) Or SeveralTemplatesSelected And RemoveLayoutVisibility;
		
		DataSources = StrSplit(CurrentTemplate.DataSources, ",", False);
		For Each DataSource In DataSources Do
			If StrStartsWith(DataSource, "DataProcessor") 
				Or StrStartsWith(DataSource, "Report")
				Or DataSource = "CommonTemplate" Then
				Continue;
			EndIf;
			DisplayInListIsAvailable = True;
		EndDo;
	EndDo;
	
	Items.PrintFormsTemplatesUseModifiedTemplate.Enabled = UseModifiedTemplateEnabled;
	Items.PrintFormsTemplatesUseStandardTemplate.Enabled = UseStandardTemplateEnabled;
	Items.PrintFormsTemplatesDeleteModifiedTemplate.Enabled = DeleteModifiedTemplateEnabled;
	
	Items.TemplatesContextMenuDeleteModifiedTemplate.Visible = DeleteModifiedTemplateEnabled And Not ReadOnly;
	Items.TemplatesContextMenuDeleteTemplate.Visible = RemoveLayoutVisibility And Not ReadOnly;
	Items.TemplatesAvailabilityConditions.Enabled = CurrentTemplateSelected And CurrentTemplate.AvailableSettingVisibility;
	Items.TemplatesCopy.Enabled = CurrentTemplateSelected And CurrentTemplate.IsPrintForm And Not SeveralTemplatesSelected And CurrentTemplate.AvailableCreate And Not ReadOnly;
	Items.TemplatesAddTemplate.Enabled = CurrentTemplateSelected And CurrentTemplate.AvailableCreate;
	Items.TemplatesAddOfficeOpenXMLTemplate.Enabled = CurrentTemplateSelected And CurrentTemplate.AvailableCreate;
	Items.TemplatesChangeTemplate.Enabled = CurrentTemplateSelected And Not CurrentTemplate.IsFolder;
	Items.FormShowInList.Enabled = DisplayInListIsAvailable;
	
EndProcedure

&AtClient
Procedure Copy(Command)
	
	NotificationParameters = New Structure("Copy, TemplateType", True);
	NotifyDescription = New NotifyDescription("OnSelectingLayoutName", ThisObject, NotificationParameters);
	CurrentTemplate = Items.Templates.CurrentData;
	CopyDescr = AssignUniqueDescription(CurrentTemplate.Presentation);
	ShowInputString(NotifyDescription, CopyDescr, NStr("en = 'Enter a template description';"), 100, False)
	
EndProcedure

&AtServer
Function AssignUniqueDescription(TemplateDescr, ThisIsCopying = True)
	
	NewDescription = TemplateDescr;
	EndOfCopy = "";
	Counter = 1;
	TreeOfTemplates = FormAttributeToValue("Templates");
	While TreeOfTemplates.Rows.Find(NewDescription + EndOfCopy, "Presentation", True) <> Undefined Do
		If ThisIsCopying Then
			EndOfCopy = " - " + NStr("en = 'copy';");
		Else
			EndOfCopy = "";
		EndIf;
		
		If Counter > 1 Then
			EndOfCopy = EndOfCopy + " ("+Format(Counter, "NFD=0; NG=;")+")";
		EndIf;
		Counter = Counter + 1;
	EndDo;			
	Return NewDescription + EndOfCopy;
	
EndFunction

&AtClient
Procedure OnSelectingLayoutName(TemplateName, NotificationParameters) Export
	
	Copy = NotificationParameters.Copy;
	
	If Not ValueIsFilled(TemplateName) Then
		Return;
	EndIf;
	
	CurrentData = Items.Templates.CurrentData;
	
	TemplateType = ?(NotificationParameters.TemplateType = Undefined, CurrentData.TemplateType, NotificationParameters.TemplateType);
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("TemplateType", TemplateType);
	OpeningParameters.Insert("Owner", ?(ValueIsFilled(CurrentData.Owner), CurrentData.Owner, CurrentData.Id));
	OpeningParameters.Insert("DocumentName", TemplateName);

	If Copy Then
		OpeningParameters.Insert("TemplateMetadataObjectName", CurrentData.TemplateMetadataObjectName);
		OpeningParameters.Insert("Copy", Copy);
	EndIf;
	
	OpeningParameters.Insert("DataSource", CurrentData.Owner);
	OpeningParameters.Insert("IsPrintForm", True);
	OpeningParameters.Insert("IsValAvailable", True);
	
	If TemplateType = "MXL" Then
		FormParameters = StandardSubsystemsClient.SpreadsheetEditorParameters();
		FormParameters.Edit = True;
		CommonClientServer.SupplementStructure(FormParameters, OpeningParameters, True);
		StandardSubsystemsClient.ShowSpreadsheetEditor(Undefined, FormParameters,, ThisObject);
		Return;
	EndIf;
	
	If TemplateType = "DOCX" Then
		OpeningParameters.Insert("Edit", True);
		OpenForm("CommonForm.EditOfficeOpenDoc", OpeningParameters, ThisObject);
		Return;
	EndIf;
	
	OpenForm("InformationRegister.UserPrintTemplates.Form.EditTemplate2", OpeningParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure GoToList()
	
	CommandsOwner = Items.Templates.CurrentData;
	If CommandsOwner = Undefined Or StrStartsWith(CommandsOwner.Id, "Subsystem") Then
		Return;
	EndIf;
	
	Parent = CommandsOwner.GetParent();
	If Parent <> Undefined And Not StrStartsWith(Parent.Id, "Subsystem") Then
		CommandsOwner = Parent;
	EndIf;
	
	ListURL = GetURLToListForm(CommandsOwner.Owner);
	For Each ClientApplicationWindow In GetWindows() Do
		If ClientApplicationWindow.GetURL() = ListURL Then
			Form = ClientApplicationWindow.Content[0];
			NotifyDescription = New NotifyDescription("GoToListCompletion", ThisObject, 
				New Structure("Form, URL", Form, ListURL));
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
	
	FileSystemClient.OpenURL(ListURL);
EndProcedure

&AtServerNoContext
Function GetURLToListForm(MetadataObjectID)
	Return  "e1cib/list/" 
		+ Common.MetadataObjectByID(MetadataObjectID).FullName();
EndFunction

&AtClient
Procedure GoToListCompletion(QuestionResult, AdditionalParameters) Export
	If QuestionResult = "Cancel" Then
		Return;
	EndIf;
	
	AdditionalParameters.Form.Close();
	FileSystemClient.OpenURL(AdditionalParameters.URL);
EndProcedure


&AtServer
Function FindTemplate(Id, Val Branch1 = Undefined)
	
	If Branch1 = Undefined Then
		Branch1 = Templates;
	EndIf;
	
	For Each Template In Branch1.GetItems() Do
		If Template.Id = Id Then
			Return Template;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure DeleteTemplate(Command)
	
	CurrentData = Items.Templates.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	IdentifierOfTemplate = CurrentData.Id;
	DeleteLayoutOnServer(IdentifierOfTemplate);
	FoundTemplates = FindTemplates(IdentifierOfTemplate, Templates);
	For Each Template In FoundTemplates Do
		Template.GetParent().GetItems().Delete(Template);
	EndDo;
	
EndProcedure

&AtServer
Procedure DeleteLayoutOnServer(IdentifierOfTemplate)
	
	PrintManagement.DeleteTemplate(IdentifierOfTemplate);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();

	// Sections
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("Templates");
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue  = New DataCompositionField("Templates.IsSubsection");
	FilterElement.ComparisonType   = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.FunctionsPanelSectionColor);
	
	// Color of disabled items
	
	AppearanceItem = ConditionalAppearance.Items.Add();
	
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField("Templates");
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Templates.Used");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;
	
	AppearanceItem.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	// Hide the usage flag for groups
	
	AppearanceItem = ConditionalAppearance.Items.Add();
	
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField("TemplatesUsed");
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Templates.IsFolder");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;
	
	AppearanceItem.Appearance.SetParameterValue("Show", False);
	
	// Hide the usage flag for 1C-supplied templates.
	
	AppearanceItem = ConditionalAppearance.Items.Add();
	
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField("TemplatesUsed");
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Templates.Supplied");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;
	
	AppearanceItem.Appearance.SetParameterValue("Show", False);	
	
	// Filter
	
	AppearanceItem = ConditionalAppearance.Items.Add();
	
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField("Templates");

	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Templates.MatchesFilter");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;

	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Templates.HasItemsMatchingFilter");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;
	
	AppearanceItem.Appearance.SetParameterValue("Show", False);
	AppearanceItem.Appearance.SetParameterValue("Visible", False);
	
	// Mismatches 
	
	AppearanceItem = ConditionalAppearance.Items.Add();
	
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField("Templates");
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Templates.MatchesFilter");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Templates.HasItemsMatchingFilter");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Templates.SearchString");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotContains;
	FilterElement.RightValue = New DataCompositionField("SearchString");
	
	AppearanceItem.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

&AtServer
Procedure PopulateTemplateListBySections()
	
	Templates.GetItems().Clear();
	OutputCollection(Templates, Metadata.Subsystems);
	FillPrintFormsTemplatesTable(Templates);
	
EndProcedure

&AtServer
Procedure FillPrintFormsTemplatesTable(Branch1)
	
	ObjectsWithTemplates = New Map;
	For Each TemplateDetails In PrintManagement.PrintFormTemplates(True) Do
		ObjectsWithTemplates.Insert(TemplateDetails.Value, True);
	EndDo;
	
	MetadataObjects = New Array;
	For Each Object In ObjectsWithTemplates Do
		MetadataObjects.Add(Object.Key);
	EndDo;
	
	TemplateOwnersMap = Common.MetadataObjectIDs(MetadataObjects, False);
	
	LayoutOwners = New ValueList();
	For Each Source In TemplateOwnersMap Do
		If Not ValueIsFilled(Source.Value) Then
			Continue;
		EndIf;
		LayoutOwners.Add(Source.Value, Source.Value);
	EndDo;
	
	MetadataObjectIDs = LayoutOwners.UnloadValues();
	ValuesEmptyReferences = Common.ObjectsAttributeValue(MetadataObjectIDs, "EmptyRefValue");
	
	LayoutOwners.SortByPresentation();
	
	LayoutGroups = New Map();
	
	GroupOther = Branch1.GetItems().Add();
	GroupOther.Presentation = NStr("en = 'Other';");
	GroupOther.PictureGroup = PictureLib.Enum;
	GroupOther.Id = "CommonTemplates";
	GroupOther.UsagePicture = -1;
	GroupOther.IsFolder = True;
	GroupOther.Used = True;
	GroupOther.Owner = Catalogs.MetadataObjectIDs.EmptyRef();
	GroupOther.SearchString = Lower(GroupOther.Presentation);
	GroupOther.AvailableCreate = False;
	LayoutGroups.Insert(Catalogs.MetadataObjectIDs.EmptyRef(), GroupOther);
	
	AddingTemplatesIsAvailable = AccessRight("Insert", Metadata.Catalogs.PrintFormTemplates); 
	
	For Each Owner In LayoutOwners Do
		LayoutGroup = GroupOther.GetItems().Add();
		LayoutGroup.Presentation = Owner.Presentation;
		LayoutGroup.PictureGroup = New Picture;
		LayoutGroup.Id = Common.ObjectAttributeValue(Owner.Value, "FullName");
		LayoutGroup.UsagePicture = -1;
		LayoutGroup.IsFolder = True;
		LayoutGroup.Used = True;
		LayoutGroup.Owner = Owner.Value;
		LayoutGroup.SearchString = Lower(LayoutGroup.Presentation);
		LayoutGroup.AvailableCreate = False;
		LayoutGroup.GetItems().Add();
		
		LayoutGroups.Insert(Owner.Value, LayoutGroup);
	EndDo;
	
	OutputTemplates(GroupOther);
	
EndProcedure

&AtServer
Procedure OutputCollection(Val Branch1, Val MetadataObjectCollection)
	
	For Each MetadataObject In MetadataObjectCollection Do
		If TypeOf(Branch1) = Type("FormDataTreeItem") And MetadataObject.FullName() = Branch1.Id Then
			Continue;
		EndIf;
		
		If Not IsSubsystem(MetadataObject) And Not Common.IsDocumentJournal(MetadataObject)
			And ObjectsWithPrintCommands.FindByValue(MetadataObject.FullName()) = Undefined Then
			Continue;
		EndIf;
		
		If Not MetadataObjectAvailable(MetadataObject) Then
			Continue;
		EndIf;
		
		NewBranch = Branch1.GetItems().Add();
		NewBranch.Presentation = MetadataObject.Presentation();
		NewBranch.PictureGroup = PictureInInterface(MetadataObject);
		NewBranch.Id = MetadataObject.FullName();
		NewBranch.UsagePicture = -1;
		NewBranch.IsFolder = True;
		NewBranch.Used = True;
		NewBranch.SearchString = Lower(NewBranch.Presentation);
		
		If IsSubsystem(MetadataObject) Then
			OutputCollection(NewBranch, MetadataObject.Content);
			OutputCollection(NewBranch, MetadataObject.Subsystems);
			NewBranch.IsSubsection = MetadataObjectCollection <> Metadata.Subsystems;
		Else
			NewBranch.Owner = Common.MetadataObjectID(NewBranch.Id, False);
			NewBranch.AvailableCreate = Common.IsRefTypeObject(MetadataObject);
			NewBranch.GetItems().Add();
		EndIf;
		
		If IsSubsystem(MetadataObject) And NewBranch.GetItems().Count() = 0 Then
			IndexOf = Branch1.GetItems().IndexOf(NewBranch);
			Branch1.GetItems().Delete(IndexOf);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function PictureInInterface(MetadataObject)
	
	ObjectProperties = New Structure("Picture");
	FillPropertyValues(ObjectProperties, MetadataObject);
	If ValueIsFilled(ObjectProperties.Picture) Then
		Return ObjectProperties.Picture;
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtServerNoContext
Function IsSubsystem(MetadataObject)
	Return StrStartsWith(MetadataObject.FullName(), "Subsystem");
EndFunction

&AtServer
Function MetadataObjectAvailable(MetadataObject)
	
	If Not Common.IsCatalog(MetadataObject)
		And Not Common.IsDocument(MetadataObject)
		And Not Common.IsDocumentJournal(MetadataObject)
		And Not Common.IsChartOfCharacteristicTypes(MetadataObject)
		And Not Common.IsChartOfCharacteristicTypes(MetadataObject)
		And Not Common.IsChartOfAccounts(MetadataObject)
		And Not Common.IsChartOfCalculationTypes(MetadataObject)
		And Not Common.IsBusinessProcess(MetadataObject)
		And Not Common.IsTask(MetadataObject)
		And Not Metadata.DataProcessors.Contains(MetadataObject)
		And Not Metadata.Reports.Contains(MetadataObject)
		And Not IsSubsystem(MetadataObject) Then
		Return False;
	EndIf;
	
	AvailableByRights = AccessRight("View", MetadataObject);
	AvailableByFunctionalOptions = Common.MetadataObjectAvailableByFunctionalOptions(MetadataObject);
	
	MetadataProperties = New Structure("FullTextSearch, IncludeInCommandInterface");
	FillPropertyValues(MetadataProperties, MetadataObject);
	
	If MetadataProperties.FullTextSearch = Undefined Then 
		FullTextSearchUsing = True;
	Else 
		FullTextSearchUsing = (MetadataProperties.FullTextSearch = 
			Metadata.ObjectProperties.FullTextSearchUsing.Use);
	EndIf;
	
	If MetadataProperties.IncludeInCommandInterface = Undefined Then 
		IncludeInCommandInterface = True;
	Else 
		IncludeInCommandInterface = MetadataProperties.IncludeInCommandInterface;
	EndIf;
	
	Return AvailableByRights And AvailableByFunctionalOptions 
		And FullTextSearchUsing And IncludeInCommandInterface;
	
EndFunction

&AtServer
Function SubordinateCatalogs(MetadataObject)
	
	If SubordinateCatalogs = Undefined Then
		SubordinateCatalogs = New Map;
		
		For Each Catalog In Metadata.Catalogs Do
			If SubordinateCatalogs[Catalog] = Undefined Then
				SubordinateCatalogs[Catalog] = New Array;
			EndIf;
			For Each OwnerOfTheDirectory In Catalog.Owners Do
				If SubordinateCatalogs[OwnerOfTheDirectory] = Undefined Then
					SubordinateCatalogs[OwnerOfTheDirectory] = New Array;
				EndIf;
				ListOfReferenceBooks = SubordinateCatalogs[OwnerOfTheDirectory]; // Array
				ListOfReferenceBooks.Add(Catalog);
			EndDo;
		EndDo;
	EndIf;
	
	Return SubordinateCatalogs[MetadataObject];
	
EndFunction

&AtServer
Procedure OutputTemplates(ObjectDetails)
	
	If Not ValueIsFilled(ObjectDetails.Id) Then
		Return;
	EndIf;
	
	ObjectTemplates = ObjectTemplates(ObjectDetails.Id);
	Branch1 = ObjectDetails;
	ItemsCollection = Branch1.GetItems();
	
	For IndexOf = 0 To ObjectTemplates.Count() -1 Do
		TemplateDetails = ObjectTemplates[IndexOf];
		Template = ItemsCollection.Insert(IndexOf);
		FillPropertyValues(Template, TemplateDetails);
	EndDo;
	
EndProcedure

&AtServer
Function ObjectTemplates(MetadataObjectName)
	
	FoundItem = ObjectsWithPrintCommands.FindByValue(MetadataObjectName);
	If FoundItem = Undefined Then
		FoundItem = ObjectsWithPrintCommands.Add(MetadataObjectName);
	EndIf;
	
	If ValueIsFilled(FoundItem.Presentation) Then
		ObjectTemplates = Common.ValueFromXMLString(FoundItem.Presentation);
	Else
		ObjectTemplates = InformationRegisters.UserPrintTemplates.ObjectTemplates(MetadataObjectName);
		FoundItem.Presentation = Common.ValueToXMLString(ObjectTemplates);
	EndIf;
	
	Return ObjectTemplates;
	
EndFunction

&AtServer
Function FindBranchesOfTemplateOwner(Owner, CurBranch_, FoundBranches = Undefined)
	
	If FoundBranches = Undefined Then
		FoundBranches = New Array;
	EndIf;
	
	For Each Branch1 In CurBranch_.GetItems() Do
		If Branch1.IsFolder And Branch1.Owner = Owner Then
			FoundBranches.Add(Branch1);
		Else
			FindBranchesOfTemplateOwner(Owner, Branch1, FoundBranches)
		EndIf;
	EndDo;
	
	Return FoundBranches;
	
EndFunction

&AtClientAtServerNoContext
Function FindTemplates(Val Id, Val Branch1)
	
	Result = New Array;
	
	For Each Item In Branch1.GetItems() Do
		If Item.Id = Id Then
			Result.Add(Item);
		Else
			CommonClientServer.SupplementArray(Result, FindTemplates(Id, Item));
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function FindItemInTemplateTree(Val Id, Val Branch1 = Undefined)
	
	If Branch1 = Undefined Then
		Branch1 = Templates;
	EndIf;
	
	For Each Item In Branch1.GetItems() Do
		If Item.Id = Id Then
			FoundItem = Item;
		Else
			FoundItem = FindItemInTemplateTree(Id, Item);
		EndIf;

		If FoundItem <> Undefined Then
			Return FoundItem;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure ApplySelection()
	
	If FilterIs_Specified() Then
		UploadListOfTemplates();
	EndIf;
	
	MarkItemsMatchingFilter();
	
	If Not FilterIs_Specified() Then
		Return;
	EndIf;
	
	ExpandItemsMatchingFilter();

	If Items.Templates.CurrentData <> Undefined Then
		If MatchesFilter(Items.Templates.CurrentData) Then
			// Move to the next row if it's not visible after the list of visible rows is modified.
			CurrentRow = Items.Templates.CurrentRow;
			Items.Templates.CurrentRow = 0;
			Items.Templates.CurrentRow = CurrentRow;
		Else
			NavigateToFirstFoundTemplate();
		EndIf;
	EndIf;
	
	SetCommandBarButtonsEnabled();
	
EndProcedure

&AtClient
Procedure ExpandItemsMatchingFilter(Branch1 = Undefined)
	
	If Not ValueIsFilled(SearchString) Then
		Return;
	EndIf;
	
	If Branch1 = Undefined Then
		Branch1 = Templates;
	EndIf;
	
	For Each Item In Branch1.GetItems() Do
		CollectionOfSubordinateItems = Item.GetItems();
		If Item.HasItemsMatchingFilter And CollectionOfSubordinateItems.Count() > 0 
			And ValueIsFilled(CollectionOfSubordinateItems[0].Id) Then
			Items.Templates.Expand(Item.GetID(), False);
			ExpandItemsMatchingFilter(Item);
		EndIf;
	EndDo;
	
EndProcedure
	
&AtClient
Function MarkItemsMatchingFilter(Val Branch1 = Undefined)

	If Branch1 = Undefined Then
		Branch1 = Templates;
	EndIf;
	
	HasItemsMatchingFilter = Not FilterIs_Specified();
	
	For Each Item In Branch1.GetItems() Do
		Item.MatchesFilter = MatchesFilter(Item);
		Item.HasItemsMatchingFilter = MarkItemsMatchingFilter(Item);
		
		HasItemsMatchingFilter = HasItemsMatchingFilter 
			Or Item.MatchesFilter Or Item.HasItemsMatchingFilter;
	EndDo;
	
	Return HasItemsMatchingFilter;
	
EndFunction

&AtClient
Function MatchesFilter(Item)
	
	TheStringMatchesTheTemplate = Not ValueIsFilled(SearchString);
	
	If StrFind(SearchString, "*") Then
		SearchTemplate = Lower(TrimAll(SearchString));
	Else
		SearchTemplate = StrReplace(Lower(TrimAll(SearchString)), " ", "*");
	EndIf;
	
	TheStringMatchesTheTemplate = TheStringMatchesTheTemplate Or TheStringMatchesTheTemplate(Item.SearchString, SearchTemplate);
	
	Return TheStringMatchesTheTemplate
		And (Not Item.IsFolder And ShowChanged And Item.Changed 
			And (ShowUsed And Item.Used Or ShowUnused And Not Item.Used)
			Or ShowUnmodified And Not Item.Changed)
		And (Not ValueIsFilled(FilterByLanguage) Or StrFind(Item.AvailableLanguages, FilterByLanguage));
	
EndFunction

&AtClient
Function FilterIs_Specified()
	
	Return ValueIsFilled(SearchString) 
		Or FilterByTemplateUsage <> "AllMakets"
		Or ValueIsFilled(FilterByLanguage);
	
EndFunction

&AtServer
Procedure PopulateObjectsWithPrintCommands()
	
	For Each MetadataObject In PrintManagement.PrintCommandsSources() Do
		ObjectsWithPrintCommands.Add(MetadataObject.FullName());
	EndDo;
	
	ObjectsWithTemplates = New Map;
	For Each TemplateDetails In PrintManagement.PrintFormTemplates(True) Do
		ObjectsWithTemplates.Insert(TemplateDetails.Value, True);
	EndDo;
	
	MetadataObjects = New Array;
	For Each Object In ObjectsWithTemplates Do
		If Object.Key <> Metadata.CommonTemplates Then
			ObjectsWithPrintCommands.Add(Object.Key.FullName());
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Function NavigateToFirstFoundTemplate(Val Branch1 = Undefined)
	
	If Branch1 = Undefined Then
		Branch1 = Templates;
	EndIf;
	
	For Each Item In Branch1.GetItems() Do
		If Item.MatchesFilter Then
			Items.Templates.CurrentRow = Item.GetID();
			Return True;
		EndIf;
		If NavigateToFirstFoundTemplate(Item) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Procedure NavigateToItem(Val PathToItem, Val Branch1 = Undefined)
	
	If Branch1 = Undefined Then
		Branch1 = Templates;
	EndIf;
	
	PathParts = StrSplit(PathToItem, "/", False);
	If PathParts.Count() = 0 Then
		Return;
	EndIf;
	
	CurrentBranchID = PathParts[0];
	For Each Item In Branch1.GetItems() Do
		If Item.Id = CurrentBranchID Then
			If PathParts.Count() = 1 Then
				Items.Templates.CurrentRow = Item.GetID();
				Return;
			EndIf;
			
			ImportSubordinateItems(Item.GetID());
			
			PathParts.Delete(0);
			PathToItem = StrConcat(PathParts, "/");
			NavigateToItem(PathToItem, Item);
			Return;
		EndIf;
	EndDo;

EndProcedure

&AtClientAtServerNoContext
Function PathToItemInTree(Item)
	
	If Item = Undefined Then
		Return "";
	EndIf;
	
	Return PathToItemInTree(Item.GetParent()) + "/" + Item.Id;
	
EndFunction

&AtClientAtServerNoContext
Procedure ClearUpCache(MetadataObjectName, ObjectsWithPrintCommands)
	
	FoundItem = ObjectsWithPrintCommands.FindByValue(MetadataObjectName);
	If FoundItem = Undefined Then
		Return;
	EndIf;
	FoundItem.Presentation = "";
	
EndProcedure

&AtClient
Procedure UploadListOfTemplates()
	
	If IsDataImportInProgress Or Not HasObjectsWithNoCash() Then
		Return;
	EndIf;
	
	IsDataImportInProgress = True;
	Items.IsSearchRunning.Visible = True;
	
	TimeConsumingOperation = StartExecutionAtServer();
	CallbackOnCompletion = New NotifyDescription("ProcessResult", ThisObject);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CallbackOnCompletion, IdleParameters);
	
EndProcedure

&AtServer
Function StartExecutionAtServer()
	
	ExecutionParameters = TimeConsumingOperations.FunctionExecutionParameters(UUID);
	Return TimeConsumingOperations.ExecuteFunction(ExecutionParameters, 
		"InformationRegisters.UserPrintTemplates.ObjectsTemplates", ObjectsWithoutCache());
	
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure ProcessResult(Result, AdditionalParameters) Export
	
	IsDataImportInProgress = False;
	Items.IsSearchRunning.Visible = False;
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
		Return;
	EndIf;
	
	ProcessResultOnServer(Result.ResultAddress);
	RefreshVisibilityOfTemplates();
	
EndProcedure 

&AtServer
Procedure ProcessResultOnServer(ResultAddress)
	
	ObjectsTemplates = GetFromTempStorage(ResultAddress); // See InformationRegisters.UserPrintTemplates.ObjectsTemplates
	WriteTemplatesCache(ObjectsTemplates);
	
	ImportBranch(Templates);
	
EndProcedure

&AtClient
Function HasObjectsWithNoCash()
	
	For Each Item In ObjectsWithPrintCommands Do
		If Not ValueIsFilled(Item.Presentation) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Function ObjectsWithoutCache()
	
	Result = New Array;
	For Each Item In ObjectsWithPrintCommands Do
		If Not ValueIsFilled(Item.Presentation) Then
			If Item.Value = "CommonTemplates" Then
				Result.Add(Catalogs.MetadataObjectIDs.EmptyRef());
			Else
				Result.Add(Common.MetadataObjectID(Item.Value));
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Procedure WriteTemplatesCache(ObjectsTemplates)
	
	MetadataObjectIDs = Common.MetadataObjectIDs(ObjectsWithPrintCommands.UnloadValues(), False);

	For Each Item In ObjectsWithPrintCommands Do
		If ValueIsFilled(Item.Presentation) Then
			Continue;
		EndIf;
		
		If Item.Value = "CommonTemplates" Then
			Owner = Catalogs.MetadataObjectIDs.EmptyRef();
		Else
			Owner = MetadataObjectIDs[Item.Value];
		EndIf;
		
		FoundTemplates = ObjectsTemplates.FindRows(New Structure("Owner", Owner));
		ObjectTemplates = ObjectsTemplates.Copy(FoundTemplates);
		Item.Presentation = Common.ValueToXMLString(ObjectTemplates);
	EndDo;
	
EndProcedure

&AtServer
Procedure ImportBranch(Branch1)
	
	For Each Item In Branch1.GetItems() Do
		ImportSubordinateItems(Item.GetID());
		ImportBranch(Item);
	EndDo;
	
EndProcedure

&AtClient
Function TheStringMatchesTheTemplate(Val String, Val Template)
	
	String = StrConcat(StrSplit(String, " " + Chars.LF + Chars.CR + Chars.Tab, False), " ");
	TheStringMatchesTheTemplate = True;
	
	For Each PartsOfTheTemplate In StrSplit(Template, "*", False) Do
		FragmentToSearchFor = StrConcat(StrSplit(PartsOfTheTemplate, " " + Chars.LF + Chars.CR + Chars.Tab, False), " ");
		
		Position = StrFind(String, FragmentToSearchFor);
		If Position = 0 Then
			TheStringMatchesTheTemplate = False;
			Break;
		EndIf;
		
		String = Mid(String, Position + StrLen(FragmentToSearchFor));
	EndDo;
	
	Return TheStringMatchesTheTemplate;
	
EndFunction

&AtServerNoContext
Function TemplateOwnerID(TemplatePath)
	
	TemplateDataSource = PrintManagement.TemplateDataSource(TemplatePath);
	
	If Not ValueIsFilled(TemplateDataSource) Then
		Return Undefined;
	EndIf;
	
	MetadataObjects = Common.MetadataObjectsByIDs(TemplateDataSource, False);
	TemplateOwnerID = Undefined;
	
	For Each DataSource In TemplateDataSource Do
		If MetadataObjects[DataSource] <> Undefined Then
			TemplateOwnerID = MetadataObjects[DataSource].FullName();
			Break;
		EndIf;
	EndDo;
	
	Return TemplateOwnerID;
	
EndFunction

&AtServer
Function TemplatePositionInTree(Val TemplatePath)
	
	Result = "";
	
	TemplateOwnerID = TemplateOwnerID(TemplatePath);
	LayoutOwner = FindItemInTemplateTree(TemplateOwnerID);
	
	If LayoutOwner <> Undefined Then
		Result = PathToItemInTree(LayoutOwner) + "/" + TemplatePath;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion
