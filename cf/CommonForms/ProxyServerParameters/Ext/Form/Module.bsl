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
	
	ProxySettingAtClient = Parameters.ProxySettingAtClient;
	If Not Parameters.ProxySettingAtClient
		And Not Users.IsFullUser(, True) Then
		Raise(NStr("en = 'Insufficient access rights.
			|Only administrators can configure proxy servers.';"),
			ErrorCategory.AccessViolation);
	EndIf;
	
	If ProxySettingAtClient Then
		ProxyServerSetting = GetFilesFromInternet.ProxySettingsAtClient();
	Else
		AutoTitle = False;
		Title = NStr("en = 'Proxy server parameters on 1C:Enterprise server';");
		ProxyServerSetting = GetFilesFromInternet.ProxySettingsAtServer();
	EndIf;
	
	UseProxy = True;
	UseSystemSettings = True;
	If TypeOf(ProxyServerSetting) = Type("Map") Then
		
		UseProxy = ProxyServerSetting.Get("UseProxy");
		UseSystemSettings = ProxyServerSetting.Get("UseSystemSettings");
		
		If UseProxy And Not UseSystemSettings Then
			
			// Complete the forms with manual settings.
			Server       = ProxyServerSetting.Get("Server");
			User = ProxyServerSetting.Get("User");
			Password       = ProxyServerSetting.Get("Password");
			Port         = ProxyServerSetting.Get("Port");
			BypassProxyOnLocal = ProxyServerSetting.Get("BypassProxyOnLocal");
			ParameterValue = ProxyServerSetting.Get("UseOSAuthentication");
			UseOSAuthentication = ?(ParameterValue = Undefined, 0, Number(ParameterValue));
			
			ExceptionServerAddressesArray = ProxyServerSetting.Get("BypassProxyOnAddresses");
			If TypeOf(ExceptionServerAddressesArray) = Type("Array") Then
				ExceptionServers.LoadValues(ExceptionServerAddressesArray);
			EndIf;
			
			AdditionalProxy = ProxyServerSetting.Get("AdditionalProxySettings");
			If TypeOf(AdditionalProxy) <> Type("Map") Then
				AllProtocolsThroughSingleProxy = True;
			Else
			
				// If the settings contain additional proxy servers, read them from the settings.
				// 				
				ParameterValue = AdditionalProxy.Get("http");
				If TypeOf(ParameterValue) = Type("Structure") Then
					HTTPServer = ParameterValue.Address;
					HTTPPort   = ParameterValue.Port;
				EndIf;
				
				ParameterValue = AdditionalProxy.Get("https");
				If TypeOf(ParameterValue) = Type("Structure") Then
					HTTPSServer = ParameterValue.Address;
					HTTPSPort   = ParameterValue.Port;
				EndIf;
				
				ParameterValue = AdditionalProxy.Get("ftp");
				If TypeOf(ParameterValue) = Type("Structure") Then
					FTPServer = ParameterValue.Address;
					FTPPort   = ParameterValue.Port;
				EndIf;
			
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Proxy server options:
	// 0 - Do not use proxy (default). Corresponds to "New InternetProxy(False))".
	// 1 - Use the system proxy settings. Same as "New InternetProxy(True))".
	// 2 - Use the custom proxy settings.
	// This option allows for manual proxy configuration.
	ProxyServerUseCase = ?(UseProxy, ?(UseSystemSettings = True, 1, 2), 0);
	If ProxyServerUseCase = 0 Then
		InitializeFormItems(ThisObject, EmptyProxyServerSettings());
	ElsIf ProxyServerUseCase = 1 And Not ProxySettingAtClient Then
		InitializeFormItems(ThisObject, ProxyServerSystemSettings());
	EndIf;
	
	SetVisibilityAvailability(ThisObject);
	
	If Not AccessRight("SaveUserData", Metadata) Then
		ReadOnly = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ProxySettingAtClient Then
#If WebClient Then
		ShowMessageBox(, NStr("en = 'Please specify the proxy server parameters in the browser settings.';"));
		Cancel = True;
		Return;
#EndIf
		
		If ProxyServerUseCase = 1 Then
			InitializeFormItems(ThisObject, ProxyServerSystemSettings());
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.AdditionalProxyServerParameters") Then
		
		If TypeOf(ValueSelected) <> Type("Structure") Then
			Return;
		EndIf;
		
		For Each KeyAndValue In ValueSelected Do
			If KeyAndValue.Key <> "BypassProxyOnAddresses" Then
				ThisObject[KeyAndValue.Key] = KeyAndValue.Value;
			EndIf;
		EndDo;
		
		ExceptionServers = ValueSelected.BypassProxyOnAddresses;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("SelectAndClose", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ProxyServerUseCasesOnChange(Item)
	
	UseProxy = (ProxyServerUseCase > 0);
	UseSystemSettings = (ProxyServerUseCase = 1);
	
	ProxySettings = Undefined;
	// Proxy server options:
	// 0 - Do not use proxy (default). Corresponds to "New InternetProxy(False))".
	// 1 - Use the system proxy settings. Same as "New InternetProxy(True))".
	// 2 - Use the custom proxy settings.
	// This option allows for manual proxy configuration.
	If ProxyServerUseCase = 0 Then
		ProxySettings = EmptyProxyServerSettings();
	ElsIf ProxyServerUseCase = 1 Then
		ProxySettings = ?(ProxySettingAtClient,
							ProxyServerSystemSettings(),
							ProxyServerSystemSettingsAtServer());
	EndIf;
	
	InitializeFormItems(ThisObject, ProxySettings);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AdditionalProxyServerParameters(Command)
	
	// Configure parameters for additional settings.
	FormParameters = New Structure;
	FormParameters.Insert("ReadOnly", Not EditingAvailable);
	
	FormParameters.Insert("AllProtocolsThroughSingleProxy", AllProtocolsThroughSingleProxy);
	
	FormParameters.Insert("Server"     , Server);
	FormParameters.Insert("Port"       , Port);
	FormParameters.Insert("HTTPServer" , HTTPServer);
	FormParameters.Insert("HTTPPort"   , HTTPPort);
	FormParameters.Insert("HTTPSServer", HTTPSServer);
	FormParameters.Insert("HTTPSPort"  , HTTPSPort);
	FormParameters.Insert("FTPServer"  , FTPServer);
	FormParameters.Insert("FTPPort"    , FTPPort);
	
	FormParameters.Insert("BypassProxyOnAddresses", ExceptionServers);
	
	OpenForm("CommonForm.AdditionalProxyServerParameters", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure OKButton(Command)
	
	// Saves the proxy server settings, closes the form,
	// and returns the proxy parameters.
	SaveProxyServerSettings();
	
EndProcedure

&AtClient
Procedure CancelButton(Command)
	
	Modified = False;
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure InitializeFormItems(Form, ProxySettings)
	
	If ProxySettings <> Undefined Then
		
		Form.Server       = ProxySettings.Server;
		Form.Port         = ProxySettings.Port;
		Form.HTTPServer   = ProxySettings.HTTPServer;
		Form.HTTPPort     = ProxySettings.HTTPPort;
		Form.HTTPSServer  = ProxySettings.HTTPSServer;
		Form.HTTPSPort    = ProxySettings.HTTPSPort;
		Form.FTPServer    = ProxySettings.FTPServer;
		Form.FTPPort      = ProxySettings.FTPPort;
		Form.User = ProxySettings.User;
		Form.Password       = ProxySettings.Password;
		Form.BypassProxyOnLocal = ProxySettings.BypassProxyOnLocal;
		Form.ExceptionServers.LoadValues(ProxySettings.BypassProxyOnAddresses);
		Form.UseOSAuthentication = ?(ProxySettings.UseOSAuthentication, 1, 0);
		
		// If settings for all protocols match the default proxy settings,
		// assume that the same proxy is used for all the protocols.
		Form.AllProtocolsThroughSingleProxy = (Form.Server = Form.HTTPServer
			And Form.HTTPServer = Form.HTTPSServer
			And Form.HTTPSServer = Form.FTPServer
			And Form.Port = Form.HTTPPort
			And Form.HTTPPort = Form.HTTPSPort
			And Form.HTTPSPort = Form.FTPPort);
		
	EndIf;
	
	SetVisibilityAvailability(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetVisibilityAvailability(Form)
	
	// Toggle the availability of the proxy parameter editor group
	// depending on the given proxy setup option.
	Form.EditingAvailable = (Form.ProxyServerUseCase = 2);
	
	Form.Items.ServerAddressGroup.Enabled = Form.EditingAvailable;
	Form.Items.GroupAuthentication.Enabled = Form.EditingAvailable;
	Form.Items.BypassProxyOnLocal.Enabled = Form.EditingAvailable;
	
EndProcedure

// Saves proxy server settings interactively as
// a result of user actions and reflects messages for users,
// then closes the form and returns proxy server settings.
//
&AtClient
Procedure SaveProxyServerSettings(CloseForm = True)
	
	ProxyServerSetting = New Map;
	
	ProxyServerSetting.Insert("UseProxy", UseProxy);
	ProxyServerSetting.Insert("User"      , User);
	ProxyServerSetting.Insert("Password"            , Password);
	ProxyServerSetting.Insert("Server"            , NormalizedProxyServerAddress(Server));
	ProxyServerSetting.Insert("Port"              , Port);
	ProxyServerSetting.Insert("BypassProxyOnLocal", BypassProxyOnLocal);
	ProxyServerSetting.Insert("BypassProxyOnAddresses", ExceptionServers.UnloadValues());
	ProxyServerSetting.Insert("UseSystemSettings", UseSystemSettings);
	ProxyServerSetting.Insert("UseOSAuthentication", Boolean(UseOSAuthentication));
	
	
	// Configure additional proxy server addresses.
	
	If Not AllProtocolsThroughSingleProxy Then
		
		AdditionalSettings = New Map;
		If Not IsBlankString(HTTPServer) Then
			AdditionalSettings.Insert("http",
				New Structure("Address,Port", NormalizedProxyServerAddress(HTTPServer), HTTPPort));
		EndIf;
		
		If Not IsBlankString(HTTPSServer) Then
			AdditionalSettings.Insert("https",
				New Structure("Address,Port", NormalizedProxyServerAddress(HTTPSServer), HTTPSPort));
		EndIf;
		
		If Not IsBlankString(FTPServer) Then
			AdditionalSettings.Insert("ftp",
				New Structure("Address,Port", NormalizedProxyServerAddress(FTPServer), FTPPort));
		EndIf;
		
		If AdditionalSettings.Count() > 0 Then
			ProxyServerSetting.Insert("AdditionalProxySettings", AdditionalSettings);
		EndIf;
		
	EndIf;
	
	WriteProxyServerSettingsToInfobase(ProxySettingAtClient, ProxyServerSetting);
	
	Modified = False;
	
	If CloseForm Then
		
		Close(ProxyServerSetting);
		
	EndIf;
	
EndProcedure

// Saves proxy server settings.
&AtServerNoContext
Procedure WriteProxyServerSettingsToInfobase(ProxySettingAtClient, ProxyServerSetting)
	
	If ProxySettingAtClient
	 Or Common.FileInfobase() Then
		
		Common.CommonSettingsStorageSave("ProxyServerSetting", "", ProxyServerSetting);
	Else
		GetFilesFromInternetInternal.SaveServerProxySettings(ProxyServerSetting);
	EndIf;
	RefreshReusableValues();
	
EndProcedure

&AtClientAtServerNoContext
Function EmptyProxyServerSettings()
	
	Result = New Structure;
	Result.Insert("Server"      , "");
	Result.Insert("Port"        , 0);
	Result.Insert("HTTPServer"  , "");
	Result.Insert("HTTPPort"    , 0);
	Result.Insert("HTTPSServer" , "");
	Result.Insert("HTTPSPort"   , 0);
	Result.Insert("FTPServer"   , "");
	Result.Insert("FTPPort"     , 0);
	Result.Insert("User", "");
	Result.Insert("Password"      , "");
	
	Result.Insert("UseOSAuthentication", False);
	
	Result.Insert("BypassProxyOnLocal", False);
	Result.Insert("BypassProxyOnAddresses", New Array);
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function ProxyServerSystemSettings()

#If WebClient Then

	Return EmptyProxyServerSettings();
	
#Else	
	
	Proxy = New InternetProxy(True);
	
	Result = New Structure;
	Result.Insert("Server", Proxy.Server());
	Result.Insert("Port"  , Proxy.Port());
	
	Result.Insert("HTTPServer" , Proxy.Server("http"));
	Result.Insert("HTTPPort"   , Proxy.Port("http"));
	Result.Insert("HTTPSServer", Proxy.Server("https"));
	Result.Insert("HTTPSPort"  , Proxy.Port("https"));
	Result.Insert("FTPServer"  , Proxy.Server("ftp"));
	Result.Insert("FTPPort"    , Proxy.Port("ftp"));
	
	Result.Insert("User", Proxy.User(""));
	Result.Insert("Password"      , Proxy.Password(""));
	Result.Insert("UseOSAuthentication", Proxy.UseOSAuthentication(""));
	
	Result.Insert("BypassProxyOnLocal",
		Proxy.BypassProxyOnLocal);
	
	BypassProxyOnAddresses = New Array;
	For Each ServerAddress In Proxy.BypassProxyOnAddresses Do
		BypassProxyOnAddresses.Add(ServerAddress);
	EndDo;
	Result.Insert("BypassProxyOnAddresses", BypassProxyOnAddresses);
	
	Return Result;
	
#EndIf
	
EndFunction

&AtServerNoContext
Function ProxyServerSystemSettingsAtServer()
	
	Return ProxyServerSystemSettings();
	
EndFunction

// Returns normalized proxy server address that contains no spaces.
// If there are spaces between meaningful characters, then
// ignore everything after the first space.
//
// Parameters:
//  ProxyServerAddress - String - proxy server address to normalize.
//
// Returns:
//   String - a normalized proxy server address.
//
&AtClientAtServerNoContext
Function NormalizedProxyServerAddress(Val ProxyServerAddress)
	
	ProxyServerAddress = TrimAll(ProxyServerAddress);
	SpacePosition = StrFind(ProxyServerAddress, " ");
	If SpacePosition > 0 Then
		// If the server address contains the whitespace characters,
		// take the part before the first whitespace.
		ProxyServerAddress = Left(ProxyServerAddress, SpacePosition - 1);
	EndIf;
	
	Return ProxyServerAddress;
	
EndFunction

&AtClient
Procedure SelectAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	SaveProxyServerSettings();
	
EndProcedure

#EndRegion
