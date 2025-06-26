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

Function IsLocalizationModuleAvailable() Export
	Return Metadata.CommonModules.Find("ContactsManagerLocalization") <> Undefined;
EndFunction

Function AreAddressManagementModulesAvailable() Export
	Return Metadata.CommonModules.Find("AddressManager") <> Undefined;
EndFunction

#EndRegion

#Region Private

// Determines the availability of the AddressClassifier subsystem and the availability of records about states in the
// AddressObjects information register.
//
// Returns:
//  FixedMap of KeyAndValue:
//    * Key - String - "ClassifierAvailable", "UseImportedItems", "AddressClassifierUsed"
//    * Value - Boolean
//
Function AddressClassifierAvailabilityInfo() Export
	
	Result = New Map;
	Result.Insert("ClassifierAvailable",             False);
	Result.Insert("UseImportedItems",           False);
	Result.Insert("AddressClassifierUsed", False);
	
	Result["AddressClassifierUsed"] = Common.SubsystemExists("StandardSubsystems.AddressClassifier");
	If Not Result["AddressClassifierUsed"] Then
		Return New FixedMap(Result);
	EndIf;
	
	ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
	AddressInfoAvailabilityInfo = ModuleAddressClassifierInternal.AddressInfoAvailabilityInfo();
	
	Result["ClassifierAvailable"]   = AddressInfoAvailabilityInfo.Get("ClassifierAvailable");
	Result["UseImportedItems"] = AddressInfoAvailabilityInfo.Get("UseImportedItems");
	
	Return New FixedMap(Result);
	
EndFunction

// Returns an enumeration value of contact information kind type.
//
//  Parameters:
//    InformationKind - CatalogRef.ContactInformationKinds
//                  - Structure - data source.
//
Function ContactInformationKindType(Val InformationKind) Export
	Result = Undefined;
	
	Type = TypeOf(InformationKind);
	If Type = Type("EnumRef.ContactInformationTypes") Then
		Result = InformationKind;
	ElsIf Type = Type("CatalogRef.ContactInformationKinds") Then
		Result = Common.ObjectAttributeValue(InformationKind, "Type");
	ElsIf InformationKind <> Undefined Then
		Data = New Structure("Type");
		FillPropertyValues(Data, InformationKind);
		Result = Data.Type;
	EndIf;
	
	Return Result;
EndFunction

Function ContactInformationKindsDescriptions() Export
	
	Result = New Map;
	For Each Language In Metadata.Languages Do
		Descriptions = New Map;
		ContactsManagerOverridable.OnGetContactInformationKindsDescriptions(Descriptions, Language.LanguageCode);
		Result[Language.LanguageCode] = Descriptions;
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

// Returns a list of predefined contact information kinds.
//
// Returns:
//  FixedMap of KeyAndValue:
//   * Key - String - name of predefined kind.
//   * Value - CatalogRef.ContactInformationKinds - a reference to an item of the ContactInformationKinds catalog.
//
Function ContactInformationKindsByName() Export
	
	Kinds = New Map;
	PredefinedKinds = ContactsManager.PredefinedContactInformationKinds();
	
	For Each PredefinedKind In PredefinedKinds Do
		Kinds.Insert(PredefinedKind.Name, PredefinedKind.Ref);
	EndDo;
	
	Return New FixedMap(Kinds);
	
EndFunction

Function ObjectContactInformationContainsValidFromColumn(ObjectRef) Export
	Return ObjectRef.Metadata().TabularSections.ContactInformation.Attributes.Find("ValidFrom") <> Undefined;
EndFunction

Function ContactInformationKindGroupByObjectName(FullMetadataObjectName) Export
	CIKindsGroupName = StrReplace(FullMetadataObjectName, ".", "");
	
	Query = New Query;
	Query.Text = "SELECT
	|	ContactInformationKinds.Ref AS Ref,
	|CASE
	|	WHEN ContactInformationKinds.PredefinedKindName <> """"
	|	THEN ContactInformationKinds.PredefinedKindName
	|	ELSE ContactInformationKinds.PredefinedDataName
	|END AS PredefinedKindName
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|WHERE
	|	ContactInformationKinds.IsFolder = TRUE
	|	AND ContactInformationKinds.DeletionMark = FALSE
	|	AND ContactInformationKinds.Used = TRUE";
	
	QueryResult = Query.Execute().Select();
	While QueryResult.Next() Do
		If StrCompare(QueryResult.PredefinedKindName, CIKindsGroupName) = 0 Then
			Return QueryResult.Ref;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

Function PicturesOfContactInfoTypes() Export
	
	PicturesOfContactInfoTypes = New Map;
	
	PicturesOfContactInfoTypes.Insert(Enums.ContactInformationTypes.Skype, PictureLib.Skype);	
	PicturesOfContactInfoTypes.Insert(Enums.ContactInformationTypes.Address, PictureLib.Address);	
	PicturesOfContactInfoTypes.Insert(Enums.ContactInformationTypes.Email, PictureLib.Email);	
	PicturesOfContactInfoTypes.Insert(Enums.ContactInformationTypes.WebPage, PictureLib.WebPage);	
	PicturesOfContactInfoTypes.Insert(Enums.ContactInformationTypes.Other, PictureLib.Other);	
	PicturesOfContactInfoTypes.Insert(Enums.ContactInformationTypes.Phone, PictureLib.PhoneCall);
	PicturesOfContactInfoTypes.Insert(Enums.ContactInformationTypes.Fax, PictureLib.Fax);	
	
	Return New FixedMap(PicturesOfContactInfoTypes);
	
EndFunction

// See ContactsManager.CommandsOfContactInfoType
Function CommandsOfContactInfoType(Type) Export

	TypeCommands = New Structure;

	If Type = Enums.ContactInformationTypes.Address Then

		TypeCommands.Insert("AddCommentToAddress", ContactsManager.CommandDetailsByName("AddCommentToAddress"));
		TypeCommands.Insert("ShowOnYandexMaps",    ContactsManager.CommandDetailsByName("ShowOnYandexMaps"));
		TypeCommands.Insert("ShowOnGoogleMap",    ContactsManager.CommandDetailsByName("ShowOnGoogleMap"));
		TypeCommands.Insert("PlanMeeting",     ContactsManager.CommandDetailsByName("PlanMeeting"));
		TypeCommands.Insert("ShowChangeHistory", ContactsManager.CommandDetailsByName("ShowChangeHistory"));

	ElsIf Type = Enums.ContactInformationTypes.Phone Then

		TypeCommands.Insert("Telephone",      ContactsManager.CommandDetailsByName("Telephone"));
		TypeCommands.Insert("SendSMS",             ContactsManager.CommandDetailsByName("SendSMS"));
		TypeCommands.Insert("ShowChangeHistory", ContactsManager.CommandDetailsByName("ShowChangeHistory"));
		
	ElsIf Type = Enums.ContactInformationTypes.Fax Then

		TypeCommands.Insert("SendFax",            ContactsManager.CommandDetailsByName("SendFax"));
		TypeCommands.Insert("ShowChangeHistory", ContactsManager.CommandDetailsByName("ShowChangeHistory"));

	ElsIf Type = Enums.ContactInformationTypes.Email Then

		TypeCommands.Insert("WriteEmail2", ContactsManager.CommandDetailsByName("WriteEmail2"));

	ElsIf Type = Enums.ContactInformationTypes.Skype Then

		TypeCommands.Insert("SkypeCall", ContactsManager.CommandDetailsByName("SkypeCall"));
		TypeCommands.Insert("StartSkypeChat", ContactsManager.CommandDetailsByName("StartSkypeChat"));

	ElsIf Type = Enums.ContactInformationTypes.WebPage Then

		TypeCommands.Insert("OpenWebPage", ContactsManager.CommandDetailsByName("OpenWebPage"));

	ElsIf Type = Enums.ContactInformationTypes.Other Then

		TypeCommands.Insert("OpenWindowOther", ContactsManager.CommandDetailsByName("OpenWindowOther"));

	EndIf;

	Return TypeCommands;

EndFunction

#EndRegion
