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

#Region UserNotification

// Generates and displays a message that might be related to a form's control element.
//
// In a long-running operation background job, if the call was made outside of a transaction,
// the procedure writes the message to an internal register and sends it to client if Collaboration System is integrated.
// At the end of the background job or when sending the progress,
// the procedure gets all messages from the message queue and writes
// them to the internal register and sends them to client, if Collaboration System is integrated.
// ACC:142-off - Four optional parameters required for compatibility with the obsolete procedure
// CommonClientServer.MessageToUser.
//
//  
// 
//
// Parameters:
//  MessageToUserText - String - message text.
//  DataKey - Arbitrary - Infobase record key, object, or object reference associated with the message.
//  Field - String - a form attribute description.
//  DataPath - String - a data path (a path to a form attribute).
//  Cancel - Boolean - an output parameter. Always True.
//
// Example:
//
//  1. Show the message associated with the object attribute near the form field:
//  Common.MessageToUser(
//   NStr("en = 'Error message.'"), ,
//   "FieldInFormAttributeObject",
//   "Object");
//
//  An alternative variant of using in the object form module:
//  Common.MessageToUser(
//   NStr("en = 'Error message.'"), ,
//   "Object.FieldInFormAttributeObject");
//
//  2. Showing a message for the form attribute, next to the form field:
//  Common.MessageToUser(
//   NStr("en = 'Error message.'"), ,
//   "FormAttributeName");
//
//  3. To display a message associated with an infobase object:
//  Common.MessageToUser(
//   NStr("en = 'Error message.'"), InfobaseObject, "Responsible person",,Cancel);
//
//  4. To display a message from a link to an infobase object:
//  Common.MessageToUser(
//   NStr("en = 'Error message.'"), Reference, , , Cancel);
//
//  Scenarios of incorrect using:
//   1. Passing DataKey and DataPath parameters at the same time.
//   2. Passing a value of an illegal type to the DataKey parameter.
//   3. Specifying a reference without specifying a field (and/or a data path).
//
Procedure MessageToUser(Val MessageToUserText, Val DataKey = Undefined,	Val Field = "",
	Val DataPath = "", Cancel = False) Export
	
	IsObject = False;
	
	If DataKey <> Undefined
		And XMLTypeOf(DataKey) <> Undefined Then
		
		ValueTypeAsString = XMLTypeOf(DataKey).TypeName;
		IsObject = StrFind(ValueTypeAsString, "Object.") > 0;
	EndIf;
	
	Message = CommonInternalClientServer.UserMessage(MessageToUserText,
		DataKey, Field, DataPath, Cancel, IsObject);
	
#If Not MobileStandaloneServer Then
	If StandardSubsystemsCached.IsLongRunningOperationSession()
	   And Not TransactionActive() Then
		
		TimeConsumingOperations.SendClientNotification("UserMessage", Message);
	Else
		Message.Message();
	EndIf;
#Else
		Message.Message();
#EndIf
	
EndProcedure

// ACC:142-on

#EndRegion

#If Not MobileStandaloneServer Then

#Region InfobaseData

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions to manage infobase data.

// Returns a structure containing attribute values retrieved from the infobase using the object reference.
// It is recommended that you use it instead of referring to object attributes via the point from the reference to an object
// for quick reading of separate object attributes from the database.
//
// To read attribute values regardless of current user rights,
// enable privileged mode.
//
// Parameters:
//  Ref    - AnyRef - the object whose attribute values will be read.
//            - String      - full name of the predefined item whose attribute values will be read.
//  Attributes - String - attribute names separated with commas, formatted
//                       according to structure requirements.
//                       Example: "Code, Description, Parent".
//            - Structure
//            - FixedStructure - the field alias is passed
//                       as a key for the passed structure with the result,
//                       an actual field name in the table (optional) is passed as a value.
//                       If the key is defined but the value is not specified, the field name is retrieved from the key.
//                       It is allowed to specify a dot-separated field name, but the LanguageCode parameter for such field
//                       is ignored.
//            - Array of String
//            - FixedArray of String - Attribute names formatted according to structure property requirements.
//  SelectAllowedItems - Boolean - If True, user rights are considered when executing the object query;
//                                if there is a restriction at the record level, all attributes will return with 
//                                the Undefined value. If there are insufficient rights to work with the table, an exception will appear;
//                                if False, an exception is raised if the user has no rights to access the table 
//                                or any attribute.
//  LanguageCode - String - language code for a multilanguage attribute. Default value is the main configuration language.
//
// Returns:
//  Structure - contains names (keys) and values of the requested attributes.
//              If a blank string is passed to Attributes, a blank structure returns.
//              If a blank reference is passed to Ref, a structure 
//              matching names of Undefined attributes returns.
//              If a reference to nonexisting object (invalid reference) is passed to Ref, 
//              all attributes return as Undefined.
//
Function ObjectAttributesValues(Ref, Val Attributes, SelectAllowedItems = False, Val LanguageCode = Undefined) Export
	
	// If the name of a predefined item is passed.
	If TypeOf(Ref) = Type("String") Then
		
		FullNameOfPredefinedItem = Ref;
		
		// Calculate a reference by the name of a predefined item.
		// - Preliminary verify the item's metadata.
		Try
			Ref = PredefinedItem(FullNameOfPredefinedItem);
		Except
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of the %1 parameter, function %2:
				|%3.';"), "Ref", "Common.ObjectAttributesValues", 
				ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			Raise(ErrorText, ErrorCategory.ConfigurationError);
		EndTry;
		
		// Parsing the full name of the predefined item.
		FullNameParts1 = StrSplit(FullNameOfPredefinedItem, ".");
		FullMetadataObjectName = FullNameParts1[0] + "." + FullNameParts1[1];
		
		// If the predefined item was not created in the infobase, check access to the object.
		// In other cases, the check is performed when executing the query.
		If Ref = Undefined Then 
			ObjectMetadata = MetadataObjectByFullName(FullMetadataObjectName);
			If Not AccessRight("Read", ObjectMetadata) Then 
				Raise(StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Insufficient rights to access table %1.';"), FullMetadataObjectName),
					ErrorCategory.AccessViolation);
			EndIf;
		EndIf;
		
	Else // If a reference is passed.
		
		Try
			FullMetadataObjectName = Ref.Metadata().FullName(); 
		Except
			Raise (StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invalid value of the %1 parameter, function %2:
					|The value must contain predefined item name or reference.';"), 
				"Ref", "Common.ObjectAttributesValues"),
				ErrorCategory.ConfigurationError);
		EndTry;
		
	EndIf;
	
	// Parsing the attributes if the second parameter is String.
	If TypeOf(Attributes) = Type("String") Then
		If IsBlankString(Attributes) Then
			Return New Structure;
		EndIf;
		
		Attributes = StrSplit(Attributes, ",", False);
		For IndexOf = 0 To Attributes.UBound() Do
			Attributes[IndexOf] = TrimAll(Attributes[IndexOf]);
		EndDo;
	EndIf;
	
	MultilingualAttributes = New Map;
	LanguageSuffix = "";
	If ValueIsFilled(LanguageCode) Then
		If SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			ModuleNationalLanguageSupportServer = CommonModule("NationalLanguageSupportServer");
			LanguageSuffix = ModuleNationalLanguageSupportServer.LanguageSuffix(LanguageCode);
			If ValueIsFilled(LanguageSuffix) Then
				MultilingualAttributes = ModuleNationalLanguageSupportServer.MultilingualObjectAttributes(Ref);
			EndIf;
		EndIf;
	EndIf;
	
	// Converting the attributes to the unified format.
	FieldsStructure = New Structure;
	If TypeOf(Attributes) = Type("Structure")
		Or TypeOf(Attributes) = Type("FixedStructure") Then
		
		For Each KeyAndValue In Attributes Do
			FieldsStructure.Insert(KeyAndValue.Key, TrimAll(KeyAndValue.Value));
		EndDo;
		
	ElsIf TypeOf(Attributes) = Type("Array")
		Or TypeOf(Attributes) = Type("FixedArray") Then
		
		For Each Attribute In Attributes Do
			Attribute = TrimAll(Attribute);
			Try
				FieldAlias = StrReplace(Attribute, ".", "");
				FieldsStructure.Insert(FieldAlias, Attribute);
			Except 
				// If the alias is not a key.
				
				// Searching for field availability error.
				Result = CheckIfObjectAttributesExist(FullMetadataObjectName, Attributes);
				If Result.Error Then 
					Raise(StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Invalid value of the %1 parameter, function %2: %3.';"),
						"Attributes", "Common.ObjectAttributesValues", Result.ErrorDescription),
						ErrorCategory.ConfigurationError);
				EndIf;
				
				// Cannot identify the error. Forwarding the original error.
				Raise;
			
			EndTry;
		EndDo;
	Else
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid type of parameter %1 in function %2: %3.';"), 
			"Attributes", "Common.ObjectAttributesValues", String(TypeOf(Attributes))),
			ErrorCategory.ConfigurationError);
	EndIf;
	
	// Preparing the result (will be redefined after the query).
	Result = New Structure;
	
	// Generating the text of query for the selected fields.
	FieldQueryText = "";
	For Each KeyAndValue In FieldsStructure Do
		
		FieldName = ?(ValueIsFilled(KeyAndValue.Value),
						KeyAndValue.Value,
						KeyAndValue.Key);
		FieldAlias = KeyAndValue.Key;
		
		If MultilingualAttributes[FieldName] <> Undefined Then
			FieldName = FieldName + LanguageSuffix;
		EndIf;
		
		FieldQueryText = 
			FieldQueryText + ?(IsBlankString(FieldQueryText), "", ",") + "
			|	" + FieldName + " AS " + FieldAlias;
		
		// Adding the field by its alias to the return value.
		Result.Insert(FieldAlias);
		
	EndDo;
	
	// In case the predefined item is missing from the infobase.
	// - Translate the result to either a missing object or passing an empty Ref.
	If Ref = Undefined Then 
		Return Result;
	EndIf;
	
	If Type("Structure") = TypeOf(Attributes)
		Or Type("FixedStructure") = TypeOf(Attributes) Then
		Attributes = New Array;
		For Each KeyAndValue In FieldsStructure Do
			FieldName = ?(ValueIsFilled(KeyAndValue.Value),
						KeyAndValue.Value,
						KeyAndValue.Key);
			Attributes.Add(FieldName);
		EndDo;
	EndIf;
	
	BankDetailsViaAPoint = New Array;
	For IndexOf = -Attributes.UBound() To 0 Do
		FieldName = Attributes[-IndexOf];
		If StrFind(FieldName, ".") Then
			BankDetailsViaAPoint.Add(FieldName);
			Attributes.Delete(-IndexOf);
		EndIf;
	EndDo;
	
	If ValueIsFilled(Attributes) Then
		ObjectAttributesValues = ObjectsAttributesValues(CommonClientServer.ValueInArray(Ref), Attributes, SelectAllowedItems, LanguageCode)[Ref];
		If ObjectAttributesValues <> Undefined Then
			For Each KeyAndValue In FieldsStructure Do
				FieldName = ?(ValueIsFilled(KeyAndValue.Value),
							KeyAndValue.Value,
							KeyAndValue.Key);
				If StrFind(FieldName, ".") = 0 And ObjectAttributesValues.Property(FieldName) Then
					Result[KeyAndValue.Key] = ObjectAttributesValues[FieldName];
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(BankDetailsViaAPoint) Then
		Return Result;
	EndIf;
	
	Attributes = BankDetailsViaAPoint;
	
	QueryText = 
		"SELECT ALLOWED
		|&FieldQueryText
		|FROM
		|	&FullMetadataObjectName AS SpecifiedTableAlias
		|WHERE
		|	SpecifiedTableAlias.Ref = &Ref";
	
	If Not SelectAllowedItems Then 
		QueryText = StrReplace(QueryText, "ALLOWED", ""); // @Query-part-1
	EndIf;
	
	QueryText = StrReplace(QueryText, "&FieldQueryText", FieldQueryText);
	QueryText = StrReplace(QueryText, "&FullMetadataObjectName", FullMetadataObjectName);
	
	// Run the query.
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text = QueryText;
	
	Try
		Selection = Query.Execute().Select();
	Except
		
		// Attributes passed as String are already converted into Array.
		// If the attributes are passed as Array, do nothing.
		// If the attributes are passed as Structure, convert them into Array.
		// Other cases already caused an exception.
		If Type("Structure") = TypeOf(Attributes)
			Or Type("FixedStructure") = TypeOf(Attributes) Then
			Attributes = New Array;
			For Each KeyAndValue In FieldsStructure Do
				FieldName = ?(ValueIsFilled(KeyAndValue.Value),
							KeyAndValue.Value,
							KeyAndValue.Key);
				Attributes.Add(FieldName);
			EndDo;
		EndIf;
		
		// Searching for field availability error.
		Result = CheckIfObjectAttributesExist(FullMetadataObjectName, Attributes);
		If Result.Error Then 
			Raise(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invalid value of the %1 parameter, function %2: %3.';"), 
				"Attributes", "Common.ObjectAttributesValues", Result.ErrorDescription),
				ErrorCategory.ConfigurationError);
		EndIf;

		Raise;
		
	EndTry;
	
	// Populate attributes.
	If Selection.Next() Then
		FillPropertyValues(Result, Selection);
	EndIf;
	
	Return Result;
	
EndFunction

// Returns attribute values retrieved from the infobase using the object reference.
// It is recommended that you use it instead of referring to object attributes via the point from the reference to an object
// for quick reading of separate object attributes from the database.
//
// To read attribute values regardless of current user rights, enable privileged mode.
// If a non-existent attribute name is passed, throws the "Object field does not exist" exception.
// 
//  
//
// Parameters:
//  Ref    - AnyRef - the object whose attribute values will be read.
//            - String      - full name of the predefined item whose attribute values will be read.
//  AttributeName       - String - a name of the attribute being received.
//                                It is allowed to specify a dot-separated attribute name, but the LanguageCode parameter for
//                                such attribute is ignored.
//  SelectAllowedItems - Boolean - If True, user rights are considered when executing the object query;
//                                If a record-level restriction is set, return Undefined;
//                                if the user has no rights to access the table, an exception is raised;
//                                if False, an exception is raised if the user has no rights to access the table
//                                or any attribute.
//  LanguageCode - String - language code for a multilanguage attribute. Default value is the main configuration language.
//
// Returns:
//  Arbitrary - if a blank reference is passed to Ref, return Undefined.
//                 If a reference to a nonexisting object (invalid reference) is passed to Ref, 
//                 return Undefined.
//
Function ObjectAttributeValue(Ref, AttributeName, SelectAllowedItems = False, Val LanguageCode = Undefined) Export
	
	If IsBlankString(AttributeName) Then 
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of the %1 parameter, function %2:
				|The attribute name cannot be empty.';"), 
			"AttributeName", "Common.ObjectAttributeValue"),
			ErrorCategory.ConfigurationError);
	EndIf;
	
	Result = ObjectAttributesValues(Ref, AttributeName, SelectAllowedItems, LanguageCode);
	Return Result[StrReplace(AttributeName, ".", "")];
	
EndFunction 

// Returns attribute values retrieved from the infobase for multiple objects.
// It is recommended that you use it instead of referring to object attributes via the point from the reference to an object
// for quick reading of separate object attributes from the database.
//
// To read attribute values regardless of current user rights, enable privileged mode.
// If a non-existent attribute name is passed, throws the "Object field does not exist" exception.
//
//  
//
// Parameters:
//  References - Array of AnyRef
//         - FixedArray of AnyRef - references to objects.
//           If the array is blank, a blank map is returned.
//  Attributes - String - the attributes names, comma-separated, in a format that meets the requirements to the structure
//                       properties. Example: "Code, Description, Parent".
//            - Array of String
//            - FixedArray of String - Attribute names formatted according to structure property requirements.
//  SelectAllowedItems - Boolean - If True, user rights are considered when executing the object query;
//                                excluding any object from the selection also excludes
//                                it from the result;
//                                if False, an exception is raised if the user has no rights to access the table
//                                or any attribute.
//  LanguageCode - String - language code for a multilanguage attribute. Default value is the main configuration language.
//
// Returns:
//  Map of KeyAndValue - List of objects and their attribute values:
//   * Key - AnyRef - object reference;
//   * Value - Structure:
//    ** Key - String - an attribute name;
//    ** Value - Arbitrary - Attribute value.
// 
Function ObjectsAttributesValues(References, Val Attributes, SelectAllowedItems = False, Val LanguageCode = Undefined) Export
	
	If TypeOf(Attributes) = Type("Array") Or TypeOf(Attributes) = Type("FixedArray") Then
		Attributes = StrConcat(Attributes, ",");
	EndIf;
	
	If IsBlankString(Attributes) Then 
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of the %1 parameter, function %2:
				|The object field must be specified.';"), 
			"Attributes", "Common.ObjectsAttributesValues"),
			ErrorCategory.ConfigurationError);
	EndIf;
	
	If StrFind(Attributes, ".") <> 0 Then 
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of the %1 parameter, function %2:
				|Dot syntax is not supported.';"), 
			"Attributes", "Common.ObjectsAttributesValues"),
			ErrorCategory.ConfigurationError);
	EndIf;
	
	AttributesValues = New Map;
	If References.Count() = 0 Then
		Return AttributesValues;
	EndIf;
	
	If ValueIsFilled(LanguageCode) Then
		LanguageCode = StrSplit(LanguageCode, "_", True)[0];
	EndIf;
	
	AttributesQueryText = Attributes;
	
	If SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = CommonModule("NationalLanguageSupportServer");
		If ValueIsFilled(LanguageCode) Then
			LanguageSuffix = ModuleNationalLanguageSupportServer.LanguageSuffix(LanguageCode);
			If ValueIsFilled(LanguageSuffix) Then
				MultilingualAttributes = ModuleNationalLanguageSupportServer.MultilingualObjectAttributes(References[0]);
				AttributesSet = StrSplit(Attributes, ",");
				For Position = 0 To AttributesSet.UBound() Do
					AttributeName = TrimAll(AttributesSet[Position]);
					If MultilingualAttributes[AttributeName] <> Undefined Then
						NameWithSuffix = AttributeName + LanguageSuffix;
						AttributesSet[Position] = NameWithSuffix + " AS " + AttributeName;
					EndIf;
				EndDo;
				AttributesQueryText = StrConcat(AttributesSet, ",");
			EndIf;
		EndIf;
	EndIf;
	
	RefsByTypes = New Map;
	For Each Ref In References Do
		Type = TypeOf(Ref);
		If RefsByTypes[Type] = Undefined Then
			RefsByTypes[Type] = New Array;
		EndIf;
		ItemByType = RefsByTypes[Type]; // Array
		ItemByType.Add(Ref);
	EndDo;
	
	QueriesTexts = New Array;
	QueryOptions = New Structure;
	
	MetadataObjectNames = New Array;
	
	For Each RefsByType In RefsByTypes Do
		Type = RefsByType.Key;
		MetadataObject = Metadata.FindByType(Type);
		If MetadataObject = Undefined Then
			Raise(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invalid value of the %1 parameter, function %2:
					|The array values must be references.';"), 
				"References", "Common.ObjectsAttributesValues"),
				ErrorCategory.ConfigurationError);
		EndIf;
		
		FullMetadataObjectName = MetadataObject.FullName();
		MetadataObjectNames.Add(FullMetadataObjectName);
		
		QueryText =
			"SELECT ALLOWED
			|	Ref,
			|	&Attributes
			|FROM
			|	&FullMetadataObjectName AS SpecifiedTableAlias
			|WHERE
			|	SpecifiedTableAlias.Ref IN (&References)";
		If Not SelectAllowedItems Or QueriesTexts.Count() > 0 Then
			QueryText = StrReplace(QueryText, "ALLOWED", ""); // @Query-part-1
		EndIf;
		QueryText = StrReplace(QueryText, "&Attributes", AttributesQueryText);
		QueryText = StrReplace(QueryText, "&FullMetadataObjectName", FullMetadataObjectName);
		ParameterName = "References" + StrReplace(FullMetadataObjectName, ".", "");
		QueryText = StrReplace(QueryText, "&References", "&" + ParameterName); // @Query-part-1
		QueryOptions.Insert(ParameterName, RefsByType.Value);
		
		If SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			ModuleNationalLanguageSupportServer  = CommonModule("NationalLanguageSupportServer");
			
			If ValueIsFilled(LanguageCode) And LanguageCode <> DefaultLanguageCode()
				And ModuleNationalLanguageSupportServer.ObjectContainsPMRepresentations(FullMetadataObjectName) Then
				
				MultilingualAttributes = ModuleNationalLanguageSupportServer.MultilingualObjectAttributes(MetadataObject);
				TablesFields = New Array;
				TablesFields.Add("SpecifiedTableAlias.Ref");
				For Each Attribute In StrSplit(Attributes, ",") Do
					If MultilingualAttributes[Attribute] <> Undefined Then
						
						If MultilingualAttributes[Attribute] = True Then
							AttributeField = "ISNULL(PresentationTable." + Attribute + ", """")";
						Else
							LanguageSuffix = ModuleNationalLanguageSupportServer.LanguageSuffix(LanguageCode);
							AttributeField = ?(ValueIsFilled(LanguageSuffix), Attribute + LanguageSuffix, Attribute);
						EndIf;
						
						TablesFields.Add(StringFunctionsClientServer.SubstituteParametersToString("%1 AS %2",
							AttributeField, Attribute));
					Else
						TablesFields.Add(Attribute);
					EndIf;
					
				EndDo;
				
				TablesFields = StrConcat(TablesFields, "," + Chars.LF);
				
				Tables = FullMetadataObjectName + " " + "AS SpecifiedTableAlias" + Chars.LF
					+ "LEFT JOIN" + " " + FullMetadataObjectName + ".Presentations AS PresentationTable" + Chars.LF
					+ "On PresentationTable.Ref = SpecifiedTableAlias.Ref AND PresentationTable.LanguageCode = &LanguageCode";
					
				ParameterName = "References" + StrReplace(FullMetadataObjectName, ".", "");
				Conditions = "SpecifiedTableAlias.Ref IN (&" + ParameterName + ")";
				
				QueryStrings = New Array;
				QueryStrings.Add("SELECT" + ?(SelectAllowedItems And Not ValueIsFilled(QueriesTexts), " " + "ALLOWED", "")); // @Query-part-1, @Query-part-3
				QueryStrings.Add(TablesFields);
				QueryStrings.Add("FROM"); // @Query-part-1
				QueryStrings.Add(Tables);
				QueryStrings.Add("WHERE"); // @Query-part-1
				QueryStrings.Add(Conditions);
				
				QueryText = StrConcat(QueryStrings, Chars.LF);
			EndIf;
		EndIf;
		
		QueriesTexts.Add(QueryText);
	EndDo;
	
	QueryText = StrConcat(QueriesTexts, Chars.LF + "UNION ALL" + Chars.LF);
	
	Query = New Query(QueryText);
	Query.SetParameter("LanguageCode", LanguageCode);
	For Each Parameter In QueryOptions Do
		Query.SetParameter(Parameter.Key, Parameter.Value);
	EndDo;
	
	Try
		Selection = Query.Execute().Select();
	Except
		
		// Trim whitespaces.
		Attributes = StrReplace(Attributes, " ", "");
		// Converting the parameter to a field array.
		Attributes = StrSplit(Attributes, ",");
		
		// Searching for field availability error.
		ErrorList = New Array;
		For Each FullMetadataObjectName In MetadataObjectNames Do
			Result = CheckIfObjectAttributesExist(FullMetadataObjectName, Attributes);
			If Result.Error Then 
				ErrorList.Add(Result.ErrorDescription);
			EndIf;
		EndDo;
		
		If ValueIsFilled(ErrorList) Then
			Raise(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invalid value of the %1 parameter, function %2: %3';"), 
				"Attributes", "Common.ObjectsAttributesValues", 
				StrConcat(ErrorList, Chars.LF)),
				ErrorCategory.ConfigurationError);
		EndIf;
		
		Raise;
		
	EndTry;
	
	While Selection.Next() Do
		Result = New Structure(Attributes);
		FillPropertyValues(Result, Selection);
		AttributesValues[Selection.Ref] = Result;
		
	EndDo;
	
	Return AttributesValues;
	
EndFunction

// Returns attribute values retrieved from the infobase for multiple objects.
// It is recommended that you use it instead of referring to object attributes via the point from the reference to an object
// for quick reading of separate object attributes from the database.
//
// To read attribute values regardless of current user rights, enable privileged mode.
// If a non-existent attribute name is passed, throws the "Object field does not exist" exception.
// 
//  
//
// Parameters:
//  ReferencesArrray       - Array of AnyRef
//                     - FixedArray of AnyRef
//  AttributeName       - String - for example, "Code".
//  SelectAllowedItems - Boolean - If True, user rights are considered when executing the object query;
//                                excluding any object from the selection also excludes
//                                it from the result;
//                                if False, an exception is raised if the user has no rights to access the table
//                                or any attribute.
//  LanguageCode - String - language code for a multilanguage attribute. Default value is the main configuration language.
//
// Returns:
//  Map of KeyAndValue:
//      * Key     - AnyRef  - reference to object,
//      * Value - Arbitrary - the read attribute value.
// 
Function ObjectsAttributeValue(ReferencesArrray, AttributeName, SelectAllowedItems = False, Val LanguageCode = Undefined) Export
	
	If IsBlankString(AttributeName) Then 
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of the %1 parameter, function %2:
			|The attribute name cannot be empty.';"), 
			"AttributeName", "Common.ObjectsAttributeValue"),
			ErrorCategory.ConfigurationError);
	EndIf;
	
	AttributesValues = ObjectsAttributesValues(ReferencesArrray, AttributeName, SelectAllowedItems, LanguageCode);
	For Each Item In AttributesValues Do
		AttributesValues[Item.Key] = Item.Value[AttributeName];
	EndDo;
		
	Return AttributesValues;
	
EndFunction

// Edits an attribute value or adds it to an object.
//
// If a non-existent attribute is passed, throws an exception. 
//
// Parameters:
//  Object - CatalogObject
//         - DocumentObject
//         - ChartOfCharacteristicTypesObject
//         - InformationRegisterRecord - Object to populate.
//  AttributeName - String - name of the attribute to fill in. For example, "Comment"
//  Value - String - the value to place in the attribute.
//  LanguageCode - String - attribute language code. For example, "en".
//
Procedure SetAttributeValue(Object, AttributeName, Value, LanguageCode = Undefined) Export
	SetAttributesValues(Object, New Structure(AttributeName, Value), LanguageCode);
EndProcedure

// Edits attribute values or adds it to an object.
//
// If a non-existent attribute is passed, throws an exception. 
//
// Parameters:
//  Object - CatalogObject
//         - DocumentObject
//         - ChartOfCharacteristicTypesObject
//         - InformationRegisterRecord - Object to populate.
//  Values - Structure - where the key is the attribute name, and the value contains the string placed in the attribute.
//  LanguageCode - String - attribute language code. For example, "en".
//
Procedure SetAttributesValues(Object, Values, LanguageCode = Undefined) Export
	
	If SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.SetAttributesValues(Object, Values, LanguageCode);
		Return;
	EndIf;
	
	For Each AttributeValue In Values Do
		Value = AttributeValue.Value;
		If TypeOf(Value) = Type("String") And StringAsNstr(Value) Then
			Value = NStr(AttributeValue.Value);
		EndIf;
		Object[AttributeValue.Key] = Value;
	EndDo;
	
EndProcedure

// Returns the code of the default infobase language, for example, "en".
// On which auto-generated rows are programmatically written in the infobase.
// For example, when initially filling the infobase with template data, generating a posting comment automatically,
// or determining the value of the EventName parameter of the EventLogRecord method.
//
// Returns:
//  String
//
Function DefaultLanguageCode() Export
	
	If SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = CommonModule("NationalLanguageSupportServer");
		Return ModuleNationalLanguageSupportServer.DefaultLanguageCode();
	EndIf;
	
	Return Metadata.DefaultLanguage.LanguageCode;
	
EndFunction

// Returns a flag indicating whether the interface language
// corresponding to the main language of the infobase is set for the user.
//
// Returns:
//  Boolean
//
Function IsMainLanguage() Export
	
	Return StrCompare(DefaultLanguageCode(), CurrentLanguage().LanguageCode) = 0;
	
EndFunction

// Returns a reference to the predefined item by its full name.
// Only the following objects can contain predefined objects:
//   - catalogs;
//   - charts of characteristic types;
//   - charts of accounts;
//   - charts of calculation types.
// After changing the list of predefined items, it is recommended that you run
// the UpdateCachedValues() method to clear the cache for Cached modules in the current session.
//
// Parameters:
//   FullPredefinedItemName - String - full path to the predefined item including the name.
//     The format is identical to the PredefinedValue() global context function.
//     Example:
//       "Catalog.ContactInformationKinds.UserEmail"
//       "ChartOfAccounts.SelfFinancing.Materials"
//       "ChartOfCalculationTypes.Accruals.SalaryPayments".
//
// Returns: 
//   AnyRef - reference to the predefined item.
//   Undefined - if the predefined item exists in metadata but not in the infobase.
//
Function PredefinedItem(FullPredefinedItemName) Export
	
	StandardProcessing = CommonInternalClientServer.UseStandardGettingPredefinedItemFunction(
		FullPredefinedItemName);
	
	If StandardProcessing Then 
		Return PredefinedValue(FullPredefinedItemName);
	EndIf;
	
	PredefinedItemFields = CommonInternalClientServer.PredefinedItemNameByFields(FullPredefinedItemName);
	
	PredefinedValues = StandardSubsystemsCached.RefsByPredefinedItemsNames(
		PredefinedItemFields.FullMetadataObjectName);
	
	Return CommonInternalClientServer.PredefinedItem(
		FullPredefinedItemName, PredefinedItemFields, PredefinedValues);
	
EndFunction

// Returns flags identifying whether the passed items are predefined or not.
// If the user does not have record-level rights to the item, it is excluded from the result.
// If the user has no right to the table, an exception is thrown.
// 
// Parameters:
//  Items - Array of AnyRef
//
// Returns:
//  Map of KeyAndValue - List of objects and their attribute values:
//   * Key - AnyRef - a reference to an object.
//   * Value - Boolean - True if it is a reference to a predefined item.
//
Function ArePredefinedItems(Val Items) Export
	
	AttributesNames = New Array;
	For Each AttributeName In StandardSubsystemsServer.PredefinedDataAttributes() Do
		AttributesNames.Add(AttributeName.Key);
	EndDo;
	
	AttributesValues = StandardSubsystemsServer.ObjectAttributeValuesIfExist(Items, AttributesNames);
	Result = New Map;
	For Each Item In AttributesValues Do
		ThisIsAPredefinedItem = False;
		For Each Value In Item.Value Do
			If ValueIsFilled(Value.Value) Then
				ThisIsAPredefinedItem = True;
			EndIf;
		EndDo;
		Result[Item.Key] = ThisIsAPredefinedItem;
	EndDo;
	Return Result;	
	
EndFunction

// Checks posting status of the passed documents and returns
// the unposted documents.
//
// Parameters:
//  Var_Documents - Array of DocumentRef - documents to check.
//
// Returns:
//  Array of DocumentRef - unposted documents.
//
Function CheckDocumentsPosting(Val Var_Documents) Export
	
	Result = New Array;
	
	QueryTemplate = 	
		"SELECT
		|	SpecifiedTableAlias.Ref AS Ref
		|FROM
		|	&DocumentName AS SpecifiedTableAlias
		|WHERE
		|	SpecifiedTableAlias.Ref IN(&DocumentsArray)
		|	AND NOT SpecifiedTableAlias.Posted";
	
	UnionAllText = UnionAllText();
	
	DocumentNames = New Array;
	For Each Document In Var_Documents Do
		MetadataOfDocument = Document.Metadata();
		If DocumentNames.Find(MetadataOfDocument.FullName()) = Undefined
			And Metadata.Documents.Contains(MetadataOfDocument)
			And MetadataOfDocument.Posting = Metadata.ObjectProperties.Posting.Allow Then
				DocumentNames.Add(MetadataOfDocument.FullName());
		EndIf;
	EndDo;
	
	QueryText = "";
	For Each DocumentName In DocumentNames Do
		If Not IsBlankString(QueryText) Then
			QueryText = QueryText + UnionAllText;
		EndIf;
		SubqueryText = StrReplace(QueryTemplate, "&DocumentName", DocumentName);
		QueryText = QueryText + SubqueryText;
	EndDo;
		
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("DocumentsArray", Var_Documents);
	
	If Not IsBlankString(QueryText) Then
		Result = Query.Execute().Unload().UnloadColumn("Ref");
	EndIf;
	
	Return Result;
	
EndFunction

// Attempts to post the documents.
//
// Parameters:
//  Var_Documents - Array of DocumentRef - documents to post.
//
// Returns:
//  Array of Structure:
//   * Ref         - DocumentRef - document that could not be posted,
//   * ErrorDescription - String         - the text of a posting error.
//
Function PostDocuments(Var_Documents) Export
	
	UnpostedDocuments = New Array;
	
	For Each DocumentRef In Var_Documents Do
		
		ExecutedSuccessfully = False;
		DocumentObject = DocumentRef.GetObject();
		If DocumentObject.CheckFilling() Then
			PostingMode = DocumentPostingMode.Regular;
			If DocumentObject.Date >= BegOfDay(CurrentSessionDate())
				And DocumentRef.Metadata().RealTimePosting = Metadata.ObjectProperties.RealTimePosting.Allow Then
					PostingMode = DocumentPostingMode.RealTime;
			EndIf;
			Try
				DocumentObject.Write(DocumentWriteMode.Posting, PostingMode);
				ExecutedSuccessfully = True;
			Except
				ErrorPresentation = ErrorProcessing.BriefErrorDescription(ErrorInfo());
			EndTry;
		Else
			ErrorPresentation = NStr("en = 'Document fields cannot be empty.';");
		EndIf;
		
		If Not ExecutedSuccessfully Then
			UnpostedDocuments.Add(New Structure("Ref,ErrorDescription", DocumentRef, ErrorPresentation));
		EndIf;
		
	EndDo;
	
	Return UnpostedDocuments;
	
EndFunction 

// Checks whether there are references to the object in the infobase.
// When called in a shared session, does not find references in separated areas.
//
// Parameters:
//  RefOrRefArray - AnyRef
//                        - Array of AnyRef - an object or a list of objects.
//  SearchInInternalObjects - Boolean - If True, ignore the default reference search exceptions.
//      For more details about reference search exceptions, see CommonOverridable.OnAddRefsSearchExceptions.
//      
//      
//
// Returns:
//  Boolean - True if any references to the object are found.
//
Function RefsToObjectFound(Val RefOrRefArray, Val SearchInInternalObjects = False) Export
	
	If TypeOf(RefOrRefArray) = Type("Array") Then
		ReferencesArrray = RefOrRefArray;
	Else
		ReferencesArrray = CommonClientServer.ValueInArray(RefOrRefArray);
	EndIf;
	
	SetPrivilegedMode(True);
	UsageInstances = FindByRef(ReferencesArrray);
	SetPrivilegedMode(False);
	
	If Not SearchInInternalObjects Then
		For Each Item In InternalDataLinks(UsageInstances) Do
			UsageInstances.Delete(Item.Key);
		EndDo;
	EndIf;
	
	Return UsageInstances.Count() > 0;
	
EndFunction

// Determines whether use instances are specified in the search exceptions.
//
// Parameters:
//  UsageInstances		 - ValueTable - Outcome of the FindByRef function:
//   *  Ref - AnyRef - the reference to check.
//   *  Data - AnyRef - usage instance.
//   *  Metadata - MetadataObject - usage instance metadata.
//  RefSearchExclusions	 - See RefSearchExclusions
//   
// Returns:
//   Map of KeyAndValue:
//     * Key - ValueTableRow
//     * Value - Boolean - Always True. If this is not an internal data link, the map doesn't contain this item.
//
Function InternalDataLinks(Val UsageInstances, Val RefSearchExclusions = Undefined) Export
	
	If RefSearchExclusions = Undefined Then
		RefSearchExclusions = RefSearchExclusions();
	EndIf;

	Result = New Map;
	UsageInstanceByMetadata = New Map;
	
	For Each UsageInstance1 In UsageInstances Do
		SearchException = RefSearchExclusions[UsageInstance1.Metadata];
		
		// Data can be either a reference or a register record key.
		If SearchException = Undefined Then
			If UsageInstance1.Ref = UsageInstance1.Data Then
				Result[UsageInstance1] = True; // Excluding self-reference.
			EndIf;
			Continue;
		ElsIf SearchException = "*" Then
			Result[UsageInstance1] = True; // Excluding everything.
			Continue;
		EndIf;
	
		IsReference = IsReference(TypeOf(UsageInstance1.Data));
		If Not IsReference Then 
			For Each AttributePath1 In SearchException Do
				AttributeValue = New Structure(AttributePath1);
				FillPropertyValues(AttributeValue, UsageInstance1.Data);
				If AttributeValue[AttributePath1] = UsageInstance1.Ref Then 
					Result[UsageInstance1] = True;
					Break;
				EndIf;
			EndDo;
			Continue;
		EndIf;

		If SearchException.Count() = 0 Then
			Continue;
		EndIf;
		
		TableName = UsageInstance1.Metadata.FullName();
		Value = UsageInstanceByMetadata[TableName];
		If Value = Undefined Then
			Value = New ValueTable;
			Value.Columns.Add("Ref", AllRefsTypeDetails());
			Value.Columns.Add("Data", AllRefsTypeDetails());
			Value.Columns.Add("Metadata");
			UsageInstanceByMetadata[TableName] = Value;
		EndIf;
		FillPropertyValues(Value.Add(), UsageInstance1);

	EndDo;
	
	IndexOf = 1;
	Query = New Query;
	QueryTexts = New Array;
	TemporaryTable = New Array;
	
	For Each UsageInstance1 In UsageInstanceByMetadata Do
		 
		TableName = UsageInstance1.Key; // String
		UsageInstance1 = UsageInstance1.Value; // ValueTable

		// Check whether the excluded path from the given data contains the reference to be checked.
		If UsageInstance1.Count() > 1 Then
			QueryTemplate = 
				"SELECT
				|	References.Data AS Ref,
				|	References.Ref AS RefToCheck
				|INTO TTRefTable
				|FROM
				|	&References AS References
				|;
				|
				|SELECT
				|	RefsTable.Ref AS Ref,
				|	RefsTable.RefToCheck AS RefToCheck
				|FROM
				|	TTRefTable AS RefsTable
				|		LEFT JOIN #FullMetadataObjectName AS Table
				|		ON RefsTable.Ref = Table.Ref
				|WHERE
				|	&Condition";

			QueryText = StrReplace(QueryTemplate, "#FullMetadataObjectName", TableName);
			QueryText = StrReplace(QueryText, "TTRefTable", "TTRefTable" + Format(IndexOf, "NG=;NZ="));

			ParameterName = "References" + Format(IndexOf, "NG=;NZ=");
			QueryText = StrReplace(QueryText, "&References", "&" + ParameterName);
			Query.SetParameter(ParameterName, UsageInstance1);
			
			QueryParts = StrSplit(QueryText, ";");
			TemporaryTable.Add(QueryParts[0]);
			QueryText = QueryParts[1];

		Else
			QueryTemplate = 
				"SELECT
				|	&OwnerReference AS Ref,
				|	&RefToCheck AS RefToCheck
				|FROM
				|	#FullMetadataObjectName AS Table
				|WHERE
				|	Table.Ref = &OwnerReference
				|	AND (&Condition)";

			QueryText = StrReplace(QueryTemplate, "#FullMetadataObjectName", TableName);

			ParameterName = "OwnerReference" + Format(IndexOf, "NG=;NZ=");
			QueryText = StrReplace(QueryText, "&OwnerReference", "&" + ParameterName);
			Query.SetParameter(ParameterName, UsageInstance1[0].Data);

			ParameterName = "RefToCheck" + Format(IndexOf, "NG=;NZ=");
			QueryText = StrReplace(QueryText, "&RefToCheck", "&" + ParameterName);
			Query.SetParameter(ParameterName, UsageInstance1[0].Ref);

		EndIf;

		ConditionText = New Array;
		// Attribute's relative path: "<NameOfTableOrAttribute>[.<TableAttributeName>]".
		For Each AttributePath1 In RefSearchExclusions[UsageInstance1[0].Metadata] Do
			ConditionText.Add(AttributePath1 + " = " 
				+ ?(UsageInstance1.Count() > 1, "RefsTable.RefToCheck", "&" + ParameterName));
		EndDo;
		QueryText = StrReplace(QueryText, "&Condition", StrConcat(ConditionText, " OR "));
		
		QueryTexts.Add(QueryText);
		IndexOf = IndexOf + 1;
		
	EndDo;
	
	If QueryTexts.Count() = 0 Then
		Return Result;
	EndIf;
	
	Query.Text = StrConcat(TemporaryTable, ";" + Chars.LF)
		+ ?(TemporaryTable.Count() > 0, ";" + Chars.LF, "") 
		+ StrConcat(QueryTexts, Chars.LF + "UNION" + Chars.LF);
	SetPrivilegedMode(True);
	QuerySelection = Query.Execute().Select();
	SetPrivilegedMode(False);
	
	UsageInstances.Indexes.Add("Ref,Data");
	While QuerySelection.Next() Do
		InternalDataLinks = UsageInstances.FindRows(New Structure("Ref,Data", 
			QuerySelection.RefToCheck, QuerySelection.Ref));
		For Each InternalDataLink In InternalDataLinks Do
			Result[InternalDataLink] = True;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

// Determines whether a use instance is specified in the search exceptions.
//
// Parameters:
//  UsageInstance1		 - Structure:
//   *  Ref - AnyRef - the reference to check.
//   *  Data - AnyRef - usage instance.
//   *  Metadata - MetadataObject - usage instance metadata.
//  RefSearchExclusions	 - See RefSearchExclusions
// 
// Returns:
//   Boolean
//
Function IsInternalDataLink(Val UsageInstance1, Val RefSearchExclusions = Undefined) Export
	
	If RefSearchExclusions = Undefined Then
		RefSearchExclusions = RefSearchExclusions();
	EndIf;

	Value = New ValueTable;
	Value.Columns.Add("Ref", AllRefsTypeDetails());
	Value.Columns.Add("Data", AllRefsTypeDetails());
	Value.Columns.Add("Metadata");
	UsageInstanceRow = Value.Add();
	FillPropertyValues(UsageInstanceRow, UsageInstance1);
	
	Result = InternalDataLinks(Value, RefSearchExclusions);
	Return Result[UsageInstanceRow] <> Undefined;

EndFunction

// Replaces references in all data. There is an option to delete all unused references after the replacement.
// References are replaced in transactions by the object to be changed and its relations but not by the reference being analyzed.
// When called in the shared session, it does not find references in separated areas.
// If the links of subordinate and main objects are described (see SubordinateObjectsLinks):
// 	* Subordinate object replacements will be searched for upon the main object replacement.
//	* An attempt to search for replacements for subordinate objects by link field values 
//		will be made (if RunAutoReplacementSearch = True). If the object does not exist, the OnSearchForReferenceReplacement procedure will be executed. 
// 	* SearchMethod will be called to select replacements (if SearchMethod is specified in the link description
//		and if the auto search did not find replacements or was not executed).
//
// Parameters:
//   ReplacementPairs - Map of KeyAndValue:
//       * Key     - AnyRef - a reference to be replaced.
//       * Value - AnyRef - a reference to use as a replacement.
//       Self-references and empty search references are ignored.
//   
//   ReplacementParameters - See Common.RefsReplacementParameters
//
// Returns:
//   ValueTable - Failed replacements (errors):
//       * Ref - AnyRef - a reference that was replaced.
//       * ErrorObject - Arbitrary - an object that has caused an error.
//       * ErrorObjectPresentation - String - string representation of an error object.
//       * ErrorType - String - An error type. Valid values are::
//           LockError - The object is locked by another user.
//           DataChanged - Another user is modifying the object data.
//           WritingError - Failed to write the object, or the "CanReplaceItems" method returned a failure.
//           DeletionError - Failed to delete the object.
//           UnknownData - Data that was not intended for replacement is found.
//       * ErrorInfo - ErrorInfo
//       * ErrorText - String - Contains the error cause if "ErrorInfo" is set to "Undefined".
//
Function ReplaceReferences(Val ReplacementPairs, Val ReplacementParameters = Undefined) Export
	
	Statistics = New Map;
	StringType = New TypeDescription("String");
	
	ReplacementErrors = New ValueTable;
	ReplacementErrors.Columns.Add("Ref");
	ReplacementErrors.Columns.Add("ErrorObject");
	ReplacementErrors.Columns.Add("ErrorObjectPresentation", StringType);
	ReplacementErrors.Columns.Add("ErrorType", StringType);
	ReplacementErrors.Columns.Add("ErrorText", StringType);
	ReplacementErrors.Columns.Add("ErrorInfo");
	
	ReplacementErrors.Indexes.Add("Ref");
	ReplacementErrors.Indexes.Add("Ref, ErrorObject, ErrorType");
	
	Result = TheResultOfReplacingLinks(ReplacementErrors);
	
	ExecutionParameters = NewReferenceReplacementExecutionParameters(ReplacementParameters);
	
	UsageInstancesSearchParameters = UsageInstancesSearchParameters();
	SupplementSubordinateObjectsRefSearchExceptions(UsageInstancesSearchParameters.AdditionalRefSearchExceptions);
	ExecutionParameters.Insert("UsageInstancesSearchParameters", UsageInstancesSearchParameters);
	
	SSLSubsystemsIntegration.BeforeSearchForUsageInstances(ReplacementPairs, ExecutionParameters);
	
	If ReplacementPairs.Count() = 0 Then
		Return Result.Errors;
	EndIf;
	
	Duplicates = GenerateDuplicates(ExecutionParameters, ReplacementParameters, ReplacementPairs, Result);	
	SearchTable = UsageInstances(Duplicates,, ExecutionParameters.UsageInstancesSearchParameters);
	
	// For each object reference, make replacements in "Constant", "Object", and "Set" (in this order).
	// An empty row in this column signifies that replacement is not required or has been made.
	SearchTable.Columns.Add("ReplacementKey", StringType);
	SearchTable.Indexes.Add("Ref, ReplacementKey");
	SearchTable.Indexes.Add("Data, ReplacementKey");
	
	// Auxiliary data.
	SearchTable.Columns.Add("DestinationRef");
	SearchTable.Columns.Add("Processed", New TypeDescription("Boolean"));
	
	// Defining the processing order and validating items that can be processed.
	MarkupErrors = New Array;
	ObjectsWithErrors = New Array;
	Count = Duplicates.Count();
	For Number = 1 To Count Do
		ReverseIndex = Count - Number;
		Duplicate1 = Duplicates[ReverseIndex];
		MarkupResult = MarkUsageInstances(ExecutionParameters, Duplicate1, ReplacementPairs[Duplicate1], SearchTable);
		If Not MarkupResult.Success Then
			Duplicates.Delete(ReverseIndex);
			For Each Error In MarkupResult.MarkupErrors Do
				Error.Insert("Duplicate1", Duplicate1);
				ObjectsWithErrors.Add(Error.Object);
			EndDo;
			CommonClientServer.SupplementArray(MarkupErrors, MarkupResult.MarkupErrors);
		EndIf;
	EndDo;
			
	If MarkupErrors.Count() > 0 Then
		ObjectsPresentations = SubjectAsString(ObjectsWithErrors);
		For Each Error In MarkupErrors Do
			RegisterReplacementError(Result, Error.Duplicate1,
				ReplacementErrorDescription("UnknownData", Error.Object, ObjectsPresentations[Error.Object], 
					Error.Text));
		EndDo;
	EndIf;
	
	// Searching for and replacing the found duplicates.
	ExecutionParameters.Insert("ReplacementPairs",      ReplacementPairs);
	ExecutionParameters.Insert("SuccessfulReplacements", New Map);
	
	DisableAccessKeysUpdate(True);
	
	Try
		
		DuplicateCount = Duplicates.Count();
		Number = 1;
		For Each Duplicate1 In Duplicates Do
			
			HadErrors = Result.HasErrors;
			Result.HasErrors = False;
			
			// @skip-check query-in-loop - Batch processing of a large amount of data.
			ReplaceRefsUsingShortTransactions(Result, ExecutionParameters, Duplicate1, SearchTable);
					
			If Not Result.HasErrors Then
				ExecutionParameters.SuccessfulReplacements.Insert(Duplicate1, ExecutionParameters.ReplacementPairs[Duplicate1]);	
			EndIf;
			Result.HasErrors = Result.HasErrors Or HadErrors;
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("SessionNumber", InfoBaseSessionNumber());
			AdditionalParameters.Insert("ProcessedItemsCount", Number);
			TimeConsumingOperations.ReportProgress(Number,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Replacing duplicates… processed (%1 of %2)';"), 
					Number, DuplicateCount), AdditionalParameters);
			Number = Number + 1;
			AddToReferenceReplacementStatistics(Statistics, Duplicate1, Result.HasErrors);
			
		EndDo;
		
		CommonOverridable.AfterReplaceRefs(Result, ExecutionParameters, SearchTable);
	
		DisableAccessKeysUpdate(False);
		
	Except
		DisableAccessKeysUpdate(False);
		Raise;
	EndTry;
	
	If SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") 
		And ExecutionParameters.ShouldDeleteDirectly Then
		
		ModuleMarkedObjectsDeletion = CommonModule("MarkedObjectsDeletion");
		
		TimeConsumingOperations.ReportProgress(0, NStr("en = 'Deleting duplicates…';"));
		DeletionResult = ModuleMarkedObjectsDeletion.ToDeleteMarkedObjects(Result.QueueForDirectDeletion);
		RegisterDeletionErrors(Result, DeletionResult.ObjectsPreventingDeletion);
		
	EndIf;
	
	SendReferenceReplacementStatistics(Statistics);
	
	Return Result.Errors;
	
EndFunction

// Structure constructor for the ReplacementParameters parameter  of the Common.ReplaceRefs function.
// 
// Returns:
//   Structure:
//     * DeletionMethod - String - shows what to do with the duplicate after a successful replacement:
//         ""                - do not do anything (by default);
//         "Mark"         - mark for deletion;
//         "Directly" - delete directly.
//     * TakeAppliedRulesIntoAccount - Boolean - If True, for the each duplicate-original pair 
//         the CanReplaceItems function of the manager module is called 
//         (the "Duplicate object detection" subsystem is required). The default value is False.
//     * IncludeBusinessLogic - Boolean - recording mode of objects when replacing duplicate references to originals.
//         If True (by default), the places of duplicate usage are recorded in the normal mode,
//         otherwise they are recorded in mode DataExchange.Import = True.
//     * ReplacePairsInTransaction - Boolean - obsolete. determines transaction size when replacing duplicates.
//         If True (default), all usage locations of one duplicate are replaced in one transaction. 
//         It can be very resource-demanding in case of a large number of usage locations.
//         If False, the replacement at usage location is performed in a separate transaction.
//     * WriteInPrivilegedMode - Boolean - If True, set privileged mode before recording
//         objects when replacing duplicate references in them to originals. Default value is False.
//
Function RefsReplacementParameters() Export
	Result = New Structure;
	Result.Insert("DeletionMethod", "");
	Result.Insert("TakeAppliedRulesIntoAccount", False);
	Result.Insert("IncludeBusinessLogic", True);
	Result.Insert("ReplacePairsInTransaction", False);
	Result.Insert("WriteInPrivilegedMode", False);
	Return Result;
EndFunction

// Retrieves all places where references are used.
// If any of the references is not used, it will not be presented in the result table.
// When called in a shared session, does not find references in separated areas.
//
// Parameters:
//     RefSet     - Array of AnyRef - references whose usage instances are to be found.
//     ResultAddress - String - Address in the temporary storage where the replacement result copy will be stored.
//     AdditionalParameters - See Common.UsageInstancesSearchParameters 
// 
// Returns:
//     ValueTable:
//       * Ref - AnyRef - the reference to analyze.
//       * Data - Arbitrary - the data that contains the reference to analyze.
//       * Metadata - MetadataObject - metadata for the found data.
//       * DataPresentation - String - presentation of the data containing the reference.
//       * RefType - Type - the type of reference to analyze.
//       * AuxiliaryData - Boolean - True if the data is used by the reference as
//           auxiliary data (leading dimension, or covered by the OnAddReferenceSearchExceptions exception).
//       * IsInternalData - Boolean - the data is covered by the OnAddReferenceSearchExceptions exception
//
Function UsageInstances(Val RefSet, Val ResultAddress = "", AdditionalParameters = Undefined) Export
	
	UsageInstances = New ValueTable;
	
	SetPrivilegedMode(True);
	UsageInstances = FindByRef(RefSet); // See UsageInstances.
	SetPrivilegedMode(False);
	
	// UsageInstances - ValueTable - A table where:
	// * Ref - AnyRef - The reference being analyzed.
	// * Data - Arbitrary - Data containing the reference.
	// * Metadata - MetadataObject - Metadata object of the data.
	
	UsageInstances.Columns.Add("DataPresentation", New TypeDescription("String"));
	UsageInstances.Columns.Add("RefType");
	UsageInstances.Columns.Add("UsageInstanceInfo");
	UsageInstances.Columns.Add("AuxiliaryData", New TypeDescription("Boolean"));
	UsageInstances.Columns.Add("IsInternalData", New TypeDescription("Boolean"));
	
	UsageInstances.Indexes.Add("Ref");
	UsageInstances.Indexes.Add("Data");
	UsageInstances.Indexes.Add("AuxiliaryData");
	UsageInstances.Indexes.Add("Ref, AuxiliaryData");
	
	RecordKeysType = RecordKeysTypeDetails();
	AllRefsType = AllRefsTypeDetails();
	
	SequenceMetadata = Metadata.Sequences;
	ConstantMetadata = Metadata.Constants;
	MetadataOfDocuments = Metadata.Documents;
	
	RefSearchExclusions = RefSearchExclusions();
	
	AdditionalRefSearchExceptions = CommonClientServer.StructureProperty(
		AdditionalParameters, "AdditionalRefSearchExceptions", New Map);
	For Each MetadataExceptionAttributes In AdditionalRefSearchExceptions Do
		ExceptionValue = RefSearchExclusions[MetadataExceptionAttributes.Key];
		If ExceptionValue = Undefined Then
			RefSearchExclusions.Insert(MetadataExceptionAttributes.Key, MetadataExceptionAttributes.Value);
		ElsIf TypeOf(ExceptionValue) = Type("Array") Then
			CommonClientServer.SupplementArray(ExceptionValue, MetadataExceptionAttributes.Value);
		EndIf;
	EndDo;
	
	CancelRefsSearchExceptions = CommonClientServer.StructureProperty(AdditionalParameters,
		"CancelRefsSearchExceptions", New Array);
	For Each CancelException In CancelRefsSearchExceptions Do
		RefSearchExclusions.Delete(CancelException);	
	EndDo;
	
	InternalDataLinks = InternalDataLinks(UsageInstances, RefSearchExclusions);
	RegisterDimensionCache = New Map;
	
	For Each UsageInstance1 In UsageInstances Do
		DataType = TypeOf(UsageInstance1.Data);
		
		IsInternalData = InternalDataLinks[UsageInstance1] <> Undefined;
		IsAuxiliaryData = IsInternalData;
		
		If DataType = Undefined Or MetadataOfDocuments.Contains(UsageInstance1.Metadata) Then
			Presentation = String(UsageInstance1.Data);
			
		ElsIf ConstantMetadata.Contains(UsageInstance1.Metadata) Then
			Presentation = UsageInstance1.Metadata.Presentation() + " (" + NStr("en = 'constant';") + ")";
			
		ElsIf SequenceMetadata.Contains(UsageInstance1.Metadata) Then
			Presentation = UsageInstance1.Metadata.Presentation() + " (" + NStr("en = 'sequence';") + ")";
			
		ElsIf AllRefsType.ContainsType(DataType) Then
			ObjectMetaPresentation = New Structure("ObjectPresentation");
			FillPropertyValues(ObjectMetaPresentation, UsageInstance1.Metadata);
			If IsBlankString(ObjectMetaPresentation.ObjectPresentation) Then
				MetaPresentation = UsageInstance1.Metadata.Presentation();
			Else
				MetaPresentation = ObjectMetaPresentation.ObjectPresentation;
			EndIf;
			Presentation = String(UsageInstance1.Data);
			If Not IsBlankString(MetaPresentation) Then
				Presentation = Presentation + " (" + MetaPresentation + ")";
			EndIf;
			
		ElsIf RecordKeysType.ContainsType(DataType) Then
			Presentation = UsageInstance1.Metadata.RecordPresentation;
			If IsBlankString(Presentation) Then
				Presentation = UsageInstance1.Metadata.Presentation();
			EndIf;
			
			DimensionsDetails = New Array;
			For Each MetadataExceptionAttributes In RecordSetDimensionsDetails(UsageInstance1.Metadata, RegisterDimensionCache) Do
				Value = UsageInstance1.Data[MetadataExceptionAttributes.Key];
				LongDesc = MetadataExceptionAttributes.Value;
				If UsageInstance1.Ref = Value Then
					If LongDesc.Master Then
						IsAuxiliaryData = True;
					EndIf;
				EndIf;
				If Not IsInternalData Then // Intended for optimization
					ValueFormat = LongDesc.Format; 
					DimensionsDetails.Add(LongDesc.Presentation + " """ 
						+ ?(ValueFormat = Undefined, String(Value), Format(Value, ValueFormat)) + """");
				EndIf;
			EndDo;
			
			If DimensionsDetails.Count() > 0 Then
				Presentation = Presentation + " (" + StrConcat(DimensionsDetails, ", ") + ")";
			EndIf;
			
		Else
			Presentation = String(UsageInstance1.Data);
		EndIf;
		
		UsageInstance1.DataPresentation = Presentation;
		UsageInstance1.AuxiliaryData = IsAuxiliaryData;
		UsageInstance1.IsInternalData = IsInternalData;
		UsageInstance1.RefType = TypeOf(UsageInstance1.Ref);
	EndDo;
	
	If Not IsBlankString(ResultAddress) Then
		PutToTempStorage(UsageInstances, ResultAddress);
	EndIf;
	
	Return UsageInstances;
EndFunction

// Returns the structure for the AdditionalParameters parameter of the Common.UsageInstances function. 
// 
// Returns:
//   Structure:
//   * AdditionalRefSearchExceptions - Map - allows you to expand the reference search exceptions
// 			See CommonOverridable.OnAddReferenceSearchExceptions
//   * CancelRefsSearchExceptions - Array of MetadataObject - completely cancels the reference search exceptions for
//                                                                 metadata objects.
//
Function UsageInstancesSearchParameters() Export

	SearchParameters = New Structure;
	SearchParameters.Insert("AdditionalRefSearchExceptions", New Map);
	SearchParameters.Insert("CancelRefsSearchExceptions", New Map);

	Return SearchParameters;

EndFunction

// Returns an exception when searching for object usage locations.
//
// Returns:
//   Map of KeyAndValue - Reference search exceptions by metadata object:
//       * Key - MetadataObject - the metadata object to apply exceptions to.
//       * Value - String
//                  - Array of String - descriptions of excluded attributes.
//           If "*", all the metadata object attributes are excluded.
//           If a string array, contains the relative names of the excluded attributes.
//
Function RefSearchExclusions() Export
	
	SearchExceptionsIntegration = New Array;
	SSLSubsystemsIntegration.OnAddReferenceSearchExceptions(SearchExceptionsIntegration);
	
	SearchExceptions = New Array;
	CommonClientServer.SupplementArray(SearchExceptions, SearchExceptionsIntegration);
	CommonOverridable.OnAddReferenceSearchExceptions(SearchExceptions);
	
	Result = New Map;
	For Each SearchException In SearchExceptions Do
		// Defining the full name of the attribute and the metadata object that owns the attribute.
		If TypeOf(SearchException) = Type("String") Then
			FullName          = SearchException;
			SubstringsArray     = StrSplit(FullName, ".");
			SubstringCount = SubstringsArray.Count();
			MetadataObject   = MetadataObjectByFullName(SubstringsArray[0] + "." + SubstringsArray[1]);
		Else
			MetadataObject   = SearchException;
			FullName          = MetadataObject.FullName();
			SubstringsArray     = StrSplit(FullName, ".");
			SubstringCount = SubstringsArray.Count();
			If SubstringCount > 2 Then
				While True Do
					Parent = MetadataObject.Parent();
					If TypeOf(Parent) = Type("ConfigurationMetadataObject") Then
						Break;
					Else
						MetadataObject = Parent;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		// Registration.
		If SubstringCount < 4 Then
			Result.Insert(MetadataObject, "*");
		Else
			PathsToAttributes = Result.Get(MetadataObject);
			If PathsToAttributes = "*" Then
				Continue; // The whole metadata object is excluded.
			ElsIf PathsToAttributes = Undefined Then
				PathsToAttributes = New Array;
				Result.Insert(MetadataObject, PathsToAttributes);
			EndIf;
			// Attribute format is:
			//   "<Object type>.<Object name>.<Type of attribute or table>.<Name of attribute or table>[.<Attribute type>.<Table attribute name>]".
			//   Examples:
			//     "InformationRegister.ObjectsVersions.Attribute.VersionAuthor",
			//     "Document.SalesOrder.TabularSection.ProformaInvoices.Attribute.Account",
			//     "ChartOfCalculationTypes.BaseEarnings.StandardTabularSection.BaseCalculationTypes.StandardAttribute.CalculationType".
			// The relative path to the attribute should be such that is can be used in query conditions:
			//   "<Name of attribute or table>[.<Table attribute name>]".
			If SubstringCount = 4 Then
				RelativePathToAttribute = SubstringsArray[3];
			Else
				RelativePathToAttribute = SubstringsArray[3] + "." + SubstringsArray[5];
			EndIf;
			PathsToAttributes.Add(RelativePathToAttribute);
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

// Returns subordinate object links and a list of attributes for the link.
//
// You can override the procedure of subordinate object search.
// In the common module or the manager module, implement the OnSearchForReferenceReplacement
// procedure with the parameters:
//	ReplacementPairs - Map - Contains Original/Duplicate value pairs.
//	UnprocessedOriginalsValues - Array of Structure - Additional information on the objects to process:
//	  * ValueToReplace - ArbitraryRef - Original object value.
//	  * UsedLinks - See Common.SubordinateObjectsLinksByTypes  
//	  * KeyAttributesValue - Structure - Key - Attribute name. Value - Attribute value.
//
// Returns:
//  ValueTable:
//    * SubordinateObject - MetadataObject - Metadata object that is subordinate to the given object. 
//    * LinksFields - String - Names of attributes that determine the link between the main and subordinate objects.
//    * OnSearchForReferenceReplacement - String - (Optional) Name of the common module or manager module where the 
//                              OnSearchForReferenceReplacement procedure is defined.
//    * RunReferenceReplacementsAutoSearch - Boolean - If True, the function will attempt to search for replacements 
//                              for subordinate objects by linking field values. If an object is not found, the function 
//                              calls the OnSearchForReferenceReplacement procedure. See also: ReplaceReferences.
//
Function SubordinateObjects() Export
	
	LinksDetails = New ValueTable;
	LinksDetails.Columns.Add("SubordinateObject", New TypeDescription("MetadataObject"));
	LinksDetails.Columns.Add("LinksFields");
	LinksDetails.Columns.Add("OnSearchForReferenceReplacement", StringTypeDetails(0));
	LinksDetails.Columns.Add("RunReferenceReplacementsAutoSearch", New TypeDescription("Boolean"));
	
	SSLSubsystemsIntegration.OnDefineSubordinateObjects(LinksDetails);
	CommonOverridable.OnDefineSubordinateObjects(LinksDetails);
	
	// If Map or Structure is passed, cast it to the required type.
	For Each LinkRow In LinksDetails Do
		
		LinkFieldsDetailsType = TypeOf(LinkRow.LinksFields);
		If LinkFieldsDetailsType = Type("Structure")
			Or LinkFieldsDetailsType = Type("Map") Then
			
			LinksFieldsAsString = "";
			For Each KeyValue In LinkRow.LinksFields Do
				LinksFieldsAsString = LinksFieldsAsString + KeyValue.Key + ",";		
			EndDo;
			StringFunctionsClientServer.DeleteLastCharInString(LinksFieldsAsString,1);
			LinkRow.LinksFields = LinksFieldsAsString;
			
		EndIf;
		
		If LinkFieldsDetailsType = Type("Array") Then
			LinkRow.LinksFields = StrConcat(LinkRow.LinksFields, ","); 	
		EndIf;
	
	EndDo;
	
	Return LinksDetails;
	
EndFunction

// Returns subordinate object links specifying a linking field type.
//
// Returns:
//   ValueTable:
//    * Key - String
//    * AttributeType - Type
//    * AttributeName - String
//    * Used - Boolean
//    * Metadata - MetadataObject
//
Function SubordinateObjectsLinksByTypes() Export

	Result = New ValueTable;
	Result.Columns.Add("AttributeType", New TypeDescription("Type"));
	Result.Columns.Add("AttributeName", StringTypeDetails(0));
	Result.Columns.Add("Key", StringTypeDetails(0));
	Result.Columns.Add("Used", New TypeDescription("Boolean"));
	Result.Columns.Add("Metadata");
	
	Return Result;

EndFunction 

#EndRegion

#Region ConditionCalls

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for calling optional subsystems.

// Returns True if the functional subsystem exists in the configuration.
// Intended for calling an optional subsystem (making a conditional call) alongside "Common.CommonModule".
//
// A subsystem is considered functional if its "Include in command interface" check box is cleared.
// See also "CommonOverridable.OnDetermineDisabledSubsystems"
// and "CommonClient.SubsystemExists" to call from client-side code.
//
// Parameters:
//  FullSubsystemName - String - the full name of the subsystem metadata object
//                        without the "Subsystem." part, case-sensitive.
//                        Example: "StandardSubsystems.ReportsOptions".
//
// Example:
//  If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
//  	ModuleReportOptions = Common.CommonModule("ReportsOptions");
//  	ModuleReportOptions.<Procedure name>();
//  EndIf;
//
// Returns:
//  Boolean
//
Function SubsystemExists(FullSubsystemName) Export
	
	SubsystemsNames = StandardSubsystemsCached.SubsystemsNames();
	Return SubsystemsNames.Get(FullSubsystemName) <> Undefined;
	
EndFunction

// Returns a reference to a common module or manager module by name.
// Intended for conditionally calling procedures and functions alongside "Common.SubsystemExists".
// See also "CommonClient.CommonModule" for calling the client-side code.
//
// Parameters:
//  Name - String - The name of a common module or manager module. For example: 
//                 "ConfigurationUpdate", "DataProcessor.FullTextSearch".
//
// Returns:
//   CommonModule
//   ObjectManagerModule
//
// Example:
//	If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
//		ModuleSoftwareUpdate = Common.CommonModule("ConfigurationUpdate");
//		ModuleSoftwareUpdate.<Procedure name>();
//	EndIf;
//
//	If Common.SubsystemExists("StandardSubsystems.FullTextSearch") Then
//		ModuleDataProcessorFullTextSearch = Common.CommonModule("DataProcessor.FullTextSearch");
//		ModuleDataProcessorFullTextSearch.<Procedure name>();
//	EndIf;
//
Function CommonModule(Name) Export
	
	If Metadata.CommonModules.Find(Name) <> Undefined Then
		// ACC:488-disable CalculateInSafeMode is not used, to avoid calling CommonModule recursively.
		SetSafeMode(True);
		Module = Eval(Name);
		// ACC:488-on
	ElsIf StrOccurrenceCount(Name, ".") = 1 Then
		Return ServerManagerModule(Name);
	Else
		Module = Undefined;
	EndIf;
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid parameter %1 in %2. Common module ""%3"" does not exist.';"), 
			"Name", "Common.CommonModule", Name), 
			ErrorCategory.ConfigurationError);
	EndIf;
	
	Return Module;
	
EndFunction

#EndRegion

#Region CurrentEnvironment

////////////////////////////////////////////////////////////////////////////////
// The details functions of the current client application environment and operating system.

// Returns True if the client application is running on Windows.
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsWindowsClient() Export
	
	SetPrivilegedMode(True);
	
	IsWindowsClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsWindowsClient");
	
	If IsWindowsClient = Undefined Then
		Return False; // No client application.
	EndIf;
	
	Return IsWindowsClient;
	
EndFunction

// Returns True if the session runs on a Windows server.
//
// Returns:
//  Boolean - True if the server runs on Windows.
//
Function IsWindowsServer() Export
	
	SystemInfo = New SystemInfo;
	Return SystemInfo.PlatformType = PlatformType.Windows_x86 
		Or SystemInfo.PlatformType = PlatformType.Windows_x86_64;
	
EndFunction

// Returns True if the client application is running on Linux.
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsLinuxClient() Export
	
	SetPrivilegedMode(True);
	
	IsLinuxClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsLinuxClient");
	
	If IsLinuxClient = Undefined Then
		Return False; // No client application.
	EndIf;
	
	Return IsLinuxClient;
	
EndFunction

// Returns True if the current session runs on a Linux server.
//
// Returns:
//  Boolean - True if the server runs on Linux.
//
Function IsLinuxServer() Export
	
	SystemInfo = New SystemInfo;
	Return SystemInfo.PlatformType = PlatformType.Linux_x86
		Or SystemInfo.PlatformType = PlatformType.Linux_x86_64
		Or CommonClientServer.CompareVersions(SystemInfo.AppVersion, "8.3.22.1923") >= 0
			And (SystemInfo.PlatformType = PlatformType["Linux_ARM64"]
			Or SystemInfo.PlatformType = PlatformType["Linux_E2K"]);
	
EndFunction

// Returns True if the client application is running on macOS.
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsMacOSClient() Export
	
	SetPrivilegedMode(True);
	
	IsMacOSClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsMacOSClient");
	
	If IsMacOSClient = Undefined Then
		Return False; // No client application.
	EndIf;
	
	Return IsMacOSClient;
	
EndFunction

// Returns True if the client application is a web client.
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsWebClient() Export
	
	SetPrivilegedMode(True);
	IsWebClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsWebClient");
	
	If IsWebClient = Undefined Then
		Return False; // No client application.
	EndIf;
	
	Return IsWebClient;
	
EndFunction

// Returns True if the client application is a mobile client.
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsMobileClient() Export
	
	SetPrivilegedMode(True);
	
	IsMobileClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsMobileClient");
	
	If IsMobileClient = Undefined Then
		Return False; // No client application
	EndIf;
	
	Return IsMobileClient;
	
EndFunction

// Returns True if a client application is connected to the infobase through a web server.
//
// Returns:
//  Boolean - True if the application is connected.
//
Function ClientConnectedOverWebServer() Export
	
	SetPrivilegedMode(True);
	
	InfoBaseConnectionString = StandardSubsystemsServer.ClientParametersAtServer().Get("InfoBaseConnectionString");
	
	If InfoBaseConnectionString = Undefined Then
		Return False; // No client application
	EndIf;
	
	Return StrFind(Upper(InfoBaseConnectionString), "WS=") = 1;
	
EndFunction

// Returns the client's system information (if there is a client app).
// Before the first server call from the client is made, returns Undefined.
//
// Returns:
//  FixedStructure:
//    * OSVersion - String
//    * AppVersion - String
//    * ClientID - UUID
//    * UserAgentInformation - String
//    * RAM - Number
//    * Processor - String
//    * PlatformType - See CommonClientServer.NameOfThePlatformType
//  Undefined - If no client app is used, or the information is retrieved before the first server call is made.
//   For example, the first call of the SessionParametersSetting event from the session module.
//   
//
Function ClientSystemInfo() Export
	
	SetPrivilegedMode(True);
	Return StandardSubsystemsServer.ClientParametersAtServer().Get("SystemInfo");
	
EndFunction

// Returns the used client. For web client, also returns its version (if any).
// Before the first server call from the client is made, returns Undefined.
//
// Returns:
//  String - Valid values: "WebClient.<Name>[.<Version>]", "ThinClient",
//           "ThickClientManagedApplication", "ThickClientOrdinaryApplication".
//           Where <Name> could be "Chrome", "Firefox", "Safari", "IE", "Opera"
//           or "Other" if non of the above is applicable. For example, "WebClient.Chrome.109".
//  Undefined - If no client app is used, or the information is retrieved
//   before the first server call is made.
//   For example, the first call of the SessionParametersSetting event from the session module.
//
Function ClientUsed() Export
	
	SetPrivilegedMode(True);
	Return StandardSubsystemsServer.ClientParametersAtServer().Get("ClientUsed");
	
EndFunction

// Returns True if debug mode is enabled.
//
// Returns:
//  Boolean - True if debug mode is enabled.
//
Function DebugMode() Export
	
	ApplicationStartupParameter = StandardSubsystemsServer.ClientParametersAtServer(False).Get("LaunchParameter");
	
	Return StrFind(ApplicationStartupParameter, "DebugMode") > 0;
	
EndFunction

// Returns the amount of RAM available to the client application.
//
// Returns:
//  Number - the number of GB of RAM, with tenths-place accuracy.
//  Undefined - no client application is available, meaning CurrentRunMode() = Undefined.
//
Function RAMAvailableForClientApplication() Export
	
	AvailableMemorySize = StandardSubsystemsServer.ClientParametersAtServer().Get("RAM");
	Return AvailableMemorySize;
	
EndFunction

// Determines the infobase mode: file (True) or client/server (False).
// This function uses the InfobaseConnectionString parameter. You can specify this parameter explicitly.
//
// Parameters:
//  InfoBaseConnectionString - String - the parameter is applied if
//                 you need to check a connection string for another infobase.
//
// Returns:
//  Boolean - True if it is a file infobase.
//
Function FileInfobase(Val InfoBaseConnectionString = "") Export
	
	If IsBlankString(InfoBaseConnectionString) Then
		Return StandardSubsystemsCached.FileInfobase();
	EndIf;
	
	Return StrFind(Upper(InfoBaseConnectionString), "FILE=") = 1;
	
EndFunction 

// Returns True if the infobase is connected to 1C:Fresh.
//
// Returns:
//  Boolean - indicates a standalone workstation.
//
Function IsStandaloneWorkplace() Export
	
	If SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = CommonModule("DataExchangeServer");
		Return ModuleDataExchangeServer.IsStandaloneWorkplace();
	EndIf;
	
	Return False;
	
EndFunction

// Returns the flag identifying whether the infobase is distributed (DIB).
//
// Returns:
//   Boolean
//
Function IsDistributedInfobase() Export
	
	SetPrivilegedMode(True);
	Return StandardSubsystemsCached.DIBUsed();
	
EndFunction

// Determines whether this infobase is a subordinate node
// of a distributed infobase (DIB).
//
// Returns: 
//  Boolean - True if the infobase is a subordinate DIB node.
//
Function IsSubordinateDIBNode() Export
	
	SetPrivilegedMode(True);
	
	Return ExchangePlans.MasterNode() <> Undefined;
	
EndFunction

// Determines whether this infobase is a subordinate node
// of a distributed infobase (DIB) with filter.
//
// Returns: 
//  Boolean - True if the infobase is a subordinate DIB node with filter.
//
Function IsSubordinateDIBNodeWithFilter() Export
	
	SetPrivilegedMode(True);
	
	If ExchangePlans.MasterNode() <> Undefined
		And SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = CommonModule("DataExchangeServer");
		If ModuleDataExchangeServer.ExchangePlanPurpose(ExchangePlans.MasterNode().Metadata().Name) = "DIBWithFilter" Then
			Return True;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Returns True if update is required for the subordinate DIB node infobase configuration.
// Always False for the master node.
//
// Returns: 
//  Boolean - True if required.
//
Function SubordinateDIBNodeConfigurationUpdateRequired() Export
	
	Return IsSubordinateDIBNode() And ConfigurationChanged();
	
EndFunction

// Returns the data separation mode flag
// (conditional separation).
// 
// Returns False if the configuration does not support data separation mode
// (does not contain attributes to share).
//
// Returns:
//  Boolean - True if separation is enabled,
//           False is separation is disabled or not supported.
//
Function DataSeparationEnabled() Export
	
	Return StandardSubsystemsCached.DataSeparationEnabled();
	
EndFunction

// Returns a flag indicating whether separated data (included in the separators) can be accessed.
// The flag is session-specific, but can change its value if data separation is enabled
// on the session run. So, check the flag right before addressing the shared data.
// 
// Returns True if the configuration does not support data separation mode
// (does not contain attributes to share).
//
// Returns:
//   Boolean - True if separation is not supported or disabled
//                    or separation is enabled and separators are set.
//            False if separation is enabled and separators are not set.
//
Function SeparatedDataUsageAvailable() Export
	
	Return StandardSubsystemsCached.SeparatedDataUsageAvailable();
	
EndFunction

// Returns infobase publishing URL that is used to generate direct links to infobase objects 
// for Internet users.
// For example, if you send a link in an email, the recipient will be able to open the object in the application simply
// by clicking on the link.
// 
// Returns:
//   String - the infobase address specified in the "Internet address" administration panel setting.
//            It is stored in the InfobasePublicationURL constant.
//            For example, "http://1c.com/database".
//
// Example: 
//  Common.LocalInfobasePublishingURL() + "/" + e1cib/app/DataProcessor.ExportProjectData";
//  Returns a direct link to open the ExportProjectData data processor.
//
Function InfobasePublicationURL() Export
	
	SetPrivilegedMode(True);
	Result = Constants.InfobasePublicationURL.Get();
	If DataSeparationEnabled() And SeparatedDataUsageAvailable() Then 
		If IsBlankString(Result)
			And SubsystemExists("CloudTechnology.Core")
			And SubsystemExists("CloudTechnology.ExternalAPI") Then

			ModuleSaaSOperations = CommonModule("SaaSOperations");
			ModuleServiceProgrammingInterface = CommonModule("ServiceProgrammingInterface");
			SessionSeparator = ModuleSaaSOperations.SessionSeparatorValue();
			Try
				Result = ModuleServiceProgrammingInterface.ApplicationProperties(SessionSeparator).ApplicationURL;
			Except
				WriteLogEvent(NStr("en = 'Publication address';", DefaultLanguageCode()), // ACC:154 - Unavailability of the Server Manager is not considered an issue. 
					EventLogLevel.Warning,,, 
					ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				Return "";
			EndTry;
			Constants.InfobasePublicationURL.Set(Result);
		EndIf;
		Return Result;
	EndIf;	
	Return Result;
	
EndFunction

// Returns infobase publishing URL that is used to generate direct links to infobase objects 
// for local network users.
// For example, if you send a link in an email, the recipient will be able to open the object in the application simply
// by clicking on the link.
// 
// For web apps, it returns the value of the function "InfobasePublicationURL".
// 
// Returns:
//   String - the infobase address specified in the "Local address" administration panel setting.
//            It is stored in the LocalInfobasePublicationURL constant.
//            Example: "http://localserver/base".
//
// Example: 
//  Common.LocalInfobasePublishingURL() + "/" + e1cib/app/DataProcessor.ExportProjectData";
//  Returns a direct link to open the ExportProjectData data processor.
//
Function LocalInfobasePublishingURL() Export
	
	If DataSeparationEnabled() And SeparatedDataUsageAvailable() Then 
		Return InfobasePublicationURL();
	EndIf;

	SetPrivilegedMode(True);
	Return Constants.LocalInfobasePublishingURL.Get();
	
EndFunction

// Generates the application access address for the specified user.
//
// Parameters:
//  User - String - user's sign-in name;
//  Password - String - user's sign-in password;
//  IBPublicationType - String - publication used by the user to access the application:
//                           "OnInternet" or "OnLocalNetwork".
//
// Returns:
//  String, Undefined - application access address, or Undefined if no address is specified.
//
Function ProgrammAuthorizationAddress(User, Password, IBPublicationType) Export
	
	Result = "";
	
	If Lower(IBPublicationType) = Lower("InInternet") Then
		Result = InfobasePublicationURL();
	ElsIf Lower(IBPublicationType) = Lower("InLocalNetwork") Then
		Result = LocalInfobasePublishingURL();
	EndIf;
	
	If IsBlankString(Result) Then
		Return Undefined;
	EndIf;
	
	If Not StrEndsWith(Result, "/") Then
		Result = Result + "/";
	EndIf;
	
	Result = Result + "?n=" + EncodeString(User, StringEncodingMethod.URLEncoding);
	If ValueIsFilled(Password) Then
		Result = Result + "&p=" + EncodeString(Password, StringEncodingMethod.URLEncoding);
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the configuration revision number.
// The revision number is two first digits of a full configuration version.
// Example: revision number for version 1.2.3.4 is 1.2.
//
// Returns:
//  String - configuration revision number.
//
Function ConfigurationRevision() Export
	
	Result = "";
	ConfigurationVersion = Metadata.Version;
	
	Position = StrFind(ConfigurationVersion, ".");
	If Position > 0 Then
		Result = Left(ConfigurationVersion, Position);
		ConfigurationVersion = Mid(ConfigurationVersion, Position + 1);
		Position = StrFind(ConfigurationVersion, ".");
		If Position > 0 Then
			Result = Result + Left(ConfigurationVersion, Position - 1);
		Else
			Result = "";
		EndIf;
	EndIf;
	
	If IsBlankString(Result) Then
		Result = Metadata.Version;
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the general functional parameters.
// 
// Parameters:
//   ShouldReturnCachedValue - Boolean - Internal parameter.
//
// Returns:
//   See CommonOverridable.OnDetermineCommonCoreParameters.CommonParameters
//
Function CommonCoreParameters(ShouldReturnCachedValue = True) Export
	
	If ShouldReturnCachedValue Then
		Return StandardSubsystemsCached.CommonCoreParameters();
	EndIf;

	Result = New Structure;
	Result.Insert("PersonalSettingsFormName", "");
	Result.Insert("AskConfirmationOnExit", True);
	Result.Insert("RecommendedRAM", 4);
	Result.Insert("MinPlatformVersion", MinPlatformVersion());
	Result.Insert("RecommendedPlatformVersion", Result.MinPlatformVersion);
	Result.Insert("ShouldIncludeFullStackInLongRunningOperationErrors", False);
	Result.Insert("DisableMetadataObjectsIDs", False);
	// Instead, use MinPlatformVersion and RecommendedPlatformVersion properties :
	Result.Insert("MinPlatformVersion1", "");
	Result.Insert("MustExit", False); // Aborting startup if the current version is earlier than the minimum version.
	
	CommonOverridable.OnDetermineCommonCoreParameters(Result);
	Result.MinPlatformVersion = BuildNumberForTheCurrentPlatformVersion(Result.MinPlatformVersion);
	Result.RecommendedPlatformVersion = BuildNumberForTheCurrentPlatformVersion(Result.RecommendedPlatformVersion);
	
	
	SystemInfo = New SystemInfo;
	If CommonClientServer.CompareVersions(SystemInfo.AppVersion, Result.MinPlatformVersion) < 0
		And IsVersionOfProtectedComplexITSystem(SystemInfo.AppVersion) Then
		Result.MinPlatformVersion = SystemInfo.AppVersion;
		Result.RecommendedPlatformVersion = SystemInfo.AppVersion;
	EndIf;
	
	Min   = Result.MinPlatformVersion;
	Recommended = Result.RecommendedPlatformVersion;
	If IsMinRecommended1CEnterpriseVersionInvalid(Min, Recommended) Then
		MessageText = NStr("en = 'The minimum and recommended platform versions specified in %1 do not meet the following requirements:
			| - The minimum version must be filled.
			| - The minimum version cannot be earlier than the minimum SSL version (see %2).
			| - The minimum version cannot be earlier than the recommended version.
			|Minimum version: %3
			|Minimum SSL version: %4
			|Recommended version: %5';",
			DefaultLanguageCode());
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText,
			"CommonOverridable.OnDetermineCommonCoreParameters",
			"Common.MinPlatformVersion",
			Min, BuildNumberForTheCurrentPlatformVersion(MinPlatformVersion()), Recommended);
		WriteLogEvent(NStr("en = 'Core';", DefaultLanguageCode()), EventLogLevel.Warning,,, 
			MessageText);		
	EndIf;
	
	// Backward compatibility.
	MinPlatformVersion1 = Result.MinPlatformVersion1;
	If ValueIsFilled(MinPlatformVersion1) Then
		If Result.MustExit Then
			Result.MinPlatformVersion   = MinPlatformVersion1;
			Result.RecommendedPlatformVersion = "";
		Else
			Result.RecommendedPlatformVersion = MinPlatformVersion1;
			Result.MinPlatformVersion   = "";
		EndIf;
	Else
		Current = SystemInfo.AppVersion;
		If CommonClientServer.CompareVersions(Min, Current) > 0 Then
			Result.MinPlatformVersion1 = Min;
			Result.MustExit = True;
		Else
			Result.MinPlatformVersion1 = Recommended;
			Result.MustExit = False;
		EndIf;
	EndIf;
	
	ClarifyPlatformVersion(Result);
	
	Return Result;
	

EndFunction

// Returns descriptions of all configuration libraries, including
// the configuration itself.
//
// Returns:
//  Array - Array of Structure with the following properties:
//     * Name                            - String - a subsystem name (for example, StandardSubsystems).
//     * OnlineSupportID - String - a unique application name in online support services.
//     * Version                         - String - version number in a four-digit format (for example, "2.1.3.1").
//     * IsConfiguration                - Boolean - Indicates that this subsystem is the main configuration.
//
Function SubsystemsDetails() Export
	Result = New Array;
	SubsystemsDetails = StandardSubsystemsCached.SubsystemsDetails();
	For Each SubsystemDetails In SubsystemsDetails.ByNames Do
		Parameters = New Structure;
		Parameters.Insert("Name");
		Parameters.Insert("OnlineSupportID");
		Parameters.Insert("Version");
		Parameters.Insert("IsConfiguration");
		
		FillPropertyValues(Parameters, SubsystemDetails.Value);
		Result.Add(Parameters);
	EndDo;
	
	Return Result;
EndFunction

// Returns ID of the main configuration online support.
//
// Returns:
//  String - a unique application name in online support services.
//
Function ConfigurationOnlineSupportID() Export
	SubsystemsDetails = StandardSubsystemsCached.SubsystemsDetails();
	For Each SubsystemDetails In SubsystemsDetails.ByNames Do
		If SubsystemDetails.Value.IsConfiguration Then
			Return SubsystemDetails.Value.OnlineSupportID;
		EndIf;
	EndDo;
	
	Return "";
EndFunction

#EndRegion

#Region Dates

////////////////////////////////////////////////////////////////////////////////
// Functions to work with dates considering the session time zone

// Convert a local date to the "YYYY-MM-DDThh:mm:ssTZD" format (ISO 8601).
//
// Parameters:
//  LocalDate - Date - a date in the session time zone.
// 
// Returns:
//   String - date presentation.
//
Function LocalDatePresentationWithOffset(LocalDate) Export
	
	Offset = StandardTimeOffset(SessionTimeZone());
	Return CommonInternalClientServer.LocalDatePresentationWithOffset(LocalDate, Offset);
	
EndFunction

// Returns a string presentation of a time period between the passed dates or
// between the passed date and the current session date.
//
// Parameters:
//  BeginTime    - Date - starting point of the time period.
//  EndTime - Date - ending point of the time period; if not specified, the current session date is used instead.
//
// Returns:
//  String - a time period presentation.
//
Function TimeIntervalString(BeginTime, EndTime = Undefined) Export
	
	If EndTime = Undefined Then
		EndTime = CurrentSessionDate();
	ElsIf BeginTime > EndTime Then
		Raise NStr("en = 'The end date cannot be earlier than the start date.';");
	EndIf;
	
	IntervalValue = EndTime - BeginTime;
	IntervalValueInDays = Int(IntervalValue/60/60/24);
	
	If IntervalValueInDays > 365 Then
		IntervalDetails = NStr("en = 'more than a year';");
	ElsIf IntervalValueInDays > 31 Then
		IntervalDetails = NStr("en = 'more than a month';");
	ElsIf IntervalValueInDays >= 1 Then
		IntervalDetails = Format(IntervalValueInDays, "NFD=0") + " "
			+ UsersInternalClientServer.IntegerSubject(IntervalValueInDays,
				"", NStr("en = 'day,days,,,0';"));
	Else
		IntervalDetails = NStr("en = 'less than a day';");
	EndIf;
	
	Return IntervalDetails;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work date management functions.

// Save user work date settings.
//
// Parameters:
//  NewWorkingDate - Date - the date to be set as a work date for the user.
//  UserName - String - name of the user, for whom the work date is set.
//		If not set, the current user work date will be set.
//			
Procedure SetUserWorkingDate(NewWorkingDate, UserName = Undefined) Export

	ObjectKey = Upper("WorkingDate");
	
	CommonSettingsStorageSave(ObjectKey, "", NewWorkingDate, , UserName);

EndProcedure

// Returns the user work date settings value.
//
// Parameters:
//  UserName - String - Name of the user the work date requested for.
//		If no user is specified, the current user.
//
// Returns:
//  Date - User work date setting. If no setting is specified, an empty date.
//
Function UserWorkingDate(UserName = Undefined) Export

	ObjectKey = Upper("WorkingDate");

	Result = CommonSettingsStorageLoad(ObjectKey, "", '0001-01-01', , UserName);
	
	If TypeOf(Result) <> Type("Date") Then
		Result = '0001-01-01';
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the user work date settings value or the current session date
// if the user work date is not set.
//
// Parameters:
//  UserName - String - Name of the user the work date requested for.
//		If no user is specified, takes the current user.
//
// Returns:
//  Date - a user work date setting value, or the current session date if no settings are found.
//
Function CurrentUserDate(UserName = Undefined) Export

	Result = UserWorkingDate(UserName);
	
	If Not ValueIsFilled(Result) Then
		Result = CurrentSessionDate();
	EndIf;
	
	Return BegOfDay(Result);
	
EndFunction

#EndRegion

#Region Data

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions for applied types and value collections.

// Returns the enumeration value name string by its reference.
// Throws an exception if a non-existing enumeration value is passed 
// (for example, deleted in the configuration or from a disabled configuration extension).
//
// Parameters:
//  Value - EnumRef - the value whose enumeration name is sought.
//
// Returns:
//  String
//
// Example:
//   String value "Individual" will be placed in the result:
//   Result = Common.EnumerationValueName(Enumerations.CompanyIndividual.Individual);
//
Function EnumerationValueName(Value) Export
	
	MetadataObject = Value.Metadata();
	ValueIndex = Enums[MetadataObject.Name].IndexOf(Value);
	Return MetadataObject.EnumValues[ValueIndex].Name;
	
EndFunction 

// Deletes AttributeArray elements that match object attribute 
// names from the NoncheckableAttributeArray array.
// The procedure is intended to be used in FillCheckProcessing event handlers.
//
// Parameters:
//  AttributesArray              - Array - the collection of object attribute names.
//  NotCheckedAttributeArray - Array - collection of the object attribute names that are not checked.
//
Procedure DeleteNotCheckedAttributesFromArray(AttributesArray, NotCheckedAttributeArray) Export
	
	For Each ArrayElement In NotCheckedAttributeArray Do
	
		SequenceNumber = AttributesArray.Find(ArrayElement);
		If SequenceNumber <> Undefined Then
			AttributesArray.Delete(SequenceNumber);
		EndIf;
	
	EndDo;
	
EndProcedure

// Converts a value table to a structure array.
// Can be used to pass data to a client if the value
// table contains only those values that can
// be passed from the server to a client.
//
// The resulting array contains structures that duplicate
// value table row structures.
//
// It is recommended that you do not use this procedure to convert value tables
// with a large number of rows.
//
// Parameters:
//  ValueTable - ValueTable - the original value table.
//
// Returns:
//  Array - collection of the table rows expressed as structures.
//
Function ValueTableToArray(ValueTable) Export
	
	Array = New Array();
	StructureString = "";
	CommaRequired = False;
	For Each Column In ValueTable.Columns Do
		If CommaRequired Then
			StructureString = StructureString + ",";
		EndIf;
		StructureString = StructureString + Column.Name;
		CommaRequired = True;
	EndDo;
	For Each TableRow In ValueTable Do
		NewRow = New Structure(StructureString);
		FillPropertyValues(NewRow, TableRow);
		Array.Add(NewRow);
	EndDo;
	Return Array;

EndFunction

// Converts a value table row to a structure.
// Structure properties and their values correspond to the columns of the passed row.
//
// Parameters:
//  ValueTableRow - ValueTableRow
//
// Returns:
//  Structure - the converted value table row.
//
Function ValueTableRowToStructure(ValueTableRow) Export
	
	Structure = New Structure;
	For Each Column In ValueTableRow.Owner().Columns Do
		Structure.Insert(Column.Name, ValueTableRow[Column.Name]);
	EndDo;
	
	Return Structure;
	
EndFunction

// Creates a structure containing names and values of dimensions, resources, and attributes
// passed from information register record manager.
//
// Parameters:
//  RecordManager     - InformationRegisterRecordManagerInformationRegisterName - the record manager that must pass the structure.
//  RegisterMetadata - MetadataObjectInformationRegister - the information register metadata.
//
// Returns:
//  Structure - a collection of dimensions, resources, and attributes passed to the record manager.
//
Function StructureByRecordManager(RecordManager, RegisterMetadata) Export
	
	RecordAsStructure = New Structure;
	
	If RegisterMetadata.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
		RecordAsStructure.Insert("Period", RecordManager.Period);
	EndIf;
	For Each Field In RegisterMetadata.Dimensions Do
		RecordAsStructure.Insert(Field.Name, RecordManager[Field.Name]);
	EndDo;
	For Each Field In RegisterMetadata.Resources Do
		RecordAsStructure.Insert(Field.Name, RecordManager[Field.Name]);
	EndDo;
	For Each Field In RegisterMetadata.Attributes Do
		RecordAsStructure.Insert(Field.Name, RecordManager[Field.Name]);
	EndDo;
	
	Return RecordAsStructure;
	
EndFunction

// Creates an array and fills it with values from the column of the object that
// can be iterated using For each… From operator.
//
// Parameters:
//  RowsCollection           - ValueTable
//                           - ValueTree
//                           - ValueList
//                           - TabularSection
//                           - Map
//                           - Structure - a collection whose column must be exported to an array.
//                                         And other objects that can be iterated
//                                         using For each… From… Do operator.
//  ColumnName               - String - the name of the collection field whose values must be exported.
//  UniqueValuesOnly - Boolean - If True,
//                                      only unique values will be added to the array.
//
// Returns:
//  Array - the column values.
//
Function UnloadColumn(RowsCollection, ColumnName, UniqueValuesOnly = False) Export

	ArrayOfValues = New Array;
	
	UniqueValues = New Map;
	
	For Each CollectionRow In RowsCollection Do
		Value = CollectionRow[ColumnName];
		If UniqueValuesOnly And UniqueValues[Value] <> Undefined Then
			Continue;
		EndIf;
		ArrayOfValues.Add(Value);
		UniqueValues.Insert(Value, True);
	EndDo; 
	
	Return ArrayOfValues;
	
EndFunction

// Converts XML text into a structure with value tables.
// The function creates table columns based on the XML description.
//
// XML schema:
// <?xml version="1.0" encoding="utf-8"?>
//  <xs:schema attributeFormDefault="unqualified" elementFormDefault="qualified" xmlns:xs="http://www.w3.org/2001/XMLSchema">
//   <xs:element name="Items">
//    <xs:complexType>
//     <xs:sequence>
//      <xs:element maxOccurs="unbounded" name="Item">
//       <xs:complexType>
//        <xs:attribute name="Code" type="xs:integer" use="required" />
//        <xs:attribute name="Name" type="xs:string" use="required" />
//        <xs:attribute name="Socr" type="xs:string" use="required" />
//        <xs:attribute name="Index" type="xs:string" use="required" />
//       </xs:complexType>
//      </xs:element>
//     </xs:sequence>
//    <xs:attribute name="Description" type="xs:string" use="required" />
//    <xs:attribute name="Columns" type="xs:string" use="required" />
//   </xs:complexType>
//  </xs:element>
// </xs:schema>
//
// Parameters:
//  XML - String
//      - XMLReader - text in XML or ReadXML format.
//
// Returns:
//  Structure:
//   * TableName - String          - table name.
//   * Data     - ValueTable - the table converted from XML.
//
// Example:
//   ClassifierTable = Common.ReadXMLToTable(
//     DataProcessors.ImportCurrenciesRates.GetTemplate("NationalCurrencyClassifier").GetText()).Data;
//
Function ReadXMLToTable(Val XML) Export
	
	If TypeOf(XML) <> Type("XMLReader") Then
		Read = New XMLReader;
		Read.SetString(XML);
	Else
		Read = XML;
	EndIf;
	
	// Read the first node and check it.
	If Not Read.Read() Then
		Raise NStr("en = 'The XML file is empty. Data couldn''t be imported.';");
	ElsIf Read.Name <> "Items" Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t export data from the XML file. The file is missing a required tag: ""%1"".';"),
			"Items");
	EndIf;
	
	// Get table details and create a table.
	TableName = Read.GetAttribute("Description");
	ColumnsNames = StrReplace(Read.GetAttribute("Columns"), ",", Chars.LF);
	Columns1 = StrLineCount(ColumnsNames);
	
	ValueTable = New ValueTable;
	For Cnt = 1 To Columns1 Do
		ValueTable.Columns.Add(StrGetLine(ColumnsNames, Cnt), New TypeDescription("String"));
	EndDo;
	
	// Populate the table.
	While Read.Read() Do
		
		If Read.NodeType = XMLNodeType.EndElement And Read.Name = "Items" Then
			Break;
		ElsIf Read.NodeType <> XMLNodeType.StartElement Then
			Continue;
		ElsIf Read.Name <> "Item" Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t export data from the XML file. The tag ""%1"" is missing a required tag: ""%2"".';"),
				"Items", "Item");
		EndIf;
		
		NwRw = ValueTable.Add();
		For Cnt = 1 To Columns1 Do
			ColumnName = StrGetLine(ColumnsNames, Cnt);
			NwRw[Cnt-1] = Read.GetAttribute(ColumnName);
		EndDo;
		
	EndDo;
	
	// Populate the resulting value table.
	Result = New Structure;
	Result.Insert("TableName", TableName);
	Result.Insert("Data", ValueTable);
	
	Return Result;
	
EndFunction

// Compares two collections of rows (such as "ValueTable" and "ValueTree")
// that can be iterated using the "For Each… From… Do" statement.
// Both collections must meet the following requirements:
//  - It supports iteration with the "For Each… From… Do" statement.
//  - It contains all columns listed in "ColumnNames" 
//  (if "ColumnNames" is empty, the second collection must contain all columns of the first collection).
//  The method can be used to compare arrays.
//  For comparing other collection kinds and comparing hierarchical collections, see the "DataMatch" function. 
//
// Parameters:
//  RowsCollection1 - ValueTable
//                  - ValueTree
//                  - ValueList
//                  - TabularSection
//                  - Map
//                  - Array
//                  - FixedArray
//                  - Structure - a collection meeting the above requirements. And other
//                     objects that can be iterated using For each… From… Do operator.
//  RowsCollection2 - ValueTable
//                  - ValueTree
//                  - ValueList
//                  - TabularSection
//                  - Map
//                  - Array
//                  - FixedArray
//                  - Structure - a collection meeting the above requirements. And other
//                     objects that can be iterated using For each… From… Do operator.
//  ColumnsNames - String - A list of comma-delimited column names used for comparison.
//                          It is optional for collections whose column list can be auto-determined:
//                          ValueTable, ValueList, Map, Structure.
//                          If the parameter is not passed, the first collection's columns are compared.
//                          NOTE: When comparing collections containing item types instead of rows,
//                          pass only item property names as column names.
//                          For Map and Structure, it is "Key" and "Value" (not the keys' values).
//                          For ValueList, it is "Value" and "Presentation" (not the values).
//                          
//                          
//  ExcludingColumns - String - names of columns not included in the comparison.
//  UseRowOrder - Boolean - If True, the collections are considered 
//                      identical only if they contain the same rows in the same order.
//
// Returns:
//  Boolean - True if the collections are identical.
//
Function IdenticalCollections(RowsCollection1, RowsCollection2, Val ColumnsNames = "", Val ExcludingColumns = "", 
	UseRowOrder = False) Export
	
	CollectionType = TypeOf(RowsCollection1);
	ArraysCompared = (CollectionType = Type("Array") Or CollectionType = Type("FixedArray"));
	
	ColumnsToCompare = Undefined;
	If Not ArraysCompared Then
		ColumnsToCompare = ColumnsToCompare(RowsCollection1, ColumnsNames, ExcludingColumns);
	EndIf;
	
	If UseRowOrder Then
		Return SequenceSensitiveToCompare(RowsCollection1, RowsCollection2, ColumnsToCompare);
	ElsIf ArraysCompared Then // Using a simplified algorithm for arrays.
		Return CompareArrays(RowsCollection1, RowsCollection2);
	Else
		Return SequenceIgnoreSensitiveToCompare(RowsCollection1, RowsCollection2, ColumnsToCompare);
	EndIf;
	
EndFunction

// Compares data of a complex structure taking nesting into account.
//
// Parameters:
//  Data1 - Structure
//          - FixedStructure
//          - Map
//          - FixedMap
//          - Array
//          - FixedArray
//          - ValueStorage
//          - ValueTable
//          - String
//          - Number
//          - Boolean - data to compare.
//  Data2 - Arbitrary - the same types as the Data1 parameter types.
//
// Returns:
//  Boolean - True if the types match.
//
Function DataMatch(Data1, Data2) Export
	
	If TypeOf(Data1) <> TypeOf(Data2) Then
		Return False;
	EndIf;
	
	If TypeOf(Data1) = Type("Structure")
	 Or TypeOf(Data1) = Type("FixedStructure") Then
		
		If Data1.Count() <> Data2.Count() Then
			Return False;
		EndIf;
		
		For Each KeyAndValue In Data1 Do
			PreviousValue2 = Undefined;
			
			If Not Data2.Property(KeyAndValue.Key, PreviousValue2)
			 Or Not DataMatch(KeyAndValue.Value, PreviousValue2) Then
			
				Return False;
			EndIf;
		EndDo;
		
		Return True;
		
	ElsIf TypeOf(Data1) = Type("Map")
	      Or TypeOf(Data1) = Type("FixedMap") Then
		
		If Data1.Count() <> Data2.Count() Then
			Return False;
		EndIf;
		
		NewMapKeys = New Map;
		
		For Each KeyAndValue In Data1 Do
			NewMapKeys.Insert(KeyAndValue.Key, True);
			PreviousValue2 = Data2.Get(KeyAndValue.Key);
			
			If Not DataMatch(KeyAndValue.Value, PreviousValue2) Then
				Return False;
			EndIf;
		EndDo;
		
		For Each KeyAndValue In Data2 Do
			If NewMapKeys[KeyAndValue.Key] = Undefined Then
				Return False;
			EndIf;
		EndDo;
		
		Return True;
		
	ElsIf TypeOf(Data1) = Type("Array")
	      Or TypeOf(Data1) = Type("FixedArray") Then
		
		If Data1.Count() <> Data2.Count() Then
			Return False;
		EndIf;
		
		IndexOf = Data1.Count()-1;
		While IndexOf >= 0 Do
			If Not DataMatch(Data1.Get(IndexOf), Data2.Get(IndexOf)) Then
				Return False;
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		
		Return True;
		
	ElsIf TypeOf(Data1) = Type("ValueTable") Then
		
		If Data1.Count() <> Data2.Count() Then
			Return False;
		EndIf;
		
		If Data1.Columns.Count() <> Data2.Columns.Count() Then
			Return False;
		EndIf;
		
		For Each Column In Data1.Columns Do
			If Data2.Columns.Find(Column.Name) = Undefined Then
				Return False;
			EndIf;
			
			IndexOf = Data1.Count()-1;
			While IndexOf >= 0 Do
				If Not DataMatch(Data1[IndexOf][Column.Name], Data2[IndexOf][Column.Name]) Then
					Return False;
				EndIf;
				IndexOf = IndexOf - 1;
			EndDo;
		EndDo;
		
		Return True;
		
	ElsIf TypeOf(Data1) = Type("ValueStorage") Then
	
		If Not DataMatch(Data1.Get(), Data2.Get()) Then
			Return False;
		EndIf;
		
		Return True;
	EndIf;
	
	Return Data1 = Data2;
	
EndFunction

// Records data of the Structure, Map, and Array types taking nesting into account.
//
// Parameters:
//  Data - Structure
//         - Map
//         - Array - Collections, whose values are primitive types, value storages, or are immutable.
//           The following value types are supported::
//           Boolean, String, Number, Date, Undefined, UUID, Null, Type,
//           ValueStorage, CommonModule, MetadataObject, XDTOValueType, XDTOObjectType, AnyRef.
//           
//
//  RaiseException1 - Boolean - the default value is True. If it is False and there is data that
//                                cannot be fixed, no exception is raised but as much data as possible
//                                is fixed.
//
// Returns:
//  FixedStructure, FixedMap, FixedArray - fixed data similar to
//    the one passed in the Data parameter.
// 
Function FixedData(Data, RaiseException1 = True) Export
	
	If TypeOf(Data) = Type("Array") Then
		Array = New Array;
		
		For Each Value In Data Do
			
			If TypeOf(Value) = Type("Structure")
			 Or TypeOf(Value) = Type("Map")
			 Or TypeOf(Value) = Type("Array") Then
				
				Array.Add(FixedData(Value, RaiseException1));
			Else
				If RaiseException1 Then
					CheckFixedData(Value, True);
				EndIf;
				Array.Add(Value);
			EndIf;
		EndDo;
		
		Return New FixedArray(Array);
		
	ElsIf TypeOf(Data) = Type("Structure")
	      Or TypeOf(Data) = Type("Map") Then
		
		If TypeOf(Data) = Type("Structure") Then
			Collection = New Structure;
		Else
			Collection = New Map;
		EndIf;
		
		For Each KeyAndValue In Data Do
			Value = KeyAndValue.Value;
			
			If TypeOf(Value) = Type("Structure")
			 Or TypeOf(Value) = Type("Map")
			 Or TypeOf(Value) = Type("Array") Then
				
				Collection.Insert(
					KeyAndValue.Key, FixedData(Value, RaiseException1));
			Else
				If RaiseException1 Then
					CheckFixedData(Value, True);
				EndIf;
				Collection.Insert(KeyAndValue.Key, Value);
			EndIf;
		EndDo;
		
		If TypeOf(Data) = Type("Structure") Then
			Return New FixedStructure(Collection);
		Else
			Return New FixedMap(Collection);
		EndIf;
		
	ElsIf RaiseException1 Then
		CheckFixedData(Data);
	EndIf;
	
	Return Data;
	
EndFunction

// Calculates the checksum for arbitrary data using the specified algorithm.
//
// Parameters:
//  Data   - Arbitrary - the data to serialize.
//  Algorithm - HashFunction   - an algorithm to calculate the checksum. The default algorithm is MD5.
// 
// Returns:
//  String - the checksum. 32 bytes, no whitespaces.
//
Function CheckSumString(Val Data, Val Algorithm = Undefined) Export
	
	If Algorithm = Undefined Then
		Algorithm = HashFunction.MD5;
	EndIf;
	
	DataHashing = New DataHashing(Algorithm);
	If TypeOf(Data) <> Type("String") And TypeOf(Data) <> Type("BinaryData") Then
		Data = ValueToXMLString(Data);
	EndIf;
	DataHashing.Append(Data);
	
	If TypeOf(DataHashing.HashSum) = Type("BinaryData") Then 
		Result = StrReplace(DataHashing.HashSum, " ", "");
	ElsIf TypeOf(DataHashing.HashSum) = Type("Number") Then
		Result = Format(DataHashing.HashSum, "NG=");
	EndIf;
	
	Return Result;
	
EndFunction

// Trims a string to the specified length. The trimmed part is hashed
// to ensure the result string is unique. Checks an input string and, unless
// it fits the limit, converts its end into
// a unique 32 symbol string using MD5 algorithm.
//
// Parameters:
//  String            - String - the input string of arbitrary length.
//  MaxLength - Number  - the maximum valid string length.
//                               The minimum value is 32.
// 
// Returns:
//   String - a string within the maximum length limit.
//
Function TrimStringUsingChecksum(String, MaxLength) Export
	
	If MaxLength < 32 Then
		CommonClientServer.Validate(False, 
		StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The %1 parameter cannot be less than 32.';"),
			"MaxLength"), "Common.TrimStringUsingChecksum");
	EndIf;
	
	Result = String;
	If StrLen(String) > MaxLength Then
		Result = Left(String, MaxLength - 32);
		DataHashing = New DataHashing(HashFunction.MD5);
		DataHashing.Append(Mid(String, MaxLength - 32 + 1));
		Result = Result + StrReplace(DataHashing.HashSum, " ", "");
	EndIf;
	Return Result;
EndFunction

// Creates a complete recursive copy of a structure, map, array, list, or value table consistent
// with the child item type. For object-type values
// (for example, CatalogObject or DocumentObject), the procedure returns references to the source objects instead of copying the content.
//
// Parameters:
//  Source - Structure
//           - FixedStructure
//           - Map
//           - FixedMap
//           - Array
//           - FixedArray
//           - ValueList - an object that needs to be copied.
//  FixData - Boolean       - If it is True, then fix, if it is False, remove the fixing.
//                    - Undefined - do not change.
//
// Returns:
//  Structure, 
//  FixedStructure,
//  Map
//  FixedMap
//  Array
//  FixedArray
//  ValueList - a copy of the object passed in the Source parameter.
//
Function CopyRecursive(Source, FixData = Undefined) Export
	
	Var Receiver;
	
	SourceType = TypeOf(Source);
	
	If SourceType = Type("ValueTable") Then
		Receiver = Source.Copy();
		CopyValuesFromValTable(Receiver, FixData);
	ElsIf SourceType = Type("ValueTree") Then
		Receiver = Source.Copy();
		CopyValuesFromValTreeRow(Receiver.Rows, FixData);
	ElsIf SourceType = Type("Structure")
		Or SourceType = Type("FixedStructure") Then
		Receiver = CopyStructure(Source, FixData);
	ElsIf SourceType = Type("Map")
		Or SourceType = Type("FixedMap") Then
		Receiver = CopyMap(Source, FixData);
	ElsIf SourceType = Type("Array")
		Or SourceType = Type("FixedArray") Then
		Receiver = CopyArray(Source, FixData);
	ElsIf SourceType = Type("ValueList") Then
		Receiver = CopyValueList(Source, FixData);
	Else
		Receiver = Source;
	EndIf;
	
	Return Receiver;
	
EndFunction

// Returns topic details as a string.
// For documents, returns the document presentation. 
// For Ref objects, returns the presentation and the type enclosed in brackets. For example, "Scissors (Inventory)".
// For empty Ref, Undefined, or empty primitive types, returns "not specified".
// 
// Parameters:
//  ReferenceToSubject - Arbitrary
//
// Returns:
//   String - For example, "Scissors (Inventory)", "Sales order #0001 dated 01.01.2001", or "not specified".
// 
Function SubjectString(ReferenceToSubject) Export
	
	If ReferenceToSubject <> Undefined Then
		Return SubjectAsString(CommonClientServer.ValueInArray(ReferenceToSubject))[ReferenceToSubject];
	Else
		Return NStr("en = 'not specified';");
	EndIf;
	
EndFunction

// Returns the details of the RefsToSubjects objects.
// For documents, returns the document presentation. 
// For Ref objects, returns the presentation and the type enclosed in brackets. For example, "Scissors (Inventory)".
// For empty Ref, Undefined, or empty primitive types, returns "not specified".
// For objects not found in the configuration, returns "deleted".
// Undefined values are skipped.
// 
// Parameters:
//  RefsToSubjects - Array of AnyRef
//
// Returns:
//   Map of KeyAndValue:
//     * Key - AnyRef
//     * Value - String - For example, "Scissors (Inventory)", "Sales order #0001 dated 01.01.2001", or "not specified".
// 
Function SubjectAsString(Val RefsToSubjects) Export
	
	RefsToCheck = New Array;
	Result = New Map;
	For Each ReferenceToSubject In RefsToSubjects Do
		If ReferenceToSubject = Undefined Then
			Result[ReferenceToSubject] = NStr("en = 'empty';");
		ElsIf Not IsReference(TypeOf(ReferenceToSubject)) Then 
			Result[ReferenceToSubject] = String(ReferenceToSubject);
		ElsIf ReferenceToSubject.IsEmpty() Then	
			Result[ReferenceToSubject] = NStr("en = 'empty';");
		ElsIf Metadata.Enums.Contains(ReferenceToSubject.Metadata()) Then
			Result[ReferenceToSubject] = String(ReferenceToSubject);
		Else
			RefsToCheck.Add(ReferenceToSubject);
		EndIf;
	EndDo;
	
	For Each ExistingRef In RefsPresentations(RefsToCheck) Do
		ReferenceToSubject = ExistingRef.Key;
		Result[ReferenceToSubject] = ExistingRef.Value;
		If Not Metadata.Documents.Contains(ReferenceToSubject.Metadata()) Then
			ObjectPresentation = ReferenceToSubject.Metadata().ObjectPresentation;
			If IsBlankString(ObjectPresentation) Then
				ObjectPresentation = ReferenceToSubject.Metadata().Presentation();
			EndIf;
			Result[ReferenceToSubject] = StringFunctionsClientServer.SubstituteParametersToString("%1 (%2)", 
				Result[ReferenceToSubject], ObjectPresentation);
		EndIf;
	EndDo;
		
	Return Result;
	
EndFunction

// Returns the presentations of the passed references.
//
// Parameters:
//  RefsToCheck - Array of AnyRef, AnyRef
// 
// Returns:
//  Map of KeyAndValue:
//   * Key - AnyRef
//   * Value - String - Reference presentation, or "deleted" if it could not find the reference in the infobase.
//
Function RefsPresentations(RefsToCheck) Export
	
	ObjectsByType = New Map;
	If TypeOf(RefsToCheck) = Type("Array") Then
		For Each RefToCheck In RefsToCheck Do
			Objects = ObjectsByType[RefToCheck.Metadata()];
			If Objects = Undefined Then
				Objects = New Array;
				ObjectsByType[RefToCheck.Metadata()] = Objects;
			EndIf;
			Objects.Add(RefToCheck);
		EndDo; 
	Else
		ObjectsByType[RefsToCheck.Metadata()] = CommonClientServer.ValueInArray(RefsToCheck);
	EndIf;
	
	Result = New Map;
	If ObjectsByType.Count() = 0 Then
		Return Result;
	EndIf;
	
	Query = New Query;
	QueriesTexts = New Array;
	IndexOf = 0;
	For Each ObjectType In ObjectsByType Do
	
		QueryText = 
			"SELECT ALLOWED
			|	Presentation AS Presentation,
			|	Table.Ref AS Ref
			|FROM
			|	&TableName AS Table
			|WHERE
			|	Table.Ref IN (&Ref)";
		
		If QueriesTexts.Count() > 0 Then
			QueryText = StrReplace(QueryText, "SELECT ALLOWED", "SELECT"); // @query-part-1, @query-part-2
		EndIf;
		QueryText = StrReplace(QueryText, "&TableName", ObjectType.Key.FullName());
		
		ParameterName = "Ref" + Format(IndexOf, "NG=;NZ=");
		QueryText = StrReplace(QueryText, "&Ref", "&" + ParameterName);
		QueriesTexts.Add(QueryText);
		Query.SetParameter(ParameterName, ObjectType.Value);

		IndexOf = IndexOf + 1;
	EndDo;
	
	Query.Text = StrConcat(QueriesTexts, Chars.LF + "UNION ALL" + Chars.LF); // @query-part;
	
	SetPrivilegedMode(True);
	ActualLinks = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	RefsPresentations = Query.Execute().Unload();
	RefsPresentations.Indexes.Add("Ref");
	
	For Each Ref In ActualLinks Do
		If ValueIsFilled(Ref.Ref) Then
			RepresentationOfTheReference = RefsPresentations.Find(Ref.Ref, "Ref");
			Result[Ref.Ref] = ?(RepresentationOfTheReference <> Undefined, 
				RepresentationOfTheReference.Presentation, String(Ref.Ref));
		EndIf;
	EndDo;
	For Each Ref In RefsToCheck Do
		If Result[Ref] = Undefined Then
			Result[Ref] = NStr("en = 'does not exist';");
		EndIf;
	EndDo;
		
	Return Result;
	
EndFunction

#EndRegion

#Region DynamicList

// Creates a structure for the second ListProperties parameter of the SetDynamicListProperties procedure.
//
// Returns:
//  Structure - Any field can be Undefined if it is not set.:
//     * QueryText - String - the new query text.
//     * MainTable - String - the name of the main table.
//     * DynamicDataRead - Boolean - a flag indicating whether dynamic reading is used.
//
Function DynamicListPropertiesStructure() Export
	
	Return New Structure("QueryText, MainTable, DynamicDataRead");
	
EndFunction

// Sets the query text, primary table, or dynamic reading from a dynamic list.
// To avoid low performance, set these properties within the same call of this procedure.
//
// Parameters:
//  List - FormTable - a form item of the dynamic list whose properties are to be set.
//  ListProperties - See DynamicListPropertiesStructure
//
Procedure SetDynamicListProperties(List, ListProperties) Export
	
	Form = List.Parent;
	TypeClientApplicationForm = Type("ClientApplicationForm");
	
	While TypeOf(Form) <> TypeClientApplicationForm Do
		Form = Form.Parent;
	EndDo;
	
	DynamicList = Form[List.DataPath];
	QueryText = ListProperties.QueryText;
	
	If Not IsBlankString(QueryText) Then
		DynamicList.QueryText = QueryText;
	EndIf;
	
	MainTable = ListProperties.MainTable;
	
	If MainTable <> Undefined Then
		DynamicList.MainTable = MainTable;
	EndIf;
	
	DynamicDataRead = ListProperties.DynamicDataRead;
	
	If TypeOf(DynamicDataRead) = Type("Boolean") Then
		DynamicList.DynamicDataRead = DynamicDataRead;
	EndIf;
	
EndProcedure

#EndRegion

#Region ExternalConnection

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for managing external connections.

// Returns the CLSID of the COM class for working with 1C:Enterprise 8 through a COM connection.
//
// Parameters:
//  COMConnectorName - String - the name of the COM class for working with 1C:Enterprise 8 through a COM connection.
//
// Returns:
//  String - the CLSID string presentation.
//
Function COMConnectorID(Val COMConnectorName) Export
	
	If COMConnectorName = "v83.COMConnector" Then
		Return "181E893D-73A4-4722-B61D-D604B3D67D47";
	EndIf;
	
	Raise(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Invalid value of parameter ""%1"" in function ""%2"". CLSID for class ""%3"" is not specified.';"), 
		"COMConnectorName", "Common.COMConnectorID", COMConnectorName),
		ErrorCategory.ConfigurationError);
	
EndFunction

// Establishes an external infobase connection with the passed parameters and returns a pointer
// to the connection.
// 
// Parameters:
//  Parameters - See CommonClientServer.ParametersStructureForExternalConnection
// 
// Returns:
//  Structure:
//    * Join - COMObject
//                 - Undefined - If the connection is established, returns a COM object reference. Otherwise, returns Undefined.
//    * BriefErrorDetails - String - brief error description;
//    * DetailedErrorDetails - String - detailed error description;
//    * AddInAttachmentError - Boolean - a COM connection error flag.
//
Function EstablishExternalConnectionWithInfobase(Parameters) Export
	
	ConnectionNotAvailable = IsLinuxServer();
	BriefErrorDetails = NStr("en = 'Servers on Linux do not support direct infobase connections.';");
	
	Return CommonInternalClientServer.EstablishExternalConnectionWithInfobase(Parameters, ConnectionNotAvailable, BriefErrorDetails);
	
EndFunction

#EndRegion

#Region Metadata

////////////////////////////////////////////////////////////////////////////////
// Metadata object type definition functions.

// Reference data types

// Checks whether the metadata object belongs to the Document common  type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against Document type.
// 
// Returns:
//   Boolean - If True, the object is a document.
//
Function IsDocument(MetadataObject) Export
	
	Return Metadata.Documents.Contains(MetadataObject);
	
EndFunction

// Checks whether the metadata object belongs to the Catalog common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is a catalog.
//
Function IsCatalog(MetadataObject) Export
	
	Return Metadata.Catalogs.Contains(MetadataObject);
	
EndFunction

// Checks whether the metadata object belongs to the Enumeration common  type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is an enumeration.
//
Function IsEnum(MetadataObject) Export
	
	Return Metadata.Enums.Contains(MetadataObject);
	
EndFunction

// Checks whether the metadata object belongs to the Exchange Plan common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is an exchange plan.
//
Function IsExchangePlan(MetadataObject) Export
	
	Return Metadata.ExchangePlans.Contains(MetadataObject);
	
EndFunction

// Checks whether the metadata object belongs to the Chart of Characteristic Types common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is a chart of characteristic types.
//
Function IsChartOfCharacteristicTypes(MetadataObject) Export
	
	Return Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject);
	
EndFunction

// Checks whether the metadata object belongs to the Business Process common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is a business process.
//
Function IsBusinessProcess(MetadataObject) Export
	
	Return Metadata.BusinessProcesses.Contains(MetadataObject);
	
EndFunction

// Checks whether the metadata object belongs to the Task common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is a task.
//
Function IsTask(MetadataObject) Export
	
	Return Metadata.Tasks.Contains(MetadataObject);
	
EndFunction

// Checks whether the metadata object belongs to the Chart of Accounts common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is a chart of accounts.
//
Function IsChartOfAccounts(MetadataObject) Export
	
	Return Metadata.ChartsOfAccounts.Contains(MetadataObject);
	
EndFunction

// Checks whether the metadata object belongs to the Chart of Calculation Types common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is a chart of calculation types.
//
Function IsChartOfCalculationTypes(MetadataObject) Export
	
	Return Metadata.ChartsOfCalculationTypes.Contains(MetadataObject);
	
EndFunction

// Registers

// Checks whether the metadata object belongs to the Information Register common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is an information register.
//
Function IsInformationRegister(MetadataObject) Export
	
	Return Metadata.InformationRegisters.Contains(MetadataObject);
	
EndFunction

// Checks whether the metadata object belongs to the Accumulation Register common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is an accumulation register.
//
Function IsAccumulationRegister(MetadataObject) Export
	
	Return Metadata.AccumulationRegisters.Contains(MetadataObject);
	
EndFunction

// Checks whether the metadata object belongs to the Accounting Register common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is an accounting register.
//
Function IsAccountingRegister(MetadataObject) Export
	
	Return Metadata.AccountingRegisters.Contains(MetadataObject);
	
EndFunction

// Checks whether the metadata object belongs to the Calculation Register common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is a calculation register.
//
Function IsCalculationRegister(MetadataObject) Export
	
	Return Metadata.CalculationRegisters.Contains(MetadataObject);
	
EndFunction

// Constants

// Checks whether the metadata object belongs to the Constant common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is a constant.
//
Function IsConstant(MetadataObject) Export
	
	Return Metadata.Constants.Contains(MetadataObject);
	
EndFunction

// Document journals

// Checks whether the metadata object belongs to the Document Journal common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - True if the object is a document journal.
//
Function IsDocumentJournal(MetadataObject) Export
	
	Return Metadata.DocumentJournals.Contains(MetadataObject);
	
EndFunction

// Sequences

// Checks whether the metadata object belongs to the Sequences common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is a sequence.
//
Function IsSequence(MetadataObject) Export
	
	Return Metadata.Sequences.Contains(MetadataObject);
	
EndFunction

// ScheduledJobs

// Checks whether the metadata object belongs to the Scheduled Jobs common type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - If True, the object is a scheduled job.
//
Function IsScheduledJob(MetadataObject) Export
	
	Return Metadata.ScheduledJobs.Contains(MetadataObject);
	
EndFunction

// Common

// Checks whether the metadata object belongs to the register type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - True if the object is a register.
//
Function IsRegister(MetadataObject) Export
	
	Return Metadata.AccountingRegisters.Contains(MetadataObject)
		Or Metadata.AccumulationRegisters.Contains(MetadataObject)
		Or Metadata.CalculationRegisters.Contains(MetadataObject)
		Or Metadata.InformationRegisters.Contains(MetadataObject);
		
EndFunction

// Checks whether the metadata object belongs to the reference type.
//
// Parameters:
//  MetadataObject - MetadataObject - object to compare against the specified type.
// 
// Returns:
//   Boolean - True if the object is a reference type object.
//
Function IsRefTypeObject(MetadataObject) Export
	
	MetadataObjectName = MetadataObject.FullName();
	Position = StrFind(MetadataObjectName, ".");
	If Position > 0 Then 
		BaseTypeName = Left(MetadataObjectName, Position - 1);
		Return BaseTypeName = "Catalog"
			Or BaseTypeName = "Document"
			Or BaseTypeName = "BusinessProcess"
			Or BaseTypeName = "Task"
			Or BaseTypeName = "ChartOfAccounts"
			Or BaseTypeName = "ExchangePlan"
			Or BaseTypeName = "ChartOfCharacteristicTypes"
			Or BaseTypeName = "ChartOfCalculationTypes";
	Else
		Return False;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for operations with types, metadata objects, and their string presentations.

// Returns names of attributes for an object of the specified type.
//
// Parameters:
//  Ref - AnyRef - a reference to a database item to use with the function;
//  Type    - Type - attribute value type.
// 
// Returns:
//  String - a comma-separated string of configuration metadata object attributes.
//
// Example:
//  CompanyAttributes = Common.AttributeNamesByType (Document.Ref, Type("CatalogRef.Companies"));
//
Function AttributeNamesByType(Ref, Type) Export
	
	Result = "";
	ObjectMetadata = Ref.Metadata();
	
	For Each Attribute In ObjectMetadata.Attributes Do
		If Attribute.Type.ContainsType(Type) Then
			Result = Result + ?(IsBlankString(Result), "", ", ") + Attribute.Name;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Returns a base type name by the passed metadata object value.
//
// Parameters:
//  MetadataObject - MetadataObject - a metadata object whose base type is to be determined.
// 
// Returns:
//  String - name of the base type for the passed metadata object value.
//
// Example:
//  BaseTypeName = Common.BaseTypeNameByMetadataObject(Metadata.Catalogs.Products); = "Catalogs".
//
Function BaseTypeNameByMetadataObject(MetadataObject) Export
	
	If Metadata.Documents.Contains(MetadataObject) Then
		Return "Documents";
		
	ElsIf Metadata.Catalogs.Contains(MetadataObject) Then
		Return "Catalogs";
		
	ElsIf Metadata.Enums.Contains(MetadataObject) Then
		Return "Enums";
		
	ElsIf Metadata.InformationRegisters.Contains(MetadataObject) Then
		Return "InformationRegisters";
		
	ElsIf Metadata.AccumulationRegisters.Contains(MetadataObject) Then
		Return "AccumulationRegisters";
		
	ElsIf Metadata.AccountingRegisters.Contains(MetadataObject) Then
		Return "AccountingRegisters";
		
	ElsIf Metadata.CalculationRegisters.Contains(MetadataObject) Then
		Return "CalculationRegisters";
		
	ElsIf Metadata.ExchangePlans.Contains(MetadataObject) Then
		Return "ExchangePlans";
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject) Then
		Return "ChartsOfCharacteristicTypes";
		
	ElsIf Metadata.BusinessProcesses.Contains(MetadataObject) Then
		Return "BusinessProcesses";
		
	ElsIf Metadata.Tasks.Contains(MetadataObject) Then
		Return "Tasks";
		
	ElsIf Metadata.ChartsOfAccounts.Contains(MetadataObject) Then
		Return "ChartsOfAccounts";
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(MetadataObject) Then
		Return "ChartsOfCalculationTypes";
		
	ElsIf Metadata.Constants.Contains(MetadataObject) Then
		Return "Constants";
		
	ElsIf Metadata.DocumentJournals.Contains(MetadataObject) Then
		Return "DocumentJournals";
		
	ElsIf Metadata.Sequences.Contains(MetadataObject) Then
		Return "Sequences";
		
	ElsIf Metadata.ScheduledJobs.Contains(MetadataObject) Then
		Return "ScheduledJobs";
		
	ElsIf Metadata.CalculationRegisters.Contains(MetadataObject.Parent())
		And MetadataObject.Parent().Recalculations.Find(MetadataObject.Name) = MetadataObject Then
		Return "Recalculations";
		
	ElsIf Metadata.DataProcessors.Contains(MetadataObject) Then
		Return "DataProcessors";
		
	ElsIf Metadata.Reports.Contains(MetadataObject) Then
		Return "Reports";
		
	ElsIf Metadata.Subsystems.Contains(MetadataObject) Then
		Return "Subsystems";
		
	ElsIf Metadata.CommonModules.Contains(MetadataObject) Then
		Return "CommonModules";
		
	ElsIf Metadata.SessionParameters.Contains(MetadataObject) Then
		Return "SessionParameters";
		
	ElsIf Metadata.Roles.Contains(MetadataObject) Then
		Return "Roles";
		
	ElsIf Metadata.CommonAttributes.Contains(MetadataObject) Then
		Return "CommonAttributes";
		
	ElsIf Metadata.FilterCriteria.Contains(MetadataObject) Then
		Return "FilterCriteria";
		
	ElsIf Metadata.EventSubscriptions.Contains(MetadataObject) Then
		Return "EventSubscriptions";
		
	ElsIf Metadata.FunctionalOptions.Contains(MetadataObject) Then
		Return "FunctionalOptions";
		
	ElsIf Metadata.FunctionalOptionsParameters.Contains(MetadataObject) Then
		Return "FunctionalOptionsParameters";
		
	ElsIf Metadata.SettingsStorages.Contains(MetadataObject) Then
		Return "SettingsStorages";
		
	ElsIf Metadata.CommonForms.Contains(MetadataObject) Then
		Return "CommonForms";
		
	ElsIf Metadata.CommonCommands.Contains(MetadataObject) Then
		Return "CommonCommands";
		
	ElsIf Metadata.CommandGroups.Contains(MetadataObject) Then
		Return "CommandGroups";
		
	ElsIf Metadata.CommonTemplates.Contains(MetadataObject) Then
		Return "CommonTemplates";
		
	ElsIf Metadata.CommonPictures.Contains(MetadataObject) Then
		Return "CommonPictures";
		
	ElsIf Metadata.XDTOPackages.Contains(MetadataObject) Then
		Return "XDTOPackages";
		
	ElsIf Metadata.WebServices.Contains(MetadataObject) Then
		Return "WebServices";
		
	ElsIf Metadata.WSReferences.Contains(MetadataObject) Then
		Return "WSReferences";
		
	ElsIf Metadata.Styles.Contains(MetadataObject) Then
		Return "Styles";
		
	ElsIf Metadata.Languages.Contains(MetadataObject) Then
		Return "Languages";
		
	ElsIf Metadata.ExternalDataSources.Contains(MetadataObject) Then
		Return "ExternalDataSources";
		
	Else
		
		Return "";
		
	EndIf;
	
EndFunction

// Returns an object manager by the passed full name of a metadata object.
// Restriction: does not process business process route points.
//
// Parameters:
//  FullName - String - a full name of metadata object. Example: "Catalog.Company".
//
// Returns:
//  CatalogManager, DocumentManager, DataProcessorManager, InformationRegisterManager, ChartOfCharacteristicTypesManager
// 
// Example:
//  CatalogManager = Common.ObjectManagerByFullName("Catalog.Companies");
//  EmptyRef = CatalogManager.EmptyRef();
//
Function ObjectManagerByFullName(FullName) Export
	
	Var MOClass, MetadataObjectName1, Manager;
	
	NameParts = StrSplit(FullName, ".");
	
	If NameParts.Count() >= 2 Then
		MOClass = NameParts[0];
		MetadataObjectName1   = NameParts[1];
	Else 
		Manager = Undefined;
	EndIf;
	
	If      Upper(MOClass) = "EXCHANGEPLAN" Then
		Manager = ExchangePlans;
		
	ElsIf Upper(MOClass) = "CATALOG" Then
		Manager = Catalogs;
		
	ElsIf Upper(MOClass) = "DOCUMENT" Then
		Manager = Documents;
		
	ElsIf Upper(MOClass) = "DOCUMENTJOURNAL" Then
		Manager = DocumentJournals;
		
	ElsIf Upper(MOClass) = "ENUM" Then
		Manager = Enums;
		
	ElsIf Upper(MOClass) = "REPORT" Then
		Manager = Reports;
		
	ElsIf Upper(MOClass) = "DATAPROCESSOR" Then
		Manager = DataProcessors;
		
	ElsIf Upper(MOClass) = "CHARTOFCHARACTERISTICTYPES" Then
		Manager = ChartsOfCharacteristicTypes;
		
	ElsIf Upper(MOClass) = "CHARTOFACCOUNTS" Then
		Manager = ChartsOfAccounts;
		
	ElsIf Upper(MOClass) = "CHARTOFCALCULATIONTYPES" Then
		Manager = ChartsOfCalculationTypes;
		
	ElsIf Upper(MOClass) = "INFORMATIONREGISTER" Then
		Manager = InformationRegisters;
		
	ElsIf Upper(MOClass) = "ACCUMULATIONREGISTER" Then
		Manager = AccumulationRegisters;
		
	ElsIf Upper(MOClass) = "ACCOUNTINGREGISTER" Then
		Manager = AccountingRegisters;
		
	ElsIf Upper(MOClass) = "CALCULATIONREGISTER" Then
		
		If      NameParts.Count() = 2 Then
			Manager = CalculationRegisters;
			
		ElsIf NameParts.Count() = 4 Then
			SubordinateMOClass = NameParts[2];
			SubordinateMOName = NameParts[3];
			
			If Upper(SubordinateMOClass) = "RECALCULATION" Then 
				Manager = CalculationRegisters[MetadataObjectName1].Recalculations;
				MetadataObjectName1 = SubordinateMOName;
				
			Else 
				Manager = Undefined;
			EndIf;
			
		Else
			Manager = Undefined;
		EndIf;
		
	ElsIf Upper(MOClass) = "BUSINESSPROCESS" Then
		Manager = BusinessProcesses;
		
	ElsIf Upper(MOClass) = "TASK" Then
		Manager = Tasks;
		
	ElsIf Upper(MOClass) = "CONSTANT" Then
		Manager = Constants;
		
	ElsIf Upper(MOClass) = "SEQUENCE" Then
		Manager = Sequences;
		
	Else
		Manager = Undefined;
	EndIf;
	
	If Manager = Undefined Then
		CheckMetadataObjectExists(FullName);
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of parameter ""%1"" in function ""%2"". Metadata object ""%3"" is missing an object manager.';"), 
			"FullName", "Common.ObjectManagerByFullName", FullName),
			ErrorCategory.ConfigurationError);
	EndIf;
	
	Try
		Return Manager[MetadataObjectName1];
	Except
		CheckMetadataObjectExists(FullName);
		Raise;
	EndTry;
	
EndFunction

// Returns an object manager by the passed object reference.
// Restriction: does not process business process route points.
// See also: Common.ObjectManagerByFullName.
//
// Parameters:
//  Ref - AnyRef - an object whose manager is sought.
//
// Returns:
//  CatalogManager, DocumentManager, DataProcessorManager, InformationRegisterManager - an object manager.
//
// Example:
//  CatalogManager = Common.ObjectManagerByRef(RefToCompany);
//  EmptyRef = CatalogManager.EmptyRef();
//
Function ObjectManagerByRef(Ref) Export
	
	ObjectName = Ref.Metadata().Name;
	RefType = TypeOf(Ref);
	
	If Catalogs.AllRefsType().ContainsType(RefType) Then
		Return Catalogs[ObjectName];
		
	ElsIf Documents.AllRefsType().ContainsType(RefType) Then
		Return Documents[ObjectName];
		
	ElsIf BusinessProcesses.AllRefsType().ContainsType(RefType) Then
		Return BusinessProcesses[ObjectName];
		
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(RefType) Then
		Return ChartsOfCharacteristicTypes[ObjectName];
		
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(RefType) Then
		Return ChartsOfAccounts[ObjectName];
		
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(RefType) Then
		Return ChartsOfCalculationTypes[ObjectName];
		
	ElsIf Tasks.AllRefsType().ContainsType(RefType) Then
		Return Tasks[ObjectName];
		
	ElsIf ExchangePlans.AllRefsType().ContainsType(RefType) Then
		Return ExchangePlans[ObjectName];
		
	ElsIf Enums.AllRefsType().ContainsType(RefType) Then
		Return Enums[ObjectName];
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Check whether the passed type is a reference data type.
// Returns False for Undefined type.
//
// Parameters:
//  TypeToCheck - Type - a reference type to check.
//
// Returns:
//  Boolean - True if the type is a reference type.
//
Function IsReference(TypeToCheck) Export
	
	Return TypeToCheck <> Type("Undefined") And AllRefsTypeDetails().ContainsType(TypeToCheck);
	
EndFunction

// Checks whether the infobase record exists by its reference.
//
// Parameters:
//  RefToCheck - AnyRef - a value of an infobase reference.
// 
// Returns:
//  Boolean - True if exists.
//
Function RefExists(RefToCheck) Export
	
	QueryText = 
		"SELECT TOP 1
		|	1 AS Field1
		|FROM
		|	&TableName AS Table
		|WHERE
		|	Table.Ref = &Ref";
	
	QueryText = StrReplace(QueryText, "&TableName", TableNameByRef(RefToCheck));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", RefToCheck);
	
	SetPrivilegedMode(True);
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Returns the name of the metadata object kind by the passed object reference.
// Restriction: Business process route points are not supported.
// See also: ObjectKindByType.
//
// Parameters:
//  Ref - AnyRef - an object of the kind to search for.
//
// Returns:
//  String - a metadata object kind name. For example: "Catalog", "Document".
// 
Function ObjectKindByRef(Ref) Export
	
	Return ObjectKindByType(TypeOf(Ref));
	
EndFunction 

// Returns the name of a metadata object kind by the passed object type.
// Restriction: Business process route points are not supported.
// See also: ObjectKindByRef.
//
// Parameters:
//  ObjectType - Type - an applied object type defined in the configuration.
//
// Returns:
//  String - a metadata object kind name. For example: "Catalog", "Document".
// 
Function ObjectKindByType(ObjectType) Export
	
	If Catalogs.AllRefsType().ContainsType(ObjectType) Then
		Return "Catalog";
	
	ElsIf Documents.AllRefsType().ContainsType(ObjectType) Then
		Return "Document";
	
	ElsIf BusinessProcesses.AllRefsType().ContainsType(ObjectType) Then
		Return "BusinessProcess";
	
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(ObjectType) Then
		Return "ChartOfCharacteristicTypes";
	
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(ObjectType) Then
		Return "ChartOfAccounts";
	
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(ObjectType) Then
		Return "ChartOfCalculationTypes";
	
	ElsIf Tasks.AllRefsType().ContainsType(ObjectType) Then
		Return "Task";
	
	ElsIf ExchangePlans.AllRefsType().ContainsType(ObjectType) Then
		Return "ExchangePlan";
	
	ElsIf Enums.AllRefsType().ContainsType(ObjectType) Then
		Return "Enum";
	
	Else
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid data type of parameter ""%1"" in function ""%2"": ""%3"".';"), String(ObjectType)),
			"ObjectType", "Common.ObjectKindByType", ErrorCategory.ConfigurationError);
	EndIf;
	
EndFunction

// Returns full metadata object name by the passed reference value.
//
// Parameters:
//  Ref - AnyRef - an object whose infobase table name is sought.
// 
// Returns:
//  String - the full name of the metadata object for the specified object. For example, "Catalog.Products".
//
Function TableNameByRef(Ref) Export
	
	Return Ref.Metadata().FullName();
	
EndFunction

// Checks whether the value is a reference type value.
//
// Parameters:
//  Value - Arbitrary - a value to check.
//
// Returns:
//  Boolean - True if the value has a reference type.
//
Function RefTypeValue(Value) Export
	
	Return IsReference(TypeOf(Value));
	
EndFunction

// Checks whether a catalog item or an item of the chart of characteristic types is an item group.
//
// Parameters:
//  Object - CatalogRef
//         - ChartOfCharacteristicTypesRef
//         - CatalogObject
//         - ChartOfCharacteristicTypesObject - Object being checked.
//
// Returns:
//  Boolean
//
Function ObjectIsFolder(Object) Export
	
	If RefTypeValue(Object) Then
		Ref = Object;
	Else
		Ref = Object.Ref;
	EndIf;
	
	ObjectMetadata = Ref.Metadata();
	If IsCatalog(ObjectMetadata) Then
		If Not ObjectMetadata.Hierarchical
		 	Or ObjectMetadata.HierarchyType <> Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
			Return False;
		EndIf;
	ElsIf Not IsChartOfCharacteristicTypes(ObjectMetadata) Or Not ObjectMetadata.Hierarchical Then
		Return False;
	EndIf;
	
	If Ref <> Object Then
		Return Object.IsFolder;
	EndIf;
	
	Return ObjectAttributeValue(Ref, "IsFolder") = True;
	
EndFunction

// Returns a reference corresponding to the metadata object to be used in the database.
// See also: Common.MetadataObjectIDs.
//
// References are returned for the following metadata objects:
// - Subsystem (See also: CommonOverridable.OnAddMetadataObjectsRenaming)
// - Role (See also: CommonOverridable.OnAddMetadataObjectsRenaming)
// - ExchangePlan
// - Constant
// - Catalog
// - Document
// - DocumentJournal
// - Report
// - DataProcessor
// - ChartOfCharacteristicTypes
// - ChartOfAccounts
// - ChartOfCalculationTypes
// - InformationRegister
// - AccumulationRegister
// - AccountingRegister
// - CalculationRegister
// - BusinessProcess
// - Task
// 
// Parameters:
//  MetadataObjectDetails - MetadataObject - a configuration metadata object;
//                            - Type - a type that can be used in Metadata.FindByType;
//                            - String - the valid full name of a metadata object to 
//                                       use in the Metadata.FindByFullName function.
//
//  RaiseException1 - Boolean - If False, Null is returned instead of calling an exception for a non-existing
//                                or unsupported metadata object.
//
// Returns:
//  CatalogRef.MetadataObjectIDs
//  CatalogRef.ExtensionObjectIDs
//  Null
//  
// Example:
//  ID = Common.MetadataObjectID(TypeOf(Ref));
//  ID = Common.MetadataObjectID(MetadataObject);
//  ID = Common.MetadataObjectID("Catalog.Companies");
//
Function MetadataObjectID(MetadataObjectDetails, RaiseException1 = True) Export
	
	Return Catalogs.MetadataObjectIDs.MetadataObjectID(
		MetadataObjectDetails, RaiseException1);
	
EndFunction

// Returns references corresponding to the metadata objects to be used in the database.
// See also: Common.MetadataObjectID.
//
// References are returned for the following metadata objects:
// - Subsystem (See also: CommonOverridable.OnAddMetadataObjectsRenaming)
// - Role (See also: CommonOverridable.OnAddMetadataObjectsRenaming)
// - ExchangePlan
// - Constant
// - Catalog
// - Document
// - DocumentJournal
// - Report
// - DataProcessor
// - ChartOfCharacteristicTypes
// - ChartOfAccounts
// - ChartOfCalculationTypes
// - InformationRegister
// - AccumulationRegister
// - AccountingRegister
// - CalculationRegister
// - BusinessProcess
// - Task
// 
// Parameters:
//  MetadataObjectsDetails - Array of MetadataObject - configuration metadata objects;
//                             - Array of String - full names of the metadata objects to use
//                         in the Metadata.FindByFullName function;
//                             - Array of Type - types that can be used in the Metadata.FindByType function.
//  RaiseException1 - Boolean - If False, non-existing and unsupported metadata objects
//                                will be skipped in the return value.
//
// Returns:
//  Map of KeyAndValue:
//    * Key     - String - a full name of the metadata object.
//    * Value - CatalogRef.MetadataObjectIDs
//               - CatalogRef.ExtensionObjectIDs - the found ID.
//
// Example:
//  FullNames = New Array;
//  FullNames.Add(Metadata.Catalogs.Currencies.FullName());
//  FullNames.Add(Metadata.InformationRegisters.ExchangeRates.FullName());
//  IDs = Common.MetadataObjectIDs(FullNames);
//
Function MetadataObjectIDs(MetadataObjectsDetails, RaiseException1 = True) Export
	
	Return Catalogs.MetadataObjectIDs.MetadataObjectIDs(
		MetadataObjectsDetails, RaiseException1);
	
EndFunction

// Returns a metadata object by ID.
//
// Parameters:
//  Id - CatalogRef.MetadataObjectIDs
//                - CatalogRef.ExtensionObjectIDs - the IDs of
//                    metadata objects in an application or an extension.
//
//  RaiseException1 - Boolean - If True, when metadata object
//                    does not exist or it is unavailable, it returns
//                    Null or Undefined instead of raising an exception.
//
// Returns:
//  MetadataObject - the metadata object with the specified ID.
//
//  Null is returned when RaiseException = False. Null means
//    there is no metadata object with this ID (the ID is invalid).
//
//  Undefined is returned when RaiseException = False. Undefined means
//    the ID is valid, but the session fails to get the MetadataObject.
//    For configuration extensions, that means the extension had been installed, but was not attached,
//    or the configuration was not restarted, or attaching the extension failed.
//    For the configuration, that means the new session contains the object
//    and the current session does not contain it.
//
Function MetadataObjectByID(Id, RaiseException1 = True) Export
	
	Return Catalogs.MetadataObjectIDs.MetadataObjectByID(
		Id, RaiseException1);
	
EndFunction

// Returns metadata objects with the specified IDs.
//
// Parameters:
//  IDs - Array - with the following values:
//                     * Value - CatalogRef.MetadataObjectIDs
//                                - CatalogRef.ExtensionObjectIDs - the IDs of
//                                    metadata objects in an application or an extension.
//
//  RaiseException1 - Boolean - If True, when metadata object
//                    does not exist or it is unavailable, it returns
//                    Null or Undefined instead of raising an exception.
//
// Returns:
//  Map of KeyAndValue:
//   * Key     - CatalogRef.MetadataObjectIDs
//              - CatalogRef.ExtensionObjectIDs - the passed ID.
//   * Value - MetadataObject - the metadata object with the specified ID.
//              - Null - is returned when RaiseException = False. Null means
//                  there is no metadata object with this ID (the ID is invalid).
//              - Undefined - is returned when RaiseException = False. Undefined means
//                  the ID is valid, but the session fails to get the MetadataObject.
//                  For configuration extensions, that means the extension had been installed, but was not attached,
//                  or the configuration was not restarted, or attaching the extension failed.
//                  For the configuration, that means the new session contains the object
//                  and the current session does not contain it.
//
Function MetadataObjectsByIDs(IDs, RaiseException1 = True) Export
	
	Return Catalogs.MetadataObjectIDs.MetadataObjectsByIDs(
		IDs, RaiseException1);
	
EndFunction

// Returns MetadataObject quickly found by its full name.
// More efficient than method Metadata.FindByFullName for root objects.
// 
//
// Parameters:
//  FullName - String - Full name of the metadata object. For example, "Catalog.Companies".
//
// Returns:
//  MetadataObject - When an object is found.
//  Undefined - When no object is found.
//
Function MetadataObjectByFullName(FullName) Export
	
	PointPosition = StrFind(FullName, ".");
	BaseTypeName = Left(FullName, PointPosition - 1);
	
	CollectionsNames = StandardSubsystemsCached.CollectionNamesByBaseTypeNames();
	Collection = CollectionsNames.Get(Upper(BaseTypeName));
	
	If Collection <> Undefined Then
		If Collection <> "Subsystems" Then
			ObjectName = Mid(FullName, PointPosition + 1);
			MetadataObject = Metadata[Collection].Find(ObjectName);
		Else
			SubsystemsNames = StrSplit(Upper(FullName), ".");
			Count = SubsystemsNames.Count();
			Subsystem = Metadata;
			MetadataObject = Undefined;
			IndexOf = 0;
			While True Do
				IndexOf = IndexOf + 1;
				If IndexOf >= Count Then
					Break;
				EndIf;
				SubsystemName = SubsystemsNames[IndexOf];
				Subsystem = Subsystem.Subsystems.Find(SubsystemName);
				If Subsystem = Undefined Then
					Break;
				EndIf;
				IndexOf = IndexOf + 1;
				If IndexOf = Count Then
					MetadataObject = Subsystem;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	If MetadataObject = Undefined Then
		MetadataObject = Metadata.FindByFullName(FullName);
	EndIf;
	
	Return MetadataObject;
	
EndFunction

// Determines whether the metadata object is available by functional options.
//
// Parameters:
//   MetadataObject - MetadataObject
//                    - String - Metadata object being checked.
//
// Returns:
//   Boolean - True if the object is available.
//
Function MetadataObjectAvailableByFunctionalOptions(Val MetadataObject) Export
	If MetadataObject = Undefined Then
		Return False;
	EndIf;
	If TypeOf(MetadataObject) <> Type("String") Then
		FullName = MetadataObject.FullName();
	Else
		FullName = MetadataObject;
	EndIf;
	Return StandardSubsystemsCached.ObjectsEnabledByOption().Get(FullName) <> False;
EndFunction

// During migration to the specified configuration version, stores the metadata object renaming details
// to the Totals structure, which is passed to
// the CommonOverridable.OnAddMetadataObjectsRenaming procedure.
// 
// Parameters:
//   Total                    - See CommonOverridable.OnAddMetadataObjectsRenaming.Total
//   IBVersion                - String    - the destination configuration version.
//                                         For example, "2.1.2.14".
//   PreviousFullName         - String    - The original full name of the metadata object to rename.
//                                         For example, "Subsystem.ServiceSubsystems".
//   NewFullName          - String    - New full name of the metadata object.
//                                         For example, "Subsystem.UtilitySubsystems".
//   LibraryID - String    - an internal ID of the library that contains IBVersion.
//                                         Not required for the base configuration.
//                                         For example, "StandardSubsystems", as specified
//                                         in InfobaseUpdateSSL.OnAddSubsystem.
// Example:
//	Common.AddRenaming(Total, "2.1.2.14",
//		"Subsystem.ServiceSubsystems",
//		"Subsystem.UtilitySubsystems");
//
Procedure AddRenaming(Total, IBVersion, PreviousFullName, NewFullName, LibraryID = "") Export
	
	Catalogs.MetadataObjectIDs.AddRenaming(Total,
		IBVersion, PreviousFullName, NewFullName, LibraryID);
	
EndProcedure

// Returns the string presentation of the type. For example, "CatalogRef.ObjectName" or "DocumentRef.ObjectName".
// For other types, casts the type to String. For example, "Number".
//
// Parameters:
//  Type - Type - a type whose presentation is sought.
//
// Returns:
//  String
//
Function TypePresentationString(Type) Export
	
	Presentation = "";
	
	If IsReference(Type) Then
	
		FullName = Metadata.FindByType(Type).FullName();
		ObjectName = StrSplit(FullName, ".")[1];
		
		If Catalogs.AllRefsType().ContainsType(Type) Then
			Presentation = "CatalogRef";
		
		ElsIf Documents.AllRefsType().ContainsType(Type) Then
			Presentation = "DocumentRef";
		
		ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
			Presentation = "BusinessProcessRef";
		
		ElsIf BusinessProcesses.RoutePointsAllRefsType().ContainsType(Type) Then
			Presentation = "BusinessProcessRoutePointRef";
		
		ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfCharacteristicTypesRef";
		
		ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfAccountsRef";
		
		ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfCalculationTypesRef";
		
		ElsIf Tasks.AllRefsType().ContainsType(Type) Then
			Presentation = "TaskRef";
		
		ElsIf ExchangePlans.AllRefsType().ContainsType(Type) Then
			Presentation = "ExchangePlanRef";
		
		ElsIf Enums.AllRefsType().ContainsType(Type) Then
			Presentation = "EnumRef";
		
		EndIf;
		
		Result = ?(Presentation = "", Presentation, Presentation + "." + ObjectName);
		
	ElsIf Type = Type("Undefined") Then
		Result = "Undefined";
		
	ElsIf Type = Type("String") Then
		Result = "String";

	ElsIf Type = Type("Number") Then
		Result = "Number";

	ElsIf Type = Type("Boolean") Then
		Result = "Boolean";

	ElsIf Type = Type("Date") Then
		Result = "Date";
	
	Else
		
		Result = String(Type);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Returns a value table with the required property information for all attributes of a metadata object.
// Gets property values of standard and custom attributes (custom attributes are the attributes created in Designer mode).
//
// Parameters:
//  MetadataObject  - MetadataObject - an object whose attribute property values are sought.
//                      Example: Metadata.Document.Invoice
//  Properties - String - comma-separated attribute properties whose values to be retrieved.
//                      Example: "Name, Type, Synonym, Tooltip".
//
// Returns:
//  ValueTable - required property information for all attributes of the metadata object.
//
Function ObjectPropertiesDetails(MetadataObject, Properties) Export
	
	PropertiesArray = StrSplit(Properties, ",");
	
	// Function return value.
	ObjectPropertiesDescriptionTable = New ValueTable;
	
	// Adding fields to the value table according to the names of the passed properties.
	For Each PropertyName In PropertiesArray Do
		ObjectPropertiesDescriptionTable.Columns.Add(TrimAll(PropertyName));
	EndDo;
	
	// Filling table rows with metadata object attribute values.
	For Each Attribute In MetadataObject.Attributes Do
		FillPropertyValues(ObjectPropertiesDescriptionTable.Add(), Attribute);
	EndDo;
	
	// Filling table rows with standard metadata object attribute properties.
	For Each Attribute In MetadataObject.StandardAttributes Do
		FillPropertyValues(ObjectPropertiesDescriptionTable.Add(), Attribute);
	EndDo;
	
	Return ObjectPropertiesDescriptionTable;
	
EndFunction

// Returns a flag indicating whether the attribute is a standard attribute.
//
// Parameters:
//  StandardAttributes - StandardAttributeDescriptions - the type and value describe a collection of settings for various
//                                                         standard attributes;
//  AttributeName         - String - an attribute to check whether it is a standard
//                                  attribute or not.
// 
// Returns:
//   Boolean - True if the attribute is a standard attribute.
//
Function IsStandardAttribute(StandardAttributes, AttributeName) Export
	
	For Each Attribute In StandardAttributes Do
		If Attribute.Name = AttributeName Then
			Return True;
		EndIf;
	EndDo;
	Return False;
	
EndFunction

// Checks whether the attribute with the passed name exists among the object attributes.
//
// Parameters:
//  AttributeName - String - an attribute name;
//  ObjectMetadata - MetadataObject - an object to search for the attribute.
//
// Returns:
//  Boolean - True if the attribute is found.
//
Function HasObjectAttribute(AttributeName, ObjectMetadata) Export

	Attributes = ObjectMetadata.Attributes; // MetadataObjectCollection
	Return Not (Attributes.Find(AttributeName) = Undefined);

EndFunction

// Checks whether the type description contains only one value type and 
// it is equal to the specified type.
//
// Parameters:
//   TypeDetails - TypeDescription - a type collection to check;
//   ValueType  - Type - Data type being checked.
//
// Returns:
//   Boolean - If True, there's a match.
//
// Example:
//  If Common.TypeDetailsContainsType(ValueTypeProperties, Type("Boolean") Then
//    // Displaying the field as a check box.
//  EndIf;
//
Function TypeDetailsContainsType(TypeDetails, ValueType) Export
	
	If TypeDetails.Types().Count() = 1
	   And TypeDetails.Types().Get(0) = ValueType Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Creates a TypeDescription object that contains the String type.
//
// Parameters:
//  StringLength - Number - string length.
//
// Returns:
//  TypeDescription - description of the String type.
//
Function StringTypeDetails(StringLength) Export
	
	Return New TypeDescription("String", , New StringQualifiers(StringLength));
	
EndFunction

// Creates a TypeDescription object that contains the Number type.
//
// Parameters:
//  Digits - Number - the total number of digits in a number (both in
//                        the integer part and the fractional part).
//  FractionDigits - Number - number of digits in the fractional part.
//  NumberSign - AllowedSign - allowed sign of the number.
//
// Returns:
//  TypeDescription - description of Number type.
//
Function TypeDescriptionNumber(Digits, FractionDigits = 0, Val NumberSign = Undefined) Export
	
	If NumberSign = Undefined Then 
		NumberSign = AllowedSign.Any;
	EndIf;
	
	Return New TypeDescription("Number", New NumberQualifiers(Digits, FractionDigits, NumberSign));
	
EndFunction

// Creates a TypeDescription object that contains the Date type.
//
// Parameters:
//  Var_DateFractions - DateFractions - a set of Date type value usage options.
//
// Returns:
//  TypeDescription - description of Date type.
//
Function DateTypeDetails(Var_DateFractions) Export
	
	Return New TypeDescription("Date", , , New DateQualifiers(Var_DateFractions));
	
EndFunction

// Returns a type description that includes all configuration reference types.
//
// Returns:
//  TypeDescription - all reference types in the configuration.
//
Function AllRefsTypeDetails() Export
	
	Return StandardSubsystemsCached.AllRefsTypeDetails();
	
EndFunction

// Returns a string list presentation specified in metadata object properties.
// Depending on which metadata object properties are filled in, the function returns one of them in the specified
// order: Extended list presentation, List presentation, Synonym, or Name.
//
// Parameters:
//  MetadataObject - MetadataObject - an arbitrary object.
//
// Returns:
//  String - list presentation.
//
Function ListPresentation(MetadataObject) Export
	
	ObjectProperties = New Structure("ExtendedListPresentation,ListPresentation");
	FillPropertyValues(ObjectProperties, MetadataObject);
	
	If ValueIsFilled(ObjectProperties.ExtendedListPresentation) Then
		Result = ObjectProperties.ExtendedListPresentation;
	ElsIf ValueIsFilled(ObjectProperties.ListPresentation) Then
		Result = ObjectProperties.ListPresentation;
	Else
		Result = MetadataObject.Presentation();
	EndIf;
	
	Return Result;
	
EndFunction

// Returns a string object presentation specified in metadata object properties.
// Depending on which metadata object properties are filled in, the function returns one of them in the specified
// order: Extended object presentation, Object presentation, Synonym, or Name.
//
// Parameters:
//  MetadataObject - MetadataObject - an arbitrary object.
//
// Returns:
//  String - object presentation.
//
Function ObjectPresentation(MetadataObject) Export
	
	ObjectProperties = New Structure("ExtendedObjectPresentation,ObjectPresentation");
	FillPropertyValues(ObjectProperties, MetadataObject);
	
	If ValueIsFilled(ObjectProperties.ExtendedObjectPresentation) Then
		Result = ObjectProperties.ExtendedObjectPresentation;
	ElsIf ValueIsFilled(ObjectProperties.ObjectPresentation) Then
		Result = ObjectProperties.ObjectPresentation;
	Else
		Result = MetadataObject.Presentation();
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region SettingsStorage

////////////////////////////////////////////////////////////////////////////////
// Saving, reading, and deleting settings from storages.

// Saves a setting to the common settings storage as the Save method
// of StandardSettingsStorageManager or SettingsStorageManager.<Storage name>,
// object. Setting keys exceeding 128 characters are supported by hashing the key part
// that exceeds 96 characters.
// If the SaveUserData right is not granted, data save fails and no error is raised.
//
// Parameters:
//   ObjectKey       - String           - See Syntax Assistant.
//   SettingsKey      - String           - See Syntax Assistant.
//   Settings         - Arbitrary     - See Syntax Assistant.
//   SettingsDescription  - SettingsDescription - See Syntax Assistant.
//   UserName   - String           - See Syntax Assistant.
//   RefreshReusableValues - Boolean - the flag that indicates whether to execute the method.
//
Procedure CommonSettingsStorageSave(ObjectKey, SettingsKey, Settings,
			SettingsDescription = Undefined,
			UserName = Undefined,
			RefreshReusableValues = False) Export
	
	StorageSave(CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		Settings,
		SettingsDescription,
		UserName,
		RefreshReusableValues);
	
EndProcedure

// Saves settings to the common settings storage as the Save method
// of StandardSettingsStorageManager or SettingsStorageManager.<Storage name>,
// object. Setting keys exceeding 128 characters are supported by hashing the key part
// that exceeds 96 characters.
// If the SaveUserData right is not granted, data save fails and no error is raised.
// 
// Parameters:
//   MultipleSettings - Array - with the following values:
//     * Value - Structure:
//         * Object    - String       - see the ObjectKey parameter in the Syntax Assistant.
//         * Setting - String       - see the SettingsKey parameter in the Syntax Assistant.
//         * Value  - Arbitrary - see the Settings parameter in the Syntax Assistant.
//
//   RefreshReusableValues - Boolean - the flag that indicates whether to execute the method.
//
Procedure CommonSettingsStorageSaveArray(MultipleSettings,
			RefreshReusableValues = False) Export
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	For Each Item In MultipleSettings Do
		CommonSettingsStorage.Save(Item.Object, SettingsKey(Item.Setting), Item.Value);
	EndDo;
	
	If RefreshReusableValues Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

// Imports the setting from the common settings storage as the Import method
// of the StandardSettingsStorageManager or SettingsStorageManager.<Storage name> objects.
// Setting keys exceeding 128 characters are supported by hashing the key part
// that exceeds 96 characters.
// Returns the specified default value if the settings do not exist.
// If the SaveUserData right is not granted, the default value is returned and no error is raised.
//
// The return value clears references to a non-existent object in the database, namely:
// - The returned reference is replaced with the default value.
// - The references are deleted from the data of the Array type.
// - The key is not changed for the data of the Structure or Map types, and the value is set to Undefined.
// - Recursive analysis of values in the data of the Array, Structure, Map types is carried out.
//
// Parameters:
//   ObjectKey          - String           - See Syntax Assistant.
//   SettingsKey         - String           - See Syntax Assistant.
//   DefaultValue  - Arbitrary     - the value that is returned if the settings do not exist.
//                                             If not specified, returns Undefined.
//   SettingsDescription     - SettingsDescription - See Syntax Assistant.
//   UserName      - String           - See Syntax Assistant.
//
// Returns: 
//   Arbitrary - See Syntax Assistant.
//
Function CommonSettingsStorageLoad(ObjectKey, SettingsKey, DefaultValue = Undefined, 
			SettingsDescription = Undefined, UserName = Undefined) Export
	
	Return StorageLoad(CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDescription,
		UserName);
	
EndFunction

// Removes a setting from the general settings storage as the Remove method,
// StandardSettingsStorageManager objects, or SettingsStorageManager.<Storage name>,
// The setting key supports more than 128 characters by hashing the part
// that exceeds 96 characters.
// If the SaveUserData right is not granted, no data is deleted and no error is raised.
//
// Parameters:
//   ObjectKey     - String
//                   - Undefined - See Syntax Assistant.
//   SettingsKey    - String
//                   - Undefined - See Syntax Assistant.
//   UserName - String
//                   - Undefined - See Syntax Assistant.
//
Procedure CommonSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	StorageDelete(CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		UserName);
	
EndProcedure

// Saves a setting to the system settings storage as the Save method
// of StandardSettingsStorageManager object. Setting keys
// exceeding 128 characters are supported by hashing the key part that exceeds 96 characters.
// If the SaveUserData right is not granted, data save fails and no error is raised.
//
// Parameters:
//   ObjectKey       - String           - See Syntax Assistant.
//   SettingsKey      - String           - See Syntax Assistant.
//   Settings         - Arbitrary     - See Syntax Assistant.
//   SettingsDescription  - SettingsDescription - See Syntax Assistant.
//   UserName   - String           - See Syntax Assistant.
//   RefreshReusableValues - Boolean - the flag that indicates whether to execute the method.
//
Procedure SystemSettingsStorageSave(ObjectKey, SettingsKey, Settings,
			SettingsDescription = Undefined,
			UserName = Undefined,
			RefreshReusableValues = False) Export
	
	StorageSave(SystemSettingsStorage, 
		ObjectKey,
		SettingsKey,
		Settings,
		SettingsDescription,
		UserName,
		RefreshReusableValues);
	
EndProcedure

// Imports settings from the system settings storage as the Import method
// of the StandardSettingsStorageManager object. Setting keys exceeding
// 128 characters are supported by hashing the key part that exceeds 96 characters.
// Returns the specified default value if the settings do not exist.
// If the SaveUserData right is not granted, the default value is returned and no error is raised.
//
// The return value clears references to a non-existent object in the database, namely:
// - The returned reference is replaced with the default value.
// - The references are deleted from the data of the Array type.
// - The key is not changed for the data of the Structure or Map types, and the value is set to Undefined.
// - Recursive analysis of values in the data of the Array, Structure, Map types is carried out.
//
// Parameters:
//   ObjectKey          - String           - See Syntax Assistant.
//   SettingsKey         - String           - See Syntax Assistant.
//   DefaultValue  - Arbitrary     - the value that is returned if the settings do not exist.
//                                             If not specified, returns Undefined.
//   SettingsDescription     - SettingsDescription - See Syntax Assistant.
//   UserName      - String           - See Syntax Assistant.
//
// Returns: 
//   Arbitrary - See Syntax Assistant.
//
Function SystemSettingsStorageLoad(ObjectKey, SettingsKey, DefaultValue = Undefined, 
			SettingsDescription = Undefined, UserName = Undefined) Export
	
	Return StorageLoad(SystemSettingsStorage,
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDescription,
		UserName);
	
EndFunction

// Removes a setting from the system settings storage as the Remove method
// or the StandardSettingsStorageManager object. The setting key supports
// more than 128 characters by hashing the part that exceeds 96 characters.
// If the SaveUserData right is not granted, no data is deleted and no error is raised.
//
// Parameters:
//   ObjectKey     - String
//                   - Undefined - See Syntax Assistant.
//   SettingsKey    - String
//                   - Undefined - See Syntax Assistant.
//   UserName - String
//                   - Undefined - See Syntax Assistant.
//
Procedure SystemSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	StorageDelete(SystemSettingsStorage,
		ObjectKey,
		SettingsKey,
		UserName);
	
EndProcedure

// Saves a setting to the form data settings storage as the Save method of
// StandardSettingsStorageManager or SettingsStorageManager.<Storage name>,
// object. Setting keys exceeding 128 characters are supported by hashing the key part
// that exceeds 96 characters.
// If the SaveUserData right is not granted, data save fails and no error is raised.
//
// Parameters:
//   ObjectKey       - String           - See Syntax Assistant.
//   SettingsKey      - String           - See Syntax Assistant.
//   Settings         - Arbitrary     - See Syntax Assistant.
//   SettingsDescription  - SettingsDescription - See Syntax Assistant.
//   UserName   - String           - See Syntax Assistant.
//   RefreshReusableValues - Boolean - the flag that indicates whether to execute the method.
//
Procedure FormDataSettingsStorageSave(ObjectKey, SettingsKey, Settings,
			SettingsDescription = Undefined,
			UserName = Undefined, 
			RefreshReusableValues = False) Export
	
	StorageSave(FormDataSettingsStorage,
		ObjectKey,
		SettingsKey,
		Settings,
		SettingsDescription,
		UserName,
		RefreshReusableValues);
	
EndProcedure

// Imports the setting from the common settings storage as the Import method
// of the StandardSettingsStorageManager or SettingsStorageManager.<Storage name> objects.
// Setting keys exceeding 128 characters are supported by hashing the key part
// that exceeds 96 characters.
// Returns the specified default value if the settings do not exist.
// If the SaveUserData right is not granted, the default value is returned and no error is raised.
//
// The return value clears references to a non-existent object in the database, namely:
// - The returned reference is replaced with the default value.
// - The references are deleted from the data of the Array type.
// - The key is not changed for the data of the Structure or Map types, and the value is set to Undefined.
// - Recursive analysis of values in the data of the Array, Structure, Map types is carried out.
//
// Parameters:
//   ObjectKey          - String           - See Syntax Assistant.
//   SettingsKey         - String           - See Syntax Assistant.
//   DefaultValue  - Arbitrary     - the value that is returned if the settings do not exist.
//                                             If not specified, returns Undefined.
//   SettingsDescription     - SettingsDescription - See Syntax Assistant.
//   UserName      - String           - See Syntax Assistant.
//
// Returns: 
//   Arbitrary - See Syntax Assistant.
//
Function FormDataSettingsStorageLoad(ObjectKey, SettingsKey, DefaultValue = Undefined, 
			SettingsDescription = Undefined, UserName = Undefined) Export
	
	Return StorageLoad(FormDataSettingsStorage,
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDescription, 
		UserName);
	
EndFunction

// Deletes the setting from the form data settings storage using the Delete method
// for StandardSettingsStorageManager or SettingsStorageManager.<Storage name>,
// objects. Setting keys exceeding 128 characters are supported by hashing the key part
// that exceeds 96 characters.
// If the SaveUserData right is not granted, no data is deleted and no error is raised.
//
// Parameters:
//   ObjectKey     - String
//                   - Undefined - See Syntax Assistant.
//   SettingsKey    - String
//                   - Undefined - See Syntax Assistant.
//   UserName - String
//                   - Undefined - See Syntax Assistant.
//
Procedure FormDataSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	StorageDelete(FormDataSettingsStorage,
		ObjectKey,
		SettingsKey,
		UserName);
	
EndProcedure

#EndRegion

#Region XMLSerialization

// Converts (serializes) a value into an XML string.
// Supports only serializable objects (for details, see Syntax Assistant).
// See also: ValueFromXMLString.
//
// Parameters:
//  Value - Arbitrary - a value to serialize into an XML string.
//
// Returns:
//  String - an XML string.
//
Function ValueToXMLString(Value) Export
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XDTOSerializer.WriteXML(XMLWriter, Value, XMLTypeAssignment.Explicit);
	
	Return XMLWriter.Close();
EndFunction

// Converts (deserializes) an XML string into a value.
// See also: ValueToXMLString.
//
// Parameters:
//  XMLLine - String - an XML string with a serialized object..
//
// Returns:
//  Arbitrary - value extracted from a passed XML string.
//
Function ValueFromXMLString(XMLLine) Export
	
	XMLReader = New XMLReader;
	XMLReader.SetString(XMLLine);
	
	Return XDTOSerializer.ReadXML(XMLReader);
EndFunction

// Returns an XML presentation of the XDTO object.
//
// Parameters:
//  XDTODataObject - XDTODataObject  - an object that requires XML presentation to be generated.
//  Factory    - XDTOFactory - the factory used for generating the XML presentation.
//                             If the parameter is not specified, the global XDTO factory is used.
//
// Returns: 
//   String - the XML presentation of the XDTO object.
//
Function XDTODataObjectToXMLString(Val XDTODataObject, Val Factory = Undefined) Export
	
	XDTODataObject.Validate();
	
	If Factory = Undefined Then
		Factory = XDTOFactory;
	EndIf;
	
	Record = New XMLWriter();
	Record.SetString();
	Factory.WriteXML(Record, XDTODataObject, , , , XMLTypeAssignment.Explicit);
	
	Return Record.Close();
	
EndFunction

// Generates an XDTO object by the XML presentation.
//
// Parameters:
//  XMLLine - String    - the XML presentation of the XDTO object,
//  Factory - XDTOFactory - the factory used for generating the XDTO object.
//                          If the parameter is not specified, the global XDTO factory is used.
//
// Returns: 
//  XDTODataObject - an XDTO object.
//
Function XDTODataObjectFromXMLString(Val XMLLine, Val Factory = Undefined) Export
	
	If Factory = Undefined Then
		Factory = XDTOFactory;
	EndIf;
	
	Read = New XMLReader();
	Read.SetString(XMLLine);
	
	Return Factory.ReadXML(Read);
	
EndFunction

#EndRegion

#Region JSONSerialization

// Converts a value into a JSON string using the WriteJSON global context method.
// Some data types are not supported. For details, see Syntax Assistant.
// Converts dates to the ISO format (YYYY-MM-DDThh:mm:ssZ).
// 
// Parameters:
//  Value - Arbitrary
//
// Returns:
//  String
//
Function ValueToJSON(Val Value) Export
	
	JSONWriter = New JSONWriter;
	JSONWriter.SetString();
	WriteJSON(JSONWriter, Value);
	
	Return JSONWriter.Close();
	
EndFunction

// Converts a JSON string into a value using the ReadJSON global context method.
// For the limitation details, see Syntax Assistant.
// By default, casts JSON objects into Map. 
// The conversion requires that you explicitly specified Date-type properties.
// The expected format date is ISO (YYYY-MM-DDThh:mm:ssZ).
// 
// Parameters:
//   String - String - JSON value.
//   PropertiesWithDateValuesNames - String - Name of the Date-type property, or comma-delimited list of properties.
//                                           
//                                - Array of String 
//   ReadToMap       - Boolean - If False, JSON objects will be converted to Structure.
//   
// Returns:
//  Arbitrary
//
Function JSONValue(Val String, Val PropertiesWithDateValuesNames = Undefined, Val ReadToMap = True) Export
	
	If TypeOf(PropertiesWithDateValuesNames) = Type("String") Then
		PropertiesWithDateValuesNames = StrSplit(PropertiesWithDateValuesNames, ", " + Chars.LF, False);
	EndIf;
	
	JSONReader = New JSONReader;
	JSONReader.SetString(String);
	
	Return ReadJSON(JSONReader, ReadToMap, PropertiesWithDateValuesNames);
	
EndFunction

#EndRegion

#Region WebServices

// Returns a parameter structure for the CreateWSProxy function.
//
// Returns:
//   See CreateWSProxy.WSProxyConnectionParameters
//
Function WSProxyConnectionParameters() Export
	Result = New Structure;
	Result.Insert("WSDLAddress");
	Result.Insert("NamespaceURI");
	Result.Insert("ServiceName");
	Result.Insert("EndpointName", "");
	Result.Insert("UserName");
	Result.Insert("Password");
	Result.Insert("Timeout", 0);
	Result.Insert("Location");
	Result.Insert("UseOSAuthentication", False);
	Result.Insert("ProbingCallRequired", False);
	Result.Insert("SecureConnection", Undefined);
	Result.Insert("IsPackageDeliveryCheckOnErrorEnabled", True);
	Return Result;
EndFunction

// Constructor of the WSProxy object. Compared to New WSProxy constructor has the following advanced features:
//  - Creates WSDefinitions.
//  - Caches WSDL file to speed up the web service.
//  - InternetProxy is not required (used automatically if configured).
//  - Can quickly check the server availability with the "Ping" command.
//
// Parameters:
//  WSProxyConnectionParameters - Structure:
//   * WSDLAddress                    - String - Location of wsdl. For example, "http://webservice.net/webservice.asmx?wsdl".
//   * NamespaceURI          - String - Web service namespace URI. For example, "http://www.webservice.net/WebService/1.0.0.1".
//   * ServiceName                   - String - Service name. For example, "WebService_1_0_0_1".
//   * EndpointName          - String - Optional. If not specified, it is generated by mask <ServiceName>Soap.
//   * UserName              - String - Optional. Server authentication username.
//   * Password                       - String - Optional. A user password.
//   * Timeout                      - Number  - Optional. Timeout for web service operation running via a proxy, in seconds. 
//                                              
//   * Location               - String - Optional. The actual service address.
//                                             Used if the actual server address does not match the WSDL file address.
//                                             
//   * UseOSAuthentication - Boolean - Optional. Enables NTLM or Negotiate authentication on the server. 
//                                             
//   * ProbingCallRequired       - Boolean - Optional. Check service availability. 
//                                             Requires the support of the "Ping" command. By default, False.
//   * SecureConnection         - OpenSSLSecureConnection
//                                  - Undefined - Optional secured connection parameters.
//   * IsPackageDeliveryCheckOnErrorEnabled - See GetFilesFromInternet.ConnectionDiagnostics.IsPackageDeliveryCheckEnabled.
//
// Returns:
//  WSProxy
//
// Example:
//	ConnectionParameters = Common.WSProxyConnectionParameters();
//	ConnectionParameters.WSDLAddress = "http://webservice.net/webservice.asmx?wsdl";
//	ConnectionParameters.NamespaceURI = "http://www.webservice.net/WebService/1.0.0.1";
//	ConnectionParameters.ServiceName = "WebService_1_0_0_1";
//	ConnectionParameters.Timeout = 20;
//	Proxy = Common.CreateWSProxy(ConnectionParameters);
//
Function CreateWSProxy(Val WSProxyConnectionParameters) Export
	
	CommonClientServer.CheckParameter("CreateWSProxy", "Parameters", WSProxyConnectionParameters, Type("Structure"),
		New Structure("WSDLAddress,NamespaceURI,ServiceName", Type("String"), Type("String"), Type("String")));
		
	ConnectionParameters = WSProxyConnectionParameters();
	FillPropertyValues(ConnectionParameters, WSProxyConnectionParameters);
	
	ProbingCallRequired = ConnectionParameters.ProbingCallRequired;
	Timeout = ConnectionParameters.Timeout;
	
	If ProbingCallRequired And Timeout <> Undefined And Timeout > 20 Then
		ConnectionParameters.Timeout = 7;
		WSProxyPing = InformationRegisters.ProgramInterfaceCache.InnerWSProxy(ConnectionParameters);
		Try
			WSProxyPing.Ping();
		Except
			EndpointAddress = WSProxyPing.Endpoint.Location;
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot check availability of the web service
				           |%1.
				           |Reason:
				           |%2.';"),
				ConnectionParameters.WSDLAddress,
				ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			
			If SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
				ModuleNetworkDownload = CommonModule("GetFilesFromInternet");
				DiagnosticsResult = ModuleNetworkDownload.ConnectionDiagnostics(EndpointAddress,,
					ConnectionParameters.IsPackageDeliveryCheckOnErrorEnabled);
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1
					           |Diagnostics result:
					           |%2';"),
					ErrorText,
					DiagnosticsResult.ErrorDescription);
			EndIf;
			
			Raise(ErrorText, ErrorCategory.NetworkError);
		EndTry;
		ConnectionParameters.Timeout = Timeout;
	EndIf;
	
	Return InformationRegisters.ProgramInterfaceCache.InnerWSProxy(ConnectionParameters);
	
EndFunction

/////////////////////////////////////////////////////////////////////////////////
// API versioning.

// Returns version numbers of interfaces in a remote system accessed over web service.
// Ensures full backwards compatibility against any API modifications,
// based on explicit versioning. For example, you could specify that a new function is only available if the API used is later than
// a specific version.
//
// For traffic economy purposes, API version 
// information is cached daily when under heavy traffic conditions. To clear the cache before the daily timeout,
// delete the corresponding records from the ProgramInterfaceCache information register.
//
// Parameters:
//  Address        - String - address of InterfaceVersion web service;
//  User - String - name of a web service user;
//  Password       - String - password of a web service user;
//  Interface    - String - name of the queried interface. Example: "FileTransferService";
//  IsPackageDeliveryCheckOnErrorEnabled - See GetFilesFromInternet.ConnectionDiagnostics.IsPackageDeliveryCheckEnabled
//
// Returns:
//   FixedArray - array of strings where each string contains a presentation of an interface version number. 
//                         Example: "1.0.2.1".
//
// Example:
//	  Versions = GetInterfaceVersions("http://vsrvx/sm", "smith",, "FileTransferService");
//
//    The obsolete option is also supported for backward compatibility reason:
//	  ConnectionParameters = New Structure;
//	  ConnectionParameters.Insert("URL", "http://vsrvx/sm");
//	  ConnectionParameters.Insert("UserName", "smith");
//	  ConnectionParameters.Insert("Password", "");
//	  Versions = GetInterfaceVersions(ConnectionParameters, "FileTransferService");
//
Function GetInterfaceVersions(Val Address, Val User, Val Password = Undefined, 
	Val Interface = Undefined, Val IsPackageDeliveryCheckOnErrorEnabled = True) Export
	
	If TypeOf(Address) = Type("Structure") Then // For backward compatibility purposes.
		ConnectionParameters = Address;
		InterfaceName = User;
	Else
		ConnectionParameters = New Structure;
		ConnectionParameters.Insert("URL", Address);
		ConnectionParameters.Insert("UserName", User);
		ConnectionParameters.Insert("Password", Password);
		InterfaceName = Interface;
	EndIf;
	
	ConnectionParameters.Insert("IsPackageDeliveryCheckOnErrorEnabled", IsPackageDeliveryCheckOnErrorEnabled);
	
	If Not ConnectionParameters.Property("URL") 
		Or Not ValueIsFilled(ConnectionParameters.URL) Then
		
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of parameter ""%1"" in function ""%2"". Service URL is not specified.';"), 
			"ConnectionParameters", "Common.GetInterfaceVersions"), ErrorCategory.ConfigurationError);
	EndIf;
	
	ReceivingParameters = New Array;
	ReceivingParameters.Add(ConnectionParameters);
	ReceivingParameters.Add(InterfaceName);
	
	Return InformationRegisters.ProgramInterfaceCache.VersionCacheData(
		InformationRegisters.ProgramInterfaceCache.VersionCacheRecordID(ConnectionParameters.URL, InterfaceName), 
		Enums.APICacheDataTypes.InterfaceVersions, 
		ReceivingParameters,
		True);
	
EndFunction

// Returns version numbers of interfaces in a remote system accessed over external connection.
// Ensures full backwards compatibility against any API modifications,
// based on explicit versioning. For example, you could specify that a new function is only available if the API used is later than
// a specific version.
//
// Parameters:
//   ExternalConnection - COMObject - an external connection used to access a remote system.
//   InterfaceName     - String    - name of the queried interface, for example: FileTransferService.
//
// Returns:
//   FixedArray - array of strings where each string contains a presentation of an interface version number. 
//                         For example: "1.0.2.1".
//
// Example:
//  Versions = Common.GetInterfaceVersionsViaExternalConnection(ExternalConnection, "FileTransferService");
//
Function GetInterfaceVersionsViaExternalConnection(ExternalConnection, Val InterfaceName) Export
	Try
		XMLInterfaceVersions = ExternalConnection.StandardSubsystemsServer.SupportedVersions(InterfaceName);
	Except
		MessageString = NStr("en = 'The peer infobase does not support application interface versioning.
			|Error details: %1';");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		WriteLogEvent(NStr("en = 'Getting interface versions';", DefaultLanguageCode()),
			EventLogLevel.Error, , , MessageString);
		
		Return New FixedArray(New Array);
	EndTry;
	
	Return New FixedArray(ValueFromXMLString(XMLInterfaceVersions));
EndFunction

// Deletes records from cache of interface versions that contain the specified substring in their IDs. 
// For example, a name of obsolete interface can be specified as the substring.
//
// Parameters:
//  IDSearchSubstring - String - ID search substring. 
//                                            Cannot contain the following characters: % _ [.
//
Procedure DeleteVersionCacheRecords(Val IDSearchSubstring) Export
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		Block.Add("InformationRegister.ProgramInterfaceCache");
		Block.Lock();
		
		QueryText =
			"SELECT
			|	CacheTable.Id AS Id,
			|	CacheTable.DataType AS DataType
			|FROM
			|	InformationRegister.ProgramInterfaceCache AS CacheTable
			|WHERE
			|	CacheTable.Id LIKE ""%SearchSubstring%"" ESCAPE ""~""";
		
		QueryText = StrReplace(QueryText, "SearchSubstring", 
			GenerateSearchQueryString(IDSearchSubstring));
		Query = New Query(QueryText);
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			Record = InformationRegisters.ProgramInterfaceCache.CreateRecordManager();
			Record.Id = Selection.Id;
			Record.DataType = Selection.DataType;
			Record.Delete();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#Region SecureStorage

////////////////////////////////////////////////////////////////////////////////
// Password storage management procedures and functions.

// Writes confidential data to a secure storage.
// The calling script must enable privileged mode.
//
// Users (except administrators) cannot read data from the secure storage.
// The code can only read the data related to it, and
// only in context of confidential data reading and writing.
//
// Parameters:
//  Owner - ExchangePlanRef
//           - CatalogRef
//           - String - Reference to the infobase object
//             representing the object that owns the password, or a string containing up to 128 characters.
//             For objects of other types, use a reference to
//             metadata item of that kind in the MetadataObjectIDs catalog
//             or a string key accounting to subsystem names as owner.
//             For SSL, the code looks as follows::
//               Owner = Common.MetadataObjectID("InformationRegister.AddressObjects");
//             If one storage is enough for SSL subsystem:
//               Owner = "StandardSubsystems.AccessManagement";
//             If multiple storages are required for SSL subsystem:
//               Owner = "StandardSubsystems.AccessManagement.<Clarification>";
//  Data  - Arbitrary - data to save to the secure storage. Undefined - deletes all data.
//            To delete data by key, use the DeleteDataFromSecureStorage procedure instead.
//          - Structure - If the "Key" parameters is assigned "Undefined". For details, see the "Key" parameter details.
//  Var_Key    - String       - Key of the settings to be saved. By default, "Password".
//                           The key must comply with the identifier naming conventions.:
//                           1. An identifier name must start with a letter or underscore ( _ ).
//                           2. The following characters are alphanumeric and underscores. 
//            Undefined - If you add a dataset as Structure.
//            Key - Data key name. Value - Data to be saved. See use cases below.
//
// Example:
//
//  Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
//      If CurrentUserCanChangePassword Then
//          SetPrivilegedMode(True);
//          Common.WriteDataToSecureStorage(CurrentObject.Ref, Login, "Login");
//          Common.WriteDataToSecureStorage(CurrentObject.Ref, Password);
//          SetPrivilegedMode(False);
//      EndIf;
//  EndProcedure
// 
//  Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
//      If CurrentUserCanChangePassword Then
//          LoginAndPassword = New Structure;
//          LoginAndPassword .Insert("Login", Login);
//          LoginAndPassword .Insert("Password", Password);
//          SetPrivilegedMode(True);
//          Common.WriteDataToSecureStorage(CurrentObject.Ref, LoginAndPassword, Undefined);
//          SetPrivilegedMode(False);
//      EndIf;
//  EndProcedure
//
Procedure WriteDataToSecureStorage(Owner, Data, Var_Key = "Password") Export
	
	CommonClientServer.Validate(ValueIsFilled(Owner),
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of the %1 parameter in %2.
			           |The parameter must contain a reference. The passed value is %3 (type: %4).';"),
			"Owner", "Common.WriteDataToSecureStorage", Owner, TypeOf(Owner)));
			
	If ValueIsFilled(Var_Key) Then
		
		CommonClientServer.Validate(TypeOf(Var_Key) = Type("String"),
			StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of the %1 parameter in %2.
			|The parameter must contain a string. The passed value is %3 (type: %4).';"),
			"Key", "Common.WriteDataToSecureStorage", Var_Key, TypeOf(Var_Key))); 
			
	Else
		
		CommonClientServer.Validate(TypeOf(Data) = Type("Structure"),
			StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of the %1 parameter in %2.
			|If Key = Undefined, the parameter must contain a structure. The passed value is %3 (type: %4).';"),
			"Data", "Common.WriteDataToSecureStorage", Data, TypeOf(Data)));
		
	EndIf;
	
	IsDataArea = DataSeparationEnabled() And SeparatedDataUsageAvailable();
	If IsDataArea Then
		SafeDataStorage = InformationRegisters.SafeDataAreaDataStorage.CreateRecordManager();
	Else
		SafeDataStorage = InformationRegisters.SafeDataStorage.CreateRecordManager();
	EndIf;
	
	SafeDataStorage.Owner = Owner;
	SafeDataStorage.Read();
	
	If Data <> Undefined Then
		
		If SafeDataStorage.Selected() Then
			
			DataToSave = SafeDataStorage.Data.Get();
			
			If TypeOf(DataToSave) <> Type("Structure") Then
				DataToSave = New Structure();
			EndIf;
			
			If ValueIsFilled(Var_Key) Then
				DataToSave.Insert(Var_Key, Data);
			Else
				CommonClientServer.SupplementStructure(DataToSave, Data, True);
			EndIf;
			
			DataForValueStorage = New ValueStorage(DataToSave, New Deflation(6));
			SafeDataStorage.Data = DataForValueStorage;
			SafeDataStorage.Write();
			
		Else
			
			DataToSave = ?(ValueIsFilled(Var_Key), New Structure(Var_Key, Data), Data);
			DataForValueStorage = New ValueStorage(DataToSave, New Deflation(6));
			
			SafeDataStorage.Data = DataForValueStorage;
			SafeDataStorage.Owner = Owner;
			SafeDataStorage.Write();
			
		EndIf;
	Else
		
		SafeDataStorage.Delete();
		
	EndIf;
	
EndProcedure

// Retrieves data from a secure storage.
// The calling script must enable privileged mode.
//
// Users (except administrators)
// cannot read data from the secure storage. The code can only read the data related to it, and
// only in context of confidential data reading and writing.
//
// Parameters:
//  Owners   - Array of ExchangePlanRef
//              - Array of CatalogRef
//              - Array of String - References to infobase objects,
//                  which are either owners or unique strings (up to 128 characters) containing owner's data.
//  Keys       - String - Contains data key name or a list of comma-delimited names.
//              - Undefined - Return all saved data for the passed owners. 
//  SharedData - Boolean - True if getting data from shared data in separated mode in SaaS.
// 
// Returns:
//  Map of KeyAndValue:
//    * Key - ExchangePlanRef
//           - CatalogRef
//           - String - Reference to the infobase object, 
//                      or a string (up to 128 characters), which identifies the data owner.
//    * Value - Arbitrary - If the Keys parameter contains only one key, 
//                                return its value of an arbitrary type.
//               - Structure    - If the Keys parameter contains multiple keys or Undefined. 
//                                (Key - Saved data key. Value - Arbitrary type value.) 
//                                If all the keys have no matching data, the value is "Undefined". 
//                                
//               - Undefined - If the key has no matching data.
//
// Example:
//	Procedure DistributeInvitations(Users)
//		
//			SetPrivilegedMode(True);
//			AuthorizationData = Common.ReadDataFromSecureStorage(Users, "Username, Password");
//			SetPrivilegedMode(False);
//			
//			For Each User From Users Do
//				DistributeInvitations(User, AuthorizationData[User]);
//			EndDo;
//		
//	EndProcedure
//
Function ReadOwnersDataFromSecureStorage(Owners, Keys = "Password", SharedData = Undefined) Export
	
	CommonClientServer.Validate(TypeOf(Owners) = Type("Array"),
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of the %1 parameter in %2.
			           |The parameter must contain an array. The passed value is %3 (type: %4).';"),
			"Owners", "Common.ReadDataFromSecureStorage", Owners, TypeOf(Owners)));
	
	Result = DataFromSecureStorage(Owners, Keys, SharedData);
	
	Return Result;
	
EndFunction

// Retrieves data from a secure storage.
// The calling script must enable privileged mode.
//
// Users (except administrators)
// cannot read data from the secure storage. The code can only read the data related to it, and
// only in context of confidential data reading and writing.
//
// Parameters:
//  Owner    - ExchangePlanRef
//              - CatalogRef
//              - String - Reference to the infobase object,
//                  or a unique string (up to 128 characters), which identifies the data owner.
//  Keys       - String - contains a comma-separated list of saved data item names.
//              - Undefined - Return all saved data for the passed owner.
//  SharedData - Boolean - True if getting data from shared data in separated mode in SaaS.
// 
// Returns:
//  Arbitrary, Structure, Undefined - data from the secure storage. If single key is specified,
//                            its value is returned, otherwise a structure is returned.
//                            If no data is available - Undefined.
//
// Example:
//	If CurrentUserCanChangePassword Then
//		SetPrivilegedMode(True);
//		Login = Common.ReadDataFromSecureStorage(CurrentObject.Ref, "Login");
//		Password = Common.ReadDataFromSecureStorage(CurrentObject.Ref);
//		SetPrivilegedMode(False);
//	Else
//		Items.UsernameAndPasswordGroup.Visible = False;
//	EndIf;
//	
//	SetPrivilegedMode(True);
//	LoginAndPassword = Common.ReadDataFromSecureStorage(CurrentObject.Ref, Undefined);
//
Function ReadDataFromSecureStorage(Owner, Keys = "Password", SharedData = Undefined) Export
	
	Owners = CommonClientServer.ValueInArray(Owner);
	OwnerData = ReadOwnersDataFromSecureStorage(Owners, Keys, SharedData);
	
	Result = OwnerData[Owner];
	
	Return Result;
	
EndFunction

// Deletes confidential data from a secure storage.
// The calling script must enable privileged mode.
//
// Users (except administrators) cannot read data from the secure storage.
// The code can only read the data related to it, and
// only in context of confidential data reading and writing.
//
// Parameters:
//  Owner - ExchangePlanRef
//           - CatalogRef
//           - String - Reference to the infobase object,
//               or a unique string (up to 128 characters), which identifies the data owner.
//           - Array - Infobase object references used to delete data for multiple owners.
//  Keys    - String - contains a comma-separated list of deleted data item names. 
//               Undefined - deletes all data.
//
// Example:
//	Procedure beforeDelete(Cancel)
//		
//		// Skipping the DataExchange.Import property check because it is necessary to delete data
//		// from the secure storage even if the object is deleted during data exchange.
//		
//		SetPrivilegedMode(True);
//		Common.DeleteDataFromSecureStorage(Ref);
//		SetPrivilegedMode(False);
//		
//	EndProcedure
//
Procedure DeleteDataFromSecureStorage(Owner, Keys = Undefined) Export
	
	CommonClientServer.Validate(ValueIsFilled(Owner),
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of the %1 parameter in %2.
			           |The parameter must contain a reference. The passed value is %3 (type: %4).';"),
			"Owner", "Common.DeleteDataFromSecureStorage", Owner, TypeOf(Owner)));
	
	If DataSeparationEnabled() And SeparatedDataUsageAvailable() Then
		SafeDataStorage = InformationRegisters.SafeDataAreaDataStorage.CreateRecordManager();
	Else
		SafeDataStorage = InformationRegisters.SafeDataStorage.CreateRecordManager();
	EndIf;  
	
	Owners = ?(TypeOf(Owner) = Type("Array"), Owner, CommonClientServer.ValueInArray(Owner));
	
	For Each DataOwner In Owners Do
		
		SafeDataStorage.Owner = DataOwner;
		SafeDataStorage.Read();
		If TypeOf(SafeDataStorage.Data) = Type("ValueStorage") Then
			DataToSave = SafeDataStorage.Data.Get();
			If Keys <> Undefined And TypeOf(DataToSave) = Type("Structure") Then
				KeysList = StrSplit(Keys, ",", False);
				If SafeDataStorage.Selected() And KeysList.Count() > 0 Then
					For Each KeyToDelete In KeysList Do
						If DataToSave.Property(KeyToDelete) Then
							DataToSave.Delete(KeyToDelete);
						EndIf;
					EndDo;
					DataForValueStorage = New ValueStorage(DataToSave, New Deflation(6));
					SafeDataStorage.Data = DataForValueStorage;
					SafeDataStorage.Write();
					Return;
				EndIf;
			EndIf;
		EndIf;
		
		SafeDataStorage.Delete();
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Clipboard

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for internal clipboard management.

// Copies the selected tabular section rows to the internal clipboard
// so that they can be retrieved using RowsFromClipboard.
//
// Parameters:
//  TabularSection   - FormDataCollection - a tabular section whose rows
//                                            need to be placed to the internal clipboard.
//  SelectedRows - Array - an array of IDs for selected rows.
//  Source         - String - an arbitrary string ID (for example, name of the object
//                              whose tabular section rows are to be copied to the internal clipboard).
//
Procedure CopyRowsToClipboard(TabularSection, SelectedRows, Source = Undefined) Export
	
	If SelectedRows = Undefined Then
		Return;
	EndIf;
	
	ValueTable = TabularSection.Unload();
	ValueTable.Clear();
	
	ColumnsToDelete = New Array;
	ColumnsToDelete.Add("SourceLineNumber");
	ColumnsToDelete.Add("LineNumber");
	
	For Each ColumnName In ColumnsToDelete Do
		Column = ValueTable.Columns.Find(ColumnName);
		If Column = Undefined Then
			Continue;
		EndIf;
		
		ValueTable.Columns.Delete(Column);
	EndDo;
	
	For Each RowID In SelectedRows Do
		RowToCopy = TabularSection.FindByID(RowID);
		FillPropertyValues(ValueTable.Add(), RowToCopy);
	EndDo;
	
	CopyToClipboard(ValueTable, Source);
	
EndProcedure

// Copies temporary data to the clipboard. To get the data, use RowsFromClipboard.
//
// Parameters:
//  Data           - Arbitrary - the data to be copied to the clipboard.
//  Source         - String       - an arbitrary string ID (for example, name of the object
//                                    whose tabular section rows are to be copied to the internal clipboard).
//
Procedure CopyToClipboard(Data, Source = Undefined) Export
	
	CurrentClipboard = SessionParameters.Clipboard;
	
	If ValueIsFilled(CurrentClipboard.Data) Then
		Address = CurrentClipboard.Data;
	Else
		Address = New UUID;
	EndIf;
	
	DataToStorage = PutToTempStorage(Data, Address);
	
	ClipboardStructure = New Structure;
	ClipboardStructure.Insert("Source", Source);
	ClipboardStructure.Insert("Data", DataToStorage);
	
	SessionParameters.Clipboard = New FixedStructure(ClipboardStructure);
	
EndProcedure

// Gets the tabular section rows that were copied to the clipboard with CopyRowsToClipboard.
//
// Returns:
//  Structure:
//     * Data   - Arbitrary - data retrieved from the internal clipboard.
//                                 For example, ValueTable when calling CopyRowsToClipboard.
//     * Source - String       - the object related to the data.
//                                 Undefined if it was not specified in the data copied to the clipboard.
//
Function RowsFromClipboard() Export
	
	Result = New Structure;
	Result.Insert("Source", Undefined);
	Result.Insert("Data", Undefined);
	
	If EmptyClipboard() Then
		Return Result;
	EndIf;
	
	CurrentClipboard = SessionParameters.Clipboard; // See RowsFromClipboard
	Result.Source = CurrentClipboard.Source;
	Result.Data = GetFromTempStorage(CurrentClipboard.Data);
	
	Return Result;
EndFunction

// Checks whether the clipboard has any data saved.
//
// Parameters:
//  Source - String - If this parameter is passed, a check is made to determine whether
//             the internal clipboard with this key contains data.
//             The default value is Undefined.
// Returns:
//  Boolean - True if empty.
//
Function EmptyClipboard(Source = Undefined) Export
	
	CurrentClipboard = SessionParameters.Clipboard; // See RowsFromClipboard
	SourceIdentical = True;
	If Source <> Undefined Then
		SourceIdentical = (Source = CurrentClipboard.Source);
	EndIf;
	Return (Not SourceIdentical Or Not ValueIsFilled(CurrentClipboard.Data));
	
EndFunction

#EndRegion

#Region ExternalCodeSecureExecution

////////////////////////////////////////////////////////////////////////////////
// Functions that provide support of security profiles that
// restrict attaching external modules in unsafe mode.
//

// Executes the export procedure by the name with the configuration privilege level.
// To enable the security profile for calling the Execute() operator, the safe mode with the security profile of the infobase
// is used
// (if no other safe mode was set in stack previously).
//
// Parameters:
//  MethodName  - String - the name of the export procedure in format
//                       <object name>.<procedure name>, where <object name> - is
//                       a common module or object manager module.
//  Parameters  - Array - the parameters are passed to <ExportProcedureName>
//                        according to the array item order.
// 
// Example:
//  Parameters = New Array();
//  Parameters.Add("1");
//  Common.ExecuteConfigurationMethod("MyCommonModule.MyProcedure", Parameters);
//
Procedure ExecuteConfigurationMethod(Val MethodName, Val Parameters = Undefined) Export
	
	CheckConfigurationProcedureName(MethodName);
	
	If SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = CommonModule("SafeModeManager");
		If ModuleSafeModeManager.UseSecurityProfiles()
			And Not ModuleSafeModeManager.SafeModeSet() Then
			
			InfobaseProfile = ModuleSafeModeManager.InfobaseSecurityProfile();
			If ValueIsFilled(InfobaseProfile) Then
				
				SetSafeMode(InfobaseProfile);
				If SafeMode() = True Then
					SetSafeMode(False);
				EndIf;
				
			EndIf;
			
		EndIf;
	EndIf;
	
	ParametersString = "";
	If Parameters <> Undefined And Parameters.Count() > 0 Then
		For IndexOf = 0 To Parameters.UBound() Do 
			ParametersString = ParametersString + "Parameters[" + XMLString(IndexOf) + "],";
		EndDo;
		ParametersString = Mid(ParametersString, 1, StrLen(ParametersString) - 1);
	EndIf;
	
	Execute MethodName + "(" + ParametersString + ")";
	
EndProcedure

// Executes the export procedure of the 1C:Enterprise language object by name.
// To enable the security profile for calling the Execute() operator, the safe mode with the security profile of the infobase
// is used
// (if no other safe mode was set in stack previously).
//
// Parameters:
//  Object    - Arbitrary - 1C:Enterprise language object that contains the methods (for example, DataProcessorObject).
//  MethodName - String       - the name of export procedure of the data processor object module.
//  Parameters - Array       - the parameters are passed to <ProcedureName>
//                             according to the array item order.
//
Procedure ExecuteObjectMethod(Val Object, Val MethodName, Val Parameters = Undefined) Export
	
	// Method name validation.
	Try
		Test = New Structure(MethodName, MethodName);
		If Test = Undefined Then 
			Raise NStr("en = 'Method name validation.';");
		EndIf;
	Except
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of the %1 parameter in %3: %2.';"), 
				"MethodName", MethodName, "Common.ExecuteObjectMethod"),
			ErrorCategory.ConfigurationError);
	EndTry;
	
	If SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = CommonModule("SafeModeManager");
		If ModuleSafeModeManager.UseSecurityProfiles()
			And Not ModuleSafeModeManager.SafeModeSet() Then
			
			ModuleSafeModeManager = CommonModule("SafeModeManager");
			InfobaseProfile = ModuleSafeModeManager.InfobaseSecurityProfile();
			
			If ValueIsFilled(InfobaseProfile) Then
				
				SetSafeMode(InfobaseProfile);
				If SafeMode() = True Then
					SetSafeMode(False);
				EndIf;
				
			EndIf;
			
		EndIf;
	EndIf;
	
	ParametersString = "";
	If Parameters <> Undefined And Parameters.Count() > 0 Then
		For IndexOf = 0 To Parameters.UBound() Do 
			ParametersString = ParametersString + "Parameters[" + XMLString(IndexOf) + "],";
		EndDo;
		ParametersString = Mid(ParametersString, 1, StrLen(ParametersString) - 1);
	EndIf;
	
	Execute "Object." + MethodName + "(" + ParametersString + ")";
	
EndProcedure

// Executes any algorithm written in 1C:Enterprise language after setting
// the script execution safe mode and date separation safe mode for
// all separators within the configuration.
// 
// Also, the following restrictions are applied to the executable code:
// 
// 1. The code cannot call the following methods:
//   - Execute
//   - Eval
//   - CommitTransaction
//   - TruncateEventLog
//   - SetEventLogEventUse
//   - RunApp
//
// 2. The code cannot call the global context common modules and context:
//   - TimeConsumingOperations
//   - InfoBaseUsers
//
// Parameters:
//  Algorithm  - String - the algorithm in the 1C:Enterprise language.
//  Parameters - Arbitrary -  the algorithm context.
//    To address the context in the algorithm text, use "Parameters" name.
//    For example, expression "Parameters.Value1 = Parameters.Value2" addresses values
//    Value1 and Value2 that were passed to Parameters as properties.
//
// Example:
//
//  Parameters = New Structure;
//  Parameters.Insert("Value1", 1);
//  Parameters.Insert("Value2", 10);
//  Common.ExecuteInSafeMode("Parameters.Value1 = Parameters.Value2", Parameters);
//
Procedure ExecuteInSafeMode(Val Algorithm, Val Parameters = Undefined) Export
	
	CheckAlgorithm(Algorithm);
	
	SetSafeMode(True);
	
	If SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = CommonModule("SaaSOperations");
		SeparatorArray = ModuleSaaSOperations.ConfigurationSeparators();
	Else
		SeparatorArray = New Array;
	EndIf;
	
	For Each SeparatorName In SeparatorArray Do
		
		SetDataSeparationSafeMode(SeparatorName, True);
		
	EndDo;
	
	Try
		If TransactionActive() Then
			Execute Algorithm;
		Else
			BeginTransaction();
			Try
				Execute Algorithm;
				RollbackTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
		EndIf;
	Except
		ErrorInfo = ErrorInfo();
		Refinement = CommonClientServer.ExceptionClarification(ErrorInfo);
		Raise(Refinement.Text, ErrorCategory.ExternalDataSourceError ,,, ErrorInfo);
	EndTry;
	
EndProcedure

// Calculates the passed expression after setting the script execution
// safe mode and date separation safe mode for all separators within the configuration.
//
// Also, the following restrictions are applied to the executable code:
// 
// 1. The code cannot call the following methods:
//   - Execute
//   - Eval
//   - CommitTransaction
//   - TruncateEventLog
//   - SetEventLogEventUse
//   - RunApp
//
// 2. The code cannot call the global context common modules and context:
//   - TimeConsumingOperations
//   - InfoBaseUsers
//
// Parameters:
//  Expression - String - an expression in the 1C:Enterprise language.
//  Parameters - Arbitrary - the context required to calculate the expression.
//    To address the context in the expression text, use "Parameters" name.
//    For example, expression "Parameters.Value1 = Parameters.Value2" addresses values
//    Value1 and Value2 that were passed to Parameters as properties.
//
// Returns:
//   Arbitrary - the result of the expression calculation.
//
// Example:
//
//  // Example 1
//  Parameters = New Structure;
//  Parameters.Insert("Value1", 1);
//  Parameters.Insert("Value2", 10);
//  Result = Common.ExecuteInSafeMode("Parameters.Value1 = Parameters.Value2", Parameters);
//
//  // Example 2
//  Result = Common.ExecuteInSafeMode("StandardSubsystemsServer.LibraryVersion()");
//
Function CalculateInSafeMode(Val Expression, Val Parameters = Undefined) Export
	
	CheckAlgorithm(Expression);
	
	SetSafeMode(True);
	
	If SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = CommonModule("SaaSOperations");
		SeparatorArray = ModuleSaaSOperations.ConfigurationSeparators();
	Else
		SeparatorArray = New Array;
	EndIf;
	
	For Each SeparatorName In SeparatorArray Do
		
		SetDataSeparationSafeMode(SeparatorName, True);
		
	EndDo;
	
	Try
		If TransactionActive() Then
			Result = Eval(Expression);
		Else
			BeginTransaction();
			Try
				Result = Eval(Expression);
				RollbackTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
		EndIf;
		
		Return Result;
	Except
		ErrorInfo = ErrorInfo();
		Refinement = CommonClientServer.ExceptionClarification(ErrorInfo);
		Raise(Refinement.Text, ErrorCategory.ExternalDataSourceError ,,, ErrorInfo);
	EndTry;
	
EndFunction

// Returns details of the Unsafe action protection with disabled warnings.
//
// Returns:
//  UnsafeOperationProtectionDescription - with the UnsafeOperationWarnings property value set to False.
//
Function ProtectionWithoutWarningsDetails() Export
	
	ProtectionDetails = New UnsafeOperationProtectionDescription;
	ProtectionDetails.UnsafeOperationWarnings = False;
	
	Return ProtectionDetails;
	
EndFunction

#EndRegion

#Region Queries

// Prepares a string for being used as a search template in a query with the "LIKE" statement.
// All special symbols are escaped.
//
// Parameters:
//  SearchString - String - arbitrary string.
//
// Returns:
//  String
//  
// Example:
//   SELECT
//    Products.Ref AS Ref
//  FROM
//    Catalog.Products AS Products
//  WHERE
//    Products.Description LIKE &Template ESCAPE "~"
//
//  Query.SetParameters("Template", Common.GenerateSearchQueryString(SearchText_1));
//
Function GenerateSearchQueryString(Val SearchString) Export
	
	Result = SearchString;
	Result = StrReplace(Result, "~", "~~");
	Result = StrReplace(Result, "%", "~%");
	Result = StrReplace(Result, "_", "~_");
	Result = StrReplace(Result, "[", "~[");
	Result = StrReplace(Result, "]", "~]");
	Result = StrReplace(Result, "^", "~^");	
	Return Result;
	
EndFunction

// Returns a query text fragment that is used as a separator between queries.
//
// Returns:
//  String - query separator.
//
Function QueryBatchSeparator() Export
	
	Return "
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|";
		
EndFunction

// Returns a piece of a query text that combines multiple queries into a single query.
//
// Returns:
//  String
//
Function UnionAllText() Export
	
	Return
		"
		|
		|UNION ALL
		|
		|";
	
EndFunction

#EndRegion

#Region Other

// Runs checks before starting a scheduled job handler and breaks its execution if the handler cannot run.
// For example, in the following cases:
//  - App update is in progress.
//  - It was started from the console or in a different way that bypasses the activation of the functional option 
//    (if cases, when the scheduled job depends on functional options).
//  - It's an attempt to start a job that handles external resources in an infobase copy.
//
// Parameters:
//  ScheduledJob - MetadataObjectScheduledJob - Scheduled job
//    that is calling the procedure.
//
// Example:
// Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.<ScheduledJobName>);
//
Procedure OnStartExecuteScheduledJob(ScheduledJob = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If InformationRegisters.ApplicationRuntimeParameters.UpdateRequired1() Then
		Text = NStr("en = 'The app is temporarily unavailable due to a version update.
			               |It is recommended that you disable scheduled jobs for the duration of the update.';");
		ScheduledJobsServer.CancelJobExecution(ScheduledJob, Text);
		Raise Text;
	EndIf;
	
	If Not DataSeparationEnabled()
	   And ExchangePlans.MasterNode() = Undefined
	   And ValueIsFilled(Constants.MasterNode.Get()) Then
	
		Text = NStr("en = 'The app is temporarily unavailable until the connection to the master node is restored.
			               |It is recommended that you disable scheduled jobs until the connection is restored.';");
		ScheduledJobsServer.CancelJobExecution(ScheduledJob, Text);
		Raise Text;
	EndIf;
	
	If ScheduledJob <> Undefined
		And SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		
		ModuleWorkLockWithExternalResources = CommonModule("ExternalResourcesOperationsLock");
		ModuleWorkLockWithExternalResources.OnStartExecuteScheduledJob(ScheduledJob);
		
		ModuleScheduledJobsInternal = CommonModule("ScheduledJobsInternal");
		Available = ModuleScheduledJobsInternal.ScheduledJobAvailableByFunctionalOptions(ScheduledJob);
		
		If Not Available Then
			Jobs = ScheduledJobsServer.FindJobs(New Structure("Metadata", ScheduledJob));
			For Each Job In Jobs Do
				ScheduledJobsServer.ChangeJob(Job.UUID,
					New Structure("Use", False));
			EndDo;
			Text = NStr("en = 'The scheduled job is unavailable due to functional option values
				               |or is not supported in the current app run mode.
				               |The scheduled job execution is canceled and the job is disabled.';");
			ScheduledJobsServer.CancelJobExecution(ScheduledJob, Text);
			Raise Text;
		EndIf;
	EndIf;
	
	If StandardSubsystemsServer.RegionalInfobaseSettingsRequired() Then
		Text = NStr("en = 'The scheduled job cannot run until the regional settings are configured.
			                |The scheduled job is aborted.';");
		ScheduledJobsServer.CancelJobExecution(ScheduledJob, Text);
		Raise Text;
	EndIf;

	Catalogs.ExtensionsVersions.RegisterExtensionsVersionUsage();
	
	InformationRegisters.ExtensionVersionParameters.UponSuccessfulStartoftheExecutionoftheScheduledTask();
	
EndProcedure

// Resets session parameters to Not set. 
// 
// Parameters:
//  ParametersToClear_ - String - names of comma-separated session parameters to be cleared.
//  Exceptions          - String - names of comma-separated session parameters that are not supposed to be cleared.
//
Procedure ClearSessionParameters(ParametersToClear_ = "", Exceptions = "") Export
	
	ExceptionsArray = StrSplit(Exceptions, ",");
	ArrayOfParametersToClear = StrSplit(ParametersToClear_, ",", False);
	
	If ArrayOfParametersToClear.Count() = 0 Then
		For Each SessionParameter In Metadata.SessionParameters Do
			If ExceptionsArray.Find(SessionParameter.Name) = Undefined Then
				ArrayOfParametersToClear.Add(SessionParameter.Name);
			EndIf;
		EndDo;
	EndIf;
	
	IndexOf = ArrayOfParametersToClear.Find("ClientParametersAtServer");
	If IndexOf <> Undefined Then
		ArrayOfParametersToClear.Delete(IndexOf);
	EndIf;
	
	IndexOf = ArrayOfParametersToClear.Find("DefaultLanguage");
	If IndexOf <> Undefined Then
		ArrayOfParametersToClear.Delete(IndexOf);
	EndIf;
	
	IndexOf = ArrayOfParametersToClear.Find("InstalledExtensions");
	If IndexOf <> Undefined Then
		ArrayOfParametersToClear.Delete(IndexOf);
	EndIf;
	
	SessionParameters.Clear(ArrayOfParametersToClear);
	
EndProcedure

// Checks whether the passed spreadsheet document fits a single page in the print layout.
//
// Parameters:
//  TabDocument        - SpreadsheetDocument - spreadsheet document.
//  AreasToOutput   - Array
//                     - SpreadsheetDocument - an array of tables, or a spreadsheet document. 
//  ResultOnError - Boolean - a result to return when an error occurs.
//
// Returns:
//   Boolean   - flag indicating whether the passed documents fit the page.
//
Function SpreadsheetDocumentFitsPage(TabDocument, AreasToOutput, ResultOnError = True) Export

	Try
		Return TabDocument.CheckPut(AreasToOutput);
	Except
		Return ResultOnError;
	EndTry;

EndFunction 

// Saves personal user settings related to the Core subsystem.
// To receive settings, use the following functions:
//  - CommonClient.SuggestFileSystemExtensionInstallation(),
//  - StandardSubsystemsServer.AskConfirmationOnExit(),
//  - StandardSubsystemsServer.ShowInstalledApplicationUpdatesWarning().
// 
// Parameters:
//  Settings - Structure:
//    * RemindAboutFileSystemExtensionInstallation  - Boolean - the flag indicating whether
//                                                               to notify users on extension installation.
//    * AskConfirmationOnExit - Boolean - the flag indicating whether to ask confirmation before the user exits the application.
//    * ShowInstalledApplicationUpdatesWarning - Boolean - show a notification when
//                                                               the application is dynamically updated.
//
Procedure SavePersonalSettings(Settings) Export
	
	If Settings.Property("RemindAboutFileSystemExtensionInstallation") Then
		If IsWebClient() Then
			ClientID = StandardSubsystemsServer.ClientParametersAtServer().Get("ClientID");
			If ClientID = Undefined Then
				SystemInfo = New SystemInfo;
				ClientID = SystemInfo.ClientID;
			EndIf;
			CommonSettingsStorageSave(
				"ApplicationSettings/SuggestFileSystemExtensionInstallation",
				ClientID, Settings.RemindAboutFileSystemExtensionInstallation);
		EndIf;
	EndIf;
	
	If Settings.Property("AskConfirmationOnExit") Then
		CommonSettingsStorageSave("UserCommonSettings",
			"AskConfirmationOnExit",
			Settings.AskConfirmationOnExit);
	EndIf;
	
	If Settings.Property("ShowInstalledApplicationUpdatesWarning") Then
		CommonSettingsStorageSave("UserCommonSettings",
			"ShowInstalledApplicationUpdatesWarning",
			Settings.ShowInstalledApplicationUpdatesWarning);
	EndIf;
	
EndProcedure

// Distributes the amount according
// to the specified distribution ratios. 
//
// Parameters:
//  AmountToDistribute - Number  - the amount to distribute. If set to 0, returns Undefined;
//                                 If set to a negative value, absolute value is calculated and then its sign is inverted.
//  Coefficients        - Array of Number - Distribution coefficients. 
//                                          All coefficients must be positive, or all coefficients must be negative.
//  Accuracy            - Number  - Rounding accuracy during distribution. 
//
// Returns:
//  Array of Number - array whose dimension is equal to the number of coefficients, contains
//           amounts according to the coefficient weights (from the array of coefficients).
//           If distribution cannot be performed (for example, number of coefficients = 0,
//           or some coefficients are negative, or total coefficient weight = 0),
//           returns Undefined.
//
// Example:
//
//	Coefficients = New Array;
//	Coefficients.Add(1);
//	Coefficients.Add(2);
//	Result = CommonClientServer.DistributeAmountInProportionToCoefficients(1, Coefficients);
//	// Result = [0.33, 0.67]
//
Function DistributeAmountInProportionToCoefficients(
		Val AmountToDistribute, Coefficients, Val Accuracy = 2) Export
	
	Return CommonClientServer.DistributeAmountInProportionToCoefficients(
		AmountToDistribute, Coefficients, Accuracy);
	
EndFunction

// Fills an attribute for a form of the FormDataTree type.
//
// Parameters:
//  TreeItemsCollection - FormDataTreeItemCollection - required attribute.
//  ValueTree           - ValueTree    - data to fill.
// 
Procedure FillFormDataTreeItemCollection(TreeItemsCollection, ValueTree) Export
	
	For Each TableRow In ValueTree.Rows Do
		
		TreeItem = TreeItemsCollection.Add();
		FillPropertyValues(TreeItem, TableRow);
		If TableRow.Rows.Count() > 0 Then
			FillFormDataTreeItemCollection(TreeItem.GetItems(), TableRow);
		EndIf;
		
	EndDo;
	
EndProcedure

// Applies an add-in based on Native API or COM technologies
// from the configuration template (stored as a ZIP archive).
//
// Parameters:
//   Id   - String - the add-in identification code.
//   FullTemplateName - String - full name of the configuration template with a ZIP archive.
//   Isolated    - Boolean - If set to "True", the add-in is attached isolatedly. 
//                              That is, it runs in a separate OS process.
//                              If set to "False", the add-in runs in the same OS process that runs 1C:Enterprise scripts. 
//                               
//                   - Undefined - Defines the 1C:Enterprise behavior.:
//                              Non-isolatedly if the add-in supports only this mode. 
//                              Isolatedly, in other cases. By default, "Undefined".
//                              See https://its.1c.eu/db/v83doc
//                                    #bookmark:dev:TI000001866
//
// Returns:
//   - AddInObject - Add-in instance.
//   - Undefined - Add-in instance.
//
// Example:
//
//  AttachableModule = Common.AttachAddInFromTemplate(
//      "QRCodeExtension",
//      "CommonTemplate.QRCodePrintingComponent");
//
//  If AttachableModule <> Undefined Then 
//      // AttachableModule contains the instance of the attached add-in.
//  EndIf;
//
//  AttachableModule = Undefined;
//
Function AttachAddInFromTemplate(Val Id, Val FullTemplateName, Val Isolated = Null) Export
	
	ResultOfCheckingTheExternalComponent = Undefined;
	
	If Isolated = Null Then
		Isolated = IsDefaultAddInAttachmentMethod();
	EndIf;
	
	If SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = CommonModule("AddInsInternal");
		ResultOfCheckingTheExternalComponent = ModuleAddInsInternal.CheckAddInAttachmentAbility(Id);
		ResultOfCheckingTheExternalComponent.Insert("Available", 
			Not ValueIsFilled(ResultOfCheckingTheExternalComponent.ErrorDescription));
	EndIf;
	
	TheComponentOfTheLatestVersion = StandardSubsystemsServer.TheComponentOfTheLatestVersion(
		Id, FullTemplateName, ResultOfCheckingTheExternalComponent);
		
	Result = AttachAddInSSLByID(Id,
			TheComponentOfTheLatestVersion.Location, Isolated);
	
	Return Result.Attachable_Module;
	
EndFunction

#EndRegion

#Region ObsoleteProceduresAndFunctions

// Deprecated. Use Common.DataSeparationEnabled() AND Common.CanUseSeparatedData().
// 
//
// Returns:
//   Boolean
//
Function SessionSeparatorUsage() Export
	
	If Not DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	If SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = CommonModule("SaaSOperations");
		Return ModuleSaaSOperations.SessionSeparatorUsage();
	EndIf;
	
EndFunction

// Deprecated. Instead, use FileSystem.CreateTemporaryDirectory
// Creates a temporary directory. If a temporary directory is not required anymore, deleted it 
// with the Common.DeleteTemporaryDirectory procedure.
//
// Parameters:
//   Extension - String - the temporary directory extension that contains the directory designation
//                         and its subsystem.
//                         It is recommended that you use only Latin characters in this parameter.
//
// Returns:
//   String - the full path to the directory, including path separators.
//
Function CreateTemporaryDirectory(Val Extension = "") Export
	
	Return FileSystem.CreateTemporaryDirectory(Extension);
	
EndFunction

// Deprecated. Instead, use FileSystem.DeleteTemporaryDirectory
// Deletes the temporary directory and its content if possible.
// If a temporary directory cannot be deleted (for example, if it is busy),
// the procedure is completed and the warning is added to the event log.
//
// This procedure is for using with the Common.CreateTemporaryDirectory procedure 
// after a temporary directory is not required anymore.
//
// Parameters:
//   PathToDirectory - String - the full path to a temporary directory.
//
Procedure DeleteTemporaryDirectory(Val PathToDirectory) Export
	
	FileSystem.DeleteTemporaryDirectory(PathToDirectory);
	
EndProcedure

// Deprecated. Obsolete. Checks for the platform features that notify users about unsafe actions.
//
// Returns:
//  Boolean - if True, the unsafe action protection feature is on.
//
Function HasUnsafeActionProtection() Export
	
	Return True;
	
EndFunction

// Deprecated. Obsolete. Creates and returns an instance of a report or data processor by the passed full name of a metadata object.
//
// Parameters:
//  FullName - String - full name of a metadata object. Example: "Report.BusinessProcesses".
//
// Returns:
//  ReportObject
//  DataProcessorObject - an instance of a report or data processor.
// 
Function ObjectByFullName(FullName) Export
	RowsArray = StrSplit(FullName, ".");
	
	If RowsArray.Count() >= 2 Then
		Kind = Upper(RowsArray[0]);
		Name = RowsArray[1];
	Else
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of parameter ""%1"" in function ""%2"". Invalid name of a report or data processor: ""%3"".';"), 
			"FullName", "Common.ObjectByFullName", FullName),
			ErrorCategory.ConfigurationError);
	EndIf;
	
	If Kind = "REPORT" Then
		Return Reports[Name].Create();
	ElsIf Kind = "DATAPROCESSOR" Then
		Return DataProcessors[Name].Create();
	Else
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of parameter ""%1"" in function ""%2"". The object is not a report or data processor: ""%3"".';"), 
			"FullName", "Common.ObjectByFullName", FullName),
			ErrorCategory.ConfigurationError);
	EndIf;
EndFunction

// Deprecated. Instead, use Common.IsMacOSClient
// Returns True if the client application runs on OS X.
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsOSXClient() Export
	
	SetPrivilegedMode(True);
	
	IsMacOSClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsMacOSClient");
	
	If IsMacOSClient = Undefined Then
		Return False; // No client application.
	EndIf;
	
	Return IsMacOSClient;
	
EndFunction

#EndRegion

#EndIf

#EndRegion

#If Not MobileStandaloneServer Then

#Region Internal

// Exports the query into an XML string, which you can pass to the Query console.
//   To pass the query and all its parameters to the Query console, call the function in the window.
//   "Eval expression" (Shift + F9), copy the resulting XML to the "Query text" field
//   of the query console and run the "Fill from XML" command in the "More" menu.
//   For details, see the Query console help.
//
// Parameters:
//   Query - Query - query to be exported as an XML string.
//
// Returns:
//   String - XML string, which can extracted using the Common.ValueFromXMLString method.
//       The extraction outcome is a structure with the following fields:
//       * Text     - String - query text.
//       * Parameters - Structure - query parameters.
//
Function QueryToXMLString(Query) Export // ACC:299 - Intended for debugging queries. See the function comments.
	Structure = New Structure("Text, Parameters");
	FillPropertyValues(Structure, Query);
	Return ValueToXMLString(Structure);
EndFunction

Function AttachAddInSSLByID(Val Id, Val Location, Val Isolated = Null) Export
	
	CheckTheLocationOfTheComponent(Id, Location);
	
	Result = New Structure;
	Result.Insert("Attached", False);
	Result.Insert("Attachable_Module", Undefined);
	Result.Insert("ErrorDescription", "");
	
	Try
		
#If MobileAppServer Then
		ConnectionResult = AttachAddIn(Location, Id + "SymbolicName");
#Else
		If Isolated = Null Then
			Isolated = IsDefaultAddInAttachmentMethod();
		EndIf;
		ConnectionResult = AttachAddIn(Location, Id + "SymbolicName",,
			CommonInternalClientServer.AddInAttachType(Isolated));
#EndIf
		
	Except
		ErrorInfo = ErrorInfo();
		ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot attach the ""%1"" add-in on the server due to:';"),
			Id);
		
		Result.ErrorDescription = ErrorTitle + Chars.LF
			+ ErrorProcessing.BriefErrorDescription(ErrorInfo);
		
		CommentForLog = ErrorTitle + Chars.LF
			+ ErrorProcessing.DetailErrorDescription(ErrorInfo)
			+ SystemInformationForLogging();
		
		WriteLogEvent(NStr("en = 'Attaching add-in on the server';", DefaultLanguageCode()),
			EventLogLevel.Error,,, CommentForLog);
		Return Result;
	EndTry;
	
	If Not ConnectionResult Then
		
		TemplateAddInCompatibilityError = TemplateAddInCompatibilityError(Location);
		
		If ValueIsFilled(TemplateAddInCompatibilityError) Then
			Result.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t attach the add-in ""%1"" on the server due to:
					 |%2.
					 |Technical information:
					 |%3
					 |Method ""%4"" returned ""False"".';"), Id, TemplateAddInCompatibilityError, Location,
				"AttachAddIn");
		Else
			Result.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot attach the ""%1"" add-in on the server.
					 |Technical information:
					 |%2
					 |The method ""%3"" returned ""False"".';"), Id, Location, "AttachAddIn");
		EndIf;
		
		Try
			Raise NStr("en = 'Call stack:';")
		Except
			CommentForLog = Result.ErrorDescription + Chars.LF + Chars.LF
				+ ErrorProcessing.DetailErrorDescription(ErrorInfo())
				+ SystemInformationForLogging();
		EndTry;
		
		WriteLogEvent(NStr("en = 'Attaching add-in on the server';", DefaultLanguageCode()),
			EventLogLevel.Error,,, CommentForLog);
		Return Result;
	EndIf;
	
	Attachable_Module = Undefined;
	Try
		Attachable_Module = New("AddIn." + Id + "SymbolicName" + "." + Id);
		If Attachable_Module = Undefined Then 
			Raise NStr("en = 'The New operator returned Undefined.';");
		EndIf;
	Except
		Attachable_Module = Undefined;
		ErrorInfo = ErrorInfo();
	EndTry;
	
	If Attachable_Module = Undefined Then
		Result.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot create object of the %1 add-in on the server due to:
			           |%2';"),
			Id, ErrorProcessing.BriefErrorDescription(ErrorInfo));
		
		CommentForLog = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot create an object of the %1 add-in on the server due to:
			           |%2';"),
			Id, ErrorProcessing.DetailErrorDescription(ErrorInfo)
				+ SystemInformationForLogging());
		
		WriteLogEvent(NStr("en = 'Attaching add-in on the server';", DefaultLanguageCode()),
			EventLogLevel.Error,,, CommentForLog);
		Return Result;
	EndIf;
	
	Result.Attached = True;
	Result.Attachable_Module = Attachable_Module;
	Return Result;
	
EndFunction

Function IsDefaultAddInAttachmentMethod() Export
	
#If Not WebClient And Not MobileClient And Not MobileAppServer Then
	
	SystemInfo = New SystemInfo;
	AppVersion = SystemInfo.AppVersion;
	If StrStartsWith(AppVersion, "8.3.24") And CommonClientServer.CompareVersions(AppVersion, "8.3.24.1267") >= 0
	 Or StrStartsWith(AppVersion, "8.3.23") And CommonClientServer.CompareVersions(AppVersion, "8.3.23.1947") >= 0
	 Or StrStartsWith(AppVersion, "8.3.22") And CommonClientServer.CompareVersions(AppVersion, "8.3.22.2322") >= 0
	 Or StrStartsWith(AppVersion, "8.3.21") And CommonClientServer.CompareVersions(AppVersion, "8.3.21.1930") >= 0 Then
		Return Undefined;
	Else
		Return False;
	EndIf;
#Else
	
	Return Undefined;
	
#EndIf
	
EndFunction

Function StringAsNstr(Val RowToValidate) Export
	
	RowToValidate = StrReplace(RowToValidate, " ", "");
	
	MatchesOptions = New Array;
	For Each Language In Metadata.Languages Do
		MatchesOptions.Add(Language.LanguageCode + "=");
	EndDo;
	
	For Each MatchOption In MatchesOptions Do
		If StrFind(RowToValidate, MatchOption) > 0 Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Sets the conditional appearance of the choice list
// 
// Parameters:
//  Form - ClientApplicationForm - the form for which the appearance is set.
//  TagName - String - the item name for which the appearance is set.
//  DataCompositionFieldName - String - a data composition field name.
//
Procedure SetChoiceListConditionalAppearance(Form, TagName, DataCompositionFieldName) Export
	
	Items           = Form.Items;
	ConditionalAppearance = Form.ConditionalAppearance;
	
	For Each ChoiceItem In Items[TagName].ChoiceList Do
		
		Item = ConditionalAppearance.Items.Add();
		
		ItemField = Item.Fields.Items.Add();
		FormItem = Items[TagName]; // FormField
		ItemField.Field = New DataCompositionField(FormItem.Name);
		
		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField(DataCompositionFieldName);
		ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
		ItemFilter.RightValue = ChoiceItem.Value;
		
		Item.Appearance.SetParameterValue("Text", ChoiceItem.Presentation);
		
	EndDo;
	
EndProcedure

// Returns the suffix of the current language (for multilingual attributes).
// 
// Returns:
//  String - "Lang1" or "Lang2" if the user language is not default.
//           Empty string, if the user language is default.
//  Undefined, if multilingual data is not supported.
//
Function CurrentUserLanguageSuffix() Export
	
	Result = New Structure();
	Result.Insert("CurrentLanguageSuffix", "");
	Result.Insert("IsMainLanguage", "");
	
	If SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = CommonModule("NationalLanguageSupportServer");
		CurrentLanguageSuffix = ModuleNationalLanguageSupportServer.CurrentLanguageSuffix();
		
		If ValueIsFilled(CurrentLanguageSuffix) Then
			Return CurrentLanguageSuffix;
		EndIf;
	Else
		CurrentLanguageSuffix  = "";
	EndIf;
	
	If IsMainLanguage() Then
		Return CurrentLanguageSuffix;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Truncates a filename if its size exceeds 255 bytes. 
// It replaces the end part of the filename (without the extension) with a unique MD5 hash. 
//  
// 
// Parameters:
//  FileName - String - File name including the extension.
// 
Procedure ShortenFileName(FileName) Export
	
	BytesLimit = 127;
	File = New File(FileName);
	
	If StringSizeInBytes(File.Name) <= BytesLimit Then
		Return;
	EndIf;
	
	String = "";
	RowBalance = "";
	LineSize = 0;
	MaximumRowSize = BytesLimit - 32;
	
	ExtensionSize = StringSizeInBytes(File.Extension);
	ShortenAlongWithExtension = ExtensionSize > 32;
	
	If ShortenAlongWithExtension Then
		AbbreviatedName = File.Name;
	Else
		AbbreviatedName = File.BaseName;
		LineSize = ExtensionSize;
	EndIf;
	
	For CharacterNumber = 1 To StrLen(AbbreviatedName) Do
		Char = Mid(AbbreviatedName, CharacterNumber, 1);
		SymbolSize = StringSizeInBytes(Char);
		
		If LineSize + SymbolSize > MaximumRowSize Then
			RowBalance = Mid(AbbreviatedName, CharacterNumber);
			Break;
		EndIf;
		
		String = String + Char;
		LineSize = LineSize + SymbolSize;
	EndDo;
	
	FileName = String;
	
	DataHashing = New DataHashing(HashFunction.MD5);
	DataHashing.Append(RowBalance);
	HashSum = StrReplace(DataHashing.HashSum, " ", "");
	
	FileName = File.Path + FileName + HashSum + ?(ShortenAlongWithExtension, "", File.Extension);
	
EndProcedure

// Internal objects and backup objects must be written without using any applied logic.
// Applied logic might lead to infinite loops, performance degradation, and unwanted changes.
//
// An object is considered internal if it is not involved in data exchange and dependencies. For example:
// - Cache objects
// - Cache update dates and flags
// - Intermediate data to be passed to background jobs
//
// - Auxiliary data (access keys, object IDs)
// If the AccessManagement subsystem is integrated, also call the AccessManagement.DisableAccessKeysUpdate procedure.
// - This procedure enables the data import mode and disables data registration in exchange plans,
// - and control of the Marked object deletion mechanism.
// 
// 
//   
//
// 
// 
// 
//
// 
// 
// 
//
// Parameters:
//  Object - ExchangePlanObject
//         - ConstantValueManager
//         - CatalogObject
//         - DocumentObject
//         - SequenceRecordSet
//         - ChartOfCharacteristicTypesObject
//         - ChartOfAccountsObject
//         - ChartOfCalculationTypesObject
//         - BusinessProcessObject
//         - TaskObject
//         - ObjectDeletion
//         - InformationRegisterRecordSet
//         - AccumulationRegisterRecordSet
//         - AccountingRegisterRecordSet
//         - CalculationRegisterRecordSet
//         - RecalculationRecordSet
//
// IsExchangePlanNode - Boolean
//
Procedure DisableRecordingControl(Object, IsExchangePlanNode = False) Export
	
	Object.AdditionalProperties.Insert("DontControlObjectsToDelete");
	Object.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	Object.DataExchange.Load = True;
	If Not IsExchangePlanNode Then
		Object.DataExchange.Recipients.AutoFill = False;
	EndIf;
	
EndProcedure

Function TemplateExists(FullTemplateName) Export
	
	Template = Metadata.FindByFullName(FullTemplateName);
	If TypeOf(Template) = Type("MetadataObject") Then 
		
		Var_482_Template = New Structure("TemplateType");
		FillPropertyValues(Var_482_Template, Template);
		TemplateType = Undefined;
		If Var_482_Template.Property("TemplateType", TemplateType) Then 
			Return TemplateType <> Undefined;
		EndIf;
		
	EndIf;
	
	Return False;
	
EndFunction

#EndRegion

#Region Private

#Region InfobaseData

#Region AttributesValues

// Checks the metadata object for the given attributes.
// 
// Parameters:
//  FullMetadataObjectName - String - object full name.
//  ExpressionsToCheck       - Array - field names or metadata object expressions to check.
// 
// Returns:
//  Structure:
//   * Error         - Boolean - the flag indicating whether an error is found.
//   * ErrorDescription - String - the descriptions of errors that are found.
//
// Example:
//  
// Attributes = New Array;
// Attributes.Add("Number");
// Attributes.Add("Currency.FullDescription");
//
// Result = Common.CheckIfObjectAttributesExist("Document.SalesOrder", Attributes);
//
// If Result.Error Then
//     CallException Result.ErrorDescription;
// EndIf;
//
Function CheckIfObjectAttributesExist(FullMetadataObjectName, ExpressionsToCheck)
	
	ObjectMetadata = MetadataObjectByFullName(FullMetadataObjectName);
	If ObjectMetadata = Undefined Then 
		Return New Structure("Error, ErrorDescription", True, 
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Non-existing metadata object: ""%1"".';"), FullMetadataObjectName));
	EndIf;

	// Allow a call from the safe mode of an external data processor or extension.
	// The information on the availability of the schema's source fields is not considered private when checking metadata.
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	Schema = New QuerySchema;
	Package = Schema.QueryBatch.Add(Type("QuerySchemaSelectQuery"));
	Operator = Package.Operators.Get(0);
	
	Source = Operator.Sources.Add(FullMetadataObjectName, "Table");
	ErrorText = "";
	
	For Each CurrentExpression In ExpressionsToCheck Do
		
		If Not QuerySchemaSourceFieldAvailable(Source, CurrentExpression) Then 
			ErrorText = ErrorText + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The ""%1"" object field does not exist.';"), CurrentExpression);
		EndIf;
		
	EndDo;
		
	Return New Structure("Error, ErrorDescription", Not IsBlankString(ErrorText), ErrorText);
	
EndFunction

// Intended for CheckIfObjectAttributesExist.
// Checks the availability of an expression field in the query schema operator source.
//
Function QuerySchemaSourceFieldAvailable(OperatorSource, ExpressToCheck)
	
	FieldNameParts = StrSplit(ExpressToCheck, ".");
	AvailableFields = OperatorSource.Source.AvailableFields;
	
	CurrentFieldNamePart = 0;
	While CurrentFieldNamePart < FieldNameParts.Count() Do 
		
		CurrentField = AvailableFields.Find(FieldNameParts.Get(CurrentFieldNamePart)); 
		
		If CurrentField = Undefined Then 
			Return False;
		EndIf;
		
		// Incrementing the next part of the field name and the relevant field availability list.
		CurrentFieldNamePart = CurrentFieldNamePart + 1;
		AvailableFields = CurrentField.Fields;
		
	EndDo;
	
	Return True;
	
EndFunction

#EndRegion

#Region ReplaceReferences

Function MarkUsageInstances(Val ExecutionParameters, Val Ref, Val DestinationRef, Val SearchTable)
	SetPrivilegedMode(True);
	
	// Setting the order of known objects and checking whether there are unidentified ones.
	Result = New Structure;
	Result.Insert("UsageInstances", SearchTable.FindRows(New Structure("Ref", Ref)));
	Result.Insert("MarkupErrors",     New Array);
	Result.Insert("Success",              True);
	
	For Each UsageInstance1 In Result.UsageInstances Do
		If UsageInstance1.IsInternalData Then
			Continue; // Skipping dependent data.
		EndIf;
		
		Information = TypeInformation(UsageInstance1.Metadata, ExecutionParameters);
		If Information.Kind = "CONSTANT" Then
			UsageInstance1.ReplacementKey = "Constant";
			UsageInstance1.DestinationRef = DestinationRef;
			
		ElsIf Information.Kind = "SEQUENCE" Then
			UsageInstance1.ReplacementKey = "Sequence";
			UsageInstance1.DestinationRef = DestinationRef;
			
		ElsIf Information.Kind = "INFORMATIONREGISTER" Then
			UsageInstance1.ReplacementKey = "InformationRegister";
			UsageInstance1.DestinationRef = DestinationRef;
			
		ElsIf Information.Kind = "ACCOUNTINGREGISTER"
			Or Information.Kind = "ACCUMULATIONREGISTER"
			Or Information.Kind = "CALCULATIONREGISTER" Then
			UsageInstance1.ReplacementKey = "RecordKey";
			UsageInstance1.DestinationRef = DestinationRef;
			
		ElsIf Information.Referential Then
			UsageInstance1.ReplacementKey = "Object";
			UsageInstance1.DestinationRef = DestinationRef;
			
		Else
			// Unknown object for reference replacement.
			Result.Success = False;
			Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot replace references in ""%1"".';"), Information.FullName);
			ErrorDescription = New Structure("Object, Text", UsageInstance1.Data, Text);
			Result.MarkupErrors.Add(ErrorDescription);
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// Parameters:
//  SearchTable - See UsageInstances
//
Procedure ReplaceRefsUsingShortTransactions(Result, Val ExecutionParameters, Val Duplicate1, Val SearchTable)
	
	// Main data processor loop.
	RefFilter = New Structure("Ref, ReplacementKey");
	
	Result.HasErrors = False;
	
	RefFilter.Ref = Duplicate1;
	RefFilter.ReplacementKey = "Constant";
	
	UsageInstances = SearchTable.FindRows(RefFilter);
	For Each UsageInstance1 In UsageInstances Do
		ReplaceInConstant(Result, UsageInstance1, ExecutionParameters);
	EndDo;
	
	RefFilter.ReplacementKey = "Object";
	UsageInstances = SearchTable.FindRows(RefFilter);
	For Each UsageInstance1 In UsageInstances Do
		ReplaceInObject(Result, UsageInstance1, ExecutionParameters);
	EndDo;
	
	RefFilter.ReplacementKey = "RecordKey";
	UsageInstances = SearchTable.FindRows(RefFilter);
	For Each UsageInstance1 In UsageInstances Do
		ReplaceInSet(Result, UsageInstance1, ExecutionParameters);
	EndDo;
	
	RefFilter.ReplacementKey = "Sequence";
	UsageInstances = SearchTable.FindRows(RefFilter);
	For Each UsageInstance1 In UsageInstances Do
		ReplaceInSet(Result, UsageInstance1, ExecutionParameters);
	EndDo;
	
	RefFilter.ReplacementKey = "InformationRegister";
	UsageInstances = SearchTable.FindRows(RefFilter);
	For Each UsageInstance1 In UsageInstances Do
		ReplaceInInformationRegister(Result, UsageInstance1, ExecutionParameters);
	EndDo;
	
	ReplacementsToProcess = New Array;
	ReplacementsToProcess.Add(Duplicate1);
	
	If ExecutionParameters.ShouldDeleteDirectly
		Or ExecutionParameters.MarkForDeletion Then
		
  		SetDeletionMarkForObjects(Result, ReplacementsToProcess, ExecutionParameters);
	Else
		
		RepeatSearchTable = UsageInstances(ReplacementsToProcess,, ExecutionParameters.UsageInstancesSearchParameters);
		AddModifiedObjectReplacementResults(Result, RepeatSearchTable);
	EndIf;
	
EndProcedure

Procedure ReplaceInConstant(Result, Val UsageInstance1, Val WriteParameters)
	
	SetPrivilegedMode(True);
	
	Data = UsageInstance1.Data;
	MetadataConstants = UsageInstance1.Metadata;
	DataPresentation = String(Data);
	
	Filter = New Structure("Data, ReplacementKey", Data, "Constant");
	RowsToProcess = UsageInstance1.Owner().FindRows(Filter); // See UsageInstances
	For Each TableRow In RowsToProcess Do
		TableRow.ReplacementKey = "";
	EndDo;

	ActionState = "";
	BeginTransaction();
	
	Try
		Block = New DataLock;
		Block.Add(MetadataConstants.FullName());
		Try
			Block.Lock();
		Except
			ActionState = "LockError";
			RefinementErrors = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Failed to make replacement in ""%1"". Another user is editing the data.
				|Please try again later.';"), 
				DataPresentation);
			ErrorInfo = ErrorInfo();
			Refinement = CommonClientServer.ExceptionClarification(ErrorInfo, RefinementErrors);
			Raise(Refinement.Text, Refinement.Category,,, ErrorInfo);
		EndTry;
	
		ManagerOfConstant = Constants[MetadataConstants.Name].CreateValueManager();
		ManagerOfConstant.Read();
		
		ReplacementPerformed = False;
		For Each TableRow In RowsToProcess Do
			If ManagerOfConstant.Value = TableRow.Ref Then
				ManagerOfConstant.Value = TableRow.DestinationRef;
				ReplacementPerformed = True;
			EndIf;
		EndDo;
		
		If Not ReplacementPerformed Then
			RollbackTransaction();
			Return;
		EndIf;	
		 
		// Save attempt.
		If Not WriteParameters.WriteInPrivilegedMode Then
			SetPrivilegedMode(False);
		EndIf;
		
		Try
			WriteObject(ManagerOfConstant, WriteParameters);
		Except
			ActionState = "WritingError";
			ErrorInfo = ErrorInfo();
			Refinement = CommonClientServer.ExceptionClarification(ErrorInfo,
				NStr("en = 'Couldn''t make replacement due to:';"));
			Raise(Refinement.Text, Refinement.Category,,, ErrorInfo);
		EndTry;
		
		If Not WriteParameters.WriteInPrivilegedMode Then
			SetPrivilegedMode(True);
		EndIf;
			
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(RefReplacementEventLogMessageText(), EventLogLevel.Error,
			MetadataConstants,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		If ActionState = "WritingError" Then
			For Each TableRow In RowsToProcess Do
				RegisterReplacementError(Result, TableRow.Ref, 
					ReplacementErrorDescription("WritingError", Data, DataPresentation, ErrorInfo()));
			EndDo;
		Else		
			RegisterReplacementError(Result, TableRow.Ref, 
				ReplacementErrorDescription(ActionState, Data, DataPresentation, ErrorInfo()));
		EndIf;		
	EndTry;
	
EndProcedure

Procedure ReplaceInObject(Result, Val UsageInstance1, Val ExecutionParameters)
	
	SetPrivilegedMode(True);
	
	Data = UsageInstance1.Data;
	
	// Performing all replacement of the data in the same time.
	Filter = New Structure("Data, ReplacementKey", Data, "Object");
	RowsToProcess = UsageInstance1.Owner().FindRows(Filter); // See UsageInstances
	
	DataPresentation = SubjectString(Data);
	ActionState = "";
	BeginTransaction();
	
	Try
		
		Block = New DataLock;
		LockUsageInstance(ExecutionParameters, Block, UsageInstance1);
		Try
			Block.Lock();
		Except
			ActionState = "LockError";
			RefinementErrors = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Failed to make replacement in ""%1"". Another user is editing the data.
				|Please try again later.';"), 
				DataPresentation);
			ErrorInfo = ErrorInfo();
			Refinement = CommonClientServer.ExceptionClarification(ErrorInfo, RefinementErrors);
			Raise(Refinement.Text, Refinement.Category,,, ErrorInfo);
		EndTry;
		
		WritingObjects = ModifiedObjectsOnReplaceInObject(ExecutionParameters, UsageInstance1, RowsToProcess);
		
		// Attempting to save. The object goes last.
		If Not ExecutionParameters.WriteInPrivilegedMode Then
			SetPrivilegedMode(False);
		EndIf;
		
		Try
			If ExecutionParameters.IncludeBusinessLogic Then
				// First writing iteration without the control to fix loop references.
				NewExecutionParameters = CopyRecursive(ExecutionParameters);
				NewExecutionParameters.IncludeBusinessLogic = False;
				For Each KeyValue In WritingObjects Do
					WriteObject(KeyValue.Key, NewExecutionParameters);
				EndDo;
				// Second writing iteration with the control.
				NewExecutionParameters.IncludeBusinessLogic = True;
				For Each KeyValue In WritingObjects Do
					WriteObject(KeyValue.Key, NewExecutionParameters);
				EndDo;
			Else
				// Writing without the business logic control.
				For Each KeyValue In WritingObjects Do
					WriteObject(KeyValue.Key, ExecutionParameters);
				EndDo;
			EndIf;
		Except
			ActionState = "WritingError";
			ErrorInfo = ErrorInfo();
			Refinement = CommonClientServer.ExceptionClarification(ErrorInfo,
				NStr("en = 'Couldn''t make replacement due to:';"));
			Raise(Refinement.Text, Refinement.Category,,, ErrorInfo);
		EndTry;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Information = ErrorInfo();
		WriteLogEvent(RefReplacementEventLogMessageText(), EventLogLevel.Error,
			UsageInstance1.Metadata,,	ErrorProcessing.DetailErrorDescription(Information));
		Error = ReplacementErrorDescription(ActionState, Data, DataPresentation, ErrorInfo());
		If ActionState = "WritingError" Then
			For Each TableRow In RowsToProcess Do
				RegisterReplacementError(Result, TableRow.Ref, Error);
			EndDo;
		Else	
			RegisterReplacementError(Result, UsageInstance1.Ref, Error);
		EndIf;
	EndTry;
	
	// Mark as processed.
	For Each TableRow In RowsToProcess Do
		TableRow.ReplacementKey = "";
	EndDo;
	
EndProcedure

Procedure ReplaceInSet(Result, Val UsageInstance1, Val ExecutionParameters)
	SetPrivilegedMode(True);
	
	Data = UsageInstance1.Data;
	RegisterMetadata = UsageInstance1.Metadata;
	DataPresentation = String(Data);
	
	// Performing all replacement of the data in the same time.
	Filter = New Structure("Data, ReplacementKey");
	FillPropertyValues(Filter, UsageInstance1);
	RowsToProcess = UsageInstance1.Owner().FindRows(Filter); // See UsageInstances
	
	SetDetails = RecordKeyDetails(RegisterMetadata);
	RecordSet = SetDetails.RecordSet; // InformationRegisterRecordSet
	
	ReplacementPairs = New Map;
	For Each TableRow In RowsToProcess Do
		ReplacementPairs.Insert(TableRow.Ref, TableRow.DestinationRef);
	EndDo;
	
	// Mark as processed.
	For Each TableRow In RowsToProcess Do
		TableRow.ReplacementKey = "";
	EndDo;
	
	ActionState = "";
	BeginTransaction();
	
	Try
		
		// Locking and preparing the set.
		Block = New DataLock;
		For Each KeyValue In SetDetails.MeasurementList Do
			DimensionType = KeyValue.Value;
			Name          = KeyValue.Key;
			Value     = Data[Name];
			
			For Each TableRow In RowsToProcess Do
				CurrentRef = TableRow.Ref;
				If DimensionType.ContainsType(TypeOf(CurrentRef)) Then
					Block.Add(SetDetails.LockSpace).SetValue(Name, CurrentRef);
				EndIf;
			EndDo;
			
			RecordSet.Filter[Name].Set(Value);
		EndDo;
		
		Try
			Block.Lock();
		Except
			ActionState = "LockError";
			RefinementErrors = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Failed to make replacement in ""%1"". Another user is editing the data.
				|Please try again later.';"), 
				DataPresentation);
			ErrorInfo = ErrorInfo();
			Refinement = CommonClientServer.ExceptionClarification(ErrorInfo, RefinementErrors);
			Raise(Refinement.Text, Refinement.Category,,, ErrorInfo);
		EndTry;
				
		RecordSet.Read();
		ReplaceInRowCollection("RecordSet", "RecordSet", RecordSet, RecordSet, SetDetails.FieldList, ReplacementPairs);
		
		If RecordSet.Modified() Then
			RollbackTransaction();
			Return;
		EndIf;	

		If Not ExecutionParameters.WriteInPrivilegedMode Then
			SetPrivilegedMode(False);
		EndIf;
		
		Try
			WriteObject(RecordSet, ExecutionParameters);
		Except
			ActionState = "WritingError";
			ErrorInfo = ErrorInfo();
			Refinement = CommonClientServer.ExceptionClarification(ErrorInfo,
				NStr("en = 'Couldn''t make replacement due to:';"));
			Raise(Refinement.Text, Refinement.Category,,, ErrorInfo);
		EndTry;
		
		If Not ExecutionParameters.WriteInPrivilegedMode Then
			SetPrivilegedMode(True);
		EndIf;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Information = ErrorInfo();
		WriteLogEvent(RefReplacementEventLogMessageText(), EventLogLevel.Error,
			RegisterMetadata,, ErrorProcessing.DetailErrorDescription(Information));
		Error = ReplacementErrorDescription(ActionState, Data, DataPresentation, ErrorInfo());
		If ActionState = "WritingError" Then
			For Each TableRow In RowsToProcess Do
				RegisterReplacementError(Result, TableRow.Ref, Error);
			EndDo;
		Else	
			RegisterReplacementError(Result, UsageInstance1.Ref, Error);
		EndIf;	
	EndTry;
	
EndProcedure

Procedure ReplaceInInformationRegister(Result, Val UsageInstance1, Val ExecutionParameters)
	
	If UsageInstance1.Processed Then
		Return;
	EndIf;
	UsageInstance1.Processed = True;
	
	// If a duplicate is specified in the set's dimensions, two sets of records are used:
	//     "DuplicateRecordSet" for reading values from the old dimensions and deleting them.
	//     "OriginalRecordSet" for reading values in the new dimensions and writing them.
	//     The following rules apply for merging the original and duplicate items:
	//         The original item's data has a higher priority.
	//         If the original item has no data, it's copied from the duplicate.
	//     The original item is written, and the duplicate is deleted.
	//
	// If no duplicate is specified in the set's dimensions, a single set of records is used:
	//     "DuplicateRecordSet" for reading values from the old dimensions and writing new values.
	//
	// In both cases, the references in resources and attributes are replaced.
	
	SetPrivilegedMode(True);
	
	Duplicate1    = UsageInstance1.Ref;
	Original = UsageInstance1.DestinationRef;
	
	RegisterMetadata = UsageInstance1.Metadata;
	RegisterRecordKey = UsageInstance1.Data;
	
	Information = TypeInformation(RegisterMetadata, ExecutionParameters);
	
	TwoSetsRequired = False;
	For Each KeyValue In Information.Dimensions Do
		DuplicateDimensionValue = RegisterRecordKey[KeyValue.Key];
		If DuplicateDimensionValue = Duplicate1
			Or ExecutionParameters.SuccessfulReplacements[DuplicateDimensionValue] = Duplicate1 Then
			TwoSetsRequired = True; // Duplicate is specified in dimensions.
			Break;
		EndIf;
	EndDo;
	
	Manager = ObjectManagerByFullName(Information.FullName);
	DuplicateRecordSet = Manager.CreateRecordSet();
	
	If TwoSetsRequired Then
		OriginalDimensionValues = New Structure;
		OriginalRecordSet = Manager.CreateRecordSet();
	EndIf;
	
	BeginTransaction();
	
	Try
		Block = New DataLock;
		DuplicateLock = Block.Add(Information.FullName);
		If TwoSetsRequired Then
			OriginalLock = Block.Add(Information.FullName);
		EndIf;
		
		For Each KeyValue In Information.Dimensions Do
			DuplicateDimensionValue = RegisterRecordKey[KeyValue.Key];
			
			// To resolve the uniqueness issue, the old values of the dimension record keys
			//   are replaced with new ones. The "SuccessfulReplacements" map stores the old and new values.
			//   The map updates after a new value–old value pair is processed and the transaction is committed.
			//   
			//   
			NewDuplicateDimensionValue = ExecutionParameters.SuccessfulReplacements[DuplicateDimensionValue];
			If NewDuplicateDimensionValue <> Undefined Then
				DuplicateDimensionValue = NewDuplicateDimensionValue;
			EndIf;
			
			DuplicateRecordSet.Filter[KeyValue.Key].Set(DuplicateDimensionValue);
			
			 // Replacement in the pair and lock for the replacement.
			DuplicateLock.SetValue(KeyValue.Key, DuplicateDimensionValue);
			
			
			If TwoSetsRequired Then
				If DuplicateDimensionValue = Duplicate1 Then
					OriginalDimensionValue = Original;
				Else
					OriginalDimensionValue = DuplicateDimensionValue;
				EndIf;
				
				OriginalRecordSet.Filter[KeyValue.Key].Set(OriginalDimensionValue);
				OriginalDimensionValues.Insert(KeyValue.Key, OriginalDimensionValue);
				
				// Replacement in the pair and lock for the replacement.
				OriginalLock.SetValue(KeyValue.Key, OriginalDimensionValue);
			EndIf;
		EndDo;
		
		Block.Lock();
		
		DuplicateRecordSet.Read();
		If DuplicateRecordSet.Count() = 0 Then 
			RollbackTransaction();
			Return;
		EndIf;
		DuplicateRecord = DuplicateRecordSet[0];
		
		If TwoSetsRequired Then
			// Writing to a set with other dimensions.
			OriginalRecordSet.Read();
			If OriginalRecordSet.Count() = 0 Then
				OriginalRecord = OriginalRecordSet.Add();
				FillPropertyValues(OriginalRecord, DuplicateRecord);
				FillPropertyValues(OriginalRecord, OriginalDimensionValues);
			Else
				OriginalRecord = OriginalRecordSet[0];
			EndIf;
		Else
			// Write to the source.
			OriginalRecordSet = DuplicateRecordSet;
			OriginalRecord = DuplicateRecord; // The zero record set case is processed above.
		EndIf;
		
		// Substituting the original for duplicate in resource and attributes.
		For Each KeyValue In Information.Resources Do
			AttributeValueInOriginal = OriginalRecord[KeyValue.Key];
			If AttributeValueInOriginal = Duplicate1 Then
				OriginalRecord[KeyValue.Key] = Original;
			EndIf;
		EndDo;
		For Each KeyValue In Information.Attributes Do
			AttributeValueInOriginal = OriginalRecord[KeyValue.Key];
			If AttributeValueInOriginal = Duplicate1 Then
				OriginalRecord[KeyValue.Key] = Original;
			EndIf;
		EndDo;
		
		If Not ExecutionParameters.WriteInPrivilegedMode Then
			SetPrivilegedMode(False);
		EndIf;
		
		// Delete the duplicate data.
		If TwoSetsRequired Then
			DuplicateRecordSet.Clear();
			WriteObject(DuplicateRecordSet, ExecutionParameters);
		EndIf;
		
		// Write original object data.
		If OriginalRecordSet.Modified() Then
			WriteObject(OriginalRecordSet, ExecutionParameters);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		RegisterErrorInTable(Result, Duplicate1, Original, RegisterRecordKey, Information, 
			"LockForRegister", ErrorInfo());
	EndTry
	
EndProcedure

Function ModifiedObjectsOnReplaceInObject(ExecutionParameters, UsageInstance1, RowsToProcess)
	Data = UsageInstance1.Data;
	SequencesDetails = SequencesDetails(UsageInstance1.Metadata);
	RegisterRecordsDetails            = RegisterRecordsDetails(UsageInstance1.Metadata);
	TaskDetails				= TaskDetails(UsageInstance1.Metadata);
	
	SetPrivilegedMode(True);
	
	// Returning modified processed objects.
	Modified1 = New Map;
	
	// Read.
	LongDesc = ObjectDetails(Data.Metadata());
	Try
		Object = Data.GetObject();
	Except
		// Has already been processed with errors.
		Object = Undefined;
	EndTry;
	
	If Object = Undefined Then
		Return Modified1;
	EndIf;
	
	For Each RegisterRecordDetails In RegisterRecordsDetails Do
		RegisterRecordDetails.RecordSet.Filter.Recorder.Set(Data);
		RegisterRecordDetails.RecordSet.Read();
	EndDo;
	
	For Each SequenceDetails In SequencesDetails Do
		SequenceDetails.RecordSet.Filter.Recorder.Set(Data);
		SequenceDetails.RecordSet.Read();
	EndDo;
	
	// Replacing all at once.
	ReplacementPairs = New Map;
	For Each UsageInstance1 In RowsToProcess Do
		ReplacementPairs.Insert(UsageInstance1.Ref, UsageInstance1.DestinationRef);
	EndDo;
	
	ExecuteReplacementInObjectAttributes(Object, LongDesc, ReplacementPairs);
		
	// Register records.
	For Each RegisterRecordDetails In RegisterRecordsDetails Do
		ReplaceInRowCollection(
			"RegisterRecords",
			RegisterRecordDetails.LockSpace,
			RegisterRecordDetails.RecordSet,
			RegisterRecordDetails.RecordSet,
			RegisterRecordDetails.FieldList,
			ReplacementPairs);
	EndDo;
	
	// Sequences
	For Each SequenceDetails In SequencesDetails Do
		ReplaceInRowCollection(
			"Sequences",
			SequenceDetails.LockSpace,
			SequenceDetails.RecordSet,
			SequenceDetails.RecordSet,
			SequenceDetails.FieldList,
			ReplacementPairs);
	EndDo;
	
	For Each RegisterRecordDetails In RegisterRecordsDetails Do
		If RegisterRecordDetails.RecordSet.Modified() Then
			Modified1.Insert(RegisterRecordDetails.RecordSet, False);
		EndIf;
	EndDo;
	
	For Each SequenceDetails In SequencesDetails Do
		If SequenceDetails.RecordSet.Modified() Then
			Modified1.Insert(SequenceDetails.RecordSet, False);
		EndIf;
	EndDo;
	
	If TaskDetails <> Undefined Then
	 	
		ProcessTask = ProcessTasks(Data, TaskDetails.LockSpace);
		While ProcessTask.Next() Do
			
			TaskObject = ProcessTask.Ref.GetObject();
			Filter = New Structure("Data, ReplacementKey", ProcessTask.Ref, "Object");
			TaskLinesToProcess = UsageInstance1.Owner().FindRows(Filter); // See UsageInstances
			For Each TaskUsageInstance In TaskLinesToProcess Do
				ReplacementPairs.Insert(TaskUsageInstance.Ref, TaskUsageInstance.DestinationRef);		
			EndDo;
			ExecuteReplacementInObjectAttributes(TaskObject, TaskDetails, ReplacementPairs);
			
			If TaskObject.Modified() Then
				Modified1.Insert(TaskObject, False);
			EndIf;
			
		EndDo;
	
	EndIf;
	
	// The object goes last in case a reposting is required.
	If Object.Modified() Then
		Modified1.Insert(Object, LongDesc.CanBePosted);
	EndIf;
	
	Return Modified1;
EndFunction

Function ProcessTasks(BusinessProcess, TasksType)

	QueryText = "SELECT
	|	TableName.Ref
	|FROM
	|	&TableName AS TableName
	|WHERE
	|	TableName.BusinessProcess = &BusinessProcess";
	QueryText = StrReplace(QueryText, "&TableName", TasksType);
	Query = New Query(QueryText);
	Query.SetParameter("BusinessProcess", BusinessProcess);
	Return Query.Execute().Select();

EndFunction

Procedure ExecuteReplacementInObjectAttributes(Object, LongDesc, ReplacementPairs)
	
	// Attributes
	For Each KeyValue In LongDesc.Attributes Do
		Name = KeyValue.Key;
		DestinationRef = ReplacementPairs[ Object[Name] ];
		If DestinationRef <> Undefined Then
			RegisterReplacement(Object, Object[Name], DestinationRef, "Attributes", Name);
			Object[Name] = DestinationRef;
		EndIf;
	EndDo;
	
	// Standard attributes.
	For Each KeyValue In LongDesc.StandardAttributes Do
		Name = KeyValue.Key;
		DestinationRef = ReplacementPairs[ Object[Name] ];
		If DestinationRef <> Undefined Then
			RegisterReplacement(Object, Object[Name], DestinationRef, "StandardAttributes", Name);
			Object[Name] = DestinationRef;
		EndIf;
	EndDo;
	
	// Tables.
	For Each Item In LongDesc.TabularSections Do
		ReplaceInRowCollection(
			"TabularSections",
			Item.Name,
			Object,
			Object[Item.Name],
			Item.FieldList,
			ReplacementPairs);
	EndDo;
	
	// Standard tables.
	For Each Item In LongDesc.StandardTabularSections Do
		ReplaceInRowCollection(
			"StandardTabularSections",
			Item.Name,
			Object,
			Object[Item.Name],
			Item.FieldList,
			ReplacementPairs);
	EndDo;

	For Each Attribute In LongDesc.AddressingAttributes Do
		Name = Attribute.Key;
		DestinationRef = ReplacementPairs[ Object[Name] ];
		If DestinationRef <> Undefined Then
			RegisterReplacement(Object, Object[Name], DestinationRef, "AddressingAttributes", Name);
			Object[Name] = DestinationRef;
		EndIf;
	EndDo;

EndProcedure

Procedure RegisterReplacement(Object, DuplicateRef, OriginalRef, AttributeKind, AttributeName, 
	IndexOf = Undefined, ColumnName = Undefined)
	
	HasAdditionalProperties = New Structure("AdditionalProperties");
	FillPropertyValues(HasAdditionalProperties, Object);
	If TypeOf(HasAdditionalProperties.AdditionalProperties) <> Type("Structure") Then
		Return;
	EndIf;
	
	AdditionalProperties = Object.AdditionalProperties;
	AdditionalProperties.Insert("ReferenceReplacement", True);
	CompletedReplacements = CommonClientServer.StructureProperty(AdditionalProperties, "CompletedReplacements");
	If CompletedReplacements = Undefined Then
		CompletedReplacements = New Array;
		AdditionalProperties.Insert("CompletedReplacements", CompletedReplacements);
	EndIf;
	
	ReplacementDetails = New Structure;
	ReplacementDetails.Insert("DuplicateRef", DuplicateRef);
	ReplacementDetails.Insert("OriginalRef", OriginalRef);
	ReplacementDetails.Insert("AttributeKind", AttributeKind);
	ReplacementDetails.Insert("AttributeName", AttributeName);
	ReplacementDetails.Insert("IndexOf", IndexOf);
	ReplacementDetails.Insert("ColumnName", ColumnName);
	CompletedReplacements.Add(ReplacementDetails);
	
EndProcedure

Procedure SetDeletionMarkForObjects(Result, Val RefsToDelete, Val ExecutionParameters)
	
	SetPrivilegedMode(True);
	HasExternalTransaction = TransactionActive();
	AllUsageInstances = UsageInstances(RefsToDelete,,ExecutionParameters.UsageInstancesSearchParameters);
	For Each RefToDelete In RefsToDelete Do
		Information = TypeInformation(TypeOf(RefToDelete), ExecutionParameters);
		Block = New DataLock;
		Block.Add(Information.FullName).SetValue("Ref", RefToDelete);
		
		BeginTransaction();
		Try
			IsLockError = True;
			Block.Lock();
			
			IsLockError = False;
 			Success = SetDeletionMark(Result, RefToDelete, AllUsageInstances, 
				ExecutionParameters, HasExternalTransaction);
			If Not Success Then
				RollbackTransaction();
				Continue;
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			If IsLockError Then 
				RegisterErrorInTable(Result, RefToDelete, Undefined, RefToDelete, Information, 
					"DataLockForDuplicateDeletion", ErrorInfo());
			EndIf;
			If HasExternalTransaction Then
				Raise;
			EndIf;	
		EndTry;
			
	EndDo;
	
EndProcedure

Function SetDeletionMark(Result, Val RefToDelete, Val AllUsageInstances, Val ExecutionParameters, 
	HasExternalTransaction)

	SetPrivilegedMode(True);
	
	RepresentationOfTheReference = SubjectString(RefToDelete);
	Filter = New Structure("Ref");
	Filter.Ref = RefToDelete;
	UsageInstances = AllUsageInstances.FindRows(Filter);
	
	IndexOf = UsageInstances.UBound();
	While IndexOf >= 0 Do
		If UsageInstances[IndexOf].AuxiliaryData Then
			UsageInstances.Delete(IndexOf);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	If UsageInstances.Count() > 0 Then
		AddModifiedObjectReplacementResults(Result, UsageInstances);
		Return False; // Cannot delete the object because other objects refer to it.
	EndIf;
	
	Object = RefToDelete.GetObject(); // DocumentObject, CatalogObject
	If Object = Undefined Then
		Return False; // Object has already been deleted.
	EndIf;
	
	If Not ExecutionParameters.WriteInPrivilegedMode Then
		SetPrivilegedMode(False);
	EndIf;
		
	Success = True;
	Try 
		WriteObjectWithMessageInterception(Object, "DeletionMark", Undefined, ExecutionParameters);
		Result.QueueForDirectDeletion.Add(Object.Ref);
	Except
		Success = False;
		ErrorInfo = ErrorInfo();
		Refinement = CommonClientServer.ExceptionClarification(ErrorInfo,
			NStr("en = 'Cannot mark the item for deletion. Reason:';"));
		Try
			Raise(Refinement.Text, Refinement.Category,,, ErrorInfo);
		Except
			ErrorDescription = ReplacementErrorDescription("DeletionError", RefToDelete, RepresentationOfTheReference, ErrorInfo());
			RegisterReplacementError(Result, RefToDelete, ErrorDescription);
			If HasExternalTransaction Then
				Raise;
			EndIf;	
		EndTry;
	EndTry;
	
	Return Success;
		
EndFunction

Procedure AddModifiedObjectReplacementResults(Result, RepeatSearchTable)
	
	Filter = New Structure("Ref, ErrorObject");
	For Each TableRow In RepeatSearchTable Do
		Test = New Structure("AuxiliaryData", False);
		FillPropertyValues(Test, TableRow);
		If Test.AuxiliaryData Then
			Continue;
		EndIf;
		
		Filter.ErrorObject = TableRow.Data;
		Filter.Ref       = TableRow.Ref;
		If Result.Errors.FindRows(Filter).Count() > 0 Then
			Continue; // Error on this issue has already been recorded.
		EndIf;

		RegisterReplacementError(Result, TableRow.Ref, 
			ReplacementErrorDescription("DataChanged1", TableRow.Data, SubjectString(TableRow.Data),
				NStr("en = 'Some of the instances were not replaced. Probably these instances were added or edited by other users.';")));
	EndDo;
	
EndProcedure

Procedure LockUsageInstance(ExecutionParameters, Block, UsageInstance1)
	
	If UsageInstance1.ReplacementKey = "Constant" Then
		
		Block.Add(UsageInstance1.Metadata.FullName());
		
	ElsIf UsageInstance1.ReplacementKey = "Object" Then
		
		ObjectRef2     = UsageInstance1.Data;
		ObjectMetadata = UsageInstance1.Metadata;
		
		// The object.
		Block.Add(ObjectMetadata.FullName()).SetValue("Ref", ObjectRef2);
		
		// Register records by recorder.
		RegisterRecordsDetails = RegisterRecordsDetails(ObjectMetadata);
		For Each Item In RegisterRecordsDetails Do
			Block.Add(Item.LockSpace + ".RecordSet").SetValue("Recorder", ObjectRef2);
		EndDo;
		
		// Sequences.
		SequencesDetails = SequencesDetails(ObjectMetadata);
		For Each Item In SequencesDetails Do
			Block.Add(Item.LockSpace).SetValue("Recorder", ObjectRef2);
		EndDo;
		
		// Business process tasks.
		TaskDetails = TaskDetails(ObjectMetadata);
		If TaskDetails <> Undefined Then
			Block.Add(TaskDetails.LockSpace).SetValue("BusinessProcess", ObjectRef2);	
		EndIf;
		
	ElsIf UsageInstance1.ReplacementKey = "Sequence" Then
		
		ObjectRef2     = UsageInstance1.Data;
		ObjectMetadata = UsageInstance1.Metadata;
		
		SequencesDetails = SequencesDetails(ObjectMetadata);
		For Each Item In SequencesDetails Do
			Block.Add(Item.LockSpace).SetValue("Recorder", ObjectRef2);
		EndDo;
		
	ElsIf UsageInstance1.ReplacementKey = "RecordKey"
		Or UsageInstance1.ReplacementKey = "InformationRegister" Then
		
		Information = TypeInformation(UsageInstance1.Metadata, ExecutionParameters);
		DuplicateType = UsageInstance1.RefType;
		OriginalType = TypeOf(UsageInstance1.DestinationRef);
		
		For Each KeyValue In Information.Dimensions Do
			DimensionType = KeyValue.Value.Type;
			If DimensionType.ContainsType(DuplicateType) Then
				DataLockByDimension = Block.Add(Information.FullName);
				DataLockByDimension.SetValue(KeyValue.Key, UsageInstance1.Ref);
			EndIf;
			If DimensionType.ContainsType(OriginalType) Then
				DataLockByDimension = Block.Add(Information.FullName);
				DataLockByDimension.SetValue(KeyValue.Key, UsageInstance1.DestinationRef);
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure DisableAccessKeysUpdate(Value)
	
	If SubsystemExists("StandardSubsystems.AccessManagement") Then
		SetPrivilegedMode(True);
		ModuleAccessManagement = CommonModule("AccessManagement");
		ModuleAccessManagement.DisableAccessKeysUpdate(Value);
	EndIf;
	
EndProcedure	

// Parameters:
//   MetadataObject - MetadataObject
// 	
// Returns:
//  Array of Structure:
//   * FieldList - Structure
//   * DimensionStructure - Structure
//   * MasterDimentionList - Structure
//   * RecordSet - InformationRegisterRecordSet
//   * LockSpace - String
//
Function RegisterRecordsDetails(Val MetadataObject)
	
	RegisterRecordsDetails = New Array;
	If Not Metadata.Documents.Contains(MetadataObject) Then
		Return RegisterRecordsDetails;
	EndIf;
	
	For Each Movement In MetadataObject.RegisterRecords Do
		
		If Metadata.AccumulationRegisters.Contains(Movement) Then
			RecordSet = AccumulationRegisters[Movement.Name].CreateRecordSet();
			ExcludeFields = "Active, LineNumber, Period, Recorder"; 
			
		ElsIf Metadata.InformationRegisters.Contains(Movement) Then
			RecordSet = InformationRegisters[Movement.Name].CreateRecordSet();
			ExcludeFields = "Active, RecordType, LineNumber, Period, Recorder"; 
			
		ElsIf Metadata.AccountingRegisters.Contains(Movement) Then
			RecordSet = AccountingRegisters[Movement.Name].CreateRecordSet();
			ExcludeFields = "Active, RecordType, LineNumber, Period, Recorder"; 
			
		ElsIf Metadata.CalculationRegisters.Contains(Movement) Then
			RecordSet = CalculationRegisters[Movement.Name].CreateRecordSet();
			ExcludeFields = "Active, EndOfBasePeriod, BegOfBasePeriod, LineNumber, ActionPeriod,
			                |EndOfActionPeriod, BegOfActionPeriod, RegistrationPeriod, Recorder, ReversingEntry,
			                |ActualActionPeriod";
		Else
			// Unknown type.
			Continue;
		EndIf;
		
		// Ref fields and candidate dimensions.
		// @skip-check query-in-loop - An empty request to obtain a list of table fields.
		LongDesc = ObjectFieldLists(RecordSet, Movement.Dimensions, ExcludeFields);
		If LongDesc.FieldList.Count() = 0 Then
			// No need to process.
			Continue;
		EndIf;
		
		LongDesc.Insert("RecordSet", RecordSet);
		LongDesc.Insert("LockSpace", Movement.FullName() );
		
		RegisterRecordsDetails.Add(LongDesc);
	EndDo;
	
	Return RegisterRecordsDetails;
EndFunction

// Parameters:
//  Meta - MetadataObject
// 
// Returns:
//  Array of Structure:
//    * RecordSet - SequenceRecordSet
//    * LockSpace - String
//    * Dimensions - Structure
// 
Function SequencesDetails(Val Meta)
	
	SequencesDetails = New Array;
	If Not Metadata.Documents.Contains(Meta) Then
		Return SequencesDetails;
	EndIf;
	
	For Each Sequence In Metadata.Sequences Do
		If Not Sequence.Documents.Contains(Meta) Then
			Continue;
		EndIf;
		
		TableName = Sequence.FullName();
		
		// @skip-check query-in-loop - Empty query for obtaining the list of table fields.
		LongDesc = ObjectFieldLists(TableName, Sequence.Dimensions, "Recorder");
		If LongDesc.FieldList.Count() > 0 Then
			
			LongDesc.Insert("RecordSet",           Sequences[Sequence.Name].CreateRecordSet());
			LongDesc.Insert("LockSpace", TableName + ".Records");
			LongDesc.Insert("Dimensions",              New Structure);
			
			SequencesDetails.Add(LongDesc);
		EndIf;
		
	EndDo;
	
	Return SequencesDetails;
EndFunction

// Returns:
//   Structure:
//   * StandardAttributes - Structure
//   * AddressingAttributes - Structure
//   * Attributes - Structure
//   * StandardTabularSections - Array of Structure:
//    ** Name - String
//    ** FieldList - Structure
//   * TabularSections - Array of Structure:
//    ** Name - String
//    ** FieldList - Structure
//   * CanBePosted - Boolean
//
Function ObjectDetails(Val MetadataObject)
	
	AllRefsType = AllRefsTypeDetails();
	
	Candidates = New Structure("Attributes, StandardAttributes, TabularSections, StandardTabularSections, AddressingAttributes");
	FillPropertyValues(Candidates, MetadataObject);
	
	ObjectDetails = New Structure;
	
	ObjectDetails.Insert("Attributes", New Structure);
	If Candidates.Attributes <> Undefined Then
		For Each MetaAttribute In Candidates.Attributes Do
			If DescriptionTypesOverlap(MetaAttribute.Type, AllRefsType) Then
				ObjectDetails.Attributes.Insert(MetaAttribute.Name);
			EndIf;
		EndDo;
	EndIf;
	
	ObjectDetails.Insert("StandardAttributes", New Structure);
	If Candidates.StandardAttributes <> Undefined Then
		ToExclude = New Structure("Ref");
		
		For Each MetaAttribute In Candidates.StandardAttributes Do
			Name = MetaAttribute.Name;
			If Not ToExclude.Property(Name) And DescriptionTypesOverlap(MetaAttribute.Type, AllRefsType) Then
				ObjectDetails.Attributes.Insert(MetaAttribute.Name);
			EndIf;
		EndDo;
	EndIf;
	
	ObjectDetails.Insert("TabularSections", New Array);
	If Candidates.TabularSections <> Undefined Then
		For Each MetaTable In Candidates.TabularSections Do
			
			FieldList = New Structure;
			For Each MetaAttribute In MetaTable.Attributes Do
				If DescriptionTypesOverlap(MetaAttribute.Type, AllRefsType) Then
					FieldList.Insert(MetaAttribute.Name);
				EndIf;
			EndDo;
			
			If FieldList.Count() > 0 Then
				ObjectDetails.TabularSections.Add(New Structure("Name, FieldList", MetaTable.Name, FieldList));
			EndIf;
		EndDo;
	EndIf;
	
	ObjectDetails.Insert("StandardTabularSections", New Array);
	If Candidates.StandardTabularSections <> Undefined Then
		For Each MetaTable In Candidates.StandardTabularSections Do
			
			FieldList = New Structure;
			For Each MetaAttribute In MetaTable.StandardAttributes Do
				If DescriptionTypesOverlap(MetaAttribute.Type, AllRefsType) Then
					FieldList.Insert(MetaAttribute.Name);
				EndIf;
			EndDo;
			
			If FieldList.Count() > 0 Then
				ObjectDetails.StandardTabularSections.Add(New Structure("Name, FieldList", MetaTable.Name, FieldList));
			EndIf;
		EndDo;
	EndIf;
	
	ObjectDetails.Insert("AddressingAttributes", New Structure);
	If Candidates.AddressingAttributes <> Undefined Then
		For Each Attribute In Candidates.AddressingAttributes Do
			If DescriptionTypesOverlap(Attribute.Type, AllRefsType) Then
				ObjectDetails.AddressingAttributes.Insert(Attribute.Name);
			EndIf;
		EndDo;
	EndIf;
	
	ObjectDetails.Insert("CanBePosted", Metadata.Documents.Contains(MetadataObject));
	Return ObjectDetails;
EndFunction

// Parameters:
//   MetadataObject - MetadataObject
// 	
// Returns:
//  Array of Structure:
//   * FieldList - Structure
//   * DimensionStructure - Structure
//   * MasterDimentionList - Structure
//   * RecordSet - InformationRegisterRecordSet
//   * LockSpace - String
//
Function TaskDetails(Val Meta)

	TaskDetails = Undefined;
	If Not Metadata.BusinessProcesses.Contains(Meta) Then
		Return TaskDetails;
	EndIf;
	
	TaskDetails = ObjectDetails(Meta.Task);
	TaskDetails.Insert("LockSpace", Meta.Task.FullName());
	
	Return TaskDetails;

EndFunction

Function RecordKeyDetails(Val MetadataTables)
	
	TableName = MetadataTables.FullName();
	
	// Candidate Ref fields and a dimension set.
	// @skip-check query-in-loop - An empty request to obtain a list of table fields.
	KeyDetails = ObjectFieldLists(TableName, MetadataTables.Dimensions, "Period, Recorder");
	
	If Metadata.InformationRegisters.Contains(MetadataTables) Then
		RecordSet = InformationRegisters[MetadataTables.Name].CreateRecordSet();
	ElsIf Metadata.AccumulationRegisters.Contains(MetadataTables) Then
		RecordSet = AccumulationRegisters[MetadataTables.Name].CreateRecordSet();
	ElsIf Metadata.AccountingRegisters.Contains(MetadataTables) Then
		RecordSet = AccountingRegisters[MetadataTables.Name].CreateRecordSet();
	ElsIf Metadata.CalculationRegisters.Contains(MetadataTables) Then
		RecordSet = CalculationRegisters[MetadataTables.Name].CreateRecordSet();
	ElsIf Metadata.Sequences.Contains(MetadataTables) Then
		RecordSet = Sequences[MetadataTables.Name].CreateRecordSet();
	Else
		RecordSet = Undefined;
	EndIf;
	
	KeyDetails.Insert("RecordSet", RecordSet);
	KeyDetails.Insert("LockSpace", TableName);
	
	Return KeyDetails;
EndFunction

Function DescriptionTypesOverlap(Val LongDesc1, Val LongDesc2)
	
	For Each Type In LongDesc1.Types() Do
		If LongDesc2.ContainsType(Type) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
EndFunction

// Returns a description by the table name or by the record set.
Function ObjectFieldLists(Val DataSource, Val RegisterDimensionsMetadata, Val ExcludeFields)
	
	LongDesc = New Structure;
	LongDesc.Insert("FieldList",     New Structure);
	LongDesc.Insert("DimensionStructure", New Structure);
	LongDesc.Insert("MasterDimentionList",   New Structure);
	
	ControlType = AllRefsTypeDetails();
	ToExclude = New Structure(ExcludeFields);
	
	DataSourceType = TypeOf(DataSource);
	
	If DataSourceType = Type("String") Then
		// The source is the table name. The fields are received with a query.
		QueryText = "SELECT * FROM &TableName WHERE FALSE";
		QueryText = StrReplace(QueryText, "&TableName", DataSource);
		Query = New Query(QueryText);
		FieldSource = Query.Execute();
	Else
		// The source is a record set.
		FieldSource = DataSource.UnloadColumns();
	EndIf;
	
	For Each Column In FieldSource.Columns Do
		Name = Column.Name;
		If Not ToExclude.Property(Name) And DescriptionTypesOverlap(Column.ValueType, ControlType) Then
			LongDesc.FieldList.Insert(Name);
			
			// Checking for a master dimension.
			Meta = RegisterDimensionsMetadata.Find(Name);
			If Meta <> Undefined Then
				LongDesc.DimensionStructure.Insert(Name, Meta.Type);
				Test = New Structure("Master", False);
				FillPropertyValues(Test, Meta);
				If Test.Master Then
					LongDesc.MasterDimentionList.Insert(Name, Meta.Type);
				EndIf;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return LongDesc;
EndFunction


Procedure ReplaceInRowCollection(CollectionKind, CollectionName, Object, Collection, Val FieldList, Val ReplacementPairs)
	
	ChangedCollection = Collection.Unload();
	Modified2 = False;
	ModifiedAttributesNames = New Array;
	
	For Each TableRow In ChangedCollection Do
		
		For Each KeyValue In FieldList Do
			AttributeName = KeyValue.Key;
			DestinationRef = ReplacementPairs[ TableRow[AttributeName] ];
			If DestinationRef <> Undefined Then
				RegisterReplacement(Object, TableRow[AttributeName], DestinationRef, CollectionKind, CollectionName, 
					ChangedCollection.IndexOf(TableRow), AttributeName);
				TableRow[AttributeName] = DestinationRef;
				Modified2 = True;
				ModifiedAttributesNames.Add(AttributeName);
			EndIf;
		EndDo;
		
	EndDo;
		
	If Modified2 Then
		IsAccountingRegister = CollectionKind = "RegisterRecords" And IsAccountingRegister(Collection.Metadata());
		If IsAccountingRegister Then
			ImportModifiedSetToAccountingRegister(Collection, ChangedCollection, ModifiedAttributesNames);
		Else	
			Collection.Load(ChangedCollection);
		EndIf;
	EndIf;
EndProcedure

Procedure ImportModifiedSetToAccountingRegister(RecordSet, ChangedCollection, ModifiedAttributesNames)
	NotModifiedDimensions = New Map;
	ChangedDimensions = New Map;
	RegisterMetadata = RecordSet.Metadata();
	
	For Each Dimension In RegisterMetadata.Dimensions Do
		DimensionsNames = New Array;
		
		If Dimension.Balance Or Not RegisterMetadata.Correspondence Then
			DimensionsNames.Add(Dimension.Name);			
		Else	
			DimensionsNames.Add(Dimension.Name + "Dr");
			DimensionsNames.Add(Dimension.Name + "Cr");		
		EndIf;
		
		For Each DimensionName In DimensionsNames Do
			If ModifiedAttributesNames.Find(DimensionName) = Undefined Then
				NotModifiedDimensions.Insert(DimensionName, RecordSet.UnloadColumn(DimensionName));
			Else
				ChangedDimensions.Insert(DimensionName, RecordSet.UnloadColumn(DimensionName));
			EndIf;
		EndDo;
	EndDo;
	
	For Cnt = 0 To RecordSet.Count()-1 Do
	
		For Each ValueDimensionName In ChangedDimensions Do
			If RecordSet[Cnt][ValueDimensionName.Key] = NULL Then
				ValueDimensionName.Value[Cnt] = NULL;
			Else
				ValueDimensionName.Value[Cnt] = ChangedCollection[Cnt][ValueDimensionName.Key];
			EndIf;
		EndDo;
	
	EndDo;
	
	RecordSet.Load(ChangedCollection);
	
	For Each ValueDimensionsInColumn In NotModifiedDimensions Do
		RecordSet.LoadColumn(ValueDimensionsInColumn.Value, ValueDimensionsInColumn.Key);
	EndDo;
	
	For Each ValueDimensionsInColumn In ChangedDimensions Do
		RecordSet.LoadColumn(ValueDimensionsInColumn.Value, ValueDimensionsInColumn.Key);
	EndDo;
EndProcedure

Procedure WriteObjectWithMessageInterception(Val Object, Val Action, Val WriteMode, Val WriteParameters)
	
	// Save the current messages before the exception.
	PreviousMessages = GetUserMessages(True);
	ReportAgain    = CurrentRunMode() <> Undefined;
	
	Try
		
		If Action = "Record" Then
			
			Object.DataExchange.Load = Not WriteParameters.IncludeBusinessLogic;
			
			If WriteMode = Undefined Then
				Object.Write();
			Else
				Object.Write(WriteMode);
			EndIf;
			
		ElsIf Action = "DeletionMark" Then
			
			ObjectMetadata = Object.Metadata();
			If IsCatalog(ObjectMetadata)
				Or IsChartOfCharacteristicTypes(ObjectMetadata)
				Or IsChartOfAccounts(ObjectMetadata) Then 
				
				Object.DataExchange.Load = Not WriteParameters.IncludeBusinessLogic;
				Object.SetDeletionMark(True, False);
			ElsIf IsDocument(ObjectMetadata) 
				And ObjectMetadata.Posting = Metadata.ObjectProperties.Posting.Allow Then
				
				Object.SetDeletionMark(True);
			Else
				Object.DataExchange.Load = Not WriteParameters.IncludeBusinessLogic;
				Object.SetDeletionMark(True);
			EndIf;
			
		EndIf;
		
	Except
		MessagesText = "";
		For Each Message In GetUserMessages(False) Do
			MessagesText = MessagesText + Chars.LF + Message.Text;
		EndDo;
		
		If ReportAgain Then
			ReportDeferredMessages(PreviousMessages);
		EndIf;
		
		If MessagesText = "" Then
			Raise;
		EndIf;
		ErrorInfo = ErrorInfo();
		Refinement = CommonClientServer.ExceptionClarification(ErrorInfo);
		Refinement.Text = Refinement.Text + Chars.LF + TrimAll(MessagesText);
		Raise(Refinement.Text, Refinement.Category,,, ErrorInfo);
	EndTry;
	
	If ReportAgain Then
		ReportDeferredMessages(PreviousMessages);
	EndIf;
	
EndProcedure

Procedure ReportDeferredMessages(Val Messages)
	
	For Each Message In Messages Do
		Message.Message();
	EndDo;
	
EndProcedure

Procedure WriteObject(Val Object, Val WriteParameters)
	
	ObjectMetadata = Object.Metadata();
	
	If IsDocument(ObjectMetadata) Then
		WriteObjectWithMessageInterception(Object, "Record", DocumentWriteMode.Write, WriteParameters);
		Return;
	EndIf;
	
	// Checking for loop references.
	ObjectProperties = New Structure("Hierarchical, ExtDimensionTypes, Owners", False, Undefined, New Array);
	FillPropertyValues(ObjectProperties, ObjectMetadata);
	
	// Check the parent.
	If ObjectProperties.Hierarchical Or ObjectProperties.ExtDimensionTypes <> Undefined Then 
		
		If Object.Parent = Object.Ref Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot write ""%1"" because it cannot be its own parent element.';"),
				SubjectString(Object));
			EndIf;
			
	EndIf;
	
	// Check the owner.
	If ObjectProperties.Owners.Count() > 1 And Object.Owner = Object.Ref Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot write ""%1"" because it cannot own itself.';"),
			SubjectString(Object));
	EndIf;
	
	// For sequences, the Update right can be absent even in the SystemAdministrator role.
	If IsSequence(ObjectMetadata)
		And Not AccessRight("Update", ObjectMetadata)
		And Users.IsFullUser(,, False) Then
		
		SetPrivilegedMode(True);
	EndIf;
	
	WriteObjectWithMessageInterception(Object, "Record", Undefined, WriteParameters);
EndProcedure

Function RefReplacementEventLogMessageText()
	
	Return NStr("en = 'Searching for references and deleting them';", DefaultLanguageCode());
	
EndFunction

// Parameters:
//   Result - See TheResultOfReplacingLinks 
//   Ref - AnyRef
//   ErrorDescription - See ReplacementErrorDescription
//
Procedure RegisterReplacementError(Result, Val Ref, Val ErrorDescription)
	
	Result.HasErrors = True;
	
	String = Result.Errors.Add();
	String.Ref = Ref;
	String.ErrorObjectPresentation = ErrorDescription.ErrorObjectPresentation;
	String.ErrorObject               = ErrorDescription.ErrorObject;
	String.ErrorInfo         = ?(TypeOf(ErrorDescription.ErrorInfo) = Type("ErrorInfo"), 
		ErrorDescription.ErrorInfo, Undefined);
	String.ErrorText                = ?(TypeOf(ErrorDescription.ErrorInfo) = Type("ErrorInfo"),
		ErrorProcessing.BriefErrorDescription(ErrorDescription.ErrorInfo), ErrorDescription.ErrorInfo);
	String.ErrorType                  = ErrorDescription.ErrorType;
	
EndProcedure

// Returns:
//   Structure:
//    * ErrorType - String
//    * ErrorObject - AnyRef
//    * ErrorObjectPresentation - String
//    * ErrorInfo - ErrorInfo, String
//
Function ReplacementErrorDescription(Val ErrorType, Val ErrorObject, Val ErrorObjectPresentation, Val ErrorInfo)

	Result = New Structure;
	Result.Insert("ErrorType",                  ErrorType);
	Result.Insert("ErrorObject",               ErrorObject);
	Result.Insert("ErrorObjectPresentation", ErrorObjectPresentation);
	Result.Insert("ErrorInfo",         ErrorInfo);
	Return Result;

EndFunction

// Returns:
//   Structure:
//     * HasErrors - Boolean
//     * QueueForDirectDeletion - Array
//     * Errors - See Common.ReplaceReferences
//
Function TheResultOfReplacingLinks(Val ReplacementErrors)

	Result = New Structure;
	Result.Insert("HasErrors", False);
	Result.Insert("QueueForDirectDeletion", New Array);
	Result.Insert("Errors", ReplacementErrors);
	Return Result
	
EndFunction

Procedure RegisterErrorInTable(Result, Duplicate1, Original, Data, Information, ErrorType, ErrorInfo)
	Result.HasErrors = True;
	
	WriteLogEvent(RefReplacementEventLogMessageText(),
		EventLogLevel.Error,,,
		ErrorProcessing.DetailErrorDescription(ErrorInfo));
	
	FullDataPresentation = String(Data) + " (" + Information.ItemPresentation + ")";
	
	Error = Result.Errors.Add();
	Error.Ref       = Duplicate1;
	Error.ErrorObject = Data;
	Error.ErrorObjectPresentation = FullDataPresentation;
	
	If ErrorType = "LockForRegister" Then
		NewTemplate = NStr("en = 'Cannot start editing %1: %2';");
		Error.ErrorType = "LockError";
	ElsIf ErrorType = "DataLockForDuplicateDeletion" Then
		NewTemplate = NStr("en = 'Cannot start deletion: %2';");
		Error.ErrorType = "LockError";
	ElsIf ErrorType = "DeleteDuplicateSet" Then
		NewTemplate = NStr("en = 'Cannot clear duplicate''s details in %1: %2';");
		Error.ErrorType = "WritingError";
	ElsIf ErrorType = "WriteOriginalSet" Then
		NewTemplate = NStr("en = 'Cannot update information in %1: %2';");
		Error.ErrorType = "WritingError";
	Else
		NewTemplate = ErrorType + " (%1): %2";
		Error.ErrorType = ErrorType;
	EndIf;
	
	NewTemplate = NewTemplate + Chars.LF + Chars.LF + NStr("en = 'See the Event log for details.';");
	
	BriefPresentation = ErrorProcessing.BriefErrorDescription(ErrorInfo);
	Error.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NewTemplate, FullDataPresentation, BriefPresentation);
	
EndProcedure

// Generates details on the metadata object type: full name, presentations, kind, and so on.
Function TypeInformation(FullNameOrMetadataOrType, Cache)
	FirstParameterType = TypeOf(FullNameOrMetadataOrType);
	If FirstParameterType = Type("String") Then
		MetadataObject = MetadataObjectByFullName(FullNameOrMetadataOrType);
	Else
		If FirstParameterType = Type("Type") Then // Search for the metadata object.
			MetadataObject = Metadata.FindByType(FullNameOrMetadataOrType);
		Else
			MetadataObject = FullNameOrMetadataOrType;
		EndIf;
	EndIf;
	FullName = Upper(MetadataObject.FullName());
	
	TypesInformation = CommonClientServer.StructureProperty(Cache, "TypesInformation");
	If TypesInformation = Undefined Then
		TypesInformation = New Map;
		Cache.Insert("TypesInformation", TypesInformation);
	Else
		Information = TypesInformation.Get(FullName);
		If Information <> Undefined Then
			Return Information;
		EndIf;
	EndIf;
	
	Information = New Structure("FullName, ItemPresentation, 
	|Kind, Referential, Technical, Separated1,
	|Hierarchical,
	|HasSubordinateItems, SubordinatesNames,
	|Dimensions, Attributes, Resources");
	TypesInformation.Insert(FullName, Information);
	
	// Populate basic information.
	Information.FullName = FullName;
	
	// Item presentation.
	Information.ItemPresentation = ObjectPresentation(MetadataObject);
	
	// Kind and its properties.
	Information.Kind = Left(Information.FullName, StrFind(Information.FullName, ".")-1);
	If Information.Kind = "CATALOG"
		Or Information.Kind = "DOCUMENT"
		Or Information.Kind = "ENUM"
		Or Information.Kind = "CHARTOFCHARACTERISTICTYPES"
		Or Information.Kind = "CHARTOFACCOUNTS"
		Or Information.Kind = "CHARTOFCALCULATIONTYPES"
		Or Information.Kind = "BUSINESSPROCESS"
		Or Information.Kind = "TASK"
		Or Information.Kind = "EXCHANGEPLAN" Then
		Information.Referential = True;
	Else
		Information.Referential = False;
	EndIf;
	
	If Information.Kind = "CATALOG"
		Or Information.Kind = "CHARTOFCHARACTERISTICTYPES" Then
		Information.Hierarchical = MetadataObject.Hierarchical;
	ElsIf Information.Kind = "CHARTOFACCOUNTS" Then
		Information.Hierarchical = True;
	Else
		Information.Hierarchical = False;
	EndIf;
	
	Information.HasSubordinateItems = False;
	If Information.Kind = "CATALOG"
		Or Information.Kind = "CHARTOFCHARACTERISTICTYPES"
		Or Information.Kind = "EXCHANGEPLAN"
		Or Information.Kind = "CHARTOFACCOUNTS"
		Or Information.Kind = "CHARTOFCALCULATIONTYPES" Then
		For Each Catalog In Metadata.Catalogs Do
			If Catalog.Owners.Contains(MetadataObject) Then
				If Information.HasSubordinateItems = False Then
					Information.HasSubordinateItems = True;
					Information.SubordinatesNames = New Array;
				EndIf;
				SubordinatesNames = Information.SubordinatesNames;  // Array - 
				SubordinatesNames.Add(Catalog.FullName());
			EndIf;
		EndDo;
	EndIf;
	
	If Information.FullName = "CATALOG.METADATAOBJECTIDS"
		Or Information.FullName = "CATALOG.PREDEFINEDREPORTSOPTIONS" Then
		Information.Technical = True;
		Information.Separated1 = False;
	Else
		Information.Technical = False;
		If Not Cache.Property("SaaSModel") Then
			Cache.Insert("SaaSModel", DataSeparationEnabled());
			If Cache.SaaSModel Then
				
				If SubsystemExists("CloudTechnology.Core") Then
					ModuleSaaSOperations = CommonModule("SaaSOperations");
					MainDataSeparator = ModuleSaaSOperations.MainDataSeparator();
					AuxiliaryDataSeparator = ModuleSaaSOperations.AuxiliaryDataSeparator();
				Else
					MainDataSeparator = Undefined;
					AuxiliaryDataSeparator = Undefined;
				EndIf;
				
				Cache.Insert("InDataArea", DataSeparationEnabled() And SeparatedDataUsageAvailable());
				Cache.Insert("MainDataSeparator",        MainDataSeparator);
				Cache.Insert("AuxiliaryDataSeparator", AuxiliaryDataSeparator);
			EndIf;
		EndIf;
		If Cache.SaaSModel Then
			If SubsystemExists("CloudTechnology.Core") Then
				ModuleSaaSOperations = CommonModule("SaaSOperations");
				IsSeparatedMetadataObject = ModuleSaaSOperations.IsSeparatedMetadataObject(MetadataObject);
			Else
				IsSeparatedMetadataObject = True;
			EndIf;
			Information.Separated1 = IsSeparatedMetadataObject;
		EndIf;
	EndIf;
	
	Information.Dimensions = New Structure;
	Information.Attributes = New Structure;
	Information.Resources = New Structure;
	
	AttributesKinds = New Structure("StandardAttributes, Attributes, Dimensions, Resources");
	FillPropertyValues(AttributesKinds, MetadataObject);
	For Each KeyAndValue In AttributesKinds Do
		Collection = KeyAndValue.Value; // MetadataObjectCollection
		If TypeOf(Collection) = Type("MetadataObjectCollection") Then
			WhereToWrite = ?(Information.Property(KeyAndValue.Key), Information[KeyAndValue.Key], Information.Attributes);
			For Each Attribute In Collection Do
				WhereToWrite.Insert(Attribute.Name, AttributeInformation1(Attribute));
			EndDo;
		EndIf;
	EndDo;
	If Information.Kind = "INFORMATIONREGISTER"
		And MetadataObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
		AttributeInformation1 = New Structure("Master, Presentation, Format, Type, DefaultValue, FillFromFillingValue");
		AttributeInformation1.Master = False;
		AttributeInformation1.FillFromFillingValue = False;
		If MetadataObject.InformationRegisterPeriodicity = Metadata.ObjectProperties.InformationRegisterPeriodicity.RecorderPosition Then
			AttributeInformation1.Type = New TypeDescription("PointInTime");
		ElsIf MetadataObject.InformationRegisterPeriodicity = Metadata.ObjectProperties.InformationRegisterPeriodicity.Second Then
			AttributeInformation1.Type = New TypeDescription("Date", , , New DateQualifiers(DateFractions.DateTime));
		Else
			AttributeInformation1.Type = New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date));
		EndIf;
		Information.Dimensions.Insert("Period", AttributeInformation1);
	EndIf;
	
	Return Information;
EndFunction

// Parameters:
//   AttributeMetadata - MetadataObjectAttribute
// 
Function AttributeInformation1(AttributeMetadata)
	// StandardAttributeDetails
	// MetadataObject: Dimension
	// MetadataObject: Resource
	// MetadataObject: Attribute
	Information = New Structure("Master, Presentation, Format, Type, DefaultValue, FillFromFillingValue");
	FillPropertyValues(Information, AttributeMetadata);
	Information.Presentation = AttributeMetadata.Presentation();
	If Information.FillFromFillingValue = True Then
		Information.DefaultValue = AttributeMetadata.FillValue;
	Else
		Information.DefaultValue = AttributeMetadata.Type.AdjustValue();
	EndIf;
	Return Information;
EndFunction

Procedure AddToReferenceReplacementStatistics(Statistics, Duplicate1, HasErrors)

	DuplicateKey = Duplicate1.Metadata().FullName();
	StatisticsItem = Statistics[DuplicateKey];
	If StatisticsItem = Undefined Then
	     StatisticsItem = New Structure("ItemCount, ErrorsCount",0,0);
		 Statistics.Insert(DuplicateKey, StatisticsItem);
	 EndIf;
	 
	 StatisticsItem.ItemCount = StatisticsItem.ItemCount + 1;
	 StatisticsItem.ErrorsCount = StatisticsItem.ErrorsCount + ?(HasErrors, 1,0);

EndProcedure

Procedure SendReferenceReplacementStatistics(Statistics)

	If Not SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		Return;
	EndIf;	
	
	ModuleMonitoringCenter = CommonModule("MonitoringCenter");
	For Each StatisticsItem In Statistics Do
		ModuleMonitoringCenter.WriteBusinessStatisticsOperation(
			"Core.ReferenceReplacement." + StatisticsItem.Key, StatisticsItem.Value.ItemCount);
		ModuleMonitoringCenter.WriteBusinessStatisticsOperation(
			"Core.ReferenceReplacementErrorsCount." + StatisticsItem.Key, StatisticsItem.Value.ErrorsCount);
	EndDo;

EndProcedure

Procedure SupplementSubordinateObjectsRefSearchExceptions(Val RefSearchExclusions)
	
	For Each SubordinateObjectDetails In SubordinateObjects() Do
		
		LinkFields = StringFunctionsClientServer.SplitStringIntoSubstringsArray(
			SubordinateObjectDetails.LinksFields, ",",, True);
		ValueRefSearchExceptions = New Array;
		For Each LinksField In LinkFields Do
			ValueRefSearchExceptions.Add(LinksField);
		EndDo;
		RefSearchExclusions.Insert(SubordinateObjectDetails.SubordinateObject, ValueRefSearchExceptions);
		
	EndDo;

EndProcedure

Procedure RegisterDeletionErrors(Result, ObjectsPreventingDeletion)

	RefsPresentations = SubjectAsString(ObjectsPreventingDeletion.UnloadColumn("UsageInstance1"));	
	For Each ObjectsPreventingDeletion In ObjectsPreventingDeletion Do
		ErrorText = NStr("en = 'An item is not deleted since there are references to it.';");
		ErrorDescription = ReplacementErrorDescription("DeletionError", ObjectsPreventingDeletion.UsageInstance1, 
			RefsPresentations[ObjectsPreventingDeletion.UsageInstance1], ErrorText);
		RegisterReplacementError(Result, ObjectsPreventingDeletion.ItemToDeleteRef, ErrorDescription);
	EndDo;

EndProcedure

Function GenerateDuplicates(ExecutionParameters, ReplacementParameters, ReplacementPairs, Result)
	
	Duplicates = New Array;
	For Each KeyValue In ReplacementPairs Do
		Duplicate1 = KeyValue.Key;
		Original = KeyValue.Value;
		If Duplicate1 = Original Or Duplicate1.IsEmpty() Then
			Continue; // Not replacing self-references and empty references.
		EndIf;
		Duplicates.Add(Duplicate1);
		// Skipping intermediate replacements to avoid building a graph (if A->B and B->C, replacing A->C).
		OriginalOriginal = ReplacementPairs[Original];
		HasOriginalOriginal = (OriginalOriginal <> Undefined And OriginalOriginal <> Duplicate1 And OriginalOriginal <> Original);
		If HasOriginalOriginal Then
			While HasOriginalOriginal Do
				Original = OriginalOriginal;
				OriginalOriginal = ReplacementPairs[Original];
				HasOriginalOriginal = (OriginalOriginal <> Undefined And OriginalOriginal <> Duplicate1 And OriginalOriginal <> Original);
			EndDo;
			ReplacementPairs.Insert(Duplicate1, Original);
		EndIf;
	EndDo;
	
	If ExecutionParameters.TakeAppliedRulesIntoAccount And SubsystemExists("StandardSubsystems.DuplicateObjectsDetection") Then
		ModuleDuplicateObjectsDetection = CommonModule("DuplicateObjectsDetection");
		Errors = ModuleDuplicateObjectsDetection.CheckCanReplaceItems(ReplacementPairs, ReplacementParameters);
		
		ObjectsOriginals = New Array;
		For Each KeyValue In Errors Do
			Duplicate1 = KeyValue.Key;
			ObjectsOriginals.Add(ReplacementPairs[Duplicate1]);

			IndexOf = Duplicates.Find(Duplicate1);
			If IndexOf <> Undefined Then
				Duplicates.Delete(IndexOf); // Skip the item with issues.
			EndIf;
		EndDo;
		
		ObjectsPresentations = SubjectAsString(ObjectsOriginals);
		For Each KeyValue In Errors Do
			Duplicate1 = KeyValue.Key;
			Original = ReplacementPairs[Duplicate1];
			ErrorText = KeyValue.Value;
			Cause = ReplacementErrorDescription("WritingError", Original, ObjectsPresentations[Original], ErrorText);
			RegisterReplacementError(Result, Duplicate1, Cause);
		EndDo;
	EndIf;
	Return Duplicates;

EndFunction

Function NewReferenceReplacementExecutionParameters(Val ReplacementParameters)
	
	DefaultParameters = RefsReplacementParameters();
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("ShouldDeleteDirectly",     DefaultParameters.DeletionMethod = "Directly");
	ExecutionParameters.Insert("MarkForDeletion",         DefaultParameters.DeletionMethod = "Check");
	ExecutionParameters.Insert("IncludeBusinessLogic",       DefaultParameters.IncludeBusinessLogic);
	ExecutionParameters.Insert("WriteInPrivilegedMode",    DefaultParameters.WriteInPrivilegedMode);
	ExecutionParameters.Insert("TakeAppliedRulesIntoAccount", DefaultParameters.TakeAppliedRulesIntoAccount);
	ExecutionParameters.Insert("ReplacementLocations", New Array);
	
	// The passed parameters are processed conditionally for backward compatibility.
	ParameterValue = CommonClientServer.StructureProperty(ReplacementParameters, "DeletionMethod");
	If ParameterValue = "Directly" Then
		ExecutionParameters.ShouldDeleteDirectly = True;
		ExecutionParameters.MarkForDeletion     = False;
	ElsIf ParameterValue = "Check" Then
		ExecutionParameters.ShouldDeleteDirectly = False;
		ExecutionParameters.MarkForDeletion     = True;
	EndIf;
	
	ParameterValue = CommonClientServer.StructureProperty(ReplacementParameters, "IncludeBusinessLogic");
	If TypeOf(ParameterValue) = Type("Boolean") Then
		ExecutionParameters.IncludeBusinessLogic = ParameterValue;
	EndIf;
	
	ParameterValue = CommonClientServer.StructureProperty(ReplacementParameters, "WriteInPrivilegedMode");
	If TypeOf(ParameterValue) = Type("Boolean") Then
		ExecutionParameters.WriteInPrivilegedMode = ParameterValue;
	EndIf;
	
	ParameterValue = CommonClientServer.StructureProperty(ReplacementParameters, "TakeAppliedRulesIntoAccount");
	If TypeOf(ParameterValue) = Type("Boolean") Then
		ExecutionParameters.TakeAppliedRulesIntoAccount = ParameterValue;
	EndIf;
	
	ParameterValue =  CommonClientServer.StructureProperty(ReplacementParameters, "ReplacementLocations", New Array);
	If (ParameterValue.Count() > 0) Then
		ExecutionParameters.ReplacementLocations = New Array(New FixedArray(ParameterValue));
	EndIf;
	
	Return ExecutionParameters;
EndFunction

#EndRegion

#Region UsageInstances

Function RecordKeysTypeDetails()
	
	AddedTypes = New Array;
	For Each Meta In Metadata.InformationRegisters Do
		AddedTypes.Add(Type("InformationRegisterRecordKey." + Meta.Name));
	EndDo;
	For Each Meta In Metadata.AccumulationRegisters Do
		AddedTypes.Add(Type("AccumulationRegisterRecordKey." + Meta.Name));
	EndDo;
	For Each Meta In Metadata.AccountingRegisters Do
		AddedTypes.Add(Type("AccountingRegisterRecordKey." + Meta.Name));
	EndDo;
	For Each Meta In Metadata.CalculationRegisters Do
		AddedTypes.Add(Type("CalculationRegisterRecordKey." + Meta.Name));
	EndDo;
	
	Return New TypeDescription(AddedTypes); 
EndFunction

Function RecordSetDimensionsDetails(Val RegisterMetadata, RegisterDimensionCache)
	
	DimensionsDetails = RegisterDimensionCache[RegisterMetadata];
	If DimensionsDetails <> Undefined Then
		Return DimensionsDetails;
	EndIf;
	
	// Period and recorder, if any.
	DimensionsDetails = New Structure;
	
	DimensionData = New Structure("Master, Presentation, Format, Type", False);
	
	If Metadata.InformationRegisters.Contains(RegisterMetadata) Then
		// There might be a period.
		MetaPeriod = RegisterMetadata.InformationRegisterPeriodicity; 
		Periodicity = Metadata.ObjectProperties.InformationRegisterPeriodicity;
		
		If MetaPeriod = Periodicity.RecorderPosition Then
			DimensionData.Type           = Documents.AllRefsType();
			DimensionData.Presentation = NStr("en = 'Recorder';");
			DimensionData.Master       = True;
			DimensionsDetails.Insert("Recorder", DimensionData);
			
		ElsIf MetaPeriod = Periodicity.Year Then
			DimensionData.Type           = New TypeDescription("Date");
			DimensionData.Presentation = NStr("en = 'Period';");
			DimensionData.Format        = NStr("en = 'DF=''yyyy''; DE=''No date''';");
			DimensionsDetails.Insert("Period", DimensionData);
			
		ElsIf MetaPeriod = Periodicity.Day Then
			DimensionData.Type           = New TypeDescription("Date");
			DimensionData.Presentation = NStr("en = 'Period';");
			DimensionData.Format        = NStr("en = 'DLF=D; DE=''No date''';");
			DimensionsDetails.Insert("Period", DimensionData);
			
		ElsIf MetaPeriod = Periodicity.Quarter Then
			DimensionData.Type           = New TypeDescription("Date");
			DimensionData.Presentation = NStr("en = 'Period';");
			DimensionData.Format        =  NStr("en = 'DF=''""""Q""""q yyyy''; DE=''No date''';");
			DimensionsDetails.Insert("Period", DimensionData);
			
		ElsIf MetaPeriod = Periodicity.Month Then
			DimensionData.Type           = New TypeDescription("Date");
			DimensionData.Presentation = NStr("en = 'Period';");
			DimensionData.Format        = NStr("en = 'DF=''MMMM yyyy''; DE=''No date''';");
			DimensionsDetails.Insert("Period", DimensionData);
			
		ElsIf MetaPeriod = Periodicity.Second Then
			DimensionData.Type           = New TypeDescription("Date");
			DimensionData.Presentation = NStr("en = 'Period';");
			DimensionData.Format        = NStr("en = 'DLF=DT; DE=''No date''';");
			DimensionsDetails.Insert("Period", DimensionData);
			
		EndIf;
		
	Else
		DimensionData.Type           = Documents.AllRefsType();
		DimensionData.Presentation = NStr("en = 'Recorder';");
		DimensionData.Master       = True;
		DimensionsDetails.Insert("Recorder", DimensionData);
		
	EndIf;
	
	// All dimensions.
	For Each MetaDimension In RegisterMetadata.Dimensions Do
		DimensionData = New Structure("Master, Presentation, Format, Type");
		DimensionData.Type           = MetaDimension.Type;
		DimensionData.Presentation = MetaDimension.Presentation();
		DimensionData.Master       = MetaDimension.Master;
		DimensionsDetails.Insert(MetaDimension.Name, DimensionData);
	EndDo;
	
	RegisterDimensionCache[RegisterMetadata] = DimensionsDetails;
	Return DimensionsDetails;
	
EndFunction

#EndRegion

#EndRegion

#Region ConditionCalls

// Returns a server manager module by object name.
Function ServerManagerModule(Name)
	ObjectFound = False;
	
	NameParts = StrSplit(Name, ".");
	If NameParts.Count() = 2 Then
		
		KindName = Upper(NameParts[0]);
		ObjectName = NameParts[1];
		
		If KindName = Upper("Constants") Then
			If Metadata.Constants.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("InformationRegisters") Then
			If Metadata.InformationRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("AccumulationRegisters") Then
			If Metadata.AccumulationRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("AccountingRegisters") Then
			If Metadata.AccountingRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("CalculationRegisters") Then
			If Metadata.CalculationRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("Catalogs") Then
			If Metadata.Catalogs.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("Documents") Then
			If Metadata.Documents.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("Reports") Then
			If Metadata.Reports.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("DataProcessors") Then
			If Metadata.DataProcessors.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("BusinessProcesses") Then
			If Metadata.BusinessProcesses.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("DocumentJournals") Then
			If Metadata.DocumentJournals.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("Tasks") Then
			If Metadata.Tasks.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("ChartsOfAccounts") Then
			If Metadata.ChartsOfAccounts.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("ExchangePlans") Then
			If Metadata.ExchangePlans.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("ChartsOfCharacteristicTypes") Then
			If Metadata.ChartsOfCharacteristicTypes.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper("ChartsOfCalculationTypes") Then
			If Metadata.ChartsOfCalculationTypes.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Not ObjectFound Then
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of parameter ""%1"" in function ""%2"". Metadata object doesn''t exist: ""%3"".';"), 
			"Name", "Common.ServerManagerModule", Name),
			ErrorCategory.ConfigurationError);
	EndIf;
	
	// ACC:488-disable CalculateInSafeMode is not used, to avoid calling CommonModule recursively.
	SetSafeMode(True);
	Module = Eval(Name);
	// ACC:488-on
	
	Return Module;
EndFunction

#EndRegion

#Region Data

Function ColumnsToCompare(Val RowsCollection, Val ColumnsNames, Val ExcludingColumns)
	
	If IsBlankString(ColumnsNames) Then
		
		CollectionType = TypeOf(RowsCollection);
		IsValueList = (CollectionType = Type("ValueList"));
		IsValueTable = (CollectionType = Type("ValueTable"));
		IsKeyAndValueCollection = (CollectionType = Type("Map"))
			Or (CollectionType = Type("Structure"))
			Or (CollectionType = Type("FixedMap"))
			Or (CollectionType = Type("FixedStructure"));
		
		ColumnsToCompare = New Array;
		If IsValueTable Then
			For Each Column In RowsCollection.Columns Do
				ColumnsToCompare.Add(Column.Name);
			EndDo;
		ElsIf IsValueList Then
			ColumnsToCompare.Add("Value");
			ColumnsToCompare.Add("Picture");
			ColumnsToCompare.Add("Check");
			ColumnsToCompare.Add("Presentation");
		ElsIf IsKeyAndValueCollection Then
			ColumnsToCompare.Add("Key");
			ColumnsToCompare.Add("Value");
		Else	
			Raise(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invalid value of parameter ""%1"" (of ""%2"" type) in ""%3"". Specify the names of the fields for comparison.';"),
				"RowsCollection1", CollectionType, "Common.IdenticalCollections"),
				ErrorCategory.ConfigurationError);
		EndIf;
	Else
		ColumnsToCompare = StrSplit(StrReplace(ColumnsNames, " ", ""), ",");
	EndIf;
	
	// Remove excluded columns.
	If Not IsBlankString(ExcludingColumns) Then
		ExcludingColumns = StrSplit(StrReplace(ExcludingColumns, " ", ""), ",");
		ColumnsToCompare = CommonClientServer.ArraysDifference(ColumnsToCompare, ExcludingColumns);
	EndIf;	
	Return ColumnsToCompare;

EndFunction

Function SequenceSensitiveToCompare(Val RowsCollection1, Val RowsCollection2, Val ColumnsToCompare)
	
	CollectionType = TypeOf(RowsCollection1);
	ArraysCompared = (CollectionType = Type("Array") Or CollectionType = Type("FixedArray"));
	
	// Iterating both collections in parallel.
	Collection1RowNumber = 0;
	For Each CollectionRow1 In RowsCollection1 Do
		// Searching for the same row in the second collection.
		Collection2RowNumber = 0;
		HasCollection2Rows = False;
		For Each CollectionRow2 In RowsCollection2 Do
			HasCollection2Rows = True;
			If Collection2RowNumber = Collection1RowNumber Then
				Break;
			EndIf;
			Collection2RowNumber = Collection2RowNumber + 1;
		EndDo;
		If Not HasCollection2Rows Then
			// Second collection has no rows.
			Return False;
		EndIf;
		// Comparing field values for two rows.
		If ArraysCompared Then
			If CollectionRow1 <> CollectionRow2 Then
				Return False;
			EndIf;
		Else
			For Each ColumnName In ColumnsToCompare Do
				If CollectionRow1[ColumnName] <> CollectionRow2[ColumnName] Then
					Return False;
				EndIf;
			EndDo;
		EndIf;
		Collection1RowNumber = Collection1RowNumber + 1;
	EndDo;
	
	Collection1RowCount = Collection1RowNumber;
	
	// Calculating rows in the second collection.
	Collection2RowCount = 0;
	For Each CollectionRow2 In RowsCollection2 Do
		Collection2RowCount = Collection2RowCount + 1;
	EndDo;
	
	// If the first collection has no rows, they shouldn't be present in the other one. 
	// 
	If Collection1RowCount = 0 Then
		For Each CollectionRow2 In RowsCollection2 Do
			Return False;
		EndDo;
		Collection2RowCount = 0;
	EndIf;
	
	// Number of rows must be equal in both collections.
	If Collection1RowCount <> Collection2RowCount Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function SequenceIgnoreSensitiveToCompare(Val RowsCollection1, Val RowsCollection2, Val ColumnsToCompare)
	
	// Accumulate selection rows by the first collection to:
	//  - Save time on searching for duplicates.
	//  - Make sure the other collection has only the rows that have been accumulated.
	
	FilterRows = New ValueTable;
	FilterParameters = New Structure;
	For Each ColumnName In ColumnsToCompare Do
		FilterRows.Columns.Add(ColumnName);
		FilterParameters.Insert(ColumnName);
	EndDo;
	
	HasCollection1Rows = False;
	For Each FIlterRow In RowsCollection1 Do
		
		FillPropertyValues(FilterParameters, FIlterRow);
		If FilterRows.FindRows(FilterParameters).Count() > 0 Then
			// The row with such field values is already checked.
			Continue;
		EndIf;
		FillPropertyValues(FilterRows.Add(), FIlterRow);
		
		// Calculating the number of such rows in the first collection.
		Collection1RowsFound = 0;
		For Each CollectionRow1 In RowsCollection1 Do
			RowFits = True;
			For Each ColumnName In ColumnsToCompare Do
				If CollectionRow1[ColumnName] <> FIlterRow[ColumnName] Then
					RowFits = False;
					Break;
				EndIf;
			EndDo;
			If RowFits Then
				Collection1RowsFound = Collection1RowsFound + 1;
			EndIf;
		EndDo;
		
		// Calculating the number of such rows in the second collection.
		Collection2RowsFound = 0;
		For Each CollectionRow2 In RowsCollection2 Do
			RowFits = True;
			For Each ColumnName In ColumnsToCompare Do
				If CollectionRow2[ColumnName] <> FIlterRow[ColumnName] Then
					RowFits = False;
					Break;
				EndIf;
			EndDo;
			If RowFits Then
				Collection2RowsFound = Collection2RowsFound + 1;
				// If the number of rows in the other collection exceeds the number of the same rows 
				// in the first collection, the collections are not identical.
				If Collection2RowsFound > Collection1RowsFound Then
					Return False;
				EndIf;
			EndIf;
		EndDo;
		
		// The number of rows must be equal for both collections.
		If Collection1RowsFound <> Collection2RowsFound Then
			Return False;
		EndIf;
		
		HasCollection1Rows = True;
		
	EndDo;
	
	// If the first collection has no rows, they shouldn't be present in the other one. 
	// 
	If Not HasCollection1Rows Then
		For Each CollectionRow2 In RowsCollection2 Do
			Return False;
		EndDo;
	EndIf;
	
	// Checking that all accumulated rows exist in the second collection.
	For Each CollectionRow2 In RowsCollection2 Do
		FillPropertyValues(FilterParameters, CollectionRow2);
		If FilterRows.FindRows(FilterParameters).Count() = 0 Then
			Return False;
		EndIf;
	EndDo;
	Return True;
	
EndFunction		

Function CompareArrays(Val Array1, Val Array2)
	
	If Array1.Count() <> Array2.Count() Then
		Return False;
	EndIf;
	
	For Each Item In Array1 Do
		If Array2.Find(Item) = Undefined Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction		

Procedure CheckFixedData(Data, DataInFixedTypeValue = False)
	
	DataType = TypeOf(Data);
	TypesComposition = New TypeDescription(
		"ValueStorage,
		|FixedArray,
		|FixedStructure,
		|FixedMap");
	
	If TypesComposition.ContainsType(DataType) Then
		Return;
	EndIf;
	
	If DataInFixedTypeValue Then
		
	TypesComposition = New TypeDescription(
		"Boolean,String,Number,Date,
		|Undefined,UUID,Null,Type,
		|ErrorReportingMode,
		|ValueStorage,CommonModule,MetadataObject,
		|XDTOValueType,XDTOObjectType,
		|CollaborationSystemConversationID");
		
		If TypesComposition.ContainsType(DataType)
		 Or IsReference(DataType) Then
			
			Return;
		EndIf;
	EndIf;
	
	Raise(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Invalid value of parameter ""%1"" in function ""%2"". Data of type ""%3"" cannot be immutable.';"),
		"Data", "Common.FixedData", String(DataType)),
		ErrorCategory.ConfigurationError);
	
EndProcedure

Function StringSizeInBytes(Val String)
	
	Return GetBinaryDataFromString(String, "UTF-8").Size();

EndFunction

#Region CopyRecursive

Function CopyStructure(SourceStructure, FixData)
	
	ResultingStructure = New Structure;
	
	For Each KeyAndValue In SourceStructure Do
		ResultingStructure.Insert(KeyAndValue.Key, CopyRecursive(KeyAndValue.Value, FixData));
	EndDo;
	
	If FixData = True 
		Or FixData = Undefined
		And TypeOf(SourceStructure) = Type("FixedStructure") Then 
		
		Return New FixedStructure(ResultingStructure);
	EndIf;
	
	Return ResultingStructure;
	
EndFunction

Function CopyMap(SourceMap, FixData)
	
	ResultingMap = New Map;
	
	For Each KeyAndValue In SourceMap Do
		ResultingMap.Insert(KeyAndValue.Key, CopyRecursive(KeyAndValue.Value, FixData));
	EndDo;
	
	If FixData = True 
		Or FixData = Undefined
		And TypeOf(SourceMap) = Type("FixedMap") Then 
		Return New FixedMap(ResultingMap);
	EndIf;
	
	Return ResultingMap;
	
EndFunction

Function CopyArray(SourceArray1, FixData)
	
	ResultingArray = New Array;
	
	For Each Item In SourceArray1 Do
		ResultingArray.Add(CopyRecursive(Item, FixData));
	EndDo;
	
	If FixData = True 
		Or FixData = Undefined
		And TypeOf(SourceArray1) = Type("FixedArray") Then 
		Return New FixedArray(ResultingArray);
	EndIf;
	
	Return ResultingArray;
	
EndFunction

Function CopyValueList(SourceList, FixData)
	
	ResultingList = New ValueList;
	
	For Each ListItem In SourceList Do
		ResultingList.Add(
			CopyRecursive(ListItem.Value, FixData), 
			ListItem.Presentation, 
			ListItem.Check, 
			ListItem.Picture);
	EndDo;
	
	Return ResultingList;
	
EndFunction

Procedure CopyValuesFromValTable(ValueTable, FixData)
	For Each ValueTableRow In ValueTable Do
		For Each Column In ValueTable.Columns Do
			ValueTableRow[Column.Name] = CopyRecursive(ValueTableRow[Column.Name], FixData);
		EndDo;
	EndDo;
EndProcedure

Procedure CopyValuesFromValTreeRow(ValTreeRows, FixData);
	For Each ValueTreeRow In ValTreeRows Do
		For Each Column In ValueTreeRow.Owner().Columns Do
			ValueTreeRow[Column.Name] = CopyRecursive(ValueTreeRow[Column.Name], FixData);
		EndDo;
		CopyValuesFromValTreeRow(ValueTreeRow.Rows, FixData);
	EndDo;
EndProcedure

#EndRegion

#EndRegion

#Region Metadata

Procedure CheckMetadataObjectExists(FullName)
	
	If MetadataObjectByFullName(FullName) = Undefined Then 
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Non-existing metadata object type: ""%1"".';"), FullName),
			ErrorCategory.ConfigurationError);
	EndIf;
	
EndProcedure

#EndRegion

#Region SettingsStorage

Procedure StorageSave(StorageManager, ObjectKey, SettingsKey, Settings,
			SettingsDescription, UserName, RefreshReusableValues)
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	StorageManager.Save(ObjectKey, SettingsKey(SettingsKey), Settings,
		SettingsDescription, UserName);
	
	If RefreshReusableValues Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

Function StorageLoad(StorageManager, ObjectKey, SettingsKey, DefaultValue,
			SettingsDescription, UserName)
	
	Result = Undefined;
	
	If AccessRight("SaveUserData", Metadata) Then
		Result = StorageManager.Load(ObjectKey, SettingsKey(SettingsKey),
			SettingsDescription, UserName);
	EndIf;
	
	If Result = Undefined Then
		Result = DefaultValue;
	Else
		SetPrivilegedMode(True);
		If ClearNonExistentRefs(Result) Then
			Result = DefaultValue;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Deletes references that refer to non-existing data in the infobase from the passed collection.
// Does not clear the passed value if a non-existing reference is passed in it, but returns False. 
//
// Parameters:
//   Value - AnyRef
//            - Arbitrary - a value or a collection to check.
//
// Returns: 
//   Boolean - True if Value of the reference type and an object do not exist in the infobase.
//            False if Value of the non-reference type or an object exists.
//
Function ClearNonExistentRefs(Value)
	
	Type = TypeOf(Value);
	If Type = Type("Undefined")
		Or Type = Type("Boolean")
		Or Type = Type("String")
		Or Type = Type("Number")
		Or Type = Type("Date") Then // Optimization - frequently used primitive types.
		
		Return False; // Not a reference.
		
	ElsIf Type = Type("Array") Then
		
		Count = Value.Count();
		For Number = 1 To Count Do
			ReverseIndex = Count - Number;
			// @skip-check query-in-loop - Set of reference from tables.
			If ClearNonExistentRefs(Value[ReverseIndex]) Then
				Value.Delete(ReverseIndex);
			EndIf;
		EndDo;
		
		Return False; // Not a reference.
		
	ElsIf Type = Type("Structure")
		Or Type = Type("Map") Then
		
		For Each KeyAndValue In Value Do
			// @skip-check query-in-loop - Set of reference from tables.
			If ClearNonExistentRefs(KeyAndValue.Value) Then
				Value.Insert(KeyAndValue.Key, Undefined);
			EndIf;
		EndDo;
		
		Return False; // Not a reference.
		
	ElsIf Documents.AllRefsType().ContainsType(Type)
		Or Catalogs.AllRefsType().ContainsType(Type)
		Or Enums.AllRefsType().ContainsType(Type)
		Or ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type)
		Or ChartsOfAccounts.AllRefsType().ContainsType(Type)
		Or ChartsOfCalculationTypes.AllRefsType().ContainsType(Type)
		Or ExchangePlans.AllRefsType().ContainsType(Type)
		Or BusinessProcesses.AllRefsType().ContainsType(Type)
		Or Tasks.AllRefsType().ContainsType(Type) Then
		// Reference type except BusinessProcessRoutePointRef.
		
		If Value.IsEmpty() Then
			Return False; // Empty reference.
		EndIf;
		Return ObjectAttributeValue(Value, "Ref") = Undefined;
		
	Else
		Return False; // Not a reference.
	EndIf;
	
EndFunction

Procedure StorageDelete(StorageManager, ObjectKey, SettingsKey, UserName)
	
	If AccessRight("SaveUserData", Metadata) Then
		StorageManager.Delete(ObjectKey, SettingsKey(SettingsKey), UserName);
	EndIf;
	
EndProcedure

// Returns a settings key string with the length within 128 character limit.
// If the string exceeds 128 characters, the part after 96 characters
// is ignored and MD5 hash sum (32 characters long) is returned instead.
//
// Parameters:
//  String - String - string of any number of characters.
//
// Returns:
//  String - must not exceed 128 characters.
//
Function SettingsKey(Val String)
	Return TrimStringUsingChecksum(String, 128);
EndFunction

#EndRegion

#Region SecureStorage

Function DataFromSecureStorage(Owners, Keys, SharedData)
	
	NameOfTheSecureDataStore = "InformationRegister.SafeDataStorage";
	If DataSeparationEnabled() And SeparatedDataUsageAvailable() And SharedData <> True Then
		NameOfTheSecureDataStore = "InformationRegister.SafeDataAreaDataStorage";
	EndIf;
	
	QueryText =
		"SELECT
		|	SafeDataStorage.Owner AS DataOwner,
		|	SafeDataStorage.Data AS Data
		|FROM
		|	#NameOfTheSecureDataStore AS SafeDataStorage
		|WHERE
		|	SafeDataStorage.Owner IN (&Owners)";
	
	QueryText = StrReplace(QueryText, "#NameOfTheSecureDataStore", NameOfTheSecureDataStore);
	Query = New Query(QueryText);
	Query.SetParameter("Owners", Owners);
	QueryResult = Query.Execute().Select();
	
	Result = New Map(); 
	
	KeyDataSet = ?(ValueIsFilled(Keys) And StrFind(Keys, ","), New Structure(Keys), Undefined);
	For Each DataOwner In Owners Do
		Result.Insert(DataOwner, KeyDataSet);
	EndDo;
	
	While QueryResult.Next() Do
		
		OwnerData = New Structure(Keys);
		
		If ValueIsFilled(QueryResult.Data) Then
			
			SavedData = QueryResult.Data.Get();
			If ValueIsFilled(SavedData) Then
				
				If ValueIsFilled(Keys) Then
					DataOwner = Result[QueryResult.DataOwner];
					FillPropertyValues(OwnerData, SavedData);
				Else
					OwnerData = SavedData;
				EndIf;
				
				If Keys <> Undefined
					And OwnerData <> Undefined
					And OwnerData.Count() = 1 Then
						TheValueForTheKey = ?(OwnerData.Property(Keys), OwnerData[Keys], Undefined);
						Result.Insert(QueryResult.DataOwner, TheValueForTheKey);
				Else
					Result.Insert(QueryResult.DataOwner, OwnerData);
				EndIf;
				
			EndIf;
			
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

#Region ExternalCodeSecureExecution

// Checks whether the passed ProcedureName is the name of a configuration export procedure.
// Can be used for checking whether the passed string does not contain an arbitrary algorithm
// in the 1C:Enterprise in-built language before using it in the Execute and Evaluate operators
// upon the dynamic call of the configuration code methods.
//
// If the passed string is not a procedure name, an exception is generated.
//
// It is intended to be called from ExecuteConfigurationMethod procedure.
//
// Parameters:
//   ProcedureName - String - the export procedure name to be checked.
//
Procedure CheckConfigurationProcedureName(Val ProcedureName)
	
	NameParts = StrSplit(ProcedureName, ".");
	If NameParts.Count() <> 2 And NameParts.Count() <> 3 Then
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid format of %1 parameter (passed value: ""%2"") in %3.';"), 
			"ProcedureName", ProcedureName, "Common.ExecuteConfigurationMethod"),
			ErrorCategory.ConfigurationError);
	EndIf;
	
	ObjectName = NameParts[0];
	If NameParts.Count() = 2 And Metadata.CommonModules.Find(ObjectName) = Undefined Then
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Incorrect format of parameter %1 (passed value: ""%2"") in %3:
				|Common module ""%4"" does not exist.';"),
			"ProcedureName", ProcedureName, "Common.ExecuteConfigurationMethod", ObjectName),
			ErrorCategory.ConfigurationError);
	EndIf;
	
	If NameParts.Count() = 3 Then
		FullObjectName = NameParts[0] + "." + NameParts[1];
		Try
			Manager = ObjectManagerByName(FullObjectName);
		Except
			Manager = Undefined;
		EndTry;
		If Manager = Undefined Then
			Raise(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Incorrect format of parameter %1 (passed value: ""%2"") in %3:
				           |Object manager ""%4"" does not exist.';"),
				"ProcedureName", ProcedureName, "Common.ExecuteConfigurationMethod", FullObjectName),
				ErrorCategory.ConfigurationError);
		EndIf;
	EndIf;
	
	ObjectMethodName = NameParts[NameParts.UBound()];
	TempStructure = New Structure;
	Try
		// Check if "ProcedureName" is a valid identifier name.
		// For example, "MyProcedure".
		TempStructure.Insert(ObjectMethodName);
	Except
		WriteLogEvent(NStr("en = 'Executing method in safe mode';", DefaultLanguageCode()),
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Incorrect format of parameter %1 (passed value: ""%2"") in %3:
			           |Name of method ""%4"" does not meet the requirements of procedure and function name formation.';"),
			"ProcedureName", ProcedureName, "Common.ExecuteConfigurationMethod", ObjectMethodName),
			ErrorCategory.ConfigurationError);
	EndTry;
	
EndProcedure

// Returns an object manager by name.
// Restriction: does not process business process route points.
//
// Parameters:
//  Name - String - name, for example Catalog, Catalogs, or Catalog.Companies.
//
// Returns:
//  CatalogsManager
//  CatalogManager
//  DocumentsManager
//  DocumentManager
//  …
//
Function ObjectManagerByName(Name)
	Var MOClass, MetadataObjectName1, Manager;
	
	NameParts = StrSplit(Name, ".");
	
	If NameParts.Count() > 0 Then
		MOClass = Upper(NameParts[0]);
	EndIf;
	
	If NameParts.Count() > 1 Then
		MetadataObjectName1 = NameParts[1];
	EndIf;
	
	If      MOClass = "EXCHANGEPLAN"
	 Or      MOClass = "EXCHANGEPLANS" Then
		Manager = ExchangePlans;
		
	ElsIf MOClass = "CATALOG"
	      Or MOClass = "CATALOGS" Then
		Manager = Catalogs;
		
	ElsIf MOClass = "DOCUMENT"
	      Or MOClass = "DOCUMENTS" Then
		Manager = Documents;
		
	ElsIf MOClass = "DOCUMENTJOURNAL"
	      Or MOClass = "DOCUMENTJOURNALS" Then
		Manager = DocumentJournals;
		
	ElsIf MOClass = "ENUM"
	      Or MOClass = "ENUMS" Then
		Manager = Enums;
		
	ElsIf MOClass = "CommonModule"
	      Or MOClass = "COMMONMODULES" Then
		
		Return CommonModule(MetadataObjectName1);
		
	ElsIf MOClass = "REPORT"
	      Or MOClass = "REPORTS" Then
		Manager = Reports;
		
	ElsIf MOClass = "DATAPROCESSOR"
	      Or MOClass = "DATAPROCESSORS" Then
		Manager = DataProcessors;
		
	ElsIf MOClass = "CHARTOFCHARACTERISTICTYPES"
	      Or MOClass = "CHARTSOFCHARACTERISTICTYPES" Then
		Manager = ChartsOfCharacteristicTypes;
		
	ElsIf MOClass = "CHARTOFACCOUNTS"
	      Or MOClass = "CHARTSOFACCOUNTS" Then
		Manager = ChartsOfAccounts;
		
	ElsIf MOClass = "CHARTOFCALCULATIONTYPES"
	      Or MOClass = "ChartOfCalculationTypes" Then
		Manager = ChartsOfCalculationTypes;
		
	ElsIf MOClass = "INFORMATIONREGISTER"
	      Or MOClass = "INFORMATIONREGISTERS" Then
		Manager = InformationRegisters;
		
	ElsIf MOClass = "ACCUMULATIONREGISTER"
	      Or MOClass = "ACCUMULATIONREGISTERS" Then
		Manager = AccumulationRegisters;
		
	ElsIf MOClass = "ACCOUNTINGREGISTER"
	      Or MOClass = "ACCOUNTINGREGISTERS" Then
		Manager = AccountingRegisters;
		
	ElsIf MOClass = "CALCULATIONREGISTER"
	      Or MOClass = "CALCULATIONREGISTERS" Then
		
		If NameParts.Count() < 3 Then
			// Calculation register.
			Manager = CalculationRegisters;
		Else
			SubordinateMOClass = Upper(NameParts[2]);
			If NameParts.Count() > 3 Then
				SubordinateMOName = NameParts[3];
			EndIf;
			If SubordinateMOClass = "RECALCULATION"
			 Or SubordinateMOClass = "RECALCULATIONS" Then
				// Recalculate.
				Try
					Manager = CalculationRegisters[MetadataObjectName1].Recalculations;
					MetadataObjectName1 = SubordinateMOName;
				Except
					Manager = Undefined;
				EndTry;
			EndIf;
		EndIf;
		
	ElsIf MOClass = "BUSINESSPROCESS"
	      Or MOClass = "BUSINESSPROCESSES" Then
		Manager = BusinessProcesses;
		
	ElsIf MOClass = "TASK"
	      Or MOClass = "TASKS" Then
		Manager = Tasks;
		
	ElsIf MOClass = "CONSTANT"
	      Or MOClass = "CONSTANTS" Then
		Manager = Constants;
		
	ElsIf MOClass = "SEQUENCE"
	      Or MOClass = "SEQUENCES" Then
		Manager = Sequences;
	EndIf;
	
	If Manager <> Undefined Then
		If ValueIsFilled(MetadataObjectName1) Then
			Try
				Return Manager[MetadataObjectName1];
			Except
				Manager = Undefined;
			EndTry;
		Else
			Return Manager;
		EndIf;
	EndIf;
	
	Raise(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Invalid value of parameter ""%1"" in ""%2"". Manager for object ""%3"" doesn''t exist.';"), Name),
		"Name", "Common.ObjectManagerByName", ErrorCategory.ConfigurationError);
	
EndFunction

// Call an export procedure by the name with the configuration privilege level.
// To enable the security profile for calling the Execute() operator, the safe mode with the security profile of the configuration
// is used
// (if no other safe mode was set in stack previously).
//
// Parameters:
//  MethodName  - String - the name of the export function in format
//                       <object name>.<procedure name>, where <object name> - is
//                       a common module or object manager module.
//  Parameters  - Array - the parameters are passed to the <MethodName> function
//                        according to the array item order.
//
// Returns:
//  Arbitrary - the called function result.
//
Function CallConfigurationFunction(Val MethodName, Val Parameters = Undefined) Export
	
	CheckConfigurationProcedureName(MethodName);
	
	If SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = CommonModule("SafeModeManager");
		If ModuleSafeModeManager.UseSecurityProfiles()
			And Not ModuleSafeModeManager.SafeModeSet() Then
			
			InfobaseProfile = ModuleSafeModeManager.InfobaseSecurityProfile();
			If ValueIsFilled(InfobaseProfile) Then
				
				SetSafeMode(InfobaseProfile);
				If SafeMode() = True Then
					SetSafeMode(False);
				EndIf;
				
			EndIf;
			
		EndIf;
	EndIf;
	
	ParametersString = "";
	If Parameters <> Undefined And Parameters.Count() > 0 Then
		For IndexOf = 0 To Parameters.UBound() Do 
			ParametersString = ParametersString + "Parameters[" + XMLString(IndexOf) + "],";
		EndDo;
		ParametersString = Mid(ParametersString, 1, StrLen(ParametersString) - 1);
	EndIf;
	
	Return Eval(MethodName + "(" + ParametersString + ")"); // ACC:488 The code being executed is safe.
	
EndFunction

// Call the export function of the 1C:Enterprise script language object by name.
// To enable the security profile for calling the Execute() operator, the safe mode with the security profile of the configuration
// is used
// (if no other safe mode was set in stack previously).
//
// Parameters:
//  Object    - Arbitrary - 1C:Enterprise language object that contains the methods (for example, DataProcessorObject).
//  MethodName - String       - the name of export function of the data processor object module.
//  Parameters - Array       - the parameters are passed to the <MethodName> function
//                             according to the array item order.
//
// Returns:
//  Arbitrary - the called function result.
//
Function CallObjectFunction(Val Object, Val MethodName, Val Parameters = Undefined) Export
	
	// Method name validation.
	Try
		Test = New Structure;
		Test.Insert(MethodName, MethodName);
	Except
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Incorrect value of parameter %1 in %3: %2.';"), 
			"MethodName", MethodName, "Common.ExecuteObjectMethod"),
			ErrorCategory.ConfigurationError);
	EndTry;
	
	If SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = CommonModule("SafeModeManager");
		If ModuleSafeModeManager.UseSecurityProfiles()
			And Not ModuleSafeModeManager.SafeModeSet() Then
			
			ModuleSafeModeManager = CommonModule("SafeModeManager");
			InfobaseProfile = ModuleSafeModeManager.InfobaseSecurityProfile();
			
			If ValueIsFilled(InfobaseProfile) Then
				
				SetSafeMode(InfobaseProfile);
				If SafeMode() = True Then
					SetSafeMode(False);
				EndIf;
				
			EndIf;
			
		EndIf;
	EndIf;
	
	ParametersString = "";
	If Parameters <> Undefined And Parameters.Count() > 0 Then
		For IndexOf = 0 To Parameters.UBound() Do 
			ParametersString = ParametersString + "Parameters[" + XMLString(IndexOf) + "],";
		EndDo;
		ParametersString = Mid(ParametersString, 1, StrLen(ParametersString) - 1);
	EndIf;
	
	Return Eval("Object." + MethodName + "(" + ParametersString + ")"); // ACC:488 The code being executed is safe.
	
EndFunction

#EndRegion

#Region AddIns

Procedure CheckTheLocationOfTheComponent(Id, Location)
	
	If TemplateExists(Location) Then
		Return;
	EndIf;
	
	If SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = CommonModule("AddInsInternal");
		ModuleAddInsInternal.CheckTheLocationOfTheComponent(Id, Location);
		Return;
	EndIf;
	Raise(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'When attaching an add-in ""%2"", non-existent template ""%1"" is specified.';"),
			Location, Id),
		ErrorCategory.ConfigurationError);
	
EndProcedure

Function TemplateAddInCompatibilityError(Location)
	
	If Not SubsystemExists("StandardSubsystems.AddIns") Then
		Return "";
	EndIf;
	
	ModuleAddInsInternal = CommonModule("AddInsInternal");
	
	Return ModuleAddInsInternal.TemplateAddInCompatibilityError(
		Location);
	
EndFunction

Function SystemInformationForLogging()
	
	SystemInfo = New SystemInfo;
	
	Return Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '1C:Enterprise: %1
		           |Type: %2
		           |OS version: %3
		           |CPU: %4
		           |RAM: %5';",
		           DefaultLanguageCode()),
		SystemInfo.AppVersion,
		SystemInfo.PlatformType,
		SystemInfo.OSVersion,
		SystemInfo.Processor,
		SystemInfo.RAM);
	
EndFunction

#EndRegion

#Region CurrentEnvironment

Function BuildNumberForTheCurrentPlatformVersion(AssemblyNumbersAsAString)
	
	AssemblyNumbers = StrSplit(AssemblyNumbersAsAString, ";", True);
	
	BuildsByVersion = New Map;
	For Each BuildNumber In AssemblyNumbers Do
		VersionNumber = CommonClientServer.ConfigurationVersionWithoutBuildNumber(BuildNumber);
		BuildsByVersion.Insert(TrimAll(VersionNumber), TrimAll(BuildNumber));
	EndDo;
	
	SystemInfo = New SystemInfo;
	CurrentVersion = CommonClientServer.ConfigurationVersionWithoutBuildNumber(SystemInfo.AppVersion);
	
	Result = BuildsByVersion[CurrentVersion];
	If Not ValueIsFilled(Result) Then
		Result = AssemblyNumbers[0];
	EndIf;
	
	Return Result;
	
EndFunction

// Sets the update prompt threshold for 1C:Enterprise. If a user runs a configuration on a version earlier than the threshold
// (and later than "StandardSubsystemsServer.Min1CEnterpriseVersionForStart").
// Specific version numbers are given in StandardSubsystemsServer.Min1CEnterpriseVersionForUse.
// Versions can be overridden in CommonOverridable.OnDetermineCommonCoreParameters.
//
Function MinPlatformVersion() Export // ACC:581 - Export checker since it is used for testing.
	
	CompatibilityModeVersion = CompatibilityModeVersion();
	MinPlatformVersions = StandardSubsystemsServer.Min1CEnterpriseVersionForUse();
	FoundVersion = MinPlatformVersions.FindByValue(CompatibilityModeVersion);
	
	If FoundVersion = Undefined Then
		FoundVersion = MinPlatformVersions[MinPlatformVersions.Count() - 1];
	EndIf;
	
	Return FoundVersion.Presentation;
	
EndFunction

Function CompatibilityModeVersion() Export
	
	SystemInfo = New SystemInfo();
	CompatibilityMode = Metadata.CompatibilityMode;
	
	If CompatibilityMode = Metadata.ObjectProperties.CompatibilityMode.DontUse Then
		CompatibilityModeVersion = CommonClientServer.ConfigurationVersionWithoutBuildNumber(SystemInfo.AppVersion);
	Else
		CompatibilityModeVersion = StrConcat(StrSplit(CompatibilityMode, 
			StrConcat(StrSplit(CompatibilityMode, "1234567890", False), ""), False), ".");
	EndIf;
	
	Return CompatibilityModeVersion;
	
EndFunction

// Validates the minimum and recommended 1C:Enterprise versions.
//
// Parameters:
//  Min - String - 1C:Enterprise version.
//  Recommended - String - 1C:Enterprise version.
//
// Returns:
//  Boolean - True if the minimum and recommended versions are invalid.
//
Function IsMinRecommended1CEnterpriseVersionInvalid(Min, Recommended)
	
	// Minimum 1C:Enterprise version is required.
	If IsBlankString(Min) Then
		Return True;
	EndIf;
	
	// The minimum 1C:Enterprise version required in the configuration must be
	// equal to or greater than the minimum 1C:Enterprise version required in the library.
	MinimalSSL = BuildNumberForTheCurrentPlatformVersion(MinPlatformVersion());
	If Not IsVersionOfProtectedComplexITSystem(Min)
		And CommonClientServer.CompareVersions(MinimalSSL, Min) > 0 Then
		Return True;
	EndIf;
	
	// Minimum 1C:Enterprise version cannot be greater than the recommended one.
	Return Not IsBlankString(Min)
		And Not IsBlankString(Recommended)
		And CommonClientServer.CompareVersions(Min, Recommended) > 0;
	
EndFunction

Function InvalidPlatformVersions() Export
	
	Return "";
	
EndFunction

Function IsVersionOfProtectedComplexITSystem(Version)
	
	Versions = StandardSubsystemsServer.SecureSoftwareSystemVersions();
	Return Versions.Find(Version) <> Undefined;
	
EndFunction

// Intended for the CommonCoreParameters function.
Procedure ClarifyPlatformVersion(CommonParameters)
	
	SystemInfo = New SystemInfo;
	NewBuild = StandardSubsystemsServer.ReplacementVersionForRevoked1CEnterprise(SystemInfo.AppVersion);
	If Not ValueIsFilled(NewBuild) Then
		NewRecommendedBuild = StandardSubsystemsServer.ReplacementVersionForRevoked1CEnterprise(CommonParameters.MinPlatformVersion);
		If ValueIsFilled(NewRecommendedBuild) Then
			MinBuild = BuildNumberForTheCurrentPlatformVersion(MinPlatformVersion());
			CommonParameters.MinPlatformVersion = MinBuild;
			CommonParameters.MinPlatformVersion1 = MinBuild;
			If CommonClientServer.CompareVersions(CommonParameters.RecommendedPlatformVersion, NewRecommendedBuild) < 0 Then
				CommonParameters.RecommendedPlatformVersion = NewRecommendedBuild;
			EndIf;
		EndIf;
	ElsIf CommonClientServer.CompareVersions(CommonParameters.MinPlatformVersion, NewBuild) < 0 Then
		CommonParameters.RecommendedPlatformVersion = NewBuild;
		CommonParameters.MinPlatformVersion = NewBuild;
		CommonParameters.MinPlatformVersion1 = NewBuild;
		CommonParameters.MustExit = True;
	EndIf;
	
EndProcedure


#EndRegion

#Region CheckingAlgorithms

Procedure CheckAlgorithm(Val Algorithm)
	
	ErrorsTexts = New Array;
	
	Algorithm = Upper(Algorithm);
	// Exclude the method of the "Query" object.
	Algorithm = StrReplace(StrReplace(Algorithm, Upper("Execute()"), ""), Upper("Execute()"), "");
	// Check if the algorithm contains invalid methods.
	FoundCalls = FoundCalls(Algorithm, InvalidMethods(), "(");
	If FoundCalls.Count() > 0 Then
		ErrorText = NStr("en = 'Invalid method calls:
			|%1';");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, StrConcat(FoundCalls, Chars.LF));
		
		ErrorsTexts.Add(ErrorText);
	EndIf;
	
	// Check for calls to the global context common modules and properties.
	FoundCalls = FoundCalls(Algorithm, ForbiddenPropertiesOfGlobalContext(), ".");
	AlternativeCallsFound = FoundCalls(Algorithm, ForbiddenPropertiesOfGlobalContext(), "[");
	CommonClientServer.SupplementArray(FoundCalls, AlternativeCallsFound, True);
	If FoundCalls.Count() > 0 Then
		ErrorText = NStr("en = 'Invalid global context property calls:
			|%1';");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, StrConcat(FoundCalls, Chars.LF));
		
		ErrorsTexts.Add(ErrorText);
	EndIf;
	
	FoundCalls = FoundCalls(Algorithm, ProhibitedModules(), ".");
	If FoundCalls.Count() > 0 Then
		ErrorText = NStr("en = 'Invalid modules calls:
			|%1';");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, StrConcat(FoundCalls, Chars.LF));
		
		ErrorsTexts.Add(ErrorText);
	EndIf;
	
	If ErrorsTexts.Count() > 0 Then
		Raise StrConcat(ErrorsTexts, Chars.LF + Chars.LF);
	EndIf;
EndProcedure

Function FoundCalls(Algorithm, SearchBars, Ending = Undefined)
	
	FoundCalls  = New Array;
	SearchForAddressThroughPoint = False;
	TableSearch = False;
	For Each Item In SearchBars Do
		
		If TypeOf(Item) = Type("Structure") Then
			SearchForAddressThroughPoint = True;
			SearchString = Item.Collection;
		Else
			SearchString = Item;
		EndIf;
		
		CallPosition  = StrFind(Algorithm, Upper(SearchString));
		EntryNumber = 1;
		While CallPosition > 0 Do
			If SearchForAddressThroughPoint Then
				Ending = ".";
				TableSearch = False;
			EndIf;
			
			CountOfCharacters  = StrLen(Ending);
			CharPosition = CallPosition + StrLen(SearchString);
			
			While CharPosition + CountOfCharacters < StrLen(Algorithm) Do
				SymbolValue = TrimAll(Mid(Algorithm, CharPosition, CountOfCharacters));
				If Upper(SearchString) = Upper("Execute")
					Or Upper(SearchString) = Upper("Execute") Then
					
					If Not ValueIsFilled(SymbolValue) Then
						FoundCalls.Add(SearchString);
						Break;
					EndIf;
				EndIf;
				
				If StrLen(SymbolValue) < StrLen(Ending) Then
					CountOfCharacters = CountOfCharacters + 1;
				ElsIf SearchForAddressThroughPoint
					And SymbolValue = Ending
					And Not TableSearch Then
					CharPosition = CharPosition + CountOfCharacters;
					Ending      = Upper(Item.Table);
					CountOfCharacters  = StrLen(Ending);
					TableSearch = True;
				ElsIf SymbolValue = Ending Then
					If SearchForAddressThroughPoint Then
						FoundCalls.Add(Item.Collection + "." + Item.Table);
					Else
						FoundCalls.Add(SearchString);
					EndIf;
					Break;
				ElsIf ValueIsFilled(TrimAll(SymbolValue)) Then
					Break;
				EndIf;
			EndDo;
			
			EntryNumber = EntryNumber + 1;
			CallPosition  = StrFind(Algorithm, Upper(SearchString), , , EntryNumber);
		EndDo;
	EndDo;
	
	Return FoundCalls;
	
EndFunction

Function InvalidMethods()
	Array = New Array;
	Array.Add("Выполнить"); // @Non-NLS
	Array.Add("Вычислить"); // @Non-NLS
	Array.Add("ЗафиксироватьТранзакцию"); // @Non-NLS
	Array.Add("СократитьЖурналРегистрации"); // @Non-NLS
	Array.Add("УстановитьИспользованиеСобытияЖурналаРегистрации"); // @Non-NLS
	Array.Add("ЗапуститьПриложение"); // @Non-NLS
	Array.Add("УстановитьМаксимальныйСрокДействияПаролейПользователей"); // @Non-NLS
	Array.Add("УстановитьМинимальнуюДлинуПаролейПользователей"); // @Non-NLS
	Array.Add("УстановитьМинимальныйСрокДействияПаролейПользователей"); // @Non-NLS
	Array.Add("УстановитьОграничениеПовторенияПаролейПользователейСредиПоследних"); // @Non-NLS
	Array.Add("УстановитьПроверкуСложностиПаролейПользователей"); // @Non-NLS
	Array.Add("УстановитьНастройкиВосстановленияПароля"); // @Non-NLS
	
	Array.Add("Execute");
	Array.Add("Eval");
	Array.Add("CommitTransaction");
	Array.Add("TruncateEventLog");
	Array.Add("SetEventLogEventUse");
	Array.Add("RunApp");
	Array.Add("SetUserPasswordMaxEffectivePeriod");
	Array.Add("SetUserPasswordMinLength");
	Array.Add("SetUserPasswordMinEffectivePeriod");
	Array.Add("SetUserPasswordReuseLimit");
	Array.Add("SetUserPasswordStrengthCheck");
	Array.Add("SetPasswordRecoverySettings");
	
	Return Array;
EndFunction

Function ForbiddenPropertiesOfGlobalContext()
	
	Array = New Array;
	Array.Add("ПользователиИнформационнойБазы"); // @Non-NLS
	Array.Add("ДополнительныеНастройкиАутентификации"); // @Non-NLS
	Array.Add("ПараметрыСеанса"); // @Non-NLS
	Array.Add("InfoBaseUsers");
	Array.Add("AdditionalAuthenticationSettings");
	Array.Add("SessionParameters");
	
	Return Array;
	
EndFunction

Function ProhibitedModules()
	
	Array = New Array;
	Array.Add("TimeConsumingOperations");
	
	Return Array;
	
EndFunction

#EndRegion

#EndRegion

#EndIf
