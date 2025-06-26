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
	
	If Object.Ref.IsEmpty() Then
		Interactions.SetSubjectByFillingData(Parameters, SubjectOf);
	EndIf;
	Interactions.FillChoiceListForReviewAfter(Items.ReviewAfter.ChoiceList);
	
	// Determining types of contacts that can be created.
	ContactsToInteractivelyCreateList = Interactions.CreateValueListOfInteractivelyCreatedContacts();
	Items.CreateContact.Visible      = ContactsToInteractivelyCreateList.Count() > 0;
	
	Interactions.PrepareNotifications(ThisObject, Parameters);
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesPage");
		AdditionalParameters.Insert("DeferredInitialization", True);
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	// End StandardSubsystems.Properties
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnCreateAtServer(ThisObject);
	EndIf;
	
	OnCreateAndOnReadAtServer();
	
	Interactions.FillTimeSelectionList(Items.BeginTime, 1800);
	Interactions.FillTimeSelectionList(Items.EndTime, 1800);
	
	// StandardSubsystems.StoredFiles
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		FilesHyperlink = ModuleFilesOperations.FilesHyperlink();
		FilesHyperlink.Location = "CommandBar";
		ModuleFilesOperations.OnCreateAtServer(ThisObject, FilesHyperlink);
	EndIf;
	// End StandardSubsystems.StoredFiles
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	If Common.IsMobileClient() Then
		Items.StartGroup1.ItemsAndTitlesAlign    = ItemsAndTitlesAlignVariant.ItemsRightTitlesLeft;
		Items.EndGroup.ItemsAndTitlesAlign = ItemsAndTitlesAlignVariant.ItemsRightTitlesLeft;
		Items.StartDate.SpinButton                   = False;
		Items.StartDate.TitleLocation                    = FormItemTitleLocation.Left;
		Items.EndDate.SpinButton                = False;
		Items.EndDate.Title                          = NStr("en = 'End';");
		Items.EndDate.TitleLocation                 = FormItemTitleLocation.Left;
		Items.BeginTime.SpinButton                  = False;
		Items.EndTime.SpinButton               = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	OnCreateAndOnReadAtServer();
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = Common.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	CheckContactCreationAvailability();
	
	// StandardSubsystems.StoredFiles
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.OnOpen(ThisObject, Cancel);
	EndIf;
	// End StandardSubsystems.StoredFiles
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		If ModulePropertyManagerClient.ProcessNotifications(ThisObject, EventName, Parameter) Then
			UpdateAdditionalAttributesItems();
			ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
		EndIf;
	EndIf;
	// End StandardSubsystems.Properties
	
	InteractionsClient.DoProcessNotification(ThisObject, EventName, Parameter, Source);
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "Meeting");
	CheckContactCreationAvailability();
	
	// StandardSubsystems.StoredFiles
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.NotificationProcessing(ThisObject, EventName);
	EndIf;
	// End StandardSubsystems.StoredFiles

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	Interactions.BeforeWriteInteractionFromForm(ThisObject, CurrentObject, ContactsChanged);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Interactions.OnWriteInteractionFromForm(CurrentObject, ThisObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)

	InteractionsClient.InteractionSubjectAfterWrite(ThisObject, Object, WriteParameters, "Meeting");
	CheckContactCreationAvailability();
	
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);

EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	InteractionsClient.ChoiceProcessingForm(ThisObject, ValueSelected, ChoiceSource, ChoiceContext);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ParticipantsDetailsPagesAdditionalOnCurrentPageChange(Item, CurrentPage)
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties")
		And CurrentPage.Name = "AdditionalAttributesPage"
		And Not PropertiesParameters.DeferredInitializationExecuted Then
		
		PropertiesExecuteDeferredInitialization();
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ReviewAfterChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	InteractionsClient.ProcessSelectionInReviewAfterField(
		ReviewAfter, ValueSelected, StandardProcessing, Modified);
	
EndProcedure

&AtClient
Procedure BeginTimeOnChange(Item)

	Object.StartDate = BegOfDay(Object.StartDate) + ExtractTime(BeginTime);
	Object.EndDate = Object.StartDate + Duration;
	EndTime = Object.EndDate;

EndProcedure

&AtClient
Procedure EndTimeOnChange(Item)

	If BegOfDay(Object.EndDate) + ExtractTime(EndTime) < Object.StartDate Then
		ClearMessages();
		CommonClient.MessageToUser(NStr("en = 'End time cannot be earlier than Start time.';"),,"EndTime");
		EndTime = BeginTime + 1800;
		Object.EndDate = BegOfDay(Object.EndDate) + ExtractTime(EndTime);
		Return;
	EndIf;

	Object.EndDate = BegOfDay(Object.EndDate) + ExtractTime(EndTime);
	Duration = Object.EndDate - Object.StartDate;

EndProcedure

&AtClient
Procedure StartDateOnChange(Item)

	Object.StartDate = BegOfDay(StartDate) + ExtractTime(BeginTime);
	Object.EndDate = Object.StartDate + Duration;
	EndDate = Object.EndDate;

EndProcedure

&AtClient
Procedure EndDateOnChange(Item)

	If BegOfDay(EndDate) + ExtractTime(EndTime) < Object.StartDate Then
		ClearMessages();
		If BegOfDay(EndDate) < BegOfDay(StartDate) Then
			CommonClient.MessageToUser(NStr("en = 'End date cannot be earlier than Start date.';"),,"EndDate");
		Else
			CommonClient.MessageToUser(NStr("en = 'End time cannot be earlier than Start time.';"),,"EndTime");
		EndIf;
		EndDate = Object.StartDate;
		Object.EndDate = BegOfDay(EndDate) + ExtractTime(EndTime);
		Return;
	EndIf;

	Object.EndDate = BegOfDay(EndDate) + ExtractTime(EndTime);
	Duration = Object.EndDate - Object.StartDate;

EndProcedure

&AtClient
Procedure ReviewedOnChange(Item)
	
	Items.ReviewAfter.Enabled = Not Reviewed;
	
EndProcedure

&AtClient
Procedure SubjectOfStartChoice(Item, ChoiceData, StandardProcessing)
	
	InteractionsClient.SubjectOfStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

// StandardSubsystems.StoredFiles
&AtClient
Procedure Attachable_PreviewFieldClick(Item, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldClick(ThisObject, Item, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PreviewFieldCheckDragging(Item, DragParameters, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldCheckDragging(ThisObject, Item,
			DragParameters, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PreviewFieldDrag(Item, DragParameters, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldDrag(ThisObject, Item,
			DragParameters, StandardProcessing);
	EndIf;
	
EndProcedure
// End StandardSubsystems.StoredFiles

#EndRegion

#Region FormTableItemsEventHandlersAttendees

&AtClient
Procedure AttendeesOnChange(Item)
	
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "Meeting");
	ContactsChanged = True;
	
EndProcedure

&AtClient
Procedure AttendeesOnActivateRow(Item)
	
	CheckContactCreationAvailability();
	
EndProcedure

&AtClient
Procedure ContactPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Items.Attendees.CurrentData;
	OpeningParameters = InteractionsClient.ContactChoiceParameters(UUID);
	InteractionsClient.SelectContact(SubjectOf, CurrentData.HowToContact, CurrentData.ContactPresentation,
		  CurrentData.Contact, OpeningParameters); 
		
EndProcedure
	  
&AtClient
Procedure ContactPresentationAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	
	If Waiting = 0 Then
		Return;
	EndIf;
	
	If IsBlankString(Text) Then
		Return;
	EndIf;
	
	ChoiceData = ContactsAutoSelection(Text);
	If ChoiceData.Count() > 0 Then
		StandardProcessing = False;
	Else
		ChoiceData = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(ValueSelected) = Type("Structure") Then
		CurrentData = Items.Attendees.CurrentData;
		CurrentData.ContactPresentation = ValueSelected.ContactPresentation;
		CurrentData.Contact               = ValueSelected.Contact;
		ContactPresentationOnChange(Item);
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactPresentationOnChange(Item)
	
	CurrentData = Items.Attendees.CurrentData;
	If CurrentData <> Undefined And ValueIsFilled(CurrentData.Contact) Then
		InteractionsServerCall.PresentationAndAllContactInformationOfContact(CurrentData.Contact,
			CurrentData.ContactPresentation, CurrentData.HowToContact);
	EndIf;

	CheckContactCreationAvailability();
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "Meeting");
	
EndProcedure

&AtClient
Procedure ContactPresentationOpening(Item, StandardProcessing)
	
	CurrentData = Items.Attendees.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;	
	
	StandardProcessing = False;
	ShowValue(, CurrentData.Contact);

EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CreateContactExecute()
	
	CurrentData = Items.Attendees.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ClearMessages();
	If Object.Ref.IsEmpty() And Not Write() Then
		Return;
	EndIf;
	
	InteractionsClient.CreateContact(CurrentData.ContactPresentation, CurrentData.HowToContact, 
		Object.Ref, ContactsToInteractivelyCreateList);
	
EndProcedure

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, Var_URL = Undefined, StandardProcessing = Undefined)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

// StandardSubsystems.StoredFiles
&AtClient
Procedure Attachable_AttachedFilesPanelCommand(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.AttachmentsControlCommand(ThisObject, Command);
	EndIf;
	
EndProcedure
// End StandardSubsystems.StoredFiles

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();
	Interactions.SetConditionalInteractionAppearance(ThisObject);

EndProcedure

&AtClient
Procedure CheckContactCreationAvailability()
	
	CurrentData = Items.Attendees.CurrentData;
	Items.CreateContact.Enabled = (CurrentData <> Undefined) 
	    And (Not ValueIsFilled(CurrentData.Contact));
	
EndProcedure

&AtClient
Function ExtractTime(Date)

	Return Hour(Date) * 3600 + Minute(Date) * 60;

EndFunction

&AtServer
Procedure OnCreateAndOnReadAtServer()
	
	StartDate        = Object.StartDate;
	BeginTime       = Object.StartDate;
	EndDate     = Object.EndDate;
	EndTime    = Object.EndDate;
	Duration = Object.EndDate - Object.StartDate;
	
	If Not Object.Ref.IsEmpty() Then
		Interactions.SetInteractionFormAttributesByRegisterData(ThisObject);
	Else
		ContactsChanged = True;
	EndIf;
	
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "Meeting");
	Items.ReviewAfter.Enabled = Not Reviewed;
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);
	
EndProcedure

&AtServerNoContext
Function ContactsAutoSelection(Val SearchString)
	
	Return Interactions.ContactsAutoSelection(SearchString);
	
EndFunction

// StandardSubsystems.Properties

&AtServer
Procedure PropertiesExecuteDeferredInitialization()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillAdditionalAttributesInForm(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.UpdateAdditionalAttributesItems(ThisObject);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
	ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
	ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
	ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion
