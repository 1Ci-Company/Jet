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
	
	If ValueIsFilled(Parameters.PropertyKind) Then
		PropertyKind = Parameters.PropertyKind;
		Items.PropertyKind.Visible = False;
		If PropertyKind = Enums.PropertiesKinds.AdditionalAttributes Then
			Var_Key = "AdditionalAttributeSets";
		ElsIf PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
			Var_Key = "AdditionalDataSets";
		ElsIf PropertyKind = Enums.PropertiesKinds.Labels Then
			Var_Key = "LabelsSets";
		EndIf;
	Else
		PropertyKind = Enums.PropertiesKinds.AdditionalAttributes;
		Var_Key = "AdditionalAttributeSets";
	EndIf;
	StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, Var_Key);
	
	FormColor = Items.Properties.BackColor;
	
	ConfigureSetsDisplay();
	ApplySetsAndPropertiesAppearance();
	
	If Not Common.SubsystemExists("StandardSubsystems.DuplicateObjectsDetection") Then
		Items.DuplicateObjectsDetection.Visible = False;
	EndIf;
	
	If Common.IsMobileClient() Then
		Items.PropertiesSets.InitialTreeView = InitialTreeView.ExpandAllLevels;
		Items.PropertiesSets.TitleLocation         = FormItemTitleLocation.Top;
		Items.Properties.TitleLocation              = FormItemTitleLocation.Top;
		Items.PropertiesSubmenuAdd.Representation      = ButtonRepresentation.Picture;
	EndIf;
	
	CurrentLanguageSuffix = Common.CurrentUserLanguageSuffix();
	
	If CurrentLanguageSuffix = Undefined Then
		
		ListProperties = Common.DynamicListPropertiesStructure();
		
		ListProperties.QueryText = StrReplace(PropertiesSets.QueryText, "WHERE",
			"LEFT JOIN Catalog.AdditionalAttributesAndInfoSets.Presentations AS PresentationSets
			|ON (PresentationSets.Ref = SetsOverridable.Ref)
			|AND (PresentationSets.LanguageCode = &LanguageCode)
			|WHERE");
			
		ListProperties.QueryText = StrReplace(ListProperties.QueryText, "SetsOverridable.Description AS Description",
			"SetsOverridable.Description AS Description, PresentationSets.Description AS DescriptionInOtherLanguages");
		
		Common.SetDynamicListProperties(Items.PropertiesSets, ListProperties);
		
		CommonClientServer.SetDynamicListParameter(
			PropertiesSets, "LanguageCode", CurrentLanguage().LanguageCode, True);
		
	ElsIf ValueIsFilled(CurrentLanguageSuffix) Then
		
		If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
			ModuleNationalLanguageSupportServer.OnCreateAtServer(ThisObject,, "PropertiesSets");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_AdditionalAttributesAndInfo"
	 Or EventName = "Write_ObjectsPropertiesValues"
	 Or EventName = "Write_ObjectPropertyValueHierarchy" Then
		
		// When writing a property, move it to the matching group.
		// When writing a value, update the first 3 values in the list.
		OnChangeCurrentSetAtServer();
		
	ElsIf EventName = "GoAdditionalDataAndAttributeSets" Then
		// When opening a metadata object property editor, open the object's set (group of sets).
		// 
		If TypeOf(Parameter) = Type("Structure") Then
			SelectSpecifiedRows(Parameter);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PropertyKindOnChange(Item)
	
	ConfigureSetsDisplay();
	ApplySetsAndPropertiesAppearance();
	
EndProcedure

&AtClient
Procedure ShowUnusedAttributesOnChange(Item)
	SwitchSetsList();
	OnChangeCurrentSet();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPropertiesSets

&AtClient
Procedure PropertiesSetsOnActivateRow(Item)
	
	AttachIdleHandler("OnChangeCurrentSet", 0.1, True);
	
EndProcedure

&AtClient
Procedure PropertiesSetsBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertiesSetsDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
	
	If String = Undefined Then
		Return;
	EndIf;
	
	If Items.PropertiesSets.RowData(String).IsFolder Then
		DragParameters.Action = DragAction.Cancel;
	EndIf;
	
EndProcedure

&AtClient
Procedure PropertiesSetsDrag(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
	
	If DragParameters.Value.CommonValues Then
		ItemToDrag = DragParameters.Value.AdditionalValuesOwner;
	Else
		ItemToDrag = DragParameters.Value.Property;
	EndIf;
	
	If TypeOf(ItemToDrag) <> Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo") Then
		Return;
	EndIf;
	
	DestinationSet = String;
	AddAttributeToSet(ItemToDrag, String);
EndProcedure

&AtServerNoContext
Procedure PropertiesSetsOnGetDataAtServer(TagName, Settings, Rows)
	
	For Each DynamicListRow In Rows Do
		Data = DynamicListRow.Value.Data;
		If Data.IsFolder Then
			Data.Presentation = String(Data.Ref);
			Continue;
		EndIf;
		
		If Data.PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
			If Not ValueIsFilled(Data.InfoCount) Then
				Data.Presentation = String(Data.Ref);
				Continue;
			EndIf;
			If Data.Property("DescriptionInOtherLanguages") And ValueIsFilled(Data.DescriptionInOtherLanguages) Then
				Data.Presentation = Data.DescriptionInOtherLanguages + " (" + Data.InfoCount + ")";
				Continue;
			EndIf;
			Data.Presentation = String(Data.Ref) + " (" + Data.InfoCount + ")";
		ElsIf Data.PropertyKind = Enums.PropertiesKinds.AdditionalAttributes Then
			If Not ValueIsFilled(Data.AttributesCount) Then
				Data.Presentation = String(Data.Ref);
				Continue;
			EndIf;
			If Data.Property("DescriptionInOtherLanguages") And ValueIsFilled(Data.DescriptionInOtherLanguages) Then 
				Data.Presentation = Data.DescriptionInOtherLanguages + " (" + Data.AttributesCount + ")";
				Continue;
			EndIf;
			Data.Presentation = String(Data.Ref) + " (" + Data.AttributesCount + ")";
		ElsIf Data.PropertyKind = Enums.PropertiesKinds.Labels Then
			If Not ValueIsFilled(Data.LabelCount) Then
				Data.Presentation = String(Data.Ref);
				Continue;
			EndIf;
			If Data.Property("DescriptionInOtherLanguages") And ValueIsFilled(Data.DescriptionInOtherLanguages) Then 
				Data.Presentation = Data.DescriptionInOtherLanguages + " (" + Data.AttributesCount + ")";
				Continue;
			EndIf;
			Data.Presentation = String(Data.Ref) + " (" + Data.LabelCount + ")";
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersProperties

&AtClient
Procedure PropertiesOnActivateRow(Item)
	
	PropertiesSetCommandAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure PropertiesBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	If Copy Then
		Copy();
	Else
		Create();
	EndIf;
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertiesBeforeRowChange(Item, Cancel)
	
	Change();
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertiesBeforeDeleteRow(Item, Cancel)
	
	ChangeDeletionMark();
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertiesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(ValueSelected) = Type("Structure") Then
		If ValueSelected.Property("AdditionalValuesOwner") Then
			
			FormParameters = New Structure;
			FormParameters.Insert("PropertyKind", PropertyKind);
			FormParameters.Insert("CurrentPropertiesSet",            Current_Set);
			FormParameters.Insert("AdditionalValuesOwner", ValueSelected.AdditionalValuesOwner);
			
			OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
				FormParameters, Items.Properties);
			
		ElsIf ValueSelected.Property("CommonProperty") Then
			
			ChangedSet = Current_Set;
			If ValueSelected.Property("Drag") Then
				AddCommonPropertyByDragging(ValueSelected.CommonProperty);
			Else
				ExecuteCommandAtServer("AddCommonProperty", ValueSelected.CommonProperty);
				ChangedSet = DestinationSet;
			EndIf;
			
			Notify("Write_AdditionalAttributesAndInfoSets",
				New Structure("Ref", ChangedSet), ChangedSet);
		Else
			SelectSpecifiedRows(ValueSelected);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure PropertiesDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure PropertiesDragStart(Item, DragParameters, Perform)
	// Properties and attributes cannot be moved, only copied.
	// Make sure the cursor icon reflects this.
	DragParameters.AllowedActions = DragAllowedActions.Copy;
	DragParameters.Action           = DragAction.Copy;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Create(Command = Undefined)
	
	FormParameters = New Structure;
	FormParameters.Insert("PropertiesSet", Current_Set);
	FormParameters.Insert("PropertyKind", PropertyKind);
	FormParameters.Insert("CurrentPropertiesSet", Current_Set);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
		FormParameters, Items.Properties);
	
EndProcedure

&AtClient
Procedure AddFromSet(Command)
	
	FormParameters = New Structure;
	
	SelectedValues = New Array;
	CommonProperties = Properties.FindRows(New Structure("Common", True));
	For Each Property In CommonProperties Do
		SelectedValues.Add(Property.Property);
	EndDo;
	
	If Not ValueIsFilled(PropertyKind) Then
		FormParameters.Insert("SelectSharedProperty", True);
	Else
		FormParameters.Insert("SelectAdditionalValuesOwner", True);
	EndIf;
	
	FormParameters.Insert("SelectedValues", SelectedValues);
	FormParameters.Insert("PropertyKind", PropertyKind);
	FormParameters.Insert("CurrentPropertiesSet", Current_Set);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
		FormParameters, Items.Properties);
EndProcedure

&AtClient
Procedure Change(Command = Undefined)
	
	If Items.Properties.CurrentData <> Undefined Then
		// Open the property form.
		FormParameters = New Structure;
		FormParameters.Insert("Key", Items.Properties.CurrentData.Property);
		FormParameters.Insert("CurrentPropertiesSet", Current_Set);
		
		OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
			FormParameters, Items.Properties);
	EndIf;
	
EndProcedure

&AtClient
Procedure Copy(Command = Undefined, PasteFromClipboard2 = False)
	
	FormParameters = New Structure;
	CopyingValue = Items.Properties.CurrentData.Property;
	FormParameters.Insert("AdditionalValuesOwner", CopyingValue);
	FormParameters.Insert("CurrentPropertiesSet", Current_Set);
	FormParameters.Insert("CopyingValue", CopyingValue);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm", FormParameters);
	
EndProcedure

&AtClient
Procedure AddAttributeToSet(AdditionalValuesOwner, Set = Undefined)
	
	FormParameters = New Structure;
	If Set = Undefined Then
		CurrentPropertiesSet = Current_Set;
	Else
		CurrentPropertiesSet = Set;
		FormParameters.Insert("Drag", True);
	EndIf;
	
	FormParameters.Insert("CopyWithQuestion", True);
	FormParameters.Insert("AdditionalValuesOwner", AdditionalValuesOwner);
	FormParameters.Insert("PropertyKind", PropertyKind);
	FormParameters.Insert("CurrentPropertiesSet", CurrentPropertiesSet);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm", FormParameters, Items.Properties);
	
EndProcedure

&AtClient
Procedure MarkToDelete(Command)
	
	ChangeDeletionMark();
	
EndProcedure

&AtClient
Procedure MoveUp(Command)
	
	ExecuteCommandAtServer("MoveUp");
	
EndProcedure

&AtClient
Procedure MoveDown(Command)
	
	ExecuteCommandAtServer("MoveDown");
	
EndProcedure

&AtClient
Procedure DuplicateObjectsDetection(Command)
	ModuleDuplicateObjectsDetectionClient = CommonClient.CommonModule("DuplicateObjectsDetectionClient");
	DuplicateObjectsDetectionFormName = ModuleDuplicateObjectsDetectionClient.DuplicateObjectsDetectionDataProcessorFormName();
	OpenForm(DuplicateObjectsDetectionFormName);
EndProcedure

&AtClient
Procedure CopySelectedAttribute(Command)
	AttributeToCopy = New Structure;
	AttributeToCopy.Insert("AttributeToCopy", Items.Properties.CurrentData.Property);
	AttributeToCopy.Insert("CommonValues", Items.Properties.CurrentData.CommonValues);
	AttributeToCopy.Insert("AdditionalValuesOwner", Items.Properties.CurrentData.AdditionalValuesOwner);
	
	Items.PasteAttribute.Enabled = Not ShowUnusedAttributes;
EndProcedure

&AtClient
Procedure PasteAttribute(Command)
	If AttributeToCopy.CommonValues Then
		AdditionalValuesOwner = AttributeToCopy.AdditionalValuesOwner;
	Else
		AdditionalValuesOwner = AttributeToCopy.AttributeToCopy;
	EndIf;
	
	AddAttributeToSet(AdditionalValuesOwner);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure ApplySetsAndPropertiesAppearance()
	
	PropertiesSets.ConditionalAppearance.Items.Clear();
	
	// Appearance of the sets root.
	ConditionalAppearanceItem = PropertiesSets.ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Text");
	AppearanceColorItem.Value = NStr("en = 'Sets';");
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Ref");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use  = True;
	
	AppearanceFieldItem = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceFieldItem.Field = New DataCompositionField("Presentation");
	AppearanceFieldItem.Use = True;
	
	// Appearance of unavailable set groups that by default are displayed by the platform as a part of group tree.
	ConditionalAppearanceItem = PropertiesSets.ConditionalAppearance.Items.Add();
	
	VisibilityItem = ConditionalAppearanceItem.Appearance.Items.Find("Visible");
	VisibilityItem.Value = False;
	VisibilityItem.Use = True;
	
	DataFilterItemsGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	DataFilterItemsGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	DataFilterItemsGroup.Use = True;
	
	DataFilterItem = DataFilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Ref");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.NotInList;
	DataFilterItem.RightValue = AvailableSetsList;
	DataFilterItem.Use  = True;
	
	DataFilterItem = DataFilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Parent");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.NotInList;
	DataFilterItem.RightValue = AvailableSetsList;
	DataFilterItem.Use  = True;
	
	DataFilterItem = DataFilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Ref");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Filled;
	DataFilterItem.Use  = True;
	
	AppearanceFieldItem = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceFieldItem.Field = New DataCompositionField("Presentation");
	AppearanceFieldItem.Use = True;
	
	ConditionalAppearance.Items.Clear();
	
	// Configuring required properties.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Font");
	AppearanceColorItem.Value = StyleFonts.MainListItem;
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Properties.RequiredToFill");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use  = True;
	
	AppearanceFieldItem = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceFieldItem.Field = New DataCompositionField("PropertiesTitle");
	AppearanceFieldItem.Use = True;
	
	// Configuring required properties.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	VisibilityItem = ConditionalAppearanceItem.Appearance.Items.Find("Visible");
	VisibilityItem.Value = False;
	VisibilityItem.Use = True; 
	
	DataFilterItemsGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	DataFilterItemsGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	DataFilterItemsGroup.Use = True;
	
	DataFilterItem = DataFilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("FieldForSearch");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Filled;
	DataFilterItem.Use  = True;
	
	DataFilterItem = DataFilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("PropertiesSets.Presentation");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.NotContains;
	DataFilterItem.RightValue = New DataCompositionField("FieldForSearch");
	DataFilterItem.Use  = True; 
	
	AppearanceFieldItem = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceFieldItem.Field = New DataCompositionField("Presentation");
	AppearanceFieldItem.Use = True;
	
EndProcedure

&AtClient
Procedure SelectSpecifiedRows(LongDesc)
	
	If LongDesc.Property("Set") Then
		
		If TypeOf(LongDesc.Set) = Type("String") Then
			ConvertStringsToReferences(LongDesc);
		EndIf;
		
		If LongDesc.PropertyKind <> PropertyKind Then
			PropertyKind = LongDesc.PropertyKind;
			ConfigureSetsDisplay();
		EndIf;
		
		Items.PropertiesSets.CurrentRow = LongDesc.Set;
		Current_Set = Undefined;
		OnChangeCurrentSet();
		FoundRows = Properties.FindRows(New Structure("Property", LongDesc.Property));
		If FoundRows.Count() > 0 Then
			Items.Properties.CurrentRow = FoundRows[0].GetID();
		Else
			Items.Properties.CurrentRow = Undefined;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SwitchSetsList()
	
	If Not ShowUnusedAttributes Then
		Items.SetsPages.CurrentPage = Items.Main;
		Return;
	EndIf;
	
	Items.SetsPages.CurrentPage = Items.Unused;
	
	ListPresentation = "";
	If PropertyKind = PredefinedValue("Enum.PropertiesKinds.AdditionalInfo") Then
		ListPresentation = NStr("en = 'Unused additional information records';");
	ElsIf PropertyKind = PredefinedValue("Enum.PropertiesKinds.AdditionalAttributes") Then
		ListPresentation = NStr("en = 'Unused additional attributes';");
	ElsIf PropertyKind = PredefinedValue("Enum.PropertiesKinds.Labels") Then
		ListPresentation = NStr("en = 'Unused labels';");
	EndIf;
	
	CommonClientServer.SetDynamicListParameter(
		UnusedSets, "ListPresentation", ListPresentation, True);
	
EndProcedure

&AtServerNoContext
Procedure ConvertStringsToReferences(LongDesc)
	
	LongDesc.Insert("Set", Catalogs.AdditionalAttributesAndInfoSets.GetRef(
		New UUID(LongDesc.Set)));
	
	LongDesc.Insert("Property", ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.GetRef(
		New UUID(LongDesc.Property)));
	
EndProcedure

&AtServer
Procedure ConfigureSetsDisplay()
	
	CreateButton            = Items.PropertiesCreate;
	ButtonCreateContext = Items.PropertiesContextMenuCreate;
	CreateCommand                      = Commands.Find("Create");
	CopyCommand                  = Commands.Find("Copy");
	ChangeCommand                     = Commands.Find("Change");
	MarkForDeletionCommand           = Commands.Find("MarkToDelete");
	MoveUpCommand             = Commands.Find("MoveUp");
	MoveDownCommand              = Commands.Find("MoveDown");
	
	If PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
		Title = NStr("en = 'Additional information records';");
		
		CreateButton.Title          = NStr("en = 'New item';");
		ButtonCreateContext.Title = NStr("en = 'New item';");
		CreateCommand.ToolTip         = NStr("en = 'Create a unique information record.';");
		
		CopyCommand.ToolTip        = NStr("en = 'Create an information record by copying the current one.';");
		ChangeCommand.ToolTip           = NStr("en = 'Change or open the information record.';");
		MarkForDeletionCommand.ToolTip = NStr("en = 'Mark the information record for deletion (Del).';");
		MoveUpCommand.ToolTip   = NStr("en = 'Move the information record up the list.';");
		MoveDownCommand.ToolTip    = NStr("en = 'Move the information record down the list.';");
		
		MetadataTabularSection =
			Metadata.Catalogs.AdditionalAttributesAndInfoSets.TabularSections.AdditionalInfo;
		
		Items.PropertiesTitle.ToolTip = MetadataTabularSection.Attributes.Property.Tooltip;
		
		Items.PropertiesRequiredToFill.Visible = False;
		
		Items.PropertiesValueType.ToolTip =
			NStr("en = 'Available information record value types.';");
		
		Items.PropertiesCommonValues.ToolTip =
			NStr("en = 'The information record inherits the master record''s list of values.';");
		
		Items.ShowUnusedAttributes.Title = NStr("en = 'Show unused information records';");
		
		Items.PropertiesCommon.Title = NStr("en = 'Shared';");
		Items.PropertiesCommon.ToolTip = NStr("en = 'A shared additional information record.
		                                              |It belongs to multiple sets.';");
	ElsIf PropertyKind = Enums.PropertiesKinds.Labels Then
		Title = NStr("en = 'Labels';");
		CreateButton.Title            = NStr("en = 'New item';");
		ButtonCreateContext.Title = NStr("en = 'New item';");
		CreateCommand.ToolTip          = NStr("en = 'Create a unique label';");
		
		CopyCommand.ToolTip        = NStr("en = 'Create a new label by copying the current label';");
		ChangeCommand.ToolTip           = NStr("en = 'Edit or open the current label';");
		MarkForDeletionCommand.ToolTip = NStr("en = 'Mark the current label for deletion (Del)';");
		MoveUpCommand.ToolTip   = NStr("en = 'Move the current label up';");
		MoveDownCommand.ToolTip    = NStr("en = 'Move the current label down';");
		
		MetadataTabularSection =
			Metadata.Catalogs.AdditionalAttributesAndInfoSets.TabularSections.AdditionalAttributes;
		
		Items.PropertiesTitle.ToolTip = MetadataTabularSection.Attributes.Property.Tooltip;
		
		Items.PropertiesRequiredToFill.Visible = True;
		Items.PropertiesRequiredToFill.ToolTip =
			Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.Attributes.RequiredToFill.Tooltip;
		
		Items.PropertiesValueType.ToolTip =
			NStr("en = 'Types of a value that you can enter when filling a label.';");
		
		Items.PropertiesCommonValues.ToolTip =
			NStr("en = 'The label uses the list of master label values.';");
		
		Items.ShowUnusedAttributes.Title = NStr("en = 'Show unused labels';");
		
		Items.PropertiesCommon.Title = NStr("en = 'Common';");
		Items.PropertiesCommon.ToolTip = NStr("en = 'A common label that is used in
		                                              |several label sets.';");
		Items.Properties.Header = False;
		Items.PropertiesValueType.Visible = False;
	Else
		Title = NStr("en = 'Additional attributes';");
		CreateButton.Title            = NStr("en = 'New item';");
		ButtonCreateContext.Title = NStr("en = 'New item';");
		CreateCommand.ToolTip          = NStr("en = 'Create a unique attribute.';");
		
		CopyCommand.ToolTip        = NStr("en = 'Create an attribute by copying the current one.';");
		ChangeCommand.ToolTip           = NStr("en = 'Change or open the attribute.';");
		MarkForDeletionCommand.ToolTip = NStr("en = 'Mark the attribute for deletion (Del).';");
		MoveUpCommand.ToolTip   = NStr("en = 'Move the attribute up the list.';");
		MoveDownCommand.ToolTip    = NStr("en = 'Move the attribute down the list.';");
		
		MetadataTabularSection =
			Metadata.Catalogs.AdditionalAttributesAndInfoSets.TabularSections.AdditionalAttributes;
		
		Items.PropertiesTitle.ToolTip = MetadataTabularSection.Attributes.Property.Tooltip;
		
		Items.PropertiesRequiredToFill.Visible = True;
		Items.PropertiesRequiredToFill.ToolTip =
			Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.Attributes.RequiredToFill.Tooltip;
		
		Items.PropertiesValueType.ToolTip =
			NStr("en = 'Available attribute value types.';");
		
		Items.PropertiesCommonValues.ToolTip =
			NStr("en = 'The attribute inherits the master attribute''s list of values.';");
		
		Items.ShowUnusedAttributes.Title = NStr("en = 'Show unused attributes';");
		
		Items.PropertiesCommon.Title = NStr("en = 'Shared';");
		Items.PropertiesCommon.ToolTip = NStr("en = 'A shared additional attribute.
		                                              |It belongs to multiple sets.';");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Sets.Ref AS Ref,
	|	Sets.DeletionMark AS DeletionMark,
	|	Sets.Predefined AS Predefined,
	|	Sets.IsFolder AS IsFolder,
	|	Sets.Parent AS Parent,
	|	Sets.PredefinedDataName AS PredefinedDataName,
	|	Sets.PredefinedSetName AS PredefinedSetName
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets AS Sets
	|WHERE
	|	Sets.Parent = VALUE(Catalog.AdditionalAttributesAndInfoSets.EmptyRef)";
	
	Sets = Query.Execute().Unload();
	AvailableSets = New Array;
	AvailableSetsList.Clear();
	
	SetProperties = New Structure;
	SetProperties.Insert("DeletionMark");
	SetProperties.Insert("Predefined");
	SetProperties.Insert("IsFolder");
	SetProperties.Insert("Parent");
	SetProperties.Insert("PredefinedDataName");
	SetProperties.Insert("PredefinedSetName");
	
	For Each TableRow In Sets Do
		If StrStartsWith(TableRow.PredefinedDataName, "Delete") Then
			Continue;
		EndIf;
		
		FillPropertyValues(SetProperties, TableRow);
		
		SetPropertiesTypes = PropertyManagerInternal.SetPropertiesTypes(SetProperties, False);
		
		If PropertyKind = Enums.PropertiesKinds.AdditionalInfo And SetPropertiesTypes.AdditionalInfo
			Or PropertyKind = Enums.PropertiesKinds.AdditionalAttributes And SetPropertiesTypes.AdditionalAttributes
			Or PropertyKind = Enums.PropertiesKinds.Labels And SetPropertiesTypes.Labels Then
			AvailableSets.Add(TableRow.Ref);
			AvailableSetsList.Add(TableRow.Ref);
		EndIf;
	EndDo;
	
	CommonClientServer.SetDynamicListParameter(
		PropertiesSets, "PropertyKind", PropertyKind, True);
	
	CommonClientServer.SetDynamicListParameter(
		PropertiesSets, "Sets", AvailableSets, True);
	
	CommonClientServer.SetDynamicListParameter(
		PropertiesSets, "LanguageCode", CurrentLanguage().LanguageCode, True);
	
	OnChangeCurrentSetAtServer();
	
EndProcedure
	
&AtClient
Procedure OnChangeCurrentSet()
	
	If ShowUnusedAttributes Then
		Current_Set = Undefined;
		OnChangeCurrentSetAtServer();
	ElsIf Items.PropertiesSets.CurrentData = Undefined Then
		If ValueIsFilled(Current_Set) Then
			Current_Set = Undefined;
			OnChangeCurrentSetAtServer();
		EndIf;
		
	ElsIf Items.PropertiesSets.CurrentData.Ref <> Current_Set Then
		Current_Set          = Items.PropertiesSets.CurrentData.Ref;
		CurrentSetIsFolder = Items.PropertiesSets.CurrentData.IsFolder;
		OnChangeCurrentSetAtServer();
	EndIf;
	
#If MobileClient Then
	CurrentItem = Items.Properties;
	If Not ImportanceConfigured Then
		Items.PropertiesSets.DisplayImportance = DisplayImportance.VeryLow;
		ImportanceConfigured = True;
	EndIf;
	Items.Properties.Title = String(Current_Set);
#EndIf
	
EndProcedure

&AtClient
Procedure ChangeDeletionMark()
	
	If Items.Properties.CurrentData <> Undefined Then
		
		If PropertyKind = PredefinedValue("Enum.PropertiesKinds.AdditionalInfo") Then
			If Not ShowUnusedAttributes Then
				QueryText = NStr("en = 'Do you want to remove the information record from the set?';");
				
			ElsIf Items.Properties.CurrentData.DeletionMark Then
				QueryText = NStr("en = 'Do you want to clear the deletion mark from the information record?';");
			Else
				QueryText = NStr("en = 'Do you want to mark the information record for deletion?';");
			EndIf;
		ElsIf PropertyKind = PredefinedValue("Enum.PropertiesKinds.AdditionalAttributes") Then
			If Not ShowUnusedAttributes Then
				QueryText = NStr("en = 'Do you want to remove the attribute from the set?';");
				
			ElsIf Items.Properties.CurrentData.DeletionMark Then
				QueryText = NStr("en = 'Do you want to clear the deletion mark from the attribute?';");
			Else
				QueryText = NStr("en = 'Do you want to mark the attribute for deletion?';");
			EndIf;
		ElsIf PropertyKind = PredefinedValue("Enum.PropertiesKinds.Labels") Then
			If Not ShowUnusedAttributes Then
				QueryText = NStr("en = 'Do you want to remove the label from the set?';");
				
			ElsIf Items.Properties.CurrentData.DeletionMark Then
				QueryText = NStr("en = 'Do you want to unmark the label for deletion?';");
			Else
				QueryText = NStr("en = 'Do you want to mark the label for deletion?';");
			EndIf;
		EndIf;
		
		ShowQueryBox(
			New NotifyDescription("ChangeDeletionMarkCompletion", ThisObject, Current_Set),
			QueryText, QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeDeletionMarkCompletion(Response, Current_Set) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ExecuteCommandAtServer("ChangeDeletionMark");
	
	Notify("Write_AdditionalAttributesAndInfoSets",
		New Structure("Ref", Current_Set), Current_Set);
	
EndProcedure

&AtServer
Procedure OnChangeCurrentSetAtServer()
	
	If ValueIsFilled(Current_Set)
	   And Not CurrentSetIsFolder
	   Or ShowUnusedAttributes Then
		
		CurrentEnable = True;
		If Items.Properties.BackColor <> Items.PropertiesSets.BackColor Then
			Items.Properties.BackColor = Items.PropertiesSets.BackColor;
		EndIf;
		PropertyManagerInternal.UpdateCurrentSetPropertiesList(ThisObject, 
			Current_Set,
			PropertyKind,
			CurrentEnable);
	Else
		CurrentEnable = False;
		If Items.Properties.BackColor <> FormColor Then
			Items.Properties.BackColor = FormColor;
		EndIf;
		Properties.Clear();
	EndIf;
	
	If Items.Properties.ReadOnly = CurrentEnable Then
		Items.Properties.ReadOnly = Not CurrentEnable;
	EndIf;
	
	PropertiesSetCommandAvailability(ThisObject);
	
	Items.PropertiesSets.Refresh();
	
EndProcedure

&AtClientAtServerNoContext
Procedure PropertiesSetCommandAvailability(Context)
	
	Items = Context.Items;
	ShowUnusedAttributes = Context.ShowUnusedAttributes;
	
	CommonAvailability = Not Items.Properties.ReadOnly;
	InsertAvailability = CommonAvailability And (Context.AttributeToCopy <> Undefined);
	
	AvailabilityForString = CommonAvailability
		And Context.Items.Properties.CurrentRow <> Undefined;
	
	CommonAvailability = CommonAvailability And Not ShowUnusedAttributes;
	
	// Customizing commands of command bar.
	Items.AddFromSet.Enabled           = CommonAvailability;
	Items.PropertiesCreate.Enabled            = CommonAvailability;
	
	Items.PropertiesCopy.Enabled        = AvailabilityForString And Not ShowUnusedAttributes;
	Items.PropertiesEdit.Enabled           = AvailabilityForString;
	Items.PropertiesMarkForDeletion.Enabled = AvailabilityForString;
	
	Items.PropertiesMoveUp.Enabled   = AvailabilityForString;
	Items.PropertiesMoveDown.Enabled    = AvailabilityForString;
	
	Items.CopyAttribute.Enabled         = AvailabilityForString;
	Items.PasteAttribute.Enabled           = InsertAvailability And Not ShowUnusedAttributes;
	
	// Customizing commands of context menu.
	Items.PropertiesContextMenuCreate.Enabled            = CommonAvailability;
	Items.PropertiesContextMenuAddFromSet.Enabled   = CommonAvailability;
	
	Items.PropertiesContextMenuCopy.Enabled        = AvailabilityForString And Not ShowUnusedAttributes;
	Items.PropertiesContextMenuChange.Enabled           = AvailabilityForString;
	Items.PropertiesContextMenuMarkToDelete.Enabled = AvailabilityForString;
	
	Items.PropertiesContextMenuCopyAttribute.Enabled = AvailabilityForString;
	Items.PropertiesContextMenuPasteAttribute.Enabled   = InsertAvailability And Not ShowUnusedAttributes;
	
EndProcedure

&AtServer
Procedure AddCommonPropertyByDragging(PropertyToAdd)
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.AdditionalAttributesAndInfoSets");
	LockItem.SetValue("Ref", DestinationSet);
	
	Try
		LockDataForEdit(DestinationSet);
		BeginTransaction();
		Try
			Block.Lock();
			LockDataForEdit(DestinationSet);
			
			SetDestinationObject = DestinationSet.GetObject();
			
			If PropertyKind = Enums.PropertiesKinds.AdditionalAttributes
				Or PropertyKind = Enums.PropertiesKinds.Labels Then
				PropertiesKindName = "AdditionalAttributes"; 
			ElsIf PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
				PropertiesKindName = "AdditionalInfo";
			EndIf;
			TabularSection = SetDestinationObject[PropertiesKindName];
			
			FoundRow = TabularSection.Find(PropertyToAdd, "Property");
			
			If FoundRow = Undefined Then
				NewRow = TabularSection.Add();
				NewRow.Property = PropertyToAdd;
				SetDestinationObject.Write();
				
			ElsIf FoundRow.DeletionMark Then
				FoundRow.DeletionMark = False;
				SetDestinationObject.Write();
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	Except
		UnlockDataForEdit(DestinationSet);
		Raise;
	EndTry;
	
	Items.PropertiesSets.Refresh();
	DestinationSet = Undefined;
	
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(Command, Parameter = Undefined)
	
	Block = New DataLock;
	
	If Command = "ChangeDeletionMark" Then
		LockItem = Block.Add("Catalog.AdditionalAttributesAndInfoSets");
		LockItem = Block.Add("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo");
		LockItem = Block.Add("Catalog.ObjectsPropertiesValues");
		LockItem = Block.Add("Catalog.ObjectPropertyValueHierarchy");
	Else
		LockItem = Block.Add("Catalog.AdditionalAttributesAndInfoSets");
		LockItem.SetValue("Ref", Current_Set);
	EndIf;
	
	If ShowUnusedAttributes Then
		BeginTransaction();
		Try
			Block.Lock();
			
			String = Properties.FindByID(Items.Properties.CurrentRow);
			ChangeDeletionMarkAndValuesOwner(String.Property, Undefined);
			OnChangeCurrentSetAtServer();
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		Return;
	EndIf;
	
	Try
		LockDataForEdit(Current_Set);
		BeginTransaction();
		Try
			Block.Lock();
			LockDataForEdit(Current_Set);
			
			CurrentSetObject = Current_Set.GetObject();
			If CurrentSetObject.DataVersion <> CurrentSetDataVersion Then
				OnChangeCurrentSetAtServer();
				If PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
					Raise
						NStr("en = 'The action is not performed as the set of information records
						           |has been changed by another user.
						           |The new set of additional information records has been read.
						           |
						           |Please try again if required.';");
				ElsIf PropertyKind = Enums.PropertiesKinds.AdditionalAttributes Then
					Raise
						NStr("en = 'The action is not performed as the set of additional attributes
						           |has been changed by another user.
						           |The new set of additional attributes has been read.
						           |
						           |Please try again if required.';");
				ElsIf PropertyKind = Enums.PropertiesKinds.Labels Then
					Raise
						NStr("en = 'The action is not performed as the set of labels
						           |has been changed by another user.
						           |The new set of labels has been read.
						           |
						           |Please try again if required.';");
				EndIf;
			EndIf;
			
			If PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
				PropertiesKindName = "AdditionalInfo";
			Else
				PropertiesKindName = "AdditionalAttributes";
			EndIf;
			TabularSection = CurrentSetObject[PropertiesKindName];
			
			If Command = "AddCommonProperty" Then
				FoundRow = TabularSection.Find(Parameter, "Property");
				
				If FoundRow = Undefined Then
					NewRow = TabularSection.Add();
					NewRow.Property = Parameter;
					CurrentSetObject.Write();
					
				ElsIf FoundRow.DeletionMark Then
					FoundRow.DeletionMark = False;
					CurrentSetObject.Write();
				EndIf;
			Else
				String = Properties.FindByID(Items.Properties.CurrentRow);
				
				If String <> Undefined Then
					IndexOf = String.LineNumber-1;
					
					If Command = "MoveUp" Then
						TopRowIndex = Properties.IndexOf(String)-1;
						If TopRowIndex >= 0 Then
							Move = Properties[TopRowIndex].LineNumber - String.LineNumber;
							TabularSection.Move(IndexOf, Move);
						EndIf;
						CurrentSetObject.Write();
						
					ElsIf Command = "MoveDown" Then
						BottomRowIndex = Properties.IndexOf(String)+1;
						If BottomRowIndex < Properties.Count() Then
							Move = Properties[BottomRowIndex].LineNumber - String.LineNumber;
							TabularSection.Move(IndexOf, Move);
						EndIf;
						CurrentSetObject.Write();
						
					ElsIf Command = "ChangeDeletionMark" Then
						String = Properties.FindByID(Items.Properties.CurrentRow);
						
						If String.Common Then
							TabularSection.Delete(IndexOf);
							CurrentSetObject.Write();
							Properties.Delete(String);
						Else
							TabularSection[IndexOf].DeletionMark = Not TabularSection[IndexOf].DeletionMark;
							CurrentSetObject.Write();
							
							ChangeDeletionMarkAndValuesOwner(
								TabularSection[IndexOf].Property,
								TabularSection[IndexOf].DeletionMark);
						EndIf;
					EndIf;
				EndIf;
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	Except
		UnlockDataForEdit(Current_Set);
		Raise;
	EndTry;
	
	OnChangeCurrentSetAtServer();
	
EndProcedure

&AtServer
Procedure ChangeDeletionMarkAndValuesOwner(CurrentProperty, PropertyDeletionMark)
	
	// ACC:1328-off - A lock is set higher up in the stack.
	// ACC:1327-off - A lock is set higher up in the stack.
	OldValuesOwner = CurrentProperty;
	
	NewValuesMark   = Undefined;
	NewValuesOwner  = Undefined;
	
	ObjectProperty = CurrentProperty.GetObject();
	
	If PropertyDeletionMark = Undefined Then
		PropertyDeletionMark = Not ObjectProperty.DeletionMark;
	EndIf;
	
	If PropertyDeletionMark Then
		// When marking a unique property for deletion:
		// - Mark the property itself.
		// - If there are clones not marked for deletion,
		//   set a new value owner and assign a new original property to the clones.
		//   Alternatively, mark the original and the cloned properties for deletion.
		//   
		ObjectProperty.DeletionMark = True;
		
		If Not ValueIsFilled(ObjectProperty.AdditionalValuesOwner) Then
			Query = New Query;
			Query.SetParameter("Property", ObjectProperty.Ref);
			Query.Text =
			"SELECT
			|	Properties.Ref,
			|	Properties.DeletionMark
			|FROM
			|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
			|WHERE
			|	Properties.AdditionalValuesOwner = &Property";
			Upload0 = Query.Execute().Unload();
			FoundRow = Upload0.Find(False, "DeletionMark");
			If FoundRow <> Undefined Then
				NewValuesOwner  = FoundRow.Ref;
				ObjectProperty.AdditionalValuesOwner = NewValuesOwner;
				For Each TableRow In Upload0 Do
					CurrentObject = TableRow.Ref.GetObject();
					If CurrentObject.Ref = NewValuesOwner Then
						CurrentObject.AdditionalValuesOwner = Undefined;
					Else
						CurrentObject.AdditionalValuesOwner = NewValuesOwner;
					EndIf;
					CurrentObject.Write();
				EndDo;
			Else
				NewValuesMark = True;
			EndIf;
		EndIf;
		ObjectProperty.Write();
	Else
		If ObjectProperty.DeletionMark Then
			ObjectProperty.DeletionMark = False;
			ObjectProperty.Write();
		EndIf;
		// When clearing the deletion mark from a unique property:
		// - Clear the deletion mark from the property itself.
		// - If it was cloned and the clones are marked for deletion,
		//   set a new (current) value owner for all properties
		//     and clear the deletion mark from the values.
		//     Alternatively, clear the deletion mark from the values.
		//   
		If Not ValueIsFilled(ObjectProperty.AdditionalValuesOwner) Then
			NewValuesMark = False;
			
		ElsIf Common.ObjectAttributeValue(
		            ObjectProperty.AdditionalValuesOwner, "DeletionMark") Then
			
			Query = New Query;
			Query.SetParameter("Property", ObjectProperty.AdditionalValuesOwner);
			Query.Text =
			"SELECT
			|	Properties.Ref AS Ref
			|FROM
			|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
			|WHERE
			|	Properties.AdditionalValuesOwner = &Property";
			Array = Query.Execute().Unload().UnloadColumn("Ref");
			Array.Add(ObjectProperty.AdditionalValuesOwner);
			NewValuesOwner = ObjectProperty.Ref;
			For Each CurrentRef In Array Do
				If CurrentRef = NewValuesOwner Then
					Continue;
				EndIf;
				CurrentObject = CurrentRef.GetObject();
				CurrentObject.AdditionalValuesOwner = NewValuesOwner;
				CurrentObject.Write();
			EndDo;
			OldValuesOwner = ObjectProperty.AdditionalValuesOwner;
			ObjectProperty.AdditionalValuesOwner = Undefined;
			ObjectProperty.Write();
			NewValuesMark = False;
		EndIf;
	EndIf;
	
	If NewValuesMark  = Undefined  And NewValuesOwner = Undefined Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Owner", OldValuesOwner);
	Query.Text =
	"SELECT
	|	ObjectsPropertiesValues.Ref AS Ref,
	|	ObjectsPropertiesValues.DeletionMark AS DeletionMark
	|FROM
	|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
	|WHERE
	|	ObjectsPropertiesValues.Owner = &Owner
	|
	|UNION ALL
	|
	|SELECT
	|	ObjectPropertyValueHierarchy.Ref,
	|	ObjectPropertyValueHierarchy.DeletionMark
	|FROM
	|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
	|WHERE
	|	ObjectPropertyValueHierarchy.Owner = &Owner";
	
	Upload0 = Query.Execute().Unload();
	
	For Each TableRow In Upload0 Do
		CurrentObject = TableRow.Ref.GetObject();
		
		If NewValuesOwner <> Undefined And CurrentObject.Owner <> NewValuesOwner Then
			CurrentObject.Owner = NewValuesOwner;
		EndIf;
		
		If NewValuesMark <> Undefined And CurrentObject.DeletionMark <> NewValuesMark Then
			CurrentObject.DeletionMark = NewValuesMark;
		EndIf;

		If CurrentObject.Modified() Then
			CurrentObject.DataExchange.Load = True;
			CurrentObject.Write();
		EndIf;
	EndDo;
	
	// ACC:1327-on
	// ACC:1328-on
	
EndProcedure

#EndRegion
