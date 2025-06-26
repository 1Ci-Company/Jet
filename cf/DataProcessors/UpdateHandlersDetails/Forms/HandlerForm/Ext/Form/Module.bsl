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
Var ParametersOfTheAttachedHandler;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	StartFromConfiguration = Parameters.StartFromConfiguration;
	HasMetadataObjectsIDs = Metadata.Catalogs.Find("MetadataObjectIDs") <> Undefined;
	
	OrderArray = New Array;
	OrderArray.Add(NStr("en = 'Current';"));
	OrderArray.Add(NStr("en = 'Conflicting';"));
	OrderArray.Add(NStr("en = 'Any';"));
	
	Items.ExecutionPrioritiesSelectExecutionOrder.ChoiceList.LoadValues(OrderArray);
	
	Presentation = New Map;
	Presentation.Insert("Before", OrderArray[0]);
	Presentation.Insert("After", OrderArray[1]);
	Presentation.Insert("Any", OrderArray[2]);
	OrderPresentation = New FixedMap(Presentation);
	
	FillModuleMaps(OrderArray);
	Modified = Parameters.NewRow;
	
	If Not IsBlankString(Parameters.HandlerAddress) Then
		
		Data = GetFromTempStorage(Parameters.HandlerAddress);
		Object["UpdateHandlers"].Load(Data.TabularSections.UpdateHandlers);
		If Data.TabularSections.Property("HandlersConflicts") Then
			Object["HandlersConflicts"].Load(Data.TabularSections.HandlersConflicts);
		EndIf;
		
		CurrentHandlerRef = Object.UpdateHandlers[0].Ref;
		ProcessingProcedure = Object.UpdateHandlers[0].Procedure;
		CurrentValueProcedureCheck = Object.UpdateHandlers[0].CheckProcedure;
		ChangedCheckProcedure = Object.UpdateHandlers[0].ChangedCheckProcedure;
		If Not IsBlankString(ProcessingProcedure) Then
			Title = ProcessingProcedure;
			AutoTitle = False;
		EndIf;
		MainMetadataObject = MainMetadataObjectName(Object.UpdateHandlers[0].Procedure, SingularForm, PluralForm);
		Items.Handler1.ExtendedTooltip.Title = Object.UpdateHandlers[0].Comment;
		
		ContainsMetadataObject = New Structure("ObjectsToRead,ObjectsToChange,ObjectsToLock");
		For Each TabularSection In Data.TabularSections Do
			If ContainsMetadataObject.Property(TabularSection.Key) Then
				For Each TSRow In TabularSection.Value Do
					NewRow = Object[TabularSection.Key].Add();
					FillPropertyValues(NewRow, TSRow);
					NewRow.PictureIndex = PictureIndex(TSRow.MetadataObject);
				EndDo;
				Object[TabularSection.Key].Sort("MetadataObject");
				
			ElsIf StrFind(TabularSection.Key, "ExecutionPriorities") > 0 Then
				ImportHandlerPriorities(TabularSection.Value);
				
			ElsIf StrFind(TabularSection.Key, "LowPriorityReading") > 0 Then
				ImportLowPriorityReading(TabularSection.Value);
				
			ElsIf StrFind(TabularSection.Key, "HandlersConflicts") = 0 Then
				Object[TabularSection.Key].Load(TabularSection.Value);
				
			EndIf;
		EndDo;
		
		SubsystemsModules = Data.SubsystemsModules;
		UpdateModulesListPassed = SubsystemsModules <> Undefined;
		Items.MainServerModuleName.Visible = Not UpdateModulesListPassed;
		If UpdateModulesListPassed Then
			List = Items.Subsystem.ChoiceList;
			For Each Subsystem In SubsystemsModules Do
				List.Add(Subsystem.Key);
			EndDo;
			List.SortByValue(SortDirection.Desc);
		EndIf;

		If ValueIsFilled(Object.UpdateHandlers[0].Subsystem) Then
			Object.UpdateHandlers[0].MainServerModuleName = SubsystemsModules[Object.UpdateHandlers[0].Subsystem];
		EndIf;
		Items.MainServerModuleName.Visible = Not ValueIsFilled(Object.UpdateHandlers[0].MainServerModuleName);
		
	Else
		Object["UpdateHandlers"].Add();
	EndIf;
	
	SetBlankExclusiveHandlerMark();
	SetMarkIncompleteCheckProcedure();
	
	FillInCommonModules();
	
	Items.WarningDecoration.Visible = ChangedCheckProcedure;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Modified Then
		Cancel = True;
		ResponseHandler1 = New NotifyDescription("FormClosingCompletion", ThisObject);
		ShowQueryBox(ResponseHandler1, NStr("en = 'The data has been changed. Do you want to save the changes?';"), QuestionDialogMode.YesNoCancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure FormClosingCompletion(Result, AdditionalParameters) Export
	
	Address = Undefined;
	If Result = DialogReturnCode.Yes Then
		
		If Not CheckFilling() Then
			Return;
		EndIf;
		
		Address = PutHandlerDataInStorage(FormOwner.UUID);
		Modified = False;
		Close(Address);
		
	ElsIf Result = DialogReturnCode.Cancel Then
		// No action required.
	Else
		Modified = False;
		Close(Address);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "DataOnUpdateHandlerConflictsUpdated" Then
		UpdateHandlerConflictsData(Parameter);
		Modified = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure MainMetadataObjectStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectMetadataObject(Item, MainMetadataObject);

EndProcedure

&AtClient
Procedure MainMetadataObjectChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If TypeOf(ValueSelected) <> Type("String") Then
		StandardProcessing = False;
	EndIf;

	ChoiceHandlerParameters = ChoiceHandlerParameters(, MainMetadataObject);
	
	ParametersOfTheAttachedHandler = New Structure;
	ParametersOfTheAttachedHandler.Insert("ValueSelected", ValueSelected);
	ParametersOfTheAttachedHandler.Insert("ChoiceHandlerParameters", ChoiceHandlerParameters);
	
	AttachIdleHandler("Attachable_MetadataObjectChoiceProcessing", 0.1, True);
	
EndProcedure

&AtClient
Procedure MainMetadataObjectAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	
	IncludingCommonModules = True;
	PickMetadataObjects(Text, ChoiceData, StandardProcessing, IncludingCommonModules);
	
EndProcedure

&AtClient
Procedure MainMetadataObjectTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	
	IncludingCommonModules = True;
	PickMetadataObjects(Text, ChoiceData, StandardProcessing, IncludingCommonModules);
	
EndProcedure

&AtClient
Procedure IdStartChoice(Item, ChoiceData, StandardProcessing)
	
	Modified = True;
	Object.UpdateHandlers[0].Id = String(New UUID);
	
EndProcedure

&AtClient
Procedure ProcedureOnChange(Item)
	
	If Not IsBlankString(Object.UpdateHandlers[0].Procedure) Then
		AutoTitle = False;
		MainMetadataObject = MainMetadataObjectName(Object.UpdateHandlers[0].Procedure, SingularForm, PluralForm);
		Title = Object.UpdateHandlers[0].Procedure;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateDataFillingProcedureOnChange(Item)
	
	If Not IsBlankString(Object.UpdateHandlers[0].UpdateDataFillingProcedure) Then
		MainMetadataObjectName(Object.UpdateHandlers[0].UpdateDataFillingProcedure, SingularForm, PluralForm);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckProcedureOnChange(Item)
	
	NotifyDescription = New NotifyDescription("ProcedureChecksFinishingTextInputAfterQuestion", ThisObject, Item.EditText);
	If Item.EditText <> StandardCheckProcedure() Then
		ShowQueryBox(NotifyDescription, TextWarningChangedCheckProcedure(True), QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcedureChecksFinishingTextInputAfterQuestion(Result, Text) Export
	If Result <> DialogReturnCode.Yes Then
		Object.UpdateHandlers[0].CheckProcedure = CurrentValueProcedureCheck;
		Return;
	EndIf;
	Object.UpdateHandlers[0].CheckProcedure = Text;
	CurrentValueProcedureCheck = Text;
	
	Items.WarningDecoration.Visible = (CurrentValueProcedureCheck <> StandardCheckProcedure());
	
	Items.CheckProcedure.MarkIncomplete = Not ValueIsFilled(Object.UpdateHandlers[0].CheckProcedure);
	If Not IsBlankString(Object.UpdateHandlers[0].CheckProcedure) Then
		MainMetadataObjectName(Object.UpdateHandlers[0].CheckProcedure, SingularForm, PluralForm);
	EndIf;
EndProcedure

&AtClient
Procedure WarningDecorationClick(Item)
	ShowMessageBox(, TextWarningChangedCheckProcedure());
EndProcedure

&AtClient
Procedure CheckProcedureStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If Object.ObjectsToRead.FindRows(New Structure("LockInterface", True)).Count() > 0
		Or Object.ObjectsToLock.Count() > 0 Then
		MessageText = NStr("en = 'Do not use the ""%1"" procedure to check locks in handlers that control locking of data to read or other objects.';");
		MessageText = StrReplace(MessageText, "%1", "InfobaseUpdate.DataUpdatedForNewApplicationVersion");
		CommonClient.MessageToUser(MessageText,,"CheckProcedure","Object");
		Return;	
	EndIf;

	Object.UpdateHandlers[0].CheckProcedure = StandardCheckProcedure();
	Items.CheckProcedure.MarkIncomplete = False;
	
	CurrentValueProcedureCheck = StandardCheckProcedure();
	Items.WarningDecoration.Visible = False;
	
EndProcedure

&AtClient
Procedure ExecutionModeOnChange(Item)
	SetBlankExclusiveHandlerMark();
EndProcedure

&AtClient
Procedure SubsystemOnChange(Item)
	
	CurrentSubsystem = Object.UpdateHandlers[0].Subsystem;
	If SubsystemsModules <> Undefined And Not IsBlankString(CurrentSubsystem) Then
		Object.UpdateHandlers[0].MainServerModuleName = SubsystemsModules[CurrentSubsystem];
	EndIf;
	Items.MainServerModuleName.Visible = Not ValueIsFilled(Object.UpdateHandlers[0].MainServerModuleName);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	Notification = New NotifyDescription("CommentStartChoiceCompletion", ThisObject);
	CommonClient.ShowMultilineTextEditingForm(
		Notification, Items.Comment.EditText, NStr("en = 'Internal comment';"));
	
EndProcedure

&AtClient
Procedure FormPagesOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage.Name = "ConflictsPage" Then
		Items.Declare.Visible = Modified;
		Items.Handler1.ExtendedTooltip.Title = Object.UpdateHandlers[0].Comment;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure ObjectsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		CurrentData = Item.CurrentData;
		CurrentData.PictureIndex = 1000;
		CurrentData.Ref = Object.UpdateHandlers[0].Ref;
		If Item.Name = "ObjectsToChange" Then
			CurrentData.LockInterface = True;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure MetadataObjectStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	TableName = Item.Parent.Parent.Name;
	SelectMetadataObject(Item,,TableName);
	
EndProcedure

&AtClient
Procedure MetadataObjectChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If TypeOf(ValueSelected) <> Type("String") Then
		StandardProcessing = False;
	EndIf;
	
	ChoiceHandlerParameters = ChoiceHandlerParameters(Item.Parent.Parent.Name);
	
	ParametersOfTheAttachedHandler = New Structure;
	ParametersOfTheAttachedHandler.Insert("ValueSelected", ValueSelected);
	ParametersOfTheAttachedHandler.Insert("ChoiceHandlerParameters", ChoiceHandlerParameters);
	
	AttachIdleHandler("Attachable_MetadataObjectChoiceProcessing", 0.1, True);
	
EndProcedure

&AtClient
Procedure MetadataObjectAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	
	PickMetadataObjects(Text, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure MetadataObjectTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	
	PickMetadataObjects(Text, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ObjectsAfterDeletion(Item)
	SetMarkIncompleteCheckProcedure();
EndProcedure

&AtClient
Procedure InfoAboutLock(Command)
	
	WarningText = NStr("en = '• Check for lock by previous queues is performed only for objects registered on the exchange plan for update for the current handler.
		|
		|• If you want to select data for update with updated readable data, specify additional sources in the registration procedure selection parameters.
		|
		|	Additional sources are readable data tables whose items must have a lower number in a queue on the exchange plan than the current handler number.';");
	
	ShowMessageBox(, WarningText);
	
EndProcedure

&AtClient
Procedure ObjectsToReadSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Field.Name = Items.ObjectsToReadWarning.Name Then
		HandlerFormName = "DataProcessor.UpdateHandlersDetails.Form.HandlerIntersectionObjects";
		If Not StartFromConfiguration Then
			HandlerFormName = "ExternalDataProcessor.UpdateHandlersDetails.Form.HandlerIntersectionObjects";
		EndIf;
		
		DataAddress = PutLowPriorityHandlersToStorage(Item.CurrentData.MetadataObject);
		FormParameters = New Structure;
		FormParameters.Insert("DataAddress", DataAddress);
		FormParameters.Insert("AreLowPriorityHandlers", True);
		
		OpenForm(HandlerFormName,
			FormParameters,
			ThisObject,
			UUID,
			,
			,
			,
			FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecutionPrioritiesSelection(Item, RowSelected, Field, StandardProcessing)
	
	Priority = Item.CurrentData;
	FillHandlerIntersections(Priority.Ref, Priority.Handler2);
	
	DataAddress = PutHandlerIntersectionsInStorage(Priority.Ref, Priority.Handler2);
	FormParameters = New Structure;
	FormParameters.Insert("DataAddress", DataAddress);
	
	If Field.Name = "ExecutionPrioritiesIntersectionObjects" Then
		HandlerFormName = "DataProcessor.UpdateHandlersDetails.Form.HandlerIntersectionObjects";
		If Not StartFromConfiguration Then
			HandlerFormName = "ExternalDataProcessor.UpdateHandlersDetails.Form.HandlerIntersectionObjects";
		EndIf;
		
		OpenForm(HandlerFormName,
			FormParameters,
			ThisObject,
			UUID,
			,
			,
			,
			FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecutionPrioritiesOnActivateRow(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	AttachIdleHandler("UpdateHandler2Info", 0.1, True);
	
EndProcedure

&AtClient
Procedure ExecutionPrioritiesSelectExecutionOrderOnChange(Item)
	
	CurrentData = Items.ExecutionPriorities.CurrentData;
	CurrentData.Order = "";
	CurrentData.ExecutionOrderSpecified = False;
	If ValueIsFilled(CurrentData.SelectExecutionOrder) Then
		CurrentData.Order = ExecutionOrder[CurrentData.SelectExecutionOrder];
		CurrentData.ExecutionOrderSpecified = ValueIsFilled(CurrentData.Order);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	If Not FilledCorrectly() Then
		Return;
	EndIf;
	
	Address = PutHandlerDataInStorage(FormOwner.UUID);
	Modified = False;
	Close(Address);
	
EndProcedure

&AtClient
Procedure WriteHandler(Command)
	
	If Not FilledCorrectly() Then
		Return;
	EndIf;
	
	ClearMessages();
	Address = PutHandlerDataInStorage(FormOwner.UUID);
	Notify("UpdateHandlerDetailsChanged", Address);
	Items.Declare.Visible = Modified;
	Items.SelectEmptyOrder.Visible = False;
	
EndProcedure

&AtClient
Procedure FillHandler1(Command)
	FillExecutionOrder("Before");
EndProcedure

&AtClient
Procedure FillHandler2(Command)
	FillExecutionOrder("After");
EndProcedure

&AtClient
Procedure FillAny(Command)
	FillExecutionOrder("Any");
EndProcedure

&AtClient
Procedure AddHandlerObjectToDataToRead(Command)
	
	AddMainMetadataObject("ObjectsToRead");
	
EndProcedure

&AtClient
Procedure AddHandlerObjectToDataToChange(Command)
	
	AddMainMetadataObject("ObjectsToChange");
	
EndProcedure

&AtClient
Procedure AddObjectToChangeToDataToRead(Command)
	
	ObjectsStrings = New Array;
	For Each LineID In Items.ObjectsToChange.SelectedRows Do
		String = Object.ObjectsToChange.FindByID(LineID);
		ObjectsStrings.Add(String);
	EndDo;
	AddObjectsToTable("ObjectsToRead", ObjectsStrings);
	
EndProcedure

&AtClient
Procedure AddObjectToReadToDataToChange(Command)
	
	ObjectsStrings = New Array;
	For Each LineID In Items.ObjectsToRead.SelectedRows Do
		String = Object.ObjectsToRead.FindByID(LineID);
		ObjectsStrings.Add(String);
	EndDo;
	AddObjectsToTable("ObjectsToChange", ObjectsStrings);
	
EndProcedure

&AtClient
Procedure AddAttributeTypesToDataToRead(Command)
	
	AddAttributeTypes("ObjectsToRead");
	
EndProcedure

&AtClient
Procedure AddAttributeTypesToObjectsToLock(Command)
	
	ObjectsNames = New ValueList;
	For Each String In Object.ObjectsToRead Do
		ObjectsNames.Add(String.MetadataObject);
	EndDo;
	For Each String In Object.ObjectsToChange Do
		ObjectsNames.Add(String.MetadataObject);
	EndDo;
	ObjectsNames.SortByValue();
	
	AdditionalParameters = New Structure("TableName", "ObjectsToLock");
	ChoiceHandler = New NotifyDescription("MetadataObjectChoiceCompletion", ThisObject, AdditionalParameters);
	ObjectsNames.ShowChooseItem(ChoiceHandler, NStr("en = 'Select metadata object';"));
	
EndProcedure

&AtClient
Procedure SelectEmptyOrder(Command)
	
	SelectedRows = Items.ExecutionPriorities.SelectedRows;
	AlreadyAllocated = New Array;
	For Each LineID In SelectedRows Do
		Priority = Object.ExecutionPriorities.FindByID(LineID);
		If IsBlankString(Priority.Order) Then
			AlreadyAllocated.Add(LineID);
		EndIf;
	EndDo;
	SelectedRows.Clear();
	For Each LineID In AlreadyAllocated Do
		SelectedRows.Add(LineID);
	EndDo;
	For Each Priority In Object.ExecutionPriorities Do
		If IsBlankString(Priority.Order) Then
			SelectedRows.Add(Priority.LineNumber-1);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure Attachable_MetadataObjectChoiceProcessing()
	
	ValueSelected = ParametersOfTheAttachedHandler.ValueSelected;
	ChoiceHandlerParameters = ParametersOfTheAttachedHandler.ChoiceHandlerParameters;
	
	MetadataObjectChoiceProcessing1(ValueSelected, ChoiceHandlerParameters);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExecutionPrioritiesSelectExecutionOrder.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.ExecutionPriorities.Order");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = New DataCompositionField("Object.ExecutionPriorities.OrderAuto");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ObjectsToReadMetadataObject.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.ObjectsToRead.HasLowPriorityReadingWriter");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.SpecialTextColor);
	
EndProcedure

&AtClient
Procedure CommentStartChoiceCompletion(ClosingResult, AdditionalParameters) Export

	If ClosingResult <> Undefined Then
		Object.UpdateHandlers[0].Comment = ClosingResult;
	EndIf;
	
EndProcedure

&AtClient
Function FilledCorrectly()
	
	If Not CheckFilling() Then
		Return False;
	EndIf;
	
	CurrentHandler = Object.UpdateHandlers[0];
	If CurrentHandler.ExecutionMode = "Deferred" 
		And Object.ObjectsToChange.Count() = 0 Then
		MessageText = NStr("en = 'Couldn''t save the deferred handler. ""Objects to change"" is empty.';");
		CommonClient.MessageToUser(MessageText);
		Items.FormPages.CurrentPage = Items.ObjectsPage;
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Function PutHandlerDataInStorage(FormOwnerUUID)
	
	Data = New Structure("TabularSections", New Structure);
	Object.UpdateHandlers[0].Changed = True;
	Data.TabularSections.Insert("UpdateHandlers", Object.UpdateHandlers.Unload());
	Data.TabularSections.Insert("ObjectsToRead", Object.ObjectsToRead.Unload());
	Data.TabularSections.Insert("ObjectsToChange", Object.ObjectsToChange.Unload());
	Data.TabularSections.Insert("ObjectsToLock", Object.ObjectsToLock.Unload());
	Data.TabularSections.Insert("ExecutionPriorities", Object.ExecutionPriorities.Unload());
	
	Return PutToTempStorage(Data,  FormOwnerUUID);
	
EndFunction

&AtServer
Function MetadataObjectPresentation(MetadataObjectRef)
	
	AttributeName = "FullName";
	If TypeOf(MetadataObjectRef) = Type("String") Then
		FullName = MetadataObjectRef;
	Else
		FullName = Common.ObjectAttributeValue(MetadataObjectRef, AttributeName);
	EndIf;
	
	Result = New Structure;
	Result.Insert("MetadataObject", FullName);
	Result.Insert("PictureIndex", PictureIndex(FullName));
	
	Return Result;
	
EndFunction

&AtServer
Function PictureIndex(FullMetadataObjectName)
	
	MetadataObjectType = StrSplit(FullMetadataObjectName, ".")[0];
	Result = 0;
	If TypesPicturesIndexes.Property(MetadataObjectType) Then
		Result = TypesPicturesIndexes[MetadataObjectType];
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure FillModuleMaps(OrderArray)
	
	PicturesIndexes = New Structure;
	PicturesIndexes.Insert("Constant", 1);
	PicturesIndexes.Insert("Catalog", 3);
	PicturesIndexes.Insert("Document", 7);
	PicturesIndexes.Insert("ChartOfCharacteristicTypes", 9);
	PicturesIndexes.Insert("ChartOfAccounts", 11);
	PicturesIndexes.Insert("ChartOfCalculationTypes", 13);
	PicturesIndexes.Insert("InformationRegister", 15);
	PicturesIndexes.Insert("AccumulationRegister", 17);
	PicturesIndexes.Insert("AccountingRegister", 19);
	PicturesIndexes.Insert("CalculationRegister", 21);
	PicturesIndexes.Insert("BusinessProcess", 23);
	PicturesIndexes.Insert("Task", 25);
	
	TypesPicturesIndexes = New FixedStructure(PicturesIndexes);
	
	Plural = New Map;
	Plural.Insert("Constant", "Constants");
	Plural.Insert("Catalog", "Catalogs");
	Plural.Insert("Document", "Documents");
	Plural.Insert("ChartOfCharacteristicTypes", "ChartsOfCharacteristicTypes");
	Plural.Insert("ChartOfAccounts", "ChartsOfAccounts");
	Plural.Insert("ChartOfCalculationTypes", "ChartsOfCalculationTypes");
	Plural.Insert("InformationRegister", "InformationRegisters");
	Plural.Insert("AccumulationRegister", "AccumulationRegisters");
	Plural.Insert("AccountingRegister", "AccountingRegisters");
	Plural.Insert("CalculationRegister", "CalculationRegisters");
	Plural.Insert("BusinessProcess", "BusinessProcesses");
	Plural.Insert("Task", "Tasks");
	Plural.Insert("DataProcessor", "DataProcessors");
	
	Singular = New Map;
	For Each Class In Plural Do
		Singular.Insert(Class.Value, Class.Key);
	EndDo;
	
	PluralForm = New FixedMap(Plural);
	SingularForm = New FixedMap(Singular);
		
	Order = New Map;
	Order.Insert(OrderArray[0], "Before");
	Order.Insert(OrderArray[1], "After");
	Order.Insert(OrderArray[2], "Any");
	ExecutionOrder = New FixedMap(Order);
	
EndProcedure

&AtClientAtServerNoContext
Function MainMetadataObjectName(ProcedureName, SingularForm, PluralForm)
	
	NameParts = StrSplit(ProcedureName, ".");
	FullObjectName = "";
	If NameParts.Count() = 2 Then
		FullObjectName = "CommonModule." + NameParts[0];
	ElsIf NameParts.Count() = 3 Then
		Try
			NameParts[0] = SingularForm[NameParts[0]];
		Except
#If Client Then
				DefaultLanguageCode = CommonClient.DefaultLanguageCode();
#EndIf
#If Server Then
				DefaultLanguageCode = Common.DefaultLanguageCode();
#EndIf
			MessageText = NStr("en = 'Cannot recognize the ""%1"" metadata object kind.
				|The object kind must be plural.';", DefaultLanguageCode);
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, NameParts[0]);
			Raise MessageText;
		EndTry;
		NameParts.Delete(NameParts.UBound());
		FullObjectName = StrConcat(NameParts, ".");
	EndIf;
	Return FullObjectName;
	
EndFunction

&AtClient
Procedure SelectMetadataObject(Item, CurrentValue = "", TableName = Undefined)
	
	If Not HasMetadataObjectsIDs Then
		Return;
	EndIf;
	
	ReferencesArrray = AvailableClassesForMetadataChoice(TableName = Undefined);
	ParentsList = New ValueList;
	ParentsList.LoadValues(ReferencesArrray);
	
	FormParameters = New Structure();
	FormParameters.Insert("ChoiceMode", True);
	
	FilterStructure1 = New Structure;
	FilterStructure1.Insert("Parent", ParentsList);
	
	FormParameters.Insert("Filter", FilterStructure1);
	If TableName <> Undefined Then
		CurrentValue = Items[TableName].CurrentData.MetadataObject;
	EndIf;
	FormParameters.Insert("CurrentRow", CurrentValue);
	FormParameters.Insert("MainMetadataObject", Undefined);
	If CurrentItem.Name = Items.ObjectsToRead.Name Then
		FormParameters.Insert("MainMetadataObject", MainMetadataObject);
	EndIf;
	
	ChoiceHandlerParameters = ChoiceHandlerParameters(TableName, CurrentValue);
	ChoiceHandler = New NotifyDescription("MetadataObjectChoiceProcessing1", ThisObject, ChoiceHandlerParameters);
	
	ChoiceFormName = "DataProcessor.UpdateHandlersDetails.Form.MetadataObjectsIDsChoiceForm";
	If Not StartFromConfiguration Then
		ChoiceFormName = "ExternalDataProcessor.UpdateHandlersDetails.Form.MetadataObjectsIDsChoiceForm";
	EndIf;
	
	OpenForm(ChoiceFormName,
		FormParameters,
		Item,
		UUID,
		,
		,
		ChoiceHandler,
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtClient
Function ChoiceHandlerParameters(TableName = Undefined, CurrentValue = "")
	
	ChoiceHandlerParameters = New Structure("AttributeName", "MainMetadataObject");
	If ValueIsFilled(TableName) Then
		ChoiceHandlerParameters = New Structure("TableName", TableName);
	EndIf;
	ChoiceHandlerParameters.Insert("PreviousValue", CurrentValue);
	
	Return ChoiceHandlerParameters;
	
EndFunction

&AtClient
Procedure MetadataObjectChoiceProcessing1(ValueSelected, AdditionalParameters) Export
	
	If ValueIsFilled(ValueSelected) Then
		ObjectPresentation = MetadataObjectPresentation(ValueSelected);
		If AdditionalParameters.Property("TableName") Then
			CurrentData = Items[AdditionalParameters.TableName].CurrentData;
			CurrentData.PictureIndex = ObjectPresentation.PictureIndex;
			CurrentData.MetadataObject = ObjectPresentation.MetadataObject;
			
		ElsIf AdditionalParameters.Property("AttributeName") Then
			Modified = True;
			ThisObject[AdditionalParameters.AttributeName] = ObjectPresentation.MetadataObject;
			Title = ObjectPresentation.MetadataObject;
			AutoTitle = False;
			If ValueIsFilled(ObjectPresentation.MetadataObject) Then
				NameParts = StrSplit(ObjectPresentation.MetadataObject, ".");
				If NameParts.Count() > 0 Then
					If NameParts[0] = "CommonModule" Then
						NameParts.Delete(0);
					Else
						NameParts[0] = PluralForm[NameParts[0]];
					EndIf;
					ObjectName = StrConcat(NameParts, ".");
					UpdateProcedureName1("Procedure", ObjectName, AdditionalParameters.PreviousValue, "ProcessDataForMigrationToNewVersion");
					UpdateProcedureName1("UpdateDataFillingProcedure", ObjectName, AdditionalParameters.PreviousValue, "RegisterDataToProcessForMigrationToNewVersion");
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateProcedureName1(NameContainer, ObjectName, Val PreviousObjectName, NewProcedureName)
	
	CurrentHandler = Object.UpdateHandlers[0];
	If IsBlankString(CurrentHandler[NameContainer]) Then
		CurrentHandler[NameContainer] = ObjectName + "." + NewProcedureName;
	
	ElsIf Not IsBlankString(PreviousObjectName) Then
		NameParts = StrSplit(PreviousObjectName, ".");
		If NameParts.Count() > 0 Then
			If NameParts[0] = "CommonModule" Then
				NameParts.Delete(0);
			Else
				NameParts[0] = PluralForm[NameParts[0]];
			EndIf;
			PreviousObjectName = StrConcat(NameParts, ".");
		EndIf;
		
		CurrentHandler[NameContainer] = StrReplace(CurrentHandler[NameContainer], PreviousObjectName, ObjectName);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function AvailableClassesForMetadataChoice(IncludeCommonModules = False)
	
	ClassesArray = AvailableMetadataObjectsClasses(IncludeCommonModules);
	
	QueryText =
	"SELECT ALLOWED
	|	ObjectsIDs.Ref AS Ref
	|FROM
	|	Catalog.MetadataObjectIDs AS ObjectsIDs
	|WHERE
	|	ObjectsIDs.Name IN(&ClassesArray)
	|	AND NOT ObjectsIDs.DeletionMark
	|	AND ObjectsIDs.Parent = VALUE(Catalog.MetadataObjectIDs.EmptyRef)";
	
	Query = New Query(QueryText);
	Query.SetParameter("ClassesArray", ClassesArray);
	
	ReferencesArrray = Query.Execute().Unload().UnloadColumn("Ref");
	
	Return ReferencesArrray;
	
EndFunction

&AtServerNoContext
Function AvailableMetadataObjectsClasses(IncludeCommonModules = False)
	
	RestrictionsArray = New Array;
	
	If IncludeCommonModules Then
		RestrictionsArray.Add("CommonModules");
	EndIf;
	
	RestrictionsArray.Add("BusinessProcesses");
	RestrictionsArray.Add("Documents");
	RestrictionsArray.Add("Tasks");
	RestrictionsArray.Add("Constants");
	RestrictionsArray.Add("SessionParameters");
	RestrictionsArray.Add("ChartsOfCalculationTypes");
	RestrictionsArray.Add("ChartsOfCharacteristicTypes");
	RestrictionsArray.Add("ExchangePlans");
	RestrictionsArray.Add("ChartsOfAccounts");
	RestrictionsArray.Add("Sequences");
	RestrictionsArray.Add("AccountingRegisters");
	RestrictionsArray.Add("AccumulationRegisters");
	RestrictionsArray.Add("CalculationRegisters");
	RestrictionsArray.Add("InformationRegisters");
	RestrictionsArray.Add("ScheduledJobs");
	RestrictionsArray.Add("Catalogs");
	
	Return RestrictionsArray;
	
EndFunction

&AtServer
Procedure UpdateHandlerConflictsData(HandlerAddress)
	
	Data = GetFromTempStorage(HandlerAddress);
	Object.HandlersConflicts.Clear();
	Object.HandlersConflicts.Load(Data.TabularSections.HandlersConflicts);
	Items.Handler1.ExtendedTooltip.Title = Data.TabularSections.UpdateHandlers[0].Comment;
	
	ImportHandlerPriorities(Data.TabularSections.ExecutionPriorities);
	ImportLowPriorityReading(Data.TabularSections.LowPriorityReading);
	
EndProcedure

&AtServer
Procedure ImportHandlerPriorities(NewPriorities)
	
	MainObjectName = MainMetadataObjectName(Object.UpdateHandlers[0].Procedure, SingularForm, PluralForm);
	Object.ExecutionPriorities.Clear();
	For Each Priority In NewPriorities Do
		NewRow = Object.ExecutionPriorities.Add();
		FillPropertyValues(NewRow, Priority);
		If ValueIsFilled(Priority.Order) Then
			NewRow.SelectExecutionOrder = OrderPresentation[Priority.Order];
		EndIf;
		
		FillHandlerIntersections(Priority.Ref, Priority.Handler2);
		IntersectionObjects = Intersections.Unload(,"MetadataObject");
		
		IntersectionObjects.GroupBy("MetadataObject");
		IntersectionObjects.Sort("MetadataObject");
		If IntersectionObjects.Count() = 1 Then
			NewRow.IntersectionObjects = IntersectionObjects[0].MetadataObject;
			
		ElsIf IntersectionObjects.Count() > 1 Then
			For Each IntersectionObject In IntersectionObjects Do
				If MainObjectName <> IntersectionObject.MetadataObject Then
					NewRow.IntersectionObjects = StringFunctionsClientServer.SubstituteParametersToString(
														"%1 +%2", IntersectionObject.MetadataObject, IntersectionObjects.Count()-1);
					Break;
				EndIf;
			EndDo;
			
		EndIf;
	EndDo;
	Object.ExecutionPriorities.Sort("Procedure2");
	
	If Object.ExecutionPriorities.Count() > 1 Then
		TableHeight = Object.ExecutionPriorities.Count()+1;
		If TableHeight > 8 Then
			TableHeight = 8;
		EndIf;
		Items.ExecutionPriorities.HeightInTableRows = TableHeight;
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportLowPriorityReading(LowPriorityReading)
	
	Object.LowPriorityReading.Load(LowPriorityReading);
	If LowPriorityReading.Count() > 0 Then
		Items.ObjectsToReadWarning.Visible = True;
		Filter = New Structure("MetadataObject");
		For Each Readable In Object.ObjectsToRead Do
			Filter.MetadataObject = Readable.MetadataObject;
			FoundRows = Object.LowPriorityReading.FindRows(Filter);
			If FoundRows.Count() > 0 Then
				Readable.HasLowPriorityReadingWriter = True;
				Readable.Warning = PictureLib.Warning;
			EndIf;
		EndDo;
		MessageText = NStr("en = 'Readable handler objects include objects that are processed by handlers with a lower priority than the current one.
		|This will cause the current handler to wait for them to complete. Resolve this mismatch.';");
		Common.MessageToUser(MessageText);
	Else
		Items.ObjectsToReadWarning.Visible = False;
		For Each Readable In Object.ObjectsToRead Do
			Readable.HasLowPriorityReadingWriter = False;
			Readable.Warning = Undefined;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Function PutHandlerIntersectionsInStorage(CurrentHandler, ConflictingHandler)
	
	FillHandlerIntersections(CurrentHandler, ConflictingHandler);
	Address = PutToTempStorage(Intersections.Unload(), UUID);
	Return Address;
	
EndFunction

&AtServer
Function PutLowPriorityHandlersToStorage(MetadataObject)
	
	Data = Object.LowPriorityReading.Unload(New Structure("MetadataObject", MetadataObject));
	Address = PutToTempStorage(Data, UUID);
	Return Address;
	
EndFunction

&AtServer
Procedure FillHandlerIntersections(CurrentHandler, ConflictingHandler)
	
	Intersections.Clear();
	For Each Conflict In Object.HandlersConflicts Do
		Filter = New Structure("MetadataObject,WriteProcedure,ReadOrWriteProcedure2", 
							Conflict.MetadataObject, Conflict.ReadOrWriteProcedure2, Conflict.WriteProcedure);
		ReverseConflicts = Intersections.FindRows(Filter);
		If Conflict.HandlerWriter = CurrentHandler
				And Conflict.ReadOrWriteHandler2 = ConflictingHandler
			Or Conflict.HandlerWriter = ConflictingHandler
				And Conflict.ReadOrWriteHandler2 = CurrentHandler 
			And ReverseConflicts.Count() = 0 Then
			NewIntersection = Intersections.Add();
			FillPropertyValues(NewIntersection, Conflict);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure UpdateHandler2Info()
	
	CurrentData = Items.ExecutionPriorities.CurrentData;
	
	Handler2 = CurrentData.Procedure2;
	Items.Handler2.ExtendedTooltip.Title = CurrentData.Comment2;
	FillHandlerIntersections(CurrentData.Ref, CurrentData.Handler2);
	
EndProcedure

&AtClient
Procedure FillExecutionOrder(NewOrder)
	
	SelectedRows = Items.ExecutionPriorities.SelectedRows;
	If SelectedRows.Count() > 0 Then
		For Each LineID In SelectedRows Do
			Priority = Object.ExecutionPriorities.FindByID(LineID);
			Priority.Order = NewOrder;
			Priority.SelectExecutionOrder = OrderPresentation[NewOrder];
			Priority.ExecutionOrderSpecified = True;
		EndDo;
	EndIf;
	Modified = True;
	
EndProcedure

&AtServer
Procedure SetMarkIncompleteCheckProcedure()
	
	Mark = True;
	
	If ValueIsFilled(Object.UpdateHandlers[0].Procedure)
		Or Object.UpdateHandlers[0].ExecutionMode = "Exclusively"
		Or Object.UpdateHandlers[0].ExecutionMode = "Seamless"
		Or Not (Object.ObjectsToLock.Count() > 0
				Or Object.ObjectsToRead.FindRows(New Structure("LockInterface", True)).Count() > 0
				Or Object.ObjectsToChange.FindRows(New Structure("LockInterface", True)).Count() > 0) Then
		Mark = False;
	EndIf;
	
	Items.CheckProcedure.MarkIncomplete = Mark;
	
EndProcedure

&AtServer
Procedure SetBlankExclusiveHandlerMark()
	
	ExclusiveHandler = Object.UpdateHandlers[0].ExecutionMode = "Exclusively";
	If ExclusiveHandler Then
		Items.UpdateDataFillingProcedure.AutoMarkIncomplete = Not ExclusiveHandler;
		Items.UpdateDataFillingProcedure.MarkIncomplete = Not ExclusiveHandler;
		Items.Comment.AutoMarkIncomplete = Not ExclusiveHandler;
		Items.Comment.MarkIncomplete = Not ExclusiveHandler;
	Else
		Items.UpdateDataFillingProcedure.AutoMarkIncomplete = Undefined;
		Items.Comment.AutoMarkIncomplete = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure PickMetadataObjects(Text, ChoiceData, StandardProcessing, IncludingCommonModules = False)
	
	If IsBlankString(Text) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	IncludingCommonModules = True;
	MetadataObjects = FindMetadataObjects(Text, IncludingCommonModules, CommonModules);
	
	If CurrentItem.Name = Items.ObjectsToRead.Name Then
		IndexOf = MetadataObjects.Find(MainMetadataObject);
		If IndexOf <> Undefined Then
			MetadataObjects.Delete(IndexOf);
		EndIf;
	EndIf;
	
	ChoiceData = New ValueList;
	ChoiceData.LoadValues(MetadataObjects);
	
EndProcedure

&AtServerNoContext
Function FindMetadataObjects(NamePart, IncludingCommonModules, Val AllSharedModules)
	
	QueryText = MetadataObjectsIDsQueryText();
	
	Query = New Query(QueryText);
	Query.SetParameter("CommonModules", AllSharedModules.Unload());
	Query.SetParameter("IncludingCommonModules", IncludingCommonModules);
	Query.SetParameter("NamePart", "%" + Common.GenerateSearchQueryString(NamePart) + "%");
	Query.SetParameter("ClassesArray", AvailableMetadataObjectsClasses(IncludingCommonModules));
	MetadataObjects = Query.Execute().Unload().UnloadColumn("Ref");
	
	Return MetadataObjects;
	
EndFunction

&AtServerNoContext
Function MetadataObjectsIDsQueryText()
	
	Return 
	"SELECT
	|	T.Name AS Name
	|INTO CommonModules
	|FROM
	|	&CommonModules AS T
	|WHERE
	|	&IncludingCommonModules
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 50
	|	MetadataObjects.FullName AS Ref
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjects
	|WHERE
	|	NOT MetadataObjects.DeletionMark
	|	AND MetadataObjects.FullName LIKE &NamePart ESCAPE ""~""
	|
	|	AND MetadataObjects.Parent.Name IN(&ClassesArray)
	|	AND NOT MetadataObjects.Parent.DeletionMark
	|
	|UNION ALL
	|
	|SELECT TOP 50
	|	CommonModules.Name
	|FROM
	|	CommonModules AS CommonModules
	|WHERE
	|	CommonModules.Name LIKE &NamePart ESCAPE ""~""
	|
	|ORDER BY
	|	Ref";

EndFunction

&AtServer
Procedure AddMainMetadataObject(TableName)
	
	If IsBlankString(MainMetadataObject) Then
		Return;
	EndIf;
	
	Filter = New Structure("MetadataObject", MainMetadataObject);
	FoundRows = Object[TableName].FindRows(Filter);
	If FoundRows.Count() > 0 Then
		Return;
	EndIf;
	
	NewRow = Object[TableName].Add(); // FormDataCollectionItem - See DataProcessor.UpdateHandlersDetails.ObjectsToRead
	NewRow.Ref = Object.UpdateHandlers[0].Ref;
	NewRow.MetadataObject = MainMetadataObject;
	NewRow.PictureIndex = PictureIndex(MainMetadataObject);
	NewRow.LockInterface = TableName = "ObjectsToChange";
	Modified = True;
	
EndProcedure

&AtClient
Procedure AddAttributeTypes(TableName, ObjectName = "")
	
	If IsBlankString(ObjectName) Then
		If Items[TableName].CurrentData = Undefined Then
			ShowMessageBox(,NStr("en = 'Metadata object is not selected';"));
			Return;
		EndIf;
		
		ObjectName = Items[TableName].CurrentData.MetadataObject;
		If IsBlankString(ObjectName) Then
			Return;
		EndIf;
	EndIf;
	Attributes = MetadataObjectAttributes1(ObjectName);
	SelectTheMetadataObjectSDetails(Attributes, TableName, ObjectName);
	
EndProcedure

&AtClient
Procedure SelectTheMetadataObjectSDetails(Attributes, TableName, ObjectName)
	
	Names = StrSplit(ObjectName, ".");
	Names[0] = PluralForm[Names[0]];
	ObjectName = StrConcat(Names, ".");
	
	AdditionalParameters = New Structure("TableName, ObjectName", TableName, ObjectName);
	ChoiceHandler = New NotifyDescription("CompletingTheSelectionOfTheMetadataObjectSProps", ThisObject, AdditionalParameters);
	Attributes.ShowChooseItem(ChoiceHandler, NStr("en = 'Select an object attribute';"));
	
EndProcedure

&AtClient
Procedure MetadataObjectChoiceCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	Attributes = MetadataObjectAttributes1(Result.Value);
	SelectTheMetadataObjectSDetails(Attributes, AdditionalParameters.TableName, Result.Value);
	
EndProcedure

&AtClient
Procedure CompletingTheSelectionOfTheMetadataObjectSProps(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	AddAttributeTypesToTable(AdditionalParameters.TableName, Result.Value);
	
EndProcedure

&AtServer
Function MetadataObjectAttributes1(ObjectName)
	
	Result = New ValueList;
	ObjectMetadata = Common.MetadataObjectByFullName(ObjectName);
	FullObjectName = ObjectMetadata.FullName();
	MoreObjectAttributes = New Structure("StandardAttributes, Dimensions, Resources, Attributes");
	
	EdH = New Map;
	EdH.Insert("StandardAttributes", "StandardAttribute");
	EdH.Insert("Dimensions", "Dimension");
	EdH.Insert("Resources", "Resource");
	EdH.Insert("Attributes", "Attribute");
	FillPropertyValues(MoreObjectAttributes, ObjectMetadata);
	For Each Collection In MoreObjectAttributes Do
		
		If Collection.Value = Undefined Then
			Continue;
		EndIf;
		
		For Each Attribute In Collection.Value Do
			FullAttributeName = FullObjectName + "." + EdH[Collection.Key];
			// Loop through the attribute types.
			For Each Type In Attribute.Type.Types() Do
				// If at least one reference type is found.
				If Common.IsReference(Type) Then // Add it to the list.
					FullAttributeName = FullAttributeName + "." + Attribute.Name;
					Result.Add(FullAttributeName, Attribute.Name);
					Break;
				EndIf;
			EndDo;
		EndDo;
		
	EndDo;
	Result.SortByPresentation();
	Return Result;
	
EndFunction

&AtServer
Procedure AddAttributeTypesToTable(TableName, FullAttributeName)
	
	Attribute = Metadata.FindByFullName(FullAttributeName);
	If StrFind(FullAttributeName, "StandardAttribute") > 0 Then
		Names = StrSplit(FullAttributeName, ".");
		Attribute = Common.MetadataObjectByFullName(Names[0]+ "." + Names[1]).StandardAttributes[Names[3]];
	EndIf;
	
	If Attribute = Undefined Then
		Return;
	EndIf;
	
	Table = Object[TableName].Unload();
	For Each Type In Attribute.Type.Types() Do
		ObjectName = StrReplace(Common.TypePresentationString(Type),"Ref","");
		NewRow = Table.Add(); // ValueTableRow - 
		NewRow.Ref = Object.UpdateHandlers[0].Ref;
		NewRow.MetadataObject = ObjectName;
		NewRow.PictureIndex = PictureIndex(ObjectName);
		If TableName <> "ObjectsToLock" Then
			NewRow.LockInterface = TableName = "ObjectsToChange";
		EndIf;
		Modified = True;
	EndDo;
	GroupingObjects = "Ref,MetadataObject,PictureIndex,LockInterface";
	If TableName = "ObjectsToChange" Then
		GroupingObjects = GroupingObjects +",NewObjects";
	ElsIf TableName = "ObjectsToLock" Then
		GroupingObjects = "Ref,MetadataObject,PictureIndex";
	EndIf;
	Table.GroupBy(GroupingObjects);
	Table.Sort("MetadataObject");
	Object[TableName].Load(Table);
	
EndProcedure

&AtClient
Procedure AddObjectsToTable(TableName, ObjectsStrings)
	
	Table = Object[TableName];
	For Each ObjectString In ObjectsStrings Do
		
		Filter = New Structure("MetadataObject", ObjectString.MetadataObject);
		FoundRows = Table.FindRows(Filter);
		If FoundRows.Count() > 0 Then
			Continue;
		EndIf;
		
		TabularSection = Object[TableName]; // TabularSection - 
		NewObject = TabularSection.Add();
		FillPropertyValues(NewObject, ObjectString);
		NewObject.LockInterface = TableName = "ObjectsToChange";
		
	EndDo;
	Modified = True;
	
EndProcedure

&AtServer
Procedure FillInCommonModules()
	
	Table = FormAttributeToValue("CommonModules");
	For Each Module In Metadata.CommonModules Do
		NewRow = Table.Add();
		NewRow.Name = Module.FullName();
	EndDo;
	ValueToFormAttribute(Table, "CommonModules");
	
EndProcedure

&AtClient
Function StandardCheckProcedure()
	
	Return "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	
EndFunction

&AtClientAtServerNoContext
Function TextWarningChangedCheckProcedure(DoQueryBox = False)
	
	TextHat = NStr("en = 'Use a custom check procedure responsibly,
		|when the standard check procedure is insufficient.';");
	TextHat = StrConcat(StrSplit(TextHat, Chars.LF), " ");
	
	TextContinued = NStr("en = 'Follow these development recommendations:
		| • The handler can lock only non-updated data.
		| • Processed data is unlocked in chunks (not after all objects are processed)
		| • Users can always enter new data.';");
	
	WarningText = TextHat + Chars.LF + Chars.LF + TextContinued;
	
	If DoQueryBox Then
		WarningText = WarningText + Chars.LF + Chars.LF + NStr("en = 'Do you want to continue?';");
	EndIf;
	
	Return WarningText;
	
EndFunction

#EndRegion
