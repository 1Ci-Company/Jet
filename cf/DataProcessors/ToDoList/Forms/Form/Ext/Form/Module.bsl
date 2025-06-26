///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

&AtServer
Var DisplayedUserTasksAndSections;
&AtClient
Var OutputNotifications;
&AtClient
Var ErrorReport;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	TimeConsumingOperation = GenerateToDoListInBackground();
	LoadAutoRefreshSettings();
	
	Items.FormCustomize.Enabled = False;
	Items.FormRefresh.Enabled  = (TimeConsumingOperation = Undefined);
	Items.FormCustomize.Visible   = AccessRight("SaveUserData", Metadata);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OutputNotifications = True;
	If TimeConsumingOperation <> Undefined Then
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow = False;
		IdleParameters.Interval = 2; // Faster than a standard interval as it is shown on the home page.
		CallbackOnCompletion = New NotifyDescription("GenerateToDoListInBackgroundCompletion", ThisObject);
		TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CallbackOnCompletion, IdleParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ToDoListAutoUpdateEnabled" Then
		LoadAutoRefreshSettings();
		UpdatePeriod = AutoRefreshSettings.AutoRefreshPeriod * 60;
		AttachIdleHandler("UpdateCurrentToDosAutomatically", UpdatePeriod);
	ElsIf EventName = "ToDoListAutoUpdateDisabled" Then
		DetachIdleHandler("UpdateCurrentToDosAutomatically");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If ErrorReport <> Undefined Then
		StandardSubsystemsClient.SendErrorReport(ErrorReport, ErrorInfo);
	EndIf;
	
	DetachIdleHandler("UpdateCurrentToDosAutomatically");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Parameters:
//  Item - FormField
//
&AtClient
Procedure Attachable_ProcessHyperlinkClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ClosingNotification1 = New NotifyDescription("ProcessHyperlinkClickCompletion", ThisObject);
	
	FilterParameters = New Structure();
	FilterParameters.Insert("Id", Item.Name);
	UserTaskParameters = UserTasksParameters.FindRows(FilterParameters)[0];
	
	OpenForm(UserTaskParameters.Form, UserTaskParameters.FormParameters, ThisObject,,,, ClosingNotification1);
	
EndProcedure

&AtClient
Procedure Attachable_URLClickProcessing(Item, Ref, StandardProcessing)
	
	StandardProcessing = False;
	
	ClosingNotification1 = New NotifyDescription("ProcessHyperlinkClickCompletion", ThisObject);
	
	FilterParameters = New Structure();
	FilterParameters.Insert("Id", Ref);
	UserTaskParameters = UserTasksParameters.FindRows(FilterParameters)[0];
	
	OpenForm(UserTaskParameters.Form, UserTaskParameters.FormParameters ,,,,, ClosingNotification1);
	
EndProcedure

// Parameters:
//  Item - FormField
//
&AtClient
Procedure Attachable_ProcessPictureClick(Item)
	SwitchPicture(Item.Name);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Customize(Command)
	
	ResultHandler = New NotifyDescription("ApplyToDoListPanel", ThisObject);
	
	FormParameters = New Structure;
	FormParameters.Insert("ToDoList", UserTasksToStorage);
	OpenForm("DataProcessor.ToDoList.Form.CustomizeCurrentUserTasks", FormParameters,,,,,ResultHandler);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	StartToDoListUpdate();
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for generating a user's to-do list.

&AtClient
Procedure UpdateCurrentToDosAutomatically()
	StartToDoListUpdate(True);
EndProcedure

&AtServer
Procedure GenerateToDoList(ToDoList)
	
	IsMobileClient = Common.IsMobileClient();
	UserTasksParameters.Clear();
	SectionsWithImportantUserTasks = New Structure;
	ViewSettings = ToDoListInternal.SavedViewSettings();
	CollapsedSections = CollapsedSections();
	
	ToDoList.Sort("IsSection Desc, SectionPresentation Asc, Important Desc, Presentation");
	PutToTempStorage(ToDoList, UserTasksToStorage);
	
	// If the user didn't customize the section positions in the to-do list,
	// they are auto-sorted according to the procedure "OnDetermineCommandInterfaceSectionsOrder".
	If ViewSettings.SectionsVisibility.Count() = 0 Then
		ToDoListInternal.SetInitialSectionsOrder(ToDoList);
	EndIf;
	
	CurrentGroup = "";
	CurrentCommonGroup = "";
	For Each ToDoItem In ToDoList Do
		
		If ToDoItem.IsSection Then
			
			// Create a common section group.
			CommonGroupName = "CommonGroup" + ToDoItem.OwnerID;
			If CurrentCommonGroup <> CommonGroupName Then
				
				SectionCollapsed = CollapsedSections[ToDoItem.OwnerID];
				If SectionCollapsed = Undefined Then
					If ViewSettings.SectionsVisibility.Count() = 0 And CurrentCommonGroup <> "" Then
						// Cannot collapse the first group.
						CollapsedSections.Insert(ToDoItem.OwnerID, True);
						SectionCollapsed = True;
					Else
						CollapsedSections.Insert(ToDoItem.OwnerID, False);
					EndIf;
					
				EndIf;
				
				SectionVisibleEnabled = ViewSettings.SectionsVisibility[ToDoItem.OwnerID];
				If SectionVisibleEnabled = Undefined Then
					SectionVisibleEnabled = True;
				EndIf;
				
				// Creating a common group containing all items required to display the section and its to-do items.
				CommonGroup = Group(CommonGroupName,, "CommonGroup");
				CommonGroup.Visible = False;
				// Create a section title group.
				TitleGroupName = "SectionTitle" + ToDoItem.OwnerID;
				TitleGroup    = Group(TitleGroupName, CommonGroup, "SectionTitle");
				// Create a section title.
				CreateCaption(ToDoItem, TitleGroup, SectionCollapsed);
				
				CurrentCommonGroup = CommonGroupName;
			EndIf;
			
			// Create a to-do items group.
			GroupName = "Group" + ToDoItem.OwnerID;
			If CurrentGroup <> GroupName Then
				CurrentGroup = GroupName;
				Var_Group        = Group(GroupName, CommonGroup);
				If IsMobileClient Then
					ViewOption = UsualGroupRepresentation.None;
				Else
					ViewOption = UsualGroupRepresentation.StrongSeparation;
				EndIf;
				Var_Group.Representation = ViewOption;
				
				If SectionCollapsed = True Then
					Var_Group.Visible = False;
				EndIf;
			EndIf;
			
			UserTaskVisibleEnabled = ViewSettings.UserTasksVisible[ToDoItem.Id];
			If UserTaskVisibleEnabled = Undefined Then
				UserTaskVisibleEnabled = True;
			EndIf;
			
			If SectionVisibleEnabled And UserTaskVisibleEnabled And ToDoItem.HasToDoItems Then
				DisplayedUserTasksAndSections.Insert(TitleGroupName);
				CommonGroup.Visible = True;
			EndIf;
			
			NewUserTask(ToDoItem, Var_Group, UserTaskVisibleEnabled);
			
			// Turning on the indicator of important to-do items.
			If ToDoItem.HasToDoItems
				And ToDoItem.Important
				And UserTaskVisibleEnabled Then
				
				SectionsWithImportantUserTasks.Insert(ToDoItem.OwnerID, CollapsedSections[ToDoItem.OwnerID]);
			EndIf;
			
		Else
			NewChildUserTask(ToDoItem);
		EndIf;
		
		FillUserTaskParameters(ToDoItem);
		
	EndDo;
	
	AddToDoItemsWithNotification(ViewSettings, ToDoList);	
	SaveCollapsedSections(CollapsedSections);
	
EndProcedure

&AtServer
Procedure OrderToDoList()
	
	SavedViewSettings = ToDoListInternal.SavedViewSettings();
	If SavedViewSettings = Undefined Then
		Return;
	EndIf;
	
	SavedUserTaskTree = SavedViewSettings.UserTasksTree;
	IsFirstSection = True;
	For Each RowSection In SavedUserTaskTree.Rows Do
		If Not IsFirstSection Then
			MoveSection(RowSection);
		EndIf;
		IsFirstSection = False;
		IsFirstUserTask   = True;
		For Each RowUserTask In RowSection.Rows Do
			If Not IsFirstUserTask Then
				MoveUserTask(RowUserTask);
			EndIf;
			IsFirstUserTask = False;
		EndDo;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Background update.

&AtServer
Function GenerateToDoListInBackground()
	
	If ExclusiveMode() Then
		Return Undefined;
	EndIf;
	
	If TimeConsumingOperation <> Undefined Then
		TimeConsumingOperations.CancelJobExecution(TimeConsumingOperation.JobID);
	EndIf;
	
	If UserTasksToStorage = "" Then
		UserTasksToStorage = PutToTempStorage(Undefined, UUID);
	EndIf;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.WaitCompletion = 0; // Run immediately.
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Update to-do list';");
	ExecutionParameters.ResultAddress = UserTasksToStorage;
	// Always runs in the background to prevent performance degradation.
	// In file mode, it might be delayed if another background job is running.
	ExecutionParameters.RunInBackground = True;
	
	Result = TimeConsumingOperations.ExecuteInBackground("ToDoListInternal.GenerateToDoListForUser",
		New Structure, ExecutionParameters);
		
	Return Result;
	
EndFunction

&AtServer
Procedure ImportToDoList(ToDoListAddress)
	
	ToDoList = GetFromTempStorage(ToDoListAddress); // See ToDoListServer.ToDoList
	DisplayedUserTasksAndSections = New Structure;
	If OnlyUpdateUserTasks Then
		FillCollapsedGroups();
		
		SectionsToDelete = New Array;
		For Each Item In Items.UserTasksPage.ChildItems Do
			SectionsToDelete.Add(Item);
		EndDo;
		
		For Each ItemToRemove In SectionsToDelete Do
			Items.Delete(ItemToRemove);
		EndDo;
		SectionsToDelete = Undefined;
		
		GenerateToDoList(ToDoList);
	Else
		OnlyUpdateUserTasks = True;
		GenerateToDoList(ToDoList);
	EndIf;
	
	// If there are collapsed sections with important to-do items, highlighting them.
	SetPictureOfSectionsWithImportantToDos();
	
	If DisplayedUserTasksAndSections.Count() = 0 Then
		Items.NoUserTasksPage.Visible = True;
	Else
		Items.NoUserTasksPage.Visible = False;
		// If all displayed to-do items belong to a single section, hiding the section title.
		If DisplayedUserTasksAndSections.Count() = 1 Then
			DisplaySection = False;
		Else
			DisplaySection = True;
		EndIf;
		For Each SectionTitleItem In DisplayedUserTasksAndSections Do
			SectionTitle = SectionTitleItem.Key;
			Items[SectionTitle].Visible = DisplaySection;
			
			If Not DisplaySection Then
				UserTaskGroupName = StrReplace(SectionTitle, "SectionTitle", "Group");
				Items[UserTaskGroupName].Visible = True;
			EndIf;
		EndDo;
	EndIf;
	
	OrderToDoList();
	
EndProcedure

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure GenerateToDoListInBackgroundCompletion(Result, AdditionalParameters) Export
	
	TimeConsumingOperation = Undefined;
	
	Items.UserTasksPage.Visible    = True;
	Items.TimeConsumingOperationPage.Visible = False;
	Items.ErrorPage.Visible  = False;
	Items.FormRefresh.Enabled = True;

	If Result = Undefined Then
		Items.FormCustomize.Enabled = OnlyUpdateUserTasks;
		Return;
	ElsIf Result.Status = "Error" Then
		Items.FormCustomize.Enabled = OnlyUpdateUserTasks;
		Items.UserTasksPage.Visible     = False;
		Items.ErrorPage.Visible   = True;
		ErrorText          = ErrorProcessing.ErrorMessageForUser(Result.ErrorInfo);
		ErrorTextDetailed = ErrorProcessing.DetailErrorDescription(Result.ErrorInfo);
		ErrorInfo   = Result.ErrorInfo;
		ErrorReport        = New ErrorReport(Result.ErrorInfo);
		StandardSubsystemsClient.ConfigureVisibilityAndTitleForURLSendErrorReport(Items.GenerateErrorReport, Result.ErrorInfo);
		Items.GroupDetails_3.Visible = Not Items.GenerateErrorReport.Visible;
		Return;
	ElsIf Result.Status = "Completed2" Then
		ImportToDoList(Result.ResultAddress);
		If OutputNotifications Then
			Picture = PictureLib.DialogInformation;
			For Each ToDoWithNotification In ToDoItemsWithNotification Do
				NotificationProcessing = New NotifyDescription("GoToImportantUserTaskFromNotificationCenter", ThisObject, 
					ToDoWithNotification.Id);
				ShowUserNotification(NStr("en = 'To-do list';"),
					NotificationProcessing, ToDoWithNotification.LongDesc, Picture, UserNotificationStatus.Important,
					ToDoWithNotification.Id);
			EndDo;
		EndIf;
		OutputNotifications = True;
		Items.FormCustomize.Enabled = True;
		If AutoRefreshSettings.Property("AutoUpdateEnabled")
			And AutoRefreshSettings.AutoUpdateEnabled Then
			UpdatePeriod = AutoRefreshSettings.AutoRefreshPeriod * 60;
			AttachIdleHandler("UpdateCurrentToDosAutomatically", UpdatePeriod);
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

&AtClient
Procedure GoToImportantUserTaskFromNotificationCenter(Id) Export
	ClosingNotification1 = New NotifyDescription("ProcessHyperlinkClickCompletion", ThisObject);
	
	FilterParameters = New Structure();
	FilterParameters.Insert("Id", Id);
	UserTaskParameters = UserTasksParameters.FindRows(FilterParameters)[0];
	
	OpenForm(UserTaskParameters.Form, UserTaskParameters.FormParameters,,,,, ClosingNotification1);
EndProcedure

&AtClient
Procedure StartToDoListUpdate(AutoUpdate = False, UpdateSilently = False)
	
	// Disable the to-do list auto-update handler if the update was triggered manually.
	// The handler will be enabled once the manual update is completed.
	If Not AutoUpdate Then
		DetachIdleHandler("UpdateCurrentToDosAutomatically");
	EndIf;
	
	TimeConsumingOperation = GenerateToDoListInBackground();
	If TimeConsumingOperation = Undefined Then
		Return;
	EndIf;

	If Not UpdateSilently Then
		Items.UserTasksPage.Visible = False;
		Items.TimeConsumingOperationPage.Visible = True;
		Items.ErrorPage.Visible   = False;
		Items.FormCustomize.Enabled = False;
		Items.FormRefresh.Enabled  = False;
		Items.NoUserTasksPage.Visible = False;
	EndIf;
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	IdleParameters.Interval = 2; // Faster than a standard interval as it is shown on the home page.
	CallbackOnCompletion = New NotifyDescription("GenerateToDoListInBackgroundCompletion", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CallbackOnCompletion, IdleParameters);
	
EndProcedure

&AtServer
Function Group(GroupName, Parent = Undefined, GroupType = "")
	
	If Parent = Undefined Then
		Parent = Items.UserTasksPage;
	EndIf;
	
	Var_Group = Items.Add(GroupName, Type("FormGroup"), Parent);
	Var_Group.Type = FormGroupType.UsualGroup;
	Var_Group.Representation = UsualGroupRepresentation.None;
	
	If GroupType = "SectionTitle" Then
		Var_Group.Group = ChildFormItemsGroup.AlwaysHorizontal;
	Else
		Var_Group.Group = ChildFormItemsGroup.Vertical;
	EndIf;
	
	Var_Group.ShowTitle = False;
	
	Return Var_Group;
	
EndFunction

&AtServer
Procedure NewUserTask(ToDoItem, Var_Group, UserTaskVisibleEnabled)
	
	UserTaskTitle = ToDoItem.Presentation + ?(ToDoItem.Count <> 0," (" + ToDoItem.Count + ")", "");
	
	Item = Items.Add(ToDoItem.Id, Type("FormDecoration"), Var_Group); // FormFieldExtensionForALabelField
	Item.Type = FormDecorationType.Label;
	Item.HorizontalAlign = ItemHorizontalLocation.Left;
	Item.Title = UserTaskTitle;
	Item.Visible = (UserTaskVisibleEnabled And ToDoItem.HasToDoItems);
	Item.AutoMaxWidth = False;
	Item.Hyperlink = ValueIsFilled(ToDoItem.Form);
	Item.SetAction("Click", "Attachable_ProcessHyperlinkClick");
	
	If ToDoItem.Important Then
		Item.TextColor = StyleColors.OverdueDataColor;
	EndIf;
	
	If ValueIsFilled(ToDoItem.ToolTip) Then
		ToolTip                    = New FormattedString(ToDoItem.ToolTip);
		Item.ToolTip            = ToolTip;
		Item.ToolTipRepresentation = ToolTipRepresentation.Button;
	EndIf;
	
