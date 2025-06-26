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

#Region Variables
Var Document; // SpreadsheetDocument
Var AccessRightsDetailedInfo; // Boolean
#EndRegion

#Region Public

#Region ForCallsFromOtherSubsystems

// Set report form settings.
//
// Parameters:
//   Form - ClientApplicationForm
//         - Undefined
//   VariantKey - String
//                - Undefined
//   Settings - See ReportsClientServer.DefaultReportSettings
//
Procedure DefineFormSettings(Form, VariantKey, Settings) Export

	Settings.GenerateImmediately = True;
	Settings.Events.BeforeImportSettingsToComposer = True;
	Settings.Events.OnDefineUsedTables = True;

EndProcedure

// Called before importing new settings. Used for modifying DCS reports.
//
// Parameters:
//   Context - Arbitrary
//   SchemaKey - String
//   VariantKey - String
//                - Undefined
//   NewDCSettings - DataCompositionSettings
//                    - Undefined
//   NewDCUserSettings - DataCompositionUserSettings
//                                    - Undefined
//
Procedure BeforeImportSettingsToComposer(Context, SchemaKey, VariantKey, NewDCSettings,
	NewDCUserSettings) Export

	If Not AccessManagementInternal.SimplifiedAccessRightsSetupInterface()
		Or Not Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		Return;
	EndIf;

	If SchemaKey <> "1" Then
		SchemaKey = "1";
		DCSchema = GetTemplate("ParametersTemplate");
		Parameter = DCSchema.Parameters.Find("AccessRightsDetailedInfo");
		Parameter.UseRestriction = True;
		ModuleReportsServer = Common.CommonModule("ReportsServer");
		ModuleReportsServer.AttachSchema(ThisObject, Context, DCSchema, SchemaKey);
	EndIf;

EndProcedure

// Parameters:
//   VariantKey - String
//                - Undefined
//   TablesToUse - Array of String
//
Procedure OnDefineUsedTables(VariantKey, TablesToUse) Export

	TablesToUse.Add(Metadata.InformationRegisters.RolesRights.FullName());
	TablesToUse.Add(Metadata.Catalogs.AccessGroupProfiles.FullName());
	TablesToUse.Add(Metadata.Catalogs.AccessGroups.FullName());
	TablesToUse.Add(Metadata.InformationRegisters.UserGroupCompositions.FullName());

EndProcedure

#EndRegion

#EndRegion

#Region EventHandlers

