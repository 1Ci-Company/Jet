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

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("IdleHandlerExitApplication", 5 * 60, True);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	Terminate();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ExitApplication(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure IdleHandlerExitApplication()
	
	Close();
	
EndProcedure

#EndRegion
