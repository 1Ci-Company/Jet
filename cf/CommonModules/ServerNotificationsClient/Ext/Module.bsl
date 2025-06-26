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

// Completion check of the intermittent wait for the handlers of
// the BeforeRecurringClientDataSendToServer event.
//
// Parameters:
//  CounterName   - String - For example, "StandardSubsystems.MonitoringCenter".
//  Timeout - Number - Timeout before the counter triggers (in seconds).
//  FirstTime     - Boolean - If set to True, returns True after initialization.
//  SessionDate    - Date - The return value (in cases when a custom counter is required).
//
// Returns:
//  Boolean - True if the last count ended, and a new one started.
//
// Example:
//	CounterName = "StandardSubsystems.MonitoringCenter";
//	If Not ServerNotificationsClient.TimeoutExpired(CounterName) Then
//		Return;
//	EndIf;
//
Function TimeoutExpired(CounterName, Timeout = 1200, FirstTime = False, SessionDate = '00010101') Export
	
	DataReceiptStatus = DataReceiptStatus();
	SessionDate = DataReceiptStatus.CurrentSessionDateToCheckWaitingCounter;
	If Not ValueIsFilled(CounterName) Then
		Return False;
	EndIf;
	WaitCounters = DataReceiptStatus.WaitCounters;
	
	LastDate = WaitCounters.Get(CounterName);
	If LastDate = Undefined Then
		WaitCounters.Insert(CounterName, SessionDate);
		Return FirstTime;
	EndIf;
	
	If LastDate + Timeout > SessionDate Then
		Return False;
	EndIf;
	
	WaitCounters.Insert(CounterName, SessionDate);
	Return True;
	
EndFunction

// Logs an error caught in the handlers of the events
// BeforeRecurringClientDataSendToServer and
// AfterRecurringReceiptOfClientDataOnServer.
//
// Parameters:
//  ErrorInfo - ErrorInfo
//
// Example:
//	StartMoment = CurrentUniversalDateInMilliseconds();
//	Try
//		If CommonClient.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
//			ModuleMonitoringCenterClientInternal = CommonClient.CommonModule("MonitoringCenterClientInternal");
//			ModuleMonitoringCenterClientInternal.BeforeRecurringClientDataSendToServer(Parameters);
//		EndIf;
//	Exception
//		ServerNotificationsClient.HandleError(ErrorInformation());
//	EndTry;
//	ServerNotificationsClient.AddIndicator(StartMoment,
//		"MonitoringCenterClientInternal.BeforeRecurringClientDataSendToServer");
//
Procedure HandleError(ErrorInfo) Export
	
	EventLogClient.AddMessageForEventLog(
		NStr("en = 'Server notifications.Error getting or processing notifications';",
			CommonClient.DefaultLanguageCode()),
		"Error",
		ErrorProcessing.DetailErrorDescription(ErrorInfo));
	
EndProcedure

// Adds a performance indicator to the handlers of the event
// BeforeRecurringClientDataSendToServer and
// AfterRecurringReceiptOfClientDataOnServer.
//
// Parameters:
//  StartMoment - Number - CurrentUniversalDateInMilliseconds before the procedure will be called.
//  ProcedureName - String - Full name of the called procedure
//
// Example:
//	StartMoment = CurrentUniversalDateInMilliseconds();
//	Try
//		If CommonClient.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
//			ModuleMonitoringCenterClientInternal = CommonClient.CommonModule("MonitoringCenterClientInternal");
//			ModuleMonitoringCenterClientInternal.BeforeRecurringClientDataSendToServer(Parameters);
//		EndIf;
//	Exception
//		ServerNotificationsClient.HandleError(ErrorInformation());
//	EndTry;
//	ServerNotificationsClient.AddIndicator(StartMoment,
//		"MonitoringCenterClientInternal.BeforeRecurringClientDataSendToServer");
//
Procedure AddIndicator(StartMoment, ProcedureName) Export
	
	Indicators = ApplicationParameters.Get(NestedIndicatorsParameterName());
	AddMainIndicator(Indicators, StartMoment, ProcedureName, , True);
	
EndProcedure

#Region ForCallsFromOtherSubsystems

// Returns the session's UUID obtained from
// the session properties SessionStart and SessionNumber.
//
// Returns:
//   See ServerNotifications.SessionKey
//
Function SessionKey() Export
	
	Return DataReceiptStatus().SessionKey;
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

// Parameters:
//  Interval - Number
//  ShouldReceiveImmediately - Boolean - If set to "True", the next check will make a server call
//                     that returns the notification stack.
//
Procedure AttachServerNotificationReceiptCheckHandler(Interval = 1, ShouldReceiveImmediately = False) Export
	
	If Interval < 1 Then
		Interval = 1;
	ElsIf Interval > 60 Then
		Interval = 60;
	EndIf;
	
	If ShouldReceiveImmediately Then
		DataReceiptStatus().ShouldReceiveImmediately = True;
	EndIf;
	
	AttachIdleHandler("ServerNotificationsReceiptCheckHandler", Interval);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.BeforeStart.
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If Not ClientParameters.Property("ServerNotifications") Then
		Return;
	EndIf;
	
	ServerNotificationsParameters = ClientParameters.ServerNotifications; // See ServerNotifications.ServerNotificationsParametersThisSession
	DataReceiptStatus = DataReceiptStatus();
	FillPropertyValues(DataReceiptStatus, ServerNotificationsParameters);
	Parameters.RetrievedClientParameters.Insert("ServerNotifications");
	Parameters.CountOfReceivedClientParameters = Parameters.CountOfReceivedClientParameters + 1;
	
	SessionDate = CommonClient.SessionDate();
	DataReceiptStatus.StatusUpdateDate = SessionDate;
	DataReceiptStatus.LastReceivedMessageDate = SessionDate;
	DataReceiptStatus.DateOfLastServerCall = SessionDate;
	DataReceiptStatus.WaitingCountersDateAlignmentSecondsNumber = Second(SessionDate);
	DataReceiptStatus.CurrentSessionDateToCheckWaitingCounter = SessionDate;
	
	DataReceiptStatus.IsCheckAllowed = True;
	AttachServerNotificationReceiptCheckHandler();
	
EndProcedure

// See CommonClientOverridable.AfterStart.
Procedure AfterStart() Export
	
	DataReceiptStatus = DataReceiptStatus();
	DataReceiptStatus.IsRecurringDataSendEnabled = True;
	
EndProcedure

#EndRegion

#Region Private

Procedure CheckAndReceiveServerNotifications() Export
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	DataReceiptStatus = DataReceiptStatus();
	Indicators = ?(DataReceiptStatus.ShouldRegisterIndicators, New Array, Undefined);
	If Indicators <> Undefined Then
		If ApplicationParameters = Undefined Then
			ApplicationParameters = New Map;
		EndIf;
		ApplicationParameters.Insert(NestedIndicatorsParameterName(), New Array);
	EndIf;
	
	Try
		CheckGetServerNotificationsWithIndicators(DataReceiptStatus, Indicators);
	Except
		AreServerCallsAllowed = True;
		Try
			StandardSubsystemsServerCall.MetadataObjectName(Type("Undefined"));
		Except
			AreServerCallsAllowed = False;
		EndTry;
		If Not AreServerCallsAllowed Then
			AttachServerNotificationReceiptCheckHandler(15);
			Return;
		EndIf;
		Raise;
	EndTry;
	
	AddMainIndicator(Indicators, StartMoment,
		"ServerNotificationsClient.CheckAndReceiveServerNotifications", True);
	
EndProcedure

Procedure CheckGetServerNotificationsWithIndicators(DataReceiptStatus, Indicators);
	
	If Not DataReceiptStatus.IsCheckAllowed Then
		Return;
	EndIf;
	
	AdditionalParameters = New Map;
	CurrentSessionDate = CommonClient.SessionDate();
	DataReceiptStatus.CurrentSessionDateToCheckWaitingCounter = BegOfMinute(CurrentSessionDate)
		+ DataReceiptStatus.WaitingCountersDateAlignmentSecondsNumber
		- ?(Second(CurrentSessionDate) < DataReceiptStatus.WaitingCountersDateAlignmentSecondsNumber, 60, 0);
	
	Interval = 60;
	AreChatsActive = DataReceiptStatus.CollaborationSystemConnected
		And DataReceiptStatus.IsNewPersonalMessageHandlerAttached
		And DataReceiptStatus.IsRecurringDataSendEnabled
		And DataReceiptStatus.LastReceivedMessageDate + 60 > CurrentSessionDate;
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Try
		TimeConsumingOperationsClient.BeforeRecurringClientDataSendToServer(AdditionalParameters,
			AreChatsActive, Interval);
	Except
		HandleError(ErrorInfo());
	EndTry;
	AddMainIndicator(Indicators, StartMoment,
		"TimeConsumingOperationsClient.BeforeRecurringClientDataSendToServer");
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	AreNotificationsReceived = AreNotificationsReceived(DataReceiptStatus);
	AddMainIndicator(Indicators, StartMoment, "ServerNotificationsClient.AreNotificationsReceived");
	
	ChatsParametersKeyName = "StandardSubsystems.Core.ServerNotifications.ChatsIDs";
	ShouldSendDataRecurrently = TimeoutExpired(
		"StandardSubsystems.Core.ServerNotifications.ShouldSendDataRecurrently",
		DataReceiptStatus.RepeatedDateExportMinInterval * 60);
	
	If ShouldSendDataRecurrently Then
		If DataReceiptStatus.IsRecurringDataSendEnabled Then
			StartMoment = CurrentUniversalDateInMilliseconds();
			Try
				SSLSubsystemsIntegrationClient.BeforeRecurringClientDataSendToServer(
					AdditionalParameters);
			Except
				HandleError(ErrorInfo());
			EndTry;
			AddMainIndicator(Indicators, StartMoment,
				"SSLSubsystemsIntegrationClient.BeforeRecurringClientDataSendToServer");
			
			StartMoment = CurrentUniversalDateInMilliseconds();
			Try
				CommonClientOverridable.BeforeRecurringClientDataSendToServer(
					AdditionalParameters);
			Except
				HandleError(ErrorInfo());
			EndTry;
			AddMainIndicator(Indicators, StartMoment,
				"CommonClientOverridable.BeforeRecurringClientDataSendToServer");
		EndIf;
		
		StartMoment = CurrentUniversalDateInMilliseconds();
		Try
			If CommonClient.SubsystemExists("StandardSubsystems.UsersSessions") Then
				ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
				ModuleIBConnectionsClient.BeforeRecurringClientDataSendToServer(AdditionalParameters,
					AreNotificationsReceived);
			EndIf;
		Except
			HandleError(ErrorInfo());
		EndTry;
		AddMainIndicator(Indicators, StartMoment,
			"IBConnectionsClient.BeforeRecurringClientDataSendToServer");
		
		If DataReceiptStatus.ServiceAdministratorSession Then
			ParameterName = "StandardSubsystems.Core.ServerNotifications.RemovingOutdatedAlerts";
			If TimeoutExpired(ParameterName) Then
				AdditionalParameters.Insert(ParameterName, True);
			EndIf;
		EndIf;
		
		If DataReceiptStatus.PersonalChatID = Undefined
		   And DataReceiptStatus.CollaborationSystemConnected
		   And TimeoutExpired(ChatsParametersKeyName, 300, True) Then
			
			AdditionalParameters.Insert(ChatsParametersKeyName, True);
		EndIf;
	EndIf;
	
	If DataReceiptStatus.DateOfLastServerCall + 60 < CurrentSessionDate Then
		MessagesForEventLog = ApplicationParameters["StandardSubsystems.MessagesForEventLog"];
	EndIf;
	
	If AreNotificationsReceived
	   And Not DataReceiptStatus.ShouldReceiveImmediately
	   And Not ValueIsFilled(AdditionalParameters)
	   And Not ValueIsFilled(MessagesForEventLog) Then
		
		AttachServerNotificationReceiptCheckHandler(Interval);
		Return;
	EndIf;
	
	CommonCallParameters = CommonServerCallNewParameters();
	CommonCallParameters.LastNotificationDate = DataReceiptStatus.LastNotificationDate;
	If ValueIsFilled(AdditionalParameters) Then
		CommonCallParameters.Insert("AdditionalParameters", AdditionalParameters);
	EndIf;
	If ShouldSendDataRecurrently Then
		CommonCallParameters.Insert("ShouldSendDataRecurrently",
			DataReceiptStatus.IsRecurringDataSendEnabled);
	EndIf;
	MessagesNew = ApplicationParameters["StandardSubsystems.MessagesForEventLog"];
	If ValueIsFilled(MessagesNew) Then
		CommonCallParameters.Insert("MessagesForEventLog", MessagesNew);
	EndIf;
	If Indicators <> Undefined Then
		CommonCallParameters.Insert("ShouldRegisterIndicators", True);
	EndIf;
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	CommonCallResult = ServerNotificationsInternalServerCall.SessionUndeliveredServerNotifications(
		CommonCallParameters);
	AddMainIndicator(Indicators, StartMoment,
		"ServerNotificationsInternalServerCall.SessionUndeliveredServerNotifications");
	
	If MessagesNew <> Undefined Then
		MessagesNew.Clear();
	EndIf;
	
	If CommonCallResult.Property("Indicators") Then
		CommonClientServer.SupplementArray(Indicators, CommonCallResult.Indicators);
	EndIf;
	
	If CommonCallResult.Property("ServerNotifications") Then
		StartMoment = CurrentUniversalDateInMilliseconds();
		For Each ServerNotification In CommonCallResult.ServerNotifications Do
			ProcessServerNotificationOnClient(DataReceiptStatus, ServerNotification);
		EndDo;
		AddMainIndicator(Indicators, StartMoment,
			"ServerNotificationsClient.ProcessServerNotificationOnClient");
	EndIf;
	DataReceiptStatus.ShouldReceiveImmediately = False;
	
	AdditionalResults = CommonClientServer.StructureProperty(CommonCallResult,
		"AdditionalResults", New Map);
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Try
		TimeConsumingOperationsClient.AfterRecurringReceiptOfClientDataOnServer(
			AdditionalResults, AreChatsActive, Interval);
	Except
		HandleError(ErrorInfo());
	EndTry;
	AddMainIndicator(Indicators, StartMoment,
		"TimeConsumingOperationsClient.AfterRecurringReceiptOfClientDataOnServer");
	
	If ShouldSendDataRecurrently Then
		If DataReceiptStatus.IsRecurringDataSendEnabled Then
			StartMoment = CurrentUniversalDateInMilliseconds();
			Try
				SSLSubsystemsIntegrationClient.AfterRecurringReceiptOfClientDataOnServer(
					AdditionalResults);
			Except
				HandleError(ErrorInfo());
			EndTry;
			AddMainIndicator(Indicators, StartMoment,
				"SSLSubsystemsIntegrationClient.AfterRecurringReceiptOfClientDataOnServer");
			
			StartMoment = CurrentUniversalDateInMilliseconds();
			Try
				CommonClientOverridable.AfterRecurringReceiptOfClientDataOnServer(
					AdditionalResults);
			Except
				HandleError(ErrorInfo());
			EndTry;
			AddMainIndicator(Indicators, StartMoment,
				"CommonClientOverridable.AfterRecurringReceiptOfClientDataOnServer");
		EndIf;
		
		StartMoment = CurrentUniversalDateInMilliseconds();
		Try
			If CommonClient.SubsystemExists("StandardSubsystems.UsersSessions") Then
				ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
				ModuleIBConnectionsClient.AfterRecurringReceiptOfClientDataOnServer(
					AdditionalResults);
			EndIf;
		Except
			HandleError(ErrorInfo());
		EndTry;
		AddMainIndicator(Indicators, StartMoment,
			"IBConnectionsClient.AfterRecurringReceiptOfClientDataOnServer");
		
		ChatsIDs = AdditionalResults.Get(ChatsParametersKeyName);
		If ChatsIDs <> Undefined Then
			FillPropertyValues(DataReceiptStatus, ChatsIDs);
			StartMoment = CurrentUniversalDateInMilliseconds();
			AttachNewMessageHandler(DataReceiptStatus);
			AddMainIndicator(Indicators, StartMoment,
				"ServerNotificationsClient.AttachNewMessageHandler");
		EndIf;
		
		If CommonCallResult.Property("CollaborationSystemConnected") Then
			DataReceiptStatus.CollaborationSystemConnected = CommonCallResult.CollaborationSystemConnected;
		EndIf;
	EndIf;
	
	If CommonCallResult.Property("LastNotificationDate") Then
		DataReceiptStatus.LastNotificationDate = CommonCallResult.LastNotificationDate;
	EndIf;
	If CommonCallResult.Property("MinCheckInterval") Then
		DataReceiptStatus.MinimumPeriod = CommonCallResult.MinCheckInterval;
	EndIf;
	DataReceiptStatus.StatusUpdateDate = CommonClient.SessionDate();
	DataReceiptStatus.DateOfLastServerCall = DataReceiptStatus.StatusUpdateDate;
	
	If Interval > DataReceiptStatus.MinimumPeriod Then
		Interval = DataReceiptStatus.MinimumPeriod;
	EndIf;
	
	AttachServerNotificationReceiptCheckHandler(Interval);
	
