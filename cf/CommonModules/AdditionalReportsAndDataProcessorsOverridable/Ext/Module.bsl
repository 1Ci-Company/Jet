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

// Defines the sections where the additional data processor calling command is available.
// Add the metadata of sections
// where the commands are available to the Sections array.
// For the start page, specify AdditionalReportsAndDataProcessorsClientServer.StartPageName.
//
// Parameters:
//   Sections - Array of MetadataObject - section (subsystem) metadata.
//           - Array of String - for the start page.
//
Procedure GetSectionsWithAdditionalDataProcessors(Sections) Export
	
	Sections.Add(Metadata.Subsystems.CashManagement);
	Sections.Add(Metadata.Subsystems.Company);
	Sections.Add(Metadata.Subsystems.Purchases);
	Sections.Add(Metadata.Subsystems.Sales);
	Sections.Add(Metadata.Subsystems.Warehouses);
	
EndProcedure

// Defines the sections where the command that opens additional reports is available.
// Add the metadata of sections 
// where the commands are available to the Sections array.
// For the start page, specify AdditionalReportsAndDataProcessorsClientServer.StartPageName.
//
// Parameters:
//   Sections - Array of MetadataObject - section (subsystem) metadata.
//           - Array of String - for the start page.
//
Procedure GetSectionsWithAdditionalReports(Sections) Export
	
	Sections.Add(Metadata.Subsystems.CashManagement);
	Sections.Add(Metadata.Subsystems.Company);
	Sections.Add(Metadata.Subsystems.Purchases);
	Sections.Add(Metadata.Subsystems.Sales);
	Sections.Add(Metadata.Subsystems.Warehouses);
	
EndProcedure

#EndRegion
