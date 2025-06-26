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

// Shows attached commands in the form.
// The procedure is called from the OnCreateAtServer form handler.
//
// If the form contains several lists, place several calls of this procedure in the OnCreateAtServer form handler
// specifying the PlacementParameters parameter.
// The PlacementParameters parameter is also used when source types depend on the form opening parameters.
//
// Parameters:
//   Form - ClientApplicationForm - a form, where the commands are to be placed.
//   PlacementParameters - See AttachableCommands.PlacementParameters
//                       - Undefined
//
Procedure OnCreateAtServer(Form, Val PlacementParameters = Undefined) Export
	FormName = Form.FormName;
	
	PassedPlacementParameters = PlacementParameters;
	
	PlacementParameters = PlacementParameters();
	If PassedPlacementParameters <> Undefined Then
		FillPropertyValues(PlacementParameters, PassedPlacementParameters);
	EndIf;
	
	SourcesCommaSeparated = "";
	
	If TypeOf(PlacementParameters.Sources) = Type("TypeDescription") Then
		Types = PlacementParameters.Sources.Types();
		For Each Type In Types Do
			MetadataObject = Metadata.FindByType(Type);
			If MetadataObject <> Undefined Then
				SourcesCommaSeparated = SourcesCommaSeparated + ?(SourcesCommaSeparated = "", "", ",") + MetadataObject.FullName();
			EndIf;
		EndDo;
	ElsIf TypeOf(PlacementParameters.Sources) = Type("Array") Then
		For Each MetadataObject In PlacementParameters.Sources Do
			If TypeOf(MetadataObject) = Type("MetadataObject") Then
				SourcesCommaSeparated = SourcesCommaSeparated + ?(SourcesCommaSeparated = "", "", ",") + MetadataObject.FullName();
			ElsIf MetadataObject <> Undefined Then
				CommonClientServer.CheckParameter(
					"AttachableCommands.OnCreateAtServer",
					"PlacementParameters.Sources[...]",
					MetadataObject,
					New TypeDescription("MetadataObject"));
			EndIf;
		EndDo;
	ElsIf PlacementParameters.Sources <> Undefined Then
		CommonClientServer.CheckParameter(
			"AttachableCommands.OnCreateAtServer",
			"PlacementParameters.Sources",
			PlacementParameters.Sources,
			New TypeDescription("TypeDescription, Array"));
	EndIf;
	
	IsObjectForm = Undefined;
	Parameters = Form.Parameters;
	HasListParameters  = Parameters.Property("Filter") And Parameters.Property("CurrentRow");
	HasObjectParameters = Parameters.Property("Key")  And Parameters.Property("Basis");
	If HasListParameters <> HasObjectParameters Then
		IsObjectForm = HasObjectParameters;
	EndIf;
	
	If IsObjectForm = Undefined Then
		FormAttributes = Form.GetAttributes();
		If FormAttributes.Count() > 0 And FormAttributes[0].ValueType = New TypeDescription("DynamicList") Then
			IsObjectForm = False;
		EndIf;
	EndIf;
	
	// Cannot get metadata from external reports and data processors by form name only.
	// Therefore, define the command sources prior to calling "Cached".
	If SourcesCommaSeparated = "" And SpecifyCommandsSources(FormName) Then
		If HasObjectParameters Then
			MetadataObject = Metadata.FindByType(TypeOf(Parameters.Key));
			If MetadataObject <> Undefined Then
				SourcesCommaSeparated = MetadataObject.FullName();
			EndIf;
		EndIf;
		If SourcesCommaSeparated = "" Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'To call the %1 procedure in report forms,
					|common forms, and data processors,
					|you must explicitly specify parameter %2.';"),
				"AttachableCommands.OnCreateAtServer",
				"PlacementParameters.Sources");
		EndIf;
	EndIf;
	
	FormCache = AttachableCommandsCached.FormCache(FormName, SourcesCommaSeparated, IsObjectForm);
	PlacementParameters.Insert("HasVisibilityConditions", FormCache.HasVisibilityConditions);
	PlacementParameters.Insert("IsObjectForm", FormCache.IsObjectForm);
	PlacementParameters.Insert("InputOnBasisUsingAttachableCommands", FormCache.InputOnBasisUsingAttachableCommands);
	
	If FormCache.FunctionalOptions.Count() > 0 Then
		Form.SetFormFunctionalOptionParameters(FormCache.FunctionalOptions);
	EndIf;
	
	Commands = FormCache.Commands.Copy();
	OutputCommands(Form, Commands, PlacementParameters);
	
EndProcedure

// Constructor of the matching parameter of the AttachableCommands.OnCreateAtServer procedure.
//
// Returns:
//   Structure - Parameter for placing attachable commands:
//       * Sources - TypeDescription
//                   - Array of MetadataObject - Command sources.
//           Used for secondary lists and in object forms that don't provide commands (data processors, common forms).
//           
//       * CommandBar - FormGroup - a command bar or a group of commands that displays a submenu.
//           It is used as a parent to create submenu if it is missing.
//           If it is not specified, the AttachableCommands group is searched first.
//       * GroupsPrefix - String - an addition to submenu and command bar names.
//           It is used if you need to add prefixes to groups with commands (in particular, when the form has several tables).
//           For the prefix use the form table name, for which commands are output.
//           For example, if GroupsPrefix = WarehouseDocuments (secondary form table name),
//           submenus named WarehouseDocumentsSubmenuPrint, WarehouseDocuments SubmenuReports, and so on are used.
//       * CommandsOwner - FormDataStructure, FormTable - Object or form element to add commands to.
//
Function PlacementParameters() Export
	
	Result = New Structure;
	Result.Insert("Sources");
	Result.Insert("CommandBar");
	Result.Insert("GroupsPrefix", "");
	Result.Insert("CommandsOwner");
	
	Return Result;
	
EndFunction

// A handler of the form command that requires a context server call.
//
// Parameters:
//   Form - ClientApplicationForm - a form, from which the command is executed.
//   CallParameters - Structure
//   Source - FormTable
//            - FormDataStructure - an object or a form list with the Reference field.
//   Result - Structure - a command execution result.
//
Procedure ExecuteCommand(Val Form, Val CallParameters, Val Source = Undefined, Result = Undefined) Export
	
	If TypeOf(CallParameters) <> Type("Structure")
		Or CallParameters.Count() <> 3
		Or TypeOf(Form) <> Type("ClientApplicationForm") Then
		Return;
	EndIf;
	
	If Source = Undefined Then
		Source = AttachableCommandsClientServer.CommandOwnerByCommandName(CallParameters.CommandNameInForm, Form);
	EndIf;
	
	SettingsAddress = Form.AttachableCommandsParameters.CommandsTableAddress;
	CommandDetails = CommandDetails(CallParameters.CommandNameInForm, SettingsAddress);
	
	ExecutionParameters = CommandExecuteParameters();
	ExecutionParameters.CommandDetails = New Structure(CommandDetails);
	ExecutionParameters.Form = Form;
	ExecutionParameters.IsObjectForm = TypeOf(Source) = Type("FormDataStructure");
	ExecutionParameters.Source = Source;
	
	ExportProcedureParameters = New Array;
	ExportProcedureParameters.Add(CallParameters.CommandParameter);
	ExportProcedureParameters.Add(ExecutionParameters);
	
	Handler = CommandDetails.Handler;
	CommonModulePrefix = Lower("CommonModule.");
	If StrStartsWith(Lower(Handler), CommonModulePrefix) Then
		Handler = Mid(Handler, StrLen(CommonModulePrefix) + 1);
	EndIf;
	
	Common.ExecuteConfigurationMethod(Handler, ExportProcedureParameters);
	
	Result = ExecutionParameters.Result;
	CallParameters.Result = ExecutionParameters.Result;
	
EndProcedure

// Sets the visibility conditions of the command on the form, depending on the context.
//
// Parameters:
//   Command      - ValueTableRow of See PrintManagement.CreatePrintCommandsCollection
//   Attribute     - String                - an object attribute name.
//   Value     - Arbitrary          - an object attribute value. The parameter is required for all kinds of
//                                          comparisons except for Filled and NotFilled.
//   Var_ComparisonType - DataCompositionComparisonType - a value comparison type.
//       You can use the following types of comparison:
//         DataCompositionComparisonType.Equal,
//         DataCompositionComparisonType.NotEqual,
//         DataCompositionComparisonType.Filled,
//         DataCompositionComparisonType.NotFilled,
//         DataCompositionComparisonType.InList,
//         DataCompositionComparisonType.NotInList,
//         DataCompositionComparisonType.Greater,
//         DataCompositionComparisonType.Less,
//         DataCompositionComparisonType.GreaterOrEqual,
//         DataCompositionComparisonType.LessOrEqual.
//       The default value is DataCompositionComparisonType.Equal.
//
Procedure AddCommandVisibilityCondition(Command, Attribute, Value = Undefined, Val Var_ComparisonType = Undefined) Export
	If Var_ComparisonType = Undefined Then
		Var_ComparisonType = DataCompositionComparisonType.Equal;
	EndIf;
	VisibilityCondition = New Structure;
	VisibilityCondition.Insert("Attribute", Attribute);
	VisibilityCondition.Insert("ComparisonType", Var_ComparisonType);
	VisibilityCondition.Insert("Value", Value);
	Command.VisibilityConditions.Add(VisibilityCondition);
EndProcedure

// Properties of the second handler parameter of the attachable command executed on the server.
//
// Returns:
//  Structure:
//   * CommandDetails - Structure - properties match the value table columns of the Commands parameter
///of the AttachableCommandsOverridable.OnDefineCommandsAttachedToObject procedure.
//                                   Key properties:
//      ** Id  - String - Command ID.
//      ** Presentation  - String - Command presentation in a form.
//      ** Name            - String - a command name on a form.
//      ** AdditionalParameters - Structure - additional properties defined by 
//                                   the kind of a specific command.
//   * Form - ClientApplicationForm - a form the command is called from.
//   * IsObjectForm - Boolean - True if the command is called from the object form.
//   * Source - FormTable
//              - FormDataStructure - an object or a form list with the Reference field.
//
Function CommandExecuteParameters() Export
	ExecutionParameters = AttachableCommandsClientServer.CommandExecuteParameters();
	// Service parameters.
	Result = New Structure;
	Result.Insert("Text",    "");
	Result.Insert("More", "");
	ExecutionParameters.Insert("Result", Result);
	Return ExecutionParameters;
EndFunction

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Event handlers.

// Generates a table of common settings for all extensions attached to the metadata object.
Function AttachedObjects(SourceDetails, AttachedObjects = Undefined, InterfaceSettings4 = Undefined) Export
	Sources = CommandsSourcesTree();
	If TypeOf(SourceDetails) = Type("CatalogRef.MetadataObjectIDs") Then
		Source = Sources.Rows.Add();
		Source.MetadataRef = SourceDetails;
		Source.DataRefType = Common.ObjectAttributeValue(SourceDetails, "EmptyRefValue");
	Else
		Source = SourceDetails;
	EndIf;
	
	If AttachedObjects = Undefined Then
		AttachedObjects = AttachableObjectsTable(InterfaceSettings4);
	EndIf;
	If Source.MetadataRef = Undefined Then
		Return AttachedObjects;
	EndIf;
	
	AttachedObjectsFullNames = AttachableCommandsCached.Parameters().AttachedObjects[Source.MetadataRef];
	If AttachedObjectsFullNames = Undefined Then
		Return AttachedObjects;
	EndIf;
	
	For Each FullName In AttachedObjectsFullNames Do
		AttachedObject = AttachedObjects.Find(FullName, "FullName");
		If AttachedObject = Undefined Then
			AttachableObjectSettings = AttachableObjectSettings(FullName, InterfaceSettings4);
			If AttachableObjectSettings = Undefined Then
				Continue;
			EndIf;
			AttachedObject = AttachedObjects.Add();
			FillPropertyValues(AttachedObject, AttachableObjectSettings);
			AttachedObject.DataRefType = Source.DataRefType;
			AttachedObject.Metadata = Common.MetadataObjectByFullName(FullName);
		Else
			AttachedObject.DataRefType = MergeTypes(AttachedObject.DataRefType, Source.DataRefType);
		EndIf;
	EndDo;
	
	Return AttachedObjects;
EndFunction

// Gets integration settings of a metadata object that provides commands (a report or a data processor).
//
// Parameters:
//   FullName - String - Full name of a metadata object.
//   InterfaceSettings4 - See AttachableCommands.AttachableObjectsInterfaceSettings.
//
// Returns:
//  Structure - Object integration settings:
//   * Location - Array of MetadataObject - objects to which an object is attached.
//   * AddPrintCommands     - Boolean - the AddPrintCommands function is defined in the object manager module. 
//   * AddFillCommands - Boolean - the AddFillCommands function is defined in the object manager module. 
//   * AddReportCommands    - Boolean - the AddReportCommands function is defined in the object manager module. 
//   * CustomizeReportOptions   - Boolean - the CustomizeReportOptions function is defined in the object manager module. 
//   * DefineFormSettings  - Boolean - the DefineFormSettings function is defined in the object manager module. 
//   * Kind - String - metadata object kind and name in uppercase.
//   * FullName - String - Full name of a metadata object.
//   * Manager - DataProcessorManager
//              - ReportManager - a metadata object manager.
//  Undefined - if failed to receive the settings.
//
Function AttachableObjectSettings(FullName, InterfaceSettings4 = Undefined) Export
	NameParts = StrSplit(FullName, ".");
	If NameParts.Count() <> 2 Then
		Return Undefined;
	EndIf;
	KindInCase = Upper(NameParts[0]);
	Name = NameParts[1];
	If KindInCase = "REPORT" Then
		Node = Reports;
	ElsIf KindInCase = "DATAPROCESSOR" Then
		Node = DataProcessors;
	Else
		Return Undefined;
	EndIf;
	
	If InterfaceSettings4 = Undefined Then
		InterfaceSettings4 = AttachableObjectsInterfaceSettings();
	EndIf;
	
	Settings = New Structure;
	For Each Setting In InterfaceSettings4 Do
		If Setting.AttachableObjectsKinds = ""
			Or StrFind(Upper(Setting.AttachableObjectsKinds), KindInCase) > 0 Then
			Settings.Insert(Setting.Key, Setting.TypeDescription.AdjustValue());
		EndIf;
	EndDo;
	
	Manager = Node[Name];
	Try
		Manager.OnDefineSettings(Settings);
	Except
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot read %1 object settings from the manager module:';"), FullName);
		ErrorText = ErrorText + Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteError1 = False;
		MetadataObject = Metadata.FindByType(TypeOf(Manager));
		
		If MetadataObject <> Undefined And Metadata.Subsystems.AttachableReportsAndDataProcessors.Content.Contains(MetadataObject) Then
			WriteError1 = True;
		EndIf;
	
		If WriteError1 Then
			WriteLogEvent(
				NStr("en = 'Attachable commands';", Common.DefaultLanguageCode()),
				EventLogLevel.Error,
				Common.MetadataObjectByFullName(FullName),
				FullName,
				ErrorText);
		EndIf;
			
		Return Undefined;
	EndTry;
	
	Settings.Insert("Kind",       KindInCase);
	Settings.Insert("FullName", FullName);
	Settings.Insert("Manager",  Manager);
	Return Settings;
EndFunction

// Adds types to array.
//
// Parameters:
//   Array - Array - a type array.
//   TypeOrTypeDetails - Type
//                       - TypeDescription - types being added.
//
Procedure SupplyTypesArray(Array, TypeOrTypeDetails) Export
	If TypeOf(TypeOrTypeDetails) = Type("TypeDescription") Then
		CommonClientServer.SupplementArray(Array, TypeOrTypeDetails.Types(), True);
	ElsIf TypeOf(TypeOrTypeDetails) = Type("Type") And Array.Find(TypeOrTypeDetails) = Undefined Then
		Array.Add(TypeOrTypeDetails);
	EndIf;
EndProcedure

// Registers a metadata object in the tree of command sources, as well as secondary metadata objects
//   attached to the specified metadata object.
//
// Parameters:
//   MetadataObject - MetadataObject - a metadata object to which command sources are attached.
//   Sources - See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject.Sources.
//   AttachedObjects - See AttachableCommands.AttachableObjectsTable
//   InterfaceSettings4 - See AttachableCommands.AttachableObjectsInterfaceSettings
//
// Returns:
//   ValueTreeRow - metadata object settings. See details of parameter 2
//       of the AttachableCommandsOverridable.OnDefineCommandsAttachedToObject() procedure.
//
Function RegisterSource(MetadataObject, Sources, AttachedObjects, InterfaceSettings4) Export
	If MetadataObject = Undefined Then
		Return Undefined;
	EndIf;
	FullName = MetadataObject.FullName();
	Manager  = Common.ObjectManagerByFullName(FullName);
	If Manager = Undefined Then
		Return Undefined; // The object cannot be a source of commands.
	EndIf;
	
	Source = Sources.Rows.Add();
	Source.Metadata          = MetadataObject;
	Source.FullName           = FullName;
	Source.Manager            = Manager;
	Source.MetadataRef    = Common.MetadataObjectID(FullName);
	Source.Kind                 = Upper(StrSplit(FullName, ".")[0]);
	Source.IsDocumentJournal = (Source.Kind = "DOCUMENTJOURNAL");
	
	If Source.IsDocumentJournal Then
		TypesArray = New Array;
		For Each MetadataOfDocument In MetadataObject.RegisteredDocuments Do
			Document = RegisterSource(MetadataOfDocument, Source, AttachedObjects, InterfaceSettings4);
			If Document <> Undefined Then
				TypesArray.Add(Document.DataRefType);
			EndIf;
		EndDo;
		Source.DataRefType = New TypeDescription(TypesArray);
	ElsIf Not Metadata.DataProcessors.Contains(MetadataObject) And Not Metadata.Reports.Contains(MetadataObject)
		 And Not Metadata.InformationRegisters.Contains(MetadataObject) Then
		Source.DataRefType = Type(Source.Kind + "Ref." + MetadataObject.Name);
	EndIf;
	
	AttachedObjects(Source, AttachedObjects, InterfaceSettings4);
	
	Return Source;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Templates.

