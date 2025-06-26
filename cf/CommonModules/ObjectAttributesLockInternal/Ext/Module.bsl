///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Sets up the object form for subsystem operations:
// - Adds the AttributesLockParameters attribute that can be used to store internal data.
// - Adds the AllowObjectAttributeEdit command and button (if sufficient rights are available).
//
// Parameters:
//  Form - ClientApplicationForm:
//    * AttributeEditProhibitionParameters - ValueTable:
//        ** AttributeName - String
//        ** Presentation - String
//        ** EditingAllowed - Boolean
//        ** ItemsToLock - Array
//        ** RightToEdit - Boolean
//        ** IsFormAttribute - Boolean
//  Ref - AnyRef
//  LockButtonGroup - FormGroup
//  LockButtonTitle - FormGroup
//
Procedure PrepareForm(Form, Ref, LockButtonGroup, LockButtonTitle) Export
	
	TypesDetailsString = New TypeDescription("String");
	TypesDetailsBoolean = New TypeDescription("Boolean");
	ArrayTypeDescription = New TypeDescription("ValueList");
	
	// Adding attributes to form.
	AttributesToBeAdded = New Array;
	AttributesToBeAdded.Add(New FormAttribute("FullNameOfAttributesUnlockingObject", New TypeDescription("String")));
	AttributesToBeAdded.Add(New FormAttribute("FullNameOfAttributeUnlockForm",   New TypeDescription("String")));
	AttributesToBeAdded.Add(New FormAttribute("AttributeEditProhibitionParameters",  New TypeDescription("ValueTable")));
	AttributesToBeAdded.Add(New FormAttribute("AttributeName",            TypesDetailsString, "AttributeEditProhibitionParameters"));
	AttributesToBeAdded.Add(New FormAttribute("Presentation",           TypesDetailsString, "AttributeEditProhibitionParameters"));
	AttributesToBeAdded.Add(New FormAttribute("EditingAllowed", TypesDetailsBoolean, "AttributeEditProhibitionParameters"));
	AttributesToBeAdded.Add(New FormAttribute("ItemsToLock",     ArrayTypeDescription, "AttributeEditProhibitionParameters"));
	AttributesToBeAdded.Add(New FormAttribute("RightToEdit",     TypesDetailsBoolean, "AttributeEditProhibitionParameters"));
	AttributesToBeAdded.Add(New FormAttribute("IsFormAttribute",        TypesDetailsBoolean, "AttributeEditProhibitionParameters"));
	
	Form.ChangeAttributes(AttributesToBeAdded);
	
	ObjectMetadata = Ref.Metadata();
	Form.FullNameOfAttributesUnlockingObject = ObjectMetadata.FullName();
	MetadataObjectForm = ObjectMetadata.Forms.Find("AttributeUnlocking");
	If MetadataObjectForm <> Undefined Then
		Form.FullNameOfAttributeUnlockForm = MetadataObjectForm.FullName();
	EndIf;
	
	AttributesToLock = BlockedObjectDetailsAndFormElements(ObjectMetadata.FullName());
	AllAttributesEditProhibited = True;
	
	PopulateDetailsForLockedAttributes(Form.AttributeEditProhibitionParameters,
		ObjectMetadata, AttributesToLock, AllAttributesEditProhibited, Form);
	
	FillRelatedItems(Form);
	
	// Adding command and button (if sufficient rights are available).
	If Users.RolesAvailable("EditObjectAttributes")
	   And AccessRight("Edit", ObjectMetadata)
	   And Not AllAttributesEditProhibited Then
		
		// Add a command.
		Command = Form.Commands.Add("AllowObjectAttributeEdit");
		Command.Title = ?(IsBlankString(LockButtonTitle), NStr("en = 'Allow edit attributes';"), LockButtonTitle);
		Command.Action = "Attachable_AllowObjectAttributeEdit";
		Command.Picture = PictureLib.AllowObjectAttributeEdit;
		Command.ModifiesStoredData = True;
		
		// Add a button.
		ParentGroup2 = ?(LockButtonGroup <> Undefined, LockButtonGroup, Form.CommandBar);
		Button = Form.Items.Add("AllowObjectAttributeEdit", Type("FormButton"), ParentGroup2);
		Button.LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
		Button.CommandName = "AllowObjectAttributeEdit";
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Intended for the PrepareForm procedure.
Procedure PopulateDetailsForLockedAttributes(LongDesc, ObjectMetadata, AttributesToLock,
			AllAttributesEditProhibited, Form = Undefined) Export
	
	FormAttributes = Undefined;
	
	For Each AttributeToLock In AttributesToLock Do
		If Not ValueIsFilled(AttributeToLock.Name) Then
			Continue;
		EndIf;
		
		AttributeDetails = LongDesc.Add();
		
		AttributeDetails.AttributeName = AttributeToLock.Name;
		
		For Each ItemToLock In AttributeToLock.FormItems Do
			AttributeDetails.ItemsToLock.Add(TrimAll(ItemToLock));
		EndDo;
		
		IsChartOfAccounts = Common.IsChartOfAccounts(ObjectMetadata);
		ThereAreStandardTabularSections = IsChartOfAccounts Or Common.IsChartOfCalculationTypes(ObjectMetadata);
		
		AttributeOrTabularSectionMetadata = ObjectMetadata.Attributes.Find(AttributeDetails.AttributeName);
		If AttributeOrTabularSectionMetadata = Undefined And IsChartOfAccounts Then
			AttributeOrTabularSectionMetadata = ObjectMetadata.AccountingFlags.Find(AttributeDetails.AttributeName);
		EndIf;
		StandardAttributeOrStandardTabularSection = False;
		
		If AttributeOrTabularSectionMetadata = Undefined Then
			AttributeOrTabularSectionMetadata = ObjectMetadata.TabularSections.Find(AttributeDetails.AttributeName);
			
			If AttributeOrTabularSectionMetadata = Undefined
			   And ThereAreStandardTabularSections
			   And Common.IsStandardAttribute(ObjectMetadata.StandardTabularSections, AttributeDetails.AttributeName) Then
					AttributeOrTabularSectionMetadata = ObjectMetadata.StandardTabularSections[AttributeDetails.AttributeName];
					StandardAttributeOrStandardTabularSection = True;
			EndIf;
			If AttributeOrTabularSectionMetadata = Undefined Then
				If Common.IsStandardAttribute(ObjectMetadata.StandardAttributes, AttributeDetails.AttributeName) Then
					AttributeOrTabularSectionMetadata = ObjectMetadata.StandardAttributes[AttributeDetails.AttributeName];
					StandardAttributeOrStandardTabularSection = True;
				EndIf;
			EndIf;
		EndIf;
		
		If AttributeOrTabularSectionMetadata = Undefined Then
			If Form = Undefined Then
				Continue;
			EndIf;
			If FormAttributes = Undefined Then
				FormAttributes = New Map;
				For Each FormAttribute In Form.GetAttributes() Do
					FormAttributes.Insert(FormAttribute.Name, FormAttribute.Title);
				EndDo;
			EndIf;
			
			AttributeDetails.Presentation = FormAttributes[AttributeDetails.AttributeName];
			AttributeDetails.IsFormAttribute = True;
			
			AttributeDetails.RightToEdit = True;
			AllAttributesEditProhibited = False;
		Else
			AttributeDetails.Presentation = AttributeOrTabularSectionMetadata.Presentation();
			
			If StandardAttributeOrStandardTabularSection Then
				RightToEdit = AccessRight("Edit", ObjectMetadata, , AttributeOrTabularSectionMetadata.Name);
			Else
				RightToEdit = AccessRight("Edit", AttributeOrTabularSectionMetadata);
			EndIf;
			If RightToEdit Then
				AttributeDetails.RightToEdit = True;
				AllAttributesEditProhibited = False;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// For the PrepareForm procedure.
// Supplements an array of form items to be locked with the linked items.
//
Procedure FillRelatedItems(Form)
	
	Filter = New Structure("AttributeName, IsFormAttribute", "", False);
	
	For Each FormItem In Form.Items Do
		
		If TypeOf(FormItem) = Type("FormField")
		   And FormItem.Type <> FormFieldType.LabelField
		 Or TypeOf(FormItem) = Type("FormTable") Then
		
			ParsedDataPath = StrSplit(FormItem.DataPath, ".", False);
			
			If ParsedDataPath.Count() > 2 Then
				Continue;
			ElsIf ParsedDataPath.Count() = 2 Then
				Filter.AttributeName = ParsedDataPath[1];
				Filter.IsFormAttribute = False;
			Else
				Filter.AttributeName = ParsedDataPath[0];
				Filter.IsFormAttribute = True;
			EndIf;
			Rows = Form.AttributeEditProhibitionParameters.FindRows(Filter);
			If Rows.Count() > 0 Then
				Rows[0].ItemsToLock.Add(FormItem.Name);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Function ObjectsWithLockedAttributes()
	
	Objects = New Map;
	SSLSubsystemsIntegration.OnDefineObjectsWithLockedAttributes(Objects);
	ObjectAttributesLockOverridable.OnDefineObjectsWithLockedAttributes(Objects);
	
	Return Objects;
	
EndFunction

// Returns a list of attributes and object tabular sections locked for editing
// and form items linked to them.
// 
// Parameters:
//  ObjectName - String - Full name of a metadata object.
//
// Returns:
//  Array of See ObjectAttributesLock.NewAttributeToLock
//
Function BlockedObjectDetailsAndFormElements(ObjectName) Export
	
	Result = New Array;
	
	Objects = ObjectsWithLockedAttributes();
	If Objects[ObjectName] = Undefined Then
		Return Result;
	EndIf;
	
	AttributesToLock = Common.ObjectManagerByFullName(ObjectName).GetObjectAttributesToLock();
	ObjectAttributesLockOverridable.OnDefineLockedAttributes(ObjectName, AttributesToLock);
	
	For Each AttributeToLock In AttributesToLock Do
		If TypeOf(AttributeToLock) <> Type("Structure") Then
			StringParts1 = StrSplit(AttributeToLock, ";");
			NewAttributeToLock = ObjectAttributesLock.NewAttributeToLock();
			NewAttributeToLock.Name = TrimAll(StringParts1[0]);
			If StringParts1.Count() > 1 Then
				For Each TagName In StrSplit(StringParts1[1], ",", False) Do
					NewAttributeToLock.FormItems.Add(TrimAll(TagName));
				EndDo;
			EndIf;
			If StringParts1.Count() > 2 Then
				NewAttributeToLock.Group = TrimAll(StringParts1[2]);
			EndIf;
			Result.Add(NewAttributeToLock);
		Else
			Result.Add(AttributeToLock);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion
