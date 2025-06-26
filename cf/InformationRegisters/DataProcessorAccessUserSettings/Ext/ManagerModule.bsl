///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Writes the settings table to the register data for the specified dimensions.
//
// Parameters:
//   SettingsTable - ValueTable 
//   DimensionValues - Structure
//   ResourcesValues - Structure
//   DeleteOldItems - Boolean
//
Procedure WriteSettingsPackage(SettingsTable, DimensionValues, ResourcesValues, DeleteOldItems) Export
	
	RecordSet = CreateRecordSet();
	For Each KeyAndValue In DimensionValues Do
		Filter = RecordSet.Filter[KeyAndValue.Key];// FilterItem
		Filter.Set(KeyAndValue.Value, True);
		SettingsTable.Columns.Add(KeyAndValue.Key);
		SettingsTable.FillValues(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	For Each KeyAndValue In ResourcesValues Do
		SettingsTable.Columns.Add(KeyAndValue.Key);
		SettingsTable.FillValues(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	If Not DeleteOldItems Then
		RecordSet.Read();
		OldRecords = RecordSet.Unload();
		SearchByDimensions = New Structure("AdditionalReportOrDataProcessor, CommandID, User");
		For Each OldRecord In OldRecords Do
			FillPropertyValues(SearchByDimensions, OldRecord);
			If SettingsTable.FindRows(SearchByDimensions).Count() = 0 Then
				FillPropertyValues(SettingsTable.Add(), OldRecord);
			EndIf;
		EndDo;
	EndIf;
	RecordSet.Load(SettingsTable);
	RecordSet.Write(True);
	
EndProcedure

#EndRegion

#EndIf