EndProcedure

Procedure AddMainIndicator(Indicators, StartMoment, ProcedureName,
			Shared = False, Nested = False, Duration = 0)
	
	If Indicators = Undefined Then
		Return;
	EndIf;
	
	Duration = CurrentUniversalDateInMilliseconds() - StartMoment;
	If Not Shared And Not ValueIsFilled(Duration) Then
		Return;
	EndIf;
	
	Text = Format(Duration / 1000, "ND=6; NFD=3; NZ=000,000; NLZ=") + " " + ProcedureName;
	
	If Shared Then
		Indicators.Insert(0, Text);
		WriteIndicators(Indicators, Duration);
		Return;
	Else
		Indicators.Add("  " + Text);
	EndIf;
	
	If Nested Then
		Return;
	EndIf;
	
	NestedIndicators = ApplicationParameters.Get(NestedIndicatorsParameterName());
	For Each NestedIndicator In NestedIndicators Do
		Indicators.Add("  " + NestedIndicator);
	EndDo;
	NestedIndicators.Clear();
	
EndProcedure

Function NestedIndicatorsParameterName()
	Return "StandardSubsystems.Core.ServerNotifications.Indicators";
EndFunction

Procedure WriteIndicators(Indicators, TotalDuration)
	
	Comment = StrConcat(Indicators, Chars.LF);
	ServerCallMethodName = "ServerNotificationsInternalServerCall.SessionUndeliveredServerNotifications";
	
	If TotalDuration < 50
	   And StrFind(Comment, ServerCallMethodName) = 0 Then
		Return;
	EndIf;
	
	ServerNotificationsInternalServerCall.WritePerformanceIndicators(Comment);
	
EndProcedure

Procedure ProcessServerNotificationOnClient(DataReceiptStatus, ServerNotification)
	
	If IsNotificationReceived(DataReceiptStatus, ServerNotification) Then
		Return;
	EndIf;
	
	NameOfAlert = ServerNotification.NameOfAlert;
	Result     = ServerNotification.Result;
	
	If NameOfAlert = "StandardSubsystems.Core.ServerNotifications.ShouldRegisterIndicators" Then
		DataReceiptStatus.ShouldRegisterIndicators = (Result = True);
		Return;
	ElsIf NameOfAlert = "StandardSubsystems.Core.ServerNotifications.CollaborationSystemConnected" Then
		DataReceiptStatus.CollaborationSystemConnected = (Result = True);
		Return;
	EndIf;
	
	Notification = DataReceiptStatus.Notifications.Get(NameOfAlert);
	If Notification = Undefined Then
		Return;
	EndIf;
	
	DataProcessorModule = CommonClient.CommonModule(Notification.NotificationReceiptModuleName);
	Try
		DataProcessorModule.OnReceiptServerNotification(NameOfAlert, Result);
	Except
		ErrorInfo = ErrorInfo();
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot execute the ""%1"" procedure due to:
			           |%2';"),
			Notification.NotificationReceiptModuleName + ".OnReceiptServerNotification",
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		EventLogClient.AddMessageForEventLog(
			NStr("en = 'Server notifications.An error occurred when processing the received message';",
				CommonClient.DefaultLanguageCode()),
			"Error",
			ErrorText);
	EndTry;
	
EndProcedure

Function AreNotificationsReceived(DataReceiptStatus)
	
	AttachNewMessageHandler(DataReceiptStatus);
	
	Boundary = DataReceiptStatus.StatusUpdateDate + DataReceiptStatus.MinimumPeriod;
	
	Inventory = Boundary - CommonClient.SessionDate();
	
	If Inventory > 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// See NewReceiptStatus
Function DataReceiptStatus()
	
	AppParameterName = "StandardSubsystems.Core.ServerNotifications";
	DataReceiptStatus = ApplicationParameters.Get(AppParameterName);
	If DataReceiptStatus = Undefined Then
		DataReceiptStatus = NewReceiptStatus();
		ApplicationParameters.Insert(AppParameterName, DataReceiptStatus);
	EndIf;
	
	Return DataReceiptStatus;
	
EndFunction

// Returns:
//  Structure:
//   * LastNotificationDate - Date
//   * AdditionalParameters - Map
//   * MessagesForEventLog - Undefined, ValueList
//   * ShouldSendDataRecurrently - Boolean
//   * ShouldRegisterIndicators - Boolean
//
Function CommonServerCallNewParameters() Export
	
	Result = New Structure;
	Result.Insert("LastNotificationDate",  '00010101');
	
	Return Result;
	
EndFunction

// Returns:
//  Structure:
//   * IsCheckAllowed - Boolean - Is set to True in the BeforeStart procedure.
//   * ShouldRegisterIndicators - Boolean
//   * ServiceAdministratorSession - Boolean
//   * IsRecurringDataSendEnabled - Boolean - Is set to True in the AfterStart procedure.
//   * RepeatedDateExportMinInterval - 
//   * SessionKey - See ServerNotifications.SessionKey
//   * IBUserID - UUID
//   * StatusUpdateDate - Date
//   * LastReceivedMessageDate - Date
//   * MinimumPeriod - Number - Time interval in seconds.
//   * LastNotificationDate - Date
//   * Notifications - See CommonOverridable.OnAddServerNotifications.Notifications
//   * ReceivedNotifications - Array of String - UUID strings of the received messages.
//   * CollaborationSystemConnected - Boolean
//   * PersonalChatID - Undefined - Chat is unavailable.
//                                    - CollaborationSystemConversationID - ID of the chat
//        "ServerNotifications <Infobase user ID>".
//
//   * GlobalChatID - Undefined - Chat is unavailable.
//                                   - CollaborationSystemConversationID - ID of the chat
//        "ServerNotifications".
//   * IsNewPersonalMessageHandlerAttached - Boolean
//   * IsNewGlobalMessageHandlerAttached - Boolean
//   * DateOfLastServerCall - Date
//   * CurrentSessionDateToCheckWaitingCounter - Date
//   * WaitingCountersDateAlignmentSecondsNumber - Number
//   * WaitCounters - Map of KeyAndValue:
//      ** Key - String - Counter name
//      ** Value - Date - Last time the counter triggered.
//   * ShouldReceiveImmediately - Boolean - If set to "True", the server call is made unconditionally.
//
Function NewReceiptStatus()
	
	State = New Structure;
	State.Insert("IsCheckAllowed", False);
	State.Insert("ShouldRegisterIndicators", False);
	State.Insert("ServiceAdministratorSession", False);
	State.Insert("IsRecurringDataSendEnabled", False);
	State.Insert("RepeatedDateExportMinInterval", 1);
	State.Insert("SessionKey", "");
	State.Insert("IBUserID",
		CommonClientServer.BlankUUID());
	State.Insert("StatusUpdateDate", '00010101');
	State.Insert("LastReceivedMessageDate", '00010101');
	State.Insert("MinimumPeriod", 60);
	State.Insert("LastNotificationDate", '00010101');
	State.Insert("Notifications", New Map);
	State.Insert("ReceivedNotifications", New Array);
	State.Insert("CollaborationSystemConnected", False);
	State.Insert("PersonalChatID", Undefined);
	State.Insert("GlobalChatID", Undefined);
	State.Insert("IsNewPersonalMessageHandlerAttached", False);
	State.Insert("IsNewGlobalMessageHandlerAttached", False);
	State.Insert("DateOfLastServerCall", '00010101');
	State.Insert("CurrentSessionDateToCheckWaitingCounter", '00010101');
	State.Insert("WaitingCountersDateAlignmentSecondsNumber", 0);
	State.Insert("WaitCounters", New Map);
	State.Insert("ShouldReceiveImmediately", False);
	
	Return State;
	
EndFunction

Procedure AttachNewMessageHandler(DataReceiptStatus)
	
	If DataReceiptStatus.PersonalChatID <> Undefined
	   And Not DataReceiptStatus.IsNewPersonalMessageHandlerAttached Then
		
		Context = New Structure("DataReceiptStatus", DataReceiptStatus);
		Try
			CollaborationSystem.BeginAttachNewMessagesHandler(
				New NotifyDescription("AfterAttachingNewPersonalMessageHandler", ThisObject, Context,
					"AfterNewPersonalMessageHandlerAttachError", ThisObject),
				DataReceiptStatus.PersonalChatID,
				New NotifyDescription("OnReceiptNewInteractionSystemPersonalMessage", ThisObject, Context,
					"OnInteractionSystemNewPersonalMessageReceiptError", ThisObject),
				Undefined);
		Except
			AfterNewPersonalMessageHandlerAttachError(ErrorInfo(), False, Context);
		EndTry;
	EndIf;
	
	If DataReceiptStatus.GlobalChatID <> Undefined
	   And Not DataReceiptStatus.IsNewGlobalMessageHandlerAttached Then
		
		Context = New Structure("DataReceiptStatus", DataReceiptStatus);
		Try
			CollaborationSystem.BeginAttachNewMessagesHandler(
				New NotifyDescription("AfterAttachingNewGroupMessageHandler", ThisObject, Context,
					"AfterNewGlobalMessageHandlerAttachError", ThisObject),
				DataReceiptStatus.GlobalChatID,
				New NotifyDescription("OnReceiptNewInteractionSystemGlobalMessage", ThisObject, Context,
					"OnInteractionSystemNewGlobalMessageReceiptError", ThisObject),
				Undefined);
		Except
			AfterNewGlobalMessageHandlerAttachError(ErrorInfo(), False, Context);
		EndTry;
	EndIf;
	
EndProcedure

Procedure AfterAttachingNewPersonalMessageHandler(Context) Export
	
	Context.DataReceiptStatus.IsNewPersonalMessageHandlerAttached = True;
	
EndProcedure

Procedure AfterNewPersonalMessageHandlerAttachError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	EventLogClient.AddMessageForEventLog(
		NStr("en = 'Server notifications.An error occurred when connecting the handler of new personal messages';",
			CommonClient.DefaultLanguageCode()),
		"Error",
		ErrorProcessing.DetailErrorDescription(ErrorInfo));
	
EndProcedure

Procedure OnReceiptNewInteractionSystemPersonalMessage(Message, Context) Export
	
	OnReceiptNewInteractionSystemMessage(Message, Context);
	
EndProcedure

Procedure OnInteractionSystemNewPersonalMessageReceiptError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	EventLogClient.AddMessageForEventLog(
		NStr("en = 'Server notifications.An error occurred when receiving a new personal message';",
			CommonClient.DefaultLanguageCode()),
		"Error",
		ErrorProcessing.DetailErrorDescription(ErrorInfo));
	
EndProcedure

Procedure AfterAttachingNewGroupMessageHandler(Context) Export
	
	Context.DataReceiptStatus.IsNewGlobalMessageHandlerAttached = True;
	
EndProcedure

Procedure AfterNewGlobalMessageHandlerAttachError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	EventLogClient.AddMessageForEventLog(
		NStr("en = 'Server notifications.An error occurred when connecting the handler of new common messages';",
			CommonClient.DefaultLanguageCode()),
		"Error",
		ErrorProcessing.DetailErrorDescription(ErrorInfo));
	
EndProcedure

Procedure OnReceiptNewInteractionSystemGlobalMessage(Message, Context) Export
	
	OnReceiptNewInteractionSystemMessage(Message, Context);
	
EndProcedure

Procedure OnInteractionSystemNewGlobalMessageReceiptError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	EventLogClient.AddMessageForEventLog(
		NStr("en = 'Server notifications.An error occurred when receiving a new common message';",
			CommonClient.DefaultLanguageCode()),
		"Error",
		ErrorProcessing.DetailErrorDescription(ErrorInfo));
	
EndProcedure

// Parameters:
//  Message - CollaborationSystemMessage
//  Context  - Structure:
//    * DataReceiptStatus - See NewReceiptStatus
//
Procedure OnReceiptNewInteractionSystemMessage(Message, Context)
	
	DataReceiptStatus = Context.DataReceiptStatus;
	
	If Not DataReceiptStatus.IsCheckAllowed
	 Or ApplicationParameters = Undefined Then
		Return;
	EndIf;
	
	DataReceiptStatus.LastReceivedMessageDate = CommonClient.SessionDate();
	
	Try
		Data = Message.Data; // See ServerNotifications.MessageNewData
	Except
		ErrorInfo = ErrorInfo();
		LongDesc = New Structure;
		LongDesc.Insert("Date", Message.Date);
		LongDesc.Insert("Id", String(Message.ID));
		LongDesc.Insert("Conversation", String(Message.Conversation));
		LongDesc.Insert("Text", TrimAll(Message.Text));
		LongDesc.Insert("DetailErrorDescription",
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		ServerNotificationsInternalServerCall.LogErrorGettingDataFromMessage(LongDesc);
		Return;
	EndTry;
	
	If TypeOf(Data) <> Type("Structure")
	 Or Not Data.Property("NameOfAlert") Then
		Return;
	EndIf;
	
	If Data.NameOfAlert <> "NoServerNotifications" Then
		If Data.SMSMessageRecipients <> Undefined Then
			SessionsKeys = Data.SMSMessageRecipients.Get(DataReceiptStatus.IBUserID);
			If TypeOf(SessionsKeys) <> Type("Array")
			 Or SessionsKeys.Find(DataReceiptStatus.SessionKey) = Undefined
			   And SessionsKeys.Find("*") = Undefined Then
				Return;
			EndIf;
		EndIf;
		ProcessServerNotificationOnClient(DataReceiptStatus, Data);
		If Not Data.WasSentFromQueue Then
			Return;
		EndIf;
	EndIf;
	
	LastNotificationDate = Data.Errors.Get(DataReceiptStatus.IBUserID);
	If LastNotificationDate = Undefined Then
		LastNotificationDate = Data.Errors.Get("AllUsers");
		If LastNotificationDate = Undefined Then
			LastNotificationDate = Data.AddedOn;
			DataReceiptStatus.StatusUpdateDate = CommonClient.SessionDate();
		EndIf;
	EndIf;
	If DataReceiptStatus.LastNotificationDate < LastNotificationDate Then
		DataReceiptStatus.LastNotificationDate = LastNotificationDate;
	EndIf;
	
EndProcedure

Function IsNotificationReceived(DataReceiptStatus, ServerNotification)
	
	If ServerNotification.AddedOn < DataReceiptStatus.LastNotificationDate Then
		Return True;
	EndIf;
	
	ReceivedNotifications = DataReceiptStatus.ReceivedNotifications;
	
	If ReceivedNotifications.Find(ServerNotification.NotificationID) <> Undefined Then
		Return True;
	EndIf;
	
	ReceivedNotifications.Add(ServerNotification.NotificationID);
	If ReceivedNotifications.Count() > 100 Then
		ReceivedNotifications.Delete(0);
	EndIf;
	
	Return False;
	
EndFunction

#EndRegion
