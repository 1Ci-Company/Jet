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

#Region Public

#Region ForCallsFromOtherSubsystems

// SaaSTechnology.ExportImportData

// Attached in ExportImportDataOverridable.OnRegisterDataExportHandlers.
//
// Parameters:
//   Container - DataProcessorObject.ExportImportDataContainerManager
//   ObjectExportManager - DataProcessorObject.ExportImportDataInfobaseDataExportManager
//   Serializer - XDTOSerializer
//   Object - ConstantValueManager
//          - CatalogObject
//          - DocumentObject
//          - BusinessProcessObject
//          - TaskObject
//          - ChartOfAccountsObject
//          - ExchangePlanObject
//          - ChartOfCharacteristicTypesObject
//          - ChartOfCalculationTypesObject
//          - InformationRegisterRecordSet
//          - AccumulationRegisterRecordSet
//          - AccountingRegisterRecordSet
//          - CalculationRegisterRecordSet
//          - SequenceRecordSet
//          - RecalculationRecordSet
//   Artifacts - Array of XDTODataObject
//   Cancel - Boolean
//
Procedure BeforeExportObject(Container, ObjectExportManager, Serializer, Object, Artifacts, Cancel) Export
	
	AccessManagementInternal.BeforeExportRecordSet(Container, ObjectExportManager, Serializer, Object, Artifacts, Cancel);
	
EndProcedure

// End SaaSTechnology.ExportImportData

#EndRegion

#EndRegion

#Region Private

// Parameters:
//  List - DynamicList
//  FieldName - String
//
Procedure CreateARepresentationOfTheAccessValueType(List, FieldName) Export
	
	AccessValuesTypes = Metadata.DefinedTypes.AccessValue.Type.Types();
	
	For Each Type In AccessValuesTypes Do
		Types = New Array;
		Types.Add(Type);
		TypeDetails = New TypeDescription(Types);
		TypeBlankRef = TypeDetails.AdjustValue(Undefined);
		
		// Appearance.
		AppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
		AppearanceItem.Appearance.SetParameterValue("Text", String(Type));
		
		FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterElement.LeftValue  = New DataCompositionField(FieldName);
		FilterElement.ComparisonType   = DataCompositionComparisonType.Equal;
		FilterElement.RightValue = TypeBlankRef;
		FilterElement.Use  = True;
		
		FieldItem = AppearanceItem.Fields.Items.Add();
		FieldItem.Field = New DataCompositionField(FieldName);
		FieldItem.Use = True;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
