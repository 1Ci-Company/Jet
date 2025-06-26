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

// Determines a list of catalogs available for importing by the "ImportDataFromFile" subsystem.
// To exclude any catalog from the list, remove it from the table.
//
// Parameters:
//  CatalogsToImport - ValueTable - a list of the catalogs, to which data can be imported:
//      * FullName          - String - a full catalog name (as in metadata).
//      * Presentation      - String - Catalog presentation in the selection list.
//      * AppliedImport - Boolean - if True, then the catalog uses its own import algorithm
//                                      and the functions are defined in the manager module.
//
// Example:
// 
//  A custom algorithm for importing products into the "Products" catalog.
//	Сведения = ЗагружаемыеСправочники.Добавить();
//	Сведения.ПолноеИмя          = Метаданные.Справочники.Номенклатура.ПолноеИмя();
//	InformationRecords.Presentation = Metadata.Catalogs.Products.Presentation ();
//	InformationRecords.AppliedImport = True;
//	
//  Import to the currency classifier is restricted.
//  TableRow = CatalogsToImport.Find(Metadata.Catalogs.Currecies.FullName(), "FullName");
//  If TableRow <> Undefined Then 
//    CatalogsToImport.Delete(TableRow);
//  EndIf;
//
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	
	
EndProcedure

#EndRegion