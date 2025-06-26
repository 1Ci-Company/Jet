///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region EventHandlers
		
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	PreviousValue = 	Constants.VolumePathIgnoreRegionalSettings.Get();
	
	If PreviousValue <> Value 
			And FilesOperationsInVolumesInternal.HasFileStorageVolumes() Then
		
		Common.MessageToUser(
			NStr("en = 'Changing a method of the volume path generation is restricted. There are files in volumes.';"),
			,,,Cancel);
	EndIf;
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf