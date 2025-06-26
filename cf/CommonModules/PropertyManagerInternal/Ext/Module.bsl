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

// Returns the list of all metadata object properties.
//
// Parameters:
//  ObjectsKind - String - a full name of a metadata object;
//  PropertyKind  - String - "AdditionalAttributes", "AdditionalInfo", or "Labels".
//
// Returns:
//  ValueTable - Property, Description, ValueType, and FormatProperties.
//  Undefined - The given object kind has no property set.
//
Function PropertiesListForObjectsKind(ObjectsKind, Val PropertyKind) Export
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	PropertiesSets.Ref AS Ref,
		|	PropertiesSets.PredefinedDataName AS PredefinedDataName
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets AS PropertiesSets
		|WHERE
		|	PropertiesSets.Predefined";
	Selection = Query.Execute().Select();
	
	PredefinedDataName = StrReplace(ObjectsKind, ".", "_");
	SetRef = Undefined;
	
	While Selection.Next() Do
		If StrStartsWith(Selection.PredefinedDataName, "Delete") Then
			Continue;
		EndIf;
		
		If Selection.PredefinedDataName = PredefinedDataName Then
			SetRef = Selection.Ref;
			Break;
		EndIf;
	EndDo;
	
	If SetRef = Undefined Then
		SetRef = PropertyManager.PropertiesSetByName(PredefinedDataName);
		If SetRef = Undefined Then
			Return Undefined;
		EndIf;
	EndIf;
	
	QueryText = 
		"SELECT
		|	PropertiesTable.Property AS Property,
		|	PropertiesTable.Property.Description AS Description,
		|	PropertiesTable.Property.ValueType AS ValueType,
		|	PropertiesTable.Property.FormatProperties AS FormatProperties
		|FROM
		|	&PropertiesTable AS PropertiesTable
		|WHERE
		|	PropertiesTable.Ref IN HIERARCHY (&Ref)
		|	AND PropertiesTable.Property.PropertyKind IN (&PropertiesKinds)";
	
	PropertiesKinds = New Array;
	If PropertyKind = "AdditionalAttributes" Then
		FullTableName = "Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes";
		PropertiesKinds.Add(Enums.PropertiesKinds.EmptyRef());
		PropertiesKinds.Add(Enums.PropertiesKinds.AdditionalAttributes);
	ElsIf PropertyKind = "AdditionalInfo" Then
		FullTableName = "Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo";
		PropertiesKinds.Add(Enums.PropertiesKinds.EmptyRef());
		PropertiesKinds.Add(Enums.PropertiesKinds.AdditionalInfo);
	ElsIf PropertyKind = "Labels" Then
		FullTableName = "Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes";
		PropertiesKinds.Add(Enums.PropertiesKinds.Labels);
	Else
		Return Undefined;
	EndIf;
	QueryText = StrReplace(QueryText, "&PropertiesTable", FullTableName);
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", SetRef);
	Query.SetParameter("PropertiesKinds", PropertiesKinds);
	
	Result = Query.Execute().Unload();
	Result.GroupBy("Property,Description,ValueType,FormatProperties");
	Result.Sort("Description Asc");
	
	Return Result;
	
EndFunction

// Adds columns of additional attributes and properties to the column list for loading data.
//
// Parameters:
//  CatalogMetadata	 - MetadataObject - catalog metadata.
//  ColumnsInformation	 - ValueTable:
//     * Visible - Boolean
//     * ColumnPresentation - String
//     * Synonym - String
//     * IsRequiredInfo - Boolean
//     * Position - Number
//     * ColumnName - String
//     * Note - String
//     * ColumnType - Arbitrary
//     * Group - String
//     * Parent - String
//     * Width - Number
//
Procedure ColumnsForDataImport(CatalogMetadata, ColumnsInformation) Export
	
	If CatalogMetadata.TabularSections.Find("AdditionalAttributes") <> Undefined Then
		
		Position = ColumnsInformation.Count() + 1;
		Properties = PropertyManager.ObjectProperties(Catalogs[CatalogMetadata.Name].EmptyRef());
		
		PropertiesValues = PropertiesAdditionalValues(Properties);
		ValueMap = New Map;
		For Each AdditionalValue In PropertiesValues Do
			Value = ValueMap[AdditionalValue.Property];
			If Value = Undefined Then
				ValueMap.Insert(AdditionalValue.Property, 
					CommonClientServer.ValueInArray(AdditionalValue.Ref));
			Else
				ValueMap[AdditionalValue.Property].Add(AdditionalValue.Ref);
			EndIf;
		EndDo;
		
		AdditionalInfo = New Array;
		For Each Property In Properties Do
			If Not Property.IsAdditionalInfo Then
				
				ColumnName = "AdditionalAttribute_" 
					+ StandardSubsystemsServer.TransformStringToValidColumnDescription(String(Property));
				
				If ColumnsInformation.Find(ColumnName, "ColumnName") <> Undefined Then
					Continue;
				EndIf;
				
				ColumnsInfoRow = ColumnsInformation.Add();
				ColumnsInfoRow.ColumnName               = ColumnName;
				ColumnsInfoRow.ColumnPresentation     = String(Property);
				ColumnsInfoRow.ColumnType               = Property.ValueType;
				ColumnsInfoRow.IsRequiredInfo = Property.RequiredToFill;
				ColumnsInfoRow.Position                  = Position;
				ColumnsInfoRow.Group                   = NStr("en = 'Additional attributes';");
				ColumnsInfoRow.Visible                = True;
				ColumnsInfoRow.Note               = String(Property);
				ColumnsInfoRow.Width                   = 30;
				Position = Position + 1;
				
				Values = ValueMap[Property];
				If TypeOf(Values) = Type("Array") And Values.Count() > 0 Then
					ColumnsInfoRow.Note = ColumnsInfoRow.Note  + Chars.LF + NStr("en = 'Available values:';") + Chars.LF;
					For Each Value In Values Do
						Code = ?(ValueIsFilled(Value.Code), " (" + Value.Code + ")", "");
						ColumnsInfoRow.Note = ColumnsInfoRow.Note + Value.Description + Code +Chars.LF;
					EndDo;
				EndIf;
			Else
				AdditionalInfo.Add(Property);
			EndIf;
		EndDo;
		
		For Each Property In AdditionalInfo Do
			
			ColumnName = "Property_"
				+ StandardSubsystemsServer.TransformStringToValidColumnDescription(String(Property));
			
			If ColumnsInformation.Find(ColumnName, "ColumnName") <> Undefined Then
				Continue;
			EndIf;
			
			ColumnsInfoRow = ColumnsInformation.Add();
			ColumnsInfoRow.ColumnName               = ColumnName;
			ColumnsInfoRow.ColumnPresentation     = String(Property);
			ColumnsInfoRow.ColumnType               = Property.ValueType;
			ColumnsInfoRow.IsRequiredInfo = Property.RequiredToFill;
			ColumnsInfoRow.Position                  = Position;
			ColumnsInfoRow.Group                   = NStr("en = 'Additional properties';");
			ColumnsInfoRow.Visible                = True;
			ColumnsInfoRow.Note               = String(Property);
			ColumnsInfoRow.Width                   = 30;
			Position = Position + 1;
			
			Values = ValueMap[Property];
			If TypeOf(Values) = Type("Array") And Values.Count() > 0 Then
				ColumnsInfoRow.Note = ColumnsInfoRow.Note  + Chars.LF + NStr("en = 'Available values:';") + Chars.LF;
				For Each Value In Values Do
					Code = ?(ValueIsFilled(Value.Code), " (" + Value.Code + ")", "");
					ColumnsInfoRow.Note = ColumnsInfoRow.Note + Value.Description + Code +Chars.LF;
				EndDo;
			EndIf;
			
		EndDo;

	EndIf;

EndProcedure

Procedure ImportPropertiesValuesfromFile(ObjectReference, TableRow) Export
	
	Properties = New Map();
	
	If PropertyManager.UseAddlAttributes(ObjectReference)
		 Or PropertyManager.UseAddlInfo(ObjectReference) Then
			ListOfProperties = PropertyManager.ObjectProperties(ObjectReference);
			For Each Property In ListOfProperties Do
				Properties.Insert(String(Property), Property);
			EndDo;
	EndIf;
	
	PropertiesTable = New ValueTable;
	PropertiesTable.Columns.Add("Property");
	PropertiesTable.Columns.Add("Value");
	
	For Each Column In TableRow.Owner().Columns Do
		
		Prefix = "";
		
		If StrStartsWith(Column.Name, "AdditionalAttribute_") Then
			Prefix = "AdditionalAttribute_";
		ElsIf StrStartsWith(Column.Name, "Property_") Then
			Prefix = "Property_";
		EndIf;
		
		If IsBlankString(Prefix) Then
			Continue;
		EndIf;
		
		PropertyName = TrimAll(StandardSubsystemsServer.TransformAdaptedColumnDescriptionToString(Mid(Column.Name, 
			StrLen(Prefix) + 1)));
		Property = Properties.Get(PropertyName); // ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo
		If Property <> Undefined Then
			NewPropertiesRow = PropertiesTable.Add();
			NewPropertiesRow.Property = Property.Ref;
			NewPropertiesRow.Value = TableRow[Column.Name];
		EndIf;
		
	EndDo;
	
	If PropertiesTable.Count() > 0 Then
		PropertyManager.WriteObjectProperties(ObjectReference, PropertiesTable);
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.SharedData = True;
	Handler.HandlerManagement = True;
	Handler.Version = "*";
	Handler.ExecutionMode = "Seamless";
	Handler.Procedure = "PropertyManagerInternal.FillSeparatedDataHandlers";
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "PropertyManagerInternal.CreatePredefinedPropertiesSets";
	Handler.ExecutionMode = "Seamless";
	Handler.InitialFilling = True;
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.1.21";
	Handler.Procedure = "PropertyManagerInternal.SetUsageFlagValue";
	Handler.ExecutionMode = "Seamless";
	Handler.InitialFilling = True;
	
	Handler = Handlers.Add();
	Handler.Version = "3.1.5.128";
	Handler.Id = New UUID("ecd6aad4-4b04-43be-82bc-cd4f563beb0b");
	Handler.Procedure = "ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.ProcessDataForMigrationToNewVersion";
	Handler.Comment = NStr("en = 'Provides a unique name and updates the dependencies of additional attributes and information records.
		|Editing additional attributes and information records will be unavailable until the update is completed.';");
	Handler.ExecutionMode = "Deferred";
	Handler.UpdateDataFillingProcedure = "ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ObjectsToRead    = "ChartOfCharacteristicTypes.AdditionalAttributesAndInfo";
	Handler.ObjectsToChange  = "ChartOfCharacteristicTypes.AdditionalAttributesAndInfo";
	Handler.CheckProcedure  = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ObjectsToLock = "ChartOfCharacteristicTypes.AdditionalAttributesAndInfo";
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
	
		NewRow = Handler.ExecutionPriorities.Add();
		NewRow.Procedure = "NationalLanguageSupportServer.ProcessDataForMigrationToNewVersion";
		NewRow.Order = "Before";
	EndIf;
	
	Handler = Handlers.Add();
	Handler.Version = "3.1.7.53";
	Handler.ExecutionMode = "Seamless";
	Handler.Procedure = "PropertyManagerInternal.ClearUnusedSettings";
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.ExecutionMode = "Deferred";
	Handler.Id = New UUID("ee1168cd-6428-4980-9ee6-602812264cfa");
	Handler.Comment = NStr("en = 'Restructures additional attributes and information records.
		|Additional attributes and information records of some documents and catalogs
		|will be unavailable until the update is completed.';");
	Handler.Procedure = "Catalogs.AdditionalAttributesAndInfoSets.ProcessPropertiesSetsForMigrationToNewVersion";
	
EndProcedure

// See InfobaseUpdateSSL.OnAddApplicationMigrationHandlers.
Procedure OnAddApplicationMigrationHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.PreviousConfigurationName = "*";
	Handler.Procedure = "PropertyManagerInternal.CreatePredefinedPropertiesSets";
	
EndProcedure

// See ObjectAttributesLockOverridable.OnDefineObjectsWithLockedAttributes.
Procedure OnDefineObjectsWithLockedAttributes(Objects) Export
	Objects.Insert(Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.FullName(), "");
EndProcedure

// See also InfobaseUpdateOverridable.OnDefineSettings
//
// Parameters:
//  Objects - Array of MetadataObject
//
Procedure OnDefineObjectsWithInitialFilling(Objects) Export
	
	Objects.Add(Metadata.Catalogs.AdditionalAttributesAndInfoSets);
	
EndProcedure

// See BatchEditObjectsOverridable.OnDefineObjectsWithEditableAttributes.
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.ObjectsPropertiesValues.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.ObjectPropertyValueHierarchy.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.AdditionalAttributesAndInfoSets.FullName(), "AttributesToEditInBatchProcessing");
EndProcedure

// See ObjectsVersioningOverridable.OnPrepareObjectData
Procedure OnPrepareObjectData(Object, AdditionalAttributes) Export 
	
	GetAddlAttributes = PropertyManager.UseAddlAttributes(Object.Ref);
	GetAddlInfo = PropertyManager.UseAddlInfo(Object.Ref);
	
	If GetAddlAttributes Or GetAddlInfo Then
		For Each PropertyValue In PropertyManager.PropertiesValues(Object.Ref, GetAddlAttributes, GetAddlInfo) Do
			Attribute = AdditionalAttributes.Add();
			Attribute.Description = PropertyValue.Property;
			Attribute.Value = PropertyValue.Value;
		EndDo;
	EndIf;
	
EndProcedure

// See ObjectsVersioningOverridable.OnRestoreObjectVersion.
Procedure OnRestoreObjectVersion(Object, AdditionalAttributes) Export
	
	For Each Attribute In AdditionalAttributes Do
		If TypeOf(Attribute.Description) = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo") Then
			IsAdditionalInfo = Common.ObjectAttributeValue(Attribute.Description, "IsAdditionalInfo");
			If IsAdditionalInfo Then
				RecordSet = InformationRegisters.AdditionalInfo.CreateRecordSet();
				RecordSet.Filter.Object.Set(Object.Ref);
				RecordSet.Filter.Property.Set(Attribute.Description);
				
				Record = RecordSet.Add();
				Record.Property = Attribute.Description;
				Record.Value = Attribute.Value;
				Record.Object = Object.Ref;
				RecordSet.Write();
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// See CommonOverridable.OnAddReferenceSearchExceptions.
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export
	
	RefSearchExclusions.Add(Metadata.Catalogs.AdditionalAttributesAndInfoSets.FullName());
	RefSearchExclusions.Add("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.TabularSection.AdditionalAttributesDependencies.Attribute.Value");
	
EndProcedure

// See AccessManagementOverridable.OnFillAccessKinds.
Procedure OnFillAccessKinds(AccessKinds) Export
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name = "AdditionalInfo";
	AccessKind.Presentation = NStr("en = 'Additional information records';");
	AccessKind.ValuesType   = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo");
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction.
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.ObjectsPropertiesValues, True);
	Lists.Insert(Metadata.Catalogs.ObjectPropertyValueHierarchy, True);
	Lists.Insert(Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo, True);
	Lists.Insert(Metadata.InformationRegisters.AdditionalInfo, True);
	
