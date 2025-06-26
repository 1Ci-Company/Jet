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
	
	If Parameters.Filter.Property("Owner") Then
		
		If Not Interactions.UserIsResponsibleForMaintainingFolders(Parameters.Filter.Owner) Then
			
			ReadOnly = True;
			
		EndIf;
		
	Else
		
		Cancel = True;
		
	EndIf;
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "Owner", Catalogs.EmailAccounts.EmptyRef(),
		DataCompositionComparisonType.Equal, , False);
EndProcedure

#EndRegion
