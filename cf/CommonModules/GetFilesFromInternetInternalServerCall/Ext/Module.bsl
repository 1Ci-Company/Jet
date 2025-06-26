///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

#Region DownloadFileAtClient

Function DownloadFile(URL, ReceivingParameters, WriteError1) Export
	
	SavingSetting = New Map;
	SavingSetting.Insert("StorageLocation", "TemporaryStorage");
	
	Return GetFilesFromInternetInternal.DownloadFile(
		URL, ReceivingParameters, SavingSetting, WriteError1);
	
EndFunction

#EndRegion

#Region ObsoleteProceduresAndFunctions

Function ProxySettingsState() Export
	
	Return GetFilesFromInternetInternal.ProxySettingsState();
	
EndFunction

#EndRegion

#EndRegion
