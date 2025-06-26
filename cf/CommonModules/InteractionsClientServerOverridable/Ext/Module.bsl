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

// Specifies interaction subject types, for example, orders, vacancies and so on.
// It is used if at least one interaction subject is determined in the configuration. 
//
// Parameters:
//  SubjectsTypes  - Array - interaction subjects (String),
//                            for example, "DocumentRef.CustomerOrder" and so on.
//
Procedure OnDeterminePossibleSubjects(SubjectsTypes) Export
	
	SubjectsTypes.Add("DocumentRef.SalesInvoice");
	SubjectsTypes.Add("DocumentRef.SupplierInvoice");
	
EndProcedure

// Sets details of possible interaction contact types, for example: partners, contact persons and so on.
// It is used if at least one interaction contact type apart from the Users catalog is determined
// in the configuration. 
//
// Parameters:
//  ContactsTypes - Array - contains interaction contact type details (Structure) and their properties:
//     * Type                               - Type    - a contact reference type.
//     * Name                               - String - a contact type name as it is defined in metadata.
//     * Presentation                     - String - a contact type presentation to be displayed to a user.
//     * Hierarchical                     - Boolean - indicates that this catalog is hierarchical.
//     * HasOwner                      - Boolean - indicates that the contact has an owner.
//     * OwnerName                      - String - a contact owner name as it is defined in metadata.
//     * SearchByDomain                    - Boolean - indicates that contacts of this type will be picked
//                                                    by the domain map and not by the full email address.
//     * Link                             - String - describes a possible link of this contact with some other contact
//                                                    when the current contact is an attribute of other contact.
//                                                    It is described with the "TableName.AttributeName" string.
//     * ContactPresentationAttributeName - String - a contact attribute name, from which a contact presentation
//                                                    will be received. If it is not specified, the standard
//                                                    Description attribute is used.
//     * InteractiveCreationPossibility - Boolean - indicates that a contact can be created interactively from interaction
//                                                    documents.
//     * NewContactFormName            - String - a full form name to create a new contact.
//                                                    For example, "Catalog.Partners.Form.NewContactWizard".
//                                                    If it is not filled in, a default item form is opened.
//
Procedure OnDeterminePossibleContacts(ContactsTypes) Export
	
	Contact = InteractionsClientServer.NewContactDescription();
	Contact.Type = Type("CatalogRef.Counterparties");
	Contact.Name = "Counterparties";
	Contact.Presentation = NStr("en = 'Counterparties'");
	Contact.Hierarchical = True;
	ContactsTypes.Add(Contact);
	
EndProcedure

#EndRegion



