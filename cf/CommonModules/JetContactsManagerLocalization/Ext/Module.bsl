
#Region Public

Procedure SetContactInformationComment(ContactInformation, Val Comment) Export
	// empty by design
EndProcedure

// Converts XML into XDTO object of contact information.
//
//  Parameters:
//      Text - String - an XML string of contact information.
//      ExpectedKind - CatalogRef.ContactsKinds, EnumRef.ContactsTypes, Structure -
//      ConversionResult - Structure - if set, the following info is written to properties:
//        * ErrorText - String - details of read errors. The return value of the function will be 
//                                 correct but not filled.
//
// Returns:
//      XDTOObject - contact information matching the XDTO package ContactInformation.
//   
Function ContactsFromXML(Val Text, Val ExpectedKind = Undefined, ConversionResult = Undefined, Val Presentation = "") Export
	
	ExpectedType = ContactsManagerInternalCached.ContactInformationKindType(ExpectedKind);
	
	If ConversionResult = Undefined Or TypeOf(ConversionResult) <> Type("Structure") Then
		ConversionResult = New Structure;
	EndIf;
	ConversionResult.Insert("InfoCorrected", False);
	
	EnumAddress      = Enums.ContactInformationTypes.Address;
	EnumEmailAddress = Enums.ContactInformationTypes.Email;
	EnumSkype        = Enums.ContactInformationTypes.Skype;
	EnumWebpage      = Enums.ContactInformationTypes.WebPage;
	EnumPhone        = Enums.ContactInformationTypes.Phone;
	EnumFax          = Enums.ContactInformationTypes.Fax;
	EnumOther        = Enums.ContactInformationTypes.Other;
	
	Namespace = JetAddressManager.Namespace();
	
	If ContactsManagerClientServer.IsXMLContactInformation(Text) Then
		XMLReader = New XMLReader;
		
		If Metadata.CommonModules.Find("AddressManager") <> Undefined Then
			ModuleAddressManager = Common.CommonModule("AddressManager");
			Text = ModuleAddressManager.BeforeReadXDTOContactInformation(Text);
		EndIf;
		
		XMLReader.SetString(Text);
		
		ErrorText = Undefined;
		
		ContactsRestorationRequired = False;
		
		Try
			Result = XDTOFactory.ReadXML(XMLReader, XDTOFactory.Type(Namespace, "ContactInformation"));
			
			If ExpectedType = Enums.ContactInformationTypes.Address AND XDTOContactsEmpty(Result) Then
				ContactsRestorationRequired = True;
			EndIf;
			
		Except
			
			ContactsRestorationRequired = True;
			
		EndTry;
		
		If ContactsRestorationRequired Then
			ErrorCauseDetails = NStr("en = 'Data on contact information recovered after failure.'; tr = 'İletişim bilgileri başarısız olduktan sonra geri yüklendi.'");
			If ValueIsFilled(Presentation) Then
				Result = XDTOContactsByPresentation(Presentation, ExpectedKind);
				If StrCompare(Result.Presentation, Presentation) <> 0  Then
					ErrorText = ErrorCauseDetails;
					ConversionResult.Insert("ErrorText", ErrorText);
				EndIf;
				
			EndIf;
			
			// Invalid XML format
			WriteLogEvent(EventLogEvent(),
				EventLogLevel.Warning, , Text, ErrorCauseDetails + Chars.LF
					+ ErrorInfo().Description);
				
			ConversionResult.Insert("InfoCorrected", True);
		EndIf;
		
		If ErrorText = Undefined AND ExpectedType <> Undefined Then
			
			If Result = Undefined Then
				ErrorText = StrReplace(NStr("en = 'A part of %ExpectedKind% contact information was damaged or populated incorrectly.'; tr = 'İletişim bilgileri %ExpectedKind% bozuk veya yanlış doldurulmuş.'"),
					"%ExpectedKind%", String(ExpectedKind));
			Else
				// Checking for type mapping.
				TypeFound = ?(Result.Content = Undefined, Undefined, Result.Content.Type());
				
				MessageTemplate = StrReplace(NStr("en = 'The %1 part of %ExpectedKind% contact information was damaged or populated incorrectly.'; tr = 'İletişim bilgileri %1 %ExpectedKind% bozuk veya yanlış doldurulmuş.'"),
					"%ExpectedKind%", String(ExpectedKind));
				If ExpectedType = EnumAddress AND TypeFound <> XDTOFactory.Type(Namespace, "Address") Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, NStr("en = 'about address'; tr = 'adres hakkında'"));
				ElsIf ExpectedType = EnumEmailAddress AND TypeFound <> XDTOFactory.Type(Namespace, "Email") Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, NStr("en = 'email'; tr = 'e-posta'"));
				ElsIf ExpectedType = EnumWebpage AND TypeFound <> XDTOFactory.Type(Namespace, "Website") Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, NStr("en = 'web page'; tr = 'web sayfası'"));
				ElsIf ExpectedType = EnumPhone AND TypeFound <> XDTOFactory.Type(Namespace, "PhoneNumber") Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, NStr("en = 'about phone number'; tr = 'telefon numarası hakkında'"));
				ElsIf ExpectedType = EnumFax AND TypeFound <> XDTOFactory.Type(Namespace, "FaxNumber") Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, NStr("en = 'about fax number'; tr = 'faks numarası hakkında'"));
				ElsIf ExpectedType = EnumSkype AND TypeFound <> XDTOFactory.Type(Namespace, "Skype") Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, NStr("en = 'about Skype username'; tr = 'Skype login hakkında'"));
				ElsIf ExpectedType = EnumOther AND TypeFound <> XDTOFactory.Type(Namespace, "Other") Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, NStr("en = 'about additional'; tr = 'ek hakkında'"));
				EndIf;
			EndIf;
		EndIf;
		
		If ErrorText = Undefined Then
			// Successfully read
			Return Result;
		EndIf;
		
		ConversionResult.Insert("ErrorText", ErrorText);
		
		// Returning an empty object.
		Text = "";
	EndIf;
	
	If TypeOf(Text) = Type("ValueList") Then
		Presentation = "";
		IsNew = Text.Count() = 0;
	ElsIf IsBlankString(Presentation) Then
		Presentation = String(Text);
		IsNew = IsBlankString(Text);
	Else
		IsNew = False;
	EndIf;
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	
	// Parsing
	If ExpectedType = EnumAddress Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
		Else
			Result = XMLAddressInXDTO(Text, Presentation, ExpectedType);
		EndIf;
		
	ElsIf ExpectedType = EnumPhone Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		Else
			Result = PhoneDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumFax Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "FaxNumber"));
		Else
			Result = FaxDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumEmailAddress Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Email"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)
		EndIf;
	ElsIf ExpectedType = EnumSkype Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Skype"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)
		EndIf;
	ElsIf ExpectedType = EnumWebpage Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Website"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumOther Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Other"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	Else
		ErrorText = NStr("en = 'Information on contact information type %1 was damaged or filled in incorrectly
								|as the required ""Type"" field is not filled in.'; 
								|tr = 'İletişim bilgileri türü hakkındaki %1 bilgileri bozuk veya yanlış doldurulmuştur, 
								|çünkü zorunlu tür alanı doldurulmamıştır.'");
		ErrorText =  StringFunctionsClientServer.SubstituteParametersToString(ErrorText, ?(ValueIsFilled(ExpectedKind), """" + ExpectedKind.Description + """", ""));
		ConversionResult.Insert("ErrorText", ErrorText);
	EndIf;
	
	Return Result;
	
EndFunction

Function XMLAddressInXDTO(Val FieldsValues, Val Presentation = "", Val ExpectedType = Undefined) Export
	
	If Metadata.DataProcessors.Find("AdvancedContactInformationInput") <> Undefined Then
		Return DataProcessors["AdvancedContactInformationInput"].XMLAddressInXDTO(FieldsValues, Presentation, ExpectedType);
	EndIf;
	
	// Empty object with presentation.
	Namespace = JetAddressManager.Namespace();
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
	Result.Content.Content = Presentation;
	Result.Presentation = Presentation;
	
	Return Result;
	
EndFunction

// Converts XDTO contact information into XML.
//
//  Parameters:
//      XDTOInformationObject - XDTOObject - contact information.
//
// Returns:
//      String - a conversion result in XML format.
//
Function XDTOContactsInXML(XDTOInformationObject) Export
	
	Record = New XMLWriter;
	Record.SetString(New XMLWriterSettings(, , False, False, ""));
	
	If XDTOInformationObject <> Undefined Then
		XDTOFactory.WriteXML(Record, XDTOInformationObject);
	EndIf;
	
	Result = StrReplace(Record.Close(), Chars.LF, "&#10;");
	Result = StrReplace(Result, "<CityDistrict/>", "");// Compatibility with ARCA
	
	Return Result;
	
EndFunction

Function PhoneNumberToOldFieldList(XDTOPhone) Export
	
	Result = New ValueList;
	
	Result.Add(XDTOPhone.CountryCode,  "CountryCode");
	Result.Add(XDTOPhone.CityCode,  "CityCode");
	Result.Add(XDTOPhone.Number,      "PhoneNumber");
	Result.Add(XDTOPhone.Extension, "Extension");
	
	Return Result;
	
EndFunction

Function ContactsFromJSONToXML(Val ContactInformation, ExpectedType = Undefined) Export
	
	If ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		ContactInformation = JSONStringToStructure(ContactInformation);
	EndIf;
	
	If ExpectedType = Undefined Then
		
		If TypeOf(ContactInformation) = Type("Structure") AND ContactInformation.Property("Type") Then
			
			ExpectedType = Enums.ContactInformationTypes[ContactInformation.Type];
			
		ElsIf ContactsManagerClientServer.IsXMLContactInformation(ContactInformation) Then
			ContactInformationXML = TransformContactInformationXML(ContactInformation);
			ExpectedType = ContactInformationXML.ContactInformationType;
		Else
			ErrorText = NStr("en = 'An error occurred while converting contact information from JSON to XML.'; tr = 'İletişim bilgilerini JSON biçiminden XML''YE dönüştürme hatası.'");
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), 
				EventLogLevel.Error,,,
				ErrorText + Chars.LF + String(ContactInformation));
			Raise NStr("en = 'Cannot determine contact information type. For more information, see the event log.'; tr = 'İletişim bilgileri türü belirlenemedi. Daha fazla bilgi için olay günlüğüne bakın.'");
		EndIf;
		
	EndIf;
	
	Namespace = JetAddressManager.Namespace();

	IsNew = IsBlankString(ContactInformation);
	Presentation = "";
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	
	// Parsing
	If ExpectedType = Enums.ContactInformationTypes.Address Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
		Else
			Result = ConvertAddressFromJSONToXML(ContactInformation, Presentation, ExpectedType);
		EndIf;
	ElsIf ExpectedType = Enums.ContactInformationTypes.Phone Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		Else
			Result = ConvertPhoneFaxFromJSONToXML(ContactInformation, Presentation, ExpectedType)
		EndIf;
	ElsIf ExpectedType = Enums.ContactInformationTypes.Fax Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "FaxNumber"));
		Else
			Result = ConvertPhoneFaxFromJSONToXML(ContactInformation, Presentation, ExpectedType)
		EndIf;
	ElsIf ExpectedType = Enums.ContactInformationTypes.Email Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Email"));
		Else
			Result = ConvertOtherContactsFromJSONToXML(ContactInformation, Presentation, ExpectedType)
		EndIf;
	ElsIf ExpectedType = Enums.ContactInformationTypes.Skype Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Skype"));
		Else
			Result = ConvertOtherContactsFromJSONToXML(ContactInformation, Presentation, ExpectedType)
		EndIf;
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Website"));
		Else
			Result = ConvertOtherContactsFromJSONToXML(ContactInformation, Presentation, ExpectedType)
		EndIf;
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Other"));
		Else
			Result = ConvertOtherContactsFromJSONToXML(ContactInformation, Presentation, ExpectedType)
		EndIf;
	Else
		ErrorText = NStr("en = 'Information on contact information type %1 was damaged or filled in incorrectly
								|as the required ""Type"" field is not filled in.'; 
								|tr = 'İletişim bilgileri türü hakkındaki %1 bilgileri bozuk veya yanlış doldurulmuştur, 
								|çünkü zorunlu tür alanı doldurulmamıştır.'");
		ErrorText =  StringFunctionsClientServer.SubstituteParametersToString(ErrorText, ?(ValueIsFilled(ExpectedType), """" + TrimAll(ExpectedType) + """", ""));
	EndIf;
	
	Return XDTOContactsInXML(Result);
	
EndFunction

// Converts contact information into XML.
//
// Parameters:
//    Data - String - details of XML or JSON contact information.
//           - XTDOObject - contact information details.
//           - Structure - contact information details. The following fields are expected:
//                 * FieldsValues - String, Structure, ValueList, Map - contact information fields.
//                 * Presentation - String - a presentation. Used when presentation cannot be 
//                                            extracted from FieldsValues (the Presentation field is not available).
//                 * Comment - String - a comment. Used when a comment cannot be extracted from 
//                                          FieldsValues.
//                 * ContactsKind - CatalogRef.ContactsKinds,
//                                             EnumRef.ContactsTypes, Structure -
//                                             Used when a type cannot be extracted from FieldsValues.
//
// Returns:
//     Structure - contains the following fields:
//        * ContactInformationType - EnumRef.ContactInformationTypes
//        * XMLData - String - an XML text.
//
Function TransformContactInformationXML(Val Data) Export
	
	XMLString               = "";
	FieldsValues           = "";
	Comment             = Undefined;
	ContactInformationType = Undefined;
	
	If TypeOf(Data) = Type("XDTODataObject") Then
		XMLString = XDTOContactsInXML(Data);
		ContactInformationType = ValueFromXMLString(XSLT_ContactInformationTypeByXMLString(XMLString));
	Else
		
		If TypeOf(Data) = Type("Structure") Then
			FieldsValues = ?(Data.Property("FieldValues"), Data.FieldValues, "");;
			Comment = ?(Data.Property("Comment"), Data.Comment, "");
			
			If Data.Property("ContactInformationKind") AND Data.ContactInformationKind <> Undefined Then
				ContactInformationType = ContactsManagerInternalCached.ContactInformationKindType(Data.ContactInformationKind);
			EndIf;
			
		ElsIf TypeOf(Data) = Type("String") Then
			FieldsValues = Data;
		EndIf;
		
		If ContactsManagerClientServer.IsJSONContactInformation(FieldsValues) Then
			XMLString = ContactsFromJSONToXML(FieldsValues, ContactInformationType);
			ContactInformationType = ValueFromXMLString(XSLT_ContactInformationTypeByXMLString(XMLString));
		ElsIf IsXMLString(FieldsValues) Then
			XMLString = FieldsValues;
			ContactInformationType = ValueFromXMLString(XSLT_ContactInformationTypeByXMLString(XMLString));
		ElsIf TypeOf(FieldsValues) = Type("String") AND ContactInformationType = Undefined Then
			
			// Obsolete format key-value
			If StrFind(Upper(FieldsValues), "STATE=") > 0 Then
				ContactInformationType = Enums.ContactInformationTypes.Address;
			ElsIf StrFind(Upper(FieldsValues), "PHONENUMBER=") > 0 Then
				ContactInformationType = Enums.ContactInformationTypes.Phone;
			ElsIf StrFind(Upper(FieldsValues), "FAXNUMBER=") > 0 Then
				ContactInformationType = Enums.ContactInformationTypes.Fax;
			Else
				ContactInformationType = Enums.ContactInformationTypes.Other;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(XMLString) Then
		
		If Not IsBlankString(Comment) Then
			ContactsManager.SetContactInformationComment(FieldsValues, Comment);
		EndIf;
		
		Return New Structure("XMLData1, ContactInformationType", XMLString, ContactInformationType);
		
	EndIf;
	
	// Parsing by FieldsValues, ContactInformationKind, Presentation.
	FieldValueType = TypeOf(FieldsValues);
	If FieldValueType = Type("String") Then
		// Text contained in key-value pairs
		XMLStructureString = XSLT_KeyValueStringToStructure(FieldsValues)
		
	ElsIf FieldValueType = Type("ValueList") Then
		// Value list
		XMLStructureString = XSLT_ValueListToStructure(ValueToXMLString(FieldsValues) );
		
	ElsIf FieldValueType = Type("Map") Then
		// Map
		XMLStructureString = XSLT_MapToStructure( ValueToXMLString(FieldsValues) );
		
	ElsIf FieldValueType = Type("XDTODataObject") Then
		// Expecting a structure
		If FieldsValues.Content.Country = Undefined Then
			FieldsValues.Content.Country = "";
		EndIf;
		If FieldsValues.Content.Content = Undefined Then
			FieldsValues.Content.Content = "";
		EndIf;
		
		XMLStructureString = ValueToXMLString(FieldsValues);
	Else
		// Expecting a structure
		XMLStructureString = ValueToXMLString(FieldsValues);
		
	EndIf;
	
	Result = New Structure("ContactInformationType, XMLData1, Presentation", ContactInformationType, "", Data.Presentation);
	
	AllTypes = Enums.ContactInformationTypes;
	If ContactInformationType = AllTypes.Address Then
		Result.XMLData1 = XSLT_StructureToAddress(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Email Then
		Result.XMLData1 = XSLT_StructureToEmailAddress(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.WebPage Then
		Result.XMLData1 = XSLT_StructureToWebPage(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Phone Then
		Result.XMLData1 = XSLT_StructureToPhone(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Fax Then
		Result.XMLData1 = XSLT_StructureToFax(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Other Then
		Result.XMLData1 = XSLT_StructureToOther(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Skype Then
		Result.XMLData1 = XSLT_StructureToOther(XMLStructureString, Data.Presentation, Comment);
		
	Else
		Raise NStr("en = 'Transformation parameter error, contact information type not specified'; tr = 'Dönüşüm parametreleri hatası, iletişim bilgileri türü belirlenmedi'");
		
	EndIf;
	
	Return Result;
	
EndFunction

// Reads the string containing composition of the contact information value.
// If the composition value has a complex type, returns undefined.
//
// Parameters:
//    Text - String - an XML string of contact information. Can be modified.
//
// Returns:
//    String - composition XML value.
//    Undefined - the Composition property is not found.
//
Function ContactInformationCompositionString(Val Text, Val NewValue = Undefined) Export
	
	Read = New XMLReader;
	Read.SetString(Text);
	XDTODataObject= XDTOFactory.ReadXML(Read, XDTOFactory.Type("http://www.v8.1c.ru/ssl/contactinfo", "ContactInformation"));
	
	Composition = XDTODataObject.Content;
	If Composition <> Undefined 
		AND Composition.Properties().Get("Value") <> Undefined
		AND TypeOf(Composition.Value) = Type("String") Then
		Return Composition.Value;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Converts a string into XDTO contact information of phone.
//
//      FieldsValues - String - serialized information, field values.
//      Presentation - String - superiority-based presentation. Used for parsing purposes if 
//                               FieldsValues is empty.
//      ExpectedType - EnumRef.ContactsType - an optional type for control.
//
//  Returns:
//      XDTOObject - contact information.
//
Function PhoneDeserialization(FieldsValues, Presentation = "", ExpectedType = Undefined) Export
	
	Return PhoneFaxDeserialization(FieldsValues, Presentation, ExpectedType);
	
EndFunction

// Converts a string into XDTO contact information of fax.
//
//      FieldsValues - String - serialized information, field values.
//      Presentation - String - superiority-based presentation. Used for parsing purposes if 
//                               FieldsValues is empty.
//      ExpectedType - EnumRef.ContactsType - an optional type for control.
//
//  Returns:
//      XDTOObject - contact information.
//
Function FaxDeserialization(FieldsValues, Presentation = "", ExpectedType = Undefined) Export
	
	Return PhoneFaxDeserialization(FieldsValues, Presentation, ExpectedType);
	
EndFunction

// Returns contact information presentation.
//
// Parameters:
//   ContactInformation -String - an address in a JSON or XML format.
//   ContactInformationFormat  - String             - if set to "ARCA", the address presentation 
//                                        does not include values of county and city district levels.
//    ContactsType - Structure - additional parameters of presentation generation for the addresses:
//      * Type - String - a contact information type.
//      * IncludeCountryInPresentation - Boolean - an address country will be included in the presentation;
//      * AddressFormat                 - String - if set to "ARCA", the address presentation does 
//                                                not include values of county and city district levels.
// Returns:
//      String - a generated presentation.
//
Function ContactInformationPresentation(Val ContactInformation, Val ContactsFormat) Export
	
	If IsBlankString(ContactInformation) Then
		Return "";
	EndIf;
	
	Kind = Undefined;
	If ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		ContactInformation = JSONStringToStructure(ContactInformation);
	ElsIf TypeOf(ContactInformation) = Type("String") Or TypeOf(ContactInformation) = Type("XDTODataObject") Then
		ContactInformation = ContactInformationToJSONStructure(ContactInformation);
	EndIf;
	If IsBlankString(ContactInformation.Value) Then
		GenerateContactInformationPresentation(ContactInformation, Kind);
	EndIf;
	
	Return ContactInformation.Value
	
EndFunction

// Converts the XML format to the JSON format
//
Function ContactInformationToJSONStructure(ContactInformation, Val Type = Undefined, Presentation = "", UpdateIDs = True) Export
	
	If Type <> Undefined AND TypeOf(Type) <> Type("EnumRef.ContactInformationTypes") Then
		Type = ContactsManagerInternalCached.ContactInformationKindType(Type);
	EndIf;
	
	If Type = Undefined Then
		If TypeOf(ContactInformation) = Type("String") Then
			
			If IsXMLString(ContactInformation) Then
				Type = ContactInformationType(ContactInformation);
			EndIf;
			
		ElsIf TypeOf(ContactInformation) = Type("XDTODataObject") Then
			
			TypeFound = ?(ContactInformation.Content = Undefined, Undefined, ContactInformation.Content.Type());
			Type = MapXDTOToContactsTypes(TypeFound);
			
		EndIf;
	EndIf;
	
	If Metadata.CommonModules.Find("AddressManager") <> Undefined AND Type = Enums.ContactInformationTypes.Address Then
		ModuleAddressManager = Common.CommonModule("AddressManager");
		Return ModuleAddressManager.ContactInformationToJSONStructure(ContactInformation, Type, Presentation, UpdateIDs);
	EndIf;
	
	Result = ContactsManagerClientServer.NewContactInformationDetails(Type);
	
	CountryDescription = "";
	Format9Commas = False;
	AddressItems = New Map;
	
	If TypeOf(ContactInformation) = Type("String") Then
		If ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
			Return JSONStringToStructure(ContactInformation);
		ElsIf ContactsManagerClientServer.IsXMLContactInformation(ContactInformation) Then
			ConversionResult = New Structure;
			XDTOContactInformation = ContactsFromXML(ContactInformation, Type, ConversionResult, Presentation);
		Else
			If StrOccurrenceCount(ContactInformation, ",") = 9 Then
				Format9Commas  = True;
				Result.Value = ContactInformation
			Else
				XDTOContactInformation      = ContactsFromXML(ContactInformation, Type,, Presentation);
			EndIf;
		EndIf;
	ElsIf TypeOf(ContactInformation) = Type("Structure") Then
		
		FieldsMap = New Map();
		FieldsMap.Insert("Presentation", "value");
		FieldsMap.Insert("Comment",   "comment");
		
		If Type = Enums.ContactInformationTypes.Phone Then
			
			FieldsMap.Insert("CountryCode",     "countryCode");
			FieldsMap.Insert("CityCode",     "areaCode");
			FieldsMap.Insert("PhoneNumber", "number");
			FieldsMap.Insert("Extension",    "extNumber");
			
		EndIf;
		
		For each ContactInformationField In ContactInformation Do
			FieldName = FieldsMap.Get(ContactInformationField.Key);
			If FieldName <> Undefined Then
				Result[FieldName] = ContactInformationField.Value;
			EndIf;
		EndDo;
		
		Return Result;
		
	Else
		XDTOContactInformation = ContactInformation;
		Type = Enums.ContactInformationTypes.Address;
	EndIf;
	
	Result.Value = String(XDTOContactInformation.Presentation);
	Result.Comment = String(XDTOContactInformation.Comment);
	
	If Type <> Enums.ContactInformationTypes.Address AND Type <> Enums.ContactInformationTypes.Phone Then
		Return Result;
	EndIf;
	
	If NOT Format9Commas Then
		
		Namespace = JetAddressManager.Namespace();
		Composition = XDTOContactInformation.Content;
		
		If Composition = Undefined Then
			Return Result;
		EndIf;
		
		XDTODataType = Composition.Type();
		
		If XDTODataType = XDTOFactory.Type(Namespace, "Address") Then
			
			Result.Insert("Country", String(Composition.Country));
			Country = Catalogs.WorldCountries.FindByDescription(Composition.Country, True);
			CountryDescription = Country.Description;
			Result.Insert("CountryCode", TrimAll(Country.Code));
			
		ElsIf
			
			XDTODataType = XDTOFactory.Type(JetAddressManager.Namespace(), "PhoneNumber")
			Or XDTODataType = XDTOFactory.Type(JetAddressManager.Namespace(), "FaxNumber") Then
			
			Result.CountryCode = Composition.CountryCode;
			Result.AreaCode    = Composition.CityCode;
			Result.Number      = Composition.Number;
			Result.ExtNumber   = Composition.Extension;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the matching value of the ContactsType enumeration by the XML string.
//
// Parameters:
//    XMLString - a string describing contact information.
//
// Returns:
//     EnumRef.ContactsType - a result.
//
Function ContactInformationType(Val XMLString) Export
	
	Return ValueFromXMLString(XSLT_ContactInformationTypeByXMLString(XMLString));
	
EndFunction

// Parses a CI presentation and returns XDTO.
//
//  Parameters:
//      Text - String - XML
//      ExpectedKind - CatalogRef.ContactsKinds, EnumRef.ContactsTypes, Structure.
//
// Returns:
//      XDTOObject - contact information.
//
Function XDTOContactsByPresentation(Text, ExpectedKind) Export
	
	ExpectedType = ContactsManagerInternalCached.ContactInformationKindType(ExpectedKind);
	
	If ExpectedType = Enums.ContactInformationTypes.Address Then
		Return XMLAddressInXDTO("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Email Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Phone Then
		Return PhoneDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Fax Then
		Return FaxDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Skype Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	EndIf;
	
	Return Undefined;
	
EndFunction

Function JSONStringToStructure(Value) Export
	
	JSONReader = New JSONReader;
	JSONReader.SetString(Value);
	
	Result = ReadJSON(JSONReader,,,, "RestoreContactInformationFields", ContactsManagerInternal);
	
	JSONReader.Close();
	
	Return Result;
	
EndFunction

Function MapXDTOToContactsTypes(TypeFound) Export
	
	Namespace = JetAddressManager.Namespace();
	
	MapTypes = New Map;
	MapTypes.Insert(XDTOFactory.Type(Namespace, "Address"), Enums.ContactInformationTypes.Address);
	MapTypes.Insert(XDTOFactory.Type(Namespace, "Email"), Enums.ContactInformationTypes.Email);
	MapTypes.Insert(XDTOFactory.Type(Namespace, "Website"), Enums.ContactInformationTypes.WebPage);
	MapTypes.Insert(XDTOFactory.Type(Namespace, "PhoneNumber"), Enums.ContactInformationTypes.Phone);
	MapTypes.Insert(XDTOFactory.Type(Namespace, "FaxNumber"), Enums.ContactInformationTypes.Fax);
	MapTypes.Insert(XDTOFactory.Type(Namespace, "Skype"), Enums.ContactInformationTypes.Skype);
	MapTypes.Insert(XDTOFactory.Type(Namespace, "Other"), Enums.ContactInformationTypes.Other);
	
	Return MapTypes[TypeFound];
	
EndFunction

#EndRegion

#Region Private

// Returns a flag indicating whether a text is in XML format.
//
//  Parameters:
//      Text - String - a text being checked.
//
// Returns:
//      Boolean - the result of the check.
//
Function IsXMLString(Text)
	
	Return TypeOf(Text) = Type("String") AND Left(TrimL(Text),1) = "<";
	
EndFunction

Function IsAddressType(TypeValue)
	
	Return StrCompare(TypeValue, String(PredefinedValue("Enum.ContactInformationTypes.Address"))) = 0;
	
EndFunction

Function EventLogEvent()
	
	Return NStr("en = 'Contact information'; tr = 'İletişim bilgileri'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// Deserializer of types registered with the platform.
//
Function ValueFromXMLString(Val Text)
	
	XMLReader = New XMLReader;
	XMLReader.SetString(Text);
	
	Return XDTOSerializer.ReadXML(XMLReader);
	
EndFunction

// Generates and returns contact information presentation.
//
// Parameters:
//   Information - Structure, String - contact information in a JSON format or a structure with fields.
//   InfomationKind - CatalogRef.ContactsKinds, Structure - parameters for presentation generation.
//
// Returns:
//      String - a generated presentation.
//
Function GenerateContactInformationPresentation(Val Information, Val InformationKind)
	
	If TypeOf(Information) = Type("String") AND ContactsManagerClientServer.IsJSONContactInformation(Information) Then
		Information = JSONStringToStructure(Information);
	EndIf;
	
	If TypeOf(Information) = Type("Structure") Then
		
		If IsAddressType(Information.Type) Then
			Return AddressPresentation(Information, InformationKind);
			
		ElsIf Information.Type = String(Enums.ContactInformationTypes.Phone)
			OR Information.Type = String(Enums.ContactInformationTypes.Fax) Then
			PhonePresentation = PhonePresentation(Information);
			Return ?(IsBlankString(PhonePresentation), Information.Value, PhonePresentation);
		EndIf;
		
		Return Information.Value;
	EndIf;
	
	// Old format or a new deserialized format.
	Return GenerateContactInformationPresentation(ContactInformationToJSONStructure(Information), InformationKind);
	
EndFunction

Function XDTOContactsEmpty(Val Result)
	
	Composition = Result.Properties().Get("Content");
	If Composition <> Undefined Then
		Information = Result.Content.Properties().Get("Content");
		If Information <> Undefined Then
			If TypeOf(Result.Content.Content) = Type("String") Then
				Return IsBlankString(Result.Content.Content);
			ElsIf TypeOf(Result.Content.Content) = Type("XDTODataObject") Then
				For each XDTOField In Result.Content.Content.Properties() Do
					If XDTOField.Name = "AddlAddressItem" Or XDTOField.Name = "MunicipalEntityDistrictProperty" Then
						Continue;
					ElsIf ValueIsFilled(Result.Content.Content.Get(XDTOField.Name)) Then
						Return False;
					EndIf;
				EndDo;
			EndIf;
		Else
			ValueField = Result.Content.Properties().Get("Value");
			If ValueField <> Undefined Then
				Return IsBlankString(Result.Content.Get("Value"));
			EndIf;
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

Function PhoneFaxDeserialization(FieldsValues, Presentation = "", ExpectedType = Undefined)
	
	If ContactsManagerClientServer.IsXMLContactInformation(FieldsValues) Then
		// Common format of contact information.
		Return ContactsFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	Namespace = JetAddressManager.Namespace();
	
	If ExpectedType = Enums.ContactInformationTypes.Phone Then
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Fax Then
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "FaxNumber"));
		
	ElsIf ExpectedType = Undefined Then
		// This data is considered to be a phone number
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		
	Else
		Raise NStr("en = 'Contact information deserialization error. Phone or fax number is expected'; tr = 'İletişim bilgilerinin seriden paralele çevrilmesi sırasında bir hata oluştu, telefon veya faks numarası bekleniyor'");
	EndIf;
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content        = Data;
	
	// From key-value pairs
	FieldValueList = Undefined;
	If TypeOf(FieldsValues)=Type("ValueList") Then
		FieldValueList = FieldsValues;
	ElsIf Not IsBlankString(FieldsValues) Then
		FieldValueList = ContactsManagerInternal.ConvertStringToFieldsList(FieldsValues);
	EndIf;
	
	PresentationField = "";
	If FieldValueList <> Undefined Then
		For Each FieldValue In FieldValueList Do
			Field = Upper(FieldValue.Presentation);
			
			If Field = "COUNTRYCODE" Then
				Data.CountryCode = FieldValue.Value;
				
			ElsIf Field = "CITYCODE" Then
				Data.CityCode = FieldValue.Value;
				
			ElsIf Field = "PHONENUMBER" Then
				Data.Number = FieldValue.Value;
				
			ElsIf Field = "EXTENSION" Then
				Data.Extension = FieldValue.Value;
				
			ElsIf Field = "PRESENTATION" Then
				PresentationField = TrimAll(FieldValue.Value);
				
			EndIf;
			
		EndDo;
		
		// Presentation with priorities.
		If Not IsBlankString(Presentation) Then
			Result.Presentation = Presentation;
		ElsIf ValueIsFilled(PresentationField) Then
			Result.Presentation = PresentationField;
		Else
			Result.Presentation = PhonePresentation(Data);
		EndIf;
		
		Return Result;
	EndIf;
	
	// Parsing from the presentation.
	
	// Groups of numbers separated by non-digits: a country, a city, a number, and an extension.
	// Extension includes non-space characters on the left and on the right.
	Position = 1;
	Data.CountryCode = FindSubstringOfNumbers(Presentation, Position);
	CityBeginning    = Position;
	
	Data.CityCode = FindSubstringOfNumbers(Presentation, Position);
	Data.Number   = FindSubstringOfNumbers(Presentation, Position, " -");
	
	Extension = TrimAll(Mid(Presentation, Position));
	If StrStartsWith(Extension, ",") Then
		Extension = TrimL(Mid(Extension, 2));
	EndIf;
	If Upper(Left(Extension, 3 ))= "EXT" Then
		Extension = TrimL(Mid(Extension, 4));
	EndIf;
	If Upper(Left(Extension, 1 ))= "." Then
		Extension = TrimL(Mid(Extension, 2));
	EndIf;
	Data.Extension = TrimAll(Extension);
	
	// Fixing possible errors.
	If IsBlankString(Data.Number) Then
		If StrStartsWith(TrimL(Presentation), "+") Then
			// An attempt to specify the area code explicitly is detected. Leaving the area code "as is".
			Data.CityCode  = "";
			Data.Number      = ContactsManagerInternal.RemoveNonDigitCharacters(Mid(Presentation, CityBeginning));
			Data.Extension = "";
		Else
			Data.CountryCode  = "";
			Data.CityCode  = "";
			Data.Number      = Presentation;
			Data.Extension = "";
		EndIf;
	EndIf;
	
	Result.Presentation = Presentation;
	
	Return Result;
	
EndFunction

Function FindSubstringOfNumbers(Text, StartPosition = Undefined, AllowedBesidesNumbers = "")
	
	If StartPosition = Undefined Then
		StartPosition = 1;
	EndIf;
	
	Result = "";
	EndPosition = StrLen(Text);
	BeginningSearch  = True;
	
	While StartPosition <= EndPosition Do
		Char = Mid(Text, StartPosition, 1);
		IsDigit = Char >= "0" AND Char <= "9";
		
		If BeginningSearch Then
			If IsDigit Then
				Result = Result + Char;
				BeginningSearch = False;
			EndIf;
		Else
			If IsDigit Or StrFind(AllowedBesidesNumbers, Char) > 0 Then
				Result = Result + Char;    
			Else
				Break;
			EndIf;
		EndIf;
		
		StartPosition = StartPosition + 1;
	EndDo;
	
	// Discarding possible hanging separators on the right.
	Return ContactsManagerInternal.RemoveNonDigitCharacters(Result, AllowedBesidesNumbers, False);
	
EndFunction

Function PhonePresentation(PhoneData)
	
	If TypeOf(PhoneData) = Type("Structure") Then
		
		PhonePresentation = ContactsManagerClientServer.GeneratePhonePresentation(
			ContactsManagerInternal.RemoveNonDigitCharacters(PhoneData.countryCode),
			PhoneData.areaCode,
			PhoneData.number,
			PhoneData.extNumber,
			"");
		
	Else
		
		PhonePresentation = ContactsManagerClientServer.GeneratePhonePresentation(
			ContactsManagerInternal.RemoveNonDigitCharacters(PhoneData.CountryCode), 
			PhoneData.CityCode,
			PhoneData.Number,
			PhoneData.Extension,
			"");
		
	EndIf;
	
	Return PhonePresentation;
	
EndFunction

// Generates an address presentation according to the rule:
//  1) Country, if necessary.
//  2) Postal code, territorial entity, county, district, city, city district, locality, and street.
//  3) Buildings, premises.
//
// Parameters:
//  Address			 - Structure - an address broken down by fields.
//  ContactsKind	 - Structure - details of a contacts kind.
// 
// Returns:
//  String - an address presentation.
//
Function AddressPresentation(Val Address, Val InformationKind)
	
	If TypeOf(InformationKind) = Type("Structure") AND InformationKind.Property("IncludeCountryInPresentation") Then
		IncludeCountryInPresentation = InformationKind.IncludeCountryInPresentation;
	Else
		IncludeCountryInPresentation = False;
	EndIf;
	
	If TypeOf(Address) = Type("Structure") Then
		
		If Metadata.CommonModules.Find("AddressManagerClientServer") <> Undefined Then
			ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
			ModuleAddressManagerClientServer.UpdateAddressPresentation(Address, IncludeCountryInPresentation);
		Else
			JetAddressManagerClientServer.UpdateAddressPresentation(Address, IncludeCountryInPresentation);
		EndIf;
		
		Return Address.Value;
	Else
		// This is a foreign address
		Presentation = TrimAll(Address);
		
		If StrOccurrenceCount(Presentation, ",") = 9 Then
			// Deleting empty values and a country.
			PresentationAsArray = StrSplit(Presentation, ",", False);
			If PresentationAsArray.Count() > 0 Then
				For Index = 0 To PresentationAsArray.UBound() Do
					PresentationAsArray[Index] = TrimAll(PresentationAsArray[Index]);
				EndDo;
				PresentationAsArray.Delete(0); // Deleting a country
				Presentation = StrConcat(PresentationAsArray, ", ");
			EndIf;
		EndIf;
	EndIf;
	
	Return Presentation;
	
EndFunction

// Converts a string into other XDTO contact information.
//
// Parameters:
//   FieldsValues - String - serialized information, field values.
//   Presentation - String - superiority-based presentation. Used for parsing purposes if FieldsValues is empty.
//   ExpectedType - EnumRef.ContactsType - an optional type for control.
//
// Returns:
//   XDTOObject - contact information.
//
Function OtherContactInformationDeserialization(FieldsValues, Presentation = "", ExpectedType = Undefined)
	
	If ContactsManagerClientServer.IsXMLContactInformation(FieldsValues) Then
		// Common format of contact information.
		Return ContactsFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	Namespace = JetAddressManager.Namespace();
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Presentation = Presentation;
	
	If ExpectedType = Enums.ContactInformationTypes.Email Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Email"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Website"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Skype Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Skype"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Other"));
		
	ElsIf ExpectedType <> Undefined Then
		Raise NStr("en = 'Contact information deserialization error. Another type is expected.'; tr = 'İletişim bilgilerinin seriden paralele çevrilmesi sırasında bir hata oluştu, diğer tür bekleniyor'");
		
	EndIf;
	
	Result.Content.Value = Presentation;
	
	Return Result;
	
EndFunction

// Internal, for serialization purposes.
Function ConvertAddressFromJSONToXML(Val FieldsValues, Val Presentation, Val ExpectedType = Undefined)
	
	Return JetAddressManager.ConvertAddressFromJSONToXML(FieldsValues, Presentation, ExpectedType);
	
	// Old format with line separator and equality.
	Namespace = JetAddressManager.Namespace();
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
	
	// Common composition
	Address = Result.Content;
	
	PresentationField = "";
	
	For Each ListItem In FieldsValues Do
		
		If IsBlankString(ListItem.Value) Then
			Continue;
		EndIf;
		
		FieldName = Upper(ListItem.Key);
		
		If FieldName = "COMMENT" Then
			Comment = TrimAll(ListItem.Value);
			If ValueIsFilled(Comment) Then
				Result.Comment = Comment;
			EndIf;
			
		ElsIf FieldName = "COUNTRY" Then
			Address.Country = String(ListItem.Value);
			
		ElsIf FieldName = "VALUE" Then
			PresentationField = TrimAll(ListItem.Value);
			
		EndIf;
		
	EndDo;
	
	// Presentation with priorities.
	If Not IsBlankString(Presentation) Then
		Result.Presentation = Presentation;
	Else
		Result.Presentation = PresentationField;
	EndIf;
	
	Address.Content = Result.Presentation;
	
	Return Result;
	
EndFunction

Function ConvertPhoneFaxFromJSONToXML(FieldsValues, Presentation = "", ExpectedType = Undefined)
	
	If ContactsManagerClientServer.IsXMLContactInformation(FieldsValues) Then
		// Common format of contact information.
		Return ContactsFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	Namespace = JetAddressManager.Namespace();
	
	If ExpectedType = Enums.ContactInformationTypes.Phone Then
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Fax Then
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "FaxNumber"));
		
	ElsIf ExpectedType = Undefined Then
		// This data is considered to be a phone number
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		
	Else
		Raise NStr("en = 'An error occurred when converting contact information. Phone or fax number is expected'; tr = 'İletişim bilgilerinin dönüştürme sırasında bir hata oluştu, telefon veya faks numarası bekleniyor'");
	EndIf;
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content        = Data;
	
	PresentationField = "";
	For Each FieldValue In FieldsValues Do
		Field = Upper(FieldValue.Key);
		
		If Field = "COUNTRYCODE" Then
			Data.CountryCode = FieldValue.Value;
			
		ElsIf Field = "AREACODE" Then
			Data.CityCode = FieldValue.Value;
			
		ElsIf Field = "NUMBER" Then
			Data.Number = FieldValue.Value;
			
		ElsIf Field = "EXTNUMBER" Then
			Data.Extension = FieldValue.Value;
			
		ElsIf Field = "VALUE" Then
			PresentationField = TrimAll(FieldValue.Value);
			
		ElsIf Field = "COMMENT" Then
			Comment = TrimAll(FieldValue.Value);
			If ValueIsFilled(Comment) Then
				Result.Comment = Comment;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Presentation with priorities.
	If Not IsBlankString(Presentation) Then
		Result.Presentation = Presentation;
	ElsIf ValueIsFilled(PresentationField) Then
		Result.Presentation = PresentationField;
	Else
		Result.Presentation = PhonePresentation(Data);
	EndIf;
	
	Return Result;
	
EndFunction

// Converts a string into other XDTO contact information.
//
// Parameters:
//   FieldsValues - String - serialized information, field values.
//   Presentation - String - superiority-based presentation. Used for parsing purposes if FieldsValues is empty.
//   ExpectedType - EnumRef.ContactsType - an optional type for control.
//
// Returns:
//   XDTOObject - contact information.
//
Function ConvertOtherContactsFromJSONToXML(FieldsValues, Val Presentation = "", ExpectedType = Undefined)
	
	If ContactsManagerClientServer.IsXMLContactInformation(FieldsValues) Then
		// Common format of contact information.
		Return ContactsFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	Namespace = JetAddressManager.Namespace();
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	
	If IsBlankString(Presentation) AND FieldsValues.Property("Value") AND ValueIsFilled(FieldsValues.Value) Then
		Presentation = FieldsValues.Value;
	EndIf;
	
	Result.Presentation = Presentation;
	
	If ExpectedType = Enums.ContactInformationTypes.Email Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Email"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Website"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Skype Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Skype"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Other"));
		
	ElsIf ExpectedType <> Undefined Then
		Raise NStr("en = 'Contact information deserialization error. Another type is expected.'; tr = 'İletişim bilgilerinin seriden paralele çevrilmesi sırasında bir hata oluştu, diğer tür bekleniyor'");
		
	EndIf;
	
	Result.Content.Value = Presentation;
	
	Comment = "";
	If FieldsValues.Property("Comment") AND ValueIsFilled(FieldsValues.Comment) Then
		Comment = TrimAll(FieldsValues.Comment);
		If ValueIsFilled(Comment) Then
			Result.Comment = Comment;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Converts a text with the Key = Value pair separated by line breaks (see the address format) into XML.
// If duplicate keys are encountered, all of them are included in the output but only the last one 
// is used during deserialization due to platform serialization logic.
//
// Parameters:
//    Text - String - Key = Value pairs.
//
// Returns:
//     String - serialized structure XML.
//
Function XSLT_KeyValueStringToStructure(Val Text) 
	
	Converter = XSLTransform_KeyValueStringToStructure();
	Return Converter.TransformFromString(XSLT_ParameterStringNode(Text));
	
EndFunction

// Converts a value list into structure. Transforms a presentation to the key.
//
// Parameters:
//    Text - String - a serialized value list.
//
// Returns:
//    String - a conversion result.
//
Function XSLT_ValueListToStructure(Text)
	
	Converter = XSLTransform_ValueListToStructure();
	Return Converter.TransformFromString(Text);
	
EndFunction

// Converts mapping to structure. Converts a key to key, a value to value.
//
// Parameters:
//    Text - String - serialized mapping.
//
// Returns:
//    String - a conversion result.
//
Function XSLT_MapToStructure(Text)
	
	Converter = XSLTransform_MapToStructure();
	Return Converter.TransformFromString(Text);
	
EndFunction

// Converts a structure to contact information XML.
//
// Parameters:
//    Text - String - a serialized structure.
//    Presentation - String - an optional presentation. Used only if there is no presentation field 
//                             in the structure.
//    Comment - String - an optional comment. Used only if there is no comment field in the structure.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_StructureToAddress(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	Converter = XSLTransform_XSLTransform();
	
	Return XSLT_PresentationAndCommentControl(Converter.TransformFromString(Text), Presentation, Comment);
	
EndFunction

// Converts a structure to contact information XML.
//
// Parameters:
//    Text - String - a serialized structure.
//    Presentation - String - an optional presentation. Used only if there is no presentation field 
//                             in the structure.
//    Comment - String - an optional comment. Used only if there is no comment field in the structure.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_StructureToEmailAddress(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	Converter = XSLTransform_StructureToEmailAddress();
	
	Return XSLT_PresentationAndCommentControl(
		XSLT_SimpleTypeStringValueControl(Converter.TransformFromString(Text), Presentation),
		Presentation,
		Comment);
	
EndFunction

// Converts a structure to contact information XML.
//
// Parameters:
//    Text - String - a serialized structure.
//    Presentation - String - an optional presentation. Used only if there is no presentation field 
//                             in the structure.
//    Comment - String - an optional comment. Used only if there is no comment field in the structure.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_StructureToWebPage(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	Converter = XSLTransform_StructureToWebPage();
	
	Return XSLT_PresentationAndCommentControl(
		XSLT_SimpleTypeStringValueControl( Converter.TransformFromString(Text), Presentation),
		Presentation,
		Comment);
	
EndFunction

// Converts a structure to contact information XML.
//
// Parameters:
//    Text - String - a serialized structure.
//    Presentation - String - an optional presentation. Used only if there is no presentation field 
//                             in the structure.
//    Comment - String - an optional comment. Used only if there is no comment field in the structure.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_StructureToPhone(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	Converter = XSLTransform_StructureToPhone();
	
	Return XSLT_PresentationAndCommentControl(
		Converter.TransformFromString(Text),
		Presentation,
		Comment);
	
EndFunction

// Converts a structure to contact information XML.
//
// Parameters:
//    Text - String - a serialized structure.
//    Presentation - String - an optional presentation. Used only if there is no presentation field 
//                             in the structure.
//    Comment - String - an optional comment. Used only if there is no comment field in the structure.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_StructureToFax(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	Converter = XSLTransform_StructureToFax();
	
	Return XSLT_PresentationAndCommentControl(
		Converter.TransformFromString(Text),
		Presentation,
		Comment);
	
EndFunction

// Converts a structure to contact information XML.
//
// Parameters:
//    Text - String - a serialized structure.
//    Presentation - String - an optional presentation. Used only if there is no presentation field 
//                             in the structure.
//    Comment - String - an optional comment. Used only if there is no comment field in the structure.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_StructureToOther(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	Converter = XSLTransform_StructureToOther();
	
	Return XSLT_PresentationAndCommentControl(
		XSLT_SimpleTypeStringValueControl(Converter.TransformFromString(Text), Presentation),
		Presentation,
		Comment);
	
EndFunction

// Sets a presentation and a comment in contact information if they are not filled in.
//
// Parameters:
//    Text - String - a serialized structure.
//    Presentation - String - an optional presentation. Used only if there is no presentation field 
//                             in the structure.
//    Comment - String - an optional comment. Used only if there is no comment field in the structure.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_PresentationAndCommentControl(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	If Presentation = Undefined AND Comment = Undefined Then
		Return Text;
	EndIf;
	
	XSLT_Text = New TextDocument;
	XSLT_Text.AddLine("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:tns=""http://www.v8.1c.ru/ssl/contactinfo""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|>
		|  <xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|
		|  <xsl:template match=""node() | @*"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" />
		|    </xsl:copy>
		|  </xsl:template>
		|");
		
	If Presentation <> Undefined Then
		XSLT_Text.AddLine("
		|  <xsl:template match=""tns:ContactInformation/@Presentation"">
		|    <xsl:attribute name=""Presentation"">
		|      <xsl:choose>
		|        <xsl:when test="".=''"">" + NormalizedStringXML(Presentation) + "</xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select="".""/>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:attribute>
		|  </xsl:template>
		|");
	EndIf;
	
	If Comment <> Undefined Then
		XSLT_Text.AddLine("
		|  <xsl:template match=""tns:ContactInformation/tns:Comment"">
		|    <xsl:element name=""Comment"">
		|      <xsl:choose>
		|        <xsl:when test="".=''"">" + NormalizedStringXML(Comment) + "</xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select="".""/>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:element>
		|  </xsl:template>
		|");
	EndIf;
		XSLT_Text.AddLine("
		|</xsl:stylesheet>
		|");
		
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString(XSLT_Text.GetText());
	
	Return Converter.TransformFromString(Text);
	
EndFunction

// Sets Composition.Value in contact information to the passed presentation.
// If Presentation is undefined, no action is performed. Otherwise, checks whether it is empty.
// Composition. If it is empty and the Composition.Value attribute is empty, insert a presentation value into the composition.
//
// Parameters:
//    Text - String - contact information XML.
//    Presentation - String - a presentation to be set.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_SimpleTypeStringValueControl(Val Text, Val Presentation)
	
	If Presentation = Undefined Then
		Return Text;
	EndIf;
	
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:tns=""http://www.v8.1c.ru/ssl/contactinfo""
		|>
		|  <xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  
		|  <xsl:template match=""node() | @*"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" />
		|    </xsl:copy>
		|  </xsl:template>
		|  
		|  <xsl:template match=""tns:ContactInformation/tns:Content/@Value"">
		|    <xsl:attribute name=""Value"">
		|      <xsl:choose>
		|        <xsl:when test="".=''"">" + NormalizedStringXML(Presentation) + "</xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select="".""/>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:attribute>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	
	Return Converter.TransformFromString(Text);
	
EndFunction

// Returns an XML fragment to be inserted to an XML string, in <Node>String<Node> format.
//
// Parameters:
//    Text - String - inserting to XML.
//    ItemName - String - an external node name (optional).
//
// Returns:
//    String - a resulting XML.
//
Function XSLT_ParameterStringNode(Val Text, Val ItemName = "ExternalParamNode")
	
	// Writing an XML to mask special characters.
	Record = New XMLWriter;
	Record.SetString();
	Record.WriteStartElement(ItemName);
	Record.WriteText(Text);
	Record.WriteEndElement();
	
	Return Record.Close();
	
EndFunction

// Converts an XML text of contact information to the type enumeration.
//
// Parameters:
//    Text - String - a source XML string.
//
// Returns:
//    String - a serialized value of the ContactsTypes enumeration.
//
Function XSLT_ContactInformationTypeByXMLString(Val Text)
	
	Converter = XSLTransformation_ContactInformationTypeByXMLString();
	Return Converter.TransformFromString(TrimL(Text));
	
EndFunction

// Converts an XML string containing contact information (see the ContactInformation XDTO package) into enumeration
// ContactInformationType.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransformation_ContactInformationTypeByXMLString()
	
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:ci=""http://www.v8.1c.ru/ssl/contactinfo""
		|>
		|  <xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|
		|  <xsl:template match=""/"">
		|    <EnumRef.ContactInformationTypes xmlns=""http://v8.1c.ru/8.1/data/enterprise/current-config"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""EnumRef.ContactInformationTypes"">
		|      <xsl:call-template name=""enum-by-type"" >
		|        <xsl:with-param name=""type"" select=""ci:ContactInformation/ci:Content/@xsi:type"" />
		|      </xsl:call-template>
		|    </EnumRef.ContactInformationTypes>
		|  </xsl:template>
		|
		|  <xsl:template name=""enum-by-type"">
		|    <xsl:param name=""type"" />
		|    <xsl:choose>
		|      <xsl:when test=""$type='Address'"">
		|        <xsl:text>Address</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='PhoneNumber'"">
		|        <xsl:text>Phone</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='FaxNumber'"">
		|        <xsl:text>Fax</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='Email'"">
		|        <xsl:text>Email</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='Website'"">
		|        <xsl:text>WebPage</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='Other'"">
		|        <xsl:text>Other</xsl:text>
		|      </xsl:when>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	
	Return Converter;
	
EndFunction

// Serializer of types registered with the platform.
Function ValueToXMLString(Val Value)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString(New XMLWriterSettings(, , False, False, ""));
	XDTOSerializer.WriteXML(XMLWriter, Value, XMLTypeAssignment.Explicit);
	// Platform serializer allows writing line breaks to attribute values.
	Return StrReplace(XMLWriter.Close(), Chars.LF, "&#10;");
	
EndFunction

// Intended for processing attributes containing line breaks.
//
// Parameters:
//     Text - String - an XML string to be modified.
//
// Returns:
//     String - a normalized string.
//
Function MultilineXMLString(Val Text)
	
	Return StrReplace(Text, Chars.LF, "&#10;");
	
EndFunction

// Prepares a string to include in the XML text, removing the special characters.
//
// Parameters:
//     Text - String - an XML string to be modified.
//
// Returns:
//     String - a normalized string.
//
Function NormalizedStringXML(Val Text)
	
	Result = StrReplace(Text, """", "&quot;");
	Result = StrReplace(Result, "&",  "&amp;");
	Result = StrReplace(Result, "'",  "&apos;");
	Result = StrReplace(Result, "<",  "&lt;");
	Result = StrReplace(Result, ">",  "&gt;");
	
	Return MultilineXMLString(Result);
	
EndFunction

// Converts a serialized structure into contact information in XML format.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_StructureToOther()
	
	Return XSLTransform_StructureToStringComposition("Other");
	
EndFunction

// Converts an XML difference table depending on the contact information type.
//
// Parameters:
//    ContactInformationType - EnumRef.ContactInformationTypes - the enumeration name or value.
//
// Returns:
//     XSLTransform - a prepared object.
//
// Returns an XSL converter to convert a structure to XML contact information. 
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_XSLTransform()
	
	If Metadata.CommonModules.Find("AddressManager") <> Undefined Then
		ModuleAddressManager = Common.CommonModule("AddressManager");
		AdditionalConversionRules = ModuleAddressManager.AdditionalConversionRules();
	EndIf;
	
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:xs=""http://www.w3.org/2001/XMLSchema""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|
		|  xmlns:data=""http://www.v8.1c.ru/ssl/contactinfo""
		|
		|  xmlns:exsl=""http://exslt.org/common""
		|  extension-element-prefixes=""exsl""
		|  exclude-result-prefixes=""data tns""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  " + XSLT_StringFunctionTemplates() + "
		|  
		|  <xsl:variable name=""local-country"">RUSSIA</xsl:variable>
		|
		|  <xsl:variable name=""presentation"" select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()"" />
		|  
		|  <xsl:template match=""/"">
		|    <ContactInformation>
		|
		|      <xsl:attribute name=""Presentation"">
		|        <xsl:value-of select=""$presentation""/>
		|      </xsl:attribute> 
		|      <xsl:element name=""Comment"">
		|       <xsl:value-of select=""tns:Structure/tns:Property[@name='Comment']/tns:Value/text()""/>
		|      </xsl:element>
		|
		|      <xsl:element name=""Content"">
		|        <xsl:attribute name=""xsi:type"">Address</xsl:attribute>
		|        <xsl:variable name=""country"" select=""tns:Structure/tns:Property[@name='Country']/tns:Value/text()""></xsl:variable>
		|        <xsl:variable name=""country-upper"">
		|          <xsl:call-template name=""str-upper"">
		|            <xsl:with-param name=""str"" select=""$country"" />
		|          </xsl:call-template>
		|        </xsl:variable>
		|
		|        <xsl:attribute name=""Country"">
		|          <xsl:choose>
		|            <xsl:when test=""0=count($country)"">
		|              <xsl:value-of select=""$local-country"" />
		|            </xsl:when>
		|            <xsl:otherwise>
		|              <xsl:value-of select=""$country"" />
		|            </xsl:otherwise> 
		|          </xsl:choose>
		|        </xsl:attribute>
		|
		|        <xsl:choose>
		|          <xsl:when test=""0=count($country)"">
		|            <xsl:apply-templates select=""/"" mode=""domestic"" />
		|          </xsl:when>
		|          <xsl:when test=""$country-upper=$local-country"">
		|            <xsl:apply-templates select=""/"" mode=""domestic"" />
		|          </xsl:when>
		|          <xsl:otherwise>
		|            <xsl:apply-templates select=""/"" mode=""foreign"" />
		|          </xsl:otherwise> 
		|        </xsl:choose>
		|
		|      </xsl:element>
		|    </ContactInformation>
		|  </xsl:template>
		|  
		|  <xsl:template match=""/"" mode=""foreign"">
		|    <xsl:element name=""Content"">
		|      <xsl:attribute name=""xsi:type"">xs:string</xsl:attribute>
		|
		|      <xsl:variable name=""value"" select=""tns:Structure/tns:Property[@name='Value']/tns:Value/text()"" />        
		|      <xsl:choose>
		|        <xsl:when test=""0=count($value)"">
		|          <xsl:value-of select=""$presentation"" />
		|        </xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select=""$value"" />
		|        </xsl:otherwise> 
		|      </xsl:choose>
		|    
		|    </xsl:element>
		|  </xsl:template>
		|" + AdditionalConversionRules);
	
	Return Converter;
	
EndFunction

// Converts a serialized structure into contact information in XML format.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_StructureToEmailAddress()
	
	Return XSLTransform_StructureToStringComposition("Email");
	
EndFunction

// Converts a serialized structure into contact information in XML format.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_StructureToWebPage()
	
	Return XSLTransform_StructureToStringComposition("Website");
	
EndFunction

// Converts a serialized structure into contact information in XML format.
//
Function XSLTransform_StructureToPhone()
	
	Return XSLTransform_StructureToPhoneFax("PhoneNumber");
	
EndFunction

// Converts a serialized structure into contact information in XML format.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_StructureToFax()
	
	Return XSLTransform_StructureToPhoneFax("FaxNumber");
	
EndFunction

// General conversion of a serialized structure into contact information in XML format of a simple type.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_StructureToStringComposition(Val XDTOTypeName)
	
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|
		|<xsl:template match=""/"">
		|  
		|  <xsl:element name=""ContactInformation"">
		|  
		|  <xsl:attribute name=""Presentation"">
		|    <xsl:value-of select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()""/>
		|  </xsl:attribute> 
		|  <xsl:element name=""Comment"">
		|    <xsl:value-of select=""tns:Structure/tns:Property[@name='Comment']/tns:Value/text()""/>
		|  </xsl:element>
		|  
		|  <xsl:element name=""Content"">
		|    <xsl:attribute name=""xsi:type"">" + XDTOTypeName + "</xsl:attribute>
		|    <xsl:attribute name=""Value"">
		|    <xsl:choose>
		|      <xsl:when test=""0=count(tns:Structure/tns:Property[@name='Value'])"">
		|      <xsl:value-of select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()""/>
		|      </xsl:when>
		|      <xsl:otherwise>
		|      <xsl:value-of select=""tns:Structure/tns:Property[@name='Value']/tns:Value/text()""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|    </xsl:attribute>
		|    
		|  </xsl:element>
		|  </xsl:element>
		|  
		|</xsl:template>
		|</xsl:stylesheet>
		|");
	
	Return Converter;
	
EndFunction

// General conversion for a phone and a fax.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_StructureToPhoneFax(Val XDTOTypeName)
	
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  <xsl:template match=""/"">
		|
		|    <xsl:element name=""ContactInformation"">
		|
		|      <xsl:attribute name=""Presentation"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()""/>
		|      </xsl:attribute> 
		|      <xsl:element name=""Comment"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='Comment']/tns:Value/text()""/>
		|      </xsl:element>
		|      <xsl:element name=""Content"">
		|        <xsl:attribute name=""xsi:type"">" + XDTOTypeName + "</xsl:attribute>
		|
		|        <xsl:attribute name=""CountryCode"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='CountryCode']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|        <xsl:attribute name=""CityCode"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='CityCode']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|        <xsl:attribute name=""Number"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='PhoneNumber']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|        <xsl:attribute name=""Extension"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='Extension']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|
		|      </xsl:element>
		|    </xsl:element>
		|
		|  </xsl:template>
		|</xsl:stylesheet>
		|");
	
	Return Converter;
	
EndFunction

// XSL fragment including string processing procedures.
//
// Returns:
//     String - an XML fragment to be used in the conversion.
//
Function XSLT_StringFunctionTemplates()
	
	Return "
		|<!-- string functions -->
		|
		|  <xsl:template name=""str-trim-left"">
		|    <xsl:param name=""str"" />
		|    <xsl:variable name=""head"" select=""substring($str, 1, 1)""/>
		|    <xsl:variable name=""tail"" select=""substring($str, 2)""/>
		|    <xsl:choose>
		|      <xsl:when test=""(string-length($str) > 0) and (string-length(normalize-space($head)) = 0)"">
		|        <xsl:call-template name=""str-trim-left"">
		|          <xsl:with-param name=""str"" select=""$tail""/>
		|        </xsl:call-template>
		|      </xsl:when>
		|      <xsl:otherwise>
		|        <xsl:value-of select=""$str""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-trim-right"">
		|    <xsl:param name=""str"" />
		|    <xsl:variable name=""head"" select=""substring($str, 1, string-length($str) - 1)""/>
		|    <xsl:variable name=""tail"" select=""substring($str, string-length($str))""/>
		|    <xsl:choose>
		|      <xsl:when test=""(string-length($str) > 0) and (string-length(normalize-space($tail)) = 0)"">
		|        <xsl:call-template name=""str-trim-right"">
		|          <xsl:with-param name=""str"" select=""$head""/>
		|        </xsl:call-template>
		|      </xsl:when>
		|      <xsl:otherwise>
		|        <xsl:value-of select=""$str""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-trim-all"">
		|    <xsl:param name=""str"" />
		|      <xsl:call-template name=""str-trim-right"">
		|        <xsl:with-param name=""str"">
		|          <xsl:call-template name=""str-trim-left"">
		|            <xsl:with-param name=""str"" select=""$str""/>
		|          </xsl:call-template>
		|      </xsl:with-param>
		|    </xsl:call-template>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-replace-all"">
		|    <xsl:param name=""str"" />
		|    <xsl:param name=""search-for"" />
		|    <xsl:param name=""replace-by"" />
		|    <xsl:choose>
		|      <xsl:when test=""contains($str, $search-for)"">
		|        <xsl:value-of select=""substring-before($str, $search-for)"" />
		|        <xsl:value-of select=""$replace-by"" />
		|        <xsl:call-template name=""str-replace-all"">
		|          <xsl:with-param name=""str"" select=""substring-after($str, $search-for)"" />
		|          <xsl:with-param name=""search-for"" select=""$search-for"" />
		|          <xsl:with-param name=""replace-by"" select=""$replace-by"" />
		|        </xsl:call-template>
		|      </xsl:when>
		|      <xsl:otherwise>
		|        <xsl:value-of select=""$str"" />
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:param name=""alpha-low"" select=""'abcdefghijklmnopqrstuvwxyz'"" />
		|  <xsl:param name=""alpha-up""  select=""'ABCDEFGHIJKLMNOPQRSTUVWXYZ'"" />
		|
		|  <xsl:template name=""str-upper"">
		|    <xsl:param name=""str"" />
		|    <xsl:value-of select=""translate($str, $alpha-low, $alpha-up)""/>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-lower"">
		|    <xsl:param name=""str"" />
		|    <xsl:value-of select=""translate($str, alpha-up, $alpha-low)"" />
		|  </xsl:template>
		|
		|<!-- /string functions -->
		|";
	
EndFunction

// Converts a text with the Key = Value pairs separated by line breaks (see the address format) to XML.
// If duplicate keys are encountered, all of them are included in the output but only the last one 
// is used during deserialization due to platform serialization logic.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_KeyValueStringToStructure()
	
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0""
		|  xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:str=""http://exslt.org/strings""
		|  extension-element-prefixes=""str""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|
		|  <xsl:template match=""ExternalParamNode"">
		|
		|    <xsl:variable name=""source"">
		|      <xsl:call-template name=""str-replace-all"">
		|        <xsl:with-param name=""str"" select=""."" />
		|        <xsl:with-param name=""search-for"" select=""'&#10;&#09;'"" />
		|        <xsl:with-param name=""replace-by"" select=""'&#13;'"" />
		|      </xsl:call-template>
		|    </xsl:variable>
		|
		|    <Structure xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""Structure"">
		|
		|     <xsl:for-each select=""str:tokenize($source, '&#10;')"" >
		|       <xsl:if test=""contains(., '=')"">
		|
		|         <xsl:element name=""Property"">
		|           <xsl:attribute name=""name"" >
		|             <xsl:call-template name=""str-trim-all"">
		|               <xsl:with-param name=""str"" select=""substring-before(., '=')"" />
		|             </xsl:call-template>
		|           </xsl:attribute>
		|
		|           <Value xsi:type=""xs:string"">
		|             <xsl:call-template name=""str-replace-all"">
		|               <xsl:with-param name=""str"" select=""substring-after(., '=')"" />
		|               <xsl:with-param name=""search-for"" select=""'&#13;'"" />
		|               <xsl:with-param name=""replace-by"" select=""'&#10;'"" />
		|             </xsl:call-template>
		|           </Value>
		|
		|         </xsl:element>
		|
		|       </xsl:if>
		|     </xsl:for-each>
		|
		|    </Structure>
		|
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	
	Return Converter;
	
EndFunction

// Conversion for a value list into the structure. Transforms a presentation to the key.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_ValueListToStructure()
	
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://v8.1c.ru/8.1/data/core""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|
		|  <xsl:template match=""/"">
		|    <Structure xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""Structure"">
		|      <xsl:apply-templates select=""//tns:ValueListType/tns:item"" />
		|    </Structure >
		|  </xsl:template>
		|
		|  <xsl:template match=""//tns:ValueListType/tns:item"">
		|    <xsl:element name=""Property"">
		|      <xsl:attribute name=""name"">
		|        <xsl:call-template name=""str-trim-all"">
		|          <xsl:with-param name=""str"" select=""tns:presentation"" />
		|        </xsl:call-template>
		|      </xsl:attribute>
		|
		|      <xsl:element name=""Value"">
		|        <xsl:attribute name=""xsi:type"">
		|          <xsl:value-of select=""tns:value/@xsi:type""/>  
		|        </xsl:attribute>
		|        <xsl:value-of select=""tns:value""/>  
		|      </xsl:element>
		|
		|    </xsl:element>
		|</xsl:template>
		|
		|</xsl:stylesheet>
		|");
	
	Return Converter;
	
EndFunction

// Conversion of a mapping into the structure. Converts a key to key, a value to value.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_MapToStructure()
	
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://v8.1c.ru/8.1/data/core""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|
		|  <xsl:template match=""/"">
		|    <Structure xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""Structure"">
		|      <xsl:apply-templates select=""//tns:Map/tns:pair"" />
		|    </Structure >
		|  </xsl:template>
		|  
		|  <xsl:template match=""//tns:Map/tns:pair"">
		|  <xsl:element name=""Property"">
		|    <xsl:attribute name=""name"">
		|      <xsl:call-template name=""str-trim-all"">
		|        <xsl:with-param name=""str"" select=""tns:Key"" />
		|      </xsl:call-template>
		|    </xsl:attribute>
		|  
		|    <xsl:element name=""Value"">
		|      <xsl:attribute name=""xsi:type"">
		|        <xsl:value-of select=""tns:Value/@xsi:type""/>  
		|      </xsl:attribute>
		|        <xsl:value-of select=""tns:Value""/>  
		|      </xsl:element>
		|  
		|    </xsl:element>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	
	Return Converter;
	
EndFunction

#EndRegion