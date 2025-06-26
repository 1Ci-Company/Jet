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

#Region UserNotification

// ACC:142-off - 4 optional parameters intended for compatibility 
// with the obsolete procedure "CommonClientServer.ReportToUser".

// Generates and displays the message that can relate to a form item.
//
// See Common.MessageToUser
//
// Parameters:
//  MessageToUserText - String - message text.
//  DataKey - AnyRef - the infobase record key or object that message refers to.
//  Field - String - a form attribute description.
//  DataPath - String - a data path (a path to a form attribute).
//  Cancel - Boolean - an output parameter. Always True.
//
// Example:
//
//  1. Showing the message associated with the object attribute near the form field:
//  CommonClient.MessageToUser(
//   NStr("en = 'Error message.'"), ,
//   "FieldInFormAttributeObject",
//   "Object");
//
//  An alternative variant of using in the object form module:
//  CommonClient.MessageToUser(
//   NStr("en = 'Error message.'"), ,
//   "Object.FieldInFormAttributeObject");
//
//  2. Showing a message for the form attribute, next to the form field:
//  CommonClient.MessageToUser(
//   NStr("en = 'Error message.'"), ,
//   "FormAttributeName");
//
//  3. To display a message associated with an infobase object:
//  CommonClient.MessageToUser(
//   NStr("en = 'Error message.'"), InfobaseObject, "Responsible person",,Cancel);
//
//  4. To display a message from a link to an infobase object:
//  CommonClient.MessageToUser(
//   NStr("en = 'Error message.'"), Reference, , , Cancel);
//
//  Scenarios of incorrect using:
//   1. Passing DataKey and DataPath parameters at the same time.
//   2. Passing a value of an illegal type to the DataKey parameter.
//   3. Specifying a reference without specifying a field (and/or a data path).
//
Procedure MessageToUser(Val MessageToUserText,	Val DataKey = Undefined,
	Val Field = "", Val DataPath = "", Cancel = False) Export
	
	Message = CommonInternalClientServer.UserMessage(MessageToUserText,
		DataKey, Field, DataPath, Cancel);
	
	Message.Message()
	
EndProcedure

// ACC:142-on

#EndRegion

#Region InfobaseData

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions to manage infobase data.

// Returns a reference to the predefined item by its full name.
// Only the following objects can contain predefined objects:
//   - catalogs;
//   - charts of characteristic types;
//   - charts of accounts;
//   - charts of calculation types.
// After changing the list of predefined items, it is recommended that you run
// the UpdateCachedValues() method to clear the cache for Cached modules in the current session.
//
// See Common.PredefinedItem
//
// Parameters:
//   FullPredefinedItemName - String - full path to the predefined item including the name.
//     The format is identical to the PredefinedValue() global context function.
//     Example:
//       "Catalog.ContactInformationKinds.UserEmail"
//       "ChartOfAccounts.SelfFinancing.Materials"
//       "ChartOfCalculationTypes.Accruals.SalaryPayments".
//
// Returns: 	
//   AnyRef - reference to the predefined item.
//   Undefined - if the predefined item exists in metadata but not in the infobase.
//
Function PredefinedItem(FullPredefinedItemName) Export
	
	If CommonInternalClientServer.UseStandardGettingPredefinedItemFunction(
		FullPredefinedItemName) Then 
		
		Return PredefinedValue(FullPredefinedItemName);
	EndIf;
	
	PredefinedItemFields = CommonInternalClientServer.PredefinedItemNameByFields(FullPredefinedItemName);
	
	PredefinedValues = StandardSubsystemsClientCached.RefsByPredefinedItemsNames(
		PredefinedItemFields.FullMetadataObjectName);
	
	Return CommonInternalClientServer.PredefinedItem(
		FullPredefinedItemName, PredefinedItemFields, PredefinedValues);
	
EndFunction

// Returns the code of the default infobase language, for example, "en".
// On which auto-generated rows are programmatically written in the infobase.
// For example, when initially filling the infobase with template data, generating a posting comment automatically,
// or determining the value of the EventName parameter of the EventLogRecord method.
//
// Returns:
//  String - language code.
//
Function DefaultLanguageCode() Export
	
	Return StandardSubsystemsClient.ClientParameter("DefaultLanguageCode");
	
EndFunction

#EndRegion

#Region ConditionCalls

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for calling optional subsystems.

// Returns True if the functional subsystem exists in the configuration.
// Intended for calling an optional subsystem (conditional call) alongside "CommonClient.SubsystemExists". 
// A subsystem is considered functional if its "Include in command interface" check box is cleared.
//
// See also: CommonOverridable.OnDetermineDisabledSubsystems
// and Common.SubsystemExists to call from server-side code.
// 
//
// Parameters:
//  FullSubsystemName - String - the full name of the subsystem metadata object
//                        without the "Subsystem." part, case-sensitive.
//                        Example: "StandardSubsystems.ReportsOptions".
//
// Example:
//  If CommonClient.SubsystemExists("StandardSubsystems.ReportsOptions") Then
//  	ModuleReportsOptionsClient = CommonClient.CommonModule("ReportsOptionsClient");
//  	ModuleReportsOptionsClient.<Procedure name>();
//  EndIf;
//
// Returns:
//  Boolean
//
Function SubsystemExists(FullSubsystemName) Export
	
	ParameterName = "StandardSubsystems.ConfigurationSubsystems";
	If ApplicationParameters[ParameterName] = Undefined Then
		SubsystemsNames = StandardSubsystemsClient.ClientParametersOnStart().SubsystemsNames;
		ApplicationParameters.Insert(ParameterName, SubsystemsNames);
	EndIf;
	SubsystemsNames = ApplicationParameters[ParameterName];
	Return SubsystemsNames.Get(FullSubsystemName) <> Undefined;
	
EndFunction

// Returns a reference to a common module by name. 
// Intended for conditionally calling procedures and functions alongside "CommonClient.SubsystemExists".
// See also "CommonClient.CommonModule" for calling the server-side code.
//
// Parameters:
//  Name - String - The name of a common module. For example, "ConfigurationUpdateClient", "ReportsServerCall".
//
// Returns:
//  CommonModule
//
// Example:
//	If CommonClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
//		ModuleConfigurationUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
//		ModuleConfigurationUpdateClient.<Procedure name>();
//	EndIf;
//
Function CommonModule(Name) Export
	
	Module = Eval(Name);
	
#If Not WebClient Then
	
	// Skip for the web client (it has no modules of this type
	// when contacting the modules with a server call).
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Common module ""%1"" does not exist.';"), 
			Name);
	EndIf;
	
#EndIf
	
	Return Module;
	
EndFunction

#EndRegion

#Region CurrentEnvironment

////////////////////////////////////////////////////////////////////////////////
// The details functions of the current client application environment and operating system.

// Returns True if the client application is running on Windows.
//
// See Common.IsWindowsClient
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsWindowsClient() Export
	
	ClientPlatformType = ClientPlatformType();
	Return ClientPlatformType = PlatformType.Windows_x86
		Or ClientPlatformType = PlatformType.Windows_x86_64;
	
EndFunction

// Returns True if the client application is running on Linux.
//
// See Common.IsLinuxClient
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsLinuxClient() Export
	
	SystemInfo = New SystemInfo;
	ClientPlatformType = SystemInfo.PlatformType;
	
#If MobileClient Then
	Return ClientPlatformType = PlatformType.Linux_x86
		Or ClientPlatformType = PlatformType.Linux_x86_64;
#EndIf
	
	Return ClientPlatformType = PlatformType.Linux_x86
		Or ClientPlatformType = PlatformType.Linux_x86_64
		Or CommonClientServer.CompareVersions(SystemInfo.AppVersion, "8.3.22.1923") >= 0
			And (ClientPlatformType = PlatformType["Linux_ARM64"]
			Or ClientPlatformType = PlatformType["Linux_E2K"]);
	
EndFunction

// Returns True if the client application is running on macOS.
//
// See Common.IsMacOSClient
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsMacOSClient() Export
	
	ClientPlatformType = ClientPlatformType();
	Return ClientPlatformType = PlatformType.MacOS_x86
		Or ClientPlatformType = PlatformType.MacOS_x86_64;
	
EndFunction

// Returns True if a client application is connected to the infobase through a web server.
//
// See Common.ClientConnectedOverWebServer
//
// Returns:
//  Boolean - True if the application is connected.
//
Function ClientConnectedOverWebServer() Export
	
	Return StrFind(Upper(InfoBaseConnectionString()), "WS=") = 1;
	
EndFunction

// Returns True if debug mode is enabled.
//
// See Common.DebugMode
//
// Returns:
//  Boolean - True if debug mode is enabled.
//
Function DebugMode() Export
	
	Return StrFind(LaunchParameter, "DebugMode") > 0;
	
EndFunction

// Returns the amount of RAM available to the client application.
//
// See Common.RAMAvailableForClientApplication
//
// Returns:
//  Number - the number of GB of RAM, with tenths-place accuracy.
//  Undefined - no client application is available, meaning CurrentRunMode() = Undefined.
//
Function RAMAvailableForClientApplication() Export
	
	SystemInfo = New SystemInfo;
	Return Round(SystemInfo.RAM / 1024, 1);
	
EndFunction

// Determines the infobase mode: file (True) or client/server (False).
// This function uses the InfobaseConnectionString parameter. You can specify this parameter explicitly.
//
// See Common.FileInfobase
//
// Parameters:
//  InfoBaseConnectionString - String - the parameter is applied if
//                 you need to check a connection string for another infobase.
//
// Returns:
//  Boolean - True if it is a file infobase.
//
Function FileInfobase(Val InfoBaseConnectionString = "") Export
	
	If Not IsBlankString(InfoBaseConnectionString) Then
		Return StrFind(Upper(InfoBaseConnectionString), "FILE=") = 1;
	EndIf;
	
	Return StandardSubsystemsClient.ClientParameter("FileInfobase");
	
EndFunction

// Returns the client platform type.
//
// Returns:
//  PlatformType, Undefined - the type of the platform running a client. In the web client mode, if the actual platform 
//                               type does not match the PlatformType value, returns Undefined.
//
Function ClientPlatformType() Export
	
	SystemData = New SystemInfo;
	Return SystemData.PlatformType;
	
EndFunction

// Returns the data separation mode flag
// (conditional separation).
// 
// Returns False if the configuration does not support data separation mode
// (does not contain attributes to share).
//
// Returns:
//  Boolean - True if data separation is enabled,
//           False is separation is disabled or not supported.
//
Function DataSeparationEnabled() Export
	
	Return StandardSubsystemsClient.ClientParameter("DataSeparationEnabled");
	
EndFunction

// Returns a flag indicating whether separated data (included in the separators) can be accessed.
// The flag is session-specific, but can change its value if data separation is enabled
// on the session run. So, check the flag right before addressing the shared data.
// 
// Returns If True, the configuration does not support data separation mode
// (does not contain attributes to share).
//
// Returns:
//   Boolean - True if separation is not supported or disabled
//                    or separation is enabled and separators are set.
//            False if separation is enabled and separators are not set.
//
Function SeparatedDataUsageAvailable() Export
	
	Return StandardSubsystemsClient.ClientParameter("SeparatedDataUsageAvailable");
	
EndFunction

#EndRegion

#Region Dates

////////////////////////////////////////////////////////////////////////////////
// Functions to work with dates considering the session time zone

// Returns current date in the session time zone.
// It is designed to be used instead of CurrentDate() function in client-side code
// in cases when it is impossible to transfer algorithm into server-side code.
//
// The returned time is close to the CurrentSessionDate function result in server-side code.
// The time inaccuracy is associated with the server call execution time.
// Besides, if you set the time on the client computer, the function will not take this change 
// into account immediately, but only after you again clear the cache of reused values.
// (See also: UpdateCachedValues).
// What is why the algorithms for which the exact time is crucially important must be placed in server-side code
// rather than in the client-side code.
//
// Returns:
//  Date - a current session date.
//
Function SessionDate() Export
	
	Adjustment = StandardSubsystemsClient.ClientParameter("SessionTimeOffset");
	Return CurrentDate() + Adjustment; // ACC:143 - CurrentDate() is required to calculate the session time
	
EndFunction

// Returns the GMT session date converted from the local session date.
//
// The returned time is close to the ToUniversalTime() function result in the server context.
// The time inaccuracy is associated with the server call execution time.
// The function replaced the obsolete function ToUniversalTime().
//
// Returns:
//  Date - the universal session date.
//
Function UniversalDate() Export
	
	ClientParameters = StandardSubsystemsClient.ClientParameter();
	
	SessionDate = CurrentDate() + ClientParameters.SessionTimeOffset;
	Return SessionDate + ClientParameters.UniversalTimeCorrection;
	
EndFunction

// Convert a local date to the "YYYY-MM-DDThh:mm:ssTZD" format (ISO 8601).
//
// See Common.LocalDatePresentationWithOffset
//
// Parameters:
//  LocalDate - Date - a date in the session time zone.
// 
// Returns:
//   String - date presentation.
//
Function LocalDatePresentationWithOffset(LocalDate) Export
	
	Offset = StandardSubsystemsClient.ClientParameter("StandardTimeOffset");
	Return CommonInternalClientServer.LocalDatePresentationWithOffset(LocalDate, Offset);
	
EndFunction

#EndRegion

#Region Data

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions for applied types and value collections.

// Creates a complete recursive copy of a structure, map, array, list, or value table consistent
// with the child item type. For object-type values
// (for example, CatalogObject or DocumentObject), the procedure returns references to the source objects instead of copying the content.
//
// See Common.CopyRecursive
//
// Parameters:
//  Source - Structure
//           - FixedStructure
//           - Map
//           - FixedMap
//           - Array
//           - FixedArray
//           - ValueList - an object that needs to be copied.
//  FixData - Boolean
//                    - Undefined - if it is True, then fix,
//                          if it is False, remove the fixing, if it is Undefined, do not change.
//
// Returns:
//  Structure
//  FixedStructure,
//  Map
//  FixedMap
//  Array
//  FixedArray
//  ValueList - Copy of the object passed in the Source parameter.
//
Function CopyRecursive(Source, FixData = Undefined) Export
	
	Var Receiver;
	
	SourceType = TypeOf(Source);
	
	If SourceType = Type("Structure")
		Or SourceType = Type("FixedStructure") Then
		Receiver = CommonInternalClient.CopyStructure(Source, FixData);
	ElsIf SourceType = Type("Map")
		Or SourceType = Type("FixedMap") Then
		Receiver = CommonInternalClient.CopyMap(Source, FixData);
	ElsIf SourceType = Type("Array")
		Or SourceType = Type("FixedArray") Then
		Receiver = CommonInternalClient.CopyArray(Source, FixData);
	ElsIf SourceType = Type("ValueList") Then
		Receiver = CommonInternalClient.CopyValueList(Source, FixData);
	Else
		Receiver = Source;
	EndIf;
	
	Return Receiver;
	
EndFunction

// Checking that the Parameter command contains an ExpectedType object.
// Otherwise, returns False and displays the standard user message.
// This situation is possible, for example, when a row that contains a group is selected in a list.
//
// Application: commands that manage dynamic list items in forms.
// 
// Parameters:
//  Parameter     - Array
//               - AnyRef - the command parameter.
//  ExpectedType - Type                 - the expected type.
//
// Returns:
//  Boolean - True if the parameter type matches the expected type.
//
// Example:
// 
//   If NOT CommonClient.CheckCommandParameterType(
//      Items.List.SelectedRows, Type("TaskRef.PerformerTask")) Then
//      Return;
//   EndIf;
//   …
//
Function CheckCommandParameterType(Val Parameter, Val ExpectedType) Export
	
	If Parameter = Undefined Then
		Return False;
	EndIf;
	
	Result = True;
	
	If TypeOf(Parameter) = Type("Array") Then
		// Checking whether the array contains only one element, and its type does not match the expected type.
		Result = Not (Parameter.Count() = 1 And TypeOf(Parameter[0]) <> ExpectedType);
	Else
		Result = TypeOf(Parameter) = ExpectedType;
	EndIf;
	
	If Not Result Then
		ShowMessageBox(,NStr("en = 'The object does not support this type of operations.';"));
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Forms

////////////////////////////////////////////////////////////////////////////////
// Common client procedures to work with forms.

// Asks whether the user wants to continue the action that will discard the changes:
// "Data was changed. Save the changes?" 
// Use in form modules BeforeClose event handlers of the objects
// that can be written to infobase.
// The message presentation depends on the form modification property.
// 
// See also: CommonClient.ShowArbitraryFormClosingConfirmation.
//
// Parameters:
//  SaveAndCloseNotification  - NotifyDescription - name of the procedure to be called once the OK button is clicked.
//  Cancel                        - Boolean - a return parameter that indicates whether the action is canceled.
//  Exit             - Boolean - Indicates whether the form closes when a user exits the application.
//  WarningText          - String - the warning message text. The default text is:
//                                          "The data was changed. Do you want to save the changes?"
//  WarningTextOnExit - String - a return parameter that contains a warning text displayed to users 
//                                          when they exit the application. If the parameter is specified, text
//                                          "Data was changed. All changes will be lost." is returned.
//
// Example:
//
//  &AtClient
//  Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
//    Notification = New NotifyDescription("SelectAndClose", ThisObject);
//    CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
//  EndProcedure
//  
//  &AtClient
//  Procedure SelectAndClose(Result= Undefined, AdditionalParameters = Undefined) Export
//     // Writing form data.
//     // …
//     Modified = False; // Do not show form closing notification again.
//     Close(<SelectionResult>);
//  EndProcedure
//
Procedure ShowFormClosingConfirmation(
		Val SaveAndCloseNotification, 
		Cancel, 
		Val Exit, 
		Val WarningText = "", 
		WarningTextOnExit = Undefined) Export
	
	Form = SaveAndCloseNotification.Module;
	If Not Form.Modified Then
		Return;
	EndIf;
	
	Cancel = True;
	
	If Exit Then
		If WarningTextOnExit = "" Then // Parameter from BeforeClose is passed.
			WarningTextOnExit = NStr("en = 'The data has been changed. All changes will be lost.';");
		EndIf;
		Return;
	EndIf;
	
	Parameters = New Structure();
	Parameters.Insert("SaveAndCloseNotification", SaveAndCloseNotification);
	Parameters.Insert("WarningText", WarningText);
	
	ParameterName = "StandardSubsystems.FormClosingConfirmationParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	
	CurrentParameters = ApplicationParameters["StandardSubsystems.FormClosingConfirmationParameters"];
	If CurrentParameters <> Undefined
	   And CurrentParameters.SaveAndCloseNotification.Module = Parameters.SaveAndCloseNotification.Module Then
		Return;
	EndIf;
	
	ApplicationParameters["StandardSubsystems.FormClosingConfirmationParameters"] = Parameters;
	
	Form.Activate();
	AttachIdleHandler("ConfirmFormClosingNow", 0.1, True);
	
EndProcedure

// Asks whether the user wants to proceed the action, which will make the form close.
// Intended for the BeforeClose event handlers in form modules.
// See also: CommonClient.ShowFormClosingConfirmation.
//
// Parameters:
//  Form                        - ClientApplicationForm - the form that calls the warning dialog.
//  Cancel                        - Boolean - a return parameter that indicates whether the action is canceled.
//  Exit             - Boolean - Indicates whether the application will be closed.
//  WarningText          - String - the warning message text.
//  CloseFormWithoutConfirmationAttributeName - String - the name of the flag attribute that indicates whether
//                                 to show the warning.
//  CloseNotifyDescription    - NotifyDescription - name of the procedure to be called once the OK button is clicked.
//
// Example: 
//  WarningText = NStr("en = 'Close the wizard?'");
//  CommonClient.ShowArbitraryFormClosingConfirmation(
//      ThisObject, Cancel, Exit, MessageText, "CloseFormWithoutConfirmation");
//
Procedure ShowArbitraryFormClosingConfirmation(
		Val Form, 
		Cancel, 
		Val Exit, 
		Val WarningText, 
		Val CloseFormWithoutConfirmationAttributeName, 
		Val CloseNotifyDescription = Undefined) Export
		
	If Form[CloseFormWithoutConfirmationAttributeName] Then
		Return;
	EndIf;
	
	Cancel = True;
	If Exit Then
		Return;
	EndIf;
	
	Parameters = New Structure();
	Parameters.Insert("Form", Form);
	Parameters.Insert("WarningText", WarningText);
	Parameters.Insert("CloseFormWithoutConfirmationAttributeName", CloseFormWithoutConfirmationAttributeName);
	Parameters.Insert("CloseNotifyDescription", CloseNotifyDescription);
	
	ParameterName = "StandardSubsystems.FormClosingConfirmationParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters["StandardSubsystems.FormClosingConfirmationParameters"] = Parameters;
	
	AttachIdleHandler("ConfirmArbitraryFormClosingNow", 0.1, True);
	
EndProcedure

// Updates the application interface keeping the current active window.
//
Procedure RefreshApplicationInterface() Export
	
	CurrentActiveWindow = ActiveWindow();
	RefreshInterface();
	If CurrentActiveWindow <> Undefined Then
		CurrentActiveWindow.Activate();
	EndIf;
	
EndProcedure

// Notifies opened forms and dynamic lists about changes in a single object.
//
// Parameters:
//  Source - AnyRef
//           - InformationRegisterRecordKeyInformationRegisterName
//           - AccumulationRegisterRecordKeyAccumulationRegisterName
//           - AccountingRegisterRecordKeyAccountingRegisterName
//           - CalculationRegisterRecordKeyCalculationRegisterName - the reference of the changed object or the key of the changed register 
//                 record whose update status must be provided to dynamic lists and forms.
//  AdditionalParameters - Arbitrary - parameters to be passed in the Notify method.
//
Procedure NotifyObjectChanged(Source, Val AdditionalParameters = Undefined) Export
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Structure;
	EndIf;
	Notify("Record_" + CommonInternalClient.MetadataObjectName(TypeOf(Source)), AdditionalParameters, Source);
	NotifyChanged(Source);
EndProcedure

// Notifies opened forms and dynamic lists about changes in multiple objects.
//
// Parameters:
//  Source - Type
//           - TypeDescription - object type or types, whose update status to be provided to 
//                             dynamic lists and forms;
//           - Array - a list of changed references or register record keys, 
//                      whose update status to be provided to dynamic lists and forms.
//  AdditionalParameters - Arbitrary - parameters to be passed in the Notify method.
//
Procedure NotifyObjectsChanged(Source, Val AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Structure;
	EndIf;
	
	If TypeOf(Source) = Type("Type") Then
		NotifyChanged(Source);
		Notify("Record_" + CommonInternalClient.MetadataObjectName(Source), AdditionalParameters);
	ElsIf TypeOf(Source) = Type("TypeDescription") Then
		For Each Type In Source.Types() Do
			NotifyChanged(Type);
			Notify("Record_" + CommonInternalClient.MetadataObjectName(Type), AdditionalParameters);
		EndDo;
	ElsIf TypeOf(Source) = Type("Array") Then
		If Source.Count() = 1 Then
			NotifyObjectChanged(Source[0], AdditionalParameters);
		Else
			NotifiedTypes = New Map;
			For Each Ref In Source Do
				NotifiedTypes.Insert(TypeOf(Ref));
			EndDo;
			For Each Type In NotifiedTypes Do
				NotifyChanged(Type.Key);
				Notify("Record_" + CommonInternalClient.MetadataObjectName(Type.Key), AdditionalParameters);
			EndDo;
		EndIf;
	EndIf;

EndProcedure

// Opens an attachment format selection form.
//
// Parameters:
//  NotifyDescription  - NotifyDescription - a choice result handler.
//  FormatSettings - Structure - default settings in the form of:
//   * PackToArchive   - Boolean - shows whether it is necessary to archive attachments.
//   * SaveFormats - Array - a list of the selected save formats.
//   * TransliterateFilesNames - Boolean - convert Cyrillic characters into the Latin ones.
//  Owner - ClientApplicationForm - the form from which the attachment selection form is called.
//
Procedure ShowAttachmentsFormatSelection(NotifyDescription, FormatSettings, Owner = Undefined) Export
	FormParameters = New Structure("FormatSettings", FormatSettings);
	OpenForm("CommonForm.SelectAttachmentFormat", FormParameters, , , , ,
		NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

#EndRegion

#Region EditingForms

////////////////////////////////////////////////////////////////////////////////
// Functions handling user actions related to
// multiline text edition (for example, document comments).

// Opens the multiline text edit form.
//
// Parameters:
//  ClosingNotification1     - NotifyDescription - the details of the procedure to be called 
//                            when the text entry form is closed. Contains the same parameters as method
//                            ShowInputString.
//  MultilineText      - String - a text to be edited;
//  Title               - String - the text to be displayed in the from title.
//
// Example:
//
//   Notification = New NotifyDescription("CommentEndEntering", ThisObject);
//   CommonClient.FormMultilineTextEditingShow(Notification, Item.EditingText);
//
//   &AtClient
//   Procedure CommentEndEntering(Val EnteredText, Val AdditionalParameters) Export
//      If EnteredText = Undefined Then
//		   Return;
//   	EndIf;	
//	
//	   Object.MultilineComment = EnteredText;
//	   Modified = True;
//   EndProcedure
//
Procedure ShowMultilineTextEditingForm(Val ClosingNotification1, 
	Val MultilineText, Val Title = Undefined) Export
	
	If Title = Undefined Then
		ShowInputString(ClosingNotification1, MultilineText,,, True);
	Else
		ShowInputString(ClosingNotification1, MultilineText, Title,, True);
	EndIf;
	
EndProcedure

// Opens the multiline comment editing form.
//
// Parameters:
//  MultilineText - String - a text to be edited.
//  OwnerForm      - ClientApplicationForm - the form that owns the field a user entering a comment into.
//  AttributeName       - String - the name of the form attribute the user comment will be stored to.
//                                The default value is Object.Comment.
//  Title          - String - the text to be displayed in the from title.
//                                The default value is Comment.
//
// Example:
//  CommonClient.ShowCommentEditingForm(
//  	Item.EditingText, ThisObject, Object.Comment);
//
Procedure ShowCommentEditingForm(
	Val MultilineText, 
	Val OwnerForm, 
	Val AttributeName = "Object.Comment", 
	Val Title = Undefined) Export
	
	Context = New Structure;
	Context.Insert("OwnerForm", OwnerForm);
	Context.Insert("AttributeName", AttributeName);
	
	Notification = New NotifyDescription(
		"CommentInputCompletion", 
		CommonInternalClient, 
		Context);
	
	FormCaption = ?(Title <> Undefined, Title, NStr("en = 'Comment';"));
	
	ShowMultilineTextEditingForm(Notification, MultilineText, FormCaption);
	
EndProcedure

#EndRegion

#Region UserSettings

// Saves personal application user settings.
//
// Parameters:
//  Settings - Structure:
//   * RemindAboutFileSystemExtensionInstallation  - Boolean - the flag indicating whether
//                                                               to notify users on extension installation.
//   * AskConfirmationOnExit - Boolean - the flag indicating whether to ask confirmation before the user exits the application.
//
Procedure SavePersonalSettings(Settings) Export
	
	If Settings.Property("RemindAboutFileSystemExtensionInstallation") Then
		ApplicationParameters["StandardSubsystems.SuggestFileSystemExtensionInstallation"] = 
			Settings.RemindAboutFileSystemExtensionInstallation;
	EndIf;
	
	If Settings.Property("AskConfirmationOnExit") Then
		StandardSubsystemsClient.SetClientParameter("AskConfirmationOnExit",
			Settings.AskConfirmationOnExit);
	EndIf;
		
	If Settings.Property("PersonalFilesOperationsSettings") Then
		StandardSubsystemsClient.SetClientParameter("PersonalFilesOperationsSettings",
			Settings.PersonalFilesOperationsSettings);
	EndIf;
	
EndProcedure

#EndRegion

#Region Styles

////////////////////////////////////////////////////////////////////////////////
// Functions to manage style colors in the client code.

// Gets the style color by a style item name.
//
// Parameters:
//  StyleColorName - String
//
// Returns:
//  Color
//
Function StyleColor(StyleColorName) Export
	
	Return CommonClientCached.StyleColor(StyleColorName);
	
EndFunction

// Gets the style color by a style item name.
//
// Parameters:
//  StyleFontName - String
//
// Returns:
//  Font
//
Function StyleFont(StyleFontName) Export
	
	Return CommonClientCached.StyleFont(StyleFontName);
	
EndFunction

#EndRegion

#Region AddIns

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to connect and install add-ins from configuration templates.

// Returns a structure of parameters for the AttachAddInFromTemplate procedure.
//
// Returns:
//  Structure:
//      * Cached           - Boolean - use component caching on the client (the default value is True).
//      * SuggestInstall - Boolean - (default value is True) prompt to install.
//      * SuggestToImport  - Boolean - (default value is False) prompt to import the add-in from the ITS website.
//      * ExplanationText       - String - a text that describes the add-in purpose and which functionality requires the add-in.
//      * ObjectsCreationIDs - Array - the creation IDs of object module instances.
//                 Applicable only with add-ins that have a number of object creation IDs.
//                 Ignored if the ID parameter is specified.
//      * Isolated - Boolean, Undefined - If True, the add-in is attached isolatedly (it is uploaded to a separate OS process).
//                 If False, the add-in is executed in the same OS process that runs the 1C:Enterprise code.
//                 If Undefined, the add-in is executed according to the default 1C:Enterprise settings
//                 Isolatedly if the add-in supports only isolated execution; otherwise, non-isolatedly.:
//                 By default, Undefined.
//                 See https://its.1c.eu/db/v83doc
//                                              #bookmark:dev:TI000001866
//      * AutoUpdate - Boolean - Flag indicating whether UpdateFrom1CITSPortal will be set to True, 
//                 if SuggestToImport is set to True. By default, True.
//
//
// Example:
//
//  AttachmentParameters = CommonClient.AddInAttachmentParameters();
//  AttachmentParameters.ExplanationText = NStr("en = 'To use a barcode scanner, install
//                                             |the add-in 1C:Barcode scanners (NativeApi).'");
//
Function AddInAttachmentParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("Cached", True);
	Parameters.Insert("SuggestInstall", True);
	Parameters.Insert("SuggestToImport", False);
	Parameters.Insert("ExplanationText", "");
	Parameters.Insert("ObjectsCreationIDs", New Array);
	Parameters.Insert("Isolated", Undefined);
	Parameters.Insert("AutoUpdate", True);
	
	Return Parameters;
	
EndFunction

// Connects an add-in based on Native API and COM technology in an asynchronous mode.
// The add-inn must be stored in the configuration template in as a ZIP file.
// Web client can display dialog with installation tips.
//
// Parameters:
//  Notification - NotifyDescription - connection notification details with the following parameters:
//      * Result - Structure - add-in attachment result:
//          ** Attached         - Boolean - attachment flag.
//          ** Attachable_Module - AddInObject  - an instance of the add-in;
//                                - FixedMap of KeyAndValue - Add-in object instances stored in 
//                                     AttachmentParameters.ObjectsCreationIDs:
//                                    *** Key - String - the add-in ID;
//                                    *** Value - AddInObject - object instance.
//          ** Location     - String - Template name or add-in URL if the add-in has a later version.
//                                           
//          ** SymbolicName   - String - The symbolic name that was specified when attaching the add-in.
//               Pass the symbolic name and location of the add-in to the 1C:Enterprise method
//               "CheckAddInAttachment" to verify if the add-in is attached.
//               
//          ** ErrorDescription     - String - brief error message. Empty string on cancel by user.
//      * AdditionalParameters - Structure - a value that was specified on creating the NotifyDescription object.
//  Id        - String - the add-in identification code.
//  FullTemplateName      - String - the full name of the template used as the add-in location.
//  ConnectionParameters - Structure
//                       - Undefined - see the AddInAttachmentParameters function.
//
// Example:
//
//  Notification = New NotifyDescription("AttachAddInSSLCompletion", ThisObject);
//
//  AttachmentParameters = CommonClient.AddInAttachmentParameters();
//  AttachmentParameters.ExplanationText = NStr("en = 'To apply for the certificate,
//                                             install the CryptS add-in.'");
//
//  CommonClient.AttachAddInFromTemplate(Notification, 
//      "CryptS",
//      "DataProcessor.ApplicationForNewQualifiedCertificateIssue.Template.ExchangeComponent",
//      AttachmentParameters);
//
//  &AtClient
//  Procedure AttachAddInSSLCompletion(Result, AdditionalParameters) Export
//
//      AttachableModule = Undefined;
//
//      If Result.Attached Then 
//          AttachableModule = Result.AttachableModule;
//      Else
//          If Not IsBlankString(Result.ErrorDetails) Then
//              ShowMessageBox (, Result.ErrorDetails);
//          EndIf;
//      EndIf;
//
//      If AttachableModule <> Undefined Then 
//          // AttachableModule contains the instance of the attached add-in.
//      EndIf;
//
//      AttachableModule = Undefined;
//
//  EndProcedure
//
Procedure AttachAddInFromTemplate(Notification, Id, FullTemplateName,
	ConnectionParameters = Undefined) Export
	
	Parameters = AddInAttachmentParameters();
	If ConnectionParameters <> Undefined Then
		FillPropertyValues(Parameters, ConnectionParameters);
	EndIf;
	
	Context = CommonInternalClient.AddInAttachmentContext();
	FillPropertyValues(Context, Parameters);
	Context.Notification = Notification;
	Context.Id = Id;
	Context.Location = FullTemplateName;
	
	CommonInternalClient.AttachAddInSSL(Context);
	
EndProcedure

// Returns a structure of parameters for the InstallAddInFromTemplate procedure.
//
// Returns:
//  Structure:
//      * ExplanationText - String - a text that describes the add-in purpose and which functionality requires the add-in.
//
// Example:
//
//  InstallationParameters = CommonClient.AddInInstallParameters();
//  InstallationParameters.ExplanationText = NStr("en = 'To use a barcode scanner, install
//                                           |the add-in 1C:Barcode scanners (NativeApi).'");
//
Function AddInInstallParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("ExplanationText", "");
	
	Return Parameters;
	
EndFunction

// Connects an add-in based on Native API and COM technology in an asynchronous mode.
// The add-inn must be stored in the configuration template in as a ZIP file.
//
// Parameters:
//  Notification - NotifyDescription - notification details of add-in installation:
//      * Result - Structure - Install component result:
//          ** IsSet    - Boolean - Installation flag.
//          ** ErrorDescription - String - brief error message. Empty string on cancel by user.
//      * AdditionalParameters - Structure - a value that was specified on creating the NotifyDescription object.
//  FullTemplateName    - String                  - the full name of the template used as the add-in location.
//  InstallationParameters - Structure
//                     - Undefined - see the AddInInstallParameters function.
//
// Example:
//
//  Notification = New NotifyDescription("SetCompletionComponent", ThisObject);
//
//  InstallationParameters = CommonClient.AddInInstallParameters();
//  InstallationParameters.ExplanationText = NStr("en = 'To apply for the certificate,
//                                           install the CryptS add-in.'");
//
//  CommonClient.InstallAddInFromTemplate(Notification,
//      "DataProcessor.ApplicationForNewQualifiedCertificateIssue.Template.ExchangeComponent",
//      InstallationParameters);
//
//  &AtClient
//  Procedure InstallAddInEnd(Result, AdditionalParameters) Export
//
//      If Not Result.Installed and Not EmptyString(Result.ErrorDetails) Then 
//          ShowMessageBox (, Result.ErrorDetails);
//      EndIf;
//
//  EndProcedure
//
Procedure InstallAddInFromTemplate(Notification, FullTemplateName, InstallationParameters = Undefined) Export
	
	Parameters = AddInInstallParameters();
	If InstallationParameters <> Undefined Then
		FillPropertyValues(Parameters, InstallationParameters);
	EndIf;
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("Location", FullTemplateName);
	Context.Insert("ExplanationText", Parameters.ExplanationText);
	Context.Insert("Id", FullTemplateName);
	
	CommonInternalClient.InstallAddInSSL(Context);
	
EndProcedure

#Region ForCallsFromOtherSubsystems

// ConnectedHardwareLibrary
// 
// Connects an add-in based on Native API and COM technology in an asynchronous mode.
// The add-inn must be stored in the configuration template in as a ZIP file.
//
// Parameters:
//  FullTemplateName    - String                  - the full name of the template used as the add-in location.
//  InstallationParameters - Structure
//                     - Undefined - see the AddInInstallParameters function.
//
// Returns:
//		Structure - Add-in installation result:
//          * IsSet    - Boolean - Installation flag.
//          * ErrorDescription - String - brief error message. Empty string on cancel by user.
//
Async Function InstallAddInFromTemplateAsync(FullTemplateName, InstallationParameters = Undefined) Export
	
	Parameters = AddInInstallParameters();
	If InstallationParameters <> Undefined Then
		FillPropertyValues(Parameters, InstallationParameters);
	EndIf;
	
	Context = New Structure;
	Context.Insert("Location", FullTemplateName);
	Context.Insert("ExplanationText", Parameters.ExplanationText);
	Context.Insert("Id", FullTemplateName);
	
	Return Await CommonInternalClient.InstallAddInSSLAsync(Context);
	
EndFunction

// Attaches an add-in based on Native API and COM technology in an asynchronous mode.
// The add-inn must be stored in the configuration template in as a ZIP file.
//
// Parameters:
//  Id        - String - the add-in identification code.
//  FullTemplateName      - String - the full name of the template used as the add-in location.
//  ConnectionParameters - Structure
//                       - Undefined - See AddInAttachmentParameters.
//
// Returns:
// 	 Structure - Add-in attachment result:
//    * Attached         - Boolean - attachment flag.
//    * Attachable_Module - AddInObject  - an instance of the add-in;
//                         - FixedMap of KeyAndValue - Add-in object instances stored in 
//                           AttachmentParameters.ObjectsCreationIDs:
//                             ** Key - String - the add-in ID;
//                             ** Value - AddInObject - object instance.
//    * Location     - String - Template name or add-in URL if the add-in has a later version.
//                                    
//    * SymbolicName   - String - The symbolic name that was specified when attaching the add-in.
//         Pass the symbolic name and location of the add-in to the 1C:Enterprise method
//         "CheckAddInAttachment" to verify if the add-in is attached.
//    * ErrorDescription     - String - brief error message. Empty string on cancel by user.
//
Async Function AttachAddInFromTemplateAsync(Id, FullTemplateName,
	ConnectionParameters = Undefined) Export
	
	Parameters = AddInAttachmentParameters();
	If ConnectionParameters <> Undefined Then
		FillPropertyValues(Parameters, ConnectionParameters);
	EndIf;
	
	Context = CommonInternalClient.AddInAttachmentContext();
	FillPropertyValues(Context, Parameters);
	Context.Id = Id;
	Context.Location = FullTemplateName;
	
	Return Await CommonInternalClient.AttachAddInSSLAsync(Context);
	
EndFunction

// End ConnectedHardwareLibrary

#EndRegion

#EndRegion

#Region ExternalConnection

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for managing external connections.

// Registers the comcntr.dll component for the current platform version.
// If the registration is successful, the procedure suggests the user to restart the client session 
// in order to registration takes effect.
//
// Is called before a client script that uses the COM connection manager (V83.COMConnector)
// and is initiated by interactive user actions.
// 
// Parameters:
//  RestartSession - Boolean - If True, after the COM connector is registered,
//      the session restart dialog box is called.
//  Notification - NotifyDescription - notification on registration result:
//      * IsRegistered - Boolean - True if the COM connector is registered without errors.
//      * AdditionalParameters - Arbitrary - a value that was specified 
//            when creating the NotifyDescription object.
//
// Example:
//  RegisterCOMConnector();
//
Procedure RegisterCOMConnector(Val RestartSession = True, 
	Val Notification = Undefined) Export
	
	Context = New Structure;
	Context.Insert("RestartSession", RestartSession);
	Context.Insert("Notification", Notification);
	
	If CommonInternalClient.RegisterCOMConnectorRegistrationIsAvailable() Then 
	
		ApplicationStartupParameters = FileSystemClient.ApplicationStartupParameters();
#If Not WebClient And Not MobileClient Then
		ApplicationStartupParameters.CurrentDirectory = BinDir();
#EndIf
		ApplicationStartupParameters.Notification = New NotifyDescription(
			"RegisterCOMConnectorOnCheckRegistration", CommonInternalClient, Context);
		ApplicationStartupParameters.WaitForCompletion = True;
		
		CommandText = "regsvr32.exe /n /i:user /s comcntr.dll";
		
		FileSystemClient.StartApplication(CommandText, ApplicationStartupParameters);
		
	Else 
		
		CommonInternalClient.RegisterCOMConnectorNotifyOnError(Context);
		
	EndIf;
	
EndProcedure

// Establishes an external infobase connection with the passed parameters and returns it.
//
// See Common.EstablishExternalConnectionWithInfobase.
//
// Parameters:
//  Parameters - See CommonClientServer.ParametersStructureForExternalConnection
// 
// Returns:
//  Structure:
//    * Join - COMObject
//                 - Undefined - if the connection is established, returns a COM object reference. Otherwise, returns Undefined;
//    * BriefErrorDetails - String - brief error description;
//    * DetailedErrorDetails - String - detailed error description;
//    * AddInAttachmentError - Boolean - a COM connection error flag.
//
Function EstablishExternalConnectionWithInfobase(Parameters) Export
	
	ConnectionNotAvailable = IsLinuxClient() Or IsMacOSClient();
	BriefErrorDetails = NStr("en = 'Only Windows clients support direct infobase connections.';");
	
	Return CommonInternalClientServer.EstablishExternalConnectionWithInfobase(Parameters, ConnectionNotAvailable, BriefErrorDetails);
	
EndFunction

#EndRegion

#Region Backup

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for backup in the user mode.

// Checks whether the backup can be done in the user mode.
//
// Returns:
//  Boolean - True if the installation prompt is on.
//
Function PromptToBackUp() Export
	
	Result = False;
	SSLSubsystemsIntegrationClient.OnCheckIfCanBackUpInUserMode(Result);
	Return Result;
	
EndFunction

// Prompt users for back up.
Procedure PromptUserToBackUp() Export
	
	SSLSubsystemsIntegrationClient.OnPromptUserForBackup();
	
EndProcedure

#EndRegion
#Region ObsoleteProceduresAndFunctions

// Deprecated. Instead, use:
//  FileSystemClient.OpenURL to pass a URL or a website link.
//  FileSystemClient.OpenExplorer to open the directory in the Explorer.
//  FileSystemClient.OpenFile to open a file by the extension when passing the file path.
//
// Follows a link to visit an infobase object or an external object.
// For example, a website link or a directory path on the computer.
//
// Parameters:
//  Ref - String - a link to follow.
//
Procedure GoToLink(Ref) Export
	
#If ThickClientOrdinaryApplication Then
		// 1C:Enterprise design aspect: GotoURL is not supported by ordinary applications running in the thick client mode.
		Notification = New NotifyDescription;
		BeginRunningApplication(Notification, Ref);
#Else
		GotoURL(Ref);
#EndIf
	
EndProcedure

// Deprecated. Instead, use FileSystemClient.AttachFileOperationsExtension
// Prompts the user to install 1C:Enterprise Extension in the web client.
// Incorporate the procedure at the beginning of code areas that process files.
//
// Parameters:
//   OnCloseNotifyDescription    - NotifyDescription - the description of the procedure
//                                    to be called once a form is closed. Parameters:
//                                      ExtensionAttached - Boolean - True if the extension is attached.
//                                      AdditionalParameters - Arbitrary - the parameters specified in
//                                                                               OnCloseNotifyDescription.
//   SuggestionText                - String - the message text. If the text is not specified, the default text is displayed.
//   CanContinueWithoutInstalling - Boolean - If True, displays the ContinueWithoutInstalling button.
//                                              If False, displays the Cancel button.
//
// Example:
//
//    Notification = New NotifyDescription("PrintDocumentCompletion", ThisObject);
//    MessageText = NStr("en = 'To print the document, install 1C:Enterprise Extension.'");
//    CommonClient.ShowFileSystemExtensionInstallationQuestion(Notification, MessageText);
//
//    Procedure PrintDocumentCompletion(ExtensionAttached, AdditionalParameters) Export
//      If ExtensionAttached Then
//        // Script that prints a document only if the extension is attached.
//        // …
//      Else
//        // Script that prints a document if the extension is not attached.
//        // …
//      EndIf;
//
Procedure ShowFileSystemExtensionInstallationQuestion(
		OnCloseNotifyDescription, 
		SuggestionText = "", 
		CanContinueWithoutInstalling = True) Export
	
	FileSystemClient.AttachFileOperationsExtension(
		OnCloseNotifyDescription, 
		SuggestionText, 
		CanContinueWithoutInstalling);
	
EndProcedure

// Deprecated. Instead, use FileSystemClient.AttachFileOperationsExtension
// Prompts the user to attach 1C:Enterprise Extension in the web client and, if the user refuses, displays a warning that it is impossible to proceed.
// Incorporate the procedure at the beginning of code areas that deal with files that require this extension.
// 
// 
//
// Parameters:
//  OnCloseNotifyDescription - NotifyDescription - the description of the procedure to be called if the extension
//                                                     is attached. Parameters:
//                                                      Result - Boolean - always True.
//                                                      AdditionalParameters - Undefined
//  SuggestionText    - String - Text of the prompt to attach 1C:Enterprise Extension. 
//                                 If not specified, the default text appears.
//  WarningText - String - warning text that notifies the user that the action cannot be continued. 
//                                 If the text is not specified, the default text is displayed.
//
// Example:
//
//    Notification = New NotifyDescription("PrintDocumentCompletion", ThisObject);
//    MessageText = NStr("en = 'To print the document, install 1C:Enterprise Extension.'");
//    CommonClient.CheckFileSystemExtensionAttached(Notification, MessageText);
//
//    Procedure PrintDocumentCompletion(Result, AdditionalParameters) Export
//        // Script that prints a document only if the extension is attached.
//        // …
//
Procedure CheckFileSystemExtensionAttached(OnCloseNotifyDescription, Val SuggestionText = "", 
	Val WarningText = "") Export
	
	Parameters = New Structure("OnCloseNotifyDescription,WarningText", 
		OnCloseNotifyDescription, WarningText, );
	Notification = New NotifyDescription("CheckFileSystemExtensionAttachedCompletion",
		CommonInternalClient, Parameters);
	FileSystemClient.AttachFileOperationsExtension(Notification, SuggestionText);
	
EndProcedure

// Deprecated. Instead, use FileSystemClient.AttachFileOperationsExtension
// Returns the value of the "Prompt to install 1C:Enterprise Extension" user setting.
//
// Returns:
//  Boolean - True if the installation prompt is on.
//
Function SuggestFileSystemExtensionInstallation() Export
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	Return CommonServerCall.CommonSettingsStorageLoad(
		"ApplicationSettings/SuggestFileSystemExtensionInstallation", ClientID, True);
	
EndFunction

// Deprecated. Instead, use FileSystemClient.OpenFile
// Opens the file in the application associated with the file type.
// Prevents executable files from opening.
//
// Parameters:
//  PathToFile - String - Full path to the file to open.
//  Notification - NotifyDescription - notification on file open attempt.
//      If the notification is not specified and an error occurs, the method shows a warning:
//      * ApplicationStarted - Boolean - True if the external application opened successfully.
//      * AdditionalParameters - Arbitrary - a value that was specified on creating the NotifyDescription object.
//
// Example:
//  CommonClient.OpenFileInViewer(DocumentsDir() + "test.pdf");
//  CommonClient.OpenFileInViewer(DocumentsDir() + "test.xlsx");
//
Procedure OpenFileInViewer(PathToFile, Val Notification = Undefined) Export
	
	If Notification = Undefined Then 
		FileSystemClient.OpenFile(PathToFile);
	Else
		OpeningParameters = FileSystemClient.FileOpeningParameters();
		OpeningParameters.ForEditing = True;
		FileSystemClient.OpenFile(PathToFile, Notification,, OpeningParameters);
	EndIf;
	
EndProcedure

// Deprecated. Instead, use FileSystemClient.OpenExplorer
// Opens Windows Explorer to the specified directory.
// If a file path is specified, the pointer is placed on the file.
//
// Parameters:
//  PathToDirectoryOrFile - String - the full path to a file or folder.
//
// Example:
//  // For Windows OS
//  CommonClient.OpenExplorer("C:\Users");
//  CommonClient.OpenExplorer("C:\Program Files\1cv8\common\1cestart.exe");
//  // For Linux OS
//  CommonClient.OpenExplorer("/home/");
//  CommonClient.OpenExplorer("/opt/1C/v8.3/x86_64/1cv8c");
//
Procedure OpenExplorer(PathToDirectoryOrFile) Export
	
	FileSystemClient.OpenExplorer(PathToDirectoryOrFile);
	
EndProcedure

// Deprecated. Use FileSystemClient.OpenURL instead.
// Opens a URL in an application associated with URL protocol.
//
// Valid protocols: HTTP, HTTPS, E1C, V8HELP, MAILTO, TEL, SKYPE.
//
// Do not use the FILE:// protocol to open the Explorer or a file.
// - To Open Explorer, See OpenExplorer.
// - To open a file in the associated application, See OpenFileInViewer.
//
// Parameters:
//  URL - String - a link to open.
//  Notification - NotifyDescription - notification on file open attempt.
//      If the notification is not specified and an error occurs, the method shows a warning:
//      * ApplicationStarted - Boolean - True if the external application opened successfully.
//      * AdditionalParameters - Arbitrary - a value that was specified on creating the NotifyDescription object.
//
// Example:
//  CommonClient.OpenURL("e1cib/navigationpoint/startpage"); // Home page.
//  CommonClient.OpenURL("v8help://1cv8/QueryLanguageFullTextSearchInData");
//  CommonClient.OpenURL("https://1c.com");
//  CommonClient.OpenURL("mailto:help@1c.com");
//  CommonClient.OpenURL("skype:echo123?call");
//
Procedure OpenURL(URL, Val Notification = Undefined) Export
	
	FileSystemClient.OpenURL(URL, Notification);
	
EndProcedure

// Deprecated. Instead, use FileSystemClient.CreateTemporaryDirectory
// Gets temporary directory name.
//
// Parameters:
//  Notification - NotifyDescription - notification on getting directory name attempt:
//      * DirectoryName             - String - path to the directory.
//      * AdditionalParameters - Structure - a value that was specified on creating the NotifyDescription object.
//  Extension - String - the suffix in the directory name, which helps to identify the directory for analysis.
//
Procedure CreateTemporaryDirectory(Val Notification, Extension = "") Export 
	
	FileSystemClient.CreateTemporaryDirectory(Notification, Extension);
	
EndProcedure

// Deprecated. Instead, use CommonClient.IsMacOSClient
// Returns True if the client application runs on OS X.
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsOSXClient() Export
	
	ClientPlatformType = ClientPlatformType();
	Return ClientPlatformType = PlatformType.MacOS_x86
		Or ClientPlatformType = PlatformType.MacOS_x86_64;
	
EndFunction

#EndRegion

#EndRegion
