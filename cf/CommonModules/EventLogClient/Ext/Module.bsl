///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// Adds a message to the Event log.
// If "WriteEvents" is set to "True", the message is written immediately through a server call.
// If "WriteEvents" is set to "False" (the default value), the message is queued.
// The queue will be written to the log either within 60 seconds,
// or when this procedure is called with "WriteEvents" set to "True",
// or then the "WriteEventsToEventLog" procedure is called.
//
//  Parameters: 
//   EventName          - String - an event name for the event log;
//   LevelPresentation - String - description of the event level that determines the event level when writing the event data on
//                                  server;
//                                  For example: "Error", "Warning".
//                                  Corresponded to the names of the EventLogLevel enumeration items.
//   Comment         - String - the comment to the log event;
//   EventDate         - Date   - the exact occurrence date of the event described in the message. This date will be added to the beginning
//                                  of the comment;
//   WriteEvents     - Boolean - write all accumulated events to the event log, through
//                                  a server call.
//
// Example:
//  EventLogClient.AddMessageForEventLog(EventLogEvent(), "Warning",
//     NStr("en = 'Cannot establish Internet connection to check for updates."));
//
Procedure AddMessageForEventLog(Val EventName, Val LevelPresentation = "Information", 
	Val Comment = "", Val EventDate = "", Val WriteEvents = False) Export
	
	ProcedureName = "EventLogClient.AddMessageForEventLog";
	CommonClientServer.CheckParameter(ProcedureName, "EventName", EventName, Type("String"));
	CommonClientServer.CheckParameter(ProcedureName, "LevelPresentation", LevelPresentation, Type("String"));
	CommonClientServer.CheckParameter(ProcedureName, "Comment", Comment, Type("String"));
	If EventDate <> "" Then
		CommonClientServer.CheckParameter(ProcedureName, "EventDate", EventDate, Type("Date"));
	EndIf;
	
	ParameterName = "StandardSubsystems.MessagesForEventLog";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New ValueList);
	EndIf;
	
	If TypeOf(EventDate) = Type("Date") Then
		EventDate = Format(EventDate, "DLF=DT");
	EndIf;
	
	MessageStructure = New Structure;
	MessageStructure.Insert("EventDate", EventDate);
	MessageStructure.Insert("EventName", EventName);
	MessageStructure.Insert("LevelPresentation", LevelPresentation);
	MessageStructure.Insert("Comment",
		CommonClientServer.ReplaceProhibitedXMLChars(Comment, " "));
	
	Messages = ApplicationParameters["StandardSubsystems.MessagesForEventLog"]; // ValueList
	Messages.Add(MessageStructure);
	
	If WriteEvents Then
		WriteEventsToEventLog();
	EndIf;
	
EndProcedure

// Opens the event log form with the set filter.
//
// Parameters:
//  Filter - Structure:
//     * User              - String
//                                 - ValueList - the name of infobase user, or the list of names of infobase
//                                                    users.
//     * EventLogEvent - String
//                                 - Array - the ID of the event.
//     * StartDate                - Date           - the start date of the interval of displayed events.
//     * EndDate             - Date           - the end date of the interval of displayed events.
//     * Data                    - Arbitrary   - data of any type.
//     * Session                     - ValueList - the list of selected sessions.
//     * Level                   - String
//                                 - Array - presentation of importance level
//                                            of the log event.
//     * ApplicationName             - Array         - array of the application IDs.
//  Owner - ClientApplicationForm - the form used to open the event log.
//
Procedure OpenEventLog(Val Filter = Undefined, Owner = Undefined) Export
	
	OpenForm("DataProcessor.EventLog.Form", Filter, Owner);
	
EndProcedure

// Writes the message queue to the Event log through a server call.
// The messages are queued by the procedure "AddMessageForEventLog".
//
Procedure WriteEventsToEventLog() Export
	
	ParameterName = "StandardSubsystems.MessagesForEventLog";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New ValueList);
	EndIf;
	
	Messages = ApplicationParameters["StandardSubsystems.MessagesForEventLog"]; // ValueList
	If ValueIsFilled(Messages) Then
		EventLogServerCall.WriteEventsToEventLog(Messages);
		ApplicationParameters.Insert(ParameterName, Messages);
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

// Opens the form for viewing additional event data.
//
// Parameters:
//  CurrentData - ValueTableRow - an event log row.
//
Procedure OpenDataForViewing(CurrentData) Export
	
	If CurrentData = Undefined Or CurrentData.Data = Undefined Then
		ShowMessageBox(, NStr("en = 'The event log record is not linked to data (see the Data column)';"));
		Return;
	EndIf;
	
	Try
		ShowValue(, CurrentData.Data);
	Except
		WarningText = NStr("en = 'The event log record is linked to data that cannot be displayed.
									|%1';");
		If CurrentData.Event = "_$Data$_.Delete" Then 
			// This is a deletion event.
			WarningText =
					StringFunctionsClientServer.SubstituteParametersToString(WarningText, NStr("en = 'The data was deleted from the infobase';"));
		Else
			WarningText =
				StringFunctionsClientServer.SubstituteParametersToString(WarningText, NStr("en = 'Perhaps the data was deleted from the infobase';"));
		EndIf;
		ShowMessageBox(, WarningText);
	EndTry;
	
EndProcedure

// Opens the event view form of the "Event log" data processor
// to display detailed data for the selected event.
//
// Parameters:
//  Data - FormDataCollectionItem of See DataProcessor.EventLog.Form.EventLog.Log
//
Procedure ViewCurrentEventInNewWindow(Data) Export
	
	If Data = Undefined Then
		Return;
	EndIf;
	
	FormOpenParameters = EventLogEventToStructure(Data);
	OpenForm("DataProcessor.EventLog.Form.Event", FormOpenParameters,, Data.EventKey);
	
EndProcedure

// Prompts the user for the period restriction 
// and includes it in the event log filter.
//
// Parameters:
//  DateInterval - StandardPeriod - the filter date interval.
//  EventLogFilter - Structure
//  HandlerNotifications - NotifyDescription
//
Procedure SetPeriodForViewing(DateInterval, EventLogFilter, HandlerNotifications = Undefined) Export
	
	// Get the current period.
	StartDate    = Undefined;
	EndDate = Undefined;
	EventLogFilter.Property("StartDate", StartDate);
	EventLogFilter.Property("EndDate", EndDate);
	StartDate    = ?(TypeOf(StartDate)    = Type("Date"), StartDate, '00010101000000');
	EndDate = ?(TypeOf(EndDate) = Type("Date"), EndDate, '00010101000000');
	
	If DateInterval.StartDate <> StartDate Then
		DateInterval.StartDate = StartDate;
	EndIf;
	
	If DateInterval.EndDate <> EndDate Then
		DateInterval.EndDate = EndDate;
	EndIf;
	
	// Edit the current period.
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = DateInterval;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("EventLogFilter", EventLogFilter);
	AdditionalParameters.Insert("DateInterval", DateInterval);
	AdditionalParameters.Insert("HandlerNotifications", HandlerNotifications);
	
	Notification = New NotifyDescription("SetPeriodForViewingCompletion", ThisObject, AdditionalParameters);
	Dialog.Show(Notification);
	
EndProcedure

// Handles selection of a single event in the event table.
//
// Parameters:
//  Parameters - Structure:
//     * CurrentData - ValueTableRow - an event log row.
//     * Field - FormField - value table field.
//     * DateInterval - StandardPeriod
//     * EventLogFilter - Filter - the event log filter.
//     * NotificationHandlerForSettingDateInterval - NotifyDescription
//
Procedure EventsChoice(Parameters) Export
	
	If Parameters.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Parameters.Field.Name = "Data" Or Parameters.Field.Name = "DataPresentation" Then
		If TypeOf(Parameters.CurrentData.Data) <> Type("Undefined")
		   And TypeOf(Parameters.CurrentData.Data) <> Type("String")
		   And TypeOf(Parameters.CurrentData.Data) <> Type("Number")
		   And TypeOf(Parameters.CurrentData.Data) <> Type("Date")
		   And TypeOf(Parameters.CurrentData.Data) <> Type("Boolean")
		   And ValueIsFilled(Parameters.CurrentData.Data) Then
			
			OpenDataForViewing(Parameters.CurrentData);
			Return;
		EndIf;
	EndIf;
	
	If Parameters.Field.Name = "Date" Then
		SetPeriodForViewing(Parameters.DateInterval,
			Parameters.EventLogFilter,
			Parameters.NotificationHandlerForSettingDateInterval);
		Return;
	EndIf;
	
	ViewCurrentEventInNewWindow(Parameters.CurrentData);
	
EndProcedure

// Fills the filter according to the value in the current event column.
//
// Parameters:
//  CurrentData - ValueTableRow
//  CurrentItemName - String - Name of the current item in the value table.
//  EventLogFilter - Structure
//  ExcludeColumns - Array
//
// Returns:
//  Boolean - True if the filter is set, False otherwise.
//
Function SetFilterByValueInCurrentColumn(CurrentData, CurrentItemName,
			EventLogFilter, ExcludeColumns) Export
	
	If CurrentData = Undefined Then
		Return False;
	EndIf;
	
	If ExcludeColumns.Find(CurrentItemName) <> Undefined Then
		Return False;
	EndIf;
	
	FilterColumnName        = CurrentItemName;
	PresentationColumnName = CurrentItemName;
	
	If CurrentItemName = "MetadataPresentation" Then
		FilterColumnName = "Metadata";
		
	ElsIf CurrentItemName = "Metadata" Then
		PresentationColumnName = "MetadataPresentation";
		
	ElsIf CurrentItemName = "SessionDataSeparationPresentation"
	      Or CurrentItemName = "DataArea" Then
		
		FilterColumnName = "SessionDataSeparation";
		
	ElsIf CurrentItemName = "UserName" Then
		FilterColumnName = "User";
		
	ElsIf CurrentItemName = "ApplicationPresentation" Then
		FilterColumnName = "ApplicationName";
		
	ElsIf CurrentItemName = "EventPresentation" Then
		FilterColumnName = "Event";
	EndIf;
	
	FilterValue = CurrentData[FilterColumnName];
	Presentation  = CurrentData[PresentationColumnName];
	
	// Filtering by a blanked string is not allowed.
	If TypeOf(FilterValue) = Type("String") And IsBlankString(FilterValue) Then
		// The default user has a blank name, it is allowed to filter by this user.
		If PresentationColumnName <> "UserName" Then 
			Return False;
		EndIf;
	EndIf;
	
	EventLogFilter.Delete(FilterColumnName);
	EventLogFilter.Delete(PresentationColumnName);
	
	If FilterColumnName = "Data"
	   And ValueIsFilled(CurrentData.DataAsStr) Then
		
		FilterValue = New ValueList;
		FilterValue.Add(CurrentData.DataAsStr, CurrentData.Data);
	EndIf;
	
	If FilterColumnName = "Metadata"
	 Or FilterColumnName = "Data"
	 Or FilterColumnName = "Comment"
	 Or FilterColumnName = "Transaction"
	 Or FilterColumnName = "DataPresentation" Then
		
		EventLogFilter.Insert(FilterColumnName, FilterValue);
	Else
		
		If FilterColumnName = "SessionDataSeparation" Then
			FilterList = FilterValue.Copy();
		ElsIf FilterColumnName = "User"
		        And FilterValue = String(CommonClientServer.BlankUUID()) Then
			Return False;
		Else
			FilterList = New ValueList;
			FilterList.Add(FilterValue, Presentation);
		EndIf;
		
		EventLogFilter.Insert(FilterColumnName, FilterList);
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#Region Private

// For internal use only.
// 
// Parameters:
//  Data - FormDataCollectionItem: See DataProcessor.EventLog.Form.EventLog.Log
// 
// Returns:
//  Structure
//
Function EventLogEventToStructure(Data)
	
	If TypeOf(Data) = Type("Structure") Then
		Return Data;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Date",                    Data.Date);
	FormParameters.Insert("UserName",         Data.UserName);
	FormParameters.Insert("User",            Data.User);
	FormParameters.Insert("ApplicationPresentation", Data.ApplicationPresentation);
	FormParameters.Insert("Computer",               Data.Computer);
	FormParameters.Insert("Event",                 Data.Event);
	FormParameters.Insert("EventPresentation",    Data.EventPresentation);
	FormParameters.Insert("Comment",             Data.Comment);
	FormParameters.Insert("MetadataPresentation", Data.MetadataPresentation);
	FormParameters.Insert("Data",                  Data.Data);
	FormParameters.Insert("DataPresentation",     Data.DataPresentation);
	FormParameters.Insert("Transaction",              Data.TransactionID);
	FormParameters.Insert("TransactionStatus",        Data.TransactionStatus);
	FormParameters.Insert("Session",                   Data.Session);
	FormParameters.Insert("ServerName",           Data.ServerName);
	FormParameters.Insert("PrimaryIPPort",          Data.Port);
	FormParameters.Insert("SyncPort",   Data.SyncPort);
	FormParameters.Insert("Level",                 Data.Level);
	FormParameters.Insert("EventKey",             Data.EventKey);
	
	If Data.Property("DataArea") Then
		FormParameters.Insert("DataArea", Data.DataArea);
	EndIf;
	If Data.Property("SessionDataSeparation") Then
		FormParameters.Insert("SessionDataSeparation", Data.SessionDataSeparation);
	EndIf;
	
	If ValueIsFilled(Data.DataAsStr) Then
		FormParameters.Insert("DataAsStr", Data.DataAsStr);
	EndIf;
	
	Return FormParameters;
EndFunction

// For internal use only.
// 
// Parameters:
//  Result - StandardPeriod
//            - Undefined
//  AdditionalParameters - Structure
//   
Procedure SetPeriodForViewingCompletion(Result, AdditionalParameters) Export
	
	EventLogFilter = AdditionalParameters.EventLogFilter;
	IntervalSet = False;
	
	If Result <> Undefined Then
		
		// Update the current period.
		DateInterval = Result;
		If DateInterval.StartDate = '00010101000000' Then
			EventLogFilter.Delete("StartDate");
		Else
			EventLogFilter.Insert("StartDate", DateInterval.StartDate);
		EndIf;
		
		If DateInterval.EndDate = '00010101000000' Then
			EventLogFilter.Delete("EndDate");
		Else
			EventLogFilter.Insert("EndDate", DateInterval.EndDate);
		EndIf;
		IntervalSet = True;
		
	EndIf;
	
	If AdditionalParameters.HandlerNotifications <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.HandlerNotifications, IntervalSet);
	EndIf;
	
EndProcedure

#EndRegion
