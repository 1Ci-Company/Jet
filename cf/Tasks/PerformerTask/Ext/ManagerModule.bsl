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

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchEditObjects

// Returns object attributes that can be edited using the bulk attribute modification data processor.
// 
//
// Returns:
//  Array of String
//
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("Importance");
	Result.Add("TaskDueDate");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AttachAdditionalTables
	|ThisList AS PerformerTask
	|
	|LEFT JOIN InformationRegister.TaskPerformers AS TaskPerformers
	|ON
	|	PerformerTask.PerformerRole = TaskPerformers.PerformerRole
	|	AND PerformerTask.MainAddressingObject = TaskPerformers.MainAddressingObject
	|	AND PerformerTask.AdditionalAddressingObject = TaskPerformers.AdditionalAddressingObject
	|;
	|AllowRead
	|WHERE
	|	ValueAllowed(Author)
	|	OR ValueAllowed(Performer)
	|	OR ValueAllowed(TaskPerformers.Performer)
	|	OR ObjectReadingAllowed(BusinessProcess)
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	ValueAllowed(Performer)
	|	OR ValueAllowed(TaskPerformers.Performer)";
	
	Restriction.TextForExternalUsers1 =
	"AllowRead
	|WHERE
	|	ValueAllowed(Author)
	|	OR ValueAllowed(Performer)
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	ValueAllowed(Performer)";
	
	
EndProcedure

// End StandardSubsystems.AccessManagement

// StandardSubsystems.AttachableCommands

// Defines the list of generation commands.
//
// Parameters:
//  GenerationCommands - See GenerateFromOverridable.BeforeAddGenerationCommands.GenerationCommands
//  Parameters - See GenerateFromOverridable.BeforeAddGenerationCommands.Parameters
//
Procedure AddGenerationCommands(GenerationCommands, Parameters) Export
	
	BusinessProcesses.Job.AddGenerateCommand(GenerationCommands);
	
EndProcedure

// Intended for use by the AddGenerationCommands procedure in other object manager modules.
// Adds this object to the list of generation commands.
//
// Parameters:
//  GenerationCommands - See GenerateFromOverridable.BeforeAddGenerationCommands.GenerationCommands
//
// Returns:
//  ValueTableRow, Undefined - Details of the added command.
//
Function AddGenerateCommand(GenerationCommands) Export
	
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleGeneration = Common.CommonModule("GenerateFrom");
		Command = ModuleGeneration.AddGenerationCommand(GenerationCommands, Metadata.Tasks.PerformerTask);
		If Command <> Undefined Then
			Command.FunctionalOptions = "UseBusinessProcessesAndTasks";
		EndIf;
		Return Command;
	EndIf;
	
	Return Undefined;
	
EndFunction

// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormType = "ObjectForm" And Parameters.Property("Key") Then
		FormParameters = BusinessProcessesAndTasksServerCall.TaskExecutionForm(Parameters.Key);
		TaskFormName = "";
		Result = FormParameters.Property("FormName", TaskFormName);
		If Result Then
			SelectedForm = TaskFormName;
			StandardProcessing = False;
			CommonClientServer.SupplementStructure(Parameters, FormParameters.FormParameters, False);
		EndIf; 
	EndIf;

EndProcedure

#EndRegion

#EndIf

#Region EventHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	Fields.Add("Description");
	Fields.Add("Date");
	StandardProcessing = False;
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	Description = ?(IsBlankString(Data.Description), NStr("en = 'No details';"), Data.Description);
	Date = Format(Data.Date, ?(GetFunctionalOption("UseDateAndTimeInTaskDeadlines"), "DLF=DT", "DLF=D"));
	Presentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1, created on %2';"), Description, Date);
	StandardProcessing = False;
	
EndProcedure

#EndRegion

