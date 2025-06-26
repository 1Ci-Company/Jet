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
	
	SubjectOf = Parameters.SubjectOf;
	MailMessage  = Parameters.MailMessage;
	DoNotChangePresentationOnChangeContact = (TypeOf(MailMessage) = Type("DocumentRef.IncomingEmail"));
	
	For Each SelectedListItem In Parameters.SelectedItemsList Do
	
		For Each ArrayElement In SelectedListItem.Value Do
			
			SearchParameters = New Structure;
			SearchParameters.Insert("Address", ArrayElement.Address);
			
			FoundRows = TableOfContacts.FindRows(SearchParameters);
			
			If FoundRows.Count() > 0 Then
				
				ContactRow = FoundRows[0];
				
				If Not ValueIsFilled(ContactRow.Contact)
					And ValueIsFilled(ArrayElement.Contact) Then
					
					ContactRow.Contact = ArrayElement.Contact;
					
				EndIf;
				
			Else
				
				NewRow = TableOfContacts.Add();
				FillPropertyValues(NewRow,ArrayElement);
				NewRow.Group = SelectedListItem.Presentation;
				NewRow.FullPresentation = InteractionsClientServer.GetAddresseePresentation(
				ArrayElement.Presentation,ArrayElement.Address, "");
				
			EndIf;
			
		EndDo;
	
	EndDo;
	
	FillFoundContactsListsByEmail();
	FillCurrentEmailContactsTables();
	DefineEditAvailabilityForContacts();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("SaveAndLoad", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ContactSelected" Then
		
		CurrentData = Items.TableOfContacts.CurrentData;
		CurrentData.Contact = Parameter.SelectedContact;
		FillContactAddresses(Items.TableOfContacts.CurrentRow);
		SetClearFlagChangeIfRequired(CurrentData);
		Modified = True;
	
	EndIf;

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure TableOfContactsOnActivateCell(Item)
	
	CurrentData = Items.TableOfContacts.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Item.CurrentItem.Name = "TableOfContactsContact" Then
		
		Items.TableOfContactsContact.ChoiceList.Clear();
		If CurrentData.FoundContactsList.Count() > 0 Then
			Items.TableOfContactsContact.ChoiceList.LoadValues(
			CurrentData.FoundContactsList.UnloadValues());
		EndIf;
		
	ElsIf Item.CurrentItem.Name = "ContactsTableContactCurrentAddress" Then
		
		Items.ContactsTableContactCurrentAddress.ChoiceList.Clear();
		If CurrentData.ContactAddressesTable.Count() > 0 Then
			For Each AddressesTableRow In CurrentData.ContactAddressesTable Do
				Items.ContactsTableContactCurrentAddress.ChoiceList.Add(
				   New Structure("Kind,Address",AddressesTableRow.Kind, AddressesTableRow.EMAddress),
				   GenerateAddressPresentationAndKind(AddressesTableRow.EMAddress, AddressesTableRow.DescriptionKind));
			EndDo;
			
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactsTableContactCurrentAddressClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ContactsTableContactCurrentAddressChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.TableOfContacts.CurrentData;
	If CurrentData = Undefined Then
		Return ;
	EndIf;
	
	If TypeOf(ValueSelected) = Type("Structure") 
		And (ValueSelected.Address <> CurrentData.CurrentContactAddress 
		Or ValueSelected.Kind <> CurrentData.CurrentContactInformationKind) Then
			
		CurrentData.CurrentContactAddress = ValueSelected.Address;
		CurrentData.CurrentContactInformationKind = ValueSelected.Kind;
		CurrentData.CurrentContactAddressPresentation = GenerateAddressPresentationAndKind(
			ValueSelected.Address,ValueSelected.Kind);
			
		SetClearFlagChangeIfRequired(CurrentData);
		
	EndIf;
	
EndProcedure 

&AtClient
Procedure TableOfContactsContactChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.TableOfContacts.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.Contact <> ValueSelected Then
		
		CurrentData.Contact = ValueSelected;
		Modified    = True;
		
		SetClearFlagChangeIfRequired(CurrentData);
		
		If Not ValueIsFilled(ValueSelected) Then
			
			OnClearContact(CurrentData);
			
		Else
			
			FillContactAddresses(Items.TableOfContacts.CurrentRow);
			
		EndIf;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TableOfContactsContactClearing(Item, StandardProcessing)
	
	CurrentData = Items.TableOfContacts.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OnClearContact(CurrentData);
	SetClearFlagChangeIfRequired(CurrentData);
	Modified = True;
	
EndProcedure

&AtClient
Procedure TableOfContactsContactOnChange(Item)
	
	CurrentData = Items.TableOfContacts.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentData.Contact) Then
		OnClearContact(CurrentData);
	Else
		FillContactAddresses(Items.TableOfContacts.CurrentRow);
	EndIf;
	
	SetClearFlagChangeIfRequired(CurrentData);
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure TableOfContactsContactStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Items.TableOfContacts.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("EmailOnly",                       True);
	OpeningParameters.Insert("PhoneOnly",                     False);
	OpeningParameters.Insert("ReplaceEmptyAddressAndPresentation", False);
	OpeningParameters.Insert("ForContactSpecificationForm",        True);
	OpeningParameters.Insert("FormIdentifier",                UUID);
	
	InteractionsClient.SelectContact(
			SubjectOf, CurrentData.Address, CurrentData.Presentation,
			CurrentData.Contact, OpeningParameters);
	
EndProcedure

&AtClient
Procedure TableOfContactsBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OkCommandExecute()
	
	SaveAndLoad();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TableOfContactsChange.Name);
	
	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TableOfContacts.Address");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = New DataCompositionField("TableOfContacts.CurrentContactAddress");

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TableOfContacts.Contact");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TableOfContacts.Address");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Enabled", False);
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TableOfContactsChange.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue  = New DataCompositionField("TableOfContacts.AvailableUpdate");
	ItemFilter.ComparisonType   = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
EndProcedure

&AtClient
Procedure SaveAndLoad(Result = Undefined, AdditionalParameters = Undefined) Export
	
	SelectionResult = New Array;
	HasContactInformationForUpdate = False;
	For Each ContactsTableRow In TableOfContacts Do
		
		If ContactsTableRow.Change Then
			HasContactInformationForUpdate = True;
		EndIf;
	
		StructureData = New Structure;
		
		StructureData.Insert("Presentation", ContactsTableRow.Presentation);
		StructureData.Insert("Address", ContactsTableRow.Address);
		StructureData.Insert("Contact", ContactsTableRow.Contact);
		StructureData.Insert("Group", ContactsTableRow.Group);
		
		SelectionResult.Add(StructureData);
		
	EndDo;
	
	If HasContactInformationForUpdate Then
		ChangeContactInformationForSelectedContacts();
	EndIf;
	
	IsCloseCommandExecuted = True;
	
	If Not Modified Then
		Close();
		Return;
	Else
		Modified = False;
	EndIf;
	
	NotifyChoice(SelectionResult);
	
EndProcedure

// Returns the string data of the Found contacts table.
// 
// Parameters:
//  SelectedRow  - FormDataCollectionItem - the string whose data is being received.
//
// Returns:
//  Structure:
//   * OwnerDescription1 - String
//   * Description          - String
//   * Presentation         - String
//   * Ref                - DefinedType.InteractionContact
//
&AtServer
Function FoundContactsRowData(SelectedRow)
	
	Return SelectedRow;
	
EndFunction

&AtServer
Procedure FillFoundContactsListsByEmail()
	
	// Getting an address list, for which emails are not specified.
	AddressesArray = New Array;
	For Each TableRow In TableOfContacts Do
		If Not IsBlankString(TableRow.Address) Then
			AddressesArray.Add(TableRow.Address);
		EndIf;
	EndDo;
	
	// If emails are specified for all addresses, do not search.
	If AddressesArray.Count() = 0 Then
		Return;
	EndIf;
	
	// Finding contacts by emails.
	FoundContacts = Interactions.GetAllContactsByEmailList(AddressesArray);
	If FoundContacts.Rows.Count() = 0 Then
		Return;
	EndIf;
	
	For Each TableRow In FoundContacts.Rows Do
		TableRow.Presentation = Upper(TableRow.Presentation);
	EndDo;
	
	// Filling in each row with a found contact list.
	For Each TableRow In TableOfContacts Do
		If Not IsBlankString(TableRow.Address)  Then
			Var_Group = FoundContacts.Rows.Find(Upper(TableRow.Address), "Presentation");
			If Var_Group = Undefined Then
				Continue;
			EndIf;
			
			For Each Var_Group In Var_Group.Rows Do 
			
				GroupRow = FoundContactsRowData(Var_Group);
				If TableRow.FoundContactsList.FindByValue(Var_Group.Contact) = Undefined Then
					ContactPresentation = GroupRow.Description + ?(IsBlankString(GroupRow.OwnerDescription1), "", " (" + GroupRow.OwnerDescription1 + ")");
					TableRow.FoundContactsList.Add(GroupRow.Contact, ContactPresentation);
				EndIf;
				
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function GenerateAddressPresentationAndKind(Address, CIKind)

	If IsBlankString(Address) Then
		Return String(CIKind);
	Else
		Return String(CIKind) + " (" + Address + ")";
	EndIf;
	
EndFunction

&AtServer
Procedure FillCurrentEmailContactsTables()
	
	ContactsTypesDetailsArray = InteractionsClientServer.ContactsDetails();
	PredefinedItemsNames = Metadata.Catalogs.ContactInformationKinds.GetPredefinedNames();
	
	QueryText = "SELECT ALLOWED DISTINCT
	|	Contacts.Contact
	|INTO AllContacts
	|FROM
	|	&Contacts AS Contacts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Contacts.Contact
	|INTO Contacts
	|FROM
	|	AllContacts AS Contacts
	|WHERE
	|	Contacts.Contact <> UNDEFINED
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ContactInformationKinds.Ref AS Kind,
	|	ContactInformationKinds.Description AS DescriptionKind,
	|	TableOfContacts.Ref AS Contact
	|INTO UsersContactInformationKinds
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds,
	|	Catalog.Users AS TableOfContacts
	|WHERE
	|	ContactInformationKinds.Parent = VALUE(Catalog.ContactInformationKinds.CatalogUsers)
	|	AND ContactInformationKinds.Type = VALUE(Enum.ContactInformationTypes.Email)
	|	AND TableOfContacts.Ref IN
	|			(SELECT
	|				Contacts.Contact
	|			FROM
	|				Contacts AS Contacts)
	|;"; 
	
	For Each DetailsArrayElement In ContactsTypesDetailsArray Do

		If DetailsArrayElement.Name = "Users" Then
			Continue;
		EndIf;
		
		VariantName = "Catalog" + DetailsArrayElement.Name;
		If PredefinedItemsNames.Find(VariantName) <> Undefined Then
			FilterOption = "VALUE(Catalog.ContactInformationKinds." + VariantName + ")";
		Else
			FilterOption = """" + VariantName +"""";
		EndIf;
		
		QueryText = QueryText + "
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactInformationKinds.Ref AS Kind,
		|	ContactInformationKinds.Description AS DescriptionKind,
		|	TableOfContacts.Ref AS Contact
		|INTO TemporaryTableTypesOfCI
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds,
		|	&CatalogName AS TableOfContacts
		|WHERE
		|	ContactInformationKinds.GroupName = &FilterOption
		|	AND ContactInformationKinds.Type = VALUE(Enum.ContactInformationTypes.Email)
		|	AND TableOfContacts.Ref IN
		|			(SELECT
		|				Contacts.Contact
		|			FROM
		|				Contacts AS Contacts)
		|	AND &TheConditionForTheGroup
		|;";
		
		QueryText = StrReplace(QueryText, "TemporaryTableTypesOfCI", DetailsArrayElement.Name + "CIKinds");
		QueryText = StrReplace(QueryText, "&CatalogName",        "Catalog." + DetailsArrayElement.Name);
		QueryText = StrReplace(QueryText, "&FilterOption",         FilterOption);
		QueryText = StrReplace(QueryText, "AND &TheConditionForTheGroup",
			?(DetailsArrayElement.Hierarchical,"AND (NOT TableOfContacts.IsFolder)",""));
		
	EndDo;
	
	QueryText = QueryText + "
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ContactsCIKinds.Contact,
	|	ISNULL(ContactInformation.EMAddress, """") AS EMAddress,
	|	ContactsCIKinds.Kind,
	|	ContactsCIKinds.DescriptionKind AS DescriptionKind
	|FROM
	|	UsersContactInformationKinds AS ContactsCIKinds
	|		LEFT JOIN Catalog.Users.ContactInformation AS ContactInformation
	|		ON ContactsCIKinds.Contact = ContactInformation.Ref
	|			AND ContactsCIKinds.Kind = ContactInformation.Kind";
	
	For Each DetailsArrayElement In ContactsTypesDetailsArray Do
		
		If DetailsArrayElement.Name = "Users" Then
			Continue;
		EndIf;
		
		QueryText = QueryText + "
		|
		|UNION ALL
		|
		|SELECT
		|	ContactsCIKinds.Contact,
		|	ISNULL(ContactInformation.EMAddress, """"),
		|	ContactsCIKinds.Kind,
		|	ContactsCIKinds.DescriptionKind
		|
		|FROM
		|	&TableNameTypesOfCI AS ContactsCIKinds
		|		LEFT JOIN &TableNameContactInformation AS ContactInformation
		|		ON ContactsCIKinds.Kind = ContactInformation.Kind
		|			AND ContactsCIKinds.Contact = ContactInformation.Ref"; // @query-part-1
		
		QueryText = StrReplace(QueryText, "&TableNameTypesOfCI",               DetailsArrayElement.Name + "CIKinds");
		QueryText = StrReplace(QueryText, "&TableNameContactInformation", "Catalog." + DetailsArrayElement.Name + ".ContactInformation");
	
	EndDo;
	
	QueryText = QueryText + "
		|
		|TOTALS BY
		|	Contact"; // @query-part-1

	Query = New Query(QueryText);
	Query.SetParameter("Contacts",TableOfContacts.Unload());
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	ResultsTree = Result.Unload(QueryResultIteration.ByGroups);
	
	For Each ContactsTableRow In TableOfContacts Do
		If ValueIsFilled(ContactsTableRow.Contact) Then
			FoundRow = ResultsTree.Rows.Find(ContactsTableRow.Contact, "Contact");
			If FoundRow <> Undefined Then
				
				FillAddressesTableFromCollection(ContactsTableRow, FoundRow.Rows);
				
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillAddressesTableFromCollection(ContactsTableRow, Collection)
	
	ContactsTableRow.ContactAddressesTable.Clear();
	ContactsTableRow.CurrentContactAddress              = "";
	ContactsTableRow.CurrentContactInformationKind    = Catalogs.ContactInformationKinds.EmptyRef();
	ContactsTableRow.CurrentContactAddressPresentation = "";
	
	If Collection = Undefined Then
		Return;
	EndIf;
	
	AddressesMappingWasFound = False;
	
	For Each CollectionRow In Collection Do
		
		NewAddressesTableRow = ContactsTableRow.ContactAddressesTable.Add();
		FillPropertyValues(NewAddressesTableRow, CollectionRow);
		If Upper(ContactsTableRow.Address) = Upper(CollectionRow.EMAddress) Then
			ContactsTableRow.CurrentContactAddress              = ContactsTableRow.Address;
			ContactsTableRow.CurrentContactInformationKind    = CollectionRow.Kind;
			ContactsTableRow.CurrentContactAddressPresentation = 
				GenerateAddressPresentationAndKind(ContactsTableRow.Address, CollectionRow.DescriptionKind);
			AddressesMappingWasFound = True;
		EndIf;
		
	EndDo;
	
	If (Not AddressesMappingWasFound) And Collection.Count() > 0 Then
		
		ContactsTableRow.CurrentContactAddress              = Collection[0].EMAddress;
		ContactsTableRow.CurrentContactInformationKind    = Collection[0].Kind;
		ContactsTableRow.CurrentContactAddressPresentation = 
			GenerateAddressPresentationAndKind(Collection[0].EMAddress,Collection[0].Kind);
		ContactsTableRow.Change                          = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClearContact(CurrentData)

	CurrentData.FoundContactsList.Clear();
	CurrentData.ContactAddressesTable.Clear();
	CurrentData.Presentation                     = "";
	CurrentData.CurrentContactAddress              = "";
	CurrentData.CurrentContactInformationKind    =
		PredefinedValue("Catalog.ContactInformationKinds.EmptyRef");
	CurrentData.CurrentContactAddressPresentation = "";

EndProcedure

&AtServer
Procedure ChangeContactInformationForSelectedContacts()
	
	OutgoingEmailMetadata = Metadata.Documents.OutgoingEmail;
	IncomingEmailMetadata = Metadata.Documents.IncomingEmail;
	
	Query = New Query;
	Query.Text = "SELECT
	|	TableOfContacts.Contact,
	|	TableOfContacts.Address,
	|	TableOfContacts.CurrentContactInformationKind,
	|	TableOfContacts.Change
	|INTO AllContacts
	|FROM
	|	&TableOfContacts AS TableOfContacts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AllContacts.Contact,
	|	AllContacts.Address,
	|	AllContacts.CurrentContactInformationKind AS Kind
	|FROM
	|	AllContacts AS AllContacts
	|WHERE
	|	AllContacts.Change";
	
	Query.SetParameter("TableOfContacts", TableOfContacts.Unload());
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		BeginTransaction();
		Try
			
			ContactMetadata = Selection.Contact.Metadata();
			Block = New DataLock;
			LockItem = Block.Add(ContactMetadata.FullName());
			LockItem.SetValue("Ref", Selection.Contact);
			Block.Lock();
			
			ContactsManager.AddContactInformation(Selection.Contact, Selection.Address, Selection.Kind, , True);
			
			Query = New Query;
			Query.Text = "
			|SELECT
			|	EmailIncomingEmailRecipients.Ref AS Ref,
			|	EmailIncomingEmailRecipients.Address,
			|	EmailIncomingEmailRecipients.Contact,
			|	""EmailRecipients"" AS TabularSectionName
			|FROM
			|	Document.IncomingEmail.EmailRecipients AS EmailIncomingEmailRecipients
			|WHERE
			|	EmailIncomingEmailRecipients.Address = &Address
			|	AND EmailIncomingEmailRecipients.Contact = UNDEFINED
			|	AND EmailIncomingEmailRecipients.Ref <> &MailMessage
			|
			|UNION ALL
			|
			|SELECT
			|	EmailIncomingCopyRecipients.Ref,
			|	EmailIncomingCopyRecipients.Address,
			|	EmailIncomingCopyRecipients.Contact,
			|	""CCRecipients""
			|FROM
			|	Document.IncomingEmail.CCRecipients AS EmailIncomingCopyRecipients
			|WHERE
			|	EmailIncomingCopyRecipients.Address = &Address
			|	AND EmailIncomingCopyRecipients.Contact = UNDEFINED
			|	AND EmailIncomingCopyRecipients.Ref <> &MailMessage
			|
			|UNION ALL
			|
			|SELECT
			|	IncomingEmail.Ref,
			|	IncomingEmail.SenderAddress,
			|	IncomingEmail.SenderContact,
			|	""Sender""
			|FROM
			|	Document.IncomingEmail AS IncomingEmail
			|WHERE
			|	IncomingEmail.SenderAddress = &Address
			|	AND IncomingEmail.SenderContact = UNDEFINED
			|	AND IncomingEmail.Ref <> &MailMessage
			|
			|UNION ALL
			|
			|SELECT
			|	EmailOutgoingEmailRecipients.Ref,
			|	EmailOutgoingEmailRecipients.Address,
			|	EmailOutgoingEmailRecipients.Contact,
			|	""EmailRecipients""
			|FROM
			|	Document.OutgoingEmail.EmailRecipients AS EmailOutgoingEmailRecipients
			|WHERE
			|	EmailOutgoingEmailRecipients.Address = &Address
			|	AND EmailOutgoingEmailRecipients.Contact = UNDEFINED
			|	AND EmailOutgoingEmailRecipients.Ref <> &MailMessage
			|
			|UNION ALL
			|
			|SELECT
			|	EMailOutgoingCopyRecipients.Ref,
			|	EMailOutgoingCopyRecipients.Address,
			|	EMailOutgoingCopyRecipients.Contact,
			|	""CCRecipients""
			|FROM
			|	Document.OutgoingEmail.CCRecipients AS EMailOutgoingCopyRecipients
			|WHERE
			|	EMailOutgoingCopyRecipients.Address = &Address
			|	AND EMailOutgoingCopyRecipients.Contact = UNDEFINED
			|	AND EMailOutgoingCopyRecipients.Ref <> &MailMessage
			|
			|UNION ALL
			|
			|SELECT
			|	EmailOutgoingRecipientsOfHiddenCopies.Ref,
			|	EmailOutgoingRecipientsOfHiddenCopies.Address,
			|	EmailOutgoingRecipientsOfHiddenCopies.Contact,
			|	""BccRecipients""
			|FROM
			|	Document.OutgoingEmail.BccRecipients AS EmailOutgoingRecipientsOfHiddenCopies
			|WHERE
			|	EmailOutgoingRecipientsOfHiddenCopies.Address = &Address
			|	AND EmailOutgoingRecipientsOfHiddenCopies.Contact = UNDEFINED
			|	AND EmailOutgoingRecipientsOfHiddenCopies.Ref <> &MailMessage
			|TOTALS BY
			|	Ref";
			
			Query.SetParameter("Address", Selection.Address);
			Query.SetParameter("MailMessage", MailMessage);
			
			// @skip-check query-in-loop - Batch processing of great number of email messages by contacts. 
			Result = Query.Execute();
			OutgoingEmailsArray = New Array;
			IncomingEmailsArray  = New Array;
			
			EmailSelection = Result.Select(QueryResultIteration.ByGroups);
			While EmailSelection.Next() Do
				
				If TypeOf(EmailSelection.Ref) = Type("DocumentRef.IncomingEmail") Then
					IncomingEmailsArray.Add(EmailSelection.Ref);
				Else
					OutgoingEmailsArray.Add(EmailSelection.Ref);
				EndIf;
				
			EndDo;
			
			If IncomingEmailsArray.Count() > 0 Then
				
				Block = New DataLock;
				LockItem = Block.Add(IncomingEmailMetadata.FullName());
				
				LockSource = New ValueTable;
				LockSource.Columns.Add("MailMessage", New TypeDescription("DocumentRef.IncomingEmail"));
				LockSource.LoadColumn(IncomingEmailsArray, "MailMessage");
				
				LockItem.DataSource = LockSource;
				LockItem.UseFromDataSource("Ref", "MailMessage");
				
				Block.Lock();
				
			EndIf;
			
			If OutgoingEmailsArray.Count() > 0 Then
				
				Block = New DataLock;
				LockItem = Block.Add(OutgoingEmailMetadata.FullName());
				
				LockSource = New ValueTable;
				LockSource.Columns.Add("MailMessage", New TypeDescription("DocumentRef.OutgoingEmail"));
				LockSource.LoadColumn(OutgoingEmailsArray, "MailMessage");
				
				LockItem.DataSource = LockSource;
				LockItem.UseFromDataSource("Ref", "MailMessage");
				
				Block.Lock();
				
			EndIf;
			
			EmailSelection.Reset();
			
			EmailSelection = Result.Select(QueryResultIteration.ByGroups);
			While EmailSelection.Next() Do
				
				EmailObject = EmailSelection.Ref.GetObject();
				EmailDetailsSelection = EmailSelection.Select();
				While EmailDetailsSelection.Next() Do
					If EmailDetailsSelection.TabularSectionName = "Sender" Then
						EmailObject.SenderContact = Selection.Contact;
					Else
						FoundRows = 
							EmailObject[EmailDetailsSelection.TabularSectionName].FindRows(New Structure("Address", Selection.Address));
						For Each FoundRow In FoundRows Do
							If Not ValueIsFilled(FoundRow.Contact) Then
								FoundRow.Contact = Selection.Contact;
							EndIf;
						EndDo;
					EndIf;
				EndDo;
				
				EmailObject.Write();
				
			EndDo;
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot update the %1 contact information due to:
				|%2';", Common.DefaultLanguageCode()),
				Selection.Contact, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
			WriteLogEvent(EmailManagement.EventLogEvent(),
				EventLogLevel.Error, , , ErrorMessageText);
			
			Continue;
		EndTry;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SetClearFlagChangeIfRequired(CurrentData)
	
	If (Not ValueIsFilled(CurrentData.Address) 
		Or Not ValueIsFilled(CurrentData.Contact) 
		Or Upper(CurrentData.Address) = Upper(CurrentData.CurrentContactAddress)
		Or Not CurrentData.AvailableUpdate) Then
		
		CurrentData.Change = False;
		
	Else
		
		CurrentData.Change = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillContactAddresses(CurrentRow)
	
	CurrentData  = TableOfContacts.FindByID(CurrentRow);
	AddressesTable = InteractionsServerCall.GetContactEmailAddresses(CurrentData.Contact,True);
	
	If (Not DoNotChangePresentationOnChangeContact) Or IsBlankString(CurrentData.Presentation) Then
		CurrentData.Presentation = String(CurrentData.Contact);
	EndIf;
	FillAddressesTableFromCollection(CurrentData, AddressesTable);
	
	DefineEditAvailabilityForContacts();

EndProcedure

&AtServer
Procedure DefineEditAvailabilityForContacts()

	For Each RowContact In TableOfContacts Do
	
		If Not ValueIsFilled(RowContact.Contact) Then
			
			RowContact.AvailableUpdate = False;
			
		Else
			
			EditRight = AccessRight("Update", Metadata.FindByType(TypeOf(RowContact.Contact)));
			RowContact.AvailableUpdate = EditRight;
			If Not EditRight Then
				RowContact.AvailableUpdate = False;
			EndIf;
			
		EndIf;
		
		If Not RowContact.AvailableUpdate Then
			
			RowContact.Change = False;
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion
