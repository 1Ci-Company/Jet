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
Var ClientCache;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	
	If ValueIsFilled(Parameters.CopyingValue) Then
		Raise NStr("en = 'Create by copying is prohibited.';");
	EndIf;
	
	If Object.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm
		And Not Common.SubsystemExists("StandardSubsystems.Print") Then
		Cancel = True;
		Common.MessageToUser(NStr("en = 'Print forms are not supported.';"));
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesPage");
		AdditionalParameters.Insert("DeferredInitialization", True);
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	
	// Checking if new data processors can be imported into the infobase.
	IsNew = Object.Ref.IsEmpty();
	InsertRight1 = AdditionalReportsAndDataProcessors.InsertRight1();
	If Not InsertRight1 Then
		If IsNew Then
			Raise(NStr("en = 'Insufficient rights to add additional reports and data processors.';"),
				ErrorCategory.AccessViolation);
		EndIf;
		Items.LoadFromFile.Visible = False;
		Items.ExportToFile.Visible = False;
	EndIf;
	
	// Restrict available publication options as specified in the infobase settings.
	Items.Publication.ChoiceList.Clear();
	AvaliablePublicationKinds = AdditionalReportsAndDataProcessorsCached.AvaliablePublicationKinds();
	For Each PublicationKind In AvaliablePublicationKinds Do
		Items.Publication.ChoiceList.Add(PublicationKind);
	EndDo;
	
	// Restricting detailed information display.
	ExtendedInformationDisplay = AdditionalReportsAndDataProcessors.DisplayExtendedInformation(Object.Ref);
	Items.AdditionalInfoPage.Visible = ExtendedInformationDisplay;
	
	// Restricting data processor import from/export to a file.
	If Not AdditionalReportsAndDataProcessors.CanImportDataProcessorFromFile(Object.Ref) Then
		Items.LoadFromFile.Visible = False;
	EndIf;
	If Not AdditionalReportsAndDataProcessors.CanExportDataProcessorToFile(Object.Ref) Then
		Items.ExportToFile.Visible = False;
	EndIf;
	
	KindAdditionalDataProcessor = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor;
	KindAdditionalReport     = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport;
	KindOfReport                   = Enums.AdditionalReportsAndDataProcessorsKinds.Report;
	
	Parameters.Property("ShowImportFromFileDialogOnOpen", ShowImportFromFileDialogOnOpen);
	
	If IsNew Then
		Object.UseForObjectForm = True;
		Object.UseForListForm  = True;
		ShowImportFromFileDialogOnOpen = True;
	EndIf;
	
	If ShowImportFromFileDialogOnOpen And Not Items.LoadFromFile.Visible Then
		Raise(NStr("en = 'Insufficient rights to import additional reports and data processors.';"),
			ErrorCategory.AccessViolation);
	EndIf;
	
	FillInCommands();
	
	PermissionsAddress = PutToTempStorage(
		FormAttributeToValue("Object").Permissions.Unload(),
		UUID);
	
	SetVisibilityAvailability();
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	
	ClientCache = New Structure;
	
	If ShowImportFromFileDialogOnOpen Then
		AttachIdleHandler("UpdateFromFile", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("Catalog.AdditionalReportsAndDataProcessors.Form.PlacementInSections") Then
		
		If TypeOf(ValueSelected) <> Type("ValueList") Then
			Return;
		EndIf;
		
		Object.Sections.Clear();
		For Each ListItem In ValueSelected Do
			NewRow = Object.Sections.Add();
			NewRow.Section = ListItem.Value;
		EndDo;
		
		Modified = True;
		SetVisibilityAvailability();
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("Catalog.AdditionalReportsAndDataProcessors.Form.QuickAccessToAdditionalReportsAndDataProcessors") Then
		
		If TypeOf(ValueSelected) <> Type("ValueList") Then
			Return;
		EndIf;
		
		ItemCommand = Object.Commands.FindByID(ClientCache.CommandRowID);
		If ItemCommand = Undefined Then
			Return;
		EndIf;
		
		FoundItems = QuickAccess.FindRows(New Structure("CommandID", ItemCommand.Id));
		For Each TableRow In FoundItems Do
			QuickAccess.Delete(TableRow);
		EndDo;
		
		For Each ListItem In ValueSelected Do
			TableRow = QuickAccess.Add();
			TableRow.CommandID = ItemCommand.Id;
			TableRow.User = ListItem.Value;
		EndDo;
		
		ItemCommand.QuickAccessPresentation = UsersQuickAccessPresentation(ValueSelected.Count());
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SelectMetadataObjects" Then
		
		ImportSelectedMetadataObjects(Parameter);
		
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		If ModulePropertyManagerClient.ProcessNotifications(ThisObject, EventName, Parameter) Then
			UpdateAdditionalAttributesItems();
			ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
		EndIf;
	EndIf
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	
	If AdditionalReportsAndDataProcessors.CanExportDataProcessorToFile(Object.Ref) Then
		
		DataProcessorDataAddress = PutToTempStorage(
			CurrentObject.DataProcessorStorage.Get(),
			UUID);
		
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", CurrentObject.Ref);
	Query.Text =
	"SELECT ALLOWED
	|	RegisterData.CommandID,
	|	RegisterData.User
	|FROM
	|	InformationRegister.DataProcessorAccessUserSettings AS RegisterData
	|WHERE
	|	RegisterData.AdditionalReportOrDataProcessor = &Ref
	|	AND RegisterData.Available = TRUE
	|	AND NOT RegisterData.User.DeletionMark
	|	AND NOT RegisterData.User.Invalid";
	QuickAccess.Load(Query.Execute().Unload());
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	If DataProcessorRegistration And AdditionalReportsAndDataProcessors.CanImportDataProcessorFromFile(Object.Ref) Then
		DataProcessorBinaryData = GetFromTempStorage(DataProcessorDataAddress);
		CurrentObject.DataProcessorStorage = New ValueStorage(DataProcessorBinaryData, New Deflation(9));
	EndIf;
	
	If Object.Kind = KindAdditionalDataProcessor Or Object.Kind = KindAdditionalReport Then
		CurrentObject.AdditionalProperties.Insert("RelevantCommands", Object.Commands.Unload());
	Else
		QuickAccess.Clear();
	EndIf;
	
	CurrentObject.AdditionalProperties.Insert("QuickAccess", QuickAccess.Unload());
	CurrentObject.AdditionalProperties.Insert("ReportOptionAssignment", ReportOptionAssignment);
	
	CurrentObject.Permissions.Load(GetFromTempStorage(PermissionsAddress));
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement

	If CurrentObject.AdditionalProperties.Property("AttachmentError") Then
		MessageText = CurrentObject.AdditionalProperties.AttachmentError;
		Common.MessageToUser(MessageText);
	EndIf;
	IsNew = False;
	If DataProcessorRegistration Then
		RefreshReusableValues();
		DataProcessorRegistration = False;
	EndIf;
	FillInCommands();
	SetVisibilityAvailability();
	
	If Object.Publication <> Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled
		And Object.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm
		And Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.DisablePrintCommands(SelectedRelatedObjects().UnloadValues(), CommandsToDisable().UnloadValues());
	EndIf;
	
	StandardSubsystemsServer.NotifyAllSessionsAboutOutdatedCache(True);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AdditionalReportOptionsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure AdditionalReportOptionsBeforeRowChange(Item, Cancel)
	Cancel = True;
	OpenOption();
EndProcedure

&AtClient
Procedure AdditionalReportOptionsBeforeDeleteRow(Item, Cancel)
	Cancel = True;
	Variant = Items.AdditionalReportOptions.CurrentData;
	If Variant = Undefined Then
		Return;
	EndIf;
	
	If Not Variant.Custom Then
		ShowMessageBox(, NStr("en = 'Predefined report option cannot be marked for deletion.';"));
		Return;
	EndIf;
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Do you want to mark %1 for deletion?';"), Variant.Description);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Variant", Variant);
	Handler = New NotifyDescription("AdditionalReportOptionsBeforeDeleteRowCompletion", ThisObject, AdditionalParameters);
	ShowQueryBox(Handler, QueryText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure UseForListFormOnChange(Item)
	If Not Object.UseForObjectForm And Not Object.UseForListForm Then
		Object.UseForObjectForm = True;
	EndIf;
EndProcedure

&AtClient
Procedure UseForObjectFormOnChange(Item)
	If Not Object.UseForObjectForm And Not Object.UseForListForm Then
		Object.UseForListForm = True;
	EndIf;
EndProcedure

&AtClient
Procedure DecorationEnablingSecurityProfilesLabelURLProcessing(Item, Ref, StandardProcessing)
	
	If Ref = "int://sp-on" Then
		
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.OpenSecurityProfileSetupDialog();
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommandsLocationClick(Item, StandardProcessing)
	StandardProcessing = False;
	If Object.Kind = KindAdditionalReport Or Object.Kind = KindAdditionalDataProcessor Then
		// Select sections.
		Sections = New ValueList;
		For Each TableRow In Object.Sections Do
			Sections.Add(TableRow.Section);
		EndDo;
		
		FormParameters = New Structure;
		FormParameters.Insert("Sections",      Sections);
		FormParameters.Insert("DataProcessorKind", Object.Kind);
		
		OpenForm("Catalog.AdditionalReportsAndDataProcessors.Form.PlacementInSections", FormParameters, ThisObject);
	Else
		// Select metadata objects
		FormParameters = PrepareMetadataObjectsSelectionFormParameters();
		StandardSubsystemsClient.ChooseMetadataObjects(FormParameters);
	EndIf;
EndProcedure

&AtClient
Procedure OptionsCommandsPermissionsPagesOnCurrentPageChange(Item, CurrentPage)
	If CommonClient.SubsystemExists("StandardSubsystems.Properties")
		And CurrentPage.Name = "AdditionalAttributesPage"
		And Not PropertiesParameters.DeferredInitializationExecuted Then
		
		PropertiesExecuteDeferredInitialization();
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersObjectCommands

&AtClient
Procedure ObjectCommandsQuickAccessPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	ChangeQuickAccess();
EndProcedure

&AtClient
Procedure ObjectCommandsQuickAccessPresentationClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ObjectCommandsScheduledJobUsageOnChange(Item)
	ChangeScheduledJob(False, True);
EndProcedure

&AtClient
Procedure ObjectCommandsScheduledJobPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	ChangeScheduledJob(True, False);
EndProcedure

&AtClient
Procedure ObjectCommandsScheduledJobPresentationClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ObjectCommandsSetQuickAccess(Command)
	ChangeQuickAccess();
EndProcedure

&AtClient
Procedure ObjectCommandsSetSchedule(Command)
	ChangeScheduledJob(True, False);
EndProcedure

&AtClient
Procedure ObjectCommandsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure ObjectCommandsBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CommandSaveAndClose(Command)
	WriteAtClient(True);
EndProcedure

&AtClient
Procedure CommandWrite(Command)
	WriteAtClient(False);
EndProcedure

&AtClient
Procedure LoadFromFile(Command)
	UpdateFromFile();
EndProcedure

&AtClient
Procedure ExportToFile(Command)
	ExportingParameters = New Structure;
	ExportingParameters.Insert("IsReport", Object.Kind = KindOfReport Or Object.Kind = KindAdditionalReport);
	ExportingParameters.Insert("FileName", Object.FileName);
	ExportingParameters.Insert("DataProcessorDataAddress", DataProcessorDataAddress);
	AdditionalReportsAndDataProcessorsClient.ExportToFile(ExportingParameters);
EndProcedure

&AtClient
Procedure AdditionalReportOptionsOpen(Command)
	Variant = Items.AdditionalReportOptions.CurrentData;
	If Variant = Undefined Then
		ShowMessageBox(, NStr("en = 'Choose a report option.';"));
		Return;
	EndIf;
	
	AdditionalReportsAndDataProcessorsClient.OpenAdditionalReportOption(Object.Ref, Variant.VariantKey);
EndProcedure

&AtClient
Procedure PlaceInSections(Command)
	OptionsArray = New Array;
	For Each RowID In Items.AdditionalReportOptions.SelectedRows Do
		Variant = AdditionalReportOptions.FindByID(RowID);
		If ValueIsFilled(Variant.Ref) Then
			OptionsArray.Add(Variant.Ref);
		EndIf;
	EndDo;
	
	// Opens a dialog for assigning multiple report options to command interface sections
	If CommonClient.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptionsClient = CommonClient.CommonModule("ReportsOptionsClient");
		ModuleReportsOptionsClient.OpenOptionArrangeInSectionsDialog(OptionsArray);
	EndIf;
EndProcedure

&AtClient
Procedure SetPrintCommandVisibility(Command)
	If Modified Then
		NotifyDescription = New NotifyDescription("SetPrintCommandVisibilityCompletion", ThisObject);
		QueryText = NStr("en = 'To configure the visibility of print commands, save the data processor. Continue?';");
		Buttons = New ValueList;
		Buttons.Add("Continue", NStr("en = 'Continue';"));
		Buttons.Add(DialogReturnCode.Cancel);
		ShowQueryBox(NotifyDescription, QueryText, Buttons);
	Else
		OpenPrintSubmenuSettingsForm();
	EndIf;
EndProcedure

&AtClient
Procedure ExecuteCommand(Command)
	CommandsTableRow = Items.ObjectCommands.CurrentData;
	If CommandsTableRow = Undefined Then
		Return;
	EndIf;
	If Not CommandsTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.OpeningForm")
		And Not CommandsTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ClientMethodCall")
		And Not CommandsTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ServerMethodCall")
		And Not CommandsTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.SafeModeScenario") Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("CommandToExecuteID", CommandsTableRow.Id);
	Handler = New NotifyDescription("ExecuteCommandAfterWriteConfirmed", ThisObject, Context);
	
	If Object.Ref.IsEmpty() Or Modified Then
		QueryText = NStr("en = 'Save the data before running the command.';");
		Buttons = New ValueList;
		Buttons.Add("WriteAndContinue", NStr("en = 'Save and continue';"));
		Buttons.Add(DialogReturnCode.Cancel);
		ShowQueryBox(Handler, QueryText, Buttons);
	Else
		ExecuteNotifyProcessing(Handler, "ContinueWithoutWriting");
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, Var_URL = Undefined, StandardProcessing = Undefined)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ObjectCommandsScheduledJobUsage.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ObjectCommandsScheduledJobPresentation.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Commands.ScheduledJobAllowed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("ReadOnly", True);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ObjectCommandsScheduledJobPresentation.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Commands.ScheduledJobUsage");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure WriteAtClient(CloseAfterWrite)
	
	Handler = New NotifyDescription("ContinueWriteAtClient", ThisObject, CloseAfterWrite);
	ExecuteNotifyProcessing(Handler, DialogReturnCode.OK);
	
EndProcedure

&AtClient
Procedure ContinueWriteAtClient(Result, CloseAfterWrite)  Export
	
	WriteParameters = New Structure;
	WriteParameters.Insert("DataProcessorRegistration", DataProcessorRegistration);
	WriteParameters.Insert("CloseAfterWrite", CloseAfterWrite);
	
	Success = Write(WriteParameters);
	If Not Success Then
		Return;
	EndIf;
	
	If WriteParameters.DataProcessorRegistration Then
		RefreshReusableValues();
		NotificationText1 = NStr("en = 'To apply the changes in open windows, close and reopen them.';");
		ShowUserNotification(, , NotificationText1);
	EndIf;
	WriteAtClientCompletion(WriteParameters);
	
EndProcedure

&AtClient
Procedure WriteAtClientCompletion(WriteParameters)
	If WriteParameters.CloseAfterWrite And IsOpen() Then
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure UpdateFromFile()
	Notification = New NotifyDescription("UpdateFromFileAfterConfirm", ThisObject);
	UsersInternalClient.ShowSecurityWarning(Notification,
		UsersInternalClientServer.SecurityWarningKinds().BeforeAddExternalReportOrDataProcessor);
EndProcedure

&AtClient
Procedure UpdateFromFileAfterConfirm(Response, RegistrationParameters) Export
	If Response <> "Continue" Then
		UpdateFromFileCompletion(Undefined, RegistrationParameters);
		Return;
	EndIf;
	
	RegistrationParameters = New Structure;
	RegistrationParameters.Insert("Success", False);
	RegistrationParameters.Insert("DataProcessorDataAddress", DataProcessorDataAddress);
	
	Handler = New NotifyDescription("UpdateFromFileAfterFileChoice", ThisObject, RegistrationParameters);
	
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.Dialog.Filter = AdditionalReportsAndDataProcessorsClientServer.SelectingAndSavingDialogFilter();
	ImportParameters.FormIdentifier = UUID;
	
	If Object.Ref.IsEmpty() Then
		ImportParameters.Dialog.FilterIndex = 0;
		ImportParameters.Dialog.Title = NStr("en = 'Select a file with external report or data processor';");
	ElsIf Object.Kind = KindAdditionalReport Or Object.Kind = KindOfReport Then
		ImportParameters.Dialog.FilterIndex = 1;
		ImportParameters.Dialog.Title = NStr("en = 'Select an file with external report';");
	Else
		ImportParameters.Dialog.FilterIndex = 2;
		ImportParameters.Dialog.Title = NStr("en = 'Select a file with external data processor';");
	EndIf;
	
	FileSystemClient.ImportFile_(Handler, ImportParameters, Object.FileName);
	
EndProcedure

&AtClient
Procedure UpdateFromFileAfterFileChoice(FileDetails, RegistrationParameters) Export
	If FileDetails = Undefined Then
		UpdateFromFileCompletion(Undefined, RegistrationParameters);
		Return;
	EndIf;
	
	Keys = New Structure("FileName, IsReport, DisablePublication, DisableConflicts, Conflicting");
	CommonClientServer.SupplementStructure(RegistrationParameters, Keys, False);
	
	RegistrationParameters.DisablePublication = False;
	RegistrationParameters.DisableConflicts = False;
	RegistrationParameters.Conflicting = New ValueList;
	
	SubstringsArray = StrSplit(FileDetails.Name, GetPathSeparator(), False);
	RegistrationParameters.FileName = SubstringsArray.Get(SubstringsArray.UBound());
	FileExtention = Upper(Right(RegistrationParameters.FileName, 3));
	
	If FileExtention = "ERF" Then
		RegistrationParameters.IsReport = True;
	ElsIf FileExtention = "EPF" Then
		RegistrationParameters.IsReport = False;
	Else
		RegistrationParameters.Success = False;
		ResultHandler = New NotifyDescription("UpdateFromFileCompletion", ThisObject, RegistrationParameters);
		WarningText = NStr("en = 'The file extension does not match external report extension (ERF) or external data processor extension (EPF).';");
		ReturnParameters1 = New Structure;
		ReturnParameters1.Insert("Handler", ResultHandler);
		ReturnParameters1.Insert("Result",  Undefined);
		SimpleDialogHandler = New NotifyDescription("ReturnResultAfterCloseSimpleDialog", ThisObject, ReturnParameters1);
		ShowMessageBox(SimpleDialogHandler, WarningText);
		Return;
	EndIf;
	
	RegistrationParameters.DataProcessorDataAddress = FileDetails.Location;
	
	UpdateFromFileAndMessage(RegistrationParameters);
EndProcedure

&AtClient
Procedure ReturnResultAfterCloseSimpleDialog(HandlerParameters) Export
	If TypeOf(HandlerParameters.Handler) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(HandlerParameters.Handler, HandlerParameters.Result);
	EndIf;
EndProcedure

&AtClient
Procedure UpdateFromFileAndMessage(RegistrationParameters)

	UpdateFromFileAtServer(RegistrationParameters);
	
	If RegistrationParameters.DisableConflicts Then
		// Multiple objects are disabled, which requires dynamic list refresh.
		NotifyChanged(Type("CatalogRef.AdditionalReportsAndDataProcessors"));
	EndIf;
	
	If RegistrationParameters.Success Then
		NotificationTitle1 = ?(RegistrationParameters.IsReport, NStr("en = 'External report file is imported';"), NStr("en = 'External data processor file is imported';"));
		NotificationRef    = ?(IsNew, "", GetURL(Object.Ref));
		NotificationText     = RegistrationParameters.FileName;
		ShowUserNotification(NotificationTitle1, NotificationRef, NotificationText);
		UpdateFromFileCompletion(Undefined, RegistrationParameters);
	ElsIf RegistrationParameters.ObjectNameUsed Then // Checking the reason of canceling data processor import and displaying the reason to the user.
		ShowConflicts(RegistrationParameters);
	Else
		ResultHandler = New NotifyDescription("UpdateFromFileCompletion", ThisObject, RegistrationParameters);
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.PromptDontAskAgain = False;
		StandardSubsystemsClient.ShowQuestionToUser(ResultHandler, RegistrationParameters.ErrorText, 
			QuestionDialogMode.OK, QuestionParameters);
	EndIf;
EndProcedure

&AtClient
Procedure ShowConflicts(RegistrationParameters)
	
	If RegistrationParameters.ConflictsCount > 1 Then
		If RegistrationParameters.IsReport Then
			QuestionTitle = NStr("en = 'External report import conflict';");
			QueryText = NStr("en = 'Internal report name ""[Name]"" 
			|is already used by the following additional reports ([Count]):
			|[List].
			|
			|Select one of the following:
			|1. ""[Continue]"". Import the new report in debug mode.
			|2. ""[Disable]"". Disable all conflicting reports and import the new report.
			|3. ""[Open]"". Cancel the import and show the list of conflicting reports.';");
		Else
			QuestionTitle = NStr("en = 'Conflicts occurred during import of external data processor';");
			QueryText = NStr("en = 'Internal name of data processor ""[Name]"" 
			|is already used by the following additional data processors ([Count]):
			|[List].
			|
			|Select one of the following:
			|1. ""[Continue]"". Import the new data processor in the debug mode.
			|2. ""[Disable]"". Disable all conflicting data processors and import the new data processor.
			|3. ""[Open]"". Cancel the import and show the list of conflicting data processors.';");
		EndIf;
		DisableButtonPresentation = NStr("en = 'Disable conflicting objects';");
		OpenButtonPresentation = NStr("en = 'Cancel and show list';");
	Else
		If RegistrationParameters.IsReport Then
			QuestionTitle = NStr("en = 'External report import conflict';");
			QueryText = NStr("en = 'Internal report name ""[Name]"" 
			|is already used by additional report [List].
			|
			|Select one of the following:
			|1. ""[Continue]"". Import the new report in debug mode.
			|2. ""[Disable]"". Disable the conflicting report and import the new report.
			|3. ""[Open]"". Open the conflicting report''s card.';");
			DisableButtonPresentation = NStr("en = 'Disable another report';");
		Else
			QuestionTitle = NStr("en = 'External data processor import conflict';");
			QueryText = NStr("en = 'Internal name of data processor ""[Name]"" 
			|is already used by additional data processor [List].
			|
			|Select one of the following:
			|1. ""[Continue]"". Import the new data processor in debug mode.
			|2. ""[Disable]"". Disable the conflicting data processor and import the new data processor.
			|3. ""[Open]"". Open the conflicting data processor''s card.';");
			DisableButtonPresentation = NStr("en = 'Disable another data processor';");
		EndIf;
		OpenButtonPresentation = NStr("en = 'Cancel and open';");
	EndIf;
	ContinueButtonPresentation = NStr("en = 'Debug mode';");
	QueryText = StrReplace(QueryText, "[Name]",  RegistrationParameters.ObjectName);
	QueryText = StrReplace(QueryText, "[Count]", RegistrationParameters.ConflictsCount);
	QueryText = StrReplace(QueryText, "[List]",  RegistrationParameters.LockersPresentation);
	QueryText = StrReplace(QueryText, "[Disable]",  DisableButtonPresentation);
	QueryText = StrReplace(QueryText, "[Open]",     OpenButtonPresentation);
	QueryText = StrReplace(QueryText, "[Continue]", ContinueButtonPresentation);
	
	QuestionButtons = New ValueList;
	QuestionButtons.Add("ContinueWithoutPublishing", ContinueButtonPresentation);
	QuestionButtons.Add("DisableConflictingItems",  DisableButtonPresentation);
	QuestionButtons.Add("CancelAndOpen",        OpenButtonPresentation);
	QuestionButtons.Add(DialogReturnCode.Cancel);
	
	Handler = New NotifyDescription("UpdateFromFileConflictDecision", ThisObject, RegistrationParameters);
	ShowQueryBox(Handler, QueryText, QuestionButtons, , "ContinueWithoutPublishing", QuestionTitle);
EndProcedure

&AtClient
Procedure UpdateFromFileConflictDecision(Response, RegistrationParameters) Export
	If Response = "ContinueWithoutPublishing" Then
		// Recall server (Debug mode option) and process the result.
		RegistrationParameters.DisablePublication = True;
		UpdateFromFileAndMessage(RegistrationParameters);
	ElsIf Response = "DisableConflictingItems" Then
		// Repeating server call (switching conflicting items to debug mode) and processing the result.
		RegistrationParameters.DisableConflicts = True;
		UpdateFromFileAndMessage(RegistrationParameters);
	ElsIf Response = "CancelAndOpen" Then
		// Cancel and show the conflicts.
		// The list is displayed if there is more than one conflicting item.
		ShowList = (RegistrationParameters.ConflictsCount > 1);
		If RegistrationParameters.OldObjectName = RegistrationParameters.ObjectName And Not IsNew Then
			// Or the current item has a name collision.
			// The list contains the current item and the conflicting item.
			// This allows you to review and decide which one should be disabled.
			ShowList = True;
		EndIf;
		If ShowList Then // List form with a filter by conflicting items.
			Var_FormName = "Catalog.AdditionalReportsAndDataProcessors.ListForm";
			FormTitle = NStr("en = 'Additional reports and data processors with name ""%1""';");
			FormTitle = StringFunctionsClientServer.SubstituteParametersToString(FormTitle, RegistrationParameters.ObjectName);
			ParametersForm = New Structure;
			ParametersForm.Insert("Filter", New Structure);
			ParametersForm.Filter.Insert("ObjectName", RegistrationParameters.ObjectName);
			ParametersForm.Filter.Insert("IsFolder", False);
			ParametersForm.Insert("Title", FormTitle);
			ParametersForm.Insert("Representation", "List");
		Else // Item form.
			Var_FormName = "Catalog.AdditionalReportsAndDataProcessors.ObjectForm";
			ParametersForm = New Structure;
			ParametersForm.Insert("Key", RegistrationParameters.Conflicting[0].Value);
		EndIf;
		UpdateFromFileCompletion(Undefined, RegistrationParameters);
		OpenForm(Var_FormName, ParametersForm, Undefined, True);
	Else // Cancel.
		UpdateFromFileCompletion(Undefined, RegistrationParameters);
	EndIf;
EndProcedure

&AtClient
Procedure UpdateFromFileCompletion(EmptyResult, RegistrationParameters) Export
	If RegistrationParameters = Undefined Or RegistrationParameters.Success = False Then
		If ShowImportFromFileDialogOnOpen And IsOpen() Then
			Close();
		EndIf;
	ElsIf RegistrationParameters.Success = True Then
		If Not IsOpen() Then
			Open();
		EndIf;
		Modified = True;
		DataProcessorRegistration = True;
		DataProcessorDataAddress = RegistrationParameters.DataProcessorDataAddress;
	EndIf;
EndProcedure

&AtClient
Procedure OpenOption()
	Variant = Items.AdditionalReportOptions.CurrentData;
	If Variant = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Variant.Ref) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '""%1"" report option is not registered.';"), Variant.Description);
		ShowMessageBox(, ErrorText);
	Else
		ModuleReportsOptionsClient = CommonClient.CommonModule("ReportsOptionsClient");
		ModuleReportsOptionsClient.ShowReportSettings(Variant.Ref);
	EndIf;
EndProcedure

&AtClient
Procedure ChangeScheduledJob(Var_ChoiceMode = False, CheckBoxChanged = False)
	
	ItemCommand = Items.ObjectCommands.CurrentData;
	If ItemCommand = Undefined Then
		Return;
	EndIf;
	
	If ItemCommand.StartupOption <> PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ServerMethodCall")
		And ItemCommand.StartupOption <> PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.SafeModeScenario") Then
		ErrorText = NStr("en = 'Scheduled jobs do not support commands
		|with the ""%1"" startup option.';");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, String(ItemCommand.StartupOption));
		ShowMessageBox(, ErrorText);
		If CheckBoxChanged Then
			ItemCommand.ScheduledJobUsage = Not ItemCommand.ScheduledJobUsage;
		EndIf;
		Return;
	EndIf;
	
	If CheckBoxChanged And Not ItemCommand.ScheduledJobUsage Then
		Return;
	EndIf;
	
	If ItemCommand.ScheduledJobSchedule.Count() > 0 Then
		CommandSchedule = ItemCommand.ScheduledJobSchedule.Get(0).Value;
	Else
		CommandSchedule = Undefined;
	EndIf;
	
	If TypeOf(CommandSchedule) <> Type("JobSchedule") Then
		CommandSchedule = New JobSchedule;
	EndIf;
	
	Context = New Structure;
	Context.Insert("ItemCommand", ItemCommand);
	Context.Insert("DisableFlagOnCancelEdit", CheckBoxChanged);
	Handler = New NotifyDescription("AfterScheduleEditComplete", ThisObject, Context);
	
	EditSchedule1 = New ScheduledJobDialog(CommandSchedule);
	EditSchedule1.Show(Handler);
	
EndProcedure

&AtClient
Procedure AfterScheduleEditComplete(Schedule, Context) Export
	ItemCommand = Context.ItemCommand;
	If Schedule = Undefined Then
		If Context.DisableFlagOnCancelEdit Then
			ItemCommand.ScheduledJobUsage = False;
		EndIf;
	Else
		
		If DataSeparationEnabled
			And Schedule.RepeatPeriodInDay <> 0
			And Schedule.RepeatPeriodInDay < 60 Then
			MessageText = NStr("en = 'Setting the retry interval of the scheduled job less than 60 seconds is not allowed.';");
			ShowMessageBox(, MessageText);
			Return;
		EndIf;
		
		ItemCommand.ScheduledJobSchedule.Clear();
		ItemCommand.ScheduledJobSchedule.Add(Schedule);
		If AdditionalReportsAndDataProcessorsClientServer.ScheduleSpecified(Schedule) Then
			Modified = True;
			ItemCommand.ScheduledJobUsage = True;
			ItemCommand.ScheduledJobPresentation = String(Schedule);
		Else
			ItemCommand.ScheduledJobPresentation = NStr("en = 'Not filled';");
			If ItemCommand.ScheduledJobUsage Then
				ItemCommand.ScheduledJobUsage = False;
				ShowUserNotification(
					NStr("en = 'Scheduling is disabled';"),
					,
					NStr("en = 'Schedule is not filled';"));
			EndIf;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure ChangeQuickAccess()
	ItemCommand = Items.ObjectCommands.CurrentData;
	If ItemCommand = Undefined Then
		Return;
	EndIf;
	
	FoundItems = QuickAccess.FindRows(New Structure("CommandID", ItemCommand.Id));
	UsersWithQuickAccess = New ValueList;
	For Each TableRow In FoundItems Do
		UsersWithQuickAccess.Add(TableRow.User);
	EndDo;
	
	FormParameters = New Structure;
	FormParameters.Insert("UsersWithQuickAccess", UsersWithQuickAccess);
	FormParameters.Insert("CommandPresentation",         ItemCommand.Presentation);
	
	ClientCache.Insert("CommandRowID", ItemCommand.GetID());
	OpenForm("Catalog.AdditionalReportsAndDataProcessors.Form.QuickAccessToAdditionalReportsAndDataProcessors", FormParameters, ThisObject);
	
EndProcedure

// Parameters:
//   Response - DialogReturnCode
//   AdditionalParameters - Structure
//
&AtClient
Procedure AdditionalReportOptionsBeforeDeleteRowCompletion(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		Variant = AdditionalParameters.Variant;
		DeleteAdditionalReportOption("ExternalReport." + Object.ObjectName, Variant.VariantKey);
		AdditionalReportOptions.Delete(Variant);
	EndIf;
EndProcedure

&AtClient
Procedure ExecuteCommandAfterWriteConfirmed(Response, Context) Export
	If Response = "WriteAndContinue" Then
		ClearMessages();
		If Not Write() Then
			Return; // Failed to write, the platform shows an error message.
		EndIf;
	ElsIf Response <> "ContinueWithoutWriting" Then
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Or Modified Then
		Return; // Final check.
	EndIf;
	
	CommandsTableRow = Items.ObjectCommands.CurrentData;
	If CommandsTableRow = Undefined
		Or CommandsTableRow.Id <> Context.CommandToExecuteID Then
		FoundItems = Object.Commands.FindRows(New Structure("Id", Context.CommandToExecuteID));
		If FoundItems.Count() = 0 Then
			Return;
		EndIf;
		CommandsTableRow = FoundItems[0];
	EndIf;
	
	CommandToExecute = New Structure(
		"Ref, Presentation,
		|Id, StartupOption, ShouldShowUserNotification, 
		|Modifier, RelatedObjects, IsReport, Kind");
	FillPropertyValues(CommandToExecute, CommandsTableRow);
	CommandToExecute.Ref = Object.Ref;
	CommandToExecute.Kind = Object.Kind;
	CommandToExecute.IsReport = (Object.Kind = KindAdditionalReport Or Object.Kind = KindOfReport);
	
	If CommandsTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.OpeningForm") Then
		
		AdditionalReportsAndDataProcessorsClient.OpenDataProcessorForm(CommandToExecute, ThisObject, CommandToExecute.RelatedObjects);
		
	ElsIf CommandsTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ClientMethodCall") Then
		
		AdditionalReportsAndDataProcessorsClient.ExecuteDataProcessorClientMethod(CommandToExecute, ThisObject, CommandToExecute.RelatedObjects);
		
	ElsIf CommandsTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ServerMethodCall")
		Or CommandsTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.SafeModeScenario") Then
		
		StateHeader = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Executing command ""%1""';"),
			CommandsTableRow.Presentation);
		ShowUserNotification(StateHeader + "...", , , PictureLib.TimeConsumingOperation48);
		
		TimeConsumingOperation = StartExecuteServerCommandInBackground(CommandToExecute, UUID);
		
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.MessageText = StateHeader;
		IdleParameters.UserNotification.Show = True;
		IdleParameters.OutputIdleWindow = True;
		
		CallbackOnCompletion = New NotifyDescription("AfterCompleteExecutingServerCommandInBackground", ThisObject, CommandToExecute);
		TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CallbackOnCompletion, IdleParameters);
		
	EndIf;
	
EndProcedure

// Parameters:
//  Job - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure AfterCompleteExecutingServerCommandInBackground(Job, AdditionalParameters) Export
	
	If Job = Undefined Then
		Return;
	EndIf;
	
	If Job.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Job.ErrorInfo);
		Return;
	EndIf;
	
	Result = GetFromTempStorage(Job.ResultAddress);
	NotifyForms = CommonClientServer.StructureProperty(Result, "NotifyForms");
	If NotifyForms <> Undefined Then
		StandardSubsystemsClient.NotifyFormsAboutChange(NotifyForms);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client, Server

&AtClientAtServerNoContext
Function UsersQuickAccessPresentation(UsersCount)
	
	If UsersCount = 0 Then
		Return NStr("en = 'None';");
	EndIf;
	
	QuickAccessPresentation = StringFunctionsClientServer.StringWithNumberForAnyLanguage(
		NStr("en = ';%1 user;;;;%1 users';"), UsersCount);
	
	Return QuickAccessPresentation;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server call, Server.

&AtServerNoContext
Function StartExecuteServerCommandInBackground(CommandToExecute, UUID)
	ProcedureName = "AdditionalReportsAndDataProcessors.ExecuteCommand";
	
	ProcedureParameters = New Structure("AdditionalDataProcessorRef, CommandID, RelatedObjects");
	ProcedureParameters.AdditionalDataProcessorRef = CommandToExecute.Ref;
	ProcedureParameters.CommandID          = CommandToExecute.Id;
	ProcedureParameters.RelatedObjects             = CommandToExecute.RelatedObjects;
	
	StartSettings1 = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings1.BackgroundJobDescription =
		NStr("en = 'Additional reports and data processors: executing data processor server method.';");
	StartSettings1.RefinementErrors =
		NStr("en = 'Cannot execute the command. Reason:';");
	
	Return TimeConsumingOperations.ExecuteInBackground(ProcedureName, ProcedureParameters, StartSettings1);
EndFunction

&AtServer
Procedure UpdateFromFileAtServer(RegistrationParameters)
	ObjectOfCatalog = FormAttributeToValue("Object");
	SavedCommands = ObjectOfCatalog.Commands.Unload();
	RegistrationResult = AdditionalReportsAndDataProcessors.RegisterDataProcessor(ObjectOfCatalog, RegistrationParameters);
	PermissionsAddress = PutToTempStorage(ObjectOfCatalog.Permissions.Unload(), UUID);
	ValueToFormAttribute(ObjectOfCatalog, "Object");
	
	CommonClientServer.SupplementStructure(RegistrationParameters, RegistrationResult, True);
	
	If RegistrationParameters.Success Then
		FillInCommands(SavedCommands);
		ReportOptionAssignment = RegistrationParameters.ReportOptionAssignment;
	ElsIf RegistrationParameters.ObjectNameUsed Then
		LockersPresentation = "";
		For Each ListItem In RegistrationParameters.Conflicting Do
			If StrLen(LockersPresentation) > 80 Then
				LockersPresentation = LockersPresentation + "... ";
				Break;
			EndIf;
			LockersPresentation = LockersPresentation
				+ ?(LockersPresentation = "", "", ", ")
				+ """" + TrimAll(ListItem.Presentation) + """";
		EndDo;
		RegistrationParameters.Insert("LockersPresentation", LockersPresentation);
		RegistrationParameters.Insert("ConflictsCount", RegistrationParameters.Conflicting.Count());
	EndIf;
	
	SetVisibilityAvailability(RegistrationParameters.Success);
EndProcedure

&AtServer
Function PrepareMetadataObjectsSelectionFormParameters()
	MetadataObjectsTable = AdditionalReportsAndDataProcessors.AttachedMetadataObjects(Object.Kind);
	If MetadataObjectsTable = Undefined Then
		Return Undefined;
	EndIf;
	
	FilterByMetadataObjects = New ValueList;
	FilterByMetadataObjects.LoadValues(MetadataObjectsTable.UnloadColumn("FullName"));
	
	SelectedMetadataObjects = New ValueList;
	RelatedObjects = New Array;
	For Each AssignmentItem In Object.Purpose Do
		If MetadataObjectsTable.Find(AssignmentItem.RelatedObject, "Ref") <> Undefined Then
			RelatedObjects.Add(AssignmentItem.RelatedObject);
		EndIf;
	EndDo;
	
	AssignmentObjectsFullNames = Common.ObjectsAttributeValue(RelatedObjects, "FullName");
	For Each KeyAndValue In AssignmentObjectsFullNames Do
		SelectedMetadataObjects.Add(KeyAndValue.Value);
	EndDo;
	
	FormParameters = StandardSubsystemsClientServer.MetadataObjectsSelectionParameters();
	FormParameters.FilterByMetadataObjects = FilterByMetadataObjects;
	FormParameters.SelectedMetadataObjects = SelectedMetadataObjects;
	FormParameters.Title = NStr("en = 'Additional data processor assignment';");
	
	Return FormParameters;
EndFunction

&AtServer
Procedure ImportSelectedMetadataObjects(Parameter)
	Object.Purpose.Clear();
	
	For Each ParameterItem In Parameter Do
		MetadataObject = Common.MetadataObjectByFullName(ParameterItem.Value);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		AssignmentRow = Object.Purpose.Add();
		AssignmentRow.RelatedObject = Common.MetadataObjectID(MetadataObject);
	EndDo;
	
	Modified = True;
	SetVisibilityAvailability();
EndProcedure

&AtServerNoContext
Procedure DeleteAdditionalReportOption(ObjectKey, VariantKey)
	SettingsStorages["ReportsVariantsStorage"].Delete(ObjectKey, VariantKey, Undefined);
EndProcedure

&AtServer
Procedure SetVisibilityAvailability(Registration = False)
	
	IsGlobalDataProcessor = (Object.Kind = KindAdditionalDataProcessor Or Object.Kind = KindAdditionalReport);
	IsReport = (Object.Kind = KindAdditionalReport Or Object.Kind = KindOfReport);
	
	If Not Registration And Not IsNew And IsReport Then
		AdditionalReportOptionsFill();
	Else
		AdditionalReportOptions.Clear();
	EndIf;
	
	OptionsCount = AdditionalReportOptions.Count();
	CommandsCount = Object.Commands.Count();
	VisibleTabsCount = 1;
	
	If Object.Kind = KindAdditionalReport And Object.UseOptionStorage Then
		VisibleTabsCount = VisibleTabsCount + 1;
		
		Items.OptionsPages.Visible = True;
		
		If Registration Or OptionsCount = 0 Then
			Items.OptionsPages.CurrentPage = Items.OptionsHideBeforeWrite;
			Items.OptionsPage.Title = NStr("en = 'Report options';");
		Else
			Items.OptionsPages.CurrentPage = Items.OptionsShow;
			Items.OptionsPage.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Report options (%1)';"),
				Format(OptionsCount, "NG="));
		EndIf;
	Else
		Items.OptionsPages.Visible = False;
	EndIf;
	
	Items.CommandPage.Visible = CommandsCount > 0;
	If CommandsCount = 0 Then
		Items.CommandPage.Title = CommandsPageName();
	Else
		VisibleTabsCount = VisibleTabsCount + 1;
		Items.CommandPage.Title = CommandsPageName() + " (" + Format(CommandsCount, "NG=") + ")";
	EndIf;
	
	Items.ExecuteCommand.Visible = False;
	If IsGlobalDataProcessor And CommandsCount > 0 Then
		For Each CommandsTableRow In Object.Commands Do
			If CommandsTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.OpeningForm")
				Or CommandsTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ClientMethodCall")
				Or CommandsTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ServerMethodCall")
				Or CommandsTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.SafeModeScenario") Then
				Items.ExecuteCommand.Visible = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	PermissionsCount = SecurityProfilePermissions().Count();
	PermissionsCompatibilityMode = Object.PermissionsCompatibilityMode;
	
	SafeMode = Object.SafeMode;
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
		UseSecurityProfiles = ModuleSafeModeManager.UseSecurityProfiles();
	Else
		UseSecurityProfiles = False;
	EndIf;
	
	If GetFunctionalOption("SaaSOperations") Or UseSecurityProfiles Then
		ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
		If PermissionsCompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_1_3 Then
			If SafeMode And PermissionsCount > 0 And UseSecurityProfiles Then
				If IsNew Then
					SafeMode = "";
				Else
					SafeMode = ModuleSafeModeManagerInternal.ExternalModuleAttachmentMode(Object.Ref);
				EndIf;
			EndIf;
		Else
			If PermissionsCount = 0 Then
				SafeMode = True;
			Else
				If UseSecurityProfiles Then
					If IsNew Then
						SafeMode = "";
					Else
						SafeMode = ModuleSafeModeManagerInternal.ExternalModuleAttachmentMode(Object.Ref);
					EndIf;
				Else
					SafeMode = False;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	If PermissionsCount = 0 Then
		
		Items.PermissionsPage.Visible = False;
		Items.SafeModeGlobalGroup.Visible = True;
		Items.SafeModeFalseLabelDecoration.Visible = (SafeMode = False);
		Items.SafeModeTrueLabelDecoration.Visible = (SafeMode = True);
		Items.EnablingSecurityProfilesGroup.Visible = False;
		
	Else
		
		VisibleTabsCount = VisibleTabsCount + 1;
		
		Items.PermissionsPage.Visible = True;
		Items.PermissionsPage.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Permissions (%1)';"),
			Format(PermissionsCount, "NG="));
		
		Items.SafeModeGlobalGroup.Visible = False;
		
		Items.PermissionCompatibilityModesPagesGroup.CurrentPage = Items.PermissionsPageVersion_2_2_2;
		
		If UseSecurityProfiles And SafeMode = True Then
			Items.SafeModeWithPermissionsPages.CurrentPage = Items.SafeModeWithPermissionsPage;
		ElsIf TypeOf(SafeMode) = Type("Boolean") Then
			Items.SafeModeWithPermissionsPages.CurrentPage = Items.UnsafeModeWithPermissionsPage;
		ElsIf TypeOf(SafeMode) = Type("String") Then
			Items.SafeModeWithPermissionsPages.CurrentPage = Items.PersonalSecurityProfilePage;
			Items.DecorationPersonalSecurityProfileLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The report or data processor will be attached to the application with a custom security profile
					|%1, which allows the following actions:';"),
				SafeMode);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 is not a valid mode to attach additional reports and data processors
					|that require permissions to use security profiles.';"),
				SafeMode);
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
			ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
			CanSetUpSecurityProfiles = ModuleSafeModeManagerInternal.CanSetUpSecurityProfiles();
		Else
			CanSetUpSecurityProfiles = False;
		EndIf;
		
		If SafeMode = False And Not UseSecurityProfiles And CanSetUpSecurityProfiles Then
			Items.EnablingSecurityProfilesGroup.Visible = True;
		Else
			Items.EnablingSecurityProfilesGroup.Visible = False;
		EndIf;
		
		GeneratePermissionsList();
		
	EndIf;
	
	Items.OptionsCommandsPermissionsPages.PagesRepresentation = FormPagesRepresentation[?(VisibleTabsCount > 1, "TabsOnTop", "None")];
	
	PurposePresentation = "";
	If IsGlobalDataProcessor Then
		For Each RowSection In Object.Sections Do
			SectionPresentation = AdditionalReportsAndDataProcessors.SectionPresentation(RowSection.Section);
			If SectionPresentation = Undefined Then
				Continue;
			EndIf;
			PurposePresentation = ?(IsBlankString(PurposePresentation), SectionPresentation,
				PurposePresentation + ", " + SectionPresentation);
		EndDo;
	Else
		For Each AssignmentRow In Object.Purpose Do
			ObjectPresentation = AdditionalReportsAndDataProcessors.MetadataObjectPresentation(AssignmentRow.RelatedObject);
			PurposePresentation = ?(IsBlankString(PurposePresentation), ObjectPresentation,
				PurposePresentation + ", " + ObjectPresentation);
		EndDo;
	EndIf;
	If PurposePresentation = "" Then
		PurposePresentation = NStr("en = 'Undefined';");
	EndIf;
	
	Items.ObjectCommandsQuickAccessPresentation.Visible       = IsGlobalDataProcessor;
	Items.ObjectCommandsSetQuickAccess.Visible           = IsGlobalDataProcessor;
	Items.ObjectCommandsScheduledJobPresentation.Visible = IsGlobalDataProcessor;
	Items.ObjectCommandsScheduledJobUsage.Visible = IsGlobalDataProcessor;
	Items.ObjectCommandsSetSchedule.Visible              = IsGlobalDataProcessor;
	
	IsPrintForm = Object.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm;
	Items.FormsTypes.Visible = Not IsGlobalDataProcessor And Not IsPrintForm;
	If Not Items.FormsTypes.Visible Then
		Object.UseForObjectForm = True;
		Object.UseForListForm = True;
	EndIf;
	Items.SetPrintCommandVisibility.Visible = IsPrintForm;
	Items.ObjectCommandsComment.Visible = IsPrintForm;
	
	If IsNew Then
		Title = ?(IsReport, NStr("en = 'Additional report (Create)';"), NStr("en = 'Additional data processor (Create)';"));
	Else
		Title = Object.Description + " " + ?(IsReport, NStr("en = '(Additional report)';"), NStr("en = '(Additional data processor)';"));
	EndIf;
	
	If OptionsCount > 0 Then
		
		OutputTableTitle = VisibleTabsCount <= 1 And Object.Kind = KindAdditionalReport And Object.UseOptionStorage;
		
		Items.AdditionalReportOptions.TitleLocation = FormItemTitleLocation[?(OutputTableTitle, "Top", "None")];
		Items.AdditionalReportOptions.Header               = Not OutputTableTitle;
		Items.AdditionalReportOptions.HorizontalLines = Not OutputTableTitle;
		
	EndIf;
	
	If CommandsCount > 0 Then
		
		OutputTableTitle = VisibleTabsCount <= 1 And Not IsGlobalDataProcessor;
		
		Items.ObjectCommands.TitleLocation = FormItemTitleLocation[?(OutputTableTitle, "Top", "None")];
		Items.ObjectCommands.Header               = Not OutputTableTitle;
		Items.ObjectCommands.HorizontalLines = Not OutputTableTitle;
		
	EndIf;
	
	WindowOptionsKey = AdditionalReportsAndDataProcessors.KindToString(Object.Kind);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure GeneratePermissionsList()
	
	PermissionsTable = GetFromTempStorage(PermissionsAddress);// CatalogTabularSection.AdditionalReportsAndDataProcessors.Permissions
	
	Permissions = New Array();
	
	ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
	
	For Each TableRow In PermissionsTable Do
		Resolution = XDTOFactory.Create(XDTOFactory.Type(ModuleSafeModeManagerInternal.Package(), TableRow.PermissionKind));
		FillPropertyValues(Resolution, TableRow.Parameters.Get());
		Permissions.Add(Resolution);
	EndDo;
	
	Properties = ModuleSafeModeManagerInternal.PropertiesForPermissionRegister(Object.Ref);
	
	SetPrivilegedMode(True);
	PermissionsPresentation_2_2_2 = ModuleSafeModeManagerInternal.PermissionsToUseExternalResourcesPresentation(
		Properties.Type, Properties.Id, Properties.Type, Properties.Id, Permissions);
	SetPrivilegedMode(False);
	
EndProcedure

&AtServer
Function SecurityProfilePermissions()
	Return GetFromTempStorage(PermissionsAddress);
EndFunction

&AtServer
Procedure FillInCommands(SavedCommands = Undefined)
	
	Object.Commands.Sort("Presentation");
	
	ObjectPrintCommands = Undefined;
	If Object.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm
		And Object.Purpose.Count() = 1
		And Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ObjectPrintCommands = ModulePrintManager.StandardObjectPrintCommands(Object.Purpose[0].RelatedObject);
	EndIf;
	
	For Each ItemCommand In Object.Commands Do
		If Object.Kind = KindAdditionalDataProcessor Or Object.Kind = KindAdditionalReport Then
			FoundItems = QuickAccess.FindRows(New Structure("CommandID", ItemCommand.Id));
			ItemCommand.QuickAccessPresentation = UsersQuickAccessPresentation(
				FoundItems.Count());
		EndIf;
		
		ItemCommand.ScheduledJobUsage = False;
		ItemCommand.ScheduledJobAllowed = False;
		
		If Object.Kind = KindAdditionalDataProcessor
			And (ItemCommand.StartupOption = Enums.AdditionalDataProcessorsCallMethods.ServerMethodCall
			Or ItemCommand.StartupOption = Enums.AdditionalDataProcessorsCallMethods.SafeModeScenario) Then
			
			ItemCommand.ScheduledJobAllowed = True;
			
			GUIDScheduledJob = ItemCommand.GUIDScheduledJob;
			If SavedCommands <> Undefined Then
				FoundRow = SavedCommands.Find(ItemCommand.Id, "Id");
				If FoundRow <> Undefined Then
					GUIDScheduledJob = FoundRow.GUIDScheduledJob;
				EndIf;
			EndIf;
			
			If ValueIsFilled(GUIDScheduledJob) Then
				SetPrivilegedMode(True);
				ScheduledJob = ScheduledJobsServer.Job(GUIDScheduledJob);
				If ScheduledJob <> Undefined Then
					ItemCommand.GUIDScheduledJob = GUIDScheduledJob;
					ItemCommand.ScheduledJobPresentation = String(ScheduledJob.Schedule);
					ItemCommand.ScheduledJobUsage = ScheduledJob.Use;
					ItemCommand.ScheduledJobSchedule.Insert(0, ScheduledJob.Schedule);
				EndIf;
				SetPrivilegedMode(False);
			EndIf;
			If Not ValueIsFilled(ItemCommand.ScheduledJobPresentation) Then
				ItemCommand.ScheduledJobPresentation = NStr("en = 'Not filled';");
			EndIf;
		ElsIf Object.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
			If Not IsBlankString(ItemCommand.CommandsToReplace) And ObjectPrintCommands <> Undefined Then
				CommandsToReplaceIDs = StrSplit(ItemCommand.CommandsToReplace, ",", False);
				CommandsToReplacePresentation = "";
				CommandsToReplaceCount = 0;
				Filter = New Structure("Id, SaveFormat, SkipPreview", Undefined, Undefined, False);
				For Each IDOfCommandToReplace In CommandsToReplaceIDs Do
					Filter.Id = TrimAll(IDOfCommandToReplace);
					ListOfCommandsToReplace = ObjectPrintCommands.FindRows(Filter);
					// If it is impossible to exactly determine a command to replace, replacement is not performed.
					If ListOfCommandsToReplace.Count() = 1 Then
						CommandsToReplacePresentation = CommandsToReplacePresentation + ?(IsBlankString(CommandsToReplacePresentation), "", ", ") + """" + ListOfCommandsToReplace[0].Presentation + """";
						CommandsToReplaceCount = CommandsToReplaceCount + 1;
					EndIf;
				EndDo;
				If CommandsToReplaceCount > 0 Then
					If CommandsToReplaceCount = 1 Then
						CommentTemplate = NStr("en = 'Replace standard print command %1';");
					Else
						CommentTemplate = NStr("en = 'Replace standard print commands: %1';");
					EndIf;
					ItemCommand.Comment = StringFunctionsClientServer.SubstituteParametersToString(CommentTemplate, CommandsToReplacePresentation);
				EndIf;
			EndIf;
		Else
			ItemCommand.ScheduledJobPresentation = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Not applicable for commands with the ""%1"" startup option';"),
				String(ItemCommand.StartupOption));
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure AdditionalReportOptionsFill()
	AdditionalReportOptions.Clear();
	
	Try
		ExternalObject = AdditionalReportsAndDataProcessors.ExternalDataProcessorObject(Object.Ref);
	Except
		ErrorText = NStr("en = 'Cannot get the list of report options due to report attachment error:';");
		MessageText = ErrorText + Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo());
		Common.MessageToUser(MessageText);
		Return;
	EndTry;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		
		ReportMetadata = ExternalObject.Metadata();
		DCSchemaMetadata = ReportMetadata.MainDataCompositionSchema;// MetadataObject
		If DCSchemaMetadata <> Undefined Then
			DCSchema = ExternalObject.GetTemplate(DCSchemaMetadata.Name);
			For Each DCSettingsOption In DCSchema.SettingVariants Do
				VariantKey = DCSettingsOption.Name;
				OptionRef = ModuleReportsOptions.ReportVariant(Object.Ref, VariantKey);
				If OptionRef <> Undefined Then
					Variant = AdditionalReportOptions.Add();
					Variant.VariantKey = VariantKey;
					Variant.Description = DCSettingsOption.Presentation;
					Variant.Custom = False;
					Variant.PictureIndex = 5;
					Variant.Ref = OptionRef;
				EndIf;
			EndDo;
		Else
			VariantKey = "";
			OptionRef = ModuleReportsOptions.ReportVariant(Object.Ref, VariantKey);
			If OptionRef <> Undefined Then
				Variant = AdditionalReportOptions.Add();
				Variant.VariantKey = VariantKey;
				Variant.Description = ReportMetadata.Presentation();
				Variant.Custom = False;
				Variant.PictureIndex = 5;
				Variant.Ref = OptionRef;
			EndIf;
		EndIf;
	Else
		ModuleReportsOptions = Undefined;
	EndIf;
	
	If Object.UseOptionStorage Then
		Store = SettingsStorages["ReportsVariantsStorage"];
		ObjectKey = Object.Ref;
		SettingsList = ModuleReportsOptions.ReportOptionsKeys(ObjectKey);
	Else
		Store = ReportsVariantsStorage;
		ObjectKey = "ExternalReport." + Object.ObjectName;
		SettingsList = Store.GetList(ObjectKey);
	EndIf;
	
	For Each ListItem In SettingsList Do
		Variant = AdditionalReportOptions.Add();
		Variant.VariantKey = ListItem.Value;
		Variant.Description = ListItem.Presentation;
		Variant.Custom = True;
		Variant.PictureIndex = 3;
		If ModuleReportsOptions <> Undefined Then
			Variant.Ref = ModuleReportsOptions.ReportVariant(Object.Ref, Variant.VariantKey);
		EndIf;
	EndDo;
EndProcedure

&AtServer
Function SelectedRelatedObjects()
	Result = New ValueList;
	Result.LoadValues(Object.Purpose.Unload(, "RelatedObject").UnloadColumn("RelatedObject"));
	Return Result;
EndFunction

&AtClient
Procedure SetPrintCommandVisibilityCompletion(DialogResult, AdditionalParameters) Export
	If DialogResult <> "Continue" Then
		Return;
	EndIf;
	Write();
	OpenPrintSubmenuSettingsForm();
EndProcedure

&AtClient
Procedure OpenPrintSubmenuSettingsForm()
	ModulePrintManagerInternalClient = CommonClient.CommonModule("PrintManagementInternalClient");
	ModulePrintManagerInternalClient.OpenPrintSubmenuSettingsForm(SelectedRelatedObjects());
EndProcedure

&AtServer
Function CommandsToDisable()
	Result = New ValueList;
	For Each Command In Object.Commands Do
		If Not IsBlankString(Command.CommandsToReplace) Then
			ItemsToReplaceList = StrSplit(Command.CommandsToReplace, ",", False);
			For Each CommandToReplace In ItemsToReplaceList Do
				Result.Add(CommandToReplace);
			EndDo;
		EndIf;
	EndDo;
	Return Result;
EndFunction

&AtServer
Function CommandsPageName()
	If Object.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
		Return NStr("en = 'Form''s print commands.';");
	Else
		Return NStr("en = 'Commands';");
	EndIf;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Additional attributes

&AtServer
Procedure PropertiesExecuteDeferredInitialization()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillAdditionalAttributesInForm(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.UpdateAdditionalAttributesItems(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion
