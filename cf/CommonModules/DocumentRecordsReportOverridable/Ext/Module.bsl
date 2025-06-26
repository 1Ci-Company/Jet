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

// Allows you to add registers with document records as additional registers.
//
// Parameters:
//    Document - DocumentRef - a document whose register records collection is to be supplemented.
//    RegistersWithRecords - Map of KeyAndValue:
//        * Key     - MetadataObject - - a register as a metadata object.
//        * Value - String           - a name of the recorder field.
//
Procedure OnDetermineRegistersWithRecords(Document, RegistersWithRecords) Export
	
	
	
EndProcedure

// Allows you to calculate the number of records for additional sets added by the
// OnDetermineRegistersWithRecords procedure.
//
// Parameters:
//    Document - DocumentRef - a document whose register records collection is to be supplemented.
//    CalculatedCount - Map of KeyAndValue:
//        * Key     - String - a full name of the register (underscore is used instead of dots).
//        * Value - Number  - a calculated number of records.
//
Procedure OnCalculateRecordsCount(Document, CalculatedCount) Export
	
	
	
EndProcedure

// Supplements or overrides the collection of data sets used to output document register records.
//
// Parameters:
//    Document - DocumentRef - a document whose register records collection is to be supplemented.
//    DataSets - Array - info about data sets (the Structure item type).
//
Procedure OnPrepareDataSet(Document, DataSets) Export
	
	
	
EndProcedure

#EndRegion
