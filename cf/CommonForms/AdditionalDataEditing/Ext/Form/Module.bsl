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
	
	SetConditionalAppearance();
	
	If Not AccessRight("Update", Metadata.InformationRegisters.AdditionalInfo) Then
		Items.FormWrite.Visible = False;
		Items.FormWriteAndClose.Visible = False;
	EndIf;
	
	If Not AccessRight("Update", Metadata.Catalogs.AdditionalAttributesAndInfoSets) Then
		Items.ChangeAdditionalDataContent.Visible = False;
	EndIf;
	
	ObjectReference = Parameters.Ref;
	
	PropertiesSets = PropertyManagerInternal.GetObjectPropertySets(Parameters.Ref);
	For Each TableRow In PropertiesSets Do
		AvailablePropertySets.Add(TableRow.Set);
	EndDo;
	
	FillPropertiesValuesTable(True);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseCompletion", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_AdditionalAttributesAndInfoSets" Then
		
		If AvailablePropertySets.FindByValue(Source) <> Undefined Then
			FillPropertiesValuesTable(False);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPropertyValueTable

&AtClient
Procedure PropertyValueTableOnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure PropertyValueTableBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertyValueTableBeforeDeleteRow(Item, Cancel)
	
	If Item.CurrentData.PictureNumber = -1 Then
		Cancel = True;
		Item.CurrentData.Value = Item.CurrentData.ValueType.AdjustValue(Undefined);
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PropertyValueTableOnStartEdit(Item, NewRow, Copy)
	
	Item.ChildItems.PropertyValueTableValue.TypeRestriction
		= Item.CurrentData.ValueType;
	
EndProcedure

&AtClient
Procedure PropertyValueTableBeforeRowChange(Item, Cancel)
	If Items.PropertyValueTable.CurrentData = Undefined Then
		Return;
	EndIf;
	
	String = Items.PropertyValueTable.CurrentData;
	
	ChoiceParametersArray1 = New Array;
	If String.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues"))
		Or String.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
		ChoiceParametersArray1.Add(New ChoiceParameter("Filter.Owner",
			?(ValueIsFilled(String.AdditionalValuesOwner),
				String.AdditionalValuesOwner, String.Property)));
	EndIf;
	Items.PropertyValueTableValue.ChoiceParameters = New FixedArray(ChoiceParametersArray1);
EndProcedure

&AtClient
Procedure PropertyValueTableSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Field.Name <> Items.PropertyValueTableColumnQuestion.Name Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	String = PropertyValueTable.FindByID(RowSelected);
	If Not ValueIsFilled(String.ToolTip) Then
		Return;
	EndIf;
	
	TitleText = NStr("en = 'Tooltip of the ""%1"" information record';");
	TitleText = StringFunctionsClientServer.SubstituteParametersToString(TitleText, String.Description);
	
	QuestionToUserParameters = StandardSubsystemsClient.QuestionToUserParameters();
	QuestionToUserParameters.Title = TitleText;
	QuestionToUserParameters.PromptDontAskAgain = False;
	QuestionToUserParameters.Picture = PictureLib.DialogInformation;
	
	Buttons = New ValueList;
	Buttons.Add("OK", NStr("en = 'OK';"));
	StandardSubsystemsClient.ShowQuestionToUser(Undefined, String.ToolTip, Buttons, QuestionToUserParameters);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Write(Command)
	
	WritePropertiesValues();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteAndCloseCompletion();
	
EndProcedure

&AtClient
Procedure ChangeAdditionalDataContent(Command)
	
	If AvailablePropertySets.Count() = 0
	 Or Not ValueIsFilled(AvailablePropertySets[0].Value) Then
		
		ShowMessageBox(,
			NStr("en = 'Cannot get the additional information record sets of the object.
			           |
			           |Probably some of the required object attributes are blank.';"));
	Else
		FormParameters = New Structure;
		FormParameters.Insert("PropertyKind",
			PredefinedValue("Enum.PropertiesKinds.AdditionalInfo"));
		
		OpenForm("Catalog.AdditionalAttributesAndInfoSets.ListForm", FormParameters);
		
		MigrationParameters = New Structure;
		MigrationParameters.Insert("Set", AvailablePropertySets[0].Value);
		MigrationParameters.Insert("Property", Undefined);
		MigrationParameters.Insert("IsAdditionalInfo", True);
		MigrationParameters.Insert("PropertyKind",
			PredefinedValue("Enum.PropertiesKinds.AdditionalInfo"));
		
		If Items.PropertyValueTable.CurrentData <> Undefined Then
			MigrationParameters.Insert("Set", Items.PropertyValueTable.CurrentData.Set);
			MigrationParameters.Insert("Property", Items.PropertyValueTable.CurrentData.Property);
		EndIf;
		
		Notify("GoAdditionalDataAndAttributeSets", MigrationParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure WriteAndCloseCompletion(Result = Undefined, AdditionalParameters = Undefined) Export
	
	WritePropertiesValues();
	Modified = False;
	Close();
	
EndProcedure

&AtServer
Procedure FillPropertiesValuesTable(FromOnCreateHandler)
	
	If FromOnCreateHandler Then
		PropertiesValues = ReadPropertiesValuesFromInfoRegister(Parameters.Ref);
	Else
		PropertiesValues = CurrentPropertiesValues();
		PropertyValueTable.Clear();
	EndIf;
	
	TableToCheck = "InformationRegister.AdditionalInfo";
	AccessValue = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo");
	
	Table = PropertyManagerInternal.PropertiesValues(
		PropertiesValues, AvailablePropertySets, Enums.PropertiesKinds.AdditionalInfo);
	
	CheckRights1 = Not Users.IsFullUser() And Common.SubsystemExists("StandardSubsystems.AccessManagement");
	
	If CheckRights1 Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		UniversalRestriction = ModuleAccessManagementInternal.LimitAccessAtRecordLevelUniversally();
		If Not UniversalRestriction Then
			PropertiesToCheck = Table.UnloadColumn("Property");
			AllowedProperties = ModuleAccessManagementInternal.AllowedDynamicListValues(
				TableToCheck, AccessValue, PropertiesToCheck, , True);
		EndIf;
	EndIf;
	
	For Each TableRow In Table Do
		
		If CheckRights1 Then
			PropertyAccessRights = PropertyAccessRights(TableRow.Property, UniversalRestriction, 
				AllowedProperties, ModuleAccessManagement);
			If Not PropertyAccessRights.CanBeRead Then
				Continue;
			EndIf;
		EndIf;
		
		NewRow = PropertyValueTable.Add();
		FillPropertyValues(NewRow, TableRow);
		
		If ValueIsFilled(NewRow.ToolTip) Then
			NewRow.ColumnQuestion = "?";
		EndIf;
		
		NewRow.PictureNumber = ?(TableRow.Deleted, 0, -1);
		NewRow.IsEditable = ?(CheckRights1, PropertyAccessRights.IsEditable, True);
		
		If TableRow.Value = Undefined
			And Common.TypeDetailsContainsType(TableRow.ValueType, Type("Boolean")) Then
			NewRow.Value = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function PropertyAccessRights(Property, UniversalRestriction, AllowedProperties, ModuleAccessManagement)

	Result = New Structure("CanBeRead,IsEditable", False, False);
	If UniversalRestriction Then
		RecordSet = TestRecordSet(Property);
		
		Result.CanBeRead = ModuleAccessManagement.ReadingAllowed(RecordSet);
		Result.IsEditable = ModuleAccessManagement.EditionAllowed(RecordSet);
		Return Result;
	EndIf;

	If AllowedProperties <> Undefined And AllowedProperties.Find(Property) = Undefined Then
		Return Result;
	EndIf;
	
	Result.CanBeRead = True;
	BeginTransaction(); // ACC:326 - Commit of the transaction is not required; this is a check for write permissions.
	Try
		RecordSet = TestRecordSet(Property);
		RecordSet.DataExchange.Load = True;
		RecordSet.Write(True);

		Result.IsEditable = True;
		
		RollbackTransaction();
	Except
		RollbackTransaction();
	EndTry;
	Return Result;

EndFunction

&AtServer
Function TestRecordSet(Property)
	RecordSet = InformationRegisters.AdditionalInfo.CreateRecordSet();
	RecordSet.Filter.Object.Set(Parameters.Ref);
	RecordSet.Filter.Property.Set(Property);
	
	Record = RecordSet.Add();
	Record.Property = Property;
	Record.Object = Parameters.Ref;
	
	Return RecordSet;
EndFunction

&AtClient
Procedure WritePropertiesValues()
	
	PropertiesValues = New Array;
	For Each TableRow In PropertyValueTable Do
		Value = New Structure("Property, Value", TableRow.Property, TableRow.Value);
		PropertiesValues.Add(Value);
	EndDo;
	
	If PropertiesValues.Count() > 0 Then
		WritePropertySetInRegister(ObjectReference, PropertiesValues);
	EndIf;
	
	Modified = False;
	
EndProcedure

&AtServerNoContext
Procedure WritePropertySetInRegister(Val Ref, Val PropertiesValues)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.AdditionalInfo");
		LockItem.SetValue("Object", Ref);
		Block.Lock();
		
		Set = InformationRegisters.AdditionalInfo.CreateRecordSet();
		Set.Filter.Object.Set(Ref);
		Set.Read();
		CurrentValues = Set.Unload();
		For Each TableRow In PropertiesValues Do
			Record = CurrentValues.Find(TableRow.Property, "Property");
			If Record = Undefined Then
				Record = CurrentValues.Add();
				Record.Property = TableRow.Property;
				Record.Value = TableRow.Value;
				Record.Object   = Ref;
			EndIf;
			Record.Value = TableRow.Value;
			
			If Not ValueIsFilled(Record.Value)
				Or Record.Value = False Then
				CurrentValues.Delete(Record);
			EndIf;
		EndDo;
		Set.Load(CurrentValues);
		Set.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
	EndTry;
	
EndProcedure

&AtServerNoContext
Function ReadPropertiesValuesFromInfoRegister(Ref)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AdditionalInfo.Property,
	|	AdditionalInfo.Value
	|FROM
	|	InformationRegister.AdditionalInfo AS AdditionalInfo
	|WHERE
	|	AdditionalInfo.Object = &Object";
	Query.SetParameter("Object", Ref);
	
	Return Query.Execute().Unload();
	
EndFunction

&AtServer
Function CurrentPropertiesValues()
	
	PropertiesValues = New ValueTable;
	PropertiesValues.Columns.Add("Property");
	PropertiesValues.Columns.Add("Value");
	
	For Each TableRow In PropertyValueTable Do
		
		If ValueIsFilled(TableRow.Value) And (TableRow.Value <> False) Then
			NewRow = PropertiesValues.Add();
			NewRow.Property = TableRow.Property;
			NewRow.Value = TableRow.Value;
		EndIf;
	EndDo;
	
	Return PropertiesValues;
	
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PropertyValueTableValue.Name);
	
	// Date format - time.
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PropertyValueTable.ValueType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = New TypeDescription("Date",,, New DateQualifiers(DateFractions.Time));
	Item.Appearance.SetParameterValue("Format", "DLF=T");
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PropertyValueTableValue.Name);
	
	// Date format - date.
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PropertyValueTable.ValueType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = New TypeDescription("Date",,, New DateQualifiers(DateFractions.Date));
	Item.Appearance.SetParameterValue("Format", "DLF=D");
	
	//
	Item = ConditionalAppearance.Items.Add();
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PropertyValueTableValue.Name);
	
	// Field availability if you have no change rights.
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PropertyValueTable.IsEditable");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	Item.Appearance.SetParameterValue("ReadOnly", True);
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

#EndRegion
