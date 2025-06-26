///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// Called when opening an assignee selection form.
// It overrides the standard selection form.
//
// Parameters:
//  PerformerItem   - FormField - a form item where an assignee is selected.
//  PerformerAttribute  - CatalogRef.Users - a previously selected assignee.
//                         Used to set the current row in the assignee selection form.
//  SimpleRolesOnly    - Boolean - If True, only roles without business objects
//                         are used in the selection.
//  NoExternalRoles      - Boolean - If True, only roles without the ExternalRole flag
//                         are used in the selection.
//  StandardProcessing - Boolean - If False, displaying the standard assignee selection form is not required.
//
Procedure OnPerformerChoice(PerformerItem, PerformerAttribute, SimpleRolesOnly,
	NoExternalRoles, StandardProcessing) Export
	
EndProcedure

#EndRegion
