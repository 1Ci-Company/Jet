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

// Opens the form of current user reminders.
//
Procedure CheckCurrentReminders() Export

	If Not CommonClient.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	// Open a form with the current notifications.
	TimeOfClosest = Undefined;
	NextCheckInterval = 60;
	
	If UserRemindersClient.GetCurrentNotifications(TimeOfClosest).Count() > 0 Then
		UserRemindersClient.OpenNotificationForm();
	ElsIf ValueIsFilled(TimeOfClosest) Then
		NextCheckInterval = Max(Min(TimeOfClosest - CommonClient.SessionDate(), NextCheckInterval), 1);
	EndIf;
	
	AttachIdleHandler("CheckCurrentReminders", NextCheckInterval, True);
	
EndProcedure

#EndRegion
