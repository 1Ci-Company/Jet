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
	
	MessageParameters = Parameters.MessageParameters;
	
	Items.InputOnBasisParameterTypeFullName.ChoiceList.Add(MessageTemplatesClientServer.CommonID(),
		MessageTemplatesClientServer.SharedPresentation());
	MessageTemplatesSettings = MessageTemplatesInternalCached.OnDefineSettings();
	For Each TemplateSubject In MessageTemplatesSettings.TemplatesSubjects Do
		Items.InputOnBasisParameterTypeFullName.ChoiceList.Add(TemplateSubject.Name, TemplateSubject.Presentation);
	EndDo;
	
	AttachmentsList = Undefined;
	IsNewTemplate = Object.Ref.IsEmpty();
	RestrictionByCondition = AccessParameters("Update", Metadata.Catalogs.MessageTemplates, "Ref").RestrictionByCondition;

	If IsNewTemplate Then
		
		If Parameters.CopyingValue = Catalogs.MessageTemplates.EmptyRef() Then
			InitializeNewMessagesTemplate(MessageTemplatesSettings);
		Else
			
			For Each CopyingValueParameters In Parameters.CopyingValue.Parameters Do
				Filter = New Structure("ParameterName", CopyingValueParameters.ParameterName);
				FoundRows = Object.Parameters.FindRows(Filter);
				If FoundRows.Count() > 0 Then
					FoundRows[0].TypeDetails = CopyingValueParameters.ParameterType.Get();
				EndIf
			EndDo;
			
			AttachmentsList = CopyAttachmentsFromSource();
		EndIf;
	EndIf;
	
	ShowFormItems(MessageTemplatesSettings.EmailFormat1);
	
	InitializeSaveFormats();
	GenerateAttributesAndPrintFormsList();
	
	UseArbitraryParameters = MessageTemplatesSettings.UseArbitraryParameters;
	
	If Not UseArbitraryParameters Then
		Items.AttributesGroupCommandBar.Visible = False;
		Items.AttributesContextMenuAdd.Visible = False;
		Items.AttributesContextMenuChange.Visible = False;
		Items.AttributesContextMenuDelete.Visible = False;
	EndIf;
	
	If ValueIsFilled(Parameters.TemplateOwner) Then
		Items.AssignmentGroup.Visible                = False;
		Items.FormMessageToGenerateGroup.Visible = False;
		Items.Purpose.Visible                      = False;
	EndIf;
	
	If Common.IsMobileClient() Then
		Items.EmailSubject.MultiLine = True;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		Items.SignatureAndSeal.Visible = ModulePrintManager.PrintSettings().UseSignaturesAndSeals;
	EndIf;
	
	SetTemplateText(Object, AttachmentsList);
	
	If RestrictionByCondition Then
		
		If IsNewTemplate Then
			Object.Author           = Users.CurrentUser();
			Object.AuthorOnly = True;
			Available               = "OnlyAuthor";
		ElsIf Object.Author = Users.CurrentUser() Then
			Available               = "OnlyAuthor";
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	SetTemplateText(CurrentObject);
	
	If SelectedSaveFormats.Count() = 0 Then
		For Each SaveFormat In StandardSubsystemsServer.SpreadsheetDocumentSaveFormatsSettings() Do
			SelectedSaveFormats.Add(String(SaveFormat.SpreadsheetDocumentFileType), String(SaveFormat.Ref), False, SaveFormat.Picture);
		EndDo;
	EndIf;

	FormatsList = CurrentObject.AttachmentFormat.Get();
	If FormatsList <> Undefined Then
		SelectedSaveFormats.FillChecks(False);
		For Each ListItem In FormatsList Do
			ValueFound = SelectedSaveFormats.FindByValue(ListItem.Value);
			If ValueFound <> Undefined Then
				ValueFound.Check = True;
			EndIf;
		EndDo;
	EndIf;
	
	FillArbitraryParametersFromObject(CurrentObject);
	
	If IsBlankString(Object.InputOnBasisParameterTypeFullName) Then
		Object.Purpose = MessageTemplatesClientServer.SharedPresentation();
		Object.ForInputOnBasis = False;
		Object.InputOnBasisParameterTypeFullName = MessageTemplatesClientServer.CommonID();
	EndIf;
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	PlaceFilesFromLocalFSInTempStorage(Attachments, UUID, Cancel);
	
	If Not Object.ForInputOnBasis Then
		Object.InputOnBasisParameterTypeFullName = "";
		Object.Purpose = MessageTemplatesClientServer.CommonID();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CheckInformation = ProcessTemplateText();
	
	If Not CheckInformation.Success Then
		Common.MessageToUser(NStr("en = 'Couldn''t save template.';")
			+ Chars.LF + CheckInformation.ErrorText);
		Cancel = True;
		Return;
	EndIf;
	
	If RestrictionByCondition Then
		
		If Available = "OnlyAuthor" Then
			CurrentObject.Author = Users.CurrentUser();
			CurrentObject.AuthorOnly = True;
		Else
			CurrentObject.Author = Catalogs.Users.EmptyRef();
			CurrentObject.AuthorOnly = False;
		EndIf;
		
	EndIf;
	
	If CurrentObject.ForSMSMessages Then
		CurrentObject.SMSTemplateText = CheckInformation.NormalText;
		CurrentObject.AttachmentFormat = Undefined;
	ElsIf CurrentObject.ForEmails Then
		CurrentObject.HTMLEmailTemplateText = CheckInformation.HTMLText;
		CurrentObject.MessageTemplateText     = CheckInformation.NormalText;
		CurrentObject.EmailSubject             = CheckInformation.EmailSubject;
		
		FormatsList = New ValueList;
		For Each ListItem In SelectedSaveFormats Do
			If ListItem.Check Then
				FillPropertyValues(FormatsList.Add(), ListItem);
			EndIf;
		EndDo;
		CurrentObject.AttachmentFormat = New ValueStorage(FormatsList);
		
		AttachmentsNamesToIDsMapsTable = New ValueList;
		AttachmentsStructure = New Structure;
		
		HTMLTemplateText = ""; // Extract the attachments
		EmailBodyInHTML.GetHTML(HTMLTemplateText, AttachmentsStructure);
		For Each Attachment In AttachmentsStructure Do
			AttachmentsNamesToIDsMapsTable.Add(Attachment.Key, New UUID,, Attachment.Value);
		EndDo;
		
		WriteParameters.Insert("HTMLAttachments", AttachmentsNamesToIDsMapsTable);
		
		If AttachmentsNamesToIDsMapsTable.Count() > 0 Then
			
			HTMLDocument = MessageTemplatesInternal.GetHTMLDocumentObjectFromHTMLText(CurrentObject.HTMLEmailTemplateText);
			ChangePicturesNamesToMailAttachmentsIDsInHTML(HTMLDocument, AttachmentsNamesToIDsMapsTable);
			CurrentObject.HTMLEmailTemplateText = MessageTemplatesInternal.GetHTMLTextFromHTMLDocumentObject(HTMLDocument);
			
		EndIf;
		
		CurrentObject.PrintFormsAndAttachments.Clear();
		For Each Attachment In Attachments Do
			If Attachment.SelectedItemsCount = 1 Then
				NewRow = CurrentObject.PrintFormsAndAttachments.Add();
				NewRow.Id = Attachment.Id;
				NewRow.Name = Attachment.ParameterName;
			EndIf;
		EndDo;
	Else
		CurrentObject.TemplateTextArbitrary = CheckInformation.NormalText;
		CurrentObject.AttachmentFormat = Undefined;
	EndIf;
	
	CurrentObject.Parameters.Clear();
	For Each TemplateParameter In Object.Parameters Do
		NewRow = CurrentObject.Parameters.Add();
		FillPropertyValues(NewRow, TemplateParameter);
		NewRow.ParameterType = New ValueStorage(TemplateParameter.TypeDetails);
	EndDo;
	
EndProcedure

&AtServer
Function ProcessTemplateText()
	
	TemplateParametersTree = FormAttributeToValue("Attributes");
	
	Result = New Structure;
	Result.Insert("NormalText", MessageBodyPlainText.GetText());
	Result.Insert("HTMLText", "");
	Result.Insert("ErrorText", "");
	Result.Insert("Success", True);
	Result.Insert("EmailSubject", Object.EmailSubject);
	Result.Insert("EmailTextType", Object.EmailTextType);
	
	TextToCheck = "";
	TransformationOption = "PresentationInParameters";
	
	If Object.ForEmails Then
		If Result.EmailTextType = Enums.EmailEditingMethods.HTML Then
			
			HTMLAttachments1 = New Structure();
			EmailBodyInHTML.GetHTML(Result.HTMLText, HTMLAttachments1);
			
			Result.HTMLText = MessageTemplatesInternal.ConvertTemplateText(StrReplace(Result.HTMLText, "&quot;", """"), TemplateParametersTree, TransformationOption);
			Result.NormalText = MessageTemplatesInternal.ConvertTemplateText(EmailBodyInHTML.GetText(), TemplateParametersTree, TransformationOption);
			TextToCheck = Result.HTMLText;
			
		Else
			
			If IsBlankString(Result.NormalText) Then
				Result.NormalText = EmailBodyInHTML.GetText();
			EndIf;
			Result.NormalText = MessageTemplatesInternal.ConvertTemplateText(Result.NormalText,
				TemplateParametersTree, TransformationOption);
			Result.HTMLText = Result.NormalText;
			
			TextToCheck = Result.NormalText;
			
		EndIf;
		
		Result.EmailSubject = MessageTemplatesInternal.ConvertTemplateText(Result.EmailSubject, TemplateParametersTree, TransformationOption);
		TextToCheck = TextToCheck + Result.EmailSubject;
	Else
		Result.NormalText = 
			MessageTemplatesInternal.ConvertTemplateText(Result.NormalText, TemplateParametersTree, TransformationOption);
		TextToCheck = Result.NormalText;
	EndIf;
	
	If Object.TemplateByExternalDataProcessor Then
		Return Result; // The data processor has a special population logic. 
	EndIf;
	
	// Check.
	
	InvalidParameters = New Array;
	TemplateParametersFromText = MessageTemplatesInternal.MessageTextParameters(TextToCheck);
	
	For Each TemplateParameterFromText In TemplateParametersFromText Do
		
		ParameterDetails =  MessageTemplatesInternal.ParameterNameWithoutFormatString(TemplateParameterFromText.Key);
		
		FoundRows = TemplateParametersTree.Rows.FindRows(New Structure("Name", ParameterDetails.Name), True);
		If FoundRows.Count() > 0 Then
			Continue;
		EndIf;
		
		InvalidParameters.Add( ParameterDetails.Name);
		
	EndDo;
	
	If InvalidParameters.Count() > 0 Then
		ErrorText = ?(InvalidParameters.Count() = 1,
			NStr("en = 'Invalid placeholder:';"),
			NStr("en = 'Invalid placeholders:';"));
		Result.ErrorText = ErrorText + " " + StrConcat(InvalidParameters, ", ");
		Result.Success = False;
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not CurrentObject.ForEmails Then
		Return;
	EndIf;
	// Adding to the list of deleted attachments previously saved pictures displayed in the body of a formatted document.
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		ListOfFiles = New Array;  // Array of DefinedType.AttachedFile
		ModuleFilesOperations.FillFilesAttachedToObject(CurrentObject.Ref, ListOfFiles);
		For Each Attachment In ListOfFiles Do
			If ValueIsFilled(Attachment.EmailFileID) Then
				DeleteAttachedFile(Attachment.Ref);
			EndIf;
		EndDo;
	EndIf;
	
	SaveFormattedDocumentPicturesAsAttachedFiles(CurrentObject.Ref,
		CurrentObject.EmailTextType, WriteParameters.HTMLAttachments, UUID);
	
	IndexOf = Attachments.Count() - 1;
	While IndexOf >= 0 Do
		AttachmentsTableRow = MessageTemplates.AttachmentsRow(Attachments.Get(IndexOf));
		If AttachmentsTableRow.Status = "ExternalToDelete" Then
			If Not AttachmentsTableRow.Ref.IsEmpty() Then
				DeleteAttachedFile(AttachmentsTableRow.Ref);
			EndIf;
			If IsBlankString(AttachmentsTableRow.Attribute) Then
				Attachments.Delete(IndexOf)
			Else
				AttachmentsTableRow.Status  = "";
				AttachmentsTableRow.SelectedItemsCount = 2;
			EndIf;
		ElsIf AttachmentsTableRow.Status = "ExternalNew" Then
			FileName = ?(IsBlankString(AttachmentsTableRow.Attribute), AttachmentsTableRow.Presentation, AttachmentsTableRow.Attribute);
			FileRef = MessageTemplatesInternal.WriteEmailAttachmentFromTempStorage(CurrentObject.Ref, AttachmentsTableRow, FileName, 0);
			AttachmentsTableRow.Ref = FileRef;
			AttachmentsTableRow.Status ="ExternalAttached";
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	FillArbitraryParametersFromObject(CurrentObject);
	ShowFormItems();
	
	SetTemplateText(CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_MessageTemplates", Object.Ref, ThisObject);
	
	If IsBlankString(Object.InputOnBasisParameterTypeFullName) Then
		Object.Purpose = MessageTemplatesClientServer.SharedPresentation();
		Object.ForInputOnBasis = False;
		Object.InputOnBasisParameterTypeFullName = MessageTemplatesClientServer.CommonID();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetFormatSelection();
	GeneratePresentationForSelectedFormats();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_File" And TypeOf(Source) = Type("CatalogRef.MessageTemplatesAttachedFiles") Then
		RefreshPrintFormsList();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure InputOnBasisParameterTypeFullNameOnChange(Item)
	If IsBlankString(Object.InputOnBasisParameterTypeFullName) Then
		Object.InputOnBasisParameterTypeFullName = MessageTemplatesClientServer.CommonID();
	EndIf;
	Object.ForInputOnBasis = (Object.InputOnBasisParameterTypeFullName <> MessageTemplatesClientServer.CommonID());
	Object.Purpose = Items.InputOnBasisParameterTypeFullName.EditText;
	GenerateAttributesAndPrintFormsList();
EndProcedure

&AtClient
Procedure InputOnBasisParameterTypeFullNameClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ExternalDataProcessorOnChange(Item)
	ShowFormItems();
EndProcedure

&AtClient
Procedure AttachmentFormatClick(Item, StandardProcessing)
	StandardProcessing    = False;
	
	If CommonClient.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManagerInternalClient = CommonClient.CommonModule("PrintManagementInternalClient");
		Notification = New NotifyDescription("AttachmentFormatClickCompletion", ThisObject);
		ModulePrintManagerInternalClient.OpenAttachmentsFormatSelectionForm(SelectedFormatSettings(), Notification);
	EndIf
	
EndProcedure

&AtClient
Procedure EmailBodyInHTMLOnChange(Item)
	EmailBodyInHTML.GetHTML(Object.HTMLEmailTemplateText, New Structure);
EndProcedure

&AtClient
Procedure MessageBodyPlainTextOnChange(Item)
	
	If Object.ForEmails Then
		Object.MessageTemplateText = MessageBodyPlainText.GetText();
	Else
		Object.TemplateTextArbitrary = MessageBodyPlainText.GetText();
	EndIf;
	
EndProcedure

&AtClient
Procedure MessageBodySMSMessagePlainTextOnChange(Item)
	Object.SMSTemplateText = MessageBodyPlainText.GetText();
	MessageBodyPlainText.SetText(Object.SMSTemplateText); // Text message must not exceed 1024 characters.
EndProcedure

&AtClient
Procedure AuthorOnChange(Item)
	Object.AuthorOnly = ValueIsFilled(Object.Author);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAttachments

&AtClient
Procedure AttachmentsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	Cancel = True;
	If Not Copy Then
		AddAttachmentExecute();
	EndIf;
EndProcedure

&AtClient
Procedure AttachmentsBeforeDeleteRow(Item, Cancel)
	DeleteAttachmentExecute();
	Cancel = True;
EndProcedure

&AtClient
Procedure AttachmentsOnActivateRow(Item)
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.Status = "PrintForm" Or ValueIsFilled(CurrentData.Attribute) Then
		Items.AttachmentsContextMenuDelete.Enabled             = False;
		Items.AttachmentsContextMenuChangeAttachment.Enabled    = False;
		Items.AttachmentsChange.Enabled                           = False;
		Items.AttachmentsDelete.Enabled                            = False;
		Items.AttachmentsCopyAttachment.Enabled                = False;
		Items.AttachmentsContextMenuCopyAttachment.Enabled = False;
	Else
		Items.AttachmentsContextMenuDelete.Enabled             = True;
		Items.AttachmentsContextMenuChangeAttachment.Enabled    = True;
		Items.AttachmentsChange.Enabled                           = False;
		Items.AttachmentsDelete.Enabled                            = True;
		Items.AttachmentsCopyAttachment.Enabled                = True;
		Items.AttachmentsContextMenuCopyAttachment.Enabled = True;
	EndIf;

EndProcedure

&AtClient
Procedure AttachmentsSelectedOnChange(Item)
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;

	If IsBlankString(CurrentData.Attribute) Then
		If CurrentData.SelectedItemsCount = 2 Then
			CurrentData.SelectedItemsCount = 0;
		EndIf;
	Else
		If CurrentData.SelectedItemsCount = 0 Then
			CurrentData.SelectedItemsCount = 2;
			AddAttachmentExecute(CurrentData.Id);
		ElsIf CurrentData.SelectedItemsCount = 2 Then
			CurrentData.Status = "ExternalToDelete";
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAttributes

&AtClient
Procedure AttributesBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	Cancel = True;
	If UseArbitraryParameters Then
		AdditionalParameters = AdditionalAttributesAddingOptions();
		ClosingNotification = New NotifyDescription("AfterCloseParameterForm", ThisObject, AdditionalParameters);
		FormParameters = New Structure("ParametersList, InputOnBasisParameterTypeFullName", Object.Parameters, Object.InputOnBasisParameterTypeFullName);
		OpenForm("Catalog.MessageTemplates.Form.ArbitraryParameter", FormParameters,,,,, ClosingNotification);
	EndIf;
EndProcedure

// Returns:
//  Structure:
//   * Create - Boolean
//
&AtClient
Function AdditionalAttributesAddingOptions()
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Create", True);
	Return AdditionalParameters;
	
EndFunction

&AtClient
Procedure AttributesOnActivateRow(Item)
	CurrentData = Items.Attributes.CurrentData;
	FormattedOutputAvailability = False;
	If CurrentData <> Undefined Then
		If CurrentData.ArbitraryParameter Then
			Items.AttributesContextMenuDelete.Enabled = True;
			Items.Delete.Enabled = True;
			Items.AttributesContextMenuChange.Enabled = True;
		Else
			Items.AttributesContextMenuDelete.Enabled = False;
			Items.Delete.Enabled = False;
			Items.AttributesContextMenuChange.Enabled = False;
		EndIf;
		If CurrentData.GetItems().Count() > 0 Then
			ChangeAttributesContextMenuAvailability(False);
		Else
			ChangeAttributesContextMenuAvailability(True);
			For Each Type In CurrentData.Type.Types() Do
				If Type = Type("Date") Or Type = Type("Number") Or Type = Type("Boolean") Then
					FormattedOutputAvailability = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	If Items.AttributePresentationFormat.Enabled <> FormattedOutputAvailability Then
		Items.AttributePresentationFormat.Enabled = FormattedOutputAvailability;
	EndIf;
	
EndProcedure

&AtClient
Procedure AttributesSelection(Item, RowSelected, Field, StandardProcessing)
	
	Attribute = Attributes.FindByID(RowSelected);
	TreeItem = Attributes.FindByID(Attribute.GetID());
	If TreeItem.GetItems().Count() = 0 Then
		AddParameterToMessageText1();
	EndIf;
	
EndProcedure

&AtClient
Procedure AttributesDragStart(Item, DragParameters, Perform)
	
	ObjectsToDrag = DragParameters.Value;
	TextForInsert = "";
	Separator = "";
	For Each ObjectToDrag In ObjectsToDrag Do
		TreeItem = Attributes.FindByID(ObjectToDrag);
		If TreeItem.GetItems().Count() = 0 Then
			OutputFormat = ?(IsBlankString(TreeItem.Format), "", "{" + TreeItem.Format +"}");
			TextForInsert = TextForInsert + Separator + "[" + TreeItem.FullPresentation + OutputFormat + "]";
			Separator = " ";
		EndIf;
	EndDo;
	DragParameters.Value = TextForInsert;
	
EndProcedure

&AtClient
Procedure AttributesBeforeDeleteRow(Item, Cancel)
	If UseArbitraryParameters Then
		
		CurrentData = Items.Attributes.CurrentData;
		If CurrentData = Undefined Or Not CurrentData.ArbitraryParameter Then
			Cancel = True;
			Return;
		EndIf;
		
		If StrStartsWith(CurrentData.Name, MessageTemplatesClientServer.ArbitraryParametersTitle()) Then
			Filter = New Structure("ParameterName", Mid(CurrentData.Name, StrLen(MessageTemplatesClientServer.ArbitraryParametersTitle()) + 2));
		Else
			Filter = New Structure("ParameterName", CurrentData.Name);
		EndIf;
		FoundRows = Object.Parameters.FindRows(Filter);
		If FoundRows.Count() > 0 Then
			Object.Parameters.Delete(FoundRows[0]);
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure EmailPlainText(Command)
	If Not Items.FormEmailPlainText.Check Then
		SetEmailPlainText(True);
	EndIf;
EndProcedure

&AtClient
Procedure EmailHTML(Command)
	If Not Items.FormEmailHTML.Check Then
		SetHTMLEmail(True);
	EndIf;
EndProcedure

&AtClient
Procedure CheckTemplateFilling(Command)
	
	ClearMessages();
	CheckInformation = ProcessTemplateText();
	
	If CheckInformation.Success Then
		ShowMessageBox(, NStr("en = 'Template is valid.';"));
	Else
		CommonClient.MessageToUser(CheckInformation.ErrorText);
	EndIf;
	
EndProcedure

&AtClient
Procedure ByExternalDataProcessor(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		Notification = New NotifyDescription("AfterAdditionalReportsAndDataProcessorsChoice", ThisObject);
		KindName = "AdditionalReportsAndDataProcessorsKinds.MessageTemplate";
		FilterValue = New Structure("Kind", PredefinedValue("Enum." + KindName));
		FormParameters = New Structure("Filter", FilterValue);
		AdditionalReportsAndDataProcessorsFormName = "AdditionalReportsAndDataProcessors.ChoiceForm";
		OpenForm("Catalog." + AdditionalReportsAndDataProcessorsFormName, FormParameters, ThisObject,,,, Notification);
	EndIf
	
EndProcedure

&AtClient
Procedure FromTemplate(Command)
	
	Items.Pages.CurrentPage         = Items.MessageEmailHTML;
	
	Items.ExternalDataProcessorGroup.Visible = False;
	Items.GroupParameters.Visible        = True;
	Items.FormFromTemplate.Check           = True;
	Items.FormByExternalDataProcessor.Check   = False;
	Items.EmailSubject.ReadOnly        = False;
	Object.TemplateByExternalDataProcessor           = False;
	Object.ExternalDataProcessor                   = Undefined;
	ShowFormItems();
	
EndProcedure

&AtClient
Procedure SetOutputFormat(Command)
	
	CurrentData = Items.Attributes.CurrentData;
	If CurrentData <> Undefined Then
		AdditionalParameters = New Structure("RowID", CurrentData.GetID());
		Handler = New NotifyDescription("AfterAttributeFormatChoice", ThisObject, AdditionalParameters);
		
		Dialog = New FormatStringWizard;
		Dialog.AvailableTypes = CurrentData.Type;
		Dialog.Text         = CurrentData.Format;
		Dialog.Show(Handler);
	EndIf;

EndProcedure

&AtClient
Procedure AfterAttributeFormatChoice(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		Attribute = Attributes.FindByID(AdditionalParameters.RowID);
		If Attribute <> Undefined Then
			Attribute.Format = Result;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure AddParameterToMessageText(Command)
	
	AddParameterToMessageText1();
	
EndProcedure

&AtClient
Procedure ChangeAttribute(Command)
	
	CurrentData = Items.Attributes.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If UseArbitraryParameters And CurrentData.ArbitraryParameter Then
		RowIDs = CurrentData.GetID();
		AdditionalParameters = New Structure("Create, RowSelected", False, RowIDs);
		FormParameters = New Structure("ParameterName, ParameterPresentation, TypeDetails", CurrentData.Name, CurrentData.Presentation, CurrentData.Type);
		FormParameters.Insert("ParametersList", Object.Parameters);
		FormParameters.Insert("InputOnBasisParameterTypeFullName", Object.InputOnBasisParameterTypeFullName);
		
		ClosingNotification = New NotifyDescription("AfterCloseParameterForm", ThisObject, AdditionalParameters);
		OpenForm("Catalog.MessageTemplates.Form.ArbitraryParameter", FormParameters,,,,, ClosingNotification);
	EndIf;
	
EndProcedure

&AtClient
Procedure AddParameterToMessageSubject(Command)
	
	CurrentData = Items.Attributes.CurrentData;
	If CurrentData <> Undefined Then
		OutputFormat = ?(IsBlankString(CurrentData.Format), "", "{" + CurrentData.Format +"}");
		ParameterStart = ?(Right(Object.EmailSubject, 1) = " ", "[", " [");
		Object.EmailSubject = Object.EmailSubject + ParameterStart + CurrentData.FullPresentation + OutputFormat + "]";
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeAttachment(Command)
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentIDInCollection = Items.Attachments.CurrentRow;
	
	If CurrentData.Ref = PredefinedValue("Catalog.MessageTemplatesAttachedFiles.EmptyRef") Then
		AdditionalParameters = New Structure("CurrentIndexInCollection", CurrentIDInCollection);
		OnCloseNotifyHandler = New NotifyDescription("ChangeAttachmentCompletion", ThisObject, AdditionalParameters);
		QueryText = NStr("en = 'You can access the file''s properties after you save the file. Save it now?';");
		ShowQueryBox(OnCloseNotifyHandler, QueryText, QuestionDialogMode.YesNo);
	Else
		OpenAttachmentProperties(CurrentIDInCollection);
	EndIf;

EndProcedure

&AtClient
Procedure CopyAttachment(Command)
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Id = Items.Attachments.CurrentRow;
	
	If CurrentData.Ref = PredefinedValue("Catalog.MessageTemplatesAttachedFiles.EmptyRef") Then
		AdditionalParameters = New Structure("CurrentIndexInCollection", Id);
		OnCloseNotifyHandler = New NotifyDescription("CopyAttachmentCompletion", ThisObject, AdditionalParameters);
		QueryText = NStr("en = 'To copy the file, you need to save the template. Do you want to save it?';");
		ShowQueryBox(OnCloseNotifyHandler, QueryText, QuestionDialogMode.YesNo);
	Else
		CopyAttachmentFile(Id);
	EndIf;
EndProcedure

#EndRegion

#Region Private

// Parameters:
//  ParameterDetails - Structure
//  AdditionalParameters - See AdditionalAttributesAddingOptions 
// 
&AtClient
Procedure AfterCloseParameterForm(ParameterDetails, AdditionalParameters) Export
	If TypeOf(ParameterDetails) = Type("Structure") Then
		Modified = True;
		If AdditionalParameters.Create Then
			AddArbitraryParameter(ParameterDetails);
		Else
			Attribute = Attributes.FindByID(AdditionalParameters.RowSelected);
			If StrStartsWith(Attribute.Name, MessageTemplatesClientServer.ArbitraryParametersTitle()) Then
				Filter = New Structure("ParameterName", Mid(Attribute.Name, StrLen(MessageTemplatesClientServer.ArbitraryParametersTitle()) + 2));
			Else
				Filter = New Structure("ParameterName", Attribute.Name);
			EndIf;
			FoundRows = Object.Parameters.FindRows(Filter);
			If FoundRows.Count() > 0 Then
				Object.Parameters.Delete(FoundRows[0]);
			EndIf;
			AddArbitraryParameter(ParameterDetails);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure ChangeAttributesContextMenuAvailability(NewValue)
	
	If Items.AttributesContextMenuAddParameterToMessageText.Enabled <> NewValue Then
		Items.AttributesContextMenuAddParameterToMessageText.Enabled = NewValue;
		Items.AttributesContextMenuAddParameterToMessageSubject.Enabled = NewValue;
		Items.AddParameterToMessageSubject.Enabled = NewValue;
		Items.AttributesAddParameterToMessageText.Enabled = NewValue;
		Items.AttributesContextMenuAddParameterToSMSMessageText.Enabled = NewValue;
		Items.AttributesMenuAddParameterToSMSMessageText.Enabled = NewValue;
	EndIf;
	
EndProcedure

&AtClient
Function SelectedFormatSettings()
	
	SaveFormats = New Array;
	
	For Each SelectedFormat In SelectedSaveFormats Do
		If SelectedFormat.Check Then
			SaveFormats.Add(SpreadsheetDocumentFileType[SelectedFormat.Value]);
		EndIf;
	EndDo;
	
	Result = CommonInternalClient.PrintFormFormatSettings();
	Result.PackToArchive = Object.PackToArchive;
	Result.SaveFormats = SaveFormats;
	Result.TransliterateFilesNames = Object.TransliterateFileNames;
	
	Return Result;
	
EndFunction

&AtClient
Procedure SetFormatSelection(Val SaveFormats = Undefined)
	
	If Not Object.ForEmails Then
		Return;
	EndIf;
	
	HasSelectedFormat = False;
	For Each SelectedFormat In SelectedSaveFormats Do
		If SaveFormats <> Undefined Then
			SelectedFormat.Check = SaveFormats.Find(SelectedFormat.Value) <> Undefined;
		EndIf;
			
		If SelectedFormat.Check Then
			HasSelectedFormat = True;
		EndIf;
	EndDo;
	
	If Not HasSelectedFormat Then
		SelectedSaveFormats[0].Check = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure AttachmentFormatClickCompletion(Result, AdditionalParameters) Export
	
	FormatsChoiceResult = Result;
	If FormatsChoiceResult <> DialogReturnCode.Cancel And FormatsChoiceResult <> Undefined Then
		SetFormatSelection(FormatsChoiceResult.SaveFormats);
		Object.PackToArchive = FormatsChoiceResult.PackToArchive;
		Object.TransliterateFileNames = FormatsChoiceResult.TransliterateFilesNames;
		GeneratePresentationForSelectedFormats();
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure GeneratePresentationForSelectedFormats()
	
	PrintFormsFormat = "";
	FormatsCount = 0;
	For Each SelectedFormat In SelectedSaveFormats Do
		If SelectedFormat.Check Then
			If Not IsBlankString(PrintFormsFormat) Then
				PrintFormsFormat = PrintFormsFormat + ", ";
			EndIf;
			PrintFormsFormat = PrintFormsFormat + SelectedFormat.Presentation;
			FormatsCount = FormatsCount + 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure AddArbitraryParameter(ParameterDetails)
	NewParameter = Object.Parameters.Add();
	FillPropertyValues(NewParameter, ParameterDetails);
	
	TypesArray = New Array;
	TypesArray.Add(ParameterDetails.ParameterType);
	TypeDetails = New TypeDescription(TypesArray);
	NewParameter.TypeDetails = TypeDetails;
	
	GenerateAttributesAndPrintFormsList();
EndProcedure

&AtServer
Procedure InitializeNewMessagesTemplate(Val MessageTemplatesSettings)
	
	MessageKind = Parameters.MessageKind;
	
	If ValueIsFilled(Parameters.FullBasisTypeName)
		 And MessageTemplatesInternal.ObjectIsTemplateSubject(Parameters.FullBasisTypeName) Then
		
		// Context call
		Object.InputOnBasisParameterTypeFullName = Parameters.FullBasisTypeName;
		If Not Parameters.CanChangeAssignment Then
			Items.AssignmentGroup.Visible = False;
		EndIf;
		
		Object.ForInputOnBasis = True;
		
		NameToAssignment = Parameters.FullBasisTypeName;
		TemplateAssignment = MessageTemplatesSettings.TemplatesSubjects.Find(NameToAssignment, "Presentation");
		If TemplateAssignment = Undefined Then
			TemplateAssignment = MessageTemplatesSettings.TemplatesSubjects.Find(NameToAssignment, "Name");
		EndIf;
		If TemplateAssignment <> Undefined Then
			Object.InputOnBasisParameterTypeFullName = TemplateAssignment.Name;
			Object.Purpose                             = TemplateAssignment.Presentation;
		Else
			Object.InputOnBasisParameterTypeFullName = NameToAssignment;
			Object.Purpose                             = NameToAssignment;
		EndIf;
		
	ElsIf Parameters.ChoiceParameters.Count() > 0 Then
		
		NameToAssignment = ?(Parameters.ChoiceParameters.Property("Purpose"), Parameters.ChoiceParameters.Purpose, "");
		
		If Parameters.ChoiceParameters.Property("InputOnBasisParameterTypeFullName") Then
			NameToAssignment = Parameters.ChoiceParameters.InputOnBasisParameterTypeFullName;
		EndIf;
			
		If ValueIsFilled(NameToAssignment) Then
			TemplateAssignment = MessageTemplatesSettings.TemplatesSubjects.Find(NameToAssignment, "Presentation");
			If TemplateAssignment = Undefined Then
				TemplateAssignment = MessageTemplatesSettings.TemplatesSubjects.Find(NameToAssignment, "Name");
			EndIf;
			If TemplateAssignment <> Undefined Then
				Object.InputOnBasisParameterTypeFullName = TemplateAssignment.Name;
				Object.Purpose                             = TemplateAssignment.Presentation;
				Object.ForInputOnBasis        = True;
				Items.AssignmentGroup.Visible           = False;
			EndIf;
		EndIf;
		
		If Parameters.ChoiceParameters.Property("ForEmails") 
			And Parameters.ChoiceParameters.ForEmails Then
			MessageKind = "MailMessage";
		ElsIf Parameters.ChoiceParameters.Property("ForSMSMessages")
			And Parameters.ChoiceParameters.ForSMSMessages Then
			MessageKind = "SMSMessage";
		Else
			MessageKind = "Arbitrary";
		EndIf;
		
	ElsIf Parameters.Basis = Undefined Then
		
		Object.ForInputOnBasis = False;
		Object.InputOnBasisParameterTypeFullName = MessageTemplatesClientServer.CommonID();
		
	EndIf;
	
	If Parameters.Basis = Undefined Then
		
		If MessageKind = "SMSMessage" Then
			Object.ForSMSMessages = True;
			Object.ForEmails = False;
		ElsIf MessageKind = "MailMessage" Then
			Object.ForSMSMessages = False;
			Object.ForEmails = True;
			Object.EmailTextType = Enums.EmailEditingMethods.HTML;
		EndIf;
		Object.AuthorOnly = False;
		
	Else
		
		TemplateGenerated = False;
		If Common.SubsystemExists("StandardSubsystems.Interactions") Then
			
			ModuleEmailManager = Common.CommonModule("EmailManagement");
			If ModuleEmailManager.IsEmailOrMessage(Parameters.Basis) Then
				TemplateBasedOnInteractionDocument();
				TemplateGenerated = True;
			EndIf;
		
		EndIf;
		
		If Not TemplateGenerated Then
			
			If Object.EmailTextType = Enums.EmailEditingMethods.HTML Then
				EmailBodyInHTML.SetHTML(Object.HTMLEmailTemplateText, New Structure);
			Else
				MessageBodyPlainText.SetText(Object.MessageTemplateText);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(Parameters.TemplateOwner) Then
		Object.TemplateOwner = Parameters.TemplateOwner;
	EndIf;
	
EndProcedure

&AtServer
Procedure TemplateBasedOnInteractionDocument()
	
	If Not Common.SubsystemExists("StandardSubsystems.Interactions")
		Or Not Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
			Return;
	EndIf;
	
	ModuleEmailManager = Common.CommonModule("EmailManagement");
	ModuleFilesOperations = Common.CommonModule("FilesOperations");
	ModuleFilesOperationsClientServer = Common.CommonModule("FilesOperationsClientServer");
	
	EmailAttachments1 = ModuleEmailManager.EmailAttachments2(Parameters.Basis, UUID);
	
	AdditionalFileParameters = ModuleFilesOperationsClientServer.FileDataParameters();
	AdditionalFileParameters.FormIdentifier = UUID;
	AdditionalFileParameters.RaiseException1 = False;
	
	For Each Attachment In EmailAttachments1 Do
		If IsBlankString(Attachment.EmailFileID) Then
			
			Extension                 = GetFileExtension(Attachment.Description);
			NewRow                = Attachments.Add();
			NewRow.Status         = "ExternalNew";
			NewRow.SelectedItemsCount        = 1;
			NewRow.Presentation  = Attachment.Description;
			NewRow.Id  = Attachment.Description;
			NewRow.PictureIndex = GetFileIconIndex(Extension);
			NewRow.Name           =  ModuleFilesOperations.FileData(Attachment.Ref,
				AdditionalFileParameters).RefToBinaryFileData;
		EndIf;
	EndDo;
	
	If Object.EmailTextType = Enums.EmailEditingMethods.HTML Then
		
		TemplateParameter = New Structure("Template, UUID");
		TemplateParameter.Template = Object.Ref;
		TemplateParameter.UUID = UUID;
		Message = MessageTemplatesInternal.MessageConstructor();
		Message.Text = Object.HTMLEmailTemplateText;
		MessageTemplatesInternal.ProcessHTMLForFormattedDocument(TemplateParameter, Message, True, EmailAttachments1);
		AttachmentsStructure = New Structure();
		For Each HTMLAttachment In Message.Attachments Do
			Image = New Picture(GetFromTempStorage(HTMLAttachment.AddressInTempStorage));
			AttachmentsStructure.Insert(HTMLAttachment.Presentation, Image);
		EndDo;
		EmailBodyInHTML.SetHTML(Message.Text, AttachmentsStructure);
		
	Else
		MessageBodyPlainText.SetText(Object.MessageTemplateText);
	EndIf;

EndProcedure

&AtServer
Procedure InitializeSaveFormats()
	
	If SelectedSaveFormats.Count() = 0 Then
		For Each SaveFormat In StandardSubsystemsServer.SpreadsheetDocumentSaveFormatsSettings() Do
			SelectedSaveFormats.Add(String(SaveFormat.SpreadsheetDocumentFileType), String(SaveFormat.Ref), False, SaveFormat.Picture);
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetTemplateText(CurrentObject, ListOfFiles = Undefined)
	
	ListOfAllParameters = FormAttributeToValue("Attributes");
	If ListOfAllParameters.Rows.Count() = 0 Then
		Return;
	EndIf;
	
	If CurrentObject.ForSMSMessages Then
		MessageBodyPlainText.SetText(
			MessageTemplatesInternal.ConvertTemplateText(CurrentObject.SMSTemplateText, ListOfAllParameters, "ParametersInPresentation"));
		
	ElsIf CurrentObject.ForEmails Then
		If CurrentObject.EmailTextType = Enums.EmailEditingMethods.HTML Then
			SetHTMLForFormattedDocument(
				MessageTemplatesInternal.ConvertTemplateText(CurrentObject.HTMLEmailTemplateText, ListOfAllParameters, "ParametersInPresentation"), CurrentObject.Ref, ListOfFiles);
		Else
			MessageBodyPlainText.SetText(
				MessageTemplatesInternal.ConvertTemplateText(CurrentObject.MessageTemplateText, ListOfAllParameters, "ParametersInPresentation"));
		EndIf;
		
		Object.EmailSubject = MessageTemplatesInternal.ConvertTemplateText(CurrentObject.EmailSubject, ListOfAllParameters, "ParametersInPresentation");
		
	Else
		MessageBodyPlainText.SetText(
			MessageTemplatesInternal.ConvertTemplateText(CurrentObject.TemplateTextArbitrary, ListOfAllParameters, "ParametersInPresentation"));
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowFormItems(EmailFormat = "")
	
	If Object.ForSMSMessages Then
		TitleSuffix = NStr("en = 'Text message template';");
		Items.FormEmailTextKind.Visible = False;
		Items.Pages.CurrentPage = Items.SMSMessage;
		Items.EmailSubject.Visible = False;
		Items.HiddenTitleParameters.Visible = False;
		Items.AttachmentsGroup.Visible = False;
		Items.AttributesContextMenuAddMailParameter.Visible = False;
		Items.AttributesMenuAddMailParameter.Visible = False;
		Items.AttributesContextMenuAddParameterToSMSMessageText.Visible = True;
		Items.AttributesMenuAddParameterToSMSMessageText.Visible = True;
		Items.HiddenTilteSMSMessage.Visible = True;
	ElsIf Object.ForEmails Then
		TitleSuffix = NStr("en = 'Email message template';");
		Items.AttachmentsGroup.Visible = True;
		Items.AttributesContextMenuAddMailParameter.Visible = True;
		Items.AttributesMenuAddMailParameter.Visible = True;
		Items.AttributesContextMenuAddParameterToSMSMessageText.Visible = False;
		Items.AttributesMenuAddParameterToSMSMessageText.Visible = False;
		
		If Not EmailFormatPredefined(EmailFormat) Then
			If Object.EmailTextType = Enums.EmailEditingMethods.HTML Then
				SetHTMLEmail();
			Else
				SetEmailPlainText();
			EndIf;
		EndIf;
		
	Else
		TitleSuffix = NStr("en = 'Message template';");
		Items.FormEmailTextKind.Visible = False;
		Items.Pages.CurrentPage = Items.MessageEmail;
		Items.EmailSubject.Visible = False;
		Items.HiddenTitleParameters.Visible = False;
		Items.AttachmentsGroup.Visible = False;
		Items.AttributesContextMenuAddMailParameter.Visible = True;
		Items.AttributesMenuAddMailParameter.Visible = True;
		Items.AttributesContextMenuAddParameterToSMSMessageText.Visible = False;
		Items.AttributesMenuAddParameterToSMSMessageText.Visible = False;
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		Title = Object.Description + " (" + TitleSuffix + ")";
	Else
		Title = TitleSuffix + " (" + NStr("en = 'Create';")+ ")";
	EndIf;
	
	If Object.TemplateByExternalDataProcessor Then
		Items.AssignmentGroup.Enabled     = False;
		Items.EmailSubject.ReadOnly        = True;
		Items.ExternalDataProcessorGroup.Visible = True;
		Items.GroupParameters.Visible        = False;
		Items.FormByExternalDataProcessor.Check   = True;
		Items.FormFromTemplate.Check           = False;
		Items.FormCheckTemplateFilling.Visible   = False;
		FillTemplateByExternalDataProcessor();
	Else
		Items.InputOnBasisParameterTypeFullName.Enabled = True;
		Items.EmailSubject.ReadOnly        = False;
		Items.ExternalDataProcessorGroup.Visible = False;
		Items.GroupParameters.Visible      = True;
		Items.FormByExternalDataProcessor.Check = False;
		Items.FormFromTemplate.Check         = True;
		Items.FormCheckTemplateFilling.Visible = True;
	EndIf;
	
	Items.Available.Visible = False;
	If RestrictionByCondition Then

		Items.Author.Visible = False;
		If Object.Ref.IsEmpty() Or Object.Author = Users.CurrentUser() Then
			Items.Available.Visible = True;
		EndIf;
		
	Else
		Items.Author.Visible    = True;
	EndIf;
		
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		Items.FormMessageToGenerateGroup.Visible = ModuleAdditionalReportsAndDataProcessors.AdditionalReportsAndDataProcessorsAreUsed();
	Else
		Items.FormMessageToGenerateGroup.Visible = False;
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.Print") Then
		Items.AttachmentsSettingsGroup.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Function EmailFormatPredefined(Val EmailFormat)
	
	If ValueIsFilled(EmailFormat) Then
		If EmailFormat = "HTMLOnly" Then
			Object.EmailTextType = Enums.EmailEditingMethods.HTML;
			SetHTMLEmail();
			Items.FormEmailHTML.Visible = False;
			Return True;
		ElsIf EmailFormat = "PlainTextOnly" Then
			Object.EmailTextType = Enums.EmailEditingMethods.NormalText;
			SetEmailPlainText();
			Items.FormEmailHTML.Visible = False;
			Return True;
		EndIf;
	EndIf;
	
	Return False;

EndFunction

&AtServer
Procedure SetHTMLForFormattedDocument(HTMLEmailTemplateText, CurrentObjectRef, ListOfFiles = Undefined)
	
	TemplateParameter = New Structure("Template, UUID");
	TemplateParameter.Template = CurrentObjectRef;
	TemplateParameter.UUID = UUID;
	Message = MessageTemplatesInternal.MessageConstructor();
	Message.Text = HTMLEmailTemplateText;
	MessageTemplatesInternal.ProcessHTMLForFormattedDocument(TemplateParameter, Message, True, ListOfFiles);
	AttachmentsStructure = New Structure();
	If ListOfFiles <> Undefined Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("FormIdentifier", UUID);
		AdditionalParameters.Insert("RaiseException1", False);
		
		For Each Attachment In ListOfFiles Do
				If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
					If ValueIsFilled(Attachment.EmailFileID) Then
						ModuleFilesOperations = Common.CommonModule("FilesOperations");
						FileInfo1 = ModuleFilesOperations.FileData(Attachment, AdditionalParameters);
						Image = New Picture(GetFromTempStorage(FileInfo1.RefToBinaryFileData));
						AttachmentsStructure.Insert(FileInfo1.Description, Image);
					EndIf;
				EndIf;
		EndDo;
	Else
		For Each HTMLAttachment In Message.Attachments Do
			Image = New Picture(GetFromTempStorage(HTMLAttachment.AddressInTempStorage));
			AttachmentsStructure.Insert(HTMLAttachment.Presentation, Image);
		EndDo;
	EndIf;
	EmailBodyInHTML.SetHTML(Message.Text, AttachmentsStructure);
	
EndProcedure

// Business logic.

&AtServer
Procedure GenerateAttributesAndPrintFormsList()
	
	DetermineIfCanAttachFiles ();
	
	TemplateParameters = MessageTemplatesInternal.TemplateParameters(Object);
	TemplateInfo = MessageTemplatesInternal.TemplateInfo(TemplateParameters);
	TemplateParameters.MessageParameters = MessageParameters;
	
	Attributes.GetItems().Clear();
	AttributesList = FormAttributeToValue("Attributes");
	FIllAttributeTree(AttributesList, TemplateInfo.Attributes);
	FIllAttributeTree(AttributesList, TemplateInfo.CommonAttributes, True);
	ValueToFormAttribute(AttributesList, "Attributes");
	
	GeneratePrintFormsList(TemplateInfo);
	
EndProcedure

&AtServer
Procedure DetermineIfCanAttachFiles ()

	If Not Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		Return;
	EndIf;
	
	ModuleFilesOperations = Common.CommonModule("FilesOperations");

	CanAttachFiles = False;
	
	MetadataObject = Common.MetadataObjectByFullName(Object.InputOnBasisParameterTypeFullName);
	If ValueIsFilled(Object.InputOnBasisParameterTypeFullName) 
		And MetadataObject <> Undefined 
		And Common.IsRefTypeObject(MetadataObject) Then
		
			EmptyRef = Common.ObjectManagerByFullName(Object.InputOnBasisParameterTypeFullName).EmptyRef();
			CanAttachFiles = ModuleFilesOperations.CanAttachFilesToObject(EmptyRef);
			If CanAttachFiles Then
				
				Items.AddAttachedFiles.Visible = True;
				Items.AddAttachedFiles.Title = StringFunctionsClientServer.SubstituteParametersToString("%1 (%2)",
						Metadata.Catalogs.MessageTemplates.Attributes.AddAttachedFiles.Presentation(), 
						Object.Purpose);
						
			EndIf;
			
	EndIf;
	
	Items.AddAttachedFiles.Visible = CanAttachFiles;
	If Not CanAttachFiles Then
		Object.AddAttachedFiles = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure GeneratePrintFormsList(TemplateInfo)
	
	SelectedPrintFormsAndAttachments = Object.PrintFormsAndAttachments.Unload(, "Id").UnloadColumn("Id");
	
	Filter = New Structure("Status", "ExternalNew");
	UnsavedFiles = Attachments.FindRows(Filter);
	Attachments.Clear();
	
	For Each Attachment In TemplateInfo.Attachments Do
		
		SelectedItemsCount = 0;
		If SelectedPrintFormsAndAttachments.Find(Attachment.Id) <> Undefined Then
			SelectedItemsCount = 1;
		ElsIf ValueIsFilled(Attachment.Attribute) Then
			SelectedItemsCount = 2;
		EndIf;
		
		NewRow = Attachments.Add();
		FillPropertyValues(NewRow, Attachment);
		Extension = ?(IsBlankString(Attachment.FileType), "mxl", Attachment.FileType);
		NewRow.PictureIndex = GetFileIconIndex(Extension);
		NewRow.SelectedItemsCount        = SelectedItemsCount;
		
	EndDo;
	
	FillAttachments();
	For Each UnsavedFile In UnsavedFiles Do
		If SelectedPrintFormsAndAttachments.Find(UnsavedFile.Id) = Undefined Then
			NewRow = Attachments.Add();
			FillPropertyValues(NewRow, UnsavedFile);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshPrintFormsList()
	
	TemplateParameters = MessageTemplatesInternal.TemplateParameters(Object);
	TemplateInfo = MessageTemplatesInternal.TemplateInfo(TemplateParameters);
	
	GeneratePrintFormsList(TemplateInfo);
	
EndProcedure

&AtServer
Function GetFileIconIndex(Extension)
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternalClientServer = Common.CommonModule("FilesOperationsInternalClientServer");
		Return ModuleFilesOperationsInternalClientServer.IndexOfFileIcon(Extension);
	EndIf;
	
	Return 0;
	
EndFunction

&AtClient
Function GetFileIconIndexClient(Extension)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternalClientServer = CommonClient.CommonModule("FilesOperationsInternalClientServer");
		Return ModuleFilesOperationsInternalClientServer.IndexOfFileIcon(Extension);
	EndIf;
	
	Return 0;
	
EndFunction

&AtServer
Procedure FIllAttributeTree(Receiver, Source, AreCommonOrArbitraryAttributes = Undefined)
	
	For Each TreeRow In Source.Rows Do
		
		If AreCommonOrArbitraryAttributes = Undefined Then
			If TreeRow.Name = MessageTemplatesClientServer.ArbitraryParametersTitle()
				Or TreeRow.Name = MessageTemplatesInternal.CommonAttributesTitle() Then
				CommonOrArbitraryAttributes = True;
			Else
				
				CommonOrArbitraryAttributes = False;
			EndIf;
		Else
			CommonOrArbitraryAttributes = AreCommonOrArbitraryAttributes;
		EndIf;
		
		PictureIndexItem = ?(CommonOrArbitraryAttributes, 1, 3);
		PictureIndexNode = ?(CommonOrArbitraryAttributes, 0, 2);
		
		NewRow = Receiver.Rows.Add();
		FillPropertyValues(NewRow, TreeRow);
		
		If TreeRow.Rows.Count() > 0 Then
			NewRow.PictureIndex = PictureIndexNode;
			FIllAttributeTree(NewRow, TreeRow, CommonOrArbitraryAttributes);
		Else
			NewRow.PictureIndex = PictureIndexItem;
		EndIf;
	EndDo;
	Receiver.Rows.Sort("Presentation", True);
	
EndProcedure

// Forced setting of properties on the server

&AtServer
Procedure SetHTMLEmail(TextWrappingRequired = False)
	
	Items.FormEmailTextKind.Title = "HTML";
	Items.MessageEmail.Visible       = False;
	Items.MessageEmailHTML.Visible   = True;
	Items.Pages.CurrentPage                   = Items.MessageEmailHTML;
	Items.FormEmailPlainText.Check = False;
	Items.FormEmailHTML.Check         = True;
	
	Object.EmailTextType = PredefinedValue("Enum.EmailEditingMethods.HTML");
	If TextWrappingRequired Then
		AttachmentsFormattedDocument = New Structure;
		MessageBodyNormalHTMLWrappedText = StrReplace(MessageBodyPlainText.GetText(), Chars.LF, "<br>");
		EmailBodyInHTML.SetHTML(MessageBodyNormalHTMLWrappedText, AttachmentsFormattedDocument);
	EndIf;
	
	Items.HiddenTitleParameters.Visible = True;
	Items.TitleParametersPages.CurrentPage = Items.TitleParametersPage;
	
EndProcedure

&AtServer
Procedure SetEmailPlainText(TextWrappingRequired = False)
	Items.FormEmailTextKind.Title = NStr("en = 'Plain Text';");
	Items.MessageEmailHTML.Visible = False;
	Items.MessageEmail.Visible = True;
	Items.Pages.CurrentPage = Items.MessageEmail;
	Items.FormEmailPlainText.Check = True;
	Items.FormEmailHTML.Check = False;
	Object.EmailTextType = PredefinedValue("Enum.EmailEditingMethods.NormalText");
	If TextWrappingRequired Then
		PlainTextTemplate = EmailBodyInHTML.GetText();
		MessageBodyPlainText.SetText(PlainTextTemplate);
		Object.MessageTemplateText = PlainTextTemplate;
	EndIf;
	
	Items.HiddenTitleParameters.Visible = False;
	Items.HiddenTilteSMSMessage.Visible = False;
	Items.TitleParametersPages.CurrentPage = Items.TitleParametersPage;
EndProcedure

// Attachments.

&AtClient
Procedure AddAttachmentExecute(Id = Undefined)
	
	AdditionalParameters = New Structure("Id", Id);
	DescriptionOfTheAlert = New NotifyDescription("FileSelectionDialogAfterChoice1", ThisObject, AdditionalParameters);
	
	FileImportParameters = FileSystemClient.FileImportParameters();
	FileImportParameters.FormIdentifier = UUID;
	FileSystemClient.ImportFiles(DescriptionOfTheAlert, FileImportParameters);
	
EndProcedure

// Parameters:
//  SelectedFiles - Array of TransferredFileDescription
//  AdditionalParameters - Structure
//
&AtClient
Procedure FileSelectionDialogAfterChoice1(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	For Each SelectedFile In SelectedFiles Do
		
		Extension                 = GetFileExtension(SelectedFile.Name);
		
		NewRow                = Attachments.Add();
		NewRow.Status         = "ExternalNew";
		NewRow.SelectedItemsCount        = 1;
		NewRow.Name            = SelectedFile.Location;
		NewRow.Presentation  = SelectedFile.FileName;
		NewRow.Id  = SelectedFile.Name;
		NewRow.PictureIndex = GetFileIconIndexClient(Extension);
		
	EndDo;
	
	Modified = True;
	
EndProcedure

// Receives an extension for the passed file name.
//
// Parameters:
//  FileName  - String - a name of the file to get the extension for.
//
// Returns:
//   String   - an extension received from the passed file.
//
&AtClientAtServerNoContext
Function GetFileExtension(Val FileName)
	
	FileExtention = "";
	RowsArray = StrSplit(FileName, ".", False);
	If RowsArray.Count() > 1 Then
		FileExtention = RowsArray[RowsArray.Count() - 1];
	EndIf;
	
	Return FileExtention;
	
EndFunction

&AtClient
Procedure PlaceFilesFromLocalFSInTempStorage(Attachments, Var_UUID, Cancel)
	
#If Not WebClient Then
	
	For Each AttachmentsTableRow In Attachments Do
		If AttachmentsTableRow.Status = "ExternalNew" Then
			Try
				
				If Not StrStartsWith(AttachmentsTableRow.Name, "e1cib") Then
					Data = New BinaryData(AttachmentsTableRow.Name);
					AttachmentsTableRow.Name = PutToTempStorage(Data, Var_UUID);
				EndIf;
				
			Except
				CommonClient.MessageToUser(ErrorProcessing.BriefErrorDescription(ErrorInfo()),, "Attachments",, Cancel);
			EndTry;
		EndIf;
	EndDo;
	
#EndIf
	
EndProcedure

&AtClient
Procedure OpenAttachmentProperties(Id)
	
	CurrentData = Attachments.FindByID(Id);
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Items.Attachments.CurrentRow = Id;
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.OpenFileForm(CurrentData.Ref);
	EndIf
	
EndProcedure

&AtClient
Procedure CopyAttachmentFile(Id)
	
	CurrentData = Attachments.FindByID(Id);
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Items.Attachments.CurrentRow = Id;
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.CopyAttachedFile(Object.Ref, CurrentData.Ref);
	EndIf
	
EndProcedure

&AtClient
Procedure ChangeAttachmentCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		Write();
		OpenAttachmentProperties(AdditionalParameters.CurrentIndexInCollection);
	EndIf;
	
EndProcedure

&AtClient
Procedure CopyAttachmentCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		If Write() Then
			CopyAttachmentFile(AdditionalParameters.CurrentIndexInCollection);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAttachments(PassedParameters = Undefined)
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		
		ListOfFiles = New Array;
		ModuleFilesOperations.FillFilesAttachedToObject(Object.Ref, ListOfFiles);
		For Each FileRef In ListOfFiles Do
			FileInfo1 = Common.ObjectAttributesValues(FileRef, "EmailFileID, PictureIndex, Description, Extension");
			If IsBlankString(FileInfo1.EmailFileID) Then
				Filter = New Structure("Attribute", FileInfo1.Description);
				FoundRows = Attachments.FindRows(Filter);
				If FoundRows.Count() = 0 Then
					NewRow = Attachments.Add();
					NewRow.Presentation = FileInfo1.Description + "." + FileInfo1.Extension;
					NewRow.PictureIndex = FileInfo1.PictureIndex;
					NewRow.Ref = FileRef;
					NewRow.Status = "ExternalAttached";
				Else
					FoundRows[0].Ref = FileRef;
				EndIf;
			EndIf;
		EndDo;
		
	EndIf
EndProcedure

&AtServer
Function CopyAttachmentsFromSource()
	
	ListOfFiles = New Array; // Array of DefinedType.AttachedFile
	ErrorList = Undefined;
	ErrorDescription = NStr("en = 'Cannot copy attachment due to: %1';");
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		ModuleFilesOperations.FillFilesAttachedToObject(Parameters.CopyingValue, ListOfFiles);
		For Each Attachment In ListOfFiles Do
			If IsBlankString(Attachment.EmailFileID) Then
				Try
					FileData = ModuleFilesOperations.FileData(Attachment, UUID, True);
				Except
					ErrorInfo = ErrorInfo();
					
					WriteErrorToEventLog(EventNameMessageTemplates(), ErrorInfo, NStr("en = 'Failed to extract and save the file';"));
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription, ErrorProcessing.BriefErrorDescription(ErrorInfo));
					CommonClientServer.AddUserError(ErrorList, "Attachments", ErrorText, "Attachments",, ErrorText);
					Continue;
				EndTry;
				NewRow                = Attachments.Add();
				NewRow.Name            = FileData.RefToBinaryFileData;
				NewRow.Presentation  = Attachment.Description + "." + Attachment.Extension;
				NewRow.PictureIndex = GetFileIconIndex(Attachment.Extension);
				NewRow.Status         = "ExternalNew";
				NewRow.Id  = Attachment.LongDesc;
			EndIf;
		EndDo;
	EndIf;
	
	CommonClientServer.ReportErrorsToUser(ErrorList);
	
	Return ListOfFiles;
	
EndFunction

&AtClient
Procedure DeleteAttachmentExecute()

	Attachment = Items.Attachments.CurrentData;
	If Attachment <> Undefined Then
		If Attachment.Status = "ExternalAttached" Or Attachment.Status = "ExternalNew" Then
			Attachment.Status = "ExternalToDelete";
			Attachment.PictureIndex = Attachment.PictureIndex + 1;
			Modified = True;
		ElsIf Attachment.Status = "ExternalToDelete" Then
			Attachment.PictureIndex = Attachment.PictureIndex - 1;
			Attachment.Status = ?(ValueIsFilled(Attachment.Ref), "ExternalAttached", "ExternalNew");
		EndIf;
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteAttachedFile(AttachedFile)
	
	SetPrivilegedMode(True);
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.MessageTemplatesAttachedFiles");
	LockItem.SetValue("Ref", AttachedFile);
	Block.Lock();
	
	ObjectAttachment = AttachedFile.GetObject();
	ObjectAttachment.Lock();
	
	ObjectAttachment.Delete();
	
EndProcedure

&AtServer
Procedure ChangePicturesNamesToMailAttachmentsIDsInHTML(HTMLDocument, MapsTable)
	
	For Each Picture In HTMLDocument.Images Do
		
		AttributePictureSource = Picture.Attributes.GetNamedItem("src");
		FoundRow = MapsTable.FindByValue(AttributePictureSource.TextContent);
		If FoundRow <> Undefined Then
			
			NewAttributePicture = AttributePictureSource.CloneNode(False);
			NewAttributePicture.TextContent = String("cid:" + FoundRow.Presentation);
			Picture.Attributes.SetNamedItem(NewAttributePicture);
			
		EndIf;
	EndDo;
	
EndProcedure

// Saves formatted document pictures as attached object files.
//
// Parameters:
//  Ref  - DocumentRef - ссылка на владельца присоединенных файлов.
//  EmailTextType  - EnumRef.EmailEditingMethods - to define whether
//                                                                                transformations are necessary.
//  AttachmentsNamesToIDsMapsTable  - ValueTable - it allows to determine, which picture
//                                                                      matches which attachment.
//  Var_UUID  - UUID - a form UUID used for saving.
//
&AtServer
Procedure SaveFormattedDocumentPicturesAsAttachedFiles(Ref, EmailTextType,
	                                                                        AttachmentsNamesToIDsMapsTable,
	                                                                        Var_UUID)
	
	If EmailTextType = Enums.EmailEditingMethods.HTML Then
		
		For Each Attachment In AttachmentsNamesToIDsMapsTable Do
			
			BinaryPictureData = Attachment.Picture.GetBinaryData(); // BinaryData
			PictureAddressInTempStorage = PutToTempStorage(BinaryPictureData, Var_UUID);
			AttachedFile = WriteEmailAttachmentFromTempStorage(Ref, PictureAddressInTempStorage,
				"_" + StrReplace(Attachment.Presentation, "-", "_"), BinaryPictureData.Size());
			
			If AttachedFile <> Undefined Then
				
				Block = New DataLock;
				LockItem = Block.Add("Catalog.MessageTemplatesAttachedFiles");
				LockItem.SetValue("Ref", AttachedFile);
				Block.Lock();
				
				AttachedFileObject = AttachedFile.GetObject();
				AttachedFileObject.Lock();
				
				AttachedFileObject.EmailFileID = Attachment.Presentation;
				AttachedFileObject.Write();
				
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Function WriteEmailAttachmentFromTempStorage(MailMessage, AddressInTempStorage, FileName,
		Size, CountOfBlankNamesInAttachments = 0)
		
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		
		FileNameToParse = FileName;
		ExtensionWithoutPoint = GetFileExtension(FileNameToParse);
		BaseName = CommonClientServer.ReplaceProhibitedCharsInFileName(FileNameToParse);
		If IsBlankString(BaseName) Then
			
			CountOfBlankNamesInAttachments = CountOfBlankNamesInAttachments + 1;
			
		Else
			BaseName = ?(ExtensionWithoutPoint = "", BaseName,
				Left(BaseName, StrLen(BaseName) - StrLen(ExtensionWithoutPoint) - 1));
		EndIf;
			
		FileParameters = ModuleFilesOperations.FileAddingOptions();
		FileParameters.FilesOwner = MailMessage;
		FileParameters.BaseName = BaseName;
		FileParameters.ExtensionWithoutPoint = ExtensionWithoutPoint;
		Return ModuleFilesOperations.AppendFile(FileParameters, AddressInTempStorage, "");
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AttachmentsSelected.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Attachments.Status");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Contains;
	ItemFilter.RightValue = "External";
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Attachments.Attribute");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	Item.Appearance.SetParameterValue("Enabled", False);
	Item.Appearance.SetParameterValue("Show", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AttachmentsPresentation.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AttachmentsSelected.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Attachments.Status");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Contains;
	ItemFilter.RightValue = "ExternalToDelete";

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

&AtClient
Procedure AfterAdditionalReportsAndDataProcessorsChoice(Result, AddlParameters) Export
	If Result <> Undefined Then
		Items.ExternalDataProcessorGroup.Visible = True;
		Items.Pages.CurrentPage = Items.MessageExternalDataProcessor;
		Items.GroupParameters.Visible = False;
		Items.FormFromTemplate.Check = False;
		Items.FormByExternalDataProcessor.Check = True;
		Object.TemplateByExternalDataProcessor = True;
		Object.ExternalDataProcessor = Result;
		ShowFormItems();
	EndIf;
EndProcedure

&AtServer
Procedure WriteErrorToEventLog(EventName, ErrorInfo, EventText)
	
	Comment = EventText + Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo);
	WriteLogEvent(EventName, EventLogLevel.Error, Metadata.Catalogs.MessageTemplates,, Comment);
	
EndProcedure

&AtServer
Function EventNameMessageTemplates()
	
	Return NStr("en = 'Message templates';", Common.DefaultLanguageCode());
	
EndFunction

&AtServer
Procedure FillArbitraryParametersFromObject(Val CurrentObject)
	
	For Each TemplateParameterCurrentObject In CurrentObject.Parameters Do
		Filter = New Structure("ParameterName", TemplateParameterCurrentObject.ParameterName);
		FoundRows = Object.Parameters.FindRows(Filter);
		If FoundRows.Count() > 0 Then
			FoundRows[0].TypeDetails = TemplateParameterCurrentObject.ParameterType.Get();
		EndIf;
	EndDo;

EndProcedure

// External data processor.

&AtServer
Procedure FillTemplateByExternalDataProcessor()
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		
		ClearTemplate(ThisObject);
		ExternalObject = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorObject(Object.ExternalDataProcessor);
		
		If ExternalObject = Undefined Then
			Return;
		EndIf;
		
		DataProcessorKind = Common.ObjectAttributeValue(Object.ExternalDataProcessor, "Kind");
		If Not ModuleAdditionalReportsAndDataProcessors.IsDataProcessorTypeForMessageTemplates(DataProcessorKind) Then
			Return;
		EndIf;
		
		MessageTemplatesSettings = MessageTemplatesInternalCached.OnDefineSettings();
		ExternalDataProcessorDataStructure = ExternalObject.DataStructureToDisplayInTemplate();
		
		TemplateSubject = DefineMessageTemplatesubject(ExternalDataProcessorDataStructure.InputOnBasisParameterTypeFullName, MessageTemplatesSettings);
		
		If TemplateSubject <> Undefined Then
			
			Object.InputOnBasisParameterTypeFullName = TemplateSubject.Name;
			Object.Purpose                             = TemplateSubject.Presentation;
			
		Else
			
			ErrorDescription = NStr("en = 'Subject ""%1"" specified in the external data processor is not found. Cannot attach the external data processor.';");
			Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription, ExternalDataProcessorDataStructure.InputOnBasisParameterTypeFullName);
			
		EndIf;
		
		Object.TemplateByExternalDataProcessor = True;
		Object.ForInputOnBasis = True;
		
		If ExternalDataProcessorDataStructure.ForSMSMessages Then
			
			MessageBodyPlainText.SetText(ExternalDataProcessorDataStructure.SMSTemplateText);
			Object.ForSMSMessages              = True;
			Object.ForEmails = False;
			
		ElsIf ExternalDataProcessorDataStructure.ForEmails Then
			
			Object.EmailSubject = ExternalDataProcessorDataStructure.EmailSubject;
			Object.HTMLEmailTemplateText = ExternalDataProcessorDataStructure.HTMLEmailTemplateText;
			
			If ExternalDataProcessorDataStructure.EmailTextType = Enums.EmailEditingMethods.HTML Then
				SetHTMLEmail(True);
				AttachmentStructure1 = New Structure;
				EmailBodyInHTML.SetHTML(ExternalDataProcessorDataStructure.HTMLEmailTemplateText, AttachmentStructure1);
			Else
				SetEmailPlainText(True);
				MessageBodyPlainText.SetText(ExternalDataProcessorDataStructure.HTMLEmailTemplateText);
			EndIf;
			
			Object.ForEmails = True;
			Object.ForSMSMessages              = False;
		
		Else
			MessageBodyPlainText.SetText(ExternalDataProcessorDataStructure.TemplateTextArbitrary);
		EndIf
		
	EndIf
	
EndProcedure

&AtClientAtServerNoContext
Function DefineMessageTemplatesubject(NameToAssignment, Val MessageTemplatesSettings)
	
	TemplateAssignment = MessageTemplatesSettings.TemplatesSubjects.Find(NameToAssignment, "Presentation");
	If TemplateAssignment = Undefined Then
		TemplateAssignment = MessageTemplatesSettings.TemplatesSubjects.Find(NameToAssignment, "Name");
	EndIf;
	
	Return TemplateAssignment;

EndFunction

&AtClientAtServerNoContext
Procedure ClearTemplate(Form)
	
	Form.Object.Parameters.Clear();
	Form.Object.ForEmails        = True;
	Form.Object.ForSMSMessages                     = False;
	Form.Object.ForInputOnBasis        = False;
	Form.Object.InputOnBasisParameterTypeFullName = "";
	Form.Object.EmailSubject                             = "";
	Form.Object.SMSTemplateText                        = "";
	Form.Object.MessageTemplateText                     = "";
	Form.Object.HTMLEmailTemplateText                 = "<html></html>";
	Form.Object.EmailTextType                        = PredefinedValue("Enum.EmailEditingMethods.NormalText");
	
EndProcedure

&AtClient
Procedure AddParameterToMessageText1()
	
	If Items.Attributes.SelectedRows <> Undefined Then
		Text = "";
		For Each LineNumber In Items.Attributes.SelectedRows Do
			FoundRow = Attributes.FindByID(LineNumber);
			If FoundRow <> Undefined Then
				OutputFormat = ?(IsBlankString(FoundRow.Format), "", "{" + FoundRow.Format +"}");
				Text = Text + "[" + FoundRow.FullPresentation + OutputFormat + "] ";
			EndIf;
		EndDo;
		If Object.EmailTextType = PredefinedValue("Enum.EmailEditingMethods.HTML") Then
			If IsBlankString(Items.EmailBodyInHTML.SelectedText) Then
				BookmarkToInsertStart = Undefined;
				BookmarkToInsertEnd  = Undefined;
				Items.EmailBodyInHTML.GetTextSelectionBounds(BookmarkToInsertStart, BookmarkToInsertEnd);
				EmailBodyInHTML.Insert(BookmarkToInsertEnd, Text);
			Else
				Items.EmailBodyInHTML.SelectedText = Text;
			EndIf;
		Else
			If Object.ForSMSMessages Then
				Items.MessageBodySMSMessagePlainText.SelectedText = Text;
			Else
				Items.MessageBodyPlainText.SelectedText = Text;
			EndIf;
		EndIf;
	EndIf;

EndProcedure

#EndRegion