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

// Creates a message based on a subject from message template.
//
// Parameters:
//  Template                   - CatalogRef.MessageTemplates - a reference to a message template.
//  SubjectOf                  - Arbitrary - a base object for a message template. Object types are listed in
//                                            the MessageTemplateSubject type to define.
//  UUID  - UUID - a form ID required to place attachments into a
//                                             temporary storage upon a client/server call. If a call
//                                            occurs only on the server, any ID can be used.
//  AdditionalParameters  - Structure - A list of additional parameters to be passed to the "Message" parameter
//                                         in "OnCreateMessage" procedures upon creating an email message.:
//      * DCSParametersValues - Structure - Values of the DCS parameters, the set of attributes and their values
//                                            for the template being generated are determined by the DCS mechanisms.
//      * ConvertHTMLForFormattedDocument - Boolean - optional, False by default, determines
//                      whether it is necessary to convert an HTML message text that contains pictures in an email text because of
//                      picture output features in the formatted document.
// 
// Returns:
//  Structure - Message created from a template.:
//    * Subject - String - an email subject.
//    * Text - String - an email text.
//    * Recipient - ValueList - Message recipients. The value contains the email address,
//                                    the presentation contains the recipient name.
//                 - Array of See NewEmailRecipients - If the property "ExtendedRecipientsList" of the procedure 
//                   "OnDefineSettings.MessageTemplatesOverridable" is set to "True".
//    * AdditionalParameters - Structure - message template parameters.
//    * Attachments - ValueTable:
//       ** Presentation - String - an attachment file name.
//       ** AddressInTempStorage - String - a binary data address of an attachment in a temporary storage.
//       ** Encoding - String - an attachment encoding (used if it differs from the message encoding).
//       ** Id - String - optional, an attachment ID, used to store 
//                                   pictures displayed in the email body.
//
Function GenerateMessage(Template, SubjectOf, UUID, AdditionalParameters = Undefined) Export

	SendOptions = GenerateSendOptions(Template, SubjectOf, UUID, AdditionalParameters);
	Return MessageTemplatesInternal.GenerateMessage(SendOptions);

EndFunction

// Sends an email or a text message based on the subject from message template.
//
// Parameters:
//  Template                   - CatalogRef.MessageTemplates - a reference to a message template.
//  SubjectOf                  - Arbitrary - a base object for a message template. Object types are listed in
//                                            the MessageTemplateSubject type to define.
//  UUID  - UUID - a form ID required to place attachments into
//                                                       a temporary storage.
//  AdditionalParameters  - See ParametersForSendingAMessageUsingATemplate
// 
// Returns:
//   See MessageTemplatesInternal.EmailSendingResult
//
Function GenerateMessageAndSend(Template, SubjectOf, UUID,
	AdditionalParameters = Undefined) Export

	SendOptions = GenerateSendOptions(Template, SubjectOf, UUID, AdditionalParameters);
	Return MessageTemplatesInternal.GenerateMessageAndSend(SendOptions);

EndFunction

// Returns the list of the required additional parameters for the GenerateMessageAndSend procedure.
// You can extend the list of parameters to pass through the
// OnCreateMessage procedures within the Message parameter and to subsequently use their values when creating a message.
// 
// Returns:
//  Structure:
//   * ConvertHTMLForFormattedDocument - Boolean - optional, False by default, determines
//                      whether it is necessary to convert an HTML message text that contains pictures in an email text because of
//                      picture output features in the formatted document.
//   * Account - Undefined
//                 - CatalogRef.EmailAccounts - Recipient's email address.
//                       
//   * SendImmediately - Boolean - if False, the email message will be placed in the Outbox folder 
//                                  and sent with other email messages. When sending via Interaction only.
//                                  Default value: False.
//   * DCSParametersValues - Structure - Values of the DCS parameters, the set of attributes and their values
//                                         for the template being generated are determined by the DCS mechanisms.
//
Function ParametersForSendingAMessageUsingATemplate() Export

	AdditionalParameters  = New Structure;

	AdditionalParameters.Insert("ConvertHTMLForFormattedDocument", False);
	AdditionalParameters.Insert("Account", Undefined);
	AdditionalParameters.Insert("SendImmediately", False);
	AdditionalParameters.Insert("DCSParametersValues", New Structure);

	Return AdditionalParameters;

EndFunction

// Fills in a list of message template attributes based on a DCS template.
//
// 	Parameters:
//    Attributes  - ValueTree - an attribute list being filled in.
//    Template      - DataCompositionSchema - a DCS template.
//
Procedure GenerateAttributesListByDCS(Attributes, Template) Export
	
	MessageTemplatesInternal.AttributesByDCS(Attributes, Template);
	
EndProcedure

// Fills in a list of message template attributes based on a DCS template.
//
// Parameters:
//  Attributes        - Map - an attribute list.
//  SubjectOf          - Arbitrary - a reference to a base object for the message template.
//  TemplateParameters - See TemplateParameters.
//
Procedure FillAttributesByDCS(Attributes, SubjectOf, TemplateParameters) Export
	MessageTemplatesInternal.FillAttributesByDCS(Attributes, SubjectOf, TemplateParameters);
EndProcedure

// Create a message template.
//
// Parameters:
//  Description     - String - a template description.
//  TemplateParameters - See MessageTemplates.TemplateParametersDetails
//
// Returns:
//  CatalogRef.MessageTemplates - a reference to the created template.
//
Function CreateTemplate(Description, TemplateParameters) Export

	TemplateParameters.Insert("Description", Description);

	EventLogEventName = NStr("en = 'Create a message template';", Common.DefaultLanguageCode());

	BeginTransaction();
	Try

		Template = Catalogs.MessageTemplates.CreateItem();
		Template.Fill(TemplateParameters);

		If InfobaseUpdate.IsCallFromUpdateHandler() Then
			InfobaseUpdate.WriteData(Template, True);
		Else
			Template.Write();
		EndIf;

		If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then

			ModuleFilesOperations = Common.CommonModule("FilesOperations");

			If TemplateParameters.Attachments <> Undefined Then
				For Each Attachment In TemplateParameters.Attachments Do

					FileName = New File(Attachment.Key);

					AdditionalParameters = New Structure;
					AdditionalParameters.Insert("Description", FileName.BaseName);
					If StrFind(TemplateParameters.Text, FileName.BaseName) > 0 Then
						AdditionalParameters.Insert("EmailFileID", FileName.BaseName);
					EndIf;

					FileAddingOptions = ModuleFilesOperations.FileAddingOptions(AdditionalParameters);
					FileAddingOptions.BaseName = FileName.BaseName;
					If StrLen(FileName.Extension) > 1 Then
						FileAddingOptions.ExtensionWithoutPoint = Mid(FileName.Extension, 2);
					EndIf;
					FileAddingOptions.Author = Users.AuthorizedUser();
					FileAddingOptions.FilesOwner = Template.Ref;

					Try
						ModuleFilesOperations.AppendFile(FileAddingOptions, Attachment.Value);
					Except
						// An exception is thrown when the files are stored in volumes that are unacceptable during writing.
						// If an exception is thrown, create a template without attachments.
						ErrorInfo = ErrorInfo();
						WriteLogEvent(EventLogEventName, EventLogLevel.Error,,,
							ErrorProcessing.DetailErrorDescription(ErrorInfo));
					EndTry;
				EndDo;
			EndIf;

		EndIf;

		CommitTransaction();
	Except
		RollbackTransaction();

		ErrorInfo = ErrorInfo();
		WriteLogEvent(EventLogEventName, EventLogLevel.Error,,,
			ErrorProcessing.DetailErrorDescription(ErrorInfo));

		Raise;
	EndTry;

	Return Template.Ref;

EndFunction

// Returns details of template parameters.
// 
// Returns:
//  Structure:
//   * Description - String - a message template description.
//   * Text        - String - a text of an email template or a text message template.
//   * Subject         - String - an email subject text. For email templates only.
//   * TemplateType   - String - a template type. Options: Email and SMSMessage.
//   * Purpose   - String - a presentation of a message template subject. For example, Sales order.
//   * FullAssignmentTypeName - String - a message template subject. If a full path to a metadata object is specified, the template will have
//                                        all its attributes available as parameters. For example, Document.SalesOrder.
//   * EmailFormat1    - EnumRef.EmailEditingMethods- an HTML email format or a plain text.
//                                         For email templates only.
//   * PackToArchive - Boolean - If True, forms and attachments are archived when sent.
//                                For email templates only.
//   * TransliterateFileNames - Boolean - Names of print forms and files attached to an email will contain 
//                                             only Latin letters and digits to ensure compatibility
//                                             with different operating systems.
//                                             For email templates only.
//   * AttachmentsFormats - ValueList - a list of attachment formats. For email templates only.
//   * Attachments - Map of KeyAndValue:
//      ** Key - String - Full filename. For example, "image.png". The description is the filename without the extension.
//                         Or an image id in the HTML message (without a cid).
//      ** Value - String - Address in a temporary storage that points to binary data.
//   * PrintCommands - Array of String - Print form UUIDs.
//   * TemplateOwner - DefinedType.MessageTemplateOwner - a context template owner.
//   * TemplateByExternalDataProcessor - Boolean - if True, a template is generated by an external data processor.
//   * ExternalDataProcessor - CatalogRef.AdditionalReportsAndDataProcessors - external data processor the template belongs to.
//   * SignatureAndSeal   - Boolean - adds the facsimile signature and seal to the print form. For email
//                                 templates only.
//   * AddAttachedFiles - Boolean - If set to "True", the owner's attachments will be added to the message attachments. 
//                                              
//
Function TemplateParametersDetails() Export

	TemplateParameters = MessageTemplatesClientServer.TemplateParametersDetails();
	TemplateParameters.Delete("ExpandRefAttributes");

	Return TemplateParameters;

EndFunction

// Creates subordinate attributes for a reference attribute in the value tree
//
// Parameters:
//  Name					 - String - a name of a reference attribute, to whose value tree subordinate attributes must be added.
//  Node				 - ValueTreeRowCollection - a node in the value tree that requires creation of child items.
//  AttributesList	 - String - a list of comma separated attributes to add. If specified, only they will be added.
//  ExcludingAttributes	 - String - a list of comma separated attributes to exclude.
//
Procedure ExpandAttribute(Name, Node, AttributesList = "", ExcludingAttributes = "") Export
	MessageTemplatesInternal.ExpandAttribute(Name, Node, AttributesList, ExcludingAttributes);
EndProcedure

// Adds relevant email addresses or phone numbers from the object contact information to the list of recipients.
// Only relevant information gets into the selection of email addresses or phone numbers 
// since there is no point in sending emails or text messages to archival data. 
//
// Parameters:
//  EmailRecipients        - ValueTable - a list of email or text message recipients.
//  MessageSubject        - Arbitrary - a parent object that has attributes containing the contact information.
//  AttributeName            - String - an attribute name in the parent object, from which you need to get email addresses or
//                                     phone numbers.
//  ContactInformationType - EnumRef.ContactInformationTypes - if the type is Address, adds postal
//                                                                          addresses. If the type is Phone, adds phone numbers.
//  SendingOption - String - Messaging options: "Whom" (To), "Copy" (CC), "HiddenCopy" (BCC), and "ReplyTo".
//
Procedure FillRecipients(EmailRecipients, MessageSubject, AttributeName,
	ContactInformationType = Undefined, SendingOption = "Whom") Export

	If TypeOf(MessageSubject) = Type("Structure") Then
		SubjectOf = MessageSubject.SubjectOf;
	Else
		SubjectOf = MessageSubject;
	EndIf;
	ObjectMetadata = SubjectOf.Metadata();

	If ObjectMetadata.Attributes.Find(AttributeName) = Undefined Then
		If Not MessageTemplatesInternal.IsStandardAttribute(ObjectMetadata, AttributeName) Then
			Return;
		EndIf;
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");

		If SubjectOf[AttributeName] = Undefined Then
			Return;
		EndIf;

		If ContactInformationType = Undefined Then
			ContactInformationType = ModuleContactsManager.ContactInformationTypeByDescription(
				"Email");
		EndIf;

		ObjectsOfContactInformation = New Array;
		ObjectsOfContactInformation.Add(SubjectOf[AttributeName]);

		ContactInformation4 = ModuleContactsManager.ObjectsContactInformation(
			ObjectsOfContactInformation, ContactInformationType,, CurrentSessionDate());
		For Each ContactInformationItem In ContactInformation4 Do
			Recipient = EmailRecipients.Add();
			If ContactInformationType = ModuleContactsManager.ContactInformationTypeByDescription(
				"Phone") Then
				Recipient.PhoneNumber = ContactInformationItem.Presentation;
				Recipient.Presentation = String(ContactInformationItem.Object);
				Recipient.Contact       = ObjectsOfContactInformation[0];
			Else
				Recipient.Address           = ContactInformationItem.Presentation;
				Recipient.Presentation   = String(ContactInformationItem.Object);
				Recipient.Contact         = ObjectsOfContactInformation[0];
				Recipient.SendingOption = SendingOption;
			EndIf;

		EndDo;
	EndIf;

EndProcedure

// Toggles the ability to create messages from templates.
//
// Parameters:
//   Value - Boolean - If returns "True", the "Message templates" mechanism is available.
//
Procedure SetUsageOfMessagesTemplates(Value) Export

	Constants.UseMessageTemplates.Set(Value);

EndProcedure

// Checks if "Message templates" mechanism is available.
//
// Returns:
//   Boolean - If returns "True", the "Message templates" mechanism is available.
//
Function MessageTemplatesUsed() Export

	Return GetFunctionalOption("UseMessageTemplates");

EndFunction

// API for external data processors.

// Creates details of the message template parameter table.
//
// Returns:
//   ValueTable   - a generated blank value table.
//
Function ParametersTable() Export

	TemplateParameters = New ValueTable;

	TemplateParameters.Columns.Add("ParameterName", New TypeDescription("String", , New StringQualifiers(50,
		AllowedLength.Variable)));
	TemplateParameters.Columns.Add("TypeDetails", New TypeDescription("TypeDescription"));
	TemplateParameters.Columns.Add("IsPredefinedParameter", New TypeDescription("Boolean"));
	TemplateParameters.Columns.Add("ParameterPresentation", New TypeDescription("String", ,
		New StringQualifiers(150, AllowedLength.Variable)));

	Return TemplateParameters;

EndFunction

// Add a template parameter for an external data processor.
//
// Parameters:
//  ParametersTable - ValueTable - a table with the list of parameters.
//  ParameterName - String - a name of the parameter to be added.
//  TypeDetails - TypeDescription - a parameter type.
//  IsPredefinedParameter - Boolean - if True, the parameter is predefined.
//  ParameterPresentation - String - a parameter presentation.
//
Procedure AddTemplateParameter(ParametersTable, ParameterName, TypeDetails, IsPredefinedParameter,
	ParameterPresentation = "") Export

	NewRow                             = ParametersTable.Add();
	NewRow.ParameterName                = ParameterName;
	NewRow.TypeDetails                = TypeDetails;
	NewRow.IsPredefinedParameter = IsPredefinedParameter;
	NewRow.ParameterPresentation      = ?(IsBlankString(ParameterPresentation), ParameterName,
		ParameterPresentation);

EndProcedure

// Initializes the Recipients structure to fill in possible message recipients.
//
// Returns:
//   Structure  - a created structure.
//
Function InitializeRecipientsStructure() Export

	Return MessageTemplatesClientServer.InitializeRecipientsStructure();

EndFunction

// Initializes the message structure that has to be returned by the external data processor from the template.
//
// Returns:
//   Structure  - a created structure.
//
Function InitializeMessageStructure() Export

	Return MessageTemplatesClientServer.InitializeMessageStructure();

EndFunction

// Returns details of message template parameters according to form data, a reference to a catalog item of the message
// template, or defining a context template by its owner. If the template is not found, a structure will be returned
// with blank message template fields, by filling which you can create a new message template.
//
// Parameters:
//  Template - FormDataStructure
//         - CatalogRef.MessageTemplates
//         - AnyRef - a reference to a message template or an owner of a context template.
//
// Returns:
//   See MessageTemplatesClientServer.TemplateParametersDetails.
//
Function TemplateParameters(Val Template) Export

	SearchByOwner = False;
	If TypeOf(Template) <> Type("FormDataStructure") And TypeOf(Template) <> Type("CatalogRef.MessageTemplates") Then

		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	MessageTemplates.Ref AS Ref
		|FROM
		|	Catalog.MessageTemplates AS MessageTemplates
		|WHERE
		|	MessageTemplates.TemplateOwner = &TemplateOwner";
		Query.SetParameter("TemplateOwner", Template);

		QueryResult = Query.Execute().Select();
		If QueryResult.Next() Then
			Template = QueryResult.Ref;
		Else
			SearchByOwner = True;
		EndIf;
	EndIf;

	Result = MessageTemplatesInternal.TemplateParameters(Template);
	If SearchByOwner Then
		Result.TemplateOwner = Template;
	EndIf;
	Return Result;
EndFunction

// Backward compatibility.

// Inserts message parameter values into a template and generates a message text.
//
// Parameters:
//  StringPattern        - String - a template to which values will be inserted according to the parameter table.
//  ValuesToInsert - Map - mapping that contains parameter keys and values.
//  Prefix             - String - a parameter prefix.
//
// Returns:
//   String - a string, to which template parameter values were inserted.
//
Function InsertParametersInRowAccordingToParametersTable(Val StringPattern, ValuesToInsert, Val Prefix = "") Export
	Return MessageTemplatesInternal.InsertParametersInRowAccordingToParametersTable(StringPattern,
		ValuesToInsert, Prefix);
EndFunction

// Returns mapping of template message text parameters.
//
// Parameters:
//  TemplateParameters - Structure - template information.
//
// Returns:
//  Map - mapping of message text parameters.
//
Function ParametersFromMessageText(TemplateParameters) Export
	Return MessageTemplatesInternal.ParametersFromMessageText(TemplateParameters);
EndFunction

// Fills in common attributes with values from the application.
// After the procedure is executed, the mapping will contain the following values:
//  CurrentDate, SystemTitle, InfobaseInternetAddress, InfobaseLocalAddress,
//   and CurrentUser
//
// Parameters:
//  CommonAttributes - Map of KeyAndValue:
//   * Key - String - a name of a common attribute.
//   * Value - String - the filled attribute value.
//
Procedure FillCommonAttributes(CommonAttributes) Export
	MessageTemplatesInternal.FillCommonAttributes(CommonAttributes);
EndProcedure

// Returns a common attribute node name.
// 
// Returns:
//  String - — a common attribute name of the upper level.
//
Function CommonAttributesNodeName() Export
	Return "CommonAttributes";
EndFunction

#EndRegion

#Region Internal

// Determines whether the passed reference is an item of the "Message templates" catalog.
//
// Parameters:
//  TemplateRef1 - CatalogRef.MessageTemplates - a reference to the "Message templates" catalog item.
// 
// Returns:
//  Boolean - if True, a reference is an item of the "Message templates" catalog.
//
Function IsTemplate1(TemplateRef1) Export
	Return TypeOf(TemplateRef1) = Type("CatalogRef.MessageTemplates");
EndFunction

// See GenerateFromOverridable.OnDefineObjectsWithCreationBasedOnCommands.
Procedure OnDefineObjectsWithCreationBasedOnCommands(Objects) Export

	Objects.Add(Metadata.Catalogs.MessageTemplates);

EndProcedure

// See GenerateFromOverridable.OnAddGenerationCommands.
Procedure OnAddGenerationCommands(Object, GenerationCommands, Parameters, StandardProcessing) Export

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		If Object = Metadata.Documents["OutgoingEmail"] Then
			Catalogs.MessageTemplates.AddGenerateCommand(GenerationCommands);
		EndIf;
	EndIf;

EndProcedure

#EndRegion

#Region Private

// Text message parameters
// 
// Parameters:
//  Template - CatalogRef.MessageTemplates
//  SubjectOf - DefinedType.MessageTemplateSubject
//  UUID - UUID
//  AdditionalParameters - Undefined
//                          - Structure
//
// Returns:
//  Structure:
//    * AdditionalParameters - Structure
//    * UUID - UUID
//    * SubjectOf - DefinedType.MessageTemplateSubject
//    * Template - CatalogRef.MessageTemplates
//
Function GenerateSendOptions(Template, SubjectOf, UUID, AdditionalParameters = Undefined) Export
	
	SendOptions = MessageTemplatesClientServer.SendOptionsConstructor(Template, SubjectOf,
		UUID);

	If TypeOf(SendOptions.SubjectOf) = Type("String") And Common.MetadataObjectByFullName(
		SendOptions.SubjectOf) <> Undefined Then

		SendOptions.SubjectOf = Common.ObjectManagerByFullName(
			SendOptions.SubjectOf).EmptyRef();

	EndIf;

	If TypeOf(AdditionalParameters) = Type("Structure") Then
		SendOptions.AdditionalParameters.MessageParameters = AdditionalParameters;
		
		// If additional parameters are passed, substitute them for the default values.
		For Each Item In AdditionalParameters Do
			If SendOptions.AdditionalParameters.Property(Item.Key) Then
				SendOptions.AdditionalParameters.Insert(Item.Key, Item.Value);
			EndIf;
		EndDo;

	EndIf;

	Return SendOptions;

EndFunction

// Returns:
//  Structure:
//    * Address - String - Recipient's email address.
//    * Presentation - String - Recipient presentation.
//    * ContactInformationSource - DefinedType.MessageTemplateSubject - a contact information owner.
//                                   - Undefined
//
Function NewEmailRecipients() Export

	Result = New Structure;
	Result.Insert("Address", "");
	Result.Insert("Presentation", "");
	Result.Insert("ContactInformationSource", Undefined);

	Return Result;

EndFunction

// Parameters:
//  Attachments - ValueTable
// Returns:
//   ValueTableRow:
//   * Ref - CatalogRef.MessageTemplatesAttachedFiles
//   * Id - String
//   * Presentation - String
//   * SelectedItemsCount - Boolean
//   * PictureIndex - Number
//   * FileType - String
//   * PrintManager
//   * PrintParameters
//   * Status
//   * Name
//   * Attribute
//   * ParameterName - String
//
Function AttachmentsRow(Attachment) Export
	Return Attachment;
EndFunction

#EndRegion