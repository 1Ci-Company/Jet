///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandParameter = Undefined Then
		ShowMessageBox(,NStr("en = 'Tasks are not selected.';"));
		Return;
	EndIf;
		
	ClearMessages();
	For Each Task In CommandParameter Do
		BusinessProcessesAndTasksServerCall.ExecuteTask(Task, True);
		ShowUserNotification(
			NStr("en = 'The task is completed';"),
			GetURL(Task),
			String(Task));
	EndDo;
	Notify("Write_PerformerTask", New Structure("Executed", True), CommandParameter);
	
EndProcedure

#EndRegion