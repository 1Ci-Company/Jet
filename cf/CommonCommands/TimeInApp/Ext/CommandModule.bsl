///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	AdditionalInformation = AdditionalInformation();
	ShowMessageBox(,
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'App time: %1
				|Server time: %2
				|Client time: %3
				|
				|The app time is the server time converted to the device''s time zone
				|(%4).
				|This time is used in timestamps when saving documents and other objects.';"),
			Format(CommonClient.SessionDate(), "DLF=T"),
			Format(AdditionalInformation.ServerDate, "DLF=T"),
			Format(CurrentDate(), "DLF=T"), // ACC:143 - An example of CurrentDate call for determining the computer time
			AdditionalInformation.TimeZonePresentation));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function AdditionalInformation()
	Result = New Structure;
	Result.Insert("TimeZonePresentation", TimeZonePresentation(SessionTimeZone()));
	Result.Insert("ServerDate", CurrentDate()); // ACC:143 - CurrentDate is called to get the server time.
	Return Result;
EndFunction

#EndRegion