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
Var RecipientOfDraggedValue, WaitHanderParametersAddress;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Common.IsMobileClient() Then
		Raise NStr("en = 'Cannot edit a spreadsheet document in mobile client.
		|Use thin client or web client.';");
	EndIf;
	
	If Parameters.WindowOpeningMode <> Undefined Then
		WindowOpeningMode = Parameters.WindowOpeningMode;
	EndIf;

	SpreadsheetDocument.LanguageCode = Common.DefaultLanguageCode();
	
	IdentifierOfTemplate = Parameters.TemplateMetadataObjectName;
	RefTemplate = Parameters.Ref;
	If ValueIsFilled(RefTemplate) Then
		KeyOfEditObject  = RefTemplate;
		LockDataForEdit(KeyOfEditObject,, UUID);
	ElsIf ValueIsFilled(IdentifierOfTemplate) Then
		If Common.SubsystemExists("StandardSubsystems.Print") Then
			ModulePrintManager = Common.CommonModule("PrintManagement");
			KeyOfEditObject = ModulePrintManager.GetTemplateRecordKey(IdentifierOfTemplate);
			If KeyOfEditObject <> Undefined Then
				LockDataForEdit(KeyOfEditObject,, UUID);
			EndIf;
		EndIf;
	EndIf;
	
	IsPrintForm = Parameters.IsPrintForm;
	IsTemplate = Not IsBlankString(IdentifierOfTemplate) Or IsPrintForm;
	SpreadsheetDocument.Template = IsTemplate;
	
	Items.ButtonShowHideOriginal.Visible = IsTemplate;
	Items.ButtonShowHideOriginalAllActions.Visible = IsTemplate;
	Items.DeleteStampEP.Visible = IsTemplate;

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
	
	DocumentName = Parameters.DocumentName;
	Items.Rename.Visible = ValueIsFilled(Parameters.Ref) 
		Or IsBlankString(IdentifierOfTemplate) And IsBlankString(Parameters.PathToFile);
	
	Items.DeleteLayoutLanguage.Visible = Not ValueIsFilled(Parameters.Ref) And IsBlankString(Parameters.PathToFile);

	If Parameters.SpreadsheetDocument = Undefined Then
		If Not IsBlankString(IdentifierOfTemplate) Then
			EditingDenied = Not Parameters.Edit;
			LoadSpreadsheetDocumentFromMetadata(Parameters.LanguageCode);
			If Parameters.Copy Then
				IDOfTemplateBeingCopied = IdentifierOfTemplate;
				IdentifierOfTemplate = "";
			EndIf;
		EndIf;
	ElsIf TypeOf(Parameters.SpreadsheetDocument) = Type("SpreadsheetDocument") Then
		FillSpreadsheetDocument(SpreadsheetDocument, Parameters.SpreadsheetDocument);
	Else
		SpreadsheetDocument.LanguageCode = Undefined;
		BinaryData = GetFromTempStorage(Parameters.SpreadsheetDocument); // BinaryData
		TempFileName = GetTempFileName("mxl");
		BinaryData.Write(TempFileName);
		SpreadsheetDocument.Read(TempFileName);
		DeleteFiles(TempFileName);
	EndIf;
	
	Items.SpreadsheetDocument.Edit = Parameters.Edit;
	Items.SpreadsheetDocument.ShowGroups = True;
	Items.SpreadsheetDocument.ShowRowAndColumnNames = SpreadsheetDocument.Template;
	Items.SpreadsheetDocument.ShowCellNames = SpreadsheetDocument.Template;
	
	Items.Warning.Visible = IsTemplate And Not IsPrintForm And Parameters.Edit;
	Items.EditInExternalApplication.Visible = Common.IsWebClient() 
		And Not IsBlankString(IdentifierOfTemplate) And Common.SubsystemExists("StandardSubsystems.Print");
	
	AvailableTranslationLayout = False;
	If IsTemplate Then
		If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.Print") Then
			PrintManagementModuleNationalLanguageSupport = Common.CommonModule("PrintManagementNationalLanguageSupport");
			AvailableTranslationLayout = PrintManagementModuleNationalLanguageSupport.AvailableTranslationLayout(IdentifierOfTemplate);
			If IsPrintForm Or PrintManagementModuleNationalLanguageSupport.AvailableTranslationLayout(IdentifierOfTemplate) Then
				PrintManagementModuleNationalLanguageSupport.FillInTheLanguageSubmenu(ThisObject, Parameters.LanguageCode);
				AutomaticTranslationAvailable = PrintManagementModuleNationalLanguageSupport.AutomaticTranslationAvailable(CurrentLanguage);
			EndIf;
		EndIf;
	EndIf;
	
	Items.Language.Enabled = (IsPrintForm Or AvailableTranslationLayout) And ValueIsFilled(IdentifierOfTemplate);
	Items.LanguageAllActions.Enabled = Items.Language.Enabled;
	
	Items.Translate.Visible = AutomaticTranslationAvailable;
	Items.TranslateAllActions.Visible = Items.Translate.Visible;
	
	If Common.IsMobileClient() Then
		CommonClientServer.SetFormItemProperty(Items, "CommandBar", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "Warning", "Visible", False);
	EndIf;
	
	If IsPrintForm And Common.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormula = Common.CommonModule("FormulasConstructor");
		
		DataSource = Parameters.DataSource;
		If Not ValueIsFilled(Parameters.DataSource) Then
			DataSource = DataSources[0].Value;
		EndIf;

		MetadataObject = Common.MetadataObjectByID(DataSource);
		PickupSample(MetadataObject);
		
		Items.Edit.Visible = False;
		FieldSelectionBackColor = StyleColors.NavigationColor;
		
		Items.TextToCopy.Visible = Common.IsWebClient();
		
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
		
		ModuleConstructorFormula.AddAListOfFieldsToTheForm(ThisObject, AddingOptions);
				
		AddingOptions = ModuleConstructorFormula.ParametersForAddingAListOfFields();
		AddingOptions.ListName = NameOfTheListOfOperators();
		AddingOptions.LocationOfTheList = Items.OperatorsAndFunctionsGroup;
		AddingOptions.FieldsCollections.Add(ListOfOperators());			
		AddingOptions.HintForEnteringTheSearchString = NStr("en = 'Find operator or function…';");
		AddingOptions.ViewBrackets = False;
		AddingOptions.ListHandlers.Insert("Selection", "Attachable_ListOfFieldsSelection");
		AddingOptions.ListHandlers.Insert("DragStart", "Attachable_OperatorsDragStart");
		AddingOptions.ListHandlers.Insert("DragEnd", "Attachable_OperatorsDragEnd");
		
		ModuleConstructorFormula.AddAListOfFieldsToTheForm(ThisObject, AddingOptions);
		
		FillSpreadsheetDocument(SpreadsheetDocument, ReadLayout());
		ReadTextInFooterField(SpreadsheetDocument.Header.LeftText, TopLeftText);
		ReadTextInFooterField(SpreadsheetDocument.Header.CenterText, TopMiddleText);
		ReadTextInFooterField(SpreadsheetDocument.Header.RightText, TopRightText);
		ReadTextInFooterField(SpreadsheetDocument.Footer.LeftText, BottomLeftText);
		ReadTextInFooterField(SpreadsheetDocument.Footer.CenterText, BottomCenterText);
		ReadTextInFooterField(SpreadsheetDocument.Footer.RightText, BottomRightText);
	
		ExpandFieldList();
		
		SpreadsheetDocument.Template = True;
		
		If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
			ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
			AttachedFilesTypes = ModuleFilesOperationsInternal.AttachedFilesTypes();
		EndIf;
	EndIf;
	
	If Not IsPrintForm Then
		Items.ShowHeadersAndFooters.Visible = False;
		Items.SettingsCurrentRegion.Visible = False;
		Items.ButtonAvailableFields.Visible = False;
		Items.ViewPrintableForm.Visible = False;
		Items.RepeatAtTopofPage.Visible = False;
		Items.RepeatAtEndPage.Visible = False;
	EndIf;
	
	Items.Header.Visible = False;
	Items.Footer.Visible = False;

	Items.GroupTemplateAssignment.Visible = IsPrintForm;
	Items.GroupTemplateAssignment.Enabled = Parameters.IsValAvailable;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not IsBlankString(Parameters.PathToFile) Then
		File = New File(Parameters.PathToFile);
		If IsBlankString(DocumentName) Then
			DocumentName = File.BaseName;
		EndIf;
		File.BeginGettingReadOnly(New NotifyDescription("OnCompleteGetReadOnly", ThisObject));
		Return;
	EndIf;
	
	SetInitialFormSettings();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Items.ViewPrintableForm.Check Then
		Cancel = True;
		ViewPrintableForm(Undefined);
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("ConfirmAndClose", ThisObject);
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Do you want to save the changes to %1?';"), DocumentName);
	CommonClient.ShowFormClosingConfirmation(NotifyDescription, Cancel, Exit, QueryText);
	
	If Modified Or Exit Then
		Return;
	EndIf;
	
	If Not IsNew() Then
		NotifyAboutTheTableDocumentEntry();
	EndIf;
	
	If  Not Cancel And Not Exit And ValueIsFilled(KeyOfEditObject) Then
		UnlockAtServer(); 
	EndIf;
	
EndProcedure

&AtClient
Procedure ConfirmAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	NotifyDescription = New NotifyDescription("CloseFormAfterWriteSpreadsheetDocument", ThisObject);
	WriteSpreadsheetDocument(NotifyDescription);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "SpreadsheetDocumentsToEditNameRequest" And Source <> ThisObject Then
		DocumentNames = Parameter; // Array -
		DocumentNames.Add(DocumentName);
	ElsIf EventName = "OwnerFormClosing" And Source = FormOwner Then
		Close();
		If IsOpen() Then
			Parameter.Cancel = True;
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SpreadsheetDocumentOnActivate(Item)
	UpdateCommandBarButtonMarks();
	SynchronizeTheLayoutViewport();
	AttachIdleHandler("ClearHighlight", 0.1, True);
	AttachIdleHandler("UpdateAreaSettingsSelectedCells", 0.1, True);
EndProcedure

&AtClient
Procedure SuppliedTemplateOnActivate(Item)
	
	SynchronizeTheLayoutViewport();
	
EndProcedure

&AtClient
Procedure TemplateOwnersClick(Item)
	
	PickingParameters = StandardSubsystemsClientServer.MetadataObjectsSelectionParameters();
	PickingParameters.SelectedMetadataObjects = CommonClient.CopyRecursive(DataSources);
	PickingParameters.ChooseRefs = True;
	PickingParameters.Title = NStr("en = 'Template assignment';");
	PickingParameters.FilterByMetadataObjects = ObjectsWithPrintCommands();
	
	NotifyDescription = New NotifyDescription("OnChooseTemplateOwners", ThisObject);
	StandardSubsystemsClient.ChooseMetadataObjects(PickingParameters, NotifyDescription);

EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// Document actions

&AtClient
Procedure WriteAndClose(Command)
	NotifyDescription = New NotifyDescription("CloseFormAfterWriteSpreadsheetDocument", ThisObject);
	WriteSpreadsheetDocument(NotifyDescription, True);
EndProcedure

&AtClient
Procedure Write(Command)
	WriteSpreadsheetDocument();
	NotifyAboutTheTableDocumentEntry();
EndProcedure

&AtClient
Procedure Edit(Command)
	Items.SpreadsheetDocument.Edit = Not Items.SpreadsheetDocument.Edit;
	SetUpCommandPresentation();
	SetUpSpreadsheetDocumentRepresentation();
EndProcedure

&AtClient
Procedure EditInExternalApplication(Command)
	If CommonClient.SubsystemExists("StandardSubsystems.Print") Then
		OpeningParameters = New Structure;
		OpeningParameters.Insert("SpreadsheetDocument", SpreadsheetDocument);
		OpeningParameters.Insert("TemplateMetadataObjectName", IdentifierOfTemplate);
		OpeningParameters.Insert("IdentifierOfTemplate", IdentifierOfTemplate);
		OpeningParameters.Insert("TemplateType", "MXL");
		NotifyDescription = New NotifyDescription("EditInExternalApplicationCompletion", ThisObject);
		ModulePrintManagerClient = CommonClient.CommonModule("PrintManagementClient");
		ModulePrintManagerClient.EditTemplateInExternalApplication(NotifyDescription, OpeningParameters, ThisObject);
	EndIf;
EndProcedure

&AtClient
Procedure SaveToFile(Command)
	
	ClearHighlight();
	
	FileDialog = New FileDialog(FileDialogMode.Save);
	FileDialog.FullFileName = CommonClientServer.ReplaceProhibitedCharsInFileName(DocumentName);
	FileDialog.Filter = NStr("en = 'Spreadsheet document';") + " (*.mxl)|*.mxl";
	
	NotifyDescription = New NotifyDescription("ContinueSavingToFile", ThisObject);
	FileSystemClient.ShowSelectionDialog(NotifyDescription, FileDialog);	
	
EndProcedure

&AtClient
Procedure LoadFromFile(Command)
	
	FileDialog = New FileDialog(FileDialogMode.Open);
	FileDialog.Filter = NStr("en = 'Spreadsheet document';") + " (*.mxl)|*.mxl";
	FileDialog.Multiselect = False;
	
	NotifyDescription = New NotifyDescription("ContinueDownloadFromFile", ThisObject);
	FileSystemClient.ShowSelectionDialog(NotifyDescription, FileDialog);	
	
EndProcedure

&AtClient
Procedure ChangeFont(Command)
	
	If Items.SpreadsheetDocument.CurrentArea = Undefined Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("ChangeFontCompletion", ThisObject);
	OpenForm("CommonForm.FontChoiceForm",, ThisObject,,,, NotifyDescription);
	
EndProcedure

// Formatting

&AtClient
Procedure IncreaseFontSize(Command)
	
	For Each Area In AreaListForChangingFont() Do
		Size = Area.Font.Size;
		Size = Size + IncreaseFontSizeChangeStep(Size);
		Area.Font = New Font(Area.Font,,Size); // ACC:1345 - Don't apply styles.
	EndDo;
	
EndProcedure

&AtClient
Procedure DecreaseFontSize(Command)
	
	For Each Area In AreaListForChangingFont() Do
		Size = Area.Font.Size;
		Size = Size - DecreaseFontSizeChangeStep(Size);
		If Size < 1 Then
			Size = 1;
		EndIf;
		Area.Font = New Font(Area.Font,,Size); // ACC:1345 - Don't apply styles.
	EndDo;
	
EndProcedure

&AtClient
Procedure Strikeout(Command)
	
	ValueToSet = Undefined;
	For Each Area In AreaListForChangingFont() Do
		If ValueToSet = Undefined Then
			ValueToSet = Not Area.Font.Strikeout = True;
		EndIf;
		Area.Font = New Font(Area.Font,,,,,,ValueToSet); // ACC:1345 - Don't apply styles.
	EndDo;
	
	UpdateCommandBarButtonMarks();
	
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
Procedure TopLeftTextOnChange(Item)
	
	SpreadsheetDocument.Header.LeftText = TopLeftText.GetFormattedString();
	SetHeaderAndFooterOutput(SpreadsheetDocument.Header);
	Modified = True;
	RecipientOfDraggedValue = Item;
	
EndProcedure

&AtClient
Procedure TopMiddleTextOnChange(Item)
	
	SpreadsheetDocument.Header.CenterText = TopMiddleText.GetFormattedString();
	SetHeaderAndFooterOutput(SpreadsheetDocument.Header);
	Modified = True;
	RecipientOfDraggedValue = Item;
	
EndProcedure

&AtClient
Procedure TopRightTextOnChange(Item)
	
	SpreadsheetDocument.Header.RightText = TopRightText.GetFormattedString();
	SetHeaderAndFooterOutput(SpreadsheetDocument.Header);
	Modified = True;
	RecipientOfDraggedValue = Item;
	
EndProcedure

&AtClient
Procedure BottomLeftTextOnChange(Item)
	
	SpreadsheetDocument.Footer.LeftText = BottomLeftText.GetFormattedString();
	SetHeaderAndFooterOutput(SpreadsheetDocument.Footer);
	Modified = True;
	RecipientOfDraggedValue = Item;
	
EndProcedure

&AtClient
Procedure BottomCenterTextOnChange(Item)
	
	SpreadsheetDocument.Footer.CenterText = BottomCenterText.GetFormattedString();
	SetHeaderAndFooterOutput(SpreadsheetDocument.Footer);
	Modified = True;
	RecipientOfDraggedValue = Item;
	
EndProcedure

&AtClient
Procedure BottomRightTextOnChange(Item)
	
	SpreadsheetDocument.Footer.RightText = BottomRightText.GetFormattedString();
	SetHeaderAndFooterOutput(SpreadsheetDocument.Footer);
	Modified = True;
	RecipientOfDraggedValue = Item;
	
EndProcedure

&AtClient
Procedure AlignTop(Command)
	
	For Each Area In AreaListForChangingFont() Do
		Area.VerticalAlign = VerticalAlign.Top;
	EndDo;
	
	UpdateCommandBarButtonMarks();
	
EndProcedure

&AtClient
Procedure AlignMiddle(Command)
	
	For Each Area In AreaListForChangingFont() Do
		Area.VerticalAlign = VerticalAlign.Center;
	EndDo;
	
	UpdateCommandBarButtonMarks();
	
EndProcedure

&AtClient
Procedure AlignBottom(Command)
	
	For Each Area In AreaListForChangingFont() Do
		Area.VerticalAlign = VerticalAlign.Bottom;
	EndDo;
	
	UpdateCommandBarButtonMarks();
	
EndProcedure

&AtClient
Procedure Rename(Command)
	
	NotifyDescription = New NotifyDescription("OnSelectingLayoutName", ThisObject);
	ShowInputString(NotifyDescription, DocumentName, NStr("en = 'Enter a template description';"), 100, False);
	
EndProcedure

&AtClient
Procedure ChangeBorderColor(Command)
	
	NotifyDescription = New NotifyDescription("ChangeBorderColorCompletion", ThisObject);
	OpenForm("CommonForm.ColorChoiceForm",, ThisObject,,,, NotifyDescription);
	
EndProcedure

&AtClient
Procedure ChangeTextColor(Command)
	
	NotifyDescription = New NotifyDescription("ChangeTextColorCompletion", ThisObject);
	OpenForm("CommonForm.ColorChoiceForm",, ThisObject,,,, NotifyDescription);
	
EndProcedure

&AtClient
Procedure ChangeBackgroundColor(Command)
	
	NotifyDescription = New NotifyDescription("ChangeBackgroundColorCompletion", ThisObject);
	OpenForm("CommonForm.ColorChoiceForm",, ThisObject,,,, NotifyDescription);

EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure LoadSpreadsheetDocumentFromMetadata(Val LanguageCode = Undefined)
	
	TranslationRequired = False;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		PrintFormTemplate = ModulePrintManager.PrintFormTemplate(IdentifierOfTemplate, LanguageCode);
		FillSpreadsheetDocument(SpreadsheetDocument, PrintFormTemplate);
		If Not ValueIsFilled(RefTemplate) Then
			SuppliedTemplate = ModulePrintManager.SuppliedTemplate(IdentifierOfTemplate, LanguageCode);
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
	EndIf;
	
EndProcedure

&AtClient
Procedure SetHeaderAndFooterOutput(HeaderOrFooter)
	HeaderOrFooter.Enabled = Not IsBlankString(HeaderOrFooter.LeftText) Or Not IsBlankString(HeaderOrFooter.RightText) Or Not IsBlankString(HeaderOrFooter.CenterText);
	HeaderOrFooter.StartPage = 1;	
EndProcedure

&AtClient
Procedure SetUpSpreadsheetDocumentRepresentation()
	Items.SpreadsheetDocument.ShowHeaders = Items.SpreadsheetDocument.Edit;
	Items.SpreadsheetDocument.ShowGrid = Items.SpreadsheetDocument.Edit;
EndProcedure

&AtClient
Procedure UpdateCommandBarButtonMarks();
	
#If Not WebClient And Not MobileClient Then
	Area = Items.SpreadsheetDocument.CurrentArea;
	If TypeOf(Area) <> Type("SpreadsheetDocumentRange") Then
		Return;
	EndIf;
	
	// Font.
	Font = Area.Font;
	Items.SpreadsheetDocumentBold.Check = Font <> Undefined And Font.Bold = True;
	Items.SpreadsheetDocumentItalic.Check = Font <> Undefined And Font.Italic = True;
	Items.SpreadsheetDocumentUnderline.Check = Font <> Undefined And Font.Underline = True;
	
	Items.SpreadsheetUnderlineAllActions.Check = Items.SpreadsheetDocumentBold.Check;
	Items.SpreadsheetItalicAllActions.Check = Items.SpreadsheetDocumentItalic.Check;
	Items.SpreadsheetUnderlineAllActions.Check = Items.SpreadsheetDocumentUnderline.Check;
	Items.StrikethroughAllActions.Check = Font <> Undefined And Font.Strikeout = True;
	
	// Horizontal orientation.
	Items.SpreadsheetDocumentAlignLeft.Check = Area.HorizontalAlign = HorizontalAlign.Left;
	Items.SpreadsheetDocumentAlignCenter.Check = Area.HorizontalAlign = HorizontalAlign.Center;
	Items.SpreadsheetDocumentAlignRight.Check = Area.HorizontalAlign = HorizontalAlign.Right;
	Items.SpreadsheetDocumentJustify.Check = Area.HorizontalAlign = HorizontalAlign.Justify;
	
	Items.SpreadsheetAlignLeftAllActions.Check = Items.SpreadsheetDocumentAlignLeft.Check;
	Items.SpreadsheetDocAlignCenterAllActions.Check = Items.SpreadsheetDocumentAlignCenter.Check;
	Items.SpreadsheetAlignRightAllActions.Check = Items.SpreadsheetDocumentAlignRight.Check;
	Items.SpreadsheetJustifyAllActions.Check = Items.SpreadsheetDocumentJustify.Check;
	
	// Vertical orientation.
	Items.AlignTop.Check = Area.VerticalAlign = VerticalAlign.Top;
	Items.AlignMiddle.Check = Area.VerticalAlign = VerticalAlign.Center;
	Items.AlignBottom.Check = Area.VerticalAlign = VerticalAlign.Bottom;
	
	Items.AlignTopAllActions.Check = Items.AlignTop.Check;
	Items.AlignMiddleAllActions.Check = Items.AlignMiddle.Check;
	Items.AlignBottomAllActions.Check = Items.AlignBottom.Check;
	
#EndIf
	
EndProcedure

&AtClient
Function IncreaseFontSizeChangeStep(Size)
	If Size = -1 Then
		Return 10;
	EndIf;
	
	If Size < 10 Then
		Return 1;
	ElsIf 10 <= Size And  Size < 20 Then
		Return 2;
	ElsIf 20 <= Size And  Size < 48 Then
		Return 4;
	ElsIf 48 <= Size And  Size < 72 Then
		Return 6;
	ElsIf 72 <= Size And  Size < 96 Then
		Return 8;
	Else
		Return Round(Size / 10);
	EndIf;
EndFunction

&AtClient
Function DecreaseFontSizeChangeStep(Size)
	If Size = -1 Then
		Return -8;
	EndIf;
	
	If Size <= 11 Then
		Return 1;
	ElsIf 11 < Size And Size <= 23 Then
		Return 2;
	ElsIf 23 < Size And Size <= 53 Then
		Return 4;
	ElsIf 53 < Size And Size <= 79 Then
		Return 6;
	ElsIf 79 < Size And Size <= 105 Then
		Return 8;
	Else
		Return Round(Size / 11);
	EndIf;
EndFunction

// Returns:
//   Array of SpreadsheetDocumentRange
//
&AtClient
Function AreaListForChangingFont()
	
	Result = New Array;
	
	For Each AreaToProcess In Items.SpreadsheetDocument.GetSelectedAreas() Do
		If AreaToProcess.Font <> Undefined Then
			Result.Add(AreaToProcess);
			Continue;
		EndIf;
		
		AreaToProcessTop = AreaToProcess.Top;
		AreaToProcessBottom = AreaToProcess.Bottom;
		AreaToProcessLeft = AreaToProcess.Left;
		AreaToProcessRight = AreaToProcess.Right;
		
		If AreaToProcessTop = 0 Then
			AreaToProcessTop = 1;
		EndIf;
		
		If AreaToProcessBottom = 0 Then
			AreaToProcessBottom = SpreadsheetDocument.TableHeight;
		EndIf;
		
		If AreaToProcessLeft = 0 Then
			AreaToProcessLeft = 1;
		EndIf;
		
		If AreaToProcessRight = 0 Then
			AreaToProcessRight = SpreadsheetDocument.TableWidth;
		EndIf;
		
		If AreaToProcess.AreaType = SpreadsheetDocumentCellAreaType.Columns Then
			AreaToProcessTop = AreaToProcess.Bottom;
			AreaToProcessBottom = SpreadsheetDocument.TableHeight;
		EndIf;
			
		For ColumnNumber = AreaToProcessLeft To AreaToProcessRight Do
			ColumnWidth = Undefined;
			For LineNumber = AreaToProcessTop To AreaToProcessBottom Do
				Cell = SpreadsheetDocument.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
				If AreaToProcess.AreaType = SpreadsheetDocumentCellAreaType.Columns Then
					If ColumnWidth = Undefined Then
						ColumnWidth = Cell.ColumnWidth;
					EndIf;
					If Cell.ColumnWidth <> ColumnWidth Then
						Continue;
					EndIf;
				EndIf;
				If Cell.Font <> Undefined Then
					Result.Add(Cell);
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure CloseFormAfterWriteSpreadsheetDocument(Close, AdditionalParameters) Export
	If Close Then
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure WriteSpreadsheetDocument(CompletionHandler = Undefined, UnlockFile = False)

	ClearHighlight();
	
	ThereIsARef = ValueIsFilled(Parameters.Ref);
	If IsNew() And Not IsTemplate And Not ThereIsARef Or EditingDenied Then
		StartFileSavingDialog(CompletionHandler, UnlockFile);
		Return;
	EndIf;
		
	WriteSpreadsheetDocumentFileNameSelected(CompletionHandler, UnlockFile);
	
EndProcedure

&AtClient
Procedure WriteSpreadsheetDocumentFileNameSelected(Val CompletionHandler, UnlockFile)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CompletionHandler", CompletionHandler);
	AdditionalParameters.Insert("UnlockFile", UnlockFile);
	
	If IsBlankString(Parameters.PathToFile) Then
		TemplateAddressInTempStorage = "";
		AdditionalParameters.Insert("TemplateAddressInTempStorage", TemplateAddressInTempStorage);
		ClearMessages();
		
		If WriteTemplate(True, AdditionalParameters.TemplateAddressInTempStorage) Then
			AfterWriteSpreadsheetDocument(AdditionalParameters.CompletionHandler, UnlockFile);
		Else
			NotifyDescription = New NotifyDescription("ContinueWritingTabularDocument", ThisObject, AdditionalParameters);
			ShowQueryBox(NotifyDescription, NStr("en = 'Some entries are invalid. Save the template anyway?';"), QuestionDialogMode.YesNo, , DialogReturnCode.No);
		EndIf;
	Else
		SpreadsheetDocument.BeginWriting(
			New NotifyDescription("ProcessSpreadsheetDocumentWritingResult", ThisObject, AdditionalParameters),
			Parameters.PathToFile);
	EndIf;
	
EndProcedure

&AtClient
Procedure ContinueWritingTabularDocument(DialogResult, AdditionalParameters) Export
	
	If DialogResult = DialogReturnCode.Yes Then
		WriteTemplate(False, AdditionalParameters.TemplateAddressInTempStorage);
		AfterWriteSpreadsheetDocument(AdditionalParameters.CompletionHandler, AdditionalParameters.UnlockFile);
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessSpreadsheetDocumentWritingResult(Result, AdditionalParameters) Export 
	If Result <> True Then 
		Return;
	EndIf;
	
	EditingDenied = False;
	AfterWriteSpreadsheetDocument(AdditionalParameters.CompletionHandler, AdditionalParameters.UnlockFile);
EndProcedure

&AtClient
Procedure AfterWriteSpreadsheetDocument(CompletionHandler, UnlockFile)
	WritingCompleted = True;
	Modified = False;
	SetHeader();
	TemplateSavedLangs.Add(CurrentLanguage);
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		If ValueIsFilled(Parameters.AttachedFile) Then
			ModuleFilesOperationsInternalClient = CommonClient.CommonModule("FilesOperationsInternalClient");
			If UnlockFile Then
				FileUpdateParameters = ModuleFilesOperationsInternalClient.FileUpdateParameters(
					CompletionHandler, Parameters.AttachedFile, UUID);
				ModuleFilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
			Else
				ModuleFilesOperationsInternalClient.SaveFileChangesWithNotification(CompletionHandler, 
					Parameters.AttachedFile, UUID);
			EndIf;
			Return;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(CompletionHandler, True);
EndProcedure

&AtClient
Procedure StartFileSavingDialog(Val CompletionHandler, UnlockFile)
	
	Var SaveFileDialog, NotifyDescription;
	
	SaveFileDialog = New FileDialog(FileDialogMode.Save);
	SaveFileDialog.FullFileName = CommonClientServer.ReplaceProhibitedCharsInFileName(DocumentName);
	SaveFileDialog.Filter = NStr("en = 'Spreadsheet documents';") + " (*.mxl)|*.mxl";
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CompletionHandler", CompletionHandler);
	AdditionalParameters.Insert("UnlockFile", UnlockFile);
		
	NotifyDescription = New NotifyDescription("OnCompleteFileSelectionDialog", ThisObject, AdditionalParameters);
	FileSystemClient.ShowSelectionDialog(NotifyDescription, SaveFileDialog);
	
EndProcedure

&AtClient
Procedure OnCompleteFileSelectionDialog(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	FullFileName = SelectedFiles[0];
	
	Parameters.PathToFile = FullFileName;
	DocumentName = Mid(FullFileName, StrLen(FileDetails(FullFileName).Path) + 1);
	If Lower(Right(DocumentName, 4)) = ".mxl" Then
		DocumentName = Left(DocumentName, StrLen(DocumentName) - 4);
	EndIf;
	
	WriteSpreadsheetDocumentFileNameSelected(AdditionalParameters.CompletionHandler, AdditionalParameters.UnlockFile);
	
EndProcedure

&AtClient
Function FileDetails(FullName)
	
	SeparatorPosition = StrFind(FullName, GetPathSeparator(), SearchDirection.FromEnd);
	
	Name = Mid(FullName, SeparatorPosition + 1);
	Path = Left(FullName, SeparatorPosition);
	
	ExtensionPosition = StrFind(Name, ".", SearchDirection.FromEnd);
	
	BaseName = Left(Name, ExtensionPosition - 1);
	Extension = Mid(Name, ExtensionPosition + 1);
	
	Result = New Structure;
	Result.Insert("FullName", FullName);
	Result.Insert("Name", Name);
	Result.Insert("Path", Path);
	Result.Insert("BaseName", BaseName);
	Result.Insert("Extension", Extension);
	
	Return Result;
	
EndFunction
	
&AtClient
Function NewDocumentName()
	Return NStr("en = 'New';");
EndFunction

&AtClient
Procedure SetHeader()
	
	Title = DocumentName;
	If ValueIsFilled(CurrentLanguage) Then
		CurrentLanguagePresentation = Items["Language_"+CurrentLanguage].Title; 
		Title = Title + " ("+CurrentLanguagePresentation+")";
	EndIf;
	
	If IsNew() Then
		Title = Title + " (" + NStr("en = 'Create';") + ")";
	ElsIf EditingDenied Then
		Title = Title + " (" + NStr("en = 'Read-only';") + ")";
	EndIf;
	
EndProcedure

&AtClient
Procedure SetUpCommandPresentation()
	
	DocumentIsBeingEdited = Items.SpreadsheetDocument.Edit;
	Items.Edit.Check = DocumentIsBeingEdited;
	Items.EditingCommands.Enabled = DocumentIsBeingEdited;
	Items.WriteAndClose.Enabled = DocumentIsBeingEdited Or Modified;
	Items.Write.Enabled = DocumentIsBeingEdited Or Modified;

	If DocumentIsBeingEdited And IsTemplate And Not IsPrintForm Then
		Items.Warning.Visible = True;
	EndIf;
	
	Items.Edit.Enabled = DocumentIsBeingEdited Or Not IsTemplate;
	Items.LoadFromFile.Enabled = DocumentIsBeingEdited Or Not IsTemplate;
	Items.StrikethroughAllActions.Enabled = DocumentIsBeingEdited Or Not IsTemplate;
	Items.CurrentValue.Enabled = DocumentIsBeingEdited;
	Items.ShowHeadersAndFooters.Enabled = DocumentIsBeingEdited;
	Items.Translate.Enabled = DocumentIsBeingEdited;
	SetAvailabilityRecursively(Items.EditingCommands);
	SetAvailabilityRecursively(Items.LangsToAdd, DocumentIsBeingEdited);
	
EndProcedure

&AtClient
Function IsNew()
	Return Not ValueIsFilled(Parameters.Ref) And IsBlankString(IdentifierOfTemplate) And IsBlankString(Parameters.PathToFile);
EndFunction

&AtClient
Procedure EditInExternalApplicationCompletion(ImportedSpreadsheetDocument, AdditionalParameters) Export
	If ImportedSpreadsheetDocument = Undefined Then
		Return;
	EndIf;
	
	Modified = True;
	UpdateSpreadsheetDocument(ImportedSpreadsheetDocument);
EndProcedure

&AtServer
Procedure UpdateSpreadsheetDocument(ImportedSpreadsheetDocument)
	FillSpreadsheetDocument(SpreadsheetDocument, ImportedSpreadsheetDocument);
EndProcedure

&AtServerNoContext
Procedure FillSpreadsheetDocument(SpreadsheetDocument, Val ImportedSpreadsheetDocument)
	For LineNumber = 1 To ImportedSpreadsheetDocument.TableHeight Do
		For ColumnNumber = 1 To ImportedSpreadsheetDocument.TableWidth Do
			OriginalCell = ImportedSpreadsheetDocument.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
			If OriginalCell.FillType <> SpreadsheetDocumentAreaFillType.Text Then
				SpreadsheetDocument = ImportedSpreadsheetDocument;
				Return;
			EndIf;
		EndDo;
	EndDo;
	
	SpreadsheetDocument.Clear();
	SpreadsheetDocument.Put(ImportedSpreadsheetDocument);
	
	
	SpreadsheetDocument.Header.LeftText = ImportedSpreadsheetDocument.Header.LeftText;
	SpreadsheetDocument.Header.CenterText = ImportedSpreadsheetDocument.Header.CenterText;
	SpreadsheetDocument.Header.RightText = ImportedSpreadsheetDocument.Header.RightText;
	SpreadsheetDocument.Footer.LeftText = ImportedSpreadsheetDocument.Footer.LeftText;
	SpreadsheetDocument.Footer.CenterText = ImportedSpreadsheetDocument.Footer.CenterText;
	SpreadsheetDocument.Footer.RightText = ImportedSpreadsheetDocument.Footer.RightText;
	
	For Each Area In SpreadsheetDocument.Areas Do
		If TypeOf(Area) = Type("SpreadsheetDocumentRange")
			And Area.AreaType = SpreadsheetDocumentCellAreaType.Rows
			Or TypeOf(Area) = Type("SpreadsheetDocumentDrawing") Then
				CopyArea = ImportedSpreadsheetDocument.Areas.Find(Area.Name);
				If CopyArea = Undefined Then
					Continue;
				EndIf;
				Area.DetailsParameter = CopyArea.DetailsParameter;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure SetInitialFormSettings()
	
	If Not IsBlankString(Parameters.PathToFile) And Not EditingDenied Then
		Items.SpreadsheetDocument.Edit = True;
	EndIf;
	
	SetDocumentName();
	SetHeader();
	SetUpCommandPresentation();
	SetUpSpreadsheetDocumentRepresentation();

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
Procedure OnCompleteGetReadOnly(Var_ReadOnly, AdditionalParameters) Export
	
	EditingDenied = Var_ReadOnly;
	SetInitialFormSettings();
	
EndProcedure

&AtClient
Procedure Attachable_SwitchLanguage(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManagerClient = CommonClient.CommonModule("PrintManagementClient");
		ModulePrintManagerClient.SwitchLanguage(ThisObject, Command);
		
		Items.DeleteLayoutLanguage.Visible = Not ValueIsFilled(Parameters.Ref) 
			Or CurrentLanguage <> CommonClient.DefaultLanguageCode();
			
		Items.ButtonShowHideOriginal.Enabled = SuppliedTemplate.TableHeight > 0;
		If IsPrintForm Then
			FillSpreadsheetDocument(SpreadsheetDocument, ReadLayout());
		EndIf;
		
		If CurrentLanguage = CommonClient.DefaultLanguageCode() Then
			Items.DeleteLayoutLanguage.Title = NStr("en = 'Delete all template changes';");
		Else
			Items.DeleteLayoutLanguage.Title = NStr("en = 'Delete template in current language';");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteLayoutLanguage(Command)
	
	DeleteLayoutInCurrentLanguage();

	WritingCompleted = True;
	NotifyAboutTheTableDocumentEntry();

	Items.DeleteLayoutLanguage.Visible = Not ValueIsFilled(Parameters.Ref)
		Or CurrentLanguage <> CommonClient.DefaultLanguageCode();
	
	SetHeader();
EndProcedure

&AtClient
Procedure Attachable_WhenSwitchingTheLanguage(LanguageCode, AdditionalParameters) Export
	
	SetHeader();
	LoadSpreadsheetDocumentFromMetadata(LanguageCode);
	If TranslationRequired And AutomaticTranslationAvailable Then
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Template has not been translated into the %1 language yet.
			|Do you want to translate it automatically?';"), Items.Language.Title);
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Translate';"));
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Do not translate';"));
		
		NotifyDescription = New NotifyDescription("WhenAnsweringAQuestionAboutTranslatingALayout", ThisObject);
		ShowQueryBox(NotifyDescription, QueryText, Buttons);
	EndIf;
	
EndProcedure

&AtClient
Procedure WhenAnsweringAQuestionAboutTranslatingALayout(Response, AdditionalParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	TranslateLayoutTexts();
	
EndProcedure

&AtServer
Procedure TranslateLayoutTexts()
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.TextTranslation") Then
		ModuleTranslationOfTextIntoOtherLanguages = Common.CommonModule("TextTranslationTool");
		ModuleTranslationOfTextIntoOtherLanguages.TranslateSpreadsheetTexts(SpreadsheetDocument, CurrentLanguage, Common.DefaultLanguageCode());
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure ShowHideOriginal(Command)
	
	Items.ButtonShowHideOriginal.Check = Not Items.ButtonShowHideOriginal.Check;
	Items.SuppliedTemplate.Visible = Items.ButtonShowHideOriginal.Check;
	If Items.ButtonShowHideOriginal.Check Then
		Items.SpreadsheetDocument.TitleLocation = FormItemTitleLocation.Auto;
	Else
		Items.SpreadsheetDocument.TitleLocation = FormItemTitleLocation.None;
	EndIf;
	
EndProcedure

&AtClient
Procedure SynchronizeTheLayoutViewport()
	
	If Not Items.SuppliedTemplate.Visible Then
		Return;
	EndIf;
	
	ManagedElement = Items.SuppliedTemplate;
	If CurrentItem <> Items.SpreadsheetDocument Then
		ManagedElement = Items.SpreadsheetDocument;
		CurrentItem = Items.SuppliedTemplate;
	EndIf;
	
	Area = CurrentItem.CurrentArea;
	If Area = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(Area) = Type("SpreadsheetDocumentRange") Then
		ManagedElement.CurrentArea = ThisObject[CurrentItem.Name].Area(
			Area.Top, Area.Left, Area.Bottom, Area.Right);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyAboutTheTableDocumentEntry()
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("PathToFile", Parameters.PathToFile);
	NotificationParameters.Insert("TemplateMetadataObjectName", IdentifierOfTemplate);
	NotificationParameters.Insert("LanguageCode", CurrentLanguage);
	NotificationParameters.Insert("Presentation", DocumentName);
	NotificationParameters.Insert("DataSources", DataSources.UnloadValues());
	
	If WritingCompleted Then
		EventName = "Write_SpreadsheetDocument";
	Else
		EventName = "CancelEditSpreadsheetDocument";
	EndIf;
	Notify(EventName, NotificationParameters, ThisObject);
	
	WritingCompleted = False;
	
EndProcedure

&AtServer
Procedure UnlockAtServer() 
	UnlockDataForEdit(KeyOfEditObject, UUID);
EndProcedure

&AtClient
Procedure ChangeFontCompletion(Result, Var_Parameters) Export 
	
	CurrentArea = Items.SpreadsheetDocument.CurrentArea;
	
	If Result = Undefined Then 
		Return;
	ElsIf Result = -1 Then 
		FontChooseDialog = New FontChooseDialog;
		NotifyDescription = New NotifyDescription("CompletionChangeFont", ThisObject);
		FontChooseDialog.Font = CurrentArea.Font;
		FontChooseDialog.Show(NotifyDescription);
	Else 
		CurrentArea.Font = New Font(CurrentArea.Font, Result);
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure CompletionChangeFont(Font, Var_Parameters) Export

	If Font = Undefined Then
		Return;
	EndIf;
	
	CurrentArea = Items.SpreadsheetDocument.CurrentArea;
	CurrentArea.Font = Font;
	Modified = True;
		
EndProcedure

&AtClient
Procedure ChangeBorderColorCompletion(Color, Var_Parameters) Export
	
	SpecifyColor("BorderColor", Color);
	
EndProcedure


&AtClient
Procedure ChangeTextColorCompletion(Color, Var_Parameters) Export
	
	SpecifyColor("TextColor", Color);
	
EndProcedure

&AtClient
Procedure ChangeBackgroundColorCompletion(Color, Var_Parameters) Export
	
	SpecifyColor("BackColor", Color);
	
EndProcedure

&AtClient
Procedure SpecifyColor(FieldName, Color)
	CurrentArea = Items.SpreadsheetDocument.CurrentArea;
	If TypeOf(Color) = Type("Color")Then
		CurrentArea[FieldName] = Color;
		Modified = True;
	ElsIf Color = "OtherColors" Then
		ColorChooseDialog = New ColorChooseDialog();
		NotifyDescription = New NotifyDescription("AfterColorSelected", ThisObject, FieldName);
		ColorChooseDialog.Show(NotifyDescription);
	EndIf;
EndProcedure

&AtClient
Procedure AfterColorSelected(Color, FieldName) Export
	SpecifyColor(FieldName, Color);
EndProcedure

#Region PrintableFormConstructor

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

&AtClient
Procedure SpreadsheetDocumentDrag(Item, DragParameters, StandardProcessing, Area)

	If CommonClient.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaClient = CommonClient.CommonModule("FormulasConstructorClient");
	
		If TypeOf(DragParameters.Value) <> Type("String") Then 
			Return;
		EndIf;
		
		SelectedField = ModuleConstructorFormulaClient.TheSelectedFieldInTheFieldList(ThisObject, NameOfTheFieldList());
		If SelectedField = Undefined Then
			Return;
		EndIf;
		
		PlaceFigureInSpreadsheetDocument(SelectedField, StandardProcessing, Area.Left, Area.Top);
		
		If StandardProcessing Then
			StandardProcessing = False;
			Area = SpreadsheetDocument.Area(Area.Top, Area.Left); // Get the area of the merged cells.
			Area.Text = ?(ValueIsFilled(Area.Text), TrimR(Area.Text) + " ", "") + DragParameters.Value;
		EndIf;
	EndIf;
	RecipientOfDraggedValue = Item;

EndProcedure

&AtServer
Procedure PlaceFigureInSpreadsheetDocument(SelectedField, StandardProcessing, Left, Top)
	
	Area = SpreadsheetDocument.Area(Top, Left, Top, Left);
	
	If StrStartsWith(SelectedField.Name, "Print") Then
		StandardProcessing = False;
		
		Drawing = SpreadsheetDocument.Drawings.Add(SpreadsheetDocumentDrawingType.Picture);
		Drawing.Name = PickupRegionName(SelectedField.Name);
		Drawing.DetailsParameter = "[" + SelectedField.DataPath + "]";
		Drawing.Picture = PictureLib["CompanySeal"];
		Drawing.Place(Area);
		Drawing.Height = 40;
		Drawing.Width = 40;
		Drawing.Line = New Line(SpreadsheetDocumentDrawingLineType.None);
		Drawing.BackColor = DefaultColor();
		Drawing.PictureSize = PictureSize.Proportionally;
		
		Items.SpreadsheetDocument.CurrentArea = Area;
		Return;
	EndIf;

	If StrStartsWith(SelectedField.Name, "Signature") Then
		StandardProcessing = False;
		Drawing = SpreadsheetDocument.Drawings.Add(SpreadsheetDocumentDrawingType.Picture);
		Drawing.Name = PickupRegionName(SelectedField.Name);
		Drawing.DetailsParameter = "[" + SelectedField.DataPath + "]";
		Drawing.Picture = PictureLib["Signature"];
		Drawing.Place(Area);
		Drawing.Height = 10;
		Drawing.Width = 30;
		Drawing.Line = New Line(SpreadsheetDocumentDrawingLineType.None);
		Drawing.BackColor = DefaultColor();
		Drawing.PictureSize = PictureSize.Proportionally;
		
		Items.SpreadsheetDocument.CurrentArea = Area;
		Return;
	EndIf;
	
	If SelectedField.Name = "DSStamp" Then
		StandardProcessing = False;

		RowArea_ = SpreadsheetDocument.Area(Area.Top, , Area.Top + 6);
		RowArea_.CreateFormatOfRows();
		
		StampArea = SpreadsheetDocument.Area(Area.Top, Area.Left, Area.Top + 6, Area.Left + 1);
		StampArea.Name = PickupRegionName("DSStamp");
		
		StampArea = SpreadsheetDocument.Area(Area.Top, Area.Left, Area.Top + 6, Area.Left);
		StampArea.ColumnWidth = 10;
		StampArea = SpreadsheetDocument.Area(Area.Top, Area.Left + 1, Area.Top + 6, Area.Left + 1);
		StampArea.ColumnWidth = 30;
		
		Items.SpreadsheetDocument.CurrentArea = Area;
		Return;
	EndIf;
	
	If SelectedField.Name = "QRCode" Then
		StandardProcessing = False;
		
		Drawing = SpreadsheetDocument.Drawings.Add(SpreadsheetDocumentDrawingType.Picture);
		Drawing.Name = PickupRegionName(SelectedField.Name);
		Drawing.DetailsParameter = "[" + SelectedField.DataPath + "]";
		Drawing.Place(Area);
		Drawing.Height = 40;
		Drawing.Width = 40;
		Drawing.Line = New Line(SpreadsheetDocumentDrawingLineType.None);
		Drawing.BackColor = DefaultColor();
		Drawing.PictureSize = PictureSize.Proportionally;
		Drawing.Picture = PictureLib["PlaceForQRCode"];
		
		Items.SpreadsheetDocument.CurrentArea = Area;
		Return;
	EndIf;
	
	If SelectedField.Name = "BarcodeIcon" Then
		StandardProcessing = False;
		
		Drawing = SpreadsheetDocument.Drawings.Add(SpreadsheetDocumentDrawingType.Picture);
		Drawing.Name = PickupRegionName(SelectedField.Name);
		Drawing.DetailsParameter = "[" + SelectedField.DataPath + "]";
		Drawing.Place(Area);
		Drawing.Height = 25.93;
		Drawing.Width = 37.29;
		Drawing.Line = New Line(SpreadsheetDocumentDrawingLineType.None);
		Drawing.BackColor = DefaultColor();
		Drawing.PictureSize = PictureSize.Proportionally;
		Drawing.Picture = PictureLib["PlaceForBarCode"];
		
		Items.SpreadsheetDocument.CurrentArea = Area;
		Return;
	EndIf;
	
	ThisisAttachedFile = SelectedField.Type.Types().Count() = 1
		And AttachedFilesTypes.ContainsType(SelectedField.Type.Types()[0]);
		
	If ThisisAttachedFile Then
		StandardProcessing = False;
		
		Drawing = SpreadsheetDocument.Drawings.Add(SpreadsheetDocumentDrawingType.Picture);
		Drawing.Name = PickupRegionName("Drawing");
		Drawing.DetailsParameter = "[" + SelectedField.DataPath + "]";
		Drawing.Picture = PictureLib["PlaceForPicture"];
		Drawing.Place(Area);
		Drawing.Height = 20;
		Drawing.Width = 20;
		Drawing.Line = New Line(SpreadsheetDocumentDrawingLineType.None);
		Drawing.BackColor = DefaultColor();
		Drawing.PictureSize = PictureSize.Proportionally;
		
		Items.SpreadsheetDocument.CurrentArea = Area;
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure SpreadsheetDocumentDragCheck(Item, DragParameters, StandardProcessing, Area)

	If TypeOf(DragParameters.Value) <> Type("Array")
		Or DragParameters.Value.Count() <> 1 
		Or Not DragParameters.Value[0].Table Then
		Return;
	EndIf;
	
	ColumnsCount = DragParameters.Value[0].Items.Count();
	If ColumnsCount = 0 Then
		AreaWidth = ?(Area.Left > 1, 2, 1);
		Area = SpreadsheetDocument.Area(Area.Top, Area.Left, Area.Top, Area.Left + AreaWidth - 1);
		Item.CurrentArea = Area;
		Return;
	EndIf;
	
	StandardProcessing = False;
	Area = SpreadsheetDocument.Area(Area.Top, Area.Left, Area.Top + 1, Area.Left + ColumnsCount - 1);
	Item.CurrentArea = Area;
	
EndProcedure

&AtClient
Procedure UpdateInputFieldCurrentCellValue()
	
	CurrentArea = SpreadsheetDocument.CurrentArea;
	EditingAvailable = Items.SpreadsheetDocument.Edit And CurrentArea <> Undefined 
		And TypeOf(CurrentArea) = Type("SpreadsheetDocumentRange");
	Items.CurrentValue.Enabled = EditingAvailable;
	If EditingAvailable Then
		CurrentValue = CurrentArea.Text;
	Else
		CurrentValue = "";
	EndIf;
	
	Items.RepeatAtTopofPage.Enabled = False;
	Items.RepeatAtEndPage.Enabled = False;
	
	ViewArea = NStr("en = 'Text of the selected cell';");
	If TypeOf(CurrentArea) = Type("SpreadsheetDocumentRange") Then
		If CurrentArea.AreaType = SpreadsheetDocumentCellAreaType.Rows
			And ValueIsFilled(CurrentArea.Top) Then
			Span = CurrentArea.Top;
			If CurrentArea.Top <> CurrentArea.Bottom Then
				Span = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1-%2';"), CurrentArea.Top, CurrentArea.Bottom);
				ViewArea = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Output conditions for rows %1';"), Span);
			Else
				ViewArea = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Output conditions for row %1';"), Span);
			EndIf;
			Items.RepeatAtTopofPage.Enabled = True;
			Items.RepeatAtEndPage.Enabled = True;
			
			If ValueIsFilled(CurrentArea.Name) Then
				CurrentValue = CurrentArea.DetailsParameter;
			EndIf;
		EndIf;
		If ValueIsFilled(CurrentArea.Left) And Not ValueIsFilled(CurrentArea.Top) Then
			Span = CurrentArea.Left;
			If CurrentArea.Left <> CurrentArea.Right Then
				Span = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1-%2';"), CurrentArea.Left, CurrentArea.Right);
				ViewArea = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Output conditions for columns %1';"), Span);
			Else
				ViewArea = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Output conditions for column %1';"), Span);
			EndIf;
		EndIf;
		If ValueIsFilled(CurrentArea.Left) And ValueIsFilled(CurrentArea.Top) Then
			If CurrentArea.Left <> CurrentArea.Right Or CurrentArea.Top <> CurrentArea.Bottom Then
				ViewArea = NStr("en = 'Text in the selected area';");
			Else
				ViewArea = NStr("en = 'Text of the selected cell';");
			EndIf;
		EndIf;
		AreaName = ViewArea;
	EndIf;
	
	Items.DeleteStampEP.Enabled = TypeOf(CurrentArea) = Type("SpreadsheetDocumentRange")
		And StrStartsWith(CurrentArea.Name, "DSStamp");
	
	If TypeOf(CurrentArea) = Type("SpreadsheetDocumentRange")
		And CurrentArea.AreaType = SpreadsheetDocumentCellAreaType.Rows Then
			Items.RepeatAtTopofPage.Check = CurrentArea.PageTop;
			Items.RepeatAtEndPage.Check = CurrentArea.PageBottom;
	Else
		Items.RepeatAtTopofPage.Check = False;
		Items.RepeatAtEndPage.Check = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure PickupSample(MetadataObject)
	
	QueryText =
	"SELECT TOP 1 ALLOWED
	|	SpecifiedTableAlias.Ref AS Ref
	|FROM
	|	&Table AS SpecifiedTableAlias
	|
	|ORDER BY
	|	Ref DESC";
	
	QueryText = StrReplace(QueryText, "&Table", MetadataObject.FullName());
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Pattern = Selection.Ref;
	EndIf;
	
EndProcedure

&AtClient
Procedure CustomizeHeadersFooters(Command)
	
	Items.ShowHeadersAndFooters.Check = Not Items.ShowHeadersAndFooters.Check;
	Items.Header.Visible = Items.ShowHeadersAndFooters.Check;
	Items.Footer.Visible = Items.ShowHeadersAndFooters.Check;
	Items.EditingCommands.Visible = Not Items.EditingCommands.Visible;
	Items.CommandPanelFooterPanel.Visible = Not Items.EditingCommands.Visible;
	Items.CurrentValue.Visible = Not Items.ShowHeadersAndFooters.Check;
	Items.SettingsCurrentRegion.Visible = Not Items.ShowHeadersAndFooters.Check;
	Items.SpreadsheetDocument.ReadOnly = Items.ShowHeadersAndFooters.Check;
		
	StateText = ?(Items.ShowHeadersAndFooters.Check, NStr("en = 'Edit headers and footers';"), "");
	DisplayCurrentPrintFormState(StateText);
	
	If Items.ShowHeadersAndFooters.Check Then
		ToggleVisibilityCommandsFooters();
	Else
		DetachIdleHandler("ToggleVisibilityCommandsFooters");
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearFormat(Command)
	CurrentArea = Items.SpreadsheetDocument.CurrentArea;
	CurrentArea.Font 		= Undefined;
	CurrentArea.BorderColor 	= DefaultColor();
	CurrentArea.TextColor 	= DefaultColor();
	CurrentArea.PatternColor 	= DefaultColor();
	CurrentArea.BackColor 	= DefaultColor();
	CurrentArea.VerticalAlign 			= Undefined;
	CurrentArea.PictureVerticalAlign 	= Undefined;
	CurrentArea.HorizontalAlign			= Undefined;
	CurrentArea.PictureHorizontalAlign	= Undefined;
	Modified = True;
EndProcedure

&AtClientAtServerNoContext
Function DefaultColor()
	Return New Color;
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

&AtClient
Procedure HighlightCellsWithSelectedField()
	
	CurrentData = Items[NameOfTheFieldList()].CurrentData;
	If CurrentData = Undefined Or Not ValueIsFilled(CurrentData.RepresentationOfTheDataPath) Then
		Return;
	EndIf;
	
	ClearHighlight();
	TreatedAreas = New Map();
	
	ModulePrintManagerClient = Undefined;
	If CommonClient.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManagerClient = CommonClient.CommonModule("PrintManagementClient");
	Else
		Return;
	EndIf;
	
	For LineNumber = 1 To SpreadsheetDocument.TableHeight Do
		For ColumnNumber = 1 To SpreadsheetDocument.TableWidth Do
			Area = SpreadsheetDocument.Area(LineNumber, ColumnNumber);

			AreaID = ModulePrintManagerClient.AreaID(Area);
			If TreatedAreas[AreaID] <> Undefined Then
				Continue;
			EndIf;
			TreatedAreas[AreaID] = True;
			
			If CurrentData.Table
				And StrFind(Area.Text, "[" + CurrentData.RepresentationOfTheDataPath + ".") > 0
				Or StrFind(Area.Text, "[" + CurrentData.RepresentationOfTheDataPath + "]") > 0 Then
				HighlightedRegions.Add(Area.BackColor, Area.Name);
				Area.BackColor = FieldSelectionBackColor;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearHighlight()
	
	For Each Item In HighlightedRegions Do
		BackColor = Item.Value;
		AreaName = Item.Presentation;
		
		Area = SpreadsheetDocument.Area(AreaName);
		Area.BackColor = BackColor;
	EndDo;
	
	HighlightedRegions.Clear();
	
EndProcedure

&AtClient
Procedure AvailableFields(Command)
	
	Items.ButtonAvailableFields.Check = Not Items.ButtonAvailableFields.Check;
	Items.FieldsAndOperatorsGroup.Visible = Items.ButtonAvailableFields.Check;
	
EndProcedure

&AtClient
Procedure DisplayCurrentPrintFormState(StateText = "")
	
	ShowStatus = Not IsBlankString(StateText);
	
	SpreadsheetDocumentField = Items.SpreadsheetDocument;
	
	StatePresentation = SpreadsheetDocumentField.StatePresentation;
	StatePresentation.Text = StateText;
	StatePresentation.Visible = ShowStatus;
	StatePresentation.AdditionalShowMode = 
		?(ShowStatus, AdditionalShowMode.Irrelevance, AdditionalShowMode.DontUse);
		
	SpreadsheetDocumentField.ReadOnly = ShowStatus Or SpreadsheetDocumentField.Output = UseOutput.Disable;
	
EndProcedure

&AtClient
Procedure UpdateAreaSettingsSelectedCells()
	UpdateInputFieldCurrentCellValue();
EndProcedure

&AtClient
Procedure RepeatOnEachPage(Command)
	
	CurrentArea = SpreadsheetDocument.CurrentArea;
	If CurrentArea = Undefined Or TypeOf(CurrentArea) <> Type("SpreadsheetDocumentRange")
		Or CurrentArea.AreaType <> SpreadsheetDocumentCellAreaType.Rows Then
		Return;
	EndIf;

	Items.RepeatAtTopofPage.Check = Not Items.RepeatAtTopofPage.Check;
	CurrentArea.PageTop = Items.RepeatAtTopofPage.Check;
	
EndProcedure

&AtClient
Procedure RepeatAtEndPage(Command)
	
	CurrentArea = SpreadsheetDocument.CurrentArea;
	If CurrentArea = Undefined Or TypeOf(CurrentArea) <> Type("SpreadsheetDocumentRange")
		Or CurrentArea.AreaType <> SpreadsheetDocumentCellAreaType.Rows Then
		Return;
	EndIf;

	Items.RepeatAtEndPage.Check = Not Items.RepeatAtEndPage.Check;
	CurrentArea.PageBottom = Items.RepeatAtEndPage.Check;
	
EndProcedure

&AtClient
Procedure CurrentValueOnChange(Item)
	
	UpdateTextInCellsArea();
	RecipientOfDraggedValue = Item;
	
EndProcedure

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

&AtServer
Function ListOfOperators()
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		Return ModulePrintManager.ListOfOperators();
	EndIf;
	
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
		
		If FillParameters.ListName = NameOfTheFieldList() Then
			CurrentData = ThisObject[FillParameters.ListName].FindByID(FillParameters.RowID);
			SetExamplesValues(CurrentData);
			SetFormatValuesDefault(CurrentData);
			If (CurrentData.Folder Or CurrentData.Table) And CurrentData.GetParent() = Undefined Then
				MarkCommonFields(CurrentData);
			Else
				SetCommonFIeldFlagForSubordinateFields(CurrentData);
			EndIf;
		EndIf
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ListOfFieldsStartDragging(Item, DragParameters, Perform)
	
	Attribute = ThisObject[NameOfTheFieldList()].FindByID(DragParameters.Value);
	
	If Attribute.Folder Or Attribute.Table 
		Or Items.ShowHeadersAndFooters.Check
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
	
	If CommonClient.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaClient = CommonClient.CommonModule("FormulasConstructorClient");
		ModuleConstructorFormulaClient.SearchStringClearing(ThisObject, Item, StandardProcessing);
	EndIf;
	
EndProcedure

&AtServer
Procedure Attachable_FormulaEditorHandlerServer(Parameter, AdditionalParameters) // ACC:1412 - The parameters return to the client.
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
Procedure Attachable_FormulaEditorHandlerClient(Parameter, AdditionalParameters = Undefined) Export // ACC:78 - Procedure is called from FormulaConstructorClient.StartSearchInFieldsList.
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
		
		UpdateTextInCellsArea();
	EndIf;
	
	If Field = Items[NameOfTheFieldList() + "ButtonSettingsFormat"] And ValueIsFilled(Items[NameOfTheFieldList()].CurrentData.Format) Then
		StandardProcessing = False;
		Designer = New FormatStringWizard(Items[NameOfTheFieldList()].CurrentData.Format);
		Designer.AvailableTypes = Items[NameOfTheFieldList()].CurrentData.Type;
		NotifyDescription = New NotifyDescription("WhenFormatFieldSelection", ThisObject);
		Designer.Show(NotifyDescription);
	EndIf;	
	
EndProcedure

&AtClient
Procedure Attachable_OperatorsDragStart(Item, DragParameters, Perform)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaClient = CommonClient.CommonModule("FormulasConstructorClient");
		
		Operator = ModuleConstructorFormulaClient.TheSelectedFieldInTheFieldList(ThisObject, NameOfTheListOfOperators());
		DragParameters.Value = ModuleConstructorFormulaClient.ExpressionToInsert(Operator);
		If Operator.DataPath = "PrintControl_NumberofLines" Then
			CurrentTablePresentation = CurrentTablePresentation();
			Perform = CurrentTablePresentation <> Undefined;
			DragParameters.Value = StrReplace(DragParameters.Value, "()", "(["+CurrentTablePresentation+"])");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_OperatorsDragEnd(Item, DragParameters, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaClient = CommonClient.CommonModule("FormulasConstructorClient");
		SelectedField = ModuleConstructorFormulaClient.TheSelectedFieldInTheFieldList(ThisObject, NameOfTheListOfOperators());
		Context = New Structure("DataPath, Title");
		FillPropertyValues(Context, SelectedField);
		
		If Context.DataPath = "Format" Then
			RowFormat = New FormatStringWizard;
			Context.Insert("RowFormat", RowFormat);
			NotificationOfDraggingEndCompletion = New NotifyDescription("OperatorsDragEndCompletion", ThisObject, Context);
			RowFormat.Show(NotificationOfDraggingEndCompletion);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OperatorsDragEndCompletion(Text, Context) Export
	
	If Text = Undefined Then
		Return;
	EndIf;
	
	TextsToReplace = New Structure("ForSearch, ForReplacement", "", "");
	
	If Context.DataPath = "Format" Then
		RowFormat = Context.RowFormat;
		If ValueIsFilled(RowFormat.Text) Then
			TextsToReplace.ForReplacement = Context.Title + "( , """ + RowFormat.Text + """)";
			TextsToReplace.ForSearch = Context.Title + "(,,)";
		EndIf;
	EndIf;
	
	WaitHanderParametersAddress = PutToTempStorage(TextsToReplace, UUID);
	
	AttachIdleHandler("SetValAfterDragging", 0.1, True);
	
EndProcedure

#EndRegion

&AtClient
Procedure SetValAfterDragging()
	
	TextsToReplace = GetFromTempStorage(WaitHanderParametersAddress);
	
	If RecipientOfDraggedValue = Items.CurrentValue Or RecipientOfDraggedValue = Undefined Then
		Items.CurrentValue.SelectedText = TextsToReplace.ForReplacement;
	Else
		CurrentAttribute = ThisObject[RecipientOfDraggedValue.Name];
		If TypeOf(CurrentAttribute) = Type("FormattedDocument") Then
			TextToPlace = StrReplace(CurrentAttribute.GetText(), TextsToReplace.ForSearch, TextsToReplace.ForReplacement);
			FormattedText = New FormattedString(TextToPlace);
			CurrentAttribute.Delete();
			CurrentAttribute.SetFormattedString(FormattedText);
		ElsIf TypeOf(CurrentAttribute) = Type("SpreadsheetDocument") Then
			CurrentAttribute.CurrentArea.Text = StrReplace(CurrentAttribute.CurrentArea.Text, TextsToReplace.ForSearch, TextsToReplace.ForReplacement);
		Else
			CurrentAttribute = StrReplace(CurrentAttribute, TextsToReplace.ForSearch, TextsToReplace.ForReplacement);
		EndIf;
	EndIf;
	RecipientOfDraggedValue = Undefined;
EndProcedure

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
	TemplateParameters1.Insert("TemplateType", "MXL");
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.WriteTemplatesInAdditionalLangs(TemplateParameters1);
	EndIf;
	
EndProcedure

&AtServer
Function PrepareLayoutForRecording(SetLanguageCode = True, Cancel = False)

	LanguageCode = Undefined;
	If SetLanguageCode Then
		LanguageCode = SpreadsheetDocument.LanguageCode;
	EndIf;
	
	Template = CopySpreadsheetDocument(SpreadsheetDocument, LanguageCode);
	If Not IsPrintForm Then
		Return Template;
	EndIf;
	
	TreatedAreas = New Map();
	
	For LineNumber = 1 To Template.TableHeight Do
		For ColumnNumber = 1 To Template.TableWidth Do
			Area = Template.Area(LineNumber, ColumnNumber);
			
			If Common.SubsystemExists("StandardSubsystems.Print") Then
				ModulePrintManager = Common.CommonModule("PrintManagement");
				AreaID = ModulePrintManager.AreaID(Area);
				If TreatedAreas[AreaID] <> Undefined Then
					Continue;
				EndIf;
				TreatedAreas[AreaID] = True;
			EndIf;
			
			If ValueIsFilled(Area.Text) Then
				FieldPresentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'string %1 column %2';"), LineNumber, ColumnNumber);
				ReplaceViewParameters(Area.Text, , Cancel, FieldPresentation);
			EndIf;
			
		EndDo;
	EndDo;
	
	ReplaceViewParameters(Template.Header.LeftText, "TopLeftText", Cancel, NStr("en = 'header on the left';"));
	ReplaceViewParameters(Template.Header.CenterText, "TopMiddleText", Cancel, NStr("en = 'header in the center';"));
	ReplaceViewParameters(Template.Header.RightText, "TopRightText", Cancel, NStr("en = 'header on the right';"));
	ReplaceViewParameters(Template.Footer.LeftText, "BottomLeftText", Cancel, NStr("en = 'footer on the left';"));
	ReplaceViewParameters(Template.Footer.CenterText, "BottomCenterText", Cancel, NStr("en = 'footer in the center';"));
	ReplaceViewParameters(Template.Footer.RightText, "BottomRightText", Cancel, NStr("en = 'footer on the right';"));
	
	For Each Area In Template.Areas Do
		If TypeOf(Area) = Type("SpreadsheetDocumentRange")
			And Area.AreaType = SpreadsheetDocumentCellAreaType.Rows Then
			Area.DetailsParameter = TheFormulaFromTheView(Area.DetailsParameter);
		EndIf;
	EndDo;
	
	Return Template;
	
EndFunction

&AtServer
Procedure ReplaceViewParameters(String, Field = Undefined, Cancel = False, FieldPresentation = "")
	
	ReplacementParameters = FormulasFromText(String(String));
	
	For Each Parameter In ReplacementParameters Do
		Formula = Parameter.Key;
		If StrOccurrenceCount(Formula, "[") > 1 Then
			Formula = Mid(Formula, 2, StrLen(Formula) - 2);
		EndIf;		
		
		ErrorText = "";
		If Common.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
			ModuleConstructorFormulaInternal = Common.CommonModule("FormulasConstructorInternal");
			ErrorText = ModuleConstructorFormulaInternal.CheckFormula(ThisObject, Formula);
		EndIf;
			
		If ValueIsFilled(ErrorText) Then
			If ValueIsFilled(FieldPresentation) Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1 (%2)';"),
					ErrorText,
					FieldPresentation);
			EndIf;
			
			Common.MessageToUser(ErrorText, , Field, , Cancel);
		EndIf;
	EndDo;
	
	If TypeOf(String) = Type("FormattedString") Then
		String = ReplaceInFormattedString(String, ReplacementParameters);
	Else
		String = ReplaceInline(String, ReplacementParameters);
	EndIf;
	
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
Function ReplaceInFormattedString(String, ReplacementParameters)

	FormattedDocument = New FormattedDocument;
	FormattedDocument.SetFormattedString(String);
	
	For Each Item In ReplacementParameters Do
		SearchSubstring = Item.Key;
		ReplaceSubstring = Item.Value;

		FoundArea = FormattedDocument.FindText(SearchSubstring);
		While FoundArea <> Undefined Do
			Particles = FormattedDocument.GenerateItems(FoundArea.BeginBookmark, FoundArea.EndBookmark);
			For IndexOf = 1 To Particles.UBound() Do
				Particles[0].Text = Particles[0].Text + Particles[IndexOf].Text;
				Particles[IndexOf].Text = "";
			EndDo;
			Particles[0].Text = StrReplace(Particles[0].Text, SearchSubstring, ReplaceSubstring);
	
			FoundArea = FormattedDocument.FindText(SearchSubstring, FoundArea.EndBookmark);
		EndDo;
	EndDo;
	
	Return FormattedDocument.GetFormattedString();

EndFunction

&AtServer
Function FormulasFromText(Val Text)
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		Return ModulePrintManager.FormulasFromText(Text, ThisObject);
	EndIf;
	
EndFunction

&AtServer
Function TheFormulaFromTheView(Presentation)
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		Return ModulePrintManager.TheFormulaFromTheView(ThisObject, Presentation);
	EndIf;
	
	Return Presentation;
	
EndFunction

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
Function ReadLayout(BinaryData = Undefined)
	
	LanguageCode = SpreadsheetDocument.LanguageCode;
	
	If BinaryData <> Undefined Then
		SpreadsheetDocument.LanguageCode = Undefined;
		SpreadsheetDocument.Read(BinaryData.OpenStreamForRead());
	EndIf;
	
	Template = CopySpreadsheetDocument(SpreadsheetDocument, LanguageCode);
	
	If Not IsPrintForm Then
		Return Template;
	EndIf;
	
	TreatedAreas = New Map();
	
	For LineNumber = 1 To Template.TableHeight Do
		For ColumnNumber = 1 To Template.TableWidth Do
			Area = Template.Area(LineNumber, ColumnNumber);

			If Common.SubsystemExists("StandardSubsystems.Print") Then
				ModulePrintManager = Common.CommonModule("PrintManagement");
				AreaID = ModulePrintManager.AreaID(Area);
				If TreatedAreas[AreaID] <> Undefined Then
					Continue;
				EndIf;
				TreatedAreas[AreaID] = True;
			EndIf;
			
			If ValueIsFilled(Area.Text) Then
				ReplaceParametersWithViews(Area.Text);
			EndIf;
		EndDo;
	EndDo;
	
	ReplaceParametersWithViews(Template.Header.LeftText);
	ReplaceParametersWithViews(Template.Header.CenterText);
	ReplaceParametersWithViews(Template.Header.RightText);
	ReplaceParametersWithViews(Template.Footer.LeftText);
	ReplaceParametersWithViews(Template.Footer.CenterText);
	ReplaceParametersWithViews(Template.Footer.RightText);
	
	For Each Area In Template.Areas Do
		If TypeOf(Area) = Type("SpreadsheetDocumentRange")
			And Area.AreaType = SpreadsheetDocumentCellAreaType.Rows Then
			Area.DetailsParameter = FormulaPresentation(Area.DetailsParameter);
		EndIf;
	EndDo;
	
	Return Template;
	
EndFunction

&AtServer
Procedure ReplaceParametersWithViews(String)
	
	ReplacementParameters = RepresentationTextParameters(String(String));
	
	If TypeOf(String) = Type("FormattedString") Then
		String = ReplaceInFormattedString(String, ReplacementParameters);
	Else
		String = ReplaceInline(String, ReplacementParameters);
	EndIf;
	
EndProcedure

&AtServer
Function FormulaPresentation(Val Formula)
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		Return ModulePrintManager.FormulaPresentation(ThisObject, Formula);
	EndIf;
	
	Return Formula;
	
EndFunction

// Returns:
//  SpreadsheetDocument
//
&AtServerNoContext
Function CopySpreadsheetDocument(SpreadsheetDocument, LanguageCode)
	
	Result = New SpreadsheetDocument;
	Result.Template = SpreadsheetDocument.Template;
	Result.LanguageCode = LanguageCode;
	Result.Put(SpreadsheetDocument);
	
	SystemInfo = New SystemInfo;
	HasRowsFormat = CommonClientServer.CompareVersions(SystemInfo.AppVersion, "8.3.22.1923") >= 0;
	
	ProcessedCells = New Map;
	For LineNumber = 1 To SpreadsheetDocument.TableHeight Do
		For ColumnNumber = 1 To SpreadsheetDocument.TableWidth Do
			CellToCopy = SpreadsheetDocument.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
			
			If Common.SubsystemExists("StandardSubsystems.Print") Then
				ModulePrintManager = Common.CommonModule("PrintManagement");
				AreaID = ModulePrintManager.AreaID(CellToCopy);
				If ProcessedCells[AreaID] <> Undefined Then
					Continue;
				EndIf;
				ProcessedCells[AreaID] = True;
			EndIf;
			
			If CellToCopy.FillType = SpreadsheetDocumentAreaFillType.Text Then
				Continue;
			EndIf;
			
			Cell = Result.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
			FillPropertyValues(Cell, CellToCopy, , ?(HasRowsFormat, "RowsFormat", Undefined));
			
			If CellToCopy.FillType = SpreadsheetDocumentAreaFillType.Template Then
				Cell.Text = CellToCopy.Text;
			EndIf;
		EndDo;
	EndDo;
	
	Result.Header.LeftText = SpreadsheetDocument.Header.LeftText;
	Result.Header.CenterText = SpreadsheetDocument.Header.CenterText;
	Result.Header.RightText = SpreadsheetDocument.Header.RightText;
	Result.Footer.LeftText = SpreadsheetDocument.Footer.LeftText;
	Result.Footer.CenterText = SpreadsheetDocument.Footer.CenterText;
	Result.Footer.RightText = SpreadsheetDocument.Footer.RightText;
	
	For Each Area In Result.Areas Do
		If TypeOf(Area) = Type("SpreadsheetDocumentRange")
			And Area.AreaType = SpreadsheetDocumentCellAreaType.Rows
			Or TypeOf(Area) = Type("SpreadsheetDocumentDrawing") 
			And Area.DrawingType <> SpreadsheetDocumentDrawingType.Group Then
				CopyArea = SpreadsheetDocument.Areas.Find(Area.Name);
				If CopyArea = Undefined Then
					Continue;
				EndIf;
				Area.DetailsParameter = CopyArea.DetailsParameter;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction	

&AtClientAtServerNoContext
Procedure ReadTextInFooterField(Val Text, HeaderOrFooter)
	
	FormattedString = Text;
	If TypeOf(Text)  = Type("String") Then
		FormattedString = New FormattedString(Text);
	EndIf;

	HeaderOrFooter.SetFormattedString(FormattedString);
	
EndProcedure

&AtClient
Procedure ToggleVisibilityCommandsFooters()
	
	If CurrentItem = Items.TopLeftText
		Or CurrentItem = Items.TopMiddleText
		Or CurrentItem = Items.TopRightText
		Or CurrentItem = Items.BottomLeftText
		Or CurrentItem = Items.BottomCenterText
		Or CurrentItem = Items.BottomRightText Then
	
		ToggleItemVisibility(Items.CommandsTextLeftHeader, CurrentItem = Items.TopLeftText);
		ToggleItemVisibility(Items.CommandsTextInCenterHeader, CurrentItem = Items.TopMiddleText);
		ToggleItemVisibility(Items.CommandsTextHeaderRight, CurrentItem = Items.TopRightText);

		ToggleItemVisibility(Items.CommandsTextLeftFooter, CurrentItem = Items.BottomLeftText);
		ToggleItemVisibility(Items.CommandsTextInCenterFooter, CurrentItem = Items.BottomCenterText);
		ToggleItemVisibility(Items.CommandsTextFooterRight, CurrentItem = Items.BottomRightText);
	
	EndIf;
	
	AttachIdleHandler("ToggleVisibilityCommandsFooters", 0.5, True);
	
EndProcedure

&AtClient
Procedure ToggleItemVisibility(Item, Visible)
	
	If Item.Visible <> Visible Then
		Item.Visible = Visible;
	EndIf;

EndProcedure

&AtServer
Function WriteTemplate(AbortRecordingIfThereAreErrorsInLayout = False, TemplateAddressInTempStorage = "")
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		Cancel = False;

		If Not ValueIsFilled(TemplateAddressInTempStorage) Then
			If IsPrintForm Then
				Template = PrepareLayoutForRecording(, Cancel);
			Else
				Template = SpreadsheetDocument;
			EndIf;
			
			TemplateAddressInTempStorage = PutToTempStorage(Template, UUID);
		EndIf;
		
		If Cancel And AbortRecordingIfThereAreErrorsInLayout Then
			Return False;
		EndIf;
		
		ModulePrintManager = Common.CommonModule("PrintManagement");
		TemplateDetails = ModulePrintManager.TemplateDetails();
		TemplateDetails.TemplateMetadataObjectName = IdentifierOfTemplate;
		TemplateDetails.TemplateAddressInTempStorage = TemplateAddressInTempStorage;
		TemplateDetails.LanguageCode = CurrentLanguage;
		TemplateDetails.Description = DocumentName;
		TemplateDetails.Ref = RefTemplate;
		TemplateDetails.TemplateType = "MXL";
		TemplateDetails.DataSources = DataSources.UnloadValues();
		
		IdentifierOfTemplate = ModulePrintManager.WriteTemplate(TemplateDetails);
		If Not ValueIsFilled(RefTemplate) Then
			RefTemplate = ModulePrintManager.RefTemplate(IdentifierOfTemplate);
		EndIf;
		
		WriteTemplatesInAdditionalLangs();
		
		If Not Items.Language.Enabled Then
			Items.Language.Enabled  = True;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

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
	ColumnPattern.ClearButton = True;
	
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

&AtClient
Procedure Attachable_AvailableFieldsWhenLineIsActivated(Item)
	
	CurrentData = Items[NameOfTheFieldList()].CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.GetParent() = Undefined Then
		Items["SearchString" + NameOfTheFieldList()].InputHint = PromptInputStringSearchFieldList();
	Else
		Items["SearchString" + NameOfTheFieldList()].InputHint = CurrentData.RepresentationOfTheDataPath;
	EndIf;

	SystemInfo = New SystemInfo;
	PlatformVersion = SystemInfo.AppVersion;

	If CommonClientServer.CompareVersions(PlatformVersion, "8.3.23.838") >= 0 Then
		AttachIdleHandler("HighlightCellsWithSelectedField", 0.1, True);
	Else
#If Not WebClient Then	
			AttachIdleHandler("HighlightCellsWithSelectedField", 0.1, True);	
#EndIf		
	EndIf;
	
EndProcedure

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
	
	If Items.LayoutPages.CurrentPage = Items.PagePreview Then
		GeneratePrintForm();
	EndIf;
	
EndProcedure

&AtServer
Function PickupRegionName(AreaName)
	
	UsedNames = New Map;
	
	For Each Area In SpreadsheetDocument.Areas Do
		UsedNames.Insert(Area.Name, True);
	EndDo;
	
	IndexOf = 1;
	While UsedNames[AreaName(AreaName, IndexOf)] <> Undefined Do
		IndexOf = IndexOf + 1;
	EndDo;
	
	Return AreaName(AreaName, IndexOf);
	
EndFunction

&AtServer
Function AreaName(AreaName, IndexOf)
	
	Return AreaName + Format(IndexOf, "NG=0");
	
EndFunction

&AtClientAtServerNoContext
Function PromptInputStringSearchFieldList()
	
	Return NStr("en = 'Find field…';");
	
EndFunction

&AtClient
Procedure ViewPrintableForm(Command)
	
	If Items.ViewPrintableForm.Check Then
		Items.LayoutPages.CurrentPage = Items.PageTemplate;
	Else
		If Not ValueIsFilled(Pattern) Then
			Items[NameOfTheFieldList()].CurrentRow = ThisObject[NameOfTheFieldList()].GetItems()[0].GetID();
			CommonClient.MessageToUser(
				NStr("en = 'Select a template whose data will be used to generate a print form';"), , NameOfTheFieldList() + "[0].Pattern");
			Return;
		EndIf;
		GeneratePrintForm();
		Items.LayoutPages.CurrentPage = Items.PagePreview;
	EndIf;
	
	Items.ViewPrintableForm.Check = Not Items.ViewPrintableForm.Check;
	Items.SettingsCurrentRegion.Visible = Not Items.ViewPrintableForm.Check;
	Items.SecondCommandBar.Enabled = Not Items.ViewPrintableForm.Check;
	Items.ShowHeadersAndFooters.Enabled = Not Items.ViewPrintableForm.Check;
	Items.ActionsWithDocument.Enabled = Not Items.ViewPrintableForm.Check;
	Items.Language.Enabled = Not Items.ViewPrintableForm.Check;
	
EndProcedure

&AtServer
Procedure GeneratePrintForm()
	
	References = CommonClientServer.ValueInArray(Pattern);
	PrintObjects = New ValueList;
	Template = PrepareLayoutForRecording();
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		PrintForm = ModulePrintManager.GenerateSpreadsheetDocument(
			Template, References, PrintObjects, CurrentLanguage);
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteStampEP(Command)
	
	For Each Area In Items.SpreadsheetDocument.GetSelectedAreas() Do
		If StrStartsWith(Area.Name, "DSStamp") Then
			Area.Name = "";
#If WebClient Then
				// It is required for the display update
				Area.Protection = Area.Protection;
#EndIf
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure DeleteLayoutInCurrentLanguage()
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.DeleteTemplate(IdentifierOfTemplate, CurrentLanguage);
	EndIf;
	
	LoadSpreadsheetDocumentFromMetadata(CurrentLanguage);
	If IsPrintForm Then
		FillSpreadsheetDocument(SpreadsheetDocument, ReadLayout());
	EndIf;
	
	Modified = False;
	
	If Not ValueIsFilled(CurrentLanguage) Or CurrentLanguage = Common.DefaultLanguageCode() Then
		Return;
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
	
EndProcedure

&AtClient
Procedure ContinueSavingToFile(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	FullFileName = SelectedFiles[0];
	
	ClearHighlight();
	Template = PrepareLayoutForRecording(False);
	Template.Write(FullFileName);
	
EndProcedure

&AtClient
Procedure ContinueDownloadFromFile(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	FullFileName = SelectedFiles[0];
	
	NotifyDescription = New NotifyDescription("ResumeImportFromFileAfterDataObtained", ThisObject);
	BeginCreateBinaryDataFromFile(NotifyDescription, FullFileName);
EndProcedure

&AtClient
Procedure ResumeImportFromFileAfterDataObtained(BinaryData, AdditionalParameters) Export
	
	FinishImportFromFile(BinaryData);
	Modified = True;
	
EndProcedure

&AtServer
Procedure FinishImportFromFile(Val BinaryData)
	
	LanguageCode = SpreadsheetDocument.LanguageCode;
	Template = ReadLayout(BinaryData);
	SpreadsheetDocument.LanguageCode = LanguageCode;
	
	FillSpreadsheetDocument(SpreadsheetDocument, Template);
	
EndProcedure

&AtClient
Procedure UpdateTextInCellsArea()
	
	CurrentArea = SpreadsheetDocument.CurrentArea;
	If CurrentArea = Undefined Or TypeOf(CurrentArea) <> Type("SpreadsheetDocumentRange") Then
		Return;
	EndIf;
	
	Modified = True;
	
	If CurrentArea.AreaType = SpreadsheetDocumentCellAreaType.Rectangle Then
		CurrentArea.Text = CurrentValue;
	ElsIf CurrentArea.AreaType = SpreadsheetDocumentCellAreaType.Rows Then
		CurrentArea.Name = "";
		
		Area = SpreadsheetDocument.Area(CurrentArea.Top, 1, CurrentArea.Top, 1);
		If Area.Text = "" Then
			Area.Text = "";
		EndIf;
		
		CurrentArea.DetailsParameter = CurrentValue;
		
		If ValueIsFilled(CurrentValue) Then
			CurrentArea.Name = PickupRegionName("Condition_");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnSelectingLayoutName(NewTemplateName, AdditionalParameters) Export
	
	If NewTemplateName = Undefined Then
		Return;
	EndIf;
	
	If DocumentName <> NewTemplateName Then
		Modified = True;
	EndIf;
	
	DocumentName = NewTemplateName;
	SetHeader();
	
EndProcedure

#EndRegion

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
