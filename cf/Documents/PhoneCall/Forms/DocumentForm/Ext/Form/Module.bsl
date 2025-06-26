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
	
	If Object.Ref.IsEmpty() Then
		Interactions.SetSubjectByFillingData(Parameters, SubjectOf);
	EndIf;
	Interactions.FillChoiceListForReviewAfter(Items.ReviewAfter.ChoiceList);
	If Object.Ref.IsEmpty() Then
		Object.Incoming = Not (Parameters.Property("Basis")
		And Not (Parameters.Basis = False Or Parameters.Basis = Undefined));
	EndIf;
	
	// Determining types of contacts that can be created.
	ContactsToInteractivelyCreateList = Interactions.CreateValueListOfInteractivelyCreatedContacts();
	Items.CreateContact.Visible      = ContactsToInteractivelyCreateList.Count() > 0;
	
	Interactions.PrepareNotifications(ThisObject,Parameters);
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesPage");
		AdditionalParameters.Insert("DeferredInitialization", True);
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	// End StandardSubsystems.Properties
	
	If Parameters.ParticipantData <> Undefined And Object.SubscriberContact <> Parameters.ParticipantData.Contact Then
		FillBasedOnParticipant(Parameters.ParticipantData);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnCreateAtServer(ThisObject);
	EndIf;
	
	OnCreateAndOnReadAtServer();
	
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "PhoneCall");
	
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

	InteractionsClient.InteractionSubjectAfterWrite(ThisObject, Object, WriteParameters, "PhoneCall");
	CheckContactCreationAvailability();
	
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	EndIf;
	
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
	
	InteractionsClient.DoProcessNotification(ThisObject,EventName, Parameter, Source);
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "PhoneCall");
	CheckContactCreationAvailability();
	
	// StandardSubsystems.StoredFiles
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.NotificationProcessing(ThisObject, EventName);
	EndIf;
	// End StandardSubsystems.StoredFiles

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
Procedure DetailsPagesAdditionalOnCurrentPageChange(Item, CurrentPage)
	
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
Procedure ContactStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("EmailOnly",                       False);
	OpeningParameters.Insert("PhoneOnly",                     True);
	OpeningParameters.Insert("ReplaceEmptyAddressAndPresentation", True);
	OpeningParameters.Insert("ForContactSpecificationForm",        False);
	OpeningParameters.Insert("FormIdentifier",                UUID);
	
	InteractionsClient.SelectContact(SubjectOf, Object.HowToContactSubscriber,
	         Object.SubscriberPresentation, Object.SubscriberContact, OpeningParameters);

EndProcedure

&AtClient
Procedure ContactPresentationOnChange(Item)
	
	CheckContactCreationAvailability();
	ContactsChanged = True;
	
EndProcedure

&AtClient
Procedure ContactOnChange(Item)
	
	InteractionsServerCall.PresentationAndAllContactInformationOfContact(Object.SubscriberContact,
	                                                                         Object.SubscriberPresentation,
	                                                                         Object.HowToContactSubscriber);
	CheckContactCreationAvailability();
	InteractionsClientServer.CheckContactsFilling(Object,ThisObject,"PhoneCall");
	ContactsChanged = True;
	
EndProcedure

&AtClient
Procedure ReviewAfterChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	InteractionsClient.ProcessSelectionInReviewAfterField(ReviewAfter, 
		ValueSelected, StandardProcessing, Modified);
	
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

#Region FormCommandsEventHandlers

&AtClient
Procedure CreateContactExecute()

	InteractionsClient.CreateContact(
		Object.SubscriberPresentation, Object.HowToContactSubscriber, Object.Ref, ContactsToInteractivelyCreateList);

EndProcedure

&AtClient
Procedure LinkedInteractionsExecute()

	FilterParameters = New Structure;
	FilterParameters.Insert("SubjectOf", Object.SubjectOf);

	OpenForm("DocumentJournal.Interactions.ListForm", FilterParameters, ThisObject, , Window);

EndProcedure

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, Var_URL = Undefined, StandardProcessing = Undefined)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
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
Procedure FillBasedOnParticipant(ParticipantData)
	
	Object.SubscriberContact = ParticipantData.Contact;
	If IsBlankString(ParticipantData.HowToContact) Then
		
		Object.HowToContactSubscriber = "";
		Interactions.FinishFillingContactsFields(Object.SubscriberContact,
			Object.SubscriberPresentation,
			Object.HowToContactSubscriber,
			Enums.ContactInformationTypes.Phone);
		
	Else
		
		Object.HowToContactSubscriber = ParticipantData.HowToContact;
		
	EndIf;
	
	Object.SubscriberPresentation = ParticipantData.Presentation;
	
EndProcedure

&AtServer
Procedure OnCreateAndOnReadAtServer()
	
	If Not Object.Ref.IsEmpty() Then
		Interactions.SetInteractionFormAttributesByRegisterData(ThisObject);
	Else
		ContactsChanged = True;
	EndIf;
	Items.ReviewAfter.Enabled = Not Reviewed;
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);
	
EndProcedure

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

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

&AtClient
Procedure CheckContactCreationAvailability()
	
	Items.CreateContact.Enabled = (Not Object.Ref.IsEmpty()) 
	                                      And (Not ValueIsFilled(Object.SubscriberContact)) 
	                                      And (Not IsBlankString(Object.SubscriberPresentation));
	
EndProcedure

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
