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

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		
		If Parameters <> Undefined And Parameters.Property("OpenByScenario") Then
			StandardProcessing = False;
			InformationKind = Parameters.ContactInformationKind;
			SelectedForm = ContactInformationInputFormName(InformationKind);
			
			If SelectedForm = Undefined Then
				Raise  StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Unprocessable address type: ""%1""';"), InformationKind);
			EndIf;
		EndIf;
		
#EndIf
	
EndProcedure

#EndRegion

#Region Private

// Returns a name of the form used to edit contact information type.
//
// Parameters:
//      InformationKind - EnumRef.ContactInformationTypes
//                    - CatalogRef.ContactInformationKinds -
//                      Requested type.
//
// Returns:
//      String - Form full name.
//
Function ContactInformationInputFormName(Val InformationKind)
	
	InformationType = ContactsManagerInternalCached.ContactInformationKindType(InformationKind);
	
	AllTypes = "Enum.ContactInformationTypes.";
	If InformationType = PredefinedValue(AllTypes + "Address") Then
		
		If Metadata.DataProcessors.Find("AdvancedContactInformationInput") = Undefined Then
			Return "DataProcessor.ContactInformationInput.Form.FreeFormAddressInput";
		Else
			Return "DataProcessor.AdvancedContactInformationInput.Form.AddressInput";
		EndIf;
		
	ElsIf InformationType = PredefinedValue(AllTypes + "Phone") Then
		Return "DataProcessor.ContactInformationInput.Form.PhoneInput";
		
	ElsIf InformationType = PredefinedValue(AllTypes + "WebPage") Then
		Return "DataProcessor.ContactInformationInput.Form.Website";
		
	ElsIf InformationType = PredefinedValue(AllTypes + "Fax") Then
		Return "DataProcessor.ContactInformationInput.Form.PhoneInput";
		
	EndIf;
	
	Return Undefined;
	
EndFunction

#EndRegion

#EndIf


