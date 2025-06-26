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

// Generates a string presentation of a phone number.
//
// Parameters:
//    CountryCode     - String - country code.
//    CityCode     - String - area code.
//    PhoneNumber - String - phone number.
//    PhoneExtension    - String - extension.
//    Comment   - String - comment.
//
// Returns:
//   - String - a phone presentation.
//
Function GeneratePhonePresentation(CountryCode, CityCode, PhoneNumber, PhoneExtension, Comment) Export
	
	Presentation = TrimAll(CountryCode);
	If Not IsBlankString(Presentation) And Not StrStartsWith(Presentation, "+") Then
		Presentation = "+" + Presentation;
	EndIf;
	
	If Not IsBlankString(CityCode) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " ") + "(" + TrimAll(CityCode) + ")";
	EndIf;
	
	If Not IsBlankString(PhoneNumber) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " ") + TrimAll(PhoneNumber);
	EndIf;
	
	If Not IsBlankString(PhoneExtension) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", ", ") + NStr("en = 'ext.';") + " " + TrimAll(PhoneExtension);
	EndIf;
	
	If Not IsBlankString(Comment) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", ", ") + TrimAll(Comment);
	EndIf;
	
	Return Presentation;
	
EndFunction

// Returns a flag indicating whether a contact information data string is in XML format.
//
// Parameters:
//     Text - String - a string to check.
//
// Returns:
//     Boolean - check result.
//
Function IsXMLContactInformation(Val Text) Export
	
	Return TypeOf(Text) = Type("String") And StrStartsWith(TrimL(Text), "<");
	
EndFunction

// Returns a flag indicating whether a contact information data string is in JSON format.
//
// Parameters:
//     Text - String - a string to check.
//
// Returns:
//     Boolean - check result.
//
Function IsJSONContactInformation(Val Text) Export
	
	Return TypeOf(Text) = Type("String") And StrStartsWith(TrimL(Text), "{");
	
EndFunction

// Text that is displayed in the contact information field when contact information is empty and displayed as
// a hyperlink.
// 
// Returns:
//  String - a text that is displayed in the contact information field.
//
Function BlankAddressTextAsHyperlink() Export
	Return NStr("en = 'Fill';");
EndFunction

// Determines whether information is entered in the contact information field when it is displayed as a hyperlink.
//
// Parameters:
//  Value - String - a contact information value.
// 
// Returns:
//  Boolean  - if True, the contact information field is filled in.
//
Function ContactsFilledIn(Value) Export
	Return TrimAll(Value) <> BlankAddressTextAsHyperlink();
EndFunction

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Use ContactsManager.ContactInformationPresentation instead
// Generates a presentation with the specified kind for the address input form.
//
// Parameters:
//    AddressStructure1  - Structure - an address as a structure.
//                                   See structure details in the AddressManager.AddressInfo function.
//                                   See details of the previous structure version in the AddressManager.PreviousContactInformationXMLStructure function.
//    Presentation    - String    - address presentation.
//    KindDescription - String    - a kind description.
//
// Returns:
//    String - an address presentation with kind.
//
Function GenerateAddressPresentation(AddressStructure1, Presentation, KindDescription = Undefined) Export
	
	Presentation = "";
	
	If TypeOf(AddressStructure1) <> Type("Structure") Then
		Return Presentation;
	EndIf;
	
	AddShortForms = AddressStructure1.Property("County");
	
	If AddressStructure1.Property("Country") Then
		Presentation = AddressStructure1.Country;
	EndIf;
	
	AddressPresentationByStructure(AddressStructure1, "IndexOf", Presentation);
	AddressPresentationByStructure(AddressStructure1, "State", Presentation, "AreaAbbr", AddShortForms);
	AddressPresentationByStructure(AddressStructure1, "County", Presentation, "CountyAbbr", AddShortForms);
	AddressPresentationByStructure(AddressStructure1, "District", Presentation, "DistrictAbbr", AddShortForms);
	AddressPresentationByStructure(AddressStructure1, "City", Presentation, "CityAbbr", AddShortForms);
	AddressPresentationByStructure(AddressStructure1, "Locality", Presentation, "LocalityAbbr", AddShortForms);
	AddressPresentationByStructure(AddressStructure1, "Territory", Presentation, "TerritoryAbbr", AddShortForms);
	AddressPresentationByStructure(AddressStructure1, "Street", Presentation, "StreetShortForm", AddShortForms);
	AddressPresentationByStructure(AddressStructure1, "AdditionalTerritory", Presentation, "AdditionalTerritoryAbbr", AddShortForms);
	AddressPresentationByStructure(AddressStructure1, "AdditionalTerritoryItem", Presentation, "AdditionalTerritoryItemAbbr", AddShortForms);
	
	If AddressStructure1.Property("BuildingUnit") Then
		SupplementAddressPresentation(TrimAll(ValueByStructureKey("Number", AddressStructure1.BuildingUnit)), ", " + ValueByStructureKey("BuildingType", AddressStructure1.BuildingUnit) + " ", Presentation);
	Else
		SupplementAddressPresentation(TrimAll(ValueByStructureKey("House", AddressStructure1)), ", " + ValueByStructureKey("HouseType", AddressStructure1) + " ", Presentation);
	EndIf;
	
	If AddressStructure1.Property("BuildingUnits") Then
		For Each Building In AddressStructure1.BuildingUnits Do
			SupplementAddressPresentation(TrimAll(ValueByStructureKey("Number", Building )), ", " + ValueByStructureKey("BuildingUnitType", Building)+ " ", Presentation);
		EndDo;
	Else
		SupplementAddressPresentation(TrimAll(ValueByStructureKey("Building", AddressStructure1)), ", " + ValueByStructureKey("BuildingUnitType", AddressStructure1)+ " ", Presentation);
	EndIf;
	
	If AddressStructure1.Property("Premises") Then
		For Each Premise In AddressStructure1.Premises Do
			SupplementAddressPresentation(TrimAll(ValueByStructureKey("Number", Premise)), ", " + ValueByStructureKey("PremiseType", Premise)+ " ", Presentation);
		EndDo;
	Else
		SupplementAddressPresentation(TrimAll(ValueByStructureKey("Appartment", AddressStructure1)), ", " + ValueByStructureKey("ApartmentType", AddressStructure1) + " ", Presentation);
	EndIf;
	
	KindDescription = ValueByStructureKey("KindDescription", AddressStructure1);
	PresentationWithKind = KindDescription + ": " + Presentation;
	
	Return PresentationWithKind;
	
EndFunction

// Deprecated. Obsolete. To get an address, use AddressManager.AddressInfo instead.
// To get a phone or fax structure, use ContactsManager.PhoneInfo instead.
// Returns contact information structure by type.
//
// Parameters:
//  CIType - EnumRef.ContactInformationTypes - contact information type.
//  AddressFormat - String - not used, left for backward compatibility.
// 
// Returns:
//  Structure - a blank contact information structure, keys - field names and field values.
//
Function ContactInformationStructureByType(CIType, AddressFormat = Undefined) Export
	
	If CIType = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Return AddressFieldsStructure();
	ElsIf CIType = PredefinedValue("Enum.ContactInformationTypes.Phone") Then
		Return PhoneFieldStructure();
	Else
		Return New Structure;
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

// Details of contact information keys for storing its values in the JSON format.
// The keys list can be extended with fields in the same-name function of the AddressManagerClientServer common module.
//
// Parameters:
//  ContactInformationType  - EnumRef.ContactInformationTypes - contact information type
//                             that determines a composition of contact information fields.
//
// Returns:
//   Structure - Contact information fields:
//     * value - String - a contact information presentation.
//     * comment - String - comment.
//     * type - String - a contact information type. See the value in Enum.ContactInformationTypes.Address.
//     Extended composition of fields for contact information type "Address":
//     * Country - String - a country name, for example, Russia.
//     * CountryCode - String -country code.
//     * ZIPcode- String - postal code.
//     * Area - String - a state description.
//     * AreaType - String - a short form (type) of "state".
//     * City - String - a city description.
//     * CityType - String - a short form (type) of "city", for example, c.
//     * Street - String - a street name.
//     * StreetType - String - a short form (type) of "street", for example, st.
//     Extended composition of fields for contact information type "Phone":
//     * CountryCode - String - country code.
//     * AreaCode - String - a state code.
//     * Number - String - a phone number.
//     * ExtNumber - String - an extension.
//
Function NewContactInformationDetails(Val ContactInformationType) Export
	
	If TypeOf(ContactInformationType) <> Type("EnumRef.ContactInformationTypes") Then
		ContactInformationType = "";
	EndIf;
	
	Result = New Structure;
	
	Result.Insert("version", 4);
	Result.Insert("value",   "");
	Result.Insert("comment", "");
	Result.Insert("type",    ContactInformationTypeToString(ContactInformationType));
	
	If ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		
		Result.Insert("country",     "");
		Result.Insert("addressType", CustomFormatAddress());
		Result.Insert("countryCode", "");
		Result.Insert("ZIPcode",     "");
		Result.Insert("area",        "");
		Result.Insert("areaType",    "");
		Result.Insert("city",        "");
		Result.Insert("cityType",    "");
		Result.Insert("street",      "");
		Result.Insert("streetType",  "");
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Phone")
		Or ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Fax") Then
		
		Result.Insert("countryCode", "");
		Result.Insert("areaCode", "");
		Result.Insert("number", "");
		Result.Insert("extNumber", "");
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.WebPage") Then
		
		Result.Insert("name", "");
		
	EndIf;
	
	Return Result;
	
EndFunction

// Parameters:
//  Form- ClientApplicationForm
// 
// Returns:
//  FormDataCollection:
//   *  AttributeName  - String
//   *  Kind           - CatalogRef.ContactInformationKinds
//   *  Type           - EnumRef.ContactInformationTypes
//   *  Value      - String
//   *  Presentation - String
//   *  Comment   - String
//   *  IsTabularSectionAttribute - Boolean
//   *  IsHistoricalContactInformation - Boolean
//   *  ValidFrom - Date
//   *  StoreChangeHistory - Boolean
//   *  ItemForPlacementName - String
//   *  InternationalAddressFormat - Boolean
//   *  Mask - String
//
Function DescriptionOfTheContactInformationOnTheForm(Form) Export
	Return Form.ContactInformationAdditionalAttributesDetails;
EndFunction

#EndRegion

#Region Private

// Returns:
//  Structure - Contact information details:
//    * FieldValues - String - contact information in JSON format
//    * Presentation - String - a contact information presentation. Used if it is impossible to determine 
//                              a presentation based on a parameter. In FieldValues, the Presentation field is not available.
//    * ContactInformationKind - EnumRef.ContactInformationTypes 
//                              - CatalogRef.ContactInformationKinds - contact information type
//
Function ContactInformationDetails(FieldValues, Presentation, ContactInformationKind) Export
	
	Result = New Structure;
	Result.Insert("FieldValues", FieldValues);
	Result.Insert("Presentation", Presentation);
	Result.Insert("ContactInformationKind", ContactInformationKind);
	
	Return Result;
	
EndFunction

Function ContactInformationTypeToString(Val ContactInformationType)
	
	Result = New Map;
	Result.Insert(PredefinedValue("Enum.ContactInformationTypes.Address"), "Address");
	Result.Insert(PredefinedValue("Enum.ContactInformationTypes.Phone"), "Phone");
	Result.Insert(PredefinedValue("Enum.ContactInformationTypes.Email"), "Email");
	Result.Insert(PredefinedValue("Enum.ContactInformationTypes.Skype"), "Skype");
	Result.Insert(PredefinedValue("Enum.ContactInformationTypes.WebPage"), "WebPage");
	Result.Insert(PredefinedValue("Enum.ContactInformationTypes.Fax"), "Fax");
	Result.Insert(PredefinedValue("Enum.ContactInformationTypes.Other"), "Other");
	Result.Insert("", "");
	Return Result[ContactInformationType];
	
EndFunction

Function CustomFormatAddress() Export
	Return "FreeForm";
EndFunction

Function EEUAddress() Export
	Return "EEU";
EndFunction

Function ForeignAddress() Export
	Return "Foreign2";
EndFunction

Function IsAddressInFreeForm(AddressType) Export
	Return StrCompare(CustomFormatAddress(), AddressType) = 0;
EndFunction

Function ConstructionOrPremiseValue(Type, Value) Export
	Return New Structure("type, number", Type, Value);
EndFunction

// Returns a blank address structure.
//
// Returns:
//    Structure - address, keys - field names and field values.
//
Function AddressFieldsStructure() Export
	
	AddressStructure1 = New Structure;
	AddressStructure1.Insert("Presentation", "");
	AddressStructure1.Insert("Country", "");
	AddressStructure1.Insert("CountryDescription", "");
	AddressStructure1.Insert("CountryCode","");
	
	Return AddressStructure1;
	
EndFunction

