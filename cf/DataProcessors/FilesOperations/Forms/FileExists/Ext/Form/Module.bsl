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
	
	ApplyForAll = Parameters.ApplyForAll;
	MessageText   = Parameters.MessageText;
	BaseAction  = Parameters.BaseAction;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Top;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetDefaultButton1(BaseAction);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OverwriteExecute()
	
	ReturnStructure = New Structure("ApplyForAll, ReturnCode", 
		ApplyForAll, DialogReturnCode.Yes);
	Close(ReturnStructure);
	
EndProcedure

&AtClient
Procedure IgnoreExecute()
	
	ReturnStructure = New Structure("ApplyForAll, ReturnCode", 
		ApplyForAll, DialogReturnCode.Ignore);
	Close(ReturnStructure);
	
EndProcedure

&AtClient
Procedure AbortExecute()
	
	ReturnStructure = New Structure("ApplyForAll, ReturnCode", 
		ApplyForAll, DialogReturnCode.Abort);
	Close(ReturnStructure);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetDefaultButton1(DefaultAction)
	
	If DefaultAction = ""
	 Or DefaultAction = "Ignore" Then
		
		Items.Ignore.DefaultButton = True;
		
	ElsIf DefaultAction = "Yes" Then
		Items.Overwrite.DefaultButton = True;
		
	ElsIf DefaultAction = "Abort" Then
		Items.Abort.DefaultButton = True;
	EndIf;
	
EndProcedure

#EndRegion
