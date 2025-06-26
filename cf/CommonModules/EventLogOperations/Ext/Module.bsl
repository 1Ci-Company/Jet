///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2022, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Handles bunch message writing to the event log.
// The EventsForEventLog variable is cleared after writing.
//
// Parameters:
//  EventsForEventLog - ValueList - where Value is structure with the following properties:
//              * EventName  - String - a name of the event to write.
//              * LevelPresentation  - String - a presentation of the EventLogLevel collection values.
//                                       Possible values: Information, Error, Warning, and Note.
//              * Comment - String - an event comment.
//              * EventDate - Date   - the event date that is added to the comment when writing.
//
Procedure WriteEventsToEventLog(EventsForEventLog) Export

	EventLog.WriteEventsToEventLog(EventsForEventLog);

EndProcedure

#EndRegion
