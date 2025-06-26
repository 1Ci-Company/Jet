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

// Asks whether the user wants to continue the action that will discard the changes.
//
Procedure ConfirmFormClosingNow() Export
	
	CommonInternalClient.ConfirmFormClosing();
	
EndProcedure

// Asks whether the user wants to continue the action that closes the form.
//
Procedure ConfirmArbitraryFormClosingNow() Export
	
	CommonInternalClient.ConfirmArbitraryFormClosing();
	
EndProcedure

#EndRegion
