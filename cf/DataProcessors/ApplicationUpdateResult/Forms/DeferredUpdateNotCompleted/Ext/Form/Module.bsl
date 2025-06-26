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
	
	SubsystemSettings = InfobaseUpdateInternal.SubsystemSettings();
	ToolTipText      = SubsystemSettings.UpdateResultNotes;
	
	If Not IsBlankString(ToolTipText) Then
		Items.ToolTip.Title = ToolTipText;
	EndIf;
	
	MessageParameters  = SubsystemSettings.UncompletedDeferredHandlersMessageParameters;
	
	If ValueIsFilled(MessageParameters.MessageText) Then
		Items.Message.Title = MessageParameters.MessageText;
	EndIf;
	
	If MessageParameters.MessagePicture <> Undefined Then
		Items.Picture.Picture = MessageParameters.MessagePicture;
	EndIf;
	
	If MessageParameters.ProhibitContinuation Then
		Items.FormContinue.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ExitApp(Command)
	Close(False);
EndProcedure

&AtClient
Procedure ContinueUpdate(Command)
	Close(True);
EndProcedure

#EndRegion
