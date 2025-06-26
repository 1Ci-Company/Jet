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

// Returns command details by form item name.
Function CommandDetails(CommandNameInForm, SettingsAddress) Export
	Return AttachableCommands.CommandDetails(CommandNameInForm, SettingsAddress);
EndFunction

// Analyzes the document array for posting and for rights to post them.
Function DocumentsInfo(ReferencesArrray) Export
	Result = New Structure;
	Result.Insert("Unposted", Common.CheckDocumentsPosting(ReferencesArrray));
	Result.Insert("HasRightToPost", StandardSubsystemsServer.HasRightToPost(Result.Unposted));
	Return Result;
EndFunction

#EndRegion
