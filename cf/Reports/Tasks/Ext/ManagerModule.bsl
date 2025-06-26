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

// StandardSubsystems.ReportsOptions

// Parameters:
//   Settings - See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//   ReportSettings - See ReportsOptions.DescriptionOfReport.
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ReportSettings.LongDesc = NStr("en = 'Task list and summary.';");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "CurrentTasks");
	OptionSettings.LongDesc = NStr("en = 'All tasks in progress by the specified due date.';");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "PerformerDisciplineSummary");
	OptionSettings.LongDesc = NStr("en = 'Overdue tasks and tasks completed on schedule summary by assignee.';");
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf