///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Not MobileStandaloneServer Then

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
	
	Return Catalogs.MetadataObjectIDs.AttributesToEditInBatchProcessing();
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// SaaSTechnology.ExportImportData

// Returns the catalog attributes that naturally form a catalog item key.
//
// Returns:
//  Array of String - Array of attribute names used to generate a natural key.
//
Function NaturalKeyFields() Export
	
	Return Catalogs.MetadataObjectIDs.NaturalKeyFields();
	
EndFunction

// End SaaSTechnology.ExportImportData

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	Catalogs.MetadataObjectIDs.PresentationFieldsGetProcessing(Fields,
		StandardProcessing);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	Catalogs.MetadataObjectIDs.PresentationGetProcessing(Data,
		Presentation, StandardProcessing);
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Function DataTablesFullNames() Export
	
	Tables = New Array;
	
	If Not ValueIsFilled(SessionParameters.AttachedExtensions) Then
		Return Tables;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.ExtensionVersionObjectIDs AS IDsVersions
	|WHERE
	|	IDsVersions.ExtensionsVersion = &ExtensionsVersion
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IDsVersions.FullObjectName AS FullObjectName
	|FROM
	|	InformationRegister.ExtensionVersionObjectIDs AS IDsVersions
	|WHERE
	|	IDsVersions.ExtensionsVersion = &ExtensionsVersion
	|	AND IDsVersions.Id.NoData = FALSE";
	
	QueryResults = Query.ExecuteBatch();
	
	If QueryResults[0].IsEmpty() Then
		Catalogs.MetadataObjectIDs.IsDataUpdated(True, True);
		QueryResults = Query.ExecuteBatch();
	EndIf;
	
	Return QueryResults[1].Unload().UnloadColumn("FullObjectName");
	
EndFunction

#EndRegion

#Region Private

// This procedure updates catalog data using the configuration metadata.
//
// Parameters:
//  HasChanges  - Boolean - a return value). True is returned
//                   to this parameter if changes are saved. Otherwise, not modified.
//
//  HasDeletedItems  - Boolean - a return value. Receives
//                   True if a catalog item was marked
//                   for deletion. Otherwise, not modified.
//
//  IsCheckOnly - Boolean - make no changes, just set
//                   the HasChanges and HasDeleted flags.
//
Procedure UpdateCatalogData(HasChanges = False, HasDeletedItems = False, IsCheckOnly = False) Export
	
	Catalogs.MetadataObjectIDs.RunDataUpdate(HasChanges,
		HasDeletedItems, IsCheckOnly, , , True);
	
EndProcedure

// Returns True if the metadata object,
// which the extension object ID corresponds to, exists in the catalog,
// does not have the deletion mark but is absent from the extension metadata cache.
//
// Parameters:
//  Id - CatalogRef.ExtensionObjectIDs - the ID
//                    of a metadata object in an extension.
//
// Returns:
//  Boolean - True if disabled.
//
Function ExtensionObjectDisabled(Id) Export
	
	StandardSubsystemsCached.MetadataObjectIDsUsageCheck(True, True);
	
	Query = New Query;
	Query.SetParameter("Ref", Id);
	Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
	
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.ExtensionObjectIDs AS IDs
	|WHERE
	|	IDs.Ref = &Ref
	|	AND NOT IDs.DeletionMark
	|	AND NOT TRUE IN
	|				(SELECT TOP 1
	|					TRUE
	|				FROM
	|					InformationRegister.ExtensionVersionObjectIDs AS IDsVersions
	|				WHERE
	|					IDsVersions.Id = IDs.Ref
	|					AND IDsVersions.ExtensionsVersion = &ExtensionsVersion)";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// For internal use only.
Function CurrentVersionExtensionObjectIDsFilled() Export
	
	Query = New Query;
	Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.ExtensionVersionObjectIDs AS IDsVersions
	|WHERE
	|	IDsVersions.ExtensionsVersion = &ExtensionsVersion";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#EndRegion

#EndIf

#EndIf
