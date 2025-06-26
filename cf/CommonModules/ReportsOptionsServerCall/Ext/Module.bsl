///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

// Opens an additional report form with the specified report option.
//
// Parameters:
//  Ref - CatalogRef.AdditionalReportsAndDataProcessors - an additional report reference.
//  OptionKey - String - Name of the additional report option.
//
Procedure OnAttachReport(OpeningParameters) Export
	
	ReportsOptions.OnAttachReport(OpeningParameters);
	
EndProcedure

// Gets an account extra dimension type by its number.
//
// Parameters:
//  Account - ChartOfAccountsRef - Account reference.
//  ExtDimensionNumber - Number - Extra dimension number.
//
// Returns:
//   TypeDescription - Extra dimension type.
//   Undefined if failed to obtain the type (the extra dimension is non-existent or the user has insufficient rights).
//
Function ExtDimensionType(Account, ExtDimensionNumber) Export
	
	If Account = Undefined Then 
		Return Undefined;
	EndIf;
	
	MetadataObject = Account.Metadata();
	
	If Not Metadata.ChartsOfAccounts.Contains(MetadataObject) Then
		Return Undefined;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED
	|	ChartOfAccountsExtDimensionTypes.ExtDimensionType.ValueType AS Type
	|FROM
	|	&FullTableName AS ChartOfAccountsExtDimensionTypes
	|WHERE
	|	ChartOfAccountsExtDimensionTypes.Ref = &Ref
	|	AND ChartOfAccountsExtDimensionTypes.LineNumber = &LineNumber");
	
	Query.Text = StrReplace(Query.Text, "&FullTableName", MetadataObject.FullName() + ".ExtDimensionTypes");
	
	Query.SetParameter("Ref", Account);
	Query.SetParameter("LineNumber", ExtDimensionNumber);
	
	Selection = Query.Execute().Select();
	
	If Not Selection.Next() Then
		Return Undefined;
	EndIf;
	
	Return Selection.Type;
	
EndFunction

// Parameters:
//   FilesDetails - Array of Structure:
//     * Location - String
//     * Name - String
//
// Returns:
//   Array of Structure
//
Function UpdateReportOptionsFromFiles(FilesDetails) Export
	
	Return ReportsOptions.UpdateReportOptionsFromFiles(FilesDetails);
	
EndFunction

// Parameters:
//   FileDetails - Structure:
//     * Location - String
//     * Name - String 
//   ReportOptionBase - CatalogRef.ReportsOptions 
//
// Returns:
//   See "ReportOptionDetails"
//
Function UpdateReportOptionFromFile(FileDetails, ReportOptionBase) Export
	
	Return ReportsOptions.UpdateReportOptionFromFile(FileDetails, ReportOptionBase);
	
EndFunction

// Parameters:
//   SelectedUsers - See ReportsOptions.ShareUserSettings.SelectedUsers
//   SettingsDescription - See ReportsOptions.ShareUserSettings.SettingsDetailsTemplate
//
Procedure ShareUserSettings(SelectedUsers, SettingsDescription) Export 
	
	ReportsOptions.ShareUserSettings(SelectedUsers, SettingsDescription);
	
EndProcedure

// Parameters:
//  ReportVariant - See ReportsOptions.IsPredefinedReportOption.ReportVariant
//
// Returns:
//  Boolean
//
Function IsPredefinedReportOption(ReportVariant) Export 
	
	Return ReportsOptions.IsPredefinedReportOption(ReportVariant);
	
EndFunction

#EndRegion
