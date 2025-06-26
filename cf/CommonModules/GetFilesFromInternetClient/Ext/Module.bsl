///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// Gets the file from the Internet via http(s) protocol or ftp protocol and saves it at the specified path on client.
// Unavailable in web client. If you work in web client, use similar
// server procedures for downloading files.
//
// Parameters:
//   URL                - String - file URL in the following format: [Protocol://]<Server>/<Path to the file on the server>.
//   ReceivingParameters - See GetFilesFromInternetClientServer.FileGettingParameters.
//   WriteError1   - Boolean - if True, write file download errors to the event log.
//
// Returns:
//   Structure - information on a received file:
//      * Status            - Boolean - True if a file is successfully received.
//      * Path              - String - path to the file on the client. This key is used only if Status is True.
//      * ErrorMessage - String - error message if Status is False.
//      * Headers         - Map - see details of the Headers parameter of the HTTPResponse object in Syntax Assistant.
//      * StatusCode      - Number - added in case of an error.
//                                    For more information on the StateCode parameter of the HTTPResponse object, see the Syntax Assistant.
//
Function DownloadFileAtClient(Val URL, Val ReceivingParameters = Undefined, Val WriteError1 = True) Export
	
#If WebClient Then
	Raise NStr("en = 'Cannot download files in the web client.';");
#Else
	
	Result = GetFilesFromInternetInternalServerCall.DownloadFile(URL, ReceivingParameters, WriteError1);
	
	If ReceivingParameters <> Undefined
		And ReceivingParameters.PathForSaving <> Undefined Then
		
		PathForSaving = ReceivingParameters.PathForSaving;
	Else
		PathForSaving = GetTempFileName(); // ACC:441 The temporary file must be deleted by the calling code.
	EndIf;
	
	If Result.Status Then
		// ACC:1348-off FileSystemClient.SaveFiles is not used for compatibility (synchronous call).
		GetFile(Result.Path, PathForSaving, False); 
		// ACC:1348-on
		Result.Path = PathForSaving;
	EndIf;
	
	Return Result;
	
#EndIf
	
EndFunction

// Opens a proxy server parameters form.
//
// Parameters:
//    FormParameters - Structure - parameters of the form to be opened.
//
Procedure OpenProxyServerParametersForm(FormParameters = Undefined) Export
	
	OpenForm("CommonForm.ProxyServerParameters", FormParameters);
	
EndProcedure

#EndRegion
