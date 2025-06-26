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
	
	OutboundMessageStatus = NStr("en = 'Sending message…';");
	MessageText = Parameters.Text;
	
	PhoneNumbers = New Array;
	If TypeOf(Parameters.RecipientsNumbers) = Type("Array") Then
		For Each PhoneInformation In Parameters.RecipientsNumbers Do
			PhoneNumbers.Add(PhoneInformation.Phone);
		EndDo;
	ElsIf TypeOf(Parameters.RecipientsNumbers) = Type("ValueList") Then
		For Each PhoneInformation In Parameters.RecipientsNumbers Do
			PhoneNumbers.Add(PhoneInformation.Value);
		EndDo;
	Else
		PhoneNumbers.Add(String(Parameters.RecipientsNumbers));
	EndIf;
	
	If PhoneNumbers.Count() = 0 Then
		Items.RecipientNumberGroup.Visible = True;
	EndIf;
	
	RecipientsNumbers = StrConcat(PhoneNumbers, ", ");
	
	TitleTemplate1 = NStr("en = 'Text message to: %1';");
	If PhoneNumbers.Count() > 1 Then
		TitleTemplate1 = NStr("en = 'Text message to: %1';");
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, RecipientsNumbers);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	CharactersInMessage = StrLen(MessageText);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure MentionSenderNameOnChange(Item)
	Items.SenderName.Enabled = MentionSenderName;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Send(Command)
	
	If StrLen(MessageText) = 0 Then
		ShowMessageBox(, NStr("en = 'Enter a message text';"));
		Return;
	EndIf;
	
	If Not SMSMessageSendingIsSetUp() Then
		OpenForm("CommonForm.OutboundSMSSettings");
		Return;
	EndIf;
	
	Items.Pages.CurrentPage = Items.StatusPage;
	
	If Items.Find("SMSSendingOpenSetting") <> Undefined Then
		Items.SMSSendingOpenSetting.Visible = False;
	EndIf;
	
	Items.Close.Visible = True;
	Items.Close.DefaultButton = True;
	Items.Send.Visible = False;
	
	// Send from server context.
	SendSMS();

	// Check a sending status.
	If Not IsBlankString(MessageID) Then
		Items.Pages.CurrentPage = Items.MessageSentPage;
		AttachIdleHandler("CheckDeliveryStatus", 2, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SendSMS()
	
	// Reset a displayed delivery status.
	MessageID = "";
	
	// Prepare recipient numbers.
	NumbersArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(RecipientsNumbers, ", ", True);
	
	// Send.
	SendingResult = SendSMSMessage.SendSMS(NumbersArray, MessageText, ?(MentionSenderName, SenderName, Undefined), SendInTransliteration);
	
	// Display information on errors occurred upon sending.
	If IsBlankString(SendingResult.ErrorDescription) Then
		// Check delivery for the first recipient.
		If SendingResult.SentMessages.Count() > 0 Then
			MessageID = SendingResult.SentMessages[0].MessageID;
		EndIf;
		Items.Pages.CurrentPage = Items.MessageSentPage;
	Else
		Items.Pages.CurrentPage = Items.MessageNotSentPage;
		
		MessageTemplate = NStr("en = 'Couldn''t send the text message.
		|%1.';");
		
		Items.MessageNotSentText.Title = FormattedString(StringFunctionsClientServer.SubstituteParametersToString(
			MessageTemplate, SendingResult.ErrorDescription));
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckDeliveryStatus()
	
	DeliveryResult = DeliveryStatus(MessageID);
	OutboundMessageStatus = DeliveryResult.LongDesc;
	
	DeliveryResults = New Array;
	DeliveryResults.Add("Error");
	DeliveryResults.Add("NotDelivered");
	DeliveryResults.Add("Delivered");
	DeliveryResults.Add("NotSent");
	
	StatusCheckCompleted = DeliveryResults.Find(DeliveryResult.Status) <> Undefined;
	Items.DeliveryStatusCheckGroup.Visible = StatusCheckCompleted;
	
	StateTemplate = NStr("en = 'The message is sent. Delivery status:
		|%1';");
	Items.MessageSentText.Title = StringFunctionsClientServer.SubstituteParametersToString(
		StateTemplate, DeliveryResult.LongDesc);
	
	
	If DeliveryResult.Status = "Error" Then
		Items.MessageSentPicture.Picture = PictureLib.DialogStop;
	Else
		If DeliveryResults.Find(DeliveryResult.Status) <> Undefined Then
			If Not DeliveryResult.Status = "Delivered" Then
				Items.MessageSentPicture.Picture = PictureLib.DialogExclamation;
			EndIf;
			Items.DeliveryStatusCheckGroup.Visible = False;
		Else
			AttachIdleHandler("CheckDeliveryStatus", 2, True);
			Items.DeliveryStatusCheckGroup.Visible = True;
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function DeliveryStatus(MessageID)
	
	DeliveryStatuses = New Map;
	DeliveryStatuses.Insert("Error", NStr("en = 'no connection to the text message service owner';"));
	DeliveryStatuses.Insert("Pending", NStr("en = 'Provider queued message for delivery';"));
	DeliveryStatuses.Insert("Sending2", NStr("en = 'Provider is delivering message';"));
	DeliveryStatuses.Insert("Sent", NStr("en = 'Provider sent the message';"));
	DeliveryStatuses.Insert("NotSent", NStr("en = 'Provider did not send message';"));
	DeliveryStatuses.Insert("Delivered", NStr("en = 'Message is delivered';"));
	DeliveryStatuses.Insert("NotDelivered", NStr("en = 'Message is not delivered';"));
	
	DeliveryResult = New Structure("Status, LongDesc");
	DeliveryResult.Status = SendSMSMessage.DeliveryStatus(MessageID);
	DeliveryResult.LongDesc = DeliveryStatuses[DeliveryResult.Status];
	If DeliveryResult.LongDesc = Undefined Then
		DeliveryResult.LongDesc = "<" + DeliveryResult.Status + ">";
	EndIf;
	
	Return DeliveryResult;
	
EndFunction

&AtClient
Procedure TextChangeEditText(Item, Text, StandardProcessing)
	CharactersInMessage = StrLen(Text);
	StandardProcessing = False;
EndProcedure

&AtServerNoContext
Function SMSMessageSendingIsSetUp()
 	Return SendSMSMessage.SMSMessageSendingSetupCompleted();
EndFunction

&AtServerNoContext
Function FormattedString(Text)
	
	FormattedStrings = New Array;
	
	Rows = StrSplit(Text, Chars.LF, True);
	For RowsIndex = 0 To Rows.UBound() Do
		String = Rows[RowsIndex];
		Words = StrSplit(String, " ", True);
		For WordIndex = 0 To Words.UBound() Do
			Particle = Words[WordIndex];
			If StrStartsWith(Particle, "http://") Or StrStartsWith(Particle, "https://") Then
				FormattedStrings.Add(New FormattedString(Particle, , , , Particle));
			Else
				FormattedStrings.Add(New FormattedString(Particle));
			EndIf;
			If WordIndex <> Words.UBound() Then
				FormattedStrings.Add(" ");
			EndIf;
		EndDo;
		If RowsIndex <> Rows.UBound() Then
			FormattedStrings.Add(Chars.LF);
		EndIf;
	EndDo;
	
	Return New FormattedString(FormattedStrings); // ACC:1356 Does not prevent translating into other languages.
	
EndFunction

#EndRegion
