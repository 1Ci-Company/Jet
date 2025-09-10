///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

// See ServerNotifications.SessionUndeliveredServerNotifications
Function SessionUndeliveredServerNotifications(Val Parameters) Export
	
	Return ServerNotifications.SessionUndeliveredServerNotifications(Parameters);
	
EndFunction

// Parameters:
//  LongDesc - Structure:
//   * Date - Date
//   * Id - String
//   * Conversation - String
//   * Text - String
//   * DetailErrorDescription - String
//
Procedure LogErrorGettingDataFromMessage(Val LongDesc) Export
	
	If StrLineCount(LongDesc.Text) = 3 Then
		NameOfAlert = TrimAll(StrGetLine(LongDesc.Text, 1));
		NotificationID = Lower(TrimAll(StrGetLine(LongDesc.Text, 2)));
		LongRunningOperationProcedureName = TrimAll(StrGetLine(LongDesc.Text, 3));
		If StringFunctionsClientServer.IsUUID(NotificationID) Then
			Query = New Query;
			Query.SetParameter("NotificationID", NotificationID);
			Query.Text =
			"SELECT
			|	SentServerNotifications.NotificationContent AS NotificationContent
			|FROM
			|	InformationRegister.SentServerNotifications AS SentServerNotifications
			|WHERE
			|	SentServerNotifications.NotificationID <> &NotificationID";
			SetPrivilegedMode(True);
			Selection = Query.Execute().Select();
			SetPrivilegedMode(False);
			If Selection.Next() Then
				NotificationContent = Selection.NotificationContent;
				If TypeOf(NotificationContent) = Type("ValueStorage") Then
					XMLNotificationContent = XMLString(NotificationContent);
				EndIf;
			Else
				XMLNotificationContent = "<" + NStr("en = 'The notification content is not found in the database';tr = 'Bildirimin içeriği veritabanında bulunamadı'") + ">"; 
			EndIf;
		Else
			XMLNotificationContent = "<" + NStr("en = 'The notification ID is not a UUID';tr = 'Bildirimin ID''si UUID değil'") + ">"; 
		EndIf;
	EndIf;
	If Not ValueIsFilled(NameOfAlert) Then
		NameOfAlert = "<" + NStr("en = 'No data';tr = 'Veri yok'") + ">";
	EndIf;
	If Not ValueIsFilled(NotificationID) Then
		NotificationID = "<" + NStr("en = 'No data';tr = 'Veri yok'") + ">";
	EndIf;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'When accessing the ""%1"" property of the collaboration system message with properties:
		           |- Date: %2
		           |- ID: %3
		           |- Conversation: %4
		           |- Text
		           |	Notification name: %5
		           |	Notification ID: %6';tr = 'Ortak çalışma sisteminin ""%1"" özelliğine erişirken:
		           |- Tarih: %2
		           |- ID: %3
		           |- Sohbet: %4
		           |- Metin
		           |	Bildirim adı: %5
		           |	Bildirim ID''si: %6'"),
		"Data",
		LongDesc.Date,
		LongDesc.Id,
		LongDesc.Conversation,
		NameOfAlert,
		NotificationID);
	
	If ValueIsFilled(LongRunningOperationProcedureName)
	   And LongRunningOperationProcedureName <> "-" Then
		
		ErrorText = ErrorText + "
		|	" + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Long-running operation procedure name: %1';tr = 'Uzun süreli işlem prosedürü adı: %1'"),
			LongRunningOperationProcedureName);
	EndIf;
	
	ErrorText = ErrorText + Chars.LF;
	ErrorText = ErrorText + StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'An error occurred:
		           |
		           |%1';tr = 'Hata oluştu:
		           |
		           |%1'"),
		LongDesc.DetailErrorDescription);
	
	If ValueIsFilled(XMLNotificationContent)
	   And NotificationID <> "-" Then
		
		ErrorText = ErrorText + Chars.LF + Chars.LF;
		ErrorText = ErrorText + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Notification content in a value storage format in XML (from the database):
			           |%1';tr = 'XML''de (veritabanından) değer saklama formatında bildirim içeriği:
			           |%1'"),
			XMLNotificationContent);
	EndIf;
	
	WriteLogEvent(
		NStr("en = 'Server notifications.An error occurred when receiving the notification data from the message';tr = 'Sunucu bildirimleri.Mesajdan bildirim verileri alınırken hata oluştu'",
			Common.DefaultLanguageCode()),
		EventLogLevel.Error,, NameOfAlert, ErrorText);
	
EndProcedure

// Parameters:
//  Comment - String - Comment for the Event log
//
Procedure WritePerformanceIndicators(Val Comment) Export
	
	WriteLogEvent(
		NStr("en = 'Server notifications.Performance indicators';tr = 'Sunucu bildirimleri.Performans göstergeleri'",
			Common.DefaultLanguageCode()),
		EventLogLevel.Information,,, Comment);
	
EndProcedure

#EndRegion
