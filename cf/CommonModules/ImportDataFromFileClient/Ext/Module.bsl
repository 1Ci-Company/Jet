///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// Creates a new structure of parameters for importing data from a file to a tabular section.
//
// Returns:
//   Structure - The opening parameters used in the data import form.:
//    * FullTabularSectionName - String   - a full path to the document tabular section 
//                                           formatted as DocumentName.TabularSectionName.
//    * Title               - String   - a header of the form for importing data from a file.
//    * DataStructureTemplateName      - String   - a data input template name.
//    * AdditionalParameters - Structure - any additional information that will be passed
//                                           to the data mapping procedure.
//    * TemplateColumns - Array of See ImportDataFromFileClientServer.TemplateColumnDetails
//                    - Undefined - In case the column details are missing from the template for importing data from a file.
//
Function DataImportParameters() Export
	
	ImportParameters = New Structure;
	ImportParameters.Insert("FullTabularSectionName", "");
	ImportParameters.Insert("Title", "");
	ImportParameters.Insert("DataStructureTemplateName", "");
	ImportParameters.Insert("AdditionalParameters", New Structure);
	ImportParameters.Insert("TemplateColumns", Undefined);
	
	Return ImportParameters;
	
EndFunction

// Opens the data import form for filling the tabular section.
//
// Parameters: 
//   ImportParameters   - See ImportDataFromFileClient.DataImportParameters.
//   ImportNotification - NotifyDescription  - the procedure called to add the imported data
//                                               to the tabular section.
//
Procedure ShowImportForm(ImportParameters, ImportNotification) Export
	
	OpenForm("DataProcessor.ImportDataFromFile.Form", ImportParameters, 
		ImportNotification.Module, , , , ImportNotification);
		
EndProcedure


#EndRegion

#Region Internal

// Opens the data import form to fill in a tabular section of link mapping in the "Report options" subsystem.
//
// Parameters: 
//   ImportParameters   - See ImportDataFromFileClient.DataImportParameters.
//   ImportNotification - NotifyDescription  - the procedure called to add the imported data
//                                               to the tabular section.
//
Procedure ShowRefFillingForm(ImportParameters, ImportNotification) Export
	
	OpenForm("DataProcessor.ImportDataFromFile.Form", ImportParameters,
		ImportNotification.Module,,,, ImportNotification);
		
EndProcedure

#EndRegion

#Region Private

// Opens a file import dialog.
//
// Parameters:
//  CompletionNotification - NotifyDescription - the procedure to call when a file is successfully put in a storage.
//  FileName	         - String - a file name in the dialog.
//
Procedure FileImportDialog(CompletionNotification , FileName = "") Export
	
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.Dialog.Filter = NStr("en = 'All supported file formats (*.xls; *.xlsx; *.ods; *.mxl; *.csv)|*.xls;*.xlsx;*.ods;*.mxl;*.csv|Excel Workbook 97 (*.xls)|*.xls|Excel Workbook 2007 (*.xlsx)|*.xlsx|OpenDocument Spreadsheet (*.ods)|*.ods|Comma-separated values file(*.csv)|*.csv|Spreadsheet document (*.mxl)|*.mxl';");
	ImportParameters.FormIdentifier = CompletionNotification.Module.UUID;
	
	
	FileSystemClient.ImportFile_(CompletionNotification, ImportParameters, FileName);
	
EndProcedure

#EndRegion