// The information template of metadata objects that are command sources.
//
// Returns:
//   See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject.Sources.
//
Function CommandsSourcesTree() Export
	Result = New ValueTree;
	Result.Columns.Add("Metadata");
	Result.Columns.Add("FullName", New TypeDescription("String"));
	Result.Columns.Add("Manager");
	Result.Columns.Add("MetadataRef");
	Result.Columns.Add("DataRefType");
	Result.Columns.Add("Kind", New TypeDescription("String"));
	Result.Columns.Add("IsDocumentJournal", New TypeDescription("Boolean"));
	Return Result;
EndFunction

// Information template of reports and data processors attached to command sources.
//
// Returns:
//   ValueTable - Secondary parameters:
//       * FullName  - String           - a full object name. For example: "Document.DocumentName".
//       * Manager   - Arbitrary     - an object manager module.
//       * Location - Array           - a list of objects, to which a report or data processor is attached.
//       * DataRefType - Type
//                         - TypeDescription - a type of objects, to which a report or a data processor is attached..
//
Function AttachableObjectsTable(InterfaceSettings4 = Undefined) Export
	If InterfaceSettings4 = Undefined Then
		InterfaceSettings4 = AttachableObjectsInterfaceSettings();
	EndIf;
	Table = New ValueTable;
	Table.Columns.Add("FullName", New TypeDescription("String"));
	Table.Columns.Add("Manager");
	Table.Columns.Add("Metadata");
	Table.Columns.Add("DataRefType");
	
	For Each Setting In InterfaceSettings4 Do
		Try
			Table.Columns.Add(Setting.Key, Setting.TypeDescription);
		Except
			ErrorText = NStr("en = 'Cannot register a setting for attachable objects application interface.
				|Key: %1. Type description: %2. Error description: %3.';");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				ErrorText,
				Setting.Key,
				String(Setting.TypeDescription),
				ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			Raise(ErrorText, ErrorCategory.ConfigurationError);
		EndTry;
	EndDo;
	
	Table.Indexes.Add("FullName");
	
	Return Table;
EndFunction

// Information template of reports and data processors attached to command sources.
//
// Returns:
//   ValueTable - Describes the "Settings" parameter of the "OnDefineSettings" procedure
//       for the objects included into the subsystem "AttachableReportsAndDataProcessors".:
//       * Key             - String        - a setting name.
//       * TypeDescription    - TypeDescription - setting type.
//       * AttachableObjectsKinds - String - a metadata object kind in uppercase.
//                                            For example: REPORT or DATA PROCESSOR.
//
Function AttachableObjectsInterfaceSettings() Export
	Table = New ValueTable;
	Table.Columns.Add("Key", New TypeDescription("String"));
	Table.Columns.Add("TypeDescription", New TypeDescription("TypeDescription"));
	Table.Columns.Add("AttachableObjectsKinds", New TypeDescription("String"));
	
	Setting = Table.Add();
	Setting.Key          = "Location";
	Setting.TypeDescription = New TypeDescription("Array");
	Setting.AttachableObjectsKinds = "Report, DataProcessor";
	
	ObjectsFilling.OnDefineAttachableObjectsSettingsComposition(Table);
	GenerateFrom.OnDefineAttachableObjectsSettingsComposition(Table);
	SSLSubsystemsIntegration.OnDefineAttachableObjectsSettingsComposition(Table);
	AttachableCommandsOverridable.OnDefineAttachableObjectsSettingsComposition(Table);
	
	Return Table;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	Handler = Handlers.Add();
	Handler.ExecuteInMandatoryGroup = False;
	Handler.SharedData                  = True;
	Handler.HandlerManagement      = False;
	Handler.ExecutionMode              = "Seamless";
	Handler.Version    = "*";
	Handler.Procedure = "AttachableCommands.ConfigurationCommonDataNonexclusiveUpdate";
	Handler.Priority = 90;
EndProcedure

// Update handler for caches associated with extensions.
Function OnFillAllExtensionParameters() Export
	Return CommonDataNonexclusiveUpdate(Type("CatalogRef.ExtensionObjectIDs"));
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

Function ConfigurationCommonDataNonexclusiveUpdate() Export
	Return CommonDataNonexclusiveUpdate(Type("CatalogRef.MetadataObjectIDs"));
EndFunction

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// OnCreateAtServer form cache.

// Cache of the form, where attachable commands will be displayed.
Function FormCache(FormName, SourcesCommaSeparated, IsObjectForm) Export
	Commands = CommandsTable();
	Sources = CommandsSourcesTree();
	InterfaceSettings4 = AttachableObjectsInterfaceSettings();
	AttachedObjects = AttachableObjectsTable(InterfaceSettings4);
	
	FormCache = New Structure;
	FormCache.Insert("Commands", Commands);
	FormCache.Insert("HasVisibilityConditions", False);
	FormCache.Insert("FunctionalOptions", New Structure);
	
	FormMetadata = Metadata.FindByFullName(FormName);
	ParentMetadata = ?(FormMetadata = Undefined, Undefined, FormMetadata.Parent());
	KindInCase = Upper(StrSplit(FormName, ".")[0]);
	SourcesTypes = New Array;
	If SourcesCommaSeparated = "" Then
		Source = RegisterSource(ParentMetadata, Sources, AttachedObjects, InterfaceSettings4);
		SupplyTypesArray(SourcesTypes, Source.DataRefType);
	Else
		SourcesFullNames = StringFunctionsClientServer.SplitStringIntoSubstringsArray(SourcesCommaSeparated, ",", True, True);
		For Each FullName In SourcesFullNames Do
			MetadataObject = Common.MetadataObjectByFullName(FullName);
			Source = RegisterSource(MetadataObject, Sources, AttachedObjects, InterfaceSettings4);
			SupplyTypesArray(SourcesTypes, Source.DataRefType);
		EndDo;
	EndIf;
	
	If IsObjectForm = True And SourcesTypes.Count() = 1 And ParentMetadata <> Metadata.FindByType(SourcesTypes[0]) Then
		IsObjectForm = False; // Object form has a list of another object type.
	EndIf;
	
	If IsObjectForm = Undefined Then
		If SourcesTypes.Count() > 1 Then
			IsObjectForm = False;
		ElsIf ParentMetadata <> Undefined Then
			Collection = New Structure("DefaultListForm, DefaultObjectForm");
			FillPropertyValues(Collection, ParentMetadata);
			If FormMetadata = Collection.DefaultListForm Then
				IsObjectForm = False;
			ElsIf FormMetadata = Collection.DefaultObjectForm And ParentMetadata <> Metadata.FindByType(SourcesTypes[0]) Then
				IsObjectForm = True;
			Else
				If KindInCase = Upper("DocumentJournal") Then
					IsObjectForm = False;
				ElsIf KindInCase = Upper("DataProcessor") Then
					IsObjectForm = False;
				Else
					IsObjectForm = True;
				EndIf;
			EndIf;
		Else
			IsObjectForm = False;
		EndIf;
	EndIf;
	FormCache.Insert("IsObjectForm", IsObjectForm);
	
	Context = New Structure;
	Context.Insert("KindInCase", KindInCase);
	Context.Insert("FormName", FormName);
	Context.Insert("FormMetadata", FormMetadata);
	Context.Insert("SourcesTypes", SourcesTypes);
	Context.Insert("IsObjectForm", IsObjectForm);
	Context.Insert("FunctionalOptions", FormCache.FunctionalOptions);
	
	FormCache.Insert("InputOnBasisUsingAttachableCommands", GenerateFrom.ObjectsAttachedToSubsystem(SourcesTypes));
	If FormCache.InputOnBasisUsingAttachableCommands Then
		GenerateFrom.OnDefineCommandsAttachedToObject(Context, Sources, AttachedObjects, Commands);
	EndIf;
	
	ObjectsFilling.OnDefineCommandsAttachedToObject(Context, Sources, AttachedObjects, Commands);
	SSLSubsystemsIntegration.OnDefineCommandsAttachedToObject(Context, Sources, AttachedObjects, Commands);
	AttachableCommandsOverridable.OnDefineCommandsAttachedToObject(Context, Sources, AttachedObjects, Commands);
	
	// Filtering commands by form names and functional options.
	NameParts = StrSplit(FormName, ".");
	ShortFormName = NameParts[NameParts.UBound()];
	Count = Commands.Count();
	For Number = 1 To Count Do
		Command = Commands[Count - Number];
		// Default values.
		If Command.ChangesSelectedObjects = Undefined Then
			Command.ChangesSelectedObjects = False;
		EndIf;
		
		// Filter by assignment.
		If Command.Purpose = "ForList" And Context.IsObjectForm Or Command.Purpose = "ForObject" And Not Context.IsObjectForm Then
			Commands.Delete(Command);
			Continue;
		EndIf;
		
		// Filter by form names.
		VisibilityInForms = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Upper(Command.VisibilityInForms), ",", True, True);
		If VisibilityInForms.Count() > 0
			And VisibilityInForms.Find(Upper(ShortFormName)) = Undefined
			And VisibilityInForms.Find(Upper(FormName)) = Undefined Then
			Commands.Delete(Command);
			Continue;
		EndIf;
		// Filter by functional options.
		FunctionalOptions = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Command.FunctionalOptions, ",", True, True);
		CommandVisibility = FunctionalOptions.Count() = 0;
		For Each OptionName1 In FunctionalOptions Do
			If GetFunctionalOption(TrimAll(OptionName1)) Then
				CommandVisibility = True;
				Break;
			EndIf;
		EndDo;
		If Not CommandVisibility Then
			Commands.Delete(Command);
			Continue;
		EndIf;
		// Dynamic applied visibility conditions.
		If TypeOf(Command.ParameterType) = Type("Type") Then
			TypesArray = New Array;
			TypesArray.Add(Command.ParameterType);
			Command.ParameterType = New TypeDescription(TypesArray);
		EndIf;
		If TypeOf(Command.ParameterType) = Type("TypeDescription") And ValueIsFilled(Command.ParameterType) Then
			HasAtLeastOneType = False;
			For Each Type In SourcesTypes Do
				If Command.ParameterType.ContainsType(Type) Then
					HasAtLeastOneType = True;
				Else
					Command.HasVisibilityConditions = True;
				EndIf;
			EndDo;
			If Not HasAtLeastOneType Then
				Commands.Delete(Command);
				Continue;
			EndIf;
		EndIf;
		If TypeOf(Command.VisibilityConditions) = Type("Array") And Command.VisibilityConditions.Count() > 0 Then
			Command.HasVisibilityConditions = True;
		EndIf;
		If Command.MultipleChoice = Undefined Then
			Command.MultipleChoice = True;
		EndIf;
		Command.ImportanceOrder = ?(Command.Importance = "Important", 1, ?(Command.Importance = "SeeAlso", 3, 2));
		FormCache.HasVisibilityConditions = FormCache.HasVisibilityConditions Or Command.HasVisibilityConditions;
		
		If IsBlankString(Command.Id) Then
			Command.Id = "Auto_" + Common.CheckSumString(Command.Manager + "/" + Command.FormName + "/" + Command.Handler);
		EndIf;
	EndDo;
	
	Return FormCache;
