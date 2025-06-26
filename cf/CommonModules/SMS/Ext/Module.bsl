#Region Public

// Backward compatibility.
// It sends a text message via a configured service provider and returns message ID. 
//
// Parameters:
//  RecipientsNumbers - Array - an array of strings containing recipient numbers in format +7XXXXXXXXXX.
//  Text - String - a message text, the maximum length varies depending on operators.
//  SenderName - String - a sender name that recipients will see instead of a number.
//  Transliterate - Boolean - True if the message text is to be transliterated before sending.
//
// Returns:
//  Structure - a sending result:
//    * SentMessages - Array - an array of structures:
//      ** RecipientNumber - String - a number of text message recipient.
//      ** MessageID - String - a text message ID assigned by a provider to track delivery.
//    * ErrorDescription - String - a user presentation of an error. If the string is empty, there is no error.
//
Function SendSMSMessage(RecipientsNumbers, Val Text, SenderName = Undefined, Transliterate = False) Export
	
	Return SendSMSMessage.SendSMS(RecipientsNumbers, Text, SenderName, Transliterate);
	
EndFunction

// Backward compatibility.
// The function requests for a message delivery status from service provider.
//
// Parameters:
//  MessageID - String - ID assigned to a text message upon sending.
//
// Returns:
//  String - a message delivery status returned from service provider:
//           Pending - the message is not processed by the service provider yet (in queue).
//           BeingSent - the message is in the sending queue at the provider.
//           Sent - the message is sent, a delivery confirmation is awaited.
//           NotSent - the message is not sent (insufficient account balance or operator network congestion).
//           Delivered - the message is delivered to the addressee.
//           NotDelivered - cannot deliver the message (the subscriber is not available or delivery 
//                              confirmation from the subscriber is timed out).
//           Error - cannot get a status from service provider (unknown status).
//
Function DeliveryStatus(Val MessageID) Export

	Return SendSMSMessage.DeliveryStatus(MessageID);
	
EndFunction

// Backward compatibility.
// This function checks whether saved text message sending settings are correct.
//
// Returns:
//  Boolean - True if text message sending is set up.
Function SMSMessageSendingSetupCompleted() Export
	
	Return SendSMSMessage.SMSMessageSendingSetupCompleted();
	
EndFunction

// Backward compatibility.
// This function checks whether the current user can send text messages.
// 
// Returns:
//  Boolean - True if text message sending is set up and the current user has sufficient rights to send text messages.
//
Function CanSendSMSMessage() Export
	Return SendSMSMessage.CanSendSMSMessage();
EndFunction

#EndRegion