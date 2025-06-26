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
	
	SetConditionalAppearance();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillFieldSelectionList();
	ListOfConditions = CurrentObject.VisibilityCondition.Get();
	
	If TypeOf(ListOfConditions) <> Type("Array") Then
		Return;
	EndIf;
	
	ComparisonViewIDs = ComparisonViewIDs();
	RepresentationsViewsComparisons = RepresentationsViewsComparisons();
	
	For Each Condition In ListOfConditions Do
		FieldDetails = FieldDetails(Condition.Attribute);
		If FieldDetails = Undefined Then
			Continue;
		EndIf;
		
		ConditionDetails = VisibilityConditions.Add();
		FillPropertyValues(ConditionDetails, FieldDetails);
		ConditionDetails.ComparisonType = ComparisonViewIDs[Condition.ComparisonType];
		ConditionDetails.ViewComparisonView = RepresentationsViewsComparisons[ConditionDetails.ComparisonType];
		ConditionDetails.Value =  Condition.Value;
	EndDo;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	RefreshReusableValues();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	ListOfConditions = New Array;
	For Each Condition In VisibilityConditions Do
		ConditionDetails = New Structure();
		ConditionDetails.Insert("Attribute", Condition.Field);
		ConditionDetails.Insert("ComparisonType", DataCompositionComparisonType[Condition.ComparisonType]);
		ConditionDetails.Insert("Value", Condition.Value);
		
		ListOfConditions.Add(ConditionDetails);
	EndDo;
	
	CurrentObject.VisibilityCondition = New ValueStorage(ListOfConditions, New Deflation(9));
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)

	For Each Condition In VisibilityConditions Do

		RowIndex = VisibilityConditions.IndexOf(Condition);
		If Not ValueIsFilled(Condition.ComparisonType) Then
			
			MessageText = NStr("en = 'Specify a comparison type';");
			Field = StringFunctionsClientServer.SubstituteParametersToString("VisibilityConditions[%1].ViewComparisonView", Format(RowIndex, "NG=0;"));
			
			CommonClient.MessageToUser(MessageText, , Field, , Cancel);
		EndIf;
		
		If Not ValueIsFilled(Condition.Field) Then
			MessageText = NStr("en = 'Select a field';");
			Field = StringFunctionsClientServer.SubstituteParametersToString("VisibilityConditions[%1].FieldPresentation", Format(RowIndex, "NG=0;"));
			
			CommonClient.MessageToUser(MessageText, , Field, , Cancel);
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersVisibilityConditions

&AtClient
Procedure VisibilityConditionsOnActivateRow(Item)
	
	SetRestrictionType();
	
EndProcedure

&AtClient
Procedure VisibilityConditionsFieldChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	CurrentData = Items.VisibilityConditions.CurrentData;
	CurrentData.Field = ValueSelected;
	Value = Items.VisibilityConditionsField.ChoiceList.FindByValue(ValueSelected);
	ValueSelected = Value.Presentation;
	
	If CurrentData.ComparisonType = "Filled" Or CurrentData.ComparisonType = "NotFilled" Then
		CurrentData.Value = Undefined;
	EndIf;
	
	SetRestrictionType();
	
EndProcedure

&AtClient
Procedure VisibilityConditionsFieldOnChange(Item)
	
	CurrentData = Items.VisibilityConditions.CurrentData;
	SelectedField = Undefined;
	
	For Each FieldDetails In Items.VisibilityConditionsField.ChoiceList Do
		If FieldDetails.Presentation = CurrentData.FieldPresentation Then
			Return;
		EndIf;
		If SelectedField = Undefined And StrStartsWith(Lower(FieldDetails.Presentation), Lower(CurrentData.FieldPresentation)) Then
			SelectedField = FieldDetails;
		EndIf;
	EndDo;
	
	If SelectedField = Undefined Then
		CurrentData.Field = "";
		CurrentData.FieldPresentation = "";
	Else
		CurrentData.Field = SelectedField.Value;
		CurrentData.FieldPresentation = SelectedField.Presentation;
	EndIf;
	
EndProcedure

&AtClient
Procedure VisibilityConditionsOnStartEdit(Item, NewRow, Copy)
	
	CurrentData = Items.VisibilityConditions.CurrentData;
	
	If NewRow And CurrentData <> Undefined And Not ValueIsFilled(CurrentData.ComparisonType) Then
		DefaultComparisonType = DataCompositionComparisonType.Equal;
		CurrentData.ComparisonType = ComparisonViewIDs()[DefaultComparisonType];
		CurrentData.ViewComparisonView = RepresentationsViewsComparisons()[CurrentData.ComparisonType];
	EndIf;
	
EndProcedure

&AtClient
Procedure ConditionsVisibilityViewComparisonStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ChoiceData = New ValueList();
	ChoiceData.Add("Equal");
	ChoiceData.Add("NotEqual");
	ChoiceData.Add("Filled");
	ChoiceData.Add("NotFilled");
	ChoiceData.Add("InList");
	ChoiceData.Add("NotInList");
	
	RepresentationsViewsComparisons = RepresentationsViewsComparisons();
	For Each DescriptionComparisonType In ChoiceData Do
		DescriptionComparisonType.Presentation = RepresentationsViewsComparisons[DescriptionComparisonType.Value];
	EndDo;
	
EndProcedure

&AtClient
Procedure ConditionsVisibilityViewComparisonChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	CurrentData = Items.VisibilityConditions.CurrentData;
	CurrentData.ComparisonType = ValueSelected;
	ValueSelected = RepresentationsViewsComparisons()[ValueSelected];
	SetRestrictionType();
	
EndProcedure

&AtClient
Procedure ConditionsVisibilityViewComparisonOnChange(Item)
	
	SetRestrictionType();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillFieldSelectionList()
	
	For Each TableRow In Object.DataSources Do
		DataSource = TableRow.DataSource;
		If Not ValueIsFilled(DataSource) Then
			Continue;
		EndIf;
		
		MetadataObject = Common.MetadataObjectByID(DataSource, False);
		If MetadataObject = Undefined Then
			Return;
		EndIf;
		
		CollectionsProps = New Array;
		CollectionsProps.Add(MetadataObject.StandardAttributes);
		CollectionsProps.Add(MetadataObject.Attributes);
		
		For Each AttributesCollection In CollectionsProps Do
			For Each Attribute In AttributesCollection Do
				AttributeDetails = ObjectAttributes.Add();
				AttributeDetails.Field = Attribute.Name;
				AttributeDetails.Type = Attribute.Type;
				AttributeDetails.FieldPresentation = Attribute.Presentation();
				
				If Items.VisibilityConditionsField.ChoiceList.FindByValue(AttributeDetails.Field) = Undefined Then
					Items.VisibilityConditionsField.ChoiceList.Add(AttributeDetails.Field, AttributeDetails.FieldPresentation);
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	Items.VisibilityConditionsField.ChoiceList.SortByPresentation();
	
EndProcedure

&AtClientAtServerNoContext
Function RepresentationsViewsComparisons()
	
	Result = New Map();
	Result.Insert("Equal", NStr("en = 'Equal to';"));
	Result.Insert("NotEqual", NStr("en = 'Not equal to';"));
	Result.Insert("Filled", NStr("en = 'Filled';"));
	Result.Insert("NotFilled", NStr("en = 'Not filled';"));
	Result.Insert("InList", NStr("en = 'In list';"));
	Result.Insert("NotInList", NStr("en = 'Not in list';"));
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function ComparisonViewIDs()
	
	Result = New Map();
	Result.Insert(DataCompositionComparisonType.Equal, "Equal");
	Result.Insert(DataCompositionComparisonType.NotEqual, "NotEqual");
	Result.Insert(DataCompositionComparisonType.Filled, "Filled");
	Result.Insert(DataCompositionComparisonType.NotFilled, "NotFilled");
	Result.Insert(DataCompositionComparisonType.InList, "InList");
	Result.Insert(DataCompositionComparisonType.NotInList, "NotInList");
	
	Return Result;
	
EndFunction

&AtClient
Procedure SetRestrictionType()
	
	CurrentData = Items.VisibilityConditions.CurrentData;
	If CurrentData = Undefined Or Not ValueIsFilled(CurrentData.Field) Then
		Return;
	EndIf;
	
	TypeRestriction = FieldValueType(CurrentData.Field);
	If CurrentData.ComparisonType = "Filled" Or CurrentData.ComparisonType = "NotFilled" Then
		TypeRestriction = New TypeDescription();
		CurrentData.Value = Undefined;
	ElsIf CurrentData.ComparisonType = "InList" Or CurrentData.ComparisonType = "NotInList" Then
		TypeRestriction = New TypeDescription("ValueList");
	EndIf;
	
	Items.VisibilityConditionsValue.TypeRestriction = TypeRestriction;
	CurrentData.Value = TypeRestriction.AdjustValue(CurrentData.Value);
	
EndProcedure

&AtClient
Function FieldValueType(Field)

	Type = Undefined;
	If ValueIsFilled(Field) Then
		FoundRows = ObjectAttributes.FindRows(New Structure("Field", Field));
		If FoundRows.Count() > 0 Then
			Type = FoundRows[0].Type;
		EndIf;
	EndIf;
	
	Return Type;
	
EndFunction

&AtServer
Function FieldDetails(Field)

	If Not ValueIsFilled(Field) Then
		Return Undefined;
	EndIf;
	
	FoundRows = ObjectAttributes.FindRows(New Structure("Field", Field));
	If FoundRows.Count() > 0 Then
		Return FoundRows[0];
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// ReadOnly for comparison type Filled and NotFilled.
	
	AppearanceItem = ConditionalAppearance.Items.Add();
	
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(Items.VisibilityConditionsValue.Name);
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("VisibilityConditions.ComparisonType");
	FilterElement.ComparisonType = DataCompositionComparisonType.InList;
	ViewListComparison = New ValueList();
	ViewListComparison.Add("Filled");
	ViewListComparison.Add("NotFilled");
	FilterElement.RightValue = ViewListComparison;
	
	AppearanceItem.Appearance.SetParameterValue("ReadOnly", True);
	
EndProcedure

#EndRegion
