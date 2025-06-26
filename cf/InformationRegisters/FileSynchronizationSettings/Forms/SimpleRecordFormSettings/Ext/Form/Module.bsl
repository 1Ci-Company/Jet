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
	
	Record.FileOwner = Parameters.FileOwner;
	Record.FileOwnerType = Parameters.FileOwnerType;
	Record.IsFile = Parameters.IsFile;
	
	If ValueIsFilled(Record.Account) Then
		Items.Account.ReadOnly = True;
	EndIf;
	
	OwnerPresentation = Common.SubjectString(Record.FileOwner);
	
	Title = NStr("en = 'File synchronization setting:';")
		+ " " + OwnerPresentation;
	
EndProcedure

#EndRegion