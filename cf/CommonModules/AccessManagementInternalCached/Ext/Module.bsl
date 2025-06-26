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

// See Catalogs.AccessGroupProfiles.SuppliedProfilesNote
Function SuppliedProfilesNote() Export
	
	Return Catalogs.AccessGroupProfiles.SuppliedProfilesNote();
	
EndFunction

// See AccessManagementInternal.PermanentMetadataObjectsRightsRestrictionsKinds
Function PermanentMetadataObjectsRightsRestrictionsKinds(ForCheck = False) Export
	
	Return AccessManagementInternal.PermanentMetadataObjectsRightsRestrictionsKinds(ForCheck);
	
EndFunction

// See AccessManagementInternal.AccessKindsPresentation
Function AccessKindsPresentation() Export
	
	Return AccessManagementInternal.AccessKindsPresentation();
	
EndFunction

#EndRegion

#Region Private

// See AccessManagement.ProfileAdministrator
Function ProfileAdministrator() Export
	
	Return Catalogs.AccessGroupProfiles.ProfileAdministrator();
	
EndFunction

// See AccessManagement.AdministratorsAccessGroup
Function AdministratorsAccessGroup() Export
	
	Return Catalogs.AccessGroups.AdministratorsAccessGroup();
	
EndFunction

// For internal use only.
//
// Returns:
//  FixedStructure:
//    * SessionProperties - See AccessManagementInternal.AccessKindsProperties
//    * HashAmounts       - See AccessManagementInternal.NewHashSumAccessTypeProperties
//    * Validation       - Structure:
//        ** Date - Date
// 
Function DescriptionPropertiesAccessTypesSession() Export
	
	HashAmounts = AccessManagementInternal.NewHashSumAccessTypeProperties();
	SessionProperties = AccessManagementInternal.CheckedSessionAccessViewProperties(HashAmounts);
	
	Result = New Structure;
	Result.Insert("SessionProperties", SessionProperties);
	Result.Insert("HashAmounts", New FixedStructure(HashAmounts));
	Result.Insert("Validation", New Structure("Date", '00010101'));
	
	Return New FixedStructure(Result);
	
EndFunction

// For internal use only.
//
// Returns:
//  FixedStructure:
//    * PossibleSessionRights - See AccessManagementInternal.RightsForObjectsRightsSettingsAvailable
//    * HashSum             - String
//    * Validation             - Structure:
//        ** Date - Date
// 
Function DescriptionPossibleSessionRightsForSettingObjectRights() Export
	
	HashSum = "";
	PossibleSessionRights = InformationRegisters.ObjectsRightsSettings.CheckedPossibleSessionPermissions(, HashSum);
	
	Result = New Structure;
	Result.Insert("PossibleSessionRights", PossibleSessionRights);
	Result.Insert("HashSum", HashSum);
	Result.Insert("Validation", New Structure("Date", '00010101'));
	
	Return New FixedStructure(Result);
	
EndFunction

// See InformationRegisters.ObjectsRightsSettings.AvailableRightsPresentation
Function AvailableRightsPresentation() Export
	
	Return InformationRegisters.ObjectsRightsSettings.AvailableRightsPresentation();
	
EndFunction

// For internal use only.
//
// Returns:
//  FixedStructure:
//    * SuppliedSessionProfiles - See AccessManagementInternal.SuppliedProfiles
//    * HashSum                  - String
//    * Validation                  - Structure:
//        ** Date - Date
// 
Function DescriptionSuppliedSessionProfiles() Export
	
	HashSum = "";
	SuppliedSessionProfiles = Catalogs.AccessGroupProfiles.VerifiedSuppliedSessionProfiles(, HashSum);
	
	Result = New Structure;
	Result.Insert("SuppliedSessionProfiles", SuppliedSessionProfiles);
	Result.Insert("HashSum", HashSum);
	Result.Insert("Validation", New Structure("Date", '00010101'));
	
	Return New FixedStructure(Result);
	
EndFunction

// For internal use only.
//
// Returns:
//  FixedStructure:
//    * SessionRoles - See AccessManagementInternal.StandardExtensionRoles
//    * HashSum   - String
//    * Validation   - Structure:
//        ** Date - Date
// 
Function DescriptionStandardRolesSessionExtensions() Export
	
	HashSum = "";
	SessionRoles = Catalogs.AccessGroupProfiles.PreparedStandardRolesSessionExtensions(HashSum);
	
	Result = New Structure;
	Result.Insert("SessionRoles", SessionRoles);
	Result.Insert("HashSum", HashSum);
	Result.Insert("Validation", New Structure("Date", '00010101'));
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns:
//  Structure:
//   * HashSum - String
//   * RoleIDs - FixedMap of KeyAndValue:
//       ** Key - CatalogRef.MetadataObjectIDs
//               - CatalogRef.ExtensionObjectIDs
//       ** Value - Boolean - True.
//
Function SessionRoleIds() Export
	
	FullRoleNames = New Array;
	For Each Role In Metadata.Roles Do
		FullRoleNames.Add(Role.FullName());
	EndDo;
	DescriptionIdsRole = Common.MetadataObjectIDs(FullRoleNames);
	List = New ValueList;
	RoleIDs = New Map;
	For Each RoleIdDescription In DescriptionIdsRole Do
		List.Add(RoleIdDescription.Value.UUID());
		RoleIDs.Insert(RoleIdDescription.Value, True);
	EndDo;
	List.SortByValue();
	
	HashSum = AccessManagementInternal.HashAmountsData(List.UnloadValues());
	
	Result = New Structure;
	Result.Insert("HashSum", HashSum);
	Result.Insert("RoleIDs", New FixedMap(RoleIDs));
	
	Return New FixedStructure(Result);
	
EndFunction

// For internal use only.
//
//  Returns:
//    String
//
Function RecordKeyDetails(TypeORFullName) Export
	
	KeyDetails = New Structure("FieldArray, FieldsString", New Array, "");
	
	If TypeOf(TypeORFullName) = Type("Type") Then
		MetadataObject = Metadata.FindByType(TypeORFullName);
	Else
		MetadataObject = Common.MetadataObjectByFullName(TypeORFullName);
	EndIf;
	Manager = Common.ObjectManagerByFullName(MetadataObject.FullName());
	
	AllFields = New Array;
	For Each Column In Manager.CreateRecordSet().Unload().Columns Do
		AllFields.Add(Column.Name);
	EndDo;
	
	EmptyRecordKey = Manager.CreateRecordKey(New Structure(StrConcat(AllFields, ",")));
	For Each Field In AllFields Do
		OneField = New Structure(Field, Null);
		FillPropertyValues(OneField, EmptyRecordKey);
		If OneField[Field] = Null Then
			Continue;
		EndIf;
		KeyDetails.FieldArray.Add(Field);
	EndDo;
	
	KeyDetails.FieldsString = StrConcat(KeyDetails.FieldArray, ",");
	
	Return Common.FixedData(KeyDetails);
	
EndFunction

// For internal use only.
//
// Returns:
//  FixedMap of KeyAndValue:
//    * Key - Type
//    * Value - Boolean - True.
//
Function TableFieldTypes(FullFieldName1) Export
	
	MetadataObject = Common.MetadataObjectByFullName(FullFieldName1);
	TypesArray = MetadataObject.Type.Types();
	IDType = Type("CatalogObject.MetadataObjectIDs");
	
	FieldTypes = New Map;
	For Each Type In TypesArray Do
		If Type = IDType Then
			Continue;
		EndIf;
		FieldTypes.Insert(Type, True);
	EndDo;
	
	Return New FixedMap(FieldTypes);
	
EndFunction

// Returns types of objects and references used in the specified event subscriptions.
// 
// Parameters:
//  SubscriptionsNames - String - a multiline string
//                  containing rows of the subscription name beginning.
//
// Returns:
//  FixedMap of KeyAndValue:
//    * Key - Type
//    * Value - Boolean
//
Function ObjectsTypesInSubscriptionsToEvents(SubscriptionsNames) Export
	
	IDType = Type("CatalogObject.MetadataObjectIDs");
	ObjectsTypes = New Map;
	
	For Each Subscription In Metadata.EventSubscriptions Do
		
		For LineNumber = 1 To StrLineCount(SubscriptionsNames) Do
			SubscriptionName = StrGetLine(SubscriptionsNames, LineNumber);
			
			If Upper(Subscription.Name) = Upper(SubscriptionName) Then
				
				Types = Subscription.Source.Types();
				For Each Type In Types Do
					If Type = IDType Then
						Continue;
					EndIf;
					ObjectsTypes.Insert(Type, True);
				EndDo;
			EndIf;
		EndDo;
		
	EndDo;
	
	Return New FixedMap(ObjectsTypes);
	
EndFunction

// For internal use only.
//
// Returns:
//   ValueStorage
//
Function BlankRecordSetTable(FullRegisterName) Export
	
	Manager = Common.ObjectManagerByFullName(FullRegisterName);
	
	Return New ValueStorage(Manager.CreateRecordSet().Unload());
	
EndFunction

// For internal use only.
//
// Returns:
//   ValueStorage - Contains the "ValueTable" type
//
Function BlankSpecifiedTypesRefsTable(FullAttributeName) Export
	
	TypeDescription = Common.MetadataObjectByFullName(FullAttributeName).Type;
	
	BlankRefs = New ValueTable;
	BlankRefs.Columns.Add("EmptyRef", TypeDescription);
	
	For Each ValueType In TypeDescription.Types() Do
		If Common.IsReference(ValueType) Then
			BlankRefs.Add().EmptyRef = Common.ObjectManagerByFullName(
				Metadata.FindByType(ValueType).FullName()).EmptyRef();
		EndIf;
	EndDo;
	
	Return New ValueStorage(BlankRefs);
	
EndFunction

// For internal use only.
//
// Returns:
//   FixedMap of KeyAndValue:
//     * Key - Type
//     * Value - AnyRef
//
Function BlankRefsMapToSpecifiedRefsTypes(FullAttributeName) Export
	
	TypeDescription = Common.MetadataObjectByFullName(FullAttributeName).Type;
	
	BlankRefs = New Map;
	
	For Each ValueType In TypeDescription.Types() Do
		If Common.IsReference(ValueType) Then
			BlankRefs.Insert(ValueType, Common.ObjectManagerByFullName(
				Metadata.FindByType(ValueType).FullName()).EmptyRef() );
		EndIf;
	EndDo;
	
	Return New FixedMap(BlankRefs);
	
EndFunction

// For internal use only.
//
// Returns:
//   FixedMap of KeyAndValue:
//     * Key - Type
//     * Value - String
//
Function RefsTypesCodes(FullAttributeName) Export
	
	TypeDescription = Common.MetadataObjectByFullName(FullAttributeName).Type;
	
	NumericCodesOfTypes = New Map;
	CurrentCode = 0;
	
	For Each ValueType In TypeDescription.Types() Do
		If Common.IsReference(ValueType) Then
			NumericCodesOfTypes.Insert(ValueType, CurrentCode);
		EndIf;
		CurrentCode = CurrentCode + 1;
	EndDo;
	
	TypesStringCodes = New Map;
	
	StringCodeLength = StrLen(Format(CurrentCode-1, "NZ=0; NG="));
	FormatCodeString = "ND=" + Format(StringCodeLength, "NZ=0; NG=") + "; NZ=0; NLZ=; NG=";
	
	For Each KeyAndValue In NumericCodesOfTypes Do
		TypesStringCodes.Insert(
			KeyAndValue.Key,
			Format(KeyAndValue.Value, FormatCodeString));
	EndDo;
	
	Return New FixedMap(TypesStringCodes);
	
EndFunction

// For internal use only.
//
// Returns:
//   FixedMap of KeyAndValue:
//     * Key - Type
//     * Value - String
//
Function EnumerationsCodes() Export
	
	EnumerationsCodes = New Map;
	
	For Each AccessValueType In Metadata.DefinedTypes.AccessValue.Type.Types() Do
		TypeMetadata = Metadata.FindByType(AccessValueType); // MetadataObjectEnum
		If TypeMetadata = Undefined Or Not Metadata.Enums.Contains(TypeMetadata) Then
			Continue;
		EndIf;
		For Each EnumerationValue In TypeMetadata.EnumValues Do
			EnumValueName = EnumerationValue.Name;
			EnumerationsCodes.Insert(Enums[TypeMetadata.Name][EnumValueName], EnumValueName);
		EndDo;
	EndDo;
	
	Return New FixedMap(EnumerationsCodes);
	
EndFunction

// See AccessManagementInternal.AccessKindsGroupsAndValuesTypes
Function AccessKindsGroupsAndValuesTypes() Export
	
	Return AccessManagementInternal.AccessKindsGroupsAndValuesTypes();
	
EndFunction

// For internal use only.
//
// Returns:
//  TypeDescription
//
Function DetailsOfAccessValuesTypesAndRightsSettingsOwners() Export
	
	Types = New Array;
	For Each Type In Metadata.DefinedTypes.AccessValue.Type.Types() Do
		Types.Add(Type);
	EndDo;
	
	For Each Type In Metadata.DefinedTypes.RightsSettingsOwner.Type.Types() Do
		If Type = Type("String") Then
			Continue;
		EndIf;
		Types.Add(Type);
	EndDo;
	
	Return New TypeDescription(Types);
	
EndFunction

// Returns reference types from the "AccessValueObject" type collection.
// 
// Returns:
//  TypeDescription
//
Function RefsTypesFromAccessValueObject() Export
	
	Types = New Array;
	For Each Type In Metadata.DefinedTypes.AccessValueObject.Type.Types() Do
		FullName = Metadata.FindByType(Type).FullName();
		RefType = Type(StrReplace(FullName, ".", "Ref."));
		Types.Add(RefType);
	EndDo;
	
	Return New TypeDescription(Types);
	
EndFunction

// See also AccessManagementInternal.ValuesTypesOfAccessKindsAndRightsSettingsOwners()
//
// Returns:
//   ValueStorage
//
Function ValuesTypesOfAccessKindsAndRightsSettingsOwners() Export
	
	Return New ValueStorage(AccessManagementInternal.ValuesTypesOfAccessKindsAndRightsSettingsOwners());
	
EndFunction

// For internal use only.
//
// Returns:
//  Structure:
//    * UpdateDate - Date
//    * Table - ValueTable:
//        ** Table - CatalogRef.MetadataObjectIDs
//                   - CatalogRef.ExtensionObjectIDs
//        ** Right - String - a right name
//        ** AccessKind - CatalogRef
//        ** Presentation - String - Access kind presentation.
//
Function MetadataObjectsRightsRestrictionsKinds() Export
	
	Return New Structure("UpdateDate, Table", '00010101');
	
EndFunction

// For internal use only.
//
// Returns:
//  Boolean
//
Function ConstantLimitAccessAtRecordLevel() Export
	
	Return Constants.LimitAccessAtRecordLevel.Get();
	
EndFunction

#Region UniversalRestriction

// Returns:
//  Boolean
//
Function ConstantLimitAccessAtRecordLevelUniversally() Export
	
	Return AccessManagementInternal.ConstantLimitAccessAtRecordLevelUniversally();
	
EndFunction

// Parameters:
//  User - CatalogRef.Users
//               - CatalogRef.ExternalUsers
//               - Undefined - Check for the current user.
//
// Returns:
//  Boolean
//
Function IsUserWithUnlimitedAccess(User = Undefined) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.ODataInterface") Then
		Return False;
	EndIf;
	
	ModuleODataInterfaceInternal = Common.CommonModule("ODataInterfaceInternal");
	ODataInterfaceRole = ModuleODataInterfaceInternal.ODataInterfaceRole();
	
	If User = Undefined
	 Or User = Users.AuthorizedUser() Then
		Return InfoBaseUsers.CurrentUser().Roles.Contains(ODataInterfaceRole);
	EndIf;
	
	If Not ValueIsFilled(User)
	 Or TypeOf(User) <> Type("CatalogRef.Users")
	   And TypeOf(User) <> Type("CatalogRef.ExternalUsers") Then
		Return False;
	EndIf;
	
	IBUserID = Common.ObjectAttributeValue(User,
		"IBUserID");
	
	If TypeOf(IBUserID) <> Type("UUID") Then
		Return False;
	EndIf;
	
	IBUser = InfoBaseUsers.FindByUUID(
		IBUserID);
	
	If IBUser = Undefined Then
		Return False;
	EndIf;
	
	Return IBUser.Roles.Contains(ODataInterfaceRole);
	
EndFunction

// Returns:
//   FixedMap of KeyAndValue:
//     * Key - Type
//     * Value - Array of CatalogRef
//
Function BlankRefsOfGroupsAndValuesTypes() Export
	
	AccessKindsProperties = AccessManagementInternal.AccessKindsProperties();
	BlankRefs = New Map;
	
	For Each Properties In AccessKindsProperties.Array Do
		AddBlankValueTypeRef(BlankRefs, Properties.ValuesType,      Properties.ValuesType);
		AddBlankValueTypeRef(BlankRefs, Properties.ValuesGroupsType, Properties.ValuesType);
		For Each LongDesc In Properties.AdditionalTypes Do
			AddBlankValueTypeRef(BlankRefs, LongDesc.ValuesType,      LongDesc.ValuesType);
			AddBlankValueTypeRef(BlankRefs, LongDesc.ValuesGroupsType, LongDesc.ValuesType);
		EndDo;
	EndDo;
	
	UsersGroupsType = Type("CatalogRef.UserGroups");
	AddBlankValueTypeRef(BlankRefs, UsersGroupsType, UsersGroupsType);
	
	ExternalUsersGroupsType = Type("CatalogRef.ExternalUsersGroups");
	AddBlankValueTypeRef(BlankRefs, ExternalUsersGroupsType, ExternalUsersGroupsType);
	
	Properties = AccessKindsProperties.ByNames.Get("Users");
	For Each LongDesc In Properties.AdditionalTypes Do
		AddBlankValueTypeRef(BlankRefs, UsersGroupsType, LongDesc.ValuesType);
	EndDo;
	
	Return New FixedMap(BlankRefs);
	
EndFunction

// Returns:
//   FixedMap of KeyAndValue:
//     * Key - Type
//     * Value - Boolean
//
Function LeadingObjectsRefTypes() Export
	
	Types = New Map;
	AddTypes(Types, Catalogs.AllRefsType().Types());
	AddTypes(Types, Documents.AllRefsType().Types());
	AddTypes(Types, ChartsOfCharacteristicTypes.AllRefsType().Types());
	AddTypes(Types, ChartsOfAccounts.AllRefsType().Types());
	AddTypes(Types, ChartsOfCalculationTypes.AllRefsType().Types());
	AddTypes(Types, BusinessProcesses.AllRefsType().Types());
	AddTypes(Types, Tasks.AllRefsType().Types());
	AddTypes(Types, ExchangePlans.AllRefsType().Types());
	
	Return New FixedMap(Types);
	
EndFunction

// Returns:
//   TypeDescription
//
Function AllowedObjectsRefsTypesDetails() Export
	
	TypeDescription = New TypeDescription(ExchangePlans.AllRefsType());
	TypeDescription = New TypeDescription(TypeDescription, Catalogs.AllRefsType().Types());
	TypeDescription = New TypeDescription(TypeDescription, Documents.AllRefsType().Types());
	TypeDescription = New TypeDescription(TypeDescription, ChartsOfCharacteristicTypes.AllRefsType().Types());
	TypeDescription = New TypeDescription(TypeDescription, ChartsOfAccounts.AllRefsType().Types());
	TypeDescription = New TypeDescription(TypeDescription, ChartsOfCalculationTypes.AllRefsType().Types());
	TypeDescription = New TypeDescription(TypeDescription, BusinessProcesses.AllRefsType().Types());
	TypeDescription = New TypeDescription(TypeDescription, Tasks.AllRefsType().Types());
	TypeDescription = New TypeDescription(TypeDescription,, "CatalogRef.SetsOfAccessGroups");
	
	Return TypeDescription;
	
EndFunction

// See AccessManagementInternal.RestrictionParametersNewCache
Function RestrictionParametersCache(CachedDataKey) Export
	
	Return AccessManagementInternal.RestrictionParametersNewCache();
	
EndFunction

// Returns:
//  Structure:
//   * ForUsers        - See AccessManagementInternal.CacheForCalculatingRightsForTheUserType
//   * ForExternalUsers - See AccessManagementInternal.CacheForCalculatingRightsForTheUserType
//   * DataVersion            - See AccessManagementInternal.NewVersionOfTheDataForTheRightsCalculationCache
// 
Function RightsCalculationCache(CachedDataKey) Export
	
	Properties = "ListAccessGroupPermissions, AccessGroupsValues, UserGroupsUsers,
		|AccessGroupsMembers, AccessGroupsUserGroups, UserGroupsAsAccessValues,
		|RolesOfAccessGroupProfiles, ProfilesAccessGroups";
	
	DataVersion = AccessManagementInternal.NewVersionOfTheDataForTheRightsCalculationCache(
		String(New UUID));
	
	Store = New Structure;
	Store.Insert("ForUsers",        New Structure(Properties, New Map));
	Store.Insert("ForExternalUsers", New Structure(Properties, New Map));
	Store.Insert("DataVersion",            DataVersion);
	
	Return Store;
	
EndFunction

Function ChangedListsCacheOnDisabledAccessKeysUpdate() Export
	
	DisableUpdate = SessionParameters.DIsableAccessKeysUpdate; // See AccessManagementInternal.NewDisableOfAccessKeysUpdate
	
	Return DisableUpdate.EditedLists.Get();
	
EndFunction

// Returns:
//   FixedMap of KeyAndValue:
//     * Key     - String - a full list (table) name.
//     * Value - Boolean - True - a restriction text in the manager module.
//                           False - a restriction text in the overridable
//                                    module in the OnFillAccessRestriction procedure.
//
Function ListsWithRestriction() Export
	
	Lists = New Map;
	SSLSubsystemsIntegration.OnFillListsWithAccessRestriction(Lists);
	AccessManagementOverridable.OnFillListsWithAccessRestriction(Lists);
	
	ListsProperties = New Map;
	For Each List In Lists Do
		FullName = List.Key.FullName();
		ListsProperties.Insert(FullName, List.Value);
	EndDo;
	
	Return New FixedMap(ListsProperties);
	
EndFunction

Function AllowedAccessKey() Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	Ref = Catalogs.AccessKeys.GetRef(
		New UUID("8bfeb2d1-08c3-11e8-bcf8-d017c2abb532"));
	
	RefInDatabase = Common.ObjectAttributeValue(Ref, "Ref");
	If Not ValueIsFilled(RefInDatabase) Then
		AllowedKey = Catalogs.AccessKeys.CreateItem();
		AllowedKey.SetNewObjectRef(Ref);
		AllowedKey.Description = NStr("en = 'Allowed access key';");
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.AccessKeys");
		LockItem.SetValue("Ref", Ref);
		
		BeginTransaction();
		Try
			Block.Lock();
			RefInDatabase = Common.ObjectAttributeValue(Ref, "Ref");
			If Not ValueIsFilled(RefInDatabase) Then
				AllowedKey.Write();
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Return Ref;
	
EndFunction

Function AllowedBlankAccessGroupsSet() Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	Ref = Catalogs.SetsOfAccessGroups.GetRef(
		New UUID("b5bc5b29-a11d-11e8-8787-b06ebfbf08c7"));
	
	RefInDatabase = Common.ObjectAttributeValue(Ref, "Ref");
	If Not ValueIsFilled(RefInDatabase) Then
		AllowedBlankSet = Catalogs.SetsOfAccessGroups.CreateItem();
		AllowedBlankSet.SetNewObjectRef(Ref);
		AllowedBlankSet.Description = NStr("en = 'Allowed empty access group set';");
		AllowedBlankSet.SetItemsType = Catalogs.AccessGroups.EmptyRef();
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.SetsOfAccessGroups");
		LockItem.SetValue("Ref", Ref);
		
		BeginTransaction();
		Try
			Block.Lock();
			RefInDatabase = Common.ObjectAttributeValue(Ref, "Ref");
			If Not ValueIsFilled(RefInDatabase) Then
				AllowedBlankSet.Write();
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Return Ref;
	
EndFunction

Function AccessKeyDimensions() Export
	
	KeyMetadata = Metadata.Catalogs.AccessKeys;
	
	If SimilarItemsInCollectionCount(KeyMetadata.Attributes, "Value") <> 5 Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Catalog ""%1"" can contain the maximum of 5 ""%2"" attributes.';"),
			"AccessKeys", "Value" + "*");
		Raise ErrorText;
	EndIf;
	
	If KeyMetadata.TabularSections.Find("Header") = Undefined
	 Or SimilarItemsInCollectionCount(KeyMetadata.TabularSections.Header.Attributes, "Value", 6) <> 5 Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Catalog ""%1"" can contain tabular section ""%2"" with the maximum of 5 ""%3"" attributes.';"),
			"AccessKeys", "Header", "Value" + "*");
		Raise ErrorText;
	EndIf;
	
	TabularSectionsCount = SimilarItemsInCollectionCount(KeyMetadata.TabularSections, "TabularSection");
	If TabularSectionsCount < 1 Or TabularSectionsCount > 12 Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Catalog ""%1"" can contain 1 to 12 tabular sections ""%2"".';"),
			"AccessKeys", "TabularSection" + "*");
		Raise ErrorText;
	EndIf;
	
	TabularSectionsCount = 0;
	TabularSectionAttributesCount = 0;
	For Each TabularSection In KeyMetadata.TabularSections Do
		If Not StrStartsWith(TabularSection.Name, "TabularSection") Then
			Continue;
		EndIf;
		TabularSectionsCount = TabularSectionsCount + 1;
		Count = SimilarItemsInCollectionCount(TabularSection.Attributes, "Value");
		If Count < 1 Or Count > 15 Then
			TabularSectionAttributesCount = 0;
			Break;
		EndIf;
		If TabularSectionAttributesCount <> 0
		   And TabularSectionAttributesCount <> Count Then
			
			TabularSectionAttributesCount = 0;
			Break;
		EndIf;
		TabularSectionAttributesCount = Count;
	EndDo;
	
	If TabularSectionAttributesCount = 0 Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Tabular sections ""%2"" of catalog ""%1""
			           |must contain the same number of attributes ""%3"", but not more than 15.';"),
			"AccessKeys", "TabularSection" + "*", "Value" + "*");
		Raise ErrorText;
	EndIf;
	
	Dimensions = New Structure;
	Dimensions.Insert("TabularSectionsCount",          TabularSectionsCount);
	Dimensions.Insert("TabularSectionAttributesCount", TabularSectionAttributesCount);
	
	Return New FixedStructure(Dimensions);
	
EndFunction

Function BasicRegisterFieldsCount(Val RegisterName = "") Export
	
	If RegisterName = "" Or RegisterName = "AccessKeysForRegisters" Then
		RegisterName = "AccessKeysForRegisters";
		Dimensions = Metadata.InformationRegisters.AccessKeysForRegisters.Dimensions;
		If Dimensions.Count() < 1 Or Dimensions[0].Name <> "Register" Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'In information register ""%1"",
				           |the first dimension must be ""%2"".';"), RegisterName, "Register");
			Raise ErrorText;
		EndIf;
		If Dimensions.Count() < 2 Or Dimensions[1].Name <> "AccessOption" Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'In information register ""%1"",
				           |the second dimension must be ""%2"".';"), RegisterName, "AccessOption");
			Raise ErrorText;
		EndIf;
		IndexOfTheFieldDimension = 2;
	Else
		Dimensions = Metadata.InformationRegisters[RegisterName].Dimensions;
		If Dimensions.Count() < 1 Or Dimensions[0].Name <> "AccessOption" Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'In information register ""%1"",
				           |the first dimension must be ""%2"".';"), RegisterName, "AccessOption");
			Raise ErrorText;
		EndIf;
		IndexOfTheFieldDimension = 1;
	EndIf;
	
	AccessOptionType = Dimensions.AccessOption.Type;
	
	If AccessOptionType.Types().Count() <> 1
	 Or Not AccessOptionType.ContainsType(Type("Number"))
	 Or AccessOptionType.NumberQualifiers.AllowedSign <> AllowedSign.Nonnegative
	 Or AccessOptionType.NumberQualifiers.Digits <> 4
	 Or AccessOptionType.NumberQualifiers.FractionDigits <> 0 Then
	
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'In information register ""%1"",
			           |dimension ""%2"" must have type ""%3"".';"),
			RegisterName, "AccessOption", "Number(4,0,Non_negative)");
		Raise ErrorText;
	EndIf;
	
	If Dimensions.Count() <= IndexOfTheFieldDimension
	 Or Dimensions[IndexOfTheFieldDimension].Name <> "Field1" Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'In information register ""%1"",
			           |dimension ""%2"" must be followed by ""%3"".';"), RegisterName, "AccessOption", "Field1");
		Raise ErrorText;
	EndIf;
	
	LastFieldNumber = 0;
	For Each Dimension In Dimensions Do
		If Dimension.Name = "Register" Or Dimension.Name = "AccessOption" Then
			Continue;
		EndIf;
		FieldName = "Field" + XMLString(LastFieldNumber + 1);
		If Dimension.Name <> FieldName Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'In the %1 information register,
				           |dimensions of type %2<number> must be in order,
				           |but %4 is found in the %3 dimension position';"),
				RegisterName, "Field", FieldName, Dimension.Name);
			Raise ErrorText;
		EndIf;
		LastFieldNumber = LastFieldNumber + 1;
	EndDo;
	
	Return LastFieldNumber;
	
EndFunction

Function MaxBasicRegisterFieldsCount() Export
	
	// When changing, synchronously change the access restriction template ForRegister.
	Return Number(5);
	
EndFunction

Function BlankBasicFieldsValues(Count) Export
	
	BlankValues = New Structure;
	For Number = 1 To Count Do
		BlankValues.Insert("Field" + Number, Enums.AdditionalAccessValues.Null);
	EndDo;
	
	Return BlankValues;
	
EndFunction

// Returns:
//  FixedStructure of KeyAndValue:
//    * Key - String - Field name
//    * Value - TypeDescription - Field type
//
Function RegisterBasicFieldsTypes(Val RegisterName = "") Export
	
	Count = AccessManagementInternalCached.BasicRegisterFieldsCount(RegisterName);
	
	If RegisterName = "" Or RegisterName = "AccessKeysForRegisters" Then
		RegisterName = "AccessKeysForRegisters";
	EndIf;
	Dimensions = Metadata.InformationRegisters[RegisterName].Dimensions;
	
	Result = New Structure;
	For Number = 1 To Count Do
		FieldName = "Field" + Number;
		Result.Insert(FieldName, Dimensions[FieldName].Type);
	EndDo;
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns:
//  FixedMap of KeyAndValue:
//    * Key - String - Table's full name.
//    * Value - Boolean - True
//
Function TablesInSubscriptionsCheckAccess() Export
	
	Result = New Map;
	
	AddTablesFromTypesDetails(Result,
		Metadata.DefinedTypes.AccessKeysValuesOwnerObject.Type);
	
	AddTablesFromTypesDetails(Result,
		Metadata.DefinedTypes.AccessKeysValuesOwnerDocument.Type);
	
	AddTablesFromTypesDetails(Result,
		Metadata.DefinedTypes.AccessKeysValuesOwnerRecordSet.Type);
	
	AddTablesFromTypesDetails(Result,
		Metadata.DefinedTypes.AccessKeysValuesOwnerCalculationRegisterRecordSet.Type);
	
	Return New FixedMap(Result);
	
EndFunction

// Returns:
//   See AccessManagementInternal.LanguageSyntax
//
Function LanguageSyntax() Export
	
	Return AccessManagementInternal.LanguageSyntax();
	
EndFunction

// Returns:
//   See AccessManagementInternal.NodesToCheckAvailability
//
Function NodesToCheckAvailability(List, IsExceptionsList) Export
	
	Return AccessManagementInternal.NodesToCheckAvailability(List, IsExceptionsList);
	
EndFunction

Function SeparatedDataUnavailable() Export
	
	Return Not Common.SeparatedDataUsageAvailable();
	
EndFunction

Function PredefinedMetadataObjectIDDetails(FullMetadataObjectName) Export
	
	Names = AccessManagementInternalCached.PredefinedCatalogItemsNames(
		"MetadataObjectIDs");
	
	Name = StrReplace(FullMetadataObjectName, ".", "");
	
	If Names.Find(Name) <> Undefined Then
		Return "MetadataObjectIDs." + Name;
	EndIf;
	
	Names = AccessManagementInternalCached.PredefinedCatalogItemsNames(
		"ExtensionObjectIDs");
	
	If Names.Find(Name) <> Undefined Then
		Return "ExtensionObjectIDs." + Name;
	EndIf;
	
	MetadataObject = Common.MetadataObjectByFullName(FullMetadataObjectName);
	If MetadataObject = Undefined Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot get the name of a predefined metadata object ID
			           |as the specified metadata object does not exist:
			           |""%1"".';"),
			FullMetadataObjectName);
		Raise ErrorText;
	EndIf;
	
	If MetadataObject.ConfigurationExtension() = Undefined Then
		Return "MetadataObjectIDs." + Name;
	EndIf;
	
	Return "ExtensionObjectIDs." + Name;
	
EndFunction

Function PredefinedCatalogItemsNames(CatalogName) Export
	
	Return Metadata.Catalogs[CatalogName].GetPredefinedNames();
	
EndFunction

Function AllowedAccessKeysValuesTypes() Export
	
	KeyDimensions = AccessKeyDimensions();
	CatalogAttributes      = Metadata.Catalogs.AccessKeys.Attributes;
	CatalogTabularSections = Metadata.Catalogs.AccessKeys.TabularSections;
	
	AllowedTypes = CatalogAttributes.Value1.Type.Types();
	For AttributeNumber = 2 To 5 Do
		ClarifyAllowedTypes(AllowedTypes, CatalogAttributes["Value" + AttributeNumber]);
	EndDo;
	For AttributeNumber = 6 To 10 Do
		ClarifyAllowedTypes(AllowedTypes, CatalogTabularSections.Header.Attributes["Value" + AttributeNumber]);
	EndDo;
	For TabularSectionNumber = 1 To KeyDimensions.TabularSectionsCount Do
		TabularSection = CatalogTabularSections["TabularSection" + TabularSectionNumber];
		For AttributeNumber = 1 To KeyDimensions.TabularSectionAttributesCount Do
			ClarifyAllowedTypes(AllowedTypes, TabularSection.Attributes["Value" + AttributeNumber]);
		EndDo;
	EndDo;
	
	Return New TypeDescription(AllowedTypes);
	
EndFunction

Function LastCheckOfAllowedSetsVersion() Export
	
	Return New Structure("Date", '00010101');
	
EndFunction

Function RolesNamesBasicAccess(ForExternalUsers) Export
	
	RolesNames = New Array;
	
	RolesAssignment = UsersInternalCached.RolesAssignment();
	
	For Each Role In Metadata.Roles Do
		NameOfRole = Role.Name;
		
		If Not StrStartsWith(Upper(NameOfRole), Upper("BasicAccess")) Then
			Continue;
		EndIf;
		RoleForExternalUsers = RolesAssignment.ForExternalUsersOnly.Get(Role.Name) <> Undefined;
		If RolesAssignment.BothForUsersAndExternalUsers.Get(Role.Name) <> Undefined
		 Or RoleForExternalUsers = ForExternalUsers Then
			RolesNames.Add(Role.Name);
		EndIf;
	EndDo;
	
	Return RolesNames;
	
EndFunction

Function QueryPlanClarificationRequired() Export
	
	Return Not Common.FileInfobase();
	
EndFunction

// For internal use only.
//
// Returns:
//  String
//
Function QueryPlanClarification(Hash, HashLength) Export
	
	Bits = New Array;
	For BitNumber = 0 To HashLength - 1 Do
		Bits.Insert(0, ?(CheckBit(Hash, BitNumber), "TRUE", "FALSE"));
	EndDo;
	
	Return "TRUE IN (TRUE," + StrConcat(Bits, ",") + ")"; // @query-part-1
	
EndFunction

Function FieldsInMetadataCharsRegister(FullName, Fields) Export
	
	QuerySchema = New QuerySchema;
	QuerySchema.SetQueryText(StrReplace("SELECT * FROM &TableName", "&TableName", FullName));
	
	FieldsInMetadata = New Map;
	For Each Column In QuerySchema.QueryBatch[0].Columns Do
		FieldsInMetadata.Insert(Upper(Column.Alias), Column.Alias);
	EndDo;
	
	FieldsAsSpecified = StrSplit(Fields, ",", False);
	FieldsAsInMetadata = New Array;
	For Each Field In FieldsAsSpecified Do
		FieldsAsInMetadata.Add(FieldsInMetadata.Get(Upper(Field)));
	EndDo;
	
	Return StrConcat(FieldsAsInMetadata, ",");
	
EndFunction

// Returns a string.
//
// Parameters:
//  Char - String - A 1-character long string.
//  Count - Number - The number of characters to return.
//
// Returns:
//  String
//
Function CharacterString(Char = " ", Count = 50) Export
	
	Template = "                                                  ";
	If Count > 50 Then
		Templates = New Array;
		While Templates.Count() * 50 < Count Do
			Templates.Add(Template);
		EndDo;
		Template = StrConcat(Templates, "");
	EndIf;
	
	Return Left(StrReplace(Template, " ", Char), Count);
	
EndFunction

Function DiskLoadBalancingAvailable() Export
	
	Return Not Common.FileInfobase();
	
EndFunction

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Procedure AddBlankValueTypeRef(BlankRefsByTypes, GroupAndValueType, ValuesType)
	
	If GroupAndValueType = Type("Undefined") Then
		Return;
	EndIf;
	
	BlankRefs = BlankRefsByTypes.Get(GroupAndValueType);
	
	If BlankRefs = Undefined Then
		BlankRefs = New Array;
		BlankRefsByTypes.Insert(GroupAndValueType, BlankRefs);
	EndIf;
	
	Types = New Array;
	Types.Add(ValuesType);
	TypeDescription = New TypeDescription(Types);
	
	EmptyRef = TypeDescription.AdjustValue(Undefined);
	BlankRefs.Add(EmptyRef);
	
EndProcedure

#Region UniversalRestriction

Function SimilarItemsInCollectionCount(Collection, NameBeginning, InitialNumber = 1)
	
	SimilarItemsCount = 0;
	MaxNumber = 0;
	
	For Each CollectionItem In Collection Do
		If Not StrStartsWith(CollectionItem.Name, NameBeginning) Then
			Continue;
		EndIf;
		ItemNumber = Mid(CollectionItem.Name, StrLen(NameBeginning) + 1);
		If StrLen(ItemNumber) < 1 Or StrLen(ItemNumber) > 2 Then
			SimilarItemsCount = 0;
			Break;
		EndIf;
		If Not ( Left(ItemNumber, 1) >= "0" And Left(ItemNumber, 1) <= "9" ) Then
			SimilarItemsCount = 0;
			Break;
		EndIf;
		If StrLen(ItemNumber) = 2
		   And Not ( Left(ItemNumber, 2) >= "0" And Left(ItemNumber, 2) <= "9" ) Then
			SimilarItemsCount = 0;
			Break;
		EndIf;
		ItemNumber = Number(ItemNumber);
		If ItemNumber < InitialNumber Then
			SimilarItemsCount = 0;
			Break;
		EndIf;
		
		SimilarItemsCount = SimilarItemsCount + 1;
		MaxNumber = ?(MaxNumber > ItemNumber, MaxNumber, ItemNumber);
	EndDo;
	
	If MaxNumber - InitialNumber + 1 <> SimilarItemsCount Then
		SimilarItemsCount = 0;
	EndIf;
	
	Return SimilarItemsCount;
	
EndFunction

// For the AllowedAccessKeysValuesTypes function.
Procedure ClarifyAllowedTypes(AllowedTypes, Attribute);
	
	IndexOf = AllowedTypes.Count() - 1;
	TypeDescription = Attribute.Type;
	
	While IndexOf >= 0 Do
		If Not TypeDescription.ContainsType(AllowedTypes[IndexOf]) Then
			AllowedTypes.Delete(IndexOf);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
EndProcedure

// For the LeadingObjectsRefsTypes function.
Procedure AddTypes(Types, AddedTypes)
	
	For Each Type In AddedTypes Do
		Types.Insert(Type, True);
	EndDo;
	
EndProcedure

// Intended for function "TablesInSubscriptionsCheckAccess".
Procedure AddTablesFromTypesDetails(Tables, TypeDescription)
	
	For Each Type In TypeDescription.Types() Do
		MetadataObject = Metadata.FindByType(Type);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		Tables.Insert(MetadataObject.FullName(), True);
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion
