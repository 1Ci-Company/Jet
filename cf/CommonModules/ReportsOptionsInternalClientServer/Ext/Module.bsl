///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

// Parameters:
//  Form - ClientApplicationForm
//  TitleProperties - See ReportsOptionsInternal.StandardReportHeaderProperties
//
Procedure DetermineTheAvailabilityOfContextMenuActions(Form, TitleProperties) Export 
	
	If TypeOf(TitleProperties) <> Type("Structure") Then 
		Return;
	EndIf;
	
	ContextMenuActions = HeaderAreaContextMenuActions();
	
	For Each Action In ContextMenuActions Do 
		Form.Items[Action.Key].Enabled = TitleProperties[Action.Value];
	EndDo;
	
EndProcedure

Function FieldPicture(FieldValueType) Export 
	
	AvailableTypes = ?(FieldValueType <> Undefined, FieldValueType.Types(), New Array);
	
	If AvailableTypes.Count() = 0 Then 
		Return PictureLib.IsEmpty;
	EndIf;
	
	If AvailableTypes.Count() > 1 Then 
		Return PictureLib.TypeFlexibleMain;
	EndIf;
	
	If FieldValueType.ContainsType(Type("Number")) Then 
		Return PictureLib.NumberType;
	EndIf;
	
	If FieldValueType.ContainsType(Type("String")) Then 
		Return PictureLib.StringType;
	EndIf;
	
	If FieldValueType.ContainsType(Type("Date")) Then 
		Return PictureLib.DateType;
	EndIf;
	
	If FieldValueType.ContainsType(Type("Boolean")) Then 
		Return PictureLib.BooleanType;
	EndIf;
	
	If FieldValueType.ContainsType(Type("UUID")) Then 
		Return PictureLib.TypeID;
	EndIf;
	
	Return PictureLib.TypeRef;
	
EndFunction

// Parameters:
//  Fields - DataCompositionGroupFields
//       - DataCompositionSelectedFields
//  Field - DataCompositionField
//  CheckUsage - Boolean
//  ContainedBy - Boolean
//
// Returns:
//  Boolean
//
Function TheFieldIsContainedInTheReportGrouping(Fields, Field, CheckUsage = True, ContainedBy = False) Export 
	
	Return ReportField(Fields, Field, CheckUsage) <> Undefined;
	
EndFunction

// Parameters:
//  Parent - DataCompositionGroup
//           - DataCompositionTableGroup
//  Field - DataCompositionField
//  ContainedBy - Boolean
//
// Returns:
//  Boolean
//
Function ThisFieldIsUsedInTheParentReportDimensions(Parent, Field, ContainedBy = False) Export 
	
	If (TypeOf(Parent) = Type("DataCompositionGroup")
		Or TypeOf(Parent) = Type("DataCompositionTableGroup")) Then 
		
		If TheFieldIsContainedInTheReportGrouping(Parent.GroupFields, Field) Then 
			ContainedBy = True;
		Else
			ThisFieldIsUsedInTheParentReportDimensions(Parent.Parent, Field, ContainedBy);
		EndIf;
		
	EndIf;
	
	Return ContainedBy;
	
EndFunction

// Parameters:
//  Fields - DataCompositionSelectedFields
//       - DataCompositionGroupFields
//  Field - DataCompositionField
//  CheckUsage - Boolean
//  ReportField - DataCompositionSelectedField
//             - DataCompositionGroupField
//             - Undefined
//
// Returns:
//  DataCompositionSelectedField
//  DataCompositionGroupFieldUndefined
//  Undefined
//
Function ReportField(Fields, Field, CheckUsage = True, FieldTitle = "", ReportField = Undefined) Export 
	
	AvailableFields = Undefined;
	
	If TypeOf(Fields) = Type("DataCompositionSelectedFields") Then 
		
		AvailableFields = Fields.SelectionAvailableFields;
		
	ElsIf TypeOf(Fields) = Type("DataCompositionGroupFields") Then 
		
		AvailableFields = Fields.GroupFieldsAvailableFields;
		
	ElsIf TypeOf(Fields) = Type("DataCompositionOrder") Then 
		
		AvailableFields = Fields.OrderAvailableFields;
		
	EndIf;
	
	FieldDetails = ?(AvailableFields = Undefined, Undefined, AvailableFields.FindField(Field));
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CheckUsage", CheckUsage);
	AdditionalParameters.Insert("FieldTitle", FieldTitle);
	AdditionalParameters.Insert("FieldDetails", FieldDetails);
	
	FindAReportField(Fields, Field, ReportField, AdditionalParameters);
	
	Return ReportField;
	
EndFunction

Function ReportOptionMode(VariantKey) Export 
	
	Return TypeOf(VariantKey) = Type("String")
		And Not IsBlankString(VariantKey);
	
EndFunction

#EndRegion

#Region Private

Function HeaderAreaContextMenuActions()
	
	Actions = New Map;
	Actions.Insert("HeadingAreaContextMenuInsertFieldRight", "InsertFieldRight");
	Actions.Insert("HeadingAreaContextMenuInsertGroupBelow", "InsertGroupBelow");
	
	Actions.Insert("HeadingAreaContextMenuMoveFieldLeft", "MoveFieldLeft");
	Actions.Insert("HeadingAreaContextMenuMoveFieldRight", "MoveFieldRight");
	Actions.Insert("HeadingAreaContextMenuMoveFieldUp", "MoveFieldUp");
	Actions.Insert("HeadingAreaContextMenuMoveFieldDown", "MoveFieldDown");
	
	Actions.Insert("HeadingAreaContextMenuSortAsc", "SortAsc");
	Actions.Insert("HeadingAreaContextMenuSortDesc", "SortDesc");
	
	Actions.Insert("HeadingAreaContextMenuHideField", "HideField");
	Actions.Insert("HeadingAreaContextMenuRenameField", "RenameField");
	
	Actions.Insert("HeadingAreaContextMenuFormatNegativeValues", "FormatNegativeValues");
	Actions.Insert("HeadingAreaContextMenuFormatPositiveValues", "FormatPositiveValues");
	Actions.Insert("MenuHeadingAreaContextMenuApplyAppearanceMore", "ApplyAppearanceMore");
	
	Return Actions;
	
EndFunction

#Region DisplayFilters

// Parameters:
//  Settings - DataCompositionSettings
//  TitleProperties - See ReportsOptionsInternal.StandardReportHeaderProperties
//
Function GroupingTheFilter(Settings, TitleProperties, ThisIsAGrouping = False) Export 
	
	If TitleProperties.IDOfTheSettings = Undefined Then 
		Return Settings;
	EndIf;
	
	SettingsUsed = Settings.GetObjectByID(
		TitleProperties.IDOfTheSettings);
	
	If SettingsUsed = Undefined Then 
		SettingsUsed = Settings;
	EndIf;
	
	If ThisIsAGrouping
		Or TitleProperties.IsFormula
		Or TitleProperties.NumberOfPartitions > 1 Then 
		
		Section = SettingsUsed.GetObjectByID(TitleProperties.SectionID);
	Else
		Section = SettingsUsed;
	EndIf;
	
	If TypeOf(Section) = Type("DataCompositionTable") Then 
		
		If StrFind(TitleProperties.GroupingID, "/column/") > 0
			And Section.Rows.Count() > 0 Then 
			
			Return Section.Rows[0];
			
		Else
			
			Group = SettingsUsed.GetObjectByID(TitleProperties.GroupingID);
			Return Group;
			
		EndIf;
		
	EndIf;
	
	Return Section;
	
EndFunction

// Parameters:
//  Settings - DataCompositionSettings
//  TitleProperties - See ReportsOptionsInternal.StandardReportHeaderProperties
//
// Returns:
//  DataCompositionFilter
//
Function ReportSectionFilters(Settings, TitleProperties, ThisIsAGrouping = False) Export 
	
	GroupingTheFilter = GroupingTheFilter(Settings, TitleProperties, ThisIsAGrouping);
	Return GroupingTheFilter.Filter;
	
EndFunction

