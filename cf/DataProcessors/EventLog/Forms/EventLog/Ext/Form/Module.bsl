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
	
	If Parameters.DataAccessLog Then
		Title = NStr("en = 'Data access log';");
		EventLogEvent = New Array;
		EventLogEvent.Add("_$Access$_.Access");
		EventLogEvent.Add("_$Access$_.AccessDenied");
		EventLogEvent.Add("_$Session$_.Authentication");
		EventLogEvent.Add("_$Session$_.AuthenticationError");
		EventLogEvent.Add("_$Session$_.Start");
		EventLogEvent.Add("_$Session$_.Finish");
		Items.Log.Visible = False;
		Items.Log2.Visible = True;
		AutoURL = False;
		URL = "e1cib/command/DataProcessor.EventLog.Command.DataAccessLog";
	Else
		Items.Log.Visible = True;
		Items.Log2.Visible = False;
		EventLogEvent = Parameters.EventLogEvent;
	EndIf;
	
	EventLogFilter = New Structure;
	DefaultEventLogFilter = New Structure;
	FilterValues = GetEventLogFilterValues("Event").Event;
	
	FilterByUser = FilterByUserFromParameter(Parameters.User);
	If ValueIsFilled(FilterByUser) Then
		EventLogFilter.Insert("User", FilterByUser);
	EndIf;
	
	If ValueIsFilled(EventLogEvent) Then
		FilterByEvent = New ValueList;
		If TypeOf(EventLogEvent) = Type("Array") Then
			For Each Event In EventLogEvent Do
				FilterByEvent.Add(Event, EventPresentation(Event, FilterValues));
			EndDo;
		Else
			Event = EventLogEvent;
			FilterByEvent.Add(Event, EventPresentation(Event, FilterValues));
		EndIf;
		EventLogFilter.Insert("Event", FilterByEvent);
	EndIf;
	
	EventLogFilter.Insert("StartDate", 
		?(ValueIsFilled(Parameters.StartDate), Parameters.StartDate, BegOfDay(CurrentSessionDate())));
	EventLogFilter.Insert("EndDate", 
		?(ValueIsFilled(Parameters.EndDate), Parameters.EndDate, EndOfDay(CurrentSessionDate())));
	
	If Parameters.Data <> Undefined Then
		If TypeOf(Parameters.Data) = Type("Array") Then
			EventLogFilter.Insert("Data", New ValueList);
			EventLogFilter.Data.LoadValues(Parameters.Data);
		Else
			EventLogFilter.Insert("Data", Parameters.Data);
		EndIf;
	EndIf;
	
	If Parameters.Session <> Undefined Then
		EventLogFilter.Insert("Session", Parameters.Session);
	EndIf;
	
	// Level - value list.
	If Parameters.Level <> Undefined Then
		FilterByLevel = New ValueList;
		If TypeOf(Parameters.Level) = Type("Array") Then
			For Each LevelPresentation In Parameters.Level Do
				FilterByLevel.Add(LevelPresentation, LevelPresentation);
			EndDo;
		ElsIf TypeOf(Parameters.Level) = Type("String") Then
			FilterByLevel.Add(Parameters.Level, Parameters.Level);
		Else
			FilterByLevel = Parameters.Level;
		EndIf;
		EventLogFilter.Insert("Level", FilterByLevel);
	EndIf;
	
	// ApplicationName - value list.
	If Parameters.ApplicationName <> Undefined Then
		ApplicationsList = New ValueList;
		For Each Package In Parameters.ApplicationName Do
			ApplicationsList.Add(Package, ApplicationPresentation(Package));
		EndDo;
		EventLogFilter.Insert("ApplicationName", ApplicationsList);
	EndIf;
	
	EventsCountLimit = 200;
	
	If Common.IsWebClient() Or Common.IsMobileClient() Then
		ItemToRemove = Items.EventsCountLimit.ChoiceList.FindByValue(10000);
		Items.EventsCountLimit.ChoiceList.Delete(ItemToRemove);
		Items.EventsCountLimit.MaxValue = 1000;
	EndIf;
	
	FilterDefault = FilterDefault(FilterValues);
	If Not EventLogFilter.Property("Event") Then
		EventLogFilter.Insert("Event", FilterDefault);
	EndIf;
	DefaultEventLogFilter.Insert("Event", FilterDefault);
	
	StandardSeparatorsOnly = EventLog.StandardSeparatorsOnly();
	SetSeparationVisibility(ThisObject,
		Not Common.SeparatedDataUsageAvailable());
	
	Severity = "AllEvents";
	
	// Switched to True if the event log must not be generated in background.
	ShouldNotRunInBackground = Parameters.ShouldNotRunInBackground;
	
	If Common.IsMobileClient() Then
		
		CommonClientServer.SetFormItemProperty(Items, "Severity",	"TitleLocation",		FormItemTitleLocation.None);
		CommonClientServer.SetFormItemProperty(Items, "Severity",	"ChoiceButton",				True);
		CommonClientServer.SetFormItemProperty(Items, "Log", 		"CommandBarLocation", FormItemCommandBarLabelLocation.None);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("RefreshCurrentList", 0.1, True);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "LoggedOnToDataArea"
	 Or EventName = "LoggedOffFromDataArea" Then
		
		Log.Clear();
		SetSeparationVisibility(ThisObject,
			Not CommonClient.SeparatedDataUsageAvailable());
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure EventsCountLimitOnChange(Item)
	
#If WebClient Or MobileClient Then
	EventsCountLimit = ?(EventsCountLimit > 1000, 1000, EventsCountLimit);
#EndIf
	
	RefreshCurrentList();
	
EndProcedure

&AtClient
Procedure SeverityOnChange(Item)
	
	EventLogFilter.Delete("Level");
	FilterByLevel = New ValueList;
	If Severity = "Error" Then
		FilterByLevel.Add("Error", "Error");
	ElsIf Severity = "Warning" Then
		FilterByLevel.Add("Warning", "Warning");
	ElsIf Severity = "Information" Then
		FilterByLevel.Add("Information", "Information");
	ElsIf Severity = "Note" Then
		FilterByLevel.Add("Note", "Note");
	EndIf;
	
	If FilterByLevel.Count() > 0 Then
		EventLogFilter.Insert("Level", FilterByLevel);
	EndIf;
	
	RefreshCurrentList();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersLog

&AtClient
Procedure LogSelection(Item, RowSelected, Field, StandardProcessing)
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("CurrentData", Item.CurrentData);
	ChoiceParameters.Insert("Field", Field);
	ChoiceParameters.Insert("DateInterval", DateInterval);
	ChoiceParameters.Insert("EventLogFilter", EventLogFilter);
	ChoiceParameters.Insert("NotificationHandlerForSettingDateInterval",
		New NotifyDescription("SetPeriodForViewingCompletion", ThisObject));
	
	EventLogClient.EventsChoice(ChoiceParameters);
EndProcedure

&AtClient
Procedure LogOnActivateField(Item)
	
	CanFilterCurrentColumnByValue =
		Item.CurrentItem <> Items.Date
		And Item.CurrentItem <> Items.Date2;
	
	Items.SetFilterByValueInCurrentColumn.Enabled
		= CanFilterCurrentColumnByValue;
	
	Items.SetFilterByValueInCurrentColumn2.Enabled
		= CanFilterCurrentColumnByValue;
	
	Items.SetFilterByValueInCurrentColumnContext.Enabled
		= CanFilterCurrentColumnByValue;
	
	Items.SetFilterByValueInCurrentColumnContext2.Enabled
		= CanFilterCurrentColumnByValue;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ValueSelected) = Type("Structure") And ValueSelected.Property("Event") Then
		
		If ValueSelected.Event = "EventLogFilterSet" Then
			
			EventLogFilter.Clear();
			For Each ListItem In ValueSelected.Filter Do
				EventLogFilter.Insert(ListItem.Presentation, ListItem.Value);
			EndDo;
			
			If EventLogFilter.Property("Level") Then
				If EventLogFilter.Level.Count() > 0 Then
					Severity = String(EventLogFilter.Level);
				EndIf;
			Else
				Severity = "AllEvents";
			EndIf;
			
			RefreshCurrentList();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure RefreshCurrentList()
	
	Items.Pages.CurrentPage = Items.TimeConsumingOperationProgress;
	CommonClientServer.SetSpreadsheetDocumentFieldState(Items.TimeConsumingOperationProgressField, "ReportGeneration");
	
	ExecutionResult = ReadEventLog();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	CallbackOnCompletion = New NotifyDescription("RefreshCurrentListCompletion", ThisObject);
	
	TimeConsumingOperationsClient.WaitCompletion(ExecutionResult, CallbackOnCompletion, IdleParameters);
	
EndProcedure

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure RefreshCurrentListCompletion(Result, AdditionalParameters) Export
	
	Items.Pages.CurrentPage = Items.EventLog;
	CommonClientServer.SetSpreadsheetDocumentFieldState(
		Items.TimeConsumingOperationProgressField, "DontUse");
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Completed2" Then
		LoadPreparedData(Result.ResultAddress);
		ScrollToListBottom();
	ElsIf Result.Status = "Error" Then
		ScrollToListBottom();
		StandardSubsystemsClient.OutputErrorInfo(Result.ErrorInfo);
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearFilter()
	
	EventLogFilter = DefaultEventLogFilter;
	Severity = "AllEvents";
	RefreshCurrentList();
	
EndProcedure

&AtClient
Procedure OpenDataForViewing()
	
	EventLogClient.OpenDataForViewing(ItemLog().CurrentData);
	
EndProcedure

&AtClient
Procedure ViewCurrentEventInNewWindow()
	
	EventLogClient.ViewCurrentEventInNewWindow(ItemLog().CurrentData);
	
EndProcedure

&AtClient
Procedure SetPeriodForViewing()
	
	Notification = New NotifyDescription("SetPeriodForViewingCompletion", ThisObject);
	EventLogClient.SetPeriodForViewing(DateInterval, EventLogFilter, Notification)
	
EndProcedure

&AtClient
Procedure SetFilter()
	
	SetFilterOnClient();
	
EndProcedure

&AtClient
Procedure FilterPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	SetFilterOnClient();
	
EndProcedure

&AtClient
Procedure SetFilterByValueInCurrentColumn()
	
	ExcludeColumns = New Array;
	ExcludeColumns.Add("Date");
	
	Item = ItemLog();
	CurrentItemName = Item.CurrentItem.Name;
	
	If StrEndsWith(CurrentItemName, "2")
	 Or StrEndsWith(CurrentItemName, "3") Then
		
		CurrentItemName = Mid(CurrentItemName, 1, StrLen(CurrentItemName) - 1);
	EndIf;
	
	If EventLogClient.SetFilterByValueInCurrentColumn(Item.CurrentData,
			CurrentItemName, EventLogFilter, ExcludeColumns) Then
		
		RefreshCurrentList();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportLogForTechnicalSupport(Command)
	
	FileSavingParameters = FileSystemClient.FileSavingParameters();
	FileSavingParameters.Dialog.Filter = NStr("en = 'Event log data';") + "(*.xml)|*.xml";
	FileSystemClient.SaveFile(Undefined, ExportRegistrationLog(), "EventLog.xml", FileSavingParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure SetSeparationVisibility(Form, SeparationVisibility)
	
	Items = Form.Items;
	
	Items.DataArea.Visible  = SeparationVisibility And Form.StandardSeparatorsOnly;
	Items.DataArea2.Visible = SeparationVisibility And Form.StandardSeparatorsOnly;
	Items.DataArea3.Visible = SeparationVisibility And Form.StandardSeparatorsOnly;
	
	Items.SessionDataSeparationPresentation.Visible =
		SeparationVisibility And Not Form.StandardSeparatorsOnly;
	
	Items.SessionDataSeparationPresentation2.Visible =
		SeparationVisibility And Not Form.StandardSeparatorsOnly;
	
	If SeparationVisibility And Form.StandardSeparatorsOnly Then
		GroupTitle = NStr("en = 'App, Session, Area';");
		GroupTip = NStr("en = 'App, Session, Data area';");
	Else
		GroupTitle = NStr("en = 'App, Session';");
		GroupTip = "";
	EndIf;
	Items.ApplicationSessionGroup.Title = GroupTitle;
	Items.ApplicationSessionGroup.ToolTip = GroupTip;
	Items.ApplicationSessionGroup2.Title = GroupTitle;
	Items.ApplicationSessionGroup2.ToolTip = GroupTip;
	
EndProcedure

&AtClient
Function ItemLog()
	Return ?(Items.Log.Visible, Items.Log, Items.Log2);
EndFunction

&AtClient
Procedure SetPeriodForViewingCompletion(IntervalSet, AdditionalParameters) Export
	
	If IntervalSet Then
		RefreshCurrentList();
	EndIf;
	
EndProcedure

// Parameters:
//  Event - String
//
// Returns:
//  String, Undefined
//
&AtServer
Function EventPresentation(Event, FilterValues)
	
	EventPresentation = EventLogEventPresentation(Event);
	
	If ValueIsFilled(EventPresentation) Then
		Return EventPresentation;
	EndIf;
	
	EventPresentation = FilterValues[Event];
	
	If ValueIsFilled(EventPresentation) Then
		Return EventPresentation;
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtServer
Function FilterDefault(EventsList)
	
	FilterDefault = New ValueList;
	
	For Each LogEvent In EventsList Do
		
		If LogEvent.Key = "_$Transaction$_.Commit"
			Or LogEvent.Key = "_$Transaction$_.Begin"
			Or LogEvent.Key = "_$Transaction$_.Rollback" Then
			Continue;
		EndIf;
		
		FilterDefault.Add(LogEvent.Key, LogEvent.Value);
		
	EndDo;
	
	Return FilterDefault;
EndFunction

&AtServer
Function FilterByUserFromParameter(ParameterUser)
	
	If Not ValueIsFilled(ParameterUser) Then
		Return Undefined;
	EndIf;
	
	FilterByUser = New ValueList;
	References = New Array;
	Names = New Array;
	
	If TypeOf(ParameterUser) = Type("ValueList") Then
		For Each ListItem In ParameterUser Do
			ProcessItem(ListItem.Value, References, Names);
		EndDo;
	ElsIf TypeOf(ParameterUser) = Type("Array") Then
		For Each Value In ParameterUser Do
			ProcessItem(Value, References, Names);
		EndDo;
	Else
		ProcessItem(ParameterUser, References, Names);
	EndIf;
	
	SetPrivilegedMode(True);
	
	For Each Name In Names Do
		IBUser = InfoBaseUsers.FindByName(Name);
		If IBUser = Undefined Then
			FilterByUser.Add(Name, Name);
		Else
			FilterByUser.Add(Lower(IBUser.UUID), Name);
		EndIf;
	EndDo;
	
	If ValueIsFilled(References) Then
		Query = New Query;
		Query.SetParameter("References", References);
		Query.Text =
		"SELECT
		|	CurrentTable.Description AS Description,
		|	CurrentTable.IBUserID AS IBUserID
		|FROM
		|	Catalog.Users AS CurrentTable
		|WHERE
		|	CurrentTable.Ref IN(&References)
		|
		|UNION ALL
		|
		|SELECT
		|	CurrentTable.Description,
		|	CurrentTable.IBUserID
		|FROM
		|	Catalog.ExternalUsers AS CurrentTable
		|WHERE
		|	CurrentTable.Ref IN(&References)";
		Selection = Query.Execute().Select();
		UserWithEmptyUUID = Undefined;
		While Selection.Next() Do
			If Not ValueIsFilled(Selection.IBUserID) Then
				UserWithEmptyUUID = Selection.Description;
				Continue;
			EndIf;
			If FilterByUser.FindByValue(Lower(Selection.IBUserID)) <> Undefined Then
				Continue;
			EndIf;
			IBUser = InfoBaseUsers.FindByUUID(
				Selection.IBUserID);
			
			If IBUser = Undefined Then
				FilterByUser.Add(Lower(Selection.IBUserID), Selection.Description);
			Else
				FilterByUser.Add(Lower(Selection.IBUserID), IBUser.Name);
			EndIf;
		EndDo;
		If Not ValueIsFilled(FilterByUser)
		   And ValueIsFilled(UserWithEmptyUUID) Then
			FilterByUser.Add(Lower(New UUID), UserWithEmptyUUID);
		EndIf;
	EndIf;
	
	Return FilterByUser;
	
EndFunction

&AtServer
Procedure ProcessItem(Value, References, Names)
	
	If TypeOf(Value) = Type("CatalogRef.Users")
	 Or TypeOf(Value) = Type("CatalogRef.ExternalUsers") Then
		
		If References.Find(Value) = Undefined Then
			References.Add(Value);
		EndIf;
		
	ElsIf TypeOf(Value) = Type("String") Then
		
		If Names.Find(Value) = Undefined Then
			Names.Add(Value);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function ReadEventLog()
	
	If ValueIsFilled(JobID) Then
		TimeConsumingOperations.CancelJobExecution(JobID);
	EndIf;
	
	StartDate    = Undefined; // Date
	EndDate = Undefined; // Date
	FilterDatesSpecified = EventLogFilter.Property("StartDate", StartDate)
		And ValueIsFilled(StartDate)
		And EventLogFilter.Property("EndDate", EndDate)
		And ValueIsFilled(EndDate);
		
	If FilterDatesSpecified And StartDate > EndDate Then
		CommonClientServer.SetSpreadsheetDocumentFieldState(
			Items.TimeConsumingOperationProgressField, "DontUse");
		Items.Pages.CurrentPage = Items.EventLog;
		Raise NStr("en = 'Incorrect event log filter settings. 
			|The start date cannot be later than the end date.';");
	EndIf;
	
	ReportParameters = ReportParameters();
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.WaitCompletion = 0; // Run immediately.
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Updating event log';");
	ExecutionParameters.RunNotInBackground1 = ShouldNotRunInBackground;
	
	TimeConsumingOperation = TimeConsumingOperations.ExecuteInBackground("EventLog.ReadEventLogEvents",
		ReportParameters, ExecutionParameters);
	
	If TimeConsumingOperation.Status = "Running" Then
		JobID = TimeConsumingOperation.JobID;
	EndIf;
	
	If TimeConsumingOperation.Status = "Running"
	 Or TimeConsumingOperation.Status = "Completed2" Then
	
		EventLog.GenerateFilterPresentation(FilterPresentation,
			EventLogFilter, DefaultEventLogFilter);
	EndIf;
	
	Return TimeConsumingOperation;
	
EndFunction

&AtServer
Function ReportParameters()
	
	ReportParameters = New Structure;
	ReportParameters.Insert("EventLogFilter", EventLogFilter);
	ReportParameters.Insert("EventsCountLimit", EventsCountLimit);
	ReportParameters.Insert("UUID", UUID);
	ReportParameters.Insert("OwnerManager", DataProcessors.EventLog);
	ReportParameters.Insert("AddAdditionalColumns", False);
	ReportParameters.Insert("Log", FormAttributeToValue("Log"));

	Return ReportParameters;
EndFunction

&AtServer
Procedure LoadPreparedData(ResultAddress)
	Result      = GetFromTempStorage(ResultAddress);
	LogEvents = Result.LogEvents;
	
	ValueToFormData(LogEvents, Log);
EndProcedure

&AtClient
Procedure ScrollToListBottom()
	If Log.Count() > 0 Then
		ItemLog().CurrentRow = Log[Log.Count() - 1].GetID();
	EndIf;
EndProcedure 

&AtClient
Procedure SetFilterOnClient()
	
	FilterForms = New ValueList;
	For Each KeyAndValue In EventLogFilter Do
		FilterForms.Add(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	
	OpenForm(
		"DataProcessor.EventLog.Form.EventLogFilter", 
		New Structure("Filter, DefaultEvents", FilterForms, DefaultEventLogFilter.Event), 
		ThisObject);
	
EndProcedure

&AtClient
Procedure SeverityClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtServer
Function ExportRegistrationLog()
	Return EventLog.TechnicalSupportLog(EventLogFilter, EventsCountLimit, UUID);
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Importance
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	If Parameters.DataAccessLog Then
		ItemField.Field = New DataCompositionField(Items.Importance2.Name);
	Else
		ItemField.Field = New DataCompositionField(Items.Importance.Name);
	EndIf;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Log.Level");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("Visible", False);
	
	// Data
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	If Parameters.DataAccessLog Then
		ItemField.Field = New DataCompositionField(Items.Data2.Name);
	Else
		ItemField.Field = New DataCompositionField(Items.Data.Name);
	EndIf;
	
	AddDataColumnHideCondition(Item.Filter.Items);
	
	Item.Appearance.SetParameterValue("Visible", False);
	
	Items.Data.Format  = NStr("en = 'NZ=0; DE=''01.01.0001 00:00:00''';");
	Items.Data2.Format = Items.Data.Format;
	
	// DataPresentation
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	If Parameters.DataAccessLog Then
		ItemField.Field = New DataCompositionField(Items.DataPresentation2.Name);
	Else
		ItemField.Field = New DataCompositionField(Items.DataPresentation.Name);
	EndIf;
	
	AddConditionToHideDataPresentationColumn(Item.Filter.Items);
	
	Item.Appearance.SetParameterValue("Visible", False);
	
	// MetadataPresentation
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	If Parameters.DataAccessLog Then
		ItemField.Field = New DataCompositionField(Items.MetadataPresentation2.Name);
	Else
		ItemField.Field = New DataCompositionField(Items.MetadataPresentation.Name);
	EndIf;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Log.MetadataPresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visible", False);
	
	// Comment
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	If Parameters.DataAccessLog Then
		ItemField.Field = New DataCompositionField(Items.Comment2.Name);
	Else
		ItemField.Field = New DataCompositionField(Items.Comment.Name);
	EndIf;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Log.Comment");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	Var_Group = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	Var_Group.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	Subgroup = Var_Group.Items.Add(Type("DataCompositionFilterItemGroup"));
	Subgroup.GroupType = DataCompositionFilterItemsGroupType.NotGroup;
	AddDataColumnHideCondition(Subgroup.Items);
	
	Subgroup = Var_Group.Items.Add(Type("DataCompositionFilterItemGroup"));
	Subgroup.GroupType = DataCompositionFilterItemsGroupType.NotGroup;
	AddConditionToHideDataPresentationColumn(Subgroup.Items);
	
	ItemFilter = Var_Group.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Log.DataPresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("Visible", False);
	
EndProcedure

&AtServer
Procedure AddDataColumnHideCondition(FilterItems1)
	
	ValuesToDisplay = New ValueList;
	ValuesToDisplay.Add(0);
	ValuesToDisplay.Add('00010101');
	ValuesToDisplay.Add(False);
	
	Var_Group = FilterItems1.Add(Type("DataCompositionFilterItemGroup"));
	Var_Group.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = Var_Group.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Log.Data");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	ItemFilter = Var_Group.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Log.Data");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotInList;
	ItemFilter.RightValue = ValuesToDisplay;
	
EndProcedure

&AtServer
Procedure AddConditionToHideDataPresentationColumn(FilterItems1);
	
	Var_Group = FilterItems1.Add(Type("DataCompositionFilterItemGroup"));
	Var_Group.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	ItemFilter = Var_Group.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Log.DataPresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	ItemFilter = Var_Group.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Log.IsDataStringMatchesDataPresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
EndProcedure

#EndRegion
