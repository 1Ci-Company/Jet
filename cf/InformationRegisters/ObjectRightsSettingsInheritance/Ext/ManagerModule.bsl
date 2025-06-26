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

// Updates a hierarchy of object right setting owners.
// For example, a hierarchy of the FilesFolders catalog items.
//
// Parameters:
//  RightsSettingsOwners - DefinedType.RightsSettingsOwner - for example, CatalogRef.FilesFolders
//                          or another type used to configure the rights directly.
//                        - Array - array of values of the types specified above.
//                        - Undefined - no filtering for all types.
//                        - DefinedType.RightsSettingsOwnerObject - — for example, CatalogObject.FilesFolders,
//                          when passing an object, update is possible only if the object is to be written and
//                          the parent is changed.
//
//  HasChanges         - Boolean - (return value) - if recorded,
//                          True is set, otherwise, it does not change.
//
Procedure UpdateRegisterData(Val RightsSettingsOwners = Undefined, HasChanges = Undefined) Export
	
	If RightsSettingsOwners = Undefined Then
		AvailableRights = AccessManagementInternal.RightsForObjectsRightsSettingsAvailable();
		
		Query = New Query;
		QueryText =
		"SELECT
		|	CurrentTable.Ref
		|FROM
		|	&CurrentTable AS CurrentTable";
		
		For Each KeyAndValue In AvailableRights.ByFullNames Do
			
			Query.Text = StrReplace(QueryText, "&CurrentTable", KeyAndValue.Key);
			// @skip-check query-in-loop - A minor loop (1 or 2 iterations)
			Selection = Query.Execute().Select();
			
			While Selection.Next() Do
				// @skip-check query-in-loop - Iterate through an item hierarchy with batch updates.
				UpdateOwnerParents(Selection.Ref, HasChanges);
			EndDo;
		EndDo;
		
	ElsIf TypeOf(RightsSettingsOwners) = Type("Array") Then
		
		For Each RightsSettingsOwner In RightsSettingsOwners Do
			// @skip-check query-in-loop - Iterate through an item hierarchy with batch updates.
			UpdateOwnerParents(RightsSettingsOwner, HasChanges);
		EndDo;
	Else
		UpdateOwnerParents(RightsSettingsOwners, HasChanges);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Updates parents of object right settings owner.
// For example, the FilesFolders catalog.
// 
// Parameters:
//  RightsSettingsOwner - DefinedType.RightsSettingsOwner - for example, CatalogRef.FilesFolders
//                          or another type used to configure the rights directly.
//                       - DefinedType.RightsSettingsOwnerObject - — for example, CatalogObject.FilesFolders,
//                         when passing an object, update is possible only if the object is to be written and
//                         the parent is changed.
//
//  HasChanges        - Boolean - (return value) - if recorded,
//                         True is set, otherwise, it does not change.
//
//  UpdateHierarchy     - Boolean - updates the subordinate hierarchy forcibly,
//                         regardless of any changes to owner parents.
//
//  ObjectsWithChanges  - Array - for internal use only.
//
Procedure UpdateOwnerParents(RightsSettingsOwner, HasChanges = False, UpdateHierarchy = False, ObjectsWithChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	AvailableRights = AccessManagementInternal.RightsForObjectsRightsSettingsAvailable();
	OwnerType = TypeOf(RightsSettingsOwner);
	
	ErrorTitle =
		NStr("en = 'An error occurred when updating the hierarchy of rights owners by Access Values.';")
		+ Chars.LF
		+ Chars.LF;
	
	If AvailableRights.ByTypes.Get(OwnerType) = Undefined Then
		Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'No object rights settings are specified
			           |for the ""%1"" type.';"),
			String(OwnerType));
	EndIf;
	
	If AvailableRights.ByRefsTypes.Get(OwnerType) = Undefined Then
		Ref = UsersInternal.ObjectRef2(RightsSettingsOwner);
		Object = RightsSettingsOwner;
	Else
		Ref = RightsSettingsOwner;
		Object = Undefined;
	EndIf;
	
	Hierarchical = AvailableRights.HierarchicalTables.Get(OwnerType) <> Undefined;
	UpdateRequired = False;
	
	If Hierarchical Then
		ObjectParentProperties = ParentProperties(Ref);
		
		If Object <> Undefined Then
			// Check for object modifications.
			If ObjectParentProperties.Ref <> Object.Parent Then
				UpdateRequired = True;
			EndIf;
			ObjectParentProperties.Ref      = Object.Parent;
			ObjectParentProperties.Inherit = SettingsInheritance(Object.Parent);
		Else
			UpdateRequired = True;
		EndIf;
	Else
		If Object = Undefined Then
			UpdateRequired = True;
		EndIf;
	EndIf;
	
	If Not UpdateRequired Then
		Return;
	EndIf;
	
	Block = New DataLock;
	Block.Add("InformationRegister.ObjectRightsSettingsInheritance");
	
	If Object = Undefined Then
		AdditionalProperties = Undefined;
	Else
		AdditionalProperties = New Structure("LeadingObjectBeforeWrite", Object);
	EndIf;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		RecordSet = CreateRecordSet();
		RecordSet.Filter.Object.Set(Ref);
		
		// Prepare parent objects.
		If Hierarchical Then
			NewRecords = ObjectParents(Ref, Ref, ObjectParentProperties);
		Else
			NewRecords = AccessManagementInternalCached.BlankRecordSetTable(
				Metadata.InformationRegisters.ObjectRightsSettingsInheritance.FullName()).Get(); // ValueTable
			
			NewRow = NewRecords.Add();
			NewRow.Object   = Ref;
			NewRow.Parent = Ref;
		EndIf;
		
		Data = New Structure;
		Data.Insert("RecordSet",           RecordSet);
		Data.Insert("NewRecords",            NewRecords);
		Data.Insert("AdditionalProperties", AdditionalProperties);
		
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateRecordSet(Data, HasCurrentChanges);
		
		If HasCurrentChanges Then
			HasChanges = True;
			
			If ObjectsWithChanges <> Undefined Then
				ObjectsWithChanges.Add(Ref);
			EndIf;
		EndIf;
		
		If Hierarchical And (HasCurrentChanges Or UpdateHierarchy) Then
			UpdateOwnerHierarchy(Ref, HasChanges, ObjectsWithChanges);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If ObjectsWithChanges <> Undefined Then
		ObjectsWithChanges = CommonClientServer.CollapseArray(ObjectsWithChanges);
	EndIf;
	
EndProcedure

// Fills RecordSet with object parents including itself as a parent.
//
// Parameters:
//  Ref                  - DefinedType.RightsSettingsOwner - a reference in the ObjectRef hierarchy or ObjectRef.
//  ObjectRef2           - DefinedType.RightsSettingsOwner
//                          - Undefined - a reference to the initial object.
//  ObjectParentProperties - Structure:
//                            * Ref      - DefinedType.RightsSettingsOwner - a reference to the source object parent
//                                            that can differ from the parent
//                                            recorded in the database.
//                            * Inherit - Boolean - inheriting settings by the parent.
//  GetInheritance    - Boolean
//
// Returns:
//  InformationRegisterRecordSet.ObjectRightsSettingsInheritance
//
Function ObjectParents(Ref, ObjectRef2 = Undefined, ObjectParentProperties = "", GetInheritance = True) Export
	
	NewRecords = AccessManagementInternalCached.BlankRecordSetTable(
		Metadata.InformationRegisters.ObjectRightsSettingsInheritance.FullName()).Get(); // ValueTable
	
	// Getting an inheritance flag of parent rights settings for the reference.
	If GetInheritance Then
		Inherit = SettingsInheritance(Ref);
	Else
		Inherit = True;
		NewRecords.Columns.Add("Level", New TypeDescription("Number"));
	EndIf;
	
	String = NewRecords.Add();
	String.Object      = Ref;
	String.Parent    = Ref;
	String.Inherit = Inherit;
	
	If Not Inherit Then
		Return NewRecords;
	EndIf;
	
	If Ref = ObjectRef2 Then
		CurrentParentProperties = ObjectParentProperties;
	Else
		CurrentParentProperties = ParentProperties(Ref);
	EndIf;
	
	While ValueIsFilled(CurrentParentProperties.Ref) Do
	
		String = NewRecords.Add();
		String.Object   = Ref;
		String.Parent = CurrentParentProperties.Ref;
		String.UsageLevel = 1;
		
		If Not GetInheritance Then
			String.Level = String.Parent.Level();
		EndIf;
		
		If Not CurrentParentProperties.Inherit Then
			Break;
		EndIf;
		
		// @skip-check query-in-loop - Iterate through an item hierarchy with batch updates.
		CurrentParentProperties = ParentProperties(CurrentParentProperties.Ref);
	EndDo;
	
	Return NewRecords;
	
EndFunction

Function SettingsInheritance(Ref) Export
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	
	Query.Text =
	"SELECT
	|	SettingsInheritance.Inherit
	|FROM
	|	InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|WHERE
	|	SettingsInheritance.Object = &Ref
	|	AND SettingsInheritance.Parent = &Ref";
	
	Selection = Query.Execute().Select();
	
	Return ?(Selection.Next(), Selection.Inherit, True);
	
EndFunction

// For the UpdateOwnerParents procedure.
Procedure UpdateOwnerHierarchy(Ref, HasChanges, ObjectsWithChanges)
	
	// Updating the list of item parents in the current value hierarchy.
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	|	TableWithHierarchy.Ref AS SubordinateRef
	|FROM
	|	&TableWithHierarchy AS TableWithHierarchy
	|WHERE
	|	TableWithHierarchy.Ref IN HIERARCHY(&Ref)
	|	AND TableWithHierarchy.Ref <> &Ref";
	
	Query.Text = StrReplace(
		Query.Text, "&TableWithHierarchy", Ref.Metadata().FullName() );
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		// @skip-check query-in-loop - Iterate through an item hierarchy with batch updates.
		NewRecords = ObjectParents(Selection.SubordinateRef, Ref);
		
		RecordSet = CreateRecordSet();
		RecordSet.Filter.Object.Set(Selection.SubordinateRef);
		
		Data = New Structure;
		Data.Insert("RecordSet", RecordSet);
		Data.Insert("NewRecords",  NewRecords);
		
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateRecordSet(Data, HasCurrentChanges);
		
		If HasCurrentChanges Then
			HasChanges = True;
			
			If ObjectsWithChanges <> Undefined Then
				ObjectsWithChanges.Add(Ref);
			EndIf;
		EndIf;
		
	EndDo;
	
EndProcedure

// For the UpdateOwnerParents and ObjectParents procedures.
Function ParentProperties(Ref)
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	|	CurrentTable.Parent
	|INTO RefParent
	|FROM
	|	ObjectsTable AS CurrentTable
	|WHERE
	|	CurrentTable.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RefParent.Parent
	|FROM
	|	RefParent AS RefParent
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Parents.Inherit AS Inherit
	|FROM
	|	InformationRegister.ObjectRightsSettingsInheritance AS Parents
	|WHERE
	|	Parents.Object = Parents.Parent
	|	AND Parents.Object IN
	|			(SELECT
	|				RefParent.Parent
	|			FROM
	|				RefParent AS RefParent)";
	
	Query.Text = StrReplace(Query.Text, "ObjectsTable", Ref.Metadata().FullName());
	
	QueryResults = Query.ExecuteBatch(); // Array of QueryResult 
	
	Selection = QueryResults[1].Select();
	Parent = ?(Selection.Next(), Selection.Parent, Undefined);
	
	Selection = QueryResults[2].Select();
	Inherit = ?(Selection.Next(), Selection.Inherit, True);
	
	Return New Structure("Ref, Inherit", Parent, Inherit);
	
EndFunction

#EndRegion

#EndIf
