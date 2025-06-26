///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	ConfigureRoleListRepresentation();
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnCreateAtServer(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_ConstantsSet" And Source = "UseExternalUsers" Then
		ConfigureRoleListRepresentation();
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure ConfigureRoleListRepresentation()
	
	QueryText = "SELECT DISTINCT
	|	TaskPerformers.PerformerRole AS PerformerRole
	|INTO Assignees
	|FROM
	|	InformationRegister.TaskPerformers AS TaskPerformers
	|		LEFT JOIN Catalog.PerformerRoles AS CatalogPerformerRoles
	|		ON TaskPerformers.PerformerRole = CatalogPerformerRoles.Ref
	|;";
		
	If Not GetFunctionalOption("UseExternalUsers") Then
		
		QueryText = QueryText + "SELECT
		|	CatalogPerformerRoles.Ref,
		|	CatalogPerformerRoles.DeletionMark,
		|	CatalogPerformerRoles.Predefined,
		|	CatalogPerformerRoles.Code,
		|	CatalogPerformerRoles.Description,
		|	CatalogPerformerRoles.UsedWithoutAddressingObjects,
		|	CatalogPerformerRoles.UsedByAddressingObjects,
		|	CatalogPerformerRoles.MainAddressingObjectTypes,
		|	CatalogPerformerRoles.AdditionalAddressingObjectTypes,
		|	CatalogPerformerRoles.Comment,
		|	CASE
		|		WHEN CatalogPerformerRoles.UsedByAddressingObjects
		|			THEN TRUE
		|		WHEN CatalogPerformerRoles.Ref IN
		|				(SELECT
		|					Assignees.PerformerRole
		|				FROM
		|					Assignees AS Assignees
		|				WHERE
		|					Assignees.PerformerRole = CatalogPerformerRoles.Ref)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS HasPerformers,
		|	CatalogPerformerRoles.ExternalRole,
		|	CatalogPerformerRoles.BriefPresentation
		|FROM
		|	Catalog.PerformerRoles AS CatalogPerformerRoles";
		
	Else
		
		QueryText = QueryText + "
		|SELECT DISTINCT
		|	ExecutorRolesAssignment.Ref AS Ref,
		|	ExecutorRolesAssignment.UsersType AS UsersType
		|INTO ExecutorRolesAssignment
		|FROM
		|	Catalog.PerformerRoles.Purpose AS ExecutorRolesAssignment
		|;
		|SELECT
		|	CatalogPerformerRoles.Ref,
		|	CatalogPerformerRoles.DeletionMark,
		|	CatalogPerformerRoles.Predefined,
		|	CatalogPerformerRoles.Code,
		|	CatalogPerformerRoles.Description,
		|	CatalogPerformerRoles.UsedWithoutAddressingObjects,
		|	CatalogPerformerRoles.UsedByAddressingObjects,
		|	CatalogPerformerRoles.MainAddressingObjectTypes,
		|	CatalogPerformerRoles.AdditionalAddressingObjectTypes,
		|	CatalogPerformerRoles.Comment,
		|	CASE
		|		WHEN CatalogPerformerRoles.UsedByAddressingObjects
		|			THEN TRUE
		|		WHEN CatalogPerformerRoles.Ref IN
		|				(SELECT
		|					Assignees.PerformerRole
		|				FROM
		|					Assignees AS Assignees
		|				WHERE
		|					Assignees.PerformerRole = CatalogPerformerRoles.Ref)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS HasPerformers,
		|	CatalogPerformerRoles.ExternalRole,
		|	CatalogPerformerRoles.BriefPresentation
		|FROM
		|	ExecutorRolesAssignment AS ExecutorRolesAssignment
		|		LEFT JOIN Catalog.PerformerRoles AS CatalogPerformerRoles
		|		ON ExecutorRolesAssignment.Ref = CatalogPerformerRoles.Ref
		|WHERE
		|	ExecutorRolesAssignment.UsersType = VALUE(Catalog.Users.EmptyRef)";
	EndIf;
	
	ListProperties = Common.DynamicListPropertiesStructure();
	ListProperties.MainTable              = "Catalog.PerformerRoles";
	ListProperties.DynamicDataRead = True;
	ListProperties.QueryText                 = QueryText;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	Item = List.ConditionalAppearance.Items.Add();
	
	FilterItemsGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemsGroup .GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("HasPerformers");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExternalRole");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.RoleWithoutPerformers);
	
EndProcedure

#EndRegion
