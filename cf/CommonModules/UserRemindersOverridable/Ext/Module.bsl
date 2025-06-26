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

// Overrides subsystem settings.
//
// Parameters:
//  Settings - Structure:
//   * Schedules1 - Map of KeyAndValue:
//      ** Key     - String - Schedule presentation;
//      ** Value - JobSchedule - schedule option.
//   * StandardIntervals - Array - contains string presentations of time intervals.
//
Procedure OnDefineSettings(Settings) Export
	
EndProcedure

// Overrides an array of object attributes, relative to which the reminder time can be set.
// For example, you can hide attributes with internal dates or dates, for 
// which it makes no sense to set reminders: document or job date, and so on.
// 
// Parameters:
//  Source - AnyRef - Reference to the object, for which an array of attributes with dates is generated;
//  AttributesWithDates - Array - attribute names (from metadata) containing dates.
//
Procedure OnFillSourceAttributesListWithReminderDates(Source, AttributesWithDates) Export
	
EndProcedure

#EndRegion
