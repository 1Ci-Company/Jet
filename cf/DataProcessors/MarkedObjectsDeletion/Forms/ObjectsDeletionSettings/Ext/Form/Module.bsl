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
	If IsTempStorageURL(Parameters.SettingsAddress) Then
		LoadSettings(GetFromTempStorage(Parameters.SettingsAddress));
	EndIf;
	
	ScheduledJob = MarkedObjectsDeletionInternalServerCall.ModeDeleteOnSchedule();
	AutomaticallyDeleteMarkedObjects = ScheduledJob.Use;
	DeleteMarkedObjectsSchedule = ScheduledJob.Schedule;
	
	SetFormStateByScheduledJobSettings(ThisObject);
	
	If Common.DataSeparationEnabled() Then
		Items.DeleteMarkedObjectsConfigureSchedule.Visible = False;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	StandardSubsystemsClient.ExpandTreeNodes(ThisObject, "ObjectsViewSettings");
	AttachIdleHandler("StartCheckOfDeletableObjectsLock",0.1, True);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseScheduledDeletionOnChange(Item)
	ChangeNotification1 = New NotifyDescription("ScheduledJobsAfterChangeSchedule", ThisObject);
	MarkedObjectsDeletionClient.OnChangeCheckBoxDeleteOnSchedule(AutomaticallyDeleteMarkedObjects, ChangeNotification1);
EndProcedure

&AtClient
Procedure ScheduledJobSettings(Command)
	ChangeNotification1 = New NotifyDescription("ScheduledJobsAfterChangeSchedule", ThisObject);
	MarkedObjectsDeletionClient.StartChangeJobSchedule(ChangeNotification1);
EndProcedure

&AtClient
Procedure ScheduledJobsAfterChangeSchedule(Changes, ExecutionParameters) Export
	If Changes = Undefined Then
		AutomaticallyDeleteMarkedObjects = False;
	Else	
		DeleteMarkedObjectsSchedule = Changes.Schedule;
		AutomaticallyDeleteMarkedObjects = Changes.Use;
	EndIf;
	
	SetFormStateByScheduledJobSettings(ThisObject);
EndProcedure

&AtClient
Procedure StandardDeletionOnChange(Item)
	SetMode("StandardDeletion");
EndProcedure

&AtClient
Procedure SafeDeletionOnChange(Item)
	SetMode("SafeDeletion");
EndProcedure

&AtClient
Procedure ExclusiveDeletionOnChange(Item)
	SetMode("ExclusiveDeletion");
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AddSetting(Command)
	ObjectsToSelectCollection = New ValueList;

	ObjectsToSelectCollection.Add("Catalogs");
	ObjectsToSelectCollection.Add("Documents");
	ObjectsToSelectCollection.Add("ChartsOfCharacteristicTypes");
	ObjectsToSelectCollection.Add("ChartsOfAccounts");
	ObjectsToSelectCollection.Add("ChartsOfAccounts");
	ObjectsToSelectCollection.Add("ChartsOfCalculationTypes");
	ObjectsToSelectCollection.Add("BusinessProcesses");
	ObjectsToSelectCollection.Add("Tasks");

	SelectedObjects = New ValueList;
	For Each SearchLocation In ObjectsViewSettings.GetItems() Do
		SelectedObjects.Add(SearchLocation.SearchLocationAttribute);
	EndDo;

	FormParameters = StandardSubsystemsClientServer.MetadataObjectsSelectionParameters();
	FormParameters.MetadataObjectsToSelectCollection = ObjectsToSelectCollection;
	FormParameters.SubsystemsWithCIOnly = True;
	FormParameters.SelectedMetadataObjects = SelectedObjects;

	ClosingNotification1 = New NotifyDescription("AddSettingCompletion", ThisObject);
	StandardSubsystemsClient.ChooseMetadataObjects(FormParameters, ClosingNotification1);
EndProcedure

&AtClient
Procedure AddSettingsField(Command)
	If ObjectsViewSettings.GetItems().Count() = 0 Then
		AddSetting(Command);
	EndIf;

	CurrentData = Items.ObjectsViewSettings.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;

	SearchLocation = CurrentData.SearchLocationAttribute;
	ItemParent = CurrentData.GetParent();
	If ItemParent <> Undefined And ValueIsFilled(ItemParent.SearchLocationAttribute) Then
		SearchLocation = ItemParent.SearchLocationAttribute;
	EndIf;

	AttributesForSelection = AttributesForSelection(AttributesMetadata(SearchLocation), CurrentData);
	
	ChoiceNotification1 = New NotifyDescription("AddSettingsFieldCompletion",
												 ThisObject,
												 New Structure("SearchLocation", SearchLocation));
	AttributesForSelection.ShowCheckItems(ChoiceNotification1);
EndProcedure

&AtClient
Procedure Select(Command)
	StorageAddress = PrepareSettings(FormOwner.UUID);
	Close(StorageAddress);
EndProcedure

&AtClient
Procedure ObjectsToDelete(Command)
	OpenForm("InformationRegister.ObjectsToDelete.ListForm");
EndProcedure

#EndRegion

#Region Private

&AtClient
Function AttributesForSelection(AttributesMetadata,Val CurrentData)
	Result = AttributesMetadata.Copy();
	
	ItemParent = CurrentData.GetParent();
	If ItemParent = Undefined Then
		ItemParent = CurrentData;
	EndIf;
	
	For Each SelectedAttribute In ItemParent.GetItems() Do
		ListAttribute = Result.FindByValue(SelectedAttribute.SearchLocationAttribute);
		
		If ListAttribute <> Undefined Then
			ListAttribute.Check = True;			
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Parameters:
//   Settings - See SettingsFromFormData
//
&AtServer
Procedure LoadSettings(Settings)
	StandardDeletion = 0;
	If Settings.DeletionMode = "Exclusive" Then
		ExclusiveDeletion = 1;
	ElsIf Settings.DeletionMode = "Simplified" Then
		SafeDeletion = 1;
	Else
		StandardDeletion = 1;
	EndIf;
	
	SelectedAttributes = Settings.SelectedAttributes;
	SelectedAttributes.Sort("Metadata");
	
	SettingsTree = FormAttributeToValue("ObjectsViewSettings");
	
	CurrentMetadata = "";
	SearchLocation = Undefined;
	PictureFolder = PictureLib.Folder;
	PictureProps = PictureLib.Attribute;
	For Each SearchLocationAttribute In SelectedAttributes Do
		If CurrentMetadata <> SearchLocationAttribute.Metadata Then
			SearchLocation = SettingsTree.Rows.Add();
			SearchLocation.SearchLocationAttributePresentation = Metadata.FindByFullName(
				SearchLocationAttribute.Metadata).Presentation();
			SearchLocation.Picture = PictureFolder;
			SearchLocation.SearchLocationAttribute = SearchLocationAttribute.Metadata;
			CurrentMetadata = SearchLocationAttribute.Metadata;
		EndIf;

		Attribute = SearchLocation.Rows.Add();
		Attribute.SearchLocationAttributePresentation = SearchLocationAttribute.Presentation;
		Attribute.SearchLocationAttribute = SearchLocationAttribute.Attribute;
		Attribute.Picture = PictureProps;
	EndDo;
	
	ValueToFormAttribute(SettingsTree, "ObjectsViewSettings");
EndProcedure

&AtServerNoContext
Function AttributesMetadata(Val MetadataObject)
	Result = New ValueList;

	MetadataObject = Common.MetadataObjectByFullName(MetadataObject);
	For Each Attribute In MetadataObject.Attributes Do
		Result.Add(Attribute.Name, Attribute.Synonym);
	EndDo;

	Return Result;
EndFunction

&AtServer
Procedure AddSettingsFieldCompletionServer(Result, AdditionalParameters)

	SearchLocationsTree = FormAttributeToValue("ObjectsViewSettings");

	SearchLocationID = AdditionalParameters.SearchLocation;
	Filter = New Structure("SearchLocationAttribute", SearchLocationID);
	SearchLocationSubgroup = SearchLocationsTree.Rows.FindRows(Filter)[0];
	SearchLocationSubgroup.Rows.Clear();
	Picture = PictureLib.Attribute;
	For Each Item In Result Do

		If Item.Check Then
			SearchLocation = SearchLocationSubgroup.Rows.Add();
			SearchLocation.SearchLocationAttribute = Item.Value;
			SearchLocation.SearchLocationAttributePresentation = Item.Presentation;
			SearchLocation.Picture = Picture;
		EndIf;

	EndDo;

	ValueToFormAttribute(SearchLocationsTree, "ObjectsViewSettings");
EndProcedure

// Returns:
//   Structure:
//   * DeletionMode - String
//   * SelectedAttributes - ValueTable:
//     ** Metadata - String
//     ** Attribute - String
//     ** Presentation - String
//
&AtServer
Function SettingsFromFormData()
	Settings = New Structure;
	Settings.Insert("SelectedAttributes");
	Settings.Insert("DeletionMode");
	
	If SafeDeletion > 0 Then
		Settings.DeletionMode = "Simplified";
	ElsIf ExclusiveDeletion > 0 Then 
		Settings.DeletionMode = "Exclusive";
	Else	
		Settings.DeletionMode = "Standard";
	EndIf;
	
	SelectedAttributes = New ValueTable;
	SelectedAttributes.Columns.Add("Metadata");
	SelectedAttributes.Columns.Add("Attribute");
	SelectedAttributes.Columns.Add("Presentation");
	
	AttributeTree = FormAttributeToValue("ObjectsViewSettings");
	For Each MetadataString1 In AttributeTree.Rows Do
		MetadataObject = MetadataString1.SearchLocationAttribute;
		For Each Item In MetadataString1.Rows Do
			Attribute = SelectedAttributes.Add();
			Attribute.Metadata = MetadataObject;
			Attribute.Presentation = Item.SearchLocationAttributePresentation;
			Attribute.Attribute = Item.SearchLocationAttribute;
		EndDo;	
	EndDo;
	
	Settings.SelectedAttributes = SelectedAttributes;
	
	Return Settings;
EndFunction

&AtServer
Function PrepareSettings(Var_UUID)
	Return PutToTempStorage(SettingsFromFormData(),
		Var_UUID); 
EndFunction

&AtClient
Procedure AddSettingCompletion(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;

	AddSettingServer(Result);
EndProcedure

&AtServer
Procedure AddSettingServer(Result)
	SearchLocationsTree = FormAttributeToValue("ObjectsViewSettings");

	Picture = PictureLib.Folder; 
	For Each Item In Result Do
		Filter = New Structure("SearchLocationAttribute", Item.Value);

		If SearchLocationsTree.Rows.FindRows(Filter).Count() = 0 Then
			SearchLocation = SearchLocationsTree.Rows.Add();
			SearchLocation.SearchLocationAttribute = Item.Value;
			SearchLocation.SearchLocationAttributePresentation = Item.Presentation;
			SearchLocation.Picture = Picture;
		EndIf;
	EndDo;

	ValueToFormAttribute(SearchLocationsTree, "ObjectsViewSettings");
EndProcedure

&AtClient
Procedure AddSettingsFieldCompletion(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		AddSettingsFieldCompletionServer(Result, AdditionalParameters);	
	EndIf;
	
	StandardSubsystemsClient.ExpandTreeNodes(ThisObject, "ObjectsViewSettings");
EndProcedure

&AtClientAtServerNoContext
Procedure SetFormStateByScheduledJobSettings(Form)
	Form.Items.DeleteMarkedObjectsConfigureSchedule.Enabled =  Form.AutomaticallyDeleteMarkedObjects;
	Form.Items.DeleteMarkedObjectsSchedulePresentation.Visible = Form.AutomaticallyDeleteMarkedObjects;
	
	If Form.AutomaticallyDeleteMarkedObjects Then
		Schedule = New JobSchedule;
		FillPropertyValues(Schedule, Form.DeleteMarkedObjectsSchedule);
		SchedulePresentation = String(Schedule);
		Presentation = Upper(Left(SchedulePresentation, 1)) + Mid(SchedulePresentation, 2);
	Else
		Presentation = NStr("en = '<Disabled>';");
	EndIf;
	
	Form.Items.DeleteMarkedObjectsSchedulePresentation.Title = Presentation;
EndProcedure

&AtClient
Procedure SetMode(Mode)
	StandardDeletion = 0;
	SafeDeletion = 0;
	ExclusiveDeletion = 0;
	ThisObject[Mode] = 1;
EndProcedure

&AtClient
Procedure StartCheckOfDeletableObjectsLock()

	Notification = New NotifyDescription("FinalizeCheckOfDeletableObjectsLock", ThisObject);
	TimeConsumingOperation = StartCheckOfDeletableObjectsLockServer();
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, Notification, TimeConsumingOperationsClient.IdleParameters(ThisObject));

EndProcedure

&AtServer
Function StartCheckOfDeletableObjectsLockServer()

	BackgroundJobParameters = TimeConsumingOperations.ProcedureExecutionParameters();
	Return TimeConsumingOperations.ExecuteProcedure(BackgroundJobParameters, 
		"MarkedObjectsDeletionInternal.MarkedObjectsDeletionControl");

EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure FinalizeCheckOfDeletableObjectsLock(Result, AdditionalParameters) Export
	FinishCheckingTheLockOnDeletedObjectsServer();
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(Result.ErrorInfo);
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure FinishCheckingTheLockOnDeletedObjectsServer()
	Items.ObjectsToDelete.Enabled = True;
	Items.ObjectsToDelete.Picture = PictureLib.ExclamationPointRed;
EndProcedure

#EndRegion

