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

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddClientParameters.
Procedure OnAddClientParameters(Parameters) Export
	
	Parameters.Insert("ProxyServerSettings", GetFilesFromInternet.ProxySettingsAtClient());
	
EndProcedure

// See SafeModeManagerOverridable.OnEnableSecurityProfiles.
Procedure OnEnableSecurityProfiles() Export
	
	// Reset proxy settings to default condition.
	SaveServerProxySettings(Undefined);
	
	WriteLogEvent(EventLogEvent(),
		EventLogLevel.Warning, Metadata.Constants.ProxyServerSetting,,
		NStr("en = 'Since a security profile is enabled, the proxy server settings are reverted to the default ones.';"));
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources.
Procedure OnFillPermissionsToAccessExternalResources(PermissionsRequests) Export
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	Permissions = New Array();
	
	// Permissions for running the procedures "GetFilesFromInternetInternal.CheckServerAvailability"
	// and "GetFilesFromInternetInternal.ServerRouteTraceLog".
	If Common.IsWindowsServer() Then
		Permissions.Add(ModuleSafeModeManager.PermissionToUseOperatingSystemApplications("cmd /S /C ""%(ping %)%""",
			NStr("en = 'Permission for ping';", Common.DefaultLanguageCode())));
		Permissions.Add(ModuleSafeModeManager.PermissionToUseOperatingSystemApplications("cmd /S /C ""%(tracert %)%""",
			NStr("en = 'Permission for tracert.';", Common.DefaultLanguageCode())));
	ElsIf Common.IsLinuxServer() Then
		Permissions.Add(ModuleSafeModeManager.PermissionToUseOperatingSystemApplications("ping % % % % %",
			NStr("en = 'Permission for ping';", Common.DefaultLanguageCode())));
		Permissions.Add(ModuleSafeModeManager.PermissionToUseOperatingSystemApplications("traceroute % % % % %",
			NStr("en = 'Permission for traceroute.';", Common.DefaultLanguageCode())));
	EndIf;
	
	PermissionsRequests.Add(
		ModuleSafeModeManager.RequestToUseExternalResources(Permissions));
	
EndProcedure


#EndRegion

#Region Private

#Region Proxy

// Saves proxy server setting parameters on the 1C:Enterprise server side.
//
Procedure SaveServerProxySettings(Val Settings) Export
	
	If Not Users.IsFullUser(, True) Then
		Raise(NStr("en = 'Insufficient rights to perform the operation.';"), ErrorCategory.AccessViolation);
	EndIf;
	
	SetPrivilegedMode(True);
	Constants.ProxyServerSetting.Set(New ValueStorage(Settings));
	
EndProcedure

#EndRegion

#Region DownloadFile

#If Not WebClient Then

// function meant for getting files from the Internet
//
// Parameters:
//   URL           - String - file url.
//   ReceivingParameters   - Structure:
//    * PathForSaving            - String - path on the server (including file name) for saving the downloaded file.
//    * User                 - String - a user that established the connection.
//    * Password                       - String - the password of the user that established the connection.
//    * Port                         - Number  - a port used for connecting to the server.
//    * Timeout                      - Number  - the file download timeout, in seconds.
//    * SecureConnection         - Boolean - in case of http download the flag shows
//                                             that the connection must be established via https.
//    * PassiveConnection          - Boolean - in case of ftp download the flag shows
//                                             that the connection must be passive (or active).
//    * Headers                    - Map - see the details of the Headers parameter of the HTTPRequest object.
//    * UseOSAuthentication - Boolean - see the details of the UseOSAuthentication parameter of the HTTPConnection object.
//    * IsPackageDeliveryCheckOnErrorEnabled - See GetFilesFromInternet.ConnectionDiagnostics.IsPackageDeliveryCheckEnabled.
//    
//
//   SavingSetting - Map - contains parameters to save the downloaded file. Keys:
//                 StorageLocation - String - can include
//                        "Server" - server,
//                        "TemporaryStorage" - temporary storage.
//                 Path - String (optional parameter) -
//                        path to folder at client or at server or temporary storage address will be generated
//                        if not specified.
//   WriteError1 - Boolean                     
//
// Returns:
//   Structure:
//      * Status - Boolean
//      * Path   - String
//      * ErrorMessage - String
//      * Headers         - Map
//      * StatusCode      - Number
//
Function DownloadFile(Val URL, Val ReceivingParameters, Val SavingSetting, Val WriteError1 = True) Export
	
	ReceivingSettings = GetFilesFromInternetClientServer.FileGettingParameters();
	If ReceivingParameters <> Undefined Then
		FillPropertyValues(ReceivingSettings, ReceivingParameters);
	EndIf;
	
	If SavingSetting.Get("StorageLocation") <> "TemporaryStorage" Then
		SavingSetting.Insert("Path", ReceivingSettings.PathForSaving);
	EndIf;
	
	ProxyServerSetting = GetFilesFromInternet.ProxySettingsAtServer();
	
	Redirections = New Array;
	
	Return GetFileFromInternet(URL, SavingSetting, ReceivingSettings,
		ProxyServerSetting, WriteError1, Redirections);
	
EndFunction

// function meant for getting files from the Internet
//
// Parameters:
//   URL - String - file URL in the following format: [Protocol://]<Server>/<Path to the file on the server>.
//   
// SavingSetting - Map - contains parameters to save the downloaded file.
//		StorageLocation - String - Valid values are
//			"Server" - A server.
//			"TemporaryStorage" - A temporary storage.
//		Path - String - (Optional) Either the path to a folder at the client or at the server
//			or the address in a temporary storage. If not specified, it will be generated automatically.
//
// ConnectionSetting - Map -
//		SecureConnection* - Boolean - Secure connection.
//		PassiveConnection* - Boolean - Secure connection.
//		User - String - User that established the connection.
//		Password - String - Password of the user that established the connection.
//		Port - Number - Port used for connecting to the server.
//		... - See GetFilesFromInternet.ConnectionDiagnostics.IsPackageDeliveryCheckEnabled
//		* - Mutually exclusive keys.
//
// ProxySettings - Map of KeyAndValue:
//     * Key - String
//     * Value - Arbitrary
//    Keys are:
//		# UseProxy - Boolean - Indicates whether to use the proxy server.
//		# BypassProxyOnLocal - Boolean - Indicates whether to use the proxy server for local addresses.
//		# UseSystemSettings - Boolean - Indicates whether to use the system settings of the proxy server.
//		# Server - String - a proxy server address.
//		# Port - Number - Proxy server port.
//		# User - String - Username for authorization on the proxy server.
//		# Password - String - User password.
//		
//
//
// Returns:
//   Structure:
//      * Status - Boolean
//      * Path   - String
//      * ErrorMessage - String
//      * Headers         - Map
//      * StatusCode      - Number
//
Function GetFileFromInternet(Val URL, Val SavingSetting, Val ConnectionSetting,
	Val ProxySettings, Val WriteError1, Redirections = Undefined)
	
	URIStructure = CommonClientServer.URIStructure(URL);
	
	Server        = URIStructure.Host;
	PathAtServer = URIStructure.PathAtServer;
	Protocol      = URIStructure.Schema;
	
	If IsBlankString(Protocol) Then 
		Protocol = "http";
	EndIf;
	
	SecureConnection = ConnectionSetting.SecureConnection;
	UserName      = ConnectionSetting.User;
	UserPassword   = ConnectionSetting.Password;
	Port                 = ConnectionSetting.Port;
	Timeout              = ConnectionSetting.Timeout;
	IsPackageDeliveryCheckOnErrorEnabled = ConnectionSetting.IsPackageDeliveryCheckOnErrorEnabled;
	
	If (Protocol = "https" Or Protocol = "ftps") And SecureConnection = Undefined Then
		SecureConnection = True;
	EndIf;
	
	If SecureConnection = True Then
		SecureConnection = CommonClientServer.NewSecureConnection();
	ElsIf SecureConnection = False Then
		SecureConnection = Undefined;
		// Otherwise the SecureConnection parameter was specified explicitly.
	EndIf;
	
	If Port = Undefined Then
		Port = URIStructure.Port;
	EndIf;
	
	If ProxySettings = Undefined Then 
		Proxy = Undefined;
	Else 
		Proxy = NewInternetProxy(ProxySettings, Protocol);
	EndIf;
	
	If SavingSetting["Path"] <> Undefined Then
		PathForSaving = SavingSetting["Path"];
	Else
		PathForSaving = GetTempFileName(); // ACC:441 The temporary file must be deleted by the calling code.
	EndIf;
	
	If Timeout = Undefined Then 
		Timeout = GetFilesFromInternetClientServer.AutomaticTimeoutDetermination();
	EndIf;
	
	FTPProtocolISUsed = (Protocol = "ftp" Or Protocol = "ftps");
	
	If FTPProtocolISUsed Then
		
		PassiveConnection                       = ConnectionSetting.PassiveConnection;
		SecureConnectionUsageLevel = ConnectionSetting.SecureConnectionUsageLevel;
		
		Try
			
			If Timeout = GetFilesFromInternetClientServer.AutomaticTimeoutDetermination() Then
				
				Join = New FTPConnection(
					Server, 
					Port, 
					UserName, 
					UserPassword,
					Proxy, 
					PassiveConnection, 
					7, 
					SecureConnection, 
					SecureConnectionUsageLevel);
				
				FileSize = FTPFileSize1(Join, PathAtServer);
				Timeout = GetFilesFromInternet.FileImportTimeout(FileSize);
				
			EndIf;
			
			Join = New FTPConnection(
				Server, 
				Port, 
				UserName, 
				UserPassword,
				Proxy, 
				PassiveConnection, 
				Timeout, 
				SecureConnection, 
				SecureConnectionUsageLevel);
			
			Server = Join.Host;
			Port   = Join.Port;
			
			Join.Get(PathAtServer, PathForSaving);
			
		Except
			
			DiagnosticsResult = GetFilesFromInternet.ConnectionDiagnostics(URL, WriteError1, 
				IsPackageDeliveryCheckOnErrorEnabled);
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot get file %1 from server %2:%3.
				           |Reason:
				           |%4
				           |Diagnostics result:
				           |%5';"),
				URL, Server, Format(Port, "NG="),
				ErrorProcessing.BriefErrorDescription(ErrorInfo()),
				DiagnosticsResult.ErrorDescription);
				
			If WriteError1 Then
				ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1
					           |
					           |Trace parameters:
					           |Secure connection: %2
					           |Timeout: %3';"),
					ErrorText,
					Format(Join.SecureConnection <> Undefined, NStr("en = 'BF=No; BT=Yes';")),
					Format(Join.Timeout, "NG=0"));
					
				WriteErrorToEventLog(ErrorMessage);
			EndIf;
			
			Return FileGetResult(False, ErrorText);
			
		EndTry;
		
	Else // HTTP protocol is used.
		
		Headers                    = ConnectionSetting.Headers;
		UseOSAuthentication = ConnectionSetting.UseOSAuthentication;
		
		Try
			
			If Timeout = GetFilesFromInternetClientServer.AutomaticTimeoutDetermination() Then
				
				Join = New HTTPConnection(
					Server, 
					Port, 
					UserName, 
					UserPassword,
					Proxy, 
					7, 
					SecureConnection, 
					UseOSAuthentication);
				
				FileSize = HTTPFileSize(Join, PathAtServer, Headers);
				Timeout = GetFilesFromInternet.FileImportTimeout(FileSize);
				
			EndIf;
			
			Join = New HTTPConnection(
				Server, 
				Port, 
				UserName, 
				UserPassword,
				Proxy, 
				Timeout, 
				SecureConnection, 
				UseOSAuthentication);
			
			Server = Join.Host;
			Port   = Join.Port;
			
			HTTPRequest = New HTTPRequest(PathAtServer, Headers);
			HTTPRequest.Headers.Insert("Accept-Charset", "UTF-8");
			HTTPRequest.Headers.Insert("X-1C-Request-UID", String(New UUID));
			HTTPResponse = Join.Get(HTTPRequest, PathForSaving);
			
		Except
			
			DiagnosticsResult = GetFilesFromInternet.ConnectionDiagnostics(URL, WriteError1,
				IsPackageDeliveryCheckOnErrorEnabled);
			
			ErrorTemplate = NStr("en = 'Cannot establish HTTP connection to server %1:%2.
				|Reason:
				|%3
				|
				|Diagnostics result:
				|%4';");
			
			RedirectionPresentations = RedirectionPresentations(Redirections);
			If Not IsBlankString(RedirectionPresentations) Then
				ErrorTemplate = ErrorTemplate + Chars.LF + Chars.LF + RedirectionPresentations;
			EndIf;
			
			If WriteError1 Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
					Server, Format(Port, "NG="),
					ErrorProcessing.DetailErrorDescription(ErrorInfo()),
					DiagnosticsResult.ErrorDescription);
				WriteErrorToEventLog(ErrorText);
			EndIf;
				
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
				Server, Format(Port, "NG="),
				ErrorProcessing.BriefErrorDescription(ErrorInfo()),
				DiagnosticsResult.ErrorDescription);
			Return FileGetResult(False, ErrorText);
			
		EndTry;
		
		Try
			
			If HTTPResponse.StatusCode = 301 // 301 Moved Permanently
				Or HTTPResponse.StatusCode = 302 // 302 Found, 302 Moved Temporarily
				Or HTTPResponse.StatusCode = 303 // 303 See Other by GET
				Or HTTPResponse.StatusCode = 307 // 307 Temporary Redirect
				Or HTTPResponse.StatusCode = 308 Then // 308 Permanent Redirect
				
				If Redirections.Count() > 7 Then
					Raise(NStr("en = 'Redirections limit exceeded.';"), ErrorCategory.NetworkError);
				EndIf;
					
				NewURL1 = StandardSubsystemsServer.HTTPHeadersInLowercase(HTTPResponse.Headers)["location"];
				If NewURL1 = Undefined Then 
					Raise(NStr("en = 'Invalid redirection: no ""Location"" header in the HTTP response.';"),
						ErrorCategory.NetworkError);
				EndIf;
				
				NewURL1 = TrimAll(NewURL1);
				If IsBlankString(NewURL1) Then
					Raise(NStr("en = 'Invalid redirection: blank ""Location"" header in the HTTP response.';"),
						ErrorCategory.NetworkError);
				EndIf;
				
				If Redirections.Find(NewURL1) <> Undefined Then
					Raise(StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Circular redirect.
									|Redirect to %1 was attempted earlier.';"),
						NewURL1),
						ErrorCategory.NetworkError);
				EndIf;
				
				Redirections.Add(URL);
				If Not StrStartsWith(NewURL1, "http") Then
					// <scheme>://<host>:<port>/<path>
					NewURL1 = StringFunctionsClientServer.SubstituteParametersToString(
						"%1://%2:%3/%4", Protocol, Server, Format(Port, "NG="), NewURL1);
				EndIf;
				
				Return GetFileFromInternet(NewURL1, SavingSetting, ConnectionSetting,
					ProxySettings, WriteError1, Redirections);
				
			EndIf;
			
			If HTTPResponse.StatusCode < 200 Or HTTPResponse.StatusCode >= 300 Then
				
				If HTTPResponse.StatusCode = 304 Then
					
					HTTPHeaders = StandardSubsystemsServer.HTTPHeadersInLowercase(HTTPRequest.Headers);
					If (HTTPHeaders["if-modified-since"] <> Undefined Or HTTPHeaders["if-none-match"] <> Undefined) Then
						WriteError1 = False;
					EndIf;
					
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Web server response has not changed since your last request:
						           |%1';"),
						HTTPConnectionCodeDetails(HTTPResponse.StatusCode));
					
					AddServerResponseBody(PathForSaving, ErrorText);
					Raise(ErrorText, ErrorCategory.NetworkError);
					
				ElsIf HTTPResponse.StatusCode < 200
					Or HTTPResponse.StatusCode >= 300 And HTTPResponse.StatusCode < 400 Then
					
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Unsupported web server response:
						           |%1';"),
						HTTPConnectionCodeDetails(HTTPResponse.StatusCode));
					
					AddServerResponseBody(PathForSaving, ErrorText);
					Raise(ErrorText, ErrorCategory.NetworkError);
					
				ElsIf HTTPResponse.StatusCode >= 400 And HTTPResponse.StatusCode < 500 Then 
					
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Web server request failed:
						           |%1';"),
						HTTPConnectionCodeDetails(HTTPResponse.StatusCode));
					
					AddServerResponseBody(PathForSaving, ErrorText);
					Raise(ErrorText, ErrorCategory.NetworkError);
					
				Else 
					
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Web server is overwhelmed, disconnected, or under maintenance:
						           |%1';"),
						HTTPConnectionCodeDetails(HTTPResponse.StatusCode));
					
					AddServerResponseBody(PathForSaving, ErrorText);
					Raise(ErrorText, ErrorCategory.NetworkError);
					
				EndIf;
				
			EndIf;
			
		Except
			
			ErrorTemplate = NStr("en = 'Cannot get file %1 from server %2.%3
				|Reason:
				|%4';");
			
			RedirectionPresentations = RedirectionPresentations(Redirections);
			If Not IsBlankString(RedirectionPresentations) Then
				ErrorTemplate = ErrorTemplate + Chars.LF + Chars.LF + RedirectionPresentations;
			EndIf;
				
			If WriteError1 Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
					URL, Server, Format(Port, "NG="),
					ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1
					           |
					           |Trace parameters:
					           |Secure connection: %2
					           |Timeout: %3
					           |OS authentication: %4';"),
					ErrorText,
					Format(Join.SecureConnection <> Undefined, NStr("en = 'BF=No; BT=Yes';")),
					Format(Join.Timeout, "NG=0"),
					Format(Join.UseOSAuthentication, NStr("en = 'BF=No; BT=Yes';")));
				
				AddHTTPHeaders(HTTPRequest, ErrorMessage);
				AddHTTPHeaders(HTTPResponse, ErrorMessage);
				
				WriteErrorToEventLog(ErrorMessage);
			EndIf;
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
				URL, Server, Format(Port, "NG="),
				ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			
			Return FileGetResult(False, ErrorText, HTTPResponse);
			
		EndTry;
		
	EndIf;
	
	// If the file is saved in accordance with the setting.
	If SavingSetting["StorageLocation"] = "TemporaryStorage" Then
		UniqueKey = New UUID;
		Address = PutToTempStorage (New BinaryData(PathForSaving), UniqueKey);
		Return FileGetResult(True, Address, HTTPResponse);
	ElsIf SavingSetting["StorageLocation"] = "Server" Then
		Return FileGetResult(True, PathForSaving, HTTPResponse);
	Else
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'File save location is not specified for ""%1"".';"), "GetFileFromInternet"),
			ErrorCategory.ConfigurationError);
	EndIf;
	
EndFunction

// Parameters:
//   Status - Boolean - success or failure of the operation.
//   MessagePath - String
//   HTTPResponse - HTTPResponse
//
// Returns:
//   Structure:
//      * Status - Boolean
//      * Path   - String
//      * ErrorMessage - String
//      * Headers         - Map
//      * StatusCode      - Number
//
Function FileGetResult(Val Status, Val MessagePath, HTTPResponse = Undefined)
	
	Result = New Structure("Status", Status);
	
	If Status Then
		Result.Insert("Path", MessagePath);
	Else
		Result.Insert("ErrorMessage", MessagePath);
		Result.Insert("StatusCode", 1);
	EndIf;
	
	If HTTPResponse <> Undefined Then
		ResponseHeadings = HTTPResponse.Headers;
		If ResponseHeadings <> Undefined Then
			Result.Insert("Headers", ResponseHeadings);
		EndIf;
		
		Result.Insert("StatusCode", HTTPResponse.StatusCode);
		
	EndIf;
	
	Return Result;
	
EndFunction

Function HTTPFileSize(HTTPConnection, Val PathAtServer, Val Headers = Undefined)
	
	HTTPRequest = New HTTPRequest(PathAtServer, Headers);
	Try
		ReceivedHeaders = HTTPConnection.Head(HTTPRequest);// HEAD
	Except
		Return 0;
	EndTry;
	SizeInString = StandardSubsystemsServer.HTTPHeadersInLowercase(ReceivedHeaders.Headers)["content-length"];
	
	NumberType = New TypeDescription("Number");
	FileSize = NumberType.AdjustValue(SizeInString);
	
	Return FileSize;
	
EndFunction

Function FTPFileSize1(FTPConnection, Val PathAtServer)
	
	FileSize = 0;
	
	Try
		FilesFound = FTPConnection.FindFiles(PathAtServer);
		If FilesFound.Count() > 0 Then
			FileSize = FilesFound[0].Size();
		EndIf;
	Except
		FileSize = 0;
	EndTry;
	
	Return FileSize;
	
EndFunction

Function HTTPConnectionCodeDetails(StatusCode)
	
	If StatusCode = 304 Then // Not Modified
		Details = NStr("en = 'There is no need to retransmit the requested resources.';");
	ElsIf StatusCode = 400 Then // Bad Request
		Details = NStr("en = 'Couldn''t process the request.';");
	ElsIf StatusCode = 401 Then // Unauthorized
		Details = NStr("en = 'The server denied authorization.';");
	ElsIf StatusCode = 402 Then // Payment Required
		Details = NStr("en = 'Payment is required.';");
	ElsIf StatusCode = 403 Then // Forbidden
		Details = NStr("en = 'No access to the requested resource.';");
	ElsIf StatusCode = 404 Then // Not Found
		Details = NStr("en = 'The requested resource does not exist on the server.';");
	ElsIf StatusCode = 405 Then // Method Not Allowed
		Details = NStr("en = 'The server does not support the request method.';");
	ElsIf StatusCode = 406 Then // Not Acceptable
		Details = NStr("en = 'The server does not support the requested data format.';");
	ElsIf StatusCode = 407 Then // Proxy Authentication Required
		Details = NStr("en = 'Proxy server authentication error.';");
	ElsIf StatusCode = 408 Then // Request Timeout
		Details = NStr("en = 'Request timeout.';");
	ElsIf StatusCode = 409 Then // Conflict
		Details = NStr("en = 'Cannot execute the request due to an access conflict.';");
	ElsIf StatusCode = 410 Then // Gone
		Details = NStr("en = 'The resource is no longer available on the server.';");
	ElsIf StatusCode = 411 Then // Length Required
		Details = NStr("en = 'The ""Content-length"" request header is not specified.';");
	ElsIf StatusCode = 412 Then // Precondition Failed
		Details = NStr("en = 'The request is not applicable to the resource.';");
	ElsIf StatusCode = 413 Then // Request Entity Too Large
		Details = NStr("en = 'The server cannot process the request because the data volume is too large.';");
	ElsIf StatusCode = 414 Then // Request-URL Too Long
		Details = NStr("en = 'The cannot process the request because the URL is too long.';");
	ElsIf StatusCode = 415 Then // Unsupported Media-Type
		Details = NStr("en = 'A part of the request has unsupported format.';");
	ElsIf StatusCode = 416 Then // Requested Range Not Satisfiable
		Details = NStr("en = 'A part of the requested resource cannot be provided.';");
	ElsIf StatusCode = 417 Then // Expectation Failed
		Details = NStr("en = 'The server cannot provide a response to the specified request.';");
	ElsIf StatusCode = 429 Then // Too Many Requests
		Details = NStr("en = 'Too many requests in a short amount of time.';");
	ElsIf StatusCode = 500 Then // Internal Server Error
		Details = NStr("en = 'Internal online server error.';");
	ElsIf StatusCode = 501 Then // Not Implemented
		Details = NStr("en = 'The server does not support the request method.';");
	ElsIf StatusCode = 502 Then // Bad Gateway
		Details = NStr("en = 'The server received an invalid response from the upstream server
		                         |while acting as a gateway or proxy server.';");
	ElsIf StatusCode = 503 Then // Server Unavailable
		Details = NStr("en = 'Server is temporarily unavailable.';");
	ElsIf StatusCode = 504 Then // Gateway Timeout
		Details = NStr("en = 'The server did not receive a timely response from the upstream server
		                         |while acting as a gateway or proxy server.';");
	ElsIf StatusCode = 505 Then // HTTP Version Not Supported
		Details = NStr("en = 'The server does not support HTTP version specified in the request.';");
	ElsIf StatusCode = 506 Then // Variant Also Negotiates
		Details = NStr("en = 'The server cannot process a request because it is configured incorrectly.';");
	ElsIf StatusCode = 507 Then // Insufficient Storage
		Details = NStr("en = 'Not enough space on the server to run the request.';");
	ElsIf StatusCode = 509 Then // Bandwidth Limit Exceeded
		Details = NStr("en = 'The server exceeded the bandwidth limit.';");
	ElsIf StatusCode = 510 Then // Not Extended
		Details = NStr("en = 'The server requires additional request details.';");
	ElsIf StatusCode = 511 Then // Network Authentication Required
		Details = NStr("en = 'Authorization on the server is required.';");
	Else 
		Details = NStr("en = '<Unknown status code>.';");
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '[%1] %2';"), 
		StatusCode, 
		Details);
	
EndFunction

Function RedirectionPresentations(Redirections)
	
	If Redirections.Count() = 0 Then 
		Return "";
	EndIf;

	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Redirected (%1):
					|%2';"),
		Redirections.Count(),
		StrConcat(Redirections, Chars.LF));

EndFunction

Procedure AddServerResponseBody(PathToFile, ErrorText)
	
	ServerResponseBody = TextFromHTMLFromFile(PathToFile);
	
	If Not IsBlankString(ServerResponseBody) Then 
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1
			           |
			           |Message from web server:
			           |%2';"),
			ErrorText,
			ServerResponseBody);
	EndIf;
	
EndProcedure

Function TextFromHTMLFromFile(PathToFile)
	
	ResponseFile = New TextReader(PathToFile, TextEncoding.UTF8);
	SourceText = ResponseFile.Read(1024 * 15);
	ErrorText = StringFunctionsClientServer.ExtractTextFromHTML(SourceText);
	ResponseFile.Close();
	
	Return ErrorText;
	
EndFunction

Procedure AddHTTPHeaders(Object, ErrorText)
	
	If TypeOf(Object) = Type("HTTPRequest") Then 
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1
			           |
			           |HTTP request:
			           |Resource address: %2
			           |Headers: %3';"),
			ErrorText,
			Object.ResourceAddress,
			HTTPHeadersPresentation(Object.Headers));
	ElsIf TypeOf(Object) = Type("HTTPResponse") Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1
			           |
			           |HTTP response:
			           |Response code: %2
			           |Headers: %3';"),
			ErrorText,
			Object.StatusCode,
			HTTPHeadersPresentation(Object.Headers));
	EndIf;
	
EndProcedure

Function HTTPHeadersPresentation(Headers)
	
	HeadersPresentation = "";
	
	For Each Title In Headers Do 
		HeadersPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1
			           |%2: %3';"), 
			HeadersPresentation,
			Title.Key, Title.Value);
	EndDo;
		
	Return HeadersPresentation;
	
EndFunction

Function InternetProxyPresentation(Proxy, Protocol = Undefined)
	
	Log = New Array;
	If ValueIsFilled(Protocol) Then
		Server = Proxy.Server(Protocol);
		Port = Proxy.Port(Protocol);
		
		If ValueIsFilled(Server) Then
			If Not ValueIsFilled(Port) Then
				Port = DefaultPort(Protocol);
			EndIf;
		Else
			Server = Proxy.Server();
			Port = Proxy.Port();
		EndIf;
		
		Log.Add(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1: %2:%3';"), Upper(Protocol), Server, Format(Port, "NG=")));
	Else
		Log.Add(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Address: %1:%2
			           |HTTP:    %3:%4
			           |HTTPS:   %5:%6
			           |FTP:     %7:%8';"),
			Proxy.Server(),        Format(Proxy.Port(),        "NG="),
			Proxy.Server("http"),  Format(Proxy.Port("http"),  "NG="),
			Proxy.Server("https"), Format(Proxy.Port("https"), "NG="),
			Proxy.Server("ftp"),   Format(Proxy.Port("ftp"),   "NG=")));
	EndIf;
		
	If Proxy.UseOSAuthentication("") Then 
		Log.Add(NStr("en = 'OS authentication.';"));
	Else 
		User = Proxy.User("");
		Password = Proxy.Password("");
		PasswordState = ?(IsBlankString(Password), NStr("en = '<not specified>';"), NStr("en = '********';"));
		
		Log.Add(NStr("en = 'Authentication with username and password.';"));
		Log.Add(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'User: %1
			           |Password: %2';"),
			User,
			PasswordState));
	EndIf;
	
	If Proxy.BypassProxyOnLocal Then 
		Log.Add(NStr("en = 'Bypass proxy for local addresses.';"));
	EndIf;
	
	If Proxy.BypassProxyOnAddresses.Count() > 0 Then 
		Log.Add(NStr("en = 'Bypass proxy for the following addresses:';"));
		For Each AddressToExclude In Proxy.BypassProxyOnAddresses Do
			Log.Add(AddressToExclude);
		EndDo;
	EndIf;
	
	Return StrConcat(Log, Chars.LF);
	
EndFunction

// Returns proxy according to settings ProxyServerSetting for the specified Protocol protocol.
//
// Parameters:
//   ProxyServerSetting - Map of KeyAndValue:
//    * Key - String - see the list of available keys below.
//    * Value - Arbitrary
//    UseProxy - Boolean - indicates whether to use the proxy server.
//    BypassProxyOnLocal - indicates whether to use the proxy server for local addresses.
//    BypassProxyOnAddresses - Array from String
//    UseSystemSettings - Boolean - indicates whether to use system settings of the proxy server.
//    Server - String - a proxy server address.
//    Port - String - a proxy server port.
//    User - String - a username to authorize on the proxy server.
//    Password - String - a user password.
//    UseOSAuthentication - Boolean - indicates that authentication by operating system is used.
//   URLOrProtocol - String - resource address or protocol for which proxy server parameters are set, for example
//                             "https://1ci.com", "http", "https", "ftp", "ftps".
//
// Returns:
//   InternetProxy
//
Function NewInternetProxy(ProxyServerSetting, URLOrProtocol) Export
	
	If ProxyServerSetting = Undefined Then
		// Proxy server system settings.
		Return Undefined;
	EndIf;
	
	UseProxy = ProxyServerSetting.Get("UseProxy");
	If Not UseProxy Then
		// Do not use a proxy server.
		Return New InternetProxy(False);
	EndIf;
	
	UseSystemSettings = ProxyServerSetting.Get("UseSystemSettings");
	If UseSystemSettings Then
		// Proxy server system settings.
		Return New InternetProxy(True);
	EndIf;
	
	UseOSAuthentication = ProxyServerSetting.Get("UseOSAuthentication");
	UseOSAuthentication = ?(UseOSAuthentication = True, True, False);

	AdditionalSettings = ProxyServerSetting.Get("AdditionalProxySettings");
	If TypeOf(AdditionalSettings) <> Type("Map") Then
		AdditionalSettings = New Map;
	EndIf;
	
	// Manually configured proxy settings.
	Proxy = New InternetProxy;
	
	Logs = StrSplit("http,https,ftp,ftps", ",", False);
	For Each Protocol In Logs Do
		ServerAddress = ProxyServerSetting["Server"];
		Port = ProxyServerSetting["Port"];
		
		ProxyByProtocol = AdditionalSettings[Protocol];
		If TypeOf(ProxyByProtocol) = Type("Structure") Then
			ServerAddress = ProxyByProtocol.Address;
			Port = ProxyByProtocol.Port;
		EndIf;
		
		If Not ValueIsFilled(Port) Then
			Port = Undefined;
		EndIf;
		
		Proxy.Set(Protocol, ServerAddress, Port, 
			ProxyServerSetting["User"], ProxyServerSetting["Password"], UseOSAuthentication);
	EndDo;
	
	Proxy.BypassProxyOnLocal = ProxyServerSetting["BypassProxyOnLocal"];
	
	ExceptionsAddresses = ProxyServerSetting.Get("BypassProxyOnAddresses");
	If TypeOf(ExceptionsAddresses) = Type("Array") Then
		For Each ExceptionAddress In ExceptionsAddresses Do
			Proxy.BypassProxyOnAddresses.Add(ExceptionAddress);
		EndDo;
	EndIf;
	
	Return Proxy;
	
EndFunction

// Writes the error to the event log as "Network download".
//
// Parameters:
//   ErrorMessage - String - error message.
// 
Procedure WriteErrorToEventLog(Val ErrorMessage)
	
	WriteLogEvent(EventLogEvent(), EventLogLevel.Error,,,
		ErrorMessage);
	
EndProcedure

Function EventLogEvent()
	
	Return NStr("en = 'Network download';", Common.DefaultLanguageCode());
	
EndFunction

#EndIf

#EndRegion

#Region ConnectionDiagnostics

// Service information that displays current settings and proxy states to perform diagnostics.
//
// Parameters:
//  Protocol - String - a protocol for which you need to get the proxy settings.
//
// Returns:
//  Structure:
//     * ProxyConnection - Boolean - flag that indicates that proxy connection should be used.
//     * Presentation - String - presentation of the current set up proxy.
//
Function ProxySettingsState(Val Protocol = Undefined) Export
	
	Protocol = TheProtocolForTheProxy(Protocol);
	Proxy = GetFilesFromInternet.GetProxy(Protocol);
	ProxySettings = GetFilesFromInternet.ProxySettingsAtServer();
	
	Log = New Array;
	
	If ProxySettings = Undefined Then 
		Log.Add(NStr("en = 'The proxy server parameters are not specified in the infobase. System proxy server are used instead.';"));
	ElsIf Not ProxySettings.Get("UseProxy") Then
		Log.Add(NStr("en = 'Proxy server parameters in the infobase: Do not use proxy server.';"));
	ElsIf ProxySettings.Get("UseSystemSettings") Then
		Log.Add(NStr("en = 'Proxy server parameters in the infobase: Use system proxy server settings.';"));
	Else
		Log.Add(NStr("en = 'Proxy server parameters in the infobase: Use other proxy server settings.';"));
	EndIf;
	
	If Proxy = Undefined Then 
		Proxy = New InternetProxy(True);
	EndIf;
	
	ProxyConnection = Not IsBlankString(Proxy.Server(Protocol)) Or Not IsBlankString(Proxy.Server());
	
	If ProxyConnection Then 
		Log.Add(NStr("en = 'Connecting via proxy server:';"));
		Log.Add(InternetProxyPresentation(Proxy, Protocol));
	EndIf;
	
	Result = New Structure;
	Result.Insert("ProxyConnection", ProxyConnection);
	Result.Insert("Presentation", StrConcat(Log, Chars.LF));
	Result.Insert("SystemProxySettingsUsed", ProxySettings = Undefined Or ProxySettings["UseSystemSettings"] = True);
	
	Return Result;
	
EndFunction

Function DiagnosticsLocationPresentation() Export
	
	If Common.DataSeparationEnabled() Then
		Return NStr("en = 'Attempting connection on a remote 1C:Enterprise server (SaaS).';");
	Else 
		If Common.FileInfobase() Then
			If Common.ClientConnectedOverWebServer() Then 
				Return StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Attempting connection from a file infobase on web server <%1>.';"), ComputerName());
			Else 
				Return StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Attempting connection from a file infobase on computer <%1>.';"), ComputerName());
			EndIf;
		Else
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Attempting connection on 1C:Enterprise server <%1>.';"), ComputerName());
		EndIf;
	EndIf;
	
EndFunction

Function CheckServerAvailability(ServerAddress) Export
	
	Result = New Structure("Available, DiagnosticsLog", False, "");

	ApplicationStartupParameters = FileSystem.ApplicationStartupParameters();
	ApplicationStartupParameters.WaitForCompletion = True;
	ApplicationStartupParameters.GetOutputStream = True;
	ApplicationStartupParameters.GetErrorStream = True;
	ApplicationStartupParameters.ExecutionEncoding = "OEM";
	
	If Common.IsWindowsServer() Then
		CommandTemplate = "ping %1 -n 4 -w 1000";
	Else
		CommandTemplate = "ping -c 4 -W 1 %1";
	EndIf;
	CommandString = StringFunctionsClientServer.SubstituteParametersToString(CommandTemplate, ServerAddress);
	
	Try
		RunResult = FileSystem.StartApplication(CommandString, ApplicationStartupParameters);
	Except
		Result.DiagnosticsLog = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot check whether the ""%1"" Internet resource is available due to:
				|%2
				|
				|using the ""%3"" command.';"), 
				ServerAddress, ErrorProcessing.BriefErrorDescription(ErrorInfo()), CommandString);
		Return Result; 
	EndTry;	
	
	// Error handling differs between OS:
	// - Windows sends errors to the output stream.
	// - Debian and RHEL send errors to the error stream.
	AvailabilityLog = RunResult.OutputStream + RunResult.ErrorStream;
	
	If Common.IsWindowsServer() Then
		Available = StrFind(AvailabilityLog, "Destination host unreachable") = 0 // Do not localize.
			And (StrFind(AvailabilityLog, "(0% loss)") > 0 // Do not localize.
			Or StrFind(AvailabilityLog, "(25% loss)") > 0); // Do not localize.
	Else 
		Available = StrFind(AvailabilityLog, "Destination Host Unreachable") = 0 // Do not localize.
			And (StrFind(AvailabilityLog, "(0% packet loss)") > 0 // Do not localize.
			Or StrFind(AvailabilityLog, "(25% packet loss)") > 0); // Do not localize.
	EndIf;
	
	Log = New Array;
	If Available Then
		Log.Add(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Remote server %1 is available:';"), 
			ServerAddress));
	Else
		Log.Add(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Remote server %1 is unavailable:';"), 
			ServerAddress));
	EndIf;
	
	Log.Add("> " + CommandString);
	Log.Add(AvailabilityLog);
	
	Result.Available = Available;
	Result.DiagnosticsLog = StrConcat(Log, Chars.LF);
	Return Result; 
	
EndFunction

Function ServerRouteTraceLog(ServerAddress) Export
	
	ApplicationStartupParameters = FileSystem.ApplicationStartupParameters();
	ApplicationStartupParameters.WaitForCompletion = True;
	ApplicationStartupParameters.GetOutputStream = True;
	ApplicationStartupParameters.GetErrorStream = True;
	ApplicationStartupParameters.ExecutionEncoding = "OEM";
	
	If Common.IsWindowsServer() Then
		CommandTemplate = "tracert -w 100 -h 15 %1";
	Else 
		// If traceroute is not installed, the output stream will have an error.
		// You can ignore that since the output is not parseable.
		// For the administrator, it will be clear what utility should be installed.
		CommandTemplate = "traceroute -w 100 -m 100 %1";
	EndIf;
	
	CommandString = StringFunctionsClientServer.SubstituteParametersToString(CommandTemplate, ServerAddress);
	
	Result = FileSystem.StartApplication(CommandString, ApplicationStartupParameters);
	
	Log = New Array;
	Log.Add(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Tracing route to remote server %1:';"), ServerAddress));
	
	Log.Add("> " + CommandString);
	Log.Add(Result.OutputStream);
	Log.Add(Result.ErrorStream);
	
	Return StrConcat(Log, Chars.LF);
	
EndFunction

Function DefaultPort(Protocol)
	
	DefaultPorts = New Map;
	DefaultPorts.Insert("http", 80);
	DefaultPorts.Insert("https", 443);
	DefaultPorts.Insert("ftp", 21);
	DefaultPorts.Insert("ftps", 990);
	
	Return DefaultPorts[Lower(Protocol)];
	
EndFunction

Function TheProtocolForTheProxy(Val URLOrProtocol)
	
	AcceptableProtocols = New Map();
	AcceptableProtocols.Insert("HTTP",  True);
	AcceptableProtocols.Insert("HTTPS", True);
	AcceptableProtocols.Insert("FTP",   True);
	AcceptableProtocols.Insert("FTPS",  True);
	
	If StrFind(URLOrProtocol, "://") > 0 Then
		URLStructure1 = CommonClientServer.URIStructure(URLOrProtocol);
		Protocol = ?(IsBlankString(URLStructure1.Schema), "http", URLStructure1.Schema);
	Else
		Protocol = Lower(URLOrProtocol);
	EndIf;
	
	If AcceptableProtocols[Upper(Protocol)] = Undefined Then
		Protocol = "HTTP";
	EndIf;
	
	Return Protocol;
	
EndFunction

#EndRegion

#EndRegion