// Returns command details for the given contact information kind.
//
// Parameters:
//   ContactInformationParameters - Structure:
//     * GroupForPlacement - String
//     * TitleLocation - String
//     * AddedAttributes - ValueList
//     * DeferredInitialization - Boolean
//     * DeferredInitializationExecuted - Boolean
//     * AddedItems - ValueList
//     * ItemsToAddList - ValueList:
//         * Value - Structure:
//           ** Ref - CatalogRef.ContactInformationKinds
//         * Key - String
//     * CanSendSMSMessage1 - Boolean
//     * Owner - AnyRef
//     * URLProcessing - Boolean
//     * HiddenKinds - Array - Contact information kinds to be hidden from the form.
//     * DetailsOfCommands - See ContactsManager.DetailsOfCommands
//     * ShouldShowIcons - Boolean
//     * ItemsPlacedOnForm - Map of KeyAndValue - Contact information kinds that were added to the form interactively.
//                                         In case of deferred initialization, they will appear on the form after the 
//                                         ContactsManager.ExecuteDeferredInitialization procedure is called.:
//         * Key - CatalogRef.ContactInformationKinds
//         * Value - Boolean
//     * ExcludedKinds - Array - Obsolete. Instead, use "ItemsPlacedOnForm".
//     * AllowAddingFields - Boolean
//   Type - EnumRef.ContactInformationTypes
//   Kind - CatalogRef.ContactInformationKinds
//   StoreHistory - Boolean
//
// Returns:
//   See ContactsManager.CommandsOfContactInfoType
//
Function CommandsToOutputToForm(ContactInformationParameters, Type, Kind, StoreHistory) Export
	
	DetailsOfCommands = ContactInformationParameters.DetailsOfCommands;
	
	If ValueIsFilled(Kind) Then
		KindCommands = DetailsOfCommands[Kind];	
	Else
		KindCommands = Undefined;
	EndIf;

	TypeCommands = DetailsOfCommands[Type];
	
	CommandsForOutput = New Structure;
	
	If TypeCommands = Undefined Then
		Return CommandsForOutput;
	EndIf;
	
	If KindCommands = Undefined Then
		For Each TypeCommand In TypeCommands Do
			If ValueIsFilled(TypeCommand.Value.Action) Then
				CommandsForOutput.Insert(TypeCommand.Key, TypeCommand.Value);
			EndIf;
		EndDo;
	Else
		For Each TypeCommand In TypeCommands Do
			KindCommandVal = KindCommands[TypeCommand.Key];
			If KindCommandVal = Undefined Then
				If ValueIsFilled(TypeCommand.Value.Action) Then
					CommandsForOutput.Insert(TypeCommand.Key, TypeCommand.Value);
				EndIf;
			Else
				If ValueIsFilled(KindCommandVal.Action) Then
					CommandsForOutput.Insert(TypeCommand.Key, KindCommandVal);
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	If Type = PredefinedValue("Enum.ContactInformationTypes.Phone") Then
		If Not ContactInformationParameters.CanSendSMSMessage1 Then
			CommandsForOutput.Delete("SendSMS");
		EndIf;
	ElsIf Type = PredefinedValue("Enum.ContactInformationTypes.WebPage") Then 	
		If ContactInformationParameters.URLProcessing Then
			CommandsForOutput.Delete("OpenWebPage");
		EndIf;
	EndIf;	
	
	If Not StoreHistory And (Type = PredefinedValue("Enum.ContactInformationTypes.Address")
		Or Type = PredefinedValue("Enum.ContactInformationTypes.Phone")
		Or Type = PredefinedValue("Enum.ContactInformationTypes.Fax")) Then
		CommandsForOutput.Delete("ShowChangeHistory");	
	EndIf;
	
	Return CommandsForOutput;
	
EndFunction

// Returns a detailed prompt for the given address.
// 
// Parameters:
//  CommandsForOutput    - Structure:
//    * AddCommentToAddress - See ContactsManager.CommandProperties
//    * ShowOnYandexMaps    - See ContactsManager.CommandProperties
//    * ShowOnGoogleMap    - See ContactsManager.CommandProperties
//    * PlanMeeting     - See ContactsManager.CommandProperties
//    * ShowChangeHistory - See ContactsManager.CommandProperties
//  AddressPresentation - String
//  Comment         - String
// 
// Returns:
//  FormattedString
//
Function ExtendedTooltipForAddress(CommandsForOutput, AddressPresentation, Comment) Export

	If CommandsForOutput.Property("AddCommentToAddress") And ValueIsFilled(AddressPresentation) Then
		ModifyComment = New FormattedString(CommandsForOutput.AddCommentToAddress.Picture, , , ,
			"AddCommentToAddress");
	Else
		ModifyComment = "";
	EndIf;

	If CommandsForOutput.Property("ShowOnYandexMaps") And CommandsForOutput.Property("ShowOnGoogleMap") Then
		ShowOnMap = New FormattedString(NStr("en = 'On map';"),,WebColors.Gray, , "ShowOnMap");
	ElsIf CommandsForOutput.Property("ShowOnYandexMaps") Then
		ShowOnMap = New FormattedString(CommandsForOutput.ShowOnYandexMaps.Title, ,WebColors.Gray, , "ShowOnYandexMaps");
	ElsIf CommandsForOutput.Property("ShowOnGoogleMap") Then
		ShowOnMap = New FormattedString(CommandsForOutput.ShowOnGoogleMap.Title, ,WebColors.Gray, , "ShowOnGoogleMap");
	Else
		ShowOnMap = "";
	EndIf;

	If CommandsForOutput.Property("ShowChangeHistory") Then
		ShowHistory = New FormattedString("History", ,WebColors.Gray, , "ShowChangeHistory");
	Else
		ShowHistory = "";
	EndIf;

	If CommandsForOutput.Property("PlanMeeting") Then
		PlanMeeting = New FormattedString(CommandsForOutput.PlanMeeting.Title, ,WebColors.Gray , , "PlanMeeting");
	Else
		PlanMeeting = "";
	EndIf;          
	
	Indent = ?(ValueIsFilled(ShowHistory) And ValueIsFilled(ShowOnMap), "    ", "");
	CommandsString = New FormattedString(ShowHistory, Indent, ShowOnMap);
	
	Indent = ?(ValueIsFilled(CommandsString) And ValueIsFilled(PlanMeeting), "    ", "");
	CommandsString = New FormattedString(CommandsString, Indent, PlanMeeting);   

	If ValueIsFilled(Comment) Then
		ModifyComment = ?(ValueIsFilled(ModifyComment), ModifyComment, ""); 
		Indent = ?(ValueIsFilled(ModifyComment), " ", "");  
		IndentBeforeCommands = ?(ValueIsFilled(CommandsString), "    ", "");
		ExtendedTooltipForAddress = New FormattedString(ModifyComment, Indent, TrimAll(Comment), IndentBeforeCommands, CommandsString);
	Else
		Indent = ?(ValueIsFilled(CommandsString) And ValueIsFilled(ModifyComment), "    ", ""); 
		ExtendedTooltipForAddress = New FormattedString(ModifyComment, Indent, CommandsString);
	EndIf;    
		
	Return ExtendedTooltipForAddress;

EndFunction

#Region PrivateForWorkingWithXMLAddresses

// Returns structure with a description and a short form by value.
//
// Parameters:
//     Text - String - full description.
//
// Returns:
//     Structure:
//         * Description - String - a text part.
//         * Abbr   - String - a text part.
//
Function DescriptionShortForm(Val Text) Export
	Result = New Structure("Description, Abbr");
	
	Text = TrimAll(Text);
	
	TextUppercase = Upper(Text);
	If StrEndsWith(TextUppercase, "TER. HS")
		Or StrEndsWith(TextUppercase, "TER. SUBURBANNONCOMMERCIALCOMMUNITY") Then
		Result.Abbr = Right(Text, 8);
		Result.Description = Left(Text, StrLen(Text) - 9);
		Return Result;
	EndIf;
	
	Parts = DescriptionsAndShortFormsSet(Text, True);
	If Parts.Count() > 0 Then
		FillPropertyValues(Result, Parts[0]);
	Else
		Result.Description = Text;
	EndIf;
	
	Return Result;
EndFunction

Function ConnectTheNameAndTypeOfTheAddressObject(Val Description, Val AddressObjectType, ThisIsTheRegion = False) Export
	
	If IsBlankString(AddressObjectType) Then
		Return Description;
	EndIf;
	
	If ThisIsTheRegion Then
		
		
		Return TrimAll(Description + " " + AddressObjectType);
	EndIf;
	
	Return TrimAll(AddressObjectType + " "+ Description);
	
EndFunction

// Splits text into words using the specified separators. Default separators are space characters.
//
// Parameters:
//     Text       - String - a string to split.
//     Separators - String - an optional string of separator characters.
//
// Returns:
//     Array - strings and words
//
Function TextWords(Val Text, Val Separators = Undefined)
	
	WordBeginning = 0;
	State   = 0;
	Result   = New Array;
	
	For Position = 1 To StrLen(Text) Do
		CurrentChar = Mid(Text, Position, 1);
		IsSeparator = ?(Separators = Undefined, IsBlankString(CurrentChar), StrFind(Separators, CurrentChar) > 0);
		
		If State = 0 And (Not IsSeparator) Then
			WordBeginning = Position;
			State   = 1;
		ElsIf State = 1 And IsSeparator Then
			Result.Add(Mid(Text, WordBeginning, Position-WordBeginning));
			State = 0;
		EndIf;
	EndDo;
	
	If State = 1 Then
		Result.Add(Mid(Text, WordBeginning, Position-WordBeginning));    
	EndIf;
	
	Return Result;
EndFunction

// Splits comma-separated text.
//
// Parameters:
//     Text              - String - a text to separate.
//     ExtractShortForms - Boolean - an optional parameter.
//
// Returns:
//     Array - contains "Description, ShortForm" structures.
//
Function DescriptionsAndShortFormsSet(Val Text, Val ExtractShortForms = True)
	
	Result = New Array;
	For Each Term In TextWords(Text, ",") Do
		PartRow = TrimAll(Term);
		If IsBlankString(PartRow) Then
			Continue;
		EndIf;
		
		Position = ?(ExtractShortForms, StrLen(PartRow), 0);
		While Position > 0 Do
			If Mid(PartRow, Position, 1) = " " Then
				Result.Add(New Structure("Description, Abbr",
					TrimAll(Left(PartRow, Position-1)), TrimAll(Mid(PartRow, Position))));
				Position = -1;
				Break;
			EndIf;
			Position = Position - 1;
		EndDo;
		If Position = 0 Then
			Result.Add(New Structure("Description, Abbr", PartRow));
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

#Region OtherPrivate

// Adds a string to an address presentation.
//
// Parameters:
//    AddOn         - String - an address addition.
//    ConcatenationString - String - a concatenation string.
//    Presentation      - String - address presentation.
//
Procedure SupplementAddressPresentation(AddOn, ConcatenationString, Presentation)
	
	If AddOn <> "" Then
		Presentation = Presentation + ConcatenationString + AddOn;
	EndIf;
	
EndProcedure

// Returns a value string by structure property.
// 
// Parameters:
//    Var_Key - String - a structure key.
//    Structure - Structure - a structure to pass.
//
// Returns:
//    Arbitrary - value.
//    String       - a blank string if there is no value.
//
Function ValueByStructureKey(Var_Key, Structure)
	
	Value = Undefined;
	
	If Structure.Property(Var_Key, Value) Then 
		Return String(Value);
	EndIf;
	
	Return "";
	
EndFunction

Procedure AddressPresentationByStructure(AddressStructure1, DescriptionKey, Presentation, ShortFormKey = "", AddShortForms = False, ConcatenationString = ", ")
	
	If AddressStructure1.Property(DescriptionKey) Then
		AddOn = TrimAll(AddressStructure1[DescriptionKey]);
		If ValueIsFilled(AddOn) Then
			If AddShortForms And AddressStructure1.Property(ShortFormKey) Then
				AddOn = AddOn + " " + TrimAll(AddressStructure1[ShortFormKey]);
			EndIf;
			If ValueIsFilled(Presentation) Then
				Presentation = Presentation + ConcatenationString + AddOn;
			Else
				Presentation = AddOn;
			EndIf;
		EndIf;
	EndIf;
EndProcedure

// Returns a blank phone structure.
//
// Returns:
//    Structure - keys - field names and field values.
//
Function PhoneFieldStructure() Export
	
	PhoneStructure = New Structure;
	PhoneStructure.Insert("Presentation", "");
	PhoneStructure.Insert("CountryCode", "");
	PhoneStructure.Insert("CityCode", "");
	PhoneStructure.Insert("PhoneNumber", "");
	PhoneStructure.Insert("PhoneExtension", "");
	PhoneStructure.Insert("Comment", "");
	
	Return PhoneStructure;
	
EndFunction

Function WebsiteAddress(Val Presentation, Val Ref, ReadOnly) Export
	
	If IsBlankString(Presentation) Or IsBlankString(Ref)  Then
		Presentation = BlankAddressTextAsHyperlink();
		Ref = WebsiteURL();
	EndIf;
	
	If StrCompare(Presentation, BlankAddressTextAsHyperlink()) = 0 And ReadOnly Then
		Return Presentation;
	EndIf;
	
	PresentationText = New FormattedString(Presentation,,,, Ref);
	
	If ReadOnly Then
		Return PresentationText;
	EndIf;
	
	PictureChange = New FormattedString(PictureLib.EditWebsiteAddress,,,, WebsiteURL());
	Return New FormattedString(PresentationText, "  ", PictureChange);

EndFunction

Function WebsiteURL() Export
	Return "e1cib/app/DataProcessor.ContactInformationInput.Form.Website";
EndFunction



// Returns a list of filling errors as a value list:
//
// Parameters:
//  InfoAboutPhone  - See PhoneFieldStructure
//  AdditionalChecksModule - Arbitrary
// 
// Returns:
//  ValueList - Phone number entry errors:
//    * Presentation   - Error details.
//    * Value        - XPath for the field.
//
Function PhoneFillingErrors(InfoAboutPhone, AdditionalChecksModule = Undefined) Export
	
	ErrorList = New ValueList;
	FullPhoneNumber = InfoAboutPhone.CountryCode + InfoAboutPhone.CityCode + InfoAboutPhone.PhoneNumber;
	
	CountryCodeNumbersOnly = LeaveOnlyTheNumbersInTheLine(InfoAboutPhone.CountryCode);
	If ValueIsFilled(InfoAboutPhone.CountryCode) And IsBlankString(CountryCodeNumbersOnly) Then
		ErrorList.Add("CountryCode", NStr("en = 'Country code contains invalid characters';"));
	EndIf;
	
	PhoneNumberNumbersOnly = LeaveOnlyTheNumbersInTheLine(InfoAboutPhone.Presentation);
	If IsBlankString(PhoneNumberNumbersOnly) Then
		ErrorList.Add("PhoneNumber", NStr("en = 'Phone number does not contain digits';"));
	EndIf;

	FullPhoneNumberOnlyDigits = LeaveOnlyTheNumbersInTheLine(FullPhoneNumber);
	If StrLen(FullPhoneNumberOnlyDigits) > 15 Then
		ErrorList.Add("PhoneNumber", NStr("en = 'Phone number is too long.';"));
	EndIf;
	
	If ValueIsFilled(InfoAboutPhone.CountryCode) And PhoneNumberContainsProhibitedChars(InfoAboutPhone.CountryCode) Then
		ErrorList.Add("CountryCode", NStr("en = 'Country code contains invalid characters';"));
	EndIf;
	
	If ValueIsFilled(InfoAboutPhone.CityCode) And PhoneNumberContainsProhibitedChars(InfoAboutPhone.CityCode) Then
		ErrorList.Add("CityCode", NStr("en = 'City code contains invalid characters';"));
	EndIf;
	
	If ValueIsFilled(InfoAboutPhone.PhoneNumber) And PhoneNumberContainsProhibitedChars(InfoAboutPhone.PhoneNumber) Then
		ErrorList.Add("PhoneNumber", NStr("en = 'Phone number contains illegal characters.';"));
	EndIf;
	
	If AdditionalChecksModule <> Undefined Then
		AdditionalChecksModule.CheckCorrectnessOfCountryAndCityCodes(InfoAboutPhone, ErrorList);
	EndIf;
	
	Return ErrorList;
	
EndFunction

Function LeaveOnlyTheNumbersInTheLine(Val String) Export
	
	ExcessCharacters = StrConcat(StrSplit(String, "0123456789"), "");
	Result     = StrConcat(StrSplit(String, ExcessCharacters), "");
	
	Return Result;
	
EndFunction

// Checks whether the string contains only ~
//
// Parameters:
//  CheckString          - String - a string to check.
//
// Returns:
//   Boolean - True - the string contains only numbers or is empty, False - the string contains other characters.
//
Function PhoneNumberContainsProhibitedChars(Val CheckString)
	
	AllowedCharactersList = "+-.,() wp1234567890";
	Return StrSplit(CheckString, AllowedCharactersList, False).Count() > 0;
	
EndFunction

#EndRegion

#EndRegion