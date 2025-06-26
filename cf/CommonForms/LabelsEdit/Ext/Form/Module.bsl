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
	
	If Parameters.ObjectDetails = Undefined Then
		Return;
	EndIf;
	
	ObjectReference = Parameters.ObjectDetails.Ref;
	If Not ValueIsFilled(ObjectReference) Then
		Return;
	EndIf;
	
	If Not AccessRight("Update", Metadata.Catalogs.AdditionalAttributesAndInfoSets) Then
		Items.LabelsContextMenuCreate.Visible = False;
		Items.LabelsContextMenuChange.Visible = False;
	EndIf;
	
	If Not AccessRight("Update", Metadata.FindByType(TypeOf(ObjectReference))) Then
		Items.LabelsValue.Enabled = False;
		Items.LabelsContextMenuSetAll.Visible = False;
		Items.LabelsContextMenuClearAllIetmsCommand.Visible = False;
	EndIf;
	
	// Getting the list of available property sets.
	PropertiesSets = PropertyManagerInternal.GetObjectPropertySets(ObjectReference);
	For Each TableRow In PropertiesSets Do
		AvailablePropertySets.Add(TableRow.Set);
	EndDo;
	
	ObjectLabels.LoadValues(PropertyManager.PropertiesByAdditionalAttributesKind(
		Parameters.ObjectDetails.AdditionalAttributes.Unload(),
		Enums.PropertiesKinds.Labels));
	
	// Populate a label table.
	FillLabels();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Refill a label table.
	If EventName = "Write_AdditionalAttributesAndInfo" Then
		FillLabels();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPropertyValueTable

&AtClient
Procedure LabelsOnChange(Item)
	
	Modified = True;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure LabelsBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure LabelsBeforeAddRow(Item, Cancel, Copy, Parent, IsFolder, Parameter)
	
	Cancel = True;
	OpenLabelCreationForm();
	
EndProcedure

&AtClient
Procedure CompleteEditing(Command)
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("Owner", FormOwner);
	NotificationParameters.Insert("LabelsApplied", LabelsApplied(Labels));
	Notify("Write_LabelsChange", NotificationParameters);
	
	Close();
	
EndProcedure

&AtClient
Procedure MarkEditing(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure Create(Command)
	
	OpenLabelCreationForm()
	
EndProcedure

&AtClient
Procedure Change(Command)
	
	CurrentData = Items.Labels.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key", CurrentData.Property);
	FormParameters.Insert("CurrentPropertiesSet", CurrentData.Set);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
		FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure SetAll(Command)
	
	SetClearAll(Labels, True);
	
EndProcedure

&AtClient
Procedure ClearAllIetmsCommand(Command)
	
	SetClearAll(Labels, False);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OpenLabelCreationForm()
	
	CurrentData = Items.Labels.CurrentData;
	If CurrentData = Undefined Then
		If AvailablePropertySets.Count() = 0 Then
			Return;
		EndIf;
		PropertiesSet = AvailablePropertySets[0].Value;
	Else
		PropertiesSet = CurrentData.Set;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("PropertiesSet", PropertiesSet);
	FormParameters.Insert("PropertyKind", PredefinedValue("Enum.PropertiesKinds.Labels"));
	FormParameters.Insert("CurrentPropertiesSet", PropertiesSet);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
		FormParameters, ThisObject);
	
EndProcedure

&AtServer
Procedure FillLabels()
	
	AdditionalAttributes = Common.ObjectAttributeValue(
		ObjectReference, "AdditionalAttributes", True);
	
	Labels.Clear();
	LabelsValues = PropertyManagerInternal.PropertiesValues(
		AdditionalAttributes.Unload(),
		AvailablePropertySets,
		Enums.PropertiesKinds.Labels);
		
	For Each Label In LabelsValues Do
		If Label.Deleted Then
			Continue;
		EndIf;
		NewRow = Labels.Add();
		FillPropertyValues(NewRow, Label);
		ObjectLabel = ObjectLabels.FindByValue(Label.Property);
		If ObjectLabel = Undefined Then
			NewRow.Value = False;
		Else
			NewRow.Value = True;
		EndIf;
		NewRow.Description = Label.Description;
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function LabelsApplied(Labels)
	
	LabelsApplied = New Array;
	For Each Label In Labels Do
		If Label.Value Then
			LabelsApplied.Add(Label.Property);
		EndIf;
	EndDo;
	
	Return LabelsApplied;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetClearAll(Labels, Set)
	
	For Each Label In Labels Do
		Label.Value = Set;
	EndDo;
	
EndProcedure

#EndRegion