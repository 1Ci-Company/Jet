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
	
	If Object.Ref.IsEmpty() Then
		Object.State = Enums.SMSDocumentStatuses.Draft;
		Reviewed = True;
		OnCreatReadAtServer();
		Interactions.SetSubjectByFillingData(Parameters, SubjectOf);
		ContactsChanged = True;
	EndIf;
	
	If Not FileInfobase Then
		Items.SMSMessageRecipientsCheckDeliveryStatuses.Visible = False;
	EndIf;
	
	Interactions.FillChoiceListForReviewAfter(Items.ReviewAfter.ChoiceList);
	
	// Determining types of contacts that can be created.
	ContactsToInteractivelyCreateList = Interactions.CreateValueListOfInteractivelyCreatedContacts();
	Items.CreateContact.Visible      = ContactsToInteractivelyCreateList.Count() > 0;
	
	Interactions.PrepareNotifications(ThisObject, Parameters);
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesPage");
		AdditionalParameters.Insert("DeferredInitialization", True);
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.StoredFiles
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		FilesHyperlink = ModuleFilesOperations.FilesHyperlink();
		FilesHyperlink.Location = "CommandBar";
		ModuleFilesOperations.OnCreateAtServer(ThisObject, FilesHyperlink);
	EndIf;
	// End StandardSubsystems.StoredFiles
	
	// StandardSubsystems.MessagesTemplates
	DeterminePossibilityToFillEmailByTemplate();
	// End StandardSubsystems.MessagesTemplates
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Interactions.OnWriteInteractionFromForm(CurrentObject, ThisObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);

EndProcedure 

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	Interactions.SetInteractionFormAttributesByRegisterData(ThisObject);
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	OnCreatReadAtServer();
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = Common.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	EndIf;
	// End StandardSubsystems.AttachableCommands

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.MessageText.UpdateEditText();
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	CheckContactCreationAvailability();
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.StoredFiles
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.OnOpen(ThisObject, Cancel);
	EndIf;
	// End StandardSubsystems.StoredFiles

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
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "SMSMessage");
	CheckContactCreationAvailability();
	AddresseesCount = Object.SMSMessageRecipients.Count();
	
	// StandardSubsystems.StoredFiles
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.NotificationProcessing(ThisObject, EventName);
	EndIf;
	// End StandardSubsystems.StoredFiles
	
	// StandardSubsystems.MessagesTemplates
	If EventName = "Write_MessageTemplates" Then
		DeterminePossibilityToFillEmailByTemplate();
	EndIf;
	// End StandardSubsystems.MessagesTemplates
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteMode)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	Interactions.BeforeWriteInteractionFromForm(ThisObject, CurrentObject, ContactsChanged);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)

	InteractionsClient.InteractionSubjectAfterWrite(ThisObject, Object, WriteParameters, "SMSMessage");
	CheckContactCreationAvailability();
	
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
	
	CheckAddresseesListFilling(Cancel);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Object.State = PredefinedValue("Enum.SMSDocumentStatuses.Draft")
		Or Object.State = PredefinedValue("Enum.SMSDocumentStatuses.Outgoing") Then
		InteractionsClient.CheckOfDeferredSendingAttributesFilling(Object, Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	InteractionsClient.ChoiceProcessingForm(ThisObject, ValueSelected, ChoiceSource, ChoiceContext);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ContactsAddlAttributesCommentPagesOnCurrentPageChange(Item, CurrentPage)
	
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
Procedure UnderControlOnChange()
	
	Reviewed = Not UnderControl;
	AvailabilityControl(ThisObject);
	Modified = True;
	
EndProcedure

&AtClient
Procedure MessageTextEditTextChange(Item, Text, StandardProcessing)
	
	CharsLeft = InteractionsClientServer.GenerateInfoLabelMessageCharsCount(
	                   Object.SendInTransliteration,
	                   Text);
	
EndProcedure

&AtClient
Procedure SendInTransliterationOnChange(Item)
	
	CharsLeft = InteractionsClientServer.GenerateInfoLabelMessageCharsCount(
	                        Object.SendInTransliteration,
	                        Object.MessageText)
	
EndProcedure

&AtClient
Procedure SubjectOfStartChoice(Item, ChoiceData, StandardProcessing)
	
	InteractionsClient.SubjectOfStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

// StandardSubsystems.StoredFiles
&AtClient
Procedure Attachable_PreviewFieldClick(Item, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldClick(ThisObject, Item, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PreviewFieldCheckDragging(Item, DragParameters, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldCheckDragging(ThisObject, Item,
			DragParameters, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PreviewFieldDrag(Item, DragParameters, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldDrag(ThisObject, Item,
			DragParameters, StandardProcessing);
	EndIf;
	
EndProcedure
// End StandardSubsystems.StoredFiles

#EndRegion

#Region FormTableItemsEventHandlersSMSMessageRecipients

&AtClient
Procedure SMSMessageRecipientsOnChange(Item)
	
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "SMSMessage");
	AddresseesCount = Object.SMSMessageRecipients.Count();
	ContactsChanged = True;
	
EndProcedure

&AtClient
Procedure SMSMessageRecipientsOnActivateRow(Item)
	
	CheckContactCreationAvailability();
	
EndProcedure

&AtClient
Procedure ContactPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Items.SMSMessageRecipients.CurrentData;
	OpeningParameters = InteractionsClient.ContactChoiceParameters(UUID);
	OpeningParameters.PhoneOnly = True;
	InteractionsClient.SelectContact(SubjectOf, CurrentData.HowToContact, 
		CurrentData.ContactPresentation, CurrentData.Contact, OpeningParameters); 
	
EndProcedure

&AtClient
Procedure ContactPresentationAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	
	If Waiting = 0 Then
		Return;
	EndIf;
	
	If IsBlankString(Text) Then
		Return;
	EndIf;
	
	ChoiceData = ContactsAutoSelection(Text);
	If ChoiceData.Count() > 0 Then
		StandardProcessing = False;
	Else
		ChoiceData = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(ValueSelected) = Type("Structure") Then
		CurrentData = Items.SMSMessageRecipients.CurrentData;
		CurrentData.ContactPresentation = ValueSelected.ContactPresentation;
		CurrentData.Contact               = ValueSelected.Contact;
		ContactPresentationOnChange(Item);
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactPresentationOnChange(Item)
	
	CurrentData = Items.SMSMessageRecipients.CurrentData;
	If CurrentData <> Undefined And ValueIsFilled(CurrentData.Contact) Then
		InteractionsServerCall.PresentationAndAllContactInformationOfContact(CurrentData.Contact,
			CurrentData.ContactPresentation, CurrentData.HowToContact, 
			PredefinedValue("Enum.ContactInformationTypes.Phone"));
	EndIf;
	CheckContactCreationAvailability();
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "SMSMessage");
	
EndProcedure

&AtClient
Procedure ContactPresentationOpening(Item, StandardProcessing)
	
	CurrentData = Items.SMSMessageRecipients.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;	
	
	StandardProcessing = False;
	ShowValue(, CurrentData.Contact);

EndProcedure

&AtClient
Procedure SMSMessageRecipientsOnEditEnd(Item, NewRow, CancelEdit)
	
	CurrentData = Items.SMSMessageRecipients.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentData.MessageState) Then
		CurrentData.MessageState = PredefinedValue("Enum.SMSMessagesState.Draft");
	EndIf;
	
EndProcedure 

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CreateContactExecute()
	
	CurrentData = Items.SMSMessageRecipients.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ClearMessages();
	If Object.Ref.IsEmpty() And Not Write() Then
		Return;
	EndIf;
	
	InteractionsClient.CreateContact(CurrentData.ContactPresentation, CurrentData.HowToContact, 
		Object.Ref, ContactsToInteractivelyCreateList);
	
EndProcedure

&AtClient
Procedure Send(Command)
	
	ClearMessages();
	
	If CheckFilling() Then
		SendExecute();
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckDeliveryStatuses(Command)
	
	ClearMessages();
	CheckDeliveryStatusesServer();
	
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

// StandardSubsystems.StoredFiles
&AtClient
Procedure Attachable_AttachedFilesPanelCommand(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.AttachmentsControlCommand(ThisObject, Command);
	EndIf;
	
EndProcedure
// End StandardSubsystems.StoredFiles

// StandardSubsystems.MessagesTemplates

&AtClient
Procedure GenerateFromTemplate(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplatesClient = CommonClient.CommonModule("MessageTemplatesClient");
		Notification = New NotifyDescription("FillByTemplateAfterTemplateChoice", ThisObject);
		MessageSubject = ?(ValueIsFilled(SubjectOf), SubjectOf, "Shared");
		ModuleMessageTemplatesClient.PrepareMessageFromTemplate(MessageSubject, "SMSMessage", Notification);
	EndIf
	
EndProcedure

// End StandardSubsystems.MessagesTemplates

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ContactPresentation.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.SMSMessageRecipients.Contact");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.FieldSelectionBackColor);

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


///////////////////////////////////////////////////////////////////////////////
// Miscellaneous.

&AtClient
Procedure CheckContactCreationAvailability()
	
	CurrentData = Items.SMSMessageRecipients.CurrentData;
	Items.CreateContact.Enabled = (CurrentData <> Undefined) 
	    And (Not ValueIsFilled(CurrentData.Contact));
		
EndProcedure

&AtServerNoContext
Function ContactsAutoSelection(Val SearchString)
	
	Return Interactions.ContactsAutoSelection(SearchString);
	
EndFunction

&AtServer
Procedure OnCreatReadAtServer()
	
	FileInfobase = Common.FileInfobase();
	ProcessPassedParameters(Parameters);
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "SMSMessage");
	Items.ReviewAfter.Enabled = Not Reviewed;
	CharsLeft = InteractionsClientServer.GenerateInfoLabelMessageCharsCount(
	                     Object.SendInTransliteration,
	                     Object.MessageText);
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);
	UnderControl = Not Reviewed;
	AvailabilityControl(ThisObject);
	AddresseesCount = Object.SMSMessageRecipients.Count();
	
EndProcedure

&AtClient
Procedure SendExecute()
	
	ClearMessages();
	
	SentSuccessfully = SendingResutAtServer();
	If SentSuccessfully Then
		Close();
	EndIf;

EndProcedure

&AtServer
Procedure CheckAddresseesListFilling(Cancel)

	For Each Addressee In Object.SMSMessageRecipients Do
		CheckPhoneFilling(Addressee, Cancel);
	EndDo;
	
EndProcedure

&AtServer
Procedure CheckPhoneFilling(Addressee, Cancel)
	
	If IsBlankString(Addressee.HowToContact) Then
		Common.MessageToUser(
			NStr("en = 'Phone number is required.';"),
			,
			CommonClientServer.PathToTabularSection("Object.SMSMessageRecipients", Addressee.LineNumber, "HowToContact"),
			,
			Cancel);
			Return;
	EndIf;
		
	If StrSplit(Addressee.HowToContact, ";", False).Count() > 1 Then
		Common.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Line %1 contains more than one phone number.';"), Addressee.LineNumber),
			,
			CommonClientServer.PathToTabularSection("Object.SMSMessageRecipients", Addressee.LineNumber, "HowToContact"),
			,
			Cancel);
			Return;
	EndIf;
		
	If Not Interactions.PhoneNumberSpecifiedCorrectly(Addressee.HowToContact) Then
		Common.MessageToUser(
			NStr("en = 'Enter a phone number in the international format.
			|You can use spaces, brackets, and hyphens.
			|For example: +1 (123) 456-78-90.';"),
			,
			CommonClientServer.PathToTabularSection("Object.SMSMessageRecipients", Addressee.LineNumber, "HowToContact"),
			,
			Cancel);
			Return;
	EndIf;
	
	Addressee.SendingNumber = ToFormatNumber(Addressee.HowToContact);
	
EndProcedure

&AtServer
Function ToFormatNumber(Number)
	Result = "";
	AllowedChars = "+1234567890";
	For Position = 1 To StrLen(Number) Do
		Char = Mid(Number,Position,1);
		If StrFind(AllowedChars, Char) > 0 Then
			Result = Result + Char;
		EndIf;
	EndDo;
	
	If StrLen(Result) > 10 Then
		FirstChar = Left(Result, 1);
		If FirstChar = "8" Then
			Result = "+7" + Mid(Result, 2);
		ElsIf FirstChar <> "+" Then
			Result = "+" + Result;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function SendingResutAtServer()
	
	If Modified Then
		Write();
	EndIf;
	
	Result = True;
	
	If FileInfobase
		And (Object.DateToSendEmail = Date(1,1,1) Or Object.DateToSendEmail < CurrentSessionDate())
		And (Object.EmailSendingRelevanceDate = Date(1,1,1) Or Object.EmailSendingRelevanceDate > CurrentSessionDate()) Then
		
		SentEmailsCount = Interactions.SendSMSMessageByDocument(Object);
		Result = SentEmailsCount > 0;
	Else
			
		Interactions.SetStateOutgoingDocumentSMSMessage(Object);
		
	EndIf;
	
	Write();
	AvailabilityControl(ThisObject);
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Procedure AvailabilityControl(Form)

	MessageSent = MessageSent(Form.Object.State);
	StatusUpperOutgoing = Form.Object.State <> PredefinedValue("Enum.SMSDocumentStatuses.Draft")
	                      And Form.Object.State <> PredefinedValue("Enum.SMSDocumentStatuses.Outgoing");
	
	SendingAvailable = True;
	If Form.FileInfobase Then
		If MessageSent Then
			SendingAvailable = False;
		ElsIf Form.Object.State = PredefinedValue("Enum.SMSDocumentStatuses.Outgoing") Then
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
				SessionDate = CurrentSessionDate();
#Else
				SessionDate = CommonClient.SessionDate();
#EndIf
			If (Form.Object.DateToSendEmail) <> Date(1,1,1)
				And Form.Object.DateToSendEmail > SessionDate Then
				SendingAvailable = False;
			EndIf;
			If (Form.Object.EmailSendingRelevanceDate) <> Date(1,1,1)
				And Form.Object.EmailSendingRelevanceDate < SessionDate Then
				SendingAvailable = False;
			EndIf;
		EndIf;
	Else
		If Form.Object.State <> PredefinedValue("Enum.SMSDocumentStatuses.Draft") Then
			SendingAvailable = False;
		EndIf
	EndIf;
	
	Form.Items.FormSend.Enabled                 = SendingAvailable;
	Form.Items.SMSMessageRecipients.ReadOnly                    = StatusUpperOutgoing;
	Form.Items.SendInTransliteration.Enabled           = Not StatusUpperOutgoing;
	Form.Items.MessageText.ReadOnly              = StatusUpperOutgoing;
	Form.Items.ReviewAfter.Enabled               = Form.UnderControl;
	Form.Items.SendingDateRelevanceGroup.Enabled = Not StatusUpperOutgoing;
	
	Form.Items.SMSMessageRecipientsCheckDeliveryStatuses.Enabled =
	                 Form.FileInfobase
	                 And MessageSent
	                 And Form.Object.State = PredefinedValue("Enum.SMSDocumentStatuses.DeliveryInProgress");

EndProcedure

&AtServer
Procedure CheckDeliveryStatusesServer()

	SetPrivilegedMode(True);
	If Not SendSMSMessage.SMSMessageSendingSetupCompleted() Then
		Common.MessageToUser(NStr("en = 'SMS settings not configured.';"),,"Object");
		Return;
	EndIf;
	
	Interactions.CheckSMSMessagesDeliveryStatuses(Object, Modified);
	AvailabilityControl(ThisObject);

EndProcedure

&AtServer
Procedure ProcessPassedParameters(PassedParameters)
	
	If Object.Ref.IsEmpty() Then
		
		If PassedParameters.Property("Text") And Not IsBlankString(PassedParameters.Text) Then
			
			Object.MessageText = PassedParameters.Text;
			
		EndIf;
		
		If PassedParameters.SMSMessageRecipients <> Undefined Then
			
			If TypeOf(PassedParameters.SMSMessageRecipients) = Type("String") And Not IsBlankString(PassedParameters.SMSMessageRecipients) Then
				
				NewRow = Object.SMSMessageRecipients.Add();
				NewRow.Address = PassedParameters.Whom;
				NewRow.MessageState = Enums.SMSMessagesState.Draft;
				
			ElsIf TypeOf(PassedParameters.SMSMessageRecipients) = Type("ValueList") Then
				
				For Each ListItem In PassedParameters.SMSMessageRecipients Do
					NewRow = Object.SMSMessageRecipients.Add();
					NewRow.HowToContact  = ListItem.Value;
					NewRow.Presentation = ListItem.Presentation;
					NewRow.MessageState = Enums.SMSMessagesState.Draft;
				EndDo;
				
			ElsIf TypeOf(PassedParameters.SMSMessageRecipients) = Type("Array") Then
				
				For Each ArrayElement In PassedParameters.SMSMessageRecipients Do
					
					NewRow = Object.SMSMessageRecipients.Add();
					NewRow.HowToContact          = ArrayElement.Phone;
					NewRow.ContactPresentation = ArrayElement.Presentation;
					NewRow.Contact               = ArrayElement.ContactInformationSource;
					NewRow.MessageState = Enums.SMSMessagesState.Draft;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
		If PassedParameters.Property("SubjectOf") Then
			SubjectOf = PassedParameters.SubjectOf;
		EndIf;
		
		If PassedParameters.Property("SendInTransliteration") Then
			Object.SendInTransliteration = PassedParameters.SendInTransliteration;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function MessageSent(State)
	
	Return State <> PredefinedValue("Enum.SMSDocumentStatuses.Draft")
	        And State <> PredefinedValue("Enum.SMSDocumentStatuses.Outgoing");
	
EndFunction

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

// StandardSubsystems.MessagesTemplates

&AtClient
Procedure FillByTemplateAfterTemplateChoice(Result, AdditionalParameters) Export
	If TypeOf(Result) = Type("Structure") Then
		FillTemplateAfterChoice(Result.Template);
		Items.MessageText.UpdateEditText();
	EndIf;
EndProcedure

&AtServer
Procedure FillTemplateAfterChoice(TemplateRef1)
	
	MessageObject = FormAttributeToValue("Object");
	MessageObject.Fill(TemplateRef1);
	ValueToFormAttribute(MessageObject, "Object");
	
EndProcedure

&AtServer
Procedure DeterminePossibilityToFillEmailByTemplate()
	
	MessageTemplatesUsed = False;
	If Object.State = Enums.SMSDocumentStatuses.Draft
		And Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
		If ModuleMessageTemplatesInternal.MessageTemplatesUsed() Then
			MessageTemplatesUsed = ModuleMessageTemplatesInternal.HasAvailableTemplates("SMS");
		EndIf;
	EndIf;
	Items.FormGenerateFromTemplate.Visible = MessageTemplatesUsed;
	
EndProcedure

// End StandardSubsystems.MessagesTemplates

#EndRegion
