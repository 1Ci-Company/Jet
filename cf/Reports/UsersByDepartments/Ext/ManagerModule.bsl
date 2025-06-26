///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// See ReportsOptionsOverridable.BeforeAddReportCommands.
Procedure BeforeAddReportCommands(ReportsCommands, Parameters, StandardProcessing) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.ReportsOptions")
	 Or Not AccessRight("View", Metadata.Reports.UsersByDepartments)
	 Or StandardSubsystemsServer.IsBaseConfigurationVersion()
	 Or Not Users.IsDepartmentUsed() Then
		Return;
	EndIf;
	
	Presentation = Undefined;
	
	If Parameters.FormName = "Catalog.Users.Form.ListForm" Then
		Presentation = NStr("en = 'Users by department';");
	EndIf;
	
	If Presentation = Undefined Then
		Return;
	EndIf;
	
	Command = ReportsCommands.Add();
	Command.Presentation = Presentation;
	Command.Manager = "Report.UsersByDepartments";
	Command.VariantKey = "Main";
	Command.OnlyInAllActions = True;
	Command.Importance = "SeeAlso";
	
EndProcedure

// Parameters:
//   Settings - See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//   ReportSettings - See ReportsOptions.DescriptionOfReport.
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		Return;
	EndIf;
	
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ReportSettings.DefineFormSettings = True;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "Main");
	OptionSettings.Enabled = Users.IsDepartmentUsed();
	OptionSettings.LongDesc =
		NStr("en = 'Displays users'' membership in departments.';");
	
EndProcedure

#EndRegion

#EndRegion

#EndIf