EndProcedure

// See AccessManagementOverridable.OnFillAccessKindUsage.
Procedure OnFillAccessKindUsage(AccessKind, Use) Export
	
	SetPrivilegedMode(True);
	
	If AccessKind = "AdditionalInfo" Then
		Use = Constants.UseAdditionalAttributesAndInfo.Get();
	EndIf;
	
EndProcedure

// See AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionKinds.
Procedure OnFillMetadataObjectsAccessRestrictionKinds(LongDesc) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
	
	If ModuleAccessManagementInternal.AccessKindExists("AdditionalInfo") Then
		
		LongDesc = LongDesc + "
		|
		|Catalog.ObjectsPropertiesValues.Read.AdditionalInfo
		|Catalog.ObjectPropertyValueHierarchy.Read.AdditionalInfo
		|ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Read.AdditionalInfo
		|InformationRegister.AdditionalInfo.Read.AdditionalInfo
		|InformationRegister.AdditionalInfo.Update.AdditionalInfo
		|";
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddSessionParameterSettingHandlers.
Procedure OnAddSessionParameterSettingHandlers(Handlers) Export
	Handlers.Insert("PropertiesFillingInteractiveCheck", "PropertyManagerInternal.SessionParametersSetting");
EndProcedure

// See CommonOverridable.OnDefineSubordinateObjects
Procedure OnDefineSubordinateObjects(SubordinateObjects) Export

	SubordinateObject = SubordinateObjects.Add();
	SubordinateObject.SubordinateObject = Metadata.Catalogs.ObjectsPropertiesValues;
	SubordinateObject.LinksFields = "Owner, Description";
	SubordinateObject.OnSearchForReferenceReplacement = "PropertyManagerInternal";
	SubordinateObject.RunReferenceReplacementsAutoSearch = True;
	
	SubordinateObject = SubordinateObjects.Add();
	SubordinateObject.SubordinateObject = Metadata.Catalogs.ObjectPropertyValueHierarchy;
	SubordinateObject.LinksFields = "Owner, Description";
	SubordinateObject.OnSearchForReferenceReplacement = "PropertyManagerInternal";
	SubordinateObject.RunReferenceReplacementsAutoSearch = True;

EndProcedure

// 
Procedure OnDefineObjectsWithTablePresentation(Objects) Export
	Objects.Add("Catalog.ObjectsPropertiesValues");
	Objects.Add("Catalog.ObjectPropertyValueHierarchy");
	Objects.Add("Catalog.AdditionalAttributesAndInfoSets");
	Objects.Add("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo");
EndProcedure

// ACC:299-off a programmatically called procedure
//
// Called upon replacing duplicates in the item attributes.
//
// Parameters:
//  ReplacementPairs - Map - contains the value pairs original and duplicate.
//  UnprocessedOriginalsValues - Array of Structure:
//    * ValueToReplace - AnyRef - The original value of a replaceable object.
//    * UsedLinks - See Common.SubordinateObjectsLinksByTypes.
//    * KeyAttributesValue - Structure - Key is the attribute name. Value is the attribute value.
//
Procedure OnSearchForReferenceReplacement(ReplacementPairs, UnprocessedOriginalsValues) Export

	// If failed to fine the owner by the property value, change the owner.
	For Each UnprocessedDuplicate In UnprocessedOriginalsValues Do
		
		BeginTransaction();
		Try
		
			Block = New DataLock;
			Item = Block.Add(UnprocessedDuplicate.ValueToReplace.Metadata().FullName());
			Item.SetValue("Ref",  UnprocessedDuplicate.ValueToReplace);
			Block.Lock();
			
			NewValue = UnprocessedDuplicate.ValueToReplace.GetObject();
			NewValue.DataExchange.Load = True;
			NewValue.Owner = UnprocessedDuplicate.KeyAttributesValue.Owner;
			NewValue.Write();
			CommitTransaction();
		
		Except
			
			RollbackTransaction();
			WriteLogEvent(NStr("en = 'Reference search and replacement';", Common.DefaultLanguageCode()),
				EventLogLevel.Error,
				UnprocessedDuplicate.ValueToReplace.Metadata(),,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
		EndTry;
			
	EndDo;		

EndProcedure
// ACC:299-on

// See SSLSubsystemsIntegration.OnGetFullTextSearchResults
Procedure OnGetFullTextSearchResults(ObjectMetadata, Value, Presentation) Export
	
	// For additional information records, the form of the object (that owns the value) opens
	// instead of the form for writing to the information register.
	
	If ObjectMetadata = Metadata.InformationRegisters.AdditionalInfo Then 
		
		Value = Value.Object;
		ObjectMetadata = Value.Metadata();
		
		Presentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1: %2';"), 
			Common.ObjectPresentation(ObjectMetadata), 
			String(Value));
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure AdditionalAttributesFillCheckProcessing(Source, Cancel, CheckedAttributes) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	If Not GetFunctionalOption("UseAdditionalAttributesAndInfo") Then
		Return;
	EndIf;
	
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalAttributesAndInfoSets) Then
		Return;
	EndIf;
	
	If TypeOf(Source.Ref) = Type("CatalogRef.AdditionalAttributesAndInfoSets") Then
		Return;
	EndIf;
	
	If SessionParameters.PropertiesFillingInteractiveCheck Then
		SessionParameters.PropertiesFillingInteractiveCheck = False;
		Return;
	EndIf;
	
	// Additional attributes are attached to the object.
	Validation = New Structure;
	Validation.Insert("AdditionalAttributes", Undefined);
	Validation.Insert("IsFolder", False);
	FillPropertyValues(Validation, Source);
	
	If Validation.AdditionalAttributes = Undefined Then
		Return; // Run a quick check.
	EndIf;
	
	TabularSection = Source.Metadata().TabularSections.Find("AdditionalAttributes");
	If TabularSection = Undefined Then
		Return;
	EndIf;
	TabularSectionCheck = New Structure;
	TabularSectionCheck.Insert("Value");
	TabularSectionCheck.Insert("Property");
	TabularSectionCheck.Insert("TextString");
	FillPropertyValues(TabularSectionCheck, TabularSection.Attributes);
	If TabularSectionCheck.Property = Undefined
		Or TabularSectionCheck.Value = Undefined
		Or TabularSectionCheck.TextString = Undefined Then
		Return;
	EndIf;
	
	If Validation.IsFolder Then
		Return; // Don't enable attributes for groups.
	EndIf;
	
	FilledAttributes = Source.AdditionalAttributes.UnloadColumn("Property");
	
	SetsTable = GetObjectPropertySets(Source);
	Sets = SetsTable.UnloadColumn("Set");
	
	Query = New Query;
	Query.SetParameter("References", Sets);
	Query.SetParameter("FilledAttributes", FilledAttributes);
	Query.Text =
		"SELECT
		|	SetAttributes.Property AS Property
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS SetAttributes
		|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributes
		|		ON SetAttributes.Property = AdditionalAttributes.Ref
		|WHERE
		|	SetAttributes.Ref IN(&References)
		|	AND NOT SetAttributes.DeletionMark
		|	AND NOT AdditionalAttributes.DeletionMark
		|	AND AdditionalAttributes.RequiredToFill = TRUE
		|	AND NOT SetAttributes.Property IN (&FilledAttributes)";
	Result = Query.Execute().Unload();
	
	If Result.Count() = 0 Then
		Return; // No required ones.
	EndIf;
	Attributes = Result.UnloadColumn("Property");
	
	Messages = New Array;
	
	Dependencies = Common.ObjectsAttributesValues(Attributes, "AdditionalAttributesDependencies");
	For Each Item In Dependencies Do
		DependenciesTable = Item.Value.AdditionalAttributesDependencies.Unload();
		Filter = New Structure;
		Filter.Insert("DependentProperty", "RequiredToFill");
		FillingRequirementDependencies = DependenciesTable.FindRows(Filter);
		If FillingRequirementDependencies.Count() = 0 Then
			Text = NStr("en = 'Attribute ""%1"" is required.';");
			Text = StringFunctionsClientServer.SubstituteParametersToString(Text, Item.Key);
			Messages.Add(Text);
		Else
			// Getting all object attributes if a dependence is set up for them.
			AdditionalObjectAttributes = PropertyManager.ObjectProperties(Source, True, False);
			AttributesValues = New Structure;
			For Each AdditionalAttribute In AdditionalObjectAttributes Do
				String   = Validation.AdditionalAttributes.Find(AdditionalAttribute, "Property");
				Properties = Common.ObjectAttributesValues(AdditionalAttribute, "Name,ValueType");
				AttributeName = "_" + Properties.Name;
				If String = Undefined Then
					AttributesValues.Insert(AttributeName, Properties.ValueType.AdjustValue(Undefined));
				Else
					AttributesValues.Insert(AttributeName, String.Value);
				EndIf;
			EndDo;
			
			DependentAttributeDetails = New Structure;
			DependentAttributeDetails.Insert("FillingRequiredCondition", Undefined);
			Parameters = Undefined;
			For Each DependenciesRow In FillingRequirementDependencies Do
				If Sets.Find(DependenciesRow.PropertiesSet) = Undefined Then
					Continue;
				EndIf;
				
				If TypeOf(DependenciesRow.Attribute) = Type("String") Then
					AttributePath1 = "Parameters.ObjectDetails." + DependenciesRow.Attribute;
				Else
					AttributeName = "_" + Common.ObjectAttributeValue(DependenciesRow.Attribute, "Name");
					AttributePath1 = "Parameters.Form." + AttributeName;
				EndIf;
				
				BuildDependenciesConditions(DependentAttributeDetails, AttributePath1, DependenciesRow);
				Parameters = DependentAttributeDetails.FillingRequiredCondition;
			EndDo;
			
			If Parameters = Undefined Then
				FillingRequired = True;
			Else
				ConditionParameters = New Structure;
				ConditionParameters.Insert("ParameterValues", Parameters.ParameterValues);
				ConditionParameters.Insert("Form", AttributesValues);
				ConditionParameters.Insert("ObjectDetails", Source);
				
				FillingRequired = Common.CalculateInSafeMode(Parameters.ConditionCode, ConditionParameters);
			EndIf;
			
			If FillingRequired Then
				Text = NStr("en = 'Attribute ""%1"" is required.';");
				Text = StringFunctionsClientServer.SubstituteParametersToString(Text, Item.Key);
				Messages.Add(Text);
			EndIf;
		EndIf;
	EndDo;
	
	If Messages.Count() > 0 Then
		Common.MessageToUser(StrConcat(Messages, Chars.LF), , , , Cancel);
	EndIf;
	
