///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// The call of this procedure should be placed in session module in the SessionParametersSetting
// procedure according to the documentation.
//
// Parameters:
//  SessionParametersNames - Array of String
//                        - Undefined - the session parameter names for initialization.
//                                         An array of the set IDs of session parameters
//                                         that should be initialized if the handler is called
//                                         before using uninitialized session parameters.
//                                         Undefined if event handler is called by the system on session start.
//
// Returns:
//  Array of String - session parameters names whose values were successfully set.
//
Function SessionParametersSetting(SessionParametersNames) Export
	
	// Session parameters that access the same data for initialization should be initialized as a batch.
	// To avoid re-initialization, the names of the initialized session parameters
	// are saved to the array "InitializedParameters".
	SpecifiedParameters = New Array;
	
#If Not MobileStandaloneServer Then
	
	If SessionParametersNames <> Undefined
	   And SessionParametersNames.Find("ClientParametersAtServer") <> Undefined Then
		
		SessionParameters.ClientParametersAtServer = New FixedMap(New Map);
		SpecifiedParameters.Add("ClientParametersAtServer");
		If SessionParametersNames.Count() = 1 Then
			Return SpecifiedParameters;
		EndIf;
	EndIf;
	
	If SessionParametersNames = Undefined Then
		If SessionParameters.ClientParametersAtServer.Count() = 0 Then
			BlankTheClientSettings = New Map;
			BlankTheClientSettings.Insert("TheFirstServerCallIsMade",
				?(CurrentRunMode() = Undefined, Undefined, False));
			BlankTheClientSettings.Insert("StateBeforeCallAuthenticateCurrentUser", True);
			SessionParameters.ClientParametersAtServer = New FixedMap(BlankTheClientSettings);
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
			ModuleNationalLanguageSupportServer.SessionParametersSetting(SessionParametersNames, SpecifiedParameters);
		EndIf;
		
		Catalogs.ExtensionsVersions.SessionParametersSetting(SessionParametersNames, SpecifiedParameters);
		
		// When establishing the connections with the infobase before calling all other handlers.
		BeforeStartApplication();
		Return SpecifiedParameters;
	EndIf;
	
	Catalogs.MetadataObjectIDs.SessionParametersSetting(SessionParametersNames, SpecifiedParameters);
	
	If SessionParametersNames.Find("CachedDataKey") <> Undefined Then
		SessionParameters.CachedDataKey = New UUID;
		SpecifiedParameters.Add("CachedDataKey");
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.SessionParametersSetting(SessionParametersNames, SpecifiedParameters);
	EndIf;
	
	Catalogs.ExtensionsVersions.SessionParametersSetting(SessionParametersNames, SpecifiedParameters);
	
	If SessionParametersNames.Find("Clipboard") <> Undefined Then
		SessionParameters.Clipboard = New FixedStructure(New Structure("Source, Data"));
		SpecifiedParameters.Add("Clipboard");
	EndIf;
	
	If AllSessionParametersAreSet(SessionParametersNames, SpecifiedParameters) Then
		Return SpecifiedParameters;
	EndIf;
	
	Handlers = New Map;
	SSLSubsystemsIntegration.OnAddSessionParameterSettingHandlers(Handlers);
	
	CustomHandlers = New Map;
	CommonOverridable.OnAddSessionParameterSettingHandlers(CustomHandlers);
	For Each Record In CustomHandlers Do
		Handlers.Insert(Record.Key, Record.Value);
	EndDo;
	
	ExecuteSessionParameterSettingHandlers(SessionParametersNames, Handlers, SpecifiedParameters);
	
	SSLSubsystemsIntegration.OnSetSessionParameters(SessionParametersNames);
	
#EndIf
	
	Return SpecifiedParameters;
	
EndFunction

#If Not MobileStandaloneServer Then

// Returns a flag that shows whether this is the basic configuration.
// The basic configuration versions may have application restrictions that
// can be enforced using this function.
// The configuration is considered basic if its name contains the term "Basic",
// for example, "TradeManagementBasic".
//
// Returns:
//   Boolean - True if this is the basic configuration.
//
Function IsBaseConfigurationVersion() Export
	
	IsBaseConfigurationVersion = StrFind(Upper(Metadata.Name), NStr("en = 'BASE';")) > 0;
	CommonOverridable.WhenDefiningAFeatureThisIsTheBasicVersionOfTheConfiguration(IsBaseConfigurationVersion);
	
	Return IsBaseConfigurationVersion;
	
EndFunction

// Returns the flag indicating whether this is the training version of 1C:Enterprise.
// Intended for the functions and procedures whose functionality
// is affected by the training version limitations.
//
// Returns:
//   Boolean - True if the code is executed on the training version of 1C:Enterprise.
//
Function IsTrainingPlatform() Export
	
	SetPrivilegedMode(True);
	CurrentUser = InfoBaseUsers.CurrentUser();

	Try
		OSUser = CurrentUser.OSUser;
	Except
		// The training version of 1C:Enterprise does not support obtaining the properties of OSUser.
		Return True;
	EndTry;
	Return False;
	
EndFunction

// Updates metadata property caches, which speed up
// session startup and infobase update, especially in the SaaS mode.
// They are updated before the infobase update.
//
// To be used in other libraries and configurations.
//
Procedure UpdateAllApplicationParameters() Export
	
	InformationRegisters.ApplicationRuntimeParameters.UpdateAllApplicationParameters();
	
EndProcedure

// Returns the Standard Subsystems Library version number (SSL)
// built in the configuration.
//
// Returns:
//  String - an SSL version, for example, "1.0.1.1".
//
Function LibraryVersion() Export
	
	Return StandardSubsystemsCached.SubsystemsDetails().ByNames["StandardSubsystems"].Version;
	
EndFunction

// Gets an infobase UUID
// that allows you to distinguish different instances of infobases,
// for example, when collecting statistics or in the mechanisms of the external management of databases.
// If the ID is not filled in, its value is set and returned automatically.
//
// The ID is stored in the InfobaseID constant.
// The InfobaseID constant cannot be included in the exchange plan contents in order to have
// the same value in each infobase (in DIB node).
//
// Returns:
//  String - infobase ID.
//
Function InfoBaseID() Export
	
	InfoBaseID = Constants.InfoBaseID.Get();
	
	If IsBlankString(InfoBaseID) Then
		InfoBaseID = String(New UUID());
		
		SetSafeModeDisabled(True);
		SetPrivilegedMode(True);
		
		Constants.InfoBaseID.Set(InfoBaseID);
		
		SetPrivilegedMode(False);
		SetSafeModeDisabled(False);
	EndIf;
	
	Return InfoBaseID;
	
EndFunction

// Returns the administration parameter saved in the infobase.
// Designed for using in the mechanisms that require
// the input of infobase and server cluster administration parameters.
// For example, infobase connection lock.
// See also: SetAdministrationParameters.
//
// Returns:
//  Structure - contains the properties of two structures
//              ClusterAdministrationClientServer.ClusterAdministrationParameters 
//              and ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//              In this case, fields containing passwords are returned empty. If administration parameters
//              were not saved using the SetAdministrationParameters function,
//              the automatically calculated administration parameters will be returned by default.
//
Function AdministrationParameters() Export
	
	If Common.DataSeparationEnabled()
	   And Common.SeparatedDataUsageAvailable() Then
		
		If Not Users.IsFullUser() Then
			Raise(NStr("en = 'Insufficient rights to perform the operation.';"), ErrorCategory.AccessViolation);
		EndIf;
	Else
		If Not Users.IsFullUser(, True) Then
			Raise(NStr("en = 'Insufficient rights to perform the operation.';"), ErrorCategory.AccessViolation);
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	IBAdministrationParameters = Constants.IBAdministrationParameters.Get().Get();
	DefaultAdministrationParameters = DefaultAdministrationParameters();
	
	If TypeOf(IBAdministrationParameters) = Type("Structure") Then
		FillPropertyValues(DefaultAdministrationParameters, IBAdministrationParameters);
	EndIf;
	IBAdministrationParameters = DefaultAdministrationParameters;
	
	If Not Common.FileInfobase() Then
		ReadParametersFromConnectionString(IBAdministrationParameters);
	EndIf;
	
	Return IBAdministrationParameters;
	
EndFunction

// Saves the infobase and server cluster administration parameters.
// When saving, the fields that contain passwords will be cleared for security reasons.
//
// Parameters:
//  IBAdministrationParameters - See AdministrationParameters
//
// Example:
//  AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
//  // Showing the administration parameters to the administrator to validate them and enter passwords.
//  // Next, executing actions related to connecting to the server cluster.
//  StandardSubsystemsServer.AdministrationParameters(AdministrationParameters);
//
Procedure SetAdministrationParameters(IBAdministrationParameters) Export
	
	UsersInternal.CheckSafeModeIsDisabled(
		"StandardSubsystemsServer.SetAdministrationParameters");
	
	IBAdministrationParameters.ClusterAdministratorPassword = "";
	IBAdministrationParameters.InfobaseAdministratorPassword = "";
	Constants.IBAdministrationParameters.Set(New ValueStorage(IBAdministrationParameters));
	
EndProcedure

// Sets presentation of the Date field in the lists containing attribute with the Date and time date content.
// For more information, see the "The "Date" field in the lists" standard.
//
// Parameters:
//   Form - ClientApplicationForm - a form with a list.
//   FullAttributeName - String - a full path to the attribute of the Date type in the format: "<ListName>.<FieldName>".
//   TagName - String - a name of the form item associated with a list attribute of the Date type.
//
// Example:
//
//	Procedure OnCreateAtServer(Cancel, StandardProcessing)
//		StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject);
//
Procedure SetDateFieldConditionalAppearance(Form, 
	FullAttributeName = "List.Date", TagName = "Date") Export
	
	CommonClientServer.CheckParameter(
		"StandardSubsystemsServer.SetDateFieldConditionalAppearance",
		"ThisObject", 
		Form, 
		Type("ClientApplicationForm"));
	
	FullNameParts1 = StrSplit(FullAttributeName, ".");
	
	If FullNameParts1.Count() <> 2 Then 
		// Invalid name of "FullAttributeName" parameter.
		// Valid attribute name format is ""<ListName>.<FieldName>""'");
		Return;
	EndIf;
	
	ListName = FullNameParts1[0];
	AttributeList = Form[ListName];
	
	If TypeOf(AttributeList) = Type("DynamicList") Then 
		// "DynamicList" allows the setting of a conditional appearance using the built-in composer.
		// The "TagName" parameter is ignored as the dynamic list 
		// composer cannot know how the list attributes will be displayed. 
		// Therefore, the attribute path, filter value, and appearance value are the attribute name.
		ConditionalAppearance = AttributeList.ConditionalAppearance;
		AttributePath1 = FullNameParts1[1];
		FormattedFieldName = AttributePath1;
	Else 
		// The other lists (for example, "FormDataTree") don't have built-in composers.
		// Instead, they use the form's composer.
		ConditionalAppearance = Form.ConditionalAppearance;
		AttributePath1 = FullAttributeName;
		FormattedFieldName = TagName;
	EndIf;
	
	If Not ValueIsFilled(ConditionalAppearance.UserSettingID) Then
		ConditionalAppearance.UserSettingID = "MainAppearance";
	EndIf;
	
	// Date presentation.
	AppearanceItem = ConditionalAppearance.Items.Add();
	AppearanceItem.Use = True;
	AppearanceItem.Appearance.SetParameterValue("Format", "DLF=D");
	
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(FormattedFieldName);
	
	// Today presentation of today.
	AppearanceItem = ConditionalAppearance.Items.Add();
	AppearanceItem.Use = True;
	AppearanceItem.Appearance.SetParameterValue("Format", NStr("en = 'DF=HH:mm';"));
	
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(FormattedFieldName);
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue  = New DataCompositionField(AttributePath1);
	FilterElement.ComparisonType   = DataCompositionComparisonType.GreaterOrEqual;
	FilterElement.RightValue = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisDay);
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue  = New DataCompositionField(AttributePath1);
	FilterElement.ComparisonType   = DataCompositionComparisonType.Less;
	FilterElement.RightValue = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfNextDay);
	
EndProcedure

// Gets the setting to display a confirmation on application exit
// for the current user. Designed for using in the form of personal user
// settings.
// 
// Returns:
//   Boolean - if True, show the session closing confirmation
//            window upon application exit to the user.
// 
Function AskConfirmationOnExit() Export
	
	Result = Common.CommonSettingsStorageLoad(
		"UserCommonSettings", 
		"AskConfirmationOnExit");
	
	If Result = Undefined Then
		Result = Common.CommonCoreParameters().AskConfirmationOnExit;
	EndIf;
	
	Return Result;
	
EndFunction

// Returns details of tabular document saving formats.
//
// Returns:
//  ValueTable:
//   * SpreadsheetDocumentFileType - SpreadsheetDocumentFileType - a value that corresponds to the format;
//   * Ref - EnumRef.ReportSaveFormats      - a reference to metadata, where the presentation is stored;
//   * Presentation - String - a file type presentation (filled in from enumeration);
//   * Extension    - String - a file type for the operating system;
//   * Picture      - Picture - a picture of the format.
//
Function SpreadsheetDocumentSaveFormatsSettings() Export
	
	FormatsTable = New ValueTable;
	
	FormatsTable.Columns.Add("SpreadsheetDocumentFileType", New TypeDescription("SpreadsheetDocumentFileType"));
	FormatsTable.Columns.Add("Ref", New TypeDescription("EnumRef.ReportSaveFormats"));
	FormatsTable.Columns.Add("Presentation", New TypeDescription("String"));
	FormatsTable.Columns.Add("Extension", New TypeDescription("String"));
	FormatsTable.Columns.Add("Picture", New TypeDescription("Picture"));

	// PDF document (.pdf)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = TableDocumentFileTypePDF();
	NewFormat.Ref = Enums.ReportSaveFormats.PDF;
	NewFormat.Extension = "pdf";
	NewFormat.Picture = PictureLib.PDFFormat;
	NewFormat.Presentation = FileTypeRepresentationOfATabularPDFDocument();
	
	StandardSubsystemsServerLocalization.OnSetupSpreadsheetSaveFormats(FormatsTable);
	
	// Spreadsheet document (.mxl)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.MXL;
	NewFormat.Ref = Enums.ReportSaveFormats.MXL;
	NewFormat.Extension = "mxl";
	NewFormat.Picture = PictureLib.MXLFormat;
	
	// Microsoft Excel 2007 worksheet (.xlsx)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.XLSX;
	NewFormat.Ref = Enums.ReportSaveFormats.XLSX;
	NewFormat.Extension = "xlsx";
	NewFormat.Picture = PictureLib.ExcelFormat2007;

	// Microsoft Excel 97-2003 worksheet (.xls)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.XLS;
	NewFormat.Ref = Enums.ReportSaveFormats.XLS;
	NewFormat.Extension = "xls";
	NewFormat.Picture = PictureLib.ExcelFormat;

	// OpenDocument spreadsheet (.ods).
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.ODS;
	NewFormat.Ref = Enums.ReportSaveFormats.ODS;
	NewFormat.Extension = "ods";
	NewFormat.Picture = PictureLib.OpenOfficeCalcFormat;
	
	// Word 2007 document (.docx)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.DOCX;
	NewFormat.Ref = Enums.ReportSaveFormats.DOCX;
	NewFormat.Extension = "docx";
	NewFormat.Picture = PictureLib.WordFormat2007;
	
	// Web page (.html).
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.HTML5;
	NewFormat.Ref = Enums.ReportSaveFormats.HTML;
	NewFormat.Extension = "html";
	NewFormat.Picture = PictureLib.HTMLFormat;
	
	// Text document, UTF-8 (.txt).
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.TXT;
	NewFormat.Ref = Enums.ReportSaveFormats.TXT;
	NewFormat.Extension = "txt";
	NewFormat.Picture = PictureLib.TXTFormat;
	
	// Text document, ANSI (.txt).
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.ANSITXT;
	NewFormat.Ref = Enums.ReportSaveFormats.ANSITXT;
	NewFormat.Extension = "txt";
	NewFormat.Picture = PictureLib.TXTFormat;
	
	For Each SaveFormat In FormatsTable Do
		If Not ValueIsFilled(SaveFormat.Presentation) Then
			SaveFormat.Presentation = String(SaveFormat.Ref);
		EndIf;
	EndDo;
		
	Return FormatsTable;
	
EndFunction

// Returns the compatibility mode version as the numbering of revisions and versions. For example: 8.3.15.0.
//
// Returns:
//   String - the compatibility mode version as the numbering of revisions and versions.
//
Function CompatibilityModeVersion() Export 
	
	If Metadata.CompatibilityMode = Metadata.ObjectProperties.CompatibilityMode.DontUse Then 
		
		Information = New SystemInfo;
		Return Information.AppVersion;
		
	EndIf;
	
	CompatibilityModeDescription = StrSplit(Metadata.CompatibilityMode, "_");
	Symbols = StrLen(CompatibilityModeDescription[0]);
	
	EditionNumber = "";
	
	For CharacterNumber = 1 To Symbols Do 
		
		CurrentChar = Mid(CompatibilityModeDescription[0], CharacterNumber, 1);
		
		If StrFind("0123456789", CurrentChar) > 0 Then 
			EditionNumber = EditionNumber + CurrentChar;
		EndIf;
		
	EndDo;
	
	CompatibilityModeDescription.Set(0, EditionNumber);
	
	For IndexOf = CompatibilityModeDescription.Count() To 3 Do 
		CompatibilityModeDescription.Add("0");
	EndDo;
	
	Return StrConcat(CompatibilityModeDescription, ".");
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Web client does not support configurations that use interface v.8.2 anymore.
// When working in the web client, the ability to switch 
// between the interface of version 8.2 and the Taxi interface is disabled.
//
// Sets the bold font for form group titles so they are correctly displayed in the 8.2 interface.2.
// In the Taxi interface, group titles with standard highlight and without one are displayed in large font.
// In the 8.2 interface such titles are displayed as regular labels and are not associated with titles.
// This function is designed for visually highlighting (in bold) group titles in the interface v.8.2 mode.
//
// Parameters:
//  Form - ClientApplicationForm - a form where group title fonts are changed;
//  GroupNames - String - a list of the form group names separated with commas. If the group names are not specified,
//                        the appearance will be applied to all groups on the form.
//
// Example:
//  Procedure OnCreateAtServer(Cancel, StandardProcessing)
//    StandardSubsystemsServer.SetGroupsTitlesRepresentation(ThisObject);
//
Procedure SetGroupTitleRepresentation(Form, GroupNames = "") Export
	
	// Nothing is running.
	
EndProcedure

#EndRegion

// Returns the flag indicating whether toast notifications about installed
// application updates (dynamic update of the application, patches, and extensions) are shown.
//
// Returns:
//  Boolean - if True, toast notifications are enabled.
//
Function ShowInstalledApplicationUpdatesWarning() Export
	
	Return ShowWarningAboutInstalledUpdatesForUser();
	
EndFunction

#Region ForCallsFromOtherSubsystems

// Called from a scheduled job in order to send a server notification to client sessions.
// See also: StandardSubsystemsClient.OnReceiptServerNotification.
//
// It is called in the privileged mode considering the given period of the notification.
// See CommonOverridable.OnAddServerNotifications.
//
// Parameters:
//  NameOfAlert - String - See ServerNotifications.NewServerNotification.Name
//  ParametersVariants - Array of Structure:
//   * Parameters - Arbitrary - See ServerNotifications.NewServerNotification.Parameters
//   * SMSMessageRecipients - Map of KeyAndValue:
//      ** Key - UUID - Infobase user ID
//      ** Value - Array of See ServerNotifications.SessionKey
//
// Example:
//	If NotificationName <> "StandardSubsystems.UsersSessions.SessionsLock" Then
//		Return;
//	EndIf;
//	SessionLockParameters = SessionLockParameters(True);
//	If SessionLockParameters.Use Then
//		ServerNotifications.SendServerNotification(NotificationName,
//			SessionLockParameters, Undefined);
//	EndIf;
//
Procedure OnSendServerNotification(NameOfAlert, ParametersVariants) Export
	
	If NameOfAlert = "StandardSubsystems.Core.FunctionalOptionsModified" Then
		OnSendServerNotificationFunctionalOptionsModified(NameOfAlert, ParametersVariants);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf

#EndRegion

#If Not MobileStandaloneServer Then

#Region Internal

// Notifies all sessions that the cached values are outdated.
// 
// Parameters:
//  SendImmediately - See ServerNotifications.SendServerNotification.SendImmediately
//
Procedure NotifyAllSessionsAboutOutdatedCache(SendImmediately = False) Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	ServerNotifications.SendServerNotification(
		"StandardSubsystems.Core.CachedValuesOutdated",
		"",
		Undefined,
		SendImmediately);
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional base functionality for analyzing client parameters on the server.

// Parameters:
//  RaiseException1 - Boolean - Call an exception if the parameters are not initialized.
//
// Returns a fixed map if CurrentRunMode() is "Undefined".
//
// Returns:
//  FixedMap of KeyAndValue:
//   * Key - String - LaunchParameter, InfobaseConnectionString
//   * Value - String
//
Function ClientParametersAtServer(RaiseException1 = True) Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	ClientParameters = SessionParameters.ClientParametersAtServer;
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	If Not RaiseException1
	 Or CurrentRunMode() = Undefined
	   And ClientParameters.Get("TheFirstServerCallIsMade") = Undefined
	 Or ClientParameters.Get("TheFirstServerCallIsMade") = True Then
		
		Return ClientParameters;
	EndIf;
	
	If CurrentRunMode() <> Undefined Then
		// Reset the client caches used when accessing the client operating parameters
		// to repopulate the client parameters on the server side.
		RefreshReusableValues();
	EndIf;
	
	OnStart = ClientParameters.Get("TheFirstServerCallIsMade") = False;
	
	If OnStart Then
		CommentForTheLogWithoutACallStack = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid access to uninitialized client parameters on the server.
			           |The call might have been executed before initialization was completed in %1.';",
			     Common.DefaultLanguageCode()),
			     "StandardSubsystemsClient.BeforeStart");
	Else
		CommentForTheLogWithoutACallStack = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid access to uninitialized client parameters on the server.
			           |The call might have been executed after session parameters were cleared incorrectly without using %2.';",
			     Common.DefaultLanguageCode()),
			     "Common.ClearSessionParameters");
	EndIf;
	
	Try
		Raise CommentForTheLogWithoutACallStack;
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
	CommentWithCallStack = ErrorProcessing.DetailErrorDescription(ErrorInfo);
	
	EventName = NStr("en = 'The client parameters on the server are blank';",
		Common.DefaultLanguageCode());
	
	WriteLogEvent(EventName, EventLogLevel.Error,,, CommentWithCallStack);
	
	If Not OnStart Then
		ErrorText =
			NStr("en = 'Client parameters on the server are not initialized.
			           |To initialize them, retry the action or restart the session.';");
		Raise ErrorText;
	EndIf;
	
	Return ClientParameters;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedure for setting, upgrading, or retrieving application parameters (caches).

// Checks whether the latest version of the application is available
// in the current session, otherwise raises an exception with the requirement to restart the session.
//
// You cannot update the parameters of the application operation in previous sessions and also
// cannot change some data, so as not to overwrite
// the new version of the data (received using the new version of the application)
// with the previous version of the data (received using the previous version of the application).
//
Procedure CheckApplicationVersionDynamicUpdate() Export
	
	If ApplicationVersionUpdatedDynamically() Then
		RequireRestartDueToApplicationVersionDynamicUpdate();
	EndIf;
	
EndProcedure

// Checks whether there is the dynamic change of base configuration in the current session and
// there is no infobase update mode.
//
// Returns:
//  Boolean - True if the application version is updated.
//
Function ApplicationVersionUpdatedDynamically() Export
	
	If Not DataBaseConfigurationChangedDynamically() Then
		Return False;
	EndIf;
	
	// If the database configuration is changed dynamically while an
	// infobase update is running, keep updating despite the change.
	// 
	
	If Common.DataSeparationEnabled() Then
		// App operation parameters are always shared.
		// Therefore, they are updated if all shared data is updated.
		Return Not InfobaseUpdateInternal.SharedInfobaseDataUpdateRequired();
	EndIf;
	
	Return Not InfobaseUpdate.InfobaseUpdateRequired();
	
EndFunction

// Raises an exception with a recommendation to restart a session due to an update of the application version.
Procedure RequireRestartDueToApplicationVersionDynamicUpdate() Export
	
	ErrorText = NStr("en = 'The app is updated. Restart the app.';");
	InstallRequiresSessionRestart(ErrorText);
	Raise ErrorText;
	
EndProcedure

// Raises an exception with a recommendation to restart a session due to an update of the application extension.
Procedure RequireSessionRestartDueToDynamicUpdateOfProgramExtensions() Export
	
	If StandardSubsystemsCached.IsSeparatedModeWithoutDataAreaExtensions() Then
		ErrorText =
			NStr("en = 'To perform the required actions,
			           |start a session with the specified separators.
			           |
			           |Data area extensions are not applied when you log in to a data area in a session
			           |that is started without separators.';");
	Else
		ErrorText = NStr("en = 'Extensions are updated. Restart the app.';");
	EndIf;
	
	InstallRequiresSessionRestart(ErrorText);
	Raise ErrorText;
	
EndProcedure

// Returns:
//  Boolean
//
Function ThisIsSplitSessionModeWithNoDelimiters() Export
	
	If Not Common.DataSeparationEnabled()
	 Or Not Common.SeparatedDataUsageAvailable()
	 Or Not Common.SubsystemExists("CloudTechnology.Core") Then
		Return False;
	EndIf;
	
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	Return ModuleSaaSOperations.SessionWithoutSeparators();
	
EndFunction

// Sets a session flag.
// The flag indicates whether to restart the session with the brief error details to check the attempt exception.
//
// Parameters:
//  BriefErrorDescription - String - Brief details of an error occurred when one of the procedures is called:
//   - RequireRestartDueToApplicationVersionDynamicUpdate
//   - RequireRestartDueToApplicationExtensionsDynamicUpdate
//
Procedure InstallRequiresSessionRestart(BriefErrorDescription) Export
	
	If CurrentRunMode() <> Undefined Then
		Return;
	EndIf;
	
	CurrentSession = GetCurrentInfoBaseSession();
	If CurrentSession.ApplicationName <> "BackgroundJob" Then
		Return;
	EndIf;
	
	If SessionRestartRequired() Then
		Return;
	EndIf;
	
	CurrentParameters = New Structure(SessionParameters.InstalledExtensions);
	CurrentParameters.Insert("SessionRestartRequired", BriefErrorDescription);
	SessionParameters.InstalledExtensions = New FixedStructure(CurrentParameters);
	
EndProcedure

// Returns whether the SetSessionRestartRequired procedure was called. Returns brief error details specified at the procedure call.
// 
//
// Parameters:
//  BriefErrorDescription - String - Returnable value.
//    Set upon start of procedure SetSessionRestartRequired.
//
// Returns:
//  Boolean
//
Function SessionRestartRequired(BriefErrorDescription = "") Export
	
	If Not SessionParameters.InstalledExtensions.Property("SessionRestartRequired") Then
		Return False;
	EndIf;
	
	BriefErrorDescription = SessionParameters.InstalledExtensions.SessionRestartRequired;
	
	Return True;
	
EndFunction

// Checks if the caught exception is an error whose brief details start with
// the text specified during a call of procedure SetSessionRestartRequired.
//
// Parameters:
//  ErrorInfo - ErrorInfo
//
// Returns:
//  Boolean
//
Function ThisErrorRequirementRestartSession(ErrorInfo) Export
	
	ErrorText = "";
	If Not SessionRestartRequired(ErrorText) Then
		Return False;
	EndIf;
	
	Return TypeOf(ErrorInfo) = Type("ErrorInfo")
	      And ValueIsFilled(ErrorText)
	      And StrStartsWith(ErrorProcessing.BriefErrorDescription(ErrorInfo), ErrorText);
	
EndFunction

// Returns the value of the application parameter.
//
// In the previous session (when the application version is updated dynamically),
// if the parameter does not exist, an exception is thrown with a recommendation to restart,
// otherwise, the value is returned ignoring the version.
//
// In the separated SaaS mode, if the parameter does not exist
// or the parameter version is not equal to the configuration version, an exception is thrown
// as the shared data cannot be updated.
//
// Parameters:
//  ParameterName - String - must not exceed 128 characters. For example,
//                 StandardSubsystems.ReportsOptions.ReportsWithSettings.
//
// Returns:
//  Arbitrary - Undefined is returned when the parameter does not exist
//                 or when in the new session, the parameter version is not equal to the configuration version.
//
Function ApplicationParameter(ParameterName) Export
	
	Return InformationRegisters.ApplicationRuntimeParameters.ApplicationParameter(ParameterName);
	
EndFunction

// Sets the value of the application operation parameter.
// You have to set the privileged mode before the procedure call.
//
// Parameters:
//  ParameterName - String - must not exceed 128 characters. For example,
//                 StandardSubsystems.ReportsOptions.ReportsWithSettings.
//
//  Value     - Arbitrary - a value that can be put in a value storage.
//
Procedure SetApplicationParameter(ParameterName, Value) Export
	
	InformationRegisters.ApplicationRuntimeParameters.SetApplicationParameter(ParameterName, Value);
	
EndProcedure

// Updates the value of the application operation parameter, if it has changed.
// You have to set the privileged mode before the procedure call.
//
// Parameters:
//  ParameterName   - String - must not exceed 128 characters. For example,
//                   StandardSubsystems.ReportsOptions.ReportsWithSettings.
//
//  Value       - Arbitrary - a value that can be put in a value storage.
//
//  HasChanges  - Boolean - a return value. It is set to True
//                   if a previous and a new parameter values do not match.
//
//  PreviousValue2 - Arbitrary - a return value. Before an update.
//
Procedure UpdateApplicationParameter(ParameterName, Value, HasChanges = False, PreviousValue2 = Undefined) Export
	
	InformationRegisters.ApplicationRuntimeParameters.UpdateApplicationParameter(ParameterName,
		Value, HasChanges, PreviousValue2);
	
EndProcedure

// Returns application parameter changes according to the current configuration
// version and the current infobase version.
//
// Parameters:
//  ParameterName - String - must not exceed 128 characters. For example,
//                 StandardSubsystems.ReportsOptions.ReportsWithSettings.
//
// Returns:
//  Undefined - means everything changed. Is returned
//                 in case of initial infobase or data area filling.
//  Array - contains values of changes. If the array is empty, there are no changes.
//                 Can contain several changes, for example, when data area has not been updated for a long time.
//
Function ApplicationParameterChanges(ParameterName) Export
	
	Return InformationRegisters.ApplicationRuntimeParameters.ApplicationParameterChanges(ParameterName);
	
EndFunction

// Add the changes of th application operation parameter during update to the current version of configuration metadata.
// Later changes are used for conditional adding of mandatory update handlers.
// In case of initial infobase or shared data filling, changes are not added.
// 
// Parameters:
//  ParameterName - String - must not exceed 128 characters. For example,
//                 StandardSubsystems.ReportsOptions.ReportsWithSettings.
//
//  Changes    - Arbitrary - fixed data that is registered as changes.
//                 Changes are not added if the value of ParameterChange is not filled.
//
Procedure AddApplicationParameterChanges(ParameterName, Changes) Export
	
	InformationRegisters.ApplicationRuntimeParameters.AddApplicationParameterChanges(ParameterName, Changes);
	
EndProcedure

// For internal use only.
Procedure RegisterPriorityDataChangeForSubordinateDIBNodes() Export
	
	If Common.IsSubordinateDIBNode()
	 Or Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	If Not StandardSubsystemsCached.DisableMetadataObjectsIDs() Then
		Catalogs.MetadataObjectIDs.RegisterTotalChangeForSubordinateDIBNodes();
	EndIf;
	
	DIBExchangePlansNodes = New Map;
	For Each ExchangePlan In Metadata.ExchangePlans Do
		If Not ExchangePlan.DistributedInfoBase Then
			Continue;
		EndIf;
		DIBNodes = New Array;
		DIBExchangePlansNodes.Insert(ExchangePlan.Content, DIBNodes);
		ExchangePlanManager = Common.ObjectManagerByFullName(ExchangePlan.FullName());
		Selection = ExchangePlanManager.Select();
		While Selection.Next() Do
			If Selection.Ref <> ExchangePlanManager.ThisNode() Then
				DIBNodes.Add(Selection.Ref);
			EndIf;
		EndDo;
	EndDo;
	
	If DIBExchangePlansNodes.Count() > 0 Then
		RegisterPredefinedItemChanges(DIBExchangePlansNodes, Metadata.Catalogs);
		RegisterPredefinedItemChanges(DIBExchangePlansNodes, Metadata.ChartsOfCharacteristicTypes);
		RegisterPredefinedItemChanges(DIBExchangePlansNodes, Metadata.ChartsOfAccounts);
		RegisterPredefinedItemChanges(DIBExchangePlansNodes, Metadata.ChartsOfCalculationTypes);
	EndIf;
	
EndProcedure

// Creates the missing predefined items with new references (UUID) in all lists.
// For a call after disconnecting a subordinate node of the DIB from the main one, or for automatic recovery of 
// missing predefined items.
//
Procedure RestorePredefinedItems() Export
	
	If ExchangePlans.MasterNode() <> Undefined Then
		Raise 
			NStr("en = 'Restore the predefined items in the master node of the distributed infobase.
			           |Then synchronize the other nodes with the master node.';");
	EndIf;
	
	MetadataObjects = MetadataObjectsOfAllPredefinedData();
	Block = New DataLock;
	For Each MetadataObject In MetadataObjects Do
		Block.Add(MetadataObject.FullName());
	EndDo;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		SetAllPredefinedDataInitialization(MetadataObjects);
		CreateMissingPredefinedData(MetadataObjects);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function PredefinedDataAttributes() Export
	Result = New Structure;
	Result.Insert("PredefinedDataName",  "");
	Result.Insert("PredefinedSetName", "");
	Result.Insert("PredefinedKindName",   "");
	Result.Insert("PredefinedFolderType",   Undefined);
	Return Result;
EndFunction

Function ThisIsPredefinedData(Val Item, AttributeName = "", AttributeValue = "") Export // ACC:581 - An export function for auto-testing purposes.
	
	// For the subsystems "Properties", "ContactInformation", and "Interactions", to define predefined items,
	// read the following attributes: "PredefinedSetName", "PredefinedKindName", "PredefinedFolderType".
	AttributesValues = PredefinedDataAttributes();
	FillPropertyValues(AttributesValues, Item);
	If AttributesValues.PredefinedDataName = ""
		And AttributesValues.PredefinedSetName = ""
		And AttributesValues.PredefinedKindName = ""
		And Not ValueIsFilled(AttributesValues.PredefinedFolderType) Then
		Return False;
	EndIf;

	AttributeName = "";
	If AttributesValues.PredefinedSetName <> "" Then
		AttributeName = "PredefinedSetName";
	ElsIf AttributesValues.PredefinedKindName <> "" Then
		AttributeName = "PredefinedKindName";
	ElsIf ValueIsFilled(AttributesValues.PredefinedFolderType) Then
		AttributeName = "PredefinedFolderType";
	Else
		AttributeName = "PredefinedDataName";
	EndIf;
	AttributeValue = AttributesValues[AttributeName];
	
	Return True;
	
EndFunction

// Parameters:
//  References - Array of AnyRef
//         - FixedArray of AnyRef - References to objects.
//           If the array is blank, a blank map is returned.
//  Attributes - Array of String
//            - FixedArray of String - Attribute names formatted according to structure property requirements.
//            - String - Comma-delimited attribute names
//
// Returns:
//  Map of KeyAndValue - List of objects and their attribute values:
//   * Key - AnyRef - object reference;
//   * Value - Structure:
//    ** Key - String - an attribute name;
//    ** Value - Arbitrary - Attribute value. "Undefined" if the object does not have this attribute.
// 
Function ObjectAttributeValuesIfExist(References, Val Attributes) Export
	
	AttributesValues = New Map;
	If References.Count() = 0 Then
		Return AttributesValues;
	EndIf;
	
	If TypeOf(Attributes) = Type("String") Then
		Attributes = StrSplit(Attributes, ",");
	EndIf;
	
	TypesAttributes = New Map;
	RefsByTypes = New Map;
	For Each Ref In References Do
		Type = TypeOf(Ref);
		If Not Common.IsReference(Type) Then
			Continue;
		EndIf;
		
		If RefsByTypes[Type] = Undefined Then
			RefsByTypes[Type] = New Array;
		EndIf;
		ItemByType = RefsByTypes[Type]; // Array
		ItemByType.Add(Ref);
		
		If TypesAttributes[Type] = Undefined Then
			
			MetadataObject = Metadata.FindByType(Type); // MetadataObjectCatalog
			If MetadataObject = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Invalid value of the %1 parameter, function %2:
						|The array values must be references.';"), 
					"References", "Common.ObjectAttributeValuesIfExist");
			EndIf;
			AttributesOfType = New Array;
			StandardAttributes = New Map;
			For Each StandardAttribute In MetadataObject.StandardAttributes Do
				StandardAttributes[StandardAttribute.Name] = True;	
			EndDo;
			StandardAttributes["DataVersion"] = True;

			For Each AttributeName In Attributes Do
				If StandardAttributes[AttributeName] <> Undefined 
					Or MetadataObject.Attributes.Find(AttributeName) <> Undefined Then
					AttributesOfType.Add(AttributeName);
				Else
					AttributesOfType.Add("UNDEFINED AS" + " " + AttributeName); // @query-part
				EndIf;
			EndDo;
			TypesAttributes[Type] = AttributesOfType;
			
		EndIf;
	EndDo;
	
	
	If RefsByTypes.Count() = 0 Then
		Return AttributesValues;
	EndIf;
	
	QueriesTexts = New Array;
	Query = New Query;
	
	For Each RefsByType In RefsByTypes Do
		Type = RefsByType.Key;
		MetadataObject = Metadata.FindByType(Type);
		FullMetadataObjectName = MetadataObject.FullName();

		QueryText =
			"SELECT ALLOWED
			|	Ref,
			|	&Attributes
			|FROM
			|	&FullMetadataObjectName AS SpecifiedTableAlias
			|WHERE
			|	SpecifiedTableAlias.Ref IN (&References)";
		If QueriesTexts.Count() > 0 Then
			QueryText = StrReplace(QueryText, "ALLOWED", ""); // @query-part-1
		EndIf;
		AttributesQueryText = StrConcat(TypesAttributes[Type], ",");
		QueryText = StrReplace(QueryText, "&Attributes", AttributesQueryText);
		QueryText = StrReplace(QueryText, "&FullMetadataObjectName", FullMetadataObjectName);
		ParameterName = "References" + StrReplace(FullMetadataObjectName, ".", "");
		QueryText = StrReplace(QueryText, "&References", "&" + ParameterName); // @query-part-1
		Query.SetParameter(ParameterName, RefsByType.Value);

		QueriesTexts.Add(QueryText);
	EndDo;
	
	AttributesNames = StrConcat(Attributes, ",");
	QueryText = StrConcat(QueriesTexts, Chars.LF + "UNION ALL" + Chars.LF); // @query-part
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Result = New Structure(AttributesNames);
		FillPropertyValues(Result, Selection);
		AttributesValues[Selection.Ref] = Result;
	EndDo;
	
	Return AttributesValues;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedure to set or get extension parameters (caches).

// Returns the parameter values for the current extension version.
// Returns Undefined if no storage is set.
//
// Parameters:
//  ParameterName - String - must not exceed 128 characters. For example,
//                 StandardSubsystems.ReportsOptions.ReportsWithSettings.
//  
//  IgnoreExtensionsVersion - Boolean
//  
//  IsAlreadyModified - Boolean - Return value. It is set to True, if IgnoreExtensionsVersion is True,
//                 the value in the value storage is not "Undefined", and
//                 the value was set by an earlier session.
//                 
//             - Undefined - No need to set a value.
//
// Returns:
//  Arbitrary - Undefined is returned if the parameter is not filled
//                 for current the extension version.
//
Function ExtensionParameter(ParameterName, IgnoreExtensionsVersion = False, IsAlreadyModified = Undefined) Export
	
	Return InformationRegisters.ExtensionVersionParameters.ExtensionParameter(ParameterName,
		IgnoreExtensionsVersion, IsAlreadyModified);
	
EndFunction

// Sets parameter value storage for the current extension version.
// Used to fill parameter values.
// You have to set the privileged mode before the procedure call.
//
// Parameters:
//  ParameterName - String - must not exceed 128 characters. For example,
//                 StandardSubsystems.ReportsOptions.ReportsWithSettings.
//
//  Value     - Arbitrary - a parameter value.
//  IgnoreExtensionsVersion - Boolean
//
Procedure SetExtensionParameter(ParameterName, Value, IgnoreExtensionsVersion = False) Export
	
	InformationRegisters.ExtensionVersionParameters.SetExtensionParameter(ParameterName, Value, IgnoreExtensionsVersion);
	
EndProcedure

// DeleteObsoleteExtensionsVersionsParameters scheduled job handler.
Procedure DeleteObsoleteExtensionsVersionsParametersJobHandler() Export
	
	Common.OnStartExecuteScheduledJob(
		Metadata.ScheduledJobs.DeleteObsoleteExtensionsVersionsParameters);
	
	SetPrivilegedMode(True);
	Catalogs.ExtensionsVersions.DeleteObsoleteParametersVersions();
	
EndProcedure

// The handler of the FillExtensionsOperationParameters scheduled job.
//
// The job must be started right after it is enabled.
// The job is auto-disabled after a successful execution.
//
Procedure FillExtensionsOperationParameters() Export
	
	Common.OnStartExecuteScheduledJob(
		Metadata.ScheduledJobs.FillExtensionsOperationParameters);
	
	SetPrivilegedMode(True);
	InformationRegisters.ExtensionVersionParameters.FillinAllJobParametersLatestVersionExtensions();
	InformationRegisters.ExtensionProperties.DeletePropertiesOfDeletedExtensions();
	
EndProcedure

// Intended for internal usage only (a background job procedure).
Procedure FillAllExtensionParametersBackgroundJob(Parameters) Export
	
	InformationRegisters.ExtensionVersionParameters.FillAllExtensionParametersBackgroundJob(Parameters);
	
EndProcedure

// Intended for internal usage only (a background job procedure).
Procedure AddNewVersionOfExtensions(ExtensionsDetails) Export
	
	SetPrivilegedMode(True);
	Catalogs.ExtensionsVersions.AddNewVersionOfExtensions(ExtensionsDetails);
	
EndProcedure

// Intended for internal usage only (a background job procedure).
Procedure UpdateDateOfLastUseOfExtensionVersion(ExtensionsVersion) Export
	
	SetPrivilegedMode(True);
	Catalogs.ExtensionsVersions.UpdateDateOfLastUseOfExtensionVersion(ExtensionsVersion);
	
EndProcedure

// Intended for internal usage only (a background job procedure).
Procedure InstallLatestVersionOfExtensions(ExtensionsVersion) Export
	
	SetPrivilegedMode(True);
	Catalogs.ExtensionsVersions.InstallLatestVersionOfExtensions(ExtensionsVersion);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional base functionality for data exchange .

// Records changes of the object for all exchange plan nodes.
// The separated configurations must meet the following conditions:
//  - Exchange plan should be separated,
//  - Object to be registered should be shared.
//
//  Parameters:
//    Object         - CatalogObject
//                   - DocumentObject
//                   - BusinessProcessObject
//                   - TaskObject
//                   - ChartOfCalculationTypesObject
//                   - ChartOfCharacteristicTypesObject
//                   - ChartOfAccountsObject
//                   - ExchangePlanObject
//
//    ExchangePlanName - String - a name of the exchange plan where the object is registered in all nodes.
//                              The exchange plan must be shared, otherwise an exception is raised.
//
//    IncludeMasterNode - Boolean - If False, registration of the master node
//                         will not be performed in the subordinate node.
// 
//
Procedure RecordObjectChangesInAllNodes(Val Object, Val ExchangePlanName, Val IncludeMasterNode = True) Export
	
	If Metadata.ExchangePlans[ExchangePlanName].Content.Find(Object.Metadata()) = Undefined Then
		Return;
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		
		If Common.SeparatedDataUsageAvailable() Then
			Raise NStr("en = 'Register changes of shared data in separated mode.';");
		EndIf;
		
		ModuleSaaSOperations = Undefined;
		If Common.SubsystemExists("CloudTechnology.Core") Then
			ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		EndIf;
		
		If ModuleSaaSOperations <> Undefined Then
			IsSeparatedExchangePlan = ModuleSaaSOperations.IsSeparatedMetadataObject(
				"ExchangePlan." + ExchangePlanName, ModuleSaaSOperations.MainDataSeparator());
		Else
			IsSeparatedExchangePlan = False;
		EndIf;
		
		If Not IsSeparatedExchangePlan Then
			Raise NStr("en = 'Shared exchange plans don''t support registration of changes.';");
		EndIf;
		
		If ModuleSaaSOperations <> Undefined Then
			IsSeparatedMetadataObject = ModuleSaaSOperations.IsSeparatedMetadataObject(
				Object.Metadata().FullName(), ModuleSaaSOperations.MainDataSeparator());
		Else
			IsSeparatedMetadataObject = False;
		EndIf;
		
		If IsSeparatedMetadataObject Then
				Raise NStr("en = 'Separated objects don''t support registration of changes.';");
		EndIf;
		
		QueryText =
		"SELECT
		|	ExchangePlan.Ref AS Recipient
		|FROM
		|	#ExchangePlanTable AS ExchangePlan
		|WHERE
		|	ExchangePlan.RegisterChanges
		|	AND NOT ExchangePlan.ThisNode
		|	AND NOT ExchangePlan.DeletionMark";
		
		QueryText = StrReplace(QueryText, "#ExchangePlanTable", "ExchangePlan." + ExchangePlanName);
		
		Query = New Query;
		Query.Text = QueryText;
		
		Recipients = Query.Execute().Unload().UnloadColumn("Recipient");
		
		For Each Recipient In Recipients Do
			
			Object.DataExchange.Recipients.Add(Recipient);
			
		EndDo;
		
	Else
		
		QueryText =
		"SELECT
		|	ExchangePlan.Ref AS Recipient
		|FROM
		|	#ExchangePlanTable AS ExchangePlan
		|WHERE
		|	NOT ExchangePlan.ThisNode
		|	AND NOT ExchangePlan.DeletionMark";
		
		QueryText = StrReplace(QueryText, "#ExchangePlanTable", "ExchangePlan." + ExchangePlanName);
		
		Query = New Query;
		Query.Text = QueryText;
		
		Recipients = Query.Execute().Unload().UnloadColumn("Recipient");
		
		MasterNode = ExchangePlans.MasterNode();
		
		For Each Recipient In Recipients Do
			If Not IncludeMasterNode And Recipient = MasterNode Then
				Continue;
			EndIf;
			Object.DataExchange.Recipients.Add(Recipient);
		EndDo;
		
	EndIf;
	
EndProcedure

// Saves the reference to master node in the MasterNode constant for recovery opportunity.
Procedure SaveMasterNode() Export
	
	MasterNodeManager = Constants.MasterNode.CreateValueManager();
	MasterNodeManager.Value = ExchangePlans.MasterNode();
	InfobaseUpdate.WriteData(MasterNodeManager);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of exchange data sending and receiving in a DIB.

// The procedure handles the same-name event that occurs during data exchange in a distributed infobase.
// For parameters, see "OnSendDataToSubordinate" in Syntax Assistant.
// 
// 
// Parameters:
//  DataElement - Arbitrary
//  ItemSend - DataItemSend
//  InitialImageCreating - Boolean
//  Recipient - ExchangePlanObject
// 
Procedure OnSendDataToSlave(DataElement, ItemSend, Val InitialImageCreating, Val Recipient) Export
	
	If ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
	
	// Metadata object IDs are sent in another exchange message section.
	IgnoreSendingMetadataObjectIDs(DataElement, ItemSend, InitialImageCreating);
	IgnoreSendingDataProcessedOnMasterDIBNodeOnInfobaseUpdate(DataElement, InitialImageCreating, Recipient);
	If ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
	
	DataExchangeSubsystemExists1 = Common.SubsystemExists("StandardSubsystems.DataExchange");
	
	// Adding data exchange subsystem script first.
	If DataExchangeSubsystemExists1 Then
		ModuleDataExchangeEvents = Common.CommonModule("DataExchangeEvents");
		ModuleDataExchangeEvents.OnSendDataToRecipient(DataElement, ItemSend, InitialImageCreating, Recipient, False);
		
		If ItemSend = DataItemSend.Ignore Then
			Return;
		EndIf;
	EndIf;
	
	SSLSubsystemsIntegration.OnSendDataToSlave(DataElement, ItemSend, InitialImageCreating, Recipient);
	If ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
	
	// Insertion of data exchange subsystem script in the SaaS model should be the last one to affect the sending logic.
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnSendDataToSlave(DataElement, ItemSend, InitialImageCreating, Recipient);
		
		If ItemSend = DataItemSend.Ignore Then
			Return;
		EndIf;
	EndIf;
	
	If DataExchangeSubsystemExists1 Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.CalculateDIBDataExportPercentage(Recipient, InitialImageCreating);
	EndIf;
	
EndProcedure

// The procedure handles the same-name event that occurs during data exchange in a distributed infobase.
// For the parameters, see "OnSendDataToSubordinate" in Syntax Assistant.
// 
// 
// Parameters:
//  DataElement - Arbitrary
//  ItemReceive - DataItemReceive
//  SendBack - Boolean
//  Sender - ExchangePlanObject
// 
Procedure OnReceiveDataFromSlave(DataElement, ItemReceive, SendBack, Val Sender) Export
	
	// Metadata object IDs can be changes only in the master node.
	IgnoreGettingMetadataObjectIDs(DataElement, ItemReceive);
	
	If ItemReceive = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	SSLSubsystemsIntegration.OnReceiveDataFromSlave(DataElement, ItemReceive, SendBack, Sender);
	If ItemReceive = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	// Calling an overridden handler to execute the applied logic of DIB exchange.
	CommonOverridable.OnReceiveDataFromSlave(DataElement, ItemReceive, SendBack, Sender);
	
	DataExchangeSubsystemExists1 = Common.SubsystemExists("StandardSubsystems.DataExchange");
	
	// Insertion of data exchange subsystem script should be the last one to affect the receiving logic.
	If DataExchangeSubsystemExists1 Then
		ModuleDataExchangeEvents = Common.CommonModule("DataExchangeEvents");
		ModuleDataExchangeEvents.OnReceiveDataFromSlaveInEnd(DataElement, ItemReceive, Sender);
	EndIf;
	
	If DataExchangeSubsystemExists1 Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.CalculateDIBDataImportPercentage(Sender);
	EndIf;
	
EndProcedure

// Procedure handles the event of the same name that occurs during data exchange in a distributed infobase
// See the OnReceiveDataFromMaster() event handler details in Syntax Assistant.
// "Sender" can be empty. For example, when getting the initial image message in SWP.
// 
// 
// Parameters:
//  DataElement - Arbitrary
//  ItemReceive - DataItemReceive
//  SendBack - Boolean
//  Sender - ExchangePlanObject
//
Procedure OnReceiveDataFromMaster(DataElement, ItemReceive, SendBack, Sender = Undefined) Export
	
	If ItemReceive = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	DataExchangeSubsystemExists1 = Common.SubsystemExists("StandardSubsystems.DataExchange");
	
	// Adding data exchange subsystem script first.
	If DataExchangeSubsystemExists1 Then
		ModuleDataExchangeEvents = Common.CommonModule("DataExchangeEvents");
		ModuleDataExchangeEvents.OnReceiveDataFromMasterInBeginning(DataElement, ItemReceive, SendBack, Sender);
		
		If ItemReceive = DataItemReceive.Ignore Then
			Return;
		EndIf;
		
	EndIf;
	
	SSLSubsystemsIntegration.OnReceiveDataFromMaster(DataElement, ItemReceive, SendBack, Sender);
	If ItemReceive = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	// Calling an overridden handler to execute the applied logic of DIB exchange.
	CommonOverridable.OnReceiveDataFromMaster(Sender, DataElement, ItemReceive, SendBack);
	
	// Insertion of data exchange subsystem script should be the last one to affect the receiving logic.
	If DataExchangeSubsystemExists1
		And Not InitialImageCreating(DataElement) Then
		
		ModuleDataExchangeEvents = Common.CommonModule("DataExchangeEvents");
		ModuleDataExchangeEvents.OnReceiveDataFromMasterInEnd(DataElement, ItemReceive, Sender);
		
	EndIf;
	
	If DataExchangeSubsystemExists1 Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.CalculateDIBDataImportPercentage(Sender);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional functions for handling types.

// Returns the reference type or the record key type of the specified metadata object .
//
// Parameters:
//  MetadataObject - MetadataObject - a register or a reference object.
//
//  Returns:
//   Type
//
Function MetadataObjectReferenceOrMetadataObjectRecordKeyType(MetadataObject) Export
	
	If Common.IsRegister(MetadataObject) Then
		
		If Common.IsInformationRegister(MetadataObject) Then
			RegisterType = "InformationRegister";
			
		ElsIf Common.IsAccumulationRegister(MetadataObject) Then
			RegisterType = "AccumulationRegister";
			
		ElsIf Common.IsAccountingRegister(MetadataObject) Then
			RegisterType = "AccountingRegister";
			
		ElsIf Common.IsCalculationRegister(MetadataObject) Then
			RegisterType = "CalculationRegister";
		EndIf;
		Type = Type(RegisterType + "RecordKey." + MetadataObject.Name);
	Else
		Manager = Common.ObjectManagerByFullName(MetadataObject.FullName());
		Type = TypeOf(Manager.EmptyRef());
	EndIf;
	
	Return Type;
	
EndFunction

// Returns the object type or the record set type of the specified metadata object.
//
// Parameters:
//  MetadataObject - MetadataObject - a register or a reference object.
//
//  Returns:
//   Type
//
Function MetadataObjectOrMetadataObjectRecordSetType(MetadataObject) Export
	
	If Common.IsRegister(MetadataObject) Then
		
		If Common.IsInformationRegister(MetadataObject) Then
			RegisterType = "InformationRegister";
			
		ElsIf Common.IsAccumulationRegister(MetadataObject) Then
			RegisterType = "AccumulationRegister";
			
		ElsIf Common.IsAccountingRegister(MetadataObject) Then
			RegisterType = "AccountingRegister";
			
		ElsIf Common.IsCalculationRegister(MetadataObject) Then
			RegisterType = "CalculationRegister";
		EndIf;
		Type = Type(RegisterType + "RecordSet." + MetadataObject.Name);
	Else
		Manager = Common.ObjectManagerByFullName(MetadataObject.FullName());
		ObjectKind = Common.ObjectKindByType(TypeOf(Manager.EmptyRef()));
		Type = Type(ObjectKind + "Object." + MetadataObject.Name);
	EndIf;
	
	Return Type;
	
EndFunction

// Checks whether the passed object has the CatalogObject.MetadataObjectIDs type.
//
// Parameters:
//  Object - Arbitrary
// 
// Returns:
//  Boolean
//
Function IsMetadataObjectID(Object) Export
	
	Return TypeOf(Object) = Type("CatalogObject.MetadataObjectIDs");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedure and function for handling forms.

// Sets the form purpose key (the purpose use key and
// the window options key). If necessary, it copies the current form settings
// if they were not recorded for the new associated key.
//
// Parameters:
//  Form - ClientApplicationForm - the OnCreateAtServer form for which a key is set.
//  Var_Key  - String - a new form assignment key.
//  LocationKey - String
//  SetSettings - Boolean - set settings saved for the current key to the new one.
//
Procedure SetFormAssignmentKey(Form, Var_Key, LocationKey = "", SetSettings = True) Export
	
	SetFormAssignmentUsageKey(Form, Var_Key, SetSettings);
	SetFormWindowOptionsSaveKey(Form, ?(LocationKey = "", Var_Key, LocationKey), SetSettings);
	
EndProcedure

Procedure ResetWindowLocationAndSize(Form) Export
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	FormName = Form.FormName;
	NewKeyForSavingTheWindowPosition = StrReplace(String(New UUID), "-", "_");
	StorageObjectKey = FormName + "/TemporaryKeysForSavingTheWindowPosition";
	UserName = UserName();
	BegOfDay = BegOfDay(CurrentUniversalDate());
	TheBoundaryOfObsolescence = BegOfDay - 2*24*60*60;
	
	Keys = SystemSettingsStorage.Load(StorageObjectKey);
	
	If TypeOf(Keys) = Type("Map") Then
		SettingsNames = New Array;
		SettingsNames.Add("/ThinClientWindowSettings");
		SettingsNames.Add("/Taxi/ThinClientWindowSettings");
		SettingsNames.Add("/WebClientWindowSettings");
		SettingsNames.Add("/MobileClientWindowSettings");
		SettingsNames.Add("/Taxi/WebClientWindowSettings");
		SettingsNames.Add("/Taxi/MobileClientWindowSettings");
		CurrentKeys = New Map(New FixedMap(Keys));
		For Each KeyAndValue In CurrentKeys Do
			CurrentDay = KeyAndValue.Key;
			If TypeOf(CurrentDay) <> Type("Date") Then
				Keys = Undefined;
				Break;
			EndIf;
			If CurrentDay > TheBoundaryOfObsolescence Then
				Continue;
			EndIf;
			KeysOfTheCurrentDay = KeyAndValue.Value;
			If TypeOf(KeysOfTheCurrentDay) <> Type("Array") Then
				Keys = Undefined;
				Break;
			EndIf;
			For Each CurrentKey In KeysOfTheCurrentDay Do
				TheBeginningOfTheObjectKey = FormName + "/" + CurrentKey;
				For Each SettingName In SettingsNames Do
					SystemSettingsStorage.Delete(TheBeginningOfTheObjectKey + SettingName, "", UserName);
				EndDo;
			EndDo;
			Keys.Delete(CurrentDay);
		EndDo;
	EndIf;
	
	ClearOldKeys = TypeOf(Keys) <> Type("Map");
	If ClearOldKeys Then
		Keys = New Map;
	EndIf;
	
	KeysOfTheDay = Keys.Get(BegOfDay);
	If TypeOf(KeysOfTheDay) <> Type("Array") Then
		KeysOfTheDay = New Array;
		Keys.Insert(BegOfDay, KeysOfTheDay);
	EndIf;
	KeysOfTheDay.Add(NewKeyForSavingTheWindowPosition);
	SystemSettingsStorage.Save(StorageObjectKey,, Keys);
	
	Form.WindowOptionsKey = NewKeyForSavingTheWindowPosition;
	
	If Not ClearOldKeys Then
		Return;
	EndIf;
	
	Filter = New Structure("User", UserName);
	Selection = SystemSettingsStorage.Select(Filter);
	KeySearchRussian = "НастройкиОкнаТонкогоКлиента"; // @Non-NLS
	SearchKeyEnglish = "ThinClientWindowSettings";
	While True Do
		Try
			ThereIsAnotherOne = Selection.Next();
		Except
			ErrorInfo = ErrorInfo();
			WriteLogEvent(
				NStr("en = 'Runtime error';", Common.DefaultLanguageCode()),
				EventLogLevel.Error,,,
				ErrorProcessing.DetailErrorDescription(ErrorInfo));
			Break;
		EndTry;
		If Not ThereIsAnotherOne Then
			Break;
		EndIf;
		If Not StrStartsWith(Selection.ObjectKey, FormName)
		 Or Selection.SettingsKey <> ""
		 Or Selection.ObjectKey = StorageObjectKey Then
			Continue;
		EndIf;
		ObjectKeyParts1 = StrSplit(Selection.ObjectKey, "/");
		If ObjectKeyParts1.Count() < 2 Then
			Continue;
		EndIf;
		TheLastPartOfTheKey = ObjectKeyParts1[ObjectKeyParts1.UBound()];
		If StrFind(TheLastPartOfTheKey, KeySearchRussian) > 0
		 Or StrFind(TheLastPartOfTheKey, SearchKeyEnglish) > 0 Then
			SystemSettingsStorage.Delete(Selection.ObjectKey, "", UserName);
		EndIf;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Returns additional details when application parameter problem occurs.
// 
// Returns:
//  String
//
Function ApplicationRunParameterErrorClarificationForDeveloper() Export
	
	Return Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString( 
		NStr("en = 'Perhaps, some service data requires an update.
			|Do one of the following:
			| • Run external data processor
			|""Development tools: Service data update.""
			| • Run the app with command-line option:
			|/C %1.
			| • Update the app to a later version.
			|The data update procedures will start automatically at launch.';"),
		"StartInfobaseUpdate");
	
EndFunction

// Returns the current infobase user.
// 
// Returns:
//  InfoBaseUser
//
Function CurrentUser() Export
	
	// Calculate the up-to-date username even if it was changed in the current session.
	// (For example, when the infobase is accessed via an external session.)
	// In other cases, get "InfobaseUsers.CurrentUser".
	CurrentUser = InfoBaseUsers.FindByUUID(
		InfoBaseUsers.CurrentUser().UUID);
	
	If CurrentUser = Undefined Then
		CurrentUser = InfoBaseUsers.CurrentUser();
	EndIf;
	
	Return CurrentUser;
	
EndFunction

// Transforming a string to a valid description of a value table column values replacing invalid
// characters with the character code escaped with the underscore character.
//
// Parameters:
//  String - String - Source string.
// 
// Returns:
//  String - a string containing only admissible characters for the description of values table columns.
//
Function TransformStringToValidColumnDescription(String) Export
	
	InvalidChars = ":;!@#$%^&-~`'.,?{}[]+=*/|\ ()_""";
	Result = "";
	For IndexOf = 1 To StrLen(String) Do
		Char =  Mid(String, IndexOf, 1);
		If StrFind(InvalidChars, Char) > 0 Or (CharCode(Char) > 126 And CharCode(Char) < 256) Then
			Result = Result + "_" + CharCode(Char) + "_";
		Else
			Result = Result + Char;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Transforms adapted column description with prohibited
// characters replaced by the character code escaped with the underscore character (_) into a usual string.
//
// Parameters:
//  ColumnDescription - String - an adapted description of a column.
// 
// Returns:
//  String - a converted string.
//
Function TransformAdaptedColumnDescriptionToString(ColumnDescription) Export
	
	Result = "";
	For IndexOf = 1 To StrLen(ColumnDescription) Do
		Char = Mid(ColumnDescription, IndexOf, 1);
		If Char = "_" Then
			ClosingCharacterPosition = StrFind(ColumnDescription, "_", SearchDirection.FromBegin, IndexOf + 1);
			CharCode = Mid(ColumnDescription, IndexOf + 1, ClosingCharacterPosition - IndexOf - 1);
			Result = Result + Char(CharCode);
			IndexOf = ClosingCharacterPosition;
		Else
			Result = Result + Char;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Generates data required to notify open forms and dynamic lists
// on client on bunch object changes made on a server.
//
// Parameters:
//   ModifiedObjects - AnyRef
//                     - Type
//                     - Array - contains info about the changed objects.
//                       You can pass a reference or an array of references
//                       or specify a type or an array of types for changed objects.
//
// Returns:
//   Map of KeyAndValue:
//     * Key - Type - for example, DocumentRef.SalesOrder.
//     * Value - Structure:
//        ** EventName - String - for example, Record_SalesOrder.
//        ** EmptyRef - AnyRef
// 
Function PrepareFormChangeNotification(ModifiedObjects) Export
	
	Result = New Map;
	If ModifiedObjects = Undefined Then
		Return Result;
	EndIf;
	
	TypesArray = New Array;
	RefOrTypeOrArrayType = TypeOf(ModifiedObjects);
	If RefOrTypeOrArrayType = Type("Array") Then
		For Each Item In ModifiedObjects Do
			ElementType = TypeOf(Item);
			If ElementType = Type("Type") Then
				ElementType = Item;
			EndIf;
			If TypesArray.Find(ElementType) = Undefined Then
				TypesArray.Add(ElementType);
			EndIf;
		EndDo;
	Else
		TypesArray.Add(ModifiedObjects);
	EndIf;
	
	For Each ElementType In TypesArray Do
		MetadataObject = Metadata.FindByType(ElementType);
		If TypeOf(MetadataObject) <> Type("MetadataObject") Then
			Continue;
		EndIf;
		EventName = "Record_" + MetadataObject.Name;
		Try
			EmptyRef = PredefinedValue(MetadataObject.FullName() + ".EmptyRef");
		Except
			EmptyRef = Undefined;
		EndTry;
		Result.Insert(ElementType, New Structure("EventName,EmptyRef", EventName, EmptyRef));
	EndDo;
	Return Result;
	
EndFunction

// Sets the BlankHomePage common form for a desktop with empty form content.
//
// The separated desktop in web client
// requires the shared desktop form content to be filled, and vice versa.
//
Procedure SetBlankFormOnBlankHomePage() Export
	
	ObjectKey = "Common/HomePageSettings";
	
	CurrentSettings = SystemSettingsStorage.Load(ObjectKey);
	If CurrentSettings = Undefined Then
		CurrentSettings = New HomePageSettings;
	EndIf;
	
	CurrentFormComposition = CurrentSettings.GetForms();
	
	If CurrentFormComposition.LeftColumn.Count() = 0
	   And CurrentFormComposition.RightColumn.Count() = 0 Then
		
		CurrentFormComposition.LeftColumn.Add("CommonForm.BlankHomePage");
		CurrentSettings.SetForms(CurrentFormComposition);
		SystemSettingsStorage.Save(ObjectKey, "", CurrentSettings);
	EndIf;
	
EndProcedure

// Checks whether documents list posting is available for the current user.
//
// Parameters:
//  DocumentsList - Array - document for checking.
//
// Returns:
//  Boolean - True if the user has the right to post at least one document.
//
Function HasRightToPost(DocumentsList) Export
	DocumentTypes = New Array;
	For Each Document In DocumentsList Do
		DocumentType = TypeOf(Document);
		If DocumentTypes.Find(DocumentType) <> Undefined Then
			Continue;
		Else
			DocumentTypes.Add(DocumentType);
		EndIf;
		If AccessRight("Posting", Metadata.FindByType(DocumentType)) Then
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

// Checks if the passed table is a register.
// 
// Parameters:
//  TableName - String - a full table name.
// 
// Returns:
//  Boolean 
//
Function IsRegisterTable(TableName) Export
	InRegTableName = Upper(TableName);
	If StrStartsWith(InRegTableName, Upper("InformationRegister"))
		Or StrStartsWith(InRegTableName, Upper("AccumulationRegister"))
		Or StrStartsWith(InRegTableName, Upper("AccountingRegister"))
		Or StrStartsWith(InRegTableName, Upper("CalculationRegister")) Then
		Return True;
	EndIf;
	
	Return False;
EndFunction

// Returns a home page presentation.
//
// Returns:
//   String
//
Function HomePagePresentation() Export 
	
	Return NStr("en = 'Main';");
	
EndFunction

// Intended for the "WriteToBusinessProcessesList" event subscription.
//
Procedure CheckSafeModeBeforeRecording(Source, Cancel) Export
	// ACC:75-off - The "DataExchange.Import" check is excessive
	// as it should be performed anyway.
	
	// ACC:1371-off - This check is applicable to all metadata objects, including the ones being deleted.
	
	If GetSafeModeDisabled() Then
		SetSafeModeDisabled(False);
	EndIf;
	
	If SafeMode() = False Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not PrivilegedMode() Then
		Raise NStr("en = 'Action not supported in safe mode.';");
	EndIf;
	
EndProcedure

// Intended for the "CheckIfSafeModeIsOnBeforeWriteRecordSet" event subscription.
//
Procedure CheckSafeModeBeforeRecordingRecordingSet(Source, Cancel, Replacing,
				WriteOnly = Undefined,
				WriteActualActionPeriod = Undefined,
				WriteRecalculations = Undefined) Export
	
	// ACC:75-off - The "DataExchange.Import" check is excessive
	// as it should be performed anyway.
	
	// ACC:1371-off - This check is applicable to all metadata objects, including the ones being deleted.
	
	If GetSafeModeDisabled() Then
		SetSafeModeDisabled(False);
	EndIf;
	
	If SafeMode() = False Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not PrivilegedMode() Then
		Raise NStr("en = 'Action not supported in safe mode.';");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport.
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	// Cannot import to the MetadataObjectIDs.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.MetadataObjectIDs.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
	// Cannot import to the ExtensionObjectIDs catalog.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.ExtensionObjectIDs.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
EndProcedure

// See BatchEditObjectsOverridable.OnDefineObjectsWithEditableAttributes.
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	
	Objects.Insert(Metadata.Catalogs.MetadataObjectIDs.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.ExtensionObjectIDs.FullName(), "AttributesToEditInBatchProcessing");
	
EndProcedure

// See CommonOverridable.OnAddReferenceSearchExceptions.
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export
	
	RefSearchExclusions.Add(Metadata.InformationRegisters.SafeDataStorage.Dimensions.Owner);
	RefSearchExclusions.Add(Metadata.InformationRegisters.SafeDataAreaDataStorage.Dimensions.Owner);
	
EndProcedure

// See CommonOverridable.OnAddClientParameters.
Procedure OnAddClientParameters(Parameters) Export
	
	AddClientRunParameters(Parameters);
	
EndProcedure

// See CommonOverridable.OnAddServerNotifications
Procedure OnAddServerNotifications(Notifications) Export
	
	// FunctionalOptionsModified
	Notification = ServerNotifications.NewServerNotification(
		"StandardSubsystems.Core.FunctionalOptionsModified");
	
	Notification.NotificationSendModuleName  = "StandardSubsystemsServer";
	Notification.NotificationReceiptModuleName = "StandardSubsystemsClient";
	
	Notifications.Insert(Notification.Name, Notification);
	
	// CachedValuesOutdated
	Notification = ServerNotifications.NewServerNotification(
		"StandardSubsystems.Core.CachedValuesOutdated");
	
	Notification.NotificationReceiptModuleName = "StandardSubsystemsClient";
	
	Notifications.Insert(Notification.Name, Notification);
	
EndProcedure

// See ExportImportDataOverridable.OnFillCommonDataTypesSupportingRefMappingOnExport.
Procedure OnFillCommonDataTypesSupportingRefMappingOnExport(Types) Export
	
	Types.Add(Metadata.Catalogs.MetadataObjectIDs);
	
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport.
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.Constants.InfobasePublicationURL);
	Types.Add(Metadata.Constants.LocalInfobasePublishingURL);
	Types.Add(Metadata.Constants.InfoBaseID);
	Types.Add(Metadata.Constants.DeliverServerNotificationsWithoutCollaborationSystem);
	Types.Add(Metadata.Constants.RegisterServerNotificationsIndicators);
	ModuleExportImportData = Common.CommonModule("ExportImportData");
	ModuleExportImportData.AddTypeExcludedFromUploadingUploads(Types,
		Metadata.Catalogs.ExtensionsVersions,
		ModuleExportImportData.ActionWithLinksDoNotChange());
	ModuleExportImportData.AddTypeExcludedFromUploadingUploads(Types,
		Metadata.Catalogs.ExtensionObjectIDs,
		ModuleExportImportData.ActionWithLinksDoNotChange());
	Types.Add(Metadata.InformationRegisters.SafeDataAreaDataStorage);
	Types.Add(Metadata.InformationRegisters.ExtensionVersionObjectIDs);
	Types.Add(Metadata.InformationRegisters.ExtensionVersionParameters);
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources.
Procedure OnFillPermissionsToAccessExternalResources(PermissionsRequests) Export
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	Permissions = New Array();
	
	Permissions.Add(ModuleSafeModeManager.PermissionToUseTempDirectory(True, True,
		NStr("en = 'Basic permissions required to run the app.';")));
	Permissions.Add(ModuleSafeModeManager.PermissionToUsePrivilegedMode());
	
	PermissionsRequests.Add(
		ModuleSafeModeManager.RequestToUseExternalResources(Permissions));
	
	AddRequestForPermissionToUseExtensions(PermissionsRequests);
	
EndProcedure

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	
	Id = "DynamicApplicationUpdateControl";
	ToDoItem = ToDoList.Add();
	ToDoItem.Id = Id;
	ToDoItem.HasToDoItems      = DataBaseConfigurationChangedDynamically()
	                     Or Catalogs.ExtensionsVersions.ExtensionsChangedDynamically();
	ToDoItem.Important        = False;
	ToDoItem.Presentation = NStr("en = 'Application update installed';");
	ToDoItem.Form         = "CommonForm.DynamicUpdateControl";
	ToDoItem.Owner      = NStr("en = 'Application performance';");
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If ModuleToDoListServer.UserTaskDisabled("SpeedupRecommendation") Then
		Return;
	EndIf;
	
	Id = "SpeedupRecommendation";
	ToDoItem = ToDoList.Add();
	ToDoItem.Id = Id;
	ToDoItem.HasToDoItems      = MustShowRAMSizeRecommendations();
	ToDoItem.Important        = True;
	ToDoItem.Presentation = NStr("en = 'Application performance degraded';");
	ToDoItem.Form         = "DataProcessor.SpeedupRecommendation.Form";
	ToDoItem.Owner      = NStr("en = 'Application performance';");
	
EndProcedure

// See UsersOverridable.OnDefineRoleAssignment
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// ForSystemAdministratorsOnly.
	RolesAssignment.ForSystemAdministratorsOnly.Add(
		Metadata.Roles.SystemAdministrator.Name);
	
	RolesAssignment.ForSystemAdministratorsOnly.Add(
		Metadata.Roles.Administration.Name);
	
	RolesAssignment.ForSystemAdministratorsOnly.Add(
		Metadata.Roles.UpdateDataBaseConfiguration.Name);
	
	// ForSystemUsersOnly.
	RolesAssignment.ForSystemUsersOnly.Add(
		Metadata.Roles.StartThickClient.Name);
	
	RolesAssignment.ForSystemUsersOnly.Add(
		Metadata.Roles.StartExternalConnection.Name);
	
	RolesAssignment.ForSystemUsersOnly.Add(
		Metadata.Roles.StartAutomation.Name);
	
	RolesAssignment.ForSystemUsersOnly.Add(
		Metadata.Roles.TechnicianMode.Name);
	
	RolesAssignment.ForSystemUsersOnly.Add(
		Metadata.Roles.InteractiveOpenExtReportsAndDataProcessors.Name);
	
	// ForExternalUsersOnly.
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.BasicAccessExternalUserSSL.Name);
	
	// BothForUsersAndExternalUsers.
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.StartThinClient.Name);
	
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.StartWebClient.Name);
	
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.StartMobileClient.Name);
	
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.OutputToPrinterFileClipboard.Name);
	
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.SaveUserData.Name);
	
EndProcedure

// See JobsQueueOverridable.OnGetTemplateList.
Procedure OnGetTemplateList(JobTemplates) Export
	
	JobTemplates.Add(Metadata.ScheduledJobs.DeleteObsoleteExtensionsVersionsParameters.Name);
	JobTemplates.Add(Metadata.ScheduledJobs.FillExtensionsOperationParameters.Name);
	
EndProcedure

// See ExportImportDataOverridable.AfterImportData.
Procedure AfterImportData(Container) Export
	
	// Update the built-in profiles and add-in run parameters in the background.
	InformationRegisters.ExtensionVersionParameters.EnableFillingExtensionsWorkParameters(False, True);
	If Common.DataSeparationEnabled() Then
		InformationRegisters.ExtensionVersionParameters.StartFillingWorkParametersExtensions(
			NStr("en = 'Start and wait after importing area data';"),
			True);
	EndIf;
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "StandardSubsystemsServer.SetConstantDoNotUseSeparationByDataAreas";
	Handler.Priority = 99;
	Handler.SharedData = True;
	Handler.ExclusiveMode = True;
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "StandardSubsystemsServer.MarkVersionCacheRecordsObsolete";
	Handler.Priority = 99;
	Handler.SharedData = True;
	Handler.ExecutionMode = "Seamless";
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "InfobaseUpdateInternal.InitialFillingOfPredefinedData";
	
	Handler = Handlers.Add();
	Handler.Version = "3.1.7.149";
	Handler.Procedure = "StandardSubsystemsServer.EnableConstantToDeliverServerAlertsWithoutInteractionSystem";
	Handler.SharedData = True;
	Handler.InitialFilling = True;
	Handler.ExecutionMode = "Seamless";
	
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings
Procedure OnDefineScheduledJobSettings(Settings) Export

	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.IntegrationServicesProcessing;
	Dependence.UseExternalResources = True;
	
EndProcedure

// See SSLSubsystemsIntegration.OnDefineObjectsToExcludeFromCheck
Procedure OnDefineObjectsToExcludeFromCheck(Objects) Export
	Objects.Add(Metadata.InformationRegisters.ExtensionVersionObjectIDs);
EndProcedure

// See CommonOverridable.OnReceiptRecurringClientDataOnServer
Procedure OnReceiptRecurringClientDataOnServer(Parameters, Results) Export
	
	ParameterName = "StandardSubsystems.Core.DynamicUpdateControl";
	CheckParameters = Parameters.Get(ParameterName);
	If CheckParameters = Undefined Then
		Return;
	EndIf;
	
	// ConfigurationOrExtensionsWasModified
	UserMessage = Undefined;
	ConfigurationOrExtensionModifiedDuringRepeatedCheck(UserMessage);
	If UserMessage = Undefined Then
		Return;
	EndIf;
	
	Results.Insert(ParameterName, UserMessage);
	
EndProcedure

// See UsersOverridable.OnGetOtherSettings.
Procedure OnGetOtherSettings(UserInfo, Settings) Export
	
	CurrentSchedule = Common.SystemSettingsStorageLoad("DynamicUpdateControl",
		"PatchCheckSchedule",,,
		UserInfo.InfobaseUserName);
	If CurrentSchedule <> Undefined Then
		SettingProperties = New Structure;
		SettingProperties.Insert("SettingName1", NStr("en = 'Schedule to check for new patches';"));
		SettingProperties.Insert("PictureSettings", PictureLib.Calendar);
		SettingProperties.Insert("SettingsList", New ValueList);
		SettingProperties.SettingsList.Add(CurrentSchedule);
		Settings.Insert("PatchCheckSchedule", SettingProperties);
	EndIf;
	
EndProcedure

// See UsersOverridable.OnSaveOtherSetings.
Procedure OnSaveOtherSetings(UserInfo, Settings) Export
	
	If Settings.SettingID = "PatchCheckSchedule" Then
		If Settings.SettingValue.Count() = 1 Then
			Schedule = Settings.SettingValue[0].Value;
			
			Common.SystemSettingsStorageSave("DynamicUpdateControl", "PatchCheckSchedule",
				Schedule,,
				UserInfo.InfobaseUserName);
		EndIf;
	EndIf;
	
EndProcedure

// See UsersOverridable.OnDeleteOtherSettings.
Procedure OnDeleteOtherSettings(UserInfo, Settings) Export
	
	If Settings.SettingID = "PatchCheckSchedule" Then
		Common.SystemSettingsStorageDelete("DynamicUpdateControl",
			"PatchCheckSchedule",
			UserInfo.InfobaseUserName);
	EndIf;
	
EndProcedure

// Generates the text to be displayed to the user if dynamic update is needed.
// 
// Parameters:
//  DynamicConfigurationChanges - See Catalogs.ExtensionsVersions.DynamicallyChangedExtensions
//  
// Returns:
//  String 
//
Function MessageTextOnDynamicUpdate(DynamicConfigurationChanges) Export
	
	Messages = New Array;
	
	If DynamicConfigurationChanges.DataBaseConfigurationChangedDynamically Then
		MessageTextConfiguration = NStr("en = 'The application is updated (the infobase configuration is modified).';");
		Messages.Add(MessageTextConfiguration);
	EndIf;
	
	If DynamicConfigurationChanges.Corrections <> Undefined Then
		If DynamicConfigurationChanges.Corrections.Added2 > 0
			And DynamicConfigurationChanges.Corrections.Deleted > 0 Then
			MessageTextPatches = NStr("en = 'New patches: %1, deleted: %2.';");
		ElsIf DynamicConfigurationChanges.Corrections.Added2 = 1 Then
			MessageTextPatches = NStr("en = 'New patch.';");
		ElsIf DynamicConfigurationChanges.Corrections.Added2 > 0 Then
			MessageTextPatches = NStr("en = 'New patches: %1.';");
		ElsIf DynamicConfigurationChanges.Corrections.Deleted > 0 Then
			MessageTextPatches = NStr("en = 'Patches deleted: %2.';");
		EndIf;
		MessageTextPatches = StringFunctionsClientServer.SubstituteParametersToString(MessageTextPatches,
			DynamicConfigurationChanges.Corrections.Added2,
			DynamicConfigurationChanges.Corrections.Deleted);
		Messages.Add(MessageTextPatches);
	EndIf;
	
	If DynamicConfigurationChanges.Extensions <> Undefined Then
		If DynamicConfigurationChanges.Extensions.Added2 > 0 Then
			MessageTextExtensions = NStr("en = 'New extensions: %1.';");
			MessageTextExtensions = StringFunctionsClientServer.SubstituteParametersToString(MessageTextExtensions,
				DynamicConfigurationChanges.Extensions.Added2);
			Messages.Add(MessageTextExtensions);
		EndIf;
		
		If DynamicConfigurationChanges.Extensions.Deleted > 0 Then
			MessageTextExtensions = NStr("en = 'Extensions deleted: %1.';");
			MessageTextExtensions = StringFunctionsClientServer.SubstituteParametersToString(MessageTextExtensions,
				DynamicConfigurationChanges.Extensions.Deleted);
			Messages.Add(MessageTextExtensions);
		EndIf;
		
		If DynamicConfigurationChanges.Extensions.IsChanged > 0 Then
			MessageTextExtensions = NStr("en = 'Extensions modified: %1.';");
			MessageTextExtensions = StringFunctionsClientServer.SubstituteParametersToString(MessageTextExtensions,
				DynamicConfigurationChanges.Extensions.IsChanged);
			Messages.Add(MessageTextExtensions);
		EndIf;
	EndIf;
		
	Return StrConcat(Messages, Chars.LF);
	
EndFunction

// Determines a PDF save format depending on the platform.
// 
// Returns:
//  SpreadsheetDocumentFileType
//
Function TableDocumentFileTypePDF() Export
	
	Return SpreadsheetDocumentFileType["PDF_A_3"];
	
EndFunction

// Determines a user presentation of the PDF save format depending on the platform.
// 
// Returns:
//  String
//
Function FileTypeRepresentationOfATabularPDFDocument() Export
	
	Return NStr("en = 'PDF/A document (.pdf)';");
	
EndFunction

Function ConfigurationLanguages() Export
	
	Languages = New Array;
	For Each Language In Metadata.Languages Do
		Languages.Add(Language.LanguageCode);
	EndDo;
	
	Return Languages;
	
EndFunction

// Parameters:
//  Headers - Map - see details of the Headers parameter of the HTTPResponse object in Syntax Assistant.
// 
// Returns:
//  Map
//
Function HTTPHeadersInLowercase(Headers) Export
	
	Result = New Map;
	For Each Title In Headers Do
		Result.Insert(Lower(Title.Key), Title.Value);
	EndDo;
	Return Result;
	
EndFunction

// Parameters:
//  Id - String - an add-in ID.
//  Location - String - an add-in template location (without the version specified).
//  AddIn - Undefined
//                    - Structure - Add-in data:
//                       * Id - String - an add-in ID in the catalog.
//                       * Version - String - version.
//                       * Location - String - location.
//                       * Available - Boolean - flag of availability.
//
// Returns:
//  Structure:
//   * Id - String - an add-in ID in the catalog.
//   * Location - String - an add-in template, a reference address in the catalog.
//   * Version - String - version.
//
Function TheComponentOfTheLatestVersion(Id, Location, AddIn = Undefined) Export
		
	TheComponentOfTheLatestVersion = New Structure;
	TheComponentOfTheLatestVersion.Insert("Id", Id);
	TheComponentOfTheLatestVersion.Insert("Location", "");
	TheComponentOfTheLatestVersion.Insert("Version", "");
	
	// Information about add-in.
	If AddIn <> Undefined And AddIn.Available Then
		TheLatestVersionOfTheExternalComponent = New Structure("Version, Location", 
			AddIn.Version, AddIn.Location);
	Else
		TheLatestVersionOfTheExternalComponent = Undefined;
	EndIf;
	
	// Information about a template add-in.
	If ValueIsFilled(Location) Then
		TheLatestVersionOfComponentsFromTheLayout = StandardSubsystemsCached.TheLatestVersionOfComponentsFromTheLayout(
			Location);
	Else
		TheLatestVersionOfComponentsFromTheLayout = Undefined;
	EndIf;
	
	If TheLatestVersionOfTheExternalComponent <> Undefined And TheLatestVersionOfComponentsFromTheLayout <> Undefined Then
		
		If StringFunctionsClientServer.OnlyNumbersInString(StrReplace(TheLatestVersionOfTheExternalComponent.Version, ".",
			"")) Then
			VersionParts = StrSplit(TheLatestVersionOfTheExternalComponent.Version, ".");
			If VersionParts.Count() = 4 And CommonClientServer.CompareVersions(
				TheLatestVersionOfTheExternalComponent.Version, TheLatestVersionOfComponentsFromTheLayout.Version) <= 0 Then
				FillPropertyValues(TheComponentOfTheLatestVersion, TheLatestVersionOfComponentsFromTheLayout);
				Return TheComponentOfTheLatestVersion;
			EndIf;
		EndIf;
		
		// If the add-in version mismatches the template or exceeds the template's version, take an add-in from the catalog.
		FillPropertyValues(TheComponentOfTheLatestVersion, TheLatestVersionOfTheExternalComponent);
		Return TheComponentOfTheLatestVersion;
		
	ElsIf TheLatestVersionOfComponentsFromTheLayout <> Undefined Then
		FillPropertyValues(TheComponentOfTheLatestVersion, TheLatestVersionOfComponentsFromTheLayout);
		Return TheComponentOfTheLatestVersion;
	ElsIf TheLatestVersionOfTheExternalComponent <> Undefined Then
		FillPropertyValues(TheComponentOfTheLatestVersion, TheLatestVersionOfTheExternalComponent);
		Return TheComponentOfTheLatestVersion;
	EndIf;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Add-in with ID %1 does not exist';"), Id);
	
EndFunction

// Returns:
//  String -  Technical information about the subsystem versions and extensions.
//
Function TechnicalInfoOnExtensionsAndSubsystemsVersions() Export
	
	SubsystemsDetails = Common.SubsystemsDetails();
	
	TechnicalInfoOnExtensionsAndSubsystemsVersions = NStr("en = 'Subsystem versions';") + ":" + Chars.LF;
	For Each SubsystemDetails In SubsystemsDetails Do
		TechnicalInfoOnExtensionsAndSubsystemsVersions = TechnicalInfoOnExtensionsAndSubsystemsVersions
			+ SubsystemDetails.Name + " - "
			+ SubsystemDetails.Version + Chars.LF;
	EndDo;
		
	TechnicalInfoOnExtensionsAndSubsystemsVersions = TechnicalInfoOnExtensionsAndSubsystemsVersions + Chars.LF;
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	Extensions = ConfigurationExtensions.Get();
	For Each Extension In Extensions Do
		
		TechnicalInfoOnExtensionsAndSubsystemsVersions = TechnicalInfoOnExtensionsAndSubsystemsVersions
			+ Extension.Name + " - " + Extension.Synonym + " - "
			+ Format(Extension.Active, NStr("en = 'BF=Disabled; BT=Enabled';")) + Chars.LF;
		
	EndDo;
	
	Return TechnicalInfoOnExtensionsAndSubsystemsVersions;
	
EndFunction

#EndRegion

#Region Private

// The procedure is a handler for the event of the same name that occurs during data exchange in a distributed
// infobase.
//
// Parameters:
//   see the OnSendDataToMaster() event handler details in the syntax assistant.
// 
Procedure OnSendDataToMaster(DataElement, ItemSend, Val Recipient)
	
	If ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
	
	// Metadata object IDs are sent in another exchange message section.
	IgnoreSendingMetadataObjectIDs(DataElement, ItemSend);
	If ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
	
	SSLSubsystemsIntegration.OnSendDataToMaster(DataElement, ItemSend, Recipient);
	
	// Calling an overridden handler to execute the applied logic of DIB exchange.
	CommonOverridable.OnSendDataToMaster(DataElement, ItemSend, Recipient);
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.CalculateDIBDataExportPercentage(Recipient, False);
	EndIf;
	
EndProcedure

// Returns a parameter structure required for this subsystem
// client script execution when the application starts, that is in following event handlers.
// - BeforeStart,
// - OnStart.
//
// Important: when starting the application, do not use cache
// reset commands of modules that reuse return values as this can lead to
// unpredictable errors and unnecessary service calls.
//
// Parameters:
//   Parameters   - Structure - a parameter structure.
//
// Returns:
//   Boolean   - False if further parameters filling should be aborted.
//
Function AddClientParametersOnStart(Parameters) Export
	
	IsCallBeforeStart = Parameters.RetrievedClientParameters <> Undefined;
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		IsSeparatedConfiguration = ModuleSaaSOperations.IsSeparatedConfiguration();
	Else
		IsSeparatedConfiguration = False;
	EndIf;
	
	// Mandatory parameters to continue application running.
	Parameters.Insert("DataSeparationEnabled", Common.DataSeparationEnabled());
	Parameters.Insert("SeparatedDataUsageAvailable", 
		Common.SeparatedDataUsageAvailable());
	Parameters.Insert("IsSeparatedConfiguration", IsSeparatedConfiguration);
	// Obsolete. Kept for backward compatibility. Use UsersClient.IsFullUser instead.
	Parameters.Insert("HasAccessForUpdatingPlatformVersion", Users.IsFullUser(,True));
	
	Parameters.Insert("SubsystemsNames", StandardSubsystemsCached.SubsystemsNames());
	Parameters.Insert("IsBaseConfigurationVersion", IsBaseConfigurationVersion());
	Parameters.Insert("IsTrainingPlatform", IsTrainingPlatform());
	Parameters.Insert("UserCurrentName", CurrentUser().Name);
	// Obsolete. Kept for backward compatibility. Use CommonClientServer.COMConnectorName instead.
	Parameters.Insert("COMConnectorName", CommonClientServer.COMConnectorName());
	Parameters.Insert("DefaultLanguageCode", Common.DefaultLanguageCode());
	
	UserSettings = ErrorProcessing.GetUserSettings();
	Parameters.Insert("ErrorInfoSendingSettings",
		New Structure("SendOutMode, SendOutAddress",
			UserSettings.SendReport,
			UserSettings.ErrorProcessingServiceAddress));
	
	Parameters.Insert("AskConfirmationOnExit", AskConfirmationOnExit());
	
	CommonParameters = Common.CommonCoreParameters();
	Parameters.Insert("MinPlatformVersion",   CommonParameters.MinPlatformVersion);
	Parameters.Insert("RecommendedPlatformVersion", CommonParameters.RecommendedPlatformVersion);
	// Obsolete. Kept for backward compatibility. Use the two previous parameters instead.
	Parameters.Insert("MinPlatformVersion1", CommonParameters.MinPlatformVersion1);
	Parameters.Insert("MustExit",            CommonParameters.MustExit);
	
	Parameters.Insert("RecommendedRAM", CommonParameters.RecommendedRAM);
	Parameters.Insert("MustShowRAMSizeRecommendations", MustShowRAMSizeRecommendations()
		And Not Common.SubsystemExists("StandardSubsystems.ToDoList"));
	
	Parameters.Insert("IsExternalUserSession", Users.IsExternalUserSession());
	Parameters.Insert("IsFullUser",  Users.IsFullUser());
	Parameters.Insert("IsSystemAdministrator",      Users.IsFullUser(, True));
	Parameters.Insert("FileInfobase",   Common.FileInfobase());
	
	If InvalidPlatformVersionUsed() Then
		Parameters.Insert("InvalidPlatformVersionUsed");
	EndIf;
	
	If IsCallBeforeStart Then
		Parameters.Insert("StyleItems", StyleElementsSet());
	EndIf;
	
	If IsCallBeforeStart
	   And Not Parameters.RetrievedClientParameters.Property("InterfaceOptions") Then
		Parameters.Insert("InterfaceOptions", StandardSubsystemsCached.InterfaceOptions());
	EndIf;
	
	If IsCallBeforeStart Then
		ErrorInsufficientRightsForAuthorization = UsersInternal.ErrorInsufficientRightsForAuthorization(
			Not Parameters.RetrievedClientParameters.Property("ErrorInsufficientRightsForAuthorization"));
		
		If ValueIsFilled(ErrorInsufficientRightsForAuthorization) Then
			Parameters.Insert("ErrorInsufficientRightsForAuthorization", ErrorInsufficientRightsForAuthorization);
			Return False;
		EndIf;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		
		ModuleWorkLockWithExternalResources = Common.CommonModule("ExternalResourcesOperationsLock");
		ModuleWorkLockWithExternalResources.OnAddClientParametersOnStart(
			Parameters, IsCallBeforeStart);
		
		If ScheduledJobsServer.OperationsWithExternalResourcesLocked() Then
			Parameters.Insert("OperationsWithExternalResourcesLocked");
		EndIf;
		
	EndIf;
	
	If Not InfobaseUpdateInternal.AddClientParametersOnStart(Parameters)
	   And IsCallBeforeStart Then
		Return False;
	EndIf;
	
	If IsCallBeforeStart
	   And Not Parameters.RetrievedClientParameters.Property("ShowDeprecatedPlatformVersion")
	   And ShowDeprecatedPlatformVersion(Parameters) Then
		
		Parameters.Insert("ShowDeprecatedPlatformVersion");
		StandardSubsystemsServerCall.HideDesktopOnStart();
		Return False;
	EndIf;
	
	If IsCallBeforeStart
	   And Not Parameters.RetrievedClientParameters.Property("ReconnectMasterNode")
	   And Not Common.DataSeparationEnabled() Then
	   
		SetPrivilegedMode(True);
		ReconnectMasterNode = ExchangePlans.MasterNode() = Undefined
			And ValueIsFilled(Constants.MasterNode.Get());
		SetPrivilegedMode(False);
	   
		If ReconnectMasterNode Then 
			Parameters.Insert("ReconnectMasterNode", Users.IsFullUser(, True));
			StandardSubsystemsServerCall.HideDesktopOnStart();
			Return False;
		EndIf;
	EndIf;
	
	If IsCallBeforeStart
	   And Not Parameters.RetrievedClientParameters.Property("ServerNotifications") Then
		
		ServerNotifications.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	If IsCallBeforeStart
	   And Not Parameters.RetrievedClientParameters.Property("SelectInitialRegionalIBSettings")
	   And RegionalInfobaseSettingsRequired() Then
		
		Parameters.Insert("SelectInitialRegionalIBSettings",
			Users.IsFullUser(, True, False));
		StandardSubsystemsServerCall.HideDesktopOnStart();
		Return False;
	EndIf;
	
	If IsCallBeforeStart And Common.SubsystemExists("CloudTechnology") Then
		
		ErrorDescription = "";
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		ModuleSaaSOperations.OnCheckDataAreaLockOnStart(ErrorDescription);
		If Not IsBlankString(ErrorDescription) Then
			Parameters.Insert("DataAreaLocked", ErrorDescription);
			// Application will be closed.
			Return False;
		EndIf;
		
	EndIf;
	
	If SessionParameters.IBUpdateInProgress <> Undefined // Mandatory initialization of the session parameters.
		And Not Parameters.DataSeparationEnabled
		And InfobaseUpdate.InfobaseUpdateRequired()
		And InfobaseUpdateInternal.UncompletedHandlersStatus(True) = "UncompletedStatus" Then
		Parameters.Insert("MustRunDeferredUpdateHandlers");
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
		ModuleSafeModeManagerInternal.OnAddClientParametersOnStart(Parameters, True);
	EndIf;
	
	If IsCallBeforeStart
	   And Not Parameters.RetrievedClientParameters.Property("RetryDataExchangeMessageImportBeforeStart")
	   And Common.IsSubordinateDIBNode()
	   And Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		ModuleDataExchangeInternal = Common.CommonModule("DataExchangeInternal");
		If ModuleDataExchangeInternal.RetryDataExchangeMessageImportBeforeStart() Then
			Parameters.Insert("RetryDataExchangeMessageImportBeforeStart");
			Return False;
		EndIf;
	EndIf;
	
	// Checking whether preliminary application parameter update is required.
	If IsCallBeforeStart
	   And Not Parameters.RetrievedClientParameters.Property("ApplicationParametersUpdateRequired")
	   And Not Parameters.Property("SimplifiedInfobaseUpdateForm") Then
		
		SubordinateDIBNodeSetup = False;
		If InformationRegisters.ApplicationRuntimeParameters.UpdateRequired1(SubordinateDIBNodeSetup) Then
			// Preliminary update will be executed.
			Parameters.Insert("ApplicationParametersUpdateRequired");
			
			If SubordinateDIBNodeSetup
			   And Common.FileInfobase() Then
				
				ErrorTemplate =
					NStr("en = 'Cannot enable exclusive mode to set up the distributed infobase node. Reason:
					           |%1';");
				EnableExclusiveModeAtStartup(True, ErrorTemplate);
			EndIf;
			Return False;
		EndIf;
	EndIf;
	
	// Mandatory parameters for all modes.
	Parameters.Insert("DetailedInformation", Metadata.DetailedInformation);
	
	If InfobaseUpdateInternal.SharedInfobaseDataUpdateRequired() Then
		Parameters.Insert("SharedInfobaseDataUpdateRequired");
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
		ModuleSafeModeManagerInternal.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	If Not Parameters.SeparatedDataUsageAvailable Then
		Return True;
	EndIf;
	
	// Parameters for the hosted mode and
	// for sessions in the SaaS mode with separators.
	
	If InfobaseUpdate.InfobaseUpdateRequired() Then
		Parameters.Insert("InfobaseUpdateRequired");
		StandardSubsystemsServerCall.HideDesktopOnStart();
	EndIf;
	
	If Not Parameters.DataSeparationEnabled
		And Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		If ModuleDataExchangeServer.LoadDataExchangeMessage() Then
			Parameters.Insert("LoadDataExchangeMessage");
		EndIf;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleStandaloneMode = Common.CommonModule("StandaloneMode");
		If ModuleStandaloneMode.ContinueStandaloneWorkstationSetup(Parameters) Then
			Return False;
		EndIf;
	EndIf;
	
	Cancel = False;
	If IsCallBeforeStart Then
		UsersInternal.OnAddClientParametersOnStart(Parameters, Cancel, True);
	EndIf;
	If Cancel Then
		Return False;
	EndIf;
	
	AddCommonClientParameters(Parameters);
	
	If IsCallBeforeStart
	   And (Parameters.Property("InfobaseUpdateRequired")
	      Or InfobaseUpdate.InfobaseUpdateInProgress()) Then
		// Do not add the other parameters until the update is completed
		// as those parameters may assume that the infobase is updated.
		Return False;
	EndIf;
	
	EnableExclusiveModeAtStartup(False);
	
	Return True;
	
EndFunction

// Fills a parameter structure required for this subsystem
// client script execution. 
//
// Parameters:
//   Parameters - Structure
//
Procedure AddClientRunParameters(Parameters)
	
	Parameters.Insert("SubsystemsNames", StandardSubsystemsCached.SubsystemsNames());
	Parameters.Insert("SeparatedDataUsageAvailable",
		Common.SeparatedDataUsageAvailable());
	Parameters.Insert("DataSeparationEnabled", Common.DataSeparationEnabled());
	
	// Outdated. Use StandardSubsystemsClient.IsBaseConfigurationVersion instead.
	Parameters.Insert("IsBaseConfigurationVersion", IsBaseConfigurationVersion());
	// Outdated. Use StandardSubsystemsClient.IsTrainingPlatform instead.
	Parameters.Insert("IsTrainingPlatform", IsTrainingPlatform());
	// Obsolete. Use UsersClientServer.COMConnectorName instead.
	Parameters.Insert("COMConnectorName", CommonClientServer.COMConnectorName());
	Parameters.Insert("StyleItems", StyleElementsSet());
	
	AddCommonClientParameters(Parameters);
	
	Parameters.Insert("ConfigurationName",     Metadata.Name);
	Parameters.Insert("ConfigurationSynonym", Metadata.Synonym);
	Parameters.Insert("ConfigurationVersion",  Metadata.Version);
	Parameters.Insert("DetailedInformation", Metadata.DetailedInformation);
	Parameters.Insert("DefaultLanguageCode",   Common.DefaultLanguageCode());
	
	Parameters.Insert("AskConfirmationOnExit",
		AskConfirmationOnExit());
	
	Parameters.Insert("FileInfobase", Common.FileInfobase());
	
	If ScheduledJobsServer.OperationsWithExternalResourcesLocked() Then
		Parameters.Insert("OperationsWithExternalResourcesLocked");
	EndIf;
	
	Parameters.Insert("CompatibilityModeVersion", CompatibilityModeVersion());
	
EndProcedure

// Fills a structure parameters required for client script execution when
// starting the application and later. 
//
// Parameters:
//   Parameters   - Structure - a parameter structure.
//
Procedure AddCommonClientParameters(Parameters)
	
	If Not Parameters.DataSeparationEnabled Or Parameters.SeparatedDataUsageAvailable Then
		
		SetPrivilegedMode(True);
		Parameters.Insert("AuthorizedUser", Users.AuthorizedUser());
		Parameters.Insert("ApplicationCaption", TrimAll(Constants.SystemTitle.Get()));
		SetPrivilegedMode(False);
		
	EndIf;
	
	Parameters.Insert("IsMasterNode1", Not Common.IsSubordinateDIBNode());
	
	Parameters.Insert("DIBNodeConfigurationUpdateRequired",
		Common.SubordinateDIBNodeConfigurationUpdateRequired());
	
EndProcedure

// Returns the version numbers supported by the InterfaceName application interface.
// See Common.GetInterfaceVersionsViaExternalConnection.
//
// Parameters:
//   InterfaceName - String - an application interface name.
//
// Returns:
//  Array - a list of versions of the String type.
//
Function SupportedVersions(InterfaceName) Export
	
	VersionsArray = Undefined;
	SupportedVersionsStructure = New Structure;
	
	SSLSubsystemsIntegration.OnDefineSupportedInterfaceVersions(SupportedVersionsStructure);
	SupportedVersionsStructure.Property(InterfaceName, VersionsArray);
	
	If VersionsArray = Undefined Then
		Return Common.ValueToXMLString(New Array);
	Else
		Return Common.ValueToXMLString(VersionsArray);
	EndIf;
	
EndFunction

// Sets the BlankHomePage common form on the desktop.
Procedure SetBlankFormOnHomePage() Export
	
	ObjectKey = "Common/HomePageSettings";
	CurrentSettings = SystemSettingsStorage.Load(ObjectKey);
	
	If TypeOf(CurrentSettings) = Type("HomePageSettings") Then
		CurrentFormComposition = CurrentSettings.GetForms();
		If CurrentFormComposition.RightColumn.Count() = 0
		   And CurrentFormComposition.LeftColumn.Count() = 1
		   And CurrentFormComposition.LeftColumn[0] = "CommonForm.BlankHomePage" Then
			Return;
		EndIf;
	EndIf;
	
	FormContent = New HomePageForms;
	FormContent.LeftColumn.Add("CommonForm.BlankHomePage");
	Settings = New HomePageSettings;
	Settings.SetForms(FormContent);
	SystemSettingsStorage.Save(ObjectKey, "", Settings);
	
EndProcedure

// Parameters:
//  Set - Boolean
//  ErrorTemplate - String
//
Procedure EnableExclusiveModeAtStartup(Set, ErrorTemplate = "")
	
	If Set And ExclusiveMode() Then
		Return;
	EndIf;
	
	ParameterName = "IsExclusiveModeEnabledAtStartup";
	
	SetPrivilegedMode(True);
	If Set Then
		Try
			SetExclusiveMode(True);
		Except
			ErrorInfo = ErrorInfo();
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
				ErrorProcessing.BriefErrorDescription(ErrorInfo));
			Raise ErrorText;
		EndTry;
		
		CurrentParameters = New Map(SessionParameters.ClientParametersAtServer);
		CurrentParameters.Insert(ParameterName, True);
		SessionParameters.ClientParametersAtServer = New FixedMap(CurrentParameters);
		
	ElsIf SessionParameters.ClientParametersAtServer.Get(ParameterName) <> Undefined Then
		
		If ExclusiveMode() Then
			SetExclusiveMode(False);
		EndIf;
		
		CurrentParameters = New Map(SessionParameters.ClientParametersAtServer);
		CurrentParameters.Insert(ParameterName, True);
		SessionParameters.ClientParametersAtServer = New FixedMap(CurrentParameters);
	EndIf;
	SetPrivilegedMode(False);
	
EndProcedure

// The handler of the scheduled job with the same name.
//
Procedure IntegrationServicesProcessing() Export
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.IntegrationServicesProcessing);
	
	If Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	IntegrationServices.ExecuteProcessing();
EndProcedure

// Parameters:
//  UserName - String
//
// Returns:
//  Boolean
//
Function ShowWarningAboutInstalledUpdatesForUser(UserName = Undefined)
	
	Result = Common.CommonSettingsStorageLoad(
		"UserCommonSettings", 
		"ShowInstalledApplicationUpdatesWarning",,,
		UserName);
	
	If Result = Undefined Then
		Result = True;
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Sets constants DoNotUseSeparationByDataAreas and StandardSubsystemsStandaloneMode.
// The constant values depend on the value of UseSeparationByDataAreas. 
//
Procedure SetConstantDoNotUseSeparationByDataAreas(Parameters) Export
	
	NewValues = New Map;
	If Constants.UseSeparationByDataAreas.Get() Then
		NewValues.Insert("NotUseSeparationByDataAreas", False);
		NewValues.Insert("StandardSubsystemsStandaloneMode", False);
	ElsIf Common.IsStandaloneWorkplace() Then
		NewValues.Insert("NotUseSeparationByDataAreas", False);
		NewValues.Insert("StandardSubsystemsStandaloneMode", True);
	Else
		NewValues.Insert("NotUseSeparationByDataAreas", True);
		NewValues.Insert("StandardSubsystemsStandaloneMode", False);
	EndIf;
	
	ThisDataExchangeInServiceModel = Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS");
	For Each NewValue In NewValues Do
		
		If ThisDataExchangeInServiceModel 
			And NewValue.Key = "StandardSubsystemsStandaloneMode" Then
			PreviousValue = Common.IsStandaloneWorkplace();
			// Always sync constant StandardSubsystemsStandaloneMode with IsStandaloneWorkplace. 
			Constants[NewValue.Key].Set(NewValue.Value); 
		Else
			PreviousValue = Constants[NewValue.Key].Get();
		EndIf;
		
		If PreviousValue <> NewValue.Value Then
				
			If Not Parameters.ExclusiveMode Then
				Parameters.ExclusiveMode = True;
				Return; // Set the exclusive mode to change the value.
			EndIf;
				
			Constants[NewValue.Key].Set(NewValue.Value);
			
			If ThisDataExchangeInServiceModel
				And NewValue.Key = "StandardSubsystemsStandaloneMode" 
				And PreviousValue Then
				ModuleStandaloneMode = Common.CommonModule("StandaloneMode");
				ModuleStandaloneMode.DisablePropertyIB();
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Clears update date for each version cache record, so
// all version cache records become out-of-date.
//
Procedure MarkVersionCacheRecordsObsolete() Export
	
	BeginTransaction();
	Try
		RecordSet = InformationRegisters.ProgramInterfaceCache.CreateRecordSet();
		
		Block = New DataLock;
		Block.Add("InformationRegister.ProgramInterfaceCache");
		Block.Lock();
		
		RecordSet.Read();
		For Each Record In RecordSet Do
			Record.UpdateDate = Undefined;
		EndDo;
		
		InfobaseUpdate.WriteData(RecordSet);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure EnableConstantToDeliverServerAlertsWithoutInteractionSystem() Export
	
	Constants.DeliverServerNotificationsWithoutCollaborationSystem.Set(True);
	
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming.
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	OldName = "Role.BasicAccess";
	NewName  = "Role.BasicAccessSSL";
	Common.AddRenaming(Total, "3.0.1.19", OldName, NewName, Library);
	
	OldName = "Role.BasicAccessExternalUser";
	NewName  = "Role.BasicAccessExternalUserSSL";
	Common.AddRenaming(Total, "3.0.1.19", OldName, NewName, Library);
	
	OldName = "Role.AllFunctionsMode";
	NewName  = "Role.TechnicianMode";
	Common.AddRenaming(Total, "3.1.5.153", OldName, NewName, Library);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// "BeforeWrite" event handler for predefined items.
//
Procedure ProcessPredefinedItemsBeforeWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ThisIsPredefinedData(Source) Then
		Return;
	EndIf;
	
	DenySettingDeletionMarksToPredefinedItemsBeforeWrite(Source);
	
	InfobaseUpdateInternal.DetermineModifiedAttributesInPredefinedItems(Source);
	
EndProcedure

// Predefined item BeforeWrite event handler.
//
Procedure DenySettingDeletionMarksToPredefinedItemsBeforeWrite(Source)
	
	If Source.DeletionMark <> True Then
		Return;
	EndIf;
	
	AttributeName = "";
	AttributeValue = "";
	If Not ThisIsPredefinedData(Source, AttributeName, AttributeValue) Then
		Return;
	EndIf;
	
	If Source.IsNew() Then
		Raise
			NStr("en = 'Cannot create a predefined item that is marked for deletion.';");
	EndIf;
	
	PreviousProperties = Common.ObjectAttributesValues(Source.Ref, 
		"DeletionMark, PredefinedDataName" 
			+ ?(AttributeName <> "PredefinedDataName", ", " + AttributeName, ""));
	
	If (PreviousProperties.PredefinedDataName <> "" Or AttributeName <> "" And ValueIsFilled(PreviousProperties[AttributeName]))
	   And PreviousProperties.DeletionMark <> True And Not IsOwnerMarkedForDeletion(Source.Ref) Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot mark the predefined item for deletion:
			           |""%1.""';"),
			String(Source.Ref));
	ElsIf (ValueIsFilled(AttributeValue) And Not ValueIsFilled(PreviousProperties[AttributeName])
	      Or PreviousProperties.PredefinedDataName = "")
	        And PreviousProperties.DeletionMark = True Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot map a predefined item name to an item marked for deletion:
			           |""%1.""';"),
			String(Source.Ref));
	EndIf;
	
EndProcedure

// Predefined item BeforeDelete event handler.
Procedure DenyPredefinedItemDeletionBeforeDelete(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ThisIsPredefinedData(Source) Then
		Return;
	EndIf;
	
	AttributesValues = New Structure("Owner");
	FillPropertyValues(AttributesValues, Source);
	
	If ValueIsFilled(AttributesValues.Owner) Then
		OwnerDetailsValues = New Structure("DeletionMark");
		OwnerDeletionMark = Common.ObjectAttributeValue(AttributesValues.Owner, "DeletionMark");
		If OwnerDeletionMark <> False Then // Undefined if the owner is deleted.
			Return;
		EndIf;
	EndIf;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot delete the predefined item 
			|""%1.""';"),
		String(Source.Ref));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// DIB exchange plan event subscription processing.

// The procedure handles the same-name event that occurs during data exchange in a distributed infobase.
// For parameters, see "OnSendDataToSubordinate" in Syntax Assistant.
// 
// 
// Parameters:
//  Source - ExchangePlanObject
//  DataElement - Arbitrary
//  ItemSend - DataItemSend
//  InitialImageCreating - Boolean
// 
Procedure OnSendDataToSubordinateEvent(Source, DataElement, ItemSend, InitialImageCreating) Export
	
	OnSendDataToSlave(DataElement, ItemSend, InitialImageCreating, Source);
	
	If ItemSend <> DataItemSend.Ignore Then
		// Calling an overridden handler to execute the applied logic of DIB exchange.
		CommonOverridable.OnSendDataToSlave(Source, DataElement, ItemSend, InitialImageCreating);
	EndIf;
	
EndProcedure

// Procedure handles the same-name event that occurs during data exchange in a distributed infobase.
// For parameters, see the "OnSendDataToMaster" event handler in Syntax Assistant.
// 
// 
// Parameters:
//  Source - ExchangePlanObject
//  DataElement - Arbitrary
//  ItemSend - DataItemSend
//  
Procedure OnSendDataToMasterEvent(Source, DataElement, ItemSend) Export
	
	OnSendDataToMaster(DataElement, ItemSend, Source);
	
	If ItemSend <> DataItemSend.Ignore Then
		// Calling an overridden handler to execute the applied logic of DIB exchange.
		CommonOverridable.OnSendDataToMaster(Source, DataElement, ItemSend);
	EndIf;
	
EndProcedure

// The procedure handles the same-name event that occurs during data exchange in a distributed infobase.
// For the parameters, see "OnSendDataToSubordinate" in Syntax Assistant.
// 
// 
// Parameters:
//  Source - ExchangePlanObject
//  DataElement - Arbitrary
//  ItemReceive - DataItemReceive
//  SendBack - Boolean
// 
Procedure OnReceiveDataFromSubordinateEvent(Source, DataElement, ItemReceive, SendBack) Export
	
	OnReceiveDataFromSlave(DataElement, ItemReceive, SendBack, Source);
	
	If ItemReceive <> DataItemReceive.Ignore Then
		// Calling an overridden handler to execute the applied logic of DIB exchange.
		CommonOverridable.OnReceiveDataFromSlave(Source, DataElement, ItemReceive, SendBack);
	EndIf;
	
EndProcedure

// Procedure handles the same-name event that occurs during data exchange in a distributed infobase.
// See the "OnReceiveDataFromMaster" event handler in Syntax Assistant.
// 
// 
// Parameters:
//  Source - ExchangePlanObject
//  DataElement - Arbitrary
//  ItemReceive - DataItemReceive
//  SendBack - Boolean
//
Procedure OnReceiveDataFromMasterEvent(Source, DataElement, ItemReceive, SendBack) Export
	
	OnReceiveDataFromMaster(DataElement, ItemReceive, SendBack, Source);
	
	If ItemReceive <> DataItemReceive.Ignore Then
		// Calling an overridden handler to execute the applied logic of DIB exchange.
		CommonOverridable.OnReceiveDataFromMaster(Source, DataElement, ItemReceive, SendBack);
	EndIf;
	
EndProcedure

// WriteBefore event subscription handler for ExchangePlanObject.
// Is used for calling the AfterReceiveData event handler when exchanging in DIB.
// 
// Parameters:
//  Source - ExchangePlanObject
//  Cancel - Boolean
//
Procedure AfterGetData(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Source.Metadata().DistributedInfoBase Then
		Return;
	EndIf;
	
	If Source.IsNew()
		Or Source.ReceivedNo = Common.ObjectAttributeValue(Source.Ref, "ReceivedNo") Then
		Return;
	EndIf;
	
	GetFromMasterNode = (ExchangePlans.MasterNode() = Source.Ref);
	SSLSubsystemsIntegration.AfterGetData(Source, Cancel, GetFromMasterNode);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

// Returns:
//  Array of MetadataObject
//
Function MetadataObjectsOfAllPredefinedData()
	
	DataSeparationEnabled  = Common.DataSeparationEnabled();
	IsSeparatedSession = Common.SeparatedDataUsageAvailable();
	
	MetadataCollections = New Array;
	MetadataCollections.Add(Metadata.Catalogs);
	MetadataCollections.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollections.Add(Metadata.ChartsOfAccounts);
	MetadataCollections.Add(Metadata.ChartsOfCalculationTypes);
	
	MetadataObjects = New Array;
	
	For Each Collection In MetadataCollections Do
		For Each MetadataObject In Collection Do
			
			If DataSeparationEnabled Then 
				
				ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
				IsSeparatedMetadataObject = ModuleSaaSOperations.IsSeparatedMetadataObject(MetadataObject);
				
				If (   IsSeparatedSession And Not IsSeparatedMetadataObject)
				 Or (Not IsSeparatedSession And    IsSeparatedMetadataObject) Then 
					Continue;
				EndIf;
				
			EndIf;
			
			MetadataObjects.Add(MetadataObject);
		EndDo;
	EndDo;
	
	Return MetadataObjects;
	
EndFunction

Procedure SetAllPredefinedDataInitialization(MetadataObjects)
	
	DataSeparationEnabled  = Common.DataSeparationEnabled();
	IsSeparatedSession = Common.SeparatedDataUsageAvailable();
	
	For Each MetadataObject In MetadataObjects Do
		Manager = Common.ObjectManagerByFullName(MetadataObject.FullName());
		Manager.SetPredefinedDataInitialization(True);
	EndDo;
	
	If Not DataSeparationEnabled Or Not IsSeparatedSession Then 
		SetInfoBasePredefinedDataUpdate(PredefinedDataUpdate.Auto);
	EndIf;
	
EndProcedure

Procedure CreateMissingPredefinedData(MetadataObjects)
	
	Query = New Query;
	QueryText =
		"SELECT
		|	SpecifiedTableAlias.Ref AS Ref,
		|	SpecifiedTableAlias.DataVersion AS DataVersion,
		|	ISNULL(SpecifiedTableAlias.Parent.PredefinedDataName, """") AS ParentName,
		|	SpecifiedTableAlias.PredefinedDataName AS Name
		|FROM
		|	&CurrentTable AS SpecifiedTableAlias
		|WHERE
		|	SpecifiedTableAlias.Predefined";
	
	SavedItemsDescriptions = New Array;
	TablesWithoutSavedData = New Array;
	For Each MetadataObject In MetadataObjects Do
		
		If MetadataObject.PredefinedDataUpdate
				= Metadata.ObjectProperties.PredefinedDataUpdate.DontAutoUpdate Then
			Continue;
		EndIf;
		
		FullName = MetadataObject.FullName();
		Query.Text = StrReplace(QueryText, "&CurrentTable", FullName);
		
		If Metadata.ChartsOfAccounts.Contains(MetadataObject)
		 Or Metadata.ChartsOfCalculationTypes.Contains(MetadataObject)
		 Or Not MetadataObject.Hierarchical Then
			
			Query.Text = StrReplace(Query.Text,
				"ISNULL(SpecifiedTableAlias.Parent.PredefinedDataName, """")", """""");
		EndIf;
		
		// ACC:1328-off - No.648.1.1. An exclusive lock is set in the calling procedure.
		// @skip-check query-in-loop - Batch-wise data processing
		NameTable = Query.Execute().Unload();
		// ACC:1328-on.
		NameTable.Indexes.Add("Name");
		Names = MetadataObject.GetPredefinedNames();
		SaveExistingPredefinedObjectsBeforeCreateMissingOnes(MetadataObject,
			FullName, NameTable, Names, Query, SavedItemsDescriptions, TablesWithoutSavedData);
	EndDo;
	
	// Restoring predefined items that were before the initialization.
	For Each SavedItemsDescription In SavedItemsDescriptions Do
		Manager = Common.ObjectManagerByFullName(SavedItemsDescription.FullName);
		Manager.SetPredefinedDataInitialization(False);
		InitializePredefinedData();
		
		Query.Text = SavedItemsDescription.QueryText;
		// ACC:1328-off - No.648.1.1. An exclusive lock is set in the calling procedure.
		// @skip-check query-in-loop - Batch-wise data processing
		NameTable = Query.Execute().Unload();
		// ACC:1328-on.
		NameTable.Indexes.Add("Name");
		For Each SavedItemDescription In SavedItemsDescription.NameTable Do
			If Not SavedItemDescription.ObjectExist Then
				Continue;
			EndIf;
			String = NameTable.Find(SavedItemDescription.Name, "Name");
			If String <> Undefined Then
				NewObject = String.Ref.GetObject();
				If SavedItemsDescription.IsChartOfAccounts Then
					If SavedItemDescription.Object.DataVersion <> String.DataVersion Then
						UpdateTheInvoiceObject(SavedItemDescription.Object);
					EndIf;
					AddNewExtraAccountDimensionTypes(SavedItemDescription.Object, NewObject);
				EndIf;
				// ACC:1327-off - #648.1.1. An exclusive lock is set in the caller procedure.
				InfobaseUpdate.DeleteData(NewObject);
				// ACC:1327-off.
				String.Name = "";
			EndIf;
			// ACC:1327-off - #648.1.1. An exclusive lock is set in the caller procedure.
			InfobaseUpdate.WriteData(SavedItemDescription.Object);
			// ACC:1327-off.
		EndDo;
		For Each TableRow In NameTable Do
			If Not ValueIsFilled(TableRow.Name)
			 Or Not ValueIsFilled(TableRow.ParentName) Then
				Continue;
			EndIf;
			ParentLevelRow = DetailsOfSavedObject(SavedItemsDescription.NameTable, TableRow.ParentName);
			If ParentLevelRow <> Undefined Then
				NewObject = TableRow.Ref.GetObject();
				NewObject.Parent = ParentLevelRow.Ref;
				// ACC:1327-off - #648.1.1. An exclusive lock is set in the caller procedure.
				InfobaseUpdate.WriteData(NewObject);
				// ACC:1327-off.
			EndIf;
		EndDo;
	EndDo;
	
	For Each FullName In TablesWithoutSavedData Do
		Manager = Common.ObjectManagerByFullName(FullName);
		Manager.SetPredefinedDataInitialization(False);
	EndDo;
	
	InitializePredefinedData();
	
EndProcedure

// Returns:
//  ValueTableRow:
//    * Ref - CatalogRef,
//             - ChartOfCharacteristicTypesRef
//             - ChartOfAccountsRef
//             - ChartOfCalculationTypesRef
//    * Name - String
//    * DataVersion- String
//    * ParentName - String
//    * Object - CatalogObject
//             - ChartOfCharacteristicTypesObject
//             - ChartOfAccountsObject
//             - ChartOfCalculationTypesObject
//    * ObjectExist - Boolean
//  Undefined
//
Function DetailsOfSavedObject(NameTable, ParentName)
	Return NameTable.Find(ParentName, "Name");
EndFunction

// Parameters:
//  OldObject - ChartOfAccountsObject
//
Procedure UpdateTheInvoiceObject(OldObject)
	
	NewObject = OldObject.Ref.GetObject();
	NewObject.PredefinedDataName = OldObject.PredefinedDataName;
	For Each ExtraDimensionKindRow In OldObject.ExtDimensionTypes Do
		If ExtraDimensionKindRow.Predefined Then
			NewLineIExtDimensionType = NewObject.ExtDimensionTypes.Find(
				ExtraDimensionKindRow.ExtDimensionType, "ExtDimensionType");
			If NewLineIExtDimensionType <> Undefined Then
				NewLineIExtDimensionType.Predefined = True;
			EndIf;
		EndIf;
	EndDo;
	
	OldObject = NewObject;
	
EndProcedure

// Parameters:
//  Account - ChartOfAccountsObject
//  SampleAccount - ChartOfAccountsObject
// 
Procedure AddNewExtraAccountDimensionTypes(Account, SampleAccount)
	
	For Each ExtDimensionType In SampleAccount.ExtDimensionTypes Do
		IndexOf = SampleAccount.ExtDimensionTypes.IndexOf(ExtDimensionType);
		If Account.ExtDimensionTypes.Count() > IndexOf Then
			If Account.ExtDimensionTypes[IndexOf].ExtDimensionType <> ExtDimensionType.ExtDimensionType Then
				WriteLogEvent(
					NStr("en = 'Data exchange.Disconnection from the master node';", Common.DefaultLanguageCode()),
					EventLogLevel.Error,
					Account.Metadata(),
					Account,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The extra dimension #%2 ""%3"" in chart of accounts ""%1"" does not match the predefined extra dimension ""%4.""';"),
						String(Account),
						IndexOf + 1,
						String(Account.ExtDimensionTypes[IndexOf].ExtDimensionType),
						String(ExtDimensionType.ExtDimensionType)),
					EventLogEntryTransactionMode.Transactional);
			ElsIf Not Account.ExtDimensionTypes[IndexOf].Predefined Then
				Account.ExtDimensionTypes[IndexOf].Predefined = True;
			EndIf;
		Else
			FillPropertyValues(Account.ExtDimensionTypes.Add(), ExtDimensionType);
		EndIf;
	EndDo;
	
EndProcedure

Procedure SaveExistingPredefinedObjectsBeforeCreateMissingOnes(
		MetadataObject, FullName, NameTable, Names, Query, SavedItemsDescriptions, TablesWithoutSavedData)
	
	InitializationRequired = False;
	PredefinedItemsExist = False;
	NameTable.Columns.Add("ObjectExist", New TypeDescription("Boolean"));
	
	For Each Name In Names Do
		TableRows = NameTable.FindRows(New Structure("Name", Name));
		If TableRows.Count() = 0 Then
			InitializationRequired = True;
		Else
			For Each TableRow In TableRows Do
				TableRow.ObjectExist = True;
			EndDo;
			PredefinedItemsExist = True;
		EndIf;
	EndDo;
	
	If Not InitializationRequired Then
		Return;
	EndIf;
	
	If PredefinedItemsExist Then
		IsChartOfAccounts = Metadata.ChartsOfAccounts.Contains(MetadataObject);
		SavedItemsDescription = New Structure;
		SavedItemsDescription.Insert("FullName",     FullName);
		SavedItemsDescription.Insert("QueryText",  Query.Text);
		SavedItemsDescription.Insert("NameTable",   NameTable);
		SavedItemsDescription.Insert("IsChartOfAccounts", IsChartOfAccounts);
		SavedItemsDescriptions.Add(SavedItemsDescription);
		
		NameTable.Columns.Add("Object");
		For Each TableRow In NameTable Do
			Object = TableRow.Ref.GetObject();
			Object.PredefinedDataName = "";
			If IsChartOfAccounts Then
				PredefinedExtraDimensionKindRows = New Array;
				For Each ExtraDimensionKindRow In Object.ExtDimensionTypes Do
					If ExtraDimensionKindRow.Predefined Then
						ExtraDimensionKindRow.Predefined = False;
						PredefinedExtraDimensionKindRows.Add(ExtraDimensionKindRow);
					EndIf;
				EndDo;
			EndIf;
			// ACC:1327-off - #648.1.1. An exclusive lock is set in the caller procedure.
			InfobaseUpdate.WriteData(Object);
			// ACC:1327-off.
			If IsChartOfAccounts Then
				For Each ExtraDimensionKindRow In PredefinedExtraDimensionKindRows Do
					ExtraDimensionKindRow.Predefined = True;
				EndDo;
			EndIf;
			If TableRow.ObjectExist Then
				Object.PredefinedDataName = TableRow.Name;
			EndIf;
			TableRow.Object = Object;
		EndDo;
	Else
		TablesWithoutSavedData.Add(FullName);
	EndIf;
	
EndProcedure

// Intended for "SetSessionParameters" function.
Function AllSessionParametersAreSet(SessionParametersNames, SpecifiedParameters)
	
	If SessionParametersNames.Count() <> SpecifiedParameters.Count() Then
		Return False;
	EndIf;
	
	For Each ParameterName In SessionParametersNames Do
		If SpecifiedParameters.Find(ParameterName) = Undefined Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

Procedure BeforeStartApplication()
	
	// Privileged mode (set by the 1C:Enterprise).
	
	If TimeConsumingOperations.ShouldSkipHandlerBeforeAppStartup() Then
		Return;
	EndIf;
	
	// Checking the default programming language set in the configuration.
	CurrentLanguageOf1CEnterpriseLanguage = Metadata.ObjectProperties.ScriptVariant["English"];
	If Metadata.ScriptVariant <> CurrentLanguageOf1CEnterpriseLanguage Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The built-in configuration language option ""%1"" is not supported.
			           |Use language option ""%2"" instead.';"),
			Metadata.ScriptVariant,
			Metadata.ObjectProperties.ScriptVariant["English"]);
	EndIf;
	
	// Check for the minimum 1C:Enterprise version that does not support the app.
	SystemInfo = New SystemInfo;
	CurrentPlatformVersion = CommonClientServer.ConfigurationVersionWithoutBuildNumber(SystemInfo.AppVersion);
	MinPlatformVersion = Min1CEnterpriseVersionForStart();
	
	AssemblyNumbers = StrSplit(MinPlatformVersion, "; ", False);
	MinBuildNumberForCurrent1CEnterpriseVersion = AssemblyNumbers[AssemblyNumbers.UBound()];
	
	For Each BuildNumber In AssemblyNumbers Do
		If StrStartsWith(BuildNumber, CurrentPlatformVersion + ".") Then
			MinBuildNumberForCurrent1CEnterpriseVersion = BuildNumber;
			Break;
		EndIf;
	EndDo;
	
	If CommonClientServer.CompareVersions(SystemInfo.AppVersion, 
		MinBuildNumberForCurrent1CEnterpriseVersion) < 0 Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The application requires 1C:Enterprise version %1 or later.';"), 
			MinBuildNumberForCurrent1CEnterpriseVersion);
	EndIf;
	
	// Check for supported compatibility modes.
	MinPlatformVersions = Min1CEnterpriseVersionForUse();
	MinPlatformVersion = MinPlatformVersions[MinPlatformVersions.Count() - 1].Value;
	CompatibilityModeVersion = Common.CompatibilityModeVersion();
	
	If MinPlatformVersions.FindByValue(CompatibilityModeVersion) = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Configuration compatibility mode ""Version %1"" is not supported. 
			           |To start the application, set the compatibility mode to ""None"" (on 1C:Enterprise version %2)
			           | or to ""Version %2"" (on a later 1C:Enterprise version).';"),
			CompatibilityModeVersion, MinPlatformVersion);
	EndIf;
	
	// Checking whether the configuration version is filled.
	If IsBlankString(Metadata.Version) Then
		Raise NStr("en = 'The Version configuration property is blank.';");
	EndIf;

	Try
		ZeroVersion = CommonClientServer.CompareVersions(Metadata.Version, "0.0.0.0") = 0;
	Except
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The Version configuration property has invalid value: %1.
						|Use the following format: 1.2.3.45.';"),
			Metadata.Version);
	EndTry;
	If ZeroVersion Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The Version configuration property has invalid value: %1.
						|The version cannot be zero.';"),
			Metadata.Version);
	EndIf;
	
	If Not Metadata.DefaultRoles.Contains(Metadata.Roles.SystemAdministrator)
		Or Not Metadata.DefaultRoles.Contains(Metadata.Roles.FullAccess) Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Standard roles %2 and %3 are not specified in property %1 in the configuration.';"),
			"DefaultRoles", Metadata.Roles.SystemAdministrator.Name, Metadata.Roles.FullAccess.Name);
	EndIf;
	
	// Checking whether the session parameter setting handlers for the application start can run.
	CheckIfCanStart();
	
	If Not ValueIsFilled(InfoBaseUsers.CurrentUser().Name)
	   And (Not Common.DataSeparationEnabled()
	      Or Not Common.SeparatedDataUsageAvailable())
	   And InfobaseUpdateInternal.IBVersion("StandardSubsystems",
	       Common.DataSeparationEnabled()) = "0.0.0.0" Then
		
		UsersInternal.SetInitialSettings("");
	EndIf;
	
	SSLSubsystemsIntegration.BeforeStartApplication();
	CommonOverridable.BeforeStartApplication();
	
	CorrectSharedUserHomePage();
	HandleCopiedSettingsQueue();
	
EndProcedure

// Configurations that are launched on earlier versions are blocked as the initialization code cannot be executed.
// A message is displayed prompting informing the user that 1C:Enterprise requires an update.
// This value must not be overridden unless a configuration supports only earlier versions of 1C:Enterprise.
// In this case, choose the version closest to the one returned by the function.
// 
// Returns:
//  String - Comma-delimited numbers of 1C:Enterprise builds.
//
Function Min1CEnterpriseVersionForStart() Export
	
	Return "8.3.21.1622; 8.3.22.1704"; // Must not be modified by patches.
	
EndFunction

// Returns supported compatibility modes and their related minimum 1C:Enterprise versions. See ReadMe.txt. 
// Configurations that are launched on earlier versions are blocked as the initialization code cannot be executed.
// (Such versions may lack some functionality, leading to errors and failures.)
// 
// 
//
// Returns:
//  ValueList:
//   * Value      - String - Supported compatibility mode.
//   * Presentation - String - Comma-delimited numbers of 1C:Enterprise builds.
//
Function Min1CEnterpriseVersionForUse() Export
	
	// It is not recommended to be modified by patches.
	Versions = New ValueList;
	Versions.Add("8.3.21", "8.3.22.2501; 8.3.23.2137; 8.3.24.1467;");
	Versions.Add("8.3.22", "8.3.22.2501; 8.3.23.2137; 8.3.24.1548; 8.3.25.1286");
	Versions.Add("8.3.23", "8.3.23.2137; 8.3.24.1548; 8.3.25.1286");
	Versions.Add("8.3.24", "8.3.24.1548; 8.3.25.1286");
	
	Return Versions;
	
EndFunction

// Supported versions of the Secure Software System. See ReadMe.txt.
// A configuration can run on these versions even if the version is earlier than Min1CEnterpriseVersionForUse, but it must be later than Min1CEnterpriseVersionForStart. 
// 
//
Function SecureSoftwareSystemVersions() Export  // ACC:581 - An export function as it is used for testing.
	
	Versions = New Array;
	Versions.Add("8.3.21.1676");
	Versions.Add("8.3.21.1901");
	Versions.Add("8.3.24.1440");
	Versions.Add("8.3.24.1599");
	
	Return Versions;

EndFunction

// Intended for procedure "ClarifyPlatformVersion".
// It contains revoked 1C:Enterprise versions and their replacements.
//
Function ReplacementVersionForRevoked1CEnterprise(CurrentBuild) Export
	
	If StrFind("8.3.22.1672,8.3.22.1603", CurrentBuild) Then
		Return "8.3.22.1709";
		
	ElsIf StrFind("8.3.21.1607,8.3.21.1508,8.3.21.1484", CurrentBuild) Then
		Return "8.3.21.1624";
		
	EndIf;
	
	Return "";
	
EndFunction

// This method is required by BeforeStartApplication procedure.
Procedure CorrectSharedUserHomePage()
	
	If CurrentRunMode() = Undefined
	 Or Not Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		SessionWithoutSeparators = ModuleSaaSOperations.SessionWithoutSeparators();
	Else
		SessionWithoutSeparators = False;
	EndIf;
	
	If Not SessionWithoutSeparators Then
		Return;
	EndIf;
	
	ObjectKey  = "Core";
	SettingsKey = "MetadataHomePageFormComposition";
	
	PreviousFormCompositionInMetadata = CommonSettingsStorage.Load(ObjectKey, SettingsKey);
	If PreviousFormCompositionInMetadata = Undefined Then
		// Clearing the home page on the first sign-in.
		SetBlankFormOnHomePage();
	Else
		SetBlankFormOnBlankHomePage();
	EndIf;
	
	// Compensation of form content change in the metadata of the home page.
	NewSettings1 = New HomePageSettings;
	FormCompositionInMetadata = NewSettings1.GetForms();
	
	If TypeOf(PreviousFormCompositionInMetadata) <> Type("Structure")
	 Or Not PreviousFormCompositionInMetadata.Property("LeftColumn")
	 Or TypeOf(PreviousFormCompositionInMetadata.LeftColumn) <> Type("Array")
	 Or Not PreviousFormCompositionInMetadata.Property("RightColumn")
	 Or TypeOf(PreviousFormCompositionInMetadata.RightColumn) <> Type("Array") Then
		
		PreviousFormCompositionInMetadata = New HomePageForms;
		
	ElsIf FormCompositionMatches(PreviousFormCompositionInMetadata.LeftColumn,  FormCompositionInMetadata.LeftColumn)
	        And FormCompositionMatches(PreviousFormCompositionInMetadata.RightColumn, FormCompositionInMetadata.RightColumn) Then
		
		// Form content in the metadata of the home page is not changed.
		Return;
	EndIf;
	
	CompensateChangesOfFormCompositionInHomePageMetadata(PreviousFormCompositionInMetadata);
	
	SavedFormCompositionInMetadata = New Structure("LeftColumn, RightColumn");
	FillPropertyValues(SavedFormCompositionInMetadata, FormCompositionInMetadata);
	
	CommonSettingsStorage.Save(ObjectKey, SettingsKey, SavedFormCompositionInMetadata);
	
EndProcedure

// This method is required by CorrectSharedUserHomePage procedure.
Function FormCompositionMatches(PreviousFormsInMetadata, FormsInMetadata)
	
	If PreviousFormsInMetadata.Count() <> FormsInMetadata.Count() Then
		Return False;
	EndIf;
	
	For Each FormName In FormsInMetadata Do
		If PreviousFormsInMetadata.Find(FormName) = Undefined Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// This method is required by CorrectSharedUserHomePage procedure.
Procedure CompensateChangesOfFormCompositionInHomePageMetadata(PreviousFormCompositionInMetadata)
	
	// The compensation takes into account that the home page settings
	// might have been saved when hiding the desktop.
	
	ObjectKey         = "Common/HomePageSettings";
	StorageObjectKey = "Common/HomePageSettingsBeforeClear";
	SavedSettings = SystemSettingsStorage.Load(StorageObjectKey, "");
	SettingsSaved   = TypeOf(SavedSettings) = Type("ValueStorage");
	
	If SettingsSaved Then
		CurrentSettings = SavedSettings.Get();
	Else
		CurrentSettings = SystemSettingsStorage.Load(ObjectKey);
	EndIf;
	If TypeOf(CurrentSettings) = Type("HomePageSettings") Then
		FormContent = CurrentSettings.GetForms();
	Else
		FormContent = New HomePageForms;
	EndIf;
	
	NewSettings1 = New HomePageSettings;
	FormCompositionInMetadata = NewSettings1.GetForms();
	
	DeleteNewHomePageForms(FormContent.LeftColumn,
		PreviousFormCompositionInMetadata.LeftColumn, FormCompositionInMetadata.LeftColumn);
	
	DeleteNewHomePageForms(FormContent.RightColumn,
		PreviousFormCompositionInMetadata.RightColumn, FormCompositionInMetadata.RightColumn);
	
	CurrentSettings = New HomePageSettings;
	CurrentSettings.SetForms(FormContent);
	
	If SettingsSaved Then
		SavingSettings = New ValueStorage(CurrentSettings);
		SystemSettingsStorage.Save(StorageObjectKey, "", SavingSettings);
		SetBlankFormOnHomePage();
	Else
		SystemSettingsStorage.Save(ObjectKey, "", CurrentSettings);
	EndIf;
	
EndProcedure

// This method is required by CompensateChangesOfFormContentInHomePageMetadata procedure.
Procedure DeleteNewHomePageForms(CurrentForms, PreviousFormsInMetadata, FormsInMetadata)
	
	For Each FormName In FormsInMetadata Do
		If PreviousFormsInMetadata.Find(FormName) <> Undefined Then
			Continue;
		EndIf;
		IndexOf = CurrentForms.Find(FormName);
		If IndexOf <> Undefined Then
			CurrentForms.Delete(IndexOf);
		EndIf;
	EndDo;
	
EndProcedure

Procedure HandleCopiedSettingsQueue()
	
	If CurrentRunMode() = Undefined Then
		Return;
	EndIf;
	
	SettingsQueue = CommonSettingsStorage.Load("SettingsQueue", "NotAppliedSettings");
	If TypeOf(SettingsQueue) <> Type("ValueStorage") Then
		Return;
	EndIf;
	SettingsQueue = SettingsQueue.Get();
	If TypeOf(SettingsQueue) <> Type("Map") Then
		Return;
	EndIf;
	
	For Each QueueItem In SettingsQueue Do
		Try
			Setting = SystemSettingsStorage.Load(QueueItem.Key, QueueItem.Value);
		Except
			Continue;
		EndTry;
		SystemSettingsStorage.Save(QueueItem.Key, QueueItem.Value, Setting);
	EndDo;
	
	CommonSettingsStorage.Save("SettingsQueue", "NotAppliedSettings", Undefined);
	
EndProcedure

Procedure ExecuteSessionParameterSettingHandlers(SessionParametersNames, Handlers, SpecifiedParameters)
	
	// An array with session parameter keys, which are set with the
	// parameter name start word followed by the asterisk ( * ).
	SessionParameterKeys = New Array;
	
	For Each Record In Handlers Do
		If StrFind(Record.Key, "*") > 0 Then
			ParameterKey = TrimAll(Record.Key);
			SessionParameterKeys.Add(Left(ParameterKey, StrLen(ParameterKey)-1));
		EndIf;
	EndDo;
	
	For Each ParameterName In SessionParametersNames Do
		If SpecifiedParameters.Find(ParameterName) <> Undefined Then
			Continue;
		EndIf;
		
		Handler = Handlers.Get(ParameterName);
		If Handler <> Undefined Then
			HandlerParameters = New Array();
			HandlerParameters.Add(ParameterName);
			HandlerParameters.Add(SpecifiedParameters);
			Common.ExecuteConfigurationMethod(Handler, HandlerParameters);
			Continue;
		EndIf;
		
		For Each ParameterKeyName In SessionParameterKeys Do
			If StrStartsWith(ParameterName, ParameterKeyName) Then
				Handler = Handlers.Get(ParameterKeyName + "*");
				HandlerParameters = New Array();
				HandlerParameters.Add(ParameterName);
				HandlerParameters.Add(SpecifiedParameters);
				Common.ExecuteConfigurationMethod(Handler, HandlerParameters);
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

Procedure IgnoreSendingMetadataObjectIDs(DataElement, ItemSend, Val InitialImageCreating = False)
	
	If Not InitialImageCreating
		And MetadataObject(DataElement) = Metadata.Catalogs.MetadataObjectIDs Then
		
		ItemSend = DataItemSend.Ignore;
		
	EndIf;
	
EndProcedure

Procedure IgnoreGettingMetadataObjectIDs(DataElement, ItemReceive)
	
	If MetadataObject(DataElement) = Metadata.Catalogs.MetadataObjectIDs Then
		ItemReceive = DataItemReceive.Ignore;
	EndIf;
	
EndProcedure

Function MetadataObject(Val DataElement)
	
	Return ?(TypeOf(DataElement) = Type("ObjectDeletion"), DataElement.Ref.Metadata(), DataElement.Metadata());
	
EndFunction

Function InitialImageCreating(Val DataElement)
	
	Return ?(TypeOf(DataElement) = Type("ObjectDeletion"), False, DataElement.AdditionalProperties.Property("InitialImageCreating"));
	
EndFunction

Function ShowDeprecatedPlatformVersion(Parameters)
	
	If Parameters.DataSeparationEnabled Then
		Return False;
	EndIf;
	
	// Checking whether the user is not an external one.
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("IBUserID",
		InfoBaseUsers.CurrentUser().UUID);
	
	Query.Text = 
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.IBUserID = &IBUserID";
	
	If Not Query.Execute().IsEmpty() Then
		Return False;
	EndIf;
	
	SystemInfo = New SystemInfo;
	Current       = SystemInfo.AppVersion;
	Min   = Parameters.MinPlatformVersion;
	Recommended = Parameters.RecommendedPlatformVersion;
	
	Return CommonClientServer.CompareVersions(Current, Min) < 0
		Or CommonClientServer.CompareVersions(Current, Recommended) < 0;
	
EndFunction

Function DefaultAdministrationParameters()
	
	ClusterAdministrationParameters = ClusterAdministration.ClusterAdministrationParameters();
	IBAdministrationParameters = ClusterAdministration.ClusterInfobaseAdministrationParameters();
	
	// Join parameter structures.
	AdministrationParameterStructure = ClusterAdministrationParameters;
	For Each Item In IBAdministrationParameters Do
		AdministrationParameterStructure.Insert(Item.Key, Item.Value);
	EndDo;
	
	AdministrationParameterStructure.Insert("OpenExternalReportsAndDataProcessorsDecisionMade", False);
	
	Return AdministrationParameterStructure;
	
EndFunction

Procedure ReadParametersFromConnectionString(AdministrationParameterStructure)
	
	ConnectionStringSubstrings = StrSplit(InfoBaseConnectionString(), ";");
	
	ServerNameString = StringFunctionsClientServer.RemoveDoubleQuotationMarks(Mid(ConnectionStringSubstrings[0], 7));
	AdministrationParameterStructure.NameInCluster = StringFunctionsClientServer.RemoveDoubleQuotationMarks(Mid(ConnectionStringSubstrings[1], 6));
	
	ClusterServerList = StrSplit(ServerNameString, ",");
	If ClusterServerList.Count() = 1 Then 
		ClusterServerList = StrSplit(ServerNameString, ";");
	EndIf;
	
	ServerName = ClusterServerList[0];
	
	// The only valid protocol is TCP. Skip it.
	If StrStartsWith(Upper(ServerName), "TCP://") Then
		ServerName = Mid(ServerName, 7);
	EndIf;
	
	// If an IPv6 address is passed as the server name, the port can go after the closing bracket (]) only.
	StartPosition = StrFind(ServerName, "]");
	If StartPosition <> 0 Then
		PortSeparator = StrFind(ServerName, ":",, StartPosition);
	Else
		PortSeparator = StrFind(ServerName, ":");
	EndIf;
	
	If PortSeparator > 0 Then
		ServerAgentAddress = Mid(ServerName, 1, PortSeparator - 1);
		ClusterPort = Number(Mid(ServerName, PortSeparator + 1));
		If AdministrationParameterStructure.ClusterPort = 1541 Then
			AdministrationParameterStructure.ClusterPort = ClusterPort;
		EndIf;
	Else
		ServerAgentAddress = ServerName;
	EndIf;
	
	AdministrationParameterStructure.ServerAgentAddress = ServerAgentAddress;
	
EndProcedure

// Checks whether handlers that set session parameters, 
// update handlers, and other basic mechanisms of configuration 
// that execute configuration code on the full procedure name can be executed.
//
// If the current settings of the security profiles (in the server cluster and in the infobase) 
// do not allow the handlers execution, an exception is generated
// that contains reason details and the list of actions to solve this problem.
//
Procedure CheckIfCanStart()
	
	If Common.FileInfobase(InfoBaseConnectionString()) Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
		InfobaseProfile = ModuleSafeModeManager.InfobaseSecurityProfile();
	Else
		InfobaseProfile = "";
	EndIf;
	
	If ValueIsFilled(InfobaseProfile) Then
		
		// The infobase is configured so that the security profile
		// prohibits unlimited access to external modules.
		
		SetSafeMode(InfobaseProfile);
		If SafeMode() <> InfobaseProfile Then
			
			// The infobase profile is unavailable for running the handlers.
			
			SetSafeMode(False);
			
			Try
				PrivilegedModeAvailable = CanExecuteHandlersWithoutSafeMode();
			Except
				PrivilegedModeAvailable = False;
			EndTry;
				
			If Not PrivilegedModeAvailable Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Couldn''t set session parameters. Reason: Security profile %1 is not found in 1C:Enterprise server cluster or it cannot be applied in safe mode.
						|
						|To restore the app functionality, disable the security profile using the cluster console and reconfigure the security profiles using the configuration interface (see the commands in the app settings section).';"),
					InfobaseProfile);
			EndIf;
			
		EndIf;
		
		PrivilegedModeAvailable = SwichingToPrivilegedModeAvailable();
		
		SetSafeMode(False);
		
		If Not PrivilegedModeAvailable Then
			
			// Infobase profile allows the handler execution but the privileged mode cannot be set.
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot set the session parameters. Reason: Security profile %1 does not contain the permission to set the privileged mode. Probably it was edited using the cluster console.
					|
					|To restore the app functionality, disable the security profile using the cluster console and reconfigure the security profiles using the configuration interface (see the commands in the app settings section).';"),
				InfobaseProfile);
			
		EndIf;
		
	Else
		
		// The infobase is configured so that the security profile
		// cannot prohibit unlimited access to external modules.
		
		Try
			PrivilegedModeAvailable = CanExecuteHandlersWithoutSafeMode();
		Except
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot set the session parameters. Reason: %1.
					|
					|Probably a security profile that does not allow execution of external modules in unsafe mode was set using the cluster console. If this is the case, to restore the application functionality, disable the security profile using the cluster console and reconfigure the security profiles using the configuration interface (see the commands in the application settings section). The app will be automatically configured to use the enabled security profiles.';"),
				ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			
		EndTry;
		
	EndIf;
	
EndProcedure

// Checks whether the handlers can be executed without safe mode.
//
// Returns:
//   Boolean
//
Function CanExecuteHandlersWithoutSafeMode()
	
	// Do not call "Common.CalculateInSafeMode" since the privileged
	// mode usage in the "Evaluate" function is checked in unsafe mode.
	Return Eval("SwichingToPrivilegedModeAvailable()"); // ACC:488
		
EndFunction

// Checks whether the privileged mode can be set from the current safe mode.
//
// Returns:
//   Boolean
//
Function SwichingToPrivilegedModeAvailable()
	
	SetPrivilegedMode(True);
	Return PrivilegedMode();
	
EndFunction

// This method is required by RegisterPriorityDataChangeForSubordinateDIBNode procedure.
Procedure RegisterPredefinedItemChanges(DIBExchangePlansNodes, MetadataCollection)
	
	Query = New Query;
	
	For Each MetadataObject In MetadataCollection Do
		DIBNodes = New Array;
		
		For Each ExchangePlanNodes In DIBExchangePlansNodes Do
			If Not ExchangePlanNodes.Key.Contains(MetadataObject) Then
				Continue;
			EndIf;
			For Each DIBNode In ExchangePlanNodes.Value Do
				DIBNodes.Add(DIBNode);
			EndDo;
		EndDo;
		
		If DIBNodes.Count() = 0 Then
			Continue;
		EndIf;
		
		Query.Text =
		"SELECT
		|	CurrentTable.Ref AS Ref
		|FROM
		|	&CurrentTable AS CurrentTable
		|WHERE
		|	CurrentTable.Predefined";
		Query.Text = StrReplace(Query.Text, "&CurrentTable", MetadataObject.FullName());
		// @skip-check query-in-loop - Batch processing of data
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			ExchangePlans.RecordChanges(DIBNodes, Selection.Ref);
		EndDo;
	EndDo;
	
EndProcedure

// This method is required by SetFormAssignmentKey procedure.
Procedure SetFormAssignmentUsageKey(Form, Var_Key, SetSettings)
	
	If Not ValueIsFilled(Var_Key)
	 Or Form.PurposeUseKey = Var_Key Then
		
		Return;
	EndIf;
	
	If Not SetSettings Then
		Form.PurposeUseKey = Var_Key;
		Return;
	EndIf;
	
	SettingsTypes1 = New Array;
	// Translated English variant.
	SettingsTypes1.Add("/CurrentVariantKey");
	SettingsTypes1.Add("/CurrentUserSettingsKey");
	SettingsTypes1.Add("/CurrentUserSettings");
	SettingsTypes1.Add("/CurrentDataSettingsKey");
	SettingsTypes1.Add("/CurrentData");
	SettingsTypes1.Add("/FormSettings");
	// Original English variant.
	SettingsTypes1.Add("/CurrentVariantKey");
	SettingsTypes1.Add("/CurrentUserSettingsKey");
	SettingsTypes1.Add("/CurrentUserSettings");
	SettingsTypes1.Add("/CurrentDataSettingsKey");
	SettingsTypes1.Add("/CurrentData");
	SettingsTypes1.Add("/FormSettings");
	If SystemSettingsStorage.Load(Var_Key, "FormAssignmentRuleKey") <> True 
		 And AccessRight("SaveUserData", Metadata) Then
		SetSettingsForKey(Var_Key, SettingsTypes1, Form.FormName, Form.PurposeUseKey);
		SystemSettingsStorage.Save(Var_Key, "FormAssignmentRuleKey", True);
	EndIf;
	
	Form.PurposeUseKey = Var_Key;
	
EndProcedure

// This method is required by SetFormAssignmentKey procedure.
Procedure SetFormWindowOptionsSaveKey(Form, Var_Key, SetSettings)
	
	If Not ValueIsFilled(Var_Key)
	 Or Form.WindowOptionsKey = Var_Key Then
		
		Return;
	EndIf;
	
	If Not SetSettings Then
		Form.WindowOptionsKey = Var_Key;
		Return;
	EndIf;
	
	SettingsTypes1 = New Array;
	// Translated English variant.
	SettingsTypes1.Add("/ThinClientWindowSettings"); // @Non-NLS
	SettingsTypes1.Add("/Taxi/ThinClientWindowSettings"); // @Non-NLS
	SettingsTypes1.Add("/WebClientWindowSettings"); // @Non-NLS
	SettingsTypes1.Add("/Taxi/WebClientWindowSettings"); // @Non-NLS
	// The English version.
	SettingsTypes1.Add("/ThinClientWindowSettings");
	SettingsTypes1.Add("/Taxi/ThinClientWindowSettings");
	SettingsTypes1.Add("/WebClientWindowSettings");
	SettingsTypes1.Add("/Taxi/WebClientWindowSettings");
	
	If SystemSettingsStorage.Load(Var_Key, "FormWindowOptionsKey") <> True 
		And AccessRight("SaveUserData", Metadata) Then
		SetSettingsForKey(Var_Key, SettingsTypes1, Form.FormName, Form.WindowOptionsKey);
		SystemSettingsStorage.Save(Var_Key, "FormWindowOptionsKey", True);
	EndIf;
	
	Form.WindowOptionsKey = Var_Key;
	
EndProcedure

// This method is required by SetFormAssignmentUseKey and SetFormWindowOptionsSaveKey procedures.
Procedure SetSettingsForKey(Var_Key, SettingsTypes1, FormName, CurrentKey)
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	NewKey = "/" + Var_Key;
	Filter = New Structure;
	Filter.Insert("User", InfoBaseUsers.CurrentUser().Name);
	
	For Each SettingsType1 In SettingsTypes1 Do
		Filter.Insert("ObjectKey", FormName + NewKey + SettingsType1);
		Selection = SystemSettingsStorage.Select(Filter);
		If Selection.Next() Then
			Return; // Key settings are already set.
		EndIf;
	EndDo;
	
	If ValueIsFilled(CurrentKey) Then
		CurrentKey = "/" + CurrentKey;
	EndIf;
	
	// Setting the initial settings key by copying them from the current key.
	For Each SettingsType1 In SettingsTypes1 Do
		Filter.Insert("ObjectKey", FormName + CurrentKey + SettingsType1);
		Selection = SystemSettingsStorage.Select(Filter);
		ObjectKey = FormName + NewKey + SettingsType1;
		While Selection.Next() Do
			SettingsDescription = New SettingsDescription;
			SettingsDescription.Presentation = Selection.Presentation;
			SystemSettingsStorage.Save(ObjectKey, Selection.SettingsKey,
				Selection.Settings, SettingsDescription);
		EndDo;
	EndDo;
	
EndProcedure

// Check server notifications and send them to client.

// See OnReceiptRecurringClientDataOnServer
Procedure ConfigurationOrExtensionModifiedDuringRepeatedCheck(UserMessage)
	
	
	SetPrivilegedMode(True);
	
	UserName = InfoBaseUsers.CurrentUser().Name;
	
	YouCanNotify = ShowWarningAboutInstalledUpdatesForUser(UserName);
	If Not YouCanNotify Then
		Return;
	EndIf;
	
	DateRemindTomorrow = Common.SystemSettingsStorageLoad(
		"DynamicUpdateControl", "DateRemindTomorrow",,, UserName);
	
	If TypeOf(DateRemindTomorrow) = Type("Date")
	   And CurrentSessionDate() < DateRemindTomorrow Then
		Return;
	EndIf;
	
	DataBaseConfigurationChangedDynamically = DataBaseConfigurationChangedDynamically();
	DynamicChanges = Catalogs.ExtensionsVersions.DynamicallyChangedExtensions(
		Catalogs.ExtensionsVersions.InstalledExtensionsOnStartup(), True);
	
	If Not DataBaseConfigurationChangedDynamically
	   And Not ValueIsFilled(DynamicChanges.Extensions)
	   And Not ValueIsFilled(DynamicChanges.Corrections) Then
		Return;
	EndIf;
	
	If DynamicChanges.Corrections <> Undefined
		And DynamicChanges.Extensions = Undefined
		And Not DataBaseConfigurationChangedDynamically
		// Only the list of patches is changed. Check that notifications can be displayed.
		And DynamicChanges.Corrections.Added2 <> 0
		And DynamicChanges.Corrections.Deleted = 0 Then
	
		NotificationSchedule = Common.SystemSettingsStorageLoad(
			"DynamicUpdateControl", "PatchCheckSchedule",,, UserName);
		
		If TypeOf(NotificationSchedule) = Type("Structure")
			And NotificationSchedule.Property("Schedule")
			And TypeOf(NotificationSchedule.Schedule) = Type("JobSchedule") Then
			
			CurrentSessionDate = CurrentSessionDate();
			YouCanNotify = NotificationSchedule.Schedule.ExecutionRequired(CurrentSessionDate,
				NotificationSchedule.LastAlert);
			
			If YouCanNotify Then
				NotificationSchedule.LastAlert = CurrentSessionDate;
				Common.SystemSettingsStorageSave("DynamicUpdateControl",
					"PatchCheckSchedule", NotificationSchedule,, UserName);
			EndIf;
		Else
			OnceADay = New JobSchedule;
			OnceADay.DaysRepeatPeriod = 1;
			
			PatchCheckSchedule = New Structure;
			PatchCheckSchedule.Insert("Id", "Once");
			PatchCheckSchedule.Insert("Presentation", NStr("en = 'Once a day';"));
			PatchCheckSchedule.Insert("Schedule", OnceADay);
			PatchCheckSchedule.Insert("LastAlert", CurrentSessionDate());

			Common.SystemSettingsStorageSave("DynamicUpdateControl", "PatchCheckSchedule", PatchCheckSchedule);
		EndIf;
	EndIf;
	
	If Not YouCanNotify Then
		Return;
	EndIf;
	
	DynamicChanges.Insert("DataBaseConfigurationChangedDynamically",
		DataBaseConfigurationChangedDynamically);
		
	Messages = New Array;
	Messages.Add(MessageTextOnDynamicUpdate(DynamicChanges));
	Messages.Add(NStr("en = 'Click here to start or postpone patch application.';"));
	UserMessage = StrConcat(Messages, Chars.LF);
	
EndProcedure

// See OnSendServerNotification
Procedure OnSendServerNotificationFunctionalOptionsModified(NameOfAlert, ParametersVariants)
	
	ParameterName = "StandardSubsystems.Core.EnabledFunctionalOptions";
	PreviousValue2 = ExtensionParameter(ParameterName, True);
	
	NewTypeCollection = New Array;
	FunctionalOptionsByTypes = New Map;
	For Each FunctionalOption In Metadata.FunctionalOptions Do
		StorageObject = FunctionalOption.Location;
		If Not Metadata.Constants.Contains(StorageObject) Then
			Continue;
		EndIf;
		Type = Type("ConstantManager." + StorageObject.Name);
		FunctionalOptionsByTypes.Insert(Type, FunctionalOption);
		If GetFunctionalOption(FunctionalOption.Name) = True Then
			NewTypeCollection.Add(Type);
		EndIf;
	EndDo;
	NewValue = New TypeDescription(NewTypeCollection);
	If PreviousValue2 = NewValue Then
		Return;
	EndIf;
	
	If TypeOf(PreviousValue2) = Type("TypeDescription") Then
		TypesChangeList = New Map;
		For Each Type In NewValue.Types() Do
			TypesChangeList.Insert(Type, True);
		EndDo;
		For Each Type In PreviousValue2.Types() Do
			If TypesChangeList.Get(Type) = Undefined Then
				TypesChangeList.Insert(Type, True);
			Else
				TypesChangeList.Delete(Type);
			EndIf;
		EndDo;
		
		Objects = New Map;
		For Each KeyAndValue In TypesChangeList Do
			FunctionalOption = FunctionalOptionsByTypes.Get(KeyAndValue.Key);
			If FunctionalOption = Undefined Then
				Continue;
			EndIf;
			AddFunctionalOptionObjects(Objects, FunctionalOption);
		EndDo;
		
		SMSMessageRecipients = New Map;
		For Each ParametersVariant In ParametersVariants Do
			For Each Addressee In ParametersVariant.SMSMessageRecipients Do
				IBUser = InfoBaseUsers.FindByUUID(Addressee.Key);
				If IBUser = Undefined Then
					Continue;
				EndIf;
				For Each KeyAndValue In Objects Do
					If AccessRight(KeyAndValue.Value, KeyAndValue.Key, IBUser) Then
						SMSMessageRecipients.Insert(Addressee.Key, Addressee.Value);
						Break;
					EndIf;
				EndDo;
			EndDo;
		EndDo;
		If ValueIsFilled(SMSMessageRecipients) Then
			ServerNotifications.SendServerNotification(NameOfAlert, "", SMSMessageRecipients);
		EndIf;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ExtensionVersionParameters");
	LockItem.SetValue("ExtensionsVersion", Catalogs.ExtensionsVersions.EmptyRef());
	LockItem.SetValue("ParameterName", ParameterName);
	
	BeginTransaction();
	Try
		Block.Lock();
		PreviousValue2 = ExtensionParameter(ParameterName, True);
		If PreviousValue2 <> NewValue Then
			SetExtensionParameter(ParameterName, NewValue, True);
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure AddFunctionalOptionObjects(Objects, FunctionalOption)
	
	BaseTypesNames =
	"
	|Subsystem
	|CommonAttribute
	|ExchangePlan
	|FilterCriterion
	|CommonForm
	|CommonCommand
	|Constant
	|Catalog
	|Document
	|DocumentJournal
	|Report
	|DataProcessor
	|ChartOfCharacteristicTypes
	|ChartOfAccounts
	|ChartOfCalculationTypes
	|InformationRegister
	|AccumulationRegister
	|AccountingRegister
	|CalculationRegister
	|BusinessProcess
	|Task
	|";
	
	For Each CompositionItem In FunctionalOption.Content Do
		Object = CompositionItem.Object;
		If Objects.Get(Object) <> Undefined
		 Or TypeOf(Object) <> Type("MetadataObject") Then
			Continue;
		EndIf;
		Try
			FullName = Object.FullName();
		Except
			FullName = "";
		EndTry;
		NameParts = StrSplit(FullName, ".", False);
		If NameParts.Count() < 2 Then
			Continue;
		EndIf;
		BaseTypeName = NameParts[0];
		If StrFind(BaseTypesNames, Chars.LF + BaseTypeName + Chars.LF) = 0 Then
			Continue;
		EndIf;
		If NameParts.Count() > 2 Then
			If BaseTypeName <> "Subsystem" Then
				Object = Common.MetadataObjectByFullName(NameParts[0] + "." + NameParts[1]);
				If Object = Undefined
				 Or Objects.Get(Object) <> Undefined Then
					Continue;
				EndIf;
			EndIf;
		EndIf;
		Objects.Insert(Object, "View");
	EndDo;
	
EndProcedure

// Multilingual configurations.

Function RegionalInfobaseSettingsRequired() Export
		
	If Common.DataSeparationEnabled() Then
		Return False;
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		Return ModuleNationalLanguageSupportServer.RegionalInfobaseSettingsRequired();
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

Function StyleItems() Export
	
	StyleElementsSet = New Structure;
	For Each StyleItem In Metadata.StyleItems Do
		StyleElementsSet.Insert(StyleItem.Name, StyleItem.Value);
	EndDo;
	
	Return New FixedStructure(StyleElementsSet);
	
EndFunction

// Returns a set of style elements to be serialized.
// 
// Returns:
//  Structure:
//   * Key - String - style item name.
//   * Value - String
//              - MetadataObjectStyleItem - a style item. For a regular application thick client,
//                           the style item is converted to the system string presentation of the passed value.
//
Function StyleElementsSet()
	
	StyleElementsSet = New Structure;
	For Each StyleItem In Metadata.StyleItems Do
		
		If CurrentRunMode() = ClientRunMode.OrdinaryApplication Then
			StyleElementsSet.Insert(StyleItem.Name, New ValueStorage(StyleItem.Value));
		Else
			StyleElementsSet.Insert(StyleItem.Name, StyleItem.Value);
		EndIf;
		
	EndDo;
	
	Return New FixedStructure(StyleElementsSet);
	
EndFunction

// This method is required by OnFillPermissionsToAccessExternalResources procedure.
Procedure AddRequestForPermissionToUseExtensions(PermissionsRequests)
	
	If Common.DataSeparationEnabled()
	   And Common.SeparatedDataUsageAvailable() Then
		
		Return;
	EndIf;
	
	Permissions = New Array;
	AllExtensions = ConfigurationExtensions.Get();
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	For Each Extension In AllExtensions Do
		Permissions.Add(ModuleSafeModeManager.PermissionToUseExternalModule(
			Extension.Name, Base64String(Extension.HashSum)));
	EndDo;
	
	PermissionsRequests.Add(ModuleSafeModeManager.RequestToUseExternalResources(Permissions,
		Common.MetadataObjectID("InformationRegister.ExtensionVersionParameters")));

EndProcedure

Function MustShowRAMSizeRecommendations()
	
	If Common.IsWebClient()
	 Or Not Common.FileInfobase() Then
		Return False;
	EndIf;
	
	RAM = ClientParametersAtServer().Get("RAM");
	If TypeOf(RAM) <> Type("Number") Then
		Return False; // The client parameter on the server is not filled (there is no client application).
	EndIf;
	
	RecommendedSize = Common.CommonCoreParameters().RecommendedRAM;
	SavedRecommendation = Common.CommonSettingsStorageLoad("UserCommonSettings",
		"RAMRecommendation");
	
	Recommendation = New Structure;
	Recommendation.Insert("Show", True);
	Recommendation.Insert("PreviousShowDate", Date(1, 1, 1));
	
	If TypeOf(SavedRecommendation) = Type("Structure") Then
		FillPropertyValues(Recommendation, SavedRecommendation);
	EndIf;
	
	Return RAM < RecommendedSize
		And (Recommendation.Show
		   Or (CurrentSessionDate() - Recommendation.PreviousShowDate) > 60*60*24*60)
	
EndFunction

Procedure IgnoreSendingDataProcessedOnMasterDIBNodeOnInfobaseUpdate(DataElement, InitialImageCreating, Recipient)
	
	If Recipient <> Undefined
		And Not InitialImageCreating
		And TypeOf(DataElement) = Type("InformationRegisterRecordSet.DataProcessedInMasterDIBNode") Then
		
		IndexOf = DataElement.Count() - 1;
		While IndexOf >= 0 Do
			SetRow = DataElement[IndexOf];
			If SetRow.ExchangePlanNode <> Recipient Then
				DataElement.Delete(SetRow);
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		
	EndIf;

EndProcedure

Function InvalidPlatformVersionUsed()
	
	SystemInfo = New SystemInfo;
	DeprecatedPlatformVersions = Common.InvalidPlatformVersions();
	
	Return StrFind(DeprecatedPlatformVersions, SystemInfo.AppVersion);
	
EndFunction

Function IsOwnerMarkedForDeletion(RemovableObject)
	
	SourceMetadata = RemovableObject.Metadata();
	If SourceMetadata.Owners.Count() = 0 Then
		Return False;
	EndIf;

	Query = New Query;
	Query.Text = "
	|SELECT
	|	OwnerTable.Owner.DeletionMark AS DeletionMark
	|FROM
	|	&TableName AS OwnerTable
	|WHERE 
	|	OwnerTable.Ref = &Ref";
	
	Query.Text = StrReplace(Query.Text, "&TableName", SourceMetadata.FullName());
	Query.SetParameter("Ref", RemovableObject);
		
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.DeletionMark;
	EndIf;
	Return False;
	
EndFunction

#EndRegion

#EndIf