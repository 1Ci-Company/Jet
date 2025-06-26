///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Prohibits editing specified attributes
//  of an object form, and adds the Allow editing
//  attributes command to All actions.
//
// Parameters:
//  Form - ClientApplicationForm
//        - ManagedFormExtensionForObjects - Object form, where:
//    * Object - FormDataStructure
//             - CatalogObject
//             - DocumentObject
//    * Items - FormAllItems:
//        ** AllowObjectAttributeEdit - FormButton
//  LockButtonGroup  - FormGroup - used to modify the default placement
//                            of the lock button in the object form.
//  LockButtonTitle  - String - The button title. By default, "Allow edit attributes".
//  Object                  - Undefined - take the object from the Object form attribute.
//                          - FormDataStructure - by object type.
//                          - CatalogObject
//                          - DocumentObject
//
Procedure LockAttributes(Form, LockButtonGroup = Undefined, LockButtonTitle = "",
		Object = Undefined) Export
	
	ObjectDetails = ?(Object = Undefined, Form.Object, Object);
	
	// Determining whether the form is already prepared during an earlier call.
	FormPrepared = False;
	FormAttributes = Form.GetAttributes();
	For Each FormAttribute In FormAttributes Do
		If FormAttribute.Name = "AttributeEditProhibitionParameters" Then
			FormPrepared = True;
			Break;
		EndIf;
	EndDo;
	
	If Not FormPrepared Then
		ObjectAttributesLockInternal.PrepareForm(Form,
			ObjectDetails.Ref, LockButtonGroup, LockButtonTitle);
	EndIf;
	
	IsNewObject = ObjectDetails.Ref.IsEmpty();
	
	// Enabling edit prohibition for form items related to the specified attributes.
	For Each DescriptionOfAttributeToLock In Form.AttributeEditProhibitionParameters Do
		For Each FormItemDescription In DescriptionOfAttributeToLock.ItemsToLock Do
			
			DescriptionOfAttributeToLock.EditingAllowed =
				DescriptionOfAttributeToLock.RightToEdit And IsNewObject;
			If DescriptionOfAttributeToLock.EditingAllowed Then
				Continue;
			EndIf;
			
			FormItem = Form.Items.Find(FormItemDescription.Value);
			If FormItem = Undefined Then
				Continue;
			EndIf;
			
			If TypeOf(FormItem) = Type("FormField")
			   And FormItem.Type <> FormFieldType.LabelField
			 Or TypeOf(FormItem) = Type("FormTable") Then
				FormItem.ReadOnly = Not DescriptionOfAttributeToLock.EditingAllowed;
			Else
				FormItem.Enabled = DescriptionOfAttributeToLock.EditingAllowed;
			EndIf;
		EndDo;
	EndDo;
	
	If Form.Items.Find("AllowObjectAttributeEdit") <> Undefined Then
		Form.Items.AllowObjectAttributeEdit.Enabled = True;
	EndIf;
	
EndProcedure

// Returns a list of attributes and object tabular sections locked for editing.
// 
// Parameters:
//  ObjectName - String - Full name of a metadata object.
//
// Returns:
//  Array of String 
//
Function ObjectAttributesToLock(ObjectName) Export
	
	AttributesDetails2 = ObjectAttributesLockInternal.BlockedObjectDetailsAndFormElements(ObjectName);
	
	Result = New Array;
	For Each AttributeDetails In AttributesDetails2 Do
		If ValueIsFilled(AttributeDetails.Name) Then
			Result.Add(AttributeDetails.Name);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns the properties of new extended details of the attribute being locked.
// The obtained properties are intended for the GetObjectAttributesToLock function in object manager modules.
//
// Returns:
//  Structure:
//   * Name - String - Attribute name. For example, "Object.Author", "AcceptRevenueAsTotalAmount".
//                    Leave it empty if you want to specify a group separately.
//   * FormItems - Array of String - The names of the form items related to the attribute.
//        The parameter is required if the names cannot be derived from the form item to the attribute name.
//        For example, "AcceptRevenueAsTotalAmountRadioButton".
//   * Warning - String - The warning text mentioning the consequences of the unlocking.
//                       The text is displayed in the unlock form, above the attribute (attribute group).
//   * Group - String - The name of the attribute group used in the unlock form.
//                       It is not required if the attribute is output individually.
//                       It is ignored in calls from bulk attribute edit (except from CommonLabel).
//   * GroupPresentation - String - The presentation of the attribute group displayed in the unlock form.
//                       It is not required if the attribute is output individually.
//                       It is ignored in calls from bulk attribute edit (except from CommonLabel).
//   * WarningForGroup - String - The warning text mentioning the consequences of the unlocking.
//                       The text is displayed in the unlock form, above the attribute group.
//   * Warning - String - The warning text mentioning the consequences of the unlocking.
//                       The text is displayed in the unlock form, above the attribute (attribute group).
//
Function NewAttributeToLock() Export
	
	Result = New Structure;
	Result.Insert("Name", "");
	Result.Insert("FormItems", New Array);
	Result.Insert("Group", "");
	Result.Insert("GroupPresentation", "");
	Result.Insert("Warning", "");
	Result.Insert("WarningForGroup", "");
	
	Return Result;
	
EndFunction

#Region ForCallsFromOtherSubsystems

// Describes the value types of the array returned by
// the GetObjectAttributesToLock function.
//
// Returns:
//  String - A string the following format: "AttributeName[;FormItemName,...][;GroupName], where
//             AttributeName - The name of an object's attribute
//             FormItemName - The name of the form item related to the given attribute.
//               For example, "Object.Author" or "FieldAuthor".
//             GroupName - The name of the attributes group displayed in the unlock form.
//
//   See NewAttributeToLock
//
Function DescriptionOfAttributeToLock() Export
	
	Return "";
	
EndFunction

#EndRegion

#EndRegion
