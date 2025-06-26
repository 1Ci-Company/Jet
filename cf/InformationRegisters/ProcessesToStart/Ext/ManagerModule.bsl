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

// Adds information about successful process start.
//
// Parameters:
//   - BusinessProcess - BusinessProcessRef.
//
Procedure RegisterProcessStart(Process_) Export
	
	Record = CreateRecordManager();
	Record.Owner = Process_;
	Record.Read();
	
	If Not Record.Selected() Then
		Return;
	EndIf;
	
	Record.Delete();
	
EndProcedure

// Adds information about process start cancellation.
//
// Parameters:
//   - BusinessProcess - BusinessProcessRef.
//
Procedure RegisterStartCancellation(Process_, CancellationReason) Export
	
	Record = CreateRecordManager();
	Record.Owner = Process_;
	Record.Read();
	
	If Not Record.Selected() Then
		Return;
	EndIf;
	
	Record.State = Enums.ProcessesStatesForStart.StartCanceled;
	Record.StartCancelReason = CancellationReason;
	
	Record.Write();
	
EndProcedure

#EndRegion

#EndIf