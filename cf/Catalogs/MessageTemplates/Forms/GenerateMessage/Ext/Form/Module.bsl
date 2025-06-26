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
	
	SubjectOf            = Parameters.SubjectOf;
	MessageKind       = Parameters.MessageKind;
	ChoiceMode        = Parameters.ChoiceMode;
	TemplateOwner    = Parameters.TemplateOwner;
	MessageParameters = Parameters.MessageParameters;
	PrepareTemplate  = Parameters.PrepareTemplate;
	
	If TypeOf(MessageParameters) = Type("Structure") And MessageParameters.Property("MessageSourceFormName") Then
		MessageSourceFormName = MessageParameters.MessageSourceFormName;
	EndIf;
	
	If ValueIsFilled(SubjectOf) And TypeOf(SubjectOf) <> Type("String") Then
		FullBasisTypeName = SubjectOf.Metadata().FullName();
	EndIf;
	
	If MessageKind = "SMSMessage" Then
		ForSMSMessages = True;
		Title = NStr("en = 'Text templates';");
	ElsIf MessageKind = "MailMessage" Then
		ForEmails = True;
	Else
		Title = NStr("en = 'Message templates';");
	EndIf;
	
	If Not AccessRight("Update", Metadata.Catalogs.MessageTemplates) Then
		HasUpdateRight = False;
		Items.FormChange.Visible = False;
		Items.FormCreate.Visible  = False;
	Else
		HasUpdateRight = True;
	EndIf;
	
	If ChoiceMode Or MessageKind = "Arbitrary" Then
		Items.FormGenerateAndSend.Visible = False;
		Items.FormGenerate.Title = NStr("en = 'Select';");
	ElsIf PrepareTemplate Then
		Items.FormGenerateAndSend.Visible = False;
	EndIf;
	
	FillAvailableTemplatesList();
	FillPrintFormsList();
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		For Each SaveFormat In ModulePrintManager.SpreadsheetDocumentSaveFormatsSettings() Do
			SelectedSaveFormats.Add(String(SaveFormat.SpreadsheetDocumentFileType), SaveFormat.Presentation, False, SaveFormat.Picture);
		EndDo;
		Items.SignatureAndSeal.Visible = ModulePrintManager.PrintSettings().UseSignaturesAndSeals;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_MessageTemplates" Then
		SelectedItemRef = Undefined;
		If Items.Templates.CurrentData <> Undefined Then
			SelectedItemRef = Items.Templates.CurrentData.Ref;
		EndIf;
		FillAvailableTemplatesList();
		FoundRows = Templates.FindRows(New Structure("Ref", SelectedItemRef));
		If FoundRows.Count() > 0 Then
			Items.Templates.CurrentRow = FoundRows[0].GetID();
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ShowTemplatesChoiceForm Then
		If CommonClient.SubsystemExists("StandardSubsystems.Print") Then
			SetFormatSelection();
			GeneratePresentationForSelectedFormats();
		EndIf;
	Else
		SendOptions = SendOptionsConstructor();
		SendOptions.AdditionalParameters.ConvertHTMLForFormattedDocument = False;
		GenerateMessageToSend(SendOptions);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AttachmentFormatClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	NotifyDescription = New NotifyDescription("OnSelectAttachmentFormat", ThisObject);
	CommonClient.ShowAttachmentsFormatSelection(NotifyDescription, SelectedFormatSettings(), ThisObject);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersTemplates

&AtClient
Procedure TemplatesBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	Cancel = True;
	If Copy And Not Var_Group Then
		CreateNewTemplate(Item.CurrentData.Ref);
	Else
		CreateNewTemplate();
	EndIf;
EndProcedure

&AtClient
Procedure TemplatesBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure TemplatesOnActivateRow(Item)
	If Item.CurrentData <> Undefined Then
		TemplateSelected = Item.CurrentData.Name <> "<NoTemplate>";
		Items.FormGenerateAndSend.Enabled = TemplateSelected;
		If TemplateSelected Or Not CommonClient.SubsystemExists("StandardSubsystems.Print") Then
			If Item.CurrentData.EmailTextType = PredefinedValue("Enum.EmailEditingMethods.HTML") Then
				Items.PreviewPages.CurrentPage = Items.FormattedDocumentPage;
				AttachIdleHandler("UpdatePreviewData", 0.2, True);
			Else
				Items.PreviewPages.CurrentPage = Items.PlainTextPage;
				PreviewPlainText.SetText(Item.CurrentData.TemplateText);
			EndIf;
		Else
			Items.PreviewPages.CurrentPage = Items.PrintFormsPage;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure TemplatesBeforeRowChange(Item, Cancel)
	Cancel = True;
	If Item.CurrentData <> Undefined Then
		FormParameters = New Structure("Key", Item.CurrentData.Ref);
		OpenForm("Catalog.MessageTemplates.ObjectForm", FormParameters);
	EndIf;
EndProcedure

&AtClient
Procedure TemplatesSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	GenerateMessageFromSelectedTemplate();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Generate(Command)
	
	GenerateMessageFromSelectedTemplate();
	
EndProcedure

&AtClient
Procedure GenerateAndSend(Command)
	
	If TypeOf(Items.Templates.CurrentRow) <> Type("Number") Then
		Return;
	EndIf;
	
	CurrentData = Templates.FindByID(Items.Templates.CurrentRow);
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	SendOptions = SendOptionsConstructor(CurrentData.Ref);
	GenerateAndSend = True;
	If CurrentData.HasArbitraryParameters Then
		ParametersInput(CurrentData.Ref, SendOptions);
	Else
		SendMessage1(SendOptions);
	EndIf;
	
EndProcedure

&AtClient
Procedure Create(Command)
	CreateNewTemplate();
EndProcedure

&AtClient
Procedure ParametersInput(Template, SendOptions)
	
	ParametersToFill = New Structure("Template, SubjectOf", Template, SubjectOf);
	
	Notification = New NotifyDescription("AfterParametersInput", ThisObject, SendOptions);
	OpenForm("Catalog.MessageTemplates.Form.FillArbitraryParameters", ParametersToFill,,,,, Notification);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GenerateMessageFromSelectedTemplate()

	If TypeOf(Items.Templates.CurrentRow) <> Type("Number") Then
		Return;
	EndIf;
	
	CurrentData = Templates.FindByID(Items.Templates.CurrentRow);
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ChoiceMode Or MessageKind = "Arbitrary" Then
		Close(CurrentData.Ref);
		Return;
	EndIf;
	
	SendOptions = SendOptionsConstructor(CurrentData.Ref);
	SendOptions.AdditionalParameters.ConvertHTMLForFormattedDocument = True;
	
	If CurrentData.HasArbitraryParameters Then
		ParametersInput(CurrentData.Ref, SendOptions);
	Else
		GenerateMessageToSend(SendOptions);
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateMessageToSend(SendOptions)
	
	ShouldGenerateWithoutTempl = Not ValueIsFilled(SendOptions.Template);
	If ShouldGenerateWithoutTempl And PrintForms.Count() > 0 Then
		SavePrintFormsChoice();
	EndIf;
	
	TempStorageAddress = Undefined;
	TempStorageAddress = PutToTempStorage(Undefined, UUID);
	
	ShouldGenerateWithoutTemplateAndSign = ShouldGenerateWithoutTempl And Sign;
	If ShouldGenerateWithoutTemplateAndSign Then
		SendOptions.AdditionalParameters.SettingsForSaving.PackToArchive = False;
	EndIf;
	
	ResultAddress = GenerateMessageAtServer(TempStorageAddress, SendOptions, MessageKind);
	
	Result = GetFromTempStorage(ResultAddress); // See MessageTemplatesInternal.GenerateMessage
	
	Result.Insert("SubjectOf", SubjectOf);
	Result.Insert("Template",  SendOptions.Template);
	If SendOptions.AdditionalParameters.Property("MessageParameters")
		And TypeOf(SendOptions.AdditionalParameters.MessageParameters) = Type("Structure") Then
		CommonClientServer.SupplementStructure(Result, MessageParameters, False);
	EndIf;
	
	If ShouldGenerateWithoutTemplateAndSign 
	   And TypeOf(Result.Attachments) = Type("Array") 
	   And Result.Attachments.Count() > 0 Then
		SendOptions.AdditionalParameters.SettingsForSaving.PackToArchive = PackToArchive;
		SIgnFiles(Result, SendOptions);
	Else
		GenerateMessageToSendEnding(Result, SendOptions)
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateMessageToSendEnding(Result, SendOptions)
	
	If GenerateAndSend Then
		AfterGenerateAndSendMessage(Result, SendOptions);
	Else
		If PrepareTemplate Then
			Close(Result);
		Else
			Close();
			ShowMessageForm(Result);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function GenerateMessageAtServer(TempStorageAddress, SendOptions, MessageKind)
	
	ServerCallParameters = New Structure();
	ServerCallParameters.Insert("SendOptions", SendOptions);
	ServerCallParameters.Insert("MessageKind",      MessageKind);
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		SendOptions.AdditionalParameters.Insert("ExtendedRecipientsList", ModuleInteractions.AreOtherInteractionsUsed());
	EndIf;
	
	MessageTemplatesInternal.GenerateMessageInBackground(ServerCallParameters, TempStorageAddress, GenerateAndSend);
	
	Return TempStorageAddress;
	
EndFunction

// Parameters:
//  Result - Map - if data was entered by the user:
//            - DialogReturnCode - — if data input is canceled
//            - Undefined - — if the window was closed
//  SendOptions - See MessageTemplatesClientServer.SendOptionsConstructor
//
&AtClient
Procedure AfterParametersInput(Result, SendOptions) Export
	
	If Result <> Undefined And Result <> DialogReturnCode.Cancel Then
		SendOptions.AdditionalParameters.ArbitraryParameters = Result;
		GenerateMessageToSend(SendOptions);
	EndIf;
	
EndProcedure

&AtClient
Procedure SendMessage1(Val MessageSendOptions)
	
	If MessageKind = "MailMessage" Then
		If CommonClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
			NotifyDescription = New NotifyDescription("SendMessageAccountCheckCompleted", ThisObject, MessageSendOptions);
			ModuleEmailOperationsClient = CommonClient.CommonModule("EmailOperationsClient");
			ModuleEmailOperationsClient.CheckAccountForSendingEmailExists(NotifyDescription);
		EndIf;
	ElsIf MessageKind = "SMSMessage" Then
		GenerateMessageToSend(MessageSendOptions);
	EndIf;
	
EndProcedure

&AtClient
Procedure SendMessageAccountCheckCompleted(AccountSetUp, SendOptions) Export
	
	If AccountSetUp = True Then
		GenerateMessageToSend(SendOptions);
	EndIf;
	
EndProcedure


// Parameters:
//  Result - See MessageTemplatesInternal.EmailSendingResult
//  SendOptions - Structure
//
&AtClient
Procedure AfterGenerateAndSendMessage(Result, SendOptions)
	
	If IsBlankString(Result.ErrorDescription)Then;
		Close();
	Else
		Notification = New NotifyDescription("AfterQuestionOnOpenMessageForm", ThisObject, SendOptions);
		ErrorDescription = Result.ErrorDescription + Chars.LF + NStr("en = 'Do you want to open the message?';");
		ShowQueryBox(Notification, ErrorDescription, QuestionDialogMode.YesNo);
	EndIf;

EndProcedure

&AtClient
Procedure ShowMessageForm(Message)
	
	If MessageKind = "SMSMessage" Then
		If CommonClient.SubsystemExists("StandardSubsystems.SendSMSMessage") Then 
			ModuleSMSClient= CommonClient.CommonModule("SendSMSMessageClient");
			
			AdditionalParameters = New Structure("Transliterate");
			If Message.AdditionalParameters <> Undefined Then
				FillPropertyValues(AdditionalParameters, Message.AdditionalParameters);
			EndIf;
			
			AdditionalParameters.Transliterate = ?(Message.AdditionalParameters.Property("Transliterate"),
				Message.AdditionalParameters.Transliterate, False);
			AdditionalParameters.Insert("SubjectOf", SubjectOf);
			Text      = ?(Message.Property("Text"), Message.Text, "");
			
			Recipient = New Array;
			IsValueList = (TypeOf(Message.Recipient) = Type("ValueList"));
			
			For Each InformationOnRecipient In Message.Recipient Do
				If IsValueList Then
					Phone                      = InformationOnRecipient.Value;
					ContactInformationSource = "";
				Else 
					Phone                      = InformationOnRecipient.PhoneNumber;
					ContactInformationSource = InformationOnRecipient.ContactInformationSource ;
				EndIf;
				
				RecipientData = New Structure();
				RecipientData.Insert("Presentation",                InformationOnRecipient.Presentation);
				RecipientData.Insert("Phone",                      Phone);
				RecipientData.Insert("ContactInformationSource", ContactInformationSource);
				Recipient.Add(RecipientData);
				
			EndDo;
			
			ModuleSMSClient.SendSMS(Recipient, Text, AdditionalParameters);
		EndIf;
	ElsIf MessageKind = "MailMessage" Then
		If CommonClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
			ModuleEmailOperationsClient = CommonClient.CommonModule("EmailOperationsClient");
			ModuleEmailOperationsClient.CreateNewEmailMessage(Message);
		EndIf;
	EndIf;
	
	If Message.Property("UserMessages")
		And Message.UserMessages <> Undefined
		And Message.UserMessages.Count() > 0 Then
			For Each UserMessages In Message.UserMessages Do
				CommonClient.MessageToUser(UserMessages.Text,
					UserMessages.DataKey, UserMessages.Field, UserMessages.DataPath);
			EndDo;
	EndIf;
	
EndProcedure

&AtClient
Function SendOptionsConstructor(Template = Undefined)
	
	SendOptions = MessageTemplatesClientServer.SendOptionsConstructor(Template, SubjectOf, UUID);
	SendOptions.AdditionalParameters.MessageKind       = MessageKind;
	SendOptions.AdditionalParameters.MessageParameters = MessageParameters;
	
	If Not ValueIsFilled(Template) Then
		For Each PrintForm In PrintForms Do
			If PrintForm.Check Then
				SendOptions.AdditionalParameters.PrintForms.Add(PrintForm.Value);
			EndIf;
		EndDo;
		
		SendOptions.AdditionalParameters.SettingsForSaving = SelectedFormatSettings();
	EndIf;
	
	Return SendOptions;
	
EndFunction

