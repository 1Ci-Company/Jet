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
	
	FillImportanceAndStatus();
	FillFilterParameters();
	
	DefaultEvents = Parameters.DefaultEvents;
	If DefaultEvents.Count() <> Events.Count() Then
		EventsToDisplay = Events.Copy();
	EndIf;
	
	SeparationVisibility = Not Common.SeparatedDataUsageAvailable();
	StandardSeparatorsOnly = EventLog.StandardSeparatorsOnly();
	Items.SessionDataSeparation.Visible = SeparationVisibility And Not StandardSeparatorsOnly;
	Items.DataAreas.Visible = SeparationVisibility And StandardSeparatorsOnly;
	If Items.DataAreas.Visible Then
		For Each ListItem In SessionDataSeparation Do
			If StrStartsWith(ListItem.Value, "DataAreaMainData") Then
				StringParts1 = StrSplit(ListItem.Value, "=");
				DataAreas = EventLog.StringDelimitersList(StringParts1[1]);
				Break;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "EventLogFilterItemValueChoice"
	   And Source.UUID = UUID Then
		If PropertyCompositionEditorItemName = Items.Users.Name Then
			UsersList = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.Events.Name Then
			Events = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.Computers.Name Then
			Computers = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.Applications.Name Then
			Applications = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.Metadata.Name Then
			Metadata = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.WorkingServers.Name Then
			WorkingServers = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.PrimaryIPPorts.Name Then
			PrimaryIPPorts = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.SecondaryIPPorts.Name Then
			SecondaryIPPorts = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.DataAreas.Name Then
			DataAreas = Parameter;
			SessionDataSeparation = CompleteListOfSeparators(Parameter);
		ElsIf PropertyCompositionEditorItemName = Items.SessionDataSeparation.Name Then
			SessionDataSeparation = Parameter;
		EndIf;
	EndIf;
	
	EventsToDisplay.Clear();
	
	If Events.Count() = 0 Then
		Events = DefaultEvents;
		Return;
	EndIf;
	
	If DefaultEvents.Count() <> Events.Count() Then
		EventsToDisplay = Events.Copy();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ChoiceCompletion(Item, ChoiceData, StandardProcessing)
	
	Var ListToEdit, ParametersToSelect;
	
	DisableStandardProcessing = True;
	PropertyCompositionEditorItemName = Item.Name;
	
	If PropertyCompositionEditorItemName = Items.Users.Name Then
		ListToEdit = UsersList;
		ParametersToSelect = "User";
	ElsIf PropertyCompositionEditorItemName = Items.Events.Name Then
		ListToEdit = Events;
		ParametersToSelect = "Event";
	ElsIf PropertyCompositionEditorItemName = Items.Computers.Name Then
		ListToEdit = Computers;
		ParametersToSelect = "Computer";
	ElsIf PropertyCompositionEditorItemName = Items.Applications.Name Then
		ListToEdit = Applications;
		ParametersToSelect = "ApplicationName";
	ElsIf PropertyCompositionEditorItemName = Items.Metadata.Name Then
		ListToEdit = Metadata;
		ParametersToSelect = "Metadata";
	ElsIf PropertyCompositionEditorItemName = Items.WorkingServers.Name Then
		ListToEdit = WorkingServers;
		ParametersToSelect = "ServerName";
	ElsIf PropertyCompositionEditorItemName = Items.PrimaryIPPorts.Name Then
		ListToEdit = PrimaryIPPorts;
		ParametersToSelect = "PrimaryIPPort";
	ElsIf PropertyCompositionEditorItemName = Items.SecondaryIPPorts.Name Then
		ListToEdit = SecondaryIPPorts;
		ParametersToSelect = "SyncPort";
	ElsIf PropertyCompositionEditorItemName = Items.DataAreas.Name Then
		ListToEdit = DataAreas;
		ParametersToSelect = "SessionDataSeparationValues" + "." + "DataAreaMainData";
	ElsIf PropertyCompositionEditorItemName = Items.SessionDataSeparation.Name Then
		StandardProcessing = False;
		FormParameters = New Structure;
		FormParameters.Insert("ActiveFilter", SessionDataSeparation);
		OpenForm("DataProcessor.EventLog.Form.SessionDataSeparation", FormParameters, ThisObject);
		Return;
	Else
		DisableStandardProcessing = False;
		Return;
	EndIf;
	
	If DisableStandardProcessing Then
		StandardProcessing = False;
	EndIf;
	
	FormParameters = New Structure;
	
	FormParameters.Insert("ListToEdit", ListToEdit);
	FormParameters.Insert("ParametersToSelect", ParametersToSelect);
	
	// Open the property editor.
	OpenForm("DataProcessor.EventLog.Form.PropertyCompositionEditor",
	             FormParameters,
	             ThisObject);
	
EndProcedure

&AtClient
Procedure DataAreasClearing(Item, StandardProcessing)
	
	SessionDataSeparation.Clear();
	
EndProcedure

&AtClient
Procedure EventsClearing(Item, StandardProcessing)
	
	Events = DefaultEvents;
	
EndProcedure

&AtClient
Procedure FilterPeriodOnChange(Item)
	
	HandlerNotifications = New NotifyDescription("FilterPeriodOnChangeCompletion", ThisObject);
	
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = FilterDateRange;
	Dialog.Show(HandlerNotifications);
	
EndProcedure

&AtClient
Procedure FilterPeriodOnChangeCompletion(Period, AdditionalParameters) Export
	
	If Period = Undefined Then
		Return;
	EndIf;
	
	FilterDateRange = Period;
	FilterPeriodStartDate    = FilterDateRange.StartDate;
	FilterPeriodEndDate = FilterDateRange.EndDate;
	
EndProcedure

&AtClient
Procedure FilterPeriodDateOnChange(Item)
	
	FilterDateRange.Variant       = StandardPeriodVariant.Custom;
	FilterDateRange.StartDate    = FilterPeriodStartDate;
	FilterDateRange.EndDate = FilterPeriodEndDate;
	
EndProcedure

&AtClient
Procedure MultipleValuesOnChange(Item)
	
	DataName = Items.Data.Name;
	DataListName = Items.Data_List.Name;
	SingleValue = Not DataMultipleValues;
	
	Items[DataName].Visible = SingleValue;
	Items[DataListName].Visible = Not SingleValue;
	CurrentData = ThisObject[DataName];
	CurrentList = ThisObject[DataListName];
	
	If SingleValue Then
		ThisObject[DataName] = ?(CurrentList.Count() = 0,
			Undefined, CurrentList[0].Value);
		
	ElsIf ValueIsFilled(CurrentData)
	      Or CurrentList.Count() > 0 Then
		
		If CurrentList.Count() = 0 Then
			CurrentList.Add();
		EndIf;
		CurrentList[0].Value = CurrentData;
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	UpdateCommentField(ThisObject);
	
EndProcedure

&AtClient
Procedure CommentEditTextChange(Item, Text, StandardProcessing)
	
	UpdateCommentField(ThisObject, Text);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SetFilterAndCloseForm(Command)
	
	NotifyChoice(
		New Structure("Event, Filter", 
			"EventLogFilterSet", 
			GetEventLogFilter()));
	
EndProcedure

&AtClient
Procedure SelectSeverityCheckBoxes(Command)
	For Each ListItem In Importance Do
		ListItem.Check = True;
	EndDo;
EndProcedure

&AtClient
Procedure ClearSeverityCheckBoxes(Command)
	For Each ListItem In Importance Do
		ListItem.Check = False;
	EndDo;
EndProcedure

&AtClient
Procedure SelectTransactionStatusesCheckBoxes(Command)
	For Each ListItem In TransactionStatus Do
		ListItem.Check = True;
	EndDo;
EndProcedure

&AtClient
Procedure ClearTransactionStatuses(Command)
	For Each ListItem In TransactionStatus Do
		ListItem.Check = False;
	EndDo;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillImportanceAndStatus()
	// Filling the Importance form item
	Importance.Add("Error",         String(EventLogLevel.Error));
	Importance.Add("Warning", String(EventLogLevel.Warning));
	Importance.Add("Information",     String(EventLogLevel.Information));
	Importance.Add("Note",     String(EventLogLevel.Note));
	
	// Filling the TransactionStatus form item
	TransactionStatus.Add("NotApplicable", String(EventLogEntryTransactionStatus.NotApplicable));
	TransactionStatus.Add("Committed", String(EventLogEntryTransactionStatus.Committed));
	TransactionStatus.Add("Unfinished",   String(EventLogEntryTransactionStatus.Unfinished));
	TransactionStatus.Add("RolledBack",      String(EventLogEntryTransactionStatus.RolledBack));
	
EndProcedure

&AtServer
Procedure FillFilterParameters()
	
	FilterParameterList = Parameters.Filter;
	HasFilterByLevel  = False;
	HasFilterByStatus = False;
	
	For Each FilterParameter In FilterParameterList Do
		ParameterName = FilterParameter.Presentation;
		Value     = FilterParameter.Value;
		
		If Upper(ParameterName) = Upper("StartDate") Then
			// StartDate.
			FilterDateRange.StartDate = Value;
			FilterPeriodStartDate  = Value;
			
		ElsIf Upper(ParameterName) = Upper("EndDate") Then
			// EndDate.
			FilterDateRange.EndDate = Value;
			FilterPeriodEndDate  = Value;
			
		ElsIf Upper(ParameterName) = Upper("User") Then
			// User.
			UsersList = Value;
			
		ElsIf Upper(ParameterName) = Upper("Event") Then
			// Event.
			Events = Value;
			
		ElsIf Upper(ParameterName) = Upper("Computer") Then
			// Computer.
			Computers = Value;
			
		ElsIf Upper(ParameterName) = Upper("ApplicationName") Then
			// ApplicationName.
			Applications = Value;
			
		ElsIf Upper(ParameterName) = Upper("Comment") Then
			// Comment.
			Comment = Value;
			UpdateCommentField(ThisObject);
			
		ElsIf Upper(ParameterName) = Upper("Metadata") Then
			// Metadata.
			Metadata = Value;
			
		ElsIf Upper(ParameterName) = Upper("Data") Then
			// Data. 
			If TypeOf(Value) = Type("ValueList") Then
				DataMultipleValues = True;
				Items.Data.Visible = False;
				Items.Data_List.Visible = True;
				Data_List = Value;
			Else
				Data = Value;
			EndIf;
			
		ElsIf Upper(ParameterName) = Upper("DataPresentation") Then
			// DataPresentation.
			DataPresentation = Value;
			
		ElsIf Upper(ParameterName) = Upper("Transaction") Then
			// TransactionID.
			Transaction = Value;
			
		ElsIf Upper(ParameterName) = Upper("ServerName") Then
			// ServerName.
			WorkingServers = Value;
			
		ElsIf Upper(ParameterName) = Upper("Session") Then
			// Session.
			Sessions = Value;
			SessionsString = "";
			For Each SessionNumber In Sessions Do
				SessionsString = SessionsString + ?(SessionsString = "", "", "; ") + SessionNumber;
			EndDo;
			
		ElsIf Upper(ParameterName) = Upper("PrimaryIPPort") Then
			// Port.
			PrimaryIPPorts = Value;
			
		ElsIf Upper(ParameterName) = Upper("SyncPort") Then
			// SyncPort.
			SecondaryIPPorts = Value;
			
		ElsIf Upper(ParameterName) = Upper("Level") Then
			// Level.
			HasFilterByLevel = True;
			For Each ValueListItem In Importance Do
				If Value.FindByValue(ValueListItem.Value) <> Undefined Then
					ValueListItem.Check = True;
				EndIf;
			EndDo;
			
		ElsIf Upper(ParameterName) = Upper("TransactionStatus") Then
			// TransactionStatus.
			HasFilterByStatus = True;
			For Each ValueListItem In TransactionStatus Do
				If Value.FindByValue(ValueListItem.Value) <> Undefined Then
					ValueListItem.Check = True;
				EndIf;
			EndDo;
			
		ElsIf Upper(ParameterName) = Upper("SessionDataSeparation") Then
			
			If TypeOf(Value) = Type("ValueList") Then
				SessionDataSeparation = Value.Copy();
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If Not HasFilterByLevel Then
		For Each ValueListItem In Importance Do
			ValueListItem.Check = True;
		EndDo;
	EndIf;
	
	If Not HasFilterByStatus Then
		For Each ValueListItem In TransactionStatus Do
			ValueListItem.Check = True;
		EndDo;
	ElsIf HasFilterByStatus Or ValueIsFilled(Transaction) Then
		Items.TransactionsGroup.Title = Items.TransactionsGroup.Title + " *";
	EndIf;
	
	If ValueIsFilled(WorkingServers)
		Or ValueIsFilled(PrimaryIPPorts)
		Or ValueIsFilled(SecondaryIPPorts) Then
		Items.OthersGroup.Title = Items.OthersGroup.Title + " *";
	EndIf;
	
EndProcedure

&AtClient
Function GetEventLogFilter()
	
	Sessions.Clear();
	Page1 = SessionsString;
	Page1 = StrReplace(Page1, ";", " ");
	Page1 = StrReplace(Page1, ",", " ");
	Page1 = TrimAll(Page1);
	TS = New TypeDescription("Number");
	
	While Not IsBlankString(Page1) Do
		Pos = StrFind(Page1, " ");
		
		If Pos = 0 Then
			Value = TS.AdjustValue(Page1);
			Page1 = "";
		Else
			Value = TS.AdjustValue(Left(Page1, Pos-1));
			Page1 = TrimAll(Mid(Page1, Pos+1));
		EndIf;
		
		If Value <> 0 Then
			Sessions.Add(Value);
		EndIf;
	EndDo;
	
	Filter = New ValueList;
	
	// Start and end dates.
	If FilterPeriodStartDate <> '00010101000000' Then 
		Filter.Add(FilterPeriodStartDate, "StartDate");
	EndIf;
	If FilterPeriodEndDate <> '00010101000000' Then
		Filter.Add(FilterPeriodEndDate, "EndDate");
	EndIf;
	
	// User.
	If UsersList.Count() > 0 Then 
		Filter.Add(UsersList, "User");
	EndIf;
	
	// Event.
	If Events.Count() > 0 Then 
		Filter.Add(Events, "Event");
	EndIf;
	
	// Computer.
	If Computers.Count() > 0 Then 
		Filter.Add(Computers, "Computer");
	EndIf;
	
	// ApplicationName.
	If Applications.Count() > 0 Then 
		Filter.Add(Applications, "ApplicationName");
	EndIf;
	
	// Comment.
	If Not IsBlankString(Comment) Then 
		Filter.Add(Comment, "Comment");
	EndIf;
	
	// Metadata.
	If Metadata.Count() > 0 Then 
		Filter.Add(Metadata, "Metadata");
	EndIf;
	
	// Data. 
	FilterValue = ?(DataMultipleValues, Data_List, Data);
	If ValueIsFilled(FilterValue) Then
		Filter.Add(FilterValue, "Data");
	EndIf;
	
	// DataPresentation.
	If Not IsBlankString(DataPresentation) Then 
		Filter.Add(DataPresentation, "DataPresentation");
	EndIf;
	
	// TransactionID.
	If Not IsBlankString(Transaction) Then 
		Filter.Add(Transaction, "Transaction");
	EndIf;
	
	// ServerName.
	If WorkingServers.Count() > 0 Then 
		Filter.Add(WorkingServers, "ServerName");
	EndIf;
	
	// Session.
	If Sessions.Count() > 0 Then 
		Filter.Add(Sessions, "Session");
	EndIf;
	
	// Port.
	If PrimaryIPPorts.Count() > 0 Then 
		Filter.Add(PrimaryIPPorts, "PrimaryIPPort");
	EndIf;
	
	// SyncPort.
	If SecondaryIPPorts.Count() > 0 Then 
		Filter.Add(SecondaryIPPorts, "SyncPort");
	EndIf;
	
	// SessionDataSeparation.
	If SessionDataSeparation.Count() > 0 Then 
		Filter.Add(SessionDataSeparation, "SessionDataSeparation");
	EndIf;
	
	// Level.
	LevelList = New ValueList;
	For Each ValueListItem In Importance Do
		If ValueListItem.Check Then 
			LevelList.Add(ValueListItem.Value, ValueListItem.Presentation);
		EndIf;
	EndDo;
	If LevelList.Count() > 0 And LevelList.Count() <> Importance.Count() Then
		Filter.Add(LevelList, "Level");
	EndIf;
	
	// TransactionStatus.
	StatusesList = New ValueList;
	For Each ValueListItem In TransactionStatus Do
		If ValueListItem.Check Then 
			StatusesList.Add(ValueListItem.Value, ValueListItem.Presentation);
		EndIf;
	EndDo;
	If StatusesList.Count() > 0 And StatusesList.Count() <> TransactionStatus.Count() Then
		Filter.Add(StatusesList, "TransactionStatus");
	EndIf;
	
	Return Filter;
	
EndFunction

&AtClientAtServerNoContext
Procedure UpdateCommentField(Form, Text = Undefined)
	
	If Text = Undefined Then
		Text = Form.Comment;
	EndIf;
	
	Rows = StrSplit(Text, Chars.LF);
	If Rows.Count() > 1 Then
		NewHeight = 2;
	Else
		NewHeight = 1;
	EndIf;
	
	If Form.Items.Comment.Height <> NewHeight Then
		Form.Comment = Text;
		Form.Items.Comment.Height = NewHeight;
	EndIf;
	
	MaxLength = 1;
	For Each String In Rows Do
		If StrLen(String) > MaxLength Then
			MaxLength = StrLen(String);
		EndIf;
	EndDo;
	
	If MaxLength > 70 Then
		NewStretch = True;
	Else
		NewStretch = False;
	EndIf;
	
	If Form.Items.Comment.HorizontalStretch <> NewStretch Then
		Form.Comment = Text;
		Form.Items.Comment.HorizontalStretch = NewStretch;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CompleteListOfSeparators(Parameter)
	
	Presentations = New Array;
	For Each ListItem In Parameter Do
		If ValueIsFilled(ListItem.Presentation) Then
			Presentations.Add(ListItem.Presentation);
		Else
			Presentations.Add(ListItem.Value);
		EndIf;
	EndDo;
	
	ValuesPresentation = StrConcat(Presentations, ", ");
	StringValues = StrConcat(Parameter.UnloadValues(), ",");
	
	List = New ValueList;
	
	For Each CommonAttribute In Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.DontUse Then
			Continue;
		EndIf;
		SeparatorPresentation = CommonAttribute.Presentation() + " = " + ValuesPresentation;
		SeparatorValue = CommonAttribute.Name + "=" + StringValues;
		List.Add(SeparatorValue, SeparatorPresentation);
	EndDo;
	
	Return List;
	
EndFunction

#EndRegion
