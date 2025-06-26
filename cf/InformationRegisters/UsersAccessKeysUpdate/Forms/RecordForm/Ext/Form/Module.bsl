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
	
	If Parameters.Key.IsEmpty() Then
		IsNewRecord = True;
		Items.UniqueKey.ReadOnly = True;
		Items.RegisterRecordChangeDate.ReadOnly = True;
		Record.JobSize = 3;
	EndIf;
	
	ReadOnly = True;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not IsNewRecord Then
		Return;
	EndIf;
	
	CurrentObject.UniqueKey = New UUID;
	CurrentObject.RegisterRecordChangeDate = CurrentSessionDate();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	IsNewRecord = False;
	
	Items.UniqueKey.ReadOnly = False;
	Items.RegisterRecordChangeDate.ReadOnly = False;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

#EndRegion
