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

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If StrStartsWith(PredefinedDataName, "Delete") Then
		Return;
	EndIf;
	
	If Not IsFolder Then
		Result = ContactsManagerInternal.CheckContactsKindParameters(ThisObject);
		If Result.HasErrors Then
			Cancel = True;
			Raise Result.ErrorText;
		EndIf;
		
		GroupName = Catalogs.ContactInformationKinds.NameOfContactInformationTypeGroup(Parent);
		
		IDCheckForFormulas(Cancel);
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	SetScheduledJobState();
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If StrStartsWith(PredefinedDataName, "Delete") Then
		CheckedAttributes.Clear();
		Return;
	EndIf; 
	
	If Not IsFolder And EnterNumberByMask Then
		CheckedAttributes.Add("PhoneNumberMask");
	EndIf;
	
	If IsFolder Then
		
		AttributesNotToCheck = New Array;
		AttributesNotToCheck.Add("Parent");
		Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, AttributesNotToCheck);
	
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	PredefinedKindName = "";
	If Not IsFolder Then
		IDForFormulas = "";
	EndIf;
EndProcedure

#EndRegion

#Region Private

Procedure IDCheckForFormulas(Cancel)
	If Not AdditionalProperties.Property("IDCheckForFormulasCompleted") Then
		// Application record.
		If ValueIsFilled(IDForFormulas) Then
			Catalogs.ContactInformationKinds.CheckIDUniqueness(IDForFormulas,
				Ref, Parent, Cancel);
		Else
			// Set an ID.
			IDForFormulas = Catalogs.ContactInformationKinds.UUIDForFormulas(
				ContactsManager.DescriptionForIDGeneration(ThisObject), Ref, Parent);
		EndIf;
	EndIf;
EndProcedure

Procedure OnReadPresentationsAtServer() Export
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnReadPresentationsAtServer(ThisObject);
	EndIf;
	
EndProcedure

Procedure SetScheduledJobState()
	
	Status = ?(CorrectObsoleteAddresses = True, True, Undefined);
	ContactsManagerInternal.SetScheduledJobUsage(Status);
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf