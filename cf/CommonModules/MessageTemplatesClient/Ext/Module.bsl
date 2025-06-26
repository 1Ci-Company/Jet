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


// Opens the template selection window for generating an email or a text message from template
// for the subject passed in the MessageSubject parameter.
//
// Parameters:
//  MessageSubject            - DefinedType.MessageTemplateSubject
//                              - String - a source object of data entered in the message.
//                                For common templates, pass the Common value.
//                                To pass a message subject as a string, specify a full metadata name.
//                                For example, "Catalog.Counterparties".
//  MessageKind                - String - Email for emails and SMSMessage for text messages.
//  OnCloseNotifyDescription - NotifyDescription - a notification that is called once a message is generated. Contains:
//     * Result - Boolean - if True, a message was created.
//     * MessageParameters - Structure
//                          - Undefined - a value that was passed in the MessageParameters parameter. 
//  TemplateOwner             - DefinedType.MessageTemplateOwner - an owner of templates. If it is not specified, all available templates are displayed in the template selection
//                                              window for the
//                                              specified MessageSubject subject.
//  MessageParameters          - Structure -  additional information to generate a message 
//                                             that is passed to the MessageParameters property of the TemplateParameters parameter
//                                             of the MessagesTemplatesOverridable.OnGenerateMessage procedure. 
//
Procedure GenerateMessage(MessageSubject, MessageKind, OnCloseNotifyDescription = Undefined, 
	TemplateOwner = Undefined, MessageParameters = Undefined) Export
	
	FormParameters = MessageFormParameters(MessageSubject, MessageKind, TemplateOwner, MessageParameters);
	ShowGenerateMessageForm(OnCloseNotifyDescription, FormParameters);
	
EndProcedure

// Opens a form to select a template.
//
// Parameters:
//  Notification - NotifyDescription - a notification to be called after a template is selected.:
//      * Result - CatalogRef.MessageTemplates - a selected template.
//      * AdditionalParameters - Structure - a value that was specified on creating the NotifyDescription object.
//  MessageKind                - String - Email for emails and SMSMessage for text messages.
//  TemplateSubject   - AnyRef
//                   - String - a reference to an object that is a subject, or its full name.
//  TemplateOwner  - DefinedType.MessageTemplateOwner - an owner of templates. If it is not specified, all available templates are displayed
//                                              in the template selection window for the specified MessageSubject subject.
//
Procedure SelectTemplate(Notification, MessageKind = "MailMessage", TemplateSubject = Undefined, TemplateOwner = Undefined) Export
	
	If TemplateSubject = Undefined Then
		TemplateSubject = "Shared";
	EndIf;
	
	FormParameters = MessageFormParameters(TemplateSubject, MessageKind, TemplateOwner, Undefined);
	FormParameters.Insert("ChoiceMode", True);
	
	ShowGenerateMessageForm(Notification, FormParameters);
	
EndProcedure

// Shows a message template form.
//
// Parameters:
//  Value - CatalogRef.MessageTemplates
//           - Structure
//           - AnyRef - If a reference to a template is passed,
 //                    this template opens.
 //                    If a structure is passed, a new template filled with the data from the structure opens.
//                     For field details, See MessageTemplatesClientServer.TemplateParametersDetails.
//                     . If a reference from the "DefinedType.MessageTemplateOwner" type collection is passed,
//                     a template for a given owner opens.
//  OpeningParameters - Structure - form opening parameters.:
//    * Owner - Arbitrary - a form or another form control.
//    * Uniqueness - Arbitrary - a key whose value will be used to search for already opened forms.
//    * URL - String - sets a URL returned by the form.
//    * OnCloseNotifyDescription - NotifyDescription - contains details of the procedure to be called after
//                                                         the form is closed.
//    * WindowOpeningMode - FormWindowOpeningMode - Form window open mode.
//
Procedure ShowTemplateForm(Value, OpeningParameters = Undefined) Export
	
	FormOpenParameters = FormParameters(OpeningParameters);
	
	FormParameters = New Structure;
	If TypeOf(Value) = Type("Structure") Then
		FormParameters.Insert("Basis", Value);
		FormParameters.Insert("TemplateOwner", Value.TemplateOwner);
	ElsIf TypeOf(Value) = Type("CatalogRef.MessageTemplates") Then
		FormParameters.Insert("Key", Value);
	Else
		FormParameters.Insert("TemplateOwner", Value);
		FormParameters.Insert("Key", Value);
	EndIf;

	OpenForm("Catalog.MessageTemplates.ObjectForm", FormParameters, FormOpenParameters.Owner,
		FormOpenParameters.Uniqueness,, FormOpenParameters.URL,
		FormOpenParameters.OnCloseNotifyDescription, FormOpenParameters.WindowOpeningMode);
EndProcedure

// Returns opening parameters of a message template form.
//
// Parameters:
//  FillingData - Arbitrary - a value used for filling.
//                                    The value of this parameter cannot be of the following types:
//                                    Undefined, Null, Number, String, Date, Boolean, and Date.
// 
// Returns:
//  Structure - List of form open parameters.:
//   * Owner - Arbitrary - a form or another form control.
//   * Uniqueness - Arbitrary - a key whose value will be used to search for already opened forms.
//   * URL - String - sets a URL returned by the form.
//   * OnCloseNotifyDescription - NotifyDescription - contains details of the procedure to be called after
//                                                       the form is closed.
//   * WindowOpeningMode - FormWindowOpeningMode - Form window open mode.
//
Function FormParameters(FillingData) Export
	OpeningParameters = New Structure();
	OpeningParameters.Insert("Owner", Undefined);
	OpeningParameters.Insert("Uniqueness", Undefined);
	OpeningParameters.Insert("URL", Undefined);
	OpeningParameters.Insert("OnCloseNotifyDescription", Undefined);
	OpeningParameters.Insert("WindowOpeningMode", Undefined);
	
	If FillingData <> Undefined Then
		FillPropertyValues(OpeningParameters, FillingData);
	EndIf;
	
	Return OpeningParameters;
	
EndFunction

#EndRegion

#Region Internal

// Opens a template selection window to generate an email or a text message on the specified subject
// MessageSubject and returns a generated template.
//
// Parameters:
//  MessageSubject            - AnyRef
//                              - String - a source object of data entered in the message.
//                                For common templates, pass the Common value.
//  MessageKind                - String - Email for emails and SMSMessage for text messages.
//  OnCloseNotifyDescription - NotifyDescription - a notification that is called once a message is generated.:
//     * Result - Structure - if True, a message was created.
//     * MessageParameters - Structure
//                          - Undefined - a value that was passed in the MessageParameters parameter. 
//  TemplateOwner         - DefinedType.MessageTemplateOwner - an owner of templates. If it is not specified, all available templates are displayed
//                            in the template selection window for the specified MessageSubject subject.
//  MessageParameters     - Structure -  additional information to generate a message 
//                                        that is passed to the MessageParameters property of the TemplateParameters parameter
//                                        of the MessagesTemplatesOverridable.OnGenerateMessage procedure. 
//
Procedure PrepareMessageFromTemplate(MessageSubject, MessageKind, OnCloseNotifyDescription = Undefined, 
	TemplateOwner = Undefined, MessageParameters = Undefined) Export
	
	FormParameters = MessageFormParameters(MessageSubject, MessageKind, TemplateOwner, MessageParameters);
	FormParameters.Insert("PrepareTemplate", True);
	
	ShowGenerateMessageForm(OnCloseNotifyDescription, FormParameters);
	
EndProcedure

Procedure SendMail(Ref, Parameters) Export
	AdditionalParameters = New Structure("MessageSourceFormName", "");
	AdditionalParameters.MessageSourceFormName = Parameters.Form.FormName;
	
	GenerateMessage(Ref, "MailMessage",,, AdditionalParameters);
EndProcedure

Procedure SendSMS(Ref, Parameters) Export
	AdditionalParameters = New Structure("MessageSourceFormName", "");
	AdditionalParameters.MessageSourceFormName = Parameters.Form.FormName;
	
	GenerateMessage(Ref, "SMSMessage",,, AdditionalParameters);
EndProcedure
	
#EndRegion

#Region Private

Function MessageFormParameters(TemplateSubject, MessageKind, TemplateOwner, MessageParameters)
	
	FormParameters = New Structure();
	FormParameters.Insert("SubjectOf",            TemplateSubject);
	FormParameters.Insert("MessageKind",       MessageKind);
	FormParameters.Insert("TemplateOwner",    TemplateOwner);
	FormParameters.Insert("MessageParameters", MessageParameters);
	
	Return FormParameters;
	
EndFunction

Procedure ShowGenerateMessageForm(OnCloseNotifyDescription, FormParameters)
	
	AdditionalParameters = New Structure("Notification", OnCloseNotifyDescription);
	Notification = New NotifyDescription("ExecuteClosingNotification", ThisObject, AdditionalParameters);
	OpenForm("Catalog.MessageTemplates.Form.GenerateMessage", FormParameters, ThisObject,,,, Notification);
	
EndProcedure

Procedure ExecuteClosingNotification(Result, AdditionalParameters) Export
	If Result <> Undefined Then 
		ExecuteNotifyProcessing(AdditionalParameters.Notification, Result);
	EndIf;
EndProcedure

#EndRegion


