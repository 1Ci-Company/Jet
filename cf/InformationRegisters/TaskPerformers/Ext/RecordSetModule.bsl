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

#Region Variables

// 
Var ModifiedPerformersGroups; // Array of CatalogRef.TaskPerformersGroups -
                                    // 
// 

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Count() > 0 Then
		NewTasksPerformers = Unload();
		SetPrivilegedMode(True);
		TaskPerformersGroups = BusinessProcessesAndTasksServer.TaskPerformersGroups(NewTasksPerformers);
		SetPrivilegedMode(False);
		IndexOf = 0;
		For Each Record In ThisObject Do
			Record.TaskPerformersGroup = TaskPerformersGroups[IndexOf];
			IndexOf = IndexOf + 1;
		EndDo
	EndIf;
		
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModifiedPerformersGroups = ModifiedTasksAssigneesGroups();
	EndIf;
	// End StandardSubsystems.AccessManagement
	
EndProcedure

// StandardSubsystems.AccessManagement
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.UpdatePerformersGroupsUsers(ModifiedPerformersGroups);
	EndIf;
	
EndProcedure
// End StandardSubsystems.AccessManagement

#EndRegion

#Region Private

// StandardSubsystems.AccessManagement
Function ModifiedTasksAssigneesGroups() Export
	
	Query = New Query;
	Query.SetParameter("NewRecords", Unload());
	Query.Text =
	"SELECT
	|	NewRecords.PerformerRole,
	|	NewRecords.Performer,
	|	NewRecords.MainAddressingObject,
	|	NewRecords.AdditionalAddressingObject,
	|	NewRecords.TaskPerformersGroup
	|INTO NewRecords
	|FROM
	|	&NewRecords AS NewRecords
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Total.TaskPerformersGroup
	|FROM
	|	(SELECT DISTINCT
	|		Differences1.TaskPerformersGroup AS TaskPerformersGroup
	|	FROM
	|		(SELECT
	|			TaskPerformers.PerformerRole AS PerformerRole,
	|			TaskPerformers.Performer AS Performer,
	|			TaskPerformers.MainAddressingObject AS MainAddressingObject,
	|			TaskPerformers.AdditionalAddressingObject AS AdditionalAddressingObject,
	|			TaskPerformers.TaskPerformersGroup AS TaskPerformersGroup,
	|			-1 AS LineChangeType
	|		FROM
	|			InformationRegister.TaskPerformers AS TaskPerformers
	|		WHERE
	|			&FilterConditions
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			NewRecords.PerformerRole,
	|			NewRecords.Performer,
	|			NewRecords.MainAddressingObject,
	|			NewRecords.AdditionalAddressingObject,
	|			NewRecords.TaskPerformersGroup,
	|			1
	|		FROM
	|			NewRecords AS NewRecords) AS Differences1
	|	
	|	GROUP BY
	|		Differences1.PerformerRole,
	|		Differences1.Performer,
	|		Differences1.MainAddressingObject,
	|		Differences1.AdditionalAddressingObject,
	|		Differences1.TaskPerformersGroup
	|	
	|	HAVING
	|		SUM(Differences1.LineChangeType) <> 0) AS Total
	|WHERE
	|	Total.TaskPerformersGroup <> VALUE(Catalog.TaskPerformersGroups.EmptyRef)";
	
	FilterConditions = "True";
	For Each FilterElement In Filter Do
		If FilterElement.Use Then
			FilterConditions = FilterConditions + "
			|AND TaskPerformers." + FilterElement.Name + " = &" + FilterElement.Name;
			Query.SetParameter(FilterElement.Name, FilterElement.Value);
		EndIf;
	EndDo;
	
	Query.Text = StrReplace(Query.Text, "&FilterConditions", FilterConditions);
	Return Query.Execute().Unload().UnloadColumn("TaskPerformersGroup");
	
EndFunction
// End StandardSubsystems.AccessManagement

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf