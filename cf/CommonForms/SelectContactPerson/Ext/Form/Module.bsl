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
	
	SaveOpeningParameters(Parameters);
	Interactions.ProcessUserGroupsDisplayNecessity(ThisObject);
	Interactions.AddContactsPickupFormPages(ThisObject);
	
	// Filling in contacts by the subject.
	Interactions.FillContactsBySubject(Items, Parameters.SubjectOf, ContactsBySubject, False);
	
	// Filling in a search option list and performing the first search.
	AllSearchLists = Interactions.AvailableSearchesList(FTSEnabled, Parameters, Items, False);
	ExecuteFirstSearch();
	
	// If a contact is filled in, set the current page as appropriate one and position for the contact.
	If ValueIsFilled(Parameters.Contact) Then
		SetContactAsCurrent(Parameters.Contact)
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FillChoiceListInSearchString(False);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FoundContactsSelection(Item, RowSelected, Field, StandardProcessing)
	
	Notify("ContactSelected", NotificationParameters(Item.CurrentData.Ref));
	Close();

EndProcedure

&AtClient
Procedure Attachable_CatalogListChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined  Then
		Return;
	EndIf;
	
	ContactDescription = New Structure;
	
	ContactDetailsArray = InteractionsClientServer.ContactsDetails();
	For Each ArrayElement In  ContactDetailsArray Do
		If TypeOf(CurrentData.Ref) = ArrayElement.Type Then
			ContactDescription = ArrayElement;
			Break;
		EndIf;
	EndDo;
	
	If ContactDescription.Property("Hierarchical")And ContactDescription.Hierarchical Then
		IsFolder = IsFolder(CurrentData.Ref);
	Else
		IsFolder = False;
	EndIf;
	
	If Not IsFolder Then
		Notify("ContactSelected", NotificationParameters(CurrentData.Ref));
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactsBySubjectSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	If Item.CurrentData <> Undefined Then
		Notify("ContactSelected", NotificationParameters(Item.CurrentData.Ref));
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure SearchOptionsOnChange(Item)
	
	FillChoiceListInSearchString(True);
	
EndProcedure 

&AtClient
Procedure Attachable_ListContactsOnActivateRow(Item)
	
	DetermineActivatedContact(Item);
	
EndProcedure

&AtClient
Procedure Attachable_ListOwnerOnActivateRow(Item)
	
	DetermineActivatedContact(Item);
	
	InteractionsClient.ContactOwnerOnActivateRow(Item, ThisObject);

EndProcedure

&AtClient
Procedure UserGroupsOnActivateRow(Item)
	
	UsersList.Parameters.SetParameterValue("UsersGroup", Items.UserGroups.CurrentRow);
	
EndProcedure

&AtClient
Procedure SearchOptionsClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FindCommandExecute()
	
	If IsBlankString(SearchString) Then
		ShowMessageBox(, NStr("en = 'Please enter text to search for.';"));
		Return;
	EndIf;
	
	Result = "";
	FoundContacts.Clear();
	
	If SearchOptions = "ByEmail" Then
		FindByEmail(False);
	ElsIf SearchOptions = "ByDomain" Then
		FindByEmail(True);
	ElsIf SearchOptions = "ByPhone" Then
		FindByPhone();
	ElsIf SearchOptions = "ByLine" Then
		Result = FindByString();
	ElsIf SearchOptions = "BeginsWith" Then
		FindByDescriptionBeginning();
	EndIf;
	
	If Not IsBlankString(Result) Then
		ShowMessageBox(, Result);
	EndIf;
	
EndProcedure

&AtClient
Procedure FindInListFromFoundItemsListExecute()
	
	If Items.FoundContacts.CurrentData <> Undefined Then
		SetContactAsCurrent(Items.FoundContacts.CurrentData.Ref);
	EndIf;

EndProcedure

&AtClient
Procedure FindInListFromSubjectsListExecute()
	
	If Items.ContactsBySubject.CurrentData <> Undefined Then
		SetContactAsCurrent(Items.ContactsBySubject.CurrentData.Ref);
	EndIf;

EndProcedure

// Returns the string data of the Contacts table by subject.
// 
// Parameters:
//  SelectedRow  - FormDataCollectionItem - the string whose data is being received.
//
// Returns:
//  Structure:
//   * Ref                    - DefinedType.InteractionContact
//   * Description              - String
//   * CatalogName            - String
//   * DescriptionPresentation - String
//
&AtClient
Function ConstantDataBySubject(SelectedRow);
	
	Return SelectedRow;
	
