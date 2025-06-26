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
	
	Interactions.ProcessUserGroupsDisplayNecessity(ThisObject);
	
	Interactions.AddContactsPickupFormPages(ThisObject);
	FillRecipientsTable();
	SetDefaultGroup();

	ContactInformationKinds = ContactsManager.ObjectContactInformationKinds(
		Catalogs.Users.EmptyRef(), Enums.ContactInformationTypes.Email);
	If ContactInformationKinds.Count() > 0 Then
		KindEmail = ContactInformationKinds[0].Ref;
	Else
		KindEmail = Undefined;
	EndIf;
	If UsersList.Parameters.Items.Find("Email") <> Undefined Then
		UsersList.Parameters.SetParameterValue("Email", KindEmail);
	EndIf;
	
	// Filling in contacts by the subject.
	SubjectOf = Parameters.SubjectOf;
	Interactions.FillContactsBySubject(Items, SubjectOf, ContactsBySubject, True);
	
	SearchOptions = "Everywhere";
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	UpdateSearchOptionsMenu();
	PagesManagement();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	InteractionsClient.DoProcessNotification(ThisObject, EventName, Parameter, Source);
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	OnChangeOnlyContactsWithAddresses(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)
	
	PagesManagement();
	
EndProcedure

&AtClient
Procedure ContactStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.EmailRecipients.CurrentData;
	OpeningParameters = New Structure;
	OpeningParameters.Insert("EmailOnly",                       True);
	OpeningParameters.Insert("PhoneOnly",                     False);
	OpeningParameters.Insert("ReplaceEmptyAddressAndPresentation", True);
	OpeningParameters.Insert("ForContactSpecificationForm",        False);
	OpeningParameters.Insert("FormIdentifier",                UUID);

	InteractionsClient.SelectContact(SubjectOf, CurrentData.Address, CurrentData.Presentation,
	                                    CurrentData.Contact,OpeningParameters)
	
EndProcedure

&AtClient
Procedure EmailRecipientsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		Item.CurrentData.Group = "Whom";
	EndIf;
	
EndProcedure

&AtClient
Procedure EmailRecipientsOnActivateCell(Item)
	
	If Item.CurrentItem.Name = "Address" Then
		Items.Address.ChoiceList.Clear();
		
		CurrentData = Items.EmailRecipients.CurrentData;
		If CurrentData = Undefined Then
			Return;
		EndIf;
		
		If Not IsBlankString(CurrentData.AddressesList) Then
			Items.Address.ChoiceList.LoadValues(
				StrSplit(CurrentData.AddressesList, ";"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactsBySubjectSelection(Item, RowSelected, Field, StandardProcessing)

	AddRecipientFromListBySubject();

EndProcedure

&AtClient
Procedure Attachable_CatalogListChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not ValueIsFilled(RowSelected) Then
		Return;
	EndIf;
	
	Result = InteractionsServerCall.ContactDescriptionAndEmailAddresses(RowSelected);
	If Result = Undefined Then
		Return;
	EndIf;
	
	Address = Result.Addresses[0];
	AddressesList = StrConcat(Result.Addresses.UnloadValues(), ";");
	
	AddRecipient(Address, Result.Description, RowSelected, AddressesList);
	
EndProcedure

// Universal handler of a dynamic list line activation with subordinate lists.
&AtClient
Procedure Attachable_ListOwnerOnActivateRow(Item)
	
	InteractionsClient.ContactOwnerOnActivateRow(Item, ThisObject);
	
EndProcedure

&AtClient
Procedure FoundContactsSelection(Item, RowSelected, Field, StandardProcessing)
	
	CurrentData = Items.FoundContacts.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Result = InteractionsServerCall.ContactDescriptionAndEmailAddresses(CurrentData.Ref);
	If Result <> Undefined And Result.Addresses.Count() > 0 Then
		AddressesList = StrConcat(Result.Addresses.UnloadValues(), ";");
	Else
		AddressesList = "";
	EndIf;
	
	AddRecipient(CurrentData.Presentation, CurrentData.ContactName, CurrentData.Ref, AddressesList);
	
EndProcedure

&AtClient
Procedure UserGroupsOnActivateRow(Item)
	
	UsersList.Parameters.SetParameterValue("UsersGroup", Items.UserGroups.CurrentRow);
	
EndProcedure

&AtClient
Procedure ShowOnlyContactsWithAddressesOnChange(Item)
	
	OnChangeOnlyContactsWithAddresses(ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// Passes to an owner a structure array 
// with selected recipient addresses and closes the form. 
//
&AtClient
Procedure OkCommandExecute()
	
	Result = New Array;
	
	For Each TableRow In EmailRecipients Do
		
		If IsBlankString(TableRow.Address) Then
			Continue;
		EndIf;
		Var_Group = ?(IsBlankString(TableRow.Group), "Whom", TableRow.Group);
		
		Contact = New Structure;
		Contact.Insert("Address", TableRow.Address);
		Contact.Insert("Presentation", TableRow.Presentation);
		Contact.Insert("Contact", TableRow.Contact);
		Contact.Insert("Group", Var_Group);
		Result.Add(Contact);
		
	EndDo;
	
	NotifyChoice(Result);
	
EndProcedure

// Moves the contact from the Contacts by subject list to the Email recipients list. 
//
&AtClient
Procedure AddFromSubjectsListExecute()

	AddRecipientFromListBySubject();

EndProcedure

// Changes the current group of email recipients to To group. 
//
&AtClient
Procedure ChangeGroupToExecute()

	ChangeGroup("Whom");

EndProcedure

// Changes the current group of email recipients to CC group. 
//
&AtClient
Procedure ChangeCcGroupExecute()

	ChangeGroup("Cc");

EndProcedure 

// Changes the current group of email recipients to BCC group. 
//
&AtClient
Procedure ChangeBCCGroupExecute()

	ChangeGroup("Hidden1");

EndProcedure

// Initiates a contact search process.
//
&AtClient
Procedure FindContactsExecute()
	
	If IsBlankString(SearchString) Then
		CommonClient.MessageToUser(NStr("en = 'Please enter text to search for.';"),, "SearchString");
		Return;
	EndIf;
	
	Result = "";
	FoundContacts.Clear();
	
	If SearchOptions = "Everywhere" Then
		Result = FindContacts();
	ElsIf SearchOptions = "ByEmail" Then
		FindByEmail(False);
	ElsIf SearchOptions = "ByDomain" Then
		FindByEmail(True);
	ElsIf SearchOptions = "ByLine" Then
		Result = ContactsFoundByString();
	ElsIf SearchOptions = "BeginsWith" Then
		FindByDescriptionBeginning();
	EndIf;
	
	If Not IsBlankString(Result) Then
		ShowMessageBox(, Result);
	EndIf;
	
EndProcedure

// Positions in the dynamic list position for the current contact 
// from the Found contacts list.
//
&AtClient
Procedure FindInListFromFoundItemsListExecute()
	
	CurrentData = Items.FoundContacts.CurrentData;
	If CurrentData <> Undefined And ValueIsFilled(CurrentData.Ref) Then
		SetContactAsCurrent(CurrentData.Ref);
	EndIf;
	
EndProcedure

// Positions in the dynamic list for the current contact
// from the Email recipients list.
//
&AtClient
Procedure FindInListFromRecipientsListExecute()
	
	CurrentData = Items.EmailRecipients.CurrentData;
	If CurrentData <> Undefined And ValueIsFilled(CurrentData.Contact) Then
		SetContactAsCurrent(CurrentData.Contact);
	EndIf;
	
EndProcedure

// Positions in the dynamic list for the current contact
// from Contacts by subject list.
//
&AtClient
Procedure FindInListFromSubjectsListExecute()
	
	CurrentData = Items.ContactsBySubject.CurrentData;
	If CurrentData <> Undefined Then
		SetContactAsCurrent(CurrentData.Ref);
	EndIf;
	
EndProcedure 

// Initiates a contacts search by email address of the current line of the Email recipients list. 
//
&AtClient
Procedure FindByAddressExecute()
	
	Items.PagesLists.CurrentPage = Items.SearchContactsPage;
	FoundContacts.Clear();

	CurrentData = Items.EmailRecipients.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;

	SearchString = CurrentData.Address;
	If Not IsBlankString(SearchString) Then
		FindByEmail(False);
	EndIf;

EndProcedure

// Initiates a contacts search by presentation of current line of the Email recipients list. 
//
&AtClient
Procedure FindByPresentationExecute()
	
	Items.PagesLists.CurrentPage = Items.SearchContactsPage;
	FoundContacts.Clear();
	
	CurrentData = Items.EmailRecipients.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	SearchString = CurrentData.Presentation;
	If Not IsBlankString(SearchString) Then
		Result = ContactsFoundByString();
		If Not IsBlankString(Result) Then
			ShowMessageBox(,Result);
		EndIf;
	EndIf;
	
EndProcedure 

// Searches all contact email addresses from the Email recipients list
 // and prompts the user to choose when a contact has more than one email address.
//
&AtClient
Procedure SetContactAddressExecute()
	
	CurrentData = Items.EmailRecipients.CurrentData;
	If CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select the recipient''s address in the list on the right.';"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentData.Contact) Then
		ContactStartChoice(Items.EmailRecipients, Undefined, True);
		Return;
	EndIf;
	
	Result = InteractionsServerCall.GetContactEmailAddresses(CurrentData.Contact);
	If Result.Count() = 0 Then
		ShowMessageBox(, 
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The following contact does not have an email: ""%1"".';"),
				CurrentData.Contact));
		Return;
	EndIf;

	If Result.Count() = 1 Then
		Address = Result[0].EMAddress;
		Presentation = Result[0].Presentation;
		SetSelectedContactAddressAndPresentation(CurrentData, Presentation, Address);
	Else
		ChoiceList = New ValueList;
		Number = 0;
		For Each Item In Result Do
			ChoiceList.Add(Number, Item.DescriptionKind + ": " + Item.EMAddress);
			Number = Number + 1;
		EndDo;
		
		ChoiceProcessingParameters = New Structure;
		ChoiceProcessingParameters.Insert("Result", Result);
		ChoiceProcessingParameters.Insert("CurrentData", CurrentData);

		OnCloseNotifyHandler = New NotifyDescription("DSAddressChoiceListAfterCompletion", ThisObject, ChoiceProcessingParameters);

		ChoiceList.ShowChooseItem(OnCloseNotifyHandler);
	EndIf;

EndProcedure

// Positions in the dynamic list for the current contact
// from Contacts by subject list.
//
&AtClient
Procedure SetContactFromSubjectsListExecute()
	
	CurrentData = Items.ContactsBySubject.CurrentData;
	If CurrentData <> Undefined Then
		SetContactInRecipientsList(CurrentData.Ref);
	EndIf;
	
EndProcedure 

&AtClient
Procedure DeleteAllRecipients(Command)
	
	EmailRecipients.Clear();
	
EndProcedure

&AtClient
Procedure DeleteRecipient(Command)
	
	SelectedRows = Items.EmailRecipients.SelectedRows;
	For Each SelectedRow In SelectedRows Do
		EmailRecipients.Delete(EmailRecipients.FindByID(SelectedRow));
	EndDo;
	
EndProcedure

// Returns the string data of the Found contacts table.
// 
// Parameters:
//  SelectedRow  - FormDataCollectionItem - the string whose data is being received.
//
// Returns:
//  Structure:
//   * ContactName - String
//   * CatalogName       - String
//   * Presentation        - String
//   * Ref               - DefinedType.InteractionContact
//
&AtClient
Function FoundContactsRowData(SelectedRow)
	
	Return Items.FoundContacts.RowData(SelectedRow);
	
EndFunction

&AtClient
Procedure AddToRecipientsList(Command)
	
	If Items.PagesLists.CurrentPage = Items.SearchContactsPage Then
		For Each SelectedRow In Items.FoundContacts.SelectedRows Do
			RowData = FoundContactsRowData(SelectedRow);
			AddRecipient(RowData.Presentation, RowData.ContactName, RowData.Ref);
		EndDo;
		Return;
	EndIf;
	
	FormItemNumber = Undefined;
	
	If Items.PagesLists.CurrentPage.ChildItems.Count() = 1 Then
		
		FormItemNumber = 0;
		
	ElsIf Items.PagesLists.CurrentPage.ChildItems.Count() = 2 Then
		
		If CurrentItem.Name = "MoveFromTopListToSelected" Then
			FormItemNumber = 0;
		Else
			FormItemNumber = 1;
		EndIf;
		
	EndIf;
	
	If FormItemNumber = Undefined Then
		Return;
	EndIf;
	
	MoveSelectedRows(
		Items.PagesLists.CurrentPage.ChildItems[FormItemNumber].SelectedRows);
	
EndProcedure

&AtClient
Procedure SearchEverywhereOption(Command)
	SearchOptions = "Everywhere";
	UpdateSearchOptionsMenu();
EndProcedure

&AtClient
Procedure SearchInAddressesOption(Command)
	SearchOptions = "ByEmail";
	UpdateSearchOptionsMenu();
EndProcedure

&AtClient
Procedure SearchInContactsDescriptionsOption(Command)
	SearchOptions = "ByLine";
	UpdateSearchOptionsMenu();
EndProcedure

&AtClient
Procedure SearchByDomainNameOption(Command)
	SearchOptions = "ByDomain";
	UpdateSearchOptionsMenu();
EndProcedure

&AtClient
Procedure View(Command)
	If Items.PagesLists.CurrentPage = Items.UsersPage Then
		CurrentData = Items.UsersList.CurrentData;
	ElsIf TypeOf(CurrentItem) = Type("FormTable") Then
		CurrentData = CurrentItem.CurrentData;
	Else
		Return;
	EndIf;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ShowValue(, CurrentData.Ref);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Search procedures and functions.

&AtServer
Function FindContacts()
	
	Return Interactions.FindContacts(SearchString, True, FoundContacts);
	
EndFunction

&AtServer
Procedure FindByEmail(ByDomain)
	
	Interactions.FindByEmail(SearchString, ByDomain, FoundContacts);
	
EndProcedure

&AtServer
Function ContactsFoundByString()
	
	Return Interactions.FullTextContactsSearchByRow(SearchString, FoundContacts, True);
	
EndFunction

&AtServer
Procedure FindByDescriptionBeginning()
	
	Interactions.FindContactsWithAddressesByDescription(SearchString, FoundContacts);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Miscellaneous.

&AtServer
Procedure FillRecipientsTable()
	
	RecipientsTab = FormAttributeToValue("EmailRecipients");
	
	For Each SelectedRecipientsGroup In Parameters.SelectedItemsList Do
		If SelectedRecipientsGroup.Value <> Undefined Then
			For Each Item In SelectedRecipientsGroup.Value Do
				NewRow = RecipientsTab.Add();
				NewRow.Group = SelectedRecipientsGroup.Presentation;
				FillPropertyValues(NewRow, Item);
			EndDo;
		EndIf;
	EndDo;
	
	RecipientsTab.Sort("Group");
	
	If RecipientsTab.Count() > 0 Then
		AddressesTable =
			Interactions.ContactsEmailAddresses(RecipientsTab.UnloadColumn("Contact"));
			
			Query = New Query;
			Query.Text = "
			|SELECT
			|	EmailRecipients.Address,
			|	EmailRecipients.Presentation,
			|	EmailRecipients.Contact,
			|	EmailRecipients.Group
			|INTO EmailRecipients
			|FROM
			|	&EmailRecipients AS EmailRecipients
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	AddressContacts.Contact,
			|	AddressContacts.AddressesList
			|INTO ContactsAddressList
			|FROM
			|	&AddressContacts AS AddressContacts
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	EmailRecipients.Address,
			|	EmailRecipients.Presentation,
			|	EmailRecipients.Contact,
			|	EmailRecipients.Group,
			|	ISNULL(ContactsAddressList.AddressesList, """") AS AddressesList
			|FROM
			|	EmailRecipients AS EmailRecipients
			|		LEFT JOIN ContactsAddressList AS ContactsAddressList
			|		ON ContactsAddressList.Contact = EmailRecipients.Contact";
			
			Query.SetParameter("EmailRecipients", RecipientsTab);
			Query.SetParameter("AddressContacts", AddressesTable);
			
			RecipientsTab = Query.Execute().Unload();
		
	EndIf;
	
	ValueToFormAttribute(RecipientsTab, "EmailRecipients");
	
EndProcedure

&AtClient
Procedure AddRecipient(Address, Description, Contact, AddressesList = "")
	
	DeleteBlankRecipient(EmailRecipients);
	
	NewRow = EmailRecipients.Add();
	NewRow.Address         = Address;
	NewRow.Presentation = Description;
	NewRow.Contact       = Contact;
	NewRow.AddressesList = AddressesList;
	NewRow.Group        = DefaultGroup;
	
EndProcedure

&AtClientAtServerNoContext
Procedure DeleteBlankRecipient(EmailRecipients)
	
	If EmailRecipients.Count() = 0 Then
		Return;
	EndIf;	
		
	EmailRecipient = EmailRecipients[0];
	If IsBlankString(EmailRecipient.Address) And IsBlankString(EmailRecipient.Presentation) And Not ValueIsFilled(EmailRecipient.Contact) Then
		EmailRecipients.Delete(0);
	EndIf;	

EndProcedure

&AtClient
Procedure AddRecipientFromListBySubject()
	
	CurrentData = Items.ContactsBySubject.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Result = InteractionsServerCall.ContactDescriptionAndEmailAddresses(CurrentData.Ref);
	If Result <> Undefined And Result.Addresses.Count() > 0 Then
		AddressesList = StrConcat(Result.Addresses.UnloadValues(), ";");
	Else
		AddressesList = "";
	EndIf;
	
	AddRecipient(CurrentData.Address, CurrentData.Description, CurrentData.Ref, AddressesList);
	
EndProcedure

&AtClient
Procedure SetContactInRecipientsList(Contact)
	
	If ValueIsFilled(Contact) And Items.EmailRecipients.CurrentData <> Undefined Then
		Items.EmailRecipients.CurrentData.Contact = Contact;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetContactAsCurrent(Contact)
	
	Interactions.SetContactAsCurrent(Contact, ThisObject);
	
EndProcedure

&AtClient
Procedure ChangeGroup(GroupName)
	
	For Each SelectedRow In Items.EmailRecipients.SelectedRows Do
		Item = EmailRecipients.FindByID(SelectedRow);
		Item.Group = GroupName;
	EndDo;
	
EndProcedure

&AtServer
Procedure MoveSelectedRows(Val SelectedRows)

	Result = Interactions.ContactsEmailAddresses(SelectedRows, DefaultGroup);
	If Result <> Undefined Then
		DeleteBlankRecipient(EmailRecipients);
		CommonClientServer.SupplementTable(Result, EmailRecipients);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetDefaultGroup()
	
	DefaultGroup = Parameters.DefaultGroup;
	If IsBlankString(DefaultGroup) Then
		DefaultGroup = NStr("en = 'To';");
	EndIf;
	
EndProcedure 

&AtClient
Procedure PagesManagement()

	If Items.PagesLists.CurrentPage = Items.AllContactsBySubjectPage 
		Or Items.PagesLists.CurrentPage = Items.SearchContactsPage 
		Or Items.PagesLists.CurrentPage.ChildItems.Count() = 1 
		Or (Items.PagesLists.CurrentPage = Items.UsersPage 
		And (Not UseUserGroups))Then
		
		Items.MovePages.CurrentPage = Items.MoveOneTablePage;
		
	Else
		
		Items.MovePages.CurrentPage = Items.MoveTwoTablesPage;
		
	EndIf;

EndProcedure 

&AtClient
Procedure DSAddressChoiceListAfterCompletion(SelectedElement, AdditionalParameters) Export

	If SelectedElement = Undefined Then
		Return;
	EndIf;
	
	IndexOf = SelectedElement.Value;
	Address = AdditionalParameters.Result[IndexOf].EMAddress;
	Presentation = AdditionalParameters.Result[IndexOf].Presentation;
	SetSelectedContactAddressAndPresentation(AdditionalParameters.CurrentData, Presentation, Address);

EndProcedure

&AtClient
Procedure SetSelectedContactAddressAndPresentation(CurrentData, Presentation, Address)

	Position = StrFind(Presentation, "<");
	Presentation = ?(Position= 0, "", TrimAll(Left(Presentation, Position-1)));

	CurrentData.Address = Address;
	If Not IsBlankString(Presentation) Then
		CurrentData.Presentation = Presentation;
	EndIf;

EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Common.SetChoiceListConditionalAppearance(ThisObject, "Group", "EmailRecipients.Group");
	
EndProcedure 

&AtClient
Procedure UpdateSearchOptionsMenu()
	
	Items.SearchEverywhereOption.Check = (SearchOptions = "Everywhere");
	Items.SearchInAddressesOption.Check = (SearchOptions = "ByEmail");
	Items.SearchInContactsDescriptionsOption.Check = (SearchOptions = "ByLine");
	Items.SearchByDomainNameOption.Check = (SearchOptions = "ByDomain");

EndProcedure

&AtClientAtServerNoContext
Procedure OnChangeOnlyContactsWithAddresses(Form)

		For Each ListName In Form.AddedTablesNames Do
		
		CommonClientServer.SetDynamicListFilterItem(Form.ThisObject[ListName.Value], "Address", , DataCompositionComparisonType.Filled,, Form.ShowOnlyContactsWithAddresses);
		
	EndDo;
	
	If Form.ShowOnlyContactsWithAddresses Then
		
		Form.Items.ContactsBySubject.RowFilter = New FixedStructure("AddressFilled", True);
		Form.Items.FoundContacts.RowFilter  = New FixedStructure("PresentationFilled", True);
		
		
	Else
		
		Form.Items.FoundContacts.RowFilter  = Undefined;
		Form.Items.ContactsBySubject.RowFilter = Undefined;
		
	EndIf

EndProcedure

#EndRegion
