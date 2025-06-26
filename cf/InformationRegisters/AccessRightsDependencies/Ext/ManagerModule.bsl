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

#Region Internal

// Updates register data if the developer
// changed dependencies in the overridable module.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	SetPrivilegedMode(True);
	
	AccessRightsDependencies = AccessRightsDependencies();
	
	TemporaryTablesQueriesText =
	"SELECT
	|	NewData.SubordinateTable,
	|	NewData.LeadingTableType
	|INTO NewData
	|FROM
	|	&AccessRightsDependencies AS NewData";
	
	QueryText =
	"SELECT
	|	NewData.SubordinateTable,
	|	NewData.LeadingTableType,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array;
	Fields.Add(New Structure("SubordinateTable"));
	Fields.Add(New Structure("LeadingTableType"));
	
	Query = New Query;
	AccessRightsDependencies.GroupBy("SubordinateTable, LeadingTableType");
	Query.SetParameter("AccessRightsDependencies", AccessRightsDependencies);
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessRightsDependencies", TemporaryTablesQueriesText);
	
	Block = New DataLock;
	Block.Add("InformationRegister.AccessRightsDependencies");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Data = New Structure;
		Data.Insert("RegisterManager",      InformationRegisters.AccessRightsDependencies);
		Data.Insert("EditStringContent", Query.Execute().Unload());
		
		AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#Region Private

// Returns:
//  ValueTable:
//   * SubordinateTable - CatalogRef.MetadataObjectIDs
//   * LeadingTableType  - AnyRef
//
Function AccessRightsDependencies() Export
	
	AccessRightsDependencies = CreateRecordSet();
	
	Table = New ValueTable;
	Table.Columns.Add("SubordinateTable", New TypeDescription("String"));
	Table.Columns.Add("LeadingTable",     New TypeDescription("String"));
	
	SSLSubsystemsIntegration.OnFillAccessRightsDependencies(Table);
	AccessManagementOverridable.OnFillAccessRightsDependencies(Table);
	
	AccessRightsDependencies = CreateRecordSet().Unload();
	For Each String In Table Do
		NewRow = AccessRightsDependencies.Add();
		
		MetadataObject = Common.MetadataObjectByFullName(String.SubordinateTable);
		If MetadataObject = Undefined Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error in procedure %1
				           |of common module %2.
				           |
				           |Cannot find subordinate table ""%3"".';"),
				"OnFillAccessRightsDependencies",
				"AccessManagementOverridable",
				String.SubordinateTable);
			Raise ErrorText;
		EndIf;
		NewRow.SubordinateTable = Common.MetadataObjectID(
			String.SubordinateTable);
		
		MetadataObject = Common.MetadataObjectByFullName(String.LeadingTable);
		If MetadataObject = Undefined Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error in procedure %1
				           |of common module %2.
				           |
				           |Cannot find master table ""%3"".';"),
				"OnFillAccessRightsDependencies",
				"AccessManagementOverridable",
				String.LeadingTable);
			Raise ErrorText;
		EndIf;
		NewRow.LeadingTableType = Common.ObjectManagerByFullName(
			String.LeadingTable).EmptyRef();
	EndDo;
	
	Return AccessRightsDependencies;
	
EndFunction

#EndRegion

#EndIf