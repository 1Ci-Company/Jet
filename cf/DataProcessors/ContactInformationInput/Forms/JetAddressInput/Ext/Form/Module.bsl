
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("OpenByScenario") Then
		Raise NStr("en = 'Form is not intended for direct usage.'; tr = 'Form doğrudan kullanıma yönelik değildir.'");
	EndIf;
	
	CIKindStructure = ContactsManagerInternal.ContactInformationKindStructure(Parameters.ContactInformationKind);
	
	Title = ?(IsBlankString(Parameters.Title), CIKindStructure.Description, Parameters.Title);
	
	// Attempting to fill data based on parameter values.
	FieldsValues = DefineAddressValue(Parameters);
	
	If IsBlankString(FieldsValues) Then
		LocalityDetailed = JetAddressManagerClientServer.NewAddressDetails();
	ElsIf ContactsManagerClientServer.IsJSONContactInformation(FieldsValues) Then
		AddressData = ContactsManagerInternal.JSONStringToStructure1(FieldsValues);
		LocalityDetailed = PrepareAddressForInput(AddressData);
	EndIf;
	
	SetAttributeValueByContacts();
	
	SetFormUsageKey();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(WarningTextOnOpen) Then
		CommonClient.MessageToUser(WarningTextOnOpen,, WarningFieldOnOpen);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New CallbackDescription("ConfirmAndClose", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CountryOnChange(Item)
	
	LocalityDetailed.Country = TrimAll(Country);
	
EndProcedure

&AtClient
Procedure CountryClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure CountryAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting)
	
	If DataGetParameters = 0 Then
		// Generating the quick selection list.
		If IsBlankString(Text) Then
			ChoiceData = New ValueList;
		EndIf;
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure CountryTextInputEnd(Item, Text, ChoiceData, DataGetParameters)
	
	If IsBlankString(Text) Then
		DataGetParameters = False;
	EndIf;
	
#If WebClient Then
	// Addressing platform specifics.
	DataGetParameters = False;
	ChoiceData = New ValueList;
	ChoiceData.Add(Country);
#EndIf

EndProcedure

&AtClient
Procedure CountryChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	ContactsManagerClient.WorldCountryChoiceProcessing(Item, ValueSelected, StandardProcessing);
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	LocalityDetailed.Comment = Comment;
	
EndProcedure

&AtClient
Procedure AddressLine1OnChange(Item)
	
	LocalityDetailed.AddressLine1 = AddressLine1;
	
EndProcedure

&AtClient
Procedure AddressLine2OnChange(Item)
	
	LocalityDetailed.AddressLine2 = AddressLine2;
	
EndProcedure

&AtClient
Procedure CityOnChange(Item)
	
	LocalityDetailed.City = City;
	
EndProcedure

&AtClient
Procedure StateOnChange(Item)
	
	LocalityDetailed.State = State;
	
EndProcedure

&AtClient
Procedure PostalCodeOnChange(Item)
	
	LocalityDetailed.PostalCode = PostalCode;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OkCommand(Command)
	
	ConfirmAndClose();
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Modified = False;
	Close();
	
EndProcedure

&AtClient
Procedure ClearAddress(Command)
	
	ClearAddressClient();
	SetAttributeValueByContacts();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ConfirmAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	If Modified Then
		
		FillAddressPresentation(LocalityDetailed, CIKindStructure);
		Context = New Structure("CIKindStructure, LocalityDetailed");
		FillPropertyValues(Context, ThisObject);
		Result = SelectionResult(Context);
		
		If TypeOf(Result) = Type("Structure") Then
			Result.Insert("ContactInformationAdditionalAttributesDetails", ContactInformationAdditionalAttributesDetails);
		EndIf;
		
		ClearModifiedOnChoice();
#If WebClient Then
		CloseFlag = CloseOnChoice;
		CloseOnChoice = False;
		NotifyChoice(Result);
		CloseOnChoice = CloseFlag;
#Else
		NotifyChoice(Result);
#EndIf
		SaveFormState();
		
	ElsIf Comment <> CommentCopy Then
		// Only the comment was modified, attempting to revert.
		Result = CommentChoiceOnlyResult(Parameters.FieldsValues, Parameters.Presentation, Comment);
		ClearModifiedOnChoice();
#If WebClient Then
		CloseFlag = CloseOnChoice;
		CloseOnChoice = False;
		NotifyChoice(Result);
		CloseOnChoice = CloseFlag;
#Else
		NotifyChoice(Result);
#EndIf
		SaveFormState();
		
	Else
		Result = Undefined;
	EndIf;
	
	If (ModalMode Or CloseOnChoice) And IsOpen() Then
		ClearModifiedOnChoice();
		SaveFormState();
		Close(Result);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure FillAddressPresentation(Address, InformationKind)
	
	If TypeOf(InformationKind) = Type("Structure") And InformationKind.Property("IncludeCountryInPresentation") Then
		IncludeCountryInPresentation = InformationKind.IncludeCountryInPresentation;
	Else
		IncludeCountryInPresentation = False;
	EndIf;
	
	JetAddressManagerClientServer.UpdateAddressPresentation(Address, IncludeCountryInPresentation);
	
EndProcedure

&AtClient
Procedure SaveFormState()
	
	SetFormUsageKey();
	SavedInSettingsDataModified = True;
	
EndProcedure

&AtClient
Procedure ClearModifiedOnChoice()
	
	Modified = False;
	CommentCopy = Comment;
	
EndProcedure

&AtServerNoContext
Function SelectionResult(Context)
	
	LocalityDetailed = Context.LocalityDetailed;
	CI = JetContactsManagerLocalization.ContactsFromJSONToXML(LocalityDetailed, Context.CIKindStructure.Type);
	
	Result = New Structure;
	Result.Insert("ContactInformation", CI);
	Result.Insert("Value", ContactsManagerInternal.ToJSONStringStructure(LocalityDetailed));
	Result.Insert("Presentation", LocalityDetailed.Value);
	Result.Insert("Comment", LocalityDetailed.Comment);
	Result.Insert("EnteredInFreeFormat", ContactsManagerInternal.AddressEnteredInFreeFormat(LocalityDetailed));
	
	If Context.CIKindStructure.Type = Enums.ContactInformationTypes.Address
		And Context.CIKindStructure.EditingOption = "Dialog" Then
		Result.Insert("AsHyperlink", True);
	Else
		Result.Insert("AsHyperlink", False);
	EndIf;
	
	// Suppressing line breaks in the separately returned presentation.
	Result.Presentation = TrimAll(StrReplace(Result.Presentation, Chars.LF, " "));
	Result.Insert("Kind", Context.CIKindStructure.Ref);
	Result.Insert("Type", Context.CIKindStructure.Type);
	
	Return Result;
	
EndFunction

&AtServer
Function CommentChoiceOnlyResult(ContactInfo, Presentation, Comment)
	
	If IsBlankString(ContactInfo) Then
		NewContactInfo = JetContactsManagerLocalization.XMLAddressInXDTO("");
		NewContactInfo.Comment = Comment;
		NewContactInfo = JetContactsManagerLocalization.XDTOContactsInXML(NewContactInfo);
		AddressEnteredInFreeFormat = False;
	ElsIf ContactsManagerClientServer.IsXMLContactInformation(ContactInfo) Then
		// Copy
		NewContactInfo = ContactInfo;
		// Modifying NewContactInfo value.
		ContactsManager.SetContactInformationComment(NewContactInfo, Comment);
		AddressEnteredInFreeFormat = ContactsManagerInternal.AddressEnteredInFreeFormat(ContactInfo);
	Else
		NewContactInfo = ContactInfo;
		AddressEnteredInFreeFormat = False;
	EndIf;
	
	Result = New Structure;
	Result.Insert("ContactInformation", NewContactInfo);
	Result.Insert("Presentation", Presentation);
	Result.Insert("Comment", Comment);
	Result.Insert("EnteredInFreeFormat", AddressEnteredInFreeFormat);
	
	Return Result;
	
EndFunction

&AtServer
Procedure SetAttributeValueByContacts()
	
	FillPropertyValues(ThisObject, LocalityDetailed);
	
	If LocalityDetailed.Property("Comment") Then
		Comment = LocalityDetailed.Comment;
	EndIf;
	
	// Comment copy used to identify data modifications.
	CommentCopy = Comment;
	
	CountryData = Undefined;
	If LocalityDetailed.Property("Country") And ValueIsFilled(LocalityDetailed.Country) Then
		CountryData = Catalogs.WorldCountries.WorldCountryData(, TrimAll(LocalityDetailed.Country));
	EndIf;
	
	If CountryData = Undefined Then
		Country = Catalogs.WorldCountries.EmptyRef();
	Else
		Country = CountryData.Ref;
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearAddressClient()
	
	For Each AddressItem In LocalityDetailed Do
		
		If AddressItem.Key = "Type" Then
			Continue;
		EndIf;
		
		LocalityDetailed[AddressItem.Key] = "";
		
	EndDo;
	
	If CIKindStructure.OnlyNationalAddress Then
		LocalityDetailed.Country = PredefinedValue("Catalog.WorldCountries.EmptyRef");
	EndIf;
	
	LocalityDetailed.AddressType = ContactsManagerClientServer.CustomFormatAddress();
	
EndProcedure

&AtServer
Procedure SetFormUsageKey()
	
	WindowOptionsKey = String(Country);
	
EndProcedure

&AtServer
Function DefineAddressValue(Parameters)
	
	If Parameters.Property("Value") Then
		If IsBlankString(Parameters.Value) And ValueIsFilled(Parameters.FieldsValues) Then
			FieldsValues = Parameters.FieldsValues;
		Else
			FieldsValues = Parameters.Value;
		EndIf;
	Else
		FieldsValues = Parameters.FieldsValues;
	EndIf;
	
	Return FieldsValues;
	
EndFunction

&AtServer
Function PrepareAddressForInput(Data)
	
	LocalityDetailed = JetAddressManagerClientServer.NewAddressDetails();
	
	FillPropertyValues(LocalityDetailed, Data);
	
	IsEmptyAddress = True;
	
	For Each AddressItem In LocalityDetailed Do
		
		If StrEndsWith(AddressItem.Key, "ID")
			And TypeOf(AddressItem.Value) = Type("String")
			And StrLen(AddressItem.Value) = 36 Then
			LocalityDetailed[AddressItem.Key] = New UUID(AddressItem.Value);
		EndIf;
		
		If ValueIsFilled(AddressItem.Value)
			And AddressItem.Key <> "AddressType"
			And AddressItem.Key <> "type"
			And AddressItem.Key <> "value" Then
			IsEmptyAddress = False;
		EndIf;
		
	EndDo;
	
	If IsEmptyAddress Then
		LocalityDetailed.AddressLine1 = LocalityDetailed.value;
	EndIf;
	
	Return LocalityDetailed;
	
EndFunction

#EndRegion