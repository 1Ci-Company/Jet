///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// Opens the form of a new document "SMS" containing the passed parameters.
//
// Parameters:
//   FormParameters - See InteractionsClient.SMSMessageSendingFormParameters.
//   DeleteText                - String - not used.
//   DeleteSubject              - AnyRef - not used.
//   DeleteSendInTransliteration - Boolean - not used.
//
Procedure OpenSMSMessageSendingForm(Val FormParameters = Undefined,
    Val DeleteText = "", Val DeleteSubject = Undefined, Val DeleteSendInTransliteration = False) Export
	
	If TypeOf(FormParameters) <> Type("Structure") Then
		Parameters = SMSMessageSendingFormParameters();
		Parameters.SMSMessageRecipients = FormParameters;
		Parameters.Text = DeleteText;
		Parameters.SubjectOf = DeleteSubject;
		Parameters.SendInTransliteration = DeleteSendInTransliteration;
		FormParameters = Parameters;
	EndIf;								  
	OpenForm("Document.SMSMessage.ObjectForm", FormParameters);
	
EndProcedure

// Returns the parameters to pass to InteractionsClient.OpenSMSSendingForm.
//
// Returns:
//  Structure:
//   * SMSMessageRecipients             - String
//                          - ValueList
//                          - Array - List of email recipients.
//   * Text                - String - email text.
//   * SubjectOf              - AnyRef - an email subject.
//   * SendInTransliteration - Boolean - indicates that a message must be transformed into Latin characters
//                                     when sending it.
//
Function SMSMessageSendingFormParameters() Export
	
	Result = New Structure;
	Result.Insert("SMSMessageRecipients", Undefined);
	Result.Insert("Text", "");
	Result.Insert("SubjectOf", Undefined);
	Result.Insert("SendInTransliteration", False);
	Return Result;
	
EndFunction

// AfterWriteAtServer form event handler. This procedure is called for a contact.
//
// Parameters:
//  Form                          - ClientApplicationForm - a form for which the event is being processed.
//  Object                         - FormDataCollection - an object data stored in the form.
//  WriteParameters                - Structure - a structure that gets parameters that will be
//                                               sent with a notification.
//  MessageSenderObjectName - String - a metadata object name, for whose form an event is processed.
//  SendNotification1  - Boolean   - indicates that it is necessary to send a notification from this procedure.
//
Procedure ContactAfterWrite(Form,Object,WriteParameters,MessageSenderObjectName,SendNotification1 = True) Export
	
	If Form.NotificationRequired Then
		
		If ValueIsFilled(Form.BasisObject) Then
			WriteParameters.Insert("Ref",Object.Ref);
			WriteParameters.Insert("Description",Object.Description);
			WriteParameters.Insert("Basis",Form.BasisObject);
			WriteParameters.Insert("NotificationType","WriteContact");
		EndIf;
		
		If SendNotification1 Then
			Notify("Record_" + MessageSenderObjectName,WriteParameters,Object.Ref);
			Form.NotificationRequired = False
		EndIf;
		
	EndIf;
	
EndProcedure

// AfterWriteAtServer form event handler. This procedure is called for an interaction or an interaction subject.
//
// Parameters:
//  Form                          - ClientApplicationForm - a form for which the event is being processed.
//  Object                         - DefinedType.InteractionSubject - an object data stored in the form.
//  WriteParameters                - Structure - a structure that gets parameters that will be
//                                               sent with a notification.
//  MessageSenderObjectName - String - a metadata object name, for whose form an event is processed.
//  SendNotification1  - Boolean   - indicates that it is necessary to send a notification from this procedure.
// 
Procedure InteractionSubjectAfterWrite(Form,Object,WriteParameters,MessageSenderObjectName = "",SendNotification1 = True) Export
		
	If ValueIsFilled(Form.InteractionBasis) Then
		WriteParameters.Insert("Basis",Form.InteractionBasis);
	Else
		WriteParameters.Insert("Basis",Undefined);
	EndIf;
	
	If InteractionsClientServer.IsInteraction(Object.Ref) Then
		WriteParameters.Insert("SubjectOf",Form.SubjectOf);
		WriteParameters.Insert("NotificationType","WriteInteraction");
	ElsIf InteractionsClientServer.IsSubject(Object.Ref) Then
		WriteParameters.Insert("SubjectOf",Object.Ref);
		WriteParameters.Insert("NotificationType","WriteSubject");
	EndIf;
	
	If SendNotification1 Then
		Notify("Record_" + MessageSenderObjectName,WriteParameters,Object.Ref);
		Form.NotificationRequired = False;
	EndIf;
	
EndProcedure

// DragCheck form event handler. It is called for the list of values when dragging interactions to it.
//
// Parameters:
//  Item                   - FormTable - a table, for which the event is being processed.
//  DragParameters   - DragParameters - contains a dragged value, an action type, and possible
//                                                        values when dragging.
//  StandardProcessing      - Boolean - indicates a standard event processing.
//  TableRow             - FormDataCollectionItem - a table row, on which the pointer is positioned.
//  Field                      - Field - Form item associated with the table column.
//
Procedure ListSubjectDragCheck(Item, DragParameters, StandardProcessing, TableRow, Field) Export
	
	If (TableRow = Undefined) Or (DragParameters.Value = Undefined) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) = Type("Array") Then
		
		For Each ArrayElement In DragParameters.Value Do
			If InteractionsClientServer.IsInteraction(ArrayElement) Then
				Return;
			EndIf;
		EndDo;
	EndIf;
	
	DragParameters.Action = DragAction.Cancel;
	
EndProcedure

// Drag form event handler. It is called for the list of values when dragging interactions to it.
//
// Parameters:
//  Item                   - FormTable - a table, for which the event is being processed.
//  DragParameters   - DragParameters - contains a dragged value, an action type, and possible
//                                                        values when dragging.
//  StandardProcessing      - Boolean - indicates a standard event processing.
//  TableRow             - FormDataCollectionItem - a table row, on which the pointer is positioned.
//  Field                      - Field - Form item associated with the table column.
//
Procedure ListSubjectDrag(Item, DragParameters, StandardProcessing, TableRow, Field) Export
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) = Type("Array") Then
		
		InteractionsServerCall.SetSubjectForInteractionsArray(DragParameters.Value,
			TableRow, True);
			
	EndIf;
	
	Notify("InteractionSubjectEdit");
	
EndProcedure

// Saves an email message to the hard drive.
//
// Parameters:
//  MailMessage                  - DocumentRef.IncomingEmail
//                          - DocumentRef.OutgoingEmail - Email message to save.
//  UUID - UUID - an Uuid of a form, from which a saving command was called.
//
Procedure SaveEmailToHardDrive(MailMessage, UUID) Export
	
	FileData = InteractionsServerCall.EmailDataToSaveAsFile(MailMessage, UUID);
	
	If FileData = Undefined Then
		Return;
	EndIf;
	
	FilesOperationsClient.SaveFileAs(FileData);

EndProcedure

#EndRegion

#Region Internal

// Opens a new form of the "Outgoing email" document
// with parameters passed to the procedure.
//
// Parameters:
//  EmailParameters - See EmailOperationsClient.EmailSendOptions.
//  OnCloseNotifyDescription - NotifyDescription - details of notification on closing an email form.
//
Procedure OpenEmailSendingForm(Val EmailParameters = Undefined, Val OnCloseNotifyDescription = Undefined) Export
	
	OpenForm("Document.OutgoingEmail.ObjectForm", EmailParameters, , , , , OnCloseNotifyDescription);
	
EndProcedure

#EndRegion

#Region Private

// Parameters:
//  ObjectFormName - String - item form name of the object being created.
//  Basis       - DefinedType.InteractionContact
//                  - DefinedType.InteractionSubject - Parent object.
//  Source        - ClientApplicationForm - the base object form contains:
//    * Items - FormAllItems - contains:
//      ** Attendees - FormTable - details on the interaction participants.
//
Procedure CreateInteractionOrSubject(ObjectFormName, Basis, Source) Export

	FormOpenParameters = New Structure("Basis", Basis);
	If (TypeOf(Basis) = Type("DocumentRef.Meeting") 
	    Or  TypeOf(Basis) = Type("DocumentRef.PlannedInteraction"))
		And Source.Items.Find("Attendees") <> Undefined
		And Source.Items.Attendees.CurrentData <> Undefined Then
	
		ParticipantDataSource = Source.Items.Attendees.CurrentData;
		FormOpenParameters.Insert("ParticipantData", ParticipantData(ParticipantDataSource));
	
	ElsIf (TypeOf(Basis) = Type("DocumentRef.SMSMessage") 
		And Source.Items.Find("SMSMessageRecipients") <> Undefined
		And Source.Items.SMSMessageRecipients.CurrentData <> Undefined) Then
		
		ParticipantDataSource = Source.Items.SMSMessageRecipients.CurrentData;
		FormOpenParameters.Insert("ParticipantData", ParticipantData(ParticipantDataSource));
	
	EndIf;
	
	OpenForm(ObjectFormName, FormOpenParameters, Source);

EndProcedure

Function ParticipantData(Source)
	Return New Structure("Contact,HowToContact,Presentation",
		Source.Contact,
		Source.HowToContact,
		Source.ContactPresentation);
EndFunction

// Opens a contact object form filled according to an interaction participant details.
//
// Parameters:
//  LongDesc      - String           - a text contact details.
//  Address         - String           - contact information.
//  Basis     - DocumentObject   - the interaction document from which a contact is created.
//  ContactsTypes - ValueList   - a list of possible contact types.
//
Procedure CreateContact(LongDesc, Address, Basis, ContactsTypes) Export

	If ContactsTypes.Count() = 0 Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("LongDesc", LongDesc);
	AdditionalParameters.Insert("Address", Address);
	AdditionalParameters.Insert("Basis", Basis);
	HandlerNotifications = New NotifyDescription("SelectContactTypeOnCompletion", ThisObject, AdditionalParameters);
	ContactsTypes.ShowChooseItem(HandlerNotifications, NStr("en = 'Select contact type';"));

EndProcedure

// A notification handler for contact type choice when creating a contact from interaction documents.
//
// Parameters:
//  SelectionResult - ValueListItem - item value contains a string contact type presentation,
//  AdditionalParameters - Structure - contains fields "Description", "Address" and "Base".
//
Procedure SelectContactTypeOnCompletion(SelectionResult, AdditionalParameters) Export

	If SelectionResult = Undefined Then
		Return;
	EndIf;
	
	FormParameter = New Structure("Basis", AdditionalParameters);
	Contacts = InteractionsClientServer.ContactsDetails();
	NewContactFormName = "";
	For Each Contact In Contacts Do
		If Contact.Name = SelectionResult.Value Then
			NewContactFormName = Contact.NewContactFormName; 
		EndIf;
	EndDo;
	
	If IsBlankString(NewContactFormName) Then
		// ACC:223-off For backward compatibility.
		If InteractionsClientOverridable.CreateContactNonstandardForm(SelectionResult.Value, FormParameter) Then
			Return;
		EndIf;
		// ACC:223-on
		NewContactFormName = "Catalog." + SelectionResult.Value + ".ObjectForm";
	EndIf;
	
	OpenForm(NewContactFormName, FormParameter);

EndProcedure

