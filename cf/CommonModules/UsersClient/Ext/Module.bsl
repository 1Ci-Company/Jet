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

// See Users.AuthorizedUser.
Function AuthorizedUser() Export
	
	Return StandardSubsystemsClient.ClientParameter("AuthorizedUser");
	
EndFunction

// See Users.CurrentUser.
Function CurrentUser() Export
	
	Return UsersInternalClientServer.CurrentUser(AuthorizedUser());
	
EndFunction

// See Users.IsExternalUserSession.
Function IsExternalUserSession() Export
	
	Return StandardSubsystemsClient.ClientParameter("IsExternalUserSession");
	
EndFunction

// Checks whether the current infobase user has full access rights.
// 
// Parameters:
//  CheckSystemAdministrationRights - See Users.IsFullUser.CheckSystemAdministrationRights
//
// Returns:
//  Boolean - If "True", the user has full access rights.
//
Function IsFullUser(CheckSystemAdministrationRights = False) Export
	
	If CheckSystemAdministrationRights Then
		Return StandardSubsystemsClient.ClientParameter("IsSystemAdministrator");
	Else
		Return StandardSubsystemsClient.ClientParameter("IsFullUser");
	EndIf;
	
EndFunction

#EndRegion
