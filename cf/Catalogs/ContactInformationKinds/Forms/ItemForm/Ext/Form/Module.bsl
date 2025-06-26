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
	
	If Object.Predefined Or Object.DenyEditingByUser Then
		Items.Description.ReadOnly = True;
		Items.Parent.ReadOnly     = True;
		Items.Type.ReadOnly          = True;
		Items.TypeCommonGroup.ReadOnly = Object.DenyEditingByUser;
		Items.IDForFormulas.ReadOnly = True;
	Else
		// Object attribute lock subsystem handler.
		If Common.SubsystemExists("StandardSubsystems.ObjectAttributesLock") Then
			ModuleObjectAttributesLock = Common.CommonModule("ObjectAttributesLock");
			ModuleObjectAttributesLock.LockAttributes(ThisObject,, NStr("en = 'Allow edit type and group';"));
			
		Else
			Items.Parent.ReadOnly = True;
			Items.Type.ReadOnly = True;
		EndIf;
	EndIf;
	
	KindBasis = Parameters.CopyingValue;
	CreatedByCopying = Not KindBasis.IsEmpty();

	If Object.Ref.IsEmpty() And Not CreatedByCopying Then
		Object.EditingOption = "InputFieldAndDialog";
	EndIf;
	
	ParentRef = Object.Parent;
	Items.StoreChangeHistory.Enabled         = Object.EditingOption = "Dialog";
	Items.AllowMultipleValueInput.Enabled = Not Object.StoreChangeHistory;	
	Items.IsAlwaysDisplayed.Enabled = Not Object.Mandatory;
	UpdatePhoneFaxItemsAvailability(ThisObject);
	
	If Not Object.CanChangeEditMethod Then
		Items.EditingOption.Enabled                  = False;
		Items.AllowMultipleValueInput.Enabled    = False;
		Items.SettingDescriptionByTypeGroup.Enabled = False;
		Items.StoreChangeHistory.Enabled            = False;
	EndIf;
	
	If Object.Type = Enums.ContactInformationTypes.Address
		Or Not ParentRef.IsEmpty()
		Or ParentRef.Level() = 0 Then
		TabularSection = Undefined;
		
		ParentAttributes = Common.ObjectAttributesValues(ParentRef, "PredefinedDataName, PredefinedKindName");
		PredefinedKindName = ?(ValueIsFilled(ParentAttributes.PredefinedKindName),
			ParentAttributes.PredefinedKindName, ParentAttributes.PredefinedDataName);
		
		If StrStartsWith(PredefinedKindName, "Catalog") Then
			ObjectName = Mid(PredefinedKindName, StrLen("Catalog") + 1);
			If Metadata.Catalogs.Find(ObjectName) <> Undefined Then
				TabularSection = Metadata.Catalogs[ObjectName].TabularSections.Find("ContactInformation");
			EndIf;
		ElsIf StrStartsWith(PredefinedKindName, "Document") Then
			ObjectName = Mid(PredefinedKindName, StrLen("Document") + 1);
			If Metadata.Documents.Find(ObjectName) <> Undefined Then
				TabularSection = Metadata.Documents[ObjectName].TabularSections.Find("ContactInformation");
			EndIf;
		EndIf;
		
		If TabularSection <> Undefined Then
			If TabularSection.Attributes.Find("ValidFrom") <> Undefined Then
				StoresHistoryChanges = True;
			EndIf;
		EndIf;
	EndIf;
	
	If (Object.Type = Enums.ContactInformationTypes.Phone
		Or Object.Type = Enums.ContactInformationTypes.Fax)
		And Object.EditingOption = "Dialog" Then
			Items.MaskOnEnterPhoneNumber.Enabled = False;
	EndIf;
	
	If Metadata.DataProcessors.Find("AdvancedContactInformationInput") <> Undefined Then
		ModuleAdvancedContactInformationInput = Common.CommonModule("DataProcessors.AdvancedContactInformationInput");
		AdditionalAddressSettingsAvailable = ModuleAdvancedContactInformationInput.AdditionalAddressSettingsAvailable()
	Else 
		AdditionalAddressSettingsAvailable = False;
	EndIf;
		
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnCreateAtServer(ThisObject, Object);
	EndIf;
	
	Items.FillIDForFormulas.Enabled = Not Items.IDForFormulas.ReadOnly;
	
	If ContactsManagerInternalCached.AreAddressManagementModulesAvailable() Then
		ModuleAddressManager = Common.CommonModule("AddressManager");
		ModuleAddressManager.FillInPhoneNumberMasks(Items.PhoneNumberMaskTemplate.ChoiceList);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ChangeDisplayOnTypeChange();
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "AfterInputStringsInDifferentLanguages"
		And Parameter = ThisObject Then
		If Not ValueIsFilled(Object.Ref) Then
			UpdateSuggestedIDValue();
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)   
	
	If Object.PhoneWithExtensionNumber And Object.EnterNumberByMask Then
		CommonClient.MessageToUser(NStr(
			"en = 'You cannot enter a phone number with an extension when the ""Enter number by mask"" option is set';"),
			, "PhoneWithExtensionNumber", "Object", Cancel);
	EndIf;
	
	If Not WriteParameters.Property("WhenIDForFormulasIsAlreadyUsed")
		And ValueIsFilled(Object.IDForFormulas) Then
		// Fill formula ID and check if there's a property with the same name.
		// 
		QueryText = IDForFormulasAlreadyUsed(
			Object.IDForFormulas, Object.Ref, Object.Parent);
		
		If ValueIsFilled(QueryText) Then
			Buttons = New ValueList;
			Buttons.Add("ContinueWrite",              NStr("en = 'Continue';"));
			Buttons.Add("BackToIDInput", NStr("en = 'Cancel';"));
			
			Cancel = True;
			
			ShowQueryBox(
				New NotifyDescription("AfterResponseOnQuestionWhenIDForFormulasIsAlreadyUsed", ThisObject, WriteParameters),
				QueryText, Buttons, , "ContinueWrite");
			
		Else
			WriteParameters.Insert("IDCheckForFormulasCompleted");
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not CurrentObject.CheckFilling() Then
		Cancel = True;
	EndIf;
	
	If TheTypeOfCISWithThisNameAlreadyExists(CurrentObject) Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Contact information kind with the %1 description already exists. Specify another description.';"),
			String(CurrentObject.Description));
		
	EndIf;
	
	// Generate ID for additional attribute (information record) formulas.
	If Not ValueIsFilled(CurrentObject.IDForFormulas)
		Or WriteParameters.Property("WhenIDForFormulasIsAlreadyUsed") Then
		
		ObjectDescription = TitleForID(CurrentObject);
		
		CurrentObject.IDForFormulas = Catalogs.ContactInformationKinds.UUIDForFormulas(
			ObjectDescription, CurrentObject.Ref, CurrentObject.Parent);
		
		WriteParameters.Insert("IDCheckForFormulasCompleted");
	EndIf;
	If WriteParameters.Property("IDCheckForFormulasCompleted") Then
		CurrentObject.AdditionalProperties.Insert("IDCheckForFormulasCompleted");
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.BeforeWriteAtServer(CurrentObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If Not CurrentObject.Predefined Then
		// Object attribute lock subsystem handler.
		If Common.SubsystemExists("StandardSubsystems.ObjectAttributesLock") Then
			ModuleObjectAttributesLock = Common.CommonModule("ObjectAttributesLock");
			ModuleObjectAttributesLock.LockAttributes(ThisObject);
		EndIf;
	EndIf;
	
	Items.FillIDForFormulas.Enabled = Not Items.IDForFormulas.ReadOnly;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	CheckedAttributes.Clear();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	If Not ValueIsFilled(Object.Ref) Then
		UpdateSuggestedIDValue();
	EndIf;
EndProcedure

&AtClient
Procedure TypeOnChange(Item)
	
	ChangeAttributesOnTypeChange();
	ChangeDisplayOnTypeChange();
	
EndProcedure

&AtClient
Procedure TypeClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure MandatoryOnChange(Item)
	
	If Object.Mandatory Then
		Object.IsAlwaysDisplayed = True;
		Items.IsAlwaysDisplayed.Enabled = False;
	Else
		Items.IsAlwaysDisplayed.Enabled = True;
	EndIf; 
	 
EndProcedure

&AtClient
Procedure EditingOptionOnChange(Item)
	
	If Object.EditingOption = "Dialog" Then
		Items.StoreChangeHistory.Enabled     = True;
		Object.EnterNumberByMask                       = False;
	Else
		Items.StoreChangeHistory.Enabled     = False;
		Object.StoreChangeHistory                   = False;
	EndIf;
	
	UpdatePhoneFaxItemsAvailability(ThisObject);
	
	Items.AllowMultipleValueInput.Enabled = Not Object.StoreChangeHistory;
	
EndProcedure

&AtClient
Procedure StoreChangeHistoryOnChange(Item)
	
	If Object.StoreChangeHistory Then
		Object.AllowMultipleValueInput = False;
	EndIf;
	
	Items.AllowMultipleValueInput.Enabled = Not Object.StoreChangeHistory;
	
EndProcedure

&AtClient
Procedure AllowMultipleValueInputOnChange(Item)
	
	If Object.AllowMultipleValueInput Then
		Object.StoreChangeHistory = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ParentClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure InternationalAddressFormatOnChange(Item)
	
	ChangeDisplayOnTypeChange();
	
EndProcedure

&AtClient
Procedure PhoneWithExtensionNumberOnChange(Item)
	
	UpdatePhoneFaxItemsAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure MaskOnEnterPhoneNumberOnChange(Item)

	UpdatePhoneFaxItemsAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_Opening(Item, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportClient = CommonClient.CommonModule("NationalLanguageSupportClient");
		ModuleNationalLanguageSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Attachable_AllowObjectAttributeEdit(Command)
	
	If Not Object.Predefined Then
		If CommonClient.SubsystemExists("StandardSubsystems.ObjectAttributesLock") Then
			ModuleObjectAttributesLockClient = CommonClient.CommonModule("ObjectAttributesLockClient");
			Notification = New NotifyDescription("AllowObjectAttributeEditCompletion", ThisObject);
			ModuleObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject, Notification);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowObjectAttributeEditCompletion(Result, AdditionalParameters) Export
	
	If Not Result = Undefined Then
		Items.FillIDForFormulas.Enabled = Not Items.IDForFormulas.ReadOnly;
	EndIf;
	
EndProcedure

&AtClient
Procedure AdditionalAddressSettings(Command)
	ClosingNotification = New NotifyDescription("AfterCloseAddressSettingsForm", ThisObject);
	FormParameters = New Structure();
	FormParameters.Insert("Object", Object);
	FormParameters.Insert("ReadOnly", ReadOnly);
	AddressSettingsFormName = "DataProcessor.AdvancedContactInformationInput.Form.AddressSettings";
	OpenForm(AddressSettingsFormName, FormParameters,,,,, ClosingNotification);
EndProcedure

&AtClient
Procedure FillIDForFormulas(Command)
	FillIDForFormulasAtServer();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ChangeDisplayOnTypeChange()
	
	If Object.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Items.Checks.CurrentPage = Items.Checks.ChildItems.Address;
		Items.EditingOption.Enabled  = Object.CanChangeEditMethod;
		Items.AdditionalAddressSettings.Visible   = AdditionalAddressSettingsAvailable;
		Items.AdditionalAddressSettings.Enabled = Not Object.InternationalAddressFormat;
		Items.EditingOption.Visible = True;
		Items.StoreChangeHistoryGroup.Visible = StoresHistoryChanges;
		
		FieldsAvailabilityForAddress();
		
	Else
		
		Items.AdditionalAddressSettings.Visible = False;
		If Object.Type = PredefinedValue("Enum.ContactInformationTypes.Email") Then
			Items.Checks.CurrentPage = Items.Checks.ChildItems.Email;
			Items.EditingOption.Visible = False;
			Items.StoreChangeHistoryGroup.Visible = False;
		ElsIf Object.Type = PredefinedValue("Enum.ContactInformationTypes.Skype") Then
			Items.Checks.CurrentPage = Items.Checks.ChildItems.Skype;
			Items.EditingOption.Visible = False;
			Items.AllowMultipleValueInput.Enabled = True;
			Items.StoreChangeHistoryGroup.Visible = False;
		ElsIf Object.Type = PredefinedValue("Enum.ContactInformationTypes.Phone")
			Or Object.Type = PredefinedValue("Enum.ContactInformationTypes.Fax") Then
			Items.Checks.CurrentPage = Items.Checks.ChildItems.Phone;
			Items.EditingOption.Enabled = Object.CanChangeEditMethod;
			Items.EditingOption.Visible = True;
			Items.StoreChangeHistoryGroup.Visible = StoresHistoryChanges;
		ElsIf Object.Type = PredefinedValue("Enum.ContactInformationTypes.Other") Then
			Items.Checks.CurrentPage = Items.Checks.ChildItems.Other;
			Items.EditingOption.Enabled = False;
			Items.EditingOption.Visible = False;
			Items.StoreChangeHistoryGroup.Visible = False;
		ElsIf Object.Type = PredefinedValue("Enum.ContactInformationTypes.WebPage") Then
			Items.Checks.CurrentPage = Items.Checks.ChildItems.OtherItems;
			Items.EditingOption.Visible = False;
			Items.StoreChangeHistoryGroup.Visible = False;
		Else
			Items.Checks.CurrentPage = Items.Checks.ChildItems.OtherItems;
			Items.EditingOption.Enabled = False;
			Items.StoreChangeHistoryGroup.Visible = False;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure FieldsAvailabilityForAddress()
	
	If ReadOnly Then
		Return;
	EndIf;
	
	If Object.EditingOption = "InputField" Then
		Object.IncludeCountryInPresentation = False;
		Items.IncludeCountryInPresentation.Enabled = False;
	Else
		Items.IncludeCountryInPresentation.Enabled = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeAttributesOnTypeChange()
	
	If Object.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Items.StoreChangeHistory.Enabled = Object.EditingOption = "Dialog";
	Else
		
		FlagStoreChangeHistory             = False;
		FlagAvailabilityKeepHistoryChanges = False;
		
		If Object.Type = PredefinedValue("Enum.ContactInformationTypes.Email") Then
			Object.EditingOption = "InputField";
		ElsIf Object.Type = PredefinedValue("Enum.ContactInformationTypes.Phone")
			Or Object.Type = PredefinedValue("Enum.ContactInformationTypes.Fax") Then
			FlagStoreChangeHistory             = Object.StoreChangeHistory;
			FlagAvailabilityKeepHistoryChanges = Object.EditingOption = "Dialog";
		Else
			Object.EditingOption = "InputFieldAndDialog";
		EndIf;
		Object.StoreChangeHistory               = FlagStoreChangeHistory;
		Items.StoreChangeHistory.Enabled = FlagAvailabilityKeepHistoryChanges;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterCloseAddressSettingsForm(Result, AdditionalParameters) Export
	If TypeOf(Result) = Type("Structure") Then
		FillPropertyValues(Object, Result);
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Procedure UpdatePhoneFaxItemsAvailability(Form)

	Form.Items.PhoneNumberMaskTemplate.Enabled = Form.Object.EnterNumberByMask;
	Form.Items.PhoneNumberMaskTemplate.AutoMarkIncomplete  = Form.Object.EnterNumberByMask;  
	Form.Items.MaskOnEnterPhoneNumber.Enabled = (Not Form.Object.PhoneWithExtensionNumber And Not Form.Object.EditingOption = "Dialog") Or Form.Object.EnterNumberByMask;
    Form.Items.PhoneWithExtensionNumber.Enabled = Not Form.Object.EnterNumberByMask Or Form.Object.PhoneWithExtensionNumber;
	
EndProcedure

&AtServer
Procedure UpdateSuggestedIDValue()
	
	SuggestedID = "";
	If Not Items.IDForFormulas.ReadOnly Then
		
		If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
			CurrentLanguageSuffix = ModuleNationalLanguageSupportServer.CurrentLanguageSuffix();
			Presentation = ?(ValueIsFilled(CurrentLanguageSuffix),
				Object["Description"+ CurrentLanguageSuffix],
				Object.Description);
		Else
			Presentation = Object.Description;
		EndIf;
		
		SuggestedID = Catalogs.ContactInformationKinds.UUIDForFormulas(
			Presentation, Object.Ref, Object.Parent);
		If SuggestedID <> Object.IDForFormulas Then
			Object.IDForFormulas = SuggestedID;
			Modified = True;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillIDForFormulasAtServer()
	
	TitleForID = TitleForID(Object);
	
	Object.IDForFormulas = Catalogs.ContactInformationKinds.UUIDForFormulas(
		TitleForID, Object.Ref, Object.Parent);
EndProcedure

&AtServerNoContext
Function TitleForID(CurrentObject)
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		CurrentLanguageSuffix = ModuleNationalLanguageSupportServer.CurrentLanguageSuffix();
		TitleForID = ?(ValueIsFilled(CurrentLanguageSuffix),
			CurrentObject["Description"+ CurrentLanguageSuffix],
			CurrentObject.Description);
	Else
		TitleForID = CurrentObject.Description;
	EndIf;
	
	Return TitleForID;
	
EndFunction

&AtClient
Procedure AfterResponseOnQuestionWhenIDForFormulasIsAlreadyUsed(Response, WriteParameters) Export
	
	If Response <> "ContinueWrite" Then
		If WriteParameters.Property("ContinuationHandler") Then
			ExecuteNotifyProcessing(
				New NotifyDescription(WriteParameters.ContinuationHandler.ProcedureName,
					ThisObject, WriteParameters.ContinuationHandler.Parameters),
				True);
		EndIf;
	Else
		WriteParameters.Insert("WhenIDForFormulasIsAlreadyUsed");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function TheTypeOfCISWithThisNameAlreadyExists(CurrentObject)
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	ContactInformationKinds.Ref AS Ref
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds
		|WHERE
		|	ContactInformationKinds.Description = &Description
		|	AND ContactInformationKinds.Parent = &Parent
		|	AND ContactInformationKinds.Ref <> &Ref";
	
	Query.SetParameter("Description", CurrentObject.Description);
	Query.SetParameter("Parent",     CurrentObject.Parent);
	Query.SetParameter("Ref",       CurrentObject.Ref);
	
	QueryResult = Query.Execute();
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

&AtServerNoContext
Function IDForFormulasAlreadyUsed(Val IDForFormulas, Val CurrentContactInformationKind, Val Parent)
	
	VerificationID = Catalogs.ContactInformationKinds.IDForFormulas(IDForFormulas);
	If Upper(IDForFormulas) <> Upper(VerificationID) Then
		QueryText = NStr("en = 'ID ""%1"" does not comply with variable naming rules.
		                          |An ID must not contain spaces and special characters.
		                          |
		                          |Do you want to create a new ID for formulas and continue saving?';");
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			QueryText,
			IDForFormulas);
		Return QueryText;
	EndIf;
	
	TopLevelParent = Parent;
	While ValueIsFilled(TopLevelParent) Do
		Value = Common.ObjectAttributeValue(TopLevelParent, "Parent");
		If ValueIsFilled(Value) Then
			TopLevelParent = Value;
		Else
			Break;
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	ContactInformationKinds.Ref
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|WHERE
	|	ContactInformationKinds.IDForFormulas = &IDForFormulas
	|	AND ContactInformationKinds.Ref <> &Ref
	|	AND ContactInformationKinds.Ref IN HIERARCHY (&Parent)";
	
	Query.SetParameter("Ref", CurrentContactInformationKind);
	Query.SetParameter("IDForFormulas", IDForFormulas);
	Query.SetParameter("Parent", TopLevelParent);
	
	Selection = Query.Execute().Select();
	
	If Not Selection.Next() Then
		Return "";
	EndIf;
	
	QueryText = NStr("en = 'A contact information kind with ID for formulas 
	                          |""%1"" already exists.
	                          |
	                          |It is recommended that you use another ID for formulas.
	                          |Otherwise, the app might malfunction.
	                          |
	                          |Create a new ID for the formulas and continue saving?';");
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		QueryText,
		IDForFormulas);
	
	Return QueryText;
	
EndFunction

#EndRegion

