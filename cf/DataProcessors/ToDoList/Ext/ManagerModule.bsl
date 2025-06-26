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

// Returns a group for to-dos not included in commanded interface sections.
//
Function FullName() Export
	
	Settings = New Structure;
	Settings.Insert("OtherToDoItemsTitle");
	SSLSubsystemsIntegration.OnDefineToDoListSettings(Settings);
	ToDoListOverridable.OnDefineSettings(Settings);
	
	If ValueIsFilled(Settings.OtherToDoItemsTitle) Then
		OtherToDoItemsTitle = Settings.OtherToDoItemsTitle;
	Else
		OtherToDoItemsTitle = NStr("en = 'Other to-do items';");
	EndIf;
	
	Return OtherToDoItemsTitle;
	
EndFunction

#EndRegion

#EndIf