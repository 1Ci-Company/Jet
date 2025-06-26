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

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchEditObjects

// Returns the object attributes that are not recommended to be edited
// using a bulk attribute modification data processor.
//
// Returns:
//  Array of String
//
Function AttributesToSkipInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.ObjectAttributesLock

// Returns:
//   See ObjectAttributesLockOverridable.OnDefineLockedAttributes.LockedAttributes.
//
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("Type;Type");
	AttributesToLock.Add("Parent");
	AttributesToLock.Add("IDForFormulas");
	
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

// StandardSubsystems.DuplicateObjectsDetection

// Parameters: 
//   ReplacementPairs - See DuplicateObjectsDetectionOverridable.OnDefineItemsReplacementAvailability.ReplacementPairs
//   ReplacementParameters - See DuplicateObjectsDetectionOverridable.OnDefineItemsReplacementAvailability.ReplacementParameters
// 
// Returns:
//   See DuplicateObjectsDetectionOverridable.OnDefineItemsReplacementAvailability.ProhibitedReplacements
//
Function CanReplaceItems(Val ReplacementPairs, Val ReplacementParameters = Undefined) Export
	
	Result = New Map;
	For Each KeyValue In ReplacementPairs Do
		CurrentRef = KeyValue.Key;
		DestinationRef = KeyValue.Value;
		
		If CurrentRef = DestinationRef Then
			Continue;
		EndIf;
		
		// Replacing a contact information kind with another kind is only allowed if they both belong to the same group.
		ReplacementAllowed = CurrentRef.Parent = DestinationRef.Parent;
		If Not ReplacementAllowed Then
			Error = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Item ""%1"" belongs to ""%2,"" while ""%3"" belongs to ""%4.""';"),
				CurrentRef, CurrentRef.Parent, DestinationRef, DestinationRef.Parent);
			Result.Insert(CurrentRef, Error);
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// Parameters: 
//   SearchParameters - See DuplicateObjectsDetectionOverridable.OnDefineDuplicatesSearchParameters.SearchParameters
//   AdditionalParameters - See DuplicateObjectsDetectionOverridable.OnDefineDuplicatesSearchParameters.AdditionalParameters 
//
Procedure DuplicatesSearchParameters(SearchParameters, AdditionalParameters = Undefined) Export
	
	Restriction = New Structure;
	Restriction.Insert("Presentation",      NStr("en = 'Same group and same type (for example, ""address"" or ""phone"" type).';"));
	Restriction.Insert("AdditionalFields", "Parent, Type, Used");
	SearchParameters.ComparisonRestrictions.Add(Restriction);
	
	// Table size to be passed to the handler.
	SearchParameters.ItemsCountToCompare = 100;
	
EndProcedure

// Parameters:
//   ItemsDuplicates - See DuplicateObjectsDetectionOverridable.OnSearchForDuplicates.ItemsDuplicates
//   AdditionalParameters - See DuplicateObjectsDetectionOverridable.OnSearchForDuplicates.AdditionalParameters
//
Procedure OnSearchForDuplicates(ItemsDuplicates, AdditionalParameters = Undefined) Export
	
	For Each Duplicate1 In ItemsDuplicates Do
		If Duplicate1.Fields1.Used
		   And Duplicate1.Fields2.Used
		   And Duplicate1.Fields1.Parent = Duplicate1.Fields2.Parent 
		   And Duplicate1.Fields1.Type = Duplicate1.Fields2.Type
		   And StrCompare(Duplicate1.Fields1.Description, Duplicate1.Fields2.Description) = 0 Then
			Duplicate1.IsDuplicates = True;
		EndIf;
	EndDo;
	
EndProcedure

// End StandardSubsystems.DuplicateObjectsDetection

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

// ACC:362-off Design-based decision.

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportClientServer = Common.CommonModule("NationalLanguageSupportClientServer");
		ModuleNationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	EndIf;
#Else
	If CommonClient.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportClientServer = CommonClient.CommonModule("NationalLanguageSupportClientServer");
		ModuleNationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	EndIf;
#EndIf
EndProcedure

// ACC:362-on

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling
// 
// Parameters:
//  Settings - See InfobaseUpdateInternal.ItemsFillingSettings
//
Procedure OnSetUpInitialItemsFilling(Settings) Export
	
	ContactsManagerOverridable.OnSetUpInitialItemsFilling(Settings);

	Settings.OnInitialItemFilling = True;
	Settings.KeyAttributeName          = KeyAttributeName();
	
EndProcedure

// See also InfobaseUpdateOverridable.OnInitialItemsFilling
// 
// Parameters:
//   LanguagesCodes - See InfobaseUpdateOverridable.OnInitialItemsFilling.LanguagesCodes
//   Items   - See InfobaseUpdateOverridable.OnInitialItemsFilling.Items
//   TabularSections - See InfobaseUpdateOverridable.OnInitialItemsFilling.TabularSections
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items, TabularSections) Export
	
	Item = Items.Add();
	Item.PredefinedDataName = "CatalogUsers";
	Item.IsFolder = True;
	Item.Used = True;
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.FillMultilanguageAttribute(Item, "Description", 
			"en = '""Users"" catalog contact information';", LanguagesCodes); // @NStr-1
	Else
		Item.Description = NStr("en = '""Users"" catalog contact information';", 
			Common.DefaultLanguageCode());
	EndIf;
	
	Item = Items.Add();
	Item.PredefinedDataName = "UserEmail";
	Item.Type = Enums.ContactInformationTypes.Email;
	Item.CanChangeEditMethod = True;
	Item.AllowMultipleValueInput   = True;
	Item.Parent = Catalogs.ContactInformationKinds.CatalogUsers;
	Item.IDForFormulas = "Email";
	Item.EditingOption = "InputField";
	Item.Used = True;
	Item.AddlOrderingAttribute = 2;
	Item.IsAlwaysDisplayed          = True;
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.FillMultilanguageAttribute(Item, "Description", 
		"en = 'Email';", LanguagesCodes); // @NStr-1
	Else
		Item.Description = NStr("en = 'Email';", Common.DefaultLanguageCode());
	EndIf;
	
	
	Item = Items.Add();
	Item.PredefinedDataName = "UserPhone";
	Item.Type = Enums.ContactInformationTypes.Phone;
	
	Item.CanChangeEditMethod = True;
	Item.AllowMultipleValueInput   = True;
	Item.Parent = Catalogs.ContactInformationKinds.CatalogUsers;
	Item.IDForFormulas = "Phone";
	Item.Used = True;
	Item.EditingOption = "InputFieldAndDialog";
	Item.AddlOrderingAttribute = 1;
	Item.IsAlwaysDisplayed          = True;
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.FillMultilanguageAttribute(Item, "Description", 
		"en = 'Phone';", LanguagesCodes); // @NStr-1
	Else
		Item.Description = NStr("en = 'Phone';", Common.DefaultLanguageCode());
	EndIf;
	
	ContactsManagerOverridable.OnInitialItemsFilling(LanguagesCodes, Items, TabularSections);
	
EndProcedure

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.
//
// Parameters:
//  Object                  - CatalogObject.ContactInformationKinds - Object to populate.
//  Data                  - ValueTableRow - object filling data.
//  AdditionalParameters - Structure:
//   * PredefinedData - ValueTable - Data populated in the OnInitialItemsFilling procedure.
//
Procedure OnInitialItemFilling(Object, Data, AdditionalParameters) Export
	
	ContactsManagerOverridable.OnInitialItemFilling(Object, Data, AdditionalParameters);
	
	If Not Object.IsFolder And IsBlankString(Object.GroupName) Then
		GroupName = Common.ObjectAttributeValue(Object.Parent, KeyAttributeName());
		If IsBlankString(GroupName) Then
			GroupName = Common.ObjectAttributeValue(Object.Parent, "PredefinedDataName");
		EndIf;
		Object.GroupName = GroupName;
	EndIf;
	
	Result = ContactsManagerInternal.CheckContactsKindParameters(Object);
	If Result.HasErrors Then
		Raise Result.ErrorText;
	EndIf;
	
	If Object.Type = Enums.ContactInformationTypes.Address Then 
		If IsBlankString(Object.EditingOption) Then
			Object.EditingOption = "InputFieldAndDialog";
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
	
#Region Private

#Region IDForFormulas

// Checks the ID uniqueness within the metadata object for which contact
// information type (parent) is intended and that the ID complies with the syntax.
// 
// Parameters:
//   IDForFormulas - String - ID for formulas.
//   Ref - CatalogRef.ContactInformationKinds - a reference to the current object.
//   Parent - CatalogRef.ContactInformationKinds - a reference to the current object parent.
//   Cancel - Boolean - a cancellation flag if there is an error.
//
Procedure CheckIDUniqueness(IDForFormulas, Ref, Parent, Cancel) Export
	
	If ValueIsFilled(IDForFormulas) Then
		
		IDByRules = True;
		VerificationID = IDForFormulas(IDForFormulas);
		If Not Upper(VerificationID) = Upper(IDForFormulas) Then
			IDByRules = False;
			
			ErrorText = NStr("en = 'ID ""%1"" does not comply with variable naming rules.
									|An ID must not contain spaces and special characters.';");
			Common.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersToString(ErrorText, IDForFormulas),,
				"IDForFormulas",, Cancel);
				
			LanguageCode = Common.DefaultLanguageCode();
			EventName = NStr("en = 'Save additional attribute or information record';", LanguageCode);
			ErrorText = NStr("en = 'ID ""%1"" does not comply with variable naming rules.
									|An ID must not contain spaces and special characters.';", LanguageCode);
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
				IDForFormulas);
			WriteLogEvent(EventName,
					EventLogLevel.Error,
					Ref.Metadata(),
					Ref,
					ErrorText);
		EndIf;
		
		If IDByRules Then
			TopLevelParent = Parent;
			While ValueIsFilled(TopLevelParent) Do
				Value = Common.ObjectAttributeValue(TopLevelParent, "Parent");
				If ValueIsFilled(Value) Then
					TopLevelParent = Value;
				Else
					Break;
				EndIf;
			EndDo;
			If Not IDForFormulasUnique(IDForFormulas, Ref, TopLevelParent) Then
				
				Cancel = True;
				
				ErrorText = NStr("en = 'The database already contains a contact information kind with ID ""%1"" within group ""%2"". The ID must be unique';");
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
					IDForFormulas, TopLevelParent);
				Common.MessageToUser(ErrorText,, "IDForFormulas");
				
				LanguageCode = Common.DefaultLanguageCode();
				ErrorText = NStr("en = 'The database already contains a contact information kind with ID ""%1"" within group ""%2"". The ID must be unique';", LanguageCode);
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
					IDForFormulas, TopLevelParent);
				EventName = NStr("en = 'Save additional attribute or information record';", LanguageCode);
				WriteLogEvent(EventName,
					EventLogLevel.Error,
					Ref.Metadata(),
					Ref,
					ErrorText);
			EndIf;
		EndIf;
		
	Else
		
		ErrorText = NStr("en = 'ID for formulas is required';");
		Common.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(ErrorText, IDForFormulas),,
			"IDForFormulas",, Cancel);
			
		LanguageCode = Common.DefaultLanguageCode();
		EventName = NStr("en = 'Save additional attribute or information record';", LanguageCode);
		ErrorText = NStr("en = 'ID for formulas is required';", LanguageCode);
		WriteLogEvent(EventName,
			EventLogLevel.Error,
			Ref.Metadata(),
			Ref,
			ErrorText);
			
	EndIf;
	
EndProcedure

// Returns a UUID for formulas (after the uniqueness check)
// 
// Parameters:
//   ObjectPresentation - String - a presentation from which an ID for formulas will be generated.
//   CurrentObjectRef - CatalogRef.ContactInformationKinds - a reference to the current item.
//   Parent - CatalogRef.ContactInformationKinds - a reference to the current object parent.
// Returns:
//   String - — a unique ID value for formulas.
//
Function UUIDForFormulas(ObjectPresentation, CurrentObjectRef, Parent) Export

	Id = IDForFormulas(ObjectPresentation);
	If IsBlankString(Id) Then
		// Presentation consists of special characters and digits.
		Prefix = NStr("en = 'ID';");
		Id = IDForFormulas(Prefix + ObjectPresentation);
	EndIf;
	
	TopLevelParent = Parent;
	While ValueIsFilled(TopLevelParent) Do
		Value = Common.ObjectAttributeValue(TopLevelParent, "Parent");
		If ValueIsFilled(Value) Then
			TopLevelParent = Value;
		Else
			Break;
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ContactInformationKinds.IDForFormulas AS IDForFormulas
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|WHERE
	|	ContactInformationKinds.IDForFormulas = &IDForFormulas
	|	AND ContactInformationKinds.Ref <> &CurrentObjectRef
	|	AND ContactInformationKinds.Ref IN HIERARCHY (&TopLevelParent)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ContactInformationKinds.IDForFormulas AS IDForFormulas
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|WHERE
	|	ContactInformationKinds.IDForFormulas LIKE &IDForFormulasSimilarity ESCAPE ""~""
	|	AND ContactInformationKinds.Ref <> &CurrentObjectRef
	|	AND ContactInformationKinds.Ref IN HIERARCHY (&TopLevelParent)";
	Query.SetParameter("CurrentObjectRef", CurrentObjectRef);
	Query.SetParameter("TopLevelParent", TopLevelParent);
	Query.SetParameter("IDForFormulas", Id);
	Query.SetParameter("IDForFormulasSimilarity", Common.GenerateSearchQueryString(Id) + "%");
	
	QueryResults = Query.ExecuteBatch();
	UniquenessByExactMatch = QueryResults[0];
	If Not UniquenessByExactMatch.IsEmpty() Then
		// There are items with this ID.
		PreviousIDs = New Map;
		SimilarItemsSelection = QueryResults[1].Select();
		While SimilarItemsSelection.Next() Do
			PreviousIDs.Insert(Upper(SimilarItemsSelection.IDForFormulas), True);
		EndDo;
		
		NumberToAdd = 1;
		IDWithoutNumber = Id;
		While Not PreviousIDs.Get(Upper(Id)) = Undefined Do
			NumberToAdd = NumberToAdd + 1;
			Id = IDWithoutNumber + NumberToAdd;
		EndDo;
	EndIf;
	PreviousIDs = New Map;
	
	Return Id;
EndFunction

Function IDForFormulasUnique(IDToCheck, CurrentObjectRef, Parent)
	
	TopLevelParent = Parent;
	While ValueIsFilled(TopLevelParent) Do
		Value = Common.ObjectAttributeValue(TopLevelParent, "Parent");
		If ValueIsFilled(Value) Then
			TopLevelParent = Value;
		Else
			Break;
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Table.Ref
	|FROM
	|	Catalog.ContactInformationKinds AS Table
	|WHERE
	|	Table.Ref <> &CurrentObjectRef
	|	AND Table.Ref IN HIERARCHY (&TopLevelParent)
	|	AND Table.IDForFormulas = &IDForFormulas";
	Query.SetParameter("IDForFormulas", IDToCheck);
	Query.SetParameter("CurrentObjectRef", CurrentObjectRef);
	Query.SetParameter("TopLevelParent", TopLevelParent);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.IsEmpty();
EndFunction

// Calculates the value of an ID from the string according to the variable naming rules.
// 
// Parameters:
//  PresentationRow - String - description, the string from which it is required to receive an ID. 
//
// Returns:
//  String - — an ID matching the ID naming rules.
//
Function IDForFormulas(PresentationRow) Export
	
	SpecialChars = SpecialChars();
	
	Id = "";
	HadSpecialChar = False;
	
	For CharNum = 1 To StrLen(PresentationRow) Do
		
		Char = Mid(PresentationRow, CharNum, 1);
		
		If StrFind(SpecialChars, Char) <> 0 Then
			HadSpecialChar = True;
			If Char = "_" Then
				Id = Id + Char;
			EndIf;
		ElsIf HadSpecialChar
			Or CharNum = 1 Then
			HadSpecialChar = False;
			Id = Id + Upper(Char);
		Else
			Id = Id + Char;
		EndIf;
		
	EndDo;
	
	Return Id;
	
EndFunction