EndFunction

&AtClient
Procedure SelectCommand(Command)
	
	If Items.PagesLists.CurrentPage = Items.SearchContactsPage Then
		
		CurrentData = ConstantDataBySubject(Items.FoundContacts.CurrentData);
		If CurrentData <> Undefined Then
			Notify("ContactSelected", NotificationParameters(CurrentData.Ref));
			Close();
		EndIf;
		
		Return;
		
	ElsIf Items.PagesLists.CurrentPage = Items.AllContactsBySubjectPage Then
		
		CurrentData = ConstantDataBySubject(Items.ContactsBySubject.CurrentData);
		If CurrentData <> Undefined Then
			Notify("ContactSelected", NotificationParameters(CurrentData.Ref));
			Close();
		EndIf;
		
		Return;
		
	EndIf;
	
	ContactForChoice = Undefined;
	
	For Indus = 0 To Items.PagesLists.CurrentPage.ChildItems.Count() -1 Do
		
		CurrentData = ConstantDataBySubject(Items.PagesLists.CurrentPage.ChildItems[Indus].CurrentData);
		If CurrentData = Undefined  Then
			Continue;
		Else
			If CurrentData.Property("Ref") And CurrentData.Ref = LastActivatedContact Then
				ContactForChoice = LastActivatedContact;
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If ContactForChoice = Undefined Then
		Return;
	EndIf;
		
	ContactDescription = New Structure;
	
	ContactDetailsArray = InteractionsClientServer.ContactsDetails();
	For Each ArrayElement In  ContactDetailsArray Do
		If TypeOf(ContactForChoice) = ArrayElement.Type Then
			ContactDescription = ArrayElement;
			Break;
		EndIf;
	EndDo;
	
	If ContactDescription.Property("Hierarchical")And ContactDescription.Hierarchical Then
		IsFolder = IsFolder(ContactForChoice);
	Else
		IsFolder = False;
	EndIf;
	
	If Not IsFolder Then
		Notify("ContactSelected", NotificationParameters(CurrentData.Ref));
		Close(ContactForChoice);
	EndIf;
	
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
// SEARCH PROCEDURES AND FUNCTIONS

// Generates a value list of the strings, by which search by the current search option will be carried out.
//
// Returns:
//   ValueList   - List of strings to be searched by.
//
&AtServer
Function SearchStringsListByOption()

	StringsList = New ValueList;
	
	Values = Undefined;
	AllSearchLists.Property(SearchOptions, Values);
	
	If TypeOf(Values) = Type("String") Then
		StringsList.Add(Values);
	ElsIf TypeOf(Values) = Type("ValueList") Then
		For Each Item In Values Do
			StringsList.Add(Item.Value);
		EndDo;
	EndIf;
	
	Return StringsList;

EndFunction

// Performs the first search by all possible search options according to the passed parameters.
//
&AtServer
Procedure ExecuteFirstSearch()
	
	SearchOptions = "ByLine";
	If IsBlankString(Parameters.Address) And IsBlankString(Parameters.Presentation) Then
		Return;
	EndIf;

	// Searching by email.
	SearchOptions = "ByEmail";
	For Each Variant In SearchStringsListByOption() Do
		SearchString = Variant.Value;
		If IsBlankString(SearchString) Then
			Continue;
		EndIf;
		If FindByEmail(False) Then
			Return;
		EndIf;
	EndDo;
	
	// Searching by phone number.
	SearchOptions = "ByPhone";
	For Each Variant In SearchStringsListByOption() Do
		SearchString = Variant.Value;
		If IsBlankString(SearchString) Then
			Continue;
		EndIf;
		If FindByPhone() Then
			Return;
		EndIf;
	EndDo;

	// If a full-text search index is not enabled, cancel search.
	If Not FTSEnabled Then
		SearchOptions = "ByEmail";
		Return;
	EndIf;

	// Searching by an address and a presentation.
	SearchOptions = "ByLine";
	For Each Variant In SearchStringsListByOption() Do
		SearchString = Variant.Value;
		If IsBlankString(SearchString) Then
			Continue;
		EndIf;
		FindByString();
		If FoundContacts.Count() > 0 Then
			Return;
		EndIf;
	EndDo;

EndProcedure

// Searches for contacts by a domain name or an email address.
//
&AtServer
Function FindByEmail(ByDomain)

	Return Interactions.FindByEmail(SearchString, ByDomain, FoundContacts);

EndFunction

// Searches for contacts by a phone number.
//
&AtServer
Function FindByPhone()
	
	Return Interactions.FindContactsByPhone(SearchString, FoundContacts);
	
EndFunction

// Searches for contacts by a string.
//
&AtServer
Function FindByString()
	
	Return Interactions.FullTextContactsSearchByRow(SearchString, FoundContacts);
	
EndFunction

// Searches for contacts by description beginning.
//
&AtServer
Function FindByDescriptionBeginning()

	TableOfContacts = Interactions.FindContactsByDescriptionBeginning(SearchString);

	If TableOfContacts = Undefined Or TableOfContacts.Count() = 0 Then
		Return False;
	EndIf;
	
	Interactions.FillFoundContacts(TableOfContacts, FoundContacts);
	Return True;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS.

// Sets a contact as the current contact in the dynamic list.
//
// Parameters:
//  Contact  - CatalogRef - a contact to be positioned on.
// 
&AtServer
Procedure SetContactAsCurrent(Contact)

	Interactions.SetContactAsCurrent(Contact, ThisObject);

EndProcedure

&AtServer
Procedure SaveOpeningParameters(PassedParameters)
	
	Presentation = "";
	If Not IsBlankString(PassedParameters.Presentation) Then
		Presentation = StrGetLine(PassedParameters.Presentation, 1);
	EndIf;
	
	FormParameters.Add( PassedParameters.Address,                             "Address");
	FormParameters.Add( PassedParameters.Contact,                           "Contact");
	FormParameters.Add( PassedParameters.SubjectOf,                           "SubjectOf");
	FormParameters.Add( Presentation,                                         "Presentation");
	FormParameters.Add( PassedParameters.EmailOnly,                       "EmailOnly");
	FormParameters.Add( PassedParameters.PhoneOnly,                     "PhoneOnly");
	FormParameters.Add( PassedParameters.ForContactSpecificationForm,        "ForContactSpecificationForm");
	FormParameters.Add( PassedParameters.ReplaceEmptyAddressAndPresentation, "ReplaceEmptyAddressAndPresentation");
	FormParameters.Add( PassedParameters.FormIdentifier,                "FormIdentifier");
	
EndProcedure

&AtClient
Function NotificationParameters(SelectedContact)

	NotificationParameters = New Structure;
	
	For Each ListItem In FormParameters Do
	
		NotificationParameters.Insert(ListItem.Presentation, ListItem.Value);
	
	EndDo;
	
	NotificationParameters.Insert("SelectedContact", SelectedContact);
	
	Return NotificationParameters;

EndFunction 

&AtClient
Procedure DetermineActivatedContact(Item)
	
	CurrentData = Item.CurrentData;
	If CurrentData <> Undefined Then
		LastActivatedContact = CurrentData.Ref;
	EndIf;
	
EndProcedure

&AtClient
Procedure FillChoiceListInSearchString(ChangeSearchString)

	SearchOptionsList = Undefined;
	AllSearchLists.Property(SearchOptions, SearchOptionsList);
	
	IsList = False;
	If TypeOf(SearchOptionsList) = Type("ValueList") Then
		Count = SearchOptionsList.Count();
		If Count = 0 Then
			SearchOptionsList = "";
		ElsIf Count = 1 Then
			SearchOptionsList = SearchOptionsList.Get(0).Value;
		Else
			IsList = True;
		EndIf;
	EndIf;
	
	Items.SearchString.DropListButton = IsList;
	
	If IsList Then
		Items.SearchString.ChoiceList.Clear();
		For Each OptionItem In SearchOptionsList Do
			Items.SearchString.ChoiceList.Add(OptionItem.Value);
		EndDo;
		If ChangeSearchString Then
			SearchString = SearchOptionsList.Get(0).Value;
		EndIf;
	ElsIf ChangeSearchString Then
		SearchString = SearchOptionsList;
	EndIf;

EndProcedure

&AtServer
Function IsFolder(ObjectReference)
	Return Common.ObjectAttributeValue(ObjectReference, "IsFolder");
EndFunction

#EndRegion
