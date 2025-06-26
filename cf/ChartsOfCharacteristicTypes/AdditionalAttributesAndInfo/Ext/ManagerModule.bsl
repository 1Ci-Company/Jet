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

// Returns object attributes that can be edited using the bulk attribute modification data processor.
// 
//
// Returns:
//  Array of String
//
Function AttributesToEditInBatchProcessing() Export
	
	AttributesToEdit = New Array;
	
	AttributesToEdit.Add("MultilineInputField");
	AttributesToEdit.Add("ValueFormTitle");
	AttributesToEdit.Add("ValueChoiceFormTitle");
	AttributesToEdit.Add("FormatProperties");
	AttributesToEdit.Add("Comment");
	AttributesToEdit.Add("ToolTip");
	
	Return AttributesToEdit;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.ObjectAttributesLock

// Returns:
//   See ObjectAttributesLockOverridable.OnDefineLockedAttributes.LockedAttributes.
//
Function GetObjectAttributesToLock() Export
	
	Result = New Array;
	
	Result.Add("ValueType");
	Result.Add("Name");
	Result.Add("IDForFormulas");
	
	Return Result;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ValueAllowed(Ref)
	|	OR NOT IsAdditionalInfo";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Property("IsAccessValueSelection") Then
		Parameters.Filter.Insert("IsAdditionalInfo", True);
	EndIf;
	
EndProcedure

#EndIf

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	Fields.Add("PropertiesSet");
	Fields.Add("Title");
	Fields.Add("Ref");
	
	StandardProcessing = False;
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	SetPresentation = "";
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If Not PropertyManagerCached.IsMainLanguage()
		And Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportClientServer = Common.CommonModule("NationalLanguageSupportClientServer");
		ModuleNationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing, "Title");
	EndIf;
	
	If ValueIsFilled(Data.PropertiesSet) Then
		PresentationOfPropertySets = PropertyManagerCached.PresentationOfPropertySets();
		SetPresentation = PresentationOfPropertySets.Get(Data.PropertiesSet);
	EndIf;
#Else
	If CommonClient.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportClientServer = CommonClient.CommonModule("NationalLanguageSupportClientServer");
		ModuleNationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing, "Title");
	EndIf;
#EndIf
	
	If Not ValueIsFilled(Presentation) Then
		Presentation = Data.Title;
	EndIf;
	
	If ValueIsFilled(Data.PropertiesSet) Then
		If Not ValueIsFilled(SetPresentation) Then
			SetPresentation = String(Data.PropertiesSet);
		EndIf;
		Presentation = Presentation + " (" + SetPresentation + ")";
	EndIf;
	StandardProcessing = False;
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

#Region IDUniquenessForFormulas

// Checks the ID uniqueness and that the ID complies with the syntax
// 
// Parameters:
//   IDForFormulas - String - iD for formulas.
//   Ref - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - a reference to the current object.
//   Cancel - Boolean - a cancellation flag if there is an error.
//
Procedure CheckIDUniqueness(IDForFormulas, Ref, Cancel) Export
	
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
			If Not IDForFormulasUnique(IDForFormulas, Ref) Then
				
				Cancel = True;
				
				ErrorText = NStr("en = 'ID for formulas ""%1"" is not unique';");
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
					IDForFormulas);
				Common.MessageToUser(ErrorText,, "IDForFormulas");
				
				LanguageCode = Common.DefaultLanguageCode();
				ErrorText = NStr("en = 'ID for formulas ""%1"" is not unique';", LanguageCode);
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
					IDForFormulas);
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
//   ObjectPresentation - String - a presentation from which an ID for formulas will be formed.
//   CurrentObjectRef - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - a reference to the current item.
// Returns:
//   String - — a unique ID value for formulas.
//
Function UUIDForFormulas(ObjectPresentation, CurrentObjectRef) Export

	Id = IDForFormulas(ObjectPresentation);
	If IsBlankString(Id) Then
		// Presentation consists of special characters and digits.
		Prefix = NStr("en = 'ID';");
		Id = IDForFormulas(Prefix + ObjectPresentation);
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AdditionalAttributesAndInfo.IDForFormulas AS IDForFormulas
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
	|WHERE
	|	AdditionalAttributesAndInfo.IDForFormulas = &IDForFormulas
	|	AND AdditionalAttributesAndInfo.Ref <> &CurrentObjectRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdditionalAttributesAndInfo.IDForFormulas AS IDForFormulas
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
	|WHERE
	|	AdditionalAttributesAndInfo.IDForFormulas LIKE &IDForFormulasSimilarity ESCAPE ""~""
	|	AND AdditionalAttributesAndInfo.Ref <> &CurrentObjectRef";
	Query.SetParameter("CurrentObjectRef", CurrentObjectRef);
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
	
	Return Id;
EndFunction

Function IDForFormulasUnique(IDToCheck, CurrentObjectRef)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AdditionalAttributesAndInfo.IDForFormulas AS IDForFormulas
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
	|WHERE
	|	AdditionalAttributesAndInfo.IDForFormulas = &IDForFormulas
	|	AND AdditionalAttributesAndInfo.Ref <> &CurrentObjectRef";
	Query.SetParameter("IDForFormulas", IDToCheck);
	Query.SetParameter("CurrentObjectRef", CurrentObjectRef);
	
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

Function TitleForIDGeneration(Val Title, Val Presentations)
	If CurrentLanguage().LanguageCode <> Common.DefaultLanguageCode() Then
		Filter = New Structure();
		Filter.Insert("LanguageCode", Common.DefaultLanguageCode());
		FoundRows = Presentations.FindRows(Filter);
		If FoundRows.Count() > 0 Then
			Title = FoundRows[0].Title;
		EndIf;
	EndIf;
	
	Return Title;
EndFunction

#EndRegion

// Changes the property setting from the common property or common list of property values
// to a separate property with separate value list.
// 
// Parameters:
//  Parameters - Structure:
//     * Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo
//     * CurrentPropertiesSet - CatalogRef.AdditionalAttributesAndInfoSets
//  StorageAddress - String
//
Procedure ChangePropertySetting(Parameters, StorageAddress) Export
	
	Property            = Parameters.Property;
	CurrentPropertiesSet = Parameters.CurrentPropertiesSet;
	
	OpenProperty = Undefined;
	Block = New DataLock;
	
	LockItem = Block.Add("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo");
	LockItem.SetValue("Ref", Property);
	
	LockItem = Block.Add("Catalog.AdditionalAttributesAndInfoSets");
	LockItem.SetValue("Ref", CurrentPropertiesSet);
	
	LockItem = Block.Add("Catalog.ObjectsPropertiesValues");
	LockItem = Block.Add("Catalog.ObjectPropertyValueHierarchy");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		ObjectProperty = Property.GetObject();
		
		Query = New Query;
		If ValueIsFilled(ObjectProperty.AdditionalValuesOwner) Then
			Query.SetParameter("Owner", ObjectProperty.AdditionalValuesOwner);
			ObjectProperty.AdditionalValuesOwner = Undefined;
			ObjectProperty.Write();
		Else
			Query.SetParameter("Owner", Property);
			NewObject = CreateItem();
			FillPropertyValues(NewObject, ObjectProperty, , "Parent, IDForFormulas");
			
			Filter = New Structure;
			Filter.Insert("PropertiesSet", CurrentPropertiesSet);
			SetDependencies = ObjectProperty.AdditionalAttributesDependencies.FindRows(Filter);
			For Each Dependence In SetDependencies Do
				FillPropertyValues(NewObject.AdditionalAttributesDependencies.Add(), Dependence);
			EndDo;
			
			ObjectProperty = NewObject;
			If ValueIsFilled(ObjectProperty.Name) Then
				NameAsParts = StrSplit(ObjectProperty.Name, "_");
				Name = NameAsParts[0];
				
				UID = New UUID();
				UIDString = StrReplace(String(UID), "-", "");
				ObjectProperty.Name = Name + "_" + UIDString;
			EndIf;
			ObjectProperty.PropertiesSet = CurrentPropertiesSet;
			ObjectProperty.Write();
			
			PropertySetObject = CurrentPropertiesSet.GetObject();
			If ObjectProperty.IsAdditionalInfo Then
				FoundRow = PropertySetObject.AdditionalInfo.Find(Property, "Property");
				If FoundRow = Undefined Then
					PropertySetObject.AdditionalInfo.Add().Property = ObjectProperty.Ref;
				Else
					FoundRow.Property = ObjectProperty.Ref;
					FoundRow.DeletionMark = False;
				EndIf;
			Else
				FoundRow = PropertySetObject.AdditionalAttributes.Find(Property, "Property");
				If FoundRow = Undefined Then
					PropertySetObject.AdditionalAttributes.Add().Property = ObjectProperty.Ref;
				Else
					FoundRow.Property = ObjectProperty.Ref;
					FoundRow.DeletionMark = False;
				EndIf;
			EndIf;
			PropertySetObject.Write();
		EndIf;
		
		OpenProperty = ObjectProperty.Ref;
		
		OwnerMetadata = PropertyManagerInternal.SetPropertiesValuesOwnerMetadata(
			CurrentPropertiesSet, False);
		
		If OwnerMetadata = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The %1 property settings were not changed.
				           |The %2 property set is not linked with any property value owner.';"),
				Property,
				CurrentPropertiesSet);
		EndIf;
		
		FullOwnerName = OwnerMetadata.FullName();
		RefsMap = New Map;
		
		HasAdditionalValues = PropertyManagerInternal.ValueTypeContainsPropertyValues(
			ObjectProperty.ValueType);
		
		If HasAdditionalValues Then
			
			If ObjectProperty.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
				CatalogName = "ObjectsPropertiesValues";
				IsFolder      = "Values.IsFolder";
			Else
				CatalogName = "ObjectPropertyValueHierarchy";
				IsFolder      = "FALSE AS IsFolder";
			EndIf;
			
			Query.Text =
			"SELECT
			|	Values.Ref AS Ref,
			|	Values.Parent AS RefParent,
			|	Values.IsFolder,
			|	Values.DeletionMark,
			|	Values.Description,
			|	Values.Weight
			|FROM
			|	Catalog.ObjectsPropertiesValues AS Values
			|WHERE
			|	Values.Owner = &Owner
			|TOTALS BY
			|	Ref HIERARCHY";
			Query.Text = StrReplace(Query.Text, "ObjectsPropertiesValues", CatalogName);
			Query.Text = StrReplace(Query.Text, "Values.IsFolder", IsFolder);
			
			Upload0 = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
			NewGroupsAndValues(Upload0.Rows, RefsMap, CatalogName, ObjectProperty.Ref);
			
		ElsIf Property = ObjectProperty.Ref Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The %1 property settings were not changed.
				           |The value type does not contain additional values.';"),
				Property);
		EndIf;
		
		If Property <> ObjectProperty.Ref
		 Or RefsMap.Count() > 0 Then
			
			Block = New DataLock;
			
			LockItem = Block.Add("InformationRegister.AdditionalInfo");
			LockItem.SetValue("Property", Property);
			
			LockItem = Block.Add("InformationRegister.AdditionalInfo");
			LockItem.SetValue("Property", ObjectProperty.Ref);
			
			// If the original property is common, then get the list of object's sets (for each reference).
			// If the replaceable property belongs not exclusively to the target set, then add the new property and value.
			// For common original properties, if their value owners have multiple property sets,
			//
			// the procedure runtime might take a while because sets in each owner are analyzed
			// (the procedure "PropertyManagerOverridable.FillObjectPropertiesSets" overrides the list of sets).
			// 
			// 
			
			OwnerWithAdditionalAttributes = False;
			
			If PropertyManagerInternal.IsMetadataObjectWithProperties(OwnerMetadata, "AdditionalAttributes") Then
				OwnerWithAdditionalAttributes = True;
				LockItem = Block.Add(FullOwnerName);
			EndIf;
			
			Block.Lock();
			
			EachOwnerObjectSetsAnalysisRequired = False;
			
			If Property <> ObjectProperty.Ref Then
				
				PredefinedItemName = StrReplace(OwnerMetadata.FullName(), ".", "_");
				PropertiesSet = PropertyManager.PropertiesSetByName(PredefinedItemName);
				If PropertiesSet = Undefined Then
					EachOwnerObjectSetsAnalysisRequired = Common.ObjectAttributeValue(
						"Catalog.AdditionalAttributesAndInfoSets." + PredefinedItemName, "IsFolder");
				Else
					EachOwnerObjectSetsAnalysisRequired = Common.ObjectAttributeValue(
						PropertiesSet, "IsFolder");
				EndIf;
				// If the predefined item is missing in the infobase.
				If EachOwnerObjectSetsAnalysisRequired = Undefined Then 
					EachOwnerObjectSetsAnalysisRequired = False;
				EndIf;
				
			EndIf;
			
			If EachOwnerObjectSetsAnalysisRequired Then
				AnalysisQuery = New Query;
				AnalysisQuery.SetParameter("CommonProperty", Property);
				AnalysisQuery.SetParameter("NewPropertySet", CurrentPropertiesSet);
				AnalysisQuery.Text =
				"SELECT TOP 1
				|	TRUE AS TrueValue
				|FROM
				|	Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo AS PropertiesSets
				|WHERE
				|	PropertiesSets.Ref <> &NewPropertySet
				|	AND PropertiesSets.Ref IN(&AllSetsForObject)
				|	AND PropertiesSets.Property = &CommonProperty";
			EndIf;
			
			Query = New Query;
			
			If Property = ObjectProperty.Ref Then
				// If the property is not changed (it's already individual), and only the list of additional values is common,
				// then replace only the additional values.
				Query.TempTablesManager = New TempTablesManager;
				
				ValueTable = New ValueTable;
				ValueTable.Columns.Add("Value", New TypeDescription(
					"CatalogRef." + CatalogName));
				
				For Each KeyAndValue In RefsMap Do
					ValueTable.Add().Value = KeyAndValue.Key;
				EndDo;
				
				Query.SetParameter("ValueTable", ValueTable);
				
				Query.Text =
				"SELECT
				|	ValueTable.Value AS Value
				|INTO PreviousValues1
				|FROM
				|	&ValueTable AS ValueTable
				|
				|INDEX BY
				|	Value";
				Query.Execute();
			EndIf;
			
			Query.SetParameter("Property", Property);
			AdditionalValuesTypes = New Map;
			AdditionalValuesTypes.Insert(Type("CatalogRef.ObjectsPropertiesValues"), True);
			AdditionalValuesTypes.Insert(Type("CatalogRef.ObjectPropertyValueHierarchy"), True);
			
			// Replace additional information records.
			
			If Property = ObjectProperty.Ref Then
				// If the property is not changed (it's already individual), and only the list of additional values is common,
				// then replace only the additional values.
				Query.Text =
				"SELECT TOP 1000
				|	AdditionalInfo.Object
				|FROM
				|	InformationRegister.AdditionalInfo AS AdditionalInfo
				|		INNER JOIN PreviousValues1 AS PreviousValues1
				|		ON (VALUETYPE(AdditionalInfo.Object) = TYPE(Catalog.ObjectsPropertiesValues))
				|			AND (NOT AdditionalInfo.Object IN (&ProcessedObjects))
				|			AND (AdditionalInfo.Property = &Property)
				|			AND AdditionalInfo.Value = PreviousValues1.Value";
			Else
				// If the property is changed (a common property becomes individual and its additional values are copied),
				// then replace the properties and the additional values.
				Query.Text =
				"SELECT TOP 1000
				|	AdditionalInfo.Object
				|FROM
				|	InformationRegister.AdditionalInfo AS AdditionalInfo
				|WHERE
				|	VALUETYPE(AdditionalInfo.Object) = TYPE(Catalog.ObjectsPropertiesValues)
				|	AND NOT AdditionalInfo.Object IN (&ProcessedObjects)
				|	AND AdditionalInfo.Property = &Property";
			EndIf;
			
			Query.Text = StrReplace(Query.Text, "Catalog.ObjectsPropertiesValues", FullOwnerName);
			
			OldRecordSet = InformationRegisters.AdditionalInfo.CreateRecordSet();
			NewRecordSet  = InformationRegisters.AdditionalInfo.CreateRecordSet();
			NewRecordSet.Add();
			
			ProcessedObjects = New Array;
			
			While True Do
				Query.SetParameter("ProcessedObjects", ProcessedObjects);
				Selection = Query.Execute().Select();
				If Selection.Count() = 0 Then
					Break;
				EndIf;
				While Selection.Next() Do
					Replace = True;
					If EachOwnerObjectSetsAnalysisRequired Then
						AnalysisQuery.SetParameter("AllSetsForObject",
							PropertyManagerInternal.GetObjectPropertySets(
								Selection.Object).UnloadColumn("Set"));
						// @skip-check query-in-loop. Batch processing of a large amount of data.
						Replace = AnalysisQuery.Execute().IsEmpty();
					EndIf;
					OldRecordSet.Filter.Object.Set(Selection.Object);
					OldRecordSet.Filter.Property.Set(Property);
					OldRecordSet.Read();
					If OldRecordSet.Count() > 0 Then
						NewRecordSet[0].Object   = Selection.Object;
						NewRecordSet[0].Property = ObjectProperty.Ref;
						Value = OldRecordSet[0].Value;
						If AdditionalValuesTypes[TypeOf(Value)] = Undefined Then
							NewRecordSet[0].Value = Value;
						Else
							NewRecordSet[0].Value = RefsMap[Value];
						EndIf;
						NewRecordSet.Filter.Object.Set(Selection.Object);
						NewRecordSet.Filter.Property.Set(NewRecordSet[0].Property);
						If Replace Then
							OldRecordSet.Clear();
							OldRecordSet.DataExchange.Load = True;
							OldRecordSet.Write();
						Else
							ProcessedObjects.Add(Selection.Object);
						EndIf;
						NewRecordSet.DataExchange.Load = True;
						NewRecordSet.Write();
					EndIf;
				EndDo;
			EndDo;
			
			// Replace additional attributes.
			
			If OwnerWithAdditionalAttributes Then
				
				If EachOwnerObjectSetsAnalysisRequired Then
					AnalysisQuery = New Query;
					AnalysisQuery.SetParameter("CommonProperty", Property);
					AnalysisQuery.SetParameter("NewPropertySet", CurrentPropertiesSet);
					AnalysisQuery.Text =
					"SELECT TOP 1
					|	TRUE AS TrueValue
					|FROM
					|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS PropertiesSets
					|WHERE
					|	PropertiesSets.Ref <> &NewPropertySet
					|	AND PropertiesSets.Ref IN(&AllSetsForObject)
					|	AND PropertiesSets.Property = &CommonProperty";
				EndIf;
				
				If Property = ObjectProperty.Ref Then
					// If the property is not changed (it's already individual), and only the list of additional values is common,
					// then replace only the additional values.
					Query.Text =
					"SELECT TOP 1000
					|	CurrentTable.Ref AS Ref
					|FROM
					|	TableName AS CurrentTable
					|		INNER JOIN PreviousValues1 AS PreviousValues1
					|		ON (NOT CurrentTable.Ref IN (&ProcessedObjects))
					|			AND (CurrentTable.Property = &Property)
					|			AND CurrentTable.Value = PreviousValues1.Value";
				Else
					// If the property is changed (a common property becomes individual and its additional values are copied),
					// then replace the properties and the additional values.
					Query.Text =
					"SELECT TOP 1000
					|	CurrentTable.Ref AS Ref
					|FROM
					|	TableName AS CurrentTable
					|WHERE
					|	NOT CurrentTable.Ref IN (&ProcessedObjects)
					|	AND CurrentTable.Property = &Property";
				EndIf;
				Query.Text = StrReplace(Query.Text, "TableName", FullOwnerName + ".AdditionalAttributes");
				
				ProcessedObjects = New Array;
				
				While True Do
					Query.SetParameter("ProcessedObjects", ProcessedObjects);
					Selection = Query.Execute().Select();
					If Selection.Count() = 0 Then
						Break;
					EndIf;
					While Selection.Next() Do
						CurrentObject = Selection.Ref.GetObject();
						Replace = True;
						If EachOwnerObjectSetsAnalysisRequired Then
							AnalysisQuery.SetParameter("AllSetsForObject",
								PropertyManagerInternal.GetObjectPropertySets(
									Selection.Ref).UnloadColumn("Set"));
							// @skip-check query-in-loop. Batch processing of a large amount of data.
							Replace = AnalysisQuery.Execute().IsEmpty();
						EndIf;
						For Each String In CurrentObject.AdditionalAttributes Do
							If String.Property = Property Then
								Value = String.Value;
								If AdditionalValuesTypes[TypeOf(Value)] <> Undefined Then
									Value = RefsMap[Value];
								EndIf;
								If Replace Then
									If String.Property <> ObjectProperty.Ref Then
										String.Property = ObjectProperty.Ref;
									EndIf;
									If String.Value <> Value Then
										String.Value = Value;
									EndIf;
								Else
									NewRow = CurrentObject.AdditionalAttributes.Add();
									NewRow.Property = ObjectProperty.Ref;
									NewRow.Value = Value;
									ProcessedObjects.Add(CurrentObject.Ref);
									Break;
								EndIf;
							EndIf;
						EndDo;
						If CurrentObject.Modified() Then
							CurrentObject.DataExchange.Load = True;
							CurrentObject.Write();
						EndIf;
					EndDo;
				EndDo;
			EndIf;
			
			If Property = ObjectProperty.Ref Then
				Query.TempTablesManager.Close();
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	PutToTempStorage(OpenProperty, StorageAddress);
	
