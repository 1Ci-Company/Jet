///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormCommandsEventHandlers

&AtClient
Procedure GoToList(Command)
	Close();
	
	Filters = New Structure;
	Filters.Insert("Publication", PredefinedValue("Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used"));
	Filters.Insert("DeletionMark", False);
	Filters.Insert("IsFolder", False);
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", Filters);
	FormParameters.Insert("Representation", "List");
	FormParameters.Insert("AdditionalReportsAndDataProcessorsCheck", True);
	
	OpenForm("Catalog.AdditionalReportsAndDataProcessors.ListForm", FormParameters);
EndProcedure

&AtClient
Procedure CloseForm(Command)
	Close();
EndProcedure

&AtClient
Procedure Checked(Command)
	MarkUserTaskDone();
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure MarkUserTaskDone()
	
	ArrayVersion  = StrSplit(Metadata.Version, ".", False);
	CurrentVersion = ArrayVersion[0] + ArrayVersion[1] + ArrayVersion[2];
	CommonSettingsStorage.Save("ToDoList", "AdditionalReportsAndDataProcessors", CurrentVersion);
	
EndProcedure

#EndRegion