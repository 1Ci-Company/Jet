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
	
	If Object.Ref = Catalogs.UserGroups.EmptyRef()
	   And Object.Parent = Users.AllUsersGroup() Then
		
		Object.Parent = Catalogs.UserGroups.EmptyRef();
	EndIf;
	
	If Object.Ref = Users.AllUsersGroup() Then
		ReadOnly = True;
	EndIf;
	
	FillUserStatuses();
	
	UpdateInvalidUsersList(True);
	SetPropertiesAvailability(ThisObject);
	
	If Common.IsStandaloneWorkplace() Then
		ReadOnly = True;
	EndIf;
	
	If Common.IsMobileClient() Then
		Items.HeaderGroup.ItemsAndTitlesAlign = ItemsAndTitlesAlignVariant.ItemsRightTitlesLeft;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillUserStatuses();
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_UserGroups", New Structure, Object.Ref);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ParentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("SelectParent");
	
	OpenForm("Catalog.UserGroups.ChoiceForm", FormParameters, Items.Parent);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersContent

&AtClient
Procedure ContentChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	Object.Content.Clear();
	If TypeOf(ValueSelected) = Type("Array") Then
		For Each Value In ValueSelected Do
			UserChoiceProcessing(Value);
		EndDo;
	Else
		UserChoiceProcessing(ValueSelected);
	EndIf;
	FillUserStatuses();
	Items.Content.Refresh();
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure ContentDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	UserMessage = MoveUserToGroup(DragParameters.Value, Object.Ref);
	If UserMessage <> Undefined Then
		ShowUserNotification(
			NStr("en = 'Move users';"), , UserMessage, PictureLib.DialogInformation);
	EndIf;
		
EndProcedure

&AtClient
Procedure ContentOnChange(Item)
	SetPropertiesAvailability(ThisObject);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure PickUsers(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CloseOnChoice", False);
	FormParameters.Insert("MultipleChoice", True);
	FormParameters.Insert("AdvancedPick", True);
	FormParameters.Insert("ExtendedPickFormParameters", ExtendedPickFormParameters());
	
	OpenForm("Catalog.Users.ChoiceForm", FormParameters, Items.Content);

EndProcedure

&AtClient
Procedure ShowInvalidUsers(Command)
	UpdateInvalidUsersList(False);
	SetPropertiesAvailability(ThisObject);
EndProcedure

&AtClient
Procedure SortAsc(Command)
	CompositionSortRows("Ascending");
EndProcedure

&AtClient
Procedure SortDesc(Command)
	CompositionSortRows("Descending");
EndProcedure

&AtClient
Procedure MoveUp(Command)
	CompositionMoveRow("Up");
EndProcedure

&AtClient
Procedure MoveDown(Command)
	CompositionMoveRow("Down");
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure SetPropertiesAvailability(Form)
	
	Items = Form.Items;
	
	GroupComposition1 = Form.Object.Content;
	
	FilterParameters = New Structure;
	FilterParameters.Insert("Invalid", False);
	HasValidUsers = GroupComposition1.FindRows(FilterParameters).Count() > 0;
	
	FilterParameters.Insert("Invalid", True);
	HasInvalidUsers = GroupComposition1.FindRows(FilterParameters).Count() > 0;
	
	MoveCommandsAvailability =
		HasValidUsers
		Or (HasInvalidUsers
			And Items.ShowInvalidUsers.Check);
	
	Items.ContentMoveUp.Enabled         = MoveCommandsAvailability;
	Items.ContentMoveDown.Enabled          = MoveCommandsAvailability;
	Items.ContentContextMenuMoveUp.Enabled = MoveCommandsAvailability;
	Items.ContentContextMenuMoveDown.Enabled  = MoveCommandsAvailability;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.User.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Content.Invalid");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);

EndProcedure

&AtClient
Procedure UserChoiceProcessing(ValueSelected)
	
	If TypeOf(ValueSelected) = Type("CatalogRef.Users") Then
		Object.Content.Add().User = ValueSelected;
	EndIf;
	
EndProcedure

&AtServer
Function MoveUserToGroup(UsersArray, NewParentGroup)
	
	MovedUsersArray = New Array;
	UnmovedUsersArray = New Array;
	For Each UserRef In UsersArray Do
		
		FilterParameters = New Structure("User", UserRef);
		If TypeOf(UserRef) = Type("CatalogRef.Users")
			And Object.Content.FindRows(FilterParameters).Count() = 0 Then
			Object.Content.Add().User = UserRef;
			MovedUsersArray.Add(UserRef);
		EndIf;
		
	EndDo;
	
	Return UsersInternal.CreateUserMessage(
		MovedUsersArray, NewParentGroup, False, UnmovedUsersArray);
	
EndFunction

&AtServer
Function ExtendedPickFormParameters()
	
	PickingParameters = UsersInternal.NewParametersOfExtendedPickForm();
	PickingParameters.PickFormHeader = NStr("en = 'Pick group members';");
	
	PickingParameters.SelectedUsers =
		Object.Content.Unload(, "User").UnloadColumn("User");
	
	Return PutToTempStorage(PickingParameters, UUID);
	
EndFunction

&AtServer
Procedure FillUserStatuses()
	
	For Each GroupCompositionRow In Object.Content Do
		GroupCompositionRow.Invalid = 
			Common.ObjectAttributeValue(GroupCompositionRow.User, "Invalid");
	EndDo;
	
EndProcedure

&AtServer
Procedure UpdateInvalidUsersList(BeforeOpenForm)
	
	Items.ShowInvalidUsers.Check = ?(BeforeOpenForm, False,
		Not Items.ShowInvalidUsers.Check);
	
	Filter = New Structure;
	
	If Not Items.ShowInvalidUsers.Check Then
		Filter.Insert("Invalid", False);
		Items.Content.RowFilter = New FixedStructure(Filter);
	Else
		Items.Content.RowFilter = New FixedStructure();
	EndIf;
	
	Items.Content.Refresh();
	
EndProcedure

&AtServer
Procedure CompositionSortRows(SortType)
	
	If Not Items.ShowInvalidUsers.Check Then
		Items.Content.RowFilter = New FixedStructure();
	EndIf;
	
	If SortType = "Ascending" Then
		Object.Content.Sort("User Asc");
	Else
		Object.Content.Sort("User Desc");
	EndIf;
	
	If Not Items.ShowInvalidUsers.Check Then
		Filter = New Structure;
		Filter.Insert("Invalid", False);
		Items.Content.RowFilter = New FixedStructure(Filter);
	EndIf;
	
EndProcedure

&AtServer
Procedure CompositionMoveRow(MovementDirection)
	
	String = Object.Content.FindByID(Items.Content.CurrentRow);
	If String = Undefined Then
		Return;
	EndIf;
	
	CurrentRowIndex = String.LineNumber - 1;
	Move = 0;
	
	While True Do
		Move = Move + ?(MovementDirection = "Up", -1, 1);
		
		If CurrentRowIndex + Move < 0
		Or CurrentRowIndex + Move >= Object.Content.Count() Then
			Return;
		EndIf;
		
		If Items.ShowInvalidUsers.Check
		 Or Object.Content[CurrentRowIndex + Move].Invalid = False Then
			Break;
		EndIf;
	EndDo;
	
	Object.Content.Move(CurrentRowIndex, Move);
	Items.Content.Refresh();
	
EndProcedure

#EndRegion
