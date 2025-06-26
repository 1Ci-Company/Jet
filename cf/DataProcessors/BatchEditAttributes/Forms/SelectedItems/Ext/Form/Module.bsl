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
	
	SelectedTypes = Parameters.SelectedTypes;
	PurposeUseKey = TrimStringUsingChecksum(SelectedTypes, 128);
	
	DataProcessorObject1 = FormAttributeToValue("Object");
	QueryText = DataProcessorObject1.QueryText(SelectedTypes);
	
	InitializeSettingsComposer();
	SettingsComposer.LoadSettings(Parameters.Settings);
	
	List.QueryText = QueryText;
	
	UpdateSelectedListAtServer();
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	Settings["Filter"] = DataCompositionSettings();
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	CompositionSettings = Settings["Filter"];
	If CompositionSettings <> Undefined Then
		SettingsComposer.LoadSettings(CompositionSettings);
		UpdateSelectedListAtServer();
	EndIf;	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSettingsComposerSettingsFilter

&AtClient
Procedure SettingsComposerSettingsFilterOnStartEdit(Item, NewRow, Copy)
	
	DetachIdleHandler("UpdateSelectedCount");
	DetachIdleHandler("UpdateSelectedList");
	IsFiltersBeingEdited = True;
	
EndProcedure

&AtClient
Procedure SettingsComposerSettingsFilterOnEditEnd(Item, NewRow, CancelEdit)
	
	IsFiltersBeingEdited = False;
	InitializeSelectedListUpdate();
	
EndProcedure

&AtClient
Procedure SettingsComposerSettingsFilterAfterDeleteRow(Item)
	
	InitializeSelectedListUpdate();
	
EndProcedure

&AtClient
Procedure SettingsComposerSettingsFilterBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	DetachIdleHandler("UpdateSelectedCount");
	DetachIdleHandler("UpdateSelectedList");
	
EndProcedure

&AtClient
Procedure SettingsComposerSettingsFilterOnActivateRow(Item)
	
	FilterItemsCount = FilterItemsCount(SettingsComposer.Settings.Filter.Items);
	If NumberOfConditions <> FilterItemsCount Then
		InitializeSelectedListUpdate();
	EndIf; 
	
EndProcedure

&AtClient
Procedure SettingsComposerSettingsFilterOnChange(Item)
	
	InitializeSelectedListUpdate();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	If Item.CurrentData <> Undefined Then 
		ShowValue(, Item.CurrentData.Ref);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	DetachIdleHandler("UpdateSelectedList");
	Result = DataCompositionSettings();
	Close(Result);
EndProcedure

&AtServer
Function DataCompositionSettings()
	If Items.SelectedObjectsGroup.Visible Then
		UpdateSelectedListAtServer();
	EndIf;
	Return List.SettingsComposer.GetSettings();
EndFunction

&AtClient
Procedure OpenItem(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	ShowValue(, CurrentData.Ref);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure InitializeSettingsComposer()
	If Not IsBlankString(Parameters.SelectedTypes) Then
		DataCompositionSchema = DataCompositionSchema(QueryText);
		SchemaURL = PutToTempStorage(DataCompositionSchema, UUID);
		SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
	EndIf;
EndProcedure

&AtServer
Function DataCompositionSchema(QueryText)
	DataProcessorObject = FormAttributeToValue("Object");
	Return DataProcessorObject.DataCompositionSchema(QueryText);
EndFunction

&AtServer
Procedure UpdateSelectedListAtServer()
	
	List.SettingsComposer.LoadSettings(SettingsComposer.Settings);
	
	Structure = List.SettingsComposer.Settings.Structure;
	Structure.Clear();
	DataCompositionGroup = Structure.Add(Type("DataCompositionGroup"));
	DataCompositionGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	DataCompositionGroup.Use = True;
	
	Case = List.SettingsComposer.Settings.Selection;
	ComboBox = Case.Items.Add(Type("DataCompositionSelectedField"));
	ComboBox.Field = New DataCompositionField("Ref");
	ComboBox.Use = True;
	
	UpdateSelectedCountServer();

EndProcedure

&AtClient
Procedure UpdateSelectedCount()
	UpdateSelectedCountServer();
EndProcedure
	
&AtServer
Procedure UpdateSelectedCountServer()
	
	PreviousSelectedCount = SelectedCount;
	
	SelectedCount = SelectedObjects().Rows.Count();
	TextSelectedCount = String(SelectedCount);
	If SelectedCount > 1000 Then
		SelectedCount = 1000;
		TextSelectedCount = NStr("en = '> 1000';");
	ElsIf SelectedCount = 0 Then
		List.SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.Full);
	EndIf;
	If PreviousSelectedCount <> SelectedCount Then
		Items.SelectedObjectsGroup.Title = SubstituteParametersToString(
			NStr("en = 'Selected items (%1)';"), TextSelectedCount);
	EndIf;

EndProcedure

&AtClient
Procedure InitializeSelectedListUpdate()
	
	DetachIdleHandler("UpdateSelectedList");

	If IsFiltersBeingEdited Then
		Return;
	EndIf;
	
	NumberOfConditions = FilterItemsCount(SettingsComposer.Settings.Filter.Items);
	
	If Items.SelectedObjectsGroup.Visible Then
		AttachIdleHandler("UpdateSelectedList", 1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateSelectedList()
	UpdateSelectedListAtServer();
EndProcedure

&AtServer
Function SelectedObjects()
	
	Result = New ValueTree;
	
	If Not IsBlankString(SelectedTypes) Then
		DataCompositionSchema = Items.List.GetPerformingDataCompositionScheme();
		Settings = Items.List.GetPerformingDataCompositionSettings();
		TemplateComposer = New DataCompositionTemplateComposer();
		Try
			DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema,
				Settings,,, Type("DataCompositionValueCollectionTemplateGenerator"));
		Except
			Return Result;
		EndTry;
		
		DataCompositionProcessor = New DataCompositionProcessor;
		DataCompositionProcessor.Initialize(DataCompositionTemplate);

		OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
		OutputProcessor.SetObject(Result);
		OutputProcessor.Output(DataCompositionProcessor);
	EndIf;
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function SubstituteParametersToString(Val SubstitutionString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	SubstitutionString = StrReplace(SubstitutionString, "%1", Parameter1);
	SubstitutionString = StrReplace(SubstitutionString, "%2", Parameter2);
	SubstitutionString = StrReplace(SubstitutionString, "%3", Parameter3);
	
	Return SubstitutionString;
EndFunction

&AtServer
Function TrimStringUsingChecksum(String, MaxLength)
	Result = String;
	If StrLen(String) > MaxLength Then
		Result = Left(String, MaxLength - 32);
		DataHashing = New DataHashing(HashFunction.MD5);
		DataHashing.Append(Mid(String, MaxLength - 32 + 1));
		Result = Result + StrReplace(DataHashing.HashSum, " ", "");
	EndIf;
	Return Result;
EndFunction

&AtClient
Function FilterItemsCount(CollectionOfSelectionElements)
	
	Result = 0;
	
	For Each Item In CollectionOfSelectionElements Do
		Result = Result + 1;
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then
			Result = Result + FilterItemsCount(Item.Items);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion
