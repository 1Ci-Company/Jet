///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

// StandardSubsystems

// 
//
// 
//   
//   
//
// 
//   
//   
//     
//   
//  
// 
//   
//   
Var ApplicationParameters Export;

// End StandardSubsystems

#EndRegion

#Region EventHandlers

Procedure BeforeStart()
	
#If MobileClient Then
	If MainServerAvailable() = False Then
		Return;
	EndIf;
#EndIf
	
	// StandardSubsystems
#If MobileClient Then
	Execute("StandardSubsystemsClient.BeforeStart()");
#Else
	StandardSubsystemsClient.BeforeStart();
#EndIf
	// End StandardSubsystems
	
EndProcedure

Procedure OnStart()
	
	// StandardSubsystems
#If MobileClient Then
	Execute("StandardSubsystemsClient.OnStart()");
#Else
	StandardSubsystemsClient.OnStart();
#EndIf
	// End StandardSubsystems
	
EndProcedure

Procedure BeforeExit(Cancel, WarningText)
	
	// StandardSubsystems
#If MobileClient Then
	Execute("StandardSubsystemsClient.BeforeExit(Cancel, WarningText)");
#Else
	StandardSubsystemsClient.BeforeExit(Cancel, WarningText);
#EndIf
	// End StandardSubsystems
	
EndProcedure

Procedure CollaborationSystemUsersChoiceFormGetProcessing(ChoicePurpose,
			Form, ConversationID, Parameters, SelectedForm, StandardProcessing)
	
	// StandardSubsystems
#If MobileClient Then
	Execute("StandardSubsystemsClient.CollaborationSystemUsersChoiceFormGetProcessing(ChoicePurpose,
		|Form, ConversationID, Parameters, SelectedForm, StandardProcessing)");
#Else
	StandardSubsystemsClient.CollaborationSystemUsersChoiceFormGetProcessing(ChoicePurpose,
		Form, ConversationID, Parameters, SelectedForm, StandardProcessing);
#EndIf
	// End StandardSubsystems
	
EndProcedure

#EndRegion