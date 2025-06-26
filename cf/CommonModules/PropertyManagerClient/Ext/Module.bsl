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

// Determines that the specified event is an event of property set change.
//
// Parameters:
//  Form      - ClientApplicationForm - a form, from which the notification processing was called.
//  EventName - String       - a name of the processed event.
//  Parameter   - Arbitrary - parameters passed in the event.
//             - Structure:
//                  * Ref - CatalogRef.AdditionalAttributesAndInfoSets - a changed property set.
//                           - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - — a changed additional
//                                                                                             attribute.
//
// Returns:
//  Boolean - if True, it is a notification of property set change, and
//           it needs to be processed in the form.
//
Function ProcessNotifications(Form, EventName, Parameter) Export
	
	If Not Form.PropertiesUseProperties
	 Or Not Form.PropertiesUseAddlAttributes Then
		
		Return False;
	EndIf;
	
	If EventName = "Write_AdditionalAttributesAndInfoSets" Then
		If Not Parameter.Property("Ref") Then
			Return True;
		Else
			Return Form.PropertiesObjectAdditionalAttributeSets.FindByValue(Parameter.Ref) <> Undefined;
		EndIf;
		
	ElsIf EventName = "Write_AdditionalAttributesAndInfo" Then
		
		If Form.PropertiesParameters.Property("DeferredInitializationExecuted")
			And Not Form.PropertiesParameters.DeferredInitializationExecuted
			Or Not Parameter.Property("Ref") Then
			Return True;
		Else
			Filter = New Structure("Property", Parameter.Ref); 
			If Form.PropertiesAdditionalAttributeDetails.FindRows(Filter).Count() > 0
				Or Form.Properties_LabelsApplied.FindByValue(Parameter.Ref) <> Undefined Then
				Return True;
			Else
				Return False;
			EndIf;
		EndIf;
	ElsIf EventName = "Write_LabelsChange" And Form = Parameter.Owner Then
		Form.Properties_LabelsApplied.LoadValues(Parameter.LabelsApplied);
		Form.Modified = True;
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Updates visibility, availability, and required filling
// of additional attributes.
//
// Parameters:
//  Form  - ClientApplicationForm     - a form being processed.
//  Object - FormDataStructure - details of the object, to which properties are attached,
//                                  if the property is not specified or Undefined, the
//                                  object is taken from the Object form attribute.
//
Procedure UpdateAdditionalAttributesDependencies(Form, Object = Undefined) Export
	
	If Not Form.PropertiesUseProperties
	 Or Not Form.PropertiesUseAddlAttributes Then
		
		Return;
	EndIf;
	
	If Form.PropertiesDependentAdditionalAttributesDescription.Count() = 0 Then
		Return;
	EndIf;
	
	If Object = Undefined Then
		ObjectDetails = Form.Object;
	Else
		ObjectDetails = Object;
	EndIf;
	
	For Each DependentAttributeDetails In Form.PropertiesDependentAdditionalAttributesDescription Do
		If DependentAttributeDetails.OutputAsHyperlink Then
			ProcessedItem = StrReplace(DependentAttributeDetails.ValueAttributeName, "AdditionalAttributeValue_", "Group_");
		Else
			ProcessedItem = DependentAttributeDetails.ValueAttributeName;
		EndIf;
		
		If DependentAttributeDetails.AvailabilityCondition <> Undefined Then
			Parameters = New Structure;
			Parameters.Insert("ParameterValues", DependentAttributeDetails.AvailabilityCondition.ParameterValues);
			Parameters.Insert("Form", Form);
			Parameters.Insert("ObjectDetails", ObjectDetails);
			Result = Eval(DependentAttributeDetails.AvailabilityCondition.ConditionCode);
			
			Item = Form.Items[ProcessedItem];
			If Item.Enabled <> Result Then
				Item.Enabled = Result;
			EndIf;
		EndIf;
		If DependentAttributeDetails.VisibilityCondition <> Undefined Then
			Parameters = New Structure;
			Parameters.Insert("ParameterValues", DependentAttributeDetails.VisibilityCondition.ParameterValues);
			Parameters.Insert("Form", Form);
			Parameters.Insert("ObjectDetails", ObjectDetails);
			Result = Eval(DependentAttributeDetails.VisibilityCondition.ConditionCode);
			
			Item = Form.Items[ProcessedItem];
			If Item.Visible <> Result Then
				Item.Visible = Result;
			EndIf;
		EndIf;
		If DependentAttributeDetails.FillingRequiredCondition <> Undefined Then
			If Not DependentAttributeDetails.RequiredToFill Then
				Continue;
			EndIf;
			
			Parameters = New Structure;
			Parameters.Insert("ParameterValues", DependentAttributeDetails.FillingRequiredCondition.ParameterValues);
			Parameters.Insert("Form", Form);
			Parameters.Insert("ObjectDetails", ObjectDetails);
			Result = Eval(DependentAttributeDetails.FillingRequiredCondition.ConditionCode);
			
			Item = Form.Items[ProcessedItem];
			If Not DependentAttributeDetails.OutputAsHyperlink
				And Item.AutoMarkIncomplete <> Result Then
				Item.AutoMarkIncomplete = Result;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Checks for dependent additional attributes on the form
// and attaches an idle handler for checking attribute dependencies if needed.
//
// Parameters:
//  Form - ClientApplicationForm - a form to be checked.
//
Procedure AfterImportAdditionalAttributes(Form) Export
	
	If Not Form.PropertiesUseProperties
		Or Not Form.PropertiesUseAddlAttributes Then
		
		Return;
	EndIf;
	
	Form.AttachIdleHandler("UpdateAdditionalAttributesDependencies", 2);
	
EndProcedure

// Command handler from forms, to which additional properties are attached.
// 
// Parameters:
//  Form                - ClientApplicationForm - a form with additional attributes preliminarily
//                          set in the PropertyManager.OnCreateAtServer() procedure.
//  Item              - FormField
//                       - FormCommand - an item whose clicking is to be processed.
//  StandardProcessing - Boolean - a returned parameter, if interactive
//                          actions with the user are needed, it is set to False.
//  Object - FormDataStructure - details of the object, to which properties are attached,
//                                  if the property is not specified or Undefined, the
//                                  object is taken from the Object form attribute.
//
Procedure ExecuteCommand(Form,
						   Item = Undefined,
						   StandardProcessing = Undefined,
						   Object = Undefined) Export
	
	If Item = Undefined Then
		CommandName = "EditAdditionalAttributesComposition";
	ElsIf TypeOf(Item) = Type("FormCommand") Then
		CommandName = Item.Name;
	ElsIf TypeOf(Item) = Type("FormDecoration") Then
		CommandName = Item.Name;
	Else
		AttributeValue = Form[Item.Name];
		If Not ValueIsFilled(AttributeValue) Then
			EditAttributeHyperlink(Form, True, Item);
			StandardProcessing = False;
		EndIf;
		Return;
	EndIf;
	
	If CommandName = "EditAdditionalAttributesComposition" Then
		EditPropertiesContent(Form);
	ElsIf CommandName = "EditAttributeHyperlink" Then
		EditAttributeHyperlink(Form);
	ElsIf CommandName = "EditLabels"
		Or CommandName = "OtherLabels"
		Or StrFind(CommandName, "Label") = 1 Then
		EditLabels(Form, Object);
	EndIf;
	
EndProcedure

// Opens the form for editing labels for an object.
//
// Parameters:
//  Form  - ClientApplicationForm     - a form being processed.
//  Object - FormDataStructure - details of the object, to which properties are attached,
//                                  if the property is not specified or Undefined, the
//                                  object is taken from the Object form attribute.
//
Procedure EditLabels(Form, Object = Undefined) Export
	
	If Object = Undefined Then
		ObjectDetails = Form.Object;
	Else
		ObjectDetails = Object;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ObjectDetails", ObjectDetails);
	
	OpenForm("CommonForm.LabelsEdit", FormParameters, Form, Form,,,,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Sets the filter in the list by label.
//
// Parameters:
//  Form      - ClientApplicationForm     - a form being processed.
//  CommandName - String - a name of the command to set a filter by label.
//
Procedure ApplyFilterByLabel(Form, CommandName) Export
	
	FilterItems1 = Form.List.Filter.Items;
	FilterGroup = Undefined;
	For Each FilterElement In FilterItems1 Do
		If FilterElement.UserSettingID = "FilterByLabels" Then
			FilterGroup = FilterElement;
			Break;
		EndIf;
	EndDo;
	
	NameOfLabel = StrReplace(CommandName, "FilterLabel_", "");
	LabelsLegendDetails = Form.Properties_LabelsLegendDetails;
	LegendLabels = LabelsLegendDetails.FindRows(New Structure("NameOfLabel", NameOfLabel));
	
	If LegendLabels.Count() = 0 Then
		Return;
	Else
		SelectedLabel = LegendLabels[0];
	EndIf;
	
	If FilterGroup = Undefined Then
		SelectedLabels = New Array;
		SelectedLabels.Add(SelectedLabel.Label);
	Else
		SelectedLabels = FilterGroup.RightValue;
		LabelIndex = SelectedLabels.Find(SelectedLabel.Label);
		If LabelIndex <> Undefined Then
			SelectedLabels.Delete(LabelIndex);
			SelectedLabel.FilterByLabel = False;
		Else
			SelectedLabels.Add(SelectedLabel.Label);
			SelectedLabel.FilterByLabel = True;
		EndIf;
	EndIf;
	
	If SelectedLabels.Count() = 0 Then
		FilterGroup.Use = False;
		Return;
	EndIf;
	
	CommonClientServer.SetDynamicListFilterItem(
		Form.List,
		"AdditionalAttributes.Property",
		SelectedLabels,
		DataCompositionComparisonType.InList,,
		True,
		DataCompositionSettingsItemViewMode.Inaccessible,
		"FilterByLabels");
	
EndProcedure

#EndRegion

#Region Internal

Procedure OpenPropertiesList(CommandName) Export
	
	If CommandName = "AdditionalAttributes" Then
		PropertyKind = PredefinedValue("Enum.PropertiesKinds.AdditionalAttributes");
	ElsIf CommandName = "AdditionalInfo" Then
		PropertyKind = PredefinedValue("Enum.PropertiesKinds.AdditionalInfo");
	ElsIf CommandName = "Labels" Then
		PropertyKind = PredefinedValue("Enum.PropertiesKinds.Labels");
	Else
		PropertyKind = PredefinedValue("Enum.PropertiesKinds.AdditionalAttributes");
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("PropertyKind", PropertyKind);
	OpenForm("Catalog.AdditionalAttributesAndInfoSets.ListForm", FormParameters,, PropertyKind);
	
EndProcedure

#EndRegion

#Region Private

// Opens the editing form of an additional attribute set.
//
// Parameters:
//  Form - ClientApplicationForm - a form the method is called from.
//
Procedure EditPropertiesContent(Form)
	
	Sets = Form.PropertiesObjectAdditionalAttributeSets;
	
	If Sets.Count() = 0
	 Or Not ValueIsFilled(Sets[0].Value) Then
		
		ShowMessageBox(,
			NStr("en = 'Cannot get the additional attribute sets of the object.
			           |
			           |Probably some of the required object attributes are blank.';"));
	
	Else
		FormParameters = New Structure;
		FormParameters.Insert("PropertyKind",
			PredefinedValue("Enum.PropertiesKinds.AdditionalAttributes"));
		
		OpenForm("Catalog.AdditionalAttributesAndInfoSets.ListForm", FormParameters);
		
		MigrationParameters = New Structure;
		MigrationParameters.Insert("Set", Sets[0].Value);
		MigrationParameters.Insert("Property", Undefined);
		MigrationParameters.Insert("IsAdditionalInfo", False);
		MigrationParameters.Insert("PropertyKind",
			PredefinedValue("Enum.PropertiesKinds.AdditionalAttributes"));
		
		BeginningLength = StrLen("AdditionalAttributeValue_");
		IsFormField = (TypeOf(Form.CurrentItem) = Type("FormField"));
		If IsFormField And Upper(Left(Form.CurrentItem.Name, BeginningLength)) = Upper("AdditionalAttributeValue_") Then
			
			SetID   = StrReplace(Mid(Form.CurrentItem.Name, BeginningLength +  1, 36), "x","-");
			PropertyID = StrReplace(Mid(Form.CurrentItem.Name, BeginningLength + 38, 36), "x","-");
			
			If StringFunctionsClientServer.IsUUID(Lower(SetID)) Then
				MigrationParameters.Insert("Set", SetID);
			EndIf;
			
			If StringFunctionsClientServer.IsUUID(Lower(PropertyID)) Then
				MigrationParameters.Insert("Property", PropertyID);
			EndIf;
		EndIf;
		
		Notify("GoAdditionalDataAndAttributeSets", MigrationParameters);
	EndIf;
	
EndProcedure

Procedure EditAttributeHyperlink(Form, HyperlinkAction = False, Item = Undefined)
	If Not HyperlinkAction Then
		ButtonName = Form.CurrentItem.Name;
		UniquePart = StrReplace(ButtonName, "Button_", "");
		AttributeName = "AdditionalAttributeValue_" + UniquePart;
	Else
		AttributeName = Item.Name;
		UniquePart = StrReplace(AttributeName, "AdditionalAttributeValue_", "");
	EndIf;
	
	FilterParameters = New Structure;
	FilterParameters.Insert("ValueAttributeName", AttributeName);
	
	AttributesDetails1 = Form.PropertiesAdditionalAttributeDetails.FindRows(FilterParameters);
	If AttributesDetails1.Count() <> 1 Then
		Return;
	EndIf;
	AttributeDetails = AttributesDetails1[0];
	
	If Not AttributeDetails.RefTypeString Then
		Item = Form.Items[AttributeName]; // FormFieldExtensionForLabelField, FormFieldExtensionForInputField
		If Item.Type = FormFieldType.InputField Then
			Item.Type = FormFieldType.LabelField;
			Item.Hyperlink = True;
		Else
			Item.Type = FormFieldType.InputField;
			If AttributeDetails.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues"))
				Or AttributeDetails.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
				ChoiceParameter = ?(ValueIsFilled(AttributeDetails.AdditionalValuesOwner),
					AttributeDetails.AdditionalValuesOwner, AttributeDetails.Property);
				ChoiceParametersArray1 = New Array;
				ChoiceParametersArray1.Add(New ChoiceParameter("Filter.Owner", ChoiceParameter));
				
				Item.ChoiceParameters = New FixedArray(ChoiceParametersArray1);
			EndIf;
		EndIf;
		
		Return;
	EndIf;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("AttributeName", AttributeName);
	OpeningParameters.Insert("ValueType", AttributeDetails.ValueType);
	OpeningParameters.Insert("AttributeDescription", AttributeDetails.Description);
	OpeningParameters.Insert("RefTypeString", AttributeDetails.RefTypeString);
	OpeningParameters.Insert("AttributeValue", Form[AttributeName]);
	OpeningParameters.Insert("ReadOnly", Form.ReadOnly);
	If AttributeDetails.RefTypeString Then
		OpeningParameters.Insert("RefAttributeName", "ReferenceAdditionalAttributeValue" + UniquePart);
	Else
		OpeningParameters.Insert("Property", AttributeDetails.Property);
		OpeningParameters.Insert("AdditionalValuesOwner", AttributeDetails.AdditionalValuesOwner);
	EndIf;
	NotifyDescription = New NotifyDescription("EditAttributeHyperlinkCompletion", PropertyManagerClient, Form);
	OpenForm("CommonForm.EditHyperlink", OpeningParameters,,,,, NotifyDescription);
EndProcedure

Procedure EditAttributeHyperlinkCompletion(Result, AdditionalParameters) Export
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	
	Form = AdditionalParameters;
	Form[Result.AttributeName] = Result.Value;
	If Result.RefTypeString Then
		Form[Result.RefAttributeName] = Result.FormattedString;
	EndIf;
	Form.Modified = True;
EndProcedure

#EndRegion