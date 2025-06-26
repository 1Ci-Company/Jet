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

// Updates register data after changing the access kind.
//
// Parameters:
//  Tables       - CatalogRef.MetadataObjectIDs
//                - CatalogRef.ExtensionObjectIDs
//                - Array - values of the type specified above.
//                - Undefined - without filter.
//
//  AccessValuesTypes - DefinedType.AccessValue
//                      - Array - values of the type specified above.
//                      - Undefined - without filter.
//
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateRegisterData(Tables = Undefined, AccessValuesTypes = Undefined,
			HasChanges = Undefined) Export
	
	QueryText =
	"SELECT DISTINCT
	|	AccessGroupsTables.Table AS Table,
	|	DefaultAccessGroupsValues.AccessValuesType AS AccessValuesType,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.DefaultAccessGroupsValues AS DefaultAccessGroupsValues
	|		INNER JOIN InformationRegister.AccessGroupsTables AS AccessGroupsTables
	|		ON (AccessGroupsTables.AccessGroup = DefaultAccessGroupsValues.AccessGroup)
	|			AND (NOT DefaultAccessGroupsValues.AllAllowedWithoutExceptions)
	|			AND (CASE
	|				WHEN AccessGroupsTables.AddRight
	|					THEN NOT AccessGroupsTables.UnrestrictedAddRight
	|				WHEN AccessGroupsTables.RightUpdate
	|					THEN NOT AccessGroupsTables.UnrestrictedUpdateRight
	|				ELSE NOT AccessGroupsTables.UnrestrictedReadRight
	|			END)
	|			AND (&ConditionForSelectingValueTypes1)
	|			AND (&TableFilterCriterion1)";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array;
	Fields.Add(New Structure("Table",            "&TableFilterCriterion2"));
	Fields.Add(New Structure("AccessValuesType", "&ConditionForSelectingValueTypes2"));
	
	Query = New Query;
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.UsedAccessKindsByTables");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, Tables, "Tables",
		"&TableFilterCriterion1:AccessGroupsTables.Table
		|&TableFilterCriterion2:OldData.Table");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AccessValuesTypes, "AccessValuesTypes",
		"&ConditionForSelectingValueTypes1:DefaultAccessGroupsValues.AccessValuesType
		|&ConditionForSelectingValueTypes2:OldData.AccessValuesType");
	
	If AccessValuesTypes <> Undefined
	   And Tables = Undefined Then
		
		FilterDimensions = "AccessValuesType";
	Else
		FilterDimensions = Undefined;
	EndIf;
	
	Block = New DataLock;
	Block.Add("InformationRegister.UsedAccessKindsByTables");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Data = New Structure;
		Data.Insert("RegisterManager",      InformationRegisters.UsedAccessKindsByTables);
		Data.Insert("EditStringContent", Query.Execute().Unload());
		Data.Insert("FilterDimensions",       FilterDimensions);
		
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateInformationRegister(Data, HasCurrentChanges);
		
		If HasCurrentChanges Then
			HasChanges = True;
			AccessManagementInternal.ScheduleAccessRestrictionParametersUpdate(
				"WhenChangingTheUseOfAccessTypesByTables");
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf
