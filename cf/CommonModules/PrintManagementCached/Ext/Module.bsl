///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

Function PrintSettings() Export
	
	Settings = PrintManagement.PrintSettings();
	
	PrintObjects = New Map;
	For Each PrintObject In Settings.PrintObjects Do
		PrintObjects.Insert(PrintObject, True);
	EndDo;
	
	Settings.PrintObjects = New FixedMap(PrintObjects);
	
	Return Settings;
	
EndFunction

Function ObjectsWithPrintCommands() Export
	
	ObjectsWithPrintCommands = New Array;
	SSLSubsystemsIntegration.OnDefineObjectsWithPrintCommands(ObjectsWithPrintCommands); // ACC:222 - A call to an obsolete procedure (for backward compatibility).
	PrintManagementOverridable.OnDefineObjectsWithPrintCommands(ObjectsWithPrintCommands); // ACC:222 - A call to an obsolete procedure (for backward compatibility).
	
	Result = New Map;
	For Each PrintObject In ObjectsWithPrintCommands Do
		Result.Insert(PrintObject, True);
	EndDo;
		
	Return New FixedMap(Result);
	
EndFunction

#EndRegion
