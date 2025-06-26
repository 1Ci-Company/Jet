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

// Changes, adds, or deletes contact information standard commands displayed in catalogs and documents.
// Toggles contact information icons on the left of the contact information kind title.
// Changes the position of the button "Add additional contact information field".
// Changes the width of the comment field for the contact information of the kinds
// "Phone", "Email", "Skype", "WebPage", and "Fax".
//
// Parameters:
//  Settings - Structure:
//    * ShouldShowIcons - Boolean
//    * DetailsOfCommands - See ContactsManager.DetailsOfCommands
//    * PositionOfAddButton - ItemHorizontalLocation - Valid values are Left, Right, or Auto.
//                                                                  If set to Left, it always appears on the left.
//                                                                  If set to Right, it always appears on the right.
//                                                                  If set to Auto, it is positioned on the right if
//                                                                         contact information is a field
//                                                                         and on the left if contact information is a hyperlink
//                                                                         or if there is no contact information field.
//                                                                         
//    * CommentFieldWidth - Number - Comment field width for contact information fields of the following types: Phone, Email,
//                                      Skype, WebPage, and Fax. This parameter is set only if the contact
//                                      information group is limited in width.
//
//  Example:
//     Settings.ShouldShowIcons = True;
//     Settings.CommentFieldWidth = 10;
//     Settings.PositionOfAddButton = ItemHorizontalLocation.Auto;
//
//     Address = Enum.ContactInformationTypes.Address;
//     Settings.CommandDetails[Address].PlanMeeting.Title = NStr("ru='Meeting'");
//     Settings.CommandDetails[Address].PlanMeeting.ToolTip = NStr("en='Schedule a meeting.'");
//     Settings.CommandDetails[Address].PlanMeeting.Picture = PictureLib.PlannedInteraction;
//     Settings.CommandDetails[Address].PlanMeeting.Action = "StandardSubsystemsClient.OpenMeetingDocForm";
//    
//     CompanyPhysicalAddress = ContactsManager.ContactInformationKindByName("_DemoCompanyPhysicalAddress");
//      Settings.CommandDetails[CompanyPhysicalAddress] = 
//    	Common.CopyRecursive(ContactsManager.CommandsOfContactInfoType(Enums.ContactInformationTypes.Address));
//      Settings.CommandDetails[CompanyPhysicalAddress].PlanMeeting.Action = ""; // Disable the command for the contact information kind.
//
//   2 parameters are passed to the procedures specified in "Action":
//       ContactInformation - Structure:
//         * Presentation - String
//         * Value - String
//         * Type - EnumRef.ContactInformationTypes
//         * Kind - CatalogRef.ContactInformationKinds
//       AdditionalParameters - Structure:        
//         * ContactInformationOwner - DefinedType.ContactInformationOwner.
//         * Form - ClientApplicationForm - Form of the owner object, where the contact information is to be displayed.
// 
//     Procedure OpenMeetingDocForm(ContactInformation, AdditionalParameters) Export
//		  FillingValues = New Structure;
//		  FillingValues.Insert("MeetingPlace", ContactInformation.Presentation);
//		  If TypeOf(AdditionalParameters.ContactInformationOwner) = Type("DocumentRef.SalesOrder") Then
//		    	FillingValues.Insert("SubjectOf", AdditionalParameters.ContactInformationOwner);
//		    	FillingValues.Insert("Contact", "");
//		  Else
//		    	FillingValues.Insert("Contact", AdditionalParameters.ContactInformationOwner);
//		    	FillingValues.Insert("SubjectOf", "");
//		  EndIf;
//
//		  OpenForm("Document.Meeting.ObjectForm", New Structure("FillingValues", FillingValues),
//			AdditionalParameters.Form);
//	   EndProcedure
//
Procedure OnDefineSettings(Settings) Export

	
    
EndProcedure

// Gets descriptions of contact information kinds in different languages.
//
// Parameters:
//  Descriptions - Map of KeyAndValue - a presentation of a contact information kind in the passed language:
//     * Key     - String - The name of a contact information kind. For example, "PartnerAddress".
//     * Value - String - a description of a contact information kind for the passed language code.
//  LanguageCode - String - a language code. For example, "en".
//
// Example:
//  Descriptions["PartnerAddress"] = NStr("ru='Адрес'; en='Address';", LanguageCode);
//
Procedure OnGetContactInformationKindsDescriptions(Descriptions, LanguageCode) Export
	
	
	
EndProcedure

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling
// 
// Parameters:
//  Settings - See InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.Settings
//
Procedure OnSetUpInitialItemsFilling(Settings) Export
	
EndProcedure

// See also InfobaseUpdateOverridable.OnInitialItemsFilling
//
// Parameters:
//  LanguagesCodes - See InfobaseUpdateOverridable.OnInitialItemsFilling.LanguagesCodes
//  Items   - See InfobaseUpdateOverridable.OnInitialItemsFilling.Items
//  TabularSections - See InfobaseUpdateOverridable.OnInitialItemsFilling.TabularSections
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items, TabularSections) Export

#Region Company
	
	Item = Items.Add(); 
	Item.PredefinedKindName = "CatalogCompanies";
	Item.IsFolder = True;
	Item.Used = True;
	Item.Description = NStr("en = 'Contact information of the ""Companies"" catalog'", Common.DefaultLanguageCode());
	
	Item = Items.Add();
	Item.PredefinedKindName = "CompanyActualAddress";
	Item.Parent = "CatalogCompanies";
	Item.Type = Enums.ContactInformationTypes.Address;
	Item.IDForFormulas = "ActualAddress";
	Item.EditingOption = "InputField";
	Item.IncludeCountryInPresentation = True;
	Item.InternationalAddressFormat = True;
	Item.StoreChangeHistory = False;
	Item.IsAlwaysDisplayed = True;
	Item.Used = True;
	Item.AddlOrderingAttribute = 1;
	Item.Description = NStr("en = 'Actual address'", Common.DefaultLanguageCode());
	
	Item = Items.Add();
	Item.PredefinedKindName = "CompanyLegalAddress";
	Item.Parent = "CatalogCompanies";
	Item.Type = Enums.ContactInformationTypes.Address;
	Item.IDForFormulas = "LegalAddress";
	Item.EditingOption = "InputField";
	Item.IncludeCountryInPresentation = True;
	Item.InternationalAddressFormat = True;
	Item.StoreChangeHistory = False;
	Item.IsAlwaysDisplayed = True;
	Item.Used = True;
	Item.AddlOrderingAttribute = 2;
	Item.Description = NStr("en = 'Legal address'", Common.DefaultLanguageCode());
	
	Item = Items.Add();
	Item.PredefinedKindName = "CompanyWebpage";
	Item.Parent = "CatalogCompanies";
	Item.Type = Enums.ContactInformationTypes.WebPage;
	Item.IDForFormulas = "Webpage";
	Item.EditingOption = "InputField";
	Item.AllowMultipleValueInput = True;
	Item.AddlOrderingAttribute = 3;
	Item.IsAlwaysDisplayed = True;
	Item.Used = True;
	Item.Description = NStr("en = 'Webpage'", Common.DefaultLanguageCode());
	
	Item = Items.Add();
	Item.PredefinedKindName = "CompanyPhone";
	Item.Parent = "CatalogCompanies";
	Item.Type = Enums.ContactInformationTypes.Phone;
	Item.IDForFormulas = "Phone";
	Item.EditingOption = "InputFieldAndDialog";
	Item.CanChangeEditMethod = True;
	Item.AllowMultipleValueInput = True;
	Item.PhoneWithExtensionNumber = True;
	Item.AddlOrderingAttribute = 4;
	Item.IsAlwaysDisplayed = True;
	Item.Used = True;
	Item.Description = NStr("en = 'Phone'", Common.DefaultLanguageCode());
	
	Item = Items.Add();
	Item.PredefinedKindName = "CompanyEmail";
	Item.Parent = "CatalogCompanies";
	Item.Type = Enums.ContactInformationTypes.Email;
	Item.IDForFormulas = "Email";
	Item.EditingOption = "InputField";
	Item.AllowMultipleValueInput = True;
	Item.AddlOrderingAttribute = 5;
	Item.IsAlwaysDisplayed = True;
	Item.Used = True;
	Item.Description = NStr("en = 'Email'", Common.DefaultLanguageCode());
	
#EndRegion

#Region Counterparties
	
	Item = Items.Add(); 
	Item.PredefinedKindName = "CatalogCounterparties";
	Item.IsFolder = True;
	Item.Used = True;
	Item.Description = NStr("en = 'Contact information of the ""Counterparties"" catalog'", Common.DefaultLanguageCode());
	
	Item = Items.Add();
	Item.PredefinedKindName = "CounterpartyActualAddress";
	Item.Parent = "CatalogCounterparties";
	Item.Type = Enums.ContactInformationTypes.Address;
	Item.IDForFormulas = "ActualAddress";
	Item.EditingOption = "InputField";
	Item.IncludeCountryInPresentation = True;
	Item.InternationalAddressFormat = True;
	Item.StoreChangeHistory = False;
	Item.IsAlwaysDisplayed = True;
	Item.Used = True;
	Item.AddlOrderingAttribute = 1;
	Item.Description = NStr("en = 'Actual address'", Common.DefaultLanguageCode());
	
	Item = Items.Add();
	Item.PredefinedKindName = "CounterpartyLegalAddress";
	Item.Parent = "CatalogCounterparties";
	Item.Type = Enums.ContactInformationTypes.Address;
	Item.IDForFormulas = "LegalAddress";
	Item.EditingOption = "InputField";
	Item.IncludeCountryInPresentation = True;
	Item.InternationalAddressFormat = True;
	Item.StoreChangeHistory = False;
	Item.IsAlwaysDisplayed = True;
	Item.Used = True;
	Item.AddlOrderingAttribute = 2;
	Item.Description = NStr("en = 'Legal address'", Common.DefaultLanguageCode());
	
	Item = Items.Add();
	Item.PredefinedKindName = "CounterpartyWebpage";
	Item.Parent = "CatalogCounterparties";
	Item.Type = Enums.ContactInformationTypes.WebPage;
	Item.IDForFormulas = "Webpage";
	Item.EditingOption = "InputField";
	Item.AllowMultipleValueInput = True;
	Item.AddlOrderingAttribute = 3;
	Item.IsAlwaysDisplayed = True;
	Item.Used = True;
	Item.Description = NStr("en = 'Webpage'", Common.DefaultLanguageCode());
	
	Item = Items.Add();
	Item.PredefinedKindName = "CounterpartyPhone";
	Item.Parent = "CatalogCounterparties";
	Item.Type = Enums.ContactInformationTypes.Phone;
	Item.IDForFormulas = "Phone";
	Item.EditingOption = "InputFieldAndDialog";
	Item.CanChangeEditMethod = True;
	Item.AllowMultipleValueInput = True;
	Item.PhoneWithExtensionNumber = True;
	Item.AddlOrderingAttribute = 4;
	Item.IsAlwaysDisplayed = True;
	Item.Used = True;
	Item.Description = NStr("en = 'Phone'", Common.DefaultLanguageCode());
	
	Item = Items.Add();
	Item.PredefinedKindName = "CounterpartyEmail";
	Item.Parent = "CatalogCounterparties";
	Item.Type = Enums.ContactInformationTypes.Email;
	Item.IDForFormulas = "Email";
	Item.EditingOption = "InputField";
	Item.AllowMultipleValueInput = True;
	Item.AddlOrderingAttribute = 5;
	Item.IsAlwaysDisplayed = True;
	Item.Used = True;
	Item.Description = NStr("en = 'Email'", Common.DefaultLanguageCode());
	
#EndRegion

EndProcedure

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.
//
// Parameters:
//  Object                  - CatalogObject.PerformerRoles - Object to populate.
//  Data                  - ValueTableRow - Object fill data.
//  AdditionalParameters - Structure:
//   * PredefinedData - ValueTable - Data populated in the OnInitialItemsFilling procedure.
//
Procedure OnInitialItemFilling(Object, Data, AdditionalParameters) Export
	
EndProcedure

#EndRegion