// NotificationProcessing form event handler. This procedure is called for an interaction.
// 
// Parameters:
//  Form - ClientApplicationForm - contains:
//     * Object - DocumentObject.PhoneCall
//             - DocumentObject.PlannedInteraction
//             - DocumentObject.SMSMessage
//             - DocumentObject.Meeting
//             - DocumentObject.IncomingEmail
//             - DocumentObject.OutgoingEmail - Object that the form contains.
//      * Items - FormAllItems - contains:
//        ** Attendees      - FormTable - interaction contact details.
//        ** CreateContact - FormButton - the item that runs the interaction creation command.
//  EventName - String - Event name.
//  Parameter - Structure:
//              * NotificationType - String - notification type details.
//              * Basis - DefinedType.InteractionContact
//           
//  Source - Arbitrary - an event source.
//
Procedure DoProcessNotification(Form,EventName, Parameter, Source) Export
	
	If TypeOf(Parameter) = Type("Structure") And Parameter.Property("NotificationType") Then
		If (Parameter.NotificationType = "WriteInteraction" Or Parameter.NotificationType = "WriteSubject")
			And Parameter.Basis = Form.Object.Ref Then
			
			If (Form.SubjectOf = Undefined Or InteractionsClientServer.IsInteraction(Form.SubjectOf))
				And Form.SubjectOf <> Parameter.SubjectOf Then
				Form.SubjectOf = Parameter.SubjectOf;
				Form.RepresentDataChange(Form.SubjectOf, DataChangeType.Update);
			EndIf;
			
		ElsIf Parameter.NotificationType = "WriteContact" And Parameter.Basis = Form.Object.Ref Then
			
			If TypeOf(Form.Object.Ref)=Type("DocumentRef.PhoneCall") Then
				Form.Object.SubscriberContact = Parameter.Ref;
				If IsBlankString(Form.Object.SubscriberPresentation) Then
					Form.Object.SubscriberPresentation = Parameter.Description;
				EndIf;
			ElsIf TypeOf(Form.Object.Ref)=Type("DocumentRef.Meeting") 
				Or TypeOf(Form.Object.Ref)=Type("DocumentRef.PlannedInteraction")Then
				Form.Items.Attendees.CurrentData.Contact = Parameter.Ref;
				If IsBlankString(Form.Items.Attendees.CurrentData.ContactPresentation) Then
					Form.Items.Attendees.CurrentData.ContactPresentation = Parameter.Description;
				EndIf;
			ElsIf TypeOf(Form.Object.Ref)=Type("DocumentRef.SMSMessage") Then
				Form.Items.SMSMessageRecipients.CurrentData.Contact = Parameter.Ref;
				If IsBlankString(Form.Items.SMSMessageRecipients.CurrentData.ContactPresentation) Then
					Form.Items.SMSMessageRecipients.CurrentData.ContactPresentation = Parameter.Description;
				EndIf;
			EndIf;
			
			Form.Items.CreateContact.Enabled = False;
			Form.Modified = True;
			
		EndIf;
		
	ElsIf EventName = "ContactSelected" Then
		
		If Form.FormName = "Document.OutgoingEmail.Form.DocumentForm" 
			Or Form.FormName = "Document.IncomingEmail.Form.DocumentForm" Then
			Return;
		EndIf;
		
		If Form.UUID <> Parameter.FormIdentifier Then
			Return;
		EndIf;
		
		ContactChanged = (Parameter.Contact <> Parameter.SelectedContact) And ValueIsFilled(Parameter.Contact);
		Contact = Parameter.SelectedContact;
		If Parameter.EmailOnly Then
			ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Email");
		ElsIf Parameter.PhoneOnly Then
			ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Phone");
		Else
			ContactInformationType = Undefined;
		EndIf;
		
		If ContactChanged Then
			
			If Not Parameter.ForContactSpecificationForm Then
				InteractionsServerCall.PresentationAndAllContactInformationOfContact(
				             Contact, Parameter.Presentation, Parameter.Address, ContactInformationType);
			EndIf;
			
			Address         = Parameter.Address;
			Presentation = Parameter.Presentation;
			
		ElsIf Parameter.ReplaceEmptyAddressAndPresentation And (IsBlankString(Parameter.Address) Or IsBlankString(Parameter.Presentation)) Then
			
			nPresentation = ""; 
			nAddress = "";
			InteractionsServerCall.PresentationAndAllContactInformationOfContact(
			             Contact, nPresentation, nAddress, ContactInformationType);
			
			Presentation = ?(IsBlankString(Parameter.Presentation), nPresentation, Parameter.Presentation);
			Address         = ?(IsBlankString(Parameter.Address), nAddress, Parameter.Address);
			
		Else
			
			Address         = Parameter.Address;
			Presentation = Parameter.Presentation;
			
		EndIf;
		
		If Form.FormName = "CommonForm.AddressBook" Then

			CurrentData = Form.Items.EmailRecipients.CurrentData;
			If CurrentData = Undefined Then
				Return;
			EndIf;
			
			CurrentData.Contact       = Contact;
			CurrentData.Address         = Address;
			CurrentData.Presentation = Presentation;
			
			Form.Modified = True;
			
		ElsIf TypeOf(Form.Object.Ref)=Type("DocumentRef.SMSMessage") Then
			CurrentData = Form.Items.SMSMessageRecipients.CurrentData;
			If CurrentData = Undefined Then
				Return;
			EndIf;
			
			Form.ContactsChanged = True;
			
			CurrentData.Contact               = Contact;
			CurrentData.HowToContact          = Address;
			CurrentData.ContactPresentation = Presentation;
			
			InteractionsClientServer.CheckContactsFilling(Form.Object,Form,"SMSMessage");
			
		ElsIf TypeOf(Form.Object.Ref)=Type("DocumentRef.PlannedInteraction") Then
			CurrentData = Form.Items.Attendees.CurrentData;
			If CurrentData = Undefined Then
				Return;
			EndIf;
			
			Form.ContactsChanged = True;
			
			CurrentData.Contact               = Contact;
			CurrentData.HowToContact          = Address;
			CurrentData.ContactPresentation = Presentation;
			
			InteractionsClientServer.CheckContactsFilling(Form.Object, Form, "PlannedInteraction");
			Form.Modified = True;
			
		ElsIf TypeOf(Form.Object.Ref)=Type("DocumentRef.Meeting") Then
			CurrentData = Form.Items.Attendees.CurrentData;
			If CurrentData = Undefined Then
				Return;
			EndIf;
			
			Form.ContactsChanged = True;
			
			CurrentData.Contact               = Contact;
			CurrentData.HowToContact          = Address;
			CurrentData.ContactPresentation = Presentation;
			
			InteractionsClientServer.CheckContactsFilling(Form.Object, Form, "Meeting");
			Form.Modified = True;
			
		ElsIf TypeOf(Form.Object.Ref)=Type("DocumentRef.PhoneCall") Then
			
			Form.ContactsChanged = True;
			
			Form.Object.SubscriberContact       = Contact;
			Form.Object.HowToContactSubscriber  = Address;
			Form.Object.SubscriberPresentation = Presentation;
			
			InteractionsClientServer.CheckContactsFilling(Form.Object, Form, "PhoneCall");
			Form.Modified = True;
			
		EndIf;
		
	ElsIf EventName = "WriteInteraction"
		And Parameter = Form.Object.Ref Then
		
		Form.Read();
		
	EndIf;
	
EndProcedure

// Parameters:
//  ObjectType        - String - type of the object to be created.
//  CreationParameters - Structure - parameters of a document to be created.
//  Form             - ClientApplicationForm
//
Procedure CreateNewInteraction(ObjectType, CreationParameters = Undefined, Form = Undefined) Export

	OpenForm("Document." + ObjectType + ".ObjectForm", CreationParameters, Form);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Common event handlers of interaction documents

// Opens the contact selection form and handles the choice.
//
// Parameters:
//  SubjectOf        - DefinedType.InteractionSubject - interaction topic.
//  Address          - String - a contact address.
//  Presentation  - String - contact presentation.
//  Contact        - DefinedType.InteractionContact - contact.
//  Parameters      - See InteractionsClient.ContactChoiceParameters.
//
Procedure SelectContact(SubjectOf, Address, Presentation, Contact, Parameters) Export

	OpeningParameters = New Structure;
	OpeningParameters.Insert("SubjectOf",                           SubjectOf);
	OpeningParameters.Insert("Address",                             Address);
	OpeningParameters.Insert("Presentation",                     Presentation);
	OpeningParameters.Insert("Contact",                           Contact);
	OpeningParameters.Insert("EmailOnly",                       Parameters.EmailOnly);
	OpeningParameters.Insert("PhoneOnly",                     Parameters.PhoneOnly);
	OpeningParameters.Insert("ReplaceEmptyAddressAndPresentation", Parameters.ReplaceEmptyAddressAndPresentation);
	OpeningParameters.Insert("ForContactSpecificationForm",        Parameters.ForContactSpecificationForm);
	OpeningParameters.Insert("FormIdentifier",                Parameters.FormIdentifier);
	
	OpenForm("CommonForm.SelectContactPerson", OpeningParameters);

EndProcedure

// Returns: 
//  Structure:
//    * EmailOnly   - Boolean
//    * PhoneOnly - Boolean
//    * ReplaceEmptyAddressAndPresentation - Boolean
//    * ForContactSpecificationForm - Boolean
//
Function ContactChoiceParameters(FormIdentifier) Export
	
	Result = New Structure;
	Result.Insert("EmailOnly",                       False);
	Result.Insert("PhoneOnly",                     False);
	Result.Insert("ReplaceEmptyAddressAndPresentation", True);
	Result.Insert("ForContactSpecificationForm",        False);
	Result.Insert("FormIdentifier",                FormIdentifier);
	Return Result;
	
EndFunction	

// Parameters:
//  Simple         - Date - "Process after" field value. 
//  ValueSelected    - Date
//                       - Number - Either the selected date or the numeric increment of the current date.
//  StandardProcessing - Boolean - indicates a standard processing of a form event handler.
//  Modified   - Boolean - indicates that the form was modified.
//
Procedure ProcessSelectionInReviewAfterField(Simple, ValueSelected, StandardProcessing, Modified) Export
	
	StandardProcessing = False;
	Modified = True;
	
	If TypeOf(ValueSelected) = Type("Number") Then
		Simple = CommonClient.SessionDate() + ValueSelected;
	Else
		Simple = ValueSelected;
	EndIf;
	
EndProcedure

// Sets filter by owner in the subordinate catalog dynamic list
// when activating a row of parent catalog dynamic list.
//
// Parameters:
//  Item - FormTable - a table where an event occurred contains:
//   * CurrentData - ValueTableRow:
//     ** Ref - DefinedType.InteractionContact - contact.
//  Form   - ClientApplicationForm - a form where the items are located.
//
Procedure ContactOwnerOnActivateRow(Item,Form) Export
	
	TableNameWithoutPrefix = Right(Item.Name,StrLen(Item.Name) - StrLen(InteractionsClientServer.PrefixTable()));
	FilterValue = ?(Item.CurrentData = Undefined, Undefined, Item.CurrentData.Ref);
	
	ContactsDetailsArray1 = InteractionsClientServer.ContactsDetails();
	For Each DetailsArrayElement In ContactsDetailsArray1  Do
		If DetailsArrayElement.OwnerName = TableNameWithoutPrefix Then
			FiltersCollection = Form["List_" + DetailsArrayElement.Name].SettingsComposer.FixedSettings.Filter; // DataCompositionFilter
			FiltersCollection.Items[0].RightValue = FilterValue;
		EndIf;
	EndDo;
 
EndProcedure 

Procedure PromptOnChangeMessageFormatToPlainText(Form, AdditionalParameters = Undefined) Export
	
	OnCloseNotifyHandler = New NotifyDescription("PromptOnChangeFormatOnClose", Form, AdditionalParameters);
	MessageText = NStr("en = 'If you change the message format to plain text, all images and formatting will be lost. Continue?';");
	ShowQueryBox(OnCloseNotifyHandler, MessageText, QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("en = 'Change mail format';"));
	
EndProcedure

// Parameters:
//  Item - FormTable - the list being modified contains:
//   * CurrentData - ValueTableRow:
//     ** Ref - DocumentRef.PhoneCall
//               - DocumentRef.PlannedInteraction
//               - DocumentRef.SMSMessage
//               - DocumentRef.Meeting
//               - DocumentRef.IncomingEmail
//               - DocumentRef.OutgoingEmail - Interaction reference.
//  Cancel  - Boolean - indicates that adding is canceled.
//  Copy  - Boolean - a copying flag.
//  OnlyEmail  - Boolean - shows that only an email client is used.
//  DocumentsAvailableForCreation  - ValueList - a list of documents available for creation.
//  CreationParameters  - Structure - new document creation parameters.
//
Procedure ListBeforeAddRow(Item, Cancel, Copy,OnlyEmail,DocumentsAvailableForCreation,CreationParameters = Undefined) Export
	
	If Copy Then
		
		CurrentData = Item.CurrentData;
		If CurrentData = Undefined Then
			Cancel = True;
			Return;
		EndIf;
		
		If TypeOf(CurrentData.Ref) = Type("DocumentRef.IncomingEmail") 
			Or TypeOf(CurrentData.Ref) = Type("DocumentRef.OutgoingEmail") Then
			Cancel = True;
			If Not OnlyEmail Then
				ShowMessageBox(, NStr("en = 'Copying messages is not allowed';"));
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

// Parameters:
//  Item                        - FormField - a form, for which the event is being processed.
//  EventData                  - FixedStructure - data contains event parameters.
//  StandardProcessing           - Boolean - indicates a standard event processing.
//
Procedure HTMLFieldOnClick(Item, EventData, StandardProcessing) Export
	
	If EventData.Href <> Undefined Then
		StandardProcessing = False;
		
		FileSystemClient.OpenURL(EventData.Href);
		
	EndIf;
	
EndProcedure

// Checks if the DateToSendEmail and EmailSendingRelevance attributes in the document form
// are filled in correctly.
//
// Parameters:
//  Object - DocumentObject - a document being checked.
//  Cancel  - Boolean - True if the attribute values are invalid.
//
Procedure CheckOfDeferredSendingAttributesFilling(Object, Cancel) Export
	
	If Object.DateToSendEmail > Object.EmailSendingRelevanceDate And (Not Object.EmailSendingRelevanceDate = Date(1,1,1)) Then
		
		Cancel = True;
		MessageText= NStr("en = '""Schedule send"" date cannot be later than ""Don''t send after"" date.';");
		CommonClient.MessageToUser(MessageText,, "Object.EmailSendingRelevanceDate");
		
	EndIf;
	
	If Not Object.EmailSendingRelevanceDate = Date(1,1,1)
			And Object.EmailSendingRelevanceDate < CommonClient.SessionDate() Then
	
		Cancel = True;
		MessageText= NStr("en = '""Don''t send after"" date is earlier than today. This message will never be sent.';");
		CommonClient.MessageToUser(MessageText,, "Object.EmailSendingRelevanceDate");
	
	EndIf;
	
EndProcedure

Procedure SubjectOfStartChoice(Form, Item, ChoiceData, StandardProcessing) Export
	
	StandardProcessing = False;
	
	OpenForm("DocumentJournal.Interactions.Form.SelectSubjectType", ,Form);
	
EndProcedure

Procedure ChoiceProcessingForm(Form, ValueSelected, ChoiceSource, ChoiceContext) Export
	
	 If Upper(ChoiceSource.FormName) = Upper("DocumentJournal.Interactions.Form.SelectSubjectType") Then
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		
		ChoiceContext = "SelectSubject";
		
		OpenForm(ValueSelected + ".ChoiceForm", FormParameters, Form);
		
	ElsIf ChoiceContext = "SelectSubject" Then
		
		If InteractionsClientServer.IsSubject(ValueSelected)
			Or InteractionsClientServer.IsInteraction(ValueSelected) Then
		
			Form.SubjectOf = ValueSelected;
			Form.Modified = True;
		
		EndIf;
		
		ChoiceContext = Undefined;
		
	EndIf;
	
EndProcedure

// Parameters:
//  MailMessage - DocumentRef.IncomingEmail
//         - DocumentRef.OutgoingEmail
//         - CatalogRef.IncomingEmailAttachedFiles
//         - CatalogRef.OutgoingEmailAttachedFiles
//  OpeningParameters - See EmailAttachmentParameters
//  Form - ClientApplicationForm
//
Procedure OpenAttachmentEmail(MailMessage, OpeningParameters, Form) Export
	
	ClearMessages();
	FormParameters = New Structure;
	FormParameters.Insert("MailMessage",                       MailMessage);
	FormParameters.Insert("DoNotCallPrintCommand",      OpeningParameters.DoNotCallPrintCommand);
	FormParameters.Insert("UserAccountUsername", OpeningParameters.UserAccountUsername);
	FormParameters.Insert("DisplayEmailAttachments",     OpeningParameters.DisplayEmailAttachments);
	FormParameters.Insert("BaseEmailDate",          OpeningParameters.BaseEmailDate);
	FormParameters.Insert("EmailBasis",              OpeningParameters.EmailBasis);
	FormParameters.Insert("BaseEmailSubject",          OpeningParameters.BaseEmailSubject);
	
	OpenForm("DocumentJournal.Interactions.Form.PrintEmail", FormParameters, Form);
	
EndProcedure

// Returns:
//   Structure:
//     * BaseEmailDate          - Date - Date of the base email message.
//     * UserAccountUsername - String - Name of the user whose email account received the base email message.
//     * DoNotCallPrintCommand      - Boolean - indicates that it is not required to call OS print command when opening
//                                               a form.
//     * EmailBasis              - Undefined
//                                    - String
//                                    - DocumentRef.IncomingEmail
//                                    - DocumentRef.OutgoingEmail - Reference to the base email message
//                                                                                  or the message presentation.
//     * BaseEmailSubject          - String - a base email subject.
//
Function EmailAttachmentParameters() Export

	OpeningParameters = New Structure;
	OpeningParameters.Insert("BaseEmailDate", Date(1, 1, 1));
	OpeningParameters.Insert("UserAccountUsername", "");
	OpeningParameters.Insert("DoNotCallPrintCommand", True);
	OpeningParameters.Insert("DisplayEmailAttachments", True);
	OpeningParameters.Insert("EmailBasis", Undefined);
	OpeningParameters.Insert("BaseEmailSubject", "");
	
	Return OpeningParameters;

EndFunction 

Procedure URLProcessing(Item, FormattedStringURL, StandardProcessing) Export

	If FormattedStringURL = "EnableReceivingAndSendingEmails" Then
		StandardProcessing = False;
		InteractionsServerCall.EnableSendingAndReceivingEmails();
		Item.Parent.Visible = False;
	ElsIf FormattedStringURL = "GoToScheduledJobsSetup" Then
		If CommonClient.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
			ModuleScheduledJobsClient = CommonClient.CommonModule("ScheduledJobsClient");
			ModuleScheduledJobsClient.GoToScheduledJobsSetup();
			StandardProcessing = False;
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Define the reference type.

// Parameters:
//  ObjectRef - AnyRef - a reference, to which a check is required.
//
// Returns:
//   Boolean   - True if the passed reference refers to an interaction document.
//
Function IsEmail(ObjectRef) Export
	
	Return TypeOf(ObjectRef) = Type("DocumentRef.IncomingEmail")
		Or TypeOf(ObjectRef) = Type("DocumentRef.OutgoingEmail");
	
EndFunction

#EndRegion
