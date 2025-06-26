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
	
	ForExternalUser = Parameters.ForExternalUser;
	NewPassword = NewPassword(ForExternalUser);
	
	If Common.IsMobileClient() Then
		Items.FormClose.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateAnotherOne(Command)
	
	NewPassword = NewPassword(ForExternalUser);
	
EndProcedure

&AtServerNoContext
Function NewPassword(ForExternalUser)
	
	PasswordProperties = Users.PasswordProperties();
	PasswordProperties.MinLength = 8;
	PasswordProperties.Complicated = True;
	PasswordProperties.ConsiderSettings = ?(ForExternalUser, "ForExternalUsers", "ForUsers");
	
	Return Users.CreatePassword(PasswordProperties);
	
EndFunction

#EndRegion
