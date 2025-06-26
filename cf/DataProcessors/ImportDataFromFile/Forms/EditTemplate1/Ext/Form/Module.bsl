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
	
	SetDataAppearance();
	
	ImportParameters = Parameters.ImportParameters;

	MappingObjectName = Parameters.MappingObjectName;
	If Parameters.ColumnsInformation <> Undefined Then
		ColumnsList.Load(Parameters.ColumnsInformation.Unload());
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ColumnsListOnActivateRow(Item)
	If Item.CurrentData <> Undefined Then 
		ColumnDetails = Item.CurrentData.Note;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	ColumnPosition = 0;
	For Each TableRow In ColumnsList Do
		If TableRow.Visible Then
			ColumnPosition = ColumnPosition + 1;
			TableRow.Position = ColumnPosition;
		Else
			TableRow.Position = -1;
		EndIf;
	EndDo;
	Close(ColumnsList);
EndProcedure

&AtClient
Procedure ResetSettings(Command)
	Notification = New NotifyDescription("ResetSettingsCompletion", ThisObject, MappingObjectName);
	ShowQueryBox(Notification, NStr("en = 'Do you want to revert to the default column settings?';"), QuestionDialogMode.YesNo);
EndProcedure

&AtClient
Procedure CheckAll(Command)
	For Each TableRow In ColumnsList Do 
		TableRow.Visible = True;
	EndDo;
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	For Each TableRow In ColumnsList Do
		If Not TableRow.IsRequiredInfo Then
			TableRow.Visible = False;
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetDataAppearance()

	ConditionalAppearance.Items.Clear();
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("ColumnsListDescription");
	AppearanceField.Use = True;
	FilterElement = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ColumnsList.IsRequiredInfo"); 
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal; 
	FilterElement.RightValue =True;
	FilterElement.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", StyleFonts.ImportantLabelFont);
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("ColumnsListVisible");
	AppearanceField.Use = True;
	FilterElement = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ColumnsList.IsRequiredInfo"); 
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal; 
	FilterElement.RightValue =True;
	FilterElement.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("ReadOnly", True);
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("ColumnsListSynonym");
	AppearanceField.Use = True;
	FilterElement = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ColumnsList.Synonym");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;
	FilterElement.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("Text", NStr("en = 'Standard name';"));
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

&AtClient
Procedure ResetSettingsCompletion(QuestionResult, MappingObjectName) Export
	If QuestionResult = DialogReturnCode.Yes Then
		ResetColumnsSettings(MappingObjectName);
	EndIf;
EndProcedure

&AtServer
Procedure ResetColumnsSettings(MappingObjectName)
	
	Common.CommonSettingsStorageSave("ImportDataFromFile", MappingObjectName, Undefined,, UserName());
	
	ColumnsListTable = ColumnsList.Unload();
	ColumnsListTable.Clear();
	DataProcessors.ImportDataFromFile.DetermineColumnsInformation(ImportParameters, ColumnsListTable);
	ValueToFormAttribute(ColumnsListTable, "ColumnsList");
	
EndProcedure

#EndRegion
