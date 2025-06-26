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

// It sends a text message via a configured service provider and returns message ID.
//
// Parameters:
//  RecipientsNumbers  - Array of String - Recipient numbers in the format +XXXXXXXXXX.
//  Text              - String - Message text. The max length varies depending on the SMS provider.
//  SenderName     - String - Sender's name that recipients will see instead of the phone number.
//  Transliterate - Boolean - If True, transliterate the outgoing message.
//
// Returns:
//  Structure:
//    * SentMessages - Array of Structure:
//      ** RecipientNumber - String - Recipient phone number.
//      ** MessageID - String - Text message ID assigned by the SMS provider.
//    * ErrorDescription - String - a user presentation of an error. If the string is empty, there is no error.
//
Function SendSMS(RecipientsNumbers, Val Text, SenderName = Undefined, Transliterate = False) Export
	
	CheckRights();
	
	Result = New Structure("SentMessages,ErrorDescription", New Array, "");
	
	If Not ValueIsFilled(StrConcat(RecipientsNumbers, "")) Then
		Result.ErrorDescription = NStr("en = 'Text message recipient number is not specified.';");
		Return Result;
	EndIf;
	
	If Transliterate Then
		Text = StringFunctions.LatinString(Text);
	EndIf;
	
	If Not SMSMessageSendingSetupCompleted() Then
		Result.ErrorDescription = NStr("en = 'Invalid SMS provider settings.';");
		Return Result;
	EndIf;
	
	SetPrivilegedMode(True);
	SMSMessageSendingSettings = SMSMessageSendingSettings();
	SetPrivilegedMode(False);
	
	If SenderName = Undefined Then
		SenderName = SMSMessageSendingSettings.SenderName;
	EndIf;
	
	ModuleSMSMessageSendingViaProvider = ModuleSMSMessageSendingViaProvider(SMSMessageSendingSettings.Provider);
	If ModuleSMSMessageSendingViaProvider <> Undefined Then
		Login = "";
		Password = "";
		If SMSMessageSendingSettings.AuthorizationMethod <> "ByKey" Then
			Login = SMSMessageSendingSettings.Login;
			Password = SMSMessageSendingSettings.Password;
		EndIf;
		Result = ModuleSMSMessageSendingViaProvider.SendSMS(RecipientsNumbers, Text, SenderName, Login, Password);
	Else
		SendOptions = New Structure;
		SendOptions.Insert("RecipientsNumbers", RecipientsNumbers);
		SendOptions.Insert("Text", Text);
		SendOptions.Insert("SenderName", SenderName);
		SendOptions.Insert("Login", SMSMessageSendingSettings.Login);
		SendOptions.Insert("Password", SMSMessageSendingSettings.Password);
		SendOptions.Insert("Provider", SMSMessageSendingSettings.Provider);
		
		SendSMSMessageOverridable.SendSMS(SendOptions, Result);
		
		CommonClientServer.CheckParameter("SendSMSMessageOverridable.SendSMS", "Result", Result,
			Type("Structure"), New Structure("SentMessages,ErrorDescription", Type("Array"), Type("String")));
			
		If Not ValueIsFilled(Result.ErrorDescription) And Not ValueIsFilled(Result.SentMessages) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(NStr(
				"en = 'Error completing procedure %1:
				|At least one of the parameters is required: %2, %3.
				|Provider: %4.';", Common.DefaultLanguageCode()),
				"SendSMSMessageOverridable.SendSMS",
				"ErrorDescription",
				"SentMessages",
				SMSMessageSendingSettings.Provider);
		EndIf;
		
		If Result.SentMessages.Count() > 0 Then
			CommonClientServer.Validate(
				TypeOf(Result.SentMessages[0]) = Type("Structure"),
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Invalid value type in %1 collection.
						|Actual type: %2. Expected type: Structure.';"),
						"Result.SentMessages",
						TypeOf(Result.SentMessages[0])),
				"SendSMSMessageOverridable.SendSMS");
			For IndexOf = 0 To Result.SentMessages.Count() - 1 Do
				CommonClientServer.CheckParameter(
					"SendSMSMessageOverridable.SendSMS",
					StringFunctionsClientServer.SubstituteParametersToString("Result.SentMessages[%1]", Format(IndexOf, "NZ=; NG=0")),
					Result.SentMessages[IndexOf],
					Type("Structure"),
					New Structure("RecipientNumber,MessageID", Type("String"), Type("String")));
			EndDo;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// The function requests the delivery status from the SMS provider.
//
// Parameters:
//  MessageID - String - ID assigned to the outgoing text message.
//
// Returns:
//  String - The delivery status returned by the service provider:
//           Pending - Message is not yet processed.
//           BeingSent - Message is pending in the send-out queue.
//           Sent - Message is sent, a delivery confirmation is awaited.
//           NotSent - Message is not sent due to insufficient account balance or operator network congestion.
//           Delivered - Message is delivered to the addressee.
//           NotDelivered - Message cannot be delivered as the subscriber is not available or
//                              delivery confirmation from the subscriber is timed out.
//           Error - Failed to get a status from the service provider or the status is unknown.
//
Function DeliveryStatus(Val MessageID) Export
	
	CheckRights();
	
	If IsBlankString(MessageID) Then
		Return "Pending";
	EndIf;
	
	Return DeliveryStatuses(CommonClientServer.ValueInArray(MessageID))[MessageID];
	
EndFunction

// This function checks whether saved text message sending settings are correct.
//
// Returns:
//  Boolean - True if text message sending is set up.
//
Function SMSMessageSendingSetupCompleted() Export
	
	SetPrivilegedMode(True);
	SMSMessageSendingSettings = SMSMessageSendingSettings();
	SetPrivilegedMode(False);
	
	If ValueIsFilled(SMSMessageSendingSettings.Provider) Then
		ProviderSettings = ProviderSettings(SMSMessageSendingSettings.Provider);
		
		AuthorizationFields = DefaultProviderAuthorizationFields().ByUsernameAndPassword;
		If SMSMessageSendingSettings.Property("AuthorizationMethod") And ValueIsFilled(SMSMessageSendingSettings.AuthorizationMethod)
			And ProviderSettings.AuthorizationFields.Property(SMSMessageSendingSettings.AuthorizationMethod) Then
			
			AuthorizationFields = ProviderSettings.AuthorizationFields[SMSMessageSendingSettings.AuthorizationMethod];
		EndIf;
		
		Cancel = False;
		For Each Field In AuthorizationFields Do
			If Not ValueIsFilled(SMSMessageSendingSettings[Field.Value]) Then
				Cancel = True;
			EndIf;
		EndDo;
		
		SendSMSMessageOverridable.OnCheckSMSMessageSendingSettings(SMSMessageSendingSettings, Cancel);
		Return Not Cancel;
	EndIf;
	
	Return False;
	
EndFunction

// This function checks whether the current user can send text messages.
// 
// Returns:
//  Boolean - True if text message sending is set up and the current user has sufficient rights to send text messages.
//
Function CanSendSMSMessage() Export
	
	Return SendSMSMessageCached.CanSendSMSMessage();
	
EndFunction

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddClientParameters.
Procedure OnAddClientParameters(Parameters) Export
	Parameters.Insert("CanSendSMSMessage", CanSendSMSMessage());
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources.
Procedure OnFillPermissionsToAccessExternalResources(PermissionsRequests) Export
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	For Each ProviderModule In ProvidersModules() Do
		ModuleSMSMessageSendingViaProvider = ProviderModule.Value;
		PermissionsRequests.Add(
			ModuleSafeModeManager.RequestToUseExternalResources(ModuleSMSMessageSendingViaProvider.Permissions()));
	EndDo;
	
	PermissionsRequests.Add(
		ModuleSafeModeManager.RequestToUseExternalResources(AdditionalPermissions()));
	
EndProcedure

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	
	SetPrivilegedMode(True);
	SMSMessageSendingSettings = SMSMessageSendingSettings();
	SetPrivilegedMode(False);
	
	If Not ValueIsFilled(SMSMessageSendingSettings.Provider) Then
		Return;
	EndIf;
	
	ModuleSMSMessageSendingViaProvider = ModuleSMSMessageSendingViaProvider(SMSMessageSendingSettings.Provider);
	
	If ModuleSMSMessageSendingViaProvider <> Undefined Then
		ProviderSettings = DefaultProviderSettings();
		ModuleSMSMessageSendingViaProvider.OnDefineSettings(ProviderSettings);
		If ProviderSettings.OnFillToDoList Then
			ModuleSMSMessageSendingViaProvider.OnFillToDoList(ToDoList);
		EndIf;
	EndIf;
	
EndProcedure

// See MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters.
Procedure OnCollectConfigurationStatisticsParameters() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		Return;
	EndIf;
	
	ProviderName = String(Constants.SMSProvider.Get());
	
	ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
	ModuleMonitoringCenter.WriteConfigurationObjectStatistics("SendSMSMessage.SMSProvider." + ProviderName, 1);
	
EndProcedure

// The function requests the delivery status from the SMS provider.
//
// Parameters:
//  MessagesIDs - Array of String - IDs assigned to the outgoing text message.
//
// Returns:
//  Map:
//   * Key - String - Text message ID.
//   * Value - String - The delivery status returned by the service provider:
//           Pending - Message is not yet processed.
//           BeingSent - Message is pending in the send-out queue.
//           Sent - Message is sent, a delivery confirmation is awaited.
//           NotSent - Message is not sent due to insufficient account balance or operator network congestion.
//           Delivered - Message is delivered to the addressee.
//           NotDelivered - Message cannot be delivered as the subscriber is not available or
//                              delivery confirmation from the subscriber is timed out.
//           Error - Failed to get a status from the service provider or the status is unknown.
//
Function DeliveryStatuses(Val MessagesIDs) Export
	
	CheckRights();
	DeliveryStatuses = SendSMSMessageCached.DeliveryStatuses(StrConcat(MessagesIDs, ","));
	
	Return New Map(DeliveryStatuses);
	
EndFunction

#EndRegion

#Region Private

Function AdditionalPermissions()
	Permissions = New Array;
	SendSMSMessageOverridable.OnGetPermissions(Permissions);
	
	Return Permissions;
EndFunction

Procedure CheckRights() Export
	VerifyAccessRights("View", Metadata.CommonForms.SendSMSMessage);
EndProcedure

Function ModuleSMSMessageSendingViaProvider(Provider) Export
	Return ProvidersModules()[Provider];
EndFunction

Function ProvidersModules()
	Result = New Map;
	
	For Each MetadataObject In Metadata.Enums.SMSProviders.EnumValues Do
		ModuleName = "SendSMSThrough" + MetadataObject.Name;
		If Metadata.CommonModules.Find(ModuleName) <> Undefined Then
			Result.Insert(Enums.SMSProviders[MetadataObject.Name], Common.CommonModule(ModuleName));
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

Function PrepareHTTPRequest(ResourceAddress, QueryOptions, PutParametersInQueryBody = True) Export
	
	Headers = New Map;
	
	If PutParametersInQueryBody Then
		Headers.Insert("Content-Type", "application/x-www-form-urlencoded");
	EndIf;
	
	SetPrivilegedMode(True);
	SMSMessageSendingSettings = SMSMessageSendingSettings();
	SetPrivilegedMode(False);
	
	If SMSMessageSendingSettings.AuthorizationMethod = "ByKey" Then
		Headers.Insert("Authorization", "Bearer" + " " + SMSMessageSendingSettings.Password);
	EndIf;
	
	If TypeOf(QueryOptions) = Type("String") Then
		ParametersString1 = QueryOptions;
	Else
		ParametersList = New Array;
		For Each Parameter In QueryOptions Do
			Values = Parameter.Value;
			If TypeOf(Parameter.Value) <> Type("Array") Then
				Values = CommonClientServer.ValueInArray(Parameter.Value);
			EndIf;
			
			For Each Value In Values Do
				ParametersList.Add(Parameter.Key + "=" + EncodeString(Value, StringEncodingMethod.URLEncoding));
			EndDo;
		EndDo;
		ParametersString1 = StrConcat(ParametersList, "&");
	EndIf;
	
	If Not PutParametersInQueryBody Then
		ResourceAddress = ResourceAddress + "?" + ParametersString1;
	EndIf;

	HTTPRequest = New HTTPRequest(ResourceAddress, Headers);
	
	If PutParametersInQueryBody Then
		HTTPRequest.SetBodyFromString(ParametersString1);
	EndIf;
	
	Return HTTPRequest;

EndFunction

Function DefaultProviderAuthorizationFields()
	
	AuthorizationMethods = New Structure;
	
	AuthorizationFields = New ValueList;
	AuthorizationFields.Add("Login", NStr("en = 'Username';"));
	AuthorizationFields.Add("Password", NStr("en = 'Password';"), True);
	
	AuthorizationMethods.Insert("ByUsernameAndPassword", AuthorizationFields);
	
	Return AuthorizationMethods;
	
EndFunction

Function DefaultAuthorizationMethods()
	
	Result = New ValueList;
	Result.Add("ByUsernameAndPassword", NStr("en = 'Username and password authentication';"));
	
	Return Result;
	
EndFunction


// SMS settings.
// 
// Returns:
//  Structure:
//   * Login - String 
//   * Password - String 
//   * Provider  - String
//   * SenderName - String 
//   * AuthorizationMethod - String - for example, "ByUsernameAndPassword".
// 
Function SMSMessageSendingSettings() Export
	
	Result = New Structure("Login,Password,Provider,SenderName,AuthorizationMethod");
	
	If Common.SeparatedDataUsageAvailable() Then
		Owner = Common.MetadataObjectID("Constant.SMSProvider");
		ProviderSettings = Common.ReadDataFromSecureStorage(Owner, "Password,Login,SenderName,AuthorizationMethod");
		FillPropertyValues(Result, ProviderSettings);
		Result.Provider = Constants.SMSProvider.Get();
	EndIf;
	
	Return Result;
	
EndFunction

Function DefaultProviderSettings()
	
	Result = New Structure;
	Result.Insert("ServiceDetailsInternetAddress", "");
	Result.Insert("AuthorizationMethods", DefaultAuthorizationMethods());
	Result.Insert("AuthorizationFields", DefaultProviderAuthorizationFields());
	Result.Insert("InformationOnAuthorizationMethods", New Structure);
	Result.Insert("OnDefineAuthorizationMethods", False);
	Result.Insert("WhenDefiningAuthorizationFields", False);
	Result.Insert("OnFillToDoList", False);
	Result.Insert("DeliveryStatusesInOneRequest", False);
	
	Return Result;
	
EndFunction

Function ProviderSettings(Provider) Export
	
	ProviderSettings = DefaultProviderSettings();
	ModuleSMSMessageSendingViaProvider = ModuleSMSMessageSendingViaProvider(Provider);
	
	If ModuleSMSMessageSendingViaProvider <> Undefined Then
		ModuleSMSMessageSendingViaProvider.OnDefineSettings(ProviderSettings);
		If ProviderSettings.OnDefineAuthorizationMethods Then
			ModuleSMSMessageSendingViaProvider.OnDefineAuthorizationMethods(ProviderSettings.AuthorizationMethods);
		EndIf;
		If ProviderSettings.WhenDefiningAuthorizationFields Then
			ModuleSMSMessageSendingViaProvider.WhenDefiningAuthorizationFields(ProviderSettings.AuthorizationFields);
		EndIf;
	EndIf;
	
	Return ProviderSettings;
	
EndFunction

#EndRegion
