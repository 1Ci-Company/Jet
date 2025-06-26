///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

// Determines the profile assignment.
//
// Parameters:
//  Profile - CatalogObject.AccessGroupProfiles - a profile with the Assignment tabular section.
//          - FormDataStructure   - a profile object structure in the form.
//          - Structure              - a built-in profile details.
//          - FixedStructure - a built-in profile details.
//
// Returns:
//  String - ForAdministrators, ForUsers, ForExternalUsers,
//            BothForUsersAndExternalUsers.
//
Function ProfileAssignment(Profile) Export
	
	AssignmentForUsers = False;
	AssignmentForExternalUsers = False;
	
	For Each AssignmentDetails In Profile.Purpose Do
		If TypeOf(Profile.Purpose) = Type("Array")
		 Or TypeOf(Profile.Purpose) = Type("FixedArray") Then
			Type = TypeOf(AssignmentDetails);
		Else
			Type = TypeOf(AssignmentDetails.UsersType);
		EndIf;
		If Type = Type("CatalogRef.Users") Then
			AssignmentForUsers = True;
		EndIf;
		If Type <> Type("CatalogRef.Users") And Type <> Undefined Then
			AssignmentForExternalUsers = True;
		EndIf;
	EndDo;
	
	If AssignmentForUsers And AssignmentForExternalUsers Then
		Return "BothForUsersAndExternalUsers";
		
	ElsIf AssignmentForExternalUsers Then
		Return "ForExternalUsers";
	EndIf;
	
	Return "ForAdministrators";
	
EndFunction

// Checks whether the access kind matches the profile assignment.
//
// Parameters:
//  AccessKind        - String - Access kind name.
//                    - DefinedType.AccessValue - Access kind value type.
//  ProfileAssignment - String - returned by the ProfileAssignment function.
//  
// Returns:
//  Boolean
//
Function AccessKindMatchesProfileAssignment(Val AccessKind, ProfileAssignment) Export
	
	If AccessKind = "Users"
	 Or TypeOf(AccessKind) = Type("CatalogRef.Users") Then
		
		Return ProfileAssignment <> "BothForUsersAndExternalUsers"
		      And ProfileAssignment <> "ForExternalUsers";
		
	ElsIf AccessKind = "ExternalUsers"
	      Or TypeOf(AccessKind) = Type("CatalogRef.ExternalUsers") Then
		
		Return ProfileAssignment = "ForExternalUsers";
	EndIf;
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Management of AccessKinds and AccessValues tables in edit forms.

// For internal use only.
Procedure FillAllAllowedPresentation(Form, AccessKindDetails, AddValuesCount = True) Export
	
	Parameters = AllowedValuesEditFormParameters(Form);
	
	If AccessKindDetails.AllAllowed Then
		If Form.IsAccessGroupProfile And Not AccessKindDetails.Predefined Then
			Name = "AllAllowedByDefault";
		Else
			Name = "AllAllowed";
		EndIf;
	Else
		If Form.IsAccessGroupProfile And Not AccessKindDetails.Predefined Then
			Name = "AllDeniedByDefault";
		Else
			Name = "AllDenied";
		EndIf;
	EndIf;
	
	AccessKindDetails.AllAllowedPresentation =
		Form.PresentationsAllAllowed.FindRows(New Structure("Name", Name))[0].Presentation;
	
	If Not AddValuesCount Then
		Return;
	EndIf;
	
	If Form.IsAccessGroupProfile And Not AccessKindDetails.Predefined Then
		Return;
	EndIf;
	
	Filter = FilterInAllowedValuesEditFormTables(Form, AccessKindDetails.AccessKind);
	
	ValuesCount = Parameters.AccessValues.FindRows(Filter).Count();
	
	If Form.IsAccessGroupProfile Then
		If ValuesCount = 0 Then
			NumberAndSubject = NStr("en = 'not assigned';");
		Else
			NumberAndSubject = Format(ValuesCount, "NG=") + " "
				+ UsersInternalClientServer.IntegerSubject(ValuesCount,
					"", NStr("en = 'value,values,,,0';"));
		EndIf;
		
		AccessKindDetails.AllAllowedPresentation =
			AccessKindDetails.AllAllowedPresentation
				+ " (" + NumberAndSubject + ")";
		Return;
	EndIf;
	
	If ValuesCount = 0 Then
		Presentation = ?(AccessKindDetails.AllAllowed,
			NStr("en = 'All allowed, no exceptions';"),
			NStr("en = 'All denied, no exceptions';"));
	Else
		NumberAndSubject = Format(ValuesCount, "NG=") + " "
			+ UsersInternalClientServer.IntegerSubject(ValuesCount,
				"", NStr("en = 'value,values,,,0';"));
		
		Presentation = StringFunctionsClientServer.SubstituteParametersToString(
			?(AccessKindDetails.AllAllowed,
				NStr("en = 'All allowed, except %1';"),
				NStr("en = 'All denied, except %1';")),
			NumberAndSubject);
	EndIf;
	
	AccessKindDetails.AllAllowedPresentation = Presentation;
	
EndProcedure

// For internal use only.
Procedure FillNumbersOfAccessValuesRowsByKind(Form, AccessKindDetails) Export
	
	Parameters = AllowedValuesEditFormParameters(Form);
	
	Filter = FilterInAllowedValuesEditFormTables(Form, AccessKindDetails.AccessKind);
	AccessValuesByKind = Parameters.AccessValues.FindRows(Filter);
	
	CurrentNumber = 1;
	For Each String In AccessValuesByKind Do
		String.RowNumberByKind = CurrentNumber;
		CurrentNumber = CurrentNumber + 1;
	EndDo;
	
EndProcedure

// For internal use only.
//
// Parameters:
//  Form - See AllowedValuesEditFormParameters
//  ProcessingAtClient - Boolean
//
Procedure OnChangeCurrentAccessKind(Form, ProcessingAtClient = True) Export
	
	Items = Form.Items;
	Parameters = AllowedValuesEditFormParameters(Form);
	
	CanEditValues = False;
	
	If ProcessingAtClient Then
		CurrentData = Items.AccessKinds.CurrentData;
	Else
		CurrentData = Parameters.AccessKinds.FindByID(
			?(Items.AccessKinds.CurrentRow = Undefined, -1, Items.AccessKinds.CurrentRow));
	EndIf;
	
	If CurrentData <> Undefined Then
		
		If CurrentData.AccessKind <> Undefined
		   And Not CurrentData.Used Then
			
			If Not Items.AccessKindNotUsedText.Visible Then
				Items.AccessKindNotUsedText.Visible = True;
			EndIf;
		Else
			If Items.AccessKindNotUsedText.Visible Then
				Items.AccessKindNotUsedText.Visible = False;
			EndIf;
		EndIf;
		
		Form.CurrentAccessKind = CurrentData.AccessKind;
		
		If Not Form.IsAccessGroupProfile Or CurrentData.Predefined Then
			CanEditValues = True;
		EndIf;
		
		If CanEditValues Then
			
			If Form.IsAccessGroupProfile Then
				Items.AccessKindsTypes.CurrentPage = Items.PresetAccessKind;
			EndIf;
			
			// Set a value filter.
			RefreshRowsFilter = False;
			RowFilter = Items.AccessValues.RowFilter;
			Filter = FilterInAllowedValuesEditFormTables(Form, CurrentData.AccessKind);
			
			If RowFilter = Undefined Then
				RefreshRowsFilter = True;
				
			ElsIf Filter.Property("AccessGroup") And RowFilter.AccessGroup <> Filter.AccessGroup Then
				RefreshRowsFilter = True;
				
			ElsIf RowFilter.AccessKind <> Filter.AccessKind
			        And Not (RowFilter.AccessKind = "" And Filter.AccessKind = Undefined) Then
				
				RefreshRowsFilter = True;
			EndIf;
			
			If RefreshRowsFilter Then
				If CurrentData.AccessKind = Undefined Then
					Filter.AccessKind = "";
				EndIf;
				Items.AccessValues.RowFilter = New FixedStructure(Filter);
			EndIf;
			
		ElsIf Form.IsAccessGroupProfile Then
			Items.AccessKindsTypes.CurrentPage = Items.NormalAccessKind;
		EndIf;
		
		If CurrentData.AccessKind = Form.AccessKindUsers
		 Or CurrentData.AccessKind = Form.AccessKindExternalUsers Then
			
			LabelPattern = ?(CurrentData.AllAllowed,
				NStr("en = 'Forbidden values (%1): Authorized user and their groups are always allowed';"),
				NStr("en = 'Allowed values (%1): Authorized user and their groups are always allowed';") );
		Else
			LabelPattern = ?(CurrentData.AllAllowed,
				NStr("en = 'Denied values (%1)';"),
				NStr("en = 'Allowed values (%1)';") );
		EndIf;
		
		// Refresh the field AccessKindLabel.
		Form.AccessKindLabel = StringFunctionsClientServer.SubstituteParametersToString(LabelPattern,
			String(CurrentData.AccessKindPresentation));
		
		FillAllAllowedPresentation(Form, CurrentData);
		
	Else
		If Items.AccessKindNotUsedText.Visible Then
			Items.AccessKindNotUsedText.Visible = False;
		EndIf;
		
		Form.CurrentAccessKind = Undefined;
		Items.AccessValues.RowFilter = New FixedStructure(
			FilterInAllowedValuesEditFormTables(Form, Undefined));
		
		If Parameters.AccessKinds.Count() = 0 Then
			Parameters.AccessValues.Clear();
		EndIf;
	EndIf;
	
	Form.CurrentTypeOfValuesToSelect  = Undefined;
	Form.CurrentTypesOfValuesToSelect = New ValueList;
	
	If CanEditValues Then
		Filter = New Structure("AccessKind", CurrentData.AccessKind);
		AccessKindsTypesDetails = Form.AllTypesOfValuesToSelect.FindRows(Filter);
		HierarchyOfItems = True;
		For Each AccessKindTypeDetails In AccessKindsTypesDetails Do
			
			Form.CurrentTypesOfValuesToSelect.Add(
				AccessKindTypeDetails.ValuesType,
				AccessKindTypeDetails.TypePresentation);
				
			HierarchyOfItems = HierarchyOfItems And AccessKindTypeDetails.HierarchyOfItems;
		EndDo;
		
		Items.AccessValuesIncludeSubordinateAccessValues.Visible = HierarchyOfItems;
	Else
		If CurrentData <> Undefined Then
			
			Filter = FilterInAllowedValuesEditFormTables(
				Form, CurrentData.AccessKind);
			
			For Each String In Parameters.AccessValues.FindRows(Filter) Do
				Parameters.AccessValues.Delete(String);
			EndDo
		EndIf;
	EndIf;
	
	If Form.CurrentTypesOfValuesToSelect.Count() = 0 Then
		Form.CurrentTypesOfValuesToSelect.Add(Undefined, NStr("en = 'Undefined';"));
	EndIf;
	
	Items.AccessValues.Enabled = CanEditValues;
	
EndProcedure

// For internal use only.
// See AccessManagementInternal.OnCreateAtServerAllowedValuesEditForm
//
// Returns:
//   ClientApplicationForm:
//     * Items - FormAllItems:
//         ** Purpose                - FormTable
//         ** AccessKinds               - FormTable
//         ** AccessValues           - FormTable
//         ** AllAccessKinds            - FormTable
//         ** PresentationsAllAllowed - FormTable
//         ** AllTypesOfValuesToSelect - FormTable
//     * CurrentAccessGroup                - CatalogRef.AccessGroups
//     * Purpose                          - See PurposeFromForm
//     * AccessKinds                         - See AccessKindsFromForm
//     * AccessValues                     - See AccessValuesFromForm
//     * UseExternalUsers    - Boolean - an attribute will be created if it is not in the form
//     * AccessKindLabel                   - String - a presentation of the current access kind in the form
//     * IsAccessGroupProfile              - Boolean
//     * CurrentAccessKind                   - DefinedType.AccessValue
//     * CurrentTypesOfValuesToSelect       - ValueList
//     * CurrentTypeOfValuesToSelect        - DefinedType.AccessValue
//     * TablesStorageAttributeName         - String
//     * AccessKindUsers              - DefinedType.AccessValue
//     * AccessKindExternalUsers       - DefinedType.AccessValue
//     * AllAccessKinds                      - See AllAccessKindsFromForm
//     * PresentationsAllAllowed           - See PresentationsAllAllowedFromForm
//     * AllTypesOfValuesToSelect           - See AllTypesOfValuesToSelectFromForm
//
Function AllowedValuesEditFormParameters(Form, CurrentObject = Undefined) Export
	
	PathToTables = "";
	
	If CurrentObject <> Undefined Then
		TablesStorage = CurrentObject;
		
	ElsIf ValueIsFilled(Form.TablesStorageAttributeName) Then
		PathToTables = Form.TablesStorageAttributeName + ".";
		TablesStorage = Form[Form.TablesStorageAttributeName];
	Else
		TablesStorage = Form;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("Purpose",                PurposeFromForm(TablesStorage));
	Parameters.Insert("AccessKinds",               AccessKindsFromForm(TablesStorage));
	Parameters.Insert("AccessValues",           AccessValuesFromForm(TablesStorage));
	Parameters.Insert("AllAccessKinds",            AllAccessKindsFromForm(Form));
	Parameters.Insert("PresentationsAllAllowed", PresentationsAllAllowedFromForm(Form));
	Parameters.Insert("AllTypesOfValuesToSelect", AllTypesOfValuesToSelectFromForm(Form));
	Parameters.Insert("PathToTables",   PathToTables);
	
	Return Parameters;
	
EndFunction

// For internal use only.
//
// Parameters:
//  Form - See AllowedValuesEditFormParameters
//  AccessKind - String
//             - DefinedType.AccessValue
// 
// Returns:
//  Filter - Structure:
//   * AccessGroup - CatalogRef.AccessGroups
//   * AccessKind - DefinedType.AccessValue - a blank reference of the main access kind value type.
//
Function FilterInAllowedValuesEditFormTables(Form, AccessKind = "NoFilterByAccessKind") Export
	
	Filter = New Structure;
	
	Structure = New Structure("CurrentAccessGroup", "AttributeNotExists");
	FillPropertyValues(Structure, Form);
	
	If Structure.CurrentAccessGroup <> "AttributeNotExists" Then
		Filter.Insert("AccessGroup", Structure.CurrentAccessGroup);
	EndIf;
	
	If AccessKind <> "NoFilterByAccessKind" Then
		Filter.Insert("AccessKind", AccessKind);
	EndIf;
	
	Return Filter;
	
EndFunction

// For internal use only.
Procedure FillAccessKindsPropertiesInForm(Form) Export
	
	Parameters = AllowedValuesEditFormParameters(Form);
	
	AccessKindsFilter = FilterInAllowedValuesEditFormTables(Form);
	AccessKinds = Parameters.AccessKinds.FindRows(AccessKindsFilter);
	
	For Each String In AccessKinds Do
		
		String.Used = True;
		
		If String.AccessKind <> Undefined Then
			Filter = New Structure("Ref", String.AccessKind);
			FoundRows = Form.AllAccessKinds.FindRows(Filter);
			If FoundRows.Count() > 0 Then
				String.AccessKindPresentation = FoundRows[0].Presentation;
				String.Used            = FoundRows[0].Used;
			EndIf;
		EndIf;
		
		FillAllAllowedPresentation(Form, String);
		
		FillNumbersOfAccessValuesRowsByKind(Form, String);
	EndDo;
	
EndProcedure

// For internal use only.
// 
// Parameters:
//  Form - See AllowedValuesEditFormParameters
//  Cancel - Boolean
//  CheckedTablesAttributes - Array of String
//  Errors - See CommonClientServer.AddUserError.Errors
//  DontCheck - Boolean
//
Procedure ProcessingOfCheckOfFillingAtServerAllowedValuesEditForm(
		Form, Cancel, CheckedTablesAttributes, Errors, DontCheck = False) Export
	
	Items = Form.Items;
	Parameters = AllowedValuesEditFormParameters(Form);
	If Parameters.Purpose <> Undefined Then
		ProfileAssignment = ProfileAssignment(Parameters);
	EndIf;
	
	CheckedTablesAttributes.Add(Parameters.PathToTables + "AccessKinds.AccessKind");
	CheckedTablesAttributes.Add(Parameters.PathToTables + "AccessValues.AccessKind");
	CheckedTablesAttributes.Add(Parameters.PathToTables + "AccessValues.AccessValue");
	
	If DontCheck Then
		Return;
	EndIf;
	
	AccessKindsFilter = FilterInAllowedValuesEditFormTables(Form);
	
	AccessKinds = Parameters.AccessKinds.FindRows(AccessKindsFilter);
	AccessKindIndex = AccessKinds.Count();
	
	// Checking for unfilled or duplicate access kinds.
	While AccessKindIndex > 0 Do
		AccessKindIndex = AccessKindIndex - 1;
		AccessKindRow = AccessKinds[AccessKindIndex];
		
		// Checking whether the access kind is filled.
		If AccessKindRow.AccessKind = Undefined Then
			CommonClientServer.AddUserError(Errors,
				Parameters.PathToTables + "AccessKinds[%1].AccessKind",
				NStr("en = 'The access kind is not selected.';"),
				"AccessKinds",
				AccessKinds.Find(AccessKindRow),
				NStr("en = 'No access kind selected in line #%1.';"),
				Parameters.AccessKinds.IndexOf(AccessKindRow));
			Cancel = True;
			Continue;
		EndIf;
		
		// Checking whether the access kind matches the profile assignment.
		If Parameters.Purpose <> Undefined
		  And Not AccessKindMatchesProfileAssignment(AccessKindRow.AccessKind, ProfileAssignment) Then
			
			CommonClientServer.AddUserError(Errors,
				Parameters.PathToTables + "AccessKinds[%1].AccessKind",
				StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Access kind ""%1"" does not match the profile assignment.';"),
					AccessKindRow.AccessKindPresentation),
				"AccessKinds",
				AccessKinds.Find(AccessKindRow),
				StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Access kind ""%1"" in line #%2 does not match the profile assignment.';"),
					AccessKindRow.AccessKindPresentation, "%1"),
				Parameters.AccessKinds.IndexOf(AccessKindRow));
			Cancel = True;
			Continue;
		EndIf;
		
		// Checking for duplicate access kinds.
		AccessKindsFilter.Insert("AccessKind", AccessKindRow.AccessKind);
		FoundAccessKinds = Parameters.AccessKinds.FindRows(AccessKindsFilter);
		
		If FoundAccessKinds.Count() > 1 Then
			CommonClientServer.AddUserError(Errors,
				Parameters.PathToTables + "AccessKinds[%1].AccessKind",
				StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Duplicate access kind: ""%1"".';"),
					AccessKindRow.AccessKindPresentation),
				"AccessKinds",
				AccessKinds.Find(AccessKindRow),
				StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Duplicate access kind ""%1"" in line #%2.';"),
					AccessKindRow.AccessKindPresentation, "%1"),
				Parameters.AccessKinds.IndexOf(AccessKindRow));
			Cancel = True;
			Continue;
		EndIf;
		
		AccessValuesFilter = FilterInAllowedValuesEditFormTables(
			Form, AccessKindRow.AccessKind);
		
		AccessValues = Parameters.AccessValues.FindRows(AccessValuesFilter);
		AccessValueIndex = AccessValues.Count();
		
		While AccessValueIndex > 0 Do
			AccessValueIndex = AccessValueIndex - 1;
			AccessValueRow = AccessValues[AccessValueIndex];
			
			// Checking whether the access value is filled.
			If AccessValueRow.AccessValue = Undefined Then
				Items.AccessKinds.CurrentRow = AccessKindRow.GetID();
				Items.AccessValues.CurrentRow = AccessValueRow.GetID();
				
				CommonClientServer.AddUserError(Errors,
					Parameters.PathToTables + "AccessValues[%1].AccessValue",
					NStr("en = 'No value is selected.';"),
					"AccessValues",
					AccessValues.Find(AccessValueRow),
					NStr("en = 'No value selected in line #%1.';"),
					Parameters.AccessValues.IndexOf(AccessValueRow));
				Cancel = True;
				Continue;
			EndIf;
			
			// Checking for duplicate values.
			AccessValuesFilter.Insert("AccessValue", AccessValueRow.AccessValue);
			FoundValues = Parameters.AccessValues.FindRows(AccessValuesFilter);
			
			If FoundValues.Count() > 1 Then
				Items.AccessKinds.CurrentRow = AccessKindRow.GetID();
				Items.AccessValues.CurrentRow = AccessValueRow.GetID();
				
				CommonClientServer.AddUserError(Errors,
					Parameters.PathToTables + "AccessValues[%1].AccessValue",
					NStr("en = 'Duplicate value.';"),
					"AccessValues",
					AccessValues.Find(AccessValueRow),
					NStr("en = 'Duplicate value in line #%1.';"),
					Parameters.AccessValues.IndexOf(AccessValueRow));
				Cancel = True;
				Continue;
			EndIf;
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

// Parameters:
//  Data - Structure:
//   * Description - String
//   * User - CatalogRef.Users
//   
// Returns:
//  String
//
Function PresentationAccessGroups(Data) Export
	
	Return Data.Description + ": " + Data.User;
	
EndFunction

// For internal use only.
// See AccessManagementInternal.OnCreateAtServerAllowedValuesEditForm
//
// Returns:
//   FormDataCollection of FormDataCollectionItem:
//     * UserType - DefinedType.User - assignment type.
//
Function PurposeFromForm(Form)
	
	OptionalAttributes = New Structure("Purpose");
	FillPropertyValues(OptionalAttributes, Form);
	Return OptionalAttributes.Purpose;
	
EndFunction

// For internal use only.
// See AccessManagementInternal.OnCreateAtServerAllowedValuesEditForm
//
// Returns:
//   FormDataCollection of FormDataCollectionItem:
//    * AccessGroup              - CatalogRef.AccessGroups
//    * AccessKind                 - DefinedType.AccessValue
//    * Predefined          - Boolean - (profile only)
//    * AllAllowed               - Boolean
//    * AccessKindPresentation    - String - setting presentation,
//    * AllAllowedPresentation  - String - setting presentation,
//    * Used               - Boolean
//
Function AccessKindsFromForm(Form)
	
	Return Form.AccessKinds;
	
EndFunction

// For internal use only.
// See AccessManagementInternal.OnCreateAtServerAllowedValuesEditForm
//
// Returns:
//   FormDataCollection of FormDataCollectionItem:
//    * AccessGroup     - CatalogRef.AccessGroups
//    * AccessKind        - DefinedType.AccessValue
//    * AccessValue   - DefinedType.AccessValue
//    * RowNumberByKind - Number
//
Function AccessValuesFromForm(Form)
	
	Return Form.AccessValues;
	
EndFunction

// For internal use only.
// See AccessManagementInternal.OnCreateAtServerAllowedValuesEditForm
//
// Returns:
//   FormDataCollection of FormDataCollectionItem:
//    * Ref        - DefinedType.AccessValue
//    * Presentation - String
//    * Used  - Boolean
//
Function AllAccessKindsFromForm(Form)
	
	OptionalAttributes = New Structure("AllAccessKinds");
	FillPropertyValues(OptionalAttributes, Form);
	Return OptionalAttributes.AllAccessKinds;
	
EndFunction

// For internal use only.
// See AccessManagementInternal.OnCreateAtServerAllowedValuesEditForm
//
// Returns:
//   FormDataCollection of FormDataCollectionItem:
//    * Name           - String
//    * Presentation - String
//
Function PresentationsAllAllowedFromForm(Form)
	
	OptionalAttributes = New Structure("PresentationsAllAllowed");
	FillPropertyValues(OptionalAttributes, Form);
	Return OptionalAttributes.PresentationsAllAllowed;
	
EndFunction

// For internal use only.
// See AccessManagementInternal.OnCreateAtServerAllowedValuesEditForm
//
// Returns:
//   FormDataCollection of FormDataCollectionItem:
//    * AccessKind        - DefinedType.AccessValue
//    * ValuesType       - DefinedType.AccessValue
//    * TypePresentation - String
//    * TableName        - String
//    * HierarchyOfItems - Boolean
//
Function AllTypesOfValuesToSelectFromForm(Form)
	
	OptionalAttributes = New Structure("AllTypesOfValuesToSelect");
	FillPropertyValues(OptionalAttributes, Form);
	Return OptionalAttributes.AllTypesOfValuesToSelect;
	
EndFunction

#EndRegion
