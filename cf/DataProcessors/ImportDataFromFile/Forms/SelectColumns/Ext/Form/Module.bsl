///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ColumnsList = Parameters.ColumnsList;
	ColumnsList.SortByPresentation();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ColumnsListSelection(Item, RowSelected, Field, StandardProcessing)
	ColumnsList.FindByID(RowSelected).Check = Not ColumnsList.FindByID(RowSelected).Check;
EndProcedure

&AtClient
Procedure ColumnsListOnStartEdit(Item, NewRow, Copy)
	String = ColumnsList.FindByID(Items.ColumnsList.CurrentRow);
	If StrStartsWith(String.Value, "ContactInformation_") Then
		For Each ColumnInformation In ColumnsList Do
			If StrStartsWith(ColumnInformation.Value, "AdditionalAttribute_") Then
				ColumnInformation.Check = False;
			EndIf;
		EndDo;
	ElsIf StrStartsWith(String.Value, "AdditionalAttribute_") Then
		For Each ColumnInformation In ColumnsList Do
			If StrStartsWith(ColumnInformation.Value, "ContactInformation_") Then
				ColumnInformation.Check = False;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Case(Command)
	Close(ColumnsList);
EndProcedure

#EndRegion
