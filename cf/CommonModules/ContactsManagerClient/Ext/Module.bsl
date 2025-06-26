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

// Handler of the StartChoice event of the contact information form field.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form                - ClientApplicationForm - a form of a contact information owner.
//     Item              - FormField        - a form item containing contact information presentation.
//     Modified   - Boolean           - a flag indicating that the form was modified.
//     StandardProcessing - Boolean           - a flag indicating that standard processing is required for the form event.
//     OpeningParameters    - Structure        - opening parameters of the contact information input form.
//
Procedure StartSelection(Form, Item, Modified = True, StandardProcessing = False, OpeningParameters = Undefined) Export
	OnStartChoice(Form, Item, Modified, StandardProcessing, OpeningParameters, True);
EndProcedure

// Handler of the OnChange event of the contact information form field.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form             - ClientApplicationForm - a form of a contact information owner.
//     Item           - FormField        - a form item containing contact information presentation.
//     IsTabularSection - Boolean           - a flag specifying that the item is part of a form table.
//
Procedure StartChanging(Form, Item, IsTabularSection = False) Export
	
	OnContactInformationChange(Form, Item, IsTabularSection, True, True);
	
EndProcedure

// Handler of the Clearing event for a contact information form field.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form        - ClientApplicationForm - a form of a contact information owner.
//     AttributeName - String           - a name of a form attribute related to contact information presentation.
//
Procedure StartClearing(Val Form, Val AttributeName) Export
	OnClear(Form, AttributeName, True);
EndProcedure

// Handler of the command related to contact information (write an email, open an address, and so on).
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form      - ClientApplicationForm - a form of a contact information owner.
//     CommandName - String           - a name of the automatically generated action command.
//
Procedure StartCommandExecution(Val Form, Val CommandName) Export
	OnExecuteCommand(Form, CommandName, True);
EndProcedure

// URL handler for opening a web page.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//   Form                - ClientApplicationForm - a form of a contact information owner.
//   Item              - FormField - a form item containing contact information presentation.
//   FormattedStringURL - String - a value of the formatted string URL. The parameter
//                                                       is passed by the link.
//   StandardProcessing  - Boolean - this parameter stores the flag of whether the standard
//                                (system) event processing is executed. If this parameter
//                                is set to False in the processing procedure, standard processing
//                                is skipped.
//
Procedure StartURLProcessing(Form, Item, FormattedStringURL, StandardProcessing) Export
	
	OnURLProcessing(Form, Item, FormattedStringURL, StandardProcessing, True);
	
EndProcedure

// URL handler for opening a web page.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//   Form                - ClientApplicationForm - a form of a contact information owner.
//   Item              - FormField - a form item containing contact information presentation.
//   FormattedStringURL - String - a value of the formatted string URL. The parameter
//                                                       is passed by the link.
//   StandardProcessing  - Boolean - this parameter stores the flag of whether the standard
//                                (system) event processing is executed. If this parameter
//                                is set to False in the processing procedure, standard processing
//                                is skipped.
//
Procedure URLProcessing(Form, Item, FormattedStringURL, StandardProcessing) Export
	OnURLProcessing(Form, Item, FormattedStringURL, StandardProcessing, False);
EndProcedure

// Handler of the AutoComplete event of a contact information form field for selecting address options by the entered string.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Item                  - FormField      - a form item containing contact information presentation.
//     Text                    - String         - a text string entered by the user in the contact information field.
//     ChoiceData             - ValueList - contains a value list that will be used for standard
//                                                 event processing.
//     DataGetParameters - Structure
//                              - Undefined - contains search parameters that will be passed
//                                to the GetChoiceData method. For more information, see details of the form field extension for
//                                the AutoComplete input field in Syntax Assistant.
//     Waiting -   Number       - an interval in seconds between text input and an event.
//                                If 0, the event was not triggered by text input
//                                but it was called to generate a quick selection list. 
//     StandardProcessing     - Boolean         - this parameter stores the flag of whether the standard
//                                (system) event processing is executed. If this parameter
//                                is set to False in the processing procedure, standard processing
//                                is skipped.
//
Procedure AutoCompleteAddress(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing) Export
	
	If StrLen(Text) > 2 Then
		SearchString = Text;
	ElsIf StrLen(Item.EditText) > 2 Then
		SearchString = Item.EditText;
	Else
		Return;
	EndIf;
	
	If StrLen(SearchString) > 2 Then
		ContactsManagerInternalServerCall.AutoCompleteAddress(SearchString, ChoiceData);
		If TypeOf(ChoiceData) = Type("ValueList") Then
			StandardProcessing = (ChoiceData.Count() = 0);
		EndIf;
	EndIf;
	
EndProcedure

// Handler of the ChoiceProcessing event of the contact information form field.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form   - ClientApplicationForm - a form of a contact information owner.
//     ValueSelected    - String        - a selected value that will be set as a value of
//                                            the contact information input field.
//     AttributeName         - String        - a name of a form attribute related to contact information presentation.
//     StandardProcessing - Boolean        - this parameter stores the flag of whether the standard
//                                            (system) event processing is executed. If this parameter is
//                                            set to False in the processing procedure, standard processing
//                                            is skipped.
//
Procedure ChoiceProcessing(Val Form, Val ValueSelected, Val AttributeName, StandardProcessing = False) Export
	
	StandardProcessing = False;
	Form[AttributeName] = ValueSelected.Presentation;
	
	FoundRows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).FindRows(New Structure("AttributeName", AttributeName));
	If FoundRows.Count() > 0 Then
		FoundRows[0].Presentation = ValueSelected.Presentation;
		FoundRows[0].Value      = ValueSelected.Address;
	EndIf;
	
EndProcedure

// Opens the address input form for the contact information form.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form     - ClientApplicationForm - a form of a contact information owner.
//     Result - Arbitrary     - data provided by the command handler.
//
Procedure OpenAddressInputForm(Form, Result) Export
	
	If Result <> Undefined Then
		If Result.Property("AddressFormItem") Then
			StartChoice(Form, Form.Items[Result.AddressFormItem]);
		EndIf;
	EndIf;
	
EndProcedure

// Handler of the refresh operation for the contact information form.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form     - ClientApplicationForm - a form of a contact information owner.
//     Result - Arbitrary     - data provided by the command handler.
//
Procedure FormRefreshControl(Form, Result) Export
	
	// Address input form callback analysis.
	OpenAddressInputForm(Form, Result);
	
EndProcedure

// Handler of the ChoiceProcessing event for a world country. 
// Implements functionality for automated creation of WorldCountries catalog item based on user choice.
//
// Parameters:
//     Item              - FormField    - an item containing the world country to be edited.
//     ValueSelected    - Arbitrary - a selection value.
//     StandardProcessing - Boolean       - a flag indicating that standard processing is required for the form event.
//
Procedure WorldCountryChoiceProcessing(Item, ValueSelected, StandardProcessing) Export
	If Not StandardProcessing Then 
		Return;
	EndIf;
	
	SelectedValueType = TypeOf(ValueSelected);
	If SelectedValueType = Type("Array") Then
		ConversionList = New Map;
		For IndexOf = 0 To ValueSelected.UBound() Do
			Data = ValueSelected[IndexOf];
			If TypeOf(Data) = Type("Structure") And Data.Property("Code") Then
				ConversionList.Insert(IndexOf, Data.Code);
			EndIf;
		EndDo;
		
		If ConversionList.Count() > 0 Then
			ContactsManagerInternalServerCall.WorldCountriesCollectionByClassifierData(ConversionList);
			For Each KeyValue In ConversionList Do
				ValueSelected[KeyValue.Key] = KeyValue.Value;
			EndDo;
		EndIf;
		
	ElsIf SelectedValueType = Type("Structure") And ValueSelected.Property("Code") Then
		ValueSelected = ContactsManagerInternalServerCall.WorldCountryByClassifierData(ValueSelected.Code);
		
	EndIf;
	
EndProcedure

// Constructor used to create a structure with contact information form opening parameters.
// The set of fields can be expanded with national-specific properties in the AddressManagerClient common module.
//
// Parameters:
//  ContactInformationKind  - CatalogRef.ContactInformationKinds - a contact information kind.
//                           - Structure - See ContactsManager.ContactInformationKindParameters
//  Value                 - String - a serialized value of contact information fields in JSON or XML format.
//  Presentation            - String - a contact information presentation.
//  Comment              - String - contact information comment.
//  ContactInformationType  - EnumRef.ContactInformationTypes - a contact information type.
//                             If specified, the fields matching the type are added to the returned structure.
// 
// Returns:
//  Structure:
//   * ContactInformationKind - See ContactsManager.ContactInformationKindParameters
//   * ReadOnly          - Boolean - if True, the form will be opened in view-only mode.
//   * Value                - String - A contact information field value in JSON or XML format.
//   * Presentation           - String - a contact information presentation.
//   * ContactInformationType - EnumRef.ContactInformationTypes - a contact information type if it was specified
//                                                                            in the parameters.
//   * Country                  - String - a world country (only if Address is specified as a contact information type).
//   * State                  - String - a value of the state field (only if Address is specified as a contact information type).
//                                       It is relevant for EAEU countries.
//   * IndexOf                  - String - a postal code (only if Address is specified as a contact information type).
//   * PremiseType            - String - a premise type in the address input form (only if Address is specified as a contact
//                                       information type).
//   * CountryCode               - String - a phone code of a world country (only if Phone is specified as a contact information type).
//   * CityCode               - String - a phone code of a city (only if Phone is specified as a contact information type).
//   * PhoneNumber           - String - a phone number (only if Phone is specified as a contact information type).
//   * PhoneExtension              - String - an additional phone number (only if Phone is specified as a contact information type).
//   * Title               - String - a form title. Default title is presentation of a contact information kind.
//   * AddressType               - String - options: An empty string (the default value), FreeForm, and EEU;
//                                       For Russian Federation: Municipal or AdministrativeAndTerritorial.
//                                       If not specified (an empty string), it is the address
//                                       selected by a user in the address input form (for existing addresses) or "Municipal" (for new addresses).
//
Function ContactInformationFormParameters(ContactInformationKind, Value,
	Presentation = Undefined, Comment = Undefined, ContactInformationType = Undefined) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("ContactInformationKind", ContactInformationKind);
	FormParameters.Insert("ReadOnly", False);
	FormParameters.Insert("Value", Value);
	FormParameters.Insert("Presentation", Presentation);
	FormParameters.Insert("Comment", Comment);
	FormParameters.Insert("AddressType", "");
	If ContactInformationType <> Undefined Then
		FormParameters.Insert("ContactInformationType", ContactInformationType);
		If ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Address") Then
			FormParameters.Insert("Country");
			FormParameters.Insert("State");
			FormParameters.Insert("IndexOf");
			FormParameters.Insert("PremiseType", "Appartment");
		ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Phone") Then
			FormParameters.Insert("CountryCode");
			FormParameters.Insert("CityCode");
			FormParameters.Insert("PhoneNumber");
			FormParameters.Insert("PhoneExtension");
		EndIf;
	EndIf;
	
	If TypeOf(ContactInformationKind) = Type("Structure") And ContactInformationKind.Property("Description") Then
		FormParameters.Insert("Title", ContactInformationKind.Description);
	Else
		FormParameters.Insert("Title", String(ContactInformationKind));
	EndIf;
	
	Return FormParameters;
	
EndFunction

// Opens an appropriate contact information form for editing or viewing.
//
//  Parameters:
//      Parameters    - Arbitrary - the ContactInformationFormParameters function result.
//      Owner     - Arbitrary - a form parameter.
//      Notification   - NotifyDescription - used to process form closing.
//
//  Returns:
//   ClientApplicationForm - a requested form.
//
Function OpenContactInformationForm(Parameters, Owner = Undefined, Notification = Undefined) Export
	Parameters.Insert("OpenByScenario", True);
	Return OpenForm("DataProcessor.ContactInformationInput.Form", Parameters, Owner,,,, Notification);
EndFunction

// Creates a contact information email.
//
// Parameters:
//  FieldValues   - String
//                  - Structure
//                  - Map
//                  - ValueList - a contact information value.
//  EmailParameters - See SMSAndEmailParameters
//  DeleteExpectedKind  - CatalogRef.ContactInformationKinds
//                       - EnumRef.ContactInformationTypes
//                       - Structure - Obsolete. Instead, use "EmailParameters".
//  ObsoleteContactInformationSource - AnyRef - Obsolete. Instead, use "EmailParameters".
//  ObsoleteAttributeName  - String - Obsolete. Instead, use "EmailParameters".
//
Procedure CreateEmailMessage(Val FieldValues, Val EmailParameters = Undefined,
	DeleteExpectedKind = Undefined, ObsoleteContactInformationSource = Undefined, 
	ObsoleteAttributeName = "") Export
	
	If TypeOf(EmailParameters) = Type("String") Then
		Presentation = EmailParameters;
		EmailParameters = SMSAndEmailParameters();
		EmailParameters.Presentation = Presentation;
		EmailParameters.ExpectedKind = DeleteExpectedKind;
		EmailParameters.ContactInformationSource = ObsoleteContactInformationSource;
		EmailParameters.AttributeName = ObsoleteAttributeName;
	ElsIf EmailParameters = Undefined Then
		EmailParameters = SMSAndEmailParameters();
	EndIf;
	
	MailAddr = "";
	If ValueIsFilled(EmailParameters.Presentation) 
		And CommonClientServer.EmailAddressMeetsRequirements(EmailParameters.Presentation, True) Then
			MailAddr = Presentation;
	EndIf;
	
	If IsBlankString(MailAddr) Then
		
		ContactInformationDetails = ContactsManagerClientServer.ContactInformationDetails(
			FieldValues, EmailParameters.Presentation, EmailParameters.ExpectedKind);
		
		ContactInformation = ContactsManagerInternalServerCall.TransformContactInformationXML(ContactInformationDetails);
		If ValueIsFilled(ContactInformation.Presentation) Then
			MailAddr = ContactInformation.Presentation;
		Else
			MailAddr = ContactsManagerInternalServerCall.ContactInformationCompositionString(ContactInformation.XMLData1);
		EndIf;
		
		ErrorText = "";
		InformationType = ContactInformation.ContactInformationType;
		
		If IsBlankString(MailAddr) Then
			ErrorText= NStr("en = 'To send an email, enter an email address.';");
		ElsIf TypeOf(MailAddr) <> Type("String") Or InformationType = Undefined Then
			ErrorText =  NStr("en = 'Cannot send an email as the value is not an email address.';");
		ElsIf InformationType <> PredefinedValue("Enum.ContactInformationTypes.Email") Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot create an email from contact information of the ""%1"" type.';"), InformationType);
		Else
			MailAddresses = CommonClientServer.EmailsFromString(MailAddr);
			ErrorsTexts = New Array;
			For Each MailAddress In MailAddresses Do  
				If ValueIsFilled(MailAddress.ErrorDescription) Then
					ErrorsTexts.Add(MailAddress.ErrorDescription);
				EndIf;
			EndDo;
			ErrorText = StrConcat(ErrorsTexts, Chars.LF);
		EndIf;
		
		If ValueIsFilled(ErrorText) Then
			If ValueIsFilled(EmailParameters.AttributeName) Then
				CommonClient.MessageToUser(ErrorText,, EmailParameters.AttributeName);
			Else
				ShowMessageBox(, ErrorText );
			EndIf;
			Return
		EndIf;
		
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsClient = CommonClient.CommonModule("EmailOperationsClient");
		
		Recipient = New Array;
		Recipient.Add(New Structure("Address, Presentation, ContactInformationSource", 
			MailAddr, StrReplace(String(EmailParameters.ContactInformationSource), ",", ""), 
				EmailParameters.ContactInformationSource));
		SendOptions = New Structure("Recipient", Recipient);
		ModuleEmailOperationsClient.CreateNewEmailMessage(SendOptions);
	Else
		FileSystemClient.OpenURL("mailto:" + MailAddr);
	EndIf;
	
EndProcedure

// Creates a text message based on the contact information.
//
// Parameters:
//  FieldValues - String
//                - Structure
//                - Map
//                - ValueList - contact information.
//  SMSParameters  - See SMSAndEmailParameters
//  DeleteExpectedKind  - CatalogRef.ContactInformationKinds
//                       - EnumRef.ContactInformationTypes
//                       - Structure - Obsolete. Instead, use "SMSParameters".
//  ObsoleteContactInformationSource - AnyRef - Obsolete. Instead, use "SMSParameters".
//
Procedure CreateSMSMessage(Val FieldValues, Val SMSParameters = Undefined,
	Val DeleteExpectedKind = Undefined, ObsoleteContactInformationSource = "") Export
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.SendSMSMessage") Then
		Raise NStr("en = 'Text messaging is not available.';");
	EndIf;
	
	If TypeOf(SMSParameters) = Type("String") Then
		Presentation = SMSParameters;
		SMSParameters = SMSAndEmailParameters();
		SMSParameters.Presentation = Presentation;
		SMSParameters.ExpectedKind = DeleteExpectedKind;
		SMSParameters.ContactInformationSource = ObsoleteContactInformationSource;
	ElsIf SMSParameters = Undefined Then
		SMSParameters = SMSAndEmailParameters();
	EndIf;
	
	RecipientNumber = "";
	If IsBlankString(SMSParameters.Presentation) Then
		
		ContactInformation = ContactsManagerInternalServerCall.TransformContactInformationXML(
			New Structure("FieldValues, Presentation, ContactInformationKind", 
				FieldValues, SMSParameters.Presentation, SMSParameters.ExpectedKind));
		
		ErrorText = "";
		InformationType = ContactInformation.ContactInformationType;
		If InformationType <> PredefinedValue("Enum.ContactInformationTypes.Phone") Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot send the text message as the phone number you provided is invalid: %1.';"), 
				InformationType);
		ElsIf FieldValues = "" And IsBlankString(SMSParameters.Presentation) Then
			ErrorText = NStr("en = 'To send a text message, enter a phone number.';");
		EndIf;
		
		If ValueIsFilled(ErrorText) Then
			If ValueIsFilled(SMSParameters.AttributeName) Then
				CommonClient.MessageToUser(ErrorText,, SMSParameters.AttributeName);
			Else
				ShowMessageBox(, ErrorText );
			EndIf;
			Return
		EndIf;
		
		XMLData = ContactInformation.XMLData1;
		If ValueIsFilled(XMLData) Then
			RecipientNumber = ContactsManagerInternalServerCall.ContactInformationCompositionString(XMLData);
		EndIf;
	
	EndIf;
	
	If IsBlankString(RecipientNumber) Then
		RecipientNumber = TrimAll(SMSParameters.Presentation);
	EndIf;
	
#If MobileClient Then
	Message = New SMSMessage();
	Message.To.Add(RecipientNumber);
	TelephonyTools.SendSMS(Message, True);
	Return;
#EndIf
	
	InformationOnRecipient = New Structure();
	InformationOnRecipient.Insert("Phone",                      RecipientNumber);
	InformationOnRecipient.Insert("Presentation",                String(SMSParameters.ContactInformationSource));
	InformationOnRecipient.Insert("ContactInformationSource", SMSParameters.ContactInformationSource);

	RecipientsNumbers = New Array;
	RecipientsNumbers.Add(InformationOnRecipient);
	
	ModuleSMSClient = CommonClient.CommonModule("SendSMSMessageClient");
	ModuleSMSClient.SendSMS(RecipientsNumbers, "", New Structure("Transliterate", False));
	
EndProcedure

// A parameter constructor for procedures "CreateEmailMessage" and "CreateSMS".
// 
// Returns:
//  Structure:
//    * Presentation - String - The contact information presentation. 
//                                Used in cases when the "FieldValues" parameter is missing the "Presentation" field.
//    * ExpectedKind  - CatalogRef.ContactInformationKinds
//                    - EnumRef.ContactInformationTypes
//                    - Structure - Intended for identifying contact information type in cases where it cannot be done using the "FieldsValues" field.
//    * ContactInformationSource - AnyRef - an owner object of contact information.
//    * AttributeName  - String - The name of the attribute of the calling form that should be associated with the error message.
//                               If not provided, the message will be shown as a warning dialog.
//
Function SMSAndEmailParameters() Export
	Result = New Structure;
	Result.Insert("Presentation", ""); 
	Result.Insert("ExpectedKind", Undefined); 
	Result.Insert("ContactInformationSource", Undefined); 
	Result.Insert("AttributeName", "");
	Return Result;
EndFunction	

// Makes a call to the passed phone number via SIP telephony
// or via Skype if SIP telephony is not available.
//
// Parameters:
//  PhoneNumber -String - a phone number to which the call will be made.
//
Procedure Telephone(PhoneNumber) Export
	
	PhoneNumber = StringFunctionsClientServer.ReplaceCharsWithOther("()_- ", PhoneNumber, "");
	
	ProtocolName = "tel"; // By default, "tel".
	
#If MobileClient Then
		TelephonyTools.DialNumber(PhoneNumber, True);
		Return;
#EndIf
	
#If Not WebClient Then
		AvailableProtocolName = TelephonyApplicationInstalled();
		If AvailableProtocolName = Undefined Then
			StringWithWarning = New FormattedString(
					NStr("en = 'To make a call, install a telecom app. For example,';"),
					 " ", New FormattedString("Skype",,,, "http://www.skype.com"), ".");
			ShowMessageBox(Undefined, StringWithWarning);
			Return;
		ElsIf Not IsBlankString(AvailableProtocolName) Then
			ProtocolName = AvailableProtocolName;
		EndIf;
#EndIf
	
	CommandLine1 = ProtocolName + ":" + PhoneNumber;
	
	Notification = New NotifyDescription("AfterStartApplication", ThisObject);
	FileSystemClient.OpenURL(CommandLine1, Notification);
	
EndProcedure

// Calls via Skype.
//
// Parameters:
//  SkypeUsername - String - a Skype username.
//
Procedure CallSkype(SkypeUsername) Export
	
	OpenSkype("skype:" + SkypeUsername + "?call");

EndProcedure

// Open conversation window (chat) in Skype
//
// Parameters:
//  SkypeUsername - String - a Skype username.
//
Procedure StartCoversationInSkype(SkypeUsername) Export
	
	OpenSkype("skype:" + SkypeUsername + "?chat");
	
EndProcedure

// Opens a contact information reference.
//
// Parameters:
//  FieldValues - String
//                - Structure
//                - Map
//                - ValueList - contact information.
//  Presentation - String - presentation. Used if it is impossible to determine a presentation based on a parameter.
//                            FieldValues (the Presentation field is not available).
//  ExpectedKind  - CatalogRef.ContactInformationKinds
//                - EnumRef.ContactInformationTypes
//                - Structure -
//                      Intended for identifying contact information type in cases where it cannot be done using the "FieldsValues" field.
//
Procedure GoToWebLink(Val FieldValues, Val Presentation = "", ExpectedKind = Undefined) Export
	
	If ExpectedKind = Undefined Then
		ExpectedKind = PredefinedValue("Enum.ContactInformationTypes.WebPage");
	EndIf;
	
	ContactInformation = ContactsManagerInternalServerCall.TransformContactInformationXML(
		New Structure("FieldValues, Presentation, ContactInformationKind", FieldValues, Presentation, ExpectedKind));
	InformationType = ContactInformation.ContactInformationType;
	
	If InformationType <> PredefinedValue("Enum.ContactInformationTypes.WebPage") Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot follow a link from contact information of the ""%1"" type.';"), InformationType);
	EndIf;
		
	XMLData = ContactInformation.XMLData1;

	HyperlinkAddress = ContactsManagerInternalServerCall.ContactInformationCompositionString(XMLData);
	If TypeOf(HyperlinkAddress) <> Type("String") Then
		Raise NStr("en = 'Error getting URL. Invalid contact information type.';");
	EndIf;
	
	If StrFind(HyperlinkAddress, "://") > 0 Then
		FileSystemClient.OpenURL(HyperlinkAddress);
	Else
		FileSystemClient.OpenURL("http://" + HyperlinkAddress);
	EndIf;
EndProcedure

// Shows an address in a browser on Yandex.Maps or Google Maps.
//
// Parameters:
//  Address                       - String - a text presentation of an address.
//  MapServiceName - String - a name of a map service where the address should be shown:
//                                         Yandex.Maps or GoogleMaps.
//
Procedure ShowAddressOnMap(Address, MapServiceName) Export
	CodedAddress = StringDecoding(Address);
	If MapServiceName = "GoogleMaps" Then
		CommandLine1 = "https://maps.google.com/?q=" + CodedAddress;
	Else
		CommandLine1 = "https://maps.yandex.com/?text=" + CodedAddress;
	EndIf;
	
	FileSystemClient.OpenURL(CommandLine1);
	
EndProcedure

// Displays a form with history of contact information changes.
//
// Parameters:
//  Form                         - ClientApplicationForm - a form with contact information.
//  ContactInformationParameters - Structure - information about a contact information item.
//  AsynchronousCall              - Boolean - an internal parameter.
//
Procedure OpenHistoryChangeForm(Form, ContactInformationParameters, AsynchronousCall = False) Export
	
	Result = New Structure("Kind", ContactInformationParameters.Kind);
	FoundRows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).FindRows(Result);
	
	ContactInformationList = New Array;
	For Each ContactInformationRow In FoundRows Do
		ContactInformation = New Structure("Presentation, Value, FieldValues, ValidFrom, Comment");
		FillPropertyValues(ContactInformation, ContactInformationRow);
		ContactInformationList.Add(ContactInformation);
	EndDo;
	
	AdditionalParameters = AfterCloseHistoryFormAdditionalParameters(Form, ContactInformationParameters, AsynchronousCall);
	
	FormParameters = New Structure("ContactInformationList", ContactInformationList);
	FormParameters.Insert("ContactInformationKind", ContactInformationParameters.Kind);
	FormParameters.Insert("ReadOnly", Form.ReadOnly);
	
	ClosingNotification = New NotifyDescription("AfterClosingHistoryForm", ContactsManagerClient, AdditionalParameters);
	
	OpenForm("DataProcessor.ContactInformationInput.Form.ContactInformationHistory", FormParameters, Form,,,, ClosingNotification);
	
EndProcedure

// Synchronous handlers.

// Handler of the StartChoice event of the contact information form field.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form                - ClientApplicationForm - a form of a contact information owner.
//     Item              - FormField        - a form item containing contact information presentation.
//     Modified   - Boolean           - a flag indicating that the form was modified.
//     StandardProcessing - Boolean           - a flag indicating that standard processing is required for the form event.
//     OpeningParameters    - Structure        - opening parameters of the contact information input form.
//
Procedure StartChoice(Form, Item, Modified = True, StandardProcessing = False, OpeningParameters = Undefined) Export
	OnStartChoice(Form, Item, Modified, StandardProcessing, OpeningParameters, False);
EndProcedure

// Handler of the Clearing event for a contact information form field.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form        - ClientApplicationForm - a form of a contact information owner.
//     AttributeName - String           - a name of a form attribute related to contact information presentation.
//
Procedure Clearing(Val Form, Val AttributeName) Export
	OnClear(Form, AttributeName, False);
EndProcedure

// Handler of the command related to contact information (write an email, open an address, and so on).
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form      - ClientApplicationForm - a form of a contact information owner.
//     CommandName - String           - a name of the automatically generated action command.
//
Procedure ExecuteCommand(Val Form, Val CommandName) Export
	OnExecuteCommand(Form, CommandName, False);
EndProcedure

// Handler of the OnChange event of the contact information form field.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form             - ClientApplicationForm - a form of a contact information owner.
//     Item           - FormField        - a form item containing contact information presentation.
//     IsTabularSection - Boolean           - a flag specifying that the item is part of a form table.
//
Procedure OnChange(Form, Item, IsTabularSection = False) Export
	
	OnContactInformationChange(Form, Item, IsTabularSection, True, False);
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Use AddressAutoComplete instead.
// Handler of the AutoComplete event of the contact information form field.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Text                - String         - a text string entered by the user in the contact information field.
//     ChoiceData         - ValueList - contains a value list that will be used for standard
//                                             event processing.
//     StandardProcessing - Boolean         - this parameter stores the flag of whether the standard
//                                             (system) event processing is executed. If this parameter is
//                                             set to False in the processing procedure, standard processing
//                                             is skipped.
//
Procedure AutoComplete(Val Text, ChoiceData, StandardProcessing = False) Export
	
	If StrLen(Text) > 2 Then
		AutoCompleteAddress(Undefined, Text, ChoiceData, Undefined, 0, StandardProcessing);
	EndIf;
	
EndProcedure

// Deprecated. Obsolete. Use OnChange instead.
//
// Parameters:
//     Form             - ClientApplicationForm - a form of a contact information owner.
//     Item           - FormField        - a form item containing contact information presentation.
//     IsTabularSection - Boolean           - a flag specifying that the item is part of a form table.
//
Procedure PresentationOnChange(Form, Item, IsTabularSection = False) Export
	OnChange(Form, Item, IsTabularSection);
EndProcedure

// Deprecated. Obsolete. Use StartChoice instead.
//
// Parameters:
//     Form                - ClientApplicationForm - a form of a contact information owner.
//     Item              - FormField        - a form item containing contact information presentation.
//     Modified   - Boolean           - a flag indicating that the form was modified.
//     StandardProcessing - Boolean           - a flag indicating that standard processing is required for the form event.
//
// Returns:
//  Undefined - not used, backward compatibility.
//
Function PresentationStartChoice(Form, Item, Modified = True, StandardProcessing = False) Export
	StartChoice(Form, Item, Modified, StandardProcessing);
	Return Undefined;
EndFunction

// Deprecated. Obsolete. Use Clearing instead.
//
// Parameters:
//     Form        - ClientApplicationForm - a form of a contact information owner.
//     AttributeName - String           - a name of a form attribute related to contact information presentation.
//
// Returns:
//  Undefined - not used, backward compatibility.
//
Function ClearingPresentation(Form, AttributeName) Export
	Clearing(Form, AttributeName);
	Return Undefined;
EndFunction

// Deprecated. Obsolete. Use ExecuteCommand instead.
//
// Parameters:
//     Form      - ClientApplicationForm - a form of a contact information owner.
//     CommandName - String           - a name of the automatically generated action command.
//
// Returns:
//  Undefined - not used, backward compatibility.
//
Function AttachableCommand(Form, CommandName) Export
	ExecuteCommand(Form, CommandName);
	Return Undefined;
EndFunction

#EndRegion

#EndRegion

#Region Internal

// Complete nonmodal dialogs.

// The handler after closing the history form 
// 
// Parameters:
//   Result - Structure
//   AdditionalParameters - See AfterCloseHistoryFormAdditionalParameters
//
Procedure AfterClosingHistoryForm(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	Form = AdditionalParameters.Form;
	
	Filter = New Structure("Kind", AdditionalParameters.Kind);
	FoundRows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).FindRows(Filter);
	
	OldComment = Undefined;
	For Each ContactInformationRow In FoundRows Do
		If Not ContactInformationRow.IsHistoricalContactInformation Then
			OldComment = ContactInformationRow.Comment;
		EndIf;
		ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).Delete(ContactInformationRow);
	EndDo;
	
	ParametersOfUpdate = New Structure;
	For Each ContactInformationRow In Result.History Do
		RowData = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).Add();
		FillPropertyValues(RowData, ContactInformationRow);
		If Not ContactInformationRow.IsHistoricalContactInformation Then
			If IsBlankString(ContactInformationRow.Presentation)
				And Result.Property("EditingOption")
				And Result.EditingOption = "Dialog" Then
					Presentation = ContactsManagerClientServer.BlankAddressTextAsHyperlink();
			Else
				Presentation = ContactInformationRow.Presentation;
			EndIf;
			Form[AdditionalParameters.TagName] = Presentation;
			RowData.AttributeName = AdditionalParameters.TagName;
			RowData.ItemForPlacementName = AdditionalParameters.ItemForPlacementName;
			If RowData.Comment <> OldComment Then
				ParametersOfUpdate.Insert("IsCommentAddition", True);
				ParametersOfUpdate.Insert("ItemForPlacementName", AdditionalParameters.ItemForPlacementName);
				ParametersOfUpdate.Insert("AttributeName", AdditionalParameters.TagName);
				ParametersOfUpdate.Insert("ContactInformationType", ContactInformationRow.Type);
			EndIf;
		EndIf;
	EndDo;
	
	Form.Modified = True;
	If ValueIsFilled(ParametersOfUpdate) Then
		UpdateFormContactInformation(Form, ParametersOfUpdate, AdditionalParameters.AsynchronousCall);
	EndIf;
EndProcedure

// A handler of closing a list form of the "ContactInformationKinds" catalog with the applied contact information owner filter.
// 
// Parameters:
//   Result - Structure
//             - Undefined
//   AdditionalParameters - Structure:
//     * Form                    - ClientApplicationForm
//     * ItemForPlacementName - String
//     * AsynchronousCall         - Boolean
//
Procedure AfterCloseListFormContactInfoKinds(Result, AdditionalParameters) Export

	Form = AdditionalParameters.Form;
	ParametersOfUpdate = New Structure;
	ParametersOfUpdate.Insert("Reread", True);
	ParametersOfUpdate.Insert("ItemForPlacementName", AdditionalParameters.ItemForPlacementName);
	UpdateFormContactInformation(Form, ParametersOfUpdate, AdditionalParameters.AsynchronousCall);
	
EndProcedure

// Continues the call of PresentationStartChoice 
// 
// Parameters:
//   ClosingResult - Structure
//   AdditionalParameters - See PresentationStartChoiceCompletionAdditionalParameters
// 
Procedure PresentationStartChoiceCompletion(Val ClosingResult, Val AdditionalParameters) Export
	
	If TypeOf(ClosingResult) <> Type("Structure") Then
		If AdditionalParameters.Property("UpdateConextMenu") 
			And AdditionalParameters.UpdateConextMenu Then
				Result = New Structure();
				Result.Insert("UpdateConextMenu",  True);
				Result.Insert("ItemForPlacementName", AdditionalParameters.PlacementItemName);
				UpdateFormContactInformation(AdditionalParameters.Form, Result, AdditionalParameters.AsynchronousCall);
		EndIf;
		Return;
	EndIf;
	
	FillingData = AdditionalParameters.FillingData;
	DataOnForm    = AdditionalParameters.RowData;
	Result        = AdditionalParameters.Result;
	Item          = AdditionalParameters.Item;
	Form            = AdditionalParameters.Form;
	
	PresentationText = ClosingResult.Presentation;
	Comment        = ClosingResult.Comment;
	
	If DataOnForm.Property("StoreChangeHistory") And DataOnForm.StoreChangeHistory Then
		ContactInformationAdditionalAttributesDetails = FillingData.ContactInformationAdditionalAttributesDetails;
		Filter = New Structure("Kind", DataOnForm.Kind);
		FoundRows = ContactInformationAdditionalAttributesDetails.FindRows(Filter);
		For Each ContactInformationRow In FoundRows Do
			ContactInformationAdditionalAttributesDetails.Delete(ContactInformationRow);
		EndDo;
		
		Filter = New Structure("Kind", DataOnForm.Kind);
		FoundRows = ClosingResult.ContactInformationAdditionalAttributesDetails.FindRows(Filter);
		
		If FoundRows.Count() > 1 Then
			
			RowWithValidAddress = Undefined;
			MinDate = Undefined;
			
			For Each ContactInformationRow In FoundRows Do
				
				NewContactInformation = ContactInformationAdditionalAttributesDetails.Add();
				FillPropertyValues(NewContactInformation, ContactInformationRow);
				NewContactInformation.ItemForPlacementName = AdditionalParameters.PlacementItemName;
				
				If RowWithValidAddress = Undefined
					Or ContactInformationRow.ValidFrom > RowWithValidAddress.ValidFrom Then
						RowWithValidAddress = ContactInformationRow;
				EndIf;
				If MinDate = Undefined
					Or ContactInformationRow.ValidFrom < MinDate Then
						MinDate = ContactInformationRow.ValidFrom;
				EndIf;
				
			EndDo;
			
			// Correcting invalid addresses without the original fill date
			If ValueIsFilled(MinDate) Then
				Filter = New Structure("ValidFrom", MinDate);
				RowsWithMinDate = ContactInformationAdditionalAttributesDetails.FindRows(Filter);
				If RowsWithMinDate.Count() > 0 Then
					RowsWithMinDate[0].ValidFrom = Date(1, 1, 1);
				EndIf;
			EndIf;
			
			If RowWithValidAddress <> Undefined Then
				PresentationText = RowWithValidAddress.Presentation;
				Comment        = RowWithValidAddress.Comment;
			EndIf;
			
		ElsIf FoundRows.Count() = 1 Then
			NewContactInformation = ContactInformationAdditionalAttributesDetails.Add();
			FillPropertyValues(NewContactInformation, FoundRows[0],, "ValidFrom");
			NewContactInformation.ItemForPlacementName = AdditionalParameters.PlacementItemName;
			DataOnForm.ValidFrom = Date(1, 1, 1);
		EndIf;
		
	EndIf;
	
	If AdditionalParameters.IsTabularSection Then
		FillingData[Item.Name + "Value"]      = ClosingResult.Value;	
	Else
		AttributeNameComment = "Comment" + Item.Name;
		If Form.Items.Find(AttributeNameComment) <> Undefined Then
			Form[AttributeNameComment] = Comment;
		Else
			FormItemPresentation = Form.Items.Find(Item.Name); // FormDecoration
			If ClosingResult.Type = PredefinedValue("Enum.ContactInformationTypes.Address")
				And ClosingResult.AsHyperlink Then
				ContactInfoParameters = Form.ContactInformationParameters[AdditionalParameters.PlacementItemName];
				StoreChangeHistory = ?(DataOnForm.Property("StoreChangeHistory"), DataOnForm.StoreChangeHistory, False);
				CommandsForOutput = ContactsManagerClientServer.CommandsToOutputToForm(ContactInfoParameters,
					ClosingResult.Type, ClosingResult.Kind, StoreChangeHistory);
				FormItemPresentation.ExtendedTooltip.Title = ContactsManagerClientServer.ExtendedTooltipForAddress(
					CommandsForOutput, DataOnForm.Presentation, Comment);
			Else
				FormItemPresentation.ExtendedTooltip.Title = Comment;
			EndIf;
		EndIf;
		
		If ClosingResult.Type = PredefinedValue("Enum.ContactInformationTypes.WebPage") Then
			PresentationText = ContactsManagerClientServer.WebsiteAddress(PresentationText, ClosingResult.Address, Form.ReadOnly);
		EndIf;
		
		DataOnForm.Presentation = PresentationText;
		DataOnForm.Value      = ClosingResult.Value;
		DataOnForm.Comment   = Comment;
	EndIf;
	
	If ClosingResult.Property("AsHyperlink")
		And ClosingResult.AsHyperlink
		And Not ValueIsFilled(PresentationText) Then
			FillingData[Item.Name] = ContactsManagerClientServer.BlankAddressTextAsHyperlink();
	Else
		FillingData[Item.Name] = PresentationText;
	EndIf;
	
	If ClosingResult.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Result.Insert("UpdateConextMenu", True);
	EndIf;
	
	Form.Modified = True;
	UpdateFormContactInformation(Form, Result, AdditionalParameters.AsynchronousCall);
EndProcedure

Procedure ContactInformationAddInputFieldCompletion(Val SelectedElement, Val AdditionalParameters) Export
	If SelectedElement = Undefined Then
		// Cancel selection.
		Return;
	EndIf;
	
	If Not ValueIsFilled(SelectedElement.Value.Ref) Then
		Form = AdditionalParameters.Form;
		ItemForPlacementName = AdditionalParameters.ItemForPlacementName;
		ContactInfoParameters = Form.ContactInformationParameters[ItemForPlacementName];
		FormOpenParameters = New Structure;
		FormOpenParameters.Insert("ContactInformationOwner", ContactInfoParameters.Owner);
		FormClosingParameters = New Structure;
		FormClosingParameters.Insert("Form",  AdditionalParameters.Form);
		FormClosingParameters.Insert("ItemForPlacementName", ItemForPlacementName);
		FormClosingParameters.Insert("AsynchronousCall", AdditionalParameters.AsynchronousCall);	
		Notification = New NotifyDescription("AfterCloseListFormContactInfoKinds", 
			ContactsManagerClient, FormClosingParameters);
		OpenForm("Catalog.ContactInformationKinds.Form.ListForm",FormOpenParameters,
			AdditionalParameters.Form,,,,Notification,FormWindowOpeningMode.LockOwnerWindow);
		Return;
	EndIf;
	
	Result = New Structure();
	Result.Insert("KindToAdd", SelectedElement.Value);
	Result.Insert("ItemForPlacementName", AdditionalParameters.ItemForPlacementName);
	Result.Insert("CommandName", AdditionalParameters.CommandName);
	If SelectedElement.Value.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Result.Insert("UpdateConextMenu", True);
	EndIf;
	
	If Not SelectedElement.Value.AllowMultipleValueInput Then
		AdditionalParameters.Form.ContactInformationParameters[Result.ItemForPlacementName].ItemsToAddList.Delete(SelectedElement);
	EndIf;
	
	UpdateFormContactInformation(AdditionalParameters.Form, Result, AdditionalParameters.AsynchronousCall);
EndProcedure

Procedure AfterStartApplication(ApplicationStarted, Parameters) Export
	
	If Not ApplicationStarted Then 
		StringWithWarning = New FormattedString(
			NStr("en = 'To make a call, install a telecom app. For example,';"),
			 " ", New FormattedString("Skype",,,, "http://www.skype.com"), ".");
		ShowMessageBox(Undefined, StringWithWarning);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Event handlers.

Procedure OnStartChoice(Form, Item, Modified, StandardProcessing, OpeningParameters, AsynchronousCall)
	
	StandardProcessing = False;
	
	Result = New Structure;
	Result.Insert("AttributeName", Item.Name);
	
	IsTabularSection = IsTabularSection(Item);
	
	If IsTabularSection Then
		FillingData = Form.Items[Form.CurrentItem.Name].CurrentData;
		If FillingData = Undefined Then
			Return;
		EndIf;
	Else
		FillingData = Form;
	EndIf;
	
	RowData = GetAdditionalValueString(Form, Item, IsTabularSection);
	
	// Setting presentation equal to the attribute if the presentation was modified directly in the form field and no longer matches the attribute.
	UpdateConextMenu = False;
	If Item.Type = FormFieldType.InputField Then
		If FillingData[Item.Name] <> Item.EditText Then
			FillingData[Item.Name] = Item.EditText;
			OnContactInformationChange(Form, Item, IsTabularSection, False, AsynchronousCall);
			UpdateConextMenu  = True;
			Form.Modified = True;
		EndIf;
		EditText = Item.EditText;
	Else
		If RowData <> Undefined And ValueIsFilled(RowData.Value) Then
			EditText = Form[Item.Name];
		Else
			EditText = "";
		EndIf;
	EndIf;
	
	ContactInformationParameters = Form.ContactInformationParameters[RowData.ItemForPlacementName];
	
	FormOpenParameters = New Structure;
	FormOpenParameters.Insert("ContactInformationKind", RowData.Kind);
	FormOpenParameters.Insert("Value",                RowData.Value);
	FormOpenParameters.Insert("Presentation",           EditText);
	FormOpenParameters.Insert("ReadOnly",          Form.ReadOnly Or Item.ReadOnly);
	FormOpenParameters.Insert("PremiseType",            ContactInformationParameters.AddressParameters.PremiseType);
	FormOpenParameters.Insert("Country",                  ContactInformationParameters.AddressParameters.Country);
	FormOpenParameters.Insert("IndexOf",                  ContactInformationParameters.AddressParameters.IndexOf);
	FormOpenParameters.Insert("ContactInformationAdditionalAttributesDetails", 
		ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form));
	
	If Not IsTabularSection Then
		FormOpenParameters.Insert("Comment", RowData.Comment);
	EndIf;
	
	If ValueIsFilled(OpeningParameters) And TypeOf(OpeningParameters) = Type("Structure") Then
		For Each ValueAndKey In OpeningParameters Do
			FormOpenParameters.Insert(ValueAndKey.Key, ValueAndKey.Value);
		EndDo;
	EndIf;
	
	AdditionalParameters = PresentationStartChoiceCompletionAdditionalParameters();
	AdditionalParameters.FillingData = FillingData;
	AdditionalParameters.IsTabularSection = IsTabularSection;
	AdditionalParameters.PlacementItemName = RowData.ItemForPlacementName;
	AdditionalParameters.RowData = RowData;
	AdditionalParameters.Item = Item;
	AdditionalParameters.Result = Result;
	AdditionalParameters.Form = Form;
	AdditionalParameters.UpdateConextMenu = UpdateConextMenu;
	AdditionalParameters.AsynchronousCall = AsynchronousCall;
	
	Notification = New NotifyDescription("PresentationStartChoiceCompletion", ThisObject, AdditionalParameters);
	
	OpenContactInformationForm(FormOpenParameters,, Notification);
	
EndProcedure

Procedure OnClear(Val Form, Val AttributeName, AsynchronousCall)
	
	Result = New Structure("AttributeName", AttributeName);
	FoundRows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(
		Form).FindRows(Result);
	If FoundRows.Count() = 0 Then
		Return;
	EndIf;
	FoundRow = FoundRows[0];
	FoundRow.Value      = "";
	FoundRow.Presentation = "";
	FoundRow.Comment   = "";
	
	Form[AttributeName] = "";
	Form.Modified = True;
		
	If FoundRow.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Result.Insert("UpdateConextMenu", True);
		Result.Insert("ItemForPlacementName", FoundRow.ItemForPlacementName);
	EndIf;
	
	If ValueIsFilled(FoundRow.Mask) Then
		FormItems = Form.Items[AttributeName]; // TextBox
		If FormItems.Type = FormFieldType.InputField Then
			FormItems.Mask = FoundRow.Mask;
		EndIf;
	EndIf;
	
	UpdateFormContactInformation(Form, Result, AsynchronousCall);
	
EndProcedure

Procedure OnExecuteCommand(Val Form, Val CommandName, AsynchronousCall)

	If StrStartsWith(CommandName, "ContactInformationAddInputField") Then

		AdditionalParameters = New Structure;

		ItemForPlacementName = Mid(CommandName, StrLen("ContactInformationAddInputField") + 1);
		AdditionalParameters.Insert("AsynchronousCall", AsynchronousCall);
		AdditionalParameters.Insert("Form", Form);
		AdditionalParameters.Insert("ItemForPlacementName", ItemForPlacementName);
		AdditionalParameters.Insert("CommandName", CommandName);
		Notification = New NotifyDescription("ContactInformationAddInputFieldCompletion", ThisObject,
			AdditionalParameters);
		Form.ShowChooseFromMenu(Notification,
			Form.ContactInformationParameters[ItemForPlacementName].ItemsToAddList,
			Form.Items[CommandName]);

		Return;

	ElsIf StrStartsWith(CommandName, "Command") Then

		AttributeName = DeleteStringPrefix(CommandName, "Command");
		ContextMenuCommand = Undefined;
		
	ElsIf StrStartsWith(CommandName, "MenuSubmenuAddress") Then
		
		AttributeName         = DeleteStringPrefix(CommandName, "MenuSubmenuAddress");
		Position              = StrFind(AttributeName, "_ContactInformationField");
		AttributeNameSource = Left(AttributeName, Position -1);
		AttributeName         = Mid(AttributeName, Position + 1);
		ContextMenuCommand = Undefined;
		
	Else

		ContextMenuCommand = ContextMenuCommand(CommandName);
		AttributeName = ContextMenuCommand.AttributeName;

	EndIf;

	Result = New Structure("AttributeName", AttributeName);
	FoundRows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(
		Form).FindRows(Result);
	If FoundRows.Count() = 0 Then
		Return;
	EndIf;

	FoundRow          = FoundRows[0];
	ContactInformationType  = FoundRow.Type;
	ItemForPlacementName = FoundRow.ItemForPlacementName;
	Result.Insert("ItemForPlacementName", ItemForPlacementName);
	Result.Insert("ContactInformationType", FoundRow.Type);
	
	If ContextMenuCommand <> Undefined Then	
		TheFirstControl = FoundRow.AttributeName;
		DescriptionOfTheContactInformationOnTheForm = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(
				Form);
		IndexOf = DescriptionOfTheContactInformationOnTheForm.IndexOf(FoundRow);
		If ContextMenuCommand.MovementDirection = 1 Then
			If IndexOf < DescriptionOfTheContactInformationOnTheForm.Count() - 1 Then
				TheSecondControl = DescriptionOfTheContactInformationOnTheForm.Get(IndexOf + 1).AttributeName;
			EndIf;
		Else
			If IndexOf > 0 Then
				TheSecondControl = DescriptionOfTheContactInformationOnTheForm.Get(IndexOf - 1).AttributeName;
			EndIf;
		EndIf;
		Result = New Structure;
		Result.Insert("ReorderItems", True); 
		Result.Insert("TheFirstControl", TheFirstControl); 
		Result.Insert("TheSecondControl", TheSecondControl); 
		Result.Insert("ItemForPlacementName", ItemForPlacementName); 	
		Form.CurrentItem = Form.Items[TheSecondControl];
		UpdateFormContactInformation(Form, Result, AsynchronousCall);
		
	ElsIf StrStartsWith(CommandName, "MenuSubmenuAddress") And ContactInformationType = PredefinedValue(
		"Enum.ContactInformationTypes.Address") Then

		Result = New Structure("AttributeName", AttributeNameSource);	
		FoundRows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(
			Form).FindRows(Result);
		If FoundRows.Count() = 0 Then
			Return;
		EndIf;
	
		ConsumerRow = FoundRows[0];
		Comment = ConsumerRow.Comment; // Save the old comment.
		If ConsumerRow.Property("InternationalAddressFormat") And ConsumerRow.InternationalAddressFormat Then

			FillPropertyValues(ConsumerRow, FoundRow, "Comment");
			AddressPresentation = StringFunctionsClient.LatinString(FoundRow.Presentation);
			ConsumerRow.Presentation        = AddressPresentation;
			Form[ConsumerRow.AttributeName]  = AddressPresentation;
			ConsumerRow.Value = ContactsManagerInternalServerCall.ContactsByPresentation(
				AddressPresentation, ContactInformationType, Comment);

		Else

			FillPropertyValues(ConsumerRow, FoundRow, "Value, Presentation,Comment");
			Form[ConsumerRow.AttributeName] = FoundRow.Presentation;

		EndIf;

		Form.Modified = True;
		Result = New Structure;
		Result.Insert("UpdateConextMenu", True);
		Result.Insert("AttributeName", ConsumerRow.AttributeName);
		Result.Insert("Comment", Comment);
		Result.Insert("ItemForPlacementName", FoundRow.ItemForPlacementName);
		UpdateFormContactInformation(Form, Result, AsynchronousCall);
		
	Else
		ContactInfoParameters = Form.ContactInformationParameters[ItemForPlacementName];
		OwnerOfTheKey = ContactInfoParameters.Owner;
	
		CommandsForOutput = ContactsManagerClientServer.CommandsToOutputToForm(ContactInfoParameters,
			ContactInformationType, FoundRow.Kind, FoundRow.StoreChangeHistory);

		CommandsCount = CommandsForOutput.Count();

		If CommandsCount = 0 Then
			Return;
		EndIf;

		ContactInformation = ParameterContactInfoForCommandExecution(FoundRow.Presentation, 
			FoundRow.Value, FoundRow.Type, FoundRow.Kind);
		AdditionalParameters = CommandRuntimeAdditionalParameters(OwnerOfTheKey, Form, FoundRow.AttributeName, AsynchronousCall);
		Parameters = New Structure("ContactInformation, AdditionalParameters", ContactInformation, AdditionalParameters);

		If CommandsCount = 1 Then

			For Each Command In CommandsForOutput Do
				RunContactInfoCommand(Command.Value.Action, Parameters);
			EndDo;

		ElsIf CommandsCount > 1 Then
			List = New ValueList;
			For Each Command In CommandsForOutput Do
				List.Add(Command.Value.Action, Command.Value.Title, , Command.Value.Picture);
			EndDo;

			NotificationMenu = New NotifyDescription("AfterMenuItemSelected", ThisObject, Parameters);
			Form.ShowChooseFromMenu(NotificationMenu, List, Form.Items[CommandName]);
		EndIf;
	EndIf;

EndProcedure

Procedure OnURLProcessing(Form, Item, FormattedStringURL, StandardProcessing, AsynchronousCall)
	
	StandardProcessing = False;
	
	If StrEndsWith(Item.Name, "ExtendedTooltip") Then
		CommandName = FormattedStringURL;
		AttributeName = DeleteStringPostfix(Item.Name, "ExtendedTooltip");
		BeforeRunCommandFromAddressExtendedTooltip(Form, Item, AttributeName, CommandName, AsynchronousCall);
		Return;
	EndIf;
	
	HyperlinkAddress = Form[Item.Name];
	If FormattedStringURL = ContactsManagerClientServer.WebsiteURL() 
		Or TrimAll(String(HyperlinkAddress)) = ContactsManagerClientServer.BlankAddressTextAsHyperlink() Then
		
		StandardChoiceProcessing = True;
		
		If AsynchronousCall Then
			StartSelection(Form, Item, True, StandardChoiceProcessing);
		Else
			StartChoice(Form, Item, True, StandardChoiceProcessing);
		EndIf;
		
	Else
		GoToWebLink("", FormattedStringURL);
	EndIf;
	
EndProcedure

// Miscellaneous.

// Processes entering a comment using the context menu.
Procedure EnterAComment(Val Form, Val AttributeName, Val FoundRow, Val Result, AsynchronousCall)
	Comment = FoundRow.Comment;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Form", Form);
	AdditionalParameters.Insert("CommentAttributeName", "Comment" + AttributeName);
	AdditionalParameters.Insert("FoundRow", FoundRow);
	AdditionalParameters.Insert("PreviousComment", Comment);
	AdditionalParameters.Insert("Result", Result);
	AdditionalParameters.Insert("ItemForPlacementName", FoundRow.ItemForPlacementName);
	AdditionalParameters.Insert("AsynchronousCall", AsynchronousCall);
	
	Notification = New NotifyDescription("EnterACommentCompletion", ThisObject, AdditionalParameters);
	
	CommonClient.ShowMultilineTextEditingForm(Notification, Comment,
		NStr("en = 'Comment';"));
EndProcedure

// Completes a nonmodal dialog.
Procedure EnterACommentCompletion(Val Comment, Val AdditionalParameters) Export
	If Comment = Undefined Or Comment = AdditionalParameters.PreviousComment Then
		// Canceling entry or no changes.
		Return;
	EndIf;
	
	CommentWasEmpty  = IsBlankString(AdditionalParameters.PreviousComment);
	CommentBecameEmpty = IsBlankString(Comment);
	
	AdditionalParameters.FoundRow.Comment = Comment;
	
	If CommentWasEmpty And Not CommentBecameEmpty Then
		AdditionalParameters.Result.Insert("IsCommentAddition", True);
	ElsIf Not CommentWasEmpty And CommentBecameEmpty Then
		AdditionalParameters.Result.Insert("IsCommentAddition", False);
	Else
		If AdditionalParameters.Form.Items.Find(AdditionalParameters.CommentAttributeName) <> Undefined Then
			Item = AdditionalParameters.Form.Items[AdditionalParameters.CommentAttributeName]; // FormItemAddition
			Item.Title = Comment;
		Else
			AdditionalParameters.Result.Insert("IsCommentAddition", True);
		EndIf;
	EndIf;
	
	AdditionalParameters.Form.Modified = True;
	UpdateFormContactInformation(AdditionalParameters.Form, AdditionalParameters.Result, AdditionalParameters.AsynchronousCall)
	
EndProcedure

Procedure OnContactInformationChange(Form, Item, IsTabularSection, UpdateForm, AsynchronousCall)
	
	Prefix = "Comment";
	If StrStartsWith(Item.Name, Prefix) Then
		AttributeName = DeleteStringPrefix(Item.Name, Prefix);
		Result = New Structure;
		Result.Insert("AttributeName", AttributeName);
		FoundRows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).FindRows(Result);
		If FoundRows.Count() = 0 Then
			Return;
		EndIf;
		FoundRow             = FoundRows[0];
		ItemForPlacementName    = FoundRow.ItemForPlacementName;
		FoundRow.Comment = Item.EditText;
		Result.Insert("ItemForPlacementName", ItemForPlacementName);
		Result.Insert("ContactInformationType", FoundRow.Type);
		Result.Insert("IsCommentAddition", True);
		UpdateFormContactInformation(Form, Result, AsynchronousCall);
		Return;
	EndIf;
	
	IsTabularSection = IsTabularSection(Item);
	
	If IsTabularSection Then
		FillingData = Form.Items[Form.CurrentItem.Name].CurrentData;
		If FillingData = Undefined Then
			Return;
		EndIf;
	Else
		FillingData = Form;
	EndIf;
	
	// Clearing presentation if clearing is required.
	RowData = GetAdditionalValueString(Form, Item, IsTabularSection);
	If RowData = Undefined Then 
		Return;
	EndIf;
	
	Text = Item.EditText;
	If IsBlankString(Text) Then
		
		FillingData[Item.Name] = "";
		If IsTabularSection Then
			FillingData[Item.Name + "Value"] = "";
		EndIf;
		RowData.Presentation = "";
		RowData.Value      = "";
		Result = New Structure("UpdateConextMenu, ItemForPlacementName", True, RowData.ItemForPlacementName);
		If UpdateForm Then
			UpdateConextMenu(Form, RowData.ItemForPlacementName);
		EndIf;      
		If ValueIsFilled(RowData.Mask) And Item.Type = FormFieldType.InputField Then
			Item.Mask = RowData.Mask;  
		EndIf;	
		Return;
		
	EndIf;
	
	If RowData.Property("StoreChangeHistory")
		And RowData.StoreChangeHistory
		And BegOfDay(RowData.ValidFrom) <> BegOfDay(CommonClient.SessionDate()) Then
		ContactInformationAdditionalAttributesDetails = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form);
		HistoricalContactInformation = ContactInformationAdditionalAttributesDetails.Add();
		FillPropertyValues(HistoricalContactInformation, RowData);
		HistoricalContactInformation.IsHistoricalContactInformation = True;
		HistoricalContactInformation.AttributeName = "";
		RowData.ValidFrom = BegOfDay(CommonClient.SessionDate());
	EndIf;
	
	RowData.Value = ContactsManagerInternalServerCall.ContactsByPresentation(Text, RowData.Kind, RowData.Comment);
	RowData.Presentation = Text;
	
	If IsTabularSection Then
		FillingData[Item.Name + "Value"]      = RowData.Value;
	EndIf;
	
	If RowData.Type = PredefinedValue("Enum.ContactInformationTypes.Address") And UpdateForm Then
		Result = New Structure("UpdateConextMenu, ItemForPlacementName", True, RowData.ItemForPlacementName);
		UpdateFormContactInformation(Form, Result, AsynchronousCall)
	EndIf;

EndProcedure

// Context call
Procedure UpdateFormContactInformation(Form, Result, AsynchronousCall)
	
	If AsynchronousCall Then
		Notification = New NotifyDescription("Attachable_ContinueContactInformationUpdate", Form);
		ExecuteNotifyProcessing(Notification, Result);
	Else
		Form.Attachable_UpdateContactInformation(Result);
	EndIf;
	
EndProcedure

// Returns a string of additional values by attribute name.
//
// Parameters:
//    Form   - ClientApplicationForm - a form to be passed.
//    Item - FormDataStructureAndCollection - form data.
//
// Returns:
//    See ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm
//    Undefined    - if no data is available.
//
Function GetAdditionalValueString(Form, Item, IsTabularSection = False)
	
	Filter = New Structure("AttributeName", Item.Name);
	Rows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form).FindRows(Filter);
	RowData = ?(Rows.Count() = 0, Undefined, Rows[0]);
	
	If IsTabularSection And RowData <> Undefined Then
		
		RowPath = Form.Items[Form.CurrentItem.Name].CurrentData;
		
		RowData.Presentation = RowPath[Item.Name];
		RowData.Value      = RowPath[Item.Name + "Value"];
		
	EndIf;
	
	Return RowData;
	
EndFunction

Function IsTabularSection(Item)
	
	Parent = Item.Parent;
	
	While TypeOf(Parent) <> Type("ClientApplicationForm") Do
		
		If TypeOf(Parent) = Type("FormTable") Then
			Return True;
		EndIf;
		
		Parent = Parent.Parent;
		
	EndDo;
	
	Return False;
	
EndFunction

// determining a context menu command.
Function ContextMenuCommand(CommandName)
	
	Result = New Structure("Command, MovementDirection, AttributeName", Undefined, 0, Undefined);
	
	AttributeName = ?(StrStartsWith(CommandName, "ContextMenuSubmenu"),
		StrReplace(CommandName, "ContextMenuSubmenu", ""), StrReplace(CommandName, "ContextMenu", ""));
		
	If StrStartsWith(AttributeName, "Up") Then
		Result.AttributeName = StrReplace(AttributeName, "Up", "");
		Result.MovementDirection = -1;
		Result.Command = "Up";
	ElsIf StrStartsWith(AttributeName, "Down") Then
		Result.AttributeName = StrReplace(AttributeName, "Down", "");
		Result.MovementDirection = 1;
		Result.Command = "Down";
	EndIf;
	
	Return Result;
	
EndFunction

// Checks whether the telephony application is installed on the computer.
//  Check is available only in thin client for Windows.
//
// Parameters:
//  ProtocolName - String - a name of an URI protocol to be checked. Available options are "skype", "tel", and "sip".
//                          If the parameter is not specified, all protocols are checked. 
// 
// Returns:
//  String - The name of the available URI protocol is saved to the register. If empty, the protocol is unavailable.
//    If "Undefined", the check cannot be run.
//
Function TelephonyApplicationInstalled(ProtocolName = Undefined)
	
	If CommonClient.IsWindowsClient() Then
		If ValueIsFilled(ProtocolName) Then
			Return ?(ProtocolNameRegisteredInRegistry(ProtocolName), ProtocolName, "");
		Else
			ProtocolList = New Array;
			ProtocolList.Add("tel");
			ProtocolList.Add("sip");
			ProtocolList.Add("skype");
			For Each ProtocolName In ProtocolList Do
				If ProtocolNameRegisteredInRegistry(ProtocolName) Then
					Return ProtocolName;
				EndIf;
			EndDo;
			Return Undefined;
		EndIf;
	EndIf;
	
	// Assume MacOS and Linux have a VoIP app.
	// Errors  will handled at the startup.
	Return ProtocolName;
EndFunction

Function ProtocolNameRegisteredInRegistry(ProtocolName)
	
#If MobileClient Then
	Return False;
#Else
	Try
		Shell = New COMObject("Wscript.Shell");
		Shell.RegRead("HKEY_CLASSES_ROOT\" + ProtocolName + "\");
	Except
		Return False;
	EndTry;
	Return True;
#EndIf

EndFunction

Procedure AfterMenuItemSelected(SelectedElement, Parameters) Export
	
	If SelectedElement <> Undefined Then
		RunContactInfoCommand(SelectedElement.Value, Parameters);
	EndIf;
	
EndProcedure

Procedure OpenSkype(CommandLine1)
	
#If Not WebClient Then
		If IsBlankString(TelephonyApplicationInstalled("skype")) Then
			ShowMessageBox(Undefined, NStr("en = 'Install Skype to make Skype calls.';"));
			Return;
		EndIf;
#EndIf
	
	Notification = New NotifyDescription("AfterStartApplication", ThisObject);
	FileSystemClient.OpenURL(CommandLine1, Notification);
	
EndProcedure

// Constructor of additional parameters for the history form
// 
// Parameters:
//   Form - ClientApplicationForm
//   ContactInformationParameters - Structure
//   AsynchronousCall - Boolean
// Returns:
//   Structure:
//   * Form - ClientApplicationForm
//   * AsynchronousCall - Boolean
//   * ItemForPlacementName - String
//   * Kind - CatalogRef.ContactInformationKinds
//   * TagName - String
//
Function AfterCloseHistoryFormAdditionalParameters(Val Form, ContactInformationParameters, Val AsynchronousCall)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Form", Form);
	AdditionalParameters.Insert("TagName", ContactInformationParameters.AttributeName);
	AdditionalParameters.Insert("Kind", ContactInformationParameters.Kind);
	AdditionalParameters.Insert("ItemForPlacementName", ContactInformationParameters.ItemForPlacementName);
	AdditionalParameters.Insert("AsynchronousCall", AsynchronousCall);

	
	Return AdditionalParameters;
	
EndFunction

// Returns:
//   Structure:
//   * AsynchronousCall - Boolean
//   * UpdateConextMenu - Boolean
//   * Form - Undefined
//   * Result - Undefined
//   * Item - FormDecoration
//             - FormGroup
//             - FormButton
//             - FormTable
//             - FormField
//   * RowData - Undefined
//                  - FormDataCollectionItem of See ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm
//   * PlacementItemName - String
//   * IsTabularSection - Boolean
//   * FillingData - String
//
Function PresentationStartChoiceCompletionAdditionalParameters()

	AdditionalParameters = New Structure;
	
	AdditionalParameters.Insert("FillingData",        "");
	AdditionalParameters.Insert("IsTabularSection",       False);
	AdditionalParameters.Insert("PlacementItemName",   "");
	AdditionalParameters.Insert("RowData",            Undefined);
	AdditionalParameters.Insert("Item",                 Undefined);
	AdditionalParameters.Insert("Result",               Undefined);
	AdditionalParameters.Insert("Form",                   Undefined);
	AdditionalParameters.Insert("UpdateConextMenu", False);
	AdditionalParameters.Insert("AsynchronousCall",        False);
	
	Return AdditionalParameters;
		
EndFunction 

////////////////////////////////////////////////////////////////////////////////
// Returns a string in which all special characters (except for the hyphen, underscore, and dot)
// are replaced with the percent sign ( % ) followed by 2 hexadecimal digits
// and whitespaces encoded as the plus sign.
// That is, the string is encoded as POST data in the content type "application/x-www-form-urlencoded."

Function StringDecoding(String)
	Result = "";
	For CharacterNumber = 1 To StrLen(String) Do
		CharCode = CharCode(String, CharacterNumber);
		Char = Mid(String, CharacterNumber, 1);
		
		// ignoring A...Z, a...z, 0...9
		If StrFind("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", Char) > 0 Then // Encode the following as safe characters: - _ . ! ~ *  ( )  
			Result = Result + Char;
			Continue;
		EndIf;
		
		If Char = " " Then
			Result = Result + "+";
			Continue;
		EndIf;
		
		If CharCode <= 127 Then // 0x007F
			Result = Result + BytePresentation(CharCode);
		ElsIf CharCode <= 2047 Then // 0x07FF 
			Result = Result 
					  + BytePresentation(
					  					   BinaryArrayToNumber(
																LogicalBitwiseOr(
																			 NumberToBinaryArray(192,8),
																			 NumberToBinaryArray(Int(CharCode / Pow(2,6)),8)))); // 0xc0 | (ch >> 6)
			Result = Result 
					  + BytePresentation(
					  					   BinaryArrayToNumber(
										   						LogicalBitwiseOr(
																			 NumberToBinaryArray(128,8),
																			 LogicalBitwiseAnd(
																			 			NumberToBinaryArray(CharCode,8),
																						NumberToBinaryArray(63,8)))));  //0x80 | (ch & 0x3F)
		Else  // 0x7FF < ch <= 0xFFFF
			Result = Result 
					  + BytePresentation	(
					  						 BinaryArrayToNumber(
																  LogicalBitwiseOr(
																			   NumberToBinaryArray(224,8), 
																			   NumberToBinaryArray(Int(CharCode / Pow(2,12)),8)))); // 0xe0 | (ch >> 12)
											
			Result = Result 
					  + BytePresentation(
					  					   BinaryArrayToNumber(
										   						LogicalBitwiseOr(
																			 NumberToBinaryArray(128,8),
																			 LogicalBitwiseAnd(
																			 			NumberToBinaryArray(Int(CharCode / Pow(2,6)),8),
																						NumberToBinaryArray(63,8)))));  //0x80 | ((ch >> 6) & 0x3F)
											
			Result = Result 
					  + BytePresentation(
					  					   BinaryArrayToNumber(
										   						LogicalBitwiseOr(
																			 NumberToBinaryArray(128,8),
																			 LogicalBitwiseAnd(
																			 			NumberToBinaryArray(CharCode,8),
																						NumberToBinaryArray(63,8)))));  //0x80 | (ch & 0x3F)
								
		EndIf;
	EndDo;
	Return Result;
EndFunction

Function BytePresentation(Val Byte)
	Result = "";
	CharacterString = "0123456789ABCDEF";
	For Counter = 1 To 2 Do
		Result = Mid(CharacterString, Byte % 16 + 1, 1) + Result;
		Byte = Int(Byte / 16);
	EndDo;
	Return "%" + Result;
EndFunction

Function NumberToBinaryArray(Val Number, Val TotalDigits = 32)
	Result = New Array;
	CurrentDigit = 0;
	While CurrentDigit < TotalDigits Do
		CurrentDigit = CurrentDigit + 1;
		Result.Add(Boolean(Number % 2));
		Number = Int(Number / 2);
	EndDo;
	Return Result;
EndFunction

Function BinaryArrayToNumber(Array)
	Result = 0;
	For DigitNumber = -(Array.Count()-1) To 0 Do
		Result = Result * 2 + Number(Array[-DigitNumber]);
	EndDo;
	Return Result;
EndFunction

Function LogicalBitwiseAnd(BinaryArray1, BinaryArray2)
	Result = New Array;
	For IndexOf = 0 To BinaryArray1.Count()-1 Do
		Result.Add(BinaryArray1[IndexOf] And BinaryArray2[IndexOf]);
	EndDo;
	Return Result;
EndFunction

Function LogicalBitwiseOr(BinaryArray1, BinaryArray2)
	Result = New Array;
	For IndexOf = 0 To BinaryArray1.Count()-1 Do
		Result.Add(BinaryArray1[IndexOf] Or BinaryArray2[IndexOf]);
	EndDo;
	Return Result;
EndFunction

Procedure UpdateConextMenu(Form, ItemForPlacementName)
	
	ContactInformationParameters = Form.ContactInformationParameters[ItemForPlacementName]; // FormDataCollection
	AllRows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(Form);
	FoundRows = AllRows.FindRows( 
		New Structure("Type, IsTabularSectionAttribute", PredefinedValue("Enum.ContactInformationTypes.Address"), False));
		
	TotalCommands = 0;
	For Each CIRow In AllRows Do
		
		If TotalCommands > 50 Then // Restriction for a large number of addresses on the form
			Break;
		EndIf;
		
		If CIRow.Type <> PredefinedValue("Enum.ContactInformationTypes.Address") Then
			Continue;
		EndIf;
		
		ContextSubmenuCopyAddresses = Form.Items.Find("ContextSubmenuCopyAddresses" + CIRow.AttributeName);
		If ContextSubmenuCopyAddresses = Undefined Then
			Continue;
		EndIf;
			
		CommandsCountInSubmenu = 0;
		AddressesListInSubmenu = New Map();
		AddressData = New Structure("Presentation, Address", CIRow.Presentation, CIRow.Value);
		AddressesListInSubmenu.Insert(Upper(CIRow.Presentation), AddressData);
		
		For Each Address In FoundRows Do
			
			If CommandsCountInSubmenu > 7 Then // Restriction for a large number of addresses on the form
				Break;
			EndIf;
			
			If Address.IsHistoricalContactInformation Or Address.AttributeName = CIRow.AttributeName Then
				Continue;
			EndIf;
			
			If Not ValueIsFilled(Address.Presentation) Then
				Continue;
			EndIf;
			
			CommandName = "MenuSubmenuAddress" + CIRow.AttributeName + "_" + Address.AttributeName;
			Command = Form.Commands.Find(CommandName);
			If Command = Undefined Then
				Continue;
			EndIf;
			
			AddressPresentation = ?(CIRow.InternationalAddressFormat,
				StringFunctionsClient.LatinString(Address.Presentation), Address.Presentation);
			
			If AddressesListInSubmenu[Upper(Address.Presentation)] <> Undefined Then
				AddressPresentation = "";
			Else
				AddressData = New Structure("Presentation, Address", AddressPresentation, Address.Value);
				If CIRow.InternationalAddressFormat Then
					AddressData.Address = ContactsManagerInternalServerCall.ContactsByPresentation(
						AddressPresentation, Address.Type, Address.Comment);
				EndIf;
				AddressesListInSubmenu.Insert(Upper(Address.Presentation), AddressData);
			EndIf;
				
			AddButtonCopyAddress(Form, CommandName, AddressPresentation, ContactInformationParameters, 
				ContextSubmenuCopyAddresses);
			
		EndDo;
		
		Field = Form.Items[CIRow.AttributeName];
		If Field.Type = FormFieldType.InputField Then
			Field.ChoiceList.Clear();
			PresentationForSearching = Upper(CIRow.Presentation);
			For Each AddressData In AddressesListInSubmenu Do
				If AddressData.Key <> PresentationForSearching Then
					Field.ChoiceList.Add(AddressData.Value, AddressData.Value.Presentation);
				EndIf;
			EndDo;
		EndIf;
		
		TotalCommands = TotalCommands + CommandsCountInSubmenu;
	EndDo;
	
EndProcedure

Procedure AddButtonCopyAddress(Form, CommandName, ItemTitle, ContactInformationParameters, Popup)
	
	TagName = Popup.Name + "_" + CommandName;
	Button = Form.Items.Find(TagName);
	If Button = Undefined Then
		Button = Form.Items.Add(TagName, Type("FormButton"), Popup);
		Button.CommandName = CommandName;
		AddedItems = ContactInformationParameters.AddedItems; // ValueList
		AddedItems.Add(TagName, 1);
	EndIf;
	Button.Title = ItemTitle;
	Button.Visible = ValueIsFilled(ItemTitle);

EndProcedure

// "ContactInformation" parameter constructor required for running contact information commands
// 
// Parameters:
//   Presentation - String - a contact information presentation.
//   Value      - String - A contact information field value in JSON or XML format.
//   Type           - EnumRef.ContactInformationTypes
//   Kind           - CatalogRef.ContactInformationKinds
//
// Returns:
//   Structure:
//     * Presentation - String - a contact information presentation.
//     * Value      - String - A contact information field value in JSON or XML format.
//     * Type           - EnumRef.ContactInformationTypes
//     * Kind           - CatalogRef.ContactInformationKinds
//
Function ParameterContactInfoForCommandExecution(Presentation, Value, Type, Kind)
	
	ContactInformation = New Structure;
	ContactInformation.Insert("Presentation", Presentation);
	ContactInformation.Insert("Value", Value);
	ContactInformation.Insert("Type", Type);
	ContactInformation.Insert("Kind", Kind);

	Return ContactInformation;
	
EndFunction

// Additional parameters constructor required for running contact information commands
// 
// Parameters:
//   ContactInformationOwner - DefinedType.ContactInformationOwner
//   Form - ClientApplicationForm
//   AttributeName - String
//
// Returns:
//   Structure:
//   * ContactInformationOwner - DefinedType.ContactInformationOwner
//   * Form - ClientApplicationForm
//   * AttributeName     - String - For internal use only.
//   * AsynchronousCall - Boolean - For internal use only.
//
Function CommandRuntimeAdditionalParameters(ContactInformationOwner, Form, AttributeName = "", AsynchronousCall = False)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ContactInformationOwner", ContactInformationOwner);
	AdditionalParameters.Insert("Form", Form);
	// For internal use.
	AdditionalParameters.Insert("AttributeName", AttributeName);
	AdditionalParameters.Insert("AsynchronousCall", AsynchronousCall);

	Return AdditionalParameters;
	
EndFunction

// Parameters:
//   HandlerName - String - The full path to the function to be executed.
//                             For example, "StandardSubsystemsClient.OpenMeetingDocForm".
//   Parameters - Structure:
//     * ContactInformation    - See ParameterContactInfoForCommandExecution
//     * AdditionalParameters - See CommandRuntimeAdditionalParameters
//
Procedure RunContactInfoCommand(HandlerName, Parameters)
	
	ProcedureNameStart = StrFind(HandlerName, ".", SearchDirection.FromEnd);
	
	If ProcedureNameStart = 0 Then
		Return;
	EndIf;
	
	ProcedureName = TrimAll(Mid(HandlerName, ProcedureNameStart + 1));
	ModuleName = TrimAll(Left(HandlerName, ProcedureNameStart - 1));
	
	ExecuteNotifyProcessing(New NotifyDescription(ProcedureName, CommonClient.CommonModule(ModuleName),
		Parameters.AdditionalParameters), Parameters.ContactInformation);	
	
EndProcedure

Procedure BeforePhoneCall(ContactInformation, AdditionalParameters) Export
	
	If IsBlankString(ContactInformation.Presentation) Then
		CommonClient.MessageToUser(
			NStr("en = 'To start a call, enter a phone number.';"), , AdditionalParameters.AttributeName);
		Return;
	EndIf;
	Telephone(ContactInformation.Presentation);
	
EndProcedure

Procedure BeforeCreateSMS(ContactInformation, AdditionalParameters) Export

	If IsBlankString(ContactInformation.Presentation) Then
		CommonClient.MessageToUser(
			NStr("en = 'To send a text message, enter a phone number.';"), , AdditionalParameters.AttributeName);
		Return;
	EndIf;
	SMSParameters = SMSAndEmailParameters();
	SMSParameters.Presentation = ContactInformation.Presentation;
	SMSParameters.ExpectedKind = ContactInformation.Type;
	SMSParameters.ContactInformationSource = AdditionalParameters.ContactInformationOwner;
	CreateSMSMessage("", SMSParameters);

EndProcedure

Procedure BeforeSkypeCall(ContactInformation, AdditionalParameters) Export
	
	CallSkype(ContactInformation.Presentation);
	
EndProcedure

Procedure BeforeStartSkypeChat(ContactInformation, AdditionalParameters) Export
	
	StartCoversationInSkype(ContactInformation.Presentation);
	
EndProcedure

Procedure BeforeNavigateWebLink(ContactInformation, AdditionalParameters) Export
	
	GoToWebLink("", ContactInformation.Presentation, ContactInformation.Type);
	
EndProcedure

Procedure BeforeCreateEmailMessage(ContactInformation, AdditionalParameters) Export

	EmailParameters = SMSAndEmailParameters();
	EmailParameters.Presentation = ContactInformation.Presentation;
	EmailParameters.ExpectedKind = ContactInformation.Type;
	EmailParameters.ContactInformationSource = AdditionalParameters.ContactInformationOwner;
	EmailParameters.AttributeName = AdditionalParameters.AttributeName;
	CreateEmailMessage("", EmailParameters);

EndProcedure

Procedure BeforeShowAddressOnGoogleMaps(ContactInformation, AdditionalParameters) Export
	
	CodedAddress = StringDecoding(ContactInformation.Presentation);
	CommandLine1 = "https://maps.google.com/?q=" + CodedAddress;
	FileSystemClient.OpenURL(CommandLine1);
	
EndProcedure

Procedure BeforeShowAddressOnYandexMaps(ContactInformation, AdditionalParameters) Export
	
	CodedAddress = StringDecoding(ContactInformation.Presentation);
	CommandLine1 = "https://maps.yandex.com/?text=" + CodedAddress;
	FileSystemClient.OpenURL(CommandLine1);
	
EndProcedure

Procedure BeforeEnterComment(ContactInformation, AdditionalParameters) Export
	
	Result = New Structure("AttributeName", AdditionalParameters.AttributeName);
	FoundRows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(
		AdditionalParameters.Form).FindRows(Result);
	If FoundRows.Count() = 0 Then
		Return;
	EndIf;

	FoundRow = FoundRows[0];
	Result.Insert("ItemForPlacementName", FoundRow.ItemForPlacementName);
	Result.Insert("ContactInformationType", FoundRow.Type);
	
	EnterAComment(AdditionalParameters.Form, AdditionalParameters.AttributeName, FoundRow, Result, 
		AdditionalParameters.AsynchronousCall);

EndProcedure

Procedure BeforeOpenChangeHistoryForm(ContactInformation, AdditionalParameters) Export
	
	Result = New Structure("AttributeName", AdditionalParameters.AttributeName);
	FoundRows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(
		AdditionalParameters.Form).FindRows(Result);
	If FoundRows.Count() = 0 Then
		Return;
	EndIf;

	FoundRow = FoundRows[0];
	
	OpenHistoryChangeForm(AdditionalParameters.Form, FoundRow, AdditionalParameters.AsynchronousCall);
	
EndProcedure

Procedure BeforeRunCommandFromAddressExtendedTooltip(Form, Item, AttributeName, CommandName, AsynchronousCall)

	Result = New Structure("AttributeName", AttributeName);
	FoundRows = ContactsManagerClientServer.DescriptionOfTheContactInformationOnTheForm(
			Form).FindRows(Result);
	If FoundRows.Count() = 0 Then
		Return;
	EndIf;
	FoundRow          = FoundRows[0];
	ItemForPlacementName = FoundRow.ItemForPlacementName;

	ContactInfoParameters = Form.ContactInformationParameters[ItemForPlacementName];
	OwnerOfTheKey = ContactInfoParameters.Owner;

	CommandsForOutput = ContactsManagerClientServer.CommandsToOutputToForm(ContactInfoParameters,
		FoundRow.Type, FoundRow.Kind, FoundRow.StoreChangeHistory);

	ContactInformation = ParameterContactInfoForCommandExecution(FoundRow.Presentation, 
		FoundRow.Value, FoundRow.Type, FoundRow.Kind);
	AdditionalParameters = CommandRuntimeAdditionalParameters(OwnerOfTheKey, Form, AttributeName, AsynchronousCall);
	Parameters = New Structure("ContactInformation, AdditionalParameters", ContactInformation,
		AdditionalParameters);

	If CommandName = "ShowOnMap" Then
		List = New ValueList;
		ShowOnYandexMaps = CommandsForOutput.ShowOnYandexMaps;
		List.Add(ShowOnYandexMaps.Action, ShowOnYandexMaps.Title, ,
			ShowOnYandexMaps.Picture);
		ShowOnGoogleMap = CommandsForOutput.ShowOnGoogleMap;
		List.Add(ShowOnGoogleMap.Action, ShowOnGoogleMap.Title, ,
			ShowOnGoogleMap.Picture);
		NotificationMenu = New NotifyDescription("AfterMenuItemSelected", ThisObject, Parameters);
		Form.ShowChooseFromMenu(NotificationMenu, List, Item);
	Else
		If CommandsForOutput.Property(CommandName) Then
			RunContactInfoCommand(CommandsForOutput[CommandName].Action, Parameters);
		EndIf;
	EndIf;

EndProcedure

// Deletes the prefix from a string. 
//
// Parameters:
//  InitialString - String
//  Prefix        - String
//
// Returns:
//   String
//
Function DeleteStringPrefix(InitialString, Prefix)

	If Not StrStartsWith(Upper(InitialString), Upper(Prefix)) Then
		Return InitialString;
	EndIf;

	PrefixLength = StrLen(Prefix);
	StringWithoutPrefix = Mid(InitialString, PrefixLength + 1);

	Return StringWithoutPrefix;

EndFunction

// Deletes the postfix from a string. 
//
// Parameters:
//  InitialString - String
//  Postfix       - String
//
// Returns:
//  String
//
Function DeleteStringPostfix(InitialString, Postfix)

	If Not StrEndsWith(Upper(InitialString), Upper(Postfix)) Then
		Return InitialString;
	EndIf;

	PostfixLength = StrLen(Postfix);
	StringLength = StrLen(InitialString);
	CharsCount = StringLength - PostfixLength;
	StringWithoutPostfix = Left(InitialString, CharsCount);

	Return StringWithoutPostfix;

EndFunction

#EndRegion