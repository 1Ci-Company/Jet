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

// Intended for the CommonOverridable.OnAddServerNotifications procedure.
//
// Parameters:
//  Name - String - Notification name matching the structure property name.
//
// Returns:
//  Structure:
//   * Name - String - Notification name.
//
//   * NotificationSendModuleName - String - Name of the server module containing the export procedure
//                    OnSendServerNotification. For example, "IBConnections".
//                    For a use case, see the StandardSubsystemsServer common module.
//                    An optional parameter. If not passed, the procedure will not be called.
//                    For example, to notify about functional option changes immediately after its constant is reassigned
//                    (instead of tracking changes in the scheduled job).
//                    
//                    
//
//   * NotificationReceiptModuleName - String - Name of the client common module containing the export procedure
//                    OnReceiptServerNotification. For example, "IBConnectionsClient".
//                    For a use case, see the StandardSubsystemsClient common module.
//
//   * Parameters - Arbitrary - Any serializable value to pass as a parameter to the OnSendServerNotification procedure.
//                    Try to make the size of serialized values as small as possible.
//                    For example, the details of session extensions and metadata it order to calculate
//                    the added and removed extensions and patches in a scheduled job upon calling
//                    OnSendServerNotification and sending a notification containing the diff of the given sessions.
//                    
//                    
//
//   * VerificationPeriod - Number - Timeout (in seconds) before calling OnSendServerNotification
//                         in order to check the status of the server and notification (if required).
//                         The start value is 20 minutes.
//                         If the passed timeout is less than 60 seconds, it will be increased to "60".
//                         Note: The actual minimal interval in SaaS might be greater and vary (5 to 10 minutes).
//                         
//                         
//
//
Function NewServerNotification(Name) Export
	
	Result = New Structure;
	Result.Insert("Name", Name);
	Result.Insert("NotificationSendModuleName", "");
	Result.Insert("NotificationReceiptModuleName", "");
	Result.Insert("Parameters", Undefined);
	Result.Insert("VerificationPeriod", 20*60);
	
	Return Result;
	
EndFunction

// Queues a server notification to be delivered to the client.
// It will be delivered by the Collaboration System or within a server call.
// 
//
// Parameters:
//  NameOfAlert - String - See NewServerNotification.Name.
//  
//  Result - Arbitrary - Any serializable value to send to the client within the notification.
//             Try to make the size of serialized values as small as possible.
//             The recommended size is less than 1 KB.
//
//  SMSMessageRecipients - Undefined - All users (all sessions).
//               If an empty map is passed, then return.
//           - Map of KeyAndValue:
//              * Key - UUID - infobase user ID.
//              * Value - Array of See ServerNotifications.SessionKey
//
//  SendImmediately - Boolean - If True, tries to send a message immediately via the
//               Collaboration System, and it fails, adds it to the queue.
//               The handlers of the OnSendServerNotification event don't support immediate sending.
//               Note: A failed request to the Collaboration System takes about (3–5 sec)*2,
//               a successful one takes about (50 msec)*2. This is particularly important when developing transactions.
//
Procedure SendServerNotification(NameOfAlert, Result, SMSMessageRecipients, SendImmediately = False) Export
	
	SendServerNotificationWithGroupID(NameOfAlert, Result, SMSMessageRecipients, SendImmediately);
	
EndProcedure

// Logs an error caught in the handlers of the
// OnReceiptRecurringClientDataOnServer event.
//
// Parameters:
//  ErrorInfo - ErrorInfo
//
// Example:
//	StartMoment = CurrentUniversalDateInMilliseconds();
//	Try
//		If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
//			ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
//			ModuleMonitoringCenterInternal.OnReceiptRecurringClientDataOnServer(Parameters, Results);
//		EndIf;
//	Exception
//		ServerNotifications.HandleError(ErrorInfo());
//	EndTry;
//	ServerNotifications.AddIndicator(Results, StartMoment,
//		"MonitoringCenterInternal.OnReceiptRecurringClientDataOnServer");
//
Procedure HandleError(ErrorInfo) Export
	
	WriteLogEvent(
		NStr("en = 'Server notifications.Error getting or processing notifications';",
			Common.DefaultLanguageCode()),
		EventLogLevel.Error,,,
		ErrorProcessing.DetailErrorDescription(ErrorInfo));
	
EndProcedure

// Adds a performance indicator to the handlers of the event
// OnReceiptRecurringClientDataOnServer.
//
// Parameters:
//  Results - See CommonOverridable.OnReceiptRecurringClientDataOnServer.Results
//  StartMoment - Number - CurrentUniversalDateInMilliseconds before the procedure will be called.
//  ProcedureName - String - Full name of the called procedure
//
// Example:
//	StartMoment = CurrentUniversalDateInMilliseconds();
//	Try
//		If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
//			ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
//			ModuleMonitoringCenterInternal.OnReceiptRecurringClientDataOnServer(Parameters, Results);
//		EndIf;
//	Exception
//		ServerNotifications.HandleError(ErrorInfo());
//	EndTry;
//	ServerNotifications.AddIndicator(Results, StartMoment,
//		"MonitoringCenterInternal.OnReceiptRecurringClientDataOnServer");
//
Procedure AddIndicator(Results, StartMoment, ProcedureName) Export
	
	Indicators = Results.Get(NestedIndicatorsParameterName());
	AddMainIndicator(Indicators, StartMoment, ProcedureName);
	
EndProcedure

#Region ForCallsFromOtherSubsystems

// Returns the session's UUID obtained from
// the session properties SessionStart and SessionNumber.
//
// Parameters:
//  Session - InfoBaseSession
//        - Undefined - Use the current session.
//
// Returns:
//  String - String of the following format: "<SessionStart> <SessionNumber>".
//    For example, "2022.03.07 05:01:09 8342".
//
Function SessionKey(Session = Undefined) Export
	
	If Session = Undefined Then
		Session = GetCurrentInfoBaseSession();
	EndIf;
	
	// ACC:1367-off - No.763.1.1. Arbitrary formats are acceptable
	// as they are intended for internal use only and hidden from the user.
	Return Format(Session.SessionStarted, "DF='yyyy.MM.dd HH:mm:ss'") + " "
		+ Format(Session.SessionNumber, "NZ=0; NG=");
	// ACC:1367-on
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddClientParametersOnStart.
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	Parameters.Insert("ServerNotifications", ServerNotificationsParametersThisSession());
	
EndProcedure

// See JobsQueueOverridable.OnDefineHandlerAliases
Procedure OnDefineHandlerAliases(NamesAndAliasesMap) Export
	
	NamesAndAliasesMap.Insert(
		Metadata.ScheduledJobs.SendServerNotificationsToClients.MethodName);
	
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport.
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.Constants.ServerNotificationsSendStatus);
	Types.Add(Metadata.InformationRegisters.PeriodicServerNotifications);
	Types.Add(Metadata.InformationRegisters.SentServerNotifications);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Main procedures and functions.

// Returns:
//  Structure:
//    * GroupID  - UUID - Notification group ID (for writing to the register).
//                           - Undefined - No need to provide.
//    * NotificationTypeInGroup - UUID - ID of the notification type in the notification group.
//                           - Undefined - No need to provide.
//    * DeliveryDeferral     - Number  - If "0", write to the Collaboration System with the scheduled job (unless it must be sent immediately).
//                                      Otherwise, the timeout in seconds before writing the message to the Collaboration System.
//                                      If the passed timeout exceeds 5 seconds, it will be reduced to "5".
//    * Replace             - Boolean - Flag indicating whether the last undelivered notification of the given type in the group must be
//                                      replaced with a new one considering the specified delay (excluding the elapsed time).
//                                      If the delay is more than 0, ShouldSendImmediately is ignored.
//
//    * LogEventOnDeliveryDeferral     - String - Event name that will be logged upon the delayed delivery.
//                                                Applicable if "Replace" is set to True.
//    * LogCommentOnDeliveryDeferral - String - Event comment for the Event Log.
//
Function AdditionalSendingParameters() Export
	
	Result = New Structure;
	Result.Insert("GroupID");
	Result.Insert("NotificationTypeInGroup");
	Result.Insert("Replace", False);
	Result.Insert("DeliveryDeferral", 0);
	Result.Insert("LogEventOnDeliveryDeferral", "");
	Result.Insert("LogCommentOnDeliveryDeferral", "");
	
	Return Result;
	
EndFunction

// Parameters:
//  NameOfAlert  - See SendServerNotification.NameOfAlert
//  Result      - See SendServerNotification.Result
//  SMSMessageRecipients       - See SendServerNotification.SMSMessageRecipients
//  SendImmediately - See SendServerNotification.SendImmediately
//
//  AdditionalParameters - See AdditionalSendingParameters
//
Procedure SendServerNotificationWithGroupID(NameOfAlert, Result, SMSMessageRecipients,
			SendImmediately, AdditionalSendingParameters = Undefined) Export
	
	If SMSMessageRecipients <> Undefined And Not ValueIsFilled(SMSMessageRecipients) Then
		Return;
	EndIf;
	
	NotificationContent = NotificationNewContent();
	NotificationContent.NameOfAlert = NameOfAlert;
	NotificationContent.Result     = Result;
	NotificationContent.SMSMessageRecipients      = SMSMessageRecipients;
	
	If TimeConsumingOperations.ShouldSkipNotification(NotificationContent) Then
		Return;
	EndIf;
	
	If SendImmediately
	   And ServerNotificationsInternalCached.IsSessionSendServerNotificationsToClients() Then
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'In procedure %1, you cannot specify value %2 for parameter %3
			           |when calling from procedures %4.';"),
			"ServerNotifications.SendServerNotification",
			"True",
			"SendImmediately",
			"OnSendServerNotification");
		Raise ErrorText;
	EndIf;
	
	NotificationID = Lower(New UUID);
	AddedOn = CurrentSessionDate();
	DateAddedMilliseconds = Milliseconds();
	AdditionalParameters = ?(AdditionalSendingParameters = Undefined,
		AdditionalSendingParameters(), AdditionalSendingParameters);
	
	DeliveryDeferral = AdditionalParameters.DeliveryDeferral;
	
	If AdditionalParameters.Replace Then
		DeleteLastUndeliveredNotification(AdditionalParameters.GroupID,
			AdditionalParameters.NotificationTypeInGroup, DeliveryDeferral,
			AddedOn, DateAddedMilliseconds);
	EndIf;
	
	If Not ValueIsFilled(SMSMessageRecipients)
	 Or SMSMessageRecipients.Count() > 27 Then
		AddresseesIDs = "";
	Else
		List = New Array;
		For Each KeyAndValue In SMSMessageRecipients Do
			List.Add(Lower(KeyAndValue.Key));
		EndDo;
		AddresseesIDs = StrConcat(List, Chars.LF);
	EndIf;
	
	RecordSet = ServiceRecordSet(InformationRegisters.SentServerNotifications);
	RecordSet.Filter.NotificationID.Set(NotificationID);
	NewRecord = RecordSet.Add();
	NewRecord.NotificationID = NotificationID;
	NewRecord.AddedOn = AddedOn;
	NewRecord.DateAddedMilliseconds = DateAddedMilliseconds;
	NewRecord.SMSMessageRecipients = AddresseesIDs;
	NewRecord.NotificationContent = New ValueStorage(NotificationContent);
	NewRecord.GroupID = Lower(AdditionalParameters.GroupID);
	NewRecord.NotificationTypeInGroup = Lower(AdditionalParameters.NotificationTypeInGroup);
	
	If Not Common.SeparatedDataUsageAvailable() Then
		RecordSet.Filter.DataAreaAuxiliaryData.Set(0);
		NewRecord.DataAreaAuxiliaryData = 0;
	EndIf;
	
	RunDeferredDelivery = False;
	
	If ValueIsFilled(DeliveryDeferral) Then
		RunDeferredDelivery = True;
		
		If DeliveryDeferral > 5 Then
			NewRecord.DeferralOfWritingToCollaborationSystem = 5;
		Else
			NewRecord.DeferralOfWritingToCollaborationSystem = DeliveryDeferral;
		EndIf;
		
	ElsIf SendImmediately
	        And IsCurrentUserRegisteredInInteractionSystem() Then
		
		If SendMessageImmediately(NotificationID, AddedOn, NotificationContent) Then
			NewRecord.CollaborationSystemRecordDate = CurrentSessionDate();
			NewRecord.DateWrittenToCollaborationSystemMilliseconds = Milliseconds();
		EndIf;
		
	ElsIf SendImmediately Then
		NewRecord.DeferralOfWritingToCollaborationSystem = 0.1;
	EndIf;
	
	If ValueIsFilled(NewRecord.DeferralOfWritingToCollaborationSystem)
	   And Not CollaborationSystemConnected() Then
		
		NewRecord.DeferralOfWritingToCollaborationSystem = 0;
		RunDeferredDelivery = False;
	EndIf;
	
	RecordSet.Write();
	
	If RunDeferredDelivery Then
		Launched = False;
		StartDeliverDeferredServerNotifications(Launched);
		If Launched And ValueIsFilled(AdditionalParameters.LogEventOnDeliveryDeferral) Then
			Try
				Raise NStr("en = 'Call stack:';");
			Except
				CallStack = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			EndTry;
			Comment = AdditionalParameters.LogCommentOnDeliveryDeferral;
			Comment = Comment + ?(ValueIsFilled(Comment), Chars.LF, "") + CallStack;
			WriteLogEvent(AdditionalParameters.LogEventOnDeliveryDeferral,
				EventLogLevel.Information,,, Comment);
		EndIf;
	EndIf;
	
EndProcedure

// Intended for the SendServerNotificationWithGroupID procedure.
Procedure DeleteLastUndeliveredNotification(GroupID, NotificationTypeInGroup,
			DeliveryDeferral, AddedOn, DateAddedMilliseconds)
	
	Query = New Query;
	Query.SetParameter("GroupID",  Lower(GroupID));
	Query.SetParameter("NotificationTypeInGroup", Lower(NotificationTypeInGroup));
	Query.Text =
	"SELECT TOP 1
	|	SentServerNotifications.NotificationID AS NotificationID,
	|	SentServerNotifications.AddedOn AS AddedOn,
	|	SentServerNotifications.DateAddedMilliseconds AS DateAddedMilliseconds,
	|	SentServerNotifications.DeferralOfWritingToCollaborationSystem AS DeferralOfWritingToCollaborationSystem,
	|	SentServerNotifications.CollaborationSystemRecordDate AS CollaborationSystemRecordDate,
	|	SentServerNotifications.DateWrittenToCollaborationSystemMilliseconds AS DateWrittenToCollaborationSystemMilliseconds
	|FROM
	|	InformationRegister.SentServerNotifications AS SentServerNotifications
	|WHERE
	|	SentServerNotifications.GroupID = &GroupID
	|	AND SentServerNotifications.NotificationTypeInGroup = &NotificationTypeInGroup
	|
	|ORDER BY
	|	SentServerNotifications.AddedOn DESC,
	|	SentServerNotifications.DateAddedMilliseconds DESC";
	
	Selection = Query.Execute().Select();
	If Not Selection.Next() Then
		DeliveryDeferral = 0;
		Return;
	EndIf;
	
	If ValueIsFilled(Selection.CollaborationSystemRecordDate) Then
		TimePassed = AddedOn - Selection.CollaborationSystemRecordDate
			+ (DateAddedMilliseconds - Selection.DateWrittenToCollaborationSystemMilliseconds) / 1000;
	Else
		TimePassed = AddedOn - Selection.AddedOn
			+ (DateAddedMilliseconds - Selection.DateAddedMilliseconds) / 1000;
	EndIf;
	TimePassed = Round(TimePassed, 1, RoundMode.Round15as20);
	DeliveryDeferral = DeliveryDeferral - TimePassed;
	
	If DeliveryDeferral < 0 Then
		DeliveryDeferral = 0;
	EndIf;
	
	If ValueIsFilled(Selection.CollaborationSystemRecordDate) Then
		Return;
	EndIf;
	
	RecordSet = ServiceRecordSet(InformationRegisters.SentServerNotifications);
	RecordSet.Filter.NotificationID.Set(Selection.NotificationID);
	RecordSet.Write();
	
EndProcedure

// Intended for the SendServerNotificationWithGroupID procedure.
Function SendMessageImmediately(NotificationID, AddedOn, NotificationContent)
	
	Data = MessageNewData();
	Data.NameOfAlert           = NotificationContent.NameOfAlert;
	Data.Result               = NotificationContent.Result;
	Data.SMSMessageRecipients                = NotificationContent.SMSMessageRecipients;
	Data.NotificationID = NotificationID;
	Data.AddedOn          = AddedOn;
	Data.WasSentFromQueue     = False;
	
	If ValueIsFilled(Data.SMSMessageRecipients) And Data.SMSMessageRecipients.Count() = 1 Then
		For Each KeyAndValue In Data.SMSMessageRecipients Do
			Break;
		EndDo;
		ConversationID = PersonalChatID(KeyAndValue.Key);
	Else
		ConversationID = GlobalChatID();
	EndIf;
	
	Return SendMessage(Data, ConversationID);
	
EndFunction

Function Milliseconds()
	
	DateInMilliseconds = CurrentUniversalDateInMilliseconds();
	
	Return DateInMilliseconds - Int(DateInMilliseconds/1000)*1000;
	
EndFunction

// Parameters:
//  GroupID  - UUID - ID of the notification type.
//                           Used to search for records in the register.
//
//  NotificationTypeInGroup - UUID - ID of the notification type in the notification group.
//                           Used to search for records in the register.
//
//  LastAlert  - See NewServerNotificationToClient
//
// Returns:
//  Array of See NewServerNotificationToClient
//
Function ServerNotificationForClient(GroupID, NotificationTypeInGroup,
			LastAlert = Undefined) Export
	
	If LastAlert = Undefined Then
		LastAlert = NewServerNotificationToClient();
	EndIf;
	
	Query = New Query;
	Query.SetParameter("GroupID",        Lower(GroupID));
	Query.SetParameter("NotificationTypeInGroup",       Lower(NotificationTypeInGroup));
	Query.SetParameter("AddedOn",             LastAlert.AddedOn);
	Query.SetParameter("DateAddedMilliseconds", LastAlert.DateAddedMilliseconds);
	Query.SetParameter("NotificationID",    LastAlert.NotificationID);
	Query.Text =
	"SELECT
	|	SentServerNotifications.NotificationID AS NotificationID,
	|	SentServerNotifications.NotificationContent AS NotificationContent,
	|	SentServerNotifications.AddedOn AS AddedOn,
	|	SentServerNotifications.DateAddedMilliseconds AS DateAddedMilliseconds
	|FROM
	|	InformationRegister.SentServerNotifications AS SentServerNotifications
	|WHERE
	|	SentServerNotifications.GroupID = &GroupID
	|	AND SentServerNotifications.NotificationTypeInGroup = &NotificationTypeInGroup
	|	AND SentServerNotifications.NotificationID <> &NotificationID
	|	AND (SentServerNotifications.AddedOn > &AddedOn
	|			OR SentServerNotifications.AddedOn = &AddedOn
	|				AND SentServerNotifications.DateAddedMilliseconds > &DateAddedMilliseconds)
	|
	|ORDER BY
	|	SentServerNotifications.AddedOn,
	|	SentServerNotifications.DateAddedMilliseconds";
	
	Selection = Query.Execute().Select();
	Result = New Array;
	
	While Selection.Next() Do
		Notification = NewServerNotificationToClient();
		FillPropertyValues(Notification, Selection);
		Notification.Content = NotificationNewContent(Selection.NotificationContent);
		Result.Add(Notification);
	EndDo;
	
	Return Result;
	
EndFunction

// Returns:
//  Structure:
//   * NotificationID - String
//   * Content - See NotificationNewContent
//   * AddedOn - Date
//   * DateAddedMilliseconds - Number
//
Function NewServerNotificationToClient()
	
	Result = New Structure;
	Result.Insert("NotificationID", "");
	Result.Insert("Content", Undefined);
	Result.Insert("AddedOn", '00010101');
	Result.Insert("DateAddedMilliseconds", 0);
	
	Return Result;
	
EndFunction

// Parameters:
//   Store - Undefined
//             - ValueStorage
//
// Returns:
//  Structure:
//   * NameOfAlert - See SendServerNotification.NameOfAlert
//   * Result     - See SendServerNotification.Result
//   * SMSMessageRecipients      - See SendServerNotification.SMSMessageRecipients
//
Function NotificationNewContent(Store = Undefined)
	
	Content = New Structure;
	Content.Insert("NameOfAlert", "");
	Content.Insert("Result");
	Content.Insert("SMSMessageRecipients", New Map);
	
	If TypeOf(Store) <> Type("ValueStorage") Then
		Return Content;
	EndIf;
	
	CurrentContent = Store.Get();
	If TypeOf(CurrentContent) = Type("Structure") Then
		FillPropertyValues(Content, CurrentContent);
	EndIf;
	
	Return Content;
	
EndFunction

// Scheduled job handler.
Procedure SendServerNotificationsToClients() Export
	
	Common.OnStartExecuteScheduledJob(
		Metadata.ScheduledJobs.SendServerNotificationsToClients);
	
	SetPrivilegedMode(True);
	
	If Not Common.SeparatedDataUsageAvailable() Then
		SetUsageOfJobSendServerNotificationsToClients(False);
		Return;
	EndIf;
	
	If IsAllSessionSleeping() Then
		SendServerNotification(NameOfNotificationAllSessionsSleepingJobDisabled(), Undefined, Undefined);
		SetUsageOfJobSendServerNotificationsToClients(False);
		Return;
	EndIf;
	
	SendStatus = SendStatusOnBackgroundJobStart();
	If SendStatus <> Undefined Then
		MaxIntervalByUser = New Map;
		PrepareServerNotifications(SendStatus, MaxIntervalByUser);
		SendPreparedServerNotifications(SendStatus, MaxIntervalByUser);
		UpdateJobSendServerNotificationsToClientsIfNoNotifications(
			SendStatus.MinCheckInterval);
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure

// Common server call handler.
//
// Parameters:
//  Parameters - See ServerNotificationsClient.CommonServerCallNewParameters
//
// Returns:
//  Structure:
//   * ServerNotifications - Array of Structure:
//      ** NameOfAlert - See SendServerNotification.NameOfAlert
//      ** Result     - See SendServerNotification.Result
//   * LastNotificationDate - Date
//   * MinCheckInterval - Number
//   * AdditionalResults - Map - Contains the parameters inserted in the procedure
//       CommonOverridable.OnReceiptRecurringClientDataOnServer.
//   * CollaborationSystemConnected - Boolean
//   * ShouldRegisterIndicators - Boolean
//
Function SessionUndeliveredServerNotifications(Val Parameters) Export
	
	CommonStartTime = CurrentUniversalDateInMilliseconds();
	ShouldRegisterIndicators = CommonClientServer.StructureProperty(Parameters,
		"ShouldRegisterIndicators", False);
	Indicators = ?(ShouldRegisterIndicators, New Array, Undefined);
	
	If Parameters.Property("MessagesForEventLog") Then
		StartMoment = CurrentUniversalDateInMilliseconds();
		EventLog.WriteEventsToEventLog(Parameters.MessagesForEventLog);
		AddMainIndicator(Indicators, StartMoment,
			"EventLog.WriteEventsToEventLog");
	EndIf;
	
	AdditionalResults = New Map;
	If Indicators <> Undefined Then
		AdditionalResults.Insert(NestedIndicatorsParameterName(), New Array);
	EndIf;
	AdditionalParameters = CommonClientServer.StructureProperty(Parameters,
		"AdditionalParameters", New Map);
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Try
		TimeConsumingOperations.OnReceiptRecurringClientDataOnServer(
			AdditionalParameters, AdditionalResults);
	Except
		HandleError(ErrorInfo());
	EndTry;
	AddMainIndicator(Indicators, StartMoment,
		"TimeConsumingOperations.OnReceiptRecurringClientDataOnServer");
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	SetPrivilegedMode(True);
	ServiceAdministratorSession = ServiceAdministratorSession();
	SetPrivilegedMode(False);
	AddMainIndicator(Indicators, StartMoment,
		"ServerNotifications.ServiceAdministratorSession");
	
	Result = New Structure;
	ShouldSendDataRecurrently = Parameters.Property("ShouldSendDataRecurrently");
	IsRecurringDataSendEnabled = ShouldSendDataRecurrently
		And Parameters.ShouldSendDataRecurrently;
	
	If ShouldSendDataRecurrently Then
		If IsRecurringDataSendEnabled Then
			StartMoment = CurrentUniversalDateInMilliseconds();
			Try
				SSLSubsystemsIntegration.OnReceiptRecurringClientDataOnServer(
					AdditionalParameters, AdditionalResults);
			Except
				HandleError(ErrorInfo());
			EndTry;
			AddMainIndicator(Indicators, StartMoment,
				"SSLSubsystemsIntegration.OnReceiptRecurringClientDataOnServer",
				AdditionalResults);
			
			StartMoment = CurrentUniversalDateInMilliseconds();
			Try
				CommonOverridable.OnReceiptRecurringClientDataOnServer(
					AdditionalParameters, AdditionalResults);
			Except
				HandleError(ErrorInfo());
			EndTry;
			AddMainIndicator(Indicators, StartMoment,
				"CommonOverridable.OnReceiptRecurringClientDataOnServer",
				AdditionalResults);
		EndIf;
		
		If Not ServiceAdministratorSession Then
			StartMoment = CurrentUniversalDateInMilliseconds();
			Try
				If Common.SubsystemExists("StandardSubsystems.UsersSessions") Then
					ModuleIBConnections = Common.CommonModule("IBConnections");
					ModuleIBConnections.OnReceiptRecurringClientDataOnServer(
						AdditionalParameters, AdditionalResults);
				EndIf;
			Except
				HandleError(ErrorInfo());
			EndTry;
			AddMainIndicator(Indicators, StartMoment,
				"IBConnections.OnReceiptRecurringClientDataOnServer");
			
			ChatsParametersKeyName = "StandardSubsystems.Core.ServerNotifications.ChatsIDs";
			PopulateChatsIDs = AdditionalParameters.Get(ChatsParametersKeyName) <> Undefined;
			
			If PopulateChatsIDs Then
				StartMoment = CurrentUniversalDateInMilliseconds();
				CollaborationSystemConnected = CollaborationSystemConnected();
				Result.Insert("CollaborationSystemConnected", CollaborationSystemConnected);
				AddMainIndicator(Indicators, StartMoment,
					"ServerNotifications.CollaborationSystemConnected");
			EndIf;
			
			If PopulateChatsIDs
			   And CollaborationSystemConnected Then
				
				StartMoment = CurrentUniversalDateInMilliseconds();
				Try
					AdditionalResults.Insert(ChatsParametersKeyName, ChatsIDs());
				Except
					HandleError(ErrorInfo());
				EndTry;
				AddMainIndicator(Indicators, StartMoment,
					"ServerNotifications.ChatsIDs");
			EndIf;
		Else
			ParameterName = "StandardSubsystems.Core.ServerNotifications.RemovingOutdatedAlerts";
			If AdditionalParameters.Get(ParameterName) <> Undefined Then
				StartMoment = CurrentUniversalDateInMilliseconds();
				Try
					DeleteOutdatedNotifications();
				Except
					HandleError(ErrorInfo());
				EndTry;
				AddMainIndicator(Indicators, StartMoment,
					"ServerNotifications.DeleteOutdatedNotifications");
			EndIf;
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	
	NewSendDateOfLastNotification = Parameters.LastNotificationDate;
	If Not ServiceAdministratorSession Then
		StartMoment = CurrentUniversalDateInMilliseconds();
		SendStatus = ServerNotificationsSendStatus();
		AddMainIndicator(Indicators, StartMoment,
			"ServerNotifications.ServerNotificationsSendStatus");
		
		If NewSendDateOfLastNotification < SendStatus.LastCheckDate Then
			NewSendDateOfLastNotification = SendStatus.LastCheckDate;
		EndIf;
		If ValueIsFilled(SendStatus.MinCheckInterval) Then
			Result.Insert("MinCheckInterval", SendStatus.MinCheckInterval);
		EndIf;
	EndIf;
	
	IBUserID = InfoBaseUsers.CurrentUser().UUID;
	ThisSessionKey = SessionKey();
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Selection = NewServerNotifications(Parameters.LastNotificationDate);
	AddMainIndicator(Indicators, StartMoment,
		"ServerNotifications.NewServerNotifications");
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	NameOfNotificationAllSessionsSleepingJobDisabled = NameOfNotificationAllSessionsSleepingJobDisabled();
	NewServerNotifications = New Array;
	While Selection.Next() Do
		Store = Selection.NotificationContent;
		Content = NotificationNewContent(Store);
		If ValueIsFilled(Content.NameOfAlert) Then
			If Content.NameOfAlert = NameOfNotificationAllSessionsSleepingJobDisabled Then
				If Not ServiceAdministratorSession Then
					Try
						SetUsageOfJobSendServerNotificationsToClients(True);
						DeleteServerNotification(Selection.NotificationID);
					Except
						HandleError(ErrorInfo());
					EndTry;
				EndIf;
				Continue;
			EndIf;
			If TypeOf(Content.SMSMessageRecipients) = Type("Map") Then
				SessionsKeys = Content.SMSMessageRecipients.Get(IBUserID);
				If TypeOf(SessionsKeys) <> Type("Array")
				 Or SessionsKeys.Find(ThisSessionKey) = Undefined
				   And SessionsKeys.Find("*") = Undefined Then
					Continue;
				EndIf;
			EndIf;
			Data = MessageNewData();
			Data.NameOfAlert           = Content.NameOfAlert;
			Data.Result               = Content.Result;
			Data.NotificationID = Selection.NotificationID;
			Data.AddedOn          = Selection.AddedOn;
			If Not TimeConsumingOperations.ShouldSkipNotification(Data) Then
				NewServerNotifications.Add(Data);
			EndIf;
		EndIf;
		NewSendDateOfLastNotification = Selection.AddedOn;
	EndDo;
	If ValueIsFilled(NewServerNotifications) Then
		Result.Insert("ServerNotifications", NewServerNotifications);
	EndIf;
	AddMainIndicator(Indicators, StartMoment,
		"ServerNotifications.NewServerNotifications.Selection.Next");
	
	If ValueIsFilled(NewSendDateOfLastNotification) Then
		Result.Insert("LastNotificationDate", NewSendDateOfLastNotification);
	EndIf;
	
	If ValueIsFilled(AdditionalResults) Then
		Result.Insert("AdditionalResults", AdditionalResults);
	EndIf;
	
	SetPrivilegedMode(False);
	
	AddMainIndicator(Indicators, CommonStartTime,
		"ServerNotifications.SessionUndeliveredServerNotifications",
		AdditionalResults, True);
	
	If ShouldRegisterIndicators Then
		Result.Insert("Indicators", Indicators);
	EndIf;
	
	Return Result;
	
EndFunction

Procedure AddMainIndicator(Indicators, StartMoment, ProcedureName,
			AdditionalResults = Undefined, Shared = False)
	
	If Indicators = Undefined Then
		Return;
	EndIf;
	
	Duration = CurrentUniversalDateInMilliseconds() - StartMoment;
	If Not Shared And Not ValueIsFilled(Duration) Then
		Return;
	EndIf;
	
	Text = Format(Duration / 1000, "ND=6; NFD=3; NZ=000,000; NLZ=") + " " + ProcedureName;
	
	If Shared Then
		Indicators.Insert(0, "    " + Text);
		AdditionalResults.Delete(NestedIndicatorsParameterName());
	Else
		Indicators.Add("      " + Text);
	EndIf;
	
	If AdditionalResults = Undefined Then
		Return;
	EndIf;
	
	NestedIndicators = AdditionalResults.Get(NestedIndicatorsParameterName());
	If TypeOf(NestedIndicators) <> Type("Array") Then
		Return;
	EndIf;
	
	For Each NestedIndicator In NestedIndicators Do
		Indicators.Add("  " + NestedIndicator);
	EndDo;
	NestedIndicators.Clear();
	
EndProcedure

Function NestedIndicatorsParameterName()
	Return "StandardSubsystems.Core.ServerNotifications.Indicators";
EndFunction

Function RegisterServerNotificationsIndicators()
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	Return Constants.RegisterServerNotificationsIndicators.Get();
	
EndFunction

Procedure RegisterServerNotificationIndicatorsOnConstantChange(DoRegister) Export
	
	SendServerNotification(
		"StandardSubsystems.Core.ServerNotifications.ShouldRegisterIndicators",
		DoRegister, Undefined, True);
	
EndProcedure

Procedure PrepareServerNotifications(SendStatus, MaxIntervalByUser = Undefined)
	
	DeleteOutdatedNotifications();
	
	SendStatus.LastCheckDate = CurrentSessionDate();
	SendStatus.MinCheckInterval = 60*20;
	
	ActiveSessionsByKeys = New Map;
	Sessions = GetInfoBaseSessions();
	For Each Session In Sessions Do
		ActiveSessionsByKeys.Insert(SessionKey(Session), Session);
	EndDo;
	
	RecurringNotifications = PeriodicServerNotifications(MaxIntervalByUser,
		ActiveSessionsByKeys);
	
	For Each KeyAndValue In RecurringNotifications Do
		NameOfAlert = KeyAndValue.Key;
		Notification    = KeyAndValue.Value;
		If SendStatus.MinCheckInterval > Notification.VerificationPeriod Then
			SendStatus.MinCheckInterval = Notification.VerificationPeriod;
		EndIf;
		CheckDate = SendStatus.CheckDatesByNotificationNames.Get(NameOfAlert);
		CurrentSessionDate = CurrentSessionDate();
		If TypeOf(CheckDate) = Type("Date")
		   And CurrentSessionDate < CheckDate + Notification.VerificationPeriod Then
			Continue;
		EndIf;
		SendStatus.CheckDatesByNotificationNames.Insert(NameOfAlert, CurrentSessionDate);
		If Metadata.CommonModules.Find(Notification.NotificationSendModuleName) = Undefined Then
			Continue;
		EndIf;
		SendingModule = Common.CommonModule(Notification.NotificationSendModuleName);
		If SendingModule = UsersInternal Then
			ProcedureParameters = New Structure;
			ProcedureParameters.Insert("ParametersVariants", KeyAndValue.Value.ParametersVariants);
			ProcedureParameters.Insert("ActiveSessionsByKeys", ActiveSessionsByKeys);
		Else
			ProcedureParameters = KeyAndValue.Value.ParametersVariants;
		EndIf;
		Try
			SendingModule.OnSendServerNotification(NameOfAlert, ProcedureParameters);
		Except
			ErrorInfo = ErrorInfo();
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot execute the ""%1"" procedure due to:
				           |%2';"),
				Notification.NotificationSendModuleName + ".OnSendServerNotification",
				ErrorProcessing.DetailErrorDescription(ErrorInfo));
			WriteLogEvent(
				NStr("en = 'Server notifications.Background job error';",
					Common.DefaultLanguageCode()),
				EventLogLevel.Error,,, ErrorText);
		EndTry;
	EndDo;
	
	ReviseMinCheckInterval(SendStatus.MinCheckInterval);
	
	ShouldRegisterIndicators = RegisterServerNotificationsIndicators();
	If SendStatus.ShouldRegisterIndicators <> ShouldRegisterIndicators Then
		SendServerNotification(
			"StandardSubsystems.Core.ServerNotifications.ShouldRegisterIndicators",
			ShouldRegisterIndicators, Undefined);
		SendStatus.ShouldRegisterIndicators = ShouldRegisterIndicators;
	EndIf;
	
	CollaborationSystemConnected = CollaborationSystemConnected();
	If SendStatus.CollaborationSystemConnected <> CollaborationSystemConnected Then
		SendServerNotification(
			"StandardSubsystems.Core.ServerNotifications.CollaborationSystemConnected",
			CollaborationSystemConnected, Undefined);
		SendStatus.CollaborationSystemConnected = CollaborationSystemConnected;
	EndIf;
	
	UpdateSendStatus(SendStatus,
		"LastCheckDate, CheckDatesByNotificationNames, MinCheckInterval,
		|CollaborationSystemConnected, ShouldRegisterIndicators");
	
EndProcedure

// Returns:
//   See CommonOverridable.OnAddServerNotifications.Notifications
//
Function AddedSessionNotifications()
	
	Notifications = New Map;
	TimeConsumingOperations.OnAddServerNotifications(Notifications);
	
	If Not ServiceAdministratorSession() Then
		SSLSubsystemsIntegration.OnAddServerNotifications(Notifications);
		CommonOverridable.OnAddServerNotifications(Notifications);
	EndIf;
	
	Return Notifications;
	
EndFunction

// Parameters:
//  RecurringNotifications - See CommonOverridable.OnAddServerNotifications.Notifications
//
// Returns:
//  Map of KeyAndValue:
//   ** Value -
//   ** Value - See ServerNotificationToSave
//
Function RepeatedNotificationToSave(RecurringNotifications)
	
	Result = New Map;
	For Each KeyAndValue In RecurringNotifications Do
		Result.Insert(KeyAndValue.Key,
			ServerNotificationToSave(KeyAndValue.Value));
	EndDo;
	
	Return Result;
	
EndFunction

// Parameters:
//  Notification - See NewServerNotification
//
// Returns:
//  Structure:
//   * NotificationSendModuleName - String - See NewServerNotification.NotificationSendModuleName.
//   * Parameters         - Arbitrary - See NewServerNotification.Parameters.
//                           If the property value is "Undefined", it does not exist.
//
//   * VerificationPeriod    - Number - See NewServerNotification.VerificationPeriod.
//                           If "20*60" is passed, the property does not exist.
//
Function ServerNotificationToSave(Notification)
	
	Result = New Structure;
	Result.Insert("NotificationSendModuleName", Notification.NotificationSendModuleName);
	
	If Notification.Parameters <> Undefined Then
		Result.Insert("Parameters", Notification.Parameters);
	EndIf;
	
	If Notification.VerificationPeriod <> 20*60 Then
		Result.Insert("VerificationPeriod", Notification.VerificationPeriod);
	EndIf;
	
	Return Result;
	
EndFunction

Procedure SendPreparedServerNotifications(SendStatus, MaxIntervalByUser)
	
	If Not IsCurrentUserRegisteredInInteractionSystem() Then
		Return;
	EndIf;
	
	GlobalChatID = GlobalChatID();
	If GlobalChatID = Undefined Then
		Return;
	EndIf;
	
	CleanUpObsoleteMessages(SendStatus);
	
	LastNotificationDate = SendStatus.LastCheckDate;
	FailedNotificationDate   = '00010101';
	
	Selection = NewServerNotifications(?(ValueIsFilled(SendStatus.FailedNotificationDate),
		SendStatus.FailedNotificationDate, SendStatus.LastNotificationDate));
	
	Context = New Structure;
	Context.Insert("GlobalChatID", GlobalChatID);
	Context.Insert("PersonalChatsIDs", New Map);
	Context.Insert("FailedNotificationsDatesByUsers", New Map);
	Context.Insert("SuccessfullNotificationsDatesByUsers", New Map);
	
	While Selection.Next() Do
		Store = Selection.NotificationContent;
		Content = NotificationNewContent(Store);
		If ValueIsFilled(Content.NameOfAlert) Then
			Data = MessageNewData();
			Data.NameOfAlert           = Content.NameOfAlert;
			Data.Result               = Content.Result;
			Data.NotificationID = Selection.NotificationID;
			Data.AddedOn          = Selection.AddedOn;
			
			If TypeOf(Content.SMSMessageRecipients) <> Type("Map") Then
				If Not MessageAlreadyDelivered(SendStatus, Selection, "AllUsers") Then
					Data.SMSMessageRecipients = Undefined;
					Data.Errors = Context.FailedNotificationsDatesByUsers;
					If SendMessage(Data, GlobalChatID) Then
						Context.SuccessfullNotificationsDatesByUsers.Insert("AllUsers", CurrentSessionDate());
					Else
						If Context.FailedNotificationsDatesByUsers.Get("AllUsers") = Undefined Then
							Context.FailedNotificationsDatesByUsers.Insert("AllUsers", Data.AddedOn);
						EndIf;
					EndIf;
				EndIf;
			Else
				SMSMessageRecipients = New Map;
				For Each AddresseeDetails In Content.SMSMessageRecipients Do
					If Not MessageAlreadyDelivered(SendStatus, Selection, AddresseeDetails.Key) Then
						SMSMessageRecipients.Insert(AddresseeDetails.Key, AddresseeDetails.Value);
					EndIf;
				EndDo;
				SendTargetedMessage(Data, SMSMessageRecipients, Context);
			EndIf;
		EndIf;
		LastNotificationDate = Data.AddedOn;
	EndDo;
	
	NotifyAboutActivity(SendStatus, MaxIntervalByUser, Context);
	
	If ValueIsFilled(FailedNotificationDate)
	   And FailedNotificationDate < LastNotificationDate - MaxDeliveryRetryIterval() Then
		
		FailedNotificationDate = LastNotificationDate - MaxDeliveryRetryIterval();
	EndIf;
	
	SendStatus.FailedNotificationDate   = FailedNotificationDate;
	SendStatus.LastNotificationDate = LastNotificationDate;
	SendStatus.FailedNotificationsDatesByUsers = Context.FailedNotificationsDatesByUsers;
	
	UpdateSendStatus(SendStatus,
		"FailedNotificationDate,
		|LastNotificationDate,
		|LastMessageClearDate,
		|FailedNotificationsDatesByUsers,
		|SuccessfullNotificationsDatesByUsers");
	
EndProcedure

Procedure SendTargetedMessage(Data, SMSMessageRecipients, Context)
	
	If SMSMessageRecipients.Count() > 20 Then
		Data.SMSMessageRecipients = SMSMessageRecipients;
		IdentifyFailedNotificationsDates(Data, Context.FailedNotificationsDatesByUsers);
		If SendMessage(Data, Context.GlobalChatID) Then
			For Each AddresseeDetails In SMSMessageRecipients Do
				Context.SuccessfullNotificationsDatesByUsers.Insert(AddresseeDetails.Key, CurrentSessionDate());
			EndDo;
		Else
			For Each AddresseeDetails In SMSMessageRecipients Do
				If Context.FailedNotificationsDatesByUsers.Get(AddresseeDetails.Key) = Undefined Then
					Context.FailedNotificationsDatesByUsers.Insert(AddresseeDetails.Key, Data.AddedOn);
				EndIf;
			EndDo;
		EndIf;
	Else
		For Each AddresseeDetails In SMSMessageRecipients Do
			IBUserID = AddresseeDetails.Key;
			Data.SMSMessageRecipients = New Map;
			Data.SMSMessageRecipients.Insert(IBUserID, AddresseeDetails.Value);
			IdentifyFailedNotificationsDates(Data, Context.FailedNotificationsDatesByUsers);
			ConversationID = Context.PersonalChatsIDs.Get(IBUserID);
			If ConversationID = Undefined Then
				ConversationID = PersonalChatID(IBUserID);
			EndIf;
			If SendMessage(Data, ConversationID) Then
				Context.SuccessfullNotificationsDatesByUsers.Insert(IBUserID, CurrentSessionDate());
			Else
				If Context.FailedNotificationsDatesByUsers.Get(IBUserID) = Undefined Then
					Context.FailedNotificationsDatesByUsers.Insert(IBUserID, Data.AddedOn);
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

Procedure NotifyAboutActivity(SendStatus, MaxIntervalByUser, Context)
	
	PingAddressees = New Map;
	NextCheckDate = SendStatus.LastCheckDate
		+ SendStatus.MinCheckInterval + 3;
	
	For Each PeriodDetails In MaxIntervalByUser Do
		If Context.FailedNotificationsDatesByUsers.Get("AllUsers") <> Undefined
		 Or Context.FailedNotificationsDatesByUsers.Get(PeriodDetails.Key) <> Undefined Then
			Continue;
		EndIf;
		DateSent = Context.SuccessfullNotificationsDatesByUsers.Get(PeriodDetails.Key);
		CommonSendDate = Context.SuccessfullNotificationsDatesByUsers.Get("AllUsers");
		If DateSent = Undefined Or CommonSendDate <> Undefined And DateSent < CommonSendDate Then
			DateSent = CommonSendDate;
		EndIf;
		If DateSent = Undefined Then
			DateSent = SendStatus.SuccessfullNotificationsDatesByUsers.Get(PeriodDetails.Key);
			CommonSendDate = SendStatus.SuccessfullNotificationsDatesByUsers.Get("AllUsers");
			If DateSent = Undefined Or CommonSendDate <> Undefined And DateSent < CommonSendDate Then
				DateSent = CommonSendDate;
			EndIf;
		EndIf;
		If DateSent = Undefined
		 Or DateSent + PeriodDetails.Value > NextCheckDate Then
			PingAddressees.Insert(PeriodDetails.Key, New Array);
		EndIf;
	EndDo;
	
	If ValueIsFilled(PingAddressees) Then
		Data = MessageNewData();
		Data.NameOfAlert = "NoServerNotifications";
		SendTargetedMessage(Data, PingAddressees, Context);
	EndIf;
	
EndProcedure

// Returns:
//  Structure:
//   * NameOfAlert           - See SendServerNotification.NameOfAlert
//   * Result               - See SendServerNotification.Result
//   * SMSMessageRecipients                - See SendServerNotification.SMSMessageRecipients
//   * NotificationID - String - UUID string.
//   * AddedOn          - Date - Date the notification was added.
//   * Errors - Map of KeyAndValue:
//       ** Key - UUID - infobase user ID.
//       ** Value - Date - Date of the first message failed to send.
//   * WasSentFromQueue - Boolean - If True, the message was sent in its due order
//       (according to the time it was queued). Therefore, you should update the last notification date.
//
Function MessageNewData() Export
	
	Data = New Structure;
	Data.Insert("NameOfAlert", "");
	Data.Insert("Result");
	Data.Insert("SMSMessageRecipients", New Map);
	Data.Insert("NotificationID", "");
	Data.Insert("AddedOn", '00010101');
	Data.Insert("Errors", New Map);
	Data.Insert("WasSentFromQueue", True);
	
	Return Data;
	
EndFunction

Function MessageAlreadyDelivered(SendStatus, Selection, IBUserID)
	
	If ValueIsFilled(Selection.CollaborationSystemRecordDate) Then
		Return True;
	EndIf;
	
	FailedNotificationDate =
		SendStatus.FailedNotificationsDatesByUsers.Get("AllUsers");
	
	If FailedNotificationDate = Undefined Then
		FailedNotificationDate = SendStatus.LastNotificationDate;
	EndIf;
	
	Return Selection.AddedOn < FailedNotificationDate;
	
EndFunction

Procedure IdentifyFailedNotificationsDates(Data, FailedNotificationsDatesByUsers,
			IBUserID = Undefined)
	
	Data.Errors = New Map;
	
	If IBUserID = Undefined Then
		For Each KeyAndValue In FailedNotificationsDatesByUsers Do
			If Data.SMSMessageRecipients.Get(KeyAndValue.Key) <> Undefined Then
				Data.Errors.Insert(KeyAndValue.Key, KeyAndValue.Value);
			EndIf;
		EndDo;
	Else
		FailedNotificationDate = FailedNotificationsDatesByUsers.Get(IBUserID);
		If FailedNotificationDate <> Undefined Then
			Data.Errors.Insert(IBUserID, FailedNotificationDate);
		EndIf;
	EndIf;
	
	FailedNotificationDate = FailedNotificationsDatesByUsers.Get("AllUsers");
	If FailedNotificationDate <> Undefined Then
		Data.Errors.Insert("AllUsers", FailedNotificationDate);
	EndIf;
	
EndProcedure

Function MaxDeliveryRetryIterval()
	
	Return 120;
	
EndFunction

Function NewServerNotifications(LastNotificationDate)
	
	Query = New Query;
	Query.SetParameter("LastNotificationDate", LastNotificationDate);
	Query.SetParameter("AddresseeSearchTemplate",
		"%" + Lower(InfoBaseUsers.CurrentUser().UUID) + "%");
	
	Query.Text =
	"SELECT
	|	SentServerNotifications.NotificationID AS NotificationID,
	|	SentServerNotifications.NotificationContent AS NotificationContent,
	|	SentServerNotifications.AddedOn AS AddedOn,
	|	SentServerNotifications.CollaborationSystemRecordDate AS CollaborationSystemRecordDate
	|FROM
	|	InformationRegister.SentServerNotifications AS SentServerNotifications
	|WHERE
	|	SentServerNotifications.AddedOn >= &LastNotificationDate
	|	AND (SentServerNotifications.SMSMessageRecipients = """"
	|		OR SentServerNotifications.SMSMessageRecipients LIKE &AddresseeSearchTemplate)
	|	AND &Filter
	|
	|ORDER BY
	|	SentServerNotifications.AddedOn,
	|	SentServerNotifications.DateAddedMilliseconds";
	
	Query.Text = StrReplace(Query.Text, "&Filter",
		?(Common.SeparatedDataUsageAvailable(), "TRUE",
			"SentServerNotifications.DataAreaAuxiliaryData = 0"));
	
	Return Query.Execute().Select();
	
EndFunction

// Returns:
//  Structure:
//   * Parameters - Arbitrary - See NewServerNotification.Parameters.
//   * SMSMessageRecipients - Map of KeyAndValue:
//      ** Key - UUID - infobase user ID.
//      ** Value - Array of See ServerNotifications.SessionKey
//
Function ServerNotificationNewParametersVariant()
	
	ParametersVariant = New Structure;
	ParametersVariant.Insert("Parameters");
	ParametersVariant.Insert("SMSMessageRecipients", New Map);
	
	Return ParametersVariant;
	
EndFunction

Function IsAllSessionSleeping()
	Return False;
EndFunction

// Returns:
//  Map of KeyAndValue:
//   * Key - String - See NewServerNotification.Name
//   * Value - Structure:
//      ** NotificationSendModuleName - String - See NewServerNotification.NotificationSendModuleName
//      ** VerificationPeriod - Number - See NewServerNotification.VerificationPeriod
//      ** ParametersVariants - See StandardSubsystemsServer.OnSendServerNotification.ParametersVariants
//
Function PeriodicServerNotifications(MaxIntervalByUser, ActiveSessionsByKeys)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PeriodicServerNotifications.SessionKey AS SessionKey,
	|	PeriodicServerNotifications.IBUserID AS IBUserID,
	|	PeriodicServerNotifications.Notifications AS Notifications
	|FROM
	|	InformationRegister.PeriodicServerNotifications AS PeriodicServerNotifications";
	
	Notifications = New Map;
	NotificationParametersVariantsByValueKeys = New Map;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If ActiveSessionsByKeys.Get(Selection.SessionKey) = Undefined Then
			RecordSet = ServiceRecordSet(InformationRegisters.PeriodicServerNotifications);
			RecordSet.Filter.SessionKey.Set(Selection.SessionKey);
			RecordSet.Write();
			Continue;
		EndIf;
		SessionNotifications = RecurringServerNotificationsAboutSession(Selection.Notifications);
		If Not ValueIsFilled(SessionNotifications) Then
			Continue;
		EndIf;
		For Each KeyAndValue In SessionNotifications Do
			NameOfAlert = KeyAndValue.Key;
			If TypeOf(KeyAndValue.Value) <> Type("Structure") Then
				Continue;
			EndIf;
			Notification = Notifications.Get(NameOfAlert);
			If Notification = Undefined Then
				Notification = New Structure;
				Notification.Insert("NotificationSendModuleName", "");
				Notification.Insert("VerificationPeriod", 20*60);
				FillPropertyValues(Notification, KeyAndValue.Value);
				Notification.Insert("ParametersVariants", New Array);
				Notifications.Insert(NameOfAlert, Notification);
			EndIf;
			NotificationParameters = Undefined;
			KeyAndValue.Value.Property("Parameters", NotificationParameters);
			ParametersVariantsByValueKeys = NotificationParametersVariantsByValueKeys.Get(NameOfAlert);
			If ParametersVariantsByValueKeys = Undefined Then
				ParametersVariantsByValueKeys = New Map;
				NotificationParametersVariantsByValueKeys.Insert(NameOfAlert, ParametersVariantsByValueKeys);
			EndIf;
			ParametersValueKey = ValueToStringInternal(NotificationParameters);
			ParametersVariant = ParametersVariantsByValueKeys.Get(ParametersValueKey);
			If ParametersVariant = Undefined Then
				ParametersVariant = ServerNotificationNewParametersVariant();
				ParametersVariantsByValueKeys.Insert(ParametersValueKey, ParametersVariant);
				ParametersVariant.Parameters = NotificationParameters;
				Notification.ParametersVariants.Add(ParametersVariant);
			EndIf;
			SessionsKeys = ParametersVariant.SMSMessageRecipients.Get(Selection.IBUserID);
			If SessionsKeys = Undefined Then
				SessionsKeys = New Array;
				ParametersVariant.SMSMessageRecipients.Insert(Selection.IBUserID, SessionsKeys);
			EndIf;
			If SessionsKeys.Find(Selection.SessionKey) = Undefined Then
				SessionsKeys.Add(Selection.SessionKey);
			EndIf;
			If MaxIntervalByUser <> Undefined Then
				CurrentPeriod = MaxIntervalByUser.Get(Selection.IBUserID);
				If CurrentPeriod = Undefined
				 Or CurrentPeriod > Notification.VerificationPeriod Then
					MaxIntervalByUser.Insert(Selection.IBUserID,
						Notification.VerificationPeriod);
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	Return Notifications;
	
EndFunction

Procedure UpdateJobSendServerNotificationsToClientsIfNoNotifications(MinCheckInterval)
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.PeriodicServerNotifications AS PeriodicServerNotifications";
	
	IsJobDisabled = False;
	If Query.Execute().IsEmpty() Then
		Block = New DataLock;
		Block.Add("InformationRegister.PeriodicServerNotifications");
		
		BeginTransaction();
		Try
			Block.Lock();
			If Query.Execute().IsEmpty() Then
				ConfigureJobSendServerNotificationsToClients(False);
				IsJobDisabled = True;
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
	If Not IsJobDisabled Then
		ConfigureJobSendServerNotificationsToClients(True, MinCheckInterval);
	EndIf;
	
EndProcedure

// Parameters:
//  NotificationsStorage - ValueStorage
//
// Returns:
//  Map of KeyAndValue:
//   * Key     - String - See ServerNotifications.NewServerNotification.Name
//   * Value - See ServerNotifications.NewServerNotification
//
Function RecurringServerNotificationsAboutSession(NotificationsStorage)
	
	If TypeOf(NotificationsStorage) <> Type("ValueStorage") Then
		Return New Map;
	EndIf;
	
	Notifications = NotificationsStorage.Get();
	If TypeOf(Notifications) <> Type("Map") Then
		Return New Map;
	EndIf;
	
	Return Notifications;
	
EndFunction

// Returns:
//  Structure:
//   * LastCheckDate - Date
//   * MinCheckInterval - Number
//   * CheckDatesByNotificationNames - Map of KeyAndValue:
//       ** Key     - String - See NewServerNotification.Name
//       ** Value - Date
//   * LastNotificationDate - Date - Date of the last notification sent.
//   * FailedNotificationDate   - Date - Date of the failed notification.
//   * FailedNotificationsDatesByUsers - Map of KeyAndValue:
//       ** Key     - UUID - infobase user ID.
//       ** Value - Date - Date of the failed notification.
//   * SuccessfullNotificationsDatesByUsers - Map of KeyAndValue:
//       ** Key     - UUID - infobase user ID.
//       ** Value - Date
//   * BackgroundJobIdentifier - UUID
//   * LastMessageClearDate - Date
//   * CollaborationSystemConnected - Boolean
//   * ShouldRegisterIndicators - Boolean
//
Function ServerNotificationsSendStatus()
	
	State = New Structure;
	State.Insert("LastCheckDate", '00010101');
	State.Insert("MinCheckInterval", 0);
	State.Insert("CheckDatesByNotificationNames", New Map);
	State.Insert("LastNotificationDate", '00010101');
	State.Insert("FailedNotificationDate", '00010101');
	State.Insert("FailedNotificationsDatesByUsers", New Map);
	State.Insert("SuccessfullNotificationsDatesByUsers", New Map);
	State.Insert("BackgroundJobIdentifier",
		CommonClientServer.BlankUUID());
	State.Insert("LastMessageClearDate", '00010101');
	State.Insert("CollaborationSystemConnected", False);
	State.Insert("ShouldRegisterIndicators", False);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ServerNotificationsSendStatus.Value AS Value
	|FROM
	|	Constant.ServerNotificationsSendStatus AS ServerNotificationsSendStatus";
	Selection = Query.Execute().Select();
	Value = ?(Selection.Next(), Selection.Value, Undefined);
	
	If TypeOf(Value) = Type("ValueStorage") Then
		CurrentStatus = Value.Get();
		If TypeOf(CurrentStatus) = Type("Structure") Then
			For Each KeyAndValue In CurrentStatus Do
				If State.Property(KeyAndValue.Key)
				   And TypeOf(State[KeyAndValue.Key]) = TypeOf(KeyAndValue.Value) Then
					State[KeyAndValue.Key] = KeyAndValue.Value;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	Return State;
	
EndFunction

Procedure UpdateSendStatus(NewSendStatus, PropertiesNames)
	
	Block = New DataLock;
	Block.Add("Constant.ServerNotificationsSendStatus");
	BeginTransaction();
	Try
		Block.Lock();
		SendStatus = ServerNotificationsSendStatus();
		If StrFind(PropertiesNames, "SuccessfullNotificationsDatesByUsers") > 0 Then
			NewDates = NewSendStatus.SuccessfullNotificationsDatesByUsers;
			For Each KeyAndValue In SendStatus.SuccessfullNotificationsDatesByUsers Do
				NewDate = NewDates.Get(KeyAndValue.Key);
				If NewDate <> Undefined And NewDate < KeyAndValue.Value Then
					NewDates.Insert(KeyAndValue.Key, NewDate);
				EndIf;
			EndDo;
		EndIf;
		Write = False;
		For Each KeyAndValue In New Structure(PropertiesNames) Do
			PropertyName = KeyAndValue.Key;
			If SendStatus[PropertyName] = NewSendStatus[PropertyName] Then
				Continue;
			EndIf;
			SendStatus[PropertyName] = NewSendStatus[PropertyName];
			Write = True;
		EndDo;
		If Write Then
			ValueManager = ServiceValueManager(Constants.ServerNotificationsSendStatus);
			ValueManager.Value = New ValueStorage(SendStatus);
			ValueManager.Write();
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		ErrorInfo = ErrorInfo();
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot set constant %1 due to:
			           |%2';"),
			"ServerNotificationsSendStatus",
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		WriteLogEvent(
			NStr("en = 'Server notifications.Background job error';",
				Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, ErrorText);
	EndTry;
	
EndProcedure

// Returns:
//   See ServerNotificationsSendStatus
//
Function SendStatusOnBackgroundJobStart()
	
	CurrentSession = GetCurrentInfoBaseSession();
	If CurrentSession.ApplicationName <> "BackgroundJob" Then
		Return ServerNotificationsSendStatus();
	EndIf;
	
	CurrentBackgroundJob = CurrentSession.GetBackgroundJob();
	If CurrentBackgroundJob = Undefined Then
		Return ServerNotificationsSendStatus();
	EndIf;
	
	SendStatus = Undefined;
	
	Block = New DataLock;
	Block.Add("Constant.ServerNotificationsSendStatus");
	BeginTransaction();
	Try
		Block.Lock();
		SendStatus = ServerNotificationsSendStatus();
		If SendServerNotificationsToClientsRunning(SendStatus) Then
			SendStatus = Undefined;
		Else
			SendStatus.BackgroundJobIdentifier = CurrentBackgroundJob.UUID;
			ValueManager = ServiceValueManager(Constants.ServerNotificationsSendStatus);
			ValueManager.Value = New ValueStorage(SendStatus);
			ValueManager.Write();
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		ErrorInfo = ErrorInfo();
		SendStatus = Undefined;
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot set constant %1 due to:
			           |%2';"),
			"ServerNotificationsSendStatus",
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		WriteLogEvent(
			NStr("en = 'Server notifications.Background job startup error';",
				Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, ErrorText);
	EndTry;
	
	Return SendStatus;
	
EndFunction

Function SendServerNotificationsToClientsRunning(SendStatus)
	
	ActiveBackgroundJob = BackgroundJobs.FindByUUID(
		SendStatus.BackgroundJobIdentifier);
	
	Return ActiveBackgroundJob <> Undefined
	      And ActiveBackgroundJob.State = BackgroundJobState.Active;
	
EndFunction

Procedure DeleteOutdatedNotifications()
	
	Query = New Query;
	Query.SetParameter("TheBoundaryOfObsolescence", CurrentSessionDate() - 60*60);
	Query.Text =
	"SELECT
	|	SentServerNotifications.NotificationID AS NotificationID
	|FROM
	|	InformationRegister.SentServerNotifications AS SentServerNotifications
	|WHERE
	|	SentServerNotifications.AddedOn < &TheBoundaryOfObsolescence
	|	AND &Filter
	|
	|ORDER BY
	|	SentServerNotifications.AddedOn,
	|	SentServerNotifications.DateAddedMilliseconds";
	
	SeparatedDataUsageAvailable = Common.SeparatedDataUsageAvailable();
	
	Query.Text = StrReplace(Query.Text, "&Filter",
		?(SeparatedDataUsageAvailable, "TRUE",
			"SentServerNotifications.DataAreaAuxiliaryData = 0"));
	
	RecordSetIsEmpty = ServiceRecordSet(InformationRegisters.SentServerNotifications);
	If Not SeparatedDataUsageAvailable Then
		RecordSetIsEmpty.Filter.DataAreaAuxiliaryData.Set(0);
	EndIf;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		RecordSetIsEmpty.Filter.NotificationID.Set(Selection.NotificationID);
		RecordSetIsEmpty.Write();
	EndDo;
	
EndProcedure

// Intended for the SendServerNotificationWithGroupID procedure.
Procedure StartDeliverDeferredServerNotifications(Launched = False)
	
	If Not IsCurrentUserRegisteredInInteractionSystem()
	 Or Common.FileInfobase() // Starting the delivery is pointless as the job will be waiting for a long-running operation job.
	 Or ExclusiveMode() // Starting the delivery is prohibited as all changes within the session will be blocked.
	 Or InfobaseUpdate.InfobaseUpdateRequired()
	 Or IsDeferredServerAlertsDeliveryRunning() Then
		Return;
	EndIf;
	
	CurrentSession = GetCurrentInfoBaseSession();
	JobDescription =
		NStr("en = 'Autostart';", Common.DefaultLanguageCode()) + ": "
		+ NStr("en = 'Delayed server notification delivery';", Common.DefaultLanguageCode()) + " ("
		+ StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'from session %1 started on %2';", Common.DefaultLanguageCode()),
			Format(CurrentSession.SessionNumber, "NG="),
			Format(CurrentSession.SessionStarted, "DLF=DT")) + ")";
	
	BackgroundJobs.Execute(NameOfJobMethodServerNotificationsDeferredDelivery(),,, JobDescription);
	
	Launched = True;
	
EndProcedure

// Start background handler.
Procedure ServerNotificationsDeferredDelivery() Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	CurrentSession = GetCurrentInfoBaseSession();
	If CurrentSession.ApplicationName <> "BackgroundJob" Then
		Return;
	EndIf;
	
	CurrentBackgroundJob = CurrentSession.GetBackgroundJob();
	If CurrentBackgroundJob = Undefined Then
		Return;
	EndIf;
	
	If IsDeferredServerAlertsDeliveryRunning(CurrentBackgroundJob)
	 Or Not IsCurrentUserRegisteredInInteractionSystem() Then
		Return;
	EndIf;
	
	While True Do
		WaitStart = CurrentSessionDate();
		While True Do
			Selection = UnsentDeferredNotifications();
			If Selection.Count() > 0
			 Or CurrentSessionDate() - WaitStart > 20 Then
				Break;
			EndIf;
			CurrentBackgroundJob.WaitForExecutionCompletion(1);
		EndDo;
		If Selection.Count() = 0 Then
			Break;
		EndIf;
		StartOfDelivery = CurrentSessionDate();
		While Selection.Next() Do
			DeliverNotification(Selection);
			If CurrentSessionDate() - StartOfDelivery > 5 Then
				Break;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

// Intended for the ServerNotificationsDeferredDelivery procedure.
Procedure DeliverNotification(Selection)
	
	AdditionDeferredDate = Selection.AddedOn + Selection.DeferralOfWritingToCollaborationSystem;
	If CurrentSessionDate() <= AdditionDeferredDate Then
		Return;
	EndIf;
	
	NotificationContent = NotificationNewContent(Selection.NotificationContent);
	If ValueIsFilled(NotificationContent.NameOfAlert) Then
		Sent = SendMessageImmediately(Selection.NotificationID,
			Selection.AddedOn, NotificationContent);
	Else
		Sent = False;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.SentServerNotifications");
	LockItem.SetValue("NotificationID", Selection.NotificationID);
	
	BeginTransaction();
	Try
		Block.Lock();
		RecordSet = InformationRegisters.SentServerNotifications.CreateRecordSet();
		RecordSet.Filter.NotificationID.Set(Selection.NotificationID);
		RecordSet.Read();
		If RecordSet.Count() = 1
		   And (Not ValueIsFilled(RecordSet[0].CollaborationSystemRecordDate)
		      Or RecordSet[0].DeferralOfWritingToCollaborationSystem <> 0 ) Then
			
			If Sent Then
				RecordSet[0].CollaborationSystemRecordDate = CurrentSessionDate();
				RecordSet[0].DateWrittenToCollaborationSystemMilliseconds = Milliseconds();
			Else
				RecordSet[0].DeferralOfWritingToCollaborationSystem = 0;
			EndIf;
			RecordSet.Write();
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Intended for the procedures StartDeliverDeferredServerNotifications and ServerNotificationsDeferredDelivery.
Function IsDeferredServerAlertsDeliveryRunning(CurrentBackgroundJob = Undefined)
	
	Filter = New Structure;
	Filter.Insert("State", BackgroundJobState.Active);
	Filter.Insert("MethodName", NameOfJobMethodServerNotificationsDeferredDelivery());
	
	FoundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	
	If FoundJobs.Count() = 0 Then
		Return False;
	EndIf;
	If CurrentBackgroundJob = Undefined Then
		Return True;
	EndIf;
	
	IDOfCurrent = CurrentBackgroundJob.UUID;
	
	For Each FoundJob In FoundJobs Do
		If FoundJob.UUID = IDOfCurrent Then
			Continue;
		EndIf;
		Return True;
	EndDo;
	
	Return False;
	
EndFunction

// Intended for the StartDeliverDeferredServerNotifications procedure
// and the IsDeferredServerAlertsDeliveryRunning function.
//
Function NameOfJobMethodServerNotificationsDeferredDelivery()
	
	Return "ServerNotifications.ServerNotificationsDeferredDelivery";
	
EndFunction

// Intended for the ServerNotificationsDeferredDelivery procedure.
Function UnsentDeferredNotifications()
	
	SendStatus = ServerNotificationsSendStatus();
	LastNotificationDate = ?(ValueIsFilled(SendStatus.FailedNotificationDate),
		SendStatus.FailedNotificationDate, SendStatus.LastNotificationDate);
	
	Query = New Query;
	Query.SetParameter("LastNotificationDate", LastNotificationDate);
	Query.SetParameter("DateEmpty", '00010101');
	Query.Text =
	"SELECT
	|	SentServerNotifications.NotificationID AS NotificationID,
	|	SentServerNotifications.NotificationContent AS NotificationContent,
	|	SentServerNotifications.AddedOn AS AddedOn,
	|	SentServerNotifications.DeferralOfWritingToCollaborationSystem AS DeferralOfWritingToCollaborationSystem
	|FROM
	|	InformationRegister.SentServerNotifications AS SentServerNotifications
	|WHERE
	|	SentServerNotifications.AddedOn >= &LastNotificationDate
	|	AND SentServerNotifications.CollaborationSystemRecordDate = &DateEmpty
	|	AND SentServerNotifications.DeferralOfWritingToCollaborationSystem > 0
	|
	|ORDER BY
	|	SentServerNotifications.AddedOn,
	|	SentServerNotifications.DateAddedMilliseconds";
	
	Return Query.Execute().Select();
	
EndFunction

// Returns:
//  Structure:
//   * SessionKey - See SessionKey
//   * IBUserID - UUID - ID of the current user.
//   * LastNotificationDate - Date
//   * Notifications - See CommonOverridable.OnAddServerNotifications.Notifications
//   * MinimumPeriod - Number - Time interval in seconds.
//   * CollaborationSystemConnected - Boolean
//   * PersonalChatID - Undefined - Chat is unavailable.
//                                    - CollaborationSystemConversationID - ID of the chat
//                                        "ServerNotifications <Infobase user ID>".
//   * GlobalChatID - Undefined - Chat is unavailable.
//                                   - CollaborationSystemConversationID - ID of the chat
//                                        "ServerNotifications".
//   * ServiceAdministratorSession - Boolean
//
Function ServerNotificationsParametersThisSession() Export
	
	Notifications = AddedSessionNotifications();
	
	Parameters = New Structure;
	Parameters.Insert("SessionKey", SessionKey());
	Parameters.Insert("IBUserID",
		InfoBaseUsers.CurrentUser().UUID);
	Parameters.Insert("LastNotificationDate", CurrSessionStartInCurrSessionDateTimeZone());
	Parameters.Insert("Notifications", Notifications);
	Parameters.Insert("MinimumPeriod", 20*60);
	Parameters.Insert("CollaborationSystemConnected", False);
	Parameters.Insert("PersonalChatID", Undefined);
	Parameters.Insert("GlobalChatID", Undefined);
	Parameters.Insert("ServiceAdministratorSession", ServiceAdministratorSession());
	Parameters.Insert("ShouldRegisterIndicators", RegisterServerNotificationsIndicators());
	Parameters.Insert("RepeatedDateExportMinInterval",
		RepeatedDateExportMinInterval());
	
	RecurringNotifications = New Map;
	For Each KeyAndValue In Notifications Do
		Notification = KeyAndValue.Value;
		If Not ValueIsFilled(Notification.Name)
		 Or KeyAndValue.Key <> Notification.Name Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'In procedure ""%1"",
				           |the notification name is either unspecified or filled in incorrectly
				           |%2 = ""%3""
				           |%4 = ""%5"".';"),
					"CommonOverridable.OnAddServerNotifications",
					"Key", KeyAndValue.Key, "Notification.Name", Notification.Name);
			Raise ErrorText;
		EndIf;
		If Not ValueIsFilled(Notification.NotificationReceiptModuleName) Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'In procedure ""%1"",
				           |property ""%3"" of notification ""%2""
				           |is not filled in.';"),
					"CommonOverridable.OnAddServerNotifications",
					Notification.Name, "NotificationReceiptModuleName");
			Raise ErrorText;
		EndIf;
		If Metadata.CommonModules.Find(Notification.NotificationReceiptModuleName) = Undefined Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'In procedure ""%1"",
				           |property ""%3"" of notification ""%2""
				           |has non-existent common module
				           |""%4"".';"),
					"CommonOverridable.OnAddServerNotifications",
					Notification.Name, "NotificationReceiptModuleName", Notification.NotificationReceiptModuleName);
			Raise ErrorText;
		EndIf;
		If Not ValueIsFilled(Notification.NotificationSendModuleName) Then
			Continue;
		EndIf;
		If Metadata.CommonModules.Find(Notification.NotificationSendModuleName) = Undefined Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'In procedure ""%1"",
				           |property ""%3"" of notification ""%2""
				           |has non-existent common module
				           |""%4"".';"),
					"CommonOverridable.OnAddServerNotifications",
					Notification.Name, "NotificationSendModuleName", Notification.NotificationSendModuleName);
			Raise ErrorText;
		EndIf;
		If Parameters.ServiceAdministratorSession Then
			Continue;
		EndIf;
		RecurringNotifications.Insert(KeyAndValue.Key, Notification);
		If Parameters.MinimumPeriod > Notification.VerificationPeriod Then
			Parameters.MinimumPeriod = Notification.VerificationPeriod;
		EndIf;
	EndDo;
	
	If Parameters.ServiceAdministratorSession Then
		Return Parameters;
	EndIf;
	
	ReviseMinCheckInterval(Parameters.MinimumPeriod);
	
	If ValueIsFilled(RecurringNotifications) Then
		SetPrivilegedMode(True);
		RecordSet = ServiceRecordSet(InformationRegisters.PeriodicServerNotifications);
		RecordSet.Filter.SessionKey.Set(Parameters.SessionKey);
		NewRecord = RecordSet.Add();
		NewRecord.SessionKey = Parameters.SessionKey;
		NewRecord.IBUserID =
			InfoBaseUsers.CurrentUser().UUID;
		NewRecord.Notifications = New ValueStorage(RepeatedNotificationToSave(RecurringNotifications));
		NewRecord.AddedOn = CurrentSessionDate();
		RecordSet.Write();
		ConfigureJobSendServerNotificationsToClients(True, Parameters.MinimumPeriod, True);
		SetPrivilegedMode(False);
	EndIf;
	
	For Each KeyAndValue In Notifications Do
		KeyAndValue.Value.Parameters = Undefined;
	EndDo;
	
	Parameters.CollaborationSystemConnected = CollaborationSystemConnected();
	FillPropertyValues(Parameters, ChatsIDs());
	
	Return Parameters;
	
EndFunction

Function CurrSessionStartInCurrSessionDateTimeZone()
	
	// ACC:143-off - No.643.2.1. "CurrentDate" is required instead of "CurrentSessionDate"
	// as the current date is used in the "SessionStart" property of the "InfoBaseSession" object.
	TimeShift = CurrentSessionDate() - CurrentDate();
	// ACC:143-on
	
	Return GetCurrentInfoBaseSession().SessionStarted + TimeShift;
	
EndFunction

// Returns:
//  Structure:
//   * PersonalChatID - Undefined - Chat is unavailable.
//                                    - CollaborationSystemConversationID - ID of the chat
//                                        "ServerNotifications <Infobase user ID>".
//   * GlobalChatID - Undefined - Chat is unavailable.
//                                   - CollaborationSystemConversationID - ID of the chat
//                                        "ServerNotifications".
// 
Function ChatsIDs()
	
	Result = New Structure;
	Result.Insert("PersonalChatID");
	Result.Insert("GlobalChatID");
	
	UserIDCollaborationSystem = Undefined;
	If Not IsCurrentUserRegisteredInInteractionSystem(UserIDCollaborationSystem) Then
		Return Result;
	EndIf;
	
	GlobalChatID = GlobalChatID();
	If GlobalChatID = Undefined Then
		Return Result;
	EndIf;
	
	PersonalChatID = PersonalChatID(, UserIDCollaborationSystem);
	If PersonalChatID = Undefined Then
		Return Result;
	EndIf;
	
	Result.GlobalChatID  = GlobalChatID;
	Result.PersonalChatID = PersonalChatID;
	
	Return Result;
	
EndFunction

Procedure ReviseMinCheckInterval(MinCheckInterval)
	
	LowerBound = ?(Common.DataSeparationEnabled(), 5*60, 60);
	
	If MinCheckInterval < LowerBound Then
		MinCheckInterval = LowerBound;
	EndIf;
	
	MinInterval = RepeatedDateExportMinInterval() * 60;
	
	If MinCheckInterval < MinInterval Then
		MinCheckInterval = MinInterval;
	EndIf;
	
EndProcedure

// When Collaboration System is not used, and the number of sessions exceeds 2,000,
// 1-minute interval for server calls will cause a high server load (33 calls per second).
// If the ratio is less than 1 core per 10 sessions, the load might lead to a critical performance degradation.
// To reduce the load, set the interval to 2–5 minutes.
// Note that will reduce the UI responsiveness when user actions affect the server side.
// 
// 
//
// Returns:
//  Number - The minimal time (in minutes) the intermittent data transfer must run
//          for the common server call and checks run by the scheduled job.
//          This parameter overrides (upward) the predefined value.
//
Function RepeatedDateExportMinInterval()
	Return 1;
EndFunction

Procedure ConfigureJobSendServerNotificationsToClients(Enable, RepeatPeriod = 0, OnStart = False)
	
	Try
		ConfigureJobSendServerNotificationsToClientsNoAttempt(Enable, RepeatPeriod, OnStart);
	Except
		ErrorInfo = ErrorInfo();
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot set up scheduled job
			           |""%1"" due to:
			           |%2';"),
			Metadata.ScheduledJobs.SendServerNotificationsToClients.Name,
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		WriteLogEvent(
			NStr("en = 'Server notifications.Scheduled job setup error';",
				Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, ErrorText);
	EndTry;
	
EndProcedure

Procedure ConfigureJobSendServerNotificationsToClientsNoAttempt(Enable, RepeatPeriod, OnStart)
	
	UserName = "";
	If ValueIsFilled(UserName())
	 Or Not OnStart
	   And InfoBaseUsers.GetUsers().Count() <> 0 Then
		Try
			IBUser = InfobaseDummyUser();
		Except
			ErrorInfo = ErrorInfo();
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot create utility user ""%1"" due to:
				           |%2';"),
				InternalUsername(),
				ErrorProcessing.DetailErrorDescription(ErrorInfo));
			Raise ErrorText;
		EndTry;
		If IBUser <> Undefined Then
			UserName = IBUser.Name;
		EndIf;
	EndIf;
	
	MinRetryInterval = 60;
	MaxRetryInterval = 20*60;
	ReviseMinCheckInterval(MinRetryInterval);
	
	If ValueIsFilled(RepeatPeriod) Then
		If RepeatPeriod < MinRetryInterval Then
			RepeatPeriod = MinRetryInterval;
		ElsIf RepeatPeriod > MaxRetryInterval Then
			RepeatPeriod = MaxRetryInterval;
		Else
			WholePartCount = Int(RepeatPeriod / 15);
			Balance = RepeatPeriod - WholePartCount * 15;
			If Balance <> 0 Then
				RepeatPeriod = WholePartCount * 15;
			EndIf;
		EndIf;
	Else
		RepeatPeriod = MaxRetryInterval;
	EndIf;
	
	Schedule = New JobSchedule;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.RepeatPeriodInDay = RepeatPeriod;
	
	JobMetadata = Metadata.ScheduledJobs.SendServerNotificationsToClients;
	JobParameters = New Structure("Key, RestartIntervalOnFailure,
	|RestartCountOnFailure");
	FillPropertyValues(JobParameters, JobMetadata);
	JobParameters.Insert("Use", Enable);
	JobParameters.Insert("UserName", UserName);
	JobParameters.Insert("Schedule", Schedule);
	
	If Common.DataSeparationEnabled() Then
		Filter = New Structure("MethodName", JobMetadata.MethodName);
	Else
		Filter = New Structure("Metadata", JobMetadata);
	EndIf;
	FoundJobs = ScheduledJobsServer.FindJobs(Filter);
	
	If FoundJobs.Count() > 1 Then
		For Each FoundJob In FoundJobs Do
			If FoundJob = FoundJobs[0] Then
				Continue;
			EndIf;
			ScheduledJobsServer.DeleteJob(FoundJob);
		EndDo;
	EndIf;
	
	If FoundJobs.Count() = 0 Then
		BeginTransaction();
		Try
			ScheduledJobsServer.BlockARoutineTask(JobMetadata);
			FoundJobs = ScheduledJobsServer.FindJobs(Filter);
			If FoundJobs.Count() = 0 Then
				JobParameters.Insert("Metadata", JobMetadata);
				ScheduledJobsServer.AddJob(JobParameters);
				UpdateSendStatus(New Structure("MinCheckInterval", RepeatPeriod),
					"MinCheckInterval");
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry
	EndIf;
	
	If FoundJobs.Count() = 0 Then
		Return;
	EndIf;
	
	Job = FoundJobs[0];
	If AreJobParametersMatch(Job, JobParameters, OnStart) Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		ScheduledJobsServer.BlockARoutineTask(Job.UUID);
		FoundJobs = ScheduledJobsServer.FindJobs(Filter);
		If FoundJobs.Count() = 0
		 Or FoundJobs[0].UUID <> Job.UUID Then
			ConfigureJobSendServerNotificationsToClientsNoAttempt(Enable, RepeatPeriod, OnStart);
		ElsIf Not AreJobParametersMatch(FoundJobs[0], JobParameters, OnStart) Then
			If OnStart And RepeatPeriod >= FoundJobs[0].Schedule.RepeatPeriodInDay Then
				JobParameters.Delete("Schedule");
			EndIf;
			ScheduledJobsServer.ChangeJob(FoundJobs[0].UUID, JobParameters);
			If JobParameters.Property("Schedule") Then
				UpdateSendStatus(New Structure("MinCheckInterval", RepeatPeriod),
					"MinCheckInterval");
			EndIf;
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry
	
EndProcedure

Function NameOfNotificationAllSessionsSleepingJobDisabled()
	Return "StandardSubsystems.Core.ServerNotifications.AllSessionsSleepingJobDisabled";
EndFunction

Procedure DeleteServerNotification(NotificationID)
	
	RecordSet = ServiceRecordSet(InformationRegisters.SentServerNotifications);
	RecordSet.Filter.NotificationID.Set(NotificationID);
	RecordSet.Write();
	
EndProcedure

Procedure SetUsageOfJobSendServerNotificationsToClients(Use)
	
	Try
		SetUsageOfJobSendServerNotificationsToClientsNoAttempt(Use);
	Except
		ErrorInfo = ErrorInfo();
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot change the usage of
			           |the ""%1"" scheduled job due to:
			           |%2';"),
			Metadata.ScheduledJobs.SendServerNotificationsToClients.Name,
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		WriteLogEvent(
			NStr("en = 'Server notifications.Scheduled job setup error';",
				Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, ErrorText);
	EndTry;
	
EndProcedure

Procedure SetUsageOfJobSendServerNotificationsToClientsNoAttempt(Use)
	
	Jobs = ScheduledJobsServer.FindJobs(New Structure("Metadata",
		Metadata.ScheduledJobs.SendServerNotificationsToClients));
	
	For Each Job In Jobs Do
		ScheduledJobsServer.ChangeJob(Job.UUID,
			New Structure("Use", Use));
	EndDo;
	
EndProcedure

Function AreJobParametersMatch(Job, JobParameters, OnStart)
	
	For Each KeyAndValue In JobParameters Do
		If Job[KeyAndValue.Key] = KeyAndValue.Value Then
			Continue;
		EndIf;
		If KeyAndValue.Key = "Schedule" Then
			If OnStart Then
				If JobParameters.Schedule.RepeatPeriodInDay
				   < Job.Schedule.RepeatPeriodInDay Then
					Return False;
				EndIf;
				NewSchedule = New JobSchedule;
				FillPropertyValues(NewSchedule, JobParameters.Schedule);
				NewSchedule.RepeatPeriodInDay =
					Job.Schedule.RepeatPeriodInDay;
			Else
				NewSchedule = JobParameters.Schedule;
			EndIf;
			If String(Job[KeyAndValue.Key]) = String(NewSchedule) Then
				Continue;
			EndIf;
		EndIf;
		Return False;
	EndDo;
	
	Return True;
	
EndFunction

Function EventLogInteractionSystemErrorSeverity(ErrorInfo)
	
	LogLevel = EventLogLevel.Error;
	If Not Common.SubsystemExists("StandardSubsystems.Conversations") Then
		Return LogLevel;
	EndIf;
	
	ModuleConversations = Common.CommonModule("Conversations");
	If ModuleConversations.IsInteractionSystemConnectError(ErrorInfo) Then
		LogLevel = EventLogLevel.Warning;
	EndIf;
	
	Return LogLevel;
	
EndFunction

// Parameters:
//  IsInternal - Boolean - If True and the name of the current user is empty,
//     create a utility user and assign it to the scheduled job.
//
// Returns:
//  Boolean
//
Function IsCurrentUserRegisteredInInteractionSystem(UserIDCollaborationSystem = Undefined)
	
	If Not CollaborationSystemConnected() Then
		Return False;
	EndIf;
	
	IBUser = InfoBaseUsers.CurrentUser();
	If Not ValueIsFilled(IBUser.Name)
	 Or Not Common.SubsystemExists("StandardSubsystems.Conversations")
	 Or IsInteractionSystemTemporarilyUnavailable() Then
		Return False;
	EndIf;
	
	ModuleConversations = Common.CommonModule("Conversations");
	AuthorizedUser = Users.AuthorizedUser();
	Try
		UserIDCollaborationSystem = ModuleConversations.CollaborationSystemUser(
			AuthorizedUser, True);
	Except
		ErrorInfo = ErrorInfo();
		If IsInteractionSystemTemporarilyUnavailable(True) Then
			Return False;
		EndIf;
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot register current user
			           |""%1 (%2)""
			           |in the collaboration system due to:
			           |%3';"),
			IBUser.Name,
			Lower(IBUser.UUID),
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		WriteLogEvent(
			NStr("en = 'Server notifications.An error occurred when registering the user in the collaboration system';",
				Common.DefaultLanguageCode()),
			EventLogInteractionSystemErrorSeverity(ErrorInfo),,,
			ErrorText);
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

Function IsInteractionSystemTemporarilyUnavailable(CheckAvailability = False)
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	ParameterName = "StandardSubsystems.Core.InteractionSystemFailedAccessDate";
	PreviousValue2 = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
	PreviousValue2 = ?(TypeOf(PreviousValue2) = Type("Date"), PreviousValue2, '00010101');
	
	If ValueIsFilled(PreviousValue2)
	   And PreviousValue2 + 60*5 > CurrentSessionDate()
	   And PreviousValue2 - 60 < CurrentSessionDate() Then
		Return True;
	EndIf;
	
	If Not CheckAvailability Then
		Return False;
	EndIf;
	
	NewValue = '00010101';
	Try
		CollaborationSystem.GetExternalSystemTypes();
	Except
		NewValue = CurrentSessionDate();
		ErrorInfo = ErrorInfo();
	EndTry;
	
	If Not ValueIsFilled(NewValue) Then
		Return False;
	EndIf;
	
	CurrentValue = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
	CurrentValue = ?(TypeOf(CurrentValue) = Type("Date"), CurrentValue, '00010101');
	If PreviousValue2 <> CurrentValue Then
		Return True;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ExtensionVersionParameters");
	LockItem.SetValue("ExtensionsVersion", Catalogs.ExtensionsVersions.EmptyRef());
	LockItem.SetValue("ParameterName", ParameterName);
	
	BeginTransaction();
	Try
		Block.Lock();
		CurrentValue = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
		CurrentValue = ?(TypeOf(CurrentValue) = Type("Date"), CurrentValue, '00010101');
		If PreviousValue2 = CurrentValue Then
			StandardSubsystemsServer.SetExtensionParameter(ParameterName, NewValue, True);
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If PreviousValue2 = CurrentValue Then
		WriteLogEvent(
			NStr("en = 'Server notifications.Collaboration system is unavailable';",
				Common.DefaultLanguageCode()),
			EventLogLevel.Warning,,,
			ErrorProcessing.BriefErrorDescription(ErrorInfo));
	EndIf;
	
	Return True;
	
EndFunction

Function InfobaseDummyUser()
	
	UserName = InternalUsername();
	IBUser = InfoBaseUsers.FindByName(UserName);
	WriteIBUser = False;
	
	Properties = New Structure;
	Properties.Insert("Name", UserName);
	Properties.Insert("FullName", UserName);
	Properties.Insert("StandardAuthentication", False);
	Properties.Insert("CannotChangePassword", True);
	Properties.Insert("ShowInList", False);
	Properties.Insert("OpenIDAuthentication", False);
	Properties.Insert("OpenIDConnectAuthentication", False);
	Properties.Insert("AccessTokenAuthentication", False);
	Properties.Insert("OSAuthentication", False);
	Properties.Insert("OSUser", "");
	
	If IBUser = Undefined Then
		If InfoBaseUsers.GetUsers().Count() = 0 Then 
			Return Undefined;
		EndIf;
		IBUser = InfoBaseUsers.CreateUser();
		WriteIBUser = True;
	Else
		CurrentProperties = New Structure(New FixedStructure(Properties));
		FillPropertyValues(CurrentProperties, IBUser);
		For Each KeyAndValue In Properties Do
			If CurrentProperties[KeyAndValue.Key] <> Properties[KeyAndValue.Key] Then
				WriteIBUser = True;
				Break;
			EndIf;
		EndDo;
		Role = Undefined;
		For Each Role In IBUser.Roles Do
			Break;
		EndDo;
		If Not IBUser.PasswordIsSet
		 Or Role <> Undefined Then
			WriteIBUser = True;
		EndIf;
	EndIf;
	
	If WriteIBUser Then
		FillPropertyValues(IBUser, Properties);
		NewPassword = String(New UUID);
		If UsersInternal.IsSettings8_3_26Available() Then
			// ACC:488-off - Support of new 1C:Enterprise methods (the executable code is safe)
			IBUser.StoredPasswordValue =
				Eval("EvaluateStoredUserPasswordValue(NewPassword)");
			// ACC:488-on
		Else
			IBUser.StoredPasswordValue =
				Users.PasswordHashString(NewPassword);
		EndIf;
		IBUser.Roles.Clear();
		IBUser.Write();
	EndIf;
	
	If InformationRegisters.ApplicationRuntimeParameters.UpdateRequired1() Then
		Return IBUser;
	EndIf;
	
	IBUserID = IBUser.UUID;
	
	Query = New Query;
	Query.SetParameter("IBUserID", IBUserID);
	Query.Text =
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.IBUserID = &IBUserID";
	
	If Not Query.Execute().IsEmpty() Then
		Return IBUser;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Description", IBUser.FullName);
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Description = &Description
	|	AND Users.IsInternal";
	
	RefToNew = Catalogs.Users.GetRef(
		New UUID("ea3b6bcf-d6d8-11ee-886a-b06ebfbf08c7"));
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.Users");
	LockItem.SetValue("Ref", RefToNew);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		RefToExisting = Selection.Ref; // CatalogRef.Users
		LockItem = Block.Add("Catalog.Users");
		LockItem.SetValue("Ref", RefToExisting);
	Else
		RefToExisting = Undefined;
	EndIf;
	
	BeginTransaction();
	Try
		Block.Lock();
		User = RefToNew.GetObject();

		If User = Undefined
		   And ValueIsFilled(RefToExisting) Then
			
			User = RefToExisting.GetObject();
			If User <> Undefined Then
				ExistingInfobaseUser = InfoBaseUsers.FindByUUID(
					User.IBUserID);
				If ExistingInfobaseUser <> Undefined Then
					User = Undefined;
				EndIf;
			EndIf;
		EndIf;
		
		If User = Undefined Then
			User = Catalogs.Users.CreateItem();
			User.SetNewObjectRef(RefToNew);
		EndIf;
		
		IBUserDetails = New Structure;
		IBUserDetails.Insert("Action", "Write");
		IBUserDetails.Insert("UUID", IBUserID);
		
		User.Description = IBUser.FullName;
		User.IsInternal = True;
		User.AdditionalProperties.Insert("IBUserDetails", IBUserDetails);
		User.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return IBUser;
	
EndFunction

Function InternalUsername()
	
	Return "SendServerNotifications";
	
EndFunction

Function ServiceAdministratorSession()
	
	If Not Common.DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		Return ModuleSaaSOperations.SessionWithoutSeparators();
	EndIf;
	
	Return False;
	
EndFunction

Function UseCollaborationSystemInFileInfobase()
	
	Return False;
	
EndFunction

Function CollaborationSystemConnected(RefreshCache = False, DeliverWithoutCS = Undefined) Export
	
	LastCheck = ServerNotificationsInternalCached.LastCheckOfInteractionSystemConnection();
	
	If LastCheck.Date + 300 > CurrentSessionDate() And Not RefreshCache Then
		Return LastCheck.Connected;
	EndIf;
	
	LastCheck.Date = CurrentSessionDate();
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	If ServiceAdministratorSession()
	 Or Not UseCollaborationSystemInFileInfobase()
	   And Common.FileInfobase() Then
		
		LastCheck.Connected = False;
	
	ElsIf Common.SubsystemExists("StandardSubsystems.Conversations") Then
		ModuleConversations = Common.CommonModule("Conversations");
		LastCheck.Connected = ModuleConversations.CollaborationSystemConnected();
	Else
		LastCheck.Connected = False;
	EndIf;
	
	If LastCheck.Connected Then
		If DeliverWithoutCS = Undefined Then
			DeliverWithoutCS = Constants.DeliverServerNotificationsWithoutCollaborationSystem.Get();
		EndIf;
		If DeliverWithoutCS Then
			LastCheck.Connected = False;
		EndIf;
	EndIf;
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Return LastCheck.Connected;
	
EndFunction

Procedure OnChangeConstantDeliverServerNotificationsWithoutCollaborationSystem(DeliverWithoutCS) Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	CollaborationSystemConnected = CollaborationSystemConnected(True);
	
	If Not CollaborationSystemConnected And DeliverWithoutCS Then
		CollaborationSystemConnected(True, False);
	EndIf;
	
	SendServerNotification(
		"StandardSubsystems.Core.ServerNotifications.CollaborationSystemConnected",
		CollaborationSystemConnected, Undefined, True);
	
	If Not CollaborationSystemConnected And DeliverWithoutCS Then
		CollaborationSystemConnected(True);
	EndIf;
	
EndProcedure

Function PersonalChatID(IBUserID = Undefined,
			UserIDCollaborationSystem = Undefined)
	
	SetPrivilegedMode(True);
	If IBUserID = Undefined Then
		UUID = InfoBaseUsers.CurrentUser().UUID;
	Else
		UUID = IBUserID;
	EndIf;
	PersonalChatKey = "ServerNotifications" + "_" + Lower(UUID);
	
	Try
		ShouldUpdateChatMembers = UserIDCollaborationSystem <> Undefined;
		AttemptNumber = 1;
		CreatedOn = False;
		While True Do
			Conversation = CollaborationSystem.GetConversation(PersonalChatKey);
			If Conversation <> Undefined Then
				Break;
			EndIf;
			If UserIDCollaborationSystem = Undefined Then
				If IBUserID = Undefined Then
					UserIDCollaborationSystem = CollaborationSystem.CurrentUserID();
				Else
					Try
						UserIDCollaborationSystem = CollaborationSystem.GetUserID(UUID);
					Except
						UserIDCollaborationSystem = CollaborationSystem.CurrentUserID();
					EndTry;
				EndIf;
			EndIf;
			NewConversation = CollaborationSystem.CreateConversation();
			NewConversation.Displayed = False;
			NewConversation.Key = PersonalChatKey;
			NewConversation.Members.Add(UserIDCollaborationSystem);
			Try
				NewConversation.Write();
				Conversation = NewConversation;
				CreatedOn = True;
				Break;
			Except
				AttemptNumber = AttemptNumber + 1;
				If AttemptNumber > 10 Then
					Raise;
				EndIf;
			EndTry;
		EndDo;
		If Not CreatedOn
		   And (Conversation.Displayed
		      Or ShouldUpdateChatMembers
		        And (Conversation.Members.Count() <> 1
		           Or Not Conversation.Members.Contains(UserIDCollaborationSystem))) Then
			Conversation.Displayed = False;
			If ShouldUpdateChatMembers Then
				Conversation.Members.Clear();
				Conversation.Members.Add(UserIDCollaborationSystem);
			EndIf;
			Conversation.Write();
		EndIf;
	Except
		ErrorInfo = ErrorInfo();
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot create a personal conversation for user ""%1 (%2)"" due to:
			           |%3';"),
			InfoBaseUsers.CurrentUser().Name,
			Lower(IBUserID),
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		WriteLogEvent(
			NStr("en = 'Server notifications.An error occurred when creating a personal conversation';",
				Common.DefaultLanguageCode()),
			EventLogInteractionSystemErrorSeverity(ErrorInfo),,, ErrorText);
		Return Undefined;
	EndTry;
	SetPrivilegedMode(False);
	
	Return Conversation.ID;
	
EndFunction

Function GlobalChatID()
	
	GlobalChatKey = "ServerNotifications";
	
	SetPrivilegedMode(True);
	Try
		Conversation = CollaborationSystem.GetConversation(GlobalChatKey);
		CreatedOn = False;
		If Conversation = Undefined Then
			Conversation = CollaborationSystem.CreateConversation();
			Conversation.Displayed = False;
			Conversation.Key = GlobalChatKey;
			Conversation.Members.Add(CollaborationSystem.StandardUsers.AllApplicationUsers);
			Try
				Conversation.Write();
				CreatedOn = True;
			Except
				CreatedOn = False;
			EndTry;
			If Not CreatedOn Then
				ExistingChat = CollaborationSystem.GetConversation(GlobalChatKey);
				If ExistingChat <> Undefined Then
					Conversation = ExistingChat;
				Else
					Conversation.Write();
					CreatedOn = True;
				EndIf;
			EndIf;
		EndIf;
		If Not CreatedOn And Conversation.Displayed Then
			Conversation.Displayed = False;
			Conversation.Write();
		EndIf;
	Except
		ErrorInfo = ErrorInfo();
		WriteLogEvent(
			NStr("en = 'Server notifications.An error occurred when creating a common conversation';",
				Common.DefaultLanguageCode()),
			EventLogInteractionSystemErrorSeverity(ErrorInfo),,,
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		Return Undefined;
	EndTry;
	SetPrivilegedMode(False);
	
	Return Conversation.ID;
	
EndFunction

// Delivers a message containing arbitrary data from the client to the server.
//
// Throws an exception if the delivery failed.
//
// Parameters: 
//   Data - See MessageNewData
//   ConversationID - CollaborationSystemConversationID
//
// Returns:
//  Boolean - True if the message is successfully written to the Collaboration System.
//
Function SendMessage(Data, ConversationID)
	
	ProcedureName = TimeConsumingOperations.FullNameOfLongRunningOperationAppliedProcedure();
	Text = Data.NameOfAlert + "
		|" + ?(ValueIsFilled(Data.NotificationID), Data.NotificationID, "-") + "
		|" + ?(ValueIsFilled(ProcedureName), ProcedureName, "-");
	
	Try
		NewMessage = CollaborationSystem.CreateMessage(ConversationID);
		NewMessage.Data = Data;
		NewMessage.Date   = CurrentSessionDate();
		NewMessage.Text  = New FormattedString(Text);
		NewMessage.Write();
	Except
		ErrorInfo = ErrorInfo();
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot send the message to conversation %1 due to:
			           |%2';"),
			Lower(ConversationID),
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		WriteLogEvent(
			NStr("en = 'Server notifications.Send message error';",
				Common.DefaultLanguageCode()),
			EventLogInteractionSystemErrorSeverity(ErrorInfo),,, ErrorText);
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

Procedure CleanUpObsoleteMessages(SendStatus)
	
	NewDate = BegOfHour(CurrentSessionDate());
	Period = 60*60;
	If SendStatus.LastMessageClearDate + Period > NewDate Then
		Return;
	EndIf;
	
	Boundary = NewDate - Period;
	
	Try
		ChatsFilter = New CollaborationSystemConversationsFilter;
		ChatsFilter.Group = True;
		ChatsFilter.Displayed = False;
		FoundDiscussions = CollaborationSystem.GetConversations(ChatsFilter);
		For Each Conversation In FoundDiscussions Do
			If Not StrStartsWith(Conversation.Key, "ServerNotifications") Then
				Continue;
			EndIf;
			MessagesFilter = New CollaborationSystemMessagesFilter;
			MessagesFilter.Conversation = Conversation.ID;
			MessagesFilter.SortDirection = SortDirection.Asc;
			Messages = CollaborationSystem.GetMessages(MessagesFilter);
			For Each Message In Messages Do
				If Message.Date < Boundary Then
					CollaborationSystem.DeleteMessage(Message.ID);
				EndIf;
			EndDo;
		EndDo;
		SendStatus.LastMessageClearDate = NewDate;
	Except
		ErrorInfo = ErrorInfo();
		WriteLogEvent(
			NStr("en = 'Server notifications.An error occurred when clearing obsolete messages';",
				Common.DefaultLanguageCode()),
			EventLogInteractionSystemErrorSeverity(ErrorInfo),,,
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
	EndTry;
	
EndProcedure

Function ServiceRecordSet(RegisterManager)
	
	RecordSet = RegisterManager.CreateRecordSet();
	RecordSet.AdditionalProperties.Insert("DontControlObjectsToDelete");
	RecordSet.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	RecordSet.DataExchange.Recipients.AutoFill = False;
	RecordSet.DataExchange.Load = True;
	
	Return RecordSet;
	
EndFunction

Function ServiceValueManager(ManagerOfConstant)
	
	ValueManager = ManagerOfConstant.CreateValueManager();
	ValueManager.AdditionalProperties.Insert("DontControlObjectsToDelete");
	ValueManager.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	ValueManager.DataExchange.Recipients.AutoFill = False;
	ValueManager.DataExchange.Load = True;
	
	Return ValueManager;
	
EndFunction

#EndRegion
