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
	
	ViewSettings = ToDoListInternal.SavedViewSettings();
	FillUserTaskTree(ViewSettings);
	SetSectionOrder(ViewSettings);
	
	AutoRefreshSettings = Common.CommonSettingsStorageLoad("ToDoList", "AutoRefreshSettings");
	If TypeOf(AutoRefreshSettings) = Type("Structure") Then
		AutoRefreshSettings.Property("AutoUpdateEnabled", UseAutoUpdate);
		AutoRefreshSettings.Property("AutoRefreshPeriod", UpdatePeriod);
	Else
		UpdatePeriod = 5;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DisplayedUserTasksTreeOnChange(Item)
	
	Modified = True;
	If Item.CurrentData.IsSection Then
		For Each ToDoItem In Item.CurrentData.GetItems() Do
			ToDoItem.Check = Item.CurrentData.Check;
		EndDo;
	ElsIf Item.CurrentData.Check Then
		Item.CurrentData.GetParent().Check = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OKButton(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	ShouldSaveSettings();
	
	If AutoUpdateEnabled Then
		Notify("ToDoListAutoUpdateEnabled");
	ElsIf AutoUpdateDisabled Then
		Notify("ToDoListAutoUpdateDisabled");
	EndIf;
	
	Close(Modified);
	
EndProcedure

&AtClient
Procedure CancelButton(Command)
	Close(False);
EndProcedure

&AtClient
Procedure MoveUp(Command)
	
	Modified = True;
	// Move the current row up one position.
	CurrentTreeRow = Items.DisplayedUserTasksTree.CurrentData;
	
	If CurrentTreeRow.IsSection Then
		TreeSections = DisplayedUserTasksTree.GetItems();
	Else
		UserTaskParent1 = CurrentTreeRow.GetParent();
		TreeSections= UserTaskParent1.GetItems();
	EndIf;
	
	CurrentRowIndex = CurrentTreeRow.IndexOf;
	If CurrentRowIndex = 0 Then
		Return; // The current row is at the top of the list. Do not move.
	EndIf;
	TreeSections.Move(CurrentTreeRow.IndexOf, -1);
	CurrentTreeRow.IndexOf = CurrentRowIndex - 1;
	// Change the previous row index.
	PreviousString = TreeSections.Get(CurrentRowIndex);
	PreviousString.IndexOf = CurrentRowIndex;
	If PreviousString.IsHidden Then
		MoveUp(Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure MoveDown(Command)
	
	Modified = True;
	// Move the current row down one position.
	CurrentTreeRow = Items.DisplayedUserTasksTree.CurrentData;
	
	If CurrentTreeRow.IsSection Then
		TreeSections = DisplayedUserTasksTree.GetItems();
	Else
		UserTaskParent1 = CurrentTreeRow.GetParent();
		TreeSections= UserTaskParent1.GetItems();
	EndIf;
	
	CurrentRowIndex = CurrentTreeRow.IndexOf;
	If CurrentRowIndex = (TreeSections.Count() -1) Then
		Return; // The current row is at the bottom of the list. Do not move.
	EndIf;
	TreeSections.Move(CurrentTreeRow.IndexOf, 1);
	CurrentTreeRow.IndexOf = CurrentRowIndex + 1;
	// Change the next row index.
	NextRow = TreeSections.Get(CurrentRowIndex);
	NextRow.IndexOf = CurrentRowIndex;
	If NextRow.IsHidden Then
		MoveDown(Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	Modified = True;
	For Each SectionRow In DisplayedUserTasksTree.GetItems() Do
		SectionRow.Check = False;
		For Each UserTaskRow In SectionRow.GetItems() Do
			UserTaskRow.Check = False;
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	Modified = True;
	For Each SectionRow In DisplayedUserTasksTree.GetItems() Do
		SectionRow.Check = True;
		For Each UserTaskRow In SectionRow.GetItems() Do
			UserTaskRow.Check = True;
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Procedure DuplicateInNotificationCenter(Command)
	
	CurrentData = Items.DisplayedUserTasksTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.IsSection Then
		Message = NStr("en = 'Please select a to-do item.';");
		ShowMessageBox(, Message);
		Return;
	EndIf;
	
	CurrentData.OutputInNotifications = Not CurrentData.OutputInNotifications;
	If CurrentData.OutputInNotifications Then
		CurrentData.Picture = PictureLib.Notifications;
	Else
		CurrentData.Picture = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillUserTaskTree(ViewSettings)
	
	ToDoList       = GetFromTempStorage(Parameters.ToDoList);
	ToDoTreeTemplate = FormAttributeToValue("DisplayedUserTasksTree");
	
	If ViewSettings.UserTasksTree.Columns.Count() = 0 Then
		UserTasksTree = ToDoTreeTemplate;
	Else
		UserTasksTree = ViewSettings.UserTasksTree;
		For Each Column In ToDoTreeTemplate.Columns Do
			If UserTasksTree.Columns.Find(Column.Name) = Undefined Then
				UserTasksTree.Columns.Add(Column.Name, Column.ValueType);
			EndIf;
		EndDo;
	EndIf;
	
	UserTasksTree.Columns.Add("Validation", New TypeDescription("Boolean"));
	CurrentSection = "";
	IndexOf        = 0;
	ToDoItemIndex    = 0;
	TreeRow  = Undefined;
	
	If ViewSettings.SectionsVisibility.Count() = 0 Then
		ToDoListInternal.SetInitialSectionsOrder(ToDoList);
	EndIf;
	
	PictureNotification = PictureLib.Notifications;
	For Each ToDoItem In ToDoList Do
		
		If ToDoItem.IsSection
			And CurrentSection <> ToDoItem.OwnerID Then
			If TreeRow <> Undefined Then
				RowFilter = New Structure;
				RowFilter.Insert("IsHidden", False);
				NotHidden1 = TreeRow.Rows.FindRows(RowFilter);
				TreeRow.IsHidden = (NotHidden1.Count() = 0);
			EndIf;
			
			TreeRow = UserTasksTree.Rows.Find(ToDoItem.OwnerID, "Id");
			If TreeRow = Undefined Then
				TreeRow = UserTasksTree.Rows.Add();
				TreeRow.Presentation = ToDoItem.SectionPresentation;
				TreeRow.Id = ToDoItem.OwnerID;
				TreeRow.IsSection     = True;
				TreeRow.Check       = True;
				TreeRow.IndexOf        = IndexOf;
				
				If ViewSettings <> Undefined Then
					SectionVisible = ViewSettings.SectionsVisibility[TreeRow.Id];
					If SectionVisible <> Undefined Then
						TreeRow.Check = SectionVisible;
					EndIf;
				EndIf;
				IndexOf = IndexOf + 1;
			Else
				IndexOf = TreeRow.IndexOf;
			EndIf;
			ToDoItemIndex = 0;
			TreeRow.Validation = True;
		ElsIf Not ToDoItem.IsSection Then
			UserTaskParent = UserTasksTree.Rows.Find(ToDoItem.OwnerID, "Id", True);
			If UserTaskParent = Undefined Then
				Continue;
			EndIf;
			UserTaskParent.ToDoDetails = UserTaskParent.ToDoDetails + ?(IsBlankString(UserTaskParent.ToDoDetails), "", Chars.LF) + ToDoItem.Presentation;
			Continue;
		EndIf;
		
		UserTaskRow = TreeRow.Rows.Find(ToDoItem.Id, "Id");
		If UserTaskRow = Undefined Then
			UserTaskRow = TreeRow.Rows.Add();
			UserTaskRow.Presentation = ToDoItem.Presentation;
			UserTaskRow.Id = ToDoItem.Id;
			UserTaskRow.IsSection     = False;
			UserTaskRow.Check       = True;
			UserTaskRow.IndexOf        = ToDoItemIndex;
			UserTaskRow.IsHidden       = ToDoItem.HideInSettings;
			UserTaskRow.Important        = ToDoItem.Important;
			UserTaskRow.OutputInNotifications = ToDoItem.OutputInNotifications;
			
			If UserTaskRow.OutputInNotifications Then
				UserTaskRow.Picture = PictureNotification;
			Else
				UserTaskRow.Picture = Undefined;
			EndIf;
			
			If ViewSettings <> Undefined Then
				UserTaskVisible = ViewSettings.UserTasksVisible[UserTaskRow.Id];
				If UserTaskVisible <> Undefined Then
					UserTaskRow.Check = UserTaskVisible;
				EndIf;
			EndIf;
			ToDoItemIndex = ToDoItemIndex + 1;
			
			CurrentSection = ToDoItem.OwnerID;
		Else
			UserTaskRow.Important = ToDoItem.Important;
			ToDoItemIndex = UserTaskRow.IndexOf + 1;
		EndIf;
		UserTaskRow.Validation = True;
	EndDo;
	
	ObsoleteItemsFilter = New Structure;
	ObsoleteItemsFilter.Insert("Validation", False);
	ObsoleteItemsFilter.Insert("Check", True);
	ObsoleteItemsFilter.Insert("IsSection", True);
	FoundRows = UserTasksTree.Rows.FindRows(ObsoleteItemsFilter, True);
	For Each FoundRow In FoundRows Do
		UserTasksTree.Rows.Delete(FoundRow);
	EndDo;
	
	ObsoleteItemsFilter.IsSection = False;
	FoundRows = UserTasksTree.Rows.FindRows(ObsoleteItemsFilter, True);
	For Each FoundRow In FoundRows Do
		FoundRow.Parent.Rows.Delete(FoundRow);
	EndDo;
	
	UserTasksTree.Columns.Delete("Validation");
	
	ValueToFormAttribute(UserTasksTree, "DisplayedUserTasksTree");
	
EndProcedure

&AtServer
Procedure ShouldSaveSettings()
	
	ViewSettings = ToDoListInternal.SavedViewSettings();
	UserTasksTree = FormAttributeToValue("DisplayedUserTasksTree");
	For Each Section In UserTasksTree.Rows Do
		ViewSettings.SectionsVisibility.Insert(Section.Id, Section.Check);
		For Each ToDoItem In Section.Rows Do
			ViewSettings.UserTasksVisible.Insert(ToDoItem.Id, ToDoItem.Check);
		EndDo;
	EndDo;
	
	ViewSettings.UserTasksTree = UserTasksTree;	
	Common.CommonSettingsStorageSave("ToDoList", "ViewSettings", ViewSettings);
	
	// Save auto-refresh settings.
	AutoRefreshSettings = Common.CommonSettingsStorageLoad("ToDoList", "AutoRefreshSettings");
	
	If AutoRefreshSettings = Undefined Then
		AutoRefreshSettings = New Structure;
	Else
		If UseAutoUpdate Then
			AutoUpdateEnabled = AutoRefreshSettings.AutoUpdateEnabled <> UseAutoUpdate;
		Else
			AutoUpdateDisabled = AutoRefreshSettings.AutoUpdateEnabled <> UseAutoUpdate;
		EndIf;
	EndIf;
	
	AutoRefreshSettings.Insert("AutoUpdateEnabled", UseAutoUpdate);
	AutoRefreshSettings.Insert("AutoRefreshPeriod", UpdatePeriod);
	
	Common.CommonSettingsStorageSave("ToDoList", "AutoRefreshSettings", AutoRefreshSettings);
	
EndProcedure

&AtServer
Procedure SetSectionOrder(ViewSettings)
	
	SavedUserTaskTree = ViewSettings.UserTasksTree;
	If SavedUserTaskTree.Rows.Count() = 0 Then
		Return;
	EndIf;
	
	UserTasksTree = FormAttributeToValue("DisplayedUserTasksTree");
	Sections   = UserTasksTree.Rows;
	For Each SectionRow In Sections Do
		SavedSection = SavedUserTaskTree.Rows.Find(SectionRow.Id, "Id");
		If SavedSection = Undefined Then
			Continue;
		EndIf;
		SectionRow.IndexOf = SavedSection.IndexOf;
		UserTasks = SectionRow.Rows;
		LastUserTaskIndex = UserTasks.Count() - 1;
		For Each RowUserTask In UserTasks Do
			SavedToDoItem = SavedSection.Rows.Find(RowUserTask.Id, "Id");
			If SavedToDoItem = Undefined Then
				RowUserTask.IndexOf = LastUserTaskIndex;
				LastUserTaskIndex = LastUserTaskIndex - 1;
				Continue;
			EndIf;
			RowUserTask.IndexOf = SavedToDoItem.IndexOf;
		EndDo;
		UserTasks.Sort("IndexOf asc");
	EndDo;
	
	Sections.Sort("IndexOf asc");
	ValueToFormAttribute(UserTasksTree, "DisplayedUserTasksTree");
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DisplayedUserTasksTreeCheck.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DisplayedUserTasksTreePresentation.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DisplayedUserTasksTreePicture.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("DisplayedUserTasksTree.IsHidden");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	Item.Appearance.SetParameterValue("Visible", False);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DisplayedUserTasksTreeCheck.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DisplayedUserTasksTreePresentation.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DisplayedUserTasksTreePicture.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("DisplayedUserTasksTree.Important");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DisplayedUserTasksTreeCheck.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DisplayedUserTasksTreePresentation.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DisplayedUserTasksTreePicture.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("DisplayedUserTasksTree.IsSection");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	Item.Appearance.SetParameterValue("Font", StyleFonts.ImportantLabelFont);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DisplayedUserTasksTreeCheck.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DisplayedUserTasksTreePresentation.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DisplayedUserTasksTreePicture.Name);  
	
	DataFilterItemsGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	DataFilterItemsGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	DataFilterItemsGroup.Use = True;
	
	DataFilterItem = DataFilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("DisplayedUserTasksTree.Important");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False;
	DataFilterItem.Use  = True;
	
	DataFilterItem = DataFilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("DisplayedUserTasksTree.IsSection");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False;
	DataFilterItem.Use  = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.HyperlinkColor);
	
EndProcedure

#EndRegion