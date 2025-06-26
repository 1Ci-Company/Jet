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

// Returns a map of metadata objects and command interface subsystems.
//
// Returns: 
//  Map of KeyAndValue:
//    * Key - String - full object name.
//    * Value - Array of String - full names of the command interface subsystems
//                                    the object belongs to.
//
Function ObjectsBelongingToCommandInterfaceSections() Export
	
	ObjectsAndSubsystemsMap = New Map;
	
	For Each Subsystem In Metadata.Subsystems Do
		If Not Subsystem.IncludeInCommandInterface
			Or Not AccessRight("View", Subsystem)
			Or Not Common.MetadataObjectAvailableByFunctionalOptions(Subsystem) Then
			Continue;
		EndIf;
		
		For Each Object In Subsystem.Content Do
			ObjectSubsystems = ObjectsAndSubsystemsMap[Object.FullName()];
			If ObjectSubsystems = Undefined Then
				ObjectSubsystems = New Array;
			ElsIf ObjectSubsystems.Find(Subsystem.FullName()) <> Undefined Then
				Continue;
			EndIf;
			ObjectSubsystems.Add(Subsystem.FullName());
			ObjectsAndSubsystemsMap.Insert(Object.FullName(), ObjectSubsystems);
		EndDo;
		
		AddSubordinateSubsystemsObjects(Subsystem, ObjectsAndSubsystemsMap);
	EndDo;
	
	Return New FixedMap(ObjectsAndSubsystemsMap);
	
EndFunction

#EndRegion

#Region Private

// For internal use only.
//
Procedure AddSubordinateSubsystemsObjects(FirstLevelSubsystem, ObjectsAndSubsystemsMap, SubsystemParent = Undefined)
	
	Subsystems = ?(SubsystemParent = Undefined, FirstLevelSubsystem, SubsystemParent);
	
	For Each Subsystem In Subsystems.Subsystems Do
		If Subsystem.IncludeInCommandInterface
			And AccessRight("View", Subsystem)
			And Common.MetadataObjectAvailableByFunctionalOptions(Subsystem) Then
			
			For Each Object In Subsystem.Content Do
				ObjectSubsystems = ObjectsAndSubsystemsMap[Object.FullName()];
				If ObjectSubsystems = Undefined Then
					ObjectSubsystems = New Array;
				ElsIf ObjectSubsystems.Find(FirstLevelSubsystem.FullName()) <> Undefined Then
					Continue;
				EndIf;
				ObjectSubsystems.Add(FirstLevelSubsystem.FullName());
				ObjectsAndSubsystemsMap.Insert(Object.FullName(), ObjectSubsystems);
			EndDo;
			
			AddSubordinateSubsystemsObjects(FirstLevelSubsystem, ObjectsAndSubsystemsMap, Subsystem);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion