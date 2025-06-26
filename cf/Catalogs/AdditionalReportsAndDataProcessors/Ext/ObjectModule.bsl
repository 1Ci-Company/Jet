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

#If Not MobileStandaloneServer Then

#Region Variables

Var IsGlobalDataProcessor;

#EndRegion

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	If IsFolder Then
		Return;
	EndIf;
	
	ItemCheck = True;
	If AdditionalProperties.Property("ListCheck") Then
		ItemCheck = False;
	EndIf;
	
	If Not AdditionalReportsAndDataProcessors.CheckGlobalDataProcessor(Kind) Then
		If Not UseForObjectForm And Not UseForListForm 
			And Publication <> Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled Then
			Common.MessageToUser(
				NStr("en = 'Disable publication or select at least one of the forms to use.';"),,, 
				"Object.UseForObjectForm", Cancel);
		EndIf;
	EndIf;
	
	// If the report is published, the name used to register the additional report 
	//     must be checked for uniqueness.
	If Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used Then
		
		// Check name.
		QueryText =
		"SELECT TOP 1
		|	1
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReports
		|WHERE
		|	AdditionalReports.ObjectName = &ObjectName
		|	AND &AdditReportCondition
		|	AND AdditionalReports.Publication = VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used)
		|	AND AdditionalReports.DeletionMark = FALSE
		|	AND AdditionalReports.Ref <> &Ref";
		
		AddlReportsKinds = New Array;
		AddlReportsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
		AddlReportsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.Report);
		
		If AddlReportsKinds.Find(Kind) <> Undefined Then
			QueryText = StrReplace(QueryText, "&AdditReportCondition", "AdditionalReports.Kind IN (&AddlReportsKinds)");
		Else
			QueryText = StrReplace(QueryText, "&AdditReportCondition", "NOT AdditionalReports.Kind IN (&AddlReportsKinds)");
		EndIf;
		
		Query = New Query;
		Query.SetParameter("ObjectName",     ObjectName);
		Query.SetParameter("AddlReportsKinds", AddlReportsKinds);
		Query.SetParameter("Ref",         Ref);
		Query.Text = QueryText;
		
		SetPrivilegedMode(True);
		Conflicting = Query.Execute().Unload();
		SetPrivilegedMode(False);
		
		If Conflicting.Count() > 0 Then
			Cancel = True;
			If ItemCheck Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The %1 report or data processor name is not unique.
					|
					|To continue, change the Publication type from ""%2"" to ""%3"" or ""%4"".';"),
					ObjectName,
					String(Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used),
					String(Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode),
					String(Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled));
			Else
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The name %1 of the %2 report or data processor is not unique. The same name is assigned to another report or data processor.';"),
					ObjectName,
					String(Ref));
			EndIf;
			Common.MessageToUser(ErrorText, , "Object.Publication");
		EndIf;
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	If IsFolder Then
		Return;
	EndIf;
	
	SSLSubsystemsIntegration.BeforeWriteAdditionalDataProcessor(ThisObject, Cancel);
	
	If IsNew() And Not AdditionalReportsAndDataProcessors.InsertRight1(ThisObject) Then
		Raise(NStr("en = 'Insufficient rights to add additional reports or data processors.';"),
			ErrorCategory.AccessViolation);
	EndIf;
	
	// Preliminary checks.
	If Not IsNew() And Kind <> Common.ObjectAttributeValue(Ref, "Kind") Then
		Common.MessageToUser(
			NStr("en = 'Cannot change the type of additional report or data processor.';"),,,,
			Cancel);
		Return;
	EndIf;
	
	// Attribute connection with deletion mark.
	If DeletionMark Then
		Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled;
	EndIf;
	
	// Cache of standard checks.
	AdditionalProperties.Insert("PublicationAvailable", Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used);
	
	If IsGlobalDataProcessor() Then
		If ScheduleSetupRight() Then
			BeforeWriteGlobalDataProcessors(Cancel);
		EndIf;
		Purpose.Clear();
	Else
		BeforeWriteAssignableDataProcessor(Cancel);
		Sections.Clear();
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	If IsFolder Then
		Return;
	EndIf;
	
	QuickAccess = CommonClientServer.StructureProperty(AdditionalProperties, "QuickAccess");
	If TypeOf(QuickAccess) = Type("ValueTable") Then
		DimensionValues = New Structure("AdditionalReportOrDataProcessor", Ref);
		ResourcesValues = New Structure("Available", True);
		InformationRegisters.DataProcessorAccessUserSettings.WriteSettingsPackage(QuickAccess, DimensionValues, ResourcesValues, True);
	EndIf;
	
	If IsGlobalDataProcessor() Then
		If ScheduleSetupRight() Then
			OnWriteGlobalDataProcessor(Cancel);
		EndIf;
	Else
		OnWriteAssignableDataProcessors(Cancel);
	EndIf;
	
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport
		Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report Then
		OnWriteReport(Cancel);
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	If IsFolder Then
		Return;
	EndIf;
	
	SSLSubsystemsIntegration.BeforeDeleteAdditionalDataProcessor(ThisObject, Cancel);
	
	If AdditionalReportsAndDataProcessors.CheckGlobalDataProcessor(Kind) Then
		
		SetPrivilegedMode(True);
		// Deleting all jobs.
		For Each Command In Commands Do
			If ValueIsFilled(Command.GUIDScheduledJob) Then
				ScheduledJobsServer.DeleteJob(Command.GUIDScheduledJob);
			EndIf;
		EndDo;
		SetPrivilegedMode(False);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function IsGlobalDataProcessor()
	
	If IsGlobalDataProcessor = Undefined Then
		IsGlobalDataProcessor = AdditionalReportsAndDataProcessors.CheckGlobalDataProcessor(Kind);
	EndIf;
	
	Return IsGlobalDataProcessor;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Global data processors.

Procedure BeforeWriteGlobalDataProcessors(Cancel)
	If Cancel Or Not AdditionalProperties.Property("RelevantCommands") Then
		Return;
	EndIf;
	
	CommandsTable = AdditionalProperties.RelevantCommands; // CatalogTabularSection.AdditionalReportsAndDataProcessors.Commands
	JobsToUpdate = New Map;
	PublicationEnabled = (Publication <> Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled);
	
	// Scheduled jobs must be changed in the privileged mode.
	SetPrivilegedMode(True);
	
	// Clearing jobs whose commands are deleted from the table.
	If Not IsNew() Then
		For Each ObsoleteCommand In Common.ObjectAttributeValue(Ref, "Commands").Unload() Do
			If ValueIsFilled(ObsoleteCommand.GUIDScheduledJob)
				And CommandsTable.Find(ObsoleteCommand.GUIDScheduledJob, "GUIDScheduledJob") = Undefined Then
				ScheduledJobsServer.DeleteJob(ObsoleteCommand.GUIDScheduledJob);
			EndIf;
		EndDo;
	EndIf;
	
	// Updating the set of scheduled jobs before writing their IDs to the tabular section.
	For Each RelevantCommand In CommandsTable Do
		Command = Commands.Find(RelevantCommand.Id, "Id");
		
		If PublicationEnabled And RelevantCommand.ScheduledJobSchedule.Count() > 0 Then
			Schedule    = RelevantCommand.ScheduledJobSchedule[0].Value;
			Use = RelevantCommand.ScheduledJobUsage
				And AdditionalReportsAndDataProcessorsClientServer.ScheduleSpecified(Schedule);
		Else
			Schedule = Undefined;
			Use = False;
		EndIf;
		
		Job = ScheduledJobsServer.Job(RelevantCommand.GUIDScheduledJob);
		If Job = Undefined Then // Not found.
			If Use Then
				// Create and register a scheduled job.
				JobParameters = New Structure;
				JobParameters.Insert("Metadata", Metadata.ScheduledJobs.StartingAdditionalDataProcessors);
				JobParameters.Insert("Use", False);
				Job = ScheduledJobsServer.AddJob(JobParameters);
				JobsToUpdate.Insert(RelevantCommand, Job);
				Command.GUIDScheduledJob = ScheduledJobsServer.UUID(Job);
			Else
				// No action required.
			EndIf;
		Else // Found.
			If Use Then
				// Register.
				JobsToUpdate.Insert(RelevantCommand, Job);
			Else
				// Delete.
				ScheduledJobsServer.DeleteJob(RelevantCommand.GUIDScheduledJob);
				Command.GUIDScheduledJob = CommonClientServer.BlankUUID();
			EndIf;
		EndIf;
	EndDo;
	
	AdditionalProperties.Insert("JobsToUpdate", JobsToUpdate);
	
EndProcedure

Procedure OnWriteGlobalDataProcessor(Cancel)
	If Cancel Or Not AdditionalProperties.Property("RelevantCommands") Then
		Return;
	EndIf;
	
	PublicationEnabled = (Publication <> Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled);
	
	// Scheduled jobs must be changed in the privileged mode.
	SetPrivilegedMode(True);
	
	For Each KeyAndValue In AdditionalProperties.JobsToUpdate Do
		Command = KeyAndValue.Key;// CatalogTabularSectionRow.AdditionalReportsAndDataProcessors.Commands
		Job = KeyAndValue.Value;
		
		Changes = New Structure;
		Changes.Insert("Use", False);
		Changes.Insert("Schedule", Undefined);
		Changes.Insert("Description", Left(JobPresentation(Command), 120));
		
		If PublicationEnabled And Command.ScheduledJobSchedule.Count() > 0 Then
			Changes.Schedule    = Command.ScheduledJobSchedule[0].Value;
			Changes.Use = Command.ScheduledJobUsage
				And AdditionalReportsAndDataProcessorsClientServer.ScheduleSpecified(Changes.Schedule);
		EndIf;
		
		ProcedureParameters = New Array;
		ProcedureParameters.Add(Ref);
		ProcedureParameters.Add(Command.Id);
		
		Changes.Insert("Parameters", ProcedureParameters);
		
		SSLSubsystemsIntegration.BeforeUpdateJob(ThisObject, Command, Job, Changes);
		If Changes <> Undefined Then
			ScheduledJobsServer.ChangeJob(Job, Changes);
		EndIf;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Operations with scheduled jobs.

Function ScheduleSetupRight()
	// Checks whether a user has rights to schedule the execution of additional reports and data processors.
	Return AccessRight("Update", Metadata.Catalogs.AdditionalReportsAndDataProcessors);
EndFunction

Function JobPresentation(Command)
	// '[ObjectKind]: [ObjectDescription] / Command: [CommandPresentation]'
	Return (
		TrimAll(Kind)
		+ ": "
		+ TrimAll(Description)
		+ " / "
		+ NStr("en = 'Command';")
		+ ": "
		+ TrimAll(Command.Presentation));
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Assignable data processors.

Procedure BeforeWriteAssignableDataProcessor(Cancel)
	AssignmentTable = Purpose.Unload();
	AssignmentTable.GroupBy("RelatedObject");
	Purpose.Load(AssignmentTable);
	
	MetadataObjectsRefs = AssignmentTable.UnloadColumn("RelatedObject");
	
	If Not IsNew() Then
		For Each TableRow In Common.ObjectAttributeValue(Ref, "Purpose").Unload() Do
			If MetadataObjectsRefs.Find(TableRow.RelatedObject) = Undefined Then
				MetadataObjectsRefs.Add(TableRow.RelatedObject);
			EndIf;
		EndDo;
	EndIf;
	
	AdditionalProperties.Insert("MetadataObjectsRefs", MetadataObjectsRefs);
EndProcedure

Procedure OnWriteAssignableDataProcessors(Cancel)
	If Cancel Or Not AdditionalProperties.Property("MetadataObjectsRefs") Then
		Return;
	EndIf;
	
	InformationRegisters.AdditionalDataProcessorsPurposes.UpdateDataByMetadataObjectsRefs(AdditionalProperties.MetadataObjectsRefs);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Global reports.

Procedure OnWriteReport(Cancel)
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		
		Try
			If IsNew() Then
				ExternalObject = ExternalReports.Create(ObjectName);
			Else
				ExternalObject = AdditionalReportsAndDataProcessors.ExternalDataProcessorObject(Ref);
			EndIf;
		Except
			ErrorText = NStr("en = 'Attachment error:';") + Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo());
			AdditionalReportsAndDataProcessors.WriteError(Ref, ErrorText);
			AdditionalProperties.Insert("AttachmentError", ErrorText);
			ExternalObject = Undefined;
		EndTry;
		
		AdditionalProperties.Insert("Global", IsGlobalDataProcessor());
		
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnWriteAdditionalReport(ThisObject, Cancel, ExternalObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf