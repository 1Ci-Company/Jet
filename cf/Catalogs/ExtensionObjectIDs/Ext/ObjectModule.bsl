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

#If Not MobileStandaloneServer Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	// The DataExchange.Import check is performed in the nested procedure.
	Catalogs.MetadataObjectIDs.BeforeWriteObject(ThisObject);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	// The "DataExchange.Import" check is performed in the nested procedure.
	Catalogs.MetadataObjectIDs.AtObjectWriting(ThisObject);
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	// The DataExchange.Import check is performed in the nested procedure.
	Catalogs.MetadataObjectIDs.BeforeDeleteObject(ThisObject);
	
EndProcedure

#EndRegion

#EndIf

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf