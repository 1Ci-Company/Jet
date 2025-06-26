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
	
	Interactions.InitializeInteractionsListForm(ThisObject, Parameters);
	Items.CreateEmailSpecialButtonTreeList.Visible = OnlyEmail;
	Items.CreateTreeGroup.Visible = Not OnlyEmail;
	If OnlyEmail Then
		TitleParticipantsMail =  NStr("en = 'To, from';");
		Items.InteractionsTreeAttendees.Title = TitleParticipantsMail;
		Items.Attendees.Title = TitleParticipantsMail;
	EndIf;
	
	
	
	If TypeOf(Parameters.Filter) = Type("Structure") Then
		
		TitleTemplate1 = NStr("en = 'Interactions on: %1';");
		
		If Parameters.Filter.Property("SubjectOf") Then
			
			If TypeOf(Parameters.AdditionalParameters) = Type("Structure") 
				And Parameters.AdditionalParameters.Property("InteractionType") Then
				
				If Parameters.AdditionalParameters.InteractionType = "Interaction" Then
					SubjectForFilter = Interactions.GetSubjectValue(Parameters.Filter.SubjectOf);
					Parameters.Filter.SubjectOf = SubjectForFilter ;
				ElsIf Parameters.AdditionalParameters.InteractionType = "SubjectOf" Then
					SubjectForFilter = Parameters.Filter.SubjectOf;
				EndIf;
			EndIf;
			
			Parameters.Filter.Delete("SubjectOf");
			SetFilterBySubject();
			
			Title = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, Common.SubjectString(SubjectForFilter));
			
		ElsIf Parameters.Filter.Property("Contact") Then
			
			Contact = Parameters.Filter.Contact;
			Title = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, Common.SubjectString(Contact));
			Parameters.Filter.Delete("Contact");
			SetFilterByContact();
			
		EndIf;
	EndIf;
	
	Interactions.FillListOfDocumentsAvailableForCreation(DocumentsAvailableForCreation);
	Interactions.FillSubmenuByInteractionType(Items.TreeInteractionType, ThisObject);
	Interactions.FillSubmenuByInteractionType(Items.InteractionTypeList, ThisObject);
	
	InteractionType = ?(OnlyEmail,"AllEmails","All");
	Status = "All";
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Status = Settings.Get("Status");
	If Status <> Undefined Then
		Settings.Delete("Status");
	EndIf;
	If Not UseReviewedFlag Or Not ValueIsFilled(Status) Then
		Status = "All";
	EndIf;
	EmployeeResponsible = Settings.Get("EmployeeResponsible");
	If EmployeeResponsible <> Undefined Then
		Settings.Delete("EmployeeResponsible");
	EndIf;
	InTreeStructure = Settings.Get("InTreeStructure");
	If InTreeStructure <> Undefined Then
		Settings.Delete("InTreeStructure");
	EndIf;
	
	Interactions.OnImportInteractionsTypeFromSettings(ThisObject, Settings);
	
	PagesManagementServer();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If InteractionsClientServer.IsInteraction(Source) Then
		If Items.TreeListPages.CurrentPage = Items.TreePage Then
			FillInteractionsTreeClient();
		Else
			If IsFilterBySubject Then
				SetFilterBySubject();
			Else
				SetFilterByContact();
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("Catalog.Users.Form.ListForm") Then
		
		If ValueSelected <> Undefined Then
			
			ArrayOfChangedDocuments = New Array;
			WasReplaced = False;
			SetEmployeeResponsible(ValueSelected, ArrayOfChangedDocuments);
			
			If Items.TreeListPages.CurrentPage = Items.ListPage Then
				If ArrayOfChangedDocuments.Count() > 0 Then
					Items.List.Refresh();
				EndIf;
			Else
				If ArrayOfChangedDocuments.Count() > 0  Then
					ExpandAllTreeRows();
				EndIf;
			EndIf;
			
			For Each ChangedDocument In ArrayOfChangedDocuments Do
				
				Notify("WriteInteraction", ChangedDocument);
				
			EndDo;
			
		EndIf;
		
	ElsIf ChoiceContext = "SubjectExecuteSubjectType" Then
		
		If ValueSelected = Undefined Then
			Return;
		EndIf;
		
		ChoiceContext = "SubjectOfExecute";
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		
		OpenForm(ValueSelected + ".ChoiceForm", FormParameters, ThisObject);
		
		Return;
		
	ElsIf ChoiceContext = "SubjectOfExecute" Then
		
		If ValueSelected <> Undefined Then
			
			If IsFilterBySubject And SubjectForFilter = ValueSelected Then
				Return;
			EndIf;
			
			WasReplaced = False;
			SetSubject(ValueSelected, WasReplaced);
			
			If Items.TreeListPages.CurrentPage = Items.ListPage Then
				If WasReplaced Then
					Items.List.Refresh();
				EndIf;
			Else
				If WasReplaced Then
					ExpandAllTreeRows();
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure EmployeeResponsibleOnChange(Item)
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		InteractionsClientServer.QuickFilterListOnChange(ThisObject, Item.Name,, IsFilterBySubject);
		
	Else
		
		FillInteractionsTreeClient();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StatusOnChange(Item)
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		DateForFilter = CommonClient.SessionDate();
		InteractionsClientServer.QuickFilterListOnChange(ThisObject,Item.Name, DateForFilter, IsFilterBySubject);
		
	Else
		
		FillInteractionsTreeClient();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	FillingValues = New Structure("SubjectOf,Contact",SubjectForFilter,Contact);
	
	InteractionsClient.ListBeforeAddRow(
		Item,Cancel,Copy,OnlyEmail,DocumentsAvailableForCreation,
		New Structure("FillingValues", FillingValues));
	
EndProcedure 

&AtClient
Procedure InteractionsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	If CurrentData <> Undefined Then
		StandardProcessing = False;
		ShowValue(, CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure InteractionsTreeBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	If Items.InteractionsTree.SelectedRows.Count() > 0 Then
		
		HasItemsMarkedForDeletion = False;
		For Each SelectedRow In Items.InteractionsTree.SelectedRows Do
			If Items.InteractionsTree.RowData(SelectedRow).DeletionMark Then
				HasItemsMarkedForDeletion = True;
				Break;
			EndIf;
		EndDo;
		
		If HasItemsMarkedForDeletion Then
			QueryText = NStr("en = 'Clear deletion mark from the selected items?';");
		Else
			QueryText = NStr("en = 'Mark the selected lines for deletion?';");
		EndIf;
		
		AdditionalParameters = New Structure("HasItemsMarkedForDeletion", HasItemsMarkedForDeletion);
		OnCloseNotifyHandler = New NotifyDescription("QuestionOnMarkForDeletionAfterCompletion", ThisObject, AdditionalParameters);
		ShowQueryBox(OnCloseNotifyHandler,
		               QueryText,QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure 

&AtClient
Procedure InteractionsTreeBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	CurrentData = Item.CurrentData;
	If CurrentData <> Undefined Then
		ShowValue(, CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure InteractionsTreeBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	If Copy Then
		CurrentData = Item.CurrentData;
		If CurrentData <> Undefined Then
			If TypeOf(CurrentData.Ref) = Type("DocumentRef.IncomingEmail") 
				Or TypeOf(CurrentData.Ref) = Type("DocumentRef.OutgoingEmail") Then
				
				ShowMessageBox(, NStr("en = 'Copying messages is not allowed';"));
				
			ElsIf TypeOf(CurrentData.Ref) = Type("DocumentRef.Meeting") Then
				
				OpenForm("Document.Meeting.ObjectForm",
					New Structure("CopyingValue", CurrentData.Ref), ThisObject);
				
			ElsIf TypeOf(CurrentData.Ref) = Type("DocumentRef.PlannedInteraction") Then
				
				OpenForm("Document.PlannedInteraction.ObjectForm",
					New Structure("CopyingValue", CurrentData.Ref), ThisObject);
				
			ElsIf TypeOf(CurrentData.Ref) = Type("DocumentRef.PhoneCall") Then
				
				OpenForm("Document.PhoneCall.ObjectForm", 
					New Structure("CopyingValue",CurrentData.Ref), ThisObject);
				
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InteractionTypeOnChange(Item)
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		InteractionsClientServer.OnChangeFilterInteractionType(ThisObject, InteractionType);
	Else
		FillInteractionsTreeClient();
	EndIf;
	
EndProcedure

&AtClient
Procedure InteractionTypeStatusClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// Changes filter by the type of interaction in the list.
// 
// Parameters:
//  Command - FormCommand - a running command.
//
&AtClient
Procedure Attachable_ChangeFilterInteractionType(Command)

	ChangeFilterInteractionTypeServer(Command.Name);
	If Items.TreeListPages.CurrentPage <> Items.ListPage Then
		FillInteractionsTreeClient();
	EndIf;

EndProcedure

&AtClient
Procedure ReviewedExecute(Command)
	
	If Not CorrectChoice() Then
		Return;
	EndIf;
	
	FlagReviewed = (Not Command.Name = "NotReviewed");
	
	WasReplaced = False;
	InteractionsArray = New Array;
	SetReviewedFlag(WasReplaced, FlagReviewed, InteractionsArray);
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		If WasReplaced Then
			Items.List.Refresh();
		EndIf;
		
	Else
		
		If WasReplaced Then
			ExpandAllTreeRows();
		EndIf;
		
	EndIf;
	
	If WasReplaced Then
		
		For Each Interaction In InteractionsArray Do
			Notify("WriteInteraction", Interaction);
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EmployeeResponsibleExecute()
	
	If Not CorrectChoice() Then
		Return;
	EndIf;
	
	ChoiceContext = Undefined;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);	
	OpenForm("Catalog.Users.ListForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure SubjectOfExecute()
	
	If Not CorrectChoice() Then
		Return;
	EndIf;
	
	ChoiceContext = "SubjectExecuteSubjectType";
	OpenForm("DocumentJournal.Interactions.Form.SelectSubjectType",,ThisObject);
	
EndProcedure

&AtClient
Procedure SetDateInterval(Command)
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period = Interval;
	CloseNotificationHandler = New NotifyDescription("SelectClosingInterval", ThisObject);
	Dialog.Show(CloseNotificationHandler);
	
EndProcedure 

&AtClient
Procedure DeferReviewExecute(Command)
	
	If Not CorrectChoice() Then
		Return;
	EndIf;
	
	ProcessingDate = CommonClient.SessionDate();
	OnCloseNotifyHandler = New NotifyDescription("DateInputSubmitAfterFinished", ThisObject);
	ShowInputDate(OnCloseNotifyHandler, ProcessingDate, NStr("en = 'Snooze till';"));
	
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
	
	CreateNewInteraction("OutgoingEmail");
	
EndProcedure

&AtClient
Procedure CreateNewInteraction(ObjectType)

	FillingValues = New Structure("SubjectOf,Contact",SubjectForFilter,Contact);
	
	InteractionsClient.CreateNewInteraction(
	          ObjectType,
	          New Structure("FillingValues", FillingValues),
	          ThisObject);

EndProcedure

&AtClient
Procedure CreateSMSMessage(Command)
	
	CreateNewInteraction("SMSMessage");
	
EndProcedure

&AtClient
Procedure SwitchViewMode(Command)
	
	SwitchViewModeServer();
	
EndProcedure 

&AtClient
Procedure RefreshTree(Command)
	
	FillInteractionsTreeClient();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject, "InteractionsTree.Date", Items.InteractionsTreeDate.Name);
	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject, "List.Date", Items.List.Name);

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
	ItemField.Field = New DataCompositionField(Items.InteractionsTree.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("InteractionsTree.Reviewed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UseReviewedFlag");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Font", Metadata.StyleItems.MainListItem.Value);

EndProcedure

&AtServer
Procedure ChangeFilterInteractionTypeServer(CommandName)

	InteractionType = Interactions.InteractionTypeByCommandName(CommandName, OnlyEmail);
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		OnChangeTypeServer();
	EndIf;

EndProcedure

&AtServer
Procedure SetReviewedFlag(WasReplaced, FlagReviewed, InteractionsArray)
	
	WasReplaced = False;
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		SelectedRows = Items.List.SelectedRows;
		GroupingType = Type("DynamicListGroupRow");
		
		For Each Interaction In SelectedRows Do
			If ValueIsFilled(Interaction)
				And TypeOf(Interaction) <> GroupingType Then
					InteractionsArray.Add(Interaction);
			EndIf;
		EndDo;
		
		Interactions.MarkAsReviewed(InteractionsArray,FlagReviewed, WasReplaced);
		
	Else
		
		SelectedRows = Items.InteractionsTree.SelectedRows;
		
		For Each Interaction In SelectedRows Do
		
			TreeItem = InteractionsTree.FindByID(Interaction);
			If TreeItem <> Undefined And (Not TreeItem.Reviewed = FlagReviewed) Then
				InteractionsArray.Add(TreeItem.Ref);
			EndIf;
			
		EndDo;
		
		Interactions.MarkAsReviewed(InteractionsArray,FlagReviewed, WasReplaced);
		
		If WasReplaced Then
			FillInteractionsTree();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEmployeeResponsible(EmployeeResponsible, ArrayOfChangedDocuments)
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		SelectedRows = Items.List.SelectedRows;
		
		GroupingType = Type("DynamicListGroupRow");
		For Each Interaction In SelectedRows Do
			If ValueIsFilled(Interaction)
				And TypeOf(Interaction) <> GroupingType
				And Interaction.EmployeeResponsible <> EmployeeResponsible Then
					Interactions.ReplaceEmployeeResponsibleInDocument(Interaction, EmployeeResponsible);
					ArrayOfChangedDocuments.Add(Interaction);
			EndIf;
		EndDo;
		
	Else
		
		SelectedRows = Items.InteractionsTree.SelectedRows;
		
		For Each Interaction In SelectedRows Do
		
			TreeItem = InteractionsTree.FindByID(Interaction);
			If TreeItem <> Undefined And TreeItem.EmployeeResponsible <> EmployeeResponsible Then
				Interactions.ReplaceEmployeeResponsibleInDocument(TreeItem.Ref, EmployeeResponsible);
				
				ArrayOfChangedDocuments.Add(TreeItem.Ref);
			EndIf;
			
		EndDo;
		
		If ArrayOfChangedDocuments.Count() > 0 Then
			FillInteractionsTree();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetSubject(SubjectOf,WasReplaced)
	
	InteractionsArray = New Array;
		
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		SelectedRows = Items.List.SelectedRows;
		
		GroupingType = Type("DynamicListGroupRow");
		For Each Interaction In SelectedRows Do
			If ValueIsFilled(Interaction)
				And TypeOf(Interaction) <> GroupingType Then
					InteractionsArray.Add(Interaction)
			EndIf;
		EndDo;
		
		If InteractionsArray.Count() > 0 Then
			InteractionsServerCall.SetSubjectForInteractionsArray(InteractionsArray, SubjectOf, True);
			WasReplaced = True;
		EndIf;
		
	Else
		
		SelectedRows = Items.InteractionsTree.SelectedRows;
		
		For Each Interaction In SelectedRows Do
		
			TreeItem = InteractionsTree.FindByID(Interaction);
			If TreeItem <> Undefined And TreeItem.SubjectOf <> SubjectOf Then
				InteractionsArray.Add(TreeItem.Ref);
			EndIf;
			
		EndDo;
		
		If InteractionsArray.Count() > 0 Then
			InteractionsServerCall.SetSubjectForInteractionsArray(InteractionsArray, SubjectOf, True);
			WasReplaced = True;
			FillInteractionsTree();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DeferReview(ReviewDate, WasReplaced = False)
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		SelectedRows = Items.List.SelectedRows;
		InteractionsArray = New Array;
		
		GroupingType = Type("DynamicListGroupRow");
		For Each Interaction In SelectedRows Do
			If ValueIsFilled(Interaction)
				And TypeOf(Interaction) <> GroupingType Then
					InteractionsArray.Add(Interaction);
			EndIf;
		EndDo;
		
		InteractionsArray = Interactions.InteractionsArrayForReviewDateChange(InteractionsArray, ReviewDate);
		
		For Each Interaction In InteractionsArray Do
			
			Attributes = InformationRegisters.InteractionsFolderSubjects.InteractionAttributes();
			Attributes.ReviewAfter        = ReviewDate;
			Attributes.CalculateReviewedItems = False;
			
			InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(Interaction, Attributes);
			WasReplaced = True;
			
		EndDo;
		
	Else
		
		SelectedRows = Items.InteractionsTree.SelectedRows;
		InteractionsArray = New Array;
		
		For Each Interaction In SelectedRows Do
		
			TreeItem = InteractionsTree.FindByID(Interaction);
			If TreeItem <> Undefined And Not TreeItem.Reviewed Then
				
				Attributes = InformationRegisters.InteractionsFolderSubjects.InteractionAttributes();
				Attributes.ReviewAfter        = ReviewDate;
				Attributes.CalculateReviewedItems = False;

				InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(TreeItem.Ref, Attributes);
				WasReplaced = True;
				
			EndIf;
			
		EndDo;
		
		If WasReplaced Then
			FillInteractionsTree();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Function CorrectChoice()
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		If Items.List.SelectedRows.Count() = 0 Then
			Return False;
		EndIf;
		
		For Each Item In Items.List.SelectedRows Do
			If TypeOf(Item) <> Type("DynamicListGroupRow") Then
				Return True;
			EndIf;
		EndDo;
		
		Return False;
		
	Else
		
		If Items.InteractionsTree.SelectedRows.Count() = 0 Then
			Return False;
		Else
			Return True;
		EndIf;
		
	EndIf;
	
EndFunction

&AtServer
Procedure SwitchViewModeServer()
	
	InTreeStructure = Not InTreeStructure;
	
	PagesManagementServer();
	
EndProcedure

&AtServer
Procedure PagesManagementServer()

	If InTreeStructure Then
		Interval = Items.List.Period;
		Commands.SwitchViewMode.ToolTip = NStr("en = 'Switch to List view';");
		Items.TreeListPages.CurrentPage = Items.TreePage;
		FillInteractionsTree();
	Else
		
		DateForFilter = CurrentSessionDate();
		Items.List.Period = Interval;
		Commands.SwitchViewMode.ToolTip = NStr("en = 'Switch to Tree view';");
		Items.TreeListPages.CurrentPage = Items.ListPage;
		InteractionsClientServer.QuickFilterListOnChange(ThisObject,"Status", DateForFilter, IsFilterBySubject);
		InteractionsClientServer.QuickFilterListOnChange(ThisObject,"EmployeeResponsible", DateForFilter, IsFilterBySubject);
		OnChangeTypeServer();
	EndIf;

EndProcedure

&AtServer
Procedure FillInteractionsTree()
	
	If IsFilterBySubject Then
		FilterScheme = DocumentJournals.Interactions.GetTemplate("InteractionsHierarchySubject");
	Else
		FilterScheme = DocumentJournals.Interactions.GetTemplate("InteractionsHierarchyContact");
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer();
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(FilterScheme));
	SettingsComposer.LoadSettings(FilterScheme.DefaultSettings);
	
	If IsFilterBySubject Then
		CommonClientServer.AddCompositionItem(SettingsComposer.Settings.Filter,
			"SubjectOf", DataCompositionComparisonType.Equal, SubjectForFilter);
	Else
		SettingsComposer.Settings.DataParameters.SetParameterValue("Contact",Contact);
	EndIf;
	
	SettingsComposer.Settings.DataParameters.SetParameterValue("Interval",Interval);
	
	CompositionCustomizerFilter = SettingsComposer.Settings.Filter;
	
	If OnlyEmail Then
		
		OtherInteractionsTypesList = New ValueList;
		OtherInteractionsTypesList.Add(Type("DocumentRef.Meeting"));
		OtherInteractionsTypesList.Add(Type("DocumentRef.PlannedInteraction"));
		OtherInteractionsTypesList.Add(Type("DocumentRef.PhoneCall"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"Type", DataCompositionComparisonType.NotInList, OtherInteractionsTypesList);
		
	EndIf;
	
	// The EmployeeResponsible quick filter.
	If Not EmployeeResponsible.IsEmpty() Then
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,"EmployeeResponsible",
			DataCompositionComparisonType.Equal, EmployeeResponsible);
	EndIf;
	
	// Quick filter "Status"
	If Status = "ToReview" Then
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Reviewed", DataCompositionComparisonType.Equal, False);
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"ReviewAfter", DataCompositionComparisonType.LessOrEqual, CurrentSessionDate());
	ElsIf Status = "Deferred3" Then
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Reviewed", DataCompositionComparisonType.Equal, False);
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"ReviewAfter", DataCompositionComparisonType.Filled,);
	ElsIf Status = "ReviewedItems" Then
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"Reviewed" ,DataCompositionComparisonType.Equal, True);
	EndIf;
	
	// The "Interaction type" quick filter.
	If InteractionType = "AllEmails" Or OnlyEmail Then
		
		EmailTypesList = New ValueList;
		EmailTypesList.Add(Type("DocumentRef.IncomingEmail"));
		EmailTypesList.Add(Type("DocumentRef.OutgoingEmail"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type",DataCompositionComparisonType.InList,EmailTypesList);
		
	ElsIf InteractionType = "IncomingMessages" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"Type",DataCompositionComparisonType.Equal,Type("DocumentRef.IncomingEmail"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"DeletionMark", DataCompositionComparisonType.Equal, False);
		
	ElsIf InteractionType = "MessageDrafts" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"Type",DataCompositionComparisonType.Equal,Type("DocumentRef.OutgoingEmail"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"DeletionMark",DataCompositionComparisonType.Equal,False);
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"OutgoingEmailStatus", DataCompositionComparisonType.Equal, 
			Enums.OutgoingEmailStatuses.Draft);
		
	ElsIf InteractionType = "OutgoingMessages" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"Type",DataCompositionComparisonType.Equal,Type("DocumentRef.OutgoingEmail"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"DeletionMark",DataCompositionComparisonType.Equal,False);
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"OutgoingEmailStatus", DataCompositionComparisonType.Equal, 
			Enums.OutgoingEmailStatuses.Outgoing);
		
	ElsIf InteractionType = "SentMessages" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type",DataCompositionComparisonType.Equal, Type("DocumentRef.OutgoingEmail"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"DeletionMark", DataCompositionComparisonType.Equal, False);
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, "OutgoingEmailStatus",
			DataCompositionComparisonType.Equal, 
			Enums.OutgoingEmailStatuses.Sent);
		
	ElsIf InteractionType = "DeletedMessages" Then
		
		EmailTypesList = New ValueList;
		EmailTypesList.Add(Type("DocumentRef.IncomingEmail"));
		EmailTypesList.Add(Type("DocumentRef.OutgoingEmail"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"Type", DataCompositionComparisonType.InList, EmailTypesList);
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"DeletionMark", DataCompositionComparisonType.Equal, True);
		
	ElsIf InteractionType = "Meetings" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type", DataCompositionComparisonType.Equal, Type("DocumentRef.Meeting"));
		
	ElsIf InteractionType = "PlannedInteractions" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type", DataCompositionComparisonType.Equal, Type("DocumentRef.PlannedInteraction"));
		
	ElsIf InteractionType = "PhoneCalls" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type",DataCompositionComparisonType.Equal, Type("DocumentRef.PhoneCall"));
		
	ElsIf InteractionType = "OutgoingCalls" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type",DataCompositionComparisonType.Equal,Type("DocumentRef.PhoneCall"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Incoming",DataCompositionComparisonType.Equal,False);
		
	ElsIf InteractionType = "IncomingCalls" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type",DataCompositionComparisonType.Equal,Type("DocumentRef.PhoneCall"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Incoming",DataCompositionComparisonType.Equal,True);
		
	ElsIf InteractionType = "SMSMessages" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type",DataCompositionComparisonType.Equal,Type("DocumentRef.SMSMessage"));
		
	EndIf;
	
	DataCompositionTemplate = TemplateComposer.Execute(FilterScheme, SettingsComposer.GetSettings(),,,
		Type("DataCompositionValueCollectionTemplateGenerator"));
	
	// Initialize composition processor.
	DataCompositionProcessor = New DataCompositionProcessor;
	DataCompositionProcessor.Initialize(DataCompositionTemplate);
	
	TreeObject = FormAttributeToValue("InteractionsTree");
	TreeObject.Rows.Clear();
	
	// Get the result.
	DataCompositionResultValueCollectionOutputProcessor =
		New DataCompositionResultValueCollectionOutputProcessor;
	DataCompositionResultValueCollectionOutputProcessor.SetObject(TreeObject);
	DataCompositionResultValueCollectionOutputProcessor.Output(DataCompositionProcessor);
	
	ValueToFormAttribute(TreeObject,"InteractionsTree");
	
	TitleTemplate1 = NStr("en = 'Interaction category: %1';");
	TypePresentation = Interactions.FiltersListByInteractionsType(OnlyEmail).FindByValue(InteractionType).Presentation;
	Items.TreeInteractionType.Title = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, TypePresentation);
	For Each SubmenuItem In Items.TreeInteractionType.ChildItems Do
		If SubmenuItem.Name = ("SetFilterInteractionTypeTreeInteractionType" + InteractionType) Then
			SubmenuItem.Check = True;
		Else
			SubmenuItem.Check = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure FillInteractionsTreeClient()

	FillInteractionsTree();
	ExpandAllTreeRows();
	
EndProcedure

&AtClient
Procedure ExpandAllTreeRows()

	For Each UpperLevelRow In InteractionsTree.GetItems() Do
		Items.InteractionsTree.Expand(UpperLevelRow.GetID(), True);
	EndDo;
	
EndProcedure

&AtServer
Procedure ProcessDeletionMarkChangeInTree(Val SelectedRows,ClearMark);
	
	For Each SelectedRow In SelectedRows Do
		
		RowData =InteractionsTree.FindByID(SelectedRow);
		If RowData.DeletionMark = ClearMark Then
			InteractionObject = RowData.Ref.GetObject();
			InteractionObject.SetDeletionMark(Not ClearMark);
			RowData.DeletionMark = Not RowData.DeletionMark;
			RowData.PictureNumber = ?(ClearMark,
			                               RowData.PictureNumber - ?(RowData.Reviewed,5,10),
			                               RowData.PictureNumber + ?(RowData.Reviewed,5,10));
		EndIf;
	EndDo;
	
EndProcedure 

// Gets an array that is passed as a query parameter when getting contact interactions.
//
// Parameters:
//  Contact  - AnyRef - a contact for which linked contacts are to be searched.
//
// Returns:
//  Array
//
&AtServer
Function ContactParameterDependingOnType(Contact)
	
	ContactsDetailsArray1 = InteractionsClientServer.ContactsDetails();
	HasAdditionalTables = False;
	QueryText = "";
	ContactTableName = Contact.Metadata().Name;
	
	For Each DetailsArrayElement In ContactsDetailsArray1 Do
		
		If DetailsArrayElement.Name = ContactTableName Then
			QueryText = "SELECT ALLOWED
			|	CatalogContact.Ref AS Contact
			|FROM
			|	&TableName AS CatalogContact
			|WHERE
			|	CatalogContact.Ref = &Contact";
			
			
			QueryText = StrReplace(QueryText, "&TableName", "Catalog." + DetailsArrayElement.Name);
			Link = DetailsArrayElement.Link;
			
			If Not IsBlankString(Link) Then
				
				QueryText = QueryText + "
				|
				|UNION ALL
				|";
				
				QueryText = QueryText + "
				|SELECT
				|	CatalogContact.Ref 
				|FROM
				|	&TableName AS CatalogContact
				|WHERE
				|	CatalogContact." + Right(Link,StrLen(Link) - StrFind(Link,".")) + " = &Contact"; 
				
				
				QueryText = StrReplace(QueryText, "&TableName", "Catalog." + Left(Link,StrFind(Link,".")-1));
				QueryText = StrReplace(QueryText, "&NameOfTheComparisonProp", "CatalogContact." + Right(Link,StrLen(Link) - StrFind(Link,".")));
				HasAdditionalTables = True;
				
			EndIf;
			
		ElsIf DetailsArrayElement.OwnerName = ContactTableName Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|";
			
			QueryText = QueryText + "
			|SELECT
			|	CatalogContact.Ref
			|FROM
			|	&TableName AS CatalogContact
			|WHERE
			|	CatalogContact.Owner = &Contact";
			
			QueryText = StrReplace(QueryText, "&TableName", "Catalog." + DetailsArrayElement.Name);
			
			HasAdditionalTables = True;
			
		EndIf;
		
	EndDo;
	
	If IsBlankString(QueryText) Or (Not HasAdditionalTables) Then
		Return New Array;
	Else
		Query = New Query(QueryText);
		Query.SetParameter("Contact",Contact);
		QueryResult = Query.Execute();
		If QueryResult.IsEmpty() Then
			Return New Array;
		Else
			Return QueryResult.Unload().UnloadColumn("Contact");
		EndIf;
	EndIf;
	
EndFunction

&AtServer
Procedure SetFilterByContact()

	Query = New Query(
			"SELECT ALLOWED DISTINCT
			|	InteractionsContacts.Interaction AS Ref
			|FROM
			|	DocumentJournal.Interactions AS Interactions
			|		INNER JOIN InformationRegister.InteractionsContacts AS InteractionsContacts
			|		ON Interactions.Ref = InteractionsContacts.Interaction
			|WHERE
			|	InteractionsContacts.Contact IN(&Contact)");
			
	ContactParameterArray = ContactParameterDependingOnType(Contact);
	If ContactParameterArray.Count() = 0 Then
		ContactParameterArray.Add(Contact);
	EndIf;
	
	Query.SetParameter("Contact",ContactParameterArray);
	
	FilterList = New ValueList;
	FilterList.LoadValues(
	Query.Execute().Unload().UnloadColumn("Ref"));
	CommonClientServer.SetDynamicListFilterItem(List, 
		"Ref",FilterList,DataCompositionComparisonType.InList,,True);

EndProcedure

&AtServer
Procedure SetFilterBySubject()

	IsFilterBySubject = True;
	CommonClientServer.SetDynamicListFilterItem(List, "SubjectOf",
			SubjectForFilter,DataCompositionComparisonType.Equal,,True);
	
EndProcedure

&AtClient
Procedure QuestionOnMarkForDeletionAfterCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		ProcessDeletionMarkChangeInTree(Items.InteractionsTree.SelectedRows, AdditionalParameters.HasItemsMarkedForDeletion);
	EndIf;
	
EndProcedure

&AtClient
Procedure DateInputSubmitAfterFinished(EnteredDate, AdditionalParameters) Export

	If EnteredDate <> Undefined Then
		
		WasReplaced = False;
		DeferReview(EnteredDate,WasReplaced);
		
		If Items.TreeListPages.CurrentPage = Items.ListPage Then
			
			If WasReplaced Then
				Items.List.Refresh();
			EndIf;
			
		Else
			
			If WasReplaced Then
				ExpandAllTreeRows();
			EndIf;
			
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
Procedure SelectClosingInterval(SelectedPeriod, AdditionalParameters) Export

	If SelectedPeriod <> Undefined Then
		Interval = SelectedPeriod;
		FillInteractionsTreeClient();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnChangeTypeServer()
	
	Interactions.ProcessFilterByInteractionsTypeSubmenu(ThisObject);
	
	InteractionsClientServer.OnChangeFilterInteractionType(ThisObject, InteractionType);
	
EndProcedure


#EndRegion
