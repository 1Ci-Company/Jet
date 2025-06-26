///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// See ReportsOptionsOverridable.BeforeAddReportCommands.
Procedure BeforeAddReportCommands(ReportsCommands, Parameters, StandardProcessing) Export
	
	If Not AccessRight("View", Metadata.DataProcessors.EventLog) Then
		Return;
	EndIf;
	
	CommandParameterType = New TypeDescription;
	CommandParameterType = New TypeDescription(CommandParameterType, Catalogs.AllRefsType().Types());
	CommandParameterType = New TypeDescription(CommandParameterType, Documents.AllRefsType().Types());
	CommandParameterType = New TypeDescription(CommandParameterType, ChartsOfAccounts.AllRefsType().Types());
	CommandParameterType = New TypeDescription(CommandParameterType, ChartsOfCharacteristicTypes.AllRefsType().Types());
	CommandParameterType = New TypeDescription(CommandParameterType, BusinessProcesses.AllRefsType().Types());
	CommandParameterType = New TypeDescription(CommandParameterType, Tasks.AllRefsType().Types());
	CommandParameterType = New TypeDescription(CommandParameterType, ChartsOfCalculationTypes.AllRefsType().Types());
	CommandParameterType = New TypeDescription(CommandParameterType, ExchangePlans.AllRefsType().Types());
	
	UsersTypes = New Array;
	UsersTypes.Add(Type("CatalogRef.Users"));
	UsersTypes.Add(Type("CatalogRef.ExternalUsers"));
	
	CommandParameterType = New TypeDescription(CommandParameterType,, UsersTypes);
	
	Command                       = ReportsCommands.Add();
	Command.Presentation         = NStr("en = 'Event log';");
	Command.MultipleChoice    = True;
	Command.FormParameterName     = "Data";
	Command.FormParameters        = New Structure("StartDate", BegOfDay(CurrentSessionDate()) - 30 * 60 * 60 * 24);
	Command.Importance              = "SeeAlso";
	Command.ParameterType          = CommandParameterType;
	Command.Manager              = "DataProcessor.EventLog";
	Command.OnlyInAllActions = True;
	
	Command                       = ReportsCommands.Add();
	Command.Presentation         = NStr("en = 'Event log';");
	Command.MultipleChoice    = True;
	Command.FormParameterName     = "User";
	Command.FormParameters        = New Structure("StartDate", BegOfDay(CurrentSessionDate()) - 30 * 60 * 60 * 24);
	Command.Importance              = "SeeAlso";
	Command.ParameterType          = New TypeDescription(UsersTypes);
	Command.Manager              = "DataProcessor.EventLog";
	Command.OnlyInAllActions = True;
	
EndProcedure

#EndRegion

#Region Private

// Returns the enumeration value corresponding to the string name of the event status.
//
// Parameters:
//  Name - String - the entry transaction status.
//
// Returns:
//  EventLogEntryTransactionStatus - transaction status value.
//
Function EventLogEntryTransactionStatusValueByName(Name) Export
	
	EnumerationValue = Undefined;
	If Name = "Committed" Then
		EnumerationValue = EventLogEntryTransactionStatus.Committed;
	ElsIf Name = "Unfinished" Then
		EnumerationValue = EventLogEntryTransactionStatus.Unfinished;
	ElsIf Name = "NotApplicable" Then
		EnumerationValue = EventLogEntryTransactionStatus.NotApplicable;
	ElsIf Name = "RolledBack" Then
		EnumerationValue = EventLogEntryTransactionStatus.RolledBack;
	EndIf;
	Return EnumerationValue;
	
EndFunction

// Returns the enumeration value corresponding to the string level of the event log.
//
// Parameters:
//  Name - String - event log level.
//
// Returns:
//  EventLogLevel - event log level value.
//
Function EventLogLevelValueByName(Name) Export
	
	EnumerationValue = Undefined;
	If Name = "Information" Then
		EnumerationValue = EventLogLevel.Information;
	ElsIf Name = "Error" Then
		EnumerationValue = EventLogLevel.Error;
	ElsIf Name = "Warning" Then
		EnumerationValue = EventLogLevel.Warning;
	ElsIf Name = "Note" Then
		EnumerationValue = EventLogLevel.Note;
	EndIf;
	Return EnumerationValue;
	
EndFunction

// Sets the picture number in the row of the event log.
//
// Parameters:
//  LogEvent - ValueTableRow - an event log row.
//
Procedure SetPictureNumber(LogEvent) Export
	
	// Setting relative image number.
	If LogEvent.Level = EventLogLevel.Information Then
		LogEvent.PicNumber = 0;
	ElsIf LogEvent.Level = EventLogLevel.Warning Then
		LogEvent.PicNumber = 1;
	ElsIf LogEvent.Level = EventLogLevel.Error Then
		LogEvent.PicNumber = 2;
	Else
		LogEvent.PicNumber = 3;
	EndIf;
	
	// Setting absolute image number.
	If LogEvent.TransactionStatus = EventLogEntryTransactionStatus.Unfinished
	 Or LogEvent.TransactionStatus = EventLogEntryTransactionStatus.RolledBack Then
		LogEvent.PicNumber = LogEvent.PicNumber + 4;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf