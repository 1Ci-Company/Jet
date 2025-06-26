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
	
	Items.DueDate.ToolTip
		= Metadata.InformationRegisters.UsersInfo.Resources.ValidityPeriod.Tooltip;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If TypeOf(FormOwner) <> Type("ClientApplicationForm") Then
		Return;
	EndIf;
	
	InactivityPeriod = FormOwner.InactivityPeriodBeforeDenyingAuthorization;
	DueDate      = FormOwner.ValidityPeriod;
	
	If FormOwner.UnlimitedValidityPeriod Then
		PeriodType = "NoExpiration";
		CurrentItem = Items.PeriodTypeNoExpiration;
		
	ElsIf ValueIsFilled(DueDate) Then
		PeriodType = "TillDate";
		CurrentItem = Items.PeriodTypeTillDate;
		
	ElsIf ValueIsFilled(InactivityPeriod) Then
		PeriodType = "InactivityPeriod";
		CurrentItem = Items.PeriodTypeTimeout;
	Else
		PeriodType = "NotSpecified";
		CurrentItem = Items.PeriodTypeNotSpecified;
	EndIf;
	
	UpdateAvailability1();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PeriodTypeOnChange(Item)
	
	UpdateAvailability1();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	
	ClearMessages();
	
	If PeriodType = "TillDate" Then
		If Not ValueIsFilled(DueDate) Then
			CommonClient.MessageToUser(
				NStr("en = 'The date is not specified.';"),, "DueDate");
			Return;
			
		ElsIf DueDate <= BegOfDay(CommonClient.SessionDate()) Then
			CommonClient.MessageToUser(
				NStr("en = 'The expiration date must be tomorrow or later.';"),, "DueDate");
			Return;
		EndIf;
	EndIf;
	
	FormOwner.Modified = True;
	FormOwner.InactivityPeriodBeforeDenyingAuthorization = InactivityPeriod;
	FormOwner.ValidityPeriod = DueDate;
	FormOwner.UnlimitedValidityPeriod = (PeriodType = "NoExpiration");
	
	Items.FormOK.Enabled = False;
	AttachIdleHandler("CloseForm", 0.1, True);
	
EndProcedure

#EndRegion

#Region Private
	
&AtClient
Procedure UpdateAvailability1()
	
	If PeriodType = "TillDate" Then
		Items.DueDate.AutoMarkIncomplete = True;
		Items.DueDate.Enabled = True;
	Else
		Items.DueDate.AutoMarkIncomplete = False;
		DueDate = Undefined;
		Items.DueDate.Enabled = False;
	EndIf;
	
	If PeriodType <> "InactivityPeriod" Then
		InactivityPeriod = 0;
	ElsIf InactivityPeriod = 0 Then
		InactivityPeriod = 60;
	EndIf;
	Items.InactivityPeriod.Enabled = PeriodType = "InactivityPeriod";
	
EndProcedure

&AtClient
Procedure CloseForm()
	
	Close();
	
EndProcedure

#EndRegion
