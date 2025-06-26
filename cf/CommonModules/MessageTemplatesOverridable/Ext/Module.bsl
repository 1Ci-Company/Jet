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

// Defines an assignment composition and common attributes in message templates 
//
// Parameters:
//  Settings - Structure:
//    * TemplatesSubjects - ValueTable - contains subject options for templates. Columns:
//         ** Name           - String - a unique assignment name.
//         ** Presentation - String - an option presentation.
//         ** Template         - String - a name of the DCS template if the composition of attributes is defined using DCS.
//         ** DCSParametersValues - Structure - DCS parameter values for the current message template subject.
//    * CommonAttributes - ValueTree - contains details of common attributes available in all templates. Columns:
//         ** Name            - String - a unique name of a common attribute.
//         ** Presentation  - String - a common attribute presentation.
//         ** Type            - Type    - a common attribute type. It is a string by default.
//    * UseArbitraryParameters  - Boolean - indicates whether it is possible to use arbitrary user
//                                                    parameters in message templates.
//    * DCSParametersValues - Structure - common values of DCS parameters for all templates, where the attribute composition
//                                          is defined using DCS.
//    * ExtendedRecipientsList - Boolean - If set to "True", the message recipients can specify a send option
//                                              and the contact in "Business interactions" outbox.
//
Procedure OnDefineSettings(Settings) Export
	
	
	
EndProcedure

// Called when preparing message templates. Overrides the list of attributes and attachments.
//
// Parameters:
//  Attributes - ValueTreeRowCollection - a list of template attributes.:
//    * Name            - String - a unique attribute name.
//    * Presentation  - String - an attribute presentation.
//    * FullPresentation - String - Attribute's extended presentation.
//    * Type            - Type    - an attribute type.
//    * ToolTip      - String - extended attribute information.
//    * ArbitraryParameter - Boolean - Flag indicating that the attribute was added interactively.
//    * Format         - String - a value output format for numbers, dates, strings, and boolean values. 
//                                For example, DLF=D for a date.
//    * Parent - ValueTreeRow, Undefined - Row that contains the given row collection.
//  Attachments - ValueTable - print forms and attachments, where:
//    * Name            - String - a unique attachment name.
//    * Id  - String - an attachment ID.
//    * Presentation  - String - an option presentation.
//    * ToolTip      - String - extended attachment information.
//    * FileType       - String - an attachment type that matches the file extension: pdf, png, jpg, mxl, and so on.
//    * ParameterName   - String - For internal use only.
//    * Attribute       - String - For internal use only.
//    * Status         - String - For internal use only.
//    * PrintManager - String - For internal use only.
//    * PrintParameters - Structure - For internal use only.
//  TemplateAssignment  - String  - a message template assignment. For example, "CustomerNotificationChangeOrder".
//  AdditionalParameters - See MessageTemplates.TemplateParametersDetails
//
Procedure OnPrepareMessageTemplate(Attributes, Attachments, TemplateAssignment, AdditionalParameters) Export
	
	

EndProcedure

// Called when creating a message from a template. Populates values in attributes and attachments.
//
// Parameters:
//  Message - Structure:
//    * AttributesValues - Map of KeyAndValue - List of template's attributes:
//      ** Key     - String - Template's attribute name.
//      ** Value - String - Template's filling value.
//    * CommonAttributesValues - Map of KeyAndValue - List of template's common attributes:
//      ** Key     - String - Template's attribute name.
//      ** Value - String - Template's filling value.
//    * Attachments - Map of KeyAndValue:
//      ** Key     - String - Template's attachment name.
//      ** Value - BinaryData
//                  - String - binary data or an address in a temporary storage of the attachment.
//    * AdditionalParameters - Structure:
//       ** MessageKind - String - The template type: "MailMessage", "SMS", or "Arbitrary".
//       ** DCSParametersValues - Structure - The values of DCS parameters. (The list of parameters is determined by the DCS means).
//       ** SendImmediately - Boolean - If set to "True", the message will be sent immediately after the user finished composing it.
//       ** MessageParameters - Structure - Additional parameters passed in functions "GenerateMessage" or 
//                               "GenerateMessageAndSend" (an API function of the "MessageTemplates" common module).
//       ** Account - CatalogRef.EmailAccounts, Undefined - The account on whose behalf 
//                         the email message will be sent. If empty, the system account is used.
//       ** ArbitraryParameters - Map - Used-added parameters.
//       ** PrintForms - Array - A list of message template print forms.
//       ** ConvertHTMLForFormattedDocument - Boolean - Indicates whether to convert the HTML text of a message containing images. 
//                                                    Intended to address the specifics of displaying images in formatted documents. 
//                                                    
//       ** SettingsForSaving - See PrintManagement.SettingsForSaving.
//  TemplateAssignment - String -  a full name of a message template assignment.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//  TemplateParameters - See MessageTemplates.TemplateParametersDetails
//
Procedure OnCreateMessage(Message, TemplateAssignment, MessageSubject, TemplateParameters) Export
	
	

EndProcedure

// Fills in a list of text message recipients when sending a message generated from template.
//
// Parameters:
//   SMSMessageRecipients - ValueTable:
//     * PhoneNumber - String - a phone number to send a text message to.
//     * Presentation - String - a text message recipient presentation.
//     * Contact       - Arbitrary - a contact that owns the phone number.
//  TemplateAssignment - String - a template assignment ID.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//                   - Structure  - Structure that describes template parameters:
//    * SubjectOf               - AnyRef - a reference to an object that is a data source.
//    * MessageKind - String - a kind of a message being generated: Email or SMSMessage.
//    * ArbitraryParameters - Map - a filled list of arbitrary parameters.
//    * SendImmediately - Boolean - indicates whether to send a text message immediately.
//    * MessageParameters - Structure - additional message parameters.
//
Procedure OnFillRecipientsPhonesInMessage(SMSMessageRecipients, TemplateAssignment, MessageSubject) Export
	
EndProcedure

// Fills in a list of email recipients upon sending a message generated from a template.
//
// Parameters:
//   EmailRecipients - ValueTable - a list of mail recipients.:
//     * SendingOption - String - Messaging options: "Whom" (To), "Copy" (CC), "HiddenCopy" (BCC), and "ReplyTo".
//     * Address           - String - a recipient email address.
//     * Presentation   - String - an email recipient presentation.
//     * Contact         - Arbitrary - a contact that owns the email address.
//  TemplateAssignment - String - a template assignment ID.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//                   - Structure  - Structure that describes template parameters:
//    * SubjectOf               - AnyRef - a reference to an object that is a data source.
//    * MessageKind - String - a kind of a message being generated: Email or SMSMessage.
//    * ArbitraryParameters - Map - a filled list of arbitrary parameters.
//    * SendImmediately - Boolean - a kind of a message being generated: Email or SMSMessage.
//    * MessageParameters - Structure - additional message parameters.
//    * ConvertHTMLForFormattedDocument - Boolean - indicates whether to convert an HTML text
//             of a message that contains pictures in an email text because of specifics of displaying pictures
//             in a formatted document.
//    * Account - CatalogRef.EmailAccounts - an account used to send an email.
//
Procedure OnFillRecipientsEmailsInMessage(EmailRecipients, TemplateAssignment, MessageSubject) Export
	
	
	
EndProcedure

// Initial population of predefined message templates.

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling
// 
// Parameters:
//  Settings - See InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.Settings
//
Procedure OnSetUpInitialItemsFilling(Settings) Export
	
EndProcedure

// See also InfobaseUpdateOverridable.OnInitialItemsFilling
//
// Parameters:
//  LanguagesCodes - See InfobaseUpdateOverridable.OnInitialItemsFilling.LanguagesCodes
//  Items   - See InfobaseUpdateOverridable.OnInitialItemsFilling.Items
//  TabularSections - See InfobaseUpdateOverridable.OnInitialItemsFilling.TabularSections
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items, TabularSections) Export
	
	
	
EndProcedure

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling
//
// Parameters:
//  Object                  - CatalogObject.PerformerRoles - Object to populate.
//  Data                  - ValueTableRow - Object fill data.
//  AdditionalParameters - Structure:
//   * PredefinedData - ValueTable - Data populated in the OnInitialItemsFilling procedure.
//
Procedure OnInitialItemFilling(Object, Data, AdditionalParameters) Export
	
	
	
EndProcedure

#EndRegion

