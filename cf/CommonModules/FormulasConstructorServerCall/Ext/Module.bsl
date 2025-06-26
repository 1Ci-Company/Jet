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

Function BackgroundSearchData(Messages = Undefined) Export
	MessagesData = New Structure("DeserializedMessages");
	If Messages <> Undefined Then
		MessagesData.DeserializedMessages = DeserializedMessages(Messages);
	EndIf;
	Return MessagesData;
EndFunction

#EndRegion

#Region Private

Function DeserializedMessages(Messages)
	Result = New Array;
	For Each Message In Messages Do
		Result.Add(Common.ValueFromXMLString(Message.Text));
	EndDo;
	Return Result;
EndFunction

#EndRegion
