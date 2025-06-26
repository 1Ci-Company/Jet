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
Var SimpleDescriptionProcedureTitle;
&AtClient
Var ParametersOfTheAttachedHandler;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StartFromConfiguration = TypeOf(DataProcessorObject2()) = Type("DataProcessorObject.UpdateHandlersDetails");
	InitializeDataProcessorConstants();
	Items.ErrorFileDirectory.Visible = Items.ExecuteQueueBuildingTest.Visible;
	
	SetConditionalAppearance();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
#If WebClient Then
	Raise NStr("en = 'Web client usage is not supported.';");
#EndIf
	
	If StrFind(LaunchParameter,"=") > 0 Then
		
		ParametersStructure = GetParametersFromString(LaunchParameter);
		
		If Not ValueIsFilled(ErrorFileDirectory) Then
			ErrorFileDirectory = TempDirectory();
		EndIf; 
		
		If ParametersStructure.Property("ErrorLogFolder") Then
			ErrorFileDirectory = ParametersStructure.ErrorLogFolder;
		EndIf;
		
		If ParametersStructure.Property("ErrorAddInfo") Then
			ErrorTextAddition = ParametersStructure.ErrorAddInfo;
		EndIf;
		
		If ParametersStructure.Property("ResultFile") Then
			ResultFile = ParametersStructure.ResultFile;
		EndIf;
		
#If Not WebClient Then
		If ParametersStructure.Property("DetectionTime") And ValueIsFilled(ParametersStructure.DetectionTime) Then
			ErrorDetectionDate = XMLValue(Type("Date"), ParametersStructure.DetectionTime);
		EndIf;
#EndIf
		
		If ParametersStructure.Property("RepoPath") Then
			RepositoryAddress = ParametersStructure.RepoPath;
		EndIf;
		
		StartCheck = StrFind(LaunchParameter,"Execute") <> 0;
		FinishWork   = StartCheck;
		
		Try
			
			If StartCheck Then
				ExecuteQueueBuildingTest(Undefined);
			EndIf;
			
		Except
			
			WriteErrorInformation(ResultFile);
			
		EndTry; 
		
		Try
			
			If StartCheck And ValueIsFilled(ResultFile) Then
				Result = New TextDocument;
				Result.SetText(Object.Errors.Count());
				Result.Write(ResultFile);
			EndIf;
			
		Except
			
			WriteErrorInformation(ResultFile);
			
		EndTry;
		
		If FinishWork Then
			Terminate();
		EndIf;
		
	EndIf;
	
	AttachIdleHandler("ExecuteHandlersImport", 0.1, True);
	
	ApplySettingsGroupAppearance();
	If ExtendedFormMode Then
		SetAdvancedMode();
	Else
		SetSimplifiedMode();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Modified And Not Exit Then
		Cancel = True;
		ResponseHandler1 = New NotifyDescription("FormClosingCompletion", ThisObject);
		ShowQueryBox(ResponseHandler1, NStr("en = 'The data has been changed. Do you want to save the changes to the repository?';"), QuestionDialogMode.YesNoCancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure FormClosingCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Modified = False;
		WriteDataToDisk();
		Close();
	ElsIf Result = DialogReturnCode.Cancel Then
		// No action required.
	Else
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	Object.SRCDirectory = Settings["Object.SRCDirectory"];
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "UpdateHandlerDetailsChanged" Then
		UpdateHandlerConflictsData(Parameter);
		Notify("DataOnUpdateHandlerConflictsUpdated", Parameter);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SRCDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
#If Not WebClient Then
		StandardProcessing = False;
		
		FileSelectionHandler = New NotifyDescription("DirectorySelectionDialogBoxCompletion", ThisObject, "SRCDirectory");
		FileSystemClient.SelectDirectory(FileSelectionHandler, NStr("en = 'Select a SRC directory';"), Object.SRCDirectory);
		
#EndIf
EndProcedure

&AtClient
Procedure SRCDirectoryTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	
	StandardProcessing = False;
	Object.SRCDirectory = AddPathSeparatorToEnd(Text);
	
EndProcedure

&AtClient
Procedure ErrorFileDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
#If Not WebClient Then
		StandardProcessing = False;
		
		FileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
		FileDialog.FullFileName = ErrorFileDirectory;
		FileSelectionHandler = New NotifyDescription("DirectorySelectionDialogBoxCompletion", ThisObject, "ErrorFileDirectory");
		FileSystemClient.SelectDirectory(FileSelectionHandler, NStr("en = 'Specify an error files directory';"), ErrorFileDirectory);
#EndIf
EndProcedure

&AtClient
Procedure ErrorFileDirectoryTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	
	StandardProcessing = False;
	ErrorFileDirectory = AddPathSeparatorToEnd(Text);
	ApplySettingsGroupAppearance();
	
EndProcedure

&AtClient
Procedure SubsystemChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AttachIdleHandler("Attachable_ProcessingSubsystemSelection", 0.1, True);
	
EndProcedure

&AtClient
Procedure Attachable_ProcessingSubsystemSelection()
	
	If ValueIsFilled(CurrentLibrary) Then
		Filter = New Structure("Subsystem", CurrentLibrary);
		SetHandlersFilter(Filter);
	Else
		DisableHandlersFilter("Subsystem");
	EndIf;
	
EndProcedure

&AtClient
Procedure ObjectToChangeOnChange(Item)
	
	OnChangeSearchObjectAtServer("ObjectsToChange", ObjectToChange);
	
EndProcedure

&AtClient
Procedure ObjectToChangeClearing(Item, StandardProcessing)
	
	OnChangeSearchObjectAtServer("ObjectsToChange", ObjectToChange);
	
EndProcedure

&AtClient
Procedure ObjectToReadOnChange(Item)
	
	OnChangeSearchObjectAtServer("ObjectsToRead", ObjectToRead);
	
EndProcedure

&AtClient
Procedure ObjectToReadClearing(Item, StandardProcessing)
	
	OnChangeSearchObjectAtServer("ObjectsToRead", ObjectToRead);
	
EndProcedure

&AtClient
Procedure QuickFiltersURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	If FormattedStringURL = "OtherItems" Then
		SelectQuickFilter = New NotifyDescription("QuickFilterChoiceProcessing", ThisObject);
		OtherQuickFilters.ShowChooseItem(SelectQuickFilter);
		Return;
	Else
		SetQuickFilter(FormattedStringURL);
	EndIf;
	
EndProcedure

&AtClient
Procedure QuickFilterChoiceProcessing(Result, AdditionalParameters1) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	SetQuickFilter(Result);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure UpdateHandlersSelection(Item, RowSelected, Field, StandardProcessing)
	
	OpenHandlerDetailsEditor(Item.CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure HandlerEditingCompletion(Result, AdditionalParameters) Export
	
	If CurrentItem <> Undefined And CurrentItem.Name <> "UpdateHandlers" Then
		CurrentItem = Items.UpdateHandlers;
		If CurrentItem.CurrentItem  <> Undefined And CurrentItem.CurrentItem.Name <> "UpdateHandlersProcedure" Then
			CurrentItem.CurrentItem = Items.UpdateHandlersProcedure;
		EndIf;
	EndIf;
	
	If ValueIsFilled(Result) Then
		UpdateHandlerData(Result);
	ElsIf Items.UpdateHandlers.CurrentData <> Undefined 
			And Items.UpdateHandlers.CurrentData.NewRow Then
		CurrentRow = Object.UpdateHandlers.FindByID(Items.UpdateHandlers.CurrentRow);
		Object.UpdateHandlers.Delete(CurrentRow);
		Items.UpdateHandlers.CurrentRow = SourceCurrentRow;
	EndIf;
	SourceCurrentRow = 0;
	
EndProcedure

&AtClient
Procedure UpdateHandlersBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	ResponseHandler1 = New NotifyDescription("HandlerDetailsDeletionCompletion", ThisObject);
	QueryText = NStr("en = 'Do you want to delete handler details?';");
	ShowQueryBox(ResponseHandler1, QueryText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure HandlerDetailsDeletionCompletion(Result, AdditionalProperties) Export
	
	Item = Items.UpdateHandlers;
	If Result = DialogReturnCode.Yes Then
		Modified = True;
		SourceCurrentRow = Item.CurrentRow;
		If Item.SelectedRows.Count() > 0 Then
			LinesToDelete = New Array;
			For Each RowID In Item.SelectedRows Do
				LinesToDelete.Add(RowID);
			EndDo;
			DeleteHandlersDetails(LinesToDelete);
		Else
			DeleteHandlersDetails(Item.CurrentData.Ref);
		EndIf;
		Item.CurrentRow = SourceCurrentRow+1;
		SourceCurrentRow = 0;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateHandlersBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	SourceCurrentRow = Item.CurrentRow;
	
EndProcedure

&AtClient
Procedure UpdateHandlersOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		SourceRef1 = Item.CurrentData.Ref;
		Item.CurrentData.NewRow = True;
		Item.CurrentData.Changed = True;
		Item.CurrentData.Ref = New UUID;
		If Copy Then
			Item.CurrentData.Id = "";
		Else
			Item.CurrentData.ExecutionMode = "Deferred";
			Item.CurrentData.DeferredHandlersExecutionMode = "Parallel";
			If ValueIsFilled(Item.RowFilter) And Item.RowFilter.Property("Subsystem") Then
				Item.CurrentData.Subsystem = Item.RowFilter.Subsystem;
			EndIf;
		EndIf;
		OpenHandlerDetailsEditor(Item.CurrentData.Ref, NewRow, SourceRef1);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateHandlersTechDesignOnChange(Item)
	
	FillQuickFilters();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ImportHandlers(Command)
	
	TechDesignHandlers = ImportTechnicalDesignHandlersList();
	ImportFromCurrentConfigurationAtServer(TechDesignHandlers);
	Items.ImportExportSettingsGroup.Hide();
	
EndProcedure

&AtClient
Procedure BuildQueue(Command)
	
	BuildQueueAtServer();
	Items.ImportExportSettingsGroup.Hide();
	
EndProcedure

&AtClient
Procedure SaveToRepository(Command)
	
	If Not TheSRCDirectoryIsSpecifiedCorrectly() Then
		Return;
	EndIf;
	
	WriteDataToDisk();
	Items.ImportExportSettingsGroup.Hide();
	Modified = False;
	
EndProcedure

&AtClient
Procedure SaveAllHandlersToRepository(Command)
	
	If Not TheSRCDirectoryIsSpecifiedCorrectly() Then
		Return;
	EndIf;
	
	Items.ImportExportSettingsGroup.Hide();
	Modified = False;
	
	SavingParameters = New Structure("AllHandlers", True);
	ResponseHandler1 = New NotifyDescription("RepositorySaveCompletion", ThisObject, SavingParameters);
	QueryText = NStr("en = 'Warning. All update handler details procedures will be overwritten.
						|Continue?';");
	ShowQueryBox(ResponseHandler1, QueryText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure ShowUpdateHandlersDetailsCode(Command)
	
	CodeGenerationParameters = NewCodeGenerationParameters();
	If ExtendedFormMode Then
		CodeGenerationParameters.UpdateQueue = False;
	Else
		CodeGenerationParameters.DetailsInCommonModule = True;
		CodeGenerationParameters.UpdateCallsList = False;
	EndIf;
	ShowUpdateHandlersDetailsTexts(CodeGenerationParameters);
	
EndProcedure

&AtClient
Procedure SetBuildNumberForHandlers(Command)
	
	AdditionalParameters = New Structure("BuildNumberForHandlers", True);
	ResponseHandler1 = New NotifyDescription("BuildNumberInputCompletion", ThisObject, AdditionalParameters);
	VersionNumbers = StrSplit(ConfigurationVersion,".");
	ShowInputNumber(ResponseHandler1, Number(VersionNumbers[3])+1, NStr("en = 'New build number';"));
	
EndProcedure

&AtClient
Procedure WriteTechnicalDesignHandlersList(Command)
	
	SaveTechnicalDesignHandlersList();
	
EndProcedure

&AtClient
Procedure SwitchFormMode(Command)
	
	If ExtendedFormMode Then
		SetSimplifiedMode();
	Else
		SetAdvancedMode();
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveToFile(Command)
	
#If Not WebClient Then
		
		FileSelectionHandler = New NotifyDescription("FileDialogCompletion", ThisObject, "");
		FileDialog = New FileDialog(FileDialogMode.Save);
		FileDialog.Title = NStr("en = 'Specify a file name';");
		FileDialog.Filter = FilterBackupFiles();
		FileDialog.Multiselect = False;
		FileSystemClient.ShowSelectionDialog(FileSelectionHandler, FileDialog);
		
#EndIf
	
EndProcedure

&AtClient
Procedure LoadFromFile(Command)
	
#If Not WebClient Then
		
		Notification = New NotifyDescription("SelectFileAfterPutFiles", ThisObject);
		ImportParameters = FileSystemClient.FileImportParameters();
		ImportParameters.Dialog.Title = NStr("en = 'Select file';");
		ImportParameters.Dialog.Filter = FilterBackupFiles();
		ImportParameters.FormIdentifier = UUID;
		FileSystemClient.ImportFile_(Notification, ImportParameters);
		
#EndIf
	
EndProcedure

#Region DebuggingSubmenu

&AtClient
Procedure CheckConflicts(Command)
	
	CheckConflictsAtServer();
	
EndProcedure

&AtClient
Procedure OnAddUpdateHandlers_Calls(Command)
	
	CodeGenerationParameters = NewCodeGenerationParameters();
	CodeGenerationParameters.UpdateQueue = False;
	ShowUpdateHandlersDetailsTexts(CodeGenerationParameters);
	
EndProcedure

&AtClient
Procedure OnAddUpdateHandlers_Details(Command)
	
	CodeGenerationParameters = NewCodeGenerationParameters();
	CodeGenerationParameters.DetailsInCommonModule = True;
	ShowUpdateHandlersDetailsTexts(CodeGenerationParameters);
	
EndProcedure

&AtClient
Procedure ShowSettings(Command)
	
	SettingsTexts = GetSettingsTexts();
	For Each FileText In SettingsTexts Do
		TextDocument = New TextDocument;
		TextDocument.SetText(FileText.Value);
		TextDocument.Show(FileText.Presentation);
	EndDo;
	
EndProcedure

&AtClient
Procedure ShowTabularSections(Command)
	
	TablesData = ExportTablesToMXL();
	For Each Table In TablesData Do
		Table.Value.Show(Table.Key);
	EndDo;
	
EndProcedure

&AtClient
Procedure ShowPrioritiesHandlerConflicts(Command)
	
	If Items.UpdateHandlers.CurrentData = Undefined Then
		ShowMessageBox(,NStr("en = 'Update handler is not selected';"));
		Return;
	EndIf;
	
	TablesData = ExportTablesToMXL(
		Items.UpdateHandlers.CurrentData.Ref, "ExecutionPriorities,HandlersConflicts");
	For Each Table In TablesData Do
		Table.Value.Show(Table.Key);
	EndDo;
	
EndProcedure

&AtClient
Procedure ShowHandlerObjects(Command)
	
	If Items.UpdateHandlers.CurrentData = Undefined Then
		ShowMessageBox(,NStr("en = 'Update handler is not selected';"));
		Return;
	EndIf;
	
	TablesData = ExportTablesToMXL(
		Items.UpdateHandlers.CurrentData.Ref, "ObjectsToRead,ObjectsToChange,ObjectsToLock");
	For Each Table In TablesData Do
		Table.Value.Show(Table.Key);
	EndDo;
	
EndProcedure

&AtClient
Procedure ExecuteQueueBuildingTest(Command)
	
#Region ErrorFileDirectoryCheck
	If Command <> Undefined Then
		Items.ErrorFileDirectory.Visible = True;
		ApplySettingsGroupAppearance();
		If Not ValueIsFilled(ErrorFileDirectory) Then
			CommonClient.MessageToUser(
				NStr("en = 'Error files directory is not specified.';"),
				,
				,
				"ErrorFileDirectory");
				Return;
		EndIf;
	EndIf;
#EndRegion
	
	Object.Errors.Clear();
	BuildQueueAtServer();
	For Each Error In Object.Errors Do
		WriteError(Error.MetadataObject, Error.Message);
	EndDo;
	
EndProcedure

&AtClient
Procedure CalculateQueue(Command)
	CalculateQueueAtServer();
EndProcedure

&AtClient
Procedure ShowAllModulesTexts(Command)
	
	CodeGenerationParameters = NewCodeGenerationParameters();
	CodeGenerationParameters.UpdateQueue = False;
	CodeGenerationParameters.OnlyChangedItems = False; 
	ModulesTexts = GetModulesTexts(CodeGenerationParameters);
	For Each ModuleCode In ModulesTexts Do
		TextDocument = New TextDocument;
		TextDocument.SetText(ModuleCode.ProcedureText);
		TextDocument.Show(ModuleCode.ModuleName);
	EndDo;
	Items.ImportExportSettingsGroup.Hide();
	Modified = False;
	
EndProcedure

&AtClient
Procedure ShowModulesText(Command)
	
	CodeGenerationParameters = NewCodeGenerationParameters();
	CodeGenerationParameters.OnlyChangedItems = False;
	CodeGenerationParameters.OnlySelectedItems = True; 
	ModulesTexts = GetModulesTexts(CodeGenerationParameters);
	For Each ModuleCode In ModulesTexts Do
		TextDocument = New TextDocument;
		TextDocument.SetText(ModuleCode.ProcedureText);
		TextDocument.Show(ModuleCode.ModuleName);
	EndDo;
	Items.ImportExportSettingsGroup.Hide();
	Modified = False;
	
EndProcedure

&AtClient
Procedure SetAutoOrder(Command)
	
	For Each Priority In Object.ExecutionPriorities Do
		Priority.Order = Priority.OrderAuto;
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
#Region StatusChangedCheckProcedure
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UpdateHandlersIssueStatus.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField(Items.UpdateHandlersChangedCheckProcedure.DataPath);
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Text", StatusChangedCheckProcedure);
	Item.Appearance.SetParameterValue("TextColor", WebColors.Goldenrod);
#EndRegion
	
#Region LowPriorityReadingStatus
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UpdateHandlersIssueStatus.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField(Items.UpdateHandlersLowPriorityReading.DataPath);
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Text", LowPriorityReadingStatus);
	Item.Appearance.SetParameterValue("TextColor", StyleColors.SpecialTextColor);
#EndRegion
	
#Region AnalysisRequiredStatus
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UpdateHandlersIssueStatus.Name);
	
	AndGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	
		ItemFilter = AndGroup.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField(Items.UpdateHandlersExecutionOrderSpecified.DataPath);
		ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
		ItemFilter.RightValue = False;
		
		OrGroup = AndGroup.Items.Add(Type("DataCompositionFilterItemGroup"));
		
			ItemFilter = OrGroup.Items.Add(Type("DataCompositionFilterItem"));
			ItemFilter.LeftValue = New DataCompositionField(Items.UpdateHandlersDataToReadWriter.DataPath);
			ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
			ItemFilter.RightValue = True;
			
			ItemFilter = OrGroup.Items.Add(Type("DataCompositionFilterItem"));
			ItemFilter.LeftValue = New DataCompositionField(Items.UpdateHandlersWriteAgain.DataPath);
			ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
			ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.SpecialTextColor);
#EndRegion
	
#Region TechnicalDesign
	Item = ConditionalAppearance.Items.Add();
	
	For Each FormItem In Items.UpdateHandlers.ChildItems Do
		ItemField = Item.Fields.Items.Add();
		ItemField.Field = New DataCompositionField(FormItem.Name);
	EndDo;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField(Items.UpdateHandlersTechDesign.DataPath);
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("BackColor", WebColors.Gainsboro);
#EndRegion
	
EndProcedure

#Region HandlersImport

&AtClient
Procedure ExecuteHandlersImport()
	
	ImportHandlers(Undefined);
	Items.Pages.CurrentPage = Items.HandlersPage;
	
EndProcedure

&AtServer
Procedure ImportFromCurrentConfigurationAtServer(TechDesignHandlers = Undefined)
	
	DataProcessor = DataProcessorObject2();
	DataProcessor.ImportHandlers();
	ValueToFormAttribute(DataProcessor, "Object");
	
	If TechDesignHandlers <> Undefined Then
		For Each Handler In TechDesignHandlers Do
			If StrFind(Handler,":") = 0 Then
				Continue;
			EndIf;
			Data = StrSplit(Handler, ":");
			Filter = New Structure;
			If ValueIsFilled(Data[0]) Then
				Filter.Insert("Id", Data[0]);
			EndIf;
			If ValueIsFilled(Data[1]) Then
				Filter.Insert("Procedure", Data[1]);
			EndIf;
			FoundHandlers = Object.UpdateHandlers.FindRows(Filter);
			For Each Found3 In FoundHandlers Do
				Found3.TechnicalDesign = True;
			EndDo;
		EndDo;
	EndIf;
	
	UpdateFormData(DataProcessor);
	
	CurrentLibrary = "";
	Modified = False;
	
EndProcedure

&AtClient
Function ImportTechnicalDesignHandlersList()
	
	FileName = SettingsDirectory() + "tech-project.updaters";
	
	File = New File(FileName);
	If Not File.Exists() Then
		Return Undefined;
	EndIf;
	
	SettingsFile = New TextDocument;
#If Not WebClient Then
	SettingsFile.Read(FileName, TextEncoding.UTF8);
#EndIf
	FileText = SettingsFile.GetText();
	TechDesignHandlers = StrSplit(FileText, Chars.LF);
	
	Return TechDesignHandlers;
	
EndFunction

#EndRegion

#Region RepositorySave

&AtClient
Function TheSRCDirectoryIsSpecifiedCorrectly()
	
	Result = True;
	If Not ValueIsFilled(Object.SRCDirectory) Then
		CommonClient.MessageToUser(
			NStr("en = 'SRC directory path is not specified';"),
			,
			,
			"Object.SRCDirectory");
		Result = False;
	EndIf;
	
	DirectoryOnHardDrive = New File(Object.SRCDirectory);
	If Not DirectoryOnHardDrive.Exists() Then
		CommonClient.MessageToUser(
			NStr("en = 'SRC directory is not found';"),
			,
			,
			"Object.SRCDirectory");
		Result = False;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure RepositorySaveCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		WriteDataToDisk(AdditionalParameters.AllHandlers);
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteDataToDisk(AllHandlers = False)
	
	ClearMessages();
	SimpleDescriptionProcedureTitle = "Procedure OnAddUpdateHandlers(Handlers) Export";
	CodeGenerationParameters = NewCodeGenerationParameters();
	CodeGenerationParameters.OnlyChangedItems = Not AllHandlers;
	ModulesTexts = GetModulesTexts(CodeGenerationParameters);
	SaveVersionToConfigurationRoot();
	For Each ModuleText In ModulesTexts Do
		ReplaceModuleProcedure(ModuleText);
	EndDo;
	SaveTechnicalDesignHandlersList();
	NewConfigurationBuildNumber = 0;
	
EndProcedure

&AtClient
Function AddModuleProcedure(Code)
	
	ProcedureAdded = False;
	FullFileName = Object.SRCDirectory + Code.ModulePath;
	ModuleStrings = FileTextToArray(FullFileName);
	IsManagerModule = StrFind(Code.ModuleName, ".") > 0;
	ProcedureName = ProcedureName(Code.ProcedureTitle);
	
	ProcedureComment = 
	"// see. InfobaseUpdateSSL.OnAddUpdateHandlers
	|%1";
	ProcedureText = StringFunctionsClientServer.SubstituteParametersToString(ProcedureComment, Code.ProcedureText);
	
	// If the module is empty, populate it from an empty module template (applicable for manager modules).
	If IsManagerModule And ModuleStrings.Count() = 0 Then
		EmptyModuleManager = 
		"#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		|
		|#Area Private
		|
		|#Area InfobaseUpdate
		|
		|%1
		|
		|#EndRegion
		|
		|#EndRegion
		|
		|#EndIf";
		NewText = StringFunctionsClientServer.SubstituteParametersToString(EmptyModuleManager, ProcedureText);
		WriteModuleText(NewText, FullFileName);
		
		Template = NStr("en = 'The ""%2"" procedure is added to the ""%1"" module';");
		CommonClient.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(Template, Code.ModuleName, ProcedureName));
		Return True;
	EndIf;
	
	HasDetailsProcedure = ModuleStrings.Find(SimpleDescriptionProcedureTitle) <> Undefined
		Or ModuleStrings.Find("Procedure UpdateHandlersDetails(Handlers) Export") <> Undefined;
	
	ThereIsALibraryDescriptionProcedure = False;
	If Code.IsDetailsProcedure Then
		For Each LibraryName In Code.LibrariesNames Do
			TitleTemplate1 = "Procedure UpdateHandlersDetails%1(Handlers) Export";
			FoundTheProcedureTitle = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, LibraryName);
			If ModuleStrings.Find(FoundTheProcedureTitle) <> Undefined Then
				ThereIsALibraryDescriptionProcedure = True;
				Break;
			EndIf;
			// "The OnAddUpdateHandlers%1(Handlers) Export"
			TitleTemplate1 = StrReplace(SimpleDescriptionProcedureTitle, "(", "%1(");
			FoundTheProcedureTitle = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, LibraryName);
			If ModuleStrings.Find(FoundTheProcedureTitle) <> Undefined Then
				ThereIsALibraryDescriptionProcedure = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	ThereIsAPassedProcedure = ModuleStrings.Find(Code.ProcedureTitle) <> Undefined;
	PassedASimpleProcedure = Code.ProcedureTitle = SimpleDescriptionProcedureTitle;
	
	// If the procedure is found, exit.
	If ThereIsAPassedProcedure
		Or HasDetailsProcedure
		Or ThereIsALibraryDescriptionProcedure And PassedASimpleProcedure Then
		Return ProcedureAdded;
	EndIf;
	
	// If either "#Region NewInfobaseVersionsUpdate" or "#Region InfobaseUpdate" is present,
	// then insert this code right at the top of the region.
	IndexOf = ModuleStrings.Find("#Area InfobaseUpdate");
	If IndexOf <> Undefined Then
		IndexOf = IndexOf + 1;
		ModuleStrings.Insert(IndexOf, "");
		ProcedureLines = StrSplit(ProcedureText, Chars.LF);
		For Each NewRow In ProcedureLines Do
			IndexOf = IndexOf + 1;
			ModuleStrings.Insert(IndexOf, NewRow);
		EndDo;
		ProcedureAdded = True;
	EndIf;
	
	// If a procedure handler is present, insert before it.
	If Not ProcedureAdded And Not IsBlankString(Code.ProcessingProcedure) Then
		Names = StrSplit(Code.ProcessingProcedure, ".");
		UpdateProcedureName = Names[Names.UBound()];
		InsertIndex = ModuleStrings.Find("Procedure "+UpdateProcedureName+"(Parameters) Export");
		If InsertIndex <> Undefined Then
			ProcedureLines = StrSplit(ProcedureText, Chars.LF);
			ModuleStrings.Insert(InsertIndex, "");
			IndexOf = ProcedureLines.UBound();
			For ShiftToTop = 0 To ProcedureLines.UBound() Do
				ProcedureLine = ProcedureLines[IndexOf - ShiftToTop];
				ModuleStrings.Insert(InsertIndex, ProcedureLine);
			EndDo;
			ProcedureAdded = True;
		EndIf;
	EndIf;
	
	AreaText = 
	"#Area InfobaseUpdate
	|
	|%1
	|
	|#EndRegion";
	
	// If no update area and handler procedure are found, search for Private and insert in it as the first area.
	If Not ProcedureAdded And Not IsBlankString(Code.ProcessingProcedure) Then
		IndexOf = ModuleStrings.Find("#Area Private");
		If IndexOf <> Undefined Then
			AreaText = StringFunctionsClientServer.SubstituteParametersToString(AreaText, ProcedureText);
			IndexOf = IndexOf + 1;
			ModuleStrings.Insert(IndexOf, "");
			AreaLines = StrSplit(AreaText, Chars.LF);
			For Each NewRow In AreaLines Do
				IndexOf = IndexOf + 1;
				ModuleStrings.Insert(IndexOf, NewRow);
			EndDo;
			ProcedureAdded = True;
		EndIf;
	EndIf;
	
	// If no update area, handler procedure, and the Private area are found, insert to the module's end.
	If Not ProcedureAdded And Not IsBlankString(Code.ProcessingProcedure) Then
		
		AreaText = StringFunctionsClientServer.SubstituteParametersToString(AreaText, ProcedureText);
		
		InsertIndex = ModuleStrings.UBound();
		LastRow = TrimAll(ModuleStrings[InsertIndex]);
		While IsBlankString(LastRow) Do
			InsertIndex = InsertIndex - 1;
			LastRow = TrimAll(ModuleStrings[InsertIndex]);
		EndDo;
		
		If LastRow = "#EndIf" Then
			InsertIndex = InsertIndex - 1;
			ModuleStrings.Insert(InsertIndex, "");
			AreaLines = StrSplit(AreaText, Chars.LF);
			IndexOf = AreaLines.UBound();
			For ShiftToTop = 0 To AreaLines.UBound() Do
				ProcedureLine = AreaLines[IndexOf - ShiftToTop];
				ModuleStrings.Insert(InsertIndex, ProcedureLine);
			EndDo;
		Else
			ModuleStrings.Add("");
			AreaLines = StrSplit(AreaText, Chars.LF);
			For Each NewRow In AreaLines Do
				ModuleStrings.Add(NewRow);
			EndDo;
		EndIf;
		ProcedureAdded = True;
	EndIf;
	
	If ProcedureAdded Then
		NewText = StrConcat(ModuleStrings, Chars.LF);
		WriteModuleText(NewText, FullFileName);
		
		Template = NStr("en = 'The ""%2"" procedure is added to the ""%1"" module';");
		CommonClient.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(Template, Code.ModuleName, ProcedureName));
	Else
		Template = NStr("en = 'Cannot add the ""%2"" procedure to the ""%1"" module.
		|The ""%3"" region might be not set in the module.
		|Add the procedure or region manually and record the handlers again.';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(Template, Code.ModuleName, ProcedureName, "InfobaseUpdate");
		Raise MessageText;
	EndIf;
	
	Return ProcedureAdded;
	
EndFunction

&AtClient
Procedure ReplaceModuleProcedure(Code)
	
	If Code.IsDetailsProcedure And AddModuleProcedure(Code) Then
		Return;
	EndIf;
	
	FullFileName = Object.SRCDirectory + Code.ModulePath;
	NewModule = New TextDocument;
	
	NewProcedureText = StrSplit(Code.ProcedureText, Chars.LF);
	ProcedureEnd = NewProcedureText[NewProcedureText.UBound()];
	
	SetVersion = ValueIsFilled(Code.Version);
	
	WasReplaced = False;
	VersionSet = False;
	ThisIsTheUpdateModule = StrStartsWith(Code.ModuleName, "InfobaseUpdate");
#If Not WebClient Then
	Module = New TextReader;
	Module.Open(FullFileName, "UTF-8");
	ModuleString = "";
	While ModuleString <> Undefined Do

		ModuleString = Module.ReadLine();
		If ModuleString = Undefined Then
			Break;
		EndIf;
	
#Region OnAddSubsystem
		If SetVersion And TrimAll(ModuleString) = Code.VersionProcedure Then
			NewModule.AddLine(ModuleString);
			While StrFind(ModuleString, "LongDesc.Version =") = 0 Do
				ModuleString = Module.ReadLine();
				If StrFind(ModuleString, "LongDesc.Version =") > 0 And StrFind(ModuleString, Code.Version) = 0 Then
					VersionSet = True;
					ModuleString = StringFunctionsClientServer.SubstituteParametersToString("	LongDesc.Version = ""%1"";", Code.Version);
				EndIf;
				If StrFind(TrimAll(ModuleString), "Procedure") = 1 Then
					NewModule.AddLine(ModuleString);
					Break;
				EndIf;
				NewModule.AddLine(ModuleString);
			EndDo;
			Continue;
		EndIf;
#EndRegion
		
#Region ReplaceComment
		// ACC:1297-off Comment in configuration code.
		If Code.IsDetailsProcedure 
			And StrFind(ModuleString, "--// Adds In list procedures-handlers updates data_ IB") > 0 Then
			ModuleString = SkipLinesUpTo(Module, "Handlers - see. InfobaseUpdate.NewUpdateHandlerTable");
			If StrFind(ModuleString, "Procedure") = 0 Then
				ModuleString = Module.ReadLine();
				ModuleString = "// see. InfobaseUpdateSSL.OnAddUpdateHandlers";
			EndIf;
		EndIf;
		// ACC:1297-on
#EndRegion
		
#Region OnAddUpdateHandlers
		ThisIsALibraryDescriptionProcedure = False;
		LibraryHeaderOfTheProcedure = Code.ProcedureTitle;
		If Not WasReplaced 
			And Code.IsDetailsProcedure
			And (StrFind(ModuleString, "Procedure UpdateHandlersDetails") > 0
				Or StrFind(ModuleString, "Procedure OnAddUpdateHandlers") > 0)
			And StrFind(ModuleString, LibraryHeaderOfTheProcedure) = 0 Then
			For Each LibraryName In Code.LibrariesNames Do
				LibraryHeaderOfTheProcedure = StringFunctionsClientServer.SubstituteParametersToString("Procedure UpdateHandlersDetails%1(Handlers) Export", LibraryName);
				If StrFind(ModuleString, LibraryHeaderOfTheProcedure) > 0 Then
					ThisIsALibraryDescriptionProcedure = True;
					Break;
				EndIf;
				LibraryHeaderOfTheProcedure = StringFunctionsClientServer.SubstituteParametersToString("Procedure OnAddUpdateHandlers%1(Handlers) Export", LibraryName);
				If StrFind(ModuleString, LibraryHeaderOfTheProcedure) > 0 Then
					ThisIsALibraryDescriptionProcedure = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		If TrimAll(ModuleString) = Code.ProcedureTitle 
			Or (Not ThisIsTheUpdateModule
				And Code.IsDetailsProcedure
				And (TrimAll(ModuleString) = SimpleDescriptionProcedureTitle
						Or TrimAll(ModuleString) = "Procedure UpdateHandlersDetails(Handlers) Export"))
			Or ThisIsALibraryDescriptionProcedure
				And Code.IsDetailsProcedure
				And (Code.ProcedureTitle = LibraryHeaderOfTheProcedure
						Or Code.ProcedureTitle = SimpleDescriptionProcedureTitle) Then
			WasReplaced = True;
			For Each NewRow In NewProcedureText Do
				NewModule.AddLine(NewRow);
			EndDo;
			ModuleString = SkipLinesUpTo(Module, ProcedureEnd);
			Continue;
		EndIf;
#EndRegion
		
		NewModule.AddLine(ModuleString);
		
	EndDo;
	Module.Close();
#EndIf
	
	ProcedureName = ProcedureName(Code.ProcedureTitle);
	If VersionSet Then
		Template = NStr("en = 'In the ""%1"" module, new version ""%2"" is installed';");
		CommonClient.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(Template, Code.ModuleName, Code.Version));
	EndIf;
	If WasReplaced Then
		Template = NStr("en = 'In the ""%1"" module, the ""%2"" procedure is replaced';");
		NewText = NewModule.GetText();
		WriteModuleText(NewText, FullFileName);
		CommonClient.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(Template, Code.ModuleName, ProcedureName));
	EndIf;
	
EndProcedure

&AtClient
Function SkipLinesUpTo(Module, FragmentEnd)
	
	ModuleString = "";
	While StrFind(ModuleString, FragmentEnd) = 0 Do
		ModuleString = Module.ReadLine();
		If StrFind(TrimAll(ModuleString), "Procedure") = 1 Then
			Break;
		EndIf;
	EndDo;
	Return ModuleString;
	
EndFunction

&AtClient
Function FileTextToArray(FullFileName)
	
	Result = New Array;
	
#If Not WebClient Then
	Module = New TextReader;
	Module.Open(FullFileName, "UTF-8");
	ModuleString = "";
	While ModuleString <> Undefined Do
		ModuleString = Module.ReadLine();
		If ModuleString = Undefined Then
			Break;
		EndIf;
		Result.Add(ModuleString);
	EndDo;
#EndIf
	
	Return Result;
	
EndFunction

&AtClient
Function ProcedureName(ProcedureTitle)
	
	ProcedureName = StrReplace(ProcedureTitle, "Procedure", "");
	ProcedureName = TrimAll(StrReplace(ProcedureName, "Export", ""));
	Bracket1 = StrFind(ProcedureName, "(");
	Return Left(ProcedureName, Bracket1-1);
	
EndFunction

&AtClient
Procedure WriteModuleText(FileText, FullFileName)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("FullFileName", FullFileName);
	AdditionalParameters.Insert("FileText", FileText);
#If Not WebClient Then
	DeleteFiles(FullFileName);
	ModuleFileDeletionCompletion(AdditionalParameters);
#EndIf
	
EndProcedure

&AtClient
Procedure ModuleFileDeletionCompletion(AdditionalParameters)
	
	FullFileName = AdditionalParameters.FullFileName;
	FileText = AdditionalParameters.FileText;
	
#If Not WebClient Then
	WriteBOM = False;
	Stream = New FileStream(FullFileName, FileOpenMode.CreateNew);
	LineSplitter = Chars.CR + Chars.LF;
	TextWriter = New TextWriter(Stream, TextEncoding.UTF8, LineSplitter,,WriteBOM);
	
	TextWriter.Write(FileText);
	TextWriter.Close();

	Stream.Close();
#EndIf
	
EndProcedure

&AtClient
Procedure SaveTechnicalDesignHandlersList()
	
	FileName = SettingsDirectory() + "tech-project.updaters";
	
	TechDesignHandlers = TechnicalDesignHandlers();
	If TechDesignHandlers.Count() > 0 Then
		FileText = StrConcat(TechDesignHandlers, Chars.LF);
		WriteFileToDisk(FileName, FileText);
	EndIf;
	
EndProcedure

&AtServer
Function TechnicalDesignHandlers()
	
	Filter = New Structure("TechnicalDesign", True);
	Handlers = Object.UpdateHandlers.Unload(Filter);
	TechDesignHandlers = New Array;
	For Each Handler In Handlers Do
		LongDesc = StringFunctionsClientServer.SubstituteParametersToString("%1:%2", Handler.Id, Handler.Procedure);
		TechDesignHandlers.Add(LongDesc);
	EndDo;
	
	Return TechDesignHandlers;
	
EndFunction

&AtClient
Procedure SaveVersionToConfigurationRoot()
	
	FullFileName = Object.SRCDirectory + "Configuration\Configuration.mdo";
	
#If Not WebClient Then
	VersionSet = False;
	NewFile = New TextDocument;
	FileText = New TextReader;
	FileText.Open(FullFileName, "UTF-8");
	ModuleString = "";
	While ModuleString <> Undefined Do

		ModuleString = FileText.ReadLine();
		If ModuleString = Undefined Then
			Break;
		EndIf;
		
		If StrFind(ModuleString, "<version>") > 0 
			And StrFind(ModuleString,  NewConfigurationVersion) = 0 Then
				VersionSet = True;
				ModuleString = StringFunctionsClientServer.SubstituteParametersToString("  <version>%1</version>", NewConfigurationVersion);
		EndIf;
		NewFile.AddLine(ModuleString);
		
	EndDo;
	
	FileText = NewFile.GetText();
	If VersionSet Then
		Template = NStr("en = 'New version ""%1"" is installed in the configuration root';");
		NewText = NewFile.GetText();
		WriteModuleText(NewText, FullFileName);
		CommonClient.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(Template, NewConfigurationVersion));
	EndIf;
	WriteFileToDisk(FullFileName, FileText);
#EndIf
	
EndProcedure

&AtClient
Function WriteFileToDisk(FullFileName, FileText)
	
#If Not WebClient Then
	WriteBOM = False;
	DeleteFiles(FullFileName);
	Stream = New FileStream(FullFileName, FileOpenMode.CreateNew);
	LineSplitter = Chars.CR + Chars.LF;
	TextWriter = New TextWriter(Stream, TextEncoding.UTF8, LineSplitter, , WriteBOM);
	
	TextWriter.Write(FileText);
	TextWriter.Close();
	
	Stream.Close();
#EndIf
	
	Return FullFileName;
	
EndFunction

#EndRegion

#Region HandlerEditing

&AtClient
Procedure OpenHandlerDetailsEditor(HandlerRef, NewRow = False, CopySource = "")
	
	ParametersOfTheAttachedHandler = New Structure;
	ParametersOfTheAttachedHandler.Insert("HandlerRef", HandlerRef);
	ParametersOfTheAttachedHandler.Insert("NewRow", NewRow);
	ParametersOfTheAttachedHandler.Insert("CopySource", CopySource);
	
	AttachIdleHandler("Attachable_OpenHandlerDetailsEditor", 0.1, True);
	
EndProcedure
	
&AtClient
Procedure Attachable_OpenHandlerDetailsEditor()
	
	HandlerRef = ParametersOfTheAttachedHandler.HandlerRef;
	NewRow = ParametersOfTheAttachedHandler.NewRow;
	CopySource = ParametersOfTheAttachedHandler.CopySource;
	
	DataAddress = PutHandlerDataInStorage(HandlerRef,,CopySource);
	FormParameters = New Structure("HandlerAddress, NewRow", DataAddress, NewRow);
	FormParameters.Insert("StartFromConfiguration", StartFromConfiguration);
	
	AdditionalParameters = New Structure("Ref", HandlerRef);
	FormClosingHandler = New NotifyDescription("HandlerEditingCompletion", ThisObject, AdditionalParameters);
	
	HandlerFormName = "DataProcessor.UpdateHandlersDetails.Form.HandlerForm";
	If Not StartFromConfiguration Then
		HandlerFormName = "ExternalDataProcessor.UpdateHandlersDetails.Form.HandlerForm";
	EndIf;
	
	OpenForm(HandlerFormName,
		FormParameters,
		ThisObject,
		UUID,
		,
		,
		FormClosingHandler,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Function PutHandlerDataInStorage(HandlerRef, Address = Undefined, CopySource = Undefined)
	
	TabSections = New Structure;
	Data = New Structure("TabularSections", TabSections);
	
	Data.Insert("SubsystemsModules", SubsystemsModules);
	
	Filter = New Structure("Ref", HandlerRef);
	Data.TabularSections.Insert("UpdateHandlers", Object.UpdateHandlers.Unload(Filter));
	If ValueIsFilled(CopySource) Then
		AddInitialHandlerObjects(Data, CopySource);
		
	Else
		TabSections.Insert("ObjectsToRead", Object.ObjectsToRead.Unload(Filter));
		TabSections.Insert("ObjectsToChange", Object.ObjectsToChange.Unload(Filter));
		TabSections.Insert("ObjectsToLock", Object.ObjectsToLock.Unload(Filter));
		TabSections.Insert("ExecutionPriorities", Object.ExecutionPriorities.Unload(Filter));
		TabSections.Insert("LowPriorityReading", Object.LowPriorityReading.Unload(Filter));
	
		Filter = New Structure("HandlerWriter", HandlerRef);
		TabSections.Insert("HandlersConflicts", Object.HandlersConflicts.Unload(Filter));
		
		Filter = New Structure("ReadOrWriteHandler2", HandlerRef);
		MoreConflicts = Object.HandlersConflicts.Unload(Filter);
		CommonClientServer.SupplementTable(MoreConflicts, TabSections.HandlersConflicts);
		
	EndIf;
	
	If Address = Undefined Then
		Address = PutToTempStorage(Data, UUID);
	Else
		PutToTempStorage(Data, Address);
	EndIf;
	
	Return Address;
	
EndFunction

// Parameters:
//   Data - Structure:
//   * SubsystemsModules - Array of String
//   * TabularSections - KeyAndValue:
//    **UpdateHandlers - ValueTable:
//     *** Ref - String
//   CopySource - Undefined
//                       - String
//
&AtServer
Procedure AddInitialHandlerObjects(Data, CopySource)
	
	TabularSections = New Array;
	TabularSections.Add("ObjectsToRead");
	TabularSections.Add("ObjectsToChange");
	TabularSections.Add("ObjectsToLock");
	
	Filter = New Structure("Ref", CopySource);
	Handler = Data.TabularSections.UpdateHandlers[0];
	NewRef = Handler.Ref;
	For Each TabSectionName In TabularSections Do
		VT = Object[TabSectionName].Unload(Filter);
		VT.FillValues(NewRef, "Ref");
		Data.TabularSections.Insert(TabSectionName, VT);
	EndDo;
	
EndProcedure

&AtServer
Function UpdateHandlerData(HandlerAddress)
	
	DataProcessor = DataProcessorObject2();
	Data = GetFromTempStorage(HandlerAddress); // See AddInitialHandlerObjects.Data
	
	NewDetails = Data.TabularSections.UpdateHandlers[0];
	Modified = NewDetails.Changed;
	
	NewDetails.VersionAsNumber = DataProcessor.VersionAsNumber(NewDetails.Version);
	VersionNumbers = StrSplit(NewDetails.Version, ".");
	VersionNumbers.Delete(0);
	NewDetails.RevisionAsNumber = DataProcessor.VersionAsNumber(VersionNumbers);
	
	HandlerDetails = DataProcessor.UpdateHandlers.Find(NewDetails.Ref, "Ref");
	If HandlerDetails <> Undefined Then
		
		FillPropertyValues(HandlerDetails, NewDetails);
		If SubsystemsModules <> Undefined And NewDetails.Subsystem <> "" Then
			HandlerDetails.MainServerModuleName = SubsystemsModules[NewDetails.Subsystem];
			HandlerDetails.LibraryName = StrReplace(HandlerDetails.MainServerModuleName, "InfobaseUpdate", "");
		EndIf;
		Names = StrSplit(HandlerDetails.Procedure, ".");
		Names.Delete(Names.UBound());
		HandlerDetails.ObjectName = StrConcat(Names, ".");
		
		InverseOrder = DataProcessor.reverseorder();
		Filter = New Structure("Ref", HandlerDetails.Ref);
		For Each TabularSection In Data.TabularSections Do
			
			If TabularSection.Key <> "UpdateHandlers" Then
				FoundRows = DataProcessor[TabularSection.Key].FindRows(Filter);
				For Each RowToDelete In FoundRows Do
					DataProcessor[TabularSection.Key].Delete(RowToDelete);
				EndDo;
				
				For Each Record In TabularSection.Value Do
					NewRow = DataProcessor[TabularSection.Key].Add();
					FillPropertyValues(NewRow, Record,,"LineNumber");
					If TabularSection.Key = "ExecutionPriorities" Then
						InvertOrder(DataProcessor, Record, InverseOrder)
					EndIf;
				EndDo;
			EndIf;
			
		EndDo;
		UpdateHandlersConflictsInfo(DataProcessor);
		ValueToFormAttribute(DataProcessor, "Object");
		
		Filter = New Structure("Ref", NewDetails.Ref);
		FoundRows = Object.UpdateHandlers.FindRows(Filter);
		If FoundRows.Count() > 0 Then
			FoundRows[0].NewRow = False;
			Items.UpdateHandlers.CurrentRow = FoundRows[0].GetID();
			SourceCurrentRow = Items.UpdateHandlers.CurrentRow;
		EndIf;
		
		NewHandlersFIlters();
		
	EndIf;
	
	Return NewDetails.Ref;
	
EndFunction

&AtServer
Procedure InvertOrder(DataProcessor, Record, InverseOrder)
	
	Filter = New Structure("Ref, Handler2");
	Filter.Ref = Record.Handler2;
	Filter.Handler2 = Record.Ref;
	FoundPriorities = DataProcessor["ExecutionPriorities"].FindRows(Filter);
	For Each Priority In FoundPriorities Do
		If Not IsBlankString(Record.Order) Then
			NewOrder = InverseOrder[Record.Order];
			If NewOrder <> Priority.Order Then
				Priority.Order = NewOrder;
				Priority.ExecutionOrderSpecified = True;
				Filter = New Structure("Ref", Record.Handler2);
				FoundHandlers = DataProcessor["UpdateHandlers"].FindRows(Filter);
				If FoundHandlers.Count() > 0 Then
					FoundHandlers[0].Changed = True;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure UpdateHandlerConflictsData(HandlerAddress)
	
	HandlerRef = UpdateHandlerData(HandlerAddress);
	PutHandlerDataInStorage(HandlerRef, HandlerAddress);
	
EndProcedure

&AtServer
Procedure PrioritiesOfDataToReadConflictsOrDoubleEntry(ExecutionPriorities, Conflicts1)
	
	HandlerPriorities1 = ExecutionPriorities.Copy();
	ExecutionPriorities.Clear();
	
	For Each Handler1Priority In HandlerPriorities1 Do
		DataToReadIsBeingChangedByOthers = Conflicts1.Find(Handler1Priority.Procedure2, "WriteProcedure") <> Undefined;
		LibraryToDevelopChangesDataToRead = SubsystemsToDevelop.Find(Handler1Priority.Subsystem2) <> Undefined;
		ManualOrder = Handler1Priority.Order <> Handler1Priority.OrderAuto;
		If (DataToReadIsBeingChangedByOthers Or Not LibraryToDevelopChangesDataToRead) And ManualOrder Then
			NewRow = ExecutionPriorities.Add();
			FillPropertyValues(NewRow, Handler1Priority);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region QueueBuilding

&AtServer
Function BuildQueueAtServer()
	
	UpdateIterations = InfobaseUpdateInternal.UpdateIterations();
	InfobaseUpdateOverridable.BeforeGenerateDeferredHandlersList(UpdateIterations);
	
	DataProcessor = DataProcessorObject2();
	OK1 = DataProcessor.BuildQueue();
	ValueToFormAttribute(DataProcessor, "Object");
	
	UpdateFormData(DataProcessor);
	
	Return OK1;
	
EndFunction

#EndRegion

#Region ConflictsDetection

&AtServer
Procedure UpdateHandlersConflictsInfo(DataProcessor)
	
	NewDetails = DataProcessor.UpdateHandlersConflictsInfo();
	FillQuickFilters(NewDetails);
	
EndProcedure

&AtServer
Procedure FillQuickFilters(Val HandlersDetails = Undefined)
	
	If HandlersDetails = Undefined Then
		HandlersDetails = Object.UpdateHandlers.Unload();
	EndIf;
	
	RowsArray = New Array;
	OtherQuickFilters.Clear();
	
	AddQuickFilter(HandlersDetails, RowsArray, "IssueStatus", AnalysisRequiredStatus, "AnalysisRequired", StyleColors.SpecialTextColor);
	AddQuickFilter(HandlersDetails, RowsArray, "LowPriorityReading", LowPriorityReadingStatus, "LowPriorityReading", StyleColors.SpecialTextColor);
	AddQuickFilter(HandlersDetails, RowsArray, "ChangedCheckProcedure", StatusChangedCheckProcedure, "ChangedCheckProcedure", WebColors.Goldenrod);
	AddQuickFilter(HandlersDetails, RowsArray, "ExecutionMode", NStr("en = 'Deferred';"), "Deferred");
	AddQuickFilter(HandlersDetails, RowsArray, "ExecutionMode", NStr("en = 'Exclusive';"), "Exclusively");
	AddQuickFilter(HandlersDetails, RowsArray, "ExecutionMode", NStr("en = 'Real-time';"), "Seamless");
	AddQuickFilter(HandlersDetails, RowsArray, "TechnicalDesign", NStr("en = 'Technical design';"), "TechnicalDesign");
	
	AddAnotherQuickFilter(HandlersDetails, "DeferredHandlersExecutionMode", NStr("en = 'Parallel';"), "Parallel");
	AddAnotherQuickFilter(HandlersDetails, "DeferredHandlersExecutionMode", NStr("en = 'Sequentially';"), "Sequentially");
	AddAnotherQuickFilter(HandlersDetails, "InitialFilling", NStr("en = 'Initial population';"), "InitialFilling");
	AddAnotherQuickFilter(HandlersDetails, "ExecuteInMandatoryGroup", NStr("en = 'Required';"), "IsRequired");
	AddAnotherQuickFilter(HandlersDetails, "Multithreaded", NStr("en = 'Multi-threaded';"), "Multithreaded");
	AddAnotherQuickFilter(HandlersDetails, "DataToReadWriter", NStr("en = 'Writing of readable objects';"), "DataToReadWriter");
	AddAnotherQuickFilter(HandlersDetails, "WriteAgain", NStr("en = 'Rewriting';"), "WriteAgain");
	
	StatusText = NStr("en = 'Other';");
	HyperlinkString = New FormattedString(
		StatusText,
		, 
		StyleColors.ButtonTextColor, ,
		"OtherItems");
	RowsArray.Add(HyperlinkString);
	RowsArray.Add("  ");
	
	StatusText = StringFunctionsClientServer.SubstituteParametersToString("%1 (%2)", NStr("en = 'All';"), HandlersDetails.Count());
	HyperlinkString = New FormattedString(
		StatusText, 
    	, 
		StyleColors.ButtonTextColor, ,
		"All");
		
	RowsArray.Add(HyperlinkString);
	
	Items.QuickFilters.Title = New FormattedString(RowsArray);
	
EndProcedure

&AtServer
Procedure AddQuickFilter(HandlersDetails, RowsArray, FilterFieldName, Val FilterValue, LinkID, Val Color = Undefined)
	
	If Color = Undefined Then
		Color = StyleColors.ButtonTextColor;
	EndIf;
	
	FilterPresentation = FilterValue;
	
	For Each FieldType In HandlersDetails.Columns[FilterFieldName].ValueType.Types() Do
		If FieldType = Type("Boolean") Then
			FilterValue = True;
			Break;
		EndIf;
	EndDo;
	
	Filter = New Structure(FilterFieldName, FilterValue);
	FilterRows = HandlersDetails.Copy(Filter);
	If FilterRows.Count() > 0 Then
		
		StatusText = StringFunctionsClientServer.SubstituteParametersToString("%1 (%2)", FilterPresentation, FilterRows.Count());
		HyperlinkString = New FormattedString(
			StatusText,
			,
			Color, ,
			LinkID);
		
		RowsArray.Add(HyperlinkString);
		RowsArray.Add("  ");
	EndIf;
	
EndProcedure

&AtServer
Procedure AddAnotherQuickFilter(HandlersDetails, FilterFieldName, Val FilterValue, LinkID)
	
	FilterPresentation = FilterValue;
	For Each FieldType In HandlersDetails.Columns[FilterFieldName].ValueType.Types() Do
		If FieldType = Type("Boolean") Then
			FilterValue = True;
			Break;
		EndIf;
	EndDo;
	
	Filter = New Structure(FilterFieldName, FilterValue);
	FilterRows = HandlersDetails.Copy(Filter);
	If FilterRows.Count() > 0 Then
		StatusText = StringFunctionsClientServer.SubstituteParametersToString("%1 (%2)", FilterPresentation, FilterRows.Count());
		OtherQuickFilters.Add(LinkID, StatusText);
	EndIf;
	
EndProcedure

#EndRegion

#Region CodeGeneration

&AtClient
Procedure ShowUpdateHandlersDetailsTexts(CodeGenerationParameters)
	
	ModulesTexts = GetModulesTexts(CodeGenerationParameters);
	For Each ModuleCode In ModulesTexts Do
		TextDocument = New TextDocument;
		TextDocument.SetText(ModuleCode.ProcedureText);
		TextDocument.Show(ModuleCode.ModuleName);
	EndDo;
	Items.ImportExportSettingsGroup.Hide();
	Modified = False;
	
EndProcedure

&AtClient
Function GetModulesTexts(CodeGenerationParameters = Undefined)
	
	If CodeGenerationParameters = Undefined Then
		CodeGenerationParameters = NewCodeGenerationParameters();
	EndIf;
	Settings = New Structure("CodeGenerationParameters", CodeGenerationParameters);
	
	FileName = SettingsDirectory() + "cut_tags.yml";
	File = New File(FileName);
	If File.Exists() Then
		TagsDetails = ReadYAMLFile(FileName);
		If TagsDetails["configurations"] <> Undefined Then
			GetSubsystemsObjects(TagsDetails["configurations"]);
			AllObjects = GetAllOriginalConfigurationObjects();
			DefineTagsForObjectsNotIncludedInConfiguration(TagsDetails);
			Settings.Insert("TagsDetails", TagsDetails);
			Settings.Insert("AllObjects", AllObjects);
		EndIf;
	EndIf;
	SettingsAddress = PutToTempStorage(Settings, UUID);
	
	If CodeGenerationParameters.DetailsInCommonModule Then
		Return HandlersDetailsByUpdateModules(SettingsAddress);
	Else
		Return HandlersDetailsByManagersModules(SettingsAddress);
	EndIf;
	
EndFunction

&AtClient
Function NewCodeGenerationParameters()
	
	Result = New Structure;
	Result.Insert("DetailsInCommonModule", False);
	Result.Insert("OnlyChangedItems", True);
	Result.Insert("OnlySelectedItems", False);
	Result.Insert("UpdateQueue", True);
	Result.Insert("UpdateCallsList", True);
	Return Result;
	
EndFunction

#Region ByUpdateModules

&AtServer
Function HandlersDetailsByUpdateModules(SettingsAddress)
	
	Settings = GetFromTempStorage(SettingsAddress);
	
	ModulesTexts = New Array;
	If Not BuildQueueAtServer() Then
		Return ModulesTexts;
	EndIf;
	
	ConfigurationsDetails = New Map;
	ConfigurationsNames = New Array;
	CodeLayout = New Structure("SetTags", False);
	CodeLayout.Insert("IsManagerModule", False);
	CodeLayout.Insert("AddDetailsArea", True);
	CodeLayout.Insert("IsDetailsProcedure", False);
	If Settings.Property("TagsDetails") Then
		ConfigurationsDetails = Settings.TagsDetails["configurations"];
		Tags1 = GetCutTagsInfo(Settings);
		ConfigurationsNames = Tags1.LibrariesInNestingOrder;
		CodeLayout.SetTags = True;
		CodeLayout.Insert("Tags1", Tags1);
	Else
		FillDetails(ConfigurationsDetails, ConfigurationsNames);
	EndIf;
	
	ModulesVersions = ModulesVersionsDetails();
	For Each ConfigurationName In ConfigurationsNames Do
		
		ConfigurationDescription = ConfigurationsDetails[ConfigurationName];
		MainServerModuleName = ConfigurationDescription["module"];
		If MainServerModuleName = Undefined Then
			Continue;
		EndIf;
		
		If SubsystemsToDevelop.Find(ConfigurationDescription["name"]) = Undefined Then
			Continue;
		EndIf;
		
		If CodeLayout.SetTags Then
			CodeLayout.Insert("ConfigurationName", ConfigurationName);
			CodeLayout.Insert("ModuleName", MainServerModuleName);
			CodeLayout.Insert("ProcedureName", "OnAddUpdateHandlers");
			CodeLayout.Insert("IsDetailsProcedure", False);
			CodeLayout.Insert("LocalizationModule", ConfigurationDescription["localization"] <> Undefined);
			If CodeLayout.LocalizationModule Then
				If ConfigurationDescription["outTags"].Count() > 0 Then
					CodeLayout.Insert("LocalizationTags", ConfigurationDescription["outTags"][0]);
				EndIf;
			EndIf;
		EndIf;
		
		Filter = New Structure("DeferredHandlersExecutionMode", "Parallel");
		Filter.Insert("MainServerModuleName", MainServerModuleName);
		ModuleHandlers = Object.UpdateHandlers.Unload(Filter);
		
		If ModuleHandlers.Count() = 0 Then
			Continue;
		EndIf;
		
		ModuleHandlers.Sort("Procedure");
		UpdateHandlersModules(ModuleHandlers, CodeLayout);
		If CodeLayout.SetTags Then
			CodeLayout.Tags1.Insert("ByHandlers", ModuleHandlers);
		EndIf;
		HandlersText = HandlersText(ModuleHandlers, CodeLayout);
		
		If CodeLayout.SetTags And CodeLayout.LocalizationModule Then
			LibraryTag = Tags1.ByLibraries.Find(ConfigurationName);
			If LibraryTag <> Undefined Then
				LocalizationTag = Tags1.LongDesc[LibraryTag.Tag]; // See TagDetails
				If LocalizationTag <> Undefined Then
					Template = "%1
					|%2
					|%3";
					HandlersText = StringFunctionsClientServer.SubstituteParametersToString(Template, LocalizationTag.Begin, HandlersText, LocalizationTag.End);
				EndIf;
			EndIf;
		EndIf;
		
		ProcedureText = 
		"Procedure OnAddUpdateHandlers(Handlers) Export
		|
		|"+ HandlersText +"
		|
		|EndProcedure";
		
		ModuleCode = ModuleCodeDetails(MainServerModuleName, ProcedureText);
		ModuleCode.ModulePath = "CommonModules\" + MainServerModuleName + "\Module.bsl";
		AddModuleVersion(ModulesVersions, ModuleHandlers);
		ModulesTexts.Add(ModuleCode);
		
	EndDo;
	
	If ModulesVersions.Count() > 0 Then
		SetModuleVersion(ModulesTexts, ModulesVersions);
	EndIf;
	
	Return ModulesTexts;
	
EndFunction

#EndRegion

#Region ByUpdateObjectsModules

&AtServer
Function HandlersDetailsByManagersModules(SettingsAddress)
	
	ModulesTexts = New Array;
	
	Settings = GetFromTempStorage(SettingsAddress);
	CodeGenerationParameters = Settings.CodeGenerationParameters;
	OnlyChangedItems = CodeGenerationParameters.OnlyChangedItems;
	OnlySelectedItems = CodeGenerationParameters.OnlySelectedItems;
	UpdateCallsList = CodeGenerationParameters.UpdateCallsList;
	UpdateQueue = CodeGenerationParameters.UpdateQueue;
	
	PickedHandlers = New Array;
	If OnlySelectedItems Then
		PickedHandlers = PickedHandlers();
	EndIf;
	
	If Not OnlySelectedItems And UpdateQueue And Not BuildQueueAtServer() Then
		Return ModulesTexts;
	EndIf;
	
	AllConfigurationsNames = New Map;
	ConfigurationsDetails = New Map;
	ConfigurationsNames = New Array;
	CodeLayout = New Structure("SetTags, IsManagerModule", False, False);
	If Settings.Property("TagsDetails") Then
		ConfigurationsDetails = Settings.TagsDetails["configurations"];
		Tags1 = GetCutTagsInfo(Settings);
		ConfigurationsNames = Tags1.LibrariesInNestingOrder;
		CodeLayout.SetTags = True;
		CodeLayout.Insert("Tags1", Tags1);
	Else
		FillDetails(ConfigurationsDetails, ConfigurationsNames);
	EndIf;
	
	ModulesVersions = ModulesVersionsDetails();
	
#Region GenerateManagersModulesLists
	AllHandlersModules = Undefined;
	HandlersForDetails = Undefined;
	For Each ConfigurationName In ConfigurationsNames Do
		
		ConfigurationDescription = ConfigurationsDetails[ConfigurationName];
		MainServerModuleName = ConfigurationDescription["module"];
		If MainServerModuleName = Undefined Then
			Continue;
		EndIf;
		
		If SubsystemsToDevelop.Find(ConfigurationDescription["name"]) = Undefined Then
			Continue;
		EndIf;
		
		If CodeLayout.SetTags Then
			CodeLayout.Insert("ConfigurationName", ConfigurationName);
			CodeLayout.Insert("ModuleName", MainServerModuleName);
			CodeLayout.Insert("LocalizationModule", ConfigurationDescription["localization"] <> Undefined);
			If CodeLayout.LocalizationModule Then
				If ConfigurationDescription["outTags"].Count() > 0 Then
					CodeLayout.Insert("LocalizationTags", ConfigurationDescription["outTags"][0]);
				EndIf;
			EndIf;
		EndIf;
		LibraryName = StrReplace(MainServerModuleName, "InfobaseUpdate", "");
		
		Filter = New Structure("DeferredHandlersExecutionMode", "Parallel");
		Filter.Insert("MainServerModuleName", MainServerModuleName);
		ModuleHandlers = Object.UpdateHandlers.Unload(Filter);
		
		If ModuleHandlers.Count() = 0 Then
			Continue;
		EndIf;
		AllConfigurationsNames.Insert(LibraryName, ConfigurationName);
		
		ModuleCode = ModuleCodeDetails(MainServerModuleName);
		AddModuleVersion(ModulesVersions, ModuleHandlers);
		ModuleHandlers.Sort("Procedure");
		
		HandlersModules = UpdateHandlersModules(ModuleHandlers, CodeLayout, PickedHandlers);
		If CodeLayout.SetTags Then
			FillModulesTagsBySubsystems(HandlersModules, CodeLayout);
		EndIf;
		
		If AllHandlersModules = Undefined Then
			AllHandlersModules = HandlersModules;
		Else
			CommonClientServer.SupplementTable(HandlersModules, AllHandlersModules);
		EndIf;
		
		If HandlersForDetails = Undefined Then
			HandlersForDetails = ModuleHandlers;
		Else
			CommonClientServer.SupplementTable(ModuleHandlers, HandlersForDetails);
		EndIf;
		
	EndDo;
#EndRegion
	
#Region SupplementingSelectedHandlersOfOtherLibraries
	If PickedHandlers.Count() > 0 And (AllHandlersModules = Undefined Or AllHandlersModules.Count() = 0) Then
		For Each Selected4 In PickedHandlers Do
			ModuleHandlers = Object.UpdateHandlers.Unload(New Structure("Ref", Selected4));
			If ModuleHandlers.Count() = 0 Then
				Continue;
			EndIf;
			HandlersModules = UpdateHandlersModules(ModuleHandlers, CodeLayout, PickedHandlers);
			If CodeLayout.SetTags Then
				FillModulesTagsBySubsystems(HandlersModules, CodeLayout);
			EndIf;
			If AllHandlersModules = Undefined Then
				AllHandlersModules = HandlersModules;
			Else
				CommonClientServer.SupplementTable(HandlersModules, AllHandlersModules);
			EndIf;
			
			If HandlersForDetails = Undefined Then
				HandlersForDetails = ModuleHandlers;
			Else
				CommonClientServer.SupplementTable(ModuleHandlers, HandlersForDetails);
			EndIf;
		EndDo;
	EndIf;
#EndRegion
	
#Region SupplementingConflictingHandlers
	If CodeLayout.SetTags And Not OnlySelectedItems Then
		ChangedHandlers = Object.UpdateHandlers.Unload(New Structure("Changed", True)).UnloadColumn("Ref");
		If PickedHandlers.Count() > 0 Then
			CommonClientServer.SupplementArray(ChangedHandlers, PickedHandlers, True);
		EndIf;
		For Each Changed In ChangedHandlers Do
			HandlerConflicts = Object.HandlersConflicts.Unload(New Structure("HandlerWriter", Changed));
			ConflictingHandlers = AllHandlersModules.CopyColumns();
			For Each Conflict In HandlerConflicts Do
				Handler = HandlersForDetails.Find(Conflict.ReadOrWriteHandler2, "Ref");
				If Handler <> Undefined Then
					Buffer = ConflictingHandlers.CopyColumns();
					NewModule = Buffer.Add();
					FillPropertyValues(NewModule, Handler);
					NewModule.Changed = OnlyChangedItems;
					CodeLayout.ConfigurationName = AllConfigurationsNames[Handler.LibraryName];
					FillModulesTagsBySubsystems(Buffer, CodeLayout);
					CommonClientServer.SupplementTable(Buffer, ConflictingHandlers);
				EndIf;
			EndDo;
			CommonClientServer.SupplementTable(ConflictingHandlers, AllHandlersModules);
		EndDo;
	EndIf;
#EndRegion
	
	If AllHandlersModules = Undefined Then
		Return ModulesTexts;
	EndIf;
	
#Region GenerateProceduresUpdateHandlersDetails
	If CodeLayout.SetTags Then
		CodeLayout.Tags1.Insert("ByHandlers", HandlersForDetails);
	EndIf;
	CodeLayout.Insert("AddDetailsArea", False);
	CodeLayout.Insert("ProcedureName", "OnAddUpdateHandlers");
	CodeLayout.Insert("IsDetailsProcedure", True);
		
	AllHandlersModules.GroupBy("HandlerModule,ObjectName,ExternalTags", "Changed");
	AllHandlersModules.Sort("HandlerModule");
	
	StringType150 = New TypeDescription("String",,New StringQualifiers(150));
	AllDetailsCalls = AllHandlersModules.CopyColumns();
	AllDetailsCalls.Columns.Add("LibraryName", StringType150);
	AllDetailsCalls.Columns.Add("ProcedureName", StringType150);
	
	ManagerModulesTexts = New Array;
	For Each Module In AllHandlersModules Do
		
		CodeLayout.IsManagerModule = StrFind(Module.ObjectName, "CommonModule") = 0;
		CodeLayout.AddDetailsArea = False;
		
		Filter = New Structure("HandlerModule", Module.HandlerModule);
		ObjectHandlers = HandlersForDetails.Copy(Filter);
		ObjectHandlers.Sort("Procedure");
		HandlersLibraries = ObjectHandlers.Copy(Filter);
		HandlersLibraries.GroupBy("LibraryName");
		HandlersLibraries.Sort("LibraryName");
		LibrariesNames = HandlersLibraries.UnloadColumn("LibraryName");
		
		For Each Library In LibrariesNames Do
			ProcedureName = "OnAddUpdateHandlers";
			If LibrariesNames.Count() > 1 Or StrFind(Module.HandlerModule, "InfobaseUpdate") > 0 Then
				ProcedureName = "OnAddUpdateHandlers" + Library;
			EndIf;
			Filter = New Structure("LibraryName", Library);
			Handlers = ObjectHandlers.Copy(Filter);
			If OnlySelectedItems And Not ExtendedFormMode Then
				HandlersToDelete = New Array;
				For Each Handler In Handlers Do
					If PickedHandlers.Find(Handler.Ref) = Undefined Then
						HandlersToDelete.Add(Handler);
					EndIf;
				EndDo;
				For Each ForDeletion In HandlersToDelete Do
					Handlers.Delete(ForDeletion);
				EndDo;
				If Handlers.Count() = 0 Then
					Continue;
				EndIf;
			EndIf;
			
			CodeLayout.AddDetailsArea = Handlers.Count() > 1 Or Not ExtendedFormMode;
			CodeLayout.ProcedureName = ProcedureName;
			If CodeLayout.SetTags Then
				CodeLayout.ConfigurationName = AllConfigurationsNames[Library];
			EndIf;
			
			NewCall = AllDetailsCalls.Add();
			FillPropertyValues(NewCall, Module);
			NewCall.LibraryName = Library;
			NewCall.ProcedureName = ProcedureName;
			
			If OnlyChangedItems And Module.Changed Or Not OnlyChangedItems Then
				HandlersText = HandlersText(Handlers, CodeLayout, Module.ExternalTags);
				If ExtendedFormMode Then
					PutInProcedure(ProcedureName, HandlersText, CodeLayout);
				EndIf;
				
				ModuleCode = ModuleCodeDetails(Module.HandlerModule, HandlersText, Handlers[0].Procedure);
				ModuleCode.IsDetailsProcedure = True;
				ModuleCode.ModulePath = "CommonModules\" + Module.HandlerModule + "\Module.bsl";
				ModuleCode.ProcedureTitle = "Procedure " + ProcedureName + "(Handlers) Export";
				ModuleCode.Insert("LibrariesNames", LibrariesNames);
				If StrFind(Module.HandlerModule, ".") > 0 Then
					Names = StrSplit(Module.HandlerModule, ".");
					Names[0] = EnglishNames[Names[0]];
					ModuleCode.ModulePath = StrConcat(Names, "\") + "\ManagerModule.bsl";
					If StrFind(ModuleCode.ModulePath, "Constants") > 0 Then
						ModuleCode.ModulePath = StrReplace(ModuleCode.ModulePath, "\ManagerModule.", "\ValueManagerModule.");
					EndIf;
				EndIf;
				ManagerModulesTexts.Add(ModuleCode);
			EndIf;
			
		EndDo;
		
	EndDo;
#EndRegion
	
#Region GenerateProceduresOnAddUpdateHandlers
	If Not OnlySelectedItems And UpdateCallsList Then
		AllDetailsCalls.Sort("LibraryName,HandlerModule");
		CodeLayout.Insert("ProcedureName", "OnAddUpdateHandlers");
		CodeLayout.IsDetailsProcedure = False;
		CodeLayout.IsManagerModule = False;
		For Each Library In AllConfigurationsNames Do
			
			LibraryName = Library.Key;
			ConfigurationName = AllConfigurationsNames[LibraryName];
			ConfigurationDescription = ConfigurationsDetails[ConfigurationName];
			MainServerModuleName = ConfigurationDescription["module"];
			
			If CodeLayout.SetTags Then
				CodeLayout.Insert("ConfigurationName", ConfigurationName);
				CodeLayout.Insert("ModuleName", MainServerModuleName);
				CodeLayout.Insert("LocalizationModule", ConfigurationDescription["localization"] <> Undefined);
				If CodeLayout.LocalizationModule Then
					If ConfigurationDescription["outTags"].Count() > 0 Then
						CodeLayout.Insert("LocalizationTags", ConfigurationDescription["outTags"][0]);
					EndIf;
				EndIf;
			EndIf;
			
			Filter = New Structure("LibraryName", LibraryName);
			HandlersModules = AllDetailsCalls.Copy(Filter);
			
			ModuleCode = ModuleCodeDetails(MainServerModuleName);
			ModuleCode.ProcedureText = TextOnAddUpdateHandlers(HandlersModules, CodeLayout);
			ModuleCode.ModulePath = "CommonModules\" + MainServerModuleName + "\Module.bsl";
			ModuleCode.ProcedureTitle = "Procedure OnAddUpdateHandlers(Handlers) Export";
			ModulesTexts.Add(ModuleCode);
			
		EndDo;
	EndIf;
	For Each ManagerModuleText In ManagerModulesTexts Do
		ModulesTexts.Add(ManagerModuleText);
	EndDo;
#EndRegion
	
	If ConfigurationVersion <> NewConfigurationVersion Then
		SetModuleVersion(ModulesTexts, ModulesVersions);
	EndIf;
	
	If Not HandlersDetailsDebugMode Then
		ClearChangedFlag();
	EndIf;
	
	If OnlySelectedItems And Not ExtendedFormMode Then
		HandlersCode = ModuleCodeDetails(NStr("en = 'Selected handlers';"));
		For Each ModuleCode In ModulesTexts Do
			HandlersCode.ProcedureText = HandlersCode.ProcedureText + ModuleCode.ProcedureText + Chars.LF + Chars.LF;
		EndDo;
		ModulesTexts = New Array;
		ModulesTexts.Add(HandlersCode);
	EndIf;
	
	Return ModulesTexts;
	
EndFunction

&AtServer
Procedure FillDetails(ConfigurationsDetails, ConfigurationsNames)
	
	ConfigurationSubsystems = StandardSubsystemsCached.SubsystemsDetails();
	For Each Subsystem In ConfigurationSubsystems.ByNames Do
		ModuleName = Subsystem.Value.MainServerModule;
		ShortLibraryName = StrReplace(ModuleName, "InfobaseUpdate", "");
		ConfigurationsNames.Add(ShortLibraryName);
		LongDesc = New Structure("module", Subsystem.Value.MainServerModule);
		LongDesc.Insert("name", Subsystem.Value.Name);
		ConfigurationsDetails.Insert(ShortLibraryName, LongDesc);
	EndDo;
	
EndProcedure

&AtServer
Procedure AddModuleVersion(ModulesVersions, ModuleHandlers)
	
	If ModuleHandlers.Count() = 0 Then
		Return;
	EndIf;
	
	DataProcessor = DataProcessorObject2();
	ModuleHandlers.Sort("RevisionAsNumber DESC");
	
	Maximum = ModuleHandlers[0];
	IsLibraryToDevelop = SubsystemsToDevelop.Find(Maximum.Subsystem) <> Undefined;
	
	If IsLibraryToDevelop Then
		LongDesc = ModulesVersions.Add();
		LongDesc.ModuleName = Maximum.MainServerModuleName;
		LongDesc.Version = Maximum.Version;
	EndIf;
	
	// Check module's handlers for the maximum build number.
	If ValueIsFilled(Maximum.Version) Then
		NumbersMax = StrSplit(Maximum.Version, ".");
	Else
		NumbersMax = StrSplit(NewConfigurationVersion, ".");
	EndIf;
	FirstDigitMax = NumbersMax[0];
	NumbersMax.Delete(0);
	MaxLast3 = DataProcessor.VersionAsNumber(NumbersMax);
	
	ConfigurationNumbers = StrSplit(NewConfigurationVersion, ".");
	FirstConfigurationDigit = ConfigurationNumbers[0];
	ConfigurationNumbers.Delete(0);
	Last3Configuration = DataProcessor.VersionAsNumber(ConfigurationNumbers);
	If IsLibraryToDevelop
		And Number(FirstDigitMax) >= Number(FirstConfigurationDigit) 
		And MaxLast3 > Last3Configuration Then
		NewConfigurationVersion = FirstConfigurationDigit + "." + StrConcat(NumbersMax, ".");
	EndIf;
	
	// Check the build number the user provided.
	ConfigurationNumbers = StrSplit(NewConfigurationVersion, ".");
	If IsLibraryToDevelop
		And NewConfigurationBuildNumber > Number(ConfigurationNumbers[3]) Then
		ConfigurationNumbers[3] = Format(NewConfigurationBuildNumber, "NZ=0; NG=0");
		NewConfigurationVersion = StrConcat(ConfigurationNumbers, ".");
		NumbersMax[3] = ConfigurationNumbers[3];
	EndIf;
	
	NumbersMax.Insert(0,0);
	
	If IsLibraryToDevelop Then
		LongDesc.RevisionVersion1 = StrConcat(NumbersMax, ".");
		LongDesc.RevisionAsNumber = DataProcessor.VersionAsNumber(LongDesc.RevisionVersion1);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetModuleVersion(ModulesTexts, Modules)
	
	If Modules.Count() = 0 Then
		Return;
	EndIf;
	
	Modules.Sort("RevisionAsNumber DESC");
	Maximum = Modules[0];
	For Each LongDesc In ModulesTexts Do
		
		Module = Modules.Find(LongDesc.ModuleName, "ModuleName");
		If Module = Undefined Then
			Continue;
		EndIf;
		
		VersionNumbers = StrSplit(Module.Version, ".");
		NewNumbers = StrSplit(Maximum.RevisionVersion1, ".");
		NewNumbers[0] = VersionNumbers[0];
		LongDesc.Version = StrConcat(NewNumbers, ".");
		
	EndDo;
	
EndProcedure

&AtServer
Function ModuleCodeDetails(ModuleName = "", ProcedureText = "", ProcessingProcedure = "")
	
	LongDesc = New Structure;
	LongDesc.Insert("ModuleName", ModuleName);
	LongDesc.Insert("ProcedureTitle", "");
	LongDesc.Insert("ProcedureText", ProcedureText);
	LongDesc.Insert("ProcessingProcedure", ProcessingProcedure);
	LongDesc.Insert("ModulePath", "");
	LongDesc.Insert("Version", "");
	LongDesc.Insert("IsDetailsProcedure", False);
	LongDesc.Insert("VersionProcedure", "Procedure OnAddSubsystem(LongDesc) Export");
	Return LongDesc;
	
EndFunction

&AtServer
Function ModulesVersionsDetails()
	
	LongDesc = New ValueTable;
	LongDesc.Columns.Add("ModuleName", New TypeDescription("String",,New StringQualifiers(150)));
	LongDesc.Columns.Add("Version", , New TypeDescription("String",,New StringQualifiers(30)));
	LongDesc.Columns.Add("RevisionVersion1", , New TypeDescription("String",,New StringQualifiers(30)));
	LongDesc.Columns.Add("RevisionAsNumber", New TypeDescription("Number",New NumberQualifiers(10, 0)));
	Return LongDesc;
	
EndFunction

&AtServer
Function UpdateHandlersModules(Handlers, CodeLayout, PickedHandlers = Undefined)
	
	StringType150 = New TypeDescription("String",,New StringQualifiers(150));
	Handlers.Columns.Add("HandlerModule", StringType150);
	Handlers.Columns.Add("UpdateModuleTags", StringType150);
	Handlers.Columns.Add("ExternalTags", StringType150);
	
	ModuleTags = "";
	If CodeLayout.SetTags Then
		TagsDetails = CodeLayout.Tags1.ByObjects.Find("CommonModule."+CodeLayout.ModuleName, "Name");
		If TagsDetails <> Undefined Then
			ModuleTags = TagsDetails.Tags1;
		EndIf;
	EndIf;
	OutputSelectedItemsOnly = PickedHandlers <> Undefined And PickedHandlers.Count() > 0;
	SelectedModuleHandlers = New Array;
	For Each Handler In Handlers Do
		
		NameParts = StrSplit(Handler.Procedure, ".");
		NameParts.Delete(NameParts.UBound());
		Handler.HandlerModule = StrConcat(NameParts, ".");
		Handler.ObjectName = Handler.HandlerModule;
		If NameParts.Count() = 1 Then
			NameParts.Insert(0, "CommonModule");
		Else
			NameParts[0] = SingularForm[NameParts[0]];
		EndIf;
		Handler.ObjectName = StrConcat(NameParts, ".");
		Handler.UpdateModuleTags = ModuleTags;
		If CodeLayout.SetTags And CodeLayout.LocalizationModule Then
			Handler.UpdateModuleTags = CodeLayout.LocalizationTags;
		EndIf;
		
		If OutputSelectedItemsOnly Then
			HandlerSelected = PickedHandlers.Find(Handler.Ref) <> Undefined;
		EndIf;
			
		If OutputSelectedItemsOnly And HandlerSelected Then
			SelectedModuleHandlers.Add(Handler.ObjectName);
		EndIf;
		
	EndDo;
	HandlersModules = Handlers.Copy();
	HandlersModules.GroupBy("HandlerModule,ObjectName,ExternalTags", "Changed");
	HandlersModules.Sort("HandlerModule");
	
	If OutputSelectedItemsOnly Then
		Selected3 = HandlersModules.CopyColumns();
		For Each Selected4 In SelectedModuleHandlers Do
			FoundRows = HandlersModules.FindRows(New Structure("ObjectName", Selected4));
			For Each Found3 In FoundRows Do
				FillPropertyValues(Selected3.Add(), Found3);
			EndDo;
		EndDo;
		Return Selected3;
	EndIf;
	
	Return HandlersModules;
	
EndFunction

&AtServer
Function PickedHandlers()
	
	Result = New Array;
	For Each LineID In Items.UpdateHandlers.SelectedRows Do
		Handler = Object.UpdateHandlers.FindByID(LineID);
		Result.Add(Handler.Ref);
	EndDo;
	Return Result;
	
EndFunction

&AtServer
Procedure ClearChangedFlag()
	
	Filter = New Structure("Changed", True);
	FoundItems = Object.UpdateHandlers.FindRows(Filter);
	For Each Handler In FoundItems Do
		Handler.Changed = False;
	EndDo;
	
EndProcedure

#EndRegion

#Region ProceduresCodeGeneration

&AtServer
Function HandlersText(Handlers, CodeLayout, ExternalTags = Undefined)
	
	StringType100 = New TypeDescription("String",,New StringQualifiers(0));
	Handlers.Columns.Add("Tags1", StringType100);
	If CodeLayout.SetTags Then
		If CodeLayout.LocalizationModule And ExternalTags = Undefined Then
			FillObjectsTags("ObjectName", Handlers, CodeLayout, CodeLayout.LocalizationTags, False);
		EndIf;
		If ExternalTags <> Undefined Then
			For Each Handler In Handlers Do
				If StrFind(ExternalTags, Handler.UpdateModuleTags) = 0 Then
					Handler.Tags1 = Handler.Tags1 + ?(IsBlankString(Handler.Tags1),"",",") + Handler.UpdateModuleTags;
				EndIf;
				Handler.UpdateModuleTags = ExternalTags;
			EndDo;
		EndIf;
	EndIf;
	
	TagsTree = CollapseByTags(Handlers, CodeLayout);
	HandlersGroupsRows = New Array;
	For Each Branch1 In TagsTree.Rows Do
		HandlersGroupText = HandlersGroupTextRecursively(Branch1, CodeLayout, HandlersGroupsRows.Count() = 0);
		HandlersGroupsRows.Add(HandlersGroupText);
	EndDo;
	HandlersText = StrConcat(HandlersGroupsRows, Chars.LF);
	
	Return HandlersText;
	
EndFunction

// Parameters:
//   Branch1 - ValueTreeRow
//   CodeLayout - Structure:
//   * Tags1 - See GetCutTagsInfo
//   * AddDetailsArea - Boolean
//   * IsManagerModule - Boolean
//   * LocalizationTags - String
//   * ProcedureName - String
//   FirstInGroup - Boolean
// Returns:
//   String
//
&AtServer
Function HandlersGroupTextRecursively(Branch1, CodeLayout, FirstInGroup = True)
	
	HandlersRow = New Array;
	For Each Handler In Branch1.Rows Do
		If Handler.Rows.Count() > 0 Then
			HandlersGroupText = HandlersGroupTextRecursively(Handler, CodeLayout, HandlersRow.Count() = 0);
			HandlersRow.Add(HandlersGroupText);
			Continue;
		EndIf;
		ExternalTags = "";
		If CodeLayout.SetTags Then
			ExternalTags = Handler.Tags1 + ?(IsBlankString(Handler.Tags1),"",",") + Handler.UpdateModuleTags;
			CodeLayout.ModuleName = Handler.MainServerModuleName;
		EndIf;
		HandlerText = HandlerDetailsText(Handler, CodeLayout, ExternalTags);
		If HandlersRow.Count() > 0 Then
			HandlerText = Chars.LF + HandlerText;
		EndIf;
		HandlersRow.Add(HandlerText);
	EndDo;
	
	HandlersText = StrConcat(HandlersRow, Chars.LF);
	If CodeLayout.SetTags 
		And Not IsBlankString(Branch1.Tags1) And Not CodeLayout.IsDetailsProcedure Then
		Template = "%1" + Chars.LF + "%2" + Chars.LF + "%3";
		If Not FirstInGroup Then
			Template = "%1" + Chars.LF + Chars.LF + "%2" + Chars.LF + "%3";
		EndIf;
		For Each Tag In StrSplit(Branch1.Tags1, ",") Do
			TagDetails = CodeLayout.Tags1.LongDesc[Tag]; // See TagDetails
			HandlersText = StringFunctionsClientServer.SubstituteParametersToString(Template, TagDetails.Begin, HandlersText, TagDetails.End);
		EndDo;
		
	ElsIf Not FirstInGroup Then
		HandlersText = Chars.LF + HandlersText;
		
	EndIf;
	
	Return HandlersText;
	
EndFunction

&AtServer
Function TextOnAddUpdateHandlers(HandlersModules, CodeLayout)
	
	HandlersModules.Columns.Add("Tags1", New TypeDescription("String",,New StringQualifiers(100)));
	If CodeLayout.SetTags Then
		If CodeLayout.LocalizationModule Then
			FillObjectsTags("ObjectName", HandlersModules, CodeLayout, CodeLayout.LocalizationTags, False);
		ElsIf CodeLayout.Property("LocalizationTags") And Not IsBlankString(CodeLayout.LocalizationTags) Then
			For Each Module In HandlersModules Do
				If StrFind(Module.ExternalTags, CodeLayout.LocalizationTags) > 0 Then
					Module.Tags1 = CodeLayout.LocalizationTags;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	TagsTree = CollapseByTags(HandlersModules, CodeLayout);
	CallsGroupsRows = New Array;
	For Each Branch1 In TagsTree.Rows Do
		CallsGroupText = CallsGroupTextRecursively(Branch1, CodeLayout);
		CallsGroupsRows.Add(CallsGroupText);
	EndDo;
	ProcedureText = StrConcat(CallsGroupsRows, Chars.LF);
	
	PutInProcedure("OnAddUpdateHandlers", ProcedureText, CodeLayout);
	
	Return ProcedureText;
	
EndFunction

// Parameters:
//   Branch1 - ValueTreeRow
//   CodeLayout - Structure:
//   * Tags1 - See GetCutTagsInfo
//   * AddDetailsArea - Boolean
//   * IsManagerModule - Boolean
//   * LocalizationTags - String
//   * ProcedureName - String
// Returns:
//   String
//
&AtServer
Function CallsGroupTextRecursively(Branch1, CodeLayout)
	
	CallsLines = New Array;
	For Each HandlerModule In Branch1.Rows Do
		If HandlerModule.Rows.Count() > 0 Then
			HandlersGroupText = CallsGroupTextRecursively(HandlerModule, CodeLayout);
			CallsLines.Add(HandlersGroupText);
			Continue;
		EndIf;
		
		ProcedureName = HandlerModule.ProcedureName + "(Handlers)";
		CallText = Chars.Tab + StringFunctionsClientServer.SubstituteParametersToString("%1.%2;", HandlerModule.HandlerModule, ProcedureName);
		CallsLines.Add(CallText);
	EndDo;
	
	HandlersText = StrConcat(CallsLines, Chars.LF);
	If Not IsBlankString(Branch1.Tags1) Then
		Template = "%1" + Chars.LF + "%2" + Chars.LF + "%3";
		For Each Tag In StrSplit(HandlerModule.Tags1, ",") Do
			TagDetails = CodeLayout.Tags1.LongDesc[Tag]; // See TagDetails
			HandlersText = StringFunctionsClientServer.SubstituteParametersToString(Template, TagDetails.Begin, HandlersText, TagDetails.End);
		EndDo;
	EndIf;
	
	Return HandlersText;
	
EndFunction

// Parameters:
//   Handler - ValueTreeRow:
//    * Id - UUID
//   CodeLayout - Structure:
//   * Tags1 - See GetCutTagsInfo
//   * ProcedureName - String
//   * AddDetailsArea - Boolean
//   * IsManagerModule - Boolean
//   * LocalizationTags - String
//   HandlerTags - String
// Returns:
//   String
//
&AtServer
Function HandlerDetailsText(Handler, CodeLayout, HandlerTags)
	
	HandlerRows = New Array;
	HandlerRows.Add("	Handler = Handlers.Add();");
	HandlerRows.Add("Handler.Procedure = """ + Handler.Procedure + """;");
	HandlerRows.Add("Handler.Version = """ + Handler.Version + """;");
	HandlerRows.Add("Handler.ExecutionMode = """ + String(Handler.ExecutionMode) + """;");
	
	If Handler.InitialFilling Then
		HandlerRows.Add("Handler.InitialFilling = True;");
	EndIf;
	
	If Not IsBlankString(Handler.Id) Then
		ID = New UUID(Handler.Id);
		If ValueIsFilled(ID) Then
			HandlerRows.Add("Handler.Id = New UUID(""" + Handler.Id + """);");
		EndIf;
	EndIf;
	
	If Handler.SharedData Then
		HandlerRows.Add("Handler.SharedData = True;");
	EndIf;
	
	If Handler.HandlerManagement Then
		HandlerRows.Add("Handler.HandlerManagement = True;");
	EndIf;
	
	If Handler.Multithreaded Then
		HandlerRows.Add("Handler.Multithreaded = True;");
	EndIf;
	
	DeferredExecutionMode = Handler.ExecutionMode = "Deferred";
	If DeferredExecutionMode Then
		HandlerRows.Add("Handler.UpdateDataFillingProcedure = """ + Handler.UpdateDataFillingProcedure + """;");
		HandlerRows.Add("Handler.CheckProcedure = """ + Handler.CheckProcedure + """;");
	EndIf;
	
	If Handler.ExecuteInMasterNodeOnly Then
		HandlerRows.Add("Handler.ExecuteInMasterNodeOnly = True;");
	EndIf;
	
	If Handler.RunAlsoInSubordinateDIBNodeWithFilters Then
		HandlerRows.Add("Handler.RunAlsoInSubordinateDIBNodeWithFilters = True;");
	EndIf;
	
	If Handler.Order <> Enums.OrderOfUpdateHandlers.Normal Then
		HandlerRows.Add("Handler.Order = Enums.OrderOfUpdateHandlers."+String(Handler.Order)+";");
	EndIf;
	
	If IsBlankString(Handler.Comment)Then
		HandlerRows.Add("Handler.Comment = """";");
	Else
		CommentText1 = TrimAll(Handler.Comment);
		CommentText1 = StrReplace(CommentText1, Chars.LF, Chars.LF + "	|");
		CommentText1 = StrReplace(CommentText1, """", """""");
		HandlerRows.Add("Handler.Comment = NStr(""ru = '" + CommentText1 +"'"");");
	EndIf;
	
	TextObjectsToRead = ObjectInformationText(Handler, "ObjectsToRead", CodeLayout, HandlerTags);
	If Not IsBlankString(TextObjectsToRead) Then
		HandlerRows.Add(TextObjectsToRead);
	EndIf;
	
	TextObjectsToChange = ObjectInformationText(Handler, "ObjectsToChange", CodeLayout, HandlerTags);
	If Not IsBlankString(TextObjectsToChange) Then
		HandlerRows.Add(TextObjectsToChange);
	EndIf;
	
	TextNewObjects = ObjectInformationText(Handler, "NewObjects", CodeLayout, HandlerTags);
	If Not IsBlankString(TextNewObjects) Then
		HandlerRows.Add(TextNewObjects);
	EndIf;
	
	If DeferredExecutionMode Then
		TextObjectsToLock = ObjectInformationText(Handler, "ObjectsToLock", CodeLayout, HandlerTags);
		If Not IsBlankString(TextObjectsToLock) Then
			HandlerRows.Add(TextObjectsToLock);
		EndIf;
	EndIf;
	
	If DeferredExecutionMode Then
		TextExecutionPriorities = ExecutionPrioritiesText(Handler, CodeLayout, HandlerTags);
		If Not IsBlankString(TextExecutionPriorities) Then
			HandlerRows.Add(TextExecutionPriorities);
		EndIf;
	EndIf;
	HandlerText = StrConcat(HandlerRows, Chars.LF + Chars.Tab);
	
	AreaTemplate1 = 
	"#Area %1
	|
	|%2
	|
	|#EndRegion";
	AreaName = StrReplace(Handler.Procedure, ".", "_");
	If CodeLayout.IsDetailsProcedure And ExtendedFormMode Then
		Names = StrSplit(Handler.Procedure, ".");
		AreaName = Names[Names.UBound()];
	EndIf;
	Result = HandlerText;
	If CodeLayout.AddDetailsArea Then
		Result = StringFunctionsClientServer.SubstituteParametersToString(AreaTemplate1, AreaName, HandlerText);
	EndIf;
	
	Return Result;
	
EndFunction

// Parameters:
//   Handler - ValueTreeRow:
//   * Ref - String
//   * Id - UUID
//   CodeLayout - Structure:
//   * AddDetailsArea - Boolean
//   * IsManagerModule - Boolean
//   * LocalizationTags - String
//   * ProcedureName - String
//   HandlerTags - String
// Returns:
//   String
//
&AtServer
Function ExecutionPrioritiesText(Handler, CodeLayout, HandlerTags)
	
	Filter = New Structure("Ref", Handler.Ref);
	ExecutionPriorities = Object.ExecutionPriorities.Unload(Filter);
	Filter = New Structure("ReadOrWriteHandler2", Handler.Ref);
	Conflicts1 = Object.HandlersConflicts.Unload(Filter);
	PrioritiesOfDataToReadConflictsOrDoubleEntry(ExecutionPriorities, Conflicts1);
	
	PrioritiesText = "";
	If ExecutionPriorities.Count() = 0 Then
		Return PrioritiesText;
	EndIf;
		
	PrioritiesText = PrioritiesText + "
	|	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
	|
	|";
	
	ExecutionPriorities.Columns.Add("Tags1", New TypeDescription("String",,New StringQualifiers(100)));
	If CodeLayout.SetTags Then
		FillObjectsTags("Procedure2", ExecutionPriorities, CodeLayout, HandlerTags);
	EndIf;
	VT = ExecutionPriorities.Copy(,"Tags1");
	VT.GroupBy("Tags1");
	VT.Sort("Tags1");
	AllObjectsTags = VT.UnloadColumn("Tags1");
	
	AllTagsDetails = New Map;
	PriorityTemplate = 
	"	NewRow = Handler.ExecutionPriorities.Add();
	|	NewRow.Procedure = ""%1"";
	|	NewRow.Order = ""%2"";";
	TagsTexts = New Array;
	For CommonIndex = 0 To AllObjectsTags.UBound() Do
		Tags1 = AllObjectsTags[CommonIndex];
		Filter = New Structure("Tags1", Tags1);
		TagPriorities = ExecutionPriorities.FindRows(Filter);
		TagStrings = New Array;
		For Each Priority In TagPriorities Do
			PriorityString = StringFunctionsClientServer.SubstituteParametersToString(PriorityTemplate,Priority.Procedure2,Priority.Order);
			TagStrings.Add(PriorityString);
		EndDo;
		
		TagText = StrConcat(TagStrings, Chars.LF + Chars.LF);
		If Not IsBlankString(Tags1) Then
			TagsArray = StrSplit(Tags1, ",");
			For IndexOf = 0 To TagsArray.UBound() Do
				Tag = TagsArray[IndexOf];
				Template = "	%1" + Chars.LF + "%2" + Chars.LF + "	%3";
				If (IndexOf + 1)%2 <> 0 And TagsArray.Count() > 1 Then
					Template = Chars.LF + "	%1" + Chars.LF + "%2" + Chars.LF + "	%3" + Chars.LF;
				EndIf;
				TagDetails = CodeLayout.Tags1.LongDesc[Tag]; // See TagDetails
				TagText = StringFunctionsClientServer.SubstituteParametersToString(Template, TagDetails.Begin, TagText, TagDetails.End);
				AllTagsDetails.Insert(Tag, TagDetails);
			EndDo;
			TagText = StrReplace(TagText, "		", "	");
		EndIf;
		If ValueIsFilled(Tags1) And CommonIndex <> AllObjectsTags.UBound() Then
			TagText = TagText + Chars.LF;
		EndIf;
		TagsTexts.Add(TagText);
	EndDo;
	TagsText = StrConcat(TagsTexts, Chars.LF);
	
	Template = "	%1
			|	%2
			|";
	For Each TagDetails In AllTagsDetails Do
		EndBegin = StringFunctionsClientServer.SubstituteParametersToString(Template, TagDetails.Value.End, TagDetails.Value.Begin);
		TagsText = StrReplace(TagsText, EndBegin, "");
	EndDo;
	PrioritiesText = PrioritiesText + TagsText; 
	
	Return PrioritiesText;
	
EndFunction

// Parameters:
//   Handler - ValueTreeRow:
//   * Ref - String
//   * Id - UUID
//   ObjectsSetName - String
//   CodeLayout - Structure:
//   * AddDetailsArea - Boolean
//   * IsManagerModule - Boolean
//   * LocalizationTags - String
//   * ProcedureName - String
//   HandlerTags - String
// Returns:
//   String
//
&AtServer
Function ObjectInformationText(Handler, ObjectsSetName, CodeLayout, HandlerTags)
	
	Filter = New Structure("Ref", Handler.Ref);
	If ObjectsSetName = "NewObjects" Then
		Filter.Insert("NewObjects", True);
		HandlerObjects = Object["ObjectsToChange"].Unload(Filter);
	Else
		HandlerObjects = Object[ObjectsSetName].Unload(Filter);
	EndIf;
	If ObjectsSetName = "ObjectsToLock" Then
		Filter.Insert("LockInterface", True);
		ObjectsToLock = Object["ObjectsToChange"].Unload(Filter);
		CommonClientServer.SupplementTable(ObjectsToLock, HandlerObjects);
		ObjectsToLock = Object["ObjectsToRead"].Unload(Filter);
		CommonClientServer.SupplementTable(ObjectsToLock, HandlerObjects);
		HandlerObjects.GroupBy("MetadataObject");
		HandlerObjects.Sort("MetadataObject");
	EndIf;
	If HandlerObjects.Count() = 0 Then
		Return "";
	EndIf;
	If CodeLayout.SetTags Then
		FillObjectsTags("MetadataObject", HandlerObjects, CodeLayout, HandlerTags);
	EndIf;
	
	SetName = StrReplace(ObjectsSetName, "Objects", "");
	TagsTree = CollapseByTags(HandlerObjects, CodeLayout);
	ObjectsGroupsRows = New Array;
	For IndexOf = 0 To TagsTree.Rows.Count()-1 Do
		Branch1 = TagsTree.Rows[IndexOf];
		ObjectsGroupsText = ObjectsGroupsTextRecursively(Branch1, CodeLayout, SetName);
		If ValueIsFilled(Branch1.Tags1) And IndexOf <> TagsTree.Rows.Count()-1 Then
			ObjectsGroupsText = ObjectsGroupsText + Chars.LF;
		EndIf;
		ObjectsGroupsRows.Add(ObjectsGroupsText);
	EndDo;
	ObjectsText = StrConcat(ObjectsGroupsRows, Chars.LF);
	Template = "
	|	%1 = New Array;
	|%2
	|	Handler.%3 = StrConcat(%1, "","");";
	Result = StringFunctionsClientServer.SubstituteParametersToString(Template, SetName, ObjectsText, ObjectsSetName);
	
	Return Result;
	
EndFunction

&AtServer
Function ObjectsGroupsTextRecursively(Branch1, CodeLayout, ObjectsSetName)
	
	ObjectsStrings = New Array;
	For Each MetadataObject In Branch1.Rows Do
		If MetadataObject.Rows.Count() > 0 Then
			ObjectsGroupsText = ObjectsGroupsTextRecursively(MetadataObject, CodeLayout, ObjectsSetName);
			ObjectsStrings.Add(ObjectsGroupsText);
			Continue;
		EndIf;
		ObjectText = Chars.Tab + ObjectsSetName + ".Add(" + FullObjectMetadataPath(MetadataObject.MetadataObject) + ");";
		ObjectsStrings.Add(ObjectText);
	EndDo;
	
	ObjectsText = StrConcat(ObjectsStrings, Chars.LF);
	If StrStartsWith(TrimAll(ObjectsStrings[ObjectsStrings.UBound()]), "//") Then
		ObjectsText = ObjectsText + Chars.LF;
	EndIf;
	If Not IsBlankString(Branch1.Tags1) Then
		TagsArray = StrSplit(Branch1.Tags1, ",");
		For IndexOf = 0 To TagsArray.UBound() Do
			Tag = TagsArray[IndexOf];
			Template = "	%1" + Chars.LF + "%2" + Chars.LF + "	%3";
			If (IndexOf + 1)%2 <> 0 And TagsArray.Count() > 1 Then
				Template = Chars.LF + "	%1" + Chars.LF + "%2" + Chars.LF + "	%3" + Chars.LF;
			EndIf;
			TagDetails = CodeLayout.Tags1.LongDesc[Tag]; // See TagDetails
			ObjectsText = StringFunctionsClientServer.SubstituteParametersToString(Template, TagDetails.Begin, ObjectsText, TagDetails.End);
		EndDo;
	EndIf;
	
	Return ObjectsText;
	
EndFunction

&AtServer
Function FullObjectMetadataPath(ObjectName)
	
	NameParts = StrSplit(ObjectName, ".");
	NameParts[0] = PluralForm.Get(NameParts[0]);
	NameParts.Insert(0, "Metadata");
	NameParts.Add("FullName()");
	Return StrConcat(NameParts,".");
	
EndFunction

&AtServer
Function FillObjectsTags(ObjectNameAttribute, HandlerObjects, CodeLayout, ExternalTags = Undefined, SortByTags = True)
	
	IsProcedureName = ObjectNameAttribute = "Procedure" Or ObjectNameAttribute = "Procedure2";
	ModuleTags = CodeLayout.Tags1.ByModules[CodeLayout.ModuleName];
	If HandlerObjects.Columns.Find("Tags1") = Undefined Then
		HandlerObjects.Columns.Add("Tags1", New TypeDescription("String",,New StringQualifiers(100)));
	EndIf;
	HasUpdateModuleTags = HandlerObjects.Columns.Find("UpdateModuleTags") <> Undefined;
	If ModuleTags = Undefined Then
		Return HandlerObjects;
	EndIf;
	UnnecessaryTags = New Array;
	UnnecessaryTags = UnnecessaryTagsInArea(ExternalTags, CodeLayout);
	For Each UsedObject In HandlerObjects Do
		Tags1 = New Array;
		If IsProcedureName Then
			ProcedureName = UsedObject[ObjectNameAttribute];
			TagsDetails = CodeLayout.Tags1.ByHandlers.Find(ProcedureName, "Procedure");
			If TagsDetails <> Undefined Then
				Tags1 = StrSplit(TagsDetails.UpdateModuleTags,",", False);
			EndIf;
			ObjectName = ObjectNameFromDataProcessorProcedure(UsedObject[ObjectNameAttribute]);
		Else
			ObjectName = UsedObject[ObjectNameAttribute];
		EndIf;
		TagsDetails = CodeLayout.Tags1.ByObjects.Find(ObjectName, "Name");
		If TagsDetails <> Undefined Then
			CommonClientServer.SupplementArray(Tags1, StrSplit(TagsDetails.Tags1,",", False), True);
		EndIf;
		If Tags1.Count() > 0 Then
			ObjectTags = New Array;
			For Each Tag In Tags1 Do
				UnnecessaryTag = UnnecessaryTags.Find(Tag) <> Undefined;
				If Not UnnecessaryTag Then
					ObjectTags.Add(Tag);
				EndIf;
			EndDo;
			UsedObject.Tags1 = StrConcat(ObjectTags, ",");
			If HasUpdateModuleTags Then
				ExternalTags = UsedObject.Tags1 + ?(IsBlankString(UsedObject.Tags1),"",",") + UsedObject.UpdateModuleTags;
				UsedObject.UpdateModuleTags = ExternalTags;
			EndIf;
		EndIf;// Object's tags are found.
	EndDo;
	SortFields = ObjectNameAttribute;
	If SortByTags Then
		SortFields = "Tags1," + ObjectNameAttribute;
	EndIf;
	HandlerObjects.Sort(SortFields);
	
	Return HandlerObjects;
	
EndFunction

&AtServer
Function FillModulesTagsBySubsystems(ManagersModules, CodeLayout)
	
	ObjectNameAttribute = "ObjectName";
	If ManagersModules.Columns.Find("ExternalTags") = Undefined Then
		ManagersModules.Columns.Add("ExternalTags", New TypeDescription("String",,New StringQualifiers(100)));
	EndIf;
	ExternalTags = New Array;
	ExternalTags = UnnecessaryTagsInArea("", CodeLayout);
	For Each ObjectModule In ManagersModules Do
		ObjectName = ObjectModule[ObjectNameAttribute];
		TagsDetails = CodeLayout.Tags1.ByObjects.Find(ObjectName, "Name");
		If TagsDetails <> Undefined Then
			ModuleTags = Common.CopyRecursive(ExternalTags); // Array - 
			For Each Tag In StrSplit(TagsDetails.Tags1,",") Do
				ExternalTag = ExternalTags.Find(Tag) <> Undefined;
				If Not ExternalTag Then
					ModuleTags.Add(Tag);
				EndIf;
			EndDo;
			ObjectModule.ExternalTags = StrConcat(ModuleTags, ",");
		EndIf;// Object's tags are found.
	EndDo;
	ManagersModules.Sort(ObjectNameAttribute);
	
	Return ManagersModules;
	
EndFunction

&AtServer
Function UnnecessaryTagsInArea(ExternalTags, CodeLayout)
	
	UnnecessaryTags = StrSplit(ExternalTags, ",", False);
	NestedTags = New Array;
	For Each UnnecessaryTag In UnnecessaryTags Do
		TagLibraries = CodeLayout.Tags1.ByLibraries.FindRows(New Structure("Tag",UnnecessaryTag));
		If TagLibraries = Undefined Then
			Continue;
		EndIf;
		For Each Name In TagLibraries Do
			NestedLibrariesTags = CodeLayout.Tags1.NestedLibraries[Name.Library];
			If NestedLibrariesTags <> Undefined Then
				CommonClientServer.SupplementArray(NestedTags, NestedLibrariesTags, True);
			EndIf;
		EndDo;
	EndDo;
	CommonClientServer.SupplementArray(UnnecessaryTags, NestedTags, True);
	// Don't add pivot library tags to the module.
	NestedLibrariesTags = CodeLayout.Tags1.NestedLibraries[CodeLayout.ConfigurationName];
	If NestedLibrariesTags <> Undefined And Not CodeLayout.IsManagerModule Then
		CommonClientServer.SupplementArray(UnnecessaryTags, NestedLibrariesTags, True);
	EndIf;
	
	Return UnnecessaryTags;
	
EndFunction

&AtServer
Function ObjectNameFromDataProcessorProcedure(DataProcessorProcedureName)
	
	NameParts = StrSplit(DataProcessorProcedureName, ".");
	If NameParts.Count() = 2 Then
		ObjectName = "CommonModule." + NameParts[0];
	Else
		NameParts[0] = SingularForm[NameParts[0]];
		NameParts.Delete(NameParts.UBound());
		ObjectName = StrConcat(NameParts, ".");
	EndIf;
	
	Return ObjectName;
	
EndFunction

&AtServer
Function CollapseByTags(Handlers, CodeLayout) 
	
	TagsTree = New ValueTree;
	For Each Column In Handlers.Columns Do
		TagsTree.Columns.Add(Column.Name, Column.ValueType);
	EndDo;
	If TagsTree.Columns.Find("Tags1") = Undefined Then
		TagsTree.Columns.Add("Tags1", New TypeDescription("String",,New StringQualifiers(100)));
	EndIf;
	
	If Not CodeLayout.SetTags Then
		TagBranch = TagsTree.Rows.Add();
		For Each Handler In Handlers Do
			NewRow = TagBranch.Rows.Add();
			FillPropertyValues(NewRow, Handler);
		EndDo;
	Else
		Nesting = CodeLayout.Tags1.Nesting;
		TagBranch = Undefined; // ValueTreeRow -
		IndexOf = 0;
		While IndexOf < Handlers.Count() Do
			Handler = Handlers[IndexOf];
			If TagBranch = Undefined Or TagBranch.Tags1 <> Handler.Tags1 Then
				TagBranch = TagsTree.Rows.Add();
				TagBranch.Tags1 = Handler.Tags1;
				AddTagHandlers(IndexOf, Handlers, TagBranch, Nesting);
				Continue;
			EndIf;
			NewRow = TagBranch.Rows.Add();
			FillPropertyValues(NewRow, Handler);
			IndexOf = IndexOf + 1;
		EndDo;
	EndIf;
	
	Return TagsTree;
	
EndFunction

&AtServer
Procedure AddTagHandlers(IndexOf, Handlers, TagBranch, Nesting)
	
	CommonTag = Nesting.Rows.Find(TagBranch.Tags1,"Tag",True);
	While IndexOf < Handlers.Count() Do
		Handler = Handlers[IndexOf];
		If TagBranch.Tags1 <> Handler.Tags1 Then
			If CommonTag = Undefined
				Or CommonTag.Rows.Find(Handler.Tags1) = Undefined Then
				Break;
			EndIf;
			NestedTagBranch = TagBranch.Rows.Add();
			NestedTagBranch.Tags1 = Handler.Tags1;
			AddTagHandlers(IndexOf, Handlers, NestedTagBranch, Nesting);
			Continue;
		EndIf;
		NewRow = TagBranch.Rows.Add();
		FillPropertyValues(NewRow, Handler);
		IndexOf = IndexOf + 1;
	EndDo;
	
EndProcedure

// Parameters:
//   ProcedureName - String
//   ProcedureText - String
//   CodeLayout - Structure:
//   * Tags1 - See GetCutTagsInfo
//   * ProcedureName - String
//   * AddDetailsArea - Boolean
//   * IsManagerModule - Boolean
//   * LocalizationTags - String
//
&AtServer
Procedure PutInProcedure(ProcedureName, ProcedureText, CodeLayout)
	
	If CodeLayout.SetTags And CodeLayout.LocalizationModule And Not CodeLayout.IsDetailsProcedure Then
		LocalizationTag = CodeLayout.Tags1.LongDesc[CodeLayout.LocalizationTags]; // See TagDetails
		If LocalizationTag <> Undefined Then
			Template = "%1
			|%2
			|%3";
			ProcedureText = StringFunctionsClientServer.SubstituteParametersToString(Template, LocalizationTag.Begin, ProcedureText, LocalizationTag.End);
		EndIf;
	EndIf;
	
	ProcedureText = 
	"Procedure " + ProcedureName + "(Handlers) Export
	|
	|"+ ProcedureText +"
	|
	|EndProcedure";
	
EndProcedure

#EndRegion

#Region CutTagsInformationRecords

// Parameters:
//   Settings - Arbitrary
// Returns:
//   Structure:
//   * ByObjects - ValueTable
//   * ByLibraries - ValueTable
//   * ByModules - Map
//   * LongDesc - String
//   * LibraryExtension - Structure
//   * LibrariesAsString - String
//   * Order - Array
//   * NestedLibraries - Map
//   * Nesting - ValueTree:
//   ** Tag - String
//   * ByModules - Map
//
&AtServer
Function GetCutTagsInfo(Settings)
	
	LibrariesInfo = GetLibrariesInfo(Settings);
	
	LibrariesObjects = LibrariesInfo.LibrariesObjects;
	LibrariesTags = LibrariesInfo.LibrariesTags;
	LibrariesAsString = LibrariesInfo.LibrariesAsString;
	LibraryExtension = LibrariesInfo.LibraryExtension;
	
	ObjectsTags = LibrariesObjects.CopyColumns(); // ValueTable - 
	StringType100 = New TypeDescription("String",,New StringQualifiers(100));
	ObjectsTags.Columns.Add("Tags1", StringType100);
	TagsDetails = GetTagsDetailsAndOrder(Settings);
	TagsOrder = Settings.TagsDetails["OrderTags"];
	
	AllLibraries = StrSplit(LibrariesAsString, ",",False);
	TotalConfigurations = AllLibraries.Count();
	For Each LibraryObject In LibrariesObjects Do
		If LibraryObject.TotalOccurrences = TotalConfigurations Then
			Continue;
		EndIf;
		
		ExcludeFromAsString = "";
		For Each LibraryName In AllLibraries Do
			Extensible = LibraryExtension[LibraryName];
			If Not LibraryObject[LibraryName] Then
				ExcludeFromAsString = ExcludeFromAsString + ?(Not IsBlankString(ExcludeFromAsString), ",", "") + LibraryName;
				If Extensible <> Undefined Then
					If TypeOf(Extensible) = Type("Array") Then
						For Each Page1 In Extensible Do
							ExcludeFromAsString = StrReplace(ExcludeFromAsString, Page1, LibraryName);
						EndDo;
					Else
						ExcludeFromAsString = StrReplace(ExcludeFromAsString, Extensible, LibraryName);
					EndIf;
				EndIf;
			EndIf;
		EndDo;
		
		ObjectTags = New Array;
		ExcludeFromConfiguration = CommonClientServer.CollapseArray(StrSplit(ExcludeFromAsString, ",",False));
		For Each LibraryName In ExcludeFromConfiguration Do
			Filter = New Structure("Library", LibraryName);
			FoundTags = LibrariesTags.FindRows(Filter);
			For Each String In FoundTags Do 
				ObjectTags.Add(String.Tag);
			EndDo;
		EndDo;
		
		SetTagsOrder(ObjectTags, TagsOrder);
		
		NewRow = ObjectsTags.Add();
		FillPropertyValues(NewRow, LibraryObject);
		NewRow.Tags1 = StrConcat(ObjectTags, ",");
		
	EndDo;
	
	ModulesTags = New Map;
	For Each LongDesc In Settings.TagsDetails["configurations"] Do
		Module = LongDesc.Value["module"];
		If Module = Undefined Then
			Continue;
		EndIf;
		
		ModuleTags = LongDesc.Value["outTags"];
		If ModuleTags <> Undefined Then
			ModulesTags.Insert(Module, ModuleTags);
		EndIf;
	EndDo;
	
	
	Tags1 = New Structure;
	Tags1.Insert("ByObjects", ObjectsTags);
	Tags1.Insert("ByLibraries", LibrariesTags);
	Tags1.Insert("ByModules", ModulesTags);
	Tags1.Insert("LongDesc", TagsDetails);
	Tags1.Insert("LibraryExtension", LibraryExtension);
	Tags1.Insert("LibrariesInNestingOrder", LibrariesInfo.LibrariesInNestingOrder);
	Tags1.Insert("LibrariesAsString", LibrariesAsString);
	Tags1.Insert("Order", TagsOrder);
	TagsTree = New ValueTree;
	TagsTree.Columns.Add("Tag", StringType100);
	Tags1.Insert("Nesting", TagsTree);
	
	NestedLibraries = New Map;
	For Each Extension In LibraryExtension Do
		NestedLibraryTags = New Array;
		AddNestedLibrariesTags(NestedLibraryTags, Extension.Key, Tags1);
		NestedLibraries.Insert(Extension.Key, NestedLibraryTags);
		
		Tag = LibraryTag(Extension.Value, LibrariesTags);
		If Not IsBlankString(Tag) Then
			TagBranch = TagsTree.Rows.Add();
			TagBranch.Tag = Tag;
			Tag = LibraryTag(Extension.Key, LibrariesTags);
			If Not IsBlankString(Tag) Then
				NestedTag = TagBranch.Rows.Add();
				NestedTag.Tag = Tag;
				AddNestedTags(NestedTag, Extension.Key, Tags1);
			EndIf;
			If TagBranch.Rows.Count() = 0 Then
				TagsTree.Rows.Delete(TagBranch);
			EndIf;
		EndIf;
	EndDo;
	Tags1.Insert("NestedLibraries", NestedLibraries);
	
	Return Tags1;
	
EndFunction

&AtServer
Procedure AddNestedTags(TagBranch, LibraryName, TagsDetails)
	
	LibraryOccurrences = Undefined;
	For Each Extension In TagsDetails.LibraryExtension Do
		If LibraryName = Extension.Value Then
			LibraryOccurrences = Extension.Key;
			Break;
		EndIf;
	EndDo;
	If LibraryOccurrences <> Undefined Then
		Tag = LibraryTag(LibraryOccurrences, TagsDetails.ByLibraries);
		If Not IsBlankString(Tag) Then
			NestedTag = TagBranch.Rows.Add();
			NestedTag.Tag = Tag;
			AddNestedTags(NestedTag, LibraryOccurrences, TagsDetails);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function LibraryTag(Library, LibrariesTags)
	
	Result = "";
	FoundRow = LibrariesTags.Find(Library, "Library");
	If FoundRow <> Undefined Then
		Result = FoundRow.Tag;
	EndIf;
	Return Result;
	
EndFunction

&AtServer
Procedure SetTagsOrder(Tags1, TagsOrder)
	
	OrderedResult = New Array;
	For Each TagInOrder In TagsOrder Do
		
		If Tags1.Find(TagInOrder) <> Undefined Then
			OrderedResult.Add(TagInOrder);
		EndIf;
		
	EndDo;
	
	Tags1 = OrderedResult;
	
EndProcedure

&AtServer
Procedure AddNestedLibrariesTags(Tags1, LibraryName, TagsDetails)
	
	NestedLibrary = TagsDetails.LibraryExtension[LibraryName];
	If NestedLibrary <> Undefined Then
		Filter = New Structure("Library", NestedLibrary);
		FoundRows = TagsDetails.ByLibraries.FindRows(Filter);
		For Each String In FoundRows Do
			Tags1.Add(String.Tag);
		EndDo;
		AddNestedLibrariesTags(Tags1, NestedLibrary, TagsDetails);
	EndIf;
	
EndProcedure

// Parameters:
//   Settings - Arbitrary
// Returns:
//   KeyAndValue - Details:
//   * Key - String - tag description
//   * Value - See TagDetails
//
&AtServer
Function GetTagsDetailsAndOrder(Settings)
	
	Tags1 = New Map;
	If Settings.TagsDetails["tags"] <> Undefined Then
		TagsOrder = New Array;
		For Each LongDesc In Settings.TagsDetails["tags"] Do
			
			TagBorders = TagDetails();
			TagBorders.Begin = LongDesc["begin"];
			TagBorders.End = LongDesc["end"];
			Tags1.Insert(LongDesc["id"], TagBorders);
			TagsOrder.Add(LongDesc["id"]);
			
		EndDo;
		Settings.TagsDetails.Insert("OrderTags", TagsOrder);
	EndIf;
	
	Return Tags1;
	
EndFunction

// Returns:
//   Structure:
//   * Begin - String
//   * End - String
//
&AtServer
Function TagDetails()
	
	Return New Structure("Begin, End");
	
EndFunction

&AtServer
Function GetLibrariesInfo(Settings)
	
	StringType100 = New TypeDescription("String",,New StringQualifiers(100));
	StringType300 = New TypeDescription("String",,New StringQualifiers(300));
	NumberType10 = New TypeDescription("Number",New NumberQualifiers(10, 0));
	
	LibrariesTags = New ValueTable;
	LibrariesTags.Columns.Add("Library", StringType100);
	LibrariesTags.Columns.Add("Tag", StringType100);
	
	BooleanType = New TypeDescription("Boolean");
	StringType300 = New TypeDescription("String",,New StringQualifiers(300));
	
	LibrariesObjects = New ValueTable;
	LibrariesObjects.Columns.Add("Name", StringType300);
	LibrariesObjects.Columns.Add("TotalOccurrences", NumberType10);
	For Each Name In Settings.AllObjects Do
		NewRow = LibrariesObjects.Add();
		NewRow.Name = Name;
	EndDo;
	
	LibrariesAsString = "";
	LibraryExtension = New Map;
	If Settings.TagsDetails["configurations"] <> Undefined Then
		For Each Library In Settings.TagsDetails["configurations"] Do
			
			NestedLibrary = Library.Value["extends"];
			If NestedLibrary <> Undefined Then
				LibraryExtension.Insert(Library.Key, NestedLibrary);
			EndIf;
			
			Content = Library.Value["content"];
			If Not ValueIsFilled(Content) Then
				Continue;
			EndIf;
			
			ClippingTags = Library.Value["outTags"];
			If ClippingTags = Undefined Then
				Continue;
			EndIf;
			
			ModuleName = Library.Value["module"];
			If Not ValueIsFilled(ModuleName) Then
				Continue;
			EndIf;
			
			If LibrariesObjects.Columns.Find(Library.Key) = Undefined Then
				LibrariesObjects.Columns.Add(Library.Key, BooleanType);
				LibrariesAsString = LibrariesAsString + ?(LibrariesAsString <> "", ",","") + Library.Key;
			EndIf;
			
			For Each Tag In ClippingTags Do
				NewTag = LibrariesTags.Add();
				NewTag.Library = Library.Key;
				NewTag.Tag = Tag;
			EndDo;
			Objects = Library.Value["Objects"];
			For Each ObjectName In Objects Do
				NewRow = LibrariesObjects.Add();
				NewRow.Name = ObjectName.Key;
				NewRow.TotalOccurrences = 1;
				NewRow[Library.Key] = True;
			EndDo;
		
		EndDo;
	EndIf;
	LibrariesNesting = DetermineLibrariesNesting(LibraryExtension);
	CommonClientServer.SupplementArray(LibrariesNesting, StrSplit(LibrariesAsString, ","), True);
	
	LibrariesObjects.GroupBy("Name", "TotalOccurrences," + LibrariesAsString);
	LibrariesObjects.Sort("Name, TotalOccurrences DESC");
	LibrariesObjects.Indexes.Add("Name");
	
	LibrariesTags.Sort("Library, Tag");
	LibrariesTags.Indexes.Add("Library");
	
	Result = New Structure;
	Result.Insert("LibrariesObjects", LibrariesObjects);
	Result.Insert("LibrariesTags", LibrariesTags);
	Result.Insert("LibrariesAsString", LibrariesAsString);
	Result.Insert("LibraryExtension", LibraryExtension);
	Result.Insert("LibrariesInNestingOrder", LibrariesNesting);
	
	Return Result
	
EndFunction

&AtServer
Procedure DefineTagsForObjectsNotIncludedInConfiguration(TagsDetails)
	
	ExtenderTags = ExtenderTags(TagsDetails);
	For Each LongDesc In TagsDetails["configurations"] Do
		LongDesc.Value.Insert("outTags", New Array);
		ClippingTags = LongDesc.Value["outTags"]; // Array - 
		
		Tags1 = LongDesc.Value["tags"];
		If Tags1 <> Undefined Then
			Extenders = ExtenderTags[LongDesc.Key];
			If Extenders = Undefined Then
				Extenders = New Array; 
			EndIf;
			For Each Tag In Tags1 Do
				IndexOf = Extenders.Find(Tag);
				If IndexOf = Undefined Then
					ClippingTags.Add(Tag);
				EndIf;
			EndDo;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Function DetermineLibrariesNesting(LinkedList)
	
	Nesting = New ValueTable;
	Nesting.Columns.Add("Library", New TypeDescription("String",,New StringQualifiers(100)));
	Nesting.Columns.Add("TotalOccurrences", New TypeDescription("Number",New NumberQualifiers(10, 0)));
	For Each Level In LinkedList Do
	
		NewRow = Nesting.Add();
		NewRow.Library = Level.Value;
		NewRow.TotalOccurrences = 1;
		
		AddNestedOne(Level.Value, Nesting, LinkedList);
		
		If Nesting.Find(Level.Key,"Library")= Undefined Then
			NewRow = Nesting.Add();
			NewRow.Library = Level.Key;
			NewRow.TotalOccurrences = 0;
		EndIf;
		
	EndDo;
	Nesting.GroupBy("Library","TotalOccurrences");
	Nesting.Sort("TotalOccurrences DESC");
	
	Return Nesting.UnloadColumn("Library");
	
EndFunction

&AtServer
Procedure AddNestedOne(Parent, Nesting, LinkedList, LevelNumber = 1)
	
	NestedRow = LinkedList[Parent];
	
	If NestedRow <> Undefined Then
		AddNestedOne(NestedRow, Nesting, LinkedList, LevelNumber+1);
	EndIf;
	NewRow = Nesting.Add();
	NewRow.Library = Parent;
	NewRow.TotalOccurrences = LevelNumber;
	
EndProcedure

&AtServer
Function ExtenderTags(TagsDetails)
	
	ExtenderTags = New Map;
	For Each LongDesc In TagsDetails["configurations"] Do
		ConfigurationToExtend = LongDesc.Value["extends"];
		If ConfigurationToExtend <> Undefined Then
			Tags1 = LongDesc.Value["tags"];
			If Tags1 <> Undefined Then
				Configuration = ExtenderTags[ConfigurationToExtend];
				If Configuration = Undefined Then
					ExtenderTags.Insert(ConfigurationToExtend, Tags1);
				Else
					CommonClientServer.SupplementArray(Configuration, Tags1, True);
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	Return ExtenderTags;
	
EndFunction

#EndRegion

#Region ConfigurationComponents

&AtClient
Function GetAllOriginalConfigurationObjects()
	
	FileName = Object.SRCDirectory + "Configuration\Configuration.mdo";
	AllObjects = New Array;
	
	SubsystemFile = New File(FileName);
	If Not SubsystemFile.Exists() Then
		Return AllObjects;
	EndIf;
	
	RUClassName = RussianClassesNames();
	
	Tags1 = New Array;
	Tags1.Add("accountingRegisters");
	Tags1.Add("accumulationRegisters");
	Tags1.Add("businessProcesses");
	Tags1.Add("calculationRegisters");
	Tags1.Add("catalogs");
	Tags1.Add("chartsOfAccounts");
	Tags1.Add("chartsOfCalculationTypes");
	Tags1.Add("chartsOfCharacteristicTypes");
	Tags1.Add("constants");
	Tags1.Add("commonModules");
	Tags1.Add("documents");
	Tags1.Add("informationRegisters");
	Tags1.Add("reports");
	Tags1.Add("tasks");
	
#If Not WebClient Then
	Text = New TextReader;
	Text.Open(FileName, TextEncoding.UTF8);
	
	FileString = Text.ReadLine();
	While FileString <> Undefined Do
		
		FileString = Text.ReadLine();
		Tag = FindTag(FileString, Tags1);
		If Tag <> Undefined Then
			
			FileString = StrReplace(FileString, "<"+Tag+">", "");
			ObjectName = TrimAll(StrReplace(FileString, "</"+Tag+">", ""));
			
			NameParts = StrSplit(ObjectName, ".");
			NameParts[0] = RUClassName[NameParts[0]];
			
			AllObjects.Add(StrConcat(NameParts, "."));
			
		EndIf;
		
	EndDo;
#EndIf
	
	Return AllObjects;
	
EndFunction

&AtClient
Function FindTag(FileString, Tags1)
	
	For Each Tag In Tags1 Do
		If StrFind(FileString, Tag) > 0 Then
			 Return Tag;
		EndIf;
	EndDo;
	Return Undefined;
	
EndFunction

#EndRegion

#Region SubsystemComposition
&AtClient
Procedure GetSubsystemsObjects(ConfigurationsDetails)
	
	RussianClassesNames = RussianClassesNames();
	For Each LongDesc In ConfigurationsDetails Do
		SubsystemObjects = New Map;
		Subsystems = LongDesc.Value["content"];
		If ValueIsFilled(Subsystems) Then
			For Each Subsystem In Subsystems Do
				AddSubsystemObjects(SubsystemObjects, Subsystem, RussianClassesNames);
			EndDo;
		EndIf;
		ExceptionSubsystems = LongDesc.Value["except_content"];
		If ValueIsFilled(ExceptionSubsystems) Then
			ExceptionObjects = New Map;
			For Each Subsystem In ExceptionSubsystems Do
				AddSubsystemObjects(ExceptionObjects, Subsystem, RussianClassesNames);
			EndDo;
			For Each ExceptionObject In ExceptionObjects Do
				SubsystemObjects.Delete(ExceptionObject.Key);
			EndDo;
		EndIf;
		
		LongDesc.Value.Insert("Objects", SubsystemObjects);
	EndDo;
	
EndProcedure

&AtClient
Procedure AddSubsystemObjects(ConfigurationObjects, Subsystem, RussianClassesNames)
	
	NameParts = StrSplit(Subsystem, ".");
	PathPart = "Subsystems\" + StrConcat(NameParts, "\Subsystems\");
	FileName = Object.SRCDirectory + PathPart + "\" + NameParts[NameParts.UBound()] + ".mdo";
	SubsystemFile = New File(FileName);
	
	If Not SubsystemFile.Exists() Then
		Return;
	EndIf;
	
#If Not WebClient Then
	Text = New TextReader;
	Text.Open(FileName, TextEncoding.UTF8);
	
	FileString = Text.ReadLine();
	While FileString <> Undefined Do
		
		If StrFind(FileString, "<content>") > 0 Then
			FileString = TrimAll(StrReplace(FileString, "<content>", ""));
			FileString = TrimAll(StrReplace(FileString, "</content>", ""));
			NameParts = StrSplit(FileString, ".");
			NameParts[0] = RussianClassesNames[NameParts[0]];
			If NameParts[0] <> Undefined Then
				ObjectName = StrConcat(NameParts, ".");
				ConfigurationObjects.Insert(ObjectName, ObjectName);
			EndIf;
			
		ElsIf StrFind(FileString, "<subsystems>") > 0 Then
			FileString = TrimAll(StrReplace(FileString, "<subsystems>", ""));
			FileString = TrimAll(StrReplace(FileString, "</subsystems>", ""));
			NameParts = New Array;
			NameParts.Add(Subsystem);
			NameParts.Add(FileString);
			NestedSubsystemName = StrConcat(NameParts, ".");
			AddSubsystemObjects(ConfigurationObjects, NestedSubsystemName, RussianClassesNames);
		EndIf;
		
		FileString = Text.ReadLine();
		
	EndDo;
#EndIf
	
EndProcedure

&AtClient
// Returns the mapping of Russian and English names of metadata object classes being processed.
Function RussianClassesNames()
	
	Result = New Map;
	
	Result.Insert("AccountingRegister", "AccountingRegister");
	Result.Insert("AccumulationRegister", "AccumulationRegister");
	Result.Insert("BusinessProcess", "BusinessProcess");
	Result.Insert("CalculationRegister", "CalculationRegister");
	Result.Insert("Catalog", "Catalog");
	Result.Insert("ChartOfAccounts", "ChartOfAccounts");
	Result.Insert("ChartOfCalculationTypes", "ChartOfCalculationTypes");
	Result.Insert("ChartOfCharacteristicTypes", "ChartOfCharacteristicTypes");
	Result.Insert("Constant", "Constant");
	Result.Insert("CommonModule", "CommonModule");// Specified in other handlers' priority lists.
	Result.Insert("Document", "Document");
	Result.Insert("ExchangePlan", "ExchangePlan");
	Result.Insert("InformationRegister", "InformationRegister");
	Result.Insert("Task", "Task");
	Result.Insert("Sequence", "Sequence");
	Result.Insert("Report", "Report");// Specified in locked objects.
	
	Return Result;
	
EndFunction

#EndRegion

#Region YAMLReader
&AtClient
Function ReadYAMLFile(FileName)
	
	Result = New Map;
	
	File = New File(FileName);
	If Not File.Exists() Then
		Template = NStr("en = 'Settings file ""%1"" was not found';");
		Raise StringFunctionsClientServer.SubstituteParametersToString(Template, FileName);
	EndIf;
	
#If Not WebClient Then
	FileText = New TextDocument;
	FileText.Read(FileName, TextEncoding.UTF8);
	Try
		
		ReadYAMLStrings(Result, FileText);
		
	Except
		ErrorText = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		MessageText = Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot read file %1.';"), FileName);
		MessageText = MessageText  + Chars.LF + NStr("en = 'Reason';")+":" + Chars.LF;
		MessageText = MessageText  + ErrorText;
		Raise MessageText;
	EndTry;
#EndIf
	
	Return Result;
	
EndFunction

&AtClient
Procedure ReadYAMLStrings(Result, FileText, LineNumber = 0, Level = 0, ReadMultilineString = False)
	
	Try
		TotalRows = FileText.LineCount();
		While LineNumber <= TotalRows Do
			
			LineNumber = LineNumber + 1;
			FileString = FileText.GetLine(LineNumber);
			If TrimAll(FileString) = "" And Not ReadMultilineString Or Left(TrimAll(FileString), 1) = "#" Then
				Continue;
			EndIf;
			
			Parameter = ValueFromYamlString(FileString);
			If Parameter.Level < Level Then
				LineNumber = LineNumber - 1;
				Break;
			EndIf;
			
			If Parameter.ArrayElement Then
				If TypeOf(Result) <> Type("Array") Then
					Result = New Array;
				EndIf;
				If IsBlankString(Parameter.Key) Then
					AddToYAMLResult(Result, Parameter);
				Else
					Result.Add(New Map);
					AddToYAMLResult(Result[Result.UBound()], Parameter);
					ReadYAMLStrings(Result[Result.UBound()], FileText, LineNumber, Parameter.Level+1);
				EndIf;
				
			ElsIf Parameter.Value = "|" Then
				Parameter.Value = "";
				ReadYAMLStrings(Parameter.Value, FileText, LineNumber, Parameter.Level+1, True);
				AddToYAMLResult(Result, Parameter);
				
			ElsIf Not ValueIsFilled(Parameter.Value) Then
				
				ReadYAMLStrings(Parameter.Value, FileText, LineNumber, Parameter.Level+1);
				AddToYAMLResult(Result, Parameter);
				
			Else
				AddToYAMLResult(Result, Parameter);
				
			EndIf;
			
		EndDo;
	
	Except
		ErrorText = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		MessageText = Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot parse string: %1';"), FileString);
		MessageText = MessageText  + Chars.LF + NStr("en = 'Reason';")+":" + Chars.LF;
		MessageText = MessageText  + ErrorText;
		Raise MessageText;
	EndTry;
	
EndProcedure

&AtClient
Procedure AddToYAMLResult(Result, Parameter)
	
	If ValueIsFilled(Parameter.Key) And TypeOf(Result) <> Type("Map") Then
		Result = New Map;
	EndIf;
	
	If TypeOf(Result) = Type("Map") Then
		Result.Insert(Parameter.Key, Parameter.Value);
		
	ElsIf TypeOf(Result) = Type("Array") Then
		Result.Add(Parameter.Value);
		
	ElsIf TypeOf(Result) = Type("String") Then
		Result = Result + Parameter.Value + Chars.LF;
		
	EndIf;
	
EndProcedure

&AtClient
Function ValueFromYamlString(Val YamlString)
	
	Var_Key = "";
	Value = Undefined;
	
	RowWithoutIndent = TrimL(YamlString);
	Indent = StrFind(YamlString,RowWithoutIndent)-1;
	Level = Indent;
	ArrayElement = False;
	
	YamlString = TrimAll(YamlString);
	If Left(YamlString,1) = "-" Then
		ArrayElement = True;
		Level = Level + 1;
		YamlString = TrimAll(Right(YamlString, StrLen(YamlString)-1));
	EndIf;
	
	Colon = StrFind(YamlString,":");
	If Colon <> 0 And Mid(YamlString, Colon, 2) <> ":\" And Mid(YamlString, Colon, 2) <> ":/" Then
		Var_Key     = TrimAll(Left(YamlString,  Colon - 1));
		Value = TrimAll(Mid(YamlString, Colon + 1));
		
	Else
		Value = YamlString;
		
	EndIf;
	
	Sharp = StrFind(Value, "#");
	If Sharp <> 0 Then
		Value = TrimAll(Left(Value,  Sharp - 1));
	EndIf;
	
	Result = New Structure("Key,Value,Level", Var_Key,Value,Level);
	Result.Insert("ArrayElement", ArrayElement);
	Return Result;
	
EndFunction
#EndRegion

#EndRegion

#Region QueueBuildingTest

&AtClient
Procedure WriteError(ObjectName, ErrorDescription = "",
                         ErrorInfo = Undefined, Var_Key = Undefined)
	 
	Error = CreateErrorDescription();
	Error.ErrorType              = NStr("en = 'An error occurred while building the queue of deferred update handlers';");
	Error.PlaybackOrder = ErrorDescription;
	Error.MetadataObject       = ObjectName;
	
	If ErrorInfo <> Undefined Then
		Error.SourceInformation   = ErrorProcessing.DetailErrorDescription(ErrorInfo);
	EndIf; 
	
	If ValueIsFilled(ErrorTextAddition) Then
		Error.PlaybackOrder = Error.PlaybackOrder + Chars.LF + ErrorTextAddition;
	EndIf; 
	If ValueIsFilled(ErrorDetectionDate) Then
		Error.DetectionDate = ErrorDetectionDate;
	EndIf; 
	If ValueIsFilled(RepositoryAddress) Then
		Error.RepositoryAddress = RepositoryAddress;
	EndIf;
	
	If ValueIsFilled(ErrorFileDirectory) Then
		
		File = New File(ErrorFileDirectory);
		If Not File.Exists() Then
			CreateDirectory(ErrorFileDirectory);
		ElsIf Not File.IsDirectory() Then
			DeleteFiles(ErrorFileDirectory);
			CreateDirectory(ErrorFileDirectory);
		EndIf; 
		
		ErrorFileName = AddPathSeparatorToEnd(ErrorFileDirectory);
		ErrorFileName = ErrorFileName + Format(CommonClient.SessionDate(), "DF=yyyyMMddHHmmss") 
		               + "_" + String(New UUID())+".xml";
		
		Result = New TextDocument;
#If Not WebClient Then
		Result.SetText(XMLErrorText(Error));
#EndIf
		Result.Write(ErrorFileName);
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function CreateErrorDescription() 

	Error = New Structure;
	
	Error.Insert("FormatVersion", "1.4");
	Error.Insert("UUID1", String(New UUID));
	Error.Insert("ErrorType", "");
	Error.Insert("SourceInformation", "");
	Error.Insert("PlaybackOrder", "");
	Error.Insert("ExpectedBehavior", "");
	Error.Insert("EmployeeResponsible", "");
	Error.Insert("DetectionCredibility", "Low"); // High or Low.
	Error.Insert("RepositoryAddress", "");
	
#If Client Or ThickClientManagedApplication Or ThinClient Or WebClient  Then
	
		SysInfo = New SystemInfo;
		Error.Insert("PlatformVersion", SysInfo.AppVersion);
		Error.Insert("ClientRAM", SysInfo.RAM);
		Error.Insert("ClientOSVersion", SysInfo.OSVersion);
		Error.Insert("ClientProcessor", SysInfo.Processor);
		Error.Insert("ClientPlatformType1", String(SysInfo.PlatformType));
		Error.Insert("ClientUserAgentInformation", SysInfo.UserAgentInformation);
		Error.Insert("ClientCurrentDate", CommonClient.SessionDate());
	
#EndIf
	
	Error.Insert("DetectionDate",   Date(1,1,1));
	Error.Insert("MetadataObjects", New Array); // To allow adding an array of metadata objects.
	// Register for a metadata object.
	Error.Insert("MetadataObject", "");
	Error.Insert("LocationClarification", "");
	Error.Insert("ScenarioCode", "");
	Error.Insert("ScenarioName", "");
	
	Error.Insert("FilesNames", New Array);
	
	Return Error;
	
EndFunction

#If Not WebClient Then
&AtClient
Function XMLErrorText(Error)
	
	If ValueIsFilled(Error.MetadataObject) Or ValueIsFilled(Error.LocationClarification) Then
		Error.MetadataObjects.Add(New Structure("MetadataObject, LocationClarification", Error.MetadataObject, Error.LocationClarification));
	EndIf; 
	
	Error.Delete("MetadataObject");
	Error.Delete("LocationClarification");
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	
	XDTOSerializer.WriteXML(XMLWriter, Error);
	
	Return XMLWriter.Close();
	
EndFunction
#EndIf

#EndRegion

#Region WriteERPSettings

&AtServer
Function GetSettingsTexts()
	
	DataProcessor = DataProcessorObject2();
	ClippingTags = DataProcessor.GetTemplate("cut_tags");
	
	SettingsTexts = New ValueList;
	SettingsTexts.Add(
		ClippingTags.GetText(), 
		NStr("en = 'Save the cut_tags.yml file to the .settings directory of the local design folder in the UTF-8 encoding';"));
	
	Return SettingsTexts;
	
EndFunction

#EndRegion

#Region SetBuildNumber

&AtClient
Procedure BuildNumberInputCompletion(Result, AdditionalParameters) Export
	
	If Result <> Undefined And Result > 0 Then
		If AdditionalParameters.BuildNumberForHandlers Then
			SetBuildNumberForHandlersAtServer(Result);
		Else
			NewConfigurationBuildNumber = Result;
		EndIf;
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetBuildNumberForHandlersAtServer(TheNewBuildNumber)
	
	DataProcessor = DataProcessorObject2();
	TheVersionNumberOfTheConfiguration = StrSplit(ConfigurationVersion, ".");
	MaxRevisionNumber = Number(TheVersionNumberOfTheConfiguration[1]);
	MaxSubrevisionNumber = Number(TheVersionNumberOfTheConfiguration[2]);
	SingleLibraryHandlers = True;
	VersionSet = New Array;
	PreviousSubsystem = Undefined;
	For Each LineID In Items.UpdateHandlers.SelectedRows Do
		Handler = Object.UpdateHandlers.FindByID(LineID);
		If PreviousSubsystem = Undefined Then
			PreviousSubsystem = Handler.Subsystem;
		EndIf;
		If StrOccurrenceCount(Handler.Version, ".") = 3 Then
			
			VersionNumbers = StrSplit(Handler.Version, ".");
			VersionNumbers[3] = Format(TheNewBuildNumber, "NZ=0; NG=0");
			
			Handler.Version = StrConcat(VersionNumbers, ".");
			Handler.VersionAsNumber = DataProcessor.VersionAsNumber(Handler.Version);
			Handler.Changed = True;
			
			VersionSet.Add(Handler);
			
			MaxRevisionNumber = Max(Number(VersionNumbers[1]), MaxRevisionNumber);
			MaxSubrevisionNumber = Max(Number(VersionNumbers[2]), MaxSubrevisionNumber);
			
			If PreviousSubsystem <> Handler.Subsystem Then
				SingleLibraryHandlers = False;
			EndIf;
			PreviousSubsystem = Handler.Subsystem;
		EndIf;
	EndDo;
	
	If SingleLibraryHandlers Then
		For Each Handler In VersionSet Do
			VersionNumbers = StrSplit(Handler.Version, ".");
			VersionNumbers[1] = Format(MaxRevisionNumber, "NZ=0; NG=0");
			VersionNumbers[2] = Format(MaxSubrevisionNumber, "NZ=0; NG=0");
			Handler.Version = StrConcat(VersionNumbers, ".");
			Handler.VersionAsNumber = DataProcessor.VersionAsNumber(Handler.Version);
			VersionNumbers.Delete(0);
			Handler.RevisionAsNumber = DataProcessor.VersionAsNumber(StrConcat(VersionNumbers, "."));
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormRadioButton

&AtClient
Procedure SetSimplifiedMode()
	
	ExtendedFormMode = False;
	Items.SwitchFormMode.Title = NStr("en = 'Go to advanced mode';");
	SetFormModeItemsVisibility();
	
EndProcedure

&AtClient
Procedure SetAdvancedMode()
	
	ExtendedFormMode = True;
	Items.SwitchFormMode.Title = NStr("en = 'Go to simplified mode';");
	SetFormModeItemsVisibility();
	
EndProcedure

&AtClient
Procedure SetFormModeItemsVisibility()
	
	Items.SaveToRepository.Visible = ExtendedFormMode;
	Items.SaveAllHandlersToRepository.Visible = ExtendedFormMode;
	Items.ImportExportSettingsGroup.Visible = ExtendedFormMode;
	Items.ShowERPSettings.Visible = ExtendedFormMode;
	Items.DebuggingGroup.Visible = ExtendedFormMode;
	
EndProcedure

#EndRegion

&AtServer
Function DataProcessorObject2()
	Return FormAttributeToValue("Object");
EndFunction

&AtClient
Function SettingsDirectory()
	Return StrReplace(Object.SRCDirectory, "\src\","\.settings\");
EndFunction

&AtClient
Function TempDirectory()
#If Not WebClient Then
	PathToDirectory = CommonClientServer.AddLastPathSeparator(GetTempFileName());
	CreateDirectory(PathToDirectory);
	Return PathToDirectory;
#EndIf
	
	Return "";
EndFunction

&AtClient
Procedure WriteErrorInformation(ResultFile)
	
	If ValueIsFilled(ResultFile) Then
		MessageText = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		Result = New TextDocument;
		Result.SetText(MessageText);
		Result.Write(ResultFile);
	EndIf;

EndProcedure

&AtServer
Procedure InitializeDataProcessorConstants()
	
	ConfigurationVersion = Metadata.Version;
	NewConfigurationVersion = Metadata.Version;
	
	DataProcessor = DataProcessorObject2();
	
	AnalysisRequiredStatus = NStr("en = 'Analysis required';");
	StatusChangedCheckProcedure = NStr("en = 'Check procedure is changed';");
	LowPriorityReadingStatus = NStr("en = 'Low order read';");
	SubsystemsToDevelop = New FixedArray(DataProcessor.SubsystemsToDevelop());
	
	PluralForm = New FixedMap(DataProcessor.PluralForm);
	SingularForm = New FixedMap(DataProcessor.SingularForm);
	
	EnglishClasses = New Map;
	EnglishClasses.Insert("Constants", "Constants");
	EnglishClasses.Insert("Catalogs", "Catalogs");
	EnglishClasses.Insert("Documents", "Documents");
	EnglishClasses.Insert("DocumentJournals", "DocumentJournals");
	EnglishClasses.Insert("DataProcessors", "DataProcessors");
	EnglishClasses.Insert("Enums", "Enums");
	EnglishClasses.Insert("ChartsOfCharacteristicTypes", "ChartsOfCharacteristicTypes");
	EnglishClasses.Insert("ExchangePlans", "ExchangePlans");
	EnglishClasses.Insert("ChartsOfAccounts", "ChartsOfAccounts");
	EnglishClasses.Insert("ChartsOfCalculationTypes", "ChartsOfCalculationTypes");
	EnglishClasses.Insert("InformationRegisters", "InformationRegisters");
	EnglishClasses.Insert("AccumulationRegisters", "AccumulationRegisters");
	EnglishClasses.Insert("AccountingRegisters", "AccountingRegisters");
	EnglishClasses.Insert("CalculationRegisters", "CalculationRegisters");
	EnglishClasses.Insert("BusinessProcesses", "BusinessProcesses");
	EnglishClasses.Insert("Tasks", "Tasks");
	
	EnglishNames =  New FixedMap(EnglishClasses);
	
EndProcedure

&AtClientAtServerNoContext
Function GetParametersFromString(Val ParametersString1)
	
	Result = New Structure;
	
	DoubleQuotationMarksChar = Char(34); // (")
	
	SubstringsArray = StrSplit(ParametersString1, ";");
	
	For Each ParameterString In SubstringsArray Do
		
		FirstEqualSignPosition = StrFind(ParameterString, "=");
		
		// Get parameter name.
		ParameterName = TrimAll(Left(ParameterString, FirstEqualSignPosition - 1));
		
		// Get parameter value.
		ParameterValue = TrimAll(Mid(ParameterString, FirstEqualSignPosition + 1));
		
		If  Left(ParameterValue, 1) = DoubleQuotationMarksChar
			And Right(ParameterValue, 1) = DoubleQuotationMarksChar Then
			
			ParameterValue = Mid(ParameterValue, 2, StrLen(ParameterValue) - 2);
			
		EndIf;
		
		If Not IsBlankString(ParameterName) Then
			
			Result.Insert(ParameterName, ParameterValue);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Function AddPathSeparatorToEnd(Val Path)
	
	If IsBlankString(Path) Then
		Return Path;
	EndIf;
	
	PathSeparator = GetPathSeparator();
	If Right(Path, 1) <> PathSeparator Then
		Path = Path + PathSeparator;
	EndIf;
	
	Return Path;
	
EndFunction

&AtClient
Procedure ApplySettingsGroupAppearance()
	
	TemplateOfPresentation = NStr("en = 'Save to %1';");
	Receiver = Object.SRCDirectory;
	If Not ValueIsFilled(Object.SRCDirectory) Then
		Receiver = NStr("en = '<Specify a src directory in the repository>';");
	EndIf;
	
	GroupPresentation = StringFunctionsClientServer.SubstituteParametersToString(TemplateOfPresentation, Receiver);
	
	If Items.ErrorFileDirectory.Visible Then
		TemplateOfPresentation =  TemplateOfPresentation + " " + NStr("en = 'Errors: %2';");
		ErrorsDirectory = ErrorFileDirectory;
		If Not ValueIsFilled(ErrorFileDirectory) Then
			ErrorsDirectory = NStr("en = '<Specify an errors directory>';");
		EndIf;
		GroupPresentation = StringFunctionsClientServer.SubstituteParametersToString(TemplateOfPresentation, Receiver, ErrorsDirectory);
	EndIf;
	
	Items.ImportExportSettingsGroup.CollapsedRepresentationTitle = GroupPresentation;
	
EndProcedure 

&AtClient
Procedure DirectorySelectionDialogBoxCompletion(SelectedDirectory, Var_AttributeName) Export

	If SelectedDirectory <> "" Then
		If Var_AttributeName = "ErrorFileDirectory" Then
			ThisObject[Var_AttributeName] = SelectedDirectory + ?(ValueIsFilled(SelectedDirectory),GetPathSeparator(),"");
		Else
			Object[Var_AttributeName] = SelectedDirectory + ?(ValueIsFilled(SelectedDirectory),GetPathSeparator(),"");
		EndIf;
		ApplySettingsGroupAppearance();
	EndIf; 
	
EndProcedure

&AtClient
Function FilterBackupFiles()
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Handler details (*.handlers)|*.handlers|All files (%1)|%1';"), GetAllFilesMask());
EndFunction

&AtClient
Procedure FileDialogCompletion(SelectedFile, AdditionalParameters) Export

	If SelectedFile <> Undefined Then
		BackupFileName = SelectedFile[0];
		Address = PutToTempStorage(DataToSaveToAFile());
		SavingParameters = FileSystemClient.FileSavingParameters();
		FileSystemClient.SaveFile(Undefined, Address, BackupFileName, SavingParameters);
	EndIf; 
	
EndProcedure

&AtClient
Procedure SelectFileAfterPutFiles(SelectedFile, AdditionalParameters) Export

	If SelectedFile <> Undefined Then
		DownloadDataFromAFile(SelectedFile.Location);
	EndIf; 
	
EndProcedure

&AtServer
Function DataToSaveToAFile()
	
	Data = New Structure;
	Data.Insert("UpdateHandlers", Object.UpdateHandlers.Unload());
	Data.Insert("ObjectsToRead", Object.ObjectsToRead.Unload());
	Data.Insert("ObjectsToChange", Object.ObjectsToChange.Unload());
	Data.Insert("ObjectsToLock", Object.ObjectsToLock.Unload());
	Data.Insert("ExecutionPriorities", Object.ExecutionPriorities.Unload());
	Data.Insert("HandlersConflicts", Object.HandlersConflicts.Unload());
		
	Return ValueToStringInternal(Data);
	
EndFunction

&AtServer
Procedure DownloadDataFromAFile(Address)
	
	FileBinaryData = GetFromTempStorage(Address); // BinaryData
	TempFile = GetTempFileName(".tmp");
	FileBinaryData.Write(TempFile);
	Text = New TextDocument;
	Text.Read(TempFile);
	String = Text.GetText();
	Data = ValueFromStringInternal(String);
	FileSystem.DeleteTempFile(TempFile);
	
	Object.UpdateHandlers.Load(Data.UpdateHandlers);
	Object.ObjectsToRead.Load(Data.ObjectsToRead);
	Object.ObjectsToChange.Load(Data.ObjectsToChange);
	Object.ObjectsToLock.Load(Data.ObjectsToLock);
	Object.ExecutionPriorities.Load(Data.ExecutionPriorities);
	Object.HandlersConflicts.Load(Data.HandlersConflicts);
	
	DataProcessor = DataProcessorObject2();
	UpdateFormData(DataProcessor);
	
	CurrentLibrary = "";
	Modified = False;
	
EndProcedure

&AtServer
Procedure OnChangeSearchObjectAtServer(TabularSectionName, FilterText1)
	
	If ValueIsFilled(FilterText1) Then
		Filter = FillFilterFieldByObjectAtServer(TabularSectionName, FilterText1);
		SetHandlersFilter(Filter);
	Else
		DisableHandlersFilter("Filter" + TabularSectionName);
	EndIf;
	
EndProcedure

&AtServer
Procedure NewHandlersFIlters()
	
	If Items.UpdateHandlers.RowFilter <> Undefined Then
		If Items.UpdateHandlers.RowFilter.Property("FilterObjectsToRead") <> Undefined Then
			OnChangeSearchObjectAtServer("ObjectsToRead", ObjectToRead);
		EndIf;
		If Items.UpdateHandlers.RowFilter.Property("FilterObjectsToChange") <> Undefined Then
			OnChangeSearchObjectAtServer("ObjectsToChange", ObjectToChange);
		EndIf;
	EndIf;

EndProcedure

&AtServer
Procedure UpdateFormData(DataProcessor)
	
	FillQuickFilters();
	NewHandlersFIlters();
	If DataProcessor.SubsystemsModules <> Undefined Then
		SubsystemsModules = New FixedStructure(DataProcessor.SubsystemsModules);
		UpdateLibrariesList(DataProcessor);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateLibrariesList(DataProcessor)
	
	SubsystemsList = Items.CurrentLibrary.ChoiceList;
	SubsystemsList.Clear();
	For Each Library In DataProcessor.SubsystemsModules Do
		SubsystemsList.Add(Library.Key);
	EndDo;
	SubsystemsList.SortByValue(SortDirection.Desc);
	SubsystemsList.Insert(0,"");
	
EndProcedure

&AtServer
Procedure SetHandlersFilter(Filter)
	
	If ValueIsFilled(Items.UpdateHandlers.RowFilter) Then
		CurrentFilter = New Structure(Items.UpdateHandlers.RowFilter);
		For Each NewFilter In Filter Do
			CurrentFilter.Insert(NewFilter.Key, NewFilter.Value);
		EndDo;
		Items.UpdateHandlers.RowFilter = New FixedStructure(CurrentFilter);
	Else
		Items.UpdateHandlers.RowFilter = New FixedStructure(Filter);
	EndIf;
	
EndProcedure

&AtServer
Procedure DisableHandlersFilter(FieldName)
	
	If Items.UpdateHandlers.RowFilter = Undefined Then
		Return;
	EndIf;
	
	If Not Items.UpdateHandlers.RowFilter.Property(FieldName) Then
		Return;
	EndIf;
	
	If StrFind(FieldName, "Filter") > 0 Then
		Filter = New Structure(FieldName, Items.UpdateHandlers.RowFilter[FieldName]);
		FoundRows = Object.UpdateHandlers.FindRows(Filter);
		For Each String In FoundRows Do
			String[FieldName] = "";
		EndDo;
	EndIf;
	
	If ValueIsFilled(Items.UpdateHandlers.RowFilter)
		And Items.UpdateHandlers.RowFilter.Property(FieldName) Then
		
		CurrentFilter = New Structure(Items.UpdateHandlers.RowFilter);
		CurrentFilter.Delete(FieldName);
		If ValueIsFilled(CurrentFilter) Then
			Items.UpdateHandlers.RowFilter = New FixedStructure(CurrentFilter);
		Else
			Items.UpdateHandlers.RowFilter = Undefined;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetQuickFilter(QuickFilterName)
	
	If TypeOf(QuickFilterName) = Type("ValueListItem") Then
		QuickFilterName = QuickFilterName.Value;
	EndIf;
	
	If QuickFilterName = "AnalysisRequired" Then
		Filter = New Structure("IssueStatus", AnalysisRequiredStatus);
		
	ElsIf QuickFilterName = "Deferred" Then
		Filter = New Structure("ExecutionMode", NStr("en = 'Deferred';"));
		
	ElsIf QuickFilterName = "Exclusively" Then
		Filter = New Structure("ExecutionMode", NStr("en = 'Exclusive';"));
		
	ElsIf QuickFilterName = "Seamless" Then
		Filter = New Structure("ExecutionMode", NStr("en = 'Real-time';"));
		
	ElsIf QuickFilterName = "Sequentially" Then
		Filter = New Structure("DeferredHandlersExecutionMode", NStr("en = 'Sequentially';"));
		
	ElsIf QuickFilterName = "Parallel" Then
		Filter = New Structure("DeferredHandlersExecutionMode", NStr("en = 'Parallel';"));
		
	ElsIf QuickFilterName = "InitialFilling" Then
		Filter = New Structure("InitialFilling", True);
		
	ElsIf QuickFilterName = "ChangedCheckProcedure" Then
		Filter = New Structure("ChangedCheckProcedure", True);
		
	ElsIf QuickFilterName = "LowPriorityReading" Then
		Filter = New Structure("LowPriorityReading", True);
		
	ElsIf QuickFilterName = "IsRequired" Then
		Filter = New Structure("ExecuteInMandatoryGroup", True);
		
	ElsIf QuickFilterName = "Multithreaded" Then
		Filter = New Structure("Multithreaded", True);
		
	ElsIf QuickFilterName = "DataToReadWriter" Then
		Filter = New Structure("DataToReadWriter", True);
		
	ElsIf QuickFilterName = "WriteAgain" Then
		Filter = New Structure("WriteAgain", True);
		
	ElsIf QuickFilterName = "TechnicalDesign" Then
		Filter = New Structure("TechnicalDesign", True);
		
	Else
		DisableHandlersFilter("IssueStatus");
		DisableHandlersFilter("ChangedCheckProcedure");
		DisableHandlersFilter("LowPriorityReading");
		DisableHandlersFilter("ExecutionMode");
		DisableHandlersFilter("DeferredHandlersExecutionMode");
		DisableHandlersFilter("InitialFilling");
		DisableHandlersFilter("ExecuteInMandatoryGroup");
		DisableHandlersFilter("Multithreaded");
		DisableHandlersFilter("DataToReadWriter");
		DisableHandlersFilter("WriteAgain");
		DisableHandlersFilter("TechnicalDesign");
		Return;
	EndIf;
	
	SetHandlersFilter(Filter);
	
EndProcedure

&AtServer
Function FillFilterFieldByObjectAtServer(TabularSectionName, Text)
	
	Query = New Query(
		"SELECT DISTINCT
		|	T.Ref AS Ref
		|INTO TT
		|FROM
		|	&VT AS T
		|WHERE
		|	T.MetadataObject LIKE &SearchString ESCAPE ""~""");
	Query.TempTablesManager = New TempTablesManager;
	Query.SetParameter("vt", Object[TabularSectionName].Unload());
	Query.SetParameter("SearchString", "%" + Common.GenerateSearchQueryString(Text) + "%");
	Query.Execute();
	UniqueRefs = Query.TempTablesManager.Tables["tt"].GetData().Unload().UnloadColumn("Ref");
	
	FilterFieldName = "Filter" + TabularSectionName;
	Filter = New Structure("Ref");
	For Each Ref In UniqueRefs Do
		Filter.Ref = Ref;
		Handlers = Object.UpdateHandlers.FindRows(Filter);
		For Each Handler In Handlers Do
			Handler[FilterFieldName] = Text;
		EndDo;
	EndDo;
	
	Filter = New Structure(FilterFieldName, Text);	
	Return Filter;
	
EndFunction

&AtServer
Procedure DeleteHandlersDetails(Handlers)
	
	If TypeOf(Handlers) = Type("Array") Then
		For Each RowID In Handlers Do
			ClearRelatedHandlerData(RowID);
		EndDo;
	Else
		ClearRelatedHandlerData(Handlers);
	EndIf;
	
	CheckConflictsAtServer();
	
EndProcedure

&AtServer
Procedure ClearRelatedHandlerData(LineID)
	
	Handler = Object.UpdateHandlers.FindByID(LineID);
	HandlerRef = Handler.Ref;
	DeleteHandlerData("UpdateHandlers", HandlerRef);
	DeleteHandlerData("ObjectsToRead", HandlerRef);
	DeleteHandlerData("ObjectsToChange", HandlerRef);
	DeleteHandlerData("ObjectsToLock", HandlerRef);
	DeleteHandlerData("ExecutionPriorities", HandlerRef);
	
	Filter = New Structure("ObjectName", Handler.ObjectName);
	MoreObjectHandlers = Object.UpdateHandlers.FindRows(Filter);
	For Each MoreHandler In MoreObjectHandlers Do
		MoreHandler.Changed = True;
	EndDo;
	
EndProcedure

&AtServer
Procedure DeleteHandlerData(TSName, HandlerRef)
	
	TabularSection = Object[TSName];
	DeleteTableRows(TabularSection, New Structure("Ref", HandlerRef));
	If TSName = "ExecutionPriorities" Then
		DeleteTableRows(TabularSection, New Structure("Handler2", HandlerRef));
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteTableRows(Table, Filter)
	
	FoundRows = Table.FindRows(Filter);
	For Each TSRow In FoundRows Do
		Table.Delete(TSRow);
	EndDo;
	
EndProcedure

&AtServer
Procedure CheckConflictsAtServer()
	
	DataProcessor = DataProcessorObject2();
	UpdateHandlersConflictsInfo(DataProcessor);
	ValueToFormAttribute(DataProcessor, "Object");
	
EndProcedure

&AtServer
Function ExportTablesToMXL(Ref = Undefined, TheTablesOfDischarge = "", TSDumpDirectory = "")
	
	If IsBlankString(TheTablesOfDischarge) Then
		TheTablesOfDischarge = "ObjectsToRead,ObjectsToChange,ObjectsToLock,ExecutionPriorities,HandlersConflicts";
	EndIf;
	
	DataProcessor = DataProcessorObject2().Metadata();
	Result = New Structure;
	
	Builder = New ReportBuilder;
	For Each TS In DataProcessor.TabularSections Do
		
		If Ref <> Undefined And StrFind(TheTablesOfDischarge, TS.Name) = 0  Then
			Continue;
		EndIf;
		
		TSData = Object[TS.Name].Unload();
		If Ref <> Undefined Then
			TSData = HandlerData(TS.Name, Ref);
		EndIf;
		If TS.Name = "ExecutionPriorities" Then
			TSData.Sort("Procedure1,Procedure2");
		ElsIf TS.Name = "HandlersConflicts" Then
			TSData.Sort("MetadataObject,WriteProcedure,ReadOrWriteProcedure2");
		ElsIf TS.Name = "LowPriorityReading" Then
			TSData.Sort("MetadataObject,ReaderProcedure,WriteProcedure");
		EndIf;
		TabDoc = New SpreadsheetDocument;
		Builder.DataSource = New DataSourceDescription(TSData);
		
		
		Builder.Put(TabDoc);
		
		Area = TabDoc.Area("R1:R3");
		TabDoc.DeleteArea(Area, SpreadsheetDocumentShiftType.Vertical);
		FirstTwoColumns = "R1C1:R" + Format(TabDoc.TableHeight, "NG=0") + "C2";
		Area = TabDoc.Area(FirstTwoColumns);
		TabDoc.DeleteArea(Area, SpreadsheetDocumentShiftType.Horizontal);
		
		Area = TabDoc.Area();
		Area.ColumnWidth = 20;
		Area.TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
		
		Result.Insert(TS.Name, TabDoc);
		
		If Not IsBlankString(TSDumpDirectory) Then
			FileName = TSDumpDirectory + "\" + TS.Name + ".mxl";
			TabDoc.Write(FileName);
			Result.Insert(TS.Name, FileName);
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function HandlerData(TSName, Ref)
	
	If TSName = "UpdateHandlers" Then
		TSData = Object[TSName].Unload();
		
	ElsIf StrFind("ObjectsToRead,ObjectsToChange,ObjectsToLock,ExecutionPriorities", TSName) > 0 Then
		Filter = New Structure("Ref", Ref);
		TSData = Object[TSName].Unload(Filter);
		
	ElsIf TSName = "HandlersConflicts" Then
		Filter = New Structure("HandlerWriter", Ref);
		TSData = Object[TSName].Unload(Filter);
		Filter = New Structure("ReadOrWriteHandler2", Ref);
		TSData2 = Object[TSName].Unload(Filter);
		CommonClientServer.SupplementTable(TSData2, TSData);
		
	ElsIf TSName = "LowPriorityReading" Then
		Filter = New Structure("Reader", Ref);
		TSData = Object[TSName].Unload(Filter);
		
	EndIf;
	
	Return TSData;
	
EndFunction

&AtServer
Procedure CalculateQueueAtServer()
	
	UpdateIterations = Undefined; // InfobaseUpdateInternal.UpdateIteration();
	If UpdateIterations <> Undefined Then
		DataProcessor = DataProcessorObject2();
		DataProcessor.FillQueueNumber(UpdateIterations);
	EndIf;
	
EndProcedure

#EndRegion
