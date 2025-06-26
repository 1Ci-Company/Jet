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

// List of objects, in which the filling commands are used.
//
// Returns:
//   Array of MetadataObject - metadata objects with filling commands.
//
Function ObjectsWithFillingCommands() Export
	Array = New Array;
	ObjectsFillingOverridable.OnDefineObjectsWithFIllingCommands(Array);
	Return Array;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See AttachableCommandsOverridable.OnDefineAttachableObjectsSettingsComposition
Procedure OnDefineAttachableObjectsSettingsComposition(InterfaceSettings4) Export
	Setting = InterfaceSettings4.Add();
	Setting.Key          = "AddFillCommands";
	Setting.TypeDescription = New TypeDescription("Boolean");
EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export
	Kind = AttachableCommandsKinds.Add();
	Kind.Name         = "ObjectsFilling";
	Kind.SubmenuName  = "FillSubmenu";
	Kind.Title   = NStr("en = 'Fill';");
	Kind.Order     = 60;
	Kind.Picture    = PictureLib.FillForm;
	Kind.Representation = ButtonRepresentation.PictureAndText;
EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	FillingCommands = Commands.CopyColumns();
	FillingCommands.Columns.Add("Processed1", New TypeDescription("Boolean"));
	FillingCommands.Indexes.Add("Processed1");
	
	StandardProcessing = Sources.Rows.Count() > 0;
	ObjectsFillingOverridable.BeforeAddFillCommands(FillingCommands, FormSettings, StandardProcessing);
	FillingCommands.FillValues(True, "Processed1");
	
	AllowedTypes = New Array; // 
	If StandardProcessing Then
		ObjectsWithFillingCommands = ObjectsWithFillingCommands();
		For Each Source In Sources.Rows Do
			For Each DocumentRecorder In Source.Rows Do
				If Not DocumentRecorder.IsDocumentJournal
					And Not AccessRight("Update", DocumentRecorder.Metadata) Then
					Continue;
				EndIf;
				AttachableCommands.SupplyTypesArray(AllowedTypes, DocumentRecorder.DataRefType);
				If ObjectsWithFillingCommands.Find(DocumentRecorder.Metadata) <> Undefined Then
					OnAddFillingCommands(FillingCommands, DocumentRecorder, FormSettings);
				EndIf;
			EndDo;
			If Not Source.IsDocumentJournal
				And Not AccessRight("Update", Source.Metadata) Then
				Continue;
			EndIf;
			AttachableCommands.SupplyTypesArray(AllowedTypes, Source.DataRefType);
			If ObjectsWithFillingCommands.Find(Source.Metadata) <> Undefined Then
				OnAddFillingCommands(FillingCommands, Source, FormSettings);
			EndIf;
		EndDo;
	EndIf;
	
	If AllowedTypes.Count() = 0 Then
		Return; // Everything is closed and there will be no extension commands with allowed types.
	EndIf;
	
	FoundItems = AttachedReportsAndDataProcessors.FindRows(New Structure("AddFillCommands", True));
	For Each AttachedObject In FoundItems Do
		OnAddFillingCommands(FillingCommands, AttachedObject, FormSettings, AllowedTypes);
	EndDo;
	
	For Each FillingCommand In FillingCommands Do
		Command = Commands.Add();
		FillPropertyValues(Command, FillingCommand);
		Command.Kind = "ObjectsFilling";
		If Command.Order = 0 Then
			Command.Order = 50;
		EndIf;
		If Command.WriteMode = "" Then
			Command.WriteMode = "Write";
		EndIf;
		If FillingCommand.ChangesSelectedObjects = Undefined Then
			Command.ChangesSelectedObjects = True;
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Auxiliary for the internal

Procedure OnAddFillingCommands(Commands, ObjectInfo, FormSettings, AllowedTypes = Undefined)
	ObjectInfo.Manager.AddFillCommands(Commands, FormSettings);
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
		Command.Processed1 = True;
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

#EndRegion
