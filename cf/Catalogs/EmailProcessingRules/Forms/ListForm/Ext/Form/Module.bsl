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
	
	If Not Parameters.Filter.Property("Owner") Then
		Cancel = True;
		Return;
	EndIf;
		
	Title = Common.ListPresentation(Metadata.Catalogs.EmailProcessingRules)
		+ ": " + Parameters.Filter.Owner;
	If Not Interactions.UserIsResponsibleForMaintainingFolders(Parameters.Filter.Owner) Then
		ReadOnly = True;
		Items.FormApplyRules.Visible = False;
		Items.ItemOrderSetup.Visible = False;
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands

EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ApplyRules(Command)
	
	ClearMessages();
	
	FormParameters = New Structure;
	
	FilterItemsArray = CommonClientServer.FindFilterItemsAndGroups(InteractionsClientServer.DynamicListFilter(List), "Owner");
	If FilterItemsArray.Count() > 0 And FilterItemsArray[0].Use
		And ValueIsFilled(FilterItemsArray[0].RightValue) Then
		FormParameters.Insert("Account", FilterItemsArray[0].RightValue);
	Else
		CommonClient.MessageToUser(NStr("en = 'Select an email account to read the list of rules.';"));
		Return;
	EndIf;
	
	OpenForm("Catalog.EmailProcessingRules.Form.RulesApplication", FormParameters, ThisObject);
	
EndProcedure

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.StartCommandExecution(ThisObject, Command, Items.List);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	AttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Items.List);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion
