///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region EventHandlers

&AtClient
Procedure CommandProcessing(ObjectReference, CommandExecuteParameters)
	
	If ObjectReference = Undefined Then 
		Return;
	EndIf;
	
	FormParameters = New Structure("ObjectReference", ObjectReference);
	OpenForm("CommonForm.ObjectsRightsSettings", FormParameters, CommandExecuteParameters.Source);
	
EndProcedure

#EndRegion
