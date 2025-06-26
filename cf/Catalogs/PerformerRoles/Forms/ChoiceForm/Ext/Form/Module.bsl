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

	If Parameters.SimpleRolesOnly Then
		CommonClientServer.SetDynamicListFilterItem(List, "ExternalRole", True,,, True);
	EndIf;

	IsExternalUser = Users.IsExternalUserSession();
	If IsExternalUser Then
		CommonClientServer.SetFormItemProperty(Items.CommandBar.ChildItems,
			"FormChange", "Visible", False);
		FIlterRowInQueryText = SetFilterForExternalUser();
	Else
		FIlterRowInQueryText = 
			"WHERE ExecutorRolesAssignmentOverridable.UsersType = VALUE(Catalog.Users.EmptyRef)"; // @query-part
	EndIf;

	ListProperties = Common.DynamicListPropertiesStructure();
	ListProperties.MainTable              = "Catalog.PerformerRoles";
	ListProperties.DynamicDataRead = True;
	ListProperties.QueryText                 = List.QueryText + " " + FIlterRowInQueryText;
	Common.SetDynamicListProperties(Items.List, ListProperties);

	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.ChangeListQueryTextForCurrentLanguage(ThisObject);
	EndIf;

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)

	If IsExternalUser Then
		Cancel = True;
	EndIf;

EndProcedure

#EndRegion

#Region Private

&AtServer
Function SetFilterForExternalUser()

	CurrentExternalUser =  ExternalUsers.CurrentExternalUser();
	AuthorizationObject = Common.ObjectAttributeValue(CurrentExternalUser, "AuthorizationObject");
	FIlterRowInQueryText = StrReplace(
		"WHERE ExecutorRolesAssignmentOverridable.UsersType = VALUE(Catalog.%Name%.EmptyRef)", // @query-part
		"%Name%", AuthorizationObject.Metadata().Name);
	Return FIlterRowInQueryText;

EndFunction

&AtServer
Procedure SetConditionalAppearance()

	List.ConditionalAppearance.Items.Clear();
	Item = List.ConditionalAppearance.Items.Add();

	FilterItemsGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemsGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

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