Function SpecialChars()
	Ranges = New Array;
	Ranges.Add(New Structure("Min, Max", 0, 32));
	Ranges.Add(New Structure("Min, Max", 127, 191));
	
	SpecialChars = " .,+,-,/,*,?,=,<,>,(,)%!@#$%&*""№:;{}[]?()\|/`~'^_";
	For Each Span In Ranges Do
		For CharCode = Span.Min To Span.Max Do
			SpecialChars = SpecialChars + Char(CharCode);
		EndDo;
	EndDo;
	Return SpecialChars;
EndFunction

Function DescriptionForIDGeneration(Val Description, Val Presentations)
	If CurrentLanguage().LanguageCode <> Common.DefaultLanguageCode() Then
		Filter = New Structure();
		Filter.Insert("LanguageCode", Common.DefaultLanguageCode());
		FoundRows = Presentations.FindRows(Filter);
		If FoundRows.Count() > 0 Then
			Description = FoundRows[0].Description;
		EndIf;
	EndIf;
	
	Return Description;
EndFunction

// Parameters:
//  Parent - CatalogRef.ContactInformationKinds
// 
// Returns:
//  String
//
Function NameOfContactInformationTypeGroup(Parent) Export
	
	GroupName = Common.ObjectAttributeValue(Parent, "PredefinedKindName");
	If IsBlankString(GroupName) Then
		GroupName = Common.ObjectAttributeValue(Parent, "PredefinedDataName");
	EndIf;
	
	Return GroupName;
	
EndFunction

#EndRegion

// Registers contact information kinds for processing.
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	
	If Metadata.Languages.Count() = 1 Then
			QueryText = "SELECT
			|	ContactInformationKinds.Ref AS Ref,
			|	ContactInformationKinds.PredefinedDataName AS PredefinedDataName
			|FROM
			|	Catalog.ContactInformationKinds AS ContactInformationKinds
			|WHERE
			|	ContactInformationKinds.IsFolder = FALSE
			|	AND (ISNULL(ContactInformationKinds.IDForFormulas, """") = """"
			|			OR ISNULL(ContactInformationKinds.EditingOption, """") = """"
			|			OR ISNULL(ContactInformationKinds.GroupName, """") = """"
			|			OR ContactInformationKinds.IsAlwaysDisplayed = FALSE)";
	Else
		
		QueryText = "SELECT
			|	ContactInformationKinds.Ref AS Ref,
			|	ContactInformationKinds.PredefinedDataName AS PredefinedDataName
			|FROM
			|	Catalog.ContactInformationKinds AS ContactInformationKinds
			|		LEFT JOIN Catalog.ContactInformationKinds.Presentations AS KindPresentations
			|		ON (KindPresentations.Ref = ContactInformationKinds.Ref)
			|WHERE
			|	(ContactInformationKinds.IsFolder = FALSE
			|				AND ((ISNULL(ContactInformationKinds.IDForFormulas, """") = """"
			|					OR ISNULL(ContactInformationKinds.EditingOption, """") = """"
			|					OR ISNULL(ContactInformationKinds.GroupName, """") = """"
			|					OR ContactInformationKinds.IsAlwaysDisplayed = FALSE)
			|			OR KindPresentations.Ref IS NULL))"
	EndIf;
		
	Query = New Query(QueryText);
	
	QueryResult = Query.Execute().Unload();
	
	Position = QueryResult.Count() - 1;
	While Position >= 0 Do
		TableRow = QueryResult.Get(Position);
		If StrStartsWith(TableRow.PredefinedDataName, "Delete") Then
			QueryResult.Delete(Position);
		EndIf;
		Position = Position - 1;
	EndDo;
	
	InfobaseUpdate.MarkForProcessing(Parameters, QueryResult.UnloadColumn("Ref"));
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ContactInformationKindRef = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.ContactInformationKinds");
	
	MoreThanOneLanguage = Metadata.Languages.Count() > 1;
	Descriptions = ContactsManagerInternalCached.ContactInformationKindsDescriptions();
	
	ObjectsWithIssuesCount = 0;
	ObjectsProcessed = 0;
	
	SetAlwaysShow = CommonClientServer.CompareVersions("3.1.8.270", Parameters.SubsystemVersionAtStartUpdates) > 0;
	
	While ContactInformationKindRef.Next() Do
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.ContactInformationKinds");
		LockItem.SetValue("Ref", ContactInformationKindRef.Ref);
		
		RepresentationOfTheReference = String(ContactInformationKindRef.Ref);
		
		BeginTransaction();
		Try
			
			Block.Lock();
			
			ContactInformationKind = ContactInformationKindRef.Ref.GetObject(); // CatalogObject.ContactInformationKinds
			
			// Correcting descriptions in various languages
			If MoreThanOneLanguage Then
				KindName = ?(ValueIsFilled(ContactInformationKind.PredefinedKindName),
					ContactInformationKind.PredefinedKindName, ContactInformationKind.PredefinedDataName);
				
				If ValueIsFilled(KindName) Then
					SetContactInformationKindsDescriptions(ContactInformationKind, KindName, Descriptions);
				EndIf;
			EndIf;
			
			If Not ContactInformationKind.IsFolder And IsBlankString(ContactInformationKind.EditingOption) Then
				If ContactInformationKind.Type = Enums.ContactInformationTypes.WebPage 
					Or ContactInformationKind.DeleteEditInDialogOnly Then
					ContactInformationKind.EditingOption = "Dialog";
				ElsIf ContactInformationKind.Type = Enums.ContactInformationTypes.Email
					Or ContactInformationKind.Type = Enums.ContactInformationTypes.Skype
					Or ContactInformationKind.Type = Enums.ContactInformationTypes.Other Then
					ContactInformationKind.EditingOption = "InputField";
				Else
					ContactInformationKind.EditingOption = "InputFieldAndDialog";
				EndIf;
			EndIf;
			
			If Not ContactInformationKind.IsFolder
				And Not ValueIsFilled(ContactInformationKind.IDForFormulas) Then
				DescriptionForID = DescriptionForIDGeneration(ContactInformationKind.Description,
					ContactInformationKind.Presentations);
				// @skip-check query-in-loop - Read up-to-date data from the infobase at each iteration.
				ContactInformationKind.IDForFormulas = UUIDForFormulas(DescriptionForID,
					ContactInformationKind.Ref, ContactInformationKind.Parent);
			EndIf;
				
			If Not ContactInformationKind.IsFolder Then
				If SetAlwaysShow Then
					ContactInformationKind.IsAlwaysDisplayed = True;
				EndIf;
				If IsBlankString(ContactInformationKind.GroupName) Then
					ContactInformationKind.GroupName = NameOfContactInformationTypeGroup(ContactInformationKind.Parent);
				EndIf;
			EndIf;
							
			InfobaseUpdate.WriteData(ContactInformationKind);
			ObjectsProcessed = ObjectsProcessed + 1;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			
			// If you cannot process any kind of contact information, try again.
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			InfobaseUpdate.WriteErrorToEventLog(
				ContactInformationKindRef.Ref,
				RepresentationOfTheReference,
				ErrorInfo());
		EndTry;
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.ContactInformationKinds");
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some contact information kinds: %1';"), 
				ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.Catalogs.ContactInformationKinds,,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Yet another batch of contact information kinds is processed: %1';"),
					ObjectsProcessed));
	EndIf;
	
EndProcedure

Procedure SetContactInformationKindsDescriptions(ContactInformationKind, KindName, Descriptions)
	
	For Each Language In Metadata.Languages Do
		
		Presentation = Descriptions[Language.LanguageCode][KindName];
		If ValueIsFilled(Presentation) Then
			
			If StrCompare(Language.LanguageCode, Common.DefaultLanguageCode()) =  0 Then
				ContactInformationKind.Description = Presentation;
			Else
				
				If Descriptions[Language.LanguageCode][KindName] <> Undefined Then
					
					Filter = New Structure;
					Filter.Insert("LanguageCode",     Language.LanguageCode);
					FoundRows = ContactInformationKind.Presentations.FindRows(Filter);
					If FoundRows.Count() > 0 Then
						NewRow = FoundRows[0];
					Else
						NewRow = ContactInformationKind.Presentations.Add();
					EndIf;
					NewRow.LanguageCode     = Language.LanguageCode;
					NewRow.Description = Presentation;
				EndIf;
				
			EndIf;
			
		EndIf;
	EndDo;

EndProcedure

Function KeyAttributeName()
	Return "PredefinedKindName";
EndFunction

#EndRegion

#EndIf