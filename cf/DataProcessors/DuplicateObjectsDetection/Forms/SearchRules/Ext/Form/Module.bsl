///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

// Expected parameters:
//
//     DuplicatesSearchArea - String - The full name of the metadata table for the given search area.
//     FilterAreaPresentation - String - Presentation used to generate the title.
//     AppliedRuleDetails - String, Undefined - Applied rule text. If set to "Undefined", there are no applied rules.
//                                  SettingsAddress - String - Address of settings in the temporary storage. Expected structure fields:
//
//     TakeAppliedRulesIntoAccount - Boolean - Previous setting flag. By default, "True".
//         SearchRules - ValueTable - Settings being edited. Expected columns:
//         Attribute - String  - Attribute name for comparison.
//             AttributePresentation - String - Attribute presentation for comparison.
//             Rule - String - Comparison option:
//             "Equal" looks for perfect matches. "Like" looks for fuzzy matches. "" looks for nothing.
//                                 ComparisonOptions - ValueList - Available comparison options, where a value is a rule.
//             Return value (as a selection result):
//                                                  Undefined - Editing is canceled.
//
// String - Address of the new composer settings in the temp storage.
//     Points at a structure similar to the "SettingsAddress" parameter.
//     
//                    
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("AppliedRuleDetails", AppliedRuleDetails);
	DuplicatesSearchArea = Parameters.DuplicatesSearchArea;

	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Duplicate search rule: %1';"), 
		Parameters.FilterAreaPresentation);
	
	InitialSettings = GetFromTempStorage(Parameters.SettingsAddress);
	DeleteFromTempStorage(Parameters.SettingsAddress);
	InitialSettings.Property("TakeAppliedRulesIntoAccount", TakeAppliedRulesIntoAccount);
	
	If AppliedRuleDetails = Undefined Then // Rules are not defined.
		Items.AppliedRestrictionsGroup.Visible = False;
		WindowOptionsKey = "NoAppliedRestrictionsGroup";
	Else
		Items.TakeAppliedRulesIntoAccount.Visible = CanCancelAppliedRules();
	EndIf;
	
	// Filling and adjusting rules.
	SearchRules.Load(InitialSettings.SearchRules);
	For Each RuleRow In SearchRules Do
		RuleRow.Use = Not IsBlankString(RuleRow.Rule);
	EndDo;
	
	For Each Item In InitialSettings.AllComparisonOptions Do
		If Not IsBlankString(Item.Value) Then
			FillPropertyValues(AllSearchRulesComparisonTypes.Add(), Item);
		EndIf;
	EndDo;
	
	HideInsignificantDuplicates = CommonClientServer.StructureProperty(InitialSettings, "HideInsignificantDuplicates", True);
	
	SetColorsAndConditionalAppearance();
	
	IsMobileClient = Common.IsMobileClient();
	If IsMobileClient Then
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		Items.HiddenAtMobileClientGroup.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If IsMobileClient Then
	
		SelectionErrorsText = SelectionErrors();
		If SelectionErrorsText <> Undefined Then
			Cancel = True;
			ShowMessageBox(, SelectionErrorsText);
		Else	
			NotifyChoice(SelectionResult());
		EndIf;
	
	EndIf; 
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure TakeAppliedRulesIntoAccountOnChange(Item)
	
	If TakeAppliedRulesIntoAccount Then
		Return;
	EndIf;
	
	LongDesc = New NotifyDescription("ClearingAppliedRulesUsageCompletion", ThisObject);
	
	TitleText = NStr("en = 'Warning';");
	QueryText   = NStr("en = 'Warning. If you turn off the default restrictions,
	                            |duplicate clean-up might lead to data inconsistency.
	                            |
	                            |Turn off the default restrictions?';");
	
	ShowQueryBox(LongDesc, QueryText, QuestionDialogMode.YesNo,,DialogReturnCode.No, TitleText);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSearchRules

&AtClient
Procedure SearchRulesSelection(Item, RowSelected, Field, StandardProcessing)
	ColumnName = Field.Name;
	If ColumnName = "SearchRulesComparisonType" Then
		StandardProcessing = False;
		SelectComparisonType();
	EndIf;
EndProcedure

&AtClient
Procedure SearchRulesUseOnChange(Item)
	TableRow = Items.SearchRules.CurrentData;
	If TableRow.Use Then
		If IsBlankString(TableRow.Rule) And TableRow.ComparisonOptions.Count() > 0 Then
			TableRow.Rule = TableRow.ComparisonOptions[0].Value
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure SearchRulesComparisonTypeStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	SelectComparisonType();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CompleteEditing(Command)
	
	SelectionErrorsText = SelectionErrors();
	If SelectionErrorsText <> Undefined Then
		ShowMessageBox(, SelectionErrorsText);
	Else	
		NotifyChoice(SelectionResult());
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectComparisonType()
	TableRow = Items.SearchRules.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	ChoiceList = TableRow.ComparisonOptions;
	Count = ChoiceList.Count();
	If Count = 0 Then
		Return;
	EndIf;
	
	Context = New Structure("IDRow", TableRow.GetID());
	Handler = New NotifyDescription("EndingComparisonTypeSelection", ThisObject, Context);
	If Count = 1 And Not TableRow.Use Then
		ExecuteNotifyProcessing(Handler, ChoiceList[0]);
		Return;
	EndIf;
	
	ShowChooseFromMenu(Handler, ChoiceList);
EndProcedure

&AtClient
Procedure EndingComparisonTypeSelection(Result, Context) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	TableRow = SearchRules.FindByID(Context.IDRow);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	TableRow.Rule      = Result.Value;
	TableRow.Use = True;
EndProcedure

&AtClient
Function SelectionErrors()
	
	If AppliedRuleDetails <> Undefined And TakeAppliedRulesIntoAccount Then
		// There are application rules and they are used. There are no errors.
		Return Undefined;
	EndIf;
	
	For Each RulesRow In SearchRules Do
		If RulesRow.Use Then
			// User rule is specified. There are no errors.
			Return Undefined;
		EndIf;
	EndDo;
	
	Return NStr("en = 'Specify at least one duplicate search rule.';");
EndFunction

&AtClient
Procedure ClearingAppliedRulesUsageCompletion(Val Response, Val AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		Return 
	EndIf;
	
	TakeAppliedRulesIntoAccount = True;
EndProcedure

&AtServerNoContext
Function CanCancelAppliedRules()
	
	Result = AccessRight("DataAdministration", Metadata);
	Return Result;
	
EndFunction

&AtServer
Function SelectionResult()
	
	Result = New Structure;
	Result.Insert("TakeAppliedRulesIntoAccount", TakeAppliedRulesIntoAccount);
	
	SelectedRules = SearchRules.Unload();
	For Each RulesRow In SelectedRules  Do
		If Not RulesRow.Use Then
			RulesRow.Rule = "";
		EndIf;
	EndDo;
	SelectedRules.Columns.Delete("Use");
	
	Result.Insert("SearchRules", SelectedRules );
	Result.Insert("HideInsignificantDuplicates", HideInsignificantDuplicates);
	
	Return PutToTempStorage(Result);
EndFunction

&AtServer
Procedure SetColorsAndConditionalAppearance()
	ConditionalAppearanceItems = ConditionalAppearance.Items;
	ConditionalAppearanceItems.Clear();
	
	UnavailableDataColor = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	
	For Each ListItem In AllSearchRulesComparisonTypes Do
		AppearanceItem = ConditionalAppearanceItems.Add();
		
		AppearanceFilter = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		AppearanceFilter.LeftValue = New DataCompositionField("SearchRules.Rule");
		AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
		AppearanceFilter.RightValue = ListItem.Value;
		
		AppearanceField = AppearanceItem.Fields.Items.Add();
		AppearanceField.Field = New DataCompositionField("SearchRulesComparisonType");
		
		AppearanceItem.Appearance.SetParameterValue("Text", ListItem.Presentation);
	EndDo;
	
	// Do not use.
	AppearanceItem = ConditionalAppearanceItems.Add();
	
	AppearanceFilter = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("SearchRules.Use");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = False;
	
	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("SearchRulesComparisonType");
	
	AppearanceItem.Appearance.SetParameterValue("TextColor", UnavailableDataColor);
EndProcedure

#EndRegion

