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

// See ReportsOptionsOverridable.BeforeAddReportCommands.
Procedure BeforeAddReportCommands(ReportsCommands, Parameters, StandardProcessing) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		Return;
	EndIf;
	
	If Not AccessRight("View", Metadata.Reports.RolesRights)
	 Or StandardSubsystemsServer.IsBaseConfigurationVersion() Then
		Return;
	EndIf;
	
	CommandRoles = ReportsCommands.Add();
	CommandRoles.MultipleChoice = True;
	CommandRoles.Manager = "Report.RolesRights";
	CommandRoles.VariantKey = "RolesRights";
	
	If StrStartsWith(Parameters.FormName, "Catalog.AccessGroupProfiles") Then
		CommandProfiles = ReportsCommands.Add();
		CommandProfiles.MultipleChoice = True;
		CommandProfiles.Manager = "Report.RolesRights";
		CommandProfiles.VariantKey = "RightsRolesOnMetadataObjects";
		
		If Parameters.FormName = "Catalog.AccessGroupProfiles.Form.ItemForm" Then
			CommandRoles.Presentation    = NStr("en = 'Rights of profile roles';tr = 'Profil rol yetkileri'");
			CommandProfiles.Presentation = NStr("en = 'Rights of profile';tr = 'Profil yetkileri'");
		Else
			CommandRoles.Presentation    = NStr("en = 'Rights of profiles roles';tr = 'Profillerin rol yetkileri'");
			CommandProfiles.Presentation = NStr("en = 'Rights of profiles';tr = 'Profillerin yetkileri'");
		EndIf;
	Else
		CommandRoles.Presentation = NStr("en = 'Rights of profiles and roles';tr = 'Rol ve profillerin yetkileri'");
		CommandRoles.OnlyInAllActions = True;
		CommandRoles.Importance = "SeeAlso";
		CommandRoles.VariantKey = "RightsRolesOnMetadataObject";
	EndIf;
	
EndProcedure

// Parameters:
//   Settings - See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//   ReportSettings - See ReportsOptions.DescriptionOfReport.
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	Else
		Return;
	EndIf;
	
	ModuleReportsOptions.SetOutputModeInReportPanels(Settings, ReportSettings, False);
	ReportSettings.DefineFormSettings = True;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "RolesRights");
	OptionSettings.LongDesc = NStr("en = 'Shows role rights that apply to metadata objects.';tr = 'Meta veri nesneleri için rol yetkilerini gösterir.'");
	OptionSettings.DefaultVisibility = False;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "RightsRolesOnMetadataObjects");
	OptionSettings.LongDesc = NStr("en = 'Shows rights of one role to different metadata objects.';tr = 'Bir rolün farklı metaveri nesneleriyle ilgili yetkilerini gösterir.'");
	OptionSettings.Enabled = False;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "RightsRolesOnMetadataObject");
	OptionSettings.LongDesc = NStr("en = 'Shows rights of different roles to the same metadata object.';tr = 'Farklı rollerin aynı metaveri nesnesiyle ilgili yetkilerini gösterir.'");
	OptionSettings.Enabled = False;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "DetailedPermissionsRolesOnMetadataObject");
	OptionSettings.LongDesc = NStr("en = 'Shows detailed rights of one role to one metadata object.';tr = 'Bir rolün bir metaveri nesnesiyle ilgili ayrıntılı yetkilerini gösterir.'");
	OptionSettings.Enabled = False;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
