///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Populate form data.
	Server      = Parameters.Server;
	Port        = Parameters.Port;
	
	HTTPServer  = Parameters.HTTPServer;
	HTTPPort    = Parameters.HTTPPort;
	
	HTTPSServer = Parameters.HTTPSServer;
	HTTPSPort   = Parameters.HTTPSPort;
	
	FTPServer   = Parameters.FTPServer;
	FTPPort     = Parameters.FTPPort;
	
	AllProtocolsThroughSingleProxy = Parameters.AllProtocolsThroughSingleProxy;
	
	InitializeFormItems(ThisObject);
	
	For Each ExceptionListItem In Parameters.BypassProxyOnAddresses Do
		ExceptionStr = ExceptionsAddresses.Add();
		ExceptionStr.ServerAddress = ExceptionListItem.Value;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AllProtocolsThroughSingleProxyOnChange(Item)
	
	InitializeFormItems(ThisObject);
	
EndProcedure

&AtClient
Procedure HTTPServerOnChange(Item)
	
	// If the server is not specified, then reset the corresponding port.
	If IsBlankString(ThisObject[Item.Name]) Then
		ThisObject[StrReplace(Item.Name, "Server", "Port")] = 0;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OKButton(Command)
	
	If Not Modified Then
		// If the form's data is not modified, don't return it.
		// 
		NotifyChoice(Undefined);
		Return;
	EndIf;
	
	If Not ValidateExceptionServerAddresses() Then
		Return;
	EndIf;
	
	// If the check is passed, return the additional proxy settings as a structure.
	// 
	ReturnValueStructure = New Structure;
	
	ReturnValueStructure.Insert("AllProtocolsThroughSingleProxy", AllProtocolsThroughSingleProxy);
	
	ReturnValueStructure.Insert("HTTPServer" , HTTPServer);
	ReturnValueStructure.Insert("HTTPPort"   , HTTPPort);
	ReturnValueStructure.Insert("HTTPSServer", HTTPSServer);
	ReturnValueStructure.Insert("HTTPSPort"  , HTTPSPort);
	ReturnValueStructure.Insert("FTPServer"  , FTPServer);
	ReturnValueStructure.Insert("FTPPort"    , FTPPort);
	
	ExceptionsList = New ValueList;
	
	For Each AddressStr In ExceptionsAddresses Do
		If Not IsBlankString(AddressStr.ServerAddress) Then
			ExceptionsList.Add(AddressStr.ServerAddress);
		EndIf;
	EndDo;
	
	ReturnValueStructure.Insert("BypassProxyOnAddresses", ExceptionsList);
	
	NotifyChoice(ReturnValueStructure);
	
EndProcedure

#EndRegion

#Region Private

// Generates form items in accordance with
// the proxy server settings.
//
&AtClientAtServerNoContext
Procedure InitializeFormItems(Form)
	
	Form.Items.ProxyServersGroup.Enabled = Not Form.AllProtocolsThroughSingleProxy;
	If Form.AllProtocolsThroughSingleProxy Then
		
		Form.HTTPServer  = Form.Server;
		Form.HTTPPort    = Form.Port;
		
		Form.HTTPSServer = Form.Server;
		Form.HTTPSPort   = Form.Port;
		
		Form.FTPServer   = Form.Server;
		Form.FTPPort     = Form.Port;
		
	EndIf;
	
EndProcedure

// Validates the addresses of exception servers.
// Notifies a user about invalid addresses.
//
// Returns:
//   Boolean - True if the addresses are valid,
//						  otherwise False.
//
&AtClient
Function ValidateExceptionServerAddresses()
	
	AddressesAreCorrect = True;
	For Each StrAddress In ExceptionsAddresses Do
		If IsBlankString(StrAddress.ServerAddress) Then
			Continue;
		EndIf;
			
		InvalidChars = ProhibitedCharsInString(StrAddress.ServerAddress,
			"0123456789aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ_-.:*?");
		If IsBlankString(InvalidChars) Then
			Continue;
		EndIf;
		MessageText = StrReplace(NStr("en = 'The address contains illegal characters: %1';"),
			"%1", InvalidChars);
		IndexAsString = StrReplace(String(ExceptionsAddresses.IndexOf(StrAddress)), Char(160), "");
		CommonClient.MessageToUser(MessageText,	,
			"ExceptionsAddresses[" + Format(IndexAsString, "NG=0") + "].ServerAddress");
		AddressesAreCorrect = False;
	EndDo;
	
	Return AddressesAreCorrect;
	
EndFunction

// Finds illegal characters and returns them as a comma-separated string.
//
// Parameters:
//  RowToValidate - String - to check for illegal characters.
//  AllowedChars - String - allowed characters.
//
// Returns:
//   String
//
&AtClient
Function ProhibitedCharsInString(RowToValidate, AllowedChars)
	
	ProhibitedCharList = New ValueList;
	
	StringLength = StrLen(RowToValidate);
	For Iterator_SSLy = 1 To StringLength Do
		CurrentChar = Mid(RowToValidate, Iterator_SSLy, 1);
		If StrFind(AllowedChars, CurrentChar) = 0 Then
			If ProhibitedCharList.FindByValue(CurrentChar) = Undefined Then
				ProhibitedCharList.Add(CurrentChar);
			EndIf;
		EndIf;
	EndDo;
	
	ProhibitedCharString = "";
	Comma                    = False;
	
	For Each ProhibitedCharItem In ProhibitedCharList Do
		
		ProhibitedCharString = ProhibitedCharString
			+ ?(Comma, ",", "")
			+ """"
			+ ProhibitedCharItem.Value
			+ """";
		Comma = True;
		
	EndDo;
	
	Return ProhibitedCharString;
	
EndFunction

#EndRegion