// Parameters:
//  DisplayFilters - DataCompositionFilter
//  Field - DataCompositionField
//  Filter - Undefined
//         - DataCompositionFilterItem
//  Delete - Boolean
//
// Returns:
//  DataCompositionFilterItem
//  Undefined
//
Function ReportSectionFilter(DisplayFilters, Field, Filter = Undefined, Delete = False) Export 
	
	ItemsToRemove = New Array;
	
	For Each Item In DisplayFilters.Items Do 
		
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then 
			
			ReportSectionFilter(Item, Field, Filter, Delete);
			If Delete And Item.Items.Count() = 0 Then
				ItemsToRemove.Add(Item);
			EndIf;
			
		ElsIf Item.LeftValue = Field Then 
			
			Filter = Item;
			If Not Delete Then
				Break;
			EndIf;
			ItemsToRemove.Add(Item);
			
		EndIf;
		
	EndDo;
	
	For Each Item In ItemsToRemove Do
		DisplayFilters.Items.Delete(Item);
	EndDo;
	
	Return Filter;
	
EndFunction

#EndRegion

#Region SearchForAField

// Parameters:
//  Fields - DataCompositionSelectedFields
//       - DataCompositionGroupFields
//  Field - DataCompositionField
//  FoundField - DataCompositionSelectedField
//                - DataCompositionGroupField
//                - Undefined
//
Procedure FindAReportField(Fields, Field, FoundField, AdditionalParameters)
	
	CheckUsage = AdditionalParameters.CheckUsage;
	FieldTitle = AdditionalParameters.FieldTitle;
	FieldDetails = AdditionalParameters.FieldDetails;
	
	For Each Item In Fields.Items Do 
		
		ElementType = TypeOf(Item);
		
		TheFieldUsageCheckWasPassedSuccessfully = Not CheckUsage
			Or CheckUsage And Item.Use;
		
		HeaderVerificationPassedSuccessfully = Not ValueIsFilled(FieldTitle)
			Or Item.Title = FieldTitle
			Or FieldDetails <> Undefined And FieldDetails.Title = FieldTitle;
		
		If ElementType <> Type("DataCompositionAutoSelectedField")
			And ElementType <> Type("DataCompositionAutoGroupField")
			And ElementType <> Type("DataCompositionAutoOrderItem")
			And Item.Field = Field
			And TheFieldUsageCheckWasPassedSuccessfully
			And HeaderVerificationPassedSuccessfully Then 
			
			FoundField = Item;
			Return;
			
		ElsIf ElementType = Type("DataCompositionSelectedFieldGroup") Then 
			
			FindAReportField(Item, Field, FoundField, AdditionalParameters);
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region DataOfTheDecryptionElement

Function TheTypeOfTheDecryptionElementIsGrouping() Export 
	
	Return "Group";
	
EndFunction

#EndRegion

Function TheFormulaOnTheDataPath(Settings, DataPath) Export 
	
	Formulae = Settings.UserFields.Items;
	
	For Each Formula In Formulae Do 
		
		If StrEndsWith(Formula.DataPath, DataPath) Then 
			Return Formula;
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

Function IndexOfTheFieldImage(Val FieldValueType, IsFolder = False) Export 
	
	If IsFolder Then 
		Return 14;
	EndIf;
	
	If FieldValueType = Undefined Then 
		FieldValueType = New TypeDescription();
	EndIf;
	
	AvailableTypes = FieldValueType.Types();
	
	If AvailableTypes.Count() = 0 Then 
		Return -1;
	EndIf;
	
	If AvailableTypes.Count() > 1 Then 
		Return 15;
	EndIf;
	
	If FieldValueType.ContainsType(Type("Number")) Then 
		Return 13;
	EndIf;
	
	If FieldValueType.ContainsType(Type("String")) Then 
		Return 8;
	EndIf;
	
	If FieldValueType.ContainsType(Type("Date")) Then 
		Return 2;
	EndIf;
	
	If FieldValueType.ContainsType(Type("Boolean")) Then 
		Return 0;
	EndIf;
	
	If FieldValueType.ContainsType(Type("UUID")) Then 
		Return 4;
	EndIf;
	
	Return 16;
	
EndFunction

Function MaxStackSizeSettings() Export 
	
	Return 10;
	
EndFunction

Function NameEventFormSettings() Export 
	
	Return "SettingsForm";
	
EndFunction

Function EventNameQuickSettingsChangesContent() Export 
	
	Return "ChangeQuickSettingsComposition";
	
EndFunction

#EndRegion