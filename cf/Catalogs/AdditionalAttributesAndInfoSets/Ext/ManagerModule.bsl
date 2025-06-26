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
	
	Return AttributesToEdit;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	Fields.Add("PredefinedSetName");
	Fields.Add("Description");
	Fields.Add("Ref");
	Fields.Add("Parent");
	
	StandardProcessing = False;
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		If Common.IsMainLanguage() Then
			Return;
		EndIf;
#Else
		If StrCompare(StandardSubsystemsClient.ClientParameter("DefaultLanguageCode"), CommonClient.DefaultLanguageCode()) = 0 Then
			Return;
		EndIf;
#EndIf
	
	If ValueIsFilled(Data.Parent) Then
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
		Return;
	EndIf;
	
	If ValueIsFilled(Data.PredefinedSetName) Then
		SetName = Data.PredefinedSetName;
	Else
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		SetName = Common.ObjectAttributeValue(Data.Ref, "PredefinedDataName");
#Else
		SetName = "";
#EndIf
	EndIf;
	Presentation = UpperLevelSetPresentation(SetName, Data);
	
	StandardProcessing = False;
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Updates descriptions of predefined sets in
// parameters of additional attributes and info.
//
// Parameters:
//  HasChanges - Boolean - a return value. If recorded,
//                  True is set, otherwise, it does not change.
//
Procedure RefreshPredefinedSetsDescriptionsContent(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	PredefinedSets = PredefinedPropertiesSets();
	
	BeginTransaction();
	Try
		HasCurrentChanges = False;
		PreviousValue2 = Undefined;
		
		StandardSubsystemsServer.UpdateApplicationParameter(
			"StandardSubsystems.Properties.AdditionalDataAndAttributePredefinedSets",
			PredefinedSets, HasCurrentChanges, PreviousValue2);
		
		StandardSubsystemsServer.AddApplicationParameterChanges(
			"StandardSubsystems.Properties.AdditionalDataAndAttributePredefinedSets",
			?(HasCurrentChanges,
			  New FixedStructure("HasChanges", True),
			  New FixedStructure()) );
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If HasCurrentChanges Then
		HasChanges = True;
	EndIf;
	
EndProcedure

Procedure ProcessPropertiesSetsForMigrationToNewVersion(Parameters) Export
	
	PredefinedPropertiesSets = PropertyManagerCached.PredefinedPropertiesSets();
	ObjectsWithIssuesCount = 0;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Sets.Ref AS Ref,
		|	Sets.PredefinedDataName AS PredefinedDataName,
		|	Sets.AdditionalAttributes.(
		|		Property AS Property
		|	) AS AdditionalAttributes,
		|	Sets.AdditionalInfo.(
		|		Property AS Property
		|	) AS AdditionalInfo,
		|	Sets.Parent AS Parent,
		|	Sets.IsFolder AS IsFolder
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets AS Sets
		|WHERE
		|	Sets.Predefined = TRUE";
	Result = Query.Execute().Unload();
	
	For Each SetToUpdate In Result Do
		
		BeginTransaction();
		Try
			If Not ValueIsFilled(SetToUpdate.PredefinedDataName) Then
				RollbackTransaction();
				Continue;
			EndIf;
			If Not StrStartsWith(SetToUpdate.PredefinedDataName, "Delete") Then
				RollbackTransaction();
				Continue;
			EndIf;
			
			PrefixLength = StrLen("Delete");
			SetName = Mid(SetToUpdate.PredefinedDataName, PrefixLength + 1, StrLen(SetToUpdate.PredefinedDataName) - PrefixLength);
			NewSetDetails = PredefinedPropertiesSets.Get(SetName); // See Catalogs.AdditionalAttributesAndInfoSets.SetProperties
			If NewSetDetails = Undefined Then
				RollbackTransaction();
				Continue;
			EndIf;
			NewSet = NewSetDetails.Ref;
			
			Block = New DataLock;
			LockItem = Block.Add("Catalog.AdditionalAttributesAndInfoSets");
			LockItem.SetValue("Ref", NewSet);
			Block.Lock();
			
			// Populate a new set.
			NewSetObject = NewSet.GetObject();
			If SetToUpdate.IsFolder <> NewSetObject.IsFolder Then
				RollbackTransaction();
				Continue;
			EndIf;
			For Each StringAttribute In SetToUpdate.AdditionalAttributes Do
				If Not ValueIsFilled(StringAttribute.Property) Then
					Continue;
				EndIf;
				NewStringAttributes = NewSetObject.AdditionalAttributes.Add();
				FillPropertyValues(NewStringAttributes, StringAttribute);
				NewStringAttributes.PredefinedSetName = NewSetObject.PredefinedSetName;
				
				// Update the property set depending on an additional attribute.
				Property = NewStringAttributes.Property;
				Block = New DataLock;
				LockItem = Block.Add("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo");
				LockItem.SetValue("Ref", Property);
				Block.Lock();
				
				ObjectProperty = Property.GetObject();
				If ObjectProperty = Undefined Then
					Continue;
				EndIf;
				
				If ObjectProperty.PropertiesSet = SetToUpdate.Ref Then
					ObjectProperty.PropertiesSet = NewSet;
				EndIf;
				
				For Each Dependence In ObjectProperty.AdditionalAttributesDependencies Do
					If Dependence.PropertiesSet = SetToUpdate.Ref Then
						Dependence.PropertiesSet = NewSet;
					EndIf;
				EndDo;
				InfobaseUpdate.WriteObject(ObjectProperty);
			EndDo;
			For Each StringInfo In SetToUpdate.AdditionalInfo Do
				NewStringInfo = NewSetObject.AdditionalInfo.Add();
				FillPropertyValues(NewStringInfo, StringInfo);
				NewStringInfo.PredefinedSetName = NewSetObject.PredefinedSetName;
			EndDo;
			
			If Not SetToUpdate.IsFolder Then
				AdditionalAttributesTable = NewSetObject.AdditionalAttributes.Unload();
				AdditionalAttributes = PropertyManager.PropertiesByAdditionalAttributesKind(
					AdditionalAttributesTable, Enums.PropertiesKinds.AdditionalAttributes);
				Labels = PropertyManager.PropertiesByAdditionalAttributesKind(
					AdditionalAttributesTable,Enums.PropertiesKinds.Labels);
				AttributesCount = AdditionalAttributes.Count();
				LabelCount      = Labels.Count();
				InfoCount   = NewSetObject.AdditionalInfo.FindRows(
					New Structure("DeletionMark", False)).Count();
				
				NewSetObject.AttributesCount = Format(AttributesCount, "NG=");
				NewSetObject.InfoCount   = Format(InfoCount, "NG=");
				NewSetObject.LabelCount      = Format(LabelCount, "NG=");
			EndIf;
			
			InfobaseUpdate.WriteObject(NewSetObject);
			
			// Clean up the old set.
			ObsoleteSetObject = SetToUpdate.Ref.GetObject();
			ObsoleteSetObject.AdditionalAttributes.Clear();
			ObsoleteSetObject.AdditionalInfo.Clear();
			ObsoleteSetObject.Used = False;
			
			InfobaseUpdate.WriteObject(ObsoleteSetObject);
			
			If SetToUpdate.IsFolder Then
				Query = New Query;
				Query.SetParameter("Parent", SetToUpdate.Ref);
				Query.Text = 
					"SELECT
					|	AdditionalAttributesAndInfoSets.Ref AS Ref
					|FROM
					|	Catalog.AdditionalAttributesAndInfoSets AS AdditionalAttributesAndInfoSets
					|WHERE
					|	AdditionalAttributesAndInfoSets.Parent = &Parent
					|	AND AdditionalAttributesAndInfoSets.Predefined = FALSE";
				SetsToTransfer = Query.Execute().Unload(); // @skip-check query-in-loop - Batch-wise data processing.
				For Each String In SetsToTransfer Do
					SetObject = String.Ref.GetObject();
					SetObject.Parent = NewSet;
					InfobaseUpdate.WriteObject(SetObject);
				EndDo;
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process the ""%1"" property set. Reason:
					|%2';"), 
					SetToUpdate.Ref, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Metadata.Catalogs.AdditionalAttributesAndInfoSets, SetToUpdate.Ref, MessageText);
		EndTry;
		
	EndDo;
	
	If ObjectsWithIssuesCount <> 0 Then
		MessageText = NStr("en = 'Procedure %1 was completed with an error. Some property sets were not updated.';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, "ProcessPropertiesSetsForMigrationToNewVersion");
		Raise MessageText;
	EndIf;
	
	Parameters.ProcessingCompleted = True;
	
EndProcedure

// Initial population.

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling
// 
// Parameters:
//  Settings - See InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.Settings
//
Procedure OnSetUpInitialItemsFilling(Settings) Export
	
	Settings.OnInitialItemFilling = False;
	
	PropertyManagerOverridable.OnSetUpInitialItemsFilling(Settings);
	
	Settings.KeyAttributeName          = "Ref";
	
EndProcedure

// See also InfobaseUpdateOverridable.OnInitialItemsFilling
// 
// Parameters:
//   LanguagesCodes - See InfobaseUpdateOverridable.OnInitialItemsFilling.LanguagesCodes
//   Items - See InfobaseUpdateOverridable.OnInitialItemsFilling.Items
//   TabularSections - See InfobaseUpdateOverridable.OnInitialItemsFilling.TabularSections
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items, TabularSections) Export
	
	PropertyManagerOverridable.OnInitialItemsFilling(LanguagesCodes, Items, TabularSections);
	
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
	
	PropertyManagerOverridable.OnInitialItemFilling(Object, Data, AdditionalParameters);
	
EndProcedure

//



#EndRegion

#EndIf

#Region Private

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Function PredefinedPropertiesSets() Export
	
	SetsTree = New ValueTree;
	SetsTree.Columns.Add("Name");
	SetsTree.Columns.Add("IsFolder", New TypeDescription("Boolean"));
	SetsTree.Columns.Add("Used");
	SetsTree.Columns.Add("Id");
	SSLSubsystemsIntegration.OnGetPredefinedPropertiesSets(SetsTree);
	PropertyManagerOverridable.OnGetPredefinedPropertiesSets(SetsTree);
	
	PropertiesSetsDescriptions = PropertyManagerInternal.PropertiesSetsDescriptions();
	Descriptions = PropertiesSetsDescriptions[CurrentLanguage().LanguageCode];
	
	PropertiesSets = New Map;
	For Each Set In SetsTree.Rows Do
		SetProperties = SetProperties(PropertiesSets, Set);
		For Each ChildSet In Set.Rows Do
			ChildSetProperties = SetProperties(PropertiesSets, ChildSet, SetProperties.Ref, Descriptions);
			SetProperties.ChildSets.Insert(ChildSet.Name, ChildSetProperties);
		EndDo;
		SetProperties.ChildSets = New FixedMap(SetProperties.ChildSets);
		PropertiesSets[SetProperties.Name] = New FixedStructure(PropertiesSets[SetProperties.Name]);
		PropertiesSets[SetProperties.Ref] = New FixedStructure(PropertiesSets[SetProperties.Ref]);
	EndDo;
	
	PredefinedData = PropertyManagerInternal.PredefinedPropertiesSets();
	
	NameInUserLanguage = "Description" + "_" + CurrentLanguage().LanguageCode;
	HaveLanguageColumn = PredefinedData.Columns.Find(NameInUserLanguage) <> Undefined;
	
	For Each Set In PredefinedData Do
		
		If HaveLanguageColumn Then
			Description = ?(HaveLanguageColumn, Set[NameInUserLanguage], Set["Description"]);
		EndIf;
		
		If ValueIsFilled(Set.Parent) Then
			Parent = ReferenceToParent(Set.Parent);
			
			SetProperties = PropertiesSets.Get(Parent);
			ChildSetProperties = InitialFillSetProperties(PropertiesSets, Set, Parent, Description);
			SetProperties.ChildSets.Insert(Set.PredefinedSetName, ChildSetProperties);
			
		Else
			SetProperties = InitialFillSetProperties(PropertiesSets, Set, Set.Parent, Description);
		EndIf;
		
	EndDo;
	
	Return New FixedMap(PropertiesSets);
	
EndFunction

// For internal use only.
// 
// Parameters:
//  PropertiesSets - Map of KeyAndValue:
//     * Key - String, CatalogRef.AdditionalAttributesAndInfoSets
//     * Value - See New_SetProperties
//  Set - ValueTreeRow:
//     * Name           - String
//     * IsFolder     - Boolean
//     * Used  - Boolean
//     * Id - UUID
// 
// Returns:
//  Structure:
//     * Name            - String
//     * IsFolder      - Boolean
//     * Used   - Boolean
//     * Ref         - CatalogRef.AdditionalAttributesAndInfoSets
//     * Parent       - CatalogRef.AdditionalAttributesAndInfoSets
//     * ChildSets - Map of KeyAndValue:
//        ** Key - String
//        ** Value - See SetProperties
//     * Description   - String
//
Function SetProperties(PropertiesSets, Set, Parent = Undefined, Descriptions = Undefined) Export
	
	ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Error in procedure %1 of common module %2.';"), 
		"WhenCreatingPredefinedPropertySets", "PropertyManagerOverridable")
		+ Chars.LF + Chars.LF;
	
	If Not ValueIsFilled(Set.Name) Then
		Raise ErrorTitle + NStr("en = 'The property set name is required.';");
	EndIf;
	
	If PropertiesSets.Get(Set.Name) <> Undefined Then
		Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The property set name ""%1"" is already defined.';"),
			Set.Name);
	EndIf;
	
	If Not ValueIsFilled(Set.Id) Then
		Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The ID of the ""%1"" property set is required.';"),
			Set.Name);
	EndIf;
	
	If Not Common.SeparatedDataUsageAvailable() Then
		SetRef = Set.Id;
	Else
		SetRef = GetRef(Set.Id);
	EndIf;
	
	If PropertiesSets.Get(SetRef) <> Undefined Then
		SetProperties = PropertiesSets.Get(SetRef); // See New_SetProperties
		Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The ID %1 of the
			           |""%2"" property set is already used for the ""%3"" property set.';"),
			Set.Id, Set.Name, SetProperties.Name);
	EndIf;
	
	SetProperties = New_SetProperties();
	SetProperties.Name            = Set.Name;
	SetProperties.IsFolder      = Set.IsFolder;
	SetProperties.Used   = Set.Used;
	SetProperties.Ref         = SetRef;
	SetProperties.Parent       = Parent;
	SetProperties.ChildSets = ?(Parent = Undefined, New Map, Undefined);
	
	If Descriptions = Undefined Then
		SetProperties.Description = UpperLevelSetPresentation(Set.Name);
	Else
		SetProperties.Description = Descriptions[Set.Name];
	EndIf;
	
	If Parent <> Undefined Then
		SetProperties = New FixedStructure(SetProperties);
	EndIf;
	PropertiesSets.Insert(SetProperties.Name,    SetProperties);
	PropertiesSets.Insert(SetProperties.Ref, SetProperties);
	
	Return SetProperties;
	
EndFunction

// For internal use only.
// 
// Returns:
//  Structure:
//     * Name            - String
//     * IsFolder      - Boolean
//     * Used   - Boolean
//     * Ref         - CatalogRef.AdditionalAttributesAndInfoSets
//     * Parent       - CatalogRef.AdditionalAttributesAndInfoSets
//     * ChildSets - Map of KeyAndValue:
//        ** Key - String
//        ** Value - See SetProperties
//     * Description   - String
//
Function InitialFillSetProperties(PropertiesSets, Set, Parent = Undefined, Description = Undefined)
	
	ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Error in procedure %1 of common module %2.';")
		+ Chars.LF + Chars.LF, "OnInitialItemsFilling", "PropertyManagerOverridable");
	
	If Not ValueIsFilled(Set.PredefinedSetName) Then
		Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 of property set is required.';"), "PredefinedSetName");
	EndIf;
	
	If PropertiesSets.Get(Set.PredefinedSetName) <> Undefined Then
		Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 of property set ""%2"" is already defined.';"), 
			"PredefinedSetName", Set.PredefinedSetName);
	EndIf;
	
	If Not ValueIsFilled(Set.Ref) Then
		Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Property set ""%1"" requires a reference.';"),
			Set.PredefinedSetName);
	EndIf;
	
	SetRef = Set.Ref;
	
	If PropertiesSets.Get(SetRef) <> Undefined Then
		SetProperties = PropertiesSets.Get(SetRef);
		Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Reference ""%1"" specified in property set
			           |""%2"" is already used in set ""%3"".';"),
			Set.Ref, Set.PredefinedSetName, SetProperties.PredefinedSetName);
	EndIf;
	
	Parent = ReferenceToParent(Parent);
	
	SetProperties = New_SetProperties();
	SetProperties.Name = Set.PredefinedSetName;
	SetProperties.IsFolder = Set.IsFolder;
	SetProperties.Used = Set.Used;
	SetProperties.Ref = SetRef;
	SetProperties.Parent = Parent;
	SetProperties.ChildSets = ?(Parent = Undefined, New Map, Undefined);

	If ValueIsFilled(Description) Then
		SetProperties.Insert("Description", Description);
	Else
		SetProperties.Insert("Description", Set["Description"]); 
	EndIf;
	
	SetProperties = New FixedStructure(SetProperties);
	PropertiesSets.Insert(SetProperties.Name, SetProperties);
	PropertiesSets.Insert(SetProperties.Ref, SetProperties);
	
	Return SetProperties;
	
EndFunction

// Returns:
//  Structure:
//   * Name - String
//   * IsFolder - Boolean
//   * Used - Undefined
//   * Ref - Undefined
//   * Parent - Undefined
//   * ChildSets - Undefined
//   * Description - String
//
Function New_SetProperties()
	
	SetProperties = New Structure;
	SetProperties.Insert("Name", "");
	SetProperties.Insert("IsFolder", False);
	SetProperties.Insert("Used", Undefined);
	SetProperties.Insert("Ref", Undefined);
	SetProperties.Insert("Parent", Undefined);
	SetProperties.Insert("ChildSets", Undefined);
	SetProperties.Insert("Description", "");
	
	Return SetProperties;

EndFunction

Function ReferenceToParent(Parent)
	
	If ValueIsFilled(Parent) Then
		
		If Not Common.SeparatedDataUsageAvailable() Then
			Return New UUID(Parent);
		EndIf;
			
			If TypeOf(Parent) = Type("String") Then
				Parent = GetRef(New UUID(Parent));
			ElsIf TypeOf(Parent) = Type("UUID") Then
				Parent = GetRef(Parent);
			EndIf;
		
	EndIf;
	
	Return Parent;
	
EndFunction

#EndIf

// ACC:361-disable server code was not accessed.
Function UpperLevelSetPresentation(PredefinedItemName, SetProperties = Undefined)
	
	Presentation = "";
	Position = StrFind(PredefinedItemName, "_");
	FirstNamePart =  Left(PredefinedItemName, Position - 1);
	SecondNamePart = Right(PredefinedItemName, StrLen(PredefinedItemName) - Position);
	
	FullName = FirstNamePart + "." + SecondNamePart;
	
	MetadataObject = Metadata.FindByFullName(FullName);
	If MetadataObject = Undefined Then
		Return Presentation;
	EndIf;
	
	If ValueIsFilled(MetadataObject.ListPresentation) Then
		Presentation = MetadataObject.ListPresentation;
	ElsIf ValueIsFilled(MetadataObject.Synonym) Then
		Presentation = MetadataObject.Synonym;
	ElsIf SetProperties <> Undefined Then
		Presentation = SetProperties.Description;
	EndIf;
	
	Return Presentation;
	
EndFunction

#EndRegion