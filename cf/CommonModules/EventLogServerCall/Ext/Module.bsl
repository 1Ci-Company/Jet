///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

// The procedure adds messages to the event log in bulk.
// After the logging is done, the "EventsForEventLog" constant is cleared.
//
// To add records on the client, use the procedure "EventLogClient.AddMessageForEventLog".
// To instantly write messages on the client, use "EventLogClient.WriteEventsToEventLog".
//
// 
// 
//
// Parameters:
//  EventsForEventLog - See EventLog.WriteEventsToEventLog
//
Procedure WriteEventsToEventLog(EventsForEventLog) Export
	
	EventLog.WriteEventsToEventLog(EventsForEventLog);
	
EndProcedure

#EndRegion
