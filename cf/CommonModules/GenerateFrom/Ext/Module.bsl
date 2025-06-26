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

// Adds a command of creation of the specified object to the list of commands of creation on basis.
//
// Parameters:
//  GenerationCommands - See GenerateFromOverridable.BeforeAddGenerationCommands.GenerationCommands
//  MetadataObject - MetadataObject - an object, for which the command is being added.
// 
// Returns:
//  ValueTableRow, Undefined - Details of the added command.
//
Function AddGenerationCommand(GenerationCommands, MetadataObject) Export
	If AccessRight("Insert", MetadataObject) Then
		CreateBasedOnCommand = GenerationCommands.Add();
		CreateBasedOnCommand.Manager = MetadataObject.FullName();
		CreateBasedOnCommand.Presentation = Common.ObjectPresentation(MetadataObject);
		CreateBasedOnCommand.WriteMode = "Write";
		
		Return CreateBasedOnCommand;
	EndIf;
	
	Return Undefined;
EndFunction

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See AttachableCommandsOverridable.OnDefineAttachableObjectsSettingsComposition
Procedure OnDefineAttachableObjectsSettingsComposition(InterfaceSettings4) Export
	Setting = InterfaceSettings4.Add();
	Setting.Key          = "AddGenerationCommands";
	Setting.TypeDescription = New TypeDescription("Boolean");
EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export
	
	If Not SubsystemSettings().UseInputBasedOnCommands Then
		Return;
	EndIf;
	
	Kind = AttachableCommandsKinds.Add();
	Kind.Name         = "GenerateFrom";
	Kind.SubmenuName  = "CreateBasedOnSubmenu";
	Kind.Title   = NStr("en = 'Generate';");
	Kind.Order     = 60;
	Kind.Picture    = PictureLib.InputOnBasis;
	Kind.Representation = ButtonRepresentation.Picture;
	
EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	GenerationCommands = Commands.CopyColumns();
	GenerationCommands.Columns.Add("Processed1", New TypeDescription("Boolean"));
	GenerationCommands.Indexes.Add("Processed1");
	
	StandardProcessing = Sources.Rows.Count() > 0;
	SSLSubsystemsIntegration.BeforeAddGenerationCommands(GenerationCommands, FormSettings, StandardProcessing);
	GenerateFromOverridable.BeforeAddGenerationCommands(GenerationCommands, FormSettings, StandardProcessing);
	
	GenerationCommands.FillValues(True, "Processed1");
	
	AllowedTypes = New Array; // 
	If StandardProcessing Then
		ObjectsWithCreationBasedOnCommands = ObjectsWithCreationBasedOnCommands();
		For Each Source In Sources.Rows Do
			For Each DocumentRecorder In Source.Rows Do
				AttachableCommands.SupplyTypesArray(AllowedTypes, DocumentRecorder.DataRefType);
				
				StandardProcessing = True;
				SSLSubsystemsIntegration.OnAddGenerationCommands(
					DocumentRecorder.Metadata, GenerationCommands, FormSettings, StandardProcessing);
				GenerateFromOverridable.OnAddGenerationCommands(
					DocumentRecorder.Metadata, GenerationCommands, FormSettings, StandardProcessing);
					
				If StandardProcessing And ObjectsWithCreationBasedOnCommands[DocumentRecorder.Metadata.FullName()] <> Undefined Then
					OnAddGenerationCommands(GenerationCommands, DocumentRecorder, FormSettings);
				EndIf;
			EndDo;
			
			AttachableCommands.SupplyTypesArray(AllowedTypes, Source.DataRefType);
			
			StandardProcessing = True;
			SSLSubsystemsIntegration.OnAddGenerationCommands(
				Source.Metadata, GenerationCommands, FormSettings, StandardProcessing);
			GenerateFromOverridable.OnAddGenerationCommands(
				Source.Metadata, GenerationCommands, FormSettings, StandardProcessing);
					
			If StandardProcessing And ObjectsWithCreationBasedOnCommands[Source.Metadata.FullName()] <> Undefined Then
				OnAddGenerationCommands(GenerationCommands, Source, FormSettings);
			EndIf;
		EndDo;
	EndIf;
	
	If AllowedTypes.Count() = 0 Then
		Return; // Everything is closed and there will be no extension commands with allowed types.
	EndIf;
	
	FoundItems = AttachedReportsAndDataProcessors.FindRows(New Structure("AddGenerationCommands", True));
	For Each AttachedObject In FoundItems Do
		OnAddGenerationCommands(GenerationCommands, AttachedObject, FormSettings, AllowedTypes);
	EndDo;
	
	For Each CreationBasedOnCommand In GenerationCommands Do
		Command = Commands.Add();
		FillPropertyValues(Command, CreationBasedOnCommand);
		Command.Kind = "GenerateFrom";
		If Command.Order = 0 Then
			Command.Order = 50;
		EndIf;
		If Command.WriteMode = "" Then
			Command.WriteMode = "Write";
		EndIf;
		If Command.MultipleChoice = Undefined Then
			Command.MultipleChoice = False;
		EndIf;
		If Command.FormParameters = Undefined Then
			Command.FormParameters = New Structure;
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#Region Private

// List of objects that use commands of creation on basis.
//
// Returns:
//   Array of String - names of metadata objects attached to the subsystem.
//
Function ObjectsWithCreationBasedOnCommands()
	
	Return New Map(GenerateFromCached.ObjectsWithCreationBasedOnCommands());
	
EndFunction

Procedure OnAddGenerationCommands(Commands, ObjectInfo, FormSettings, AllowedTypes = Undefined)
	ObjectInfo.Manager.AddGenerationCommands(Commands, FormSettings);
	AddedCommands = Commands.FindRows(New Structure("Processed1", False));
	For Each Command In AddedCommands Do
		If Not ValueIsFilled(Command.Manager) Then
			Command.Manager = ObjectInfo.FullName;
		EndIf;
		If Not ValueIsFilled(Command.ParameterType) Then
			Command.ParameterType = ObjectInfo.DataRefType;
		EndIf;
		If AllowedTypes <> Undefined And Not TypeInArray(Command.ParameterType, AllowedTypes) Then
			Commands.Delete(Command);
			Continue;
		EndIf;
		FoundItems = Commands.FindRows(New Structure("Processed1, Presentation", True, Command.Manager));
		If FoundItems.Count() > 0 Then
			FoundItems[0].ParameterType = MergeTypes(FoundItems[0].ParameterType, Command.ParameterType);
			Commands.Delete(Command);
			Continue;
		EndIf;
		Command.Processed1 = True;
		If Not ValueIsFilled(Command.Handler) And Not ValueIsFilled(Command.FormName) Then
			Command.FormName = "ObjectForm";
		EndIf;
		If Not ValueIsFilled(Command.FormParameterName) Then
			Command.FormParameterName = "Basis";
		EndIf;
	EndDo;
EndProcedure

Function TypeInArray(TypeOrTypeDetails, TypesArray)
	If TypeOf(TypeOrTypeDetails) = Type("TypeDescription") Then
		For Each Type In TypeOrTypeDetails.Types() Do
			If TypesArray.Find(Type) <> Undefined Then
				Return True;
			EndIf;
		EndDo;
		Return False
	Else
		Return TypesArray.Find(TypeOrTypeDetails) <> Undefined;
	EndIf;
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

Function SubsystemSettings()
	
	Settings = New Structure;
	Settings.Insert("UseInputBasedOnCommands", True);
	
	GenerateFromOverridable.OnDefineSettings(Settings);
	
	Return Settings;
	
EndFunction

// Parameters:
//  Form - ClientApplicationForm
//  CommandsKind - ValueTableRow of See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds.AttachableCommandsKinds
//  SubmenuInfoByDefault - ValueTableRow:
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
//  PlacementParameters - See AttachableCommands.PlacementParameters
//
Procedure OnOutputCommands(Form, SubmenuInfoByDefault, PlacementParameters) Export
	
	If SubmenuInfoByDefault = Undefined Then
		Return;
	EndIf;
		
	If PlacementParameters.InputOnBasisUsingAttachableCommands Then
		HideStandardInputBasedOnSubmenu(Form, SubmenuInfoByDefault);
	EndIf;
	
EndProcedure

// Parameters:
//  Form - ClientApplicationForm
//  DynamicCreationBasedOnSubmenu - See OnOutputCommands.SubmenuInfoByDefault
//
Procedure HideStandardInputBasedOnSubmenu(Form, DynamicCreationBasedOnSubmenu)
	
	CreateBasedOnSubmenu = Form.Items.Find("FormCreateBasedOn");
	If CreateBasedOnSubmenu = Undefined Then
		Return;
	EndIf;
	
	CreateBasedOnSubmenu.Visible = False;
	
	AutoGeneratedCommandsNames = New Map;
	For Each Item In ObjectsWithCreationBasedOnCommands() Do
		AutoGeneratedCommandsNames.Insert("Form" + StrReplace(Item.Key, ".", "") + "CreateBasedOn", True);
	EndDo;
	
	MovingElements = New Array;
	
	For Each Item In CreateBasedOnSubmenu.ChildItems Do
		If AutoGeneratedCommandsNames[Item.Name] = Undefined Then
			MovingElements.Add(Item);
		EndIf;
	EndDo;
	
	For Each Item In MovingElements Do
		Form.Items.Move(Item, DynamicCreationBasedOnSubmenu.Groups.Ordinary);
		DynamicCreationBasedOnSubmenu.CommandsCount = DynamicCreationBasedOnSubmenu.CommandsCount + 1;
	EndDo;
	
EndProcedure

Function ObjectsAttachedToSubsystem(Types) Export
	
	ObjectsWithCreationBasedOnCommands = ObjectsWithCreationBasedOnCommands();
	
	For Each Type In Types Do
		MetadataObject = Metadata.FindByType(Type);
		If ObjectsWithCreationBasedOnCommands[MetadataObject.FullName()] <> Undefined Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

#EndRegion
