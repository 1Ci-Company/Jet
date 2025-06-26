///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

Function PictureByName(IconName) Export
	
	Return PictureLib[IconName];	
	
EndFunction   

Function EnumsMetadata() Export 
	
	TypesArray = New Array;
	
	For Each EnumerationMetadata In Metadata.Enums Do
		TypesArray.Add(EnumerationMetadata);
	EndDo;   
	
	Return New FixedArray(TypesArray);
	
EndFunction

#EndRegion