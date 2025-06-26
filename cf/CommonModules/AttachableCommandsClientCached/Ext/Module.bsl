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
Function CommandDetails(CommandName, SettingsAddress) Export
	Return AttachableCommandsServerCall.CommandDetails(CommandName, SettingsAddress);
EndFunction

#EndRegion
