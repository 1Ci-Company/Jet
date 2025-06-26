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
		CommonClientServer.SetDynamicListFilterItem(
			ListRoles, "UsedWithoutAddressingObjects", True,,True);
	EndIf;	
	If Parameters.NoExternalRoles = True Then
		CommonClientServer.SetDynamicListFilterItem(
			ListRoles, "ExternalRole", False);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.ChangeListQueryTextForCurrentLanguage(ThisObject, "ListRoles");
	EndIf;
	
	If TypeOf(Parameters.Performer) = Type("CatalogRef.Users") Then
		
		CurrentItem = Items.ListUsers;
		Items.ListUsers.CurrentRow = Parameters.Performer;
		
	ElsIf TypeOf(Parameters.Performer) = Type("CatalogRef.PerformerRoles") Then
		
		Items.Pages.CurrentPage = Items.Roles;
		CurrentItem = Items.ListRoles;
		Items.ListRoles.CurrentRow = Parameters.Performer;
		
	EndIf;
	
	UsersInternal.SetUpFieldDynamicListPicNum(ListUsers);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SelectPerformerRole") Then
		If TypeOf(ValueSelected) = Type("Structure") Then
			NotifyChoice(ValueSelected);
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersListUsers

&AtServerNoContext
Procedure ListUsersOnGetDataAtServer(TagName, Settings, Rows)
	
	UsersInternal.DynamicListOnGetDataAtServer(TagName, Settings, Rows);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersListRoles

&AtClient
Procedure ListUsersValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	NotifyChoice(Value);
	
EndProcedure

&AtClient
Procedure ListRolesValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	SelectRole(Item.CurrentData);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	
	If Items.Pages.CurrentPage = Items.Users Then 
		NotifyChoice(Items.ListUsers.CurrentRow);
		
	ElsIf Items.Pages.CurrentPage = Items.Roles Then 
		SelectRole(Items.ListRoles.CurrentData);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectRole(CurrentData)
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.UsedByAddressingObjects Then
		
		FormParameters = BusinessProcessesAndTasksClient.PerformerRoleChoiceFormParameters(CurrentData.Ref);
		FormParameters.SelectAddressingObject = True;
	
		BusinessProcessesAndTasksClient.OpenPerformerRoleChoiceForm(FormParameters, ThisObject);
		
	Else
		
		ValueSelected = New Structure("PerformerRole, MainAddressingObject, AdditionalAddressingObject", 
			CurrentData.Ref, Undefined, Undefined);
		NotifyChoice(ValueSelected);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ListRoles.ConditionalAppearance.Items.Clear();
	Item = ListRoles.ConditionalAppearance.Items.Add();
	
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