EndProcedure

&AtServer
Procedure CreateCaption(ToDoItem, Var_Group, SectionCollapsed)
	
	// Create an icon for the section show/hide button.
	Item = Items.Add("Picture" + ToDoItem.OwnerID, Type("FormDecoration"), Var_Group); // FormFieldExtensionForALabelField
	Item.Type = FormDecorationType.Picture;
	Item.Hyperlink = True;
	
	If SectionCollapsed = True Then
		If ToDoItem.HasToDoItems And ToDoItem.Important Then
			Item.Picture = PictureLib.RedRightArrow;
		Else
			Item.Picture = PictureLib.RightArrow;
		EndIf;
	Else
		Item.Picture = PictureLib.DownArrow;
	EndIf;
	
	Item.PictureSize = PictureSize.AutoSize;
	Item.Width      = 2;
	Item.Height      = 1;
	Item.SetAction("Click", "Attachable_ProcessPictureClick");
	Item.ToolTip = NStr("en = 'Expand or collapse the section.';");
	
	// Create a section title.
	Item = Items.Add("Title" + ToDoItem.OwnerID, Type("FormDecoration"), Var_Group);
	Item.Type = FormDecorationType.Label;
	Item.HorizontalAlign = ItemHorizontalLocation.Left;
	Item.Title  = ToDoItem.SectionPresentation;
	Item.Font = StyleFonts.ToDoListSectionTitleFont;
	
EndProcedure

&AtServer
Procedure NewChildUserTask(ToDoItem)
	
	If Not ToDoItem.HasToDoItems Then
		Return;
	EndIf;
	
	ItemUserTaskOwner = Items.Find(ToDoItem.OwnerID);
	If ItemUserTaskOwner = Undefined Then
		Return;
	EndIf;
	ItemUserTaskOwner.ToolTipRepresentation           = ToolTipRepresentation.ShowBottom;
	ItemUserTaskOwner.ExtendedTooltip.Font     = StyleFonts.ToDoListChildToDoTitle;
	ItemUserTaskOwner.ExtendedTooltip.HorizontalStretch = True;
	
	SubordinateUserTaskTitle = SubordinateUserTaskTitle(ItemUserTaskOwner.ExtendedTooltip.Title, ToDoItem);
	
	ItemUserTaskOwner.ExtendedTooltip.Title = SubordinateUserTaskTitle;
	ItemUserTaskOwner.ExtendedTooltip.SetAction("URLProcessing", "Attachable_URLClickProcessing");
	ItemUserTaskOwner.ExtendedTooltip.AutoMaxWidth = False;
	
	// Turning on the indicator of important to-do items.
	If ToDoItem.HasToDoItems
		And ToDoItem.Important
		And ItemUserTaskOwner.Visible Then
		
		SectionID = StrReplace(ItemUserTaskOwner.Parent.Name, "Group", "");
		SectionsWithImportantUserTasks.Insert(SectionID, Not ItemUserTaskOwner.Parent.Visible);
	EndIf;
	
EndProcedure

&AtServer
Function SubordinateUserTaskTitle(CurrentTitle, ToDoItem)
	
	CurrentEmptyTitle = Not ValueIsFilled(CurrentTitle);
	UserTaskTitle = ToDoItem.Presentation + ?(ToDoItem.Count <> 0," (" + ToDoItem.Count + ")", "");
	RowUserTaskTitle    = UserTaskTitle;
	If ToDoItem.Important Then
		UserTaskColor        = StyleColors.OverdueDataColor;
	Else
		UserTaskColor        = StyleColors.ToDoListTitleColor;
	EndIf;
	
	FormattedStringWrap = New FormattedString(Chars.LF);
	FormattedStringIndent  = New FormattedString(Chars.NBSp+Chars.NBSp+Chars.NBSp);
	
	If ToDoItem.Important Then
		If ValueIsFilled(ToDoItem.Form) Then
			UserTaskTitleFormattedString = New FormattedString(
			                                           RowUserTaskTitle,,
			                                           UserTaskColor,,
			                                           ToDoItem.Id);
		Else
			UserTaskTitleFormattedString = New FormattedString(
			                                           RowUserTaskTitle,,
			                                           UserTaskColor);
		EndIf;
	Else
		If ValueIsFilled(ToDoItem.Form) Then
			UserTaskTitleFormattedString = New FormattedString(
			                                           RowUserTaskTitle,,,,
			                                           ToDoItem.Id);
		Else
			UserTaskTitleFormattedString = New FormattedString(RowUserTaskTitle,,UserTaskColor);
		EndIf;
	EndIf;
	
	If CurrentEmptyTitle Then
		Return New FormattedString(FormattedStringIndent, UserTaskTitleFormattedString);
	Else
		Return New FormattedString(CurrentTitle, FormattedStringWrap, FormattedStringIndent, UserTaskTitleFormattedString);
	EndIf;
	
EndFunction

&AtServer
Procedure FillUserTaskParameters(ToDoItem)
	
	FillPropertyValues(UserTasksParameters.Add(), ToDoItem);
	
EndProcedure

&AtServer
Procedure LoadAutoRefreshSettings()
	
	AutoRefreshSettings = Common.CommonSettingsStorageLoad("ToDoList", "AutoRefreshSettings");
	
	If AutoRefreshSettings = Undefined Then
		AutoRefreshSettings = New Structure;
	EndIf;
	
EndProcedure

&AtClient
Procedure ApplyToDoListPanel(ApplySettings, AdditionalParameters) Export
	If ApplySettings = True Then
		OutputNotifications = False;
		StartToDoListUpdate();
	EndIf;
EndProcedure

&AtServer
Procedure MoveSection(RowSection)
	
	TagName = "CommonGroup" + RowSection.Id;
	ItemToMove = Items.Find(TagName);
	If ItemToMove = Undefined Then
		Return;
	EndIf;
	Items.Move(ItemToMove, ItemToMove.Parent);
	
EndProcedure

&AtServer
Procedure MoveUserTask(RowUserTask)
	
	ItemToMove = Items.Find(RowUserTask.Id);
	If ItemToMove = Undefined Then
		Return;
	EndIf;
	Items.Move(ItemToMove, ItemToMove.Parent);
	
EndProcedure

&AtServer
Procedure SaveCollapsedSections(CollapsedSections)
	
	ViewSettings = Common.CommonSettingsStorageLoad("ToDoList", "ViewSettings");
	
	If TypeOf(ViewSettings) <> Type("Structure") Then
		ViewSettings = New Structure;
	EndIf;
	
	ViewSettings.Insert("CollapsedSections", CollapsedSections);
	Common.CommonSettingsStorageSave("ToDoList", "ViewSettings", ViewSettings);
	
EndProcedure

&AtServer
Function CollapsedSections()
	
	ViewSettings = Common.CommonSettingsStorageLoad("ToDoList", "ViewSettings");
	If ViewSettings <> Undefined And ViewSettings.Property("CollapsedSections") Then
		CollapsedSections = ViewSettings.CollapsedSections;
	Else
		CollapsedSections = New Map;
	EndIf;
	
	Return CollapsedSections;
	
EndFunction

&AtServer
Procedure FillCollapsedGroups()
	
	ViewSettings = Common.CommonSettingsStorageLoad("ToDoList", "ViewSettings");
	If ViewSettings = Undefined Or Not ViewSettings.Property("CollapsedSections") Then
		Return;
	EndIf;
	
	PictureRightArrow = PictureLib.RightArrow;
	PictureRightArrowRed = PictureLib.RedRightArrow;
	CollapsedSections = New Map;
	For Each MapRow In ViewSettings.CollapsedSections Do
		
		FormItem = Items.Find("Picture" + MapRow.Key);
		If FormItem = Undefined Then
			Continue;
		EndIf;
		
		If FormItem.Picture = PictureRightArrow
			Or FormItem.Picture = PictureRightArrowRed Then
			CollapsedSections.Insert(MapRow.Key, True);
		Else
			CollapsedSections.Insert(MapRow.Key, False);
		EndIf;
		
	EndDo;
	
	If CollapsedSections.Count() = 0 Then
		Return;
	EndIf;
	
	SaveCollapsedSections(CollapsedSections);
	
EndProcedure

&AtServer
Procedure SwitchPicture(TagName)
	
	SectionGroupName1 = StrReplace(TagName, "Picture", "");
	Item = Items[TagName];
	
	Collapsed = False;
	If Item.Picture = PictureLib.DownArrow Then
		If SectionsWithImportantUserTasks.Property(SectionGroupName1) Then
			Item.Picture = PictureLib.RedRightArrow;
		Else
			Item.Picture = PictureLib.RightArrow;
		EndIf;
		Items["Group" + SectionGroupName1].Visible = False;
		Collapsed = True;
	Else
		Item.Picture = PictureLib.DownArrow;
		Items["Group" + SectionGroupName1].Visible = True;
	EndIf;
	
	CollapsedSections = CollapsedSections();
	CollapsedSections.Insert(SectionGroupName1, Collapsed);
	
	SaveCollapsedSections(CollapsedSections);
	
EndProcedure

&AtServer
Procedure SetPictureOfSectionsWithImportantToDos()
	
	Picture = PictureLib.RedRightArrow;
	For Each SectionWithImportantToDos In SectionsWithImportantUserTasks Do
		If SectionWithImportantToDos.Value <> True Then
			Continue; // Section not collapsed.
		EndIf;
		IconName = "Picture" + SectionWithImportantToDos.Key;
		ItemPicture1 = Items[IconName];
		ItemPicture1.Picture = Picture;
	EndDo;
	
EndProcedure

&AtClient
Procedure ProcessHyperlinkClickCompletion(Result, AdditionalParameters) Export
	OutputNotifications = False;
	StartToDoListUpdate(, True);
EndProcedure

&AtServer
Procedure AddToDoItemsWithNotification(ViewSettings, ToDoList)
	
	ToDoItemsWithNotification.Clear();
	
	FilterParameters = New Structure;
	FilterParameters.Insert("OutputInNotifications", True);
	
	If ViewSettings.UserTasksTree.Columns.Find("OutputInNotifications") <> Undefined Then
		FoundRows = ViewSettings.UserTasksTree.Rows.FindRows(FilterParameters, True);
		For Each String In FoundRows Do
			ToDoItem = ToDoList.Find(String.Id, "Id");
			
			If ToDoItem = Undefined Then
				Continue;
			EndIf;
			
			If ToDoItem <> Undefined And Not ToDoItem.HasToDoItems Then
				Continue;
			EndIf;
			
			If ViewSettings.UserTasksVisible[String.Id] = False Then
				Continue;
			EndIf;
			
			If ToDoItem.Count <> 0 Then
				Addition = " (" + ToDoItem.Count + ")";
			Else
				Addition = "";
			EndIf;
			
			ToDoWithNotification = ToDoItemsWithNotification.Add();
			ToDoWithNotification.Id = String.Id;
			ToDoWithNotification.LongDesc = String.Presentation + Addition;
		EndDo;
	EndIf;
	
	FoundRows = ToDoList.FindRows(FilterParameters);
	For Each String In FoundRows Do
		If ViewSettings.UserTasksVisible[String.Id] <> Undefined Then
			Continue;
		EndIf;
		
		If Not String.HasToDoItems Then
			Continue;
		EndIf;
		
		If String.Count <> 0 Then
			Addition = " (" + String.Count + ")";
		Else
			Addition = "";
		EndIf;
		
		ToDoWithNotification = ToDoItemsWithNotification.Add();
		ToDoWithNotification.Id = String.Id;
		ToDoWithNotification.LongDesc = String.Presentation + Addition;
	EndDo;
	
EndProcedure

&AtClient
Procedure GenerateErrorReportClick(Item)
	StandardSubsystemsClient.ShowErrorReport(ErrorReport);
EndProcedure

#EndRegion
