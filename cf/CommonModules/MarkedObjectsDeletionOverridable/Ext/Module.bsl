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

// Specify the metadata objects whose list forms will
// output the show marked objects and go to objects marked for deletion commands.
// See MarkedObjectsDeletionClient.ShowObjectsMarkedForDeletion 
// and MarkedObjectsDeletionClient.GoToMarkedForDeletionItems.
//
// Parameters:
//  Objects - Array of MetadataObject - the metadata objects to whose list forms the hide marked
//                                         objects for deletion command will be added.
//
// Example:
//	Objects.Add(Metadata.Catalogs.Products);
//	Objects.Add(Metadata.Catalogs.Partners);
//
Procedure OnDefineObjectsWithShowMarkedObjectsCommand(Objects) Export
	
EndProcedure

// Called outside of a transaction, before the deletion of associated objects.
// 
// Parameters:
//  Context - Structure - Arbitrary data, which can be initialized and passed to 
//                         MarkedObjectsDeletionOverridable.AfterDeleteObjectsGroup. 
//  ObjectsToDelete - Array of AnyRef - Objects to delete.
// 
Procedure BeforeDeletingAGroupOfObjects(Context, ObjectsToDelete) Export
	
EndProcedure

// Called outside of a transaction, before the deletion of associated objects.
// Use it to run operations that cannot be run within a transaction.
// For example, to clean up the associated data on external resources.
// 
// Parameters:
//  Context - See MarkedObjectsDeletionOverridable.BeforeDeletingAGroupOfObjects.Context
//  Success - Boolean - True if the object group has been deleted.
//
Procedure AfterDeletingAGroupOfObjects(Context, Success) Export
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Called before searching for the objects marked for deletion.
// The handler cleans up obsolete dimension keys and other infobase objects that are no longer needed.
// Instead, use either the BeforeDelete event of the objects to be deleted or specify SubordinateObjects.
// 
//  
//  See Common.SubordinateObjects.
//
// Parameters:
//   Parameters - Structure:
//     * Interactive - Boolean - True if deletion of marked objects is started by a user.
//                                False if deletion is started on the job schedule.
//
Procedure BeforeSearchForItemsMarkedForDeletion(Parameters) Export
	
EndProcedure

#EndRegion

#EndRegion
