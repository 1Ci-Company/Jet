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
Var ChoiceContext;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	InfobaseUpdate.CheckObjectProcessed(Object, ThisObject);
	
	Object.HTMLText = CommonClientServer.ReplaceProhibitedXMLChars(Object.HTMLText);
	
	If Object.Ref.IsEmpty() Then
		Reviewed = True;
		OnCreateAndOnReadAtServer();
		Interactions.SetSubjectByFillingData(Parameters, SubjectOf);
		ContactsChanged = True;
	EndIf;
	
	Interactions.FillChoiceListForReviewAfter(Items.ReviewAfter.ChoiceList);
	RestrictedExtensions = FilesOperationsInternal.DeniedExtensionsList();
	
	// Preparing interaction notifications.
	Interactions.PrepareNotifications(ThisObject,Parameters);
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesPage");
		AdditionalParameters.Insert("DeferredInitialization", True);
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.MessagesTemplates
	DeterminePossibilityToFillEmailByTemplate();
	// End StandardSubsystems.MessagesTemplates
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands       
	
	StatusOfSendingEmails = StatusOfSendingEmails();
	Items.WarningAboutUnsentEmails.Visible = StatusOfSendingEmails.SendingIsSuspended;
	Items.WarningAboutUnsentEmailsLabel.Title = StatusOfSendingEmails.WarningText;
	
	If Common.IsMobileClient() Then
		Items.SpecifyContacts.Title                  = NStr("en = 'Save emails to Address Book';");
		Items.SpecifyContacts.Representation                = ButtonRepresentation.Text;
		Items.LeftGroup1.ItemsAndTitlesAlign = ItemsAndTitlesAlignVariant.ItemsRightTitlesLeft;
		Items.Subject.TitleLocation                     = FormItemTitleLocation.Top;
		Items.AttachmentsGroup.ShowTitle          = True;
		Items.RecipientsGroup.ShowTitle        = True;
		Items.SaveAttachment.Representation               = ButtonRepresentation.Picture;
		Items.DeleteAttachment.Representation                 = ButtonRepresentation.Picture;
		Items.DeleteAttachment.LocationInCommandBar   = ButtonLocationInCommandBar.InCommandBar;
	EndIf
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	AvailabilityControl();

	Interval = ?(Items.WarningAboutUnsentEmails.Visible, 60, 600);
	AttachIdleHandler("CheckEmailsSendingStatus", Interval, True);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		If ModulePropertyManagerClient.ProcessNotifications(ThisObject, EventName, Parameter) Then
			UpdateAdditionalAttributesItems();
			ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
		EndIf;
	EndIf;
	// End StandardSubsystems.Properties
	
	InteractionsClient.DoProcessNotification(ThisObject, EventName, Parameter, Source);

	If EventName = "Write_AttachedFile" Then
		If TypeOf(Source) = Type("CatalogRef.OutgoingEmailAttachedFiles") Then
			
			AttachmentsCurrentData = Items.Attachments.CurrentData;
			If AttachmentsCurrentData = Undefined Then
				Return;
			EndIf;
			FileAttributes = FileAttributes(Source);
			FillPropertyValues(AttachmentsCurrentData, FileAttributes);
			AttachmentsCurrentData.SizePresentation = 
				InteractionsClientServer.GetFileSizeStringPresentation(FileAttributes.Size);
			AttachmentsCurrentData.FileName = ?(IsBlankString(FileAttributes.Extension),
			                                   FileAttributes.Description,
			                                   FileAttributes.Description + "." + FileAttributes.Extension);
		EndIf;
	EndIf;
	
	// StandardSubsystems.MessagesTemplates
	If EventName = "Write_MessageTemplates" Then
		DeterminePossibilityToFillEmailByTemplate();
	EndIf;
	// End StandardSubsystems.MessagesTemplates
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	Var RowStart1, RowEnd1, ColumnStart1, ColumnEnd1;
	Var BoldBeginning, BoldEnd;
	
	If Upper(ChoiceSource.FormName) = Upper("Document.OutgoingEmail.Form.ExternalObjectRefGeneration") Then
		
		If MessageFormat = PredefinedValue("Enum.EmailEditingMethods.NormalText") Then
			Items.EmailText.GetTextSelectionBounds(RowStart1, ColumnStart1, RowEnd1, ColumnEnd1);
			
			EmailText = TextInsertionInEmailResult(EmailText, RowStart1, ColumnStart1, ColumnEnd1, ValueSelected);
			
		Else
			
			Items.EmailTextFormattedDocument.GetTextSelectionBounds(BoldBeginning, BoldEnd);
			EmailTextFormattedDocument.Insert(BoldBeginning, ValueSelected);
			
		EndIf;
	
	ElsIf Upper(ChoiceSource.FormName) = Upper("DocumentJournal.Interactions.Form.EmailMessageParameters") Then
		
		If ValueSelected <> Undefined And Object.EmailStatus <> PredefinedValue("Enum.OutgoingEmailStatuses.Sent") Then
			
			Object.RequestDeliveryReceipt          = ValueSelected.RequestDeliveryReceipt;
			Object.RequestReadReceipt         = ValueSelected.RequestReadReceipt;
			Object.IncludeOriginalEmailBody = ValueSelected.IncludeOriginalEmailBody;
			Modified = True;
			
		EndIf;
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("CommonForm.AddressBook")
		Or Upper(ChoiceSource.FormName) = Upper("CommonForm.ContactsClarification") Then
		
		FillSelectedRecipientsAfterChoice(ValueSelected);
		
	Else
		
		InteractionsClient.ChoiceProcessingForm(ThisObject, ValueSelected, ChoiceSource, ChoiceContext);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	EnableUnsafeContent = False;
	
	Interactions.SetInteractionFormAttributesByRegisterData(ThisObject);
	OnCreateAndOnReadAtServer();
	
	Object.HTMLText = CommonClientServer.ReplaceProhibitedXMLChars(Object.HTMLText);
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = Common.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	ClearMessages();
	
	If Not IsSendingInProgress Then
		
		If CheckAddresseesListFilling1() Then
			Cancel = True;
		EndIf;
		
		If Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Draft") 
			Or Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Sent") Then
			InteractionsClient.CheckOfDeferredSendingAttributesFilling(Object, Cancel);
		EndIf;
		
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
#If Not WebClient Then
		For Each AttachmentsTableRow In Attachments Do
			If AttachmentsTableRow.Placement = 2 Then
				Try
					Data = New BinaryData(AttachmentsTableRow.FileNameOnComputer);
					AttachmentsTableRow.FileNameOnComputer = PutToTempStorage(Data, "");
					AttachmentsTableRow.Placement = 4;
				Except
					CommonClient.MessageToUser(ErrorProcessing.BriefErrorDescription(ErrorInfo()),,"Attachments",, Cancel);
				EndTry;
			EndIf;
		EndDo;
#EndIf
	
	Object.HasAttachments = (Attachments.Count() <> 0);
	
	FillTabularSectionsByRecipientsList();
	
	Object.EmailRecipientsList =
		InteractionsClientServer.GetAddressesListPresentation(Object.EmailRecipients, False);
	Object.CcRecipientsList =
		InteractionsClientServer.GetAddressesListPresentation(Object.CCRecipients, False);
	Object.BccRecipientsList = 
		InteractionsClientServer.GetAddressesListPresentation(Object.BccRecipients, False);
		
	For Each Attachment In Attachments Do
		
		If Attachment.Placement = 0 
			And Attachment.IsBeingEdited Then
			
			PutFileNotifyDescription = New NotifyDescription("AfterPutFile", ThisObject);
			FilesOperationsClient.PutAttachedFile(PutFileNotifyDescription, Attachment.Ref, UUID);
			
		EndIf;

	EndDo;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Not Exit
		And Modified
		And Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Draft") Then
		
		HasFilesToEdit = False;
		FilesToEditArray = New Array;
		
		For Each Attachment In Attachments Do
			
			If Attachment.IsBeingEdited Then
				HasFilesToEdit = True;
				FilesToEditArray.Add(Attachment.Ref);
			EndIf;
			
		EndDo;
		
		If HasFilesToEdit Then
			
			Cancel                = True;
			StandardProcessing = False;
			
			QueryText = NStr("en = 'The data has been changed. Save the changes?';");
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("FilesToEditArray", FilesToEditArray);
			NotificationAfterClosingPrompt = New NotifyDescription("AfterQuestionOnClose", ThisObject, AdditionalParameters);
			
			ShowQueryBox(NotificationAfterClosingPrompt, QueryText, QuestionDialogMode.YesNoCancel);
			
		EndIf;
		
	EndIf;
		
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteMode, PostingMode)
	
	HTMLDocumentOfCurrentEmailPrepared = False;
	
	// Preparing an HTML document from the formatted document content.
	If MessageFormat = Enums.EmailEditingMethods.HTML
		 And CurrentObject.EmailStatus = Enums.OutgoingEmailStatuses.Draft Then
		
		AttachmentsNamesToIDsMapsTable.Clear();
		
		AttachmentsStructure = New Structure;
		EmailTextFormattedDocument.GetHTML(CurrentObject.HTMLText, AttachmentsStructure);
		For Each Attachment In AttachmentsStructure Do
			
			NewRow = AttachmentsNamesToIDsMapsTable.Add();
			NewRow.FileName = Attachment.Key;
			NewRow.FileIDForHTML = New UUID;
			NewRow.Picture = Attachment.Value;
			
		EndDo;
		
		If AttachmentsNamesToIDsMapsTable.Count() > 0 Then
			
			HTMLDocument = Interactions.GetHTMLDocumentObjectFromHTMLText(CurrentObject.HTMLText);
			Interactions.ChangePicturesNamesToMailAttachmentsIDsInHTML(
			    HTMLDocument, AttachmentsNamesToIDsMapsTable.Unload());
			HTMLDocumentOfCurrentEmailPrepared = True;
			
		EndIf;
		
	Else
		
		CurrentObject.Text = EmailText;
		
	EndIf;
	
	If BaseEmailProcessingRequired() Then
		
		If MessageFormat = Enums.EmailEditingMethods.HTML Then
			
			CurrentObject.HTMLText = GenerateEmailTextIncludingBaseEmail(
				?(HTMLDocumentOfCurrentEmailPrepared,HTMLDocument,Undefined), CurrentObject);
				
			CurrentObject.Text = Interactions.GetPlainTextFromHTML(CurrentObject.HTMLText);
			
		Else
			
			CurrentObject.Text = GenerateEmailTextIncludingBaseEmail(Undefined, CurrentObject);
			
		EndIf;
		
	Else
		
		If MessageFormat = Enums.EmailEditingMethods.HTML Then
			
			If HTMLDocumentOfCurrentEmailPrepared Then
			
				CurrentObject.HTMLText = Interactions.GetHTMLTextFromHTMLDocumentObject(HTMLDocument);
				
			EndIf;
	
			CurrentObject.Text     = Interactions.GetPlainTextFromHTML(CurrentObject.HTMLText);
			
		EndIf;
		
	EndIf;
	
	If Object.EmailStatus = Enums.OutgoingEmailStatuses.Draft Then
		
		CurrentObject.EmailAttachments.Clear();
		RowIndex = 1;
		For Each Attachment In Attachments Do
			
			If Attachment.Placement = 5 And ValueIsFilled(Attachment.MailMessage) Then
				NewRow = CurrentObject.EmailAttachments.Add();
				NewRow.MailMessage                     = Attachment.MailMessage;
				NewRow.SequenceNumberInAttachments = RowIndex;
			EndIf;
			
			RowIndex =  RowIndex + 1;
			
		EndDo;
		
	EndIf;
	
	If IsSendingInProgress And Not SendMessagesImmediately Then
		
		CurrentObject.EmailStatus = Enums.OutgoingEmailStatuses.Outgoing;
		
	EndIf;
	
	If Object.EmailStatus <> CurrentEmailStatus 
		And CurrentObject.EmailStatus = Enums.OutgoingEmailStatuses.Outgoing 
		And Not GetFunctionalOption("SendEmailsInHTMLFormat")
		And (TypeOf(InteractionBasis) = Type("DocumentRef.IncomingEmail")
		Or TypeOf(InteractionBasis) = Type("DocumentRef.OutgoingEmail"))
		And IncomingEmailTextType = Enums.EmailTextTypes.HTML Then
		
		CurrentObject.HasAttachments = True;
		
	EndIf;
	
	CurrentObject.Size = EstimateEmailSize();
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	Interactions.BeforeWriteInteractionFromForm(ThisObject, CurrentObject, ContactsChanged);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Interactions.OnWriteInteractionFromForm(CurrentObject, ThisObject);
	
	If Object.EmailStatus <> Enums.OutgoingEmailStatuses.Draft Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	MailMessage = CurrentObject.Ref;
	
	Block = New DataLock;
	DataLockItem = Block.Add("Catalog.OutgoingEmailAttachedFiles");
	DataLockItem.SetValue("FileOwner", MailMessage);
	InformationRegisters.InteractionsFolderSubjects.BlockInteractionFoldersSubjects(Block, MailMessage);
	Block.Lock();
	
	// Adding to the list of deleted attachments previously saved pictures displayed in the body of a formatted document.
	FormattedDocumentPicturesAttachmentsTable = Interactions.GetEmailAttachmentsWithNonBlankIDs(MailMessage);
	For Each Attachment In FormattedDocumentPicturesAttachmentsTable Do
		DeletedAttachments.Add(Attachment.Ref);
	EndDo;
	
	// Delete removed attachments.
	For Each DeletedAttachment In DeletedAttachments Do
		ObjectAttachment = DeletedAttachment.Value.GetObject();
		ObjectAttachment.Delete();
	EndDo;
	DeletedAttachments.Clear();
	
	If MessageFormat = Enums.EmailEditingMethods.HTML Then
		
		For Each Attachment In AttachmentsNamesToIDsMapsTable Do
			
			BinaryPictureData = Attachment.Picture.GetBinaryData();
			PictureAddressInTempStorage = PutToTempStorage(BinaryPictureData, UUID);
			
			AttachmentParameters = New Structure;
			AttachmentParameters.Insert("FileName", "_" + StrReplace(Attachment.FileIDForHTML, "-", "_"));
			AttachmentParameters.Insert("Size", BinaryPictureData.Size());
			AttachmentParameters.Insert("EmailFileID", Attachment.FileIDForHTML);
			
			EmailManagement.WriteEmailAttachmentFromTempStorage(
				MailMessage, PictureAddressInTempStorage, AttachmentParameters);
			
		EndDo;
		
	EndIf;
	
	If BaseEmailProcessingRequired() Then
		
		BaseEmailAttachments = Interactions.GetEmailAttachmentsWithNonBlankIDs(Object.InteractionBasis);
		
		For Each Attachment In BaseEmailAttachments Do
			
			BinaryPictureData = FilesOperations.FileBinaryData(Attachment.Ref);
			PictureAddressInTempStorage = PutToTempStorage(BinaryPictureData, UUID);
			
			AttachmentParameters = New Structure;
			AttachmentParameters.Insert("FileName", Attachment.Description);
			AttachmentParameters.Insert("Size", Attachment.Size);
			AttachmentParameters.Insert("EmailFileID", Attachment.EmailFileID);
			
			EmailManagement.WriteEmailAttachmentFromTempStorage(
				MailMessage, PictureAddressInTempStorage, AttachmentParameters);
			
		EndDo;
		
	EndIf;
	
	For Each AttachmentsTableRow In Attachments Do
		
		Size = 0;
		FileName = AttachmentsTableRow.FileName;
		
		If AttachmentsTableRow.Placement = 4 Then
			// From a temporary storage.
			
			AttachmentParameters = New Structure;
			AttachmentParameters.Insert("FileName", FileName);
			AttachmentParameters.Insert("Size", Size);
			
			EmailManagement.WriteEmailAttachmentFromTempStorage(
				MailMessage, AttachmentsTableRow.FileNameOnComputer, AttachmentParameters);
			
		ElsIf AttachmentsTableRow.Placement = 3 Then
			// from a file on server
			
		ElsIf AttachmentsTableRow.Placement = 2 Then
			// From a local file.
			
			BinaryData = New BinaryData(AttachmentsTableRow.FileNameOnComputer);
			TempFileStorageAddress = PutToTempStorage(BinaryData);
			
			AttachmentParameters = New Structure;
			AttachmentParameters.Insert("FileName", FileName);
			AttachmentParameters.Insert("Size", Size);
			
			EmailManagement.WriteEmailAttachmentFromTempStorage(
				MailMessage, TempFileStorageAddress, AttachmentParameters);
			
		ElsIf AttachmentsTableRow.Placement = 1 Then
			
			EmailManagement.WriteEmailAttachmentByCopyOtherEmailAttachment(
				MailMessage, AttachmentsTableRow.Ref, UUID);
			
		ElsIf AttachmentsTableRow.Placement = 0 Then
			// Rewrite the attachment.
			
		EndIf;
		
		AttachmentsTableRow.Placement = 0;
		
	EndDo;
	
	If Object.EmailStatus <> CurrentEmailStatus Then
		AttachIncomingBaseEmailAsAttachmentIfNecessary(CurrentObject);
		Interactions.SetEmailFolder(MailMessage, 
			Interactions.DefineDefaultFolderForEmail(MailMessage, True));
		CurrentEmailStatus = Object.EmailStatus;
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
	
	FillAttachments();
	Interactions.SetEmailFormHeader(ThisObject);
	SetButtonTitleByDefault();
	
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)

	InteractionsClient.InteractionSubjectAfterWrite(ThisObject, Object,
		WriteParameters, "OutgoingEmail");
		
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DetailsPagesAdditionalOnCurrentPageChange(Item, CurrentPage)
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties")
		And CurrentPage.Name = "AdditionalAttributesPage"
		And Not PropertiesParameters.DeferredInitializationExecuted Then
		
		PropertiesExecuteDeferredInitialization();
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ReviewAfterChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	InteractionsClient.ProcessSelectionInReviewAfterField(
		ReviewAfter, ValueSelected, StandardProcessing, Modified);
	
EndProcedure

&AtClient
Procedure SenderPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If Object.Account <> ValueSelected Then
		
		AccountBeforeChange = Object.Account;
		Object.Account = ValueSelected;
		ListItem = Item.ChoiceList.FindByValue(ValueSelected);
		If ListItem <> Undefined Then
			StandardProcessing = False;
			Object.SenderPresentation = ListItem.Presentation;
		EndIf;
		Modified = True;
		AttachIdleHandler("AfterChangingSender", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EmailTextOnClick(Item, EventData, StandardProcessing)
	
	InteractionsClient.HTMLFieldOnClick(Item, EventData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure IncomingEmailTextOnClick(Item, EventData, StandardProcessing)
	
	InteractionsClient.HTMLFieldOnClick(Item, EventData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure SubjectOfStartChoice(Item, ChoiceData, StandardProcessing)
	
	InteractionsClient.SubjectOfStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure WarningAboutUnsafeContentURLProcessing(Item, FormattedStringURL, StandardProcessing)
	If FormattedStringURL = "EnableUnsafeContent" Then
		StandardProcessing = False;
		EnableUnsafeContent = True;
		ReadOutgoingHTMLEmailText();
	EndIf;
EndProcedure

&AtClient
Procedure WarningAboutUnsentEmailsLabelURLProcessing(Item, FormattedStringURL, StandardProcessing)

	InteractionsClient.URLProcessing(Item, FormattedStringURL, StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAttachments

&AtClient
Procedure AttachmentsSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenAttachmentExecute();
	
EndProcedure

&AtClient
Procedure AttachmentsDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	If Object.EmailStatus <> PredefinedValue("Enum.OutgoingEmailStatuses.Draft") Then
		DragParameters.Action = DragAction.Cancel;
	EndIf;
	
EndProcedure

&AtClient
Procedure AttachmentsDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	FilesArray = New Array;
	
	If TypeOf(DragParameters.Value) = Type("File") Then
		
		FilesArray.Add(DragParameters.Value);
		
	ElsIf TypeOf(DragParameters.Value) = Type("Array") Then
		
		If DragParameters.Value.Count() >= 1
			And TypeOf(DragParameters.Value[0]) = Type("File") Then
			
			For Each ReceivedFile1 In DragParameters.Value Do
				If TypeOf(ReceivedFile1) = Type("File") Then
					FilesArray.Add(ReceivedFile1);
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	For Each SelectedFile In FilesArray Do
		
		AdditionalParameters = New Structure("SelectedFile", SelectedFile);
		DescriptionOfTheAlert = New NotifyDescription("IsFileAfterCompletionCheck", ThisObject, AdditionalParameters);
		SelectedFile.BeginCheckingIsFile(DescriptionOfTheAlert);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersRecipientsList

&AtClient
Procedure RecipientsListPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	ClearMessages();
	
	If Items.RecipientsList.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Object.EmailStatus <> PredefinedValue("Enum.OutgoingEmailStatuses.Sent") Then
		
		SendingOption = Items.RecipientsList.CurrentData.SendingOption;

		If SendingOption  = "Whom" Then
			SelectionGroup = "Whom";
		ElsIf SendingOption  = "Copy" Then
			SelectionGroup = "Cc";
		ElsIf SendingOption = "HiddenCopy" Then
			SelectionGroup = "Hidden1";
		EndIf;
		
		EditRecipientsList(True, SelectionGroup);
	Else
		EditRecipientsList(False);
	EndIf;

EndProcedure

&AtClient
Procedure RecipientsListBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)
	
	If CancelEdit Then
		Return;
	EndIf;
	
	RowData = Item.CurrentData;
	If RowData = Undefined Then
		Return;
	EndIf;
	
	Address = "";
	PositionStart = StrFind(RowData.Presentation, "<");
	If PositionStart > 0 Then
		PositionEnd1 = StrFind(RowData.Presentation, ">", SearchDirection.FromBegin, PositionStart);
		If PositionEnd1 > 0 Then
			Address = Mid(RowData.Presentation, PositionStart + 1, PositionEnd1 - PositionStart - 1);
		EndIf;
	EndIf;
	
	If IsBlankString(Address) Then
		Address = RowData.Presentation;
	EndIf;
	
	If IsBlankString(Address) Then
		Return;
	EndIf;
	
	If StrFind(Address, "@") = 0 Or StrFind(Address, ".") = 0 Then
		AttachIdleHandler("ShowEmailAddressRequiredMessage", 0.1, True);
		Cancel = True;
		Return;
	EndIf;
	
	Item.CurrentData.Address = TrimAll(Address);

	Filter = New Structure("Address", Address);
	FoundRows = RecipientsList.FindRows(Filter);
	If FoundRows.Count() > 1 Then
		ErrorTextTemplate = NStr("en = 'You already added %1.';");
		CommonClient.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(ErrorTextTemplate, Address)
			,, "RecipientsList[" + Format(RecipientsList.IndexOf(FoundRows[0]), "NG=0") + "].Presentation");
		Cancel = True;
		Return;
	EndIf;
	
	ContactsChanged = True;

EndProcedure

&AtClient
Procedure RecipientsListPresentationAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	If Waiting = 0 Then
		Return;
	EndIf;
	
	If IsBlankString(Text) Then
		Return;
	EndIf;
	
	ChoiceData = FindContacts(Text);
	If ChoiceData.Count() > 0 Then
		StandardProcessing = False;
	Else
		ChoiceData = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure RecipientsListOnStartEdit(Item, NewRow, Copy)
	If NewRow Then
		Item.CurrentData.SendingOption = "Whom";
		Item.CurrentItem = Items.RecipientsListPresentation;
	EndIf;
EndProcedure

&AtClient
Procedure RecipientsListPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	StandardProcessing = False;
	
	If TypeOf(ValueSelected) = Type("Structure") Then
		CurrentData = Items.RecipientsList.CurrentData;
		CurrentData.Address         = ValueSelected.Address;
		CurrentData.Presentation = InteractionsClientServer.GetAddresseePresentation(ValueSelected.Presentation, ValueSelected.Address, "");
		CurrentData.Contact       = ValueSelected.Contact;
	EndIf;
	
EndProcedure

&AtClient
Procedure RecipientsListBeforeDeleteRow(Item, Cancel)
	If RecipientsList.Count() = 1 Then
		Cancel = True;
		RecipientsList[0].Presentation = "";
		RecipientsList[0].Address = "";
		RecipientsList[0].Contact = Undefined;
	EndIf;
EndProcedure

&AtClient
Procedure RecipientsListOnChange(Item)
	
	FillTabularSectionsByRecipientsList();
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "OutgoingEmail");
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SendForwardExecute(Command)
	
	ClearMessages();
	
	If Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Sent") Then
		ForwardMailExecute();
		Return;
	EndIf;
		
	If CheckAddresseesListFilling1() Then
		Return;
	EndIf;
	
	If RecipientsList.Count() = 0 Then
		
		CommonClient.MessageToUser(
			NStr("en = 'Specify at least one email recipient.';"),, "RecipientsList");
		Return;
		
	ElsIf (RecipientsList.Count() = 1 And IsBlankString(RecipientsList[0].Address)) Then
		
		CommonClient.MessageToUser(
			NStr("en = 'Specify at least one email recipient.';"),, "RecipientsList[0].Presentation");
		Return;
		
	EndIf;
	
	SendExecute();
	
EndProcedure

&AtClient
Procedure HTMLFormat(Command)
	
	If MessageFormat <> PredefinedValue("Enum.EmailEditingMethods.HTML") Then
		
		MessageFormat = PredefinedValue("Enum.EmailEditingMethods.HTML");
		MessageFormatOnChange();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FormatPlainText(Command)
	
	If MessageFormat <> PredefinedValue("Enum.EmailEditingMethods.NormalText") Then
		
		MessageFormat = PredefinedValue("Enum.EmailEditingMethods.NormalText");
		MessageFormatOnChange();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DisplayBaseEmailText(Command)
	
	Items.DisplayBaseEmailText.Check = Not Items.DisplayBaseEmailText.Check;
	Items.IncomingGroup.Visible = Items.DisplayBaseEmailText.Check;
	Object.DisplaySourceEmailBody = Not Object.DisplaySourceEmailBody;
	
EndProcedure

&AtClient
Procedure SpecifyContacts(Command)
	
	EditRecipientsList(False);
	
EndProcedure

&AtClient
Procedure EmailParameters(Command)
	
	TextIDs = New Array;
	TextIDs.Add("Id messages:  " + Object.MessageID);
	TextIDs.Add("Id basis1:  " + Object.BasisID);
	TextIDs.Add("IDs footings: " 
	                                   + GetBaseIDsPresentation(Object.BasisIDs));
	
	ParametersStructure1 = New Structure;
	ParametersStructure1.Insert("CreatedOn", Object.Date);
	ParametersStructure1.Insert("Sent", Object.PostingDate);
	ParametersStructure1.Insert("RequestDeliveryReceipt", Object.RequestDeliveryReceipt);
	ParametersStructure1.Insert("RequestReadReceipt", Object.RequestReadReceipt);
	ParametersStructure1.Insert("InternetTitles", StrConcat(TextIDs, Chars.LF));
	ParametersStructure1.Insert("MailMessage", Object.Ref);
	ParametersStructure1.Insert("EmailType", "OutgoingEmail");
	ParametersStructure1.Insert("Encoding", Object.Encoding);
	ParametersStructure1.Insert("InternalNumber", Object.Number);
	ParametersStructure1.Insert("IncludeOriginalEmailBody", Object.IncludeOriginalEmailBody);
	ParametersStructure1.Insert("Account", Object.Account);
	
	OpenForm("DocumentJournal.Interactions.Form.EmailMessageParameters", ParametersStructure1, ThisObject);
	
EndProcedure

&AtClient
Procedure InsertExternalRefToInfobaseObject(Command)
	
	OpenForm("Document.OutgoingEmail.Form.ExternalObjectRefGeneration",,ThisObject);
	
EndProcedure

&AtClient
Procedure ImportanceHigh(Command)
	
	Object.Importance = PredefinedValue("Enum.InteractionImportanceOptions.High");
	Items.SeverityGroup.Picture = PictureLib.ImportanceHigh;
	Items.SeverityGroup.ToolTip = NStr("en = 'High importance';");
	Items.DecorationImportance.Picture = PictureLib.ImportanceHigh;
	Items.DecorationImportance.ToolTip = NStr("en = 'High importance';");
	Modified = True;
	
EndProcedure

&AtClient
Procedure ImportanceNormal(Command)
	
	Object.Importance = PredefinedValue("Enum.InteractionImportanceOptions.Ordinary");
	Items.SeverityGroup.Picture = PictureLib.ImportanceNotSpecified;
	Items.SeverityGroup.ToolTip = NStr("en = 'Normal importance';");
	Items.DecorationImportance.Picture = PictureLib.ImportanceNotSpecified;
	Items.DecorationImportance.ToolTip = NStr("en = 'Normal importance';");
	Modified = True;
	
EndProcedure

&AtClient
Procedure ImportanceLow(Command)
	
	Object.Importance = PredefinedValue("Enum.InteractionImportanceOptions.Low");
	Items.SeverityGroup.Picture = PictureLib.ImportanceLow;
	Items.SeverityGroup.ToolTip = NStr("en = 'Low importance';");
	Items.DecorationImportance.Picture = PictureLib.ImportanceLow;
	Items.DecorationImportance.ToolTip = NStr("en = 'Low importance';");
	Modified = True;
	
EndProcedure

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, Var_URL = Undefined, StandardProcessing = Undefined)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

// StandardSubsystems.MessagesTemplates

&AtClient
Procedure GenerateFromTemplate(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		
		FillTabularSectionsByRecipientsList();
		
		ModuleMessageTemplatesClient = CommonClient.CommonModule("MessageTemplatesClient");
		Notification = New NotifyDescription("FillByTemplateAfterTemplateChoice", ThisObject);
		MessageSubject = ?(ValueIsFilled(SubjectOf), SubjectOf, "Shared");
		ModuleMessageTemplatesClient.PrepareMessageFromTemplate(MessageSubject, "MailMessage", Notification);
		
	EndIf
	
EndProcedure

// End StandardSubsystems.MessagesTemplates

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();
	
	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Subject.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.EmailStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = Enums.OutgoingEmailStatuses.Sent;

	Item.Appearance.SetParameterValue("ReadOnly", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AttachmentsContextMenuAttachmentProperties.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.EmailStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.OutgoingEmailStatuses.Draft;

	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	// Email send options list.
	Common.SetChoiceListConditionalAppearance(ThisObject, "RecipientsListSendingOption", "RecipientsList.SendingOption");

EndProcedure

&AtClient
Procedure UnderControlOnChange()
	
	AvailabilityControl();
	
	Reviewed = Not UnderControl;
	Modified = True;
	
EndProcedure

&AtClient
Function CheckAddresseesListFilling1()
	
	Cancel = False;
	AddressesByPresentations = New Map;
	AddressesByValues = New Map;
	ErrorTextTemplate = NStr("en = 'You already added %1.';");
	
	For Each AddressLine In RecipientsList Do
		
		Result = CommonClientServer.EmailsFromString(AddressLine.Presentation);
		For Each AddressStructure1 In Result Do
			
			If Not IsBlankString(AddressStructure1.ErrorDescription) Then
				Cancel = True;
				CommonClient.MessageToUser(AddressStructure1.ErrorDescription,, 
					"RecipientsList[" + Format(RecipientsList.IndexOf(AddressLine), "NG=0") + "].Presentation");
			EndIf;
			
			If AddressesByPresentations.Get(AddressStructure1.Address) <> Undefined Then
				Cancel = True;
				CommonClient.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(ErrorTextTemplate,
					AddressStructure1.Address),, "RecipientsList[" + Format(RecipientsList.IndexOf(AddressLine), "NG=0") + "].Presentation");
			Else
				AddressesByPresentations.Insert(AddressStructure1.Address, AddressLine.GetID());
			EndIf;
			
		EndDo;
		
		If Not Cancel Then
			Result = CommonClientServer.EmailsFromString(AddressLine.Address);
			For Each AddressStructure1 In Result Do
				
				If Not IsBlankString(AddressStructure1.ErrorDescription) Then
					Cancel = True;
					CommonClient.MessageToUser(AddressStructure1.ErrorDescription,, 
						"RecipientsList[" + Format(RecipientsList.IndexOf(AddressLine), "NG=0") + "].Presentation");
				EndIf;
				
				If AddressesByValues.Get(AddressStructure1.Address) <> Undefined Then
					Cancel = True;
					CommonClient.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(ErrorTextTemplate,
						AddressStructure1.Address),, "RecipientsList[" + Format(RecipientsList.IndexOf(AddressLine), "NG=0") + "].Presentation");
				Else
					AddressesByValues.Insert(AddressStructure1.Address, AddressLine.GetID());
				EndIf;
			
			EndDo;
		EndIf;
		
	EndDo;
	
	If Not Cancel Then
		
		For Each AddressByValue In AddressesByValues Do
			If AddressesByPresentations[AddressByValue.Key] <> Undefined
				And AddressesByPresentations[AddressByValue.Key] <> AddressByValue.Value Then
					Cancel = True;
					IndexOf = RecipientsList.IndexOf(RecipientsList.FindByID(AddressByValue.Value));
					CommonClient.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(ErrorTextTemplate,
						AddressByValue.Key),, "RecipientsList[" + Format(IndexOf, "NG=0") + "].Presentation");
			EndIf;
		EndDo;
	EndIf;
	
	Return Cancel;
	
EndFunction

&AtServer
Function BaseEmailProcessingRequired()

	Return IsSendingInProgress And Object.IncludeOriginalEmailBody And GetFunctionalOption("SendEmailsInHTMLFormat") 
	        And (Not Object.InteractionBasis = Undefined) And (Not Object.InteractionBasis.IsEmpty()) 
	        And Object.EmailStatus = Enums.OutgoingEmailStatuses.Draft;

EndFunction

&AtServer
Procedure DoDisplayImportance()

	If Object.Importance = Enums.InteractionImportanceOptions.High Then
		Items.SeverityGroup.Picture = PictureLib.ImportanceHigh;
		Items.SeverityGroup.ToolTip = NStr("en = 'High importance';");
		Items.DecorationImportance.Picture = PictureLib.ImportanceHigh;
		Items.DecorationImportance.ToolTip = NStr("en = 'High importance';");
		
	ElsIf Object.Importance = Enums.InteractionImportanceOptions.Low Then
		Items.SeverityGroup.Picture = PictureLib.ImportanceLow;
		Items.SeverityGroup.ToolTip = NStr("en = 'Low importance';");
		Items.DecorationImportance.Picture = PictureLib.ImportanceLow;
		Items.DecorationImportance.ToolTip = NStr("en = 'Low importance';");
		
	Else
		Items.SeverityGroup.Picture = PictureLib.ImportanceNotSpecified;
		Items.SeverityGroup.ToolTip = NStr("en = 'Normal importance';");
		Items.DecorationImportance.Picture = PictureLib.ImportanceNotSpecified;
		Items.DecorationImportance.ToolTip = NStr("en = 'Normal importance';");
	EndIf;

EndProcedure

/////////////////////////////////////////////////////////////////////////////////
//  Managing form item availability.

&AtClient
Procedure AvailabilityControl()

	Items.ReviewAfter.Enabled = UnderControl;
	
	If Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Outgoing") 
		And (Not FileInfobase
		Or (Object.DateToSendEmail <> Date(1,1,1) And Object.DateToSendEmail > CommonClient.SessionDate())
		Or (Object.EmailSendingRelevanceDate <> Date(1,1,1) And Object.EmailSendingRelevanceDate < CommonClient.SessionDate())) Then
		Items.Send.Visible = False;
	Else
		Items.Send.Visible = True;
	EndIf;
	Items.FormWriteAndClose.Visible = Not Items.Send.Visible;
	
	Items.SendingDateRelevanceGroup.Enabled = (Object.EmailStatus <> PredefinedValue("Enum.OutgoingEmailStatuses.Sent")); 

EndProcedure

&AtServer
Procedure DefineItemsVisibilityAvailabilityDependingOnEmailStatus()

	If Object.EmailStatus <> Enums.OutgoingEmailStatuses.Sent Then
		EmailManagement.GetAvailableAccountsForSending(
			Items.SenderPresentation.ChoiceList,AvailableAccountsForSending);
			
		If Object.Account.IsEmpty()
			And AvailableAccountsForSending.Count() > 0
			And Object.Ref.IsEmpty() Then
			
			Object.Account = AvailableAccountsForSending[0].Account;
			
		EndIf;
		
		ListItem = Items.SenderPresentation.ChoiceList.FindByValue(Object.Account);
		If ListItem <> Undefined Then
			Object.SenderPresentation = ListItem.Presentation;
		EndIf;
		
	Else
		
		Items.SenderPresentation.ReadOnly             = True;
		Items.RecipientsListSendingOption.ReadOnly     = True;
		Items.RecipientsListPresentation.TextEdit = False;
		Items.RecipientsList.ReadOnly                    = True;
		Items.SeverityGroup.Visible                            = False;
		Items.DecorationImportance.Visible = Object.Importance <> Enums.InteractionImportanceOptions.Ordinary;
		
	EndIf;
	
	If Object.EmailStatus <> Enums.OutgoingEmailStatuses.Draft Then
		
		If Attachments.Count() > 0 Then
			Items.AddAttachment.Enabled = False;
			Items.DeleteAttachment.Enabled  = False;
			Items.AddEmail.Enabled   = False;
		Else
			Items.Attachments.Visible = False;
		EndIf;
		
		If Object.TextType = Enums.EmailTextTypes.HTML Then
			EmailText = Object.HTMLText;
			EmailText = Interactions.ProcessHTMLText(Object.Ref, False, False);
			Items.EmailText.Type = FormFieldType.HTMLDocumentField;
			Items.EmailText.ReadOnly = False;
		Else
			EmailText = Object.Text;
			Items.EmailText.Type = FormFieldType.TextDocumentField;
			Items.EmailText.ReadOnly = True;
		EndIf;
		
		If Object.EmailStatus = Enums.OutgoingEmailStatuses.Outgoing 
			And (Not FileInfobase 
			Or (Object.DateToSendEmail <> Date(1,1,1) And Object.DateToSendEmail > CurrentSessionDate())
			Or (Object.EmailSendingRelevanceDate <> Date(1,1,1) And Object.EmailSendingRelevanceDate < CurrentSessionDate())) Then
			
			Items.Send.Enabled = False;
			
		EndIf;
		
	Else
		
		DetermineEmailEditMethod();
		
	EndIf;

EndProcedure

#Region AttachmentsOperations

&AtServer
Procedure AddEmailAttachment(MailMessage)
	
	If Attachments.FindRows(New Structure("MailMessage", MailMessage)).Count() > 0 Then
		Return;
	EndIf;
	
	AttributesString = "Size, Subject";
	If TypeOf(MailMessage) = Type("DocumentRef.IncomingEmail") Then
		AttributesString =  AttributesString + ", DateReceived";
	ElsIf TypeOf(MailMessage) = Type("DocumentRef.OutgoingEmail") Then
		AttributesString =  AttributesString + ", Date, PostingDate";
	Else
		Return;
	EndIf;
	
	EmailAttributes = Common.ObjectAttributesValues(MailMessage, AttributesString);
	
	If TypeOf(MailMessage) = Type("DocumentRef.IncomingEmail") Then
		EmailDate = EmailAttributes.DateReceived;
	Else
		EmailDate = ?(ValueIsFilled(EmailAttributes.PostingDate), EmailAttributes.PostingDate, EmailAttributes.Date);
	EndIf;

	EmailPresentation = Interactions.EmailPresentation(EmailAttributes.Subject, EmailDate);
	
	NewRow = Attachments.Add();
	NewRow.MailMessage               = MailMessage;
	NewRow.FileName             = EmailPresentation;
	NewRow.PictureIndex       = FilesOperationsInternalClientServer.IndexOfFileIcon("eml");
	NewRow.FileNameOnComputer = "";
	NewRow.SignedWithDS           = False;
	NewRow.Size               = EmailAttributes.Size;
	NewRow.SizePresentation  = InteractionsClientServer.GetFileSizeStringPresentation(NewRow.Size);
	NewRow.Placement         = 5;

EndProcedure

&AtServer
Procedure AddEmailsAttachments()

	AttachmentEmailsTable = Interactions.DataStoredInAttachmentsEmailsDatabase(Object.Ref);
	
	For Each AttachmentEmail In AttachmentEmailsTable Do
			
		EmailPresentation = Interactions.EmailPresentation(AttachmentEmail.Subject, AttachmentEmail.Date);
		
		NewRow = Attachments.Add();
		NewRow.MailMessage               = AttachmentEmail.MailMessage;
		NewRow.FileName             = EmailPresentation;
		NewRow.PictureIndex       = FilesOperationsInternalClientServer.IndexOfFileIcon("eml");
		NewRow.FileNameOnComputer = "";
		NewRow.SignedWithDS           = False;
		NewRow.Size               = AttachmentEmail.Size;
		NewRow.SizePresentation  = InteractionsClientServer.GetFileSizeStringPresentation(NewRow.Size);
		NewRow.Placement         = 5;
		
	EndDo;

EndProcedure

&AtClient
Procedure AddEmail(Command)
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("ChoiceMode", True);
	OpeningParameters.Insert("CloseOnChoice", True);
	OpeningParameters.Insert("OnlyEmail", True);
	NotifyDescription = New NotifyDescription("AddEmailCompletion", ThisObject);
	OpenForm("DocumentJournal.Interactions.ListForm",
	             OpeningParameters,
	             ThisObject,,,,
	             NotifyDescription,
	             FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AddEmailCompletion(Result, Var_Parameters) Export
	
	If InteractionsClient.IsEmail(Result) Then
		AddEmailAttachment(Result);
		Modified = True;
	EndIf;
	
EndProcedure 

&AtClient
Procedure AttachmentsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	AddAttachmentExecute();

EndProcedure

&AtClient
Procedure AttachmentsBeforeDeleteRow(Item, Cancel)
	
	If Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Draft") Then
		DeleteAttachmentExecute();
	EndIf;
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure AttachmentsOnActivateCell(Item)
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Items.AttachmentsContextMenuAttachmentProperties.Enabled = (CurrentData.Placement <> 5);
	Items.AttachmentProperties.Enabled                        = (CurrentData.Placement <> 5);
	
EndProcedure

&AtClient
Procedure AddAttachmentExecute()
	
	DescriptionOfTheAlert = New NotifyDescription("FileSelectionDialogAfterChoice", ThisObject);
	FileSystemClient.ImportFiles(DescriptionOfTheAlert);
	
EndProcedure

&AtClient
Procedure DeleteAttachmentExecute()

	AddAttachmentToDeletedAttachmentsList();
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData <> Undefined Then
		IndexOf = Attachments.IndexOf(CurrentData);
		Attachments.Delete(IndexOf);
	EndIf;
	
EndProcedure

&AtClient
Procedure AddAttachmentToDeletedAttachmentsList()

	CurrentData = Items.Attachments.CurrentData;
	If (CurrentData <> Undefined) And (CurrentData.Placement = 0) Then
		DeletedAttachments.Add(CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenAttachmentExecute()
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If (CurrentData.Placement = 0) Or (CurrentData.Placement = 1) Then
		
		If InteractionsClientServer.IsFileEmail(CurrentData.FileName) Then
			InteractionsClient.OpenAttachmentEmail(CurrentData.Ref, EmailAttachmentParameters(), ThisObject);
		Else
			ForEditing = Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Draft");
			EmailManagementClient.OpenAttachment(CurrentData.Ref, ThisObject, ForEditing);
			If ForEditing Then
				CurrentData.IsBeingEdited = True;
				Modified = True;
			EndIf;
		EndIf;
		
	ElsIf CurrentData.Placement = 2 Then
		
		PathToFile = CurrentData.FileNameOnComputer;
		If InteractionsClientServer.IsFileEmail(CurrentData.FileName) Then
			InteractionsClient.OpenAttachmentEmail(CurrentData.MailMessage, EmailAttachmentParameters(), ThisObject);
		Else
			FileSystemClient.OpenFile(PathToFile);
		EndIf;
		
	ElsIf CurrentData.Placement = 4 Then
		
		FileSystemClient.OpenFile(CurrentData.FileNameOnComputer,, CurrentData.FileName);
		
	ElsIf CurrentData.Placement = 5 Then
		
		AttachmentParameters = InteractionsClient.EmailAttachmentParameters();
		AttachmentParameters.BaseEmailDate = ?(ValueIsFilled(Object.PostingDate), Object.PostingDate , Object.Date);
		AttachmentParameters.EmailBasis     = Object.Ref;
		AttachmentParameters.BaseEmailSubject = Object.Subject;
		InteractionsClient.OpenAttachmentEmail(CurrentData.MailMessage, AttachmentParameters, ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveAttachment(Command)
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
		
	If Not ValueIsFilled(CurrentData.Ref) Then
		Return;
	EndIf;
		
	FileData = FilesOperationsClient.FileData(CurrentData.Ref, UUID);
	FilesOperationsClient.SaveFileAs(FileData);
	
EndProcedure

&AtServer
Procedure FillAttachments(PassedParameters = Undefined)
	
	If Object.Ref.IsEmpty() And PassedParameters <> Undefined Then
		If PassedParameters.Property("Basis") 
			And TypeOf(PassedParameters.Basis) = Type("Structure") 
			And PassedParameters.Basis.Property("Command") Then 
			
			If  PassedParameters.Basis.Command = "ForwardMail" Then
			
				AttachmentTab = EmailManagement.GetEmailAttachments(PassedParameters.Basis.Basis, True);
				For Each AttachmentsTableRow In AttachmentTab Do
					If IsBlankString(AttachmentsTableRow.EmailFileID) Then
						NewRow = Attachments.Add();
						NewRow.Ref              = AttachmentsTableRow.Ref;
						NewRow.FileName            = AttachmentsTableRow.FileName;
						NewRow.PictureIndex      = AttachmentsTableRow.PictureIndex;
						NewRow.Size              = AttachmentsTableRow.Size;
						NewRow.SizePresentation = AttachmentsTableRow.SizePresentation;
						NewRow.Placement        = 1;
					EndIf;
				EndDo;
				
				DataStoredInAttachmentsEmailsDatabase = Interactions.DataStoredInAttachmentsEmailsDatabase(PassedParameters.Basis.Basis);
				For Each TableRow In DataStoredInAttachmentsEmailsDatabase Do
					AddEmailAttachment(TableRow.MailMessage);
				EndDo;
				
			ElsIf PassedParameters.Basis.Command = "ForwardAsAttachment"
				And Parameters.Basis.Property("Basis")  Then

				AddEmailAttachment(Parameters.Basis.Basis);
				
			EndIf;
			
		EndIf;
	Else
		
		Attachments.Clear();
		AttachmentTab = EmailManagement.GetEmailAttachments(Object.Ref, True);
		For Each AttachmentsTableRow In AttachmentTab Do
			If IsBlankString(AttachmentsTableRow.EmailFileID) Then
				NewRow = Attachments.Add();
				NewRow.Ref              = AttachmentsTableRow.Ref;
				NewRow.FileName            = AttachmentsTableRow.FileName;
				NewRow.PictureIndex      = AttachmentsTableRow.PictureIndex;
				NewRow.Size              = AttachmentsTableRow.Size;
				NewRow.SizePresentation = AttachmentsTableRow.SizePresentation;
				NewRow.SignedWithDS          = AttachmentsTableRow.SignedWithDS;
				NewRow.Placement        = 0;
			EndIf;
		EndDo;
		
		AddEmailsAttachments();
		
	EndIf;
	
	Attachments.Sort("FileName");
	
EndProcedure

&AtServer
Procedure AttachIncomingBaseEmailAsAttachmentIfNecessary(CurrentObject)
	
	If CurrentObject.EmailStatus = Enums.OutgoingEmailStatuses.Outgoing 
		And Not GetFunctionalOption("SendEmailsInHTMLFormat") 
		And (TypeOf(InteractionBasis) = Type("DocumentRef.IncomingEmail") 
		Or TypeOf(InteractionBasis) = Type("DocumentRef.OutgoingEmail")) 
		And IncomingEmailTextType = Enums.EmailTextTypes.HTML Then
		
		If TypeOf(InteractionBasis) = Type("DocumentRef.IncomingEmail") Then
			HTMLTextIncomingEmail = Interactions.GenerateHTMLTextForIncomingEmail(InteractionBasis, True, True, False);
		Else
			HTMLTextIncomingEmail = Interactions.GenerateHTMLTextForOutgoingEmail(InteractionBasis, True, True, False);
		EndIf;
		
		FileName = GetTempFileName("html");
		FileSourceMessage = New TextWriter(FileName,TextEncoding.UTF16);
		FileSourceMessage.Write(HTMLTextIncomingEmail);
		FileSourceMessage.Close();
		BinaryData       = New BinaryData(FileName);
		FileAddressInStorage = PutToTempStorage(BinaryData);
		
		FileOnHardDrive = New File(FileName);
		If FileOnHardDrive.Exists() Then
			DeleteFiles(FileName);
		EndIf;
		
		FileParameters = FilesOperations.FileAddingOptions();
		FileParameters.FilesOwner = CurrentObject.Ref;
		FileParameters.BaseName = NStr("en = 'Forwarded message';");
		FileParameters.ExtensionWithoutPoint = "html";
		FileParameters.ModificationTimeUniversal = Undefined;
		
		FilesOperations.AppendFile(FileParameters, FileAddressInStorage);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AttachmentProperties(Command)
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentIndexInCollection = Attachments.IndexOf(CurrentData);
	
	If CurrentData.Ref = Undefined Then
		AdditionalParameters = New Structure("CurrentIndexInCollection", CurrentIndexInCollection);
		OnCloseNotifyHandler = New NotifyDescription("QuestionOfFileRecordAfterClose", ThisObject, AdditionalParameters);
		QueryText = NStr("en = 'You can access the file''s properties after you save the file. Save it now?';");
		ShowQueryBox(OnCloseNotifyHandler, QueryText, QuestionDialogMode.YesNo);
	Else
		OpenAttachmentProperties(CurrentIndexInCollection);
	EndIf;
	
EndProcedure

&AtClient
Procedure QuestionOfFileRecordAfterClose(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		
		CurrentData = Attachments.Get(AdditionalParameters.CurrentIndexInCollection);
		If CurrentData <> Undefined Then
			FileName = CurrentData.FileName;
		Else
			Return;
		EndIf;
		Write();
		
		SearchParameters = New Structure;
		SearchParameters.Insert("FileName", FileName);
		
		FoundRows = Attachments.FindRows(SearchParameters);
		
		If FoundRows.Count() > 0 Then
			RowID = Attachments.IndexOf(FoundRows[0]);
			Items.Attachments.CurrentRow = RowID;
			AdditionalParameters.CurrentIndexInCollection = RowID;
		Else
			Return;
		EndIf;
		
	Else
		Return;
	EndIf;
	
	OpenAttachmentProperties(AdditionalParameters.CurrentIndexInCollection);
	
EndProcedure

// Occurs when the file size is received
// 
// Parameters:
//  Size - Number - file size.
//  AdditionalParameters - Structure:
//    * AttachmentsTableRow - ValueTableRow:
//      ** Size - Number - file size.
//
&AtClient
Procedure ReceivingSizeCompletion(Size, AdditionalParameters) Export

	AttachmentsTableRow  = AdditionalParameters.AttachmentsTableRow;
	AttachmentsTableRow.Size = Size;
	AttachmentsTableRow.SizePresentation = InteractionsClientServer.GetFileSizeStringPresentation(Size); 

EndProcedure

&AtClient
Procedure FileSelectionDialogAfterChoice(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	For Each SelectedFile In SelectedFiles Do
		NewRow = Attachments.Add();
		
#If WebClient Then
			NewRow.Placement = 4;
			NewRow.FileNameOnComputer = PutToTempStorage(GetFromTempStorage(SelectedFile.Location), 
			                                                                 UUID);
#Else
			NewRow.Placement = 2;
			NewRow.FileNameOnComputer = SelectedFile.FullName;
#EndIf
		
		FileName = FileNameWithoutDirectory(SelectedFile.FullName);
		NewRow.FileName = FileName;
		
		Extension                      = CommonClientServer.GetFileNameExtension(FileName);
		NewRow.PictureIndex      = FilesOperationsInternalClientServer.IndexOfFileIcon(Extension);
		AdditionalParameters = New Structure("AttachmentsTableRow", NewRow);
		File = New File(SelectedFile.FullName);
		File.BeginGettingSize(New NotifyDescription("ReceivingSizeCompletion", ThisObject, AdditionalParameters));
	EndDo;
	
	If SelectedFiles.Count() > 0 Then
		Items.Attachments.CurrentRow = NewRow.GetID();
	EndIf;
	
EndProcedure

&AtClient
Procedure IsFileAfterCompletionCheck(IsFile, AdditionalParameters) Export

	If Not IsFile Then
		Return;
	EndIf;
	
	FullName = AdditionalParameters.SelectedFile.FullName;
	
	NewRow = Attachments.Add();
	NewRow.Placement = 2;
	NewRow.FileNameOnComputer = FullName;
	
	FileName = FileNameWithoutDirectory(FullName);
	NewRow.FileName = FileName;
	
	Extension                      = CommonClientServer.GetFileNameExtension(FileName);
	NewRow.PictureIndex      = FilesOperationsInternalClientServer.IndexOfFileIcon(Extension);
	AdditionalParameters         = New Structure("AttachmentsTableRow", NewRow);
	File = New File(FullName);
	File.BeginGettingSize(New NotifyDescription("ReceivingSizeCompletion", ThisObject, AdditionalParameters));

EndProcedure

&AtClient
Function FileNameWithoutDirectory(Val FullFileName)
	
	FileName = FullFileName;
	While True Do
		
		Position = Max(StrFind(FileName, "\"), StrFind(FileName, "/"));
		If Position = 0 Then
			Return FileName;
		EndIf;
		
		FileName = Mid(FileName, Position + 1);
		
	EndDo;
	Return FileName;
	
EndFunction

#EndRegion

#Region EmailBodyGeneration

&AtServer
Function GenerateEmailTextIncludingBaseEmail(HTMLDocumentToEdit, CurrentObject)
	
	Selection = Interactions.GetBaseEmailData(Object.InteractionBasis);
	If MessageFormat = Enums.EmailEditingMethods.NormalText Then
		Return GenerateOutgoingMessagePlainText(Selection, CurrentObject);
	Else
		Return GenerateOutgoingMessageHTML(Selection, HTMLDocumentToEdit, CurrentObject);
	EndIf;
	
EndFunction

&AtServer
Function GenerateOutgoingMessageHTML(Selection, HTMLDocumentToEdit, CurrentObject)
	
	If Selection.TextType = Enums.EmailTextTypes.PlainText Then
		HTMLDocument = Interactions.GetHTMLDocumentFromPlainText(Selection.Text);
	Else
		HTMLDocument = Interactions.GetHTMLDocumentObjectFromHTMLText(Selection.HTMLText);
	EndIf;
	
	EmailBodyItem = HTMLDocument.Body;
	If EmailBodyItem = Undefined Then
		If HTMLDocumentToEdit = Undefined Then
			Return CurrentObject.HTMLText;
		Else
			Return Interactions.GetHTMLTextFromHTMLDocumentObject(HTMLDocumentToEdit);
		EndIf
	EndIf;
	
	If HTMLDocumentToEdit = Undefined Then
		HTMLDocumentToEdit = Interactions.GetHTMLDocumentObjectFromHTMLText(CurrentObject.HTMLText);
	EndIf;
	
	HTMLDocument = Interactions.MergeEmails(HTMLDocumentToEdit, HTMLDocument, Selection);
	Return Interactions.GetHTMLTextFromHTMLDocumentObject(HTMLDocument);
	
EndFunction

&AtServer
Function GenerateOutgoingMessagePlainText(SelectionIncomingEmailData, CurrentObject)

	StringHeader1 = NStr("en = '-----Forwarded message-----';");
	
	StringHeader1 = StringHeader1 + Chars.LF+ NStr("en = 'From';") + ": "+ SelectionIncomingEmailData.SenderPresentation
		          + ?(SelectionIncomingEmailData.MetadataObjectName = "IncomingEmail",
		          "[" + SelectionIncomingEmailData.SenderAddress +"]",
		          "");
		
	StringHeader1 = StringHeader1 + Chars.LF+ NStr("en = 'Sent on';") + ": " 
	              + Format(SelectionIncomingEmailData.Date,"DLF=DT");
	
	StringHeader1 = StringHeader1 + Chars.LF+ NStr("en = 'To';") + ": " 
	    + Interactions.GetIncomingEmailRecipientsPresentations(SelectionIncomingEmailData.EmailRecipients.Unload());
		
	CCRecipientsTable = SelectionIncomingEmailData.CCRecipients.Unload();
	
	If CCRecipientsTable.Count() > 0 Then
		StringHeader1 = StringHeader1 + Chars.LF+ NStr("en = 'Cc';") + ": "
		+ Interactions.GetIncomingEmailRecipientsPresentations(CCRecipientsTable);
	EndIf;
	
	StringHeader1 = StringHeader1 + Chars.LF+ NStr("en = 'Subject';") + ": " + SelectionIncomingEmailData.Subject;
	
	// Transforming an HTML text to a plain text if necessary.
	If SelectionIncomingEmailData.TextType <> Enums.EmailTextTypes.PlainText Then
		
		IncomingEmailText =  Interactions.GetPlainTextFromHTML(SelectionIncomingEmailData.HTMLText);
		
	Else
		
		IncomingEmailText = SelectionIncomingEmailData.Text
		
	EndIf;
	
	Return CurrentObject.Text + Chars.LF + Chars.LF + StringHeader1 + Chars.LF + Chars.LF + IncomingEmailText;

EndFunction

#Region Other

&AtServer
Procedure DetermineEmailEditMethod()

	If Object.TextType.IsEmpty() Then
		
		MessageFormat = Interactions.DefaultMessageFormat(Users.CurrentUser());
		
		// If the text type is not specified, the format might mismatch. Therefore:
		// - If plain text is filled and HTML is not filled, set the format to plain text.
		// - If HTML is filled and plain text is not, set the format to HTML.
		If MessageFormat = Enums.EmailEditingMethods.NormalText 
			And TrimAll(Object.Text) = "" And TrimAll(Object.HTMLText) <> "" Then
			MessageFormat = Enums.EmailEditingMethods.HTML;
		ElsIf MessageFormat = Enums.EmailEditingMethods.HTML
			And TrimAll(Object.Text) <> "" And TrimAll(Object.HTMLText) = "" Then
			MessageFormat = Enums.EmailEditingMethods.NormalText;
		EndIf;
		
	Else
		If Object.TextType = Enums.EmailTextTypes.PlainText Then
			MessageFormat = Enums.EmailEditingMethods.NormalText;
		Else
			MessageFormat = Enums.EmailEditingMethods.HTML;
		EndIf;
		
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		
		If Not GetFunctionalOption("SendEmailsInHTMLFormat") 
			And MessageFormat = Enums.EmailEditingMethods.HTML Then
			MessageFormat = Enums.EmailEditingMethods.NormalText;
		EndIf;
		
		UserUserSessionParameters =
			Interactions.GetUserParametersForOutgoingEmail(
			Object.Account,
			MessageFormat,
			?(Object.InteractionBasis = Undefined, True, False));
		
		Object.RequestDeliveryReceipt            = UserUserSessionParameters.RequestDeliveryReceipt;
		Object.RequestReadReceipt           = UserUserSessionParameters.RequestReadReceipt;
		Object.IncludeOriginalEmailBody   = UserUserSessionParameters.IncludeOriginalEmailBody;
		Object.DisplaySourceEmailBody = UserUserSessionParameters.DisplaySourceEmailBody;
		
	EndIf;
	
	If MessageFormat = Enums.EmailEditingMethods.HTML Then
		
		Items.EmailTextPages.CurrentPage = Items.FormattedDocumentPage;
		Object.TextType = Enums.EmailTextTypes.HTML;
		If Not Object.Ref.IsEmpty() Or ValueIsFilled(Object.HTMLText) Then
			
			If IsTempStorageURL(Object.HTMLText) Then
				
				HTMLEmailBody   = GetFromTempStorage(Object.HTMLText);
				Object.HTMLText = HTMLEmailBody.HTMLText;
				EmailTextFormattedDocument.SetHTML(HTMLEmailBody.HTMLText, HTMLEmailBody.AttachmentsStructure);
				Object.TextType = Enums.EmailTextTypes.HTMLWithPictures;
				Object.Text     = EmailTextFormattedDocument.GetText();
				
			Else
				
				AttachmentsStructure  = New Structure;
				HTMLText = "";
				EmailTextFormattedDocument.GetHTML(HTMLText, AttachmentsStructure);
				
				// If "EmailTextFormattedDocument" was filled using the passed parameters when composing the email message,
				// do not read the HTML text from the message.
				HTMLTextToCheck = EmailTextFormattedDocument.GetText();
				If IsBlankString(HTMLTextToCheck) And ValueIsFilled(Object.HTMLText) Then
					Object.HTMLText = Interactions.ProcessHTMLTextForFormattedDocument(
						Object.Ref, Object.HTMLText, AttachmentsStructure);
					EmailTextFormattedDocument.SetHTML(Object.HTMLText, AttachmentsStructure);
				EndIf;
			
			EndIf;
			
		EndIf;
		
		If Object.Ref.IsEmpty() And UserUserSessionParameters.Signature <> Undefined Then
			AddFormattedDocumentToFormattedDocument(EmailTextFormattedDocument, UserUserSessionParameters.Signature);
		EndIf;
		
	Else
		
		Items.EmailTextPages.CurrentPage = Items.PlainTextPage;
		Items.EmailText.Type = FormFieldType.TextDocumentField;
		Object.TextType = Enums.EmailTextTypes.PlainText;
		EmailText = Object.Text;
		If Object.Ref.IsEmpty() And UserUserSessionParameters.Signature <> Undefined Then
			EmailText = EmailText + UserUserSessionParameters.Signature;
		EndIf;
		Object.Encoding = "UTF-8";
		
	EndIf;
	
	Items.MessageFormat.Visible = True;
	Items.MessageFormat.Title = MessageFormat;
	
EndProcedure

&AtServer
Procedure ProcessPassedParameters(PassedParameters)
	
	If Not Object.Ref.IsEmpty() Then
		Return;
	EndIf;
	
	SetTheMessageTextAccordingToThePassedParameters(PassedParameters);
	
	If PassedParameters.Property("Attachments") And PassedParameters.Attachments <> Undefined Then
		
		If TypeOf(PassedParameters.Attachments) = Type("ValueList") Or TypeOf(PassedParameters.Attachments) = Type("Array") Then
			For Each Attachment In PassedParameters.Attachments Do
				AttachmentDetails = Attachments.Add();
				If TypeOf(PassedParameters.Attachments) = Type("ValueList") Then
					If IsTempStorageURL(Attachment.Value) Then
						AttachmentDetails.Placement = 4;
						AttachmentDetails.FileNameOnComputer = PutToTempStorage(GetFromTempStorage(Attachment.Value), UUID);
					ElsIf TypeOf(Attachment.Value) = Type("BinaryData") Then
						AttachmentDetails.Placement = 4;
						AttachmentDetails.FileNameOnComputer = PutToTempStorage(Attachment.Value, UUID);
					Else
						AttachmentDetails.Placement = 2;
						AttachmentDetails.FileNameOnComputer = Attachment.Value;
					EndIf;
					AttachmentDetails.FileName = Attachment.Presentation;
				Else // ValueType(PassedParameters.Attachments) = "array of structures"
					If Not IsBlankString(Attachment.AddressInTempStorage) Then
						AttachmentDetails.Placement = 4;
						AttachmentDetails.FileNameOnComputer = PutToTempStorage(
						GetFromTempStorage(Attachment.AddressInTempStorage), UUID);
					Else
						AttachmentDetails.Placement = 2;
						AttachmentDetails.FileNameOnComputer = Attachment.PathToFile;
					EndIf;
				EndIf;
				AttachmentDetails.FileName = Attachment.Presentation;
				Extension = CommonClientServer.GetFileNameExtension(AttachmentDetails.FileName);
				AttachmentDetails.PictureIndex = FilesOperationsInternalClientServer.IndexOfFileIcon(Extension);
			EndDo;
		EndIf;
		
	EndIf;
	
	If PassedParameters.Property("Subject") And Not IsBlankString(PassedParameters.Subject) Then
		Object.Subject = PassedParameters.Subject;
	EndIf;
	
	If PassedParameters.Property("Recipient") And PassedParameters.Recipient <> Undefined Then
		
		// If the Recipient parameter is passed, this tabular section is cleared before being filled according to the parameter data.
		Object.EmailRecipients.Clear();
		RecipientsList.Clear();
		
		If TypeOf(PassedParameters.Recipient) = Type("String") And Not IsBlankString(PassedParameters.Recipient) Then
			Object.EmailRecipientsList = PassedParameters.Recipient;
			NewRow = Object.EmailRecipients.Add();
			NewRow.Address = PassedParameters.Recipient;
			
		ElsIf TypeOf(PassedParameters.Recipient) = Type("ValueList") Then
			
			For Each ListItem In PassedParameters.Recipient Do
				NewRow = Object.EmailRecipients.Add();
				NewRow.Address = ListItem.Value;
				NewRow.Presentation = ProcessedAddresseePresentation(ListItem.Presentation);
				
				NewRow = RecipientsList.Add();
				NewRow.SendingOption = "Whom";
				NewRow.Address = ListItem.Value;
				NewRow.Presentation = ProcessedAddresseePresentation(ListItem.Presentation);
			EndDo;
			
			Object.EmailRecipientsList = InteractionsClientServer.GetAddressesListPresentation(Object.EmailRecipients, False);
			
		ElsIf TypeOf(PassedParameters.Recipient) = Type("Array") Then
			
			For Each ArrayElement In PassedParameters.Recipient Do
				
				AddressesArray = StrSplit(ArrayElement.Address, ";");
				
				For Each Address In AddressesArray Do
					If IsBlankString(Address) Then 
						Continue;
					EndIf;
					
					SendingOption = ?(ArrayElement.Property("SendingOption"), ArrayElement.SendingOption, "Whom");
					
					If Items.RecipientsListSendingOption.ChoiceList.FindByValue(SendingOption) = Undefined Then
						SendingOption = "Whom";
					EndIf;
					
					If SendingOption = "Copy" Then
						NewRow = Object.CCRecipients.Add();
					ElsIf SendingOption = "HiddenCopy" Then
						NewRow = Object.BccRecipients.Add(); 
					ElsIf SendingOption = "ReplyTo" Then
						NewRow = Object.ReplyRecipients.Add();
					Else
						NewRow = Object.EmailRecipients.Add();
					EndIf;
					
					NewRow.Address = TrimAll(Address);
					NewRow.Presentation = ProcessedAddresseePresentation(ArrayElement.Presentation);
					NewRow.Contact = ArrayElement.ContactInformationSource;
				
				EndDo;
				
			EndDo;
			
			Object.EmailRecipientsList = InteractionsClientServer.GetAddressesListPresentation(Object.EmailRecipients, False);
			
		EndIf;
		
	EndIf;
	
	ClearAddresseesDuplicates(Object.EmailRecipients);
	
	If PassedParameters.Property("Sender") And ValueIsFilled(PassedParameters.Sender) Then
		
		Object.Account = PassedParameters.Sender;
		SenderAttributes = Common.ObjectAttributesValues(
		PassedParameters.Sender,"Ref, UserName, Email");
		Object.SenderPresentation = InteractionsClientServer.GetAddresseePresentation(
		SenderAttributes.UserName, SenderAttributes.Email, "");
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function ProcessedAddresseePresentation(AddresseePresentation)

	AddresseePresentation = StrReplace(AddresseePresentation, ",", "");
	AddresseePresentation = StrReplace(AddresseePresentation, ";", "");
	
	Return AddresseePresentation;

EndFunction

&AtServer
Procedure SetTheMessageTextAccordingToThePassedParameters(PassedParameters)
	
	If Not PassedParameters.Property("Text") Then
		Return;
	EndIf;
	
	Text = PassedParameters.Text;
	
	If TypeOf(Text) = Type("Structure") Then
		
		EmailTextFormattedDocument.SetHTML(Text.HTMLText, Text.AttachmentsStructure);
		Object.TextType = Enums.EmailTextTypes.HTMLWithPictures;
		Object.Text = EmailTextFormattedDocument.GetText();
		
	ElsIf TypeOf(Text) = Type("String") And Not IsBlankString(Text) Then
		
		If StrEndsWith(Lower(TrimR(Text)), Lower("</html>")) Then
			Images = New Structure;
			If TypeOf(PassedParameters.Attachments) = Type("Array") Then
				For IndexOf = -PassedParameters.Attachments.UBound() To 0 Do
					Attachment = PassedParameters.Attachments[-IndexOf];
					If Attachment.Property("Id") And ValueIsFilled(Attachment.Id) Then
						PictureAttachment = New Picture(GetFromTempStorage(Attachment.AddressInTempStorage));
						Images.Insert(Attachment.Presentation, PictureAttachment);
						PassedParameters.Attachments.Delete(-IndexOf);
					EndIf;
				EndDo;
			EndIf;
			
			EmailTextFormattedDocument.SetHTML(Text, Images);
			
			Object.TextType = Enums.EmailTextTypes.HTMLWithPictures;
			Object.Text = EmailTextFormattedDocument.GetText();
			Object.HTMLText = Text;
			
		ElsIf Interactions.DefaultMessageFormat(Object.Author) = Enums.EmailEditingMethods.HTML Then
			
			EmailTextFormattedDocument.Add(Text);
			AttachmentPage = New Structure;
			EmailTextFormattedDocument.GetHTML(Object.HTMLText, AttachmentPage);
			
		Else
			Object.Text = Text;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DisplayBaseEmail()
	
	If Not Object.InteractionBasis = Undefined And Not Object.InteractionBasis.IsEmpty()
		And Object.EmailStatus = Enums.OutgoingEmailStatuses.Draft 
		And (TypeOf(Object.InteractionBasis) = Type("DocumentRef.IncomingEmail")
		Or TypeOf(Object.InteractionBasis) = Type("DocumentRef.OutgoingEmail")) Then
		
		IncomingMessageAttributesValues = Common.ObjectAttributesValues(
			Object.InteractionBasis,"TextType,HTMLText,Text");
		
		IncomingEmailTextType = ?(IncomingMessageAttributesValues.TextType = Enums.EmailTextTypes.PlainText,
			Enums.EmailTextTypes.PlainText,
			Enums.EmailTextTypes.HTML);
		
		If GetFunctionalOption("SendEmailsInHTMLFormat") Then
			
			If IncomingMessageAttributesValues.TextType = Enums.EmailTextTypes.PlainText Then
				
				IncomingEmailText = IncomingMessageAttributesValues.Text;
				Items.IncomingEmailText.Type = FormFieldType.TextDocumentField;
				
			Else
				
				ReadOutgoingHTMLEmailText();
				Items.IncomingEmailText.Type = FormFieldType.HTMLDocumentField;
				Items.IncomingEmailText.ReadOnly = False
				
			EndIf;
			
			If Not Object.DisplaySourceEmailBody Then
				Items.IncomingGroup.Visible = False;
			Else
				Items.DisplayBaseEmailText.Check = True;
			EndIf;
			
		Else
			
			Items.IncomingGroup.Visible = False;
			EmailText = GenerateEmailTextIncludingBaseEmail(Undefined, Object);
			
		EndIf;
		
	Else
		
		Items.IncomingGroup.Visible = False;
		Items.DisplayBaseEmailText.Visible = False;
		
	EndIf;
	
EndProcedure

&AtServer
Function TextInsertionInEmailResult(EmailText, RowStart1, ColumnStart1, ColumnEnd1, ValueSelected)
	
	TextDocument = New TextDocument;
	TextDocument.SetText(EmailText);
	InsertionRow = TextDocument.GetLine(RowStart1);
	InsertionRow = Left(InsertionRow, ColumnStart1 - 1) + ValueSelected + Right(InsertionRow,StrLen(InsertionRow) - ColumnEnd1 + 1);
	TextDocument.ReplaceLine(RowStart1, InsertionRow);
	Return TextDocument.GetText();
	
EndFunction

#EndRegion

&AtClient
Procedure SendExecute()
	
	ClearMessages();
	
	FoundRows = AvailableAccountsForSending.FindRows(New Structure("Account", Object.Account));
	If FoundRows.Count() = 0 Then
		CommonClient.MessageToUser(
			NStr("en = 'The selected account cannot be used to send mail.';"),, "SenderPresentation", "Object");
		Return;
	EndIf;
	
	If FoundRows[0].DeleteAfterSend Then
			
		ButtonsList = New ValueList;
		ButtonsList.Add(DialogReturnCode.Yes, NStr("en = 'Send';"));
		ButtonsList.Add(DialogReturnCode.No, NStr("en = 'Send and save';"));
		ButtonsList.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
		
		QueryText = NStr("en = 'This email account doesn''t store sent messages in the app.
		                    |Do you want to continue?';");
		CloseNotificationHandler = New NotifyDescription("PromptForNotSavingSentEmail", ThisObject);
		ShowQueryBox(CloseNotificationHandler,QueryText, ButtonsList,, DialogReturnCode.Yes, NStr("en = 'Send message';"));
	Else
		SendMailClient();
	EndIf;
	
EndProcedure

&AtClient
Procedure ForwardMailExecute()
	
	Basis = New Structure("Basis,Command", Object.Ref, "ForwardMail");
	OpeningParameters = New Structure("Basis", Basis);
	OpenForm("Document.OutgoingEmail.ObjectForm", OpeningParameters);

EndProcedure

&AtServer
Procedure SetButtonTitleByDefault()
	
	If Object.EmailStatus = Enums.OutgoingEmailStatuses.Sent Then
		Items.Send.Title = NStr("en = 'Forward';");
	ElsIf Object.EmailStatus = Enums.OutgoingEmailStatuses.Outgoing Then
		Items.Send.Title = NStr("en = 'Send now';");
	ElsIf Object.EmailStatus = Enums.OutgoingEmailStatuses.Draft Then
		If Common.FileInfobase() Then
			EmailOperationSettings = Interactions.EmailOperationSettings();
			If EmailOperationSettings.Property("SendMessagesImmediately") And EmailOperationSettings.SendMessagesImmediately Then
				SendMessagesImmediately = True;
			EndIf;
		EndIf;
		
		Items.Send.Title = NStr("en = 'Send';");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MessageFormatOnChange()
	
	If Object.TextType <> PredefinedValue("Enum.EmailTextTypes.PlainText") 
		And MessageFormat = PredefinedValue("Enum.EmailEditingMethods.NormalText") Then
		
		InteractionsClient.PromptOnChangeMessageFormatToPlainText(ThisObject);
		
	Else
		
		OnChangeSignatureFormatToHTMLAtServer(Object.Account);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnCreateAndOnReadAtServer()
	
	FileInfobase = Common.FileInfobase();
	Interactions.SetEmailFormHeader(ThisObject);
	SetButtonTitleByDefault();
	ProcessPassedParameters(Parameters);
	
	FillAttachments(Parameters);
	
	For Each EmailRecipient In Object.EmailRecipients Do
		If ValueIsFilled(EmailRecipient.Contact) Then
			AddressesAndContactsMaps.Add(EmailRecipient.Contact, EmailRecipient.Address);
		EndIf;
	EndDo;
	
	DefineItemsVisibilityAvailabilityDependingOnEmailStatus();
	DisplayBaseEmail();
	
	If Not Object.Ref.IsEmpty() Then
		Interactions.SetInteractionFormAttributesByRegisterData(ThisObject);
		CurrentEmailStatus = Object.EmailStatus;
	EndIf;
	
	UnderControl = Not Reviewed;
	
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "OutgoingEmail");
	
	If Object.EmailStatus = Enums.OutgoingEmailStatuses.Sent Then
		Items.Subject.TextEdit                  = False;
	EndIf;
	
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);
	
	GenerateEmailRecipientsLists();  
	DoDisplayImportance();
	
EndProcedure 

&AtServerNoContext
Function FindContacts(Val SearchString)
	
	Result = New ValueList;
	TableOfContacts = Interactions.FindContactsWithAddresses(SearchString);
	For Each Selection In TableOfContacts Do
		SelectionValue = New Structure;
		SelectionValue.Insert("Contact", Selection.Contact);
		SelectionValue.Insert("Address", Selection.Presentation);
		SelectionValue.Insert("Presentation", Selection.Description);
		SelectionValue.Insert("IndexInRecipientsList", 0);
		Result.Add(SelectionValue, 
			InteractionsClientServer.GetAddresseePresentation(Selection.Description, Selection.Presentation, ""));
	EndDo;
	Return Result;
	
EndFunction 

&AtClient
Function GetBaseIDsPresentation(Val IDs)

	IDs = StrReplace(IDs, "<",  " ");
	IDs = StrReplace(IDs, ">",  " ");
	IDs = StrReplace(IDs, "  ", " ");
	IDs = TrimAll(StrReplace(IDs, "  ", " "));
	IDs = StrReplace(IDs, " ", Chars.LF + "                          ");
	
	Return IDs;

EndFunction

&AtClient
Procedure EditRecipientsList(ToSelect, SelectionGroup = "")
	
	Object.EmailRecipients.Clear();
	Object.CCRecipients.Clear();
	Object.BccRecipients.Clear();
	Object.ReplyRecipients.Clear();
	For Each Recipient In RecipientsList Do
		If Recipient.SendingOption = "ReplyTo" Then
			NewRow = Object.ReplyRecipients.Add();
		ElsIf Recipient.SendingOption = "Copy" Then
			NewRow = Object.CCRecipients.Add();
		ElsIf Recipient.SendingOption = "HiddenCopy" Then
			NewRow = Object.BccRecipients.Add();
		Else
			NewRow = Object.EmailRecipients.Add();
		EndIf;
		FillPropertyValues(NewRow, Recipient);
	EndDo;
	
	// Get the addressee list.
	TabularSectionsMap = New Map;
	TabularSectionsMap.Insert("Whom", Object.EmailRecipients);
	TabularSectionsMap.Insert("Cc", Object.CCRecipients);
	TabularSectionsMap.Insert("Hidden1", Object.BccRecipients);
	TabularSectionsMap.Insert("Response", Object.ReplyRecipients);
	
	SelectedItemsList = New ValueList;
	For Each TabularSection In TabularSectionsMap Do
		SelectedItemsList.Add(
			EmailManagementClient.ContactsTableToArray(TabularSection.Value), TabularSection.Key);
	EndDo;

	OpeningParameters = New Structure;
	OpeningParameters.Insert("Account", Object.Account);
	OpeningParameters.Insert("SelectedItemsList", SelectedItemsList);
	OpeningParameters.Insert("SubjectOf", SubjectOf);
	OpeningParameters.Insert("MailMessage", Object.Ref);
	OpeningParameters.Insert("DefaultGroup", ?(IsBlankString(SelectionGroup), "Whom", SelectionGroup));
	
	NotificationAfterClose = New NotifyDescription("AfterFillAddressBook", ThisObject);
	CommonFormName = ?(ToSelect, "CommonForm.AddressBook", "CommonForm.ContactsClarification");
	
	OpenForm(CommonFormName, OpeningParameters, ThisObject,,,, NotificationAfterClose);
	
EndProcedure

&AtClient
Procedure AfterFillAddressBook(ValueSelected, AdditionalParameters) Export
	
	FillSelectedRecipientsAfterChoice(ValueSelected);
	
EndProcedure

&AtClient
Procedure FillSelectedRecipientsAfterChoice(ValueSelected)
	
	If TypeOf(ValueSelected) <> Type("Array") And TypeOf(ValueSelected) <> Type("Map") Then
		Return;
	EndIf;
	
	// Get the addressee list.
	TabularSectionsMap = New Map;
	TabularSectionsMap.Insert("Whom", Object.EmailRecipients);
	TabularSectionsMap.Insert("Cc", Object.CCRecipients);
	TabularSectionsMap.Insert("Hidden1", Object.BccRecipients);
	TabularSectionsMap.Insert("Recipients", Object.ReplyRecipients);
	
	ToSelect = (Object.EmailStatus <> PredefinedValue("Enum.OutgoingEmailStatuses.Sent"));
	
	If ToSelect Then
		FillSelectedRecipients(TabularSectionsMap, ValueSelected);
	Else
		FillClarifiedContacts(ValueSelected);
	EndIf;
	
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "OutgoingEmail");
	ContactsChanged = True;
	Modified = True;

EndProcedure

&AtClient
Procedure FillSelectedRecipients(TabularSectionsMap, Result)

	For Each TabularSection In TabularSectionsMap Do
		TabularSection.Value.Clear();
	EndDo;
	
	AddressesAddedEarlierArray = New Array;
	
	For Each Item In Result Do
		
		TabularSection = TabularSectionsMap.Get(Item.Group);
		If TabularSection = Undefined Then
			TabularSection = Object.EmailRecipients;
		EndIf;
		
		If AddressesAddedEarlierArray.Find(Item.Address) <> Undefined Then
			Continue;
		EndIf;
		
		NewRow = TabularSection.Add();
		NewRow.Address         = Item.Address;
		NewRow.Presentation = ProcessedAddresseePresentation(Item.Presentation);
		NewRow.Contact       = Item.Contact;
		
		AddressesAddedEarlierArray.Add(NewRow.Address);
		
	EndDo;
	
	ClearAddresseesDuplicates(Object.EmailRecipients);
	
	GenerateRecipientsLists();
	
EndProcedure

&AtClient
Procedure GenerateRecipientsLists()

	Object.EmailRecipientsList =
		InteractionsClientServer.GetAddressesListPresentation(Object.EmailRecipients, False);
	Object.CcRecipientsList =
		InteractionsClientServer.GetAddressesListPresentation(Object.CCRecipients, False);
	Object.BccRecipientsList = 
		InteractionsClientServer.GetAddressesListPresentation(Object.BccRecipients, False);

	GenerateEmailRecipientsLists();
	
EndProcedure

&AtServer
Procedure GenerateEmailRecipientsLists()
	
	RecipientsList.Clear();
	
	AddAddressToRecipientsList(RecipientsList, Object.EmailRecipients, "Whom");
	AddAddressToRecipientsList(RecipientsList, Object.CCRecipients, "Copy");
	AddAddressToRecipientsList(RecipientsList, Object.BccRecipients, "HiddenCopy");
	AddAddressToRecipientsList(RecipientsList, Object.ReplyRecipients, "ReplyTo");
	
	If RecipientsList.Count() = 0 Then
		NewRow = RecipientsList.Add();
		NewRow.SendingOption = "Whom";
	EndIf;
	
EndProcedure

&AtServer
Procedure AddAddressToRecipientsList(RecipientsList, EmailRecipients, Whom)

	For Each RecipientRow In EmailRecipients Do
		NewRow = RecipientsList.Add();
		NewRow.SendingOption = Whom;
		NewRow.Address           = RecipientRow.Address;
		NewRow.Contact         = RecipientRow.Contact;
		NewRow.Presentation   = InteractionsClientServer.GetAddresseePresentation(RecipientRow.Presentation, 
			RecipientRow.Address, "");
	EndDo;
		
EndProcedure

&AtClient
Procedure FillClarifiedContacts(Result)
	
	Object.CCRecipients.Clear();
	Object.ReplyRecipients.Clear();
	Object.EmailRecipients.Clear();
	Object.BccRecipients.Clear();
	
	For Each ArrayElement In Result Do
	
		If ArrayElement.Group = "Whom" Then
			TableOfRecipients = Object.EmailRecipients;
		ElsIf ArrayElement.Group = "Cc" Then
			TableOfRecipients = Object.CCRecipients;
		ElsIf ArrayElement.Group = "Hidden1" Then
			TableOfRecipients = Object.BccRecipients;
		Else
			TableOfRecipients = Object.ReplyRecipients;
		EndIf;
		
		RowRecipients = TableOfRecipients.Add();
		FillPropertyValues(RowRecipients, ArrayElement);
	
	EndDo;
	
	GenerateRecipientsLists();

EndProcedure

&AtClient
Procedure ShowEmailAddressRequiredMessage()
	ShowMessageBox(, NStr("en = 'Enter an email address';"));
EndProcedure

&AtServer
Function ExecuteSendingAtServer()
	
	EmailObject = FormAttributeToValue("Object");
	
	Result = New Structure;
	Result.Insert("MessageText", "");
	Result.Insert("EmailSent", False);
	Result.Insert("AttachmentError", False);
	
	EmailParameters = Interactions.EmailSendingParameters(EmailObject);
	MailMessage = EmailOperations.PrepareEmail(EmailObject.Account, EmailParameters);
	Try
		SendingResult = EmailOperations.SendMail(EmailObject.Account, MailMessage);
	Except
		ErrorText = EmailOperations.ExtendedErrorPresentation(
			ErrorInfo(), Common.DefaultLanguageCode());
		
		WriteLogEvent(EmailManagement.EventLogEvent(),
			EventLogLevel.Error, , EmailObject.Ref, ErrorText);
		
		Result.MessageText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		Result.AttachmentError = True;
		Return Result;
	EndTry;
	
	ErrorProcessingParameters = EmailManagement.SendErrorProcessingParameters();
	ErrorProcessingParameters.EmailObject                      = EmailObject;
	ErrorProcessingParameters.Ref                            = EmailObject.Ref;
	ErrorProcessingParameters.EmailPresentation               = Interactions.EmailPresentation(EmailObject.Subject, EmailObject.Date);
	ErrorProcessingParameters.AttemptsNumber                 = 0;
	ErrorProcessingParameters.IncrementAttemptsCount = False;
	ErrorProcessingParameters.InformUser              = True;
	
	If ValueIsFilled(SendingResult.WrongRecipients) Then
		FillPropertyValues(Result, EmailManagement.ProcessEmailSendingError(
			ErrorProcessingParameters, SendingResult.WrongRecipients));
			
		If Not Result.EmailSent Then
			ValueToFormAttribute(EmailObject, "Object");
			Return Result;
		EndIf;
	EndIf;
	
	Result.EmailSent = True;
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("Document.OutgoingEmail");
		LockItem.SetValue("Ref", Object.Ref);
		InformationRegisters.InteractionsFolderSubjects.BlockInteractionFoldersSubjects(Block, Object.Ref);
		Block.Lock();
		
		If Not EmailObject.DeleteAfterSend Then
			
			EmailObject.EmailStatus                       = Enums.OutgoingEmailStatuses.Sent;
			EmailObject.PostingDate                    = CurrentSessionDate();
			EmailObject.MessageID             = SendingResult.SMTPEmailID;
			EmailObject.MessageIDIMAPSending = SendingResult.IMAPEmailID;
			EmailObject.Write(DocumentWriteMode.Write);
			ValueToFormAttribute(EmailObject, "Object");
			
			Interactions.SetEmailFolder(Object.Ref, Interactions.DefineFolderForEmail(Object.Ref));
			CurrentEmailStatus = Object.EmailStatus;
		Else
			EmailObject.Read();
			EmailObject.Delete();
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;	
	Return Result;
	
EndFunction

&AtServer
Function EstimateEmailSize()

	Size = StrLen(Object.Subject)*2;
	Size = Size + ?(Object.TextType = Enums.EmailTextTypes.HTML,
	                    StrLen(Object.HTMLText),
	                    StrLen(Object.Text)) * 2;
	
	For Each Attachment In Attachments Do
		Size = Size + Attachment.Size * 1.5;
	EndDo;
	
	For Each MapsTableRow In AttachmentsNamesToIDsMapsTable Do
		Size = Size + MapsTableRow.Picture.GetBinaryData().Size()*1.5;
	EndDo;
	
	Return Size;

EndFunction

&AtServer
Function FileAttributes(File)
	
	RequiredAttributes1 = "Description, Extension, PictureIndex, Size";
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		RequiredAttributes1 = RequiredAttributes1 + ", SignedWithDS";
	EndIf;
	
	Return Common.ObjectAttributesValues(File, RequiredAttributes1);
	
EndFunction

&AtClient
Procedure SendMailClient()
	
	If Not SendMessagesImmediately Then
		SendMessagesImmediately = (
			Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Outgoing"));
	EndIf;
	
	IsSendingInProgress = True;
	
	If Object.Ref.IsEmpty() 
		Or Modified 
		Or Object.IncludeOriginalEmailBody 
		Or (Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Draft")) Then
		Write();
	EndIf;
	
	IsSendingInProgress = False;
	
	If Modified Then
		Return;
	EndIf;
	
	If SendMessagesImmediately Then
		Result = ExecuteSendingAtServer();
	Else
		Close();
		Return;
	EndIf;
	
	If Result.EmailSent And Result.MessageText = "" Then
		Close();
		Return;
	EndIf;
	
	If Result.EmailSent  Then
		Read();
	EndIf;
	
	If Result.AttachmentError Then
		EmailOperationsClient.ReportConnectionError(Object.Account, 
			NStr("en = 'The message is not sent';"), Result.MessageText);
	Else
		ShowMessageBox(, Result.MessageText);
	EndIf;
	
EndProcedure

&AtClient
Procedure PromptForNotSavingSentEmail(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		Object.DeleteAfterSend = True;
	ElsIf QuestionResult = DialogReturnCode.No Then
		Object.DeleteAfterSend = False;
	ElsIf QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	SendMailClient();
	
EndProcedure

&AtClient
Procedure PromptOnChangeFormatOnClose(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		MessageFormat = PredefinedValue("Enum.EmailEditingMethods.HTML");
	Else
		EmailText = EmailTextFormattedDocument.GetText();
		Object.TextType = PredefinedValue("Enum.EmailTextTypes.PlainText");
		EmailTextFormattedDocument.Delete();
		Items.EmailText.Type = FormFieldType.TextDocumentField;
		Object.HTMLText = "";
		Object.Encoding = "UTF-8";
		Items.EmailTextPages.CurrentPage = Items.PlainTextPage;
	EndIf;
		
	Items.MessageFormat.Title = MessageFormat;
	
EndProcedure

&AtClient
Procedure OpenAttachmentProperties(CurrentIndexInCollection)
	
	CurrentData = Attachments.Get(CurrentIndexInCollection);
	If CurrentData = Undefined Then
		Return;
	EndIf;

	Items.Attachments.CurrentRow = CurrentData.GetID();

	FileAvailableForEditing = 
		(Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Draft"));
	FormParameters = New Structure("ReadOnly", Not FileAvailableForEditing);
	FilesOperationsClient.OpenFileForm(CurrentData.Ref,, FormParameters);
	
EndProcedure

&AtServer
Procedure ChangeSignature(PreviousAccount, NewAccount)

	ParametersPreviousAccount =
			Interactions.GetUserParametersForOutgoingEmail(
			PreviousAccount,
			MessageFormat,
			?(Object.InteractionBasis = Undefined, True, False));
			
	ParametersNewAccount =
			Interactions.GetUserParametersForOutgoingEmail(
			NewAccount,
			MessageFormat,
			?(Object.InteractionBasis = Undefined, True, False));
	
	If MessageFormat = Enums.EmailEditingMethods.NormalText Then
		If IsBlankString(EmailText) Then
			EmailText = ParametersNewAccount.Signature;
		Else
			If StrOccurrenceCount(EmailText, ParametersPreviousAccount.Signature) > 0 Then
				EmailText = StrReplace(EmailText, ParametersPreviousAccount.Signature, ParametersNewAccount.Signature);
			Else
				EmailText = EmailText + ParametersNewAccount.Signature;
			EndIf;
		EndIf;
	Else
		
		
		TextEmail = EmailTextFormattedDocument.GetText();
		If IsBlankString(TextEmail) Then
			
			EmailTextFormattedDocument = ParametersNewAccount.Signature;
			
		Else
			
			If TypeOf(ParametersPreviousAccount.Signature) = Type("FormattedDocument") Then
				
				TextPreviousAccount = ParametersPreviousAccount.Signature.GetText();
				
				If StrOccurrenceCount(TextEmail, TextPreviousAccount) > 0 Then
					
					DeleteOldSignatureItems(EmailTextFormattedDocument,ParametersPreviousAccount.Signature);
					
				EndIf;
				
				If TypeOf(ParametersNewAccount.Signature) = Type("FormattedDocument") Then
					AddFormattedDocumentToFormattedDocument(EmailTextFormattedDocument, ParametersNewAccount.Signature);
				EndIf;
			
			EndIf;
			
		EndIf;
		
	EndIf;

EndProcedure

&AtServer
Procedure OnChangeSignatureFormatToHTMLAtServer(Account)
	
	AccountParameters =
			Interactions.GetUserParametersForOutgoingEmail(
			Account,
			MessageFormat,
			?(Object.InteractionBasis = Undefined, True, False));
		
	If AccountParameters.Signature <> Undefined Then
		
		TextSignature = AccountParameters.Signature.GetText();
	
		If StrOccurrenceCount(EmailText, TextSignature) > 0 Then
			EmailText = StrReplace(EmailText, TextSignature, "");
		EndIf;
	
		EmailTextFormattedDocument.Add(EmailText);
	
		AddFormattedDocumentToFormattedDocument(EmailTextFormattedDocument, AccountParameters.Signature);
		
	Else
		
		EmailTextFormattedDocument.Add(EmailText);
		
	EndIf;
	
	Object.Text = "";
	Object.TextType =  PredefinedValue("Enum.EmailTextTypes.HTML");
	Items.EmailTextPages.CurrentPage = Items.FormattedDocumentPage;
	Items.MessageFormat.Title = MessageFormat;
	
EndProcedure

&AtServer
Procedure DeleteOldSignatureItems(EmailTextFormattedDocument, OldSignature)

	HTMLTextFormattedDocument = "";
	AttachmentsFormattedDocument = New Structure;
	
	EmailTextFormattedDocument.GetHTML(HTMLTextFormattedDocument, AttachmentsFormattedDocument);
	
	OldSignatureByAdding = New FormattedDocument;
	AddFormattedDocumentToFormattedDocument(OldSignatureByAdding, OldSignature);
	HTMLTextOldSignature = "";
	AttachmentsOldSignature = New Structure;
	
	OldSignatureByAdding.GetHTML(HTMLTextOldSignature, AttachmentsOldSignature);

	HTMLTextOldSignature = Interactions.HTMLTagContent(HTMLTextOldSignature,"body");
	HTMLTextFormattedDocument = StrReplace(HTMLTextFormattedDocument, HTMLTextOldSignature, "");
	EmailTextFormattedDocument.SetHTML(HTMLTextFormattedDocument, AttachmentsFormattedDocument);
	
EndProcedure

&AtServer
Procedure AddFormattedDocumentToFormattedDocument(DocumentRecipient, DocumentToAdd)

	For Indus = 0 To DocumentToAdd.Items.Count() -1 Do
		ItemToAdd = DocumentToAdd.Items[Indus];
		If TypeOf(ItemToAdd) = Type("FormattedDocumentParagraph") Then
			NewParagraph = DocumentRecipient.Items.Add();
			FillPropertyValues(NewParagraph, ItemToAdd, "ParagraphType, HorizontalAlign, LineSpacing,Indent");
			AddFormattedDocumentToFormattedDocument(NewParagraph, ItemToAdd);
		Else
			If TypeOf(ItemToAdd) = Type("FormattedDocumentText")
				And Not ItemToAdd.Text = "" Then
				NewItem = DocumentRecipient.Items.Add(ItemToAdd.Text, Type("FormattedDocumentText"));
				FillPropertyValues(NewItem,ItemToAdd,,"EndBookmark, BeginBookmark, Parent");
			ElsIf TypeOf(ItemToAdd) = Type("FormattedDocumentPicture") Then
				NewItem = DocumentRecipient.Items.Add(ItemToAdd.Picture, Type("FormattedDocumentPicture"));
				FillPropertyValues(NewItem,ItemToAdd,,"EndBookmark, BeginBookmark, Parent");
			ElsIf TypeOf(ItemToAdd) = Type("FormattedDocumentLinefeed") Then
				If TypeOf(DocumentToAdd) = Type("FormattedDocumentParagraph") 
					And (DocumentToAdd.ParagraphType = ParagraphType.BulletedList
					Or DocumentToAdd.ParagraphType = ParagraphType.NumberedList) Then
					Continue;
				EndIf;
				NewItem = DocumentRecipient.Items.Add( , Type("FormattedDocumentLinefeed"));
			EndIf;
		EndIf;
	EndDo;

EndProcedure

&AtClientAtServerNoContext
Procedure ClearAddresseesDuplicates(TableOfRecipients)
	
	MapOfRowsAddressesToDelete = New Map;
	
	For Each RecipientRow In TableOfRecipients Do
		If MapOfRowsAddressesToDelete.Get(RecipientRow.Address) <> Undefined Then
			Continue;
		EndIf;
		FoundRows =  TableOfRecipients.FindRows(New Structure("Address", RecipientRow.Address));
		If FoundRows.Count() > 1 Then
			ArrayToDelete = New Array;
			For Indus = 0 To FoundRows.Count() - 1 Do
				If Indus = 0 Then
					If Not ValueIsFilled(FoundRows[Indus].Contact) Then
						ArrayToDelete.Add(FoundRows[Indus]);
					EndIf;
				Else
					If ArrayToDelete.Count() = 0 Or (Not ValueIsFilled(FoundRows[Indus].Contact)) Then
						ArrayToDelete.Add(FoundRows[Indus]);
					ElsIf ValueIsFilled(FoundRows[Indus].Contact) And Not (Indus = ArrayToDelete.Count()) Then
						ArrayToDelete.Add(FoundRows[Indus]);
					EndIf;
				EndIf;
				
			EndDo;
			
			If FoundRows.Count() = ArrayToDelete.Count() Then
				ArrayToDelete.Delete(0);
			EndIf;
			
			MapOfRowsAddressesToDelete.Insert(RecipientRow.Address,ArrayToDelete);
			
		EndIf;
	EndDo;
	
	For Each MapRow In MapOfRowsAddressesToDelete Do
		For Each RowToDelete In MapRow.Value Do
			TableOfRecipients.Delete(RowToDelete);
		EndDo;
	EndDo;

EndProcedure

&AtClient
Function EmailAttachmentParameters()
	
	AttachmentParameters = InteractionsClient.EmailAttachmentParameters();
	AttachmentParameters.BaseEmailDate = ?(ValueIsFilled(Object.PostingDate), Object.PostingDate, Object.Date);
	AttachmentParameters.EmailBasis     = Object.Ref;
	AttachmentParameters.BaseEmailSubject = Object.Subject;
	
	Return AttachmentParameters;
	
EndFunction

&AtClient
Procedure AfterPutFile(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		If Not IsBlankString(Result.ErrorDescription) Then
			Raise Result.ErrorDescription;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterChangingSender()

	ChangeSignature(AccountBeforeChange, Object.Account);

EndProcedure

&AtClient
Procedure AfterQuestionOnClose(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		WrittenSuccessfully = Write();
		If WrittenSuccessfully Then
			Close();
		EndIf;
	ElsIf Result = DialogReturnCode.No 
		And AdditionalParameters.FilesToEditArray.Count() > 0 Then
		
		FilesOperationsInternalServerCall.UnlockFiles(AdditionalParameters.FilesToEditArray);
		Modified = False;
		Close();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillTabularSectionsByRecipientsList()
	
	Object.EmailRecipients.Clear();
	Object.CCRecipients.Clear();
	Object.BccRecipients.Clear();
	Object.ReplyRecipients.Clear();
	For Each Recipient In RecipientsList Do
		
		If IsBlankString(Recipient.Presentation) Then
			Recipient.Address = "";
			Recipient.Contact = Undefined;
			Continue;
		EndIf;
				
		MailAddresses = CommonClientServer.EmailsFromString(Recipient.Presentation);
		
		For Each MailAddress In MailAddresses Do
			
			If Recipient.SendingOption = "ReplyTo" Then
				NewRow = Object.ReplyRecipients.Add();
			ElsIf Recipient.SendingOption = "Copy" Then
				NewRow = Object.CCRecipients.Add();
			ElsIf Recipient.SendingOption = "HiddenCopy" Then
				NewRow = Object.BccRecipients.Add();
			Else
				NewRow = Object.EmailRecipients.Add();
			EndIf;
			
			NewRow.Address = MailAddress.Address;
			NewRow.Presentation = MailAddress.Alias;
			NewRow.Contact = Recipient.Contact;
		EndDo;
		
	EndDo;
	
EndProcedure

// StandardSubsystems.Properties

&AtServer
Procedure PropertiesExecuteDeferredInitialization()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillAdditionalAttributesInForm(ThisObject);
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

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

// StandardSubsystems.MessagesTemplates

&AtClient
Procedure FillByTemplateAfterTemplateChoice(Result, AdditionalParameters) Export
	If Result <> Undefined And TypeOf(Result) = Type("Structure") And Result.Property("Template") Then
		FillTemplateAfterChoice(Result);
	EndIf;
EndProcedure

&AtServer
Procedure FillTemplateAfterChoice(EmailParameters)
	
	ProcessPassedParameters(EmailParameters);
	GenerateEmailRecipientsLists();
	DefineItemsVisibilityAvailabilityDependingOnEmailStatus();
	
EndProcedure

&AtServer
Procedure DeterminePossibilityToFillEmailByTemplate()
	
	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		If Object.EmailStatus = Enums.OutgoingEmailStatuses.Draft Then
			ModuleMessageTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
			Items.FormGenerateFromTemplate.Visible = ModuleMessageTemplatesInternal.MessageTemplatesUsed();
		EndIf;
	Else
		Items.FormGenerateFromTemplate.Visible = False;
	EndIf;
	
EndProcedure

// End StandardSubsystems.MessagesTemplates

&AtServer
Procedure SetSecurityWarningVisiblity()
	UnsafeContentDisplayInEmailsProhibited = Interactions.UnsafeContentDisplayInEmailsProhibited();
	Items.SecurityWarning.Visible = Not UnsafeContentDisplayInEmailsProhibited
		And HasUnsafeContent And Not EnableUnsafeContent;
EndProcedure

&AtServer
Procedure ReadOutgoingHTMLEmailText()
	IncomingEmailText = Interactions.ProcessHTMLText(Object.InteractionBasis,
		Not EnableUnsafeContent, HasUnsafeContent);
	SetSecurityWarningVisiblity();
EndProcedure

#EndRegion

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
	ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
	ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
	ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

&AtClient
Procedure CheckEmailsSendingStatus()
	
	StatusOfSendingEmails = StatusOfSendingEmails();
	If Items.WarningAboutUnsentEmails.Visible <> StatusOfSendingEmails.SendingIsSuspended Then
		Items.WarningAboutUnsentEmails.Visible = StatusOfSendingEmails.SendingIsSuspended;
		Items.WarningAboutUnsentEmailsLabel.Title = StatusOfSendingEmails.WarningText;
	EndIf;
	
	Interval = ?(Items.WarningAboutUnsentEmails.Visible, 60, 600);
	AttachIdleHandler("CheckEmailsSendingStatus", Interval, True);
	
EndProcedure

&AtServerNoContext
Function StatusOfSendingEmails()
	
	Result = New Structure;
	Result.Insert("SendingIsSuspended", Interactions.SendingPaused());
	Result.Insert("WarningText", Interactions.SendingPausedWarningText());
	
	Return Result;
	
EndFunction

#EndRegion
