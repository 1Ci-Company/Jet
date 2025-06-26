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
	ReportSettings.LongDesc = NStr("en = 'Duties and duty completion summary.';");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "JobsList");
	OptionSettings.LongDesc = NStr("en = 'All duties for the specified period.';");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "JobsStatistics");
	OptionSettings.LongDesc = NStr("en = 'Pivot chart of all duties that are completed, canceled, or in progress.';");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "CheckExecutionCyclesStatistics");
	OptionSettings.LongDesc = NStr("en = 'Top 10 authors by average time of duty counterchecks.';");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "DurationStatistics");
	OptionSettings.LongDesc = NStr("en = 'Top 10 authors by average time of duty completion.';");
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf