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

// Gets the file from the Internet via http(s) protocol or ftp protocol and saves it at the specified path on server.
//
// Parameters:
//   URL                - String - file URL in the following format: [Protocol://]<Server>/<Path to the file on the server>.
//   ReceivingParameters - See GetFilesFromInternetClientServer.FileGettingParameters
//   WriteError1   - Boolean - if True, write file download errors to the event log.
//
// Returns:
//   Structure:
//      * Status            - Boolean - a result of receiving a file.
//      * Path   - String   - path to the file on the server. This key is used only if Status is True.
//      * ErrorMessage - String - error message if Status is False.
//      * Headers         - Map - see details of the Headers parameter of the HTTPResponse object in Syntax Assistant.
//      * StatusCode      - Number - added in case of an error.
//                                    For more information on the StateCode parameter of the HTTPResponse object, see the Syntax Assistant.
//
Function DownloadFileAtServer(Val URL, ReceivingParameters = Undefined, Val WriteError1 = True) Export
	
	SavingSetting = New Map;
	SavingSetting.Insert("StorageLocation", "Server");
	
	Return GetFilesFromInternetInternal.DownloadFile(URL,
		ReceivingParameters, SavingSetting, WriteError1);
	
EndFunction

// Gets a file from the Internet over HTTP(S) or FTP and saves it to a temporary storage.
// Note. After getting the file, clear the temporary storage
// using the DeleteFromTempStorage method. If you do not do it, the file will remain in
// the server memory until the session is over.
//
// Parameters:
//   URL                - String - file URL in the following format: [Protocol://]<Server>/<Path to the file on the server>.
//   ReceivingParameters - See GetFilesFromInternetClientServer.FileGettingParameters.
//   WriteError1   - Boolean - if True, write file download errors to the event log.
//
// Returns:
//   Structure:
//      * Status            - Boolean - a result of receiving a file.
//      * Path              - String   - an address of a temporary storage with binary file data.
//                            The key is used only if the status is True.
//      * ErrorMessage - String - error message if Status is False.
//      * Headers         - Map - see details of the Headers parameter of the HTTPResponse object in Syntax Assistant.
//      * StatusCode      - Number - added in case of an error.
//                                    For more information on the StateCode parameter of the HTTPResponse object, see the Syntax Assistant.
//
Function DownloadFileToTempStorage(Val URL, ReceivingParameters = Undefined, Val WriteError1 = True) Export
	
	SavingSetting = New Map;
	SavingSetting.Insert("StorageLocation", "TemporaryStorage");
	
	Return GetFilesFromInternetInternal.DownloadFile(URL,
		ReceivingParameters, SavingSetting, WriteError1);
	
EndFunction

// Returns the current user's proxy server settings for Internet access from
// the client.
//
// Returns:
//    Map of KeyAndValue:
//      * Key - String
//      * Value - Arbitrary
//    Keys:
//      # UseProxy - Boolean - indicates whether to use the proxy server.
//      # BypassProxyOnLocal - Boolean - indicates whether to use the proxy server for local addresses.
//      # UseSystemSettings - Boolean - indicates whether to use system settings of the proxy server.
//      # Server - String - a proxy server address.
//      # Port - Number - a proxy server port.
//      # User - String - a username to authorize on the proxy server.
//      # Password - String - a user password.
//
Function ProxySettingsAtClient() Export
	
	UserName = Undefined;
	
	If Common.FileInfobase() Then
		
		// In the file mode, scheduled jobs run on the user's computer.
		// 
		
		CurrentInfobaseSession1 = GetCurrentInfoBaseSession();
		BackgroundJob = CurrentInfobaseSession1.GetBackgroundJob();
		IsScheduledJobSession = BackgroundJob <> Undefined And BackgroundJob.ScheduledJob <> Undefined;
		
		If IsScheduledJobSession Then
			
			If Not ValueIsFilled(BackgroundJob.ScheduledJob.UserName) Then 
				
				// If a scheduled job is started on behalf of the default user, take the proxy settings
				// from the user settings saved on the computer where the session is running.
				// 
				
				Sessions = GetInfoBaseSessions(); // Array of InfoBaseSession
				For Each Session In Sessions Do 
					If Session.ComputerName = CurrentInfobaseSession1.ComputerName Then 
						UserName = Session.User.Name;
						Break;
					EndIf;
				EndDo;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Common.CommonSettingsStorageLoad("ProxyServerSetting", "",,, UserName);
	
EndFunction

// Returns the 1C:Enterprise server's proxy settings.
//
// Returns:
//   Map of KeyAndValue:
//     * Key - String
//     * Value - Arbitrary
//    Keys:
//      # UseProxy - Boolean - indicates whether to use the proxy server.
//      # BypassProxyOnLocal - Boolean - indicates whether to use the proxy server for local addresses.
//      # UseSystemSettings - Boolean - indicates whether to use system settings of the proxy server.
//      # Server - String - a proxy server address.
//      # Port - Number - a proxy server port.
//      # User - String - a username to authorize on the proxy server.
//      # Password - String - a user password.
//
Function ProxySettingsAtServer() Export
	
	If Common.FileInfobase() Then
		Return ProxySettingsAtClient();
	Else
		SetPrivilegedMode(True);
		ProxySettingsAtServer = Constants.ProxyServerSetting.Get().Get();
		Return ?(TypeOf(ProxySettingsAtServer) = Type("Map"),
			ProxySettingsAtServer,
			Undefined);
	EndIf;
	
EndFunction

// Returns InternetProxy object for Internet access.
// The following protocols are acceptable for creating InternetProxy: http, https, ftp, and ftps.
//
// Parameters:
//    URLOrProtocol - String - URL in the following format: [Protocol://]<Server>/<Path to the file on the server>,
//                              or protocol identifier (http, ftp, …).
//
// Returns:
//    InternetProxy - describes proxy server parameters for various protocols.
//                     If the network protocol scheme cannot be recognized,
//                     the proxy will be created based on the HTTP protocol.
//
Function GetProxy(Val URLOrProtocol) Export
	
	Return GetFilesFromInternetInternal.NewInternetProxy(ProxySettingsAtServer(), URLOrProtocol);
	
EndFunction

// Runs the network resource diagnostics.
// In SaaS mode, returns only an error description.
//
// Parameters:
//  URL - String - URL resource address to be diagnosed.
//  WriteError1 - Boolean - indicates whether it is necessary to write errors to the event log.
//  IsPackageDeliveryCheckEnabled - Boolean - Include a PING command to the required URL resource in the diagnostics.
//
// Returns:
//  Structure:
//    *  ErrorDescription    - String - brief error message.
//    *  DiagnosticsLog - String - a detailed log of diagnostics with technical details.
//
// Example:
//	Diagnostics of address classifier web service.
//	Result = GetFilesFromInternet.ConnectionDiagnostics("https://api.orgaddress.1c.com/orgaddress/v1?wsdl");
//	
//	ErrorDescription = Result.ErrorDescription;
//	DiagnosticsLog = Result.DiagnosticsLog;
//
Function ConnectionDiagnostics(URL, WriteError1 = True, IsPackageDeliveryCheckEnabled = True) Export
	
	LongDesc = New Array;
	LongDesc.Add(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Accessing URL: %1.';"), 
		URL));
	LongDesc.Add(GetFilesFromInternetInternal.DiagnosticsLocationPresentation());
	
	If Common.DataSeparationEnabled() Then
		LongDesc.Add(
			NStr("en = 'Please contact the administrator.';"));
		
		ErrorDescription = StrConcat(LongDesc, Chars.LF);
		
		Result = New Structure;
		Result.Insert("ErrorDescription", ErrorDescription);
		Result.Insert("DiagnosticsLog", "");
		
		Return Result;
	EndIf;
	
	Log = New Array;
	If IsPackageDeliveryCheckEnabled Then
		Log.Add(
			NStr("en = 'Diagnostics log:
			           |Server availability test.
			           |See the error description in the next log record.';"));
	Else
		Log.Add(
			NStr("en = 'Diagnostics log:
			           |Monitoring server availability test.
			           |See the error details in the next log record.';"));
	EndIf;
	Log.Add();
	
	RefStructure = CommonClientServer.URIStructure(URL);
	
	ProxySettingsState = GetFilesFromInternetInternal.ProxySettingsState(RefStructure.Schema);
	ProxyConnection = ProxySettingsState.ProxyConnection;
	Log.Add(ProxySettingsState.Presentation);
	
	If ProxyConnection And Not ProxySettingsState.SystemProxySettingsUsed Then 
		
		LongDesc.Add(
			NStr("en = 'Connection diagnostics are not performed because a proxy server is configured.
			           |Please contact the administrator.';"));
		
	Else 
		
		ResourceServerAddress = RefStructure.Host;
		VerificationServerAddress = "google.com";
		
		If Metadata.CommonModules.Find("GetFilesFromInternetInternalLocalization") <> Undefined Then
			ModuleNetworkDownloadInternalLocalization = Common.CommonModule("GetFilesFromInternetInternalLocalization");
			VerificationServerAddress = ModuleNetworkDownloadInternalLocalization.VerificationServerAddress();
		EndIf;
		
		If IsPackageDeliveryCheckEnabled Then
			ResourceAvailabilityResult = GetFilesFromInternetInternal.CheckServerAvailability(ResourceServerAddress);
			
			Log.Add();
			Log.Add("1) " + ResourceAvailabilityResult.DiagnosticsLog);
		
			If ResourceAvailabilityResult.Available Then 
				
				LongDesc.Add(StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Attempted to access a resource that does not exist on server %1,
					           |or some issues occurred on the remote server.';"),
					ResourceServerAddress));
				
			Else 
				
				VerificationResult = GetFilesFromInternetInternal.CheckServerAvailability(VerificationServerAddress);
				Log.Add("2) " + VerificationResult.DiagnosticsLog);
				
				If Not VerificationResult.Available Then
					
					LongDesc.Add(
						NStr("en = 'No Internet access. Possible reasons:
						           |- Computer is not connected to the Internet.
						           | - Internet provider issues.
						           |- Access blocked by firewall, antivirus, or other software.';"));
					
				Else 
					
					LongDesc.Add(StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Server %1 is currently unavailable. Possible reasons:
						           |- Internet provider issues.
						           |- Access blocked by firewall, antivirus, or other software.
						           |- Server is disabled or undergoing maintenance.';"),
						ResourceServerAddress));
					
					TraceLog = GetFilesFromInternetInternal.ServerRouteTraceLog(ResourceServerAddress);
					Log.Add("3) " + TraceLog);
					
				EndIf;
				
			EndIf;
		Else
			VerificationResult = GetFilesFromInternetInternal.CheckServerAvailability(VerificationServerAddress);
				Log.Add("1) " + VerificationResult.DiagnosticsLog);
				
				If Not VerificationResult.Available Then
					
					LongDesc.Add(
						NStr("en = 'No Internet access. Possible reasons:
						           |- Computer is not connected to the Internet.
						           | - Internet provider issues.
						           |- Access blocked by firewall, antivirus, or other software.';"));
					
				Else 
					
					LongDesc.Add(StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Server %1 is currently unavailable. Possible reasons:
						           |- Internet provider issues.
						           |- Access blocked by firewall, antivirus, or other software.
						           |- Server is disabled or undergoing maintenance.';"),
						ResourceServerAddress));
					
					TraceLog = GetFilesFromInternetInternal.ServerRouteTraceLog(ResourceServerAddress);
					Log.Add("2) " + TraceLog);
					
				EndIf;
		EndIf;
		
	EndIf;
	
	ErrorDescription = StrConcat(LongDesc, Chars.LF);
	
	Log.Insert(0);
	Log.Insert(0, ErrorDescription);
	
	DiagnosticsLog = StrConcat(Log, Chars.LF);
	
	If WriteError1 Then
		WriteLogEvent(
			NStr("en = 'Connection diagnostics';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, DiagnosticsLog);
	EndIf;
	
	Result = New Structure;
	Result.Insert("ErrorDescription", ErrorDescription);
	Result.Insert("DiagnosticsLog", DiagnosticsLog);
	
	Return Result;
	
EndFunction

// Defines the import timeout (in seconds) for the given file size.
// The timeout equals the file size multiplied by 128.
// If the size if unknown, then the timeout is maximum (no more than 43200).
// The minimal timeout is 30, which is required to establish a connection.
//
// Parameters:
//  Size - Number - File size in bytes.
//
// Returns:
//  Number
//
Function FileImportTimeout(Size) Export
	
	BytesInMegabyte = 1048576;
	
	Timeout = Round(Size / BytesInMegabyte * 128);
	If Timeout > 43200 Then
		Timeout = 43200;
	ElsIf Timeout < 30 Then
			Timeout = 30;
	EndIf;
	
	Return Timeout;
	
EndFunction

#EndRegion
