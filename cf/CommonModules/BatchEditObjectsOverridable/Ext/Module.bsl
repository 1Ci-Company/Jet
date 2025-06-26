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

// Define metadata objects in whose list forms
// the bulk edit command will be displayed.
// See BatchEditObjectsClient.ChangeSelectedItems
// 
// Parameters:
//  Objects - Array of MetadataObject
//
// Example:
//	Objects.Add(Metadata.Catalogs.Products);
//	Objects.Add(Metadata.Catalogs.Partners);
//
Procedure OnDefineObjectsWithBatchObjectsModificationCommand(Objects) Export

	

EndProcedure

// Defining metadata objects, in whose manager modules group 
// attribute editing is prohibited.
//
// Parameters:
//   Objects - Map of KeyAndValue - set the key to the full name of the metadata object
//                            attached to the "Bulk edit" subsystem. 
//                            In addition, the value can include export function names:
//                            "AttributesToSkipInBatchProcessing",
//                            "AttributesToEditInBatchProcessing".
//                            Every name must start with a new line.
//                            In case there is a "*", the manager module has both functions specified.
//
// Example: 
//   Objects.Insert(Metadata.Documents.PurchaserOrders.FullName(), "*"); // both functions are defined.
//   Objects.Insert(Metadata.BusinessProcesses.JobWithRoleBasedAddressing.FullName(), "AttributesToEditInBatchProcessing");
//   Objects.Insert(Metadata.Catalogs.Partners.FullName(), "AttributesToEditInBatchProcessing
//		|AttributesToSkipInBatchProcessing");
//
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	
	
	
EndProcedure

// Determines object attributes that can be edited using the bulk edit data processor.
// By default, all the object attributes can be edited. To limit the attribute list, fill one of the collections: AttributesToEdit or NonEditAttributes.
// If the both collections contain values, the attributes that don't belong to these collections are considered to be members of the NonEditAttributes collection.
// 
// 
// Parameters:
//  Object - MetadataObject - Object for which the list of editable attributes is specified.
//  AttributesToEdit - Undefined, Array of String - Names of the attributes that can be edited using the bulk edit data processor.
//                                                            This value is ignored if the NonEditAttributes parameter is passed.
//  AttributesToSkip - Undefined, Array of String - Names of the attributes that cannot be edited using the bulk edit data processor.
// 
Procedure OnDefineEditableObjectAttributes(Object, AttributesToEdit, AttributesToSkip) Export

EndProcedure

#EndRegion
