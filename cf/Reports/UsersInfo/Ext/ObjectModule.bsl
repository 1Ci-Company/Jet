///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	ResultDocument.Clear();
	
	TemplateComposer = New DataCompositionTemplateComposer;
	Settings = SettingsComposer.GetSettings();
	
	NonExistingIBUsersIDs = New Array;
	
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("IBUsers", IBUsers(NonExistingIBUsersIDs));
	ExternalDataSets.Insert("ContactInformation", ContactInformation(Settings));
	
	Settings.DataParameters.SetParameterValue(
		"NonExistingIBUsersIDs", NonExistingIBUsersIDs);
	
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Settings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	OutputProcessor.BeginOutput();
	ResultItem = CompositionProcessor.Next();
	While ResultItem <> Undefined Do
		OutputProcessor.OutputItem(ResultItem);
		ResultItem = CompositionProcessor.Next();
	EndDo;
	OutputProcessor.EndOutput();
	
EndProcedure

#EndRegion

#Region Private

Function IBUsers(NonExistingIBUsersIDs)
	
	BlankUUID = CommonClientServer.BlankUUID();
	NonExistingIBUsersIDs.Add(BlankUUID);
	
	Query = New Query;
	Query.SetParameter("BlankUUID", BlankUUID);
	Query.Text =
	"SELECT
	|	Users.IBUserID AS IBUserID,
	|	UsersInfo.CanSignIn AS CanSignIn,
	|	UsersInfo.StandardAuthentication AS StandardAuthentication,
	|	UsersInfo.OpenIDAuthentication AS OpenIDAuthentication,
	|	UsersInfo.OpenIDConnectAuthentication AS OpenIDConnectAuthentication,
	|	UsersInfo.AccessTokenAuthentication AS AccessTokenAuthentication,
	|	UsersInfo.OSAuthentication AS OSAuthentication
	|FROM
	|	Catalog.Users AS Users
	|		LEFT JOIN InformationRegister.UsersInfo AS UsersInfo
	|		ON (UsersInfo.User = Users.Ref)
	|WHERE
	|	Users.IBUserID <> &BlankUUID
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.IBUserID,
	|	UsersInfo.CanSignIn,
	|	UsersInfo.StandardAuthentication,
	|	UsersInfo.OpenIDAuthentication,
	|	UsersInfo.OpenIDConnectAuthentication,
	|	UsersInfo.AccessTokenAuthentication,
	|	UsersInfo.OSAuthentication
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|		LEFT JOIN InformationRegister.UsersInfo AS UsersInfo
	|		ON (UsersInfo.User = ExternalUsers.Ref)
	|WHERE
	|	ExternalUsers.IBUserID <> &BlankUUID";
	
	Upload0 = Query.Execute().Unload();
	Upload0.Indexes.Add("IBUserID");
	Upload0.Columns.Add("Mapped", New TypeDescription("Boolean"));
	
	IBUsers = New ValueTable;
	IBUsers.Columns.Add("UUID", New TypeDescription("UUID"));
	IBUsers.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(100)));
	IBUsers.Columns.Add("CanSignIn",         New TypeDescription("Boolean"));
	IBUsers.Columns.Add("StandardAuthentication",      New TypeDescription("Boolean"));
	IBUsers.Columns.Add("ShowInList",        New TypeDescription("Boolean"));
	IBUsers.Columns.Add("CannotChangePassword",        New TypeDescription("Boolean"));
	IBUsers.Columns.Add("CannotRecoveryPassword", New TypeDescription("Boolean"));
	IBUsers.Columns.Add("OpenIDAuthentication",           New TypeDescription("Boolean"));
	IBUsers.Columns.Add("OpenIDConnectAuthentication",    New TypeDescription("Boolean"));
	IBUsers.Columns.Add("AccessTokenAuthentication",   New TypeDescription("Boolean"));
	IBUsers.Columns.Add("OSAuthentication",               New TypeDescription("Boolean"));
	IBUsers.Columns.Add("UnsafeActionProtection",        New TypeDescription("Boolean"));
	IBUsers.Columns.Add("OSUser", New TypeDescription("String", , New StringQualifiers(1024)));
	IBUsers.Columns.Add("Language",           New TypeDescription("String", , New StringQualifiers(100)));
	IBUsers.Columns.Add("RunMode",   New TypeDescription("String", , New StringQualifiers(100)));
	
	SetPrivilegedMode(True);
	AllIBUsers = InfoBaseUsers.GetUsers();
	
	For Each IBUser In AllIBUsers Do
		
		PropertiesIBUser = Users.IBUserProperies(IBUser.UUID);
		
		NewRow = IBUsers.Add();
		FillPropertyValues(NewRow, PropertiesIBUser);
		Language = PropertiesIBUser.Language;
		NewRow.Language = ?(ValueIsFilled(Language), Metadata.Languages[Language].Synonym, "");
		NewRow.CanSignIn = Users.CanSignIn(PropertiesIBUser);
		
		String = Upload0.Find(PropertiesIBUser.UUID, "IBUserID");
		If String <> Undefined Then
			String.Mapped = True;
			If Not NewRow.CanSignIn Then
				FillPropertyValues(NewRow,
					UsersInternal.StoredIBUserProperties(String));
			EndIf;
		EndIf;
	EndDo;
	
	Filter = New Structure("Mapped", False);
	Rows = Upload0.FindRows(Filter);
	For Each String In Rows Do
		NonExistingIBUsersIDs.Add(String.IBUserID);
	EndDo;
	
	Return IBUsers;
	
EndFunction

Function ContactInformation(Settings)
	
	TypesReference = New Array;
	TypesReference.Add(Type("CatalogRef.Users"));
	TypesReference.Add(Type("CatalogRef.ExternalUsers"));
	
	Contacts = New ValueTable;
	Contacts.Columns.Add("Ref", New TypeDescription(TypesReference));
	Contacts.Columns.Add("Phone", New TypeDescription("String"));
	Contacts.Columns.Add("EmailAddress", New TypeDescription("String"));
	
	If Not Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Return Contacts;
	EndIf;
	
	FillContacts = False;
	PhoneField          = New DataCompositionField("Phone");
	FieldEmailAddress = New DataCompositionField("EmailAddress");
	
	For Each Item In Settings.Selection.Items Do
		If TypeOf(Item) = Type("DataCompositionSelectedField")
		   And (Item.Field = PhoneField Or Item.Field = FieldEmailAddress)
		   And Item.Use Then
			
			FillContacts = True;
			Break;
		EndIf;
	EndDo;
	
	If Not FillContacts Then
		Return Contacts;
	EndIf;
	
	ContactInformationKinds = New Array;
	ContactInformationKinds.Add(Catalogs["ContactInformationKinds"].UserEmail);
	ContactInformationKinds.Add(Catalogs["ContactInformationKinds"].UserPhone);
	Query = New Query;
	Query.SetParameter("ContactInformationKinds", ContactInformationKinds);
	Query.Text =
	"SELECT
	|	UsersContactInformation.Ref AS Ref,
	|	UsersContactInformation.Kind AS Kind,
	|	UsersContactInformation.Presentation AS Presentation
	|FROM
	|	Catalog.Users.ContactInformation AS UsersContactInformation
	|WHERE
	|	UsersContactInformation.Kind IN(&ContactInformationKinds)
	|
	|ORDER BY
	|	UsersContactInformation.Ref,
	|	UsersContactInformation.Type.Order,
	|	UsersContactInformation.Kind
	|TOTALS BY
	|	Ref";
	
	SelectionByUsers = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionByUsers.Next() Do
		Phones = "";
		EmailAddresses = "";
		Selection = SelectionByUsers.Select();
		While Selection.Next() Do
			If Selection.Kind = Catalogs["ContactInformationKinds"].UserPhone Then
				Phones = Phones + ?(ValueIsFilled(Phones), ", ", "");
				Phones = Phones + Selection.Presentation;
			EndIf;
			If Selection.Kind = Catalogs["ContactInformationKinds"].UserEmail Then
				EmailAddresses = EmailAddresses + ?(ValueIsFilled(EmailAddresses), ", ", "");
				EmailAddresses = EmailAddresses + Selection.Presentation;
			EndIf;
		EndDo;
		If ValueIsFilled(Phones) Or ValueIsFilled(EmailAddresses) Then
			NewRow = Contacts.Add();
			NewRow.Ref = SelectionByUsers.Ref;
			NewRow.Phone = Phones;
			NewRow.EmailAddress = EmailAddresses;
		EndIf;
	EndDo;
	
	Return Contacts;
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf