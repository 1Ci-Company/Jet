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
	ModuleReportsOptions.SetOutputModeInReportPanels(Settings, ReportSettings, False);
	
	ReportSettings.DefineFormSettings = True;
	
	OptionSettingsHorizontal = ReportsOptions.OptionDetails(Settings, ReportSettings, "Main");
	OptionSettingsHorizontal.LongDesc = NStr("en = 'Horizontal arrangement of columns with dimensions, resources, and register attributes.';");
	OptionSettingsHorizontal.SearchSettings.Keywords = NStr("en = 'Document register records';");
	OptionSettingsHorizontal.Enabled = False;
	OptionSettingsHorizontal.ShouldShowInOptionsSubmenu = True;
	
	OptionSettingsVertical = ReportsOptions.OptionDetails(Settings, ReportSettings, "Additional");
	OptionSettingsVertical.LongDesc = NStr("en = 'Vertical arrangement of columns with dimensions, resources, and attributes allows you to arrange data more compactly to view registers with a large number of columns.';");
	OptionSettingsVertical.SearchSettings.Keywords = NStr("en = 'Document register records';");
	OptionSettingsVertical.Enabled = False;
	OptionSettingsVertical.ShouldShowInOptionsSubmenu = True;
	
EndProcedure

// To be called from ReportsOptionsOverridable.BeforeAddReportCommands.
// 
// Parameters:
//  ReportsCommands - ValueTable - Table of commands to add to a submenu:
//       * Id - String - Command ID.
//       * Presentation - String   - Command presentation in a form.
//       * Importance      - String   - a suffix of a submenu group in which the command is to be output.
//       * Order       - Number    - Command position in the group. Can be customized workspace-wise.
//                                    
//       * Picture      - Picture - Command icon.
//       * Shortcut - Shortcut - a shortcut for fast command call.
//       * ParameterType - TypeDescription - types of objects that the command is intended for.
//       * VisibilityInForms    - String - comma-separated names of forms on which the command is to be displayed.
//       * FunctionalOptions - String - Comma-delimited names of functional options that affect the command visibility.
//       * VisibilityConditions    - Array - defines the command visibility depending on the context.
//       * ChangesSelectedObjects - Boolean - defines whether the command is available.
//       * MultipleChoice - Boolean
//                            - Undefined -  Optional. If True, the command supports multiple option choices.
//             In this case, the parameter passes a list of references.
//             By default, True.
//       * WriteMode - String - actions associated with object writing that are executed before the command handler.
//       * FilesOperationsRequired - Boolean - If True, in the web client, users are prompted
//             to install 1C:Enterprise Extension.
//       * Manager - String - a full name of the metadata object responsible for executing the command.
//       * FormName - String - a name of the form to be open or retrieved for the command execution.
//       * VariantKey - String - Name of the report option the command will open.
//       * FormParameterName - String - Name of the form parameter to pass a reference or a reference array to.
//       * FormParameters - Undefined
//                        - Structure - Parameters of the form specified in FormName.
//       * Handler - String - details of the procedure that handles the main action of the command.
//       * AdditionalParameters - Structure - Handler parameters specified in Handler.
//  Parameters                   - Structure - a structure containing command connection parameters.
//  DocumentsWithRecordsReport - Array
//                              - Undefined - an array of documents in which the
//                                command of reports opening will be displayed. Undefined if the report is displayed
//                                for all documents with the Posting property set in Allow
//                                and filled register records collection.
//
// Returns:
//  ValueTableRow, Undefined - an added command or Undefined if there are no rights to view the report.
//
Function AddDocumentRecordsReportCommand(ReportsCommands, Parameters, DocumentsWithRecordsReport = Undefined) Export
	
	If Not AccessRight("View", Metadata.Reports.DocumentRegisterRecords) Then
		Return Undefined;
	EndIf;
	
	CommandParameterTypeDetails = CommandParameterTypeDetails(ReportsCommands, Parameters, DocumentsWithRecordsReport);
	If CommandParameterTypeDetails = Undefined Then
		Return Undefined;
	EndIf;
	
	Command                    = ReportsCommands.Add();
	Command.Presentation      = NStr("en = 'Document register records';");
	Command.MultipleChoice = False;
	Command.FormParameterName  = "";
	Command.Importance           = "SeeAlso";
	Command.ParameterType       = CommandParameterTypeDetails;
	Command.Manager           = "Report.DocumentRegisterRecords";
	Command.Shortcut    = New Shortcut(Key.A, False, True, True);
	
	Return Command;
	
EndFunction

// See ReportsOptionsOverridable.CustomizeReportsOptions.
Procedure OnSetUpReportsOptions(Settings) Export
	
	ReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.DocumentRegisterRecords);
	
	DescriptionOfReport = ReportsOptions.DescriptionOfReport(Settings, Metadata.Reports.DocumentRegisterRecords);
	DescriptionOfReport.Enabled = False;
	
EndProcedure

// See ReportsOptionsOverridable.BeforeAddReportCommands.
Procedure BeforeAddReportCommands(ReportsCommands, Parameters, StandardProcessing) Export
	
	AddDocumentRecordsReportCommand(ReportsCommands, Parameters);
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region Private

Function CommandParameterTypeDetails(Val ReportsCommands, Val Parameters, Val DocumentsWithRecordsReport)
	
	If Not Parameters.Property("Sources") Then
		Return Undefined;
	EndIf;
	
	SourcesStrings = Parameters.Sources.Rows;
	
	If DocumentsWithRecordsReport <> Undefined Then
		DetachReportFromDocuments(ReportsCommands);
		DocumentsWithReport = New Map;
		For Each DocumentWithReport In DocumentsWithRecordsReport Do
			DocumentsWithReport[DocumentWithReport] = True;
		EndDo;	
	Else	
		DocumentsWithReport = Undefined;
	EndIf;
	
	DocumentsTypesWithRegisterRecords = New Array;
	For Each SourceRow1 In SourcesStrings Do
		
		DataRefType = SourceRow1.DataRefType;
		
		If TypeOf(DataRefType) = Type("Type") Then
			DocumentsTypesWithRegisterRecords.Add(DataRefType);
		ElsIf TypeOf(DataRefType) = Type("TypeDescription") Then
			CommonClientServer.SupplementArray(DocumentsTypesWithRegisterRecords, DataRefType.Types());
		EndIf;
		
	EndDo;
	
	DocumentsTypesWithRegisterRecords = CommonClientServer.CollapseArray(DocumentsTypesWithRegisterRecords);
	
	IndexOf = DocumentsTypesWithRegisterRecords.Count() - 1;
	While IndexOf >= 0 Do
		If Not IsConnectedType(DocumentsTypesWithRegisterRecords[IndexOf], DocumentsWithReport) Then
			DocumentsTypesWithRegisterRecords.Delete(IndexOf);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;	
	
	Return ?(DocumentsTypesWithRegisterRecords.Count() > 0, New TypeDescription(DocumentsTypesWithRegisterRecords), Undefined);
	
EndFunction

Procedure DetachReportFromDocuments(ReportsCommands)
	
	TheStructureOfTheSearch = New Structure;
	TheStructureOfTheSearch.Insert("Manager", "Report.DocumentRegisterRecords");
	FoundRows = ReportsCommands.FindRows(TheStructureOfTheSearch);
	
	For Each FoundRow In FoundRows Do
		ReportsCommands.Delete(FoundRow);
	EndDo;
	
EndProcedure

Function IsConnectedType(TypeToCheck, DocumentsWithRecordsReport)
	
	MetadataObject = Metadata.FindByType(TypeToCheck);
	If MetadataObject = Undefined Then
		Return False;
	EndIf;
	
	If DocumentsWithRecordsReport <> Undefined And DocumentsWithRecordsReport[MetadataObject] = Undefined Then
		Return False;
	EndIf;
	
	If Not Common.IsDocument(MetadataObject) Then
		Return False;
	EndIf;
	
	If MetadataObject.Posting <> Metadata.ObjectProperties.Posting.Allow
		Or MetadataObject.RegisterRecords.Count() = 0 Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#EndIf