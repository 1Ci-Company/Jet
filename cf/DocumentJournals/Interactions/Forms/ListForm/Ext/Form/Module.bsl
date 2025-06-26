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

&AtClient
Var ChoiceContext;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("ChoiceMode") And Parameters.ChoiceMode = True Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		Items.List.ChoiceMode = True;
	EndIf;
	
	FileInfobase = Common.FileInfobase();
	DataSeparationEnabled         = Common.DataSeparationEnabled();
	
	HyperlinkColor = StyleColors.HyperlinkColor;
	
	Interactions.InitializeInteractionsListForm(ThisObject, Parameters);
	DetermineAvailabilityFullTextSearch();
	FoldersDeletionMarkRight = AccessRight("Update", Metadata.Catalogs.EmailMessageFolders);
	
	CommonClientServer.SetDynamicListFilterItem(Tabs, "Owner", Users.CurrentUser(),,, True);
	
	AddToNavigationPanel();
	Interactions.FillStatusSubmenu(Items.ListStatus, ThisObject);
	Interactions.FillSubmenuByInteractionType(Items.InteractionTypeList, ThisObject);
	
	For Each SubjectType In Metadata.InformationRegisters.InteractionsFolderSubjects.Resources.SubjectOf.Type.Types() Do
		If OnlyEmail 
			And (SubjectType = Type("DocumentRef.Meeting") Or SubjectType = Type("DocumentRef.PhoneCall") 
			Or SubjectType = Type("DocumentRef.PlannedInteraction") Or SubjectType = Type("DocumentRef.SMSMessage")) Then
			Continue;
		EndIf;
		SubjectTypeChoiceList.Add(Metadata.FindByType(SubjectType).FullName(), String(SubjectType));
	EndDo;
	
	InteractionType = ?(OnlyEmail, "AllEmails","All");
	Status = "All";
	
	CurrentNavigationPanelName = CommonClientServer.StructureProperty(Parameters, "CurrentNavigationPanelName");
	CurrentRef = CommonClientServer.StructureProperty(Parameters, "CurrentRow");
	If ValueIsFilled(CurrentRef) Then
		PrepareFormSettingsForCurrentRefOutput(CurrentRef);
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	PlacementParameters = AttachableCommands.PlacementParameters();
	PlacementParameters.Insert("CommandBar", Items.NavigationPanelListGroup.ChildItems.NavigationOptionCommandBar);
	AttachableCommands.OnCreateAtServer(ThisObject, PlacementParameters);
	// End StandardSubsystems.AttachableCommands
	
	Interactions.FillListOfDocumentsAvailableForCreation(DocumentsAvailableForCreation);
	UnsafeContentDisplayInEmailsProhibited = Interactions.UnsafeContentDisplayInEmailsProhibited();
	
	CheckEmailsSendingStatusAtServer();
	GenerateImportantSubjectsOnlyDecoration();
	GenerateImportantContactsOnlyDecoration();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If DataSeparationEnabled 
		And Not SendReceiveEmailInProgress Then
		SendReceiveUserMailClient();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	If Parameters.Property("CurrentNavigationPanelName") Then
		Settings.Delete("CurrentNavigationPanelName");
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If IsBlankString(CurrentNavigationPanelName) Or Items.Find(CurrentNavigationPanelName) = Undefined Then
		CurrentNavigationPanelName = "EmailSubjectPage";
	ElsIf CurrentNavigationPanelName = "PropertiesPage" Then
		If AddlAttributesPropertiesTable.FindRows(New 
				Structure("AddlAttributeInfo",CurrentPropertyOfNavigationPanel)).Count() = 0 Then
			CurrentNavigationPanelName = "EmailSubjectPage";
		EndIf;
	EndIf;
	
	Items.NavigationPanelPages.CurrentPage = Items[CurrentNavigationPanelName];
	
	Status = Settings.Get("Status");
	If Status <> Undefined Then
		Settings.Delete("Status");
	EndIf;
	If Not UseReviewedFlag Then
		Status = "All";
	EndIf;
	If ValueIsFilled(Status) Then
		OnChangeStatusServer(False);
	EndIf;

	EmployeeResponsible = Settings.Get("EmployeeResponsible");
	If EmployeeResponsible <> Undefined Then
		OnChangeEmployeeResponsibleServer(False);
		Settings.Delete("EmployeeResponsible");
	EndIf;
	
	Interactions.OnImportInteractionsTypeFromSettings(ThisObject, Settings);
	
	OnChangeTypeServer(False);
	UpdateNavigationPanelAtServer();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_InteractionsTabs") Then
		If Items.NavigationPanelPages.CurrentPage = Items.TabsPage Then
			Items.Tabs.Refresh();
			ProcessNavigationPanelRowActivation();
		EndIf;
	ElsIf Upper(EventName) = Upper("Write_EmailMessageFolders") 
		Or Upper(EventName) = Upper("MessageProcessingRulesApplied")
		Or Upper(EventName) = Upper("SendAndReceiveEmailDone") Then
		
		If Items.NavigationPanelPages.CurrentPage = Items.FoldersPage Then
			RefreshNavigationPanel();
			RestoreExpandedTreeNodes();
		EndIf;
		
		If Upper(EventName) = Upper("SendAndReceiveEmailDone") Then

			If DataSeparationEnabled Then
				AttachIdleHandler("CheckWhetherYouNeedToSendReceiveMail", 150, True);
			EndIf;
		
		EndIf;
		
	ElsIf Upper(EventName) = Upper("InteractionSubjectEdit") Then
		If Items.NavigationPanelPages.CurrentPage = Items.EmailSubjectPage Then
			RefreshNavigationPanel();
		EndIf;
	EndIf;
	
EndProcedure 

&AtClient
Procedure OnOpen(Cancel)
	
	If IsBlankString(CurrentNavigationPanelName) 
		Or IsBlankString(Status) 
		Or IsBlankString(InteractionType)  Then
		
		SetInitialValuesOnOpen();
		
	EndIf;
	
	RestoreExpandedTreeNodes();
	
	If DataSeparationEnabled Then
		
		SendReceiveUserMailClient();
		
	Else
		
		AttachIdleHandler("CheckEmailsSendingStatus", 60, True);
		
	EndIf;
	
#If MobileClient Then
		
		Items.ListStatus.Type            = FormGroupType.ButtonGroup;
		Items.InteractionTypeList.Type = FormGroupType.ButtonGroup;
		
#EndIf
	
EndProcedure

&AtServer
Procedure SetInitialValuesOnOpen()
	
	Items.NavigationPanelPages.CurrentPage = Items.EmailSubjectPage;
	Status = "All";
	InteractionType = "All";
	OnChangeStatusServer(False);
	OnChangeTypeServer(False);
	UpdateNavigationPanelAtServer();

EndProcedure

&AtClient
Procedure NavigationProcessing(NavigationObject, StandardProcessing)
	If Not ValueIsFilled(NavigationObject) Or NavigationObject = Items.List.CurrentRow Then
		Return;
	EndIf;
	
	NavigationProcessingAtServer(NavigationObject);
	RestoreExpandedTreeNodes();
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceContext = "EmployeeResponsibleExecute" Then
		
		If ValueSelected <> Undefined Then
			SetEmployeeResponsible(ValueSelected, Undefined);
		EndIf;
		
		RestoreExpandedTreeNodes();
		
	ElsIf ChoiceContext = "EmployeeResponsibleList" Then
		
		If ValueSelected <> Undefined Then
			SetEmployeeResponsible(ValueSelected, Items.List.SelectedRows);
		EndIf;
		
		RestoreExpandedTreeNodes();
		
	ElsIf ChoiceContext = "SubjectExecuteSubjectType" Then
		
		If ValueSelected = Undefined Then
			Return;
		EndIf;
		
		ChoiceContext = "SubjectOfExecute";
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		
		OpenForm(ValueSelected + ".ChoiceForm", FormParameters, ThisObject);
		
		Return;
		
	ElsIf ChoiceContext = "SubjectListSubjectType" Then
		
		If ValueSelected = Undefined Then
			Return;
		EndIf;
		
		ChoiceContext = "SubjectList";
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		
		OpenForm(ValueSelected + ".ChoiceForm", FormParameters, ThisObject);
		
		Return;
		
	ElsIf ChoiceContext = "SubjectOfExecute" Then
		
		If ValueSelected <> Undefined Then
			SetSubject(ValueSelected, Undefined);
		EndIf;
		
		RestoreExpandedTreeNodes();
		
	ElsIf ChoiceContext = "SubjectList" Then
		
		If ValueSelected <> Undefined Then
			SetSubject(ValueSelected, Items.List.SelectedRows);
		EndIf;
		
		RestoreExpandedTreeNodes();
		
	ElsIf ChoiceContext = "MoveToFolder" Then
		
		If ValueSelected <> Undefined Then
			
			CurrentItemName = CurrentItem.Name;
			FoldersCurrentData = Items.Folders.CurrentData;
			
			If StrStartsWith(CurrentItemName, "List") Then
				ExecuteTransferToEmailsArrayFolder(Items[CurrentItemName].SelectedRows, ValueSelected);
			Else
				SetFolderParent(FoldersCurrentData.Value, ValueSelected);
			EndIf;
			
			RestoreExpandedTreeNodes();
			
		EndIf;
		
	EndIf;
	
	ChoiceContext = Undefined;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure NavigationPanelOnActivateRow(Item)
	
	If Item.Name = "Subjects" 
		And Items.NavigationPanelPages.CurrentPage <> Items.EmailSubjectPage Then
		Return;
	ElsIf Item.Name = "Contacts" 
		And Items.NavigationPanelPages.CurrentPage <> Items.ContactPage Then
		Return;
	ElsIf Item.Name = "Tabs" 
		And Items.NavigationPanelPages.CurrentPage <> Items.TabsPage Then
		Return;
	ElsIf Item.Name = "Properties" 
		And Items.NavigationPanelPages.CurrentPage <> Items.PropertiesPage Then
		Return;
	ElsIf Item.Name = "Folders" 
		And Items.NavigationPanelPages.CurrentPage <> Items.FoldersPage Then
		Return;
	ElsIf Item.Name = "Categories" 
		And Items.NavigationPanelPages.CurrentPage <> Items.CategoriesPage Then
		Return;
	EndIf;
	
	If Item.Name = "Folders" Then
		CurrentData = Items.Folders.CurrentData;
		If CurrentData = Undefined Then 
			Return
		EndIf;
			
		Items.FoldersContextMenuDelete.Enabled = Not (TypeOf(CurrentData.Value) = Type("CatalogRef.EmailAccounts")
		                                                       Or CurrentData.HasEditPermission = 0 
		                                                       Or CurrentData.PredefinedFolder);
	EndIf;
	
	If DoNotTestNavigationPanelActivation Then
		DoNotTestNavigationPanelActivation = False;
	Else
		AttachIdleHandler("ProcessNavigationPanelRowActivation", 0.2, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure EmployeeResponsibleOnChange(Item)
	
	OnChangeEmployeeResponsibleServer(True);
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure InteractionTypeOnChange(Item)
	
	OnChangeTypeServer();
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure ListOnChange(Item)
	
	RefreshNavigationPanel();
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure PersonalSettings(Command)
	
	OpenForm("DocumentJournal.Interactions.Form.EmailOperationSettings", , ThisObject);
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Items.List.CurrentData = Undefined And DisplayReadingPane Then
		If Items.PagesPreview.CurrentPage <> Items.PreviewPlainTextPage Then
			Items.PagesPreview.CurrentPage = Items.PreviewPlainTextPage;
		EndIf;
		Preview = "";
		HTMLPreview = "<HTML><BODY></BODY></HTML>";
		InteractionPreviewGeneratedFor = Undefined;
		
	Else
		
		If CorrectChoice(Item.Name,True) 
			And InteractionPreviewGeneratedFor <> Items.List.CurrentData.Ref Then
			
			If Items.List.SelectedRows.Count() = 1 Then
				
				AttachIdleHandler("ProcessListRowActivation",0.1,True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Items.List.ChoiceMode Then
		StandardProcessing = False;
		NotifyChoice(RowSelected);
	EndIf;
	
EndProcedure

&AtClient
Procedure FoldersSelection(Item, RowSelected, Field, StandardProcessing)
	
#If Not MobileClient Then
		StandardProcessing = False;
		CurrentData = Item.CurrentData;
		ShowValue(, CurrentData.Value);
#EndIf
	
EndProcedure

&AtClient
Procedure NavigationPanelContactsSelection(Item, RowSelected, Field, StandardProcessing)
	
#If Not MobileClient Then
		StandardProcessing = False;
		CurrentData = Item.CurrentData;
		If Not TypeOf(CurrentData.Contact) = Type("CatalogRef.StringContactInteractions") Then
			ShowValue( ,CurrentData.Contact);
		EndIf;
#EndIf
	
EndProcedure

&AtClient
Procedure NavigationPanelSubjectsSelection(Item, RowSelected, Field, StandardProcessing)
	
#If Not MobileClient Then
		CurrentData = Item.CurrentData;
		If CurrentData <> Undefined Then
			StandardProcessing = False;
			ShowValue( ,CurrentData.SubjectOf);
		EndIf;
#EndIf
	
EndProcedure

&AtClient
Procedure NavigationPanelSubjectsBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure NavigationPanelSubjectsBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ContactsBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ContactsBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure FoldersBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	
	CurrentData = Items.Folders.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.HasEditPermission = 0 Then
		Raise(NStr("en = 'Insufficient rights to create a folder.';"), ErrorCategory.AccessViolation);
	EndIf;
		
	ParametersStructure1 = New Structure;
	ParametersStructure1.Insert("Owner", CurrentData.Account);
	If TypeOf(CurrentData.Value) = Type("CatalogRef.EmailMessageFolders") Then
		ParametersStructure1.Insert("Parent", CurrentData.Value);
	EndIf;
	
	FormParameters = New Structure("FillingValues", ParametersStructure1);
	OpenForm("Catalog.EmailMessageFolders.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure FoldersBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
	CurrentData = Items.Folders.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(CurrentData.Value) = Type("CatalogRef.EmailAccounts")
		Or CurrentData.HasEditPermission = 0 Or CurrentData.PredefinedFolder Then
		Return;
	EndIf;
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Delete the ""%1"" folder and move all its contents to the ""Trash"" folder?';"),
			String(CurrentData.Value));
	
	AdditionalParameters = New Structure("CurrentData", CurrentData);
	OnCloseNotifyHandler = New NotifyDescription("QuestionOnFolderDeletionAfterCompletion", ThisObject, AdditionalParameters);
	ShowQueryBox(OnCloseNotifyHandler, QueryText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtServer
Function DeleteFolderServer(Val Folder)
	
	ErrorDescription = "";
	Interactions.ExecuteEmailsFolderDeletion(Folder, ErrorDescription);
	If IsBlankString(ErrorDescription) Then
		RefreshNavigationPanel();
	EndIf;
	
	Return ErrorDescription;
	
EndFunction

&AtClient
Procedure StatusOnChange(Item)
	
	OnChangeStatusServer(True);
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure InteractionTypeStatusClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure SearchStringOnChange(Item)
	
	FullTextSearchResultDetails.Clear();
	
	If SearchString <> "" Then
		
		ExecuteFullTextSearch();
		
	Else
		AdvancedSearch = False;
		CommonClientServer.SetDynamicListFilterItem(
			List, 
			"Search",
			Undefined,
			DataCompositionComparisonType.Equal,,False);
		Items.DetailsFoundByFullTextSearch.Visible = AdvancedSearch;
	EndIf;
	
EndProcedure

&AtClient
Procedure SearchStringAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceData = New ValueList;
	
	FoundItemsCount = 0;
	For Each ListItem In Items.SearchString.ChoiceList Do
		If Left(Upper(ListItem.Value), StrLen(TrimAll(Text))) = Upper(TrimAll(Text)) Then
			ChoiceData.Add(ListItem.Value);
			FoundItemsCount = FoundItemsCount + 1;
			If FoundItemsCount > 7 Then
				Break;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure 

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	InteractionsClient.ListBeforeAddRow(Item, Cancel, Copy, OnlyEmail, DocumentsAvailableForCreation);
	
EndProcedure

&AtClient
Procedure NavigationPanelTreeNodeBeforeCollapse(Item, String, Cancel)
	
	TreeName = Item.Name;
	
	If Item.CurrentRow <> Undefined Then
		RowData = Items[TreeName].RowData(String);
		If RowData <> Undefined Then
			SaveNodeStateInSettings(TreeName, RowData.Value, False);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure NavigationPanelTreeNodeBeforeExpand(Item, String, Cancel)
	
	TreeName = Item.Name;
	
	If Item.CurrentRow <> Undefined Then
		RowData = Items[TreeName].RowData(String);
		If RowData <> Undefined Then
			SaveNodeStateInSettings(TreeName, RowData.Value, True);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure HTMLPreviewOnClick(Item, EventData, StandardProcessing)
	
	InteractionsClient.HTMLFieldOnClick(Item, EventData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure WarningAboutUnsentEmailsLabelURLProcessing(Item, FormattedStringURL, StandardProcessing)

	InteractionsClient.URLProcessing(Item, FormattedStringURL, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ImportantSubjectsOnlyDecorationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	If FormattedStringURL = "ChangeImportantSubjectsOnly" Then
		
		ImportantSubjectsOnly = Not ImportantSubjectsOnly;
		FillSubjectsPanel();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportantContactsOnlyDecorationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	If FormattedStringURL = "ChangeImportantContactsOnly" Then
		
		ImportantContactsOnly = Not ImportantContactsOnly;
		FillContactsPanel();
		
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////////
// Drag-and-drop handler.

&AtClient
Procedure SubjectsDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	If (String = Undefined) Or (DragParameters.Value = Undefined) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) = Type("Array") Then
		
		For Each ArrayElement In DragParameters.Value Do
			If InteractionsClientServer.IsInteraction(ArrayElement) Then
				Return;
			EndIf;
		EndDo;
	EndIf;
	
	DragParameters.Action = DragAction.Cancel;

EndProcedure

&AtClient
Procedure SubjectsDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) = Type("Array") Then
		
		InteractionsServerCall.SetSubjectForInteractionsArray(DragParameters.Value,
			String, True);
			
	EndIf;
	
	RefreshNavigationPanel();
	
EndProcedure

&AtClient
Procedure FoldersDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	If (String = Undefined) Or (DragParameters.Value = Undefined) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	AssignmentRow = Folders.FindByID(String);
	
	If TypeOf(DragParameters.Value) = Type("Array") Then
		
		If TypeOf(AssignmentRow.Value) = Type("CatalogRef.EmailAccounts") 
			Or AssignmentRow.HasEditPermission = 0 Then
			DragParameters.Action = DragAction.Cancel;
			Return;
		EndIf;
		
		For Each ArrayElement In DragParameters.Value Do
			If Not InteractionsClient.IsEmail(ArrayElement) Then
				Continue;
			EndIf;
			
			DragParameters.Action = DragAction.Cancel;
			RowData = Items.List.RowData(ArrayElement);
			If RowData.Account = AssignmentRow.Account Then
				DragParameters.Action = DragAction.Move;
				Return;
			EndIf;
		EndDo;
		DragParameters.Action = DragAction.Cancel;
		
	ElsIf TypeOf(DragParameters.Value) = Type("Number") Then
		
		RowDrag = Folders.FindByID(DragParameters.Value);
		If RowDrag.Account <> AssignmentRow.Account Then
			DragParameters.Action = DragAction.Cancel;
			Return;
		EndIf;
		
		ParentRow = AssignmentRow;
		While TypeOf(ParentRow.Value) <> Type("CatalogRef.EmailAccounts") Do
			If RowDrag = ParentRow Then
				DragParameters.Action = DragAction.Cancel;
				Return;
			EndIf;
			ParentRow = ParentRow.GetParent();
		EndDo;
		
	Else
		
		DragParameters.Action = DragAction.Cancel;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FoldersDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	AssignmentRow = Folders.FindByID(String);
	
	If TypeOf(DragParameters.Value) = Type("Array") Then
		ExecuteTransferToEmailsArrayFolder(DragParameters.Value, AssignmentRow.Value);
	ElsIf TypeOf(DragParameters.Value) = Type("Number") Then
		DragRowData = Folders.FindByID(DragParameters.Value);
		If Not DragRowData.GetParent() = AssignmentRow Then
			SetFolderParent(DragRowData.Value,
			                        ?(TypeOf(AssignmentRow.Value) = Type("CatalogRef.EmailAccounts"),
			                        PredefinedValue("Catalog.EmailMessageFolders.EmptyRef"),
			                        AssignmentRow.Value));
		EndIf;
			
	EndIf;
	
	RefreshNavigationPanel(AssignmentRow.Value);
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure FoldersDragStart(Item, DragParameters, Perform)
	
	If DragParameters.Value = Undefined Then
		Return;
	EndIf;
	
	RowData = Folders.FindByID(DragParameters.Value);
	If TypeOf(RowData.Value) = Type("CatalogRef.EmailAccounts") 
		Or RowData.PredefinedFolder Or RowData.HasEditPermission = 0 Then
		Perform = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	ListFileNames = New ValueList;
	
	If TypeOf(DragParameters.Value) = Type("File") 
		And DragParameters.Value.IsFile() Then
		
		ListFileNames.Add(DragParameters.Value.FullName,DragParameters.Value.Name);
		
	ElsIf TypeOf(DragParameters.Value) = Type("Array") Then
		
		If DragParameters.Value.Count() >= 1 
			And TypeOf(DragParameters.Value[0]) = Type("File") Then
			
			For Each ReceivedFile1 In DragParameters.Value Do
				If TypeOf(ReceivedFile1) = Type("File") And ReceivedFile1.IsFile() Then
					ListFileNames.Add(ReceivedFile1.FullName,ReceivedFile1.Name);
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	FormParameters = New Structure("Attachments", ListFileNames);
	OpenForm("Document.OutgoingEmail.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ListDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Refresh(Command)
	
	UpdateAtServer();
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure SendReceiveEmailExecute(Command)
	
	ClearMessages();	
	If Not DataSeparationEnabled And Not FileInfobase Then
		Return;
	EndIf;
	
	If SendReceiveEmailInProgress Then
		MessageText = NStr("en = 'Mail synchronization in progress.';");
		CommonClient.MessageToUser(MessageText);
		Return;
	EndIf;
	
	If DateOfPreviousEmailReceiptSending + 15 > CommonClient.SessionDate() Then
		MessageText = NStr("en = 'It''s been less than 15 seconds since the last mail sync. Try again later.';");
		CommonClient.MessageToUser(MessageText);
		Return;
	EndIf;
	
	If DateOfPreviousExecutionOfSendReceiveEmailCommand + 15 > CommonClient.SessionDate() Then
		MessageText = NStr("en = 'It''s been less than 15 seconds since you run mail sync. Try again later.';");
		CommonClient.MessageToUser(MessageText);
		Return;
	EndIf;
	
	DateOfPreviousExecutionOfSendReceiveEmailCommand = CommonClient.SessionDate();
	
	SendReceiveUserMailClient(True);
	
EndProcedure

&AtClient
Procedure Reply(Command)
	
	If CorrectChoice(Items.List.Name, True) Then
		CurrentInteraction = Items.List.CurrentData.Ref;
		If TypeOf(CurrentInteraction) <> Type("DocumentRef.IncomingEmail") Then
			ShowMessageBox(, NStr("en = 'You can use ""Reply"" only for incoming messages.';"));
			Return;
		EndIf;
	Else
		Return;
	EndIf;
	
	Basis = New Structure("Basis,Command",CurrentInteraction, "Reply");
	OpeningParameters = New Structure("Basis", Basis);
	OpenForm("Document.OutgoingEmail.ObjectForm", OpeningParameters);
	
EndProcedure

&AtClient
Procedure ReplyToAll(Command)
	
	If CorrectChoice(Items.List.Name, True) Then
		CurrentInteraction = Items.List.CurrentData.Ref;
		If TypeOf(CurrentInteraction) <> Type("DocumentRef.IncomingEmail") Then
			ShowMessageBox(, NStr("en = 'You can use ""Reply all"" only for incoming messages.';"));
			Return;
		EndIf;
	Else
		Return;
	EndIf;
	
	Basis = New Structure("Basis,Command",CurrentInteraction, "ReplyToAll");
	OpeningParameters = New Structure("Basis", Basis);
	OpenForm("Document.OutgoingEmail.ObjectForm", OpeningParameters);
	
EndProcedure

&AtClient
Procedure ForwardMail(Command)
	
	If CorrectChoice(Items.List.Name, True) Then
		CurrentInteraction = Items.List.CurrentData.Ref;
		If TypeOf(CurrentInteraction) <> Type("DocumentRef.OutgoingEmail") 
			And TypeOf(CurrentInteraction) <> Type("DocumentRef.IncomingEmail") Then
			ShowMessageBox(, NStr("en = 'You can use ""Forward"" only for mail messages.';"));
			Return;
		EndIf;
	Else
		Return;
	EndIf;
	
	Basis = New Structure("Basis,Command", CurrentInteraction, "ForwardMail");
	OpeningParameters = New Structure("Basis", Basis);
	OpenForm("Document.OutgoingEmail.ObjectForm", OpeningParameters);

EndProcedure

&AtClient
Procedure SwitchNavigationPanel(Command)
	
	SwitchNavigationPanelServer(Command.Name);
	RestoreExpandedTreeNodes();
	
EndProcedure 

&AtClient
Procedure SetNavigationMethodByContact(Command)
	
	SwitchNavigationPanel(Command);
	
EndProcedure

&AtClient
Procedure SetNavigationMethodBySubject(Command)
	
	SwitchNavigationPanel(Command);
	
EndProcedure

&AtClient
Procedure SetNavigationMethodByTabs(Command)
	
	SwitchNavigationPanel(Command);
	
EndProcedure

&AtClient
Procedure SetNavigationMethodByFolders(Command)
	
	SwitchNavigationPanel(Command);
	
EndProcedure

&AtClient
Procedure EmployeeResponsibleExecute(Command)
	
	ChoiceContext = "EmployeeResponsibleExecute";
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode",True);	
	OpenForm("Catalog.Users.ListForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure EmployeeResponsibleList(Command)
	
	CurrentItemName = Items.List.Name;
	If StrStartsWith(CurrentItemName, "List") And Not CorrectChoice(CurrentItemName) Then
		Return;
	EndIf;
	
	ChoiceContext = "EmployeeResponsibleList";
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode",True);	
	OpenForm("Catalog.Users.ListForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ReviewedExecute(Command)
	
	SetReviewedFlag(Undefined,True);
	RestoreExpandedTreeNodes();

EndProcedure

&AtClient
Procedure MarkAsReviewed(Command)
	
	ReviewedExecuteList(True);
	
EndProcedure

&AtClient
Procedure InteractionsBySubject(Command)
	
	CurrentItemName = Items.List.Name;
	If Not CorrectChoice(CurrentItemName,True) Then
		Return;
	EndIf;
	
	SubjectOf = Items[CurrentItemName].CurrentData.SubjectOf;
	
	If InteractionsClientServer.IsSubject(SubjectOf) Then
		
		FilterStructure1 = New Structure;
		FilterStructure1.Insert("SubjectOf", SubjectOf);
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("InteractionType", "SubjectOf");
		
		FormParameters = New Structure;
		FormParameters.Insert("Filter", FilterStructure1);
		FormParameters.Insert("AdditionalParameters", AdditionalParameters);
		
	ElsIf InteractionsClientServer.IsInteraction(SubjectOf) Then
		
		FilterStructure1 = New Structure;
		FilterStructure1.Insert("SubjectOf", SubjectOf);
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("InteractionType", "Interaction");
		
		FormParameters = New Structure;
		FormParameters.Insert("Filter", FilterStructure1);
		FormParameters.Insert("AdditionalParameters", AdditionalParameters);
		
	Else
		Return;
	EndIf;

	OpenForm(
		"DocumentJournal.Interactions.Form.ParametricListForm",
		FormParameters,
		ThisObject);
	
EndProcedure

&AtClient
Procedure ClearReviewedFlag(Command)
	
	ReviewedExecuteList(False);
	
EndProcedure

&AtClient
Procedure ReviewedExecuteList(FlagValues)
	
	CurrentItemName = Items.List.Name;
	If Not CorrectChoice(CurrentItemName) Then
		Return;
	EndIf;
	
	SetReviewedFlag(Items[CurrentItemName].SelectedRows, FlagValues);
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure SubjectOfExecute(Command)
	
	ChoiceContext = "SubjectExecuteSubjectType";
	OpenForm("DocumentJournal.Interactions.Form.SelectSubjectType",,ThisObject);

EndProcedure

&AtClient
Procedure SubjectList(Command)
	
	CurrentItemName = Items.List.Name;
	If Not CorrectChoice(CurrentItemName) Then
		Return;
	EndIf;
	
	ChoiceContext = "SubjectListSubjectType";
	OpenForm("DocumentJournal.Interactions.Form.SelectSubjectType",,ThisObject);
	
EndProcedure

&AtClient
Procedure AddToTabs(Command)
	
	CurrentItemName = CurrentItem.Name;
	If StrStartsWith(CurrentItemName, "List") And Not CorrectChoice(CurrentItemName) Then
		ShowMessageBox(, NStr("en = 'Select an item you want to add to bookmarks.';"));
		Return;
	EndIf;
	
	ItemToAdd1 = Undefined;
	If StrStartsWith(CurrentItemName, "List") Then
		ItemToAdd1 = Items[CurrentItemName].SelectedRows;
	ElsIf CurrentItemName = "Properties" Or CurrentItemName = "Categories" Or CurrentItemName = "Folders" Then
		CurrentData = Items[CurrentItemName].CurrentData;
		If CurrentData <> Undefined Then
			ItemToAdd1 = New Structure("Value", CurrentData.Value);
		EndIf;
	ElsIf CurrentItemName = "NavigationPanelSubjects" Then
		CurrentData = Items.NavigationPanelSubjects.CurrentData;
		If CurrentData <> Undefined Then
			ItemToAdd1 = New Structure("Value", CurrentData.SubjectOf);
		EndIf;
	ElsIf CurrentItemName = "NavigationPanelContacts" Then
		CurrentData = Items.NavigationPanelContacts.CurrentData;
		If CurrentData <> Undefined Then
			ItemToAdd1 = New Structure("Value", CurrentData.Contact);
		EndIf;
	Else
		CurrentData = Items[CurrentItemName].CurrentData;
		If CurrentData <> Undefined Then
			ItemToAdd1 = New Structure("Value,TypeDescription", CurrentData.Value, CurrentData.TypeDescription);
		EndIf;
	EndIf;
	
	If ItemToAdd1 = Undefined Then
		ShowMessageBox(, NStr("en = 'Select an item you want to add to bookmarks.';"));
		Return;
	EndIf;
	
	Result = AddToTabsServer(ItemToAdd1, CurrentItemName);
	If Not Result.ItemAdded Then
		ShowMessageBox(, Result.ErrorMessageText1);
		Return;
	EndIf;
	ShowUserNotification(NStr("en = 'Items added to bookmarks:';"),
		Result.ItemURL, Result.ItemPresentation, PictureLib.DialogInformation);
	
EndProcedure

&AtClient
Procedure DeferReviewExecute(Command)
	
	CurrentItemName = CurrentItem.Name;
	If StrStartsWith(CurrentItemName, "List") And Not CorrectChoice(CurrentItemName) Then
		Return;
	EndIf;
	
	ProcessingDate = CommonClient.SessionDate();
	
	AdditionalParameters = New Structure("CurrentItemName", Undefined);
	OnCloseNotifyHandler = New NotifyDescription("ProcessingDateChoiceOnCompletion", ThisObject, AdditionalParameters);
	ShowInputDate(OnCloseNotifyHandler, ProcessingDate, NStr("en = 'Snooze till';"), DateFractions.DateTime);
	
EndProcedure

&AtClient
Procedure DeferListReview(Command)
	
	CurrentItemName = Items.List.Name;
	If Not CorrectChoice(CurrentItemName) Then
		Return;
	EndIf;
	
	ProcessingDate = CommonClient.SessionDate();
	
	AdditionalParameters = New Structure("CurrentItemName", CurrentItemName);
	OnCloseNotifyHandler = New NotifyDescription("ProcessingDateChoiceOnCompletion", ThisObject, AdditionalParameters);
	ShowInputDate(OnCloseNotifyHandler, ProcessingDate, NStr("en = 'Snooze till';"), DateFractions.DateTime);

EndProcedure

&AtClient
Procedure CreateMeeting(Command)
	
	CreateNewInteraction("Meeting");
	
EndProcedure

&AtClient
Procedure CreateScheduledInteraction(Command)
	
	CreateNewInteraction("PlannedInteraction");
	
EndProcedure

&AtClient
Procedure CreatePhoneCall(Command)
	
	CreateNewInteraction("PhoneCall");
	
EndProcedure

&AtClient
Procedure CreateEmailMessage(Command)
	
	NotifyDescription = New NotifyDescription("CreateEmailFollowUp", ThisObject, );
	EmailOperationsClient.CheckAccountForSendingEmailExists(NotifyDescription);
	
EndProcedure

&AtClient
Procedure CreateEmailFollowUp(CheckCompleted, AdditionalParameters) Export
	
	If CheckCompleted = True Then
		CreateNewInteraction("OutgoingEmail");
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateSMSMessage(Command)
	
	CreateNewInteraction("SMSMessage");
	
EndProcedure

&AtClient
Procedure ApplyProcessingRules(Command)

	CurrentData = Items.Folders.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.HasEditPermission = 0 
		Or TypeOf(CurrentData.Value) = Type("CatalogRef.EmailAccounts") Then
		Return;
	EndIf;
		
	ParametersStructure1 = New Structure;
	ParametersStructure1.Insert("Account", CurrentData.Account);
	ParametersStructure1.Insert("ForEmailsInFolder", CurrentData.Value);
	
	OpenForm("Catalog.EmailProcessingRules.Form.RulesApplication", ParametersStructure1);
	
EndProcedure

&AtClient
Procedure MoveToFolder(Command)
	
	CurrentItemName = CurrentItem.Name;
	If StrStartsWith(CurrentItemName, "List") And Not CorrectChoice(CurrentItemName) Then
		Return;
	EndIf;
	
	FoldersCurrentData = Items.Folders.CurrentData;
	If FoldersCurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentItemName = "Folders" Then
		If TypeOf(FoldersCurrentData.Value) = Type("CatalogRef.EmailAccounts") 
			Or FoldersCurrentData.PredefinedFolder Then
			ShowMessageBox(, NStr("en = 'Cannot execute the command on this object';"));
			Return;
		ElsIf FoldersCurrentData.HasEditPermission = 0 Then
			Raise(NStr("en = 'Insufficient rights to edit folders.';"), ErrorCategory.AccessViolation);
		EndIf;
	EndIf;
	
	ChoiceContext = "MoveToFolder";
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", New Structure("Owner", FoldersCurrentData.Account));
	FormParameters.Insert("ChoiceMode", True);
	
	OpenForm("Catalog.EmailMessageFolders.ChoiceForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure EditNavigationPanelValue(Command)
	
	Item = CurrentItemNavigationPanelList();
	If Item = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Item.CurrentData;
	If CurrentData <> Undefined Then
		
		DisplayedValue = Undefined;
		If CurrentData.Property("Contact") And TypeOf(CurrentData.Contact) <> Type("CatalogRef.StringContactInteractions") Then
			DisplayedValue = CurrentData.Contact;
		ElsIf CurrentData.Property("SubjectOf") Then
			DisplayedValue = CurrentData.SubjectOf;
		ElsIf CurrentData.Property("Value") And TypeOf(CurrentData.Value) <> Type("String") Then
			DisplayedValue = CurrentData.Value;
		EndIf;
		
		If DisplayedValue <> Undefined Then
			ShowValue(, DisplayedValue);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ActiveSubjectsOnly(Command)
	
	ShowAllActiveSubjects = Not ShowAllActiveSubjects;
	FillSubjectsPanel();
	
EndProcedure

&AtClient
Procedure DisplayReadingPane(Command)
	
	DisplayReadingPane = Not DisplayReadingPane;
	ListOnActivateRow(Items.List);
	ManageVisibilityOnSwitchNavigationPanel();
	
EndProcedure

// Changes filter by the status of interaction in the list.
// 
// Parameters:
//  Command - FormCommand - a running command.
//
&AtClient
Procedure Attachable_ChangeFilterStatus(Command)
	
	ChangeFilterStatusServer(Command.Name);	
	RestoreExpandedTreeNodes();
	
EndProcedure

// Changes filter by the type of interaction in the list.
// 
// Parameters:
//  Command - FormCommand - a running command.
//
&AtClient
Procedure Attachable_ChangeFilterInteractionType(Command)

	ChangeFilterInteractionTypeServer(Command.Name);
	RestoreExpandedTreeNodes();

EndProcedure

&AtClient
Procedure EditNavigationPanelView(Command)
	
	NavigationPanelHidden = Not NavigationPanelHidden;
	ManageVisibilityOnSwitchNavigationPanel();
	
EndProcedure

&AtClient
Procedure ForwardAsAttachment(Command)
	
	ClearMessages();
	
	If Not CorrectChoice("List", True) Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.Type = Type("DocumentRef.IncomingEmail")
		Or (CurrentData.Type = Type("DocumentRef.OutgoingEmail")
		    And CurrentData.OutgoingEmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Sent")) Then
		
		Basis = New Structure("Basis,Command",CurrentData.Ref, "ForwardAsAttachment");
		OpeningParameters = New Structure("Basis", Basis);
		OpenForm("Document.OutgoingEmail.ObjectForm", OpeningParameters);
	
	Else
		
		MessageText = NStr("en = 'You can forward as an attachment only messages you sent or received.';");
		ShowMessageBox(, MessageText); 
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();
	NavigationPanelSubjects.ConditionalAppearance.Items.Clear();
	ContactsNavigationPanel.ConditionalAppearance.Items.Clear();

	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject, "List.Date", Items.Date.Name);
	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject, "List.SentReceived", Items.SentReceived.Name);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Properties.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Properties.NotReviewed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UseReviewedFlag");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Font", Metadata.StyleItems.MainListItem.Value);
	
	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Folders.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Folders.NotReviewed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UseReviewedFlag");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Font", Metadata.StyleItems.MainListItem.Value);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Categories.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Categories.NotReviewed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UseReviewedFlag");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Font", Metadata.StyleItems.MainListItem.Value);

	//

	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.List.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("List.Reviewed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UseReviewedFlag");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Font", Metadata.StyleItems.MainListItem.Value);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SearchString.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("SearchString");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = "";
	
	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("AdvancedSearch");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("BackColor", StyleColors.FieldBackColor);
	
#Region ReviewedContacts

	Item = ContactsNavigationPanel.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("Contact");
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("NotReviewedInteractionsCount");

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("NotReviewedInteractionsCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Font", Metadata.StyleItems.MainListItem.Value);
	
#EndRegion

#Region ReviewedSubjects

	Item = NavigationPanelSubjects.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("SubjectOf");
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("NotReviewedInteractionsCount");

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("NotReviewedInteractionsCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Font", Metadata.StyleItems.MainListItem.Value);

#EndRegion
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// Processing quick filter change.

&AtServer
Procedure ChangeFilterInteractionTypeServer(Val CommandName)

	InteractionType = Interactions.InteractionTypeByCommandName(CommandName, OnlyEmail);
	OnChangeTypeServer();

EndProcedure

&AtServer
Procedure OnChangeStatusServer(Val UpdateNavigationPanel)
	
	DateForFilter = CurrentSessionDate();
	InteractionsClientServer.QuickFilterListOnChange(ThisObject, "Status", DateForFilter);
	
	TitleTemplate1 = NStr("en = 'Status: %1';");
	StatusWasFound = Interactions.StatusesList().FindByValue(Status);
	If StatusWasFound = Undefined Then
		Status = "All";
		StatusPresentation = NStr("en = 'All items';");
	Else
		StatusPresentation = StatusWasFound.Presentation;
	EndIf;
	Items.ListStatus.Title = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, StatusPresentation);
	For Each SubmenuItem In Items.ListStatus.ChildItems Do
		If SubmenuItem.Name = ("SetTheSelectionStatus_" + Status) Then
			SubmenuItem.Check = True;
		Else
			SubmenuItem.Check = False;
		EndIf;
	EndDo;
	
	If UpdateNavigationPanel Then
		RefreshNavigationPanel();
	EndIf;

EndProcedure

&AtServer
Procedure ChangeFilterStatusServer(Val CommandName)
	Status = StatusByCommandName(CommandName);
	OnChangeStatusServer(True);
EndProcedure

&AtServer
Function StatusByCommandName(CommandName)
	
	FoundPosition = StrFind(CommandName, "_");
	If FoundPosition = 0 Then
		Return "All";
	EndIf;
	
	RowStatus = Right(CommandName, StrLen(CommandName) - FoundPosition);
	If Interactions.StatusesList().FindByValue(RowStatus) = Undefined Then
		Return "All";
	EndIf;
	
	Return RowStatus;
	
EndFunction

&AtServer
Procedure OnChangeEmployeeResponsibleServer(Val UpdateNavigationPanel)

	InteractionsClientServer.QuickFilterListOnChange(ThisObject,"EmployeeResponsible");

	If UpdateNavigationPanel Then
		RefreshNavigationPanel();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnChangeTypeServer(UpdateNavigationPanel = True)
	
	Interactions.ProcessFilterByInteractionsTypeSubmenu(ThisObject);
	
	InteractionsClientServer.OnChangeFilterInteractionType(ThisObject, InteractionType);
	If UpdateNavigationPanel Then
		RefreshNavigationPanel();
	EndIf;
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
//    Processing activation of list rows and navigation panel.

&AtClient
Procedure ProcessListRowActivation()
	
	HasUnsafeContent = False;
	EnableUnsafeContent = False;
	SetSecurityWarningVisiblity(ThisObject);
	
	If CorrectChoice("List",True) Then
		
		If DisplayReadingPane Then
			
			PreviewPageName = Items.PagesPreview.CurrentPage.Name;
			If InteractionPreviewGeneratedFor <> Items.List.CurrentData.Ref Then
				DisplayInteractionPreview(Items.List.CurrentData.Ref, PreviewPageName);
				If PreviewPageName <> Items.PagesPreview.CurrentPage.Name Then
					Items.PagesPreview.CurrentPage = Items[PreviewPageName];
				EndIf;
			EndIf;
			
		EndIf;
		
		If AdvancedSearch Then
			FillInTheDescriptionFoundByFullTextSearch(Items.List.CurrentData.Ref);
		Else
			DetailsFoundByFullTextSearch = "";
		EndIf;
		
	Else
		
		If DisplayReadingPane Then
			If Items.PagesPreview.CurrentPage <> Items.PreviewPlainTextPage Then
				Items.PagesPreview.CurrentPage = Items.PreviewPlainTextPage;
			EndIf;
			Preview = "";
			HTMLPreview = "<HTML><BODY></BODY></HTML>";
			InteractionPreviewGeneratedFor = Undefined;
		EndIf;
		DetailsFoundByFullTextSearch = "";
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessNavigationPanelRowActivation();
	
	If NavigationPanelHidden Then
		Return;
	EndIf;
	
	If Items.NavigationPanelPages.CurrentPage = Items.ContactPage Then
		CurrentData = Items.NavigationPanelContacts.CurrentData;
		If CurrentData <> Undefined Then
			
			If CurrentData.Contact = ValueSetAfterFillNavigationPanel Then
				ValueSetAfterFillNavigationPanel = Undefined;
				Return;
			EndIf;
			
			ChangeFilterList("Contacts",New Structure("Value,TypeDescription",
			                    CurrentData.Contact, Undefined));
			SaveCurrentActiveValueInSettings("Contacts",CurrentData.Contact);
			
		EndIf;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.EmailSubjectPage Then
		CurrentData = Items.NavigationPanelSubjects.CurrentData;
		If CurrentData <> Undefined Then
			
			If CurrentData.SubjectOf = ValueSetAfterFillNavigationPanel Then
				ValueSetAfterFillNavigationPanel = Undefined;
				Return;
			EndIf;
			
			ChangeFilterList("Subjects",New Structure("Value,TypeDescription",
			                    CurrentData.SubjectOf, Undefined));
			SaveCurrentActiveValueInSettings("Subjects", CurrentData.SubjectOf);
		Else
			ChangeFilterList("Subjects",New Structure("Value,TypeDescription",
			                    Undefined, Undefined));
		EndIf;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.FoldersPage Then

		CurrentData = Items.Folders.CurrentData;
		If CurrentData <> Undefined Then
			ChangeFilterList("Folders",New Structure("Value,Account",
			                    CurrentData.Value, CurrentData.Account));
			SaveCurrentActiveValueInSettings("Folders", CurrentData.Value);
		EndIf;
	
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.TabsPage Then
		CurrentData = Items.Tabs.CurrentData;
		If CurrentData <> Undefined And Not CurrentData.IsFolder Then
			ChangeFilterList("Tabs",New Structure("Value", CurrentData.Ref));
			SaveCurrentActiveValueInSettings("Tabs", CurrentData.Ref);
		Else
			CreateNavigationPanelFilterGroup();
		EndIf;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.PropertiesPage Then
		CurrentData = Items.Properties.CurrentData;
		
		If CurrentData <> Undefined Then
			
			ChangeFilterList("Properties", New Structure("Value", CurrentData.Value));
			SaveCurrentActiveValueInSettings("Properties", CurrentData.Value);
			
		EndIf;
		
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.CategoriesPage Then
		CurrentData = Items.Categories.CurrentData;
		If CurrentData <> Undefined Then
			ChangeFilterList("Categories",New Structure("Value", CurrentData.Value));
			SaveCurrentActiveValueInSettings("Categories", CurrentData.Value);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveCurrentActiveValueInSettings(TreeName, Value)

	If TreeName = "Properties" Then
		TreeName  = "Properties_" + String(CurrentPropertyOfNavigationPanel);
	EndIf;
	
	FoundRows =  NavigationPanelTreesSettings.FindRows(New Structure("TreeName",TreeName));
	If FoundRows.Count() = 1 Then
		SettingsTreeRow = FoundRows[0];
	ElsIf FoundRows.Count() > 1 Then
		SettingsTreeRow = FoundRows[0];
		For Indus = 1 To FoundRows.Count()-1 Do
			NavigationPanelTreesSettings.Delete(FoundRows[Indus]);
		EndDo;
	Else
		SettingsTreeRow = NavigationPanelTreesSettings.Add();
		SettingsTreeRow.TreeName = TreeName;
	EndIf;
	
	SettingsTreeRow.CurrentValue = Value;

EndProcedure 

&AtServer
Function CreateNavigationPanelFilterGroup()

	Return CommonClientServer.CreateFilterItemGroup(
	                    InteractionsClientServer.DynamicListFilter(List).Items,
	                    "FIlterNavigationPanel",
	                    DataCompositionFilterItemsGroupType.AndGroup);

EndFunction

&AtServer
Procedure ChangeFilterList(TableName, DataForProcessing)
	
	If TableName = "Subjects" Or TableName = "Contacts" Or TableName = "Tabs" Then
		DynamicListQueryText1 = Interactions.InteractionsListQueryText(DataForProcessing.Value);
	Else
		DynamicListQueryText1 = Interactions.InteractionsListQueryText();
	EndIf;
	
	ListProperties = Common.DynamicListPropertiesStructure();
	ListProperties.QueryText = DynamicListQueryText1;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	
	FilterGroup = CreateNavigationPanelFilterGroup();
	
	If DataForProcessing.Value = "AllValues" Then // See AddRowAll
		InteractionsClientServer.DynamicListFilter(List).Items.Delete(FilterGroup);
		Return;
	EndIf;
	
	TitleTemplate1 = "%1 (%2)";
	
	If TableName = "Subjects" Then
		
		FieldName                    = "SubjectOf";
		FilterItemCompareType = DataCompositionComparisonType.Equal;
		RightValue             = DataForProcessing.Value;
		FilterName = NStr("en = 'Topic';");
		FilterValue = DataForProcessing.Value;
		
	ElsIf TableName = "Folders" Then
		
			FieldName                    = "Type";
			FilterItemCompareType = DataCompositionComparisonType.InList;
			TypesList = New ValueList;
			TypesList.Add(Type("DocumentRef.IncomingEmail"));
			TypesList.Add(Type("DocumentRef.OutgoingEmail"));
			RightValue             = TypesList;
			
			CommonClientServer.AddCompositionItem(FilterGroup, FieldName,
			                                                       FilterItemCompareType, RightValue);
			
			FilterValue = DataForProcessing.Value;
			
			If TypeOf(DataForProcessing.Value) = Type("CatalogRef.EmailMessageFolders") Then
				
				FieldName                    = "Folder";
				FilterItemCompareType = DataCompositionComparisonType.Equal;
				RightValue             = DataForProcessing.Value;
				FilterName = NStr("en = 'Folder';");
				
			Else
				
				FieldName                    = "Account";
				FilterItemCompareType = DataCompositionComparisonType.Equal;
				RightValue             = DataForProcessing.Value;
				FilterName = NStr("en = 'Email account';");
				
			EndIf;
		
	ElsIf TableName = "Contacts" Then
		
		FieldName                    = "Contact";
		FilterItemCompareType = DataCompositionComparisonType.Equal;
		RightValue             = DataForProcessing.Value;
		FilterName = NStr("en = 'Contact';");
		FilterValue = DataForProcessing.Value;
		
	ElsIf TableName = "Properties" Then
		
		FieldName = "Ref.[" + String(CurrentPropertyOfNavigationPanel) + "]";
		FilterName = String(CurrentPropertyOfNavigationPanel);
		If TypeOf(DataForProcessing.Value) = Type("String") 
			And DataForProcessing.Value = "NotSpecified" Then
			
			FilterItemCompareType = DataCompositionComparisonType.NotFilled;
			RightValue             = "";
			FilterValue = NStr("en = 'Not specified';");
			
		Else
			
			FilterItemCompareType = DataCompositionComparisonType.Equal;
			RightValue             = DataForProcessing.Value;
			FilterValue = DataForProcessing.Value;
			
		EndIf;
		
	ElsIf TableName = "Categories" Then
		
		FieldName =  "Ref.[" + String(DataForProcessing.Value) + "]";
		FilterItemCompareType = DataCompositionComparisonType.Equal;
		RightValue             = True;
		FilterName      = NStr("en = 'Category';");
		FilterValue = String(DataForProcessing.Value);
		
	ElsIf TableName = "Tabs" Then
		
		CompositionSetup = DataForProcessing.Value.SettingsComposer.Get();
		If CompositionSetup = Undefined Then
			Return;
		EndIf;
		CompositionSchema = DocumentJournals.Interactions.GetTemplate("SchemaInteractionsFilter");
		SchemaURL = PutToTempStorage(CompositionSchema ,UUID);
		SettingsComposer = New DataCompositionSettingsComposer;
		SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
		
		SettingsComposer.LoadSettings(CompositionSetup);
		SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
		
		CopyFilter(FilterGroup,SettingsComposer.Settings.Filter);
		NavigationPanelTitle   = StringFunctionsClientServer.SubstituteParametersToString(
			TitleTemplate1, NStr("en = 'Bookmark';"), DataForProcessing.Value);
		
		Return;
		
	Else
		
		NavigationPanelTitle = "";
		Return;
		
	EndIf;
	
	NavigationPanelTitleTooltip = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, 
		FilterValue, FilterName);
	NavigationPanelTitle = FilterValue;
	If StrLen(NavigationPanelTitle) > 30 Then
		NavigationPanelTitle = Left(NavigationPanelTitle, 27) + "...";
	EndIf;
	CommonClientServer.AddCompositionItem(FilterGroup, FieldName, 
		FilterItemCompareType, RightValue);
	
EndProcedure

&AtServer
Procedure DisplayInteractionPreview(InteractionsDocumentRef, CurrentPageName)
	
	If TypeOf(InteractionsDocumentRef) = Type("DocumentRef.IncomingEmail") Then
		
		CurrentPageName = Items.HTMLPreviewPage.Name;
		HTMLPreview = Interactions.GenerateHTMLTextForIncomingEmail(InteractionsDocumentRef, False, False,
			Not EnableUnsafeContent, HasUnsafeContent);
		Preview = "";
		
	ElsIf TypeOf(InteractionsDocumentRef) = Type("DocumentRef.OutgoingEmail") Then
		
		CurrentPageName = Items.HTMLPreviewPage.Name;
		HTMLPreview = Interactions.GenerateHTMLTextForOutgoingEmail(InteractionsDocumentRef, False, False,
			Not EnableUnsafeContent, HasUnsafeContent);
		Preview = "";
		
	Else
		HasUnsafeContent = False;
		
		CurrentPageName = Items.PreviewPlainTextPage.Name;
		If TypeOf(InteractionsDocumentRef) = Type("DocumentRef.SMSMessage") Then
			Preview = Common.ObjectAttributeValue(InteractionsDocumentRef, "MessageText");
		Else
			Preview = Common.ObjectAttributeValue(InteractionsDocumentRef, "LongDesc");
		EndIf;
		HTMLPreview = "<HTML><BODY></BODY></HTML>";
		
	EndIf;
	
	If StrFind(HTMLPreview,"<BODY>") = 0 Then
		HTMLPreview = "<HTML><BODY>" + HTMLPreview + "</BODY></HTML>";
	EndIf;
	
	InteractionPreviewGeneratedFor = InteractionsDocumentRef;
	SetSecurityWarningVisiblity(ThisObject);
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
//    Switching and filling navigation panels.

&AtServer
Procedure SwitchNavigationPanelServer(CommandName)
	
	If CommandName = "SetNavigationMethodByContact" Then
		FillContactsPanel();
		Items.NavigationPanelPages.CurrentPage = Items.ContactPage;
	ElsIf CommandName = "SetNavigationMethodBySubject" Then
		FillSubjectsPanel();
		Items.NavigationPanelPages.CurrentPage = Items.EmailSubjectPage;
	ElsIf CommandName = "SetNavigationMethodByFolders" Then
		FillFoldersTree();
		Items.NavigationPanelPages.CurrentPage = Items.FoldersPage;
	ElsIf CommandName = "SetNavigationMethodByTabs" Then
		Items.NavigationPanelPages.CurrentPage = Items.TabsPage;
	ElsIf CommandName = "SetOptionByCategories" Then
		FillCategoriesTable();
		Items.NavigationPanelPages.CurrentPage = Items.CategoriesPage;
	ElsIf StrFind(CommandName,"SetOptionByProperty") > 0 Then
		FillPropertiesTree(CommandName);
		Items.NavigationPanelPages.CurrentPage = Items.PropertiesPage;
	EndIf;
	
	NavigationPanelHidden = False;
	CurrentNavigationPanelName = Items.NavigationPanelPages.CurrentPage.Name;
	ManageVisibilityOnSwitchNavigationPanel();
	AfterFillNavigationPanel();

EndProcedure

&AtServer
Procedure ManageVisibilityOnSwitchNavigationPanel()
	
	CurrentNavigationPanelPage = Items.NavigationPanelPages.CurrentPage;
	IsFolders    = (CurrentNavigationPanelPage = Items.FoldersPage);
	
	Items.ListContextMenuMoveToFolder.Visible          = IsFolders;
	Items.SentReceived.Visible                            = IsFolders;
	Items.Size.Visible                                        = IsFolders;
	Items.CreateEmailSpecialButtonList.Visible = IsFolders Or OnlyEmail;
	Items.ReplyList.Visible                                = IsFolders Or OnlyEmail;
	Items.ReplyToAllList.Visible                            = IsFolders Or OnlyEmail;
	Items.ForwardList.Visible                               = IsFolders Or OnlyEmail;
	Items.SendReceiveMailList.Visible                  = (IsFolders Or OnlyEmail)
	                                                                   And (FileInfobase Or DataSeparationEnabled);
	
	Items.Date.Visible                              = Not IsFolders;
	Items.GroupCreate.Visible                     = Not IsFolders And Not OnlyEmail;
	Items.ListContextMenuCopy.Visible  = Not IsFolders And Not OnlyEmail;
	Items.Copy.Visible                       = Not IsFolders And Not OnlyEmail;
	
	Items.PagesPreview.Visible              = DisplayReadingPane;
	Items.DisplayReadingPaneList.Check       = DisplayReadingPane;
	
	Items.InteractionTypeList.Visible =         Not IsFolders;
	If IsFolders Then
		InteractionType = "All";
		OnChangeTypeServer(False);		
	EndIf;	
	
	Items.NavigationPanelGroup.Visible             = Not NavigationPanelHidden;
	
	ChangeNavigationPanelDisplayCommand = Commands.Find("EditNavigationPanelView");
	If NavigationPanelHidden Then
		Items.EditNavigationPanelView.Picture = PictureLib.RightArrow;
		ChangeNavigationPanelDisplayCommand.ToolTip = NStr("en = 'Show navigation panel';");
		ChangeNavigationPanelDisplayCommand.Title = NStr("en = 'Show navigation panel';");
	Else
		Items.EditNavigationPanelView.Picture = PictureLib.LeftArrow;
		ChangeNavigationPanelDisplayCommand.ToolTip = NStr("en = 'Hide navigation panel';");
		ChangeNavigationPanelDisplayCommand.Title = NStr("en = 'Hide navigation panel';");
	EndIf;
	
	SetNavigationPanelViewTitle();
	GenerateImportantSubjectsOnlyDecoration();
	GenerateImportantContactsOnlyDecoration();
	
EndProcedure

&AtServer
Procedure SetNavigationPanelViewTitle(FilterValue = Undefined)
	
	For Each SubordinateItem In Items.SelectNavigationOption.ChildItems Do
		If TypeOf(SubordinateItem) = Type("FormButton") Then
			SubordinateItem.Check = False;
		EndIf;
	EndDo;
	
	If NavigationPanelHidden Then
		Items.SelectNavigationOption.Title = ?(IsBlankString(NavigationPanelTitle), 
		                                              NStr("en = 'Not specified';"),
		                                              NavigationPanelTitle);
		Items.SelectNavigationOption.ToolTip = ?(IsBlankString(NavigationPanelTitle),
		                                              NStr("en = 'Not specified';") + NavigationPanelTitleTooltip,
		                                              NavigationPanelTitleTooltip);
	Else
	
		If Items.NavigationPanelPages.CurrentPage = Items.PropertiesPage Then
			Items.SelectNavigationOption.Title = NStr("en = 'By';") + " " + CurrentPropertyPresentation;
			FoundRows = AddlAttributesPropertiesTable.FindRows(New Structure("AddlAttributeInfo",
			                                                          CurrentPropertyOfNavigationPanel));
			If FoundRows.Count() > 0 Then
				Items["AdditionalButtonPropertyNavigationOptionSelection" + XMLString(FoundRows[0].SequenceNumber)].Check = True;
			EndIf;

		ElsIf Items.NavigationPanelPages.CurrentPage = Items.TabsPage Then
			
			Items.SelectNavigationOption.Title = NStr("en = 'By bookmark';");
			Items.SetNavigationMethodByTabs.Check = True;
			
		ElsIf Items.NavigationPanelPages.CurrentPage = Items.EmailSubjectPage Then
			
			Items.SelectNavigationOption.Title = NStr("en = 'By topic';");
			Items.SetNavigationMethodBySubject.Check = True;
			
		ElsIf Items.NavigationPanelPages.CurrentPage = Items.ContactPage Then
			
			Items.SelectNavigationOption.Title = NStr("en = 'By contact';");
			Items.SetNavigationMethodByContact.Check = True;
			
		ElsIf Items.NavigationPanelPages.CurrentPage = Items.FoldersPage Then
			
			Items.SelectNavigationOption.Title = NStr("en = 'By folder';");
			Items.SetNavigationMethodByFolders.Check = True;
			
		ElsIf Items.NavigationPanelPages.CurrentPage = Items.CategoriesPage Then
			
			Items.SelectNavigationOption.Title = NStr("en = 'By category';");
			Items["AdditionalButtonCategoryNavigationOptionSelection"].Check = True;
			
		EndIf;
		
		Items.SelectNavigationOption.ToolTip = NStr("en = 'Select navigation option';");
		
	EndIf;
	
	Items.NavigationPanelGroup.Title = ?(IsBlankString(NavigationPanelTitle), 
	                                           NStr("en = 'Filter not set';"),
	                                           NStr("en = 'Filter set';"));
	
EndProcedure

&AtServer
Procedure AddRowAll(FormDataCollection, PictureNumber = 0)
	
	If TypeOf(FormDataCollection) = Type("FormDataTree") Then
		NewRow = FormDataCollection.GetItems().Add();
	Else
		NewRow = FormDataCollection.Add();
	EndIf;
	
	NewRow.Value = "AllValues";
	NewRow.Presentation = NStr("en = 'All';");
	NewRow.PictureNumber = PictureNumber;
	
EndProcedure

&AtServer
Procedure FillPropertiesTree(CommandName = "")
	
	Properties.GetItems().Clear();
	
	If Not IsBlankString(CommandName) Then
		
		PropertyNumberInTable = Number(Right(CommandName, 1));
		
		FoundRows = AddlAttributesPropertiesTable.FindRows(New Structure("SequenceNumber", PropertyNumberInTable));
		CurrentPropertyOfNavigationPanel                   = FoundRows[0].AddlAttributeInfo;
		CurrentPropertyOfNavigationPanelIsAttribute = FoundRows[0].IsAttribute;
		CurrentPropertyPresentation                    = FoundRows[0].Presentation;
		
	EndIf;
	
	Items.PropertiesPresentation.Title  = CurrentPropertyPresentation;
	
	Query = New Query;
	ConditionText = "";
	
	ConditionTextByListFilter =  GetQueryTextByListFilter(Query);
	If Not IsBlankString(ConditionTextByListFilter) Then
		Query.Text = ConditionTextByListFilter;
		
		ConditionText = " WHERE
			|(InteractionsDocument.Ref IN
			|	(SELECT DISTINCT
			|		Filterlist0.Ref
			|	FROM
			|		Filterlist0 AS Filterlist0))";
	
	EndIf;
	
	If CurrentPropertyOfNavigationPanelIsAttribute Then
		Query.Text = Query.Text + "
		|SELECT ALLOWED
		|	NestedQuery.Value AS Value,
		|	SUM(NestedQuery.NotReviewed) AS NotReviewed,
		|	1 AS PictureNumber,
		|	CASE
		|		WHEN NestedQuery.Value = &NotSpecified
		|			THEN &NotSpecifiedPresentation
		|		ELSE PRESENTATION(NestedQuery.Value)
		|	END AS Presentation
		|FROM
		|	(SELECT
		|		InteractionsDocument.Ref AS Ref,
		|		ISNULL(InteractionsDocumentAdditionalAttributes.Value, &NotSpecified) AS Value,
		|		CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END AS NotReviewed
		|	FROM
		|		Document.OutgoingEmail AS InteractionsDocument
		|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			ON InteractionsDocument.Ref = InteractionsFolderSubjects.Interaction
		|			LEFT JOIN Document.OutgoingEmail.AdditionalAttributes AS InteractionsDocumentAdditionalAttributes
		|			ON (InteractionsDocumentAdditionalAttributes.Ref = InteractionsDocument.Ref)
		|				AND (InteractionsDocumentAdditionalAttributes.Property = &Property)
		|				AND &ConditionText
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		InteractionsDocument.Ref,
		|		ISNULL(InteractionsDocumentAdditionalAttributes.Value, &NotSpecified),
		|		CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END
		|	FROM
		|		Document.IncomingEmail AS InteractionsDocument
		|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			ON InteractionsDocument.Ref = InteractionsFolderSubjects.Interaction
		|			LEFT JOIN Document.IncomingEmail.AdditionalAttributes AS InteractionsDocumentAdditionalAttributes
		|			ON (InteractionsDocumentAdditionalAttributes.Ref = InteractionsDocument.Ref)
		|				AND (InteractionsDocumentAdditionalAttributes.Property = &Property)
		|				AND &ConditionText
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		InteractionsDocument.Ref,
		|		ISNULL(InteractionsDocumentAdditionalAttributes.Value, &NotSpecified),
		|		CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END
		|	FROM
		|		Document.Meeting AS InteractionsDocument
		|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			ON InteractionsDocument.Ref = InteractionsFolderSubjects.Interaction
		|			LEFT JOIN Document.Meeting.AdditionalAttributes AS InteractionsDocumentAdditionalAttributes
		|			ON (InteractionsDocumentAdditionalAttributes.Ref = InteractionsDocument.Ref)
		|				AND (InteractionsDocumentAdditionalAttributes.Property = &Property)
		|				AND &ConditionText
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		InteractionsDocument.Ref,
		|		ISNULL(InteractionsDocumentAdditionalAttributes.Value, &NotSpecified),
		|		CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END
		|	FROM
		|		Document.PhoneCall AS InteractionsDocument
		|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			ON InteractionsDocument.Ref = InteractionsFolderSubjects.Interaction
		|			LEFT JOIN Document.PhoneCall.AdditionalAttributes AS InteractionsDocumentAdditionalAttributes
		|			ON (InteractionsDocumentAdditionalAttributes.Ref = InteractionsDocument.Ref)
		|				AND (InteractionsDocumentAdditionalAttributes.Property = &Property)
		|				AND &ConditionText
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		InteractionsDocument.Ref,
		|		ISNULL(InteractionsDocumentAdditionalAttributes.Value, &NotSpecified),
		|		CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END
		|	FROM
		|		Document.SMSMessage AS InteractionsDocument
		|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			ON InteractionsDocument.Ref = InteractionsFolderSubjects.Interaction
		|			LEFT JOIN Document.SMSMessage.AdditionalAttributes AS InteractionsDocumentAdditionalAttributes
		|			ON (InteractionsDocumentAdditionalAttributes.Ref = InteractionsDocument.Ref)
		|				AND (InteractionsDocumentAdditionalAttributes.Property = &Property)
		|				AND &ConditionText
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		InteractionsDocument.Ref,
		|		ISNULL(InteractionsDocumentAdditionalAttributes.Value, &NotSpecified),
		|		CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END
		|	FROM
		|		Document.PlannedInteraction AS InteractionsDocument
		|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			ON InteractionsDocument.Ref = InteractionsFolderSubjects.Interaction
		|			LEFT JOIN Document.PlannedInteraction.AdditionalAttributes AS InteractionsDocumentAdditionalAttributes
		|			ON (InteractionsDocumentAdditionalAttributes.Ref = InteractionsDocument.Ref)
		|				AND (InteractionsDocumentAdditionalAttributes.Property = &Property)
		|				AND &ConditionText) AS NestedQuery
		|
		|GROUP BY
		|	NestedQuery.Value
		|
		|ORDER BY
		|	Value
		|TOTALS BY
		|	Value HIERARCHY";
		
	Else
		
		Query.Text = Query.Text + "
		|SELECT ALLOWED
		|	NestedQuery.Value                        AS Value,
		|	SUM(NestedQuery.NotReviewed)            AS NotReviewed,
		|	1                                               AS PictureNumber,
		|	CASE
		|		WHEN NestedQuery.Value = &NotSpecified
		|			THEN &NotSpecifiedPresentation
		|		ELSE PRESENTATION(NestedQuery.Value)
		|		END AS Presentation
		|	FROM
		|	(SELECT
		|		InteractionsDocument.Ref AS Ref,
		|		CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END AS NotReviewed,
		|		ISNULL(AdditionalInfo.Value, &NotSpecified) AS Value
		|	FROM
		|		DocumentJournal.Interactions AS InteractionsDocument
		|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			ON InteractionsDocument.Ref = InteractionsFolderSubjects.Interaction
		|			LEFT JOIN InformationRegister.AdditionalInfo AS AdditionalInfo
		|			ON InteractionsDocument.Ref = AdditionalInfo.Object
		|				AND (AdditionalInfo.Property = &Property)
		|			AND &ConditionText) AS NestedQuery
		|
		|GROUP BY
		|	NestedQuery.Value
		|
		|ORDER BY
		|Value
		|
		|TOTALS BY
		|Value HIERARCHY";
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "AND &ConditionText", ConditionText);
	
	Query.SetParameter("Property",              CurrentPropertyOfNavigationPanel);
	Query.SetParameter("NotSpecified",              "NotSpecified");
	Query.SetParameter("NotSpecifiedPresentation", NStr("en = 'Not specified';"));
	
	Result = Query.Execute();
	Tree = Result.Unload(QueryResultIteration.ByGroupsWithHierarchy);
	
	RowsFirstLevel = Properties.GetItems();
	
	For Each String In Tree.Rows Do
		PropertyRow =  RowsFirstLevel.Add();
		FillPropertyValues(PropertyRow, String);
		PropertyRow.PictureNumber = ?(TypeOf(PropertyRow.Value) = Type("String"), 0, 1);
		PropertyRow.Presentation = String(PropertyRow.Value) 
		                               + ?(String.NotReviewed = 0 Or Not UseReviewedFlag,
		                               "", " (" + String(String.NotReviewed) + ")");
		AddRowsToNavigationTree(String, PropertyRow, True, 1);
	EndDo;
	
	AddRowAll(Properties, 2);
	
EndProcedure

&AtServer
Procedure FillSubjectsPanel()
	
	ListParameters = Common.DynamicListPropertiesStructure();
	
	FilterReceiver = NavigationPanelSubjects.SettingsComposer.FixedSettings.Filter;
	FilterReceiver.Items.Clear();
	
	If ImportantSubjectsOnly Then
		
		Query = New Query;
		QueryTextByFilter = GetQueryTextByListFilter(Query);
		PositionWHERE = StrFind(QueryTextByFilter, "WHERE");
		If PositionWHERE = 0 Then
			StringToSearchBy = "";
		Else
			StringToSearchBy = Right(QueryTextByFilter, StrLen(QueryTextByFilter) - PositionWHERE + 1);
		EndIf;
		
		ConditionStringsArray = StrSplit(StringToSearchBy, Chars.LF, False);
		ConditionsTextByDocumentJournal = "";
		ConditionsTextByRegister          = "";
		ConstructionAnd                    = Chars.Tab + "And";
		
		For Each ConditionString In ConditionStringsArray Do
			ConditionString = StrReplace(ConditionString, "&P", "&Par");
			If StrFind(ConditionString, "InteractionDocumentsLog") Then
				If IsBlankString(ConditionsTextByDocumentJournal) 
					And StrStartsWith(ConditionString, ConstructionAnd) Then 
					ConditionString = Right(ConditionString, StrLen(ConditionString) - StrLen(ConstructionAnd));
				EndIf;
				ConditionsTextByDocumentJournal = ConditionsTextByDocumentJournal + ConditionString + Chars.LF;
			ElsIf StrFind(ConditionString, "InteractionsSubjects") Then
				If IsBlankString(ConditionsTextByRegister)
					And StrStartsWith(ConditionString, ConstructionAnd) Then
					ConditionString = Right(ConditionString, StrLen(ConditionString) - StrLen(ConstructionAnd));
				EndIf;
				ConditionsTextByRegister = ConditionsTextByRegister + ConditionString + Chars.LF;
			EndIf;
		EndDo;
		
		QueryTextDynamicList = 
			"SELECT
			|	InteractionsSubjectsStates.SubjectOf AS SubjectOf,
			|	InteractionsSubjectsStates.NotReviewedInteractionsCount AS NotReviewedInteractionsCount,
			|	InteractionsSubjectsStates.LastInteractionDate AS LastInteractionDate,
			|	InteractionsSubjectsStates.Running AS Running,
			|	VALUETYPE(InteractionsSubjectsStates.SubjectOf) AS SubjectType
			|FROM
			|	InformationRegister.InteractionsSubjectsStates AS InteractionsSubjectsStates
			|WHERE
			|	TRUE IN
			|			(SELECT TOP 1
			|				TRUE
			|			FROM
			|				InformationRegister.InteractionsFolderSubjects AS InteractionsSubjects
			|					INNER JOIN DocumentJournal.Interactions AS InteractionDocumentsLog
			|					ON
			|						InteractionsSubjects.SubjectOf = InteractionsSubjectsStates.SubjectOf
			|							AND InteractionsSubjects.Interaction = InteractionDocumentsLog.Ref
			|							AND &DocumentJournalConditionText
			|			WHERE
			|				&FolderRegisterConnectionText)";
		
		QueryTextDynamicList = StrReplace(QueryTextDynamicList, "&DocumentJournalConditionText", 
			?(IsBlankString(ConditionsTextByDocumentJournal), "TRUE", ConditionsTextByDocumentJournal));
		QueryTextDynamicList = StrReplace(QueryTextDynamicList, "&FolderRegisterConnectionText", 
			?(IsBlankString(ConditionsTextByRegister), "TRUE", ConditionsTextByRegister));
		
		ListParameters.QueryText = QueryTextDynamicList;
		Common.SetDynamicListProperties(Items.NavigationPanelSubjects, ListParameters);
		
		For Each QueryParameter In Query.Parameters Do
			If StrStartsWith(QueryParameter.Key, "P") Then
				ParameterName = "Par" + Right(QueryParameter.Key, StrLen(QueryParameter.Key)-1);
			Else
				ParameterName = QueryParameter.Key;
			EndIf;
			CommonClientServer.SetDynamicListParameter(NavigationPanelSubjects, ParameterName, QueryParameter.Value);
		EndDo;
		
	Else
		
		QueryTextDynamicList = "
		|SELECT
		|	InteractionsSubjectsStates.SubjectOf,
		|	InteractionsSubjectsStates.NotReviewedInteractionsCount,
		|	InteractionsSubjectsStates.LastInteractionDate,
		|	InteractionsSubjectsStates.Running AS Running,
		|	VALUETYPE(InteractionsSubjectsStates.SubjectOf) AS SubjectType
		|FROM
		|	InformationRegister.InteractionsSubjectsStates AS InteractionsSubjectsStates
		|WHERE
		|	TRUE IN
		|			(SELECT TOP 1
		|				TRUE
		|			FROM
		|				InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|					INNER JOIN DocumentJournal.Interactions AS InteractionDocumentsLog
		|					ON InteractionsFolderSubjects.SubjectOf = InteractionsSubjectsStates.SubjectOf
		|							AND InteractionsFolderSubjects.Interaction = InteractionDocumentsLog.Ref)";
		
		ListParameters.QueryText = QueryTextDynamicList;
		Common.SetDynamicListProperties(Items.NavigationPanelSubjects, ListParameters);
		
	EndIf;
	
	If ShowAllActiveSubjects Then
		CommonClientServer.SetFilterItem(FilterReceiver,"Running", True,DataCompositionComparisonType.Equal);
	EndIf;
	
	Items.NavigationPanelSubjectsContextMenuActiveSubjectsOnly.Check = ShowAllActiveSubjects;
	GenerateImportantSubjectsOnlyDecoration();
	
EndProcedure

&AtServer
Procedure FillCategoriesTable()
	
	Categories.Clear();

	Query = New Query;
	ConditionTextAttributes = "";
	ConditionTextInfo  = "";
	
	ConditionTextByListFilter = GetQueryTextByListFilter(Query);
	If Not IsBlankString(ConditionTextByListFilter) Then
		Query.Text = ConditionTextByListFilter;
		
		ConditionTextAttributes = " AND
			|InteractionAdditionalAttributes.Ref IN
			|	(SELECT DISTINCT
			|		Filterlist0.Ref
			|	FROM
			|		Filterlist0 AS Filterlist0)";
		
		ConditionTextInfo = " AND
			|AdditionalInfo.Object IN
			|	(SELECT DISTINCT
			|		Filterlist0.Ref
			|	FROM
			|		Filterlist0 AS Filterlist0)";
	
	EndIf;
		
	Query.Text = Query.Text + "
	|SELECT ALLOWED
	|	BooleanProperties.AddlAttributeInfo AS Property,
	|	BooleanProperties.IsAttribute
	|INTO BooleanProperties
	|FROM
	|	&BooleanProperties AS BooleanProperties
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PRESENTATION(NestedQuery.Property) AS Presentation,
	|	NestedQuery.Property AS Value,
	|	SUM(NestedQuery.NotReviewed) AS NotReviewed
	|FROM
	|	(SELECT
	|		InteractionAdditionalAttributes.Property AS Property,
	|		SUM(CASE
	|				WHEN InteractionsFolderSubjects.Reviewed
	|					THEN 0
	|				ELSE 1
	|			END) AS NotReviewed
	|	FROM
	|		Document.Meeting.AdditionalAttributes AS InteractionAdditionalAttributes
	|			INNER JOIN Document.Meeting AS Interaction
	|			ON InteractionAdditionalAttributes.Ref = Interaction.Ref
	|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			ON InteractionAdditionalAttributes.Ref = InteractionsFolderSubjects.Interaction
	|	WHERE
	|		InteractionAdditionalAttributes.Property IN
	|				(SELECT
	|					BooleanProperties.Property
	|				FROM
	|					BooleanProperties AS BooleanProperties
	|				WHERE
	|					BooleanProperties.IsAttribute) AND &ConditionTextAttributes
	|	
	|	GROUP BY
	|		InteractionAdditionalAttributes.Property
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InteractionAdditionalAttributes.Property,
	|		SUM(CASE
	|				WHEN InteractionsFolderSubjects.Reviewed
	|					THEN 0
	|				ELSE 1
	|			END)
	|	FROM
	|		Document.PhoneCall.AdditionalAttributes AS InteractionAdditionalAttributes
	|			INNER JOIN Document.PhoneCall AS Interaction
	|			ON InteractionAdditionalAttributes.Ref = Interaction.Ref
	|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			ON InteractionAdditionalAttributes.Ref = InteractionsFolderSubjects.Interaction
	|	WHERE
	|		InteractionAdditionalAttributes.Property IN
	|				(SELECT
	|					BooleanProperties.Property
	|				FROM
	|					BooleanProperties AS BooleanProperties
	|				WHERE
	|					BooleanProperties.IsAttribute) AND &ConditionTextAttributes
	|	
	|	GROUP BY
	|		InteractionAdditionalAttributes.Property
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InteractionAdditionalAttributes.Property,
	|		SUM(CASE
	|				WHEN InteractionsFolderSubjects.Reviewed
	|					THEN 0
	|				ELSE 1
	|			END)
	|	FROM
	|		Document.PlannedInteraction.AdditionalAttributes AS InteractionAdditionalAttributes
	|			INNER JOIN Document.PlannedInteraction AS Interaction
	|			ON InteractionAdditionalAttributes.Ref = Interaction.Ref
	|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			ON InteractionAdditionalAttributes.Ref = InteractionsFolderSubjects.Interaction
	|	WHERE
	|		InteractionAdditionalAttributes.Property IN
	|				(SELECT
	|					BooleanProperties.Property
	|				FROM
	|					BooleanProperties AS BooleanProperties
	|				WHERE
	|					BooleanProperties.IsAttribute) AND &ConditionTextAttributes
	|	
	|	GROUP BY
	|		InteractionAdditionalAttributes.Property
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InteractionAdditionalAttributes.Property,
	|		SUM(CASE
	|				WHEN InteractionsFolderSubjects.Reviewed
	|					THEN 0
	|				ELSE 1
	|			END)
	|	FROM
	|		Document.IncomingEmail.AdditionalAttributes AS InteractionAdditionalAttributes
	|			INNER JOIN Document.IncomingEmail AS Interaction
	|			ON InteractionAdditionalAttributes.Ref = Interaction.Ref
	|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			ON InteractionAdditionalAttributes.Ref = InteractionsFolderSubjects.Interaction
	|	WHERE
	|		InteractionAdditionalAttributes.Property IN
	|				(SELECT
	|					BooleanProperties.Property
	|				FROM
	|					BooleanProperties AS BooleanProperties
	|				WHERE
	|					BooleanProperties.IsAttribute) AND &ConditionTextAttributes
	|	
	|	GROUP BY
	|		InteractionAdditionalAttributes.Property
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InteractionAdditionalAttributes.Property,
	|		SUM(CASE
	|				WHEN InteractionsFolderSubjects.Reviewed
	|					THEN 0
	|				ELSE 1
	|			END)
	|	FROM
	|		Document.OutgoingEmail.AdditionalAttributes AS InteractionAdditionalAttributes
	|			INNER JOIN Document.OutgoingEmail AS Interaction
	|			ON InteractionAdditionalAttributes.Ref = Interaction.Ref
	|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			ON InteractionAdditionalAttributes.Ref = InteractionsFolderSubjects.Interaction
	|	WHERE
	|		InteractionAdditionalAttributes.Property IN
	|				(SELECT
	|					BooleanProperties.Property
	|				FROM
	|					BooleanProperties AS BooleanProperties
	|				WHERE
	|					BooleanProperties.IsAttribute) AND &ConditionTextAttributes
	|	
	|	GROUP BY
	|		InteractionAdditionalAttributes.Property
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AdditionalInfo.Property,
	|		SUM(CASE
	|				WHEN InteractionsFolderSubjects.Reviewed
	|					THEN 0
	|				ELSE 1
	|			END)
	|	FROM
	|		InformationRegister.AdditionalInfo AS AdditionalInfo
	|			INNER JOIN DocumentJournal.Interactions AS Interactions
	|			ON AdditionalInfo.Object = Interactions.Ref
	|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			ON Interactions.Ref = InteractionsFolderSubjects.Interaction
	|	WHERE
	|		AdditionalInfo.Property IN
	|				(SELECT
	|					BooleanProperties.Property
	|				FROM
	|					BooleanProperties AS BooleanProperties
	|				WHERE
	|					(NOT BooleanProperties.IsAttribute))
	|		AND VALUETYPE(AdditionalInfo.Object) IN (TYPE(Document.PlannedInteraction), TYPE(Document.Meeting), TYPE(Document.PhoneCall), TYPE(Document.IncomingEmail), TYPE(Document.OutgoingEmail), TYPE(Document.PlannedInteraction), TYPE(Document.SMSMessage))
	|				 AND &ConditionTextInfo
	|	
	|	GROUP BY
	|		AdditionalInfo.Property) AS NestedQuery
	|
	|GROUP BY
	|	NestedQuery.Property";
	
	Query.Text = StrReplace(Query.Text, "AND &ConditionTextInfo", ConditionTextInfo);
	Query.Text = StrReplace(Query.Text, "AND &ConditionTextAttributes", ConditionTextAttributes);
	
	Query.SetParameter("BooleanProperties", AddlAttributesPropertiesTableOfBooleanType.Unload());
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRow = Categories.Add();
		FillPropertyValues(NewRow,Selection);
		NewRow.PictureNumber = 0;
		NewRow.Presentation = String(Selection.Presentation) 
		                            + ?(Selection.NotReviewed = 0 Or Not UseReviewedFlag,
		                                "", " (" + String(Selection.NotReviewed) + ")");
		
	EndDo;
	
	AddRowAll(Properties, 2);
	
EndProcedure

&AtServer
Procedure FillContactsPanel()
	
	ListPropertiesStructure = Common.DynamicListPropertiesStructure();
	
	If ImportantContactsOnly Then
		
		Query = New Query;
		QueryTextByFilter = GetQueryTextByListFilter(Query);
		PositionWHERE = StrFind(QueryTextByFilter, "WHERE");
		If PositionWHERE = 0 Then
			StringToSearchBy = "";
		Else
			StringToSearchBy = Right(QueryTextByFilter, StrLen(QueryTextByFilter) - PositionWHERE + 1);
		EndIf;
		
		ConditionStringsArray = StrSplit(StringToSearchBy, Chars.LF, False);
		ConditionsTextByDocumentJournal = "";
		ConditionsTextByRegister          = "";
		ConstructionAnd                    = Chars.Tab + "And";
		
		For Each ConditionString In ConditionStringsArray Do
			ConditionString = StrReplace(ConditionString, "&P", "&Par");
			If StrFind(ConditionString, "InteractionDocumentsLog") Then
				If IsBlankString(ConditionsTextByDocumentJournal) 
					And StrStartsWith(ConditionString, ConstructionAnd) Then 
					ConditionString = Right(ConditionString, StrLen(ConditionString) - StrLen(ConstructionAnd));
				EndIf;
				ConditionsTextByDocumentJournal = ConditionsTextByDocumentJournal + ConditionString + Chars.LF;
			ElsIf StrFind(ConditionString, "InteractionsSubjects") Then
				If IsBlankString(ConditionsTextByRegister)
					And StrStartsWith(ConditionString, ConstructionAnd) Then
					ConditionString = Right(ConditionString, StrLen(ConditionString) - StrLen(ConstructionAnd));
				EndIf;
				ConditionsTextByRegister = ConditionsTextByRegister + ConditionString + Chars.LF;
			EndIf;
		EndDo;
		
		QueryTextDynamicList = 
		"SELECT
		|	InteractionsContactStates.Contact,
		|	InteractionsContactStates.NotReviewedInteractionsCount,
		|	InteractionsContactStates.LastInteractionDate,
		|	3 AS PictureNumber,
		|	VALUETYPE(InteractionsContactStates.Contact) AS ContactType
		|FROM
		|	InformationRegister.InteractionsContactStates AS InteractionsContactStates
		|WHERE
		|	TRUE IN
		|			(SELECT TOP 1
		|				TRUE
		|			FROM
		|				InformationRegister.InteractionsContacts AS InteractionsContacts
		|					INNER JOIN DocumentJournal.Interactions AS InteractionDocumentsLog
		|					ON
		|						InteractionsContacts.Contact = InteractionsContactStates.Contact
		|							AND InteractionsContacts.Interaction = InteractionDocumentsLog.Ref
		|							AND &DocumentJournalConditionText
		|					INNER JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsSubjects
		|					ON
		|						InteractionsContacts.Contact = InteractionsContactStates.Contact
		|							AND InteractionsContacts.Interaction = InteractionsSubjects.Interaction
		|							AND &FolderRegisterConnectionText)";
		
		QueryTextDynamicList = StrReplace(QueryTextDynamicList, "&DocumentJournalConditionText", 
			?(IsBlankString(ConditionsTextByDocumentJournal), "TRUE", ConditionsTextByDocumentJournal));
		QueryTextDynamicList = StrReplace(QueryTextDynamicList, "&FolderRegisterConnectionText", 
			?(IsBlankString(ConditionsTextByRegister), "TRUE", ConditionsTextByRegister));
		
		ListPropertiesStructure.QueryText = QueryTextDynamicList;
		Common.SetDynamicListProperties(Items.NavigationPanelContacts, ListPropertiesStructure);
		
		For Each QueryParameter In Query.Parameters Do
			If StrStartsWith(QueryParameter.Key, "P") Then
				ParameterName = "Par" + Right(QueryParameter.Key, StrLen(QueryParameter.Key)-1);
			Else
				ParameterName = QueryParameter.Key;
			EndIf;
			CommonClientServer.SetDynamicListParameter(ContactsNavigationPanel, ParameterName, QueryParameter.Value);
		EndDo;
		
	Else
		
		QueryTextDynamicList = "
		|SELECT
		|	InteractionsContactStates.Contact,
		|	InteractionsContactStates.NotReviewedInteractionsCount,
		|	InteractionsContactStates.LastInteractionDate,
		|	3 AS PictureNumber,
		|	VALUETYPE(InteractionsContactStates.Contact) AS ContactType
		|FROM
		|	InformationRegister.InteractionsContactStates AS InteractionsContactStates";
		
		ListPropertiesStructure.QueryText = QueryTextDynamicList;
		Common.SetDynamicListProperties(Items.NavigationPanelContacts, ListPropertiesStructure);
		
	EndIf;
	
	GenerateImportantContactsOnlyDecoration();
	
EndProcedure

&AtServer
Procedure FillFoldersTree()
	
	Folders.GetItems().Clear();
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	EmailAccounts.Ref AS Account,
	|	EmailMessageFolders.Ref AS Value,
	|	ISNULL(NotReviewedFolders.NotReviewedInteractionsCount, 0) AS NotReviewed,
	|	EmailMessageFolders.PredefinedFolder AS PredefinedFolder,
	|	CASE
	|		WHEN CASE
	|					WHEN EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef)
	|						THEN EmailAccountSettings.EmployeeResponsibleForFoldersMaintenance = &CurrentUser
	|					ELSE EmailAccounts.AccountOwner = &CurrentUser
	|				END
	|				OR &FullRightsRoleAvailable
	|			THEN 1
	|		ELSE 0
	|	END AS HasEditPermission,
	|	CASE 
	|		WHEN EmailAccounts.AccountOwner = &CurrentUser THEN 1
	|		WHEN EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef) THEN 2
	|		ELSE 3
	|	END AS OrderingValue,
	|	CASE
	|		WHEN NOT EmailMessageFolders.PredefinedFolder
	|			THEN 7
	|		ELSE CASE
	|				WHEN EmailMessageFolders.PredefinedFolderType = VALUE(Enum.PredefinedEmailsFoldersTypes.IncomingMessages)
	|					THEN 1
	|				WHEN EmailMessageFolders.PredefinedFolderType = VALUE(Enum.PredefinedEmailsFoldersTypes.SentMessages)
	|					THEN 2
	|				WHEN EmailMessageFolders.PredefinedFolderType = VALUE(Enum.PredefinedEmailsFoldersTypes.Drafts)
	|					THEN 3
	|				WHEN EmailMessageFolders.PredefinedFolderType = VALUE(Enum.PredefinedEmailsFoldersTypes.Outbox)
	|					THEN 4
	|				WHEN EmailMessageFolders.PredefinedFolderType = VALUE(Enum.PredefinedEmailsFoldersTypes.JunkMail)
	|					THEN 5
	|				WHEN EmailMessageFolders.PredefinedFolderType = VALUE(Enum.PredefinedEmailsFoldersTypes.Trash)
	|					THEN 6
	|			END
	|	END AS PictureNumber
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|		LEFT JOIN Catalog.EmailMessageFolders AS EmailMessageFolders
	|		ON (EmailMessageFolders.Owner = EmailAccounts.Ref)
	|		LEFT JOIN InformationRegister.EmailFolderStates AS NotReviewedFolders
	|		ON (NotReviewedFolders.Folder = EmailMessageFolders.Ref)
	|		LEFT JOIN InformationRegister.EmailAccountSettings AS EmailAccountSettings
	|		ON (EmailMessageFolders.Owner = EmailAccountSettings.EmailAccount)
	|LEFT JOIN Catalog.Users AS Users
	|	ON EmailAccounts.AccountOwner = Users.Ref
	|		AND (EmailMessageFolders.Owner = EmailAccounts.Ref)
	|WHERE
	|	NOT ISNULL(EmailAccountSettings.NotUseInDefaultEmailClient, FALSE)
	|	AND NOT EmailMessageFolders.DeletionMark
	|	AND NOT EmailAccounts.DeletionMark
	|	AND CASE 
	|		WHEN &FullRightsRoleAvailable 
	|		THEN TRUE 
	|		ELSE (NOT ISNULL(Users.Invalid, FALSE)) OR EmailAccounts.UseForSending OR EmailAccounts.UseForReceiving
	|	END 
	|
	|ORDER BY
	|	OrderingValue,
	|	EmailMessageFolders.Code
	|TOTALS
	|	SUM(NotReviewed),
	|	SUM(HasEditPermission)
	|BY
	|	Account,
	|	Value HIERARCHY";
	
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("FullRightsRoleAvailable", Users.IsFullUser());

	Result = Query.Execute();
	Tree = Result.Unload(QueryResultIteration.ByGroupsWithHierarchy);
	RowsFirstLevel = Folders.GetItems();
	
	For Each String In Tree.Rows Do
		
		AccountRow = RowsFirstLevel.Add();
		AccountRow.Account        = String.Account;
		AccountRow.Value             = String.Account;
		AccountRow.PictureNumber        = 0;
		AccountRow.NotReviewed        = String.NotReviewed;
		AccountRow.HasEditPermission = String.HasEditPermission;
		AccountRow.Presentation = String(AccountRow.Value) 
		                              + ?(String.NotReviewed = 0 Or Not UseReviewedFlag,
		                              "", " (" + String(String.NotReviewed) + ")");
		
		AddRowsToNavigationTree(String, AccountRow);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AddRowsToNavigationTree(ParentString, ParentRow, ExecuteCheck1 = True, PictureNumber = -1)
	
	For Each String In ParentString.Rows Do
		
		If ExecuteCheck1 And (String.Value = ParentString.Value Or String.Value = Undefined) Then
			Continue;
		EndIf;
		
		NewRow = ParentRow.GetItems().Add();
		FillPropertyValues(NewRow,String);
		
		If String.PictureNumber = Null And PictureNumber <> -1 Then
			NewRow.PictureNumber = PictureNumber;
		EndIf;
	
		If InteractionsClientServer.IsInteraction(String.Value) Then
			DetailsRow = String.Rows[0];
			NewRow.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1, %2 %3';"),
				?(IsBlankString(DetailsRow.Subject),NStr("en = 'Subject not specified';"), DetailsRow.Subject),
				Format(DetailsRow.Date, "DLF=DT"),
				?(String.NotReviewed = 0 Or Not UseReviewedFlag, "","(" + String(String.NotReviewed) + ")"));
			NewRow.PictureNumber = DetailsRow.PictureNumber;
		Else
			NewRow.Presentation = String(NewRow.Value) 
			         + ?(String.NotReviewed = 0 Or Not UseReviewedFlag, 
			             "", 
			             " (" + String(String.NotReviewed) + ")");
			If String.PictureNumber = Null And PictureNumber = -1 And String.Rows.Count() > 0 Then
				NewRow.PictureNumber = String.Rows[0].PictureNumber;
			EndIf;
		EndIf;
		
		AddRowsToNavigationTree(String, NewRow);
		
	EndDo;
	
EndProcedure

&AtServer
Function GetQueryTextByListFilter(Query)
	
	If InteractionsClientServer.DynamicListFilter(List).Items.Count() > 0 Then
		
		SchemaInteractionsFilter = DocumentJournals.Interactions.GetTemplate("SchemaInteractionsFilter");
		
		TemplateComposer = New DataCompositionTemplateComposer();
		SettingsComposer = New DataCompositionSettingsComposer;
		SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaInteractionsFilter));
		SettingsComposer.LoadSettings(SchemaInteractionsFilter.DefaultSettings);
		
		CopyFilter(SettingsComposer.Settings.Filter, InteractionsClientServer.DynamicListFilter(List),,, True);
		
		If ValueIsFilled(Items.List.Period.StartDate) Or  ValueIsFilled(Items.List.Period.EndDate) Then
			SettingsComposer.Settings.DataParameters.SetParameterValue("Interval", Items.List.Period);
		EndIf;
		
		DataCompositionTemplate = TemplateComposer.Execute(SchemaInteractionsFilter, SettingsComposer.GetSettings(),,,
			Type("DataCompositionValueCollectionTemplateGenerator"));
		
		ValuesOfLayoutParameters = DataCompositionTemplate.ParameterValues; // DataCompositionTemplateParameterValues
		
		If ValuesOfLayoutParameters.Count() = 0 Then
			Return "";
		ElsIf ValuesOfLayoutParameters.Count() = 2 
			And (Not ValueIsFilled(ValuesOfLayoutParameters.BeginningOfSelectionPeriod.Value)) 
			And (Not ValueIsFilled(ValuesOfLayoutParameters.EndOfSelectionPeriod.Value)) Then
			Return "";
		EndIf;
		
		QueryText = DataCompositionTemplate.DataSets.MainDataSet.Query;
		
		For Each Parameter In DataCompositionTemplate.ParameterValues Do
			Query.Parameters.Insert(Parameter.Name, Parameter.Value);
		EndDo;
		
		QueryText = QueryText +"
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|";
		
		FoundItemFROM = StrFind(QueryText,"FROM"); // @query-part
		If FoundItemFROM <> 0 Then
			QueryText = Left(QueryText,FoundItemFROM - 1) + "  INTO Filterlist0
			|  " + Right(QueryText,StrLen(QueryText) - FoundItemFROM + 1); // @query-part
		EndIf;
		
	Else
		
		Return "";
		
	EndIf;
	
	Return QueryText;
	
EndFunction

&AtServer
Procedure RefreshNavigationPanel(CurrentRowValue = Undefined, SetDontTestNavigationPanelActivationFlag = True)
	
	CurrentNavigationPanelPage = Items.NavigationPanelPages.CurrentPage;
	
	If CurrentNavigationPanelPage = Items.ContactPage Then
		FillContactsPanel();
	ElsIf CurrentNavigationPanelPage = Items.EmailSubjectPage Then
		FillSubjectsPanel();
	ElsIf CurrentNavigationPanelPage = Items.FoldersPage Then
		FillFoldersTree();
	ElsIf CurrentNavigationPanelPage = Items.PropertiesPage Then
		FillPropertiesTree();
	ElsIf CurrentNavigationPanelPage = Items.CategoriesPage Then
		FillCategoriesTable();
	EndIf;
	
	AfterFillNavigationPanel(SetDontTestNavigationPanelActivationFlag);
	
EndProcedure

&AtServer
Procedure AfterFillNavigationPanel(SetDontTestNavigationPanelActivationFlag = True)
	
	If Not SetDontTestNavigationPanelActivationFlag Then
		Return;
	EndIf;
	
	ValueSetAfterFillNavigationPanel = Undefined;
	
	Settings = GetSavedSettingsOfNavigationPanelTree(Items.NavigationPanelPages.CurrentPage.Name,
		CurrentPropertyOfNavigationPanel,NavigationPanelTreesSettings);
	
	If Settings = Undefined Then
		Return;
	EndIf;
	
	SettingsValue = Settings.SettingsValue;
	
	If Not (Items.NavigationPanelPages.CurrentPage = Items.EmailSubjectPage 
		Or Items.NavigationPanelPages.CurrentPage = Items.ContactPage
		Or Items.NavigationPanelPages.CurrentPage = Items.TabsPage) Then
		PositionOnRowAccordingToSavedValue(SettingsValue.CurrentValue, Settings.TreeName);
	EndIf;
	
	
	If Items.NavigationPanelPages.CurrentPage = Items.ContactPage Then
		
		Items.NavigationPanelContacts.CurrentRow = InformationRegisters.InteractionsContactStates.CreateRecordKey(New Structure("Contact", SettingsValue.CurrentValue));

		ChangeFilterList("Contacts",New Structure("Value,TypeDescription",
		                    SettingsValue.CurrentValue, Undefined));
			
		ValueSetAfterFillNavigationPanel = SettingsValue.CurrentValue;
		
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.FoldersPage Then
		
		CurrentData = Folders.FindByID(Items.Folders.CurrentRow);
		If CurrentData = Undefined And Folders.GetItems().Count() > 0 Then
			CurrentData =  Folders.GetItems()[0];
		EndIf;
		
		If CurrentData <> Undefined Then
			ChangeFilterList("Folders",New Structure("Value,Account",
			                   CurrentData.Value, CurrentData.Account));
		EndIf;
		
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.EmailSubjectPage Then
		
		If ValueIsFilled(Items.NavigationPanelSubjects.CurrentRow) Then
			Return;
		EndIf;
		
		Items.NavigationPanelSubjects.CurrentRow = InformationRegisters.InteractionsSubjectsStates.CreateRecordKey(New Structure("SubjectOf", SettingsValue.CurrentValue));
		
		ChangeFilterList("Subjects",New Structure("Value,TypeDescription",
		                    SettingsValue.CurrentValue, Undefined));
		
		ValueSetAfterFillNavigationPanel = SettingsValue.CurrentValue;

	ElsIf Items.NavigationPanelPages.CurrentPage = Items.PropertiesPage Then
		
		CurrentData = Properties.FindByID(Items.Properties.CurrentRow);
		
		If CurrentData = Undefined Then
			Items.Properties.CurrentRow = FindStringInFormDataTree(Properties,NStr("en = 'All';"),"Value",False);
			CurrentData = Properties.FindByID(Items.Properties.CurrentRow);
		EndIf;
		
		If CurrentData <> Undefined Then
			
			ChangeFilterList("Properties", New Structure("Value", CurrentData.Value));
			
		EndIf;
		
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.CategoriesPage Then
		
		CurrentData = Categories.FindByID(Items.Categories.CurrentRow);
		
		If CurrentData = Undefined Then
			Items.Categories.CurrentRow = FindRowInCollectionFormData(Categories,NStr("en = 'All';"),"Value");
			CurrentData = Categories.FindByID(Items.Categories.CurrentRow);
		EndIf;
		
		If CurrentData <> Undefined Then
			ChangeFilterList("Categories",New Structure("Value", CurrentData.Value));
		EndIf;
		
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.TabsPage Then
		
		Items.Tabs.CurrentRow = SettingsValue.CurrentValue;
		ChangeFilterList("Tabs", New Structure("Value", SettingsValue.CurrentValue));
		
	EndIf;
	
	DoNotTestNavigationPanelActivation = True;

EndProcedure

&AtServer
Procedure UpdateAtServer()

	RefreshNavigationPanel( ,False);

EndProcedure

&AtServer
Procedure AddToNavigationPanel()
	
	If Not Common.SubsystemExists("StandardSubsystems.Properties") Then
		Return;
	EndIf;
	ModulePropertyManager = Common.CommonModule("PropertyManager");
	
	Sets = New Array;
	Sets.Add(ModulePropertyManager.PropertiesSetByName("Document_Meeting"));
	Sets.Add(ModulePropertyManager.PropertiesSetByName("Document_PlannedInteraction"));
	Sets.Add(ModulePropertyManager.PropertiesSetByName("Document_PhoneCall"));
	Sets.Add(ModulePropertyManager.PropertiesSetByName("Document_IncomingEmail"));
	Sets.Add(ModulePropertyManager.PropertiesSetByName("Document_OutgoingEmail"));
	Sets.Add(ModulePropertyManager.PropertiesSetByName("Document_SMSMessage"));
	
	Query = New Query;
	Query.SetParameter("Sets", Sets);
	Query.Text = "
	|SELECT DISTINCT ALLOWED
	|	SetsOfAdditionalDetailsAndDetailsAdditionalDetails.Property,
	|	PRESENTATION(SetsOfAdditionalDetailsAndDetailsAdditionalDetails.Property) AS Presentation,
	|	TRUE AS IsAddlAttribute
	|INTO AddlAttributesAndInfo
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS SetsOfAdditionalDetailsAndDetailsAdditionalDetails
	|WHERE
	|	SetsOfAdditionalDetailsAndDetailsAdditionalDetails.Ref IN (&Sets)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	SetsOfAdditionalDetailsAndDetailsAdditionalInformation.Property,
	|	PRESENTATION(SetsOfAdditionalDetailsAndDetailsAdditionalInformation.Property),
	|	FALSE
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo AS SetsOfAdditionalDetailsAndDetailsAdditionalInformation
	|WHERE
	|	SetsOfAdditionalDetailsAndDetailsAdditionalInformation.Ref IN (&Sets)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AddlAttributesAndInfo.Property,
	|	AddlAttributesAndInfo.Presentation,
	|	AddlAttributesAndInfo.IsAddlAttribute,
	|	AdditionalAttributesAndInfo.ValueType
	|FROM
	|	AddlAttributesAndInfo AS AddlAttributesAndInfo
	|		INNER JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
	|		ON AddlAttributesAndInfo.Property = AdditionalAttributesAndInfo.Ref";
	
	Indus = 0;
	TypesDetailsBoolean = New TypeDescription("Boolean");
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.ValueType = TypesDetailsBoolean Then
			NewRow = AddlAttributesPropertiesTableOfBooleanType.Add();
		Else
			
		NewCommand = Commands.Add("SetOptionByProperty_" + XMLString(Indus));
		NewCommand.Action = "SwitchNavigationPanel";
		
		ItemButtonSubmenu = Items.Add("AdditionalButtonPropertyNavigationOptionSelection" + XMLString(Indus), 
			Type("FormButton"), Items.SelectNavigationOption);
		ItemButtonSubmenu.Type = FormButtonType.CommandBarButton;
		ItemButtonSubmenu.CommandName = NewCommand.Name;
		ItemButtonSubmenu.Title = NStr("en = 'By';") + " " + Selection.Presentation;
			
			NewRow = AddlAttributesPropertiesTable.Add();
			NewRow.SequenceNumber = Indus;
			Indus = Indus + 1;
			
		EndIf;
		
		NewRow.AddlAttributeInfo = Selection.Property;
		NewRow.IsAttribute = Selection.IsAddlAttribute;
		NewRow.Presentation = Selection.Presentation;
		
	EndDo;
	
	If AddlAttributesPropertiesTableOfBooleanType.Count() > 0 Then
	
		NewCommand = Commands.Add("SetOptionByCategories");
		NewCommand.Action = "SwitchNavigationPanel";
		
		ItemButtonSubmenu = Items.Add("AdditionalButtonCategoryNavigationOptionSelection", 
			Type("FormButton"), Items.SelectNavigationOption);
		ItemButtonSubmenu.Type = FormButtonType.CommandBarButton;
		ItemButtonSubmenu.CommandName = NewCommand.Name;
		ItemButtonSubmenu.Title = NStr("en = 'By categories';");
	
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
//    Saving node statuses and navigation panel tree values.

&AtClientAtServerNoContext
Function GetSavedSettingsOfNavigationPanelTree(
	CurrentPageNameOfNavigationPanel,
	CurrentPropertyOfNavigationPanel,
	NavigationPanelTreesSettings)

	If CurrentPageNameOfNavigationPanel = "EmailSubjectPage" Then
		TreeName = "Subjects";
		SettingName = "Subjects";
	ElsIf CurrentPageNameOfNavigationPanel = "ContactPage" Then
		TreeName = "Contacts";
		SettingName = "Contacts";
	ElsIf CurrentPageNameOfNavigationPanel = "CategoriesPage" Then
		TreeName = "Categories";
		SettingName = "Categories";
	ElsIf CurrentPageNameOfNavigationPanel = "FoldersPage" Then
		TreeName = "Folders";
		SettingName = "Folders";
	ElsIf CurrentPageNameOfNavigationPanel = "PropertiesPage" Then
		TreeName = "Properties";
		SettingName = "Properties_" + String(CurrentPropertyOfNavigationPanel);
	ElsIf CurrentPageNameOfNavigationPanel = "TabsPage" Then
		TreeName = "Tabs";
		SettingName = "Tabs";
	Else
		Return Undefined;
	EndIf;
	
	FoundRows =  NavigationPanelTreesSettings.FindRows(New Structure("TreeName", SettingName));
	If FoundRows.Count() = 1 Then
		SettingsTreeRow = FoundRows[0];
	ElsIf FoundRows.Count() > 1 Then
		SettingsTreeRow = FoundRows[0];
		For Indus = 1 To FoundRows.Count()-1 Do
			NavigationPanelTreesSettings.Delete(FoundRows[Indus]);
		EndDo;
	Else
		Return Undefined;
	EndIf;
	
	Return New Structure("TreeName,SettingsValue",TreeName,SettingsTreeRow);

EndFunction

&AtClient
Procedure SaveNodeStateInSettings(TreeName, Value, Expansion);
	
	If TreeName = "Properties" Then
		TreeName =  "Properties_" + String(CurrentPropertyOfNavigationPanel);
	EndIf;
	
	FoundRows =  NavigationPanelTreesSettings.FindRows(New Structure("TreeName",TreeName));
	If FoundRows.Count() = 1 Then
		SettingsTreeRow = FoundRows[0];
	ElsIf FoundRows.Count() > 1 Then
		SettingsTreeRow = FoundRows[0];
		For Indus = 1 To FoundRows.Count()-1 Do
			NavigationPanelTreesSettings.Delete(FoundRows[Indus]);
		EndDo;
	Else
		If Expansion Then
			SettingsTreeRow = NavigationPanelTreesSettings.Add();
			SettingsTreeRow.TreeName = TreeName;
		Else
			Return;
		EndIf;
	EndIf;
	
	FoundListItem = SettingsTreeRow.ExpandedNodes.FindByValue(Value);
	
	If Expansion Then
		
		If FoundListItem = Undefined Then
			
			SettingsTreeRow.ExpandedNodes.Add(Value);
			
		EndIf;
		
	Else
		
		If FoundListItem <> Undefined Then
			
			SettingsTreeRow.ExpandedNodes.Delete(FoundListItem);
			
		EndIf;
	
	EndIf;
	
EndProcedure

&AtClient
Procedure RestoreExpandedTreeNodes()
	
	If Items.NavigationPanelPages.CurrentPage = Items.EmailSubjectPage 
		Or Items.NavigationPanelPages.CurrentPage = Items.ContactPage Then
		AttachIdleHandler("ProcessNavigationPanelRowActivation", 0.2, True);
		Return;
	EndIf;
	
	Settings = GetSavedSettingsOfNavigationPanelTree(Items.NavigationPanelPages.CurrentPage.Name,
		CurrentPropertyOfNavigationPanel,NavigationPanelTreesSettings);
	If Settings = Undefined Or Settings.TreeName = "Categories" Then
		Return;
	EndIf;
	
	ExpandedNodes = Settings.SettingsValue.ExpandedNodes;
	If ExpandedNodes.Count() = 0 Then
		Return;
	EndIf;

	ExpandedNodesIDs = New Map;
	DetermineExpandedNodesIDs(ExpandedNodes, ThisObject[Settings.TreeName].GetItems(),
		ExpandedNodesIDs);

	For Each NodeID In ExpandedNodesIDs Do
		Items[Settings.TreeName].Expand(NodeID.Value);
	EndDo;
	
	DeletedNodes = New Array;
	For Each ListItem In ExpandedNodes Do
		If ExpandedNodesIDs[ListItem.Value] = Undefined Then
			DeletedNodes.Add(ListItem);
		EndIf;
	EndDo;
	For Each ListItem In DeletedNodes Do
		ExpandedNodes.Delete(ListItem);
	EndDo;

EndProcedure

&AtClient
Procedure DetermineExpandedNodesIDs(ExpandedNodesList, TreeRows, NodesIDs)

	For Each Item In TreeRows Do
		If ExpandedNodesList.FindByValue(Item.Value) <> Undefined Then
			ParentElement = Item.GetParent();
			If ParentElement = Undefined Or NodesIDs[ParentElement.Value] <> Undefined Then
				NodesIDs[Item.Value] = Item.GetID();
			EndIf;
		EndIf;
		DetermineExpandedNodesIDs(ExpandedNodesList, Item.GetItems(), NodesIDs);
	EndDo;
		
EndProcedure

&AtServer
Procedure PositionOnRowAccordingToSavedValue(CurrentRowValue,
	                                                             TagName,
	                                                             RowAll = Undefined)
	
	CurrentTable = Items[TagName]; // FormTable
	If CurrentRowValue <> Undefined Then
		If TagName <> "Categories" Then
			FoundRowID = FindStringInFormDataTree(ThisObject[TagName],
				CurrentRowValue,"Value",True);
		Else
			FoundRowID = FindRowInCollectionFormData(ThisObject[TagName],
				CurrentRowValue,"Value");
		EndIf;
		
		If FoundRowID > 0 Then
			CurrentTable.CurrentRow = FoundRowID;
		Else
			CurrentTable.CurrentRow = ?(RowAll = Undefined, 0, RowAll.GetID());
		EndIf;
	Else
		CurrentTable.CurrentRow = ?(RowAll = Undefined, 0, RowAll.GetID());
	EndIf;

EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Procedures and functions of command processing.

// Set a responsible person for selected interactions - the server part.
// Parameters:
//  Interactions - a list of selected interactions.
//  EmployeeResponsible - User the interaction is assigned to.
//
&AtServer
Procedure SetEmployeeResponsible(EmployeeResponsible, Val DataForProcessing)
	
	UpdateNavigationPanel = False;
	
	If DataForProcessing <> Undefined Then
		
		For Each Interaction In DataForProcessing Do
			If ValueIsFilled(Interaction)
				And Interaction.EmployeeResponsible <> EmployeeResponsible Then
				
				Interactions.ReplaceEmployeeResponsibleInDocument(Interaction, EmployeeResponsible);
				UpdateNavigationPanel = True;
				
			EndIf;
		EndDo;
		
	Else
		
		InteractionsArray = GetInteractionsByListFilter(EmployeeResponsible,"EmployeeResponsible");
		
		For Each Interaction In InteractionsArray Do
			
			Interactions.ReplaceEmployeeResponsibleInDocument(Interaction, EmployeeResponsible);
			UpdateNavigationPanel = True;
			
		EndDo; 
		
	EndIf;
	
	If UpdateNavigationPanel Then
		RefreshNavigationPanel(, Not IsPanelWithDynamicList(CurrentNavigationPanelName));
	EndIf;
	
EndProcedure

// Set the Reviewed flag for selected interactions - the server part.
// Parameters:
//  Interactions - a list of selected interactions.
//
&AtServer
Procedure SetReviewedFlag(Val DataForProcessing, Val FlagValue)
	
	UpdateNavigationPanel = False;
	
	If DataForProcessing <> Undefined Then
		
		InteractionsArray = New Array;
		
		For Each Interaction In DataForProcessing Do
			If ValueIsFilled(Interaction) Then
				InteractionsArray.Add(Interaction);
			EndIf;
		EndDo;
		
		Interactions.MarkAsReviewed(InteractionsArray, FlagValue, UpdateNavigationPanel);
		
	Else
		
		InteractionsArray = GetInteractionsByListFilter(FlagValue, "Reviewed");
		Interactions.MarkAsReviewed(InteractionsArray, FlagValue, UpdateNavigationPanel);
		
	EndIf;
	
	If UpdateNavigationPanel Then
		RefreshNavigationPanel(, Not IsPanelWithDynamicList(CurrentNavigationPanelName));
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function IsPanelWithDynamicList(CurrentNavigationPanelName)

	If CurrentNavigationPanelName = "EmailSubjectPage" Or CurrentNavigationPanelName = "ContactPage" Then
		Return True;
	Else
		Return False;
	EndIf;

EndFunction

&AtServer
Function AddToTabsServer(Val DataForProcessing, FormItemName)
	
	Result = New Structure;
	Result.Insert("ItemAdded", False);
	Result.Insert("ItemURL", "");
	Result.Insert("ItemPresentation", "");
	Result.Insert("ErrorMessageText1", "");
		
	CompositionSchema = DocumentJournals.Interactions.GetTemplate("SchemaInteractionsFilter");
	SchemaURL = PutToTempStorage(CompositionSchema, UUID);
	
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
	SettingsComposer.LoadSettings(CompositionSchema.DefaultSettings);
	
	If StrStartsWith(FormItemName, "List") Then
		
		InteractionsList = New ValueList;
		
		For Each Interaction In DataForProcessing Do
			If ValueIsFilled(Interaction) Then
				InteractionsList.Add(Interaction);
			EndIf;
		EndDo;
		
		If InteractionsList.Count() = 0 Then
			Result.ErrorMessageText1 = NStr("en = 'Select an item you want to add to bookmarks.';");
			Return Result;
		EndIf;
		
		CommonClientServer.AddCompositionItem(SettingsComposer.Settings.Filter,
			"Ref", DataCompositionComparisonType.InList, InteractionsList);
		TabDescription = ?(OnlyEmail, NStr("en = 'Favorite Mails';"), NStr("en = 'Favorite interactions';"));
		If InteractionsList.Count() > 1 Then
			Text = ?(OnlyEmail, NStr("en = 'Selected mails (%1)';"), NStr("en = 'Selected interactions (%1)';"));
			Result.ItemPresentation = StringFunctionsClientServer.SubstituteParametersToString(Text, InteractionsList.Count());
		Else
			Result.ItemPresentation = Common.SubjectString(InteractionsList[0].Value);
			Result.ItemURL = GetURL(InteractionsList[0].Value);
		EndIf;
	Else
		
		If DataForProcessing.Value = "AllValues" Then
			Result.ErrorMessageText1 = NStr("en = 'Cannot create a bookmark without a filter.';");
			Return Result;
		EndIf;
		
		FilterGroupByNavigationPanel = CommonClientServer.FindFilterItemByPresentation(
		    InteractionsClientServer.DynamicListFilter(List).Items,
		    "FIlterNavigationPanel");
		If FilterGroupByNavigationPanel = Undefined Then
			Result.ErrorMessageText1 = NStr("en = 'Select an item you want to add to bookmarks.';");
			Return Result;
		EndIf;
		
		CopyFilter(SettingsComposer.Settings.Filter, FilterGroupByNavigationPanel, True);
		If FormItemName = "NavigationPanelSubjects" Then
			
			If Common.RefTypeValue(DataForProcessing.Value) Then
				TabDescription       = NStr("en = 'Topic';") + " = " + String(DataForProcessing.Value); 
				Text = ?(OnlyEmail, NStr("en = 'Mails on topic %1';"), NStr("en = 'Interactions on topic %1';"));
				Result.ItemPresentation = StringFunctionsClientServer.SubstituteParametersToString(Text, Common.SubjectString(DataForProcessing.Value));
				Result.ItemURL = GetURL(DataForProcessing.Value);
			Else
				Result.ErrorMessageText1 = NStr("en = 'Select an item you want to add to bookmarks.';");
				Return Result;
			EndIf;
			
		ElsIf FormItemName = "Properties" Then
			
			CurrentPropertyDescription = Common.ObjectAttributeValue(CurrentPropertyOfNavigationPanel, "Description");
			
			If TypeOf(DataForProcessing.Value) = Type("String") 
				And DataForProcessing.Value = "NotSpecified" Then
				TabDescription       = CurrentPropertyDescription + " " + NStr("en = 'not specified';");
				Result.ItemPresentation = ?(OnlyEmail, NStr("en = 'Mail messages';"), NStr("en = 'Interactions';"));
			Else
				TabDescription       = CurrentPropertyDescription + " = " + String(DataForProcessing.Value);
				Result.ItemPresentation = ?(OnlyEmail, 
				                                   NStr("en = 'Mail messages with the property: %1';"), 
				                                   NStr("en = 'Interactions with the property: %1';"));
				Result.ItemPresentation = 
					StringFunctionsClientServer.SubstituteParametersToString(Result.ItemPresentation, DataForProcessing.Value);
			EndIf;
			
		ElsIf FormItemName = "Categories" Then
			
			TabDescription       = NStr("en = 'Included in category';") + " " + String(DataForProcessing.Value);
			Result.ItemPresentation = ?(OnlyEmail, NStr("en = 'Mail messages in category: %1';"), NStr("en = 'Interactions in category: %1';"));
			Result.ItemPresentation = 
				StringFunctionsClientServer.SubstituteParametersToString(Result.ItemPresentation, DataForProcessing.Value);
			
		ElsIf FormItemName = "NavigationPanelContacts" Then
			
			If Common.RefTypeValue(DataForProcessing.Value) Then
				TabDescription       = NStr("en = 'Contact';") + " = " + String(DataForProcessing.Value); 
				Text = ?(OnlyEmail, NStr("en = 'Email conversations with: %1';"), NStr("en = 'Interactions with: %1';"));
				Result.ItemPresentation = 
					StringFunctionsClientServer.SubstituteParametersToString(Text, Common.SubjectString(DataForProcessing.Value));
				Result.ItemURL = GetURL(DataForProcessing.Value);
			Else
				Result.ErrorMessageText1 = NStr("en = 'Select an item you want to add to bookmarks.';");
				Return Result;
			EndIf;

		ElsIf FormItemName = "Folders" Then
			
			TabDescription       = NStr("en = 'In folder';") + " " + String(DataForProcessing.Value);
			Result.ItemPresentation = ?(OnlyEmail, NStr("en = 'Mail messages in folder: %1';"), NStr("en = 'Interactions in folder: %1';"));
			Result.ItemPresentation = StringFunctionsClientServer.SubstituteParametersToString(Result.ItemPresentation, DataForProcessing.Value);
			
		EndIf;
		
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	InteractionsTabs.Ref,
	|	InteractionsTabs.Description,
	|	InteractionsTabs.SettingsComposer
	|FROM
	|	Catalog.InteractionsTabs AS InteractionsTabs
	|WHERE
	|	NOT InteractionsTabs.IsFolder
	|	AND NOT InteractionsTabs.DeletionMark";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		If ValueInXML(SettingsComposer.GetSettings()) =  ValueInXML(Selection.SettingsComposer.Get()) Then
			Result.ErrorMessageText1 = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'A bookmark with the same settings already exists: %1';"),
				Selection.Description);
			Return Result;
		EndIf;
	EndDo;
	
	Bookmark = Catalogs.InteractionsTabs.CreateItem();
	Bookmark.Owner = Users.AuthorizedUser();
	Bookmark.Description = TabDescription;
	Bookmark.SettingsComposer = New ValueStorage(SettingsComposer.GetSettings());
	Bookmark.Write();
	
	Items.Tabs.Refresh();
	
	Result.ItemAdded = True;
	Return Result;
	
EndFunction

&AtServerNoContext
Function ValueInXML(Value)
	
	Record = New XMLWriter();
	Record.SetString();
	XDTOSerializer.WriteXML(Record, Value);
	Return Record.Close();
	
EndFunction

// Set a subject for selected interactions - the server part.
// Parameters:
//  Interactions - a list of selected interactions.
//  SubjectOf - Topic to set.
//
&AtServer
Procedure SetSubject(SubjectOf, Val DataForProcessing)
	
	If DataForProcessing <> Undefined Then
		
		Query = New Query;
		Query.Text = "SELECT
		|	Interactions.Ref
		|FROM
		|	DocumentJournal.Interactions AS Interactions
		|		INNER JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|		ON Interactions.Ref = InteractionsFolderSubjects.Interaction
		|WHERE
		|	InteractionsFolderSubjects.SubjectOf <> &SubjectOf
		|	AND Interactions.Ref IN (&InteractionsArray)";
		
		Query.SetParameter("InteractionsArray",DataForProcessing );
		Query.SetParameter("SubjectOf", SubjectOf);
		
		InteractionsArray = Query.Execute().Unload().UnloadColumn("Ref");
		
	Else
		
		InteractionsArray = GetInteractionsByListFilter(SubjectOf, "SubjectOf");
		
	EndIf;
	
	If InteractionsArray.Count() > 0 Then
		InteractionsServerCall.SetSubjectForInteractionsArray(InteractionsArray, SubjectOf, True);
		RefreshNavigationPanel();
	EndIf;
	
EndProcedure

&AtServer
Procedure DeferReview(ReviewDate, Val DataForProcessing)
	
	If DataForProcessing <> Undefined Then
		
		InteractionsArray = Interactions.InteractionsArrayForReviewDateChange(DataForProcessing, ReviewDate);
		
	Else
		
		InteractionsArray = GetInteractionsByListFilter(True, "Reviewed");
		
	EndIf;
	
	For Each Interaction In InteractionsArray Do
		
		Attributes = InformationRegisters.InteractionsFolderSubjects.InteractionAttributes();
		Attributes.ReviewAfter        = ReviewDate;
		Attributes.CalculateReviewedItems = False;
		InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(Interaction, Attributes);
		
	EndDo;
	
	If InteractionsArray.Count() > 0 Then
		RefreshNavigationPanel();
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateNewInteraction(ObjectType)
	
	CreationParameters = New Structure;
	
	If CurrentNavigationPanelName = "ContactPage" Then
		CurrentData = Items.NavigationPanelContacts.CurrentData;
		If CurrentData <> Undefined Then
			CreationParameters.Insert("FillingValues", New Structure("Contact", CurrentData.Contact));
		EndIf;
	ElsIf CurrentNavigationPanelName = "EmailSubjectPage" Then
		CurrentData = Items.NavigationPanelSubjects.CurrentData;
		If CurrentData <> Undefined Then
			CreationParameters.Insert("FillingValues", New Structure("SubjectOf", CurrentData.SubjectOf));
		EndIf;
	ElsIf CurrentNavigationPanelName = "FoldersPage" Then
		CurrentData = Items.Folders.CurrentData;
		If CurrentData <> Undefined Then
			CreationParameters.Insert("FillingValues", New Structure("Account", CurrentData.Account));
		EndIf;
	EndIf;
	
	InteractionsClient.CreateNewInteraction(ObjectType, CreationParameters, ThisObject);
	
EndProcedure

&AtServer
Function GetInteractionsByListFilter(AdditionalFilterAttributeValue = Undefined, AdditionalFilterAttributeName = "")
	
	Query = New Query;
	
	If Items.NavigationPanelPages.CurrentPage = Items.ContactPage
		Or Items.NavigationPanelPages.CurrentPage = Items.TabsPage Then
		FilterScheme = DocumentJournals.Interactions.GetTemplate("SchemaFilterInteractionsContact");
	Else
		FilterScheme = DocumentJournals.Interactions.GetTemplate("SchemaInteractionsFilter");
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer();
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(FilterScheme));
	SettingsComposer.LoadSettings(FilterScheme.DefaultSettings);
	
	CopyFilter(SettingsComposer.Settings.Filter, InteractionsClientServer.DynamicListFilter(List));
	
	// Add a filter with comparison type NOT for group commands.
	If AdditionalFilterAttributeValue <> Undefined Then
		FilterElement = SettingsComposer.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterElement.LeftValue = New DataCompositionField(AdditionalFilterAttributeName);
		FilterElement.ComparisonType = DataCompositionComparisonType.NotEqual;
		FilterElement.RightValue = AdditionalFilterAttributeValue;
	EndIf;
	
	DataCompositionTemplate = TemplateComposer.Execute(FilterScheme, SettingsComposer.GetSettings()
		,,, Type("DataCompositionValueCollectionTemplateGenerator"));
	
	QueryText = DataCompositionTemplate.DataSets.MainDataSet.Query;
	
	For Each Parameter In DataCompositionTemplate.ParameterValues Do
		Query.Parameters.Insert(Parameter.Name, Parameter.Value);
	EndDo;
	
	Query.Text = QueryText;
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

&AtServer
Procedure SetFolderParent(Val Folder, Val NewParent)
	
	Interactions.SetFolderParent(Folder, NewParent);
	RefreshNavigationPanel();
	
EndProcedure

&AtServer
Procedure ExecuteTransferToEmailsArrayFolder(Val EmailsArray, Val Folder)

	Interactions.SetFolderForEmailsArray(EmailsArray, Folder);
	RefreshNavigationPanel(Folder);

EndProcedure

/////////////////////////////////////////////////////////////////////////////////////////
// Full-text search.

&AtServer
Procedure DetermineAvailabilityFullTextSearch() 
	
	If GetFunctionalOption("UseFullTextSearch") 
		And FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Enable Then
		SearchHistory = Common.CommonSettingsStorageLoad("InteractionSearchHistory", "");
		If SearchHistory <> Undefined Then
			Items.SearchString.ChoiceList.LoadValues(SearchHistory);
		EndIf;
	Else
		Items.SearchString.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteFullTextSearch()
	
	Result = InteractionSearchResultFullTextSearch();
	
	If Not Result.HasError  Then
		AdvancedSearch = True;
		NotificationText1 = StringFunctionsClientServer.SubstituteParametersToString(
			?(OnlyEmail, NStr("en = 'Found emails: %1.';"), NStr("en = 'Found business interactions: %1.';")), 
			String(Result.FoundItemsCount2));
		ShowUserNotification(NStr("en = 'Search results';"),, NotificationText1);
		CurrentData = Items.List.CurrentData;
		If CurrentData <> Undefined Then
			FillInTheDescriptionFoundByFullTextSearch(Items.List.CurrentData.Ref);
		Else
			DetailsFoundByFullTextSearch = "";
		EndIf;
	Else
		If Result.ErrorID = "FoundNothing" Then
			AdvancedSearch = False;
		Else
			ShowUserNotification(Result.ErrorText);
		EndIf;
	EndIf;
	
	Items.DetailsFoundByFullTextSearch.Visible = AdvancedSearch;
	
EndProcedure

&AtServer
Function InteractionSearchResultFullTextSearch()

	Result = New Structure;
	Result.Insert("HasError", False);
	Result.Insert("ErrorText",                "");
	Result.Insert("ErrorID",        "");
	Result.Insert("FoundItemsCount2", 0);
	
	// Set up search parameters.
	SearchArea = New Array;
	PortionSize = 200;
	
	FullTextSearchString = SearchString;
	If StrFind(FullTextSearchString, "*") = 0 Then
		FullTextSearchString = "*" + FullTextSearchString + "*";
	EndIf;
	
	SearchResultsList = FullTextSearch.CreateList(FullTextSearchString, PortionSize);
	SearchArea.Add(Metadata.Documents.IncomingEmail);
	SearchArea.Add(Metadata.Documents.OutgoingEmail);
	SearchArea.Add(Metadata.Catalogs.IncomingEmailAttachedFiles);
	SearchArea.Add(Metadata.Catalogs.OutgoingEmailAttachedFiles);
	SearchArea.Add(Metadata.InformationRegisters.InteractionsFolderSubjects);

	If Not OnlyEmail Then
		SearchArea.Add(Metadata.Documents.PhoneCall);
		SearchArea.Add(Metadata.Documents.Meeting);
		SearchArea.Add(Metadata.Documents.PlannedInteraction);
		SearchArea.Add(Metadata.Catalogs.PhoneCallAttachedFiles);
		SearchArea.Add(Metadata.Catalogs.MeetingAttachedFiles);
		SearchArea.Add(Metadata.Catalogs.PlannedInteractionAttachedFiles);
	EndIf;
	SearchResultsList.SearchArea = SearchArea;

	SearchResultsList.FirstPart();

	// Return if search has too many results.
	If SearchResultsList.TooManyResults() Then
		CommonClientServer.SetDynamicListFilterItem(
			List,
			"Search",
			Documents.IncomingEmail.EmptyRef(),
			DataCompositionComparisonType.Equal,, True);
		Items.SearchString.BackColor = StyleColors.ErrorFullTextSearchBackground;
		
		Result.HasError = True;
		Result.ErrorID = "TooManyResults";
		Result.ErrorText = NStr("en = 'Too many results. Please narrow your search.';");
		Return Result;
		
	EndIf;

	// Return if search has no results.
	If SearchResultsList.TotalCount() = 0 Then
		CommonClientServer.SetDynamicListFilterItem(
			List,
			"Search",
			Documents.IncomingEmail.EmptyRef(),
			DataCompositionComparisonType.Equal,, True);
		Items.SearchString.BackColor = StyleColors.ErrorFullTextSearchBackground;
		
		Result.HasError          = True;
		Result.ErrorID = "FoundNothing";
		Result.ErrorText         = NStr("en = 'No result found.';");
		Return Result;

	EndIf;
	
	Result.FoundItemsCount2 = SearchResultsList.TotalCount();
	
	StartPosition = 0;
	EndPosition = ?(Result.FoundItemsCount2 > PortionSize, PortionSize, Result.FoundItemsCount2) - 1;
	HasNextBatch = True;

	// Process the FTS results by portions.
	While HasNextBatch Do
		For ItemsCounter = 0 To EndPosition Do
			
			Item = SearchResultsList.Get(ItemsCounter);
			NewRow = FullTextSearchResultDetails.Add();
			FillPropertyValues(NewRow,Item);
			If InteractionsClientServer.IsAttachedInteractionsFile(Item.Value) Then
				NewRow.Interaction = Item.Value.FileOwner;
			ElsIf TypeOf(Item.Value) = Type("InformationRegisterRecordKey.InteractionsFolderSubjects") Then
				NewRow.Interaction =  Item.Value.Interaction;
			Else
				NewRow.Interaction = Item.Value;
			EndIf;
			
		EndDo;
		StartPosition = StartPosition + PortionSize;
		HasNextBatch = (StartPosition < Result.FoundItemsCount2 - 1);
		If HasNextBatch Then
			EndPosition = 
			?(Result.FoundItemsCount2 > StartPosition + PortionSize, PortionSize,
			Result.FoundItemsCount2 - StartPosition) - 1;
			SearchResultsList.NextPart();
		EndIf;
	EndDo;
	
	If FullTextSearchResultDetails.Count() = 0 Then
		CommonClientServer.SetDynamicListFilterItem(
			List,
			"Search",
			Documents.IncomingEmail.EmptyRef(),
			DataCompositionComparisonType.Equal,, True);
		Items.SearchString.BackColor = StyleColors.ErrorFullTextSearchBackground;
		
		Result.HasError          = True;
		Result.ErrorID = "FoundNothing";
		Result.ErrorText         = NStr("en = 'No result found.';");
		Return Result;
	EndIf;
	
	// Deleting an item from search history if it was there.
	NumberOfFoundListItem = Items.SearchString.ChoiceList.FindByValue(SearchString);
	While NumberOfFoundListItem <> Undefined Do
		Items.SearchString.ChoiceList.Delete(NumberOfFoundListItem);
		NumberOfFoundListItem = Items.SearchString.ChoiceList.FindByValue(SearchString);
	EndDo;
	
	// And put it on top.
	Items.SearchString.ChoiceList.Insert(0, SearchString);
	While Items.SearchString.ChoiceList.Count() > 100 Do
		Items.SearchString.ChoiceList.Delete(Items.SearchString.ChoiceList.Count() - 1);
	EndDo;
	Common.CommonSettingsStorageSave(
		"InteractionSearchHistory",
		"",
		Items.SearchString.ChoiceList.UnloadValues());
	
	CommonClientServer.SetDynamicListFilterItem(
			List,
			"Search",
			FullTextSearchResultDetails.Unload(,"Interaction").UnloadColumn("Interaction"),
			DataCompositionComparisonType.InList,, True);
			
	Items.SearchString.BackColor = StyleColors.FieldBackColor;
	
	Return Result;
	
EndFunction

&AtClient
Procedure FillInTheDescriptionFoundByFullTextSearch(Interaction)

	DetailsString = FullTextSearchResultDetails.FindRows(New Structure("Interaction", Interaction));
	If DetailsString.Count() = 0 Then
		DetailsFoundByFullTextSearch = "";
		Return;
	EndIf;

	TableRowWithDetails = DetailsString[0];
	If InteractionsClientServer.IsAttachedInteractionsFile(TableRowWithDetails.Value) Then
		TextFound = NStr("en = 'Found in attachment %1.';");
	Else
		TextFound = NStr("en = 'Found in %1.';");
	EndIf;
	
	DetailsFoundByFullTextSearch = StringFunctionsClientServer.SubstituteParametersToString(TextFound,
		TableRowWithDetails.LongDesc);

EndProcedure 

///////////////////////////////////////////////////////////////////////////////
// Miscellaneous.

&AtServer
Function FindRowInCollectionFormData(WhereToFind, Value, Column)

	FoundRows = WhereToFind.FindRows(New Structure(Column, Value));
	If FoundRows.Count() > 0 Then
		Return FoundRows[0].GetID();
	EndIf;
	
	Return -1;
	
EndFunction

&AtServer
Function FindStringInFormDataTree(WhereToFind, Value, Column, SearchSubordinateItems)
	
	TreeItems = WhereToFind.GetItems();
	
	For Each TreeItem In TreeItems Do
		If TreeItem[Column] = Value Then
			Return TreeItem.GetID();
		ElsIf  SearchSubordinateItems Then
			FoundRowID1 =  FindStringInFormDataTree(TreeItem, Value,Column, SearchSubordinateItems);
			If FoundRowID1 >=0 Then
				Return FoundRowID1;
			EndIf;
		EndIf;
	EndDo;
	
	Return -1;
	
EndFunction

&AtClient
Function CurrentItemNavigationPanelList()

	If Items.NavigationPanelPages.CurrentPage = Items.ContactPage Then
		Return Items.NavigationPanelContacts;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.EmailSubjectPage Then
		Return Items.NavigationPanelSubjects;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.FoldersPage Then
		Return Items.Folders;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.PropertiesPage Then
		Return Items.Properties;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.CategoriesPage Then
		Return Items.Categories;
	Else
		Return Undefined;
	EndIf;

EndFunction

&AtClient
Function CorrectChoice(ListName, ByCurrentString = False)
	
	GroupingType = Type("DynamicListGroupRow");
	If ByCurrentString Then
		
		If TypeOf(Items[ListName].CurrentRow) <> GroupingType And Items[ListName].CurrentData <> Undefined Then
			Return True;
		EndIf;
		
	Else
		
		For Each Item In Items[ListName].SelectedRows Do
			If TypeOf(Item) <> GroupingType Then
				Return True;
			EndIf;
		EndDo;
		
	EndIf;
	
	Return False;
	
EndFunction 

&AtServer
Procedure CopyFilter(Receiver, Source, DeleteGroupPresentation = False, DeleteUnusedItems = True, DoNotEnableNavigationPanelFilter = False)
	
	For Each SourceFilterItem In Source.Items Do
		
		If DeleteUnusedItems And (Not SourceFilterItem.Use) Then
			Continue;
		EndIf;
		
		If DoNotEnableNavigationPanelFilter And TypeOf(SourceFilterItem) = Type("DataCompositionFilterItemGroup") 
			And SourceFilterItem.Presentation = "FIlterNavigationPanel" Then
			
			Continue;
			
		EndIf;
		
		If TypeOf(SourceFilterItem) = Type("DataCompositionFilterItem") 
			And SourceFilterItem.LeftValue = New DataCompositionField("Search") Then
			Continue;
		EndIf;
		
		FilterElement = Receiver.Items.Add(TypeOf(SourceFilterItem));
		FillPropertyValues(FilterElement, SourceFilterItem);
		If TypeOf(SourceFilterItem) = Type("DataCompositionFilterItemGroup") Then
			If DeleteGroupPresentation Then
				FilterElement.Presentation = "";
			EndIf;
			CopyFilter(FilterElement, SourceFilterItem);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure QuestionOnFolderDeletionAfterCompletion(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		
		ErrorDescription =  DeleteFolderServer(AdditionalParameters.CurrentData.Value);
		If Not IsBlankString(ErrorDescription) Then
			ShowMessageBox(, ErrorDescription);
		Else
			RestoreExpandedTreeNodes();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessingDateChoiceOnCompletion(SelectedDate, AdditionalParameters) Export
	
	CurrentItemName = AdditionalParameters.CurrentItemName;
	
	If SelectedDate <> Undefined Then
		DeferReview(SelectedDate, ?(CurrentItemName = Undefined, Undefined, Items[CurrentItemName].SelectedRows));
		RestoreExpandedTreeNodes();
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateNavigationPanelAtServer()
	
	RefreshNavigationPanel();
	ManageVisibilityOnSwitchNavigationPanel();
	
EndProcedure

&AtServer
Procedure PrepareFormSettingsForCurrentRefOutput(CurrentRef)
	CurrentNavigationPanelName = "EmailSubjectPage";
	If InteractionsClientServer.IsSubject(CurrentRef) Then
		SubjectOf = CurrentRef;
	ElsIf InteractionsClientServer.IsInteraction(CurrentRef) Then
		SubjectOf = Interactions.InteractionAttributesStructure(CurrentRef).SubjectOf;
	Else
		SubjectOf = Undefined;
	EndIf;
	If ValueIsFilled(SubjectOf) Then
		Items.NavigationPanelSubjects.CurrentRow = InformationRegisters.InteractionsSubjectsStates.CreateRecordKey(New Structure("SubjectOf", SubjectOf));
		ChangeFilterList("Subjects", New Structure("Value, TypeDescription", SubjectOf, Undefined));
	EndIf;
EndProcedure

&AtServer
Procedure NavigationProcessingAtServer(Val CurrentRef)
	PrepareFormSettingsForCurrentRefOutput(CurrentRef);
	
	If SearchString <> "" Then
		SearchString = "";
		AdvancedSearch = False;
		CommonClientServer.SetDynamicListFilterItem(List, "Search", Undefined,
			DataCompositionComparisonType.Equal,, False);
		Items.DetailsFoundByFullTextSearch.Visible = AdvancedSearch;
	EndIf;
	
	InteractionType = "All";
	Status = "All";
	EmployeeResponsible = Undefined;
	InteractionsClientServer.QuickFilterListOnChange(ThisObject, "EmployeeResponsible");
	OnChangeTypeServer(True);
	
	NavigationPanelHidden = False;
	Items.NavigationPanelPages.CurrentPage = Items[CurrentNavigationPanelName];
	ManageVisibilityOnSwitchNavigationPanel();
EndProcedure

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.StartCommandExecution(ThisObject, Command, Items.List);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	AttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Items.List);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.AttachableCommands

&AtClient
Procedure WarningAboutUnsafeContentURLProcessing(Item, FormattedStringURL, StandardProcessing)
	If FormattedStringURL = "EnableUnsafeContent" Then
		StandardProcessing = False;
		EnableUnsafeContent = True;
		DisplayInteractionPreview(InteractionPreviewGeneratedFor, Items.PagesPreview.CurrentPage.Name);
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Procedure SetSecurityWarningVisiblity(Form)
	Form.Items.SecurityWarning.Visible = Not Form.UnsafeContentDisplayInEmailsProhibited
		And Form.HasUnsafeContent And Not Form.EnableUnsafeContent;
EndProcedure

&AtClient
Procedure CheckEmailsSendingStatus()
	
	CheckEmailsSendingStatusAtServer();
	Interval = ?(Items.WarningAboutUnsentEmails.Visible, 60, 600);
	AttachIdleHandler("CheckEmailsSendingStatus", Interval, True);
	
EndProcedure

&AtServer
Procedure CheckEmailsSendingStatusAtServer()
	
	Items.WarningAboutUnsentEmails.Visible = Interactions.SendingPaused();
	Items.WarningAboutUnsentEmailsLabel.Title = Interactions.SendingPausedWarningText();
	
EndProcedure

&AtServer
Procedure GenerateImportantContactsOnlyDecoration()
	
	If ImportantContactsOnly Then
		TitleText = StringFunctions.FormattedString(NStr("en = 'Show topics of filtered interactions. <a href = ""%1"">Click to change</a>.';"), 
		                                                        "ChangeImportantContactsOnly");
	Else
		TitleText = StringFunctions.FormattedString(NStr("en = 'Show all topics. <a href = ""%1"">Click to change</a>.';"),
		                                                        "ChangeImportantContactsOnly");
	EndIf;
	
	Items.ImportantContactsOnlyDecoration.Title = TitleText;
	
EndProcedure

&AtServer
Procedure GenerateImportantSubjectsOnlyDecoration()
	
	If ImportantSubjectsOnly Then
		TitleText = StringFunctions.FormattedString(NStr("en = 'Show topics of filtered interactions. <a href = ""%1"">Click to change</a>.';"), 
		                                                        "ChangeImportantSubjectsOnly");
	Else
		TitleText = StringFunctions.FormattedString(NStr("en = 'Show all topics. <a href = ""%1"">Click to change</a>.';"), 
		                                                        "ChangeImportantSubjectsOnly");
	EndIf;
	
	Items.ImportantSubjectsOnlyDecoration.Title = TitleText;
	
EndProcedure

&AtClient
Procedure SendReceiveUserMailClient(DisplayProgress = False)
	
	ClearMessages();
	EmailManagementClient.SendReceiveUserEmail(UUID, ThisObject, 
		Items.List, DisplayProgress);
	AttachIdleHandler("CheckWhetherYouNeedToSendReceiveMail", 30, True);
	
EndProcedure

&AtClient
Procedure CheckWhetherYouNeedToSendReceiveMail()

	If Not DataSeparationEnabled Then
		Return;
	EndIf;
	
	If Not SendReceiveEmailInProgress
		And (CommonClient.SessionDate() > DateOfPreviousEmailReceiptSending + 300) Then
		SendReceiveUserMailClient();
	EndIf;
	
	AttachIdleHandler("CheckWhetherYouNeedToSendReceiveMail", 30, True);
	
EndProcedure

#EndRegion