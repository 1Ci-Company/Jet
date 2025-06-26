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

#Region Private

Procedure Refresh() Export
	
	CurrentValue = Constants.UseExternalUserGroups.Get();
	ComputedValue = ComputedValue();
	
	If CurrentValue <> ComputedValue Then
		Constants.UseExternalUserGroups.Set(ComputedValue);
	EndIf;
	
EndProcedure

Function ComputedValue() Export
	
	Return Constants.UseExternalUsers.Get()
	      And Constants.UseUserGroups.Get();
	
EndFunction

#EndRegion

#EndIf