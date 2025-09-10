
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	LabelsDisplayParameters = PropertyManager.LabelsDisplayParameters();
	LabelsDisplayParameters.LabelsDestinationElementName = Items.GroupLabels.Name;
	LabelsDisplayParameters.LabelsDisplayOption = Enums.LabelsDisplayOptions.Label;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("LabelsDisplayParameters", LabelsDisplayParameters);
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ContactInformation
	AdditionalParameters = ContactsManager.ContactInformationParameters();
	AdditionalParameters.ItemForPlacementName = "ContactInformationGroup";
	ContactsManager.OnCreateAtServer(ThisObject, Object, AdditionalParameters);
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Interactions
	Interactions.PrepareNotifications(ThisObject, Parameters, False);
	// End StandardSubsystems.Interactions
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ContactInformation
	ContactsManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// EDI
	FillGroupEGovernmentByEDIServerIsTaxpayer();
	// End EDI
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Interactions
	InteractionsClient.ContactAfterWrite(ThisObject, Object, WriteParameters, "Counterparties");
	// End StandardSubsystems.Interactions
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNotifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ContactInformation
	ContactsManager.FillCheckProcessingAtServer(ThisObject, Object, Cancel);
	// End StandardSubsystems.ContactInformation
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ContactInformation
	ContactsManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ContactInformation
	ContactsManager.AfterWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// EDI
&AtClient
Procedure CheckIsTaxpayer(Command)
	
	ClearMessages();
	
	If Not IsBlankString(Object.TIN) And StrLen(Object.TIN) >= 10 Then
		
		MainCompany = PredefinedValue("Catalog.Companies.MainCompany");
		CounterprtyInfo = EDIClient.CheckCounterpartyIsTaxpayer(MainCompany, Object.TIN, True);
		If CounterprtyInfo.IsTaxpayer Then
			
			If Not IsBlankString(CounterprtyInfo.Description) Then
				
				If Object.LegalName <> CounterprtyInfo.Description Then
					UpdateLegalName(CounterprtyInfo.Description)
				EndIf;
				
			EndIf;
			
			FillGroupEGovernmentByEDIServerIsTaxpayer();
			
		EndIf;
		
	Else
		CommonClient.MessageToUser(NStr("en = 'TIN must have 10 digits.'; tr = 'VKN 10 basamaklı olmalıdır. '"));
	EndIf;
	
EndProcedure
// End EDI

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	AttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, Var_URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure
// End StandardSubsystems.Properties

#EndRegion

#Region Private

// EDI
&AtClient
Procedure FillGroupEGovernmentByEDIServerIsTaxpayer()
	
	TaxpayerStructure = EDIClientServer.IsTaxpayer(Object.TIN, PredefinedValue("Enum.EDocumentType.EInvoice"));
	UseEInvoice = TaxpayerStructure.Result;
	RegisterDateEInvoice = TaxpayerStructure.RegisterDate;
	ReceiverTagEInvoice = TaxpayerStructure.Identifier;
	
EndProcedure

&AtClient
Async Procedure UpdateLegalName(NewDescription)
	
	MessageText = NStr("en = 'Counterparty''s legal name is different. Use ""%1"" instead of ""%2""'; tr = 'Cari hesabın yasal ünvanı farklı. ""%2"" yerine ""%1"" kullanın'",
		CommonClientServer.DefaultLanguageCode());
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		MessageText,
		NewDescription,
		Object.LegalName);
	MessageTitle = NStr("en = 'Update legal name'; tr = 'Yasal unvanı güncelle'", CommonClientServer.DefaultLanguageCode());
	
	Response = Await DoQueryBoxAsync(MessageText, QuestionDialogMode.YesNo,,, MessageTitle);
	If Response = DialogReturnCode.Yes Then
		Object.LegalName = NewDescription;
		Object.Description = NewDescription;
		Modified = True;
	EndIf;
	
EndProcedure
// End EDI

// StandardSubsystems.Properties
&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure
// End StandardSubsystems.Properties

// StandardSubsystems.ContactInformation
&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	ContactsManagerClient.StartChanging(ThisObject, Item);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	ContactsManagerClient.StartSelection(ThisObject, Item,, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationOnClick(Item, StandardProcessing)
	ContactsManagerClient.StartSelection(ThisObject, Item,, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationClearing(Item, StandardProcessing)
	ContactsManagerClient.StartClearing(ThisObject, Item.Name);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationExecuteCommand(Command)
	ContactsManagerClient.StartCommandExecution(ThisObject, Command.Name);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	ContactsManagerClient.AutoCompleteAddress(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	ContactsManagerClient.ChoiceProcessing(ThisObject, ValueSelected, Item.Name, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	ContactsManagerClient.StartURLProcessing(ThisObject, Item, FormattedStringURL, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContinueContactInformationUpdate(Result, AdditionalParameters) Export
	UpdateContactInformation(Result);
EndProcedure

&AtServer
Procedure UpdateContactInformation(Result)
	ContactsManager.UpdateContactInformation(ThisObject, Object, Result);
EndProcedure
// End StandardSubsystems.ContactInformation

#EndRegion