// Parameters:
//  Result - DialogReturnCode
//  SendOptions -See MessageTemplatesClientServer.SendOptionsConstructor
// 
&AtClient
Procedure AfterQuestionOnOpenMessageForm(Result, SendOptions) Export
	
	If Result = DialogReturnCode.Yes Then
		GenerateAndSend = False;
		SendOptions.AdditionalParameters.ConvertHTMLForFormattedDocument = True;
		GenerateMessageToSend(SendOptions);
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateNewTemplate(CopyingValue = Undefined)
	
	FormParameters = New Structure();
	FormParameters.Insert("MessageKind"          , MessageKind);
	FormParameters.Insert("FullBasisTypeName",
		?(ValueIsFilled(FullBasisTypeName), FullBasisTypeName, SubjectOf));
	FormParameters.Insert("AuthorOnly",        True);
	FormParameters.Insert("TemplateOwner",        TemplateOwner);
	FormParameters.Insert("CopyingValue",    CopyingValue);
	FormParameters.Insert("New",                  True);
	
	OpenForm("Catalog.MessageTemplates.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtServer
Procedure FillAvailableTemplatesList()
	
	Templates.Clear();
	
	TemplateType = "Arbitrary";
	If ForSMSMessages Then
		TemplateType = "SMS";
	ElsIf ForEmails Then
		TemplateType = "MailMessage";
	EndIf;
	
	Query = MessageTemplatesInternal.PrepareQueryToGetTemplatesList(TemplateType, SubjectOf, TemplateOwner);
	
	QueryResult = Query.Execute().Select();
		
	While QueryResult.Next() Do
		NewRow = Templates.Add();
		FillPropertyValues(NewRow, QueryResult);
		
		If QueryResult.TemplateByExternalDataProcessor
			And Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
				ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
				ExternalObject = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorObject(QueryResult.ExternalDataProcessor);
				TemplateParameters = ExternalObject.TemplateParameters();
				
				If TemplateParameters.Count() > 1 Then
					HasArbitraryParameters = True;
				Else
					HasArbitraryParameters = False;
				EndIf;
		Else
			ArbitraryParameters = QueryResult.HasArbitraryParameters.Unload();
			HasArbitraryParameters = ArbitraryParameters.Count() > 0;
		EndIf;
		
		NewRow.HasArbitraryParameters = HasArbitraryParameters;
	EndDo;
	
	If Templates.Count() = 0 Then
		MessageTemplatesSettings = MessageTemplatesInternalCached.OnDefineSettings();
		ShowTemplatesChoiceForm = MessageTemplatesSettings.AlwaysShowTemplatesChoiceForm;
	Else
		ShowTemplatesChoiceForm = True;
	EndIf;
	
	Templates.Sort("Presentation");
	
	If Not ChoiceMode And Not PrepareTemplate Then
		FirstRow = Templates.Insert(0);
		FirstRow.Name = "<NoTemplate>";
		FirstRow.Presentation = NStr("en = '<No template>';");
	EndIf;
	
	If Templates.Count() = 0 Then
		Items.FormCreate.LocationInCommandBar = ButtonLocationInCommandBar.InCommandBar;
		Items.FormCreate.Representation = ButtonRepresentation.PictureAndText;
		Items.FormGenerate.Enabled           = False;
		Items.FormGenerateAndSend.Enabled = False;
	Else
		Items.FormGenerate.Enabled           = True;
		Items.FormGenerateAndSend.Enabled = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdatePreviewData()
	CurrentData = Items.Templates.CurrentData;
	If CurrentData <> Undefined Then
		SetHTMLInFormattedDocument(CurrentData.TemplateText, CurrentData.Ref);
	EndIf;
EndProcedure

&AtServer
Procedure SetHTMLInFormattedDocument(HTMLEmailTemplateText, CurrentObjectRef);
	
	Message = MessageTemplatesInternal.MessageConstructor();
	
	TemplateParameter = New Structure("Template, UUID");
	TemplateParameter.Template = CurrentObjectRef;
	TemplateParameter.UUID = UUID;
	Message.Text = HTMLEmailTemplateText;
	MessageTemplatesInternal.ProcessHTMLForFormattedDocument(TemplateParameter, Message, True);
	AttachmentsStructure = New Structure();
	For Each HTMLAttachment In Message.Attachments Do
		Image = New Picture(GetFromTempStorage(HTMLAttachment.AddressInTempStorage));
		AttachmentsStructure.Insert(HTMLAttachment.Presentation, Image);
	EndDo;
	
	TemplateParameters = MessageTemplatesInternal.TemplateParameters(CurrentObjectRef);
	TemplateInfo = MessageTemplatesInternal.TemplateInfo(TemplateParameters);
	
	Message.Text = MessageTemplatesInternal.ConvertTemplateText(Message.Text , TemplateInfo.Attributes, "ParametersInPresentation");
	Message.Text = MessageTemplatesInternal.ConvertTemplateText(Message.Text , TemplateInfo.CommonAttributes, "ParametersInPresentation");
	PreviewFormattedDocument.SetHTML(Message.Text, AttachmentsStructure);
	
EndProcedure

&AtClient
Procedure SetFormatSelection(Val SaveFormats = Undefined)
	
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
		SelectedSaveFormats[0].Check = True; // The default choice is the first in the list.
	EndIf;
	
EndProcedure

&AtClient
Procedure GeneratePresentationForSelectedFormats()
	
	AttachmentFormat = "";
	FormatsCount = 0;
	For Each SelectedFormat In SelectedSaveFormats Do
		If SelectedFormat.Check Then
			If Not IsBlankString(AttachmentFormat) Then
				AttachmentFormat = AttachmentFormat + ", ";
			EndIf;
			AttachmentFormat = AttachmentFormat + SelectedFormat.Presentation;
			FormatsCount = FormatsCount + 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Function SelectedFormatSettings()
	
	Result = CommonInternalClient.PrintFormFormatSettings();
	
	For Each SelectedFormat In SelectedSaveFormats Do
		If SelectedFormat.Check Then
			Result.SaveFormats.Add(SelectedFormat.Value);
		EndIf;
	EndDo;

	Result.PackToArchive = PackToArchive;
	Result.TransliterateFilesNames = TransliterateFilesNames;
	Result.SignatureAndSeal = SignatureAndSeal;
	
	Return Result;
	
EndFunction

&AtClient
Procedure OnSelectAttachmentFormat(ValueSelected, AdditionalParameters) Export
	
	If ValueSelected <> DialogReturnCode.Cancel And ValueSelected <> Undefined Then
		SetFormatSelection(ValueSelected.SaveFormats);
		PackToArchive = ValueSelected.PackToArchive;
		TransliterateFilesNames = ValueSelected.TransliterateFilesNames;
		Sign = ValueSelected.Sign;
		GeneratePresentationForSelectedFormats();
	EndIf;
		
EndProcedure

&AtServer
Procedure FillPrintFormsList()
	
	If MessageKind = "Arbitrary" Or MessageKind = "SMSMessage" Or ChoiceMode Or PrepareTemplate
		Or TypeOf(SubjectOf) = Type("String") Or Not ValueIsFilled(SubjectOf) Then
		Items.SelectPrintForms.Visible = False;
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		
		PrintCommands = Undefined;
		If ValueIsFilled(MessageSourceFormName) Then
			PrintCommands = Common.ValueTableToArray(ModulePrintManager.FormPrintCommands(
				MessageSourceFormName, CommonClientServer.ValueInArray(SubjectOf.Metadata())));
		EndIf;
		
		If Not ValueIsFilled(PrintCommands) Then
			Items.SelectPrintForms.Visible = False;
			Return;
		EndIf;
		
		PrintFormsSelectedEarlier = PrintFormsSelectedEarlier();
		
		For Each PrintCommand In PrintCommands Do
			Check = PrintFormsSelectedEarlier.Find(PrintCommand.UUID) <> Undefined;
			PrintForms.Add(PrintCommand, PrintCommand.Presentation, Check);
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SavePrintFormsChoice()
	
	If Not ValueIsFilled(MessageSourceFormName) Then
		Return;
	EndIf;
	
	IDs = New Array;
	For Each PrintForm In PrintForms Do
		If PrintForm.Check Then
			IDs.Add(PrintForm.Value.UUID);
		EndIf;
	EndDo;
	
	Common.CommonSettingsStorageSave(
		"SendPrintFormsWithoutTemplate", MessageSourceFormName, IDs);
	
EndProcedure

&AtServer
Function PrintFormsSelectedEarlier()
	
	Result = New Array;
	
	If ValueIsFilled("MessageSourceFormName") Then
		Result = Common.CommonSettingsStorageLoad(
			"SendPrintFormsWithoutTemplate", MessageSourceFormName, New Array);
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure SIgnFiles(Result, SendOptions)
	FilesToSign = Result.Attachments;
	
	Context = New Structure;
	Context.Insert("Result", Result);
	Context.Insert("SendOptions", SendOptions);
	
	NotifyDescription = New NotifyDescription("GenerateMessageToSendFollowUp", ThisObject, Context);
	
	If CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		DataDetails = New Structure;
		DataDetails.Insert("ShowComment", False);
		If FilesToSign.Count() > 1 Then
			DataDetails.Insert("Operation",            NStr("en = 'Sign files';"));
			DataDetails.Insert("DataTitle",     NStr("en = 'Files';"));
			
			DataSet = New Array;
			For Each File In FilesToSign Do
				DescriptionOfFileData = New Structure;
				DescriptionOfFileData.Insert("Presentation", File.Presentation);
				DescriptionOfFileData.Insert("Data", File.AddressInTempStorage);
				DescriptionOfFileData.Insert("PrintObject", SubjectOf);
				DataSet.Add(DescriptionOfFileData);
			EndDo;
			
			DataDetails.Insert("DataSet", DataSet);
			DataDetails.Insert("SetPresentation", "Files (%1)");
		Else
			File = FilesToSign[0];
			DataDetails.Insert("Operation",        NStr("en = 'Sign a file';"));
			DataDetails.Insert("DataTitle", NStr("en = 'File';"));
			DataDetails.Insert("Presentation", File.Presentation);
			DataDetails.Insert("Data", File.AddressInTempStorage);
			DataDetails.Insert("PrintObject", SubjectOf);
		EndIf;
		
		ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
		SignatureParameters = ModuleDigitalSignatureClient.NewSignatureType();
		SignatureParameters.CanSelectLetterOfAuthority = True;
		ModuleDigitalSignatureClient.Sign(DataDetails,,NotifyDescription, SignatureParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateMessageToSendFollowUp(SigningResult, Context) Export
	
	If TypeOf(SigningResult) = Type("Structure") And SigningResult.Property("Success") And Not SigningResult.Success Then
		Return;
	EndIf;
	
	Attachments = GetSignatureFilesAndPutToArchive(SigningResult, TransliterateFilesNames, Context.SendOptions.AdditionalParameters.SettingsForSaving);

	Result = Context.Result;
	Result.Attachments.Clear();
	
	CommonClientServer.SupplementArray(Result.Attachments, Attachments);
	
	GenerateMessageToSendEnding(Result, Context.SendOptions);
	
EndProcedure

&AtServer
Function GetSignatureFilesAndPutToArchive(SigningResult, TransliterateFilesNames, SettingsForSaving)
		
	ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
	
	FilesReceiptParameters = ModuleDigitalSignatureInternal.FilesReceiptParameters();
	FilesReceiptParameters.TransliterateFilesNames = TransliterateFilesNames;
	Files = ModuleDigitalSignatureInternal.GetFilesFromSigningResult(
		SigningResult, FilesReceiptParameters, UUID);
	
	FilesInTempStorage = New Array;
	For Each File In Files Do
		StructureOfFileDetails = New Structure("AddressInTempStorage, Presentation, Id, Encoding");
		StructureOfFileDetails.AddressInTempStorage = File.Data;
		StructureOfFileDetails.Presentation = File.FileName;
		FilesInTempStorage.Add(StructureOfFileDetails);
	EndDo;
	
	FilesInTempStorage = PutFilesToArchive(FilesInTempStorage, SettingsForSaving);
	
	Return FilesInTempStorage;
	
EndFunction

&AtServer
Function PutFilesToArchive(DocsPrintForms, PassedSettings)
	
	Result = New Array;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		SettingsForSaving = ModulePrintManager.SettingsForSaving();
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
		
		ArchiveName = GetTempFileName("zip");
		ZipFileWriter = New ZipFileWriter(ArchiveName);
	
		For Each FileStructure In DocsPrintForms Do
				
			FileData = GetFromTempStorage(FileStructure.AddressInTempStorage);
			FullFileName = TempDirectoryName + FileStructure.Presentation;
			FullFileName = FileSystem.UniqueFileName(FullFileName);
			FileData.Write(FullFileName);
			ZipFileWriter.Add(FullFileName);
	
		EndDo;
			
		ZipFileWriter.Write();
		BinaryData = New BinaryData(ArchiveName);
		PathInTempStorage = PutToTempStorage(BinaryData, UUID);
		FileDetails = New Structure;
		File = New File(ArchiveName);
		FileDetails.Insert("Presentation", File.Name);
		FileDetails.Insert("AddressInTempStorage", PathInTempStorage);
		Result.Add(FileDetails);
		DeleteFiles(ArchiveName);
			
		DeleteFiles(TempDirectoryName);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion