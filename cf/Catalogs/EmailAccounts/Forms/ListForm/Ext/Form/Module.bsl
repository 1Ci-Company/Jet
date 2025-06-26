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
	
	Items.ShowPersonalUsersAccounts.Visible = Users.IsFullUser();
	
	SwitchPersonalAccountsVisibility(List,
		ShowPersonalUsersAccounts,
		Users.CurrentUser());
	
	SwitchInvalidAccountsVisibility(List, ShowInvalidAccounts);
	Items.AccountOwner.Visible = ShowPersonalUsersAccounts;
	Items.ShowInvalidAccounts.Enabled = ShowPersonalUsersAccounts;
	
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowPersonalUsersAccountsOnChange(Item)
	
	SwitchPersonalAccountsVisibility(List,
		ShowPersonalUsersAccounts,
		UsersClient.CurrentUser());
	
	Items.AccountOwner.Visible = ShowPersonalUsersAccounts;
	Items.ShowInvalidAccounts.Enabled = ShowPersonalUsersAccounts;
	
	ShowInvalidAccounts = ShowInvalidAccounts And ShowPersonalUsersAccounts;
	SwitchInvalidAccountsVisibility(List, ShowInvalidAccounts);
	
EndProcedure

&AtClient
Procedure ShowInvalidAccountsOnChange(Item)
	SwitchInvalidAccountsVisibility(List, ShowInvalidAccounts);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListOnActivateRow(Item)

	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Attachable_UpdateCommands()
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
	EndIf;
EndProcedure


&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Items.List);
	EndIf;
EndProcedure


&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure


&AtClient
Procedure Attachable_ExecuteCommand(Command)
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Items.List);
	EndIf;
EndProcedure

#EndRegion



#Region Private

&AtClientAtServerNoContext
Procedure SwitchPersonalAccountsVisibility(List, ShowPersonalUsersAccounts, CurrentUser)
	UsersList = New Array;
	UsersList.Add(PredefinedValue("Catalog.Users.EmptyRef"));
	UsersList.Add(CurrentUser);
	CommonClientServer.SetDynamicListFilterItem(
		List, "AccountOwner", UsersList, DataCompositionComparisonType.InList, ,
			Not ShowPersonalUsersAccounts);
EndProcedure

&AtClientAtServerNoContext
Procedure SwitchInvalidAccountsVisibility(List, ShowInvalidAccounts)
	CommonClientServer.SetDynamicListFilterItem(
		List, "OwnerInvalid", False, DataCompositionComparisonType.Equal, ,
			Not ShowInvalidAccounts);
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("OwnerInvalid");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

#EndRegion