EndProcedure

// Parameters:
//   DependentAttributeDetails - Structure
//   AttributePath1 - String
//   TableRow - ValueTableRow:
//      * DependentProperty - String
//      * PropertiesSet - CatalogRef.AdditionalAttributesAndInfoSets
//      * Attribute - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo
//      * Condition - String
//      * Value - String
//                 - Number
//                 - Boolean
//                 - Date
//                 - AnyRef
//
Procedure BuildDependenciesConditions(DependentAttributeDetails, AttributePath1, TableRow) Export
	
	// Converting the old condition for backward compatibility.
	ConditionByParts = StrSplit(TableRow.Condition, " ");
	NewCondition = "";
	If ConditionByParts.Count() > 0 Then
		For Each ConditionPart In ConditionByParts Do
			NewCondition = NewCondition + Upper(Left(ConditionPart, 1)) + Mid(ConditionPart, 2);
		EndDo;
	EndIf;
	
	If ValueIsFilled(NewCondition) Then
		TableRow.Condition = NewCondition;
	EndIf;
	
	ConditionTemplate = "";
	If TableRow.Condition = "Equal" Then
		ConditionTemplate = "%1 = %2";
	ElsIf TableRow.Condition = "NotEqual" Then
		ConditionTemplate = "%1 <> %2";
	EndIf;
	
	If TableRow.Condition = "InList" Then
		ConditionTemplate = "%2.FindByValue(%1) <> Undefined";
	ElsIf TableRow.Condition = "NotInList" Then
		ConditionTemplate = "%2.FindByValue(%1) = Undefined";
	EndIf;
	
	RightValue = "";
	If ValueIsFilled(ConditionTemplate) Then
		RightValue = "Parameters.ParameterValues[""" + AttributePath1 + """]";
	EndIf;
	
	If TableRow.Condition = "Filled" Then
		ConditionTemplate = "ValueIsFilled(%1)";
	ElsIf TableRow.Condition = "NotFilled" Then
		ConditionTemplate = "Not ValueIsFilled(%1)";
	EndIf;
	
	If ValueIsFilled(RightValue) Then
		ConditionCode = StringFunctionsClientServer.SubstituteParametersToString(ConditionTemplate, AttributePath1, RightValue);
	Else
		ConditionCode = StringFunctionsClientServer.SubstituteParametersToString(ConditionTemplate, AttributePath1);
	EndIf;
	
	If TableRow.DependentProperty = "Available" Then
		SetDependenceCondition(DependentAttributeDetails.AvailabilityCondition, AttributePath1, TableRow, ConditionCode, TableRow.Condition);
	ElsIf TableRow.DependentProperty = "isVisible" Then
		SetDependenceCondition(DependentAttributeDetails.VisibilityCondition, AttributePath1, TableRow, ConditionCode, TableRow.Condition);
	Else
		SetDependenceCondition(DependentAttributeDetails.FillingRequiredCondition, AttributePath1, TableRow, ConditionCode, TableRow.Condition);
	EndIf;

EndProcedure

Procedure SetDependenceCondition(DependenciesStructure, AttributePath1, TableRow, ConditionCode, Condition)
	If DependenciesStructure = Undefined Then
		ParameterValues = New Map;
		If Condition = "InList"
			Or Condition = "NotInList" Then
			Value = New ValueList;
			Value.Add(TableRow.Value);
		Else
			Value = TableRow.Value;
		EndIf;
		ParameterValues.Insert(AttributePath1, Value);
		DependenciesStructure = New Structure;
		DependenciesStructure.Insert("ConditionCode", ConditionCode);
		DependenciesStructure.Insert("ParameterValues", ParameterValues);
	ElsIf (Condition = "InList" Or Condition = "NotInList")
		And TypeOf(DependenciesStructure.ParameterValues[AttributePath1]) = Type("ValueList") Then
		AttributeValues = DependenciesStructure.ParameterValues[AttributePath1]; // ValueList
		AttributeValues.Add(TableRow.Value);
	Else
		DependenciesStructure.ConditionCode = DependenciesStructure.ConditionCode + " And " + ConditionCode;
		If Condition = "InList" Or Condition = "NotInList" Then
			Value = New ValueList;
			Value.Add(TableRow.Value);
		Else
			Value = TableRow.Value;
		EndIf;
		DependenciesStructure.ParameterValues.Insert(AttributePath1, Value);
	EndIf;
EndProcedure

// Parameters:
//  ParameterName - String
//  SpecifiedParameters - Array of String
//
Procedure SessionParametersSetting(Val ParameterName, SpecifiedParameters) Export
	If ParameterName = "PropertiesFillingInteractiveCheck" Then
		SessionParameters.PropertiesFillingInteractiveCheck = False;
		SpecifiedParameters.Add("PropertiesFillingInteractiveCheck");
	EndIf;
EndProcedure

// See PropertyManager.TransferValuesFromFormAttributesToObject.
Procedure TransferValuesFromFormAttributesToObject(Form, Object = Undefined, BeforeWrite = False) Export
	
	Receiver = New Structure;
	Receiver.Insert("PropertiesParameters", Undefined);
	FillPropertyValues(Receiver, Form);
	
	If Not Form.PropertiesUseProperties
		Or Not Form.PropertiesUseAddlAttributes
		Or (TypeOf(Receiver.PropertiesParameters) = Type("Structure")
			And Receiver.PropertiesParameters.Property("DeferredInitializationExecuted")
			And Not Receiver.PropertiesParameters.DeferredInitializationExecuted) Then
		
		Return;
	EndIf;
	
	If Object = Undefined Then
		ObjectDetails = Form.Object;
	Else
		ObjectDetails = Object;
	EndIf;
	
	PreviousValues1 = ObjectDetails.AdditionalAttributes.Unload();
	AdditionalAttributes = PropertyManager.PropertiesByAdditionalAttributesKind(
		ObjectDetails.AdditionalAttributes.Unload(),
		Enums.PropertiesKinds.AdditionalAttributes);
	For Each AdditionalAttribute In AdditionalAttributes Do
		Properties = ObjectDetails.AdditionalAttributes.FindRows(
			New Structure("Property", AdditionalAttribute));
		For Each Property In Properties Do
			ObjectDetails.AdditionalAttributes.Delete(Property);
		EndDo;
	EndDo;
	
	For Each LongDesc In Form.PropertiesAdditionalAttributeDetails Do
		
		Value = Form[LongDesc.ValueAttributeName];
		If Value = Undefined Then
			Continue;
		EndIf;
		
		If LongDesc.ValueType.Types().Count() = 1
		   And (Not ValueIsFilled(Value) Or Value = False) Then
			
			Continue;
		EndIf;
		
		If LongDesc.Deleted Then
			If ValueIsFilled(Value) And Not (BeforeWrite And Form.PropertiesHideDeleted) Then
				FoundRow = PreviousValues1.Find(LongDesc.Property, "Property");
				If FoundRow <> Undefined Then
					FillPropertyValues(ObjectDetails.AdditionalAttributes.Add(), FoundRow);
				EndIf;
			EndIf;
			Continue;
		EndIf;
		
		// Support of hyperlink strings.
		UseStringAsLink = UseStringAsLink(
			LongDesc.ValueType, LongDesc.OutputAsHyperlink, LongDesc.MultilineInputField);
		
		NewRow = ObjectDetails.AdditionalAttributes.Add();
		NewRow.Property = LongDesc.Property;
		If UseStringAsLink Then
			AddressAndPresentation = AddressAndPresentation(Value);
			NewRow.Value = AddressAndPresentation.Presentation;
		Else
			NewRow.Value = Value;
		EndIf;
		
		// Support of strings with unlimited length.
		UseUnlimitedString = UseUnlimitedString(
			LongDesc.ValueType, LongDesc.MultilineInputField);
		
		If UseUnlimitedString Or UseStringAsLink Then
			NewRow.TextString = Value;
		EndIf;
	EndDo;
	
	If BeforeWrite Then
		Form.PropertiesHideDeleted = False;
	EndIf;
	
EndProcedure

Procedure MoveSetLabelsIntoObject(Form, Object = Undefined) Export
	
	If Not Form.PropertiesUseProperties
		Or Not Form.PropertiesUseAddlAttributes Then
		Return;
	EndIf;
	
	If Object = Undefined Then
		ObjectDetails = Form.Object;
	Else
		ObjectDetails = Object;
	EndIf; 
	
	Labels = PropertyManager.PropertiesByAdditionalAttributesKind(
		ObjectDetails.AdditionalAttributes.Unload(),
		Enums.PropertiesKinds.Labels);
	For Each Label In Labels Do
		Properties = ObjectDetails.AdditionalAttributes.FindRows(New Structure("Property", Label));
		For Each Property In Properties Do
			ObjectDetails.AdditionalAttributes.Delete(Property);
		EndDo;
	EndDo;
	
	For Each LabelApplied In Form.Properties_LabelsApplied Do
		Label = ObjectDetails.AdditionalAttributes.Add();
		Label.Property = LabelApplied.Value;
		Label.Value = True;
	EndDo;
	
EndProcedure

// Returns a table of available owner property sets.
//
// Parameters:
//  PropertiesOwner - AnyRef - a reference to a property owner.
//                  - CatalogObjectCatalogName
//                  - DocumentObjectDocumentName
//                  - ChartOfCharacteristicTypesObjectChartOfCharacteristicTypesName
//                  - BusinessProcessObjectNameOfBusinessProcess
//                  - TaskObjectTaskName
//                  - ChartOfCalculationTypesObjectChartOfCalculationTypesName
//                  - ChartOfAccountsObjectChartOfAccountsName
//                  - FormDataStructure:
//                       * Ref - AnyRef
//  AssignmentKey - String
//
// Returns:
//   See PropertyManagerOverridable.FillObjectPropertiesSets.PropertiesSets
//
Function GetObjectPropertySets(Val PropertiesOwner, AssignmentKey = Undefined) Export
	
	If TypeOf(PropertiesOwner) = Type("FormDataStructure") Then
		RefType = TypeOf(PropertiesOwner.Ref);
	ElsIf Common.IsReference(TypeOf(PropertiesOwner)) Then
		RefType = TypeOf(PropertiesOwner);
	Else
		RefType = TypeOf(PropertiesOwner.Ref)
	EndIf;
	
	GetDefaultSet = True;
	
	PropertiesSets = New ValueTable;
	PropertiesSets.Columns.Add("Set");
	PropertiesSets.Columns.Add("Height");
	PropertiesSets.Columns.Add("Title");
	PropertiesSets.Columns.Add("ToolTip");
	PropertiesSets.Columns.Add("VerticalStretch");
	PropertiesSets.Columns.Add("HorizontalStretch");
	PropertiesSets.Columns.Add("ReadOnly");
	PropertiesSets.Columns.Add("TitleTextColor");
	PropertiesSets.Columns.Add("Width");
	PropertiesSets.Columns.Add("TitleFont");
	PropertiesSets.Columns.Add("Group");
	PropertiesSets.Columns.Add("Representation");
	PropertiesSets.Columns.Add("Picture");
	PropertiesSets.Columns.Add("ShowTitle");
	PropertiesSets.Columns.Add("SharedSet", New TypeDescription("Boolean"));
	// Obsolete:
	PropertiesSets.Columns.Add("SlaveItemsWidth");
	
	PropertyManagerOverridable.FillObjectPropertiesSets(
		PropertiesOwner, RefType, PropertiesSets, GetDefaultSet, AssignmentKey);
	
	If PropertiesSets.Count() = 0
	   And GetDefaultSet = True Then
		
		MainSet = GetDefaultObjectPropertySet(PropertiesOwner);
		
		If ValueIsFilled(MainSet) Then
			PropertiesSets.Add().Set = MainSet;
		EndIf;
	EndIf;
	
	Return PropertiesSets;
	
EndFunction

// Returns a filled table of object property values.
// 
// Parameters:
//   AdditionalObjectProperties - ValueTable
//   Sets - ValueTable
//   PropertyKind - EnumRef.PropertiesKinds
//
Function PropertiesValues(AdditionalObjectProperties, Sets, PropertyKind) Export
	
	If AdditionalObjectProperties.Count() = 0 Then
		// Preliminary quick check of additional properties usage.
		PropertiesNotFound = AdditionalAttributesAndInfoNotFound(Sets, PropertyKind);
		
		If PropertiesNotFound Then
			PropertiesDetails = New ValueTable;
			PropertiesDetails.Columns.Add("Set");
			PropertiesDetails.Columns.Add("Property");
			PropertiesDetails.Columns.Add("AdditionalValuesOwner");
			PropertiesDetails.Columns.Add("RequiredToFill");
			PropertiesDetails.Columns.Add("Description");
			PropertiesDetails.Columns.Add("ValueType");
			PropertiesDetails.Columns.Add("FormatProperties");
			PropertiesDetails.Columns.Add("MultilineInputField");
			PropertiesDetails.Columns.Add("Deleted");
			PropertiesDetails.Columns.Add("Value");
			PropertiesDetails.Columns.Add("PictureNumber");
			Return PropertiesDetails;
		EndIf;
	EndIf;
	
	Properties = AdditionalObjectProperties.UnloadColumn("Property");
	
	PropertiesSets = New ValueTable;
	
	PropertiesSets.Columns.Add(
		"Set", New TypeDescription("CatalogRef.AdditionalAttributesAndInfoSets"));
	
	PropertiesSets.Columns.Add(
		"SetOrder", New TypeDescription("Number"));
	
	For Each ListItem In Sets Do
		NewRow = PropertiesSets.Add();
		NewRow.Set         = ListItem.Value;
		NewRow.SetOrder = Sets.IndexOf(ListItem);
	EndDo;
	
	Query = New Query;
	Query.SetParameter("Properties",      Properties);
	Query.SetParameter("PropertiesSets", PropertiesSets);
	Query.SetParameter("IsMainLanguage", Common.IsMainLanguage());
	Query.SetParameter("LanguageCode", CurrentLanguage().LanguageCode);
	Query.SetParameter("PropertyKind", PropertyKind);
	
	Query.Text =
	"SELECT
	|	PropertiesSets.Set AS Set,
	|	PropertiesSets.SetOrder AS SetOrder
	|INTO PropertiesSets
	|FROM
	|	&PropertiesSets AS PropertiesSets
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PropertiesSets.Set AS Set,
	|	PropertiesSets.SetOrder AS SetOrder,
	|	SetsProperties.Property AS Property,
	|	SetsProperties.DeletionMark AS DeletionMark,
	|	SetsProperties.LineNumber AS PropertyOrder
	|INTO SetsProperties
	|FROM
	|	PropertiesSets AS PropertiesSets
	|		INNER JOIN Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS SetsProperties
	|			INNER JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
	|			ON SetsProperties.Property = Properties.Ref
	|		ON (SetsProperties.Ref = PropertiesSets.Set)
	|WHERE
	|	NOT SetsProperties.DeletionMark
	|	AND NOT Properties.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Properties.Ref AS Property
	|INTO CompletedProperties
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
	|WHERE
	|	Properties.Ref IN(&Properties)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SetsProperties.Set AS Set,
	|	SetsProperties.SetOrder AS SetOrder,
	|	SetsProperties.Property AS Property,
	|	SetsProperties.PropertyOrder AS PropertyOrder,
	|	SetsProperties.DeletionMark AS Deleted
	|INTO AllProperties
	|FROM
	|	SetsProperties AS SetsProperties
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(Catalog.AdditionalAttributesAndInfoSets.EmptyRef),
	|	0,
	|	CompletedProperties.Property,
	|	0,
	|	TRUE
	|FROM
	|	CompletedProperties AS CompletedProperties
	|		LEFT JOIN SetsProperties AS SetsProperties
	|		ON CompletedProperties.Property = SetsProperties.Property
	|WHERE
	|	SetsProperties.Property IS NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AllProperties.Set AS Set,
	|	AllProperties.Property AS Property,
	|	AdditionalAttributesAndInfo.AdditionalValuesOwner AS AdditionalValuesOwner,
	|	AdditionalAttributesAndInfo.RequiredToFill AS RequiredToFill,
	|	AdditionalAttributesAndInfo.Title AS Description,
	|	AdditionalAttributesAndInfo.ValueType AS ValueType,
	|	AdditionalAttributesAndInfo.FormatProperties AS FormatProperties,
	|	AdditionalAttributesAndInfo.MultilineInputField AS MultilineInputField,
	|	AllProperties.Deleted AS Deleted,
	|	AdditionalAttributesAndInfo.Available AS Available,
	|	AdditionalAttributesAndInfo.isVisible AS isVisible,
	|	AdditionalAttributesAndInfo.ToolTip AS ToolTip,
	|	AdditionalAttributesAndInfo.OutputAsHyperlink AS OutputAsHyperlink,
	|	AdditionalAttributesAndInfo.AdditionalAttributesDependencies.(
	|		DependentProperty AS DependentProperty,
	|		Attribute AS Attribute,
	|		Condition AS Condition,
	|		Value AS Value,
	|		PropertiesSet AS PropertiesSet
	|	) AS AdditionalAttributesDependencies,
	|	CASE
	|		WHEN AdditionalAttributesAndInfo.DeletionMark = TRUE
	|			THEN 12
	|		WHEN AdditionalAttributesAndInfo.PropertyKind = VALUE(Enum.PropertiesKinds.Labels)
	|			THEN AdditionalAttributesAndInfo.PropertiesColor.Order + 1
	|		ELSE 11
	|	END AS PictureNumber
	|FROM
	|	AllProperties AS AllProperties
	|		INNER JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
	|		ON AllProperties.Property = AdditionalAttributesAndInfo.Ref
	|WHERE
	|	AdditionalAttributesAndInfo.IsAdditionalInfo = &IsAdditionalInfoSets
	|	AND AdditionalAttributesAndInfo.PropertyKind IN (VALUE(Enum.PropertiesKinds.EmptyRef), &PropertyKind)
	|ORDER BY
	|	Deleted,
	|	AllProperties.SetOrder,
	|	AllProperties.PropertyOrder";
	
	If PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
		Query.Text = StrReplace(
			Query.Text,
			"Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes",
			"Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo");
		IsAdditionalInfoSets = True;
	ElsIf PropertyKind = Enums.PropertiesKinds.Labels Then
		Query.Text = StrReplace(
			Query.Text,
			"IN (VALUE(Enum.PropertiesKinds.EmptyRef), &PropertyKind)",
			"= VALUE(Enum.PropertiesKinds.Labels)");
		IsAdditionalInfoSets = False;
	Else
		IsAdditionalInfoSets = False;
	EndIf;
	Query.SetParameter("IsAdditionalInfoSets", IsAdditionalInfoSets);
	
	CurrentLanguageSuffix = Common.CurrentUserLanguageSuffix();
	If CurrentLanguageSuffix = Undefined Then
		Query.Text = StrReplace(Query.Text,
			"	AllProperties AS AllProperties
			|		INNER JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
			|		ON AllProperties.Property = AdditionalAttributesAndInfo.Ref",
			"	AllProperties AS AllProperties
			|		INNER JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
			|		ON AllProperties.Property = AdditionalAttributesAndInfo.Ref
			|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Presentations AS PresentationProperties
			|		ON (PresentationProperties.Ref = AdditionalAttributesAndInfo.Ref)
			|			AND (PresentationProperties.LanguageCode = &LanguageCode)");
			
		Query.Text = StrReplace(Query.Text, "AdditionalAttributesAndInfo.Title AS Description",
			"CAST(ISNULL(PresentationProperties.Title, AdditionalAttributesAndInfo.Title) AS STRING(150)) AS Description");
		
		Query.Text = StrReplace(Query.Text, "AdditionalAttributesAndInfo.ToolTip AS ToolTip",
			"CAST(ISNULL(PresentationProperties.ToolTip, AdditionalAttributesAndInfo.ToolTip) AS STRING(150)) AS ToolTip");
			
	Else
		
		If ValueIsFilled(CurrentLanguageSuffix) And Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
			ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(Query.Text, "AdditionalAttributesAndInfo.Title AS Description");
			ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(Query.Text, "AdditionalAttributesAndInfo.ToolTip AS ToolTip");
		EndIf;
		
	EndIf;
	
	PropertiesDetails = Query.Execute().Unload();
	PropertiesDetails.Indexes.Add("Property");
	PropertiesDetails.Columns.Add("Value");
	
	// Deleting property duplicates in subordinate property sets.
	If Sets.Count() > 1 Then
		IndexOf = PropertiesDetails.Count()-1;
		
		While IndexOf >= 0 Do
			String = PropertiesDetails[IndexOf];
			FoundRow = PropertiesDetails.Find(String.Property, "Property");
			
			If FoundRow <> Undefined
			   And FoundRow <> String Then
				
				PropertiesDetails.Delete(IndexOf);
			EndIf;
			
			IndexOf = IndexOf-1;
		EndDo;
	EndIf;
	
	// Populate property values.
	For Each LongDesc In AdditionalObjectProperties Do
		PropertyDetails = PropertiesDetails.Find(LongDesc.Property, "Property");
		If PropertyDetails <> Undefined Then
			// Support of strings with unlimited length.
			If PropertyKind = Enums.PropertiesKinds.AdditionalAttributes Then
				UseStringAsLink = UseStringAsLink(
					PropertyDetails.ValueType,
					PropertyDetails.OutputAsHyperlink,
					PropertyDetails.MultilineInputField);
				UseUnlimitedString = UseUnlimitedString(
					PropertyDetails.ValueType,
					PropertyDetails.MultilineInputField);
				NeedToTransferValueFromRef = NeedToTransferValueFromRef(
						LongDesc.TextString,
						LongDesc.Value);
				If (UseUnlimitedString
						Or UseStringAsLink
						Or NeedToTransferValueFromRef)
					And Not IsBlankString(LongDesc.TextString) Then
					If Not UseStringAsLink And NeedToTransferValueFromRef Then
						ValueWithoutRef = ValueWithoutRef(LongDesc.TextString, LongDesc.Value);
						PropertyDetails.Value = ValueWithoutRef;
					Else
						PropertyDetails.Value = LongDesc.TextString;
					EndIf;
				Else
					PropertyDetails.Value = LongDesc.Value;
				EndIf;
			Else
				PropertyDetails.Value = LongDesc.Value;
			EndIf;
		EndIf;
	EndDo;
	
	Return PropertiesDetails;
	
EndFunction

// For internal use only.
//
Function AdditionalAttributesAndInfoNotFound(Sets, PropertyKind, DeferredInitialization = False)
	
	Query = New Query;
	Query.SetParameter("PropertiesSets", Sets.UnloadValues());
	Query.Text =
	"SELECT TOP 1
	|	SetsProperties.Property AS Property
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS SetsProperties
	|WHERE
	|	SetsProperties.Ref IN(&PropertiesSets)
	|	AND NOT SetsProperties.DeletionMark";
	
	If PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
		Query.Text = StrReplace(
			Query.Text,
			"Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes",
			"Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo");
	EndIf;
	
	SetPrivilegedMode(True);
	PropertiesNotFound = Query.Execute().IsEmpty();
	SetPrivilegedMode(False);
	
	Return PropertiesNotFound;
EndFunction

Function DisplayMoreTab(Ref, Sets) Export
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("PropertiesSets", Sets.UnloadValues());
	Query.Text = 
		"SELECT TOP 1
		|	AdditionalAttributes.Property AS Property
		|FROM
		|	&TableName AS AdditionalAttributes
		|WHERE
		|	AdditionalAttributes.Ref = &Ref
		|;
		|
		|SELECT TOP 1
		|	SetsProperties.Property AS Property
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS SetsProperties
		|WHERE
		|	SetsProperties.Ref IN(&PropertiesSets)
		|	AND NOT SetsProperties.DeletionMark";
	Query.Text = StrReplace(Query.Text, "&TableName", Ref.Metadata().FullName() + ".AdditionalAttributes");
	Result = Query.ExecuteBatch();
	
	Return Not (Result[0].IsEmpty() And Result[1].IsEmpty());
	
EndFunction

// Returns the metadata object that is the owner of property
// values of additional attribute and info set.
// 
// Parameters:
//  Ref - AnyRef
//
Function SetPropertiesValuesOwnerMetadata(Ref, ConsiderDeletionMark = True, RefType = Undefined) Export
	
	If Not ValueIsFilled(Ref) Then
		Return Undefined;
	EndIf;
	
	PredefinedPropertiesSets = PropertyManagerCached.PredefinedPropertiesSets();
	
	If TypeOf(Ref) = Type("Structure") Then
		ReferenceProperties = Ref;
	Else
		ReferenceProperties = Common.ObjectAttributesValues(
			Ref, "DeletionMark, IsFolder, Predefined, Parent, PredefinedDataName, PredefinedSetName");
	EndIf;
	
	If ValueIsFilled(ReferenceProperties.PredefinedSetName) Then
		ReferenceProperties.PredefinedDataName = ReferenceProperties.PredefinedSetName;
		ReferenceProperties.Predefined          = True;
	EndIf;
	
	If ConsiderDeletionMark And ReferenceProperties.DeletionMark Then
		Return Undefined;
	EndIf;
	
	If ReferenceProperties.IsFolder Then
		PredefinedRef1 = Ref;
		
	ElsIf ReferenceProperties.Predefined
	        And ReferenceProperties.Parent = Catalogs.AdditionalAttributesAndInfoSets.EmptyRef()
	        Or ReferenceProperties.Parent = Undefined Then
		
		PredefinedRef1 = Ref;
	Else
		PredefinedRef1 = ReferenceProperties.Parent;
	EndIf;
	
	If Ref <> PredefinedRef1 Then
		SetProperties = PredefinedPropertiesSets.Get(ReferenceProperties.Parent);
		If SetProperties <> Undefined Then
			SetProperties = PredefinedPropertiesSets.Get(PredefinedRef1);// See Catalogs.AdditionalAttributesAndInfoSets.SetProperties
			PredefinedItemName = SetProperties.Name;
		Else
			PredefinedItemName = Common.ObjectAttributeValue(PredefinedRef1, "PredefinedDataName");
		EndIf;
	Else
		PredefinedItemName = ReferenceProperties.PredefinedDataName;
	EndIf;
	
	Position = StrFind(PredefinedItemName, "_");
	
	FirstNamePart =  Left(PredefinedItemName, Position - 1);
	SecondNamePart = Right(PredefinedItemName, StrLen(PredefinedItemName) - Position);
	
	FullTableName = FirstNamePart + "." + SecondNamePart;
	OwnerMetadata = Common.MetadataObjectByFullName(FullTableName);
	
	If OwnerMetadata <> Undefined Then
		RefType = Type(FirstNamePart + "Ref." + SecondNamePart);
	EndIf;
	
	Return OwnerMetadata;
	
EndFunction

// Returns the usage of additional attributes and info by the set.
Function SetPropertiesTypes(Ref, ConsiderDeletionMark = True) Export
	
	SetPropertiesTypes = PropertyManagerCached.SetPropertiesTypes(Ref, ConsiderDeletionMark);
	Return SetPropertiesTypes;
	
EndFunction

// Parameters:
//  AllSets See PropertyManagerOverridable.FillObjectPropertiesSets.PropertiesSets
//  SetsWithAttributes - ValueList
//
Procedure FillSetsWithAdditionalAttributes(AllSets, SetsWithAttributes) Export
	
	References = AllSets.UnloadColumn("Set");
	ExcludeBrokenPropertiesSets(References, Undefined);
	ExcludeBrokenPropertiesSets(References, Null);
	
	ReferencesProperties = Common.ObjectsAttributesValues(
		References, "DeletionMark, IsFolder, Predefined, Parent, PredefinedDataName, PredefinedSetName");
	
	For Each ReferenceProperties In ReferencesProperties Do
		RefType = Undefined;
		OwnerMetadata = SetPropertiesValuesOwnerMetadata(ReferenceProperties.Value, True, RefType);
		
		If OwnerMetadata = Undefined Then
			Return;
		EndIf;
		
		// Checking additional attributes usage.
		If OwnerMetadata.TabularSections.Find("AdditionalAttributes") <> Undefined Then
			String = AllSets.Find(ReferenceProperties.Key, "Set");
			SetsWithAttributes.Add(String.Set, String.Title);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ExcludeBrokenPropertiesSets(References, Value)
	
	IndexOf = References.Find(Value);
	While IndexOf <> Undefined Do
		References.Delete(IndexOf);
		IndexOf = References.Find(Value);
	EndDo;
	
EndProcedure

// Defines that a value type contains a type of additional property values.
Function ValueTypeContainsPropertyValues(ValueType) Export
	
	Return ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues"))
	    Or ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy"));
	
EndFunction

// Checks if it is possible to use string of unlimited length for the property.
Function UseUnlimitedString(PropertyValueType1, MultilineInputField) Export
	
	If PropertyValueType1.ContainsType(Type("String"))
	   And PropertyValueType1.Types().Count() = 1
	   And (PropertyValueType1.StringQualifiers.Length = 0
		   Or MultilineInputField > 1) Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

Function UseStringAsLink(PropertyValueType1, OutputAsHyperlink, MultilineInputField)
	TypesList = PropertyValueType1.Types();
	
	If Not UseUnlimitedString(PropertyValueType1, MultilineInputField)
		And TypesList.Count() = 1
		And TypesList[0] = Type("String")
		And OutputAsHyperlink Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

Function AddressAndPresentation(String) Export
	
	Result = New Structure;
	BoldBeginning = StrFind(String, "<a href = ");
	
	StringAfterOpeningTag = Mid(String, BoldBeginning + 9);
	EndTag1 = StrFind(StringAfterOpeningTag, ">");
	
	Ref = TrimAll(Left(StringAfterOpeningTag, EndTag1 - 2));
	If StrStartsWith(Ref, """") Then
		Ref = Mid(Ref, 2, StrLen(Ref) - 1);
	EndIf;
	If StrEndsWith(Ref, """") Then
		Ref = Mid(Ref, 1, StrLen(Ref) - 1);
	EndIf;
	
	StringAfterLink = Mid(StringAfterOpeningTag, EndTag1 + 1);
	BoldEnd = StrFind(StringAfterLink, "</a>");
	HyperlinkAnchorText = Left(StringAfterLink, BoldEnd - 1);
	Result.Insert("Presentation", HyperlinkAnchorText);
	Result.Insert("Ref", Ref);
	
	Return Result;
	
EndFunction

// PropertiesBeforeDeleteReferenceObject event handler.
// Searches for references to deleted objects in the additional attribute dependence table.
//
Procedure BeforeRemoveReferenceObject(Object, Cancel) Export
	If Object.DataExchange.Load = True
		Or Cancel Then
		Return;
	EndIf;
	
	If Not Common.SeparatedDataUsageAvailable() Then
		// Do not check in shared mode.
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
		"SELECT DISTINCT
		|	Dependencies.Ref AS Ref
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.AdditionalAttributesDependencies AS Dependencies
		|WHERE
		|	Dependencies.Value = &Value
		|
		|ORDER BY
		|	Ref";
	Query.SetParameter("Value", Object.Ref);
	Result = Query.Execute().Unload();
	
	For Each TableRow In Result Do
		Block = New DataLock;
		LockItem = Block.Add("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo");
		LockItem.SetValue("Ref", TableRow.Ref);
		Block.Lock();
		
		AttributeOfObject = TableRow.Ref.GetObject();// ChartOfCharacteristicTypesObject.AdditionalAttributesAndInfo
		FilterParameters = New Structure("Value", Object.Ref);
		FoundRows = AttributeOfObject.AdditionalAttributesDependencies.FindRows(FilterParameters);
		For Each Dependence In FoundRows Do
			AttributeOfObject.AdditionalAttributesDependencies.Delete(Dependence);
		EndDo;
		AttributeOfObject.Write();
	EndDo;
EndProcedure

// Checks for objects using the property.
//
// Parameters:
//  Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo
//
// Returns:
//  Boolean -  True if at least one object is found.
//
Function AdditionalPropertyUsed(Property) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("Property", Property);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AdditionalInfo AS AdditionalInfo
	|WHERE
	|	AdditionalInfo.Property = &Property";
	
	If Not Query.Execute().IsEmpty() Then
		Return True;
	EndIf;
	
	MetadataObjectsKinds = New Array;
	MetadataObjectsKinds.Add("ExchangePlans");
	MetadataObjectsKinds.Add("Catalogs");
	MetadataObjectsKinds.Add("Documents");
	MetadataObjectsKinds.Add("ChartsOfCharacteristicTypes");
	MetadataObjectsKinds.Add("ChartsOfAccounts");
	MetadataObjectsKinds.Add("ChartsOfCalculationTypes");
	MetadataObjectsKinds.Add("BusinessProcesses");
	MetadataObjectsKinds.Add("Tasks");
	
	ObjectTables1 = New Array;
	For Each MetadataObjectsKind In MetadataObjectsKinds Do
		For Each MetadataObject In Metadata[MetadataObjectsKind] Do
			
			If IsMetadataObjectWithProperties(MetadataObject, "AdditionalAttributes") Then
				ObjectTables1.Add(MetadataObject.FullName());
			EndIf;
			
		EndDo;
	EndDo;
	
	QueryText =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	TableName AS CurrentTable
	|WHERE
	|	CurrentTable.Property = &Property";
	
	For Each Table In ObjectTables1 Do
		Query.Text = StrReplace(QueryText, "TableName", Table + ".AdditionalAttributes");
		If Not Query.Execute().IsEmpty() Then // @skip-check query-in-loop. Query to multiple tables.
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Checks if the metadata object uses properties of a certain kind (except for additional information records).
// The check is intended to control reference integrity,
// that is why the embedding check is skipped.
//
Function IsMetadataObjectWithProperties(MetadataObject, PropertyKind) Export
	
	If MetadataObject = Metadata.Catalogs.AdditionalAttributesAndInfoSets Then
		Return False;
	EndIf;
	
	TabularSection = MetadataObject.TabularSections.Find(PropertyKind);
	If TabularSection = Undefined Then
		Return False;
	EndIf;
	
	Attribute = TabularSection.Attributes.Find("Property");
	If Attribute = Undefined Then
		Return False;
	EndIf;
	
	If Not Attribute.Type.ContainsType(Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo")) Then
		Return False;
	EndIf;
	
	Attribute = TabularSection.Attributes.Find("Value");
	If Attribute = Undefined Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Returns description of the predefined set that is received
// from the metadata object found by the predefined set description.
// 
// Parameters:
//  Set - CatalogRef.AdditionalAttributesAndInfoSets,
//        - String - a full name of the predefined item.
//
Function PredefinedSetDescription(Set) Export
	
	If TypeOf(Set) = Type("String") Then
		PredefinedItemName = Set;
	Else
		PredefinedItemName = Common.ObjectAttributeValue(Set, "PredefinedDataName");
	EndIf;
	
	Position = StrFind(PredefinedItemName, "_");
	FirstNamePart =  Left(PredefinedItemName, Position - 1);
	SecondNamePart = Right(PredefinedItemName, StrLen(PredefinedItemName) - Position);
	
	FullName = FirstNamePart + "." + SecondNamePart;
	
	MetadataObject = Common.MetadataObjectByFullName(FullName);
	If MetadataObject = Undefined Then
		If TypeOf(Set) = Type("String") Then
			Return "";
		Else
			Return String(Set);
		EndIf;
	EndIf;
	
	If ValueIsFilled(MetadataObject.ListPresentation) Then
		Description = MetadataObject.ListPresentation;
		
	ElsIf ValueIsFilled(MetadataObject.Synonym) Then
		Description = MetadataObject.Synonym;
	Else
		If TypeOf(Set) = Type("String") Then
			Description = "";
		Else
			Description = String(Set);
		EndIf;
	EndIf;
	
	Return Description;
	
EndFunction

// Updates content of the top group to use fields
// of the dynamic list and its settings (filters, …) upon customization.
//
// Parameters:
//  Group - CatalogRef.AdditionalAttributesAndInfoSets - an item with flag IsFolder = True.
//
Procedure CheckRefreshGroupPropertiesContent(Group) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("Group", Group);
	Query.Text =
	"SELECT DISTINCT
	|	AdditionalAttributes.Property AS Property,
	|	AdditionalAttributes.PredefinedSetName AS PredefinedSetName
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS AdditionalAttributes
	|WHERE
	|	AdditionalAttributes.Ref.Parent = &Group
	|
	|ORDER BY
	|	Property
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AdditionalInfo.Property AS Property,
	|	AdditionalInfo.PredefinedSetName AS PredefinedSetName
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo AS AdditionalInfo
	|WHERE
	|	AdditionalInfo.Ref.Parent = &Group
	|
	|ORDER BY
	|	Property";
	
	QueryResult = Query.ExecuteBatch();
	AdditionalGroupAttributes = QueryResult[0].Unload();
	AdditionalGroupInfo  = QueryResult[1].Unload();
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.AdditionalAttributesAndInfoSets");
	LockItem.SetValue("Ref", Group);
	Block.Lock();
	
	GroupObject = Group.GetObject();
	
	Refresh = False;
	
	If GroupObject.AdditionalAttributes.Count() <> AdditionalGroupAttributes.Count() Then
		Refresh = True;
	EndIf;
	
	If GroupObject.AdditionalInfo.Count() <> AdditionalGroupInfo.Count() Then
		Refresh = True;
	EndIf;
	
	If Not Refresh Then
		IndexOf = 0;
		For Each AdditionalAttribute In GroupObject.AdditionalAttributes Do
			If AdditionalAttribute.Property <> AdditionalGroupAttributes[IndexOf].Property Then
				Refresh = True;
			EndIf;
			IndexOf = IndexOf + 1;
		EndDo;
	EndIf;
	
	If Not Refresh Then
		IndexOf = 0;
		For Each AdditionalInfoItem In GroupObject.AdditionalInfo Do
			If AdditionalInfoItem.Property <> AdditionalGroupInfo[IndexOf].Property Then
				Refresh = True;
			EndIf;
			IndexOf = IndexOf + 1;
		EndDo;
	EndIf;
	
	If Not Refresh Then
		Return;
	EndIf;
	
	GroupObject.AdditionalAttributes.Load(AdditionalGroupAttributes);
	GroupObject.AdditionalInfo.Load(AdditionalGroupInfo);
	GroupObject.Write();
	
EndProcedure

// Returns enum values of the specified property.
//
// Parameters:
//  Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - a property for
//             which listed values are to be received.
// 
// Returns:
//  Array of CatalogRef - property values if any.
//
Function AdditionalPropertyValues(Property) Export
	
	ProcedureName = "PropertyManagerInternal.AdditionalPropertyValues";
	CommonClientServer.CheckParameter(ProcedureName, "Property", Property, 
		Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo"));
	
	PropertiesValues = PropertiesAdditionalValues(Property);
	Result       = PropertiesValues.UnloadColumn("Ref");
	
	Return Result;
	
EndFunction

// Returns a table with enumeration values of the given property.
//
// Parameters:
//  Property - Array of ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - properties for
//             which listed values are to be received.
//           - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo
// 
// Returns:
//  ValueTable:
//   * Ref - CatalogRef.ObjectPropertyValueHierarchy
//            - CatalogRef.ObjectsPropertiesValues
//   * Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo
//
Function PropertiesAdditionalValues(Property) Export
	
	Query = New Query;
	Query.Parameters.Insert("Property", Property);
	Query.Text =
		"SELECT
		|	ObjectPropertyValueHierarchy.Ref AS Ref,
		|	ObjectPropertyValueHierarchy.Owner AS Property
		|FROM
		|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
		|WHERE
		|	ObjectPropertyValueHierarchy.Owner IN (&Property)
		|
		|UNION ALL
		|
		|SELECT
		|	ObjectsPropertiesValues.Ref AS Ref,
		|	ObjectsPropertiesValues.Owner AS Property
		|FROM
		|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
		|WHERE
		|	ObjectsPropertiesValues.Owner IN (&Property)";
	
	Result = Query.Execute().Unload();
	
	Return Result;
	
EndFunction

Procedure CreatePredefinedPropertiesSets() Export
	
	PredefinedPropertiesSets = PropertyManagerCached.PredefinedPropertiesSets();
	PropertiesSetsDescriptions    = PropertyManagerCached.PropertiesSetsDescriptions();
	
	TempTable = New ValueTable;
	TempTable.Columns.Add("Name",          New TypeDescription("String",,,, New StringQualifiers(150)));
	TempTable.Columns.Add("Used", New TypeDescription("Boolean"));
	TempTable.Columns.Add("IsChildOne",  New TypeDescription("Boolean"));
	TempTable.Columns.Add("Description", New TypeDescription("String",,,, New StringQualifiers(100)));
	TempTable.Columns.Add("IsFolder",    New TypeDescription("Boolean"));
	TempTable.Columns.Add("Ref",       New TypeDescription("CatalogRef.AdditionalAttributesAndInfoSets"));
	For Each PredefinedSet In PredefinedPropertiesSets Do
		If TypeOf(PredefinedSet.Key) = Type("String") Then
			Continue;
		EndIf;
		
		String = TempTable.Add();
		FillPropertyValues(String, PredefinedSet.Value);
		If ValueIsFilled(PredefinedSet.Value.Parent) Then
			// If a subordinate set is changed, still select an upper level set for processing.
			String.Ref      = PredefinedSet.Value.Parent;
			String.IsChildOne = True;
		EndIf;
		
		If PredefinedSet.Value.Used = Undefined Then
			String.Used = True;
		EndIf;
	EndDo;
	
	MultipleLanguages = False;
	For Each Language In Metadata.Languages Do
		If Language.LanguageCode <> CurrentLanguage().LanguageCode Then
			MultipleLanguages = True;
			Break;
		EndIf
	EndDo;
	
	Query = New Query;
	Query.SetParameter("SetsDetails", TempTable);
	Query.SetParameter("MultipleLanguages", MultipleLanguages);
	Query.Text =
	"SELECT
	|	SetsDetails.Ref AS Ref,
	|	SetsDetails.Name AS Name,
	|	SetsDetails.Description AS Description,
	|	SetsDetails.IsFolder AS IsFolder,
	|	SetsDetails.IsChildOne AS IsChildOne,
	|	SetsDetails.Used AS Used
	|INTO SetsDetails
	|FROM
	|	&SetsDetails AS SetsDetails
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	SetsDetails.Ref AS Ref
	|FROM
	|	SetsDetails AS SetsDetails
	|WHERE
	|	NOT TRUE IN
	|				(SELECT TOP 1
	|					TRUE
	|				FROM
	|					Catalog.AdditionalAttributesAndInfoSets AS Sets
	|				WHERE
	|					SetsDetails.Name = Sets.PredefinedSetName
	|					AND SetsDetails.Used = Sets.Used
	|					AND SetsDetails.Description = Sets.Description
	|					AND NOT Sets.DeletionMark
	|					AND &MultipleLanguages = FALSE)
	|
	|UNION ALL
	|
	|SELECT
	|	SetsDetails.Ref
	|FROM
	|	SetsDetails AS SetsDetails
	|		LEFT JOIN Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS AdditionalAttributes
	|		ON SetsDetails.Ref = AdditionalAttributes.Ref
	|WHERE
	|	AdditionalAttributes.PredefinedSetName <> SetsDetails.Name
	|	AND NOT SetsDetails.IsChildOne
	|
	|UNION ALL
	|
	|SELECT
	|	SetsDetails.Ref
	|FROM
	|	SetsDetails AS SetsDetails
	|		LEFT JOIN Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo AS AdditionalInfo
	|		ON SetsDetails.Ref = AdditionalInfo.Ref
	|WHERE
	|	AdditionalInfo.PredefinedSetName <> SetsDetails.Name
	|	AND NOT SetsDetails.IsChildOne";
	SetsToProcess = Query.Execute().Unload();
	
	For Each TableRow In SetsToProcess Do
		SetProperties = PredefinedPropertiesSets.Get(TableRow.Ref); // See Catalogs.AdditionalAttributesAndInfoSets.SetProperties
		Object         = SetProperties.Ref.GetObject();
		CreatePropertiesSet(Object, SetProperties);
		
		For Each ChildSet In SetProperties.ChildSets Do
			SetProperties = ChildSet.Value; // See Catalogs.AdditionalAttributesAndInfoSets.SetProperties
			ChildObject = SetProperties.Ref.GetObject();
			CreatePropertiesSet(ChildObject, SetProperties, PropertiesSetsDescriptions, Object.Ref);
		EndDo;
	EndDo;
	
EndProcedure

// Parameters:
//  SetProperties See Catalogs.AdditionalAttributesAndInfoSets.SetProperties
//
Procedure CreatePropertiesSet(Object, SetProperties, PropertiesSetsDescriptions = Undefined, Parent = Undefined)
	
	Write = False;
	If Object = Undefined Then
		If SetProperties.IsFolder
			Or (SetProperties.ChildSets <> Undefined
				And SetProperties.ChildSets.Count() <> 0) Then
			Object = Catalogs.AdditionalAttributesAndInfoSets.CreateFolder();
		Else
			Object = Catalogs.AdditionalAttributesAndInfoSets.CreateItem();
		EndIf;
		If Parent <> Undefined Then
			Object.Parent = Parent;
		EndIf;
		Object.SetNewObjectRef(SetProperties.Ref);
		Object.PredefinedSetName = SetProperties.Name;
		Write = True;
	EndIf;
	
	If SetProperties.Used <> Undefined Then
		If Object.Used <> SetProperties.Used Then
			Object.Used = SetProperties.Used;
			Write = True;
		EndIf;
	Else
		If Object.Used <> True Then
			Object.Used = True;
			Write = True;
		EndIf;
	EndIf;
	
	If Object.Description <> SetProperties.Description Then
		Object.Description = SetProperties.Description;
		Write = True;
	EndIf;
	
	If Object.PredefinedSetName <> SetProperties.Name Then
		Object.PredefinedSetName = SetProperties.Name;
		Write = True;
	EndIf;
	
	If Parent = Undefined Then
		For Each TableRow In Object.AdditionalAttributes Do
			If TableRow.PredefinedSetName <> SetProperties.Name Then
				TableRow.PredefinedSetName = SetProperties.Name;
				Write = True;
			EndIf;
		EndDo;
	EndIf;
	
	If Parent = Undefined Then
		For Each TableRow In Object.AdditionalInfo Do
			If TableRow.PredefinedSetName <> SetProperties.Name Then
				TableRow.PredefinedSetName = SetProperties.Name;
				Write = True;
			EndIf;
		EndDo;
	EndIf;
	
	If Object.DeletionMark Then
		Object.DeletionMark = False;
		Write = True;
	EndIf;
	
	If PropertiesSetsDescriptions <> Undefined Then
		
		If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
			
			For Each Language In Metadata.Languages Do
				If Language.LanguageCode = CurrentLanguage().LanguageCode Then
					Continue;
				EndIf;
				
				LocalizedDescriptions = PropertiesSetsDescriptions[Language.LanguageCode];
				LocalizedDescription = LocalizedDescriptions[SetProperties.Name];
				LanguageSuffix = ModuleNationalLanguageSupportServer.LanguageSuffix(Language.LanguageCode);
				If ValueIsFilled(LanguageSuffix) 
					And ValueIsFilled(LocalizedDescription)
					And IsBlankString(Object["Description" + LanguageSuffix])
					And LocalizedDescription <> Object["Description" + LanguageSuffix] Then
						Object["Description" + LanguageSuffix] = LocalizedDescription;
						Write = True;
				EndIf;

				
			EndDo;
		EndIf;
		
	EndIf;
	
	If Write Then
		InfobaseUpdate.WriteObject(Object, False);
	EndIf;
	
EndProcedure

Function PropertiesSetsDescriptions() Export
	
	PredefinedData = PredefinedPropertiesSets();
	
	Result = New Map;
	For Each Language In Metadata.Languages Do
		Descriptions = New Map;
		PropertyManagerOverridable.OnGetPropertiesSetsDescriptions(Descriptions, Language.LanguageCode);
		
		ColumnName = "Description" + "_" + Language.LanguageCode;
		If PredefinedData.Columns.Find(ColumnName) <> Undefined Then
			For Each ElementData In PredefinedData Do
				Descriptions.Insert(ElementData.PredefinedSetName, ElementData[ColumnName]);
			EndDo;
		EndIf;
		Result[Language.LanguageCode] = Descriptions;
	EndDo;
	
	Return New FixedMap(Result);
EndFunction

Function PredefinedPropertiesSets() Export
	
	ObjectAttributesToLocalize = New Map();
	ObjectAttributesToLocalize.Insert("Description", True);
	
	PredefinedData = InfobaseUpdateInternal.PredefinedObjectData(Metadata.Catalogs.AdditionalAttributesAndInfoSets,
	Catalogs.AdditionalAttributesAndInfoSets, ObjectAttributesToLocalize);
	Return PredefinedData;

EndFunction

Procedure DeleteDisallowedCharacters(String) Export
	InvalidChars = """'`/\[]{}:;|-=?*<>,.()+#№@!%^&~«»";
	String = StrConcat(StrSplit(String, InvalidChars, True));
EndProcedure

Procedure ClearUnusedSettings() Export
	
	Filter = New Structure;
	Filter.Insert("SettingsKey", "FormAssignmentRuleKey");
	DeleteSettingFromStorage(Filter);
	
	Filter.SettingsKey = "FormWindowOptionsKey";
	DeleteSettingFromStorage(Filter);
	
EndProcedure

Procedure DeleteSettingFromStorage(Filter)
	
	SettingsSelection = SystemSettingsStorage.Select(Filter);
	While NextSettingsItem(SettingsSelection) Do
		Try
			ObjectKey = SettingsSelection.ObjectKey;
			If StrStartsWith(ObjectKey, "PropertySetsKey") Then
				Common.SystemSettingsStorageDelete(SettingsSelection.ObjectKey,
					SettingsSelection.SettingsKey,
					SettingsSelection.User);
			EndIf;
		Except
			ErrorInfo = ErrorInfo();
			ErrorText = NStr("en = 'An error occurred
				|when clearing settings in handler %1:
				|%2';");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
				"PropertyManagerInternal.ClearUnusedSettings",
				ErrorProcessing.DetailErrorDescription(ErrorInfo));
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Warning,,,
				ErrorText);
		EndTry;
	EndDo;
	
EndProcedure

Function NextSettingsItem(Selection)
	
	HasNextObject = False;
	Try
		HasNextObject = Selection.Next();
	Except
		ErrorInfo = ErrorInfo();
		ErrorText = NStr("en = 'An error occurred
			|when reading settings in handler %1:
			|%2';");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
			"PropertyManagerInternal.ClearUnusedSettings",
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		WriteLogEvent(
			InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Warning,,,
			ErrorText);
	EndTry;
	
	Return HasNextObject;
	
EndFunction

Function DescriptionAlreadyUsed(Property, PropertiesSet, Description) Export
	
	Query = New Query;
	Query.Text =
		"SELECT TOP 1
		|	SetProperties.Property AS Property,
		|	AttributesAndInfo.IsAdditionalInfo AS IsAdditionalInfo
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS SetProperties
		|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AttributesAndInfo
		|		ON (AttributesAndInfo.Ref = SetProperties.Property)
		|WHERE
		|	AttributesAndInfo.Title = &Description
		|	AND SetProperties.Ref = &PropertiesSet
		|	AND SetProperties.Property <> &Ref
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	SetProperties.Property AS Property,
		|	AttributesAndInfo.IsAdditionalInfo AS IsAdditionalInfo
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo AS SetProperties
		|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AttributesAndInfo
		|		ON (AttributesAndInfo.Ref = SetProperties.Property)
		|WHERE
		|	AttributesAndInfo.Title = &Description
		|	AND SetProperties.Ref = &PropertiesSet
		|	AND SetProperties.Property <> &Ref";
	
	Query.SetParameter("Ref",       Property);
	Query.SetParameter("PropertiesSet", PropertiesSet);
	Query.SetParameter("Description", Description);
	
	Selection = Query.Execute().Select();
	
	If Not Selection.Next() Then
		Return "";
	EndIf;
	
	If Selection.IsAdditionalInfo Then
		QueryText = NStr("en = 'The additional information record with description
		                          |""%1"" already exists.';");
	Else
		QueryText = NStr("en = 'The additional attribute with description
		                          |""%1"" already exists.';");
	EndIf;
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		QueryText + Chars.LF + Chars.LF
		                         + NStr("en = 'It is recommended that you enter another description,
		                         |otherwise, the application might not work properly.';"),
		Description);
	
	Return QueryText;
	
EndFunction

Function NameAlreadyUsed(Val Name, Val CurrentProperty) Export
	
	NewName = Name;
	DeleteDisallowedCharacters(NewName);
	If NewName <> Name
		Or TheNameStartsWithANumber(Name)
		Or StrSplit(NewName, " ", True).Count() > 1 Then
		
		QueryText = NStr("en = 'The name (the For developing purpose group) must be a single word that starts with a letter and can contain digits, letters, and underscores ( _ ).';");
		Return QueryText;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Properties.IsAdditionalInfo
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
	|WHERE
	|	Properties.Name = &Name
	|	AND Properties.Ref <> &Ref";
	
	Query.SetParameter("Ref", CurrentProperty);
	Query.SetParameter("Name",    Name);
	
	Selection = Query.Execute().Select();
	
	If Not Selection.Next() Then
		Return "";
	EndIf;
	
	If Selection.IsAdditionalInfo Then
		QueryText = NStr("en = 'The additional information record with name
		                          |""%1"" already exists.';");
	Else
		QueryText = NStr("en = 'The additional attribute with name
		                          |""%1"" already exists.';");
	EndIf;
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		QueryText + Chars.LF + Chars.LF
		                         + NStr("en = 'It is recommended that you enter another name,
		                         |otherwise, the application might not work properly.
		                         |
		                         |Do you want to enter a new name and proceed to saving?';"),
		Name);
	
	Return QueryText;
	
EndFunction

Function TheNameStartsWithANumber(AttributeName) Export
	FirstChar = Left(AttributeName, 1);
	If StrFind("0123456789", FirstChar) > 0 Then
		Return True;
	EndIf;
	
	Return False;
EndFunction

Function IDForFormulasAlreadyUsed(Val IDForFormulas, Val CurrentProperty) Export
	
	VerificationID = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.IDForFormulas(IDForFormulas);
	If Upper(IDForFormulas) <> Upper(VerificationID) Then
		QueryText = NStr("en = 'ID ""%1"" does not comply with variable naming rules.
		                          |An ID must not contain spaces and special characters.';");
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			QueryText,
			IDForFormulas);
		Return QueryText;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Properties.IsAdditionalInfo
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
	|WHERE
	|	Properties.IDForFormulas = &IDForFormulas
	|	AND Properties.Ref <> &Ref";
	
	Query.SetParameter("Ref", CurrentProperty);
	Query.SetParameter("IDForFormulas", IDForFormulas);
	
	BeginTransaction();
	Try
		Selection = Query.Execute().Select();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Not Selection.Next() Then
		Return "";
	EndIf;
	
	If Selection.IsAdditionalInfo Then
		QueryText = NStr("en = 'An additional information record with ID for formulas
		                          |""%1"" already exists.';");
	Else
		QueryText = NStr("en = 'An additional attribute with ID for formulas
		                          |""%1"" already exists.';");
	EndIf;
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		QueryText + Chars.LF + Chars.LF
		                         + NStr("en = 'It is recommended to use another ID for formulas.
		                         |Otherwise, the application might function incorrectly.';"),
		IDForFormulas);
	
	Return QueryText;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Returns the default owner property set.
//
// Parameters:
//  PropertiesOwner - a reference or property owner object.
//
// Returns:
//  CatalogRef.AdditionalAttributesAndInfoSets
//  
Function GetDefaultObjectPropertySet(PropertiesOwner)
	
	If Common.RefTypeValue(PropertiesOwner) Then
		Ref = PropertiesOwner;
	Else
		Ref = PropertiesOwner.Ref;
	EndIf;
	
	ObjectMetadata = Ref.Metadata();
	MetadataObjectName = ObjectMetadata.Name;
	
	MetadataObjectKind = Common.ObjectKindByRef(Ref);
	
	TagName = MetadataObjectKind + "_" + MetadataObjectName;
	MainSet = PropertyManager.PropertiesSetByName(TagName);
	If MainSet = Undefined Then
		MainSet = Catalogs.AdditionalAttributesAndInfoSets[TagName];
	EndIf;
	
	Return MainSet;
	
EndFunction

// Used upon infobase update.
Function HasMetadataObjectWithPropertiesPresentationChanges()
	
	SetPrivilegedMode(True);
	
	Catalogs.AdditionalAttributesAndInfoSets.RefreshPredefinedSetsDescriptionsContent();
	
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		"StandardSubsystems.Properties.AdditionalDataAndAttributePredefinedSets");
	
	If LastChanges = Undefined
	 Or LastChanges.Count() > 0 Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function NeedToTransferValueFromRef(Value, Presentation)
	
	If ValueIsFilled(Presentation) And Left(Value, 7) = "<a href" Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function ValueWithoutRef(Value, Presentation)
	
	If Not ValueIsFilled(Presentation) Or Left(Value, 7) <> "<a href" Then
		Return Value;
	EndIf;
	
	RefStart = "<a href = """;
	RefFinish = StringFunctionsClientServer.SubstituteParametersToString(""">%1</a>", Presentation);
	
	Result = StrReplace(Value, RefStart, "");
	Result = StrReplace(Result, RefFinish, "");
	Return Result;
	
EndFunction

// Used in the list form of the AdditionalAttributesAndInfoSets catalog
// and of the AdditionalAttributesAndInfo chart of characteristic types.
//
Procedure UpdateCurrentSetPropertiesList(Form, Set, PropertyKind, CurrentEnable = Undefined) Export
	
	Query = New Query;
	Query.SetParameter("Set", Set);
	Query.SetParameter("IsMainLanguage", Common.IsMainLanguage());
	Query.SetParameter("LanguageCode", CurrentLanguage().LanguageCode);
	Query.SetParameter("PropertyKind", PropertyKind);
	
	If Not Form.ShowUnusedAttributes Then
		Query.Text =
		"SELECT
		|	SetsProperties.LineNumber,
		|	SetsProperties.Property,
		|	SetsProperties.DeletionMark,
		|	Properties.Title AS Title,
		|	Properties.AdditionalValuesOwner,
		|	Properties.RequiredToFill,
		|	Properties.ValueType AS ValueType,
		|	TRUE AS Common,
		|	CASE
		|		WHEN Properties.DeletionMark = TRUE
		|			THEN 12
		|		WHEN Properties.PropertyKind = VALUE(Enum.PropertiesKinds.Labels)
		|			THEN Properties.PropertiesColor.Order + 1
		|		ELSE 11
		|	END AS PictureNumber,
		|	Properties.ToolTip AS ToolTip,
		|	Properties.ValueFormTitle AS ValueFormTitle,
		|	Properties.ValueChoiceFormTitle AS ValueChoiceFormTitle
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS SetsProperties
		|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
		|		ON SetsProperties.Property = Properties.Ref
		|WHERE
		|	SetsProperties.Property.IsAdditionalInfo = &IsAdditionalInfoSets
		|	AND SetsProperties.Property.PropertyKind IN (VALUE(Enum.PropertiesKinds.EmptyRef), &PropertyKind)
		|	AND SetsProperties.Ref = &Set
		|
		|ORDER BY
		|	SetsProperties.LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Sets.DataVersion AS DataVersion
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets AS Sets
		|WHERE
		|	Sets.Ref = &Set";
	Else
		Query.Text =
		"SELECT
		|	Properties.Ref AS Property,
		|	Properties.DeletionMark AS DeletionMark,
		|	Properties.Title AS Title,
		|	Properties.AdditionalValuesOwner,
		|	Properties.ValueType AS ValueType,
		|	TRUE AS Common,
		|	CASE
		|		WHEN Properties.DeletionMark = TRUE
		|			THEN 12
		|		WHEN Properties.PropertyKind = VALUE(Enum.PropertiesKinds.Labels)
		|			THEN Properties.PropertiesColor.Order + 1
		|		ELSE 11
		|	END AS PictureNumber,
		|	Properties.ToolTip AS ToolTip,
		|	Properties.ValueFormTitle AS ValueFormTitle,
		|	Properties.ValueChoiceFormTitle AS ValueChoiceFormTitle
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
		|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Presentations AS PresentationProperties
		|		ON Properties.Ref = PresentationProperties.Ref
		|		AND PresentationProperties.LanguageCode = &LanguageCode
		|		LEFT JOIN Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS SetComposition
		|		ON Properties.Ref = SetComposition.Property
		|WHERE
		|	Properties.IsAdditionalInfo = &IsAdditionalInfoSets
		|	AND Properties.PropertyKind IN (VALUE(Enum.PropertiesKinds.EmptyRef), &PropertyKind)
		|	AND SetComposition.Property IS NULL
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	""DataVersion"" AS DataVersion";
	EndIf;
	
	If PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
		Query.Text = StrReplace(
			Query.Text,
			"Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes",
			"Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo");
		IsAdditionalInfoSets = True;
	ElsIf PropertyKind = Enums.PropertiesKinds.Labels Then
		Query.Text = StrReplace(
			Query.Text,
			"IN (VALUE(Enum.PropertiesKinds.EmptyRef), &PropertyKind)",
			"= VALUE(Enum.PropertiesKinds.Labels)");
		IsAdditionalInfoSets = False;
	Else
		IsAdditionalInfoSets = False;
	EndIf;
	Query.SetParameter("IsAdditionalInfoSets", IsAdditionalInfoSets);
	
	CurrentLanguageSuffix = Common.CurrentUserLanguageSuffix();
	If CurrentLanguageSuffix = Undefined Then
		
		If Not Form.ShowUnusedAttributes Then
			Position = StrFind(Query.Text, "WHERE");
			Query.Text = Left(Query.Text, Position - 1 ) 
				+ " LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Presentations AS PresentationProperties
				 |		ON Properties.Ref = PresentationProperties.Ref
				 |			AND PresentationProperties.LanguageCode = &LanguageCode" + Mid(Query.Text, Position -1);
		EndIf;
		
		Query.Text = StrReplace(Query.Text, "Properties.Title AS Title", 
			"CAST(ISNULL(PresentationProperties.Title, Properties.Title) AS STRING(150)) AS Title");
		Query.Text = StrReplace(Query.Text, "Properties.ToolTip AS ToolTip", 
			"CAST(ISNULL(PresentationProperties.ToolTip, Properties.ToolTip) AS STRING(150)) AS ToolTip");
		Query.Text = StrReplace(Query.Text, "Properties.ValueFormTitle AS ValueFormTitle", 
			"CAST(ISNULL(PresentationProperties.ValueFormTitle, Properties.ValueFormTitle) AS STRING(150)) AS ValueFormTitle");
		Query.Text = StrReplace(Query.Text, "Properties.ValueChoiceFormTitle AS ValueChoiceFormTitle", 
			"CAST(ISNULL(PresentationProperties.ValueChoiceFormTitle, Properties.ValueChoiceFormTitle) AS STRING(150)) AS ValueChoiceFormTitle");
	Else
	
		If ValueIsFilled(CurrentLanguageSuffix) And Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
			ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(Query.Text, "Properties.Title AS Title");
			If Form.ShowUnusedAttributes Then
				ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(Query.Text, "Properties.ToolTip AS ToolTip");
				ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(Query.Text, "Properties.ValueFormTitle AS ValueFormTitle");
				ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(Query.Text, "Properties.ValueChoiceFormTitle AS ValueChoiceFormTitle");
			EndIf;
		EndIf;
		
	EndIf;
	
	BeginTransaction();
	Try
		QueryResults = Query.ExecuteBatch();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Form.Items.Properties.CurrentRow = Undefined Then
		String = Undefined;
	Else
		String = Form.Properties.FindByID(Form.Items.Properties.CurrentRow);
	EndIf;
	CurrentProperty = ?(String = Undefined, Undefined, String.Property);
	
	Form.Properties.Clear();
	
	If QueryResults[1].IsEmpty() Then
		CurrentEnable = False;
		Return;
	EndIf;
	
	Form.CurrentSetDataVersion = QueryResults[1].Unload()[0].DataVersion;
	
	AttributeWithPropertiesValues = New Array;
	Selection = QueryResults[0].Select();
	While Selection.Next() Do
		If Selection.ValueType <> NULL
			And ValueTypeContainsPropertyValues(Selection.ValueType) Then
			If ValueIsFilled(Selection.AdditionalValuesOwner) Then
				AttributeWithPropertiesValues.Add(Selection.AdditionalValuesOwner);
			Else
				AttributeWithPropertiesValues.Add(Selection.Property);
			EndIf;
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("Owner", AttributeWithPropertiesValues);
	Query.Text =
		"SELECT
		|	PRESENTATION(ObjectsPropertiesValues.Ref) AS Description,
		|	ObjectsPropertiesValues.Owner AS Owner
		|FROM
		|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
		|WHERE
		|	ObjectsPropertiesValues.Owner IN(&Owner)
		|	AND NOT ObjectsPropertiesValues.IsFolder
		|	AND NOT ObjectsPropertiesValues.DeletionMark
		|
		|UNION ALL
		|
		|SELECT
		|	PRESENTATION(ObjectPropertyValueHierarchy.Ref) AS Description,
		|	ObjectPropertyValueHierarchy.Owner
		|FROM
		|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
		|WHERE
		|	ObjectPropertyValueHierarchy.Owner IN(&Owner)
		|	AND NOT ObjectPropertyValueHierarchy.DeletionMark
		|
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	ObjectsPropertiesValues.Owner AS Owner
		|FROM
		|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
		|WHERE
		|	ObjectsPropertiesValues.Owner IN(&Owner)
		|	AND NOT ObjectsPropertiesValues.IsFolder
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	ObjectPropertyValueHierarchy.Owner AS Owner
		|FROM
		|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
		|WHERE
		|	ObjectPropertyValueHierarchy.Owner IN(&Owner)";
	FetchingValues = Query.ExecuteBatch();
	
	Result = FetchingValues[0].Unload();
	MapOfAttributesValues = New Map;
	For Each TableRow In Result Do
		CurrentListOfVals = MapOfAttributesValues[TableRow.Owner];
		If CurrentListOfVals = Undefined Then
			IndexOf = 1;
			MapOfAttributesValues.Insert(TableRow.Owner, TableRow.Description);
		Else
			IndexOf = IndexOf + 1;
			If IndexOf > 4 Then
				Continue;
			ElsIf IndexOf = 4 Then
				CurrentListOfVals = CurrentListOfVals + ",...";
			Else
				CurrentListOfVals = CurrentListOfVals + ", " + TableRow.Description;
			EndIf;
			MapOfAttributesValues.Insert(TableRow.Owner, CurrentListOfVals);
		EndIf;
	EndDo;
	
	Result = FetchingValues[1].Unload();
	AttributesWithValues = New Map;
	For Each TableRow In Result Do
		AttributesWithValues.Insert(TableRow.Owner, True);
	EndDo;
	
	Selection = QueryResults[0].Select();
	While Selection.Next() Do
		
		NewRow = Form.Properties.Add();
		FillPropertyValues(NewRow, Selection);
		
		NewRow.CommonValues = ValueIsFilled(Selection.AdditionalValuesOwner);
		
		If Selection.ValueType <> NULL
		   And ValueTypeContainsPropertyValues(Selection.ValueType) Then
			
			NewRow.ValueType = String(New TypeDescription(
				Selection.ValueType,
				,
				"CatalogRef.ObjectPropertyValueHierarchy,
				|CatalogRef.ObjectsPropertiesValues"));
			
			If ValueIsFilled(Selection.AdditionalValuesOwner) Then
				TopValues = MapOfAttributesValues[Selection.AdditionalValuesOwner];
				HasVal   = AttributesWithValues[Selection.AdditionalValuesOwner];
			Else
				TopValues = MapOfAttributesValues[Selection.Property];
				HasVal   = AttributesWithValues[Selection.Property];
			EndIf;
			
			If TopValues = Undefined Then 
				If HasVal = True Then
					ValuesPresentation = NStr("en = 'Values are marked for deletion';");
				Else
					ValuesPresentation = NStr("en = 'Values are not entered yet';");
				EndIf;
			Else
				ValuesPresentation = TopValues;
			EndIf;
			ValuesPresentation = "<" + ValuesPresentation + ">";
			If ValueIsFilled(NewRow.ValueType) Then
				ValuesPresentation = ValuesPresentation + ", ";
			EndIf;
			NewRow.ValueType = ValuesPresentation + NewRow.ValueType;
		EndIf;
		
		If Selection.Property = CurrentProperty Then
			Form.Items.Properties.CurrentRow =
				Form.Properties[Form.Properties.Count()-1].GetID();
		EndIf;
	EndDo
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Fills in separated data handler that depends on shared data change.
//
// Parameters:
//   Parameters - Structure - parameters of the update handlers:
//     * SeparatedHandlers - See InfobaseUpdate.NewUpdateHandlerTable
// 
Procedure FillSeparatedDataHandlers(Parameters = Undefined) Export
	
	If Parameters <> Undefined And HasMetadataObjectWithPropertiesPresentationChanges() Then
		Handlers = Parameters.SeparatedHandlers;
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.ExecutionMode = "Seamless";
		Handler.Procedure = "PropertyManagerInternal.CreatePredefinedPropertiesSets";
	EndIf;
	
EndProcedure

// Sets the Used property value to True.
//
Procedure SetUsageFlagValue() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AdditionalAttributesAndInfoSets.Ref
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets AS AdditionalAttributesAndInfoSets
	|WHERE
	|	NOT AdditionalAttributesAndInfoSets.Used";
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add("Catalog.AdditionalAttributesAndInfoSets");
			LockItem.SetValue("Ref", Selection.Ref);
			Block.Lock();
		
			SetObject = Selection.Ref.GetObject();
			SetObject.Used = True;
			InfobaseUpdate.WriteData(SetObject);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure MoveSetting(Setting, AssignmentKey, SetName, OldSetUUID = Undefined) Export
	
	If StrFind(Setting.ObjectKey, AssignmentKey) = 0 Then
		Return;
	EndIf;
	
	NewSet = PropertyManager.PropertiesSetByName(SetName);
	If TypeOf(NewSet) <> Type("CatalogRef.AdditionalAttributesAndInfoSets") Then
		Return;
	EndIf;
	
	IDOfNewSet = NewSet.UUID();
	Checksum = Common.CheckSumString(StrReplace(IDOfNewSet, "-", ""));
	NewAssignmentKey  = "PropertySetsKey" + Checksum;
	
	SettingValue = Common.SystemSettingsStorageLoad(Setting.ObjectKey,
		Setting.SettingsKey, , , Setting.User);
	
	If OldSetUUID <> Undefined Then
		OldSetID = StrReplace(Upper(OldSetUUID), "-", "x");
		NewSetID  = StrReplace(Upper(IDOfNewSet), "-", "x");
		SettingValAsString = ValueToStringInternal(SettingValue);
		SettingValAsString = StrReplace(SettingValAsString, OldSetID, NewSetID);
		SettingValue = ValueFromStringInternal(SettingValAsString);
	EndIf;
	
	NewObjectKey = StrReplace(Setting.ObjectKey, AssignmentKey, NewAssignmentKey);
	Common.SystemSettingsStorageSave(NewObjectKey, Setting.SettingsKey,
		SettingValue, , Setting.User);
	
EndProcedure

// Parameters:
//  SettingsManager - StandardSettingsStorageManager
//
Function ReadSettingsFromStorage(SettingsManager) Export
	
	Settings = New ValueTable;
	Settings.Columns.Add("ObjectKey");
	Settings.Columns.Add("SettingsKey");
	Settings.Columns.Add("User");
	
	SettingsSelection = SettingsManager.Select();
	While NextSettingsItem(SettingsSelection) Do
		
		If StrFind(SettingsSelection.ObjectKey, "PropertySetsKey") = 0 Then
			Continue;
		EndIf;
		
		NewRow = Settings.Add();
		NewRow.ObjectKey = SettingsSelection.ObjectKey;
		NewRow.SettingsKey = SettingsSelection.SettingsKey;
		NewRow.User = SettingsSelection.User;
		
	EndDo;
	
	Return Settings;
	
EndFunction

#EndRegion
