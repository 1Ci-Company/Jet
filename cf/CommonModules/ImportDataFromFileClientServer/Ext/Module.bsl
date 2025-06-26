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

// Creates a structure to describe columns for a template of importing data from file.
//
// Parameters:
//  Name        -String - Column name.
//  Type       - TypeDescription - column type.
//  Title - String - Column header displayed in the template for import.
//  Width    - Number - column width.
//  ToolTip - String - a tooltip displayed in the column header.
// 
// Returns:
//  Structure - Structure containing column details:
//    * Name                      - String - Column name.
//    * Title                - String - Column header displayed in the template for import.
//    * Type                      - TypeDescription - column type.
//    * Width                   - Number  - column width.
//    * Position                  - Number  - Column position in the table.
//    * ToolTip                - String - a tooltip displayed in the column header.
//    * IsRequiredInfo - Boolean - "True" if the column must contain values.
//    * Group                   - String - Column group name.
//    * Parent                 - String - used to connect a dynamic column with an attribute of the object tabular section.
//
Function TemplateColumnDetails(Name, Type, Title = Undefined, Width = 0, ToolTip = "") Export
	
	TemplateColumn = New Structure;
	
	TemplateColumn.Insert("Name",       Name);
	TemplateColumn.Insert("Title", ?(ValueIsFilled(Title), String(Title), Name));
	TemplateColumn.Insert("Type",       Type);
	TemplateColumn.Insert("Position",   0);
	TemplateColumn.Insert("Width",    ?(Width = 0, 30, Width));
	TemplateColumn.Insert("ToolTip", ToolTip);
	TemplateColumn.Insert("IsRequiredInfo", False);
	TemplateColumn.Insert("Group",    "");
	TemplateColumn.Insert("Parent",  Name);
	
	Return TemplateColumn;
	
EndFunction

// Returns a template column by its name.
//
// Parameters:
//  Name				 - String - Column name.
//  ColumnsList	 - Array of See ImportDataFromFileClientServer.TemplateColumnDetails
// 
// Returns:
//   - See TemplateColumnDetails
//   - — Undefined — if the column does not exist.
//
Function TemplateColumn(Name, ColumnsList) Export
	For Each Column In ColumnsList Do
		If Column.Name = Name Then
			Return Column;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

// Deletes a template column from the array.
//
// Parameters:
//  Name           - String - Column name.
//  ColumnsList - Array of See ImportDataFromFileClientServer.TemplateColumnDetails
//
Procedure DeleteTemplateColumn(Name, ColumnsList) Export
	
	For IndexOf = 0 To ColumnsList.Count() -1  Do
		If ColumnsList[IndexOf].Name = Name Then
			ColumnsList.Delete(IndexOf);
			Return;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Function ColumnsHaveGroup(Val ColumnsInformation) Export
	ColumnsGroups = New Map;
	For Each TableColumn2 In ColumnsInformation Do
		ColumnsGroups.Insert(TableColumn2.Group);
	EndDo;
	Return ?(ColumnsGroups.Count() > 1, True, False);
EndFunction

Function MappingTablePrefix() Export
	Return "DataMappingTable";
EndFunction

Function TablePartPrefix() Export
	Return "TS";
EndFunction

Function StatusAmbiguity() Export
	Return UnmappedRowsPrefix() + "Conflict1";
EndFunction

Function StatusUnmapped() Export
	Return UnmappedRowsPrefix() + "NotMapped";
EndFunction

Function StatusMapped() Export
	Return "RowMapped";
EndFunction

Function UnmappedRowsPrefix() Export
	Return "Fix";
EndFunction

#EndRegion
