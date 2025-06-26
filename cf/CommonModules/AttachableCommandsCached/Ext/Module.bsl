///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

Function FormCache(Val FormName, Val SourcesCommaSeparated, Val IsObjectForm) Export
	Return New FixedStructure(AttachableCommands.FormCache(FormName, SourcesCommaSeparated, IsObjectForm));
EndFunction

Function Parameters() Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	Parameters = StandardSubsystemsServer.ApplicationParameter("StandardSubsystems.AttachableCommands");
	If Parameters = Undefined Then
		AttachableCommands.ConfigurationCommonDataNonexclusiveUpdate();
		Parameters = StandardSubsystemsServer.ApplicationParameter("StandardSubsystems.AttachableCommands");
		If Parameters = Undefined Then
			Return New FixedStructure("AttachedObjects", New Map);
		EndIf;
	EndIf;
	
	If ValueIsFilled(SessionParameters.ExtensionsVersion) Then
		ExtensionParameters = StandardSubsystemsServer.ExtensionParameter(AttachableCommands.FullSubsystemName());
		If ExtensionParameters = Undefined Then
			AttachableCommands.OnFillAllExtensionParameters();
			ExtensionParameters = StandardSubsystemsServer.ExtensionParameter(AttachableCommands.FullSubsystemName());
			If ExtensionParameters = Undefined Then
				Return New FixedStructure(Parameters);
			EndIf;
		EndIf;
		SupplementMapWithArrays(Parameters.AttachedObjects, ExtensionParameters.AttachedObjects);
	EndIf;
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Return New FixedStructure(Parameters);
EndFunction

Procedure SupplementMapWithArrays(DestinationMap, SourceMap)
	For Each KeyAndValue In SourceMap Do
		DestinationArray1 = DestinationMap[KeyAndValue.Key];
		If DestinationArray1 = Undefined Then
			DestinationMap[KeyAndValue.Key] = KeyAndValue.Value;
		Else
			CommonClientServer.SupplementArray(DestinationArray1, KeyAndValue.Value, True);
		EndIf;
	EndDo;
EndProcedure

Function CommandsKinds() Export
	
	CommandsKinds = New ValueTable;
	CommandsKinds.Columns.Add("Name", New TypeDescription("String"));
	CommandsKinds.Columns.Add("SubmenuName", New TypeDescription("String"));
	CommandsKinds.Columns.Add("Title", New TypeDescription("String"));
	CommandsKinds.Columns.Add("Order", New TypeDescription("Number"));
	CommandsKinds.Columns.Add("Picture", New TypeDescription("Picture"));
	CommandsKinds.Columns.Add("Representation", New TypeDescription("ButtonRepresentation, ButtonGroupRepresentation"));
	CommandsKinds.Columns.Add("FormGroupType");
	
	ObjectsFilling.OnDefineAttachableCommandsKinds(CommandsKinds);
	GenerateFrom.OnDefineAttachableCommandsKinds(CommandsKinds);
	SSLSubsystemsIntegration.OnDefineAttachableCommandsKinds(CommandsKinds);
	AttachableCommands.OnDefineAttachableCommandsKinds(CommandsKinds);
	AttachableCommandsOverridable.OnDefineAttachableCommandsKinds(CommandsKinds);
	
	For Each CommandsKind In CommandsKinds Do
		AttachableCommands.CheckCommandsKindName(CommandsKind.Name);
		If Not ValueIsFilled(CommandsKind.SubmenuName) Then
			CommandsKind.SubmenuName = "Popup" + CommandsKind.Name;
		EndIf;
		If Not ValueIsFilled(CommandsKind.Title) Then
			CommandsKind.Title = CommandsKind.Name;
		EndIf;
	EndDo;
	
	CommandsKind = CommandsKinds.Add();
	CommandsKind.Name = "CommandBar";
	CommandsKind.SubmenuName = "";
	CommandsKind.Order = 90;
	
	CommandsKinds.Sort("Order Asc");
	
	Return CommandsKinds;
	
EndFunction

#EndRegion