// Parameters:
//  ResultDocument - SpreadsheetDocument
//  DetailsData - DataCompositionDetailsData
//  StandardProcessing - Boolean
//
Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;

	If Not Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ErrorText = NStr("en = 'To generate a report, the Report options subsystem is required.';");
		Raise ErrorText;
	EndIf;

	InformationRegisters.RolesRights.CheckRegisterData();

	DataParameters = SettingsComposer.GetSettings().DataParameters;
	UserOrGroup = FilterUser();
	AccessRightsDetailedInfo = DataParameters.Items.Find("AccessRightsDetailedInfo").Value;
	If TypeOf(AccessRightsDetailedInfo) <> Type("Boolean") Then
		AccessRightsDetailedInfo = False;
	EndIf;

	If Not ValueIsFilled(UserOrGroup) Then
		ErrorText = NStr("en = 'Open the user card, click ""Access rights"",
						   |and then click ""Access rights report"".';");
		Raise ErrorText;
	EndIf;

	If UserOrGroup <> Users.AuthorizedUser()
		And Not Users.IsFullUser() Then

		ErrorText = NStr("en = 'Insufficient rights to view the report.';");
		Raise(ErrorText, ErrorCategory.AccessViolation);
	EndIf;

	OutputGroupRights = TypeOf(UserOrGroup) = Type("CatalogRef.UserGroups") 
		Or TypeOf(UserOrGroup) = Type("CatalogRef.ExternalUsersGroups");
	SimplifiedInterface = AccessManagementInternal.SimplifiedAccessRightsSetupInterface();

	Document = ResultDocument;
	Template = GetTemplate("Template");

	Properties = New Structure;
	Properties.Insert("Ref", UserOrGroup);

	OutputReportHeader(Template, Properties, UserOrGroup);
	
	// Displaying the infobase user properties for a user and an external user.
	If Not OutputGroupRights Then
		OutputIBUserProperties(Template, UserOrGroup);
	EndIf;
	
	// The report on administrator rights.
	If TypeOf(UserOrGroup) = Type("CatalogRef.Users") 
		Or TypeOf(UserOrGroup) = Type("CatalogRef.ExternalUsers") Then

		SetPrivilegedMode(True);
		IBUser = InfoBaseUsers.FindByUUID(
			Common.ObjectAttributeValue(UserOrGroup, "IBUserID"));
		SetPrivilegedMode(False);

		If IBUser <> Undefined And Users.IsFullUser(IBUser, True) Then

			Area = Template.GetArea("FullUser");
			Document.Put(Area, 1);
			Return;
		EndIf;
	EndIf;

	SetPrivilegedMode(True);
	AvailableRights = AccessManagementInternal.RightsForObjectsRightsSettingsAvailable();
	QueryResults = SelectInfoOnAccessRights(AvailableRights, OutputGroupRights, UserOrGroup);

	Document.StartRowAutoGrouping();

	If AccessRightsDetailedInfo Then
		OutputDetailedInfoOnAccessRights(Template, UserOrGroup, QueryResults[3], Properties);
		OutputRolesByProfiles(Template, UserOrGroup, QueryResults[5], Properties);
	EndIf;

	OutputAvailableForView(AvailableRights, Template, QueryResults[9], SimplifiedInterface);
	OutputAvailableForEdit(AvailableRights, Template, QueryResults[10], SimplifiedInterface);
	OutputRightsToSeparateObjects(AvailableRights, Template, QueryResults[6], OutputGroupRights);

	Document.EndRowAutoGrouping();

EndProcedure

#EndRegion

#Region Private

Function FilterUser()

	Filter = SettingsComposer.GetSettings().Filter;
	For Each Item In Filter.Items Do
		If Item.Use And Item.LeftValue = New DataCompositionField("User") Then
			If Item.ComparisonType = DataCompositionComparisonType.Equal 
				Or Item.ComparisonType = DataCompositionComparisonType.InList Then
				Return Item.RightValue;
			Else
				Return Undefined;
			EndIf;
		EndIf;
	EndDo;

	Return Undefined;

EndFunction

Function SelectInfoOnAccessRights(Val AvailableRights, Val OutputGroupRights, Val UserOrGroup)

	AccessRestrictionKinds = Reports.AccessRightsAnalysis.AccessRestrictionKinds(
		TypeOf(UserOrGroup) = Type("CatalogRef.ExternalUsers") 
		Or TypeOf(UserOrGroup) = Type("CatalogRef.ExternalUsersGroups"));

	Query = New Query;
	Query.SetParameter("User", UserOrGroup);
	Query.SetParameter("OutputGroupRights", OutputGroupRights);
	Query.SetParameter("AccessRestrictionKinds", AccessRestrictionKinds);
	Query.SetParameter("RightsSettingsOwnersTypes", AvailableRights.OwnersTypes);
	Query.SetParameter("ExtensionsRolesRights", AccessManagementInternal.ExtensionsRolesRights());
	
	// ACC:96-off - No.434 The "JOIN" statement is acceptable since rows must be unique and this is a report query.
	Query.Text =
	"SELECT
	|	ExtensionsRolesRights.MetadataObject AS MetadataObject,
	|	ExtensionsRolesRights.Role AS Role,
	|	ExtensionsRolesRights.AddRight AS AddRight,
	|	ExtensionsRolesRights.RightUpdate AS RightUpdate,
	|	ExtensionsRolesRights.UnrestrictedReadRight AS UnrestrictedReadRight,
	|	ExtensionsRolesRights.UnrestrictedAddRight AS UnrestrictedAddRight,
	|	ExtensionsRolesRights.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|	ExtensionsRolesRights.ViewRight AS ViewRight,
	|	ExtensionsRolesRights.InteractiveAddRight AS InteractiveAddRight,
	|	ExtensionsRolesRights.EditRight AS EditRight,
	|	ExtensionsRolesRights.LineChangeType AS LineChangeType
	|INTO ExtensionsRolesRights
	|FROM
	|	&ExtensionsRolesRights AS ExtensionsRolesRights
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExtensionsRolesRights.MetadataObject AS MetadataObject,
	|	ExtensionsRolesRights.Role AS Role,
	|	ExtensionsRolesRights.AddRight AS AddRight,
	|	ExtensionsRolesRights.RightUpdate AS RightUpdate,
	|	ExtensionsRolesRights.UnrestrictedReadRight AS UnrestrictedReadRight,
	|	ExtensionsRolesRights.UnrestrictedAddRight AS UnrestrictedAddRight,
	|	ExtensionsRolesRights.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|	ExtensionsRolesRights.ViewRight AS ViewRight,
	|	ExtensionsRolesRights.InteractiveAddRight AS InteractiveAddRight,
	|	ExtensionsRolesRights.EditRight AS EditRight
	|INTO RolesRights
	|FROM
	|	ExtensionsRolesRights AS ExtensionsRolesRights
	|WHERE
	|	ExtensionsRolesRights.LineChangeType = 1
	|
	|UNION ALL
	|
	|SELECT
	|	RolesRights.MetadataObject,
	|	RolesRights.Role,
	|	RolesRights.AddRight,
	|	RolesRights.RightUpdate,
	|	RolesRights.UnrestrictedReadRight,
	|	RolesRights.UnrestrictedAddRight,
	|	RolesRights.UnrestrictedUpdateRight,
	|	RolesRights.ViewRight,
	|	RolesRights.InteractiveAddRight,
	|	RolesRights.EditRight
	|FROM
	|	InformationRegister.RolesRights AS RolesRights
	|		LEFT JOIN ExtensionsRolesRights AS ExtensionsRolesRights
	|		ON RolesRights.MetadataObject = ExtensionsRolesRights.MetadataObject
	|			AND RolesRights.Role = ExtensionsRolesRights.Role
	|WHERE
	|	ExtensionsRolesRights.MetadataObject IS NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessGroups.Profile AS Profile,
	|	AccessGroups_Users.User AS User,
	|	NOT VALUETYPE(AccessGroups_Users.User) IN (
	|		TYPE(Catalog.Users),
	|		TYPE(Catalog.ExternalUsers)) AS GroupParticipation,
	|	AccessGroups.EmployeeResponsible AS EmployeeResponsible
	|INTO UserAccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroups_Users
	|		ON AccessGroups.Ref = AccessGroups_Users.Ref
	|			AND (NOT AccessGroups.DeletionMark)
	|			AND (NOT AccessGroups.Profile.DeletionMark)
	|			AND (CASE
	|				WHEN &OutputGroupRights
	|					THEN AccessGroups_Users.User = &User
	|				ELSE TRUE IN
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|						WHERE
	|							UserGroupCompositions.UsersGroup = AccessGroups_Users.User
	|							AND UserGroupCompositions.User = &User)
	|			END)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserAccessGroups.AccessGroup AS AccessGroup,
	|	PRESENTATION(UserAccessGroups.AccessGroup) AS PresentationAccessGroups,
	|	UserAccessGroups.User AS Member,
	|	PRESENTATION(UserAccessGroups.User) AS ParticipantPresentation,
	|	UserAccessGroups.GroupParticipation AS GroupParticipation,
	|	UserAccessGroups.AccessGroup.EmployeeResponsible AS EmployeeResponsible,
	|	PRESENTATION(UserAccessGroups.EmployeeResponsible) AS EmployeeResponsiblePresentation,
	|	UserAccessGroups.AccessGroup.Comment AS Comment,
	|	UserAccessGroups.AccessGroup.Profile AS Profile,
	|	PRESENTATION(UserAccessGroups.AccessGroup.Profile) AS ProfilePresentation
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|TOTALS
	|	MAX(Member)
	|BY
	|	AccessGroup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UserAccessGroups.Profile AS Profile
	|INTO UserProfiles
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserProfiles.Profile AS Profile,
	|	PRESENTATION(UserProfiles.Profile) AS ProfilePresentation,
	|	ProfilesRoles.Role.Name AS Role,
	|	ProfilesRoles.Role.Synonym AS RolePresentation
	|FROM
	|	UserProfiles AS UserProfiles
	|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfilesRoles
	|		ON UserProfiles.Profile = ProfilesRoles.Ref
	|TOTALS
	|	MAX(Profile),
	|	MAX(ProfilePresentation),
	|	MAX(Role),
	|	MAX(RolePresentation)
	|BY
	|	Profile,
	|	Role
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	VALUETYPE(ObjectsRightsSettings.Object) AS ObjectType,
	|	ObjectsRightsSettings.Object AS Object,
	|	ISNULL(SettingsInheritance.Inherit, TRUE) AS Inherit,
	|	CASE
	|		WHEN VALUETYPE(ObjectsRightsSettings.User) <> TYPE(Catalog.Users)
	|				AND VALUETYPE(ObjectsRightsSettings.User) <> TYPE(Catalog.ExternalUsers)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS GroupParticipation,
	|	ObjectsRightsSettings.User AS User,
	|	PRESENTATION(ObjectsRightsSettings.User) AS UserDescription1,
	|	ObjectsRightsSettings.Right AS Right,
	|	ObjectsRightsSettings.RightIsProhibited AS RightIsProhibited,
	|	ObjectsRightsSettings.InheritanceIsAllowed AS InheritanceIsAllowed
	|FROM
	|	InformationRegister.ObjectsRightsSettings AS ObjectsRightsSettings
	|		LEFT JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|		ON (SettingsInheritance.Object = ObjectsRightsSettings.Object)
	|			AND (SettingsInheritance.Parent = ObjectsRightsSettings.Object)
	|WHERE
	|	CASE
	|			WHEN &OutputGroupRights
	|				THEN ObjectsRightsSettings.User = &User
	|			ELSE TRUE IN
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|					WHERE
	|						UserGroupCompositions.UsersGroup = ObjectsRightsSettings.User
	|						AND UserGroupCompositions.User = &User)
	|		END
	|
	|UNION ALL
	|
	|SELECT
	|	VALUETYPE(SettingsInheritance.Object),
	|	SettingsInheritance.Object,
	|	SettingsInheritance.Inherit,
	|	FALSE,
	|	UNDEFINED,
	|	"""",
	|	"""",
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|		LEFT JOIN InformationRegister.ObjectsRightsSettings AS ObjectsRightsSettings
	|		ON (ObjectsRightsSettings.Object = SettingsInheritance.Object)
	|			AND (ObjectsRightsSettings.Object = SettingsInheritance.Parent)
	|WHERE
	|	SettingsInheritance.Object = SettingsInheritance.Parent
	|	AND SettingsInheritance.Inherit = FALSE
	|	AND ObjectsRightsSettings.Object IS NULL
	|TOTALS
	|	MAX(Inherit),
	|	MAX(GroupParticipation),
	|	MAX(User),
	|	MAX(UserDescription1),
	|	MAX(InheritanceIsAllowed)
	|BY
	|	ObjectType,
	|	Object,
	|	User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessRestrictionKinds.Table AS Table,
	|	AccessRestrictionKinds.Right AS Right,
	|	AccessRestrictionKinds.AccessKind AS AccessKind,
	|	AccessRestrictionKinds.Presentation AS AccessKindPresentation
	|INTO AccessRestrictionKinds
	|FROM
	|	&AccessRestrictionKinds AS AccessRestrictionKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserAccessGroups.Profile AS Profile,
	|	UserAccessGroups.AccessGroup AS AccessGroup,
	|	ISNULL(AccessGroupsTypesOfAccess.AccessKind, UNDEFINED) AS AccessKind,
	|	ISNULL(AccessGroupsTypesOfAccess.AllAllowed, FALSE) AS AllAllowed,
	|	ISNULL(AccessGroupsAccessValues.AccessValue, UNDEFINED) AS AccessValue
	|INTO AccessKindsAndValues
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|		LEFT JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsTypesOfAccess
	|		ON (AccessGroupsTypesOfAccess.Ref = UserAccessGroups.AccessGroup)
	|		LEFT JOIN Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|		ON (AccessGroupsAccessValues.Ref = AccessGroupsTypesOfAccess.Ref)
	|			AND (AccessGroupsAccessValues.AccessKind = AccessGroupsTypesOfAccess.AccessKind)
	|
	|UNION
	|
	|SELECT
	|	UserAccessGroups.Profile,
	|	UserAccessGroups.AccessGroup,
	|	AccessGroupProfilesAccessTypes.AccessKind,
	|	AccessGroupProfilesAccessTypes.AllAllowed,
	|	ISNULL(AccessGroupProfilesAccessValues.AccessValue, UNDEFINED)
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS AccessGroupProfilesAccessTypes
	|		ON (AccessGroupProfilesAccessTypes.Ref = UserAccessGroups.Profile)
	|		LEFT JOIN Catalog.AccessGroupProfiles.AccessValues AS AccessGroupProfilesAccessValues
	|		ON (AccessGroupProfilesAccessValues.Ref = AccessGroupProfilesAccessTypes.Ref)
	|			AND (AccessGroupProfilesAccessValues.AccessKind = AccessGroupProfilesAccessTypes.AccessKind)
	|WHERE
	|	AccessGroupProfilesAccessTypes.Predefined
	|
	|UNION
	|
	|SELECT
	|	UserAccessGroups.Profile,
	|	UserAccessGroups.AccessGroup,
	|	AccessKindsRightsSettings.EmptyRefValue,
	|	FALSE,
	|	UNDEFINED
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|		INNER JOIN Catalog.MetadataObjectIDs AS AccessKindsRightsSettings
	|		ON (AccessKindsRightsSettings.EmptyRefValue IN (&RightsSettingsOwnersTypes))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfileRolesRights.Table.Parent.Name AS ObjectsKind,
	|	ProfileRolesRights.Table.Parent.CollectionOrder AS ObjectKindOrder,
	|	ProfileRolesRights.Table.FullName AS Table,
	|	ProfileRolesRights.Table.Name AS Object,
	|	ProfileRolesRights.Table AS MetadataObjectID,
	|	ProfileRolesRights.Profile AS Profile,
	|	PRESENTATION(ProfileRolesRights.Profile) AS ProfilePresentation,
	|	ProfileRolesRights.Role.Name AS Role,
	|	ProfileRolesRights.Role.Synonym AS RolePresentation,
	|	ProfileRolesRights.RolesKind AS RolesKind,
	|	ProfileRolesRights.UnrestrictedReadRight AS UnrestrictedReadRight,
	|	ProfileRolesRights.ViewRight AS ViewRight,
	|	ProfileRolesRights.AccessGroup AS AccessGroup,
	|	PRESENTATION(ProfileRolesRights.AccessGroup) AS PresentationAccessGroups,
	|	ProfileRolesRights.AccessKind AS AccessKind,
	|	ProfileRolesRights.AccessKindPresentation AS AccessKindPresentation,
	|	ProfileRolesRights.AllAllowed AS AllAllowed,
	|	ProfileRolesRights.AccessValue AS AccessValue,
	|	PRESENTATION(ProfileRolesRights.AccessValue) AS AccessValuePresentation
	|FROM
	|	(SELECT
	|		RolesRights.MetadataObject AS Table,
	|		ProfilesRoles.Ref AS Profile,
	|		CASE
	|			WHEN RolesRights.ViewRight
	|					AND RolesRights.UnrestrictedReadRight
	|				THEN 0
	|			WHEN NOT RolesRights.ViewRight
	|					AND RolesRights.UnrestrictedReadRight
	|				THEN 1
	|			WHEN RolesRights.ViewRight
	|					AND NOT RolesRights.UnrestrictedReadRight
	|				THEN 2
	|			ELSE 3
	|		END AS RolesKind,
	|		RolesRights.Role AS Role,
	|		RolesRights.UnrestrictedReadRight AS UnrestrictedReadRight,
	|		RolesRights.ViewRight AS ViewRight,
	|		UNDEFINED AS AccessGroup,
	|		UNDEFINED AS AccessKind,
	|		"""" AS AccessKindPresentation,
	|		UNDEFINED AS AllAllowed,
	|		UNDEFINED AS AccessValue
	|	FROM
	|		RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfilesRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfilesRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfilesRoles.Role
	|	
	|	UNION
	|	
	|	SELECT
	|		RolesRights.MetadataObject,
	|		UserProfiles.Profile,
	|		1000,
	|		"""",
	|		FALSE,
	|		FALSE,
	|		AccessKindsAndValues.AccessGroup,
	|		ISNULL(AccessRestrictionKinds.AccessKind, UNDEFINED),
	|		ISNULL(AccessRestrictionKinds.AccessKindPresentation, """"),
	|		AccessKindsAndValues.AllAllowed,
	|		AccessKindsAndValues.AccessValue
	|	FROM
	|		RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfilesRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfilesRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfilesRoles.Role
	|			INNER JOIN AccessKindsAndValues AS AccessKindsAndValues
	|			ON (UserProfiles.Profile = AccessKindsAndValues.Profile)
	|			LEFT JOIN AccessRestrictionKinds AS AccessRestrictionKinds
	|			ON (AccessRestrictionKinds.Table = RolesRights.MetadataObject)
	|				AND (AccessRestrictionKinds.Right = ""Read"")
	|				AND (AccessRestrictionKinds.AccessKind = AccessKindsAndValues.AccessKind)) AS ProfileRolesRights
	|TOTALS
	|	MAX(ObjectKindOrder),
	|	MAX(Table),
	|	MAX(MetadataObjectID),
	|	MAX(ProfilePresentation),
	|	MAX(RolePresentation),
	|	MAX(UnrestrictedReadRight),
	|	MAX(ViewRight),
	|	MAX(PresentationAccessGroups),
	|	MAX(AccessKindPresentation),
	|	MAX(AllAllowed)
	|BY
	|	ObjectsKind,
	|	Object,
	|	Profile,
	|	RolesKind,
	|	Role,
	|	AccessGroup,
	|	AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfileRolesRights.Table.Parent.Name AS ObjectsKind,
	|	ProfileRolesRights.Table.Parent.CollectionOrder AS ObjectKindOrder,
	|	ProfileRolesRights.Table.FullName AS Table,
	|	ProfileRolesRights.Table.Name AS Object,
	|	ProfileRolesRights.Table AS MetadataObjectID,
	|	ProfileRolesRights.Profile AS Profile,
	|	PRESENTATION(ProfileRolesRights.Profile) AS ProfilePresentation,
	|	ProfileRolesRights.Role.Name AS Role,
	|	ProfileRolesRights.Role.Synonym AS RolePresentation,
	|	ProfileRolesRights.RolesKind AS RolesKind,
	|	ProfileRolesRights.AddRight AS AddRight,
	|	ProfileRolesRights.RightUpdate AS RightUpdate,
	|	ProfileRolesRights.UnrestrictedAddRight AS UnrestrictedAddRight,
	|	ProfileRolesRights.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|	ProfileRolesRights.InteractiveAddRight AS InteractiveAddRight,
	|	ProfileRolesRights.EditRight AS EditRight,
	|	ProfileRolesRights.AccessGroup AS AccessGroup,
	|	PRESENTATION(ProfileRolesRights.AccessGroup) AS PresentationAccessGroups,
	|	ProfileRolesRights.AccessKind AS AccessKind,
	|	ProfileRolesRights.AccessKindPresentation AS AccessKindPresentation,
	|	ProfileRolesRights.AllAllowed AS AllAllowed,
	|	ProfileRolesRights.AccessValue AS AccessValue,
	|	PRESENTATION(ProfileRolesRights.AccessValue) AS AccessValuePresentation
	|FROM
	|	(SELECT
	|		RolesRights.MetadataObject AS Table,
	|		ProfilesRoles.Ref AS Profile,
	|		CASE
	|			WHEN RolesRights.UnrestrictedAddRight
	|					AND RolesRights.UnrestrictedUpdateRight
	|				THEN 0
	|			WHEN NOT RolesRights.UnrestrictedAddRight
	|					AND RolesRights.UnrestrictedUpdateRight
	|				THEN 100
	|			WHEN RolesRights.UnrestrictedAddRight
	|					AND NOT RolesRights.UnrestrictedUpdateRight
	|				THEN 200
	|			ELSE 300
	|		END + CASE
	|			WHEN RolesRights.AddRight
	|					AND RolesRights.RightUpdate
	|				THEN 0
	|			WHEN NOT RolesRights.AddRight
	|					AND RolesRights.RightUpdate
	|				THEN 10
	|			WHEN RolesRights.AddRight
	|					AND NOT RolesRights.RightUpdate
	|				THEN 20
	|			ELSE 30
	|		END + CASE
	|			WHEN RolesRights.InteractiveAddRight
	|					AND RolesRights.EditRight
	|				THEN 0
	|			WHEN NOT RolesRights.InteractiveAddRight
	|					AND RolesRights.EditRight
	|				THEN 1
	|			WHEN RolesRights.InteractiveAddRight
	|					AND NOT RolesRights.EditRight
	|				THEN 2
	|			ELSE 3
	|		END AS RolesKind,
	|		RolesRights.Role AS Role,
	|		RolesRights.AddRight AS AddRight,
	|		RolesRights.RightUpdate AS RightUpdate,
	|		RolesRights.UnrestrictedAddRight AS UnrestrictedAddRight,
	|		RolesRights.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|		RolesRights.InteractiveAddRight AS InteractiveAddRight,
	|		RolesRights.EditRight AS EditRight,
	|		UNDEFINED AS AccessGroup,
	|		UNDEFINED AS AccessKind,
	|		"""" AS AccessKindPresentation,
	|		UNDEFINED AS AllAllowed,
	|		UNDEFINED AS AccessValue
	|	FROM
	|		RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfilesRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfilesRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfilesRoles.Role
	|				AND (RolesRights.AddRight
	|					OR RolesRights.RightUpdate)
	|	
	|	UNION
	|	
	|	SELECT
	|		RolesRights.MetadataObject,
	|		UserProfiles.Profile,
	|		1000,
	|		"""",
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		AccessKindsAndValues.AccessGroup,
	|		ISNULL(AccessRestrictionKinds.AccessKind, UNDEFINED),
	|		ISNULL(AccessRestrictionKinds.AccessKindPresentation, """"),
	|		AccessKindsAndValues.AllAllowed,
	|		AccessKindsAndValues.AccessValue
	|	FROM
	|		RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfilesRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfilesRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfilesRoles.Role
	|				AND (RolesRights.AddRight)
	|			INNER JOIN AccessKindsAndValues AS AccessKindsAndValues
	|			ON (UserProfiles.Profile = AccessKindsAndValues.Profile)
	|			LEFT JOIN AccessRestrictionKinds AS AccessRestrictionKinds
	|			ON (AccessRestrictionKinds.Table = RolesRights.MetadataObject)
	|				AND (AccessRestrictionKinds.Right = ""Create"")
	|				AND (AccessRestrictionKinds.AccessKind = AccessKindsAndValues.AccessKind)
	|	
	|	UNION
	|	
	|	SELECT
	|		RolesRights.MetadataObject,
	|		UserProfiles.Profile,
	|		1000,
	|		"""",
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		AccessKindsAndValues.AccessGroup,
	|		ISNULL(AccessRestrictionKinds.AccessKind, UNDEFINED),
	|		ISNULL(AccessRestrictionKinds.AccessKindPresentation, """"),
	|		AccessKindsAndValues.AllAllowed,
	|		AccessKindsAndValues.AccessValue
	|	FROM
	|		RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfilesRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfilesRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfilesRoles.Role
	|				AND (RolesRights.RightUpdate)
	|			INNER JOIN AccessKindsAndValues AS AccessKindsAndValues
	|			ON (UserProfiles.Profile = AccessKindsAndValues.Profile)
	|			LEFT JOIN AccessRestrictionKinds AS AccessRestrictionKinds
	|			ON (AccessRestrictionKinds.Table = RolesRights.MetadataObject)
	|				AND (AccessRestrictionKinds.Right = ""Update"")
	|				AND (AccessRestrictionKinds.AccessKind = AccessKindsAndValues.AccessKind)) AS ProfileRolesRights
	|TOTALS
	|	MAX(ObjectsKind),
	|	MAX(Table),
	|	MAX(MetadataObjectID),
	|	MAX(ProfilePresentation),
	|	MAX(RolePresentation),
	|	MAX(AddRight),
	|	MAX(RightUpdate),
	|	MAX(UnrestrictedAddRight),
	|	MAX(UnrestrictedUpdateRight),
	|	MAX(InteractiveAddRight),
	|	MAX(EditRight),
	|	MAX(PresentationAccessGroups),
	|	MAX(AccessKindPresentation),
	|	MAX(AllAllowed)
	|BY
	|	ObjectsKind,
	|	Object,
	|	Profile,
	|	RolesKind,
	|	Role,
	|	AccessGroup,
	|	AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKindsAndValues.Profile AS Profile,
	|	AccessKindsAndValues.AccessGroup AS AccessGroup,
	|	AccessKindsAndValues.AccessKind AS AccessKind,
	|	AccessKindsAndValues.AllAllowed AS AllAllowed,
	|	AccessKindsAndValues.AccessValue AS AccessValue
	|FROM
	|	AccessKindsAndValues AS AccessKindsAndValues";
	// ACC:96-on

	Return Query.ExecuteBatch();

EndFunction

Procedure OutputAvailableForView(Val AvailableRights, Val Template, Val QueryResult, Val SimplifiedInterface)
	
	IndentArea = Template.GetArea("Indent");
	RightsObjects = QueryResult.Unload(QueryResultIteration.ByGroups); // ValueTree
	
	FillObjectsPresentations(RightsObjects);
	RightsObjects.Rows.Sort(
		"ObjectKindOrder Asc,
		|ObjectPresentation Asc,
		|ProfilePresentation Asc,
		|RolesKind Asc,
		|RolePresentation Asc,
		|PresentationAccessGroups Asc,
		|AccessKindPresentation Asc,
		|AccessValuePresentation Asc",
		True);
	
	Area = Template.GetArea("ObjectsRightsGroup");
	Area.Parameters.ObjectsRightsGroupPresentation = NStr("en = 'View objects';");
	Document.Put(Area, 1);
	Area = Template.GetArea("ViewObjectsLegend");
	Document.Put(Area, 2);
	
	RightsSettingsOwners = AvailableRights.ByRefsTypes;
	
	For Each ObjectsKindDetails In RightsObjects.Rows Do
		Area = Template.GetArea("ObjectRightsTableTitle");
		If SimplifiedInterface Then
			Area.Parameters.ProfilesOrAccessGroupsPresentation = NStr("en = 'Profiles';");
		Else
			Area.Parameters.ProfilesOrAccessGroupsPresentation = NStr("en = 'Access groups';");
		EndIf;
		Area.Parameters.Fill(ObjectsKindDetails);
		Document.Put(Area, 2);
		
		Area = Template.GetArea("ObjectRightsTableTitleAddl");
		If AccessRightsDetailedInfo Then
			Area.Parameters.ProfilesOrAccessGroupsPresentation = NStr("en = '(profile, roles)';");
		Else
			Area.Parameters.ProfilesOrAccessGroupsPresentation = "";
		EndIf;
		Area.Parameters.Fill(ObjectsKindDetails);
		Document.Put(Area, 3);
		
		For Each ObjectDetails In ObjectsKindDetails.Rows Do
			ObjectAreaInitialString = Undefined;
			ObjectAreaEndRow  = Undefined;
			Area = Template.GetArea("ObjectRightsTableString");
			
			Area.Parameters.OpenListForm = "OpenListForm: " + ObjectDetails.Table;
			
			If ObjectDetails.UnrestrictedReadRight Then
				If ObjectDetails.ViewRight Then
					ObjectPresentationClarification = NStr("en = '(view, unrestricted)';");
				Else
					ObjectPresentationClarification = NStr("en = '(view*, unrestricted)';");
				EndIf;
			Else
				If ObjectDetails.ViewRight Then
					ObjectPresentationClarification = NStr("en = '(view, restricted)';");
				Else
					ObjectPresentationClarification = NStr("en = '(view*, restricted)';");
				EndIf;
			EndIf;
			
			Area.Parameters.ObjectPresentation = ObjectDetails.ObjectPresentation + Chars.LF 
				+ ObjectPresentationClarification;
			
			For Each ProfileDetails In ObjectDetails.Rows Do
				ProfileRolesPresentation = "";
				RolesCount = 0;
				AllRolesWithRestriction = True;
				For Each RoleKindDetails In ProfileDetails.Rows Do
					If RoleKindDetails.RolesKind < 1000 Then
						// Description of the role with or without restrictions.
						For Each RoleDetails In RoleKindDetails.Rows Do
							
							If RoleKindDetails.UnrestrictedReadRight Then
								AllRolesWithRestriction = False;
							EndIf;
							
							If Not AccessRightsDetailedInfo Then
								Continue;
							EndIf;
							
							If RoleKindDetails.Rows.Count() > 1
								And RoleKindDetails.Rows.IndexOf(RoleDetails) < RoleKindDetails.Rows.Count() - 1 Then
								ProfileRolesPresentation = ProfileRolesPresentation + RoleDetails.RolePresentation + ",";
								RolesCount = RolesCount + 1;
							EndIf;
							
							If RoleKindDetails.Rows.IndexOf(RoleDetails) = RoleKindDetails.Rows.Count() - 1 Then
								ProfileRolesPresentation = ProfileRolesPresentation + RoleDetails.RolePresentation + ",";
								RolesCount = RolesCount + 1;
							EndIf;
							ProfileRolesPresentation = ProfileRolesPresentation + Chars.LF;
						EndDo;
					ElsIf RoleKindDetails.Rows[0].Rows.Count() > 0 Then
						// Description of access restrictions for roles with restrictions.
						For Each AccessGroupDetails In RoleKindDetails.Rows[0].Rows Do
							IndexOf = AccessGroupDetails.Rows.Count() - 1;
							While IndexOf >= 0 Do
								If AccessGroupDetails.Rows[IndexOf].AccessKind = Undefined Then
									AccessGroupDetails.Rows.Delete(IndexOf);
								EndIf;
								IndexOf = IndexOf - 1;
							EndDo;
							AccessGroupAreaInitialRow = Undefined;
							If Area = Undefined Then
								Area = Template.GetArea("ObjectRightsTableString");
							EndIf;
							If SimplifiedInterface Then
								Area.Parameters.ProfileOrAccessGroup = ProfileDetails.AccessGroup;
								
								Area.Parameters.ProfileOrAccessGroupPresentation =
								ProfileDetails.PresentationAccessGroups;
							Else
								Area.Parameters.ProfileOrAccessGroup = AccessGroupDetails.AccessGroup;
								If AccessRightsDetailedInfo Then
									ProfileRolesPresentation = TrimAll(ProfileRolesPresentation);
									
									If ValueIsFilled(ProfileRolesPresentation)
										And StrEndsWith(ProfileRolesPresentation, ",") Then
										
										ProfileRolesPresentation = Left(ProfileRolesPresentation, StrLen(ProfileRolesPresentation) - 1);
									EndIf;
									
									If RolesCount > 1 Then
										PresentationClarificationAccessGroups = NStr("en = '(profile: %1, roles:
											|%2)';")
									Else
										PresentationClarificationAccessGroups = NStr("en = '(profile: %1, role:
											|%2)';")
									EndIf;
									
									Area.Parameters.ProfileOrAccessGroupPresentation =
										AccessGroupDetails.PresentationAccessGroups + Chars.LF
										+ StringFunctionsClientServer.SubstituteParametersToString(PresentationClarificationAccessGroups,
											ProfileDetails.ProfilePresentation,
											TrimAll(ProfileRolesPresentation));
								Else
									Area.Parameters.ProfileOrAccessGroupPresentation =
									AccessGroupDetails.PresentationAccessGroups;
								EndIf;
							EndIf;
							If AllRolesWithRestriction Then
								If GetFunctionalOption("LimitAccessAtRecordLevel") Then
									For Each AccessKindDetails In AccessGroupDetails.Rows Do
										IndexOf = AccessKindDetails.Rows.Count()-1;
										While IndexOf >= 0 Do
											If AccessKindDetails.Rows[IndexOf].AccessValue = Undefined Then
												AccessKindDetails.Rows.Delete(IndexOf);
											EndIf;
											IndexOf = IndexOf - 1;
										EndDo;
										// Getting a new area if the access kind is not the first one.
										If Area = Undefined Then
											Area = Template.GetArea("ObjectRightsTableString");
										EndIf;
										
										Area.Parameters.AccessKind = AccessKindDetails.AccessKind;
										
										Area.Parameters.AccessKindPresentation = StringFunctionsClientServer.SubstituteParametersToString(
											AccessKindPresentationTemplate(
											AccessKindDetails, RightsSettingsOwners),
											AccessKindDetails.AccessKindPresentation);
										
										OutputArea(Document, Area, 3,
											ObjectAreaInitialString,
											ObjectAreaEndRow,
											AccessGroupAreaInitialRow);
										
										For Each AccessValueDetails In AccessKindDetails.Rows Do
											Area = Template.GetArea("ObjectRightsTableStringAccessValues");
											Area.Parameters.AccessValuePresentation = AccessValueDetails.AccessValuePresentation;
											Area.Parameters.AccessValue =	AccessValueDetails.AccessValue;
											
											OutputArea(Document, Area, 3,
												ObjectAreaInitialString,
												ObjectAreaEndRow,
												AccessGroupAreaInitialRow);
										EndDo;
									EndDo;
								EndIf;
							EndIf;
							If Area <> Undefined Then
								OutputArea(Document, Area, 3,
									ObjectAreaInitialString,
									ObjectAreaEndRow,
									AccessGroupAreaInitialRow);
							EndIf;
							SetKindsAndAccessValuesBoundaries(Document, AccessGroupAreaInitialRow, 
								ObjectAreaEndRow);

							MergeCellsSetBoundaries(Document,
								AccessGroupAreaInitialRow,
								ObjectAreaEndRow,
								3);
						EndDo;
					EndIf;
				EndDo;
			EndDo;
			MergeCellsSetBoundaries(Document, ObjectAreaInitialString, ObjectAreaEndRow, 2);
		EndDo;
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
	EndDo;
	Document.Put(IndentArea, 2);
	Document.Put(IndentArea, 2);

EndProcedure

Procedure OutputAvailableForEdit(Val AvailableRights, Val Template, Val QueryResult,
	Val SimplifiedInterface)

	IndentArea = Template.GetArea("Indent");
	RightsObjects = QueryResult.Unload(QueryResultIteration.ByGroups); // ValueTree
	
	FillObjectsPresentations(RightsObjects);
	RightsObjects.Rows.Sort(
		"ObjectKindOrder Asc,
		|ObjectPresentation Asc,
		|ProfilePresentation Asc,
		|RolesKind Asc,
		|RolePresentation Asc,
		|PresentationAccessGroups Asc,
		|AccessKindPresentation Asc,
		|AccessValuePresentation Asc", True);

	Area = Template.GetArea("ObjectsRightsGroup");
	Area.Parameters.ObjectsRightsGroupPresentation = NStr("en = 'Editing objects';");
	Document.Put(Area, 1);
	Area = Template.GetArea("ObjectsEditLegend");
	Document.Put(Area, 2);

	For Each ObjectsKindDetails In RightsObjects.Rows Do
		Area = Template.GetArea("ObjectRightsTableTitle");
		If SimplifiedInterface Then
			Area.Parameters.ProfilesOrAccessGroupsPresentation = NStr("en = 'Profiles';");
		Else
			Area.Parameters.ProfilesOrAccessGroupsPresentation = NStr("en = 'Access groups';");
		EndIf;
		Area.Parameters.Fill(ObjectsKindDetails);
		Document.Put(Area, 2);

		Area = Template.GetArea("ObjectRightsTableTitleAddl");
		If AccessRightsDetailedInfo Then
			Area.Parameters.ProfilesOrAccessGroupsPresentation = NStr("en = '(profile, roles)';");
		Else
			Area.Parameters.ProfilesOrAccessGroupsPresentation = "";
		EndIf;
		Area.Parameters.Fill(ObjectsKindDetails);
		Document.Put(Area, 3);

		InsertUsed = StandardSubsystemsServer.IsRegisterTable(ObjectsKindDetails.Table);

		For Each ObjectDetails In ObjectsKindDetails.Rows Do
			ObjectAreaInitialString = Undefined;
			ObjectAreaEndRow  = Undefined;
			Area = Template.GetArea("ObjectRightsTableString");

			Area.Parameters.OpenListForm = "OpenListForm: " + ObjectDetails.Table;

			If InsertUsed Then
				If ObjectDetails.AddRight And ObjectDetails.RightUpdate Then
					If ObjectDetails.UnrestrictedAddRight And ObjectDetails.UnrestrictedUpdateRight Then
						If ObjectDetails.InteractiveAddRight And ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Add, unrestricted
																 |Edit, unrestricted)';");
						ElsIf Not ObjectDetails.InteractiveAddRight And ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Add*, unrestricted
																 |Edit, unrestricted)';");
						ElsIf ObjectDetails.InteractiveAddRight And Not ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Add, unrestricted
																 |Edit*, unrestricted)';");
						Else // Not ObjectDetails.InteractiveAddRight And Not ObjectDetails.EditRight.
							ObjectPresentationClarification = NStr("en = '(Add*, unrestricted
																 |Edit*, unrestricted)';");
						EndIf;
					ElsIf Not ObjectDetails.UnrestrictedAddRight
						And ObjectDetails.UnrestrictedUpdateRight Then
						If ObjectDetails.InteractiveAddRight And ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Add, restricted
																 |Edit unrestricted)';");
						ElsIf Not ObjectDetails.InteractiveAddRight And ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Add*, restricted
																 |Edit, unrestricted)';");
						ElsIf ObjectDetails.InteractiveAddRight And Not ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Add, restricted
																 |Edit*, unrestricted)';");
						Else // Not ObjectDetails.InteractiveAddRight And Not ObjectDetails.EditRight.
							ObjectPresentationClarification = NStr("en = '(Add*, restricted
																 |Edit*, unrestricted)';");
						EndIf;
					ElsIf ObjectDetails.UnrestrictedAddRight And Not ObjectDetails.UnrestrictedUpdateRight Then
						If ObjectDetails.InteractiveAddRight And ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Add, unrestricted
																 |Edit, restricted)';");
						ElsIf Not ObjectDetails.InteractiveAddRight And ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Add*, unrestricted
																 |Edit, restricted)';");
						ElsIf ObjectDetails.InteractiveAddRight And Not ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Add, unrestricted
																 |Edit*, restricted)';");
						Else // Not ObjectDetails.InteractiveAddRight And Not ObjectDetails.EditRight.
							ObjectPresentationClarification = NStr("en = '(Add*, unrestricted
																 |Edit*, restricted)';");
						EndIf;
					Else // Not ObjectDetails.UnrestrictedAddRight And Not ObjectDetails.UnrestrictedUpdateRight.
						If ObjectDetails.InteractiveAddRight And ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Add, restricted
																 |Edit, restricted)';");
						ElsIf Not ObjectDetails.InteractiveAddRight And ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Add*, restricted
																 |Edit, restricted)';");
						ElsIf ObjectDetails.InteractiveAddRight And Not ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Add, restricted
																 |Edit*, restricted)';");
						Else // Not ObjectDetails.InteractiveAddRight And Not ObjectDetails.EditRight.
							ObjectPresentationClarification = NStr("en = '(Add*, restricted
																 |Edit*, restricted)';");
						EndIf;
					EndIf;

				ElsIf Not ObjectDetails.AddRight And ObjectDetails.RightUpdate Then

					If ObjectDetails.UnrestrictedUpdateRight Then
						If ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Add unavailable 
																 |Edit, unrestricted)';");
						Else // Not ObjectDetails.EditRight.
							ObjectPresentationClarification = NStr("en = '(Add unavailable 
																 |Edit*, unrestricted)';");
						EndIf;
					Else // Not ObjectDetails.UnrestrictedUpdateRight.
						If ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Add unavailable
																 |Edit, restricted)';");
						Else // Not ObjectDetails.EditRight.
							ObjectPresentationClarification = NStr("en = '(Add unavailable 
																 |Edit*, restricted)';");
						EndIf;
					EndIf;

				Else // Not ObjectDetails.AddRight And Not ObjectDetails.UpdateRight.
					ObjectPresentationClarification = NStr("en = '(Add unavailable 
														 |Edit unavailable)';");
				EndIf;
			Else
				If ObjectDetails.RightUpdate Then
					If ObjectDetails.UnrestrictedUpdateRight Then
						If ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Edit, unrestricted)';");
						Else // Not ObjectDetails.EditRight.
							ObjectPresentationClarification = NStr("en = '(Edit*, unrestricted)';");
						EndIf;
					Else
						If ObjectDetails.EditRight Then
							ObjectPresentationClarification = NStr("en = '(Edit, restricted)';");
						Else // Not ObjectDetails.EditRight.
							ObjectPresentationClarification = NStr("en = '(Edit*, restricted)';");
						EndIf;
					EndIf;
				Else // Not ObjectDetails.UpdateRight.
					ObjectPresentationClarification = NStr("en = '(Edit unavailable)';");
				EndIf;
			EndIf;

			Area.Parameters.ObjectPresentation = ObjectDetails.ObjectPresentation + Chars.LF
				+ ObjectPresentationClarification;

			For Each ProfileDetails In ObjectDetails.Rows Do
				ProfileRolesPresentation = "";
				RolesCount = 0;
				AllRolesWithRestriction = True;
				For Each RoleKindDetails In ProfileDetails.Rows Do
					If RoleKindDetails.RolesKind < 1000 Then
						// Description of the role with or without restrictions.
						For Each RoleDetails In RoleKindDetails.Rows Do

							If RoleKindDetails.UnrestrictedAddRight And RoleKindDetails.UnrestrictedUpdateRight Then
								AllRolesWithRestriction = False;
							EndIf;

							If Not AccessRightsDetailedInfo Then
								Continue;
							EndIf;

							If RoleKindDetails.Rows.Count() > 1 
								And RoleKindDetails.Rows.IndexOf(RoleDetails) < RoleKindDetails.Rows.Count() - 1 Then
								ProfileRolesPresentation = ProfileRolesPresentation + RoleDetails.RolePresentation + ",";
								RolesCount = RolesCount + 1;
							EndIf;

							If RoleKindDetails.Rows.IndexOf(RoleDetails) = RoleKindDetails.Rows.Count() - 1 Then
								ProfileRolesPresentation = ProfileRolesPresentation + RoleDetails.RolePresentation + ",";
								RolesCount = RolesCount + 1;
							EndIf;
							ProfileRolesPresentation = ProfileRolesPresentation + Chars.LF;
						EndDo;
					ElsIf RoleKindDetails.Rows[0].Rows.Count() > 0 Then
						// Description of access restrictions for roles with restrictions.
						For Each AccessGroupDetails In RoleKindDetails.Rows[0].Rows Do
							IndexOf = AccessGroupDetails.Rows.Count() - 1;
							While IndexOf >= 0 Do
								If AccessGroupDetails.Rows[IndexOf].AccessKind = Undefined Then
									AccessGroupDetails.Rows.Delete(IndexOf);
								EndIf;
								IndexOf = IndexOf - 1;
							EndDo;
							AccessGroupAreaInitialRow = Undefined;
							If Area = Undefined Then
								Area = Template.GetArea("ObjectRightsTableString");
							EndIf;
							If SimplifiedInterface Then
								Area.Parameters.ProfileOrAccessGroup = ProfileDetails.AccessGroup;
								Area.Parameters.ProfileOrAccessGroupPresentation = ProfileDetails.PresentationAccessGroups;
							Else
								Area.Parameters.ProfileOrAccessGroup = AccessGroupDetails.AccessGroup;
								If AccessRightsDetailedInfo Then
									ProfileRolesPresentation = TrimAll(ProfileRolesPresentation);

									If ValueIsFilled(ProfileRolesPresentation) 
										And StrEndsWith(ProfileRolesPresentation, ",") Then
										ProfileRolesPresentation = Left(ProfileRolesPresentation, StrLen(ProfileRolesPresentation) - 1);
									EndIf;
									If RolesCount > 1 Then
										PresentationClarificationAccessGroups = NStr("en = '(profile: %1, roles:
																				   |%2)';");
									Else
										PresentationClarificationAccessGroups = NStr("en = '(profile: %1, role:
																				   |%2)';");
									EndIf;

									Area.Parameters.ProfileOrAccessGroupPresentation = AccessGroupDetails.PresentationAccessGroups
										+ Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
										PresentationClarificationAccessGroups, ProfileDetails.ProfilePresentation,
										TrimAll(ProfileRolesPresentation));
								Else
									Area.Parameters.ProfileOrAccessGroupPresentation = AccessGroupDetails.PresentationAccessGroups;
								EndIf;
							EndIf;
							If AllRolesWithRestriction Then
								If GetFunctionalOption("LimitAccessAtRecordLevel") Then
									For Each AccessKindDetails In AccessGroupDetails.Rows Do
										IndexOf = AccessKindDetails.Rows.Count() - 1;
										While IndexOf >= 0 Do
											If AccessKindDetails.Rows[IndexOf].AccessValue = Undefined Then
												AccessKindDetails.Rows.Delete(IndexOf);
											EndIf;
											IndexOf = IndexOf - 1;
										EndDo;
										// Getting a new area if the access kind is not the first one.
										If Area = Undefined Then
											Area = Template.GetArea("ObjectRightsTableString");
										EndIf;

										Area.Parameters.AccessKind = AccessKindDetails.AccessKind;
										Area.Parameters.AccessKindPresentation = StringFunctionsClientServer.SubstituteParametersToString(
											AccessKindPresentationTemplate(AccessKindDetails,
											AvailableRights.ByRefsTypes), AccessKindDetails.AccessKindPresentation);

										OutputArea(Document, Area, 3, ObjectAreaInitialString,
											ObjectAreaEndRow, AccessGroupAreaInitialRow);

										For Each AccessValueDetails In AccessKindDetails.Rows Do
											Area = Template.GetArea("ObjectRightsTableStringAccessValues");
											Area.Parameters.AccessValuePresentation = AccessValueDetails.AccessValuePresentation;
											Area.Parameters.AccessValue = AccessValueDetails.AccessValue;

											OutputArea(Document, Area, 3, ObjectAreaInitialString,
												ObjectAreaEndRow, AccessGroupAreaInitialRow);
										EndDo;
									EndDo;
								EndIf;
							EndIf;
							If Area <> Undefined Then
								OutputArea(Document, Area, 3, ObjectAreaInitialString, ObjectAreaEndRow,
									AccessGroupAreaInitialRow);
							EndIf;
							// Setting boundaries for access kinds of the current access group.
							SetKindsAndAccessValuesBoundaries(Document, AccessGroupAreaInitialRow, 
								ObjectAreaEndRow);
							
							// Merging access group cells and setting boundaries.
							MergeCellsSetBoundaries(Document, AccessGroupAreaInitialRow, 
								ObjectAreaEndRow, 3);
						EndDo;
					EndIf;
				EndDo;
			EndDo;
			// Merging object cells and setting boundaries.
			MergeCellsSetBoundaries(Document, ObjectAreaInitialString, ObjectAreaEndRow, 2);
		EndDo;
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
	EndDo;
	Document.Put(IndentArea, 2);
	Document.Put(IndentArea, 2);

EndProcedure

Procedure FillObjectsPresentations(RightsObjects)
	
	RightsObjects.Columns.Add("ObjectsKindPresentation", New TypeDescription("String"));
	RightsObjects.Columns.Add("ObjectPresentation", New TypeDescription("String"));
	
	MedatadataKindIDs = RightsObjects.Rows.UnloadColumn("MetadataObjectID");
	MetadataObjectsKinds = Common.MetadataObjectsByIDs(MedatadataKindIDs, False);
	MetadataObjectsCollections = StandardSubsystemsCached.MetadataObjectCollectionProperties();

	For Each ObjectsKindDetails In RightsObjects.Rows Do
		MetadataObject = MetadataObjectsKinds[ObjectsKindDetails.MetadataObjectID];
		If MetadataObject <> Undefined Then
			BaseTypeName = Common.BaseTypeNameByMetadataObject(MetadataObject);
			If BaseTypeName <> "" Then
				CollectionProperties = MetadataObjectsCollections.Find(BaseTypeName, "Name");
				If CollectionProperties <> Undefined Then 
					ObjectsKindDetails.ObjectsKindPresentation = CollectionProperties.Synonym;
				EndIf;
			EndIf;
		EndIf;
		If Not ValueIsFilled(ObjectsKindDetails.ObjectsKindPresentation) Then
			ObjectsKindDetails.ObjectsKindPresentation = ObjectsKindDetails.ObjectsKind;
		EndIf;
		
		MetadataObjectIDs = ObjectsKindDetails.Rows.UnloadColumn("MetadataObjectID");
		MetadataObjects = Common.MetadataObjectsByIDs(MetadataObjectIDs, False);
		For Each ObjectDetails In ObjectsKindDetails.Rows Do
			MetadataObject = MetadataObjects[ObjectDetails.MetadataObjectID];
			If MetadataObject <> Undefined Then
				ObjectDetails.ObjectPresentation = MetadataObject.Synonym;
			Else
				ObjectDetails.ObjectPresentation = NStr("en = 'does not exist';") + " " + ObjectDetails.Table;
			EndIf;
		EndDo;
	EndDo;
		
EndProcedure

Procedure OutputRightsToSeparateObjects(Val AvailableRights, Val Template, Val QueryResult, Val OutputGroupRights)

	IndentArea = Template.GetArea("Indent");

	RightsSettings = QueryResult.Unload(QueryResultIteration.ByGroups); // ValueTable
	RightsSettings.Columns.Add("FullNameObjectsType");
	RightsSettings.Columns.Add("ObjectsKindPresentation");
	RightsSettings.Columns.Add("FullDescr");

	For Each ObjectsTypeDetails In RightsSettings.Rows Do
		TypeMetadata = Metadata.FindByType(ObjectsTypeDetails.ObjectType);
		ObjectsTypeDetails.FullNameObjectsType      = TypeMetadata.FullName();
		ObjectsTypeDetails.ObjectsKindPresentation = TypeMetadata.Presentation();
	EndDo;
	RightsSettings.Rows.Sort("ObjectsKindPresentation Asc");

	For Each ObjectsTypeDetails In RightsSettings.Rows Do

		RightsDetails = AvailableRights.ByRefsTypes.Get(ObjectsTypeDetails.ObjectType);

		If AvailableRights.HierarchicalTables.Get(ObjectsTypeDetails.ObjectType) = Undefined Then
			ObjectsTypeRootItems = Undefined;
		Else
			// @skip-check query-in-loop - A minor loop (1 or 2 iterations)
			ObjectsTypeRootItems = ObjectsTypeRootItems(ObjectsTypeDetails.ObjectType);
		EndIf;

		For Each ObjectDetails In ObjectsTypeDetails.Rows Do
			ObjectDetails.FullDescr = ObjectDetails.Object.FullDescr();
		EndDo;
		ObjectsTypeDetails.Rows.Sort("FullDescr Asc");

		Area = Template.GetArea("RightsSettingsGroup");
		Area.Parameters.Fill(ObjectsTypeDetails);
		Document.Put(Area, 1);
		
		// Output the legend.
		Area = Template.GetArea("RightsSettingsLegendHeader");
		Document.Put(Area, 2);
		For Each RightDetails In RightsDetails Do
			RightPresentations = InformationRegisters.ObjectsRightsSettings.AvailableRightPresentation(RightDetails);
			Area = Template.GetArea("RightsSettingsLegendString");
			Area.Parameters.Title = StrReplace(RightPresentations.Title, Chars.LF, " ");
			Area.Parameters.ToolTip = StrReplace(RightPresentations.ToolTip, Chars.LF, " ");
			Document.Put(Area, 2);
		EndDo;

		TitleForSubfolders = NStr("en = 'For
									|subfolders';");
		TooltipForSubfolders = NStr("en = 'Rights both for the current folder and its subfolders';");

		Area = Template.GetArea("RightsSettingsLegendString");
		Area.Parameters.Title = StrReplace(TitleForSubfolders, Chars.LF, " ");
		Area.Parameters.ToolTip = StrReplace(TooltipForSubfolders, Chars.LF, " ");
		Document.Put(Area, 2);

		TitleSettingReceivedFromGroup = NStr("en = 'Rights inherited from group';");

		Area = Template.GetArea("RightsSettingsLegendStringInheritance");
		Area.Parameters.ToolTip = NStr("en = 'Right inheritance from parent folders';");
		Document.Put(Area, 2);

		Document.Put(IndentArea, 2);
		
		// Prepare a row template.
		HeaderTemplate  = New SpreadsheetDocument;
		RowTemplate = New SpreadsheetDocument;
		OutputUserGroups = ObjectsTypeDetails.GroupParticipation And Not OutputGroupRights;
		ColumnsCount = RightsDetails.Count() + ?(OutputUserGroups, 2, 1);

		For ColumnNumber = 1 To ColumnsCount Do
			NewHeaderCell  = Template.GetArea("RightsSettingsDetailsCellHeader");
			HeaderCell = HeaderTemplate.Join(NewHeaderCell);
			HeaderCell.HorizontalAlign = HorizontalAlign.Center;
			NewRowCell = Template.GetArea("RightsSettingsDetailsCellRows");
			RowCell = RowTemplate.Join(NewRowCell);
			RowCell.HorizontalAlign = HorizontalAlign.Center;
		EndDo;

		If OutputUserGroups Then
			HeaderCell.HorizontalAlign  = HorizontalAlign.Left;
			RowCell.HorizontalAlign = HorizontalAlign.Left;
		EndIf;
		
		// Output the table header.
		CellNumberForSubfolders = "R1C" + Format(RightsDetails.Count() + 1, "NG=");

		HeaderTemplate.Area(CellNumberForSubfolders).Text = TitleForSubfolders;
		HeaderTemplate.Area(CellNumberForSubfolders).ColumnWidth = MaxStringLength(
			HeaderTemplate.Area(CellNumberForSubfolders).Text);

		Offset = 1;

		CurrentAreaNumber = Offset;
		For Each RightDetails In RightsDetails Do
			RightPresentations = InformationRegisters.ObjectsRightsSettings.AvailableRightPresentation(RightDetails);
			CellNumber = "R1C" + Format(CurrentAreaNumber, "NG=");
			HeaderTemplate.Area(CellNumber).Text = RightPresentations.Title;
			HeaderTemplate.Area(CellNumber).ColumnWidth = MaxStringLength(RightPresentations.Title);
			CurrentAreaNumber = CurrentAreaNumber + 1;

			RowTemplate.Area(CellNumber).ColumnWidth = HeaderTemplate.Area(CellNumber).ColumnWidth;
		EndDo;

		If OutputUserGroups Then
			CellNumberForGroup = "R1C" + Format(ColumnsCount, "NG=");
			HeaderTemplate.Area(CellNumberForGroup).Text = TitleSettingReceivedFromGroup;
			HeaderTemplate.Area(CellNumberForGroup).ColumnWidth = 35;
		EndIf;
		Document.Put(HeaderTemplate, 2);

		TextYes  = NStr("en = 'Yes';");
		TextNo = NStr("en = 'No';");
		
		// Output table rows.
		For Each ObjectDetails In ObjectsTypeDetails.Rows Do

			If ObjectsTypeRootItems = Undefined Or ObjectsTypeRootItems.Get(
				ObjectDetails.Object) <> Undefined Then
				Area = Template.GetArea("RightsSettingsDetailsObject");

			ElsIf ObjectDetails.Inherit Then
				Area = Template.GetArea("RightsSettingsDetailsObjectInheritYes");
			Else
				Area = Template.GetArea("RightsSettingsDetailsObjectInheritNo");
			EndIf;

			Area.Parameters.Fill(ObjectDetails);
			Document.Put(Area, 2);
			For Each UserDetails In ObjectDetails.Rows Do

				For RightAreaNumber = 1 To ColumnsCount Do
					CellNumber = "R1C" + Format(RightAreaNumber, "NG=");
					RowTemplate.Area(CellNumber).Text = "";
				EndDo;

				If TypeOf(UserDetails.InheritanceIsAllowed) = Type("Boolean") Then
					RowTemplate.Area(CellNumberForSubfolders).Text = 
						?(UserDetails.InheritanceIsAllowed, TextYes, TextNo);
				EndIf;

				OwnerRights = AvailableRights.ByTypes.Get(ObjectsTypeDetails.ObjectType);
				For Each CurrentRightDetails In UserDetails.Rows Do
					OwnerRight = OwnerRights.Get(CurrentRightDetails.Right);
					If OwnerRight <> Undefined Then
						RightAreaNumber = OwnerRight.RightIndex + Offset;
						CellNumber = "R1C" + Format(RightAreaNumber, "NG=");
						RowTemplate.Area(CellNumber).Text = ?(
							CurrentRightDetails.RightIsProhibited, TextNo, TextYes);
					EndIf;
				EndDo;
				If OutputUserGroups Then
					If UserDetails.GroupParticipation Then
						RowTemplate.Area(CellNumberForGroup).Text = UserDetails.UserDescription1;
						RowTemplate.Area(CellNumberForGroup).DetailsParameter = "User";
						RowTemplate.Parameters.User = UserDetails.User;
					EndIf;
				EndIf;
				RowTemplate.Area(CellNumberForGroup).ColumnWidth = 35;
				Document.Put(RowTemplate, 2);
			EndDo;
		EndDo;
	EndDo;

EndProcedure

Procedure OutputReportHeader(Val Template, Properties, Val UserOrGroup)

	If TypeOf(UserOrGroup) = Type("CatalogRef.Users") Then
		Properties.Insert("ReportHeader", NStr("en = 'User rights report';"));
		Properties.Insert("RolesByProfilesGroup", NStr("en = 'User roles by profiles';"));
		Properties.Insert("ObjectPresentation", NStr("en = 'User: %1';"));

	ElsIf TypeOf(UserOrGroup) = Type("CatalogRef.ExternalUsers") Then
		Properties.Insert("ReportHeader", NStr("en = 'External user rights report';"));
		Properties.Insert("RolesByProfilesGroup", NStr("en = 'External user roles by profiles';"));
		Properties.Insert("ObjectPresentation", NStr("en = 'External user: %1';"));

	ElsIf TypeOf(UserOrGroup) = Type("CatalogRef.UserGroups") Then
		Properties.Insert("ReportHeader", NStr("en = 'User group rights report';"));
		Properties.Insert("RolesByProfilesGroup", NStr("en = 'User group roles by profiles';"));
		Properties.Insert("ObjectPresentation", NStr("en = 'User group: %1';"));
	Else
		Properties.Insert("ReportHeader", NStr("en = 'External user group rights report';"));
		Properties.Insert("RolesByProfilesGroup", NStr("en = 'External user group roles by profiles';"));
		Properties.Insert("ObjectPresentation", NStr("en = 'External user group: %1';"));
	EndIf;

	Properties.ObjectPresentation = StringFunctionsClientServer.SubstituteParametersToString(
		Properties.ObjectPresentation, String(UserOrGroup));
	
	// Output the title.
	Area = Template.GetArea("Title");
	Area.Parameters.Fill(Properties);
	Document.Put(Area);

EndProcedure

Procedure OutputIBUserProperties(Val Template, Val UserOrGroup)

	Document.StartRowAutoGrouping();
	Document.Put(Template.GetArea("IBUserPropertiesGroup"), 1,, True);
	Area = Template.GetArea("IBUserPropertiesDetails1");

	SetPrivilegedMode(True);
	IBUserProperies = Users.IBUserProperies(
		Common.ObjectAttributeValue(UserOrGroup, "IBUserID"));
	SetPrivilegedMode(False);

	If IBUserProperies <> Undefined Then
		Area.Parameters.CanSignIn = Users.CanSignIn(
		IBUserProperies);

		Document.Put(Area, 2);

		Area = Template.GetArea("IBUserPropertiesDetails2");
		Area.Parameters.Fill(IBUserProperies);
		Area.Parameters.LanguagePresentation = LanguagePresentation(IBUserProperies.Language);
		Area.Parameters.RunModePresentation = PresentationRunMode(IBUserProperies.RunMode);
		If Not ValueIsFilled(IBUserProperies.OSUser) Then
			Area.Parameters.OSUser = NStr("en = 'Not specified';");
		EndIf;
		Document.Put(Area, 2);
	Else
		Area.Parameters.CanSignIn = False;
		Document.Put(Area, 2);
	EndIf;
	Document.EndRowAutoGrouping();

EndProcedure

Procedure OutputDetailedInfoOnAccessRights(Val Template, UserOrGroup, Val QueryResult, Properties)

	IndentArea = Template.GetArea("Indent");
	
	// Output access groups.
	AccessGroupsDetails = QueryResult.Unload(QueryResultIteration.ByGroups).Rows;
	OnePersonalGroup = AccessGroupsDetails.Count() = 1 And ValueIsFilled(AccessGroupsDetails[0].Member);

	Area = Template.GetArea("AllAccessGroupsGroup");
	Area.Parameters.Fill(Properties);

	If OnePersonalGroup Then
		If TypeOf(UserOrGroup) = Type("CatalogRef.Users") Then
			AccessPresentation = NStr("en = 'User access restrictions';");

		ElsIf TypeOf(UserOrGroup) = Type("CatalogRef.ExternalUsers") Then
			AccessPresentation = NStr("en = 'External user access restrictions';");

		ElsIf TypeOf(UserOrGroup) = Type("CatalogRef.UserGroups") Then
			AccessPresentation = NStr("en = 'User group access restrictions';");
		Else
			AccessPresentation = NStr("en = 'External user group access restrictions';");
		EndIf;
	Else
		If TypeOf(UserOrGroup) = Type("CatalogRef.Users") Then
			AccessPresentation = NStr("en = 'User access groups';");

		ElsIf TypeOf(UserOrGroup) = Type("CatalogRef.ExternalUsers") Then
			AccessPresentation = NStr("en = 'External user access groups';");

		ElsIf TypeOf(UserOrGroup) = Type("CatalogRef.UserGroups") Then
			AccessPresentation = NStr("en = 'User group access groups';");
		Else
			AccessPresentation = NStr("en = 'External user group access groups';");
		EndIf;
	EndIf;

	Area.Parameters.AccessPresentation = AccessPresentation;

	Document.Put(Area, 1);
	Document.Put(IndentArea, 2);

	For Each AccessGroupDetails In AccessGroupsDetails Do
		If Not OnePersonalGroup Then
			Area = Template.GetArea("AccessGroupGroup");
			Area.Parameters.Fill(AccessGroupDetails);
			Document.Put(Area, 2);
		EndIf;
		// Displaying group membership.
		If AccessGroupDetails.Rows.Count() = 1 And AccessGroupDetails.Rows[0].Member = UserOrGroup Then
			// The user is included into an access group explicitly.
			// Therefore, no need to output.
		Else
			Area = Template.GetArea("AccessGroupDetailsUserIsInGroup");
			Document.Put(Area, 3);
			If AccessGroupDetails.Rows.Find(UserOrGroup, "Member") <> Undefined Then
				Area = Template.GetArea("AccessGroupDetailsUserIsInGroupExplicitly");
				Document.Put(Area, 3);
			EndIf;
			Filter = New Structure("GroupParticipation", True);
			UserGroupsDetails = AccessGroupDetails.Rows.FindRows(Filter);
			
			If UserGroupsDetails.Count() > 0 Then

				Area = Template.GetArea("AccessGroupDetailsUserIsInGroupAsUserGroupMember");
				Document.Put(Area, 3);

				For Each UserGroupDetails In UserGroupsDetails Do
					Area = Template.GetArea("AccessGroupDetailsUserIsInGroupAsMemberPresentation");
					Area.Parameters.Fill(UserGroupDetails);
					Document.Put(Area, 3);
				EndDo;
			EndIf;
		EndIf;

		If Not OnePersonalGroup Then
			// Output the profile.
			Area = Template.GetArea("AccessGroupDetailsProfile");
			Area.Parameters.Fill(AccessGroupDetails);
			Document.Put(Area, 3);
		EndIf;
		
		// Displaying the employee responsible for the list of group members.
		If Not OnePersonalGroup And ValueIsFilled(AccessGroupDetails.EmployeeResponsible) Then
			Area = Template.GetArea("AccessGroupDetailsEmployeeResponsible");
			Area.Parameters.Fill(AccessGroupDetails);
			Document.Put(Area, 3);
		EndIf;
		
		// Output the description.
		If Not OnePersonalGroup And ValueIsFilled(AccessGroupDetails.Comment) Then
			Area = Template.GetArea("AccessGroupDetailsComment");
			Area.Parameters.Fill(AccessGroupDetails);
			Document.Put(Area, 3);
		EndIf;

		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
	EndDo;

EndProcedure

Procedure OutputRolesByProfiles(Val Template, UserOrGroup, Val QueryResult, Properties)

	IndentArea = Template.GetArea("Indent");
	RolesByProfiles = QueryResult.Unload(QueryResultIteration.ByGroups);
	RolesByProfiles.Rows.Sort("ProfilePresentation Asc, RolePresentation Asc");

	If RolesByProfiles.Rows.Count() > 0 Then
		Area = Template.GetArea("RolesByProfilesGroup");
		Area.Parameters.Fill(Properties);
		Document.Put(Area, 1);
		Document.Put(IndentArea, 2);

		For Each ProfileDetails In RolesByProfiles.Rows Do
			Area = Template.GetArea("RolesByProfilesProfilePresentation");
			Area.Parameters.Fill(ProfileDetails);
			Document.Put(Area, 2);
			For Each RoleDetails In ProfileDetails.Rows Do
				Area = Template.GetArea("RolesByProfilesRolePresentation");
				Area.Parameters.Fill(RoleDetails);
				Document.Put(Area, 3);
			EndDo;
		EndDo;
	EndIf;
	Document.Put(IndentArea, 2);
	Document.Put(IndentArea, 2);

EndProcedure

Function AccessKindPresentationTemplate(AccessKindDetails, RightsSettingsOwners)

	If AccessKindDetails.Rows.Count() = 0 Then
		If RightsSettingsOwners.Get(TypeOf(AccessKindDetails.AccessKind)) <> Undefined Then
			AccessKindPresentationTemplate = "%1";

		ElsIf AccessKindDetails.AllAllowed Then
			If AccessKindDetails.AccessKind = Catalogs.Users.EmptyRef()
			 Or AccessKindDetails.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				
				AccessKindPresentationTemplate = NStr("en = '%1 (No forbidden: Authorized user and their groups are always allowed)';");
			Else
				AccessKindPresentationTemplate = NStr("en = '%1 (none denied)';");
			EndIf;
		Else
			If AccessKindDetails.AccessKind = Catalogs.Users.EmptyRef()
			 Or AccessKindDetails.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				
				AccessKindPresentationTemplate = NStr("en = '%1 (No allowed: Authorized user and their groups are always allowed)';");
			Else
				AccessKindPresentationTemplate = NStr("en = '%1 (none allowed)';");
			EndIf;
		EndIf;
	Else
		If AccessKindDetails.AllAllowed Then
			If AccessKindDetails.AccessKind = Catalogs.Users.EmptyRef()
			 Or AccessKindDetails.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				
				AccessKindPresentationTemplate = NStr("en = '%1 (Forbidden: Authorized user and their groups are always allowed):';");
			Else
				AccessKindPresentationTemplate = NStr("en = '%1 (denied):';");
			EndIf;
		Else
			If AccessKindDetails.AccessKind = Catalogs.Users.EmptyRef()
			 Or AccessKindDetails.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				
				AccessKindPresentationTemplate = NStr("en = '%1 (Allowed: Authorized user and their groups are always allowed):';");
			Else
				AccessKindPresentationTemplate = NStr("en = '%1 (allowed):';");
			EndIf;
		EndIf;
	EndIf;

	Return AccessKindPresentationTemplate;

EndFunction

Procedure OutputArea(Val Document, Area, Level, ObjectAreaInitialString, ObjectAreaEndRow,
	AccessGroupAreaInitialRow)

	If ObjectAreaInitialString = Undefined Then
		ObjectAreaInitialString = Document.Put(Area, Level);
		ObjectAreaEndRow  = ObjectAreaInitialString;
	Else
		ObjectAreaEndRow = Document.Put(Area);
	EndIf;

	If AccessGroupAreaInitialRow = Undefined Then
		AccessGroupAreaInitialRow = ObjectAreaEndRow;
	EndIf;

	Area = Undefined;

EndProcedure

Procedure MergeCellsSetBoundaries(Val Document, Val InitialAreaString, Val EndAreaRow,
	Val ColumnNumber)

	Area = Document.Area(InitialAreaString.Top, ColumnNumber, EndAreaRow.Bottom, ColumnNumber);
	Area.Merge();

	BoundaryString = New Line(SpreadsheetDocumentCellLineType.Dotted);

	Area.TopBorder = BoundaryString;
	Area.BottomBorder  = BoundaryString;

EndProcedure

Procedure SetKindsAndAccessValuesBoundaries(Val Document, Val AccessGroupAreaInitialRow,
	Val ObjectAreaEndRow)

	BoundaryString = New Line(SpreadsheetDocumentCellLineType.Dotted);

	Area = Document.Area(AccessGroupAreaInitialRow.Top, 4, AccessGroupAreaInitialRow.Top, 5);
	Area.TopBorder = BoundaryString;

	Area = Document.Area(ObjectAreaEndRow.Bottom, 4, ObjectAreaEndRow.Bottom, 5);
	Area.BottomBorder = BoundaryString;

EndProcedure

Function PresentationRunMode(RunMode)

	If RunMode = "Auto" Then
		PresentationRunMode = NStr("en = 'Auto';");

	ElsIf RunMode = "OrdinaryApplication" Then
		PresentationRunMode = NStr("en = 'Ordinary application';");

	ElsIf RunMode = "ManagedApplication" Then
		PresentationRunMode = NStr("en = 'Managed application';");
	Else
		PresentationRunMode = "";
	EndIf;

	Return PresentationRunMode;

EndFunction

Function LanguagePresentation(Language)

	LanguagePresentation = "";

	For Each LanguageMetadata In Metadata.Languages Do

		If LanguageMetadata.Name = Language Then
			LanguagePresentation = LanguageMetadata.Synonym;
			Break;
		EndIf;
	EndDo;

	Return LanguagePresentation;

EndFunction

Function MaxStringLength(MultilineString, InitialLength = 5)

	For LineNumber = 1 To StrLineCount(MultilineString) Do
		SubstringLength = StrLen(StrGetLine(MultilineString, LineNumber));
		If InitialLength < SubstringLength Then
			InitialLength = SubstringLength;
		EndIf;
	EndDo;

	Return InitialLength + 1;

EndFunction

Function ObjectsTypeRootItems(ObjectType)

	TableName = Metadata.FindByType(ObjectType).FullName();

	Query = New Query;
	Query.SetParameter("EmptyRef", Common.ObjectManagerByFullName(TableName).EmptyRef());

	Query.Text =
	"SELECT
	|	CurrentTable.Ref AS Ref
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.Parent = &EmptyRef";

	Query.Text = StrReplace(Query.Text, "&CurrentTable", TableName);
	Selection = Query.Execute().Select();

	RootItems = New Map;
	While Selection.Next() Do
		RootItems.Insert(Selection.Ref, True);
	EndDo;

	Return RootItems;

EndFunction

#EndRegion

#Else
	Raise NStr("en = 'Invalid object call on the client.';");
#EndIf