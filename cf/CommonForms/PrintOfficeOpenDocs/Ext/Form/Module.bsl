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
Var CombinedDocStructure;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If IsTempStorageURL(Parameters.PrintFormSettingsAddress) Then
		PrintFormSettingsIncoming = GetFromTempStorage(Parameters.PrintFormSettingsAddress);
	Else
		PrintFormSettingsIncoming = FormAttributeToValue("PrintFormsSettings", Type("ValueTable"));
	EndIf;		
	
	OutputParameters = Parameters.OutputParameters;
	If OutputParameters = Undefined Then
		OutputParameters = PrintManagement.PrepareOutputParametersStructure();
	EndIf;
	
	If IsTempStorageURL(Parameters.CombinedDocStructureAddress) Then
		CombinedDocStructureAddress = Parameters.CombinedDocStructureAddress;
	EndIf;
	
	TableOfPrintedForms 		= FormAttributeToValue("PrintForms", Type("ValueTable"));
	
	SettingsOfGeneratedPrintForms = New Map;
		
	For Each PrintFormSetting In PrintFormSettingsIncoming Do
		PrintFormsOfDoc = Common.ValueFromXMLString(PrintFormSetting.OfficeDocuments);
		For Each PrintForm In PrintFormsOfDoc Do
			If IsTempStorageURL(PrintForm.Key) Then
				SpecifiedPrintFormsNames = Common.ValueFromXMLString(PrintFormSetting.PrintFormFileName);
				PrintFormPresentation = PrintManagement.ObjectPrintFormFileName(PrintForm.Value, SpecifiedPrintFormsNames, PrintFormSetting.Name1);
				AddPrintedForm(TableOfPrintedForms, PrintFormSetting, PrintForm, PrintFormPresentation);
				SettingsStructure_ = New Structure("SignatureAndSeal, Check, CurrentLanguage");
				FillPropertyValues(SettingsStructure_, PrintFormSetting);
				SettingsOfGeneratedPrintForms.Insert(PrintForm.Key, SettingsStructure_);
				NewSetting = PrintFormsSettings.Add();
				FillPropertyValues(NewSetting, PrintFormSetting,,"OfficeDocuments");
				OfficeDocuments = New Map;
				OfficeDocuments.Insert(PrintForm.Key, PrintForm.Value);
				NewSetting.OfficeDocuments = Common.ValueToXMLString(OfficeDocuments);
			EndIf;
		EndDo;
	EndDo;
	
	If Common.IsMobileClient() Then
		Items.Help.Visible = False;
	ElsIf PrintFormsSettings.Count() = 1 Then
		Instruction = GetInstructionText(TableOfPrintedForms[0].Presentation, TableOfPrintedForms[0].PrintFormAddress);
	Else
		Instruction = GetInstructionText();
	EndIf;
	
	TableOfPrintedForms.FillValues(0, "Picture");
	
	ValueToFormData(TableOfPrintedForms, PrintForms);
	CustomizeForm(PrintFormsSettings.Count());
	
	AdditionalInformation = New Structure("Picture, Text", New Picture, "");
	
	TableOfPrintObjects = PrintForms.Unload(,"PrintObject");
	ReferencesArrray = TableOfPrintObjects.UnloadColumn("PrintObject");
	PrintObjects.LoadValues(ReferencesArrray);
	
	ReferencesArrray = PrintObjects.UnloadValues();
	
	// OnlineInteraction
	If TypeOf(ReferencesArrray) = Type("Array")
		And ReferencesArrray.Count() > 0
		And Common.RefTypeValue(ReferencesArrray[0]) Then
			If Common.SubsystemExists("ElectronicInteraction") Then 
				ModuleOnlineInteraction = Common.CommonModule("ElectronicInteraction");
				ModuleOnlineInteraction.WhenDisplayingNavigationLinkInFormOfInformationSecurityObject(AdditionalInformation, ReferencesArrray);
			EndIf;
	EndIf;
	// End OnlineInteraction
	
	Items.AdditionalInformation.Title = StringFunctions.FormattedString(AdditionalInformation.Text);
	Items.PictureOfInformation.Picture = AdditionalInformation.Picture;
	Items.AdditionalInformationGroup.Visible = Not IsBlankString(Items.AdditionalInformation.Title);
	Items.PictureOfInformation.Visible = Items.PictureOfInformation.Picture.Type <> PictureType.Empty;
	
	PrintManagement.PrintDocumentsOnCreateAtServer(ThisObject, Cancel, StandardProcessing);
	
	If Common.IsMobileClient() Then
		Items.CommandBarLeftPart.Visible = False;
		Items.CommandBarRightPart.Visible = False;
		Items.PrintForms.TitleLocation = FormItemTitleLocation.Auto;
		Items.SendButtonAllActions.DefaultButton = True;
		Items.Help.LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
		Items.ChangeTemplateButton.Visible = False;
		Items.SignedAndSealedFlag.TitleLocation = FormItemTitleLocation.Auto;
		Items.MergeDocsFlag.TitleLocation = FormItemTitleLocation.Auto;
		Items.GroupCommandBar.Group = ChildFormItemsGroup.Vertical;
		Items.ConfigureSignatureAndStamp.Group = ChildFormItemsGroup.Vertical;
		Items.PrintForms.Header = False;
		Items.DontShowAgain.Visible = False;
		DontShowAgain = False;
		Items.InstructionGroup_.Visible = False;
		Items.Move(Items.Show, Items.MoreCommandBar, Items.SaveButtonAllActions);
		Items.Show.LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
		
		Items.PrintFormsSetFlags.LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
		Items.PrintFormsClearFlags.LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
		Items.Move(Items.PrintFormsSetFlags, Items.MoreCommandBar);
		Items.Move(Items.PrintFormsClearFlags, Items.MoreCommandBar);
		
		Items.GoToTemplatesManagement.Visible = False;
		
	Else
		DontShowAgain = Common.CommonSettingsStorageLoad("PrintOfficeOpenDocs",
		"OutputImmediately", True);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.Print") Then
		PrintManagementModuleNationalLanguageSupport = Common.CommonModule("PrintManagementNationalLanguageSupport");
		PrintManagementModuleNationalLanguageSupport.FillInTheLanguageSubmenu(ThisObject, , AvailablePrintFormLanguages());
	EndIf;
	
	Items.SignedAndSealedFlag.Visible = HasSignaturesAndSealsForPrintObjects();
	
	MergeDocs = Common.CommonSettingsStorageLoad("PrintOfficeOpenDocs",
		"AsCombinedDoc", False) And Items.MergeDocsFlag.Visible;
		
	SignatureAndSeal =  Common.CommonSettingsStorageLoad("PrintOfficeOpenDocs",
		"SignatureAndSeal", False);
	
	SetFormHeader();		
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If IsTempStorageURL(CombinedDocStructureAddress) Then
		CombinedDocStructure = GetFromTempStorage(CombinedDocStructureAddress);
	EndIf;
	
	If CombinedDocStructure = Undefined Then
		CombinedDocStructure = New Structure();
		CombinedDocStructure.Insert("PrintFormAddress", PutToTempStorage(Undefined, UUID));
		CombinedDocStructure.Insert("PrintFormFileName");
		CombinedDocStructure.Insert("Presentation");
		CombinedDocStructure.Insert("ContentOfCombinedDoc", New Map());
		
		If MergeDocs Then
			Notification = New NotifyDescription("OnCompleteGeneratingPrintForms", ThisObject);
			StartGettingPrintForms(CombinedDocStructure, Notification);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	For Each FileToDelete In ListOfFilesToDelete Do
		BeginDeletingFiles(New NotifyDescription, FileToDelete.Value);
	EndDo;
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	ChoiceParameters = New Structure("ValueSelected, ChoiceSource", ValueSelected, ChoiceSource);
	NotificationChoiceFollowUp = New NotifyDescription("SelectionProcessingFollowUp", ThisObject, ChoiceParameters);
	Notification = New NotifyDescription("OnCompleteGeneratingPrintForms", ThisObject, NotificationChoiceFollowUp);
	
	If IsReGenerationRequired Then
		StartGettingPrintForms(CombinedDocStructure, Notification);
	Else
		ExecuteNotifyProcessing(NotificationChoiceFollowUp);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_UserPrintTemplates" 
		And Source.FormOwner = ThisObject Then
			IsReGenerationRequired = True;
	ElsIf (EventName = "CancelTemplateChange"
		Or EventName = "CancelEditingOfficeDoc"
		And Source.FormOwner = ThisObject) Then
			LockForm();
	ElsIf EventName = "Write_OfficeDocument" And Source.FormOwner = ThisObject Then
			IsReGenerationRequired = True;
	EndIf;
	
	PrintManagementClientOverridable.PrintDocumentsNotificationProcessing(ThisObject, EventName, Parameter, Source);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Print(Command)
	ArrayOfPrintForms = PrintFormsWithMarks();
	If IsReGenerationRequired Then
		Notification = New NotifyDescription("PrintFollowUp", ThisObject, ArrayOfPrintForms);
		StartGettingPrintForms(CombinedDocStructure, Notification);
	Else
		PrintCompletion(ArrayOfPrintForms);
	EndIf;
EndProcedure	
	
&AtClient
Procedure Preview(Command)
	OpenMarkedPrintForms();
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	SetAllMarksAtServer(False);
EndProcedure

&AtClient
Procedure CheckAll(Command)
	SetAllMarksAtServer(True);
EndProcedure

&AtServer
Procedure SetAllMarksAtServer(Check)
	
	IsReGenerationRequired = True;
	
	ValueTable = PrintForms.Unload();
	
	ValueTable.FillValues(Check, "Check");
	
	PrintForms.Load(ValueTable);
	
EndProcedure

&AtClient
Procedure PrintFormsCheckBoxOnChange(Item)
	IsReGenerationRequired = True;
EndProcedure


&AtClient
Procedure OpenTemplateForEditing()
	
	PrintFormSetting = PrintFormsSettings[0];
	
	LockForm(True);
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("TemplateMetadataObjectName", PrintFormSetting.TemplatePath);
	OpeningParameters.Insert("Ref", RefTemplate(PrintFormSetting.TemplatePath));
	OpeningParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	OpeningParameters.Insert("DocumentName", PrintFormSetting.Presentation);
	OpeningParameters.Insert("TemplateType", "MXL");
	OpeningParameters.Insert("Edit", True);
	OpeningParameters.Insert("LanguageCode", StrSplit(CurrentLanguage, "_", True)[0]);
	
	OpenForm("CommonForm.EditOfficeOpenDoc", OpeningParameters, ThisObject, "PrintOfficeOpenDocs");
	
EndProcedure

&AtClient
Procedure ChangeTemplate(Command)
	OpenTemplateForEditing();
EndProcedure

&AtClient
Procedure GoToTemplatesManagement(Command)
	
	PrintManagementClient.GoToTemplate(PrintFormsSettings[0].TemplatePath);
	
EndProcedure

&AtClient
Procedure Save(Command)
	
	Notification = New NotifyDescription("WhenConnectingTheExtension", ThisObject);
	FileSystemClient.AttachFileOperationsExtension(Notification);
	
EndProcedure

&AtClient
Procedure Send(Command)
	SendPrintFormsByEmail();
EndProcedure

&AtClient
Procedure Attachable_SwitchLanguage(Command)
	
	PrintManagementClient.SwitchLanguage(ThisObject, Command);
	SetFormHeader();
	
EndProcedure

&AtClient
Procedure Attachable_WhenSwitchingTheLanguage(LanguageCode, AdditionalParameters) Export
	
	IsReGenerationRequired = True;
	
EndProcedure

&AtClient
Procedure MergeDocsOnChange(Item)
	IsReGenerationRequired = True;
	MergeDocsOnChangeAtServer(MergeDocs);
EndProcedure

&AtServerNoContext
Procedure MergeDocsOnChangeAtServer(Value)
	Common.CommonSettingsStorageSave("PrintOfficeOpenDocs",
		"AsCombinedDoc",	Value);
EndProcedure
	
&AtClient
Procedure SignedAndSealedFlagOnChange(Item)
	IsReGenerationRequired = True;
	FlagSignatureAndStampOnChangeAtServer(SignatureAndSeal);
EndProcedure

&AtServerNoContext
Procedure FlagSignatureAndStampOnChangeAtServer(Value)
	Common.CommonSettingsStorageSave("PrintOfficeOpenDocs",
		"SignatureAndSeal", Value);
EndProcedure

&AtClient
Procedure PrintFormsSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	SelectionRow = PrintForms.FindByID(RowSelected);
	
	ArrayOfPrintForms = New Array;
	AddPrintFormData(ArrayOfPrintForms, SelectionRow.PrintFormAddress, 
		SelectionRow.PrintFormFileName);
	
	OpenPrintForms(ArrayOfPrintForms);
EndProcedure

&AtClient
Procedure InstructionOnClick(Item, EventData, StandardProcessing)
	If EventData.Event.type = "click" And StrFind(EventData.Element.href, "OpenSinglePrintingForm") Then
		OpenPrintForms();
		StandardProcessing = False;
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure LockForm(Lock = False)
	
	GroupOfDocsDisplay = Items.DocumentsGroup;
	GroupOfDocsDisplay.ReadOnly = Lock;
	
EndProcedure

&AtServer
Procedure SetFormHeader()
	Var FormCaption;
	
	OutputParameters.Property("FormCaption", FormCaption);
	
	If Not ValueIsFilled(FormCaption) Then
		
		If PrintObjects.Count() > 1 Then
			FormCaption = NStr("en = 'Print documents';");
		ElsIf PrintObjects.Count() = 1 And Common.IsReference(TypeOf(PrintObjects[0].Value))
			And Common.ObjectAttributeValue(PrintObjects[0].Value, "Ref", True) <> Undefined Then
			FormCaption = String(PrintObjects[0].Value);
		Else
			FormCaption = NStr("en = 'Print document';");
		EndIf;
	EndIf;
	
	If ValueIsFilled(CurrentLanguage) Then 
		CurrentLanguagePresentation = Items["Language_"+CurrentLanguage].Title; 
		FormCaption = FormCaption + " ("+CurrentLanguagePresentation+")";
	EndIf;
	
	Title = FormCaption;
	
EndProcedure

&AtClient
Procedure OpenMarkedPrintForms(AdditionalParameters = Undefined) Export
	ArrayOfPrintForms = PrintFormsWithMarks();
	OpenPrintForms(ArrayOfPrintForms);
EndProcedure

&AtClient
Procedure OpenPrintForms(ArrayOfPrintForms = Undefined)
	If Not IsReGenerationRequired Then
		
		If ArrayOfPrintForms = Undefined Then
			ArrayOfPrintForms = GetPrintForms(CombinedDocStructure);
		EndIf;
		
		OpenPrintFormsCompletion(ArrayOfPrintForms);
	
	Else
		Notification = New NotifyDescription("OpenPrintFormsFollowUp", ThisObject, ArrayOfPrintForms);
		StartGettingPrintForms(CombinedDocStructure, Notification);
	EndIf;	
EndProcedure

&AtServer
Procedure CustomizeForm(PrintFormCount)
	MultiplePrintFormsMode = PrintFormCount > 1;
	
	If Not MultiplePrintFormsMode Then	
		Items.Show.Title = NStr("en = 'Show';");
	EndIf;
	
	Items.MergeDocsFlag.Visible = MultiplePrintFormsMode;
	Items.PrintForms.Visible = MultiplePrintFormsMode Or Common.IsMobileClient();
	Items.GroupDocListManagement.Visible = Items.PrintForms.Visible;
	
EndProcedure

&AtServerNoContext
Function GetInstructionText(Presentation = Undefined, PrintFormAddress = Undefined)

	 InstructionText = "<!DOCTYPE html PUBLIC ""-//W3C//DTD HTML 4.0 Transitional//EN"">
	 		|<html>
			|
			|<head></head>
			|<style type=""text/css"">
			|    .Text {
			|        font-family: Arial;
			|        orphans: 2;
			|        widows: 2;
			|        font-variant-ligatures: normal;
			|    }
			|
			|</style>
			|
			|<body class=""text"">
			|
			|    <div>
			|        <p><strong>%1</strong></p>
			|    </div>
			|    <div>
			|        <p><span>%2</span></p>
			|        </p>
			|    </div>
			|</body>
			|
			|</html>";
	
	
	If Presentation = Undefined Then	
		InstructionText = StringFunctionsClientServer.SubstituteParametersToString(InstructionText, NStr("en = 'The documents are generated and prepared for printing';"), NStr("en = 'You can open the document to view or send it to print.';"));
	Else
		InstructionText = StringFunctionsClientServer.SubstituteParametersToString(InstructionText, NStr("en = 'The document is generated and prepared for printing';"), "<a href=""OpenSinglePrintingForm"">"+Presentation+"</a>");
	EndIf;

	Return InstructionText;			
EndFunction

&AtClient
Function IdleParameters()
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.MessageText = NStr("en = 'The parameters for generating print forms are changed.';");
	IdleParameters.UserNotification.Show = False;
	IdleParameters.OutputIdleWindow = True;
	IdleParameters.Interval = 1;
	Return IdleParameters;

EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  ArrayOfPrintForms - Array
//
&AtClient
Procedure OpenPrintFormsFollowUp(Result, ArrayOfPrintForms) Export
	If Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
	Else
		CombinedDocStructure = GetFromTempStorage(Result.ResultAddress);
		ArrayOfPrintForms = GetPrintForms(CombinedDocStructure, ArrayOfPrintForms);
		OpenPrintFormsCompletion(ArrayOfPrintForms);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenPrintFormsCompletion(ArrayOfPrintForms)

	If MergeDocs And ArrayOfPrintForms.UBound() Then
		OpenOfficeDoc(CombinedDocStructure.PrintFormAddress, CombinedDocStructure.PrintFormFileName);
	Else
		For Each PrintForm In ArrayOfPrintForms Do
			OpenOfficeDoc(PrintForm.PrintFormAddress, PrintForm.PrintFormFileName);
		EndDo;
	EndIf;	

EndProcedure

&AtClient
Procedure OpenOfficeDoc(DocumentAddress, NameOfFileToOpen)
	AdditionalParameters = New Structure("DocumentAddress, CompletionHandler, NameOfFileToOpen");
	AdditionalParameters.DocumentAddress 			= DocumentAddress;
	AdditionalParameters.CompletionHandler	= Undefined;
	AdditionalParameters.NameOfFileToOpen		= NameOfFileToOpen;
	
	Notification = New NotifyDescription("OpenOfficeDocAfterTempDirObtained", ThisObject, AdditionalParameters);
	FileSystemClient.CreateTemporaryDirectory(Notification);
EndProcedure

// Continuation of the OpenOfficeDoc procedure.
&AtClient
Procedure OpenOfficeDocAfterTempDirObtained(DirectoryName, AdditionalParameters) Export
	
	Notification = New NotifyDescription("OpenAfterSavedAtClient", ThisObject, AdditionalParameters.CompletionHandler);
	SavingParameters = FileSystemClient.FileSavingParameters();
	SavingParameters.Interactively = False;
	
	NameOfFileToOpen = DirectoryName + GetPathSeparator() + CommonClientServer.ReplaceProhibitedCharsInFileName(AdditionalParameters.NameOfFileToOpen);
	FileSystemClient.SaveFile(Notification, AdditionalParameters.DocumentAddress, NameOfFileToOpen, SavingParameters);
	
EndProcedure

&AtClient
Procedure OpenAfterSavedAtClient(ObtainedFiles, CompletionHandler) Export
	If ObtainedFiles <> Undefined Then		
		PathToFile  = ObtainedFiles[0].FullName;
		FileName	= ObtainedFiles[0].Name;
		
		CompletionParameters = New Structure;
		CompletionParameters.Insert("CompletionHandler", CompletionHandler);
		CompletionParameters.Insert("PathToFile", PathToFile);
		CompletionParameters.Insert("FileName", FileName);
		
		FileOnHardDrive = New File(PathToFile);
		DetailsAfterSetReadOnly = New NotifyDescription("OpenFileCompletion", ThisObject, CompletionParameters);
		FileOnHardDrive.BeginSettingReadOnly(DetailsAfterSetReadOnly, Not CanEditPrintForms());
	EndIf;
	
	ExecuteNotifyProcessing(CompletionHandler);
EndProcedure

&AtClient
Procedure OpenFileCompletion(CompletionParameters) Export	
	CompletionHandler = CompletionParameters.CompletionHandler;
	PathToFile = CompletionParameters.PathToFile;
	FileName = CompletionParameters.FileName;
		
	FileOpeningParameters = FileSystemClient.FileOpeningParameters();
	FileSystemClient.OpenFile(PathToFile, CompletionHandler, FileName, FileOpeningParameters);
EndProcedure

&AtServer
Function CanEditPrintForms()
	Return Users.RolesAvailable("PrintFormsEdit");
EndFunction

&AtServer
Function GetPrintFormsLongRunningOperation(CombinedDocStructure)
	
	IsReGenerationRequired = False;
	TableOfPrintedForms = PrintForms.Unload();
	TableOfPrintedForms.Columns.Add("CreateAgain",  New TypeDescription("Boolean"));
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.WaitCompletion = 1;
	
	GenerationParameters = New Structure("RegenerateCombinedDoc", False);

	ContentOfCombinedDoc = CombinedDocStructure.ContentOfCombinedDoc; 
	
	For Each PrintFormSetting In TableOfPrintedForms Do
		
		PrintFormSetting.CreateAgain = PrintFormSetting.Check 
			And (SignatureAndSeal <> PrintFormSetting.SignatureAndSeal
			Or (CurrentLanguage <> PrintFormSetting.CurrentLanguage And CurrentLanguage <> ""));
			
		PrintFormSetting.SignatureAndSeal = SignatureAndSeal;
		PrintFormSetting.CurrentLanguage = CurrentLanguage; 
		
	EndDo;
	
	
	If GetFromTempStorage(CombinedDocStructure.PrintFormAddress) <> Undefined Then
		For Each PrintFormSetting In ContentOfCombinedDoc Do
			GeneratedPrintFormSetting  = TableOfPrintedForms.Find(PrintFormSetting.Key, "PrintFormAddress");
			If GeneratedPrintFormSetting = Undefined Then
				GenerationParameters.RegenerateCombinedDoc = True;
			Else
				
				For Each SettingParameter In PrintFormSetting.Value Do
					GenerationParameters.RegenerateCombinedDoc = GenerationParameters.RegenerateCombinedDoc 
				 		Or SettingParameter.Value <> GeneratedPrintFormSetting[SettingParameter.Key];
				EndDo;
				
				GenerationParameters.RegenerateCombinedDoc = GenerationParameters.RegenerateCombinedDoc 
				 		Or Not GeneratedPrintFormSetting.Check;
			EndIf;
		EndDo;
		
		ArrayOfFoundStrings = TableOfPrintedForms.FindRows(New Structure("Check", True));
		For Each FoundRow In ArrayOfFoundStrings Do
			GenerationParameters.RegenerateCombinedDoc = GenerationParameters.RegenerateCombinedDoc
				Or ContentOfCombinedDoc[FoundRow.PrintFormAddress] <> Undefined;
		EndDo; 
			 
		GenerationParameters.RegenerateCombinedDoc = MergeDocs And GenerationParameters.RegenerateCombinedDoc;
	Else
		GenerationParameters.RegenerateCombinedDoc = True;
	EndIf;
	
	OfficeDocuments = New Map();
	For Each PrintFormTableRow In TableOfPrintedForms Do
		OfficeDocuments.Insert(PrintFormTableRow.PrintFormAddress, GetFromTempStorage(PrintFormTableRow.PrintFormAddress));
	EndDo;
	TableOfPrintedForms.FillValues(0, "Picture");
	PrintForms.Load(TableOfPrintedForms);
	
	Return	TimeConsumingOperations.ExecuteFunction(ExecutionParameters, "PrintManagementInternal.GeneratePrintForms", TableOfPrintedForms, GenerationParameters, OfficeDocuments, CombinedDocStructure);
		
EndFunction

&AtServer
Function GetPrintForms(CombinedDocStructure, ArrayOfPrintFormsLimitation = Undefined)
	ArrayOfPrintForms = New Array;
	
	TableOfPrintedForms = FormAttributeToValue("PrintForms", Type("ValueTable"));
	
	If MergeDocs Then
		AddPrintFormData(ArrayOfPrintForms, CombinedDocStructure.PrintFormAddress, CombinedDocStructure.PrintFormFileName);
	Else
		If ArrayOfPrintFormsLimitation = Undefined Then
			For Each PrintFormString In TableOfPrintedForms Do
				If PrintFormString.Check Then
					AddPrintFormData(ArrayOfPrintForms, PrintFormString.PrintFormAddress, 
						PrintFormString.PrintFormFileName);
				EndIf;
			EndDo;
		Else
			For Each PrintFormString In ArrayOfPrintFormsLimitation Do
				AddPrintFormData(ArrayOfPrintForms, PrintFormString.PrintFormAddress, 
					PrintFormString.PrintFormFileName);
			EndDo;
		EndIf;
	EndIf;
	
	Return ArrayOfPrintForms;
EndFunction

&AtServer
Function PrintFormsWithMarks()
		
	TableOfPrintedForms = PrintForms.Unload();
	
	ArrayOfFoundStrings = TableOfPrintedForms.FindRows(New Structure("Check", True));
	If ArrayOfFoundStrings.Count()  <> 0 Then
		ArrayOfPrintForms = New Array();
		For Each PrintFormString In ArrayOfFoundStrings Do
			AddPrintFormData(ArrayOfPrintForms, PrintFormString.PrintFormAddress, 
				PrintFormString.PrintFormFileName);
		EndDo;
		Return ArrayOfPrintForms;
	Else
		Return New Array
	EndIf;
EndFunction

&AtServer
Procedure AddPrintFormData(ArrayOfPrintForms, Val PrintFormAddress, Val PrintFormFileName)
	PrintForm = New Structure("PrintFormAddress, Presentation, PrintFormFileName");
	PrintForm.PrintFormAddress 	= PrintFormAddress;
	PrintForm.Presentation 		= PrintFormFileName;
	PrintForm.PrintFormFileName = PrintFormFileName;
	ArrayOfPrintForms.Add(PrintForm);
EndProcedure

&AtServer
Function RefTemplate(TemplateMetadataObjectName)
	
	Return Catalogs.PrintFormTemplates.RefTemplate(TemplateMetadataObjectName);
	
EndFunction

&AtServer
Function HasSignaturesAndSealsForPrintObjects()
	
	Result = False;
	
	ObjectsSignaturesAndSeals = PrintManagement.ObjectsSignaturesAndSeals(PrintObjects);
	For Each ObjectSignaturesAndSeals In ObjectsSignaturesAndSeals Do
		SignaturesAndSealsCollection = ObjectSignaturesAndSeals.Value;
		For Each SignatureSeal In SignaturesAndSealsCollection Do
			Picture = SignatureSeal.Value; // Picture
			If Picture.Type <> PictureType.Empty Then
				Return True;
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  ContinuationHandler - NotifyDescription, Undefined
//
&AtClient
Procedure OnCompleteGeneratingPrintForms(Result, ContinuationHandler) Export

	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
		Return;
	EndIf;
	CombinedDocStructure = GetFromTempStorage(Result.ResultAddress);

	If ContinuationHandler <> Undefined Then
		ExecuteNotifyProcessing(ContinuationHandler);		
	EndIf;

EndProcedure

&AtClient
Procedure SelectionProcessingFollowUp(Result, ChoiceParameters) Export
	
	ValueSelected = CommonClient.CopyRecursive(ChoiceParameters.ValueSelected);
	ChoiceSource = ChoiceParameters.ChoiceSource;
		
	If Not ValueSelected.Property("PrintObject") Then
		ChoiceFormOwner = ChoiceSource.FormOwner;
		ListOfPrintObjects = ChoiceFormOwner.PrintObjects;
		ValueSelected.Insert("PrintObject", ListOfPrintObjects[0].Value);
	EndIf;
	
	SavingOption = Undefined;
	ValueSelected.Property("SavingOption", SavingOption);
	AttachmentsList = Undefined;
	If MergeDocs And SavingOption <> "Join" Then  
		Attachment = FileDetails(CombinedDocStructure.PrintFormFileName);
		Attachment.AddressInTempStorage = CombinedDocStructure.PrintFormAddress;
		Attachment.PrintObject	= ValueSelected.PrintObject;
		AttachmentsList = New Array;
		AttachmentsList.Add(Attachment);
	EndIf;
	ValueSelected.Insert("AttachmentsList", AttachmentsList);
	
	FilesInTempStorage = PutOfficeDocsToTempStorage(ValueSelected,,True);
	
	If ValueSelected.Sign Then
		
		If Upper(ChoiceSource.FormName) = Upper("CommonForm.SavePrintForm") Then
			If ValueSelected.SavingOption = "Join" Then
				FilesInTempStorage = PutFilesToArchive(FilesInTempStorage, ValueSelected);
				WrittenObjects = AttachPrintFormsToObject(FilesInTempStorage);
				ChoiceParameters.Insert("WrittenObjects", WrittenObjects);
				NotifyDescription = New NotifyDescription("SelectionProcessingCompletion", ThisObject, ChoiceParameters);
				SignWrittenObjects(WrittenObjects, NotifyDescription);
				Return;
			EndIf;
		EndIf;
		
		SIgnFiles(FilesInTempStorage, ChoiceParameters);
	Else
		ChoiceParameters.ValueSelected.Insert("AttachmentsList",
			PutFilesToArchive(FilesInTempStorage, ValueSelected));
		SelectionProcessingCompletion(True, ChoiceParameters);
	EndIf;

EndProcedure

&AtClient
Procedure SignWrittenObjects(WrittenObjects, NotificationSignatureCompletion)
	AdditionalParameters = New Structure("ResultProcessing", NotificationSignatureCompletion);
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		
		If CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
			SignatureParameters = ModuleDigitalSignatureClient.NewSignatureType();
			SignatureParameters.CanSelectLetterOfAuthority = True;
		Else
			SignatureParameters = Undefined;
		EndIf;
		
		ModuleFilesOperationsClient.SignFile(WrittenObjects, UUID, AdditionalParameters, SignatureParameters);
	EndIf;
EndProcedure

&AtClient
Procedure SIgnFiles(FilesInTempStorage, ChoiceParameters)

	If Not CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	Map = New Map;
	
	DataDetails = New Structure;
	DataDetails.Insert("ShowComment", False);
	If FilesInTempStorage.Count() > 1 Then
		DataDetails.Insert("Operation", NStr("en = 'Sign files';"));
		DataDetails.Insert("DataTitle", NStr("en = 'Files';"));

		DataSet = New Array;
		For Each File In FilesInTempStorage Do
			DescriptionOfFileData = New Structure;
			DescriptionOfFileData.Insert("Presentation", File.Presentation);
			DescriptionOfFileData.Insert("Data", File.AddressInTempStorage);
			
			Map.Insert(File.AddressInTempStorage, File.PrintObject);
			
			DataSet.Add(DescriptionOfFileData);
		EndDo;

		DataDetails.Insert("DataSet", DataSet);
		DataDetails.Insert("SetPresentation", "Files (%1)");
	Else
		File = FilesInTempStorage[0];
		DataDetails.Insert("Operation", NStr("en = 'Sign a file';"));
		DataDetails.Insert("DataTitle", NStr("en = 'File';"));
		DataDetails.Insert("Presentation", File.Presentation);
		DataDetails.Insert("Data", File.AddressInTempStorage);
		
		Map.Insert(File.AddressInTempStorage, File.PrintObject);
	EndIf;

	ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
	SignatureParameters = ModuleDigitalSignatureClient.NewSignatureType();
	SignatureParameters.CanSelectLetterOfAuthority = True;
	
	ChoiceParameters.Insert("MapBetweenFilesAndPrintableObjects", Map);
	
	NotifyDescription = New NotifyDescription("SelectionProcessingCompletion", ThisObject, ChoiceParameters);
	ModuleDigitalSignatureClient.Sign(DataDetails,, NotifyDescription, SignatureParameters);
	
EndProcedure

&AtClient
Procedure SelectionProcessingCompletion(Result, ChoiceParameters) Export	
	If Result = False 
		Or (TypeOf(Result) = Type("Structure") And Result.Property("Success") And Not Result.Success) Then
		Return;
	EndIf;
		
	ValueSelected = ChoiceParameters.ValueSelected;
	ChoiceSource = ChoiceParameters.ChoiceSource;
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SavePrintForm") Then
		
		If ValueSelected <> Undefined And ValueSelected <> DialogReturnCode.Cancel Then
			If ValueSelected.SavingOption = "SaveToFolder" Then
				If ChoiceParameters.ValueSelected.Sign Then
					FilesInTempStorage = GetSignatureFilesAndPutToArchive(
						Result, ValueSelected, ChoiceParameters.MapBetweenFilesAndPrintableObjects);
					SavePrintFormsToDirectory(FilesInTempStorage, ValueSelected.FolderForSaving);
				Else
					SavePrintFormsToDirectory(ValueSelected.AttachmentsList, ValueSelected.FolderForSaving);
				EndIf;
				
			ElsIf CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
				If ValueSelected.Sign Then
					WrittenObjects = ChoiceParameters.WrittenObjects;
				Else
					FilesInTempStorage = PutOfficeDocsToTempStorage(ValueSelected, True);
					WrittenObjects = AttachPrintFormsToObject(FilesInTempStorage);
				EndIf;
				
				If WrittenObjects.Count() > 0 Then
					NotifyChanged(TypeOf(WrittenObjects[0]));
				EndIf;
				
				ModuleFilesOperationsInternalClient = CommonClient.CommonModule("FilesOperationsInternalClient");
				ModuleFilesOperationsInternalClient.NotifyOfFilesModification(WrittenObjects);
				
				ShowUserNotification(NStr("en = 'Saved';"), , , PictureLib.DialogInformation);
			EndIf;
		EndIf;
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("CommonForm.SelectAttachmentFormat")
		Or Upper(ChoiceSource.FormName) = Upper("CommonForm.ComposeNewMessage") Then
		
		If ValueSelected <> Undefined And ValueSelected <> DialogReturnCode.Cancel Then
			If ValueSelected.Sign Then
				FilesInTempStorage = GetSignatureFilesAndPutToArchive(Result, ValueSelected, ChoiceParameters.MapBetweenFilesAndPrintableObjects);
				SendOptions = EmailSendOptions(ValueSelected, FilesInTempStorage);
				FormClosingNotification = Undefined;
			Else
				If ValueSelected.Property("AttachmentsList") Then
					Attachments = ValueSelected.AttachmentsList;
				Else
					Attachments = Undefined;
				EndIf;
				SendOptions = EmailSendOptions(ValueSelected, Attachments);
				FormClosingNotification = Undefined;
			EndIf;
			DisableRecipientSelection = Upper(ChoiceSource.FormName) = Upper("CommonForm.ComposeNewMessage"); 
			SendOptions.Insert("DisableRecipientSelection", DisableRecipientSelection);
			
			ModuleEmailOperationsClient = CommonClient.CommonModule("EmailOperationsClient");
			ModuleEmailOperationsClient.CreateNewEmailMessage(SendOptions, FormClosingNotification);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function GetSignatureFilesAndPutToArchive(SigningResult, PassedSettings, MapBetweenFilesAndPrintableObjects)
		
	ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
	
	FilesReceiptParameters = ModuleDigitalSignatureInternal.FilesReceiptParameters();
	FilesReceiptParameters.TransliterateFilesNames = PassedSettings.TransliterateFilesNames;
	Files = ModuleDigitalSignatureInternal.GetFilesFromSigningResult(
		SigningResult, FilesReceiptParameters, UUID);
	
	FilesInTempStorage = New Array;
	For Each File In Files Do
		StructureOfFileDetails = New Structure("AddressInTempStorage, Presentation, PrintObject");
		StructureOfFileDetails.AddressInTempStorage = File.Data;
		StructureOfFileDetails.Presentation = File.FileName;
		StructureOfFileDetails.PrintObject = MapBetweenFilesAndPrintableObjects.Get(File.Data);
		FilesInTempStorage.Add(StructureOfFileDetails);
	EndDo;
	
	FilesInTempStorage = PutFilesToArchive(FilesInTempStorage, PassedSettings);
	
	Return FilesInTempStorage;
	
EndFunction

&AtServer
Function PutFilesInTempStorage(FilesArray)
	AttachmentsList = New Array;
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		For Each File In FilesArray Do
			ArrayForFile = CommonClientServer.ValueInArray(File);
			ArrayOfFileAttachments = ModuleFilesOperationsInternal.PutFilesInTempStorage(ArrayForFile, StorageUUID);
			For Each AttachmentOfFile In ArrayOfFileAttachments Do
				AttachmentOfFile.Insert("PrintObject", File.FileOwner);
			EndDo;
			CommonClientServer.SupplementArray(AttachmentsList, ArrayOfFileAttachments);
		EndDo;
	EndIf;
	Return AttachmentsList;
EndFunction

&AtServer
Function AvailablePrintFormLanguages()
	
	Result = New Array;
	
	For Each PrintFormSetting In PrintFormsSettings Do
		If Not PrintFormSetting.OutputInOtherLanguagesAvailable Then
			Continue;
		EndIf;
		For Each LanguageCode In StrSplit(PrintFormSetting.AvailableLanguages, ",", False) Do
			If Result.Find(LanguageCode) = Undefined Then
				Result.Add(LanguageCode);
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure AdditionalInformationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	
	SSLSubsystemsIntegrationClient.PrintDocumentsURLProcessing(ThisObject, Item, FormattedStringURL, StandardProcessing);
	PrintManagementClientOverridable.PrintDocumentsURLProcessing(ThisObject, Item, FormattedStringURL, StandardProcessing);
EndProcedure

// Branch of the procedure that triggers after 1C:Enterprise Extension is installed.
&AtClient
Procedure ResumePrintingAfterFileManagementExtensionInstalled(ExtensionAttached, AdditionalParameters) Export
	
#If WebClient Then
		Text = NStr("en = 'Print the document using an application designed to manage this file.';");
		NotifyDescription = New NotifyDescription("OpenMarkedPrintForms", ThisObject);
		ShowMessageBox(NotifyDescription, Text,,NStr("en = 'Print a document from the web client';"));
		Return;
#EndIf
	
	If Not ExtensionAttached Then
		Return;
	EndIf;
	
	FileOperationsExtensionAttached = ExtensionAttached;
	
	ArrayOfPrintForms = GetPrintForms(CombinedDocStructure, AdditionalParameters);
	
	
#If WebClient Then
	Notification = New NotifyDescription(
		"PrintAfterTempDirNameObtained", ThisObject, ArrayOfPrintForms);
	BeginGettingTempFilesDir(Notification);
#Else
	PrintAfterTempDirNameObtained("", ArrayOfPrintForms);
#EndIf
	
		
EndProcedure

&AtClient
Procedure PrintAfterTempDirNameObtained(TempFilesDirName, ArrayOfPrintForms) Export
	
	For Each PrintForm In ArrayOfPrintForms Do
#If WebClient Then
		TempFileName = TempFilesDirName + String(New UUID);
#Else
		TempFileName = GetTempFileName("DOCX"); // ACC:441 - The function is a temporary file name getter.
#EndIf
		Notification = New NotifyDescription("AfterFileSaved", ThisObject, TempFileName);
		DocumentData = GetFromTempStorage(PrintForm.PrintFormAddress); // BinaryData
		DocumentData.BeginWrite(Notification, TempFileName);
	EndDo;
	
EndProcedure

&AtClient
Procedure AfterFileSaved(TempFileName) Export
	PrintFileByApplication(TempFileName);
	ListOfFilesToDelete.Add(TempFileName);
EndProcedure



#Region PrintUsingApp
// The procedure is designed to print the file by the appropriate application.
//
// Parameters:
//  FilenameForPrint - String
//
&AtClient
Procedure PrintFileByApplication(FilenameForPrint)
	
#If MobileClient Then
	ShowMessageBox(, NStr("en = 'You can print this type of files only from an application for Windows or Linux.';"));
	Return;
#Else
		
	Try
		
		If CommonClient.IsWindowsClient() Then
			FilenameForPrint = StrReplace(FilenameForPrint, "/", "\");
		EndIf;
		
		FileSystemClient.PrintFromApplicationByFileName(FilenameForPrint);
		
	Except
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot print the file. Reason:
				|%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo())); 
		
	EndTry;
#EndIf

EndProcedure

#EndRegion

// Parameters:
//   SelectedOptions - See PrintManagement.SettingsForSaving
//
&AtServer
Function EmailSendOptions(SelectedOptions, Attachments)
	If Attachments <> Undefined Then
		If TypeOf(Attachments[0]) = Type("Structure") Then
			AttachmentsList = Attachments;
		Else
			AttachmentsList = PutFilesInTempStorage(Attachments);
			
			For Each Attachment In AttachmentsList Do
				Attachment.Insert("Print", True);
				Attachment.Insert("Name1", Attachment.Presentation);
			EndDo;
		EndIf;
	Else
		AttachmentsList = PutOfficeDocsToTempStorage(SelectedOptions);
	EndIf;
	
	// Check the names for uniqueness.
	FileNameTemplate = "%1%2.%3";
	UsedFilesNames = New Map;
	For Each Attachment In AttachmentsList Do
		FileName = Attachment.Presentation;
		UsageNumber = ?(UsedFilesNames[FileName] <> Undefined,
			UsedFilesNames[FileName] + 1, 1);
		UsedFilesNames.Insert(FileName, UsageNumber);
		If UsageNumber > 1 Then
			File = New File(FileName);
			FileName = StringFunctionsClientServer.SubstituteParametersToString(FileNameTemplate,
				File.BaseName, " (" + UsageNumber + ")", File.Extension);
		EndIf;
		Attachment.Presentation = FileName;
	EndDo;
	
	Recipients = OutputParameters.SendOptions.Recipient;
	If SelectedOptions.Property("Recipients") Then
		Recipients = SelectedOptions.Recipients;
	EndIf;
	
	Result = New Structure;
	Result.Insert("Recipient", Recipients);
	Result.Insert("Subject", OutputParameters.SendOptions.Subject);
	Result.Insert("Text", OutputParameters.SendOptions.Text);
	Result.Insert("Attachments", AttachmentsList);
	Result.Insert("DeleteFilesAfterSending", True);
	
	If PrintObjects.Count() = 1 And Common.IsReference(TypeOf(PrintObjects[0].Value)) Then
		Result.Insert("SubjectOf", PrintObjects[0].Value);
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure WhenConnectingTheExtension(ExtensionAttached, AdditionalParameters) Export
	
	FileOperationsExtensionAttached = ExtensionAttached;
	
	FormParameters = New Structure;
	FormParameters.Insert("PrintObjects", PrintObjects);
	FormParameters.Insert("FileOperationsExtensionAttached", ExtensionAttached);
	FormParameters.Insert("RestrictionOfSaveFormats", "docx");
	OpenForm("CommonForm.SavePrintForm", FormParameters, ThisObject, "PrintOfficeOpenDocs");

EndProcedure

&AtClient
Procedure SendPrintFormsByEmail()
	NotifyDescription = New NotifyDescription("SendPrintFormsByEmailAccountSetupOffered", ThisObject);
	If CommonClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsClient = CommonClient.CommonModule("EmailOperationsClient");
		ModuleEmailOperationsClient.CheckAccountForSendingEmailExists(NotifyDescription);
	EndIf;
EndProcedure

&AtClient
Procedure SendPrintFormsByEmailAccountSetupOffered(AccountSetUp, AdditionalParameters) Export
	
	If AccountSetUp <> True Then
		Return;
	EndIf;

	FormParameters = CommonInternalClient.PrintFormFormatSettings();
	NameOfFormToOpen_ = "CommonForm.SelectAttachmentFormat";
	If CommonClient.SubsystemExists("StandardSubsystems.Interactions") 
		And StandardSubsystemsClient.ClientRunParameters().UseEmailClient Then
			If MoreThanOneRecipient(OutputParameters.SendOptions.Recipient) Then
				FormParameters.Insert("Recipients", OutputParameters.SendOptions.Recipient);
				NameOfFormToOpen_ = "CommonForm.ComposeNewMessage";
			EndIf;
	EndIf;
	
	FormParameters.Insert("RestrictionOfSaveFormats", "docx");
	
	OpenForm(NameOfFormToOpen_, FormParameters, ThisObject, "PrintOfficeOpenDocs");
	
EndProcedure

&AtClient
Procedure DontShowAgainOnChange(Item)
	DoNotShowAgainOnChangeAtServer(DontShowAgain);
EndProcedure

&AtServerNoContext
Procedure DoNotShowAgainOnChangeAtServer(Value)
	Common.CommonSettingsStorageSave("PrintOfficeOpenDocs",
		"OutputImmediately",	Value);
EndProcedure

&AtClient
Function MoreThanOneRecipient(Recipient)
	If TypeOf(Recipient) = Type("Array") Or TypeOf(Recipient) = Type("ValueList") Then
		Return Recipient.Count() > 1;
	Else
		Return CommonClientServer.EmailsFromString(Recipient).Count() > 1;
	EndIf;
EndFunction

// Parameters:
//  TableOfPrintedForms - ValueTable
//  PrintFormSetting - ValueTableRow
//  PrintForm - See PrintManagement.PreparePrintFormsCollection
//  PrintFormPresentation - String
//
&AtServer
Procedure AddPrintedForm(TableOfPrintedForms, PrintFormSetting, PrintForm, PrintFormPresentation)
	
	PrintFormFileName = PrintFormPresentation + ".DOCX";
	
	PrintFormNewRow = TableOfPrintedForms.Add();
	FillPropertyValues(PrintFormNewRow, PrintFormSetting);
	PrintFormNewRow.PrintObject = PrintForm.Value;
	PrintFormNewRow.PrintFormAddress = PrintForm.Key;
	PrintFormNewRow.PrintFormFileName = PrintFormFileName;
	PrintFormNewRow.Presentation = PrintFormPresentation;
	PrintFormNewRow.Check = True;
	PrintFormNewRow.CurrentLanguage = Common.DefaultLanguageCode();
	
EndProcedure


&AtServer
Function PutFilesToArchive(DocsPrintForms, PassedSettings)
	Var ZipFileWriter, ArchiveName;
	
	Result = New Array;
	
	SettingsForSaving = SettingsForSaving();
	FillPropertyValues(SettingsForSaving, PassedSettings);
	
	If Not SettingsForSaving.PackToArchive Then
		Return DocsPrintForms;
	EndIf;
	SavingOption = Undefined; 
	PassedSettings.Property("SavingOption", SavingOption);
	SetPrintObject = SavingOption = "Join";	
	
	TransliterateFilesNames = SettingsForSaving.TransliterateFilesNames;
	
	TempDirectoryName = CommonClientServer.AddLastPathSeparator(GetTempFileName());
	CreateDirectory(TempDirectoryName);
	
	MapForArchives = New Map;
		
	For Each FileStructure In DocsPrintForms Do
			
		FileData = GetFromTempStorage(FileStructure.AddressInTempStorage);
		FullFileName = TempDirectoryName + FileStructure.Presentation;
		FileData.Write(FullFileName);
		
		PrintObject = ?(SetPrintObject And ValueIsFilled(FileStructure.PrintObject), FileStructure.PrintObject, Undefined);
		
		If MapForArchives[PrintObject] = Undefined Then
			ArchiveName = GetTempFileName("zip");
			ZipFileWriter = New ZipFileWriter(ArchiveName);
			
			Presentation = ?(PrintObject = Undefined, NStr("en = 'Documents';"), CommonClientServer.ReplaceProhibitedCharsInFileName(String(PrintObject)));
			If TransliterateFilesNames Then
				Presentation = StringFunctions.LatinString(Presentation);
			EndIf;
			WriteParameters = New Structure("ZipFileWriter, ArchiveName, Presentation", ZipFileWriter, ArchiveName, Presentation+".zip");
			MapForArchives.Insert(PrintObject, WriteParameters);
		EndIf;
		
		MapForArchives[PrintObject].ZipFileWriter.Add(FullFileName);

	EndDo;
		
	For Each ObjectArchive In MapForArchives Do
		ZipFileWriter = ObjectArchive.Value.ZipFileWriter;
		ArchiveName = ObjectArchive.Value.ArchiveName;
		ZipFileWriter.Write();
		BinaryData = New BinaryData(ArchiveName);
		PathInTempStorage = PutToTempStorage(BinaryData, StorageUUID);
		FileDetails = FileDetails(ObjectArchive.Value.Presentation);
		FileDetails.Insert("PrintObject", ObjectArchive.Key);
		FileDetails.Insert("AddressInTempStorage", PathInTempStorage);
		Result.Add(FileDetails);
		DeleteFiles(ArchiveName);
	EndDo;
		
	DeleteFiles(TempDirectoryName);
	
	Return Result;
	
EndFunction

&AtServer
Function PutOfficeDocsToTempStorage(PassedSettings, UseIndividualPrintForms = False, ThisIsSigning = False)
	Var ZipFileWriter, ArchiveName;
	
	If PassedSettings.Property("AttachmentsList") And PassedSettings.AttachmentsList <> Undefined
			And Not UseIndividualPrintForms Then
		PrintFormsSettingsTemp = PassedSettings.AttachmentsList; // A single document.
	Else
		PrintFormsSettingsTemp = PrintFormsSettings;
	EndIf;
	
	SettingsForSaving = SettingsForSaving();
	FillPropertyValues(SettingsForSaving, PassedSettings);
	
	Result = New Array;
	
	// Prepare an archive.
	If SettingsForSaving.PackToArchive And Not ThisIsSigning Then
		ArchiveName = GetTempFileName("zip");
		ZipFileWriter = New ZipFileWriter(ArchiveName);
	EndIf;
	
	TempDirectoryName = CommonClientServer.AddLastPathSeparator(GetTempFileName());
	CreateDirectory(TempDirectoryName);
	
	TransliterateFilesNames = SettingsForSaving.TransliterateFilesNames;
	
	ObjectsToAttach = Undefined;
	If PassedSettings.Property("ObjectsToAttach") Then
		ObjectsToAttach = Common.CopyRecursive(PassedSettings.ObjectsToAttach);
	EndIf;
	
	// Save print forms.
	For Each PrintFormSetting In PrintFormsSettingsTemp Do
		If PrintFormSetting.Property("OfficeDocuments") And Not IsBlankString(PrintFormSetting.OfficeDocuments) Then
			
			OfficeDocumentsFiles = Common.ValueFromXMLString(PrintFormSetting.OfficeDocuments);
			
			For Each OfficeDocumentFile In OfficeDocumentsFiles Do
				FileName = PrintManagement.OfficeDocumentFileName(OfficeDocumentFile.Value);
				PrintObject = OfficeDocumentFile.Value;
				If ObjectsToAttach <> Undefined And ObjectsToAttach[PrintObject] <> True Then
					Continue;
				EndIf;
				
				If TransliterateFilesNames Then
					FileName = StringFunctions.LatinString(FileName);
				EndIf;
				
				If ZipFileWriter <> Undefined Then 
					FullFileName = FileSystem.UniqueFileName(TempDirectoryName + FileName);
					BinaryData = GetFromTempStorage(OfficeDocumentFile.Key); // BinaryData - 
					BinaryData.Write(FullFileName);
					ZipFileWriter.Add(FullFileName);
				Else
					FileDetails = FileDetails(FileName);
					FileDetails.Insert("AddressInTempStorage", OfficeDocumentFile.Key);
					FileDetails.Insert("PrintObject", PrintObject);
					Result.Add(FileDetails);
				EndIf;
				
			EndDo;
			
			Continue;
		ElsIf PrintFormSetting.Property("AddressInTempStorage") Then
			
			If ObjectsToAttach <> Undefined And ObjectsToAttach[PrintFormSetting.PrintObject] <> True Then
				Continue;
			EndIf;
			
			FileName = PrintFormSetting.Presentation;
				
			If TransliterateFilesNames Then
				FileName = StringFunctions.LatinString(FileName);
			EndIf;
			
			If ZipFileWriter <> Undefined Then 
				FullFileName = FileSystem.UniqueFileName(TempDirectoryName + FileName);
				BinaryData = GetFromTempStorage(PrintFormSetting.AddressInTempStorage); // BinaryData - 
				BinaryData.Write(FullFileName);
				ZipFileWriter.Add(FullFileName);
			Else
				FileDetails = FileDetails(FileName);
				FileDetails.Insert("AddressInTempStorage", PrintFormSetting.AddressInTempStorage);
				FileDetails.Insert("PrintObject", PrintFormSetting.PrintObject);
				Result.Add(FileDetails);
			EndIf;
		EndIf;
		
	EndDo;
	
	// If the archive is prepared, writing it and putting in the temporary storage.
	If ZipFileWriter <> Undefined Then 
		ZipFileWriter.Write();
		BinaryData = New BinaryData(ArchiveName);
		PathInTempStorage = PutToTempStorage(BinaryData, StorageUUID);
		FileDetails = FileDetails(GetFileNameForArchive(TransliterateFilesNames, PrintFormsSettingsTemp));
		FileDetails.Insert("AddressInTempStorage", PathInTempStorage);
		If PassedSettings.Property("PrintObject") Then
			FileDetails.Insert("PrintObject", PassedSettings.PrintObject);
		Else
			FileDetails.Insert("PrintObject", Undefined);
		EndIf;
		Result.Add(FileDetails);
	EndIf;
	
	DeleteFiles(TempDirectoryName);
	If ValueIsFilled(ArchiveName) Then
		DeleteFiles(ArchiveName);
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function GetFileNameForArchive(TransliterateFilesNames, PrintFormsSettingsTemp = Undefined)
	
	If PrintFormsSettingsTemp = Undefined Then
		PrintFormsSettingsTemp = PrintFormsSettings;
	EndIf;
	
	Result = "";
	
	For Each PrintFormSetting In PrintFormsSettingsTemp Do
		
		If Not CanOutput() Then
			Continue;
		EndIf;
		
		If IsBlankString(Result) Then
			Result = PrintFormSetting.Name1;
		Else
			Result = NStr("en = 'Documents';");
			Break;
		EndIf;
	EndDo;
	
	If TransliterateFilesNames Then
		Result = StringFunctions.LatinString(Result);
	EndIf;
	
	Return Result + ".zip";
	
EndFunction

&AtServerNoContext
Function SettingsForSaving()

	Return PrintManagement.SettingsForSaving();

EndFunction

&AtServer
Function CanOutput()
	Return AccessRight("Output", Metadata);
EndFunction

&AtClient
Procedure SavePrintFormsToDirectory(FilesListInTempStorage, Val DirectoryName = "")
	
	If FileOperationsExtensionAttached And ValueIsFilled(DirectoryName) Then
		DirectoryName = CommonClientServer.AddLastPathSeparator(DirectoryName);
	Else
		WhenPreparingFileNames(FilesListInTempStorage, "");
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("WhenPreparingFileNames", ThisObject, DirectoryName);
	PreparationParameters = PrintManagementClient.FileNamePreparationOptions(FilesListInTempStorage, DirectoryName, NotifyDescription);
	PrepareFileNamesToSaveToADirectory(PreparationParameters);
	
EndProcedure

// Parameters:
//  PreparationParameters - See PrintManagementClient.FileNamePreparationOptions
//
&AtClient
Procedure PrepareFileNamesToSaveToADirectory(PreparationParameters)
	
	PrintManagementClient.PrepareFileNamesToSaveToADirectory(PreparationParameters);
		
EndProcedure

&AtClient
Procedure WhenPreparingFileNames(FilesListInTempStorage, DirectoryName) Export
	
	FilesToSave = New Array;
	
	For Each FileToWrite In FilesListInTempStorage Do
		FileName = FileToWrite.Presentation;
		FilesToSave.Add(New TransferableFileDescription(FileName, FileToWrite.AddressInTempStorage));
	EndDo;
	
	SavingParameters = FileSystemClient.FilesSavingParameters();
	SavingParameters.Dialog.Directory = DirectoryName;
	SavingParameters.Interactively = Not ValueIsFilled(DirectoryName);
	FileSystemClient.SaveFiles(Undefined, FilesToSave, SavingParameters);

#If Not WebClient Then
	If ValueIsFilled(DirectoryName) Then
		NotifyDescription = New NotifyDescription("OpenFolderSaveTo", ThisObject, DirectoryName); 
		ShowUserNotification(NStr("en = 'Saved successfully.';"), NotifyDescription,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Folder: %1';"), DirectoryName), PictureLib.DialogInformation);
	EndIf;
#EndIf
	
EndProcedure

&AtClient
Procedure OpenFolderSaveTo(DirectoryName) Export
	FileSystemClient.OpenExplorer(DirectoryName);
EndProcedure

&AtServer
Function AttachPrintFormsToObject(FilesInTempStorage)
	Result = New Array;
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		For Each File In FilesInTempStorage Do
			If ModuleFilesOperations.CanAttachFilesToObject(File["PrintObject"]) Then
				FileParameters = ModuleFilesOperations.FileAddingOptions();
				FileParameters.FilesOwner = File["PrintObject"];
				FileParameters.BaseName = File.Presentation;
				Result.Add(ModuleFilesOperations.AppendFile(
					FileParameters, File.AddressInTempStorage, , NStr("en = 'Print form';")));
			EndIf;
		EndDo;
	EndIf;
	Return Result;
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  ArrayOfPrintForms - Array
//
&AtClient
Procedure PrintFollowUp(Result, ArrayOfPrintForms) Export
	If Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
	Else
		CombinedDocStructure = GetFromTempStorage(Result.ResultAddress);
		ArrayOfPrintForms = GetPrintForms(CombinedDocStructure, ArrayOfPrintForms);
		PrintCompletion(ArrayOfPrintForms);
	EndIf;
	
EndProcedure	
	
&AtClient
Procedure PrintCompletion(ArrayOfPrintForms)	
	Handler = New NotifyDescription("ResumePrintingAfterFileManagementExtensionInstalled", ThisObject, ArrayOfPrintForms);
	MessageText = NStr("en = 'To continue, install 1C:Enterprise Extension.';");
	FileSystemClient.AttachFileOperationsExtension(Handler, MessageText);
EndProcedure

&AtClient
Procedure StartGettingPrintForms(CombinedDocStructure, Notification)
	TimeConsumingOperation = GetPrintFormsLongRunningOperation(CombinedDocStructure);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, Notification, IdleParameters());
EndProcedure

&AtServerNoContext
Function FileDetails(FileDescription = "")
	FileDetails = New Structure;
	FileDetails.Insert("AddressInTempStorage", "");
	FileDetails.Insert("Name1", FileDescription);
	FileDetails.Insert("Print", True);
	FileDetails.Insert("Presentation", FileDescription);
	FileDetails.Insert("PrintObject", Undefined);
	FileDetails.Insert("IsOfficeDocument", True);
	Return FileDetails; 
EndFunction
#EndRegion










