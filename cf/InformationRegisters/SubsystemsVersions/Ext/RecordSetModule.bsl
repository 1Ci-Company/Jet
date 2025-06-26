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

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	AttributesNotToCheck = New Array();
	For Each VersionRecord In ThisObject Do
		If Not IsBlankString(VersionRecord.Version) And Not IsFullVersionNumber(VersionRecord.Version) Then
			Common.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invalid version number: %1. The expected format is ""1.2.3.4"".';"), VersionRecord.Version));
			Cancel = True; 
	    	AttributesNotToCheck.Add("Version"); 
		EndIf;
	EndDo;
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, AttributesNotToCheck);
	
EndProcedure

#EndRegion

#Region Private

Function IsFullVersionNumber(Val VersionNumber)
	
	VersionParts = StrSplit(VersionNumber, ".");
	If VersionParts.Count() <> 4 Then
		Return False;	
	EndIf;
	
	NumberType = New TypeDescription("Number", New NumberQualifiers(10, 0, AllowedSign.Nonnegative));
 	For Digit = 0 To 3 Do
		VersionPart = VersionParts[Digit];
		If NumberType.AdjustValue(VersionPart) = 0 And VersionPart <> "0" Then
			Return False;
		EndIf;
	EndDo;
	Return True;
		
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf