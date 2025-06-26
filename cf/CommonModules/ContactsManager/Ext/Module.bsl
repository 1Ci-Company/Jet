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

////////////////////////////////////////////////////////////////////////////////
// Add, change, and get contact information.

// Returns a table containing contact information for multiple objects. 
//
// Parameters:
//    Source         - Array - contact information owners.
//    Filter - See FilterContactInformation3.
//
// Returns:
//  ValueTable:
//   * Object           - AnyRef - a contact information owner.
//   * Kind              - CatalogRef.ContactInformationKinds - a contact information kind.
//   * Type              - EnumRef.ContactInformationTypes - contact information type.
//   * Value         - String - contact information in the internal JSON format.
//   * Presentation    - String - a contact information presentation.
//   * Date             - Date   - a date, from which contact information record is valid.
//   * TabularSectionRowID - Number - row ID of this tabular section
//   * FieldValues    - String - an obsolete XML file matching the ContactInformation or Address XDTO packages. For
//                                 backward compatibility.
//
Function ContactInformation(Source, Filter) Export
	
	ContactInformationObjects = New Array; // Array of CatalogObject
	ContactInformationLinks  = New Array;
	
	If TypeOf(Source) = Type("Array") Then
		ReferencesOrObjects = Source;
	Else
		ReferencesOrObjects = CommonClientServer.ValueInArray(Source);
	EndIf;
	
	For Each ReferenceOrObject In ReferencesOrObjects Do
		
		If Common.IsReference(TypeOf(ReferenceOrObject)) Then
			ContactInformationLinks.Add(ReferenceOrObject);
		Else
			ContactInformationObjects.Add(ReferenceOrObject);
		EndIf;
		
	EndDo;
	
	Date = Filter.Date;
	
	ContactInformationTypes = Undefined;
	If ValueIsFilled(Filter.ContactInformationTypes) Then
		ContactInformationTypes = Filter.ContactInformationTypes;
		
		If TypeOf(ContactInformationTypes) = Type("EnumRef.ContactInformationTypes") Then
			ContactInformationTypes = CommonClientServer.ValueInArray(ContactInformationTypes);
		EndIf;
	EndIf;
	
	ContactInformationKinds = Undefined;
	If ValueIsFilled(Filter.ContactInformationKinds) Then
		ContactInformationKinds = Filter.ContactInformationKinds;
		
		If TypeOf(ContactInformationKinds) = Type("CatalogRef.ContactInformationKinds") Then
			ContactInformationKinds = CommonClientServer.ValueInArray(ContactInformationKinds);
		EndIf;
	EndIf;
	
	Result = NewContactInformation(True);
	
	If ContactInformationLinks.Count() > 0 Then
		
		Query = New Query;
		Query.TempTablesManager = New TempTablesManager;
		
		CreateContactInformationTemporaryTable(Query.TempTablesManager, ContactInformationLinks, ContactInformationTypes, ContactInformationKinds, Date);
		
		ValidFrom = ?(TypeOf(Date) = Type("Date"), "ContactInformation.ValidFrom", "DATETIME(1, 1, 1, 0, 0, 0)");
		
		Query.Text =
		"SELECT
		|	ContactInformation.Object AS Object,
		|	ContactInformation.Kind AS Kind,
		|	ContactInformation.Type AS Type,
		|	ContactInformation.Value AS Value,
		|	ContactInformation.FieldValues AS FieldValues,
		|	ContactInformation.LineNumber AS LineNumber,
		|	ContactInformation.TabularSectionRowID AS TabularSectionRowID,
		|	&ValidFrom AS Date,
		|	ContactInformation.Presentation AS Presentation
		|FROM
		|	TTContactInformation AS ContactInformation
		|
		|ORDER BY
		|	LineNumber";
		
		Query.Text = StrReplace(Query.Text, "&ValidFrom", ValidFrom);
		
		ResultLink = Query.Execute().Unload();
		
		For Each ContactInformationRow In ResultLink Do
			
			NewRow = Result.Add();
			FillPropertyValues(NewRow, ContactInformationRow);
			
			If IsBlankString(NewRow.Value)
				And ValueIsFilled(NewRow.FieldValues) Then
				NewRow.Value = ContactInformationInJSON(NewRow.FieldValues, NewRow.Type);
			EndIf;
		EndDo;
		
	EndIf;
	
	For Each ContactInformationObject In ContactInformationObjects Do
		
		If ContainsContactInformation(TypeOf(ContactInformationObject)) Then
			
			For Each ContactInformationRow In ContactInformationObject.ContactInformation Do
				
				If Not ValueIsFilled(ContactInformationRow.Kind) Then
					Continue;
				EndIf;
				
				If ContactsManagerInternalCached.ObjectContactInformationContainsValidFromColumn(ContactInformationObject.Ref) Then
					
					If ContactInformationRow.ValidFrom > Date Then
						Continue;
					EndIf;
					
					FilterByDate = New Structure;
					FilterByDate.Insert("Object", ContactInformationObject);
					FilterByDate.Insert("Kind",    ContactInformationRow.Kind);
					
					FoundRows = Result.FindRows(FilterByDate);
					
					If FoundRows.Count() > 0 Then
						If FoundRows[0].Date < ContactInformationRow.ValidFrom Then
							Result.Delete(FoundRows[0]);
						Else
							Continue;
						EndIf;
					EndIf;
					
				EndIf;
				
				If (ContactInformationTypes = Undefined Or ContactInformationTypes.Find(ContactInformationRow.Type) <> Undefined)
					And (ContactInformationKinds = Undefined Or ContactInformationKinds.Find(ContactInformationRow.Kind) <> Undefined) Then
					
					NewRow = Result.Add();
					FillPropertyValues(NewRow, ContactInformationRow);
					
					NewRow.Object = ContactInformationObject;
					
					If IsBlankString(NewRow.Value)
						And ValueIsFilled(NewRow.FieldValues) Then
						NewRow.Value = ContactInformationInJSON(NewRow.FieldValues, NewRow.Type);
					EndIf;
					
					If ContactsManagerInternalCached.ObjectContactInformationContainsValidFromColumn(ContactInformationObject.Ref) Then
						NewRow.Date = ContactInformationRow.ValidFrom;
					EndIf;
					
				EndIf;
			EndDo;
			
		EndIf;
	EndDo;
	
	LanguageCode = StrSplit(Filter.LanguageCode, "_", True)[0];
	If ValueIsFilled(LanguageCode) And LanguageCode <> Common.DefaultLanguageCode() Then
		For Each TableRow In Result Do
			If TableRow.Type = Enums.ContactInformationTypes.Address Then
				TableRow.Presentation = StringFunctions.LatinString(TableRow.Presentation);
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
	
EndFunction

// The constructor of the Filter parameter for the ContactInformation function.
//
// Returns:
//  Structure:
//   * ContactInformationTypes - Array of EnumRef.ContactInformationTypes - a filter by contact information type.
//   * ContactInformationKinds - Array of CatalogRef.ContactInformationKinds - a filter by contact information kinds.
//   * Date                     - Date - a date, from which contact information is recorded, it is used for storing
//                                       contact information change history. If the owner stores the change history,
//                                       an exception is thrown if the parameter does not match the date.
//   * LanguageCode - String - the code of the language in which you need to get the contact information presentation.
//                         Presentations of contact information of the Address type will be received upon transliteration. This parameter does not affect
//                         other types of contact information.
//
Function FilterContactInformation3() Export
	
	Filter = New Structure;
	Filter.Insert("ContactInformationTypes", New Array);
	Filter.Insert("ContactInformationKinds", New Array);
	Filter.Insert("Date");
	Filter.Insert("LanguageCode");
	
	Return Filter;
	
EndFunction

// Returns a table containing contact information for multiple objects. 
//
// Parameters:
//    ReferencesOrObjects         - Array - contact information owners.
//    ContactInformationTypes - Array
//                             - EnumRef.ContactInformationTypes - if types are specified,
//        only contact information of these types is got.
//    ContactInformationKinds - Array
//                             - CatalogRef.ContactInformationKinds - if kinds are specified,
//                               only contact information of these kinds is returned.
//    Date                     - Date   - a date, from which contact information is recorded,
//                              it is used for storing contact information change history.
//                              If the owner stores the change history, an exception is thrown if the parameter
//                              does not match the date.
//
// Returns:
//  ValueTable:
//    * Object           - AnyRef - a contact information owner.
//    * Kind              - CatalogRef.ContactInformationKinds - a contact information kind.
//    * Type              - EnumRef.ContactInformationTypes - contact information type.
//    * Value         - String - contact information in the internal JSON format.
//    * Presentation    - String - a contact information presentation.
//    * Date             - Date - a date, from which contact information record is valid.
//    * TabularSectionRowID - Number - row ID of this tabular section
//    * FieldValues    - String - an obsolete XML file matching the ContactInformation or Address XDTO packages. For
//                                  backward compatibility.
//
Function ObjectsContactInformation(ReferencesOrObjects, Val ContactInformationTypes = Undefined, Val ContactInformationKinds = Undefined, Date = Undefined) Export
	
	Filter = FilterContactInformation3();
	
	If TypeOf(ContactInformationTypes) = Type("Array") Then
		Filter.ContactInformationTypes = ContactInformationTypes;
	ElsIf ValueIsFilled(ContactInformationTypes) Then
		Filter.ContactInformationTypes.Add(ContactInformationTypes);
	EndIf;
	
	If TypeOf(ContactInformationKinds) = Type("Array") Then
		Filter.ContactInformationKinds = ContactInformationKinds;
	ElsIf ValueIsFilled(ContactInformationKinds) Then
		Filter.ContactInformationKinds.Add(ContactInformationKinds);
	EndIf;
	
	Filter.Date = Date;
	
	Return ContactInformation(ReferencesOrObjects, Filter);
	
EndFunction

// Returns a table that contains an object contact information.
// The behavior when a contact information presentation was returned is now considered obsolete
// and is kept for backward compatibility. To get a contact information presentation,
// use the ObjectContactInformationPresentation function instead.
//
// Parameters:
//  ReferenceOrObject - DefinedType.ContactInformationOwner
//                  - CatalogObject
//                  - DocumentObject - reference or object - a contact information owner (company,
//                                      counterparty, partner, and so on).
//  TypeOrTypeOfContactInformation - CatalogRef.ContactInformationKinds - a filter by contact information kind.
//                                - EnumRef.ContactInformationTypes - a filter by contact information type.
//  Date                     - Date - a date, from which contact information is recorded,
//                              it is used for storing contact information change history.
//                              If the owner stores the change history, an exception is thrown if the parameter
//                              does not match the date.
//  OnlyPresentation      - Boolean - if True, it returns only a presentation, otherwise, a value table.
//                                      To get a presentation, use the ObjectContactInformationPresentation function.
// 
// Returns:
//  ValueTable:
//    * Object           - AnyRef - a contact information owner.
//    * Kind              - CatalogRef.ContactInformationKinds   - a contact information kind.
//    * Type              - EnumRef.ContactInformationTypes - contact information type.
//    * Value         - String - contact information in the internal JSON format.
//    * Presentation    - String - a contact information presentation.
//    * Date             - Date   - a date, from which contact information record is valid.
//    * TabularSectionRowID - Number - row ID of this tabular section
//    * FieldValues    - String - an obsolete XML file matching the ContactInformation or Address XDTO packages. For
//                                  backward compatibility.
//
Function ObjectContactInformation(ReferenceOrObject, TypeOrTypeOfContactInformation = Undefined, Date = Undefined, OnlyPresentation = True) Export
	
	ContactInformationType = Undefined;
	ContactInformationKind = Undefined;
	If TypeOf(TypeOrTypeOfContactInformation) = Type("EnumRef.ContactInformationTypes") Then
		ContactInformationType = TypeOrTypeOfContactInformation;
	ElsIf TypeOf(TypeOrTypeOfContactInformation) = Type("CatalogRef.ContactInformationKinds") Then
		ContactInformationKind = TypeOrTypeOfContactInformation;
	EndIf;
	
	ObjectType = TypeOf(ReferenceOrObject);
	If Not Common.IsReference(ObjectType) Then
		
		Result = NewContactInformation();
		If ContainsContactInformation(ObjectType) Then
			
			For Each ContactInformationRow In ReferenceOrObject.ContactInformation Do
				If TypeOrTypeOfContactInformation = Undefined
					Or ContactInformationRow.Type = ContactInformationType
					Or ContactInformationRow.Kind = ContactInformationKind Then
						NewRow = Result.Add();
						FillPropertyValues(NewRow, ContactInformationRow);
						If IsBlankString(NewRow.Value)
							 And ValueIsFilled(NewRow.FieldValues) Then
								NewRow.Value = ContactInformationInJSON(NewRow.FieldValues, ContactInformationRow.Type);
						EndIf;
						NewRow.Object = ReferenceOrObject;
				EndIf;
			EndDo;
			
		EndIf;
		
		If OnlyPresentation Then
			If Result.Count() > 0 Then
				Return Result[0].Presentation;
			EndIf;
			Return "";
		EndIf;
		
		Return Result;
		
	EndIf;
	
	If OnlyPresentation Then
		// Left for backward compatibility.
		ObjectsArray = New Array;
		ObjectsArray.Add(ReferenceOrObject.Ref);
		
		If Not ValueIsFilled(TypeOrTypeOfContactInformation) Then
			Return "";
		EndIf;
		
		ObjectContactInformation = ObjectsContactInformation(ObjectsArray, ContactInformationType, ContactInformationKind, Date);
		
		If ObjectContactInformation.Count() > 0 Then
			Return ObjectContactInformation[0].Presentation;
		EndIf;
		
		Return "";
	Else
		ReferencesOrObjects = New Array;
		ReferencesOrObjects.Add(ReferenceOrObject);
		
		If ContactInformationType <> Undefined Then
			ContactInformationTypes = New Array;
			ContactInformationTypes.Add(ContactInformationType);
			ContactInformationKinds = Undefined;
		ElsIf ContactInformationKind <> Undefined Then
			ContactInformationKinds = New Array;
			ContactInformationKinds.Add(ContactInformationKind);
			ContactInformationTypes = New Array;
			ContactInformationTypes.Add(Common.ObjectAttributeValue(ContactInformationKind, "Type"));
		Else
			ContactInformationTypes = Undefined;
			ContactInformationKinds = Undefined;
		EndIf;
		
		Return ObjectsContactInformation(ReferencesOrObjects, ContactInformationTypes, ContactInformationKinds, Date);
	EndIf;
	
EndFunction

// Returns a presentation of object contact information.
//
// Parameters:
//  ReferenceOrObject         - Arbitrary - a contact information owner.
//  ContactInformationKind - CatalogRef.ContactInformationKinds - a contact information kind.
//  Separator             - String - a separator that is added to a presentation between contact information records.
//                                     By default, this is a comma followed by a space; to exclude
//                                     a space, use the WithoutSpaces flag of the AdditionalParameters parameter.
//  Date                    - Date - a date, from which contact information record is valid. If contact information
//                                   stores change history, the date is to be passed.
//  AdditionalParameters - Structure - optional parameters for generating a contact information presentation:
//   * OnlyFirst         - Boolean - if True, only presentation of the main (first)
//                                     contact information record returns. Default value is False;
//   * WithoutSpaces          - Boolean - if True, a space is not added automatically after the separator.
//                                     Default value is False;
// 
// Returns:
//  String
//
Function ObjectContactInformationPresentation(ReferenceOrObject, ContactInformationKind, Separator = ",", Date = Undefined, AdditionalParameters = Undefined) Export
	
	OnlyFirst = False;
	WithoutSpaces = False;
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		If AdditionalParameters.Property("OnlyFirst") Then
			OnlyFirst = AdditionalParameters.OnlyFirst;
		EndIf;
		If AdditionalParameters.Property("WithoutSpaces") Then
			WithoutSpaces = AdditionalParameters.WithoutSpaces;
		EndIf;
	EndIf;
	SeparatorInPresentation = ?(WithoutSpaces, Separator, Separator + " ");
	
	FirstPass         = True;
	ContactInformation = ObjectContactInformation(ReferenceOrObject, ContactInformationKind, Date, False);
	
	If TypeOf(ContactInformation) = Type("ValueTable") Then
		
		For Each ContactInformationRecord In ContactInformation Do
			If FirstPass Then
				Presentation = ContactInformationRecord.Presentation;
				If OnlyFirst Then
					Return Presentation;
				EndIf;
				FirstPass = False;
			Else
				Presentation = Presentation + SeparatorInPresentation + ContactInformationRecord.Presentation;
			EndIf;
		EndDo;
		
	Else
		
		Presentation = ContactInformation;
		
	EndIf;
	
	Return Presentation;
	
EndFunction

// Generates a new contact information table.
//
// Parameters:
//  ObjectColumn - Boolean - if True, the table will contain the Object column.
//                           It is necessary if you need to store contact information for multiple objects.
// 
// Returns:
//  ValueTable:
//       * Object        - AnyRef - a contact information owner.
//       * Kind           - CatalogRef.ContactInformationKinds - a contact information kind.
//       * Type           - EnumRef.ContactInformationTypes - contact information type.
//       * Value      - String - a JSON file matching a contact information structure.
//       * FieldValues - String - an XML file matching XDTO package ContactInformation or Address.
//       * Presentation - String - a contact information presentation.
//       * Date          - Date   - a date, from which contact information record is valid.
//       * TabularSectionRowID - Number - row ID of this tabular section
//
Function NewContactInformation(ObjectColumn = True) Export
	
	ContactInformation = New ValueTable;
	TypesDetailsString1500 = New TypeDescription("String",, New StringQualifiers(1500));
	
	If ObjectColumn Then
		ContactInformation.Columns.Add("Object");
	EndIf;
	
	ContactInformation.Columns.Add("Presentation",                     TypesDetailsString1500);
	ContactInformation.Columns.Add("FieldValues",                     New TypeDescription("String"));
	ContactInformation.Columns.Add("Value",                          New TypeDescription("String"));
	ContactInformation.Columns.Add("Kind",                               New TypeDescription("CatalogRef.ContactInformationKinds"));
	ContactInformation.Columns.Add("Type",                               New TypeDescription("EnumRef.ContactInformationTypes"));
	ContactInformation.Columns.Add("Date",                              New TypeDescription("Date"));
	ContactInformation.Columns.Add("TabularSectionRowID", New TypeDescription("Number"));
	
	Return ContactInformation;
	
EndFunction

// Adds contact information to an object by presentation or JSON file.
//
// Parameters:
//  ReferenceOrObject - CatalogRef
//                  - DocumentRef
//                  - CatalogObject
//                  - DocumentObject - a reference or an object of an owner
//                                     containing contact information. For references, after adding contact
//                                     information, the owner is recorded. If the object is passed, the contact
//                                     information is added without being recorded. To save changes,
//                                     it is necessary to record the object separately.
//  ValueOrPresentation - String - a presentation, JSON, or XML file matching XDTO package ContactInformation
//                                      or Address.
//  ContactInformationKind  - CatalogRef.ContactInformationKinds - a kind of contact information being added.
//  Date                     - Date    - a date, from which contact information will be recorded.
//                                       Required for contact information, for which the change history is stored.
//                                       If the value is not specified, the current session date is taken.
//  Replace                 - Boolean - if True (by default), all contact information
//                                      of the passed contact information kind will be replaced.
//                                      If False, a record will be added. If the contact information kind does not allow
//                                      entering multiple values and object contact information already contains a record,
//                                      the record will not be added.
//
Procedure AddContactInformation(ReferenceOrObject, ValueOrPresentation, ContactInformationKind, Date = Undefined, Replace = True) Export
	
	If Common.IsReference(TypeOf(ReferenceOrObject)) Then
		ContactsManagerInternal.AddContactInformationForRef(ReferenceOrObject,
			ValueOrPresentation, ContactInformationKind, Date, Replace);
		Return;
	EndIf;
	
	ContactsManagerInternal.AddContactInformation(ReferenceOrObject, ValueOrPresentation, 
		ContactInformationKind, Date, Replace);
	
EndProcedure

// Adds or changes contact information for several owners of contact information.
// Important: if in the Object column the ContactInformation parameter has a reference, then after adding
// contact information the owner will be recorded. If the Object column contains an object of
// the contact information owner, then, to save changes, it is necessary to record the objects separately.
//
// Parameters:
//  ContactInformation - See ContactsManager.NewContactInformation
//  Replace             - Boolean -  if True (by default),
//                                   all contact information of the passed contact information kind will be replaced.
//                                   If False, a record will be added. If the contact information kind does not allow
//                                   entering multiple values and object contact information already contains a record,
//                                   the record will not be added.
//                                   
//                                   
//
Procedure SetObjectsContactInformation(ContactInformation, Replace = True) Export
	
	If ContactInformation.Count() = 0 Then
		Return;
	EndIf;
	
	ContactInformationOwners = New Map;
	For Each ContactInformationRow In ContactInformation Do
		ContactInformationParameters = ContactInformationOwners[ContactInformationRow.Object];
		If ContactInformationParameters = Undefined Then
			If Not ContainsContactInformation(ContactInformationRow.Object) Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString( 
					NStr("en = 'Object %1 is not attached to the ""Contact information"" subsystem';"), String(ContactInformationRow.Object));
				Raise ErrorText;
			EndIf;
			
			ContactInformationParameters = New Structure;
			IsReference = Common.RefTypeValue(ContactInformationRow.Object);
			ContactInformationParameters.Insert("IsReference", IsReference);
			If Not IsReference Then
				OwnerOfTheKey = ContactInformationRow.Object; // CatalogObject
			EndIf;
			ContactInformationParameters.Insert("Periodic", 
				ContactsManagerInternalCached.ObjectContactInformationContainsValidFromColumn(
				?(IsReference, ContactInformationRow.Object, OwnerOfTheKey.Ref)));
			
			ContactInformationOwners.Insert(ContactInformationRow.Object, ContactInformationParameters);
		EndIf;
		
		RestoreEmptyValuePresentation(ContactInformationRow);
		
	EndDo;
	
	For Each ContactInformationOwner In ContactInformationOwners Do
		Filter = New Structure("Object", ContactInformationOwner.Key);
		ObjectContactInformationRows = ContactInformation.FindRows(Filter);
		
		If ContactInformationOwner.Value["IsReference"] Then
			ContactsManagerInternal.SetObjectsContactInformationForRef(ContactInformationOwner, ObjectContactInformationRows, Replace);
		Else
			ContactsManagerInternal.SetObjectsContactInformation(ContactInformationOwner, ContactInformationOwner.Key, ObjectContactInformationRows, Replace);
		EndIf;
		
	EndDo;
	
EndProcedure

// Adds or changes contact information for the contact information owner.
//
// Parameters:
//  ReferenceOrObject - CatalogRef
//                  - DocumentRef
//                  - CatalogObject
//                  - DocumentObject - a reference or an object of
//                                     a contact information owner. For references, after adding contact information,
//                                     the owner is recorded. If the object is passed, the contact information is
//                                     added without being recorded. To save changes, it is necessary to
//                                     record the object separately.
//                  - FormDataStructure:
//                      *  Ref - CatalogRef - a reference to an object-owner of a contact information
//  ContactInformation - ValueTable - a table containing contact information
//                                           See column details in the NewContactInformation function.
//                                           Warning! If a blank value table is passed and the replacement mode is set,
//                                           all contact information of the contact information owner will be cleared.
//  Replace             - Boolean          - if True (by default), all contact information of the passed contact information kind
//                                           will be replaced.
//                                           If False, a record will be added. If the contact information kind 
//                                           does not allow entering multiple values and object contact information
//                                           already contains a record, the record will not be added.
//
Procedure SetObjectContactInformation(ReferenceOrObject, Val ContactInformation, Replace = True) Export
	
	If TypeOf(ReferenceOrObject) <> Type("FormDataStructure") Then
		MetadataObject = Metadata.FindByType(TypeOf(ReferenceOrObject));
	Else
		MetadataObject = Metadata.FindByType(TypeOf(ReferenceOrObject.Ref));
	EndIf;
	
	If Not ContainsContactInformation(ReferenceOrObject.Ref) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString( 
			NStr("en = 'Object %1 is not attached to the ""Contact information"" subsystem';"), MetadataObject.Presentation());
		Raise ErrorText;
	EndIf;
	
	If Common.RefTypeValue(ReferenceOrObject) Then
		ContactsManagerInternal.SetObjectContactInformationForRef(ReferenceOrObject, ContactInformation, MetadataObject, Replace);
		Return;
	EndIf;
	
	// Clearing contact information using a blank table.
	If ContactInformation.Count() = 0 Then
		If Replace Then
			ReferenceOrObject.ContactInformation.Clear();
		EndIf;
		Return;
	EndIf;
	
	ContactsManagerInternal.SetObjectContactInformation(ReferenceOrObject, ContactInformation, MetadataObject, Replace);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Phone numbers.

// Returns information about a phone or a fax number.
//
// Parameters:
//  ContactInformation - String - a phone in the internal JSON or XML format matching the XDTO package
//                                  ContactInformation.
//                       - Undefined - constructor, returns a list of blank phone fields.
//
// Returns:
//  Structure:
//    * Presentation - String - — a full presentation of a phone number with an extension and comment. For example, "+1 800
//                               8222531 (+12) Call after 6 p.m.".
//    * CountryCode     - String - a country code. For example, +7.
//    * CityCode     - String - a city code. For example, 495.
//    * PhoneNumber - String - a phone number. For example, 1234567.
//    * PhoneExtension    - String - an extension. For example, +12.
//    * Comment   - String - a comment to a phone number. For example, "Call after 6 p.m.".
//
Function InfoAboutPhone(ContactInformation = Undefined) Export
	
	Result               = ContactsManagerClientServer.PhoneFieldStructure();
	If ContactInformation = Undefined Then
		Return Result;
	EndIf;
	
	PhoneByFields         = ContactsManagerInternal.ContactInformationToJSONStructure(ContactInformation, 
		Enums.ContactInformationTypes.Phone);
	
	Result.Presentation = String(PhoneByFields.Value);
	Result.CountryCode     = String(PhoneByFields.CountryCode);
	Result.CityCode     = String(PhoneByFields.AreaCode);
	Result.PhoneNumber = String(PhoneByFields.Number);
	Result.PhoneExtension    = String(PhoneByFields.ExtNumber);
	Result.Comment   = String(PhoneByFields.Comment);
	
	Return Result;
	
EndFunction

// Returns a string containing a phone number without an area code and an extension.
//
// Parameters:
//    ContactInformation - String - a JSON or XML string of contact information matching XDTO package ContactInformation.
//
// Returns:
//    String - phone number.
//
Function ContactInformationPhoneNumber(Val ContactInformation) Export
	
	If IsBlankString(ContactInformation) Then
		Return "";
	EndIf;
	
	If ContactsManagerClientServer.IsXMLContactInformation(ContactInformation) Then
		ContactInformationAsStructure = ContactsManagerInternal.ContactInformationToJSONStructure(ContactInformation);
	ElsIf ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		ContactInformationAsStructure = ContactsManagerInternal.JSONToContactInformationByFields(ContactInformation, Enums.ContactInformationTypes.Phone);
	EndIf;
	
	If ContactInformationAsStructure.Property("Number") Then
		
		Return TrimAll(ContactInformationAsStructure.Number);
		
	EndIf;
	
	Raise NStr("en = 'Cannot recognize number. Phone number or fax expected.';");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Convert contact information.

// Converts incoming contact information formats into the internal JSON format.
//
// Parameters:
//    ContactInformation - String - a string in the XML format. The structure of the XML document matches the ContactInformation
//                                    or Address XDTO package (for addresses containing fields with specific national characteristics).
//                                    If a string is passed in the JSON format, the return value will
//                                    match the string.
//                         - Structure - See ContactsManagerClientServer.ContactInformationStructureByType
//                                       See AddressManager.AddressFields for addresses containing fields with specific national characteristics.
//                                       See AddressManagerClientServer.ContactInformationStructureByType
//                                       for other types of contact information containing local specific fields.
//    ExpectedKind - CatalogRef.ContactInformationKinds
//                 - EnumRef.ContactInformationTypes -
//                   Intended for identifying contact information type in cases where
//                   it cannot be done using the ContactInformation parameter.
//
// Returns:
//     String - Contact information in the internal JSON format.
//              For the fields and details, See ContactsManagerClientServer.NewContactInformationDetails.
//              For additional fields used in localized configurations, see AddressManagerClientServer.NewContactInformationDetails
//
Function ContactInformationInJSON(Val ContactInformation, Val ExpectedKind = Undefined) Export
	
	If ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		Return ContactInformation;
	EndIf;
	
	SettingsOfConversion = ContactInformationConversionSettings();
	SettingsOfConversion.UpdateIDs = False;
	
	ContactInformationByFields = ContactsManagerInternal.ContactInformationToJSONStructure(ContactInformation, ExpectedKind, SettingsOfConversion);
	Return ContactsManagerInternal.ToJSONStringStructure(ContactInformationByFields);
	
EndFunction

// Converts all incoming contact information formats to XML.
//
// Parameters:
//    FieldValues - String
//                  - Structure
//                  - Map
//                  - ValueList - details of contact information fields.
//                    XML must match XDTO package ContactInformation or Address.
//                    Structure, Map, ValueList must contain fields in accordance with the structure
//                    of XDTO packages ContactInformation or Address (for a configuration with support of local specifics).
//    Presentation - String - a contact information presentation. Used if it is impossible to determine
//                    a presentation based on the FieldValues parameter (the Presentation field is missing).
//    ExpectedKind  - CatalogRef.ContactInformationKinds
//                  - EnumRef.ContactInformationTypes -
//                    Intended for identifying contact information type in cases where it cannot be done using the "FieldsValues" field.
//
// Returns:
//     String - contact information in the XML format matching the structure of the XDTO packages ContactInformation and Address.
//
Function ContactInformationToXML(Val FieldValues, Val Presentation = "", Val ExpectedKind = Undefined) Export
	
	If ContactsManagerInternalCached.IsLocalizationModuleAvailable() Then
		ModuleContactsManagerLocalization = Common.CommonModule("ContactsManagerLocalization");
		Result = ModuleContactsManagerLocalization.TransformContactInformationXML(New Structure(
			"FieldValues, Presentation, ContactInformationKind",
		FieldValues, Presentation, ExpectedKind));
		Return Result.XMLData1;
	EndIf;
	
	Return "";
	
EndFunction

// Converts the contact information stored in the FieldValue field to JSON and saves it
// in the filed of the Table value column ContactInformation.
// If the FieldsValue and Value columns contain empty strings, JSON will be formed by presentation.
// If the ReferenceOrObject parameter contains a contact information object,
// then, to save changes, it is necessary to record the object separately.
// If the reference is passed, after the conversion of at least one contact information string, the owner will be recorded.
//
// Parameters:
//  ReferenceOrObject - DefinedType.ContactInformationOwner - a reference to an object with contact information.
//                  - CatalogObject
//                  - DocumentObject - object - a contact information owner (company,
//                                    counterparty, partner, and so on).
// 
// Returns:
//  Boolean - — if True, contact information will be converted to JSON.
//
Function UpdateObjectContactInformation(ReferenceOrObject) Export
	
	ObjectModified = False;
	
	ObjectType = TypeOf(ReferenceOrObject);
	
	If Not ContainsContactInformation(ObjectType) Then
		Return ObjectModified;
	EndIf;
	
	ObjectModified = ContactsManagerInternal.ConvertContactInformationToJSONFormat(
		ReferenceOrObject, ObjectType);
	
	Return ObjectModified;
	
EndFunction

// Returns objects that store contact information in obsolete XML or key—value formats
// and whose contact information must be converted to the modern JSON format.
//
// Parameters:
//  MetadataObject - MetadataObject - an object with contact information whose item
//                     containing blank fields in JSON is to be defined.
//  PortionSize  - Number - a number of objects returned in one call. If not specified, all the objects will be selected.
// 
// Returns:
//  Array - — object references.
//
Function ObjectsThatRequireContactInformationUpdate(MetadataObject, PortionSize = Undefined) Export
	
	If MetadataObject.TabularSections.Find("ContactInformation") = Undefined Then
		Return New Array;
	EndIf;
	
	FullTabularSectionName = MetadataObject.FullName() + ".ContactInformation";
	
	Query = New Query;
	QueryText = "SELECT DISTINCT
	|	ContactInformationTabularSection.Ref AS Ref
	|FROM
	|	&ContactInformationTable1 AS ContactInformationTabularSection
	|WHERE
	|	CAST(ContactInformationTabularSection.Value AS STRING(1)) = """" ";
	
	QueryText = StrReplace(QueryText, "&ContactInformationTable1", FullTabularSectionName);
	If TypeOf(PortionSize) = Type("Number") Then
		QueryText = StrReplace(QueryText, "SELECT DISTINCT", "SELECT DISTINCT TOP " + Format(PortionSize,"NGS=' '; NG=0")); // @query-part-1, @query-part-2 
	EndIf;
	
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return New Array;
	EndIf;
	
	Result = QueryResult.Unload().UnloadColumn("Ref");
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Contact information management from other subsystems.

// Returns a contact information type.
//
// Parameters:
//    ContactInformation - String - contact information as an XML matching the structure of
//                                    the ContactInformation and Address XDTO packages.
//
// Returns:
//    EnumRef.ContactInformationTypes - the corresponding type.
//
Function ContactInformationType(Val ContactInformation) Export
	
	If ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		
		ContactInformationAsStructure = ContactsManagerInternal.JSONStringToStructure1(ContactInformation);
		If TypeOf(ContactInformationAsStructure) = Type("Structure") And ContactInformationAsStructure.Property("type") Then
			Return Enums.ContactInformationTypes[ContactInformationAsStructure.type];
		EndIf;
	
	EndIf;
	
	If ContactsManagerInternalCached.IsLocalizationModuleAvailable() Then
	
		ModuleContactsManagerLocalization = Common.CommonModule("ContactsManagerLocalization");
		Return ModuleContactsManagerLocalization.ContactInformationType(ContactInformation);
		
	EndIf;
		
	Return Enums.ContactInformationTypes.EmptyRef();
	
EndFunction

// Converts a presentation of contacts into the internal JSON format.
//
// Correct conversion is not guaranteed for the addresses entered in free form.
//
//  Parameters:
//      Presentation - String  - a string presentation of contact information displayed to a user.
//      ExpectedKind  - CatalogRef.ContactInformationKinds
//                    - EnumRef.ContactInformationTypes
//                    - Structure - a kind or a type of contact information.
//
// Returns:
//      String - contact information in the JSON format.
//
Function ContactsByPresentation(Presentation, ExpectedKind) Export
	
	Return ContactsManagerInternal.ToJSONStringStructure(
		ContactsManagerInternal.ContactsByPresentation(Presentation, ExpectedKind));
	
EndFunction

// Returns a presentation of contact information (such as address, phone, or email).
//
// Parameters:
//    ContactInformation - String - a JSON or XML string of contact information
//                                    matching XDTO packages ContactInformation or Address.
//                         - XDTODataObject - the ContactInformation or Address XDTO object.
//                         - Structure - see AddressManager.AddressInfo
//                         - Structure - See ContactsManager.InfoAboutPhone
//    Transliterate - Boolean - If set to "True", the contact information presentation will be converted from Cyrillic into Latin.
//
// Returns:
//    String - a contact information presentation.
//
Function ContactInformationPresentation(Val ContactInformation, Val Transliterate = False) Export
	
	Return ContactsManagerInternal.ContactInformationPresentation(ContactInformation, Transliterate);
	
EndFunction

// Evaluates that the address was entered in free form.
//
//  Parameters:
//      ContactInformation - String - a JSON or XML string of contact information matching XDTO packages
//                                      ContactInformation or Address.
//
//  Returns:
//      Boolean - new value.
//
Function AddressEnteredInFreeFormat(Val ContactInformation) Export
	
	If ContactsManagerClientServer.IsXMLContactInformation(ContactInformation) Then
		JSONContactInformation = ContactInformationInJSON(ContactInformation);
		ContactInformation = ContactsManagerInternal.JSONToContactInformationByFields(JSONContactInformation, Enums.ContactInformationTypes.Address);
	ElsIf ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		ContactInformation = ContactsManagerInternal.JSONToContactInformationByFields(ContactInformation, Enums.ContactInformationTypes.Address);
	EndIf;
	
	Return ContactsManagerClientServer.IsAddressInFreeForm(ContactInformation.AddressType);
	
EndFunction

// Returns contact information comment.
//
// Parameters:
//  ContactInformation - String - a JSON or XML string or XDTO object matching XDTO packages
//                                   ContactInformation or Address.
//
// Returns:
//  String - a contact information comment or a blank string
//           if the parameter value is not contact information.
//
Function ContactInformationComment(ContactInformation) Export
	
	If IsBlankString(ContactInformation) Then
		Return "";
	EndIf;

	If ContactsManagerClientServer.IsXMLContactInformation(ContactInformation) Then
		ContactInformationAsStructure = ContactsManagerInternal.ContactInformationToJSONStructure(ContactInformation);
	ElsIf ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		ContactInformationAsStructure = ContactsManagerInternal.JSONStringToStructure1(ContactInformation);
	Else
		ContactInformationToXML = ContactInformationToXML(ContactInformation);
		ContactInformationAsStructure = ContactsManagerInternal.ContactInformationToJSONStructure(ContactInformationToXML);
	EndIf;
	
	If ContactInformationAsStructure.Property("Comment") Then
		Return ContactInformationAsStructure.Comment;
	EndIf;
	
	Return "";
	
EndFunction

// Sets a new comment for contact information.
//
// Parameters:
//   ContactInformation - String
//                        - XDTODataObject - a JSON or XML string of contact information matching XDTO
//                                       packages ContactInformation or Address.
//   Comment          - String             - a new comment value.
//
Procedure SetContactInformationComment(ContactInformation, Val Comment) Export
	
	If ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		
		ContactInformationAsStructure = ContactsManagerInternal.JSONToContactInformationByFields(ContactInformation, Undefined);
		ContactInformationAsStructure.comment = Comment;
		ContactInformation = ContactsManagerInternal.ToJSONStringStructure(ContactInformationAsStructure);
		Return;
	EndIf;
		
	If ContactsManagerInternalCached.IsLocalizationModuleAvailable() Then

		ModuleContactsManagerLocalization = Common.CommonModule("ContactsManagerLocalization");
		ModuleContactsManagerLocalization.SetContactInformationComment(ContactInformation, Comment);
		
	EndIf;
	
EndProcedure

// Returns information on the address country.
// If the passed string does not contain information on the address, an exception will be raised.
// If an empty string is passed, a blank structure is returned.
// If the country does not exist in the catalog but exists in the country classifier, the Ref field of the result will not be filled in.
// If the country does not exist in the country classifier, only the Description field will be filled in.
//
// Parameters:
//    Address - Structure
//          - String - an address in a JSON format or an XML string matching XDTO packages ContactInformation
//                     or Address.
//
// Returns:
//    Structure - Country details containing the following fields:
//        * Ref             - CatalogRef.WorldCountries
//                             - Undefined - a reference to the world country catalog item.
//        * Description       - String - a country description.
//        * Code                - String - country code.
//        * DescriptionFull - String - a full description of the country.
//        * CodeAlpha2          - String - a two-character alpha-2 country code.
//        * CodeAlpha3          - String - a three-character alpha-3 country code.
//
Function ContactInformationAddressCountry(Val Address) Export
	
	Result = New Structure("Ref, Code, Description, DescriptionFull, CodeAlpha2, CodeAlpha3");
	
	If TypeOf(Address) = Type("String") Then
		
		If IsBlankString(Address) Then
			Return Result;
		EndIf;
	
		If ContactsManagerClientServer.IsXMLContactInformation(Address) Then
			Address = ContactInformationInJSON(Address, Enums.ContactInformationTypes.Address);
		EndIf;
		
		Address = ContactsManagerInternal.JSONToContactInformationByFields(Address, Enums.ContactInformationTypes.Address);
		
	ElsIf TypeOf(Address) <> Type("Structure") Then
		
		Raise NStr("en = 'Cannot recognize country. Address expected.';");
		
	EndIf;
	
	Result.Description = TrimAll(Address.Country);
	CountryData1 = WorldCountryData(, Result.Description);
	Return ?(CountryData1 = Undefined, Result, CountryData1);
	
EndFunction

// Returns a domain of the network address for a web link or an email address.
//
// Parameters:
//    ContactInformation - String - a JSON or XML string of contact information matching XDTO package ContactInformation.
//
// Returns:
//    String - an address domain.
//
Function ContactInformationAddressDomain(Val ContactInformation) Export
	
	If IsBlankString(ContactInformation) Then
		Return "";
	EndIf;
	
	If ContactsManagerClientServer.IsXMLContactInformation(ContactInformation) Then
		ContactInformationAsStructure = ContactsManagerInternal.ContactInformationToJSONStructure(ContactInformation);
	ElsIf ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		ContactInformationAsStructure = ContactsManagerInternal.JSONStringToStructure1(ContactInformation);
	EndIf;
	
	If ContactInformationAsStructure.Property("Type") And ContactInformationAsStructure.Property("Value") Then
		
		AddressDomain = TrimAll(ContactInformationAsStructure.Value);
		If ContactInformationTypeByDescription(ContactInformationAsStructure.Type) = Enums.ContactInformationTypes.WebPage Then
			
			Position = StrFind(AddressDomain, "://");
			If Position > 0 Then
				AddressDomain = Mid(AddressDomain, Position + 3);
			EndIf;
			Position = StrFind(AddressDomain, "/");
			Return ?(Position = 0, AddressDomain, Left(AddressDomain, Position - 1));
			
		ElsIf ContactInformationTypeByDescription(ContactInformationAsStructure.Type) = Enums.ContactInformationTypes.Email Then
			
			Position = StrFind(AddressDomain, "@");
			Return ?(Position = 0, AddressDomain, Mid(AddressDomain, Position + 1));
			
		EndIf;
		
	EndIf;
	
	Raise NStr("en = 'Cannot recognize domain. Email address or URL expected.';");
EndFunction

// Compares two instances of contact information.
//
// Parameters:
//    Data1 - XDTODataObject - object with contact information.
//            - String     - contact information in XML format.
//            - Structure  - contact information details. The expected fields are:
//                 * FieldValues - String
//                                 - Structure
//                                 - ValueList
//                                 - Map - contact information fields.
//                 * Presentation - String - a presentation. Used when presentation
//                                            cannot be extracted from FieldValues (the Presentation field is not available).
//                 * Comment - String - a comment. Used when a comment cannot be extracted
//                                          from FieldValues.
//                 * ContactInformationKind - CatalogRef.ContactInformationKinds
//                                           - EnumRef.ContactInformationTypes
//                                           - Structure -
//                                             Used in cases where the type cannot be identified using "FieldsValues".
//    Data2 - XDTODataObject
//            - String
//            - Structure - — see details of the Data1 parameter.
//
// Returns:
//     ValueTable: - A table of diff fields with the following columns:
//        * Path      - String - XPath identifying a different value. The "ContactInformationType" value
//                               means that passed contact information sets have different types.
//        * LongDesc  - String - details of a different attribute in terms of the subject field.
//        * Value1 - String - a value matching the object passed in the Data1 parameter.
//        * Value2 - String - a value matching the object passed in Data2 parameter.
//
Function ContactInformationDifferences(Val Data1, Val Data2) Export
	
	Result = New ValueTable;
	Result.Columns.Add("Path", Common.StringTypeDetails(0));
	Result.Columns.Add("LongDesc", Common.StringTypeDetails(0));
	Result.Columns.Add("Value1", Common.StringTypeDetails(0));
	Result.Columns.Add("Value2", Common.StringTypeDetails(0));
	
	If Not ContactsManagerInternalCached.IsLocalizationModuleAvailable() Then
		Return Result;
	EndIf;
	
	ModuleContactsManagerLocalization = Common.CommonModule("ContactsManagerLocalization");
	Return ModuleContactsManagerLocalization.ContactInformationDifferences(Data1, Data2, Result);
	
EndFunction

// Generates a temporary table with contact information of multiple objects.
//
// Parameters:
//    TempTablesManager  - TempTablesManager - a temporary table is created in the manager
//     ContactInformationTemporaryTable with the following fields:
//     * Object        - AnyRef - a contact information owner.
//     * Kind           - CatalogRef.ContactInformationKinds - a reference to a contact information kind.
//     * Type           - EnumRef.ContactInformationTypes - contact information type.
//     * FieldValues - String - an XML file matching the ContactInformation or Address XDTO data package.
//     * Presentation - String - a contact information presentation.
//    ObjectsArray           - Array - contact information owners.
//    ContactInformationTypes - Array - if specified, a temporary table will contain only contact
//                                        information of these types.
//    ContactInformationKinds - Array - if specified, a temporary table will contain only contact
//                                        information of these types.
//    Date                     - Date   - the date, from which contact information record is valid. It is used for
//                                        storing the history of contact information changes. If the owner stores the change history,
//                                        an exception is thrown if the parameter does not match the date.
//
Procedure CreateContactInformationTemporaryTable(TempTablesManager, ObjectsArray, ContactInformationTypes = Undefined, ContactInformationKinds = Undefined, Date = Undefined) Export
	
	If TypeOf(ObjectsArray) <> Type("Array") Or ObjectsArray.Count() = 0 Then
		Raise NStr("en = 'Invalid value for array of contact information owners.';");
	EndIf;
	
	ObjectsGroupedByTypes = New Map;
	For Each Ref In ObjectsArray Do
		ObjectType = TypeOf(Ref);
		FoundObject = ObjectsGroupedByTypes.Get(ObjectType); // Array
		If FoundObject = Undefined Then
			RefSet = New Array;
			RefSet.Add(Ref);
			ObjectsGroupedByTypes.Insert(ObjectType, RefSet);
		Else
			FoundObject.Add(Ref);
		EndIf;
	EndDo;
	
	Query = New Query();
	QueryTextDataPreparation = "";
	
	For Each ObjectWithContactInformation In ObjectsGroupedByTypes Do
		
		If Not ContainsContactInformation(ObjectWithContactInformation.Key) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 does not contain contact information.';"), String(ObjectWithContactInformation.Key));
		EndIf;
		
		ObjectMetadata = Metadata.FindByType(ObjectWithContactInformation.Key);
		TableName = ObjectMetadata.Name;
		
		If ObjectMetadata.TabularSections.ContactInformation.Attributes.Find("ValidFrom") <> Undefined Then
			
			QueryTextDataPreparation = QueryTextDataPreparation + "SELECT ALLOWED
			|	ContactInformation.Ref AS Object,
			|	ContactInformation.Kind AS Kind,
			|	MIN(ContactInformation.LineNumber) AS LineNumber,
			|	MAX(ContactInformation.ValidFrom) AS ValidFrom
			|INTO ContactInformationSlice" + TableName + "
			|FROM
			|	" + ObjectMetadata.FullName() + ".ContactInformation AS ContactInformation
			|WHERE
			|	ContactInformation.Ref IN (&ObjectsArray" + TableName + ")
			|	AND ContactInformation.ValidFrom <= &ValidFrom
			|	AND ContactInformation.Kind <> VALUE(Catalog.ContactInformationKinds.EmptyRef)
			|	AND ContactInformation.Type <> VALUE(Enum.ContactInformationTypes.EmptyRef)
			|
			|GROUP BY
			|	ContactInformation.Kind, ContactInformation.Ref
			|;" // @Query-part-1
			
		EndIf;
	EndDo;
	
	QueryText = "";
	ThisIsTheFirstRequest = True;
	For Each ObjectWithContactInformation In ObjectsGroupedByTypes Do
		QueryText = QueryText + ?(Not IsBlankString(QueryText), Chars.LF + " UNION ALL " + Chars.LF, "");
		ObjectMetadata = Metadata.FindByType(ObjectWithContactInformation.Key);
		TableName = ObjectMetadata.Name;
		
		HasTabularSectionRowID = ObjectMetadata.TabularSections.ContactInformation.Attributes.Find("TabularSectionRowID") <> Undefined;
		
		If ObjectMetadata.TabularSections.ContactInformation.Attributes.Find("ValidFrom") <> Undefined Then
			If TypeOf(Date) <> Type("Date") Then
				Raise NStr("en = 'To view the contact information history,
					|specify the start date.';");
			EndIf;
			
			FilterConditions = ?(ContactInformationKinds = Undefined, "", " ContactInformation.Kind IN (&ContactInformationKinds)"); // @query-part-2
			If IsBlankString(FilterConditions) Then
				ConditionAnd = "";
			Else
				ConditionAnd = " And ";
			EndIf;
			FilterConditions = FilterConditions + ?(ContactInformationTypes = Undefined, "", ConditionAnd + " ContactInformation.Type IN (&ContactInformationTypes)"); // @query-part-2
			If Not IsBlankString(FilterConditions) Then
				FilterConditions = " WHERE " + FilterConditions;
			EndIf;
			
			QueryText = QueryText + "SELECT
			|	ContactInformation.Ref AS Object,
			|	ContactInformation.Kind AS Kind,
			|	ContactInformation.Type AS Type,
			|	ContactInformation.LineNumber AS LineNumber,
			|	ContactInformation.ValidFrom AS ValidFrom,
			|	ContactInformation.Presentation AS Presentation,
			|	ContactInformation.Value,
			|	ContactInformation.FieldValues,
			|	0 AS TabularSectionRowID
			|FROM
			|	&ContactInformationSlice AS ContactInformationSlice
			|		LEFT JOIN #ContactInformation AS ContactInformation
			|		ON ContactInformationSlice.Kind = ContactInformation.Kind
			|			AND ContactInformationSlice.ValidFrom = ContactInformation.ValidFrom
			|			AND ContactInformationSlice.Object = ContactInformation.Ref " + FilterConditions;
			
			QueryText = StrReplace(QueryText, "&ContactInformationSlice", "ContactInformationSlice" + TableName);
			
		Else
			QueryText = QueryText + "SELECT
			|	ContactInformation.Ref AS Object,
			|	ContactInformation.Kind AS Kind,
			|	ContactInformation.Type AS Type,
			|	ContactInformation.LineNumber AS LineNumber,
			|	DATETIME(1,1,1) AS ValidFrom,
			|	ContactInformation.Presentation AS Presentation,
			|	ContactInformation.Value,
			|	ContactInformation.FieldValues AS FieldValues,
			|	0 AS TabularSectionRowID
			|FROM
			|	#ContactInformation AS ContactInformation
			|WHERE
			| ContactInformation.Kind <> VALUE(Catalog.ContactInformationKinds.EmptyRef)
			| AND ContactInformation.Type <> VALUE(Enum.ContactInformationTypes.EmptyRef)
			| AND ContactInformation.Ref IN (&ArrayOfObjectsTableName)
			| AND &ConditionWhereTypeContactInformation
			| AND &ConditionWhereIsTheTypeOfContactInformation
			|";
			
			QueryText = StrReplace(QueryText, "&ConditionWhereTypeContactInformation",
				?(ContactInformationTypes = Undefined, "TRUE", "ContactInformation.Type IN (&ContactInformationTypes)")); // @query-part-2
			QueryText = StrReplace(QueryText, "&ConditionWhereIsTheTypeOfContactInformation",
				?(ContactInformationKinds = Undefined, "TRUE", "ContactInformation.Kind IN (&ContactInformationKinds)")); // @query-part-2
			
			QueryText = StrReplace(QueryText, "&ArrayOfObjectsTableName", "&ObjectsArray" + TableName);
			
		EndIf;
		
		QueryText = StrReplace(QueryText, "#ContactInformation" , ObjectMetadata.FullName() + ".ContactInformation"); // @Query-part-1, @Query-part-2
		
		If ThisIsTheFirstRequest Then
			
			QueryText = StrReplace(QueryText, "SELECT" , "SELECT ALLOWED"); // @Query-part-1, @Query-part-2
			
			QueryText = StrReplace(QueryText, 
			"FROM" , "INTO TTContactInformation "+ Chars.LF + "FROM"); // @Query-part-1, @Query-part-2, @Query-part-3
			
			ThisIsTheFirstRequest = False;
			
		EndIf;
		
		If HasTabularSectionRowID Then
			QueryText = StrReplace(QueryText, "0 AS TabularSectionRowID",
				"ContactInformation.TabularSectionRowID AS TabularSectionRowID"); // @Query-part-1, @Query-part-2
		EndIf;
		
		Query.SetParameter("ObjectsArray" + TableName, ObjectWithContactInformation.Value);
	EndDo;
	
	Query.Text = QueryTextDataPreparation + QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Query.SetParameter("ValidFrom", Date);
	Query.SetParameter("ContactInformationTypes", ContactInformationTypes);
	Query.SetParameter("ContactInformationKinds", ContactInformationKinds);
	Query.Execute();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// World countries.

// Returns country data from the country catalog or classifier.
//
// Parameters:
//    CountryCode    - String
//                 - Number - — a country code by classifier. If not specified, search by code is not executed.
//    Description - String - a country name including an international name. If not specified, search by description is not performed.
//
// Returns:
//    Structure - Country details with the following fields:
//        * Ref             - CatalogRef.WorldCountries
//                             - Undefined - a matching item of the world country catalog.
//        * Description       - String - a country description.
//        * Code                - String - country code.
//        * DescriptionFull - String - a full description of the country.
//        * CodeAlpha2          - String - a two-character alpha-2 country code.
//        * CodeAlpha3          - String - a three-character alpha-3 country code.
//        * EEUMember       - Boolean - a EAEU member country.
//        * InternationalDescription - String - international description of the country
//    Undefined — the country does not exist.
//
Function WorldCountryData(Val CountryCode = Undefined, Val Description = Undefined) Export
	Result = Undefined;
	
	If CountryCode = Undefined And Description = Undefined Then
		Return Result;
	EndIf;
	
	SearchCondition = New Array;
	ClassifierFilter = New Structure;
	
	StandardizedCode = WorldCountryCode(CountryCode);
	If CountryCode <> Undefined Then
		SearchCondition.Add("Code=" + CheckQuotesInString(StandardizedCode));
		ClassifierFilter.Insert("Code", StandardizedCode);
	EndIf;
	
	If Description <> Undefined Then
		Template_Description = " (Description = %1 OR InternationalDescription = %1)";
		SearchCondition.Add(StringFunctionsClientServer.SubstituteParametersToString(Template_Description,
			CheckQuotesInString(Description)));
		
		ClassifierFilter.Insert("Description", Description);
	EndIf;
	SearchCondition = StrConcat(SearchCondition, " And ");
	
	Result = New Structure;
	Result.Insert("Ref");
	Result.Insert("Code",                       "");
	Result.Insert("Description",              "");
	Result.Insert("DescriptionFull",        "");
	Result.Insert("InternationalDescription", "");
	Result.Insert("CodeAlpha2",                 "");
	Result.Insert("CodeAlpha3",                 "");
	Result.Insert("EEUMember",              False);
	
	QueryText = "SELECT TOP 1
	|	Ref, Code, Description, DescriptionFull,
	|	InternationalDescription, CodeAlpha2, CodeAlpha3, EEUMember
	|FROM
	|	Catalog.WorldCountries
	|WHERE
	|	&SearchCondition
	|ORDER BY
	|	Description";
	
	QueryText = StrReplace(QueryText, "&SearchCondition", SearchCondition);
	Query = New Query(QueryText);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then 
		FillPropertyValues(Result, Selection);
	Else
		
		If Not ContactsManagerInternalCached.AreAddressManagementModulesAvailable() Then
			Return Undefined;
		EndIf;
		
		ModuleAddressManager = Common.CommonModule("AddressManager");
		ClassifierData = ModuleAddressManager.TableOfClassifier();
		DataRows = ClassifierData.FindRows(ClassifierFilter);
		If DataRows.Count() = 0 Then
			Return Undefined;
		Else
			FillPropertyValues(Result, DataRows[0]);
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Returns a country data by code.
//
// Parameters:
//  Code     - String
//          - Number - — a country code by classifier.
//  CodeType - String - options: CountryCode (by default), Alpha2, and Alpha3.
// 
// Returns:
//  Structure - Country details with the following fields:
//     * Description       - String - a country description.
//     * Code                - String - country code.
//     * DescriptionFull - String - a full description of the country.
//     * CodeAlpha2          - String - a two-character alpha-2 country code.
//     * CodeAlpha3          - String - a three-character alpha-3 country code.
//     * EEUMember       - Boolean - a EAEU member country.
//  Undefined — the country does not exist.
//
Function WorldCountryClassifierDataByCode(Val Code, Val CodeType = "CountryCode") Export
	
	If Not ContactsManagerInternalCached.AreAddressManagementModulesAvailable()  Then
		Return Undefined;
	EndIf;
	
	Result = New Structure;
	Result.Insert("Code",                       "");
	Result.Insert("Description",              "");
	Result.Insert("DescriptionFull",        "");
	Result.Insert("CodeAlpha2",                 "");
	Result.Insert("CodeAlpha3",                 "");
	Result.Insert("EEUMember",              False);
	
	ModuleAddressManager = Common.CommonModule("AddressManager");
	ClassifierData = ModuleAddressManager.TableOfClassifier();
	
	If StrCompare(CodeType, "Alpha2") = 0 Then
		DataString1 = ClassifierData.Find(Upper(Code), "CodeAlpha2");
	ElsIf StrCompare(CodeType, "Alpha3") = 0 Then
		DataString1 = ClassifierData.Find(Upper(Code), "CodeAlpha3");
	Else
		DataString1 = ClassifierData.Find(WorldCountryCode(Code), "Code");
	EndIf;
	
	If DataString1 = Undefined Then
		Return Undefined
	EndIf;
	
	FillPropertyValues(Result, DataString1);
	
	Return Result;
	
EndFunction

// Returns country data by country description.
//
// Parameters:
//    Description - String - a country description.
//
// Returns:
//    Structure - Country details with the following fields:
//       * Description       - String - a country description.
//       * Code                - String - country code.
//       * DescriptionFull - String - a full description of the country.
//       * CodeAlpha2          - String - a two-character alpha-2 country code.
//       * CodeAlpha3          - String - a three-character alpha-3 country code.
//       * EEUMember       - Boolean - a EAEU member country.
//    Undefined — the country does not exist in the classifier.
//
Function WorldCountryClassifierDataByDescription(Val Description) Export
	
	If Not ContactsManagerInternalCached.AreAddressManagementModulesAvailable() Then
		Return Undefined;
	EndIf;
	
	Result = New Structure;
	Result.Insert("Code",                       "");
	Result.Insert("Description",              "");
	Result.Insert("DescriptionFull",        "");
	Result.Insert("CodeAlpha2",                 "");
	Result.Insert("CodeAlpha3",                 "");
	Result.Insert("EEUMember",              False);
	
	ModuleAddressManager = Common.CommonModule("AddressManager");
	ClassifierData = ModuleAddressManager.TableOfClassifier();
	
	DataString1 = ClassifierData.Find(Description, "Description");
	If DataString1 = Undefined Then
		Return Undefined;
	EndIf;
	
	FillPropertyValues(Result, DataString1);
	
	Return Result;
	
EndFunction

// Returns a reference to an item of the world country catalog by code or description.
// If the item of the WorldCountries catalog does not exist, it will be created based on filling data.
//
// Parameters:
//  CodeOrDescription - String    - a country code, alpha2 code, alpha3 code, or country description, including an international one.
//  FillingData   - Structure - data for filling when creating a new item.
//                                   The structure keys match the attribute of the WorldCountries catalog.
// 
// Returns:
//  CatalogRef.WorldCountries - — if several values were found, the first one will be returned.
//                                If it does not exist or filling data is not specified, an empty reference is returned.
//
Function WorldCountryByCodeOrDescription(CodeOrDescription, FillingData = Undefined) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	WorldCountries.Ref AS Ref
	|FROM
	|	Catalog.WorldCountries AS WorldCountries
	|WHERE
	|	(WorldCountries.Code = &CodeOrDescription
	|			OR WorldCountries.CodeAlpha2 = &CodeOrDescription
	|			OR WorldCountries.CodeAlpha3 = &CodeOrDescription
	|			OR WorldCountries.Description = &CodeOrDescription
	|			OR WorldCountries.InternationalDescription = &CodeOrDescription
	|			OR WorldCountries.DescriptionFull = &CodeOrDescription)";
	
	Query.SetParameter("CodeOrDescription", CodeOrDescription);
	QueryResult = Query.Execute().Select();
	
	If QueryResult.Next() Then
		Return QueryResult.Ref;
	EndIf;
	
	If Not ContactsManagerInternalCached.AreAddressManagementModulesAvailable()  Then
		Return Catalogs.WorldCountries.EmptyRef();
	EndIf;
	
	ModuleAddressManager = Common.CommonModule("AddressManager");
	ClassifierData = ModuleAddressManager.TableOfClassifier();
	
	Query = New Query;
	Query.Text = "SELECT
	|	TableClassifier.Code,
	|	TableClassifier.CodeAlpha2,
	|	TableClassifier.CodeAlpha3,
	|	TableClassifier.Description,
	|	TableClassifier.DescriptionFull,
	|	TableClassifier.InternationalDescription,
	|	TableClassifier.EEUMember,
	|	TableClassifier.NonRelevant
	|INTO TableClassifier
	|FROM
	|	&TableClassifier AS TableClassifier
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorldCountry.Code,
	|	WorldCountry.CodeAlpha2,
	|	WorldCountry.CodeAlpha3,
	|	WorldCountry.Description,
	|	WorldCountry.DescriptionFull,
	|	WorldCountry.InternationalDescription,
	|	WorldCountry.EEUMember,
	|	WorldCountry.NonRelevant
	|FROM
	|	TableClassifier AS WorldCountry
	|WHERE
	|	(WorldCountry.Code = &CodeOrDescription
	|			OR WorldCountry.CodeAlpha2 = &CodeOrDescription
	|			OR WorldCountry.CodeAlpha3 = &CodeOrDescription
	|			OR WorldCountry.Description = &CodeOrDescription
	|			OR WorldCountry.InternationalDescription = &CodeOrDescription
	|			OR WorldCountry.DescriptionFull = &CodeOrDescription)";
	
	Query.SetParameter("TableClassifier", ClassifierData);
	Query.SetParameter("CodeOrDescription",   CodeOrDescription);
	QueryResult = Query.Execute().Select();
	
	If QueryResult.Next() Then
		FillingData = WorldCountryDetails(Common.ValueTableRowToStructure(QueryResult));
	EndIf;
	
	If FillingData = Undefined
		Or Not FillingData.Property("Description")
		Or IsBlankString(FillingData.Description) Then
		Return Catalogs.WorldCountries.EmptyRef();
	EndIf;
	
	SetPrivilegedMode(True);
	CountryObject = Catalogs.WorldCountries.CreateItem();
	FillPropertyValues(CountryObject, FillingData);
	CountryObject.Write();
	
	Return CountryObject.Ref;
	
EndFunction

// Returns a list of member states of the Eurasian Economic Union (EAEU).
// The function call may initiate an HTTP request to a web service for working with classifiers
// to get a relevant list of all EAEU member states.
//
// Returns:
//  - ValueTable - A list of member states of the Eurasian Economic Union (EEU):
//     * Ref             - CatalogRef.WorldCountries - a reference to an item of the WorldCountries catalog.
//     * Description       - String - a country description.
//     * Code                - String - country code.
//     * DescriptionFull - String - a full description of the country.
//     * CodeAlpha2          - String - a two-character alpha-2 country code.
//     * CodeAlpha3          - String - a three-character alpha-3 country code.
//     * InternationalDescription - String - international description of the country
//
Function EEUMemberCountries() Export
	
	EEUCountries = CustomEAEUCountries();
	
	If Not ContactsManagerInternalCached.AreAddressManagementModulesAvailable() Then
		Return EEUCountries;
	EndIf;
	
	ModuleAddressManager = Common.CommonModule("AddressManager");
	ClassifierData = ModuleAddressManager.TableOfClassifier();
	
	For Each Country In ClassifierData Do
		If Country.EEUMember Then
			Filter = New Structure();
			Filter.Insert("Description", Country.Description);
			Filter.Insert("Code", Country.Code);
			Filter.Insert("DescriptionFull", Country.DescriptionFull);
			Filter.Insert("CodeAlpha2", Country.CodeAlpha2);
			Filter.Insert("CodeAlpha3", Country.CodeAlpha3);
			FoundRows = EEUCountries.FindRows(Filter);
			If FoundRows.Count() = 0 Then
				NewRow = EEUCountries.Add();
				FillPropertyValues(NewRow, Filter);
			EndIf;
		EndIf;
	EndDo;
	
	Return EEUCountries;

EndFunction

// Determines whether a country is the Eurasian Economic Union member (EAEU).
//
// Parameters:
//  Country - String
//         - CatalogRef.WorldCountries - a country code, code alpha2, code alpha3,
//                  country description, or a reference to an item of the World countries catalog.
// Returns:
//    Boolean - if True, a country is the EEU country member.
//
Function IsEEUMemberCountry(Country) Export
	
	If TypeOf(Country) = TypeOf(Catalogs.WorldCountries.EmptyRef()) Then
		Query = New Query;
		Query.Text = 
			"SELECT
			|	WorldCountries.EEUMember AS EEUMember
			|FROM
			|	Catalog.WorldCountries AS WorldCountries
			|WHERE
			|	WorldCountries.Ref = &Ref";
		
		Query.SetParameter("Ref", Country);
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			ResultString1 = QueryResult.Select();
			If ResultString1.Next() Then
				Return (ResultString1.EEUMember = True);
			EndIf;
		EndIf;
		
	Else
		FoundCountry =  WorldCountryByCodeOrDescription(Country);
		If ValueIsFilled(FoundCountry) Then
			Return Common.ObjectAttributeValue(FoundCountry, "EEUMember");
		EndIf;
		
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of form events and object module called upon the subsystem integration.

// OnCreateAtServer form event handler.
// Called from the module of contact information owner object form upon the subsystem integration.
//
// Parameters:
//    Form - ClientApplicationForm - an owner object form used for displaying contact information.
//    Object - CatalogRef
//           - DocumentRef
//           - CatalogObject
//           - DocumentObject - an owner object of contact information. 
//                              If it is a reference, contact information
//                              will be received from the object by reference, otherwise, from the ContactInformation table of the object.
//    AdditionalParameters - See ContactInformationParameters.
//                            - String - Obsolete.
//    DeleteCITitleLocation - FormItemTitleLocation - obsolete, use AdditionalParameters instead.
//    DeleteExcludedKinds - Array  - obsolete, use AdditionalParameters instead.
//    DeleteDeferredInitialization - Array - obsolete, use AdditionalParameters instead.
//
Procedure OnCreateAtServer(Form, Object, Val AdditionalParameters = Undefined, DeleteCITitleLocation = "",
	Val DeleteExcludedKinds = Undefined, DeleteDeferredInitialization = False) Export
	
	PremiseType = Undefined;
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		
		AdditionalParameters.Property("PremiseType", PremiseType);
		DeferredInitialization  = ?(AdditionalParameters.Property("DeferredInitialization"), AdditionalParameters.DeferredInitialization, False);
		CITitleLocation     = ?(AdditionalParameters.Property("CITitleLocation"), AdditionalParameters.CITitleLocation, "");
		ExcludedKinds          = ?(AdditionalParameters.Property("ExcludedKinds"), AdditionalParameters.ExcludedKinds, Undefined);
		HiddenKinds           = ?(AdditionalParameters.Property("HiddenKinds"), AdditionalParameters.HiddenKinds, Undefined);
		ItemForPlacementName = ?(AdditionalParameters.Property("ItemForPlacementName"), AdditionalParameters.ItemForPlacementName, "ContactInformationGroup");
		AllowAddingFields = ?(AdditionalParameters.Property("AllowAddingFields"), AdditionalParameters.AllowAddingFields, True);
		ItemsPlacedOnForm         = ?(AdditionalParameters.Property("ItemsPlacedOnForm"), AdditionalParameters.ItemsPlacedOnForm, Undefined);
		URLProcessing = ?(AdditionalParameters.Property("URLProcessing"), AdditionalParameters.URLProcessing, False);
	Else
		ItemForPlacementName = ?(AdditionalParameters = Undefined, "ContactInformationGroup", AdditionalParameters);
		DeferredInitialization  = DeleteDeferredInitialization;
		ExcludedKinds          = DeleteExcludedKinds;
		HiddenKinds           = Undefined;
		CITitleLocation     = DeleteCITitleLocation;
		AllowAddingFields = True;
		ItemsPlacedOnForm         = Undefined;
		URLProcessing = False;
	EndIf;
	
	If ExcludedKinds = Undefined Then
		ExcludedKinds = New Array;
	EndIf;
		
	If ItemsPlacedOnForm = Undefined Then
		ItemsPlacedOnForm = New Map;
		For Each KindToExclude In ExcludedKinds Do
			ItemsPlacedOnForm.Insert(KindToExclude, True);
		EndDo;
	Else
		ItemPlacedOnFormRefs = New Map();
		Kinds = ContactsManagerInternalCached.ContactInformationKindsByName();
		For Each ItemOnForm In ItemsPlacedOnForm Do
			If TypeOf(ItemOnForm.Key) = Type("String") Then
				ItemPlacedOnFormRefs.Insert(Kinds.Get(ItemOnForm.Key), True);
			Else	
				ItemPlacedOnFormRefs.Insert(ItemOnForm.Key, True);
			EndIf;
		EndDo;
		ItemsPlacedOnForm = ItemPlacedOnFormRefs;
	EndIf;
	
	If HiddenKinds = Undefined Then
		HiddenKinds = New Array;
	EndIf;
	
	AttributesToBeAdded = New Array;
	CheckContactInformationAttributesAvailability(Form, AttributesToBeAdded);
	
	// Caching of frequently used values
	ObjectReference             = Object.Ref;
	ObjectMetadata          = ObjectReference.Metadata();
	FullMetadataObjectName = ObjectMetadata.FullName();
	ObjectName                 = ObjectMetadata.Name;
	IsMainLanguage            = Common.IsMainLanguage();
	
	ContactInfoSettings = SubsystemSettings(Object.Ref);
	
	ContactInformationKindsGroup  = ObjectContactInformationKindsGroup(FullMetadataObjectName);
	ContactInformationUsed = Common.ObjectAttributeValue(ContactInformationKindsGroup, "Used");
	If ContactInformationUsed = False Then
		
		ContactInformationOutputParameters = New Structure();
		ContactInformationOutputParameters.Insert("ItemForPlacementName", ItemForPlacementName);
		ContactInformationOutputParameters.Insert("CITitleLocation", CITitleLocation);
		ContactInformationOutputParameters.Insert("DeferredInitialization", DeferredInitialization);
		ContactInformationOutputParameters.Insert("ExcludedKinds", ExcludedKinds);
		ContactInformationOutputParameters.Insert("HiddenKinds", HiddenKinds);
		ContactInformationOutputParameters.Insert("ObjectReference", ObjectReference);
		ContactInformationOutputParameters.Insert("DetailsOfCommands", ContactInfoSettings.DetailsOfCommands);
		ContactInformationOutputParameters.Insert("ShouldShowIcons", ContactInfoSettings.ShouldShowIcons);
		ContactInformationOutputParameters.Insert("ItemsPlacedOnForm", ItemsPlacedOnForm);
		ContactInformationOutputParameters.Insert("AllowAddingFields", AllowAddingFields);
		ContactInformationOutputParameters.Insert("URLProcessing", URLProcessing);
		ContactInformationOutputParameters.Insert("PositionOfAddButton", ContactInfoSettings.PositionOfAddButton);
		ContactInformationOutputParameters.Insert("CommentFieldWidth", ContactInfoSettings.CommentFieldWidth);
		
		HideContactInformation(Form, AttributesToBeAdded, ContactInformationOutputParameters);
		
		Return;
	EndIf;
	
	ContainsValidFrom = ContactsManagerInternalCached.ObjectContactInformationContainsValidFromColumn(ObjectReference);
	ObjectAttributes           = ObjectMetadata.TabularSections.ContactInformation.Attributes;
	HasColumnTabularSectionRowID = (ObjectAttributes.Find("TabularSectionRowID") <> Undefined);
	
	If Common.IsReference(TypeOf(Object)) Then
		QueryText = "SELECT
		|	ContactInformation.Presentation AS Presentation,
		|	ContactInformation.LineNumber AS LineNumber,
		|	ContactInformation.Kind AS Kind, 
		|	ISNULL(ContactInformationKinds.StoreChangeHistory, FALSE) AS StoreChangeHistory,
		|	ContactInformation.FieldValues,
		|	ContactInformation.Value,
		|	"""" AS ValidFrom,
		|	0 AS TabularSectionRowID,
		|	FALSE AS IsHistoricalContactInformation
		|FROM
		|	&PathToTheContactInformationTable AS ContactInformation
		|		LEFT JOIN Catalog.ContactInformationKinds AS ContactInformationKinds
		|			ON (ContactInformation.Kind = ContactInformationKinds.Ref)
		|WHERE
		|	ContactInformation.Ref = &Ref ORDER BY Kind, ValidFrom";

		QueryText = StrReplace(QueryText, "&PathToTheContactInformationTable", FullMetadataObjectName + ".ContactInformation");
		
		If HasColumnTabularSectionRowID Then
			QueryText = StrReplace(QueryText, "0 AS TabularSectionRowID",
			"ISNULL(ContactInformation.TabularSectionRowID, 0) AS TabularSectionRowID");
		EndIf;
		
		If ContainsValidFrom Then
			QueryText = StrReplace(QueryText, """"" AS ValidFrom", "ContactInformation.ValidFrom AS ValidFrom");
		EndIf;
		Query = New Query(QueryText);
		Query.SetParameter("Ref", ObjectReference);
		ContactInformation = Query.Execute().Unload();
	Else
		ContactInformation = Object.ContactInformation.Unload();
		
		If ContainsValidFrom Then
			BooleanType = New TypeDescription("Boolean");
			ContactInformation.Columns.Add("StoreChangeHistory", BooleanType);
			ContactInformation.Columns.Add("IsHistoricalContactInformation", BooleanType);
			ContactInformation.Sort("Kind, ValidFrom");
			
			ContactInfoKindsKeepChangeHistory = Common.ObjectsAttributeValue(
				ContactInformation.UnloadColumn("Kind"), "StoreChangeHistory");
			
			For Each ContactInformationRow In ContactInformation Do
				StoreChangeHistory = ContactInfoKindsKeepChangeHistory.Get(ContactInformationRow.Kind);
				ContactInformationRow.StoreChangeHistory = ?(StoreChangeHistory <> Undefined, StoreChangeHistory, False);
			EndDo;
		EndIf;
	EndIf;
	
	If ContainsValidFrom Then
		PreviousKind = Undefined;
		For Each ContactInformationRow In ContactInformation Do
			If ContactInformationRow.StoreChangeHistory
				And (PreviousKind = Undefined Or PreviousKind <> ContactInformationRow.Kind) Then
				Filter = New Structure("Kind", ContactInformationRow.Kind);
				FoundRows = ContactInformation.FindRows(Filter);
				LastDate = FoundRows.Get(FoundRows.Count() - 1).ValidFrom;
				For Each FoundRow In FoundRows Do
					If FoundRow.ValidFrom < LastDate Then
						FoundRow.IsHistoricalContactInformation = True;
					EndIf;
				EndDo;
				PreviousKind = ContactInformationRow.Kind;
			EndIf;
		EndDo;
		HasHistoricalInformation = True;
	Else
		HasHistoricalInformation = False;
	EndIf;
	
	QueryText = GenerateQueryText(HasColumnTabularSectionRowID, HasHistoricalInformation, IsMainLanguage);
	
	Query = New Query(QueryText);
	Query.SetParameter("ContactInformationTable1", ContactInformation);
	Query.SetParameter("CIKindsGroup", ContactInformationKindsGroup);
	Query.SetParameter("Owner", ObjectReference);
	Query.SetParameter("HiddenKinds", HiddenKinds);
	If Not IsMainLanguage Then
		Query.SetParameter("IsMainLanguage", IsMainLanguage);
		Query.SetParameter("LanguageCode", CurrentLanguage().LanguageCode);
	EndIf;
	
	SetPrivilegedMode(True);
	ContactInformation = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy).Rows;
	SetPrivilegedMode(False);
	
	ContactInformationConvertionToJSON(ContactInformation);
	
	ContactInformation.Sort("AddlOrderingAttribute, LineNumber");
	GenerateContactInformationAttributes(Form, AttributesToBeAdded, ObjectName, ItemsPlacedOnForm, ContactInformation, 
		DeferredInitialization, URLProcessing);
	
	AdditionalParameters = AdditionalParametersOfContactInfoOutput(ContactInfoSettings.DetailsOfCommands,
		ContactInfoSettings.ShouldShowIcons, ItemsPlacedOnForm, AllowAddingFields, ExcludedKinds, HiddenKinds);
	AdditionalParameters.PositionOfAddButton = ContactInfoSettings.PositionOfAddButton;
	AdditionalParameters.CommentFieldWidth = ContactInfoSettings.CommentFieldWidth;
	
	ContactInformationParameters = ContactInformationOutputParameters(Form, ItemForPlacementName,
		CITitleLocation, DeferredInitialization, AdditionalParameters);
	ContactInformationParameters.Owner                     = ObjectReference;
	If ValueIsFilled(PremiseType) Then
		ContactInformationParameters.AddressParameters.PremiseType = PremiseType;
	EndIf;
	ContactInformationParameters.URLProcessing = URLProcessing;
	
	Filter = New Structure("Type", Enums.ContactInformationTypes.Address);
	AddressesCount = ContactInformation.FindRows(Filter).Count();
	
	// Creating form items, filling in the attribute values.
	CreatedItems = Common.CopyRecursive(ItemsPlacedOnForm);
	PreviousKind = Undefined;
	
	If Common.IsMobileClient() Then
		Form.Items[ItemForPlacementName].TitleFont = StyleFonts.ImportantLabelFont;
	EndIf;
	
	GroupName = "GroupContactInfoCommandVals" + ItemForPlacementName;
	GroupContactInfoCommandVals = Form.Items.Find(GroupName);
		
	If GroupContactInfoCommandVals = Undefined Then
		Parent = Parent(Form, ItemForPlacementName);
		GroupContactInfoCommandVals = Form.Items.Add(GroupName, Type("FormGroup"), Parent);
		GroupContactInfoCommandVals.Type = FormGroupType.UsualGroup;
		GroupContactInfoCommandVals.Title = NStr("en = 'Contact information values';");
		GroupContactInfoCommandVals.ShowTitle = False;
		GroupContactInfoCommandVals.EnableContentChange = False;
		GroupContactInfoCommandVals.Representation = UsualGroupRepresentation.None;
		GroupContactInfoCommandVals.Group = ChildFormItemsGroup.Vertical;
		GroupContactInfoCommandVals.HorizontalAlignInGroup = ItemHorizontalLocation.Right;
		GroupContactInfoCommandVals.HorizontalStretch = False;
		GroupContactInfoCommandVals.United = False;
	EndIf;
			
	GroupName = "GroupOfContactInfoValues" + ItemForPlacementName;
	GroupOfContactInfoValues = Form.Items.Find(GroupName);
	
	If GroupOfContactInfoValues = Undefined Then
		GroupOfContactInfoValues = Form.Items.Add(GroupName, Type("FormGroup"), GroupContactInfoCommandVals);
		GroupOfContactInfoValues.Type = FormGroupType.UsualGroup;
		GroupOfContactInfoValues.Title = NStr("en = 'Contact information values and commands';");
		GroupOfContactInfoValues.ShowTitle = False;
		GroupOfContactInfoValues.EnableContentChange = False;
		GroupOfContactInfoValues.Representation = UsualGroupRepresentation.None;
		GroupOfContactInfoValues.Group = ChildFormItemsGroup.Vertical;
	EndIf;
		
	For Each CIRow In ContactInformation Do
		
		ContactInformationKindData = Common.ValueTableRowToStructure(CIRow);
			
		If CIRow.IsTabularSectionAttribute Then
			CreateTabularSectionItems(Form, ObjectName, ItemForPlacementName, CIRow, ContactInformationKindData);
			Continue;
		EndIf;
		
		If CIRow.DeletionMark And IsBlankString(CIRow.FieldValues) And IsBlankString(CIRow.Value) Then
			Continue;
		EndIf;
		
		CreatedElement = ?(Not CIRow.IsHistoricalContactInformation,
			CreatedItems.Get(CIRow.Kind), Undefined);
		
		If CreatedElement <> Undefined Then
			CreatedElement = CIRow.Kind;
		EndIf;
		StaticItem = CreatedElement <> Undefined;
		IsNewCIKind      = (CIRow.Kind <> PreviousKind);
		
		If Not CIRow.IsHistoricalContactInformation  Then
			PreviousKind = CIRow.Kind;
		EndIf;
		
		If Not CIRow.IsAlwaysDisplayed And IsBlankString(CIRow.Value) And Not StaticItem Then
			If IsNewCIKind And Not CIRow.DeletionMark Then
				Kind = CIRow.Kind; // CatalogRef.ContactInformationKinds
				ContactInformationKindData.Insert("Ref", CIRow.Kind);
				If Common.IsMobileClient() Then
					ContactInformationParameters.ItemsToAddList.Add(ContactInformationKindData, String(Kind));
				Else
					ImageOfType = PictureContactInfoType(ContactInformationKindData.Type);
					ContactInformationParameters.ItemsToAddList.Add(ContactInformationKindData, String(Kind),,ImageOfType);
				EndIf;
			EndIf;
			Continue;
		EndIf;
		
		If DeferredInitialization Then
			
			AddAttributeToDetails(Form, CIRow, ContactInformationKindData, IsNewCIKind,, 
				StaticItem, ItemForPlacementName);
			If StaticItem Then
				PrepareStaticItem(Form, CIRow, CreatedItems, CreatedElement,
					ContactInformationParameters.ShouldShowIcons, ItemForPlacementName);
			EndIf;
			Continue;
		EndIf;
		
		AddAttributeToDetails(Form, CIRow, ContactInformationKindData, IsNewCIKind,, 
			Not CIRow.IsHistoricalContactInformation, ItemForPlacementName);
		
		If StaticItem Then
			PrepareStaticItem(Form, CIRow, CreatedItems, CreatedElement, 
				ContactInformationParameters.ShouldShowIcons, ItemForPlacementName);
		Else
			NextRow = ?(CreatedItems.Count() = 0, Undefined,
				DefineNextString(Form, ContactInformation, CIRow));
			
			If Not CIRow.IsHistoricalContactInformation Then
				AddContactInformationRow(Form, CIRow, ItemForPlacementName, IsNewCIKind, AddressesCount, NextRow);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	UpdateConextMenu(Form, ItemForPlacementName);
	
	If AccessRight("Update",Metadata.Catalogs.ContactInformationKinds) Then
		ContactInformationParameters.ItemsToAddList.Add(New Structure("Ref",
			Catalogs.ContactInformationKinds.EmptyRef()), NStr("en = 'Configure…';"));
	EndIf;
	
	If Not DeferredInitialization And AllowAddingFields
		And Form.ContactInformationParameters[ItemForPlacementName].ItemsToAddList.Count() > 0 Then
		AddAdditionalContactInformationFieldButton(Form, ItemForPlacementName);
	Else
		AddNoteOnFormSettingsReset(Form, ItemForPlacementName, DeferredInitialization);
	EndIf;
	
EndProcedure

// OnReadAtServer form event handler.
// Called from the module of contact information owner object form upon the subsystem integration.
//
// Parameters:
//    Form  - ClientApplicationForm - an owner object form used for displaying contact information.
//    Object - CatalogRef
//           - DocumentRef
//           - CatalogObject
//           - DocumentObject - an owner object of contact information.
//    ItemForPlacementName - String - the group, to which contact information items will be placed.
//
Procedure OnReadAtServer(Form, Object, ItemForPlacementName = "ContactInformationGroup") Export
	
	FormAttributeList = Form.GetAttributes();
	
	FirstRun = True;
	For Each Attribute In FormAttributeList Do
		If Attribute.Name = "ContactInformationParameters" And TypeOf(Form.ContactInformationParameters) = Type("Structure") Then
			FirstRun = False;
			Break;
		EndIf;
	EndDo;
	
	If FirstRun Then
		Return;
	EndIf;
	
	Parameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
	
	ObjectReference = Object.Ref;
	ObjectMetadata = ObjectReference.Metadata();
	FullMetadataObjectName = ObjectMetadata.FullName();
	CIKindsGroupName = StrReplace(FullMetadataObjectName, ".", "");
	CIKindsGroup = ContactInformationKindByName(CIKindsGroupName);
	ItemForPlacementName = Parameters.GroupForPlacement;
	
	CITitleLocation = ?(ValueIsFilled(Parameters.TitleLocation), PredefinedValue(Parameters.TitleLocation), FormItemTitleLocation.Left);
	DeferredInitializationExecuted = Parameters.DeferredInitializationExecuted;
	DeferredInitialization = Parameters.DeferredInitialization And Not DeferredInitializationExecuted;
	
	ContactInformationUsed = Common.ObjectAttributeValue(CIKindsGroup, "Used");
	If ContactInformationUsed = False Then
		AttributesToDeleteArray = Parameters.AddedAttributes;
	Else
		DeleteFormItemsAndCommands(Form, ItemForPlacementName);
		
		AttributesToDeleteArray = New Array;
		ObjectName = Object.Ref.Metadata().Name;
		
		StaticAttributes = Common.CopyRecursive(Parameters.ItemsPlacedOnForm);
		TabularSectionsNamesByCIKinds = Undefined;
		
		Filter = New Structure("ItemForPlacementName", ItemForPlacementName);
		ContactInformationAdditionalAttributesDetails = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).FindRows(Filter);
		For Each FormAttribute In ContactInformationAdditionalAttributesDetails Do
			
			If FormAttribute.IsTabularSectionAttribute Then
				
				If TabularSectionsNamesByCIKinds = Undefined Then
					Filter = New Structure("IsTabularSectionAttribute", True);
					TabularSectionCIKinds = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).Unload(Filter, "Kind");
					// @skip-check query-in-loop - Runs only in one iteration when the table attribute first appears
					TabularSectionsNamesByCIKinds = TabularSectionsNamesByCIKinds(TabularSectionCIKinds, ObjectName);
				EndIf;
				
				TabularSectionName = TabularSectionsNamesByCIKinds[FormAttribute.Kind];
				AttributesToDeleteArray.Add("Object." + TabularSectionName + "." + FormAttribute.AttributeName);
				AttributesToDeleteArray.Add("Object." + TabularSectionName + "." + FormAttribute.AttributeName + "Value");
				
			ElsIf Not FormAttribute.Property("IsHistoricalContactInformation")
				Or Not FormAttribute.IsHistoricalContactInformation Then
				
				StaticAttribute = StaticAttributes.Get(FormAttribute.Kind);
				If StaticAttribute <> Undefined Then
					StaticAttribute = FormAttribute.Kind;
				EndIf;
				
				If StaticAttribute = Undefined Then // Attribute is created dynamically.
					If Not DeferredInitialization And ValueIsFilled(FormAttribute.AttributeName) Then
						AttributesToDeleteArray.Add(FormAttribute.AttributeName);
						If HasCommentFieldForContactInfoType(FormAttribute.Type, Parameters.URLProcessing) Then
							AttributesToDeleteArray.Add("Comment" + FormAttribute.AttributeName);
						EndIf;	
					EndIf;
				Else
					StaticAttributes.Delete(StaticAttribute);
				EndIf;
				
			EndIf;
		EndDo;
		For Each FormAttribute In ContactInformationAdditionalAttributesDetails Do
			ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).Delete(FormAttribute);
		EndDo;
		Filter = New Structure("IsHistoricalContactInformation",True);
		HistoricalContactInfo = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).FindRows(Filter);
		For Each CollectionItem In HistoricalContactInfo Do
			ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).Delete(CollectionItem);
		EndDo;
	EndIf;
	Form.ChangeAttributes(, AttributesToDeleteArray);
	
	AdditionalParameters = ContactInformationParameters();
	FillPropertyValues(AdditionalParameters, Parameters);
	AdditionalParameters.ItemForPlacementName = ItemForPlacementName;
	AdditionalParameters.CITitleLocation = CITitleLocation;
	AdditionalParameters.DeferredInitialization = DeferredInitialization;
	OnCreateAtServer(Form, Object, AdditionalParameters);
	
	Parameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
	Parameters.DeferredInitializationExecuted = DeferredInitializationExecuted;
	
EndProcedure

// AfterWriteAtServer form event handler.
// Called from the module of contact information owner object form upon the subsystem integration.
//
// Parameters:
//    Form  - ClientApplicationForm - an owner object form used for displaying contact information.
//    Object - CatalogRef
//           - DocumentRef
//           - CatalogObject
//           - DocumentObject - an owner object of contact information.
//
Procedure AfterWriteAtServer(Form, Object) Export
	
	ObjectName = Object.Ref.Metadata().Name;
	
	// Only for contact information of the tabular section.
	Filter = New Structure("IsTabularSectionAttribute", True);
	TabularSectionRows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).Unload(Filter);
	TabularSectionsNamesByCIKinds = TabularSectionsNamesByCIKinds(TabularSectionRows, ObjectName);
	
	For Each TableRow In TabularSectionRows Do
		InformationKind = TableRow.Kind;
		AttributeName = TableRow.AttributeName;
		FormTabularSection = Form.Object[TabularSectionsNamesByCIKinds[InformationKind]];
		
		For Each FormTabularSectionRow In FormTabularSection Do
			
			Filter = New Structure;
			Filter.Insert("Kind", InformationKind);
			Filter.Insert("TabularSectionRowID", FormTabularSectionRow.TabularSectionRowID);
			FoundRows = Object.ContactInformation.FindRows(Filter);
			
			If FoundRows.Count() = 1 Then
				
				CIRow = FoundRows[0];
				FormTabularSectionRow[AttributeName] = CIRow.Presentation;
				FormTabularSectionRow[AttributeName + "Value"] = CIRow.Value;
				
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

// FillCheckProcessingAtServer form event handler.
// Called from the module of contact information owner object form upon the subsystem integration.
//
// Parameters:
//    Form  - ClientApplicationForm - an owner object form used for displaying contact information.
//    Object - CatalogRef
//           - DocumentRef
//           - CatalogObject
//           - DocumentObject - an owner object of contact information.
//    Cancel  - Boolean - if True, errors were detected during the check.
//
Procedure FillCheckProcessingAtServer(Form, Object, Cancel) Export
	
	SessionParameters.ContactInformationFillingInteractiveCheck = True;
	
	ObjectName = Object.Ref.Metadata().Name;
	ErrorsLevel = 0;
	PreviousKind = Undefined;
	
	TabularSectionsNamesByCIKinds = Undefined;
	
	For Each TableRow In ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form) Do
		
		InformationKind = TableRow.Kind;
		InformationType = TableRow.Type;
		Comment   = TableRow.Comment;
		AttributeName  = TableRow.AttributeName;
		InformationKindProperty = Common.ObjectAttributesValues(InformationKind, "Mandatory, EditingOption");
		Mandatory = InformationKindProperty.Mandatory;
		
		If TableRow.IsTabularSectionAttribute Then
			
			If TabularSectionsNamesByCIKinds = Undefined Then
				Filter = New Structure("IsTabularSectionAttribute", True);
				TabularSectionCIKinds = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).Unload(Filter , "Kind");
				// @skip-check query-in-loop - Runs only in one iteration when the table attribute first appears
				TabularSectionsNamesByCIKinds = TabularSectionsNamesByCIKinds(TabularSectionCIKinds, ObjectName);
			EndIf;
			
			TabularSectionName = TabularSectionsNamesByCIKinds[InformationKind];
			FormTabularSection = Form.Object[TabularSectionName];
			
			For Each FormTabularSectionRow In FormTabularSection Do
				
				Presentation = FormTabularSectionRow[AttributeName];
				Field = "Object." + TabularSectionName + "[" + XMLString((FormTabularSectionRow.LineNumber - 1)) + "]." + AttributeName;
				
				If Mandatory And IsBlankString(Presentation) And Not InformationKind.DeletionMark Then
					
					Common.MessageToUser(
					StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Field ""%1"" is required.';"), InformationKind.Description),,Field);
					CurrentErrorsLevel = 2;
					
				Else
					
					Value = FormTabularSectionRow[AttributeName + "Value"];
					
					CurrentErrorsLevel = CheckContactInformationFilling(Presentation, Value, InformationKind,
						InformationType, AttributeName, , Field);
					
					FormTabularSectionRow[AttributeName] = Presentation;
					FormTabularSectionRow[AttributeName + "Value"] = Value;
					
				EndIf;
				
				ErrorsLevel = ?(CurrentErrorsLevel > ErrorsLevel, CurrentErrorsLevel, ErrorsLevel);
				
			EndDo;
			
		Else
			
			FormItem = Form.Items.Find(AttributeName);
			If FormItem = Undefined Or InformationKind.DeletionMark Then
				Continue; // Item was not created. Deferred initialization wasn't called.
			EndIf;
			
			If (InformationKindProperty.EditingOption = "Dialog"
				Or InformationType = Enums.ContactInformationTypes.WebPage)
				And Not ContactsManagerClientServer.ContactsFilledIn(String(Form[AttributeName])) Then
				Presentation = "";
			Else
				Presentation = Form[AttributeName];
			EndIf;
			
			If InformationKind <> PreviousKind And Mandatory And IsBlankString(Presentation)
				And Not HasOtherRowsFilledWithThisContactInformationKind(Form, TableRow, InformationKind) Then
				// And no other strings with data for contact information kinds with multiple values.
				
				Common.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Field ""%1"" is required.';"), InformationKind.Description),,, AttributeName);
				CurrentErrorsLevel = 2;
				
			Else
				
				CurrentErrorsLevel = CheckContactInformationFilling(Presentation, TableRow.Value,
					InformationKind, InformationType, AttributeName, Comment);
				
			EndIf;
			
			ErrorsLevel = ?(CurrentErrorsLevel > ErrorsLevel, CurrentErrorsLevel, ErrorsLevel);
			
		EndIf;
		
		PreviousKind = InformationKind;
		
	EndDo;
	
	If ErrorsLevel <> 0 Then
		Cancel = True;
	EndIf;
	
EndProcedure

// BeforeWriteAtServer form event handler.
// Called from the module of contact information owner object form upon the subsystem integration.
//
// Parameters:
//    Form  - ClientApplicationForm - an owner object form used for displaying contact information.
//    Object - CatalogObject
//           - DocumentRef - an owner object of contact information.
//             FormStructureData - an object containing a tabular section with contact information. Supports
//                              hidden kinds of contact information only for already existing objects
//                              as it is impossible to set a reference for a new object.
//    Cancel  - Boolean - if True, the object was not written as errors occurred while recording.
//
Procedure BeforeWriteAtServer(Form, Object, Cancel = False) Export
	
	ContactInformation = ContactInformationFromFormAttributes(Form, Object);
	
	IsMainObjectParameters  = True;
	ContactInformationParameters = Undefined;
	HiddenKinds                = New Array;
	
	DefineContactInformationParametersByOwner(Form, Object, ContactInformationParameters, IsMainObjectParameters, HiddenKinds);
	
	If Object.Ref.IsEmpty() And TypeOf(Object) <> Type("FormDataStructure") Then
		
		If IsMainObjectParameters Then
			
			NewRef = Object.GetNewObjectRef();
			ObjectManager = Common.ObjectManagerByRef(Object.Ref);
			If NewRef = ObjectManager.EmptyRef() Then
				Object.SetNewObjectRef(ObjectManager.GetRef());
			EndIf;
			ContactInformationParameters.Owner = Object.GetNewObjectRef();
			
		Else
			Return;
		EndIf;
		
	EndIf;
	
	If HiddenKinds.Count() = 0 Then
		Object.ContactInformation.Clear();
	Else
		
		IndexOf = Object.ContactInformation.Count() -1;
		While IndexOf >= 0 Do
			TableRow = Object.ContactInformation.Get(IndexOf);
			If HiddenKinds.Find(TableRow.Kind) = Undefined Then
				Object.ContactInformation.Delete(TableRow);
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		
	EndIf;
	
	SetObjectContactInformation(Object, ContactInformation);
	
EndProcedure

// Adds (deletes) an input field or a comment to a form, updating data.
// Called from the form module of the contact information owner object.
//
// Parameters:
//    Form     - ClientApplicationForm - an owner object form used for displaying contact information.
//    Object    - FormDataStructure - an owner object of contact information.
//    Result - Undefined - an optional internal attribute received from the previous event handler.
//              - Structure: - A dynamic property set:
//      * ReorderItems - Boolean - if item values are swapped.
//      * TheFirstControl - String - if item values are swapped.
//      * TheSecondControl - String - if item values are swapped.
//      * UpdateConextMenu - Boolean -  upon context menu update
//      * AttributeName - String - if menu update is in progress
//      * KindToAdd - Boolean - upon adding a new item
//      * IsCommentAddition - Boolean - upon adding a comment
//      * UpdateConextMenu - Boolean - upon context menu update
//      * ItemForPlacementName - String -  if adds a new item, comment, or context menu is being updated
//      * Comment - String - upon context menu update
//       * Reread  - Boolean - Identifies whether the contact information should be updated within the element for placing.
//
// Returns:
//    Undefined - a value is not used, backward compatibility.
//
Function UpdateContactInformation(Form, Object, Result = Undefined) Export
	
	If Result = Undefined Then
		Return Undefined;
	EndIf;
	
	If Result.Property("IsCommentAddition") Then
		ModifyComment(Form, Result.AttributeName, Result.ItemForPlacementName, Result.ContactInformationType);
	ElsIf Result.Property("KindToAdd") Then
		AddContactInformationRow(Form, Result, Result.ItemForPlacementName);	
	ElsIf Result.Property("ReorderItems") Then
		
		Filter = New Structure("AttributeName", Result.TheFirstControl);
		ContactInformationDetails = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form);
		TheFirstControl = ContactInformationDetails.FindRows(Filter)[0];
		Filter = New Structure("AttributeName", Result.TheSecondControl);
		TheSecondControl = ContactInformationDetails.FindRows(Filter)[0];
		
		PropertiesToTransferList = "Comment,Presentation,Value";
		TemporaryBuffer = New Structure(PropertiesToTransferList);
		
		FillPropertyValues(TemporaryBuffer, TheFirstControl);
		FillPropertyValues(TheFirstControl, TheSecondControl, PropertiesToTransferList);
		FillPropertyValues(TheSecondControl, TemporaryBuffer);
		
		ContactInformationParameters = FormContactInformationParameters(Form.ContactInformationParameters, 
			Result.ItemForPlacementName);
		URLProcessing = ContactInformationParameters.URLProcessing;

		IsAddressAsHyperlink = TheFirstControl.Type = Enums.ContactInformationTypes.Address And TypeOf(
			Form.Items[Result.TheFirstControl].ExtendedTooltip.Title) = Type("FormattedString");

		If TheFirstControl.Type = Enums.ContactInformationTypes.WebPage And URLProcessing Then
			Form[Result.TheFirstControl] = ContactsManagerClientServer.WebsiteAddress(
				TheFirstControl.Presentation, TheFirstControl.Value, Form.ReadOnly);
			Form[Result.TheSecondControl] = ContactsManagerClientServer.WebsiteAddress(
				TheSecondControl.Presentation, TheSecondControl.Value, Form.ReadOnly);
		ElsIf IsAddressAsHyperlink Then
			Form[Result.TheFirstControl] = ?(ValueIsFilled(TheFirstControl.Presentation), TheFirstControl.Presentation,
				ContactsManagerClientServer.BlankAddressTextAsHyperlink());
			Form[Result.TheSecondControl] =  ?(ValueIsFilled(TheSecondControl.Presentation), TheSecondControl.Presentation,
				ContactsManagerClientServer.BlankAddressTextAsHyperlink());				
		Else
			Form[Result.TheFirstControl] = TheFirstControl.Presentation;
			Form[Result.TheSecondControl] = TheSecondControl.Presentation;
		EndIf;
				
		If HasCommentFieldForContactInfoType(TheFirstControl.Type, URLProcessing) Then
			Form["Comment" + Result.TheFirstControl] = TheFirstControl.Comment; 
			Form["Comment" + Result.TheSecondControl] = TheSecondControl.Comment;	
		ElsIf IsAddressAsHyperlink Then
		 	CommandsForOutput = ContactsManagerClientServer.CommandsToOutputToForm(
				ContactInformationParameters, TheFirstControl.Type, TheFirstControl.Kind, TheFirstControl.StoreChangeHistory);
			
			FirstItemComment = Form.Items[Result.TheFirstControl]; // FormDecoration
			FirstItemComment.ExtendedTooltip.Title = ContactsManagerClientServer.ExtendedTooltipForAddress(
				CommandsForOutput, TheFirstControl.Presentation, TheFirstControl.Comment);
			
			SecondItemComment = Form.Items[Result.TheSecondControl]; // FormDecoration
			SecondItemComment.ExtendedTooltip.Title = ContactsManagerClientServer.ExtendedTooltipForAddress(
				CommandsForOutput, TheSecondControl.Presentation, TheSecondControl.Comment);
		Else	
			FirstItemComment = Form.Items[Result.TheFirstControl]; // FormDecoration
			FirstItemComment.ExtendedTooltip.Title = TheFirstControl.Comment;
			SecondItemComment = Form.Items[Result.TheSecondControl]; // FormDecoration
			SecondItemComment.ExtendedTooltip.Title = TheSecondControl.Comment;
		EndIf;
		
	EndIf;
	
	If Result.Property("UpdateConextMenu") Then
		If Result.Property("ItemForPlacementName") Then
			UpdateConextMenu(Form, Result.ItemForPlacementName);
			
			If Result.Property("AttributeName") Then
				ContactInformationDetails = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form);
				Filter = New Structure("AttributeName", Result.AttributeName);
				FoundRow = ContactInformationDetails.FindRows(Filter)[0];
				If ContactsManagerClientServer.IsJSONContactInformation(FoundRow.Value) Then
					ContactInformationByFields = ContactsManagerInternal.JSONToContactInformationByFields(FoundRow.Value, Undefined);
					If Result.Property("Comment") Then
						ContactInformationByFields.Comment = Result.Comment;
					Else 
						ContactInformationByFields.Comment = "";
					EndIf;
					FoundRow.Value = ContactsManagerInternal.ToJSONStringStructure(ContactInformationByFields);
				EndIf;
			EndIf;
			
		Else
			For Each PlacementItemName In Form.ContactInformationParameters Do
				UpdateConextMenu(Form, PlacementItemName.Key);
			EndDo;
		EndIf;
	EndIf;
	
	If Result.Property("Reread") And Result.Property("ItemForPlacementName") Then
		ContactInformationParameters = FormContactInformationParameters(Form.ContactInformationParameters, 
		Result.ItemForPlacementName);
		
		CopyOfContactInfoDetails = Form.FormAttributeToValue("ContactInformationAdditionalAttributesDetails", Type("ValueTable"));
		
		OnReadAtServer(Form, ContactInformationParameters.Owner, Result.ItemForPlacementName);
		
		ContactInformationDetails = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form);
		CIKindsWithHistory = New Array();
		For Each TableRow In ContactInformationDetails Do
			If Not ValueIsFilled(TableRow.AttributeName) Then
				Continue;
			EndIf;
			Filter = New Structure("AttributeName", TableRow.AttributeName);
			FoundRows = CopyOfContactInfoDetails.FindRows(Filter);
			If FoundRows.Count() > 0 Then
				FoundRow = FoundRows[0];
				If TableRow.Comment <> FoundRow.Comment And HasCommentFieldForContactInfoType(
					TableRow.Type, ContactInformationParameters.URLProcessing) Then
					Form["Comment"+TableRow.AttributeName] =  FoundRow.Comment;
				EndIf;
				TableRow.ValidFrom = FoundRow.ValidFrom;
				If TableRow.Value <> FoundRow.Value Then
					TableRow.Value      =  FoundRow.Value;
					TableRow.Presentation =  FoundRow.Presentation;
					TableRow.Comment   =  FoundRow.Comment;
					Form[TableRow.AttributeName] = FoundRow.Presentation;
					IsAddressAsHyperlink = TableRow.Type = Enums.ContactInformationTypes.Address And TypeOf(
						Form.Items[TableRow.AttributeName].ExtendedTooltip.Title) = Type("FormattedString");
					If IsAddressAsHyperlink Then
						Form[TableRow.AttributeName] = ?(ValueIsFilled(FoundRow.Presentation),
							FoundRow.Presentation,
							ContactsManagerClientServer.BlankAddressTextAsHyperlink());
							
						CommandsForOutput = ContactsManagerClientServer.CommandsToOutputToForm(
							ContactInformationParameters, TableRow.Type, TableRow.Kind, TableRow.StoreChangeHistory);		
						Form.Items[TableRow.AttributeName].ExtendedTooltip.Title = 
							ContactsManagerClientServer.ExtendedTooltipForAddress(
								CommandsForOutput, TableRow.Presentation, TableRow.Comment);	
					Else
						Form[TableRow.AttributeName] = FoundRow.Presentation;
						Form.Items[TableRow.AttributeName].ExtendedTooltip.Title = TableRow.Comment;
					EndIf;						
				EndIf;
			EndIf;
			If TableRow.StoreChangeHistory Then
				If CIKindsWithHistory.Find(TableRow.Kind) = Undefined Then
					CIKindsWithHistory.Add(TableRow.Kind);
				EndIf;
			EndIf;
		EndDo;
		For Each Kind In CIKindsWithHistory Do
			HistoricalContactInfo = CopyOfContactInfoDetails.FindRows(New Structure("IsHistoricalContactInformation, Kind", True, Kind));
			For Each CIRow In HistoricalContactInfo Do
				Filter = New Structure("Value, IsHistoricalContactInformation, ValidFrom",
				CIRow.Value, CIRow.IsHistoricalContactInformation, CIRow.ValidFrom);
				FoundRows = ContactInformationDetails.FindRows(Filter);
				If FoundRows.Count() = 0 Then
					AddressHistoryItem = ContactInformationDetails.Add();
					FillPropertyValues(AddressHistoryItem, CIRow);
				EndIf;
			EndDo;
		EndDo;
		
	EndIf;
		
	Return Undefined;
	
EndFunction

// FillingProcessing event subscription handler.
//
// Parameters:
//  Source             - CatalogObject
//                       - DocumentObject - an object containing contact information.
//  FillingData     - Structure - data with contact information to fill in the object.
//  FillingText      - String - not used.
//  StandardProcessing - Boolean - not used.
//
Procedure FillContactInformationProcessing(Source, FillingData, FillingText, StandardProcessing) Export
	
	ObjectContactInformationFillingProcessing(Source, FillingData);
	
EndProcedure

// The BeforeWrite event subscription handler for updating contact information for lists.
//
// Parameters:
//  Object - Arbitrary - an object containing contact information.
//  Cancel  - Boolean       - not used, backward compatibility.
//
Procedure ProcessingContactsUpdating(Object, Cancel) Export
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
	UpdateContactInformationForLists(Object);
	
EndProcedure

// FillingProcessing event subscription handler for documents.
//
// Parameters:
//  Source             - Arbitrary         - an object containing contact information.
//  FillingData     - Structure            - data with contact information to fill in the object.
//  FillingText      - String
//                       - Undefined - filling data of the Description attribute.
//  StandardProcessing - Boolean               - not used.
//
Procedure DocumentContactInformationFilling(Source, FillingData, FillingText, StandardProcessing) Export
	
	ObjectContactInformationFillingProcessing(Source, FillingData);
	
EndProcedure

// Executes deferred initialization of attributes and contact information items.
//
// Parameters:
//  Form                    - ClientApplicationForm - an owner object form used for displaying
//                                                          contact information.
//  Object                   - Arbitrary - an owner object of contact information.
//  ItemForPlacementName - String - a group name where the contact information is placed.
//
Procedure ExecuteDeferredInitialization(Form, Object, ItemForPlacementName = "ContactInformationGroup") Export
	
		ContactInformationStub = Form.Items.Find("ContactInformationStub"); // A temporary item
	If ContactInformationStub <> Undefined Then
		Form.Items.Delete(ContactInformationStub);
	EndIf;
	
	ContactInformationParameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
	
	ContactInformationAdditionalAttributesDetails = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).Unload(,
		"Kind, Presentation, Value, Comment, AttributeName");
	ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).Clear();
	
	CITitleLocation = ?(ValueIsFilled(ContactInformationParameters.TitleLocation), 
		PredefinedValue(ContactInformationParameters.TitleLocation), FormItemTitleLocation.Left);
	
	AdditionalContactInformationParameters = ContactInformationParameters();
	AdditionalContactInformationParameters.ItemForPlacementName = ItemForPlacementName;
	AdditionalContactInformationParameters.CITitleLocation = CITitleLocation;
	AdditionalContactInformationParameters.ItemsPlacedOnForm = ContactInformationParameters.ItemsPlacedOnForm;
	
	OnCreateAtServer(Form, Object, AdditionalContactInformationParameters);
	ContactInformationParameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
	
	For Each ContactInformationKind In ContactInformationParameters.ItemsPlacedOnForm Do
		
		Filter = New Structure("Kind", ContactInformationKind.Key);
		RowsArray = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).FindRows(Filter);
		
		For Each CurrentValue In RowsArray Do 
			If IsBlankString(CurrentValue.AttributeName) Then
				Continue;
			EndIf;

			Filter = New Structure("AttributeName",CurrentValue.AttributeName);
			StoredValues = ContactInformationAdditionalAttributesDetails.FindRows(Filter);
			
			If StoredValues.Count() = 0 Then
				Continue;
			EndIf;
			
			SavedValue = StoredValues[0];
			
			If SavedValue <> Undefined And IsBlankString(SavedValue.Value)
				And IsBlankString(SavedValue.Comment) Then
				Continue;
			EndIf;
			
			FillPropertyValues(CurrentValue, SavedValue);
			Form[CurrentValue.AttributeName] = SavedValue.Presentation;
		EndDo;
		
	EndDo;
	
	If Form.Items.Find("EmptyDecorationContactInformation") <> Undefined Then
		Form.Items.EmptyDecorationContactInformation.Visible = False;
	EndIf;
	
	ContactInformationParameters.DeferredInitializationExecuted = True;

	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary functions and constructors.

// Returns the object contact information kinds being used.
//
// Parameters:
//  ContactInformationOwner - CatalogRef.ContactInformationKinds
//                               - CatalogObject.ContactInformationKinds
//                               - FormDataStructure:
//                                 * Ref - CatalogRef.ContactInformationKinds - a reference to a CI kind.
//  ContactInformationType - EnumRef.ContactInformationTypes - CI kind filter by type.
//
// Returns:
//  ValueTable - Contact information kinds, where:
//    * Ref  - CatalogRef.ContactInformationKinds
//    * Type - EnumRef.ContactInformationTypes
//    * Presentation - String
//    * Description - String
//    * AllowMultipleValueInput - Boolean
//    * AddlOrderingAttribute - Number
//    * Mandatory - Boolean
//    * CheckValidity - Boolean
//    * IDForFormulas - String
//    * PredefinedKindName - String
//
Function ObjectContactInformationKinds(ContactInformationOwner, ContactInformationType = Undefined) Export
	
	If TypeOf(ContactInformationOwner) = Type("FormDataStructure") Then
		RefType = TypeOf(ContactInformationOwner.Ref)
	ElsIf Common.IsReference(TypeOf(ContactInformationOwner)) Then
		RefType = TypeOf(ContactInformationOwner);
	Else
		RefType = TypeOf(ContactInformationOwner.Ref)
	EndIf;
	
	CatalogMetadata = Metadata.FindByType(RefType);
	If CatalogMetadata <> Undefined Then
		CIKindsGroup = ContactsManagerInternalCached.ContactInformationKindGroupByObjectName(
			CatalogMetadata.FullName());
	Else
		CIKindsGroup = Undefined;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	ContactInformationKinds.Ref,
	|	ContactInformationKinds.Type,
	|	ContactInformationKinds.Presentation,
	|	ContactInformationKinds.Description,
	|	ContactInformationKinds.AllowMultipleValueInput,
	|	ContactInformationKinds.Mandatory,
	|	ContactInformationKinds.CheckValidity,
	|	ContactInformationKinds.IDForFormulas,
	|	CASE WHEN ContactInformationKinds.PredefinedKindName <> """"
	|		THEN ContactInformationKinds.PredefinedKindName
	|		ELSE ContactInformationKinds.PredefinedDataName
	|	END AS PredefinedKindName,
	|	ContactInformationKinds.AddlOrderingAttribute
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|WHERE
	|	ContactInformationKinds.Parent = &CIKindsGroup
	|	AND ContactInformationKinds.DeletionMark = FALSE
	|	AND ContactInformationKinds.Used = TRUE
	|	AND &ContactInformationTypeFilter
	|
	|ORDER BY
	|	AddlOrderingAttribute";
	
	Query.SetParameter("CIKindsGroup", CIKindsGroup);
	
	If ContactInformationType <> Undefined Then
		ReplacementText  = "ContactInformationKinds.Type = &ContactInformationType";
		Query.SetParameter("ContactInformationType", ContactInformationType);
	Else
		ReplacementText = "True";
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&ContactInformationTypeFilter", ReplacementText);
	
	QueryResult = Query.Execute().Unload();
	Return QueryResult;
	
EndFunction

// Returns the attribute indicating the object is attached to the "Contact information" subsystem
// and contains tabular section ContactInformation.
//
// Parameters:
//  ObjectToCheck - CatalogObject
//                    - CatalogRef
//                    - DocumentObject
//                    - DocumentRef
//                    - Type - — the object being checked for integration with the Contact information subsystem.
//
// Returns:
//  Boolean - — if True, the object contains contact information.
//
Function ContainsContactInformation(ObjectToCheck) Export
	
	ObjectType = ?(TypeOf(ObjectToCheck) <> Type("Type"),
		TypeOf(ObjectToCheck),
		ObjectToCheck);
	ObjectMetadata = Metadata.FindByType(ObjectType);
	If ObjectMetadata <> Undefined
		And ObjectMetadata.TabularSections.Find("ContactInformation") <> Undefined Then
			Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Returns a reference to a contact information kind.
// If a kind is not found by name, then the search is executed by names of predefined items.
//
// Parameters:
//  Name - String - a unique name of a contact information kind.
// 
// Returns:
//  CatalogRef.ContactInformationKinds
//
Function ContactInformationKindByName(Name) Export
	
	Kind = Undefined;
	If Not InfobaseUpdate.InfobaseUpdateInProgress() Then
		Kinds = ContactsManagerInternalCached.ContactInformationKindsByName();
		Kind = Kinds.Get(Name);
	Else
		Kinds = PredefinedContactInformationKinds(Name);
		If Kinds.Count() > 0 Then
			Kind = Kinds[0].Ref;
		EndIf;
	EndIf;
	
	If Kind <> Undefined Then
		Return Kind;
	EndIf;
	
	Return Catalogs.ContactInformationKinds[Name];
	
EndFunction

// Details of contact information parameters used in the OnCreateAtServer handler.
// 
// Returns:
//  Structure - Contact information parameters:
//   * IndexOf                   - String - an address postal code.
//   * Country                   - String - an address country.
//   * PremiseType             - String - a description of premise type that will be set
//                                         in the address input form. Apartment by default.
//   * ItemForPlacementName - String - the group, to which contact information items will be placed.
//   * HiddenKinds           - Array - contact information kinds that do not need to be displayed on the form.
//   * DeferredInitialization  - Boolean - if True, generation of contact information fields on the form will be deferred.
//   * CITitleLocation     - FormItemTitleLocation - can take the following values:
//                                                             FormItemTitleLocation.Top or
//                                                             FormItemTitleLocation.Left (by default).
//   * AllowAddingFields - Boolean - If True, the contact information owner form has a button for adding additional contact information
//                                         
//   * ItemsPlacedOnForm         - Map of KeyAndValue - Contact information kinds that were added to the form interactively.
//                                               In case of deferred initialization, they will appear on the form after the
//                                               ContactsManager.ExecuteDeferredInitialization procedure is called.:
//                                  ** Key - String - The name of a predefined contact information kind
//                                          - CatalogRef.ContactInformationKinds
//                                  ** Value - Boolean - True
//   * URLProcessing - Boolean - If True, contact information of the WebPage type is displayed as a hyperlink 
//   										   	
//   * ExcludedKinds - Array - Obsolete. Instead, use "ItemsPlacedOnForm". 						                                                            
//
Function ContactInformationParameters() Export

	Result = New Structure;
	Result.Insert("PremiseType", "Appartment");
	Result.Insert("IndexOf", Undefined);
	Result.Insert("Country", Undefined);
	Result.Insert("DeferredInitialization", False);
	Result.Insert("CITitleLocation", "");
	Result.Insert("HiddenKinds", Undefined);
	Result.Insert("ItemForPlacementName", "ContactInformationGroup");
	Result.Insert("URLProcessing", False); 
	Result.Insert("AllowAddingFields", True);
	Result.Insert("ItemsPlacedOnForm", Undefined);
	Result.Insert("ExcludedKinds", Undefined);
	
	Return Result;

EndFunction 

////////////////////////////////////////////////////////////////////////////////
// Check and information about the address

// Checks contact information.
//
// Parameters:
//   Presentation  - String - a contact information presentation. Used if it is impossible to determine
//                           a presentation based on the FieldValues parameter (the Presentation field is missing).
//   FieldValues  - String
//                  - Structure
//                  - Map
//                  - ValueList - details of contact information fields.
//   InformationKind  - CatalogRef.ContactInformationKinds - used to determine a type if it is impossible
//                                                               to determine it by the FieldValues parameter.
//   InformationType  - EnumRef.ContactInformationTypes - contact information type.
//   AttributeName   - String - an attribute name on the form.
//   Comment    - String - comment text.
//   AttributePath1 - String - an attribute path.
// 
// Returns:
//   Number - an error level, 0 - no errors.
//
Function ValidateContactInformation(Presentation, FieldValues, InformationKind, InformationType,
	AttributeName, Comment = Undefined, AttributePath1 = "") Export
	
	SerializationText = ?(IsBlankString(FieldValues), Presentation, FieldValues);

	If ContactsManagerClientServer.IsXMLContactInformation(SerializationText) Then
		CIObject = ContactInformationInJSON(SerializationText);
	Else
		CIObject = FieldValues;
	EndIf;
	
	// Check.
	If InformationType = Enums.ContactInformationTypes.Email Then
		ErrorsLevel = EmailFIllingErrors(CIObject, InformationKind, AttributeName, AttributePath1);
	ElsIf InformationType = Enums.ContactInformationTypes.Address Then
		ErrorsLevel = AddressFIllErrors(CIObject, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.Phone Then
		ErrorsLevel = PhoneFillingErrors(CIObject, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.Fax Then
		ErrorsLevel = PhoneFillingErrors(CIObject, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.WebPage Then
		ErrorsLevel = WebPageFillingErrors(CIObject, InformationKind, AttributeName);
	Else
		// No other checks are made.
		ErrorsLevel = 0;
	EndIf;
	
	Return ErrorsLevel;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Sets properties of a contact information group.
//
// Parameters:
//    Parameters - Structure:
//        * Code    - String   - a code of a contact information kind to identify the item.
//        * Description - String - a description of a contact information kind.
//        * Name - String - name of the predefined contact information type;
//        * Used - Boolean - indicates whether a contact information kind is used. Default value is True.
//
// Returns:
//   CatalogRef.ContactInformationKinds - a reference to the group.
//
Function SetContactInformationKindGroupProperties(Parameters) Export
	
	Object = ContactInformationKindObject(Parameters.Name, True);
	
	Object.PredefinedKindName = Parameters.Name;
	Object.Parent                 = Parameters.Group;
	Object.Used             = Parameters.Used;
	
	If IsBlankString(Object.PredefinedKindName) Then
		Object.PredefinedKindName = Object.PredefinedDataName;
	EndIf;
	
	SetContactInformationKindDescription(Object, Parameters.Description);
	
	InfobaseUpdate.WriteObject(Object);
	
	Return Object.Ref;
	
EndFunction

// Sets properties of a contact information kind.
// Note. When using the Order parameter, make sure that the assigned values are unique.
//  If any non-unique order values are identified in this same group after update,
//  users cannot further edit order values.
//  Generally, it is recommended that you do not use this parameter (the order will not change) or set it to
//  0 (in this case, the order will be assigned automatically in the "Item order" subsystem upon the procedure execution).
//  To reassign several contact information kinds in a given relative order without moving them to the beginning of
//  the list, you only need to call the procedure in sequence for each required contact information kind (with order value set to 0).
//  If a predefined contact information kind is added to the infobase, do not assign its order explicitly.
//
// Parameters:
//   Parameters - Structure - properties of a contact information kind:
//      * Name - String - name of the predefined contact information type;
//      * Description - String - a description of a contact information kind;
//      * Kind - CatalogRef.ContactInformationKinds
//            - String - a reference to the contact information kind or
//                       a predefined item ID.
//      * Type - EnumRef.ContactInformationTypes - a type of contact information or its
//                                                                    ID.
//      * Order - Number
//                - Undefined - The contact information kind's relative position in the list:
//                                 "Undefined" - Keep the current order:
//                                 "0" - Order automatically
//                                 "1", "2", ... - The specific position in the list.
//                                 
//      * CanChangeEditMethod - Boolean                - True if you can change the editing
//                                                                      method only in the dialog box, otherwise, False.
//    * EditingOption - String - a value editing method. Available options: InputFieldAndDialog, InputField, and Dialog.
//                                    If Dialog, the form displays a hyperlink with a contact
//                                    information presentation. Clicking it opens the form of the matching contact information type.
//                                    The property is applicable only for the following contact information types: Address, Phone, and Fax.
//                                    If InputField, an input field is displayed on the form.
//                                    If InputFieldAndDialog, both the input field and the input form of the matching contact information type are available.
//      * Mandatory                                    - Boolean - True if the field is
//                                                                      mandatory, otherwise, False.
//      * AllowMultipleValueInput - Boolean                  - indicates whether additional
//                                                                      input fields are used for this kind.
//      * DenyEditingByUser - Boolean             - indicates that editing
//                                                                      of contact
//                                                                      information kind properties by a user is unavailable.
//      * StoreChangeHistory - Boolean -                          indicates whether the change history of
//                                                                      a contact information kind is stored.
//                                                                      Default value is False.
//      * Used - Boolean -                                     indicates whether a contact information kind is used.
//                                                                      Default value is True.
//      * FieldKindOther - String -                                    The Other field layout on the form. Possible values:
//                                                                      MultilineWide, SingleLineWide, SingleLineNarrow.
//                                                                      The default value is SingleLineWide.
//      * EditInDialogOnly - Boolean - obsolete. Use EditingOption instead.
//                                                 If True, the form displays a hyperlink with a contact
//                                                 information presentation. Click it to open the form of the matching
//                                                 contact information type. The property is applicable only for contact information with the type:
//                                                 Address, Phone, Fax, WebPage. Default value is False.
//      * ValidationSettings - Undefined - for the Other, WebPage, and Skype types.
//                          - Structure - The field set varies for different contact information types:
//         ** OnlyNationalAddress - Boolean - for the Address type. If True, only national address input is enabled.
//         ** CheckValidity - Boolean - For the EmailAddress type.
//                                             If True, forbid users to save invalid email addresses.
//         ** HideObsoleteAddresses - Boolean - for the Address type. True if showing
//                                                  outdated addresses upon
//                                                  input is not required (only if OnlyNationalAddress = True).
//         ** IncludeCountryInPresentation - Boolean - for the Address type. True if including a country
//                                                    description in the address presentation is required.
//         ** CheckValidity - Boolean - For the EmailAddress type.
//                                             If True, forbid users to save invalid email addresses.
//         ** PhoneWithExtensionNumber  - Boolean - for the Phone or Fax types. If True, a phone/fax contains
//                                                  an extension.
//         ** EnterNumberByMask - Boolean - for the Phone or Fax types. True if entering a phone by mask is required.
//         ** PhoneNumberMask  - String - for types Phone or Fax. Contains a character-by-character string of the mask
//                                           of interactive entering a text in the field. The mask format matches
//                                           the platform mask for the input field.
//         ** ProhibitInvalidEntry - Boolean - obsolete. All passed values are ignored.
//                                                  For the EmailAddress type. To prevent users from saving
//                                                  incorrect addresses, use the CheckValidity parameter instead.
//         ** ProhibitInvalidEntry - Boolean - obsolete. All passed values are ignored.
//                                                  For the EmailAddress type. To prevent users from saving
//                                                  incorrect addresses, use the CheckValidity parameter instead.
//
Procedure SetContactInformationKindProperties(Parameters) Export
	
	If Not ValueIsFilled(Parameters.Kind) Then
		Object = ContactInformationKindObject(Parameters.Name);
	ElsIf TypeOf(Parameters.Kind) = Type("String") Then
		Object = ContactInformationKindObject(Parameters.Kind);
	Else
		Object = Parameters.Kind.GetObject();
	EndIf;
	
	RefreshScheduledJobStatus = (Object.CorrectObsoleteAddresses <> Parameters.CorrectObsoleteAddresses);
	
	If Parameters.EditInDialogOnly Then
		Parameters.EditingOption = "Dialog";
	EndIf;
	
	FillPropertyValues(Object, Parameters, "Type, CanChangeEditMethod,
	|EditingOption, Mandatory, AllowMultipleValueInput, IsAlwaysDisplayed,
	|DenyEditingByUser, Used, StoreChangeHistory ,InternationalAddressFormat, CorrectObsoleteAddresses");
	
	If ValueIsFilled(Parameters.Name) Then
		Object.PredefinedKindName = Parameters.Name;
	EndIf;
	
	If IsBlankString(Object.PredefinedKindName) Then
		Object.PredefinedKindName = Object.PredefinedDataName;
	EndIf;
	
	SetContactInformationKindDescription(Object, Parameters.Description);
	
	If IsBlankString(Object.Parent) Then
		Object.Parent = Parameters.Group;
	EndIf;
	Object.GroupName = Common.ObjectAttributeValue(Object.Parent, "PredefinedKindName");
	
	If Parameters.Type = Enums.ContactInformationTypes.Other Then
		Object.FieldKindOther = Parameters.FieldKindOther;
	EndIf;
	
	ValidateSettings = TypeOf(Parameters.ValidationSettings) = Type("Structure");
	ValidationSettings = SettingsForCheckingContactInformationParameters(Parameters.Type);
	
	If ValidateSettings Then
		If Parameters.ValidationSettings.Property("PhoneWithExtension") 
		   And Parameters.ValidationSettings.PhoneWithExtension  Then
				ValidationSettings.PhoneWithExtensionNumber = Parameters.ValidationSettings.PhoneWithExtension;
		EndIf;
		FillPropertyValues(ValidationSettings, Parameters.ValidationSettings);
	EndIf;
	
	If ValidateSettings And Parameters.Type = Enums.ContactInformationTypes.Address Then
		FillPropertyValues(Object, ValidationSettings);
	ElsIf ValidateSettings And Parameters.Type = Enums.ContactInformationTypes.Email Then
		SetValidationAttributesValues(Object, ValidationSettings);
	ElsIf ValidateSettings And Parameters.Type = Enums.ContactInformationTypes.Phone Then
		Object.PhoneWithExtensionNumber = ValidationSettings.PhoneWithExtensionNumber;
		Object.PhoneNumberMask = ValidationSettings.PhoneNumberMask;
		Object.EnterNumberByMask = ValidationSettings.EnterNumberByMask;
	Else
		SetValidationAttributesValues(Object);
	EndIf;
	
	Result = ContactsManagerInternal.CheckContactsKindParameters(Object);
	
	If Result.HasErrors Then
		Raise Result.ErrorText;
	EndIf;
	
	If Parameters.Order <> Undefined Then
		Object.AddlOrderingAttribute = Parameters.Order;
	EndIf;
	
	ValueUsedForGroup = Common.ObjectAttributeValue(Object.Parent, "Used");
	If IsBlankString(Object.IDForFormulas) Then
		Object.IDForFormulas = Catalogs.ContactInformationKinds.UUIDForFormulas(
				DescriptionForIDGeneration(Object), Object.Ref, Object.Parent);
	EndIf;
	
	If ValueUsedForGroup = False And Object.Used Then
		
		BeginTransaction();
		Try
			
			Block = New DataLock;
			LockItem = Block.Add("Catalog.ContactInformationKinds");
			LockItem.SetValue("Ref", Object.Parent);
			Block.Lock();
			
			Parent = Object.Parent.GetObject();
			Parent.Used = True;
			InfobaseUpdate.WriteObject(Parent);
			
			InfobaseUpdate.WriteObject(Object);
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	Else
		InfobaseUpdate.WriteObject(Object);
	EndIf;
	
	If RefreshScheduledJobStatus Then
		Status = ?(Object.CorrectObsoleteAddresses = True, True, Undefined);
		ContactsManagerInternal.SetScheduledJobUsage(Status);
	EndIf;
	
EndProcedure

// Returns a structure of parameters of a contact information kind group.
//
// Parameters:
//    ContactInformationGroup1 - CatalogRef.ContactInformationKinds- a contact information group.
//
// Returns:
//    Structure:
//        * Name          - String - a unique name of a contact information kind.
//        * Description - String - a description of a contact information kind.
//        * Group - CatalogRef.ContactInformationKinds - a reference to a group (parent) of a catalog item.
//        * Used - Boolean - indicates whether a contact information kind is used. Default value is True.
//
Function ContactInformationKindGroupParameters(ContactInformationGroup1 = Undefined) Export
	
	Result = ContactInformationKindCommonParametersDetails();
	
	If TypeOf(ContactInformationGroup1 ) = Type("CatalogRef.ContactInformationKinds") Then
		Values = Common.ObjectAttributesValues(ContactInformationGroup1, "PredefinedKindName, PredefinedDataName, Parent, Description, Used");
		Result.Name = ?(ValueIsFilled(Values.PredefinedKindName), Values.PredefinedKindName, Values.PredefinedDataName);
		Result.Group = Values.Parent;
		Result.Description = Values.Description;
		Result.Used = Values.Used;
	EndIf;
	
	Return Result;
	
EndFunction

// Returns a structure of contact information kind parameters for a particular type.
// 
// Parameters:
//    ContactInformationKindOrType - EnumRef.ContactInformationTypes
//                                  - String - contact information type,
//                                  - CatalogRef.ContactInformationKinds- a contact information kind for
//                                  filling the ValidationSettings property.
//
// Returns:
//  Structure:
//   * Name          - String - a unique name of a contact information kind.
//   * Description - String - a description of a contact information kind.
//   * Kind - CatalogRef.ContactInformationKinds
//         - String - a reference to the contact information kind or
//                    a predefined item ID.
//   * Group - CatalogRef.ContactInformationKinds - a reference to a group (parent) of a catalog item.
//   * Type - EnumRef.ContactInformationTypes - a type of contact information or its ID.
//   * Order - Number
//             - Undefined - contact information kind order, a relative position in the list.
//                              Undefined - do not reassign;
//                              0            - assign automatically;
//                              Number > 0    - assign the specified order.
//                              Note. When using the Order parameter, make sure
//                              that the assigned values are unique. If any non-unique order values are identified in this same group after update,
//                              users cannot further edit
//                              order values. Generally, it is recommended that you do not
//                              use this parameter (the order will not change) or set it to
//                              0 (in this case, the order will be assigned automatically in the Item
//                              ordering subsystem upon the procedure execution). To reassign several contact information kinds in
//                              a given relative order without
//                              moving them to the beginning of the list, you only need to call the procedure in
//                              sequence for each required contact information kind (with order value set to 0). If
//                              a predefined contact information kind is added to the infobase,
//                              do not assign its order explicitly.
//     * CanChangeEditMethod - Boolean -indicates whether a user can change properties of a contact information kind.
//                                                    If False, properties of a contact information kind form
//                                                    are view-only. The default value is False.
//     * EditingOption - String - An editing option.
//     * EditingOption - String - An editing option.
//                                    
//                                    
//                                    
//                                    
//                                    
//     * StoreChangeHistory     - Boolean - indicates whether the contact information change history can be stored.
//                                              Storing the history is allowed if EditingOption = "Dialog"
//                                              is True. The property is only applicable when the tabular section ContactInformation
//                                              contains the ValidFrom attribute. Default value is False.
//     * Mandatory       - Boolean - if True, a value in 
//                                               the contact information field is mandatory. The default value is False.
//     * AllowMultipleValueInput - Boolean       - indicates whether multiple value input is available for this kind.
//                                                        The default value is False.
//     * DenyEditingByUser - Boolean - indicates that editing of a contact information kind 
//                                                       by a user is unavailable. The default value is False.
//     * Used - Boolean - if False, a contact information kind is not available for users.
//                               Such a kind is not displayed in forms and lists of contact information kinds.
//                               Default value is True.
//     * InternationalAddressFormat          - Boolean - indicates that an address format is international. 
//                                                     If True, all addresses can be entered in international format only.
//                                                     The default value is False.
//     * FieldKindOther                        - String - Defines the Other field layout on the form.
//                                            Available options: MultilineWide, SingleLineWide, and SingleLineNarrow.
//                                            The property is applicable only for contact information with the type: Other.
//                                            The default value for a contact information kind with the Other type is SingleLineWide,
//                                            otherwise, a blank string.
//     * EditInDialogOnly - Boolean - obsolete. Use EditingOption instead.
//                                               If True, the form displays a hyperlink with a contact
//                                               information presentation. Click it to open the form of the matching
//                                               contact information type. The property is applicable only for contact information with the type-
//                                               Address, Phone, Fax, WebPage. Default value is False.
//     * ValidationSettings  - Undefined - for the Other, WebPage, and Skype types.
//                          - Structure - Validation settings for the given contact information kind: 
//       ** OnlyNationalAddress - Boolean - for the Address type. If True, you can enter only national addresses.
//                                               Changing the address country is not allowed.
//       ** CheckValidity - Boolean - for the EmailAddress type. If True, a user cannot enter
//                                           an incorrect email address. The default value is False.
//                                           
//                                           
//                                           
//       ** IncludeCountryInPresentation - Boolean - for the Address type. if True, a country Description is always
//                                                  added to an address presentation even when other address fields are blank.
//                                                  The default value is False.
//       ** SpecifyRNCMT - Boolean - for the Address type. indicates whether manual input of an RNCMT code is available in the address input form.
//       ** CheckValidity - Boolean - for the EmailAddress type. If True, a user cannot enter 
//                                          an incorrect email address. The default value is False.
//       ** PhoneWithExtensionNumber - Boolean - for the Phone and Fax type. If true,
//                                               you can enter an extension in the phone input form. The default value is True.
//
Function ContactInformationKindParameters(ContactInformationKindOrType = Undefined) Export
	
	If TypeOf(ContactInformationKindOrType) = Type("CatalogRef.ContactInformationKinds") Then
		
		KindParameters = ParametersFromContactInformationKind(ContactInformationKindOrType);
		
	Else
		
		If TypeOf(ContactInformationKindOrType) = Type("String") Then
			TypeToSet = Enums.ContactInformationTypes[ContactInformationKindOrType];
		Else
			TypeToSet = ContactInformationKindOrType;
		EndIf;
		
		KindParameters = ContactInformationParametersDetails(TypeToSet);
	EndIf;
	
	Return KindParameters;
	
EndFunction

// Writes contact information from XML to the fields of the Object contact information tabular section.
//
// Parameters:
//    Object - CatalogObject - A configuration object containing the contact information table.
//    Value - String - contact information in the internal JSON format.
//    InformationKind - CatalogRef.ContactInformationKinds - a reference to a contact information kind.
//    InformationType - EnumRef.ContactInformationTypes - contact information type.
//    RowID - Number - tabular section row ID.
//    Date - Date - the date, from which contact information record is valid.
//                  It is used for storing the history of contact information changes.
//
Procedure WriteContactInformation(Object, Val Value, InformationKind, InformationType, RowID = 0, Date = Undefined) Export
	
	If IsBlankString(Value) Then
		Return;
	EndIf;
	
	If ContactsManagerClientServer.IsXMLContactInformation(Value) Then
		CIObject = ContactsManagerInternal.ContactInformationToJSONStructure(Value, InformationType);
	Else
		CIObject = ContactsManagerInternal.JSONToContactInformationByFields(Value, InformationType);
	EndIf;
	
	If Not ContactsManagerInternal.ContactsFilledIn(CIObject) Then
		Return;
	EndIf;
	
	NewRow = Object.ContactInformation.Add();
	NewRow.Presentation = CIObject.Value;
	NewRow.Value      = ContactsManagerInternal.ToJSONStringStructure(CIObject);
	NewRow.Kind           = InformationKind;
	NewRow.Type           = InformationType;
	
	If ContactsManagerInternalCached.IsLocalizationModuleAvailable() Then
		ModuleContactsManagerLocalization = Common.CommonModule("ContactsManagerLocalization");
		NewRow.FieldValues = ModuleContactsManagerLocalization.ContactsFromJSONToXML(CIObject, InformationType);
	EndIf;
	
	If ValueIsFilled(Date) 
		And ContactsManagerInternalCached.ObjectContactInformationContainsValidFromColumn(Object.Ref) Then
			NewRow.ValidFrom  = Date;
	EndIf;
	
	If ValueIsFilled(RowID) Then
		NewRow.TabularSectionRowID = RowID;
	EndIf;
	
	// Filling in additional attributes of the tabular section.
	ContactsManagerInternal.FillContactInformationTechnicalFields(NewRow, CIObject, InformationType);
	
EndProcedure

// Updates a contact information presentation in internal field KindForList that
// is used to display it in dynamic lists and reports.
//
// Parameters:
//  Object -DefinedType.ContactInformationOwner - a reference to the configuration object containing
//  contact information tabular section.
//
Procedure UpdateContactInformationForLists(Object = Undefined) Export
	
	If Object = Undefined Then
		ContactsManagerInternal.UpdateContactInformationForLists();
	Else
		If Object.Metadata().TabularSections.ContactInformation.Attributes.Find("KindForList") <> Undefined Then
			ContactsManagerInternal.UpdateCotactsForListsForObject(Object);
		EndIf;
	EndIf;
	
EndProcedure

// Executes deferred update of contact information for lists.
//
// Parameters:
//  Parameters    - Structure - update handler parameters.
//  PortionSize - Number - Size of a batch to be processed in a single run.
//
Procedure UpdateContactsForListDeferred(Parameters, PortionSize = 1000) Export
	
	ObjectsWithKindForList = Undefined;
	Parameters.Property("ObjectsWithKindForList", ObjectsWithKindForList);
	
	If Parameters.ExecutionProgress.TotalObjectCount = 0 Then
		// Calculate the quantity.
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ContactInformationKinds.Ref,
		|CASE
		|	WHEN ContactInformationKinds.PredefinedKindName <> """"
		|	THEN ContactInformationKinds.PredefinedKindName
		|	ELSE ContactInformationKinds.PredefinedDataName
		|END AS PredefinedKindName
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds
		|WHERE
		|	ContactInformationKinds.IsFolder = TRUE";
		
		QueryResult = Query.Execute();
		SelectionDetailRecords = QueryResult.Select();
		ObjectsWithKindForList = New Array;
		QueryText = "";
		Separator = "";
		
		QueryTemplate = "SELECT
		| COUNT(TableWithContactInformation.Ref) AS Count,
		| VALUETYPE(TableWithContactInformation.Ref) AS Ref
		|FROM
		| &TableWithContactInformation AS TableWithContactInformation
		| GROUP BY
		|	VALUETYPE(TableWithContactInformation.Ref)";
		
		While SelectionDetailRecords.Next() Do
			If StrStartsWith(SelectionDetailRecords.PredefinedKindName, "Catalog") Then
				ObjectName = Mid(SelectionDetailRecords.PredefinedKindName, StrLen("Catalog") + 1);
				
				If Metadata.Catalogs.Find(ObjectName) <> Undefined Then
					ContactInformation = Metadata.Catalogs[ObjectName].TabularSections.ContactInformation;
					If ContactInformation.Attributes.Find("KindForList") <> Undefined Then
						QueryText = QueryText + Separator 
							+ StrReplace(QueryTemplate, "&TableWithContactInformation", "Catalog." + ObjectName);
						Separator = " UNION ALL ";
					EndIf;
				EndIf;
			ElsIf StrStartsWith(SelectionDetailRecords.PredefinedKindName, "Document") Then
				ObjectName = Mid(SelectionDetailRecords.PredefinedKindName, StrLen("Document") + 1);
				
				If Metadata.Documents.Find(ObjectName) <> Undefined Then
					ContactInformation = Metadata.Documents[ObjectName].TabularSections.ContactInformation;
					If ContactInformation.Attributes.Find("KindForList") <> Undefined Then
						QueryText = QueryText + Separator 
							+ StrReplace(QueryTemplate, "&TableWithContactInformation", "Document." + ObjectName);
						Separator = " UNION ALL ";
					EndIf;
				EndIf;
			EndIf;
		EndDo;
		
		If IsBlankString(QueryText) Then
			Parameters.ProcessingCompleted = False;
			Return;
		EndIf;
		Query = New Query(QueryText);
		QueryResult = Query.Execute().Select();
		Count = 0;
		ObjectsWithKindForList = New Array;
		While QueryResult.Next() Do
			Count = Count + QueryResult.Count;
			ObjectsWithKindForList.Add(QueryResult.Ref);
		EndDo;
		Parameters.ExecutionProgress.TotalObjectCount = Count;
		Parameters.Insert("ObjectsWithKindForList", ObjectsWithKindForList);
	EndIf;
	
	If ObjectsWithKindForList = Undefined Or ObjectsWithKindForList.Count() = 0 Then
		Return;
	EndIf;
	
	FullObjectNameWithKindForList = Metadata.FindByType(ObjectsWithKindForList.Get(0)).FullName();
	QueryText = "SELECT TOP 1234
	|	ContactInformation.Ref AS Ref
	|FROM
	|	&ContactInformation AS ContactInformation
	|
	|GROUP BY
	|	ContactInformation.Ref
	|
	|HAVING
	|	SUM(CASE
	|			WHEN ContactInformation.KindForList = VALUE(Catalog.ContactInformationKinds.EmptyRef)
	|				THEN 0
	|				ELSE 1
	|		END) = 0";
	
	QueryText = StrReplace(QueryText, "1234", Format(PortionSize, "NG=0"));
	QueryText = StrReplace(QueryText, "&ContactInformation", FullObjectNameWithKindForList + ".ContactInformation");
	
	Query = New Query(QueryText);
	QueryResult = Query.Execute().Select();
	Count = QueryResult.Count();
	If Count > 0 Then
		
		Block = New DataLock();
		Block.Add(FullObjectNameWithKindForList);
		
		BeginTransaction();
		Try
			Block.Lock();
			
			While QueryResult.Next() Do
				Object = QueryResult.Ref.GetObject();
				UpdateContactInformationForLists(Object);
				InfobaseUpdate.WriteData(Object);
			EndDo;
			
			CommitTransaction();
			
		Except
			RollbackTransaction();
			Raise;
		EndTry;

		If Count < 1000 Then
			ObjectsWithKindForList.Delete(0);
		EndIf;
		Parameters.ExecutionProgress.ProcessedObjectsCount1 = Parameters.ExecutionProgress.ProcessedObjectsCount1 + Count;
	Else
		ObjectsWithKindForList.Delete(0);
	EndIf;
	
	If ObjectsWithKindForList.Count() > 0 Then
		Parameters.ProcessingCompleted = False;
	EndIf;
	
	Parameters.Insert("ObjectsWithKindForList", ObjectsWithKindForList);
	
EndProcedure

// Deletes information about the matching contact information kind catalog item and predefined value
// that was marked as deleted. For a single call in update handlers of canceling predefined
// items of the ContactInformationKinds catalog.
//
Procedure RemovePredefinedAttributeForContactInformationKinds() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ContactInformationKinds.Ref AS CIKind,
	|	ContactInformationKinds.PredefinedDataName AS PredefinedDataName,
	|	ISNULL(ContactInformationKinds.Parent.PredefinedDataName, """") AS Group,
	|	ContactInformationKinds.PredefinedKindName AS PredefinedKindName,
	|	ContactInformationKinds.Predefined AS Predefined
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds";
	
	ContactInformationKinds = Query.Execute().Unload();
	ContactInformationKinds.Indexes.Add("PredefinedKindName");
	
	Block = New DataLock();
	Block.Add("Catalog.ContactInformationKinds");
	
	BeginTransaction();
	Try
		
		Block.Lock();
		
		For Each Kind In ContactInformationKinds Do
			
			If Not Kind.Predefined Or Not StrStartsWith(Lower(Kind.PredefinedDataName), "delete") Then
				Continue;
			EndIf;
			
			PredefinedKindName = Mid(Kind.PredefinedDataName, StrLen("delete") + 1);
			If ContactInformationKinds.Find(PredefinedKindName, "PredefinedKindName") <> Undefined Then
				Continue;
			EndIf;
			
			CIKindObject1 = Kind.CIKind.GetObject();
			If Not CIKindObject1.IsFolder Then
				CIKindObject1.GroupName = Mid(Kind.Group, StrLen("delete") + 1);
			EndIf;
			
			CIKindObject1.PredefinedKindName = PredefinedKindName;
			CIKindObject1.PredefinedDataName = "";
			InfobaseUpdate.WriteData(CIKindObject1);
			
		EndDo;
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Backward compatibility.

// Deprecated. Obsolete. Use ContactsManager.ContactsByPresentation instead.
// Converts a contact information presentation into an XML string matching the structure
// of XDTO packages ContactInformation and Address.
// Correct conversion is not guaranteed for the addresses entered in free form.
//
//  Parameters:
//      Presentation - String  - a string presentation of contact information displayed to a user.
//      ExpectedKind  - CatalogRef.ContactInformationKinds
//                    - EnumRef.ContactInformationTypes
//                    - Structure - a kind or a type of contact information.
//
// Returns:
//      String - contact information in the XML format matching the structure of the XDTO packages ContactInformation and Address.
//
Function ContactsXMLByPresentation(Presentation, ExpectedKind) Export
	
	If ContactsManagerInternalCached.IsLocalizationModuleAvailable() Then
		ModuleContactsManagerLocalization = Common.CommonModule("ContactsManagerLocalization");
	
		Return ModuleContactsManagerLocalization.XDTOContactsInXML(
			ModuleContactsManagerLocalization.XDTOContactsByPresentation(Presentation, ExpectedKind));
			
	EndIf;
	
	Return "";
	
EndFunction

#EndRegion

// Returns command details grouped by the associated contact information type.
// The resulting map is intended for ContactsManagerOverridable.OnDefineSettings. 
//
// Returns:
//   Map of KeyAndValue:
//     * Key     - EnumRef.ContactInformationTypes
//     * Value - See CommandsOfContactInfoType
//
Function DetailsOfCommands() Export
	
	DetailsOfCommands = New Map;
	DetailsOfCommands.Insert(Enums.ContactInformationTypes.Address, CommandsOfContactInfoType(
		Enums.ContactInformationTypes.Address));
	DetailsOfCommands.Insert(Enums.ContactInformationTypes.Phone, CommandsOfContactInfoType(
		Enums.ContactInformationTypes.Phone));
	DetailsOfCommands.Insert(Enums.ContactInformationTypes.Email,
		CommandsOfContactInfoType(Enums.ContactInformationTypes.Email));
	DetailsOfCommands.Insert(Enums.ContactInformationTypes.Skype, CommandsOfContactInfoType(
		Enums.ContactInformationTypes.Skype));
	DetailsOfCommands.Insert(Enums.ContactInformationTypes.WebPage, CommandsOfContactInfoType(
		Enums.ContactInformationTypes.WebPage));
	DetailsOfCommands.Insert(Enums.ContactInformationTypes.Fax, CommandsOfContactInfoType(
		Enums.ContactInformationTypes.Fax));
	DetailsOfCommands.Insert(Enums.ContactInformationTypes.Other, CommandsOfContactInfoType(
		Enums.ContactInformationTypes.Other));

	Return DetailsOfCommands;
	
EndFunction

// Returns the details of the commands associated with the passed contact information type.
// Intended for ContactsManagerOverridable.OnDefineSettings. 
//
// Parameters:
//   Type - EnumRef.ContactInformationTypes
//
// Returns:
//   Structure - Field sets for different contact information types.
//   Address: AddCommentToAddress, ShowOnYandexMaps, ShowOnGoogleMap, PlanMeeting, ShowChangeHistory. 
//     Phone: Telephone, SendSMSMessage, ShowChangeHistory.
//     Fax: SendFax, ShowChangeHistory.
//     Email: WriteEmail.
//     Skype: CallSkype, StartSkypeChat.
//     WebPage: OpenWebPage.
//     Other: OpenWindowOther.
//     A list of fields:
//     * AddCommentToAddress  - See CommandDetailsByName
//     * ShowOnYandexMaps     - See CommandDetailsByName
//     * ShowOnGoogleMap     - See CommandDetailsByName
//     * PlanMeeting      - See CommandDetailsByName
//     * ShowChangeHistory  - See CommandDetailsByName
//     * Telephone       - See CommandDetailsByName
//     * SendSMS              - See CommandDetailsByName
//     * SendFax             - See CommandDetailsByName
//     * WriteEmail2 - See CommandDetailsByName
//     * SkypeCall            - See CommandDetailsByName
//     * StartSkypeChat            - See CommandDetailsByName
//     * OpenWebPage        - See CommandDetailsByName
//     * OpenWindowOther         - See CommandDetailsByName
//
Function CommandsOfContactInfoType(Type) Export

	Return ContactsManagerInternalCached.CommandsOfContactInfoType(Type);

EndFunction

// Returns a structure describing a contact information command.
// The resulting map is intended for ContactsManagerOverridable.OnDefineSettings. 
//
// Parameters:
//   CommandName - String - The name of the command whose details should be obtained.
//
// Returns:
//   See CommandProperties 
//
Function CommandDetailsByName(CommandName) Export
	
	// A command associated with the types "Address", "Phone", and "Fax"
	If CommandName = "ShowChangeHistory" Then
		Return CommandProperties(
				NStr("en = 'Change history…';"),
				NStr("en = 'View contact information change history.';"),
				PictureLib.ChangeHistory,
				"ContactsManagerClient.BeforeOpenChangeHistoryForm",
				True);
	EndIf;
	
	// Commands associated with the type "Address"
	If CommandName = "AddCommentToAddress" Then
		Return CommandProperties(
				NStr("en = 'Type comment';"),
				NStr("en = 'Type comment';"),
				PictureLib.Comment,
				"ContactsManagerClient.BeforeEnterComment",
				True);
	ElsIf CommandName = "ShowOnYandexMaps" Then
		Return CommandProperties(
				NStr("en = 'Address on Yandex.Maps';"),
				NStr("en = 'Show the address on Yandex.Maps.';"),
				PictureLib.YandexMaps,
				"ContactsManagerClient.BeforeShowAddressOnYandexMaps");
	ElsIf CommandName = "ShowOnGoogleMap" Then
		Return CommandProperties(
				NStr("en = 'Address on Google Maps';"),
				NStr("en = 'Show the address on Google Maps.';"),
				PictureLib.GoogleMaps,
				"ContactsManagerClient.BeforeShowAddressOnGoogleMaps");
	ElsIf CommandName = "PlanMeeting" Then
		Return CommandProperties("", "");
	EndIf;
	
	// Commands associated with the type "Phone"
	If CommandName = "Telephone" Then
		Return CommandProperties(
				NStr("en = 'Make a call';"),
				NStr("en = 'Make a phone call.';"),
				PictureLib.Call,
				"ContactsManagerClient.BeforePhoneCall");
	ElsIf CommandName = "SendSMS" Then
		Return CommandProperties(
				NStr("en = 'Send text message';"),
				NStr("en = 'Send text message';"),
				PictureLib.SendSMS,
				"ContactsManagerClient.BeforeCreateSMS");
	EndIf;
	
	// Commands associated with the type "Fax"
	If CommandName = "SendFax" Then
		Return CommandProperties("", "");
	EndIf;
	
	// Commands for the type "Email"
	If CommandName = "WriteEmail2" Then
		Return CommandProperties(
				NStr("en = 'Create mail';"),
				NStr("en = 'Send an email to the specified address';"),
				PictureLib.ContactInformationSendEmail,
				"ContactsManagerClient.BeforeCreateEmailMessage");
	EndIf;
	
	// Commands associated with the type "Skype"
	If CommandName = "SkypeCall" Then
		Return CommandProperties(
				NStr("en = 'Make a call';"),
				NStr("en = 'Make a Skype call';"),
				PictureLib.Call,
				"ContactsManagerClient.BeforeSkypeCall");
	ElsIf CommandName = "StartSkypeChat" Then
		Return CommandProperties(
				NStr("en = 'Start a chat';"),
				NStr("en = 'Start a Skype chat';"),
				PictureLib.SendSMS,
				"ContactsManagerClient.BeforeStartSkypeChat");
	EndIf;
	
	// Commands associated with the type "WebPage"
	If CommandName = "OpenWebPage" Then
		Return CommandProperties(
				NStr("en = 'Follow';"),
				NStr("en = 'Follow the link';"),
				PictureLib.ContactInformationGoToURL,
				"ContactsManagerClient.BeforeNavigateWebLink");
	EndIf;

	// Commands associated with the type "Other"
	If CommandName = "OpenWindowOther" Then
		Return CommandProperties("", "");
	EndIf;
		
EndFunction

// Returns a structure describing contact information commands.
// The structure is intended for ContactsManagerOverridable.OnDefineSettings
//
// Parameters:
//   Title - String   - Command title.
//   ToolTip - String   - Command tooltip.
//   Picture  - Picture - Command icon.
//   Action  - String   - The full path to the procedure to be executed.
//                            For example, "StandardSubsystemsClient.OpenMeetingDocForm".
//   ModifiesStoredData - Boolean 
//
// Returns:
//   Structure:
//     * Title - String
//     * ToolTip - String
//     * Picture  - Picture
//     * Action  - String
//     * ModifiesStoredData - Boolean
//
Function CommandProperties(Title, ToolTip, Picture = "", Action = "", ModifiesStoredData = False) Export
	
	Properties = New Structure;
	Properties.Insert("Title", Title);
	Properties.Insert("ToolTip", ToolTip);
	Properties.Insert("Picture",  ?(Picture="", New Picture(), Picture)); 
	Properties.Insert("Action",  Action);
	Properties.Insert("ModifiesStoredData", ModifiesStoredData);
	
	Return Properties;
	
EndFunction

#EndRegion

#Region Internal

// Sets the availability of contact information items on the form.
//
// Parameters:
//    Form - ClientApplicationForm - a form to be passed.
//    Items - Map of KeyAndValue - a list of contact information kinds for which access is set:
//        * Key     - MetadataObject - The subsystem where the report (report option) should be added to.
//        * Value - Boolean           - if False, an item can only be viewed.
//    ItemForPlacementName - String - a group name where the contact information is placed.
//
Procedure SetContactInformationItemAvailability(Form, Items, ItemForPlacementName = "ContactInformationGroup") Export
	For Each Item In Items Do
		
		Filter = New Structure("Kind", Item.Key);
		FoundRows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).FindRows(Filter);
		If FoundRows <> Undefined Then
			For Each FoundRow In FoundRows Do
				CIItem = Form.Items[FoundRow.AttributeName];
				CIItem.ReadOnly = Not Item.Value;
			EndDo;
			// If an item can only be viewed, remove the option to add this item to the form.
			ContactInformationParameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
			If Not Item.Value Then
				For Position = -ContactInformationParameters.ItemsToAddList.Count() + 1 To 0 Do
					ContextMenuItem = ContactInformationParameters.ItemsToAddList.Get(-Position);
					Value = ContextMenuItem.Value; // CatalogRef.ContactInformationKinds 
					If Value.Ref = Item.Key Then
						ContactInformationParameters.ItemsToAddList.Delete(-Position);
						Continue;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		
	EndDo;
	
	If Form.Items.Find("ContactInformationAddInputField") <> Undefined Then
		ContactInformationParameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
		If ContactInformationParameters.ItemsToAddList.Count() = 0 Then
			// Make the "Add" button inactive (as the context menu is empty). 
			ContactInformationAddInputField = Form.Items.ContactInformationAddInputField; // FormGroup
			ContactInformationAddInputField.Enabled = False;
		EndIf;
	EndIf;
	
EndProcedure

// Adds contact information columns to the list of columns for data import.
//
// Parameters:
//  CatalogMetadata  - MetadataObject - catalog metadata.
//  ColumnsInformation   - ValueTable - template columns.
//
Procedure ColumnsForDataImport(CatalogMetadata, ColumnsInformation) Export
	
	If CatalogMetadata.TabularSections.Find("ContactInformation") = Undefined Then
		Return;
	EndIf;
	
	Position = ColumnsInformation.Count() + 1;
	
	ContactInformationKinds = ObjectContactInformationKinds(Catalogs[CatalogMetadata.Name].EmptyRef());
	
	For Each ContactInformationKind In ContactInformationKinds Do
		ColumnName = "ContactInformation_" + StandardSubsystemsServer.TransformStringToValidColumnDescription(ContactInformationKind.Description);
		If ColumnsInformation.Find(ColumnName, "ColumnName") = Undefined Then
			ColumnsInfoRow = ColumnsInformation.Add();
			ColumnsInfoRow.ColumnName = ColumnName;
			ColumnsInfoRow.ColumnPresentation = ContactInformationKind.Presentation;
			ColumnsInfoRow.ColumnType = New TypeDescription("String");
			ColumnsInfoRow.IsRequiredInfo = False;
			ColumnsInfoRow.Position = Position;
			ColumnsInfoRow.Group = NStr("en = 'Contact information';");
			ColumnsInfoRow.Visible = True;
			ColumnsInfoRow.Width = 30;
			Position = Position + 1;
		EndIf;
	EndDo;
	
EndProcedure

// Returns a contact information type.
//
// Parameters:
//    Description - String - a contact information type as a string.
//
// Returns:
//    EnumRef.ContactInformationTypes - the corresponding type.
//
Function ContactInformationTypeByDescription(Val Description) Export
	Return Enums.ContactInformationTypes[Description];
EndFunction

Procedure OnHideAttributeValue(FullName, Value, StandardProcessing) Export
	
	TabularSectionName = StringFunctionsClientServer.SubstituteParametersToString(".%1.", "ContactInformation");
	If StrFind(FullName, TabularSectionName) = 0 Then
		Return;
	EndIf;
	
	If StrEndsWith(FullName, "ContactInformation.FieldValues") And ValueIsFilled(Value) Then
	
		StandardProcessing = False;
		Template = "<ContactInformation xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" Presentation=""%Presentation%""></ContactInformation>";
		Value = StrReplace(Template, "%Presentation%", New UUID);
	
	ElsIf StrEndsWith(FullName, "ContactInformation.Value") And ValueIsFilled(Value) Then
		
		ContactInformationFields = ContactsManagerInternal.JSONStringToStructure1(Value);
		
		If ContactInformationFields.Count() > 0 Then
		
			For Each ContactInformationField1 In ContactInformationFields Do
				
				If Not ValueIsFilled(ContactInformationField1.Value)
					Or TypeOf(ContactInformationField1.Value) = Type("Array")
					Or ContactInformationField1.Key = "type" Then
					Continue;
				EndIf;
				
				ContactInformationFields[ContactInformationField1.Key] =
					StrReplace(String(New UUID), "-", "");
					
			EndDo;
			
			Value = ContactsManagerInternal.ToJSONStringStructure(ContactInformationFields);
		Else
			Value = StrReplace(String(New UUID), "-", "");
		EndIf;
		
		StandardProcessing = False;
		
	ElsIf ValueIsFilled(Value) Then
		
		Value = StrReplace(String(New UUID), "-", "");
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

Function Email(Val ContactInformationValue) Export
	
	ContactInformationInJSONFormat = ContactInformationInJSON(ContactInformationValue, Enums.ContactInformationTypes.Email);
	
	ContactInformationAsStructure = ContactsManagerInternal.JSONToContactInformationByFields(
		ContactInformationInJSONFormat, Enums.ContactInformationTypes.Email);
		
	Return ContactInformationAsStructure.value;
	
EndFunction

// Updates a password recovery address in the contact information owner.
// For the "Users" catalog, in the user object (before writing the changes).
// For the "ExternalUsers" catalog, in the authentication object.
// 
// Parameters:
//  UserObject - CatalogObject.Users - Object before writing.
//                     - CatalogObject.ExternalUsers
//  NewAddress  - String
//  OldAddress - String
//              - Undefined - If an old infobase user does not exist
//
Procedure ChangePasswordRecoveryEmail(UserObject, NewAddress, OldAddress) Export
	
	ContactInformationOwner = ?( TypeOf(UserObject) = Type("CatalogObject.ExternalUsers"),
		UserObject.AuthorizationObject, UserObject);
	
	UserEmailAccount = ObjectContactInformation(ContactInformationOwner, 
		Enums.ContactInformationTypes.Email, CurrentSessionDate(), False);
	
	StringWithNewAddress = UserEmailAccount.Find(NewAddress, "Presentation");
	If StringWithNewAddress <> Undefined Then
		Return;
	EndIf;
	
	StringWithAddress = UserEmailAccount.Find(OldAddress, "Presentation");
	If StringWithAddress <> Undefined Then
		FillContactInformationTableRowFromPresentation(StringWithAddress, NewAddress);
		SetObjectContactInformation(ContactInformationOwner, 
			UserEmailAccount, True);
		Return;
	EndIf;
	
	ObjectContactInformationKinds = ObjectContactInformationKinds(ContactInformationOwner,
		Enums.ContactInformationTypes.Email);
	
	If ObjectContactInformationKinds.Count() = 0 Then
		Return;
	EndIf;
	
	If TypeOf(UserObject) = Type("CatalogObject.Users") Then 
		ContactInformationKind = ContactInformationKindByName("UserEmail");
		If ContactInformationKind <> Undefined Then
			ParametersOfCIType = ContactInformationKindParameters(ContactInformationKind);
			If ParametersOfCIType.AllowMultipleValueInput Then
				AddContactInformation(ContactInformationOwner,
					NewAddress, ContactInformationKind, CurrentSessionDate(), False);
				Return;
			EndIf;
		EndIf;
	EndIf;
	
	ContactInformationKind = Undefined;
	For Each KindOfObjectContactInformation In ObjectContactInformationKinds Do
		If KindOfObjectContactInformation.AllowMultipleValueInput Then
			ContactInformationKind = KindOfObjectContactInformation.Ref;
			Break;
		EndIf;
		StringWithAddress = UserEmailAccount.Find(KindOfObjectContactInformation.Ref, "Kind");
		If StringWithAddress = Undefined Then
			ContactInformationKind = KindOfObjectContactInformation.Ref;
			Break;
		EndIf;
	EndDo;
	
	If ContactInformationKind <> Undefined Then
		AddContactInformation(ContactInformationOwner,
			NewAddress, ContactInformationKind, CurrentSessionDate(), False);
	ElsIf UserEmailAccount.Count() > 0 Then
		FillContactInformationTableRowFromPresentation(UserEmailAccount[0], NewAddress);
		SetObjectContactInformation(ContactInformationOwner, UserEmailAccount, True);
	EndIf;
	
EndProcedure



Function NewEmailAddressForPasswordRecovery(Val ObjectReference, Val Email) Export
	
	Result = Undefined;
	
	If ContainsContactInformation(ObjectReference) Then
		ObjectSEmailAddress = ObjectContactInformation(ObjectReference, 
			Enums.ContactInformationTypes.Email, CurrentSessionDate(), False);
		If ObjectSEmailAddress.Count() > 0 Then
			Mail = ObjectSEmailAddress.Find(Email, "Presentation");
			If Mail = Undefined Then
				Result = ObjectSEmailAddress[0].Presentation;
			EndIf;
		Else
			Result = "";
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Parameters:
//  Form - ClientApplicationForm
//  Email - String
//  EditingAvailable - Boolean
//  IsExternalUser - Boolean
// Returns:
//   String
// 
Function DefineAnItemWithMailForPasswordRecovery(Form, Email, EditingAvailable, IsExternalUser = False) Export
	
	If IsExternalUser Then
		TypeOrTypeOfUserSEmailAddress = Enums.ContactInformationTypes.Email;
	Else
		TypeOrTypeOfUserSEmailAddress                = ContactInformationKindByName("UserEmail");
	EndIf;
	
	AttributeName = TheNameOfTheDetailsForPasswordRecovery(Form, Email, TypeOrTypeOfUserSEmailAddress);
	
	If ValueIsFilled(AttributeName)
		And Form.Items.Find(AttributeName) <> Undefined Then
		Form.Items[AttributeName].Parent.ToolTip = NStr("en = 'Used for password recovery.';");
		Form.Items[AttributeName].Parent.ToolTipRepresentation = ToolTipRepresentation.ShowRight;
		Form.Items[AttributeName].Parent.Enabled = EditingAvailable;
	EndIf;
	
	Return AttributeName;
	
EndFunction

// Restore password.

Function EmailDescriptionStringForPasswordRecoveryFromFormData(Form, TypeOrTypeOfUserSEmailAddress, Email = "") Export
	
	ContactInformation = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form);
	
	Filter = New Structure;
	If TypeOf(TypeOrTypeOfUserSEmailAddress) = Type("CatalogRef.ContactInformationKinds") Then
		Filter.Insert("Kind",           TypeOrTypeOfUserSEmailAddress);
	ElsIf TypeOf(TypeOrTypeOfUserSEmailAddress) = Type("EnumRef.ContactInformationTypes") Then
		Filter.Insert("Type",           TypeOrTypeOfUserSEmailAddress);
	EndIf;
	
	If ValueIsFilled(Email) Then
		Filter.Insert("Presentation", Email);
	EndIf;
	
	FoundRows = ContactInformation.FindRows(Filter);
	If FoundRows.Count() > 0 Then
		Return FoundRows[0];
	EndIf;
	
	Return Undefined;
	
EndFunction

// See PropertyManagerOverridable.OnGetPredefinedPropertiesSets.
Procedure OnGetPredefinedPropertiesSets(Sets) Export
	Set = Sets.Rows.Add();
	Set.Name = "Catalog_WorldCountries";
	Set.Id = New UUID("38186b5b-6c32-40fa-b894-8eadad18bf62");
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Initialization of items on the form of a contact information owner object.

Procedure DefineContactInformationParametersByOwner(Form, Object, ContactInformationParameters, IsMainObjectParameters, HiddenKinds)
	
	HiddenKinds = New Array;
	For Each ContactInformationParameter In Form.ContactInformationParameters Do
		
		If ContactInformationParameter.Value.Owner = Object.Ref
			Or Form.ContactInformationParameters.Count() = 1 Then
				
				ContactInformationParameters = ContactInformationParameter.Value;
				HiddenKinds = ContactInformationParameters.HiddenKinds;
				Return;
		EndIf;
		
		IsMainObjectParameters = False;
		
	EndDo;

EndProcedure

// Parameters:
//   Form - ClientApplicationForm
//   AttributesToBeAdded - Array of FormAttribute
//   ObjectName - String
//   ItemsPlacedOnForm - Map of KeyAndValue:
//     * Key - CatalogRef.ContactInformationKinds
//     * Value - Boolean
//   ContactInformation - ValueTreeRowCollection:
//    * Kind              - CatalogRef.ContactInformationKinds   - a contact information kind.
//    * PredefinedKindName - String
//    * PredefinedDataName - String
//    * Type              - EnumRef.ContactInformationTypes - contact information type.
//    * Mandatory - Boolean
//    * FieldKindOther - String
//    * AllowMultipleValueInput - Boolean
//    * Description - String
//    * StoreChangeHistory - Boolean
//    * EditingOption - String
//    * IsTabularSectionAttribute - Boolean
//    * AddlOrderingAttribute - Boolean
//    * InternationalAddressFormat - Boolean
//    * EnterNumberByMask - Boolean
//    * IsHistoricalContactInformation - Boolean
//    * Presentation    - String - a contact information presentation.
//    * FieldValues    - String - an obsolete XML file matching the ContactInformation or Address XDTO packages. For
//                                  backward compatibility.
//    * Value    - String
//    * ValidFrom    - Date
//    * LineNumber    - Number
//    * TabularSectionRowID    - Number
//    * AttributeName    - String
//    * DeletionMark    - Boolean
//    * Comment    - String
//   DeferredInitialization - Boolean
//                           - Array
//   URLProcessing - Boolean
//
Procedure GenerateContactInformationAttributes(Val Form, Val AttributesToBeAdded, Val ObjectName, Val ItemsPlacedOnForm,
	Val ContactInformation, Val DeferredInitialization, Val URLProcessing)
	
	String1500            = New TypeDescription("String", , New StringQualifiers(1500));
	FormattedString = New TypeDescription("FormattedString");
	
	GeneratedAttributes = Common.CopyRecursive(ItemsPlacedOnForm);
	PreviousKind      = Undefined;
	SequenceNumber    = 1;
	
	For Each ObjectOfContactInformation In ContactInformation Do
		
		If ObjectOfContactInformation.DeletionMark And IsBlankString(ObjectOfContactInformation.Value) Then
			Continue;
		EndIf;
			
		If ObjectOfContactInformation.IsTabularSectionAttribute Then
			
			CIKindName = ObjectOfContactInformation.PredefinedKindName;
			Position = StrFind(CIKindName, ObjectName);
			TabularSectionName = Mid(CIKindName, Position + StrLen(ObjectName));
			
			PreviousKind = Undefined;
			AttributeName = "";
			
			ObjectOfContactInformation.Rows.Sort("AddlOrderingAttribute");
			
			For Each CIRow In ObjectOfContactInformation.Rows Do
				
				CurrentKind = CIRow.Kind;
				If CurrentKind <> PreviousKind Then
					
					AttributeName = "ContactInformationField" + TabularSectionName + StrReplace(CurrentKind.UUID(), "-", "x")
						+ ObjectOfContactInformation.Rows.IndexOf(CIRow);
					AttributesPath = "Object." + TabularSectionName;
					
					AttributesToBeAdded.Add(New FormAttribute(AttributeName, String1500, AttributesPath, CIRow.Description, True));
					AttributesToBeAdded.Add(New FormAttribute(AttributeName + "Value", New TypeDescription("String"), AttributesPath,, True));
					PreviousKind = CurrentKind;
					
				EndIf;
				
				CIRow.AttributeName = AttributeName;
				
			EndDo;
			
		Else
			
			If ObjectOfContactInformation.IsHistoricalContactInformation Then
				AdjustContactInformation(Form, ObjectOfContactInformation);
				Continue;
			EndIf;
			
			CurrentKind = ObjectOfContactInformation.Kind;
			
			CreatedAttribute = GeneratedAttributes.Get(CurrentKind);
			If CreatedAttribute <> Undefined Then
				CreatedAttribute = CurrentKind;
			EndIf;
			
			If Not ObjectOfContactInformation.IsAlwaysDisplayed And IsBlankString(ObjectOfContactInformation.Value) And CreatedAttribute = Undefined Then
				Continue;
			EndIf;
			
			If CurrentKind <> PreviousKind Then
				PreviousKind = CurrentKind;
				SequenceNumber = 1;
			Else
				SequenceNumber = SequenceNumber + 1;
			EndIf;
			
			HasCommentField = HasCommentFieldForContactInfoType(ObjectOfContactInformation.Type, URLProcessing);
			
			If CreatedAttribute = Undefined Then
				ObjectOfContactInformation.AttributeName = "ContactInformationField" + StrReplace(CurrentKind.UUID(), "-", "x")
					+ Format(SequenceNumber, "NG=0");
				If HasCommentField Then
					ObjectOfContactInformation.AttributeNameComment = "CommentContactInformationField" + StrReplace(
						CurrentKind.UUID(), "-", "x") + Format(SequenceNumber, "NG=0");
				EndIf;
				If Not DeferredInitialization Then
					
					AttributeType = String1500;
					If ObjectOfContactInformation.Type = Enums.ContactInformationTypes.WebPage And URLProcessing Then
						AttributeType = FormattedString;
					EndIf;
					
					AttributesToBeAdded.Add(
						New FormAttribute(ObjectOfContactInformation.AttributeName, AttributeType,, ObjectOfContactInformation.Description, True));
					If HasCommentField Then					
						AttributesToBeAdded.Add(
							New FormAttribute(ObjectOfContactInformation.AttributeNameComment, AttributeType,, ObjectOfContactInformation.Description, True));
					EndIf;
				EndIf;
			Else
				ObjectOfContactInformation.AttributeName = "ContactInformationField" + ObjectOfContactInformation.PredefinedKindName;
				If HasCommentField Then
					ObjectOfContactInformation.AttributeNameComment = "CommentContactInformationField" + ObjectOfContactInformation.PredefinedKindName;
				EndIf;
				GeneratedAttributes.Delete(CreatedAttribute);
			EndIf;
			
			AdjustContactInformation(Form, ObjectOfContactInformation);
		EndIf;
	EndDo;
	
	// Add new attributes.
	If AttributesToBeAdded.Count() > 0 Then
		Form.ChangeAttributes(AttributesToBeAdded);
	EndIf;

EndProcedure

Procedure HideContactInformation(Val Form, Val AttributesToBeAdded, OutputParameters)
	
	If AttributesToBeAdded.Count() > 0 Then
		Form.ChangeAttributes(AttributesToBeAdded);
	EndIf;
	AddedAttributes = New Array;
	For Each AttributeToAdd In AttributesToBeAdded Do
		If IsBlankString(AttributeToAdd.Path) Then
			AddedAttributes.Add(AttributeToAdd.Name);
		EndIf;
	EndDo;
	
	AdditionalParameters = AdditionalParametersOfContactInfoOutput(OutputParameters.DetailsOfCommands,
		OutputParameters.ShouldShowIcons, OutputParameters.ItemsPlacedOnForm, OutputParameters.AllowAddingFields,
		OutputParameters.ExcludedKinds, OutputParameters.HiddenKinds);
		
	AdditionalParameters.PositionOfAddButton = OutputParameters.PositionOfAddButton;
	AdditionalParameters.CommentFieldWidth = OutputParameters.CommentFieldWidth;	
		
	ContactInformationParameters = ContactInformationOutputParameters(Form, OutputParameters.ItemForPlacementName,
		OutputParameters.CITitleLocation, OutputParameters.DeferredInitialization, AdditionalParameters);
		
	ContactInformationParameters.AddedAttributes = AddedAttributes;
	ContactInformationParameters.Owner             = OutputParameters.ObjectReference;
	
	If Not IsBlankString(OutputParameters.ItemForPlacementName) Then
		Form.Items[OutputParameters.ItemForPlacementName].Visible = False;
	EndIf;
	
EndProcedure

Procedure AddAdditionalContactInformationFieldButton(Val Form, Val ItemForPlacementName)
	
	ItemContactInformationParameters = Form.ContactInformationParameters[ItemForPlacementName]; // See ContactInformationOutputParameters
	
	LongDesc = NStr("en = 'Add additional contact information field';");
	CommandGroup             = Group("ContactInformationGroupAddInputField" + ItemForPlacementName, 
		Form, LongDesc, ItemForPlacementName, "GroupContactInfoCommandVals"+ItemForPlacementName);
	CommandGroup.Representation = UsualGroupRepresentation.NormalSeparation;
	If ItemContactInformationParameters.PositionOfAddButton = "Auto"
		Or ItemContactInformationParameters.PositionOfAddButton = "Right" Then
		HorizontalAlignInGroup = ItemHorizontalLocation.Right;
	Else
		HorizontalAlignInGroup = ItemHorizontalLocation.Left;
	EndIf;
	CommandGroup.HorizontalAlignInGroup = HorizontalAlignInGroup;
	
	CommandName          = "ContactInformationAddInputField" + ItemForPlacementName;
	Command             = Form.Commands.Add(CommandName);
	Command.ToolTip   = LongDesc;
	Command.Representation = ButtonRepresentation.PictureAndText;
	If Not Common.IsMobileClient() Then
		Command.Picture    = PictureLib.DropDownList;
	EndIf;
	Command.Action    = "Attachable_ContactInformationExecuteCommand";
	
	ItemContactInformationParameters.AddedItems.Add(CommandName, 9, True);
	
	Button             = Form.Items.Add(CommandName,Type("FormButton"), CommandGroup);
	Button.Enabled = Not Form.Items[ItemForPlacementName].ReadOnly;
	Button.Title   = "+ " + NStr("en = 'Phone number, address';");
	Command.ModifiesStoredData     = True;
	Button.CommandName                     = CommandName;
	Button.HorizontalAlignInGroup = HorizontalAlignInGroup;
	Button.PictureLocation              = FormButtonPictureLocation.Right;
	ItemContactInformationParameters.AddedItems.Add(CommandName, 2, False);
	
	If Not Common.IsMobileClient() And ItemContactInformationParameters.PositionOfAddButton = "Auto" Then
		// Determine the button display option (left side, indented, non-indented).
		// Handle the scenario where the form contains both dynamic and static information.
		ItemsOfPlacementGroup = Form.Items[ItemForPlacementName].ChildItems;
		GroupCountInMain = ItemsOfPlacementGroup.Count();
		ItemsOfContactInfoValGroup = Form.Items["GroupOfContactInfoValues"+ItemForPlacementName].ChildItems;
		GroupCount = ItemsOfContactInfoValGroup.Count();
		
		If GroupCount = 0 And GroupCountInMain = 1 Then
			CommandGroup.HorizontalAlignInGroup = ItemHorizontalLocation.Left;
			Button.HorizontalAlignInGroup = ItemHorizontalLocation.Left;
		Else
			If GroupCount = 0 And GroupCountInMain > 1 Then
				LastGroup = ItemsOfPlacementGroup[GroupCountInMain - 2];
			ElsIf GroupCount > 0 Then
				LastGroup = ItemsOfContactInfoValGroup[GroupCount - 1];
			EndIf;
			
			HasContactInfoStaticButton = HasContactInfoButton(ItemsOfPlacementGroup, False);
			HasContactInfoDynamicButton = HasContactInfoButton(ItemsOfContactInfoValGroup, False);
			
			If LastGroup <> Undefined And HasHyperlink(LastGroup) Then
				CommandGroup.HorizontalAlignInGroup = ItemHorizontalLocation.Left;
				Button.HorizontalAlignInGroup = ItemHorizontalLocation.Left;
			ElsIf LastGroup <> Undefined And Not HasContactInfoButton(LastGroup, True)
				And (HasContactInfoStaticButton Or HasContactInfoDynamicButton) Then
				Decoration = Form.Items.Add("IndentAdd", Type("FormDecoration"), CommandGroup);
				Decoration.Type       = FormDecorationType.Picture;
				Decoration.Width    = 3;
				Decoration.Title = NStr("en = 'Indent';");
				Decoration.Height    = 1;		
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure AddNoteOnFormSettingsReset(Val Form, Val ItemForPlacementName, Val DeferredInitialization)
	
	GroupForPlacement = Form.Items[ItemForPlacementName];
	// In case of deferred initialization and the page has no elements, 1C:Enterprise hides the page.
	// Therefore, create a temporary element that is deleted when the page opens.
	If DeferredInitialization
		And GroupForPlacement.Type = FormGroupType.Page 
		And Form.Items.Find("ContactInformationStub") = Undefined Then
		
		PagesGroup = GroupForPlacement.Parent; // FormGroup
		PageHeader = ?(ValueIsFilled(GroupForPlacement.Title), GroupForPlacement.Title, GroupForPlacement.Name);
		PageGroupHeader1 = ?(ValueIsFilled(PagesGroup.Title), PagesGroup.Title, PagesGroup.Name);
		
		PlacementWarning = NStr("en = 'To view the contact information, display the ""%1"" group under any other item in the ""%2"" group. To do so, click More actions — Change form.';");
		PlacementWarning = StringFunctionsClientServer.SubstituteParametersToString(PlacementWarning,
		PageHeader, PageGroupHeader1);
		ToolTipText = NStr("en = 'To restore a form to the default settings, do the following:
		| • Select More actions — Change form.
		| • In the Customize form window that opens, select More actions — Restore default settings.';");
		
		Decoration = Form.Items.Add("ContactInformationStub", Type("FormDecoration"), GroupForPlacement);
		Decoration.Title              = PlacementWarning;
		Decoration.ToolTipRepresentation   = ToolTipRepresentation.Button;
		Decoration.ToolTip              = ToolTipText;
		Decoration.TextColor             = StyleColors.ErrorNoteText;
		Decoration.AutoMaxHeight = False;
	EndIf;

EndProcedure

Function TitleLeft(Val CITitleLocation = Undefined)
	
	If ValueIsFilled(CITitleLocation) Then
		CITitleLocation = PredefinedValue(CITitleLocation);
	Else
		CITitleLocation = FormItemTitleLocation.Left;
	EndIf;
	
	Return (CITitleLocation = FormItemTitleLocation.Left);
	
EndFunction

Procedure ModifyComment(Form, AttributeName, ItemForPlacementName, ContactInformationType)
	
	ContactInformationDetails = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form);
	
	Filter = New Structure("AttributeName", AttributeName);
	FoundRow = ContactInformationDetails.FindRows(Filter)[0];
	
	If ContactsManagerClientServer.IsJSONContactInformation(FoundRow.Value) Then
		ContactInformationByFields = ContactsManagerInternal.JSONToContactInformationByFields(
			FoundRow.Value, Undefined);
		ContactInformationByFields.Comment = FoundRow.Comment;
		FoundRow.Value = ContactsManagerInternal.ToJSONStringStructure(ContactInformationByFields);
	EndIf;
	
	ContactInfoParameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
	URLProcessing = ContactInfoParameters.URLProcessing;
	If Not HasCommentFieldForContactInfoType(ContactInformationType, URLProcessing) Then
		InputField = Form.Items.Find(AttributeName); // FormItemAddition
		If ContactInformationType = Enums.ContactInformationTypes.Address 
			And TypeOf(InputField.ExtendedToolTip.Title) = Type("FormattedString") Then	
			CommandsForOutput = ContactsManagerClientServer.CommandsToOutputToForm(ContactInfoParameters,
				ContactInformationType, FoundRow.Kind, FoundRow.StoreChangeHistory);
			InputField.ExtendedToolTip.Title = ContactsManagerClientServer.ExtendedTooltipForAddress(
				CommandsForOutput, FoundRow.Presentation, FoundRow.Comment);
		Else
			InputField.ExtendedToolTip.Title = FoundRow.Comment;
		EndIf;
	EndIf;
	
EndProcedure

Procedure AddContactInformationRow(Form, Result, ItemForPlacementName, IsNewCIKind = False, AddressesCount = Undefined, NextRow = Undefined)
	
	AddNewValue = TypeOf(Result) = Type("Structure");
	
	If AddNewValue Then
		Result.Property("ItemForPlacementName", ItemForPlacementName);
		
		KindToAdd = Result.KindToAdd;
		If TypeOf(KindToAdd)= Type("CatalogRef.ContactInformationKinds") Then
			CIKindInformation = Common.ObjectAttributesValues(KindToAdd, "Type, Description, EditingOption, FieldKindOther, EnterNumberByMask, PhoneNumberMask");
		Else
			CIKindInformation = KindToAdd;
			KindToAdd    = KindToAdd.Ref;
		EndIf;
	Else
		CIKindInformation = Result;
		KindToAdd    = Result.Kind;
	EndIf;
	
	ContactInformationTable1 = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form);
	FilterByType = New Structure("Kind, IsHistoricalContactInformation", KindToAdd, False);
	
	ContactInformationParameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
	URLProcessing = ContactInformationParameters.URLProcessing;
	HasCommentField = HasCommentFieldForContactInfoType(CIKindInformation.Type, URLProcessing);
		
	If AddNewValue Then
		
		FoundRows = ContactInformationTable1.FindRows(FilterByType);
		
		KindRowsCount = FoundRows.Count();
		If KindRowsCount > 0 Then
			LastRow = FoundRows.Get(KindRowsCount - 1);
			RowToAddIndex = ContactInformationTable1.IndexOf(LastRow) + 1;
		Else
			FilterByLocation = New Structure("ItemForPlacementName", ItemForPlacementName);
			FoundRows = ContactInformationTable1.FindRows(FilterByLocation);
			GroupRowCount = FoundRows.Count();
			If GroupRowCount > 0 Then
				LastRow = FoundRows.Get(GroupRowCount - 1);
				RowToAddIndex = ContactInformationTable1.IndexOf(LastRow) + 1;
			Else
				RowToAddIndex = ContactInformationTable1.Count();
			EndIf;
		EndIf;
		
		If RowToAddIndex >= ContactInformationTable1.Count() Then
			IsLastRow = True;
		Else
			NextTableRow = ContactInformationTable1.Get(RowToAddIndex);
			IsLastRow = NextTableRow.ItemForPlacementName <> ItemForPlacementName;
		EndIf;
		
		NewRow  = ContactInformationTable1.Insert(RowToAddIndex);
		AttributeName = StringFunctionsClientServer.SubstituteParametersToString("%1%2%3",
			"ContactInformationField",
			StrReplace(KindToAdd.UUID(), "-", "x"),
			Format(KindRowsCount + 1, "NG=0"));
		AttributeNameComment = "";
		If HasCommentField Then
			AttributeNameComment = StringFunctionsClientServer.SubstituteParametersToString("%1%2%3%4",
			"Comment", "ContactInformationField",
			StrReplace(KindToAdd.UUID(), "-", "x"),
			Format(KindRowsCount + 1, "NG=0"));
		EndIf;
		NewRow.AttributeName              = AttributeName;
		NewRow.AttributeNameComment   = AttributeNameComment;
		NewRow.Kind                       = KindToAdd;
		NewRow.Type                       = CIKindInformation.Type;
		NewRow.ItemForPlacementName  = ItemForPlacementName;
		NewRow.IsTabularSectionAttribute = False;		
		
		If URLProcessing = True And CIKindInformation.Type = Enums.ContactInformationTypes.WebPage Then
			AttributeTypeDetails = New TypeDescription("FormattedString");
		Else
			AttributeTypeDetails = New TypeDescription("String", , New StringQualifiers(500));
		EndIf;
		
		AttributesToAddArray = New Array;
		AttributesToAddArray.Add(New FormAttribute(AttributeName, AttributeTypeDetails,, CIKindInformation.Description, True));
		If HasCommentField Then
			AttributesToAddArray.Add(New FormAttribute(AttributeNameComment, AttributeTypeDetails,, CIKindInformation.Description, True));
		EndIf;
		Form.ChangeAttributes(AttributesToAddArray);
		
		HasComment = False;
		Mandatory = False;
	Else
		IsLastRow = NextRow = Undefined;
		AttributeName = CIKindInformation.AttributeName;
		AttributeNameComment = CIKindInformation.AttributeNameComment;
		HasComment = ValueIsFilled(CIKindInformation.Comment);
		Mandatory = CIKindInformation.Mandatory;
	EndIf;
	
	KindToAddDescription = Common.ObjectAttributeValue(KindToAdd, "Description");
	
	// Draw items on the form.
	If Common.IsMobileClient() And ContactInformationParameters.ShouldShowIcons Then
		GroupStringsTitle = Group("TitleGroup" + AttributeName, Form, KindToAddDescription, ItemForPlacementName, "GroupOfContactInfoValues" + ItemForPlacementName, 6);
		GroupStringsTitle.Group = ChildFormItemsGroup.Vertical;
		GroupStringsTitle.Representation = UsualGroupRepresentation.NormalSeparation; 
		GroupLinesTitlesPicture = Group("GroupTitlePicture" + AttributeName, Form, KindToAddDescription, ItemForPlacementName, "TitleGroup" + AttributeName);
		Decoration = Form.Items.Add("Picture" + AttributeName, Type("FormDecoration"), GroupLinesTitlesPicture);
		Decoration.Title = NStr("en = 'Picture';");
		Decoration.Type       = FormDecorationType.Picture;
		Decoration.Width    = 2;
		Decoration.Picture = PictureContactInfoType(CIKindInformation.Type);
		ContactInformationParameters.AddedItems.Add("Picture" + AttributeName, 2, False);
		TitleDecoration = Form.Items.Add("Title" + AttributeName, Type("FormDecoration"), GroupLinesTitlesPicture);
		TitleDecoration.Title = Upper(KindToAddDescription);
		TitleDecoration.Type       = FormDecorationType.Label;
		ContactInformationParameters.AddedItems.Add("Title" + AttributeName, 2, False);
		ParentGroupName = "TitleGroup" + AttributeName;
	Else	 
		 ParentGroupName = "GroupOfContactInfoValues" + ItemForPlacementName;
	EndIf;
	
	StringGroup1 = Group("Group" + AttributeName, Form, KindToAddDescription, ItemForPlacementName, 
		ParentGroupName);
	
	If Common.IsMobileClient() And Not ContactInformationParameters.ShouldShowIcons Then
		StringGroup1.ShowTitle = True;
	EndIf;
	
	Parent = Form.Items["GroupOfContactInfoValues" + ItemForPlacementName];
	If Common.IsMobileClient() And ContactInformationParameters.ShouldShowIcons Then
		
		If Not IsLastRow And NextRow = Undefined Then
			NextGroupName = "TitleGroup" + LastRow.AttributeName;
			If Form.Items.Find(NextGroupName) <> Undefined Then
				NextGroupIndex = Parent.ChildItems.IndexOf(Form.Items[NextGroupName]) + 1;
				NextGroup1 = Parent.ChildItems.Get(NextGroupIndex);
				Form.Items.Move(GroupStringsTitle, Parent, NextGroup1);
			EndIf;
		EndIf;
		
	Else
		If Not IsLastRow And NextRow = Undefined Then
			NextGroupName = "Group" + LastRow.AttributeName;
			If Form.Items.Find(NextGroupName) <> Undefined Then
				NextGroupIndex = Parent.ChildItems.IndexOf(Form.Items[NextGroupName]) + 1;
				NextGroup1 = Parent.ChildItems.Get(NextGroupIndex);
				Form.Items.Move(StringGroup1, Parent, NextGroup1);
			EndIf;
		EndIf;
		
	EndIf;
		
	If Common.IsMobileClient() And ContactInformationParameters.ShouldShowIcons Then
		NameOfNextGroupOfCurrentKind = "TitleGroup" + AttributeName;
	Else
		NameOfNextGroupOfCurrentKind = "Group" + AttributeName;
	EndIf;
	
	// Handling situations when multiple dynamic and static contact information is displayed on the form at the same time.
	If Form.Items.Find(NameOfNextGroupOfCurrentKind) <> Undefined Then
		
		Filter = New Structure("AttributeName", AttributeName);
		FoundRowsOfCurrentKind = ContactInformationTable1.FindRows(Filter);
		If FoundRowsOfCurrentKind.Count() > 0 Then
			CurrentKind = FoundRowsOfCurrentKind[0].Kind;
		EndIf;
		
		IndexOfPreviousKindGroup = Parent.ChildItems.IndexOf(Form.Items[NameOfNextGroupOfCurrentKind]) - 1;
		If IndexOfPreviousKindGroup >= 0 Then
			PreviousKindGroup = Parent.ChildItems.Get(IndexOfPreviousKindGroup);

			If PreviousKindGroup <> Undefined Then

				If Common.IsMobileClient() And ContactInformationParameters.ShouldShowIcons Then		
					Filter = New Structure("AttributeName", StrReplace(PreviousKindGroup.Name, "TitleGroup", ""));
				Else
					Filter = New Structure("AttributeName", StrReplace(PreviousKindGroup.Name, "Group", ""));
				EndIf;
				FoundRowsOfPreviousKind = ContactInformationTable1.FindRows(Filter);
				If FoundRowsOfPreviousKind.Count() > 0 Then
					PreviousKind = FoundRowsOfPreviousKind[0].Kind;
				EndIf;

				If CurrentKind <> PreviousKind Then
					IsNewCIKind = True;
				EndIf;
			EndIf;
		Else
			IsNewCIKind = True;
		EndIf;
	EndIf;

	If ContactInformationParameters.ShouldShowIcons And Not Common.IsMobileClient() Then
		StringGroup1.United = False;
		Decoration = Form.Items.Add("Picture" + AttributeName, Type("FormDecoration"), StringGroup1);
		Decoration.Title = NStr("en = 'Picture';");
		Decoration.Type       = FormDecorationType.Picture;
		Decoration.Width    = 2;
		ContactInformationParameters.AddedItems.Add("Picture" + AttributeName, 2, False);
		If IsNewCIKind Then
			Decoration.Picture = PictureContactInfoType(CIKindInformation.Type);
		Else
			Decoration.Title = NStr("en = 'Indent';");
			Decoration.Height    = 1;
		EndIf;
	EndIf;
	
	If HasCommentField Then
		GroupFIeldComment  = Group("GroupComment" + AttributeName, Form,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 field, comment';"),
			KindToAddDescription), ItemForPlacementName, "Group" + AttributeName, 4);
	Else
		GroupFIeldComment = StringGroup1;
	EndIf;
	
	If ContactInformationParameters.HasDestinationGroupWidthLimit Then
		Form.Items[ItemForPlacementName].HorizontalStretch = False;
	EndIf;
	
	InputField = GenerateInputField(Form, GroupFIeldComment, CIKindInformation, AttributeName, ItemForPlacementName, IsNewCIKind, Mandatory);
	
	If Common.IsMobileClient() Then
		InputField.TitleLocation = FormItemTitleLocation.None;
	EndIf;
	
	If HasCommentField Then
		CommentField = Form.Items.Add(AttributeNameComment, Type("FormField"), GroupFIeldComment);
		CommentField.Type = FormFieldType.InputField;
		CommentField.Title = NStr("en = 'Comment';");
		CommentField.DataPath = AttributeNameComment;
		CommentField.TitleLocation = FormItemTitleLocation.None;
		CommentField.SkipOnInput = True;
		CommentField.InputHint = NStr("en = 'Note';");
		CommentField.AutoMaxWidth = False;
		CommentFieldWidth = ?(ContactInformationParameters.HasDestinationGroupWidthLimit, ContactInformationParameters.CommentFieldWidth, 30);
		CommentField.MaxWidth = CommentFieldWidth;
		CommentField.Width = CommentFieldWidth;
		CommentField.HorizontalStretch = False;
		CommentField.VerticalStretch = False;
		CommentField.SetAction("OnChange", "Attachable_ContactInformationOnChange");
		ContactInformationParameters.AddedItems.Add(AttributeNameComment, 2, False);
		If Common.IsMobileClient() Then
			CommentField.MultiLine = True;
		EndIf;
	ElsIf HasComment Then
		InputField.ExtendedTooltip.Title              = CIKindInformation.Comment;
		InputField.ExtendedTooltip.AutoMaxWidth = False;
		InputField.ExtendedTooltip.MaxWidth     = InputField.Width;
		InputField.ExtendedTooltip.Width                 = InputField.Width;
	EndIf;
	
	If AddressesCount = Undefined Then
		FIlter_By_Type = New Structure("Type", Enums.ContactInformationTypes.Address);
		AddressesCount = ContactInformationTable1.FindRows(FIlter_By_Type).Count();
	EndIf;
	
	CreateAction(Form, CIKindInformation, AttributeName, StringGroup1, ItemForPlacementName);
	
	If Not IsNewCIKind Then
		If ContactInformationTable1.Count() > 1 And ContactInformationTable1[0].Property("IsHistoricalContactInformation") Then
			MoveContextMenuItem(InputField, Form, 1, ItemForPlacementName);
			FoundRows = ContactInformationTable1.FindRows(FilterByType);
			If FoundRows.Count() > 1 Then
				PreviousString = FoundRows.Get(FoundRows.Count() - 2);
				MoveContextMenuItem(Form.Items[PreviousString.AttributeName], Form, - 1, ItemForPlacementName);
			EndIf;
		EndIf;
	EndIf;
	
	If AddNewValue Then
		Form.CurrentItem = Form.Items[AttributeName];
		If CIKindInformation.Type = Enums.ContactInformationTypes.Address
			And CIKindInformation.EditingOption = "Dialog" Then
			Result.Insert("AddressFormItem", AttributeName);
		EndIf;
	EndIf;
	
EndProcedure

Function GenerateInputField(Form, Parent, CIKindInformation, AttributeName, ItemForPlacementName,IsNewCIKind = False, Mandatory = False)
	
	ContactInformationParameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
	URLProcessing = ContactInformationParameters.URLProcessing;
	
	TitleLeft = TitleLeft(ContactInformationParameters.TitleLocation);
	Item = Form.Items.Add(AttributeName, Type("FormField"), Parent); // FormField, FormFieldExtensionForATextBox, FormFieldExtensionForALabelField
	Item.DataPath = AttributeName;
	
	HasDestinationGroupWidthLimit = ContactInformationParameters.HasDestinationGroupWidthLimit;
	
	If CIKindInformation.EditingOption = "Dialog" And CIKindInformation.Type = Enums.ContactInformationTypes.Address Then
		
			Item.Type = FormFieldType.LabelField;
			Item.Hyperlink = True;
			Item.SetAction("Click", "Attachable_ContactInformationOnClick");
			If IsBlankString(Form[AttributeName]) Then
				Form[AttributeName] = ContactsManagerClientServer.BlankAddressTextAsHyperlink();
			EndIf;
		
	ElsIf CIKindInformation.Type = Enums.ContactInformationTypes.WebPage And URLProcessing Then
		
		Item.Type = FormFieldType.LabelField;
		Item.SetAction("URLProcessing", "Attachable_ContactInformationURLProcessing");
		
		If TypeOf(CIKindInformation) <> Type("Structure") And ContactsManagerClientServer.IsJSONContactInformation(CIKindInformation.Value) Then
			ContactInformation = ContactsManagerInternal.JSONToContactInformationByFields(CIKindInformation.Value, Enums.ContactInformationTypes.WebPage);
			WebsiteAddress    = ContactInformation.value;
			Presentation = ?(ContactInformation.Property("name") And ValueIsFilled(ContactInformation.name), ContactInformation.name, CIKindInformation.Presentation);
		Else
			WebsiteAddress = "";
			Presentation = ContactsManagerClientServer.BlankAddressTextAsHyperlink();
		EndIf;
		
		Form[AttributeName] = ContactsManagerClientServer.WebsiteAddress(Presentation, WebsiteAddress, Form.ReadOnly);
		
	Else
		
		Item.Type = FormFieldType.InputField;
		If CIKindInformation.EditingOption = "Dialog" And CIKindInformation.Type <> Enums.ContactInformationTypes.WebPage Then
			Item.TextEdit = False;
		EndIf;
		
		Item.SetAction("Clearing", "Attachable_ContactInformationClearing");
		
		If CIKindInformation.Type = Enums.ContactInformationTypes.Address Then
			Item.SetAction("AutoComplete",      "Attachable_ContactInformationAutoComplete");
			Item.SetAction("ChoiceProcessing", "Attachable_ContactInformationChoiceProcessing");
		EndIf;
		If Common.IsMobileClient() Then
			Item.MultiLine = True;
		EndIf;
		
	EndIf;
	
	Item.ToolTipRepresentation = ToolTipRepresentation.ShowBottom;
	Item.HorizontalStretch = False;
	Item.VerticalStretch = False;
	
	Item.TitleHeight = ?(Common.IsMobileClient(), 1, 3);
	
	SetEntryFieldsProperties(CIKindInformation, Item, Form, AttributeName, URLProcessing);
	
	If Not IsNewCIKind Then
		Item.HorizontalAlignInGroup = ItemHorizontalLocation.Right;
		Item.TitleTextColor = StyleColors.FormBackColor;
	EndIf;
	
	Item.TitleLocation = ?(TitleLeft, FormItemTitleLocation.Left, FormItemTitleLocation.Top);
	If TitleLeft Then
		Item.TitleLocation = FormItemTitleLocation.Left;
	Else
		Item.TitleLocation = FormItemTitleLocation.Top;
	EndIf;
	
	ContactInformationParameters.AddedItems.Add(AttributeName, 2, False);
	
	If CIKindInformation.Type = Enums.ContactInformationTypes.Address And Not CIKindInformation.DeletionMark Then
		// Populate.
		GroupAddressSubmenu = Form.Items.Add("ContextSubmenuCopyAddresses" + AttributeName, Type(
			"FormGroup"), Item.ContextMenu);
		GroupAddressSubmenu.Type = FormGroupType.Popup;
		GroupAddressSubmenu.Representation = ButtonRepresentation.Text;
		GroupAddressSubmenu.Title = NStr("en = 'Fill';");
	EndIf;
	
	If Mandatory And IsNewCIKind And Item.Type = FormFieldType.InputField Then
		Item.AutoMarkIncomplete = True;
	EndIf;
	
	// Edit in dialog.
	If CanEditContactInformationTypeInDialog(CIKindInformation.Type)
		And Item.Type = FormFieldType.InputField And CIKindInformation.EditingOption <> "InputField" Then
		
		ChoiceAvailable = Not CIKindInformation.DeletionMark And CIKindInformation.EditingOption <> "InputField";
		
		If ChoiceAvailable And Not Form.ReadOnly Then
			Item.ChoiceButton = True;
			Item.SetAction("StartChoice", "Attachable_ContactInformationStartChoice");
		Else
			Item.ChoiceButton   = False;
			If ValueIsFilled(Form[AttributeName]) Then
				Item.OpenButton = True;
				Item.SetAction("Opening", "Attachable_ContactInformationOnClick");
			EndIf;
		EndIf;
		
	EndIf;
	
	Item.SetAction("OnChange", "Attachable_ContactInformationOnChange");
	
	If CIKindInformation.DeletionMark Then
		
		Item.TitleFont = StyleFonts.DeletedAttributeTitleFont;
		If Not CIKindInformation.EditingOption = "Dialog" Then
			Item.ClearButton        = True;
			Item.TextEdit = False;
			Item.Width = Item.Width - 2;
		Else
			Item.ReadOnly       = True;
		EndIf;
		
	EndIf;
	
	If HasDestinationGroupWidthLimit Then
		Item.Width = 0;
		Item.MaxWidth = 0;
		Item.AutoMaxWidth = False;
		Item.HorizontalStretch = True
	EndIf;
	
	Return Item;
	
EndFunction

Procedure PrepareStaticItem(Form, CIRow, CreatedItems, CreatedElement, ShouldShowIcons, ItemForPlacementName)
	
	CreatedItems.Delete(CreatedElement);
	
	If Form.ReadOnly Then
		ItemOnForm = Form.Items[CIRow.AttributeName];
		If ItemOnForm.Type = FormFieldType.InputField Then
			If CanEditContactInformationTypeInDialog(CIRow.Type) Then
				ItemOnForm.ChoiceButton = False;
				If ValueIsFilled(Form[CIRow.AttributeName]) Then
					ItemOnForm.OpenButton = True;
					ItemOnForm.SetAction("Opening", "Attachable_ContactInformationOnClick");
				EndIf;
			Else
				ItemOnForm.ReadOnly = True;
			EndIf;
		EndIf;
	EndIf;
	
	SetActionsForStaticItems(Form, CIRow, ItemForPlacementName);
	
	ItemNameStringGroup = "Group" + CIRow.AttributeName;
	If Form.Items.Find(ItemNameStringGroup) <> Undefined Then
		StringGroup1 = Form.Items[ItemNameStringGroup];
		If StringGroup1.Parent = Form.Items[ItemForPlacementName]
			Or StringGroup1.Parent = Form.Items["GroupOfContactInfoValues"+ItemForPlacementName] Then			
			Form.Items.Move(StringGroup1, Form.Items["GroupOfContactInfoValues"+ItemForPlacementName]);
		EndIf;
		ContactInformationParameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
		
		ButtonName = "Command" + CIRow.AttributeName;
		If Form.Items.Find(ButtonName) <> Undefined Then
			Button = Form.Items[ButtonName];
			If Form.Commands[Button.CommandName].Action = "Attachable_ContactInformationExecuteCommand" Then
				ShouldDisplayHistory = CIRow.StoreChangeHistory And Not CIRow.DeletionMark;
				CommandsForOutput = ContactsManagerClientServer.CommandsToOutputToForm(ContactInformationParameters, 
					CIRow.Type, CIRow.Kind, ShouldDisplayHistory);
				CommandsCount = CommandsForOutput.Count();
				If CommandsCount = 1 Then
					For Each CommandForOutput In CommandsForOutput Do
						FillPropertyValues(Button, CommandForOutput.Value, "Picture");
					EndDo;
				ElsIf CommandsCount > 1 Then
					Button.Picture = PictureLib.MenuAdditionalFunctions;
				EndIf;
			EndIf;
		EndIf;
		
		If Common.IsMobileClient() Then
			
			If Form.Items.Find(CIRow.AttributeName) <> Undefined Then
				InputField = Form.Items[CIRow.AttributeName];
				InputField.TitleLocation = FormItemTitleLocation.None;
				If InputField.Type = FormFieldType.InputField Then
					InputField.MultiLine = True;
				EndIf;
			EndIf;
			
			If ShouldShowIcons Then	
				GroupStringsTitle = Group("TitleGroup" + CIRow.AttributeName, Form, StringGroup1.Title, ItemForPlacementName, "GroupOfContactInfoValues"+ItemForPlacementName, 6);
				GroupStringsTitle.Group = ChildFormItemsGroup.Vertical;
				GroupStringsTitle.Representation = UsualGroupRepresentation.NormalSeparation; 
				
				GroupLinesTitlesPicture = Group("GroupTitlePicture" + CIRow.AttributeName, Form, StringGroup1.Title, ItemForPlacementName, "TitleGroup" + CIRow.AttributeName);
				
								
				PictureItemName = "Picture" + CIRow.AttributeName;
				If Form.Items.Find(PictureItemName) <> Undefined Then
					ItemPicture1 = Form.Items[PictureItemName];			
					Form.Items.Move(ItemPicture1, GroupLinesTitlesPicture);			
				Else
					ItemPicture1 = Form.Items.Add(PictureItemName, Type("FormDecoration"), GroupLinesTitlesPicture);
					ItemPicture1.Title = NStr("en = 'Picture';");
					ItemPicture1.Type       = FormDecorationType.Picture;
					ItemPicture1.Width    = 2;
					ItemPicture1.Picture = PictureContactInfoType(CIRow.Type);
					ContactInformationParameters.AddedItems.Add("Picture" + CIRow.AttributeName, 2, False);
				EndIf;
				
				ItemNameTitle = "Title" + CIRow.AttributeName;
				If Form.Items.Find(ItemNameTitle) <> Undefined Then
					ItemHeader = Form.Items[ItemNameTitle];			
					Form.Items.Move(ItemHeader, GroupLinesTitlesPicture);			
				Else
				TitleDecoration = Form.Items.Add(ItemNameTitle, Type("FormDecoration"), GroupLinesTitlesPicture);
				TitleDecoration.Title = Upper(StringGroup1.Title);
				TitleDecoration.Type       = FormDecorationType.Label;			
				ContactInformationParameters.AddedItems.Add("Title" + CIRow.AttributeName, 2, False);
				EndIf;
				
				Form.Items.Move(StringGroup1, GroupStringsTitle);
				
			Else			
				StringGroup1.ShowTitle = True;
			EndIf;
			
		Else
			
			If ContactInformationParameters.HasDestinationGroupWidthLimit Then
				If Form.Items.Find(CIRow.AttributeName) <> Undefined Then
					InputField = Form.Items[CIRow.AttributeName];
					InputField.Width = 0;
					InputField.MaxWidth = 0;
					InputField.AutoMaxWidth = False;
					InputField.HorizontalStretch = True;
				EndIf;
				
				ItemNameComment = "Comment" + CIRow.AttributeName;
				If Form.Items.Find(ItemNameComment) <> Undefined Then
					CommentField = Form.Items[ItemNameComment];
					CommentField.MaxWidth = ContactInformationParameters.CommentFieldWidth;
					CommentField.Width = ContactInformationParameters.CommentFieldWidth;
				EndIf; 
			Else
				If Form.Items.Find(CIRow.AttributeName) <> Undefined Then
					InputField = Form.Items[CIRow.AttributeName]; 
					URLProcessing = ContactInformationParameters.URLProcessing;
					SetEntryFieldsProperties(CIRow, InputField, Form, CIRow.AttributeName, URLProcessing);
				EndIf;
			EndIf;
			
			PictureItemName = "Picture" + CIRow.AttributeName;
			If ShouldShowIcons And Form.Items.Find(PictureItemName) = Undefined Then
				If StringGroup1.Parent = Form.Items["GroupOfContactInfoValues"+ItemForPlacementName] Then
					StringGroup1.United = False;
				EndIf;
				Decoration = Form.Items.Add(PictureItemName, Type("FormDecoration"), StringGroup1);
				Decoration.Title = NStr("en = 'Picture';");
				Decoration.Type       = FormDecorationType.Picture;
				Decoration.Width    = 2;
				Decoration.Picture = PictureContactInfoType(CIRow.Type);
				If Form.Items.Find(CIRow.AttributeName) <> Undefined Then
					Form.Items.Move(Decoration, StringGroup1, Form.Items[CIRow.AttributeName]);
				EndIf;
			EndIf;
			
		EndIf;
	EndIf;
	
EndProcedure

Procedure SetEntryFieldsProperties(CIKindInformation, Item, Form, AttributeName, URLProcessing)
	
	If CIKindInformation.Type = Enums.ContactInformationTypes.Address Then
		If Item.Type = FormFieldType.InputField Then
			If CIKindInformation.EditingOption = "InputField" Then
				Item.DropListButton = True;
				Item.Width = 70;
			ElsIf CIKindInformation.EditingOption = "Dialog" Then
				Item.Width = 73;
			Else
				Item.DropListButton = True;
				Item.Width = 68;
			EndIf;
		ElsIf Item.Type = FormFieldType.LabelField Then
			Item.Width = 73;
		EndIf;
		
	ElsIf CIKindInformation.Type = Enums.ContactInformationTypes.Phone
		Or CIKindInformation.Type = Enums.ContactInformationTypes.Fax Then
		
		If CIKindInformation.EditingOption = "InputField" Then
			Item.Width = 40;
		Else
			Item.Width = 38;
		EndIf;
		
		If CIKindInformation.EnterNumberByMask Then 
			PhoneNumberMatchesMask = ContactsManagerInternal.PhoneNumberMatchesMask(Form[AttributeName], CIKindInformation.PhoneNumberMask);	
			If IsBlankString(Form[AttributeName]) Or PhoneNumberMatchesMask Then
				Item.Mask = CIKindInformation.PhoneNumberMask;
			EndIf;
			
			ContactInformationTable1 = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form);
			FoundRows = ContactInformationTable1.FindRows(New Structure("AttributeName", AttributeName));
			If FoundRows.Count() > 0 Then
				FoundRows[0].Mask = CIKindInformation.PhoneNumberMask;
			EndIf;
		EndIf;
		
	ElsIf CIKindInformation.Type = Enums.ContactInformationTypes.Other Then
		If CIKindInformation.FieldKindOther = "MultilineWide" Then
			Item.Height = 3;
			Item.Width = 72;
			Item.MultiLine = True;
		ElsIf CIKindInformation.FieldKindOther = "SingleLineWide" Then
			Item.Height = 1;
			Item.Width = 72;
			Item.MultiLine = False;
		Else // SingleLineNarrow
			Item.Height = 1;
			Item.Width = 35;
			Item.MultiLine = False;
		EndIf;
	ElsIf CIKindInformation.Type = Enums.ContactInformationTypes.WebPage Then
		If URLProcessing Then	
			Item.Width = 73;
		Else
			Item.Width = 40;
		EndIf;
	Else
		Item.Width = 40;
	EndIf;
	
EndProcedure

Procedure MoveContextMenuItem(PreviousItem, Form, Direction, ItemForPlacementName)
	
	If Direction > 0 Then
		CommandName = "ContextMenuUp" + PreviousItem.Name;
	Else
		CommandName = "ContextMenuDown" + PreviousItem.Name;
	EndIf;
	
	Command = Form.Commands.Add(CommandName);
	Button = Form.Items.Add(CommandName, Type("FormButton"), PreviousItem.ContextMenu);
	
	Command.Action = "Attachable_ContactInformationExecuteCommand";
	If Direction > 0 Then 
		CommandText = NStr("en = 'Move up';");
		Button.Picture = PictureLib.MoveUp;
	Else
		CommandText = NStr("en = 'Move down';");
		Button.Picture = PictureLib.MoveDown;
	EndIf;
	Button.Title = CommandText;
	Command.ToolTip = CommandText;
	Button.CommandName = CommandName;
	Command.ModifiesStoredData = True;
	Button.Enabled = True;
	ContactInformationParameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
	ContactInformationParameters.AddedItems.Add(CommandName, 1);
	ContactInformationParameters.AddedItems.Add(CommandName, 9, True);
	
EndProcedure

Function Group(GroupName, Form, Title, ItemForPlacementName, ParentGroupName = "", ProcedureForDeleting = 5)
	
	Group = Form.Items.Find(GroupName);
	
	If Group = Undefined Then
		ParentName = ?(ValueIsFilled(ParentGroupName), ParentGroupName, ItemForPlacementName);
		Parent = Parent(Form, ParentName);
		Group = Form.Items.Add(GroupName, Type("FormGroup"), Parent);
		Group.Type = FormGroupType.UsualGroup;
		Group.Title = Title;
		Group.ShowTitle = False;
		Group.EnableContentChange = False;
		Group.Representation = UsualGroupRepresentation.None;
		Group.Group = ChildFormItemsGroup.AlwaysHorizontal;
		ContactInformationParameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
		ContactInformationParameters.AddedItems.Add(GroupName, ProcedureForDeleting);
	EndIf;
	
	Return Group;
	
EndFunction

Procedure CheckContactInformationAttributesAvailability(Form, AttributesToAddArray)
	
	FormAttributeList = Form.GetAttributes();
	
	CreateContactInformationParameters = True;
	CreateContactInformationTable = True;
	For Each Attribute In FormAttributeList Do
		If Attribute.Name = "ContactInformationParameters" Then
			CreateContactInformationParameters = False;
		ElsIf Attribute.Name = "ContactInformationAdditionalAttributesDetails" Then
			CreateContactInformationTable = False;
		EndIf;
	EndDo;
	
	String500 = New TypeDescription("String", , New StringQualifiers(500));
	DetailsName = "ContactInformationAdditionalAttributesDetails";
	
	If CreateContactInformationTable Then
		
		// Create a value table.
		DetailsName = "ContactInformationAdditionalAttributesDetails";
		AttributesToAddArray.Add(New FormAttribute(DetailsName, New TypeDescription("ValueTable")));
		AttributesToAddArray.Add(New FormAttribute("AttributeName", String500, DetailsName));
		AttributesToAddArray.Add(New FormAttribute("AttributeNameComment", String500, DetailsName));
		AttributesToAddArray.Add(New FormAttribute("Kind", New TypeDescription("CatalogRef.ContactInformationKinds"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("Type", New TypeDescription("EnumRef.ContactInformationTypes"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("Value", New TypeDescription("String"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("Presentation", String500, DetailsName));
		AttributesToAddArray.Add(New FormAttribute("Comment", New TypeDescription("String"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("IsTabularSectionAttribute", New TypeDescription("Boolean"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("IsHistoricalContactInformation", New TypeDescription("Boolean"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("ValidFrom", New TypeDescription("Date"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("StoreChangeHistory", New TypeDescription("Boolean"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("ItemForPlacementName", String500, DetailsName));
		AttributesToAddArray.Add(New FormAttribute("InternationalAddressFormat", New TypeDescription("Boolean"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("Mask", Common.StringTypeDetails(100), DetailsName));
	Else
		TableAttributes = Form.GetAttributes("ContactInformationAdditionalAttributesDetails");
		AttributesToCreate = New Map;
		AttributesToCreate.Insert("ItemForPlacementName",            True);
		AttributesToCreate.Insert("AttributeNameComment",             True);
		AttributesToCreate.Insert("StoreChangeHistory",             True);
		AttributesToCreate.Insert("ValidFrom",                          True);
		AttributesToCreate.Insert("IsHistoricalContactInformation", True);
		AttributesToCreate.Insert("Value",                            True);
		AttributesToCreate.Insert("InternationalAddressFormat",           True);
		AttributesToCreate.Insert("Mask",           True);
		
		For Each Attribute In TableAttributes Do
			If AttributesToCreate[Attribute.Name] <> Undefined Then
				AttributesToCreate[Attribute.Name] = False;
			EndIf;
		EndDo;
		
		If AttributesToCreate["Value"] Then
			AttributesToAddArray.Add(New FormAttribute("Value", New TypeDescription("String"), DetailsName));
		EndIf;
		
		If AttributesToCreate["InternationalAddressFormat"] Then
			AttributesToAddArray.Add(New FormAttribute("InternationalAddressFormat", New TypeDescription("Boolean"), DetailsName));
		EndIf;
		
		If AttributesToCreate["ItemForPlacementName"] Then
			AttributesToAddArray.Add(New FormAttribute("ItemForPlacementName", String500, DetailsName));
		EndIf;
		
		If AttributesToCreate["AttributeNameComment"] Then
			AttributesToAddArray.Add(New FormAttribute("AttributeNameComment", String500, DetailsName));
		EndIf;
		
		If AttributesToCreate["StoreChangeHistory"] Then
			AttributesToAddArray.Add(New FormAttribute("StoreChangeHistory", New TypeDescription("Boolean"), DetailsName));
		EndIf;
		
		If AttributesToCreate["ValidFrom"] Then
			AttributesToAddArray.Add(New FormAttribute("ValidFrom", New TypeDescription("Date"), DetailsName));
		EndIf;
		
		If AttributesToCreate["Mask"] Then
			AttributesToAddArray.Add(New FormAttribute("Mask", Common.StringTypeDetails(100), DetailsName));
		EndIf;
		
		If AttributesToCreate["IsHistoricalContactInformation"] Then
			AttributesToAddArray.Add(New FormAttribute("IsHistoricalContactInformation", New TypeDescription("Boolean"), DetailsName));
		EndIf;
		
	EndIf;
	
	If CreateContactInformationParameters Then
		AttributesToAddArray.Add(New FormAttribute("ContactInformationParameters", New TypeDescription()));
	EndIf;
	
EndProcedure

Procedure SetValidationAttributesValues(Object, ValidationSettings = Undefined)
	
	Object.CheckValidity = ?(ValidationSettings = Undefined, False, ValidationSettings.CheckValidity);
	
	Object.OnlyNationalAddress = False;
	Object.IncludeCountryInPresentation = False;
	Object.HideObsoleteAddresses = False;
	
EndProcedure

Function DescriptionForIDGeneration(Object) Export
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		CurrentLanguageSuffix = ModuleNationalLanguageSupportServer.CurrentLanguageSuffix();
		
		Return ?(ValueIsFilled(CurrentLanguageSuffix),
			Object["Description"+ CurrentLanguageSuffix],
			Object.Description);
		
	EndIf;
	
	Return Object.Description;

EndFunction

Procedure AddAttributeToDetails(Form, ContactInformationRow, ContactInformationKindData, IsNewCIKind,
	IsTabularSectionAttribute = False, FillAttributeValue = True, ItemForPlacementName = "ContactInformationGroup")
	
	AdditionalAttributesDetailsTable = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form);
	NewRow = AdditionalAttributesDetailsTable.Add();
	NewRow.AttributeName  = ContactInformationRow.AttributeName;
	NewRow.Kind           = ContactInformationRow.Kind;
	NewRow.Type           = ContactInformationRow.Type;
	NewRow.ItemForPlacementName  = ItemForPlacementName;
	NewRow.IsTabularSectionAttribute = IsTabularSectionAttribute;
	
	If NewRow.Property("IsHistoricalContactInformation") Then
		NewRow.IsHistoricalContactInformation = ContactInformationRow.IsHistoricalContactInformation;
	EndIf;
	
	If NewRow.Property("ValidFrom") Then
		NewRow.ValidFrom = ContactInformationRow.ValidFrom;
	EndIf;
	
	If NewRow.Property("StoreChangeHistory") Then
		NewRow.StoreChangeHistory = ContactInformationRow.StoreChangeHistory;
	EndIf;
	
	If NewRow.Property("InternationalAddressFormat") Then
		NewRow.InternationalAddressFormat = ContactInformationRow.InternationalAddressFormat;
	EndIf;
	
	NewRow.Value      = ContactInformationRow.Value;
	NewRow.Presentation = ContactInformationRow.Presentation;
	NewRow.Comment   = ContactInformationRow.Comment;
	
	If FillAttributeValue And Not IsTabularSectionAttribute Then
		
		If Form.Items.Find(ContactInformationRow.AttributeName) <> Undefined 
			And Form.Items[ContactInformationRow.AttributeName].Type = FormFieldType.LabelField Then
			IsLabelField = True;
		Else
			IsLabelField = False;
		EndIf;
		
		If ContactInformationRow.Type = Enums.ContactInformationTypes.Address
			And (ContactInformationRow.EditingOption = "Dialog" Or IsLabelField)
			And IsBlankString(ContactInformationRow.Presentation) Then
			Form[ContactInformationRow.AttributeName] = ContactsManagerClientServer.BlankAddressTextAsHyperlink();
		Else
			Form[ContactInformationRow.AttributeName] = ContactInformationRow.Presentation;
		EndIf;
		
		ContactInformationParameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
		URLProcessing = ContactInformationParameters.URLProcessing;
		If HasCommentFieldForContactInfoType(ContactInformationRow.Type, URLProcessing) Then
			DetailsForFillIn = New Structure();    
			DetailsForFillIn.Insert("Comment" + ContactInformationRow.AttributeName, ContactInformationRow.Comment); 
			FillPropertyValues(Form, DetailsForFillIn); 
		EndIf;
		
	EndIf;
	
	ContactInformationKindData.Insert("Ref", ContactInformationRow.Kind);
	
	If IsNewCIKind And ContactInformationKindData.AllowMultipleValueInput And Not IsTabularSectionAttribute And Not ContactInformationKindData.DeletionMark Then
		ContactInformationParameters = ?(ContactInformationParameters = Undefined,
			FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName),
			ContactInformationParameters);
		Kind = ContactInformationRow.Kind; // CatalogRef.ContactInformationKinds
		If Common.IsMobileClient() Then
			ContactInformationParameters.ItemsToAddList.Add(ContactInformationKindData, String(Kind));
		Else
			ImageOfType = PictureContactInfoType(ContactInformationKindData.Type);
			ContactInformationParameters.ItemsToAddList.Add(ContactInformationKindData, String(Kind),,ImageOfType);
		EndIf;
	EndIf;
	
EndProcedure

Procedure DeleteFormItemsAndCommands(Form, ItemForPlacementName)
	
	ContactInformationParameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
	AddedItems = ContactInformationParameters.AddedItems;
	AddedItems.SortByPresentation();
	
	For Each ItemToRemove In AddedItems Do
		
		If ItemToRemove.Check Then
			Form.Commands.Delete(Form.Commands[ItemToRemove.Value]);
		Else
			Form.Items.Delete(Form.Items[ItemToRemove.Value]);
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns the flag indicating whether contact information type can be edited interactively.
//
// Parameters:
//    Type - EnumRef.ContactInformationTypes - contact information type.
//
// Returns:
//    Boolean
//
Function CanEditContactInformationTypeInDialog(Type)
	
	Return Type = Enums.ContactInformationTypes.Address 
		Or Type = Enums.ContactInformationTypes.Phone
		Or Type = Enums.ContactInformationTypes.Fax;
	
EndFunction

// Returns names of document tabular sections by contact information kind.
//
// Parameters:
//    ContactInformationKindsTable - ValueTable - a list of contact information kinds:
//     * Kind - CatalogRef.ContactInformationKinds - a contact information kind.
//    ObjectName                       - String - a full name of a metadata object.
//
// Returns:
//    Map - tabular section names or a blank string if a tabular section is not available.
//
Function TabularSectionsNamesByCIKinds(ContactInformationKindsTable, ObjectName)
	
	Query = New Query;
	Query.Text = "SELECT
	|	ContactInformationKinds.Kind AS CIKind
	|INTO CIKinds
	|FROM
	|	&ContactInformationKindsTable AS ContactInformationKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN ContactInformationKinds.Parent.PredefinedKindName <> """"
	|		THEN ContactInformationKinds.Parent.PredefinedKindName
	|		ELSE ContactInformationKinds.Parent.PredefinedDataName
	|	END AS TabularSectionName,
	|	CIKinds.CIKind AS ContactInformationKind
	|FROM
	|	CIKinds AS CIKinds
	|		LEFT JOIN Catalog.ContactInformationKinds AS ContactInformationKinds
	|		ON CIKinds.CIKind = ContactInformationKinds.Ref";
	
	Query.SetParameter("ContactInformationKindsTable", ContactInformationKindsTable);
	QueryResult = Query.Execute().Select();
	
	Result = New Map;
	While QueryResult.Next() Do
		
		If ValueIsFilled(QueryResult.TabularSectionName) Then
			TabularSectionName = Mid(QueryResult.TabularSectionName, StrFind(QueryResult.TabularSectionName, ObjectName) + StrLen(ObjectName));
		Else
			TabularSectionName = "";
		EndIf;
		
		Result.Insert(QueryResult.ContactInformationKind, TabularSectionName);
	EndDo;
	
	Return Result;
	
EndFunction

// Checks if the form contains filled CI rows of the same kind (except for the current one).
//
Function HasOtherRowsFilledWithThisContactInformationKind(Val Form, Val RowToValidate, Val ContactInformationKind)
	
	AllRowsOfThisKind = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).FindRows(
		New Structure("Kind", ContactInformationKind));
	
	For Each KindRow In AllRowsOfThisKind Do
		
		If KindRow <> RowToValidate Then
			Presentation = Form[KindRow.AttributeName];
			If Not IsBlankString(Presentation) Then 
				Return True;
			EndIf;
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

Procedure OutputUserMessage(MessageText, AttributeName, AttributeField = "")
	
	AttributeName = ?(IsBlankString(AttributeField), AttributeName, "");
	Common.MessageToUser(MessageText,, AttributeField, AttributeName);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Filling additional attributes of Contact information tabular section.


Procedure SetContactInformationKindDescription(Val Object, Val Description)
	
	DescriptionsInDifferentLanguages = ContactsManagerInternalCached.ContactInformationKindsDescriptions();
	PredefinedKindName = TrimAll(Object.PredefinedKindName);
	
	Presentation = DescriptionsInDifferentLanguages.Get(Common.DefaultLanguageCode())[PredefinedKindName];
	If ValueIsFilled(Presentation) Then
		Object.Description = Presentation;
	ElsIf ValueIsFilled(Description) Then
		Object.Description = Description;
	EndIf;
	
	PredefinedObjectData = Undefined;
	
	FillParameters = InfobaseUpdateInternal.ParameterSetForFillingObject(Object.Metadata());
	KeyAttributeName = FillParameters.PredefinedItemsSettings.OverriddenSettings.KeyAttributeName;
	
	If ValueIsFilled(KeyAttributeName) Then
		
		ObjectKeyValue = Object[KeyAttributeName];
		
		If ValueIsFilled(ObjectKeyValue) Then
			PredefinedObjectData = FillParameters.PredefinedData.Find(ObjectKeyValue, KeyAttributeName);
		EndIf;
		
	EndIf;
	
	If PredefinedObjectData = Undefined Or IsBlankString(KeyAttributeName) Then
		PredefinedObjectData = FillParameters.PredefinedData.Find(ObjectKeyValue, "PredefinedDataName");
	EndIf;
	
	If IsBlankString(Object.Description) And PredefinedObjectData <> Undefined Then
		
		Presentation = PredefinedObjectData["Description" + "_" + Common.DefaultLanguageCode()];
		If IsBlankString(Presentation) Then
			Presentation = PredefinedObjectData["Description"];
		EndIf;
		
		If ValueIsFilled(Presentation) Then
			Object.Description = Presentation;
		EndIf;
		
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		LanguagesInformationRecords = ModuleNationalLanguageSupportServer.LanguagesInformationRecords();
		
		PresentationLanguage1 = "";
		PresentationLanguage2 = "";
		
		If PredefinedObjectData <> Undefined Then
			
			If ValueIsFilled(LanguagesInformationRecords.Language1) Then
				PresentationLanguage1 = PredefinedObjectData["Description" + "_" + LanguagesInformationRecords.Language1];
			EndIf;
			If ValueIsFilled(LanguagesInformationRecords.Language2) Then
				PresentationLanguage2 = PredefinedObjectData["Description" + "_" + LanguagesInformationRecords.Language2];
			EndIf;
			
		EndIf;
		
		If IsBlankString(PresentationLanguage1) Then
			
			CaptionLanguage1 = DescriptionsInDifferentLanguages.Get(ModuleNationalLanguageSupportServer.FirstAdditionalInfobaseLanguageCode());
			If TypeOf(CaptionLanguage1) = Type("Map") Then
				PresentationLanguage1 = CaptionLanguage1.Get(PredefinedKindName);
			EndIf;
			
		EndIf;
		
		If IsBlankString(PresentationLanguage2) Then
			CaptionLanguage2 = DescriptionsInDifferentLanguages.Get(ModuleNationalLanguageSupportServer.SecondAdditionalInfobaseLanguageCode());
			If TypeOf(CaptionLanguage2) = Type("Map") Then
				PresentationLanguage2 = CaptionLanguage2.Get(PredefinedKindName);
			EndIf;
		EndIf;
		
		Object.DescriptionLanguage1 = ?(ValueIsFilled(PresentationLanguage1), PresentationLanguage1, Object.Description);
		Object.DescriptionLanguage2 = ?(ValueIsFilled(PresentationLanguage2), PresentationLanguage2, Object.Description);
		
	EndIf;
	
EndProcedure

Procedure ContactInformationConvertionToJSON(ContactInformation)
	
	// Conversion.
	For Each CIRow In ContactInformation Do
		If IsBlankString(CIRow.Value) Then
			If ValueIsFilled(CIRow.FieldValues) Then
				
				SettingsOfConversion = ContactInformationConversionSettings();
				SettingsOfConversion.UpdateIDs             = False;
				SettingsOfConversion.ShouldRestoreContactInfo = False;
				SettingsOfConversion.Presentation                       = CIRow.Presentation;
				
				ContactInformationByFields = ContactsManagerInternal.ContactInformationToJSONStructure(CIRow.FieldValues,
					CIRow.Type, SettingsOfConversion);
				
				If CIRow.Type = Enums.ContactInformationTypes.Address
				   And ContactsManagerClientServer.IsAddressInFreeForm(ContactInformationByFields.AddressType) Then
						Continue;
				EndIf;
				
				If IsBlankString(ContactInformationByFields.value) Then
					ContactInformationByFields.value = CIRow.Presentation;
				EndIf;
				
				If IsBlankString(ContactInformationByFields.comment) And ValueIsFilled(CIRow.Comment) Then
					ContactInformationByFields.comment = CIRow.Comment;
				EndIf;
				
				CIRow.Value = ContactsManagerInternal.ToJSONStringStructure(ContactInformationByFields);
				
			EndIf;
			
		EndIf;
		
		If IsBlankString(CIRow.Description) Then
			CIRow.Description = CIRow.PresentationInDefaultLanguage;
		EndIf;
		
	EndDo;

EndProcedure

Function ContactInformationConversionSettings() Export
	
	Result = New Structure();
	Result.Insert("UpdateIDs",             True);
	Result.Insert("ShouldRestoreContactInfo", True);
	Result.Insert("Presentation",                       "");
	Return Result;
	
EndFunction

Function ContactInformationBasicInfo(ContactInformation = Undefined) Export
	
	Result = ContactInfoBasicFields();
	If ContactInformation = Undefined Then
		Return Result;
	EndIf;
	
	ContactInformationFields = ContactsManagerInternal.ContactInformationToJSONStructure(ContactInformation);
	ContactInformationType = ContactInformationType(ContactInformation);
	
	Result.Presentation           = String(ContactInformationFields.Value);
	Result.Comment             = String(ContactInformationFields.Comment);
	Result.ContactInformationType = ContactInformationType;
	
	Return Result;
	
EndFunction

// Returns:
//  Structure:
//    * Presentation - String
//    * ContactInformationType - EnumRef.ContactInformationTypes
//                              - Undefined
//    * Comment - String
//
Function ContactInfoBasicFields()
	
	ContactInformationFields = New Structure;
	ContactInformationFields.Insert("Presentation",           "");
	ContactInformationFields.Insert("ContactInformationType", Undefined);
	ContactInformationFields.Insert("Comment",             "");
	
	Return ContactInformationFields;
	
EndFunction

// Returns:
//  Structure -  Contact information fields to be converted:
//   * ContactInformationType - EnumRef.ContactInformationTypes
//                           - Undefined
//   * XMLData1 - String
//   * Presentation - String 
//
Function ContactInfoFieldsToConvert() Export

	Result = New Structure;
	Result.Insert("ContactInformationType", Undefined);
	Result.Insert("XMLData1",               "");
	Result.Insert("Presentation",           "");
	
	Return Result;
	
EndFunction

Procedure CreateTabularSectionItems(Val Form, Val ObjectName, ItemForPlacementName, 
	Val ContactInformationRow, Val ContactInformationKindData)
	
	TabularSectionContactInformationKinds = New Array;
	For Each LineOfATabularSection In ContactInformationRow.Rows Do
		TabularSectionContactInformationKinds.Add(LineOfATabularSection.Kind);
	EndDo;
	TabularSectionContactInformationKindsData = ContactsManagerInternal.ContactInformationKindsData(
		TabularSectionContactInformationKinds);
	
	ContactInformationKindName = ContactInformationKindData.PredefinedKindName;
	If IsBlankString(ContactInformationKindName) Then
		ContactInformationKindName = ContactInformationKindData.PredefinedDataName;
	EndIf;
	Position = StrFind(ContactInformationKindName, ObjectName);
	TabularSectionName = Mid(ContactInformationKindName, Position + StrLen(ObjectName));
	PreviousTabularSectionKind = Undefined;
	
	For Each LineOfATabularSection In ContactInformationRow.Rows Do
		
		TabularSectionContactInformationKind = LineOfATabularSection.Kind;
		If TabularSectionContactInformationKind <> PreviousTabularSectionKind Then
			
			TabularSectionGroup = Form.Items[TabularSectionName + "ContactInformationGroup"];
			
			Item = Form.Items.Add(LineOfATabularSection.AttributeName, Type("FormField"), TabularSectionGroup);
			Item.Type = FormFieldType.InputField;
			Item.DataPath = "Object." + TabularSectionName + "." + LineOfATabularSection.AttributeName;
			
			If CanEditContactInformationTypeInDialog(LineOfATabularSection.Type) Then
				Item.ChoiceButton = Not LineOfATabularSection.DeletionMark;
				If TabularSectionContactInformationKind.EditingOption = "Dialog" Then
					Item.TextEdit = False;
				EndIf;
				
				Item.SetAction("StartChoice", "Attachable_ContactInformationStartChoice");
			EndIf;
			Item.SetAction("OnChange", "Attachable_ContactInformationOnChange");
			
			If LineOfATabularSection.DeletionMark Then
				Item.Font = StyleFonts.DeletedAttributeTitleFont;
				Item.TextEdit = False;
			EndIf;
			
			If TabularSectionContactInformationKind.Mandatory Then
				Item.AutoMarkIncomplete = Not LineOfATabularSection.DeletionMark;
			EndIf;
			
			ItemContactInformationParameters = Form.ContactInformationParameters[ItemForPlacementName]; // See ContactInformationOutputParameters
			ItemContactInformationParameters.AddedItems.Add(LineOfATabularSection.AttributeName, 2, False);
			
			AddAttributeToDetails(Form, LineOfATabularSection, TabularSectionContactInformationKindsData, False, True,, ItemForPlacementName);
			PreviousTabularSectionKind = TabularSectionContactInformationKind;
			
		EndIf;
		
		Filter = New Structure;
		Filter.Insert("TabularSectionRowID", LineOfATabularSection.TabularSectionRowID);
		
		TableRows = Form.Object[TabularSectionName].FindRows(Filter);
		
		If TableRows.Count() = 1 Then
			TableRow = TableRows[0];
			TableRow[LineOfATabularSection.AttributeName]                   = LineOfATabularSection.Presentation;
			TableRow[LineOfATabularSection.AttributeName + "Value"]      = LineOfATabularSection.Value;
		EndIf;
	EndDo;

EndProcedure

// Validates email contact information and reports any errors. 
//
// Parameters:
//     EMAddress      - Structure
//                  - String - contact information.
//     InformationKind - CatalogRef.ContactInformationKinds - a contact information kind with with validation settings.
//     AttributeName  - String - an optional attribute name used to link an error message.
//
// Returns:
//     Number - error level: 0 - no, 1 - non-critical, 2 - critical.
//
Function EmailFIllingErrors(EMAddress, InformationKind, Val AttributeName = "", AttributeField = "")
	
	CheckValidity = Common.ObjectAttributeValue(InformationKind, "CheckValidity");
	
	If Not CheckValidity Then
		Return 0;
	EndIf;
	
	If Not ValueIsFilled(EMAddress) Then
		Return 0;
	EndIf;
	
	ErrorString = "";
	Email = ContactsManagerInternal.JSONToContactInformationByFields(EMAddress, Enums.ContactInformationTypes.Email);
	
	Try
		Result = CommonClientServer.EmailsFromString(Email.Value);
		If Result.Count() > 1 Then
			ErrorString = NStr("en = 'Only one email address is allowed';");
		ElsIf Result.Count() = 1 Then
			ErrorString = Result[0].ErrorDescription;
		EndIf;
	Except
		ErrorString = ErrorProcessing.BriefErrorDescription(ErrorInfo());
	EndTry;
	
	If Not IsBlankString(ErrorString) Then
		OutputUserMessage(ErrorString, AttributeName, AttributeField);
		ErrorLevel = ?(CheckValidity, 2, 1);
	Else
		ErrorLevel = 0;
	EndIf;
	
	Return ErrorLevel;
	
EndFunction

// Checks contact information.
//
Function CheckContactInformationFilling(Presentation, Value, InformationKind, InformationType,
	AttributeName, Comment = Undefined, AttributePath1 = "")
	
	If IsBlankString(Value) Then
		
		If IsBlankString(Presentation) Then
			Return 0;
		EndIf;
		
		EditingOption = Common.ObjectAttributeValue(InformationKind, "EditingOption");
		If EditingOption = "Dialog" And StrCompare(Presentation, ContactsManagerClientServer.BlankAddressTextAsHyperlink()) = 0 Then
			Return 0;
		EndIf;
		
		ContactInformation = ContactsManagerInternal.ContactsByPresentation(Presentation, InformationKind);
		Value = ?(TypeOf(ContactInformation) = Type("Structure"), ContactsManagerInternal.ToJSONStringStructure(ContactInformation), "");
		
	ElsIf ContactsManagerClientServer.IsXMLContactInformation(Value) Then
		
		Value = ContactInformationInJSON(Value, InformationKind);
		
	EndIf;
	
	// Check.
	If InformationType = Enums.ContactInformationTypes.Email Then
		ErrorsLevel = EmailFIllingErrors(Value, InformationKind, AttributeName, AttributePath1);
	ElsIf InformationType = Enums.ContactInformationTypes.Address Then
		ErrorsLevel = AddressFIllErrors(Value, InformationKind, AttributeName, AttributePath1);
	ElsIf InformationType = Enums.ContactInformationTypes.Phone 
		Or InformationType = Enums.ContactInformationTypes.Fax Then
		ErrorsLevel = PhoneFillingErrors(Value, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.WebPage Then
		ErrorsLevel = WebPageFillingErrors(Value, InformationKind, AttributeName);
	Else
		ErrorsLevel = 0; // Skip other checks.
	EndIf;
	
	Return ErrorsLevel;
	
EndFunction

// Getting and adjusting contact information
Procedure AdjustContactInformation(Form, CIRow)
	
	ConversionResult = New Structure;
	
	If IsBlankString(CIRow.Value) Then
		
		If IsBlankString(CIRow.Presentation) And ValueIsFilled(CIRow.FieldValues) Then
			CIRow.Presentation = ContactsManagerInternal.ContactInformationPresentation(CIRow.FieldValues);
		EndIf;
		
		
	Else
		
		CIRow.Comment = ContactInformationComment(CIRow.Value);
		
		If IsBlankString(CIRow.Presentation) Then
			CIRow.Presentation = ContactInformationPresentation(CIRow.Value);
		EndIf;
		
	EndIf;
	
EndProcedure

// Validates address contact information and reports any errors. Returns the flag indicating that there are errors.
//
// Parameters:
//     Source      - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationKinds - a contact information kind with with validation settings.
//     AttributeName  - String - an optional attribute name used to link an error message.
//
// Returns:
//     Number - error level: 0 - no, 1 - non-critical, 2 - critical.
//
Function AddressFIllErrors(Source, InformationKind, AttributeName = "", AttributeField = "")
	
	CheckValidity = Common.ObjectAttributeValue(InformationKind, "CheckValidity");
	
	If Not CheckValidity Then
		Return 0;
	EndIf;
	HasErrors = False;
	
	If Not ContactsManagerInternal.IsNationalAddress(Source) Then
		Return 0;
	EndIf;
	
	If Metadata.DataProcessors.Find("AdvancedContactInformationInput") <> Undefined Then
		ErrorList = DataProcessors["AdvancedContactInformationInput"].AddressFIllErrors(Source, InformationKind);
		For Each Item In ErrorList Do
			
			OutputUserMessage(Item.ErrorText, AttributeName, AttributeField);
			HasErrors = True;
			
		EndDo;
	EndIf;
	
	If HasErrors And CheckValidity Then
		Return 2;
	ElsIf HasErrors Then
		Return 1;
	EndIf;
	
	Return 0;
EndFunction


// Validates phone contact information and reports any errors. Returns the flag indicating that there are errors.
//
// Parameters:
//     Source      - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationKinds - a contact information kind with with validation settings.
//     AttributeName  - String - To link an error message to a form attribute, the attribute name is not required.
//
// Returns:
//     Number - error level: 0 - no, 1 - non-critical, 2 - critical.
//
Function PhoneFillingErrors(Source, InformationKind, AttributeName = "")
	
	CheckValidity = Common.ObjectAttributeValue(InformationKind, "CheckValidity");
	
	If Not CheckValidity Then
		Return 0;
	EndIf;
		
	HasErrors = False;
	
	InfoAboutPhone = InfoAboutPhone(Source);
	
	ModuleAddressManager = Undefined;
	If ContactsManagerInternalCached.AreAddressManagementModulesAvailable()  Then 
		ModuleAddressManager = Common.CommonModule("AddressManager");
	EndIf;
	
	ErrorList  = ContactsManagerClientServer.PhoneFillingErrors(InfoAboutPhone, ModuleAddressManager);

	For Each Item In ErrorList Do
		
		If ValueIsFilled(AttributeName) Then
			OutputUserMessage(Item.Presentation, AttributeName);
		EndIf;
		
		HasErrors = True;
	EndDo;

	If HasErrors And CheckValidity Then
		Return 2;
	ElsIf HasErrors Then
		Return 1;
	EndIf;
	
	Return 0;
	
EndFunction

// Validates web page contact information and reports any errors. Returns the flag indicating that there are errors.
//
// Parameters:
//     Source      - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationKinds - a contact information kind with with validation settings.
//     AttributeName  - String - an optional attribute name used to link an error message.
//
// Returns:
//     Number - error level: 0 - no, 1 - non-critical, 2 - critical.
//
Function WebPageFillingErrors(Source, InformationKind, AttributeName = "")
	Return 0;
EndFunction

Procedure ObjectContactInformationFillingProcessing(Object, Val FillingData)
	
	If TypeOf(FillingData) <> Type("Structure") Then
		Return;
	EndIf;
	
	// Description, if available in the destination object.
	Description = Undefined;
	If FillingData.Property("Description", Description)
		And CommonClientServer.HasAttributeOrObjectProperty(Object, "Description") Then
		Object.Description = Description;
	EndIf;
	
	// Contact information table. It is filled in only if CI is not in another tabular section.
	ContactInformation = Undefined;
	If FillingData.Property("ContactInformation", ContactInformation) 
		And CommonClientServer.HasAttributeOrObjectProperty(Object, "ContactInformation") Then
		
		If TypeOf(ContactInformation) = Type("ValueTable") Then
			TableColumns1 = ContactInformation.Columns;
		Else
			ContactInformationTable = ContactInformation.UnloadColumns(); // ValueTable
			TableColumns1 = ContactInformationTable.Columns;
		EndIf;
		
		If TableColumns1.Find("TabularSectionRowID") = Undefined Then
			
			For Each CIRow In ContactInformation Do
				NewCIRow = Object.ContactInformation.Add();
				FillPropertyValues(NewCIRow, CIRow, , "FieldValues");
				NewCIRow.FieldValues = ContactInformationToXML(CIRow.FieldValues, CIRow.Presentation, CIRow.Kind);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function Parent(Form, ItemForPlacementName)
	
	Return ?(IsBlankString(ItemForPlacementName), Form, Form.Items[ItemForPlacementName])
	
EndFunction

// Details of contact information output parameters
// 
// Parameters:
//   Form - ClientApplicationForm
//   ItemForPlacementName - String
//                            - Undefined
//   CITitleLocation - String
//                        - FormItemTitleLocation
//   DeferredInitialization - Array
//                           - Boolean
//   AdditionalParameters - See AdditionalParametersOfContactInfoOutput
//
// Returns:
//  Structure:
//   * GroupForPlacement - String
//   * TitleLocation - String
//   * AddedAttributes - ValueList
//   * DeferredInitialization - Boolean
//   * ExcludedKinds - Array
//                     - Undefined
//   * DeferredInitializationExecuted - Boolean
//   * AddedItems - ValueList
//   * ItemsToAddList - ValueList:
//       * Value - Structure:
//         ** Ref - CatalogRef.ContactInformationKinds
//       * Key - String
//   * CanSendSMSMessage1 - Boolean
//   * Owner - AnyRef
//   * URLProcessing - Boolean
//   * HiddenKinds - Array
//                    - Undefined
//   * DetailsOfCommands - See DetailsOfCommands
//   * ShouldShowIcons - Boolean
//   * ItemsPlacedOnForm - Map of KeyAndValue:
//       * Key - CatalogRef.ContactInformationKinds
//       * Value - Boolean
//                  - Undefined
//   * AllowAddingFields - Boolean
//   * CommentFieldWidth - Number
//   * PositionOfAddButton - String - Valid values are: "Left", "Right", "Auto".
//   * HasDestinationGroupWidthLimit - Boolean
//
Function ContactInformationOutputParameters(Form, ItemForPlacementName, CITitleLocation,
	DeferredInitialization, AdditionalParameters)
	
	If TypeOf(Form.ContactInformationParameters) <> Type("Structure") Then
		Form.ContactInformationParameters = New Structure;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SendSMSMessage") Then
		ModuleSMS  = Common.CommonModule("SendSMSMessage");
		CanSendSMSMessage1 = ModuleSMS.CanSendSMSMessage();
	Else
		CanSendSMSMessage1 = False;
	EndIf;
	
	ContactInformationParameters = New Structure;
	ContactInformationParameters.Insert("GroupForPlacement",              ItemForPlacementName);
	ContactInformationParameters.Insert("TitleLocation",               CITitleLocationValue(CITitleLocation));
	ContactInformationParameters.Insert("AddedAttributes",             New ValueList); 
	ContactInformationParameters.Insert("DeferredInitialization",          DeferredInitialization);
	ContactInformationParameters.Insert("ExcludedKinds",                  AdditionalParameters.ExcludedKinds);
	ContactInformationParameters.Insert("DeferredInitializationExecuted", False);
	ContactInformationParameters.Insert("AddedItems",              New ValueList);
	ContactInformationParameters.Insert("ItemsToAddList",       New ValueList);
	ContactInformationParameters.Insert("CanSendSMSMessage1",               CanSendSMSMessage1);
	ContactInformationParameters.Insert("Owner",                         Undefined);
	ContactInformationParameters.Insert("URLProcessing",     False);
	ContactInformationParameters.Insert("HiddenKinds",                   AdditionalParameters.HiddenKinds);
	ContactInformationParameters.Insert("DetailsOfCommands",                   AdditionalParameters.DetailsOfCommands);
	ContactInformationParameters.Insert("ShouldShowIcons",                 AdditionalParameters.ShouldShowIcons);
	ContactInformationParameters.Insert("ItemsPlacedOnForm",                 AdditionalParameters.ItemsPlacedOnForm);
	ContactInformationParameters.Insert("AllowAddingFields",         AdditionalParameters.AllowAddingFields);
	ContactInformationParameters.Insert("CommentFieldWidth",            AdditionalParameters.CommentFieldWidth);
	ContactInformationParameters.Insert("PositionOfAddButton",          String(AdditionalParameters.PositionOfAddButton));
	ContactInformationParameters.Insert("HasDestinationGroupWidthLimit", HasDestinationGroupWidthLimit(Form.Items[ItemForPlacementName]));
	
	AddressParameters = New Structure("PremiseType, Country, IndexOf", "Appartment");
	ContactInformationParameters.Insert("AddressParameters", AddressParameters);
	
	Form.ContactInformationParameters.Insert(ItemForPlacementName, ContactInformationParameters);
	Return Form.ContactInformationParameters[ItemForPlacementName];
	
EndFunction

// Checks the group (including its parents) for the width limitations.
// Any width value less than 90 is a limitation.
//
Function HasDestinationGroupWidthLimit(Group)

	WidthCap = False;
	CheckGroupForWidthRestrictionsRecursively(Group, WidthCap);
	
	Return WidthCap;

EndFunction

Procedure CheckGroupForWidthRestrictionsRecursively(Group, WidthCap)
	
	If Group.Width <> 0 And Group.Width < 90 Then
		WidthCap = True;
	EndIf;
	
	If TypeOf(Group) <> Type("ClientApplicationForm") Then
		CheckGroupForWidthRestrictionsRecursively(Group.Parent, WidthCap);
	EndIf;
	
EndProcedure

Function ObjectContactInformationKindsGroup(Val FullMetadataObjectName)
	
	Return ContactInformationKindByName(StrReplace(FullMetadataObjectName, ".", ""));
	
EndFunction

// Returns contact information kinds by a name.
// If no name is specified, a full list of predefined kinds is returned by the application.
//
// Returns:
//  ValueTable  - Contact information kinds, where:
//    * Name - String - a name of a contact information kind.
//    * Ref - CatalogRef.ContactInformationKinds - a reference to an item of the "Contact information kinds" catalog.
//
Function PredefinedContactInformationKinds(Name = "") Export
	
	QueryText = "SELECT
		|	ContactInformationKinds.PredefinedKindName AS Name,
		|	ContactInformationKinds.Ref AS Ref
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds
		|WHERE
		|	&Filter";
	
	Query = New Query();
	If ValueIsFilled(Name) Then
		QueryText = StrReplace(QueryText, "&Filter", "ContactInformationKinds.PredefinedKindName = &Name");
		Query.SetParameter("Name", Name);
	Else
		QueryText = StrReplace(QueryText, "&Filter", "ContactInformationKinds.PredefinedKindName <> """"");
	EndIf;
	
	Query.Text = QueryText;
	Return Query.Execute().Unload();
	
EndFunction

// Defines the title location value. To support localized configurations.
//
// Parameters:
//  CITitleLocation - String - title location in text presentation in the localization language.
// 
// Returns:
//  String - title location.
//
Function CITitleLocationValue(CITitleLocation)
	
	If FormItemTitleLocation.Left = CITitleLocation Then
		Return "FormItemTitleLocation.Left";
	ElsIf FormItemTitleLocation.Top = CITitleLocation Then
		Return "FormItemTitleLocation.Top";
	ElsIf FormItemTitleLocation.Bottom = CITitleLocation Then
		Return "FormItemTitleLocation.Bottom";
	ElsIf FormItemTitleLocation.Right = CITitleLocation Then
		Return "FormItemTitleLocation.Right";
	ElsIf FormItemTitleLocation.None = CITitleLocation Then
		Return "FormItemTitleLocation.None";
	ElsIf FormItemTitleLocation.Auto = CITitleLocation Then
		Return "FormItemTitleLocation.Auto";
	EndIf;
	
	Return "";
	
EndFunction

Procedure CreateAction(Form, ContactInformationKind, AttributeName, ActionGroup1, ItemForPlacementName = "ContactInformationGroup")

	Type = ContactInformationKind.Type;
		
	ContactInfoParameters = FormContactInformationParameters(Form.ContactInformationParameters, ItemForPlacementName);
	
	ShouldDisplayHistory = ContactInformationKind.StoreChangeHistory And Not ContactInformationKind.DeletionMark;
	CommandsForOutput = ContactsManagerClientServer.CommandsToOutputToForm(ContactInfoParameters, Type, 
		ContactInformationKind.Kind, ShouldDisplayHistory);

	CommandsCount = CommandsForOutput.Count();
	If CommandsCount = 0 Then
		If ContactInfoParameters.HasDestinationGroupWidthLimit Then
			Decoration = Form.Items.Add("Indent" + AttributeName, Type("FormDecoration"), ActionGroup1);
			Decoration.Type       = FormDecorationType.Picture;
			Decoration.Width    = 3;
			Decoration.Title = NStr("en = 'Indent';");
			Decoration.Height    = 1;
		EndIf;
		Return;
	EndIf;
	
	If Type = Enums.ContactInformationTypes.Address And ContactInformationKind.EditingOption = "Dialog" Then	
		InputField = Form.Items[AttributeName];		
		InputField.ExtendedTooltip.Title = ContactsManagerClientServer.ExtendedTooltipForAddress(
			CommandsForOutput, ContactInformationKind.Presentation, ContactInformationKind.Comment);	
		InputField.ExtendedTooltip.SetAction("URLProcessing",
			 "Attachable_ContactInformationURLProcessing");			
		Return;
	EndIf;	
	
	CommandName = "Command" + AttributeName;
	Command = Form.Commands.Add(CommandName);
	ContactInfoParameters.AddedItems.Add(CommandName, 9, True);
	Command.Representation = ButtonRepresentation.Picture;
	Command.Action = "Attachable_ContactInformationExecuteCommand";
	Item = Form.Items.Add(CommandName, Type("FormButton"), ActionGroup1);
	ContactInfoParameters.AddedItems.Add(CommandName, 2);
	Item.CommandName = CommandName;

	If CommandsCount = 1 Then
		For Each CommandForOutput In CommandsForOutput Do
			FillPropertyValues(Command, CommandForOutput.Value, , "Action");
		EndDo;
	ElsIf CommandsCount > 1 Then
		Command.Picture = PictureLib.MenuAdditionalFunctions;
	EndIf;

EndProcedure

// Returns parameters of the contact information available on the form
// 
// Parameters:
//   ContactInformationParameters - See ContactInformationOutputParameters
//   ItemForPlacementName - String
//                            - Undefined
// 	
// Returns:
//   See ContactInformationOutputParameters
// 	
Function FormContactInformationParameters(ContactInformationParameters, ItemForPlacementName)
	
	If Not ValueIsFilled(ItemForPlacementName) Or Not ContactInformationParameters.Property(ItemForPlacementName) Then
		For Each FirstRecord In ContactInformationParameters Do
			Return FirstRecord.Value;
		EndDo;
		Return ContactInformationParameters;
	EndIf;
	
	Return ContactInformationParameters[ItemForPlacementName];
	
EndFunction

Function DefineNextString(Form, ContactInformation, CIRow)
	
	Position = ContactInformation.IndexOf(CIRow) + 1;
	While Position < ContactInformation.Count() Do
		NextRow = ContactInformation.Get(Position);
		If NextRow = Undefined Then
			Return Undefined;
		EndIf;
		If Form.Items.Find(NextRow.AttributeName) <> Undefined Then
			Return NextRow;
		EndIf;
		Position = Position + 1;
	EndDo;
	
	Return Undefined;
EndFunction

Procedure RestoreEmptyValuePresentation(ContactInformationRow) Export
	
	If IsBlankString(ContactInformationRow.Type) Then
		ContactInformationRow.Type = ContactsManagerInternalCached.ContactInformationKindType(
			ContactInformationRow.Kind);
	EndIf;
	
	// FieldValues may be absent in a contact information string.
	FieldsInfo = New Structure("FieldValues", Undefined);
	FillPropertyValues(FieldsInfo, ContactInformationRow);
	HasFieldsValues = (FieldsInfo.FieldValues <> Undefined);
	
	EmptyPresentation = IsBlankString(ContactInformationRow.Presentation);
	EmptyValue      = IsBlankString(ContactInformationRow.Value);
	EmptyFieldsValues = ?(HasFieldsValues, IsBlankString(FieldsInfo.FieldValues), True);
	
	AllFieldsEmpty = EmptyPresentation And EmptyValue And EmptyFieldsValues;
	AllFieldsFilled = Not EmptyPresentation And Not EmptyValue And Not EmptyFieldsValues;
	
	If AllFieldsEmpty Or AllFieldsFilled Then
		Return;
	EndIf;
	
	If EmptyPresentation Then
				
		ValuesSource = ?(EmptyFieldsValues, ContactInformationRow.Value, ContactInformationRow.FieldValues);
		
		ContactInformationRow.Presentation = ContactsManagerInternal.ContactInformationPresentation(
			ValuesSource);
		
	EndIf;
	
	If EmptyValue Then
		
		If Not EmptyPresentation And EmptyFieldsValues Then
			
			AddressByFields = ContactsManagerInternal.ContactsByPresentation(
				ContactInformationRow.Presentation, ContactInformationRow.Type);
			ContactInformationRow.Value = ContactsManagerInternal.ToJSONStringStructure(AddressByFields);
			
			If HasFieldsValues And ContactsManagerInternalCached.IsLocalizationModuleAvailable() Then
				ModuleContactsManagerLocalization = Common.CommonModule("ContactsManagerLocalization");
				ContactInformationRow.FieldValues = ModuleContactsManagerLocalization.ContactsFromJSONToXML(
					ContactInformationRow.Value, ContactInformationRow.Type);
			EndIf;
			
		ElsIf Not EmptyFieldsValues Then
			
			ContactInformationRow.Value = ContactInformationInJSON(ContactInformationRow.FieldValues,
				ContactInformationRow.Type);
			
		EndIf;
	
	ElsIf EmptyFieldsValues And HasFieldsValues Then
		
		ContactInformationRow.FieldValues = ContactInformationToXML(ContactInformationRow.Value, 
			ContactInformationRow.Presentation, ContactInformationRow.Kind);
			
	EndIf;
	
EndProcedure

// Converts a country code to the standard format - a three-character string.
//
Function WorldCountryCode(Val CountryCode)
	
	If TypeOf(CountryCode)=Type("Number") Then
		Return Format(CountryCode, "ND=3; NZ=; NLZ=; NG=");
	EndIf;
	
	Return Right("000" + CountryCode, 3);
EndFunction

// Returns a string enclosed in quotes.
//
Function CheckQuotesInString(Val String)
	Return """" + StrReplace(String, """", """""") + """";
EndFunction

Procedure UpdateConextMenu(Form, ItemForPlacementName)
	
	ContactInformationParameters = Form.ContactInformationParameters[ItemForPlacementName];  // See ContactInformationOutputParameters
	AllRows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form);
	FoundRows = AllRows.FindRows( 
		New Structure("Type, IsTabularSectionAttribute", Enums.ContactInformationTypes.Address, False));
		
	TotalCommands = 0;
	For Each CIRow In AllRows Do
		
		If TotalCommands > 50 Then // Restriction for a large number of addresses on the form
			Break;
		EndIf;
		
		If CIRow.Type <> Enums.ContactInformationTypes.Address Then
			Continue;
		EndIf;
		
		ContextSubmenuCopyAddresses = Form.Items.Find("ContextSubmenuCopyAddresses" + CIRow.AttributeName);
		If ContextSubmenuCopyAddresses = Undefined Then
			Continue;
		EndIf;
			
		CommandsCountInSubmenu = 0;
		AddressesListInSubmenu = New Map();
		AddressData = New Structure("Presentation, Address", CIRow.Presentation, CIRow.Value);
		AddressesListInSubmenu.Insert(Upper(CIRow.Presentation), AddressData);
		
		For Each Address In FoundRows Do
			
			If CommandsCountInSubmenu > 7 Then // Restriction for a large number of addresses on the form
				Break;
			EndIf;
			
			If Address.IsHistoricalContactInformation Or Address.AttributeName = CIRow.AttributeName Then
				Continue;
			EndIf;
			
			If Not ValueIsFilled(Address.Presentation) Then
				Continue;
			EndIf;
			
			CommandName = "MenuSubmenuAddress" + CIRow.AttributeName + "_" + Address.AttributeName;
			Command = Form.Commands.Find(CommandName);
			If Command = Undefined Then
				Command = Form.Commands.Add(CommandName);
				Command.ToolTip = NStr("en = 'Copy address';");
				Command.Action = "Attachable_ContactInformationExecuteCommand";
				Command.ModifiesStoredData = True;
				
				ContactInformationParameters.AddedItems.Add(CommandName, 9, True);
				CommandsCountInSubmenu = CommandsCountInSubmenu + 1;
			EndIf;
			
			AddressPresentation = ?(CIRow.InternationalAddressFormat,
				StringFunctions.LatinString(Address.Presentation), Address.Presentation);
			
			If AddressesListInSubmenu[Upper(Address.Presentation)] <> Undefined Then
				AddressPresentation = "";
			Else
				AddressData = New Structure("Presentation, Address", AddressPresentation, Address.Value);
				AddressesListInSubmenu.Insert(Upper(Address.Presentation), AddressData);
			EndIf;
				
			AddButtonCopyAddress(Form, CommandName, AddressPresentation, ContactInformationParameters, 
				ContextSubmenuCopyAddresses);
						
		EndDo;
		
		Field = Form.Items[CIRow.AttributeName];
		If Field.Type = FormFieldType.InputField Then
			Field.ChoiceList.Clear();
			PresentationForSearching = Upper(CIRow.Presentation);
			For Each AddressData In AddressesListInSubmenu Do
				If AddressData.Key <> PresentationForSearching Then
					Field.ChoiceList.Add(AddressData.Value, AddressData.Value.Presentation);
				EndIf;
			EndDo;
		EndIf;
		
		TotalCommands = TotalCommands + CommandsCountInSubmenu;
	EndDo;
	
EndProcedure

Procedure AddButtonCopyAddress(Form, CommandName, ItemTitle, ContactInformationParameters, Popup)
	
	TagName = Popup.Name + "_" + CommandName;
	Button = Form.Items.Find(TagName);
	If Button = Undefined Then
		Button = Form.Items.Add(TagName, Type("FormButton"), Popup);
		Button.CommandName = CommandName;
		AddedItems = ContactInformationParameters.AddedItems; // ValueList
		AddedItems.Add(TagName, 1);
	EndIf;
	Button.Title = ItemTitle;
	Button.Visible = ValueIsFilled(ItemTitle);

EndProcedure

Function NewContactInformationDetails(Val Type) Export
	
	If ContactsManagerInternalCached.AreAddressManagementModulesAvailable() Then
		ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
		Return ModuleAddressManagerClientServer.NewContactInformationDetails(Type);
	EndIf;
	
	Return ContactsManagerClientServer.NewContactInformationDetails(Type);
	
EndFunction

Function ContactInformationFromFormAttributes(Form, Object)
	
	ContactInformation = NewContactInformation(False);
	
	ObjectMetadata = Object.Ref.Metadata();
	MetadataObjectName = ObjectMetadata.Name;
	FullMetadataObjectName = ObjectMetadata.FullName();
	ContactInformationKindsGroup = ObjectContactInformationKindsGroup(FullMetadataObjectName);
	TabularSectionsNamesByCIKinds = Undefined;
	
	For Each TableRow In ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form) Do
		
		AttributeName  = TableRow.AttributeName;
		
		Item = Form.Items.Find(AttributeName); // FormFieldExtensionForALabelField
		If Item <> Undefined Then
			If Item.Type = FormFieldType.LabelField And Item.Hyperlink Then
				If IsBlankString(TableRow.Presentation)
					Or TableRow.Presentation = ContactsManagerClientServer.BlankAddressTextAsHyperlink() Then
					Continue;
				EndIf;
			EndIf;
		EndIf;
		
		RestoreEmptyValuePresentation(TableRow);
		
		If TableRow.IsTabularSectionAttribute Then
			
			If TabularSectionsNamesByCIKinds = Undefined Then
				Filter = New Structure("IsTabularSectionAttribute", True);
				TabularSectionCIKinds = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).Unload(Filter, "Kind");
				// @skip-check query-in-loop - Runs only in one iteration when the table attribute first appears
				TabularSectionsNamesByCIKinds = TabularSectionsNamesByCIKinds(TabularSectionCIKinds, MetadataObjectName);
			EndIf;
			
			TabularSectionName = TabularSectionsNamesByCIKinds[TableRow.Kind];
			FormTabularSection = Form.Object[TabularSectionName];
			For Each FormTabularSectionRow In FormTabularSection Do
				
				RowID = FormTabularSectionRow.GetID();
				FormTabularSectionRow.TabularSectionRowID = RowID;
				
				LineOfATabularSection = Object[TabularSectionName][FormTabularSectionRow.LineNumber - 1];
				LineOfATabularSection.TabularSectionRowID = RowID;
				
				Value = FormTabularSectionRow[AttributeName + "Value"];
				
				MoveContactInformationRecordFromFormToTable(ContactInformation, TableRow, Value, RowID);
				
			EndDo;
			
		Else
			
			If TableRow.Kind.Parent <> ContactInformationKindsGroup Then
				Continue;
			EndIf;
			
			MoveContactInformationRecordFromFormToTable(ContactInformation, TableRow, TableRow.Value);
			
		EndIf;
		
	EndDo;
	
	Return ContactInformation;
	
EndFunction

Procedure MoveContactInformationRecordFromFormToTable(ContactInformation, TableRow, Val Value, Val RowID = Undefined)
	
	If IsBlankString(Value) Then
		Return;
	EndIf;
	
	If ContactsManagerClientServer.IsXMLContactInformation(Value) Then
		CIObject = ContactsManagerInternal.ContactInformationToJSONStructure(Value, TableRow.Type);
	Else
		CIObject = ContactsManagerInternal.JSONToContactInformationByFields(Value, TableRow.Type);
	EndIf;
	
	If Not ContactsManagerInternal.ContactsFilledIn(CIObject) Then
		Return;
	EndIf;
	
	ContactInformationRow = ContactInformation.Add();
	
	ValidFrom = ?(TableRow.Property("ValidFrom"), TableRow.ValidFrom, Undefined);
	FillPropertyValues(ContactInformationRow, TableRow, "Kind,Type");
	
	ContactInformationRow.Presentation = CIObject.Value;
	ContactInformationRow.Value      = ContactsManagerInternal.ToJSONStringStructure(CIObject);
	
	If ContactsManagerInternalCached.IsLocalizationModuleAvailable() Then
		ModuleContactsManagerLocalization = Common.CommonModule("ContactsManagerLocalization");
		ContactInformationRow.FieldValues = ModuleContactsManagerLocalization.ContactsFromJSONToXML(CIObject, TableRow.Type);
	EndIf;
	
	If ValueIsFilled(ValidFrom) Then
		ContactInformationRow.Date    = ValidFrom;
	EndIf;
	
	ContactInformationRow.TabularSectionRowID = RowID;
	
EndProcedure

Procedure FillContactInformationTableRowFromPresentation(ContactInformationRow, Presentation)
	ContactInformationRow.Presentation = Presentation;
	ContactInformationRow.Value      = ContactInformationInJSON(Presentation, 
		ContactInformationRow.Kind);
	ContactInformationRow.FieldValues = "";
EndProcedure

// Contact information kinds

Function ParametersFromContactInformationKind(Val ContactInformationKind)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	ContactInformationKinds.Ref AS Ref,
	|	ContactInformationKinds.Parent AS Parent,
	|	ContactInformationKinds.IsFolder AS IsFolder,
	|	ContactInformationKinds.Description AS Description,
	|	ContactInformationKinds.OnlyNationalAddress AS OnlyNationalAddress,
	|	ContactInformationKinds.FieldKindOther AS FieldKindOther,
	|	ContactInformationKinds.IncludeCountryInPresentation AS IncludeCountryInPresentation,
	|	ContactInformationKinds.DenyEditingByUser AS DenyEditingByUser,
	|	ContactInformationKinds.Used AS Used,
	|	ContactInformationKinds.CanChangeEditMethod AS CanChangeEditMethod,
	|	ContactInformationKinds.Mandatory AS Mandatory,
	|	ContactInformationKinds.CheckValidity AS CheckValidity,
	|	ContactInformationKinds.AllowMultipleValueInput AS AllowMultipleValueInput,
	|	ContactInformationKinds.EditingOption AS EditingOption,
	|	ContactInformationKinds.AddlOrderingAttribute AS AddlOrderingAttribute,
	|	ContactInformationKinds.HideObsoleteAddresses AS HideObsoleteAddresses,
	|	ContactInformationKinds.PhoneWithExtensionNumber AS PhoneWithExtensionNumber,
	|	ContactInformationKinds.PhoneNumberMask AS PhoneNumberMask,
	|	ContactInformationKinds.EnterNumberByMask AS EnterNumberByMask,
	|	ContactInformationKinds.Type AS Type,
	|	ContactInformationKinds.StoreChangeHistory AS StoreChangeHistory,
	|	ContactInformationKinds.PredefinedKindName AS Name,
	|	ContactInformationKinds.InternationalAddressFormat AS InternationalAddressFormat,
	|	ContactInformationKinds.IsAlwaysDisplayed AS IsAlwaysDisplayed
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|WHERE
	|	ContactInformationKinds.Ref = &Ref";
	
	Query.SetParameter("Ref", ContactInformationKind);
	
	QueryResult = Query.Execute().Unload();
	
	If QueryResult.Count() = 0 Then
		ErrorTextTemplate = NStr("en = 'Invalid contact information kind obtained when receiving contact information properties. %1';");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTextTemplate , String(ContactInformationKind));
		Raise ErrorText;
	EndIf;
	
	Type = QueryResult[0].Type;
	
	CurrentParameters = Common.ValueTableRowToStructure(QueryResult[0]);
	KindParameters = ContactInformationParametersDetails(Type);
	FillPropertyValues(KindParameters, CurrentParameters);
	
	If Type = Enums.ContactInformationTypes.Address Then
		
		FillPropertyValues(KindParameters.ValidationSettings, CurrentParameters, "IncludeCountryInPresentation,
		|CheckValidity,HideObsoleteAddresses,OnlyNationalAddress");
		
		If ContactsManagerInternalCached.AreAddressManagementModulesAvailable() Then
			ModuleAddressManager = Common.CommonModule("AddressManager");
			ModuleAddressManager.AddAddressVerificationSettings(KindParameters, ContactInformationKind);
		EndIf;
		
	ElsIf Type = Enums.ContactInformationTypes.Email Then
		KindParameters.ValidationSettings.CheckValidity = CurrentParameters.CheckValidity;
	ElsIf Type = Enums.ContactInformationTypes.Phone Then
		KindParameters.ValidationSettings.PhoneWithExtensionNumber = CurrentParameters.PhoneWithExtensionNumber;
		KindParameters.ValidationSettings.PhoneNumberMask = CurrentParameters.PhoneNumberMask;
		KindParameters.ValidationSettings.EnterNumberByMask = CurrentParameters.EnterNumberByMask;
	ElsIf Type = Enums.ContactInformationTypes.Other Then
		KindParameters.FieldKindOther = CurrentParameters.FieldKindOther;
	EndIf;
	
	KindParameters.Kind = QueryResult[0].Ref;
	
	Return KindParameters;
	
EndFunction

Function SettingsForCheckingContactInformationParameters(Val ContactInformationType)
	
	ValidationSettings = New Structure;
	
	If ContactInformationType =  Enums.ContactInformationTypes.Address Then
		ValidationSettings.Insert("OnlyNationalAddress",      False);
		ValidationSettings.Insert("CheckValidity",        False);
		ValidationSettings.Insert("IncludeCountryInPresentation", False);
		ValidationSettings.Insert("SpecifyRNCMT",               False);
		ValidationSettings.Insert("HideObsoleteAddresses",   False); // Obsolete. Keep for backward compatibility.
		ValidationSettings.Insert("CheckByFIAS",              True); // Obsolete. Keep for backward compatibility.
	ElsIf ContactInformationType = Enums.ContactInformationTypes.Email Then
		ValidationSettings = New Structure;
		ValidationSettings.Insert("CheckValidity",        False);
	ElsIf ContactInformationType =  Enums.ContactInformationTypes.Phone Then
		ValidationSettings = New Structure;
		ValidationSettings.Insert("PhoneWithExtension",    True);
		ValidationSettings.Insert("PhoneWithExtensionNumber",    True);
		ValidationSettings.Insert("EnterNumberByMask", False);
		ValidationSettings.Insert("PhoneNumberMask", "");
	EndIf;
	
	Return ValidationSettings;

EndFunction

Function ContactInformationKindObject(Name, IsFolder = False)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	ContactInformationKinds.Ref AS Ref
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|WHERE
	|	ContactInformationKinds.PredefinedKindName = &Name
	|	AND ContactInformationKinds.IsFolder = &IsFolder";
	
	Query.SetParameter("Name", Name);
	Query.SetParameter("IsFolder", IsFolder);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		SelectionDetailRecords = QueryResult.Unload();
		Ref = SelectionDetailRecords[0].Ref;
		Return Ref.GetObject();
	EndIf;
	
	PredefinedItemsNames = Metadata.Catalogs.ContactInformationKinds.GetPredefinedNames();
	PredefinedItemName  = PredefinedItemsNames.Find(Name);
	
	If PredefinedItemName <> Undefined Then
		Object = Catalogs.ContactInformationKinds[Name].GetObject();
		Object.PredefinedKindName = Name;
		Return Object;
	EndIf;
	
	If IsFolder Then
		NewItem = Catalogs.ContactInformationKinds.CreateFolder();
	Else
		NewItem = Catalogs.ContactInformationKinds.CreateItem();
	EndIf;
	
	NewItem.PredefinedKindName = Name;
	
	Return NewItem;
	
EndFunction

// Returns details of contact information properties for the passed contact information type.
// The structure is used in update handlers when filling in contact information kinds 
// or generating opening parameters of the address or phone input form for the method used in OpenContactInformationForm.
// 
// Parameters:
//    ContactInformationType - EnumRef.ContactInformationTypes - contact information type.
//
// Returns:
//   Structure:
//     * Name          - String - a unique name of a contact information kind.
//     * Description - String - a description of a contact information kind.
//     * Kind - CatalogRef.ContactInformationKinds - a reference to a contact information kind.
//                                                         Default value - CatalogRef.ContactInformationKinds.EmptyRef.
//     * Type - EnumRef.ContactInformationTypes - contact information type.
//     * Group - CatalogRef.ContactInformationKinds
//              - Undefined - a reference to a group (parent) of a catalog item.
//                               Default value is Undefined.
//     * Used - Boolean - if False, a contact information kind is not available for users.
//                               Such a kind is not displayed in forms and lists of contact information kinds.
//                               Default value is True.
//     * CanChangeEditMethod - Boolean - indicates whether a user can change properties of a contact information kind.
//                                                    If False, properties of a contact information kind form
//                                                    are view-only. The default value is False.
//     * EditingOption - String - a value editing method. Available options: InputFieldAndDialog, InputField, and Dialog.
//                                    If Dialog, the form displays a hyperlink with a contact
//                                    information presentation. Clicking it opens the form of the matching contact information type.
//                                    The property is applicable only for the following contact information types: Address, Phone, and Fax.
//                                    If InputField, an input field is displayed on the form.
//                                    If InputFieldAndDialog, both the input field and the input form of the matching contact information type are available.
//     * StoreChangeHistory     - Boolean - indicates whether the contact information change history can be stored.
//                                              Storing the history is allowed if EditingOption = "Dialog".
//                                              The property is only applicable when the tabular section ContactInformation
//                                              contains the ValidFrom attribute. Default value is False.
//     * Mandatory       - Boolean - if True, a value in the contact
//                                               information field is mandatory. The default value is False.
//     * AllowMultipleValueInput - Boolean - indicates whether multiple value input is available for this kind.
//                                                  The default value is False.
//     * DenyEditingByUser - Boolean - indicates that editing of
//                                                       a contact information kind by a user is unavailable. The default value is False.
//     * InternationalAddressFormat - Boolean - indicates that an address format is international. 
//                                   If True, all addresses can be entered in international format only.
//                                   The default value is False.
//     * FieldKindOther             - String - Defines the Other field layout on the form. Available options:
//                                            MultilineWide, SingleLineWide, SingleLineNarrow. The property
//                                            is applicable only for contact information with the type: Other. The default value for a contact information kind with
//                                            the Other type is SingleLineWide, otherwise, a blank string.
//     * EditInDialogOnly - Boolean - obsolete. Use EditingOption instead.
//                                               If True, the form displays a hyperlink with a contact
//                                               information presentation. Click it to open the form of the matching
//                                               contact information type. The property is applicable only for contact information with the type:
//                                               Address, Phone, Fax, WebPage. Default value is False.
//     * ValidationSettings - Undefined - for the Other, WebPage, and Skype types 
//                         - Structure - The field set varies for different contact information types: 
//       ** OnlyNationalAddress- Boolean - for the Address type. If True, you can enter only national
//                                                          addresses. Changing the address country is not allowed.
//       ** CheckValidity - Boolean - For the EmailAddress type.
//                                           If True, forbid users to save invalid email addresses. By default, False.
//                                           
//                                           
//                                           
//       ** IncludeCountryInPresentation - Boolean - for the Address type. if True, a Country description is always
//                                                 added to an address presentation even when other address fields are blank.
//                                                 The default value is False.
//       ** SpecifyRNCMT - Boolean - for the Address type. indicates whether manual input of an RNCMT code is available in the address input form.
//       ** CheckValidity - Boolean - For the EmailAddress type. 
//                                           If True, forbid users to save invalid email addresses. By default, False.
//       ** PhoneWithExtensionNumber - Boolean - for the Phone or Fax type. If true,
//                                               you can enter an extension in the phone input form. The default value is True.
//
Function ContactInformationParametersDetails(Val ContactInformationType)
	
	KindParameters = ContactInformationKindCommonParametersDetails();
	
	KindParameters.Insert("Kind", Catalogs.ContactInformationKinds.EmptyRef());
	KindParameters.Insert("Order", Undefined);
	KindParameters.Insert("Type", ContactInformationType);
	KindParameters.Insert("CanChangeEditMethod",    False);
	KindParameters.Insert("EditInDialogOnly",         False);  // Obsolete. Keep for backward compatibility.
	KindParameters.Insert("Mandatory",               False);
	KindParameters.Insert("AllowMultipleValueInput",      False);
	KindParameters.Insert("DenyEditingByUser", False);
	KindParameters.Insert("StoreChangeHistory",              False);
	KindParameters.Insert("InternationalAddressFormat",            False);
	KindParameters.Insert("CorrectObsoleteAddresses",           False);
	KindParameters.Insert("IsAlwaysDisplayed",                     True);
	
	FieldKindOther = ?(ContactInformationType = Enums.ContactInformationTypes.Other,
		"SingleLineWide", "");
	
	If ContactInformationType = Enums.ContactInformationTypes.Address
		 Or ContactInformationType = Enums.ContactInformationTypes.Fax
		 Or ContactInformationType = Enums.ContactInformationTypes.Phone Then
			EditingOption = "InputFieldAndDialog";
	ElsIf ContactInformationType = Enums.ContactInformationTypes.WebPage Then
			EditingOption = "Dialog";
	Else
			EditingOption = "InputField";
	EndIf;
	
	KindParameters.Insert("EditingOption", EditingOption);
	KindParameters.Insert("FieldKindOther",     FieldKindOther);
	
	ValidationSettings = SettingsForCheckingContactInformationParameters(ContactInformationType);
	
	KindParameters.Insert("ValidationSettings", ValidationSettings);
	Return KindParameters;

EndFunction

Function ContactInformationKindCommonParametersDetails()
	
	KindParameters = New Structure;
	KindParameters.Insert("Name", "");
	KindParameters.Insert("Group", Undefined);
	KindParameters.Insert("Description", "");
	KindParameters.Insert("Used", True);
	
	Return KindParameters;
	
EndFunction

// Constructor of world country details. 
// 
// Parameters:
//   QueryResult - Structure - filling data.
// 	 
// Returns:
//   Structure:
//    Code — String — numeric country code by classifier;
//    CodeAlpha2 — String — two-letter country code by classifier;
//    CodeAlpha3 — String — three-letter country code by classifier;
//    Description — String — a short description of the country
//    DescriptionFull — String — a full description of the country;
//    EEUMember — Boolean — the country is a member of the Eurasian Economic Union;
//    NonRelevant — Boolean — marked for deletion.
//
Function WorldCountryDetails(FillingData)
	
	Result = New Structure;
	Result.Insert("Code", "");
	Result.Insert("CodeAlpha2", "");
	Result.Insert("CodeAlpha3", "");
	Result.Insert("Description", "");
	Result.Insert("DescriptionFull", "");
	Result.Insert("InternationalDescription", "");
	Result.Insert("EEUMember", False);
	Result.Insert("NonRelevant", False);
	
	FillPropertyValues(Result, FillingData);
	
	Return Result
EndFunction

// The EAEU countries added to the WorldCountries catalog by a user.
// 
// Returns:
//   See EEUMemberCountries
// 
Function CustomEAEUCountries() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	WorldCountries.Ref AS Ref,
		|	WorldCountries.Description AS Description,
		|	WorldCountries.Code AS Code,
		|	WorldCountries.DescriptionFull AS DescriptionFull,
		|	WorldCountries.CodeAlpha2 AS CodeAlpha2,
		|	WorldCountries.InternationalDescription AS InternationalDescription,
		|	WorldCountries.CodeAlpha3 AS CodeAlpha3
		|FROM
		|	Catalog.WorldCountries AS WorldCountries
		|WHERE
		|	WorldCountries.EEUMember = TRUE";
	
	EEUCountries = Query.Execute().Unload();
	
	Return EEUCountries;
	
EndFunction

Function GenerateQueryText(Val HasColumnTabularSectionRowID, Val QueryTextHistoricalInformation, Val IsMainLanguage)
	
		QueryText = "SELECT
	|	ContactInformation.Presentation               AS Presentation,
	|	ContactInformation.Value                    AS Value,
	|	ContactInformation.FieldValues               AS FieldValues,
	|	ContactInformation.LineNumber                 AS LineNumber,
	|	&ValidFrom                                      AS ValidFrom,
	|	&IsHistoricalContactInformation             AS IsHistoricalContactInformation,
	|	ContactInformation.Kind                         AS Kind,
	|	&TabularSectionRowID               AS TabularSectionRowID
	|INTO 
	|	ContactInformation
	|FROM
	|	&ContactInformationTable1 AS ContactInformation
	|INDEX BY
	|	Kind
	|;////////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	ContactInformationKinds.Ref                       AS Kind,
	|CASE
	|	WHEN ContactInformationKinds.PredefinedKindName <> """"
	|	THEN ContactInformationKinds.PredefinedKindName
	|	ELSE ContactInformationKinds.PredefinedDataName
	|END AS PredefinedKindName,
	|	ContactInformationKinds.PredefinedDataName AS PredefinedDataName,
	|	ContactInformationKinds.Type                          AS Type,
	|	ContactInformationKinds.IsAlwaysDisplayed             AS IsAlwaysDisplayed,
	|	ContactInformationKinds.Mandatory       AS Mandatory,
	|	ContactInformationKinds.FieldKindOther                AS FieldKindOther,
	|	ContactInformationKinds.AllowMultipleValueInput AS AllowMultipleValueInput,
	|	ContactInformationKinds.Description AS PresentationInDefaultLanguage,
	|	ContactInformationKinds.Description AS Description,
	|	ContactInformationKinds.StoreChangeHistory      AS StoreChangeHistory,
	|	ContactInformationKinds.EditingOption            AS EditingOption,
	|	ContactInformationKinds.IsFolder                    AS IsTabularSectionAttribute,
	|	ContactInformationKinds.AddlOrderingAttribute    AS AddlOrderingAttribute,
	|	ContactInformationKinds.InternationalAddressFormat    AS InternationalAddressFormat,
	|	ContactInformationKinds.EnterNumberByMask  AS EnterNumberByMask,
	|	ContactInformationKinds.PhoneNumberMask    AS PhoneNumberMask,
	|	ISNULL(ContactInformation.IsHistoricalContactInformation, FALSE)    AS IsHistoricalContactInformation,
	|	ISNULL(ContactInformation.Presentation, """")    AS Presentation,
	|	ISNULL(ContactInformation.FieldValues, """")    AS FieldValues,
	|	ISNULL(ContactInformation.Value, """")         AS Value,
	|	ISNULL(ContactInformation.ValidFrom, 0)          AS ValidFrom,
	|	ISNULL(ContactInformation.LineNumber, 0)         AS LineNumber,
	|	ISNULL(ContactInformation.TabularSectionRowID, 0)    AS TabularSectionRowID,
	|	CAST("""" AS STRING(200))                        AS AttributeName,
	|	CAST("""" AS STRING(200))                        AS AttributeNameComment,
	|	ContactInformationKinds.DeletionMark              AS DeletionMark,
	|	CAST("""" AS STRING)                             AS Comment
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|LEFT JOIN
	|	ContactInformation AS ContactInformation
	|ON
	|	ContactInformationKinds.Ref = ContactInformation.Kind
	|WHERE
	|	ContactInformationKinds.Used
	|	AND ISNULL(ContactInformationKinds.Parent.Used, TRUE)
	|	AND (
	|		ContactInformationKinds.Parent = &CIKindsGroup
	|		OR ContactInformationKinds.Parent.Parent = &CIKindsGroup)
	|	AND ContactInformationKinds.Ref NOT IN (&HiddenKinds)
	|ORDER BY
	|	ContactInformationKinds.Ref HIERARCHY
	|";
		
	CurrentLanguageSuffix = Common.CurrentUserLanguageSuffix();
		
	If CurrentLanguageSuffix <> Undefined Then
		
		If ValueIsFilled(CurrentLanguageSuffix) Then
			ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
			ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(QueryText, "ContactInformationKinds.Description AS Description");
		EndIf;
		
	Else
		
		QueryText = StrReplace(QueryText, "ContactInformationKinds.Description AS Description", 
			"CAST(ISNULL(TypesOfPresentationContactInformation.Description, ContactInformationKinds.Description) AS STRING(150)) AS Description");
		
		QueryText = StrReplace(QueryText, "WHERE", "LEFT JOIN Catalog.ContactInformationKinds.Presentations AS TypesOfPresentationContactInformation
		|ON TypesOfPresentationContactInformation.Ref = ContactInformationKinds.Ref
		|	AND TypesOfPresentationContactInformation.LanguageCode = &LanguageCode
		|WHERE");
		
	EndIf;
	
	QueryText = StrReplace(QueryText, "&TabularSectionRowID",
		?(HasColumnTabularSectionRowID,
		"ISNULL(ContactInformation.TabularSectionRowID, 0)",
		"0"));
	
	If QueryTextHistoricalInformation Then
		QueryText = StrReplace(QueryText, "&ValidFrom", "ContactInformation.ValidFrom");
		QueryText = StrReplace(QueryText, "&IsHistoricalContactInformation", "ContactInformation.IsHistoricalContactInformation");
	Else
		QueryText = StrReplace(QueryText, "&ValidFrom", "0");
		QueryText = StrReplace(QueryText, "&IsHistoricalContactInformation", "FALSE");
	EndIf;
	
	Return QueryText;
	
EndFunction

// Restore password.

// The attribute name for password recovery
//
// Parameters:
//  ContactInformation - FormDataCollection
// 
// Returns:
//  String - — an attribute name in the form with a password recovery email.
//
Function TheNameOfTheDetailsForPasswordRecovery(Form, Email, TypeOrTypeOfUserSEmailAddress)
	
	NameOfThePasswordRecoveryAccount = "";
	
	EmailDescription = EmailDescriptionStringForPasswordRecoveryFromFormData(
		Form, TypeOrTypeOfUserSEmailAddress, Email);
	
	If EmailDescription = Undefined Then
		// The first email is a recovery email.
		EmailDescription = EmailDescriptionStringForPasswordRecoveryFromFormData(
			Form, TypeOrTypeOfUserSEmailAddress);
	EndIf;
	
	If EmailDescription <> Undefined Then
		NameOfThePasswordRecoveryAccount = EmailDescription.AttributeName;
	EndIf;
	
	Return NameOfThePasswordRecoveryAccount;
	
EndFunction

Procedure SetActionsForStaticItems(Form, CIRow, ItemForPlacementName)

	Item = Form.Items[CIRow.AttributeName];
	Type = CIRow.Type;

	ContactInformationParameters = FormContactInformationParameters(Form.ContactInformationParameters,
		ItemForPlacementName);
	URLProcessing = ContactInformationParameters.URLProcessing;

	If CIRow.EditingOption = "Dialog" And CIRow.Type = Enums.ContactInformationTypes.Address 
		And Item.Type = FormFieldType.LabelField Then

	If Not ValueIsFilled(Item.GetAction("Click")) Then
		Item.SetAction("Click", "Attachable_ContactInformationOnClick");
	EndIf;

	ElsIf Type = Enums.ContactInformationTypes.WebPage And URLProcessing And Item.Type = FormFieldType.LabelField Then

		If Not ValueIsFilled(Item.GetAction("URLProcessing")) Then
			Item.SetAction("URLProcessing", "Attachable_ContactInformationURLProcessing");
		EndIf;

	ElsIf Item.Type = FormFieldType.InputField Then 

		If Not ValueIsFilled(Item.GetAction("Clearing")) Then
			Item.SetAction("Clearing", "Attachable_ContactInformationClearing");
		EndIf;

		If Type = Enums.ContactInformationTypes.Address Then
			If Not ValueIsFilled(Item.GetAction("AutoComplete")) Then
				Item.SetAction("AutoComplete", "Attachable_ContactInformationAutoComplete");
			EndIf;
			If Not ValueIsFilled(Item.GetAction("ChoiceProcessing")) Then
				Item.SetAction("ChoiceProcessing", "Attachable_ContactInformationChoiceProcessing");
			EndIf;
		EndIf;

	EndIf;
	
	// Edit in dialog.
	If CanEditContactInformationTypeInDialog(Type) And Item.Type = FormFieldType.InputField
		And Not CIRow.EditingOption = "InputField" Then

		ChoiceAvailable = Not CIRow.DeletionMark And CIRow.EditingOption <> "InputField";

		If ChoiceAvailable And Not Form.ReadOnly Then
			Item.ChoiceButton = True;
			If Not ValueIsFilled(Item.GetAction("StartChoice")) Then
				Item.SetAction("StartChoice", "Attachable_ContactInformationStartChoice");
			EndIf;
		Else
			Item.ChoiceButton   = False;
			If ValueIsFilled(Form[CIRow.AttributeName]) Then
				Item.OpenButton = True;
				If Not ValueIsFilled(Item.GetAction("Opening")) Then
					Item.SetAction("Opening", "Attachable_ContactInformationOnClick");
				EndIf;
			EndIf;
		EndIf;

	EndIf;

	If Not ValueIsFilled(Item.GetAction("OnChange")) Then
		Item.SetAction("OnChange", "Attachable_ContactInformationOnChange");
	EndIf;
	
	If HasCommentFieldForContactInfoType(Type, URLProcessing) Then
		ItemNameComment = "Comment" + CIRow.AttributeName;
		If Form.Items.Find(ItemNameComment) <> Undefined Then
			If Not ValueIsFilled(Form.Items[ItemNameComment].GetAction("OnChange")) Then
				Form.Items[ItemNameComment].SetAction("OnChange", "Attachable_ContactInformationOnChange");
			EndIf;
		EndIf;
	EndIf;

EndProcedure

// Describes additional output parameters of contact information.
// 
// Parameters:             
//   DetailsOfCommands   - See DetailsOfCommands 
//   ShouldShowIcons - Boolean
//   ItemsPlacedOnForm - Map of KeyAndValue:
//     * Key - CatalogRef.ContactInformationKinds
//     * Value - Boolean
//                - Undefined
//   AllowAddingFields - Boolean
//   ExcludedKinds  - Array
//                    - Undefined
//   HiddenKinds   - Array
//                    - Undefined
// 	
// Returns:
//  Structure:
//    * DetailsOfCommands   - See DetailsOfCommands 
//    * ShouldShowIcons - Boolean
//    * ItemsPlacedOnForm - Map of KeyAndValue:
//        ** Key - CatalogRef.ContactInformationKinds
//        ** Value - Boolean
//                    - Undefined
//    * AllowAddingFields - Boolean
//    * ExcludedKinds  - Array
//                       - Undefined
//    * HiddenKinds   - Array
//                       - Undefined
//    * CommentFieldWidth - Number
//    * PositionOfAddButton - ItemHorizontalLocation
//
Function AdditionalParametersOfContactInfoOutput(DetailsOfCommands, ShouldShowIcons, ItemsPlacedOnForm,
	AllowAddingFields, ExcludedKinds, HiddenKinds) 

	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("DetailsOfCommands",           DetailsOfCommands);
	AdditionalParameters.Insert("ShouldShowIcons",         ShouldShowIcons);
	AdditionalParameters.Insert("ItemsPlacedOnForm",         ItemsPlacedOnForm);
	AdditionalParameters.Insert("AllowAddingFields", AllowAddingFields);
	AdditionalParameters.Insert("ExcludedKinds",          ExcludedKinds);
	AdditionalParameters.Insert("HiddenKinds",           HiddenKinds);
	AdditionalParameters.Insert("CommentFieldWidth",    30);
	AdditionalParameters.Insert("PositionOfAddButton", ItemHorizontalLocation.Left);
	
	Return AdditionalParameters;

EndFunction

Function SubsystemSettings(ContactInformationOwner)
	
	Settings = New Structure;
	Settings.Insert("ShouldShowIcons", False);
	Settings.Insert("DetailsOfCommands", DetailsOfCommands());
	Settings.Insert("PositionOfAddButton", ItemHorizontalLocation.Left);
	Settings.Insert("CommentFieldWidth", 30);
	
	ContactsManagerOverridable.OnDefineSettings(Settings);
	
	Return Settings;
	
EndFunction

// Looks up for a button in contact information groups.
// 
// Parameters:
//   Group - FormGroup
//          - FormItems
//   IsStringGroup - Boolean - If True, search for a button in the group's child elements.
// 
// Returns:
//   Boolean
//
Function HasContactInfoButton(Group, IsStringGroup)

	If IsStringGroup Then  
		If TypeOf(Group) = Type("FormGroup") Then
			For Each GroupItem In Group.ChildItems Do
				If GroupItem.Type = FormButtonType.UsualButton Then
					Return True;
				EndIf;
			EndDo;
		EndIf;
	Else
		For Each GroupWithFields In Group Do
			If TypeOf(GroupWithFields) <> Type("FormGroup") Then
				Continue;
			EndIf;
			For Each GroupItem In GroupWithFields.ChildItems Do
				If GroupItem.Type = FormButtonType.UsualButton Then
					Return True;
				EndIf;
			EndDo;
		EndDo;
	EndIf;
	
	Return False;

EndFunction

// Returns an icon by the given contact information type
//
// Parameters:
//  ContactInformationType	 - EnumRef.ContactInformationTypes
// 
// Returns:
//  Picture - A contact information icon.
//
Function PictureContactInfoType(ContactInformationType)
	
	Return ContactsManagerInternalCached.PicturesOfContactInfoTypes().Get(ContactInformationType);
		
EndFunction

// Checks if the contact information type has the "Comment" field
//
// Parameters:
//  ContactInformationType	     - EnumRef.ContactInformationTypes
//  URLProcessing - Boolean
// 
// Returns:
//  Boolean - The comment presence flag.
//
Function HasCommentFieldForContactInfoType(ContactInformationType, URLProcessing)
	
	If ContactInformationType = Enums.ContactInformationTypes.Address 
		Or ContactInformationType = Enums.ContactInformationTypes.Other 
		Or (ContactInformationType = Enums.ContactInformationTypes.WebPage And URLProcessing) Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

// Looks up for a hyperlink.
// 
// Parameters:
//  Item - FormGroup
//          - FormField
// 
// Returns:
//  Boolean
//
Function HasHyperlink(Item)

	If TypeOf(Item) = Type("FormGroup") Then
		For Each GroupItem In Item.ChildItems Do
			If GroupItem.Type = FormFieldType.LabelField Then
				Return True;
			EndIf;
		EndDo;
	ElsIf TypeOf(Item) = Type("FormField") And Item.Type = FormFieldType.LabelField Then
		Return True;
	EndIf;

	Return False;

EndFunction

#EndRegion