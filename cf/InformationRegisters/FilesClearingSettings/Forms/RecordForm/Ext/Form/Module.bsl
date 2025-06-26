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
Procedure OnReadAtServer(CurrentObject)
	
	If ValueIsFilled(CurrentObject.FileOwner) Then
		InitializeComposer();
	EndIf;
	If CurrentObject.FilterRule.Get() <> Undefined Then
		Rule.LoadSettings(CurrentObject.FilterRule.Get());
	EndIf;

	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = Common.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Record);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Title = NStr("en = 'File cleanup settings:';")
		+ " " + Record.FileOwner;
	
	If AttributesArrayWithDateType.Count() = 0 Then
		Items.AddConditionByDate.Enabled = False;
	EndIf;
	
	If Common.IsMobileClient() Then
		Items.SettingRuleFilterColumnGroupApply.Visible = False;
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	CurrentObject.FilterRule = New ValueStorage(Rule.GetSettings());
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.AfterWrite(ThisObject, Record, WriteParameters);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "InformationRegister.FilesClearingSettings.Form.AddConditionsByDate" Then
		AddToFilterIntervalException(ValueSelected);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		Source = New Array;
		Source.Add(Record.FileOwner);
		ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Source);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
    ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Record);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Record);
	EndIf;
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion

#Region Private

&AtServer
Procedure InitializeComposer()
	
	If Not ValueIsFilled(Record.FileOwner) Then
		Return;
	EndIf;
	
	Rule.Settings.Filter.Items.Clear();
	
	DCS = New DataCompositionSchema;
	DataSource = DCS.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "Local";
	
	DataSet = DCS.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Name = "DataSet1";
	DataSet.DataSource = DataSource.Name;
	
	DCS.TotalFields.Clear();
	DCS.DataSets[0].Query = QueryText();
	
	DataCompositionSchema = PutToTempStorage(DCS, UUID);
	Rule.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	Rule.Refresh(); 
	Rule.Settings.Structure.Clear();
	
EndProcedure

&AtServer
Function QueryText()
	
	AttributesArrayWithDateType.Clear();
	If TypeOf(Record.FileOwner) = Type("CatalogRef.MetadataObjectIDs") Then
		ObjectType = Record.FileOwner;
	Else
		ObjectType = Common.MetadataObjectID(TypeOf(Record.FileOwner));
	EndIf;
	AllCatalogs = Catalogs.AllRefsType();
	AllDocuments = Documents.AllRefsType();

	QueryText = 
		"SELECT
		|	&FileOwnerFields
		|FROM
		|	#FullNameFileOwner";
	
	ObjectTypeInfoRecords = Common.ObjectAttributesValues(ObjectType, "Name,FullName,EmptyRefValue");
	FileOwnerFields = ObjectTypeInfoRecords.Name + ".Ref";
	If AllCatalogs.ContainsType(TypeOf(ObjectTypeInfoRecords.EmptyRefValue)) Then
		Catalog = Metadata.Catalogs[ObjectTypeInfoRecords.Name];
		For Each Attribute In Catalog.Attributes Do
			FileOwnerFields = FileOwnerFields + "," + Chars.LF + ObjectTypeInfoRecords.Name + "." + Attribute.Name;
		EndDo;
	ElsIf
		AllDocuments.ContainsType(TypeOf(ObjectTypeInfoRecords.EmptyRefValue)) Then
		Document = Metadata.Documents[ObjectTypeInfoRecords.Name];
		For Each Attribute In Document.Attributes Do
			FileOwnerFields = FileOwnerFields + "," + Chars.LF + ObjectTypeInfoRecords.Name + "." + Attribute.Name;
			If Attribute.Type.ContainsType(Type("Date")) Then
				AttributesArrayWithDateType.Add(Attribute.Name, Attribute.Synonym);
				FileOwnerFields = FileOwnerFields + "," + Chars.LF 
					+ StrReplace("DATEDIFF(&AttributeName, &CurrentDate, DAY) AS DaysBeforeDeletionFrom&AttributeName",
						"&AttributeName", Attribute.Name);
			EndIf;
		EndDo;
	EndIf;
	
	QueryText = StrReplace(QueryText, "&FileOwnerFields", FileOwnerFields);
	QueryText = StrReplace(QueryText, "#FullNameFileOwner", 
		ObjectTypeInfoRecords.FullName + " AS " + ObjectTypeInfoRecords.Name);
	Return QueryText;
	
EndFunction

&AtClient
Procedure AddConditionByDate(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("AttributesOfDateType", AttributesArrayWithDateType);
	OpenForm("InformationRegister.FilesClearingSettings.Form.AddConditionsByDate", FormParameters, ThisObject);
	
EndProcedure

&AtServer
Procedure AddToFilterIntervalException(Val ValueSelected)
	
	FilterByInterval = Rule.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterByInterval.LeftValue = New DataCompositionField("DaysBeforeDeletionFrom" + ValueSelected.DateTypeAttribute);
	FilterByInterval.ComparisonType = DataCompositionComparisonType.GreaterOrEqual;
	FilterByInterval.RightValue = ValueSelected.IntervalException;
	PresentationOfAttributeWithDateType = AttributesArrayWithDateType.FindByValue(ValueSelected.DateTypeAttribute).Presentation;
	PresentationText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Clean up after %1 days since %2';"), 
		ValueSelected.IntervalException, PresentationOfAttributeWithDateType);
	FilterByInterval.Presentation = PresentationText;

EndProcedure

#EndRegion