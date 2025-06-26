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

// Attaches an external report or data processor and returns the name of the attached report or data processor.
// Then registers the report or data processor in the application with a unique name.
// You can use this name to create a report or data processor object or open its forms.
//
// Important: Checking functional option UseAdditionalReportsAndDataProcessors
// must be executed by the calling code.
//
// Parameters:
//   Ref - CatalogRef.AdditionalReportsAndDataProcessors - a data processor to attach.
//
// Returns: 
//   String       - a name of the attached report or data processor.
//   Undefined - if an invalid reference is passed.
//
Function AttachExternalDataProcessor(Ref) Export
	
	StandardProcessing = True;
	Result = Undefined;
	
	SSLSubsystemsIntegration.OnAttachExternalDataProcessor(Ref, StandardProcessing, Result);
	If Not StandardProcessing Then
		Return Result;
	EndIf;
		
	// Validating the passed parameters.
	If TypeOf(Ref) <> Type("CatalogRef.AdditionalReportsAndDataProcessors") 
		Or Ref = Catalogs.AdditionalReportsAndDataProcessors.EmptyRef() Then
		Return Undefined;
	EndIf;
	
	// Attaching.
#If ThickClientOrdinaryApplication Then
	DataProcessorName = GetTempFileName();
	DataProcessorStorage = Common.ObjectAttributeValue(Ref, "DataProcessorStorage");
	BinaryData = DataProcessorStorage.Get();
	BinaryData.Write(DataProcessorName);
	Return DataProcessorName;
#EndIf
	
	Kind = Common.ObjectAttributeValue(Ref, "Kind");
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report
		Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		Manager = ExternalReports;
	Else
		Manager = ExternalDataProcessors;
	EndIf;
	
	StartupParameters = Common.ObjectAttributesValues(Ref, "SafeMode, DataProcessorStorage");
	AddressInTempStorage = PutToTempStorage(StartupParameters.DataProcessorStorage.Get());
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
		UseSecurityProfiles = ModuleSafeModeManager.UseSecurityProfiles();
	Else
		UseSecurityProfiles = False;
	EndIf;
	
	HasPermissions1 = False;
	If UseSecurityProfiles Then
		
		ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
		SafeMode = ModuleSafeModeManagerInternal.ExternalModuleAttachmentMode(Ref);
		
		If SafeMode = Undefined Then
			SafeMode = True;
		EndIf;
		
	Else
		
		SafeMode = GetFunctionalOption("StandardSubsystemsSaaS") Or StartupParameters.SafeMode;
		
		If SafeMode Then
			CompatibilityMode = Common.ObjectAttributeValue(Ref, "PermissionsCompatibilityMode");
			
			PermissionsRequest = New Query(
				"SELECT TOP 1
				|	AdditionalReportsAndPermissionProcessing.LineNumber,
				|	AdditionalReportsAndPermissionProcessing.PermissionKind
				|FROM
				|	Catalog.AdditionalReportsAndDataProcessors.Permissions AS AdditionalReportsAndPermissionProcessing
				|WHERE
				|	AdditionalReportsAndPermissionProcessing.Ref = &Ref");
			PermissionsRequest.SetParameter("Ref", Ref);
			HasPermissions1 = Not PermissionsRequest.Execute().IsEmpty()
				And CompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_2_2;
			
			If HasPermissions1 Then
				SafeMode = False;
			EndIf;
		EndIf;
		
	EndIf;
	
	DataProcessorName = Manager.Connect(AddressInTempStorage, , True,
		Common.ProtectionWithoutWarningsDetails());
	ExternalObject = Manager.Create(DataProcessorName);
	ExternalDataProcessorInfo = ExternalObject.ExternalDataProcessorInfo();
	If (Not ExternalDataProcessorInfo.SafeMode Or HasPermissions1)
		And Not SafeMode Then
		// Re-connect in unsafe mode (if allowed).
		DataProcessorName = Manager.Connect(AddressInTempStorage, , SafeMode,
			Common.ProtectionWithoutWarningsDetails());
	EndIf;
	
	WriteComment(Ref,
		StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Attachment, %1 = ""%2"".';"), "SafeMode",
			ExternalDataProcessorInfo.SafeMode Or SafeMode));
	
	Return DataProcessorName;
	
EndFunction

// Returns an object of an external report or data processor.
//
// Important: Checking functional option UseAdditionalReportsAndDataProcessors
// must be executed by the calling code.
//
// Parameters:
//   Ref - CatalogRef.AdditionalReportsAndDataProcessors - a report or a data processor to attach.
//
// Returns: 
//   ExternalDataProcessor - — an object of the attached data processor.
//   ExternalReport — an object of the attached report.
//   Undefined — if an invalid reference is passed.
//
Function ExternalDataProcessorObject(Ref) Export
	
	StandardProcessing = True;
	Result = Undefined;
	
	SSLSubsystemsIntegration.OnCreateExternalDataProcessor(Ref, StandardProcessing, Result);
	If Not StandardProcessing Then
		Return Result;
	EndIf;
	
	// Attaching.
	DataProcessorName = AttachExternalDataProcessor(Ref);
	
	// Validating the passed parameters.
	If DataProcessorName = Undefined Then
		Return Undefined;
	EndIf;
	
	// Get an object instance.
	Kind = Common.ObjectAttributeValue(Ref, "Kind");
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report
		Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		Manager = ExternalReports;
	Else
		Manager = ExternalDataProcessors;
	EndIf;
	
	Return Manager.Create(DataProcessorName);
	
EndFunction

// Generates a print form based on an external source.
//
// Parameters:
//   AdditionalDataProcessorRef - CatalogRef.AdditionalReportsAndDataProcessors - external data processor.
//   SourceParameters            - Structure:
//       * CommandID - String - a list of comma-separated templates.
//       * RelatedObjects    - Array
//   PrintFormsCollection - ValueTable - generated spreadsheet documents (return parameter).
//   PrintObjects         - ValueList  - a map between objects and names of spreadsheet document
//                                             print areas. Value - Object, Presentation - a name of the area
//                                             the object (return parameter) was displayed in.
//   OutputParameters       - Structure       - additional parameters of generated spreadsheet documents
//                                             (return parameter).
//
Procedure PrintByExternalSource(AdditionalDataProcessorRef, SourceParameters, PrintFormsCollection,
	PrintObjects, OutputParameters) Export
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.PrintByExternalSource(
			AdditionalDataProcessorRef,
			SourceParameters,
			PrintFormsCollection,
			PrintObjects,
			OutputParameters);
	EndIf;
	
EndProcedure

// Generates a details template for an external report or data processor to be filled in later.
//
// Parameters:
//   SSLVersion - See StandardSubsystemsServer.LibraryVersion.
//
// Returns:
//   Structure - Parameters of the external report or data processor:
//       * Kind - EnumRef.AdditionalReportsAndDataProcessorsKinds 
//             - String - Kind of the external report or data processor. To specify the kind, use functions
//           AdditionalReportsAndDataProcessorsClientServer.DataProcessorKind<KindName>.
//           You can also specify the kind explicitly:
//           PrintForm
//           ObjectFilling
//           RelatedObjectsCreation
//           Report
//           MessageTemplate
//           AdditionalDataProcessor
//           AdditionalReport
//       
//       * Version - String - a version of the report or data processor (later on data processor).
//           Conforms to "<Senior number>.<Junior number>" format.
//       
//       * Purpose - Array - full names of the configuration objects (String) for which the data processor is intended for.
//                               Optional property.
//       
//       * Description - String - a presentation for the administrator (a catalog item description).
//                                 If empty, a presentation of an external data processor metadata object is used.
//                                 Optional property. 
//       
//       * SafeMode - Boolean - Flag indicating whether the external data processor is attached in safe mode.
//                                    True by default (data processor runs in safe mode).
//                                    In safe mode:
//                                     Privileged mode is ignored.
//                                     The following external (relative to the 1C:Enterprise platform) actions are prohibited:
//                                      COM
//                                      Importing add-ins
//                                      Running external applications and operating system commands
//                                      Accessing file system except for temporary files
//                                      Accessing the Internet
//                                    Optional property.
//       
//       * Permissions - Array of XDTODataObject - additional permissions required for the external data processor in
//                               safe mode. ArrayElement - XDTODataObject - a permission of type
//                               http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}PermissionBase.
//                               To generate permission details, use functions
//                               SafeModeManager.Permission<PermissionKind>(<PermissionParameters>).
//                               Optional property.
//       
//       * Information - String - short information on the external data processor.
//                               It is recommended that you provide the data processor functionality for the administrator in this parameter.
//                               If empty, a comment of an external data processor metadata object is used.
//       
//       * SSLVersion - See StandardSubsystemsServer.LibraryVersion.
//       
//       * DefineFormSettings - Boolean - Applicable only to additional reports attached to the ReportForm common form.
//                                             It's intended for overriding some settings of the common report form and subscribe to its events. 
//                                             If True, 
//                                             :
//       
//       * ReportOptionAssignment - EnumRef.ReportOptionPurposes - Report option device compativility
//										(ForComputersAndTablets, ForSmartphones, ForAnyDevice).
//           
//           Specify report form settings.
//           //
//           :
//           Parameters
//           Form - ClientApplicationForm, Undefined
//           VariantKey - String, Undefined See ReportsClientServer.DefaultReportSettings
//           //
//           Settings -
//           	
//           Procedure DefineFormSettings(Form, VariantKey, Settings) Export
//           
//           Procedure code.
//           EndProcedure
//                                                                                    For details, see "Additional reports and data processors" and "Report options" in the subsystem documentation.
//                                                                                    An optional property.
//       
//       * Commands - ValueTable - settings of the commands provided by the external data processor (optional for reports):
//           ** Id - String - an internal command name. For external print forms (when Kind = "PrintForm"):
//                 ID can contain comma-separated names of one or more
//                 print commands. For more information, see details of column ID
//                 in function PrintManagement.CreatePrintCommandsCollection.
//           ** Presentation - String - a user presentation of the command.
//           ** Use - String - a command type:
//               "ClientMethodCall",
//               "ServerMethodCall",
//               "FillingForm",
//               "OpeningForm", or
//               "SafeModeScenario".
//               To get command types, use functions
//               AdditionalReportsAndDataProcessorsClientServer.CommandType<TypeName>.
//               Comments to these functions also contain templates of command handler procedures.
//           ** ShouldShowUserNotification - Boolean - if True, show "Executing command…" notification upon command execution.
//              It is used for all command types except for commands for opening a form (Usage = "OpeningForm").
//           ** Modifier - String - Additional command classification.
//               For external print forms (Kind = "PrintForm"):
//                 MXLPrinting for print forms generated on the basis of spreadsheet templates.
//               For data import from file (Kind = "PrintForm" and Usage = "ImportDataFromFile"):
//                 Modifier is required.
//                 It must contain the full name of the metadata object (catalog)
//                 the data is being imported for.
//           ** Hide - Boolean - optional. Indicates whether it is an internal command.
//               If True, the command is hidden from the additional object card.
//
Function ExternalDataProcessorInfo(SSLVersion = "") Export
	RegistrationParameters = New Structure;
	
	RegistrationParameters.Insert("Kind", "");
	RegistrationParameters.Insert("Version", "0.0");
	RegistrationParameters.Insert("Purpose", New Array);
	RegistrationParameters.Insert("Description", Undefined);
	RegistrationParameters.Insert("SafeMode", True);
	RegistrationParameters.Insert("Information", Undefined);
	RegistrationParameters.Insert("SSLVersion", SSLVersion);
	RegistrationParameters.Insert("DefineFormSettings", False);
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptionsInternal = Common.CommonModule("ReportsOptionsInternal");
		RegistrationParameters.Insert("ReportOptionAssignment",
			ModuleReportsOptionsInternal.ReportOptionEmptyAssignment());
	EndIf;
	
	TabularSectionAttributes = Metadata.Catalogs.AdditionalReportsAndDataProcessors.TabularSections.Commands.Attributes;
	
	CommandsTable = New ValueTable;
	CommandsTable.Columns.Add("Presentation", TabularSectionAttributes.Presentation.Type);
	CommandsTable.Columns.Add("Id", TabularSectionAttributes.Id.Type);
	CommandsTable.Columns.Add("Use", New TypeDescription("String"));
	CommandsTable.Columns.Add("ShouldShowUserNotification", TabularSectionAttributes.ShouldShowUserNotification.Type);
	CommandsTable.Columns.Add("Modifier", TabularSectionAttributes.Modifier.Type);
	CommandsTable.Columns.Add("Hide",      TabularSectionAttributes.Hide.Type);
	CommandsTable.Columns.Add("CommandsToReplace", TabularSectionAttributes.CommandsToReplace.Type);
	
	RegistrationParameters.Insert("Commands", CommandsTable);
	RegistrationParameters.Insert("Permissions", New Array);
	
	Return RegistrationParameters;
EndFunction

// Executes a data processor command and returns the result.
//
// Important: Checking functional option UseAdditionalReportsAndDataProcessors
// must be executed by the calling code.
//
// Parameters:
//   CommandParameters - Structure - parameters of the command:
//       * AdditionalDataProcessorRef - CatalogRef.AdditionalReportsAndDataProcessors - catalog item.
//       * CommandID - String - a name of the command being executed.
//       * RelatedObjects    - Array - references to the objects the data processor is running for. Mandatory for assignable
//                                         data processors.
//   ResultAddress - String - address of a temporary storage where the execution result
//                              will be stored.
//
// Returns:
//   Structure - an execution result to be passed to client.
//   Undefined - if ResultAddress is passed.
//
Function ExecuteCommand(CommandParameters, ResultAddress = Undefined) Export
	
	If TypeOf(CommandParameters.AdditionalDataProcessorRef) <> Type("CatalogRef.AdditionalReportsAndDataProcessors")
		Or CommandParameters.AdditionalDataProcessorRef = Catalogs.AdditionalReportsAndDataProcessors.EmptyRef() Then
		Return Undefined;
	EndIf;
	
	ExternalObject = ExternalDataProcessorObject(CommandParameters.AdditionalDataProcessorRef);
	CommandID = CommandParameters.CommandID;
	ExecutionResult = ExecuteExternalObjectCommand(ExternalObject, CommandID, CommandParameters, ResultAddress);
	
	Return ExecutionResult;
	
EndFunction

// Executes a data processor command directly from the external object form and returns the execution result.
// Usage example: See AdditionalReportsAndDataProcessorsClient.ExecuteCommandInBackground.
//
// Important! The check of the functional option UseAdditionalReportsAndDataProcessors
// must be triggered in the calling code.
//
// Parameters:
//   CommandID - String    - a command name as it is specified in function ExternalDataProcessorInfo() in the object module.
//   CommandParameters     - Structure - command execution parameters.
//                                      See AdditionalReportsAndDataProcessorsClient.ExecuteCommandInBackground.
//   Form                - ClientApplicationForm - a form to return the result to.
//
// Returns:
//   Structure - for internal use.
//
Function ExecuteCommandFromExternalObjectForm(CommandID, CommandParameters, Form) Export
	
	ExternalObject = Form.FormAttributeToValue("Object");
	ExecutionResult = ExecuteExternalObjectCommand(ExternalObject, CommandID, CommandParameters, Undefined);
	Return ExecutionResult;
	
EndFunction

// Generates a list of sections where the additional report calling command is available.
//
// Returns: 
//   Array - an array of Subsystem metadata objects - metadata of the sections where the list of commands of additional
//                                                    data processors is displayed.
//
Function AdditionalReportSections() Export
	MetadataSections = New Array;
	
	AdditionalReportsAndDataProcessorsOverridable.GetSectionsWithAdditionalReports(MetadataSections);
	
	// ACC:1383-off Get a manager module instead of a common module.
	If Common.SubsystemExists("StandardSubsystems.ApplicationSettings") Then
		ModuleDataProcessorsControlPanelSSL = Common.CommonModule("DataProcessors.SSLAdministrationPanel");
		ModuleDataProcessorsControlPanelSSL.OnDefineSectionsWithAdditionalReports(MetadataSections);
	EndIf;
	// ACC:1383-on
	
	Return MetadataSections;
EndFunction

// Generates a list of sections where the additional data processor calling command is available.
//
// Returns: 
//   Array - an array of Subsystem metadata objects - metadata of the sections where the list of commands of additional data processors
//   is displayed.
//
Function AdditionalDataProcessorSections() Export
	MetadataSections = New Array;
	
	// ACC:1383-off Get a manager module instead of a common module.
	If Common.SubsystemExists("StandardSubsystems.ApplicationSettings") Then
		ModuleDataProcessorsControlPanelSSL = Common.CommonModule("DataProcessors.SSLAdministrationPanel");
		ModuleDataProcessorsControlPanelSSL.OnDefineSectionsWithAdditionalDataProcessors(MetadataSections);
	EndIf;
	// ACC:1383-on
	
	AdditionalReportsAndDataProcessorsOverridable.GetSectionsWithAdditionalDataProcessors(MetadataSections);
	
	Return MetadataSections;
EndFunction

#EndRegion

#Region Internal

// Determines a list of metadata objects to which an assignable data processor of the passed kind can be applied.
//
// Parameters:
//   Kind - EnumRef.AdditionalReportsAndDataProcessorsKinds - External data processor type.
//
// Returns:
//   ValueTable - Metadata object details:
//       * Metadata - MetadataObject - a metadata object attached to this kind.
//       * FullName  - String - a full name of the metadata object, for example, Catalog.Currencies.
//       * Ref     - CatalogRef.MetadataObjectIDs - a metadata object reference.
//       * Kind        - String - a metadata object kind.
//       * Presentation       - String - a metadata object presentation.
//       * FullPresentation - String - a presentation of a metadata object name and kind.
//   Undefined - if invalid Kind is passed.
//
Function AttachedMetadataObjects(Kind) Export
	Result = New ValueTable;
	Result.Columns.Add("Metadata");
	Result.Columns.Add("FullName", New TypeDescription("String"));
	Result.Columns.Add("Ref", New TypeDescription("CatalogRef.MetadataObjectIDs, CatalogRef.ExtensionObjectIDs"));
	Result.Columns.Add("Kind", New TypeDescription("String"));
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("FullPresentation", New TypeDescription("String"));
	
	TypesOrMetadataArray = New Array;
	
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling
		Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report
		Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.RelatedObjectsCreation Then
		
		TypesOrMetadataArray = Metadata.DefinedTypes.ObjectWithAdditionalCommands.Type.Types();
		
	ElsIf Kind = Enums.AdditionalReportsAndDataProcessorsKinds.MessageTemplate Then
		
		If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
			ModuleMessageTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
			TypesOrMetadataArray = ModuleMessageTemplatesInternal.MessageTemplatesSources()
		Else
			Return Result;
		EndIf;
		
	ElsIf Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
		
		If Common.SubsystemExists("StandardSubsystems.Print") Then
			ModulePrintManager = Common.CommonModule("PrintManagement");
			TypesOrMetadataArray = ModulePrintManager.PrintCommandsSources()
		Else
			Return Result;
		EndIf;
		
	ElsIf Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor Then
		
		TypesOrMetadataArray = AdditionalDataProcessorSections();
		
	ElsIf Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		
		TypesOrMetadataArray = AdditionalReportSections();
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	For Each TypeOrMetadata In TypesOrMetadataArray Do
		If TypeOf(TypeOrMetadata) = Type("Type") Then
			MetadataObject = Metadata.FindByType(TypeOrMetadata);
			If MetadataObject = Undefined Then
				Continue;
			EndIf;
		Else
			MetadataObject = TypeOrMetadata;
		EndIf;
		
		TableRow = Result.Add();
		TableRow.Metadata = MetadataObject;
		
		If MetadataObject = AdditionalReportsAndDataProcessorsClientServer.StartPageName() Then
			TableRow.FullName = AdditionalReportsAndDataProcessorsClientServer.StartPageName();
			TableRow.Ref = Catalogs.MetadataObjectIDs.EmptyRef();
			TableRow.Kind = "Subsystem";
			TableRow.Presentation = StandardSubsystemsServer.HomePagePresentation();
		Else
			TableRow.FullName = MetadataObject.FullName();
			TableRow.Ref = Common.MetadataObjectID(MetadataObject);
			TableRow.Kind = Left(TableRow.FullName, StrFind(TableRow.FullName, ".") - 1);
			TableRow.Presentation = MetadataObject.Presentation();
		EndIf;
		
		TableRow.FullPresentation = TableRow.Presentation + " (" + TableRow.Kind + ")";
	EndDo;
	
	Result.Indexes.Add("Ref");
	Result.Indexes.Add("Kind");
	Result.Indexes.Add("FullName");
	
	Return Result;
EndFunction

// Generates a new query used to get a command table for additional reports or data processors.
//
// Parameters:
//   DataProcessorsKind - EnumRef.AdditionalReportsAndDataProcessorsKinds - Data processor type.
//   Location - CatalogRef.MetadataObjectIDs
//              - String - a reference or a full name of the metadata object
//       linked to the searched additional reports and data processors.
//       Global data processors are located in sections, while context ones are used in catalogs and documents.
//   IsObjectForm - Boolean -
//       Type of forms that contain context additional reports and data processors.
//       True - only reports and data processors linked to object forms.
//       False - only reports and data processors linked to list forms.
//   CommandsTypes - EnumRef.AdditionalReportsAndDataProcessorsPublicationOptions - a type of commands to get.
//              - Array of EnumRef.AdditionalReportsAndDataProcessorsPublicationOptions
//   EnabledOnly - Boolean -
//       Type of forms that contain context additional reports and data processors.
//       True - only reports and data processors linked to object forms.
//       False - only reports and data processors linked to list forms.
//
// Returns:
//   ValueTable:
//       * Ref - CatalogRef.AdditionalReportsAndDataProcessors - a reference of an additional report or data processor.
//       * Id - String - a command ID as it is specified by the developer of the additional object.
//       * StartupOption - EnumRef.AdditionalDataProcessorsCallMethods -
//           A method of calling the additional object command.
//       * Presentation - String - a command name in the user interface.
//       * ShouldShowUserNotification - Boolean - show user notification when a command is executed.
//       * Modifier - String - a command modifier.
//
Function NewQueryByAvailableCommands(DataProcessorsKind, Location, IsObjectForm = Undefined, CommandsTypes = Undefined, EnabledOnly = True) Export
	Query = New Query;
	
	If TypeOf(Location) = Type("CatalogRef.MetadataObjectIDs") Then
		ParentOrSectionRef = Location;
	Else
		If ValueIsFilled(Location) Then
			ParentOrSectionRef = Common.MetadataObjectID(Location);
		Else
			ParentOrSectionRef = Undefined;
		EndIf;
	EndIf;
	
	If ParentOrSectionRef <> Undefined Then // Filter by parent is set.
		AreGlobalDataProcessors = (
			DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport
			Or DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor);
		
		// Calls used for global and for assignable data processors are fundamentally different.
		If AreGlobalDataProcessors Then
			QueryText =
			"SELECT ALLOWED DISTINCT
			|	AdditionalReportsAndDataProcessors1.Ref
			|INTO ttRefs
			|FROM
			|	Catalog.AdditionalReportsAndDataProcessors.Sections AS TableSections
			|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors1
			|		ON (TableSections.Section = &SectionRef)
			|			AND TableSections.Ref = AdditionalReportsAndDataProcessors1.Ref
			|WHERE
			|	AdditionalReportsAndDataProcessors1.Kind = &Kind
			|	AND NOT AdditionalReportsAndDataProcessors1.DeletionMark
			|	AND AdditionalReportsAndDataProcessors1.Publication = &Publication
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED
			|	CommandsTable1.Ref,
			|	CommandsTable1.Id,
			|	CommandsTable1.CommandsToReplace,
			|	CommandsTable1.StartupOption,
			|	CommandsTable1.Presentation,
			|	CommandsTable1.ShouldShowUserNotification,
			|	CommandsTable1.Modifier,
			|	ISNULL(QuickAccess.Available, FALSE) AS Use
			|INTO SummaryTable
			|FROM
			|	ttRefs AS ReferencesTable
			|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors.Commands AS CommandsTable1
			|		ON ReferencesTable.Ref = CommandsTable1.Ref
			|			AND (CommandsTable1.Hide = FALSE)
			|			AND (CommandsTable1.StartupOption IN (&CommandsTypes))
			|		LEFT JOIN InformationRegister.DataProcessorAccessUserSettings AS QuickAccess
			|		ON (CommandsTable1.Ref = QuickAccess.AdditionalReportOrDataProcessor)
			|			AND (CommandsTable1.Id = QuickAccess.CommandID)
			|			AND (QuickAccess.User = &CurrentUser)
			|WHERE
			|	ISNULL(QuickAccess.Available, FALSE)";
			Query.SetParameter("SectionRef", ParentOrSectionRef);
			
			If Not EnabledOnly Then
				QueryText = StrReplace(QueryText,
					"WHERE
					|	ISNULL(QuickAccess.Available, FALSE)",
					"");
			EndIf;
			
		Else
			
			QueryText =
			"SELECT ALLOWED DISTINCT
			|	AssignmentTable.Ref
			|INTO ttRefs
			|FROM
			|	Catalog.AdditionalReportsAndDataProcessors.Purpose AS AssignmentTable
			|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors1
			|		ON (AssignmentTable.RelatedObject = &ParentRef)
			|			AND AssignmentTable.Ref = AdditionalReportsAndDataProcessors1.Ref
			|			AND (AdditionalReportsAndDataProcessors1.DeletionMark = FALSE)
			|			AND (AdditionalReportsAndDataProcessors1.Kind = &Kind)
			|			AND (AdditionalReportsAndDataProcessors1.Publication = &Publication)
			|			AND (AdditionalReportsAndDataProcessors1.UseForListForm = TRUE)
			|			AND (AdditionalReportsAndDataProcessors1.UseForObjectForm = TRUE)
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED
			|	CommandsTable1.Ref,
			|	CommandsTable1.Id,
			|	CommandsTable1.CommandsToReplace,
			|	CommandsTable1.StartupOption,
			|	CommandsTable1.Presentation,
			|	CommandsTable1.ShouldShowUserNotification,
			|	CommandsTable1.Modifier,
			|	UNDEFINED AS Use
			|INTO SummaryTable
			|FROM
			|	ttRefs AS ReferencesTable
			|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors.Commands AS CommandsTable1
			|		ON ReferencesTable.Ref = CommandsTable1.Ref
			|			AND (CommandsTable1.Hide = FALSE)
			|			AND (CommandsTable1.StartupOption IN (&CommandsTypes))";
			
			Query.SetParameter("ParentRef", ParentOrSectionRef);
			
		EndIf;
		
	Else
		
		QueryText =
		"SELECT ALLOWED
		|	CommandsTable1.Ref,
		|	CommandsTable1.Id,
		|	CommandsTable1.CommandsToReplace,
		|	CommandsTable1.StartupOption,
		|	CommandsTable1.Presentation AS Presentation,
		|	CommandsTable1.ShouldShowUserNotification,
		|	CommandsTable1.Modifier,
		|	UNDEFINED AS Use
		|INTO SummaryTable
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors.Commands AS CommandsTable1
		|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors1
		|		ON CommandsTable1.Ref = AdditionalReportsAndDataProcessors1.Ref
		|			AND (AdditionalReportsAndDataProcessors1.Kind = &Kind)
		|			AND (CommandsTable1.StartupOption IN (&CommandsTypes))
		|			AND (AdditionalReportsAndDataProcessors1.Publication = &Publication)
		|			AND (AdditionalReportsAndDataProcessors1.DeletionMark = FALSE)
		|			AND (AdditionalReportsAndDataProcessors1.UseForListForm = TRUE)
		|			AND (AdditionalReportsAndDataProcessors1.UseForObjectForm = TRUE)
		|			AND (CommandsTable1.Hide = FALSE)";
		
	EndIf;
	
	// Disabling filters by list and object form.
	If IsObjectForm <> True Then
		QueryText = StrReplace(QueryText, "AND (AdditionalReportsAndDataProcessors1.UseForObjectForm = TRUE)", "");
	EndIf;
	If IsObjectForm <> False Then
		QueryText = StrReplace(QueryText, "AND (AdditionalReportsAndDataProcessors1.UseForListForm = TRUE)", "");
	EndIf;
	
	If CommandsTypes = Undefined Then
		QueryText = StrReplace(QueryText, "AND (CommandsTable1.StartupOption IN (&CommandsTypes))", "");
	Else
		Query.SetParameter("CommandsTypes", CommandsTypes);
	EndIf;
	
	Query.SetParameter("Kind", DataProcessorsKind);
	If AccessRight("Update", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		QueryText = StrReplace(QueryText, "Publication = &Publication", "Publication <> &Publication");
		Query.SetParameter("Publication", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled);
	Else
		Query.SetParameter("Publication", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used);
	EndIf;
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.Text = QueryText;
	
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS")
		And Common.DataSeparationEnabled() Then
		RegisterName = "UseSuppliedAdditionalReportsAndProcessorsInDataAreas";
		Query.Text = Query.Text + ";
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SummaryTable.Ref,
		|	SummaryTable.Id,
		|	SummaryTable.CommandsToReplace,
		|	SummaryTable.StartupOption,
		|	SummaryTable.Presentation AS Presentation,
		|	SummaryTable.ShouldShowUserNotification,
		|	SummaryTable.Modifier,
		|	SummaryTable.Use
		|FROM
		|	SummaryTable AS SummaryTable
		|		INNER JOIN &FullRegisterName1 AS Installations
		|		ON SummaryTable.Ref = Installations.DataProcessorToUse
		|
		|ORDER BY
		|	Presentation";
		Query.Text = StrReplace(Query.Text, "&FullRegisterName1", "InformationRegister." + RegisterName);
	Else
		Query.Text = StrReplace(Query.Text, "INTO SummaryTable", ""); // @query-part
		Query.Text = Query.Text + "
		|
		|ORDER BY
		|	Presentation";
	EndIf;
	
	Return Query;
EndFunction

// Parameters:
//   ReferencesArrray - Array of AnyRef - references to the selected objects for which a command is being executed.
//   ExecutionParameters - Structure:
//    * CommandDetails - Structure:
//      ** Id - String - Command ID.
//      ** Presentation - String - Command presentation in a form.
//      ** Name - String - a command name on a form.
//      ** AdditionalParameters - See AdditionalFillingCommandParameters
//    * Form - ClientApplicationForm - a form where the command is called.
//    * Source - FormDataStructure:
//      ** Ref - AnyRef
//               - FormTable - an object or a form list with the Reference field.
//
Procedure HandlerFillingCommands(Val ReferencesArrray, Val ExecutionParameters) Export
	CommandToExecute = ExecutionParameters.CommandDetails.AdditionalParameters; 
	
	ExternalObject = ExternalDataProcessorObject(CommandToExecute.Ref);
	
	CommandParameters = New Structure;
	CommandParameters.Insert("ThisForm", ExecutionParameters.Form);
	CommandParameters.Insert("AdditionalDataProcessorRef", CommandToExecute.Ref);
	
	ExecuteExternalObjectCommand(ExternalObject, CommandToExecute.Id, CommandParameters, Undefined);
EndProcedure

Function AdditionalReportsAndDataProcessorsAreUsed() Export
	Return GetFunctionalOption("UseAdditionalReportsAndDataProcessors");
EndFunction

// Returns:
//  String - — a command workstation name.
//
Function SectionPresentation(Section) Export
	If Section = AdditionalReportsAndDataProcessorsClientServer.StartPageName()
		Or Section = Catalogs.MetadataObjectIDs.EmptyRef() Then
		Return StandardSubsystemsServer.HomePagePresentation();
	EndIf;
	Return MetadataObjectPresentation(Section);
EndFunction

Function IsAdditionalReportOrDataProcessorType(Type) Export
	Return (Type = Type("CatalogRef.AdditionalReportsAndDataProcessors"));
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// Delete subsystems references before their deletion.
Procedure BeforeDeleteMetadataObjectID(MetadataObjectIDObject, Cancel) Export
	If MetadataObjectIDObject.DataExchange.Load Then
		Return;
	EndIf;
	
	MetadataObjectIDRef = MetadataObjectIDObject.Ref;
	Query = New Query(
		"SELECT DISTINCT
		|	ReportAndDataProcessorSections.Ref
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors.Sections AS ReportAndDataProcessorSections
		|WHERE
		|	ReportAndDataProcessorSections.Section = &Subsystem
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	ReportAndDataProcessorSections.Ref
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors.Purpose AS ReportAndDataProcessorSections
		|WHERE
		|	ReportAndDataProcessorSections.RelatedObject = &Subsystem");
	Query.SetParameter("Subsystem", MetadataObjectIDRef);
	ObjectsToChange = Query.Execute().Unload().UnloadColumn("Ref");
	
	BeginTransaction();
	Try
		Block = New DataLock;
		For Each CatalogRef In ObjectsToChange Do
			LockItem = Block.Add(Metadata.Catalogs.AdditionalReportsAndDataProcessors.FullName());
			LockItem.SetValue("Ref", CatalogRef);
		EndDo;
		Block.Lock();
		
		For Each CatalogRef In ObjectsToChange Do
			CatalogObject = CatalogRef.GetObject();
			
			FoundItems = CatalogObject.Sections.FindRows(New Structure("Section", MetadataObjectIDRef));
			For Each TableRow In FoundItems Do
				CatalogObject.Sections.Delete(TableRow);
			EndDo;
			
			FoundItems = CatalogObject.Purpose.FindRows(New Structure("RelatedObject", MetadataObjectIDRef));
			For Each TableRow In FoundItems Do
				CatalogObject.Purpose.Delete(TableRow);
			EndDo;
			
			CatalogObject.Write();
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;	
EndProcedure

// Updates reports and data processors in the catalog from common templates.
//
// Parameters:
//   ReportsAndDataProcessors - ValueTable - a table of reports and data processors in common templates:
//     * MetadataObject - MetadataObject - a report or a data processor from the configuration.
//     * OldObjectsNames - Array - old names of objects used while searching for old versions of the report or data processor.
//     * OldFilesNames - Array - old names of files used while searching for old versions of the report or data processor.
//     * Ref - CatalogRef.AdditionalReportsAndDataProcessors
//     * Name - String
//
Procedure ImportAdditionalReportsAndDataProcessorsFromMetadata(ReportsAndDataProcessors) Export
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	
	MapConfigurationDataProcessorsWithCatalogDataProcessors(ReportsAndDataProcessors);
	If ReportsAndDataProcessors.Count() = 0 Then
		Return; // The update is not required.
	EndIf;
	
	ExportReportsAndDataProcessorsToFiles(ReportsAndDataProcessors);
	If ReportsAndDataProcessors.Count() = 0 Then
		Return; // Export failed.
	EndIf;
	
	RegisterReportsAndDataProcessors(ReportsAndDataProcessors);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddMetadataObjectsRenaming.
Procedure OnAddMetadataObjectsRenaming(Renamings) Export
	
	Common.AddRenaming(Renamings, "2.3.3.3", 
		"Role.UseAdditionalReportsAndServiceProcessors", "Role.ReadAdditionalReportsAndDataProcessors", "StandardSubsystems");
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromSlave.
Procedure OnReceiveDataFromSlave(DataElement, ItemReceive, SendBack, Sender) Export
	
	OnGetAdditionalDataProcessor(DataElement, ItemReceive);
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromMaster.
Procedure OnReceiveDataFromMaster(DataElement, ItemReceive, SendBack, Sender) Export
	
	OnGetAdditionalDataProcessor(DataElement, ItemReceive);
	
EndProcedure

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	If Common.DataSeparationEnabled()
		Or Not AccessRight("Edit", Metadata.Catalogs.AdditionalReportsAndDataProcessors)
		Or Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If ModuleToDoListServer.UserTaskDisabled("AdditionalReportsAndDataProcessors") Then
		Return; // The to-do is disabled in the overridable module.
	EndIf;
	
	Subsystem = Metadata.Subsystems.Find("Administration");
	If Subsystem = Undefined
		Or Not AccessRight("View", Subsystem)
		Or Not Common.MetadataObjectAvailableByFunctionalOptions(Subsystem) Then
		Sections = ModuleToDoListServer.SectionsForObject("Catalog.AdditionalReportsAndDataProcessors");
	Else
		Sections = New Array;
		Sections.Add(Subsystem);
	EndIf;
	
	OutputToDoItem = True;
	VersionChecked = CommonSettingsStorage.Load("ToDoList", "AdditionalReportsAndDataProcessors");
	If VersionChecked <> Undefined Then
		ArrayVersion  = StrSplit(Metadata.Version, ".", True);
		CurrentVersion = ArrayVersion[0] + ArrayVersion[1] + ArrayVersion[2];
		If VersionChecked = CurrentVersion Then
			OutputToDoItem = False; // Additional reports and data processors were checked on the current version.
		EndIf;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	COUNT(DISTINCT AdditionalReportsAndDataProcessors.Ref) AS Count
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
	|WHERE
	|	AdditionalReportsAndDataProcessors.Publication = VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used)
	|	AND AdditionalReportsAndDataProcessors.DeletionMark = FALSE
	|	AND AdditionalReportsAndDataProcessors.IsFolder = FALSE";
	Count = Query.Execute().Unload()[0].Count;
	
	For Each Section In Sections Do
		SectionID = "CheckCompatibilityWithCurrentVersion" + StrReplace(Section.FullName(), ".", "");
		
		ToDoItem = ToDoList.Add();
		ToDoItem.Id = "AdditionalReportsAndDataProcessors";
		ToDoItem.HasToDoItems      = OutputToDoItem And Count > 0;
		ToDoItem.Presentation = NStr("en = 'Additional reports and data processors';");
		ToDoItem.Count    = Count;
		ToDoItem.Form         = "Catalog.AdditionalReportsAndDataProcessors.Form.AdditionalReportsAndDataProcessorsCheck";
		ToDoItem.Owner      = SectionID;
		
		// Check for the to-do's group. If the group is missing, add it.
		ToDoGroup = ToDoList.Find(SectionID, "Id");
		If ToDoGroup = Undefined Then
			ToDoGroup = ToDoList.Add();
			ToDoGroup.Id = SectionID;
			ToDoGroup.HasToDoItems      = ToDoItem.HasToDoItems;
			ToDoGroup.Presentation = NStr("en = 'Check compatibility';");
			If ToDoItem.HasToDoItems Then
				ToDoGroup.Count = ToDoItem.Count;
			EndIf;
			ToDoGroup.Owner = Section;
		Else
			If Not ToDoGroup.HasToDoItems Then
				ToDoGroup.HasToDoItems = ToDoItem.HasToDoItems;
			EndIf;
			
			If ToDoItem.HasToDoItems Then
				ToDoGroup.Count = ToDoGroup.Count + ToDoItem.Count;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// See AccessManagementOverridable.OnFillAccessKinds.
Procedure OnFillAccessKinds(AccessKinds) Export
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name = "AdditionalReportsAndDataProcessors";
	AccessKind.Presentation = NStr("en = 'Additional reports and data processors';");
	AccessKind.ValuesType   = Type("CatalogRef.AdditionalReportsAndDataProcessors");
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction.
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.AdditionalReportsAndDataProcessors, True);
	
EndProcedure

// See AccessManagementOverridable.OnFillAccessKindUsage.
Procedure OnFillAccessKindUsage(AccessKind, Use) Export
	
	SetPrivilegedMode(True);
	
	If AccessKind = "AdditionalReportsAndDataProcessors" Then
		Use = Constants.UseAdditionalReportsAndDataProcessors.Get();
	EndIf;
	
EndProcedure

// See AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionKinds.
Procedure OnFillMetadataObjectsAccessRestrictionKinds(LongDesc) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
	If ModuleAccessManagementInternal.AccessKindExists("AdditionalReportsAndDataProcessors") Then
		
		LongDesc = LongDesc + "
		|
		|Catalog.AdditionalReportsAndDataProcessors.Read.AdditionalReportsAndDataProcessors
		|";
	EndIf;
	
EndProcedure

// See UsersOverridable.OnDefineRoleAssignment
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// BothForUsersAndExternalUsers.
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadAdditionalReportsAndDataProcessors.Name);
	
EndProcedure

// See UsersOverridable.OnGetOtherSettings.
Procedure OnGetOtherSettings(UserInfo, Settings) Export
	
	// Gets additional report and data processor settings for a passed user.
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors")
		Or Not AccessRight("Update", Metadata.InformationRegisters.DataProcessorAccessUserSettings) Then
		Return;
	EndIf;
	
	// Settings string name to be displayed in the data processor settings tree.
	SettingName1 = NStr("en = 'Settings for additional report and data processor quick access';");
	
	// Settings string picture.
	PictureSettings = "";
	
	// List of additional reports and data processors the user can quickly access.
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DataProcessorAccessUserSettings.AdditionalReportOrDataProcessor AS Object,
	|	DataProcessorAccessUserSettings.CommandID AS Id,
	|	DataProcessorAccessUserSettings.User AS User
	|FROM
	|	InformationRegister.DataProcessorAccessUserSettings AS DataProcessorAccessUserSettings
	|WHERE
	|	User = &User";
	
	Query.Parameters.Insert("User", UserInfo.UserRef);
	
	QueryResult = Query.Execute().Unload(); // See UsersInternal.ANewDescriptionOfSettings
	
	QuickAccessSetting = New Structure;
	QuickAccessSetting.Insert("SettingName1", SettingName1);
	QuickAccessSetting.Insert("PictureSettings", PictureSettings);
	QuickAccessSetting.Insert("SettingsList",    QueryResult);
	
	Settings.Insert("QuickAccessSetting", QuickAccessSetting);
	
EndProcedure

// See UsersOverridable.OnSaveOtherSetings.
Procedure OnSaveOtherSetings(UserInfo, Settings) Export
	
	// Saves additional report and data processor commands for the specified users.
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	
	If Settings.SettingID <> "QuickAccessSetting" Then
		Return;
	EndIf;
	
	For Each RowItem In Settings.SettingValue Do
		
		Record = InformationRegisters.DataProcessorAccessUserSettings.CreateRecordManager();
		
		Record.AdditionalReportOrDataProcessor  = RowItem.Value;
		Record.CommandID             = RowItem.Presentation;
		Record.User                     = UserInfo.UserRef;
		Record.Available                         = True;
		
		Record.Write(True);
		
	EndDo;
	
EndProcedure

// See UsersOverridable.OnDeleteOtherSettings.
Procedure OnDeleteOtherSettings(UserInfo, Settings) Export
	
	// Clears additional report and data processor commands for the specified user.
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	
	If Settings.SettingID <> "QuickAccessSetting" Then
		Return;
	EndIf;
	
	For Each RowItem In Settings.SettingValue Do
		
		Record = InformationRegisters.DataProcessorAccessUserSettings.CreateRecordManager();
		
		Record.AdditionalReportOrDataProcessor  = RowItem.Value;
		Record.CommandID             = RowItem.Presentation;
		Record.User                     = UserInfo.UserRef;
		
		Record.Read();
		
		Record.Delete();
		
	EndDo;
	
EndProcedure

// See BatchEditObjectsOverridable.OnDefineObjectsWithEditableAttributes.
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.AdditionalReportsAndDataProcessors.FullName(), "AttributesToEditInBatchProcessing");
EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export
	If AttachableCommandsKinds.Find("ObjectsFilling", "Name") = Undefined Then
		Kind = AttachableCommandsKinds.Add();
		Kind.Name         = "ObjectsFilling";
		Kind.SubmenuName  = "FillSubmenu";
		Kind.Title   = NStr("en = 'Fill';");
		Kind.Picture    = PictureLib.FillForm;
		Kind.Representation = ButtonRepresentation.Picture;
	EndIf;
EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	
	If Not AccessRight("Read", Metadata.InformationRegisters.AdditionalDataProcessorsPurposes) Then 
		Return;
	EndIf;
	
	If FormSettings.IsObjectForm Then
		FormType = AdditionalReportsAndDataProcessorsClientServer.ObjectFormType();
	Else
		FormType = AdditionalReportsAndDataProcessorsClientServer.ListFormType();
	EndIf;
	
	SetFOParameters = (Metadata.CommonCommands.Find("RelatedObjectsCreation") <> Undefined);
	If SetFOParameters Then
		FormSettings.FunctionalOptions.Insert("AdditionalReportsAndDataProcessorsRelatedObject", Catalogs.MetadataObjectIDs.EmptyRef());
		FormSettings.FunctionalOptions.Insert("AdditionalReportsAndDataProcessorsFormType",         FormType);
	EndIf;
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	
	ObjectsIDs = New Array;
	CommandsSources = New Map;
	For Each Source In Sources.Rows Do
		For Each DocumentRecorder In Source.Rows Do
			ObjectsIDs.Add(DocumentRecorder.MetadataRef);
			CommandsSources.Insert(DocumentRecorder.MetadataRef, DocumentRecorder);
		EndDo;
		ObjectsIDs.Add(Source.MetadataRef);
		CommandsSources.Insert(Source.MetadataRef, Source);
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Purpose.RelatedObject,
	|	Purpose.UseObjectFilling AS UseObjectFilling,
	|	Purpose.UseReports AS UseReports,
	|	Purpose.UseRelatedObjectCreation AS UseRelatedObjectCreation
	|FROM
	|	InformationRegister.AdditionalDataProcessorsPurposes AS Purpose
	|WHERE
	|	Purpose.RelatedObject IN(&MOIDs)
	|	AND Purpose.FormType = &FormType";
	Query.SetParameter("MOIDs", ObjectsIDs);
	If FormType = Undefined Then
		Query.Text = StrReplace(Query.Text, "AND Purpose.FormType = &FormType", "");
	Else
		Query.SetParameter("FormType", FormType);
	EndIf;
	
	ObjectFillingTypes = New Array;
	ReportsTypes = New Array;
	RelatedObjectsCreationTypes = New Array;
	
	RegisterTable = Query.Execute().Unload();
	For Each TableRow In RegisterTable Do
		Source = CommandsSources[TableRow.RelatedObject];
		If Source = Undefined Then
			Continue;
		EndIf;
		If TableRow.UseObjectFilling Then
			AttachableCommands.SupplyTypesArray(ObjectFillingTypes, Source.DataRefType);
		EndIf;
		If TableRow.UseReports Then
			AttachableCommands.SupplyTypesArray(ReportsTypes, Source.DataRefType);
		EndIf;
		If TableRow.UseRelatedObjectCreation Then
			AttachableCommands.SupplyTypesArray(RelatedObjectsCreationTypes, Source.DataRefType);
		EndIf;
	EndDo;
	
	If ObjectFillingTypes.Count() > 0 Then
		Command = Commands.Add();
		If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
			Command.Kind           = "ObjectsFilling";
			Command.Presentation = NStr("en = 'Object filling additional data processors…';");
			Command.Importance      = "SeeAlso";
		Else
			Command.Kind           = "CommandBar";
			Command.Presentation = NStr("en = 'Filling…';");
		EndIf;
		Command.ChangesSelectedObjects = True;
		Command.Order            = 50;
		Command.Handler         = "AdditionalReportsAndDataProcessorsClient.OpenCommandList";
		Command.WriteMode        = "Write";
		Command.MultipleChoice = True;
		Command.ParameterType       = New TypeDescription(ObjectFillingTypes);
		Command.AdditionalParameters = AdditionalCommandParameters(AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindObjectFilling(), False);
	ElsIf FormSettings.IsObjectForm Then
		OnDetermineFillingCommandsAttachedToObject(Commands, ObjectsIDs, CommandsSources);
	EndIf;
	
	If ReportsTypes.Count() > 0 Then
		Command = Commands.Add();
		If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
			Command.Kind           = "Reports";
			Command.Importance      = "SeeAlso";
			Command.Presentation = NStr("en = 'Additional reports…';");
		Else
			Command.Kind           = "CommandBar";
			Command.Presentation = NStr("en = 'Reports…';");
		EndIf;
		Command.Order            = 50;
		Command.Handler         = "AdditionalReportsAndDataProcessorsClient.OpenCommandList";
		Command.WriteMode        = "Write";
		Command.MultipleChoice = True;
		Command.ParameterType       = New TypeDescription(ReportsTypes);
		Command.AdditionalParameters = AdditionalCommandParameters(AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindReport(), True);
	EndIf;
	
	If RelatedObjectsCreationTypes.Count() > 0 Then
		If SetFOParameters And ObjectsIDs.Count() = 1 Then
			FormSettings.FunctionalOptions.Insert("AdditionalReportsAndDataProcessorsRelatedObject", ObjectsIDs[0]);
		Else
			Command = Commands.Add();
			Command.Kind                = ?(SetFOParameters, "CommandBar", "GenerateFrom");
			Command.Presentation      = NStr("en = 'Create related objects…';");
			Command.Picture           = PictureLib.InputOnBasis;
			Command.Order            = 50;
			Command.Handler         = "AdditionalReportsAndDataProcessorsClient.OpenCommandList";
			Command.WriteMode        = "Write";
			Command.MultipleChoice = True;
			Command.ParameterType       = New TypeDescription(RelatedObjectsCreationTypes);
			Command.AdditionalParameters = AdditionalCommandParameters(AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindRelatedObjectCreation(), False);
		EndIf;
	EndIf;
	
EndProcedure

// Adds the reports of the "Additional reports and data processors" subsystem
// whose object modules contain the DefineFormSettings procedure.
// Called from ReportsOptionsCached.Parameters.
//
// Parameters:
//   ReportsWithSettings - Array - references of the reports whose object modules contain procedure DefineFormSettings().
//
Procedure OnDetermineReportsWithSettings(ReportsWithSettings) Export
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	If Common.DataSeparationEnabled()
		And Not Common.SeparatedDataUsageAvailable() Then 
		Return;
	EndIf;

	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AdditionalReportsAndDataProcessors.Ref
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
	|WHERE
	|	AdditionalReportsAndDataProcessors.UseOptionStorage
	|	AND AdditionalReportsAndDataProcessors.DeepIntegrationWithReportForm
	|	AND NOT AdditionalReportsAndDataProcessors.DeletionMark
	|	AND AdditionalReportsAndDataProcessors.Kind IN(&ReportsKinds)";
	ReportsKinds = New Array;
	ReportsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
	ReportsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	Query.SetParameter("ReportsKinds", ReportsKinds);
	
	SetPrivilegedMode(True);
	AdditionalReportsWithSettings = Query.Execute().Unload().UnloadColumn("Ref");
	For Each Ref In AdditionalReportsWithSettings Do
		If Not IsSuppliedDataProcessor(Ref) Then
			Continue;
		EndIf;
		ReportsWithSettings.Add(Ref);
	EndDo;
	
EndProcedure

// Gets an additional report reference, provided that the report is attached to the "Report options" subsystem storage.
//
// Parameters:
//   ReportInformation - See ReportsOptions.ReportInformation.
//
Procedure OnDetermineTypeAndReferenceIfReportIsAuxiliary(ReportInformation) Export
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AdditionalReportsAndDataProcessors.Ref
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
	|WHERE
	|	AdditionalReportsAndDataProcessors.ObjectName = &ObjectName
	|	AND AdditionalReportsAndDataProcessors.DeletionMark = FALSE
	|	AND AdditionalReportsAndDataProcessors.UseOptionStorage = TRUE
	|	AND AdditionalReportsAndDataProcessors.Kind IN (&KindAdditionalReport, &KindOfReport)
	|	AND AdditionalReportsAndDataProcessors.Publication = &PublicationAvailable";
	If ReportInformation.ByDefaultAllAttachedToStorage Then
		Query.Text = StrReplace(Query.Text, "AND AdditionalReportsAndDataProcessors.UseOptionStorage = TRUE", "");
	EndIf;
	Query.SetParameter("ObjectName", ReportInformation.ReportShortName);
	Query.SetParameter("KindOfReport",               Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	Query.SetParameter("KindAdditionalReport", Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
	Query.SetParameter("PublicationAvailable", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used);
	
	// Required for generated data integrity. Access rights will apply at the use stage.
	ReferencesArrray = Query.Execute().Unload().UnloadColumn("Ref");
	For Each Ref In ReferencesArrray Do
		If Not IsSuppliedDataProcessor(Ref) Then
			Continue;
		EndIf;
		ReportInformation.Report = Ref;
	EndDo;
	
EndProcedure

// Supplements the array with references to additional reports the current user can access.
//
// Parameters:
//   AvailableReports - Array - references to reports the current user can access.
//
// Usage locations:
//   ReportsOptions.CurrentUserReports().
//
Procedure OnAddAdditionalReportsAvailableForCurrentUser(AvailableReports) Export
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	AdditionalReportsAndDataProcessors.Ref
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
	|WHERE
	|	AdditionalReportsAndDataProcessors.UseOptionStorage
	|	AND AdditionalReportsAndDataProcessors.Kind IN (&KindAdditionalReport, &KindOfReport)
	|	AND NOT AdditionalReportsAndDataProcessors.Ref IN (&AvailableReports)";
	
	Query.SetParameter("AvailableReports", AvailableReports);
	Query.SetParameter("KindOfReport",               Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	Query.SetParameter("KindAdditionalReport", Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Not IsSuppliedDataProcessor(Selection.Ref) Then
			Continue;
		EndIf;
		AvailableReports.Add(Selection.Ref);
	EndDo;
	
EndProcedure

// Supplements the array with references to additional reports the current user can access.
//
// Parameters:
//   AvailableReports - Array - full report names available to the specified user.
//   IBUser - InfoBaseUser
//   UserRef - CatalogRef.Users
//
// Usage locations:
//   DataProcessor.UsersSettings.ReportsAvailableToUser().
//
Procedure OnAddAdditionalReportsAvailableToSpecifiedUser(AvailableReports, IBUser, UserRef) Export
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors, IBUser) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AdditionalReportsAndDataProcessors.Ref AS Ref,
	|	AdditionalReportsAndDataProcessors.ObjectName AS ObjectName
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
	|		INNER JOIN InformationRegister.DataProcessorAccessUserSettings AS AccessSettings
	|		ON (AccessSettings.AdditionalReportOrDataProcessor = AdditionalReportsAndDataProcessors.Ref)
	|			AND (AccessSettings.Available = TRUE)
	|			AND (AccessSettings.User = &User)
	|			AND (AdditionalReportsAndDataProcessors.Kind IN (&KindAdditionalReport, &KindOfReport))";
	
	Query.SetParameter("User",           UserRef);
	Query.SetParameter("KindOfReport",               Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	Query.SetParameter("KindAdditionalReport", Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Not IsSuppliedDataProcessor(Selection.Ref) Then
			Continue;
		EndIf;
		FullReportName = "ExternalReport." + Selection.ObjectName;
		AvailableReports.Add(FullReportName);
	EndDo;
	
EndProcedure

// Attaches a report from the "Additional reports and data processors" subsystem.
// Exception handling is performed by the control code.
//
// Usage locations:
//   ReportsOptions.AttachReportObject.
//   ReportMailing.InitializeReport.
//   
// Parameters:
//   Ref - CatalogRef.AdditionalReportsAndDataProcessors - a report to initialize.
//   ReportParameters - See ReportMailing.InitializeReport
//   Result - Boolean
//             - Undefined - an attachment result.
//       True - an additional report is attached.
//       False - failed to attach an additional report.
//  GetMetadata - Boolean
//
Procedure OnAttachAdditionalReport(Ref, ReportParameters, Result, GetMetadata) Export
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		ReportParameters.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot attach %1. Additional reports and data processors are disabled in the application settings.';"),
			"'" + String(Ref) + "'");
		Return;
	EndIf;
	
	Kind = Common.ObjectAttributeValue(Ref, "Kind");
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report
		Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		
		Try
			ReportParameters.Name = AttachExternalDataProcessor(Ref);
			ReportParameters.Object = ExternalReports.Create(ReportParameters.Name);
			If GetMetadata Then
				ReportParameters.Metadata = ReportParameters.Object.Metadata();
			EndIf;
			Result = True;
		Except
			ReportParameters.ErrorText = 
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot attach the ""%1"" additional report due to:';"), String(Ref))
				+ Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo());
			Result = False;
		EndTry;
		
	Else
		
		ReportParameters.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 is not an additional report.';"),
			"'"+ String(Ref) +"'");
		
		Result = False;
		
	EndIf;
	
EndProcedure

// Attaches a report from the "Additional reports and data processors" subsystem.
//   Exception handling is performed by the control code.
//
// Parameters:
//   Context - Structure - a set of parameters got while checking and attaching a report.
//       See ReportsOptions.OnAttachReport.
//
// Usage locations:
//   ReportsOptions.OnAttachReport().
//
Procedure OnAttachReport(Context) Export
	Ref = CommonClientServer.StructureProperty(Context, "Report");
	If TypeOf(Ref) <> Type("CatalogRef.AdditionalReportsAndDataProcessors") Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'No report is passed to the ""%1"" procedure.';"),
			"AdditionalReportsAndDataProcessors.OnAttachReport");
	EndIf;
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Raise NStr("en = 'The ""Additional reports and data processors"" feature is disabled in the application settings.';");
	EndIf;
	
	Kind = Common.ObjectAttributeValue(Ref, "Kind");
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report
		Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		
		Context.ReportName = AttachExternalDataProcessor(Ref);
		Context.Connected = True;
		
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '""%1"" is not an additional report.';"), String(Ref));
	EndIf;
	
EndProcedure

// See PropertyManagerOverridable.OnGetPredefinedPropertiesSets.
Procedure OnGetPredefinedPropertiesSets(Sets) Export
	Set = Sets.Rows.Add();
	Set.Name = "Catalog_AdditionalReportsAndDataProcessors";
	Set.Id = New UUID("82cbc0a7-224e-48bc-a4a5-a108c3ac3bd0");
EndProcedure

Procedure OnDefineReportsAvailability(AddlReportsRefs, Result) Export
	SubsystemEnabled = True;
	HasReadRight = True;
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		SubsystemEnabled = False;
	ElsIf Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		HasReadRight = False;
	EndIf;
	
	For Each Report In AddlReportsRefs Do
		FoundItems = Result.FindRows(New Structure("Report", Report));
		For Each TableRow In FoundItems Do
			If Not SubsystemEnabled Then
				TableRow.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""%1"" report is unavailable as additional reports and data processors are disabled in the application settings.';"),
					TableRow.Presentation);
			ElsIf Not HasReadRight Then
				TableRow.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""%1"" report is unavailable as you do not have the right to read additional reports and processors.';"),
					TableRow.Presentation);
			ElsIf Not IsSuppliedDataProcessor(Report) Then
				TableRow.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""%1"" report is unavailable in SaaS mode.';"),
					TableRow.Presentation);
			Else
				TableRow.Available = True;
			EndIf;
		EndDo;
	EndDo;
EndProcedure

// Adds external print forms to the print command list.
//
// Parameters:
//   PrintCommands - See PrintManagement.CreatePrintCommandsCollection
//   ObjectName    - String          - a full name of the metadata object to obtain the list of print
//                                     commands for.
//
// Usage locations:
//   PrintManagement.FormPrintCommands().
//
Procedure OnReceivePrintCommands(PrintCommands, ObjectName) Export
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;

	Query = NewQueryByAvailableCommands(Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm, ObjectName);
	CommandsTable = Query.Execute().Unload(); // See AdditionalReportsAndDataProcessors.NewQueryByAvailableCommands 
	If CommandsTable.Count() = 0 Then
		Return;
	EndIf;
	
	For Each TableRow In CommandsTable Do
		If Not IsSuppliedDataProcessor(TableRow.Ref) Then
			Continue;
		EndIf;
		PrintCommand = PrintCommands.Add();
		
		// Mandatory parameters.
		FillPropertyValues(PrintCommand, TableRow, "Id, Presentation");
		// Parameters used as subsystem IDs.
		PrintCommand.PrintManager = "StandardSubsystems.AdditionalReportsAndDataProcessors";
		
		// Additional parameters.
		PrintCommand.AdditionalParameters = New Structure("Ref, Modifier, StartupOption, ShouldShowUserNotification");
		FillPropertyValues(PrintCommand.AdditionalParameters, TableRow);
	EndDo;
	
EndProcedure

// Fills a list of print forms from external sources.
//
// Parameters:
//   ExternalPrintForms - ValueList:
//       Value      - String - a print form ID.
//       Presentation - String - a print form name.
//   FullMetadataObjectName - String - Full name of the metadata object to get print form list for.
//       
//
Procedure OnReceiveExternalPrintFormList(ExternalPrintForms, FullMetadataObjectName) Export
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	
	Query = NewQueryByAvailableCommands(Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm, FullMetadataObjectName);
	CommandsTable = Query.Execute().Unload(); // See AdditionalReportsAndDataProcessors.NewQueryByAvailableCommands
	
	For Each Command In CommandsTable Do
		If Not IsSuppliedDataProcessor(Command.Ref) Then
			Continue;
		EndIf;
		If Command.StartupOption <> Enums.AdditionalDataProcessorsCallMethods.ServerMethodCall Then
			Continue;
		EndIf;
		If StrFind(Command.Id, ",") = 0 Then // Ignore sets.
			ExternalPrintForms.Add(Command.Id, Command.Presentation);
		EndIf;
	EndDo;
	
EndProcedure

// Returns a reference to an external print form object.
//
Procedure OnReceiveExternalPrintForm(Id, FullMetadataObjectName, ExternalPrintFormRef) Export
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	
	Query = NewQueryByAvailableCommands(Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm, FullMetadataObjectName);
	CommandsTable = Query.Execute().Unload(); // See AdditionalReportsAndDataProcessors.NewQueryByAvailableCommands
	
	Command = CommandsTable.Find(Id, "Id");
	If Command <> Undefined Then 
		ExternalPrintFormRef = Command.Ref;
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddReferenceSearchExceptions.
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export
	
	RefSearchExclusions.Add("Catalog.AdditionalReportsAndDataProcessors.TabularSection.Sections.Attribute.Section");
	RefSearchExclusions.Add("Catalog.AdditionalReportsAndDataProcessors.TabularSection.Purpose.Attribute.RelatedObject");
	
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings
Procedure OnDefineScheduledJobSettings(Settings) Export
	
	Setting = Settings.Add();
	Setting.ScheduledJob = Metadata.ScheduledJobs.StartingAdditionalDataProcessors;
	Setting.UseExternalResources = True;
	
EndProcedure

Function AdditionalReportsAndProcessingAreUpdated(Queue) Export
	Return InfobaseUpdate.HasDataLockedByPreviousQueues(Queue, "Catalog.AdditionalReportsAndDataProcessors");
EndFunction

Function AdditionalReportTableName() Export
	
	Return "Catalog.AdditionalReportsAndDataProcessors";
	
EndFunction

Function IsDataProcessorTypeForMessageTemplates(DataProcessorKind) Export

	If DataProcessorKind = GetDataProcessorKindByKindStringPresentation(
		AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindMessageTemplate()) Then
		Return True;
	EndIf;

	Return False;
	
EndFunction

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Scheduled jobs.

// StartingDataProcessors scheduled job instance handler.
//   Starts a global data processor handler for the scheduled job
//   using the specified command ID.
//
// Parameters:
//   ExternalDataProcessor     - CatalogRef.AdditionalReportsAndDataProcessors - a reference to the data processor being executed.
//   CommandID - String - an ID of the command being executed.
//
Procedure ExecuteDataProcessorByScheduledJob(ExternalDataProcessor, CommandID) Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.StartingAdditionalDataProcessors);
	
	// Event log record.
	WriteInformation(ExternalDataProcessor, 
		StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Command %1: Start.';"), CommandID));
	
	// Run the command.
	Try
		ExecuteCommand(New Structure("AdditionalDataProcessorRef, CommandID", ExternalDataProcessor, CommandID), Undefined);
	Except
		Refinement = CommonClientServer.ExceptionClarification(ErrorInfo(),
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t execute command %1 due to:';"), CommandID));
		Raise(Refinement.Text, Refinement.Category,,, ErrorInfo());
	EndTry;
	
	// Event log record.
	WriteInformation(ExternalDataProcessor, 
		StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Command %1: Complete.';"), CommandID));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Returns True when the specified additional report (data processor) kind is global.
//
// Parameters:
//   Kind - EnumRef.AdditionalReportsAndDataProcessorsKinds - External data processor type.
//
// Returns:
//     Boolean - True - a data processor is global.
//    False   - a data processor is assignable.
//
Function CheckGlobalDataProcessor(Kind) Export
	
	Return Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor
		Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport;
	
EndFunction

// Transforms an additional report (data processor) type from a string constant to an enumeration reference.
//
// Parameters:
//   StringPresentation - String - String presentation of the type.
//
// Returns: 
//   EnumRef.AdditionalReportsAndDataProcessorsKinds - a reference of the kind.
//
Function GetDataProcessorKindByKindStringPresentation(StringPresentation) Export
	
	If StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindObjectFilling() Then
		Return Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindReport() Then
		Return Enums.AdditionalReportsAndDataProcessorsKinds.Report;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindPrintForm() Then
		Return Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindRelatedObjectCreation() Then
		Return Enums.AdditionalReportsAndDataProcessorsKinds.RelatedObjectsCreation;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindMessageTemplate() Then
		Return Enums.AdditionalReportsAndDataProcessorsKinds.MessageTemplate;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalDataProcessor() Then
		Return Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalReport() Then
		Return Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport;
	EndIf;
	
EndFunction

// Returns:
//  String
//
Function KindToString(KindRef) Export
	
	If KindRef = Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindObjectFilling();
		
	ElsIf KindRef = Enums.AdditionalReportsAndDataProcessorsKinds.Report Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindReport();
		
	ElsIf KindRef = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindPrintForm();
		
	ElsIf KindRef = Enums.AdditionalReportsAndDataProcessorsKinds.RelatedObjectsCreation Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindRelatedObjectCreation();
		
	ElsIf KindRef = Enums.AdditionalReportsAndDataProcessorsKinds.MessageTemplate Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindMessageTemplate();
		
	ElsIf KindRef = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalDataProcessor();
		
	ElsIf KindRef = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalReport();
		
	Else
		Return "";
	EndIf;
	
EndFunction

// Returns:
//  String
//
Function MetadataObjectPresentation(Object) Export
	If TypeOf(Object) = Type("CatalogRef.MetadataObjectIDs") Then
		MetadataObject = Common.MetadataObjectByID(Object, False);
		If TypeOf(MetadataObject) <> Type("MetadataObject") Then
			Return NStr("en = '<does not exist>';");
		EndIf;
	ElsIf TypeOf(Object) = Type("MetadataObject") Then
		MetadataObject = Object;
	Else
		MetadataObject = Metadata.Subsystems.Find(Object);
	EndIf;
	Return MetadataObject.Presentation();
EndFunction

// Returns:
//  Boolean
//
Function InsertRight1(Val AdditionalDataProcessor = Undefined) Export
	
	Result = False;
	StandardProcessing = True;
	
	SSLSubsystemsIntegration.OnCheckInsertRight(AdditionalDataProcessor, Result, StandardProcessing);
	
	If StandardProcessing Then
		
		If Common.DataSeparationEnabled()
		   And Common.SeparatedDataUsageAvailable() Then
			
			Result = Users.IsFullUser(, True);
		Else
			Result = AccessRight("Update", Metadata.Catalogs.AdditionalReportsAndDataProcessors);
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Checks whether an additional report or data processor can be exported to a file.
//
// Parameters:
//   DataProcessor - CatalogRef.AdditionalReportsAndDataProcessors
//
// Returns:
//   Boolean
//
Function CanExportDataProcessorToFile(Val DataProcessor) Export
	
	Result = False;
	StandardProcessing = True;
	
	SSLSubsystemsIntegration.OnCheckCanExportDataProcessorToFile(DataProcessor, Result, StandardProcessing);
	If Not StandardProcessing Then
		Return Result;
	EndIf;
		
	Return True;
	
EndFunction

// Checks whether an additional data processor already existing in the infobase can be imported from a file.
//
// Parameters:
//   DataProcessor - CatalogRef.AdditionalReportsAndDataProcessors
//
// Returns:
//   Boolean
//
Function CanImportDataProcessorFromFile(Val DataProcessor) Export
	
	Result = False;
	StandardProcessing = True;
	SSLSubsystemsIntegration.OnCheckCanImportDataProcessorFromFile(DataProcessor, Result, StandardProcessing);
		
	If Not StandardProcessing Then
		Return Result;
	EndIf;
		
	Return True;
	
EndFunction

// Returns a flag specifying whether extended information on an additional report or a data processor must be displayed to the user.
//
// Parameters:
//   DataProcessor - CatalogRef.AdditionalReportsAndDataProcessors
//
// Returns:
//   Boolean
//
Function DisplayExtendedInformation(Val DataProcessor) Export
	
	Return True;
	
EndFunction

// Publication kinds unavailable for use in the current application mode.
//
// Returns:
//  Array of String
//
Function NotAvailablePublicationKinds() Export
	
	Result = New Array;
	SSLSubsystemsIntegration.OnFillUnavailablePublicationKinds(Result);
	Return Result;
	
EndFunction

Function IsSuppliedDataProcessor(Ref)
	
	If Common.DataSeparationEnabled() 
		And Common.SubsystemExists("StandardSubsystems.SaaSOperations.AdditionalReportsAndDataProcessorsSaaS") Then
		
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule("AdditionalReportsAndDataProcessorsSaaS");
		Return ModuleAdditionalReportsAndDataProcessorsSaaS.IsSuppliedDataProcessor(Ref);
		
	EndIf;
	Return True; // including local operation mode
	
EndFunction	
	
// The function is called on generating a new query used to get a command table for additional reports or data processors.
// Writing an error to the event log dedicated to the additional report (data processor).
//
Procedure WriteError(Ref, MessageText) Export
	WriteToLog(EventLogLevel.Error, Ref, MessageText);
EndProcedure

// Writing a warning to the event log dedicated to the additional report (data processor).
Procedure WriteWarning(Ref, MessageText)
	WriteToLog(EventLogLevel.Warning, Ref, MessageText);
EndProcedure

// Writing information to the event log dedicated to the additional report (data processor).
Procedure WriteInformation(Ref, MessageText)
	WriteToLog(EventLogLevel.Information, Ref, MessageText);
EndProcedure

// Writing a comment to the event log dedicated to the additional report (data processor).
Procedure WriteComment(Ref, MessageText)
	WriteToLog(EventLogLevel.Note, Ref, MessageText);
EndProcedure

// Writing an event to the event log dedicated to the additional report (data processor).
Procedure WriteToLog(Level, Ref, Text)
	WriteLogEvent(SubsystemDescription(), Level, Metadata.Catalogs.AdditionalReportsAndDataProcessors,
		Ref, Text);
EndProcedure

// Generates a subsystem description to write an event to the event log.
//
Function SubsystemDescription()
	Return NStr("en = 'Additional reports and data processors';", Common.DefaultLanguageCode());
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// For internal use.
Procedure ExecuteAdditionalReportOrDataProcessorCommand(ExternalObject, Val CommandID, CommandParameters)
	
	If CommandParameters = Undefined Then
		
		ExternalObject.ExecuteCommand(CommandID);
		
	Else
		
		ExternalObject.ExecuteCommand(CommandID, CommandParameters);
		
	EndIf;
	
EndProcedure

// For internal use.
Procedure ExecuteAssignableAdditionalReportOrDataProcessorCommand(ExternalObject, Val CommandID, CommandParameters, RelatedObjects)
	
	If CommandParameters = Undefined Then
		ExternalObject.ExecuteCommand(CommandID, RelatedObjects);
	Else
		ExternalObject.ExecuteCommand(CommandID, RelatedObjects, CommandParameters);
	EndIf;
	
EndProcedure

// For internal use.
Procedure ExecuteRelatedObjectsCreationCommand(ExternalObject, Val CommandID, CommandParameters, RelatedObjects, ModifiedObjects)
	
	If CommandParameters = Undefined Then
		ExternalObject.ExecuteCommand(CommandID, RelatedObjects, ModifiedObjects);
	Else
		ExternalObject.ExecuteCommand(CommandID, RelatedObjects, ModifiedObjects, CommandParameters);
	EndIf;
	
EndProcedure

// For internal use.
Procedure ExecutePrintFormCreationCommand(ExternalObject, Val CommandID, CommandParameters, RelatedObjects)
	
	If CommandParameters = Undefined Then
		ExternalObject.Print(CommandID, RelatedObjects);
	Else
		ExternalObject.Print(CommandID, RelatedObjects, CommandParameters);
	EndIf;
	
EndProcedure

// Executes an additional report (data processor) command from an object.
Function ExecuteExternalObjectCommand(ExternalObject, CommandID, CommandParameters, ResultAddress)
	
	ExternalObjectInfo = ExternalObject.ExternalDataProcessorInfo(); // See ExternalDataProcessorInfo
	
	DataProcessorKind = GetDataProcessorKindByKindStringPresentation(ExternalObjectInfo.Kind);
	
	PassParameters = (
		ExternalObjectInfo.Property("SSLVersion")
		And CommonClientServer.CompareVersions(ExternalObjectInfo.SSLVersion, "1.2.1.4") >= 0);
	
	ExecutionResult = CommonClientServer.StructureProperty(CommandParameters, "ExecutionResult");
	If TypeOf(ExecutionResult) <> Type("Structure") Then
		CommandParameters.Insert("ExecutionResult", New Structure());
	EndIf;
	
	CommandDetails = ExternalObjectInfo.Commands.Find(CommandID, "Id");
	If CommandDetails = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Command %1 is not found.';"), CommandID);
	EndIf;
	
	ModifiedObjects = Undefined;
	
	If DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor
		Or DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		
		ExecuteAdditionalReportOrDataProcessorCommand(
			ExternalObject,
			CommandID,
			?(PassParameters, CommandParameters, Undefined));
		
	ElsIf DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.RelatedObjectsCreation Then
		
		ModifiedObjects = New Array;
		ExecuteRelatedObjectsCreationCommand(
			ExternalObject,
			CommandID,
			?(PassParameters, CommandParameters, Undefined),
			CommandParameters.RelatedObjects,
			ModifiedObjects);
		
	ElsIf DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling
		Or DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.Report
		Or DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
		
		RelatedObjects = Undefined;
		CommandParameters.Property("RelatedObjects", RelatedObjects);
		
		If DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
			
			// Only custom print is available here. To print in MXL, use the Print tools subsystem.
			ExecutePrintFormCreationCommand(
				ExternalObject,
				CommandID,
				?(PassParameters, CommandParameters, Undefined),
				RelatedObjects);
			
		Else
			
			ExecuteAssignableAdditionalReportOrDataProcessorCommand(
				ExternalObject,
				CommandID,
				?(PassParameters, CommandParameters, Undefined),
				RelatedObjects);
			
			If DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling Then
				ModifiedObjects = RelatedObjects;
			EndIf;
		EndIf;
		
	EndIf;
	
	CommandParameters.ExecutionResult.Insert("NotifyForms", StandardSubsystemsServer.PrepareFormChangeNotification(ModifiedObjects));
	
	If TypeOf(ResultAddress) = Type("String") And IsTempStorageURL(ResultAddress) Then
		PutToTempStorage(CommandParameters.ExecutionResult, ResultAddress);
	EndIf;
	
	Return CommandParameters.ExecutionResult;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures used for data exchange.

// Overrides standard behavior during data import.
// Attribute GUIDScheduledJob of the Commands tabular section cannot be transferred
// because it is related to a scheduled job of the current infobase.
//
Procedure OnGetAdditionalDataProcessor(DataElement, ItemReceive)
	
	If ItemReceive = DataItemReceive.Ignore Then
		
		// No overriding for standard data processor.
		
	ElsIf TypeOf(DataElement) = Type("CatalogObject.AdditionalReportsAndDataProcessors")
		And DataElement.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor Then
		
		// The table of scheduled job UUIDs.
		QueryText =
		"SELECT
		|	Commands.Ref AS Ref,
		|	Commands.Id AS Id,
		|	Commands.GUIDScheduledJob AS GUIDScheduledJob
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors.Commands AS Commands
		|WHERE
		|	Commands.Ref = &Ref";
		
		Query = New Query(QueryText);
		Query.Parameters.Insert("Ref", DataElement.Ref);
		
		ScheduledJobsIDs = Query.Execute().Unload();
		
		// Filling in the command table with the scheduled job IDs based on the current database data.
		For Each StringCommand In DataElement.Commands Do
			FoundItems = ScheduledJobsIDs.FindRows(New Structure("Id", StringCommand.Id));
			If FoundItems.Count() = 0 Then
				StringCommand.GUIDScheduledJob = CommonClientServer.BlankUUID();
			Else
				StringCommand.GUIDScheduledJob = FoundItems[0].GUIDScheduledJob;
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Mapping catalog items with configuration metadata objects.


// Parameters:
//  ReportsAndDataProcessors - See ImportAdditionalReportsAndDataProcessorsFromMetadata.ReportsAndDataProcessors
//
Procedure MapConfigurationDataProcessorsWithCatalogDataProcessors(ReportsAndDataProcessors)
	DataProcessorsFromConfiguration = DataProcessorsFromConfiguration();
	
	For Each ConfigurationDataProcessor In DataProcessorsFromConfiguration Do
		ConfigurationDataProcessor.ObjectName = Upper(ConfigurationDataProcessor.ObjectName);
		ConfigurationDataProcessor.FileName   = Upper(ConfigurationDataProcessor.FileName);
	EndDo;
	DataProcessorsFromConfiguration.Columns.Add("Found1", New TypeDescription("Boolean"));
	
	ReportsAndDataProcessors.Columns.Add("Name");
	ReportsAndDataProcessors.Columns.Add("FileName");
	ReportsAndDataProcessors.Columns.Add("FullName");
	ReportsAndDataProcessors.Columns.Add("Kind");
	ReportsAndDataProcessors.Columns.Add("Extension");
	ReportsAndDataProcessors.Columns.Add("Manager");
	ReportsAndDataProcessors.Columns.Add("InformationRecords");
	ReportsAndDataProcessors.Columns.Add("DataFromCatalog");
	ReportsAndDataProcessors.Columns.Add("Ref");
	
	ReverseIndex = ReportsAndDataProcessors.Count();
	While ReverseIndex > 0 Do
		ReverseIndex = ReverseIndex - 1;
		TableRow = ReportsAndDataProcessors.Get(ReverseIndex);
		
		TableRow.Name = TableRow.MetadataObject.Name;
		TableRow.FullName = TableRow.MetadataObject.FullName();
		TableRow.Kind = Upper(StrSplit(TableRow.FullName, ".")[0]);
		If TableRow.Kind = "REPORT" Then
			TableRow.Extension = "erf";
			ManagerFromConfigurationMetadata = Reports[TableRow.Name];
		ElsIf TableRow.Kind = "DATAPROCESSOR" Then
			TableRow.Extension = "epf";
			ManagerFromConfigurationMetadata = DataProcessors[TableRow.Name];
		Else
			ReportsAndDataProcessors.Delete(ReverseIndex);
			Continue; // Unsupported metadata object kind.
		EndIf;
		TableRow.FileName = TableRow.Name + "." + TableRow.Extension;
		TableRow.OldFilesNames.Insert(0, TableRow.FileName);
		TableRow.OldObjectsNames.Insert(0, TableRow.Name);
		
		TableRow.InformationRecords = ManagerFromConfigurationMetadata.Create().ExternalDataProcessorInfo();
		
		// Search by the catalog.
		DataFromCatalog = Undefined;
		For Each FileName In TableRow.OldFilesNames Do
			DataFromCatalog = DataProcessorsFromConfiguration.Find(Upper(FileName), "FileName");
			If DataFromCatalog <> Undefined Then
				Break;
			EndIf;
		EndDo;
		If DataFromCatalog = Undefined Then
			For Each ObjectName In TableRow.OldObjectsNames Do
				DataFromCatalog = DataProcessorsFromConfiguration.Find(Upper(ObjectName), "ObjectName");
				If DataFromCatalog <> Undefined Then
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		If DataFromCatalog = Undefined Then
			Continue; // Registering a new data processor.
		EndIf;
		
		If VersionAsNumber(DataFromCatalog.Version) = VersionAsNumber(TableRow.InformationRecords.Version)
			And TableRow.InformationRecords.Version <> Metadata.Version Then
			// Update is not required because the catalog contains the latest version of the data processor.
			ReportsAndDataProcessors.Delete(ReverseIndex);
		Else
			// Registering a reference for update.
			TableRow.Ref = DataFromCatalog.Ref;
		EndIf;
		DataProcessorsFromConfiguration.Delete(DataFromCatalog);
		
	EndDo;
	
	ReportsAndDataProcessors.Columns.Delete("OldFilesNames");
	ReportsAndDataProcessors.Columns.Delete("OldObjectsNames");
EndProcedure

// Returns:
//   ValueTable:
//   * Ref - CatalogRef.AdditionalReportsAndDataProcessors
//   * Version - String
//   * ObjectName - String
//   * FileName - String
//
Function DataProcessorsFromConfiguration()
	Var DataProcessorsFromConfiguration;
	Var Query;
	Query = New Query;
	Query.Text =
	"SELECT
	|	AdditionalReportsAndDataProcessors.Ref,
	|	AdditionalReportsAndDataProcessors.Version,
	|	AdditionalReportsAndDataProcessors.ObjectName,
	|	AdditionalReportsAndDataProcessors.FileName
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors";
	
	DataProcessorsFromConfiguration = Query.Execute().Unload();
	Return DataProcessorsFromConfiguration
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Exporting configuration reports and data processors to files of external reports and data processors.

// Parameters:
//  ReportsAndDataProcessors - See ImportAdditionalReportsAndDataProcessorsFromMetadata.ReportsAndDataProcessors
//
Procedure ExportReportsAndDataProcessorsToFiles(ReportsAndDataProcessors)
	
	ReportsAndDataProcessors.Columns.Add("BinaryData");
	Parameters = New Structure;
	Parameters.Insert("WorkingDirectory", FileSystem.CreateTemporaryDirectory("ARADP"));
	StartupCommand = New Array;
	StartupCommand.Add("/DumpConfigToFiles");
	StartupCommand.Add(Parameters.WorkingDirectory);
	Upload0 = DesignerBatchRun(Parameters, StartupCommand);
	If Not Upload0.Success Then
		ErrorText = TrimAll(
			NStr("en = 'Failed to export reports and configuration data processors to external files:';")
			+ Chars.LF + Upload0.Brief1
			+ Chars.LF + Upload0.More);
		WriteWarning(Undefined, ErrorText);
		ReportsAndDataProcessors.Clear();
	EndIf;
	
	ReverseIndex = ReportsAndDataProcessors.Count();
	While ReverseIndex > 0 Do
		ReverseIndex = ReverseIndex - 1;
		TableRow = ReportsAndDataProcessors.Get(ReverseIndex);
		
		If TableRow.Kind = "REPORT" Then
			KindDirectory = Parameters.WorkingDirectory + "Reports" + GetPathSeparator();
		ElsIf TableRow.Kind = "DATAPROCESSOR" Then
			KindDirectory = Parameters.WorkingDirectory + "DataProcessors" + GetPathSeparator();
		Else
			WriteError(TableRow.Ref, 
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Invalid metadata object kind: ""1""';"), TableRow.Kind));
			ReportsAndDataProcessors.Delete(ReverseIndex);
			Continue;
		EndIf;
		
		FullObjectSchemaName = KindDirectory + TableRow.Name + ".xml";
		SchemaText = ReadTextFile(FullObjectSchemaName);
		If SchemaText = Undefined Then
			WriteError(TableRow.Ref, 
				StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot find file: %1.';"), 
					FullObjectSchemaName));
			ReportsAndDataProcessors.Delete(ReverseIndex);
			Continue;
		EndIf;
		If TableRow.Kind = "REPORT" Then
			SchemaText = StrReplace(SchemaText, "Report", "ExternalReport");
			SchemaText = StrReplace(SchemaText, "ExternalReportTabularSection", "ReportTabularSection");
		ElsIf TableRow.Kind = "DATAPROCESSOR" Then
			SchemaText = StrReplace(SchemaText, "DataProcessor", "ExternalDataProcessor");
		EndIf;
		WriteTextFile(FullObjectSchemaName, SchemaText);
		
		If TableRow.Kind = "DATAPROCESSOR" Then
			DOMDocument = ReadDOMDocument(FullObjectSchemaName);
			Dereferencer = New DOMNamespaceResolver(DOMDocument);
			XMLChanged = False;
			
			SearchExpressionsForNodesToDelete = New Array;
			SearchExpressionsForNodesToDelete.Add("//xmlns:Command");
			SearchExpressionsForNodesToDelete.Add("//*[contains(@name, 'ExternalDataProcessorManager.')]");
			SearchExpressionsForNodesToDelete.Add("//xmlns:UseStandardCommands");
			SearchExpressionsForNodesToDelete.Add("//xmlns:IncludeHelpInContents");
			SearchExpressionsForNodesToDelete.Add("//xmlns:ExtendedPresentation");
			SearchExpressionsForNodesToDelete.Add("//xmlns:Explanation");
			
			For Each Expression In SearchExpressionsForNodesToDelete Do
				XPathResult = EvaluateXPathExpression(Expression, DOMDocument, Dereferencer);
				DOMElement = XPathResult.IterateNext();
				While DOMElement <> Undefined Do
					DOMElement.ParentNode.RemoveChild(DOMElement);
					XMLChanged = True;
					DOMElement = XPathResult.IterateNext();
				EndDo;
			EndDo;
			
			If XMLChanged Then
				WriteDOMDocument(DOMDocument, FullObjectSchemaName);
			EndIf;
		EndIf;
		
		FullFileName = Parameters.WorkingDirectory + TableRow.FileName;
		StartupCommand = New Array;
		StartupCommand.Add("/LoadExternalDataProcessorOrReportFromFiles");
		StartupCommand.Add(FullObjectSchemaName);
		StartupCommand.Add(FullFileName);
		CreateDataProcessor = DesignerBatchRun(Parameters, StartupCommand);
		If Not CreateDataProcessor.Success Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot create %1 from the external file %2:
					|%3
					|%4';"),
				TableRow.FullName, FullObjectSchemaName, 
				CreateDataProcessor.Brief1, CreateDataProcessor.More);
			WriteWarning(Undefined, ErrorText);
			ReportsAndDataProcessors.Delete(ReverseIndex);
			Continue;
		EndIf;
		TableRow.BinaryData = New BinaryData(FullFileName);
	EndDo;
	
	If Parameters.OneCDCopyDirectory <> Undefined Then
		FileSystem.DeleteTemporaryDirectory(Parameters.OneCDCopyDirectory);
	EndIf;
	FileSystem.DeleteTemporaryDirectory(Parameters.WorkingDirectory);
	
EndProcedure

Function DesignerBatchRun(Parameters, PassedStartupCommands)
	Result = New Structure("Success, Brief1, More", False, "", "");
	ParametersSample = New Structure("WorkingDirectory, User, Password, BINDirectory, ConfigurationPath, OneCDCopyDirectory");
	CommonClientServer.SupplementStructure(Parameters, ParametersSample, False);
	If Not ValueIsFilled(Parameters.User) Then
		Parameters.User = UserName();
	EndIf;
	If Not FileExists(Parameters.WorkingDirectory) Then
		CreateDirectory(Parameters.WorkingDirectory);
	EndIf;
	If Not ValueIsFilled(Parameters.BINDirectory) Then
		Parameters.BINDirectory = BinDir();
	EndIf;
	If Not ValueIsFilled(Parameters.ConfigurationPath) Then
		Parameters.ConfigurationPath = InfoBaseConnectionString();
		If DesignerIsOpen() Then
			If Common.FileInfobase() Then
				InfobaseDirectory = StringFunctionsClientServer.ParametersFromString(Parameters.ConfigurationPath).file;
				Parameters.OneCDCopyDirectory = Parameters.WorkingDirectory + "BaseCopy" + GetPathSeparator();
				CreateDirectory(Parameters.OneCDCopyDirectory);
				FileCopy(InfobaseDirectory + "\1Cv8.1CD", Parameters.OneCDCopyDirectory + "1Cv8.1CD");
				Parameters.ConfigurationPath = StringFunctionsClientServer.SubstituteParametersToString(
					"File=""%1"";", Parameters.OneCDCopyDirectory);
			Else
				Result.Brief1 = NStr("en = 'To export modules, close Designer.';");
				Return Result;
			EndIf;
		EndIf;
	EndIf;
	
	MessagesFileName = Parameters.WorkingDirectory + "Upload0.log";
	
	StartupCommand = New Array;
	StartupCommand.Add(Parameters.BINDirectory + "1cv8.exe");
	StartupCommand.Add("DESIGNER");
	StartupCommand.Add("/IBConnectionString");
	StartupCommand.Add(Parameters.ConfigurationPath);
	StartupCommand.Add("/N");
	StartupCommand.Add(Parameters.User);
	StartupCommand.Add("/P");
	StartupCommand.Add(Parameters.Password);
	CommonClientServer.SupplementArray(StartupCommand, PassedStartupCommands);
	StartupCommand.Add("/Out");
	StartupCommand.Add(MessagesFileName);
	StartupCommand.Add("/DisableStartupMessages");
	StartupCommand.Add("/DisableStartupDialogs");
	
	CommandRunParameters = FileSystem.ApplicationStartupParameters();
	CommandRunParameters.WaitForCompletion = True;
	
	RunResult = FileSystem.StartApplication(StartupCommand, CommandRunParameters);
	
	ReturnCode = RunResult.ReturnCode;
	If ReturnCode = 0 Then
		Result.Success = True;
		Return Result;
	EndIf;
	
	Result.Brief1 = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot dump configuration to XML. Error code: %1.';"),
		ReturnCode);
	If FileExists(MessagesFileName) Then
		TextReader = New TextReader(MessagesFileName, , , , False);
		Messages = TrimAll(TextReader.Read());
		TextReader.Close();
		If Messages <> "" Then
			Result.More = StrReplace(Chars.LF + Messages, Chars.LF, Chars.LF + Chars.Tab);
		EndIf;
	EndIf;
	Return Result;
	
EndFunction

Function FileExists(FullFileName)
	File = New File(FullFileName);
	Return File.Exists();
EndFunction

Function DesignerIsOpen()
	Sessions = GetInfoBaseSessions();
	For Each Session In Sessions Do
		If Upper(Session.ApplicationName) = "DESIGNER" Then
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

Function ReadTextFile(FullFileName)
	If Not FileExists(FullFileName) Then
		Return Undefined;
	EndIf;
	TextReader = New TextReader(FullFileName);
	Text = TextReader.Read();
	TextReader.Close();
	Return Text;
EndFunction

Procedure WriteTextFile(FullFileName, Text)
	TextWriter = New TextWriter(FullFileName, TextEncoding.UTF8);
	TextWriter.Write(Text);
	TextWriter.Close();
EndProcedure

Function ReadDOMDocument(PathToFile)
	XMLReader = New XMLReader;
	XMLReader.OpenFile(PathToFile);
	DOMBuilder = New DOMBuilder;
	DOMDocument = DOMBuilder.Read(XMLReader);
	XMLReader.Close();
	
	Return DOMDocument;
EndFunction

Function EvaluateXPathExpression(Expression, DOMDocument, Dereferencer)
	Return DOMDocument.EvaluateXPathExpression(Expression, DOMDocument, Dereferencer);
EndFunction

Procedure WriteDOMDocument(DOMDocument, FileName)
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(FileName);
	DOMWriter = New DOMWriter;
	DOMWriter.Write(DOMDocument, XMLWriter);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Performs batch registration of external reports and data processors in the catalog.

Procedure RegisterReportsAndDataProcessors(ReportsAndDataProcessors)
	
	DataProcessorsNames = ReportsAndDataProcessors.UnloadColumn("Name");
	DataProcessorsRefs = ReportsAndDataProcessors.UnloadColumn("Ref");
	AllConflictingOnes = AllConflictingReportsAndDataProcessors(DataProcessorsRefs, DataProcessorsNames);
	
	AdditionalReportsAndDataProcessorsKinds = New Array;
	AdditionalReportsAndDataProcessorsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
	AdditionalReportsAndDataProcessorsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	
	For Each TableRow In ReportsAndDataProcessors Do
		// Update or add.
		If TableRow.Ref = Undefined Then
			CatalogObject = Catalogs.AdditionalReportsAndDataProcessors.CreateItem();
			CatalogObject.UseForObjectForm = True;
			CatalogObject.UseForListForm  = True;
			CatalogObject.EmployeeResponsible               = Users.CurrentUser();
		Else
			CatalogObject = TableRow.Ref.GetObject();
		EndIf;
		
		IsReport      = (TableRow.Kind = "REPORT");
		DataAddress   = PutToTempStorage(TableRow.BinaryData);
		Manager      = ?(IsReport, ExternalReports, ExternalDataProcessors);
		ObjectName = Manager.Connect(DataAddress, , True,
			Common.ProtectionWithoutWarningsDetails());
		ExternalObject = Manager.Create(ObjectName);
		
		ExternalObjectMetadata = ExternalObject.Metadata();
		DataProcessorInfo = TableRow.InformationRecords;
		If DataProcessorInfo.Description = Undefined Or DataProcessorInfo.Information = Undefined Then
			If DataProcessorInfo.Description = Undefined Then
				DataProcessorInfo.Description = ExternalObjectMetadata.Presentation();
			EndIf;
			If DataProcessorInfo.Information = Undefined Then
				DataProcessorInfo.Information = ExternalObjectMetadata.Comment;
			EndIf;
		EndIf;
		
		FillPropertyValues(CatalogObject, DataProcessorInfo, "Description, SafeMode, Version, Information");
		
		// Exporting command settings that can be changed by administrator.
		JobsSearch = New Map;
		For Each ObsoleteCommand In CatalogObject.Commands Do
			If ValueIsFilled(ObsoleteCommand.GUIDScheduledJob) Then
				JobsSearch.Insert(Upper(ObsoleteCommand.Id), ObsoleteCommand.GUIDScheduledJob);
			EndIf;
		EndDo;
		
		RegistrationParameters = New Structure;
		RegistrationParameters.Insert("DataProcessorDataAddress", DataAddress);
		RegistrationParameters.Insert("IsReport", IsReport);
		RegistrationParameters.Insert("DisableConflicts", False);
		RegistrationParameters.Insert("FileName", TableRow.FileName);
		RegistrationParameters.Insert("DisablePublication", False);
		
		CatalogObject.ObjectName = Undefined;
		CatalogObject.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used;
		CatalogObject.Kind        = GetDataProcessorKindByKindStringPresentation(
			DataProcessorInfo.Kind);
		
		Conflicting = New ValueList;
		Filter = New Structure;
		Filter.Insert("ObjectName", TableRow.Name);
		FoundItems = AllConflictingOnes.FindRows(Filter);
		For Each Found3 In FoundItems Do
			ConflictKindReport = AdditionalReportsAndDataProcessorsKinds.Find(Found3.Kind) <> Undefined;
			If IsReport And Not ConflictKindReport Then
				Continue;
			ElsIf Not IsReport And ConflictKindReport Then
				Continue;
			EndIf;
			
			Conflicting.Add(Found3.Ref, Found3.Presentation);
		EndDo;
		If Conflicting.Count() <> 0 Then
			RegistrationParameters.Insert("DisableConflicts", True);
			RegistrationParameters.Insert("Conflicting", Conflicting);
		EndIf;
		Result = RegisterDataProcessor(CatalogObject, RegistrationParameters);
		If Not Result.Success Then
			If Conflicting.Count() <> 0 Then
				Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Name %1 is assigned to objects %2.';"),
					ObjectName,
					String(Conflicting));
			EndIf;
			WriteLogEvent(
				SubsystemDescription(),
				EventLogLevel.Error,
				Metadata.CommonTemplates.Find(TableRow.TemplateName),
				,
				Result.ErrorText);
			Continue;
		EndIf;
		
		CatalogObject.DataProcessorStorage = New ValueStorage(TableRow.BinaryData);
		CatalogObject.ObjectName         = ExternalObjectMetadata.Name;
		CatalogObject.FileName           = TableRow.FileName;
		
		// Clearing and importing new commands.
		For Each Command In CatalogObject.Commands Do
			GUIDScheduledJob = JobsSearch.Get(Upper(Command.Id));
			If GUIDScheduledJob <> Undefined Then
				Command.GUIDScheduledJob = GUIDScheduledJob;
				JobsSearch.Delete(Upper(Command.Id));
			EndIf;
		EndDo;
		
		// Delete outdated jobs.
		For Each KeyAndValue In JobsSearch Do
			Try
				Job = ScheduledJobsServer.Job(KeyAndValue.Value);
				Job.Delete();
			Except
				WriteLogEvent(InfobaseUpdate.EventLogEvent(),
					EventLogLevel.Error,, CatalogObject.Ref,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot delete the ""%1"" scheduled job due to:
							|%2';"),
						KeyAndValue.Value,
						ErrorProcessing.DetailErrorDescription(ErrorInfo())));
			EndTry;
		EndDo;
		
		If CheckGlobalDataProcessor(CatalogObject.Kind) Then
			MetadataObjectsTable = AttachedMetadataObjects(CatalogObject.Kind);
			For Each TableRow In MetadataObjectsTable Do
				SectionReference = TableRow.Ref;
				SectionRow = CatalogObject.Sections.Find(SectionReference, "Section");
				If SectionRow = Undefined Then
					SectionRow = CatalogObject.Sections.Add();
					SectionRow.Section = SectionReference;
				EndIf;
			EndDo;
		Else
			For Each AssignmentDetails In DataProcessorInfo.Purpose Do
				MetadataObject = Common.MetadataObjectByFullName(AssignmentDetails);
				If MetadataObject = Undefined Then
					Continue;
				EndIf;
				RelatedObjectRef = Common.MetadataObjectID(MetadataObject);
				AssignmentRow1 = CatalogObject.Purpose.Find(RelatedObjectRef, "RelatedObject");
				If AssignmentRow1 = Undefined Then
					AssignmentRow1 = CatalogObject.Purpose.Add();
					AssignmentRow1.RelatedObject = RelatedObjectRef;
				EndIf;
			EndDo;
		EndIf;
		
		// ACC:1327-off - The mechanism of updating additional reports and data processors from metadata.
		// Competitive operations are not expected.
		InfobaseUpdate.WriteObject(CatalogObject, , True);
		// ACC:1327-on
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Miscellaneous.

// Sets the data processor publication kind used for conflicting additional reports and data processors.
Procedure DisableConflictingDataProcessor(DataProcessorObject)
	KindDebugMode = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode;
	AvailableKinds = AdditionalReportsAndDataProcessorsCached.AvaliablePublicationKinds();
	If AvailableKinds.Find(KindDebugMode) Then
		DataProcessorObject.Publication = KindDebugMode;
	Else
		DataProcessorObject.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled;
	EndIf;
EndProcedure

// For internal use.
Function RegisterDataProcessor(Val Object, Val RegistrationParameters) Export
	
	KindAdditionalDataProcessor = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor;
	KindAdditionalReport     = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport;
	KindOfReport                   = Enums.AdditionalReportsAndDataProcessorsKinds.Report;
	
	// Gets a data processor file from temporary storage, tries to create an external report object,
	// and gets information from the external data processor/report object.
	If RegistrationParameters.DisableConflicts Then
		For Each ListItem In RegistrationParameters.Conflicting Do
			BeginTransaction();
			Try
				Block = New DataLock;
				LockItem = Block.Add("Catalog.AdditionalReportsAndDataProcessors");
				LockItem.SetValue("Ref", ListItem.Value);
				Block.Lock();
				
				ConflictingObject = ListItem.Value.GetObject(); // CatalogObject.AdditionalReportsAndDataProcessors
				DisableConflictingDataProcessor(ConflictingObject);
				
				ConflictingObject.Write();
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
		EndDo;
	ElsIf RegistrationParameters.DisablePublication Then
		DisableConflictingDataProcessor(Object);
	EndIf;
	
	Result = New Structure;
	Result.Insert("ObjectName", "");
	Result.Insert("OldObjectName", "");
	Result.Insert("Success", False);
	Result.Insert("ObjectNameUsed", False);
	Result.Insert("Conflicting", New ValueList);
	Result.Insert("ErrorText", "");
	Result.Insert("BriefErrorDescription", "");
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptionsInternal = Common.CommonModule("ReportsOptionsInternal");
		Result.Insert("ReportOptionAssignment", ModuleReportsOptionsInternal.ReportOptionEmptyAssignment());
	EndIf;
	Result.ObjectNameUsed = False;
	Result.Success = False;
	If Object.IsNew() Then
		Result.OldObjectName = Object.ObjectName;
	Else
		Result.OldObjectName = Common.ObjectAttributeValue(Object.Ref, "ObjectName");
	EndIf;
	
	RegistrationData = GetRegistrationData(Object, RegistrationParameters, Result);
	If ValueIsFilled(Result.ErrorText) Then
		Return Result;
	EndIf;
	
	If RegistrationData.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm
		And Not Common.SubsystemExists("StandardSubsystems.Print") Then
		Result.ErrorText = NStr("en = 'Operations with print forms are unavailable.';");
		Return Result;
	EndIf;
	
	If Not RegistrationData.SafeMode And Not Users.IsFullUser(, True) Then
		Result.ErrorText = NStr("en = 'Cannot attach the data processor. Only users with the ""System administrator"" role can attach data processors that require disabling safe mode.';");
		Return Result;
	EndIf;
	
	IsExternalReport = RegistrationData.Kind = KindAdditionalReport Or RegistrationData.Kind = KindOfReport;
	If Not Object.IsNew() And RegistrationData.Kind <> Object.Kind Then
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Object kind mismatch. Imported object: %1. Current object: %2.
				|To import a new object, select Create.';"),
			String(RegistrationData.Kind),
			String(Object.Kind));
		Return Result;
	ElsIf RegistrationParameters.IsReport <> IsExternalReport Then
		Result.ErrorText = NStr("en = 'The data processor type specified in the data processor details does not match the actual extension.';");
		Return Result;
	EndIf;
	
	Object.Description    = RegistrationData.Description;
	Object.Version          = RegistrationData.Version;
	Object.PermissionsCompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_1_3;
	If ValueIsFilled(RegistrationData.SSLVersion) 
		And CommonClientServer.CompareVersions(RegistrationData.SSLVersion, "2.2.2.0") > 0 Then
		Object.PermissionsCompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_2_2;
	EndIf;
	Object.SafeMode = RegistrationData.SafeMode;
	Object.Information      = RegistrationData.Information;
	Object.FileName        = RegistrationParameters.FileName;
	Object.ObjectName      = Result.ObjectName;
	Object.UseOptionStorage = False;

	If IsExternalReport Then
		Store = Metadata.ReportsVariantsStorage; // MetadataObjectSettingsStorage
		Object.UseOptionStorage = (RegistrationData.VariantsStorage = "ReportsVariantsStorage"
			Or (Store <> Undefined And Store.Name = "ReportsVariantsStorage"));
		Object.DeepIntegrationWithReportForm = RegistrationData.DefineFormSettings;
		If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
			If ValueIsFilled(RegistrationData.ReportOptionAssignment) Then
				Result.ReportOptionAssignment = RegistrationData.ReportOptionAssignment;
			Else
				ModuleReportsOptionsInternal = Common.CommonModule("ReportsOptionsInternal");
				Result.ReportOptionAssignment = ModuleReportsOptionsInternal.AssigningDefaultReportOption();
			EndIf;
		EndIf;
	EndIf;
	
	// A different data processor is imported (an object name or a data processor type was changed).
	If Object.IsNew() Or Object.ObjectName <> Result.ObjectName Or Object.Kind <> RegistrationData.Kind Then
		Object.Purpose.Clear();
		Object.Sections.Clear();
		Object.Kind = RegistrationData.Kind;
	EndIf;
	
	// If the assignment is not specified, setting the value from the data processor.
	If Object.Purpose.Count() = 0
		And Object.Kind <> KindAdditionalReport
		And Object.Kind <> KindAdditionalDataProcessor Then
		
		If RegistrationData.Purpose.Count() > 0 Then
			MetadataObjectsTable = AttachedMetadataObjects(Object.Kind);
			
			For Each FullMetadataObjectName In RegistrationData.Purpose Do
				PointPosition = StrFind(FullMetadataObjectName, ".");
				If Mid(FullMetadataObjectName, PointPosition + 1) = "*" Then // For example, [Catalog.*].
					Search = New Structure("Kind", Left(FullMetadataObjectName, PointPosition - 1));
				Else
					Search = New Structure("FullName", FullMetadataObjectName);
				EndIf;
				FoundItems = MetadataObjectsTable.FindRows(Search);
				For Each TableRow In FoundItems Do
					AssignmentRow = Object.Purpose.Add();
					AssignmentRow.RelatedObject = TableRow.Ref;
				EndDo;
			EndDo;
		EndIf;
		
		Object.Purpose.GroupBy("RelatedObject", "");
		
	EndIf;
	
	Object.Commands.Clear();
	
	// Initialize commands.
	For Each DetailsCommand In RegistrationData.Commands Do
		
		If Not ValueIsFilled(DetailsCommand.StartupOption) Then
			Common.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Startup option is not specified for command %1.';"), DetailsCommand.Presentation));
		EndIf;
		Command = Object.Commands.Add();
		FillPropertyValues(Command, DetailsCommand);
		
	EndDo;
	
	// Reading permissions required by the additional data processor.
	Object.Permissions.Clear();
	For Each Resolution In RegistrationData.Permissions Do
		
		XDTOType = Resolution.Type();// XDTOObjectType
		
		TSRow = Object.Permissions.Add();
		TSRow.PermissionKind = XDTOType.Name;
		
		Parameters = New Structure();
		
		For Each XDTOProperty In XDTOType.Properties Do
			
			Container = Resolution.GetXDTO(XDTOProperty.Name);
			
			If Container <> Undefined Then
				Parameters.Insert(XDTOProperty.Name, Container.Value);
			Else
				Parameters.Insert(XDTOProperty.Name);
			EndIf;
			
		EndDo;
		
		TSRow.Parameters = New ValueStorage(Parameters);
		
	EndDo;
	
	Object.EmployeeResponsible = Users.CurrentUser();
	Result.Success = True;
	Return Result;
	
EndFunction

// Parameters:
//   Object - CatalogRef.AdditionalReportsAndDataProcessors
//   ObjectName - String
// Returns:
//   ValueTable:
//   * Ref - CatalogRef.AdditionalReportsAndDataProcessors
//   * Kind - EnumRef.AdditionalReportsAndDataProcessorsKinds
//   * ObjectName - String
//   * Presentation - String
//
Function AllConflictingReportsAndDataProcessors(References, DataProcessorsNames)
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT
	|	CatalogTable.Ref AS Ref,
	|	CatalogTable.Kind AS Kind,
	|	CatalogTable.ObjectName AS ObjectName,
	|	CatalogTable.Presentation AS Presentation
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS CatalogTable
	|WHERE
	|	CatalogTable.ObjectName IN(&ObjectName)
	|	AND CatalogTable.Publication = VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used)
	|	AND CatalogTable.DeletionMark = FALSE
	|	AND NOT CatalogTable.Ref IN(&Ref)";
	
	AdditionalReportsAndDataProcessorsKinds = New Array;
	AdditionalReportsAndDataProcessorsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
	AdditionalReportsAndDataProcessorsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	
	Query = New Query;
	Query.SetParameter("ObjectName", DataProcessorsNames);
	Query.SetParameter("AdditionalReportsAndDataProcessorsKinds", AdditionalReportsAndDataProcessorsKinds);
	Query.SetParameter("Ref", References);
	
	Query.Text = QueryText;
	
	Conflicting = Query.Execute().Unload();
	Return Conflicting;
EndFunction

// For internal use.
//
// Returns:
//   See ExternalDataProcessorInfo 
//
Function GetRegistrationData(Val Object, Val RegistrationParameters, Val RegistrationResult)

	RegistrationData = ExternalDataProcessorInfo();
	StandardProcessing = True;
	
	SSLSubsystemsIntegration.OnGetRegistrationData(Object, RegistrationData, StandardProcessing);
	If StandardProcessing Then
		OnGetRegistrationData(Object, RegistrationData, RegistrationParameters, RegistrationResult);
	EndIf;
	
	Return RegistrationData;
EndFunction

// For internal use.
// 
// Parameters:
//   Object - CatalogObject.AdditionalReportsAndDataProcessors
//          - Undefined
//   RegistrationData - See ExternalDataProcessorInfo 
//
Procedure OnGetRegistrationData(Object, RegistrationData, RegistrationParameters, RegistrationResult)
	
	// Attaching and getting the name to be used when attaching the object.
	Manager = ?(RegistrationParameters.IsReport, ExternalReports, ExternalDataProcessors);
	
	ErrorInfo = Undefined;
	Try
#If ThickClientOrdinaryApplication Then
		RegistrationResult.ObjectName = GetTempFileName();
		BinaryData = GetFromTempStorage(RegistrationParameters.DataProcessorDataAddress);
		BinaryData.Write(RegistrationResult.ObjectName);
#Else
		RegistrationResult.ObjectName =
			TrimAll(Manager.Connect(RegistrationParameters.DataProcessorDataAddress, , True,
				Common.ProtectionWithoutWarningsDetails()));
#EndIf
		
		// Getting information about an external data processor.
		ExternalObject = Manager.Create(RegistrationResult.ObjectName);
		ExternalObjectMetadata = ExternalObject.Metadata(); // MetadataObjectReport
		
		ExternalDataProcessorInfo = ExternalObject.ExternalDataProcessorInfo();
		CommonClientServer.SupplementStructure(RegistrationData, ExternalDataProcessorInfo, True);
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
#If ThickClientOrdinaryApplication Then
	Try
		DeleteFiles(RegistrationResult.ObjectName);
	Except
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot delete the ""%1"" temporary file due to:
			|%2';"),
			RegistrationResult.ObjectName,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		WriteWarning(Object.Ref, WarningText);
	EndTry;
#EndIf
	If ErrorInfo <> Undefined Then
		If RegistrationParameters.IsReport Then
			ErrorText = NStr("en = 'Cannot attach an additional report from a file.
			|It might not be compatible with this application version.';");
		Else
			ErrorText = NStr("en = 'Cannot attach an additional data processor from a file.
			|It might not be compatible with this application version.';");
		EndIf;
		ErrorText = ErrorText + Chars.LF + Chars.LF + NStr("en = 'Technical information:';") + Chars.LF;
		RegistrationResult.BriefErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo);
		RegistrationResult.ErrorText = ErrorText + RegistrationResult.BriefErrorDescription;
		WriteError(Object.Ref, ErrorText + ErrorProcessing.DetailErrorDescription(ErrorInfo));
		Return;
	ElsIf RegistrationParameters.IsReport
		And Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		WarningText = "";
		
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		OptionsStorageCorrect = ModuleReportsOptions.AdditionalReportOptionsStorageCorrect(
			ExternalObjectMetadata, WarningText);
		
		If Not OptionsStorageCorrect Then 
			WriteWarning(Object.Ref, WarningText);
		EndIf;
	EndIf;
	
	If RegistrationData.Description = Undefined Or RegistrationData.Information = Undefined Then
		If RegistrationData.Description = Undefined Then
			RegistrationData.Description = ExternalObjectMetadata.Presentation();
		EndIf;
		If RegistrationData.Information = Undefined Then
			RegistrationData.Information = ExternalObjectMetadata.Comment;
		EndIf;
	EndIf;
	
	If TypeOf(RegistrationData.Kind) <> Type("EnumRef.AdditionalReportsAndDataProcessorsKinds") Then
		RegistrationData.Kind = Enums.AdditionalReportsAndDataProcessorsKinds[RegistrationData.Kind];
	EndIf;
	
	RegistrationData.Insert("VariantsStorage");
	If RegistrationData.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport
		Or RegistrationData.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report Then
		If ExternalObjectMetadata.VariantsStorage <> Undefined Then
			RegistrationData.VariantsStorage = ExternalObjectMetadata.VariantsStorage.Name;
		EndIf;
	EndIf;
	
	RegistrationData.Commands.Columns.Add("StartupOption");
	
	For Each DetailsCommand In RegistrationData.Commands Do
		DetailsCommand.StartupOption = Enums.AdditionalDataProcessorsCallMethods[DetailsCommand.Use];
	EndDo;
	
#If ThickClientOrdinaryApplication Then
		RegistrationResult.ObjectName = ExternalObjectMetadata.Name;
#EndIf
EndProcedure

// Displays filling commands in object forms.
Procedure OnDetermineFillingCommandsAttachedToObject(Commands, ObjectsIDs, CommandsSources)
	
	Table = ReportsAndDataProcessorsTable(ObjectsIDs);
	FillingForm = Enums.AdditionalDataProcessorsCallMethods.FillingForm;
	
	For Each ReportOrDataProcessor In Table Do
		If Not IsSuppliedDataProcessor(ReportOrDataProcessor.Ref) Then
			Continue;
		EndIf;
		
		ObjectFillingTypes = New Array;
		For Each AssignmentTableRow In ReportOrDataProcessor.Purpose Do
			Source = CommandsSources[AssignmentTableRow.RelatedObject];
			If Source = Undefined Then
				Continue;
			EndIf;
			AttachableCommands.SupplyTypesArray(ObjectFillingTypes, Source.DataRefType);
		EndDo;
		
		For Each TableRow In ReportOrDataProcessor.Commands Do
			If TableRow.Hide Then
				Continue;
			EndIf;
			Command = Commands.Add();
			Command.Kind            = "ObjectsFilling";
			Command.Presentation  = TableRow.Presentation;
			Command.Importance       = "SeeAlso";
			Command.Order        = 50;
			Command.ChangesSelectedObjects = True;
			If TableRow.StartupOption = FillingForm Then
				Command.Handler  = "AdditionalReportsAndDataProcessors.HandlerFillingCommands";
				Command.WriteMode = "NotWrite";
			Else
				Command.Handler  = "AdditionalReportsAndDataProcessorsClient.HandlerFillingCommands";
				Command.WriteMode = "Write";
			EndIf;
			Command.ParameterType = New TypeDescription(ObjectFillingTypes);
			Command.AdditionalParameters = AdditionalFillingCommandParameters();
			FillPropertyValues(Command.AdditionalParameters, TableRow);
			Command.AdditionalParameters.Ref = ReportOrDataProcessor.Ref;
			Command.AdditionalParameters.IsReport = False;
		EndDo;
	EndDo;
EndProcedure

// Returns:
//   Structure:
//   * Kind      - String - A data processor type that can be obtained from the
//                        AdditionalReportsAndDataProcessorsClientServer.DataProcessorKind<…> function.
//   * IsReport - Boolean
//
Function AdditionalCommandParameters(Kind, IsReport) Export
	Result = New Structure();
	Result.Insert("Kind", Kind);
	Result.Insert("IsReport", IsReport);
	Return Result;
EndFunction

// Returns:
//  Structure:
//   * Ref - CatalogRef.AdditionalReportsAndDataProcessors
//   * Kind - String
//   * StartupOption - String
//   * Id - String
//   * ShouldShowUserNotification - String
//   * Presentation - String
//   * IsReport - Boolean
//
Function AdditionalFillingCommandParameters() Export
	HandlerParametersKeys = "Ref, Id, StartupOption, Presentation, ShouldShowUserNotification, IsReport";
	Return New Structure(HandlerParametersKeys);
EndFunction

// Parameters:
//   ObjectsIDs - Array
//
// Returns:
//   ValueTable:
//   * Ref - CatalogRef.AdditionalReportsAndDataProcessors
//   * Commands - ValueTable:
//   ** Id - String
//   ** StartupOption - EnumRef.AdditionalDataProcessorsCallMethods
//   ** Presentation - String
//   ** ShouldShowUserNotification - Boolean
//   ** Hide - Boolean
//   * Purpose - ValueTable:
//   ** RelatedObject - CatalogRef.MetadataObjectIDs
//
Function ReportsAndDataProcessorsTable(Val ObjectsIDs)
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Table.Ref,
	|	Table.Commands.(
	|		Id,
	|		StartupOption,
	|		Presentation,
	|		ShouldShowUserNotification,
	|		Hide
	|	),
	|	Table.Purpose.(
	|		RelatedObject
	|	)
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS Table
	|WHERE
	|	Table.Purpose.RelatedObject IN(&MOIDs)
	|	AND Table.Kind = &Kind
	|	AND Table.UseForObjectForm = TRUE
	|	AND Table.Publication = VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used)
	|	AND Table.Publication <> VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled)
	|	AND Table.DeletionMark = FALSE";
	Query.SetParameter("MOIDs", ObjectsIDs);
	Query.SetParameter("Kind", Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling);
	If AccessRight("Update", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Query.Text = StrReplace(Query.Text, "AND Table.Publication = VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used)", "");
	Else
		Query.Text = StrReplace(Query.Text, "AND Table.Publication <> VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled)", "");
	EndIf;
	Table = Query.Execute().Unload();
	Return Table
EndFunction

// Converts a string presentation of a version to a number presentation.
//
Function VersionAsNumber(VersionAsString)
	If IsBlankString(VersionAsString) Or VersionAsString = "0.0.0.0" Then
		Return 0;
	EndIf;
	
	Digit = 0;
	
	Result = 0;
	
	TypeDescriptionNumber = New TypeDescription("Number");
	Balance = VersionAsString;
	PointPosition = StrFind(Balance, ".");
	While PointPosition > 0 Do
		NumberAsString = Left(Balance, PointPosition - 1);
		Number = TypeDescriptionNumber.AdjustValue(NumberAsString);
		Result = Result * 1000 + Number;
		Balance = Mid(Balance, PointPosition + 1);
		PointPosition = StrFind(Balance, ".");
		Digit = Digit + 1;
	EndDo;
	
	Number = TypeDescriptionNumber.AdjustValue(Balance);
	Result = Result * 1000 + Number;
	Digit = Digit + 1;
	
	// The comma-delimited version numbers that follow the 4th dot.
	// For example, if you pass "1.2.3.4.5.6.7", it returns "1002003004,005006007".
	If Digit > 4 Then
		Result = Result / Pow(1000, Digit - 4);
	EndIf;
	
	Return Result;
EndFunction

#EndRegion
