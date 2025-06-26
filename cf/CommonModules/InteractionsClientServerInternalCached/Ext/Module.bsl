///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

// Returns:
//   FixedArray of See InteractionsClientServer.NewContactDescription
//
Function InteractionsContacts() Export

	Result = New Array();
	
	Contact = InteractionsClientServer.NewContactDescription();
	Contact.Type                               = Type("CatalogRef.Users");
	Contact.Name                               = "Users";
	Contact.Presentation                     = NStr("en = 'Users';");
	Contact.InteractiveCreationPossibility = False;
	Contact.SearchByDomain                    = True;
	Result.Add(Contact);
	
	InteractionsClientServerOverridable.OnDeterminePossibleContacts(Result);
	Return New FixedArray(Result);

EndFunction

Function InteractionsSubjects() Export
	
	Subjects = New Array;
	InteractionsClientServerOverridable.OnDeterminePossibleSubjects(Subjects);
	Return New FixedArray(Subjects);
	
EndFunction

#EndRegion
