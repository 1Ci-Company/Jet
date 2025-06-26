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

Function ObjectsWithCreationBasedOnCommands() Export
	
	Objects = New Array;
	SSLSubsystemsIntegration.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	GenerateFromOverridable.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	
	Result = New Map;
	For Each MetadataObject In Objects Do
		Result.Insert(MetadataObject.FullName(), True);
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

#EndRegion

