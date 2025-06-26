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

// Returns new interaction contact details.
// To use in InteractionsClientServerOverridable.OnDeterminePossibleContacts.
//
// Returns:
//   Structure - Contact properties:
//     * Type                                - Type     - a contact reference type.
//     * Name                                 - String - a contact type name as it is defined in metadata.
//     * Presentation                       - String - a contact type presentation to be displayed to a user.
//     * Hierarchical                       - Boolean - indicates that this catalog is hierarchical.
//     * HasOwner                        - Boolean - indicates that the contact has an owner.
//     * OwnerName                        - String - a contact owner name as it is defined in metadata.
//     * SearchByDomain                      - Boolean - indicates that contacts of this type will be picked
//                                                      by the domain map and not by the full email address.
//     * Link                               - String - describes a possible link of this contact with some other contact
//                                                      when the current contact is an attribute of other contact.
//                                                      It is described with the "TableName.AttributeName" string.
//     * ContactPresentationAttributeName   - String - a contact attribute name, from which a contact presentation
//                                                      will be received. If it is not specified, the standard
//                                                      Description attribute is used.
//     * InteractiveCreationPossibility   - Boolean - indicates that a contact can be created interactively from interaction
//                                                      documents.
//     * NewContactFormName              - String - a full form name to create a new contact,
//                                                      for example, "Catalog.Partners.Form.NewContactWizard".
//                                                      If it is not filled in, a default item form is opened.
//
Function NewContactDescription() Export
	
	Result = New Structure;
	Result.Insert("Type",                               "");
	Result.Insert("Name",                               "");
	Result.Insert("Presentation",                     "");
	Result.Insert("Hierarchical",                     False);
	Result.Insert("HasOwner",                      False);
	Result.Insert("OwnerName",                      "");
	Result.Insert("SearchByDomain",                    True);
	Result.Insert("Link",                             "");
	Result.Insert("ContactPresentationAttributeName", "Description");
	Result.Insert("InteractiveCreationPossibility", True);
	Result.Insert("NewContactFormName",            "");
	Return Result;
	
EndFunction	

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Use InteractionsClientServer.NewContactDetails.
// Adds an element to a contact structure array.
//
// Parameters:
//  DetailsArray                     - Array - an array, to which a contact description structure will be added.
//  Type                                - Type    - a contact reference type.
//  InteractiveCreationPossibility  - Boolean - indicates that a contact can be created interactively from interaction
//                                                documents.
//  Name                                 - String - a contact type name as it is defined in metadata.
//  Presentation                       - String - a contact type presentation to be displayed to a user.
//  Hierarchical                       - Boolean - indicates that this catalog is hierarchical.
//  HasOwner                        - Boolean - indicates that the contact has an owner.
//  OwnerName                        - String - a contact owner name as it is defined in metadata.
//  SearchByDomain                      - Boolean - indicates that this contact type will be searched
//                                                 by domain.
//  Link                               - String - describes a possible link of this contact with some other contact
//                                                 when the current contact is an attribute of other contact.
//                                                 It is described with the "TableName.AttributeName" string.
//  ContactPresentationAttributeName   - String - a contact attribute name, from which a contact presentation will be received.
//
Procedure AddPossibleContactsTypesDetailsArrayElement(
	DetailsArray,
	Type,
	InteractiveCreationPossibility,
	Name,
	Presentation,
	Hierarchical,
	HasOwner,
	OwnerName,
	SearchByDomain,
	Link,
	ContactPresentationAttributeName = "Description") Export
	
	DetailsStructure1 = New Structure;
	DetailsStructure1.Insert("Type",                               Type);
	DetailsStructure1.Insert("InteractiveCreationPossibility", InteractiveCreationPossibility);
	DetailsStructure1.Insert("Name",                               Name);
	DetailsStructure1.Insert("Presentation",                     Presentation);
	DetailsStructure1.Insert("Hierarchical",                     Hierarchical);
	DetailsStructure1.Insert("HasOwner",                      HasOwner);
	DetailsStructure1.Insert("OwnerName",                      OwnerName);
	DetailsStructure1.Insert("SearchByDomain",                    SearchByDomain);
	DetailsStructure1.Insert("Link",                             Link);
	DetailsStructure1.Insert("ContactPresentationAttributeName", ContactPresentationAttributeName);

	
	DetailsArray.Add(DetailsStructure1);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