EndProcedure

Procedure NewGroupsAndValues(Rows, RefsMap, CatalogName, Property, PreviousParent = Undefined)
	
	For Each String In Rows Do
		If String.Ref = PreviousParent Then
			Continue;
		EndIf;
		
		If String.IsFolder = True Then
			NewObject = Catalogs[CatalogName].CreateFolder();
			FillPropertyValues(NewObject, String, "Description, DeletionMark");
		Else
			NewObject = Catalogs[CatalogName].CreateItem();
			FillPropertyValues(NewObject, String, "Description, Weight, DeletionMark");
		EndIf;
		NewObject.Owner = Property;
		If ValueIsFilled(String.RefParent) Then
			NewObject.Parent = RefsMap[String.RefParent];
		EndIf;
		NewObject.Write();
		RefsMap.Insert(String.Ref, NewObject.Ref);
		
		NewGroupsAndValues(String.Rows, RefsMap, CatalogName, Property, String.Ref);
	EndDo;
	
EndProcedure

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	// Get a list of properties with the Obsolete prefix.
	PropertiesSets = New Array;
	NamesOfPredefinedSets = Metadata.Catalogs.AdditionalAttributesAndInfoSets.GetPredefinedNames();
	For Each PredefinedSetName In NamesOfPredefinedSets Do
		If StrStartsWith(PredefinedSetName, "Delete") Then
			Try
				PredefinedSet = Catalogs.AdditionalAttributesAndInfoSets[PredefinedSetName];
				PropertiesSets.Add(PredefinedSet);
			Except
				// Don't handle the exception. The data has no predefined item.
				Continue;
			EndTry;
		EndIf;
	EndDo;
	PropertiesSets.Add(Catalogs.AdditionalAttributesAndInfoSets.EmptyRef());
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	AdditionalAttributesAndInfo.Ref AS Ref
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
		|WHERE
		|	AdditionalAttributesAndInfo.Name LIKE """" ESCAPE ""~""
		|	OR AdditionalAttributesAndInfo.Name LIKE ""%-%"" ESCAPE ""~""
		|	OR AdditionalAttributesAndInfo.Name LIKE ""%«%"" ESCAPE ""~""
		|
		|UNION ALL
		|
		|SELECT
		|	AdditionalAttributesDependencies.Ref AS Ref
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.AdditionalAttributesDependencies AS AdditionalAttributesDependencies
		|WHERE
		|	AdditionalAttributesDependencies.PropertiesSet IN (&PropertiesSets)
		|
		|UNION ALL
		|
		|SELECT
		|	AdditionalAttributesAndInfo.Ref
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
		|WHERE
		|	IDForFormulas = """"";
		
	Query.SetParameter("PropertiesSets", PropertiesSets);
	
	Result = Query.Execute().Unload();
	ReferencesArrray = Result.UnloadColumn("Ref");
	
	InfobaseUpdate.MarkForProcessing(Parameters, ReferencesArrray);
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	FullName = "ChartOfCharacteristicTypes.AdditionalAttributesAndInfo";
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, FullName);
	
	ObjectsWithIssuesCount = 0;
	ObjectsProcessed = 0;
	
	While Selection.Next() Do
		RepresentationOfTheReference = String(Selection.Ref);
		BeginTransaction();
		Try
			// Lock the object (to ensure that it won't be edited in other sessions).
			Block = New DataLock;
			LockItem = Block.Add(FullName);
			Ref = Selection.Ref; // ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - 
			LockItem.SetValue("Ref", Ref);
			Block.Lock();
			
			Object = Ref.GetObject();
			
			If Not ValueIsFilled(Object.Name) Then
				// @skip-check query-in-loop. Batch processing of a large amount of data.
				SetAttributeName(Selection, Object);
			Else
				PropertyManagerInternal.DeleteDisallowedCharacters(Object.Name);
			EndIf;
			
			For Each Dependence In Object.AdditionalAttributesDependencies Do
				PredefinedDataName = "";
				If ValueIsFilled(Dependence.PropertiesSet) Then
					PredefinedDataName = Common.ObjectAttributeValue(Dependence.PropertiesSet, "PredefinedDataName");
					If Not StrStartsWith(PredefinedDataName, "Delete") Then
						Continue;
					EndIf;
				EndIf;
				If Not ValueIsFilled(PredefinedDataName) Then
					Dependence.PropertiesSet = Object.PropertiesSet;
				Else
					PrefixLength = StrLen("Delete");
					SetName = Mid(PredefinedDataName, PrefixLength + 1, StrLen(PredefinedDataName) - PrefixLength);
					NewSet = PropertyManager.PropertiesSetByName(SetName);
					If NewSet <> Undefined Then
						Dependence.PropertiesSet = NewSet;
					EndIf;
				EndIf;
			EndDo;
			
			If Not ValueIsFilled(Object.IDForFormulas) Then
				TitleForFormulas = TitleForIDGeneration(Object.Title, Object.Presentations);
				// @skip-check query-in-loop. Batch processing of a large amount of data.
				Object.IDForFormulas = UUIDForFormulas(TitleForFormulas, Object.Ref);
			EndIf;
			
			InfobaseUpdate.WriteData(Object);
			ObjectsProcessed = ObjectsProcessed + 1;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			InfobaseUpdate.WriteErrorToEventLog(
				Selection.Ref,
				RepresentationOfTheReference,
				ErrorInfo());
		EndTry;
		
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, FullName);
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Failed to process (skipped) some additional attributes or information records: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo,,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Yet another batch of additional attributes or information records is processed: %1';"),
				ObjectsProcessed));
	EndIf;
	
EndProcedure

Procedure SetAttributeName(Selection, Object)
	
	ObjectTitle = Object.Title;
	PropertyManagerInternal.DeleteDisallowedCharacters(ObjectTitle);
	ObjectTitleInParts = StrSplit(ObjectTitle, " ", False);
	For Each TitlePart In ObjectTitleInParts Do
		Object.Name = Object.Name + Upper(Left(TitlePart, 1)) + Mid(TitlePart, 2);
	EndDo;
	
	// Check the name for uniqueness.
	If NameUsed(Selection.Ref, Object.Name) Then
		UID = New UUID();
		UIDString = StrReplace(String(UID), "-", "");
		Object.Name = Object.Name + "_" + UIDString;
	EndIf;

EndProcedure

Function NameUsed(Ref, Name)
	
	Query = New Query;
	Query.Text =
		"SELECT TOP 1
		|	Properties.IsAdditionalInfo
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
		|WHERE
		|	Properties.Name = &Name
		|	AND Properties.Ref <> &Ref";
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Name",    Name);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#EndRegion

#EndIf