///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2022, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Search for duplicates for the specified SampleObject value.
//
// Parameters:
//     SearchArea - String - Data table name (full metadata name) of the search location.
//                              For example, "Catalog.Products". 
//                              Supports search in catalogs, charts of characteristic types, calculation types, and charts of accounts.
//
//     SampleObject - Arbitrary - Object with the data of the search item.
//
//     AdditionalParameters - Arbitrary - Parameter to pass to event handlers.
//
// Returns:
//     ValueTable:
//       * Ref       - AnyRef - Item reference.
//       * Code          - String
//                      - Number - 
//       * Description - String - Item description.
//       * Parent     - Arbitrary - Parent to the group of duplicates.
//                                       If Parent is empty, the item is the parent to the group.
//       * OtherFields - Arbitrary - a value of the corresponding filter fields and criteria for comparing duplicates.
// 
Function FindItemDuplicates(Val SearchArea, Val SampleObject, Val AdditionalParameters) Export

	Return DuplicateObjectsDetection.FindItemDuplicates(SearchArea, SampleObject, AdditionalParameters);

EndFunction

// Adds related subordinate objects to a duplicate collection.
//
// Parameters:
//  ReplacementPairs		 - See Common.ReplaceReferences.ReplacementPairs
//  ReplacementParameters	 - See Common.RefsReplacementParameters
//
Procedure SupplementDuplicatesWithLinkedSubordinateObjects(ReplacementPairs, ReplacementParameters) Export

	DuplicateObjectsDetection.SupplementDuplicatesWithLinkedSubordinateObjects(ReplacementPairs, ReplacementParameters);

EndProcedure

#EndRegion