EndFunction

Procedure CheckCommandsKindName(KindName) Export
	
	If Not CommonClientServer.NameMeetPropertyNamingRequirements(KindName) Then
		ErrorText = NStr("en = 'Command kind name ""%1"" does not meet naming requirements for variables.';");
		Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorText, KindName);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Output.

// Places attached commands in the form.
//
// Parameters:
//   Form - ClientApplicationForm - a form, where the commands are to be placed.
//   Commands - See CommandsTable
//   PlacementParameters - See PlacementParameters
//
Procedure OutputCommands(Form, Commands, PlacementParameters)
	
	CommandsPrefix = "";
	If TypeOf(PlacementParameters.CommandsOwner) = Type("FormTable") Then
		CommandsPrefix = "Item_" + PlacementParameters.CommandsOwner.Name;
	ElsIf TypeOf(PlacementParameters.CommandsOwner) = Type("FormDataStructure") Then
		For Each Attribute In Form.GetAttributes() Do
			If Attribute = PlacementParameters.CommandsOwner Then
				CommandsPrefix = "Attribute_" + Attribute.Name;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	PlacementParameters.CommandsOwner = CommandsPrefix;
	
	AttachedCommands = AttachedCommands(Form);
	AttachedCommands.InputOnBasisUsingAttachableCommands = PlacementParameters.InputOnBasisUsingAttachableCommands;
	
	PlacementParametersKey = PlacementParametersKey(PlacementParameters);
	EarlierAddedCommands = Undefined;
	
	If AttachedCommands.CommandsTableAddress <> Undefined And IsTempStorageURL(AttachedCommands.CommandsTableAddress) Then
		EarlierAddedCommands = GetFromTempStorage(AttachedCommands.CommandsTableAddress);
		CommandsToRemove = EarlierAddedCommands.FindRows(New Structure("PlacementParametersKey", PlacementParametersKey));
		RemoveCommands(Form, CommandsToRemove);
		For Each Command In CommandsToRemove Do
			CommandCollection = AttachedCommands.CommandsMarked;
			For IndexOf = -CommandCollection.UBound() To 0 Do
				SubmenuCommand = CommandCollection[-IndexOf];
				If SubmenuCommand.NameOnForm = Command.NameOnForm Then
					CommandCollection.Delete(-IndexOf);
				EndIf;
			EndDo;
			For Each Popup In AttachedCommands.SubmenuWithVisibilityConditions Do
				CommandCollection = Popup.CommandsWithVisibilityConditions;
				For IndexOf = -CommandCollection.UBound() To 0 Do
					SubmenuCommand = CommandCollection[-IndexOf];
					If SubmenuCommand.NameOnForm = Command.NameOnForm Then
						CommandCollection.Delete(-IndexOf);
					EndIf;
				EndDo;
			EndDo;
			EarlierAddedCommands.Delete(Command);
		EndDo;
	EndIf;
	
	If ValueIsFilled(CommandsPrefix) And AttachedCommands.CommandsOwners.Find(CommandsPrefix) = Undefined Then
		AttachedCommands.CommandsOwners.Add(CommandsPrefix);
	EndIf;
	
	AttachedCommands.HasVisibilityConditions = AttachedCommands.HasVisibilityConditions Or PlacementParameters.HasVisibilityConditions;
	
	Items = Form.Items;
	GroupsPrefix = ?(ValueIsFilled(PlacementParameters.GroupsPrefix), PlacementParameters.GroupsPrefix, "");
	
	CommandBar = PlacementParameters.CommandBar;
	If CommandBar = Undefined Then
		CommandBar = CommandBarForm(Form, GroupsPrefix, PlacementParameters.IsObjectForm);
	EndIf;
	
	InfoOnAllSubmenus = InfoOnAllSubmenus();
	SubmenuInfoQuickSearch = New Map;
	
	RootSubmenuAndCommands = AttachedCommands.RootSubmenuAndCommands;
	
	// Output commands.
	Commands.Sort("Kind, ImportanceOrder Asc, Order Asc, Presentation Asc");
	CommandsCounterWithAutonaming = 0;
	CommandsKinds = AttachableCommandsCached.CommandsKinds();
	InfoOnGenerateSubmenu = Undefined;
	
	For Each CommandsKind In CommandsKinds Do
		KindCommands = Commands.FindRows(New Structure("Kind", CommandsKind.Name)); // Array of ValueTableRow: See CommandsTable
		
		If KindCommands.Count() = 0 And CommandsKind.Name <> "GenerateFrom" Then
			Continue;
		EndIf;
		
		SubmenuNameByDefault = "";
		If Not IsBlankString(CommandsKind.SubmenuName) Then
			SubmenuNameByDefault = GroupsPrefix + CommandsKind.SubmenuName;
		EndIf;
		
		SubmenuInfoByDefault = SubmenuInfoQuickSearch.Get(Lower(SubmenuNameByDefault));
		If SubmenuInfoByDefault = Undefined Then
			SubmenuInfoByDefault = RegisterSubmenu(Items, InfoOnAllSubmenus, SubmenuNameByDefault, 
				CommandsKind, CommandBar);
			SubmenuInfoQuickSearch.Insert(Lower(SubmenuNameByDefault), SubmenuInfoByDefault);
		EndIf;
		
		If CommandsKind.Name = "GenerateFrom" Then
			InfoOnGenerateSubmenu = SubmenuInfoByDefault;
		EndIf;
		
		For Each Command In KindCommands Do 
			If IsBlankString(Command.Popup) Then
				CommandSubmenuInfo = SubmenuInfoByDefault;
			Else
				SubmenuName = GroupsPrefix + Command.Popup;
				CommandSubmenuInfo = SubmenuInfoQuickSearch.Get(Lower(SubmenuName));
				If CommandSubmenuInfo = Undefined Then
					CommandSubmenuInfo = RegisterSubmenu(Items, InfoOnAllSubmenus, SubmenuName,,,
						SubmenuInfoByDefault);
					SubmenuInfoQuickSearch.Insert(Lower(SubmenuName), CommandSubmenuInfo);
				EndIf;
			EndIf;
			CommandSubmenuInfo.CommandsCount = CommandSubmenuInfo.CommandsCount + 1;
			CommandSubmenuInfo.Commands.Add(Commands.IndexOf(Command));
		EndDo;
	EndDo;
	
	For Each CommandSubmenuInfo In InfoOnAllSubmenus Do
		For Each CommandIndex In CommandSubmenuInfo.Commands Do
			Command = Commands[CommandIndex];
			
			FormGroup = Undefined; // FormGroup
			If Not ValueIsFilled(Command.Importance)
				Or Not CommandSubmenuInfo.Groups.Property(Command.Importance, FormGroup) Then
				FormGroup = CommandSubmenuInfo.DefaultGroup;
			EndIf;
			
			Command.NameOnForm = DefineCommandName(Form, FormGroup.Name, Command.Id, 
				CommandsCounterWithAutonaming, CommandsPrefix);
			Command.PlacementParametersKey = PlacementParametersKey;
			
			Popup = CommandSubmenuInfo.Popup; // FormGroup
			IsCommandOfCommandBarType = Command.Kind = "CommandBar";
			RootItemName = ?(IsCommandOfCommandBarType, Command.NameOnForm, Popup.Name);
					
			FormCommand = Form.Commands.Add(Command.NameOnForm);
			FormCommand.Action = "Attachable_ExecuteCommand";
			FormCommand.Title = Command.Presentation;
			FormCommand.ToolTip   = FormCommand.Title;
			FormCommand.Representation = ?(ValueIsFilled(Command.ButtonRepresentation),
				Command.ButtonRepresentation, ButtonRepresentation.PictureAndText);
			If TypeOf(Command.Picture) = Type("Picture") Then
				FormCommand.Picture = Command.Picture;
			EndIf;
			If TypeOf(Command.Shortcut) = Type("Shortcut") Then
				FormCommand.Shortcut = Command.Shortcut;
			EndIf;
			If CommandSubmenuInfo.Popup = CommandBar
				And StrLen(Command.Presentation) > 35
				And ValueIsFilled(FormCommand.Picture) Then
				FormCommand.Representation = ButtonRepresentation.Picture;
			EndIf;
			FormCommand.ModifiesStoredData = Command.ChangesSelectedObjects 
				And PlacementParameters.IsObjectForm And Form.ReadOnly;
				
			If CommandSubmenuInfo.CommandsCount = 1 And TypeOf(FormGroup.Parent) <> Type("ClientApplicationForm") 
				And Not IsCommandOfCommandBarType Then
				FormButton = Items.Insert(Command.NameOnForm, Type("FormButton"), CommandSubmenuInfo.Popup.Parent, FormGroup.Parent);
			Else
				FormButton = Items.Add(Command.NameOnForm, Type("FormButton"), FormGroup);
			EndIf;
			
			FormButton.Type = FormButtonType.CommandBarButton;
			FormButton.CommandName = Command.NameOnForm;
			If Command.OnlyInAllActions = True Then
				LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
			ElsIf Command.OnlyInAllActions = False Then
				LocationInCommandBar = ButtonLocationInCommandBar.InCommandBarAndInAdditionalSubmenu;
			Else
				LocationInCommandBar = ButtonLocationInCommandBar.Auto;
			EndIf;
			FormButton.LocationInCommandBar = LocationInCommandBar;
			
			If ValueIsFilled(Command.CheckMarkValue) And IsAttributePath(Command.CheckMarkValue) Then
				Command.CheckMarkValue = TheExpressionCalculationNotes(Command.CheckMarkValue);
				AttachedCommands.CommandsMarked.Add(CommandDetailsAtClient(Command, FormButton, CommandsPrefix));
			EndIf;
			
			CommandRootSubmenuProperties = RootSubmenuAndCommands[RootItemName];
			If CommandRootSubmenuProperties = Undefined Then
				CommandRootSubmenuProperties = CommandRootSubmenuProperties();
				CommandRootSubmenuProperties.HasInCommandBar = 
					FormButton.LocationInCommandBar <> ButtonLocationInCommandBar.InAdditionalSubmenu;
				CommandRootSubmenuProperties.CommandsPrefix = CommandsPrefix;
				RootSubmenuAndCommands.Insert(RootItemName, CommandRootSubmenuProperties);
			EndIf;
			
			CommandSubmenuInfo.LastCommand = FormCommand;
			If Command.HasVisibilityConditions Then
				CommandSubmenuInfo.HasCommandsWithVisibilityConditions = True;
				
				CommandInfo = New Structure;
				CommandInfo.Insert("NameOnForm");
				CommandInfo.Insert("ParameterType");
				CommandInfo.Insert("VisibilityConditions");
				CommandInfo.Insert("VisibilityConditionsByObjectTypes");
				CommandInfo.Insert("CommandsPrefix");
				FillPropertyValues(CommandInfo, Command);
				
				CommandInfo.CommandsPrefix = CommandsPrefix;
				CommandSubmenuInfo.CommandsWithVisibilityConditions.Add(CommandInfo);
			ElsIf Not Command.OnlyInAllActions Then
				CommandSubmenuInfo.HasCommandsWithoutVisibilityConditions = True;
			EndIf;
		EndDo;
	EndDo;
	
	GenerateFrom.OnOutputCommands(Form, InfoOnGenerateSubmenu, PlacementParameters);
	
	// A stub command is always required.
	CapCommand = Form.Commands.Find("OutputToEmptySubmenuCommand");
	If CapCommand = Undefined Then
		CapCommand = Form.Commands.Add("OutputToEmptySubmenuCommand");
		CapCommand.Title = NStr("en = '(N/A)';");
	EndIf;
	
	// Selected submenu post-processing.
	For Each SubmenuInfo In InfoOnAllSubmenus Do
		If SubmenuInfo.CommandsCount = 0 Then
			Continue;
		EndIf;
		IsCommandBar = (SubmenuInfo.Popup = CommandBar);
		FormCommand = SubmenuInfo.LastCommand;
		Popup = SubmenuInfo.Popup; // FormGroup
		
		If Not IsCommandBar Then
			If SubmenuInfo.CommandsCount = 1 And FormCommand <> Undefined Then
				// Submenu turns to button when 1 command with a short title is displayed.
				If Not ValueIsFilled(FormCommand.Picture) And Popup.Type = FormGroupType.Popup Then
					FormCommand.Picture = Popup.Picture;
				EndIf;
				
				If Not ValueIsFilled(FormCommand.Picture) Then
					FormCommand.Picture = SubmenuInfo.SubmenuImage;
				EndIf;			
				
				If StrLen(FormCommand.Title) <= 35 And Popup.Representation <> ButtonRepresentation.Picture Then
					FormCommand.Representation = ButtonRepresentation.PictureAndText;
				Else
					FormCommand.Representation = ButtonRepresentation.Picture;
				EndIf;
				FormCommand.ToolTip = FormCommand.Title;
			Else
				// Adding cap buttons that are shown when all commands are hidden in the submenu.
				CapCommandName = Popup.Name + "Stub";
				If Items.Find(CapCommandName) = Undefined Then
					FormButton = Items.Add(CapCommandName, Type("FormButton"), Popup);
					FormButton.Type = FormButtonType.CommandBarButton;
					FormButton.CommandName  = "OutputToEmptySubmenuCommand";
					FormButton.Visible   = False;
					FormButton.Enabled = False;
					FormButton.LocationInCommandBar = ButtonLocationInCommandBar.InCommandBar;
				EndIf;
			EndIf;
		EndIf;
		
		If SubmenuInfo.HasCommandsWithVisibilityConditions Then
			SubmenuShortInfo = SubmenuShortInfo(SubmenuInfo);
			SubmenuShortInfo.Name = Popup.Name;
			AttachedCommands.SubmenuWithVisibilityConditions.Add(SubmenuShortInfo);
		EndIf;
	EndDo;
	
	If EarlierAddedCommands <> Undefined Then
		EarlierAddedCommands = GetFromTempStorage(AttachedCommands.CommandsTableAddress);
		If TypeOf(EarlierAddedCommands) = Type("ValueTable") Then
			IndexOf = -1;
			For Each TableRow In EarlierAddedCommands Do
				IndexOf = IndexOf + 1;
				FillPropertyValues(Commands.Insert(IndexOf), TableRow);
			EndDo;
		EndIf;
		DeleteFromTempStorage(AttachedCommands.CommandsTableAddress);
	EndIf;
	
	Commands.Columns.Delete("Shortcut");
	AttachedCommands.CommandsTableAddress = PutToTempStorage(Commands, Form.UUID);
	
EndProcedure

// Returns:
//  ValueTable:
//   * Popup - FormGroup 
//   * CommandsCount - Number
//   * HasCommandsWithVisibilityConditions - Boolean
//   * HasCommandsWithoutVisibilityConditions - Boolean
//   * Groups - Structure:
//    ** Ordinary - FormGroup
//    ** Important - FormGroup
//    ** SeeAlso - FormGroup
//   * DefaultGroup - FormGroup
//   * LastCommand - FormCommand
//   * CommandsWithVisibilityConditions - Array
//   * SubmenuImage - Picture
//   * Commands - Array
//
Function InfoOnAllSubmenus()
	
	InfoOnAllSubmenus = New ValueTable;
	InfoOnAllSubmenus.Columns.Add("Popup");
	InfoOnAllSubmenus.Columns.Add("CommandsCount", New TypeDescription("Number"));
	InfoOnAllSubmenus.Columns.Add("HasCommandsWithVisibilityConditions", New TypeDescription("Boolean"));
	InfoOnAllSubmenus.Columns.Add("HasCommandsWithoutVisibilityConditions", New TypeDescription("Boolean"));
	InfoOnAllSubmenus.Columns.Add("Groups", New TypeDescription("Structure"));
	InfoOnAllSubmenus.Columns.Add("DefaultGroup");
	InfoOnAllSubmenus.Columns.Add("LastCommand");
	InfoOnAllSubmenus.Columns.Add("CommandsWithVisibilityConditions", New TypeDescription("Array"));
	InfoOnAllSubmenus.Columns.Add("SubmenuImage");
	InfoOnAllSubmenus.Columns.Add("Commands", New TypeDescription("Array"));
	
	Return InfoOnAllSubmenus;
	
EndFunction

// Returns:
//  Structure:
//   * Name - String
//   * CommandsWithVisibilityConditions - Array
//   * HasCommandsWithoutVisibilityConditions - Boolean
//
Function SubmenuShortInfo(SubmenuInfo)
	SubmenuShortInfo = New Structure("Name, CommandsWithVisibilityConditions, HasCommandsWithoutVisibilityConditions");
	FillPropertyValues(SubmenuShortInfo, SubmenuInfo);
	Return SubmenuShortInfo;
EndFunction

Function PlacementParametersKey(Val PlacementParameters)
	
	PlacementParameters = Common.CopyRecursive(PlacementParameters);
	PlacementParameters.Delete("IsObjectForm");
	
	FormGroup = PlacementParameters.CommandBar;
	
	If TypeOf(FormGroup) = Type("FormGroup") Then
		PlacementParameters.CommandBar = FormGroup.Name;
	EndIf;
	
	Sources = New Array;
	
	If TypeOf(PlacementParameters.Sources) = Type("Array") Then
		For Each MetadataObject In PlacementParameters.Sources Do
			Sources.Add(MetadataObject.FullName());
		EndDo;
		PlacementParameters.Sources = Sources;
	EndIf;
	
	Return Common.CheckSumString(Common.ValueToXMLString(PlacementParameters));

EndFunction

Procedure RemoveCommands(Form, CommandsToRemove)
	
	For Each CommandDetails In CommandsToRemove Do
		Command = Form.Commands[CommandDetails.NameOnForm];
		Form.Commands.Delete(Command);
		Form.Items.Delete(Form.Items[CommandDetails.NameOnForm]);
	EndDo;
	
EndProcedure

Function CommandBarForm(Form, GroupsPrefix, IsObjectForm)
	
	Items = Form.Items;
	
	Result = Items.Find(GroupsPrefix + "AttachableCommands");
	If Result = Undefined Then
		Result = Items.Find(GroupsPrefix + "CommandBar");
		
		If Result = Undefined Then
			Result = Items.Find(GroupsPrefix + "MainCommandBar");
			
			If Result = Undefined And ValueIsFilled(GroupsPrefix) Then
				FormTable = Items.Find(GroupsPrefix);
				If TypeOf(FormTable) = Type("FormTable") Then
					Result = FormTable.CommandBar;
				EndIf;
			EndIf;
			
			If Not IsObjectForm
				And Result = Undefined
				And Not ValueIsFilled(GroupsPrefix) Then
				FormTable = Items.Find("List");
				If TypeOf(FormTable) = Type("FormTable")
					And FormTable.CommandBarLocation <> FormItemCommandBarLabelLocation.None Then
					Result = FormTable.CommandBar;
				EndIf;
			EndIf;
			
			If Result = Undefined Then
				Result = Form.CommandBar;
			EndIf;
		EndIf;
	EndIf;
	
	Return Result;

EndFunction

Function AttachedCommands(Form)
	
	PropertiesValues = New Structure("AttachableCommandsParameters", Null);
	FillPropertyValues(PropertiesValues, Form);

	Result = PropertiesValues.AttachableCommandsParameters;
	
	If TypeOf(Result) <> Type("Structure") Then
		If Result = Null Then
			AttributesToBeAdded = New Array;
			AttributesToBeAdded.Add(New FormAttribute("AttachableCommandsParameters", New TypeDescription));
			Form.ChangeAttributes(AttributesToBeAdded);
		EndIf;
		
		Result = New Structure;
		Result.Insert("HasVisibilityConditions", False);
		Result.Insert("SubmenuWithVisibilityConditions", New Array);
		Result.Insert("CommandsMarked", New Array);
		Result.Insert("RootSubmenuAndCommands", New Map);
		Result.Insert("CommandsAvailability", True);
		Result.Insert("CommandsTableAddress", Undefined);
		Result.Insert("InputOnBasisUsingAttachableCommands");
		Result.Insert("CommandsOwners", New Array);
		
		Form.AttachableCommandsParameters = Result;
	EndIf;
	
	Return Result;

EndFunction

Function CommandRootSubmenuProperties()
	
	Result = New Structure;
	Result.Insert("HasInCommandBar", False);
	Result.Insert("CommandsPrefix", "");
	Result.Insert("CommandsAvailability", True);
	
	Return Result;
	
EndFunction

Function IsAttributePath(Val AttributePath)
	AttributePath = Upper(AttributePath);
	AttributePath = StrReplace(AttributePath, "NOT ", "");
	IDs = StrSplit(StrReplace(AttributePath, "%SOURCE%",""), ".");
	For Each Item In IDs Do
		If Not CommonClientServer.NameMeetPropertyNamingRequirements(Item) Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
EndFunction

Function CommandDetailsAtClient(Command, FormButton, CommandsPrefix)
	CommandDetails = New Structure;
	CommandDetails.Insert("NameOnForm", FormButton.Name);
	CommandDetails.Insert("Kind", Command.Kind);
	CommandDetails.Insert("Id", Command.Id);
	CommandDetails.Insert("CheckMarkValue", Command.CheckMarkValue);
	CommandDetails.Insert("CommandsPrefix", CommandsPrefix);
	Return CommandDetails;
EndFunction

Function RegisterSubmenu(Items, InfoOnAllSubmenus, SubmenuName, NewSubmenuTemplate = Undefined, 
	CommandBar = Undefined, SubmenuByDefault = Undefined)
	
	CommandsCount = 0;
	Groups = New Structure;
	SubmenuImage = Undefined;
	If ValueIsFilled(SubmenuName) Then
		Popup = Items.Find(SubmenuName);
		If Popup = Undefined Then
			If NewSubmenuTemplate = Undefined Then
				Return SubmenuByDefault;
			EndIf;
			Popup = Items.Add(SubmenuName, Type("FormGroup"), CommandBar);
			Popup.Type         = ?(ValueIsFilled(NewSubmenuTemplate.FormGroupType), NewSubmenuTemplate.FormGroupType, 
				FormGroupType.Popup);
			If ValueIsFilled(NewSubmenuTemplate.Representation) Then
				Popup.Representation = NewSubmenuTemplate.Representation;
			EndIf;
			Popup.Title   = NewSubmenuTemplate.Title;
			If Popup.Type = FormGroupType.Popup Then
				Popup.Picture    = NewSubmenuTemplate.Picture;
				SubmenuImage		= Popup.Picture;
			EndIf;
		Else
			DefaultGroup = Popup;
			If Popup.Type = FormGroupType.Popup Then
				SubmenuImage		= Popup.Picture;
			ElsIf NewSubmenuTemplate <> Undefined Then
				SubmenuImage 	= NewSubmenuTemplate.Picture;
			ElsIf SubmenuByDefault <> Undefined Then
				SubmenuImage 	= SubmenuByDefault.SubmenuImage;
			EndIf;
			CommandsCount = GroupCommandsCount(DefaultGroup);
			For Each Group In Popup.ChildItems Do
				If TypeOf(Group) <> Type("FormGroup") Then
					Continue;
				EndIf;
				ShortName = Group.Name;
				If StrStartsWith(Lower(ShortName), Lower(SubmenuName)) Then
					ShortName = Mid(ShortName, StrLen(SubmenuName) + 1);
					If Lower(ShortName) = Lower("Ordinary") Then
						DefaultGroup = Group;
					EndIf;
				EndIf;
				Groups.Insert(ShortName, Group);
			EndDo;
		EndIf;
		
		If Popup.Representation = ButtonRepresentation.Picture And Not ValueIsFilled(Popup.ToolTip) Then
			Popup.ToolTip = Popup.Title;
		EndIf;
		
		If Not Groups.Property("Important") Then
			GroupImportant = Items.Add(SubmenuName + "Important", Type("FormGroup"), Popup);
			GroupImportant.Type = FormGroupType.ButtonGroup;
			GroupImportant.Title = Popup.Title + " (" + NStr("en = 'Important';") + ")";
			Groups.Insert("Important", GroupImportant);
		EndIf;
		If Not Groups.Property("Ordinary") Then
			DefaultGroup = Items.Add(SubmenuName + "Ordinary", Type("FormGroup"), Popup);
			DefaultGroup.Type = FormGroupType.ButtonGroup;
			DefaultGroup.Title = Popup.Title + " (" + NStr("en = 'Standard';") + ")";
			Groups.Insert("Ordinary", DefaultGroup);
		EndIf;
		If Not Groups.Property("SeeAlso") Then
			GroupSeeAlso = Items.Add(SubmenuName + "SeeAlso", Type("FormGroup"), Popup);
			GroupSeeAlso.Type = FormGroupType.ButtonGroup;
			GroupSeeAlso.Title = Popup.Title + " (" + NStr("en = 'See also:';") + ")";
			Groups.Insert("SeeAlso", GroupSeeAlso);
		EndIf;
		
	Else
		If NewSubmenuTemplate = Undefined Then
			Return SubmenuByDefault;
		EndIf;
		Popup = CommandBar;
		DefaultGroup = CommandBar;
	EndIf;
	
	Result = InfoOnAllSubmenus.Add();
	Result.Popup = Popup;
	Result.DefaultGroup = DefaultGroup;
	Result.Groups = Groups;
	Result.CommandsCount = CommandsCount;
	Result.SubmenuImage = SubmenuImage;
	
	Return Result;
EndFunction

Function GroupCommandsCount(Group)
	Result = 0;
	For Each Item In Group.ChildItems Do
		If TypeOf(Item) = Type("FormGroup") Then
			Result = Result + GroupCommandsCount(Item);
		ElsIf TypeOf(Item) = Type("FormButton") Then
			Result = Result + 1;
		EndIf;
	EndDo;
	Return Result;
EndFunction

Function DefineCommandName(Form, GroupName, CommandID, CommandsCounterWithAutonaming, CommandsPrefix)
	If CommonClientServer.NameMeetPropertyNamingRequirements(CommandID) Then
		CommandName = GroupName + "_" + CommandsPrefix + "_" +  CommandID;
	Else
		CommandsCounterWithAutonaming = CommandsCounterWithAutonaming + 1;
		CommandName = GroupName + "_" + CommandsPrefix + "_" + Format(CommandsCounterWithAutonaming, "NZ=; NG=");
	EndIf;
		
	While Form.Items.Find(CommandName) <> Undefined
		Or Form.Commands.Find(CommandName) <> Undefined Do
		CommandsCounterWithAutonaming = CommandsCounterWithAutonaming + 1;
		CommandName = GroupName + "_" + CommandsPrefix + "_" + Format(CommandsCounterWithAutonaming, "NZ=; NG=");
	EndDo;
	Return CommandName;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Updates cache Objects metadata specified type.
//
// Parameters:
//  Filter - CatalogRef.MetadataObjectIDs - update configuration cache.
//                      Structure with the "AttachedObjects" key is written to the AttachableCommandsParameters constant.
//        - CatalogRef.ExtensionObjectIDs - update cache of extensions.
//                      Structure with the "AttachedObjects" key is written to the ExtensionVersionParameters register.
//
// Returns:
//   Structure:
//       * HasChanges - Boolean - True if there were changes made during the update.
//       * AttachedObjects - Map of KeyAndValue - Cache intended to quickly define a list of objects attached to configuration objects.
//           :
//           ** Key - CatalogRef.MetadataObjectIDs, CatalogRef.ExtensionObjectIDs.
//           ** Value - Array of String
//
Function CommonDataNonexclusiveUpdate(Filter)
	Result = New Structure;
	Result.Insert("HasChanges", False);
	
	If Filter = Type("CatalogRef.ExtensionObjectIDs")
		And Not ValueIsFilled(SessionParameters.ExtensionsVersion) Then
		Return Result;
	EndIf;
	
	AttachedObjects = New Map;
	InterfaceSettings4 = AttachableObjectsInterfaceSettings();
	
	Content = Metadata.Subsystems.AttachableReportsAndDataProcessors.Content;
	For Each VendorMetadataObject In Content Do
		If Not Common.SeparatedDataUsageAvailable() And VendorMetadataObject.ConfigurationExtension() <> Undefined Then
			Continue;
		EndIf;
		
		MetadataObjectID = Common.MetadataObjectID(VendorMetadataObject, False);
		If TypeOf(MetadataObjectID) <> Filter Then
			Continue;
		EndIf;
		FullName = VendorMetadataObject.FullName();
		Settings = AttachableObjectSettings(FullName, InterfaceSettings4);
		If Settings = Undefined Then
			Continue;
		EndIf;
		For Each MetadataObject In Settings.Location Do
			MetadataObjectID = Common.MetadataObjectID(MetadataObject);
			DestinationArray = AttachedObjects[MetadataObjectID];
			If DestinationArray = Undefined Then
				DestinationArray = New Array;
				AttachedObjects.Insert(MetadataObjectID, DestinationArray);
			EndIf;
			If DestinationArray.Find(FullName) = Undefined Then
				DestinationArray.Add(FullName);
			EndIf;
		EndDo;
	EndDo;
	
	If Filter = Type("CatalogRef.MetadataObjectIDs") Then
		PreviousValue2 = StandardSubsystemsServer.ApplicationParameter(FullSubsystemName());
	ElsIf Filter = Type("CatalogRef.ExtensionObjectIDs") Then
		PreviousValue2 = StandardSubsystemsServer.ExtensionParameter(FullSubsystemName());
	Else
		Return Result;
	EndIf;
	
	NewValue = New Structure("AttachedObjects", AttachedObjects);
	If Not Common.DataMatch(PreviousValue2, NewValue) Then
		Result.HasChanges = True;
		If Filter = Type("CatalogRef.MetadataObjectIDs") Then
			StandardSubsystemsServer.SetApplicationParameter(FullSubsystemName(), NewValue);
		ElsIf Filter = Type("CatalogRef.ExtensionObjectIDs") Then
			StandardSubsystemsServer.SetExtensionParameter(FullSubsystemName(), NewValue);
		EndIf;
	EndIf;
	
	Result.Insert("AttachedObjects", AttachedObjects);
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Calls from the ServerCall modules.

// Returns command details by form item name.
// 
// Parameters:
//  CommandNameInForm A command name on a form
//  SettingsAddress Settings address
// 
// Returns:
//  FixedStructure:
//   * Kind - String
//   * Id - String
//   * Presentation - String
//   * Popup - String
//   * Importance - String
//   * Order - Number
//   * Picture - Picture
//   * Shortcut - Shortcut
//   * ButtonRepresentation - Undefined
//   * OnlyInAllActions - Boolean
//   * CheckMarkValue - String
//   * ParameterType - TypeDescription
//   * VisibilityInForms - String
//   * Purpose - String
//   * FunctionalOptions - String
//   * VisibilityConditions - Array
//   * ChangesSelectedObjects - Boolean
//   * MultipleChoice - Boolean, Undefined
//   * WriteMode - String
//   * FilesOperationsRequired - Boolean
//   * Manager - String
//   * Handler - String
//   * AdditionalParameters - Structure
//   * FormName - String
//   * FormParameters - Structure, Undefined
//   * FormParameterName - String
//   * ImportanceOrder - Number
//   * NameOnForm - String
//   * HasVisibilityConditions - Boolean
//   * PlacementParametersKey - String
//
Function CommandDetails(CommandNameInForm, SettingsAddress) Export
	Commands = GetFromTempStorage(SettingsAddress);
	Command = Commands.Find(CommandNameInForm, "NameOnForm");
	If Command = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Information on command ""%1"" does not exist.';"),
			CommandNameInForm);
	EndIf;
	CommandDetails = Common.ValueTableRowToStructure(Command);
	
	If ValueIsFilled(CommandDetails.FormName) Then
		CommandDetails.Insert("ServerRoom", False);
		SubstringsArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(CommandDetails.FormName, ".", True, True);
		SubstringCount = SubstringsArray.Count();
		If SubstringCount = 1
			Or (SubstringCount = 2 And Upper(SubstringsArray[0]) <> "COMMONFORM") Then
			CommandDetails.FormName = CommandDetails.Manager + "." + CommandDetails.FormName;
		EndIf;
	Else
		CommandDetails.Insert("ServerRoom", True);
		If ValueIsFilled(CommandDetails.Handler) Then
			If Not IsBlankString(CommandDetails.Manager) And StrFind(CommandDetails.Handler, ".") = 0 Then
				CommandDetails.Handler = CommandDetails.Manager + "." + CommandDetails.Handler;
			EndIf;
			If StrStartsWith(Upper(CommandDetails.Handler), Upper("CommonModule.")) Then
				PointPosition = StrFind(CommandDetails.Handler, ".");
				CommandDetails.Handler = Mid(CommandDetails.Handler, PointPosition + 1);
			EndIf;
			SubstringsArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(CommandDetails.Handler, ".", True, True);
			SubstringCount = SubstringsArray.Count();
			If SubstringCount = 2 Then
				ModuleName = SubstringsArray[0];
				MetadataObjectCommonModule = Metadata.CommonModules.Find(ModuleName);
				If MetadataObjectCommonModule = Undefined Then
					Raise StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Common module ""%1"" does not exist.';"),
						ModuleName);
				EndIf;
				If MetadataObjectCommonModule.ClientManagedApplication Then
					CommandDetails.ServerRoom = False;
				EndIf;
			Else
				Kind = Upper(SubstringsArray[0]);
				KindInPlural1 = MetadataObjectKindInPlural(Kind);
				If KindInPlural1 <> Undefined Then
					SubstringsArray.Set(0, KindInPlural1);
					CommandDetails.Handler = StrConcat(SubstringsArray, ".");
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	CommandDetails.Delete("Manager");
	
	Return New FixedStructure(CommandDetails);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Operations with metadata objects.

// Returns the type of the object in plural.
Function MetadataObjectKindInPlural(Val Kind)
	Kind = Upper(TrimAll(Kind));
	If Kind = "EXCHANGEPLAN" Then
		Return "ExchangePlans";
	ElsIf Kind = "CATALOG" Then
		Return "Catalogs";
	ElsIf Kind = "DOCUMENT" Then
		Return "Documents";
	ElsIf Kind = "DOCUMENTJOURNAL" Then
		Return "DocumentJournals";
	ElsIf Kind = "ENUM" Then
		Return "Enums";
	ElsIf Kind = "REPORT" Then
		Return "Reports";
	ElsIf Kind = "DATAPROCESSOR" Then
		Return "DataProcessors";
	ElsIf Kind = "CHARTOFCHARACTERISTICTYPES" Then
		Return "ChartsOfCharacteristicTypes";
	ElsIf Kind = "CHARTOFACCOUNTS" Then
		Return "ChartsOfAccounts";
	ElsIf Kind = "CHARTOFCALCULATIONTYPES" Then
		Return "ChartsOfCalculationTypes";
	ElsIf Kind = "INFORMATIONREGISTER" Then
		Return "InformationRegisters";
	ElsIf Kind = "ACCUMULATIONREGISTER" Then
		Return "AccumulationRegisters";
	ElsIf Kind = "ACCOUNTINGREGISTER" Then
		Return "AccountingRegisters";
	ElsIf Kind = "CALCULATIONREGISTER" Then
		Return "CalculationRegisters";
	ElsIf Kind = "RECALCULATION" Then
		Return "Recalculations";
	ElsIf Kind = "BUSINESSPROCESS" Then
		Return "BusinessProcesses";
	ElsIf Kind = "TASK" Then
		Return "Tasks";
	ElsIf Kind = "CONSTANT" Then
		Return "Constants";
	ElsIf Kind = "SEQUENCE" Then
		Return "Sequences";
	Else
		Return Undefined;
	EndIf;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Templates.

// Attachable commands table template.
//
// Returns:
//  ValueTable:
//   * Kind - String
//   * Id - String
//   * Presentation - String
//   * Popup - String
//   * Importance - String
//   * Order - Number
//   * Picture - Picture
//   * Shortcut - Shortcut
//   * ButtonRepresentation - Undefined
//   * OnlyInAllActions - Boolean
//   * CheckMarkValue - String
//   * ParameterType - TypeDescription
//   * VisibilityInForms - String
//   * Purpose - String
//   * FunctionalOptions - String
//   * VisibilityConditions - Array
//   * ChangesSelectedObjects - Boolean
//   * MultipleChoice - Boolean, Undefined
//   * WriteMode - String
//   * FilesOperationsRequired - Boolean
//   * Manager - String
//   * Handler - String
//   * AdditionalParameters - Structure
//   * FormName - String
//   * FormParameters - Structure, Undefined
//   * FormParameterName - String
//   * ImportanceOrder - Number
//   * NameOnForm - String
//   * HasVisibilityConditions - Boolean
//   * PlacementParametersKey - String
//
Function CommandsTable()
	Table = New ValueTable;
	Table.Columns.Add("Kind", New TypeDescription("String"));
	Table.Columns.Add("Id", New TypeDescription("String"));
	// Appearance settings:
	Table.Columns.Add("Presentation", New TypeDescription("String"));
	Table.Columns.Add("Popup", New TypeDescription("String"));
	Table.Columns.Add("Importance", New TypeDescription("String"));
	Table.Columns.Add("Order", New TypeDescription("Number"));
	Table.Columns.Add("Picture"); // Picture
	Table.Columns.Add("Shortcut"); // Shortcut
	Table.Columns.Add("ButtonRepresentation");
	Table.Columns.Add("OnlyInAllActions", New TypeDescription("Boolean"));
	Table.Columns.Add("CheckMarkValue", New TypeDescription("String"));
	// Visibility and availability settings:
	Table.Columns.Add("ParameterType"); // TypeDescription
	Table.Columns.Add("VisibilityInForms", New TypeDescription("String"));
	Table.Columns.Add("Purpose", New TypeDescription("String"));
	Table.Columns.Add("FunctionalOptions", New TypeDescription("String"));
	Table.Columns.Add("VisibilityConditions", New TypeDescription("Array"));
	Table.Columns.Add("ChangesSelectedObjects"); // Boolean or Undefined.
	// Runtime settings:
	Table.Columns.Add("MultipleChoice"); // Boolean or Undefined.
	Table.Columns.Add("WriteMode", New TypeDescription("String"));
	Table.Columns.Add("FilesOperationsRequired", New TypeDescription("Boolean"));
	// Handler settings:
	Table.Columns.Add("Manager", New TypeDescription("String"));
	Table.Columns.Add("Handler", New TypeDescription("String"));
	Table.Columns.Add("AdditionalParameters", New TypeDescription("Structure"));
	Table.Columns.Add("FormName", New TypeDescription("String"));
	Table.Columns.Add("FormParameters"); // Structure or Undefined.
	Table.Columns.Add("FormParameterName", New TypeDescription("String"));
	// Service:
	Table.Columns.Add("ImportanceOrder", New TypeDescription("Number"));
	Table.Columns.Add("NameOnForm", New TypeDescription("String"));
	Table.Columns.Add("HasVisibilityConditions", New TypeDescription("Boolean"));
	Table.Columns.Add("PlacementParametersKey", New TypeDescription("String"));
	Table.Columns.Add("VisibilityConditionsByObjectTypes", New TypeDescription("Map"));
		
	Return Table;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Miscellaneous.

// Returns a full subsystem name.
Function FullSubsystemName() Export
	Return "StandardSubsystems.AttachableCommands";
EndFunction

Function MergeTypes(Type1, Type2)
	Type1IsTypesDetails = TypeOf(Type1) = Type("TypeDescription");
	Type2IsTypesDetails = TypeOf(Type2) = Type("TypeDescription");
	If Type1IsTypesDetails And Type1.Types().Count() > 0 Then
		SourceDescriptionOfTypes = Type1;
		AddedTypes = ?(Type2IsTypesDetails, Type2.Types(), ValueToArray(Type2));
	ElsIf Type2IsTypesDetails And Type2.Types().Count() > 0 Then
		SourceDescriptionOfTypes = Type2;
		AddedTypes = ValueToArray(Type1);
	ElsIf TypeOf(Type1) <> Type("Type") Then
		Return Type2;
	ElsIf TypeOf(Type2) <> Type("Type") Then
		Return Type1;
	Else
		Types = New Array;
		Types.Add(Type1);
		Types.Add(Type2);
		Return New TypeDescription(Types);
	EndIf;
	If AddedTypes.Count() = 0 Then
		Return SourceDescriptionOfTypes;
	Else
		Return New TypeDescription(SourceDescriptionOfTypes, AddedTypes);
	EndIf;
EndFunction

Function ValueToArray(Value)
	Result = New Array;
	Result.Add(Value);
	Return Result;
EndFunction

Function SpecifyCommandsSources(FullMetadataObjectName)
	MetadataObjectKind = Lower(StrSplit(FullMetadataObjectName, ".")[0]);
	Return MetadataObjectKind = Lower("ExternalDataProcessor")
		Or MetadataObjectKind = Lower("ExternalReport")
		Or MetadataObjectKind = Lower("DataProcessor")
		Or MetadataObjectKind = Lower("Report")
		Or MetadataObjectKind = Lower("CommonForm");
EndFunction

Function TheExpressionCalculationNotes(Val TagExpression)
	Result = "";
	
	TagExpression = Upper(TagExpression);
	AttributePath = StrReplace(TagExpression, "NOT ", "");
	If StrStartsWith(TagExpression, "NOT ") Then
		Result = "NOT "	
	EndIf;
	PartsOfThePathMarkValue = StrSplit(AttributePath, ".");
	For Cnt = 0 To PartsOfThePathMarkValue.Count() - 1 Do
		PartsOfThePathMarkValue[Cnt] = "["""+PartsOfThePathMarkValue[Cnt]+"""]";			
	EndDo;
	Result = Result + "Form"+StrConcat(PartsOfThePathMarkValue, "");
	
	Return Result;
EndFunction

// See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export

	Kind = AttachableCommandsKinds.Add();
	Kind.Name         = "Send";
	Kind.SubmenuName  = "SubmenuSend";
	Kind.Title   = NStr("en = 'Send';");
	Kind.Order     = 45;
	Kind.Picture    = PictureLib.SendMessage;
	Kind.Representation = ButtonRepresentation.PictureAndText;
	
	Kind = AttachableCommandsKinds.Add();
	Kind.Name         = "Organizer";
	Kind.SubmenuName  = "SubmenuOrganizer";
	Kind.Title   = NStr("en = 'Organizer';");
	Kind.Order     = 50;
	Kind.Picture    = PictureLib.Organizer;
	Kind.Representation = ButtonRepresentation.Picture;	

EndProcedure

#EndRegion
