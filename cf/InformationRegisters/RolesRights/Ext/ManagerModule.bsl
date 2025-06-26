///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// If data is not updated but an update is possible, it updates,
// otherwise, it calls an exception.
//
Procedure CheckRegisterData() Export
	
	Updated = StandardSubsystemsServer.ApplicationParameter(
		"StandardSubsystems.AccessManagement.RolesRights");
	
	If Updated <> Undefined Then
		Return;
	EndIf;
	
	UpdateRegisterData();
	
EndProcedure

// Updates the register data when changing a configuration.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	StandardSubsystemsCached.MetadataObjectIDsUsageCheck(True);
	
	If ValueIsFilled(SessionParameters.ExtensionsVersion)
	   And HasRolesModifiedByExtensions() Then
		
		ErrorText =
			NStr("en = 'Couldn''t update role rights. Reason:
			           |Extensions that modify configuration roles are found.';");
		Raise ErrorText;
	EndIf;
	
	Query = ChangesQuery(False);
	
	Block = New DataLock;
	Block.Add("InformationRegister.RolesRights");
	
	BeginTransaction();
	Try
		Block.Lock();
		Changes = Query.Execute().Unload();
		
		Data = New Structure;
		Data.Insert("RegisterManager",      InformationRegisters.RolesRights);
		Data.Insert("EditStringContent", Changes);
		
		AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
		
		StandardSubsystemsServer.AddApplicationParameterChanges(
			"StandardSubsystems.AccessManagement.RoleRightMetadataObjects",
			ChangedMetadataObjects(Changes));
		
		StandardSubsystemsServer.UpdateApplicationParameter(
			"StandardSubsystems.AccessManagement.RolesRights", True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Function AvailableMetadataObjectsRights()
	
	SetPrivilegedMode(True);
	
	MetadataObjectsRights = New ValueTable;
	MetadataObjectsRights.Columns.Add("Collection");
	MetadataObjectsRights.Columns.Add("InsertRight1");
	MetadataObjectsRights.Columns.Add("EditRight");
	
	String = MetadataObjectsRights.Add();
	String.Collection         = "Catalogs";
	String.InsertRight1   = True;
	String.EditRight    = True;
	
	String = MetadataObjectsRights.Add();
	String.Collection         = "Documents";
	String.InsertRight1   = True;
	String.EditRight    = True;
	
	String = MetadataObjectsRights.Add();
	String.Collection         = "DocumentJournals";
	String.InsertRight1   = False;
	String.EditRight    = False;
	
	String = MetadataObjectsRights.Add();
	String.Collection         = "ChartsOfCharacteristicTypes";
	String.InsertRight1   = True;
	String.EditRight    = True;
	
	String = MetadataObjectsRights.Add();
	String.Collection         = "ChartsOfAccounts";
	String.InsertRight1   = True;
	String.EditRight    = True;
	
	String = MetadataObjectsRights.Add();
	String.Collection         = "ChartsOfCalculationTypes";
	String.InsertRight1   = True;
	String.EditRight    = True;
	
	String = MetadataObjectsRights.Add();
	String.Collection         = "InformationRegisters";
	String.InsertRight1   = False;
	String.EditRight    = True;
	
	String = MetadataObjectsRights.Add();
	String.Collection         = "AccumulationRegisters";
	String.InsertRight1   = False;
	String.EditRight    = True;
	
	String = MetadataObjectsRights.Add();
	String.Collection         = "AccountingRegisters";
	String.InsertRight1   = False;
	String.EditRight    = True;
	
	String = MetadataObjectsRights.Add();
	String.Collection         = "CalculationRegisters";
	String.InsertRight1   = False;
	String.EditRight    = True;
	
	String = MetadataObjectsRights.Add();
	String.Collection         = "BusinessProcesses";
	String.InsertRight1   = True;
	String.EditRight    = True;
	
	String = MetadataObjectsRights.Add();
	String.Collection         = "Tasks";
	String.InsertRight1   = True;
	String.EditRight    = True;
	
	Return MetadataObjectsRights;
	
EndFunction

// Returns object metadata fields that can be used to restrict access.
//
// Parameters:
//  MetadataObject   - MetadataObject - an object that requires returning fields.
//  IBObject           - Undefined - use the current configuration,
//                     - COMObject - use COM connection to configuration.
//  GetNamesArray - Boolean - a result type.
//
// Returns:
//  String - comma-separated names, if GetNamesArray = False.
//  Array - an array with values of the String type if GetNamesArray = True.
//
Function AllFieldsOfMetadataObjectAccessRestriction(MetadataObject,
			FullName, IBObject = Undefined, GetNamesArray = False) Export
	
	FieldsNames = New Array;
	CollectionsNames = New Array;
	NameParts = StrSplit(FullName, ".");
	TypeName = NameParts[0];
	
	If TypeName = "Catalog" Then
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("TabularSections");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "Document" Then
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("TabularSections");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "DocumentJournal" Then
		CollectionsNames.Add("Columns");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "ChartOfCharacteristicTypes" Then
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("TabularSections");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "ChartOfAccounts" Then
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("TabularSections");
		CollectionsNames.Add("AccountingFlags");
		CollectionsNames.Add("StandardAttributes");
		CollectionsNames.Add("StandardTabularSections");
		
	ElsIf TypeName = "ChartOfCalculationTypes" Then
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("TabularSections");
		CollectionsNames.Add("StandardAttributes");
		CollectionsNames.Add("StandardTabularSections");
		
	ElsIf TypeName = "InformationRegister" Then
		CollectionsNames.Add("Dimensions");
		CollectionsNames.Add("Resources");
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "AccumulationRegister" Then
		CollectionsNames.Add("Dimensions");
		CollectionsNames.Add("Resources");
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "AccountingRegister" Then
		CollectionsNames.Add("Dimensions");
		CollectionsNames.Add("Resources");
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "CalculationRegister" Then
		If NameParts.Count() > 2 And NameParts[2] = "Recalculation" Then
			AddFieldOfMetadataObjectAccessRestriction(MetadataObject,
				"RecalculationObject", FieldsNames, IBObject);
			AddFieldOfMetadataObjectAccessRestriction(MetadataObject,
				"CalculationType", FieldsNames, IBObject);
			CollectionsNames.Add("Dimensions");
		Else
			CollectionsNames.Add("Dimensions");
			CollectionsNames.Add("Resources");
			CollectionsNames.Add("Attributes");
			CollectionsNames.Add("StandardAttributes");
		EndIf;
		
	ElsIf TypeName = "BusinessProcess" Then
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("TabularSections");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "Task" Then
		CollectionsNames.Add("AddressingAttributes");
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("TabularSections");
		CollectionsNames.Add("StandardAttributes");
	EndIf;
	
	If IBObject = Undefined Then
		ValueStorageType = Type("ValueStorage");
	Else
		ValueStorageType = IBObject.NewObject("TypeDescription", "ValueStorage").Types().Get(0);
	EndIf;

	For Each CollectionName In CollectionsNames Do
		If CollectionName = "TabularSections"
		 Or CollectionName = "StandardTabularSections" Then
			For Each TabularSection In MetadataObject[CollectionName] Do
				If TypeName = "ChartOfAccounts" And CollectionName = "StandardTabularSections" And TabularSection.Name = "ExtDimensionTypes" Then
					Continue;
				EndIf;
				AddFieldOfMetadataObjectAccessRestriction(MetadataObject, TabularSection.Name, FieldsNames, IBObject);
				Attributes = ?(CollectionName = "TabularSections", TabularSection.Attributes, TabularSection.StandardAttributes);
				For Each Field In Attributes Do
					If Field.Type.ContainsType(ValueStorageType) Then
						Continue;
					EndIf;
					AddFieldOfMetadataObjectAccessRestriction(MetadataObject, TabularSection.Name + "." + Field.Name, FieldsNames, IBObject);
				EndDo;
				If CollectionName = "StandardTabularSections" And TabularSection.Name = "ExtDimensionTypes" Then
					For Each Field In MetadataObject.ExtDimensionAccountingFlags Do
						AddFieldOfMetadataObjectAccessRestriction(MetadataObject, "ExtDimensionTypes." + Field.Name, FieldsNames, IBObject);
					EndDo;
				EndIf;
			EndDo;
		Else
			For Each Field In MetadataObject[CollectionName] Do
				If TypeName = "DocumentJournal"       And Field.Name = "Type"
				 Or TypeName = "ChartOfCharacteristicTypes" And Field.Name = "ValueType"
				 Or TypeName = "ChartOfAccounts"             And Field.Name = "Kind"
				 Or TypeName = "AccumulationRegister"      And Field.Name = "RecordType"
				 Or TypeName = "AccountingRegister"     And CollectionName = "StandardAttributes"
				   And StrFind(Field.Name, "ExtDimension") > 0 Then
					Continue;
				EndIf;
				If CollectionName = "Columns" Then
					Continue;
				EndIf;
				PropertyType = New Structure("Type");
				FillPropertyValues(PropertyType, Field);
				If TypeOf(PropertyType.Type) = Type("TypeDescription")
				   And PropertyType.Type.ContainsType(ValueStorageType) Then
					Continue;
				EndIf;
				If (CollectionName = "Dimensions" Or CollectionName = "Resources")
				   And ?(IBObject = Undefined, Metadata,
				           IBObject.Metadata).AccountingRegisters.Contains(MetadataObject)
				   And MetadataObject.Correspondence
				   And Not Field.Balance Then
					AddFieldOfMetadataObjectAccessRestriction(MetadataObject,
						Field.Name + "Dr", FieldsNames, IBObject);
					AddFieldOfMetadataObjectAccessRestriction(MetadataObject,
						Field.Name + "Cr", FieldsNames, IBObject);
				Else
					AddFieldOfMetadataObjectAccessRestriction(MetadataObject,
						Field.Name, FieldsNames, IBObject);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	If GetNamesArray Then
		Return FieldsNames;
	EndIf;
	
	FieldList = "";
	For Each FieldName In FieldsNames Do
		FieldList = FieldList + ", " + FieldName;
	EndDo;
	
	Return Mid(FieldList, 3);
	
EndFunction

Procedure AddFieldOfMetadataObjectAccessRestriction(MetadataObject, FieldName,
			FieldsNames, IBObject)
	
	Try
		If IBObject = Undefined Then
			AccessParameters("Read",
				MetadataObject, FieldName, Metadata.Roles.FullAccess);
		Else
			IBObject.AccessParameters("Read",
				MetadataObject, FieldName, IBObject.Metadata.Roles.FullAccess);
		EndIf;
		CanGetAccessParameters = True;
	Except
		// Some fields that cannot be used to configure read restrictions might cause errors
		// when trying to get access parameters.
		// Such fields must be excluded as they shouldn't be checked for access restrictions.
		CanGetAccessParameters = False;
	EndTry;
	
	If CanGetAccessParameters Then
		FieldsNames.Add(FieldName);
	EndIf;
	
EndProcedure

Function ChangesQuery(ExtensionsObjects) Export
	
	AvailableMetadataObjectsRights = AvailableMetadataObjectsRights();
	RolesRights = RolesRightsTable(ExtensionsObjects);
	
	Roles = New Array;
	FullMetadataObjectsNames = New Array;
	For Each Role In Metadata.Roles Do
		If ExtensionsObjects Then
			If Role.ConfigurationExtension() = Undefined
			   And Not Role.ChangedByConfigurationExtensions() Then
				Continue;
			EndIf;
		ElsIf Role.ConfigurationExtension() <> Undefined Then
			Continue;
		EndIf;
		Roles.Add(Role);
		FullMetadataObjectsNames.Add(Role.FullName());
	EndDo;
	
	For Each AvailableRights In AvailableMetadataObjectsRights Do
		For Each MetadataObject In Metadata[AvailableRights.Collection] Do
			
			If Not ExtensionsObjects
			   And MetadataObject.ConfigurationExtension() <> Undefined Then
				Continue;
			EndIf;
			
			FullName = MetadataObject.FullName();
			FullMetadataObjectsNames.Add(FullName);
			Fields = Undefined;
			
			For Each Role In Roles Do
				
				If Not AccessRight("Read", MetadataObject, Role) Then
					Continue;
				EndIf;
				
				If Fields = Undefined Then
					Fields = AllFieldsOfMetadataObjectAccessRestriction(MetadataObject, FullName);
				EndIf;
				
				NewRow = RolesRights.Add();
				NewRow.RoleFullName = Role.FullName();
				NewRow.MetadataObjectFullName = FullName;
				
				NewRow.UnrestrictedReadRight = Not AccessParameters("Read",
					MetadataObject, Fields, Role).RestrictionByCondition;
				NewRow.ViewRight = AccessRight("View", MetadataObject, Role);
				
				If AvailableRights.InsertRight1
				   And AccessRight("Insert", MetadataObject, Role) Then
					
					NewRow.AddRight = True;
					NewRow.UnrestrictedAddRight = Not AccessParameters("Insert",
						MetadataObject, Fields, Role).RestrictionByCondition;
					NewRow.InteractiveAddRight =
						AccessRight("InteractiveInsert", MetadataObject, Role);
				EndIf;
				
				If AvailableRights.EditRight
				   And AccessRight("Update", MetadataObject, Role) Then
					
					NewRow.RightUpdate = True;
					NewRow.UnrestrictedUpdateRight = Not AccessParameters("Update",
						MetadataObject, Fields, Role).RestrictionByCondition;
					NewRow.EditRight =
						AccessRight("Edit", MetadataObject, Role);
				EndIf;
			EndDo;
			
		EndDo;
	EndDo;
	
	ObjectsIDs = Common.MetadataObjectIDs(FullMetadataObjectsNames);
	For Each String In RolesRights Do
		String.Role             = ObjectsIDs.Get(String.RoleFullName);
		String.MetadataObject = ObjectsIDs.Get(String.MetadataObjectFullName);
	EndDo;
	
	TemporaryTablesQueriesText =
	"SELECT
	|	NewData.MetadataObject,
	|	NewData.Role,
	|	NewData.AddRight,
	|	NewData.RightUpdate,
	|	NewData.UnrestrictedReadRight,
	|	NewData.UnrestrictedAddRight,
	|	NewData.UnrestrictedUpdateRight,
	|	NewData.ViewRight,
	|	NewData.InteractiveAddRight,
	|	NewData.EditRight
	|INTO NewData
	|FROM
	|	&RolesRights AS NewData";
	
	QueryText =
	"SELECT
	|	NewData.MetadataObject,
	|	NewData.Role,
	|	NewData.AddRight,
	|	NewData.RightUpdate,
	|	NewData.UnrestrictedReadRight,
	|	NewData.UnrestrictedAddRight,
	|	NewData.UnrestrictedUpdateRight,
	|	NewData.ViewRight,
	|	NewData.InteractiveAddRight,
	|	NewData.EditRight,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	RolesFilterValue = ?(ExtensionsObjects, "&RoleFilterCriterion", Undefined);
	
	// Preparing the selected fields with optional filter.
	Fields = New Array;
	Fields.Add(New Structure("MetadataObject"));
	Fields.Add(New Structure("Role", RolesFilterValue));
	Fields.Add(New Structure("AddRight"));
	Fields.Add(New Structure("RightUpdate"));
	Fields.Add(New Structure("UnrestrictedReadRight"));
	Fields.Add(New Structure("UnrestrictedAddRight"));
	Fields.Add(New Structure("UnrestrictedUpdateRight"));
	Fields.Add(New Structure("ViewRight"));
	Fields.Add(New Structure("InteractiveAddRight"));
	Fields.Add(New Structure("EditRight"));
	
	Query = New Query;
	Query.SetParameter("RolesRights", RolesRights);
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.RolesRights", TemporaryTablesQueriesText);
		
	If ExtensionsObjects Then
		Table = RolesRights.Copy(, "Role");
		Table.GroupBy("Role");
		ModifiedRoles = Table.UnloadColumn("Role");
		AccessManagementInternal.SetFilterCriterionInQuery(Query, ModifiedRoles, "ModifiedRoles",
			"&RoleFilterCriterion:OldData.Role");
	EndIf;
	
	Return Query;
	
EndFunction

// Generates a blank table of role rights.
//
// Returns:
//  ValueTable:
//    * MetadataObject - CatalogRef.MetadataObjectIDs
//    * Role - CatalogRef.MetadataObjectIDs
//    * RightUpdate - Boolean
//    * AddRight - Boolean
//    * UnrestrictedReadRight - Boolean
//    * UnrestrictedUpdateRight - Boolean
//    * UnrestrictedAddRight - Boolean
//    * ViewRight - Boolean
//    * EditRight - Boolean
//    * InteractiveAddRight - Boolean
//    * RoleFullName - String
//    * MetadataObjectFullName - String
//
Function RolesRightsTable(ExtensionsObjects = False, LineChangeType = False, AsQueryResult = False) Export
	
	RolesRights = CreateRecordSet().Unload();
	If Not AsQueryResult Then
		RolesRights.Columns.Add("RoleFullName",             New TypeDescription("String"));
		RolesRights.Columns.Add("MetadataObjectFullName", New TypeDescription("String"));
	EndIf;
	
	If ExtensionsObjects Then
		// If a table is used for extension objects, extend the type of the columns "Role" and
		// "MetadataObject" with the type "CatalogRef.ExtensionObjectIDs".
		
		Types = New Array;
		Types.Add(Type("CatalogRef.MetadataObjectIDs"));
		Types.Add(Type("CatalogRef.ExtensionObjectIDs"));
		
		SetTypesForColumn(RolesRights, "Role", Types);
		SetTypesForColumn(RolesRights, "MetadataObject", Types);
	EndIf;
	
	If LineChangeType Then
		RolesRights.Columns.Add("LineChangeType", New TypeDescription("Number"));
	EndIf;
	
	If AsQueryResult Then
		For Each Column In RolesRights.Columns Do
			Types = Column.ValueType.Types();
			Types.Add(Type("Null"));
			SetTypesForColumn(RolesRights, Column.Name, Types);
		EndDo;
	EndIf;
	
	Return RolesRights;
	
EndFunction

// It is required by the RolesRightsTable function.
Procedure SetTypesForColumn(Table, ColumnName, Types)
	
	Column = Table.Columns[ColumnName];
	ColumnProperties = New Structure("Name, Title, Width");
	FillPropertyValues(ColumnProperties, Column);
	IndexOf = Table.Columns.IndexOf(Column);
	Table.Columns.Delete(IndexOf);
	
	Table.Columns.Insert(IndexOf, ColumnProperties.Name, New TypeDescription(Types),
		ColumnProperties.Title, ColumnProperties.Width);
	
EndProcedure

Function ChangedMetadataObjects(Changes) Export
	
	Changes.GroupBy("MetadataObject, Role, AddRight, RightUpdate, "
			+ "UnrestrictedReadRight, UnrestrictedAddRight, UnrestrictedUpdateRight",
		"LineChangeType");
	
	UnnecessaryRows = Changes.FindRows(New Structure("LineChangeType", 0));
	For Each String In UnnecessaryRows Do
		Changes.Delete(String);
	EndDo;
	
	Changes.GroupBy("MetadataObject");
	
	Return New FixedArray(Changes.UnloadColumn("MetadataObject"));
	
EndFunction

Function HasRolesModifiedByExtensions()
	
	For Each Role In Metadata.Roles Do
		If Role.ChangedByConfigurationExtensions() Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

#EndRegion

#EndIf
