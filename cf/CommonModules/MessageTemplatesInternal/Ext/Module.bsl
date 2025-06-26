///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

// Creating a message from template
// Parameters:
//  SendOptions - Structure:
//    * AdditionalParameters - Structure
//
// Returns:
//   Structure:
//   * Attachments - ValueTable:
//     ** Presentation - String
//     ** AddressInTempStorage - String
//     ** Encoding - String
//     ** Id - String
//   * UserMessages - FixedArray
//   * AdditionalParameters - Structure:
//     ** Sender - String
//   * Recipient - Undefined
//   * Text - String
//   * Subject - String
//
Function GenerateMessage(SendOptions) Export
	
	If SendOptions.Template = Catalogs.MessageTemplates.EmptyRef() Then
		Return MessageWithoutTemplate(SendOptions);
	EndIf;
	
	TemplateParameters = TemplateParameters(SendOptions.Template);
	If SendOptions.AdditionalParameters.Property("MessageParameters") Then
		TemplateParameters.MessageParameters = SendOptions.AdditionalParameters.MessageParameters;
	EndIf;
	
	If ValueIsFilled(SendOptions.AdditionalParameters.DCSParametersValues) Then
		CommonClientServer.SupplementStructure(TemplateParameters.DCSParameters,
			SendOptions.AdditionalParameters.DCSParametersValues, True);
	EndIf;
	
	If SendOptions.Template = Undefined Then
		If SendOptions.Property("AdditionalParameters")
			And SendOptions.AdditionalParameters.Property("MessageKind") Then
			TemplateParameters.TemplateType = SendOptions.AdditionalParameters.MessageKind;
		EndIf;
	Else
		TemplatePurposes = Common.ObjectAttributesValues(
			SendOptions.Template, "ForSMSMessages, ForEmails");
		If TemplatePurposes.ForSMSMessages Then
			SendOptions.AdditionalParameters.Insert("MessageKind", "SMSMessage");
		ElsIf TemplatePurposes.ForEmails Then
			SendOptions.AdditionalParameters.Insert("MessageKind", "Email");
		Else
			SendOptions.AdditionalParameters.Insert("MessageKind", "Arbitrary");
		EndIf;
	EndIf;
	
	ObjectManager = Undefined;
	TemplateInfo = Undefined;
	If SendOptions.SubjectOf <> Undefined Then
		TemplateInfo = TemplateInfo(TemplateParameters);
		TemplateParameters.Insert("SubjectOf", SendOptions.SubjectOf);
	EndIf;
	If ValueIsFilled(TemplateParameters.FullAssignmentTypeName) Then
		ObjectMetadata = Common.MetadataObjectByFullName(TemplateParameters.FullAssignmentTypeName);
		If ObjectMetadata <> Undefined Then
			ObjectManager = Common.ObjectManagerByFullName(TemplateParameters.FullAssignmentTypeName);
		EndIf;
	EndIf;
	
	GeneratedMessage = MessageConstructor(TemplateParameters);
	If TemplateParameters = Undefined Then
		Return GeneratedMessage;
	EndIf;
	
	If TemplateParameters.TemplateByExternalDataProcessor Then
		Return GenerateMesageByExternalDataProcessor(TemplateParameters, TemplateInfo, SendOptions);
	EndIf;
	
	// Extracting parameters from the template
	MessageTextParameters = ParametersFromMessageText(TemplateParameters);
	
	// Populate parameters.
	Message = FillMessageParameters(TemplateParameters, MessageTextParameters, SendOptions);
	Message.AdditionalParameters = SendOptions.AdditionalParameters;
	
	// Attachments.
	If TemplateParameters.TemplateType = "MailMessage" And TemplateInfo <> Undefined Then
		AddSelectedPrintFormsToAttachments(SendOptions, TemplateInfo, Message.Attachments, TemplateParameters);
	EndIf;
	AddAttachedFilesToAttachments(SendOptions, Message);
	
	MessageTemplatesOverridable.OnCreateMessage(Message, TemplateParameters.FullAssignmentTypeName, SendOptions.SubjectOf, TemplateParameters);
	If ObjectManager <> Undefined Then
		ObjectManager.OnCreateMessage(Message, SendOptions.SubjectOf, TemplateParameters);
	EndIf;
	
	// Filling in parameter values
	MessageResult = SetAttributesValuesToMessageText(TemplateParameters, MessageTextParameters, SendOptions.SubjectOf);
	
	GeneratedMessage.Subject  = MessageResult.Subject;
	GeneratedMessage.Text = MessageResult.Text;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
	
	If TemplateParameters.AddAttachedFiles Then
			
			OwnerFiles = New Array;
			ModuleFilesOperations.FillFilesAttachedToObject(SendOptions.SubjectOf, OwnerFiles);
			For Each OwnerFile In OwnerFiles Do
				
				ModuleFilesOperationsClientServer = Common.CommonModule("FilesOperationsClientServer");
				FileDataParameters = ModuleFilesOperationsClientServer.FileDataParameters();
				FileDataParameters.RaiseException1 = False;
				FileData = ModuleFilesOperations.FileData(OwnerFile, FileDataParameters);
				
				If FileData = Undefined Or FileData.Count() = 0 Then
					Continue;
				EndIf;
				
				NewAttachment = GeneratedMessage.Attachments.Add();
				NewAttachment.AddressInTempStorage = FileData.RefToBinaryFileData;
				NewAttachment.Presentation =?(TemplateParameters.TransliterateFileNames,
					 StringFunctions.LatinString(FileData.FileName), FileData.FileName);
				
			EndDo;
			
		EndIf;
	
	EndIf;
	
	For Each Attachment In Message.Attachments Do
		NewAttachment = GeneratedMessage.Attachments.Add();
		If TemplateParameters.TransliterateFileNames Then
			NewAttachment.Presentation = StringFunctions.LatinString(Attachment.Key);
		Else
			NewAttachment.Presentation = Attachment.Key;
		EndIf;
		NewAttachment.AddressInTempStorage = Attachment.Value;
	EndDo;
	
	If TemplateParameters.TemplateType = "MailMessage" And TemplateParameters.EmailFormat1 = Enums.EmailEditingMethods.HTML Then
		ProcessHTMLForFormattedDocument(SendOptions, GeneratedMessage, SendOptions.AdditionalParameters.ConvertHTMLForFormattedDocument);
	EndIf;
	
	If TemplateParameters.TemplateType <> "Arbitrary" Then
		FillMessageRecipients(SendOptions, TemplateParameters, GeneratedMessage, ObjectManager);
	EndIf;
	
	GeneratedMessage.UserMessages = GetUserMessages(True);
	
	Return GeneratedMessage;
	
EndFunction

// Generate a message and send it immediately.
// 
// Parameters:
//   SendOptions - Structure:
//   * AdditionalParameters - Structure
//
// Returns:
//    See EmailSendingResult
// 
Function GenerateMessageAndSend(SendOptions) Export
	
	Result = EmailSendingResult();
	
	Message = GenerateMessage(SendOptions);
	
	If SendOptions.Template.ForSMSMessages Then
		If Message.Recipient.Count() = 0 Then
			Result.ErrorDescription  = NStr("en = 'To send the message, enter recipient phone numbers.';");
			Return Result;
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.SendSMSMessage") Then
			ModuleSMS = Common.CommonModule("SendSMSMessage");
			If ModuleSMS.CanSendSMSMessage() Then
				
				If Common.SubsystemExists("StandardSubsystems.Interactions") Then
					
					ModuleInteractions = Common.CommonModule("Interactions");
					If ModuleInteractions.AreOtherInteractionsUsed() Then
						
						ModuleInteractions.CreateAndSendSMSMessage(Message);
						Result.Sent = True;
						Return Result;
						
					EndIf;
				EndIf;
				
				RecipientsNumbers = New Array;
				For Each Recipient In Message.Recipient Do
					If TypeOf(Recipient) = Type("Structure") Then
						RecipientsNumbers.Add(Recipient.PhoneNumber);
					Else
						RecipientsNumbers.Add(Recipient.Value);
					EndIf;
				EndDo;
				
				SMSMessageSendingResult = ModuleSMS.SendSMS(RecipientsNumbers, Message.Text, Message.AdditionalParameters.Sender, Message.AdditionalParameters.Transliterate);
				Result.Sent = IsBlankString(SMSMessageSendingResult.ErrorDescription);
				Result.ErrorDescription = SMSMessageSendingResult.ErrorDescription;
				
			Else
				
				Result.ErrorDescription = NStr("en = 'Cannot send the text message right away.';");
				
			EndIf;
			
			Return Result;
			
		EndIf;
		
	ElsIf SendOptions.Template.ForEmails Then
		If Message.Recipient.Count() = 0 Then
			Result.ErrorDescription  = NStr("en = 'Enter an email address to send the message right away.';");
			Return Result;
		EndIf;
		
		EmailParameters = New Structure();
		EmailParameters.Insert("Subject",      Message.Subject);
		EmailParameters.Insert("Body",      Message.Text);
		EmailParameters.Insert("Attachments",  New Map);
		EmailParameters.Insert("Encoding", "utf-8");
		
		For Each Attachment In Message.Attachments Do
			NewAttachment = New Structure("BinaryData, Id");
			NewAttachment.BinaryData = GetFromTempStorage(Attachment.AddressInTempStorage);
			NewAttachment.Id = Attachment.Id;
			EmailParameters.Attachments.Insert(Attachment.Presentation, NewAttachment);
		EndDo;
		
		If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
			ModuleEmailOperationsInternal = Common.CommonModule("EmailOperationsInternal");
			If Message.AdditionalParameters.EmailFormat1 = Enums.EmailEditingMethods.HTML Then
				TextType = ModuleEmailOperationsInternal.EmailTextsType("HTMLWithPictures");
			Else
				TextType = ModuleEmailOperationsInternal.EmailTextsType("PlainText");
			EndIf;
		Else
			TextType = "";
		EndIf;
		
		EmailParameters.Insert("TextType", TextType);
		Whom = GenerateMessageRecipientsList(Message.Recipient);
		
		EmailParameters.Insert("Whom", Whom);
		
		If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
			ModuleEmailOperations = Common.CommonModule("EmailOperations");
			If ModuleEmailOperations.CanSendEmails() Then
				
				If SendOptions.AdditionalParameters.Account = Undefined Then
					Account = ModuleEmailOperations.SystemAccount();
				Else
					Account = SendOptions.AdditionalParameters.Account;
				EndIf;
				
				If Common.SubsystemExists("StandardSubsystems.Interactions") Then
					
					ModuleInteractions = Common.CommonModule("Interactions");
					If ModuleInteractions.EmailClientUsed() Then
						
						EmailParameters = ModuleInteractions.EmailParameters();
						FillPropertyValues(EmailParameters, Message, , "AdditionalParameters");
						
						RecipientsListAsValueList =(TypeOf(Message.Recipient) = Type("ValueList"));
						For Each EmailRecipient In Message.Recipient Do
							NewRow = EmailParameters.Recipients.Add();
							If RecipientsListAsValueList Then
								NewRow.Address         = EmailRecipient.Value;
								NewRow.Presentation = EmailRecipient.Presentation;
							Else
								NewRow.Address         = EmailRecipient.Address;
								NewRow.Presentation = EmailRecipient.Presentation;
								NewRow.ContactInformationSource = EmailRecipient.ContactInformationSource;
							EndIf;
						EndDo;
						
						FillPropertyValues(EmailParameters.AdditionalParameters, Message.AdditionalParameters);
						EmailParameters.AdditionalParameters.Comment = CommentByTemplateDescription(Message.AdditionalParameters.Description);
						
						SendingResult = ModuleInteractions.CreateEmail(EmailParameters, Account, SendOptions.AdditionalParameters.SendImmediately);
						FillPropertyValues(Result, SendingResult);
						Return Result;
						
					EndIf;
					
				EndIf;
				
				MailMessage = ModuleEmailOperations.PrepareEmail(Account, EmailParameters);
				ModuleEmailOperations.SendMail(Account, MailMessage);
				
				Result.Sent = True;
				
			Else
				
				Result.ErrorDescription  = NStr("en = 'Cannot send the message right away.';");
				Return Result;
				
			EndIf;
		EndIf
		
	EndIf;
	
	Return Result;
	
EndFunction

Function HasAvailableTemplates(TemplateType, SubjectOf = Undefined) Export
	
	If Not HasRightToReadMessageTemplates() Then
		Return False;
	EndIf;
	
	Query = PrepareQueryToGetTemplatesList(TemplateType, SubjectOf);
	Return Not Query.Execute().IsEmpty();
EndFunction


// Returns a list of metadata objects the "Message templates" subsystem is attached to.
//
// Returns:
//  Array - a list of items of the MetadataObject type.
//
Function MessageTemplatesSources() Export
	
	TypesOrMetadataArray = Metadata.DefinedTypes.MessageTemplateSubject.Type.Types();
	
	MetadataObjectsIDsTypeIndex = TypesOrMetadataArray.Find(Type("CatalogRef.MetadataObjectIDs"));
	If MetadataObjectsIDsTypeIndex <> Undefined Then
		TypesOrMetadataArray.Delete(MetadataObjectsIDsTypeIndex);
	EndIf;
	
	Return TypesOrMetadataArray;
	
EndFunction

Function MessageTemplatesUsed() Export
	Return GetFunctionalOption("UseMessageTemplates");
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "3.0.1.35";
	Handler.Procedure = "MessageTemplatesInternal.AddAddEditPersonalTemplatesRoleToBasicRightsProfiles";
	Handler.ExecutionMode = "Seamless";
	
	ObjectsToRead = New Array;
	ObjectsToRead.Add("Catalog.MessageTemplates");
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ObjectsToRead.Add(Metadata.Catalogs["ContactInformationKinds"].FullName());
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ObjectsToRead.Add(Metadata.Catalogs["AdditionalReportsAndDataProcessors"].FullName());
	EndIf;
	
	Handler = Handlers.Add();
	Handler.Version          = "3.1.3.156";
	Handler.Id   = New UUID("9fa8ac0b-1d3c-4584-8d32-bb46720e9d67");
	Handler.Procedure       = "Catalogs.MessageTemplates.ProcessDataForMigrationToNewVersion";
	Handler.ExecutionMode = "Deferred";
	Handler.UpdateDataFillingProcedure = "Catalogs.MessageTemplates.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ObjectsToRead    = StrConcat(ObjectsToRead, ",");
	Handler.ObjectsToChange  = "Catalog.MessageTemplates";
	Handler.ObjectsToLock = "Catalog.MessageTemplates";
	Handler.CheckProcedure  = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Comment = NStr("en = 'Updating message templates…
		|Until it is completed, you cannot compose email and text messages from templates.';");
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = "Catalogs.ContactInformationKinds.ProcessDataForMigrationToNewVersion";
		Priority.Order = "After";
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		
		If Handler.ExecutionPriorities = Undefined Then
			Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
		EndIf;
		
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = "NationalLanguageSupportServer.ProcessDataForMigrationToNewVersion";
		Priority.Order = "Before";
	EndIf; 
	
	Handler = Handlers.Add();
	Handler.Procedure = "MessageTemplatesInternal.ProcessDataForMigrationToAttachableCommands";
	Handler.Version = "3.1.10.99";
	Handler.ExecutionMode = "Seamless";
	Handler.InitialFilling = True;
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction.
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.MessageTemplates, True);
	Lists.Insert(Metadata.Catalogs.MessageTemplatesAttachedFiles, True);
	
EndProcedure

// See AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionKinds.
Procedure OnFillMetadataObjectsAccessRestrictionKinds(LongDesc) Export
	
	LongDesc = LongDesc + "
	|Catalog.MessageTemplates.Read.Users
	|Catalog.MessageTemplates.Update.Users
	|";
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		LongDesc = LongDesc + "
			|Catalog.MessageTemplatesAttachedFiles.Read.Users
			|Catalog.MessageTemplatesAttachedFiles.Update.Users
			|";
	EndIf;
	
EndProcedure

// See also InfobaseUpdateOverridable.OnDefineSettings
//
// Parameters:
//  Objects - Array of MetadataObject
//
Procedure OnDefineObjectsWithInitialFilling(Objects) Export
	
	Objects.Add(Metadata.Catalogs.MessageTemplates);
	
EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject.
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	
	If Not HasRightToReadMessageTemplates() Then
		Return;
	EndIf;
	
	AvailableOptions = MessageTemplatesAvailableSendOutOptions();
	
	If AvailableOptions.Mail Then
		Command = Commands.Add();
		Command.Kind = "Send";
		Command.Presentation = NStr("en = 'Email';");
		Command.Picture = PictureLib.SendEmail;
		Command.WriteMode = "NotWrite";
		Command.Order = 40;
		Command.ParameterType = Metadata.DefinedTypes.MessageTemplateSubject.Type;
		Command.Handler = "MessageTemplatesClient.SendMail";
		Command.MultipleChoice = False;
	EndIf;
	
	If AvailableOptions.SMS Then
		Command = Commands.Add();
		Command.Kind = "Send";
		Command.Presentation = NStr("en = 'SMS';");
		Command.WriteMode = "NotWrite";
		Command.Order = 50;
		Command.ParameterType = Metadata.DefinedTypes.MessageTemplateSubject.Type;
		Command.Handler = "MessageTemplatesClient.SendSMS";
		Command.MultipleChoice = False;
	EndIf;
		
EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableObjectsSettingsComposition
Procedure OnDefineAttachableObjectsSettingsComposition(InterfaceSettings4) Export
	Setting = InterfaceSettings4.Add();
	Setting.Key          = "AddSendingCommands";
	Setting.TypeDescription = New TypeDescription("Boolean");
EndProcedure

#EndRegion

#Region Private

// Returns information records about the available message sending options.
// 
// Returns:
//  FixedStructure:
//   * SMS - Boolean - If set to "True", users can create text messages from templates.
//   * Mail - Boolean - If set to "True", users can create email messages from templates.
//
Function MessageTemplatesAvailableSendOutOptions() Export
	
	Return MessageTemplatesInternalCached.MessageTemplatesAvailableSendOutOptions();
	
EndFunction 


// Returns information on the created outgoing email. 
//
// Returns:
//  Structure:
//   * Sent - Boolean - indicates whether the email message is sent.
//   * ErrorDescription - String - contains the error details when failed to send an email message.
//   * LinkToTheEmail - Undefined - an outgoing email was not created.
//                    - DocumentRef.OutgoingEmail - Reference to the created outgoing email.
//
Function EmailSendingResult() Export
	
	EmailSendingResult = New Structure;
	
	EmailSendingResult.Insert("Sent", False);
	EmailSendingResult.Insert("ErrorDescription", "");
	EmailSendingResult.Insert("LinkToTheEmail", Undefined);
	
	Return EmailSendingResult;
	
EndFunction

Function TemplateByOwner(TemplateOwner) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	MessageTemplates.Ref AS Ref
		|FROM
		|	Catalog.MessageTemplates AS MessageTemplates
		|WHERE
		|	MessageTemplates.TemplateOwner = &TemplateOwner";
	
	Query.SetParameter("TemplateOwner", TemplateOwner);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Return QueryResult.Unload()[0].Ref;
	Else
		Return Catalogs.MessageTemplates.EmptyRef();
	EndIf;
	
EndFunction

// A function creating message parameters.
// 
// Parameters:
//  TemplateParameters - Structure
//                   - Undefined
// 
// Returns:
//  Structure:
//    * Subject - String
//    * Text - String
//    * Recipient - ValueList
//    * Attachments - ValueTable:
//      ** Presentation - String
//      ** AddressInTempStorage - String
//      ** Encoding - String
//      ** Id - String
//   * UserMessages - FixedArray
//   * AdditionalParameters - Undefined
//                             - Structure
//
Function MessageConstructor(TemplateParameters = Undefined) Export
	
	Message = New Structure();
	Message.Insert("Subject",       "");
	Message.Insert("Text",      "");
	Message.Insert("Recipient", New ValueList);
	Message.Insert("AdditionalParameters",
		?(TemplateParameters <> Undefined, TemplateParameters, New Structure()));
	Message.Insert("UserMessages", New FixedArray(New Array()));
	
	StringType = New TypeDescription("String");
	Attachments = New ValueTable;
	Attachments.Columns.Add("Presentation",             StringType);
	Attachments.Columns.Add("AddressInTempStorage", StringType);
	Attachments.Columns.Add("Encoding",                 StringType);
	Attachments.Columns.Add("Id",             StringType);
	
	Message.Insert("Attachments", Attachments);
	
	If TemplateParameters <> Undefined Then
		FillPropertyValues(Message, TemplateParameters,, "Attachments");
	
		For Each Attachment In TemplateParameters.Attachments Do
			
			NewAttachment = Attachments.Add();
			NewAttachment.Presentation             = Attachment.Key;
			NewAttachment.AddressInTempStorage = Attachment.Value;
			
		EndDo;
		
	EndIf;
	
	Return Message;
EndFunction

// Returns:
//   See TemplateInfoConstructor
//
Function TemplateInfo(TemplateParameters) Export
	
	TemplateInfo = TemplateInfoConstructor();
	
	CommonAttributesNodeName = MessageTemplates.CommonAttributesNodeName();
	
	If TypeOf(TemplateInfo.CommonAttributes) = Type("ValueTree") Then
		For Each CommonAttribute In CommonAttributes(TemplateInfo.CommonAttributes).Rows Do
			If Not StrStartsWith(CommonAttribute.Name, CommonAttributesNodeName + ".") Then
				CommonAttribute.Name = CommonAttributesNodeName + "." + CommonAttribute.Name;
			EndIf;
		EndDo;
	Else
		TemplateInfo.CommonAttributes = AttributeTree();
		CommonAttributesTree = DetermineCommonAttributes();
		TemplateInfo.CommonAttributes = CommonAttributes(CommonAttributesTree);
	EndIf;
	
	DefineAttributesAndAttachmentsList(TemplateInfo, TemplateParameters);
	
	GenerateFullPresentations(TemplateInfo.Attributes.Rows);
	GenerateFullPresentations(TemplateInfo.CommonAttributes.Rows);
	
	Return TemplateInfo;
	
EndFunction

// A function creating template information.
// 
// Returns:
//  Structure:
//    * Purpose - String
//    * Attachments - ValueTable:
//       ** Name - String
//       ** Id - String
//       ** Presentation - String
//       ** PrintManager - String
//       ** PrintParameters - Structure
//       ** FileType - String
//       ** Status - String
//       ** Attribute - String
//       ** ParameterName - String
//   * CommonAttributes - ValueTree:
//       ** Name - String
//       ** Presentation - String
//       ** ToolTip - String
//       ** Format - String
//       ** Type - TypeDescription
//       ** ArbitraryParameter - Boolean
//   * Attributes - ValueTree:
//       ** Name - String
//       ** Presentation - String
//       ** ToolTip - String
//       ** Format - String
//       ** Type - TypeDescription
//       ** ArbitraryParameter - Boolean
// 
Function TemplateInfoConstructor()
	
	TemplateInfo = New Structure();
	
	MessageTemplatesSettings = MessageTemplatesInternalCached.OnDefineSettings();
	
	TemplateInfo.Insert("Attributes", AttributeTree());
	TemplateInfo.Insert("CommonAttributes", MessageTemplatesSettings.CommonAttributes);
	TemplateInfo.Insert("Attachments", AttachmentsTable());
	TemplateInfo.Insert("Purpose", "");
	
	Return TemplateInfo;
	
EndFunction

Function ParameterNameWithoutFormatString(Val TemplateParameterFromText) Export
	
	Result = New Structure;
	Result.Insert("Name",   "");
	Result.Insert("Format", "");
	
	PositionFormatText = StrFind(TemplateParameterFromText, "{", SearchDirection.FromEnd);
	If PositionFormatText > 0 Then
		Result.Name = Left(TemplateParameterFromText, PositionFormatText - 1);
		Result.Format = Mid(TemplateParameterFromText, PositionFormatText + 1, StrLen(TemplateParameterFromText) - PositionFormatText - 1);
	Else
		Result.Name = TemplateParameterFromText;
	EndIf;
	
	Return Result;
	
EndFunction

Procedure DefineAttributesAndAttachmentsList(TemplateInfo, TemplateParameters)
	
	If ValueIsFilled(TemplateParameters.FullAssignmentTypeName) Then
		
		// Attributes.
		MetadataObject3 = Common.MetadataObjectByFullName(TemplateParameters.FullAssignmentTypeName);
		RelatedObjectAttributes = RelatedObjectAttributes(TemplateInfo.Attributes, 
			TemplateParameters.FullAssignmentTypeName, TemplateParameters.Purpose);
		ExpandRefAttributes = TemplateParameters.ExpandRefAttributes;
		
		If MetadataObject3 <> Undefined Then
			ObjectManager = Common.ObjectManagerByFullName(MetadataObject3.FullName());
			
			Prefix = MetadataObject3.Name + ".";
			
			If IsBlankString(TemplateParameters.Template) Then
				AttributesByObjectMetadata(RelatedObjectAttributes, MetadataObject3,,, Prefix);
			Else
				DCSTemplate = ObjectManager.GetTemplate(TemplateParameters.Template);
				AttributesByDCS(RelatedObjectAttributes, DCSTemplate, MetadataObject3.Name);
				ExpandRefAttributes = False;
			EndIf;
			
			DefinePrintFormsList(MetadataObject3, TemplateInfo);
			Presentation = MetadataObject3.Presentation();
			ObjectReference = RelatedObjectAttributes.Add();
			ObjectReference.Presentation = NStr("en = 'Ref to';") + " """ + Presentation + """";
			ObjectReference.Name           = Prefix + "ExternalObjectRef";
			ObjectReference.Type  = New TypeDescription("String");
			ObjectReference.FullPresentation = Presentation + "." + NStr("en = 'Ref to';") + " """ + Presentation + """";
			
		Else
			Prefix = TemplateParameters.FullAssignmentTypeName + ".";
			Presentation = TemplateParameters.Purpose;
		EndIf;
		
		MessageTemplatesOverridable.OnPrepareMessageTemplate(RelatedObjectAttributes, TemplateInfo.Attachments, 
			TemplateParameters.FullAssignmentTypeName, TemplateParameters);
		
		If MetadataObject3 <> Undefined Then
			ObjectManager.OnPrepareMessageTemplate(RelatedObjectAttributes, TemplateInfo.Attachments, TemplateParameters);
		EndIf;
		
		For Each RelatedObjectAttribute In RelatedObjectAttributes Do
			If Not StrStartsWith(RelatedObjectAttribute.Name, Prefix) Then
				RelatedObjectAttribute.Name = Prefix + RelatedObjectAttribute.Name;
			EndIf;
			If ExpandRefAttributes Then
				If RelatedObjectAttribute.Type.Types().Count() = 1 Then
					ObjectType = Metadata.FindByType(RelatedObjectAttribute.Type.Types()[0]);
					If ObjectType <> Undefined And StrStartsWith(ObjectType.FullName(), "Catalog") Then
						ExpandAttribute(RelatedObjectAttribute.Name, RelatedObjectAttributes);
					EndIf;
				EndIf;
			EndIf;
		EndDo;
		
	EndIf;
	
	For Each ArbitraryParameter In TemplateParameters.Parameters Do
		
		If ArbitraryParameter.Value.TypeDetails.Types().Count() > 0 Then
			Type = ArbitraryParameter.Value.TypeDetails.Types()[0];
			MetadataObject3 = Metadata.FindByType(Type);
			If MetadataObject3 <> Undefined Then
				ObjectManager = Common.ObjectManagerByFullName(MetadataObject3.FullName());
				If ObjectManager <> Undefined Then
					RelatedObjectAttributes = RelatedObjectAttributes(TemplateInfo.Attributes, ArbitraryParameter.Key);
					RelatedObjectAttributes.Parent.Presentation = ArbitraryParameter.Value.Presentation;
					RelatedObjectAttributes.Parent.Type = ArbitraryParameter.Value.TypeDetails;
					RelatedObjectAttributes.Parent.ArbitraryParameter = True;
					AttributesByObjectMetadata(RelatedObjectAttributes, MetadataObject3,,, MetadataObject3.Name + ".");
				EndIf;
				DefinePrintFormsList(MetadataObject3, TemplateInfo, ArbitraryParameter.Key);
			Else
				Arbitrary_ParametersPresentation = NStr("en = 'Custom';");
				Prefix = "Arbitrary_Parameters";
				RelatedObjectAttributes = RelatedObjectAttributes(TemplateInfo.Attributes, Prefix, Arbitrary_ParametersPresentation);
				NewString1 = RelatedObjectAttributes.Add();
				NewString1.Name = Prefix + "." + ArbitraryParameter.Key;
				NewString1.Presentation = ArbitraryParameter.Value.Presentation;
				NewString1.Type = ArbitraryParameter.Value.TypeDetails;
				NewString1.ArbitraryParameter = True;
			EndIf;
		Else
			Arbitrary_ParametersPresentation = NStr("en = 'Custom';");
			Prefix = "Arbitrary_Parameters";
			RelatedObjectAttributes = RelatedObjectAttributes(TemplateInfo.Attributes, Prefix, Arbitrary_ParametersPresentation);
			NewString1 = RelatedObjectAttributes.Add();
			NewString1.Name = Prefix + "." + ArbitraryParameter.Key;
			NewString1.Presentation = ArbitraryParameter.Value.Presentation;
			NewString1.Type = Common.StringTypeDetails(150);
			NewString1.ArbitraryParameter = True;
		EndIf;
	EndDo;
	
EndProcedure

Function ConvertTemplateText( Val Text, Val ListOfAllParameters, ConversionOption) Export
	
	If ConversionOption = "ParametersInPresentation" Then
		SourceAttributeName  = "Name";
		RecipientAttributeName = "FullPresentation";
	Else
		SourceAttributeName  = "FullPresentation";
		RecipientAttributeName = "Name";
	EndIf;
	
	ParametersInTemplate = MessageTextParameters(Text);
	
	For Each ParameterInTemplate In ParametersInTemplate Do
		
		ParameterDetails = ParameterNameWithoutFormatString(ParameterInTemplate.Key);
		
		FoundRows = ListOfAllParameters.Rows.FindRows(New Structure(SourceAttributeName, ParameterDetails.Name), True);
		If FoundRows.Count() > 0 Then
			
			If IsBlankString(ParameterDetails.Format) Then
				ParametersInTemplate[ParameterInTemplate.Key] = FoundRows[0][RecipientAttributeName];
			Else
				ParametersInTemplate[ParameterInTemplate.Key] = FoundRows[0][RecipientAttributeName] + "{" + ParameterDetails.Format + "}";
				FoundRows[0].Format = ParameterDetails.Format;
			EndIf;
			
		EndIf;
	EndDo;
	
	Return ReplaceParametersInText(Text, ParametersInTemplate);
	
EndFunction

Function ReplaceParametersInText(Val TextToReplace, ParametersSet)
	
	For Each ParameterDetails In ParametersSet Do
		TextToReplace = StrReplace(TextToReplace, "[" + ParameterDetails.Key + "]", "[" + ParameterDetails.Value + "]");
	EndDo;
	
	Return TextToReplace;
	
EndFunction

Procedure GenerateFullPresentations(RelatedObjectAttributes, Presentation = "")
	
	Matches1 = New Map;
	For Each RelatedObjectAttribute In RelatedObjectAttributes Do
		FullPresentation = Presentation + RelatedObjectAttribute.Presentation;
		If RelatedObjectAttribute.Rows.Count() > 0 Then
			GenerateFullPresentations(RelatedObjectAttribute.Rows, FullPresentation + ".");
		EndIf;
		
		If Matches1[FullPresentation] = Undefined Then
			RelatedObjectAttribute.FullPresentation = FullPresentation;
			Matches1.Insert(FullPresentation, RelatedObjectAttribute);
		Else
			For SequenceNumber = 1 To 100 Do
				FullPresentation = StringFunctionsClientServer.SubstituteParametersToString(
					"%1.%2 (%3)", Presentation, RelatedObjectAttribute.Presentation, SequenceNumber);
				If Matches1[FullPresentation] = Undefined Then
					RelatedObjectAttribute.FullPresentation = FullPresentation;
					Matches1.Insert(FullPresentation, RelatedObjectAttribute);
					Break;
				EndIf;
			EndDo;
		EndIf;
		
	EndDo;
	
EndProcedure

Function ObjectIsTemplateSubject(FullAssignmentTypeName) Export
	
	Result = MessageTemplatesInternalCached.OnDefineSettings().TemplatesSubjects.Find(FullAssignmentTypeName, "Name");
	Return Result <> Undefined;
	
EndFunction

Function GenerateMesageByExternalDataProcessor(TemplateParameters, TemplateInfo, SendOptions)
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		
		GeneratedMessage = MessageConstructor(TemplateParameters);
		ExternalObject = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorObject(TemplateParameters.ExternalDataProcessor);
		TemplateParameters = ExternalObject.TemplateParameters();
		
		Values = New Structure;
		For Each TemplateParameter In TemplateParameters Do
			IsArbitraryParameter = True;
			For Each TypeDetails In TemplateParameter.TypeDetails.Types() Do
				If TypeDetails = TypeOf(SendOptions.SubjectOf) Then
					MetadataObject = SendOptions.SubjectOf.Metadata(); // MetadataObject
					Values.Insert(MetadataObject.Name, SendOptions.SubjectOf);
					IsArbitraryParameter = False;
					Break;
				EndIf;
			EndDo;
			If IsArbitraryParameter Then
				Value = SendOptions.AdditionalParameters.ArbitraryParameters[TemplateParameter.ParameterName];
				Values.Insert(TemplateParameter.ParameterName, Value);
			EndIf;
		EndDo;
		
		Message = ExternalObject.GenerateMessageUsingTemplate(Values);
		
		If TypeOf(Message) = Type("Structure") And SendOptions.AdditionalParameters.MessageKind = "SMSMessage" Then
			
			GeneratedMessage.Text = Message.SMSMessageText;
			
		ElsIf TypeOf(Message) = Type("Structure") And SendOptions.AdditionalParameters.MessageKind = "Arbitrary" Then
			
			GeneratedMessage.Text = Message.ArbitraryMessageText;
			
		ElsIf TypeOf(Message) = Type("Structure") And Message.Property("AttachmentsStructure") Then
			
			GeneratedMessage.Text = Message.HTMLEmailText;
			GeneratedMessage.Subject  = Message.EmailSubject;
			
			For Each Attachment In Message.AttachmentsStructure Do
				NewAttachment = GeneratedMessage.Attachments.Add();
				NewAttachment.AddressInTempStorage = PutToTempStorage(Attachment.Value.GetBinaryData(), SendOptions.UUID);
				NewAttachment.Id = Attachment.Key;
				NewAttachment.Presentation = Attachment.Key;
			EndDo;
			
		EndIf;
		
		StandardProcessing = False;
		Recipients = ExternalObject.DataStructureRecipients(Values, StandardProcessing);
		If TypeOf(Recipients) = Type("Array") Then
			
			GeneratedMessage.Recipient = New ValueList;
			
			For Each Recipient In Recipients Do
				GeneratedMessage.Recipient.Add(Recipient.Address, Recipient.Presentation);
			EndDo;
			
		EndIf;
		
		Return GeneratedMessage;
		
	EndIf;
	
EndFunction

Function MessageWithoutTemplate(SendOptions)
	
	TemplateParameters = MessageTemplatesClientServer.TemplateParametersDetails();
	If SendOptions.AdditionalParameters.Property("MessageKind")
		And SendOptions.AdditionalParameters.MessageKind = "SMSMessage" Then
			TemplateParameters.TemplateType = "SMS";
	EndIf;
	
	If SendOptions.AdditionalParameters.Property("ExtendedRecipientsList") Then
		TemplateParameters.ExtendedRecipientsList = SendOptions.AdditionalParameters.ExtendedRecipientsList;
	EndIf;
	
	ObjectManager = Undefined;
	If SendOptions.Property("SubjectOf") And ValueIsFilled(SendOptions.SubjectOf) Then
		ObjectMetadata = Metadata.FindByType(TypeOf(SendOptions.SubjectOf));
		If ObjectMetadata <> Undefined Then
			ObjectManager = Common.ObjectManagerByFullName(ObjectMetadata.FullName());
		EndIf;
	EndIf;
	
	GeneratedMessage = MessageConstructor(TemplateParameters);
	FillMessageRecipients(SendOptions, TemplateParameters, GeneratedMessage, ObjectManager);
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		If TemplateParameters.TemplateType = "MailMessage" And ValueIsFilled(SendOptions.AdditionalParameters.PrintForms) Then
			PrintForms = SendOptions.AdditionalParameters.PrintForms;
			ListOfObjects = CommonClientServer.ValueInArray(SendOptions.SubjectOf);
			SettingsForSaving = SendOptions.AdditionalParameters.SettingsForSaving;
			Files = ModulePrintManager.PrintToFile(PrintForms, ListOfObjects, SettingsForSaving);
			For Each File In Files Do
				Attachment = GeneratedMessage.Attachments.Add();
				Attachment.AddressInTempStorage = PutToTempStorage(File.BinaryData, SendOptions.UUID);
				Attachment.Presentation = File.FileName;
			EndDo;
		EndIf;
	EndIf;
	
	GeneratedMessage.UserMessages = GetUserMessages(True);
	
	Return GeneratedMessage;
	
EndFunction

Function GenerateMessageRecipientsList(RecipientsList)
	
	RecipientsWithContactList = (TypeOf(RecipientsList)= Type("Array"));
	
	Whom = New Array;
	For Each Recipient In RecipientsList Do
		MessageRecipient = New Structure();
		MessageRecipient.Insert("Presentation", Recipient.Presentation);
		
		If RecipientsWithContactList Then
			MessageRecipient.Insert("Address",   Recipient.Address);
			MessageRecipient.Insert("Contact", Recipient.ContactInformationSource);
		Else
			MessageRecipient.Insert("Address",   Recipient.Value);
		EndIf;
		
		Whom.Add(MessageRecipient);
	EndDo;
	
	Return Whom;

EndFunction

Function CommentByTemplateDescription(TemplateDescription)

	Return NStr("en = 'Created from template and sent';") + " - " + TemplateDescription;

EndFunction

// Settings.

Function DefineTemplatesSubjects() Export
	DefaultTemplateName = "MessagesTemplateData";
	
	BasisForMessageTemplates = New ValueTable;
	BasisForMessageTemplates.Columns.Add("Name", New TypeDescription("String"));
	BasisForMessageTemplates.Columns.Add("Presentation", New TypeDescription("String"));
	BasisForMessageTemplates.Columns.Add("Template", New TypeDescription("String"));
	BasisForMessageTemplates.Columns.Add("DCSParametersValues", New TypeDescription("Structure"));
	
	MessageTemplatesSubjectsTypes = Metadata.DefinedTypes.MessageTemplateSubject.Type.Types();
	For Each MessageTemplateSubjectType In MessageTemplatesSubjectsTypes Do
		If MessageTemplateSubjectType <> Type("CatalogRef.MetadataObjectIDs") Then
			
			MetadataObject3 = Metadata.FindByType(MessageTemplateSubjectType);
			
			If MetadataObject3 = Undefined Or Not AccessRight("Read", MetadataObject3) Then
				Continue;
			EndIf;
			
			Purpose = BasisForMessageTemplates.Add();
			Purpose.Name           = MetadataObject3.FullName();
			Purpose.Presentation = MetadataObject3.Presentation();
			
			If MetadataObject3.Templates.Find(DefaultTemplateName) <> Undefined Then
				Purpose.Template = DefaultTemplateName;
				
				// DCS parameters.
				ObjectManager = Common.ObjectManagerByFullName(Purpose.Name);
				DCSTemplate = ObjectManager.GetTemplate(DefaultTemplateName);
				SchemaURL = PutToTempStorage(DCSTemplate);
				SettingsComposer = New DataCompositionSettingsComposer;
				SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
				PeriodParameter  = New DataCompositionParameter("Period");
				
				For Each AvailableParameter In SettingsComposer.Settings.DataParameters.AvailableParameters.Items Do
					ParameterName = String(AvailableParameter.Parameter);
					If Not (AvailableParameter.Parameter =  PeriodParameter
								Or StrCompare(ParameterName, MetadataObject3.Name) = 0) Then
									Purpose.DCSParametersValues.Insert(ParameterName, NULL);
					EndIf;
				EndDo;
			EndIf;
			
		EndIf;
	EndDo;
	
	Return BasisForMessageTemplates;
	
EndFunction

Function TemplatesKinds() Export
	
	TemplatesTypes = New ValueList;
	AvailableOptions = MessageTemplatesAvailableSendOutOptions();
	If AvailableOptions.Mail Then
		TemplatesTypes.Add(MessageTemplatesClientServer.EmailTemplateName(), NStr("en = 'Mail template';"));
	EndIf;
	If AvailableOptions.SMS Then
		TemplatesTypes.Add(MessageTemplatesClientServer.SMSTemplateName(), NStr("en = 'Text template';"));
	EndIf;
	
	Return TemplatesTypes;
	
EndFunction

Function PrepareQueryToGetTemplatesList(TemplateType, SubjectOf = Undefined, TemplateOwner = Undefined, OutputCommonTemplates = True) Export
	
	ForSMSMessages = TemplateType = "SMS";
	ForEmails = TemplateType = "MailMessage";
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	MessageTemplates.Ref,
	|	MessageTemplates.Presentation,
	|	MessageTemplates.Description AS Name,
	|	MessageTemplates.ExternalDataProcessor AS ExternalDataProcessor,
	|	MessageTemplates.TemplateByExternalDataProcessor AS TemplateByExternalDataProcessor,
	|	CASE
	|		WHEN MessageTemplates.ForEmails
	|			THEN CASE
	|					WHEN MessageTemplates.EmailTextType = VALUE(Enum.EmailEditingMethods.HTML)
	|						THEN MessageTemplates.HTMLEmailTemplateText
	|					ELSE MessageTemplates.MessageTemplateText
	|				END
	|		WHEN MessageTemplates.ForSMSMessages
	|			THEN MessageTemplates.SMSTemplateText
	|		ELSE MessageTemplates.TemplateTextArbitrary
	|	END AS TemplateText,
	|	MessageTemplates.EmailTextType,
	|	MessageTemplates.EmailSubject,
	|		CASE
	|			WHEN COUNT(MessageTemplates.Parameters.ParameterName) > 0
	|				THEN TRUE
	|			ELSE FALSE
	|		END AS HasArbitraryParameters
	|FROM
	|	Catalog.MessageTemplates AS MessageTemplates
	|WHERE
	|	(MessageTemplates.AuthorOnly = FALSE OR MessageTemplates.Author = &User) AND
	|	MessageTemplates.ForSMSMessages = &ForSMSMessages
	|	AND MessageTemplates.ForEmails = &ForEmails
	|	AND MessageTemplates.Purpose <> ""IsInternal""
	|	AND &FilterByTemplateOwner
	|	AND MessageTemplates.DeletionMark = FALSE";
	
	If ValueIsFilled(TemplateOwner) Then
		FilterByOwner = "MessageTemplates.TemplateOwner = &TemplateOwner";
		Query.SetParameter("TemplateOwner", TemplateOwner);
	Else
		FilterByOwner = "TRUE";
	EndIf;
	Query.Text = StrReplace(Query.Text, "&FilterByTemplateOwner", FilterByOwner);
	
	Query.SetParameter("ForSMSMessages", ForSMSMessages);
	Query.SetParameter("ForEmails", ForEmails);
	Query.SetParameter("User", Users.AuthorizedUser());
	
	FilterCommonTemplates = ?(OutputCommonTemplates, "MessageTemplates.ForInputOnBasis = FALSE", "");
	
	If ValueIsFilled(SubjectOf) Then
		Query.Text = Query.Text + " AND (MessageTemplates.InputOnBasisParameterTypeFullName = &FullSubjectTypeName "
		+ ?(ValueIsFilled(FilterCommonTemplates), " OR " + FilterCommonTemplates, "") + ")";
		Query.SetParameter("FullSubjectTypeName", 
			?(TypeOf(SubjectOf) = Type("String"), SubjectOf, SubjectOf.Metadata().FullName()));
	Else 
		Query.Text = Query.Text + ?(ValueIsFilled(FilterCommonTemplates), " And " + FilterCommonTemplates, "");
	EndIf;
	
	Return Query;
	
EndFunction

// Base object attributes.
//
// Parameters:
//  Attributes - ValueTree:
//   * Name - String
//   * Presentation - String
//  FullAssignmentTypeName - String
//  Presentation - String
// 
// Returns:
//  ValueTreeRowCollection:
//    * Name - String
//    * Presentation - String
//
Function RelatedObjectAttributes(Attributes, FullAssignmentTypeName, Val Presentation = "")
	
	MetadataObject3 = Common.MetadataObjectByFullName(FullAssignmentTypeName);
	If MetadataObject3 <> Undefined Then
		ParentName = MetadataObject3.Name;
		Presentation = ?(ValueIsFilled(Presentation), Presentation, MetadataObject3.Presentation());
	Else
		ParentName = FullAssignmentTypeName;
		Presentation = ?(ValueIsFilled(Presentation), Presentation, FullAssignmentTypeName);
	EndIf;
	
	RelatedObjectAttributesNode = Attributes.Rows.Find(ParentName, "Name");
	If RelatedObjectAttributesNode = Undefined Then
		RelatedObjectAttributesNode = Attributes.Rows.Add();
		RelatedObjectAttributesNode.Name = ParentName;
		RelatedObjectAttributesNode.Presentation = Presentation;
		RelatedObjectAttributesNode.FullPresentation = Presentation;
	EndIf;
	
	Return RelatedObjectAttributesNode.Rows;
	
EndFunction

Procedure StandardAttributesToHide(Array)
	
	AddUniqueValueToArray(Array, "DeletionMark");
	AddUniqueValueToArray(Array, "Posted");
	AddUniqueValueToArray(Array, "Ref");
	AddUniqueValueToArray(Array, "Predefined");
	AddUniqueValueToArray(Array, "PredefinedDataName");
	AddUniqueValueToArray(Array, "IsFolder");
	AddUniqueValueToArray(Array, "Parent");
	AddUniqueValueToArray(Array, "Owner");
	
EndProcedure

Procedure AddUniqueValueToArray(Array, Value)
	If Array.Find(Value) = Undefined Then
		Array.Add(Upper(Value));
	EndIf;
EndProcedure

// Print forms and attachments

Procedure DefinePrintFormsList(MetadataObject3, Val TemplateParameters, ParameterName = "")
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		
		PrintCommandsSources   = ModulePrintManager.PrintCommandsSources();
		If PrintCommandsSources.Find(MetadataObject3) <> Undefined Then
			
			ObjectPrintCommands = ModulePrintManager.ObjectPrintCommandsAvailableForAttachments(MetadataObject3);
			CheckForDuplicates      = New Map;
			
			For Each Attachment In ObjectPrintCommands Do
				If Not Attachment.isDisabled
					And StrFind(Attachment.Id, ",") = 0
					And Not IsBlankString(Attachment.PrintManager)
					And Not Attachment.SkipPreview
					And Not Attachment.HiddenByFunctionalOptions
					And CheckForDuplicates[Attachment.UUID] = Undefined Then
						NewRow                 = TemplateParameters.Attachments.Add();
						NewRow.Name             = Attachment.Id;
						NewRow.Id   = Attachment.UUID;
						NewRow.Presentation   = Attachment.Presentation;
						NewRow.PrintManager  = Attachment.PrintManager;
						NewRow.FileType        = "MXL";
						NewRow.Status          = "PrintForm";
						NewRow.ParameterName    = ParameterName;
						NewRow.PrintParameters = Attachment.AdditionalParameters;
						CheckForDuplicates.Insert(Attachment.UUID, True);
				EndIf;
			EndDo;
			
		EndIf;
	EndIf;

EndProcedure

// Writes an email attachment located in a temporary storage to a file.
//
// Parameters:
//   Owner - CatalogRef.MessageTemplates
//   InformationRecords - See MessageTemplates.AttachmentsRow
//   FileName - String
//   Size - Number 
//   CountOfBlankNamesInAttachments - Number 
//
Function WriteEmailAttachmentFromTempStorage(Owner, InformationRecords, FileName, Size, CountOfBlankNamesInAttachments = 0) Export
	
	AddressInTempStorage = InformationRecords.Name;
	LongDesc = InformationRecords.Id;
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		
		FileNameToParse = FileName;
		ExtensionWithoutPoint = GetFileExtension(FileNameToParse);
		BaseName = CommonClientServer.ReplaceProhibitedCharsInFileName(FileNameToParse);
		If IsBlankString(BaseName) Then
			
			BaseName = NStr("en = 'Untitled attachment';") + ?(CountOfBlankNamesInAttachments = 0, ""," " + String(CountOfBlankNamesInAttachments + 1));
			CountOfBlankNamesInAttachments = CountOfBlankNamesInAttachments + 1;
			
		Else
			BaseName =  ?(ExtensionWithoutPoint = "", BaseName, Left(BaseName, StrLen(BaseName) - StrLen(ExtensionWithoutPoint) - 1));
		EndIf;
		
		FileParameters = ModuleFilesOperations.FileAddingOptions();
		FileParameters.FilesOwner = Owner;
		FileParameters.BaseName = BaseName;
		FileParameters.ExtensionWithoutPoint = ExtensionWithoutPoint;
		Return ModuleFilesOperations.AppendFile(FileParameters, AddressInTempStorage, "", LongDesc);
		
	EndIf;
	
	Return Undefined;
	
EndFunction

// Procedure - add a print form attachment
//
// Parameters:
//  SendOptions
//  TemplateInfo
//  Attachments
//  TemplatesParameters
//
Procedure AddSelectedPrintFormsToAttachments(SendOptions, TemplateInfo, Attachments, TemplateParameters)
	
	If TemplateInfo.Attachments.Count() = 0 Then
		Return;
	EndIf;
	
	SaveFormats = New Array;
	If TypeOf(TemplateParameters.AttachmentsFormats) = Type("ValueList") Then
		For Each AttachmentFormat1 In TemplateParameters.AttachmentsFormats Do
			SaveFormats.Add(?(TypeOf(AttachmentFormat1.Value) = Type("SpreadsheetDocumentFileType"),
				AttachmentFormat1.Value,
				SpreadsheetDocumentFileType[AttachmentFormat1.Value]));
		EndDo;
	Else
		SaveFormats.Add(StandardSubsystemsServer.TableDocumentFileTypePDF());
	EndIf;
	
	For Each AttachmentPrintForm In TemplateInfo.Attachments Do
		NameOfParameterWithPrintFormInTemplate = TemplateParameters.SelectedAttachments[AttachmentPrintForm.Id];
		If AttachmentPrintForm.Status = "PrintForm" And NameOfParameterWithPrintFormInTemplate <> Undefined Then
			PrintManagerName = AttachmentPrintForm.PrintManager;
			PrintParameters    = AttachmentPrintForm.PrintParameters;
			ObjectsArray     = New Array;
			
			// If the message template has a defined additional (arbitrary) parameter that has its own print forms,
			// then define the object using the name of the parameter that will be used for print form generation.
			SubjectOf = SendOptions.AdditionalParameters.ArbitraryParameters[NameOfParameterWithPrintFormInTemplate];
			If SubjectOf = Undefined Then
				ObjectsArray.Add(SendOptions.SubjectOf);
			Else
				ObjectsArray.Add(SubjectOf);
			EndIf;
			
			TemplatesNames       = ?(IsBlankString(AttachmentPrintForm.Name), AttachmentPrintForm.Id, AttachmentPrintForm.Name);
			
			If Common.SubsystemExists("StandardSubsystems.Print") Then
				ModulePrintManager = Common.CommonModule("PrintManagement");
				
				Try
					PrintCommand = New Structure;
					PrintCommand.Insert("Id", TemplatesNames);
					PrintCommand.Insert("PrintManager", PrintManagerName);
					PrintCommand.Insert("AdditionalParameters", PrintParameters);
					
					SettingsForSaving = ModulePrintManager.SettingsForSaving();
					SettingsForSaving.SaveFormats = SaveFormats;
					SettingsForSaving.PackToArchive = TemplateParameters.PackToArchive;
					SettingsForSaving.TransliterateFilesNames = TemplateParameters.TransliterateFileNames;
					SettingsForSaving.SignatureAndSeal = TemplateParameters.SignatureAndSeal;
					
					PrintFormsCollection = ModulePrintManager.PrintToFile(PrintCommand, ObjectsArray, SettingsForSaving);
					
				Except
					// Error creating the external print form. Skip it and create an email message.
					ErrorInfo = ErrorInfo();
					
					WriteLogEvent(
						EventLogEventName(),
						EventLogLevel.Error,,, NStr("en = 'Error creating external print form due to:';") + Chars.LF
							+ ErrorProcessing.DetailErrorDescription(ErrorInfo));
						
					Common.MessageToUser(ErrorInfo.Description); // messages are processed in GenerateMessage
					Continue;
				EndTry;
				
				For Each PrintForm In PrintFormsCollection Do
					
					AddressInTempStorage = PutToTempStorage(PrintForm.BinaryData, SendOptions.UUID);
					Attachments.Insert(PrintForm.FileName, AddressInTempStorage);
				EndDo;
				
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// A function creating the attachment table.
// 
// Returns:
//  ValueTable:
//   * Name - String
//   * Id- String
//   * Presentation - String
//   * PrintManager - String
//   * PrintParameters - Structure
//   * FileType - String
//   * Status - String
//   * Attribute- String
//   * ParameterName - String
// 
Function AttachmentsTable()
	
	StringType = New TypeDescription("String");
	Attachments = New ValueTable;
	Attachments.Columns.Add("Name",             StringType);
	Attachments.Columns.Add("Id",   StringType);
	Attachments.Columns.Add("Presentation",   StringType);
	Attachments.Columns.Add("PrintManager",  StringType);
	Attachments.Columns.Add("PrintParameters", New TypeDescription("Structure"));
	Attachments.Columns.Add("FileType",        StringType);
	Attachments.Columns.Add("Status",          StringType);
	Attachments.Columns.Add("Attribute",        StringType);
	Attachments.Columns.Add("ParameterName",    StringType);
	
	Return Attachments;
	
EndFunction

// Receives an extension for the passed file name.
//
// Parameters:
//  FileName  - String - a name of the file to get the extension for.
//
// Returns:
//   String   - an extension received from the passed file.
//
Function GetFileExtension(Val FileName)
	
	FileExtention = "";
	RowsArray = StrSplit(FileName, ".", False);
	If RowsArray.Count() > 1 Then
		FileExtention = RowsArray[RowsArray.Count() - 1];
	EndIf;
	
	Return FileExtention;
	
EndFunction

// Defining and filling in parameters (attributes) in the message text
// 
// Parameters:
//  Template - FormDataStructure:
//   * Sender - String
//   * PrintFormsAndAttachments - ValueTable:
//     ** Id - String 
//     ** Name - String 
//   * Parameters - ValueTable
//
// Returns:
//   See MessageTemplatesClientServer.TemplateParametersDetails
//
Function TemplateParameters(Template) Export
	
	Result = MessageTemplatesClientServer.TemplateParametersDetails();
	
	If TypeOf(Template) = Type("FormDataStructure") Or TypeOf(Template) = Type("CatalogObject.MessageTemplates") Then
		
		SetTemplateParameters(Template, Result);
		
	ElsIf TypeOf(Template) = Type("CatalogRef.MessageTemplates") Then
		Query = New Query;
		Query.Text = "SELECT ALLOWED
		|	MessageTemplates.ForInputOnBasis,
		|	MessageTemplates.InputOnBasisParameterTypeFullName,
		|	MessageTemplates.Purpose,
		|	MessageTemplates.Description,
		|	MessageTemplates.ForEmails,
		|	MessageTemplates.EmailTextType,
		|	CASE
		|		WHEN MessageTemplates.ForEmails
		|			THEN CASE
		|					WHEN MessageTemplates.EmailTextType = VALUE(Enum.EmailEditingMethods.HTML)
		|						THEN MessageTemplates.HTMLEmailTemplateText
		|					ELSE MessageTemplates.MessageTemplateText
		|				END
		|		WHEN MessageTemplates.ForSMSMessages
		|			THEN MessageTemplates.SMSTemplateText
		|		ELSE MessageTemplates.TemplateTextArbitrary
		|	END AS TemplateText,
		|	MessageTemplates.EmailSubject,
		|	MessageTemplates.PackToArchive,
		|	MessageTemplates.TransliterateFileNames,
		|	MessageTemplates.AttachmentFormat,
		|	MessageTemplates.ForSMSMessages,
		|	MessageTemplates.SendInTransliteration,
		|	MessageTemplates.SignatureAndSeal,
		|	MessageTemplates.TemplateByExternalDataProcessor,
		|	MessageTemplates.AddAttachedFiles,
		|	MessageTemplates.ExternalDataProcessor,
		|	MessageTemplates.Ref,
		|	MessageTemplates.TemplateOwner
		|FROM
		|	Catalog.MessageTemplates AS MessageTemplates
		|WHERE
		|	MessageTemplates.Ref = &Template
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MessageTemplatesPrintedFormsAndAttachments.Id,
		|	MessageTemplatesPrintedFormsAndAttachments.Name
		|FROM
		|	Catalog.MessageTemplates.PrintFormsAndAttachments AS MessageTemplatesPrintedFormsAndAttachments
		|WHERE
		|	MessageTemplatesPrintedFormsAndAttachments.Ref = &Template
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MessageTemplatesParameters.ParameterPresentation,
		|	MessageTemplatesParameters.ParameterType,
		|	MessageTemplatesParameters.ParameterName
		|FROM
		|	Catalog.MessageTemplates.Parameters AS MessageTemplatesParameters
		|WHERE
		|	MessageTemplatesParameters.Ref = &Template";
		
		Query.SetParameter("Template", Template);
		
		QueryResult = Query.ExecuteBatch();
		TemplateInfo = QueryResult[0].Unload();
		
		If TemplateInfo.Count() > 0 Then
			
			TemplateInfoString = TemplateInfo[0];
			For Each SelectedPrintForm In QueryResult[1].Unload() Do
				Result.SelectedAttachments.Insert(SelectedPrintForm.Id, SelectedPrintForm.Name);
			EndDo;
			Result.Text                      = TemplateInfoString.TemplateText;
			Result.TemplateType                 = TemplateType(TemplateInfoString);
			
			If TemplateInfoString.ForInputOnBasis Then
				Result.Purpose              = TemplateInfoString.Purpose;
				Result.FullAssignmentTypeName = TemplateInfoString.InputOnBasisParameterTypeFullName;
			EndIf;
			Result.EmailFormat1                = TemplateInfoString.EmailTextType;
			
			If Result.TemplateType = "SMS" Then
				Result.Transliterate      = TemplateInfoString.SendInTransliteration;
			ElsIf Result.TemplateType = "MailMessage" Then
				Result.Subject                    = TemplateInfoString.EmailSubject;
				Result.PackToArchive         = TemplateInfoString.PackToArchive;
				Result.EmailFormat1            = TemplateInfoString.EmailTextType;
				Result.SignatureAndSeal          = TemplateInfoString.SignatureAndSeal;
			EndIf;
			
			FillPropertyValues(Result, TemplateInfoString);
			Result.AttachmentsFormats             = TemplateInfoString.AttachmentFormat.Get();
			
			For Each StringParameter In QueryResult[2].Unload() Do
				
				DescriptionOfTheParameterType = Common.StringTypeDetails(250);
				If TypeOf(StringParameter.ParameterType) = Type("ValueStorage") Then
					TheTypeOfTheParameterValue = StringParameter.ParameterType.Get();
					If TypeOf(TheTypeOfTheParameterValue) = Type("TypeDescription") Then
						DescriptionOfTheParameterType = TheTypeOfTheParameterValue;
					EndIf;
				EndIf;
				
				Result.Parameters.Insert(StringParameter.ParameterName,
					New Structure("TypeDetails, Presentation", DescriptionOfTheParameterType, StringParameter.ParameterPresentation));
				
			EndDo;
			
		EndIf;
	EndIf;
	
	If ValueIsFilled(Result.FullAssignmentTypeName) 
		And Not ObjectIsTemplateSubject(Result.FullAssignmentTypeName) Then
		// The object does not belong to the list of template objects, that is why the template can be common only.
		Result.FullAssignmentTypeName = "";
		Result.Purpose              = "";
	EndIf;
	
	MessageTemplatesSettings = MessageTemplatesInternalCached.OnDefineSettings();
	Result.Insert("ExtendedRecipientsList", MessageTemplatesSettings.ExtendedRecipientsList);
	SubjectInfo = MessageTemplatesSettings.TemplatesSubjects.Find(Result.FullAssignmentTypeName, "Name");
	If SubjectInfo <> Undefined Then
		Result.Template = SubjectInfo.Template;
		Result.DCSParameters = SubjectInfo.DCSParametersValues;
		Result.Purpose   = SubjectInfo.Presentation;
	EndIf;
	
	Return Result;
	
EndFunction

// Parameters:
//  Template - CatalogObject.MessageTemplates
//         - FormDataStructure:
//   * Sender - String
//   * PrintFormsAndAttachments - ValueTable:
//     ** Id - String
//     ** Name - String
//   * Parameters - ValueTable
//  Result - Structure:
//   * Subject - String
//   * Text - String
//   * SignatureAndSeal - Boolean
//   * MessageParameters - Structure
//   * Description - String
//   * Ref - Undefined
//   * TemplateOwner - Undefined
//   * DCSParameters - Map
//   * Parameters - Map
//   * Template - String
//   * SelectedAttachments - Map
//   * AttachmentsFormats - ValueList
//   * ExpandRefAttributes - Boolean
//   * TemplateByExternalDataProcessor - Boolean
//   * ExternalDataProcessor - Undefined
//   * Sender - String
//   * Transliterate - Boolean
//   * PackToArchive - Boolean
//   * EmailFormat1 - EnumRef.EmailEditingMethods
//   * FullAssignmentTypeName - String
//   * Purpose - String
//   * TemplateType - String
//
Procedure SetTemplateParameters(Template, Result)
	
	Var PrintFormsAndAttachments;
	
	Result.TemplateType                  = TemplateType(Template);
	Result.Subject                        = Template.EmailSubject;
	
	If Template.ForInputOnBasis Then
		Result.FullAssignmentTypeName  = Template.InputOnBasisParameterTypeFullName;
		Result.Purpose               = Template.Purpose;
	EndIf;
	Result.EmailFormat1                 = Template.EmailTextType;
	Result.PackToArchive              = Template.PackToArchive;
	Result.Transliterate           = Template.SendInTransliteration;
	Result.Sender                  = Template.Sender;
	
	If Result.TemplateType = "SMS" Then
		Result.Text = Template.SMSTemplateText;
	ElsIf Result.TemplateType = "MailMessage" Then
		If Template.EmailTextType = Enums.EmailEditingMethods.HTML Then
			Result.Text = Template.HTMLEmailTemplateText;
		Else
			Result.Text = Template.MessageTemplateText;
		EndIf;
	Else
		Result.Text = Template.TemplateTextArbitrary;
	EndIf;
	
	Result.TransliterateFileNames = Template.TransliterateFileNames;
	Result.SignatureAndSeal               = Template.SignatureAndSeal;
	
	FillPropertyValues(Result, Template,, "Parameters");
	
	For Each PrintFormsAndAttachments In Template.PrintFormsAndAttachments Do
		Result.SelectedAttachments.Insert(PrintFormsAndAttachments.Id, PrintFormsAndAttachments.Name);
	EndDo;
	
	For Each StringParameter In Template.Parameters Do
		Result.Parameters.Insert(StringParameter.ParameterName, New Structure("TypeDetails, Presentation", StringParameter.TypeDetails, StringParameter.ParameterPresentation));
	EndDo;
	
EndProcedure

Function TemplateType(Template)
	
	Result = "Arbitrary";
	
	If Template.ForSMSMessages Then
		Result = "SMS";
	ElsIf Template.ForEmails Then
		Result = "MailMessage";
	EndIf;
	
	Return Result;
	
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
	
	If TemplateParameters.TemplateType = "MailMessage" Then
		Return DefineMessageTextParameters(TemplateParameters.Text + " " + TemplateParameters.Subject);
	ElsIf TemplateParameters.TemplateType = "SMS" 
	      Or TemplateParameters.TemplateType = "Arbitrary" Then
		Return DefineMessageTextParameters(TemplateParameters.Text);
	Else
		Return New Map;
	EndIf;
	
EndFunction

Function DefineMessageTextParameters(MessageText)
	
	ParametersArray = New Map;
	
	MessageLength = StrLen(MessageText);
	
	Text = MessageText;
	Position = StrFind(Text, "[");
	While Position > 0 Do
		If Position + 1 > MessageLength Then
			Break;
		EndIf;
		PositionEnd1 = StrFind(Text, "]", SearchDirection.FromBegin, Position + 1);
		If PositionEnd1 > 0 Then
			FoundParameter = Mid(Text, Position + 1, PositionEnd1 - Position - 1);
			ParametersArray.Insert(FoundParameter, "");
		ElsIf PositionEnd1 = 0 Then
			PositionEnd1 = Position + 1;
		EndIf;
		If PositionEnd1 > MessageLength Then
			Break;
		EndIf;
		Position = StrFind(Text, "[", SearchDirection.FromBegin, PositionEnd1);
	EndDo;
	
	ParametersMap = New Map;
	For Each ParametersArrayElement In ParametersArray Do
		PositionFormat = StrFind(ParametersArrayElement.Key, "{");
		If PositionFormat > 0 Then
			ParameterName  = Left(ParametersArrayElement.Key, PositionFormat - 1);
			FormatLine = Mid(ParametersArrayElement.Key, PositionFormat );
		Else
			ParameterName  = ParametersArrayElement.Key;
			FormatLine = "";
		EndIf;
		ArrayParsedParameter = StrSplit(ParameterName, ".", False);
		If ArrayParsedParameter.Count() < 2 Then
			Continue;
		EndIf;
		
		SetMapItem(ParametersMap, ArrayParsedParameter, FormatLine);
	EndDo;
	
	Return ParametersMap;
	
EndFunction

Function MessageTextParameters(MessageText) Export
	
	ParametersArray = New Map;
	
	Set = StrSplit(MessageText, "[");
	For Each SetParameter In Set Do
		Position = StrFind(SetParameter, "]");
		If Position > 0 Then
			ParameterName = Left(SetParameter, Position - 1);
			ParametersArray.Insert(ParameterName, ParameterName);
		EndIf;
	EndDo;
	
	Return ParametersArray;
	
EndFunction

Procedure SetMapItem(ParametersMap, Val ArrayParsedParameter, FormatLine)
	MapItem = ParametersMap.Get(ArrayParsedParameter[0]);
	If MapItem = Undefined Then
		If ArrayParsedParameter.Count() > 1 Then
			InternalMapItem = New Map;
			ParametersMap.Insert(ArrayParsedParameter[0], InternalMapItem);
			ArrayParsedParameter.Delete(0);
			SetMapItem(InternalMapItem, ArrayParsedParameter, FormatLine)
		Else
			If ParametersMap[ArrayParsedParameter[0] + FormatLine] = Undefined Then
				ParametersMap.Insert(ArrayParsedParameter[0] + FormatLine, "");
			EndIf;
		EndIf;
	Else
		If ArrayParsedParameter.Count() > 1 Then
			ArrayParsedParameter.Delete(0);
			SetMapItem(MapItem, ArrayParsedParameter, FormatLine)
		Else
			If ParametersMap[ArrayParsedParameter[0] + FormatLine] = Undefined Then
				ParametersMap.Insert(ArrayParsedParameter[0] + FormatLine, "");
			EndIf;
		EndIf;
	EndIf;
EndProcedure

Function ParametersList(MessageTextParameters, Prefix = "")
	
	AttributesList = "";
	Attributes = New Map;
	For Each Attribute In MessageTextParameters Do
		If TypeOf(Attribute.Value) = Type("Map") Then
			AttributesList = AttributesList + ParametersList(Attribute.Value, Attribute.Key + ".");
		Else
			If IsBlankString(Attribute.Value) Then
				
				AttributeDetails = ParameterNameWithoutFormatString(Attribute.Key);
				If Attributes[AttributeDetails.Name] <> Undefined Then
					Continue;
				EndIf;
				Attributes.Insert(AttributeDetails.Name, True);
				
				AttributesList = AttributesList + ", " + Prefix + AttributeDetails.Name;
			EndIf;
		EndIf;
	EndDo;
	
	Return AttributesList;
	
EndFunction

Function FillMessageParameters(TemplateParameters, MessageTextParameters, SendOptions)
	
	SubjectOf = SendOptions.SubjectOf;
	Message = New Structure("AttributesValues, CommonAttributesValues, Attachments, AdditionalParameters");
	Message.Attachments = New Map;
	Message.CommonAttributesValues = New Map;
	Message.AttributesValues = New Map;
	ObjectName = "";
	
	If SubjectOf <> Undefined 
		And ValueIsFilled(TemplateParameters.FullAssignmentTypeName) Then
		SubjectMetadata1 = SubjectOf.Metadata(); // MetadataObject
		ObjectName = SubjectMetadata1.Name;
		
		If MessageTextParameters[ObjectName] <> Undefined Then
			
			FillAttributesValuesByParameters(Message, MessageTextParameters[ObjectName], TemplateParameters, SubjectOf);
			
		Else
			Message.AttributesValues = ?(MessageTextParameters[TemplateParameters.FullAssignmentTypeName] <> Undefined,
				MessageTextParameters[TemplateParameters.FullAssignmentTypeName], New Map);
		EndIf;
		
	EndIf;
	
	If SendOptions.AdditionalParameters.Property("ArbitraryParameters") Then
		For Each ArbitraryTemplateParameter In MessageTextParameters Do
			
			ParameterKey = ArbitraryTemplateParameter.Key;
			If StrCompare(ParameterKey, ObjectName) = 0 Then
				Continue;
			EndIf;
			
			If ParameterKey = MessageTemplatesClientServer.ArbitraryParametersTitle() Then
				ArbitraryAttributes = MessageTextParameters[MessageTemplatesClientServer.ArbitraryParametersTitle()];
				If TypeOf(ArbitraryAttributes ) = Type("Map") Then
					For Each ArbitraryAttribute In ArbitraryAttributes Do
						ParameterDetails = ParameterNameWithoutFormatString(ArbitraryAttribute.Key);
						If IsBlankString(ParameterDetails.Format) Then
							ArbitraryAttributes[ArbitraryAttribute.Key] = SendOptions.AdditionalParameters.ArbitraryParameters[ArbitraryAttribute.Key];
						Else
							ArbitraryAttributes[ArbitraryAttribute.Key] = 
								Format(SendOptions.AdditionalParameters.ArbitraryParameters[ParameterDetails.Name], ParameterDetails.Format);
						EndIf;
					EndDo;
				EndIf;
				Continue;
			EndIf;
			
			If ParameterKey = MessageTemplates.CommonAttributesNodeName() Then
				Continue;
			EndIf;
			
			ArbitraryParameterValue = SendOptions.AdditionalParameters.ArbitraryParameters[ParameterKey];
			If ArbitraryParameterValue <> Undefined Then
				
				If Not ValueIsFilled(ArbitraryParameterValue) Then
					Continue;
				EndIf;
				
				If TypeOf(ArbitraryParameterValue) = Type("String")
					Or TypeOf(ArbitraryParameterValue) = Type("Date") Then
					ArbitraryAttributes = MessageTextParameters[MessageTemplatesClientServer.ArbitraryParametersTitle()];
					If TypeOf(ArbitraryAttributes ) = Type("Map") Then
						MessageTextParameters[MessageTemplatesClientServer.ArbitraryParametersTitle()][ParameterKey] = ArbitraryParameterValue;
					EndIf;
				Else
					
					ArbitraryParameterValueMetadata = Metadata.FindByType(TypeOf(ArbitraryParameterValue)); // MetadataObject
					
					If ArbitraryParameterValueMetadata <> Undefined Then
						ObjectName = ArbitraryParameterValueMetadata.Name;
						
						If MessageTextParameters[ObjectName] <> Undefined Then
							FillAttributesBySubject(MessageTextParameters[ObjectName], ArbitraryParameterValue);
							FillPropertiesAndContactInformationAttributes(MessageTextParameters[ObjectName], ArbitraryParameterValue);
						EndIf;
					EndIf;
					
				EndIf;
			Else
				
				SendOptions.AdditionalParameters.ArbitraryParameters.Insert(ParameterKey, ArbitraryTemplateParameter.Value);
				
			EndIf;
			
		EndDo;
	EndIf;
	
	If MessageTextParameters[MessageTemplates.CommonAttributesNodeName()] <> Undefined Then
		FillCommonAttributes(MessageTextParameters[MessageTemplates.CommonAttributesNodeName()]);
		Message.CommonAttributesValues = MessageTextParameters[MessageTemplates.CommonAttributesNodeName()];
	EndIf;
	
	Return Message;
	
EndFunction

Procedure FillAttributesValuesByParameters(Message, Val MessageTextParameters, Val TemplateParameters, SubjectOf)
	
	If MessageTextParameters["ExternalObjectRef"] <> Undefined Then
		MessageTextParameters["ExternalObjectRef"] = ExternalObjectRef(SubjectOf);
		If MessageTextParameters.Count() = 1 Then
			Return;
		EndIf;
	EndIf;
	
	If ValueIsFilled(TemplateParameters.Template) Then
		FillAttributesByDCS(MessageTextParameters, SubjectOf, TemplateParameters);
	Else
		FillAttributesBySubject(MessageTextParameters, SubjectOf);
	EndIf;
	FillPropertiesAndContactInformationAttributes(MessageTextParameters, SubjectOf);
	Message.AttributesValues = MessageTextParameters;

EndProcedure

Function SetAttributesValuesToMessageText(TemplateParameters, MessageTextParameters, SubjectOf)
	
	Result = New Structure("Subject, Text, Attachments");
	
	If TemplateParameters.TemplateType = "MailMessage" Then
		Result.Subject = InsertParametersInRowAccordingToParametersTable(TemplateParameters.Subject, MessageTextParameters);
	EndIf;
	Result.Text = InsertParametersInRowAccordingToParametersTable(TemplateParameters.Text, MessageTextParameters);
	
	Return Result;
	
EndFunction

Procedure SetParametersFromQuery(Parameters, Result, Val Prefix = "")
	
	For Each ParameterValue In Parameters Do
		If TypeOf(Parameters[ParameterValue.Key]) = Type("Map") Then
			SetParametersFromQuery(Parameters[ParameterValue.Key], Result, Prefix + ParameterValue.Key);
		Else
			If IsBlankString(ParameterValue.Value) Then
				FormatPosition = StrFind(ParameterValue.Key, "{");
				If FormatPosition > 0 Then
					ParameterName = Left(ParameterValue.Key, FormatPosition - 1);
					FormatLine =Mid(ParameterValue.Key, FormatPosition + 1, StrLen(ParameterValue.Key) - StrLen(ParameterName) -2);
					Value = Result.Get(Prefix + ParameterName);
					If StrStartsWith(FormatLine , "D") Then
						Parameters[ParameterValue.Key] = Format(ConvertStringsToType(Value, "Date"), FormatLine);
					ElsIf StrStartsWith(FormatLine , "Ch") Then
						Parameters[ParameterValue.Key] = Format(ConvertStringsToType(Value, "Number"), FormatLine);
					ElsIf StrStartsWith(FormatLine , "B") Then
						Parameters[ParameterValue.Key] = Format(ConvertStringsToType(Value, "Boolean"), FormatLine);
					Else
						Parameters[ParameterValue.Key] = Format(Result.Get(Prefix + ParameterName), FormatLine);
					EndIf;
				Else
					Parameters[ParameterValue.Key] = ?(Result[Prefix + ParameterValue.Key] <> Undefined, Result[Prefix + ParameterValue.Key], "");
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Function ConvertStringsToType(Value, Type)
	TypeDetails = New TypeDescription(Type);
	Return TypeDetails.AdjustValue(Value);
EndFunction

Procedure FillCommonAttributes(CommonAttributes) Export
	
	If TypeOf(CommonAttributes) = Type("Map") Then
		For Each CommonAttribute In CommonAttributes Do
			If StrStartsWith(CommonAttribute.Key, "CurrentDate") Then
				ParameterDetails = ParameterNameWithoutFormatString(CommonAttribute.Key);
				If IsBlankString(ParameterDetails.Format) Then
					CommonAttributes[CommonAttribute.Key] = CurrentSessionDate();
				Else
					CommonAttributes[CommonAttribute.Key] = Format(CurrentSessionDate(), ParameterDetails.Format);
				EndIf;
				Break;
			EndIf;
		EndDo;
		
		If CommonAttributes.Get("SystemTitle") <> Undefined Then
			CommonAttributes["SystemTitle"] = ThisInfobaseName();
		EndIf;
		If CommonAttributes.Get("InfobaseInternetAddress") <> Undefined Then
			CommonAttributes["InfobaseInternetAddress"] = Common.InfobasePublicationURL();
		EndIf;
		If CommonAttributes.Get("InfobaseLocalAddress") <> Undefined Then
			CommonAttributes["InfobaseLocalAddress"] = Common.LocalInfobasePublishingURL();
		EndIf;
		
		If TypeOf(CommonAttributes.Get("CurrentUser")) = Type("Map") Then
			CurrentUser = Users.AuthorizedUser();
			FillAttributesBySubject(CommonAttributes.Get("CurrentUser"), CurrentUser);
			FillPropertiesAndContactInformationAttributes(CommonAttributes.Get("CurrentUser"), CurrentUser);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillAttributesByDCS(Attributes, SubjectOf, TemplateParameters) Export
	
	TemplateName = TemplateParameters.Template;
	
	QueryOptions = New Array;
	ObjectMetadata = SubjectOf.Metadata();
	ObjectName = ObjectMetadata.Name;
	ObjectManager = Common.ObjectManagerByFullName(ObjectMetadata.FullName());
	DCSTemplate = ObjectManager.GetTemplate(TemplateName);
	
	SchemaURL = PutToTempStorage(DCSTemplate);
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
	PeriodParameter = New DataCompositionParameter("Period");
	
	For Each AvailableParameter In SettingsComposer.Settings.DataParameters.AvailableParameters.Items Do
		If AvailableParameter.Parameter <> PeriodParameter Then
			QueryOptions.Add(String(AvailableParameter.Parameter));
		EndIf;
	EndDo;
	
	SettingsComposer.LoadSettings(DCSTemplate.DefaultSettings);
	TemplateComposer = New DataCompositionTemplateComposer();
	
	For Each Attribute In Attributes Do
		SelectedField = SettingsComposer.Settings.Selection.Items.Add(Type("DataCompositionSelectedField"));
		
		FieldName = Attribute.Key;
		If StrEndsWith(FieldName, "}") And StrFind(FieldName, "{") > 0 Then
			FieldName = Left(FieldName, StrFind(FieldName, "{") - 1);
		EndIf;
		
		SelectedField.Field = New DataCompositionField(FieldName);
	EndDo;
	
	DataCompositionTemplate = TemplateComposer.Execute(DCSTemplate, SettingsComposer.GetSettings(),,, Type("DataCompositionValueCollectionTemplateGenerator"));
	
	If DataCompositionTemplate.DataSets.Count() = 0 Then
		Return;
	EndIf;
	
	QueryTextTemplate = DataCompositionTemplate.DataSets.Data.Query;
	
	Query = New Query;
	Query.Text = QueryTextTemplate;
	
	BlankParameters = New Array;
	For Each RequiredParameter In QueryOptions Do
		If StrCompare(RequiredParameter, "CurrentDate") = 0 Then
			Query.SetParameter(RequiredParameter, CurrentSessionDate());
		ElsIf StrCompare(RequiredParameter, ObjectName) = 0 Then
			Query.SetParameter(RequiredParameter, SubjectOf);
		Else
			If TemplateParameters.DCSParameters.Property(RequiredParameter) Then
				Query.SetParameter(RequiredParameter, TemplateParameters.DCSParameters[RequiredParameter]);
			Else
				BlankParameters.Add(RequiredParameter);
			EndIf;
			
		EndIf;
	EndDo;
	
	If BlankParameters.Count() > 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot generate the message as the following parameter filling data is missing: %1 for %2';"), 
			StrConcat(BlankParameters, ","), String(SubjectOf));
	EndIf;
	
	QueryResult = Query.Execute().Unload();
	If QueryResult.Count() > 0 Then
		QueryResult = ValueTableRowToMap(QueryResult[0]);
		SetParametersFromQuery(Attributes, QueryResult);
	EndIf;
	
EndProcedure

Procedure FillAttributesBySubject(Attributes, SubjectOf)
	
	ObjectMetadata = SubjectOf.Metadata();
	BasisParameters = DefineAttributesForMetadataQuery(Attributes, ObjectMetadata);
	
	AttributesList = Mid(ParametersList(BasisParameters), 3);
	If ValueIsFilled(AttributesList) Then
		
		AttributesValues = New Map;
		For Each AttributeValue In Common.ObjectAttributesValues(SubjectOf, AttributesList, True) Do
			AttributesValues.Insert(AttributeValue.Key,AttributeValue.Value);
		EndDo;
		SetParametersFromQuery(Attributes, AttributesValues);
		
	EndIf;
	
EndProcedure

Function ValueTableRowToMap(ValueTableRow)
	
	Map = New Map;
	For Each Column In ValueTableRow.Owner().Columns Do
		Map.Insert(Column.Name, ValueTableRow[Column.Name]);
	EndDo;
	
	Return Map;
	
EndFunction

// Inserts message parameter values into a template and generates a message text.
//
// Parameters:
//  StringPattern        - String
//  ValuesToInsert - Map
//  Prefix             - String
// 
// Returns:
//   String
//
Function InsertParametersInRowAccordingToParametersTable(Val StringPattern, ValuesToInsert, Val Prefix = "") Export
	
	Result = StringPattern;
	For Each AttributesList In ValuesToInsert Do
		If TypeOf(AttributesList.Value) = Type("Map") Then
			Result = InsertParametersInRowAccordingToParametersTable(Result, AttributesList.Value, Prefix + AttributesList.Key + ".");
		Else
			Result = StrReplace(Result, "[" + Prefix + AttributesList.Key + "]", AttributesList.Value);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Processes HTML text for storing to a formatted document.
//
Procedure ProcessHTMLForFormattedDocument(TemplateParameters, GeneratedMessage, ConvertHTMLForFormattedDocument, ListOfFiles = Undefined) Export

	If IsBlankString(GeneratedMessage.Text) Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		
		If ListOfFiles = Undefined Then
			ListOfFiles = New Array;
			ModuleFilesOperations.FillFilesAttachedToObject(TemplateParameters.Template, ListOfFiles);
		EndIf;
		
		HTMLDocument = GetHTMLDocumentObjectFromHTMLText(GeneratedMessage.Text);
		For Each Picture In HTMLDocument.Images Do
			
			AttributePictureSource = Picture.Attributes.GetNamedItem("src");
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("FormIdentifier", TemplateParameters.UUID);
			AdditionalParameters.Insert("RaiseException1", False);
			
			PictureMissingInAttachedFiles = True;
			
			For Each AttachedFile In ListOfFiles Do
				If StrOccurrenceCount(AttributePictureSource.Value, AttachedFile.EmailFileID) > 0 Then
					FileData = ModuleFilesOperations.FileData(AttachedFile.Ref, AdditionalParameters);
					ProcessPictureInHTMLTextForFormattedDocument(Picture, FileData, GeneratedMessage, 
					AttributePictureSource, AttachedFile.Description, AttachedFile.EmailFileID);
					PictureMissingInAttachedFiles = False;
					Break;
				ElsIf StrStartsWith(AttributePictureSource.Value, "cid:" + AttachedFile.Description) Then
					FoundRow = GeneratedMessage.Attachments.Find(AttachedFile.Description, "Presentation");
					If FoundRow <> Undefined Then
						GeneratedMessage.Attachments.Delete(FoundRow);
					EndIf;
					
					FileData = ModuleFilesOperations.FileData(AttachedFile.Ref, AdditionalParameters);
					ProcessPictureInHTMLTextForFormattedDocument(Picture, FileData, GeneratedMessage,
						AttributePictureSource, AttachedFile.Description, AttachedFile.Description);
					PictureMissingInAttachedFiles = False;
					Break;
				EndIf;
			EndDo;
			If PictureMissingInAttachedFiles Then
				IconName = Mid(AttributePictureSource.Value, 5);
				FoundRow = GeneratedMessage.Attachments.Find(IconName, "Presentation");
				If FoundRow <> Undefined Then
					BinaryData = GetFromTempStorage(FoundRow.AddressInTempStorage);
					AddressInTempStorage = PutToTempStorage(BinaryData, TemplateParameters.UUID);
					
					FoundRow.Id = IconName;
					FoundRow.AddressInTempStorage = AddressInTempStorage;
					NewAttributePicture = AttributePictureSource.CloneNode(False);
					NewAttributePicture.TextContent = IconName;
					Picture.Attributes.SetNamedItem(NewAttributePicture);
				EndIf;
			EndIf;
		EndDo;
		
		If ConvertHTMLForFormattedDocument Then
			HTMLText = GetHTMLTextFromHTMLDocumentObject(HTMLDocument);
			GeneratedMessage.Text = HTMLText;
		EndIf;
	EndIf;
	
EndProcedure

Procedure ProcessPictureInHTMLTextForFormattedDocument(Picture, AttachedFile, GeneratedMessage, AttributePictureSource, Presentation, Id)
	
	NewAttributePicture = AttributePictureSource.CloneNode(False);
	NewAttributePicture.TextContent = AttachedFile.Description;
	Picture.Attributes.SetNamedItem(NewAttributePicture);
	
	NewAttachment = GeneratedMessage.Attachments.Add();
	NewAttachment.Presentation = Presentation;
	NewAttachment.AddressInTempStorage = AttachedFile.RefToBinaryFileData;
	NewAttachment.Id = Id;

EndProcedure

// Receives an HTML text from the HTMLDocument object.
//
// Parameters:
//  HTMLDocument  - HTMLDocument - a document, from which the text will be extracted.
//
// Returns:
//   String   - HTML text.
//
Function GetHTMLTextFromHTMLDocumentObject(HTMLDocument) Export
	
	DOMWriter = New DOMWriter;
	HTMLWriter = New HTMLWriter;
	HTMLWriter.SetString();
	DOMWriter.Write(HTMLDocument, HTMLWriter);
	Return HTMLWriter.Close();
	
EndFunction

// Receives the HTMLDocument object from an HTML text.
//
// Parameters:
//  HTMLText  - String -  an HTML text.
//  Encoding - String - text encoding
//
// Returns:
//   HTMLDocument   - Created HTML document.
//
Function GetHTMLDocumentObjectFromHTMLText(HTMLText, Encoding = Undefined) Export
	
	Builder = New DOMBuilder;
	HTMLReader = New HTMLReader;
	
	NewHTMLText = HTMLText;
	PositionOpenXML = StrFind(NewHTMLText,"<?xml");
	
	If PositionOpenXML > 0 Then
		
		PositionCloseXML = StrFind(NewHTMLText,"?>");
		If PositionCloseXML > 0 Then
			
			NewHTMLText = Left(NewHTMLText,PositionOpenXML - 1) + Right(NewHTMLText,StrLen(NewHTMLText) - PositionCloseXML -1);
			
		EndIf;
		
	EndIf;
	
	If Encoding = Undefined Then
		HTMLReader.SetString(HTMLText);
	Else
		HTMLReader.SetString(HTMLText, Encoding);
	EndIf;
	Return Builder.Read(HTMLReader);
	
EndFunction

// Attribute management.

Procedure AttributesByDCS(Attributes, Template, Val Prefix = "") Export
	
	If ValueIsFilled(Prefix) Then
		If Not StrEndsWith(Prefix, ".") Then
			Prefix = Prefix + ".";
		EndIf;
	EndIf;
	
	SchemaURL = PutToTempStorage(Template);
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
	
	For Each AvailableField In SettingsComposer.Settings.SelectionAvailableFields.Items Do
		
		If AvailableField.Folder Then
			Continue;
		EndIf;
		
		NewString1 = AddAttribute(Prefix + AvailableField.Field, Attributes);
		NewString1.Presentation = AvailableField.Title;
		NewString1.Type           = AvailableField.ValueType;
		
	EndDo;
	
EndProcedure

// Details
// 
// Parameters:
//  Attributes - ValueTreeRowCollection
//            - ValueTree:
//   * Name - String
//   * Presentation - String
//  MetadataObject3 - MetadataObject
//                   - Undefined
//  AttributesList - String
//  ExcludingAttributes - String
//  Prefix - String
//
Procedure AttributesByObjectMetadata(Attributes, MetadataObject3, AttributesList = "", ExcludingAttributes = "", Prefix = "")
	
	AttributesListInfo = New Structure("AttributesList, ListContainsData");
	AttributesListInfo.AttributesList     = StrSplit(Upper(AttributesList), ",", False);
	AttributesListInfo.ListContainsData = (AttributesListInfo.AttributesList.Count() > 0);
	
	AttributesToExcludeInfo = New Structure("AttributesList, ListContainsData");
	AttributesToExcludeInfo.AttributesList = StrSplit(Upper(ExcludingAttributes), ",", False);
	AttributesToExcludeInfo.ListContainsData = (AttributesToExcludeInfo.AttributesList.Count() > 0);
	
	If TypeOf(MetadataObject3) = Type("MetadataObject") And Not Common.IsEnum(MetadataObject3) Then
		For Each Attribute In MetadataObject3.Attributes Do
			If Not StrStartsWith(Attribute.Name, "Delete") Then
				If Attribute.Type.Types().Count() = 1 And Attribute.Type.Types()[0] = Type("ValueStorage") Then
					Continue;
				EndIf;
				
				AddAttributeByObjectMetadata(Attributes, Attribute, Prefix, AttributesListInfo, AttributesToExcludeInfo);
			EndIf;
		EndDo;
	EndIf;
	
	StandardAttributesToHide(AttributesToExcludeInfo.AttributesList);
	AttributesToExcludeInfo.ListContainsData = True;
	For Each Attribute In MetadataObject3.StandardAttributes Do
		AddAttributeByObjectMetadata(Attributes, Attribute, Prefix, AttributesListInfo, AttributesToExcludeInfo);
	EndDo;
	
	If Not Common.IsEnum(MetadataObject3) Then
		AddPropertiesAttributes(MetadataObject3, Prefix, Attributes, AttributesToExcludeInfo, AttributesListInfo);
		AddContactInformationAttributes(MetadataObject3, Prefix, Attributes, AttributesToExcludeInfo, AttributesListInfo);
	EndIf;
	
EndProcedure

Procedure AddContactInformationAttributes(MetadataObject3, Prefix, Attributes, AttributesToExcludeInfo, AttributesListInfo)
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Ref = Common.ObjectManagerByFullName(MetadataObject3.FullName()).EmptyRef();
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ContactInformationKinds1 = ModuleContactsManager.ObjectContactInformationKinds(Ref);
		If ContactInformationKinds1.Count() > 0 Then
			For Each ContactInformationKind1 In ContactInformationKinds1 Do
				AddAttributeByObjectMetadata(Attributes, ContactInformationKind1.Ref, Prefix, AttributesListInfo, AttributesToExcludeInfo);
			EndDo;
		EndIf;
	EndIf;

EndProcedure

Procedure AddPropertiesAttributes(MetadataObject3, Prefix, Attributes, AttributesToExcludeInfo, AttributesListInfo)
	
	Properties = New Array;
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		EmptyRef = Common.ObjectManagerByFullName(MetadataObject3.FullName()).EmptyRef();
		GetAddlInfo = ModulePropertyManager.UseAddlInfo(EmptyRef);
		GetAddlAttributes = ModulePropertyManager.UseAddlAttributes(EmptyRef);
		
		If GetAddlAttributes Or GetAddlInfo Then
			Properties = ModulePropertyManager.ObjectProperties(EmptyRef, GetAddlAttributes, GetAddlInfo);
			For Each Property In Properties Do
				AddAttributeByObjectMetadata(Attributes, Property, Prefix, AttributesListInfo, AttributesToExcludeInfo);
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure

// Details
// 
// Parameters:
//  Attributes - See RelatedObjectAttributes
//  Attribute - MetadataObject
//  Prefix - String
//  AttributesListInfo - Structure:
//   * AttributesList - Array
//   * ListContainsData - Boolean
//  AttributesToExcludeInfo - Structure:
//   * AttributesList - Array
//   * ListContainsData - Boolean
//
Procedure AddAttributeByObjectMetadata(Attributes, Attribute, Prefix, AttributesListInfo, AttributesToExcludeInfo)
	
	AttributeName = Undefined;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		If TypeOf(Attribute) = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo") Then
			ValuesProperty = Common.ObjectAttributesValues(Attribute, "IDForFormulas, ValueType, FormatProperties");
			AttributeName   = "~Property." + ValuesProperty.IDForFormulas;
			Presentation = String(Attribute);
			Type           = ValuesProperty.ValueType;
			Format        = ValuesProperty.FormatProperties;
		EndIf;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		If TypeOf(Attribute) = Type("CatalogRef.ContactInformationKinds") Then
			IDForFormulas = Common.ObjectAttributeValue(Attribute, "IDForFormulas");
			AttributeName  =  "~KI." + IDForFormulas;
			Presentation = String(Attribute);
			Type           = New TypeDescription("String");
			Format        = "";
		EndIf;
	EndIf;
	
	If AttributeName = Undefined Then
		AttributeName  = Attribute.Name;
		Presentation = Attribute.Presentation();
		Type           = Attribute.Type;
		Format        = Attribute.Format;
	EndIf;
	
	If AttributesListInfo.ListContainsData
		And AttributesListInfo.AttributesList.Find(Upper(TrimAll(AttributeName))) = Undefined Then
		Return;
	EndIf;
	
	If AttributesToExcludeInfo.ListContainsData
		And AttributesToExcludeInfo.AttributesList.Find(Upper(TrimAll(AttributeName))) <> Undefined Then
		Return;
	EndIf;
	
	NewString1 = Attributes.Add();
	NewString1.Name           = Prefix + AttributeName;
	NewString1.Presentation = Presentation;
	NewString1.Type           = Type;
	NewString1.Format        = Format;
	
EndProcedure

Function PropertiesAttributesValues(SubjectOf)
	
	PropertiesValues = New ValueTable;
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		GetAddlInfo = ModulePropertyManager.UseAddlInfo(SubjectOf);
		GetAddlAttributes = ModulePropertyManager.UseAddlAttributes(SubjectOf);
		
		If GetAddlAttributes Or GetAddlInfo Then
			PropertiesValues = ModulePropertyManager.PropertiesValues(SubjectOf, GetAddlAttributes, GetAddlInfo);
		EndIf;
		
	EndIf;
	
	Return PropertiesValues;
	
EndFunction

Function DefineAttributesForMetadataQuery(Val MessageTextParameters, ObjectMetadata)
	
	BasisParameters = CopyMap(MessageTextParameters);
	ProcessDefineAttributesForMetadataQuery(BasisParameters, ObjectMetadata);
	Return BasisParameters;
	
EndFunction

Procedure ProcessDefineAttributesForMetadataQuery(BasisParameters, ObjectMetadata)
	
	KeysOfParametersToDelete = New Array;
	
	For Each BasisParameter In BasisParameters Do
		Position = StrFind(BasisParameter.Key, "{");
		If Position > 0 Then
			ParameterName = Left(BasisParameter.Key, Position - 1);
		Else
			ParameterName = BasisParameter.Key;
		EndIf;
		If TypeOf(BasisParameter.Value) = Type("Map") Then
			ObjectMetadataByKey = ObjectMetadata.Attributes.Find(ParameterName);
			If ObjectMetadataByKey <> Undefined Then
				For Each Type In ObjectMetadataByKey.Type.Types() Do
					ProcessDefineAttributesForMetadataQuery(BasisParameter.Value, Metadata.FindByType(Type));
				EndDo;
			Else
				KeysOfParametersToDelete.Add(BasisParameter.Key);
			EndIf;
		ElsIf ObjectMetadata.Attributes.Find(ParameterName) = Undefined Then
			AttributeNotFound = True;
				For Each StandardAttributes In ObjectMetadata.StandardAttributes Do
				If StrCompare(StandardAttributes.Name, ParameterName) = 0 Then
					AttributeNotFound = False;
					Break;
				EndIf;
			EndDo;
			
			If AttributeNotFound Then
				KeysOfParametersToDelete.Add(BasisParameter.Key);
			EndIf;
		EndIf;
	EndDo;
	
	For Each ParameterKey In KeysOfParametersToDelete Do
		BasisParameters.Delete(ParameterKey);
	EndDo;
	
EndProcedure

// Parameters:
//  MessageTextParameters - See MessageTemplatesInternal.ParametersFromMessageText
//  ErrorAttributes - Array
//  TemplateInfo - See MessageTemplatesInternal.TemplateInfo
//  Prefix - String
//
Procedure DetermineErrorAttributes(MessageTextParameters, ErrorAttributes, TemplateInfo, Prefix = "")
	
	CommonAttributesNodeName = MessageTemplates.CommonAttributesNodeName();
	For Each Attribute In MessageTextParameters Do
		If TypeOf(Attribute.Value) = Type("Map") Then
			DetermineErrorAttributes(Attribute.Value, ErrorAttributes, TemplateInfo, Prefix + Attribute.Key + ".");
		Else
			PositionFormatText = StrFind(Attribute.Key, "{", SearchDirection.FromEnd);
			If PositionFormatText > 0 Then 
				ParameterName = Prefix + Left(Attribute.Key, PositionFormatText - 1);
			Else
				ParameterName = Prefix + Attribute.Key;
			EndIf;
			If StrStartsWith(Prefix, CommonAttributesNodeName) Then
				FoundAttribute = TemplateInfo.CommonAttributes.Rows.Find(ParameterName, "Name", True);
			Else
				FoundAttribute = TemplateInfo.Attributes.Rows.Find(ParameterName, "Name", True);
			EndIf;
			If FoundAttribute = Undefined Then 
				ErrorAttributes.Add(ParameterName);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Procedure FillPropertiesAndContactInformationAttributes(MessageTextParameters, SubjectOf);
	
	ObjectMetadata = SubjectOf.Metadata();
	PropertiesValues = PropertiesAttributesValues(SubjectOf);
	ObjectsContactInformation = ContactInformationAttributesValues(SubjectOf);
	
	If TypeOf(MessageTextParameters) <> Type("Map") Then
		Return;
	EndIf;
	
	For Each BasisParameter In MessageTextParameters Do
		
		If StrStartsWith(BasisParameter.Key, "~Property") Then
			
			For Each ParameterProperty In BasisParameter.Value Do
				If PropertiesValues <> Undefined Then
					For Each RowProperty In PropertiesValues Do
						ParameterDetails = ParameterNameWithoutFormatString(ParameterProperty.Key);
						IDForFormulas = Common.ObjectAttributeValue(RowProperty.Property, "IDForFormulas");
						
						If StrCompare(IDForFormulas, ParameterDetails.Name) = 0 Then
							
							If TypeOf(BasisParameter.Value[ParameterProperty.Key]) = Type("Map")
								And (Catalogs.AllRefsType().ContainsType(TypeOf(RowProperty.Value))
								Or ChartsOfCharacteristicTypes.AllRefsType().ContainsType(TypeOf(RowProperty.Value))) Then
								
								FillAttributesBySubject(BasisParameter.Value[ParameterProperty.Key], RowProperty.Value);
								FillPropertiesAndContactInformationAttributes(BasisParameter.Value[ParameterProperty.Key], RowProperty.Value);
								
							ElsIf ValueIsFilled(ParameterDetails.Format) Then
								BasisParameter.Value[ParameterProperty.Key] = Format(RowProperty.Value, ParameterDetails.Format);
							Else
								BasisParameter.Value[ParameterProperty.Key] = String(RowProperty.Value);
							EndIf;
							
						EndIf;
						
					EndDo;
				EndIf;
			EndDo;
			
		ElsIf StrStartsWith(BasisParameter.Key, "~KI") Then
			
			For Each ContactInformationParameter In BasisParameter.Value Do
				
				For Each ObjectContactInformation In ObjectsContactInformation Do
					IDForFormulas = Common.ObjectAttributeValue(ObjectContactInformation.Kind, "IDForFormulas");
					
					If StrCompare(IDForFormulas, ContactInformationParameter.Key) = 0 Then
						If ValueIsFilled(BasisParameter.Value[ContactInformationParameter.Key]) Then
							PreviousValue1 = BasisParameter.Value[ContactInformationParameter.Key] +", ";
						Else
							PreviousValue1 = "";
						EndIf;
						BasisParameter.Value[ContactInformationParameter.Key] = PreviousValue1 + String(ObjectContactInformation.Presentation);
					EndIf;
				EndDo;
				
			EndDo;
			
		ElsIf TypeOf(BasisParameter.Value) = Type("Map") Then
			
			ObjectMetadataByKey = ObjectMetadata.Attributes.Find(BasisParameter.Key);
			If ObjectMetadataByKey <> Undefined  Then
				FillPropertiesAndContactInformationAttributes(BasisParameter.Value, SubjectOf[BasisParameter.Key]);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function ContactInformationAttributesValues(SubjectOf)
	
	ObjectsContactInformation = Undefined;
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");	
		
		ObjectsWithContactInformation = New Array;
		ObjectsWithContactInformation.Add(SubjectOf);
		ContactInformationKinds = ModuleContactsManager.ObjectContactInformationKinds(SubjectOf.Ref);
		If ContactInformationKinds.Count() > 0 Then
			ObjectsContactInformation = ModuleContactsManager.ObjectsContactInformation(ObjectsWithContactInformation,,, CurrentSessionDate());
		EndIf;
	EndIf;
	
	Return ObjectsContactInformation;
	
EndFunction

Function CommonAttributesTitle() Export
	Return NStr("en = 'Common attributes';");
EndFunction

// Operations with auxiliary methods attributes 
// 
// Returns:
//  ValueTree:
//    * Name - String
//    * Presentation - String
//    * ToolTip - String
//    * Format - String
//    * Type - TypeDescription
//    * ArbitraryParameter - Boolean
//
Function AttributeTree()
	
	StringType = New TypeDescription("String");
	
	Attributes = New ValueTree;
	Attributes.Columns.Add("Name", StringType);
	Attributes.Columns.Add("Presentation", StringType);
	Attributes.Columns.Add("ToolTip", StringType);
	Attributes.Columns.Add("FullPresentation", Common.StringTypeDetails(300));
	Attributes.Columns.Add("Format", StringType);
	Attributes.Columns.Add("Type", New TypeDescription("TypeDescription"));
	Attributes.Columns.Add("ArbitraryParameter", New TypeDescription("Boolean"));
	
	Return Attributes;
	
EndFunction

Function CommonAttributes(Attributes) Export
	
	AttributesNode = Attributes.Rows.Find(MessageTemplates.CommonAttributesNodeName(), "Name");
	If AttributesNode = Undefined Then
		AttributesNode = Attributes.Rows.Add();
		AttributesNode.Name = MessageTemplates.CommonAttributesNodeName();
		AttributesNode.FullPresentation = CommonAttributesTitle();
		AttributesNode.Presentation = CommonAttributesTitle();
	EndIf;
	
	Return AttributesNode;
	
EndFunction

Function DetermineCommonAttributes() Export
	
	CommonAttributes = AttributeTree();
	CommonRowAttributes = CommonAttributes(CommonAttributes);
	
	AddCommonAttribute(CommonRowAttributes, "CurrentDate", NStr("en = 'Current date';"), New TypeDescription("Date"));
	AddCommonAttribute(CommonRowAttributes, "SystemTitle", NStr("en = 'Application title';"));
	AddCommonAttribute(CommonRowAttributes, "InfobaseInternetAddress", NStr("en = 'Infobase web address';"), New TypeDescription("String"));
	AddCommonAttribute(CommonRowAttributes, "InfobaseLocalAddress", NStr("en = 'Infobase LAN address';"), New TypeDescription("String"));
	AddCommonAttribute(CommonRowAttributes, "CurrentUser", NStr("en = 'Current user';"), New TypeDescription("CatalogRef.Users"));
	
	ListOfAttributesToExclude = "Invalid,IBUserID,ServiceUserID,Prepared,IsInternal";
	
	If Metadata.DefinedTypes.Individual.Type.Types().Count() = 1
		And Metadata.DefinedTypes.Individual.Type.Types()[0] = Type("String") Then
		ListOfAttributesToExclude = ListOfAttributesToExclude + ",Individual";
	EndIf;
	
	If Metadata.DefinedTypes.Department.Type.Types().Count() = 1
		And Metadata.DefinedTypes.Department.Type.Types()[0] = Type("String") Then
		ListOfAttributesToExclude = ListOfAttributesToExclude + ",Department";
	EndIf;
	
	ExpandAttribute(MessageTemplates.CommonAttributesNodeName() + ".CurrentUser", CommonRowAttributes.Rows,, ListOfAttributesToExclude);
	
	Return CommonAttributes;
	
EndFunction

Procedure AddCommonAttribute(CommonAttributes, Name, Presentation, Type = Undefined)
	
	NewAttribute = CommonAttributes.Rows.Add();
	NewAttribute.Name = MessageTemplates.CommonAttributesNodeName() + "." + Name;
	NewAttribute.Presentation = Presentation;
	NewAttribute.FullPresentation = CommonAttributesTitle() + "." + Presentation;
	NewAttribute.Type =?(Type = Undefined, New TypeDescription("String"), Type);
	
EndProcedure

Function AddAttribute(Val Name, Node)
	
	NodeName = Node.Parent.Name;
	If Not StrStartsWith(Name, NodeName + ".") Then
		Name = NodeName + "." + Name;
	EndIf;
	
	NewAttribute = Node.Add();
	NewAttribute.Name = Name;
	NewAttribute.Presentation = Name;
	
	Return NewAttribute;
	
EndFunction

Function ExpandAttribute(Val Name, Node, AttributesList = "", ExcludingAttributes = "") Export
	
	Attribute = Node.Find(Name, "Name", False);
	If Attribute <> Undefined Then
		ExpandAttributeByObjectMetadata(Attribute, AttributesList, ExcludingAttributes, Name);
	Else
		Name = Node.Parent.Name + "." + Name;
		Attribute = Node.Find(Name, "Name", False);
		If StrOccurrenceCount(Name, ".") > 1 Then
			Return Attribute.Rows;
		EndIf;
		
		If Attribute <> Undefined Then
			ExpandAttributeByObjectMetadata(Attribute, AttributesList, ExcludingAttributes, Name);
		EndIf;
	EndIf;
	
	Return Attribute.Rows;
	
EndFunction

Procedure ExpandAttributeByObjectMetadata(Attribute, AttributesList, ExcludingAttributes, Val Prefix)
	
	If TypeOf(Attribute.Type) = Type("TypeDescription") Then
		AttributesNode = Attribute.Rows;
		Prefix = Prefix + ?(Right(Prefix, 1) <> ".", ".", "");
		For Each Type In Attribute.Type.Types() Do
			MetadataObject3 = Metadata.FindByType(Type);
			If MetadataObject3 <> Undefined Then
				AttributesByObjectMetadata(AttributesNode, MetadataObject3, AttributesList, ExcludingAttributes, Prefix);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

// Files
Procedure AddAttachedFilesToAttachments(Val SendOptions, Val Message)
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		AttachedFilesList = New Array; // Array of DefinedType.AttachedFile
		ModuleFilesOperations.FillFilesAttachedToObject(SendOptions.Template, AttachedFilesList);
		
		For Each AttachedFile In AttachedFilesList Do
			If IsBlankString(AttachedFile.EmailFileID) Then
				FileDetails = ModuleFilesOperations.FileData(AttachedFile.Ref, SendOptions.UUID);
				If Right(FileDetails.FileName, 1) = "." Then
					FileDetailsFileName = Left(FileDetails.FileName, StrLen(FileDetails.FileName) - 1);
				Else
					FileDetailsFileName = FileDetails.FileName;
				EndIf;
				Message.Attachments.Insert(FileDetailsFileName,  FileDetails.RefToBinaryFileData);
			EndIf;
		EndDo;
	EndIf;

EndProcedure

// Gets an application title. If it is not specified, gets a configuration metadata synonym.
Function ThisInfobaseName()
	
	SetPrivilegedMode(True);
	
	Result = Constants.SystemTitle.Get();
	
	If IsBlankString(Result) Then
		
		Result = Metadata.Synonym;
		
	EndIf;
	
	Return Result;
EndFunction

Function ExternalObjectRef(Parameter)
	
	Return Common.InfobasePublicationURL() + "#" +  GetURL(Parameter);
	
EndFunction

Procedure FillMessageRecipients(SendOptions, TemplateParameters, Result, ObjectManager)
	
	If SendOptions.Property("AdditionalParameters")
		And SendOptions.AdditionalParameters.Property("ArbitraryParameters") Then
		
		MessageSubject = New Structure("SubjectOf, ArbitraryParameters");
		MessageSubject.SubjectOf               = SendOptions.SubjectOf;
		MessageSubject.ArbitraryParameters = SendOptions.AdditionalParameters.ArbitraryParameters;
		CommonClientServer.SupplementStructure(MessageSubject, SendOptions.AdditionalParameters, False);
		
	Else
		
		MessageSubject = SendOptions.SubjectOf;
		
	EndIf;
	
	If TemplateParameters.TemplateType = "MailMessage" Then
		Recipients = GenerateRecipientsByDefault(SendOptions.SubjectOf, TemplateParameters.TemplateType);
		MessageTemplatesOverridable.OnFillRecipientsEmailsInMessage(Recipients, TemplateParameters.FullAssignmentTypeName, MessageSubject);
		If ObjectManager <> Undefined Then
			ObjectManager.OnFillRecipientsEmailsInMessage(Recipients, MessageSubject);
		EndIf;
		
		If TemplateParameters.Property("ExtendedRecipientsList")
			And TemplateParameters.ExtendedRecipientsList Then
			
			Result.Recipient = New Array;
			For Each Recipient In Recipients Do
				If ValueIsFilled(Recipient.Address) Then
					
					RecipientValue = MessageTemplates.NewEmailRecipients();
					RecipientValue.Address                        = Recipient.Address;
					RecipientValue.Presentation                = Recipient.Presentation;
					RecipientValue.ContactInformationSource = Recipient.Contact;
				
					RecipientValue.Insert("SendingOption", Recipient.SendingOption);
					Result.Recipient.Add(RecipientValue);
				EndIf;
			EndDo;
			
		Else
			
			Result.Recipient = New ValueList();
			For Each Recipients In Recipients Do
				If ValueIsFilled(Recipients.Address) Then
					Result.Recipient.Add(Recipients.Address, Recipients.Presentation);
				EndIf;
			EndDo;
			
		EndIf;
		
	Else
		
		Recipients = GenerateRecipientsByDefault(SendOptions.SubjectOf, TemplateParameters.TemplateType);
		MessageTemplatesOverridable.OnFillRecipientsPhonesInMessage(Recipients, TemplateParameters.FullAssignmentTypeName, MessageSubject);
		If ObjectManager <> Undefined Then
			ObjectManager.OnFillRecipientsPhonesInMessage(Recipients, MessageSubject);
		EndIf;
		
		ExtendedRecipientsList = SendOptions.AdditionalParameters.Property("ExtendedRecipientsList") And SendOptions.AdditionalParameters.ExtendedRecipientsList;
		
		If ExtendedRecipientsList Or (TemplateParameters.Property("ExtendedRecipientsList")
			And TemplateParameters.ExtendedRecipientsList) Then
			
			Result.Recipient = New Array;
			For Each Recipient In Recipients Do
				If ValueIsFilled(Recipient.PhoneNumber) Then
					RecipientValue = New Structure("PhoneNumber, Presentation, ContactInformationSource", 
					Recipient.PhoneNumber, Recipient.Presentation, Recipient.Contact);
					Result.Recipient.Add(RecipientValue);
				EndIf;
			EndDo;
			
		Else
			
			Result.Recipient = New ValueList;
			For Each Recipients In Recipients Do
				If ValueIsFilled(Recipients.PhoneNumber) Then
					Result.Recipient.Add(Recipients.PhoneNumber, Recipients.Presentation);
				EndIf;
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function GenerateRecipientsByDefault(SubjectOf, TemplateType);
	
	Recipients = New ValueTable;
	Recipients.Columns.Add("SendingOption", Common.StringTypeDetails(20));
	Recipients.Columns.Add("Presentation", Common.StringTypeDetails(0));
	Recipients.Columns.Add("Contact");
	If StrCompare(TemplateType, "SMS") = 0 Then
		Recipients.Columns.Add("PhoneNumber", Common.StringTypeDetails(500));
		ColumnName = "PhoneNumber";
	Else
		Recipients.Columns.Add("Address", New TypeDescription("String"));
		ColumnName = "Address";
	EndIf;
	
	If SubjectOf = Undefined Then
		Return Recipients;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		
		ContactInformationType = ?(StrCompare(TemplateType, "SMS") = 0,
			ModuleContactsManager.ContactInformationTypeByDescription("Phone"),
			ModuleContactsManager.ContactInformationTypeByDescription("Email"));
	
			If Common.SubsystemExists("StandardSubsystems.Interactions") Then
				ModuleInteractions = Common.CommonModule("Interactions");
				
				If ModuleInteractions.EmailClientUsed() Then
					Contacts = ModuleInteractions.GetContactsBySubject(SubjectOf, ContactInformationType);
					
					For Each InformationAboutContact In Contacts Do
						NewRow = Recipients.Add();
						NewRow.SendingOption = "Whom";
						NewRow.Contact         = InformationAboutContact.Contact;
						NewRow.Presentation   = InformationAboutContact.Presentation;
						NewRow[ColumnName]     = InformationAboutContact.Address;
					EndDo;
				EndIf;
				
		EndIf;
	
		// If the contact list is blank and the object has contact information.
		If Recipients.Count() = 0 And TypeOf(SubjectOf) <> Type("String") Then
			ObjectsWithContactInformation = CommonClientServer.ValueInArray(SubjectOf);
			
			ObjectContactInformationKinds = ModuleContactsManager.ObjectContactInformationKinds(SubjectOf);
			If ObjectContactInformationKinds.Count() > 0 Then
				ObjectsContactInformation = ModuleContactsManager.ObjectsContactInformation(ObjectsWithContactInformation, ContactInformationType,, CurrentSessionDate());
				If ObjectsContactInformation.Count() > 0 Then
					For Each ObjectContactInformation In ObjectsContactInformation Do
						NewRow= Recipients.Add();
						NewRow.SendingOption = "Whom";
						NewRow[ColumnName]     = ObjectContactInformation.Presentation;
						NewRow.Presentation   = StrReplace(String(ObjectContactInformation.Object), ",", "");
						NewRow.Contact         = SubjectOf;
					EndDo;
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Recipients;
	
EndFunction

Function CopyMap(Source)
	
	Recipient = New Map;
	
	For Each Item In Source Do
		If TypeOf(Item.Value) = Type("Map") Then
			Recipient[Item.Key] = CopyMap(Item.Value);
		Else
			Recipient[Item.Key] = Item.Value;
		EndIf;
	EndDo;
	
	Return Recipient;
	
EndFunction

Function EventLogEventName()
	
	Return NStr("en = 'Create message template';", Common.DefaultLanguageCode());
	
EndFunction

Procedure GenerateMessageInBackground(ServerCallParameters, StorageAddress, GenerateAndSend) Export
	
	SendOptions = ServerCallParameters.SendOptions; // See MessageTemplatesClientServer.SendOptionsConstructor
	MessageKind = ServerCallParameters.MessageKind;
	
	If GenerateAndSend Then
		Result = GenerateMessageAndSend(SendOptions);
		PutToTempStorage(Result, StorageAddress);
	Else
		
		TemplateParameters = MessageTemplates.GenerateSendOptions(SendOptions.Template, SendOptions.SubjectOf,
			SendOptions.UUID, SendOptions.AdditionalParameters.MessageParameters);
		
		CommonClientServer.SupplementStructure(TemplateParameters.AdditionalParameters,
			SendOptions.AdditionalParameters, True);
		
		Message = GenerateMessage(TemplateParameters);
		
		If MessageKind = "MailMessage" Then
			Message = ConvertEmailParameters(Message);
		Else
			Message.Attachments = Undefined;
		EndIf;
		
		PutToTempStorage(Message, StorageAddress);
	EndIf;
	
EndProcedure

Function ConvertEmailParameters(Message)
	
	EmailParameters = New Structure();
	EmailParameters.Insert("Sender");
	EmailParameters.Insert("Subject", Message.Subject);
	EmailParameters.Insert("Text", Message.Text);
	EmailParameters.Insert("UserMessages", Message.UserMessages);
	EmailParameters.Insert("DeleteFilesAfterSending", False);
	
	If Message.Recipient = Undefined Or Message.Recipient.Count() = 0 Then
		EmailParameters.Insert("Recipient", Undefined);
	Else
		EmailParameters.Insert("Recipient", Message.Recipient);
	EndIf;
	
	AttachmentsArray = New Array;
	For Each AttachmentDetails In Message.Attachments Do
		AttachmentInformation = New Structure("Presentation, AddressInTempStorage, Encoding, Id");
		FillPropertyValues(AttachmentInformation, AttachmentDetails);
		AttachmentsArray.Add(AttachmentInformation);
	EndDo;
	EmailParameters.Insert("Attachments", AttachmentsArray);
	
	Return EmailParameters;
	
EndFunction

// Update.

// Adds the AddEditPersonalMessageTemplates role to all profiles that contain the BasicAccessSSL role.
Procedure AddAddEditPersonalTemplatesRoleToBasicRightsProfiles() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	ModuleAccessManagement = Common.CommonModule("AccessManagement");
	
	NewRoles = New Array;
	NewRoles.Add(Metadata.Roles.BasicAccessSSL.Name);
	NewRoles.Add(Metadata.Roles.AddEditPersonalMessageTemplates.Name);
	
	RolesToReplace = New Map;
	RolesToReplace.Insert(Metadata.Roles.BasicAccessSSL.Name, NewRoles);
	
	ModuleAccessManagement.ReplaceRolesInProfiles(RolesToReplace);
	
EndProcedure

Function IsStandardAttribute(ObjectMetadata, AttributeName) Export
	
	For Each StandardAttribute In ObjectMetadata.StandardAttributes Do
		
		If StrCompare(StandardAttribute.Name, AttributeName) = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function HasRightToReadMessageTemplates()
	
	Return AccessRight("Read", Metadata.Catalogs.MessageTemplates);
	
EndFunction

Procedure ProcessDataForMigrationToAttachableCommands() Export
		
	HasAttachableCommands = Common.SubsystemExists("StandardSubsystems.AttachableCommands");

	Block = New DataLock;
	Block.Add("Constant.UseSMSMessagesSendingInMessageTemplates");
	Block.Add("Constant.UseEmailInMessageTemplates");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Object = Metadata.Constants.UseSMSMessagesSendingInMessageTemplates;
		ObjectPresentation = Object.Presentation();
		Constants.UseSMSMessagesSendingInMessageTemplates.Set(Not HasAttachableCommands);
		
		Object = Metadata.Constants.UseEmailInMessageTemplates;
		ObjectPresentation = Object.Presentation();
		Constants.UseEmailInMessageTemplates.Set(Not HasAttachableCommands);
		
		CommitTransaction();
	Except
		RollbackTransaction();
				
		InfobaseUpdate.WriteErrorToEventLog(Object, ObjectPresentation, ErrorInfo());
	EndTry;

EndProcedure

#EndRegion

