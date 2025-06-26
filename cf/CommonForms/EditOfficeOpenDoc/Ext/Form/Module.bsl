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
Var ReClosing;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
			
	If Common.IsMobileClient() Then
		Raise NStr("en = 'Cannot edit an office document in the mobile client.
		|Use thin client or web client.';");
	EndIf;
	
	IsLinuxClient = Common.IsLinuxClient();
	
	If IsLinuxClient Then
		Commands.PutToClipboard.Shortcut = New Shortcut(Key.None, False, False, False);
		Items.PutToClipboard.Visible = False;
	EndIf;
	
	DisplayInstruction();
	Items.InstructionDocumentField.Visible = True;
	Items.DisplayInstruction.Check = Items.InstructionDocumentField.Visible;
	
	If Parameters.WindowOpeningMode <> Undefined Then
		WindowOpeningMode = Parameters.WindowOpeningMode;
	EndIf;
	
	LanguageCode = Common.DefaultLanguageCode();
	IdentifierOfTemplate = Parameters.TemplateMetadataObjectName;
	RefTemplate = Parameters.Ref;
	
	If ValueIsFilled(RefTemplate) Then
		KeyOfEditObject  = RefTemplate;
		LockDataForEdit(KeyOfEditObject,,UUID);
	ElsIf ValueIsFilled(IdentifierOfTemplate) Then
		KeyOfEditObject = InformationRegisters.UserPrintTemplates.GetTemplateRecordKey(IdentifierOfTemplate);
		If KeyOfEditObject <> Undefined Then
			LockDataForEdit(KeyOfEditObject,,UUID);
		EndIf;
	EndIf;

	IsPrintForm = Parameters.IsPrintForm;
	EditingDenied = Not Parameters.Edit;
	IsTemplate = Not IsBlankString(IdentifierOfTemplate) Or IsPrintForm;
	
	If IsTemplate Then
		If Common.SubsystemExists("StandardSubsystems.Print") Then
			ModulePrintManager = Common.CommonModule("PrintManagement");
			TemplateDataSource = ModulePrintManager.TemplateDataSource(IdentifierOfTemplate);
			For Each DataSource In TemplateDataSource Do
				DataSources.Add(DataSource);
			EndDo;
		EndIf;
	EndIf;
	
	If ValueIsFilled(Parameters.DataSource) Then
		If Not ValueIsFilled(DataSources) Then
			DataSources.Add(Parameters.DataSource);
		EndIf;
	EndIf;
	Items.TextAssignment.Title = PresentationOfDataSource(DataSources);
	
	TemplateType = Parameters.TemplateType;
	TemplatePresentation = Parameters.DocumentName;
	TemplateFileName = CommonClientServer.ReplaceProhibitedCharsInFileName(TemplatePresentation) + "." + Lower(TemplateType);
	
	DocumentName = Parameters.DocumentName;
	Items.Rename.Visible = ValueIsFilled(Parameters.Ref) 
		Or IsBlankString(IdentifierOfTemplate) And IsBlankString(Parameters.PathToFile);
	
	ImportOfficeDocFromMetadata(Parameters.LanguageCode);
	If Parameters.Copy Then
		IDOfTemplateBeingCopied = IdentifierOfTemplate;
		IdentifierOfTemplate = "";
	EndIf;
	
	PreparedTemplate = GetFromTempStorage(TemplateFileAddress);
		
	AvailableTranslationLayout = False;
	If IsTemplate Then
		If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.Print") Then
			PrintManagementModuleNationalLanguageSupport = Common.CommonModule("PrintManagementNationalLanguageSupport");
			AvailableTranslationLayout = PrintManagementModuleNationalLanguageSupport.AvailableTranslationLayout(IdentifierOfTemplate);
			If IsPrintForm Or AvailableTranslationLayout Then
				PrintManagementModuleNationalLanguageSupport.FillInTheLanguageSubmenu(ThisObject, Parameters.LanguageCode);
				AutomaticTranslationAvailable = PrintManagementModuleNationalLanguageSupport.AutomaticTranslationAvailable(CurrentLanguage);
			EndIf;
		EndIf;
	EndIf;
	
	Items.Language.Enabled = (IsPrintForm Or AvailableTranslationLayout) And ValueIsFilled(IdentifierOfTemplate);
	
	Items.Translate.Visible = AutomaticTranslationAvailable;
	Items.ButtonShowOriginal.Visible = Items.Translate.Visible;
	Items.ButtonShowOriginal.Enabled = CurrentLanguage <> Common.DefaultLanguageCode();
	
	Items.LanguageAllActions.Enabled = Items.Language.Enabled;
	Items.TranslateAllActions.Visible = Items.Translate.Visible;
	Items.ButtonShowOriginalAllActions.Visible = Items.ButtonShowOriginal.Visible;
	Items.ButtonShowOriginalAllActions.Enabled = Items.ButtonShowOriginal.Enabled;
	
	If Common.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormula = Common.CommonModule("FormulasConstructor");
		
		DataSource = Parameters.DataSource;
		If Not ValueIsFilled(Parameters.DataSource) Then
			DataSource = DataSources[0].Value;
		EndIf;

		MetadataObject = Common.MetadataObjectByID(DataSource);
		PickupSample(MetadataObject);
	
		AddingOptions = ModuleConstructorFormula.ParametersForAddingAListOfFields();
		AddingOptions.ListName = NameOfTheFieldList();
		AddingOptions.LocationOfTheList = Items.AvailableFieldsGroup;
		AddingOptions.FieldsCollections = FieldsCollections(DataSources.UnloadValues(), EditParameters());
		AddingOptions.HintForEnteringTheSearchString = PromptInputStringSearchFieldList();
		AddingOptions.WhenDefiningAvailableFieldSources = "PrintManagement";
		AddingOptions.ListHandlers.Insert("Selection", "Attachable_ListOfFieldsSelection");
		AddingOptions.ListHandlers.Insert("BeforeRowChange", "Attachable_AvailableFieldsBeforeStartOfChange");
		AddingOptions.ListHandlers.Insert("OnEditEnd", "Attachable_AvailableFieldsAtEndOfEditing");
		AddingOptions.UseBackgroundSearch = True;
		
		If Not IsLinuxClient Then
			AddingOptions.ContextMenu.Insert("Duplicate", "PutToClipboard");
		EndIf;
		
		ModuleConstructorFormula.AddAListOfFieldsToTheForm(ThisObject, AddingOptions);
		
		AddingOptions = ModuleConstructorFormula.ParametersForAddingAListOfFields();
		AddingOptions.ListName = NameOfTheListOfOperators();
		AddingOptions.LocationOfTheList = Items.OperatorsAndFunctionsGroup;
		AddingOptions.FieldsCollections.Add(ListOfOperators());
		AddingOptions.HintForEnteringTheSearchString = NStr("en = 'Find operator or function…';");
		AddingOptions.ViewBrackets = False;
		AddingOptions.ListHandlers.Insert("Selection", "Attachable_ListOfFieldsSelection");
		AddingOptions.ListHandlers.Insert("OnActivateRow", "Attachable_FieldListRowActivation");
		AddingOptions.ListHandlers.Insert("DragStart", "Attachable_OperatorsDragStart");
				
		If Not IsLinuxClient Then
			AddingOptions.ContextMenu.Insert("Duplicate", "PutToClipboard");
		EndIf;
		
		ModuleConstructorFormula.AddAListOfFieldsToTheForm(ThisObject, AddingOptions);
		PrepareTemplateForOpening(PreparedTemplate);
		ExpandFieldList();
		
	EndIf;
	
	PutToTempStorage(PreparedTemplate, TemplateFileAddress);
	EditableTemplateHash = GetTemplateHash(TemplateFileAddress);
	TemplateModificationCheckTime =	CurrentUniversalDateInMilliseconds();
	Items.GroupTemplateAssignment.Enabled = Parameters.IsValAvailable;

EndProcedure

&AtClient
Procedure OnOpen(Cancel)

#If WebClient Then
		HideDragZone = False;
#Else
		HideDragZone = True;
#EndIf

	If IsLinuxClient Then
		HideDragZone = False;
	EndIf;

	If Not HideDragZone Then
		Items.GroupHTMLPages.CurrentPage = Items.PageWebClient;
	Else
		Items.GroupHTMLPages.CurrentPage = Items.PageThinClient;
		MoveGroupOfOperatorsAndFunctions();
	EndIf;

	PrepareInstruction();
	MinimizeInterface();
	SetInitialFormSettings();
	
EndProcedure


&AtClient
Procedure OnClose(Exit)
	If Not Exit Then
		ReturnInterface();
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "SpreadsheetDocumentsToEditNameRequest" And Source <> ThisObject Then
		DocumentNames = Parameter; // Array -
		DocumentNames.Add(DocumentName);
	ElsIf EventName = "OwnerFormClosing" And Source = FormOwner Then
		If IsOpen() Then
			Close();
			Parameter.Cancel = True;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)

	If Exit Then
		If Modified And Not CancelSavingChanges Then
			WarningText = NStr("en = 'The print form''s template has been edited in another application.
				|Click ""Save"" to save the changes.';");
			Cancel = True;
		EndIf;
		Return;
	EndIf;

	If Not CancelSavingChanges Then
		
		If Not WritingCompleted Then
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("Cancel", Cancel);
			Notification = New NotifyDescription("BeforeCloseEnd", ThisObject, AdditionalParameters);
			ErrorAlert = New NotifyDescription("ErrorReadingFile", ThisObject);

			ReadTemplateEditableFile(Notification, ErrorAlert);
			Cancel = True;
		Else
			BeforeCloseCompletion(False, Undefined);
		EndIf;
	EndIf;
	
	If Not Cancel And ValueIsFilled(KeyOfEditObject) Then
		UnlockAtServer(); 
	EndIf;
		
EndProcedure


#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure InstructionDocumentFieldOnClick(Item, EventData, StandardProcessing)
	If EventData.Event.type = "click" And StrFind(EventData.Element.href, "CallHelp")<> 0 Then
		OpenHelp("CommonForm.EditOfficeOpenDoc");
		StandardProcessing = False;
	EndIf;
EndProcedure

#EndRegion


#Region FormCommandsEventHandlers

&AtClient
Procedure ShowInstruction(Command)
	Items.InstructionDocumentField.Visible = Not Items.InstructionDocumentField.Visible;
	Items.DisplayInstruction.Check = Items.InstructionDocumentField.Visible; 
EndProcedure

&AtClient
Procedure Write(Command)
	Notification = New NotifyDescription("WriteFollowUp", ThisObject);
	ErrorAlert = New NotifyDescription("ErrorReadingFile", ThisObject);
	ReadTemplateEditableFile(Notification, ErrorAlert);
EndProcedure

&AtClient
Procedure Rename(Command)
	
	NotifyDescription = New NotifyDescription("OnSelectingLayoutName", ThisObject);
	ShowInputString(NotifyDescription, DocumentName, NStr("en = 'Enter a template description';"), 100, False);
	
EndProcedure

&AtClient
Procedure Translate(Command)
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Do you want to automatically translate into the %1 language?';"), Items.Language.Title);
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Translate';"));
	Buttons.Add(DialogReturnCode.No, NStr("en = 'Do not translate';"));
	
	NotifyDescription = New NotifyDescription("WhenAnsweringAQuestionAboutTranslatingALayout", ThisObject);
	ShowQueryBox(NotifyDescription, QueryText, Buttons);
EndProcedure

&AtClient
Procedure ShowOriginal(Command)
	TemplateOpenParameters = GetTemplateOpeningParameters(TemplateFileAddress);
	TemplateOpenParameters.NameOfFileToOpen = "Original.docx";
	TemplateOpenParameters.ReadOnly = True;
	
	OpenTemplate(TemplateOpenParameters);
EndProcedure

&AtClient
Procedure OpenEditor(Command)
	Notification = New NotifyDescription("OpenEditorFollowUp", ThisObject);
	ErrorAlert = New NotifyDescription("ErrorOpeningFile", ThisObject);
	ReadTemplateEditableFile(Notification, ErrorAlert);
	
	If Not IsNew() Then
		Modified = True;
	EndIf;

EndProcedure

&AtClient
Procedure LoadFromFile(Command)
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.FormIdentifier = UUID;
	ImportParameters.Dialog.Title = NStr("en = 'Select an office document';");
	ImportParameters.Dialog.Filter = NStr("en = 'Office document';") + " (*.docx)|*.docx";

	NotifyDescription = New NotifyDescription("ContinueDownloadFromFile", ThisObject);
	FileSystemClient.ImportFile_(NotifyDescription, ImportParameters,, TemplateFileAddress);
EndProcedure

&AtClient
Procedure SaveToFile(Command)
	Notification = New NotifyDescription("SaveToFileFollowUp", ThisObject);
	ErrorAlert = New NotifyDescription("ErrorReadingFile", ThisObject);
	ReadTemplateEditableFile(Notification, ErrorAlert);
EndProcedure

&AtClient
Procedure ExitAppUpdate(Command)
	Notification = New NotifyDescription("ExitAppUpdateCompletion", ThisObject);
	ErrorAlert = New NotifyDescription("ErrorReadingFile", ThisObject);
	ReadTemplateEditableFile(Notification, ErrorAlert);
EndProcedure

&AtClient
Procedure PutToClipboard(Command)
	
	HTMLDocument = Items.HTMLField.Document;
	HTMLDocument.defaultView.value_to_copy = GetCurrentRowValue();
	Button = HTMLDocument.getElementById("myb");
	If Button = Undefined Then
		ShowMessageBox(,NStr("en = 'Select an object field, operator, or function.';"));
	Else
		Button.onclick();
	EndIf;
	
EndProcedure

&AtClient
Procedure ViewPrintableForm(Command)
	Notification = New NotifyDescription("ViewPrintFormFollowUp", ThisObject);
	ErrorAlert = New NotifyDescription("ErrorReadingFile", ThisObject);
	ReadTemplateEditableFile(Notification, ErrorAlert);
EndProcedure

&AtClient
Procedure ViewPrintFormFollowUp(Result, Context) Export
	PrintForm = GetPrintForm();
	SampleAddress = PrintForm.Key;
	If SampleAddress <> Undefined Then
		TemplateOpenParameters = GetTemplateOpeningParameters(SampleAddress);
		TemplateOpenParameters.ShouldPrepareTemplate = False;
		TemplateOpenParameters.ShouldReadHash = False;
		CurrentDate = CommonClient.SessionDate();
		TemplateOpenParameters.NameOfFileToOpen = NStr("en = 'Preview';")+" "+ StrReplace(CurrentDate, ":", "_")+".docx";
		OpenTemplate(TemplateOpenParameters);
	EndIf;
EndProcedure


#EndRegion

#Region Private

&AtServer
Procedure MoveGroupOfOperatorsAndFunctions()
	Items.Move(Items.OperatorsAndFunctionsGroup, Items.PageThinClient);
EndProcedure

&AtClient
Procedure OpenEditorFollowUp(Result, AdditionalParameters) Export
	TemplateOpenParameters = GetTemplateOpeningParameters(TemplateFileAddress);
	TemplateOpenParameters.ShouldPrepareTemplate = False;
	TemplateOpenParameters.ShouldReadHash = True;
	TemplateOpenParameters.NameOfFileToOpen = TemplateFileName;
	OpenTemplate(TemplateOpenParameters);
EndProcedure

&AtClient
Procedure ReadTemplateEditableFile(ContinueNotification, ErrorAlert)
	If PathToTemplateFile = "" Then
		ExecuteNotifyProcessing(ContinueNotification, Undefined);
		Return;
	EndIf;

	NotificationParameters = New Structure("ContinueNotification, ErrorAlert");
	NotificationParameters.ContinueNotification = ContinueNotification;
	NotificationParameters.ErrorAlert = ErrorAlert;
	
	NotifyDescription = New NotifyDescription("OnImportFileToStorage", ThisObject, NotificationParameters);
#If WebClient Then
	RequestCheckPermissionsAndImportFile(NotifyDescription);
#Else
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.FormIdentifier = UUID;
	ImportParameters.Interactively = False;
	FileSystemClient.ImportFile_(NotifyDescription, ImportParameters, PathToTemplateFile, TemplateFileAddress);
#EndIf
	
EndProcedure

&AtClient
Procedure RequestCheckPermissionsAndImportFile(DetailsOfNotificationFollowUp)
	
	AfterPermissionsHandler = New NotifyDescription("AfterRequestedPermissionsToCheckFile", ThisObject, DetailsOfNotificationFollowUp);
	
	ArrayOfFilesToPut = New Array;
	ArrayOfFilesToPut.Add(New TransferableFileDescription(PathToTemplateFile, TemplateFileAddress));
	
	ArrayOfCalls = New Array;
	Call = New Array;
	Call.Add("BeginPuttingFiles");
	Call.Add(ArrayOfFilesToPut);
	Call.Add(Undefined);
	Call.Add(False);
	Call.Add(UUID);
	ArrayOfCalls.Add(Call);
		
	Call = New Array;
	Call.Add("BeginDeletingFiles");
	Call.Add(PathToTemplateFile);
	Call.Add("");
	Call.Add();
	ArrayOfCalls.Add(Call);

	BeginRequestingUserPermission(AfterPermissionsHandler, ArrayOfCalls);
	
EndProcedure

&AtClient
Procedure AfterRequestedPermissionsToCheckFile(PermissionsGranted, DetailsOfNotificationFollowUp) Export
	If Not PermissionsGranted Then
		Return;
	EndIf;
	NotifyDescription = New NotifyDescription("OnImportFileToStorageCheckReading", ThisObject, DetailsOfNotificationFollowUp);
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.FormIdentifier = UUID;
	ImportParameters.Interactively = False;
	FileSystemClient.ImportFile_(NotifyDescription, ImportParameters, PathToTemplateFile, TemplateFileAddress);
EndProcedure

//
// Parameters:
//  FileThatWasPut - Undefined
//                 - Structure:   
//                                    * Location  - String
//                                    * Name       - String
//
&AtClient 
Procedure OnImportFileToStorageCheckReading(FileThatWasPut, DetailsOfNotificationFollowUp) Export
	Context = New Structure("DetailsOfNotificationCompletion", DetailsOfNotificationFollowUp);
	Context.Insert("FilesToUpload", FileThatWasPut);
	NotifyDescription = New NotifyDescription("AfterCheckingExistence", ThisObject, Context);
	File = New File(FileThatWasPut.Name);
	File.BeginCheckingExistence(NotifyDescription);
EndProcedure


// Parameters:
//  Result - Boolean
//  Context - Structure: 
//               * DetailsOfNotificationCompletion - NotifyDescription
//               * FilesToUpload - See OnImportFileToStorageCheckReading.FileThatWasPut
//
&AtClient
Procedure AfterCheckingExistence(Result, Context) Export
	DetailsStartMovingFile = New NotifyDescription("AfterTryToDelete", ThisObject, Context, "FileDeletionError", ThisObject);	
	If Result Then
		BeginDeletingFiles(DetailsStartMovingFile, Context.FilesToUpload.Name);  
	EndIf;
EndProcedure

&AtClient
Procedure AfterTryToDelete(Context) Export
	PathToTemplateFile = "";
	FileStorageStructure = New Structure("Location", TemplateFileAddress);
	ExecuteNotifyProcessing(Context.DetailsOfNotificationCompletion, FileStorageStructure);
EndProcedure

&AtClient
Procedure FileDeletionError(ErrorInfo, StandardProcessing, Context) Export
	StandardProcessing = False;
	WarnAboutLockAndOpenApp();	
EndProcedure

&AtClient
Procedure ErrorOpeningFile(Result, Context) Export
	OpenFileCompletion(PathToTemplateFile);	
EndProcedure

&AtClient
Procedure ErrorReadingFile(Result, Context) Export
	OpenFileCompletion(PathToTemplateFile);	
EndProcedure

&AtClient
Procedure OnImportFileToStorage(File, NotificationParameters) Export
	
	If File <> Undefined Then
		TemplateFileAddress = File.Location;
		ExecuteNotifyProcessing(NotificationParameters.ContinueNotification, Undefined);
	Else
		ExecuteNotifyProcessing(NotificationParameters.ErrorAlert);
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveToFileFollowUp(Result, AdditionalParameters) Export
	
	Template = TemplateFromTempStorage();
	PrepareTemplateForSaving(Template);
	TemplateAddressInTempStorage = PutToTempStorage(Template, UUID);
	
	SavingParameters = FileSystemClient.FileSavingParameters();
	SavingParameters.Dialog.Title = NStr("en = 'Save template to file';");
	SavingParameters.Dialog.Filter = NStr("en = 'Office document';") + " (*.docx)|*.docx";
	FileSystemClient.SaveFile(Undefined, TemplateAddressInTempStorage, DocumentName, SavingParameters);
	
EndProcedure

&AtClient
Procedure ExitAppUpdateCompletion(Result, AdditionalParameters) Export
	NotifyDescription = New NotifyDescription("OnImportFile", ThisObject);
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.FormIdentifier = UUID;
	ImportParameters.Interactively = Not ValueIsFilled(PathToTemplateFile);
	FileSystemClient.ImportFile_(NotifyDescription, ImportParameters, PathToTemplateFile);
EndProcedure

&AtClient
Procedure WriteFollowUp(Result, AdditionalParameters) Export
	
	If IsTempStorageURL(TemplateFileAddress) Then
		Template = TemplateFromTempStorage();
		EditableTemplateHash = GetTemplateHash(Template);
		WriteTemplate(Template);
		NotifyWhenOfficeDocSaved();
	EndIf;
	SetHeader();
	
EndProcedure

// Parameters:
//  FileThatWasPut - See OnImportFileToStorageCheckReading.FileThatWasPut
//
&AtClient
Procedure ContinueDownloadFromFile(FileThatWasPut, AdditionalParameters) Export
	
	If FileThatWasPut = Undefined Then
		Return;
	EndIf;
	
	NameArray = StrSplit(FileThatWasPut.Name, "\/");
	
	TemplateOpenParameters = GetTemplateOpeningParameters(TemplateFileAddress);
	TemplateOpenParameters.ShouldPrepareTemplate = HasParameters(TemplateFileAddress);
	TemplateOpenParameters.NameOfFileToOpen = NameArray[NameArray.UBound()];
	
	Modified = TemplateChanged();
	OpenTemplate(TemplateOpenParameters);
	
EndProcedure

&AtServer
Function HasParameters(AddressOfTemplate)
	Template = GetFromTempStorage(AddressOfTemplate);
	TreeOfTemplate = PrintManagement.InitializeTemplateOfDCSOfficeDoc(Template);
	DocumentStructure = TreeOfTemplate.DocumentStructure;
	DocumentTree = DocumentStructure.DocumentTree;
	ParameterNode = PrintManagementInternal.FindNodeByContent(DocumentTree, "w:textInput");
	Return ParameterNode <> Undefined;
EndFunction

&AtServer
Procedure ImportOfficeDocFromMetadata(Val LanguageCode = Undefined)
	
	TranslationRequired = False;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		
		If IdentifierOfTemplate = "" Then
			TemplateFileAddress = PutToTempStorage(GetCommonTemplate("EmptyDOCXTemplate"), UUID);
		Else
			TemplateFileAddress = PutToTempStorage(ModulePrintManager.PrintFormTemplate(IdentifierOfTemplate, LanguageCode), UUID);
		EndIf;
		
		If IdentifierOfTemplate <> "" And Not ValueIsFilled(RefTemplate) Then
			AddressOf1CSuppliedTemplate = PutToTempStorage(ModulePrintManager.SuppliedTemplate(IdentifierOfTemplate, LanguageCode), UUID);
		EndIf;
	EndIf;
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.Print") Then
		PrintManagementModuleNationalLanguageSupport = Common.CommonModule("PrintManagementNationalLanguageSupport");
		If ValueIsFilled(LanguageCode) Then
			AvailableTabularDocumentLanguages = PrintManagementModuleNationalLanguageSupport.LayoutLanguages(IdentifierOfTemplate);
			TranslationRequired = AvailableTabularDocumentLanguages.Find(LanguageCode) = Undefined;
		EndIf;
		
		If LanguageCode <> "" Then
			LayoutLanguages = PrintManagementModuleNationalLanguageSupport.LayoutLanguages(IdentifierOfTemplate);
			Modified = Modified Or (LayoutLanguages.Find(LanguageCode) = Undefined);
		EndIf;
		
		AutomaticTranslationAvailable = PrintManagementModuleNationalLanguageSupport.AutomaticTranslationAvailable(CurrentLanguage);
		Items.Translate.Visible = AutomaticTranslationAvailable;
		Items.ButtonShowOriginal.Visible = Items.Translate.Visible;

		Items.TranslateAllActions.Visible = Items.Translate.Visible;
		Items.ButtonShowOriginalAllActions.Visible = Items.ButtonShowOriginal.Visible;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyWhenOfficeDocSaved()
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("PathToFile", PathToTemplateFile);
	NotificationParameters.Insert("TemplateMetadataObjectName", IdentifierOfTemplate);
	NotificationParameters.Insert("LanguageCode", CurrentLanguage);
	NotificationParameters.Insert("Presentation", DocumentName);
	NotificationParameters.Insert("DataSources", DataSources.UnloadValues());
	
	If WritingCompleted Then
		EventName = "Write_OfficeDocument";
	Else
		EventName = "CancelEditingOfficeDoc";
	EndIf;
	Notify(EventName, NotificationParameters, ThisObject);
	
	WritingCompleted = False;
	
EndProcedure


&AtServer
Procedure UnlockAtServer() 
	UnlockDataForEdit(KeyOfEditObject, UUID);
EndProcedure

&AtClient
Procedure BeforeCloseEnd(Result, AdditionalParameters) Export
	
	Cancel = AdditionalParameters.Cancel;
	
	If ReClosing <> True Then
		Modified = Modified Or TemplateChanged();
	EndIf;
	ReClosing = True;
	
	NotifyDescription = New NotifyDescription("BeforeCloseCompletion", ThisObject);
	LanguageDetails = ?(ValueIsFilled(CurrentLanguage), " (" + CurrentLanguage + ")", "");
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Do you want to save the changes to %1%2?';"), 
		DocumentName, LanguageDetails);
	CommonClient.ShowFormClosingConfirmation(NotifyDescription, Cancel, False, QueryText);
	
	If Modified Then
		Return;
	EndIf;
	
	If Not Cancel Then
		CancelSavingChanges = True;
		Close();
	EndIf;
EndProcedure

&AtServer
Function TemplateChanged()
	
	Template = GetFromTempStorage(TemplateFileAddress);
	If Template <> Undefined Then 	
		Hashing = New DataHashing(HashFunction.CRC32);
		Hashing.Append(Template);
		CacheOfCurrentTemplate =	Hashing.HashSum;
		TemplateModificationCheckTime = CurrentUniversalDateInMilliseconds();
	Else
		CacheOfCurrentTemplate = EditableTemplateHash;
	EndIf;
	
	Return CacheOfCurrentTemplate <> EditableTemplateHash;
EndFunction 

&AtClient
Procedure BeforeCloseCompletion(Result, AdditionalParameters) Export
	
	If Not CancelSavingChanges And Not WritingCompleted Then
		TemplateImported = True;
		Template = TemplateFromTempStorage();
		WriteTemplate(Template);
	EndIf;
	Close(Template);
	
	If Not IsNew() Then
		NotifyWhenOfficeDocSaved();
	EndIf;
	
EndProcedure

&AtServer
Procedure DisplayInstruction()
	 
	Template = GetCommonTemplate("GuideHowToSetUpOpenOfficeTemplate");
	InstructionDocumentField = Template.GetText();
		
EndProcedure

&AtClient
Procedure PrepareInstruction()
	
	If Not HideDragZone Then
		InstructionDocumentField = StrReplace(InstructionDocumentField, ".thinclient{", ".webclient{");
	EndIf;
	
EndProcedure


&AtClient
Procedure SetInHTMLField(Value)
	
	If ValueIsFilled(Value) Then
		If IsLinuxClient Then
			HTMLText = "<!DOCTYPE html>
						|
						|<html>
						|
						|<head>
						|    <title>%2</title>
						|    <style type=""text/css"">
						|        body {
						|            background: rgb(255, 255, 255);
						|            overflow-y: hidden;
						|            overflow-x: hidden;
						|        }
						|        
						|        .draggable {
						|            font-weight: normal;
						|            position: relative;
						|            display: block;
						|            border-color: rgb(253, 205, 143);
						|            border-style: dashed;
						|            border-radius: 10px;
						|            border-width: 4px;
						|        }
						|        
						|        .draggabletext {
						|            margin-left: 5px;
						|        }
        				|
						|        .draggabletab {
						|            font-size: xx-small;
						|        }
        				|
						|        .draggablebackground {
						|            position: absolute;
						|            top: 0;
						|            bottom: 0;
						|            z-index: -1;
						|            background-color: rgb(254, 242, 199);
						|            color: rgb(253, 205, 143);
						|            width: 100%%;
						|            height: 100%%;
						|            text-align: right;
						|        }
						|        
						|        .draggablebackgroundtest {
						|            position: absolute;
						|            color: rgb(253, 205, 143);
						|            width: 97%%;
						|            text-align: right;
						|        }
						|        
						|        .myButton {
						|            background-color: #ffec64;
						|            border-radius: 4px;
						|            float: none;
						|            position: absolute;
						|            bottom: 1%%;
						|            right: 1%%;
						|            display: none;
						|            background-color: rgb(254, 242, 199);
						|        }
						|    </style>
						|</head>
						|
						|<body style=""font-family:Arial, Helvetica, sans-serif;"">
						|    <div id=""field"" class=""draggable"" draggable=""true"" ondragstart=""onDragStart(event);"">
						|        <div class=""draggablebackground"">
						|            <Div class=""draggabletab""> <br></Div>
						|
						|            <div class=""draggablebackgroundtest"">
						|                %3
						|            </div>
						|        </div>
						|        <p>
						|            <div class=""draggabletext"">%1</div>
						|        </p>
						|    </div>
						|    <button id=""myb"" class=""myButton"" onclick=""copytext();"">%4</button>
						|    <script type=""text/javascript"">
						|    var value_to_copy = null;
						|        function onDragStart(event) {
						|            event
						|                .dataTransfer
						|                .setData('text/plain', value_to_copy);
						|        }
						|
        				|		function copytext() {
						|            var area = document.createElement('textarea');
						|
						|            document.body.appendChild(area);
						|            area.value = value_to_copy;
						|            area.select();
						|            document.execCommand(""copy"");
						|            document.body.removeChild(area);
						|        }
						|    </script>
						|</body>
						|
						|</html>";
		Else
			HTMLText = "<!DOCTYPE html>
						|<html>
						|
						|<head>
						|    <title>%2</title>
						|    <style type=""text/css"">
						|        body {
						|            background: rgb(255, 255, 255);
						|            overflow-y: hidden;
						|            overflow-x: hidden;
						|        }
						|
						|		  .draggable {
						|            font-weight: normal;
						|            position: relative;
						|            display: block;
						|            border-color: rgb(253, 205, 143);
						|            border-style: dashed;
						|            border-radius: 10px;
						|            border-width: 4px;
						|        }
						|        
						|        .draggabletext {
						|            margin-left:5px;
						|
						|        }
						|
						|        .draggablebackground {
						|            position: absolute;
						|            top: 0;
						|            bottom: 0;
						|            z-index: -1;
						|            background-color: rgb(254, 242, 199);
						|            color: rgb(253, 205, 143);
						|            width: 100%%;
						|            height: 100%;
						|            text-align: right;
						|        }
						|        .draggablebackgroundtest {
						|            position: absolute;
						|            top: 50%%;
						|            color: rgb(253, 205, 143);
						|            width: 97%%;
						|            text-align: right;
						|            transform: translateY(-50%%);
						|        }
						|
						|        .myButton {
						|
						|            background-color: #ffec64;
						|            border-radius: 4px;
						|            float: none;
						|            position: absolute;
						|            bottom: 1%%;
						|            right: 1%%;
						|            display: none;
						|			 background-color: rgb(254, 242, 199);
						|        }
						|    </style>
						|</head>
						|
						|<body style=""font-family:Arial, Helvetica, sans-serif;"">
						|    <div id=""field"" class=""draggable"" draggable=""true"" ondragstart=""onDragStart(event);"">
						|		<div class=""draggablebackground"">
	                    |       	<div class=""draggablebackgroundtest"">
	                    | 				%3
	                    |   	    </div>
	                    |    	</div>
	                    |    	<p><div class=""draggabletext"">%1</div></p>
						|    </div>
						|    <button id=""myb"" class=""myButton"" onclick=""copytext();"">%4</button>
						|    <script type=""text/javascript"">
						|    var value_to_copy = null;
						|        function onDragStart(event) {
						|            event
						|                .dataTransfer
						|                .setData('text/plain', value_to_copy);
						|        }
						|        function copytext() {
						|            var area = document.createElement('textarea');
						|
						|            document.body.appendChild(area);
						|            area.value = value_to_copy;
						|            area.select();
						|            document.execCommand(""copy"");
						|            document.body.removeChild(area);
						|        }
						|    </script>
						|</body>
						|
						|</html>";
		EndIf;
									
	Else
		
		HTMLText = "<!DOCTYPE html>
					|
					|<html>
					|
					|<head>
					|    <title>%2</title>
					|    <style type=""text/css"">
					|        body {
					|            background: rgb(255, 255, 255);
					|            overflow-y: hidden;
					|            overflow-x: hidden;
					|        }
					|
					|        .draggable {
					|            font-weight: normal;
					|            position: relative;
					|            display: block;
					|            border-color: rgb(253, 205, 143);
					|            color: rgb(253, 205, 143);
					|            background-color: rgb(254, 242, 199);
					|            border-style: dashed;
					|            border-radius: 10px;
					|            border-width: 4px;
					|            font-size: large;
					|            text-align: center;
					|        }
					|        
					|    </style>
					|</head>
					|
					|<body style=""font-family:Arial, Helvetica, sans-serif;"">
					|    <div class=""draggable"">
					|        <p><b>%5</b></p>
					|    </div>
					|    
					|</body>
					|
					|</html>";
	EndIf;
	
	HTMLField = StringFunctionsClientServer.SubstituteParametersToString(HTMLText,
		StrReplace(Value, """", "&quot;"),
		NStr("en = 'Wrap the text';"),
		NStr("en = 'Drag<br> to the editor';"),
		NStr("en = 'Copy';"),
		NStr("en = 'Select a field';"));
	HTMLField = StrReplace(HTMLField, "%%", "%");
EndProcedure


&AtClient
Procedure OnImportFile(File, AdditionalParameters) Export
	
	TemplateImported = File <> Undefined;
	If TemplateImported Then
		TemplateFileAddress = File.Location;
		TemplateFileName = File.Name;
	EndIf;
	
	WriteTemplateAndClose();
	
EndProcedure

&AtClient
Procedure WriteTemplateAndClose()
	Template = Undefined;
	If TemplateImported Then
		Template = TemplateFromTempStorage();
		WriteTemplate(Template);
		WritingCompleted = True;
	EndIf;
	
	Close(Template);
EndProcedure


&AtServer
Function TemplateFromTempStorage()
	Template = GetFromTempStorage(TemplateFileAddress); 
	Return Template;
EndFunction

&AtServer
Procedure WriteTemplate(Template)
	
	PrepareTemplateForSaving(Template);
	
	TemplateAddressInTempStorage = PutToTempStorage(Template, UUID);
	TemplateDetails = PrintManagement.TemplateDetails();
	TemplateDetails.TemplateMetadataObjectName = IdentifierOfTemplate;
	TemplateDetails.TemplateAddressInTempStorage = TemplateAddressInTempStorage;
	TemplateDetails.LanguageCode = CurrentLanguage;
	TemplateDetails.Description = DocumentName;
	TemplateDetails.Ref = RefTemplate;
	TemplateDetails.TemplateType = "DOCX";
	TemplateDetails.DataSources = DataSources.UnloadValues();
	
	IdentifierOfTemplate = PrintManagement.WriteTemplate(TemplateDetails);
	If Not ValueIsFilled(RefTemplate) Then
		RefTemplate = PrintManagement.RefTemplate(IdentifierOfTemplate);
	EndIf;
	
	WriteTemplatesInAdditionalLangs();
	
	If Not Items.Language.Enabled Then
		Items.Language.Enabled  = True;
	EndIf;
	
	TemplateSavedLangs.Add(CurrentLanguage);
	WritingCompleted = True;
	Modified = False;
	
EndProcedure

&AtServer
Procedure WriteTemplatesInAdditionalLangs()
	
	TemplateParameters1 = New Structure;
	TemplateParameters1.Insert("IDOfTemplateBeingCopied", IDOfTemplateBeingCopied);
	TemplateParameters1.Insert("CurrentLanguage", CurrentLanguage);
	TemplateParameters1.Insert("UUID", UUID);
	TemplateParameters1.Insert("IdentifierOfTemplate", IdentifierOfTemplate);
	TemplateParameters1.Insert("LayoutOwner", LayoutOwner);
	TemplateParameters1.Insert("DocumentName", DocumentName);
	TemplateParameters1.Insert("RefTemplate", RefTemplate);
	TemplateParameters1.Insert("TemplateType", "DOCX");
	
	PrintManagement.WriteTemplatesInAdditionalLangs(TemplateParameters1);
	
EndProcedure

&AtServer
Procedure PrepareTemplateForSaving(Template)
	TreeOfTemplate = PrintManagement.InitializeTemplateOfDCSOfficeDoc(Template);
	ReplacementsMap = New Map();
	For Each TextParameter In TreeOfTemplate.DocumentStructure.TextParameters Do
		TextParameterKey = TextParameter;
		ReplaceViewParameters(TextParameter);
		ReplacementsMap.Insert(TextParameterKey, TextParameter);
	EndDo;
	AreaPopulationParameters = PrintManagement.AreaPopulationParameters();
	AreaPopulationParameters.ShouldAddLinks = False;
	PrintManagement.SpecifyParameters(TreeOfTemplate, ReplacementsMap, AreaPopulationParameters);
	Address = PrintManagementInternal.GetPrintForm(TreeOfTemplate);
	Template = GetFromTempStorage(Address);
		
EndProcedure

&AtServer
Procedure PrepareTemplateForOpening(Template, PopulateTemplateFileAddress = False)
	TreeOfTemplate = PrintManagement.InitializeTemplateOfDCSOfficeDoc(Template);
	DocumentStructure = TreeOfTemplate.DocumentStructure;
	DocumentTree = DocumentStructure.DocumentTree;
	PrintManagement.ConvertParameters(DocumentTree);
	For Each HeaderOrFooter In DocumentStructure.HeaderFooter Do
		PrintManagement.ConvertParameters(HeaderOrFooter.Value);
	EndDo;
	
	ReplacementsMap = New Map();
	For Each TextParameter In TreeOfTemplate.DocumentStructure.TextParameters Do
		TextParameterKey = TextParameter;
		ReplaceParametersWithViews(TextParameter);
		ReplacementsMap.Insert(TextParameterKey, TextParameter);
	EndDo;
	
	AreaPopulationParameters = PrintManagement.AreaPopulationParameters();
	AreaPopulationParameters.ShouldAddLinks = False;
	PrintManagement.SpecifyParameters(TreeOfTemplate, ReplacementsMap, AreaPopulationParameters);
	If PopulateTemplateFileAddress Then
		Address = PrintManagementInternal.GetPrintForm(TreeOfTemplate, TemplateFileAddress);
	Else
		Address = PrintManagementInternal.GetPrintForm(TreeOfTemplate);
	EndIf;
	
	Template = GetFromTempStorage(Address);
EndProcedure

&AtServer
Procedure ReplaceParametersWithViews(String)
	
	ReplacementParameters = RepresentationTextParameters(String(String));
	
	String = ReplaceInline(String, ReplacementParameters);
	
EndProcedure

&AtServer
Function RepresentationTextParameters(Val Text)
	
	Result = New Map();
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		Return ModulePrintManager.RepresentationTextParameters(Text, ThisObject);
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure ReplaceViewParameters(String)
	
	ReplacementParameters = FormulasFromText(String(String));
	
	For Each Parameter In ReplacementParameters Do
		Formula = Parameter.Key;
		If StrOccurrenceCount(Formula, "[") > 1 Then
			Formula = Mid(Formula, 2, StrLen(Formula) - 2);
		EndIf;		
		
		ErrorText = FormulasConstructorInternal.CheckFormula(ThisObject, Formula);
			
		If ValueIsFilled(ErrorText) Then
			Common.MessageToUser(ErrorText);
		EndIf;
	EndDo;
	
	String = ReplaceInline(String, ReplacementParameters);
	
EndProcedure

&AtServer
Function ReplaceInline(Val String, ReplacementParameters)
	
	For Each Item In ReplacementParameters Do
		SearchSubstring = Item.Key;
		ReplaceSubstring = Item.Value;
		String = StrReplace(String, SearchSubstring, ReplaceSubstring);
	EndDo;
	
	Return String;
	
EndFunction

&AtServer
Function FormulasFromText(Val Text)
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		Return ModulePrintManager.FormulasFromText(Text, ThisObject);
	EndIf;
	
EndFunction

&AtClient
Procedure SetInitialFormSettings()
			
	SetDocumentName();
	SetHeader();
	SetUpCommandPresentation();

EndProcedure

&AtClient
Procedure SetDocumentName()

	If IsBlankString(DocumentName) Then
		UsedNames = New Array;
		Notify("SpreadsheetDocumentsToEditNameRequest", UsedNames, ThisObject);
		
		IndexOf = 1;
		While UsedNames.Find(NewDocumentName() + IndexOf) <> Undefined Do
			IndexOf = IndexOf + 1;
		EndDo;
		
		DocumentName = NewDocumentName() + IndexOf;
	EndIf;

EndProcedure

&AtClient
Function NewDocumentName()
	Return NStr("en = 'New';");
EndFunction

&AtClient
Function GetTemplateOpeningParameters(DocumentAddress)
	OpeningParameters = New Structure;
	OpeningParameters.Insert("DocumentAddress", DocumentAddress);
	OpeningParameters.Insert("ShouldPrepareTemplate", True);
	OpeningParameters.Insert("ShouldReadHash", False);
	OpeningParameters.Insert("NameOfFileToOpen", "");
	OpeningParameters.Insert("ReadOnly", EditingDenied);
	Return OpeningParameters;
EndFunction

&AtClient
Procedure OpenTemplate(OpeningParameters)

	CompletionHandler = New NotifyDescription("OpenAfterSavedAtClient", ThisObject, OpeningParameters);

	Template = GetFromTempStorage(OpeningParameters.DocumentAddress);
	
	If OpeningParameters.ShouldPrepareTemplate Then
		PrepareTemplateForOpening(Template, OpeningParameters.DocumentAddress = TemplateFileAddress);
	EndIf;
	
	If OpeningParameters.ShouldReadHash Then
		EditableTemplateHash = GetTemplateHash(Template);
	EndIf;

	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CompletionHandler", CompletionHandler);
	AdditionalParameters.Insert("TempDirectory", TempDirectory);
	AfterAttachExtension = New NotifyDescription("AfterAttachExtension", ThisObject, AdditionalParameters);
	FileSystemClient.AttachFileOperationsExtension(AfterAttachExtension);
	
	Items.OpenEditor.DefaultButton = False;
	Items.WriteAndClose.DefaultButton = True;
	
	Items.InstructionDocumentField.Visible = False;
	Items.DisplayInstruction.Check = False;
EndProcedure

&AtClient
Procedure AfterAttachExtension(Attached, AdditionalParameters) Export
	If Attached Then
		Handler = New NotifyDescription("OpenTemplateAfterGotTempDir", ThisObject, AdditionalParameters.CompletionHandler);
		If TempDirectory = "" Then
#If WebClient Then
			FileSystemClient.SelectDirectory(Handler);	
#Else
			FileSystemClient.CreateTemporaryDirectory(Handler);
#EndIf
		Else
			ExecuteNotifyProcessing(Handler, TempDirectory);
		EndIf;
	Else
		Handler = New NotifyDescription("AfterRequestPermissionsToOpenTemplate", ThisObject, AdditionalParameters);
		ExecuteNotifyProcessing(Handler);
	EndIf;
EndProcedure

// Parameters:
//  CreatedTempDir - String
//  CompletionHandler - NotifyDescription
//
&AtClient
Procedure OpenTemplateAfterGotTempDir(CreatedTempDir, CompletionHandler) Export
	TempDirectory = CommonClientServer.AddLastPathSeparator(
		CreatedTempDir);
	
	OpeningParameters = CompletionHandler.AdditionalParameters;
	
	Context = New Structure;
	Context.Insert("CompletionHandler", CompletionHandler);
	Context.Insert("TempDirectory", TempDirectory);
	
	AfterPermissionsHandler = New NotifyDescription("AfterRequestPermissionsToOpenTemplate", ThisObject, Context);
	
	ArrayOfReceivedFiles = New Array;
	ArrayOfReceivedFiles.Add(New TransferableFileDescription(TempDirectory+OpeningParameters.NameOfFileToOpen,OpeningParameters.DocumentAddress));
	
	ArrayOfCalls = New Array;
	Call = New Array;
	Call.Add("BeginGettingFiles");
	Call.Add(ArrayOfReceivedFiles);
	Call.Add(TempDirectory);
	Call.Add(False);
	ArrayOfCalls.Add(Call);
		
	Call = New Array;
	Call.Add("BeginRunningApplication");
	Call.Add(TempDirectory+OpeningParameters.NameOfFileToOpen);
	Call.Add();
	Call.Add(False);
	ArrayOfCalls.Add(Call);
	
	BeginRequestingUserPermission(AfterPermissionsHandler, ArrayOfCalls);
EndProcedure

&AtClient
Procedure AfterRequestPermissionsToOpenTemplate(PermissionsGranted, Context) Export
	
	If PermissionsGranted = False Then
		Return;
	EndIf;
	
	AfterPermissionsHandler = Context.CompletionHandler; // NotifyDescription
	TempDirectory = Context.TempDirectory;
	
	SavingParameters = FileSystemClient.FileSavingParameters();
	
#If WebClient Then
		SavingParameters.Interactively = True;
#Else
		SavingParameters.Interactively = False;
#EndIf

	OpeningParameters = AfterPermissionsHandler.AdditionalParameters;		
	FileSystemClient.SaveFile(AfterPermissionsHandler, OpeningParameters.DocumentAddress, TempDirectory+OpeningParameters.NameOfFileToOpen, SavingParameters);
EndProcedure

&AtClient
Procedure OpenAfterSavedAtClient(ObtainedFiles, OpeningParameters) Export

	If ObtainedFiles <> Undefined Then		
		PathToFile = ObtainedFiles[0].FullName;
		
		If OpeningParameters.DocumentAddress = TemplateFileAddress Then
			PathToTemplateFile = PathToFile;
		EndIf;
		
		FileOnHardDrive = New File(PathToFile);
		DetailsAfterSetReadOnly = New NotifyDescription("OpenFileCompletion", ThisObject, PathToFile);
		FileOnHardDrive.BeginSettingReadOnly(DetailsAfterSetReadOnly, OpeningParameters.ReadOnly);
	EndIf;
EndProcedure

&AtClient
Procedure OpenFileCompletion(PathToFile) Export		
	FileOpeningParameters = FileSystemClient.FileOpeningParameters();
	FileSystemClient.OpenFile(PathToFile,,,FileOpeningParameters);
EndProcedure

&AtServerNoContext
Function GetTemplateHash(AddressOrData)
	Hashing = New DataHashing(HashFunction.CRC32);
	If TypeOf(AddressOrData) = Type("String") 
		And IsTempStorageURL(AddressOrData) Then
		
		Hashing.Append(GetFromTempStorage(AddressOrData));
	Else
		Hashing.Append(AddressOrData);
	EndIf;
	Return Hashing.HashSum;
EndFunction

&AtClient
Procedure MinimizeInterface()
	
	MinimizeInterfaceAtServer();
	RefreshInterface();
	ReturnInterfaceAtServer();
	
EndProcedure

&AtServer
Procedure MinimizeInterfaceAtServer()
	InterfaceCurrentSettings = SystemSettingsStorage.Load("Common/ClientApplicationInterfaceSettings");
	PanelsSettingAddress = PutToTempStorage(InterfaceCurrentSettings, UUID);
	
	CompositionSettings1 = New ClientApplicationInterfaceContentSettings;
	InterfaceSettings = New ClientApplicationInterfaceSettings;
	InterfaceSettings.SetContent(CompositionSettings1);
	SystemSettingsStorage.Save("Common/ClientApplicationInterfaceSettings", , InterfaceSettings);
	
EndProcedure

&AtClient
Procedure ReturnInterface()
	
	RefreshInterface();
	
EndProcedure

&AtServer
Procedure ReturnInterfaceAtServer()
	
	If IsTempStorageURL(PanelsSettingAddress) Then
		InterfaceSettings = GetFromTempStorage(PanelsSettingAddress);
		SystemSettingsStorage.Save("Common/ClientApplicationInterfaceSettings", , InterfaceSettings);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetHeader()
	
	Title = DocumentName;
	
	If ValueIsFilled(CurrentLanguage) Then 
		CurrentLanguagePresentation = Items["Language_"+CurrentLanguage].Title; 
		Title = Title + " ("+CurrentLanguagePresentation+")";
	EndIf;
	
	If IsNew() Then
		Title = Title + " (" + NStr("en = 'create';") + ")";
	ElsIf EditingDenied Then
		Title = Title + " (" + NStr("en = 'read-only';") + ")";
	EndIf;
	
EndProcedure

&AtClient
Function IsNew()
	Return Not ValueIsFilled(Parameters.Ref) And IsBlankString(IdentifierOfTemplate) And IsBlankString(Parameters.PathToFile);
EndFunction

&AtClient
Procedure WhenFormatFieldSelection(Format, AdditionalParameters) Export
	
	If Format = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Items[NameOfTheFieldList()].CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	CurrentData.Format = Format;
	CurrentData.Pattern = Format(CurrentData.Value, CurrentData.Format);
	
	PopulateHTMLFIeldByCurrField();
EndProcedure

&AtClient
Procedure Attachable_SwitchLanguage(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	ParametersForResuming = New Structure("Command", Command);
	Notification = New NotifyDescription("SwitchLangAfterImportFileFollowUp", ThisObject, ParametersForResuming);
	ErrorAlert = New NotifyDescription("ErrorReadingFile", ThisObject);
	ReadTemplateEditableFile(Notification, ErrorAlert);
EndProcedure

&AtClient
Procedure Attachable_WhenSwitchingTheLanguage(LanguageCode, AdditionalParameters) Export
	
	ImportOfficeDocFromMetadata(LanguageCode);
	If TranslationRequired And AutomaticTranslationAvailable Then
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Template has not been translated into the %1 language yet.
			|Do you want to translate it automatically?';"), Items.Language.Title);
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Translate';"));
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Do not translate';"));
		
		NotifyDescription = New NotifyDescription("WhenAnsweringAQuestionAboutTranslatingALayout", ThisObject);
		ShowQueryBox(NotifyDescription, QueryText, Buttons);
	Else
		TemplateOpenParameters = GetTemplateOpeningParameters(TemplateFileAddress);
		TemplateOpenParameters.ShouldReadHash = True;
		TemplateOpenParameters.NameOfFileToOpen = TemplateFileName;
		OpenTemplate(TemplateOpenParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure SwitchLangAfterImportFileFollowUp(Result, AdditionalParameters) Export
	
	Modified = Modified Or TemplateChanged();
	
	ParametersForResuming = New Structure("Command", AdditionalParameters.Command);
	NotifyDescription = New NotifyDescription("SwitchLangFollowUp", ThisObject, ParametersForResuming);
	
	If Modified Then
		LanguageDetails = ?(ValueIsFilled(CurrentLanguage), " (" + CurrentLanguage + ")", "");
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Do you want to save the changes to %1%2?';"), DocumentName, LanguageDetails);
		ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNoCancel, ,
			DialogReturnCode.Yes);
	Else
		ExecuteNotifyProcessing(NotifyDescription, DialogReturnCode.No);
	EndIf;
			
EndProcedure

&AtClient
Procedure SwitchLangFollowUp(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Cancel Then
		Return;
	ElsIf Response = DialogReturnCode.Yes Then
	
		Template = TemplateFromTempStorage();
		WriteTemplate(Template);
		
		Modified = False;
	ElsIf Response = DialogReturnCode.No Then
		Modified = False;
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManagerClient = CommonClient.CommonModule("PrintManagementClient");
		ModulePrintManagerClient.SwitchLanguage(ThisObject, AdditionalParameters.Command);
		SetHeader();
		Items.DeleteLayoutLanguage.Visible = CurrentLanguage <> CommonClient.DefaultLanguageCode();
		Items.ButtonShowOriginal.Enabled = CurrentLanguage <> CommonClient.DefaultLanguageCode();
	EndIf;	
EndProcedure

&AtClient
Procedure DeleteLayoutLanguage(Command)
	
	If CurrentLanguage = CommonClient.DefaultLanguageCode() Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("DeleteTemplateLanguageFollowUp", ThisObject, , "ErrorMovingDeletingFile", ThisObject);
	BeginDeletingFiles(NotifyDescription, PathToTemplateFile);
	
EndProcedure

&AtClient
Procedure ErrorMovingDeletingFile(ErrorInfo, StandardProcessing, AdditionalParameters) Export
	StandardProcessing = False;
	WarnAboutLockAndOpenApp();	
EndProcedure

&AtClient
Procedure WarnAboutLockAndOpenApp()
	NotifyDescription = New NotifyDescription("OpenFileCompletion", ThisObject, PathToTemplateFile);
	ShowMessageBox(NotifyDescription, NStr("en = 'Complete the operation with the file in another application.';"), , NStr("en = 'The file is opened in another application';"));
EndProcedure

&AtServer
Procedure DeleteLayoutInCurrentLanguage()
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.DeleteTemplate(IdentifierOfTemplate, CurrentLanguage);
	EndIf;
	
	MenuLang = Items.Language;
	LangsToAdd = Items.LangsToAdd;
	LangOfFormToDelete = CurrentLanguage;
	CurrentLanguage = Common.DefaultLanguageCode();
	For Each LangButton In MenuLang.ChildItems Do
		If StrEndsWith(LangButton.Name, LangOfFormToDelete) Then
			LangButton.Check = False;
			LangButton.Visible = False;
		EndIf;
		
		If StrEndsWith(LangButton.Name, CurrentLanguage) Then
			LangButton.Check = True;
		EndIf;
	EndDo;
	
	For Each ButtonForAddedLang In LangsToAdd.ChildItems Do
		If StrEndsWith(ButtonForAddedLang.Name, LangOfFormToDelete) Then
			ButtonForAddedLang.Visible = True;
		EndIf;
	EndDo;
	
	MenuLanguageAllActions = Items.LanguageAllActions;
	LangsToAddAllActions = Items.LangsToAddAllActions;
	For Each LangButton In MenuLanguageAllActions.ChildItems Do
		If TypeOf(LangButton) = Type("FormButton") Then
			If StrEndsWith(LangButton.CommandName, LangOfFormToDelete) Then
				LangButton.Check = False;
				LangButton.Visible = False;
			EndIf;
			
			If StrEndsWith(LangButton.CommandName, CurrentLanguage) Then
				LangButton.Check = True;
			EndIf;
		EndIf;
	EndDo;
	
	For Each ButtonForAddedLang In LangsToAddAllActions.ChildItems Do
		If TypeOf(ButtonForAddedLang) = Type("FormButton") Then
			If StrEndsWith(ButtonForAddedLang.CommandName, LangOfFormToDelete) Then
				ButtonForAddedLang.Visible = True;
			EndIf;
		EndIf;
	EndDo;
	
	Items.Language.Title = Items["Language_"+CurrentLanguage].Title;
	Items.LanguageAllActions.Title = Items["Language_"+CurrentLanguage].Title;
	
	ImportOfficeDocFromMetadata(CurrentLanguage);
	PreparedTemplate = GetFromTempStorage(TemplateFileAddress);
	
	PrepareTemplateForOpening(PreparedTemplate);
	PutToTempStorage(PreparedTemplate, TemplateFileAddress);
	EditableTemplateHash = GetTemplateHash(TemplateFileAddress);
	TemplateModificationCheckTime =	CurrentUniversalDateInMilliseconds();
	
	
	Modified = False;
	
EndProcedure

&AtClient
Procedure DeleteTemplateLanguageFollowUp(AdditionalParameters) Export
	PathToTemplateFile = "";
	DeleteLayoutInCurrentLanguage();

	WritingCompleted = True;
	NotifyWhenOfficeDocSaved();

	Items.DeleteLayoutLanguage.Visible = CurrentLanguage <> CommonClient.DefaultLanguageCode();
	Items.ButtonShowOriginal.Enabled = False;
	SetHeader();
EndProcedure

&AtClient
Procedure WhenAnsweringAQuestionAboutTranslatingALayout(Response, AdditionalParameters) Export
	
	TemplateOpenParameters = GetTemplateOpeningParameters(TemplateFileAddress);
	TemplateOpenParameters.ShouldReadHash = True;
	TemplateOpenParameters.NameOfFileToOpen = TemplateFileName;
	
	If Response <> DialogReturnCode.Yes Then
		OpenTemplate(TemplateOpenParameters);
		Return;
	EndIf;
	
	TranslateLayoutTexts();
	OpenTemplate(TemplateOpenParameters);
EndProcedure

&AtServer
Procedure TranslateLayoutTexts()
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.Print") Then
		PrintManagementModuleNationalLanguageSupport = Common.CommonModule("PrintManagementNationalLanguageSupport");
		PrintManagementModuleNationalLanguageSupport.TranslateOfficeDoc(TemplateFileAddress, CurrentLanguage, Common.DefaultLanguageCode());
		
		Modified = True;
	EndIf;
	
EndProcedure


#Region PrintableFormConstructor

&AtServer
Procedure PickupSample(MetadataObject)
	
	QueryText =
	"SELECT TOP 1
	|	SpecifiedTableAlias.Ref AS Ref
	|FROM
	|	&Table AS SpecifiedTableAlias
	|ORDER BY
	|	Ref DESC";
	
	QueryText = StrReplace(QueryText, "&Table", MetadataObject.FullName());
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Pattern = Selection.Ref;
	EndIf;
	
EndProcedure

&AtServer
Procedure ExpandFieldList()
	
	AttributesToBeAdded = New Array;
	AttributesToBeAdded.Add(New FormAttribute("Pattern", New TypeDescription, NameOfTheFieldList()));
	AttributesToBeAdded.Add(New FormAttribute("Format", New TypeDescription("String"), NameOfTheFieldList()));
	AttributesToBeAdded.Add(New FormAttribute("DefaultFormat", New TypeDescription("String"), NameOfTheFieldList()));
	AttributesToBeAdded.Add(New FormAttribute("ButtonSettingsFormat", New TypeDescription("Number"), NameOfTheFieldList()));
	AttributesToBeAdded.Add(New FormAttribute("Value", New TypeDescription, NameOfTheFieldList()));
	AttributesToBeAdded.Add(New FormAttribute("Common", New TypeDescription("Boolean"), NameOfTheFieldList()));
	
	ChangeAttributes(AttributesToBeAdded);
	
	FieldList = Items[NameOfTheFieldList()];
	FieldList.Header = True;
	FieldList.SetAction("OnActivateRow", "Attachable_AvailableFieldsWhenLineIsActivated");
	
	ColumnNamePresentation = NameOfTheFieldList() + "Presentation";
	If Common.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaInternal = Common.CommonModule("FormulasConstructorInternal");
		ColumnNamePresentation = ModuleConstructorFormulaInternal.ColumnNamePresentation(NameOfTheFieldList());
	EndIf;
	
	ColumnPresentation = Items[ColumnNamePresentation];
	ColumnPresentation.Title = NStr("en = 'Field';");
	
	ColumnPattern = Items.Add(NameOfTheFieldList() + "Pattern", Type("FormField"), FieldList);
	ColumnPattern.DataPath = NameOfTheFieldList() + "." + "Pattern";
	ColumnPattern.Type = FormFieldType.InputField;
	ColumnPattern.Title = NStr("en = 'Preview';");
	ColumnPattern.SetAction("OnChange", "Attachable_SampleWhenChanging");
	ColumnPattern.ShowInFooter = False;
	
	ButtonSettingsFormat = Items.Add(NameOfTheFieldList() + "ButtonSettingsFormat", Type("FormField"), FieldList);
	ButtonSettingsFormat.DataPath = NameOfTheFieldList() + "." + "ButtonSettingsFormat";
	ButtonSettingsFormat.Type = FormFieldType.PictureField;
	ButtonSettingsFormat.ShowInHeader = True;
	ButtonSettingsFormat.HeaderPicture = PictureLib.DataCompositionOutputParameters;	
	ButtonSettingsFormat.ValuesPicture = PictureLib.DataCompositionOutputParameters;	
	ButtonSettingsFormat.Title = NStr("en = 'Configure format';");
	ButtonSettingsFormat.TitleLocation = FormItemTitleLocation.None;
	ButtonSettingsFormat.CellHyperlink = True;
	ButtonSettingsFormat.ShowInFooter = False;
		
	SetExamplesValues();
	SetFormatValuesDefault();
	SetUpFieldSample();
	MarkCommonFields();
	
	For Each AppearanceItem In ConditionalAppearance.Items Do
		For Each FormattedField In AppearanceItem.Fields.Items Do
			If FormattedField.Field = New DataCompositionField(NameOfTheFieldList() + "Presentation") Then
				FormattedField = AppearanceItem.Fields.Items.Add();
				FormattedField.Field = New DataCompositionField(NameOfTheFieldList() + "Pattern");
				FormattedField = AppearanceItem.Fields.Items.Add();
				FormattedField.Field = New DataCompositionField(NameOfTheFieldList() + "ButtonSettingsFormat");
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	// Color of the fields that are not common for the selected objects.
	
	AppearanceItem = ConditionalAppearance.Items.Add();
	
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(NameOfTheFieldList());
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField(NameOfTheFieldList() + ".Common");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;
	
	AppearanceItem.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);	
	
EndProcedure

&AtServer
Function FillListDisplayedFields(FieldsCollection, Result = Undefined)
	
	If Result = Undefined Then
		Result = New Array;
	EndIf;
	
	For Each Item In FieldsCollection.GetItems() Do
		If Not ValueIsFilled(Item.DataPath) Then
			Continue;
		EndIf;
		Result.Add(Item.DataPath);
		FillListDisplayedFields(Item, Result);
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SetExamplesValues(FieldsCollection = Undefined, PrintData = Undefined)
	
	If Not Common.SubsystemExists("StandardSubsystems.Print") Then
		Return;
	EndIf;
	
	ModulePrintManager = Common.CommonModule("PrintManagement");

	If FieldsCollection = Undefined Then
		FieldsCollection = ThisObject[NameOfTheFieldList()];
	EndIf;
	
	If PrintData = Undefined Then
		If Not ValueIsFilled(Pattern) Then
			Return;
		EndIf;
		Objects = CommonClientServer.ValueInArray(Pattern);
		DisplayedFields = FillListDisplayedFields(FieldsCollection);
		If Common.SubsystemExists("StandardSubsystems.Print") Then
			Try
				PrintData = ModulePrintManager.PrintData(Objects, DisplayedFields, CurrentLanguage);
			Except
				UnlockDataForEdit(KeyOfEditObject, UUID);
				Raise ErrorProcessing.DetailErrorDescription(ErrorInfo());
			EndTry;
			GetUserMessages(True);
		Else
			Return;
		EndIf;
	EndIf;
	
	ModulePrintManager.SetExamplesValues(FieldsCollection, PrintData, Pattern);
	
EndProcedure

&AtServer
Procedure SetFormatValuesDefault(FieldsCollection = Undefined)
	
	If FieldsCollection = Undefined Then
		FieldsCollection = ThisObject[NameOfTheFieldList()];
	EndIf;
	
	For Each Item In FieldsCollection.GetItems() Do
		If Not ValueIsFilled(Item.DataPath) Then
			Continue;
		EndIf;
		
		If Not ValueIsFilled(Item.DefaultFormat) Then
			Item.DefaultFormat = DefaultFormat(Item.Type);
		EndIf;
		
		Item.Format = Item.DefaultFormat;
		
		If ValueIsFilled(Item.Format) Then
			Item.Pattern = Format(Item.Pattern, Item.Format);
		Else
			Item.ButtonSettingsFormat = -1;
		EndIf;
			
		SetFormatValuesDefault(Item);
	EndDo;
	
EndProcedure

&AtServer
Function DefaultFormat(TypeDescription)
	
	Format = "";
	If TypeDescription.Types().Count() <> 1 Then
		Return Format;
	EndIf;
	
	Type = TypeDescription.Types()[0];
	
	If Type = Type("Number") Then
		Format = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'ND=%1; NFD=%2';"),
			TypeDescription.NumberQualifiers.Digits,
			TypeDescription.NumberQualifiers.FractionDigits);
	ElsIf Type = Type("Date") Then
		If TypeDescription.DateQualifiers.DateFractions = DateFractions.Date Then
			Format = NStr("en = 'DLF=D';");
		Else
			Format = NStr("en = 'DLF=DT';");
		EndIf;
	ElsIf Type = Type("Boolean") Then
		Format = NStr("en = 'BF=No; BT=Yes';");
	EndIf;
	
	Return Format;
	
EndFunction

&AtServer
Function LayoutOwner()
	
	If ValueIsFilled(LayoutOwner) Then
		Return Common.MetadataObjectByID(LayoutOwner);
	EndIf;
	
	TemplatePath = IdentifierOfTemplate;
	
	PathParts = StrSplit(TemplatePath, ".", True);
	If PathParts.Count() <> 2 And PathParts.Count() <> 3 Then
		Return Undefined;
	EndIf;
	
	If PathParts.Count() <> 3 Then
		Return Undefined;
	EndIf;
	
	PathParts.Delete(PathParts.UBound());
	ObjectName = StrConcat(PathParts, ".");
	
	If IsBlankString(ObjectName) Then
		Return Undefined;
	EndIf;
	
	Return Common.MetadataObjectByFullName(ObjectName);
	
EndFunction

&AtServerNoContext
Function FieldsCollections(DataSources, EditParameters)
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		Try
			Return ModulePrintManager.CollectionOfDataSourcesFields(DataSources);
		Except
			UnlockDataForEdit(EditParameters.KeyOfEditObject, EditParameters.UUID);
			Raise ErrorProcessing.DetailErrorDescription(ErrorInfo());
		EndTry
	EndIf;

	Return New Array;
	
EndFunction

&AtClient
Procedure OnSelectingLayoutName(NewTemplateName, AdditionalParameters) Export
	
	If NewTemplateName = Undefined Then
		Return;
	EndIf;
	
	If DocumentName <> NewTemplateName Then
		Modified = True;
		DocumentName = NewTemplateName;
		SetHeader();
	EndIf;
	
EndProcedure

&AtServer
Function ListOfOperators()
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
				
		ModulePrintManager = Common.CommonModule("PrintManagement");
		
		AdditionalFields = New Structure;
		
		DetailsOfAdditionalFields = New Structure("Presentation, Type");
		DetailsOfAdditionalFields.Presentation = NStr("en = 'Condition start';");
		DetailsOfAdditionalFields.Type = New TypeDescription("Boolean");
		AdditionalFields.Insert("AreaStart", DetailsOfAdditionalFields);
		
		DetailsOfAdditionalFields = New Structure("Presentation, Type");
		DetailsOfAdditionalFields.Presentation = NStr("en = 'Condition end';");
		DetailsOfAdditionalFields.Type = New TypeDescription("Boolean");
		AdditionalFields.Insert("EndOfRegion", DetailsOfAdditionalFields);
		
		
		AdditionalFieldsGroupDetails = New Structure("Presentation, Order, Picture");
		AdditionalFieldsGroupDetails.Insert("Items", AdditionalFields);
		AdditionalFieldsGroupDetails.Presentation = NStr("en = 'Conditional display';");
		AdditionalFieldsGroupDetails.Order = 7;
		
		GroupsOfAdditionalFields = New Structure;
		GroupsOfAdditionalFields.Insert("ConditionalOutput", AdditionalFieldsGroupDetails);
		
		Return ModulePrintManager.ListOfOperators(GroupsOfAdditionalFields);
	EndIf;
	
EndFunction

&AtClient
Function TagNameCondition()
	Return PrintManagementClientServer.TagNameCondition();
EndFunction

#Region PlugInListOfFields

&AtClient
Procedure Attachable_ListOfFieldsBeforeExpanding(Item, String, Cancel)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaClient = CommonClient.CommonModule("FormulasConstructorClient");
		ModuleConstructorFormulaClient.ListOfFieldsBeforeExpanding(ThisObject, Item, String, Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ExpandTheCurrentFieldListItem()
	
	If CommonClient.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaClient = CommonClient.CommonModule("FormulasConstructorClient");
		ModuleConstructorFormulaClient.ExpandTheCurrentFieldListItem(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_FillInTheListOfAvailableFields(FillParameters) Export // ACC:78 - Called from FormulaConstructorClient.
	
	FillInTheListOfAvailableFields(FillParameters);
	
EndProcedure

&AtServer
Procedure FillInTheListOfAvailableFields(FillParameters)
	
	If Common.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormula = Common.CommonModule("FormulasConstructor");
		ModuleConstructorFormula.FillInTheListOfAvailableFields(ThisObject, FillParameters);
	
		CurrentData = ThisObject[NameOfTheFieldList()].FindByID(FillParameters.RowID);
		SetExamplesValues(CurrentData);
		SetFormatValuesDefault(CurrentData);
		If (CurrentData.Folder Or CurrentData.Table) And CurrentData.GetParent() = Undefined Then
			MarkCommonFields(CurrentData);
		Else
			SetCommonFIeldFlagForSubordinateFields(CurrentData);
		EndIf;		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ListOfFieldsStartDragging(Item, DragParameters, Perform)
	
	Attribute = ThisObject[NameOfTheFieldList()].FindByID(DragParameters.Value);
	
	If Attribute.Folder Or Attribute.Table 
		And Not StrStartsWith(Attribute.DataPath, "CommonAttributes.") Then
		Perform = False;
		Return;
	EndIf;
	
	DragParameters.Value = "[" + Attribute.RepresentationOfTheDataPath + "]";

	If Item = Items[NameOfTheFieldList()]
		And ValueIsFilled(Attribute.Format) And Attribute.Format <> Attribute.DefaultFormat Then
		
		DragParameters.Value = StringFunctionsClientServer.SubstituteParametersToString(
			"[Format(%1, %2)]", DragParameters.Value, """" + Attribute.Format + """");
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_SearchStringEditTextChange(Item, Text, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaClient = CommonClient.CommonModule("FormulasConstructorClient");
		ModuleConstructorFormulaClient.SearchStringEditTextChange(ThisObject, Item, Text, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PerformASearchInTheListOfFields()
	
	PerformASearchInTheListOfFields();
	
EndProcedure

&AtServer
Procedure PerformASearchInTheListOfFields()
	
	If Common.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormula = Common.CommonModule("FormulasConstructor");
		ModuleConstructorFormula.PerformASearchInTheListOfFields(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_SearchStringClearing(Item, StandardProcessing)
	
	FormulasConstructorClient.SearchStringClearing(ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtServer
Procedure Attachable_FormulaEditorHandlerServer(Parameter, AdditionalParameters)
	If Common.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormula = Common.CommonModule("FormulasConstructor");
		ModuleConstructorFormula.FormulaEditorHandler(ThisObject, Parameter, AdditionalParameters);
	EndIf;
	
	If AdditionalParameters.OperationKey = "HandleSearchMessage" Then
		MarkCommonFields();
		SetFormatValuesDefault();
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_FormulaEditorHandlerClient(Parameter, AdditionalParameters = Undefined) Export  // ACC:78 - Procedure is called from FormulaConstructorClient.StartSearchInFieldsList.
	If CommonClient.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaClient = CommonClient.CommonModule("FormulasConstructorClient");
		ModuleConstructorFormulaClient.FormulaEditorHandler(ThisObject, Parameter, AdditionalParameters);
		If AdditionalParameters <> Undefined And AdditionalParameters.RunAtServer Then
			Attachable_FormulaEditorHandlerServer(Parameter, AdditionalParameters);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_StartSearchInFieldsList()

	If CommonClient.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaClient = CommonClient.CommonModule("FormulasConstructorClient");
		ModuleConstructorFormulaClient.StartSearchInFieldsList(ThisObject);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function NameOfTheFieldList()
	
	Return "AvailableFields";
	
EndFunction

&AtClientAtServerNoContext
Function NameOfTheListOfOperators()
	
	Return "ListOfOperators";
	
EndFunction

#EndRegion


#Region AdditionalHandlersForConnectedLists

&AtClient
Procedure Attachable_AvailableFieldsWhenLineIsActivated(Item)
	
	CurrentData = Items[NameOfTheFieldList()].CurrentData;

	If CurrentData.GetParent() = Undefined Then
		Items["SearchString" + NameOfTheFieldList()].InputHint = PromptInputStringSearchFieldList();
	Else
		Items["SearchString" + NameOfTheFieldList()].InputHint = CurrentData.RepresentationOfTheDataPath;
	EndIf;
	
	PopulateHTMLFIeldByCurrField();
	
EndProcedure

&AtClient
Procedure PopulateHTMLFIeldByCurrField()
	
	Value = GetCurrentRowValue();
	
	SetInHTMLField(Value);
	
EndProcedure

&AtClient
Function GetCurrentRowValue()
	CurrentRow = Items[NameOfTheFieldList()].CurrentRow; 	
	Attribute = ThisObject[NameOfTheFieldList()].FindByID(CurrentRow);
	
	If Attribute.Folder Or Attribute.Table 
		And Not StrStartsWith(Attribute.DataPath, "CommonAttributes.") Then
		Return "";
	EndIf;
	
	Value = "[" + Attribute.RepresentationOfTheDataPath + "]";

	If CurrentItem = Items[NameOfTheFieldList()]
		And ValueIsFilled(Attribute.Format) And Attribute.Format <> Attribute.DefaultFormat Then
		
		Value = StringFunctionsClientServer.SubstituteParametersToString(
			"[Format(%1, %2)]", Value, """" + Attribute.Format + """");
	EndIf;
	
	Return Value;
	
EndFunction

&AtClient
Procedure Attachable_AvailableFieldsBeforeStartOfChange(Item, Cancel)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaClient = CommonClient.CommonModule("FormulasConstructorClient");
		
		CurrentData = Items[NameOfTheFieldList()].CurrentData;
		CurrentData.Pattern = CurrentData.Value;
		InputField = Items[NameOfTheFieldList() + "Pattern"];
		SelectedField = ModuleConstructorFormulaClient.TheSelectedFieldInTheFieldList(ThisObject, NameOfTheFieldList());
		InputField.TypeRestriction = SelectedField.Type;
		
	EndIf;
	
EndProcedure

// Parameters:
//  Item - FormTable
//  RowSelected - Number
//  Field - FormField
//  StandardProcessing - Boolean
//
&AtClient
Procedure Attachable_ListOfFieldsSelection(Item, RowSelected, Field, StandardProcessing)
	
	ModuleConstructorFormulaClient = Undefined;
	If CommonClient.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaClient = CommonClient.CommonModule("FormulasConstructorClient");
	Else
		Return;
	EndIf;
	
	If Field.Name = Item.Name + "Presentation" Then
		StandardProcessing = False;
		SelectedField = ModuleConstructorFormulaClient.TheSelectedFieldInTheFieldList(ThisObject);
		If ValueIsFilled(CurrentValue) Then
			CurrentValue = TrimR(CurrentValue) + " ";
		Else
			CurrentValue = "";
		EndIf;
		If Item.Name = NameOfTheFieldList() Then
			CurrentValue = CurrentValue + "[" + SelectedField.RepresentationOfTheDataPath + "]";
		Else
			CurrentValue = CurrentValue + ModuleConstructorFormulaClient.ExpressionToInsert(SelectedField);
		EndIf;
	EndIf;
	
	If Field = Items[NameOfTheFieldList() + "ButtonSettingsFormat"] Then
		StandardProcessing = False;
		Designer = New FormatStringWizard(Items[NameOfTheFieldList()].CurrentData.Format);
		Designer.AvailableTypes = Items[NameOfTheFieldList()].CurrentData.Type;
		NotifyDescription = New NotifyDescription("WhenFormatFieldSelection", ThisObject);
		Designer.Show(NotifyDescription);
	EndIf;	
	
EndProcedure

&AtClient
Procedure Attachable_FieldListRowActivation(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaClient = CommonClient.CommonModule("FormulasConstructorClient");
		
		Operator = ModuleConstructorFormulaClient.TheSelectedFieldInTheFieldList(ThisObject, NameOfTheListOfOperators());
		
		If ValueIsFilled(Operator.Parent) Then
			OperatorsGroup = Operator.Parent; // See FormulasConstructorClient.TheSelectedFieldInTheFieldList
			OperatorGroupName = OperatorsGroup.Name;
			
			If OperatorGroupName = "ConditionalOutput" Then
				If Operator.Name = "AreaStart" Then
					SetInHTMLField(StrTemplate("{%1 *text conditions*}", TagNameCondition()));
				ElsIf Operator.Name = "EndOfRegion" Then
					SetInHTMLField(StrTemplate("{/%1}", TagNameCondition()));
				EndIf;
				Return;
			EndIf;
		EndIf;
		
		SetInHTMLField(ModuleConstructorFormulaClient.ExpressionToInsert(Operator));
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_OperatorsDragStart(Item, DragParameters, Perform)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaClient = CommonClient.CommonModule("FormulasConstructorClient");
		
		Operator = ModuleConstructorFormulaClient.TheSelectedFieldInTheFieldList(ThisObject, NameOfTheListOfOperators());
		
		If ValueIsFilled(Operator.Parent) Then
			OperatorsGroup = Operator.Parent; // See FormulasConstructorClient.TheSelectedFieldInTheFieldList
			OperatorGroupName = OperatorsGroup.Name;
			
			If OperatorGroupName = "ConditionalOutput" Then
				If Operator.Name = "AreaStart" Then
					DragParameters.Value = "{v8 Condition *text conditions*}";
				ElsIf Operator.Name = "EndOfRegion" Then
					DragParameters.Value = "{/v8 Condition}";
				EndIf;
				Return;
			EndIf;
		EndIf;
		
		DragParameters.Value = ModuleConstructorFormulaClient.ExpressionToInsert(Operator);
		
		If Operator.DataPath = "PrintControl_NumberofLines" Then
			CurrentTablePresentation = CurrentTablePresentation();
			Perform = CurrentTablePresentation <> Undefined;
			DragParameters.Value = StrReplace(DragParameters.Value, "()", "(["+CurrentTablePresentation+"])");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_AvailableFieldsAtEndOfEditing(Item, NewRow, CancelEdit)
	
	CurrentData = Items[NameOfTheFieldList()].CurrentData;
	If ValueIsFilled(CurrentData.Format) Then
		CurrentData.Pattern = Format(CurrentData.Value, CurrentData.Format);
	EndIf;

	If CurrentData.DataPath = "Ref" Then
		Pattern = CurrentData.Pattern;
	EndIf;
	AttachIdleHandler("WhenChangingSample", 0.1,  True);
	
EndProcedure

&AtClient
Procedure Attachable_SampleWhenChanging(Item)
	
	CurrentData = Items[NameOfTheFieldList()].CurrentData;
	CurrentData.Value = CurrentData.Pattern;
	
EndProcedure

&AtClient
Procedure WhenChangingSample()

	WhenChangingSampleOnServer();
	
EndProcedure

&AtServer
Procedure WhenChangingSampleOnServer()
	
	SetExamplesValues();
		
EndProcedure

#EndRegion

#EndRegion


&AtClientAtServerNoContext
Function PromptInputStringSearchFieldList()
	
	Return NStr("en = 'Find field…';");
	
EndFunction

&AtServer
Function GetPrintForm()
	
	References = CommonClientServer.ValueInArray(Pattern);
	PrintObjects = New ValueList;
	Template = GetFromTempStorage(TemplateFileAddress);
	PrepareTemplateForSaving(Template);
	PrintParameters = New Structure;
		
	OfficeDocuments = PrintManagement.GenerateOfficeDoc(Template, References, PrintObjects, LanguageCode, PrintParameters);
	If OfficeDocuments.Count() > 0 Then
		For Each OfficeDocument In OfficeDocuments Do
			Return OfficeDocument;
		EndDo;
	Else 
		Return Undefined;
	EndIf;
	
EndFunction

&AtClient
Function CurrentTablePresentation()
	For Each AttachedFieldList In ThisObject["ConnectedFieldLists"] Do
		If AttachedFieldList.NameOfTheFieldList <> NameOfTheListOfOperators() Then
			If Items[AttachedFieldList.NameOfTheFieldList].CurrentData <> Undefined
				And Items[AttachedFieldList.NameOfTheFieldList].CurrentData.Table Then
					Return Items[AttachedFieldList.NameOfTheFieldList].CurrentData.RepresentationOfTheDataPath;
			EndIf;			
		EndIf;
	EndDo;	
	Return Undefined;
EndFunction

&AtClient
Procedure TemplateAssignmentClick(Item)
	
	PickingParameters = StandardSubsystemsClientServer.MetadataObjectsSelectionParameters();
	PickingParameters.SelectedMetadataObjects = CommonClient.CopyRecursive(DataSources);
	PickingParameters.ChooseRefs = True;
	PickingParameters.Title = NStr("en = 'Template assignment';");
	PickingParameters.FilterByMetadataObjects = ObjectsWithPrintCommands();
	
	NotifyDescription = New NotifyDescription("OnChooseTemplateOwners", ThisObject);
	StandardSubsystemsClient.ChooseMetadataObjects(PickingParameters, NotifyDescription);

EndProcedure

&AtClient
Procedure OnChooseTemplateOwners(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	DataSources.LoadValues(Result.UnloadValues());
	Items.TextAssignment.Title = PresentationOfDataSource(DataSources);
	UpdateListOfAvailableFields();
	
EndProcedure

&AtClientAtServerNoContext
Function PresentationOfDataSource(DataSources)
	
	Values = New Array;
	For Each Item In DataSources Do
		Values.Add(Item.Value);
	EndDo;
	
	Result = StrConcat(Values, ", ");
	If Not ValueIsFilled(Result) Then
		Result = "<" + NStr("en = 'not selected';") + ">";
	EndIf;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function ObjectsWithPrintCommands()
	
	ObjectsWithPrintCommands = New ValueList;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		For Each MetadataObject In ModulePrintManager.PrintCommandsSources() Do
			ObjectsWithPrintCommands.Add(MetadataObject.FullName());
		EndDo;
	EndIf;

	Return ObjectsWithPrintCommands;
	
EndFunction

&AtServer
Procedure UpdateListOfAvailableFields()
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.UpdateListOfAvailableFields(ThisObject, 
			FieldsCollections(DataSources.UnloadValues(), EditParameters()), NameOfTheFieldList());
		
		SetUpFieldSample();
		MarkCommonFields();
		SetFormatValuesDefault();
			
		If DataSources.Count() > 0 Then
			DataSource = DataSources[0].Value;
			MetadataObject = Common.MetadataObjectByID(DataSource);
			PickupSample(MetadataObject);
			SetExamplesValues();
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetUpFieldSample()

	FieldsCollection = ThisObject[NameOfTheFieldList()].GetItems(); // FormDataTreeItemCollection
	Offset = 0;
	For Each FieldDetails In FieldsCollection Do
		If FieldDetails.DataPath = "Ref" Then
			FieldDetails.Title = NStr("en = 'Preview';");
			If Offset <> 0 Then
				IndexOf = FieldsCollection.IndexOf(FieldDetails);
				FieldsCollection.Move(IndexOf, Offset);
			EndIf;
			Break;
		EndIf;
		Offset = Offset - 1;
	EndDo;
	
EndProcedure

&AtServer
Function CommonFieldsOfDataSources()
	
	CommonFieldsOfDataSources = New Array;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		CommonFieldsOfDataSources = ModulePrintManager.CommonFieldsOfDataSources(DataSources.UnloadValues());
	EndIf;
	
	Return CommonFieldsOfDataSources;
	
EndFunction

&AtServer
Procedure MarkCommonFields(Val FieldsCollection = Undefined, Val CommonFields = Undefined)
	
	If FieldsCollection = Undefined Then
		FieldsCollection = ThisObject[NameOfTheFieldList()];
	EndIf;
	
	If CommonFields = Undefined Then
		CommonFields = CommonFieldsOfDataSources();
	EndIf;
	
	For Each FieldDetails In FieldsCollection.GetItems() Do
		If FieldDetails.Folder And FieldDetails.Field = New DataCompositionField("CommonAttributes")
			Or FieldDetails.GetParent() <> Undefined And FieldDetails.GetParent().Field = New DataCompositionField("CommonAttributes") Then
			FieldDetails.Common = True;
			SetCommonFIeldFlagForSubordinateFields(FieldDetails);
			Continue;
		EndIf;
		
		If CommonFields.Find(FieldDetails.Field) <> Undefined Then
			FieldDetails.Common = True;
			If Not FieldDetails.Folder And Not FieldDetails.Table Then
				SetCommonFIeldFlagForSubordinateFields(FieldDetails);
			EndIf;
		EndIf;
		If FieldDetails.Common And (FieldDetails.Folder Or FieldDetails.Table) Then
			MarkCommonFields(FieldDetails, CommonFields);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetCommonFIeldFlagForSubordinateFields(FieldsCollection)
	
	For Each FieldDetails In FieldsCollection.GetItems() Do
		FieldDetails.Common = FieldsCollection.Common;
		SetCommonFIeldFlagForSubordinateFields(FieldDetails);
	EndDo;
	
EndProcedure

&AtClient
Procedure SetUpCommandPresentation()
	
	Items.WriteAndClose.Visible = Not EditingDenied;
	Items.Close.Visible = EditingDenied;
	Items.Write.Enabled = Not EditingDenied;
	Items.Translate.Enabled = Not EditingDenied;
	Items.TranslateAllActions.Enabled = Items.Translate.Enabled;
	Items.Rename.Enabled = Not EditingDenied;
	Items.DeleteLayoutLanguage.Enabled = Not EditingDenied;
	Items.LoadFromFile.Enabled = Not EditingDenied;
	SetAvailabilityRecursively(Items.LangsToAdd, Not EditingDenied);
	
EndProcedure

&AtClient
Procedure SetAvailabilityRecursively(Item, Var_Enabled = Undefined)
	If Var_Enabled = Undefined Then
		Var_Enabled = Item.Enabled;
	EndIf;
	
	For Each SubordinateItem In Item.ChildItems Do
		If TypeOf(SubordinateItem) = Type("FormButton") And SubordinateItem.CommandName <> "" Then
			SubordinateItem.Enabled = Var_Enabled;
		EndIf;
		
		If TypeOf(SubordinateItem) = Type("FormGroup") Then
			SetAvailabilityRecursively(SubordinateItem, Var_Enabled);
		EndIf;
	EndDo;
EndProcedure

&AtServer
Function EditParameters()
	Result = New Structure;
	Result.Insert("KeyOfEditObject", KeyOfEditObject);
	Result.Insert("UUID", UUID);
	Return Result;
EndFunction

#EndRegion



