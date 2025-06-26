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

// Is called by following a link or double-clicking a cell 
// of a spreadsheet document that contains application release notes (common template AppReleaseNotes).
//
// Parameters:
//   Area - SpreadsheetDocumentRange - a document area 
//             that was clicked.
//
Procedure OnClickUpdateDetailsDocumentHyperlink(Val Area) Export
	
	

EndProcedure

// Is called in the BeforeStart handler. Checks for
// an update to a current version of a program.
//
// Parameters:
//  DataVersion - String - data version of a main configuration that is to be updated
//                          (from the SubsystemsVersions information register).
//
Procedure OnDetermineUpdateAvailability(Val DataVersion) Export
	
	
	
EndProcedure

#EndRegion
