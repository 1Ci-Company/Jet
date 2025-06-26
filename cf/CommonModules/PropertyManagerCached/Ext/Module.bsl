///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

// For internal use only.
// 
// Returns:
//  FixedMap of KeyAndValue:
//     * Key     - String
//                - CatalogRef.AdditionalAttributesAndInfoSets
//     * Value - See Catalogs.AdditionalAttributesAndInfoSets.SetProperties
//
Function PredefinedPropertiesSets() Export

	Return Catalogs.AdditionalAttributesAndInfoSets.PredefinedPropertiesSets();
	
EndFunction

// For internal use only.
//
Function PropertiesSetsDescriptions() Export
	
	Return PropertyManagerInternal.PropertiesSetsDescriptions();
	
EndFunction

// For internal use only.
//
Function SetPropertiesTypes(Ref, ConsiderDeletionMark = True) Export
	
	SetPropertiesTypes = New Structure;
	SetPropertiesTypes.Insert("AdditionalAttributes", False);
	SetPropertiesTypes.Insert("AdditionalInfo",  False);
	SetPropertiesTypes.Insert("Labels",  False);
	
	RefType = Undefined;
	OwnerMetadata = PropertyManagerInternal.SetPropertiesValuesOwnerMetadata(Ref, ConsiderDeletionMark, RefType);
	
	If OwnerMetadata = Undefined Then
		Return SetPropertiesTypes;
	EndIf;
	
	// Checking additional attributes usage.
	SetPropertiesTypes.Insert(
		"AdditionalAttributes",
		OwnerMetadata <> Undefined
		And OwnerMetadata.TabularSections.Find("AdditionalAttributes") <> Undefined);
	
	// Checking additional info usage.
	SetPropertiesTypes.Insert(
		"AdditionalInfo",
		      Metadata.CommonCommands.Find("AdditionalInfoCommandBar") <> Undefined
		    And Metadata.CommonCommands.AdditionalInfoCommandBar.CommandParameterType.ContainsType(RefType));
	
	// Check label usage.
	LabelsOwners = Metadata.DefinedTypes.LabelsOwner.Type;
	SetPropertiesTypes.Insert(
		"Labels",
		OwnerMetadata <> Undefined
		And LabelsOwners.ContainsType(RefType));
	
	Return New FixedStructure(SetPropertiesTypes);
	
EndFunction

// For internal use only.
//
Function IsMainLanguage() Export
	
	Return StrCompare(Common.DefaultLanguageCode(), CurrentLanguage().LanguageCode) = 0;
	
EndFunction

// For internal use only.
//
Function PresentationOfPropertySets() Export
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	AdditionalAttributesAndInfoSets.Ref AS Ref,
		|	REFPRESENTATION(AdditionalAttributesAndInfoSets.Ref) AS Presentation
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets AS AdditionalAttributesAndInfoSets
		|WHERE
		|	NOT AdditionalAttributesAndInfoSets.IsFolder
		|	AND NOT AdditionalAttributesAndInfoSets.Predefined
		|	AND AdditionalAttributesAndInfoSets.PredefinedSetName = """"";
	
	SetsPresentation = New Map;
	Result = Query.Execute().Unload();
	For Each TableRow In Result Do
		SetsPresentation.Insert(TableRow.Ref, TableRow.Presentation);
	EndDo;
	
	Return New FixedMap(SetsPresentation);
	
EndFunction

#EndRegion