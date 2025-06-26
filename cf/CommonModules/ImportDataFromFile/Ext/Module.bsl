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

// Returns description of columns of the tabular section or value table.
//
// Parameters:
//  Table - ValueTable - TabularSectionDetails with columns.
//          - FormDataCollection - Table of the form.
//          - String - To receive a list of the table columns, specify the table's full name (String) from metadata.
//              For example "Documents.ProformaInvoice.TabularSections.Goods".
//  Columns - String - a list of comma-separated extracted columns. For example: "Number, Goods, Quantity".
// 
// Returns:
//   Array of See ImportDataFromFileClientServer.TemplateColumnDetails.
//
Function GenerateColumnDetails(Table, Columns = Undefined) Export
	
	DontExtractAllColumns = False;
	If Columns <> Undefined Then
		ColumnsListForExtraction = StrSplit(Columns, ",", False);
		DontExtractAllColumns = True;
	EndIf;
	
	ColumnsList = New Array;
	If TypeOf(Table) = Type("FormDataCollection") Then
		TableCopy = Table;
		InternalTable = TableCopy.Unload();
		InternalTable.Columns.Delete("SourceLineNumber");
		InternalTable.Columns.Delete("LineNumber");
	Else
		InternalTable= Table;
	EndIf;
	
	Position = 1;
	If TypeOf(InternalTable) = Type("ValueTable") Then
		For Each Column In InternalTable.Columns Do
			If DontExtractAllColumns And ColumnsListForExtraction.Find(Column.Name) = Undefined Then
				Continue;
			EndIf;
			ToolTip = "";
			For Each ColumnType In Column.ValueType.Types() Do
				MetadataObject = Metadata.FindByType(ColumnType);
				
				If MetadataObject <> Undefined Then
					ToolTip = ToolTip + MetadataObject.Comment + Chars.LF;
					
					If Common.IsEnum(MetadataObject) Then
						ToolTipSet = New Array;
						ToolTipSet.Add(NStr("en = 'Available options:';"));
						For Each EnumOption In MetadataObject.EnumValues Do
							ToolTipSet.Add(EnumOption.Presentation());
						EndDo;
						ToolTip = StrConcat(ToolTipSet, Chars.LF);
					EndIf;
					
				EndIf;
			EndDo;
			
			NewColumn = ImportDataFromFileClientServer.TemplateColumnDetails(Column.Name, Column.ValueType, Column.Title, Column.Width, ToolTip);
			NewColumn.Position = Position;
			ColumnsList.Add(NewColumn);
			
			Position = Position + 1;
		
		EndDo;
	ElsIf TypeOf(InternalTable) = Type("String") Then
		Object = Common.MetadataObjectByFullName(InternalTable); // MetadataObjectCatalog, MetadataObjectDocument 
		For Each Column In Object.Attributes Do
			If DontExtractAllColumns And ColumnsListForExtraction.Find(Column.Name) = Undefined Then
				Continue;
			EndIf;
			
			NewColumn = ImportDataFromFileClientServer.TemplateColumnDetails(Column.Name, Column.Type, Column.Presentation());
			NewColumn.ToolTip = Column.Tooltip;
			NewColumn.Width    = 30;
			NewColumn.Position   = Position;
			ColumnsList.Add(NewColumn);
			
			Position = Position + 1;
		EndDo;
	EndIf;
	
	Return ColumnsList;
EndFunction

// Import settings of new and existing items.
// 
// Returns:
//  Structure: 
//    * CreateNewItems - Boolean
//    * UpdateExistingItems - Boolean
//
Function DataLoadingSettings() Export
	
	ImportParameters = New Structure();
	ImportParameters.Insert("CreateNewItems", False);
	ImportParameters.Insert("UpdateExistingItems", False);
	Return ImportParameters;
	
EndFunction

// Adds internal columns to the table of imported data.
// The dynamic list of the table columns is generated based on the imported data template.
// The return value describes only the internal column that is always present.
// 
// Parameters:
//  DataToImport - ValueTable
//  MappingObjectTypeDetails - TypeDescription -  details of a mapping object type.
//  ColumnHeaderOfTheMappingObject - String - Mapping object column header.
// 
// Returns:
//  ValueTable:
//       * MappedObject         - CatalogRef - Reference to the mapped object.
//       * RowMappingResult - String       - an import status, possible values: Created, Updated, and Skipped.
//       * ErrorDescription               - String       - data import error details.
//       * Id                - Number        - Unique row number.
//       * ConflictsList       - ValueList - a list of conflicts that occurred upon data import.
//
Function DescriptionOfTheUploadedDataForReferenceBooks(DataToImport, MappingObjectTypeDetails, ColumnHeaderOfTheMappingObject) Export
		
	DataToImport.Columns.Add("Id", New TypeDescription("Number"), NStr("en = '#';"));
	DataToImport.Columns.Add("MappingObject", MappingObjectTypeDetails, ColumnHeaderOfTheMappingObject);
	DataToImport.Columns.Add("RowMappingResult", New TypeDescription("String"), NStr("en = 'Result';"));
	DataToImport.Columns.Add("ErrorDescription", New TypeDescription("String"), NStr("en = 'Reason';"));
	DataToImport.Columns.Add("ConflictsList", New TypeDescription("ValueList"), "ConflictsList");
	
	Return DataToImport;
	
EndFunction

// To create a table with a list of conflicts that have several relevant data options in the infobase.
// 
// Returns:
//  ValueTable:
//     * Column       - String - Column name where the conflict was found.
//     * Id - Number  - ID of the row where the conflict was found.
//
Function ANewListOfAmbiguities() Export
	
	ConflictsList = New ValueTable;
	ConflictsList.Columns.Add("Id");
	ConflictsList.Columns.Add("Column");
	
	Return ConflictsList;
EndFunction

// Returns a table from the temporary storage to map imported and app data.
// The dynamic list of table columns is generated based on the imported data template.
// The return value describes only the internal column that is always present.
// 
// Parameters:
//  ResultAddress - String - address in temporary storage 
// 
// Returns:
//  ValueTable:
//     * MappedObject - CatalogRef - Reference to the mapped object. It is populated inside the procedure.
//
Function MappingTable(ResultAddress) Export
	
	MappingTable = GetFromTempStorage(ResultAddress);
	Return MappingTable;
	
EndFunction

// Saves the values of additional attributes and properties from a data table row to the owner.
// The function automatically finds the columns containing the required values.
// The function is called from the LoadFromFile procedure upon an applicable data import in the object manager module.
//
// Parameters:
//  ObjectReference - AnyRef - Reference to the property owner where the data is imported to.
//  TableRow - ValueTableRow of See ImportDataFromFile.DescriptionOfTheUploadedDataForReferenceBooks
//
Procedure WritePropertiesOfObject(ObjectReference, TableRow) Export
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.ImportPropertiesValuesfromFile(ObjectReference, TableRow);
	EndIf;
		
EndProcedure

#EndRegion

#Region Private

Procedure AddStatisticalInformation(OperationName, Value = 1, Comment = "") Export
	
	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
		OperationName = "ImportDataFromFile." + OperationName;
		ModuleMonitoringCenter.WriteBusinessStatisticsOperation(OperationName, Value, Comment);
	EndIf;
	
EndProcedure

// Reports the details required for importing data from a file.
//
// Returns:
//  Structure:
//    * Title - String - a presentation in the list of import options and in the window title.
//    * ColumnDataType - Map of KeyAndValue:
//        ** Key - String - a table column name.
//        ** Value - TypeDescription - description of the column data type.
//    * DataStructureTemplateName - String - a template name with data structure (optional
//                                    parameter, default value is ImportDataFromFile).
//    * RequiredTemplateColumns - Array of String - contains the list of required fields.
//    * TitleMappingColumns - String - Mapping column presentation in the data mapping
//                                                    table header (an optional parameter, its default
//                                                    value is formed as follows: "Catalog: <catalog synonym>").
//    * FullObjectName - String - a full object name as in metadata. For example, Catalog.Partners.
//    * ObjectPresentation - String - the object presentation in the data mapping table. For example, "Client".
//    * ImportType - String - data import options (internal).
//
Function ImportFromFileParameters(MappingObjectName) Export
	
	ObjectMetadata = Common.MetadataObjectByFullName(MappingObjectName);
	
	RequiredTemplateColumns = New Array;
	For Each Attribute In ObjectMetadata.Attributes Do
		If Attribute.FillChecking=FillChecking.ShowError Then
			RequiredTemplateColumns.Add(Attribute.Name);
		EndIf;
	EndDo;
		
	DefaultParameters = New Structure;
	DefaultParameters.Insert("Title", ObjectMetadata.Presentation());
	DefaultParameters.Insert("RequiredColumns2", RequiredTemplateColumns);
	DefaultParameters.Insert("ColumnDataType", New Map);
	DefaultParameters.Insert("ImportType", "");
	DefaultParameters.Insert("FullObjectName", MappingObjectName);
	DefaultParameters.Insert("ObjectPresentation", ObjectMetadata.Presentation());
	
	Return DefaultParameters;
	
EndFunction

Function PresentationOfTextYesForBoolean() Export
	Return NStr("en = 'Yes';");
EndFunction

#EndRegion
