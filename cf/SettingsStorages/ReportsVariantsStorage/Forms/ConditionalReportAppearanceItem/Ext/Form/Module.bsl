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
	
	SettingsComposer = Parameters.SettingsComposer;
	ReportSettings = Parameters.ReportSettings;
	SettingsStructureItemID = Parameters.SettingsStructureItemID;
	DCID = Parameters.DCID;
	Description = Parameters.Description;
	SetHeader();
	
	AppearanceItem = TheDesignElementIsTheOriginalOne();
	Use = AppearanceItem.Use;
	
	If DCID <> Undefined Then
		
		Description = AppearanceItem.UserSettingPresentation;
		DefaultDescription = ReportsClientServer.ConditionalAppearanceItemPresentation(
			AppearanceItem, Undefined, "");
		
		DescriptionOverridden = (Description <> "" And Description <> DefaultDescription);
		Items.Description.InputHint = DefaultDescription;
		
		If Not DescriptionOverridden Then
			
			Description = "";
			Items.Description.ClearButton = False;
			
		EndIf;
		
	EndIf;
	
	CheckTheDesignField(AppearanceItem);
	CheckTheCondition(AppearanceItem);
	
	For Each CheckBoxField In Items.UsageOptionsMarks.ChildItems Do
		
		CheckBoxName = CheckBoxField.Name;
		DisplayAreaCheckBoxes.Add(CheckBoxName);
		
		If AppearanceItem[CheckBoxName] = DataCompositionConditionalAppearanceUse.Use Then
			ThisObject[CheckBoxName] = True;
		EndIf;
		
	EndDo;
	
	FillInTheSelectionListOfTheFieldsToBeDrawnUp(AppearanceItem);
	SetTheOptionForSelectingTheFieldToBeDrawnUp(AppearanceItem);
	
	CloseOnChoice = False;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FormattedFieldsSelectionOptionOnChange(Item)
	
	ApplyTheOptionToSelectTheFieldToBeDrawnUp(ThisObject);
	
EndProcedure

&AtClient
Procedure FormattedFieldOnChange(Item)
	
	If Not ValueIsFilled(FormattedField) Then 
		
		FormattedFieldsSelectionOption = Items.FormattedFieldsSelectionOption.ChoiceList[0].Value;
		ApplyTheOptionToSelectTheFieldToBeDrawnUp(ThisObject);
		
	EndIf;
	
	UpdateDefaultDescription();
	
EndProcedure

&AtClient
Procedure FormattedFieldChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	UsedFields = TheFieldsThatAreBeingProcessedAreUsed(ThisObject);
	
	If TypeOf(ValueSelected) = Type("String")
		And ValueSelected <> AdditionalField() Then 
		
		Field = New DataCompositionField(ValueSelected);
		
		Appearance = Appearance(ThisObject);
		AvailableField = Appearance.FieldsAvailableFields.FindField(Field);
		
	ElsIf TypeOf(ValueSelected) = Type("DataCompositionAvailableField") Then 
		
		Field = ValueSelected.Field;
		AvailableField = ValueSelected;
		
	ElsIf TypeOf(ValueSelected) = Type("DataCompositionUserFieldExpression") Then 
		
		UpdateTheCompositionOfTheFormulaDescription(ValueSelected);
		
		Appearance = Appearance(ThisObject);
		
		AvailableField = ValueSelected;
		ReportsOptionsInternalClient.AddFormula(SettingsComposer.Settings, Appearance.FieldsAvailableFields, AvailableField);
		
		Field = AvailableField.Field;
		
	Else
		
		SelectTheFieldToBeDrawnUp(Item, ValueSelected, UsedFields);
		Return;
		
	EndIf;
	
	If UsedFields.Count() = 0 Then 
		
		AppearanceItem = AppearanceItem(SettingsComposer.Settings);
		TheFieldUsed = AppearanceItem.Fields.Items.Insert(0);
		TheFieldUsed.Use = True;
		
	Else
		
		TheFieldUsed = UsedFields[0];
		
	EndIf;
	
	TheFieldUsed.Field = Field;
	
	AddASelectionListOfTheFieldsToBeDrawnUp(ThisObject, Field, AvailableField);
	FormattedField = Field;
	
	UpdateDefaultDescription();
	
EndProcedure

&AtClient
Procedure DescriptionOnChange(Item)
	
	If Description = "" Or Description = Items.Description.InputHint Then
		DefaultDescriptionUpdateRequired = True;
		UpdateDefaultDescriptionIfRequired();
		Items.Description.ClearButton = False;
	Else
		Items.Description.ClearButton = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure UseInGroupOnChange(Item)
	
	UpdateDefaultDescription();
	
EndProcedure

&AtClient
Procedure UseInHierarchicalGroupOnChange(Item)
	
	UpdateDefaultDescription();
	
EndProcedure

&AtClient
Procedure UseInOverallOnChange(Item)
	
	UpdateDefaultDescription();
	
EndProcedure

&AtClient
Procedure UseInFieldsHeaderOnChange(Item)
	
	UpdateDefaultDescription();
	
EndProcedure

&AtClient
Procedure UseInHeaderOnChange(Item)
	
	UpdateDefaultDescription();
	
EndProcedure

&AtClient
Procedure UseInParametersOnChange(Item)
	
	UpdateDefaultDescription();
	
EndProcedure

&AtClient
Procedure UseInFilterOnChange(Item)
	
	UpdateDefaultDescription();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAppearance

&AtClient
Procedure AppearanceOnChange(Item)
	
	UpdateDefaultDescription();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFilter

&AtClient
Procedure FilterOnChange(Item)
	
	UpdateDefaultDescription();
	
EndProcedure

&AtClient
Procedure FilterBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	ChangeTheField(Item, Cancel);
	
EndProcedure

&AtClient
Procedure FilterBeforeRowChange(Item, Cancel)
	
	If Item.CurrentItem.Name = Items.FilterLeftValue.Name Then 
		ChangeTheField(Item, Cancel, False);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFormattedFields

&AtClient
Procedure FormattedFieldsOnChange(Item)
	
	UpdateDefaultDescription();
	
EndProcedure

&AtClient
Procedure FormattedFieldsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	ChangeTheField(Item, Cancel);
	
EndProcedure

&AtClient
Procedure FormattedFieldsBeforeRowChange(Item, Cancel)
	
	ChangeTheField(Item, Cancel, False);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	
	SelectAndClose();
	
EndProcedure

&AtClient
Procedure Show_SelectCheckBoxes(Command)
	
	For Each ListItem In DisplayAreaCheckBoxes Do
		ThisObject[ListItem.Value] = True;
	EndDo;
	
	UpdateDefaultDescription();
	
EndProcedure

&AtClient
Procedure Show_ClearCheckBoxes(Command)
	
	For Each ListItem In DisplayAreaCheckBoxes Do
		ThisObject[ListItem.Value] = False;
	EndDo;
	
EndProcedure

&AtClient
Procedure InsertDefaultDescription(Command)
	
	Description = DefaultDescription;
	Items.Description.ClearButton = False;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetHeader()
	
	Title = Parameters.Title;
	
	If Not ValueIsFilled(Title) Then 
		Title = NStr("en = 'Appearance';");
	EndIf;
	
EndProcedure

&AtServer
Function TheDesignElementIsTheOriginalOne()
	
	Source = New DataCompositionAvailableSettingsSource(ReportSettings.SchemaURL);
	SettingsComposer.Initialize(Source);
	
	Appearance = SettingsComposer.Settings.ConditionalAppearance;
	
	If DCID = Undefined Then // New item.
		
		IsNew = True;
		
		AppearanceItem = Appearance.Items.Insert(0);
		AppearanceItem.Use = True;
		AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Normal;
		
		Items.Description.ClearButton = False;
		
	Else
		
		DesignSource = Appearance(ThisObject);
		If DesignSource = Undefined Then
			Raise NStr("en = 'The report node does not exist.';");
		EndIf;
		
		DesignElementSource = DesignSource.GetObjectByID(DCID);
		If DesignElementSource = Undefined Then
			Raise NStr("en = 'The conditional appearance item does not exist.';");
		EndIf;
		
		AppearanceItem = ReportsClientServer.CopyRecursive(Appearance, DesignElementSource, Appearance.Items, 0, New Map);
		
	EndIf;
	
	Return AppearanceItem;
	
EndFunction

&AtClientAtServerNoContext
Function AppearanceItem(Settings)
	
	Return Settings.ConditionalAppearance.Items[0];
	
EndFunction

&AtClientAtServerNoContext
Function Appearance(Form)
	
	Settings = Form.SettingsComposer.Settings;
	If Form.SettingsStructureItemID = Undefined Then
		Return Settings.ConditionalAppearance;
	EndIf;
	
	StructureItem = Settings.GetObjectByID(Form.SettingsStructureItemID);
	If TypeOf(StructureItem) = Type("DataCompositionNestedObjectSettings") Then
		Return StructureItem.Settings.ConditionalAppearance;
	Else
		Return StructureItem.ConditionalAppearance;
	EndIf;
	
EndFunction

&AtClientAtServerNoContext
Function TheDesignFieldFound(Settings, SearchField)
	
	AppearanceItem = AppearanceItem(Settings);
	
	For Each Item In AppearanceItem.Fields.Items Do 
		
		If Item.Field = SearchField Then  
			Return Item;
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtServer
Procedure CheckTheDesignField(AppearanceItem)
	
	If TypeOf(Parameters.Field) <> Type("DataCompositionField") Then
		Return;
	EndIf;
	
	AppearanceField = TheDesignFieldFound(SettingsComposer.Settings, Parameters.Field);
	
	If AppearanceField  = Undefined Then 
		
		AppearanceField = AppearanceItem.Fields.Items.Add();
		AppearanceField.Field = Parameters.Field;
		
	EndIf;
	
	AppearanceField.Use = True;
	
EndProcedure

&AtServer
Procedure CheckTheCondition(AppearanceItem)
	
	Condition = Undefined;
	
	If Not Parameters.Property("Condition", Condition)
		Or TypeOf(Condition) <> Type("Structure") Then 
		
		Return;
	EndIf;
	
	FilterElement = Undefined;
	
	For Each Item In AppearanceItem.Filter.Items Do 
		
		If TypeOf(Item) = Type("DataCompositionFilterItem")
			And Item.LeftValue = Condition.LeftValue Then 
			
			FilterElement = Item;
			Break;
			
		EndIf;
		
	EndDo;
	
	If FilterElement = Undefined Then 
		
		FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterElement.LeftValue = Condition.LeftValue;
		
	EndIf;
	
	FilterElement.ComparisonType = Condition.ComparisonType;
	FilterElement.RightValue = Condition.RightValue;
	FilterElement.Use = True;
	
EndProcedure

&AtClient
Procedure UpdateDefaultDescription()
	
	DefaultDescriptionUpdateRequired = True;
	
	If Description = "" Or Description = Items.Description.InputHint Then
		AttachIdleHandler("UpdateDefaultDescriptionIfRequired", 1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateDefaultDescriptionIfRequired()
	
	If Not DefaultDescriptionUpdateRequired Then
		Return;
	EndIf;
	
	DefaultDescriptionUpdateRequired = False;
	
	AppearanceItem = AppearanceItem(SettingsComposer.Settings);
	
	DefaultDescription = ReportsClientServer.ConditionalAppearanceItemPresentation(AppearanceItem, Undefined, "");
	If Description = Items.Description.InputHint Then
		
		Description = DefaultDescription;
		Items.Description.InputHint = DefaultDescription;
		
	ElsIf Description = "" Then
		
		Items.Description.InputHint = DefaultDescription;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectAndClose()
	
	DetachIdleHandler("UpdateDefaultDescriptionIfRequired");
	UpdateDefaultDescriptionIfRequired();
	
	If Description = "" Then
		Description = DefaultDescription;
	EndIf;
	
	AppearanceItem = AppearanceItem(SettingsComposer.Settings);
	
	If Description = DefaultDescription Then
		AppearanceItem.UserSettingPresentation = "";
	Else
		AppearanceItem.UserSettingPresentation = Description;
	EndIf;
	
	For Each ListItem In DisplayAreaCheckBoxes Do
		
		CheckBoxName = ListItem.Value;
		
		If ThisObject[CheckBoxName] Then
			AppearanceItem[CheckBoxName] = DataCompositionConditionalAppearanceUse.Use;
		Else
			AppearanceItem[CheckBoxName] = DataCompositionConditionalAppearanceUse.DontUse;
		EndIf;
		
	EndDo;
	
	SpecifyTheCompositionOfTheFieldsToBeDrawnUp(AppearanceItem);
	
	AppearanceItem.Use = Use;
	
	DescriptionOfFormulas = CommonClientServer.StructureProperty(ReportSettings, "DescriptionOfFormulas", New Array);
	
	Result = New Structure();
	Result.Insert("DCItem", AppearanceItem);
	Result.Insert("Description", Description);
	Result.Insert("DescriptionOfFormulas", DescriptionOfFormulas);
	
	NotifyChoice(Result);
	Close(Result);
	
EndProcedure

&AtServer
Procedure FillInTheSelectionListOfTheFieldsToBeDrawnUp(AppearanceItem)
	
	List = Items.FormattedField.ChoiceList;
	
	Appearance = Appearance(ThisObject);
	AvailableFields = Appearance.FieldsAvailableFields.Items;
	
	Boundary = Min(19, AvailableFields.Count() - 1);
	
	For IndexOf = 0 To Boundary Do 
		
		AvailableField = AvailableFields[IndexOf];
		
		If Not AvailableField.Folder Then 
			
			FieldPicture = ReportsOptionsInternalClientServer.FieldPicture(AvailableField.ValueType);
			List.Add(String(AvailableField.Field), AvailableField.Title,, FieldPicture);
			
		EndIf;
		
	EndDo;
	
	UsedFields = TheFieldsThatAreBeingProcessedAreUsed(ThisObject, AppearanceItem);
	
	If UsedFields.Count() > 0 Then 
		
		TheFieldUsed = UsedFields[0].Field;
		AvailableField = Appearance.FieldsAvailableFields.FindField(TheFieldUsed);
		AddASelectionListOfTheFieldsToBeDrawnUp(ThisObject, TheFieldUsed, AvailableField);
		
	EndIf;
	
	AddAdditionalField(List);
	
EndProcedure

&AtServer
Procedure SetTheOptionForSelectingTheFieldToBeDrawnUp(AppearanceItem)
	
	UsedFields = TheFieldsThatAreBeingProcessedAreUsed(ThisObject, AppearanceItem);
	SelectionOptions = Items.FormattedFieldsSelectionOption.ChoiceList;
	
	If UsedFields.Count() = 0 Then 
		
		FormattedFieldsSelectionOption = SelectionOptions[0].Value;
		
	ElsIf UsedFields.Count() = 1 Then 
		
		FormattedFieldsSelectionOption = SelectionOptions[1].Value;
		
	Else
		
		FormattedFieldsSelectionOption = SelectionOptions[2].Value;
		
	EndIf;
	
	ApplyTheOptionToSelectTheFieldToBeDrawnUp(ThisObject, AppearanceItem, UsedFields);
	
EndProcedure

&AtClientAtServerNoContext
Function TheFieldsThatAreBeingProcessedAreUsed(Form, AppearanceItem = Undefined)
	
	If AppearanceItem = Undefined Then 
		AppearanceItem = AppearanceItem(Form.SettingsComposer.Settings);
	EndIf;
	
	UsedFields = New Array;
	
	FormattedFields = AppearanceItem.Fields.Items;
	
	For Each FormattedField In FormattedFields Do 
		
		If FormattedField.Use Then 
			UsedFields.Add(FormattedField);
		EndIf;
		
	EndDo;
	
	Return UsedFields;
	
EndFunction

&AtClientAtServerNoContext
Procedure ApplyTheOptionToSelectTheFieldToBeDrawnUp(Form, AppearanceItem = Undefined, UsedFields = Undefined)
	
	If AppearanceItem = Undefined Then 
		AppearanceItem = AppearanceItem(Form.SettingsComposer.Settings);
	EndIf;
	
	If UsedFields = Undefined Then 
		UsedFields = TheFieldsThatAreBeingProcessedAreUsed(Form, AppearanceItem);
	EndIf;
	
	FormItems = Form.Items;
	
	Variant = Form.FormattedFieldsSelectionOption;
	Variants = FormItems.FormattedFieldsSelectionOption.ChoiceList;
	
	If Variant = Variants[0].Value Then 
		
		FormItems.FormattedFieldsPages.CurrentPage = FormItems.FormattedFieldPage;
		FormItems.FormattedFields.Visible = False;
		
		Form.FormattedField = Undefined;
		FormItems.FormattedField.ReadOnly = True;
		
	ElsIf Variant = Variants[1].Value Then 
		
		FormItems.FormattedFieldsPages.CurrentPage = FormItems.FormattedFieldPage;
		FormItems.FormattedFields.Visible = False;
		
		Form.FormattedField = ?(UsedFields.Count() = 0, Undefined, UsedFields[0].Field);
		FormItems.FormattedField.ReadOnly = False;
		
	Else
		
		FormItems.FormattedFieldsPages.CurrentPage = FormItems.PageCommandBar;
		FormItems.FormattedFields.Visible = True;
		
		Form.FormattedField = Undefined;
		FormItems.FormattedField.ReadOnly = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectTheFieldToBeDrawnUp(Item, ValueSelected, UsedFields)
	
	If ValueSelected <> AdditionalField() Then 
		Return;
	EndIf;
	
	Field = ?(UsedFields.Count() = 0, Undefined, UsedFields[0].Field);
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("ReportSettings", ReportSettings);
	ChoiceParameters.Insert("SettingsComposer", SettingsComposer);
	ChoiceParameters.Insert("Mode", "SelectedFields");
	ChoiceParameters.Insert("DCField", Field);
	ChoiceParameters.Insert("SettingsStructureItemID", SettingsStructureItemID);
	
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.SelectReportField",
		ChoiceParameters, Item, UUID);
	
EndProcedure

&AtClientAtServerNoContext
Procedure AddASelectionListOfTheFieldsToBeDrawnUp(Form, Field, AvailableField)
	
	Field_String = String(Field);
	
	List = Form.Items.FormattedField.ChoiceList;
	FoundField = List.FindByValue(Field_String);
	
	If FoundField = Undefined Then 
		
		FieldValueType = Undefined;
		FieldTitle = Field_String;
		
		If AvailableField <> Undefined Then 
			
			FieldValueType = AvailableField.ValueType;
			FieldTitle = AvailableField.Title;
			
		EndIf;
		
		FieldPicture = ReportsOptionsInternalClientServer.FieldPicture(FieldValueType);
		List.Add(Field_String, FieldTitle,, FieldPicture);
		
	ElsIf AvailableField <> Undefined Then 
		
		FoundField.Presentation = AvailableField.Title;
	
	EndIf;
	
	AdditionalField = List.FindByValue(AdditionalField());
	
	If AdditionalField <> Undefined Then
		List.Delete(AdditionalField);
	EndIf;
	
	AddAdditionalField(List);
	
EndProcedure

&AtClientAtServerNoContext
Procedure AddAdditionalField(List)
	
	If List.FindByValue(AdditionalField()) <> Undefined Then 
		Return;
	EndIf;
	
	List.SortByPresentation();
	List.Add(AdditionalField(), NStr("en = 'More…';"),, PictureLib.IsEmpty);
	
EndProcedure

&AtClientAtServerNoContext
Function AdditionalField()
	
	Return "More";
	
EndFunction

&AtClient
Procedure SpecifyTheCompositionOfTheFieldsToBeDrawnUp(AppearanceItem)
	
	Variants = Items.FormattedFieldsSelectionOption.ChoiceList;
	
	If FormattedFieldsSelectionOption = Variants[2].Value Then 
		Return;
	EndIf;
	
	InitialIndex = 1;
	
	If FormattedFieldsSelectionOption = Variants[0].Value Then 
		InitialIndex = 0;
	EndIf;
	
	UsedFields = TheFieldsThatAreBeingProcessedAreUsed(ThisObject, AppearanceItem);
	Fields = AppearanceItem.Fields.Items;
	
	For IndexOf = InitialIndex To UsedFields.UBound() Do 
		Fields.Delete(UsedFields[IndexOf]);
	EndDo;
	
EndProcedure

&AtClient
Procedure ChangeTheField(Item, Cancel, ThisIsAnAddendum = True)
	
	Cancel = True;
	
	TheCurrentRecordOfTheDesignCollection = TheCurrentRecordOfTheDesignCollection(Item, ThisIsAnAddendum);
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("ReportSettings", ReportSettings);
	ChoiceParameters.Insert("SettingsComposer", SettingsComposer);
	ChoiceParameters.Insert("Mode", FieldSelectionMode(Item));
	ChoiceParameters.Insert("DCField", CurrentField(TheCurrentRecordOfTheDesignCollection));
	ChoiceParameters.Insert("SettingsStructureItemID", SettingsStructureItemID);
	
	AdditionalParameters = New Structure("Item, TheCurrentRecordOfTheDesignCollection", Item, TheCurrentRecordOfTheDesignCollection);
	Handler = New NotifyDescription("AfterSelectingAField", ThisObject, AdditionalParameters);
	
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.SelectReportField",
		ChoiceParameters, ThisObject, UUID,,, Handler);
	
EndProcedure

// Parameters:
//  ValueSelected - DataCompositionUserFieldExpression
//                    - DataCompositionAvailableField
//                    - DataCompositionFilterAvailableField
//  AdditionalParameters - Structure:
//    * Item - FormTable
//    * TheCurrentRecordOfTheDesignCollection - DataCompositionFilterItem
//                                       - DataCompositionAppearanceField
//                                       - Undefined
//
&AtClient
Procedure AfterSelectingAField(ValueSelected, AdditionalParameters) Export 
	
	If ValueSelected = Undefined Then 
		Return;
	EndIf;
	
	AvailableFields = AvailableFields(AdditionalParameters.Item);
	
	If TypeOf(ValueSelected) = Type("DataCompositionUserFieldExpression") Then 
		
		UpdateTheCompositionOfTheFormulaDescription(ValueSelected);
		ReportsOptionsInternalClient.AddFormula(SettingsComposer.Settings, AvailableFields, ValueSelected);
		
	EndIf;
	
	If AvailableFields.FindField(ValueSelected.Field) = Undefined Then 
		Return;
	EndIf;
	
	TheCurrentRecordOfTheDesignCollection = AdditionalParameters.TheCurrentRecordOfTheDesignCollection;
	
	If AdditionalParameters.Item = Items.FormattedFields Then 
		UpdateTheDesignField(SettingsComposer.Settings, TheCurrentRecordOfTheDesignCollection, ValueSelected.Field);
	Else
		UpdateTheRegistrationConditionsField(SettingsComposer.Settings, TheCurrentRecordOfTheDesignCollection, ValueSelected.Field);
	EndIf;
	
	UpdateDefaultDescription();
	
EndProcedure

&AtClient
Procedure UpdateTheDesignField(Settings, CurrentField, SelectedField)
	
	AppearanceItem = AppearanceItem(Settings);
	
	If CurrentField = Undefined Then 
		
		AppearanceField = TheDesignFieldFound(Settings, SelectedField);
		
		If AppearanceField = Undefined Then 
			AppearanceField = AppearanceItem.Fields.Items.Add();
		EndIf;
		
	Else
		AppearanceField = CurrentField;
	EndIf;
	
	AppearanceField.Field = SelectedField;
	AppearanceField.Use = True;
	
EndProcedure

&AtClient
Procedure UpdateTheRegistrationConditionsField(Settings, CurrentCondition, SelectedField)
	
	AppearanceItem = AppearanceItem(Settings);
	
	If CurrentCondition = Undefined Then 
		
		Condition = TheFoundRegistrationCondition(Settings, SelectedField);
		
		If Condition = Undefined Then 
			
			Condition = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
			Items.Filter.Expand(Items.Filter.CurrentRow, True);
			
		EndIf;
		
	Else
		Condition = CurrentCondition;
	EndIf;
	
	Condition.LeftValue = SelectedField;
	Condition.Use = True;
	
EndProcedure

&AtClient
Function TheFoundRegistrationCondition(Settings, SearchField, Conditions = Undefined, TheFoundCondition = Undefined)
	
	If Conditions = Undefined Then 
		
		AppearanceItem = AppearanceItem(Settings);
		Conditions = AppearanceItem.Filter;
		
	EndIf;
	
	For Each Item In Conditions.Items Do 
		
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then 
			
			TheFoundRegistrationCondition(Settings, SearchField, Item, TheFoundCondition);
			
		ElsIf Item.LeftValue = SearchField Then  
			
			TheFoundCondition = Item;
			Break;
			
		EndIf;
		
	EndDo;
	
	Return TheFoundCondition;
	
EndFunction

&AtClient
Function TheCurrentRecordOfTheDesignCollection(Item, ThisIsAnAddendum)
	
	If ThisIsAnAddendum Then 
		Return Undefined;
	EndIf;
	
	String = Item.CurrentData;
	
	If String = Undefined Then 
		Return Undefined;
	EndIf;
	
	If Item = Items.FormattedFields Then 
		Return TheDesignFieldFound(SettingsComposer.Settings, String.Field);
	EndIf;
	
	Return TheFoundRegistrationCondition(SettingsComposer.Settings, String.LeftValue);
	
EndFunction

&AtClient
Function CurrentField(TheCurrentRecordOfTheDesignCollection)
	
	If TypeOf(TheCurrentRecordOfTheDesignCollection) = Type("DataCompositionAppearanceField") Then 
		
		Return TheCurrentRecordOfTheDesignCollection.Field;
		
	ElsIf TypeOf(TheCurrentRecordOfTheDesignCollection) = Type("DataCompositionFilterItem") Then 
		
		Return TheCurrentRecordOfTheDesignCollection.LeftValue;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function FieldSelectionMode(Item)
	
	If Item = Items.FormattedFields Then 
		Return "AppearanceFields";
	EndIf;
	
	Return "TermsOfRegistration";
	
EndFunction

&AtClient
Function AvailableFields(Item)
	
	Appearance = Appearance(ThisObject);
	
	If Item = Items.FormattedFields Then 
		Return Appearance.FieldsAvailableFields;
	EndIf;
	
	Return Appearance.FilterAvailableFields;
	
EndFunction

&AtClient
Procedure UpdateTheCompositionOfTheFormulaDescription(FormulaDescription)
	
	DescriptionOfFormulas = CommonClientServer.StructureProperty(ReportSettings, "DescriptionOfFormulas", New Array);
	
	If DescriptionOfFormulas.Find(FormulaDescription) = Undefined Then 
		DescriptionOfFormulas.Add(FormulaDescription);
	EndIf;
	
	ReportSettings.Insert("DescriptionOfFormulas", DescriptionOfFormulas);
	
EndProcedure

#EndRegion