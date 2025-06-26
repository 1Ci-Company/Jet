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
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "SelectionPick");
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	EndIf;
	
	If Parameters.Filter.Property("Owner") Then
		Property = Parameters.Filter.Owner;
		Parameters.Filter.Delete("Owner");
	EndIf;
	
	If Not ValueIsFilled(Property) Then
		Items.Property.Visible = True;
		SetValuesOrderByProperties(List);
	EndIf;
	
	If Parameters.ChoiceMode Then
		If Parameters.Property("ChoiceFoldersAndItems")
		   And Parameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Folders Then
			
			SelectGroups = True;
			CommonClientServer.SetDynamicListFilterItem(List, "IsFolder", True);
		Else
			Parameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Items;
		EndIf;
	Else
		Items.List.ChoiceMode = False;
	EndIf;
	
	SetHeader();
	
	If SelectGroups Then
		If Items.Find("FormCreate") <> Undefined Then
			Items.FormCreate.Visible = False;
		EndIf;
	EndIf;
	
	OnChangeProperty();
	
	CurrentLanguageSuffix = Common.CurrentUserLanguageSuffix();
	If CurrentLanguageSuffix = Undefined Then
		
		ListProperties = Common.DynamicListPropertiesStructure();
		
		ListProperties.QueryText = StrReplace(List.QueryText, "ValuesOverridable.Description AS Description",
			"CAST(ISNULL(PresentationValues.Description, ValuesOverridable.Description) AS STRING(150)) AS Description");
				
		ListProperties.QueryText = ListProperties.QueryText + "
		|	LEFT JOIN Catalog.ObjectsPropertiesValues.Presentations AS PresentationValues
		|		ON (PresentationValues.Ref = ValuesOverridable.Ref)
		|		AND PresentationValues.LanguageCode = &LanguageCode";
		
		Common.SetDynamicListProperties(Items.List, ListProperties);
		
		CommonClientServer.SetDynamicListParameter(
			List, "LanguageCode", CurrentLanguage().LanguageCode, True);
		
	Else
		
		If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
			ModuleNationalLanguageSupportServer.OnCreateAtServer(ThisObject);
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_AdditionalAttributesAndInfo"
	   And (    Source = Property
	      Or Source = AdditionalValuesOwner) Then
		
		AttachIdleHandler("IdleHandlerOnChangeProperty", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PropertyOnChange(Item)
	
	OnChangeProperty();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	If Not Copy
	   And Items.List.Representation = TableRepresentation.List Then
		
		Parent = Undefined;
	EndIf;
	
	If SelectGroups
	   And Not Var_Group Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	If Items.List.CurrentRow <> Undefined Then
		// Opening a value form or a value set.
		FormParameters = New Structure;
		FormParameters.Insert("HideOwner", True);
		FormParameters.Insert("ShowWeight", AdditionalValuesWithWeight);
		FormParameters.Insert("Key", Items.List.CurrentRow);
		
		OpenForm("Catalog.ObjectsPropertiesValues.ObjectForm", FormParameters, Items.List);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetValuesOrderByProperties(List)
	
	Var Order;
	
	// Order.
	Order = List.SettingsComposer.Settings.Order;
	Order.UserSettingID = "DefaultOrder";
	
	Order.Items.Clear();
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Owner");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("IsFolder");
	OrderItem.OrderType = DataCompositionSortDirection.Desc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Description");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
EndProcedure

&AtServer
Procedure SetHeader()
	
	TitleLine = "";
	
	If ValueIsFilled(Property) Then
		TitleLine = Common.ObjectAttributeValue(
			Property, "ValueChoiceFormTitle",, CurrentLanguage().LanguageCode);
	EndIf;
	
	If IsBlankString(TitleLine) Then
		
		If ValueIsFilled(Property) Then
			If Not Parameters.ChoiceMode Then
				TitleLine = NStr("en = '""%1"" property values';");
			ElsIf SelectGroups Then
				TitleLine = NStr("en = 'Select ""%1"" property values group';");
			Else
				TitleLine = NStr("en = 'Select ""%1"" property value';");
			EndIf;
			
			TitleLine = StringFunctionsClientServer.SubstituteParametersToString(TitleLine,
				String(Common.ObjectAttributeValue(
					Property, "Title")));
		
		ElsIf Parameters.ChoiceMode Then
			
			If SelectGroups Then
				TitleLine = NStr("en = 'Select property value group';");
			Else
				TitleLine = NStr("en = 'Select property value';");
			EndIf;
		EndIf;
	EndIf;
	
	If Not IsBlankString(TitleLine) Then
		AutoTitle = False;
		Title = TitleLine;
	EndIf;
	
EndProcedure

&AtClient
Procedure IdleHandlerOnChangeProperty()
	
	OnChangeProperty();
	
EndProcedure

&AtServer
Procedure OnChangeProperty()
	
	If ValueIsFilled(Property) Then
		
		AdditionalValuesOwner = Common.ObjectAttributeValue(
			Property, "AdditionalValuesOwner");
		
		If ValueIsFilled(AdditionalValuesOwner) Then
			ReadOnly = True;
			
			ValueType = Common.ObjectAttributeValue(
				AdditionalValuesOwner, "ValueType");
			
			CommonClientServer.SetDynamicListFilterItem(
				List, "Owner", AdditionalValuesOwner);
			
			AdditionalValuesWithWeight = Common.ObjectAttributeValue(
				AdditionalValuesOwner, "AdditionalValuesWithWeight");
		Else
			ReadOnly = False;
			ValueType = Common.ObjectAttributeValue(Property, "ValueType");
			
			CommonClientServer.SetDynamicListFilterItem(
				List, "Owner", Property);
			
			AdditionalValuesWithWeight = Common.ObjectAttributeValue(
				Property, "AdditionalValuesWithWeight");
		EndIf;
		
		If TypeOf(ValueType) = Type("TypeDescription")
		   And ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
			
			Items.List.ChangeRowSet = True;
		Else
			Items.List.ChangeRowSet = False;
		EndIf;
		
		Items.List.Representation = TableRepresentation.HierarchicalList;
		Items.Owner.Visible = False;
		Items.Weight.Visible = AdditionalValuesWithWeight;
	Else
		CommonClientServer.DeleteDynamicListFilterGroupItems(
			List, "Owner");
		
		Items.List.Representation = TableRepresentation.List;
		Items.List.ChangeRowSet = False;
		Items.Owner.Visible = True;
		Items.Weight.Visible = False;
	EndIf;
	
	Items.List.Header = Items.Owner.Visible Or Items.Weight.Visible;
	
EndProcedure

#EndRegion
