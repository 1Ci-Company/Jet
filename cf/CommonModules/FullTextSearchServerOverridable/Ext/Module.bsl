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

// Provides users with the ability to change the full-search sections shown upon search location selection.
// By default, the section tree is based on the subsystem tree.
//
// Before you add a metadata object, make sure that FullTextSearch is set to Metadata.ObjectProperties.FullTextSearchUsing.Use.
// 
//
// Parameters:
//   SearchSections - ValueTree - Search locations. Contains the following columns:
//     * Section   - String   - section presentation, for example, a name of a subsystem or metadata object.
//     * Picture - Picture - a section picture; recommended only for root sections.
//     * MetadataObjectsList - CatalogRef.MetadataObjectIDs,
//                  CatalogRef.ExtensionObjectIDs - Required for metadata objects only.
//                                                                      Must be empty for sections.
// Example:
//
//	SectionMain = SearchSections.Rows.Add();
//	SectionMain.Section = "Main";
//	SectionMain.Picture = PictureLib.SectionMain;
//	
//	ProformaInvoice = Metadata.Documents.CustomerProformaInvoice;
//	If AccessRight("View", ProformaInvoice)
//		And Common.MetadataObjectAvailableByFunctionalOptions(ProformaInvoice) Then 
//		
//		SectionObject = SectionMain.Rows.Add();
//		SectionObject.Section= ProformaInvoice.ListPresentation;
//		SectionObject.MetadataObject= Common.MetadataObjectID(ProformaInvoice);
//	EndIf;
//
Procedure OnGetFullTextSearchSections(SearchSections) Export
	
	
	
EndProcedure

#EndRegion