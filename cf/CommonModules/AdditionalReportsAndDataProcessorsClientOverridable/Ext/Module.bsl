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

#Region ObsoleteProceduresAndFunctions

// Deprecated. Instead, use PrintManagementOverridable.OnDefinePrintSettings
// It performs additional actions before generating a print form.
//
// Parameters:
//  ObjectsToPrint    - Array - references to the objects for which the print command is being executed;
//  StandardProcessing - Boolean - indicates whether it is necessary to check that a document is posted before printing.
//                                  If False, the check is skipped.
//
Procedure BeforeExecuteExternalPrintFormPrintCommand(ObjectsToPrint, StandardProcessing) Export
	
EndProcedure

#EndRegion

#EndRegion
