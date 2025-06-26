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
	
	If InteractionsClientServer.IsSubject(CommandParameter) Then
		
		FilterStructure1 = New Structure;
		FilterStructure1.Insert("SubjectOf", CommandParameter);
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("InteractionType", "SubjectOf");
		
		FormParameters = New Structure;
		FormParameters.Insert("Filter", FilterStructure1);
		FormParameters.Insert("AdditionalParameters", AdditionalParameters);
		
	ElsIf InteractionsClientServer.IsInteraction(CommandParameter) Then
		
		FilterStructure1 = New Structure;
		FilterStructure1.Insert("SubjectOf", CommandParameter);
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("InteractionType", "Interaction");
		
		FormParameters = New Structure;
		FormParameters.Insert("Filter", FilterStructure1);
		FormParameters.Insert("AdditionalParameters", AdditionalParameters);
		
	Else
		Return;
	EndIf;

	OpenForm(
		"DocumentJournal.Interactions.Form.ParametricListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Source.UniqueKey,
		CommandExecuteParameters.Window);

EndProcedure

#EndRegion