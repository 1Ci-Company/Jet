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
	
	If ValueIsFilled(Parameters.FileOwner) Then
		Record.FileOwner = Parameters.FileOwner;
		If Not ValueIsFilled(Parameters.Key) Then
			InitializeComposer();
		EndIf;
	EndIf;
	
	If AttributesArrayWithDateType.Count() = 0 Then
		Items.AddConditionByDate.Enabled = False;
	EndIf;
	
	If ValueIsFilled(Parameters.FileOwnerType) Then
		Record.FileOwnerType = Parameters.FileOwnerType;
	EndIf;
	
	Record.IsFile = Parameters.IsFile;
	
	NewSetting = Parameters.NewSetting;
	
	If Record.FileOwner = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Record.Account) Then
		FillSynchronizationAccount();
	EndIf;
	
	FileOwnerNotMetadataObjectsID = TypeOf(Record.FileOwner) <> Type("CatalogRef.MetadataObjectIDs");
	If FileOwnerNotMetadataObjectsID Then
		
		Common.MetadataObjectID(TypeOf(Record.FileOwner));
		SynchronizationObject = "OnlyItemFiles";
		
		FilesOwnerID = Common.MetadataObjectID(TypeOf(Record.FileOwner));
		PresentationFilesOwnerType = Common.ObjectAttributeValue(Record.FileOwnerType, "Description");
		OwnerPresentationForTitle = Common.SubjectString(Record.FileOwner);
		CatalogItem = Record.FileOwner;
		
		ExistingSettingsList.LoadValues(ExistingSynchronizationObjects(TypeOf(Record.FileOwner)));
		
	Else
		
		OwnerProperties = Common.ObjectAttributesValues(Record.FileOwner, 
			"Description,EmptyRefValue");
		ExistingSettingsList.LoadValues(ExistingSynchronizationObjects(TypeOf(OwnerProperties.EmptyRefValue)));
		SynchronizationObject = "AllFiles";
		
		FilesOwnerID = Record.FileOwner;
		PresentationFilesOwnerType = OwnerProperties.Description;
		OwnerPresentationForTitle = PresentationFilesOwnerType;
		CatalogItem = OwnerProperties.EmptyRefValue;
		
	EndIf;
	
	If HasSyncRulesSettings(Record.FileOwner) 
		And (NewSetting Or TypeOf(Record.FileOwner) <> Type("CatalogRef.MetadataObjectIDs")) Then
		Items.SyncObjectAllFiles.ReadOnly = True;
		Items.SyncRuleGroup.ReadOnly  = True;
		SynchronizationObject                                 = "OnlyItemFiles";
	EndIf;
	
	Title = NStr("en = 'File synchronization setting:';") + " " + OwnerPresentationForTitle;
	
	Items.SetupRuleFilter.ExtendedTooltip.Title =
		StringFunctionsClientServer.SubstituteParametersToString(Items.SetupRuleFilter.ExtendedTooltip.Title, PresentationFilesOwnerType);
	Items.SyncObjectAllFiles.ChoiceList[0].Presentation = StringFunctionsClientServer.SubstituteParametersToString(Items.SyncObjectAllFiles.ChoiceList[0].Presentation, PresentationFilesOwnerType);
	
	If Common.IsMobileClient() Then
		Items.SetupRuleFilter.Header = False;
		Items.Description.TitleLocation = FormItemTitleLocation.Top;
	EndIf;
	
	Items.Account.ReadOnly = Parameters.ForbidChangeAccount;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetFormItemEnabled();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If ValueIsFilled(CurrentObject.FileOwner) Then
		InitializeComposer();
	EndIf;
	If CurrentObject.FilterRule.Get() <> Undefined Then
		Rule.LoadSettings(CurrentObject.FilterRule.Get());
	EndIf;

EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If SynchronizationObject = "OnlyItemFiles" And Not ValueIsFilled(CatalogItem) Then
		Cancel = True;
		CommonClient.MessageToUser(
			NStr("en = 'The object with attachments is not specified.';"),
			,
			"CatalogItem");
	EndIf;
		
	Record.FileOwner = 
		?(SynchronizationObject = "AllFiles", FilesOwnerID, CatalogItem);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	FilterRule = Rule.GetSettings();
	
	If SynchronizationObject = "OnlyItemFiles" Then
		FilterRule.Filter.Items.Clear();
		CurrentObject.Description = "";
	EndIf;
	
	CurrentObject.FilterRule = New ValueStorage(FilterRule);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ReturnValue = New Structure;
	If SynchronizationObject = "OnlyItemFiles" Then
		ObjectDescriptionSynonym = CurrentObject.FileOwner;
		HasFilterRules = False;
	Else
		ObjectDescriptionSynonym = Common.ObjectAttributeValue(FilesOwnerID, "Synonym");
		HasFilterRules = Rule.GetSettings().Filter.Items.Count() > 0;
	EndIf;
	ReturnValue.Insert("ObjectDescriptionSynonym", ObjectDescriptionSynonym);
	ReturnValue.Insert("NewSetting",    NewSetting);
	ReturnValue.Insert("FileOwner",     CurrentObject.FileOwner);
	ReturnValue.Insert("FileOwnerType", CurrentObject.FileOwnerType);
	ReturnValue.Insert("Synchronize",  CurrentObject.Synchronize);
	ReturnValue.Insert("Description",      CurrentObject.Description);
	ReturnValue.Insert("Account",     CurrentObject.Account);
	ReturnValue.Insert("IsFile",           CurrentObject.IsFile);
	ReturnValue.Insert("Rule",           CurrentObject.FilterRule);
	ReturnValue.Insert("HasFilterRules", HasFilterRules);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "InformationRegister.FileSynchronizationSettings.Form.AddConditionsByDate" Then
		AddToFilterIntervalException(ValueSelected);
	EndIf;
	
EndProcedure

&AtClient
Procedure SynchronizationObjectOnChange(Item)
	
	SetFormItemEnabled();
	Record.FileOwner = FilesOwnerID;
	
EndProcedure

&AtClient
Procedure SyncObjectItemFilesOnChange(Item)
	
	SetFormItemEnabled();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	NotifyChoice(ReturnValue);
	
EndProcedure

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
	
	DCS.DataSets[0].Query = GetQueryText();
	
	DataCompositionSchema = PutToTempStorage(DCS, UUID);
	
	Rule.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	
	Rule.Refresh(); 
	Rule.Settings.Structure.Clear();
	
EndProcedure

&AtServer
Function GetQueryText()
	
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
	
	ObjectTypeAttributes = Common.ObjectAttributesValues(ObjectType, "Name, EmptyRefValue, FullName");
	FileOwnerFields = ObjectTypeAttributes.Name + ".Ref";
	If AllCatalogs.ContainsType(TypeOf(ObjectTypeAttributes.EmptyRefValue)) Then
		Catalog = Metadata.Catalogs[ObjectTypeAttributes.Name];
		For Each Attribute In Catalog.Attributes Do
			FileOwnerFields = FileOwnerFields + "," + Chars.LF + ObjectTypeAttributes.Name + "." + Attribute.Name;
		EndDo;
	ElsIf AllDocuments.ContainsType(TypeOf(ObjectTypeAttributes.EmptyRefValue)) Then
		Document = Metadata.Documents[ObjectTypeAttributes.Name];
		For Each Attribute In Document.Attributes Do
			FileOwnerFields = FileOwnerFields + "," + Chars.LF + ObjectTypeAttributes.Name + "." + Attribute.Name;
			If Attribute.Type.ContainsType(Type("Date")) Then
				AttributesArrayWithDateType.Add(Attribute.Name, Attribute.Synonym);
				FileOwnerFields = FileOwnerFields + "," + Chars.LF 
					+ StrReplace("DATEDIFF(&AttributeName, &CurrentDate, DAY) AS DaysBeforeDeletionFrom&AttributeName",
						"&AttributeName", Attribute.Name);
			EndIf;
		EndDo;
	EndIf;
	
	QueryText = StrReplace(QueryText, "&FileOwnerFields", FileOwnerFields);
	QueryText = StrReplace(QueryText, "#FullNameFileOwner", ObjectTypeAttributes.FullName + " AS "
		+ ObjectTypeAttributes.Name);
	Return QueryText;
	
EndFunction

&AtClient
Procedure AddConditionByDate(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("AttributesOfDateType", AttributesArrayWithDateType);
	OpenForm("InformationRegister.FileSynchronizationSettings.Form.AddConditionsByDate", FormParameters, ThisObject);
	
EndProcedure

&AtServer
Procedure AddToFilterIntervalException(ValueSelected)
	
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

&AtClient
Procedure SetFormItemEnabled()
	
	CatalogSynchronization = SynchronizationObject = "AllFiles";
	
#If MobileClient Then
	Items.SyncRuleGroup.Visible = CatalogSynchronization;
	Items.CatalogItem.Visible = Not CatalogSynchronization;
#Else
	Items.SyncRuleGroup.Enabled = CatalogSynchronization;
	Items.CatalogItem.Enabled = Not CatalogSynchronization;
#EndIf

EndProcedure

&AtClient
Procedure CatalogItemStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ChoiceFormParameters = New Structure;
	
	ChoiceFormParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.FoldersAndItems);
	ChoiceFormParameters.Insert("CloseOnChoice", True);
	ChoiceFormParameters.Insert("CloseOnOwnerClose", True);
	ChoiceFormParameters.Insert("MultipleChoice", False);
	ChoiceFormParameters.Insert("ChoiceMode", True);
	
	ChoiceFormParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	ChoiceFormParameters.Insert("SelectGroups", True);
	ChoiceFormParameters.Insert("UsersGroupsSelection", True);
	
	ChoiceFormParameters.Insert("AdvancedPick", True);
	ChoiceFormParameters.Insert("PickFormHeader", NStr("en = 'Select settings items';"));
	
	FixedSettings = New DataCompositionSettings;
	SettingItem = FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	SettingItem.LeftValue = New DataCompositionField("Ref");
	SettingItem.ComparisonType = DataCompositionComparisonType.NotInList;
	SettingItem.RightValue = ExistingSettingsList;
	SettingItem.Use = True;
	SettingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ChoiceFormParameters.Insert("FixedSettings", FixedSettings);
	
	OpenForm(ChoiceFormPath(CatalogItem, FilesOwnerID), ChoiceFormParameters, Items.CatalogItem);
	
EndProcedure
 
&AtServerNoContext
Function ChoiceFormPath(FileOwner, FilesOwnerID)
	
	MetadataObject = Common.MetadataObjectByID(FilesOwnerID);
	Return MetadataObject.FullName() + ".ChoiceForm";
	
EndFunction

&AtServer
Function ExistingSynchronizationObjects(FileOwnerType)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileSynchronizationSettings.FileOwner
		|FROM
		|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
		|WHERE
		|	VALUETYPE(FileSynchronizationSettings.FileOwner) = &FileOwnerType";
	
	Query.SetParameter("FileOwnerType", FileOwnerType);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Unload().UnloadColumn("FileOwner");
	
EndFunction

&AtServer
Function HasSyncRulesSettings(FileOwner)
	
	Query = New Query;
	Query.Text = "SELECT TRUE AS HasSyncRulesSettings
		|FROM
		|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
		|WHERE
		|	FileSynchronizationSettings.FileOwner = &FileOwner";
	
	Query.SetParameter("FileOwner", FileOwner);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return False;
	EndIf;
	
	Result = QueryResult.Unload()[0];

	Return ValueIsFilled(Result.HasSyncRulesSettings);
	
EndFunction

&AtServer
Procedure FillSynchronizationAccount()
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	FileSynchronizationAccounts.Ref
		|FROM
		|	Catalog.FileSynchronizationAccounts AS FileSynchronizationAccounts
		|WHERE
		|	NOT FileSynchronizationAccounts.DeletionMark";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Count() = 1 Then
		While SelectionDetailRecords.Next() Do
			Record.Account = SelectionDetailRecords.Ref;
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion