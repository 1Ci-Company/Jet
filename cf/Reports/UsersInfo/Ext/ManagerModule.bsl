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
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UsersAndExternalUsersInfo");
	OptionSettings.LongDesc = 
		NStr("en = 'Detailed information about all users,
		|including their authorization settings (if specified).';");
	OptionSettings.FunctionalOptions.Add("UseExternalUsers");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UsersInfo");
	OptionSettings.LongDesc = 
		NStr("en = 'Detailed information about users,
		|including their authorization settings (if specified).';");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "ExternalUsersInfo");
	OptionSettings.LongDesc = 
		NStr("en = 'Detailed information about external users,
		|including their authorization settings (if specified).';");
	OptionSettings.FunctionalOptions.Add("UseExternalUsers");
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If Not Parameters.Property("VariantKey") Then
		StandardProcessing = False;
		Parameters.Insert("VariantKey", "UsersAndExternalUsersInfo");
		SelectedForm = "Report.UsersInfo.Form";
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
