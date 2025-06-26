///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2022, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Opens a form to merge items of catalogs, charts of characteristic types, calculation types, and accounts.
//
// Parameters:
//     ItemsToMerge - FormTable
//                  - Array of AnyRef
//                  - ValueList
//                            
//     AdditionalParameters - See AttachableCommandsClient.CommandExecuteParameters 
//
Procedure MergeSelectedItems(Val ItemsToMerge, AdditionalParameters = Undefined) Export

	DuplicateObjectsDetectionClient.MergeSelectedItems(ItemsToMerge, AdditionalParameters);

EndProcedure

// Opens a form to replace and delete items of catalogs, charts of characteristic types, calculation types, and accounts.
//
// Parameters:
//     ReplacedItems - FormTable
//                        - Array
//                        - ValueList - 
//                          
//     AdditionalParameters - See AttachableCommandsClient.CommandExecuteParameters 
//
Procedure ReplaceSelected(Val ReplacedItems, AdditionalParameters = Undefined) Export

	DuplicateObjectsDetectionClient.ReplaceSelected(ReplacedItems, AdditionalParameters);

EndProcedure

// Opens the reference occurrence report.
// The report doesn't include auxiliary data, such as record sets with the master dimension.
//
// Parameters:
//     Items - FormTable
//              - FormDataCollection
//              - Array of AnyRef
//              - ValueList - 
//         
//     OpeningParameters - Structure - Form opening parameters. Contains a set of optional fields.
//         Owner, Uniqueness, Window, URL, OnCloseNotifyDetails, WindowOpeningMode corresponding to the OpenForm parameters.
//         
// 
Procedure ShowUsageInstances(Val Items, Val OpeningParameters = Undefined) Export

	DuplicateObjectsDetectionClient.ShowUsageInstances(Items, OpeningParameters);

EndProcedure

#EndRegion
