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
	
	FillFormAttributesFromParameters(Parameters);
	AvailabilityControl();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("SelectAndClose", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OkCommand(Command)
	
	SelectAndClose();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	If Folder <> CurrentFolder Then
		SetEmailFolder();
	EndIf;
	
	If EmailType = "OutgoingEmail" And ReceivedSent = Date(1,1,1) And Modified Then
		
		SelectionResult = New Structure;
		SelectionResult.Insert("RequestDeliveryReceipt", RequestDeliveryReceipt);
		SelectionResult.Insert("RequestReadReceipt", RequestReadReceipt);
		SelectionResult.Insert("IncludeOriginalEmailBody", IncludeOriginalEmailBody);
		SelectionResult.Insert("Folder", Undefined);
		
	Else
		
		SelectionResult = Undefined;
		
	EndIf;
	
	Modified = False;
	NotifyChoice(SelectionResult);
	
EndProcedure

&AtServer
Procedure SetEmailFolder()
	
	Interactions.SetEmailFolder(MailMessage, Folder);
	
EndProcedure

&AtServer
Procedure FillFormAttributeFromParameter(PassedParameters,ParameterName,Var_AttributeName = "")

	If PassedParameters.Property(ParameterName) Then
		
		ThisObject[?(IsBlankString(Var_AttributeName),ParameterName,Var_AttributeName)] = PassedParameters[ParameterName];
		
	EndIf;

EndProcedure

&AtServer
Procedure FillFormAttributesFromParameters(PassedParameters)

	FillFormAttributeFromParameter(PassedParameters,"InternalNumber");
	FillFormAttributeFromParameter(PassedParameters,"CreatedOn");
	FillFormAttributeFromParameter(PassedParameters,"ReceivedEmails","ReceivedSent");
	FillFormAttributeFromParameter(PassedParameters,"Sent","ReceivedSent");
	FillFormAttributeFromParameter(PassedParameters,"RequestDeliveryReceipt");
	FillFormAttributeFromParameter(PassedParameters,"RequestReadReceipt");
	FillFormAttributeFromParameter(PassedParameters,"MailMessage");
	FillFormAttributeFromParameter(PassedParameters,"EmailType");
	FillFormAttributeFromParameter(PassedParameters,"IncludeOriginalEmailBody");
	FillFormAttributeFromParameter(PassedParameters,"Account");
	
	InternetTitles.AddLine(PassedParameters.InternetTitles);
	
	Folder = Interactions.GetEmailFolder(MailMessage);
	CurrentFolder = Folder;

EndProcedure

&AtServer
Procedure AvailabilityControl()

	If EmailType = "OutgoingEmail" Then
		Items.Headers.Title = NStr("en = 'IDs';");
		If ReceivedSent = Date(1,1,1) Then
			Items.RequestDeliveryReceipt.ReadOnly          = False;
			Items.RequestReadReceipt.ReadOnly         = False;
			Items.IncludeOriginalEmailBody.ReadOnly = False;
		EndIf;
	Else
		Items.ReceivedSent.Title = NStr("en = 'Received';");
		Items.IncludeOriginalEmailBody.Visible =False;
	EndIf;
	
	Items.Folder.Enabled = ValueIsFilled(Account);
	
EndProcedure

#EndRegion