Function PrefixTable() Export
	Return "Table_";
EndFunction
	
////////////////////////////////////////////////////////////////////////////////
// Define the reference type.

// Parameters:
//  ObjectRef  - AnyRef - a reference, to which a check is required.
//
// Returns:
//   Boolean   - True if the passed reference refers to an interaction document.
//
Function IsInteraction(ObjectRef) Export
	
	If TypeOf(ObjectRef) = Type("Type") Then
		ObjectType = ObjectRef;
	Else
		ObjectType = TypeOf(ObjectRef);
	EndIf;
	
	Return ObjectType = Type("DocumentRef.Meeting")
		Or ObjectType = Type("DocumentRef.PlannedInteraction")
		Or ObjectType = Type("DocumentRef.PhoneCall")
		Or ObjectType = Type("DocumentRef.IncomingEmail")
		Or ObjectType = Type("DocumentRef.OutgoingEmail")
		Or ObjectType = Type("DocumentRef.SMSMessage");
	
EndFunction

// Parameters:
//  ObjectRef  - AnyRef - a reference, to which a check is required.
//
// Returns:
//   Boolean   - True if the passed reference is associated with an interaction attachment.
//
Function IsAttachedInteractionsFile(ObjectRef) Export
	
	Return TypeOf(ObjectRef) = Type("CatalogRef.MeetingAttachedFiles")
		Or TypeOf(ObjectRef) = Type("CatalogRef.PlannedInteractionAttachedFiles")
		Or TypeOf(ObjectRef) = Type("CatalogRef.PhoneCallAttachedFiles")
		Or TypeOf(ObjectRef) = Type("CatalogRef.IncomingEmailAttachedFiles")
		Or TypeOf(ObjectRef) = Type("CatalogRef.OutgoingEmailAttachedFiles")
		Or TypeOf(ObjectRef) = Type("CatalogRef.SMSMessageAttachedFiles");
	
EndFunction

// Parameters:
//  ObjectRef - AnyRef - a reference, which is checked
//                               if it is a reference to an interaction subject.
//
// Returns:
//   Boolean   - True if the conditions are met.
//
Function IsSubject(ObjectRef) Export
	
	InteractionsSubjects = InteractionsClientServerInternalCached.InteractionsSubjects();
	For Each SubjectOf In InteractionsSubjects Do
		If TypeOf(ObjectRef) = Type(SubjectOf) Then
			Return True;
		EndIf;
	EndDo;
	Return False;	
	
EndFunction 

////////////////////////////////////////////////////////////////////////////////
// Miscellaneous.

// Parameters:
//  FileName  - String - a checked file name.
//
// Returns:
//   Boolean   - True if the file extension is an email file extension. 
//
Function IsFileEmail(FileName) Export

	FileExtensionsArray = EmailFileExtensionsArray();
	FileExtention       = CommonClientServer.GetFileNameExtension(FileName);
	Return (FileExtensionsArray.Find(FileExtention) <> Undefined);
	
EndFunction

// Parameters:
//  SendInTransliteration  - Boolean - SendInTransliteration - Boolean - indicates that a message 
//                                   will be automatically transformed into Latin characters when sending it.
//  MessageText  - String       - a message text, for which a message is being generated.
//
// Returns:
//   String   - a generated information message.
//
Function GenerateInfoLabelMessageCharsCount(SendInTransliteration, MessageText) Export

	CharsInMessage = ?(SendInTransliteration, 140, 50);
	CountOfCharacters = StrLen(MessageText);
	MessagesCount   = Int(CountOfCharacters / CharsInMessage) + 1;
	CharsLeft      = CharsInMessage - CountOfCharacters % CharsInMessage;
	MessageTextTemplate = NStr("en = 'Messages: %1. Symbols left: %2';");
	Return StringFunctionsClientServer.SubstituteParametersToString(MessageTextTemplate, MessagesCount, CharsLeft);

EndFunction

// Returns:
//  FixedArray of Structure - Includes:
//     * Type                                 - Type     - a contact reference type.
//     * Name                                 - String - a contact type name as it is defined in metadata.
//     * Presentation                       - String - a contact type presentation to be displayed to a user.
//     * Hierarchical                       - Boolean - indicates that this catalog is hierarchical.
//     * HasOwner                        - Boolean - indicates that the contact has an owner.
//     * OwnerName                        - String - a contact owner name as it is defined in metadata.
//     * SearchByDomain                      - Boolean - indicates that contacts of this type will be picked
//                                                      by the domain map and not by the full email address.
//     * Link                               - String - describes a possible link of this contact with some other contact
//                                                      when the current contact is an attribute of other contact.
//                                                      It is described with the "TableName.AttributeName" string.
//     * ContactPresentationAttributeName   - String - a contact attribute name, from which a contact presentation
//                                                      will be received. If it is not specified, the standard
//                                                      Description attribute is used.
//     * InteractiveCreationPossibility   - Boolean - indicates that a contact can be created interactively from interaction
//                                                      documents.
//     * NewContactFormName              - String - a full form name to create a new contact,
//                                                      for example, "Catalog.Partners.Form.NewContactWizard".
//                                                      If it is not filled in, a default item form is opened.
//
Function ContactsDetails() Export
	
	Return InteractionsClientServerInternalCached.InteractionsContacts();
	
EndFunction

// Checks if contacts are populated in an interaction document and updates the interaction document form
//
// Parameters:
//  Object - DocumentObject - an interaction document being checked.
//  Form - ClientApplicationForm - a form for an interactions document.
//  DocumentKind - String - a string name of an interaction document.
//
Procedure CheckContactsFilling(Object,Form,DocumentKind) Export
	
	ContactsFilled = ContactsFilled(Object,DocumentKind);
	
	If ContactsFilled Then
		Form.Items.ContactsSpecifiedPages.CurrentPage = Form.Items.ContactsFilledPage;
	Else
		Form.Items.ContactsSpecifiedPages.CurrentPage = Form.Items.ContactsNotFilledPage;
	EndIf;
	
EndProcedure

// Parameters:
//  SizeInBytes - Number - Attachment size in bytes.
//
// Returns:
//   String   - Attachment size presentation as String.
//
Function GetFileSizeStringPresentation(SizeInBytes) Export
	
	SizeMB = SizeInBytes / (1024*1024);
	If SizeMB > 1 Then
		StringSize = Format(SizeMB, "NFD=1") + " " + NStr("en = 'MB';");
	Else
		StringSize = Format(SizeInBytes /1024, "NFD=0; NZ=0") + " " + NStr("en = 'kB';");
	EndIf;
	
	Return StringSize;
	
EndFunction

// Processes quick filter change of the dynamic interaction document list.
//
// Parameters:
//  Form - ClientApplicationForm - a form for which actions are performed.
//  FilterName - String - name of a filter being changed.
//  IsFilterBySubject - Boolean - indicates that the list form is parametrical and it is filtered by subject.
//
Procedure QuickFilterListOnChange(Form, FilterName, DateForFilter = Undefined, IsFilterBySubject = True) Export
	
	Filter = DynamicListFilter(Form.List);
	
	If FilterName = "Status" Then
		
		CommonClientServer.DeleteFilterItems(Filter, "ReviewAfter");
		CommonClientServer.DeleteFilterItems(Filter, "Reviewed");
		If Not IsFilterBySubject Then
			CommonClientServer.DeleteFilterItems(Filter, "SubjectOf");
		EndIf;
		
		If Form[FilterName] = "ToReview" Then
			
			CommonClientServer.SetFilterItem(Filter, "Reviewed", False,,, True);
			CommonClientServer.SetFilterItem(
				Filter, "ReviewAfter", DateForFilter, DataCompositionComparisonType.LessOrEqual,, True);
			
		ElsIf Form[FilterName] = "Deferred3" Then
			CommonClientServer.SetFilterItem(Filter, "Reviewed", False,,, True);
			CommonClientServer.SetFilterItem(
			Filter, "ReviewAfter", , DataCompositionComparisonType.Filled,, True);
		ElsIf Form[FilterName] = "ReviewedItems" Then
			CommonClientServer.SetFilterItem(Filter, "Reviewed", True,,, True);
		EndIf;
		
	Else
		
		CommonClientServer.SetFilterItem(
			Filter,FilterName,Form[FilterName],,, ValueIsFilled(Form[FilterName]));
		
	EndIf;
	
EndProcedure

// Processes quick filter change by interaction type in a dynamic interaction document list.
//
// Parameters:
//  Form - ClientApplicationForm - Contains the dynamic list the filter is applied to.
//  InteractionType - String - Filter name.
//
Procedure OnChangeFilterInteractionType(Form,InteractionType) Export
	
	Filter = DynamicListFilter(Form.List);
	
	// Clear linked filters.
	FilterGroup = CommonClientServer.CreateFilterItemGroup(
		Filter.Items, NStr("en = 'Filter by interaction category';"), DataCompositionFilterItemsGroupType.AndGroup);
	
	// .Set filters by type.
	If InteractionType = "AllEmails" Then
		
		EmailTypesList = New ValueList;
		EmailTypesList.Add(Type("DocumentRef.IncomingEmail"));
		EmailTypesList.Add(Type("DocumentRef.OutgoingEmail"));
		CommonClientServer.SetFilterItem(
			FilterGroup, "Type", EmailTypesList, DataCompositionComparisonType.InList,, True);
		
	ElsIf InteractionType = "IncomingMessages" Then
		
		CommonClientServer.SetFilterItem(FilterGroup,
			"Type", Type("DocumentRef.IncomingEmail"), DataCompositionComparisonType.Equal,, True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"DeletionMark", False, DataCompositionComparisonType.Equal, , True);
		
	ElsIf InteractionType = "MessageDrafts" Then
		
		CommonClientServer.SetFilterItem(FilterGroup,
			"Type", Type("DocumentRef.OutgoingEmail"), DataCompositionComparisonType.Equal, , True);
		CommonClientServer.SetFilterItem(
			FilterGroup, "DeletionMark", False, DataCompositionComparisonType.Equal, , True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"OutgoingEmailStatus", PredefinedValue("Enum.OutgoingEmailStatuses.Draft"),
			DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "OutgoingMessages" Then
		
		CommonClientServer.SetFilterItem(FilterGroup,
		"Type", Type("DocumentRef.OutgoingEmail"),DataCompositionComparisonType.Equal,, True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"DeletionMark", False,DataCompositionComparisonType.Equal,, True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"OutgoingEmailStatus", PredefinedValue("Enum.OutgoingEmailStatuses.Outgoing"),DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "SentMessages" Then
		
		CommonClientServer.SetFilterItem(FilterGroup,
			"Type", Type("DocumentRef.OutgoingEmail"),DataCompositionComparisonType.Equal,, True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"DeletionMark", False,DataCompositionComparisonType.Equal,, True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"OutgoingEmailStatus", PredefinedValue("Enum.OutgoingEmailStatuses.Sent"),
			DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "DeletedMessages" Then
		
		EmailTypesList = New ValueList;
		EmailTypesList.Add(Type("DocumentRef.IncomingEmail"));
		EmailTypesList.Add(Type("DocumentRef.OutgoingEmail"));
		CommonClientServer.SetFilterItem(FilterGroup,
			"Type", EmailTypesList, DataCompositionComparisonType.InList,, True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"DeletionMark", True,DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "Meetings" Then
		
		CommonClientServer.SetFilterItem(FilterGroup, 
			"Type", Type("DocumentRef.Meeting"),DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "PlannedInteractions" Then
		
		CommonClientServer.SetFilterItem(FilterGroup,
			"Type", Type("DocumentRef.PlannedInteraction"),DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "PhoneCalls" Then
		
		CommonClientServer.SetFilterItem(FilterGroup, 
			"Type", Type("DocumentRef.PhoneCall"),DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "OutgoingCalls" Then
		
		CommonClientServer.SetFilterItem(FilterGroup,
			"Type", Type("DocumentRef.PhoneCall"),DataCompositionComparisonType.Equal,, True);
		CommonClientServer.SetFilterItem(FilterGroup, 
			"Incoming",False,DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "IncomingCalls" Then
		
		CommonClientServer.SetFilterItem(FilterGroup, 
			"Type", Type("DocumentRef.PhoneCall"),DataCompositionComparisonType.Equal,, True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"Incoming", True, DataCompositionComparisonType.Equal,, True);
			
	ElsIf InteractionType = "SMSMessages" Then
		
		CommonClientServer.SetFilterItem(FilterGroup, 
			"Type", Type("DocumentRef.SMSMessage"),DataCompositionComparisonType.Equal,, True);
	Else
			
		Filter.Items.Delete(FilterGroup);
		
	EndIf;
	
EndProcedure

// Parameters:
//  Name     - String - a recipient's name.
//  Address   - String - an addressee email address.
//  Contact - CatalogRef - a contact that owns the name and email address.
//
// Returns:
//   String - Generated presentation of the addressee.
//
Function GetAddresseePresentation(Name, Address, Contact) Export
	
	Result = ?(Name = Address Or Name = "", Address, ?(IsBlankString(Address), Name, ?(StrFind(Name, Address) > 0, Name, Name + " <" + Address + ">")));
	If ValueIsFilled(Contact) And TypeOf(Contact) <> Type("String") Then
		Result = Result + " [" + GetContactPresentation(Contact) + "]";
	EndIf;
	
	Return Result;
	
EndFunction

// Parameters:
//  AddresseesTable    - ValueTable - Table with addressee data.
//  IncludeContactName - Boolean - Flag indicating whether to include it in contact details into the presentation.
//  Contact - CatalogRef - Contact the name and email address belongs to.
//
// Returns:
//  String - Generated presentation of the email addressee list.
//
Function GetAddressesListPresentation(AddresseesTable, IncludeContactName = True) Export

	Presentation = "";
	For Each TableRow In AddresseesTable Do
		Presentation = Presentation 
	              + GetAddresseePresentation(TableRow.Presentation,
	                                              TableRow.Address, 
	                                             ?(IncludeContactName, TableRow.Contact, "")) + "; ";
	EndDo;

	Return Presentation;

EndFunction

// Parameters:
//  InteractionObject - DocumentObject - an interaction document being checked.
//  DocumentKind - String - a document name.
//
// Returns:
//  Boolean - True if contacts are specified. Otherwise, False.
//
Function ContactsFilled(InteractionObject, DocumentKind)
	
	TabularSectionsArray = New Array;
	
	If DocumentKind = "OutgoingEmail" Then
		
		TabularSectionsArray.Add("EmailRecipients");
		TabularSectionsArray.Add("CCRecipients");
		TabularSectionsArray.Add("ReplyRecipients");
		TabularSectionsArray.Add("BccRecipients");
		
	ElsIf DocumentKind = "IncomingEmail" Then
		
		If Not ValueIsFilled(InteractionObject.SenderContact) Then
			Return False;
		EndIf;
		
		TabularSectionsArray.Add("EmailRecipients");
		TabularSectionsArray.Add("CCRecipients");
		TabularSectionsArray.Add("ReplyRecipients");
		
	ElsIf DocumentKind = "Meeting" 
		Or DocumentKind = "PlannedInteraction" Then
				
		TabularSectionsArray.Add("Attendees");
		
	ElsIf DocumentKind = "SMSMessage" Then
		
		TabularSectionsArray.Add("SMSMessageRecipients");
		
	ElsIf DocumentKind = "PhoneCall" Then
		
		If Not ValueIsFilled(InteractionObject.SubscriberContact) Then
			Return False;
		EndIf;
		
	EndIf;
	
	For Each TabularSectionName In TabularSectionsArray Do
		For Each LineOfATabularSection In InteractionObject[TabularSectionName] Do
			
			If Not ValueIsFilled(LineOfATabularSection.Contact) Then
				Return False;
			EndIf;
			
		EndDo;
	EndDo;
	
	Return True;
	
EndFunction

Procedure SetGroupItemsProperty(Items_Group, PropertyName, PropertyValue) Export
	
	For Each SubordinateItem In Items_Group.ChildItems Do
		
		If TypeOf(SubordinateItem) = Type("FormGroup") Then
			
			SetGroupItemsProperty(SubordinateItem, PropertyName, PropertyValue);
			
		Else
			
			SubordinateItem[PropertyName] = PropertyValue;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetContactPresentation(Contact)

	Return String(Contact);

EndFunction

// Parameters:
//  List  - DynamicList - a list, whose filter has to be determined.
//
// Returns:
//   Filter   - Filter.
//
Function DynamicListFilter(List) Export

	Return List.SettingsComposer.FixedSettings.Filter;

EndFunction

// Parameters:
//  ObjectManager     - DocumentObject.PhoneCall
//                      - DocumentObject.PlannedInteraction
//                      - DocumentObject.SMSMessage
//                      - DocumentObject.Meeting
//                      - DocumentObject.IncomingEmail
//                      - DocumentObject.OutgoingEmail - Interaction whose presentation is received.
//  Data              - Structure:
//                        * StartDate - Date - the beginning of the scheduled interaction.
//  Presentation        - String - a generated presentation.
//  StandardProcessing - Boolean - indicates whether standard processing is necessary.
//
Procedure PresentationGetProcessing(ObjectManager, Data, Presentation, StandardProcessing) Export
	
	Subject = InteractionSubject1(Data.Subject);
	Date = Format(Data.Date, "DLF=D");
	DocumentType = "";
	If TypeOf(ObjectManager) = Type("DocumentManager.Meeting") Then
		DocumentType = NStr("en = 'Appointment';");
		Date = Format(Data.StartDate, "DLF=D");
	ElsIf TypeOf(ObjectManager) = Type("DocumentManager.PlannedInteraction") Then
		DocumentType = NStr("en = 'Scheduled interaction';");
	ElsIf TypeOf(ObjectManager) = Type("DocumentManager.SMSMessage") Then
		DocumentType = NStr("en = 'SMS';");
	ElsIf TypeOf(ObjectManager) = Type("DocumentManager.PhoneCall") Then
		DocumentType = NStr("en = 'Phone call';");
	ElsIf TypeOf(ObjectManager) = Type("DocumentManager.IncomingEmail") Then
		DocumentType = NStr("en = 'Incoming mail';");
	ElsIf TypeOf(ObjectManager) = Type("DocumentManager.OutgoingEmail") Then
		DocumentType = NStr("en = 'Outgoing mail';");
	EndIf;
	
	TemplateOfPresentation = NStr("en = '%1, %2 (%3)';");
	Presentation = StringFunctionsClientServer.SubstituteParametersToString(TemplateOfPresentation, Subject, Date, DocumentType);
	
	StandardProcessing = False;
	 
EndProcedure

// Receives the fields required for generating a presentation for interactions.
// 
// Parameters:
//  ObjectManager - DocumentObject.PhoneCall
//                  - DocumentObject.PlannedInteraction
//                  - DocumentObject.SMSMessage
//                  - DocumentObject.Meeting
//                  - DocumentObject.IncomingEmail
//                  - DocumentObject.OutgoingEmail - Interaction whose presentation is received.
//  Fields                  - Array - an array that contains names of fields that are required to generate presentation of an object or a reference.
//  StandardProcessing  - Boolean - indicates whether standard processing is necessary.
//
Procedure PresentationFieldsGetProcessing(ObjectManager, Fields, StandardProcessing) Export
	
	Fields.Add("Subject");
	Fields.Add("Date");
	If TypeOf(ObjectManager) = Type("DocumentManager.Meeting") Then
		Fields.Add("StartDate");
	EndIf;
	StandardProcessing = False;
	
EndProcedure

Function EmailFileExtensionsArray()
	
	FileExtensionsArray = New Array;
	FileExtensionsArray.Add("msg");
	FileExtensionsArray.Add("eml");
	
	Return FileExtensionsArray;
	
EndFunction

Function InteractionSubject1(Subject) Export

	Return ?(IsBlankString(Subject), NStr("en = '<No Subject>';"), Subject);

EndFunction 

#EndRegion
