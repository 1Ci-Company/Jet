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
	If AdditionalProperties.Property("PredefinedObjectsFilling") Then
		CheckPredefinedReportOptionFilling(Cancel);
	EndIf;
	If DataExchange.Load Then
		Return;
	EndIf;
	If Not AdditionalProperties.Property("PredefinedObjectsFilling") Then
		Raise NStr("en = 'Predefined report options catalog is modified only during automatic population.';tr = '""Öntanımlı rapor seçenekleri"" kataloğu sadece veriler otomatik doldurulduğunda değiştirilir.'");
	EndIf;
EndProcedure

// Basic validation of predefined report options.
Procedure CheckPredefinedReportOptionFilling(Cancel)
	If DeletionMark Then
		Return;
	EndIf;
	If Not ValueIsFilled(Report) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Field %1 is required.';tr = '""%1"" alanı doldurulmadı'"), "Report");
	EndIf;
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';tr = 'İstemcide geçersiz nesne çağrısı.'");
#EndIf