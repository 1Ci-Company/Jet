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

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Use InteractionsClientServerOverridable.OnDeterminePossibleContacts.
// See the NewContactFormName property of the ContactsTypes parameter.
//
// It is called when creating a new contact.
// It is used if one or several contact types require 
// to open another form instead the main one when creating them.
// For example, it can be the form of a new catalog item creation wizard.
//
// Parameters:
//  ContactType   - String    - a contact catalog name.
//  FormParameter - Structure - a parameter that is passed when opening.
//
// Returns:
//  Boolean - True if a custom form opened. Otherwise, False.
//
// Example:
//	If ContactType = "Partners" Then
//		OpenForm("Catalog.Partners.Form.NewContactWizard", FormParameter);
//		Return;
//	EndIf;
//	
//	Return False;
//
Function CreateContactNonstandardForm(ContactType, FormParameter)  Export
	
	Return False;
	
EndFunction

#EndRegion

#EndRegion
