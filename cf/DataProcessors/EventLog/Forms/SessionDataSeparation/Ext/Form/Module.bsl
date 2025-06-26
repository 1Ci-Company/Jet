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
	
	ActiveFilter = Parameters.ActiveFilter;
	DataSeparationMap = New Map;
	If ActiveFilter.Count() > 0 Then
		
		For Each SessionSeparator In ActiveFilter Do
			StringParts1 = StrSplit(SessionSeparator.Value, "=");
			DataSeparationMap.Insert(StringParts1[0], StringParts1[1]);
		EndDo;
		
	EndIf;
	
	For Each CommonAttribute In Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.DontUse Then
			Continue;
		EndIf;
		TableRow = SessionDataSeparation.Add();
		TableRow.Separator = CommonAttribute.Name;
		TableRow.SeparatorPresentation = CommonAttribute.Presentation();
		SeparatorValue = DataSeparationMap[CommonAttribute.Name];
		If SeparatorValue <> Undefined Then
			TableRow.CheckBox = True;
			TableRow.SeparatorValue = EventLog.StringDelimitersList(SeparatorValue);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "EventLogFilterItemValueChoice"
	   And Source.UUID = UUID Then
		
		Items.SessionDataSeparation.CurrentData.SeparatorValue = Parameter;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OkCommand(Command)
	Result = New ValueList;
	For Each TableRow In SessionDataSeparation Do
		If TableRow.CheckBox Then
			SeparatorValue = TableRow.Separator + "="
				+ StrConcat(TableRow.SeparatorValue.UnloadValues(), ",");
			SeparatorPresentation = TableRow.SeparatorPresentation + " = "
				+ StrConcat(TableRow.SeparatorValue.UnloadValues(), ", ");
			Result.Add(SeparatorValue, SeparatorPresentation);
		EndIf;
	EndDo;
	
	Notify("EventLogFilterItemValueChoice",
		Result,
		FormOwner);
	
	Close();
EndProcedure

&AtClient
Procedure SelectAllCommand(Command)
	For Each ListItem In SessionDataSeparation Do
		ListItem.CheckBox = True;
	EndDo;
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	For Each ListItem In SessionDataSeparation Do
		ListItem.CheckBox = False;
	EndDo;
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	Close();
EndProcedure

&AtClient
Procedure SessionDataSeparationSeparatorValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Items.SessionDataSeparation.CurrentData;
	
	FormParameters = New Structure;
	FormParameters.Insert("ListToEdit", CurrentData.SeparatorValue);
	FormParameters.Insert("ParametersToSelect", "SessionDataSeparationValues" + "." + CurrentData.Separator);
	
	// Open the property editor.
	OpenForm("DataProcessor.EventLog.Form.PropertyCompositionEditor",
		FormParameters, ThisObject);
	
EndProcedure

#EndRegion