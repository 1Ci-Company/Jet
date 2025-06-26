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

#Region Variables

// 
Var PreviousValue2;

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	PreviousValue2 = Constants.LimitAccessAtRecordLevel.Get();
	
	If Value = PreviousValue2 Then
		Return;
	EndIf;
	
	If Common.IsStandaloneWorkplace() Then
		ErrorText =
			NStr("en = 'To update RLS access restrictions, go to the app in the service.';");
		Raise ErrorText;
		
	ElsIf Common.IsSubordinateDIBNode() Then
		ErrorText =
			NStr("en = 'RLS access restrictions can only be changed in the master node.';");
		Raise ErrorText;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Value <> PreviousValue2 Then
		RefreshReusableValues();
		Try
			AccessManagementInternal.OnChangeAccessRestrictionAtRecordLevel(
				Not PreviousValue2 And Value);
		Except
			RefreshReusableValues();
			Raise;
		EndTry;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// For internal use only.
Procedure RegisterChangeUponDataImport(DataElement) Export
	
	If DataElement.Value = Constants.LimitAccessAtRecordLevel.Get() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	UsersInternal.RegisterRefs("LimitAccessAtRecordLevel", True);
	
EndProcedure

// For internal use only.
Procedure ProcessChangeRegisteredUponDataImport() Export
	
	If Common.DataSeparationEnabled() Then
		// Right settings changes in SWP are locked and cannot be imported into the data area.
		Return;
	EndIf;
	
	Changes = UsersInternal.RegisteredRefs("LimitAccessAtRecordLevel");
	If Changes.Count() = 0 Then
		Return;
	EndIf;
	
	AccessManagementInternal.OnChangeAccessRestrictionAtRecordLevel(
		Constants.LimitAccessAtRecordLevel.Get());
	
	UsersInternal.RegisterRefs("LimitAccessAtRecordLevel", Null);
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf