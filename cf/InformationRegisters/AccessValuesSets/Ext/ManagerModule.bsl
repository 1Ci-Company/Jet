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

#Region Internal

// The procedure updates register cache attributes based on the result of changing the content
// of value types and access value groups.
//
Procedure UpdateAuxiliaryRegisterDataByConfigurationChanges1() Export
	
	SetPrivilegedMode(True);
	
	If Constants.LimitAccessAtRecordLevel.Get() Then
		AccessManagementInternal.SetDataFillingForAccessRestriction(True);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// The procedure updates the register data during the full update of auxiliary data.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	AccessManagementInternal.CheckWhetherTheMetadataIsUpToDate();
	
	DataVolume = 1;
	While DataVolume > 0 Do
		DataVolume = 0;
		AccessManagementInternal.DataFillingForAccessRestriction(DataVolume, True, HasChanges);
	EndDo;
	
	ObjectsTypes = AccessManagementInternalCached.ObjectsTypesInSubscriptionsToEvents(
		"WriteAccessValuesSets");
	
	For Each TypeDetails In ObjectsTypes Do
		Type = TypeDetails.Key;
		
		If Type = Type("String") Then
			Continue;
		EndIf;
		
		Selection = Common.ObjectManagerByFullName(Metadata.FindByType(Type).FullName()).Select();
		
		While Selection.Next() Do
			AccessManagementInternal.UpdateAccessValuesSets(Selection.Ref, HasChanges);
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
