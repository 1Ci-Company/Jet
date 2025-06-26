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

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AttachAdditionalTables
	|ThisList AS ReportOptionsSettings
	|
	|LEFT JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|ON
	|	UserGroupCompositions.UsersGroup = ReportOptionsSettings.User
	|;
	|AllowReadUpdate
	|WHERE
	|	IsAuthorizedUser(User, UNDEFINED AS TRUE)
	|	OR IsAuthorizedUser(UserGroupCompositions.User)
	|	OR IsAuthorizedUser(Variant.Author)";
	
	Restriction.TextForExternalUsers1 = Restriction.Text;
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region Private

// Writes the settings table to the register data for the specified dimensions.
//
// Parameters:
//  SettingsTable - ValueTable
//  Dimensions - Structure:
//    * User - CatalogRef.Users
//                   - CatalogRef.ExternalUsers
//    * Variant - CatalogRef.ReportsOptions
//    * Subsystem - CatalogRef.MetadataObjectIDs
//                 - CatalogRef.ExtensionObjectIDs
//  Resources - Structure:
//    * Visible - Boolean
//    * QuickAccess - Boolean
//  DeleteOldItems - Boolean
//
Procedure WriteSettingsPackage(SettingsTable, Dimensions, Resources, DeleteOldItems) Export
	
	RecordSet = CreateRecordSet(); // InformationRegisterRecordSet.ReportOptionsSettings
	For Each KeyAndValue In Dimensions Do
		FilterElement = RecordSet.Filter[KeyAndValue.Key]; // FilterItem
		FilterElement.Set(KeyAndValue.Value, True);
		
		SettingsTable.Columns.Add(KeyAndValue.Key);
		SettingsTable.FillValues(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	
	For Each KeyAndValue In Resources Do
		SettingsTable.Columns.Add(KeyAndValue.Key);
		SettingsTable.FillValues(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	
	If Not DeleteOldItems Then
		RecordSet.Read();
		OldRecords = RecordSet.Unload();
		SearchByDimensions = New Structure("User, Subsystem, Variant");
		For Each OldRecord In OldRecords Do
			FillPropertyValues(SearchByDimensions, OldRecord);
			If SettingsTable.FindRows(SearchByDimensions).Count() = 0 Then
				FillPropertyValues(SettingsTable.Add(), OldRecord);
			EndIf;
		EndDo;
	EndIf;
	
	RecordSet.Load(SettingsTable);
	RecordSet.Write(True);
	
EndProcedure

// Clears settings by a report option.
Procedure ResetSettings(OptionRef = Undefined) Export
	
	RecordSet = CreateRecordSet();
	If OptionRef <> Undefined Then
		RecordSet.Filter.Variant.Set(OptionRef, True);
	EndIf;
	RecordSet.Write(True);
	
EndProcedure

// Clears settings of the specified (of the current) user in the section.
Procedure ResetUsesrSettingsInSection(SectionReference, User = Undefined) Export
	If User = Undefined Then
		User = Users.AuthorizedUser();
	EndIf;
	
	Query = New Query;
	Query.SetParameter("SectionReference", SectionReference);
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	MetadataObjectIDs.Ref
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|WHERE
	|	MetadataObjectIDs.Ref IN HIERARCHY(&SectionReference)";
	SubsystemsArray = Query.Execute().Unload().UnloadColumn("Ref");
	
	RecordSet = CreateRecordSet();
	RecordSet.Filter.User.Set(User, True);
	For Each SubsystemRef In SubsystemsArray Do
		RecordSet.Filter.Subsystem.Set(SubsystemRef, True);
		RecordSet.Write(True);
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of reading or writing settings of report option availability.

Procedure ReadReportOptionAvailabilitySettings(ReportVariant, OptionUsers,
	UseUserGroups = Undefined, UseExternalUsers = Undefined) Export 
	
	If Not AccessRight("Read", Metadata.Catalogs.Users) Then 
		Return;
	EndIf;
	
	OptionUsers.Clear();
	
	UseUserGroups = GetFunctionalOption("UseUserGroups");
	UseExternalUsers = GetFunctionalOption("UseExternalUsers");
	
#Region OptionUsersQuery
	
	// ACC:96-off When receiving the result of combining the second and third queries, non-unique records might be in the result.
	
	Query = New Query(
	"SELECT ALLOWED
	|	TRUE AS Check,
	|	Settings.User AS Value,
	|	PRESENTATION(Settings.User) AS Presentation,
	|	CASE
	|		WHEN VALUETYPE(Settings.User) = TYPE(Catalog.Users)
	|			THEN ""UserState02""
	|		WHEN VALUETYPE(Settings.User) = TYPE(Catalog.ExternalUsers)
	|			THEN ""UserState08""
	|		WHEN VALUETYPE(Settings.User) = TYPE(Catalog.ExternalUsersGroups)
	|			THEN ""UserState10""
	|		ELSE ""UserState04""
	|	END AS Picture,
	|	TRUE IN (
	|			SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|			WHERE
	|				UserGroupCompositions.User = &CurrentUser
	|				AND UserGroupCompositions.UsersGroup = Settings.User
	|				AND NOT UserGroupCompositions.UsersGroup IN (
	|					VALUE(Catalog.UserGroups.AllUsers),
	|					VALUE(Catalog.ExternalUsersGroups.AllExternalUsers))
	|		) AS IsCurrentUser
	|FROM
	|	InformationRegister.ReportOptionsSettings AS Settings
	|WHERE
	|	(&UseUserGroups
	|		OR &UseExternalUsers)
	|	AND Settings.Variant = &ReportVariant
	|	AND VALUETYPE(Settings.User) <> TYPE(Catalog.ExternalUsers)
	|	AND Settings.Subsystem = VALUE(Catalog.MetadataObjectIDs.EmptyRef)
	|	AND Settings.Visible
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN &ReportVariant IN (UNDEFINED, VALUE(Catalog.ReportsOptions.EmptyRef))
	|		THEN Users.Ref = &CurrentUser
	|		ELSE NOT Settings.Variant IS NULL
	|	END AS Check,
	|	Users.Ref AS Value,
	|	PRESENTATION(Users.Ref) AS Presentation,
	|	""UserState02"" AS Picture,
	|	Users.Ref = &CurrentUser AS IsCurrentUser
	|FROM
	|	Catalog.Users AS Users
	|	LEFT JOIN InformationRegister.ReportOptionsSettings AS Settings
	|		ON Settings.Variant = &ReportVariant
	|		AND Settings.User IN (Users.Ref, UNDEFINED)
	|		AND Settings.Subsystem = VALUE(Catalog.MetadataObjectIDs.EmptyRef)
	|		AND Settings.Visible
	|WHERE
	|	NOT &UseUserGroups
	|	AND NOT &UseExternalUsers
	|	AND NOT Users.DeletionMark
	|	AND NOT Users.Invalid
	|	AND NOT Users.IsInternal
	|
	|UNION
	|
	|SELECT
	|	TRUE AS Check,
	|	Users.Ref AS Value,
	|	PRESENTATION(Users.Ref) AS Presentation,
	|	""UserState02"" AS Picture,
	|	Users.Ref = &CurrentUser AS IsCurrentUser
	|FROM
	|	InformationRegister.ReportOptionsSettings AS Settings
	|	LEFT JOIN Catalog.UserGroups AS UserGroups
	|		ON UserGroups.Ref = Settings.User
	|	LEFT JOIN Catalog.UserGroups.Content AS UserGroupCompositions
	|		ON UserGroupCompositions.Ref = UserGroups.Ref
	|	LEFT JOIN Catalog.Users AS Users
	|		ON Users.Ref = UserGroupCompositions.User
	|WHERE
	|	NOT &UseUserGroups
	|	AND NOT &UseExternalUsers
	|	AND Settings.Variant = &ReportVariant
	|	AND Settings.Subsystem = VALUE(Catalog.MetadataObjectIDs.EmptyRef)
	|	AND Settings.Visible
	|	AND NOT UserGroups.DeletionMark
	|	AND NOT Users.DeletionMark
	|	AND NOT Users.Invalid
	|	AND NOT Users.IsInternal
	|	
	|UNION
	|
	|SELECT
	|	TRUE AS Check,
	|	&CurrentUser AS Value,
	|	PRESENTATION(&CurrentUser) AS Presentation,
	|	""UserState02"" AS Picture,
	|	TRUE AS IsCurrentUser
	|WHERE
	|	&ReportVariant IN (UNDEFINED, VALUE(Catalog.ReportsOptions.EmptyRef))");
	
	Query.SetParameter("ReportVariant", ReportVariant);
	Query.SetParameter("UseUserGroups", UseUserGroups);
	Query.SetParameter("UseExternalUsers", UseExternalUsers);
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	
	// ACC:96-on When receiving the result of combining the second and third queries, non-unique records might be in the result.
	
#EndRegion
	
	Selection = Query.Execute().Select();
	
	If Selection.FindNext(Undefined, "Value") Then 
		
		OptionUsers.Add(,, True, PictureLib.UserState04);
		Return;
		
	EndIf;
	
	Selection.Reset();
	
	While Selection.Next() Do 
		
		ListItem = OptionUsers.Add();
		FillPropertyValues(ListItem, Selection,, "Picture");
		ListItem.Picture = PictureLib[Selection.Picture];
		
		If Selection.IsCurrentUser Then 
			ListItem.Presentation = ListItem.Presentation + " [IsCurrentUser]";
		EndIf;
		
	EndDo;
	
	OptionUsers.SortByValue();
	
EndProcedure

Procedure WriteReportOptionAvailabilitySettings(ReportVariant, IsNewReportOption,
	OptionUsers = Undefined, NotifyUsers = False) Export 
	
	If OptionUsers = Undefined Then 
		OptionUsers = DefaultReportOptionUsers(ReportVariant);
	EndIf;
	
	If TypeOf(OptionUsers) <> Type("ValueList") Then
		Return;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		Block = New DataLock;
		
		If Not IsNewReportOption Then
			
			LockItem = Block.Add(Metadata.InformationRegisters.ReportOptionsSettings.FullName());
			LockItem.SetValue("Variant", ReportVariant);
			
		EndIf;
		
		Block.Lock();
		
		AddReportOptionUsers(
			ReportVariant,
			OptionUsers,
			NotifyUsers);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

Function NumberOfUsersReportOption(OptionUsers) Export 
	
	SetPrivilegedMode(True);
	
	SelectedUsers = New Array;
	
	AllUsersGroup = Users.AllUsersGroup();
	
	For Each OptionUser In OptionUsers Do 
		
		If Not OptionUser.Check Then 
			Continue;
		EndIf;
		
		SelectedUser = OptionUser.Value;
		
		If SelectedUser = Undefined Then 
			SelectedUser = AllUsersGroup;
		EndIf;
		
		SelectedUsers.Add(SelectedUser);
		
	EndDo;
	
	Query = New Query(
	"SELECT ALLOWED
	|	COUNT(DISTINCT Compositions.User) AS UsersCount
	|FROM
	|	InformationRegister.UserGroupCompositions AS Compositions
	|	LEFT JOIN Catalog.Users AS Users
	|		ON Users.Ref = Compositions.User
	|WHERE
	|	Compositions.UsersGroup IN (&SelectedUsers)
	|	AND Compositions.User <> &CurrentUser
	|	AND NOT VALUETYPE(Compositions.User) IN (
	|		TYPE(Catalog.ExternalUsers),
	|		TYPE(Catalog.ExternalUsersGroups))
	|	AND Compositions.Used
	|	AND NOT Users.IsInternal");
	
	Query.SetParameter("SelectedUsers", SelectedUsers);
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	
	Selection = Query.Execute().Select();
	
	Return ?(Selection.Next(), Selection.UsersCount, 0);
	
EndFunction

Function DefaultReportOptionUsers(ReportVariant)
	
	If ReportOptionAvailabilitySettingsConfigured(ReportVariant) Then 
		Return Undefined;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	UNDEFINED AS User
	|FROM
	|	Catalog.ReportsOptions AS Reports
	|	LEFT JOIN Catalog.ReportsOptions.Location AS ReportsPlacementrt
	|		ON ReportsPlacementrt.Ref = Reports.Ref
	|	LEFT JOIN Catalog.PredefinedReportsOptions AS ConfigurationReports
	|		ON ConfigurationReports.Ref = Reports.PredefinedOption
	|	LEFT JOIN Catalog.PredefinedReportsOptions.Location AS ConfigurationReportsPlacement
	|		ON ConfigurationReportsPlacement.Ref = Reports.PredefinedOption
	|	LEFT JOIN Catalog.PredefinedExtensionsReportsOptions AS ExtensionReports
	|		ON ExtensionReports.Ref = Reports.PredefinedOption
	|	LEFT JOIN Catalog.PredefinedExtensionsReportsOptions.Location AS ExtensionsReportsPlacement
	|		ON ExtensionsReportsPlacement.Ref = Reports.PredefinedOption
	|WHERE
	|	Reports.Ref = &ReportVariant
	|	AND ISNULL(ReportsPlacementrt.Use, TRUE) 
	|	AND NOT ISNULL(ReportsPlacementrt.Subsystem,
	|		ISNULL(ConfigurationReportsPlacement.Subsystem, ExtensionsReportsPlacement.Subsystem)) IS NULL
	|	AND ISNULL(ConfigurationReports.DefaultVisibility, ExtensionReports.DefaultVisibility) = TRUE");
	
	Query.SetParameter("ReportVariant", ReportVariant);
	
	If Query.Execute().IsEmpty() Then 
		Return Undefined;
	EndIf;
	
	OptionUsers = New ValueList;
	OptionUsers.ValueType = New TypeDescription(
		"CatalogRef.ExternalUsersGroups, CatalogRef.UserGroups, CatalogRef.Users");
	
	OptionUsers.Add(,, True);
	
	Return OptionUsers;
	
EndFunction

Function ReportOptionAvailabilitySettingsConfigured(ReportVariant)
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	TRUE
	|FROM
	|	InformationRegister.ReportOptionsSettings
	|WHERE
	|	Variant = &ReportVariant
	|	AND Subsystem = VALUE(Catalog.MetadataObjectIDs.EmptyRef)");
	
	Query.SetParameter("ReportVariant", ReportVariant);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Procedure AddReportOptionUsers(ReportVariant, OptionUsers, NotifyUsers)
	
	Records = InformationRegisters.ReportOptionsSettings.CreateRecordSet();
	Records.AdditionalProperties.Insert("NotifyUsers", NotifyUsers);
	
	Subsystem = Catalogs.MetadataObjectIDs.EmptyRef();
	
	EnableBusinessLogic = Not InfobaseUpdate.InfobaseUpdateInProgress();
	
	Records.Filter.Variant.Set(ReportVariant);
	Records.Filter.Subsystem.Set(Subsystem);
	
	CommonUserGroups = New Array;
	CommonUserGroups.Add(Users.AllUsersGroup());
	CommonUserGroups.Add(ExternalUsers.AllExternalUsersGroup());
	
	If OptionUsers.FindByValue(Undefined) <> Undefined
		Or OptionUsers.Count() = 1
			And CommonUserGroups.Find(OptionUsers[0].Value) <> Undefined Then 
		
		Record = Records.Add();
		Record.Variant = ReportVariant;
		Record.Subsystem = Subsystem;
		Record.Visible = True;
		
		InfobaseUpdate.WriteRecordSet(Records,,, EnableBusinessLogic);
		Return;
		
	EndIf;
	
	SelectedUsers = SelectedReportOptionUsers(OptionUsers);
	
	For Each User In SelectedUsers Do 
		
		Record = Records.Add();
		Record.Variant = ReportVariant;
		Record.User = User;
		Record.Subsystem = Subsystem;
		Record.Visible = True;
		
	EndDo;
	
	InfobaseUpdate.WriteRecordSet(Records,,, EnableBusinessLogic);
	
EndProcedure

Function SelectedReportOptionUsers(OptionUsers)
	
	UseUserGroups = GetFunctionalOption("UseUserGroups");
	UseExternalUsers = GetFunctionalOption("UseExternalUsers");
	
	If UseUserGroups
		Or UseExternalUsers Then 
		
		Return OptionUsers.UnloadValues();
		
	EndIf;
	
	SelectedUsers = New Array;
	
	For Each ListItem In OptionUsers Do 
		
		If ListItem.Check Then 
			SelectedUsers.Add(ListItem.Value);
		EndIf;
		
	EndDo;
	
	Return SelectedUsers;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of a report option user notification.

// Creates a message in the report option context that notifies users
//  having rights to the current report option.
//
// Parameters:
//  Records - InformationRegisterRecordSet.ReportOptionsSettings
//
Procedure NotifyReportOptionUsers(Records) Export 
	
	If Not Common.SubsystemExists("StandardSubsystems.Conversations") Then
		Return;
	EndIf;
	
	NotifyUsers = CommonClientServer.StructureProperty(
		Records.AdditionalProperties, "NotifyUsers", False);
	
	If Not NotifyUsers Then 
		Return;
	EndIf;
	
	ModuleConversations = Common.CommonModule("Conversations");
	
	SetPrivilegedMode(True);
	Recipients = New Array;
	
	FilterElement = Records.Filter.Find("Variant");
	OptionUsers = ReportOptionUsers(FilterElement.Value);
	
	While OptionUsers.Next() Do 
		Recipients.Add(OptionUsers.Ref);
	EndDo;
	
	If Recipients.Count() = 0 Then 
		Return;
	EndIf;
	
	
	ReportVariant = Records[0].Variant;
	Text = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Report %1 is configured';"),
		GetURL(ReportVariant));
	
	Message = ModuleConversations.MessageDetails(Text);
	Try
		ModuleConversations.SendMessage(Users.CurrentUser(), Recipients,
			Message, ReportVariant);
	Except
		
		DefaultLanguageCode = Common.DefaultLanguageCode();
		ReportOptionPresentation = String(ReportVariant);
		WriteLogEvent(
			NStr("en = 'Report options';", DefaultLanguageCode),
			EventLogLevel.Error,,
			ReportOptionPresentation,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		
	EndTry;
	
EndProcedure

Function ReportOptionUsers(ReportVariant, SelectedUsers = Undefined) Export 
	
	Query = New Query(
	"SELECT ALLOWED DISTINCT
	|	Compositions.User AS Ref,
	|	Users.IBUserID AS Id
	|FROM
	|	InformationRegister.ReportOptionsSettings AS Settings
	|	LEFT JOIN InformationRegister.UserGroupCompositions AS Compositions
	|		ON Compositions.UsersGroup = Settings.User
	|		OR Settings.User = UNDEFINED
	|			AND Compositions.UsersGroup = VALUE(Catalog.UserGroups.AllUsers)
	|	LEFT JOIN Catalog.Users AS Users
	|		ON Users.Ref = Compositions.User
	|WHERE
	|	Settings.Variant = &ReportVariant
	|	AND Settings.Subsystem = VALUE(Catalog.MetadataObjectIDs.EmptyRef)
	|	AND NOT VALUETYPE(Settings.User) IN (
	|		TYPE(Catalog.ExternalUsers),
	|		TYPE(Catalog.ExternalUsersGroups))
	|	AND Settings.Visible
	|	AND Compositions.Used
	|	AND Users.Ref <> &CurrentUser
	|	AND (NOT &UsersSelected
	|		OR Users.Ref IN (&SelectedUsers))
	|	AND NOT Users.IsInternal");
	
	Query.SetParameter("ReportVariant", ReportVariant);
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("UsersSelected", SelectedUsers <> Undefined);
	Query.SetParameter("SelectedUsers", SelectedUsers);
	
	Return Query.Execute().Select();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Update handlers.

// This procedure registers data to be updated in the InfobaseUpdate exchange plan.
//  See "Parallel mode of deferred update" in the application development standards.
//
// Parameters:
//  Parameters - See InfobaseUpdate.MainProcessingMarkParameters
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export 
	
	Query = New Query(
	"SELECT ALLOWED DISTINCT
	|	Reports.Ref AS Variant,
	|	VALUE(Catalog.MetadataObjectIDs.EmptyRef) AS Subsystem,
	|	UNDEFINED AS User,
	|	CASE
	|		WHEN Reports.DefaultVisibilityOverridden
	|			OR ISNULL(ConfigurationReports.DefaultVisibility, ExtensionReports.DefaultVisibility) IS NULL
	|		THEN Reports.DefaultVisibility
	|		ELSE ISNULL(ConfigurationReports.DefaultVisibility, ExtensionReports.DefaultVisibility)
	|	END AS Visible,
	|	FALSE AS QuickAccess
	|INTO Settings
	|FROM
	|	Catalog.ReportsOptions AS Reports
	|	LEFT JOIN Catalog.ReportsOptions.Location AS ReportsPlacementrt
	|		ON ReportsPlacementrt.Ref = Reports.Ref
	|	LEFT JOIN Catalog.PredefinedReportsOptions AS ConfigurationReports
	|		ON ConfigurationReports.Ref = Reports.PredefinedOption
	|	LEFT JOIN Catalog.PredefinedReportsOptions.Location AS ConfigurationReportsPlacement
	|		ON ConfigurationReportsPlacement.Ref = Reports.PredefinedOption
	|	LEFT JOIN Catalog.PredefinedExtensionsReportsOptions AS ExtensionReports
	|		ON ExtensionReports.Ref = Reports.PredefinedOption
	|	LEFT JOIN Catalog.PredefinedExtensionsReportsOptions.Location AS ExtensionsReportsPlacement
	|		ON ExtensionsReportsPlacement.Ref = Reports.PredefinedOption
	|WHERE
	|	ISNULL(ReportsPlacementrt.Use, TRUE) 
	|	AND NOT ISNULL(ReportsPlacementrt.Subsystem,
	|		ISNULL(ConfigurationReportsPlacement.Subsystem, ExtensionsReportsPlacement.Subsystem)) IS NULL
	|;
	|
	|SELECT
	|	Settings.Variant,
	|	Settings.Subsystem,
	|	Settings.User,
	|	Settings.Visible,
	|	Settings.QuickAccess
	|FROM
	|	Settings AS Settings
	|	LEFT JOIN InformationRegister.ReportOptionsSettings AS ExistingSettings
	|		ON ExistingSettings.Variant = Settings.Variant
	|		AND ExistingSettings.Subsystem = Settings.Subsystem
	|WHERE
	|	Settings.Visible
	|	AND ExistingSettings.Variant IS NULL");
	
	References = Query.Execute().Unload().UnloadColumn("Variant");
	
	InfobaseUpdate.MarkForProcessing(Parameters, References);
	
EndProcedure

// This procedure processes data registered in the InfobaseUpdate exchange plan.
//  See "Parallel mode of deferred update" in the application development standards.
//
// Parameters:
//  Parameters - See InfobaseUpdate.MainProcessingMarkParameters
//
Procedure ProcessDataForMigrationToNewVersion(Parameters) Export 
	
	Variant = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.ReportsOptions");
	
	Data = New Structure("Variant, User, Subsystem, Visible, QuickAccess");
	Data.Subsystem = Catalogs.MetadataObjectIDs.EmptyRef();
	Data.Visible = True;
	Data.QuickAccess = False;
	
	RegisterMetadata = Metadata.InformationRegisters.ReportOptionsSettings;
	RegisterPresentation = RegisterMetadata.Presentation();
	
	Processed = 0;
	Declined = 0;
	
	While Variant.Next() Do
		
		Data.Variant = Variant.Ref;
		RepresentationOfTheReference = String(Variant.Ref);
		Try
			
			MoveReportOptionAvailabilitySettings(Data);
			Processed = Processed + 1;
			
		Except
			
			Declined = Declined + 1;
			
			CommentTemplate = NStr("en = 'Cannot move the availability settings of the ""%1"" report option to the ""%2"" register.
				|Reason: %3';");
				
			Comment = StringFunctionsClientServer.SubstituteParametersToString(
				CommentTemplate,
				RepresentationOfTheReference,
				RegisterPresentation,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
			InfobaseUpdate.WriteErrorToEventLog(
				RegisterMetadata,
				RegisterPresentation,
				Comment);
			
		EndTry;
		
	EndDo;

	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(
		Parameters.Queue, Metadata.Catalogs.ReportsOptions.FullName());
	
	If Processed = 0 And Declined <> 0 Then
		MessageTemplate = NStr("en = 'Couldn''t process (skipped) some report option settings: %1';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, Declined);
		Raise MessageText;
	Else
		CommentTemplate = NStr("en = 'Yet another batch of report option settings is processed: %1';");
		Comment = StringFunctionsClientServer.SubstituteParametersToString(CommentTemplate, Processed);
		WriteLogEvent(
			InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Information,
			RegisterMetadata,,
			Comment);
	EndIf;
	
EndProcedure

Procedure MoveReportOptionAvailabilitySettings(Data)
	
	BeginTransaction();
	
	Try
		
		Block = New DataLock;
		
		LockItem = Block.Add("Catalog.ReportsOptions");
		LockItem.SetValue("Ref", Data.Variant);
		
		LockItem = Block.Add("InformationRegister.ReportOptionsSettings");
		LockItem.SetValue("Variant", Data.Variant);
		
		Block.Lock();
		
		Records = CreateRecordSet();
		Records.Filter.Variant.Set(Data.Variant);
		Records.Filter.User.Set(Data.User);
		Records.Filter.Subsystem.Set(Data.Subsystem);
		
		Record = Records.Add();
		FillPropertyValues(Record, Data);
		
		InfobaseUpdate.WriteRecordSet(Records);
		InfobaseUpdate.MarkProcessingCompletion(Data.Variant);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion

#EndIf