///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Not IsBlankString(Parameters.ExplanationText) Then
		Items.DecorationNote.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1
			           |Do you want to install it?';"),
			Parameters.ExplanationText);
	EndIf;
	
EndProcedure

#EndRegion